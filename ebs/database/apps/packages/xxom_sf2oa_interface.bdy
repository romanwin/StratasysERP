CREATE OR REPLACE PACKAGE BODY xxom_sf2oa_interface AS
  ---------------------------------------------------------------------------
  -- $Header: xxom_sf2oa_interface   $
  ---------------------------------------------------------------------------
  -- Package: xxom_sf2oa_interface
  -- Created:
  -- Author  :
  --------------------------------------------------------------------------
  -- Perpose: CUST  515
  --          Interface between SYSS Salsforce system and Oracle Apps
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --     1.0  29.7.12   yuval tal       Initial Build / CUST 515
  --     1.1  23.12.12  yuval tal       CR631:WS modification: add warehouse field to line
  --     1.2  14.01.13  yuval tal       1. create_order_api : maintaining the SO Status in a Profile XXOM_SF2OA_ORDER_STATUS
  --                                    2. Translate Date Format : add fix_date
  --                                    3. add fnd_global.apps_initialize(l_user_id, l_resp_id, l_resp_appl_id);  in create_order
  --     1.3  03.02.13 yuval tal        CR662 : add new fields : UOM line level , Shipping_Comments, User_Email in header level
  --                                    remove time from maintanance date format in
  --     1.4  15.09.13 yuval tal        CR1028 :
  --                                    1. fix cursor c_account (remove OU restrict)
  --                                    2. insert_line, modify create_order  : support new fields  p_accounting_rule_id     p_service_start_date,p_service_end_date
  --                                       add parameters to insert_line, modify create_order
  --     16.01.14   yuval tal           CR1238 : modify proc insert _header, insert_line, create_order

  --     09.04.14   yuvl tal            CHG0031906 add func  check order exists
  --                                     modify create order : call to check _order_exists
  ---------------------------------------------------------------------------

  ---------------------------------------
  -- GLOBALS
  ---------------------------------------
  g_date_format             VARCHAR2(50) := 'ddmmyyyy hh24:mi:ss';
  g_maintenance_date_format VARCHAR2(50) := 'ddmmyyyy';

  CURSOR c_account(c_cust_num      VARCHAR2,
                   c_site_num      VARCHAR2,
                   c_site_use_code VARCHAR2,
                   c_org_id        NUMBER) IS
    SELECT bill_su.site_use_id       invoice_ship_to_org_id,
           bill_cas.org_id,
           bill_su.site_use_code,
           org.name                  organization_name,
           cust_acct.cust_account_id sold_to_org_id,
           cust_acct.account_number  cust_num,
           --Billing location deatils
           party.party_name          cust_name,
           party.party_id,
           bill_ps.party_site_number site_num,
           bill_loc.location_id,
           bill_cas.territory        territory_code
      FROM -- Customer Details
           hz_parties       party,
           hz_cust_accounts cust_acct,
           --Billing location deatils
           hz_cust_site_uses_all     bill_su,
           hz_cust_acct_sites_all    bill_cas,
           hz_party_sites            bill_ps,
           hz_locations              bill_loc,
           hr_all_organization_units org
    --Organization Details
     WHERE bill_cas.org_id = org.organization_id
          -- AND org.name IN ('OBJET DE (OU)', 'OBJET HK (OU)')
          --Customer Details
       AND cust_acct.party_id = party.party_id
       AND cust_acct.status = 'A'
       AND party.status = 'A'
          --Billing location deatils
       AND cust_acct.cust_account_id = bill_cas.cust_account_id
       AND bill_cas.cust_acct_site_id = bill_su.cust_acct_site_id
       AND bill_su.site_use_code IN ('BILL_TO', 'SHIP_TO')
       AND bill_su.status = 'A'
       AND bill_cas.party_site_id = bill_ps.party_site_id
       AND bill_cas.status = 'A'
       AND bill_ps.location_id = bill_loc.location_id
       AND bill_ps.status = 'A'
       AND cust_acct.account_number =
           nvl(c_cust_num, cust_acct.account_number)
       AND bill_su.site_use_code =
           nvl(c_site_use_code, bill_su.site_use_code)
       AND bill_ps.party_site_number =
           nvl(c_site_num, bill_ps.party_site_number)
       AND bill_cas.org_id = nvl(c_org_id, bill_cas.org_id);

  ---------------------------------
  -- FIX_DATE
  -- SF provide midnight hour with 24 while oracle look for 00
  --------------------------------
  FUNCTION fix_date(p_date VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    RETURN REPLACE(p_date, ' 24:', ' 00:');
  
  END;
  -----------------------------------
  -- get_order_type_name
  ------------------------------------

  FUNCTION get_order_type_name(p_order_type_id NUMBER) RETURN VARCHAR2 IS
    l_tmp VARCHAR2(500);
  
  BEGIN
  
    SELECT t.name
      INTO l_tmp
      FROM oe_transaction_types_tl t
     WHERE t.transaction_type_id = p_order_type_id
       AND t.language = 'US';
    RETURN l_tmp;
  END;
  -------------------------------------
  -- check_sf_order_exists
  --
  -- check if Sf order aleader exists in interface with Status 'S'
  -- return
  --   p_message IS NOT NULL = EXISTS
  --  
  -------------------------------------
  PROCEDURE check_order_exists(p_orig_sys_document_ref VARCHAR2,
                               p_order_source_id       NUMBER,
                               p_org_id                NUMBER,
                               p_interface_header_id   NUMBER,
                               p_message               OUT VARCHAR2,
                               p_order_number          OUT NUMBER,
                               p_order_header_id       OUT NUMBER,
                               p_order_status          OUT VARCHAR2) IS
  
    CURSOR c IS
      SELECT 'Duplicate Request , Order Already created , see Oracle Order=' ||
             t.order_number,
             t.order_number,
             t.header_id,
             t.flow_status_code
        FROM oe_order_headers_all t
       WHERE t.orig_sys_document_ref = p_orig_sys_document_ref
         AND t.order_source_id = p_order_source_id
         AND t.org_id = p_org_id
         AND t.flow_status_code != 'CANCELLED';
  
    CURSOR c_interface IS
      SELECT 'Other request is being processed for the same Order (interface id =' ||
             intr.interface_header_id || ')'
        FROM xxom_sf2oa_header_interface intr
       WHERE intr.order_source_id = p_order_source_id
         AND orig_sys_document_ref = p_orig_sys_document_ref
         AND intr.org_id = p_org_id
         AND intr.interface_header_id != p_interface_header_id
         AND intr.status_code = 'P';
  
  BEGIN
  
    OPEN c_interface;
    FETCH c_interface
      INTO p_message;
    CLOSE c_interface;
  
    IF p_message IS NULL THEN
      OPEN c;
      FETCH c
        INTO p_message, p_order_number, p_order_header_id, p_order_status;
      CLOSE c;
    
    END IF;
  
  END;

  -------------------------------
  -- get_order_type_details
  --------------------------------
  PROCEDURE get_order_type_details(p_org_id           NUMBER,
                                   p_operation        NUMBER,
                                   p_order_type_id    OUT NUMBER,
                                   p_pos_line_type_id OUT NUMBER,
                                   p_neg_line_type_id OUT NUMBER,
                                   p_resp_id          OUT NUMBER) IS
  
    CURSOR c(c_org_id NUMBER, c_operation NUMBER) IS
      SELECT attribute1 operation,
             attribute2 org_id,
             attribute3 order_type_id,
             attribute4 pos_line_type_id,
             attribute5 neg_line_type_id,
             attribute6 resp_id
        FROM fnd_flex_values_vl p, fnd_flex_value_sets vs
       WHERE p.flex_value_set_id = vs.flex_value_set_id
         AND vs.flex_value_set_name = 'XXOM_SF2OA_Order_Types_Mapping'
         AND attribute1 = c_operation
         AND attribute2 = c_org_id;
  
  BEGIN
    -- dbms_output.put_line('11');
    FOR i IN c(p_org_id, p_operation) LOOP
      p_order_type_id    := i.order_type_id;
      p_pos_line_type_id := i.pos_line_type_id;
      p_neg_line_type_id := nvl(i.neg_line_type_id, i.pos_line_type_id);
      p_resp_id          := i.resp_id;
    END LOOP;
  
  END;

  ----------------------------
  -- get_sold_to_org_id
  ----------------------------

  FUNCTION get_sold_to_org_id(p_cust_number VARCHAR2, p_org_id NUMBER)
    RETURN NUMBER IS
  
    l_rec c_account%ROWTYPE;
  BEGIN
    OPEN c_account(p_cust_number, NULL, NULL, p_org_id);
    FETCH c_account
      INTO l_rec; --l_sold_to_org_id;
    CLOSE c_account;
  
    RETURN l_rec.sold_to_org_id;
  END;

  ----------------------------
  -- get_ship_invoice_org_id
  ----------------------------

  FUNCTION get_ship_invoice_org_id(p_cust_number   VARCHAR2,
                                   p_site_number   VARCHAR2,
                                   p_site_use_code VARCHAR2,
                                   p_org_id        NUMBER) RETURN NUMBER IS
  
    l_org_id NUMBER;
  
  BEGIN
    FOR i IN c_account(p_cust_number,
                       p_site_number,
                       p_site_use_code,
                       p_org_id) LOOP
      l_org_id := i.invoice_ship_to_org_id;
    END LOOP;
  
    RETURN l_org_id;
  END;

  ------------------------------
  -- get_contact_id
  ------------------------------

  FUNCTION get_contact_id(p_contact_number  VARCHAR2,
                          p_cust_account_id NUMBER) RETURN NUMBER IS
    l_contact_id NUMBER;
    CURSOR c_contact IS
      SELECT acct_role.cust_account_role_id contact_id,
             con.contact_number             contact_number,
             rel_party.party_id             contact_party_id,
             acct_role.cust_acct_site_id    org_id,
             acct_role.cust_account_id,
             rel_party.party_id,
             party.party_name               contact_name,
             -- acct_role.status,
             acct_role.primary_flag
        FROM hz_cust_account_roles acct_role,
             hz_parties            party,
             hz_cust_accounts      acct,
             hz_relationships      rel,
             hz_parties            rel_party,
             hz_org_contacts       con
       WHERE con.party_relationship_id = rel.relationship_id
         AND acct_role.party_id = rel.party_id
         AND acct_role.role_type = 'CONTACT'
         AND rel.subject_table_name = 'HZ_PARTIES'
         AND rel.object_table_name = 'HZ_PARTIES'
         AND rel.subject_id = party.party_id
         AND rel.party_id = rel_party.party_id
         AND rel.object_id = acct.party_id
         AND acct.cust_account_id = acct_role.cust_account_id
         AND acct_role.status = 'A'
         AND con.contact_number = p_contact_number -- '36240';
         AND acct_role.cust_account_id =
             nvl(p_cust_account_id, acct_role.cust_account_id);
  BEGIN
    FOR i IN c_contact LOOP
    
      l_contact_id := i.contact_id;
    
    END LOOP;
    RETURN l_contact_id;
  END;

  -------------------------------------------------
  -- insert_header
  --------------------------------------------------
  -- Version  Date      Performer     Comments
  ----------  --------  ------------  -------------------------------------

  --   1.1   03.2.13    yuval tal     cr662 add  fields  p_shipping_comments,  p_email varchar2,
  --   1.2   16.01.14   yuval tal     CR1238 add fields SALESREP_ID number  , Attribute10     varchar2(240),PRICE_LIST_ID  number;

  ----------------------------------------------------------------------------
  PROCEDURE insert_header(p_auth_string            VARCHAR2,
                          p_operation              VARCHAR2,
                          p_ordered_date           VARCHAR2,
                          p_organization_code      VARCHAR2,
                          p_cust_account_number    VARCHAR2,
                          p_shipping_site_num      VARCHAR2,
                          p_invoice_site_num       VARCHAR2,
                          p_cust_po                VARCHAR2,
                          p_orig_sys_document_ref  VARCHAR2,
                          p_ship_to_contact_num    VARCHAR2,
                          p_invoice_to_contact_num VARCHAR2,
                          p_shipping_method_code   VARCHAR2,
                          p_freight_terms_code     VARCHAR2,
                          p_currency_code          VARCHAR2,
                          p_bpel_instance_id       NUMBER,
                          p_shipping_comments      VARCHAR2,
                          p_email                  VARCHAR2,
                          p_salesrep_id            NUMBER,
                          p_attribute10            VARCHAR2,
                          p_price_list_id          NUMBER,
                          p_org_id                 NUMBER,
                          p_err_code               OUT NUMBER,
                          p_err_message            OUT VARCHAR2,
                          p_interface_header_id    OUT NUMBER) IS
  
    l_ordered_date DATE;
    l_auth_string  VARCHAR2(150);
    l_order_no     VARCHAR2(100);
    l_status_code  VARCHAR2(50);
  BEGIN
    p_err_code := 0;
  
    -- check env string
  
    IF sys_context('USERENV', 'DB_NAME') = 'PROD' THEN
      l_auth_string := fnd_profile.value('XXOM_SF2OA_PROD_ENV_STRING');
    ELSE
      l_auth_string := fnd_profile.value('XXOM_SF2OA_TEST_ENV_STRING');
    END IF;
  
    IF p_auth_string IS NULL OR p_auth_string != l_auth_string THEN
      p_err_code := 1;
    
      p_err_message := 'Environment Check failed'; --  fnd_message.get;
      RETURN;
    END IF;
  
    --
    -- check SF order already exists  with status S
    /*check_sf_order_exists(p_orig_sys_document_ref,
    l_order_no,
    l_status_code);*/
  
    /* IF l_order_no IS NOT NULL THEN
    
      p_err_code := 1;
      fnd_message.set_name('XXOBJT', 'XXOM_SF2OA_ORDER_EXISTS');
      fnd_message.set_token('SF_REF_ID', p_orig_sys_document_ref);
      fnd_message.set_token('ORDER_NO', l_order_no);
      p_err_message := fnd_message.get;
    
      RETURN;
    ELSIF l_status_code = 'P' THEN
      p_err_code := 1;
      fnd_message.set_name('XXOBJT', 'XXOM_SF2OA_ORDER_IN_PROCESS');
      fnd_message.set_token('SF_REF_ID', p_orig_sys_document_ref);
      p_err_message := fnd_message.get;
      RETURN;
    END IF;*/
  
    -----
  
    -- check date format
    BEGIN
      l_ordered_date := to_date(fix_date(p_ordered_date), g_date_format);
    EXCEPTION
      WHEN OTHERS THEN
        p_err_code := 1;
        fnd_message.set_name('XXOBJT', 'XXOM_SF2OA_BAD_DATE_FORMAT');
        fnd_message.set_token('FIELD', 'Ordered_Date');
        fnd_message.set_token('FORMAT', g_date_format);
        p_err_message := fnd_message.get;
        RETURN;
    END;
  
    INSERT INTO xxom_sf2oa_header_interface
      (interface_header_id,
       -- uf_ssys_ext_system_name,
       -- uf_ssys_ext_system_ref_number,
       operation,
       ordered_date,
       organization_code,
       cust_account_number,
       shipping_site_num,
       invoice_site_num,
       cust_po,
       orig_sys_document_ref,
       ship_to_contact_num,
       invoice_to_contact_num,
       shipping_method_code,
       freight_terms_code,
       currency_code,
       bpel_instance_id,
       status_code,
       creation_date,
       shipping_comments,
       email,
       salesrep_id,
       attribute10,
       price_list_id,
       org_id)
    VALUES
      (xxom_sf2oa_header_int_seq.nextval,
       -- p_uf_ssys_ext_system_name,
       -- p_uf_ssys_ext_system_ref_num,
       p_operation,
       nvl(l_ordered_date, SYSDATE),
       p_organization_code,
       p_cust_account_number,
       p_shipping_site_num,
       p_invoice_site_num,
       p_cust_po,
       p_orig_sys_document_ref,
       p_ship_to_contact_num,
       p_invoice_to_contact_num,
       p_shipping_method_code,
       p_freight_terms_code,
       p_currency_code,
       p_bpel_instance_id,
       'N',
       SYSDATE,
       p_shipping_comments,
       p_email,
       p_salesrep_id,
       p_attribute10,
       p_price_list_id,
       p_org_id)
    RETURNING interface_header_id INTO p_interface_header_id;
    COMMIT;
  
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code    := 1;
      p_err_message := 'Error: Unable to insert Header -' || SQLERRM;
  END;
  -------------------------------------------------
  -- insert_line
  --
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --  1.0      3.2.13   yuval tal       cr 662 : add new fields  p_UOM
  --  1.1      15.9.13  yuval tal       cr1028 : add new fields  p_accounting_rule_id     p_service_start_date,p_service_end_date
  --  1.2      16.01.14 yuval tal       CR 1238 : add field REFERENCE_HEADER_ID REFERENCE_LINE_ID
  --------------------------------------------------
  PROCEDURE insert_line(p_interface_header_id    NUMBER,
                        p_line_number            VARCHAR2,
                        p_ordered_item           VARCHAR2,
                        p_ordered_quantity       VARCHAR2,
                        p_return_reason_code     VARCHAR2,
                        p_unit_selling_price     VARCHAR2,
                        p_maintenance_start_date VARCHAR2,
                        p_maintenance_end_date   VARCHAR2,
                        p_serial_number          VARCHAR2,
                        p_source_type_code       VARCHAR2,
                        p_organization_code      VARCHAR2,
                        p_uom                    VARCHAR2,
                        p_accounting_rule_id     VARCHAR2,
                        p_service_start_date     VARCHAR2,
                        p_service_end_date       VARCHAR2,
                        p_reference_header_id    NUMBER,
                        p_reference_line_id      NUMBER,
                        p_err_code               OUT NUMBER,
                        p_err_message            OUT VARCHAR2)
  
   IS
  
    l_maintenance_start_date DATE;
    l_maintenance_end_date   DATE;
    l_service_start_date     DATE;
    l_service_end_date       DATE;
  BEGIN
  
    p_err_code := 0;
    -- check date format
    -- l_maintenance_start_date
    BEGIN
    
      l_maintenance_start_date := to_date(p_maintenance_start_date,
                                          g_maintenance_date_format);
    EXCEPTION
      WHEN OTHERS THEN
      
        p_err_code := 1;
        fnd_message.set_name('XXOBJT', 'XXOM_SF2OA_BAD_DATE_FORMAT');
        fnd_message.set_token('FIELD', 'Maintenance_Start_Date');
        fnd_message.set_token('FORMAT', g_maintenance_date_format);
        p_err_message := fnd_message.get;
      
        RETURN;
    END;
    -- l_maintenance_end_date
    BEGIN
    
      l_maintenance_end_date := to_date(p_maintenance_end_date,
                                        g_maintenance_date_format);
    EXCEPTION
      WHEN OTHERS THEN
      
        p_err_code := 1;
        fnd_message.set_name('XXOBJT', 'XXOM_SF2OA_BAD_DATE_FORMAT');
        fnd_message.set_token('FIELD', 'Maintenance_End_Date');
        fnd_message.set_token('FORMAT', g_maintenance_date_format);
        p_err_message := fnd_message.get;
        RETURN;
    END;
  
    -- l_service_end_date
    BEGIN
    
      l_service_end_date := to_date(p_service_end_date,
                                    g_maintenance_date_format);
    EXCEPTION
      WHEN OTHERS THEN
      
        p_err_code := 1;
        fnd_message.set_name('XXOBJT', 'XXOM_SF2OA_BAD_DATE_FORMAT');
        fnd_message.set_token('FIELD', 'Service_End_Date');
        fnd_message.set_token('FORMAT', g_maintenance_date_format);
        p_err_message := fnd_message.get;
      
        RETURN;
    END;
  
    -- l_service_start_date
    BEGIN
    
      l_service_start_date := to_date(p_service_start_date,
                                      g_maintenance_date_format);
    EXCEPTION
      WHEN OTHERS THEN
      
        p_err_code := 1;
        fnd_message.set_name('XXOBJT', 'XXOM_SF2OA_BAD_DATE_FORMAT');
        fnd_message.set_token('FIELD', 'Service_Start_Date');
        fnd_message.set_token('FORMAT', g_maintenance_date_format);
        p_err_message := fnd_message.get;
      
        RETURN;
    END;
    ------------------------
  
    INSERT INTO xxom_sf2oa_lines_interface
      (interface_header_id,
       order_line_seq,
       line_number,
       ordered_item,
       ordered_quantity,
       return_reason_code,
       unit_selling_price,
       maintenance_start_date,
       maintenance_end_date,
       serial_number,
       creation_date,
       source_type_code,
       organization_code,
       uom,
       accounting_rule_id,
       service_start_date,
       service_end_date,
       reference_header_id,
       reference_line_id)
    
    VALUES
      (p_interface_header_id,
       xxom_sf2oa_line_int_seq.nextval,
       p_line_number,
       upper(p_ordered_item),
       p_ordered_quantity,
       p_return_reason_code,
       p_unit_selling_price,
       l_maintenance_start_date,
       l_maintenance_end_date,
       p_serial_number,
       SYSDATE,
       upper(p_source_type_code),
       p_organization_code,
       p_uom,
       p_accounting_rule_id,
       l_service_start_date,
       l_service_end_date,
       p_reference_header_id,
       p_reference_line_id);
    COMMIT;
  
  EXCEPTION
    WHEN OTHERS THEN
    
      p_err_code    := 1;
      p_err_message := 'Error: Unable to insert line No -' || p_line_number || ' ' ||
                       SQLERRM;
  END;
  -------------------------------------------------
  --  create_order
  --  create sales order according to data in tables xxom_sf2oa_header_interface, xxom_sf2oa_lines_interface
  --  filled  by bpel service being called by SYSS Salesfoce Site

  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --  1.1      15.9.13  yuval tal       cr1028 : add new fields  p_accounting_rule_id     p_service_start_date,p_service_end_date
  --  1.2      16.01.14  yuval tal      CR1238 add fields header :SALESREP_ID number  , Attribute10     varchar2(240),PRICE_LIST_ID  number;
  --                                                        line level :REFERENCE_HEADER_ID REFERENCE_LINE_ID
  --------------------------------------------------
  PROCEDURE create_order(p_header_seq      NUMBER,
                         p_err_code        OUT VARCHAR2,
                         p_err_message     OUT VARCHAR2,
                         p_order_number    OUT NUMBER,
                         p_order_header_id OUT NUMBER,
                         p_order_status    OUT VARCHAR2) IS
  
    CURSOR c_header IS
      SELECT *
        FROM xxom_sf2oa_header_interface t
       WHERE t.interface_header_id = p_header_seq;
  
    CURSOR c_lines IS
      SELECT *
        FROM xxom_sf2oa_lines_interface t
       WHERE t.interface_header_id = p_header_seq
       ORDER BY t.line_number;
  
    CURSOR c_shipping(c_ship_method_code  VARCHAR2,
                      c_organization_code VARCHAR2) IS
      SELECT 'Y'
        FROM wsh_carrier_ship_methods_v tt
       WHERE tt.enabled_flag = 'Y'
         AND tt.ship_method_code = c_ship_method_code
         AND tt.organization_code = c_organization_code;
  
    l_header_rec oe_order_pub.header_rec_type;
    l_line_tbl   oe_order_pub.line_tbl_type;
    l_inx        NUMBER;
    l_my_exception EXCEPTION;
    l_org_id NUMBER;
  
    l_user_id      NUMBER;
    l_resp_id      NUMBER;
    l_resp_appl_id NUMBER;
    --
    l_order_source_id  NUMBER;
    l_pos_line_type_id NUMBER;
    l_neg_line_type_id NUMBER;
    l_tmp              VARCHAR2(500);
    l_line_exists_flag NUMBER := 0;
    l_header_flag      NUMBER := 0;
  BEGIN
  
    --- set status to in process
    UPDATE xxom_sf2oa_header_interface t
       SET t.status_code = 'P', t.status_message = NULL
     WHERE t.interface_header_id = p_header_seq;
    COMMIT;
  
    p_err_code    := 'S';
    p_err_message := '';
    fnd_message.clear;
    -- set resp env param
  
    l_user_id      := 4290; -- SALESFORCE
    l_resp_appl_id := 660; ---?????????????????
  
    -- get order source id
  
    -- SAVEPOINT a;
    BEGIN
      dbms_output.put_line('Start validation...' ||
                           to_char(SYSDATE, 'hh24:mi:ss'));
      SELECT t.order_source_id
        INTO l_order_source_id
        FROM oe_order_sources t
       WHERE upper(t.name) = upper('Service SFDC');
    EXCEPTION
      WHEN OTHERS THEN
      
        p_err_message := 'Unable to get Order source Id for source = Service SFDC';
        RAISE l_my_exception;
    END;
  
    --
    -- set id's and validation checks
    --
  
    FOR i IN c_header LOOP
    
      l_header_flag := 1;
    
      -- check exists 
    
      check_order_exists(i.orig_sys_document_ref,
                         l_order_source_id,
                         i.org_id,
                         i.interface_header_id,
                         p_err_message,
                         p_order_number,
                         p_order_header_id,
                         p_order_status);
    
      IF p_order_number IS NOT NULL THEN
        UPDATE xxom_sf2oa_header_interface t
           SET t.header_id        = p_order_header_id,
               t.status_code      = 'S',
               t.status_message   = substr(p_err_message, 1, 2000),
               t.last_update_date = SYSDATE,
               t.last_updated_by  = fnd_global.user_id
         WHERE t.interface_header_id = p_header_seq;
        COMMIT;
        RETURN;
      
      ELSIF p_err_message IS NOT NULL THEN
        RAISE l_my_exception;
      END IF;
    
      -- check required
    
      -- organization_code
      IF i.organization_code IS NULL THEN
        fnd_message.set_name('XXOBJT', 'XXOM_SF2OA_REQUIRED_HDR_FIELD');
        fnd_message.set_token('FIELD', 'Organization_Code');
        p_err_message := fnd_message.get;
        RAISE l_my_exception;
      END IF;
    
      -- org_id
      IF i.org_id IS NULL THEN
        fnd_message.set_name('XXOBJT', 'XXOM_SF2OA_REQUIRED_HDR_FIELD');
        fnd_message.set_token('FIELD', 'Org_Id');
        p_err_message := fnd_message.get;
        RAISE l_my_exception;
      END IF;
    
      -- Shipping_Site_Num
      IF i.shipping_site_num IS NULL THEN
        fnd_message.set_name('XXOBJT', 'XXOM_SF2OA_REQUIRED_HDR_FIELD');
        fnd_message.set_token('FIELD', 'Shipping_Site_Num');
        p_err_message := fnd_message.get;
        RAISE l_my_exception;
      END IF;
      --   Account_Number
    
      IF i.cust_account_number IS NULL THEN
        fnd_message.set_name('XXOBJT', 'XXOM_SF2OA_REQUIRED_HDR_FIELD');
        fnd_message.set_token('FIELD', 'Account_Number');
        p_err_message := fnd_message.get;
        RAISE l_my_exception;
      END IF;
    
      -- ship_from_org_id/Org_id
      BEGIN
      
        SELECT t.organization_id ship_from_org_id
          INTO i.ship_from_org_id
          FROM xxobjt_org_organization_def_v t
         WHERE t.organization_code = i.organization_code;
      EXCEPTION
      
        WHEN OTHERS THEN
        
          fnd_message.set_name('XXOBJT', 'XXOM_SF2OA_INVALID_VALUE');
          fnd_message.set_token('FIELD', 'Organization_Code');
          p_err_message := fnd_message.get;
          RAISE l_my_exception;
        
      END;
    
      -- Invoice_Site_Num
    
      IF i.invoice_site_num IS NULL THEN
        fnd_message.set_name('XXOBJT', 'XXOM_SF2OA_REQUIRED_HDR_FIELD');
        fnd_message.set_token('FIELD', 'Invoice_Site_Num');
        p_err_message := fnd_message.get;
        RAISE l_my_exception;
      END IF;
    
      -- operation
      IF i.operation IS NULL THEN
        fnd_message.set_name('XXOBJT', 'XXOM_SF2OA_REQUIRED_HDR_FIELD');
        fnd_message.set_token('FIELD', 'Operation');
        p_err_message := fnd_message.get;
        RAISE l_my_exception;
      END IF;
    
      -- currency
    
      IF i.currency_code IS NULL THEN
        fnd_message.set_name('XXOBJT', 'XXOM_SF2OA_REQUIRED_HDR_FIELD');
        fnd_message.set_token('FIELD', 'Currency_Code');
        p_err_message := fnd_message.get;
        RAISE l_my_exception;
      END IF;
    
      -- find oracle ID's
    
      l_org_id := i.org_id;
    
      -- order type id's + resp_id for initial env
    
      get_order_type_details(p_org_id           => l_org_id,
                             p_operation        => i.operation,
                             p_order_type_id    => i.order_type_id,
                             p_pos_line_type_id => l_pos_line_type_id,
                             p_neg_line_type_id => l_neg_line_type_id,
                             p_resp_id          => l_resp_id);
    
      IF l_resp_id IS NULL THEN
      
        fnd_message.set_name('XXOBJT', 'XXOM_SF2OA_INVALID_VALUE');
        fnd_message.set_token('FIELD',
                              'l_resp_id (valueset XXOM_SF2OA_Order_Types_Mapping)');
        p_err_message := fnd_message.get;
        RAISE l_my_exception;
      END IF;
    
      IF l_pos_line_type_id IS NULL THEN
      
        fnd_message.set_name('XXOBJT', 'XXOM_SF2OA_INVALID_ORD_TYPE');
        fnd_message.set_token('OPERATION', i.operation);
        fnd_message.set_token('ORGANIZATION_CODE', i.organization_code);
        p_err_message := fnd_message.get;
        RAISE l_my_exception;
      END IF;
    
      -- init environment befor selects from hz_party tables
      fnd_global.apps_initialize(l_user_id, 0, 0);
      fnd_global.apps_initialize(l_user_id, l_resp_id, l_resp_appl_id);
    
      mo_global.init('ONT');
      mo_global.set_policy_context('S', l_org_id);
    
      -- sold_to_org_id
      i.sold_to_org_id := get_sold_to_org_id(i.cust_account_number, NULL);
      IF i.sold_to_org_id IS NULL THEN
      
        fnd_message.set_name('XXOBJT', 'XXOM_SF2OA_INVALID_VALUE');
        fnd_message.set_token('FIELD', 'Account_Number');
        p_err_message := fnd_message.get;
        RAISE l_my_exception;
      
      END IF;
    
      -- check account-org id match
      i.sold_to_org_id := get_sold_to_org_id(i.cust_account_number,
                                             l_org_id);
      IF i.sold_to_org_id IS NULL THEN
      
        fnd_message.set_name('XXOBJT', 'XXOM_SF2OA_INVALID_RELATION');
        fnd_message.set_token('FIELD1',
                              'Account_Number ' || i.cust_account_number);
        fnd_message.set_token('FIELD2',
                              'Organization_Code ' || i.organization_code);
        p_err_message := fnd_message.get;
        RAISE l_my_exception;
      
      END IF;
    
      -- ship/invoice to_org_id
    
      i.ship_to_org_id := get_ship_invoice_org_id(NULL, /*i.cust_account_number*/
                                                  i.shipping_site_num,
                                                  'SHIP_TO',
                                                  l_org_id);
    
      i.invoice_to_org_id := get_ship_invoice_org_id(NULL,
                                                     i.invoice_site_num,
                                                     'BILL_TO',
                                                     l_org_id);
    
      -- ship to contact id
    
      i.ship_to_contact_id := get_contact_id(i.ship_to_contact_num, NULL);
    
      IF i.ship_to_contact_num IS NOT NULL AND i.ship_to_contact_id IS NULL THEN
        fnd_message.set_name('XXOBJT', 'XXOM_SF2OA_INVALID_VALUE');
        fnd_message.set_token('FIELD', 'Ship_To_Contact_Num');
        p_err_message := fnd_message.get;
        RAISE l_my_exception;
      
      END IF;
    
      --- invoice to contact
    
      i.invoice_to_contact_id := get_contact_id(i.invoice_to_contact_num,
                                                NULL);
    
      IF i.invoice_to_contact_num IS NOT NULL AND
         i.invoice_to_contact_id IS NULL THEN
        fnd_message.set_name('XXOBJT', 'XXOM_SF2OA_INVALID_VALUE');
        fnd_message.set_token('FIELD', 'Invoice_To_Contact_Num');
        p_err_message := fnd_message.get;
        RAISE l_my_exception;
      
      END IF;
    
      ----------------------------
      -- check lookup existance
      -----------------------------
      -- ship method code
    
      IF i.shipping_method_code IS NOT NULL THEN
        l_tmp := xxinv_utils_pkg.get_lookup_meaning(p_lookup_type => 'SHIP_METHOD',
                                                    p_lookup_code => i.shipping_method_code);
      
        IF l_tmp IS NULL THEN
          -- fnd_message.set_name('XXOBJT', 'XXOM_SF2OA_SHIP_METHOD_MISS');
        
          fnd_message.set_name('XXOBJT', 'XXOM_SF2OA_INVALID_VALUE');
          fnd_message.set_token('FIELD',
                                'Shipping_Method_Code ' ||
                                i.shipping_method_code);
        
          p_err_message := fnd_message.get;
        
          RAISE l_my_exception;
        END IF;
      
        -- check ship relate to org
        l_tmp := NULL;
        OPEN c_shipping(i.shipping_method_code, i.organization_code);
        FETCH c_shipping
          INTO l_tmp;
        CLOSE c_shipping;
      
        IF nvl(l_tmp, 'N') = 'N' THEN
          fnd_message.set_name('XXOBJT', 'XXOM_SF2OA_INVALID_RELATION');
          fnd_message.set_token('FIELD1',
                                'Shipping_Method_Code ' ||
                                i.shipping_method_code);
          fnd_message.set_token('FIELD2',
                                'Organization_Code ' || i.organization_code);
          p_err_message := fnd_message.get;
          RAISE l_my_exception;
        
        END IF;
      
      END IF;
    
      -- FREIGHT_TERMS
      IF i.freight_terms_code IS NOT NULL THEN
        l_tmp := xxinv_utils_pkg.get_lookup_meaning(p_lookup_type => 'FREIGHT_TERMS',
                                                    p_lookup_code => i.freight_terms_code);
      
        IF l_tmp IS NULL THEN
        
          fnd_message.set_name('XXOBJT', 'XXOM_SF2OA_INVALID_VALUE');
          fnd_message.set_token('FIELD',
                                'Freight_Terms_Code ' ||
                                i.freight_terms_code);
          p_err_message := fnd_message.get;
        
          RAISE l_my_exception;
        END IF;
      END IF;
    
      -- save calc fields
    
      UPDATE xxom_sf2oa_header_interface t
         SET t.order_type_id         = i.order_type_id,
             t.ship_to_org_id        = i.ship_to_org_id,
             t.sold_to_org_id        = i.sold_to_org_id,
             t.ship_from_org_id      = i.ship_from_org_id,
             t.invoice_to_org_id     = i.invoice_to_org_id,
             t.ship_to_contact_id    = i.ship_to_contact_id,
             t.invoice_to_contact_id = i.invoice_to_contact_id,
             t.order_source_id       = l_order_source_id,
             t.last_update_date      = SYSDATE,
             t.last_updated_by       = fnd_global.user_id
      
       WHERE t.interface_header_id = p_header_seq;
    
      COMMIT;
    
      --------------------------------------------------
      -------------- lines validation ------------------
      --------------------------------------------------
    
      FOR j IN c_lines LOOP
      
        l_line_exists_flag := 1;
        -- check required
        -- return_reason_code
        IF j.ordered_quantity < 0 AND j.return_reason_code IS NULL THEN
        
          fnd_message.set_name('XXOBJT', 'XXOM_SF2OA_REQUIRED_LINE_FIELD');
          fnd_message.set_token('FIELD', 'Return_reason_Code');
          fnd_message.set_token('LINE_NO', j.line_number);
          p_err_message := fnd_message.get;
          RAISE l_my_exception;
        
        END IF;
      
        ---
        IF j.ordered_quantity IS NULL THEN
        
          fnd_message.set_name('XXOBJT', 'XXOM_SF2OA_REQUIRED_LINE_FIELD');
          fnd_message.set_token('FIELD', 'Quantity');
          fnd_message.set_token('LINE_NO', j.line_number);
          p_err_message := fnd_message.get;
          RAISE l_my_exception;
        END IF;
      
        -- unit price
        IF j.unit_selling_price IS NULL THEN
        
          fnd_message.set_name('XXOBJT', 'XXOM_SF2OA_REQUIRED_LINE_FIELD');
          fnd_message.set_token('FIELD', 'Unit_Selling_Price');
          fnd_message.set_token('LINE_NO', j.line_number);
          p_err_message := fnd_message.get;
          RAISE l_my_exception;
        END IF;
      
        -- line_number
        IF j.line_number IS NULL THEN
          fnd_message.set_name('XXOBJT', 'XXOM_SF2OA_REQUIRED_LINE_FIELD');
          fnd_message.set_token('FIELD', 'Order_Line_number');
          fnd_message.set_token('LINE_NO', c_lines%ROWCOUNT);
          p_err_message := fnd_message.get;
          RAISE l_my_exception;
        END IF;
      
        -- ship from org
        IF j.organization_code IS NOT NULL THEN
          BEGIN
          
            SELECT /*t.operating_unit,*/
             t.organization_id ship_from_org_id
              INTO /*l_org_id,*/ j.ship_from_org_id
              FROM xxobjt_org_organization_def_v t
             WHERE t.organization_code = j.organization_code;
          EXCEPTION
          
            WHEN OTHERS THEN
            
              fnd_message.set_name('XXOBJT', 'XXOM_SF2OA_INVALID_VALUE');
              fnd_message.set_token('FIELD',
                                    'Organization_Code (Line Level) ');
              p_err_message := fnd_message.get;
              RAISE l_my_exception;
            
          END;
        END IF;
      
        -- inventory_item_id
      
        BEGIN
          SELECT msib.inventory_item_id
            INTO j.inventory_item_id
            FROM mtl_system_items_b msib
           WHERE msib.segment1 = j.ordered_item
             AND msib.organization_id = 91;
        
        EXCEPTION
          WHEN no_data_found THEN
          
            fnd_message.set_name('XXOBJT',
                                 'XXOM_SF2OA_REQUIRED_ITEM_FIELD');
            fnd_message.set_token('ITEM', j.ordered_item);
            fnd_message.set_token('LINE_NO', j.line_number);
            p_err_message := fnd_message.get;
          
            RAISE l_my_exception;
        END;
      
        -- line_type_id
        IF j.ordered_quantity >= 0 THEN
          j.line_type_id := l_pos_line_type_id;
        ELSE
          j.line_type_id := l_neg_line_type_id;
        END IF;
      
        -- save calc fields
        UPDATE xxom_sf2oa_lines_interface l
           SET l.line_type_id      = j.line_type_id,
               l.inventory_item_id = j.inventory_item_id,
               l.ship_from_org_id  = j.ship_from_org_id
         WHERE l.interface_header_id = j.interface_header_id
           AND l.order_line_seq = j.order_line_seq;
        COMMIT;
      
      END LOOP;
    
      -- check lines exists
      IF nvl(l_line_exists_flag, 0) = 0 THEN
      
        p_err_message := 'No lines Found for Order'; --fnd_message.get;
      
        RAISE l_my_exception;
      
      END IF;
    
    END LOOP;
  
    -- check header exists
    IF l_header_flag = 0 THEN
    
      p_err_message := 'No Header Found for p_header_seq=' || p_header_seq; --fnd_message.get;
    
      RAISE l_my_exception;
    
    END IF;
  
    ------------------------------------------------------------
    --
    --
    --
    ---- prepare  order API
    --------------------------------------------------------------
  
    FOR i IN c_header LOOP
    
      l_header_rec           := oe_order_pub.g_miss_header_rec;
      l_header_rec.operation := oe_globals.g_opr_create;
      -- set header variables
      l_header_rec.org_id                  := i.org_id;
      l_header_rec.order_type_id           := i.order_type_id;
      l_header_rec.sold_to_org_id          := i.sold_to_org_id;
      l_header_rec.ship_to_org_id          := i.ship_to_org_id;
      l_header_rec.invoice_to_org_id       := i.invoice_to_org_id;
      l_header_rec.pricing_date            := SYSDATE;
      l_header_rec.ship_from_org_id        := i.ship_from_org_id;
      l_header_rec.transactional_curr_code := i.currency_code;
      l_header_rec.flow_status_code        := 'ENTERED';
      l_header_rec.cust_po_number          := nvl(i.cust_po, 'No PO');
      l_header_rec.order_source_id         := l_order_source_id;
      l_header_rec.freight_terms_code      := nvl(i.freight_terms_code,
                                                  fnd_api.g_miss_char);
      l_header_rec.shipping_method_code    := nvl(i.shipping_method_code,
                                                  fnd_api.g_miss_char);
      l_header_rec.orig_sys_document_ref   := i.orig_sys_document_ref;
      l_header_rec.ordered_date            := i.ordered_date;
      l_header_rec.ship_to_contact_id      := i.ship_to_contact_id;
      l_header_rec.invoice_to_contact_id   := i.invoice_to_contact_id;
      l_header_rec.shipping_instructions   := i.shipping_comments;
      --  l_header_rec.price_list_id           := i.price_list_id;
      l_header_rec.attribute10 := i.attribute10;
      -- l_header_rec.salesrep_id             := i.salesrep_id;
    
      BEGIN
        SELECT con.descriptive_flex_context_code
          INTO l_header_rec.context
          FROM fnd_descr_flex_contexts_vl con, fnd_application_vl fav
         WHERE con.descriptive_flex_context_code =
               get_order_type_name(i.order_type_id)
           AND fav.application_id = con.application_id
           AND fav.application_name = 'Order Management'
           AND con.descriptive_flexfield_name = 'OE_HEADER_ATTRIBUTES';
      EXCEPTION
        WHEN OTHERS THEN
          NULL;
        
      END;
      -- l_header_rec.context := get_order_type_name(i.order_type_id);
    
      SELECT decode(i.price_list_id, 0, fnd_api.g_miss_num, i.price_list_id),
             decode(i.salesrep_id, 0, fnd_api.g_miss_num, i.salesrep_id)
        INTO l_header_rec.price_list_id, l_header_rec.salesrep_id
        FROM dual;
    
      -- get user_id from email
      BEGIN
        SELECT nvl(user_id, l_user_id)
          INTO l_user_id
          FROM fnd_user u
         WHERE upper(u.email_address) = upper(i.email)
           AND rownum = 1;
      
      EXCEPTION
        WHEN OTHERS THEN
          NULL;
      END;
      --
    
      FOR j IN c_lines LOOP
        l_inx := c_lines%ROWCOUNT;
      
        -- set lines variables
        l_line_tbl(l_inx) := oe_order_pub.g_miss_line_rec;
        l_line_tbl(l_inx).line_number := j.line_number;
        l_line_tbl(l_inx).operation := oe_globals.g_opr_create;
        l_line_tbl(l_inx).inventory_item_id := j.inventory_item_id;
        l_line_tbl(l_inx).ordered_quantity := j.ordered_quantity;
        l_line_tbl(l_inx).ship_to_org_id := i.ship_to_org_id;
        l_line_tbl(l_inx).return_reason_code := nvl(j.return_reason_code,
                                                    fnd_api.g_miss_char);
      
        l_line_tbl(l_inx).ship_from_org_id := j.ship_from_org_id;
      
        SELECT decode(j.reference_header_id, 0, NULL, j.reference_header_id),
               decode(j.reference_line_id, 0, NULL, j.reference_line_id)
          INTO l_line_tbl(l_inx).reference_header_id,
               l_line_tbl(l_inx).reference_line_id
          FROM dual;
      
        SELECT decode(sign(j.ordered_quantity),
                      -1,
                      l_neg_line_type_id,
                      l_pos_line_type_id)
          INTO l_line_tbl(l_inx).line_type_id
          FROM dual;
        -- cr1025
        l_line_tbl(l_inx).accounting_rule_id := nvl(j.accounting_rule_id,
                                                    fnd_api.g_miss_num);
        l_line_tbl(l_inx).service_start_date := nvl(j.service_start_date,
                                                    fnd_api.g_miss_date);
        l_line_tbl(l_inx).service_end_date := nvl(j.service_end_date,
                                                  fnd_api.g_miss_date);
      
        --cr1025
      
        l_line_tbl(l_inx).unit_selling_price := j.unit_selling_price;
        l_line_tbl(l_inx).calculate_price_flag := 'N';
        l_line_tbl(l_inx).unit_list_price := j.unit_selling_price;
      
        l_line_tbl(l_inx).attribute12 := fnd_date.date_to_canonical(j.maintenance_start_date);
        l_line_tbl(l_inx).attribute13 := fnd_date.date_to_canonical(j.maintenance_end_date);
        l_line_tbl(l_inx).attribute14 := j.serial_number;
        l_line_tbl(l_inx).source_type_code := j.source_type_code;
        -- set context
        IF l_line_tbl(l_inx).attribute12 IS NOT NULL OR l_line_tbl(l_inx)
           .attribute13 IS NOT NULL OR l_line_tbl(l_inx)
           .attribute14 IS NOT NULL THEN
          l_line_tbl(l_inx).context := get_order_type_name(i.order_type_id);
        
        END IF;
      
        l_line_tbl(l_inx).order_quantity_uom := nvl(j.uom,
                                                    fnd_api.g_miss_char);
        -- l_line_tbl(l_inx).pricing_quantity_uom := j.uom;
      
      END LOOP;
      dbms_output.put_line('End  validation...Start Api' ||
                           to_char(SYSDATE, 'hh24:mi:ss'));
    
      --
      -- create order
      --
    
      create_order_api(l_org_id,
                       l_user_id,
                       l_resp_id,
                       l_resp_appl_id,
                       l_header_rec,
                       l_line_tbl,
                       --   l_line_adj_tbl,
                       p_order_number,
                       p_order_header_id,
                       p_order_status,
                       p_err_code,
                       p_err_message);
    
      -- update result
      dbms_output.put_line('End  Api...' || to_char(SYSDATE, 'hh24:mi:ss'));
      p_err_message := REPLACE(p_err_message,
                               'This Customer' || '''' ||
                               's PO Number is referenced by another order');
    
      UPDATE xxom_sf2oa_header_interface t
         SET t.header_id        = p_order_header_id,
             t.status_code      = decode(p_err_code,
                                         '0',
                                         'S',
                                         '1',
                                         'E',
                                         status_code),
             t.status_message   = substr(p_err_message, 1, 2000),
             t.last_update_date = SYSDATE,
             t.last_updated_by  = fnd_global.user_id
      
       WHERE t.interface_header_id = p_header_seq
      RETURNING status_code INTO p_err_code;
      COMMIT;
    
      IF p_err_code = 'S' AND p_order_status = 'BOOKED' THEN
        p_err_message := NULL;
      END IF;
    
    ---
    END LOOP;
  
  EXCEPTION
    WHEN l_my_exception THEN
      --  ROLLBACK TO a;
      p_err_code := 'E';
      UPDATE xxom_sf2oa_header_interface t
         SET t.status_code = 'E', t.status_message = p_err_message
       WHERE t.interface_header_id = p_header_seq;
      COMMIT;
  END;

  --------------------------------------------
  -- create_order_api
  --
  -- caliing so api
  --------------------------------------------

  PROCEDURE create_order_api(p_org_id     NUMBER,
                             p_user_id    NUMBER,
                             p_resp_id    NUMBER,
                             p_appl_id    NUMBER,
                             p_header_rec oe_order_pub.header_rec_type,
                             p_line_tbl   oe_order_pub.line_tbl_type,
                             --   p_line_adj_tbl_type oe_order_pub.line_adj_tbl_type,
                             p_order_number OUT NUMBER,
                             p_header_id    OUT NUMBER,
                             p_order_status OUT VARCHAR2,
                             p_err_code     OUT VARCHAR2,
                             p_err_message  OUT VARCHAR2) IS
    l_api_version_number NUMBER := 1;
  
    l_return_status VARCHAR2(2000);
    l_msg_count     NUMBER;
    l_msg_data      VARCHAR2(2000);
    /*****************PARAMETERS****************************************************/
    l_debug_level NUMBER := 0; -- OM DEBUG LEVEL (MAX 5) fnd_profile.value('ONT_DEBUG_LEVEL')
    --  l_org         NUMBER := p_org_id; --204; -- OPERATING UNIT
    l_user NUMBER := p_user_id; --1318; -- USER
    l_resp NUMBER := p_resp_id; --21623; -- RESPONSIBLILTY
    l_appl NUMBER := p_appl_id; --660; -- ORDER MANAGEMENT
    /***INPUT VARIABLES FOR PROCESS_ORDER API*************************/
  
    --  l_header_rec         oe_order_pub.header_rec_type;
    -- l_line_tbl           oe_order_pub.line_tbl_type;
    l_action_request_tbl oe_order_pub.request_tbl_type;
  
    /***OUT VARIABLES FOR PROCESS_ORDER API***************************/
    l_header_rec_out             oe_order_pub.header_rec_type;
    l_header_val_rec_out         oe_order_pub.header_val_rec_type;
    l_header_adj_tbl_out         oe_order_pub.header_adj_tbl_type;
    l_header_adj_val_tbl_out     oe_order_pub.header_adj_val_tbl_type;
    l_header_price_att_tbl_out   oe_order_pub.header_price_att_tbl_type;
    l_header_adj_att_tbl_out     oe_order_pub.header_adj_att_tbl_type;
    l_header_adj_assoc_tbl_out   oe_order_pub.header_adj_assoc_tbl_type;
    l_header_scredit_tbl_out     oe_order_pub.header_scredit_tbl_type;
    l_header_scredit_val_tbl_out oe_order_pub.header_scredit_val_tbl_type;
    l_line_tbl_out               oe_order_pub.line_tbl_type;
    l_line_val_tbl_out           oe_order_pub.line_val_tbl_type;
    l_line_adj_tbl_out           oe_order_pub.line_adj_tbl_type;
    l_line_adj_val_tbl_out       oe_order_pub.line_adj_val_tbl_type;
    l_line_price_att_tbl_out     oe_order_pub.line_price_att_tbl_type;
    l_line_adj_att_tbl_out       oe_order_pub.line_adj_att_tbl_type;
    l_line_adj_assoc_tbl_out     oe_order_pub.line_adj_assoc_tbl_type;
    l_line_scredit_tbl_out       oe_order_pub.line_scredit_tbl_type;
    l_line_scredit_val_tbl_out   oe_order_pub.line_scredit_val_tbl_type;
    l_lot_serial_tbl_out         oe_order_pub.lot_serial_tbl_type;
    l_lot_serial_val_tbl_out     oe_order_pub.lot_serial_val_tbl_type;
    l_action_request_tbl_out     oe_order_pub.request_tbl_type;
    l_msg_index                  NUMBER;
    l_data                       VARCHAR2(2000);
    --l_loop_count                 NUMBER;
    l_debug_file VARCHAR2(200);
    -- book API vars
  
    --  b_return_status VARCHAR2(200);
    --b_msg_count     NUMBER;
    -- b_msg_data      VARCHAR2(2000);
  BEGIN
    p_err_code := 0;
  
    -- dbms_application_info.set_client_info(l_org);
  
    /*****************INITIALIZE DEBUG INFO*************************************/
  
    IF (l_debug_level > 0) THEN
      l_debug_file := oe_debug_pub.set_debug_mode('FILE');
      oe_debug_pub.initialize;
      oe_debug_pub.setdebuglevel(l_debug_level);
      --   oe_msg_pub.initialize;
    END IF;
    oe_msg_pub.initialize;
    /*****************INITIALIZE ENVIRONMENT*************************************/
  
    -- fnd_global.apps_initialize(l_user, l_resp, l_appl, 0, 0);
    --  fnd_profile.initialize_org_context;
    -- dbms_output.put_line('l_resp=' || l_resp);
    fnd_global.apps_initialize(l_user, l_resp, l_appl);
    -- fnd_profile.initialize_org_context;
  
    mo_global.set_policy_context('S', p_org_id);
    dbms_output.put_line('XXOM_SF2OA_ORDER_STATUS=' ||
                         fnd_profile.value('XXOM_SF2OA_ORDER_STATUS'));
    dbms_output.put_line('p_org_id=' || p_org_id || ' ORG_ID=' ||
                         fnd_global.org_id || ' USER_ID=' ||
                         fnd_global.user_id);
    mo_global.init('ONT');
  
    /*****************INITIALIZE HEADER RECORD******************************/
    -- l_header_rec := oe_order_pub.g_miss_header_rec;
  
    /***********POPULATE REQUIRED ATTRIBUTES **********************************/
    --  l_header_rec := p_header_rec;
  
    /*******INITIALIZE ACTION REQUEST RECORD*************************************/
  
    IF xxobjt_general_utils_pkg.get_profile_value('XXOM_SF2OA_ORDER_STATUS',
                                                  'ORG',
                                                  p_org_id) /*fnd_profile.value('XXOM_SF2OA_ORDER_STATUS')*/
       = 'BOOKED' THEN
      l_action_request_tbl(1) := oe_order_pub.g_miss_request_rec;
      l_action_request_tbl(1).request_type := oe_globals.g_book_order;
      l_action_request_tbl(1).entity_code := oe_globals.g_entity_header;
    END IF;
  
    /*****************INITIALIZE LINE RECORD********************************/
  
    /* FOR i IN 1 .. p_line_tbl.count LOOP
      l_line_tbl(i) := oe_order_pub.g_miss_line_rec;
    
      l_line_tbl(i) := p_line_tbl(i);
    
    END LOOP;*/
  
    /*****************CALLTO PROCESS ORDER API*********************************/
    dbms_output.put_line('Calling API');
    oe_order_pub.process_order(p_api_version_number => l_api_version_number, --1
                               p_header_rec         => p_header_rec,
                               p_line_tbl           => p_line_tbl,
                               p_action_request_tbl => l_action_request_tbl,
                               --    p_line_adj_tbl       => l_line_adj_tbl_type,
                               --OUT variables
                               x_header_rec             => l_header_rec_out,
                               x_header_val_rec         => l_header_val_rec_out,
                               x_header_adj_tbl         => l_header_adj_tbl_out,
                               x_header_adj_val_tbl     => l_header_adj_val_tbl_out,
                               x_header_price_att_tbl   => l_header_price_att_tbl_out,
                               x_header_adj_att_tbl     => l_header_adj_att_tbl_out,
                               x_header_adj_assoc_tbl   => l_header_adj_assoc_tbl_out,
                               x_header_scredit_tbl     => l_header_scredit_tbl_out,
                               x_header_scredit_val_tbl => l_header_scredit_val_tbl_out,
                               x_line_tbl               => l_line_tbl_out,
                               x_line_val_tbl           => l_line_val_tbl_out,
                               x_line_adj_tbl           => l_line_adj_tbl_out,
                               x_line_adj_val_tbl       => l_line_adj_val_tbl_out,
                               x_line_price_att_tbl     => l_line_price_att_tbl_out,
                               x_line_adj_att_tbl       => l_line_adj_att_tbl_out,
                               x_line_adj_assoc_tbl     => l_line_adj_assoc_tbl_out,
                               x_line_scredit_tbl       => l_line_scredit_tbl_out,
                               x_line_scredit_val_tbl   => l_line_scredit_val_tbl_out,
                               x_lot_serial_tbl         => l_lot_serial_tbl_out,
                               x_lot_serial_val_tbl     => l_lot_serial_val_tbl_out,
                               x_action_request_tbl     => l_action_request_tbl_out,
                               x_return_status          => l_return_status,
                               x_msg_count              => l_msg_count,
                               x_msg_data               => l_msg_data);
  
    /*****************CHECK RETURN STATUS***********************************/
    IF l_return_status = fnd_api.g_ret_sts_success THEN
      dbms_output.put_line('Return status is success ');
      dbms_output.put_line('debug level ' || l_debug_level);
      p_err_code     := 0;
      p_order_number := l_header_rec_out.order_number;
      p_header_id    := l_header_rec_out.header_id;
    
      SELECT flow_status_code
        INTO p_order_status
        FROM oe_order_headers_all t
       WHERE t.header_id = l_header_rec_out.header_id;
    
      COMMIT;
    ELSE
      p_err_code := 1;
      dbms_output.put_line('Return status failure ');
      IF (l_debug_level > 0) THEN
        dbms_output.put_line('failure');
      
      END IF;
      ROLLBACK;
    END IF;
  
    /*****************DISPLAY RETURN STATUS FLAGS******************************/
    IF (l_debug_level > 0) THEN
    
      dbms_output.put_line('process ORDER ret status IS: ' ||
                           l_return_status);
      dbms_output.put_line('process ORDER msg data IS: ' || l_msg_data);
      dbms_output.put_line('process ORDER msg COUNT IS: ' || l_msg_count);
      dbms_output.put_line('header.order_number IS: ' ||
                           to_char(l_header_rec_out.order_number));
      dbms_output.put_line('header.return_status IS: ' ||
                           l_header_rec_out.return_status);
      dbms_output.put_line('header.booked_flag IS: ' ||
                           l_header_rec_out.booked_flag);
      dbms_output.put_line('header.header_id IS: ' ||
                           l_header_rec_out.header_id);
      dbms_output.put_line('header.order_source_id IS: ' ||
                           l_header_rec_out.order_source_id);
      dbms_output.put_line('header.flow_status_code IS: ' ||
                           l_header_rec_out.flow_status_code);
    
    END IF;
    /*****************DISPLAY ERROR MSGS*************************************/
    -- IF (l_debug_level > 0) THEN
    FOR i IN 1 .. l_msg_count LOOP
      oe_msg_pub.get(p_msg_index     => i,
                     p_encoded       => fnd_api.g_false,
                     p_data          => l_data,
                     p_msg_index_out => l_msg_index);
      dbms_output.put_line('message is: ' || l_data);
      dbms_output.put_line('message index is: ' || l_msg_index);
    
      p_err_message := p_err_message || '|' || l_data;
    END LOOP;
    p_err_message := ltrim(p_err_message, '|');
    --  END IF;
    IF (l_debug_level > 0) THEN
      dbms_output.put_line('Debug = ' || oe_debug_pub.g_debug);
      dbms_output.put_line('Debug Level = ' ||
                           to_char(oe_debug_pub.g_debug_level));
      dbms_output.put_line('Debug File = ' || oe_debug_pub.g_dir || '/' ||
                           oe_debug_pub.g_file);
      dbms_output.put_line('****************************************************');
    
      oe_debug_pub.debug_off;
    END IF;
  
  END;

END;
/
