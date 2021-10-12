CREATE OR REPLACE PACKAGE BODY xxtas_interface AS

  --------------------------------------------------------------------
  --  name:            XXTAS_INTERFACE
  --  create by:       yuval tal
  --  Revision:        1.1
  --  creation date:   11/02/2013
  --------------------------------------------------------------------
  --  purpose :        CUST 641 CombTas Interfaces
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  11/02/2013  yuval tal         initial build
  --  1.1  16/06/2013  yuval atl         bugfix 830 Expense Concurrent cannot run in loop :
  --                                     add import_invoices_conc, modify update_last_gl_date
  --  1.2  20.4.16     yuval tal         CHG0037918 migration to 12c support redirect between 2 servers
  --                                     modify : submit combtas_generic     ,set_env_param
  -- 1.3  15.12.20      yuval tal       CHG0048579 - modify submit_combtas_generic ,add  submit_oic_combtas_generic 
  --------------------------------------------------------------------

  g_bpel_host        VARCHAR2(300) := xxobjt_bpel_utils_pkg.get_bpel_host;
  g_jndi_name        VARCHAR2(50) := xxobjt_bpel_utils_pkg.get_jndi_name(NULL);
  g_jndi_data_source VARCHAR2(50) := xxobjt_bpel_utils_pkg.get_jndi_data_source;
  g_tas_user         VARCHAR2(200);
  g_tas_password     VARCHAR2(200);
  g_end_point_url    VARCHAR2(2000);

  g_oic_service VARCHAR2(20) := 'COMBTAS';

  PROCEDURE message(p_msg IN VARCHAR2) IS
    ---------------------------------
    --      Local Definition
    ---------------------------------
    l_msg VARCHAR2(2000);
    ---------------------------------
    --      Code Section
    ---------------------------------
  BEGIN
    l_msg := to_char(SYSDATE, 'YYYY-MM-DD HH24:MI:SS') || ' - ' || p_msg;
  
    IF -1 = fnd_global.conc_request_id THEN
      dbms_output.put_line(l_msg);
    ELSE
      fnd_file.put_line(fnd_file.log, l_msg);
    END IF;
  
  END message;

  --------------------------------------------------------------------
  --  name:            set_env_param
  --  create by:       yuval tal
  --  Revision:        1.1
  --  creation date:   11/02/2013
  --------------------------------------------------------------------
  --  purpose :        CUST 641 CombTas Interfaces
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  11/02/2013  yuval tal         initial build
  --  1.1  1.5.16      yuval tal         CHG0037918 migration to 12c support redirect between 2 servers
  --
  --------------------------------------------------------------------
  PROCEDURE set_env_param IS
    l_env VARCHAR2(10);
  BEGIN
    l_env := xxobjt_bpel_utils_pkg.get_bpel_env;
    CASE
      WHEN l_env = 'production' THEN
      
        g_tas_user      := fnd_profile.value('XXTAS_USER_PROD');
        g_tas_password  := fnd_profile.value('XXTAS_PASSWORD_PROD');
        g_end_point_url := fnd_profile.value('XXTAS_ENDPOINT_URL_PROD');
      WHEN l_env = 'default' THEN
      
        g_tas_user      := fnd_profile.value('XXTAS_USER_TEST');
        g_tas_password  := fnd_profile.value('XXTAS_PASSWORD_TEST');
        g_end_point_url := fnd_profile.value('XXTAS_ENDPOINT_URL_TEST');
    END CASE;
  END set_env_param;

  --------------------------------------------------------------------
  --  name:            update_last_gl_rate
  --  create by:       yuval tal
  --  Revision:        1.1
  --  creation date:   11/02/2013
  --------------------------------------------------------------------
  --  purpose :        update profile with max rate date
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  11/02/2013  yuval tal         initial build
  --  1.1  19/06/2013  yuval tal         change logic bugfix 830
  --------------------------------------------------------------------
  PROCEDURE update_last_gl_rate(p_err_code    OUT NUMBER,
		        p_err_message OUT VARCHAR2) IS
    l_ret  BOOLEAN;
    l_date VARCHAR2(50);
  
    CURSOR c IS
      SELECT to_char(t.conversion_date, 'DD-MON-YYYY')
      --  INTO l_date
      FROM   xxgl_tas_daily_rate_v t
      WHERE  conversion_date <= SYSDATE
      GROUP  BY conversion_date
      HAVING COUNT(*) > fnd_profile.value('XXTAS_MAX_CURRENCY_COUNT4POINTER')
      ORDER  BY t.conversion_date DESC;
  
  BEGIN
  
    p_err_code := 0;
    OPEN c;
    FETCH c
      INTO l_date;
    CLOSE c;
  
    l_ret := fnd_profile_server.save(x_name       => 'XXTAS_GL_RATE_FROM_DATE',
			 x_value      => l_date,
			 x_level_name => 'SITE');
    COMMIT;
  
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code    := 1;
      p_err_message := SQLERRM;
  END update_last_gl_rate;

  --------------------------------------------------------------------
  --  customization code: CHG0048579
  --  name:               submit_oic_combtas_generic
  --  create by:          yuval tal
  --  creation date:      15.12.20
  --  Purpose :           support combtas call via oic 

  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   15.12.20      yuval tal       CHG0048579 support combtas call via oic 

  ----------------------------------------------------------------------
  PROCEDURE submit_oic_combtas_generic(p_errbuff   OUT VARCHAR2,
			   p_errcode   OUT VARCHAR2,
			   p_type      VARCHAR2,
			   p_from_date DATE,
			   p_group_id  NUMBER) IS
    l_enable_flag VARCHAR2(1);
    l_wallet_loc  VARCHAR2(500);
    l_url         VARCHAR2(500);
    l_wallet_pwd  VARCHAR2(500);
    l_auth_user   VARCHAR2(50);
    l_auth_pwd    VARCHAR2(50);
    -- l_error_code  VARCHAR2(5);
    -- l_error_desc  VARCHAR2(500);
  
    l_request_xml     VARCHAR2(1000);
    l_path            VARCHAR2(500);
    l_extended_format VARCHAR2(10);
  
    l_http_request            utl_http.req;
    l_http_response           utl_http.resp;
    l_resp                    VARCHAR2(32767);
    l_amount                  NUMBER;
    l_response_flow_id        NUMBER;
    l_response_tas_process_id VARCHAR2(100);
    l_response_err_code       NUMBER;
    l_response_err_message    VARCHAR2(3000);
    l_seq                     NUMBER;
  BEGIN
  
    message('OIC Mode');
    p_errcode := 0;
    set_env_param;
  
    -- log
    INSERT INTO xxtas_log
      (seq,
       request_type,
       creation_date,
       status,
       message_text,
       response)
    VALUES
      (xxtas_log_seq.nextval,
       p_type,
       SYSDATE,
       'N',
       NULL,
       NULL)
    RETURNING seq INTO l_seq;
    COMMIT;
  
    xxssys_oic_util_pkg.get_service_details(g_oic_service,
			        l_enable_flag,
			        l_url,
			        l_wallet_loc,
			        l_wallet_pwd,
			        l_auth_user,
			        l_auth_pwd,
			        p_errcode,
			        p_errbuff);
  
    IF p_errcode = 0 THEN
    
      l_request_xml := '<xxCombTasIntProcessRequest>
