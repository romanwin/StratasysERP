CREATE OR REPLACE PACKAGE BODY xxqp_price_book_pkg IS
  ----------------------------------------------------------------------------
  --  name:            XXQP_PRICE_BOOK_PKG
  --  create by:       Diptasurjya Chatterjee (TCS)
  --  Revision:        1.0
  --  creation date:   02-Mar-2018
  ----------------------------------------------------------------------------
  --  purpose :        CHG0042196 - Pricebook Generation as per request originating from Strataforce
  ----------------------------------------------------------------------------
  --  ver   date           name                            Desc
  --  1.0   02-Mar-2018    Diptasurjya Chatterjee (TCS)    CHG0042196 - Initial Build
  --  1.1   08-Jul-2018    Diptasurjya Chatterjee (TCS)    CTASK0037438 - Add extra filter conditions
  --  1.2   27-Mar-2019    Diptasurjya Chatterjee (TCS)    CHG0045417 - Pricebook date filter
  --  1.3   27-Dec-2019    Diptasurjya                     CHG0046948 - add new pricing header rec field in call_pricing_api
  --  1.4   16/03/2020     Roman W.                        INC0186641 - adding new field to xxqp_pricereq_custatt_rec_type 
  ----------------------------------------------------------------------------

  g_sf_stat_progress VARCHAR2(100) := 'In Progress';
  g_sf_stat_success  VARCHAR2(100) := 'Success';
  g_sf_stat_failure  VARCHAR2(100) := 'Error';

  -- This variable is to limit the number od records fetched during testing (set to high number during go-live)
  g_test_count NUMBER := 1000;
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0042196 - This function fetches item description
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                            Description
  -- 1.0  23/02/2018  Diptasurjya Chatterjee (TCS)    CHG0042196 - Initial Build
  -- --------------------------------------------------------------------------------------------
  FUNCTION get_item_description(p_inventory_item_id NUMBER) RETURN VARCHAR2 IS
    l_item_description VARCHAR2(240);
  BEGIN
    SELECT description
      INTO l_item_description
      FROM mtl_system_items_b
     WHERE inventory_item_id = p_inventory_item_id
       AND organization_id = xxinv_utils_pkg.get_master_organization_id;
  
    RETURN l_item_description;
  END get_item_description;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0042196 - This function fetches item long description
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                            Description
  -- 1.0  23/02/2018  Diptasurjya Chatterjee (TCS)    CHG0042196 - Initial Build
  -- --------------------------------------------------------------------------------------------
  FUNCTION get_item_long_description(p_inventory_item_id NUMBER)
    RETURN VARCHAR2 IS
    l_item_long_description VARCHAR2(4000);
  BEGIN
    SELECT msit.long_description
      INTO l_item_long_description
      FROM mtl_system_items_b msib, mtl_system_items_tl msit
     WHERE msib.inventory_item_id = p_inventory_item_id
       AND msib.organization_id =
           xxinv_utils_pkg.get_master_organization_id
       AND msib.inventory_item_id = msit.inventory_item_id
       AND msit.organization_id = msib.organization_id
       AND msit.language = userenv('LANG');
  
    RETURN l_item_long_description;
  EXCEPTION
    WHEN no_data_found THEN
      RETURN NULL;
  END get_item_long_description;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0042196 - This function fetches Direct PL value for received reseller PL
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                            Description
  -- 1.0  23/02/2018  Diptasurjya Chatterjee (TCS)    CHG0042196 - Initial Build
  -- --------------------------------------------------------------------------------------------
  FUNCTION get_direct_pl(p_reseller_pl_id NUMBER) RETURN NUMBER IS
    l_direct_pl_id NUMBER;
  BEGIN
    SELECT qld.direct_pl
      INTO l_direct_pl_id
      FROM qp_list_headers_all_b qlh, qp_list_headers_b_dfv qld
     WHERE qlh.list_header_id = p_reseller_pl_id
       AND qlh.rowid = qld.row_id;
  
    RETURN l_direct_pl_id;
  EXCEPTION
    WHEN no_data_found THEN
      RETURN NULL;
  END get_direct_pl;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0042196 - This function fetches Product Family for a item code from Strataforce
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                            Description
  -- 1.0  23/02/2018  Diptasurjya Chatterjee (TCS)    CHG0042196 - Initial Build
  -- --------------------------------------------------------------------------------------------
  FUNCTION get_sf_prod_family(p_item_code VARCHAR2) RETURN VARCHAR2 IS
    l_sf_prod_family VARCHAR2(4000);
  BEGIN
    SELECT to_char(related_to_product_families__c)
      INTO l_sf_prod_family
      FROM xxsf2_product2
     WHERE external_key__c = p_item_code;
  
    RETURN l_sf_prod_family;
  EXCEPTION
    WHEN no_data_found THEN
      RETURN NULL;
  END get_sf_prod_family;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0042196 - This function fetches Applicable Systems for a item code from Strataforce
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                            Description
  -- 1.0  23/02/2018  Diptasurjya Chatterjee (TCS)    CHG0042196 - Initial Build
  -- --------------------------------------------------------------------------------------------
  FUNCTION get_sf_appl_system(p_item_code VARCHAR2) RETURN VARCHAR2 IS
    l_sf_appl_systems VARCHAR2(4000);
  BEGIN
    SELECT relatedtosystemsfx__c
      INTO l_sf_appl_systems
      FROM xxsf2_product2
     WHERE external_key__c = p_item_code;
  
    IF l_sf_appl_systems IS NOT NULL THEN
      l_sf_appl_systems := TRIM(both '|' FROM l_sf_appl_systems);
      --regexpr regexp_replace(l_sf_appl_systems, '(\|){2,}','')
    END IF;
  
    RETURN l_sf_appl_systems;
  EXCEPTION
    WHEN no_data_found THEN
      RETURN NULL;
  END get_sf_appl_system;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0042196 - This function checks if an item is valid for PB as per related product family filter
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                            Description
  -- 1.0  23/02/2018  Diptasurjya Chatterjee (TCS)    CHG0042196 - Initial Build
  -- --------------------------------------------------------------------------------------------
  FUNCTION is_eligible_per_prodfam(p_item_code   VARCHAR2,
                                   p_prod_family VARCHAR2) RETURN VARCHAR2 IS
    l_is_valid VARCHAR2(1);
  BEGIN
    FOR rec_prodfamily IN (WITH temp AS
                              (SELECT p_prod_family prod_families FROM dual)
                             SELECT DISTINCT TRIM(regexp_substr(prod_families,
                                                                '[^;]+',
                                                                1,
                                                                LEVEL)) prod_family
                               FROM (SELECT prod_families FROM temp) t
                             CONNECT BY instr(prod_families,
                                              ';',
                                              1,
                                              LEVEL - 1) > 0) LOOP
    
      BEGIN
        SELECT 'Y'
          INTO l_is_valid
          FROM xxsf2_product2
         WHERE upper(related_to_product_families__c) LIKE
               '%' || upper(rec_prodfamily.prod_family) || '%'
           AND external_key__c = p_item_code;
      
        EXIT;
      EXCEPTION
        WHEN no_data_found THEN
          l_is_valid := 'N';
      END;
    END LOOP;
  
    RETURN l_is_valid;
  END is_eligible_per_prodfam;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0042196 - This function checks if an item is valid for PB as per related machine filter
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                            Description
  -- 1.0  23/02/2018  Diptasurjya Chatterjee (TCS)    CHG0042196 - Initial Build
  -- --------------------------------------------------------------------------------------------
  FUNCTION is_eligible_per_machine(p_item_id         NUMBER,
                                   p_related_machine VARCHAR2)
    RETURN VARCHAR2 IS
    l_is_valid VARCHAR2(1);
  BEGIN
    FOR rec_machine IN (WITH temp AS
                           (SELECT p_related_machine rel_machines FROM dual)
                          SELECT DISTINCT TRIM(regexp_substr(rel_machines,
                                                             '[^;]+',
                                                             1,
                                                             LEVEL)) rel_machine
                            FROM (SELECT rel_machines FROM temp) t
                          CONNECT BY instr(rel_machines, ';', 1, LEVEL - 1) > 0) LOOP
    
      BEGIN
      
        SELECT 'Y'
          INTO l_is_valid
          FROM mtl_item_categories mic,
               mtl_category_sets   mcs,
               mtl_categories_kfv  mck
         WHERE mic.inventory_item_id = p_item_id
           AND mic.organization_id =
               xxinv_utils_pkg.get_master_organization_id
           AND mic.category_set_id = mcs.category_set_id
           AND mcs.category_set_name IN
               ('CS Price Book Product Type',
                'SALES Price Book Product Type')
           AND mic.category_id = mck.category_id
           AND mck.concatenated_segments = rec_machine.rel_machine;
      
        EXIT;
      EXCEPTION
        WHEN no_data_found THEN
          l_is_valid := 'N';
      END;
    END LOOP;
  
    RETURN l_is_valid;
  END is_eligible_per_machine;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0042196 - This function checks if an item is valid for PB as per related Visible in PB
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                            Description
  -- 1.0  23/02/2018  Yuval tal                       CHG0042196 - Initial Build
  -- --------------------------------------------------------------------------------------------

  FUNCTION is_visible_in_pb(p_item_id NUMBER) RETURN VARCHAR2 IS
    l_flag   VARCHAR2(1);
    l_org_id NUMBER := xxinv_utils_pkg.get_master_organization_id;
  BEGIN
    SELECT 'Y'
      INTO l_flag
      FROM mtl_item_categories mic,
           mtl_categories_kfv  mck,
           mtl_category_sets   mas
     WHERE mas.category_set_id = mic.category_set_id
       AND mic.inventory_item_id = p_item_id
       AND mas.category_set_name = 'Visible in PB'
       AND mic.organization_id = l_org_id
       AND mic.category_id = mck.category_id
       AND mck.segment1 = 'Y';
  
    RETURN l_flag;
  EXCEPTION
    WHEN no_data_found THEN
      RETURN 'N';
    
  END;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0042196
  --          This function will delete records from XXQP_PRICEBOOK_DATA as per input event_id
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  03/02/2018  Diptasurjya Chatterjee        Initial Build
  -- --------------------------------------------------------------------------------------------
  FUNCTION delete_price(p_event_id NUMBER) RETURN NUMBER IS
  
  BEGIN
    DELETE FROM xxobjt.xxqp_pricebook_data WHERE event_id = p_event_id;
    COMMIT;
  
    RETURN 0;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 1;
  END delete_price;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0042196
  --          This procedure will insert records into  XXQP_PRICEBOOK_DATA as per input table type
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  03/02/2018  Diptasurjya Chatterjee        Initial Build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE populate_price(p_sf_price_tab IN xxqp_sf_price_tab DEFAULT CAST(NULL AS
                                                                            xxqp_sf_price_tab)) IS
    l_gt_rec_cnt NUMBER;
  BEGIN
  
    FOR j IN 1 .. p_sf_price_tab.count LOOP
    
      INSERT INTO xxqp_pricebook_data
        (product_family,
         applicable_system,
         product_code,
         product_name,
         prod_long_desc,
         product_type,
         reseller_price,
         direct_price,
         currency,
         event_id,
         adjustment_info)
      VALUES
        (
         --p_sf_price_tab(j).product_family,
         get_sf_prod_family(p_sf_price_tab(j).product_code),
         --p_sf_price_tab(j).applicable_system,
         get_sf_appl_system(p_sf_price_tab(j).product_code),
         p_sf_price_tab(j).product_code,
         p_sf_price_tab(j).product_name,
         p_sf_price_tab(j).prod_long_desc,
         p_sf_price_tab(j).product_type,
         p_sf_price_tab(j).reseller_price,
         p_sf_price_tab(j).direct_price,
         p_sf_price_tab(j).currency,
         p_sf_price_tab(j).event_id,
         p_sf_price_tab(j).adjustment_info);
    END LOOP;
    COMMIT;
    --Select count(1) into l_GT_rec_cnt from XXOBJT_PRICEBOOK_GEN;
    fnd_file.put_line(fnd_file.log,
                      '-->No of Records in the Global Temp Table :' ||
                      p_sf_price_tab.count);
  
  END populate_price;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0042196
  --          This program will generate price book excel file. Performs following activities:
  --          1. Call report program XXGENPRICEBOOK for passed event id
  --          2. Wait for above program to complete
  --          3. Submit concurrent program XDOBURSTREP if p_send_email is Y
  --          If p_email_address has valid value, then it will override the email address present for the event record
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  03/02/2018  Diptasurjya Chatterjee        Initial Build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE generate_pricebook_excel(x_err_code            OUT VARCHAR2,
                                     x_err_msg             OUT VARCHAR2,
                                     p_event_id            IN NUMBER,
                                     p_send_mail           IN VARCHAR2,
                                     p_email_address       IN VARCHAR2,
                                     p_process_extra_field IN VARCHAR2) IS
    l_rep_request_id   NUMBER;
    l_burst_request_id NUMBER;
    l_err_msg          VARCHAR2(2000);
    l_layout           BOOLEAN;
  
    v_phase      VARCHAR2(80) := NULL;
    v_status     VARCHAR2(80) := NULL;
    v_dev_phase  VARCHAR2(80) := NULL;
    v_dev_status VARCHAR2(80) := NULL;
    v_message    VARCHAR2(240) := NULL;
    v_req_st     BOOLEAN;
  
  BEGIN
    fnd_file.put_line(fnd_file.log,
                      'generate_pricebook_excel Called ' ||
                      p_process_extra_field);
  
    l_layout := fnd_request.add_layout(template_appl_name => 'XXOBJT',
                                       template_code      => 'XXQPPBREPORT',
                                       template_language  => 'en',
                                       template_territory => 'US',
                                       output_format      => 'EXCEL');
  
    l_rep_request_id := fnd_request.submit_request(application => 'XXOBJT',
                                                   program     => 'XXQPPBREPORT',
                                                   description => 'XX: QP Generate Price Book and Send Mail',
                                                   start_time  => SYSDATE,
                                                   sub_request => FALSE,
                                                   argument1   => p_event_id,
                                                   argument2   => p_email_address,
                                                   argument3   => p_process_extra_field);
  
    IF l_rep_request_id > 0 THEN
      COMMIT;
    
      LOOP
        v_req_st := apps.fnd_concurrent.wait_for_request(request_id => l_rep_request_id,
                                                         INTERVAL   => 0,
                                                         max_wait   => 0,
                                                         phase      => v_phase,
                                                         status     => v_status,
                                                         dev_phase  => v_dev_phase,
                                                         dev_status => v_dev_status,
                                                         message    => v_message);
        EXIT WHEN v_dev_phase = 'COMPLETE';
      END LOOP;
    
      fnd_file.put_line(fnd_file.log, 'Request status ' || v_dev_status);
    
      IF v_dev_status <> 'NORMAL' THEN
        x_err_code := 'ERROR';
        x_err_msg  := 'ERROR: Pricebook report generation program finished with errors.';
      ELSE
        IF p_send_mail = 'Y' THEN
          v_req_st     := NULL;
          v_phase      := NULL;
          v_status     := NULL;
          v_dev_phase  := NULL;
          v_dev_status := NULL;
          v_message    := NULL;
        
          l_burst_request_id := fnd_request.submit_request(application => 'XDO',
                                                           program     => 'XDOBURSTREP',
                                                           description => NULL,
                                                           start_time  => SYSDATE,
                                                           sub_request => FALSE,
                                                           argument1   => NULL,
                                                           argument2   => l_rep_request_id,
                                                           argument3   => 'Y');
        
          IF l_burst_request_id > 0 THEN
            COMMIT;
          
            LOOP
              v_req_st := apps.fnd_concurrent.wait_for_request(request_id => l_burst_request_id,
                                                               INTERVAL   => 0,
                                                               max_wait   => 0,
                                                               phase      => v_phase,
                                                               status     => v_status,
                                                               dev_phase  => v_dev_phase,
                                                               dev_status => v_dev_status,
                                                               message    => v_message);
              EXIT WHEN v_dev_phase = 'COMPLETE';
            END LOOP;
          
            IF v_dev_status <> 'NORMAL' THEN
              x_err_code := 'ERROR';
              x_err_msg  := 'ERROR: Pricebook report bursting program finished with errors.';
            ELSE
              x_err_code := 'SUCCESS';
              x_err_msg  := NULL;
            END IF;
          ELSE
            x_err_code := 'ERROR';
            x_err_msg  := 'ERROR: Pricebook report bursting program could not be submitted';
          END IF;
        ELSE
          x_err_code := 'SUCCESS';
          x_err_msg  := NULL;
        END IF;
      END IF;
    
      COMMIT;
    ELSE
      x_err_code := 'ERROR';
      x_err_msg  := 'ERROR: Pricebook report generation program could not be submitted';
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      x_err_code := 'ERROR';
      x_err_msg  := 'ERROR: Pricebook report generation program could not be submitted. ' ||
                    SQLERRM;
  END generate_pricebook_excel;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0042196
  --          This program will validate input details for a price book generation event ID
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  03/02/2018  Diptasurjya Chatterjee        Initial Build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE validate_data(p_event_id IN NUMBER,
                          x_err_code OUT NUMBER,
                          x_err_msg  OUT VARCHAR2) IS
    l_request_id NUMBER;
  
    l_email_address_nosplit VARCHAR2(4000);
    l_email_address_invalid VARCHAR2(4000);
  
    l_pricelist_id   NUMBER;
    l_account_number VARCHAR2(100);
  
    l_is_valid     VARCHAR2(1);
    l_is_valid_msg VARCHAR2(4000);
    l_exists       VARCHAR2(1) := 'N';
  BEGIN
    x_err_code := 0;
  
    SELECT attribute3, attribute1, attribute2
      INTO l_email_address_nosplit, l_pricelist_id, l_account_number
      FROM xxssys_events
     WHERE event_id = p_event_id;
  
    -- Validate email
    BEGIN
      IF l_email_address_nosplit IS NULL THEN
        l_is_valid     := 'N';
        l_is_valid_msg := l_is_valid_msg ||
                          'VALIDATION ERROR: Email address is required input.' ||
                          chr(13);
      END IF;
    
      IF l_is_valid <> 'N' THEN
        SELECT xxobjt_general_utils_pkg.get_invalid_mail_list(l_email_address_nosplit,
                                                              ',')
          INTO l_email_address_invalid
          FROM dual;
      
        IF nvl(l_email_address_invalid, 'Z') = 'Z' THEN
          l_is_valid     := 'N';
          l_is_valid_msg := l_is_valid_msg ||
                            'VALIDATION ERROR: Email addresses: ' ||
                            l_email_address_invalid || ' not valid.' ||
                            chr(13);
        END IF;
      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        l_is_valid     := 'N';
        l_is_valid_msg := l_is_valid_msg ||
                          'UNEXPECTED ERROR: While validation Email address. ' ||
                          SQLERRM || chr(13);
    END;
  
    IF l_pricelist_id IS NULL THEN
      l_is_valid     := 'N';
      l_is_valid_msg := l_is_valid_msg ||
                        'VALIDATION ERROR: Pricelist is required input.' ||
                        chr(13);
    END IF;
  
    IF l_account_number IS NULL THEN
      l_is_valid     := 'N';
      l_is_valid_msg := l_is_valid_msg ||
                        'VALIDATION ERROR: Account Number is required input.' ||
                        chr(13);
    ELSE
      BEGIN
        SELECT 'Y'
          INTO l_exists
          FROM hz_cust_accounts hca
         WHERE hca.account_number = l_account_number
           AND hca.status = 'A';
      EXCEPTION
        WHEN no_data_found THEN
          l_is_valid     := 'N';
          l_is_valid_msg := l_is_valid_msg ||
                            'VALIDATION ERROR: Account Number ' ||
                            l_account_number || ' is not Active in Oracle.' ||
                            chr(13);
      END;
    END IF;
  
    IF l_is_valid = 'N' THEN
      x_err_code := 2;
      x_err_msg  := l_is_valid_msg;
    ELSE
      x_err_code := 0;
      x_err_msg  := NULL;
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      x_err_msg  := l_is_valid_msg ||
                    'UNEXPECTED ERROR: In procedure validate_data. ' ||
                    SQLERRM || chr(13);
      x_err_code := 2;
  END validate_data;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0042196
  --          This program will call SOA WS http://www.strataforce.dmn/UpdatePricebook_Request
  --          to update the status of a Price book generation request in Strataforce
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  03/02/2018  Diptasurjya Chatterjee        Initial Build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE call_update_status_sfws(x_retcode      OUT NUMBER,
                                    x_errbuf       OUT VARCHAR2,
                                    p_event_id     IN NUMBER,
                                    p_sourceref_id IN VARCHAR2,
                                    p_in_status    IN VARCHAR2,
                                    p_err_message  VARCHAR2 /*default null*/) IS
  
    l_quote_number     VARCHAR2(200);
    l_order_number     NUMBER;
    l_org_id           NUMBER;
    l_so_line_count    NUMBER;
    l_quote_orders     VARCHAR2(2000) := 0;
    l_so_header_status VARCHAR2(20);
  
    l_user_id NUMBER;
    l_resp_id NUMBER;
    l_appl_id NUMBER;
  
    service_            sys.utl_dbws.service;
    call_               sys.utl_dbws.call;
    service_qname       sys.utl_dbws.qname;
    response            sys.xmltype;
    request             sys.xmltype;
    l_string_type_qname sys.utl_dbws.qname;
  
    l_err_msg VARCHAR2(2000) := NULL;
  
    l_ws_q_err_message VARCHAR2(2000);
    l_ws_q_err_code    VARCHAR2(100);
  
    g_strataforce_target VARCHAR2(150) := 'STRATAFORCE';
  BEGIN
    x_retcode := 0;
    /* Perform basic validations */
    IF p_event_id IS NULL THEN
      x_retcode := 2;
      x_errbuf  := 'ERROR: Event ID cannot be blank';
    END IF;
  
    IF p_sourceref_id IS NULL THEN
      x_retcode := 2;
      x_errbuf  := x_errbuf || chr(13) ||
                   'ERROR: Source Reference ID cannot be blank';
    END IF;
  
    IF p_in_status IS NULL OR
       p_in_status NOT IN
       (g_sf_stat_failure, g_sf_stat_progress, g_sf_stat_success) THEN
      x_retcode := 2;
      x_errbuf  := x_errbuf || chr(13) ||
                   'ERROR: Status to be updated must have proper value';
    END IF;
  
    /* Start webservice call processing */
    fnd_file.put_line(fnd_file.log,
                      'BPEL CALL: Starting BPEL connection processing');
    service_qname       := sys.utl_dbws.to_qname('http://www.strataforce.dmn/UpdatePricebook_Request',
                                                 'UpdatePricebook_Request');
    l_string_type_qname := sys.utl_dbws.to_qname('http://www.w3.org/2001/XMLSchema',
                                                 'string');
    service_            := sys.utl_dbws.create_service(service_qname);
    call_               := sys.utl_dbws.create_call(service_);
  
    fnd_file.put_line(fnd_file.log,
                      'XXOBJT_SF2OA_SOA_SRV_NUM=' ||
                      fnd_profile.value('XXOBJT_SF2OA_SOA_SRV_NUM'));
  
    IF nvl(fnd_profile.value('XXOBJT_SF2OA_SOA_SRV_NUM'), '1') = '1' THEN
      sys.utl_dbws.set_target_endpoint_address(call_,
                                               xxobjt_bpel_utils_pkg.get_bpel_host_srv1 ||
                                               '/soa-infra/services/sfdc/UpdatePricebookRequestCmp/updatepricebookrequestbpel_client_ep?WSDL');
    ELSE
      sys.utl_dbws.set_target_endpoint_address(call_,
                                               xxobjt_bpel_utils_pkg.get_bpel_host_srv2 ||
                                               '/soa-infra/services/sfdc/UpdatePricebookRequestCmp/updatepricebookrequestbpel_client_ep?WSDL');
    END IF;
  
    sys.utl_dbws.set_property(call_, 'SOAPACTION_USE', 'TRUE');
    sys.utl_dbws.set_property(call_, 'SOAPACTION_URI', 'process');
    sys.utl_dbws.set_property(call_, 'OPERATION_STYLE', 'document');
    sys.utl_dbws.set_property(call_,
                              'ENCODINGSTYLE_URI',
                              'http://schemas.xmlsoap.org/soap/encoding/');
  
    sys.utl_dbws.set_return_type(call_, l_string_type_qname);
    -- Set request input
    request := sys.xmltype('<ns1:UpdatePricebook_Request xmlns:ns1="http://www.strataforce.dmn/UpdatePricebook_Request">
   <ns1:HeaderInfo><ns1:SourceRequestId>' ||
                           p_event_id || '</ns1:SourceRequestId>
  <ns1:Token>' ||
                           sys_context('userenv', 'db_name') ||
                           '</ns1:Token><ns1:SourceName>ORACLE</ns1:SourceName>
          </ns1:HeaderInfo> <ns1:Event><ns1:Event_id>' ||
                           p_event_id || '</ns1:Event_id>
  <ns1:Id>' || p_sourceref_id ||
                           '</ns1:Id><ns1:Status>' || p_in_status ||
                           '</ns1:Status><ns1:Status_note>' ||
                           p_err_message ||
                           '</ns1:Status_note>
          </ns1:Event></ns1:UpdatePricebook_Request>');
  
    response := sys.utl_dbws.invoke(call_, request);
    sys.utl_dbws.release_call(call_);
    sys.utl_dbws.release_service(service_);
  
    SELECT response.extract('//tns:IsSuccess/text()', 'xmlns:tns="http://www.strataforce.dmn/UpdatePricebook_Response" xmlns="http://www.stratasys.dmn/processQuoteLineResponse"')
           .getstringval(),
           response.extract('//tns:ErrorMsg/text()', 'xmlns:tns="http://www.strataforce.dmn/UpdatePricebook_Response" xmlns="http://www.stratasys.dmn/processQuoteLineResponse"')
           .getstringval()
      INTO l_ws_q_err_code, l_ws_q_err_message
      FROM dual;
  
    fnd_file.put_line(fnd_file.log,
                      'Webservice response - Code: ' || l_ws_q_err_code ||
                      ' Msg: ' || l_ws_q_err_message);
  
    IF upper(l_ws_q_err_code) <> 'TRUE' THEN
      x_retcode := 2;
      x_errbuf  := 'ERROR: ' || l_ws_q_err_message;
    ELSE
      x_retcode := 0;
      x_errbuf  := NULL;
    END IF;
  
    dbms_output.put_line('Webservice response - ' ||
                         response.getstringval());
  
    fnd_file.put_line(fnd_file.log,
                      'Webservice response - ' || response.getstringval());
  
  EXCEPTION
    WHEN OTHERS THEN
      dbms_output.put_line(substr(SQLERRM, 1, 250));
      l_err_msg := 'ERROR: While processing BPEL for event ID :' ||
                   p_event_id || ' ' || SQLERRM;
      fnd_file.put_line(fnd_file.log, l_err_msg);
      sys.utl_dbws.release_call(call_);
      sys.utl_dbws.release_service(service_);
      x_retcode := 2;
      x_errbuf  := l_err_msg;
  END call_update_status_sfws;
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0042196
  --          This Program will fetch the Active Price and UOM for the Item
  -- Return : Active Price , UOM
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.1  21/06/2018  Lingaraj                      CHG0042196 - CTASK0037204
  -- --------------------------------------------------------------------------------------------
  PROCEDURE get_direct_price_info(p_list_header_id NUMBER,
                                  p_item_id        IN OUT NUMBER,
                                  x_price_fetched  OUT VARCHAR2,
                                  x_price_uom      OUT VARCHAR2) IS
  BEGIN
    x_price_fetched := 'N';
  
    --Is Direct Price Exists for the Item
    BEGIN
      SELECT 'Y', qll.product_uom_code, qll.product_id
        INTO x_price_fetched, x_price_uom, p_item_id
        FROM qp_list_lines_v qll
       WHERE qll.list_header_id = p_list_header_id
         AND qll.product_attr_value <> 'ALL'
         AND is_visible_in_pb(qll.product_id) = 'Y'
         AND qll.product_id = p_item_id
         AND trunc(SYSDATE) BETWEEN nvl(qll.start_date_active, SYSDATE - 1) AND
             nvl(qll.end_date_active, SYSDATE + 1);
    EXCEPTION
      WHEN no_data_found THEN
        --If Active Price not found, Search for Related Item Price
        BEGIN
          SELECT related_item_id
            INTO p_item_id
            FROM mtl_related_items
           WHERE relationship_type_id = 5
             AND inventory_item_id = p_item_id; --var
        
          SELECT 'Y', qll.product_uom_code
            INTO x_price_fetched, x_price_uom
            FROM qp_list_lines_v qll
           WHERE qll.list_header_id = p_list_header_id --var
             AND qll.product_attr_value <> 'ALL'
             AND is_visible_in_pb(qll.product_id) = 'Y'
             AND qll.product_id = p_item_id --var
             AND trunc(SYSDATE) BETWEEN
                 nvl(qll.start_date_active, SYSDATE - 1) AND
                 nvl(qll.end_date_active, SYSDATE + 1);
        EXCEPTION
          WHEN no_data_found THEN
            x_price_fetched := 'N';
        END;
    END;
  END get_direct_price_info;
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0042196
  --          This program will call pricing API in LINE pricing mode for passed input details
  --          Price request number will be generated as per sequence xxqp_strataforce_pb_gen_seq
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  03/02/2018  Diptasurjya Chatterjee        Initial Build
  -- 1.1  18/06/2018  Lingaraj                      CHG0042196 - CTASK0037116 - Fetch related Item Direct price
  -- 1.2  27/12/2019  Diptasurjya                   CHG0046948 - add new pricing header rec field
  -- 1.3  16/03/2020  Roman W.                      INC0186641 - adding new field to xxqp_pricereq_custatt_rec_type 
  -- --------------------------------------------------------------------------------------------
  PROCEDURE call_pricing_api(p_input_rec           IN xxqp_sf_price_rec,
                             p_direct_pl           IN NUMBER,
                             p_indirect_pl         IN NUMBER,
                             p_process_extra_field IN VARCHAR2,
                             x_output_rec          OUT xxqp_sf_price_rec,
                             x_status              OUT VARCHAR2,
                             x_status_msg          OUT VARCHAR2) IS
    l_output_rec xxqp_sf_price_rec;
  
    -- reseller
    l_order_header_r xxqp_pricereq_header_tab_type := xxqp_pricereq_header_tab_type();
  
    l_order_output_r    xxqp_pricereq_header_tab_type := xxqp_pricereq_header_tab_type();
    l_lines_output_r    xxqp_pricereq_lines_tab_type := xxqp_pricereq_lines_tab_type();
    l_modifier_output_r xxqp_pricereq_mod_tab_type := xxqp_pricereq_mod_tab_type();
    l_session_output_r  xxqp_pricereq_session_tab_type := xxqp_pricereq_session_tab_type();
    l_rel_output_r      xxqp_pricereq_reltd_tab_type := xxqp_pricereq_reltd_tab_type();
    l_attr_output_r     xxqp_pricereq_attr_tab_type := xxqp_pricereq_attr_tab_type();
  
    l_status_r         VARCHAR2(10) := 'S';
    l_status_message_r VARCHAR2(2000);
  
    -- direct
    l_order_header_d xxqp_pricereq_header_tab_type := xxqp_pricereq_header_tab_type();
  
    l_order_output_d    xxqp_pricereq_header_tab_type := xxqp_pricereq_header_tab_type();
    l_lines_output_d    xxqp_pricereq_lines_tab_type := xxqp_pricereq_lines_tab_type();
    l_modifier_output_d xxqp_pricereq_mod_tab_type := xxqp_pricereq_mod_tab_type();
    l_session_output_d  xxqp_pricereq_session_tab_type := xxqp_pricereq_session_tab_type();
    l_rel_output_d      xxqp_pricereq_reltd_tab_type := xxqp_pricereq_reltd_tab_type();
    l_attr_output_d     xxqp_pricereq_attr_tab_type := xxqp_pricereq_attr_tab_type();
  
    l_status_d         VARCHAR2(10) := 'S';
    l_status_message_d VARCHAR2(2000);
  
    -- common
    l_order_lines       xxqp_pricereq_lines_tab_type := xxqp_pricereq_lines_tab_type();
    l_custom_attributes xxqp_pricereq_custatt_tab_type := xxqp_pricereq_custatt_tab_type();
  
    l_cust_attr_index NUMBER := 1;
  
    l_status         VARCHAR2(1) := 'S';
    l_status_message VARCHAR2(4000) := NULL;
  
    --l_related_inv_item_id   NUMBER := null; --CTASK0037116
    --l_related_item_flag     VARCHAR2(1):= 'N';--CTASK0037116
    l_item_id_d          NUMBER;
    l_is_price_fetched_d VARCHAR2(1) := 'N'; --CTASK0037204
    l_price_uom_d        VARCHAR2(10); --CTASK0037204
    l_step               VARCHAR2(20);
  BEGIN
    l_step       := 'Step 01';
    l_output_rec := p_input_rec;
  
    -- Set RESELLER header inputs
    l_order_header_r.extend;
    l_order_header_r(1) := xxqp_pricereq_header_rec_type(NULL,
                                                         NULL,
                                                         NULL,
                                                         NULL,
                                                         NULL,
                                                         NULL,
                                                         NULL,
                                                         NULL,
                                                         NULL,
                                                         NULL,
                                                         NULL,
                                                         NULL,
                                                         NULL,
                                                         NULL,
                                                         NULL,
                                                         NULL,
                                                         NULL,
                                                         NULL,
                                                         NULL,
                                                         NULL,
                                                         NULL,
                                                         NULL,
                                                         NULL,
                                                         NULL,
                                                         NULL,
                                                         NULL,
                                                         NULL,
                                                         NULL,
                                                         NULL,
                                                         NULL,
                                                         NULL,
                                                         NULL,
                                                         NULL,
                                                         NULL,
                                                         NULL,
                                                         NULL,
                                                         NULL,
                                                         NULL,
                                                         NULL,
                                                         NULL,
                                                         NULL,
                                                         NULL,
                                                         NULL,
                                                         NULL,
                                                         NULL); -- CHG0046948 added
  
    l_order_header_r(1).cust_account_number := p_input_rec.account_number;
    l_order_header_r(1).price_list_id := p_indirect_pl; --p_input_rec.list_header_id;
    l_order_header_r(1).operation_no := p_input_rec.operation_no;
    l_order_header_r(1).org_id := p_input_rec.org_id;
    l_order_header_r(1).country_code := p_input_rec.country_code;
    l_order_header_r(1).end_customer_account := p_input_rec.end_cust_acct_num;
    l_order_header_r(1).price_request_number := xxqp_strataforce_pb_gen_seq.nextval;
  
    l_step := 'Step 02';
  
    IF p_direct_pl IS NOT NULL THEN
      -- Set DIRECT header inputs
      l_step := 'Step 02.1';
      l_order_header_d.extend;
      l_order_header_d(1) := xxqp_pricereq_header_rec_type(NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL); -- CHG0046948 added
    
      l_order_header_d(1).cust_account_number := p_input_rec.account_number;
      l_order_header_d(1).price_list_id := p_direct_pl;
      l_order_header_d(1).operation_no := p_input_rec.operation_no;
      l_order_header_d(1).org_id := p_input_rec.org_id;
      l_order_header_d(1).country_code := p_input_rec.country_code;
      l_order_header_d(1).end_customer_account := p_input_rec.end_cust_acct_num;
      l_order_header_d(1).price_request_number := xxqp_strataforce_pb_gen_seq.nextval;
    
      --CTASK0037204
      l_item_id_d   := p_input_rec.inventory_item_id;
      l_price_uom_d := p_input_rec.item_uom;
    
      IF p_indirect_pl IS NOT NULL THEN
        get_direct_price_info(p_list_header_id => p_direct_pl,
                              p_item_id        => l_item_id_d,
                              x_price_fetched  => l_is_price_fetched_d, --Y/N
                              x_price_uom      => l_price_uom_d);
      ELSE
        l_is_price_fetched_d := 'Y';
      END IF;
    
    END IF;
  
    l_step := 'Step 03';
    -- Set line inputs
    l_order_lines.extend;
    l_order_lines(1) := xxqp_pricereq_lines_rec_type(NULL,
                                                     NULL,
                                                     NULL,
                                                     NULL,
                                                     NULL,
                                                     NULL,
                                                     NULL,
                                                     NULL,
                                                     NULL,
                                                     NULL,
                                                     NULL,
                                                     NULL,
                                                     NULL,
                                                     NULL,
                                                     NULL,
                                                     NULL,
                                                     NULL,
                                                     NULL,
                                                     NULL,
                                                     NULL,
                                                     NULL,
                                                     NULL,
                                                     NULL,
                                                     NULL,
                                                     NULL);
    l_order_lines(1).line_num := 101;
    l_order_lines(1).inventory_item_id := p_input_rec.inventory_item_id;
    l_order_lines(1).quantity := 1;
    l_order_lines(1).item_uom := p_input_rec.item_uom; --CTASK0037204
    l_step := 'Step 04';
    -- Set custom attributes
    IF p_input_rec.industry IS NOT NULL THEN
      l_step := 'Step 04.1';
      l_custom_attributes.extend;
      l_custom_attributes(l_cust_attr_index) := xxqp_pricereq_custatt_rec_type(NULL,
                                                                               NULL,
                                                                               NULL,
                                                                               NULL,
                                                                               NULL,
                                                                               NULL,
                                                                               NULL,
                                                                               NULL,
                                                                               NULL,
                                                                               NULL,
                                                                               NULL -- Added by Roman W. 16/03/2020 INC0186641
                                                                               );
      l_custom_attributes(l_cust_attr_index).line_num := 101;
      l_custom_attributes(l_cust_attr_index).attribute_key := 'QUALIFIER|XX_OBJ|XX END CUSTOMER INDUSTRY';
      l_custom_attributes(l_cust_attr_index).attribute_value := p_input_rec.industry;
    
      l_cust_attr_index := l_cust_attr_index + 1;
    END IF;
    l_step := 'Step 05';
    l_custom_attributes.extend;
    l_custom_attributes(l_cust_attr_index) := xxqp_pricereq_custatt_rec_type(NULL,
                                                                             NULL,
                                                                             NULL,
                                                                             NULL,
                                                                             NULL,
                                                                             NULL,
                                                                             NULL,
                                                                             NULL,
                                                                             NULL,
                                                                             NULL, -- Added by Roman W. 16/03/2020 INC0186641
                                                                             NULL);
    l_custom_attributes(l_cust_attr_index).line_num := 101;
    l_custom_attributes(l_cust_attr_index).attribute_key := 'QUALIFIER|XX_OBJ|XX PROMOTIONAL';
    l_custom_attributes(l_cust_attr_index).attribute_value := 'N';
    l_step := 'Step 06';
    --dbms_output.put_line('In Call Pricing: '||p_input_rec.inventory_item_id);
  
    -- pricing engine call call for RESELLER
    IF p_indirect_pl IS NOT NULL THEN
      l_step := 'Step 06.1';
      xxqp_request_price_pkg.price_request(p_order_header       => l_order_header_r,
                                           p_item_lines         => l_order_lines,
                                           p_custom_attributes  => l_custom_attributes,
                                           p_pricing_phase      => 'LINE',
                                           p_debug_flag         => 'N',
                                           p_pricing_server     => 'FAILOVER',
                                           p_request_source     => 'STRATAFORCE',
                                           p_process_xtra_field => p_process_extra_field,
                                           x_session_details    => l_session_output_r,
                                           x_order_details      => l_order_output_r,
                                           x_line_details       => l_lines_output_r,
                                           x_modifier_details   => l_modifier_output_r,
                                           x_attribute_details  => l_attr_output_r,
                                           x_related_adjustment => l_rel_output_r,
                                           x_status             => l_status_r,
                                           x_status_message     => l_status_message_r);
    END IF;
    --dbms_output.put_line('In Call Pricing: Direct');
    l_step := 'Step 07';
    -- pricing engine call call for DIRECT
    IF p_direct_pl IS NOT NULL AND l_is_price_fetched_d = 'Y' THEN
      l_step := 'Step 07.1';
      l_order_lines(1).inventory_item_id := l_item_id_d; --CTASK0037204
      l_order_lines(1).item_uom := l_price_uom_d; --CTASK0037204
    
      xxqp_request_price_pkg.price_request(p_order_header       => l_order_header_d,
                                           p_item_lines         => l_order_lines,
                                           p_custom_attributes  => l_custom_attributes,
                                           p_pricing_phase      => 'LINE',
                                           p_debug_flag         => 'N',
                                           p_pricing_server     => 'FAILOVER',
                                           p_request_source     => 'STRATAFORCE',
                                           p_process_xtra_field => p_process_extra_field,
                                           x_session_details    => l_session_output_d,
                                           x_order_details      => l_order_output_d,
                                           x_line_details       => l_lines_output_d,
                                           x_modifier_details   => l_modifier_output_d,
                                           x_attribute_details  => l_attr_output_d,
                                           x_related_adjustment => l_rel_output_d,
                                           x_status             => l_status_d,
                                           x_status_message     => l_status_message_d);
    
    ELSE
      l_status_d := 'SP01';
      l_step     := 'Step 07.2';
    END IF;
  
    --commit;
    l_step := 'Step 08';
    IF l_status_r <> 'SP01' AND p_indirect_pl IS NOT NULL THEN
      l_status         := 'E';
      l_status_message := l_status_message ||
                          'PRICING ERROR: Reseller Pricing: ' ||
                          l_status_message_r || chr(13);
    END IF;
    l_step := 'Step 09';
    IF l_status_d <> 'SP01' AND p_direct_pl IS NOT NULL THEN
      l_status         := 'E';
      l_status_message := l_status_message ||
                          'PRICING ERROR: Direct Pricing: ' ||
                          l_status_message_d || chr(13);
    END IF;
    l_step := 'Step 10';
    --fnd_file.put_line(fnd_file.log,
    --          'PRICE Output Count: ' || l_lines_output_r.count || ' ' ||
    --          l_lines_output_d.count);
    l_step := 'Step 10.1';
    -- set output for reseller call
    IF l_lines_output_r IS NOT NULL AND l_lines_output_r.count > 0 THEN
      l_step := 'Step 10.2';
      FOR k IN 1 .. l_lines_output_r.count LOOP
        IF l_lines_output_r(k).line_num = 101 THEN
          l_output_rec.product_code   := xxinv_utils_pkg.get_item_segment(l_output_rec.inventory_item_id,
                                                                          xxinv_utils_pkg.get_master_organization_id);
          l_output_rec.product_name   := get_item_description(l_output_rec.inventory_item_id);
          l_output_rec.prod_long_desc := get_item_long_description(l_output_rec.inventory_item_id);
        
          l_output_rec.product_type := xxssys_oa2sf_util_pkg.get_product_type(NULL,
                                                                              l_output_rec.inventory_item_id);
        
          l_output_rec.reseller_price  := l_lines_output_r(k)
                                          .adj_unit_sales_price;
          l_output_rec.currency        := l_order_output_r(1).currency;
          l_output_rec.adjustment_info := l_lines_output_r(k)
                                          .adjustment_info;
        
          fnd_file.put_line(fnd_file.log,
                            'In Pricing Reseller: ' ||
                            l_output_rec.reseller_price);
        
        END IF;
      END LOOP;
    END IF;
    l_step := 'Step 11';
    -- set output for direct call
    IF l_lines_output_d IS NOT NULL AND l_lines_output_d.count > 0 THEN
      l_step := 'Step 11.1';
      FOR k IN 1 .. l_lines_output_d.count LOOP
        IF l_lines_output_d(k).line_num = 101 THEN
          IF l_output_rec.product_code IS NULL THEN
            l_output_rec.product_code   := xxinv_utils_pkg.get_item_segment(l_output_rec.inventory_item_id,
                                                                            xxinv_utils_pkg.get_master_organization_id);
            l_output_rec.product_name   := get_item_description(l_output_rec.inventory_item_id);
            l_output_rec.prod_long_desc := get_item_long_description(l_output_rec.inventory_item_id);
          
            l_output_rec.product_type    := xxssys_oa2sf_util_pkg.get_product_type(NULL,
                                                                                   l_output_rec.inventory_item_id);
            l_output_rec.currency        := l_order_output_d(1).currency;
            l_output_rec.adjustment_info := l_lines_output_d(k)
                                            .adjustment_info;
          END IF;
        
          l_output_rec.direct_price := l_lines_output_d(k)
                                       .adj_unit_sales_price;
        
          --fnd_file.put_line(fnd_file.log,
          --  'In Pricing Direct: ' ||
          --  l_output_rec.direct_price);
        END IF;
      END LOOP;
    END IF;
    l_step       := 'Step 12';
    x_output_rec := l_output_rec;
    x_status     := l_status;
    x_status_msg := l_status_message;
    l_step       := 'End Of Program';
  EXCEPTION
    WHEN OTHERS THEN
      x_output_rec := NULL;
      x_status     := 'E';
    
      x_status_msg := 'UNEXPECTED ERROR: In procedure call_pricing_api. ' ||
                      chr(13) || SQLERRM || '.' || chr(13) ||
                      'The Last step executed was :' || l_step || chr(13) ||
                      'Direct Price List Id:' || p_direct_pl || chr(13) ||
                      'Indirect Price List Id:' || p_indirect_pl || chr(13) ||
                      'Reseller Item Id:' || p_input_rec.inventory_item_id ||
                      chr(13) || 'Reseller Item UOM :' ||
                      p_input_rec.item_uom || chr(13) || 'Direct Item Id :' ||
                      l_item_id_d || chr(13) || 'Direct Item UOM :' ||
                      l_price_uom_d || chr(13) ||
                      'Indirect Price API Call Status :' || l_status_r ||
                      '    ,' || l_status_message_r || chr(13) ||
                      'Direct Price API Call Status   :' || l_status_d ||
                      '     ,' || l_status_message_d;
      --dbms_output.put_line(x_status_msg);
  END call_pricing_api;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0042196
  --          This program will check for all NEW price book generation events and perform following activities:
  --          1. Prepare valid item list as per filter conditions provided
  --          2. Call pricing API in LINE pricing mode with proper inputs
  --          3. Populate table XXQP_PRICEBOOK_DATA with pricing information against an event_id
  --          4. Call procedure  generate_pricebook_excel to generate Excel report with above table data
  --             and send same via email
  -- --------------------------------------------------------------------------------------------
  -- Calling Entity: Concurrent Program: XXQP Process PriceBookGeneration event
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  03/02/2018  Diptasurjya Chatterjee        Initial Build
  -- 1.1  07/06/2018  Diptasurjya Chatterjee        CTASK0037438 - Add extra filter conditions
  -- 1.2  27-Mar-2019 Diptasurjya Chatterjee        CHG0045417 - Pricebook date filter
  -- --------------------------------------------------------------------------------------------
  PROCEDURE generate_price_book_conc(errbuf                OUT VARCHAR2,
                                     retcode               OUT NUMBER,
                                     p_event_id            IN NUMBER,
                                     p_send_mail           IN VARCHAR2,
                                     p_email_address       IN VARCHAR2 DEFAULT NULL,
                                     p_process_extra_field IN VARCHAR2) IS
    l_sf_price_rec xxqp_sf_price_rec;
    l_sf_price_tab xxqp_sf_price_tab;
  
    --TYPE item_list IS TABLE OF NUMBER INDEX BY BINARY_INTEGER;
    TYPE item_list_rec IS RECORD(
      item_id NUMBER,
      uom     VARCHAR2(10)); --CTASK0037204
    TYPE item_list IS TABLE OF item_list_rec INDEX BY BINARY_INTEGER; --CTASK0037204
  
    l_item_list     item_list;
    l_item_list_cnt NUMBER := 1;
    l_msg           VARCHAR2(2000);
  
    l_validation_status  VARCHAR2(1);
    l_validation_message VARCHAR2(4000);
  
    l_direct_pl    NUMBER;
    l_indirect_pl  NUMBER;
    l_is_pl_direct VARCHAR2(1);
  
    l_operation_no NUMBER := 20;
  
    l_price_out xxqp_sf_price_rec;
  
    l_output_count NUMBER := 1;
  
    l_price_delete_status NUMBER;
    l_sfws_status         NUMBER;
    l_sfws_status_msg     VARCHAR2(4000);
  
    l_pricing_status  VARCHAR2(1);
    l_pricing_message VARCHAR2(4000);
  
    l_pb_report_status     VARCHAR2(10);
    l_pb_report_status_msg VARCHAR2(10);
  
    l_rel_prodfam_status VARCHAR2(1);
    l_rel_machine_status VARCHAR2(1);
  
    l_event_processed_count NUMBER := 0;
  
    l_pb_effective_date date; -- CHG0045417
  
    CURSOR event_cur IS
      SELECT *
        FROM xxssys_events
       WHERE status = 'NEW'
         AND entity_name = 'PRICE_BOOK_GEN'
         AND event_id = nvl(p_event_id, event_id);
  BEGIN
    retcode := 0;
  
    FOR event_rec IN event_cur LOOP
      BEGIN
        l_validation_message := NULL;
      
        --dbms_output.put_line('In Proc: 2: '||event_rec.event_id);
        xxssys_event_pkg.update_inprocess(event_rec.event_id);
        COMMIT;
      
        l_price_delete_status := delete_price(event_rec.event_id);
      
        IF l_price_delete_status = 1 THEN
          -- Call SOA WS to mark SFDC request as Error
          call_update_status_sfws(x_retcode      => l_sfws_status,
                                  x_errbuf       => l_sfws_status_msg,
                                  p_event_id     => event_rec.event_id,
                                  p_sourceref_id => event_rec.entity_code,
                                  p_in_status    => g_sf_stat_failure,
                                  p_err_message  => 'Unable to delete old price book temp data');
        
          IF l_sfws_status <> 0 THEN
            xxssys_event_pkg.update_error(p_event_id    => event_rec.event_id,
                                          p_err_message => 'ERROR: While deleting existing pricing data' ||
                                                           chr(13) ||
                                                           'ERROR: While calling Strataforce status update WS. ' ||
                                                           l_sfws_status_msg);
          ELSE
            xxssys_event_pkg.update_error(p_event_id    => event_rec.event_id,
                                          p_err_message => 'ERROR: While deleting existing pricing data');
          END IF;
        
          COMMIT;
        
          retcode := 2;
          errbuf  := 'WARNING';
        
          fnd_file.put_line(fnd_file.log,
                            'ERROR: While delete existing pricing data for event ID ' ||
                            event_rec.event_id);
        
          CONTINUE;
        END IF;
      
        l_event_processed_count := l_event_processed_count + 1;
      
        -- Call SOA WS to mark SFDC request as In-Process
        call_update_status_sfws(x_retcode      => l_sfws_status,
                                x_errbuf       => l_sfws_status_msg,
                                p_event_id     => event_rec.event_id,
                                p_sourceref_id => event_rec.entity_code,
                                p_in_status    => g_sf_stat_progress,
                                p_err_message  => NULL);
      
        IF l_sfws_status <> 0 THEN
          xxssys_event_pkg.update_error(p_event_id    => event_rec.event_id,
                                        p_err_message => 'ERROR: While calling Strataforce status update WS. ' ||
                                                         l_sfws_status_msg);
        
          COMMIT;
          retcode := 1;
          errbuf  := 'WARNING';
        
          CONTINUE;
        END IF;
      
        -- Validate received event data
        validate_data(event_rec.event_id,
                      l_validation_status,
                      l_validation_message);
      
        -- Fetch direct PL ID from passed reseller PL ID
        IF l_validation_status = 0 THEN
          BEGIN
            BEGIN
              SELECT decode(qld.direct_indirect, 'Direct', 'Y', 'N')
                INTO l_is_pl_direct
                FROM qp_list_headers_b qlh, qp_list_headers_b_dfv qld
               WHERE qlh.rowid = qld.row_id
                 AND qlh.list_header_id = event_rec.attribute1;
            EXCEPTION
              WHEN no_data_found THEN
                l_validation_status  := 2;
                l_validation_message := l_validation_message ||
                                        'ERROR: Direct/Indirect definition for provided PL is not present.';
            END;
          
            IF l_is_pl_direct = 'Y' THEN
              l_direct_pl   := event_rec.attribute1;
              l_indirect_pl := NULL;
            ELSE
              l_indirect_pl := event_rec.attribute1;
              l_direct_pl   := get_direct_pl(event_rec.attribute1);
              IF l_direct_pl = '' THEN
                l_direct_pl          := NULL;
                l_validation_status  := 2;
                l_validation_message := l_validation_message ||
                                        'ERROR: Direct PL not defined for provided PL' ||
                                        SQLERRM;
              END IF;
            END IF;
          
            IF l_direct_pl IS NULL AND l_indirect_pl IS NULL THEN
              l_validation_status  := 2;
              l_validation_message := l_validation_message ||
                                      'ERROR: Both Direct and Indirect PL cannot be blank. ';
            END IF;
          EXCEPTION
            WHEN OTHERS THEN
              l_validation_status  := 2;
              l_validation_message := l_validation_message ||
                                      'ERROR: While fetching Direct PL. ' ||
                                      SQLERRM;
          END;
        END IF;
      
        -- CHG0045417 start
        begin
          if event_rec.attribute10 is not null then
            l_pb_effective_date := to_date(event_rec.attribute10,
                                           'yyyy-mm-dd');
          else
            l_pb_effective_date := to_date('01-JAN-1900', 'dd-MON-rrrr');
          end if;
        exception
          when others then
            l_validation_status  := 2;
            l_validation_message := l_validation_message ||
                                    'ERROR: Pricing effective date format conversion error. ' ||
                                    substr(sqlerrm, 100);
        end;
        fnd_file.put_line(fnd_file.log,
                          'Effective Date: ' || l_pb_effective_date);
        -- CHG0045417 end
      
        IF l_validation_status <> 0 THEN
          -- Call SOA WS to mark SFDC request as Error
          call_update_status_sfws(x_retcode      => l_sfws_status,
                                  x_errbuf       => l_sfws_status_msg,
                                  p_event_id     => event_rec.event_id,
                                  p_sourceref_id => event_rec.entity_code,
                                  p_in_status    => g_sf_stat_failure,
                                  p_err_message  => l_validation_message);
        
          IF l_sfws_status <> 0 THEN
            xxssys_event_pkg.update_error(p_event_id    => event_rec.event_id,
                                          p_err_message => l_validation_message ||
                                                           chr(13) ||
                                                           'ERROR: While calling Strataforce status update WS. ' ||
                                                           l_sfws_status_msg);
          ELSE
            xxssys_event_pkg.update_error(p_event_id    => event_rec.event_id,
                                          p_err_message => l_validation_message);
          END IF;
        
          COMMIT;
        
          retcode := 1;
          errbuf  := 'WARNING';
        
          fnd_file.put_line(fnd_file.log,
                            'VALIDATION ERROR: For event ID ' ||
                            event_rec.event_id);
          fnd_file.put_line(fnd_file.log,
                            'VALIDATION ERROR MESSAGE: For event ID ' ||
                            event_rec.event_id || ' ' ||
                            l_validation_message);
        
          CONTINUE;
        END IF;
      
        -- Prepare item list
        fnd_file.put_line(fnd_file.log,
                          'Inventory Item Id          | Item Code         | UOM    |');
        fnd_file.put_line(fnd_file.log,
                          '---------------------------------------------------------');
      
        --dbms_output.put_line('In Proc: 3: before item filter');
        FOR item_rec IN (SELECT qll.product_attr_val_disp item_code,
                                qll.product_id, --, mck.concatenated_segments
                                qll.operand, -- CTASK0037438 add
                                xxinv_utils_pkg.get_category_segment(p_segment_name      => 'SEGMENT1',
                                                                     p_category_set_id   => 1100000221,
                                                                     p_inventory_item_id => qll.product_id) ph_cat_seg1, -- CTASK0037438 add
                                qll.product_uom_code --Added on CTASK0037204
                           FROM qp_list_lines_v qll
                          WHERE qll.list_header_id = event_rec.attribute1
                            AND qll.product_attr_value <> 'ALL'
                            AND trunc(SYSDATE) BETWEEN
                                nvl(qll.start_date_active, SYSDATE - 1) AND
                                nvl(qll.end_date_active, SYSDATE + 1)
                            AND is_visible_in_pb(qll.product_id) = 'Y'
                            AND l_pb_effective_date <=
                                nvl(qll.start_date_active,
                                    to_date('01-JAN-1900', 'dd-MON-rrrr')) -- CHG0045417
                         --AND qll.product_attr_val_disp = '10007800-S'
                         --and rownum = 1
                         ) LOOP
          --  fnd_file.put_line(fnd_file.log,
          --    '-->Checking item id= ' || item_rec.product_id);
        
          -- CTASK0037438 Exclude item if list price=0 and Product Hierarchy category
          -- Line of Business segment is not Customer Support
          IF item_rec.operand = 0 AND
             item_rec.ph_cat_seg1 <> 'Customer Support' THEN
            CONTINUE;
          END IF;
        
          -- Check if item is eligible as per provided product family filter
          IF event_rec.attribute7 IS NOT NULL THEN
            IF is_eligible_per_prodfam(item_rec.item_code,
                                       event_rec.attribute7) = 'Y' THEN
              l_rel_prodfam_status := 'Y';
            ELSE
              l_rel_prodfam_status := 'N';
            END IF;
          END IF;
        
          -- If item not eligible as per product family filter
          -- Check if item is eligible as per provided related machine filter
          IF nvl(l_rel_prodfam_status, 'N') = 'N' THEN
            IF event_rec.attribute6 IS NOT NULL THEN
              IF is_eligible_per_machine(item_rec.product_id,
                                         event_rec.attribute6) = 'Y' THEN
                l_rel_machine_status := 'Y';
              ELSE
                l_rel_machine_status := 'N';
              END IF;
            END IF;
          END IF;
        
          -- If no filters provided then product is eligible
          IF event_rec.attribute7 IS NULL AND event_rec.attribute6 IS NULL THEN
            l_rel_prodfam_status := 'Y';
          END IF;
        
          IF l_rel_prodfam_status = 'Y' OR l_rel_machine_status = 'Y' THEN
            fnd_file.put_line(fnd_file.log,
                              ' ' || rpad(item_rec.product_id, 26) || '| ' ||
                              rpad(item_rec.item_code, 18) || '| ' ||
                              rpad(item_rec.product_uom_code, 7) || '|');
            --fnd_file.put_line(fnd_file.log,
            --  '-->Adding item id= ' || item_rec.product_id);
          
            l_item_list(l_item_list_cnt).item_id := item_rec.product_id; --CTASK0037204
            l_item_list(l_item_list_cnt).uom := item_rec.product_uom_code; --CTASK0037204
            l_item_list_cnt := l_item_list_cnt + 1;
          END IF;
        END LOOP;
      
        --dbms_output.put_line('In Proc: 3: after item filter '||l_item_list.count);
      
        FOR i IN 1 .. l_item_list.count LOOP
          --dbms_output.put_line('In Proc: 4: after item filter '||l_item_list(i));
          -- Prepare the pricing call input
          l_sf_price_rec.event_id            := event_rec.event_id;
          l_sf_price_rec.list_header_id      := event_rec.attribute1;
          l_sf_price_rec.account_number      := event_rec.attribute2;
          l_sf_price_rec.email_address       := event_rec.attribute3;
          l_sf_price_rec.end_cust_acct_num   := event_rec.attribute4;
          l_sf_price_rec.industry            := event_rec.attribute5;
          l_sf_price_rec.related_to_machine  := event_rec.attribute6;
          l_sf_price_rec.related_to_prod_fam := event_rec.attribute7;
          l_sf_price_rec.currency            := event_rec.attribute8;
          l_sf_price_rec.org_id              := event_rec.attribute9;
          l_sf_price_rec.operation_no        := l_operation_no; -- Constant 20
          l_sf_price_rec.item_uom            := l_item_list(i).uom; --CTASK0037204
        
          l_sf_price_rec.inventory_item_id := l_item_list(i).item_id; --CTASK0037204
          l_pricing_status                 := NULL;
          call_pricing_api(l_sf_price_rec,
                           l_direct_pl,
                           l_indirect_pl,
                           p_process_extra_field,
                           l_price_out,
                           l_pricing_status,
                           l_pricing_message);
        
          IF l_pricing_status = 'E' THEN
            xxssys_event_pkg.update_error(p_event_id    => event_rec.event_id,
                                          p_err_message => l_pricing_message);
            COMMIT;
            -- Call SOA WS to mark SFDC request as Error
            call_update_status_sfws(x_retcode      => l_sfws_status,
                                    x_errbuf       => l_sfws_status_msg,
                                    p_event_id     => event_rec.event_id,
                                    p_sourceref_id => event_rec.entity_code,
                                    p_in_status    => g_sf_stat_failure,
                                    p_err_message  => l_pricing_message);
          
            IF l_sfws_status <> 0 THEN
              fnd_file.put_line(fnd_file.log,
                                'PRICING ERROR: For event ID ' ||
                                event_rec.event_id ||
                                ' SF Status Update failed: ' ||
                                l_sfws_status_msg);
              xxssys_event_pkg.update_error(p_event_id    => event_rec.event_id,
                                            p_err_message => l_pricing_message ||
                                                             chr(13) ||
                                                             'ERROR: While calling Strataforce status update WS. ' ||
                                                             l_sfws_status_msg);
            ELSE
              xxssys_event_pkg.update_error(p_event_id    => event_rec.event_id,
                                            p_err_message => l_pricing_message);
            END IF;
          
            COMMIT;
            retcode := 1;
            errbuf  := 'WARNING';
          
            fnd_file.put_line(fnd_file.log,
                              'PRICING ERROR: For event ID ' ||
                              event_rec.event_id || ' ERROR Messge: ' ||
                              l_pricing_message);
          
            EXIT;
          END IF;
        
          l_sf_price_tab(l_output_count) := l_price_out;
        
          l_output_count := l_output_count + 1;
        END LOOP;
      
        --
      
        /*   if retcode =1 then
        continue
        end if;*/
      
        -- Populate Prices in the Pricing Table
        IF retcode = 0 THEN
          BEGIN
            populate_price(l_sf_price_tab);
          EXCEPTION
            WHEN OTHERS THEN
              xxssys_event_pkg.update_error(p_event_id    => event_rec.event_id,
                                            p_err_message => 'ERROR: While inserting pricing data. ' ||
                                                             SQLERRM || ' ' ||
                                                             l_sfws_status_msg);
              COMMIT;
              call_update_status_sfws(x_retcode      => l_sfws_status,
                                      x_errbuf       => l_sfws_status_msg,
                                      p_event_id     => event_rec.event_id,
                                      p_sourceref_id => event_rec.entity_code,
                                      p_in_status    => g_sf_stat_failure,
                                      p_err_message  => 'ERROR: While inserting pricing data. ' ||
                                                        SQLERRM || ' ' ||
                                                        l_sfws_status_msg);
            
              fnd_file.put_line(fnd_file.log,
                                'ERROR: While inserting pricing data. ' ||
                                SQLERRM || ' ' || l_sfws_status_msg);
            
              retcode := 1;
              errbuf  := 'WARNING';
            
              CONTINUE;
          END;
        
          --Call the XML Publisher Report to generate the Price Book excel
          generate_pricebook_excel(l_pb_report_status,
                                   l_pb_report_status_msg,
                                   event_rec.event_id,
                                   p_send_mail,
                                   REPLACE(p_email_address, '~'), -- yuval add replace : due to soa limitation
                                   p_process_extra_field);
        
          IF l_pb_report_status = 'SUCCESS' THEN
            xxssys_event_pkg.update_success(p_event_id => event_rec.event_id);
            -- Call SOA WS to mark SFDC request as Success
            call_update_status_sfws(x_retcode      => l_sfws_status,
                                    x_errbuf       => l_sfws_status_msg,
                                    p_event_id     => event_rec.event_id,
                                    p_sourceref_id => event_rec.entity_code,
                                    p_in_status    => g_sf_stat_success,
                                    p_err_message  => NULL);
          
            IF l_sfws_status <> 0 THEN
              xxssys_event_pkg.update_error(p_event_id    => event_rec.event_id,
                                            p_err_message => 'ERROR: While calling Strataforce status update WS. ' ||
                                                             l_sfws_status_msg);
              retcode := 1;
              errbuf  := 'WARNING';
            END IF;
          ELSE
          
            xxssys_event_pkg.update_error(p_event_id    => event_rec.event_id,
                                          p_err_message => 'ERROR: While generating Price book report. ' ||
                                                           l_pb_report_status_msg || ' ' ||
                                                           l_sfws_status_msg);
          
            COMMIT;
            fnd_file.put_line(fnd_file.log,
                              'REPORT GENERATION ERROR: For event ID ' ||
                              event_rec.event_id || ' ERROR Message: ' ||
                              l_pb_report_status_msg);
          
            -- Call SOA WS to mark SFDC request as Failure
            call_update_status_sfws(x_retcode      => l_sfws_status,
                                    x_errbuf       => l_sfws_status_msg,
                                    p_event_id     => event_rec.event_id,
                                    p_sourceref_id => event_rec.entity_code,
                                    p_in_status    => g_sf_stat_failure,
                                    p_err_message  => 'ERROR: While generating Price book report. ' ||
                                                      l_pb_report_status_msg || ' ' ||
                                                      l_sfws_status_msg);
          
            retcode := 1;
            errbuf  := 'WARNING';
          END IF;
        END IF;
        COMMIT;
      
      EXCEPTION
        WHEN OTHERS THEN
          ROLLBACK;
          xxssys_event_pkg.update_error(p_event_id    => event_rec.event_id,
                                        p_err_message => 'ERROR: While generating Price book report. ' ||
                                                         substr(SQLERRM,
                                                                1,
                                                                200));
          COMMIT;
          fnd_file.put_line(fnd_file.log,
                            'ERROR: While generating price book in procedure XXQP_PRICE_BOOK_PKG.generate_price_book_conc. ' ||
                            substr(SQLERRM, 1, 200));
          -- Call SOA WS to mark SFDC request as Failure
          call_update_status_sfws(x_retcode      => l_sfws_status,
                                  x_errbuf       => l_sfws_status_msg,
                                  p_event_id     => event_rec.event_id,
                                  p_sourceref_id => event_rec.entity_code,
                                  p_in_status    => g_sf_stat_failure,
                                  p_err_message  => 'ERROR: While generating Price book report. ' ||
                                                    substr(SQLERRM, 1, 200));
        
          retcode := 1;
          errbuf  := 'WARNING';
      END;
    END LOOP;
  
    IF l_event_processed_count = 0 THEN
      fnd_file.put_line(fnd_file.log,
                        'No NEW events were found for price book generation');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      retcode := 2;
      errbuf  := 'ERROR';
      ROLLBACK;
    
      fnd_file.put_line(fnd_file.log,
                        'ERROR: While generating price book in procedure XXQP_PRICE_BOOK_PKG.generate_price_book_conc. ' ||
                        substr(SQLERRM, 1, 200));
    
  END generate_price_book_conc;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0042196 - is_valid_request
  -- called by soa to ensure no duplicate request inserted during proccesing pricebook
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                            Description
  -- 1.0  23/02/2018  Yuval tal                       CHG0042196 - Initial Build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE is_ready2process(p_source_name VARCHAR2,
                             p_entity_code VARCHAR2,
                             p_err_code    OUT VARCHAR2,
                             p_err_message OUT VARCHAR2) IS
  BEGIN
  
    p_err_code    := 'S';
    p_err_message := NULL;
  
  END;

END xxqp_price_book_pkg;
/
