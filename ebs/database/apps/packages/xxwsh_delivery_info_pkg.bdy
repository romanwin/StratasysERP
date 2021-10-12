create or replace package body xxwsh_delivery_info_pkg IS
  --------------------------------------------------------------------
  --  name:            XXWSH_DELIVERY_INFO_PKG
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   29/03/2015 14:11:28
  --------------------------------------------------------------------
  --  purpose :        CHG0034230 - Commercial Invoice modifications
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  29/03/2015  Dalit A. Raviv    initial build
  --  1.1  01/Jun/2015 Dalit A. Raviv    CHG0035526 - get_line_unit_price - change logic of calculation
  --  1.2  18/Jun/2015 Dalit A. Raviv    CHG0035672 - Commercial Invoice Pricing and Discount change Logic
  --                                     new functions: get_customs_price, get_price_list_distribution,
  --                                     get_parent_line_id, get_parent_line_price
  --                                     Update functions: get_line_unit_price, get_line_discount_percent
  --  1.3  04/08/2015  Dalit A. Raviv    Happy birthday Dalit!!!
  --                                     get_line_unit_price -> INC0042143, correct security calculation of price.
  --  1.4  25/08/2015  Yuval tal         INC0046407 modify get_line_unit_price
  --  1.5  06-Sep-2015 Dalit A. Raviv    CHG0036018 - Commercial invoice modifications
  --                                     add function - get_country_of_origion
  --  1.6  11-Nov-2015 Dalit A. Raviv    CHG0036697 - UOM modifications - take from delivery and not from SO line
  --  1.7  07-Jun-2017 Lingaraj(TCS)     CHG0040996 Discrepancy of Warranty price on Commercial Invoice and Order
  --  1.8  26-Sep-2019 Bellona(TCS)      CHG0046167 - Packing List Reports
  --                   add functions - get_gross_weight, get_chargeable_weight
  --  1.9  31/03/2020  Roman W.          CHG0047653 - Commercial Invoice - Change logic for Zero price for SP items
  --------------------------------------------------------------------

  --------------------------------------------------------------------
  --  customization code: CHG0034230
  --  name:               show_in_doc
  --  create by:          Dalit A. Raviv
  --  creation date:      24/03/2015
  --  Purpose :
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   24/03/2015    Dalit A. Raviv  Initial Build
  ----------------------------------------------------------------------
  FUNCTION show_parent_in_doc(p_line_id IN NUMBER) RETURN VARCHAR2 IS
    l_return VARCHAR2(10);
  BEGIN
    -- Show parent
    --if p_parent = 'Y' then
    SELECT 'Y'
      INTO l_return
      FROM oe_price_adjustments opa, qp_list_lines pll
     WHERE opa.list_header_id = pll.list_header_id
       AND opa.list_line_id = pll.list_line_id
       AND opa.list_line_type_code = 'PRG'
       AND nvl(pll.attribute3, 'NO') = 'YES'
       AND opa.line_id = p_line_id;
  
    RETURN l_return;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 'N';
  END show_parent_in_doc;

  --------------------------------------------------------------------
  --  customization code: CHG0034230
  --  name:               show_in_doc
  --  create by:          Dalit A. Raviv
  --  creation date:      24/03/2015
  --  Purpose :
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   24/03/2015    Dalit A. Raviv  Initial Build
  ----------------------------------------------------------------------
  FUNCTION show_child_in_doc(p_line_id IN NUMBER) RETURN VARCHAR2 IS
    l_return VARCHAR2(10);
  BEGIN
    -- Show child
    SELECT 'Y'
      INTO l_return
      FROM oe_price_adjustments opa, qp_list_lines pll
     WHERE opa.list_header_id = pll.list_header_id
       AND opa.list_line_id = pll.list_line_id
       AND opa.list_line_type_code = 'DIS'
       AND nvl(pll.attribute3, 'YES') = 'YES'
       AND opa.line_id = p_line_id
       AND rownum = 1;
  
    RETURN l_return;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 'N';
  END show_child_in_doc;

  --------------------------------------------------------------------
  --  customization code: CHG0034230
  --  name:               get_parent_item
  --  create by:          Dalit A. Raviv
  --  creation date:      29/03/2015
  --  Purpose :
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   29/03/2015    Dalit A. Raviv  Initial Build
  --  1.1   23/06/2015    Dalit A. Raviv  CHG0035672 - Commercial Invoice change Logic
  ----------------------------------------------------------------------
  FUNCTION get_parent_item(p_line_id IN NUMBER) RETURN VARCHAR2 IS
    l_item VARCHAR2(240);
  BEGIN
    BEGIN
      -- Case of Bundle Parent (Buy and Get)
      SELECT oola.ordered_item
        INTO l_item
        FROM oe_price_adjustments    tcomp,
             ont.oe_price_adj_assocs opaa,
             oe_price_adjustments    tprnt,
             ont.oe_order_lines_all  oola
       WHERE tcomp.line_id = p_line_id --<Parameter>
         AND tprnt.price_adjustment_id = opaa.price_adjustment_id
         AND opaa.rltd_price_adj_id = tcomp.price_adjustment_id
         AND tprnt.header_id = tcomp.header_id
         AND tprnt.line_id = oola.line_id
         AND tcomp.list_line_type_code = 'DIS'
         AND tprnt.list_line_type_code = 'PRG';
    
    EXCEPTION
      WHEN OTHERS THEN
        BEGIN
          -- Case of PTO
          SELECT oola2.ordered_item
            INTO l_item
            FROM oe_order_lines_all oola1, oe_order_lines_all oola2
           WHERE oola1.line_id = p_line_id --<param>
             AND oola2.line_id = oola1.top_model_line_id
             AND oola1.line_id <> oola1.top_model_line_id;
        EXCEPTION
          WHEN OTHERS THEN
            -- Case regular item with no parent
            l_item := NULL;
        END;
    END;
  
    RETURN l_item;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_parent_item;

  --------------------------------------------------------------------
  --  customization code: CHG0034230
  --  name:               get_parent_line_discount
  --  create by:          Dalit A. Raviv
  --  creation date:      29/03/2015
  --  In param:           p_entity - BUNDLE/ PTO
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   29/03/2015    Dalit A. Raviv  Initial Build
  ----------------------------------------------------------------------
  FUNCTION get_parent_line_discount(p_entity  IN VARCHAR2,
                                    p_line_id IN NUMBER) RETURN NUMBER IS
  
    l_discount NUMBER := 0;
  BEGIN
  
    -- Buy & Get Parent Discount
    IF p_entity = 'BUNDLE' THEN
      SELECT SUM(tprnt.adjusted_amount * (-1)) /
             (oola1.ordered_quantity * oola1.unit_list_price)
        INTO l_discount
        FROM oe_price_adjustments tprnt,
             oe_price_adjustments tcomp,
             oe_order_lines_all   oola1
       WHERE tcomp.line_id = p_line_id
         AND tcomp.list_header_id = tprnt.list_header_id
         AND tcomp.header_id = tprnt.header_id
         AND tcomp.list_line_type_code = 'DIS'
         AND tprnt.list_line_type_code = 'PRG'
         AND tprnt.line_id = oola1.line_id
         AND oola1.unit_list_price IS NOT NULL
         AND oola1.unit_list_price != 0
       GROUP BY oola1.ordered_quantity, oola1.unit_list_price;
      -- PTO Parent Discount
    ELSIF p_entity = 'PTO' THEN
      SELECT SUM(tprnt.adjusted_amount * (-1)) /
             (oola1.ordered_quantity * oola1.unit_list_price)
        INTO l_discount
        FROM oe_price_adjustments tprnt, oe_order_lines_all oola1
       WHERE tprnt.line_id = p_line_id
         AND tprnt.line_id = oola1.line_id
         AND oola1.unit_list_price IS NOT NULL
         AND oola1.unit_list_price != 0
       GROUP BY oola1.ordered_quantity, oola1.unit_list_price;
    ELSE
      l_discount := 0;
    END IF;
  
    RETURN nvl(l_discount, 0);
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 0;
  END get_parent_line_discount;

  --------------------------------------------------------------------
  --  customization code: CHG0034230
  --  name:               get_parent_item
  --  create by:          Dalit A. Raviv
  --  creation date:      29/03/2015
  --  Purpose :
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   29/03/2015    Dalit A. Raviv  Initial Build
  --  1.1   21/06/2015    dalit A. Raviv  CHG0035672 change the all logic of how to calculate the discount logic
  --                                      new logic exists in design and design diagram.
  ----------------------------------------------------------------------
  FUNCTION get_line_discount_percent(p_line_id IN NUMBER,
                                     p_index   IN NUMBER DEFAULT 0)
    RETURN NUMBER IS
  
    l_line_rec       oe_order_lines_all%ROWTYPE;
    l_discount       NUMBER;
    l_parent_line_id NUMBER := NULL;
  BEGIN
    -- CHG0035672 1.2 18/06/2015 Dalit A. Raviv
    -- to prevent the recursive to work more then 3 times.
    IF p_index > 3 THEN
      RETURN NULL;
    END IF;
  
    SELECT *
      INTO l_line_rec
      FROM oe_order_lines_all oola
     WHERE oola.line_id = p_line_id;
  
    IF l_line_rec.unit_list_price = 0 THEN
      -- CHG0035672 1.2 18/06/2015 Dalit A. Raviv
      -- if bundle or pto find the parent item line id and send it in recursive way to the same function.
      IF (xxoe_utils_pkg.is_comp_bundle_line(p_line_id) = 'Y') AND
         (get_parent_line_price(p_line_id, 'BUNDLE') <> 0) THEN
        l_parent_line_id := get_parent_line_id(p_line_id, 'BUNDLE');
        l_discount       := get_line_discount_percent(l_parent_line_id,
                                                      p_index + 1);
      ELSIF (xxwsh_delivery_info_pkg.is_pto_component(p_line_id) = 'Y') AND
            (get_parent_line_price(p_line_id, 'PTO') <> 0) THEN
        l_parent_line_id := get_parent_line_id(p_line_id, 'PTO');
        l_discount       := get_line_discount_percent(l_parent_line_id,
                                                      p_index + 1);
      ELSE
        -- CHG0035672 1.2 18/06/2015 Dalit A. Raviv
        -- if item is not resin there is no discount
        IF xxoe_utils_pkg.is_item_resin_credit(l_line_rec.inventory_item_id) = 'N' THEN
          l_discount := 0;
          -- if item is resin then give the resin credit amount
        ELSE
          IF nvl(l_line_rec.attribute4, 0) = 0 THEN
            l_discount := 0;
          ELSE
            l_discount := 1 - (l_line_rec.unit_selling_price /
                          l_line_rec.attribute4);
          END IF;
        END IF;
      END IF;
      -- unit list price <> 0
    ELSE
      IF l_line_rec.unit_selling_price <> 0 THEN
        l_discount := 1 - (l_line_rec.unit_selling_price /
                      l_line_rec.unit_list_price);
      ELSE
        -- case it is bundle or Pto, look for the parent line id and call recursive the function again.
        IF (xxoe_utils_pkg.is_comp_bundle_line(p_line_id) = 'Y') AND
           (get_parent_line_price(p_line_id, 'BUNDLE') <> 0) THEN
          l_parent_line_id := get_parent_line_id(p_line_id, 'BUNDLE');
          l_discount       := get_line_discount_percent(l_parent_line_id,
                                                        p_index + 1);
        ELSIF (xxwsh_delivery_info_pkg.is_pto_component(p_line_id) = 'Y') AND
              (get_parent_line_price(p_line_id, 'PTO') <> 0) THEN
          l_parent_line_id := get_parent_line_id(p_line_id, 'PTO');
          l_discount       := get_line_discount_percent(l_parent_line_id,
                                                        p_index + 1);
        ELSE
          l_discount := 1;
        END IF;
      END IF;
    END IF;
    RETURN l_discount;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 0;
  END get_line_discount_percent;

  --------------------------------------------------------------------
  --  customization code: CHG0034230
  --  name:               get_line_unit_price
  --  create by:          Dalit A. Raviv
  --  creation date:      29/03/2015
  --  Purpose :
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   29/03/2015    Dalit A. Raviv  Initial Build
  --  1.1   01/Jun/2015   Dalit A. Raviv  CHG0035526 - change logic of calculation
  --  1.2   18/06/2015    Dalit A. Raviv  CHG0035672 - Commercial Invoice Pricing and Discount change Logic
  --                                      1) show discount change logic: delivery att8 , order att3
  --                                      2) calculation for PTO/Bundle changed
  --  1.3   04/08/2015    Dalit A. Raviv  Happy birthday Dalit!!!
  --                                      INC0042143 - correct security calculation of price.
  --  1.4  25/08/15      Yuval tal        INC0046407   modify get_line_unit_price : replave p_sp_id_char => 0 with p_sp_id_char => null
  --  1.5  11-Nov-2015   Dalit A. Raviv   CHG0036697 - UOM modifications - take from delivery and not from SO line
  --  1.6  07-Jun-2017   Lingaraj(TCS)    CHG0040996 - Discrepancy of Warranty price on Commercial Invoice and Order
  --                                      inv_convert.inv_um_convert_new Parameter precision Value Changed from Null to 20
  --  1.9  31/03/2020    Roman W.         CHG0047653 - Commercial Invoice - Change logic for Zero price for SP items  
  ----------------------------------------------------------------------
  FUNCTION get_line_unit_price(p_line_id IN NUMBER) RETURN NUMBER IS
    CURSOR c_line IS
      SELECT * FROM oe_order_lines_all oola WHERE oola.line_id = p_line_id;
  
    l_show_discount oe_order_lines_all.attribute3%TYPE := 'N';
    l_price         NUMBER := 0;
    -- 1.5 11-Nov-2015 Dalit A. Raviv CHG0036697
    l_requested_quantity_uom wsh_delivery_details.requested_quantity_uom%TYPE;
  BEGIN
  
    FOR r_line IN c_line LOOP
      BEGIN
        mo_global.set_org_context(p_org_id_char     => r_line.org_id,
                                  p_sp_id_char      => 0,
                                  p_appl_short_name => 'AR');
      END;
    
      -- Get if to show discount from order header.
      -- CHG0035672 1.2 18/06/2015 Dalit A. Raviv
      -- Show Discount will take from delivery att8 if null from oredr att3
      BEGIN
        SELECT nvl(wnd.attribute8, nvl(ooha.attribute3, 'N')) show_discount
          INTO l_show_discount
          FROM wsh_new_deliveries       wnd,
               wsh_delivery_assignments wda,
               wsh_delivery_details     wdd,
               oe_order_headers_all     ooha
         WHERE wnd.delivery_id = wda.delivery_id
           AND wda.delivery_detail_id = wdd.delivery_detail_id
           AND wdd.source_code = 'OE'
           AND wdd.source_header_id = ooha.header_id
           AND wdd.source_header_id = r_line.header_id
           AND wdd.source_line_id = p_line_id
           AND nvl(wnd.attribute8, nvl(ooha.attribute3, 'N')) = 'Y';
      EXCEPTION
        WHEN too_many_rows THEN
          l_show_discount := 'Y';
        WHEN OTHERS THEN
          l_show_discount := 'N';
      END;
      -- 11-Nov-2015 Dalit A. Raviv CHG0036697
      -- Get delivery_details UOM
      BEGIN
        SELECT wdd.requested_quantity_uom
          INTO l_requested_quantity_uom
          FROM wsh_new_deliveries       wnd,
               wsh_delivery_assignments wda,
               wsh_delivery_details     wdd,
               oe_order_headers_all     ooha
         WHERE wnd.delivery_id = wda.delivery_id
           AND wda.delivery_detail_id = wdd.delivery_detail_id
           AND wdd.source_code = 'OE'
           AND wdd.source_header_id = ooha.header_id
           AND wdd.source_header_id = r_line.header_id
           AND wdd.source_line_id = p_line_id;
      EXCEPTION
        WHEN OTHERS THEN
          l_requested_quantity_uom := r_line.order_quantity_uom;
      END;
    
      IF nvl(l_show_discount, 'Y') = 'N' THEN
        IF r_line.unit_selling_price = 0 THEN
          /* IF xxoe_utils_pkg.is_line_order_under_contract(p_line_id) = 'Y' THEN rem by Roman 31/03/2020 CHG0047653 */
          IF xxoe_utils_pkg.is_line_order_sp_zero(p_line_id) = 'Y' THEN
          
            l_price := (CASE
                         WHEN r_line.unit_list_price = 0 THEN
                          xxoe_utils_pkg.get_qp_list_price(p_line_id)
                         ELSE
                          (r_line.unit_list_price *
                          inv_convert.inv_um_convert_new(r_line.inventory_item_id,
                                                          20, --NULL,----Modified on 7JUN17 for CHG0040996, Parameter Value Change from Null to 20
                                                          1,
                                                          l_requested_quantity_uom, -- 11-Nov-2015 Dalit A. Raviv CHG0036697
                                                          r_line.pricing_quantity_uom,
                                                          NULL,
                                                          NULL,
                                                          'U'))
                       END) / 2;
            RETURN l_price;
          ELSE
            -- line not under contract
            IF (xxoe_utils_pkg.is_comp_bundle_line(p_line_id) = 'Y') AND
               (get_parent_line_price(p_line_id, 'BUNDLE') <> 0) THEN
              l_price := get_price_list_distribution(p_line_id, 'BUNDLE') *
                         (1 - (get_line_discount_percent(p_line_id, 0)));
              RETURN l_price;
            ELSIF (xxwsh_delivery_info_pkg.is_pto_component(p_line_id) = 'Y') AND
                  (get_parent_line_price(p_line_id, 'PTO') <> 0) THEN
              l_price := get_price_list_distribution(p_line_id, 'PTO') *
                         (1 - (get_line_discount_percent(p_line_id, 0)));
              RETURN l_price;
            ELSE
              -- CHG0035672 1.2 18/06/2015 Dalit A. Raviv
              l_price := get_customs_price(p_line_id) *
                         (1 - (get_line_discount_percent(p_line_id, 0)));
              RETURN l_price;
            END IF; -- bundle or PTO
          END IF; -- is_line_order_under_contract = Y
        ELSE
          -- CHG0035672 1.2 18/06/2015 Dalit A. Raviv
          l_price := r_line.unit_selling_price *
                     inv_convert.inv_um_convert_new(r_line.inventory_item_id,
                                                    20, --NULL,--Modified on 7JUN17 for CHG0040996, Parameter Value Change from Null to 20
                                                    1,
                                                    l_requested_quantity_uom, -- 11-Nov-2015 Dalit A. Raviv CHG0036697
                                                    r_line.order_quantity_uom, -- 23-Nov-2015 Moni C.; CHG0036697
                                                    NULL,
                                                    NULL,
                                                    'U');
          RETURN l_price;
        END IF; -- unit_selling_price = 0
      ELSE
        -- show discount = Y
        IF r_line.unit_list_price = 0 THEN
          /* IF xxoe_utils_pkg.is_line_order_under_contract(p_line_id) = 'Y' THEN rem by Roman W 31/03/2020 CHG0047653 */
          IF xxoe_utils_pkg.is_line_order_sp_zero(p_line_id) = 'Y' THEN
            l_price := xxoe_utils_pkg.get_qp_list_price(p_line_id) / 2;
            RETURN l_price;
          ELSE
            -- CHG0035672 1.2 18/06/2015 Dalit A. Raviv
            IF (xxoe_utils_pkg.is_comp_bundle_line(p_line_id) = 'Y') AND
               (get_parent_line_price(p_line_id, 'BUNDLE') <> 0) THEN
              l_price := get_price_list_distribution(p_line_id, 'BUNDLE');
              RETURN l_price;
            ELSIF (xxwsh_delivery_info_pkg.is_pto_component(p_line_id) = 'Y') AND
                  (get_parent_line_price(p_line_id, 'PTO') <> 0) THEN
              l_price := get_price_list_distribution(p_line_id, 'PTO');
              RETURN l_price;
            ELSE
              -- CHG0035672 1.2 18/06/2015 Dalit A. Raviv
              l_price := get_customs_price(p_line_id);
              RETURN l_price;
            END IF; -- bundle or PTO
          END IF; -- line under contract
        ELSE
          /* IF xxoe_utils_pkg.is_line_order_under_contract(p_line_id) = 'Y' THEN rem by Roman W 31/03/2020 CHG0047653 */
          IF xxoe_utils_pkg.is_line_order_sp_zero(p_line_id) = 'Y' THEN
            l_price := (r_line.unit_list_price *
                       inv_convert.inv_um_convert_new(r_line.inventory_item_id,
                                                       20, --NULL,--Modified on 7JUN17 for CHG0040996, Parameter Value Change from Null to 20
                                                       1,
                                                       l_requested_quantity_uom, -- 11-Nov-2015 Dalit A. Raviv CHG0036697 --r_line.order_quantity_uom,
                                                       r_line.order_quantity_uom, -- 26-Nov-2015 Moni C. CHG0036697       -- r_line.pricing_quantity_uom,
                                                       NULL,
                                                       NULL,
                                                       'U')) / 2;
            RETURN l_price;
          ELSE
            IF (xxoe_utils_pkg.is_comp_bundle_line(p_line_id) = 'Y') AND
               (get_parent_line_price(p_line_id, 'BUNDLE') <> 0) THEN
              l_price := get_price_list_distribution(p_line_id, 'BUNDLE');
              RETURN l_price;
            ELSIF xxwsh_delivery_info_pkg.is_pto_component(p_line_id) = 'Y' AND
                  (get_parent_line_price(p_line_id, 'PTO') <> 0) THEN
              l_price := get_price_list_distribution(p_line_id, 'PTO');
              RETURN l_price;
            ELSE
              l_price := (r_line.unit_list_price *
                         inv_convert.inv_um_convert_new(r_line.inventory_item_id,
                                                         20, --NULL,--Modified on 7JUN17 for CHG0040996, Parameter Value Change from Null to 20
                                                         1,
                                                         l_requested_quantity_uom, -- 11-Nov-2015 Dalit A. Raviv CHG0036697 --r_line.order_quantity_uom,
                                                         r_line.order_quantity_uom, -- 26-Nov-2015 Moni C. CHG0036697      --r_line.pricing_quantity_uom,
                                                         NULL,
                                                         NULL,
                                                         'U'));
              RETURN l_price;
            END IF;
          END IF; -- line under contract
        END IF; -- unit_list_price = 0
      END IF; -- show_discount
    END LOOP;
    RETURN l_price;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 0;
  END get_line_unit_price;

  --------------------------------------------------------------------
  --  customization code: CHG0034230
  --  name:               get_delivery_freight_charge
  --  create by:          Dalit A. Raviv
  --  creation date:      28/04/2015
  --  Purpose :           CHG0034736 GTMS - Carriers
  --                      This function calculate the freight charge amount per delivery
  --                      the amount need to be as in the commercial invoice
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   28/04/2015    Dalit A. Raviv  Initial Build
  ----------------------------------------------------------------------
  FUNCTION get_delivery_freight_charge(p_delivery_id IN NUMBER) RETURN NUMBER IS
  
    CURSOR get_charges_c IS
      SELECT DISTINCT wdd.source_line_id,
                      nvl(charge.operand, 0) adjusted_amount -- adjusted_amount
        FROM wsh_delivery_details     wdd,
             wsh_new_deliveries       wnd,
             wsh_delivery_assignments wda,
             oe_price_adjustments_v   charge
       WHERE wdd.delivery_detail_id = wda.delivery_detail_id
         AND wda.delivery_id = wnd.delivery_id
         AND wnd.delivery_id = p_delivery_id
         AND charge.list_line_type_code = 'FREIGHT_CHARGE'
         AND charge.applied_flag = 'Y'
         AND charge.header_id = wdd.source_header_id
         AND charge.line_id = wdd.source_line_id;
  
    l_charges NUMBER := 0;
  BEGIN
    --return oe_oe_totals_summary.charges(:source_header_id_chr);
    FOR get_charges_r IN get_charges_c LOOP
      l_charges := l_charges + get_charges_r.adjusted_amount;
    END LOOP;
  
    RETURN l_charges;
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_delivery_freight_charge;
  --------------------------------------------------------------------
  --  customization code: CHG0034230
  --  name:               get_delivery_total_amount
  --  create by:          Dalit A. Raviv
  --  creation date:      16/04/2015
  --  Purpose :           CHG0034736 GTMS - Carriers
  --                      This function need to be with the same population of the commercial invoice.
  --                      total delivery amount should be exact as in the commercial invoice.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   16/04/2015    Dalit A. Raviv  Initial Build
  ----------------------------------------------------------------------
  PROCEDURE get_delivery_total_amount(p_delivery_id      IN NUMBER,
                                      p_curr_code        OUT VARCHAR2,
                                      p_delivery_tot_amt OUT NUMBER) IS
  
    CURSOR c_pop IS
      SELECT wnd.delivery_id,
             nvl(wnd.currency_code, wdd.currency_code) currency_code,
             SUM(nvl(wdd.shipped_quantity, wdd.requested_quantity) * -- ship qty
                 xxwsh_delivery_info_pkg.get_line_unit_price(wdd.source_line_id) * -- unit_price
                 CASE
                   WHEN nvl(wnd.attribute8, h.attribute3) /*nvl(h.attribute3, 'Y')*/
                        = 'Y' THEN
                    (1 -
                    xxwsh_delivery_info_pkg.get_line_discount_percent(wdd.source_line_id,
                                                                       0)) -- discount
                   ELSE
                    1
                 END) total_delivery_amt
        FROM wsh_new_deliveries         wnd,
             wsh_delivery_assignments_v wda,
             wsh_delivery_details       wdd,
             oe_order_headers_all       h,
             mtl_categories             mc,
             mtl_item_categories        mic,
             mtl_default_category_sets  mdc,
             mtl_system_items_b         msi
       WHERE wnd.delivery_id = wda.delivery_id
         AND wdd.inventory_item_id = msi.inventory_item_id
         AND wdd.organization_id = msi.organization_id
         AND wdd.source_header_id = h.header_id(+)
         AND nvl(wnd.shipment_direction, 'O') IN ('O', 'IO')
         AND wnd.delivery_type = 'STANDARD'
         AND (wdd.requested_quantity > 0 OR wdd.released_status != 'D')
         AND wdd.container_flag = 'N'
         AND wdd.delivery_detail_id = wda.delivery_detail_id
         AND wda.delivery_id IS NOT NULL
         AND nvl(xxoe_utils_pkg.show_dis_get_line(wdd.source_line_id), 'Y') = 'Y'
         AND wdd.organization_id = mic.organization_id
         AND wdd.inventory_item_id = mic.inventory_item_id
         AND mic.category_id = mc.category_id
         AND mic.category_set_id = mdc.category_set_id
         AND mdc.functional_area_id = 7
         AND msi.item_type <>
             fnd_profile.value('XXAR PREPAYMENT ITEM TYPES')
         AND msi.segment1 NOT LIKE 'PREPAYMENT (-)'
         AND EXISTS (SELECT 'EXISTS'
                FROM bom_inventory_components bic
               WHERE bic.include_on_ship_docs = 1
                 AND bic.component_sequence_id =
                     (SELECT component_sequence_id
                        FROM oe_order_lines_all oel
                       WHERE oel.line_id = wdd.source_line_id)
              UNION
              SELECT 'EXISTS'
                FROM dual
               WHERE wdd.top_model_line_id IS NULL
              UNION
              SELECT 'EXISTS'
                FROM dual
               WHERE wdd.top_model_line_id IS NOT NULL
                 AND wdd.ato_line_id IS NOT NULL
              UNION
              SELECT 'EXISTS'
                FROM dual
               WHERE wdd.top_model_line_id = wdd.source_line_id)
            -- 24/03/2015 Dalit A. Raviv CHG0034230
            -- do not retrieve PTO model parent lines -> model line = N
            ---and    xxoe_utils_pkg.is_model_line(wdd.source_line_id) = 'N' -- PTO child(parent will return Y)
            -- change logic 06/07/2015 Dalit A. Raviv CHG0035672
         AND xxwsh_delivery_info_pkg.is_pto_parent(wdd.source_line_id) = 'N'
            -- do not retrieve a buy and get parent line
            --and    (xxoe_utils_pkg.is_bundle_line(wdd.source_line_id) = 'N' and xxwsh_delivery_info_pkg.show_parent_in_doc(wdd.source_line_id) = 'N')
         AND ((xxoe_utils_pkg.is_bundle_line(wdd.source_line_id) = 'Y' AND
             xxwsh_delivery_info_pkg.show_parent_in_doc(wdd.source_line_id) = 'Y') OR
             (xxoe_utils_pkg.is_bundle_line(wdd.source_line_id) = 'N'))
            -- retrieve only buy and get components (not the parent)
         AND ((xxoe_utils_pkg.is_comp_bundle_line(wdd.source_line_id) = 'Y' AND
             xxwsh_delivery_info_pkg.show_child_in_doc(wdd.source_line_id) = 'Y') OR
             (xxoe_utils_pkg.is_comp_bundle_line(wdd.source_line_id) = 'N'))
         AND wnd.delivery_id = p_delivery_id -- (1463597 ,1185622, 1336525)
      -- end CHG0034230
       GROUP BY wnd.delivery_id, nvl(wnd.currency_code, wdd.currency_code);
  
  BEGIN
    FOR r_pop IN c_pop LOOP
      p_curr_code        := r_pop.currency_code;
      p_delivery_tot_amt := r_pop.total_delivery_amt;
    END LOOP;
  
    --p_delivery_tot_amt := trunc(p_delivery_tot_amt,2);
    -- some commercial invoice do have amount for the friegth
    -- in this cat the total amount of the delivery is delivery amount + freight amount
    p_delivery_tot_amt := round(p_delivery_tot_amt +
                                get_delivery_freight_charge(p_delivery_id),
                                2);
  
  EXCEPTION
    WHEN OTHERS THEN
      p_curr_code        := NULL;
      p_delivery_tot_amt := 0;
  END get_delivery_total_amount;

  --------------------------------------------------------------------
  --  customization code: CHG0034230
  --  name:               get_collect_shipping_account
  --  create by:          Dalit A. Raviv
  --  creation date:      16/04/2015
  --  Purpose :           CHG0034736 GTMS - Carriers
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   16/04/2015    Dalit A. Raviv  Initial Build
  ----------------------------------------------------------------------
  FUNCTION get_collect_shipping_account(p_delivery_id IN NUMBER)
    RETURN VARCHAR2 IS
  
    CURSOR c_pop IS
      SELECT wdd.source_header_id, ooha.order_number, ooha.attribute5
        FROM wsh_delivery_details     wdd,
             wsh_delivery_assignments wda,
             oe_order_headers_all     ooha
       WHERE wda.delivery_detail_id = wdd.delivery_detail_id
         AND ooha.header_id = wdd.source_header_id
         AND ooha.attribute5 IS NOT NULL
         AND wda.delivery_id = p_delivery_id;
  
    l_ship_account VARCHAR2(240) := NULL;
  
  BEGIN
    -- CHG0035038 -  Packing List modifications
    FOR r_pop IN c_pop LOOP
      l_ship_account := r_pop.attribute5;
      EXIT;
    END LOOP;
  
    RETURN l_ship_account;
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_collect_shipping_account;

  --------------------------------------------------------------------
  --  customization code: CHG0035672 - Commercial Invoice Pricing and Discount change Logic
  --  name:               get_customs_price
  --  create by:          Dalit A. Raviv
  --  creation date:      18/06/2015
  --  Purpose :
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   18/06/2015    Dalit A. Raviv  Initial Build
  --  1.1   11-Nov-2015   Dalit A. Raviv  CHG0036697 - UOM modifications - take from delivery and not from SO line
  --  1.2  07-Jun-2017   Lingaraj(TCS)    CHG0040996 - Discrepancy of Warranty price on Commercial Invoice and Order
  --                                      inv_convert.inv_um_convert_new Parameter precision Value Changed from Null to 20
  ----------------------------------------------------------------------
  FUNCTION get_customs_price(p_line_id IN NUMBER) RETURN NUMBER IS
    -- return the list price
  
    l_price_list_id NUMBER := NULL;
    l_list_price    NUMBER := NULL;
    CURSOR c_line IS
      SELECT oola.unit_selling_price
        FROM oe_order_lines_all oola
       WHERE oola.line_id = p_line_id;
  BEGIN
    -- 1) Get Price List for Custom Price Function
    -- look at PRG if return no data bring the price list from the order line
    BEGIN
      SELECT oola.price_list_id
        INTO l_price_list_id
        FROM oe_price_adjustments    tcomp,
             ont.oe_price_adj_assocs opaa,
             oe_price_adjustments    tprnt,
             ont.oe_order_lines_all  oola
       WHERE tcomp.line_id = p_line_id
         AND tcomp.price_adjustment_id = opaa.rltd_price_adj_id
         AND tprnt.price_adjustment_id = opaa.price_adjustment_id
         AND tprnt.header_id = tcomp.header_id
         AND tprnt.line_id = oola.line_id
         AND tcomp.list_line_type_code = 'DIS'
         AND tprnt.list_line_type_code = 'PRG';
    EXCEPTION
      WHEN OTHERS THEN
        l_price_list_id := NULL;
    END;
  
    IF l_price_list_id IS NULL THEN
      BEGIN
        SELECT oola.price_list_id
          INTO l_price_list_id
          FROM ont.oe_order_lines_all oola
         WHERE oola.line_id = p_line_id;
      EXCEPTION
        WHEN OTHERS THEN
          l_price_list_id := NULL;
      END;
    END IF;
  
    -- 2 - Give Prices from the found price list, for the item
    -- go to price list table with the item from the line and get the price from there
    BEGIN
      SELECT nvl(MAX(inv_convert.inv_um_convert_new(oola.inventory_item_id,
                                                    20, --NULL,--Modified on 7JUN17 for CHG0040996, Parameter Value Change from Null to 20
                                                    pll.operand,
                                                    wdd.requested_quantity_uom, -- 11-Nov-2015 Dalit A. Raviv CHG0036697 --oola.order_quantity_uom,
                                                    patt.product_uom_code,
                                                    NULL,
                                                    NULL,
                                                    'U')),
                 0)
        INTO l_list_price
        FROM qp_list_lines         pll,
             qp_pricing_attributes patt,
             oe_order_lines_all    oola,
             wsh_delivery_details  wdd
       WHERE pll.list_header_id = l_price_list_id
         AND pll.list_line_id = patt.list_line_id
         AND patt.product_attr_value = to_char(oola.inventory_item_id)
         AND nvl(trunc(pll.end_date_active), trunc(SYSDATE + 1)) >=
             trunc(SYSDATE)
         AND oola.line_id = p_line_id
         AND wdd.source_line_id = oola.line_id;
    EXCEPTION
      WHEN OTHERS THEN
        l_list_price := 0;
    END;
    IF l_list_price = 0 THEN
      -- secondary price list
      SELECT nvl(MAX(inv_convert.inv_um_convert_new(ol.inventory_item_id,
                                                    20, --NULL,--Modified on 7JUN17 for CHG0040996, Parameter Value Change from Null to 20
                                                    qllv.operand,
                                                    wdd.requested_quantity_uom, -- 11-Nov-2015 Dalit A. Raviv CHG0036697 --ol.order_quantity_uom,
                                                    qllv.product_uom_code,
                                                    NULL,
                                                    NULL,
                                                    'U')),
                 0)
        INTO l_list_price
        FROM qp_secondary_price_lists_v qspl,
             qp_list_lines_v            qllv,
             ont.oe_order_lines_all     ol,
             wsh_delivery_details       wdd
       WHERE qspl.parent_price_list_id = to_char(l_price_list_id)
         AND qspl.list_header_id = qllv.list_header_id
         AND qllv.product_attr_value = to_char(ol.inventory_item_id)
         AND nvl(trunc(qllv.end_date_active), trunc(SYSDATE + 1)) >=
             trunc(SYSDATE)
         AND ol.line_id = p_line_id
         AND wdd.source_line_id = ol.line_id;
    END IF;
  
    IF l_list_price = 0 THEN
      FOR r_line IN c_line LOOP
        l_list_price := r_line.unit_selling_price;
      END LOOP;
    END IF;
  
    RETURN l_list_price;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 0;
  END get_customs_price;

  --------------------------------------------------------------------
  --  customization code: CHG0035672 - Commercial Invoice Pricing and Discount change Logic
  --  name:               get_price_list_distribution
  --  create by:          Dalit A. Raviv
  --  creation date:      18/06/2015
  --  Purpose :
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   18/06/2015    Dalit A. Raviv  Initial Build
  --  1.1   15-Nov-2015   Dalit A. Raviv  CHG0036697 return parent price
  ----------------------------------------------------------------------
  FUNCTION get_price_list_distribution(p_so_line_id IN NUMBER,
                                       p_entity     IN VARCHAR2)
    RETURN NUMBER IS
    l_header_id      NUMBER := NULL;
    l_new_item_price NUMBER := NULL;
  BEGIN
    -- get header id by the line id
    SELECT oola.header_id
      INTO l_header_id
      FROM oe_order_lines_all oola
     WHERE oola.line_id = p_so_line_id;
  
    IF p_entity = 'BUNDLE' THEN
      -- CHG0036697 15-Nov-2015 Dalit A. Raviv
      -- the new item price is the proportion of the item whitin its parent unit list price
      SELECT round(((parent_price * parent_qty) *
                   (ord_item_list_price /
                   (ordered_quantity * total_bundle))),
                   2) new_item_price -- Moni C. INC0054908
      /*,parent_price, Ord_Item_List_Price, total_bundle, line_id*/
        INTO l_new_item_price
        FROM ( -- this select sum the items prices per parent
              SELECT SUM(ord_item_list_price) over(PARTITION BY parent_line_id) total_bundle,
                      ord_item_list_price,
                      parent_price,
                      line_id,
                      ordered_quantity,
                      parent_qty
                FROM ( -- this select retrive the item and its parent
                       -- including their prices
                       SELECT oola2.line_id parent_line_id,
                               oola1.line_id line_id,
                               oola1.line_number,
                               oola1.ordered_item,
                               oola1.ordered_quantity,
                               oola1.unit_selling_price ord_item_sell_price,
                               oola2.ordered_item parent_item,
                               oola2.ordered_quantity parent_qty,
                               CASE
                                 WHEN oola2.unit_list_price = 0 THEN
                                  oola2.unit_selling_price
                                 ELSE
                                  oola2.unit_list_price
                               END parent_price,
                               (inv_convert.inv_um_convert_new(oola1.inventory_item_id,
                                                               0,
                                                               pll.operand,
                                                               oola1.order_quantity_uom,
                                                               patt.product_uom_code,
                                                               NULL,
                                                               NULL,
                                                               'U') *
                               oola1.ordered_quantity) ord_item_list_price
                         FROM ont.oe_price_adj_assocs opaa,
                               oe_price_adjustments    tcomp,
                               oe_price_adjustments    tprnt,
                               ont.oe_order_lines_all  oola1,
                               ont.oe_order_lines_all  oola2,
                               qp_list_lines           pll,
                               qp_pricing_attributes   patt
                        WHERE tcomp.line_id = oola1.line_id
                          AND tcomp.list_line_type_code = 'DIS'
                          AND tcomp.price_adjustment_id = opaa.rltd_price_adj_id
                          AND opaa.price_adjustment_id =
                              tprnt.price_adjustment_id
                          AND tprnt.list_line_type_code = 'PRG'
                          AND tprnt.line_id = oola2.line_id
                          AND pll.list_header_id = oola2.price_list_id
                          AND pll.list_line_id = patt.list_line_id
                          AND patt.product_attr_value =
                              to_char(oola1.inventory_item_id)
                          AND nvl(trunc(pll.end_date_active), trunc(SYSDATE + 1)) >=
                              trunc(SYSDATE)
                          AND oola1.header_id = l_header_id))
       WHERE line_id = p_so_line_id;
    
    ELSIF p_entity = 'PTO' THEN
      l_new_item_price := NULL;
      -- CHG0036697 15-Nov-2015 Dalit A. Raviv
      SELECT round(((parent_price * parent_qty) *
                   (ord_item_list_price / (ordered_quantity * total_pto))),
                   2) new_item_price -- Moni C. INC0054908
      /*,parent_price, Ord_Item_List_Price, total_pto, line_id*/
        INTO l_new_item_price
        FROM (SELECT order_number,
                     line_id,
                     line_number,
                     option_number,
                     ordered_item,
                     ord_item_sell_price,
                     parent_item,
                     parent_price,
                     ord_item_list_price,
                     ordered_quantity,
                     parent_qty,
                     SUM(ord_item_list_price) over(PARTITION BY parent_line_id) total_pto
                FROM (SELECT ooha.order_number,
                             oola1.line_id,
                             oola1.line_number,
                             oola1.option_number,
                             oola1.ordered_item,
                             oola1.ordered_quantity,
                             oola1.unit_selling_price ord_item_sell_price,
                             oola2.line_id parent_line_id,
                             oola2.ordered_item parent_item,
                             oola2.ordered_quantity parent_qty,
                             CASE
                               WHEN oola2.unit_list_price = 0 THEN
                                oola2.unit_selling_price
                               ELSE
                                oola2.unit_list_price
                             END parent_price,
                             ((CASE
                               WHEN apps.xxoe_utils_pkg.is_item_resin_credit(oola1.inventory_item_id) = 'Y' THEN
                                nvl(to_number(oola1.attribute4), 0)
                               ELSE
                                nvl(nvl((SELECT inv_convert.inv_um_convert_new(oola1.inventory_item_id,
                                                                              0,
                                                                              pll.operand,
                                                                              oola1.order_quantity_uom,
                                                                              patt.product_uom_code,
                                                                              NULL,
                                                                              NULL,
                                                                              'U')
                                          FROM qp_list_lines         pll,
                                               qp_pricing_attributes patt
                                         WHERE pll.list_line_id =
                                               patt.list_line_id
                                           AND to_char(oola1.inventory_item_id) =
                                               patt.product_attr_value
                                           AND nvl(trunc(pll.end_date_active),
                                                   trunc(SYSDATE + 1)) >=
                                               trunc(SYSDATE)
                                           AND pll.list_header_id =
                                               oola2.price_list_id),
                                        (SELECT inv_convert.inv_um_convert_new(oola1.inventory_item_id,
                                                                               0,
                                                                               pll.operand,
                                                                               oola1.order_quantity_uom,
                                                                               patt.product_uom_code,
                                                                               NULL,
                                                                               NULL,
                                                                               'U')
                                           FROM qp_secondary_price_lists_v qsplv,
                                                qp_list_lines              pll,
                                                qp_pricing_attributes      patt
                                          WHERE pll.list_line_id =
                                                patt.list_line_id
                                            AND to_char(oola1.inventory_item_id) =
                                                patt.product_attr_value
                                            AND nvl(trunc(pll.end_date_active),
                                                    trunc(SYSDATE + 1)) >=
                                                trunc(SYSDATE)
                                            AND pll.list_header_id =
                                                qsplv.list_header_id
                                            AND qsplv.parent_price_list_id =
                                                to_char(oola2.price_list_id))),
                                    0)
                             END) * oola1.ordered_quantity) ord_item_list_price
                        FROM ont.oe_order_lines_all   oola1,
                             ont.oe_order_headers_all ooha,
                             ont.oe_order_lines_all   oola2
                       WHERE oola1.top_model_line_id = oola2.line_id
                         AND oola1.line_id <> oola1.top_model_line_id
                         AND oola1.header_id = ooha.header_id
                         AND oola1.item_type_code <> 'CLASS' -- 06/07/2015
                         AND ooha.header_id = l_header_id))
       WHERE line_id = p_so_line_id;
    
    END IF;
    RETURN l_new_item_price;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 0;
  END get_price_list_distribution;

  --------------------------------------------------------------------
  --  customization code: CHG0035672 - Commercial Invoice Pricing and Discount change Logic
  --  name:               get_parent_line_id
  --  create by:          Dalit A. Raviv
  --  creation date:      18/06/2015
  --  Purpose :           get om line id and return parent line id
  --                      Applied only if the Item is a PTO Option or a Bundle Component.
  --                      p_entity - PTO/BUNDLE
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   18/06/2015    Dalit A. Raviv  Initial Build
  ----------------------------------------------------------------------
  FUNCTION get_parent_line_id(p_line_id IN NUMBER, p_entity IN VARCHAR2)
    RETURN NUMBER IS
  
    l_parent_line_id NUMBER;
  BEGIN
    -- PTO'S
    IF p_entity = 'PTO' THEN
      SELECT oola.top_model_line_id
        INTO l_parent_line_id
        FROM ont.oe_order_lines_all oola
       WHERE oola.line_id = p_line_id;
    ELSIF p_entity = 'BUNDLE' THEN
      -- Buy and Get Bundles
      SELECT tprnt.line_id
        INTO l_parent_line_id
        FROM oe_price_adjustments    tcomp,
             ont.oe_price_adj_assocs opaa,
             oe_price_adjustments    tprnt
       WHERE tcomp.line_id = p_line_id
         AND tprnt.price_adjustment_id = opaa.price_adjustment_id
         AND opaa.rltd_price_adj_id = tcomp.price_adjustment_id
         AND tprnt.header_id = tcomp.header_id
         AND tcomp.list_line_type_code = 'DIS'
         AND tprnt.list_line_type_code = 'PRG';
    END IF;
  
    RETURN l_parent_line_id;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_parent_line_id;

  --------------------------------------------------------------------
  --  customization code: CHG0035672 - Commercial Invoice Pricing and Discount change Logic
  --  name:               get_parent_line_price
  --  create by:          Dalit A. Raviv
  --  creation date:      23/06/2015
  --  Purpose :           get om line id and return parent line id price
  --                      Applied only if the Item is a PTO Option or a Bundle Component.
  --                      p_entity - PTO/BUNDLE
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   23/06/2015    Dalit A. Raviv  Initial Build
  ----------------------------------------------------------------------
  FUNCTION get_parent_line_price(p_line_id IN NUMBER, p_entity IN VARCHAR2)
    RETURN NUMBER IS
  
    l_price NUMBER;
  BEGIN
    SELECT CASE
             WHEN oola3.unit_list_price = 0 THEN
              oola3.unit_selling_price
             ELSE
              oola3.unit_list_price
           END price
      INTO l_price
      FROM ont.oe_order_lines_all oola3
     WHERE oola3.line_id =
           xxwsh_delivery_info_pkg.get_parent_line_id(p_line_id, p_entity);
  
    RETURN l_price;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 0;
  END get_parent_line_price;

  --------------------------------------------------------------------
  --  customization code: CHG0035672 - Commercial Invoice Pricing and Discount change Logic
  --  name:               is_pto_component
  --  create by:          Dalit A. Raviv
  --  creation date:      06/07/2015
  --  Purpose :           get om line id and return if item is a PTO component (but not option class)
  --                      return Y/N
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   23/06/2015    Dalit A. Raviv  Initial Build
  ----------------------------------------------------------------------
  FUNCTION is_pto_component(p_line_id IN NUMBER) RETURN VARCHAR2 IS
    l_return VARCHAR2(10) := 'N';
  BEGIN
    SELECT 'Y'
      INTO l_return
      FROM oe_order_lines_all oola
     WHERE oola.link_to_line_id IS NOT NULL
       AND oola.item_type_code <> 'CLASS'
       AND oola.line_id = p_line_id;
  
    RETURN l_return;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 'N';
  END is_pto_component;

  --------------------------------------------------------------------
  --  customization code: CHG0035672 - Commercial Invoice Pricing and Discount change Logic
  --  name:               is_pto_component
  --  create by:          Dalit A. Raviv
  --  creation date:      06/07/2015
  --  Purpose :           get om line id and return if item is a PTO parent
  --                      return Y/N
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   23/06/2015    Dalit A. Raviv  Initial Build
  ----------------------------------------------------------------------
  FUNCTION is_pto_parent(p_line_id IN NUMBER) RETURN VARCHAR2 IS
    l_return VARCHAR2(10) := 'N';
  BEGIN
    SELECT 'Y'
      INTO l_return
      FROM oe_order_lines_all oola
     WHERE oola.item_type_code IN ('MODEL', 'KIT')
       AND oola.line_id = oola.top_model_line_id
       AND oola.line_id = p_line_id;
  
    RETURN l_return;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 'N';
  END is_pto_parent;

  --------------------------------------------------------------------
  --  customization code: CHG0036018 - Commercial invoice modifications
  --  name:               get_country_of_origin
  --  create by:          Dalit A. Raviv
  --  creation date:      06-Sep-2015
  --  Purpose :           Change logic for the source of Country of Origion COO
  --                      Delivery Country of Origin COO is not null -> COO = Delivery COO
  --                      Delivery COO is null  -> is item lot control -> Y COO = lot COO (nvl to item COO)
  --                                            -> if item lot control -> N COO = Item COO
  --                      Delivery COO = wsh_delivery_details.attribute1
  --                      Lot COO      = mtl_lot_numbers.attribute1
  --                      Item COO     = mtl_system_items_b.attribute2
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   06-Sep-2015   Dalit A. Raviv  Initial Build
  ----------------------------------------------------------------------
  FUNCTION get_country_of_origin(p_wdd_coo           IN VARCHAR2,
                                 p_inventory_item_id IN NUMBER,
                                 p_organization_id   IN NUMBER,
                                 p_lot_number        IN VARCHAR2,
                                 p_msi_coo           IN VARCHAR2)
    RETURN VARCHAR2 IS
  
    l_country_of_origin VARCHAR2(80) := NULL;
    l_coo_code          VARCHAR2(150) := NULL;
    l_lot_control       VARCHAR2(100) := NULL;
  BEGIN
  
    IF p_wdd_coo IS NOT NULL THEN
    
      SELECT MAX(territory_short_name)
        INTO l_country_of_origin
        FROM fnd_territories_tl
       WHERE territory_code = p_wdd_coo
         AND LANGUAGE = userenv('LANG');
    ELSE
      BEGIN
        SELECT decode(nvl(msi.lot_control_code, 1), 2, 'Y', 'N') lot_control_code
          INTO l_lot_control
          FROM mtl_system_items_b msi
         WHERE inventory_item_id = p_inventory_item_id
           AND organization_id = p_organization_id;
      EXCEPTION
        WHEN OTHERS THEN
          l_lot_control := 'N';
      END;
    
      IF l_lot_control = 'Y' THEN
      
        SELECT nvl(MAX(attribute1), p_msi_coo)
          INTO l_coo_code
          FROM mtl_lot_numbers l
         WHERE l.inventory_item_id = p_inventory_item_id
           AND l.lot_number = p_lot_number
           AND l.organization_id = p_organization_id;
      
        SELECT MAX(territory_short_name)
          INTO l_country_of_origin
          FROM fnd_territories_tl
         WHERE territory_code = l_coo_code
           AND LANGUAGE = userenv('LANG');
      ELSE
        SELECT MAX(territory_short_name)
          INTO l_country_of_origin
          FROM fnd_territories_tl
         WHERE territory_code = p_msi_coo
           AND LANGUAGE = userenv('LANG');
      END IF;
    END IF; -- coo is not null
  
    RETURN l_country_of_origin;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_country_of_origin;

  --------------------------------------------------------------------
  --  customization code: CHG0046167 - Packing list report - logic to calculate chargeable weight
  --  name:               get_chargeable_weight
  --  create by:          Bellona(TCS)
  --  creation date:      25/09/2019
  --  Purpose :           calculate chargeable weight based on weight and length measurement
  --                      units.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   25/09/2019    Bellona(TCS)  Initial Build
  ----------------------------------------------------------------------
  FUNCTION get_chargeable_weight(p_weight_uom IN VARCHAR2,
                                 p_attribute2 IN VARCHAR2,
                                 p_attribute3 IN VARCHAR2,
                                 p_attribute4 IN VARCHAR2,
                                 p_attribute5 IN VARCHAR2,
                                 p_net_weight IN NUMBER,
                                 p_count      IN NUMBER) RETURN NUMBER IS
    l_return       NUMBER := 0;
    l_gross_weight NUMBER := 0;
  BEGIN
    IF p_weight_uom = 'LBS' and p_attribute5 = 'IN' THEN
      l_return := (p_attribute2 * p_attribute3 * p_attribute4) / 166;
    ELSIF p_weight_uom = 'KG' and p_attribute5 = 'CM' THEN
      l_return := (p_attribute2 * p_attribute3 * p_attribute4) / 6000;
    ELSIF p_weight_uom = 'KG' and p_attribute5 = 'IN' THEN
      l_return := (p_attribute2 * p_attribute3 * p_attribute4) / 366;
    END IF;
  
    l_gross_weight := p_net_weight / p_count;
  
    IF l_return > l_gross_weight THEN
      RETURN l_return;
    ELSE
      RETURN l_gross_weight;
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 0;
  END get_chargeable_weight;
  --------------------------------------------------------------------
  --  customization code: CHG0046167 - Packing list report - logic to calculate gross weight
  --  name:               get_gross_weight
  --  create by:          Bellona(TCS)
  --  creation date:      25/09/2019
  --  Purpose :           calculate gross weight, based on comparison with net weight
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   25/09/2019    Bellona(TCS)  Initial Build
  ----------------------------------------------------------------------
  FUNCTION get_gross_weight(p_net_weight   IN NUMBER,
                            p_gross_weight IN NUMBER) RETURN NUMBER IS
  BEGIN
  
    IF p_net_weight > p_gross_weight THEN
      RETURN p_net_weight;
    ELSE
      RETURN p_gross_weight;
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 0;
  END get_gross_weight;

END xxwsh_delivery_info_pkg;
/
