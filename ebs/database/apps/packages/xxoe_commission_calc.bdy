CREATE OR REPLACE PACKAGE BODY xxoe_commission_calc AS
  ---------------------------------------------------------------------------
  -- $Header: xxap_invoices_upload   $
  ---------------------------------------------------------------------------
  -- Package: xxobjt_fnd_attachments
  -- Created: 
  -- Author  : 
  --------------------------------------------------------------------------
  -- Perpose: support commission calculation process
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --     1.0  16.08.11   yuval tal        initial Build
  --     1.1   22.3.12   yuval.tal        get_ap_paid_info : add l.line_type_lookup_code ='ITEM'
  --     1.3  10.10.12   yuval tal        CR 506 - change logic : is_upgrade_order : change to oe_order_lines_all 
  --                                                     create invoices : add is_updrade condition for account 
  --                                                                       decision logic 
  --     1.4  26.2.13    yuval tal         bugfix - Fix resin coupon commission and resin portion by site
  --                                               get_shipped_date : fix unshippable item logic for get ship date  
  CURSOR c_sql IS
    SELECT * FROM xxoe_commission_dynamic_param;
  CURSOR c_data(c_line_id NUMBER) IS
    SELECT *
      FROM xxoe_commission_source_v
     WHERE line_id = c_line_id
     ORDER BY line_id;

  CURSOR c_calc_data(c_stage VARCHAR2, c_line_id NUMBER) IS
    SELECT *
      FROM xxoe_commission_data t
     WHERE t.oe_line_id = c_line_id
       AND t.stage_context = c_stage;

  CURSOR c_calc_data_his(c_stage VARCHAR2, c_line_id NUMBER, c_date DATE) IS
    SELECT *
      FROM xxoe_commission_data_his t
     WHERE t.oe_line_id = c_line_id
       AND t.stage_context = c_stage
       AND t.creation_date = c_date;

  CURSOR c_delta(c_line_id NUMBER) IS
    SELECT *
      FROM xxoe_commission_source_v t
     WHERE -- t.order_number = '174348';
     line_id > fnd_profile.value('XXOECOMM_LASTID') - 10000
     AND t.ordered_date >= to_date('01-JAN-2012', 'dd-mon-yyyy');

  CURSOR c_open_lines IS
    SELECT * FROM xxoe_commission_data t WHERE t.ap_full_paid_flag = 'N';
  --   AND t.agent_id IS NOT NULL; -- t.close_flag = 'N';

  CURSOR c_comm_re_check_lines IS
    SELECT *
      FROM xxoe_commission_data t
     WHERE t.ap_full_paid_flag = 'N'
       AND nvl(t.cancelled_flag, 'N') = 'N';

  CURSOR c_stage_check IS
    SELECT *
      FROM xxoe_commission_data t
     WHERE t.current_stage_flag = 'Y'
       AND is_stage_final(t.stage_context) = 'N'
       AND t.stage_context NOT LIKE '%OVERAGE';

  CURSOR c_ap_open_lines(c_agent_id NUMBER) IS
    SELECT DISTINCT t.oe_line_id
      FROM xxoe_commission_data t
     WHERE -- t.rule_id IS NOT NULL
    -- AND
     t.stage_context != 'WAITING'
     AND t.agent_id = nvl(c_agent_id, agent_id)
     AND t.ap_full_paid_flag = 'N';
  --  AND t.oe_number = '163341';

  CURSOR c_ap_interface_lines IS
    SELECT DISTINCT t.ap_group_id
      FROM xxoe_commission_data t
     WHERE t.ap_group_status = 'INTERFACE';

  TYPE t_arr_char IS TABLE OF VARCHAR2(200) INDEX BY VARCHAR2(50);
  g_param_arr t_arr_char;

  TYPE party_ib_rec IS RECORD(
    base_count      NUMBER,
    total_sys_count NUMBER,
    from_date       DATE);

  TYPE t_party_rec IS TABLE OF party_ib_rec INDEX BY BINARY_INTEGER;

  TYPE t_agent_rec IS TABLE OF DATE INDEX BY BINARY_INTEGER;

  g_agent_arr t_agent_rec;
  g_party_arr t_party_rec;
  ------------------------------
  -- init_global
  -------------------------------
  PROCEDURE init_global IS
  
    CURSOR c IS
      SELECT s.salesrep_id agent_id,
             nvl(fnd_date.canonical_to_date(t.attribute4),
                 to_date('01-jan-2010', 'dd-mon-yyyy')) resin_start_date
      
        FROM jtf_rs_resource_extns t, jtf_rs_salesreps s, ra_salesreps sl
       WHERE s.salesrep_id = sl.salesrep_id --p_resource_id
         AND t.resource_id = s.resource_id;
  BEGIN
  
    -- BEGIN
    mo_global.set_org_context(p_org_id_char     => 89,
                              p_sp_id_char      => NULL,
                              p_appl_short_name => 'AR');
    --  END;
    FOR i IN c LOOP
      -- dbms_output.put_line(i.agent_id || ' ' || i.resin_start_date);
      g_agent_arr(i.agent_id) := i.resin_start_date;
    
    END LOOP;
  
  END;
  ------------------------------------
  -- get_upgrade_date
  ------------------------------------
  FUNCTION get_order_upgrade_date(p_order_number VARCHAR2) RETURN DATE IS
    l_tmp DATE;
    CURSOR c IS
      SELECT l.estimate_upgrade_date
        FROM xxcs_ib_upgrades_v l
       WHERE l.order_number = p_order_number
         AND l.estimate_upgrade_date IS NOT NULL;
  BEGIN
    OPEN c;
    FETCH c
      INTO l_tmp;
    CLOSE c;
    RETURN l_tmp;
  
  END;

  FUNCTION get_upgrade_date(p_instance_id NUMBER) RETURN DATE IS
    l_tmp DATE;
  BEGIN
  
    WITH att_id_tab AS
     (SELECT DISTINCT cie.attribute_id, cie.attribute_code
        FROM csi_i_extended_attribs cie,
             fnd_lookup_values      flv,
             xxcs_sales_ug_items_v  u
       WHERE cie.attribute_code = flv.lookup_code
         AND flv.language = 'US'
         AND flv.attribute1 = to_char(u.upgrade_item_id) --to_char(p_instance_rec.upgrade_kit)--'377010'--'225021' 
         AND flv.enabled_flag = 'Y'
         AND cie.attribute_level = 'CATEGORY'
         AND nvl(flv.end_date_active, SYSDATE + 1) > SYSDATE
         AND nvl(cie.active_end_date, SYSDATE + 1) > SYSDATE)
    SELECT MIN(to_date(attribute_value, 'dd-mon-yyyy')) upgrade_date
      INTO l_tmp
      FROM csi_inst_ext_attr_all_v t, att_id_tab
     WHERE src_instance_id = p_instance_id
       AND t.attribute_value IS NOT NULL
       AND t.attribute_id = att_id_tab.attribute_id
       AND (active_end_date IS NULL OR active_end_date > SYSDATE);
  
    RETURN l_tmp;
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END;
  --------------------------------------
  -- get_ap_info_desc 
  --------------------------------------
  FUNCTION get_ap_info_desc(p_type VARCHAR2, p_line_id NUMBER)
    RETURN VARCHAR2 IS
    l_tmp VARCHAR2(500);
  
    CURSOR c IS
      SELECT h.invoice_num, l.line_number
        FROM ap_invoices_all h, ap_invoice_lines_all l
       WHERE h.invoice_type_lookup_code = p_type
         AND h.invoice_id = l.invoice_id
         AND l.attribute5 = to_char(p_line_id)
         AND ap_invoices_pkg.get_approval_status(h.invoice_id,
                                                 h.invoice_amount,
                                                 h.payment_status_flag,
                                                 h.invoice_type_lookup_code) !=
             'CANCELLED';
  BEGIN
  
    FOR i IN c LOOP
      l_tmp := l_tmp || ',' || i.invoice_num || '-' || i.line_number;
    END LOOP;
  
    RETURN ltrim(l_tmp, ',');
  
  END;
  ------------------------------------
  -- get_order_invoice_type
  -----------------------------------

  FUNCTION get_line_invoice_type(p_line_id NUMBER) RETURN VARCHAR2 IS
    CURSOR c IS
      SELECT 'STANDARD'
        FROM xxoe_commission_data t
       WHERE t.oe_line_id = p_line_id
         AND xxoe_commission_calc.is_stage_final(t.stage_context) = 'Y';
    l_tmp VARCHAR2(20);
  
  BEGIN
  
    OPEN c;
    FETCH c
      INTO l_tmp;
    CLOSE c;
  
    RETURN nvl(l_tmp, 'PREPAYMENT');
  
  END;

  -------------------------------------
  -- get_param_type
  ------------------------------------
  FUNCTION get_param_type(p_param VARCHAR2) RETURN VARCHAR2 IS
    l_type VARCHAR2(10);
  BEGIN
    SELECT param_type
      INTO l_type
      FROM (SELECT p.attribute2 param_type
            
              FROM fnd_flex_values_vl p, fnd_flex_value_sets vs
             WHERE p.attribute1 = p_param
               AND p.flex_value_set_id = vs.flex_value_set_id
               AND vs.flex_value_set_name = 'XXOE_COMMISSION_PARAMETERS'
            UNION ALL
            SELECT param_type
              FROM xxoe_commission_dynamic_param p
             WHERE p.field_mapping = p_param);
  
    RETURN l_type;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 'C';
    
  END;

  -----------------------------------
  -- check_sql
  -----------------------------------
  PROCEDURE check_sql(p_sql VARCHAR2) IS
  
    l_val VARCHAR2(50);
  
  BEGIN
    EXECUTE IMMEDIATE p_sql
      USING 1, 2, 3, OUT l_val;
  
  END;

  ---------------------------------------
  -- get_param_desc
  ------------------------------------------
  FUNCTION get_param_desc(p_param VARCHAR2) RETURN VARCHAR2 IS
    l_desc VARCHAR2(100);
  BEGIN
  
    SELECT t.description
      INTO l_desc
      FROM fnd_flex_values_vl t, fnd_flex_value_sets vs
     WHERE t.flex_value_set_id = vs.flex_value_set_id
       AND vs.flex_value_set_name = 'XXOE_COMMISSION_PARAMETERS'
       AND t.attribute1 = p_param
    UNION ALL
    SELECT t.param_name
      FROM xxoe_commission_dynamic_param t
     WHERE t.field_mapping = p_param;
  
    RETURN l_desc;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END;

  ------------------------------------------
  -- get_item_type
  -------------------------------------------

  FUNCTION get_item_type(p_inventory_item_id NUMBER,
                         p_organization_id   NUMBER) RETURN VARCHAR2 IS
    CURSOR c IS
    
      SELECT msi.item_type
        FROM mtl_system_items_b msi
       WHERE msi.inventory_item_id = p_inventory_item_id
         AND msi.organization_id = p_organization_id;
    l_tmp VARCHAR2(50);
  BEGIN
  
    OPEN c;
    FETCH c
      INTO l_tmp;
    CLOSE c;
  
    RETURN l_tmp;
  
  END;
  -----------------------------------------
  -- get_vendor_info
  ----------------------------------------

  PROCEDURE get_vendor_info(p_err_code       OUT NUMBER,
                            p_err_msg        OUT VARCHAR2,
                            p_resource_id    NUMBER,
                            p_vendor_id      OUT NUMBER,
                            p_vendor_site_id OUT NUMBER,
                            p_vendor_name    OUT VARCHAR2,
                            p_ccid           OUT NUMBER,
                            p_inv_curr       OUT VARCHAR2) IS
  
  BEGIN
    p_err_code := 0;
    BEGIN
    
      SELECT t.attribute3
        INTO p_vendor_site_id
        FROM jtf_rs_resource_extns t, jtf_rs_salesreps s
       WHERE s.salesrep_id = p_resource_id
         AND t.resource_id = s.resource_id;
    EXCEPTION
      WHEN no_data_found THEN
        p_err_code := 1;
        p_err_msg  := 'Error : No vendor site found in table jtf_rs_resource_extns.attribute3 for agent';
        RETURN;
      
    END;
  
    SELECT t.vendor_id,
           tt.vendor_name,
           t.prepay_code_combination_id,
           t.invoice_currency_code
      INTO p_vendor_id, p_vendor_name, p_ccid, p_inv_curr
      FROM po_vendor_sites_all t, ap_vendors_v tt
     WHERE t.vendor_id = tt.vendor_id
       AND t.vendor_site_id = p_vendor_site_id;
  
    IF p_inv_curr IS NULL THEN
    
      SELECT h.base_currency_code
        INTO p_inv_curr
        FROM ap_system_parameters_all h
       WHERE h.org_id = fnd_global.org_id;
    
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code := 1;
      p_err_msg  := 'Error : No vendor info found  for agent: ' || SQLERRM;
  END;
  ---------------------------------------
  -- is_ap_interface_err_exist
  ----------------------------------------

  FUNCTION is_ap_interface_err_exist(p_group_id NUMBER) RETURN NUMBER IS
  
    CURSOR c IS
      SELECT 1
        FROM xxoe_inv_interface_err_v t
       WHERE t.group_id = p_group_id;
  
    l_tmp NUMBER;
  BEGIN
    OPEN c;
    FETCH c
      INTO l_tmp;
    CLOSE c;
  
    RETURN nvl(l_tmp, 0);
  
  END;
  ----------------------------------------
  -- is_stage_final
  ----------------------------------------

  FUNCTION is_stage_final(p_stage VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    IF p_stage LIKE 'COI%' OR p_stage = 'SHIPPED' THEN
      RETURN 'Y';
    ELSE
      RETURN 'N';
    END IF;
  
  END;
  -------------------------------------------
  -- is_rule_used
  ------------------------------------------
  FUNCTION is_rule_used(p_rule_id NUMBER, p_ver NUMBER) RETURN NUMBER IS
  
    CURSOR c IS
      SELECT 1
        FROM xxoe_commission_data t
       WHERE t.rule_id = p_rule_id
         AND t.rule_version = p_ver
         AND t.ap_full_paid_flag = 'Y';
    l_tmp NUMBER;
  BEGIN
  
    OPEN c;
    FETCH c
      INTO l_tmp;
    CLOSE c;
  
    RETURN nvl(l_tmp, 0);
  END;
  --------------------------------------------
  -- ENABLE_LAST_RULE
  -------------------------------------------
  PROCEDURE enable_last_rule(p_rule_id NUMBER, p_ver NUMBER) IS
  BEGIN
  
    UPDATE xxoe_commission_rules_header t
       SET t.last_version_flag = 'Y', t.version_end_date = NULL
     WHERE t.rule_id = p_rule_id
       AND t.rule_version = p_ver - 1;
    COMMIT;
  END;

  -------------------------------------------
  -- create_new_rule_version
  ------------------------------------------

  PROCEDURE create_new_rule_version(p_rule_id NUMBER, p_ver NUMBER) IS
  
  BEGIN
  
    UPDATE xxoe_commission_rules_header t
       SET t.last_version_flag = 'N', t.version_end_date = trunc(SYSDATE)
     WHERE t.rule_id = p_rule_id
       AND t.rule_version = p_ver;
  
    INSERT INTO xxoe_commission_rules_header
      (rule_id,
       rule_name,
       effective_from_date,
       effective_end_date,
       commission_pct,
       commission_pct_extra,
       commission_amount,
       last_version_flag,
       last_update_date,
       last_updated_by,
       creation_date,
       created_by,
       last_update_login,
       rule_seq,
       rule_version,
       version_start_date,
       version_end_date)
      SELECT rule_id,
             rule_name,
             effective_from_date,
             trunc(SYSDATE),
             commission_pct,
             commission_pct_extra,
             commission_amount,
             'Y', --last_version_flag,
             NULL,
             NULL,
             SYSDATE,
             fnd_global.user_id,
             fnd_global.login_id, --last_update_login,
             rule_seq,
             rule_version + 1,
             trunc(SYSDATE),
             NULL
        FROM xxoe_commission_rules_header t
       WHERE t.rule_id = p_rule_id
         AND t.rule_version = p_ver;
  
    INSERT INTO xxoe_commission_rules_lines t
      (rule_line_id,
       rule_id,
       
       rule_code,
       rule_condition,
       data_value,
       last_update_date,
       last_updated_by,
       creation_date,
       created_by,
       last_update_login,
       data_value2,
       rule_version)
      SELECT xxoe_commission_rules_l_seq.nextval,
             rule_id,
             rule_code,
             rule_condition,
             data_value,
             NULL, --last_update_date,
             NULL, --last_updated_by,
             SYSDATE, --creation_date,
             fnd_global.user_id,
             fnd_global.login_id,
             data_value2,
             rule_version + 1
        FROM xxoe_commission_rules_lines tt
       WHERE tt.rule_id = p_rule_id
         AND tt.rule_version = p_ver;
  
    COMMIT;
  END;
  -----------------------------------------------------
  -- copy_rule
  -----------------------------------------------------

  PROCEDURE copy_rule(p_rule_id NUMBER, p_ver NUMBER) IS
  BEGIN
  
    INSERT INTO xxoe_commission_rules_header
      (rule_id,
       rule_name,
       effective_from_date,
       effective_end_date,
       commission_pct,
       commission_pct_extra,
       commission_amount,
       last_version_flag,
       last_update_date,
       last_updated_by,
       creation_date,
       created_by,
       last_update_login,
       rule_seq,
       rule_version,
       version_start_date,
       version_end_date)
      SELECT xxoe_commission_rules_seq.nextval,
             rule_name,
             effective_from_date,
             trunc(SYSDATE),
             commission_pct,
             commission_pct_extra,
             commission_amount,
             'Y', --last_version_flag,
             NULL,
             NULL,
             SYSDATE,
             fnd_global.user_id,
             fnd_global.login_id, --last_update_login,
             rule_seq,
             0,
             trunc(SYSDATE),
             NULL
        FROM xxoe_commission_rules_header t
       WHERE t.rule_id = p_rule_id
         AND t.rule_version = p_ver;
  
    INSERT INTO xxoe_commission_rules_lines t
      (rule_line_id,
       rule_id,
       
       rule_code,
       rule_condition,
       data_value,
       last_update_date,
       last_updated_by,
       creation_date,
       created_by,
       last_update_login,
       data_value2,
       rule_version)
      SELECT xxoe_commission_rules_l_seq.nextval,
             xxoe_commission_rules_seq.currval,
             rule_code,
             rule_condition,
             data_value,
             NULL, --last_update_date,
             NULL, --last_updated_by,
             SYSDATE, --creation_date,
             fnd_global.user_id,
             fnd_global.login_id,
             data_value2,
             0
        FROM xxoe_commission_rules_lines tt
       WHERE tt.rule_id = p_rule_id
         AND tt.rule_version = p_ver;
  
    COMMIT;
  END;

  PROCEDURE init_param_arr(p_data c_calc_data%ROWTYPE) IS
  BEGIN
  
    g_param_arr('PARTY_ID') := p_data.party_id;
    g_param_arr('PARTY_NAME') := p_data.party_name;
    g_param_arr('AGENT_ID') := p_data.agent_id;
    g_param_arr('IS_INITIAL') := p_data.is_initial;
    g_param_arr('IS_IB_EXISTS') := p_data.is_ib_exists;
    g_param_arr('IS_AR_PAYMENTS_EXISTS') := p_data.is_ar_payments_exists;
    g_param_arr('SALESREP_ID') := p_data.salesrep_id;
    g_param_arr('CATEGORY_ID') := p_data.category_id;
    g_param_arr('INVENTORY_ITEM_ID') := p_data.inventory_item_id;
    g_param_arr('ORG_ID') := p_data.org_id;
    g_param_arr('AVERAGE_DISCOUNT') := p_data.average_discount;
    g_param_arr('MAIN_CATEGORY') := p_data.main_category;
    g_param_arr('CATEGORY_ID') := p_data.category_id;
    g_param_arr('ITEM_CODE') := p_data.item_code;
    g_param_arr('AGENT_NAME') := p_data.agent_name;
    g_param_arr('MAIN_CATEGORY') := p_data.main_category;
    g_param_arr('BILL_TO_PARTY_ID') := p_data.bill_to_party_id;
    g_param_arr('BILL_TO_NAME') := p_data.bill_to_name;
    g_param_arr('PRODUCT_LINE') := p_data.product_line;
    g_param_arr('ORDER_TYPE') := p_data.oe_line_status;
    g_param_arr('SO_LINE_STATUS') := p_data.oe_line_status;
    g_param_arr('IS_SPEC_19') := p_data.is_spec_19;
    g_param_arr('BOOKING_DATE') := p_data.booking_date;
    g_param_arr('SOLD_CUSTOMER_NAME') := p_data.sold_customer_name;
    g_param_arr('SOLD_ACCOUNT_ID') := p_data.sold_account_id;
    g_param_arr('SHIP_TO_NAME') := p_data.ship_to_name;
    g_param_arr('ORDER_TYPE_ID') := p_data.order_type_id;
    g_param_arr('ORDER_TYPE_NAME') := p_data.order_type_name;
    g_param_arr('SHIP_DATE') := p_data.ship_date;
    g_param_arr('IS_UPGRADE_ORDER') := p_data.is_upgrade_order;
    g_param_arr('IS_SOLD_TO_DEALER') := p_data.is_sold_to_dealer;
    g_param_arr('ORDER_SYSTEM_TYPE') := p_data.order_system_type;
  
    g_param_arr('D_ATTRIBUTE1') := p_data.d_attribute1;
    g_param_arr('D_ATTRIBUTE2') := p_data.d_attribute2;
    g_param_arr('D_ATTRIBUTE3') := p_data.d_attribute3;
    g_param_arr('D_ATTRIBUTE4') := p_data.d_attribute4;
    g_param_arr('D_ATTRIBUTE5') := p_data.d_attribute5;
    g_param_arr('D_ATTRIBUTE6') := p_data.d_attribute6;
    g_param_arr('D_ATTRIBUTE7') := p_data.d_attribute7;
    g_param_arr('D_ATTRIBUTE8') := p_data.d_attribute8;
    g_param_arr('D_ATTRIBUTE9') := p_data.d_attribute9;
    g_param_arr('D_ATTRIBUTE10') := p_data.d_attribute10;
  
  END;
  -----------------------------------------
  -- convert_records_type
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --  1.0  26.2.13    yuval tal         bugfix - Fix resin coupon commission and resin portion by site
  ----------------------------------------------------------------------------

  PROCEDURE convert_records_type(l_on_line_data_rec         c_data%ROWTYPE,
                                 l_xxoe_commission_data_rec IN OUT xxoe_commission_data%ROWTYPE) IS
    l_att2 VARCHAR2(100);
  
  BEGIN
  
    l_xxoe_commission_data_rec. oe_header_id := l_on_line_data_rec.header_id;
    l_xxoe_commission_data_rec. oe_number := l_on_line_data_rec.
                                             order_number;
    l_xxoe_commission_data_rec. oe_line_id := l_on_line_data_rec. line_id;
    l_xxoe_commission_data_rec.oe_line_number := l_on_line_data_rec.line_number;
    l_xxoe_commission_data_rec. oe_line_status := l_on_line_data_rec.
                                                  so_line_status;
    l_xxoe_commission_data_rec. inventory_item_id := l_on_line_data_rec.
                                                     inventory_item_id;
  
    l_xxoe_commission_data_rec.ship_date := l_on_line_data_rec.ship_date;
    l_xxoe_commission_data_rec.coi_date  := l_on_line_data_rec.coi_date;
    l_xxoe_commission_data_rec.item_code := l_on_line_data_rec. item_code;
  
    l_xxoe_commission_data_rec. item_desc := l_on_line_data_rec. item_desc; --ITEM_DESC;
    l_xxoe_commission_data_rec. order_date := l_on_line_data_rec.
                                              ordered_date; --order_date,;
    l_xxoe_commission_data_rec. booking_date := l_on_line_data_rec.
                                                booking_date;
  
    l_xxoe_commission_data_rec. order_line_number := l_on_line_data_rec.
                                                     line_number; --, --order_line_number,;
    l_xxoe_commission_data_rec. sold_account_id := l_on_line_data_rec.
                                                   sold_account_id;
    l_xxoe_commission_data_rec. sold_customer_number := l_on_line_data_rec.
                                                        sold_customer_number;
    l_xxoe_commission_data_rec. sold_customer_name := l_on_line_data_rec.
                                                      sold_customer_name;
    l_xxoe_commission_data_rec. ship_to_party_id := l_on_line_data_rec.
                                                    ship_to_party_id;
    l_xxoe_commission_data_rec. ship_to_name := l_on_line_data_rec.
                                                ship_to_name;
    l_xxoe_commission_data_rec. bill_to_party_id := l_on_line_data_rec.
                                                    bill_to_party_id;
    l_xxoe_commission_data_rec. bill_to_name := l_on_line_data_rec.
                                                bill_to_name;
    l_xxoe_commission_data_rec. salesrep_id := l_on_line_data_rec.
                                               salesrep_id;
    l_xxoe_commission_data_rec. salesrep_name := l_on_line_data_rec.
                                                 salesrep_name;
    l_xxoe_commission_data_rec. cancelled_flag := l_on_line_data_rec.
                                                  cancelled_flag;
  
    l_xxoe_commission_data_rec.order_system_type := l_on_line_data_rec.
                                                    order_system_type;
  
    l_xxoe_commission_data_rec. is_initial := l_on_line_data_rec.
                                              is_initial; --is_intial,;
    l_xxoe_commission_data_rec. is_ib_exists := l_on_line_data_rec.is_ib_exists;
    l_xxoe_commission_data_rec. order_type_id := l_on_line_data_rec.
                                                 order_type_id; --order_type_ID,;
    l_xxoe_commission_data_rec.order_type_name := l_on_line_data_rec.order_type;
  
    l_xxoe_commission_data_rec. org_id := l_on_line_data_rec. org_id; --org_id,;
    l_xxoe_commission_data_rec. agent_name := l_on_line_data_rec.
                                              agent_name; --agent_name,;
  
    l_xxoe_commission_data_rec.is_upgrade_order  := l_on_line_data_rec.is_upgrade_order;
    l_xxoe_commission_data_rec.is_sold_to_dealer := l_on_line_data_rec.is_sold_to_dealer;
    --  dbms_output.put_line(l_on_line_data_rec. average_discount);
    BEGIN
      /* l_xxoe_commission_data_rec. average_discount := l_on_line_data_rec.
      average_discount;*/
      -- avg discount
    
      l_xxoe_commission_data_rec.average_discount := nvl(xxoe_commission_calc.get_ar_avg_discount(l_xxoe_commission_data_rec.oe_number,
                                                                                                  l_xxoe_commission_data_rec.oe_line_id),
                                                         l_on_line_data_rec.average_discount);
    
    EXCEPTION
      WHEN OTHERS THEN
        l_xxoe_commission_data_rec. average_discount := NULL;
      
    END; --average_discount,;
  
    l_xxoe_commission_data_rec. agent_id := l_on_line_data_rec. agent_id; --Agent_Id,;
  
    l_xxoe_commission_data_rec. currency_code := l_on_line_data_rec.
                                                 transactional_curr_code; --currency_code,;
  
    l_xxoe_commission_data_rec. order_line_amount := l_on_line_data_rec.
                                                     extended_price; --order_line_amount;
    l_xxoe_commission_data_rec. order_line_amount_dist := l_on_line_data_rec.
                                                          dist_functional_amount; -- order_line_amount_dist,;
  
    l_xxoe_commission_data_rec.is_ar_payments_exists := l_on_line_data_rec.is_ar_payments_exists;
    l_xxoe_commission_data_rec.category_id           := l_on_line_data_rec.category_id;
    l_xxoe_commission_data_rec.main_category         := l_on_line_data_rec.main_category;
    l_xxoe_commission_data_rec.is_spec_19            := l_on_line_data_rec.is_spec_19;
    l_xxoe_commission_data_rec.product_line          := l_on_line_data_rec.product_line;
  
    l_xxoe_commission_data_rec.order_unit_list_price := l_on_line_data_rec.unit_list_price;
    l_xxoe_commission_data_rec.party_name            := l_on_line_data_rec.party_name;
    l_xxoe_commission_data_rec.party_id              := l_on_line_data_rec.party_id;
    l_xxoe_commission_data_rec.order_quantity        := l_on_line_data_rec.order_quantity;
    l_xxoe_commission_data_rec.unit_selling_price    := l_on_line_data_rec.unit_selling_price;
    l_xxoe_commission_data_rec.oe_line_attribute4    := l_on_line_data_rec.attribute4;
  
    -- amount manipulation
    BEGIN
      SELECT 'Y'
        INTO l_att2
        FROM oe_order_lines_all ol, oe_transaction_types_all ott
       WHERE ol.line_id = l_on_line_data_rec.line_id
         AND ol.header_id = l_on_line_data_rec.header_id
         AND ol.line_type_id = ott.transaction_type_id
         AND nvl(ott.attribute2, 'Y') = 'Y';
    EXCEPTION
      WHEN OTHERS THEN
        l_att2 := 'N';
    END;
    -- dbms_output.put_line('l_att2=' || l_att2);
  
    IF xxoe_utils_pkg.is_initial_order(l_on_line_data_rec.order_type_id) = 'Y' AND
       l_on_line_data_rec.order_quantity >= 0 AND
       l_on_line_data_rec.unit_selling_price >= 0 AND
       get_item_type(l_on_line_data_rec.inventory_item_id,
                     l_on_line_data_rec.ship_from_org_id) NOT IN
       (fnd_profile.value('XXAR PREPAYMENT ITEM TYPES'),
        fnd_profile.value('XXAR_FREIGHT_AR_ITEM'))
      
       AND l_att2 = 'Y' THEN
      l_xxoe_commission_data_rec.avg_discount_flag := 'Y';
      -- do average manipulation
    
      l_xxoe_commission_data_rec.order_line_amount_dist := round(xxar_autoinvoice_pkg.get_price_list_for_resin(l_on_line_data_rec.line_id,
                                                                                                               l_on_line_data_rec.unit_list_price,
                                                                                                               l_on_line_data_rec.attribute4) *
                                                                 l_on_line_data_rec.order_quantity *
                                                                 (100 -
                                                                  nvl(l_xxoe_commission_data_rec.
                                                                      average_discount,
                                                                      0)) / 100,
                                                                 2);
    ELSE
    
      l_xxoe_commission_data_rec.order_line_amount_dist := l_on_line_data_rec.unit_selling_price *
                                                           l_on_line_data_rec.order_quantity;
    END IF;
    l_xxoe_commission_data_rec.order_line_amount_dist_orig := l_xxoe_commission_data_rec.order_line_amount_dist;
  
    IF l_on_line_data_rec.agent_id IS NULL THEN
      l_xxoe_commission_data_rec.ap_full_paid_flag := 'Y';
      RETURN;
    END IF;
  
    ------------ DYN SQL -------------------------
  
    DECLARE
      l_value VARCHAR2(50);
      --  l_sql   xxoe_commission_dynamic_param.dyn_sql%TYPE;
    BEGIN
    
      FOR i IN c_sql LOOP
        g_xxoe_commission_data_rec := l_xxoe_commission_data_rec;
        -- dbms_output.put_line(i.dyn_sql);
      
        EXECUTE IMMEDIATE i.dyn_sql
          USING l_on_line_data_rec.inventory_item_id, l_on_line_data_rec.header_id, l_on_line_data_rec.line_id, OUT l_value;
      
        -- dbms_output.put_line('l_value=' || l_value);
      
        CASE i.field_mapping
          WHEN 'D_ATTRIBUTE1' THEN
            l_xxoe_commission_data_rec.d_attribute1 := l_value;
          WHEN 'D_ATTRIBUTE2' THEN
            l_xxoe_commission_data_rec.d_attribute2 := l_value;
          WHEN 'D_ATTRIBUTE3' THEN
            l_xxoe_commission_data_rec.d_attribute3 := l_value;
          WHEN 'D_ATTRIBUTE4' THEN
            l_xxoe_commission_data_rec.d_attribute4 := l_value;
          WHEN 'D_ATTRIBUTE5' THEN
            l_xxoe_commission_data_rec.d_attribute5 := l_value;
          WHEN 'D_ATTRIBUTE6' THEN
            l_xxoe_commission_data_rec.d_attribute6 := l_value;
          WHEN 'D_ATTRIBUTE7' THEN
            l_xxoe_commission_data_rec.d_attribute7 := l_value;
          WHEN 'D_ATTRIBUTE8' THEN
            l_xxoe_commission_data_rec.d_attribute8 := l_value;
          WHEN 'D_ATTRIBUTE9' THEN
            l_xxoe_commission_data_rec.d_attribute9 := l_value;
          WHEN 'D_ATTRIBUTE10' THEN
            l_xxoe_commission_data_rec.d_attribute10 := l_value;
        END CASE;
      
      END LOOP;
      --  EXCEPTION !!!! get resin portion if needed
      -- portion only on connex !!!
      IF l_on_line_data_rec.org_id = 89 AND
         l_on_line_data_rec.item_code NOT LIKE 'OBJ-04%' AND
         l_xxoe_commission_data_rec.d_attribute2 != 'Y' AND -- not resin credit for desktop
         l_on_line_data_rec.is_initial = 'N' AND
         l_on_line_data_rec.order_type = 'Standard Resins, US' THEN
        count_e_c_sys_printers(p_agent_id    => l_on_line_data_rec.agent_id,
                               p_party_id    => l_on_line_data_rec.party_id,
                               p_base_count  => l_xxoe_commission_data_rec.edden_conn_sys_base,
                               p_total_count => l_xxoe_commission_data_rec.edden_conn_sys_total);
      
        IF l_xxoe_commission_data_rec.edden_conn_sys_total = 0 THEN
          l_xxoe_commission_data_rec.resin_portion := 0;
        ELSE
        
          l_xxoe_commission_data_rec.resin_portion := round(l_xxoe_commission_data_rec.edden_conn_sys_base /
                                                            l_xxoe_commission_data_rec.edden_conn_sys_total,
                                                            2);
        END IF;
      
      END IF;
    
    END;
    --------------------------------------------------------
  
    --  dbms_output.put_line('l_xxoe_commission_data_rec.order_line_amount_dist=' ||
    --        l_xxoe_commission_data_rec.order_line_amount_dist);
  
  EXCEPTION
    WHEN OTHERS THEN
      IF l_on_line_data_rec.agent_id IS NULL THEN
        l_xxoe_commission_data_rec.ap_full_paid_flag := 'Y';
      END IF;
      l_xxoe_commission_data_rec.err_flag := 'Y';
      l_xxoe_commission_data_rec.err_msg  := 'error in convert_recod_type :' ||
                                             SQLERRM;
  END;
  ----------------------------------------
  -- insert new stage
  ----------------------------------------

  PROCEDURE insert_new_stage(p_new_stage     VARCHAR2,
                             p_data          c_data%ROWTYPE,
                             p_comm_pct      NUMBER,
                             p_comm_override VARCHAR2,
                             p_rule_id       NUMBER,
                             p_rule_ver      NUMBER) IS
    l_upd_rec xxoe_commission_data%ROWTYPE;
  BEGIN
  
    convert_records_type(p_data, l_upd_rec);
    l_upd_rec.creation_date         := SYSDATE + 0.001;
    l_upd_rec.stage_context         := p_new_stage;
    l_upd_rec.stage_pct             := get_stage_pct(p_new_stage);
    l_upd_rec.commission_pct        := p_comm_pct;
    l_upd_rec.commission_to_pay_pct := l_upd_rec.stage_pct *
                                       l_upd_rec.commission_pct / 100;
    l_upd_rec.manual_comm_override  := p_comm_override;
    l_upd_rec.created_by            := fnd_global.user_id;
    l_upd_rec.rule_id               := p_rule_id;
    l_upd_rec.rule_version          := p_rule_ver;
    l_upd_rec.current_stage_flag    := 'Y';
    l_upd_rec.cancelled_flag        := 'N';
    l_upd_rec.close_flag            := 'N';
    l_upd_rec.ap_full_paid_flag     := 'N';
    INSERT INTO xxoe_commission_data VALUES l_upd_rec;
    COMMIT;
  END;

  --------------------------------
  -- chek_in_value
  --------------------------------

  FUNCTION check_in_value(p_chk VARCHAR2, p_string VARCHAR2) RETURN BOOLEAN IS
    CURSOR c IS
      SELECT 1
        FROM (SELECT TRIM(substr(txt,
                                 instr(txt, ';', 1, LEVEL) + 1,
                                 instr(txt, ';', 1, LEVEL + 1) -
                                 instr(txt, ';', 1, LEVEL) - 1)) AS token
                FROM (SELECT ';' || p_string || ';' AS txt FROM dual)
              CONNECT BY LEVEL <=
                         length(txt) - length(REPLACE(txt, ';', '')) - 1)
       WHERE token = p_chk;
    l_tmp NUMBER;
  BEGIN
    OPEN c;
    FETCH c
      INTO l_tmp;
    CLOSE c;
  
    IF nvl(l_tmp, 0) = 1 THEN
      RETURN TRUE;
    ELSE
      RETURN FALSE;
    END IF;
  END;
  -----------------------------------------
  -- insert_history
  -----------------------------------------

  PROCEDURE insert_history(p_rec xxoe_commission_data%ROWTYPE) IS
    l_rec xxoe_commission_data%ROWTYPE := p_rec;
  BEGIN
    IF p_rec.ar_invoice_number IS NOT NULL OR
       p_rec.manual_comm_override = 'Y' THEN
      l_rec.creation_date := SYSDATE;
      INSERT INTO xxoe_commission_data_his VALUES l_rec;
      COMMIT;
    END IF;
  END;

  ------------------------------------
  -- calc_commission
  -----------------------------------
  PROCEDURE calc_commission(p_rec         xxoe_commission_data%ROWTYPE /* c_data%ROWTYPE*/,
                            p_comm        OUT NUMBER,
                            p_comm_extra  OUT NUMBER,
                            p_comm_amount OUT NUMBER,
                            p_rule_id     OUT NUMBER,
                            p_rule_ver    OUT NUMBER,
                            p_err_code    OUT NUMBER,
                            p_err_message OUT VARCHAR2) IS
  
    CURSOR c_h IS
      SELECT t.rule_id,
             t.rule_name,
             t.commission_pct,
             t.commission_pct_extra,
             t.rule_version,
             t.commission_amount
      
        FROM xxoe_commission_rules_header t
       WHERE p_rec.order_date BETWEEN t.effective_from_date AND
            
             t.effective_end_date
         AND t.last_version_flag = 'Y'
       ORDER BY rule_seq;
  
    CURSOR c_l(c_rule_id NUMBER) IS
      SELECT t.commission_pct,
             
             l.rule_line_id,
             l.rule_id,
             l.rule_code,
             l.rule_condition,
             l.data_value,
             l.data_value2,
             get_param_type(l.rule_code) param_type
        FROM xxoe_commission_rules_header t, xxoe_commission_rules_lines l
      
       WHERE l.rule_id = t.rule_id
         AND t.rule_version = l.rule_version
         AND t.rule_id = c_rule_id
         AND t.last_version_flag = 'Y';
  
    l_boolean BOOLEAN := TRUE;
    myexit EXCEPTION;
  
  BEGIN
    p_err_code := 0;
  
    init_param_arr(p_rec);
  
    FOR h IN c_h LOOP
    
      l_boolean := TRUE;
    
      FOR l IN c_l(h.rule_id) LOOP
        /* dbms_output.put_line(l.rule_code || '=' ||
        g_param_arr(l.rule_code) || ' l.data_value=' ||
        l.data_value);*/
        BEGIN
        
          CASE l.rule_condition
            WHEN '=' THEN
              l_boolean := l_boolean AND
                           CASE l.param_type
                             WHEN 'N' THEN
                              to_number(g_param_arr(l.rule_code)) =
                              to_number(l.data_value)
                             ELSE
                              g_param_arr(l.rule_code) = l.data_value
                           END;
            WHEN '<>' THEN
              l_boolean := l_boolean AND
                           CASE l.param_type
                             WHEN 'N' THEN
                              to_number(g_param_arr(l.rule_code)) <>
                              to_number(l.data_value)
                             ELSE
                              g_param_arr(l.rule_code) <> l.data_value
                           END;
            
            WHEN '<' THEN
              l_boolean := l_boolean AND
                           CASE l.param_type
                             WHEN 'N' THEN
                              to_number(g_param_arr(l.rule_code)) <
                              to_number(l.data_value)
                             ELSE
                              g_param_arr(l.rule_code) < l.data_value
                           END;
            
            WHEN '>' THEN
              l_boolean := l_boolean AND
                           CASE l.param_type
                             WHEN 'N' THEN
                              to_number(g_param_arr(l.rule_code)) >
                              to_number(l.data_value)
                             ELSE
                              g_param_arr(l.rule_code) > l.data_value
                           END;
            
            WHEN '<=' THEN
              l_boolean := l_boolean AND
                           CASE l.param_type
                             WHEN 'N' THEN
                              to_number(g_param_arr(l.rule_code)) <=
                              to_number(l.data_value)
                             ELSE
                              g_param_arr(l.rule_code) <= l.data_value
                           END;
            
            WHEN '>=' THEN
              l_boolean := l_boolean AND
                           CASE l.param_type
                             WHEN 'N' THEN
                              to_number(g_param_arr(l.rule_code)) >=
                              to_number(l.data_value)
                             ELSE
                              g_param_arr(l.rule_code) >= l.data_value
                           END;
            
            WHEN 'BETWEEN' THEN
              l_boolean := l_boolean AND
                           g_param_arr(l.rule_code) BETWEEN l.data_value AND
                           l.data_value2;
            
              l_boolean := l_boolean AND CASE l.param_type
                             WHEN 'N' THEN
                              to_number(g_param_arr(l.rule_code)) BETWEEN
                              to_number(l.data_value) AND
                              to_number(l.data_value2)
                             ELSE
                              g_param_arr(l.rule_code) BETWEEN
                              l.data_value AND l.data_value2
                           END;
            
            WHEN 'LIKE' THEN
            
              l_boolean := l_boolean AND
                           g_param_arr(l.rule_code) LIKE l.data_value;
            
            WHEN 'IN' THEN
            
              l_boolean := l_boolean AND
                           check_in_value(g_param_arr(l.rule_code),
                                          l.data_value);
            
            WHEN 'NOT IN' THEN
            
              l_boolean := l_boolean AND
                           NOT check_in_value(g_param_arr(l.rule_code),
                                              l.data_value);
            WHEN 'NOT LIKE' THEN
              l_boolean := l_boolean AND
                           g_param_arr(l.rule_code) NOT LIKE l.data_value;
          END CASE;
        EXCEPTION
          WHEN no_data_found THEN
            p_err_code    := 1;
            p_err_message := 'Missing mapping for ' || l.rule_code ||
                            
                             ' in procedure init_param_arr';
            RAISE myexit;
          WHEN OTHERS THEN
            p_err_code    := 1;
            p_err_message := SQLERRM ||
                             (l.rule_condition ||
                             ' l.rule_code =
                                 ' ||
                             l.rule_code || 'g_param_arr(l.rule_code)=' ||
                             g_param_arr(l.rule_code) || ' data_value=' ||
                             l.data_value);
            RAISE myexit;
        END;
      END LOOP;
    
      IF l_boolean THEN
        --        dbms_output.put_line('p_comm=' || h.commission_pct);
        p_rule_id     := h.rule_id;
        p_comm        := h.commission_pct;
        p_comm_extra  := h.commission_pct_extra;
        p_rule_ver    := h.rule_version;
        p_comm_amount := h.commission_amount;
        EXIT;
      ELSE
        NULL;
        --  p_comm    := 0;
        --  p_rule_id := 0;
      
      END IF;
    
    END LOOP;
  
    -- p_comm    := 0;
    -- p_rule_id := 0;
  EXCEPTION
    WHEN myexit THEN
      NULL;
    
    WHEN OTHERS THEN
      p_err_code    := 1;
      p_err_message := SQLERRM;
  END;

  ---------------------------------------
  -- get_shipped_date
  --
  -- 1.1 27.02.13 yuval tal     bugfix if item not shippable check if one of other items is shipped 
  ---------------------------------------

  FUNCTION get_shipped_date(p_line_id NUMBER) RETURN DATE IS
  
    CURSOR c IS
      SELECT msib.shippable_item_flag,
             -- decode(nvl(msib.shippable_item_flag, 'N'),
             --     'Y',
             ool.actual_shipment_date
      -- ool.fulfillment_date --) -- 'Y'
        FROM oe_order_lines_all   ool,
             wsh_delivery_details dd,
             mtl_system_items_b   msib
       WHERE msib.organization_id = 91
         AND msib.inventory_item_id = ool.inventory_item_id
         AND dd.source_line_id(+) = ool.line_id
         AND dd.source_header_id(+) = ool.header_id
         AND dd.inv_interfaced_flag(+) IN ('X', 'Y')
         AND ool.line_id = p_line_id;
  
    CURSOR c_unship_check IS
      SELECT ool.actual_shipment_date
      
        FROM oe_order_lines_all   ool,
             oe_order_lines_all   ool2,
             wsh_delivery_details dd,
             mtl_system_items_b   msib
       WHERE msib.organization_id = 91
         AND msib.inventory_item_id = ool.inventory_item_id
         AND dd.source_line_id(+) = ool.line_id
         AND dd.source_header_id(+) = ool.header_id
         AND dd.inv_interfaced_flag(+) IN ('X', 'Y')
         AND ool2.line_id = p_line_id
         AND ool.header_id = ool2.header_id
         AND ool.actual_shipment_date IS NOT NULL
         AND msib.shippable_item_flag = 'Y'
         AND msib.item_type NOT IN
             (fnd_profile.value('XXAR PREPAYMENT ITEM TYPES'),
              fnd_profile.value('XXAR_FREIGHT_AR_ITEM'));
  
    l_tmp                 DATE;
    l_shippable_item_flag VARCHAR2(1);
  BEGIN
    OPEN c;
  
    FETCH c
      INTO l_shippable_item_flag, l_tmp;
    CLOSE c;
  
    -- non shipable item logic
    IF l_shippable_item_flag = 'N' THEN
      l_tmp := NULL;
      OPEN c_unship_check;
    
      FETCH c_unship_check
        INTO l_tmp;
    
      CLOSE c_unship_check;
    END IF;
    RETURN l_tmp;
  
  END;

  ---------------------------------------
  -- get ar avg discount
  --------------------------------------

  FUNCTION get_ar_avg_discount(p_order_number VARCHAR2, p_line_id NUMBER)
    RETURN VARCHAR2 IS
    l_tmp VARCHAR2(20);
  BEGIN
    SELECT l.attribute10
      INTO l_tmp
      FROM ra_customer_trx_lines_all l, ra_customer_trx_all hh --,
    --  ra_cust_trx_line_gl_dist_all k
     WHERE -- k.customer_trx_id = l.customer_trx_id
    --  AND k.customer_trx_line_id = l.customer_trx_line_id
     hh.customer_trx_id = l.customer_trx_id
    --  AND k.account_class = 'REV'
    -- AND k.amount IS NOT NULL
     AND l.sales_order = p_order_number
     AND l.interface_line_attribute6 = p_line_id
     AND rownum = 1;
  
    RETURN l_tmp;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END;

  -------------------------------------
  -- get_ar_info
  --------------------------------------

  PROCEDURE get_ar_info(p_order_number     VARCHAR2,
                        p_line_id          NUMBER,
                        p_org_id           NUMBER,
                        p_amount           OUT NUMBER,
                        p_inv_number       OUT VARCHAR2,
                        p_inv_line_number  OUT NUMBER,
                        p_inv_paid_flag    OUT VARCHAR2,
                        p_inv_date         OUT DATE,
                        p_avg_discount_pct OUT NUMBER,
                        p_err_code         OUT NUMBER,
                        p_err_message      OUT VARCHAR2) IS
    l_customer_trx_id NUMBER;
  BEGIN
    p_err_message      := '';
    p_err_code         := 0;
    p_amount           := NULL;
    p_inv_number       := NULL;
    p_inv_line_number  := NULL;
    p_inv_date         := NULL;
    p_avg_discount_pct := NULL;
    SELECT SUM(k.amount),
           l.attribute10,
           hh.trx_date,
           hh.trx_number, -- inv number
           --  hh.customer_trx_id,
           --  l.customer_trx_line_id,       
           --  nvl(quantity_invoiced, l.quantity_credited) * l.unit_selling_price,       
           l.line_number, -- inv line number,
           hh.customer_trx_id
    --  l.interface_line_attribute6 -- oe line id
      INTO p_amount,
           p_avg_discount_pct,
           p_inv_date,
           p_inv_number,
           p_inv_line_number,
           l_customer_trx_id
      FROM ra_customer_trx_lines_all    l,
           ra_customer_trx_all          hh,
           ra_cust_trx_line_gl_dist_all k
     WHERE l.org_id = p_org_id
       AND k.customer_trx_id = l.customer_trx_id
       AND k.customer_trx_line_id = l.customer_trx_line_id
       AND hh.customer_trx_id = l.customer_trx_id
       AND k.account_class = 'REV'
       AND k.amount IS NOT NULL
       AND l.sales_order = p_order_number
       AND l.interface_line_attribute6 = p_line_id
     GROUP BY l.attribute10,
              hh.trx_date,
              hh.trx_number, -- inv number                 
              l.line_number, -- inv line number,
              hh.customer_trx_id;
  
    BEGIN
    
      SELECT 'N'
        INTO p_inv_paid_flag
        FROM ar_payment_schedules_all g
       WHERE g.customer_trx_id = l_customer_trx_id
            -- AND g.amount_applied > 0
         AND g.amount_due_remaining != 0;
    EXCEPTION
      WHEN no_data_found THEN
        p_inv_paid_flag := 'Y';
      WHEN too_many_rows THEN
        p_inv_paid_flag := 'N';
    END;
  
  EXCEPTION
  
    WHEN no_data_found THEN
      p_inv_paid_flag := 'N';
    WHEN OTHERS THEN
      p_err_message := SQLERRM;
      p_err_code    := 1;
    
  END;
  --------------------------------
  -- is_ar_payments_exists
  ----------------------------------

  FUNCTION is_ar_payments_exists(p_order_number VARCHAR2,
                                 p_line_id      NUMBER,
                                 p_org_id       NUMBER) RETURN VARCHAR2 IS
  
    l_amount           NUMBER;
    l_inv_number       NUMBER;
    l_inv_line_number  NUMBER;
    l_inv_paid_flag    VARCHAR2(1);
    l_inv_date         DATE;
    l_err_code         NUMBER;
    l_err_message      VARCHAR2(500);
    l_avg_discount_pct NUMBER;
  BEGIN
    xxoe_commission_calc.get_ar_info(p_order_number     => p_order_number,
                                     p_line_id          => p_line_id,
                                     p_org_id           => p_org_id,
                                     p_amount           => l_amount,
                                     p_inv_number       => l_inv_number,
                                     p_inv_line_number  => l_inv_line_number,
                                     p_inv_paid_flag    => l_inv_paid_flag,
                                     p_inv_date         => l_inv_date,
                                     p_avg_discount_pct => l_avg_discount_pct,
                                     p_err_code         => l_err_code,
                                     p_err_message      => l_err_message);
    RETURN l_inv_paid_flag;
  
  END;

  --------------------------------
  -- is_ar_inv_exists
  ----------------------------------

  FUNCTION is_ar_inv_exists(p_order_number VARCHAR2,
                            p_line_id      NUMBER,
                            p_org_id       NUMBER) RETURN VARCHAR2 IS
  
    l_amount           NUMBER;
    l_inv_number       NUMBER;
    l_inv_line_number  NUMBER;
    l_inv_paid_flag    VARCHAR2(1);
    l_err_code         NUMBER;
    l_inv_date         DATE;
    l_err_message      VARCHAR2(500);
    l_avg_discount_pct NUMBER;
  BEGIN
    xxoe_commission_calc.get_ar_info(p_order_number     => p_order_number,
                                     p_line_id          => p_line_id,
                                     p_org_id           => p_org_id,
                                     p_amount           => l_amount,
                                     p_inv_number       => l_inv_number,
                                     p_inv_line_number  => l_inv_line_number,
                                     p_inv_paid_flag    => l_inv_paid_flag,
                                     p_inv_date         => l_inv_date,
                                     p_avg_discount_pct => l_avg_discount_pct,
                                     p_err_code         => l_err_code,
                                     p_err_message      => l_err_message);
    RETURN CASE nvl(l_inv_number, '-1') WHEN '-1' THEN 'N' ELSE 'Y' END;
  
  END;
  ------------------------------------
  -- get_stage_pct
  ------------------------------------
  FUNCTION get_stage_pct(p_stage VARCHAR2) RETURN NUMBER IS
  BEGIN
    CASE p_stage
    
      WHEN 'BOOKED' THEN
        RETURN 50;
      WHEN 'SHIPPED' THEN
        RETURN 100;
      WHEN 'WAITING' THEN
        RETURN 0;
      WHEN 'COI' THEN
        RETURN 50;
      ELSE
        RETURN 0;
    END CASE;
  
  END;
  ------------------------------------
  -- get_stage_context
  ------------------------------------
  FUNCTION get_stage_context(p_rec c_data%ROWTYPE) RETURN VARCHAR2 IS
  BEGIN
  
    -- DBMS_OUTPUT.PUT_LINE('is_initial='||p_rec.is_initial);
  
    IF (p_rec.is_upgrade_order = 'Y' AND
       get_order_upgrade_date(p_rec.so_number) < SYSDATE) OR
       (p_rec.is_initial = 'Y' AND
       (p_rec.ship_date IS NOT NULL AND p_rec.booking_date >= '03-dec-12') OR
       (p_rec.is_ib_exists = 'Y' AND p_rec.booking_date < '03-dec-12')) THEN
      RETURN 'COI';
    ELSIF (p_rec.is_upgrade_order = 'Y' OR p_rec.is_initial = 'Y') AND
          p_rec.so_line_status IN
          ( --'CANCELLED',
           'BOOKED',
           'AWAITING_SHIPPING',
           'CLOSED',
           'INVOICE_HOLD',
           'AWAITING_FULFILLMENT') THEN
      RETURN 'BOOKED';
    
    ELSIF p_rec.is_initial = 'N' AND p_rec.ship_date IS NOT NULL /*is_shipped(p_rec.line_id) = 'Y'*/
          AND
          is_ar_inv_exists(p_rec.order_number, p_rec.line_id, p_rec.org_id) = 'Y' THEN
      RETURN 'SHIPPED';
    ELSE
      /*IF p_rec.is_initial = 'N' */
      --  THEN
      RETURN 'WAITING';
      -- ELSE
      --   RETURN NULL;
    END IF;
  
  END;
  ----------------------------------
  -- is_initial_order
  ----------------------------------

  FUNCTION is_initial_order(p_oe_header_id NUMBER) RETURN VARCHAR2 IS
  
    CURSOR c IS
      SELECT 'Y'
        FROM mtl_cross_references_v r, oe_order_lines_all l
       WHERE l.header_id = p_oe_header_id
         AND r.inventory_item_id = l.inventory_item_id
         AND r.cross_reference_type = 'Bi Item type'
         AND r.cross_reference = 'System'
            --  AND r.attribute3 <> 'Desktop'
         AND l.cancelled_flag = 'N';
    l_tmp VARCHAR2(1);
  BEGIN
    OPEN c;
    FETCH c
      INTO l_tmp;
    CLOSE c;
    RETURN nvl(l_tmp, 'N');
  
  END;

  -----------------------------------
  -- get_order_system_type
  -----------------------------------
  FUNCTION get_order_system_type(p_oe_header_id NUMBER) RETURN VARCHAR2 IS
    l_family VARCHAR2(50);
    CURSOR c IS
      SELECT inventory_item_id
        FROM oe_order_lines_all t
       WHERE t.header_id = p_oe_header_id
         AND t.line_category_code != 'RETURN'
         AND nvl(t.cancelled_flag, 'N') = 'N';
  BEGIN
    FOR i IN c LOOP
      l_family := xxinv_item_classification.get_item_system_sub_family2(i.inventory_item_id);
      IF l_family IS NOT NULL THEN
        RETURN l_family;
      END IF;
    
    END LOOP;
  
    RETURN NULL;
  
  END;

  -----------------------------
  -- IS_DEALER
  -----------------------------
  FUNCTION is_dealer(p_party_id NUMBER, p_to_date DATE DEFAULT SYSDATE)
    RETURN VARCHAR2 IS
    CURSOR c_dealer IS
      SELECT 'Y'
        FROM hz_code_assignments hcodeass
       WHERE hcodeass.class_category = 'Objet Business Type'
         AND hcodeass.status = 'A'
         AND hcodeass.class_code IN ('Agent', 'Distributor', 'DISTRIBUTOR')
         AND hcodeass.owner_table_id = p_party_id
         AND p_to_date BETWEEN hcodeass.start_date_active AND
             nvl(hcodeass.end_date_active, p_to_date + 1)
         AND hcodeass.owner_table_name = 'HZ_PARTIES';
  
    l_tmp VARCHAR2(1);
  BEGIN
    OPEN c_dealer;
    FETCH c_dealer
      INTO l_tmp;
    CLOSE c_dealer;
    RETURN nvl(l_tmp, 'N');
  END;

  ------------------------------
  -- is_upgrade_order
  -------------------------------
  FUNCTION is_upgrade_order(p_oe_header_id NUMBER) RETURN VARCHAR2 IS
  
    CURSOR c IS
      SELECT 'Y'
        FROM xxcs_sales_ug_items_v u, oe_order_lines_all d
       WHERE u.upgrade_item_id = d.inventory_item_id
         AND d.header_id = p_oe_header_id
         AND d.cancelled_flag = 'N';
    l_tmp VARCHAR2(1);
  BEGIN
    OPEN c;
    FETCH c
      INTO l_tmp;
    CLOSE c;
    RETURN nvl(l_tmp, 'N');
  END;

  ---------------------------------
  -- get_coi_status
  ---------------------------------

  FUNCTION is_ib_exists(p_header_id NUMBER) RETURN VARCHAR2 IS
    CURSOR c_status IS
      SELECT 'Y'
      
        FROM csi_item_instances t, oe_order_lines_all l
       WHERE l.line_id = t.last_oe_order_line_id
         AND l.header_id = p_header_id
         AND t.install_date IS NOT NULL;
  
    l_tmp VARCHAR2(10);
  BEGIN
    OPEN c_status;
    FETCH c_status
      INTO l_tmp;
    CLOSE c_status;
  
    RETURN nvl(l_tmp, 'N');
  END;

  ---------------------------------
  -- get_coi_date
  ---------------------------------

  FUNCTION get_coi_date(p_header_id NUMBER) RETURN DATE IS
    CURSOR c_status IS
      SELECT install_date
      
        FROM csi_item_instances t, oe_order_lines_all l
       WHERE l.line_id = t.last_oe_order_line_id
         AND l.header_id = p_header_id
         AND t.install_date IS NOT NULL;
  
    l_tmp DATE;
  BEGIN
    OPEN c_status;
    FETCH c_status
      INTO l_tmp;
    CLOSE c_status;
  
    RETURN l_tmp;
  END;

  ----------------------------------
  -- delta
  ----------------------------------
  PROCEDURE delta(p_err_code OUT NUMBER, p_err_message OUT VARCHAR2) IS
    -- l_stage        VARCHAR2(20);
    l_counter      NUMBER := 0;
    l_data_rec     xxoe_commission_data%ROWTYPE;
    l_ol_rec       c_data%ROWTYPE;
    l_ret          BOOLEAN;
    l_last_line_id NUMBER;
    l_from_line_id NUMBER := fnd_profile.value('XXOECOMM_LASTID');
    -- l_att2         VARCHAR2(50);
    l_curr_line_id NUMBER;
  BEGIN
    p_err_code := 0;
  
    COMMIT;
    FOR i IN c_delta(l_from_line_id) LOOP
      BEGIN
        l_curr_line_id := i.line_id;
        l_ol_rec       := i;
        l_data_rec     := NULL;
        --  dbms_output.put_line('0');
        convert_records_type(l_ol_rec, l_data_rec);
        --  dbms_output.put_line('0');
      
        l_data_rec.created_by        := fnd_global.user_id;
        l_data_rec.creation_date     := SYSDATE;
        l_data_rec.last_update_login := fnd_global.login_id;
        l_data_rec.stage_context     := 'WAITING'; --get_stage_context(i);
        /* CASE
          WHEN (i.is_initial = 'Y' OR
               i.is_upgrade_order = 'Y') THEN
          
           'BOOKED'
          ELSE
           'WAITING'
        END;*/
        l_data_rec.stage_pct          := get_stage_pct(l_data_rec.stage_context);
        l_data_rec.close_flag         := 'N';
        l_data_rec.current_stage_flag := 'Y';
        l_data_rec.ap_full_paid_flag  := CASE l_data_rec.stage_pct
                                           WHEN 0 THEN
                                            'Y'
                                           ELSE
                                            'N'
                                         END;
      
        INSERT INTO xxoe_commission_data VALUES l_data_rec;
        l_counter := l_counter + 1;
      
      EXCEPTION
        WHEN dup_val_on_index THEN
          NULL;
        
        WHEN OTHERS THEN
          fnd_file.put_line(fnd_file.log,
                            'header_id=' || i.header_id || ' line_id=' ||
                            i.line_id || ' sqlerrm=' || SQLERRM);
        
          p_err_code    := 1;
          p_err_message := 'See error log ' || SQLERRM;
      END;
    
      l_last_line_id := greatest(i.line_id, nvl(l_last_line_id, 0));
    END LOOP;
  
    IF p_err_code = 1 THEN
      ROLLBACK;
    ELSE
      p_err_message := l_counter || ' rows loaded';
      l_ret         := fnd_profile_server.save(x_name       => 'XXOECOMM_LASTID',
                                               x_value      => nvl(l_last_line_id,
                                                                   l_from_line_id),
                                               x_level_name => 'SITE');
    END IF;
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
    
      --  send mail alert
      l_ret      := fnd_profile_server.save(x_name       => 'XXOECOMM_LASTID',
                                            x_value      => l_last_line_id,
                                            x_level_name => 'SITE');
      p_err_code := 1;
      COMMIT;
      p_err_message := SQLERRM || 'curr line_id=' || l_curr_line_id;
  END;
  ---------------------------------
  -- check_avg_discount
  -----------------------------------

  PROCEDURE process_avg_discount(p_err_code    OUT NUMBER,
                                 p_err_message OUT VARCHAR2) IS
  
    l_delta    NUMBER;
    l_ar_delta NUMBER;
  BEGIN
    p_err_code := 0;
    FOR i IN c_open_lines LOOP
      -- dbms_output.put_line(i.oe_line_number || '-' || i.stage_context);
      DELETE FROM xxoe_commission_data t
       WHERE t.oe_line_id = i.oe_line_id
         AND t.stage_context = i.stage_context || '-OVERAGE';
      COMMIT;
    
      IF i.average_discount < 0 AND i.avg_discount_flag = 'Y' AND
         i.stage_context NOT LIKE '%-OVERAGE' AND
         i.stage_context != 'WAITING' AND
         i.commission_pct_extra != i.commission_pct THEN
      
        l_delta    := i.order_line_amount_dist_orig -
                      (i.order_unit_list_price * i.order_quantity);
        l_ar_delta := i.ar_line_amount_orig -
                      (i.order_unit_list_price * i.order_quantity);
      
        BEGIN
          insert_history(i);
        
          UPDATE xxoe_commission_data tt
             SET tt.order_line_amount_dist =
                 (i.order_unit_list_price * i.order_quantity),
                 tt.ar_line_amount         = decode(ar_line_amount_orig,
                                                    NULL,
                                                    NULL,
                                                    (i.order_unit_list_price *
                                                    i.order_quantity)),
                 amount_to_pay             = round((i.commission_to_pay_pct / 100) *
                                                   nvl(ar_line_amount -
                                                       l_ar_delta,
                                                       i.order_unit_list_price),
                                                   2),
                 tt.last_update_date       = SYSDATE,
                 tt.last_updated_by        = fnd_global.user_id
           WHERE tt.oe_line_id = i.oe_line_id
             AND tt.stage_context = i.stage_context;
        
          i.stage_context := i.stage_context || '-OVERAGE';
        
          i.order_line_amount_dist := l_delta;
          i.ar_line_amount         := l_ar_delta;
          i.commission_pct         := i.commission_pct_extra;
          i.commission_to_pay_pct  := (i.stage_pct / 100) *
                                      i.commission_pct;
          i.amount_to_pay          := round((i.commission_to_pay_pct / 100) *
                                            nvl(l_ar_delta, l_delta),
                                            2);
        
          i.last_update_date := NULL;
          i.last_updated_by  := NULL;
          i.created_by       := fnd_global.user_id;
          i.creation_date    := i.creation_date + 1 / 24 / 60 / 60;
          /* dbms_output.put_line('befor insert  ' || i.oe_line_number || '-' ||
          i.stage_context);*/
          INSERT INTO xxoe_commission_data VALUES i;
        EXCEPTION
          WHEN dup_val_on_index THEN
          
            /*  dbms_output.put_line('delete ' || i.oe_line_number || '-' ||
            i.stage_context);*/
          
            DELETE FROM xxoe_commission_data t
             WHERE t.oe_line_id = i.oe_line_id
               AND t.stage_context = i.stage_context;
          
            INSERT INTO xxoe_commission_data VALUES i;
            -- COMMIT;
        END;
      
        /* -- UPDATE amounts 
        UPDATE xxoe_commission_data tt
           SET tt.order_line_amount_dist = l_delta,
               tt.ar_line_amount         = l_ar_delta,
               tt.last_update_date       = SYSDATE,
               tt.last_updated_by        = fnd_global.user_id
         WHERE tt.oe_line_id = i.oe_line_id
           AND tt.stage_context = i.stage_context;*/
      
      END IF;
    
    END LOOP;
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code    := 1;
      p_err_message := SQLERRM;
  END;

  ----------------------------------
  -- check_stages
  -- 1. check cancel line
  -- 2. check stage change
  -- if yes create new stage

  ----------------------------------
  PROCEDURE check_stages(p_err_code OUT NUMBER, p_err_message OUT VARCHAR2) IS
  
    l_stage_context   VARCHAR2(50);
    l_online_data_rec c_data%ROWTYPE;
    l_continue_exception EXCEPTION;
    l_sqlerrm VARCHAR2(500);
  
  BEGIN
  
    p_err_code := 0;
    -- 
    FOR i IN c_stage_check LOOP
      BEGIN
        OPEN c_data(i.oe_line_id);
      
        FETCH c_data
          INTO l_online_data_rec;
        CLOSE c_data;
      
        -- check cancelled
      
        IF l_online_data_rec.cancelled_flag = 'Y' THEN
          -- copy  rec into   history 
        
          insert_history(i);
        
          -- update cancelled
          -- including close flag 
        
          UPDATE xxoe_commission_data t
             SET t.cancelled_flag        = 'Y',
                 t.commission_pct        = 0,
                 t.commission_to_pay_pct = 0,
                 t.stage_pct             = NULL,
                 t.amount_to_pay         = 0,
                 t.ap_full_paid_flag     = 'Y',
                 
                 t.close_flag             = 'Y',
                 t.oe_line_status         = l_online_data_rec.so_line_status,
                 t.order_line_amount_dist = 0,
                 t.last_update_date       = SYSDATE,
                 t.last_updated_by        = fnd_global.user_id
          
           WHERE t.oe_line_id = i.oe_line_id
             AND t.stage_context = i.stage_context;
        
          -- Delete cancel overage lines if exists
          DELETE FROM xxoe_commission_data t
           WHERE t.oe_line_id = i.oe_line_id
             AND t.stage_context LIKE '%OVERAGE';
        
          -- continue loop
          RAISE l_continue_exception;
        
          /* ELSIF i.oe_line_status != l_online_data_rec.so_line_status OR
              l_online_data_rec.booking_date !=
              nvl(i.booking_date, SYSDATE + 1) OR
              nvl(l_online_data_rec.ship_date, trunc(SYSDATE)) !=
              nvl(i.ship_date, trunc(SYSDATE)) THEN
          
          UPDATE xxoe_commission_data t
             SET t.booking_date     = l_online_data_rec.booking_date,
                 t.ship_date        = l_online_data_rec.ship_date,
                 t.ship_to_party_id = l_online_data_rec.ship_to_party_id,
                 t.ship_to_name     = l_online_data_rec.ship_to_name,
                 t.oe_line_status   = l_online_data_rec.so_line_status,
                 t.last_update_date = SYSDATE,
                 t.last_updated_by  = fnd_global.user_id
           WHERE t.oe_line_id = i.oe_line_id
             AND t.stage_context = i.stage_context;*/
        
        END IF;
      
        ----- check stage 
        l_stage_context := get_stage_context(l_online_data_rec);
      
        IF nvl(l_stage_context, i.stage_context) != i.stage_context THEN
        
          -- insert new stage line
          insert_new_stage(l_stage_context,
                           l_online_data_rec,
                           i.commission_pct,
                           i.manual_comm_override,
                           i.rule_id,
                           i.rule_version);
        
          -- update cuurent stage flag
        
          UPDATE xxoe_commission_data t
             SET t.current_stage_flag = 'N',
                 t.last_update_date   = SYSDATE,
                 t.last_updated_by    = fnd_global.user_id
           WHERE t.oe_line_id = i.oe_line_id
             AND t.stage_context = i.stage_context;
        
        END IF;
      
        COMMIT;
        ----
      EXCEPTION
        WHEN l_continue_exception THEN
          COMMIT;
        WHEN OTHERS THEN
          l_sqlerrm := SQLERRM;
          UPDATE xxoe_commission_data t
             SET t.err_flag         = 'Y',
                 t.err_msg          = 'check_stages error: ' || l_sqlerrm,
                 t.last_update_date = SYSDATE,
                 t.last_updated_by  = fnd_global.user_id
           WHERE t.oe_line_id = i.oe_line_id
             AND t.stage_context = i.stage_context;
          COMMIT;
        
      END;
    END LOOP;
  
    --
  
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code    := 0;
      p_err_message := SQLERRM;
    
  END;
  ----------------------------------
  -- get_comm_paid_info
  -----------------------------------
  PROCEDURE get_ap_paid_info(p_line_id           NUMBER,
                             p_amount            OUT NUMBER,
                             p_amount_prepayment OUT NUMBER,
                             p_exp_desc          OUT VARCHAR2,
                             p_prepay_desc       OUT VARCHAR2) IS
    --p_rate OUT VARCHAR2)
  
    CURSOR c_pre IS
      SELECT --ail.org_id,
       aia.invoice_id,
       ail.amount, --, aia.invoice_currency_code --, aia.exchange_rate
       aia.invoice_num,
       ail.line_number
        FROM ap_invoice_lines_all ail, ap_invoices_all aia
       WHERE aia.invoice_type_lookup_code = 'PREPAYMENT'
         AND ail.line_type_lookup_code = 'ITEM'
         AND aia.invoice_id = ail.invoice_id
         AND ail.attribute5 = to_char(p_line_id)
         AND ap_invoices_pkg.get_approval_status(aia.invoice_id,
                                                 aia.invoice_amount,
                                                 aia.payment_status_flag,
                                                 aia.invoice_type_lookup_code) !=
             'CANCELLED';
  
    CURSOR c_exp IS
      SELECT --ail.org_id,
       aia.invoice_id,
       ail.amount, --, aia.invoice_currency_code --, aia.exchange_rate
       aia.invoice_num,
       ail.line_number
        FROM ap_invoice_lines_all ail, ap_invoices_all aia
       WHERE aia.invoice_type_lookup_code = 'STANDARD'
         AND ail.line_type_lookup_code = 'ITEM'
         AND aia.invoice_id = ail.invoice_id
         AND ail.attribute5 = to_char(p_line_id)
         AND ap_invoices_pkg.get_approval_status(aia.invoice_id,
                                                 aia.invoice_amount,
                                                 aia.payment_status_flag,
                                                 aia.invoice_type_lookup_code) !=
             'CANCELLED';
  
  BEGIN
    FOR i IN c_exp LOOP
      p_amount := nvl(p_amount, 0) + i.amount;
      /* p_exp_desc := p_exp_desc || ',' || i.invoice_id || '-' ||
      i.line_number;*/
    
    END LOOP;
    p_exp_desc := ltrim(p_exp_desc, ',');
  
    --
  
    FOR i IN c_pre LOOP
      p_amount_prepayment := nvl(p_amount_prepayment, 0) + i.amount;
      /* p_prepay_desc       := p_prepay_desc || ',' || i.invoice_id || '-' ||
      i.line_number;*/
    
    END LOOP;
    p_prepay_desc := ltrim(p_prepay_desc, ',');
  
  END;

  -----------------------------------
  --  match AR invoice info
  -----------------------------------
  PROCEDURE match_ar_invoice_info(p_err_code    OUT NUMBER,
                                  p_err_message OUT VARCHAR2) IS
  
    l_amount           NUMBER;
    l_inv_number       VARCHAR2(30);
    l_inv_line_number  NUMBER;
    l_err_code         NUMBER;
    l_err_message      VARCHAR2(500);
    l_inv_paid_flag    VARCHAR2(1);
    l_inv_date         DATE;
    l_avg_discount_pct NUMBER;
  BEGIN
  
    p_err_code := 0;
  
    FOR i IN c_open_lines LOOP
    
      xxoe_commission_calc.get_ar_info(p_order_number     => i.oe_number,
                                       p_line_id          => i.oe_line_id,
                                       p_org_id           => i.org_id,
                                       p_amount           => l_amount,
                                       p_inv_number       => l_inv_number,
                                       p_inv_line_number  => l_inv_line_number,
                                       p_inv_paid_flag    => l_inv_paid_flag,
                                       p_inv_date         => l_inv_date,
                                       p_avg_discount_pct => l_avg_discount_pct,
                                       p_err_code         => l_err_code,
                                       p_err_message      => l_err_message);
    
      -- dbms_output.put_line('l_amount=' || l_amount);
    
      UPDATE xxoe_commission_data tt
         SET tt.ar_line_amount_orig = l_amount,
             tt.ar_line_amount      = l_amount,
             tt.ar_invoice_number   = l_inv_number,
             tt.ar_invoice_line     = l_inv_line_number,
             tt.ar_invoice_date     = l_inv_date,
             tt.amount_to_pay       = CASE nvl(tt.commission_amount, -9999)
                                        WHEN -9999 THEN
                                         round((nvl(tt.resin_portion, 1) *
                                               tt.commission_to_pay_pct / 100) *
                                               nvl(l_amount,
                                                   tt.order_line_amount_dist),
                                               2)
                                        ELSE /* nvl(tt.resin_portion, 1) **/
                                         tt.commission_amount *
                                         tt.order_quantity
                                      END,
             
             tt.is_ar_payments_exists = l_inv_paid_flag,
             tt.last_update_date      = SYSDATE,
             tt.last_updated_by       = fnd_global.user_id
       WHERE tt.oe_line_id = i.oe_line_id
         AND tt.stage_context = i.stage_context;
      COMMIT;
    END LOOP;
  
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code    := 1;
      p_err_message := SQLERRM;
  END;

  -----------------------------------
  -- match AP commission payments
  -- split commision paid fifo
  -----------------------------------
  PROCEDURE match_ap_commission_payments(p_err_code    OUT NUMBER,
                                         p_err_message OUT VARCHAR2,
                                         p_agent_id    NUMBER) IS
  
    CURSOR c_lines(c_line_id NUMBER) IS
      SELECT *
        FROM xxoe_commission_data t
       WHERE t.oe_line_id = c_line_id
         AND t.stage_context != 'WAITING'
      
       ORDER BY t.creation_date;
  
    l_ap_exp_amount    NUMBER;
    l_ap_prepay_amount NUMBER;
    l_amount_to_pay    NUMBER;
    l_last_stage       VARCHAR2(50);
    l_last_line_id     NUMBER;
    l_sqlerrm          VARCHAR2(500);
    l_ap_exp_desc      VARCHAR2(500);
    l_ap_prepay_desc   VARCHAR2(500);
  BEGIN
    p_err_code := 0;
  
    FOR i IN c_ap_open_lines(p_agent_id) LOOP
      BEGIN
        l_ap_exp_amount    := 0;
        l_ap_prepay_amount := 0;
        get_ap_paid_info(i.oe_line_id,
                         l_ap_exp_amount,
                         l_ap_prepay_amount,
                         l_ap_exp_desc,
                         l_ap_prepay_desc);
      
        l_ap_exp_amount    := nvl(l_ap_exp_amount, 0);
        l_ap_prepay_amount := nvl(l_ap_prepay_amount, 0);
      
        -- clean amount paid and re calc
      
        UPDATE xxoe_commission_data t
           SET amount_paid = 0, amount_paid_prepayment = 0
         WHERE t.oe_line_id = i.oe_line_id;
        --
      
        FOR j IN c_lines(i.oe_line_id) LOOP
        
          l_amount_to_pay := 0;
          UPDATE xxoe_commission_data t
             SET t.amount_paid = decode(sign(t.amount_to_pay),
                                        -1,
                                        greatest(nvl(t.amount_to_pay, 0),
                                                 l_ap_exp_amount),
                                        least(nvl(t.amount_to_pay, 0),
                                              l_ap_exp_amount))
          
           WHERE t.oe_line_id = j.oe_line_id
             AND t.stage_context = j.stage_context
          RETURNING t.amount_to_pay INTO l_amount_to_pay;
        
          SELECT l_ap_exp_amount -
                 decode(sign(l_amount_to_pay),
                        -1,
                        greatest(nvl(l_amount_to_pay, 0), l_ap_exp_amount),
                        least(nvl(l_amount_to_pay, 0), l_ap_exp_amount))
            INTO l_ap_exp_amount
            FROM dual;
        
          EXIT WHEN l_ap_exp_amount = 0;
        
          l_last_stage   := j.stage_context;
          l_last_line_id := j.oe_line_id;
        END LOOP;
        -- in case of over payment
        IF l_ap_exp_amount != 0 THEN
          UPDATE xxoe_commission_data t
             SET t.amount_paid = nvl(t.amount_paid, 0) + l_ap_exp_amount
          
           WHERE t.oe_line_id = l_last_line_id
             AND t.stage_context = l_last_stage;
        END IF;
        --  END IF;
      
        ---  SPLIT PREP PAYMENT AMOUNT 
        FOR j IN c_lines(i.oe_line_id) LOOP
          --  dbms_output.put_line('l_ap_prepay_amount=' || l_ap_prepay_amount);
        
          l_amount_to_pay := 0;
          UPDATE xxoe_commission_data t
             SET t.amount_paid_prepayment = decode(sign(t.amount_to_pay),
                                                   -1,
                                                   greatest(nvl(t.amount_to_pay,
                                                                0),
                                                            l_ap_prepay_amount),
                                                   least(nvl(t.amount_to_pay,
                                                             0),
                                                         l_ap_prepay_amount))
          
          /*  least(nvl(t.amount_to_pay, 0),
          l_ap_prepay_amount)*/
          
           WHERE t.oe_line_id = j.oe_line_id
             AND t.stage_context = j.stage_context
          RETURNING t.amount_paid_prepayment INTO l_amount_to_pay;
          --  dbms_output.put_line('after=' || l_amount_to_pay);
        
          SELECT l_ap_prepay_amount -
                 decode(sign(l_amount_to_pay),
                        -1,
                        greatest(nvl(l_amount_to_pay, 0), l_ap_prepay_amount),
                        least(nvl(l_amount_to_pay, 0), l_ap_prepay_amount))
            INTO l_ap_prepay_amount
            FROM dual;
          --  dbms_output.put_line('after2=' || l_ap_prepay_amount);
          /*         l_ap_prepay_amount := l_ap_prepay_amount -
          least(nvl(l_amount_to_pay, 0),
                l_ap_prepay_amount);*/
        
          EXIT WHEN l_ap_prepay_amount = 0;
        
          l_last_stage   := j.stage_context;
          l_last_line_id := j.oe_line_id;
        END LOOP;
        -- in case of over payment
        IF l_ap_prepay_amount != 0 THEN
          UPDATE xxoe_commission_data t
             SET t.amount_paid_prepayment = nvl(t.amount_paid_prepayment, 0) +
                                            l_ap_prepay_amount
          
           WHERE t.oe_line_id = l_last_line_id
             AND t.stage_context = l_last_stage;
        END IF;
      
        -----
        --  END IF;
        COMMIT;
      EXCEPTION
        WHEN OTHERS THEN
          ROLLBACK;
          l_sqlerrm := SQLERRM;
          UPDATE xxoe_commission_data t
             SET t.err_flag = 'Y',
                 t.err_msg  = 'error in match_ap_commission_payment: ' ||
                              l_sqlerrm
          
           WHERE t.err_flag != 'N'
             AND t.oe_line_id = i.oe_line_id;
          COMMIT;
      END;
    
      -- set amount_left_to_be_paid
    
      UPDATE xxoe_commission_data t
         SET t.amount_left_to_be_paid = nvl(t.amount_to_pay, 0) -
                                        nvl(t.amount_paid, 0),
             
             t.amount_left_2_pay_prepayment = nvl(t.amount_to_pay, 0) -
                                              nvl(t.amount_paid_prepayment,
                                                  0)
      
       WHERE t.oe_line_id = i.oe_line_id;
    
      UPDATE xxoe_commission_data t
         SET t.ap_full_paid_flag = decode(nvl(round(amount_left_to_be_paid,
                                                    1),
                                              0),
                                          0,
                                          'Y',
                                          'N'),
             t.last_update_date  = SYSDATE,
             t.last_updated_by   = fnd_global.user_id
       WHERE t.agent_id = nvl(p_agent_id, agent_id)
            --  AND t.ap_full_paid_flag = 'N'
            --   AND nvl(round(amount_left_to_be_paid, 1), 0) = 0
            --   AND t.close_flag = 'Y'
         AND t.amount_to_pay IS NOT NULL
         AND t.commission_pct IS NOT NULL
         AND t.oe_line_id = i.oe_line_id;
      COMMIT;
    END LOOP;
  
    COMMIT;
  
    -- check ap_interface lines
    -- for each line in AP_Status='INTERFACE' 
    -- check if error exists
  
    FOR i IN c_ap_interface_lines LOOP
    
      IF is_ap_interface_err_exist(i.ap_group_id) = 1 THEN
        UPDATE xxoe_commission_data t
           SET t.err_flag = 'Y',
               t.err_msg  = t.err_msg || ' ' || chr(13) || chr(10) ||
                            'Error exist in AP interface (see interface log).'
         WHERE t.ap_group_id = i.ap_group_id;
      ELSE
        UPDATE xxoe_commission_data t
           SET t.err_flag        = NULL,
               t.err_msg         = NULL,
               t.ap_group_status = NULL
         WHERE t.ap_group_id = i.ap_group_id;
      END IF;
    
    END LOOP;
  
    COMMIT;
  
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      --  send mail alert
      p_err_code    := 1;
      p_err_message := 'match_ap_commission_payments :' || SQLERRM;
    
  END;

  -----------------------------------
  -- close_lines
  -- mark record for setting commission percent as permanent
  -----------------------------------
  PROCEDURE close_lines(p_err_code    OUT NUMBER,
                        p_err_message OUT VARCHAR2,
                        p_agent_id    NUMBER) IS
  BEGIN
    p_err_code := 0;
  
    UPDATE xxoe_commission_data t
       SET t.close_flag       = 'Y',
           t.last_update_date = SYSDATE,
           t.last_updated_by  = fnd_global.user_id
     WHERE close_flag = 'N'
       AND t.agent_id = nvl(p_agent_id, agent_id)
       AND t.oe_line_id IN (SELECT tt.oe_line_id /*, tt.stage_context*/
                              FROM xxoe_commission_data tt
                             WHERE tt.ar_line_amount IS NOT NULL --??? 
                                  -- amount 2 pay = amount paid 
                               AND is_stage_final(tt.stage_context) = 'Y' -- IN ('SHIPPED', 'COI')
                               AND tt.close_flag = 'N'); -- chenge to last stage flag mark at dff
  
    COMMIT;
  
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code    := 1;
      p_err_message := SQLERRM;
  END;
  -----------------------------------
  -- calc_commission
  --
  -- select all open lines and recalculate comm 
  -- check updated fileds 
  -----------------------------------
  PROCEDURE check_commission(p_err_code    OUT NUMBER,
                             p_err_message OUT VARCHAR2) IS
    l_comm             NUMBER;
    l_comm_extra       NUMBER;
    l_comm_amount      NUMBER;
    l_rule_id          NUMBER;
    l_rule_ver         NUMBER;
    l_on_line_data_rec c_data%ROWTYPE;
    l_upd_rec          xxoe_commission_data%ROWTYPE;
    l_err_code         NUMBER;
    l_err_message      VARCHAR2(500);
    l_data             xxoe_commission_data%ROWTYPE;
    l_continue_exception EXCEPTION;
  BEGIN
    p_err_code := 0;
    FOR i IN c_comm_re_check_lines LOOP
      BEGIN
      
        l_on_line_data_rec := NULL;
        OPEN c_data(i.oe_line_id);
        FETCH c_data
          INTO l_on_line_data_rec;
        CLOSE c_data;
      
        -- if record deleted or agent is still not set than 
        -- continue to next record
        IF l_on_line_data_rec.header_id IS NULL THEN
          --OR
          DELETE FROM xxoe_commission_data t
           WHERE t.oe_line_id = i.oe_line_id;
          COMMIT;
        
          RAISE l_continue_exception;
        END IF;
      
        l_data := NULL;
        convert_records_type(l_on_line_data_rec, l_data);
      
        -- do calc 
        calc_commission(l_data, --l_on_line_data_rec
                        l_comm,
                        l_comm_extra,
                        l_comm_amount,
                        l_rule_id,
                        l_rule_ver,
                        l_err_code,
                        l_err_message);
      
        /* dbms_output.put_line('l_err_code=' || l_err_code || ' l_comm=' ||
        l_comm || ' l_rule_id=' || l_rule_id);*/
      
        IF l_err_code = 1 THEN
          p_err_message := l_err_message;
          -- error 
          UPDATE xxoe_commission_data t
             SET t.commission_pct        = NULL,
                 t.commission_to_pay_pct = NULL,
                 t.rule_id               = NULL,
                 t.amount_to_pay         = NULL,
                 t.commission_pct_extra  = NULL,
                 t.rule_version          = NULL,
                 t.err_flag              = 'Y',
                 t.err_msg               = l_err_message,
                 t.last_update_date      = SYSDATE,
                 t.last_updated_by       = fnd_global.user_id,
                 t.last_update_login     = fnd_global.login_id
           WHERE t.oe_line_id = i.oe_line_id
             AND t.stage_context = i.stage_context;
        ELSE
        
          -- commission changed 
          l_upd_rec := i;
        
          convert_records_type(l_on_line_data_rec, l_upd_rec);
        
          IF nvl(i.manual_comm_override, 'N') = 'N' AND
            --  l_on_line_data_rec.d_attribute1 = 'N' AND
             (i.order_quantity != l_on_line_data_rec.order_quantity OR
              i.average_discount != l_on_line_data_rec.average_discount OR
              nvl(i.commission_pct, -1) != nvl(l_comm, -1) OR
              nvl(i.commission_pct_extra, -1) != nvl(l_comm_extra, -1) OR
              nvl(i.commission_amount, -1) != nvl(l_comm_amount, -1) OR
              nvl(i.rule_id, -1) != nvl(l_rule_id, -1) OR
              nvl(i.resin_portion, -1) != nvl(l_data.resin_portion, -1) OR
              i.order_line_amount_dist !=
              l_upd_rec.order_line_amount_dist_orig) OR
             i.unit_selling_price != l_data.unit_selling_price OR
             i.order_line_amount != l_data.order_line_amount THEN
            --  copy to history  if  not first calc
            IF i.commission_pct IS NOT NULL OR
               i.commission_amount IS NOT NULL THEN
            
              insert_history(i);
            
            END IF;
          
            -- update current row with param          
            -- convert type
            -- get all updated data param 
          
            --  set new fields         
            l_upd_rec . commission_pct := l_comm;
            l_upd_rec.commission_amount := l_comm_amount;
            l_upd_rec .commission_pct_extra := l_comm_extra;
            IF l_comm_amount IS NULL THEN
              l_upd_rec . commission_to_pay_pct := l_comm * i.stage_pct / 100;
            ELSE
              l_upd_rec . commission_to_pay_pct := NULL;
            END IF;
          
            l_upd_rec . rule_id := l_rule_id;
            l_upd_rec.rule_version := l_rule_ver;
            l_upd_rec . last_update_date := SYSDATE;
            l_upd_rec . last_updated_by := fnd_global.user_id;
            l_upd_rec. last_update_login := fnd_global.login_id;
            l_upd_rec.err_flag := NULL;
            l_upd_rec.err_msg := NULL;
          
            UPDATE xxoe_commission_data t
               SET ROW = l_upd_rec
             WHERE t.oe_line_id = i.oe_line_id
               AND t.stage_context = i.stage_context;
            COMMIT;
          
            -- commission not changed 
            -- check if update of other changeable fields needed 
          ELSIF i.oe_line_status != l_on_line_data_rec.so_line_status OR
                l_on_line_data_rec.booking_date !=
                nvl(i.booking_date, SYSDATE + 1) OR
                nvl(l_on_line_data_rec.ship_date, trunc(SYSDATE)) !=
                nvl(i.ship_date, trunc(SYSDATE)) OR
                (i.agent_id IS NULL AND
                l_on_line_data_rec.agent_id IS NOT NULL) OR
                i.bill_to_party_id != l_on_line_data_rec.bill_to_party_id OR
                i.ship_to_party_id != l_on_line_data_rec.ship_to_party_id OR
               
                nvl(i.coi_date, SYSDATE + 1) !=
                nvl(l_on_line_data_rec.coi_date, SYSDATE + 1) OR
                i.agent_id != l_on_line_data_rec.agent_id OR
                i.agent_id != l_on_line_data_rec.agent_id OR
                i.salesrep_name != l_on_line_data_rec.salesrep_name OR
                i.order_line_amount_dist !=
                l_data.order_line_amount_dist_orig OR
                i.unit_selling_price != l_data.unit_selling_price OR
                i.order_line_amount != l_data.order_line_amount OR
                i.is_upgrade_order != l_on_line_data_rec.is_upgrade_order THEN
          
            insert_history(i);
          
            UPDATE xxoe_commission_data t
               SET t.salesrep_id                 = l_on_line_data_rec.salesrep_id,
                   t.salesrep_name               = l_on_line_data_rec.salesrep_name,
                   t.booking_date                = l_on_line_data_rec.booking_date,
                   t.ship_date                   = l_on_line_data_rec.ship_date,
                   t.ship_to_party_id            = l_on_line_data_rec.ship_to_party_id,
                   t.ship_to_name                = l_on_line_data_rec.ship_to_name,
                   t.oe_line_status              = l_on_line_data_rec.so_line_status,
                   t.agent_id                    = l_on_line_data_rec.agent_id,
                   t.agent_name                  = l_on_line_data_rec.agent_name,
                   t.bill_to_party_id            = l_on_line_data_rec.bill_to_party_id,
                   t.bill_to_name                = l_on_line_data_rec.bill_to_name,
                   t.average_discount            = l_on_line_data_rec.average_discount,
                   t.coi_date                    = l_on_line_data_rec.coi_date,
                   t.is_ib_exists                = l_on_line_data_rec.is_ib_exists,
                   t.order_line_amount_dist      = l_data.order_line_amount_dist,
                   t.order_line_amount           = l_data.order_line_amount,
                   t.order_line_amount_dist_orig = l_data.order_line_amount_dist_orig,
                   t.unit_selling_price          = l_data.unit_selling_price,
                   t.is_upgrade_order            = l_data.is_upgrade_order,
                   t.last_update_date            = SYSDATE,
                   t.last_updated_by             = fnd_global.user_id
            
             WHERE t.oe_line_id = i.oe_line_id
               AND t.stage_context = i.stage_context;
          END IF;
        
        END IF;
      
      EXCEPTION
        WHEN l_continue_exception THEN
          NULL;
        
        WHEN OTHERS THEN
          --     dbms_output.put_line('order / line id=' || i.oe_number || ' ' ||
          --      i.oe_line_id);
        
          p_err_code    := 1;
          p_err_message := SQLERRM;
      END;
    
    END LOOP;
  
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code    := 1;
      p_err_message := SQLERRM;
  END;

  --------------------------------------
  -- main
  --------------------------------------

  PROCEDURE main(p_err_message OUT VARCHAR2, p_err_code OUT NUMBER) IS
    l_err_code    NUMBER;
    l_err_message VARCHAR2(500);
  
    l_mail_message VARCHAR2(2000);
    l_nl           VARCHAR2(2) := chr(10) || chr(13);
  BEGIN
    p_err_message := NULL;
    p_err_code    := 0;
  
    l_err_code := 0;
  
    --  DELETE FROM xxoe_commission_data;
    --  DELETE FROM xxoe_commission_data_his;
    COMMIT;
    l_mail_message := 'Delta : Start' || l_nl;
  
    init_global;
  
    --- delta 
    -- insert new lines for commission table
    delta(p_err_code => l_err_code, p_err_message => l_err_message);
  
    l_mail_message := l_mail_message || l_err_message || l_nl ||
                      'Delta : end ' || l_nl;
  
    -- insert new stage
  
    -- book --- coi
    -- check cancel lines
  
    l_mail_message := l_mail_message || 'check_stages : Start' || l_nl;
    check_stages(p_err_code => l_err_code, p_err_message => l_err_message);
    l_mail_message := l_mail_message || 'check_stages : end ' || l_nl;
  
    -- check commission
    -- get commission percent for each line 
    -- check update fileds
    l_mail_message := l_mail_message || 'check_commission : Start' || l_nl;
    check_commission(p_err_code    => l_err_code,
                     p_err_message => l_err_message);
    l_mail_message := l_mail_message || l_err_message || l_nl ||
                      'check_commission : end ' || l_nl;
  
    -- match_ar_invoice_info
    l_mail_message := l_mail_message || 'match_ar_invoice_info : Start' || l_nl;
    match_ar_invoice_info(p_err_code    => l_err_code,
                          p_err_message => l_err_message);
    l_mail_message := l_mail_message || l_err_message || l_nl ||
                      'match_ar_invoice_info : end ' || l_nl;
  
    -- process_avg_discount
    l_mail_message := l_mail_message || 'process_avg_discount : Start' || l_nl;
    xxoe_commission_calc.process_avg_discount(p_err_code    => l_err_code,
                                              p_err_message => l_err_message);
    l_mail_message := l_mail_message || l_err_message || l_nl ||
                      'process_avg_discount : end ' || l_nl;
  
    -- match_ap_commission_payments
  
    l_mail_message := l_mail_message ||
                      'match_ap_commission_payments : Start' || l_nl;
    match_ap_commission_payments(p_err_code    => l_err_code,
                                 p_err_message => l_err_message,
                                 p_agent_id    => NULL);
    l_mail_message := l_mail_message || l_err_message || l_nl ||
                      'match_ap_commission_payments : end ' || l_nl;
  
    xxobjt_wf_mail.send_mail_text(p_to_role     => fnd_profile.value('XXOECOMM_ALERT_ROLE'),
                                  p_cc_mail     => fnd_profile.value('XXOECOMM_ALERT_CC_MAIL_LIST'),
                                  p_subject     => 'Commissions Report',
                                  p_body_text   => l_mail_message,
                                  p_err_code    => l_err_code,
                                  p_err_message => l_err_message);
  
  EXCEPTION
    WHEN OTHERS THEN
      p_err_message := SQLERRM;
      p_err_code    := 1;
  END;

  ---------------------------------------
  -- get_rule_explain his
  --------------------------------------
  FUNCTION get_rule_explain_his(p_line_id NUMBER,
                                p_stage   VARCHAR2,
                                p_rule_id NUMBER,
                                p_ver     NUMBER,
                                p_date    DATE) RETURN VARCHAR2 IS
  
    CURSOR c_rule IS
      SELECT t.commission_pct,
             l.rule_line_id,
             l.rule_id,
             l.rule_code,
             l.rule_condition,
             l.data_value,
             l.data_value2
        FROM xxoe_commission_rules_header t, xxoe_commission_rules_lines l
       WHERE l.rule_id = t.rule_id
         AND t.rule_version = l.rule_version
         AND t.rule_id = p_rule_id
         AND t.rule_version = p_ver;
    l_data_rec xxoe_commission_data%ROWTYPE;
    l_str      VARCHAR2(2000);
  BEGIN
    IF p_rule_id IS NULL THEN
      RETURN NULL;
    END IF;
    FOR i IN c_calc_data_his(p_stage, p_line_id, p_date) LOOP
      l_data_rec := i;
      init_param_arr(i);
      FOR j IN c_rule LOOP
      
        l_str := l_str || get_param_desc(j.rule_code) || '=' ||
                 g_param_arr(j.rule_code) || ' ' || chr(13) || chr(10);
      END LOOP;
    
    END LOOP;
  
    RETURN l_str;
  END;
  ---------------------------------------
  -- get_rule_explain
  --------------------------------------
  FUNCTION get_rule_explain(p_line_id NUMBER,
                            p_stage   VARCHAR2,
                            p_rule_id NUMBER,
                            p_ver     NUMBER) RETURN VARCHAR2 IS
  
    CURSOR c_rule IS
      SELECT t.commission_pct,
             l.rule_line_id,
             l.rule_id,
             l.rule_code,
             l.rule_condition,
             l.data_value,
             l.data_value2
        FROM xxoe_commission_rules_header t, xxoe_commission_rules_lines l
       WHERE l.rule_id = t.rule_id
         AND t.rule_version = l.rule_version
         AND t.rule_id = p_rule_id
         AND t.rule_version = p_ver;
    l_data_rec xxoe_commission_data%ROWTYPE;
    l_str      VARCHAR2(2000);
  BEGIN
    IF p_rule_id IS NULL THEN
      RETURN NULL;
    END IF;
    FOR i IN c_calc_data(p_stage, p_line_id) LOOP
      l_data_rec := i;
      init_param_arr(i);
      FOR j IN c_rule LOOP
      
        l_str := l_str || get_param_desc(j.rule_code) || '=' ||
                 g_param_arr(j.rule_code) || ' ' || chr(13) || chr(10);
      END LOOP;
    
    END LOOP;
  
    RETURN l_str;
  END;

  ---------------------------
  -- create_invoices
  --
  -- insert into intterface 
  -- submit cuncurrent set  for import invoices  and update comm lines
  ----------------------------

  PROCEDURE create_invoices(p_err_code    OUT NUMBER,
                            p_err_message OUT VARCHAR2,
                            p_agent_id    NUMBER) IS
  
    CURSOR c_h IS
      SELECT *
        FROM xxoe_commission_ap2pay_sum_v t
       WHERE t.agent_id = nvl(p_agent_id, agent_id);
  
    CURSOR c_l(c_group_id NUMBER) IS
      SELECT oe_number,
             t.oe_line_id,
             order_line_number,
             t.is_initial,
             t.is_upgrade_order,
             t.item_code,
             SUM(amount_left_to_be_paid) amount_left_to_be_paid
        FROM xxoe_commission_ap2pay_v t
       WHERE ap_group_id = c_group_id
       GROUP BY oe_number,
                t.oe_line_id,
                order_line_number,
                t.is_initial,
                t.is_upgrade_order,
                t.item_code --,     
       ORDER BY t.oe_number, t.oe_line_id;
  
    l_line       NUMBER;
    l_group_id   NUMBER;
    l_req_number NUMBER;
    l_err_code   NUMBER;
    l_err_msg    VARCHAR2(500);
  
    l_vendor_id           NUMBER;
    l_vendor_site_id      NUMBER;
    l_vendor_name         VARCHAR2(500);
    l_terms_id            NUMBER;
    l_code_combination_id NUMBER;
    l_inv_curr            VARCHAR2(5);
    l_message             VARCHAR2(500);
    l_inv_counter         NUMBER := 0;
    l_inv_no              NUMBER;
    success               BOOLEAN;
    myexception EXCEPTION;
  
    l_inital_dist_code_conc     VARCHAR2(250) := fnd_profile.value('XXOECOMM_SYS_COMB_ACCOUNT');
    l_e_c_resin_dist_code_conc  VARCHAR2(250) := fnd_profile.value('XXOECOMM_RESIN_E_C_COMB_ACCOUNT');
    l_desk_resin_dist_code_conc VARCHAR2(250) := fnd_profile.value('XXOECOMM_RESIN_DESK_COMB_ACCOUNT');
    l_dist_code_concatenated    VARCHAR2(250);
  
  BEGIN
    p_err_code := 0;
  
    FOR i IN c_h LOOP
      l_message := NULL;
      BEGIN
        -- set group for  records 
        SELECT xxap_inv_commission_group_seq.nextval
          INTO l_group_id
          FROM dual;
        -- MARK ALL LINES  WITH  GROUP ID
        UPDATE xxoe_commission_data t
           SET t.ap_group_id      = l_group_id,
               t.last_update_date = SYSDATE,
               t.last_updated_by  = fnd_global.user_id
         WHERE t.ap_user_flag = 'Y'
           AND t.org_id = fnd_global.org_id
           AND t.agent_id = i.agent_id;
      
        l_inv_no := SQL%ROWCOUNT;
      
        COMMIT;
      
        -- get vendor info 
        xxoe_commission_calc.get_vendor_info(p_err_code       => l_err_code,
                                             p_err_msg        => l_err_msg,
                                             p_resource_id    => i.agent_id,
                                             p_vendor_id      => l_vendor_id,
                                             p_vendor_site_id => l_vendor_site_id,
                                             p_vendor_name    => l_vendor_name,
                                             p_ccid           => l_code_combination_id,
                                             p_inv_curr       => l_inv_curr);
      
        IF l_err_code != 0 THEN
        
          l_message := ' Unable find vendor details for agent ' ||
                       i.agent_name;
          RAISE myexception;
        
        END IF;
      
        IF i.invoice_type = 'PREPAYMENT' THEN
          l_terms_id := 10035; -- immediate
        ELSE
          l_terms_id := NULL;
        END IF;
      
        INSERT INTO ap_invoices_interface
          (invoice_id,
           invoice_num,
           invoice_type_lookup_code,
           invoice_date,
           vendor_id,
           vendor_site_id,
           invoice_amount,
           invoice_currency_code,
           description,
           SOURCE,
           gl_date,
           org_id,
           exchange_rate,
           group_id,
           terms_id)
        VALUES
          (ap_invoices_interface_s.nextval,
           xxap_inv_commission_number_seq.nextval, --L_INVOICE_NO ,-- SEQUNCE
           i.invoice_type, --'PREPAYMENT', --L_INVOICE_TYPE,-- 'PREPAYMENT'
           trunc(SYSDATE),
           l_vendor_id,
           l_vendor_site_id,
           i.amount_left_to_be_paid, --i.amount_to_pay, --L_INVOICE_AMOUNT,
           i.currency_code, --L_CURRENCY_CODE,
           'Commission Payment', --L_DESCRIPTION, -- -- COMMISION PERCENT & SLAE ORDER NUMBER
           'XX_AP_COMMISSIONS', --L_SOURCE, -- 
           trunc(SYSDATE),
           i.org_id, --L_ORG_ID,
           1, --l_exchange_rate,
           l_group_id, --  SEQUNCE,
           l_terms_id)
        RETURNING invoice_num INTO l_inv_no;
      
        FOR j IN c_l(l_group_id) LOOP
          -- get dist code
          IF i.invoice_type = 'STANDARD' THEN
            CASE
              WHEN (j.is_initial = 'Y' OR j.is_upgrade_order = 'Y') THEN
                l_dist_code_concatenated := l_inital_dist_code_conc;
              WHEN j.item_code NOT LIKE 'OBJ-04%' THEN
                l_dist_code_concatenated := l_e_c_resin_dist_code_conc;
              ELSE
                l_dist_code_concatenated := l_desk_resin_dist_code_conc;
            END CASE;
          
            l_code_combination_id := NULL; --:= 51012; -- FND_PROFILE.VALUE('XXXXX');
          ELSE
            -- GET ACCOUNT FROM VENDOR INFO
            l_dist_code_concatenated := NULL;
          
          END IF;
        
          l_line := c_l%ROWCOUNT;
          INSERT INTO ap_invoice_lines_interface
            (invoice_id,
             invoice_line_id,
             line_number,
             line_type_lookup_code,
             amount,
             dist_code_combination_id,
             dist_code_concatenated,
             org_id,
             description,
             attribute5)
          VALUES
            (ap_invoices_interface_s.currval,
             ap_invoice_lines_interface_s.nextval,
             l_line, -- 
             'ITEM', --l_line_type,
             j.amount_left_to_be_paid, -- j.amount_to_pay, --l_line_amount, -- 'ITEM'
             l_code_combination_id,
             l_dist_code_concatenated,
             i. org_id, --l_org_id,
             i.agent_name || ' ' || 'SO#Line ' || j.oe_number || '#' ||
             j.order_line_number, --|| l_description, -- COMMISION PERCENT ANS SLAE ORDER NUMBER AND LINE
             j.oe_line_id --l_so_line_id -- SALE ORDER LINE ID
             );
        
        END LOOP;
      
        COMMIT;
      
        /* set the context for the request set FNDRSTEST */
        success := fnd_submit.set_request_set('XXOBJT', 'XXOECOMMAP');
        IF (success) THEN
          /* submit program FNDSCARU which is in stage STAGE1 */
          success := fnd_submit.submit_program(application => 'SQLAP',
                                               program     => 'APXIIMPT',
                                               stage       => 'STAGE10',
                                               --   description => NULL,
                                               --  start_time  => SYSDATE,
                                               --  sub_request => FALSE,
                                               argument1  => fnd_global.org_id,
                                               argument2  => 'XX_AP_COMMISSIONS',
                                               argument3  => l_group_id,
                                               argument4  => 'N/A',
                                               argument5  => NULL,
                                               argument6  => NULL,
                                               argument7  => NULL,
                                               argument8  => 'N',
                                               argument9  => 'N',
                                               argument10 => 'N',
                                               argument11 => 'N',
                                               argument12 => 1000,
                                               argument13 => fnd_global.user_id);
          IF (NOT success) THEN
            l_message := 'failed submit program APXIIMPT ' ||
                         fnd_message.get;
            RAISE myexception;
          END IF;
        
          /* submit program FNDSCURS which is in stage STAGE2 */
          success := fnd_submit.submit_program('XXOBJT',
                                               'XXOECOMMAPMATCH',
                                               'STAGE20',
                                               i.agent_id,
                                               chr(0));
        
          IF (NOT success) THEN
            l_message := 'failed submit program XXOECOMMAPMATCH';
            RAISE myexception;
          END IF;
          /* Submit the Request Set */
          l_req_number := fnd_submit.submit_set(NULL, FALSE);
          COMMIT;
        END IF;
      
        IF l_req_number = 0 THEN
        
          UPDATE xxoe_commission_data t
             SET t.ap_group_id      = l_group_id,
                 ap_group_status    = 'ERROR',
                 t.err_flag         = 'Y',
                 t.err_msg          = 'Unable to submit request Invoice Import/APXIIMPT',
                 t.last_update_date = SYSDATE,
                 t.last_updated_by  = fnd_global.user_id
           WHERE ap_group_id = l_group_id;
          p_err_code    := 1;
          p_err_message := 'Unable to submit request Invoice Import/APXIIMPT';
        ELSE
          l_inv_counter := l_inv_counter + 1;
          UPDATE xxoe_commission_data t
             SET t.ap_request_id    = l_req_number,
                 t.ap_user_flag     = 'N',
                 t.err_flag         = NULL,
                 t.err_msg          = NULL,
                 ap_group_status    = 'INTERFACE',
                 t.last_update_date = SYSDATE,
                 t.last_updated_by  = fnd_global.user_id
           WHERE ap_group_id = l_group_id;
        
        END IF;
        COMMIT;
      
      EXCEPTION
        WHEN myexception THEN
          p_err_code    := 1;
          p_err_message := p_err_message || ' ' || l_message;
          UPDATE xxoe_commission_data t
             SET t.ap_group_id      = l_group_id,
                 ap_group_status    = 'ERROR',
                 t.err_flag         = 'Y',
                 t.err_msg          = t.err_msg || l_message,
                 t.last_update_date = SYSDATE,
                 t.last_updated_by  = fnd_global.user_id
          
           WHERE ap_group_id = l_group_id;
          COMMIT;
        
      END;
    END LOOP;
    p_err_message := 'Invoice number ' || l_inv_no ||
                     ' created in AP interface';
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      p_err_code    := 1;
      p_err_message := 'Error in xxoe_commission_calc.create_invoices ' ||
                       SQLERRM;
  END;
  ----------------------------------------------
  -- count_e_c_sys_printers
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --    1.1  26.2.13    yuval tal         bugfix - Fix resin coupon commission and resin portion by site
  ---------------------------------------------
  PROCEDURE count_e_c_sys_printers(p_agent_id    NUMBER,
                                   p_party_id    NUMBER,
                                   p_base_count  OUT NUMBER,
                                   p_total_count OUT NUMBER) IS
    l_cut_date DATE;
  BEGIN
    p_base_count  := NULL;
    p_total_count := NULL;
    l_cut_date    := g_agent_arr(p_agent_id);
  
    p_total_count := g_party_arr(p_party_id).total_sys_count;
    p_base_count  := g_party_arr(p_party_id).base_count;
  
  EXCEPTION
    WHEN no_data_found THEN
    
      SELECT SUM(CASE
                   WHEN coalesce(get_upgrade_date(cii.instance_id),
                                 l.actual_shipment_date,
                                 cii.install_date,
                                 cii.active_start_date,
                                 SYSDATE) > l_cut_date THEN
                    1
                   ELSE
                    0
                 END) base,
             COUNT(*)
        INTO p_base_count, p_total_count
        FROM csi_item_instances cii,
             oe_order_lines_all l,
             hz_party_sites     hps
       WHERE cii.owner_party_id = p_party_id
            -- AND cii.instance_id IN (3890000, 10414, 3552000)
         AND xxhz_party_ga_util.is_system_item(cii.inventory_item_id) = 'Y'
         AND SYSDATE < nvl(cii.active_end_date, SYSDATE + 1)
         AND xxinv_item_classification.get_item_system_sub_family2(cii.inventory_item_id) =
             'Eden Connex'
         AND l.sold_to_org_id(+) = cii.owner_party_account_id
         AND cii.last_oe_order_line_id = l.line_id(+)
         AND hps.party_site_id = cii.location_id
         AND hps.attribute11 = p_agent_id;
    
      g_party_arr(p_party_id).total_sys_count := p_total_count;
      g_party_arr(p_party_id).base_count := p_base_count;
    
    /* EXCEPTION
    WHEN no_data_found THEN
      dbms_output.put_line('ndf agent_id=' || p_agent_id);*/
  END;

  PROCEDURE check_ap_interface(p_err_code    OUT NUMBER,
                               p_err_message OUT VARCHAR2,
                               p_agent_id    NUMBER) IS
  
  BEGIN
  
    NULL;
  
  END;

  --------------------------
  -- open_order4recalc
  ---------------------------

  PROCEDURE open_order4recalc(p_err_code    OUT NUMBER,
                              p_err_message OUT VARCHAR2,
                              p_order_num   NUMBER) IS
  BEGIN
    p_err_code := 0;
  
    UPDATE xxoe_commission_data t
       SET t.ap_full_paid_flag = 'N'
    
     WHERE t.oe_number = p_order_num;
  
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code    := 1;
      p_err_message := SQLERRM;
  END;

END;
/