<requestType>' || p_type || '</requestType>
<tasUser>' || g_tas_user || '</tasUser>
<tasPass>' || g_tas_password || '</tasPass>
<officeId>' || fnd_profile.value('XXTAS_OFFICE_ID') ||
	           '</officeId>
<endPointUrl>' || g_end_point_url ||
	           '</endPointUrl><fromDate>' ||
	           to_char(p_from_date, 'DD-MON-YYYY') || '</fromDate>
<groupId>' || p_group_id ||
	           '</groupId>
</xxCombTasIntProcessRequest>';
    
      --   message(l_request_xml);
      --- call oic 
    
      utl_http.set_wallet(l_wallet_loc, l_wallet_pwd);
      l_http_request := utl_http.begin_request(l_url, 'POST');
    
      utl_http.set_authentication(l_http_request, l_auth_user, l_auth_pwd);
    
      -- utl_http.set_header(l_http_request, 'Proxy-Connection', 'Keep-Alive');   
      utl_http.set_header(l_http_request,
		  'Content-Length',
		  length(l_request_xml));
      utl_http.set_header(l_http_request,
		  'Content-Type',
		  'application/xml');
    
      ---------------------
      --  l_amount := 1000;
    
      utl_http.write_text(r => l_http_request, data => l_request_xml);
    
      ---------------------------
      l_http_response := utl_http.get_response(l_http_request);
      message('------------------------');
      message('Http.status_code=' || l_http_response.status_code);
      message('------------------------');
      --
      --Response
    
      /*<xxCombTasIntProcessResponse>
      <flowId>6008139</flowId>
      <tasProcessId>8736FED5-84A2-41C9-8F5C-D11B528517C6</tasProcessId>
      <errCode>0</errCode>
      <errMessage>Budgets_Data is NULL.</errMessage>
      <errXmlMessage/>
      </xxCombTasIntProcessResponse>';*/
    
      BEGIN
        -- LOOP
        utl_http.read_text(l_http_response, l_resp, 32766);
        message(l_resp);
        --  END LOOP;
        utl_http.end_response(l_http_response);
      EXCEPTION
        WHEN utl_http.end_of_body THEN
          utl_http.end_response(l_http_response);
      END;
    
      IF instr(l_resp, '<TITLE>Error') > 0 THEN
        p_errcode := '2';
        p_errbuff := l_resp;
      ELSE
      
        SELECT flow_id,
	   response_tas_process_id,
	   nvl(ERROR_CODE, 2),
	   nvl('OIC Flow id=' || flow_id || ' ' || error_message,
	       substr(l_resp, 200))
        INTO   l_response_flow_id,
	   l_response_tas_process_id,
	   l_response_err_code,
	   l_response_err_message
        FROM   -- resp r,
	   xmltable('xxCombTasIntProcessResponse' passing
		xmltype(l_resp) columns flow_id VARCHAR2(10) path
		'flowId',
		response_tas_process_id VARCHAR2(150) path
		'tasProcessId',
		ERROR_CODE VARCHAR2(10) path 'errCode',
		error_message VARCHAR2(1000) path 'errMessage'
		
		) xt;
      END IF;
      utl_http.end_response(l_http_response);
    
      -- log
      UPDATE xxtas_log t
      SET    t.bpel_instance_id = l_response_flow_id,
	 t.last_update_date = SYSDATE,
	 t.tas_process_id   = l_response_tas_process_id,
	 t.message_text     = l_response_err_message,
	 t.status           = decode(l_response_err_code, '0', 'S', 'E'),
	 t.response         = l_resp
      WHERE  t.seq = l_seq;
    
      COMMIT;
    END IF;
  
    p_errcode := l_response_err_code;
    IF l_response_err_code != 0 THEN
      p_errcode := 1;
    END IF;
  
    p_errbuff := l_response_err_message;
  
    message('Status = ' || l_response_err_code);
    message('Status = ' || p_errbuff);
  EXCEPTION
    WHEN OTHERS THEN
    
      dbms_output.put_line('get_detailed_sqlerrm' ||
		   utl_http.get_detailed_sqlerrm);
      utl_http.end_response(l_http_response);
      p_errcode := '2';
      p_errbuff := 'Error in xxtas_interface.submit_oic_combtas_generic: ' ||
	       substr(SQLERRM, 1, 250);
    
  END;

  --------------------------------------------------------------------
  --  customization code:
  --  name:               submit_combtas_generic
  --  create by:          yuval tal
  --  creation date:      11.2.2013
  --  Purpose :           submit bpel process for combtas services
  --  CR 679 : Daily rates interface
  --  PARAMETERS:
  --  p_type       :
  --    DAILY_RATE   : daily rate Sync according to profile (XXTAS_GL_RATE_FROM_DATE)
  --    PROJECT      : project(segment)
  --    ORGANIZATION : Organization hierarchy
  --    BUDGET       : budgert amount Sync
  --    EMP          : employee sync
  --    AP_PULL      : get ap invoives data
  --    AP_PUSH      : update invoices creation status
  --  p_from_date  : used for request type
  --                                  DAILY_RATE : force upload data from conversion date>p_from_date
  --                                  BUDGET     : budget year according to year of p_from_date
  --
  --  p_group_id   : used for trquest_type AP_PULL,AP_PUSH (batch of invoices)
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   11.2.2013     yuval tal       Initial Build
  --  1.1   30/06/2015    Dalit A. Raviv  CHG0035389 Upgrade bpel 10G to 11G - xxCombTas_Int
  --  1.2   20.4.16       yuval tal       CHG0037918 migration to 12c support redirect between 2 servers
  --  1.3   15.12.20      yuval tal       CHG0048579 support combtas call via oic 
  ----------------------------------------------------------------------
  PROCEDURE submit_combtas_generic(p_errbuff   OUT VARCHAR2,
		           p_errcode   OUT VARCHAR2,
		           p_type      VARCHAR2,
		           p_from_date VARCHAR2,
		           p_group_id  NUMBER) IS
  
    service_            sys.utl_dbws.service;
    call_               sys.utl_dbws.call;
    service_qname       sys.utl_dbws.qname;
    response            sys.xmltype;
    request             sys.xmltype;
    l_string_type_qname sys.utl_dbws.qname;
    -- response
    l_response_err_code         NUMBER;
    l_response_err_message      VARCHAR2(3000);
    l_response_bpel_instance_id NUMBER;
    l_response_tas_process_id   VARCHAR2(100);
    l_response_err_xml_message  CLOB;
    l_from_date                 DATE := trunc(fnd_date.canonical_to_date(p_from_date));
  
    --
    l_seq NUMBER;
    --l_err_code    NUMBER;
    --l_err_message VARCHAR2(500);
  BEGIN
    --
  
    --- check oic enable CHG0048579
    IF xxssys_oic_util_pkg.get_service_oic_enable_flag(p_service => g_oic_service) = 'Y' THEN
      submit_oic_combtas_generic(p_errbuff   => p_errbuff,
		         p_errcode   => p_errcode,
		         p_type      => p_type,
		         p_from_date => l_from_date,
		         p_group_id  => p_group_id);
    
      RETURN; -- get out of procedure
    END IF;
    message('Bpel Mode');
    ----
    p_errcode := 0;
    set_env_param;
  
    -- log
    INSERT INTO xxtas_log
      (seq,
       request_type,
       creation_date,
       status,
       message_text,
       response)
    VALUES
      (xxtas_log_seq.nextval,
       p_type,
       SYSDATE,
       'N',
       NULL,
       NULL)
    RETURNING seq INTO l_seq;
    COMMIT;
  
    -- fnd log ------------------------------
    fnd_file.put_line(fnd_file.log,
	          ' ----------------- EBS - Combtas Sync Log -----------------');
    fnd_file.put_line(fnd_file.log, 'Type = ' || p_type);
    fnd_file.put_line(fnd_file.log, 'Seq  = ' || l_seq);
    -- call bpel
  
    service_qname       := sys.utl_dbws.to_qname('http://xmlns.oracle.com/xxCombTas_Int',
				 'xxCombTas_Int');
    l_string_type_qname := sys.utl_dbws.to_qname('http://www.w3.org/2001/XMLSchema',
				 'string');
  
    service_ := sys.utl_dbws.create_service(service_qname);
    call_    := sys.utl_dbws.create_call(service_);
  
    fnd_file.put_line(fnd_file.log,
	          'srv1=' || xxobjt_bpel_utils_pkg.get_bpel_host_srv1 ||
	          '/soa-infra/services/tas/xxCombTas_Int/client');
    fnd_file.put_line(fnd_file.log,
	          'srv2=' || xxobjt_bpel_utils_pkg.get_bpel_host_srv2 ||
	          '/soa-infra/services/tas/xxCombTas_Int/client');
  
    fnd_file.put_line(fnd_file.log,
	          'XXSSYS_TAS_SOA_SRV_NUM=' ||
	          nvl(fnd_profile.value('XXSSYS_TAS_SOA_SRV_NUM'), '1'));
  
    -- 1.1 30/06/2015 Dalit A. Raviv CHG0035389 Upgrade bpel 10G to 11G - xxCombTas_Int
    -- add profile that will determine if the bpel will go to 10G or 11G
    --  if nvl(fnd_profile.value('XXSSYS_ENABLE_TAS_BPEL11G'), 'N') = 'N' THEN  --CHG0037918 put in rem
  
    IF nvl(fnd_profile.value('XXSSYS_TAS_SOA_SRV_NUM'), '1') = '1' THEN
      --???
      --CHG0037918
      sys.utl_dbws.set_target_endpoint_address(call_,
			           xxobjt_bpel_utils_pkg.get_bpel_host_srv1 ||
			           '/soa-infra/services/tas/xxCombTas_Int/client');
      -- 11G
    ELSE
      --12c
      sys.utl_dbws.set_target_endpoint_address(call_,
			           xxobjt_bpel_utils_pkg.get_bpel_host_srv2 ||
			           '/soa-infra/services/tas/xxCombTas_Int/client');
    
    END IF;
    sys.utl_dbws.set_property(call_, 'SOAPACTION_USE', 'TRUE');
    sys.utl_dbws.set_property(call_, 'SOAPACTION_URI', 'process');
    sys.utl_dbws.set_property(call_, 'OPERATION_STYLE', 'document');
  
    sys.utl_dbws.set_property(call_,
		      'ENCODINGSTYLE_URI',
		      'http://schemas.xmlsoap.org/soap/encoding/');
  
    sys.utl_dbws.set_return_type(call_, l_string_type_qname);
  
    request := sys.xmltype('<ns1:xxCombTas_IntProcessRequest xmlns:ns1="http://xmlns.oracle.com/xxCombTas_Int">
		        <ns1:request_type>' || p_type ||
		   '</ns1:request_type>
		        <ns1:jndi_db_name>' || g_jndi_name ||
		   '</ns1:jndi_db_name>
		        <ns1:tas_user>' || g_tas_user ||
		   '</ns1:tas_user>
		        <ns1:tas_pass>' || g_tas_password ||
		   '</ns1:tas_pass>
		        <ns1:office_id>' ||
		   fnd_profile.value('XXTAS_OFFICE_ID') ||
		   '</ns1:office_id>
		        <ns1:end_point_url>' || g_end_point_url ||
		   '</ns1:end_point_url>
		        <ns1:from_date>' ||
		   to_char(l_from_date, 'DD-MON-YYYY') ||
		   '</ns1:from_date>
		        <ns1:group_id>' || p_group_id ||
		   '</ns1:group_id>
		        <ns1:jndi_data_source>' ||
		   g_jndi_data_source ||
		   '</ns1:jndi_data_source>
		     </ns1:xxCombTas_IntProcessRequest>');
  
    response := sys.utl_dbws.invoke(call_, request);
    sys.utl_dbws.release_call(call_);
    sys.utl_dbws.release_service(service_);
    -- p_errbuff := substr(response.getstringval(), 1, 240);
  
    ----------------------------
    -- parse bpel response
    ------------------------------
    l_response_err_code := response.extract('//xxCombTas_IntProcessResponse/err_code/text()','xmlns="http://xmlns.oracle.com/xxCombTas_Int"')
		   .getstringval();
  
    l_response_err_message := response.extract('//xxCombTas_IntProcessResponse/err_message/text()','xmlns="http://xmlns.oracle.com/xxCombTas_Int"')
		      .getstringval();
  
    l_response_bpel_instance_id := response.extract('//xxCombTas_IntProcessResponse/bpel_instance_id/text()','xmlns="http://xmlns.oracle.com/xxCombTas_Int"')
		           .getstringval();
    l_response_tas_process_id   := response.extract('//xxCombTas_IntProcessResponse/tas_process_id/text()','xmlns="http://xmlns.oracle.com/xxCombTas_Int"')
		           .getstringval();
  
    l_response_err_xml_message := xmltype.getclobval(response);
    dbms_output.put_line('l_response_bpel_instance_id = ' ||
		 l_response_bpel_instance_id);
    -- log
    UPDATE xxtas_log t
    SET    t.bpel_instance_id = l_response_bpel_instance_id,
           t.last_update_date = SYSDATE,
           t.tas_process_id   = l_response_tas_process_id,
           t.message_text     = l_response_err_message,
           t.status           = decode(l_response_err_code, '0', 'S', 'E'),
           t.response         = l_response_err_xml_message
    WHERE  t.seq = l_seq;
    COMMIT;
  
    -- update response
    p_errcode := l_response_err_code;
    p_errbuff := l_response_err_message;
  
    fnd_file.put_line(fnd_file.log, 'Status = ' || l_response_err_code);
    fnd_file.put_line(fnd_file.log, p_errbuff);
  
  EXCEPTION
    WHEN OTHERS THEN
      p_errcode := 2;
      p_errbuff := substr(SQLERRM, 1, 255);
      fnd_file.put_line(fnd_file.log, 'Status = ' || p_errbuff);
  END submit_combtas_generic;

  --------------------------------------------------------------------
  --  name:            import_invoices_conc
  --  create by:       yuval tal
  --  Revision:        1.1
  --  creation date:   11/02/2013
  --------------------------------------------------------------------
  --  purpose :        create tas AP invoice for exp/standard invoices
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  16/06/2013  yuval tal         Initial Build
  --                                     Called from prog XX TAS Import Invoices / XXTASAPINVC
  --                                     Param in:
  --                                     p_table_source: invoice source from table xx_ap_invoices_interface .
  --                                                     source  XX_COMBTAS_EXP (employee expenses) or XX_COMBTAS (Supplier)
  --                                                     VALUESET XX_TAS_INVOICE_TYPE :
  --                                                     SELECT t.flex_value, t.flex_value_meaning
  --                                                     FROM fnd_flex_values_vl t
  --                                                     WHERE t.flex_value_set_id = 1018971
  --                                                     AND t.parent_flex_value_low = 'XX_AP_INVOICES_INTERFACE'
  --                                                     AND t.flex_value IN ('XX_COMBTAS', 'XX_COMBTAS_EXP')
  --                                     p_ap_import_flag: execute import to ap process
  --                                     Param Out:
  --                                     p_err_code    : 1 error 0 success
  --                                     p_err_message : error message
  --------------------------------------------------------------------
  PROCEDURE import_invoices_conc(p_err_message    OUT VARCHAR2,
		         p_err_code       OUT NUMBER,
		         p_table_source   VARCHAR2,
		         p_ap_import_flag VARCHAR2) IS
    l_errbuff   VARCHAR2(3000);
    l_errcode   NUMBER;
    l_group_id  NUMBER;
    l_type_push VARCHAR2(50);
    l_type_pull VARCHAR2(50);
    --l_import_request_id NUMBER;
  BEGIN
  
    p_err_code := 0;
  
    IF p_table_source = 'XX_COMBTAS_EXP' THEN
      l_type_push := 'APEXP_PUSH';
      l_type_pull := 'APEXP_PULL';
    ELSE
      l_type_push := 'AP_PUSH';
      l_type_pull := 'AP_PULL';
    END IF;
  
    SELECT xxap_interface_group_id_s.nextval
    INTO   l_group_id
    FROM   dual;
    fnd_file.put_line(fnd_file.log, 'Group_id=' || l_group_id);
    fnd_file.put_line(fnd_file.log, '----------' || l_type_pull || '----');
    -- import ap invoices
    submit_combtas_generic(p_errbuff   => l_errbuff,
		   p_errcode   => l_errcode,
		   p_type      => l_type_pull,
		   p_from_date => NULL,
		   p_group_id  => l_group_id);
    p_err_code := greatest(l_errcode, p_err_code);
  
    fnd_file.put_line(fnd_file.log, 'l_errcode = ' || l_errcode);
  
    -- process ap_inteface
    --IF l_errcode = 0 THEN
    fnd_file.put_line(fnd_file.log, '-----------------------');
    fnd_file.put_line(fnd_file.log, 'Process Invoices....');
    fnd_file.put_line(fnd_file.log, '-----------------------');
  
    xxap_invoice_interface_api.process_invoices_conc(p_table_source   => p_table_source,
				     p_err_code       => l_errcode,
				     p_err_message    => l_errbuff,
				     p_group_id       => l_group_id,
				     p_ap_import_flag => p_ap_import_flag);
    p_err_code := greatest(l_errcode, p_err_code);
    fnd_file.put_line(fnd_file.log, 'l_errcode=' || l_errcode);
    -- update tas system
    fnd_file.put_line(fnd_file.log, '----------' || l_type_push || '----');
    submit_combtas_generic(p_errbuff   => l_errbuff,
		   p_errcode   => l_errcode,
		   p_type      => l_type_push,
		   p_from_date => NULL,
		   p_group_id  => l_group_id);
  
    --  END IF;
    p_err_code    := greatest(l_errcode, p_err_code);
    p_err_message := '';
  
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code    := 2;
      p_err_message := substr(SQLERRM, 1, 250);
  END import_invoices_conc;

END xxtas_interface;
/
