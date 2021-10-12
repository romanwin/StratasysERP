CREATE OR REPLACE PACKAGE BODY xxinv_item_classification AS
  --------------------------------------------------------------------
  --  name:               xxinv_item_classification
  --  create by:          yuval tal
  --  Revision:           1.0
  --  creation date:      31.3.11
  --------------------------------------------------------------------
  --  purpose:            general item_classifications methods
  ---------------------------------------------------------------------
  --  ver     date        name            desc
  --  1.0     31.3.11     yuval tal       initial build
  --  1.1     9.11.2011   yuval tal       add functions:
  --                                      get_last_trans_type_active, get_last_org_trans_active
  --                                      get_last_trans_qty_active, get_total_demand_by_item
  --  1.2     15.12.11                    change get_tatal_demand_by_item logic add
  --                                      AND dem.plan_id=msi.Plan_Id
  --  1.3     08.1.2012   yuval atl       get_last_rcv  : get price from po_line instead of rcv_trans
  --  1.4     06/02/2012  Dalit A. Raviv  new function is_contract_service_item
  --                                      check if item is SERVICE is_contract_service_item
  --  1.5     18.08.2013  Vitaly          CR 870 std cost - change hard-coded organization
  --  1.6     25.12.2013  Vitaly          cust 410 CR 1196 - add import_categories and upload categories
  --  1.7     27/03/2014  Dalit A. Raviv  add functions - is_item_POLYJET, is_item_FDM, is_item_RESIN, is_item_SP, is_item_FG
  --  1.8     03/12/2015  Gubendran K     Created new procedure upload_categories_pivot for the CR - CHG0033893
  --  1.9     01/06/2015  Michal Tzvik    CHG0035332 - update procedure upload_categories_pivot to support additional column of attachment
  --  1.10    30.04.17     yuval tal      CHG0040061 add is_system_item modify
  --                                                 is_item_fdm : add new parameter p_organization_id
  --                                                 is_item_polyjet :add new parameter p_organization_id
  --  1.11    01.03.18   Bellona(TCS)     CHG0042432 add new valueset in sql query of function is_system_item modify
  --                                      to handle multiple activity analysis.
  --  1.12    20.06.18   Ofer Suad        CHG0042761 remove Main Category Set
  --  2.0     05/07/2018 Roman W.         INC0125761 - create procedure calculate MTL_SYSTEM_ITEMS_B.item_type by ...
  --  2.1     02/06/2019 Roman W.         INC0158489 utl_file.fopen : increase max_linesize from default to 2500
  --                                              upload_categories_pivot
  --  2.2     15/12/2019 Roman W.         CHG0047007 - Support N Technologies
  --                                             1) get_item_technology
  --                                             2) get_item_speciality_flavor
  ---------------------------------------------------------------------------------------------------------------------------------------------
  FUNCTION get_category_by_set(p_organization_id   IN NUMBER,
                               p_inventory_item_id IN NUMBER,
                               p_category_set_id   IN NUMBER) RETURN VARCHAR2 IS
    v_result VARCHAR2(240);
  BEGIN
    SELECT mc.concatenated_segments categoty_description
      INTO v_result
      FROM mtl_item_categories ic, mtl_categories_b_kfv mc
     WHERE ic.inventory_item_id = p_inventory_item_id
       AND ic.organization_id = p_organization_id
       AND ic.category_id = mc.category_id
       AND ic.category_set_id = p_category_set_id;
    RETURN v_result;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_category_by_set;
  ---------------------------------------
  -- get_item_system_family
  --------------------------------------
  FUNCTION get_item_system_family(p_item_id NUMBER) RETURN VARCHAR2 AS
    CURSOR c IS
      SELECT t.cross_reference
        FROM mtl_cross_references_v t
       WHERE t.cross_reference_type = 'Bi Item type'
            -- AND t.organization_id = 91
         AND t.inventory_item_id = p_item_id;
    l_family VARCHAR2(500);
  BEGIN
    OPEN c;
    FETCH c
      INTO l_family;
    CLOSE c;
    RETURN l_family;
  END;
  -------------------------------------------------
  -- get_item_system_sub_family1
  ---------------------------------------------------
  FUNCTION get_item_system_sub_family1(p_item_id NUMBER) RETURN VARCHAR2 IS
    CURSOR c IS
      SELECT t.attribute3
        FROM mtl_cross_references_v t
       WHERE t.cross_reference_type = 'Bi Item type'
            --  AND t.organization_id = 91
         AND t.inventory_item_id = p_item_id;
    l_family VARCHAR2(500);
  BEGIN
    OPEN c;
    FETCH c
      INTO l_family;
    CLOSE c;
    RETURN l_family;
  END;
  -------------------------------------------------
  -- get_item_system_sub_family2
  ---------------------------------------------------
  FUNCTION get_item_system_sub_family2(p_item_id NUMBER) RETURN VARCHAR2 IS
    CURSOR c IS
      SELECT t.attribute4
        FROM mtl_cross_references_v t
       WHERE t.cross_reference_type = 'Bi Item type'
            --   AND t.organization_id = 91
         AND t.inventory_item_id = p_item_id;
    l_family VARCHAR2(500);
  BEGIN
    OPEN c;
    FETCH c
      INTO l_family;
    CLOSE c;
    RETURN l_family;
  END;
  ------------------------------------------------
  --  get_item_Preferred_vendor
  -----------------------------------------------
  FUNCTION get_item_preferred_vendor(p_item_id NUMBER) RETURN VARCHAR2 IS
    CURSOR c IS
      SELECT 'BIVI_' || vendor_id
        FROM (SELECT pv.vendor_id,
                     pv.vendor_name,
                     allocation_percent,
                     msib.inventory_item_id,
                     msib.segment1,
                     msib.description
                FROM mrp_sr_assignments      g,
                     mtl_system_items_b      msib,
                     mrp_sourcing_rules      msr,
                     mrp_sr_receipt_org      a,
                     mrp_sr_source_org       b,
                     ap_suppliers            pv,
                     inv_organization_info_v inv
               WHERE g.inventory_item_id = msib.inventory_item_id
                 AND msib.organization_id = g.organization_id
                 AND msib.planning_make_buy_code = 2
                 AND msr.sourcing_rule_id = g.sourcing_rule_id
                 AND a.sourcing_rule_id = msr.sourcing_rule_id
                 AND a.sr_receipt_id = b.sr_receipt_id
                 AND b.vendor_id = pv.vendor_id
                 AND g.organization_id = inv.organization_id
                 AND b.rank = 1
                 AND inv.organization_code = 'IPK' --'WPI'
              UNION
              SELECT pv.vendor_id,
                     pv.vendor_name,
                     allocation_percent,
                     msib.inventory_item_id,
                     msib.segment1,
                     msib.description
                FROM mrp_sr_assignments      g,
                     mtl_system_items_b      msib,
                     mrp_sourcing_rules      msr,
                     mrp_sr_receipt_org      a,
                     mrp_sr_source_org       b,
                     ap_suppliers            pv,
                     inv_organization_info_v inv
               WHERE g.inventory_item_id = msib.inventory_item_id
                 AND msib.organization_id = g.organization_id
                 AND msib.planning_make_buy_code = 2
                 AND msr.sourcing_rule_id = g.sourcing_rule_id
                 AND a.sourcing_rule_id = msr.sourcing_rule_id
                 AND a.sr_receipt_id = b.sr_receipt_id
                 AND b.vendor_id = pv.vendor_id
                 AND g.organization_id = inv.organization_id
                 AND b.rank = 1
                 AND inv.organization_code != 'IPK' --'WPI'
                 AND NOT EXISTS
               (SELECT 1
                        FROM (SELECT pv.vendor_id,
                                     pv.vendor_name,
                                     allocation_percent,
                                     msib.inventory_item_id,
                                     msib.segment1,
                                     msib.description
                                FROM mrp_sr_assignments      g,
                                     mtl_system_items_b      msib,
                                     mrp_sourcing_rules      msr,
                                     mrp_sr_receipt_org      a,
                                     mrp_sr_source_org       b,
                                     ap_suppliers            pv,
                                     inv_organization_info_v inv
                               WHERE g.inventory_item_id =
                                     msib.inventory_item_id
                                 AND msib.organization_id = g.organization_id
                                 AND msib.planning_make_buy_code = 2
                                 AND msr.sourcing_rule_id = g.sourcing_rule_id
                                 AND a.sourcing_rule_id = msr.sourcing_rule_id
                                 AND a.sr_receipt_id = b.sr_receipt_id
                                 AND b.vendor_id = pv.vendor_id
                                 AND g.organization_id = inv.organization_id
                                 AND b.rank = 1
                                 AND inv.organization_code = 'IPK' -- WPI
                              ) dd
                       WHERE dd.segment1 = msib.segment1))
       WHERE inventory_item_id = p_item_id;
    l_vendor VARCHAR2(50);
  BEGIN
    OPEN c;
    FETCH c
      INTO l_vendor;
    CLOSE c;
    RETURN l_vendor;
  END;
  -------------------------------------------------------
  --    get_item_id
  -------------------------------------------------------
  FUNCTION get_item_id(p_segment1 VARCHAR2) RETURN NUMBER IS
    l_tmp NUMBER;
  BEGIN
    SELECT t.inventory_item_id
      INTO l_tmp
      FROM mtl_system_items_b t
     WHERE t.organization_id = 91
       AND t.segment1 = p_segment1;
    RETURN l_tmp;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END;
  -----------------------------------------------------
  -- get_finish_good
  ------------------------------------------------------
  FUNCTION get_finish_good(p_item_id NUMBER) RETURN VARCHAR2 IS
    l_tmp VARCHAR2(1);
  BEGIN
    SELECT c.attribute7
      INTO l_tmp
      FROM mtl_item_categories t,
           mtl_categories_b    c,
           mtl_system_items_b  msib
     WHERE t.category_set_id = 1100000041
       AND t.organization_id = 91
       AND c.enabled_flag = 'Y'
       AND t.category_id = c.category_id
       AND t.organization_id = msib.organization_id
       AND t.inventory_item_id = msib.inventory_item_id
       AND msib.inventory_item_id = p_item_id;
    RETURN l_tmp;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 'N';
  END;
  ---------------------------------------------------------
  -- get product line
  -------------------------------------------------------
  FUNCTION get_product_line(p_code_combination_id NUMBER) RETURN VARCHAR2 IS
    l_tmp VARCHAR2(50);
  BEGIN
    SELECT v.description
      INTO l_tmp
      FROM gl_code_combinations c, fnd_flex_values_vl v
     WHERE c.code_combination_id = p_code_combination_id
       AND c.segment5 = v.flex_value
       AND v.flex_value_set_id = 1013893; --XXGL_PRODUCT_LINE_SEG
    RETURN l_tmp;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END;
  ----------------------------------------------
  -- is_spec_19
  ---------------------------------------------
  FUNCTION is_spec_19(p_item_id NUMBER) RETURN VARCHAR2 IS
    l_tmp NUMBER;
  BEGIN
    SELECT 1
      INTO l_tmp
      FROM mtl_system_items_b a, mtl_system_items_b_dfv b
     WHERE a.rowid = b.row_id
       AND b.spec19(+) = 'Service'
       AND rownum = 1
       AND a.inventory_item_id = p_item_id
       AND a.organization_id = 91;
    RETURN 'Y';
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 'N';
  END;
  ------------------------------
  --get concatenate by com
  ------------------------------
  FUNCTION get_concatenate_bom_by_part(p_item_id NUMBER) RETURN VARCHAR2 IS
    CURSOR get_pop_c IS
      SELECT DISTINCT t.comp_part_number,
                      t.comp_quantity_extended,
                      t.top_level_assembly_part_number,
                      xxinv_item_classification.is_spec_19(t.top_assembly_item_id)
        FROM xxinv_bom_explode_history t
       WHERE t.top_level_assembly_part_number NOT LIKE ('OBJ%-R')
         AND (t.top_level_assembly_part_number LIKE ('OBJ%') OR
             xxinv_item_classification.is_spec_19(t.top_assembly_item_id) = 'Y')
         AND t.comp_item_id = p_item_id
         AND t.creation_date =
             (SELECT MAX(mm.creation_date) FROM xxinv_bom_explode_history mm);
    l_flag   VARCHAR2(5) := 'Y';
    l_string VARCHAR2(2000) := NULL;
  BEGIN
    FOR get_pop_r IN get_pop_c LOOP
      IF get_pop_r.top_level_assembly_part_number LIKE ('OBJ%') THEN
        IF l_string IS NULL THEN
          l_string := get_pop_r.top_level_assembly_part_number;
        ELSE
          l_string := l_string || ', ' ||
                      get_pop_r.top_level_assembly_part_number;
        END IF;
      ELSE
        IF l_flag = 'Y' THEN
          IF l_string IS NULL THEN
            l_string := 'SERVICE';
          ELSE
            l_string := l_string || ', SERVICE';
          END IF;
          l_flag := 'N';
        END IF;
      END IF;
    END LOOP;
    RETURN l_string;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END;
  ------------------------------
  --get concatenate Family by com
  ------------------------------
  FUNCTION get_conc_bom_family_by_part(p_item_id NUMBER) RETURN VARCHAR2 IS
    CURSOR get_pop_c IS
      SELECT DISTINCT CASE
                        WHEN top_level_assembly_part_number NOT LIKE
                             ('OBJ%') THEN
                         'SERVICE'
                        ELSE
                         get_item_system_sub_family1(t.top_assembly_item_id)
                      END xx
        FROM xxinv_bom_explode_history t
       WHERE t.top_level_assembly_part_number NOT LIKE ('OBJ%-R')
         AND (t.top_level_assembly_part_number LIKE ('OBJ%') OR
             xxinv_item_classification.is_spec_19(t.top_assembly_item_id) = 'Y')
         AND t.comp_item_id = p_item_id
         AND t.creation_date =
             (SELECT MAX(mm.creation_date) FROM xxinv_bom_explode_history mm);
    l_string VARCHAR2(2000) := NULL;
  BEGIN
    FOR get_pop_r IN get_pop_c LOOP
      l_string := l_string || get_pop_r.xx || ' ,';
    END LOOP;
    RETURN rtrim(l_string, ',');
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END;
  ------------------------------
  --  get CHM WIEGHT
  -----------------------------
  FUNCTION get_chm_pack_of(p_item_id NUMBER) RETURN NUMBER IS
    l_tmp NUMBER;
    CURSOR c IS
      SELECT mdev_pack_of.element_value
        FROM mtl_descr_element_values_v mdev_pack_of
       WHERE mdev_pack_of.inventory_item_id = p_item_id
         AND mdev_pack_of.item_catalog_group_id = 2
         AND mdev_pack_of.element_name = 'pack of';
  BEGIN
    OPEN c;
    FETCH c
      INTO l_tmp;
    CLOSE c;
    RETURN l_tmp;
  END;
  ----------------------------------------
  -- get Resin net weight
  -----------------------------------------
  FUNCTION get_chm_weight(p_item_id NUMBER) RETURN NUMBER IS
    l_tmp NUMBER;
    CURSOR c IS
      SELECT element_value
        FROM mtl_descr_element_values_v mdev
       WHERE mdev.inventory_item_id = p_item_id
         AND mdev.item_catalog_group_id = 2
         AND mdev.element_name = 'Resin net weight';
  BEGIN
    OPEN c;
    FETCH c
      INTO l_tmp;
    CLOSE c;
    RETURN l_tmp;
  END;
  --------------------------------------
  -- get
  --------------------------------------
  FUNCTION get_item_category_obj(p_item_id NUMBER) RETURN VARCHAR2 IS
  BEGIN
    RETURN CASE WHEN xxinv_item_classification.get_item_system_family(p_item_id) = 'Head' THEN 'Heads' WHEN xxinv_item_classification.get_product_line(p_item_id) = 'Spare Parts' THEN 'SP' WHEN xxoe_utils_pkg.is_item_resin(p_item_id) = 'Y' THEN 'Resin' ELSE 'System' END;
  END;
  ---------------------------------------------
  --get_last_rcv_po_price
  ----------------------------------------------
  FUNCTION get_last_rcv_po_price(p_item_id NUMBER, p_date DATE) RETURN NUMBER IS
    l_price NUMBER;
  BEGIN
    SELECT gl_currency_api.convert_closest_amount_sql(nvl(ind.currency_code,
                                                          poh.currency_code),
                                                      'USD',
                                                      nvl(ind.base_date,
                                                          rcv.transaction_date),
                                                      'Corporate',
                                                      NULL,
                                                      l.unit_price /
                                                      decode(ind.base_rate,
                                                             0,
                                                             1,
                                                             NULL,
                                                             1,
                                                             ind.base_rate),
                                                      7)
      INTO l_price
      FROM rcv_transactions         rcv,
           po_headers_all           poh,
           clef062_po_index_esc_set ind,
           po_lines_all             l
     WHERE l.po_line_id = rcv.po_line_id
       AND poh.po_header_id = rcv.po_header_id
       AND poh.segment1 = ind.document_id(+)
       AND ind.module(+) = 'PO'
       AND rcv.transaction_id =
           nvl((SELECT MAX(t.transaction_id)
                 FROM rcv_transactions   t,
                      rcv_shipment_lines s,
                      po_lines_all       l
                WHERE l.po_line_id = t.po_line_id
                  AND nvl(l.cancel_flag, 'N') = 'N'
                  AND s.shipment_line_id = t.shipment_line_id
                  AND s.item_id = p_item_id
                  AND transaction_type = 'DELIVER'
                  AND transaction_date < p_date),
               (SELECT MIN(t.transaction_id)
                  FROM rcv_transactions   t,
                       rcv_shipment_lines s,
                       po_lines_all       l
                 WHERE s.shipment_line_id = t.shipment_line_id
                   AND l.po_line_id = t.po_line_id
                   AND nvl(l.cancel_flag, 'N') = 'N'
                   AND s.item_id = p_item_id
                   AND transaction_type = 'DELIVER'
                   AND transaction_date >= p_date));
    RETURN l_price;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_last_rcv_po_price;
  ------------------------------------
  -- get_last_rcv_po_price
  ------------------------------------
  PROCEDURE get_last_rcv_po_price(p_item_id         NUMBER,
                                  p_date            DATE,
                                  p_orig_currency   OUT VARCHAR2,
                                  p_orig_unit_price OUT NUMBER,
                                  p_unit_price_usd  OUT NUMBER) IS
  BEGIN
    SELECT gl_currency_api.convert_closest_amount_sql(nvl(ind.currency_code,
                                                          poh.currency_code),
                                                      'USD',
                                                      nvl(ind.base_date,
                                                          rcv.transaction_date),
                                                      'Corporate',
                                                      NULL,
                                                      l.unit_price /
                                                      decode(ind.base_rate,
                                                             0,
                                                             1,
                                                             NULL,
                                                             1,
                                                             ind.base_rate),
                                                      7),
           nvl(ind.currency_code, poh.currency_code),
           rcv.po_unit_price /
           decode(ind.base_rate, 0, 1, NULL, 1, ind.base_rate)
      INTO p_unit_price_usd, p_orig_currency, p_orig_unit_price
      FROM rcv_transactions         rcv,
           po_headers_all           poh,
           clef062_po_index_esc_set ind,
           po_lines_all             l
     WHERE l.po_line_id = rcv.po_line_id
       AND poh.po_header_id = rcv.po_header_id
       AND poh.segment1 = ind.document_id(+)
       AND ind.module(+) = 'PO'
       AND rcv.transaction_id =
           nvl((SELECT MAX(t.transaction_id)
                 FROM rcv_transactions   t,
                      rcv_shipment_lines s,
                      po_lines_all       l
                WHERE l.po_line_id = t.po_line_id
                  AND nvl(l.cancel_flag, 'N') = 'N'
                  AND s.shipment_line_id = t.shipment_line_id
                  AND s.item_id = p_item_id
                  AND transaction_type = 'DELIVER'
                  AND transaction_date < p_date),
               (SELECT MIN(t.transaction_id)
                  FROM rcv_transactions   t,
                       rcv_shipment_lines s,
                       po_lines_all       l
                 WHERE s.shipment_line_id = t.shipment_line_id
                   AND l.po_line_id = t.po_line_id
                   AND nvl(l.cancel_flag, 'N') = 'N'
                   AND s.item_id = p_item_id
                   AND transaction_type = 'DELIVER'
                   AND transaction_date >= p_date));
  EXCEPTION
    WHEN OTHERS THEN
      p_unit_price_usd  := NULL;
      p_orig_currency   := NULL;
      p_orig_unit_price := NULL;
  END;
  ---------------------------------------
  --- get_last_org_trans_active
  -----------------------------------------
  FUNCTION get_last_trans_type_active(p_inventory_item_id NUMBER)
    RETURN VARCHAR2 IS
    l_tmp VARCHAR2(50);
  BEGIN
    SELECT mtt.transaction_type_name
      INTO l_tmp
      FROM mtl_material_transactions mmt,
           mtl_transaction_types     mtt,
           mtl_secondary_inventories ms
     WHERE mmt.transaction_type_id = mtt.transaction_type_id
       AND mtt.transaction_type_id IN (18, 33, 35, 44)
       AND mmt.inventory_item_id = p_inventory_item_id --??
       AND mmt.subinventory_code = ms.secondary_inventory_name
       AND ms.organization_id = mmt.organization_id
       AND ms.asset_inventory = 1
       AND mmt.transaction_date =
           (SELECT MAX(mmt.transaction_date)
              FROM mtl_material_transactions mmt,
                   mtl_transaction_types     mtt,
                   mtl_secondary_inventories ms
             WHERE mmt.transaction_type_id = mtt.transaction_type_id
               AND mtt.transaction_type_id IN (18, 33, 35, 44)
               AND mmt.subinventory_code = ms.secondary_inventory_name
               AND ms.organization_id = mmt.organization_id
               AND ms.asset_inventory = 1
               AND mmt.inventory_item_id = p_inventory_item_id) --??)
       AND rownum = 1;
    RETURN l_tmp;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END;
  ---------------------------------------
  --- get last organization transaction active
  -----------------------------------------
  FUNCTION get_last_org_trans_active(p_inventory_item_id NUMBER)
    RETURN VARCHAR2 IS
    l_tmp VARCHAR2(3);
  BEGIN
    SELECT mtp.organization_code
      INTO l_tmp
      FROM mtl_material_transactions mmt,
           mtl_transaction_types     mtt,
           mtl_secondary_inventories ms,
           mtl_parameters            mtp
     WHERE mmt.transaction_type_id = mtt.transaction_type_id
       AND mtt.transaction_type_id IN (18, 33, 35, 44)
       AND mmt.inventory_item_id = p_inventory_item_id --??
       AND mmt.subinventory_code = ms.secondary_inventory_name
       AND ms.organization_id = mmt.organization_id
       AND ms.asset_inventory = 1
       AND mtp.organization_id = mmt.organization_id
       AND mmt.transaction_date =
           (SELECT MAX(mmt.transaction_date)
              FROM mtl_material_transactions mmt,
                   mtl_transaction_types     mtt,
                   mtl_secondary_inventories ms
             WHERE mmt.transaction_type_id = mtt.transaction_type_id
               AND mtt.transaction_type_id IN (18, 33, 35, 44)
               AND mmt.subinventory_code = ms.secondary_inventory_name
               AND ms.organization_id = mmt.organization_id
               AND ms.asset_inventory = 1
               AND mmt.inventory_item_id = p_inventory_item_id) --??)
       AND rownum = 1;
    RETURN l_tmp;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END;
  ------------------------------------------------
  -- get last transaction qty active
  ------------------------------------------------
  FUNCTION get_last_trans_qty_active(p_inventory_item_id NUMBER)
    RETURN NUMBER IS
    l_tmp NUMBER;
  BEGIN
    --- get last transaction qty active
    SELECT mmt.transaction_quantity
      INTO l_tmp
      FROM mtl_material_transactions mmt,
           mtl_transaction_types     mtt,
           mtl_secondary_inventories ms,
           mtl_parameters            mtp
     WHERE mmt.transaction_type_id = mtt.transaction_type_id
       AND mtt.transaction_type_id IN (18, 33, 35, 44)
       AND mmt.inventory_item_id = p_inventory_item_id --??
       AND mmt.subinventory_code = ms.secondary_inventory_name
       AND ms.organization_id = mmt.organization_id
       AND ms.asset_inventory = 1
       AND mtp.organization_id = mmt.organization_id
       AND mmt.transaction_date =
           (SELECT MAX(mmt.transaction_date)
              FROM mtl_material_transactions mmt,
                   mtl_transaction_types     mtt,
                   mtl_secondary_inventories ms
             WHERE mmt.transaction_type_id = mtt.transaction_type_id
               AND mtt.transaction_type_id IN (18, 33, 35, 44)
               AND mmt.subinventory_code = ms.secondary_inventory_name
               AND ms.organization_id = mmt.organization_id
               AND ms.asset_inventory = 1
               AND mmt.inventory_item_id = p_inventory_item_id) --??)
       AND rownum = 1;
    RETURN l_tmp;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END;
  ---------------------------------------------
  -- GET_TOTAL_DEMAND_BY_ITEM
  ---------------------------------------------
  FUNCTION get_total_demand_by_item(p_inventory_item_code VARCHAR2)
    RETURN NUMBER IS
    l_tmp NUMBER;
  BEGIN
    SELECT SUM(dem.using_requirement_quantity)
      INTO l_tmp
      FROM msc_demands dem, msc_system_items msi
     WHERE dem.plan_id = 3
       AND dem.plan_id = msi.plan_id
       AND msi.inventory_item_id = dem.inventory_item_id
       AND dem.organization_id = msi.organization_id
       AND msi.item_name = p_inventory_item_code --??
     HAVING SUM(dem.using_requirement_quantity) > 0;
    RETURN l_tmp;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END;
  --------------------------------------------------------------------
  --  name:            is_contract_service_item
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   06/02/2012
  --------------------------------------------------------------------
  --  purpose :        check if item is SERVICE is_contract_service_item 06/02/2012
  --                   Return Y / N
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  06/02/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION is_contract_service_item(p_inventory_item_id NUMBER)
    RETURN VARCHAR2 IS
    l_exist VARCHAR2(2) := NULL;
  BEGIN
    SELECT 'Y'
      INTO l_exist
      FROM mtl_system_items_b msib
     WHERE msib.inventory_item_id = p_inventory_item_id
       AND msib.contract_item_type_code = 'SERVICE'
       AND msib.organization_id = 91;
    RETURN l_exist;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 'N';
  END is_contract_service_item;
  --------------------------------------------------------------------
  -- import_categories
  -- CUST410 - Item Classification\CR1196 - Upload Item Categories
  -------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -----------------------------
  --     1.0  22.12.13    Vitaly         initial build
  --     1.0  03.18.15    Yuval          CHG0033893 - Added p_mode parameter to support single/multiple category assignmet logic
  --------------------------------------------------------------------
  PROCEDURE import_categories(errbuf                         OUT VARCHAR2,
                              retcode                        OUT VARCHAR2,
                              p_request_id                   IN NUMBER,
                              p_create_new_combinations_flag IN VARCHAR2,
                              p_mode                         IN VARCHAR2 DEFAULT 'SINGLE') IS
    --CHG0033893 - p_mode parameter added to support single/multiple category assigment logic
    CURSOR c_get_data IS
      SELECT data_tab.trx_id,
             data_tab.organization_code,
             data_tab.organization_id,
             data_tab.structure_id,
             data_tab.structure_name,
             data_tab.category_set_id,
             data_tab.category_set_name,
             mc.category_id,
             data_tab.item_code,
             msi.inventory_item_id,
             data_tab.segment1,
             data_tab.segment2,
             data_tab.segment3,
             data_tab.segment4,
             data_tab.segment5,
             data_tab.segment6,
             data_tab.segment7,
             data_tab.segment8,
             data_tab.segment9,
             data_tab.segment10,
             data_tab.segment11,
             data_tab.segment12,
             data_tab.segment13,
             data_tab.segment14,
             data_tab.segment15,
             data_tab.segment16,
             data_tab.segment17,
             data_tab.segment18,
             data_tab.segment19,
             data_tab.segment20,
             data_tab.concatenated_segments
        FROM mtl_system_items_b msi,
             mtl_categories_kfv mc,
             (SELECT c.trx_id,
                     c.organization_code,
                     mp.organization_id,
                     mcs.structure_id,
                     mcs.structure_name,
                     mcs.category_set_id,
                     c.category_set_name,
                     c.item_code,
                     c.segment1,
                     c.segment2,
                     c.segment3,
                     c.segment4,
                     c.segment5,
                     c.segment6,
                     c.segment7,
                     c.segment8,
                     c.segment9,
                     c.segment10,
                     c.segment11,
                     c.segment12,
                     c.segment13,
                     c.segment14,
                     c.segment15,
                     c.segment16,
                     c.segment17,
                     c.segment18,
                     c.segment19,
                     c.segment20,
                     nvl(c.concatenated_segments, 'MISSING') concatenated_segments
                FROM (SELECT nvl(cc.organization_code, 'MISSING') organization_code,
                             nvl(cc.category_set_name, 'MISSING') category_set_name,
                             nvl(cc.item_code, 'MISSING') item_code,
                             cc.trx_id,
                             cc.segment1,
                             cc.segment2,
                             cc.segment3,
                             cc.segment4,
                             cc.segment5,
                             cc.segment6,
                             cc.segment7,
                             cc.segment8,
                             cc.segment9,
                             cc.segment10,
                             cc.segment11,
                             cc.segment12,
                             cc.segment13,
                             cc.segment14,
                             cc.segment15,
                             cc.segment16,
                             cc.segment17,
                             cc.segment18,
                             cc.segment19,
                             cc.segment20,
                             REPLACE(rtrim(cc.segment1 || '|' || cc.segment2 || '|' ||
                                           cc.segment3 || '|' || cc.segment4 || '|' ||
                                           cc.segment5 || '|' || cc.segment6 || '|' ||
                                           cc.segment7 || '|' || cc.segment8 || '|' ||
                                           cc.segment9 || '|' || cc.segment10 || '|' ||
                                           cc.segment11 || '|' ||
                                           cc.segment12 || '|' ||
                                           cc.segment13 || '|' ||
                                           cc.segment14 || '|' ||
                                           cc.segment15 || '|' ||
                                           cc.segment16 || '|' ||
                                           cc.segment17 || '|' ||
                                           cc.segment18 || '|' ||
                                           cc.segment19 || '|' ||
                                           cc.segment20,
                                           '|'),
                                     '|',
                                     '.') concatenated_segments
                        FROM xxobjt_conv_category cc
                       WHERE cc.request_id = p_request_id
                         AND cc.trans_to_int_code = 'N') c,
                     mtl_parameters mp,
                     mtl_category_sets_v mcs
               WHERE c.organization_code = mp.organization_code(+)
                 AND c.category_set_name = mcs.category_set_name(+)) data_tab
       WHERE nvl(data_tab.organization_id, -777) = msi.organization_id(+)
         AND data_tab.item_code = msi.segment1(+)
         AND nvl(data_tab.structure_id, -777) = mc.structure_id(+)
         AND data_tab.concatenated_segments = mc.concatenated_segments(+);
    CURSOR c_get_value_sets_for_segments(p_structure_id NUMBER) IS
    ---XXINV_LINE_OF_BUSINESS,XXINV_PRODUCT_LINE,XXINV_PRODUCT_FAMILY,XXINV_SUB_FAMILY,
    -- XXINV_SPECIALTY/FLAVOR,XXINV_TECHNOLOGY,XXINV_ITEM_TYPE
      SELECT id_flex_num            structure_id,
             s.flex_value_set_id,
             vs.flex_value_set_name,
             s.segment_num, -- 10,20,30,40,50,60,70
             rownum                 segment_number -- 1,2,3,4,5,6,7
        FROM fnd_id_flex_segments s, fnd_flex_value_sets vs
       WHERE s.application_id = 401
         AND s.id_flex_code = 'MCAT'
         AND s.id_flex_num = p_structure_id --50449
         AND s.enabled_flag = 'Y'
         AND s.flex_value_set_id = vs.flex_value_set_id
       ORDER BY s.segment_num;
    v_step VARCHAR2(100);
    stop_processing EXCEPTION;
    l_return_status                VARCHAR2(1);
    l_error_code                   NUMBER;
    l_msg_count                    NUMBER;
    l_msg_data                     VARCHAR2(500);
    l_msg_index_out                NUMBER;
    t_category_rec                 inv_item_category_pub.category_rec_type;
    t_new_category_rec             inv_item_category_pub.category_rec_type;
    l_error_tbl                    inv_item_grp.error_tbl_type;
    v_error_message                VARCHAR2(3000);
    v_def_category_id              NUMBER;
    v_new_category_id              NUMBER;
    v_creation_categories_failured NUMBER := 0;
    v_creation_categories_success  NUMBER := 0;
    v_upd_category_assign_failured NUMBER := 0;
    v_upd_category_assign_success  NUMBER := 0;
    v_cre_category_assign_failured NUMBER := 0;
    v_cre_category_assign_success  NUMBER := 0;
    v_invalid_records_counter      NUMBER := 0;
    invalid_record EXCEPTION;
    v_value_set_desc VARCHAR2(300);
    v_segment_value  VARCHAR2(300);
    l_is_value_exist VARCHAR2(1);
  BEGIN
    v_step  := 'Step 0';
    errbuf  := 'Success';
    retcode := '0';
    FOR data_rec IN c_get_data LOOP
      -- LOOP
      BEGIN
        v_error_message   := NULL;
        v_new_category_id := NULL;
        v_segment_value   := NULL;
        v_step            := 'Step 100';
        -- Validations --
        IF data_rec.organization_code = 'MISSING' THEN
          v_error_message := 'Missing organization code';
          RAISE invalid_record;
        END IF;
        IF data_rec.organization_id IS NULL THEN
          v_error_message := 'Invalid organization code ''' ||
                             data_rec.organization_code || '''';
          RAISE invalid_record;
        END IF;
        IF data_rec.item_code = 'MISSING' THEN
          v_error_message := 'Missing item code';
          RAISE invalid_record;
        END IF;
        IF data_rec.inventory_item_id IS NULL THEN
          v_error_message := 'Item not exists/Item does not assign to organization';
          RAISE invalid_record;
        END IF;
        IF data_rec.category_set_name = 'MISSING' THEN
          v_error_message := 'Missing category set';
          RAISE invalid_record;
        END IF;
        IF data_rec.structure_id IS NULL THEN
          v_error_message := 'Invalid category set name';
          RAISE invalid_record;
        END IF;
        -- validate segments according to value set
        FOR value_set_rec IN c_get_value_sets_for_segments(data_rec.structure_id) LOOP
          IF value_set_rec.segment_number = 1 THEN
            v_segment_value := data_rec.segment1;
          ELSIF value_set_rec.segment_number = 2 THEN
            v_segment_value := data_rec.segment2;
          ELSIF value_set_rec.segment_number = 3 THEN
            v_segment_value := data_rec.segment3;
          ELSIF value_set_rec.segment_number = 4 THEN
            v_segment_value := data_rec.segment4;
          ELSIF value_set_rec.segment_number = 5 THEN
            v_segment_value := data_rec.segment5;
          ELSIF value_set_rec.segment_number = 6 THEN
            v_segment_value := data_rec.segment6;
          ELSIF value_set_rec.segment_number = 7 THEN
            v_segment_value := data_rec.segment7;
          ELSIF value_set_rec.segment_number = 8 THEN
            v_segment_value := data_rec.segment8;
          ELSIF value_set_rec.segment_number = 9 THEN
            v_segment_value := data_rec.segment9;
          ELSIF value_set_rec.segment_number = 10 THEN
            v_segment_value := data_rec.segment10;
          ELSIF value_set_rec.segment_number = 11 THEN
            v_segment_value := data_rec.segment11;
          ELSIF value_set_rec.segment_number = 12 THEN
            v_segment_value := data_rec.segment12;
          ELSIF value_set_rec.segment_number = 13 THEN
            v_segment_value := data_rec.segment13;
          ELSIF value_set_rec.segment_number = 14 THEN
            v_segment_value := data_rec.segment14;
          ELSIF value_set_rec.segment_number = 15 THEN
            v_segment_value := data_rec.segment15;
          ELSIF value_set_rec.segment_number = 16 THEN
            v_segment_value := data_rec.segment16;
          ELSIF value_set_rec.segment_number = 17 THEN
            v_segment_value := data_rec.segment17;
          ELSIF value_set_rec.segment_number = 18 THEN
            v_segment_value := data_rec.segment18;
          ELSIF value_set_rec.segment_number = 19 THEN
            v_segment_value := data_rec.segment19;
          ELSIF value_set_rec.segment_number = 20 THEN
            v_segment_value := data_rec.segment20;
          END IF;
          IF v_segment_value IS NULL THEN
            v_error_message := 'Missing value for segment' ||
                               value_set_rec.segment_number ||
                               ' for structure ' || data_rec.structure_name ||
                               ',  value set ' ||
                               value_set_rec.flex_value_set_name;
            RAISE invalid_record;
          END IF;
          /* v_value_set_desc := xxobjt_general_utils_pkg.get_valueset_desc(p_set_code => value_set_rec.flex_value_set_name,
          p_code     => v_segment_value);*/
          BEGIN
            SELECT 'Y'
              INTO l_is_value_exist
              FROM fnd_flex_values_vl p, fnd_flex_value_sets vs
             WHERE flex_value = v_segment_value
               AND p.flex_value_set_id = vs.flex_value_set_id
               AND vs.flex_value_set_name =
                   value_set_rec.flex_value_set_name
               AND nvl(p.enabled_flag, 'N') = 'Y';
          EXCEPTION
            WHEN no_data_found THEN
              -- IF v_value_set_desc IS NULL THEN
              v_error_message := 'Invalid value ''' || v_segment_value ||
                                 ''' in Seqment' ||
                                 value_set_rec.segment_number ||
                                 ' (Value not exists in value set ' ||
                                 value_set_rec.flex_value_set_name || ')';
              RAISE invalid_record;
              -- END IF;
          END;
        END LOOP;
        -- check category exists in case of flag p_create_new_combinations_flag='N'
        -- else create new category
        IF nvl(p_create_new_combinations_flag, 'N') = 'N' AND
           data_rec.category_id IS NULL THEN
          v_error_message := 'Invalid segments combination -- category does not exist';
          RAISE invalid_record;
        END IF;
        -- create new category
        IF data_rec.category_id IS NULL AND
           nvl(p_create_new_combinations_flag, 'N') = 'Y' THEN
          -------
          BEGIN
            v_step := 'Step 200';
            SELECT mc.category_id
              INTO v_new_category_id
              FROM mtl_categories_kfv mc
             WHERE mc.structure_id = data_rec.structure_id
               AND mc.concatenated_segments =
                   data_rec.concatenated_segments;
            -- this segments cobmibation already exists (category already exists)
          EXCEPTION
            WHEN no_data_found THEN
              v_step := 'Step 200.2';
              -- this segments cobmibation does not exist
              -- Create new category
              t_category_rec              := t_new_category_rec;
              t_category_rec.structure_id := data_rec.structure_id;
              t_category_rec.segment1     := data_rec.segment1;
              t_category_rec.segment2     := data_rec.segment2;
              t_category_rec.segment3     := data_rec.segment3;
              t_category_rec.segment4     := data_rec.segment4;
              t_category_rec.segment5     := data_rec.segment5;
              t_category_rec.segment6     := data_rec.segment6;
              t_category_rec.segment7     := data_rec.segment7;
              t_category_rec.segment8     := data_rec.segment8;
              t_category_rec.segment9     := data_rec.segment9;
              t_category_rec.segment10    := data_rec.segment10;
              t_category_rec.segment11    := data_rec.segment11;
              t_category_rec.segment12    := data_rec.segment12;
              t_category_rec.segment13    := data_rec.segment13;
              t_category_rec.segment14    := data_rec.segment14;
              t_category_rec.segment15    := data_rec.segment15;
              t_category_rec.segment16    := data_rec.segment16;
              t_category_rec.segment17    := data_rec.segment17;
              t_category_rec.segment18    := data_rec.segment18;
              t_category_rec.segment19    := data_rec.segment19;
              t_category_rec.segment20    := data_rec.segment20;
              t_category_rec.enabled_flag := 'Y';
              inv_item_category_pub.create_category(p_api_version   => '1.0',
                                                    p_init_msg_list => fnd_api.g_true,
                                                    p_commit        => fnd_api.g_false,
                                                    x_return_status => l_return_status,
                                                    x_errorcode     => l_error_code,
                                                    x_msg_count     => l_msg_count,
                                                    x_msg_data      => l_msg_data,
                                                    p_category_rec  => t_category_rec,
                                                    x_category_id   => v_new_category_id);
              IF l_return_status = fnd_api.g_ret_sts_success THEN
                -- New category was created successfuly
                COMMIT;
                v_creation_categories_success := v_creation_categories_success + 1;
              ELSE
                -- New Category creation API ERROR
                ROLLBACK;
                FOR i IN 1 .. l_msg_count LOOP
                  fnd_msg_pub.get(p_msg_index     => i,
                                  p_encoded       => fnd_api.g_false,
                                  p_data          => l_msg_data,
                                  p_msg_index_out => l_msg_index_out);
                  IF v_error_message IS NULL THEN
                    v_error_message := substr(l_msg_data, 1, 250);
                  ELSE
                    v_error_message := v_error_message || ' /' ||
                                       substr(l_msg_data, 1, 250);
                  END IF;
                END LOOP;
                v_error_message                := 'Category creation API ERROR: ' ||
                                                  v_error_message;
                v_creation_categories_failured := v_creation_categories_failured + 1;
                RAISE invalid_record;
              END IF;
              v_step := 'Step 300';
              -- Create Valid Category
              inv_item_category_pub.create_valid_category(p_api_version        => '1.0',
                                                          p_init_msg_list      => fnd_api.g_true,
                                                          p_commit             => fnd_api.g_true,
                                                          p_category_id        => v_new_category_id,
                                                          p_category_set_id    => data_rec.category_set_id,
                                                          p_parent_category_id => NULL,
                                                          x_return_status      => l_return_status,
                                                          x_errorcode          => l_error_code,
                                                          x_msg_count          => l_msg_count,
                                                          x_msg_data           => l_msg_data);
              IF l_return_status = 'S' THEN
                -- Valid Category was created successfuly
                NULL;
              ELSE
                -- Valid Category creation Error
                FOR i IN 1 .. l_error_tbl.count LOOP
                  v_error_message := v_error_message || l_error_tbl(i)
                                    .message_text || chr(10);
                END LOOP;
                v_error_message := 'Valid Category creation API ERROR: ' ||
                                   v_error_message;
                RAISE invalid_record;
              END IF;
          END;
          --
        END IF;
        -- update log with new or exists category
        v_step := 'Step 350';
        UPDATE xxobjt_conv_category c
           SET c.category_id      = nvl(data_rec.category_id,
                                        v_new_category_id),
               c.last_update_date = SYSDATE,
               c.last_updated_by  = fnd_global.user_id
         WHERE c.trx_id = data_rec.trx_id;
        COMMIT;
        v_step := 'Step 400';
        BEGIN
          v_def_category_id := NULL;
          IF p_mode = 'SINGLE' THEN
            --CHG0033893 - p_mode parameter added to support single/multiple category assigment logic
            SELECT category_id
              INTO v_def_category_id
              FROM mtl_item_categories mic
             WHERE mic.inventory_item_id = data_rec.inventory_item_id
               AND mic.organization_id = data_rec.organization_id
               AND mic.category_set_id = data_rec.category_set_id
               AND rownum = 1;
            --CHG0033893
          ELSE
            SELECT category_id
              INTO v_def_category_id
              FROM mtl_item_categories mic
             WHERE mic.inventory_item_id = data_rec.inventory_item_id
               AND mic.organization_id = data_rec.organization_id
               AND mic.category_set_id = data_rec.category_set_id
               AND mic.category_id =
                   nvl(data_rec.category_id, v_new_category_id);
          END IF;
          --CHG0033893
          IF v_def_category_id <>
             nvl(data_rec.category_id, v_new_category_id) THEN
            v_step := 'Step 410';
            inv_item_category_pub.update_category_assignment(p_api_version       => 1.0,
                                                             p_init_msg_list     => fnd_api.g_true,
                                                             p_commit            => fnd_api.g_false,
                                                             p_category_id       => nvl(data_rec.category_id,
                                                                                        v_new_category_id),
                                                             p_old_category_id   => v_def_category_id,
                                                             p_category_set_id   => data_rec.category_set_id,
                                                             p_inventory_item_id => data_rec.inventory_item_id,
                                                             p_organization_id   => data_rec.organization_id,
                                                             x_return_status     => l_return_status,
                                                             x_errorcode         => l_error_code,
                                                             x_msg_count         => l_msg_count,
                                                             x_msg_data          => l_msg_data);
            IF l_return_status != fnd_api.g_ret_sts_success THEN
              -- update_category_assignment Error
              v_upd_category_assign_failured := v_upd_category_assign_failured + 1;
              v_error_message                := 'Update Category Assignment Error: ' ||
                                                l_msg_data;
              RAISE invalid_record;
            ELSE
              v_upd_category_assign_success := v_upd_category_assign_success + 1;
            END IF;
          END IF; -- if v_def_category_id
        EXCEPTION
          WHEN no_data_found THEN
            --------
            v_step := 'Step 420';
            BEGIN
              inv_item_category_pub.create_category_assignment(p_api_version       => '1.0',
                                                               p_init_msg_list     => fnd_api.g_true,
                                                               p_commit            => fnd_api.g_true,
                                                               p_category_id       => nvl(data_rec.category_id,
                                                                                          v_new_category_id),
                                                               p_category_set_id   => data_rec.category_set_id,
                                                               p_inventory_item_id => data_rec.inventory_item_id,
                                                               p_organization_id   => data_rec.organization_id,
                                                               x_return_status     => l_return_status,
                                                               x_errorcode         => l_error_code,
                                                               x_msg_count         => l_msg_count,
                                                               x_msg_data          => l_msg_data);
              IF l_return_status != fnd_api.g_ret_sts_success THEN
                -- create_category_assignment Error
                v_cre_category_assign_failured := v_cre_category_assign_failured + 1;
                v_error_message                := 'Create Category Assignment Error: ' ||
                                                  l_msg_data;
                RAISE invalid_record;
              ELSE
                v_cre_category_assign_success := v_cre_category_assign_success + 1;
              END IF;
            END;
            --------
        END;
        UPDATE xxobjt_conv_category c
           SET c.trans_to_int_code = 'S',
               c.last_update_date  = SYSDATE,
               c.last_updated_by   = fnd_global.user_id
         WHERE c.trx_id = data_rec.trx_id;
        COMMIT;
      EXCEPTION
        WHEN invalid_record THEN
          v_invalid_records_counter := v_invalid_records_counter + 1;
          UPDATE xxobjt_conv_category c
             SET c.trans_to_int_code  = 'E',
                 c.trans_to_int_error = v_error_message,
                 c.last_update_date   = SYSDATE,
                 c.last_updated_by    = fnd_global.user_id
           WHERE c.trx_id = data_rec.trx_id;
          COMMIT;
        
          fnd_file.put_line(fnd_file.log,
                            'Error:' || rpad(data_rec.item_code, 25, ' ') ||
                            ' - ' || rpad(data_rec.segment1, 25, ' ') ||
                            ' - ' || v_error_message);
      END;
      -- end of LOOP --
    END LOOP;
    COMMIT;
    IF v_creation_categories_success > 0 THEN
      fnd_file.put_line(fnd_file.log,
                        v_creation_categories_success ||
                        ' Categories were created Successfully');
    END IF;
    IF v_creation_categories_failured > 0 THEN
      fnd_file.put_line(fnd_file.log,
                        v_creation_categories_failured ||
                        ' Categories creation Failured');
    END IF;
    IF v_upd_category_assign_success > 0 THEN
      fnd_file.put_line(fnd_file.log,
                        v_upd_category_assign_success ||
                        ' Category Assignments were updated Successfully');
    END IF;
    IF v_upd_category_assign_failured > 0 THEN
      fnd_file.put_line(fnd_file.log,
                        v_upd_category_assign_failured ||
                        ' Category Assignments updating Failured');
    END IF;
    IF v_cre_category_assign_success > 0 THEN
      fnd_file.put_line(fnd_file.log,
                        v_cre_category_assign_success ||
                        ' Category Assignments were created Successfully');
    END IF;
    IF v_cre_category_assign_failured > 0 THEN
      fnd_file.put_line(fnd_file.log,
                        v_cre_category_assign_failured ||
                        ' Category Assignments creating Failured');
    END IF;
    IF v_invalid_records_counter > 0 THEN
      fnd_file.put_line(fnd_file.log,
                        v_invalid_records_counter || ' invalid records');
    END IF;
    fnd_file.put_line(fnd_file.log,
                      'import_categories was completed, for request_id = ' ||
                      p_request_id);
    fnd_file.put_line(fnd_file.log,
                      'check errors, import_categories was completed, for request_id = ' ||
                      p_request_id);
    IF v_invalid_records_counter > 0 THEN
      retcode := '1';
      errbuf  := 'WARNING: ' || v_invalid_records_counter ||
                 ' invalid records in your file. Please check errors in XXOBJT_CONV_CATEGORY table for request_id = ' ||
                 p_request_id;
    END IF;
  EXCEPTION
    WHEN stop_processing THEN
      fnd_file.put_line(fnd_file.log, v_error_message);
      retcode := '2';
      errbuf  := v_error_message;
    WHEN OTHERS THEN
      v_error_message := 'Unexpected Error in import_categories - ' ||
                         v_step || ' - ' || SQLERRM;
      fnd_file.put_line(fnd_file.log, v_error_message);
      retcode := '2';
      errbuf  := v_error_message;
  END import_categories;
  --------------------------------------------------------------
  -- upload_categories
  -- CUST410 - Item Classification\CR1196 - Upload Item Categories
  -------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -----------------------------
  --     1.0  22.12.13    Vitaly         initial build
  --------------------------------------------------------------------
  PROCEDURE upload_categories(errbuf                         OUT VARCHAR2,
                              retcode                        OUT VARCHAR2,
                              p_table_name                   IN VARCHAR2, -- hidden parameter, default value ='XXOBJT_CONV_CATEGORY' independent value set XXOBJT_LOADER_TABLES
                              p_template_name                IN VARCHAR2, -- dependent value set XXOBJT_LOADER_TEMPLATES
                              p_file_name                    IN VARCHAR2,
                              p_directory                    IN VARCHAR2,
                              p_create_new_combinations_flag IN VARCHAR2) IS
    v_step VARCHAR2(100);
    stop_processing EXCEPTION;
    v_errbuf        VARCHAR2(3000);
    v_retcode       VARCHAR2(3000);
    v_error_message VARCHAR2(3000);
    l_request_id    NUMBER := fnd_global.conc_request_id;
    invalid_item EXCEPTION;
  BEGIN
    fnd_file.put_line(fnd_file.log,
                      'START xxinv_item_classification.upload_categories');
    fnd_file.put_line(fnd_file.log, 'REQUEST_ID = ' || l_request_id);
    v_step  := 'Step 0';
    errbuf  := 'Success';
    retcode := '0';
    v_step  := 'Step 10';
    -- Load data from CSV-table into XXOBJT_CONV_CATEGORY table
    xxobjt_table_loader_util_pkg.load_file(errbuf                 => v_errbuf,
                                           retcode                => v_retcode,
                                           p_table_name           => p_table_name, -- 'XXOBJT_CONV_CATEGORY',
                                           p_template_name        => p_template_name,
                                           p_file_name            => p_file_name,
                                           p_directory            => p_directory,
                                           p_expected_num_of_rows => NULL);
    IF v_retcode <> '0' THEN
      -- WARNING or ERROR
      v_error_message := v_errbuf;
      RAISE stop_processing;
    END IF;
    fnd_file.put_line(fnd_file.log,
                      'All records from file ' || p_file_name ||
                      ' were successfully loaded into table XXOBJT_CONV_ITEMS');
    UPDATE xxobjt_conv_category c
       SET c.source_code = p_file_name
     WHERE c.request_id = l_request_id;
    COMMIT;
    import_categories(errbuf                         => v_errbuf,
                      retcode                        => v_retcode,
                      p_request_id                   => l_request_id,
                      p_create_new_combinations_flag => p_create_new_combinations_flag);
    IF v_retcode <> '0' THEN
      retcode := v_retcode;
      errbuf  := v_errbuf;
    END IF;
    fnd_file.put_line(fnd_file.log,
                      'xxinv_item_classification.upload_categories was COMPLETED');
  EXCEPTION
    WHEN stop_processing THEN
      fnd_file.put_line(fnd_file.log, v_error_message);
      retcode := '2';
      errbuf  := v_error_message;
    WHEN OTHERS THEN
      v_error_message := 'Unexpected Error in upload_categories - ' ||
                         v_step || ' - ' || SQLERRM;
      fnd_file.put_line(fnd_file.log, v_error_message);
      errbuf  := v_error_message;
      retcode := '2';
  END upload_categories;
  --------------------------------------------------------------------
  --  customization code: delete_category_assignments
  --  name:
  --  create by:          Michal Tzvik
  --  Revision:           1.0
  --  creation date:      11/06/2015
  --  Purpose :           Delete category assignments to item, using API
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0  11/06/2015     Michal Tzvik    initial build
  -----------------------------------------------------------------------
  PROCEDURE delete_category_assignments(errbuf              OUT VARCHAR2,
                                        retcode             OUT VARCHAR2,
                                        p_category_id       IN NUMBER,
                                        p_category_set_id   IN NUMBER,
                                        p_inventory_item_id IN NUMBER,
                                        p_organization_id   IN NUMBER) IS
    l_error_message VARCHAR2(3000);
    /* l_request_id     NUMBER := fnd_global.conc_request_id;
     l_line           VARCHAR2(2000);
     l_item_code      VARCHAR2(240);
     l_sql_statement  VARCHAR2(1000);
     l_category_flag  VARCHAR2(5);
     stop_processing EXCEPTION;
    */
    l_msg_index_out NUMBER;
    l_return_status VARCHAR2(80);
    l_error_code    NUMBER;
    l_msg_count     NUMBER;
    l_msg_data      VARCHAR2(250);
    --l_delete_count  NUMBER := 0;
    --l_err_flag      NUMBER := 0;
  BEGIN
    errbuf  := '';
    retcode := '0';
  
    inv_item_category_pub.delete_category_assignment(p_api_version       => 1.0, --
                                                     p_init_msg_list     => fnd_api.g_true, --
                                                     p_commit            => fnd_api.g_true, --
                                                     x_return_status     => l_return_status, --
                                                     x_errorcode         => l_error_code, --
                                                     x_msg_count         => l_msg_count, --
                                                     x_msg_data          => l_msg_data, --
                                                     p_category_id       => p_category_id, --
                                                     p_category_set_id   => p_category_set_id, --
                                                     p_inventory_item_id => p_inventory_item_id, --
                                                     p_organization_id   => p_organization_id);
  
    IF l_return_status != fnd_api.g_ret_sts_success THEN
      retcode := 1;
      FOR i IN 1 .. l_msg_count LOOP
        l_error_message := NULL;
        apps.fnd_msg_pub.get(p_msg_index     => i,
                             p_encoded       => fnd_api.g_false,
                             p_data          => l_msg_data,
                             p_msg_index_out => l_msg_index_out);
        IF l_error_message IS NULL THEN
          l_error_message := substr(l_msg_data, 1, 250);
        ELSE
          l_error_message := l_error_message || ' /' ||
                             substr(l_msg_data, 1, 250);
        END IF;
      END LOOP;
      fnd_file.put_line(fnd_file.log,
                        'Delete category assignment API Error : ' ||
                        l_error_message);
      /* ELSE
      l_delete_count := l_delete_count + 1;*/
    END IF;
    /* IF l_delete_count > 0 THEN
      fnd_file.put_line(fnd_file.log, l_delete_count ||
                         ' Category Assignments were removed Successfully');
      fnd_file.put_line(fnd_file.log, '---------------------------------------------');
    END IF;*/
  
    IF retcode = 1 THEN
      errbuf := l_error_message;
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      retcode := 1;
      errbuf  := 'Unexpected error in xxinv_item_classification.delete_category_assignments: ' ||
                 SQLERRM;
  END delete_category_assignments;
  --------------------------------------------------------------------
  -- upload_categories_pivot
  -- CHG0033893 - Item Classification - Upload Item Categories pivot
  -------------------------------------------------------------------
  -- Version  Date         Performer            Comments
  ----------  ----------  -----------------     -----------------------------
  --     1.0  03.12.15    Yuval Tal/Gubendran K   Initial build
  --     1.1  01.06.2015  Michal Tzvik            CHG0035332 - Enable upload additional column of short text attachment
  --                                              remove parameter p_delete_all_flag
  --     1.2  02/06/2019  Roman W.                INC0158489 utl_file.fopen : increase max_linesize to 2500
  --------------------------------------------------------------------
  PROCEDURE upload_categories_pivot(errbuf                         OUT VARCHAR2,
                                    retcode                        OUT VARCHAR2,
                                    p_category_set_name            IN VARCHAR2,
                                    p_file_name                    IN VARCHAR2,
                                    p_directory                    IN VARCHAR2,
                                    p_create_new_combinations_flag IN VARCHAR2
                                    /*p_delete_all_flag              IN VARCHAR2 DEFAULT 'N'*/) IS
  
    l_file_handler   utl_file.file_type;
    l_counter        NUMBER := 0;
    l_directory_name VARCHAR2(50) := 'XXINV_CATEGORY_DIR';
    l_error_message  VARCHAR2(3000);
    l_request_id     NUMBER := fnd_global.conc_request_id;
    l_line           VARCHAR2(2500);
    l_item_code      VARCHAR2(240);
    l_sql_statement  VARCHAR2(1000);
    l_category_flag  VARCHAR2(5);
    stop_processing EXCEPTION;
    l_msg_index_out NUMBER;
    l_return_status VARCHAR2(80);
    l_error_code    NUMBER;
    l_msg_count     NUMBER;
    l_msg_data      VARCHAR2(250);
    l_delete_count  NUMBER := 0;
    l_err_flag      NUMBER := 0;
  
    -- 1.1   Michal Tzvik: Start
    l_attachment_flag        VARCHAR2(1);
    l_col_cnt                NUMBER; --  number of columns in the file
    l_err_code               NUMBER;
    l_document_id            NUMBER;
    l_master_organization_id NUMBER;
    l_inventory_item_id      NUMBER;
    l_att_category_name      fnd_document_categories_tl.user_name%TYPE := fnd_profile.value('XXCS_PZ_ATTACHMENT_CATEGORY');
    l_att_category_id        NUMBER;
    l_att_entity_name        fnd_attached_docs_form_vl.entity_name%TYPE := 'MTL_SYSTEM_ITEMS';
    l_att_function_name      fnd_attached_docs_form_vl.function_name%TYPE := 'INVIDITM';
    l_att_cnt                NUMBER; -- number of attachments for current iteml_attachment
    l_attachment             VARCHAR2(4000);
    -- 1.1   Michal Tzvik: End
  
    TYPE l_categories_tab IS TABLE OF VARCHAR2(240) INDEX BY BINARY_INTEGER;
    l_categories_arr l_categories_tab;
    CURSOR c_split(l_str VARCHAR2) IS
      SELECT TRIM(regexp_substr(l_str, '[^,]+', 1, LEVEL)) val
        FROM dual
      CONNECT BY regexp_substr(l_str, '[^,]+', 1, LEVEL) IS NOT NULL;
  
    CURSOR c_del_data(p_inventory_item_id NUMBER, p_organization_id NUMBER) IS
      SELECT --msi.segment1 item_code,
       mic.inventory_item_id,
       mcs.category_set_id,
       mcb.category_id,
       mic.organization_id
        FROM --mtl_system_items_b  msi,
             mtl_item_categories mic,
             mtl_categories_b    mcb,
             mtl_category_sets   mcs
       WHERE mic.inventory_item_id =
             nvl(p_inventory_item_id, mic.inventory_item_id)
         AND mic.organization_id = p_organization_id --msi.organization_id
         AND mic.category_id = mcb.category_id
         AND mic.category_set_id = mcs.category_set_id
         AND mcs.category_set_name = p_category_set_name --'CS Price Book Product Type'
         AND mcb.structure_id = mcs.structure_id
      --AND    msi.organization_id = p_organization_id
      ;
  
  BEGIN
    fnd_file.put_line(fnd_file.log,
                      'START xxinv_item_classification.upload_categories_pivot');
    fnd_file.put_line(fnd_file.log, 'REQUEST_ID = ' || l_request_id);
    IF p_directory IS NULL THEN
      l_error_message := 'Missing parameter p_directory';
      RAISE stop_processing;
    END IF;
    ---Create or replace directory-----
    l_sql_statement := 'CREATE OR REPLACE DIRECTORY ' || l_directory_name ||
                       ' AS ''' || p_directory || '''';
    BEGIN
      EXECUTE IMMEDIATE l_sql_statement;
      fnd_file.put_line(fnd_file.log,
                        'Directory ' || l_directory_name ||
                        ' was created/replaced successfully');
    EXCEPTION
      WHEN OTHERS THEN
        ---Error----
        l_error_message := substr('Create/Replace Directory Error: ' ||
                                  SQLERRM,
                                  1,
                                  200);
        fnd_file.put_line(fnd_file.log,
                          'l_sql_statement' || l_sql_statement);
        RAISE stop_processing;
    END;
    -- open the file for reading
  
    l_file_handler := utl_file.fopen(location     => p_directory,
                                     filename     => p_file_name,
                                     open_mode    => 'R',
                                     max_linesize => 2500);
    fnd_file.put_line(fnd_file.log,
                      'File ' || ltrim(p_file_name) ||
                      ' Is open For Reading ');
  
    --Get the First Line for Category Assignment from pivot excel file
  
    utl_file.get_line(l_file_handler, l_line);
    -- add dummy char if string start with comma
    IF instr(l_line, ',') = 1 THEN
      l_line := 'x' || l_line;
    END IF;
  
    fnd_file.put_line(fnd_file.log, 'Reading categories from first line');
  
    -- remove comma between "
    l_line := regexp_replace(l_line, '((\"|^).*?(\"|$))|,', '\1 ');
  
    FOR i IN c_split(l_line) LOOP
      l_categories_arr(c_split%ROWCOUNT) := rtrim(i.val, chr(13));
    
      fnd_file.put_line(fnd_file.log,
                        'Category=' || l_categories_arr(c_split%ROWCOUNT));
    
      l_col_cnt := c_split%ROWCOUNT;
    END LOOP;
  
    --fnd_file.put_line(fnd_file.log, 'l_col_cnt=' || l_col_cnt);
    -- 1.1 Michal Tzvik: Check if last column is for attachment
    IF l_categories_arr(l_col_cnt) =
       fnd_profile.value('XXCS_ATT_HEADER_IN_UPLOAD_FILE') THEN
      l_attachment_flag := 'Y';
    ELSE
      l_attachment_flag := 'N';
    END IF;
    fnd_file.put_line(fnd_file.log,
                      'Include attachment column: ' || l_attachment_flag);
  
    -- read line 2 ...N  data and insert into table
    BEGIN
      l_master_organization_id := xxinv_utils_pkg.get_master_organization_id;
    
      LOOP
        BEGIN
          utl_file.get_line(l_file_handler, l_line);
          -- remove comma between "
          l_line := regexp_replace(l_line, '((\"|^).*?(\"|$))|,', '\1 ');
        
          --  process 2-N records
          -- split record and insert data to table
          FOR i IN 1 .. l_categories_arr.count() LOOP
            IF i = 1 THEN
              l_item_code := TRIM(regexp_replace(l_line,
                                                 '^([^,]*).*$',
                                                 '\1'));
              --- 1.1 Michal Tzvik: delete category assignments assignment
            
              BEGIN
                SELECT msib.inventory_item_id
                  INTO l_inventory_item_id
                  FROM mtl_system_items_b msib
                 WHERE msib.segment1 = l_item_code
                   AND msib.organization_id = l_master_organization_id;
              EXCEPTION
                WHEN no_data_found THEN
                  l_error_message := 'Invalid item ' || l_item_code;
                  RAISE stop_processing;
              END;
              FOR c_del_rec IN c_del_data(l_inventory_item_id,
                                          l_master_organization_id) LOOP
                delete_category_assignments(errbuf              => l_error_message, --
                                            retcode             => l_error_code, --
                                            p_category_id       => c_del_rec.category_id, --
                                            p_category_set_id   => c_del_rec.category_set_id, --
                                            p_inventory_item_id => l_inventory_item_id, --
                                            p_organization_id   => l_master_organization_id --
                                            );
                IF l_error_code != '0' THEN
                  RAISE stop_processing;
                END IF;
              END LOOP;
              -- 1.1 Michal Tzvik: Check if last column is for attachment
            ELSIF i = l_col_cnt AND l_attachment_flag = 'Y' THEN
            
              SELECT fdcv.category_id
                INTO l_att_category_id
                FROM fnd_document_categories_vl fdcv
               WHERE fdcv.user_name = l_att_category_name;
            
              xxobjt_fnd_attachments.delete_attachment(err_code          => l_error_code, --
                                                       err_msg           => l_error_message, --
                                                       p_document_id     => NULL, --
                                                       p_entity_name     => 'MTL_SYSTEM_ITEMS', --
                                                       p_category_name   => l_att_category_name, --
                                                       p_function_name   => 'INVIDITM', --
                                                       p_delete_ref_flag => 'Y', --
                                                       p_pk1             => l_master_organization_id, --
                                                       p_pk2             => l_inventory_item_id, --
                                                       p_pk3             => NULL);
            
              IF l_error_code != '0' THEN
                RAISE stop_processing;
              END IF;
            
              l_attachment := REPLACE(TRIM(regexp_replace(l_line,
                                                          '^([^,]*\,){' ||
                                                          to_char(i - 1) ||
                                                          '}([^,]*).*$',
                                                          '\2')),
                                      chr(13),
                                      NULL);
              -- remove "
            
              l_attachment := rtrim(ltrim(l_attachment, '"'), '"');
            
              fnd_file.put_line(fnd_file.log,
                                'l_attachment: ' || l_attachment);
            
              IF l_attachment IS NOT NULL THEN
                --IF l_att_cnt = 0 THEN
                -- No attachment exists, create a new attachment
                xxobjt_fnd_attachments.create_short_text_att(err_code      => l_error_code, -- out
                                                             err_msg       => l_error_message, -- out
                                                             p_document_id => l_document_id, -- out
                                                             p_category_id => l_att_category_id, --fnd_profile.value('XX'), --!!!
                                                             p_entity_name => l_att_entity_name, --
                                                             p_file_name   => NULL, --
                                                             p_title       => NULL, --
                                                             p_description => NULL, --
                                                             p_short_text  => l_attachment, --
                                                             p_pk1         => l_master_organization_id, --
                                                             p_pk2         => l_inventory_item_id, --
                                                             p_pk3         => NULL);
              
                IF l_error_code != '0' THEN
                  RAISE stop_processing;
                END IF;
              END IF;
              -- 1.1: End handle attachment
            
            ELSE
            
              l_category_flag := regexp_replace(l_line,
                                                '^([^,]*\,){' ||
                                                to_char(i - 1) ||
                                                '}([^,]*).*$',
                                                '\2');
              /* fnd_file.put_line(fnd_file.log, 'Item: ' || l_item_code ||
              ', category: ' ||
              l_categories_arr(i) ||
              ',l_category_flag: ' ||
              l_category_flag || ', i:' || i);*/
            
              IF nvl(l_category_flag, '0') > '0' THEN
                l_counter := l_counter + 1;
                INSERT INTO xxobjt_conv_category
                  (trx_id,
                   request_id,
                   category_set_name,
                   item_code,
                   trans_to_int_code,
                   creation_date,
                   created_by,
                   segment1,
                   organization_code)
                VALUES
                  (xxobjt_conv_category_trxid_seq.nextval,
                   l_request_id,
                   p_category_set_name,
                   l_item_code,
                   'N',
                   SYSDATE,
                   fnd_global.login_id,
                   l_categories_arr(i),
                   'OMA');
              END IF;
            END IF;
          
          END LOOP;
        EXCEPTION
          WHEN no_data_found THEN
            EXIT;
          
        END;
        COMMIT;
      END LOOP;
    
      --- call delete categories if needed
    
      IF l_counter > 0 THEN
        /* fnd_file.put_line(fnd_file.log, 'Start Removed Category Assiginment');
        fnd_file.put_line(fnd_file.log, '---------------------------------------------');
        
        IF p_delete_all_flag = 'Y' THEN
        
          FOR c_del_rec IN c_del_data LOOP
            inv_item_category_pub.delete_category_assignment(p_api_version => 1.0, p_init_msg_list => fnd_api.g_true, p_commit => fnd_api.g_true, x_return_status => l_return_status, x_errorcode => l_error_code, x_msg_count => l_msg_count, x_msg_data => l_msg_data, p_category_id => c_del_rec.category_id, p_category_set_id => c_del_rec.category_set_id, p_inventory_item_id => c_del_rec.inventory_item_id, p_organization_id => c_del_rec.organization_id);
            IF l_return_status != fnd_api.g_ret_sts_success THEN
              l_err_flag := 1;
              FOR i IN 1 .. l_msg_count LOOP
                l_error_message := NULL;
                apps.fnd_msg_pub.get(p_msg_index => i, p_encoded => fnd_api.g_false, p_data => l_msg_data, p_msg_index_out => l_msg_index_out);
                IF l_error_message IS NULL THEN
                  l_error_message := substr(l_msg_data, 1, 250);
                ELSE
                  l_error_message := l_error_message || ' /' ||
                                     substr(l_msg_data, 1, 250);
                END IF;
              END LOOP;
              fnd_file.put_line(fnd_file.log, 'API Error : ' ||
                                 l_error_message);
            ELSE
              l_delete_count := l_delete_count + 1;
            END IF;
          END LOOP;
          IF l_delete_count > 0 THEN
            fnd_file.put_line(fnd_file.log, l_delete_count ||
                               ' Category Assignments were removed Successfully');
            fnd_file.put_line(fnd_file.log, '---------------------------------------------');
          END IF;
        
        END IF; -- if del
        
        IF l_err_flag = 1 THEN
        
          l_error_message := ' Errors found during delete categories ... processes stopped';
          RAISE stop_processing;
        END IF;*/
      
        --- import categories
        fnd_file.put_line(fnd_file.log, 'Start import categories: ');
        fnd_file.put_line(fnd_file.log,
                          '---------------------------------------------');
        import_categories(errbuf,
                          retcode,
                          l_request_id,
                          p_create_new_combinations_flag,
                          'MULTI');
        fnd_file.put_line(fnd_file.log,
                          '---------------------------------------------');
        fnd_file.put_line(fnd_file.log,
                          'import_categories: ' || errbuf || ' ' || retcode);
      ELSE
        fnd_file.put_line(fnd_file.log, 'No records found for process');
      END IF; -- records found
    
    END;
    utl_file.fclose(l_file_handler);
    fnd_file.put_line(fnd_file.log,
                      'xxinv_item_classification.upload_categories_pivot COMPLETED');
  EXCEPTION
    WHEN utl_file.invalid_path THEN
      retcode := '1';
      errbuf  := errbuf || 'Invalid Path for ' || ltrim(p_file_name) ||
                 chr(0);
    WHEN utl_file.invalid_mode THEN
      retcode := '1';
      errbuf  := errbuf || 'Invalid Mode for ' || ltrim(p_file_name) ||
                 chr(0);
    WHEN utl_file.invalid_operation THEN
      retcode := '1';
      errbuf  := errbuf || 'Invalid operation for ' || ltrim(p_file_name) ||
                 SQLERRM || chr(0);
    WHEN stop_processing THEN
      fnd_file.put_line(fnd_file.log, l_error_message);
      retcode := '1';
      errbuf  := l_error_message;
    WHEN OTHERS THEN
      l_error_message := 'Unexpected Error in upload_categories_pivot - (l_item_code: ' ||
                         l_item_code || '):' || SQLERRM;
      fnd_file.put_line(fnd_file.log, l_error_message);
      errbuf  := l_error_message;
      retcode := '2';
  END upload_categories_pivot;
  --------------------------------------------------------------------
  --  name:            is_item_polyjet
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   28/05/2014 14:19:38
  --------------------------------------------------------------------
  --  purpose :        REP485 - INV allocation by product family\CR382- Slow_Inactive
  --
  --  in params:       inventory_item_id
  --  out:             if this is FDM
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  28/05/2014  Dalit A. Raviv    initial build
  --  1.1 30.4.17      yuval tal         CHG0040061 add new parameter p_organization_id
  --------------------------------------------------------------------
  FUNCTION is_item_polyjet(p_inventory_item_id IN NUMBER,
                           p_organization_id   NUMBER DEFAULT NULL)
    RETURN VARCHAR2 IS
    l_is_pj VARCHAR2(10) := 'N';
  
    l_master_org_id NUMBER;
  BEGIN
    IF p_organization_id IS NULL THEN
      l_master_org_id := xxinv_utils_pkg.get_master_organization_id;
    ELSE
      l_master_org_id := p_organization_id;
    END IF;
  
    SELECT 'Y'
      INTO l_is_pj
      FROM mtl_item_categories mic, mtl_categories_b_kfv mc
     WHERE mic.category_id = mc.category_id
       AND mic.inventory_item_id = p_inventory_item_id -- 13003
       AND mic.organization_id = l_master_org_id
       AND mic.category_set_id = 1100000221
       AND mc.segment6 = 'POLYJET';
    RETURN l_is_pj;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 'N';
  END is_item_polyjet;
  --------------------------------------------------------------------
  --  name:            is_item_fdm
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   28/05/2014 14:19:38
  --------------------------------------------------------------------
  --  purpose :        REP485 - INV allocation by product family\CR382- Slow_Inactive
  --
  --  in params:       inventory_item_id
  --  out:             if this is FDM
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  28/05/2014  Dalit A. Raviv    initial build
  --  1.1 30.4.17      yuval tal         CHG0040061 add new parameter p_organization_id
  --------------------------------------------------------------------
  FUNCTION is_item_fdm(p_inventory_item_id IN NUMBER,
                       p_organization_id   NUMBER DEFAULT NULL)
    RETURN VARCHAR2 IS
    l_is_pj VARCHAR2(10) := 'N';
  
    l_master_org_id NUMBER;
  BEGIN
    IF p_organization_id IS NULL THEN
      l_master_org_id := xxinv_utils_pkg.get_master_organization_id;
    ELSE
      l_master_org_id := p_organization_id;
    END IF;
  
    SELECT 'Y'
      INTO l_is_pj
      FROM mtl_item_categories mic, mtl_categories_b_kfv mc
     WHERE mic.category_id = mc.category_id
       AND mic.inventory_item_id = p_inventory_item_id -- 13003
       AND mic.organization_id = l_master_org_id
       AND mic.category_set_id = 1100000221
       AND mc.segment6 = 'FDM';
    RETURN l_is_pj;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 'N';
  END is_item_fdm;

  --------------------------------------------------------------------
  --  name:            is_system_item

  --------------------------------------------------------------------
  --  purpose :
  --
  --  in params:       inventory_item_id/p_organization_id
  --  out:             Y/N
  --------------------------------------------------------------------
  --  ver  date        name         desc
  --  1.0  30.4.17   yuval tal     CHG0040061 initial build
  --  1.1  01.3.18   bellona(TCS)  CHG0042432 function xxinv_item_classification.is_system_item
  --                               should be based on multiple activity analysis.
  --------------------------------------------------------------------
  FUNCTION is_system_item(p_inventory_item_id IN NUMBER,
                          p_organization_id   NUMBER DEFAULT NULL)
    RETURN VARCHAR2 IS
    l_return        VARCHAR2(10) := NULL;
    l_master_org_id NUMBER;
  BEGIN
    IF p_organization_id IS NULL THEN
      l_master_org_id := xxinv_utils_pkg.get_master_organization_id;
    ELSE
      l_master_org_id := p_organization_id;
    END IF;
  
    BEGIN
      SELECT 'Y'
        INTO l_return
        FROM mtl_item_categories_v mic,
             mtl_categories_b      mcb,
             mtl_system_items_b    msib,
             fnd_flex_values       flv,
             fnd_flex_value_sets   flvs
       WHERE mic.organization_id = l_master_org_id
         AND mcb.category_id = mic.category_id
         AND msib.inventory_item_id = mic.inventory_item_id
         AND msib.organization_id = l_master_org_id
         AND mic.category_set_name = 'Activity Analysis'
            --AND    mic.segment1 = 'Systems (net)'
            --CHG0042432 - converted function to multiple activity handling by using new valueset
         AND flv.flex_value = mic.segment1
         AND flv.flex_value_set_id = flvs.flex_value_set_id
         AND flvs.flex_value_set_name = 'XXINV_SYSTEM_ACTIVITY_ANALYSIS'
         AND flv.enabled_flag = 'Y'
         AND trunc(SYSDATE) BETWEEN
             nvl(flv.start_date_active, trunc(SYSDATE)) AND
             nvl(flv.end_date_active, trunc(SYSDATE))
         AND msib.inventory_item_id = p_inventory_item_id;
    EXCEPTION
      WHEN too_many_rows THEN
        NULL;
    END;
    BEGIN
      SELECT 'Y'
        INTO l_return
        FROM mtl_item_categories_v mic,
             mtl_categories_b      mcb,
             mtl_system_items_b    msib
       WHERE mic.organization_id = l_master_org_id
         AND mcb.category_id = mic.category_id
         AND msib.inventory_item_id = mic.inventory_item_id
         AND msib.organization_id = l_master_org_id
         AND mic.category_set_name = 'Brand'
         AND mic.segment1 = 'SSYS Core'
         AND msib.inventory_item_id = p_inventory_item_id;
    EXCEPTION
      WHEN too_many_rows THEN
        NULL;
    END;
    BEGIN
      SELECT 'Y'
        INTO l_return
        FROM mtl_item_categories_v mic,
             mtl_categories_b      mcb,
             mtl_system_items_b    msib
       WHERE mic.organization_id = l_master_org_id
         AND mcb.category_id = mic.category_id
         AND msib.inventory_item_id = mic.inventory_item_id
         AND msib.organization_id = l_master_org_id
         AND mic.category_set_name = 'Product Hierarchy'
         AND mic.segment1 = 'Systems'
         AND msib.inventory_item_id = p_inventory_item_id;
    EXCEPTION
      WHEN too_many_rows THEN
        NULL;
    END;
    RETURN 'Y';
  EXCEPTION
    WHEN no_data_found THEN
      RETURN 'N';
  END;

  --------------------------------------------------------------------
  --  name:            get_is_item_resin
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   26/02/2014 14:19:38
  --------------------------------------------------------------------
  --  purpose :        REP485 - INV allocation by product family\CR382- Slow_Inactive
  --
  --  in params:       inventory_item_id
  --  out:             if this is a resin item Y/N
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  26/02/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION is_item_resin(p_inventory_item_id IN NUMBER) RETURN VARCHAR2 IS
    l_is_resin VARCHAR2(10) := 'N';
  BEGIN
    BEGIN
      SELECT 'Y'
        INTO l_is_resin
        FROM mtl_item_categories mic, mtl_categories_b_kfv mc
       WHERE mic.category_id = mc.category_id
         AND mic.inventory_item_id = p_inventory_item_id -- 13003
         AND mic.organization_id = 91
         AND mic.category_set_id = 1100000221
         AND mc.segment1 = 'Materials'
         AND mc.segment6 = 'POLYJET';
      RETURN 'Y';
    EXCEPTION
      WHEN no_data_found THEN
        BEGIN
          SELECT 'Y'
            INTO l_is_resin
            FROM mtl_item_categories_v mic1,
                 mtl_categories        mc1,
                 mtl_categories_kfv    mckfv1
           WHERE mic1.organization_id = mic1.organization_id
             AND mic1.category_id = mc1.category_id
             AND mic1.organization_id = 91
             AND mc1.category_id = mckfv1.category_id
             AND mc1.structure_id = mckfv1.structure_id
             AND category_set_id = 1100000041 --  'Main Category Set'
             AND mckfv1.segment1 = 'Resins'
             AND mic1.inventory_item_id = p_inventory_item_id;
          RETURN 'Y';
        EXCEPTION
          WHEN OTHERS THEN
            RETURN 'N';
        END;
    END;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 'N';
  END is_item_resin;
  --------------------------------------------------------------------
  --  name:               is_item_SP
  --  create by:          Dalit A. Raviv
  --  Revision:           1.0
  --  creation date:      27/03/2014
  --------------------------------------------------------------------
  --  purpose:            Get if item is Spare Part
  --------------------------------------------------------------------
  --  ver     date        name            desc
  --  1.0     27/03/2014  Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  FUNCTION is_item_sp(p_inventory_item_id IN NUMBER) RETURN VARCHAR2 IS
    l_is_sp VARCHAR2(10) := 'N';
  BEGIN
    SELECT 'Y'
      INTO l_is_sp
      FROM mtl_item_categories_v
     WHERE inventory_item_id = p_inventory_item_id -- 13003, 14935
       AND organization_id = 91
       AND category_set_id = 1100000222 -- 'Activity Analysis'
       AND upper(category_concat_segs) LIKE 'SP%';
    --and    category_concat_segs  = 'Spare Parts';
    RETURN l_is_sp;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 'N';
  END is_item_sp;
  --------------------------------------------------------------------
  --  name:               is_item_FG
  --  create by:          Dalit A. Raviv
  --  Revision:           1.0
  --  creation date:      27/03/2014
  --------------------------------------------------------------------
  --  purpose:            Get if item is Finished good
  --------------------------------------------------------------------
  --  ver     date        name            desc
  --  1.0     27/03/2014  Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  FUNCTION is_item_fg(p_inventory_item_id IN NUMBER) RETURN VARCHAR2 IS
    l_count NUMBER;
  BEGIN
    SELECT COUNT(1)
      INTO l_count
      FROM mtl_item_categories mic, mtl_categories_b_kfv mc
     WHERE mic.category_id = mc.category_id
       AND mic.inventory_item_id = p_inventory_item_id -- 13003
       AND mic.organization_id = 91
       AND mic.category_set_id = 1100000221
       AND mc.segment7 = 'FG';
    IF l_count > 0 THEN
      RETURN 'Y';
    ELSE
      RETURN 'N';
    END IF;
  END is_item_fg;
  --------------------------------------------------------------------
  --  name:               is_item_Material
  --  create by:          OFER SUAD
  --  Revision:           1.0
  --  creation date:      27/03/2014
  --------------------------------------------------------------------
  --  purpose:            is_item_Material
  --------------------------------------------------------------------
  --  ver     date        name            desc
  --  1.0     08.07.14  OFER SUAD       CHANGE CHG0032527 - initial build
  --  1.1     20.06.18  Ofer Suad       CHG0042761 remove Main Category Set
  --------------------------------------------------------------------
  FUNCTION is_item_material(p_inventory_item_id IN NUMBER) RETURN VARCHAR2 IS
    l_is_material VARCHAR2(10) := 'N';
  BEGIN
    --BEGIN
    SELECT 'Y'
      INTO l_is_material
      FROM mtl_item_categories mic, mtl_categories_b_kfv mc
     WHERE mic.category_id = mc.category_id
       AND mic.inventory_item_id = p_inventory_item_id -- 13003
       AND mic.organization_id = 91
       AND mic.category_set_id = 1100000221
       AND mc.segment1 = 'Materials';
    RETURN 'Y';
    /*EXCEPTION --CHG0042761   Main Category Set
      WHEN no_data_found THEN
        BEGIN
          SELECT 'Y'
          INTO   l_is_material
          FROM   mtl_item_categories_v mic1,
         mtl_categories        mc1,
         mtl_categories_kfv    mckfv1
          WHERE  mic1.organization_id = mic1.organization_id
          AND    mic1.category_id = mc1.category_id
          AND    mic1.organization_id = 91
          AND    mc1.category_id = mckfv1.category_id
          AND    mc1.structure_id = mckfv1.structure_id
          AND    category_set_id = 1100000041 --  'Main Category Set'
          AND    mckfv1.segment1 IN ('Resins', 'Consummables')
          AND    mic1.inventory_item_id = p_inventory_item_id;
          RETURN 'Y';
        EXCEPTION
          WHEN OTHERS THEN
    RETURN 'N';
        END;
    END;*/
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 'N';
  END is_item_material;

  ------------------------------------------------------------------------------------------------------------------
  -- Ver      When         Who       Description
  -- -------  -----------  --------  -------------------------------------------------------------------------------
  --  1.9      05/07/2018   Roman W.  INC0125761 - create procedure calculate MTL_SYSTEM_ITEMS_B.item_type by ...
  ------------------------------------------------------------------------------------------------------------------
  FUNCTION get_item_type(p_inventory_item_id NUMBER) RETURN VARCHAR2 IS
    ---------------------------
    --     Local Definition
    ---------------------------
    l_ret_value VARCHAR2(30);
  
    ---------------------------
    --     Code Section
    ---------------------------
  BEGIN
  
    SELECT msi.item_type
      INTO l_ret_value
      FROM mtl_system_items_b msi
     WHERE msi.organization_id = xxinv_utils_pkg.get_master_organization_id
       AND msi.inventory_item_id = p_inventory_item_id;
  
    RETURN l_ret_value;
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_item_type;

  ----------------------------------------------------------------------------------------------------
  --  ver  When        Who               Descr
  -------- ----------- ----------------- -------------------------------------------------------------
  --  1.0  15/12/2019  Roman W.          CHG0047007 - Support Multiple Technologies
  ----------------------------------------------------------------------------------------------------
  function get_item_technology(p_inventory_item_id NUMBER) return VARCHAR2 is
    ------------------------------
    --   Local Definition
    ------------------------------
    l_master_org_id NUMBER;
    l_ret_val       mtl_categories_b_kfv.segment6%TYPE;
    ------------------------------
    --   Code Section
    ------------------------------
  begin
  
    l_master_org_id := XXINV_UTILS_PKG.GET_MASTER_ORGANIZATION_ID;
  
    SELECT mc.segment6
      INTO l_ret_val
      FROM mtl_item_categories mic, mtl_categories_b_kfv mc
     WHERE mic.category_id = mc.category_id
       AND mic.inventory_item_id = p_inventory_item_id -- 13003
       AND mic.organization_id = l_master_org_id
       AND mic.category_set_id = 1100000221;
  
    return l_ret_val;
  
  exception
    when others then
      l_ret_val := null;
    
      return l_ret_val;
    
  end get_item_technology;
  ----------------------------------------------------------------------------------------------------
  --  ver  When        Who               Descr
  -------- ----------- ----------------- -------------------------------------------------------------
  --  1.0  15/12/2019  Roman W.          CHG0047007 - Support Multiple Technologies
  ----------------------------------------------------------------------------------------------------
  function get_item_speciality_flavor(p_inventory_item_id NUMBER)
    return VARCHAR2 is
    ------------------------------
    --   Local Definition
    ------------------------------
    l_master_org_id NUMBER;
    l_ret_val       mtl_categories_b_kfv.segment6%TYPE;
    ------------------------------
    --   Code Section
    ------------------------------
  begin
  
    l_master_org_id := XXINV_UTILS_PKG.GET_MASTER_ORGANIZATION_ID;
  
    SELECT mc.segment5
      INTO l_ret_val
      FROM mtl_item_categories mic, mtl_categories_b_kfv mc
     WHERE mic.category_id = mc.category_id
       AND mic.inventory_item_id = p_inventory_item_id -- 13003
       AND mic.organization_id = l_master_org_id
       AND mic.category_set_id = 1100000221;
  
    return l_ret_val;
  
  exception
    when others then
      l_ret_val := null;
      return l_ret_val;
    
  end get_item_speciality_flavor;

END xxinv_item_classification;
/
