CREATE OR REPLACE PACKAGE BODY xxecomm_interface_pkg IS

  --------------------------------------------------------------------
  --  name:            XXECOMM_INTERFACE_PKG
  --  create by:       Dalit A. Raviv
  --  Revision:        1.1
  --  creation date:   12/06/2013 14:46:24
  --------------------------------------------------------------------
  --  purpose :        CUST674 - eCommerce Integration
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  12/06/2013  Dalit A. Raviv    initial build
  --  1.1  25/12/2013  yuval tal         CR 1083 : modify main procudure 
  --------------------------------------------------------------------

  g_bpel_host VARCHAR2(300) := xxobjt_bpel_utils_pkg.get_bpel_host;
  g_jndi_name VARCHAR2(50) := xxobjt_bpel_utils_pkg.get_jndi_name(NULL);
  --g_jndi_data_source varchar2(50)  := xxobjt_bpel_utils_pkg.get_jndi_data_source;
  g_ecomm_user     VARCHAR2(200);
  g_ecomm_password VARCHAR2(200);
  g_end_point_url  VARCHAR2(2000);

  --------------------------------------------------------------------
  --  name:            set_env_param
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   12/06/2013 14:46:24
  --------------------------------------------------------------------
  --  purpose :        CUST674 - eCommerce Integration
  --                   from profile set the environment parameters to send to BPEL
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  12/06/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE set_env_param IS
  
    l_env VARCHAR2(10);
  
  BEGIN
  
    l_env := xxagile_util_pkg.get_bpel_domain;
  
    CASE
      WHEN l_env = 'production' THEN
      
        g_ecomm_user     := fnd_profile.value('XXECOM_USER_PROD');
        g_ecomm_password := fnd_profile.value('XXECOM_PASSWORD_PROD');
        g_end_point_url  := fnd_profile.value('XXECOM_ENDPOINT_URL_PROD');
      WHEN l_env = 'default' THEN
      
        g_ecomm_user     := fnd_profile.value('XXECOM_USER_TEST');
        g_ecomm_password := fnd_profile.value('XXECOM_PASSWORD_TEST');
        g_end_point_url  := fnd_profile.value('XXECOM_ENDPOINT_URL_TEST');
      ELSE
        g_ecomm_user     := fnd_profile.value('XXECOM_USER_TEST');
        g_ecomm_password := fnd_profile.value('XXECOM_PASSWORD_TEST');
        g_end_point_url  := fnd_profile.value('XXECOM_ENDPOINT_URL_TEST');
    END CASE;
  
  END set_env_param;

  --------------------------------------------------------------------
  --  name:            submit_Ecomm_bpel
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   12/06/2013 14:46:24
  --------------------------------------------------------------------
  --  purpose :        CUST674 - eCommerce Integration
  --                   from profile set the environment parameters to send to BPEL
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  12/06/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE submit_ecomm_bpel(errbuf  OUT VARCHAR2,
                              retcode OUT VARCHAR2,
                              p_type  IN VARCHAR2,
                              --p_fetch_size     in  number,
                              p_days_back IN VARCHAR2,
                              p_active_yn IN VARCHAR2,
                              p_ou_id     IN NUMBER,
                              p_from_seq  IN NUMBER,
                              p_to_seq    IN NUMBER) IS
  
    service_            sys.utl_dbws.service;
    call_               sys.utl_dbws.call;
    service_qname       sys.utl_dbws.qname;
    response            sys.xmltype;
    request             sys.xmltype;
    l_string_type_qname sys.utl_dbws.qname;
    -- response
    l_response_err_code         NUMBER;
    l_response_err_message      VARCHAR2(3000);
    l_response_bpel_instance_id VARCHAR2(3000);
    l_response_refreshsucceeded VARCHAR2(3000);
  
  BEGIN
    errbuf  := NULL;
    retcode := 0;
    set_env_param;
  
    -- call bpel
    service_qname       := sys.utl_dbws.to_qname('http://xmlns.oracle.com/xxEcommerceOUT',
                                                 'xxEcommerceOUT');
    l_string_type_qname := sys.utl_dbws.to_qname('http://www.w3.org/2001/XMLSchema',
                                                 'string');
    service_            := sys.utl_dbws.create_service(service_qname);
  
    call_ := sys.utl_dbws.create_call(service_);
    --dbms_output.put_line(g_bpel_host || xxagile_util_pkg.get_bpel_domain ||'/xxEcommerceOUT/1.0');
  
    sys.utl_dbws.set_target_endpoint_address(call_,
                                             g_bpel_host ||
                                             xxagile_util_pkg.get_bpel_domain ||
                                             '/xxEcommerceOUT/1.0');
    sys.utl_dbws.set_property(call_, 'SOAPACTION_USE', 'TRUE');
    sys.utl_dbws.set_property(call_, 'SOAPACTION_URI', 'process');
    sys.utl_dbws.set_property(call_, 'OPERATION_STYLE', 'document');
    sys.utl_dbws.set_property(call_,
                              'ENCODINGSTYLE_URI',
                              'http://schemas.xmlsoap.org/soap/encoding/');
    sys.utl_dbws.set_return_type(call_, l_string_type_qname);
    -- Set input parameters
    request := sys.xmltype('<ns1:xxEcommerceOUTProcessRequest xmlns:ns1="http://xmlns.oracle.com/xxEcommerceOUT">' ||
                           '<ns1:request_type>' || p_type ||
                           '</ns1:request_type>' || '<ns1:jndi_db_name>' ||
                           g_jndi_name || '</ns1:jndi_db_name>' ||
                           '<ns1:end_point_url>' || g_end_point_url ||
                           '</ns1:end_point_url>' || '<ns1:eComm_user>' ||
                           g_ecomm_user || '</ns1:eComm_user>' ||
                           '<ns1:eComm_pass>' || g_ecomm_password ||
                           '</ns1:eComm_pass>' || '<ns1:from_seq>' ||
                           p_from_seq || '</ns1:from_seq>' ||
                           '<ns1:to_seq>' || p_to_seq || '</ns1:to_seq>' ||
                           '<ns1:Active_YN>' || p_active_yn ||
                           '</ns1:Active_YN>' || '<ns1:OU_id>' || p_ou_id ||
                           '</ns1:OU_id>' || '<ns1:Days_Back>' ||
                           p_days_back || '</ns1:Days_Back>' ||
                           '</ns1:xxEcommerceOUTProcessRequest>');
  
    --dbms_output.put_line('g_jndi_name '||g_jndi_name);                                
    --dbms_output.put_line('g_end_point_url '||g_end_point_url);
    --dbms_output.put_line('g_ecomm_user '||g_ecomm_user);
    --dbms_output.put_line('g_ecomm_password '||g_ecomm_password);
    --dbms_output.put_line('p_from_seq '||p_from_seq);
    --dbms_output.put_line('p_to_seq '||p_to_seq);
    --dbms_output.put_line('p_active_YN '||p_active_YN);
    --dbms_output.put_line('p_ou_id '||p_ou_id);
    --dbms_output.put_line('p_days_back '||p_days_back);
  
    response := sys.utl_dbws.invoke(call_, request);
  
    -- parse bpel response                              
    l_response_bpel_instance_id := response.extract('//xxEcommerceOUTProcessResponse/bpel_instance_id/text()','xmlns="http://xmlns.oracle.com/xxEcommerceOUT"')
                                   .getstringval();
    l_response_err_message      := response.extract('//xxEcommerceOUTProcessResponse/err_message/text()','xmlns="http://xmlns.oracle.com/xxEcommerceOUT"')
                                   .getstringval();
    l_response_err_code         := response.extract('//xxEcommerceOUTProcessResponse/err_code/text()','xmlns="http://xmlns.oracle.com/xxEcommerceOUT"')
                                   .getstringval();
    l_response_refreshsucceeded := response.extract('//xxEcommerceOUTProcessResponse/RefreshSucceeded/text()','xmlns="http://xmlns.oracle.com/xxEcommerceOUT"')
                                   .getstringval();
  
    fnd_file.put_line(fnd_file.log,
                      'Bpel Instance Id: ' || l_response_bpel_instance_id);
    fnd_file.put_line(fnd_file.log,
                      'Err Message: ' || l_response_err_message);
    fnd_file.put_line(fnd_file.log, 'Err Code: ' || l_response_err_code);
    fnd_file.put_line(fnd_file.log,
                      'Return Status: ' || l_response_refreshsucceeded);
    --dbms_output.put_line('Bpel Instance Id: ' || l_response_bpel_instance_id); 
    --dbms_output.put_line('Err Code: ' || l_response_err_code); 
    --dbms_output.put_line('Err Message: ' || l_response_err_message); 
    --dbms_output.put_line('Return Status: ' || l_response_err_code); 
  
    -- update response
    IF l_response_err_code <> 0 OR l_response_refreshsucceeded = 'false' THEN
      fnd_file.put_line(fnd_file.log,
                        'Status: ' || l_response_refreshsucceeded);
      errbuf  := 'Failed run Bpel - ' || l_response_err_message;
      retcode := 2;
    END IF;
    -- 
  
    sys.utl_dbws.release_call(call_);
    sys.utl_dbws.release_service(service_);
    --sys.UTL_DBWS.RELEASE_ALL_SERVICES;
    --  dbms_lock.sleep(5);
  
  EXCEPTION
    WHEN OTHERS THEN
      dbms_output.put_line('7');
      retcode := 2;
      errbuf  := substr(SQLERRM, 1, 255);
      fnd_file.put_line(fnd_file.log, 'gen error: ' || errbuf);
    
  END submit_ecomm_bpel;

  --------------------------------------------------------------------
  --  name:            main
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   16/06/2013 14:46:24
  --------------------------------------------------------------------
  --  purpose :        CUST674 - eCommerce Integration
  --                   main program that by loop will call to BPEL.
  --                   otherwise we get memory problem.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  16/06/2013  Dalit A. Raviv    initial build
  --  1.1  25/12/2013  yuval tal         CR 1083 : remove p_ou_id IS NULL from select count (*) condition  
  --------------------------------------------------------------------
  PROCEDURE main(errbuf       OUT VARCHAR2,
                 retcode      OUT VARCHAR2,
                 p_type       IN VARCHAR2,
                 p_fetch_size IN NUMBER,
                 p_days_back  IN VARCHAR2,
                 p_active_yn  IN VARCHAR2,
                 p_ou_id      IN NUMBER) IS
  
    l_count      NUMBER;
    l_from_seq   NUMBER := NULL;
    l_to_seq     NUMBER := NULL;
    l_fetch_size NUMBER;
    l_max_loops  NUMBER;
    l_request_id NUMBER := NULL;
    --l_error_flag   boolean       := FALSE;
    l_phase       VARCHAR2(100);
    l_status      VARCHAR2(100);
    l_dev_phase   VARCHAR2(100);
    l_dev_status  VARCHAR2(100);
    l_message     VARCHAR2(100);
    l_return_bool BOOLEAN;
    --l_exit         varchar2(5);
    --l_status_code  varchar2(5);
  
    gen_exception EXCEPTION;
  BEGIN
    --
    errbuf  := NULL;
    retcode := 0;
  
    --fnd_global.APPS_INITIALIZE(user_id => 2470,resp_id => 20420,resp_appl_id => 1);
    -- log 
    fnd_file.put_line(fnd_file.log,
                      ' ----------------- eCommerce Integration -----------------');
    fnd_file.put_line(fnd_file.log, 'Type:' || p_type);
    fnd_file.put_line(fnd_file.log, 'Fetch Size:' || p_fetch_size);
    fnd_file.put_line(fnd_file.log, 'Number of days:' || p_days_back);
    fnd_file.put_line(fnd_file.log, 'Active Y/N:' || p_active_yn);
    fnd_file.put_line(fnd_file.log, 'Operating Unit:' || p_ou_id);
    /*dbms_output.put_line('Type:' || p_type); 
    dbms_output.put_line('Fetch Size:' || P_Fetch_Size);
    dbms_output.put_line('Number of days:' || p_days_back);
    dbms_output.put_line('Active Y/N:' || p_active_YN);*/
  
    -- check if there are raws to transfer
    SELECT COUNT(*)
      INTO l_count
      FROM xxecomm_customer_details_v a
     WHERE a.last_update_date > SYSDATE - p_days_back
       AND ((a.is_active = 'true' AND p_active_yn = 'Y') OR
           p_active_yn IS NULL)
          
       AND a.operating_unit_id = p_ou_id /* OR p_ou_id IS NULL)*/  --  1.1  25/12/2013  yuval tal 
    ;
  
    fnd_file.put_line(fnd_file.log,
                      'Number of rows to process:' || l_count);
  
    IF l_count > 0 THEN
      l_fetch_size := p_fetch_size;
      l_max_loops  := ceil(l_count / l_fetch_size); -- ceil round the number allways up
      l_from_seq   := 1;
      l_to_seq     := l_fetch_size;
      --l_exit       := 'N';
      -- by loop call BPEL 
      FOR i IN 1 .. l_max_loops LOOP
        dbms_output.put_line('l_from_seq ' || l_from_seq);
        dbms_output.put_line('l_to_seq ' || l_to_seq);
        fnd_file.put_line(fnd_file.log, 'l_from_seq ' || l_from_seq);
        fnd_file.put_line(fnd_file.log, 'l_to_seq ' || l_to_seq);
        -- call submit_Ecomm_bpel
        COMMIT;
        l_request_id := fnd_request.submit_request(application => 'XXOBJT',
                                                   program     => 'XXECOMMCUST',
                                                   description => NULL,
                                                   start_time  => NULL,
                                                   sub_request => FALSE,
                                                   argument1   => p_type,
                                                   argument2   => p_days_back,
                                                   argument3   => p_active_yn,
                                                   argument4   => p_ou_id,
                                                   argument5   => l_from_seq,
                                                   argument6   => l_to_seq);
        -- must commit the request
        COMMIT;
      
        IF l_request_id = 0 THEN
          fnd_file.put_line(fnd_file.log, 'Failed to call bpel -----');
          fnd_file.put_line(fnd_file.log, 'Err - ' || SQLERRM);
          errbuf  := 'Failed to call bpel';
          retcode := 2;
          RAISE gen_exception;
        END IF;
      
        IF l_request_id > 0 THEN
          LOOP
            l_return_bool := fnd_concurrent.wait_for_request(l_request_id,
                                                             10,
                                                             0,
                                                             l_phase,
                                                             l_status,
                                                             l_dev_phase,
                                                             l_dev_status,
                                                             l_message);
          
            dbms_output.put_line('phase = ' || l_phase || ' status = ' ||
                                 l_status);
            EXIT WHEN upper(l_phase) = 'COMPLETED' OR upper(l_status) IN('CANCELLED',
                                                                         'ERROR',
                                                                         'TERMINATED');
          END LOOP;
        
          IF upper(l_phase) = 'COMPLETED' AND upper(l_status) <> 'NORMAL' THEN
            dbms_output.put_line('The XXXX Import program completed in error. Oracle request id');
            dbms_output.put_line(substr(SQLERRM, 1, 255));
            errbuf  := 'Request finished in error or warrning';
            retcode := 2;
            fnd_file.put_line(fnd_file.log,
                              'Request finished in error or warrning, submit_Ecomm_bpel returned with error - ' ||
                              l_message);
            --raise gen_exception;
          END IF; -- l_phase
        END IF; -- l_request_id 
      
        l_request_id  := NULL;
        l_phase       := NULL;
        l_status      := NULL;
        l_dev_phase   := NULL;
        l_dev_status  := NULL;
        l_message     := NULL;
        l_return_bool := NULL;
      
        l_from_seq := l_from_seq + l_fetch_size;
        l_to_seq   := l_to_seq + l_fetch_size;
        -- do not take out
        -- it needed for the bpel otherwise it return with false
        -- the program can run with batches of 100, 200, 300, 400 and sleep of 2 !!!!!!!!
        dbms_lock.sleep(2);
      END LOOP;
    END IF;
  
  EXCEPTION
    WHEN gen_exception THEN
      NULL;
    WHEN OTHERS THEN
      retcode := 2;
      errbuf  := substr(SQLERRM, 1, 255);
      fnd_file.put_line(fnd_file.log, 'gen error: ' || errbuf);
  END main;

/*FUNCTION is_ship_site_exists(p_cust_number VARCHAR2) RETURN VARCHAR2 IS
  
    l_tmp VARCHAR2(5);
  BEGIN
  
    SELECT 'true'
      INTO l_tmp
      FROM xxecomm_customer_shipping_v sh
     WHERE sh.cust_num = p_cust_number
       AND sh.status = 'A'
       AND rownum = 1;
  
    RETURN l_tmp;
  
  EXCEPTION
    WHEN no_data_found THEN
      RETURN 'false';
  END;*/
END xxecomm_interface_pkg;
/
