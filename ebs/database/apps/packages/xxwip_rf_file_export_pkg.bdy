CREATE OR REPLACE PACKAGE BODY xxwip_rf_file_export_pkg IS
  g_service VARCHAR2(2) := 'RF';
  --------------------------------------------------------------------
  --  name:            xxwip_rf_file_export_pkg
  --  create by:       yuval tal
  --  Revision:
  --  creation date:
  --------------------------------------------------------------------
  --  purpose :        support  bpel rf process
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  12.11.14    yuval tal       CHG0032304  modify call_rf_bpel_process
  --  1.1  21.4.16     yuval atl       CHG0037918 migration to 12c support redirect between 2 servers
  --  1.2  28/08/2019  Roman W.        CHG0046309 - New RF file for Tavor
  --  1.3  15.12.20    yuval tal       CHG0048579 - add call_rf_oic_process , modify call_rf_bpel_process
  --------------------------------------------------------------------

  ------------------------------------------------------------------------------------------
  -- Ver     When         Who             Description
  -- ------  -----------  -------------   --------------------------------------------------
  -- 1.0     2019-08-11   Roman W.        CHG0045829
  ------------------------------------------------------------------------------------------
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
  -- Ver    When         Who            Descr
  -- -----  -----------  -------------  ------------------------------
  -- 1.0    28/08/2019   Roman W.       CHG0046309
  --------------------------------------------------------------------
  FUNCTION get_extended_format(p_destination VARCHAR2) RETURN VARCHAR IS
    l_ret_val VARCHAR2(1);
    -----------------------------
    --     Code Section
    -----------------------------
  BEGIN
    l_ret_val := 'N';
  
    SELECT nvl(ffvv.attribute1, 'N')
    INTO   l_ret_val
    FROM   fnd_flex_value_sets ffvs,
           fnd_flex_values_vl  ffvv
    WHERE  ffvv.flex_value = p_destination
    AND    ffvs.flex_value_set_name = 'XXWIP_RF_DESTINATIONS'
    AND    ffvv.flex_value_set_id = ffvs.flex_value_set_id
    AND    ffvv.enabled_flag = 'Y'
    AND    trunc(SYSDATE) BETWEEN
           nvl(ffvv.start_date_active, trunc(SYSDATE)) AND
           nvl(ffvv.end_date_active, trunc(SYSDATE));
  
    RETURN l_ret_val;
  EXCEPTION
    WHEN no_data_found THEN
      RETURN 'N';
  END get_extended_format;

  ---------------------------------------------------
  -- call_rf_oic_process
  --------------------------------------------------------------------
  --  purpose :        call oic rtf process
  --------------------------------------------------------------------
  --  ver     name           date           desc
  ---  1.0     yuval tal      15.12.20        CHG0048579 - OIC  intergration -intial build
  --------------------------------------------------

  PROCEDURE call_rf_oic_process(errbuf         OUT VARCHAR2,
		        retcode        OUT NUMBER,
		        p_job_number   IN VARCHAR2,
		        p_lot          IN VARCHAR2,
		        p_organization IN VARCHAR2,
		        p_destination  IN VARCHAR2) IS
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
  
    l_http_request  utl_http.req;
    l_http_response utl_http.resp;
    l_resp          VARCHAR2(32767);
    l_amount        NUMBER;
    --l_offset        NUMBER;
  BEGIN
    retcode := 0;
    xxssys_oic_util_pkg.get_service_details(g_service,
			        l_enable_flag,
			        l_url,
			        l_wallet_loc,
			        l_wallet_pwd,
			        l_auth_user,
			        l_auth_pwd,
			        retcode,
			        errbuf);
  
    IF retcode = 0 THEN
      l_path := xxobjt_general_utils_pkg.get_valueset_desc(p_set_code => 'XXWIP_RF_DESTINATIONS',
				           p_code     => p_destination);
      message('l_path=' || l_path);
      l_extended_format := get_extended_format(p_destination);
      l_request_xml     := '<xxRfFileExportProcessRequest>' ||
		   '<jobNumber>' || p_job_number || '</jobNumber>' ||
		   '<lotNumber>' || p_lot || '</lotNumber>' ||
		   '<organizationId>' || p_organization ||
		   '</organizationId>' || '<destination>' || l_path ||
		   '</destination>' || '<extendedFormat>' ||
		   l_extended_format || '</extendedFormat>' ||
		   '</xxRfFileExportProcessRequest>';
      message(l_request_xml);
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
        retcode := '2';
        errbuf  := l_resp;
      ELSE
      
        WITH resp AS
         (SELECT xmltype(l_resp) xml_data
          FROM   dual)
        -- The above simulates the table in your DB
        SELECT nvl(ERROR_CODE, 2),
	   nvl('OIC Flow id=' || flow_id || ' ' || error_message,
	       substr(l_resp, 200))
        INTO   retcode,
	   errbuf
        FROM   resp r,
	   xmltable('xxRfFileExportProcessResponse' passing r.xml_data
		columns flow_id VARCHAR2(10) path 'flowId',
		ERROR_CODE VARCHAR2(10) path 'errorCode',
		error_message VARCHAR2(1000) path 'errorMessage'
		
		) xt;
      END IF;
    
    END IF;
  
    utl_http.end_response(l_http_response);
  EXCEPTION
    WHEN OTHERS THEN
    
      dbms_output.put_line('get_detailed_sqlerrm' ||
		   utl_http.get_detailed_sqlerrm);
      utl_http.end_response(l_http_response);
      retcode := '2';
      errbuf  := 'Error in xxwip_rf_file_export_pkg: ' ||
	     substr(SQLERRM, 1, 250);
    
  END;

  --------------------------------------------------------------------
  --  purpose :        call bpel rtf process
  --------------------------------------------------------------------
  --  ver     name           date           desc
  --          yuval tal      22.5.11        change logic for p_destination to hold path instead of code
  --   1.1    yuval tal      12.4.14        CHG0032304  suppoert redirect to new bpel server11g
  --   1.2    yuval atl      21.4.16        CHG0037918 migration to 12c support redirect between 2 servers
  --                                        modify
  --   1.3    Roman W.       28/08/2019     CHG0046309 - New RF file for Tavor
  --   1.4    yuval tal      15.12.2020     CHG0048579 - OIC  intergration - plsql modifications
  --------------------------------------------------------------------
  PROCEDURE call_rf_bpel_process(errbuf         OUT VARCHAR2,
		         retcode        OUT NUMBER,
		         p_job_number   IN VARCHAR2,
		         p_lot          IN VARCHAR2,
		         p_organization IN VARCHAR2,
		         p_destination  IN VARCHAR2) IS
    -----------------------------------
    --     Local Definition
    -----------------------------------
    service_            sys.utl_dbws.service;
    call_               sys.utl_dbws.call;
    service_qname       sys.utl_dbws.qname;
    response            sys.xmltype;
    request             sys.xmltype;
    v_string_type_qname sys.utl_dbws.qname;
    v_error             VARCHAR2(1000);
    l_path              VARCHAR2(500);
    l_extended_format   VARCHAR2(10);
    l_request_xml       VARCHAR2(2000);
  
    -- l_oic_enable VARCHAR2(1);
    -----------------------------------
    --     Code Section
    -----------------------------------
  BEGIN
  
    --- check oic enable CHG0048579
    IF xxssys_oic_util_pkg.get_service_oic_enable_flag(p_service => g_service) = 'Y' THEN
    
      call_rf_oic_process(errbuf         => errbuf,
		  retcode        => retcode,
		  p_job_number   => p_job_number,
		  p_lot          => p_lot,
		  p_organization => p_organization,
		  p_destination  => p_destination);
      RETURN; -- get out of procedure
    END IF;
  
    ----
  
    BEGIN
    
      l_path              := xxobjt_general_utils_pkg.get_valueset_desc(p_set_code => 'XXWIP_RF_DESTINATIONS',
						p_code     => p_destination);
      service_qname       := sys.utl_dbws.to_qname('http://xmlns.oracle.com/xxRfFileExport',
				   'xxRfFileExport');
      v_string_type_qname := sys.utl_dbws.to_qname('http://www.w3.org/2001/XMLSchema',
				   'string');
      service_            := sys.utl_dbws.create_service(service_qname);
      call_               := sys.utl_dbws.create_call(service_);
    
      l_extended_format := get_extended_format(p_destination);
    
      -- CHG0032304
      --  IF nvl(fnd_profile.value('XXWIP_ENABLE_RF_BPEL11G'), 'N') = 'N' THEN  --CHG0037918
      IF nvl(fnd_profile.value('XXWIP_RF_SOA_SRV_NUM'), '1') = '1' THEN
        --CHG0037918
        sys.utl_dbws.set_target_endpoint_address(call_,
				 xxobjt_bpel_utils_pkg.get_bpel_host_srv1 ||
				 '/soa-infra/services/wip/xxRfFileExport/client');
      ELSE
      
        sys.utl_dbws.set_target_endpoint_address(call_,
				 xxobjt_bpel_utils_pkg.get_bpel_host_srv2 ||
				 '/soa-infra/services/wip/xxRfFileExport/client');
      END IF;
    
      sys.utl_dbws.set_property(call_, 'SOAPACTION_USE', 'TRUE');
      sys.utl_dbws.set_property(call_, 'SOAPACTION_URI', 'process');
      sys.utl_dbws.set_property(call_, 'OPERATION_STYLE', 'document');
      sys.utl_dbws.set_return_type(call_, v_string_type_qname);
    
      l_request_xml := '<ns1:xxRfFileExportProcessRequest xmlns:ns1="http://xmlns.oracle.com/xxRfFileExport">' ||
	           '<ns1:Job_Number>' || p_job_number ||
	           '</ns1:Job_Number>' || '<ns1:Lot_Number>' || p_lot ||
	           '</ns1:Lot_Number>' || '<ns1:Organization_Id>' ||
	           p_organization || '</ns1:Organization_Id>' ||
	           '<ns1:Destination>' || l_path ||
	           '</ns1:Destination>' || '<ns1:ExtendedFormat>' ||
	           l_extended_format || '</ns1:ExtendedFormat>' ||
	           '</ns1:xxRfFileExportProcessRequest>';
    
      message(l_request_xml);
    
      request := sys.xmltype(l_request_xml);
    
      -- END IF;
    
      response := sys.utl_dbws.invoke(call_, request);
      sys.utl_dbws.release_call(call_);
      sys.utl_dbws.release_service(service_);
      v_error := response.getstringval();
    
      IF response.getstringval() LIKE '%Error%' THEN
        retcode := 2;
        errbuf  := REPLACE(REPLACE(substr(v_error,
			      instr(v_error, 'instance') + 10,
			      length(v_error)),
		           '</OutPut>',
		           NULL),
		   '</processResponse>',
		   NULL);
      ELSIF response.getstringval() LIKE '%Warning%' THEN
        retcode := 1;
        errbuf  := REPLACE(REPLACE(substr(v_error,
			      instr(v_error, 'instance') + 10,
			      length(v_error)),
		           '</OutPut>',
		           NULL),
		   '</processResponse>',
		   NULL);
      END IF;
      --dbms_output.put_line(response.getstringval());
    EXCEPTION
      WHEN OTHERS THEN
        v_error := substr(SQLERRM, 1, 250);
        retcode := '2';
        errbuf  := 'Error Run Bpel Interface: ' || v_error;
        sys.utl_dbws.release_call(call_);
        sys.utl_dbws.release_service(service_);
    END;
  
  END call_rf_bpel_process;
END xxwip_rf_file_export_pkg;
/
