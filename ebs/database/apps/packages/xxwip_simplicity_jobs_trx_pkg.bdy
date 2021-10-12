CREATE OR REPLACE PACKAGE BODY xxwip_simplicity_jobs_trx_pkg IS
  g_user_id     fnd_user.user_id%TYPE;
  g_oic_service VARCHAR2(15) := 'SIMPLICITY';
  --------------------------------------------------------------------
  --  customization code:
  --  name:               call_bpel_process
  --  create by:          XXX
  --  creation date:      XX/XX/XXXX
  --  Purpose :
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   XX/XX/XXXX    XXX             Initial Build
  --  1.1   17/06/2015    Dalit A. Raviv  CHG0035388 Upgrade bpel 10G to 11G - xxGetSimplFile
  -- 1.2    08.5.16       yuval tal       CHG0037918 migration to 12c support redirect between 2 servers
  --                                        modify
  -- 1.3    25.12.17      yuval tal       INC0110260 modify    
  -- 1.4    15.12.20      yuval tal       CHG0048579 - modify call_bpel_process ,add  call_oic_process                
  ----------------------------------------------------------------------

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

  ---------------------------------------------------------------------
  -- call_OIC_process

  ----------------------------------------------------------------------
  --  ver   date          name            desc
  -- 1.0    15.12.20      yuval tal       CHG0048579 - OIC  intergration - plsql modifications                 
  ----------------------------------------------------------------------

  PROCEDURE call_oic_process(p_job_number IN VARCHAR2,
		     p_directory  IN VARCHAR2,
		     p_file_name  IN VARCHAR2,
		     p_status     OUT VARCHAR2,
		     p_message    OUT VARCHAR2) IS
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
    l_retcode       VARCHAR2(5);
  
    l_errbuf VARCHAR2(2000);
  BEGIN
    p_status := 'S';
    xxssys_oic_util_pkg.get_service_details(g_oic_service,
			        l_enable_flag,
			        l_url,
			        l_wallet_loc,
			        l_wallet_pwd,
			        l_auth_user,
			        l_auth_pwd,
			        l_retcode,
			        l_errbuf);
  
    IF l_retcode = 0 THEN
    
      l_request_xml := '<xxGetSimplFileProcessRequest>
<jobNumber>' || p_job_number || '</jobNumber>
<getFileDirectory>' || p_directory || '</getFileDirectory>
<fileName>' || p_file_name ||
	           '</fileName>
