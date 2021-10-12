CREATE OR REPLACE PACKAGE BODY xxcst_general_pkg IS
  ------------------------------------------------------------------
  -- $Header: xxcst_general_pkg   $
  ------------------------------------------------------------------
  -- Package: XXCST_GENERAL_PKG
  -- Created:
  -- Author:  Vitaly
  ------------------------------------------------------------------
  -- Purpose: 
  ------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ----------------------------
  --     1.0  03.10.13   Vitaly         initial build
  ------------------------------------------------------------------

  ----------------------------------------------------------------------------
  -- get_buy_item_avg_material_cost
  --------------------------------------------------------------------------
  -- Version  Date        Performer       Comments
  ----------  --------    --------------  -------------------------------------
  -- 1.0      03.10.2013  Vitaly          cr1055 initial revision
  ---------------------------------------------------------------------------
  FUNCTION get_buy_item_avg_material_cost(p_organization_id   IN NUMBER,
                                          p_inventory_item_id IN NUMBER,
                                          p_from_date         IN DATE,
                                          p_to_date           IN DATE)
    RETURN NUMBER IS
    v_buy_item_avg_material_cost NUMBER;
  
  BEGIN
  
    IF p_organization_id IS NULL OR p_inventory_item_id IS NULL OR
       p_from_date IS NULL OR p_to_date IS NULL THEN
      RETURN NULL;
    END IF;
  
    SELECT round(SUM(a.unit_cost * a.transaction_quantity) /
                 SUM(a.transaction_quantity),
                 4) item_average_material_cost
      INTO v_buy_item_avg_material_cost
      FROM cst_inv_distribution_v a, mtl_system_items_b msi
     WHERE a.transaction_type_id = 18 -------PO Receipt
       AND a.line_type_name = 'Receiving Inspection'
       AND a.transaction_quantity <> 0
       AND a.transaction_date BETWEEN p_from_date AND p_to_date ---parameters
       AND a.inventory_item_id = msi.inventory_item_id
       AND a.organization_id = msi.organization_id
       AND msi.planning_make_buy_code = 2
       AND a.inventory_item_id = p_inventory_item_id --parameter
       AND a.organization_id = p_organization_id; ---parameter
  
    RETURN v_buy_item_avg_material_cost;
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_buy_item_avg_material_cost;
  ----------------------------------------------------------------------------
  -- get_buy_item_prev_mat_cost
  --------------------------------------------------------------------------
  -- Version  Date        Performer       Comments
  ----------  --------    --------------  -------------------------------------
  -- 1.0      03.10.2013  Vitaly          cr1055 initial revision
  ---------------------------------------------------------------------------
  FUNCTION get_buy_item_prev_mat_cost(p_organization_id   IN NUMBER,
                                      p_inventory_item_id IN NUMBER,
                                      p_date              IN DATE)
    RETURN NUMBER IS
    v_buy_item_prev_mat_cost NUMBER;
  
  BEGIN
  
    IF p_organization_id IS NULL OR p_inventory_item_id IS NULL OR
       p_date IS NULL THEN
      RETURN NULL;
    END IF;
  
    SELECT round(a.unit_cost, 4) last_prev_unit_cost
      INTO v_buy_item_prev_mat_cost
      FROM cst_inv_distribution_v a, mtl_system_items_b msi
     WHERE a.transaction_type_id = 18 -------PO Receipt
       AND a.line_type_name = 'Receiving Inspection'
       AND a.transaction_date =
           (SELECT MAX(a2.transaction_date)
              FROM cst_inv_distribution_v a2
             WHERE a2.transaction_type_id = 18 -------PO Receipt
               AND a2.line_type_name = 'Receiving Inspection'
               AND a2.transaction_date < p_date --- parameter
               AND a2.inventory_item_id = a.inventory_item_id
               AND a2.organization_id = a.organization_id)
       AND a.inventory_item_id = msi.inventory_item_id
       AND a.organization_id = msi.organization_id
       AND msi.planning_make_buy_code = 2
       AND a.transaction_date < p_date --- parameter
       AND a.inventory_item_id = p_inventory_item_id --parameter
       AND a.organization_id = p_organization_id; ---parameter
  
    RETURN v_buy_item_prev_mat_cost;
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_buy_item_prev_mat_cost;
  ----------------------------------------------------------------------------
  -- get_buy_item_curr_std_cost
  --------------------------------------------------------------------------
  -- Version  Date        Performer       Comments
  ----------  --------    --------------  -------------------------------------
  -- 1.0      03.10.2013  Vitaly          cr1055 initial revision
  ---------------------------------------------------------------------------
  FUNCTION get_buy_item_curr_std_cost(p_organization_id   IN NUMBER,
                                      p_inventory_item_id IN NUMBER)
    RETURN NUMBER IS
    v_curr_std_cost NUMBER;
  
  BEGIN
  
    IF p_organization_id IS NULL OR p_inventory_item_id IS NULL THEN
      RETURN NULL;
    END IF;
  
    SELECT cst.material_cost standard_cost
      INTO v_curr_std_cost
      FROM cst_item_costs cst
     WHERE cst.cost_type_id = 1
       AND cst.inventory_item_id = p_inventory_item_id --parameter
       AND cst.organization_id = p_organization_id; ---parameter
  
    RETURN v_curr_std_cost;
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_buy_item_curr_std_cost;
  ----------------------------------------------------------------------------
  -- get_buy_item_last_unit_price
  --------------------------------------------------------------------------
  -- Version  Date        Performer       Comments
  ----------  --------    --------------  -------------------------------------
  -- 1.0      14.10.2013  Vitaly          cr1055 initial revision
  ---------------------------------------------------------------------------
  FUNCTION get_buy_item_last_unit_price(p_inventory_item_id IN NUMBER)
    RETURN NUMBER IS
    v_unit_price NUMBER;
  
  BEGIN
  
    IF p_inventory_item_id IS NULL THEN
      RETURN NULL;
    END IF;
  
    /*v_unit_price := xxpo_utils_pkg.get_last_po_price(p_inventory_item_id,
    SYSDATE); ----Ask Yair*/
  
    SELECT gl_currency_api.convert_closest_amount_sql(nvl(ind.currency_code,
                                                          h.currency_code),
                                                      'USD',
                                                      nvl(ind.base_date,
                                                          nvl(h.rate_date,
                                                              h.creation_date)),
                                                      'Corporate',
                                                      nvl(ind.base_rate,
                                                          h.rate),
                                                      l.unit_price /
                                                      decode(ind.base_rate,
                                                             0,
                                                             1,
                                                             NULL,
                                                             1,
                                                             ind.base_rate),
                                                      7)
      INTO v_unit_price
      FROM po_headers_all           h,
           po_lines_all             l,
           po_line_locations_all    pl,
           clef062_po_index_esc_set ind
     WHERE h.po_header_id = l.po_header_id
       AND h.segment1 = ind.document_id(+)
       AND l.po_line_id = pl.po_line_id
       AND h.po_header_id = pl.po_header_id
       AND ind.module(+) = 'PO'
       AND l.item_id = p_inventory_item_id ---parameter
       AND l.org_id = 81
       AND h.type_lookup_code IN ('BLANKET', 'STANDARD')
       AND h.authorization_status = 'APPROVED'
       AND nvl(l.cancel_flag, 'N') = 'N'
          ---AND pl.need_by_date =
          ---    (SELECT MAX(pl1.need_by_date)
       AND pl.line_location_id =
           (SELECT MAX(pl1.line_location_id)
              FROM po_headers_all        h1,
                   po_lines_all          l1,
                   po_line_locations_all pl1
             WHERE h1.po_header_id = l1.po_header_id
               AND l1.po_line_id = pl1.po_line_id
               AND l1.item_id = p_inventory_item_id ---parameter
               AND l1.org_id = 81
               AND h1.type_lookup_code IN ('BLANKET', 'STANDARD')
               AND h1.authorization_status = 'APPROVED'
               AND nvl(l1.cancel_flag, 'N') = 'N'
                  ----AND nvl(pl1.promised_date, pl1.need_by_date) < SYSDATE
               AND l1.unit_price > 0);
    ---AND rownum = 1;
  
    RETURN v_unit_price;
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_buy_item_last_unit_price;
  ----------------------------------------------------------------------------
  -- get_buy_item_last_need_by_date
  --------------------------------------------------------------------------
  -- Version  Date        Performer       Comments
  ----------  --------    --------------  -------------------------------------
  -- 1.0      14.10.2013  Vitaly          cr1055 initial revision
  ---------------------------------------------------------------------------
  FUNCTION get_buy_item_last_need_by_date(p_inventory_item_id IN NUMBER)
    RETURN DATE IS
    v_need_by_date DATE;
  
  BEGIN
  
    IF p_inventory_item_id IS NULL THEN
      RETURN NULL;
    END IF;
  
    /*SELECT MAX(pl1.need_by_date)
     INTO v_need_by_date
     FROM po_headers_all h1, po_lines_all l1, po_line_locations_all pl1
    WHERE h1.po_header_id = l1.po_header_id
      AND l1.po_line_id = pl1.po_line_id
      AND l1.item_id = p_inventory_item_id ---parameter
      AND l1.org_id = 81
      AND h1.type_lookup_code IN ('BLANKET', 'STANDARD')
      AND h1.authorization_status = 'APPROVED'
      AND nvl(l1.cancel_flag, 'N') = 'N'
         ----AND nvl(pl1.promised_date, pl1.need_by_date) < SYSDATE
      AND l1.unit_price > 0;*/
    SELECT pl.need_by_date
      INTO v_need_by_date
      FROM po_line_locations_all pl
     WHERE pl.line_location_id =
           (SELECT MAX(pl1.line_location_id)
              FROM po_headers_all        h1,
                   po_lines_all          l1,
                   po_line_locations_all pl1
             WHERE h1.po_header_id = l1.po_header_id
               AND l1.po_line_id = pl1.po_line_id
               AND l1.item_id = p_inventory_item_id ---parameter
               AND l1.org_id = 81
               AND h1.type_lookup_code IN ('BLANKET', 'STANDARD')
               AND h1.authorization_status = 'APPROVED'
               AND nvl(l1.cancel_flag, 'N') = 'N'
                  ----AND nvl(pl1.promised_date, pl1.need_by_date) < SYSDATE
               AND l1.unit_price > 0);
    --AND rownum = 1;
  
    RETURN v_need_by_date;
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_buy_item_last_need_by_date;
  --------------------------------------------------------------
END xxcst_general_pkg;
/
