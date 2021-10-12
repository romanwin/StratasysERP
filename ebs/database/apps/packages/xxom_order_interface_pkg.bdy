create or replace package body xxom_order_interface_pkg AS

  --------------------------------------------------------------------
  --  name:              XXOM_ORDER_INTERFACE_PKG
  --  create by:         yuval tal
  --  Revision:          1.1
  --  creation date:     26/05/2013
  --------------------------------------------------------------------
  --  purpose :          CUST 675 eCommerce Integration
  --                     Interface between SYSS Salsforce system and Oracle Apps
  --
  --------------------------------------------------------------------
  --  ver  date          name              desc
  --  1.0  26/05/2013    yuval tal         Initial Build - CR736 eCommerce Integration IN - Handle Order creation/Query
  --  1.1  16/12/2013    Dalit A. Raviv    add 2 new procedures: create_quote create_sales_order_from_quote
  --                                       correct function get_freight_amount
  --  1.2  12/01/2014    Dalit A. Raviv    CUST776-CR1215 Procedure get_order_type_details add check to SF process
  --  1.3  07/01/2015    Michal Tzvik      CHG0034083? Monitor form for Orders Interface from SF-> OA and Purge process for log
  --                                       1. Add functions / procedures:
  --                                          - purge_order_interface_tables
  --                                          - get_contact_name
  --  1.4  04/02/2015    Dalit A. Raviv    procedure create_order_api CHG0034398.
  --                                       limit err msg to 2000 chars and move it to the failed API part.
  --  1.5  30.3.2015     Yuval Tal         CHG0034734 ? modify create_order : support more fileds line level
  --                                                  - add get_price_list_currency
  --  1.4  19/04/2015    Dalit A. Raviv    CHG0034734 procedure create_order
  --                                       add validation, if line status is not in ('ENTERED', 'AWAITING_SHIPPING', 'BOOKED')
  --                                       do not update the line at oracle.
  --  1.5  06/05/2015    Dalit A. Raviv    CHG0035312 roll back to previous version
  --                                       procedure create_order - set to N -calculation is not done by Oracle,
  --                                       all prices came from outer system that interface to Oracle
  --  2.0  02/05/2018    Diptasurjya       CHG0042734 - STRATAFORCE related changes
  --  2.1  20/09/2018    Lingaraj          CHG0042734- CTASK0037800 - Add Support for service contracts from Contract renewal quote
  --  2.2  19/12/2018    Diptasurjya       CHG0042734 CTASK0039570 - change existing order checking logic
  --  2.3  26.12.18      yuval tal         CHG0042734 - CTASK0039774 validate_order : add sort order
  --  2.4  27/01/2019    Roman W           INC0145320 - Bug Fix at "validate_order"
  --  2.5  31/03/2019    Roman W.          CHG0045447 - xxom_order_interface_pkg.validate_order
  --  2.6  31/03/2019    Roman W.          CHG0045447 - xxom_order_interface_pkg.check_order_exists
  --  2.7  1.4.19        yuval tal         CHG0045447 - create order
  --  2.8  09/06/2019    Roman W.          CHG0045273 - Valditions for Order interface
  --------------------------------------------------------------------

  ---------------------------------------
  -- GLOBALS
  ---------------------------------------
  g_header_table_name VARCHAR2(100) := 'XXOM_SF2OA_HEADER_INTERFACE';
  g_lines_table_name  VARCHAR2(100) := 'XXOM_SF2OA_LINES_INTERFACE';

  g_strataforce_chk_source VARCHAR2(100) := 'STRATAFORCE'; -- CHG0042734

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

  --------------------------------------------------------------------
  --  name:              validate_order
  --  create by:         yuval tal
  --  Revision:          1.0
  --  creation date:     26.5.13
  --------------------------------------------------------------------
  --  purpose :          CUST 675 eCommerce Integration
  --                     Interface between SYSS Salsforce system and Oracle Apps
  --------------------------------------------------------------------
  --  ver  date          name              desc
  --  1.0  26.5.13       yuval tal         Initial Build - CR736 eCommerce Integration IN - Handle Order creation/Query
  --  1.1  18/11/2013    Dalit A. Raviv    take all validation out from create order procedure
  --------------------------------------------------------------------
  PROCEDURE validate_order(p_header_seq  IN NUMBER,
                           p_err_code    OUT VARCHAR2,
                           p_err_message OUT VARCHAR2,
                           --p_org_id        out number
                           p_order_number    OUT NUMBER,
                           p_order_header_id OUT NUMBER,
                           p_order_status    OUT VARCHAR2);
  ---------------------------------
  -- FIX_DATE
  -- SF provide midnight hour with 24 while oracle look for 00
  --------------------------------
  /* FUNCTION fix_date(p_date VARCHAR2) RETURN VARCHAR2 IS
    BEGIN
      RETURN REPLACE(p_date, ' 24:', ' 00:');
  
    END;
  */
  -------------------------------------
  -- check_order_exists
  --
  -- check if  order aleader exists in interface with Status P (in process)
  -- return
  --   order number -  exists
  ---------------------------------------------------------------------------------------------------------------
  --  ver  date          name              desc
  --  ---  ----------    ---------------   ----------------------------------------------------------------------
  --  1.0  --            --                Initial Build
  --  1.1  19/12/2018    Diptasurjya       CHG0042734 CTASK0039570 - change existing order checking logic
  --  1.2  01/04/2019    Roman W.          CHG0045447
  ---------------------------------------------------------------------------------------------------------------
  PROCEDURE check_order_exists(p_orig_sys_document_ref VARCHAR2,
                               p_order_source_id       NUMBER,
                               p_org_id                NUMBER,
                               p_interface_header_id   NUMBER,
                               p_message               OUT VARCHAR2,
                               p_order_number          OUT NUMBER,
                               p_order_header_id       OUT NUMBER,
                               p_order_status          OUT VARCHAR2) IS
  
    CURSOR c IS
      SELECT 'ORDEREXISTS', --'Duplicate Request , Order Already created , see Oracle Order=' ||t.order_number,  -- CTASK0039570
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
         AND intr.status_code = 'P'; -- CTASK0039570 change from !='E' to ='P'
  
    l_line_exists         VARCHAR2(1); -- CTASK0039570
    l_mismatch_line_count NUMBER; -- CTASK0039570
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
    
      -- CTASK0039570 start
      IF p_order_header_id IS NOT NULL THEN
        SELECT COUNT(*)
          INTO l_mismatch_line_count
          FROM ((SELECT xli.external_reference_id,
                        xli.ordered_quantity,
                        -- nvl(inventory_item_id, 0), --  rem by Roman W. 01/04/2019 CHG0045447
                        nvl(xli.inventory_item_id,
                            xxinv_utils_pkg.get_item_id(xli.ordered_item)), --  added by Roman W. 01/04/2019 CHG0045447
                        xli.ordered_item
                   FROM xxom_sf2oa_lines_interface xli
                  WHERE xli.interface_header_id = p_interface_header_id
                 MINUS
                 SELECT ol.orig_sys_line_ref,
                        ol.ordered_quantity,
                        ol.inventory_item_id,
                        ol.ordered_item
                   FROM oe_order_lines_all ol
                  WHERE ol.header_id = p_order_header_id) UNION ALL
                (SELECT ol.orig_sys_line_ref,
                        ol.ordered_quantity,
                        ol.inventory_item_id,
                        ol.ordered_item
                   FROM oe_order_lines_all ol
                  WHERE ol.header_id = p_order_header_id
                 MINUS
                 SELECT xli.external_reference_id,
                        xli.ordered_quantity,
                        -- nvl(inventory_item_id, 0), -- rem by Roman W. 01/04/2019 CHG0045447
                        nvl(xli.inventory_item_id,
                            xxinv_utils_pkg.get_item_id(xli.ordered_item)), --  added by Roman W. 01/04/2019 CHG0045447
                        xli.ordered_item
                   FROM xxom_sf2oa_lines_interface xli
                  WHERE xli.interface_header_id = p_interface_header_id)) aa;
      
        IF l_mismatch_line_count = 0 THEN
          l_line_exists := 'Y';
        ELSE
          l_line_exists := 'N';
          p_message     := 'The SFDC order lines do not match with existing Oracle order. Ensure same lines exist in SFDC to book the order.';
        END IF;
        /*for l_rec in (select *
                        from xxom_sf2oa_lines_interface xli
                       where xli.interface_header_id = p_interface_header_id) loop
          begin
        
            select 'Y'
              into l_line_exists
              from oe_order_lines_all ol
             where ol.orig_sys_line_ref = l_rec.external_reference_id
               and ol.ordered_quantity = l_rec.ordered_quantity
               and (ol.inventory_item_id = l_rec.inventory_item_id or
                   ol.ordered_item = l_rec.ordered_item);
          exception
            when no_data_found then
              l_line_exists := 'N';
              exit;
          end;
        
        end loop;*/
      END IF;
      -- CTASK0039570 end
    END IF;
  
  END;
  --------------------------------------------------------------------
  --  name:              is_valueset_value_valid
  --  create by:         Lingaraj
  --  Revision:          1.0
  --  creation date:     26.09.18
  --------------------------------------------------------------------
  --  purpose :     Check the Value is available in Value Set
  --------------------------------------------------------------------
  --  1.0  26.09.18       Lingaraj    CHG0042734 - CTASK0037800 - Add Support for service contracts from Contract renewal quote
  --------------------------------------------------------------------
  FUNCTION is_valueset_value_valid(p_valueset_name VARCHAR2,
                                   p_value         VARCHAR2) RETURN VARCHAR2 IS
    CURSOR c_valid IS
      SELECT 1
        FROM fnd_flex_values_vl ffvv, fnd_flex_value_sets ffvs
       WHERE ffvv.flex_value_set_id = ffvs.flex_value_set_id
         AND ffvs.flex_value_set_name = p_valueset_name
         AND upper(ffvv.description) = upper(p_value)
         AND nvl(enabled_flag, 'N') = 'Y';
  
    l_valid NUMBER;
  BEGIN
    OPEN c_valid;
    FETCH c_valid
      INTO l_valid;
    CLOSE c_valid;
  
    IF l_valid = 1 THEN
      RETURN 'Y';
    ELSE
      RETURN 'N';
    END IF;
  END is_valueset_value_valid;
  --------------------------------------------------------------------
  --  name:              get_price_list_currency
  --  create by:         yuval tal
  --  Revision:          1.0
  --  creation date:     30.3.15
  --------------------------------------------------------------------
  --  purpose :     CHG0034734 get price list currency
  --------------------------------------------------------------------
  --  1.0  30.3.15       Yuval Tal         CHG0034734 ? used by  create_order :  change logic of calculate_price_flag accoriding to price list curr and order curr
  FUNCTION get_price_list_currency(p_price_list_id NUMBER) RETURN VARCHAR2 IS
    l_curr qp_list_headers_all_b.currency_code%TYPE := NULL;
  BEGIN
  
    SELECT qlh.currency_code
      INTO l_curr
      FROM qp_list_headers_all_b qlh
     WHERE qlh.list_header_id = p_price_list_id;
    RETURN l_curr;
  EXCEPTION
    WHEN no_data_found THEN
      RETURN NULL;
    
  END;
  --------------------------------------------------------------------
  --  name:              get_site_use_id
  --  create by:         yuval tal
  --  Revision:          1.0
  --  creation date:     26.5.13
  --------------------------------------------------------------------
  --  purpose :          CUST 675 eCommerce Integration
  --                     Interface between SYSS Salsforce system and Oracle Apps
  --------------------------------------------------------------------
  --  ver  date          name              desc
  --  1.0  26.5.13       yuval tal         Initial Build -
  --------------------------------------------------------------------

  FUNCTION get_site_use_id(p_org_id            NUMBER,
                           p_cust_acct_site_id NUMBER,
                           p_use_code          VARCHAR2) RETURN NUMBER IS
    l_tmp NUMBER;
  BEGIN
  
    SELECT t.site_use_id
      INTO l_tmp
      FROM ar.hz_cust_site_uses_all t
     WHERE t.cust_acct_site_id = p_cust_acct_site_id
       AND t.site_use_code = p_use_code
       AND t.status = 'A'
       AND t.org_id = p_org_id;
  
    dbms_output.put_line(p_use_code || ' - site use id=' || l_tmp);
  
    RETURN l_tmp;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
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

  --------------------------------------------------------------------
  --  name:            get_order_type_details
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   12/01/2014
  --------------------------------------------------------------------
  --  purpose :        Set order type id and lines type id
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  12/01/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE get_order_type_details(p_interface_header_id IN NUMBER,
                                   errbuf                OUT VARCHAR2,
                                   retcode               OUT NUMBER) IS
  
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
  
    CURSOR poph_c IS
      SELECT *
        FROM xxom_sf2oa_header_interface h
       WHERE h.interface_header_id = p_interface_header_id;
  
    l_count            NUMBER := 0;
    l_order_type_id    NUMBER;
    l_pos_line_type_id NUMBER;
    l_neg_line_type_id NUMBER;
    l_resp_id          NUMBER;
  
  BEGIN
    errbuf  := NULL;
    retcode := 0;
    FOR poph_r IN poph_c LOOP
      -- dbms_output.put_line('11');
      FOR i IN c(poph_r.org_id, poph_r.operation) LOOP
        -- value set
        l_order_type_id    := i.order_type_id;
        l_pos_line_type_id := i.pos_line_type_id;
        l_neg_line_type_id := nvl(i.neg_line_type_id, i.pos_line_type_id);
        l_resp_id          := i.resp_id;
        l_count            := l_count + 1;
      END LOOP;
      IF l_count <> 0 THEN
        UPDATE xxom_sf2oa_header_interface h
           SET h.order_type_id = l_order_type_id,
               h.resp_id       = l_resp_id,
               h.resp_appl_id  = 660
         WHERE h.interface_header_id = p_interface_header_id;
      
        UPDATE xxom_sf2oa_lines_interface l
           SET l.line_type_id = decode(sign(ordered_quantity),
                                       -1,
                                       l_neg_line_type_id,
                                       l_pos_line_type_id)
         WHERE l.interface_header_id = p_interface_header_id;
      
        COMMIT;
      ELSE
        errbuf  := 'Setup for order/line type is missing - value set=XXOM_SF2OA_Order_Types_Mapping , org_id=' ||
                   poph_r.org_id || ', operation=' || poph_r.operation;
        retcode := 1;
      END IF;
    END LOOP;
  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'get_order_type_details failed to get order and line type';
      retcode := 1;
  END get_order_type_details;

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

  ---------------------------------------------------------------------------
  -- get_order_source_id - Fetch order_source_id for given source name
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  -- 1.0      04.27.18  Diptasurjya     CHG0042734 - Initial Build

  -----------------------------------------------------------------------------
  FUNCTION get_order_source_id(p_order_source_name VARCHAR2) RETURN NUMBER IS
    l_order_source_id NUMBER;
  BEGIN
    SELECT order_source_id
      INTO l_order_source_id
      FROM oe_order_sources
     WHERE NAME = p_order_source_name;
  
    RETURN l_order_source_id;
  END get_order_source_id;

  ---------------------------------------------------------------------------
  -- get_change_reason_code - Fetch change reason code for given change reason meaning
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  -- 1.0      04.27.18  Diptasurjya     CHG0042734 - Initial Build

  -----------------------------------------------------------------------------
  FUNCTION get_lookup_code(p_lookup_type         VARCHAR2,
                           p_lookup_meaning_code VARCHAR2) RETURN VARCHAR2 IS
    l_tmp VARCHAR2(30);
  BEGIN
    SELECT lookup_code
      INTO l_tmp
      FROM fnd_lookup_values_vl
     WHERE lookup_type = p_lookup_type
       AND (meaning = p_lookup_meaning_code OR
           lookup_code = p_lookup_meaning_code);
  
    RETURN l_tmp;
  EXCEPTION
    WHEN no_data_found THEN
      RETURN NULL;
  END;

  ---------------------------------------------------------------------------
  -- get_change_reason_code - Fetch change reason code for given change reason meaning
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  -- 1.0      04.27.18  Diptasurjya     CHG0042734 - Initial Build

  -----------------------------------------------------------------------------
  FUNCTION get_change_reason_code(p_change_reason_meaning VARCHAR2)
    RETURN VARCHAR2 IS
    l_change_reason_code VARCHAR2(30);
  BEGIN
    SELECT lookup_code
      INTO l_change_reason_code
      FROM fnd_lookup_values_vl
     WHERE lookup_type = 'CANCEL_CODE'
       AND (meaning = p_change_reason_meaning OR
           lookup_code = p_change_reason_meaning);
  
    RETURN l_change_reason_code;
  EXCEPTION
    WHEN no_data_found THEN
      RETURN NULL;
  END get_change_reason_code;

  ---------------------------------------------------------------------------
  -- get_contact_id
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --     1.0  26.5.13    yuval tal       Initial Build - CR736 eCommerce Integration IN - Handle Order creation/Query

  -----------------------------------------------------------------------------
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

  --------------------------------------------------------------------
  --  name:            create_quote
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   16/12/2013
  --------------------------------------------------------------------
  --  purpose :        create sales order from type quote according to data in tables
  --                   xxom_sf2oa_header_interface, xxom_sf2oa_lines_interface
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  16/12/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE create_quote(p_header_seq      NUMBER,
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
  
    /*CURSOR c_shipping(c_ship_method_code  VARCHAR2,
                    c_organization_code VARCHAR2) IS
    SELECT 'Y'
      FROM wsh_carrier_ship_methods_v tt
     WHERE tt.enabled_flag = 'Y'
       AND tt.ship_method_code = c_ship_method_code
       AND tt.organization_code = c_organization_code;*/
  
    l_header_rec         oe_order_pub.header_rec_type;
    l_line_tbl           oe_order_pub.line_tbl_type;
    l_action_request_tbl oe_order_pub.request_tbl_type;
    l_inx                NUMBER;
    l_my_exception EXCEPTION;
  
    l_user_id NUMBER;
    --
    l_err_code     NUMBER;
    l_err_message  VARCHAR2(500);
    l_line_tbl_out oe_order_pub.line_tbl_type;
  BEGIN
  
    --- set status to in process
    UPDATE xxom_sf2oa_header_interface t
       SET t.status_code = 'P', t.status_message = NULL
     WHERE t.interface_header_id = p_header_seq;
    COMMIT;
  
    p_err_code    := 'S';
    p_err_message := '';
    fnd_message.clear;
  
    -- 13/01/2014 Dalit A. Raviv
    validate_order(p_header_seq      => p_header_seq, -- i n
                   p_err_code        => l_err_code, -- o v
                   p_err_message     => l_err_message, -- o v
                   p_order_number    => p_order_number,
                   p_order_header_id => p_order_header_id,
                   p_order_status    => p_order_status);
    IF l_err_code <> 0 THEN
      p_err_message := l_err_message;
      RAISE l_my_exception;
    END IF;
  
    -------------------------------------------------------------
    ---- prepare  order API
    --------------------------------------------------------------
    FOR i IN c_header LOOP
    
      l_header_rec           := oe_order_pub.g_miss_header_rec;
      l_header_rec.operation := oe_globals.g_opr_create;
      -- set header variables
      l_header_rec.org_id                  := i.org_id; /*l_org_id*/
      l_header_rec.order_type_id           := i.order_type_id;
      l_header_rec.sold_to_org_id          := i.sold_to_org_id;
      l_header_rec.ship_to_org_id          := i.ship_to_org_id;
      l_header_rec.invoice_to_org_id       := i.invoice_to_org_id;
      l_header_rec.pricing_date            := SYSDATE;
      l_header_rec.ship_from_org_id        := i.ship_from_org_id;
      l_header_rec.transactional_curr_code := i.currency_code;
      l_header_rec.flow_status_code        := 'DRAFT'; -- value to create quote is draft instead of 'ENTERED' for SO
      l_header_rec.transaction_phase_code  := 'N'; -- new param for quote
      l_header_rec.cust_po_number          := nvl(i.cust_po, 'No PO');
      l_header_rec.order_source_id         := i.order_source_id;
      l_header_rec.freight_terms_code      := nvl(i.freight_terms_code,
                                                  fnd_api.g_miss_char);
      l_header_rec.shipping_method_code    := nvl(i.shipping_method_code,
                                                  fnd_api.g_miss_char);
      l_header_rec.orig_sys_document_ref   := i.orig_sys_document_ref;
      l_header_rec.ordered_date            := i.ordered_date;
      l_header_rec.ship_to_contact_id      := i.ship_to_contact_id;
      l_header_rec.invoice_to_contact_id   := i.invoice_to_contact_id;
      l_header_rec.shipping_instructions   := i.shipping_comments;
      l_header_rec.payment_term_id         := i.payment_term_id;
      -- dff
      l_header_rec.attribute1  := i.attribute1;
      l_header_rec.attribute2  := i.attribute2;
      l_header_rec.attribute3  := i.attribute3;
      l_header_rec.attribute4  := i.attribute4;
      l_header_rec.attribute5  := i.attribute5;
      l_header_rec.attribute6  := i.attribute6;
      l_header_rec.attribute7  := i.attribute7;
      l_header_rec.attribute8  := i.attribute8;
      l_header_rec.attribute9  := i.attribute9;
      l_header_rec.attribute10 := i.attribute10;
      l_header_rec.attribute11 := i.attribute11;
      l_header_rec.attribute12 := i.attribute12;
      l_header_rec.attribute13 := i.attribute13;
      l_header_rec.attribute14 := i.attribute14;
      l_header_rec.attribute15 := i.attribute15;
    
      -- get user_id from email
      IF i.email IS NOT NULL THEN
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
      END IF;
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
        l_line_tbl(l_inx).shipping_instructions := j.shipping_instructions;
        l_line_tbl(l_inx).packing_instructions := j.packing_instructions;
        l_line_tbl(l_inx).line_type_id := l_line_tbl(l_inx).line_type_id;
        l_line_tbl(l_inx).unit_selling_price := j.unit_selling_price;
        l_line_tbl(l_inx).calculate_price_flag := 'Y'; -- value set to Y when quote is create to be able to calculate price from price list
        l_line_tbl(l_inx).unit_list_price := j.unit_selling_price;
        l_line_tbl(l_inx).attribute12 := fnd_date.date_to_canonical(j.maintenance_start_date);
        l_line_tbl(l_inx).attribute13 := fnd_date.date_to_canonical(j.maintenance_end_date);
        l_line_tbl(l_inx).attribute14 := j.serial_number;
        l_line_tbl(l_inx).source_type_code := j.source_type_code;
        -- set context
        IF l_line_tbl(l_inx).attribute12 IS NOT NULL OR l_line_tbl(l_inx).attribute13 IS NOT NULL OR l_line_tbl(l_inx).attribute14 IS NOT NULL THEN
          l_line_tbl(l_inx).context := get_order_type_name(i.order_type_id);
        END IF;
      
        l_line_tbl(l_inx).order_quantity_uom := nvl(j.uom,
                                                    fnd_api.g_miss_char);
        -- dff
        l_line_tbl(l_inx).attribute1 := j.attribute1;
        l_line_tbl(l_inx).attribute2 := j.attribute2;
        l_line_tbl(l_inx).attribute3 := j.attribute3;
        l_line_tbl(l_inx).attribute4 := j.attribute4;
        l_line_tbl(l_inx).attribute5 := j.attribute5;
        l_line_tbl(l_inx).attribute6 := j.attribute6;
        l_line_tbl(l_inx).attribute7 := j.attribute7;
        l_line_tbl(l_inx).attribute8 := j.attribute8;
        l_line_tbl(l_inx).attribute9 := j.attribute9;
        l_line_tbl(l_inx).attribute10 := j.attribute10;
        l_line_tbl(l_inx).attribute11 := j.attribute11;
        l_line_tbl(l_inx).attribute12 := j.attribute12;
        l_line_tbl(l_inx).attribute13 := j.attribute13;
        l_line_tbl(l_inx).attribute14 := j.attribute14;
        l_line_tbl(l_inx).attribute15 := j.attribute15;
      
      END LOOP;
      dbms_output.put_line('End  validation...Start Api ' ||
                           to_char(SYSDATE, 'hh24:mi:ss'));
      --
      -- create order
      --
      create_order_api(p_org_id             => i.org_id, -- i n
                       p_user_id            => nvl(l_user_id, i.user_id), -- i n
                       p_resp_id            => i.resp_id, -- i n
                       p_appl_id            => i.resp_appl_id, -- i n
                       p_header_rec         => l_header_rec, -- i oe_order_pub.header_rec_type,
                       p_line_tbl           => l_line_tbl, -- i oe_order_pub.line_tbl_type,
                       p_action_request_tbl => l_action_request_tbl, -- i oe_order_pub.request_tbl_type,
                       p_line_tbl_out       => l_line_tbl_out, -- o oe_order_pub.line_tbl_type,
                       p_order_number       => p_order_number, -- o n
                       p_header_id          => p_order_header_id, -- o n
                       p_order_status       => p_order_status, -- o v
                       p_err_code           => p_err_code, -- o v
                       p_err_message        => p_err_message); -- o v
    
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
             t.last_updated_by  = fnd_global.user_id,
             t.order_number     = p_order_number -- 14/01/2014 Dalit A. Raviv
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
  END create_quote;

  --------------------------------------------------------------------
  --  name:            create_sales_order_from_quote
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   16/12/2013
  --------------------------------------------------------------------
  --  purpose :        create sales order from type quote according to data in tables
  --                   xxom_sf2oa_header_interface, xxom_sf2oa_lines_interface
  --
  --                   p_order_header_id (674830) is the draft headr id that created by the api process_order
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  16/12/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE create_sales_order_from_quote(p_order_header_id IN NUMBER,
                                          p_user            IN NUMBER,
                                          p_resp            IN NUMBER,
                                          p_appl            IN NUMBER,
                                          p_err_code        OUT VARCHAR2,
                                          p_err_message     OUT VARCHAR2) IS
  
    l_user          NUMBER := p_user; --1318;  -- USER
    l_resp          NUMBER := p_resp; --21623; -- RESPONSIBLILTY
    l_appl          NUMBER := p_appl; --660;   -- ORDER MANAGEMENT
    l_return_status VARCHAR2(2000);
    l_msg_index     NUMBER;
    l_data          VARCHAR2(2000);
    l_org_id        NUMBER := NULL;
  
  BEGIN
    p_err_code    := 0;
    p_err_message := 'Success';
  
    SELECT org_id
      INTO l_org_id
      FROM oe_order_headers_all ooha
     WHERE ooha.header_id = p_order_header_id;
  
    fnd_global.apps_initialize(l_user, 0, 0);
    fnd_global.apps_initialize(l_user, l_resp, l_appl);
    mo_global.init('ONT');
    mo_global.set_policy_context('S', l_org_id);
  
    oe_negotiate_wf.submit_draft(p_order_header_id, -- i n
                                 l_return_status);
  
    IF l_return_status <> fnd_api.g_ret_sts_success THEN
      FOR i IN 1 .. 1 LOOP
        oe_msg_pub.get(p_msg_index     => i,
                       p_encoded       => fnd_api.g_false,
                       p_data          => l_data,
                       p_msg_index_out => l_msg_index);
        dbms_output.put_line('message is: ' || l_data);
        dbms_output.put_line('message index is: ' || l_msg_index);
        --p_err_message := p_err_message || '|' || l_data;
      END LOOP;
      dbms_output.put_line('Failed to submit draft');
    ELSE
      oe_negotiate_wf.customer_accepted(p_order_header_id, -- i n
                                        l_return_status);
    
      IF l_return_status <> fnd_api.g_ret_sts_success THEN
        FOR i IN 1 .. 1 LOOP
          oe_msg_pub.get(p_msg_index     => i,
                         p_encoded       => fnd_api.g_false,
                         p_data          => l_data,
                         p_msg_index_out => l_msg_index);
          dbms_output.put_line('message is: ' || l_data);
          dbms_output.put_line('message index is: ' || l_msg_index);
        
        --p_err_message := p_err_message || '|' || l_data;
        END LOOP;
        dbms_output.put_line('Failed Customer Accepted');
      ELSE
        COMMIT;
      END IF;
    END IF;
  END create_sales_order_from_quote;

  --------------------------------------------------------------------
  --  name:            create_quote
  --  create by:       yuval tal
  --  Revision:        1.0
  --  creation date:   26.5.2013
  --------------------------------------------------------------------
  --  purpose :        CR736 eCommerce Integration IN - Handle Order creation/Query
  --                   caliing so api
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  26.5.2013   yuval tal         initial build
  --  1.1  12/01/2014  Dalit A. Raviv    add handle of create order in BOOKED status
  --  1.2  03/02/2014  Dalit A. Raviv    add Parameter of Line info from the API (p_line_tbl_out )
  --  1.3  04/02/2015  Dalit A. Raviv    CHG0034398.
  --                                     limit err msg to 2000 chars and move it to the failed API part.
  --------------------------------------------------------------------
  PROCEDURE create_order_api(p_org_id             IN NUMBER,
                             p_user_id            IN NUMBER,
                             p_resp_id            IN NUMBER,
                             p_appl_id            IN NUMBER,
                             p_header_rec         IN oe_order_pub.header_rec_type,
                             p_line_tbl           IN oe_order_pub.line_tbl_type,
                             p_action_request_tbl IN oe_order_pub.request_tbl_type,
                             --   p_line_adj_tbl_type oe_order_pub.line_adj_tbl_type,
                             p_line_tbl_out OUT oe_order_pub.line_tbl_type,
                             p_order_number OUT NUMBER,
                             p_header_id    OUT NUMBER,
                             p_order_status OUT VARCHAR2,
                             p_err_code     OUT VARCHAR2,
                             p_err_message  OUT VARCHAR2) IS
    l_api_version_number NUMBER := 1;
  
    l_return_status VARCHAR2(2000);
    l_msg_count     NUMBER;
    l_msg_data      VARCHAR2(2000);
    -- parameters
    l_debug_level NUMBER := fnd_profile.value('ONT_DEBUG_LEVEL'); -- OM DEBUG LEVEL (MAX 5) fnd_profile.value('ONT_DEBUG_LEVEL')
    l_user        NUMBER := p_user_id; -- 1318;  -- USER
    l_resp        NUMBER := p_resp_id; -- 21623; -- RESPONSIBLILTY
    l_appl        NUMBER := p_appl_id; -- 660;   -- ORDER MANAGEMENT
    -- input variables for process_order api
    -- l_line_tbl                oe_order_pub.line_tbl_type;
    --l_action_request_tbl         oe_order_pub.request_tbl_type;
    --l_header_rec               oe_order_pub.header_rec_type := oe_order_pub.g_miss_header_rec;
    -- out variables for process_order api
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
    l_debug_file                 VARCHAR2(200);
  
  BEGIN
  
    p_err_code := 0;
    -- dbms_application_info.set_client_info(l_org);
  
    -- initialize debug info
    IF (l_debug_level > 0) THEN
      l_debug_file := oe_debug_pub.set_debug_mode('FILE');
      oe_debug_pub.debug_on;
      oe_debug_pub.initialize;
      oe_debug_pub.setdebuglevel(l_debug_level);
      oe_msg_pub.initialize;
    END IF;
    oe_msg_pub.initialize;
    -- initialize environment
    fnd_global.apps_initialize(l_user, 0, 0);
    fnd_global.apps_initialize(l_user, l_resp, l_appl);
    mo_global.init('ONT');
    mo_global.set_policy_context('S', p_org_id);
  
    -- initialize line record
    /* FOR i IN 1 .. p_line_tbl.count LOOP
      l_line_tbl(i) := oe_order_pub.g_miss_line_rec;
      l_line_tbl(i) := p_line_tbl(i);
    END LOOP;*/
  
    -- call to process order api
    dbms_output.put_line('Calling API');
    oe_order_pub.process_order(p_api_version_number => l_api_version_number, --1
                               p_header_rec         => p_header_rec,
                               p_line_tbl           => p_line_tbl,
                               p_action_request_tbl => p_action_request_tbl /*l_action_request_tbl*/,
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
  
    -- 03/02/2014 Dalit A. Raviv
    p_line_tbl_out := l_line_tbl_out;
  
    -- check return status
    IF l_return_status = fnd_api.g_ret_sts_success THEN
      dbms_output.put_line('Return status is success ');
      dbms_output.put_line('debug level ' || l_debug_level);
      p_err_code     := 0;
      p_order_number := l_header_rec_out.order_number;
      p_header_id    := l_header_rec_out.header_id;
    
      -- 13/01/2014 Dalit A. Raviv
      IF p_header_rec.operation = oe_globals.g_opr_delete THEN
        p_order_status := NULL;
      ELSE
        p_order_status := l_header_rec_out.flow_status_code;
      END IF;
    
      COMMIT;
    ELSE
      p_err_code := 1;
      dbms_output.put_line('Return status failure ');
      IF (l_debug_level > 0) THEN
        dbms_output.put_line('failure');
      END IF;
      -- Dalit A. Raviv 04/02/2015 Happy birthday Yuval Raviv 20
      -- display msgs only when API did not Success
      FOR i IN 1 .. l_msg_count LOOP
        oe_msg_pub.get(p_msg_index     => i,
                       p_encoded       => fnd_api.g_false,
                       p_data          => l_data,
                       p_msg_index_out => l_msg_index);
        dbms_output.put_line('message is: ' || l_data);
        dbms_output.put_line('message index is: ' || l_msg_index);
        p_err_message := substr(p_err_message || '|' || l_data, 1, 2000);
      END LOOP;
      p_err_message := substr(ltrim(p_err_message, '|'), 1, 2000);
      ROLLBACK;
    END IF;
  
    -- display return status flags
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
  
    IF (l_debug_level > 0) THEN
      dbms_output.put_line('Debug = ' || oe_debug_pub.g_debug);
      dbms_output.put_line('Debug Level = ' ||
                           to_char(oe_debug_pub.g_debug_level));
      dbms_output.put_line('Debug File = ' || oe_debug_pub.g_dir || '/' ||
                           oe_debug_pub.g_file);
      dbms_output.put_line('---------------------------------------------------');
      oe_debug_pub.debug_off;
    END IF;
  END create_order_api;

  --------------------------------------------------------------------
  --  name:              get_freight_amount
  --  create by:         yuval tal
  --  Revision:          1.0
  --  creation date:     26.5.13
  --------------------------------------------------------------------
  --  purpose :          CUST 675 eCommerce Integration
  --                     Interface between SYSS Salsforce system and Oracle Apps
  --------------------------------------------------------------------
  --  ver  date          name              desc
  --  1.0  26.5.13       yuval tal         Initial Build - CR736 eCommerce Integration IN - Handle Order creation/Query
  --  1.1  18/11/2013    Dalit A. Raviv    function return too_many_rows
  --                                       because there are more then 1 freight row. CR1083
  --------------------------------------------------------------------
  FUNCTION get_freight_amount(p_oe_header_id NUMBER) RETURN NUMBER IS
    l_tmp NUMBER;
  
  BEGIN
    SELECT SUM(nvl(ordered_quantity, 0) * nvl(unit_selling_price, 0))
      INTO l_tmp
      FROM oe_order_lines_all t
     WHERE header_id = p_oe_header_id
       AND nvl(cancelled_flag, 'N') = 'N'
       AND t.ordered_item = 'FREIGHT';
  
    RETURN l_tmp;
  
  END;
  ------------------------------------------------------------------------------------------
  -- Ver    When         Who              Description
  -- -----  -----------  ---------------  --------------------------------------------------
  -- 1.0    31/03/2019   Roman W.         CHG0045447
  ------------------------------------------------------------------------------------------
  PROCEDURE is_order_locked(p_header_seq  IN NUMBER,
                            p_err_code    OUT VARCHAR2,
                            p_err_message OUT VARCHAR2) IS
    ----------------------------------
    --    Local Definition
    ----------------------------------
    CURSOR header_cur IS
      SELECT 'X'
        FROM oe_order_headers_all ooh
       WHERE ooh.header_id IN
             (SELECT xshi.header_id
                FROM xxom_sf2oa_header_interface xshi
               WHERE xshi.interface_header_id = p_header_seq
                 AND xshi.header_id IS NOT NULL)
         FOR UPDATE NOWAIT;
  
    CURSOR lines_cur IS
      SELECT 'X'
        FROM oe_order_lines_all ool
       WHERE ool.line_id IN
             (SELECT xshi.line_id
                FROM xxom_order_lines_interface xshi
               WHERE xshi.interface_header_id = p_header_seq
                 AND xshi.line_id IS NOT NULL)
         FOR UPDATE NOWAIT;
  
    l_value VARCHAR2(30);
    row_locked EXCEPTION;
    PRAGMA EXCEPTION_INIT(row_locked, -54);
  
    ----------------------------------
    --    Code Section
    ----------------------------------
  BEGIN
    SAVEPOINT a;
    p_err_code    := '0';
    p_err_message := NULL;
  
    FOR header_ind IN header_cur LOOP
      NULL;
    END LOOP;
  
    FOR lines_ind IN lines_cur LOOP
      NULL;
    END LOOP;
  
    ROLLBACK TO a;
  EXCEPTION
    WHEN row_locked THEN
      p_err_code    := '2';
      p_err_message := 'Order Is being lock by another user, try later';
      ROLLBACK TO a;
    WHEN OTHERS THEN
      p_err_code    := '2';
      p_err_message := substr('EXCEPTION_OTHERS xxom_order_interface_pkg.is_order_locked(' ||
                              p_header_seq || ') - ' || SQLERRM,
                              1,
                              2000);
      ROLLBACK TO a;
  END is_order_locked;

  --------------------------------------------------------------------
  --  name:              validate_order
  --  create by:         yuval tal
  --  Revision:          1.0
  --  creation date:     26.5.13
  --------------------------------------------------------------------
  --  purpose :          CUST 675 eCommerce Integration
  --                     Interface between SYSS Salsforce system and Oracle Apps
  --------------------------------------------------------------------
  --  ver  date          name              desc
  --  1.0  26.5.13       yuval tal         Initial Build - CR736 eCommerce Integration IN - Handle Order creation/Query
  --  1.1  18/11/2013    Dalit A. Raviv    take all validation out from create order procedure
  --  1.2  1.4.15        yuval tal         CHG0034734 check if header_id is not null when order operation is cancel
  --  1.3  04/27/2018    Diptasurjya       CHG0042734 - STRATAFORCE changes
  --  1.4  20/09/2018    Lingaraj          CHG0042734- CTASK0037800 - Add Support for service contracts from Contract renewal quote
  --  1.5  26.12.18      yuval tal         CTASK0039774 change line_number assign  logic + add sort by new fied sort_order cursor c_lines
  --  1.6  27/01/2019    Roman W           INC0145320 - bug Fix
  --  1.7  01/04/2019    Roman W.          CHG0045447
  --  1.8  10/06/2019    Roman W           CHG0045273 - Valditions for Order interface
  --------------------------------------------------------------------
  PROCEDURE validate_order(p_header_seq  IN NUMBER,
                           p_err_code    OUT VARCHAR2,
                           p_err_message OUT VARCHAR2,
                           
                           p_order_number    OUT NUMBER,
                           p_order_header_id OUT NUMBER,
                           p_order_status    OUT VARCHAR2) IS
  
    CURSOR c_header IS
      SELECT *
        FROM xxom_order_header_interface t
       WHERE t.interface_header_id = p_header_seq;
  
    CURSOR c_lines IS
      SELECT *
        FROM xxom_order_lines_interface t
       WHERE t.interface_header_id = p_header_seq
       ORDER BY sort_order, t.line_number; --yuval CTASK0039774
  
    CURSOR c_shipping(c_ship_method_code  VARCHAR2,
                      c_organization_code VARCHAR2) IS
      SELECT 'Y'
        FROM wsh_carrier_ship_methods_v tt
       WHERE tt.enabled_flag = 'Y'
         AND tt.ship_method_code = c_ship_method_code
         AND tt.organization_code = c_organization_code;
  
    l_my_exception EXCEPTION;
    l_org_id           NUMBER;
    l_tmp              VARCHAR2(500);
    l_line_exists_flag NUMBER := 0;
    l_header_flag      NUMBER := 0;
    l_user_id          NUMBER;
  
    l_h_attribute19_valid VARCHAR2(1000); -- CHG0042734
    l_h_attribute20_valid VARCHAR2(1000); -- CHG0042734
  
    --
    l_err_code     NUMBER;
    l_err_message  VARCHAR2(500);
    l_message      VARCHAR2(500);
    l_max_line_num NUMBER := 0;
  
    l_oracle_contract_number VARCHAR2(300); -- CHG0045273
    l_contract_start_date    varchar2(300); -- CHG0045273
    l_contract_end_date      varchar2(300); -- CHG0045273
  
    l_owner_party_account_id varchar2(300); -- CHG0045273
    l_serial_number          varchar2(300); -- CHG0045273
    l_account_name           varchar2(300); -- CHG0045273
    l_account_number         varchar2(300); -- CHG0045273
  
    l_bill_to_cust_account_id varchar2(300); -- CHG0045273
    l_bill_to_account_number  varchar2(300); -- CHG0045273
    l_bill_to_account_name    varchar2(300); -- CHG0045273
    l_account_relation_count  number;
    l_cust_account_name       varchar2(300); -- CHG0045273
  
  BEGIN
    p_err_code    := 0;
    p_err_message := NULL;
  
    -- Added By Roman W. 31/03/2019 CHG0045447
    is_order_locked(p_header_seq  => p_header_seq,
                    p_err_code    => p_err_code,
                    p_err_message => p_err_message);
  
    -- Added By Roman W. 31/03/2019 CHG0045447
    IF '0' != p_err_code THEN
      RETURN;
    END IF;
  
    --------------- Activate dynamic Checks ----------------------
    FOR i IN c_header LOOP
    
      --CHG0034734 check if header_id is not null when order operation is cancel
      IF i.order_operation = 'CANCEL' AND i.header_id IS NULL THEN
        p_err_message := 'Unable to cancel order. Order does not exists in Oracle.';
        RAISE l_my_exception;
      END IF;
    
      -- check required
      IF i.org_id IS NULL THEN
      
        fnd_message.set_name('XXOBJT', 'XXOM_SF2OA_REQUIRED_HDR_FIELD');
        fnd_message.set_token('FIELD', 'orgId (Operating Unit)');
        p_err_message := fnd_message.get;
        RAISE l_my_exception;
      
      END IF;
    
      -- activate header checks
      -- 0. check environment
      -- 1.  Set global param according to org_id
      -- 1.1.  order_source_id
      -- 1.2.  Order_type_id
      -- 1.3.  User_id
      -- 1.4.  Resplonsibility_id
      -- 1.5.  resp_appl_id
      -- 1.6   organization_code (ship from )
    
      -- CHG0042734 - Comment the dynamic check call. Will make these call directly from this API instead of using the dynamic check setups
      /*xxobjt_interface_check.handle_check(p_group_id     => i.interface_header_id,
      p_table_name   => g_header_table_name,
      p_table_source => i.check_source,
      p_id           => i.interface_header_id,
      p_err_code     => l_err_code,
      p_err_message  => l_err_message);*/
    
      -- CHG0042734 - Introduce direct checks
      -- CHG0042734 - Start Set order type ID
      xxom_order_interface_pkg.get_order_type_details(p_interface_header_id => i.interface_header_id, -- i n
                                                      errbuf                => l_err_message, -- o v
                                                      retcode               => l_err_code); -- o n
    
      IF l_err_code = 1 THEN
        -- CHG0042734 -- Comment below
        /*p_err_message := xxobjt_interface_check.get_err_string(i.interface_header_id,
        g_header_table_name,
        i.interface_header_id);*/
        p_err_message := p_err_message || chr(13) || l_err_message; -- CHG0042734 - Append error message to output variable
        RAISE l_my_exception;
      END IF;
      -- CHG0042734 - End Set order type ID
    
      -- CHG0042734 - Start User ID setting
      BEGIN
        IF i.email IS NOT NULL THEN
          BEGIN
            SELECT fu.user_id
              INTO l_user_id
              FROM fnd_user fu
             WHERE upper(fu.email_address) = upper(i.email)
               AND trunc(SYSDATE) BETWEEN fu.start_date AND
                   nvl(fu.end_date, trunc(SYSDATE) + 1) -- INC0145320
               AND rownum = 1;
          EXCEPTION
            WHEN OTHERS THEN
              --null; -- INC0145320
              l_user_id := NULL; -- INC0145320
          END;
        END IF;
      
        IF l_user_id IS NULL THEN
          BEGIN
            SELECT to_number(ffv.attribute2)
              INTO l_user_id
              FROM fnd_flex_values_vl ffv, fnd_flex_value_sets ffvs
             WHERE ffvs.flex_value_set_name = 'XXSSYS_EVENT_TARGET_NAME'
               AND ffvs.flex_value_set_id = ffv.flex_value_set_id
               AND ffv.flex_value = decode(i.check_source,
                                           'SF',
                                           'SALESFORCE',
                                           i.check_source);
          EXCEPTION
            -- INC0145320
            WHEN no_data_found THEN
              l_user_id := NULL;
          END;
        END IF;
      
        IF l_user_id IS NULL THEN
          p_err_message := p_err_message || chr(13) ||
                           'User ID could not be derived for interface header ID: ' ||
                           i.interface_header_id;
          RAISE l_my_exception;
        END IF;
      
        -- salesperson change CHG0042734 YUVAL
        --
      
        IF upper(i.check_source) = 'STRATAFORCE' AND i.salesrep_id IS NULL THEN
        
          i.salesrep_id := -3;
        
        END IF;
      
        ---
      
        UPDATE xxom_sf2oa_header_interface h
           SET h.user_id = l_user_id,
               /*   h.order_status      = decode(org_id || '-' || operation,
               '103-3',
               NULL,
               order_status),*/ -- CHG0042734 yuval comment out by Adi instruction
               h.order_source_name = decode(h.check_source,
                                            'SF',
                                            'SERVICE SFDC',
                                            order_source_name), -- order source assign by yuval CHG0042734
               salesrep_id         = i.salesrep_id -- CHG0042734 YUVAL
         WHERE h.interface_header_id = i.interface_header_id;
      
        COMMIT;
      EXCEPTION
        WHEN OTHERS THEN
          p_err_message := p_err_message || chr(13) ||
                           'Error while deriving user ID for interface header ID: ' ||
                           i.interface_header_id;
          RAISE l_my_exception;
      END;
      -- CHG0042734 - End User ID setting
    
      FOR j IN c_lines LOOP
        -- activate header checks
        -- 1.  Set global param according to org_id
        -- 1.1.  line_type_id
        xxobjt_interface_check.handle_check(p_group_id     => j.order_line_seq,
                                            p_table_name   => g_lines_table_name,
                                            p_table_source => i.check_source,
                                            p_id           => j.order_line_seq,
                                            p_err_code     => l_err_code,
                                            p_err_message  => l_err_message);
      
        COMMIT;
        IF l_err_code = 1 THEN
          p_err_message := xxobjt_interface_check.get_err_string(j.order_line_seq,
                                                                 g_lines_table_name,
                                                                 j.order_line_seq);
          RAISE l_my_exception;
        END IF;
      END LOOP;
    END LOOP;
  
    --------------- set id's and validation checks --------------------------
    FOR i IN c_header LOOP
      l_header_flag := 1;
      -- check required
      IF i.orig_sys_document_ref IS NULL THEN
      
        fnd_message.set_name('XXOBJT', 'XXOM_SF2OA_REQUIRED_HDR_FIELD');
        fnd_message.set_token('FIELD', 'orig_sys_document_ref');
        p_err_message := fnd_message.get;
        RAISE l_my_exception;
      
      END IF;
    
      -- CHG0042734 - Start - dipta
      IF i.order_source_name IS NULL AND i.order_source_id IS NULL THEN
        p_err_message := 'Order Source name or ID must be provided';
        RAISE l_my_exception;
      END IF;
    
      IF i.order_source_name IS NOT NULL AND i.order_source_id IS NULL THEN
        BEGIN
          i.order_source_id := get_order_source_id(i.order_source_name);
        EXCEPTION
          WHEN no_data_found THEN
            p_err_message := 'Order Source name - ' || i.order_source_name ||
                             ' is not valid';
            RAISE l_my_exception;
        END;
      END IF;
    
      -- Validate Ack email DFF
      IF i.attribute19 IS NOT NULL THEN
        l_h_attribute19_valid := xxobjt_general_utils_pkg.get_invalid_mail_list(i.attribute19,
                                                                                '|');
      
        IF l_h_attribute19_valid IS NOT NULL THEN
          p_err_message := 'Ack mail field (ATTRIBUTE19) contains illegal email addresses: ' ||
                           l_h_attribute19_valid;
          RAISE l_my_exception;
        END IF;
      END IF;
    
      -- Validate Ship email DFF
      IF i.attribute20 IS NOT NULL THEN
        l_h_attribute20_valid := xxobjt_general_utils_pkg.get_invalid_mail_list(i.attribute20,
                                                                                '|');
      
        IF l_h_attribute20_valid IS NOT NULL THEN
          p_err_message := 'Ship mail field (ATTRIBUTE20) contains illegal email addresses: ' ||
                           l_h_attribute20_valid;
          RAISE l_my_exception;
        END IF;
      END IF;
    
      -- Cancellation reason validation
      IF i.change_reason_meaning IS NOT NULL THEN
        i.change_reason_code := get_change_reason_code(i.change_reason_meaning);
      
        IF i.change_reason_code IS NULL THEN
          p_err_message := 'Change reason is not valid';
          RAISE l_my_exception;
        END IF;
      ELSE
        i.change_reason_code := 'Not provided';
      END IF;
    
      -- CHG0042734 - End - Dipta
    
      -- check required
      IF i.order_source_id IS NULL THEN
      
        fnd_message.set_name('XXOBJT', 'XXOM_SF2OA_REQUIRED_HDR_FIELD');
        fnd_message.set_token('FIELD', 'order_source_id');
        p_err_message := fnd_message.get;
        RAISE l_my_exception;
      
      END IF;
    
      -- check order exists (for new order  header_id is null ) avoid create duplicate orders
      IF i.header_id IS NULL THEN
        check_order_exists(i.orig_sys_document_ref,
                           i.order_source_id,
                           i.org_id,
                           i.interface_header_id,
                           l_message,
                           p_order_number,
                           p_order_header_id,
                           p_order_status);
      
        IF l_message IS NOT NULL THEN
          p_err_message := l_message;
          --  RETURN;  --
          RAISE l_my_exception;
        END IF;
      END IF;
      -- check required
    
      -- get user_id from email
      IF i.email IS NOT NULL THEN
        BEGIN
          SELECT user_id
            INTO l_user_id
            FROM fnd_user u
           WHERE upper(u.email_address) = upper(i.email)
             AND rownum = 1;
        
        EXCEPTION
          WHEN OTHERS THEN
            NULL;
        END;
      END IF;
    
      IF nvl(l_user_id, i.user_id) IS NULL THEN
        fnd_message.set_name('XXOBJT', 'XXOM_SF2OA_REQUIRED_HDR_FIELD');
        fnd_message.set_token('FIELD', 'userId');
        p_err_message := fnd_message.get;
        RAISE l_my_exception;
      END IF;
    
      -- order Date
      IF i.ordered_date IS NULL THEN
        fnd_message.set_name('XXOBJT', 'XXOM_SF2OA_REQUIRED_HDR_FIELD');
        fnd_message.set_token('FIELD', 'Ordered_Date');
        p_err_message := fnd_message.get;
        RAISE l_my_exception;
      END IF;
    
      -- organization_code (ship from inv org)
      -- Dalit A. Raviv 03/02/2014
      IF i.organization_code IS NULL AND i.ship_from_org_id IS NULL THEN
        fnd_message.set_name('XXOBJT', 'XXOM_SF2OA_REQUIRED_HDR_FIELD');
        fnd_message.set_token('FIELD',
                              'Organization_Code/Ship_from_org_id');
        p_err_message := fnd_message.get;
        RAISE l_my_exception;
      END IF;
    
      -- Shipping_Site_Num
      -- Dalit A. Raviv 03/02/2014
      IF i.shipping_site_num IS NULL AND i.ship_to_org_id IS NULL AND
         i.ship_to_site_id IS NULL THEN
        fnd_message.set_name('XXOBJT', 'XXOM_SF2OA_REQUIRED_HDR_FIELD');
        fnd_message.set_token('FIELD',
                              'Shipping_Site_Num/Ship_to_org_id/Ship_to_site_id');
        p_err_message := fnd_message.get;
        RAISE l_my_exception;
      END IF;
    
      --   Account_Number
      --  Yuval Tal 03/02/2014
      IF i.cust_account_number IS NULL AND i.sold_to_org_id IS NULL THEN
        fnd_message.set_name('XXOBJT', 'XXOM_SF2OA_REQUIRED_HDR_FIELD');
        fnd_message.set_token('FIELD', 'Account_Number/Sold_to_org_id');
        p_err_message := fnd_message.get;
        RAISE l_my_exception;
      END IF;
    
      -- Invoice_Site_Num
      -- Dalit A. Raviv 03/02/2014
      IF i.invoice_site_num IS NULL AND i.invoice_to_org_id IS NULL AND
         i.invoice_to_site_id IS NULL THEN
        fnd_message.set_name('XXOBJT', 'XXOM_SF2OA_REQUIRED_HDR_FIELD');
        fnd_message.set_token('FIELD',
                              'Invoice_Site_Num/Invoice_to_org_id');
        p_err_message := fnd_message.get;
        RAISE l_my_exception;
      END IF;
    
      -- find oracle ID's
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
      l_org_id := i.org_id; -- yuval 3.2.14
    
      -- init environment befor selects from hz_party tables
      fnd_global.apps_initialize(i.user_id, 0, 0);
      fnd_global.apps_initialize(i.user_id, i.resp_id, i.resp_appl_id);
      mo_global.init('ONT');
      mo_global.set_policy_context('S', l_org_id);
    
      -- sold_to_org_id
      IF i.sold_to_org_id IS NULL THEN
        i.sold_to_org_id := get_sold_to_org_id(i.cust_account_number,
                                               l_org_id /*NULL*/); -- 18/11/2013 Dalit A. Raviv l_org_id
        /* IF i.sold_to_org_id IS NULL THEN
          fnd_message.set_name('XXOBJT', 'XXOM_SF2OA_INVALID_VALUE');
          fnd_message.set_token('FIELD', 'Account_Number');
          p_err_message := fnd_message.get;
          RAISE l_my_exception;
        END IF;
        
        -- check account-org id match
        i.sold_to_org_id := get_sold_to_org_id(i.cust_account_number,
                                               l_org_id);*/
        IF i.sold_to_org_id IS NULL THEN
          fnd_message.set_name('XXOBJT', 'XXOM_SF2OA_INVALID_RELATION');
          fnd_message.set_token('FIELD1',
                                'Account_Number ' || i.cust_account_number);
          fnd_message.set_token('FIELD2',
                                'Organization_Code ' || i.organization_code);
          p_err_message := fnd_message.get;
          RAISE l_my_exception;
        END IF;
      END IF;
    
      IF i.invoice_to_org_id IS NULL THEN
        IF i.invoice_to_site_id IS NOT NULL THEN
          i.invoice_to_org_id := get_site_use_id(l_org_id,
                                                 i.invoice_to_site_id,
                                                 'BILL_TO');
          IF i.invoice_to_org_id IS NULL THEN
            fnd_message.set_name('XXOBJT', 'XXOM_SF2OA_INVALID_VALUE');
            fnd_message.set_token('FIELD', 'Bill to Site');
            p_err_message := fnd_message.get;
            RAISE l_my_exception;
          END IF;
        ELSE
          i.invoice_to_org_id := get_ship_invoice_org_id(i.cust_account_number,
                                                         i.invoice_site_num,
                                                         'BILL_TO',
                                                         l_org_id /*NULL*/); -- 18/11/2013 Dalit A. Raviv l_org_id
        
        END IF;
      END IF;
    
      IF i.ship_to_org_id IS NULL THEN
        IF i.ship_to_site_id IS NOT NULL THEN
          i.ship_to_org_id := get_site_use_id(l_org_id,
                                              i.ship_to_site_id,
                                              'SHIP_TO');
          IF i.ship_to_org_id IS NULL THEN
            fnd_message.set_name('XXOBJT', 'XXOM_SF2OA_INVALID_VALUE');
            fnd_message.set_token('FIELD', 'Ship to Site');
            p_err_message := fnd_message.get;
            RAISE l_my_exception;
          END IF;
        ELSE
          i.ship_to_org_id := get_ship_invoice_org_id(i.cust_account_number,
                                                      i.shipping_site_num,
                                                      'SHIP_TO',
                                                      l_org_id); -- 18/11/2013 Dalit A. Raviv l_org_id  get_ship_invoice_org_id get_sold_to_org_id
        END IF;
      END IF;
    
      -- ship to contact id
      -- Dalit A. Raviv 03/02/2014
      IF i.ship_to_contact_id IS NULL THEN
        -- ship/invoice to_org_id
        IF i.ship_to_contact_num IS NOT NULL AND
           i.ship_to_contact_id IS NULL THEN
          i.ship_to_contact_id := get_contact_id(i.ship_to_contact_num,
                                                 NULL);
        END IF;
      END IF;
    
      --- invoice to contact
      -- Dalit A. Raviv 03/02/2014
      /*i.invoice_to_contact_id := get_contact_id(i.invoice_to_contact_num,null);
      if i.invoice_to_contact_num is not null and i.invoice_to_contact_id is null then
        fnd_message.set_name('xxobjt', 'xxom_sf2oa_invalid_value');
        fnd_message.set_token('field', 'invoice_to_contact_num');
        p_err_message := fnd_message.get;
        raise l_my_exception;
      end if;
      */
      IF i.invoice_to_contact_id IS NULL AND
         i.invoice_to_contact_num IS NULL THEN
        NULL;
      ELSIF i.invoice_to_contact_id IS NULL AND
            i.invoice_to_contact_num IS NOT NULL THEN
        i.invoice_to_contact_id := get_contact_id(i.invoice_to_contact_num,
                                                  NULL);
      END IF;
      ----------------------------
      -- check lookup existance
      -----------------------------
      -- ship method code
      IF i.shipping_method_code IS NOT NULL THEN
        l_tmp := xxinv_utils_pkg.get_lookup_meaning(p_lookup_type => 'SHIP_METHOD',
                                                    p_lookup_code => i.shipping_method_code);
      
        IF l_tmp IS NULL THEN
          -- yuval add translation for startaforce
          BEGIN
            SELECT wcsv.ship_method_code
              INTO i.shipping_method_code
            
              FROM wsh_carrier_services_v     wcsv,
                   wsh_org_carrier_services_v wocsv
             WHERE wcsv.carrier_service_id = wocsv.carrier_service_id
               AND wcsv.enabled_flag = 'Y'
               AND wocsv.enabled_flag = 'Y'
               AND wcsv.ship_method_meaning = i.shipping_method_code
               AND wocsv.organization_code = i.organization_code;
          
          EXCEPTION
          
            WHEN OTHERS THEN
            
              fnd_message.set_name('XXOBJT', 'XXOM_SF2OA_INVALID_VALUE');
              fnd_message.set_token('FIELD',
                                    'Shipping_Method_Code/Organization_Code ' ||
                                    i.shipping_method_code || '/' ||
                                    i.organization_code);
              p_err_message := fnd_message.get;
              RAISE l_my_exception;
          END;
        
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
             t.user_id               = nvl(l_user_id, t.user_id),
             --  t.org_id                = l_org_id,
             t.last_update_date     = SYSDATE,
             t.last_updated_by      = fnd_global.user_id,
             t.change_reason_code   = i.change_reason_code, -- CHG0042734 - Dipta
             t.order_source_id      = i.order_source_id, -- CHG0042734 - Dipta
             t.shipping_method_code = i.shipping_method_code -- CHG0042734 - yuval
       WHERE t.interface_header_id = p_header_seq;
    
      COMMIT;
    
      --------------------------------------------------
      -------------- lines validation ------------------
      --------------------------------------------------
      -- yuval set inital line number CHG0042734
      IF i.header_id IS NOT NULL THEN
      
        SELECT MAX(line_number)
          INTO l_max_line_num
          FROM oe_order_lines_all l
         WHERE header_id = i.header_id;
      
      END IF;
    
      FOR j IN c_lines LOOP
        l_line_exists_flag := 1;
        -- check required
        -- return_reason_code
      
        -- line_number
      
        IF j.line_id IS NULL AND j.line_number IS NULL THEN
          -- CTASK0039774
          l_max_line_num := l_max_line_num + 1;
          j.line_number  := l_max_line_num; --c_lines%ROWCOUNT + l_max_line_num;
        
          --  fnd_message.set_name('XXOBJT', 'XXOM_SF2OA_REQUIRED_LINE_FIELD');
          --   fnd_message.set_token('FIELD', 'Order_Line_number/Line Id');
          --  fnd_message.set_token('LINE_NO', c_lines%ROWCOUNT);
          --   p_err_message := fnd_message.get;
          --   RAISE l_my_exception;
        END IF;
        -- yuval get code by meaning
        IF j.ordered_quantity < 0 AND j.return_reason_code IS NULL THEN
          fnd_message.set_name('XXOBJT', 'XXOM_SF2OA_REQUIRED_LINE_FIELD');
          fnd_message.set_token('FIELD', 'Return_reason_Code');
          fnd_message.set_token('LINE_NO', j.line_number);
          p_err_message := fnd_message.get;
          RAISE l_my_exception;
        ELSIF j.ordered_quantity < 0 AND j.return_reason_code IS NOT NULL THEN
        
          -- check return reason code
        
          j.return_reason_code := get_lookup_code('CREDIT_MEMO_REASON',
                                                  j.return_reason_code);
        
          IF j.return_reason_code IS NULL THEN
            fnd_message.set_name('XXOBJT',
                                 'XXOM_SF2OA_REQUIRED_LINE_FIELD');
            fnd_message.set_token('FIELD', 'Return_reason_Code');
            fnd_message.set_token('LINE_NO',
                                  j.line_number || '/' ||
                                  j.external_reference_id);
            p_err_message := fnd_message.get;
            RAISE l_my_exception;
          END IF;
        
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
      
        -- CHG0042734 - Validate Unit List price for STRATAFORCE
        IF j.unit_list_price IS NULL AND
           i.check_source = g_strataforce_chk_source THEN
          p_err_message := 'Unit List Price must be provided for line number ' ||
                           j.line_number;
          RAISE l_my_exception;
        END IF;
        -- CHG0042734 - End
      
        -- CHG0042734 - Cancellation reason validation
        IF j.change_reason_meaning IS NOT NULL THEN
          j.change_reason_code := get_change_reason_code(j.change_reason_meaning);
        
          IF j.change_reason_code IS NULL THEN
            p_err_message := 'Change reason is not valid for line ' ||
                             j.line_number;
            RAISE l_my_exception;
          END IF;
        ELSE
          j.change_reason_code := 'Not provided';
        END IF;
        -- CHG0042734 - End
      
        -- ship from org
        -- Dalit A. Raviv 03/02/2014
        IF j.ship_from_org_id IS NULL THEN
          IF j.organization_code IS NOT NULL THEN
            BEGIN
              SELECT t.organization_id ship_from_org_id
                INTO j.ship_from_org_id
                FROM xxobjt_org_organization_def_v t
               WHERE t.organization_code = j.organization_code;
            EXCEPTION
              WHEN OTHERS THEN
                fnd_message.set_name('XXOBJT', 'XXOM_SF2OA_INVALID_VALUE');
                fnd_message.set_token('FIELD',
                                      'Organization_Code (Line Level)/Ship_from_org_id');
                p_err_message := fnd_message.get;
                RAISE l_my_exception;
            END;
          END IF;
        END IF;
      
        -- inventory_item_id
        -- Dalit A. Raviv 03/02/2014
        IF j.inventory_item_id IS NULL THEN
          BEGIN
            SELECT msib.inventory_item_id
              INTO j.inventory_item_id
              FROM mtl_system_items_b msib
             WHERE msib.segment1 = j.ordered_item
               AND msib.organization_id = 91;
          EXCEPTION
            WHEN no_data_found THEN
              -- Cant find item id for order item &ITEM (line=&LINE_NO)
              fnd_message.set_name('XXOBJT',
                                   'XXOM_SF2OA_REQUIRED_ITEM_FIELD');
              fnd_message.set_token('ITEM', j.ordered_item);
              fnd_message.set_token('LINE_NO', j.line_number);
              p_err_message := fnd_message.get;
              RAISE l_my_exception;
          END;
        END IF;
      
        --CHG0042734-CTASK0037800 -Add Support for service contracts from Contract renewal quote
        --Begin
        -- Add logic in "IF" CHG0045273
        IF j.inventory_item_id IS NOT NULL AND i.operation = 3 AND
           is_valueset_value_valid('XXOM_SF2OA_ORDER_SOURCE_NAME',
                                   i.order_source_name) = 'Y' AND
           is_valueset_value_valid('XXOM_SF2OA_ITEM_CATEGORY_VALUE',
                                   (xxssys_oa2sf_util_pkg.get_category_value('Activity Analysis',
                                                                             j.inventory_item_id))) = 'Y' THEN
          BEGIN
            SELECT decode(msib.coverage_schedule_id, NULL, 'N', 'Y')
              INTO j.is_service_contract_item
              FROM mtl_system_items_b msib
             WHERE msib.inventory_item_id = j.inventory_item_id
               AND msib.organization_id = 91;
          EXCEPTION
            WHEN no_data_found THEN
              j.is_service_contract_item := 'N';
          END;
          IF j.is_service_contract_item = 'Y' THEN
            IF j.service_start_date IS NULL OR j.service_end_date IS NULL THEN
              -- For Service Contract Item Service Start Date and End date is Required
              fnd_message.set_name('XXOBJT',
                                   'XXOM_SF2OA_REQUIRED_SRV_FIELD');
              fnd_message.set_token('ITEM', j.ordered_item);
              fnd_message.set_token('LINE_NO', j.line_number);
              p_err_message := fnd_message.get;
              RAISE l_my_exception;
            END IF;
          
            -------------------------------------------------
            -- CHG0045273 (a)
            -------------------------------------------------
          
            -- Get Serial number for messages.
            IF j.serial_number IS NOT NULL THEN
              BEGIN
                SELECT ass.serialnumber
                  INTO l_serial_number
                  FROM xxsf2_asset ass
                 WHERE ass.external_key__c = j.serial_number;
              
              EXCEPTION
                WHEN NO_DATA_FOUND THEN
                  BEGIN
                    SELECT cii.serial_number
                      INTO l_serial_number
                      FROM csi_item_instances cii
                     WHERE cii.instance_number = j.serial_number;
                  EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                      p_err_message := 'No serial number found for asset external key: ' ||
                                       j.serial_number ||
                                       '. Please open a ticket for further assistance.';
                      RAISE l_my_exception;
                    WHEN OTHERS THEN
                      p_err_message := 'Error while getting Oracle serial number for asset external key: ' ||
                                       j.serial_number ||
                                       '. Please open a ticket for further assistance.';
                      RAISE l_my_exception;
                  END;
                WHEN OTHERS THEN
                  p_err_message := 'Error while getting serial number for asset external key: ' ||
                                   j.serial_number ||
                                   '. Please open a ticket for further assistance.';
                  RAISE l_my_exception;
              END;
            END IF;
            begin
              select con.oa_contract_number__c oracle_contract_number,
                     to_char(con.startdate, 'DD-MON-YYYY'),
                     to_char(con.enddate, 'DD-MON-YYYY')
                into l_oracle_contract_number,
                     l_contract_start_date,
                     l_contract_end_date
                from xxsf2_servicecontract con, xxsf2_asset ass
               where con.asset__c = ass.id
                 and ass.external_key__c = j.serial_number --external_reference_id --[asset.external_key - instance id of the serial number]
                 and ((trunc(j.service_start_date) between con.startdate and
                     con.enddate) or (trunc(j.service_end_date) between
                     con.startdate and con.enddate))
                 and con.oracle_contract_status__c in ('Active', 'Signed');
              ----------------------------------------------------------------------------
              --  required add error message setting
              --  Error message: �There is already active/signed service contract (con.Oracle_Contract_number) for SN : con.serial_number between con.start_date and con.end_date. Please choose different dates�
              -----------------------------------------------------------------------------
              /*p_err_message := 'There is already active/signed service contract ('||l_oracle_contract_number||') for SN : '
              ||j.serial_number||' between '||l_contract_start_date||' and '||l_contract_end_date
              ||'. Please choose different dates.';*/
              fnd_message.set_name('XXOBJT',
                                   'XXOM_SF2OA_SERVICE_CON_DATES');
              fnd_message.set_token('ORA_CONTRACT_NUM',
                                    l_oracle_contract_number);
              fnd_message.set_token('SERIAL_NO', l_serial_number);
              fnd_message.set_token('CONTRACT_START_DATE',
                                    l_contract_start_date);
              fnd_message.set_token('CONTRACT_END_DATE',
                                    l_contract_end_date);
              p_err_message := fnd_message.get;
              RAISE l_my_exception;
            exception
              when l_my_exception then
                RAISE l_my_exception;
              when no_data_found then
                null; -- nothing to do, validation complited success
              when too_many_rows then
                ----------------------------------------------------------------------------
                --  required add error message setting
                --  Error message: �There is already active/signed service contract (con.Oracle_Contract_number) for SN : con.serial_number between con.start_date and con.end_date. Please choose different dates�
                -----------------------------------------------------------------------------
                p_err_message := 'There are more than one active/signed service contract (' ||
                                 l_oracle_contract_number || ') for SN : ' ||
                                 l_serial_number || ' between ' ||
                                 l_contract_start_date || ' and ' ||
                                 l_contract_end_date ||
                                 '. Please choose different dates.';
                RAISE l_my_exception;
              when others then
                ----------------------------------------------------------------------------
                --  required add error message setting
                --  Error message: �There is already active/signed service contract (con.Oracle_Contract_number) for SN : con.serial_number between con.start_date and con.end_date. Please choose different dates�
                -----------------------------------------------------------------------------
                p_err_message := 'Error while validating service contract dates for SN : ' ||
                                 l_serial_number || ' between dates' ||
                                 l_contract_start_date || ' and ' ||
                                 l_contract_end_date ||
                                 '. Please open a ticket for further assistance.' ||
                                 SQLERRM;
                RAISE l_my_exception;
            end;
          
            -------------------------------------------------
            -- CHG0045273 - (b)
            -------------------------------------------------
            begin
              SELECT cii.owner_party_account_id,
                     hca.account_name,
                     hca.account_number
                INTO l_owner_party_account_id,
                     l_account_name,
                     l_account_number
                FROM csi_item_instances cii, HZ_CUST_ACCOUNTS hca
               WHERE cii.instance_id = j.serial_number --[asset.external_key - INSTANCE ID OF THE serial NUMBER that interface in the order line]
                 AND cii.owner_party_account_id = hca.cust_account_id
                 AND hca.status = 'A';
            
              if i.sold_to_org_id != l_owner_party_account_id then
                -- Error Message: �The account owner of SN:[cii.serial_number] in Oracle is hca.account_name||�(AC# �||hca.account_number ||�)� and not the same as StrataForce. Please navigate to salesforce asset, validate it and sync it information to Oracle, then try again to book the order.�
                /*p_err_message := 'The account owner of SN:['||l_serial_number||'] in Oracle is '||l_account_number|| '(AC# '
                ||l_account_number||') and not the same as StrataForce. Please navigate to salesforce '
                ||'asset, validate it and sync it information to Oracle, then try again to book the order.';*/
                fnd_message.set_name('XXOBJT',
                                     'XXOM_SF2OA_CHK_ASSET_OWNERSHIP');
                fnd_message.set_token('ACC_NUMBER', l_account_number); 
                fnd_message.set_token('ACC_NAME', l_account_name);                
                fnd_message.set_token('SERIAL_NO', l_serial_number);
                p_err_message := fnd_message.get;
                RAISE l_my_exception;
              end if;
            exception   
              when l_my_exception then
                RAISE l_my_exception;            
              when no_data_found then
                -- Err Message
                p_err_message := 'No data found while trying to check asset ownership for service contract order';
                RAISE l_my_exception;
              when others then
                -- Err Message
                p_err_message := 'Error ocurred while trying to check asset ownership for service contract order';
                RAISE l_my_exception;
            end;
          END IF;
        
        ELSE
          j.is_service_contract_item := 'N';
        END IF;
        -------------------------------------------------------------------
        -- CHG0045273 (c)
        -------------------------------------------------------------------
        begin
          select hcasa.cust_account_id,
                 hca.account_number,
                 hca.account_name
            into l_bill_to_cust_account_id,
                 l_bill_to_account_number,
                 l_bill_to_account_name
            from hz_cust_site_uses_all  bill_to,
                 hz_cust_acct_sites_all hcasa,
                 hz_cust_accounts       hca
           where hcasa.cust_acct_site_id = bill_to.cust_acct_site_id
             AND hcasa.cust_account_id = hca.cust_account_id
             AND bill_to.site_use_id = i.invoice_to_org_id
             AND bill_to.site_use_code = 'BILL_TO'
             AND bill_to.status = 'A';
        
          select count(*)
            into l_account_relation_count
            from hz_cust_acct_relate_all cust_rel,
                 hz_cust_accounts        source_acc,
                 hz_cust_accounts        dest_acc,
                 hz_parties              pa
           where cust_rel.related_cust_account_id =
                 dest_acc.cust_account_id
             and cust_rel.cust_account_id = source_acc.cust_account_id
             and source_acc.party_id = pa.party_id
             AND cust_rel.bill_to_flag = 'Y'
             AND cust_rel.status = 'A'
             AND dest_acc.account_number = i.cust_account_number
             and cust_rel.org_id = i.org_id
             AND source_acc.cust_account_id = l_bill_to_cust_account_id;
        
          if 0 = l_account_relation_count AND
             l_bill_to_account_number != i.cust_account_number then
            -- 1) query cust_account_name by <i.cust_account_number>
            -- 2)
            -- Error Message: �You tried to use locations from < cust_account_name > ||�(AC#�|| <i.cust_account_number ||�)�
            -- and end customer/third party  || <l_bill_to_account_name> ||�(AC# �||<l_bill_to_account_number> ||�)�
            -- that has no relationship between them.
            /*p_err_message := 'You tried to use locations from account '||l_bill_to_account_name|| ' (AC#'
            ||i.cust_account_number||') and end customer/third party '||l_bill_to_account_name
            ||' (AC#'||l_bill_to_account_number||') that has no relationship between them.'
            ||'Please create account relationship between them or use different locations.'; */
            select hp.PARTY_NAME
              into l_cust_account_name
              from hz_cust_accounts hca, hz_parties hp
             where hca.account_number = i.cust_account_number
               and hp.party_id = hca.party_id;
          
            fnd_message.set_name('XXOBJT',
                                 'XXOM_SF2OA_CHK_ACC_RELATIONSHP');
            fnd_message.set_token('ACC_NAME', l_cust_account_name);
            fnd_message.set_token('ACC_NUMBER', i.cust_account_number);
            fnd_message.set_token('BILL_TO_ACC_NAME',
                                  l_bill_to_account_name);
            fnd_message.set_token('BILL_TO_ACC_NUM',
                                  l_bill_to_account_number);
            p_err_message := fnd_message.get;
            RAISE l_my_exception;
          elsif 1 < l_account_relation_count then
            NULL; -- no message to be raised
          end if;
        
        exception  
          when l_my_exception then
            RAISE l_my_exception;        
          when no_data_found then
            p_err_message := 'No data found while trying to check account relationship between account and end customer';
            RAISE l_my_exception;
          when too_many_rows then
            -- Set Error message
            p_err_message := 'More than 1 records found while trying to check account relationship between account and end customer';
            RAISE l_my_exception;
          when others then
            -- Set Error message
            p_err_message := 'Error ocurred while trying to check account relationship between account and end customer';
            RAISE l_my_exception;
        end;
        -------------------------------------------------------------------------
      
        --End #CHG0042734-CTASK0037800
        -- save calc fields
        UPDATE xxom_sf2oa_lines_interface l
           SET l.inventory_item_id        = j.inventory_item_id,
               l.ship_from_org_id         = j.ship_from_org_id,
               l.change_reason_code       = j.change_reason_code, -- CHG0042734 - Dipta
               l.line_number              = j.line_number, --CHG0042734  yuval
               l.return_reason_code       = j.return_reason_code, -- CHG0042734  yuval
               l.is_service_contract_item = j.is_service_contract_item --#CHG0042734-CTASK0037800 Lingaraj
         WHERE l.interface_header_id = j.interface_header_id
           AND l.order_line_seq = j.order_line_seq;
        COMMIT;
      END LOOP;
    
    -- check lines exists
    /* IF nvl(l_line_exists_flag, 0) = 0 THEN
                                                                                                                          p_err_message := 'No lines Found for Order'; --fnd_message.get;
                                                                                                                          RAISE l_my_exception;
                                                                                                                          END IF;
                                                                                                                    */
    END LOOP;
  
    -- check header exists
    IF l_header_flag = 0 THEN
      p_err_message := 'No Header Found for p_header_seq=' || p_header_seq; --fnd_message.get;
      RAISE l_my_exception;
    END IF;
  
  EXCEPTION
    WHEN l_my_exception THEN
      p_err_code := 1;
    WHEN OTHERS THEN
      p_err_code    := 1;
      p_err_message := 'Problem to pass Validation - ' ||
                       substr(SQLERRM, 1, 240);
  END;

  --------------------------------------------------------------------
  --  name:              create_order
  --  create by:         yuval tal
  --  Revision:          1.0
  --  creation date:     26.5.13
  --------------------------------------------------------------------
  --  purpose :          CUST 675 eCommerce Integration
  --                     Interface between SYSS Salsforce system and Oracle Apps
  --------------------------------------------------------------------
  --  ver  date          name              desc
  --  1.0  26.5.13       yuval tal         create sales order according to data in tables xxom_sf2oa_header_interface, xxom_sf2oa_lines_interface
  --  1.1  18/11/2013    Dalit A. Raviv    send org_id to function get_ship_invoice_org_id, get_sold_to_org_id instead of null CR1083
  --  1.2  13/01/2014    Dalit A. Raviv    1) Handle create order in BOOKED status.
  --                                       2) Handle case of Create/Update/Delete/Cancel of Order/Line
  --                                       order_status :ENTERED/BOOKED
  --                                       Header Operation :UPDATE/DELETE/CANCEL/null =CREATE
  --                                       Line Operation :  UPDATE/DELETE/CANCEL/null =CREATE
  --  1.3  30.3.15       Yuval Tal         CHG0034734 ? modify create_order : support more fileds at line level
  --                                       Ship_set, user_item_description, return_attribute1..15, return_context
  --                                       change logic of calculate_price_flag accoriding to price list curr and order curr
  --  1.4  19/04/2015    Dalit A. Raviv    CHG0034734 add validation, if line status is not in ('ENTERED', 'AWAITING_SHIPPING', 'BOOKED')
  --                                       do not update the line at oracle, skip the line.
  --  1.5  06/05/2015    Dalit A. Raviv    CHG0035312 roll back to previous version
  --                                       procedure create_order - set to N -calculation is not done by Oracle,
  --                                       all prices came from outer system that interface to Oracle
  --  1.6  04/27/2018    Diptasurjya       CHG0042734 - STRATAFORCE changes
  --  1.7  20/09/2018    Lingaraj          CHG0042734- CTASK0037800 - Add Support for service contracts from Contract renewal quote
  --  1.8  19/12/2018    Diptasurjya       CHG0042734 CTASK0039570 - change existing order checking logic
  -- 1.9   1.4.19        yuval tal         CHG0045447 - create order - raise my exception  if not  p_err_message = 'ORDEREXISTS'
  -------------------------------------------------------------------------------------------------------------------
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
  
    l_header_rec oe_order_pub.header_rec_type;
    l_line_tbl   oe_order_pub.line_tbl_type;
    --l_line_rec             oe_order_pub.line_rec_type;
    l_action_request_tbl oe_order_pub.request_tbl_type;
    l_inx                NUMBER;
    l_my_exception EXCEPTION;
  
    l_user_id  NUMBER;
    l_err_code NUMBER;
    --l_err_message  VARCHAR2(500);
    l_line_tbl_out oe_order_pub.line_tbl_type;
  
    -- CHG0034734 19/04/2015 Dalit A. Raviv
    l_flow_status_code oe_order_lines_all.flow_status_code%TYPE;
  
  BEGIN
  
    --- set status to in process
    UPDATE xxom_sf2oa_header_interface t
       SET t.status_code = 'P', t.status_message = NULL
     WHERE t.interface_header_id = p_header_seq;
    COMMIT;
  
    p_err_code    := 'S';
    p_err_message := '';
    fnd_message.clear;
  
    -- 13/01/2014 Dalit A. Raviv
    validate_order(p_header_seq      => p_header_seq, -- i n
                   p_err_code        => l_err_code, -- o v
                   p_err_message     => p_err_message, -- o v
                   p_order_number    => p_order_number,
                   p_order_header_id => p_order_header_id,
                   p_order_status    => p_order_status);
  
    IF p_order_number IS NOT NULL THEN
    
      IF p_err_message = 'ORDEREXISTS' THEN
        -- CTASK0039570 added to check condition where order header and lines exist
        UPDATE xxom_sf2oa_header_interface t
           SET t.header_id        = p_order_header_id,
               t.status_code      = 'S',
               t.status_message   = NULL, --substr(p_err_message, 1, 2000),  -- CTASK0039570 set message as blank so as to mimic successful first time creation of order
               t.last_update_date = SYSDATE,
               t.last_updated_by  = fnd_global.user_id
         WHERE t.interface_header_id = p_header_seq;
      
        UPDATE xxom_sf2oa_lines_interface t
           SET t.line_number =
               (SELECT line_number
                  FROM oe_order_lines_all l
                 WHERE l.header_id = p_order_header_id
                   AND l.orig_sys_line_ref = t.external_reference_id),
               t.line_id    =
               (SELECT line_id
                  FROM oe_order_lines_all l
                 WHERE l.header_id = p_order_header_id
                   AND l.orig_sys_line_ref = t.external_reference_id) -- CTASK0039570 added
         WHERE t.interface_header_id = p_header_seq;
      ELSE
        --  comment  CHG0045447
        -- CTASK0039570 added to check for condition where order exists but lines mismatch
        /* UPDATE xxom_sf2oa_header_interface t
        SET    t.header_id        = p_order_header_id,
               t.status_code      = 'E',
               t.status_message   = substr(p_err_message, 1, 2000),
               t.last_update_date = SYSDATE,
               t.last_updated_by  = fnd_global.user_id
        WHERE  t.interface_header_id = p_header_seq;*/
      
        RAISE l_my_exception; --  CHG0045447
      
      END IF;
    
      COMMIT;
      RETURN;
    
    ELSIF p_err_message IS NOT NULL THEN
      RAISE l_my_exception;
    END IF;
    /*IF l_err_code <> 0 THEN
      p_err_message := l_err_message;
      RAISE l_my_exception;
    END IF;*/
    -------------------------------------------------------------
    ---- prepare  order API
    --------------------------------------------------------------
    FOR i IN c_header LOOP
      -- 12/01/2014 Dalit A. Raviv - handle create order in BOOKED status.
      -- populate required attributes
      -- initialize action request record
      IF i.order_status = 'BOOKED' THEN
        IF i.payment_term_id IS NULL THEN
          fnd_message.set_name('XXOBJT', 'XXOM_SF2OA_PAYMENT_TERM_ISNULL'); -- Payment Term is required on a booked order line.
          p_err_message := fnd_message.get;
          RAISE l_my_exception;
        ELSE
          dbms_output.put_line('oe_globals.g_book_order = ' ||
                               oe_globals.g_book_order);
          l_action_request_tbl(1) := oe_order_pub.g_miss_request_rec;
          l_action_request_tbl(1).request_type := oe_globals.g_book_order; -- 'BOOK_ORDER'
          l_action_request_tbl(1).entity_code := oe_globals.g_entity_header;
        END IF;
      END IF;
      -- end 12/01/2014
    
      l_header_rec := oe_order_pub.g_miss_header_rec;
      -- l_header_rec.flow_status_code        := 'ENTERED';
      -- 13/01/2014 Dalit A. Raviv  Handle case of Create / Update / Cancel / Delete
      -- Case of update/cancel/delete
      IF i.header_id IS NOT NULL THEN
        l_header_rec.header_id := i.header_id;
        IF i.order_operation = 'CANCEL' THEN
          l_header_rec.operation      := oe_globals.g_opr_update;
          l_header_rec.cancelled_flag := 'Y';
          -- l_header_rec.change_reason  := 'Not provided';  -- CHG0042734 Commented
          l_header_rec.change_reason   := i.change_reason_code; -- CHG0042734
          l_header_rec.change_comments := i.change_comments; -- CHG0042734
        ELSIF i.order_operation = 'DELETE' THEN
          l_header_rec.operation := oe_globals.g_opr_delete;
          -- case of update
        ELSE
          l_header_rec.operation     := oe_globals.g_opr_update;
          l_header_rec.change_reason := 'Not provided';
        END IF;
        -- case of create
      ELSE
        l_header_rec.operation := oe_globals.g_opr_create;
        --l_header_rec.flow_status_code        := 'ENTERED';
      END IF;
    
      -- Handle Quate case
      IF i.order_operation = 'DRAFT' THEN
        l_header_rec.flow_status_code       := 'DRAFT'; -- value to create quote is draft instead of 'ENTERED' for SO
        l_header_rec.transaction_phase_code := 'N'; -- new param for quote
      END IF;
    
      -- set header variables
    
      -- dff
      l_header_rec.attribute1  := i.attribute1;
      l_header_rec.attribute2  := i.attribute2;
      l_header_rec.attribute3  := i.attribute3;
      l_header_rec.attribute4  := i.attribute4;
      l_header_rec.attribute5  := i.attribute5;
      l_header_rec.attribute6  := i.attribute6;
      l_header_rec.attribute7  := i.attribute7;
      l_header_rec.attribute8  := i.attribute8;
      l_header_rec.attribute9  := i.attribute9;
      l_header_rec.attribute10 := i.attribute10;
      l_header_rec.attribute11 := i.attribute11;
      l_header_rec.attribute12 := i.attribute12;
      l_header_rec.attribute13 := i.attribute13;
      l_header_rec.attribute14 := i.attribute14;
      l_header_rec.attribute15 := i.attribute15;
    
      l_header_rec.attribute19 := i.attribute19; -- CHG0042734
      l_header_rec.attribute20 := i.attribute20; -- CHG0042734
    
      l_header_rec.org_id            := i.org_id; /*l_org_id*/
      l_header_rec.order_type_id     := i.order_type_id;
      l_header_rec.sold_to_org_id    := i.sold_to_org_id;
      l_header_rec.ship_to_org_id    := i.ship_to_org_id;
      l_header_rec.invoice_to_org_id := i.invoice_to_org_id;
      /*  l_header_rec.invoice_to_org_id := get_site_use_id(i.org_id,
                                                        i.invoice_to_org_id,
                                                        'BILL_TO');
      
      l_header_rec.ship_to_org_id := get_site_use_id(i.org_id,
                                                     i.ship_to_org_id,
                                                     'SHIP_TO');*/
      l_header_rec.pricing_date            := SYSDATE;
      l_header_rec.ship_from_org_id        := i.ship_from_org_id;
      l_header_rec.transactional_curr_code := i.currency_code;
      l_header_rec.cust_po_number          := nvl(i.cust_po, 'No PO');
      l_header_rec.order_source_id         := i.order_source_id;
      l_header_rec.freight_terms_code      := nvl(i.freight_terms_code,
                                                  fnd_api.g_miss_char);
      l_header_rec.shipping_method_code    := nvl(i.shipping_method_code,
                                                  fnd_api.g_miss_char);
      l_header_rec.orig_sys_document_ref   := i.orig_sys_document_ref;
      l_header_rec.ordered_date            := i.ordered_date;
      l_header_rec.ship_to_contact_id      := i.ship_to_contact_id;
      l_header_rec.invoice_to_contact_id   := i.invoice_to_contact_id;
      l_header_rec.shipping_instructions   := i.shipping_comments;
      l_header_rec.packing_instructions    := i.packing_instructions;
      l_header_rec.payment_term_id         := i.payment_term_id;
    
      -- 14/01/2014 Dalit A. Raviv add new feilds
      l_header_rec.salesrep_id   := i.salesrep_id;
      l_header_rec.price_list_id := i.price_list_id;
      -- context
      BEGIN
        SELECT con.descriptive_flex_context_code
          INTO l_header_rec.context
          FROM fnd_descr_flex_contexts_vl con, fnd_application_vl fav
         WHERE con.descriptive_flex_context_code =
               get_order_type_name(i.order_type_id)
           AND fav.application_id = con.application_id
           AND con.enabled_flag = 'Y'
           AND fav.application_name = 'Order Management'
           AND con.descriptive_flexfield_name = 'OE_HEADER_ATTRIBUTES';
      EXCEPTION
        WHEN OTHERS THEN
          NULL;
      END;
    
      -- 13/01/2014 Dalit A. Raviv when delete the order no need to delete the line too.
      IF nvl(i.order_operation, 'DAR') NOT IN ('DELETE', 'CANCEL') THEN
        l_inx := 0;
        FOR j IN c_lines LOOP
          -- CHG0034734 19/04/2015 Dalit A. Raviv
          IF j.line_id IS NOT NULL THEN
            BEGIN
              -- CHG0035312 change logic for the continue
              SELECT oola.flow_status_code
                INTO l_flow_status_code
                FROM fnd_flex_values_vl  ffv,
                     fnd_flex_value_sets ffvs,
                     oe_order_lines_all  oola
               WHERE ffv.flex_value_set_id = ffvs.flex_value_set_id
                 AND ffvs.flex_value_set_name =
                     'XXOM_ORD_INTER_PROCESS_LINE_STATUS'
                 AND oola.flow_status_code = ffv.flex_value
                 AND ffv.enabled_flag = 'Y'
                 AND SYSDATE BETWEEN
                     nvl(ffv.start_date_active, SYSDATE - 1) AND
                     nvl(ffv.end_date_active, SYSDATE + 1)
                 AND oola.header_id = i.header_id
                 AND oola.line_id = j.line_id;
            
            EXCEPTION
              WHEN OTHERS THEN
                l_flow_status_code := NULL;
                CONTINUE;
            END;
            -- end CHG0035312
          END IF;
          -- because of the continue the api see empty record (c_lines%ROWCOUNT)
          -- with this change there will not be empty record
          l_inx := l_inx + 1; --c_lines%ROWCOUNT;
          -- end CHG0034734
          -- set lines variables
          l_line_tbl(l_inx) := oe_order_pub.g_miss_line_rec;
        
          -- dff
          l_line_tbl(l_inx).attribute1 := j.attribute1;
          l_line_tbl(l_inx).attribute2 := j.attribute2;
          l_line_tbl(l_inx).attribute3 := j.attribute3;
          l_line_tbl(l_inx).attribute4 := j.attribute4;
          l_line_tbl(l_inx).attribute5 := j.attribute5;
          l_line_tbl(l_inx).attribute6 := j.attribute6;
          l_line_tbl(l_inx).attribute7 := j.attribute7;
          l_line_tbl(l_inx).attribute8 := j.attribute8;
          l_line_tbl(l_inx).attribute9 := j.attribute9;
          l_line_tbl(l_inx).attribute10 := j.attribute10;
          l_line_tbl(l_inx).attribute11 := j.attribute11;
          l_line_tbl(l_inx).attribute12 := j.attribute12;
          l_line_tbl(l_inx).attribute13 := j.attribute13;
          l_line_tbl(l_inx).attribute14 := j.attribute14;
          l_line_tbl(l_inx).attribute15 := j.attribute15;
        
          l_line_tbl(l_inx).orig_sys_line_ref := j.external_reference_id; -- CHG0042734 - CTASK0039570
        
          -- 13/01/2014 Dalit A. Raviv  Handle case of create or update
          -- Case of update/cancel/delete
          IF j.line_id IS NOT NULL THEN
          
            l_line_tbl(l_inx).header_id := i.header_id;
            l_line_tbl(l_inx).line_id := j.line_id;
            IF j.line_operation = 'CANCEL' THEN
              l_line_tbl(l_inx).operation := oe_globals.g_opr_update;
              --l_line_tbl(l_inx).change_reason := 'Not provided';-- CHG0042734 Commented
              l_line_tbl(l_inx).change_reason := j.change_reason_code; -- CHG0042734
              l_line_tbl(l_inx).change_comments := j.change_comments; -- CHG0042734
              l_line_tbl(l_inx).cancelled_flag := 'Y';
              l_line_tbl(l_inx).ordered_quantity := 0;
              CONTINUE;
              -- object version number
            ELSIF j.line_operation = 'DELETE' THEN
              l_line_tbl(l_inx).operation := oe_globals.g_opr_delete;
              -- case of update
            ELSE
              l_line_tbl(l_inx).operation := oe_globals.g_opr_update;
              l_line_tbl(l_inx).change_reason := 'Not provided';
              l_line_tbl(l_inx).ordered_quantity := j.ordered_quantity;
              -- object version number
            END IF;
            -- case of create
          ELSE
            l_line_tbl(l_inx).operation := oe_globals.g_opr_create;
            l_line_tbl(l_inx).ordered_quantity := j.ordered_quantity;
          END IF;
        
          -- Handle Quate case
          IF j.line_operation = 'DRAFT' THEN
            l_line_tbl(l_inx).calculate_price_flag := 'Y'; -- value set to Y when quote is create and calculate price from price list
          ELSE
            -- CHG0035312 roll back to previous version
            -- set to N -calculation is not done by Oracle, all prices came from outer system that interface to Oracle
            l_line_tbl(l_inx).calculate_price_flag := 'N';
            -- CHG0034734  -- Yuval Tal change to Y incase price list currency not equal header currency
            /*IF i.currency_code != nvl(get_price_list_currency(i.price_list_id), i.currency_code) THEN
              l_line_tbl(l_inx).calculate_price_flag := 'Y';
            ELSE
              l_line_tbl(l_inx).calculate_price_flag := 'N';
            END IF;*/
          END IF;
          -- CHG0034734
          -- CHG0034734 19/04/2015 Dalit A. Raviv
          IF i.operation = 8 AND
             xxoe_utils_pkg.is_item_service_contract(j.inventory_item_id) = 'Y' THEN
            -- Handle return attribute1
            BEGIN
              SELECT ra.customer_trx_id
                INTO j.return_attribute1
                FROM ra_customer_trx_all ra
               WHERE ra.trx_number = j.return_attribute1
                 AND ra.org_id = i.org_id
                 AND rownum = 1;
            EXCEPTION
              WHEN OTHERS THEN
                --fnd_message.set_name('XXOBJT', 'XXOM_SF2OA_PAYMENT_TERM_ISNULL'); -- Payment Term is required on a booked order line.
                p_err_message := 'Invoice number does not exists in oracle ' ||
                                 j.return_attribute1;
                RAISE l_my_exception;
            END;
            -- Handle return attribute2
            BEGIN
              SELECT rl.customer_trx_line_id
                INTO j.return_attribute2
                FROM ra_customer_trx_lines_all rl
               WHERE rl.customer_trx_id = j.return_attribute1
                 AND rl.line_number = j.return_attribute2
                 AND rl.line_type = 'LINE'
                 AND rownum = 1;
            EXCEPTION
              WHEN OTHERS THEN
                p_err_message := 'Invoice line number does not exists in oracle ' ||
                                 j.return_attribute2;
                RAISE l_my_exception;
            END;
            l_line_tbl(l_inx).return_attribute1 := j.return_attribute1;
            l_line_tbl(l_inx).return_attribute2 := j.return_attribute2;
          ELSE
            l_line_tbl(l_inx).return_attribute1 := nvl(j.return_attribute1,
                                                       fnd_api.g_miss_char);
            l_line_tbl(l_inx).return_attribute2 := nvl(j.return_attribute2,
                                                       fnd_api.g_miss_char);
          END IF;
          l_line_tbl(l_inx).return_context := nvl(j.return_context,
                                                  fnd_api.g_miss_char);
          -- end CHG0034734
          l_line_tbl(l_inx).user_item_description := nvl(j.user_item_description,
                                                         fnd_api.g_miss_char);
          l_line_tbl(l_inx).ship_set := nvl(j.ship_set, fnd_api.g_miss_char);
        
          l_line_tbl(l_inx).return_attribute3 := nvl(j.return_attribute3,
                                                     fnd_api.g_miss_char);
          l_line_tbl(l_inx).return_attribute4 := nvl(j.return_attribute4,
                                                     fnd_api.g_miss_char);
          l_line_tbl(l_inx).return_attribute5 := nvl(j.return_attribute5,
                                                     fnd_api.g_miss_char);
          l_line_tbl(l_inx).return_attribute6 := nvl(j.return_attribute6,
                                                     fnd_api.g_miss_char);
          l_line_tbl(l_inx).return_attribute7 := nvl(j.return_attribute7,
                                                     fnd_api.g_miss_char);
          l_line_tbl(l_inx).return_attribute8 := nvl(j.return_attribute8,
                                                     fnd_api.g_miss_char);
          l_line_tbl(l_inx).return_attribute9 := nvl(j.return_attribute9,
                                                     fnd_api.g_miss_char);
          l_line_tbl(l_inx).return_attribute10 := nvl(j.return_attribute10,
                                                      fnd_api.g_miss_char);
          l_line_tbl(l_inx).return_attribute11 := nvl(j.return_attribute11,
                                                      fnd_api.g_miss_char);
          l_line_tbl(l_inx).return_attribute12 := nvl(j.return_attribute12,
                                                      fnd_api.g_miss_char);
          l_line_tbl(l_inx).return_attribute13 := nvl(j.return_attribute13,
                                                      fnd_api.g_miss_char);
          l_line_tbl(l_inx).return_attribute14 := nvl(j.return_attribute14,
                                                      fnd_api.g_miss_char);
          l_line_tbl(l_inx).return_attribute15 := nvl(j.return_attribute15,
                                                      fnd_api.g_miss_char);
          -- end CHG0034734
        
          -- CHG0034734 yuval exclude line number in case line id populated
          IF l_line_tbl(l_inx).line_id IS NULL THEN
            l_line_tbl(l_inx).line_number := j.line_number;
          END IF;
        
          l_line_tbl(l_inx).inventory_item_id := j.inventory_item_id;
          l_line_tbl(l_inx).ship_to_org_id := l_header_rec.ship_to_org_id; --i.ship_to_org_id;
          l_line_tbl(l_inx).return_reason_code := nvl(j.return_reason_code,
                                                      fnd_api.g_miss_char);
          l_line_tbl(l_inx).ship_from_org_id := j.ship_from_org_id;
          l_line_tbl(l_inx).shipping_instructions := j.shipping_instructions;
          l_line_tbl(l_inx).packing_instructions := j.packing_instructions;
          l_line_tbl(l_inx).line_type_id := l_line_tbl(l_inx).line_type_id;
          l_line_tbl(l_inx).unit_selling_price := j.unit_selling_price;
          l_line_tbl(l_inx).unit_list_price := j.unit_selling_price;
        
          -- CHG0042734 - Start - Dipta
          IF i.check_source = g_strataforce_chk_source THEN
            l_line_tbl(l_inx).unit_list_price := j.unit_list_price;
          END IF;
          -- CHG0042734 - End - Dipta
        
          l_line_tbl(l_inx).order_quantity_uom := nvl(j.uom,
                                                      fnd_api.g_miss_char);
          l_line_tbl(l_inx).attribute12 := fnd_date.date_to_canonical(j.maintenance_start_date);
          l_line_tbl(l_inx).attribute13 := fnd_date.date_to_canonical(j.maintenance_end_date);
          l_line_tbl(l_inx).attribute14 := j.serial_number;
          l_line_tbl(l_inx).source_type_code := nvl(j.source_type_code,
                                                    fnd_api.g_miss_char);
          -- 14/01/2014 Dalit A. Raviv add new feilds
          l_line_tbl(l_inx).reference_header_id := j.reference_header_id;
          l_line_tbl(l_inx).reference_line_id := j.reference_line_id;
          l_line_tbl(l_inx).accounting_rule_id := j.accounting_rule_id;
          l_line_tbl(l_inx).service_start_date := nvl(j.service_start_date,
                                                      fnd_api.g_miss_date);
          l_line_tbl(l_inx).service_end_date := nvl(j.service_end_date,
                                                    fnd_api.g_miss_date);
          --
          l_line_tbl(l_inx).subinventory := j.subinventory;
          -- set context
          /* IF l_line_tbl(l_inx).attribute12 IS NOT NULL OR l_line_tbl(l_inx)
             .attribute13 IS NOT NULL OR l_line_tbl(l_inx).attribute14 IS NOT NULL THEN
            l_line_tbl(l_inx).context := get_order_type_name(i.order_type_id);
          END IF;*/
        
          -- Start CHG0042734 - CTASK0037800 - Service Contract Item
          IF nvl(j.is_service_contract_item, 'N') = 'Y' THEN
            l_line_tbl(l_inx).service_reference_type_code := 'CUSTOMER_PRODUCT';
            l_line_tbl(l_inx).item_type_code := 'SERVICE';
            l_line_tbl(l_inx).accounting_rule_id := 1000;
            l_line_tbl(l_inx).service_reference_line_id := j.serial_number;
            -- INC0145450 start
          ELSE
            l_line_tbl(l_inx).accounting_rule_id := 1;
            -- INC0145450 end
          END IF;
          -- End CHG0042734 - CTASK0037800 - Service Contract Item
        
          -- context -- yuval 3.2.14
          BEGIN
            SELECT con.descriptive_flex_context_code
              INTO l_line_tbl(l_inx).context
              FROM fnd_descr_flex_contexts_vl con, fnd_application_vl fav
             WHERE con.descriptive_flex_context_code =
                   get_order_type_name(i.order_type_id)
               AND con.enabled_flag = 'Y'
               AND fav.application_id = con.application_id
               AND fav.application_name = 'Order Management'
               AND con.descriptive_flexfield_name = 'OE_LINE_ATTRIBUTES';
          EXCEPTION
            WHEN OTHERS THEN
              NULL;
          END;
        END LOOP;
      END IF; -- operator = Delete
      dbms_output.put_line('End  validation...Start Api ' ||
                           to_char(SYSDATE, 'hh24:mi:ss'));
    
      --
      -- create order
      --
      create_order_api(p_org_id             => i.org_id, -- i n
                       p_user_id            => nvl(l_user_id, i.user_id), -- i n
                       p_resp_id            => i.resp_id, -- i n
                       p_appl_id            => i.resp_appl_id, -- i n
                       p_header_rec         => l_header_rec, -- i oe_order_pub.header_rec_type,
                       p_line_tbl           => l_line_tbl, -- i oe_order_pub.line_tbl_type,
                       p_action_request_tbl => l_action_request_tbl, -- i oe_order_pub.request_tbl_type,
                       p_line_tbl_out       => l_line_tbl_out, -- o oe_order_pub.line_tbl_type,
                       p_order_number       => p_order_number, -- o n
                       p_header_id          => p_order_header_id, -- o n
                       p_order_status       => p_order_status, -- o v
                       p_err_code           => p_err_code, -- o v
                       p_err_message        => p_err_message); -- o v
    
      -- update result
      dbms_output.put_line('End  Api...' || to_char(SYSDATE, 'hh24:mi:ss'));
      p_err_message := REPLACE(p_err_message,
                               'This Customer' || '''' ||
                               's PO Number is referenced by another order');
    
      UPDATE xxom_sf2oa_header_interface t
         SET t.header_id        = nvl(p_order_header_id, t.header_id),
             t.status_code      = decode(p_err_code,
                                         '0',
                                         'S',
                                         '1',
                                         'E',
                                         status_code),
             t.status_message   = substr(p_err_message, 1, 2000),
             t.last_update_date = SYSDATE,
             t.last_updated_by  = fnd_global.user_id,
             t.order_number     = p_order_number -- 14/01/2014 Dalit A. Raviv
       WHERE t.interface_header_id = p_header_seq
      RETURNING status_code INTO p_err_code;
      COMMIT;
    
      IF p_err_code = 'S' AND p_order_status = 'BOOKED' THEN
        p_err_message := NULL;
      END IF;
    
      IF p_err_code = 'S' THEN
        FOR i IN 1 .. l_line_tbl_out.count LOOP
          /*l_line_tbl_out.first*/
          UPDATE xxom_sf2oa_lines_interface t
             SET t.line_id          = l_line_tbl_out(i).line_id,
                 t.last_update_date = SYSDATE,
                 t.last_updated_by  = fnd_global.user_id
           WHERE t.interface_header_id = p_header_seq
             AND t.line_number = l_line_tbl_out(i).line_number;
        
          COMMIT;
        
        --DBMS_OUTPUT.put_line('return_status '||l_line_tbl_out(i).return_status);
        --DBMS_OUTPUT.put_line('line_id '||l_line_tbl_out(i).line_id);
        --DBMS_OUTPUT.put_line('flow_status_code '||l_line_tbl_out(i).flow_status_code);
        --DBMS_OUTPUT.put_line('status_flag '||l_line_tbl_out(i).status_flag);
        END LOOP;
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
    WHEN OTHERS THEN
      -- Added By Roman W. 07/04/2019 CHG0045447
    
      p_err_code    := 'E';
      p_err_message := substr(SQLERRM, 1, 2000);
    
      UPDATE xxom_sf2oa_header_interface t
         SET t.status_code = 'E', t.status_message = p_err_message
       WHERE t.interface_header_id = p_header_seq;
    
      COMMIT;
    
  END create_order;

  --------------------------------------------------------------------
  --  name:              create_order_old
  --  create by:         yuval tal
  --  Revision:          1.0
  --  creation date:     26.5.13
  --------------------------------------------------------------------
  --  purpose :          CUST 675 eCommerce Integration
  --                     Interface between SYSS Salsforce system and Oracle Apps
  --------------------------------------------------------------------
  --  ver  date          name              desc
  --  1.0  26.5.13       yuval tal         create sales order according to data in tables xxom_sf2oa_header_interface, xxom_sf2oa_lines_interface
  --  1.1  18/11/2013    Dalit A. Raviv    send org_id to function get_ship_invoice_org_id, get_sold_to_org_id instead of null CR1083
  --------------------------------------------------------------------
  /*PROCEDURE create_order_old(p_header_seq      number,
                               p_err_code        out varchar2,
                               p_err_message     out varchar2,
                               p_order_number    out number,
                               p_order_header_id out number,
                               p_order_status    out varchar2) is
  
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
  
      l_header_rec         oe_order_pub.header_rec_type;
      l_line_tbl           oe_order_pub.line_tbl_type;
      l_action_request_tbl oe_order_pub.request_tbl_type;
      l_inx                NUMBER;
      l_my_exception EXCEPTION;
      l_org_id NUMBER;
  
      l_user_id NUMBER;
      --  l_resp_id      NUMBER;
      --  l_resp_appl_id NUMBER;
      --
      --l_order_source_id  NUMBER;
      --  l_pos_line_type_id NUMBER;
      -- l_neg_line_type_id NUMBER;
      l_tmp              VARCHAR2(500);
      l_line_exists_flag NUMBER := 0;
      l_header_flag      NUMBER := 0;
      --
      l_err_code    NUMBER;
      l_err_message VARCHAR2(500);
    BEGIN
  
      --- set status to in process
      UPDATE xxom_sf2oa_header_interface t
         SET t.status_code = 'P', t.status_message = NULL
       WHERE t.interface_header_id = p_header_seq;
      COMMIT;
  
      p_err_code    := 'S';
      p_err_message := '';
      fnd_message.clear;
  
      --------------- Activate dynamic Checks ----------------------
  
      FOR i IN c_header LOOP
        -- activate header checks
  
        -- 0. check environment
  
        -- 1.  Set global param according to org_id
        -- 1.1.  order_source_id
        -- 1.2.  Order_type_id
        -- 1.3.  User_id
        -- 1.4.  Resplonsibility_id
        -- 1.5.  resp_appl_id
        -- 1.6   organization_code (ship from )
  
        xxobjt_interface_check.handle_check(p_group_id     => i.interface_header_id,
                                            p_table_name   => g_header_table_name,
                                            p_table_source => i.check_source,
                                            p_id           => i.interface_header_id,
                                            p_err_code     => l_err_code,
                                            p_err_message  => l_err_message);
  
        IF l_err_code = 1 THEN
          p_err_message := xxobjt_interface_check.get_err_string(i.interface_header_id,
                                                                 g_header_table_name,
                                                                 i.interface_header_id);
          RAISE l_my_exception;
        END IF;
  
        FOR j IN c_lines LOOP
          -- activate header checks
          -- 1.  Set global param according to org_id
          -- 1.1.  line_type_id
  
          xxobjt_interface_check.handle_check(p_group_id     => j.order_line_seq,
                                              p_table_name   => g_lines_table_name,
                                              p_table_source => i.check_source,
                                              p_id           => j.order_line_seq,
                                              p_err_code     => l_err_code,
                                              p_err_message  => l_err_message);
  
          COMMIT;
          IF l_err_code = 1 THEN
            p_err_message := xxobjt_interface_check.get_err_string(j.order_line_seq,
                                                                   g_lines_table_name,
                                                                   j.order_line_seq);
            RAISE l_my_exception;
          END IF;
  
        END LOOP;
      END LOOP;
  
      --------------- set id's and validation checks --------------------------
  
      FOR i IN c_header LOOP
  
        l_header_flag := 1;
  
        -- check required
        -- order Date
        IF i.ordered_date IS NULL THEN
          fnd_message.set_name('XXOBJT', 'XXOM_SF2OA_REQUIRED_HDR_FIELD');
          fnd_message.set_token('FIELD', 'Ordered_Date');
          p_err_message := fnd_message.get;
          RAISE l_my_exception;
        END IF;
        -- organization_code (ship from inv org)
        IF i.organization_code IS NULL THEN
          fnd_message.set_name('XXOBJT', 'XXOM_SF2OA_REQUIRED_HDR_FIELD');
          fnd_message.set_token('FIELD', 'Organization_Code');
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
        -- Invoice_Site_Num
  
        IF i.invoice_site_num IS NULL THEN
          fnd_message.set_name('XXOBJT', 'XXOM_SF2OA_REQUIRED_HDR_FIELD');
          fnd_message.set_token('FIELD', 'Invoice_Site_Num');
          p_err_message := fnd_message.get;
          RAISE l_my_exception;
        END IF;
  
        -- find oracle ID's
        -- ship_from_org_id/Org_id
  
        BEGIN
  
          SELECT t.operating_unit, t.organization_id ship_from_org_id
            INTO l_org_id, i.ship_from_org_id
            FROM xxobjt_org_organization_def_v t
           WHERE t.organization_code = i.organization_code;
        EXCEPTION
  
          WHEN OTHERS THEN
  
            fnd_message.set_name('XXOBJT', 'XXOM_SF2OA_INVALID_VALUE');
            fnd_message.set_token('FIELD', 'Organization_Code');
            p_err_message := fnd_message.get;
            RAISE l_my_exception;
  
        END;
  
        -- init environment befor selects from hz_party tables
        fnd_global.apps_initialize(i.user_id, 0, 0);
        fnd_global.apps_initialize(i.user_id, i.resp_id, i.resp_appl_id);
  
        mo_global.init('ONT');
        mo_global.set_policy_context('S', l_org_id);
  
        -- sold_to_org_id
        i.sold_to_org_id := get_sold_to_org_id(i.cust_account_number,
                                               l_org_id ); -- 18/11/2013 Dalit A. Raviv l_org_id
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
  
        i.ship_to_org_id := get_ship_invoice_org_id(NULL, -- i.cust_account_number
                                                    i.shipping_site_num,
                                                    'SHIP_TO',
                                                    l_org_id ); -- 18/11/2013 Dalit A. Raviv l_org_id  get_ship_invoice_org_id get_sold_to_org_id
  
        i.invoice_to_org_id := get_ship_invoice_org_id(NULL,
                                                       i.invoice_site_num,
                                                       'BILL_TO',
                                                       l_org_id ); -- 18/11/2013 Dalit A. Raviv l_org_id
  
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
               t.org_id                = l_org_id,
               t.last_update_date      = SYSDATE,
               t.last_updated_by       = fnd_global.user_id
  
         WHERE t.interface_header_id = p_header_seq;
  
        COMMIT;
  
        --------------------------------------------------
        -------------- lines validation ------------------
        --------------------------------------------------
  
        FOR j IN c_lines LOOP
  
          --  dbms_output.put_line('j.ordered_item=' || j.ordered_item);
  
          l_line_exists_flag := 1;
          -- check required
          -- return_reason_code
  
          -- line_number
          IF j.line_number IS NULL THEN
            fnd_message.set_name('XXOBJT', 'XXOM_SF2OA_REQUIRED_LINE_FIELD');
            fnd_message.set_token('FIELD', 'Order_Line_number');
            fnd_message.set_token('LINE_NO', c_lines%ROWCOUNT);
            p_err_message := fnd_message.get;
            RAISE l_my_exception;
          END IF;
  
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
  
          -- ship from org
  
          IF j.organization_code IS NOT NULL THEN
            BEGIN
  
              SELECT t.organization_id ship_from_org_id
                INTO j.ship_from_org_id
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
  
          -- save calc fields
          UPDATE xxom_sf2oa_lines_interface l
             SET l.inventory_item_id = j.inventory_item_id,
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
  
      -------------------------------------------------------------
      ---- prepare  order API
      --------------------------------------------------------------
  
      FOR i IN c_header LOOP
  
        --if nvl(i.order_status,'ENTERED') = 'BOOKED' then
        --  l_header_rec.flow_status_code        := 'BOOKED';
        --else
        --  l_header_rec.flow_status_code        := 'ENTERED';
        --end if;
  
        -- 12/01/2014 Dalit A. Raviv - handle create order in BOOKED status.
        -- populate required attributes
        -- l_header_rec := p_header_rec;
        -- initialize action request record
        IF i.order_status = 'BOOKED' THEN
          IF i.payment_term_id IS NULL THEN
            NULL;
            fnd_message.set_name('XXOBJT', 'XXOM_SF2OA_PAYMENT_TERM_ISNULL'); -- Payment Term is required on a booked order line.
            p_err_message := fnd_message.get;
            RAISE l_my_exception;
          ELSE
            l_action_request_tbl(1) := oe_order_pub.g_miss_request_rec;
            l_action_request_tbl(1).request_type := oe_globals.g_book_order; -- 'BOOK_ORDER'
            l_action_request_tbl(1).entity_code := oe_globals.g_entity_header;
          END IF;
        END IF;
        -- end 12/01/2014
  
        l_header_rec.flow_status_code := 'ENTERED';
        l_header_rec                  := oe_order_pub.g_miss_header_rec;
        l_header_rec.operation        := oe_globals.g_opr_create;
        -- set header variables
        l_header_rec.org_id                  := l_org_id;
        l_header_rec.order_type_id           := i.order_type_id;
        l_header_rec.sold_to_org_id          := i.sold_to_org_id;
        l_header_rec.ship_to_org_id          := i.ship_to_org_id;
        l_header_rec.invoice_to_org_id       := i.invoice_to_org_id;
        l_header_rec.pricing_date            := SYSDATE;
        l_header_rec.ship_from_org_id        := i.ship_from_org_id;
        l_header_rec.transactional_curr_code := i.currency_code;
  
        l_header_rec.cust_po_number        := nvl(i.cust_po, 'No PO');
        l_header_rec.order_source_id       := i.order_source_id;
        l_header_rec.freight_terms_code    := nvl(i.freight_terms_code,
                                                  fnd_api.g_miss_char);
        l_header_rec.shipping_method_code  := nvl(i.shipping_method_code,
                                                  fnd_api.g_miss_char);
        l_header_rec.orig_sys_document_ref := i.orig_sys_document_ref;
        l_header_rec.ordered_date          := i.ordered_date;
        l_header_rec.ship_to_contact_id    := i.ship_to_contact_id;
        l_header_rec.invoice_to_contact_id := i.invoice_to_contact_id;
        l_header_rec.shipping_instructions := i.shipping_comments;
        l_header_rec.payment_term_id       := i.payment_term_id;
  
        -- dff
        l_header_rec.attribute1  := nvl(i.attribute1, fnd_api.g_miss_char);
        l_header_rec.attribute2  := nvl(i.attribute2, fnd_api.g_miss_char);
        l_header_rec.attribute3  := nvl(i.attribute3, fnd_api.g_miss_char);
        l_header_rec.attribute4  := nvl(i.attribute4, fnd_api.g_miss_char);
        l_header_rec.attribute5  := nvl(i.attribute5, fnd_api.g_miss_char);
        l_header_rec.attribute6  := nvl(i.attribute6, fnd_api.g_miss_char);
        l_header_rec.attribute7  := nvl(i.attribute7, fnd_api.g_miss_char);
        l_header_rec.attribute8  := nvl(i.attribute8, fnd_api.g_miss_char);
        l_header_rec.attribute9  := nvl(i.attribute9, fnd_api.g_miss_char);
        l_header_rec.attribute10 := nvl(i.attribute10, fnd_api.g_miss_char);
        l_header_rec.attribute11 := nvl(i.attribute11, fnd_api.g_miss_char);
        l_header_rec.attribute12 := nvl(i.attribute12, fnd_api.g_miss_char);
        l_header_rec.attribute13 := nvl(i.attribute13, fnd_api.g_miss_char);
        l_header_rec.attribute14 := nvl(i.attribute14, fnd_api.g_miss_char);
        l_header_rec.attribute15 := nvl(i.attribute15, fnd_api.g_miss_char);
  
        -- get user_id from email
        IF i.email IS NOT NULL THEN
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
  
        END IF;
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
          l_line_tbl(l_inx).shipping_instructions := j.shipping_instructions;
          l_line_tbl(l_inx).packing_instructions := j.packing_instructions;
  
          l_line_tbl(l_inx).line_type_id := l_line_tbl(l_inx).line_type_id;
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
          -- dff
          l_line_tbl(l_inx).attribute1 := nvl(j.attribute1,
                                              fnd_api.g_miss_char);
          l_line_tbl(l_inx).attribute2 := nvl(j.attribute2,
                                              fnd_api.g_miss_char);
          l_line_tbl(l_inx).attribute3 := nvl(j.attribute3,
                                              fnd_api.g_miss_char);
          l_line_tbl(l_inx).attribute4 := nvl(j.attribute4,
                                              fnd_api.g_miss_char);
          l_line_tbl(l_inx).attribute5 := nvl(j.attribute5,
                                              fnd_api.g_miss_char);
          l_line_tbl(l_inx).attribute6 := nvl(j.attribute6,
                                              fnd_api.g_miss_char);
          l_line_tbl(l_inx).attribute7 := nvl(j.attribute7,
                                              fnd_api.g_miss_char);
          l_line_tbl(l_inx).attribute8 := nvl(j.attribute8,
                                              fnd_api.g_miss_char);
          l_line_tbl(l_inx).attribute9 := nvl(j.attribute9,
                                              fnd_api.g_miss_char);
          l_line_tbl(l_inx).attribute10 := nvl(j.attribute10,
                                               fnd_api.g_miss_char);
          l_line_tbl(l_inx).attribute11 := nvl(j.attribute11,
                                               fnd_api.g_miss_char);
          l_line_tbl(l_inx).attribute12 := nvl(j.attribute12,
                                               fnd_api.g_miss_char);
          l_line_tbl(l_inx).attribute13 := nvl(j.attribute13,
                                               fnd_api.g_miss_char);
          l_line_tbl(l_inx).attribute14 := nvl(j.attribute14,
                                               fnd_api.g_miss_char);
          l_line_tbl(l_inx).attribute15 := nvl(j.attribute15,
                                               fnd_api.g_miss_char);
  
        END LOOP;
        dbms_output.put_line('End  validation...Start Api' ||
                             to_char(SYSDATE, 'hh24:mi:ss'));
  
        --
        -- create order
        --
  
        create_order_api(l_org_id,
  
                         nvl(l_user_id, i.user_id),
                         i.resp_id,
                         i.resp_appl_id,
                         l_header_rec,
                         l_line_tbl,
                         l_action_request_tbl,
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
    END create_order_old;
  */

  --------------------------------------------------------------------
  --  name:            Purge_order_interface_tables
  --  create by:       Michal Tzvik
  --  Revision:        1.0
  --  creation date:   07/01/2015
  --------------------------------------------------------------------
  --  purpose :        CHG00340083
  --                   Purge order interface tables
  --                   Concurrent executable: XXOM_PURGE_ORDER_INT_TABELS
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  07/01/2015  Michal Tzvik    initial build
  --------------------------------------------------------------------
  PROCEDURE purge_order_interface_tables(errbuf             OUT VARCHAR2,
                                         retcode            OUT VARCHAR2,
                                         p_days_back        IN NUMBER,
                                         p_source_type_code IN VARCHAR2,
                                         p_status           IN VARCHAR2) IS
  
    CURSOR c_headers(p_days_back        NUMBER,
                     p_source_type_code VARCHAR2,
                     p_status           VARCHAR2) IS
      SELECT xohi.interface_header_id
        FROM xxom_order_header_interface xohi
       WHERE 1 = 1
         AND (p_status IS NULL OR xohi.status_code = p_status)
         AND xohi.check_source = nvl(p_source_type_code, xohi.check_source)
         AND xohi.creation_date < SYSDATE - p_days_back;
  
    l_cnt NUMBER := 0;
  BEGIN
    errbuf  := '';
    retcode := '0';
  
    fnd_file.put_line(fnd_file.log, 'Parameters:');
    fnd_file.put_line(fnd_file.log, '-----------');
    fnd_file.put_line(fnd_file.log, 'p_days_back:        ' || p_days_back);
    fnd_file.put_line(fnd_file.log,
                      'p_source_type_code: ' || p_source_type_code);
    fnd_file.put_line(fnd_file.log, 'p_status:           ' || p_status);
    fnd_file.put_line(fnd_file.log, '');
    fnd_file.put_line(fnd_file.log, '');
  
    FOR r_header IN c_headers(p_days_back, p_source_type_code, p_status) LOOP
      BEGIN
        SAVEPOINT delete_header;
      
        -- delete header
        DELETE FROM xxom_order_header_interface xohi
         WHERE xohi.interface_header_id = r_header.interface_header_id;
      
        -- delete related lines
        DELETE FROM xxom_order_lines_interface xoli
         WHERE xoli.interface_header_id = r_header.interface_header_id;
      
        l_cnt := l_cnt + 1;
      EXCEPTION
        WHEN OTHERS THEN
          errbuf  := 'Prcess failed. see details in log.';
          retcode := '1';
          fnd_file.put_line(fnd_file.log,
                            'Error: cannot delete records of interface_header_id ' ||
                            r_header.interface_header_id || ': ' || SQLERRM);
          ROLLBACK TO delete_header;
      END;
    END LOOP;
  
    COMMIT;
    fnd_file.put_line(fnd_file.log,
                      l_cnt ||
                      ' interface headers were deleted successfully.');
  
  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'Unexpected error';
      retcode := '2';
      fnd_file.put_line(fnd_file.log, 'Unexpected error: ' || SQLERRM);
  END purge_order_interface_tables;

  --------------------------------------------------------------------
  --  name:            get_contact_name
  --  create by:       Michal Tzvik
  --  Revision:        1.0
  --  creation date:   07/01/2015
  --------------------------------------------------------------------
  --  purpose :        CHG00340083
  --                   get formated contact name
  --                   Called by view xxom_order_header_interface_v
  --                   for form XXOMORDERSINT
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  07/01/2015  Michal Tzvik    initial build
  --------------------------------------------------------------------
  FUNCTION get_contact_name(p_contact_id NUMBER) RETURN VARCHAR2 IS
    l_contact_name VARCHAR2(200);
  BEGIN
  
    SELECT xocdv_con.contact_number || ' - ' || xocdv_con.contact_name ||
           ' (AC# ' || hca.account_number || ')'
      INTO l_contact_name
      FROM xxobjt_oa2sf_contact_details_v xocdv_con, hz_cust_accounts hca
     WHERE hca.cust_account_id = xocdv_con.cust_account_id
       AND xocdv_con.contact_id = p_contact_id;
  
    RETURN l_contact_name;
  
  EXCEPTION
    WHEN no_data_found THEN
      RETURN NULL;
  END get_contact_name;

END xxom_order_interface_pkg;
/