<sourceName>oracle</sourceName>
</xxGetSimplFileProcessRequest>';
    
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
        p_status  := 'E';
        p_message := l_resp;
      ELSE
        /*  <xxGetSimplFileProcessResponse>
        <result>S</result>
        </xxGetSimplFileProcessResponse>
        
        Faliure Response
        
        <xxGetSimplFileProcessResponse>
        <status>E</status>
        <errorMessage>ErrorCode: businessError ErrorReason: Error - The Job Number Parameter Is Not Equal To Job Number In The File  Error Details: <details xmlns="http://www.oracle.com/2014/03/ics/fault"> This is business error raised from flow , please check the error reason </details>
        </errorMessage>
        </xxGetSimplFileProcessResponse>*/
        SELECT nvl(ERROR_CODE, 2),
	   nvl('OIC Flow id=' || flow_id || ' ' || error_message,
	       substr(l_resp, 200))
        INTO   p_status,
	   p_message
        FROM   xmltable('xxGetSimplFileProcessResponse' passing
		xmltype(l_resp) columns flow_id VARCHAR2(10) path
		'flowId',
		ERROR_CODE VARCHAR2(10) path 'status',
		error_message VARCHAR2(1000) path 'errorMessage'
		
		) xt;
      END IF;
      utl_http.end_response(l_http_response);
    ELSE
    
      p_status  := 'E';
      p_message := l_errbuf;
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
    
      dbms_output.put_line('get_detailed_sqlerrm' ||
		   utl_http.get_detailed_sqlerrm);
      utl_http.end_response(l_http_response);
      p_status  := 'E';
      p_message := 'Error in xxwip_simplicity_jobs_trx_pkg.call_oic_process: ' ||
	       substr(SQLERRM, 1, 250);
    
  END;

  ---------------------------------------------------------------------
  -- call_bpel_process
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   XX/XX/XXXX    XXX             Initial Build
  -- 1.4    15.12.20      yuval tal       CHG0048579 - modify call_bpel_process OIC  intergration - plsql modifications                 
  ----------------------------------------------------------------------

  PROCEDURE call_bpel_process(p_job_number IN VARCHAR2,
		      p_directory  IN VARCHAR2,
		      p_file_name  IN VARCHAR2,
		      p_status     OUT VARCHAR2,
		      p_message    OUT VARCHAR2) IS
  
    service_            sys.utl_dbws.service;
    call_               sys.utl_dbws.call;
    service_qname       sys.utl_dbws.qname;
    response            sys.xmltype;
    request             sys.xmltype;
    v_string_type_qname sys.utl_dbws.qname;
    v_error             VARCHAR2(1000);
    l_jndi_name         VARCHAR2(50);
  BEGIN
  
    p_status := 'S';
  
    --- check oic enable CHG0048579
    IF xxssys_oic_util_pkg.get_service_oic_enable_flag(p_service => g_oic_service) = 'Y' THEN
      message('OIC Mode');
      call_oic_process(p_job_number => p_job_number,
	           p_directory  => p_directory,
	           p_file_name  => p_file_name,
	           p_status     => p_status,
	           p_message    => p_message);
      RETURN; -- get out of procedure
    END IF;
    message('Bpel Mode');
    ----
  
    BEGIN
      l_jndi_name := xxobjt_bpel_utils_pkg.get_jndi_name(NULL);
    
      service_qname       := sys.utl_dbws.to_qname('http://xmlns.oracle.com/xxGetSimplFile',
				   'xxGetSimplFile');
      v_string_type_qname := sys.utl_dbws.to_qname('http://www.w3.org/2001/XMLSchema',
				   'string');
      service_            := sys.utl_dbws.create_service(service_qname);
      call_               := sys.utl_dbws.create_call(service_);
    
      --  CHG0035388 Upgrade bpel 10G to 11G - xxGetSimplFile
      --  add profile that will determine if the bpel will go to 10G or 11G
      --  IF nvl(fnd_profile.value('XXWIP_ENABLE_SIMPLICITY_BPEL11G'), 'N') = 'N' THEN
      fnd_file.put_line(fnd_file.log,
		'XXWIP_SIMPLICITY_SOA_SRV_NUM=' ||
		fnd_profile.value('XXWIP_SIMPLICITY_SOA_SRV_NUM'));
    
      IF nvl(fnd_profile.value('XXWIP_SIMPLICITY_SOA_SRV_NUM'), '1') = '1' THEN
      
        sys.utl_dbws.set_target_endpoint_address(call_,
				 xxobjt_bpel_utils_pkg.get_bpel_host_srv1 ||
				 '/soa-infra/services/wip/xxGetSimplFile/client');
      ELSE
        -- 11G
        --'http://srv-ire-bpeldev.2objet.com:8001/soa-infra/services/wip/xxGetSimplFile/client'
        sys.utl_dbws.set_target_endpoint_address(call_,
				 xxobjt_bpel_utils_pkg.get_bpel_host_srv2 ||
				 '/soa-infra/services/wip/xxGetSimplFile/client');
      END IF;
    
      sys.utl_dbws.set_property(call_, 'SOAPACTION_USE', 'TRUE');
      sys.utl_dbws.set_property(call_, 'SOAPACTION_URI', 'process');
      sys.utl_dbws.set_property(call_, 'OPERATION_STYLE', 'document');
      sys.utl_dbws.set_property(call_,
		        'ENCODINGSTYLE_URI',
		        'http://schemas.xmlsoap.org/soap/encoding/');
      /*    sys.utl_dbws.add_parameter(call_,
                                 'JobNumber',
                                 v_string_type_qname,
                                 'ParameterMode.IN');
      sys.utl_dbws.add_parameter(call_,
                                 'GetFileDirectory',
                                 v_string_type_qname,
                                 'ParameterMode.IN');
      sys.utl_dbws.add_parameter(call_,
                                 'FileName',
                                 v_string_type_qname,
                                 'ParameterMode.IN');
      sys.utl_dbws.add_parameter(call_,
                                 'JndiName',
                                 v_string_type_qname,
                                 'ParameterMode.IN');*/
      sys.utl_dbws.set_return_type(call_, v_string_type_qname);
    
      request := sys.xmltype('<ns1:xxGetSimplFileProcessRequest xmlns:ns1="http://xmlns.oracle.com/xxGetSimplFile">
		           <ns1:JobNumber>' || p_job_number ||
		     '</ns1:JobNumber>
		           <ns1:GetFileDirectory>' ||
		     p_directory || '</ns1:GetFileDirectory>
		           <ns1:FileName>' || p_file_name ||
		     '</ns1:FileName>
		           <ns1:JndiName>' || l_jndi_name ||
		     '</ns1:JndiName>

		           </ns1:xxGetSimplFileProcessRequest>');
    
      fnd_file.put_line(fnd_file.log, 'l_jndi_name - ' || l_jndi_name);
    
      response := sys.utl_dbws.invoke(call_, request);
      --  dbms_output.put_line(response.getstringval());
      sys.utl_dbws.release_call(call_);
      sys.utl_dbws.release_service(service_);
      v_error := response.getstringval();
    
      IF response.getstringval() LIKE '%Error%' THEN
        p_status  := 'E';
        p_message := REPLACE(REPLACE(substr(v_error,
			        instr(v_error, 'instance') + 10,
			        length(v_error)),
			 '</OutPut>',
			 NULL),
		     '</processResponse>',
		     NULL);
      END IF;
    
    EXCEPTION
      WHEN OTHERS THEN
        dbms_output.put_line(substr(SQLERRM, 1, 250));
        v_error := substr(SQLERRM, 1, 250);
        fnd_file.put_line(fnd_file.log, 'v_error - ' || v_error);
        p_status  := 'E';
        p_message := 'Error Run Bpel Interface: ' || v_error;
        sys.utl_dbws.release_call(call_);
        sys.utl_dbws.release_service(service_);
    END;
    -- dbms_output.put_line(p_status);
  END call_bpel_process;
  -----------------------------------------------
  -- process_wip_interface
  ----------------------------------------------
  PROCEDURE process_wip_interface(p_object_id        IN NUMBER,
		          p_parent_object_id IN NUMBER,
		          p_status           OUT VARCHAR2,
		          p_message          OUT VARCHAR2) IS
  
    l_return_status VARCHAR2(1);
    l_msg_data      VARCHAR2(2000);
    l_msg_count     NUMBER;
    v_func          NUMBER;
    ---v_trans_count   NUMBER;
  BEGIN
    fnd_global.apps_initialize(g_user_id, 50606, 660);
    fnd_msg_pub.initialize;
  
    inv_genealogy_pub.insert_genealogy(p_api_version        => 1,
			   p_object_type        => 1,
			   p_parent_object_type => 1,
			   p_object_id          => p_object_id,
			   p_parent_object_id   => p_parent_object_id,
			   p_origin_txn_id      => 999,
			   x_return_status      => l_return_status,
			   x_msg_count          => l_msg_count,
			   x_msg_data           => l_msg_data);
  
    p_status  := l_return_status;
    p_message := l_return_status;
    dbms_output.put_line('v_func = ' || v_func);
    dbms_output.put_line(substr('x_returnstatus = ' || l_return_status,
		        1,
		        255));
    dbms_output.put_line(substr('x_errormsg = ' || l_msg_data, 1, 255));
  END process_wip_interface;
  ---------------------------------------------
  -- process_interface
  --------------------------------------------------------------------
  --  ver   date        name            desc
  --  1.2   16.5.2012   yuval tal       process_interface : add trim in item/assy/job search select
  --  1.3   18.08.2013  Vitaly          CR 870 std cost - change hard-coded organization (variable name v_wri_org changed to v_irk_organization_id)
  --  1.4   25.12.17    yuval tal       INC0110260 - add item filter to lot search 
  ---------------------------------------------
  PROCEDURE process_interface(errbuf       OUT VARCHAR2,
		      retcode      OUT VARCHAR2,
		      p_job_number IN VARCHAR2,
		      p_operation  IN VARCHAR2,
		      p_file_name  IN VARCHAR2) IS
    CURSOR cr_wip_jobs IS
      SELECT w.job_number,
	 w.assembly_item_number,
	 w.component,
	 w.weight,
	 w.lot,
	 w.time_stemp
      FROM   xxobjt_wip_job_trx w
      WHERE  w.error_code IS NULL
      AND    w.job_number = p_job_number;
  
    v_assembly_item_id    NUMBER;
    v_component_item_id   NUMBER;
    v_wip_entity_id       NUMBER;
    v_lot_number          VARCHAR2(80);
    v_qty_oh              NUMBER;
    v_trx_interface_id    NUMBER;
    l_return_status       VARCHAR2(1);
    l_msg_data            VARCHAR2(2000);
    l_msg_count           NUMBER;
    v_func                NUMBER;
    v_trans_count         NUMBER;
    v_gen_exist           VARCHAR2(1);
    v_parent_object_id    NUMBER;
    v_object_id           NUMBER;
    v_uom                 VARCHAR2(10);
    v_operation_seq_num   NUMBER;
    v_irk_organization_id NUMBER;
    l_directory           VARCHAR2(100);
  
    l_file_name VARCHAR2(100);
  
  BEGIN
  
    BEGIN
      SELECT user_id
      INTO   g_user_id
      FROM   fnd_user
      WHERE  user_name = 'SCHEDULER';
    EXCEPTION
      WHEN no_data_found THEN
        g_user_id := NULL;
    END;
  
    BEGIN
      SELECT mp.organization_id
      INTO   v_irk_organization_id
      FROM   mtl_parameters mp
      WHERE  mp.organization_code = 'IRK'; ---'WRI';
    EXCEPTION
      WHEN no_data_found THEN
        NULL;
    END;
  
    fnd_global.apps_initialize(g_user_id, 50623, 660);
  
    retcode := '0';
    --Call BPEL Process
  
    IF p_operation = 'SHKILA' THEN
      l_directory := '/Simplicity/Shkila/';
    ELSIF p_operation = 'REACTOR' THEN
      l_directory := '/Simplicity/Reactor/';
    ELSE
      l_directory := NULL;
    END IF;
  
    /* IF xxagile_util_pkg.get_bpel_domain != 'production' THEN
      l_directory := l_directory || 'DEV';
    END IF;*/
  
    l_file_name := xxobjt_general_utils_pkg.get_valueset_desc(p_set_code => 'XXOBJ_SIMPLICITY_OPERATIONS_FILES',
					  p_code     => p_file_name);
  
    fnd_file.put_line(fnd_file.log, 'l_file_name - ' || l_file_name);
    fnd_file.put_line(fnd_file.log, 'l_directory - ' || l_directory);
    fnd_file.put_line(fnd_file.log, 'p_job_number - ' || p_job_number);
  
    call_bpel_process(p_job_number, --'MTL12892',
	          l_directory,
	          l_file_name,
	          l_return_status,
	          l_msg_data);
  
    fnd_file.put_line(fnd_file.log,
	          'l_return_status - ' || l_return_status);
    IF l_return_status = 'S' THEN
      --Wait 20 SEC before continue
      dbms_lock.sleep(seconds => 20);
      FOR i IN cr_wip_jobs
      LOOP
      
        IF i.lot IS NOT NULL THEN
          v_uom := 'KG';
        ELSE
          v_uom := 'EA';
        END IF;
      
        IF retcode = '0' THEN
          --If there is problem with 1 component -> don't update the job
        
          BEGIN
	SELECT msi.inventory_item_id
	INTO   v_assembly_item_id
	FROM   mtl_system_items_b msi
	WHERE  msi.organization_id = v_irk_organization_id
	AND    msi.segment1 = TRIM(i.assembly_item_number);
          EXCEPTION
	WHEN no_data_found THEN
	  v_assembly_item_id := NULL;
	  retcode            := '2';
	  IF errbuf IS NULL THEN
	    errbuf := 'Assembly Item: ' || i.assembly_item_number ||
		  ' Not Exists In The System';
	  ELSE
	    errbuf := errbuf || chr(10) || 'Assembly Item: ' ||
		  i.assembly_item_number ||
		  ' Not Exists In The System';
	  END IF;
          END;
          BEGIN
	SELECT msi.inventory_item_id
	INTO   v_component_item_id
	FROM   mtl_system_items_b msi
	WHERE  msi.organization_id = v_irk_organization_id
	AND    msi.segment1 = TRIM(i.component);
          EXCEPTION
	WHEN no_data_found THEN
	  v_component_item_id := NULL;
	  retcode             := '2';
	  IF errbuf IS NULL THEN
	    errbuf := 'Component Item: ' || i.component ||
		  ' Not Exists In The System';
	  ELSE
	    errbuf := errbuf || chr(10) || 'Component Item: ' ||
		  i.component || ' Not Exists In The System';
	  END IF;
          END;
          BEGIN
	SELECT we.wip_entity_id
	INTO   v_wip_entity_id
	FROM   wip_entities we
	WHERE  we.organization_id = v_irk_organization_id
	AND    we.wip_entity_name = TRIM(i.job_number);
          EXCEPTION
	WHEN no_data_found THEN
	  v_wip_entity_id := NULL;
	  retcode         := '2';
	  IF errbuf IS NULL THEN
	    errbuf := 'job: ' || i.job_number ||
		  ' Not Exists In The System';
	  ELSE
	    errbuf := errbuf || chr(10) || 'job : ' || i.job_number ||
		  ' Not Exists In The System';
	  END IF;
          END;
        
          IF i.lot IS NOT NULL THEN
	BEGIN
	  SELECT ml.lot_number
	  INTO   v_lot_number
	  FROM   mtl_lot_numbers ml
	  WHERE  ml.organization_id = v_irk_organization_id
	  AND    ml.lot_number = i.lot
	  AND    ml.inventory_item_id = v_component_item_id; -- INC0110260
	EXCEPTION
	  WHEN no_data_found THEN
	    v_lot_number := NULL;
	    retcode      := '2';
	    IF errbuf IS NULL THEN
	      errbuf := 'Lot: ' || i.lot || ' Not Exists In The System';
	    ELSE
	      errbuf := errbuf || chr(10) || 'lot: ' || i.lot ||
		    ' Not Exists In The System';
	    END IF;
	END;
          END IF;
          BEGIN
	SELECT SUM(mo.transaction_quantity)
	INTO   v_qty_oh
	FROM   mtl_onhand_quantities_detail mo
	WHERE  mo.inventory_item_id = v_component_item_id
	AND    mo.organization_id = v_irk_organization_id
	AND    mo.subinventory_code = '1014'
	AND    decode(i.lot, NULL, 'a', mo.lot_number) =
	       nvl(i.lot, 'a'); --according to what?? also locator
          EXCEPTION
	WHEN no_data_found THEN
	  v_qty_oh := 0;
          END;
        
          BEGIN
	SELECT wr.operation_seq_num
	INTO   v_operation_seq_num
	FROM   wip_requirement_operations_v wr
	WHERE  wr.organization_id = v_irk_organization_id
	AND    wr.inventory_item_id = v_component_item_id
	AND    wr.wip_entity_id = v_wip_entity_id;
          EXCEPTION
	WHEN no_data_found THEN
	  v_operation_seq_num := NULL;
	  retcode             := '2';
	  IF errbuf IS NULL THEN
	    errbuf := 'Problem With Operation Seq Num';
	  ELSE
	    errbuf := errbuf || chr(10) ||
		  'Problem With Operation Seq Num';
	  END IF;
          END;
        
          /* IF v_qty_oh < i.weight THEN
             retcode := '2';
             IF errbuf IS NULL THEN
                errbuf := 'No OH QTY For Component: ' || i.component;
             ELSE
                errbuf := errbuf || chr(10) ||
                          'No OH QTY For Component: ' || i.component;
             END IF;
          END IF;*/
          IF retcode = '0' THEN
          
	SELECT mtl_material_transactions_s.nextval
	INTO   v_trx_interface_id
	FROM   dual;
	INSERT INTO mtl_transactions_interface
	  (inventory_item_id,
	   transaction_header_id,
	   transaction_interface_id,
	   source_code,
	   transaction_type_id,
	   transaction_uom,
	   transaction_quantity,
	   transaction_date,
	   -- transaction_reference,
	   organization_id,
	   distribution_account_id,
	   last_update_date,
	   source_header_id,
	   created_by,
	   flow_schedule,
	   process_flag,
	   transaction_mode,
	   creation_date,
	   subinventory_code,
	   scheduled_flag,
	   substitution_item_id,
	   substitution_type_id,
	   last_updated_by,
	   locator_id,
	   source_line_id,
	   revision,
	   transaction_cost,
	   new_average_cost,
	   final_completion_flag,
	   wip_entity_type,
	   transaction_source_id,
	   operation_seq_num)
	VALUES
	  (v_component_item_id,
	   999,
	   v_trx_interface_id,
	   'Wip',
	   35 /*WIP Issue*/,
	   v_uom,
	   i.weight * -1,
	   SYSDATE,
	   -- 'Empty SubInv',
	   v_irk_organization_id,
	   NULL,
	   SYSDATE,
	   v_trx_interface_id,
	   g_user_id,
	   'N',
	   '1',
	   '3', --'3',
	   SYSDATE,
	   '1014', --Check
	   '2',
	   '0',
	   '0',
	   g_user_id,
	   NULL,
	   v_trx_interface_id,
	   NULL,
	   NULL,
	   NULL,
	   NULL, --'Y',
	   1,
	   v_wip_entity_id,
	   v_operation_seq_num);
	IF i.lot IS NOT NULL THEN
	  INSERT INTO mtl_transaction_lots_interface
	    (transaction_interface_id,
	     last_update_date,
	     last_updated_by,
	     creation_date,
	     created_by,
	     last_update_login,
	     lot_number,
	     transaction_quantity,
	     primary_quantity,
	     product_code,
	     product_transaction_id) --link to rcv_transactions_interface
	  VALUES
	    (v_trx_interface_id,
	     SYSDATE,
	     g_user_id,
	     SYSDATE,
	     g_user_id,
	     g_user_id,
	     i.lot,
	     i.weight * -1,
	     1,
	     'RCV',
	     rcv_transactions_interface_s.nextval);
	END IF;
          
	UPDATE xxobjt_wip_job_trx w
	SET    w.error_code = 'S'
	WHERE  w.job_number = i.job_number
	AND    w.assembly_item_number = i.assembly_item_number
	AND    w.component = i.component
	AND    w.error_code IS NULL;
          END IF;
        
        ELSE
          dbms_output.put_line('first error = ');
          ROLLBACK;
        
          retcode := '2';
          errbuf  := 'Error When Trying To Run Material Interface(records NOT exist in the interface): ' ||
	         errbuf;
        
          UPDATE xxobjt_wip_job_trx w
          SET    w.error_code    = 'E',
	     w.error_message = errbuf
          WHERE  w.job_number = i.job_number
          AND    w.error_code IS NULL;
          COMMIT;
          EXIT; --Exit the loop
        END IF;
      END LOOP;
    
      --Run API to launch the interface
      IF retcode = '0' THEN
        COMMIT;
        fnd_msg_pub.initialize;
      
        fnd_file.put_line(fnd_file.log,
		  '--->  inv_txn_manager_pub.process_transactions');
      
        v_func := inv_txn_manager_pub.process_transactions(p_api_version   => '1.0',
				           p_header_id     => 999,
				           p_commit        => fnd_api.g_false,
				           x_return_status => l_return_status,
				           x_msg_count     => l_msg_count,
				           x_msg_data      => l_msg_data,
				           x_trans_count   => v_trans_count);
      
        dbms_output.put_line('v_func = ' || v_func);
        dbms_output.put_line(substr('x_returnstatus = ' || l_return_status,
			1,
			255));
        dbms_output.put_line(substr('x_errormsg = ' || l_msg_data, 1, 255));
      
        fnd_file.put_line(fnd_file.log,
		  'x_errormsg - ' ||
		  substr('x_errormsg = ' || l_msg_data, 1, 255));
      
        IF l_return_status = 'S' THEN
          COMMIT;
          FOR i IN cr_wip_jobs
          LOOP
	IF i.lot IS NOT NULL THEN
	  --Check if the combination of parent lot(JOB) and lot (come with component) exist. If not -> create the combination
	  BEGIN
	    SELECT ml.gen_object_id
	    INTO   v_object_id
	    FROM   mtl_lot_numbers ml
	    WHERE  ml.lot_number = i.lot
	    AND    ml.organization_id = v_irk_organization_id;
	  EXCEPTION
	    WHEN no_data_found THEN
	      v_object_id := NULL;
	  END;
	
	  BEGIN
	    SELECT ml.gen_object_id
	    INTO   v_parent_object_id
	    FROM   mtl_lot_numbers ml
	    WHERE  ml.lot_number = i.job_number
	    AND    ml.organization_id = v_irk_organization_id;
	  EXCEPTION
	    WHEN no_data_found THEN
	      v_parent_object_id := NULL;
	  END;
	
	  IF v_parent_object_id IS NOT NULL AND v_object_id IS NOT NULL THEN
	    dbms_output.put_line('before comb');
	    BEGIN
	      SELECT 'Y'
	      INTO   v_gen_exist
	      FROM   mtl_object_genealogy mo
	      WHERE  mo.object_id = v_object_id
	      AND    mo.parent_object_id = v_parent_object_id;
	    EXCEPTION
	      WHEN no_data_found THEN
	        dbms_output.put_line('comb');
	        --Call API To Generate Combination
	        l_return_status := NULL;
	        l_msg_data      := NULL;
	        process_wip_interface(v_object_id,
			      v_parent_object_id,
			      l_return_status,
			      l_msg_data);
	        IF l_return_status <> 'S' THEN
	          retcode := '1';
	          IF errbuf IS NULL THEN
		errbuf := 'Error When Trying To Create Genealogy (Lot: ' ||
		          i.lot || ', Parent Lot: ' || i.job_number ||
		          '): ' || l_msg_data;
	          ELSE
		errbuf := errbuf || chr(10) ||
		          'Error When Trying To Create Genealogy (Lot: ' ||
		          i.lot || ', Parent Lot: ' || i.job_number ||
		          '): ' || l_msg_data;
	          END IF;
	        END IF;
	    END;
	  END IF;
	END IF;
          END LOOP;
        
        ELSE
          retcode := '2';
          errbuf  := 'Error When Trying To Run Material Interface(records exist in the interface): ' ||
	         l_msg_data;
        
          UPDATE xxobjt_wip_job_trx w
          SET    w.error_code    = 'E',
	     w.error_message = 'Error When Trying To Run Material Interface: ' ||
		           l_msg_data
          WHERE  w.job_number = p_job_number
          AND    w.error_code IS NULL;
          COMMIT;
        
        END IF;
      END IF;
    ELSE
      --Error Calling BPEL
      retcode := '2';
      errbuf  := l_msg_data;
    END IF;
  END process_interface;

END xxwip_simplicity_jobs_trx_pkg;
/
