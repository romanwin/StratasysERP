CREATE OR REPLACE PACKAGE BODY xxcs_salesforce_utils_pkg IS
  --------------------------------------------------------------------
  --  customization code: CUST276 - Salesforce
  --  name:               xxcs_salesforce_utils_pkg
  --  create by:          ELLA.MALCHI
  --  $Revision:          1.0 $
  --  creation date:      23/04/2010
  --  Purpose :           Salceforce Integration
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   23/04/2010    ELLA.MALCHI     initial build
  -----------------------------------------------------------------------

  --------------------------------------------------------------------
  --  customization code: CUST276 - Salesforce
  --  name:               initiate_rates_process
  --  create by:          ELLA.MALCHI
  --  $Revision:          1.0 $
  --  creation date:      23/04/2010
  --  Purpose :           Salceforce Integration
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   23/04/2010    ELLA.MALCHI     initial build
  --  1.1   08/08/2010    Dalit A. Raviv  when finished with error 
  --                                      send mail notification to Roman
  --  1.2  5.7.11       YUVAL TAL         add dyn env param to bpel
  -----------------------------------------------------------------------
  PROCEDURE initiate_rates_process(errbuf OUT VARCHAR2, retcode OUT NUMBER) IS
  
    service_            sys.utl_dbws.service;
    call_               sys.utl_dbws.CALL;
    service_qname       sys.utl_dbws.qname;
    response            sys.xmltype;
    request             sys.xmltype;
    v_string_type_qname sys.utl_dbws.qname;
    v_message           VARCHAR2(1000);
    l_response_msg      VARCHAR2(100);
    l_response_pos      NUMBER := 0;
  
    -- Dalit A. Raviv 08/08/2010  
    l_to_person   VARCHAR2(100) := NULL;
    l_sender_name VARCHAR2(240) := 'OracleApps_NoReply@objet.com';
    l_html_str    VARCHAR2(500) := NULL;
    l_error_desc  VARCHAR2(2000) := NULL;
    l_error_code  VARCHAR2(2000) := NULL;
  
    l_err_code         VARCHAR2(100) := NULL;
    l_err_msg          VARCHAR2(2500) := NULL;
    l_env              VARCHAR2(20) := NULL;
    l_user             VARCHAR2(150) := NULL;
    l_password         VARCHAR2(150) := NULL;
    l_jndi_name        VARCHAR2(150) := NULL;
    l_endpoint_service VARCHAR2(150) := NULL;
    l_endpoint_login   VARCHAR2(150) := NULL;
  
  BEGIN
  
    xxobjt_bpel_utils_pkg.get_sf_login_params(p_user_name        => l_user, -- o v
                                              p_password         => l_password, -- o v
                                              p_env              => l_env, -- o v
                                              p_jndi_name        => l_jndi_name, -- o v
                                              p_endpoint_service => l_endpoint_service, -- o v
                                              p_endpoint_login   => l_endpoint_login, -- o v
                                              p_err_code         => l_err_code, -- o v
                                              p_err_msg          => l_err_msg);
  
    service_qname       := sys.utl_dbws.to_qname('http://xmlns.oracle.com/xxUpdateSalesforceRates',
                                                 'xxUpdateSalesforceRates');
    v_string_type_qname := sys.utl_dbws.to_qname('http://www.w3.org/2001/XMLSchema',
                                                 'string');
    service_            := sys.utl_dbws.create_service(service_qname);
    call_               := sys.utl_dbws.create_call(service_);
    sys.utl_dbws.set_target_endpoint_address(call_,
                                             'http://soaprodapps.2objet.com:7777/orabpel/' ||
                                             xxagile_util_pkg.get_bpel_domain ||
                                             '/xxUpdateSalesforceRates/1.0');
  
    sys.utl_dbws.set_property(call_, 'SOAPACTION_USE', 'TRUE');
    sys.utl_dbws.set_property(call_, 'SOAPACTION_URI', 'process');
    sys.utl_dbws.set_property(call_, 'OPERATION_STYLE', 'document');
    sys.utl_dbws.set_property(call_,
                              'ENCODINGSTYLE_URI',
                              'http://schemas.xmlsoap.org/soap/encoding/');
  
    sys.utl_dbws.set_return_type(call_, v_string_type_qname);
  
    -- Set the input
  
    /*   request := sys.xmltype('<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
        <soap:Body xmlns:ns1="http://xmlns.oracle.com/xxUpdateSalesforceRates">
            <ns1:xxUpdateSalesforceRatesProcessRequest>' ||
                               '<ns1:user>' || l_user || '</ns1:user>' ||
                               '<ns1:pass>' || l_password || '</ns1:pass>' ||
                               '<ns1:jndi_name>' || l_jndi_name ||
                               '</ns1:jndi_name>' || '<ns1:endpoint_login_url>' ||
                               l_endpoint_login || '</ns1:endpoint_login_url>' ||
                               '</ns1:xxUpdateSalesforceRatesProcessRequest>
        </soap:Body>
    </soap:Envelope>
    ');
    */
    request := sys.xmltype('<ns1:xxUpdateSalesforceRatesProcessRequest xmlns:ns1="http://xmlns.oracle.com/xxUpdateSalesforceRates">' ||
                           '<ns1:user>' || l_user || '</ns1:user>' ||
                           '<ns1:pass>' || l_password || '</ns1:pass>' ||
                           '<ns1:jndi_name>' || l_jndi_name ||
                           '</ns1:jndi_name>' || '<ns1:endpoint_login_url>' ||
                           l_endpoint_login || '</ns1:endpoint_login_url>' ||
                           '</ns1:xxUpdateSalesforceRatesProcessRequest>');
  
    response := sys.utl_dbws.invoke(call_, request);
    sys.utl_dbws.release_call(call_);
    sys.utl_dbws.release_service(service_);
    v_message := response.getstringval();
  
    l_response_pos := instr(v_message, '<result>') + 8;
    l_response_msg := substr(v_message,
                             l_response_pos,
                             instr(v_message, '</result>') - l_response_pos);
  
    fnd_file.put_line(fnd_file.log, l_response_msg);
  
    IF l_response_msg LIKE '%Error%' THEN
    
      retcode        := 2;
      errbuf         := l_response_msg;
      l_response_msg := substr(l_response_msg, 1, 245);
      -- 1.1 Dalit A. Raviv 08/08/2010 when finished with error roman will get email nptification         
      l_html_str := '<p> Dear </p>' || '<p> Bpel Error ' || l_response_msg ||
                    '<p> Good day,  ' || --'<p> <br> </p>' || 
                    '<p> Oracle sys ' || '</p>';
    
      l_to_person := fnd_profile.VALUE('XXCS_SALESFORCE_FAILURE_SEND_TO');
      IF l_to_person IS NOT NULL THEN
        xxfnd_smtp_utilities.conc_send_mail(errbuf        => l_error_desc,
                                            retcode       => l_error_code,
                                            p_sender_name => l_sender_name,
                                            p_recipient   => l_to_person,
                                            p_subject     => 'XX: Salesforce Rates Integration - Failed',
                                            p_body        => l_html_str);
      END IF;
      -- end 1.1 08/08/2010                                          
    END IF;
    --dbms_output.put_line(response.getstringval()); 
  EXCEPTION
    WHEN OTHERS THEN
      v_message := substr(SQLERRM, 1, 250);
      retcode   := '2';
      errbuf    := 'Error Run Bpel Process - xxUpdateSalesforceRates: ' ||
                   v_message;
      sys.utl_dbws.release_call(call_);
      sys.utl_dbws.release_service(service_);
    
      -- Dalit A. Raviv 08/08/2010           
      l_html_str := '<p> Dear </p>' ||
                    '<p> Bpel Error - General Exception - ' || v_message ||
                    '<p> Good day,  ' || --'<p> <br> </p>' || 
                    '<p> Oracle sys ' || '</p>';
    
      l_to_person := fnd_profile.VALUE('XXCS_SALESFORCE_FAILURE_SEND_TO');
      xxfnd_smtp_utilities.conc_send_mail(errbuf        => l_error_desc,
                                          retcode       => l_error_code,
                                          p_sender_name => l_sender_name,
                                          p_recipient   => l_to_person,
                                          p_subject     => 'XX: Salesforce Rates Integration - GEN Failed',
                                          p_body        => l_html_str);
    
  END initiate_rates_process;

END xxcs_salesforce_utils_pkg;
/
