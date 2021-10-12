CREATE OR REPLACE PACKAGE BODY xxcs_hasp_pkg AS
  ---------------------------------------------------------------------------
  -- $Header: xx_cs_hasp_pkg   $
  ---------------------------------------------------------------------------
  -- Package: xx_cs_hasp_pkg
  -- Created:
  -- Author  :
  --------------------------------------------------------------------------
  -- Perpose: support hasp interface process cust419
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --     1.0  04.06.12   yuval tal       Initial Build
  --     1.1  07.08.12   yuval tal       CR467 : procedure initiate process -
  --                                            add hasp sn and order to WF attribute
  --     1.2  16.8.12    yuval tal       CR484 :procedure initiate process -
  --                                            add upgrade part type(UPGRADE KIT) to WF attribute
  --     1.3  9.9.12     yuval tal       CR496 modify call_safenet :HASP interface - logic change for saving at network directory
  --     1.4  19.06.14   Michal Tzvik    CHG0032163: Add logic for ?Installation? ? for the new process related to Order Management
  --                                     PROCEDURE initiate_hasp_table: add cursor c_inst.
  --                                     PROCEDURE update_hasp_header: add cursor c_inst.
  --                                     PROCEDURE insert_hasp_header: add field source_type to insert statement.
  --                                     PROCEDURE call_safenet: enable different file pefix for installation
  --                                     Enable BPEL 11G
  --                     yuval tal       procedure call_safenet : modify g_hasp_root_dir to local variable l_hasp_root_dir
  --                                     support directory for upgrade and installation according
  --                                     to profile XXCS_HASP_FILE_ROOT_DIR and XXCS_HASP_FILE_ROOT_INSTALL_DIR
  --  1.5  10.1.16       yuval tal       CHG0037403 - modify initiate_process , Hasp Notification - Seperate upgrade and installation notifications
  --  1.6  20.4.16       yuval tal       CHG0037918 migration to 12c support redirect between 2 servers
  --                                     modify :  call_safenet   ,download_files,upload_files
  --       19.06.2017    Lingaraj(TCS)   CHG0040890 - updated the upgrade advisor to support selling an upgrade in an initial sale
  --  1.7  8.2.18        yuval tal       CHG0042312  add port support by profile , modify   call_safenet  ,get_safenet_user_pass
  --  1.8  09/04/2019    Bellona B.      INC0153077 - called from XXCSHASP.fmb
  --                                            submits conc program XXCS: Hasp Initiate Process
  --  1.9  16/05/2019    Roman W.        INC0156901 - HASP process not completeWhen clicking resubmit
  --                                             added writing to log
  --  2.0  22/07/2019    Roman W.        INC0163990 - Activation key is late to come
  --  2.1  08/12/2019    Roman W.        INC0177120 - added COMMIT to insert_hasp_header
  --  2.2  03/06/2020    Roman W.        CHG0048021 - PZ Move to MY SSYS
  --  2.3  15.12.20      yuval tal       CHG0048579 - modify upload_files,download_files, call_safenet  add  call_safenet_oic  ,
  --                                                download_files_oic,upload_files_oic
  ---------------------------------------------------------------------------------------------------------------------------------
  g_item_type           VARCHAR2(50) := 'XXCSHASP';
  g_workflow_process    VARCHAR2(50) := 'MAIN';
  g_flow_code_oracle    VARCHAR2(50) := 'ORACLE';
  g_flow_code_safenet   VARCHAR2(50) := 'SAFENET';
  g_flow_code_pz_send   VARCHAR2(50) := 'PZ_SEND';
  g_flow_code_pz_rcv    VARCHAR2(50) := 'PZ_RCV';
  g_flow_code_wf        VARCHAR2(50) := 'WF_SUBMIT';
  g_flow_code_completed VARCHAR2(50) := 'COMPLETE';
  g_flow_code_exists_so VARCHAR2(50) := 'FIND_SO';
  g_batch_id            NUMBER := 2;

  --1.4  29.06.14   Michal Tzvik    CHG003216
  g_upgrade      CONSTANT VARCHAR2(50) := 'Upgrade';
  g_installation CONSTANT VARCHAR2(50) := 'Installation';
  g_err_ind VARCHAR2(10);

  -- bpel
  g_db_jndi_name VARCHAR2(50) := xxobjt_bpel_utils_pkg.get_jndi_name(NULL); --'eis/DB/PATCH'; --

  g_ftp_jndi_name VARCHAR2(50) := get_ftp_jndi_info; --'eis/Ftp/HASP/DEV';

  -- 1.4  19.11.14   Michal Tzvik    CHG003216: put g_bpel_host in a remark.
  --g_enable_hasp_bpel11g VARCHAR2(1) := nvl(fnd_profile.value('XXCS_ENABLE_HASP_BPEL11G'),
  --'N');
  -- g_bpel_host VARCHAR2(300) := xxobjt_bpel_utils_pkg.get_bpel_host; --'http://soatestapps.2objet.com:7777/orabpel/';
  /* g_hasp_root_dir     VARCHAR2(240) :=  \*'/mnt/hasp/' ||*\
  fnd_profile.value('XXCS_HASP_FILE_ROOT_DIR') || '/' || -- /UtlFiles/shared
                                      sys_context('USERENV', 'DB_NAME') || '/';*/
  g_hasp_root_dir_bck    VARCHAR2(240) := fnd_profile.value('XXCS_HASP_FILE_ROOT_DIR_BCK') || '/'; --'/usr/tmp/hasp/';
  g_oic_hasp_service     VARCHAR2(15) := 'HASP'; -- CHG0048579
  g_oic_hasp_ftp_service VARCHAR2(15) := 'HASP_FTP'; -- CHG0048579
  -----------------------------------------------------------------------------
  -- Version  When        Who           Comments
  ----------  ----------  ------------  ---------------------------------------
  --  1.0     10/04/2019  Bellona B.    initial build -> print log messages
  -----------------------------------------------------------------------------
  PROCEDURE message(p_msg VARCHAR2) IS
  
    l_msg VARCHAR2(3000);
  BEGIN
  
    l_msg := to_char(SYSDATE, 'DD/MM/YYYY HH24:MI:SS') || ' : ' || p_msg;
  
    IF fnd_global.conc_request_id != -1 THEN
      fnd_file.put_line(fnd_file.log, l_msg);
    ELSE
      dbms_output.put_line(l_msg);
    END IF;
  
  END message;

  ---------------------------------------------------------
  -- GET_FTP_SERVER_INFO
  --------------------------------------------------------
  FUNCTION get_ftp_jndi_info(p_env VARCHAR2 DEFAULT NULL) RETURN VARCHAR2
  
   IS
    l_env VARCHAR2(10);
  
  BEGIN
    l_env := p_env;
    IF l_env IS NULL THEN
      l_env := xxagile_util_pkg.get_bpel_domain;
    
    END IF;
  
    CASE
      WHEN l_env = 'production' THEN
      
        RETURN(fnd_profile.value('XXCS_HASP_FTP_JNDI_PROD'));
      WHEN l_env = 'default' THEN
      
        RETURN(fnd_profile.value('XXCS_HASP_FTP_JNDI_DEV'));
      
    END CASE;
    RETURN NULL;
  EXCEPTION
    WHEN OTHERS THEN
    
      RETURN NULL;
    
  END;

  --------------------------------------------------------------------
  --  customization code: CHG0032163
  --  name:               get_inst_group_number
  --  create by:          Michal Tzvik
  --  Revision:
  --  creation date:
  --  Purpose :           Get group number for Installation records
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.1   10.08.14      Michal Tzvik    Initial Build
  -------------------------------
  FUNCTION get_inst_group_number(p_org_id NUMBER) RETURN VARCHAR2 IS
    l_group_number fnd_lookup_values_vl.description%TYPE;
  BEGIN
    SELECT flv.description
    INTO   l_group_number
    FROM   fnd_lookup_values_vl flv
    WHERE  flv.lookup_type = 'XXCS_HASP_GROUP_MAPPING'
    AND    flv.enabled_flag = 'Y'
    AND    SYSDATE BETWEEN nvl(flv.start_date_active, SYSDATE - 1) AND
           nvl(flv.end_date_active, SYSDATE + 1)
    AND    flv.lookup_code = p_org_id;
  
    RETURN l_group_number;
  
  END get_inst_group_number;
  --------------------------------------------------------------------
  --  customization code:
  --  name:               update_hasp_header
  --  create by:          Yuval Tal
  --  Revision:
  --  creation date:
  --  Purpose :           Initiate hasp table
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.1   23.06.14      Michal Tzvik    CHG0032163: Add logic for ?Installation? ? for the new process related to Order Management
  --  1.1   05.07.15      yuval tal       CHG0035824 : split cursor  c to c and c_interface due to performence issue
  ----------------------------------------------------------------------
  PROCEDURE update_hasp_header(p_hasp_interface_id NUMBER)
  
   IS
    l_new_region    VARCHAR2(50);
    l_printers_type VARCHAR2(50);
    l_direct        VARCHAR2(50);
    l_group_number  VARCHAR2(50);
  
    l_line_id      NUMBER;
    l_order_number VARCHAR2(50);
    l_instance_id  NUMBER;
  
    CURSOR c(c_line_id      NUMBER,
	 c_order_number VARCHAR2) IS
      SELECT t.*
      FROM   xxcs_hasp_upgrade_v t
      -- xxcs_hasp_headers   h
      WHERE  -- h.hasp_interface_id = p_hasp_interface_id
       t.line_id = c_line_id
       AND    t.order_number = c_order_number;
  
    CURSOR c_inst(c_instance_id NUMBER) IS -- 1.1  Michal Tzvik CHG0032163
      SELECT t.*
      FROM   xxom_hasp_installation_v t
      WHERE  t.instance_id = c_instance_id;
  
    /* Rem by Roman W. 08/12/2019
    CURSOR c_interface(c_hasp_interface_id NUMBER) IS
      SELECT h.order_line_id, h. order_number, h.instance_id
        FROM xxcs_hasp_headers h
       WHERE h.hasp_interface_id = c_hasp_interface_id;
    */
  BEGIN
    message(' IN update_hasp_header(' || p_hasp_interface_id || ')');
    -- INC0163990
    /* Rem by Roman W.
    OPEN c_interface(p_hasp_interface_id);
    FETCH c_interface
      INTO l_line_id, l_order_number, l_instance_id;
    
    CLOSE c_interface;
    */
    SELECT h.order_line_id,
           h. order_number,
           h.instance_id
    INTO   l_line_id,
           l_order_number,
           l_instance_id
    FROM   xxcs_hasp_headers h
    WHERE  h.hasp_interface_id = p_hasp_interface_id
    AND    rownum = 1;
  
    message('1.1 l_line_id      - ' || l_line_id || ',' || chr(10) ||
	'l_order_number - ' || l_order_number || ',' || chr(10) ||
	'l_instance_id  - ' || l_instance_id);
  
    FOR i IN c(l_line_id, l_order_number)
    LOOP
    
      l_new_region := xxobjt_general_utils_pkg.get_valueset_attribute(p_set_code       => 'XXCS_CS_REGIONS',
					          p_code           => i.cs_region,
					          p_attribute_name => 'ATTRIBUTE9');
    
      l_printers_type := xxobjt_general_utils_pkg.get_lookup_attribute(p_lookup_type        => 'XXCSI_UPGRADE_TYPE',
					           p_lookup_description => i.segment1,
					           p_attribute_name     => 'ATTRIBUTE8');
    
      -- Set group number
      -- check custom group number overide default logic
    
      IF fnd_profile.value('XXCS_HASP_CUSTOM_GROUP_NUMBER') IS NOT NULL THEN
        l_group_number := fnd_profile.value('XXCS_HASP_CUSTOM_GROUP_NUMBER');
      
      ELSE
      
        l_group_number := i.owner_account_number;
        l_direct       := xxobjt_general_utils_pkg.get_valueset_attribute(p_set_code       => 'XXCS_CS_REGIONS',
						  p_code           => i.cs_region,
						  p_attribute_name => 'ATTRIBUTE10');
      
        IF l_direct = 'Direct' THEN
          l_group_number := xxobjt_general_utils_pkg.get_valueset_attribute(p_set_code       => 'XXCS_CS_REGIONS',
						    p_code           => i.cs_region,
						    p_attribute_name => 'ATTRIBUTE11');
        
        END IF;
      END IF;
    
      message('1.2 before update');
    
      UPDATE xxcs_hasp_headers t
      SET    t.group_number     = l_group_number,
	 t.orig_region_name = i.cs_region,
	 t.region_name      = l_new_region,
	 t.printers_type    = l_printers_type
      WHERE  t.hasp_interface_id = p_hasp_interface_id;
    
      message('1.3 after update');
    
      COMMIT;
    END LOOP;
  
    message('1.4 l_instance_id - ' || l_instance_id);
  
    -- 1.1  Michal Tzvik CHG0032163: start
    FOR i IN c_inst(l_instance_id)
    LOOP
      l_new_region    := i.org; /*xxobjt_general_utils_pkg.get_valueset_attribute(p_set_code       => 'XXCS_CS_REGIONS',
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          p_code           => i.cs_region,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          p_attribute_name => 'ATTRIBUTE9');*/
      l_printers_type := i.printer_type;
    
      -- Set group number
      IF i.org_id IS NOT NULL THEN
        l_group_number := get_inst_group_number(i.org_id);
      END IF;
    
      message('1.5 before update');
      UPDATE xxcs_hasp_headers t
      SET    t.group_number     = l_group_number,
	 t.orig_region_name = i.org,
	 t.region_name      = l_new_region,
	 t.printers_type    = l_printers_type
      WHERE  t.hasp_interface_id = p_hasp_interface_id;
    
      message('1.6 before update');
    
      COMMIT;
    END LOOP;
    -- 1.1  Michal Tzvik CHG0032163: end
    message('1.7 end update_hasp_header');
  END update_hasp_header;
  ---------------------------------------------------------
  -- get_safnet_user_pass
  --
  -- get safent user password according to env
  --------------------------------------------------------------------------
  -- Version  Date         Performer       Comments
  ----------  --------     --------------  -------------------------------------

  --    1.1   8.2.18       yuval tal       -- CHG0042312 get port from profiles
  --                                        XXCS_DEV_HASP_PORT/XXCS_PROD_HASP_PORT

  --------------------------------------------------------
  PROCEDURE get_safenet_user_pass(p_user_name      OUT VARCHAR2,
		          p_password       OUT VARCHAR2,
		          p_safenet_server OUT VARCHAR2,
		          p_endpoint_url   OUT VARCHAR2,
		          p_port           OUT VARCHAR2, -- CHG0042312
		          p_env            IN OUT VARCHAR2,
		          
		          p_err_code OUT VARCHAR2,
		          p_err_msg  OUT VARCHAR2) IS
  BEGIN
    p_err_code := 0;
    IF p_env IS NULL THEN
      p_env := xxagile_util_pkg.get_bpel_domain;
    
    END IF;
  
    CASE
      WHEN p_env = 'production' THEN
        p_user_name      := fnd_profile.value('XXCS_PROD_HASP_USER');
        p_password       := fnd_profile.value('XXCS_PROD_HASP_PASS');
        p_safenet_server := fnd_profile.value('XXCS_PROD_HASP_SERVER');
        p_endpoint_url   := fnd_profile.value('XXCS_HASP_ENDPOINT_ADDRESS_URL_PROD');
        p_port           := fnd_profile.value('XXCS_PROD_HASP_PORT'); -- CHG0042312
      WHEN p_env = 'default' THEN
        p_user_name      := fnd_profile.value('XXCS_DEV_HASP_USER');
        p_password       := fnd_profile.value('XXCS_DEV_HASP_PASS');
        p_safenet_server := fnd_profile.value('XXCS_DEV_HASP_SERVER');
        p_endpoint_url   := fnd_profile.value('XXCS_HASP_ENDPOINT_ADDRESS_URL_DEV');
        p_port           := fnd_profile.value('XXCS_DEV_HASP_PORT'); -- CHG0042312
    -- 'testhasp2';
    END CASE;
  EXCEPTION
    WHEN OTHERS THEN
      p_user_name := NULL;
      p_password  := NULL;
      p_env       := NULL;
      p_err_code  := 1;
      p_err_msg   := 'xxcs_hasp_pkg.get_hasp_user_pass :' ||
	         substr(SQLERRM, 1, 240);
  END;

  -------------------------------------------------------
  -- update_header_status
  -------------------------------------------------------
  PROCEDURE update_header_status(p_hasp_interface_id NUMBER,
		         p_status            VARCHAR2,
		         p_flow_code         VARCHAR2 DEFAULT NULL) IS
    -- PRAGMA AUTONOMOUS_TRANSACTION;
  BEGIN
  
    UPDATE xxcs_hasp_headers t
    SET    t.status_code    = p_status,
           t.flow_code      = nvl(p_flow_code, t.flow_code),
           last_update_date = SYSDATE,
           last_updated_by  = fnd_global.user_id
    
    WHERE  t.hasp_interface_id = p_hasp_interface_id;
    COMMIT;
  END;
  -------------------------------------------------------
  -- update_header_status_wf
  -------------------------------------------------------

  PROCEDURE update_header_err_wf(itemtype  IN VARCHAR2,
		         itemkey   IN VARCHAR2,
		         actid     IN NUMBER,
		         funcmode  IN VARCHAR2,
		         resultout OUT NOCOPY VARCHAR2) IS
    l_hasp_interface_id NUMBER;
  BEGIN
    l_hasp_interface_id := wf_engine.getitemattrnumber(itemtype => itemtype,
				       itemkey  => itemkey,
				       aname    => 'HASP_INTERFACE_ID');
    update_header_status(l_hasp_interface_id, 'E');
    resultout := wf_engine.eng_completed;
  END;

  -------------------------------------------------------
  -- insert_log
  -------------------------------------------------------

  PROCEDURE insert_log(p_rec         xxcs_hasp_log%ROWTYPE,
	           p_delete_flag VARCHAR2 DEFAULT 'N') IS
    PRAGMA AUTONOMOUS_TRANSACTION;
  BEGIN
    dbms_lock.sleep(1);
    IF p_delete_flag = 'Y' THEN
      DELETE FROM xxcs_hasp_log t
      WHERE  t.hasp_interface_id = p_rec.hasp_interface_id
      AND    flow_code = p_rec.flow_code
      AND    log_code = p_rec.log_code
      AND    open_flag = 'Y';
    END IF;
  
    INSERT INTO xxcs_hasp_log
      (hasp_interface_id,
       flow_code,
       log_code,
       description,
       open_flag,
       last_update_date,
       last_updated_by,
       creation_date,
       created_by,
       last_update_login)
    VALUES
    
      (p_rec.hasp_interface_id,
       p_rec.flow_code,
       p_rec.log_code,
       substr(p_rec.description, 1, 2000),
       'Y', --OPEN_FLAG,
       SYSDATE,
       NULL,
       SYSDATE,
       fnd_global.user_id, --CREATED_BY,
       fnd_global.login_id);
    COMMIT;
  END;
  ----------------------------------------------
  -- close open errors
  ----------------------------------------------

  PROCEDURE close_open_erros(p_hasp_interface_id NUMBER) IS
  BEGIN
  
    UPDATE xxcs_hasp_log t
    SET    t.open_flag = 'N'
    WHERE  t.hasp_interface_id = p_hasp_interface_id;
    -- COMMIT;
  END;
  --------------------------------------------------------------------
  --  customization code:
  --  name:               insert_hasp_header
  --  create by:          Yuval Tal
  --  Revision:
  --  creation date:
  --  Purpose :           Initiate hasp table
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.1   29.06.14      Michal Tzvik    CHG0032163: Add logic for ?Installation? ? for the new process related to Order Management:
  --                                      add field source_type to insert statement.
  --  1.2   08/12/2019    Roman W.        INC0177120 - added COMMIT

  -------------------------------
  FUNCTION insert_hasp_header(p_rec xxcs_hasp_headers%ROWTYPE) RETURN NUMBER IS
    l_seq           NUMBER;
    l_new_region    VARCHAR2(50);
    l_printers_type VARCHAR2(50);
    l_direct        VARCHAR2(50);
    l_group_number  VARCHAR2(50);
    l_commit_flag   VARCHAR2(50);
  BEGIN
    /*  l_new_region := xxobjt_general_utils_pkg.get_valueset_attribute(p_set_code       => 'XXCS_CS_REGIONS',
                                                                    p_code           => p_rec.orig_region_name,
                                                                    p_attribute_name => 'ATTRIBUTE9');
    
    l_printers_type := xxobjt_general_utils_pkg.get_lookup_attribute(p_lookup_type        => 'XXCSI_UPGRADE_TYPE',
                                                                     p_lookup_description => p_rec.upgrade_kit,
                                                                     p_attribute_name     => 'ATTRIBUTE8');
    
    -- Set group number
    -- check custom group number overide default logic
    
    IF fnd_profile.value('XXCS_HASP_CUSTOM_GROUP_NUMBER') IS NOT NULL THEN
      l_group_number := fnd_profile.value('XXCS_HASP_CUSTOM_GROUP_NUMBER');
    
    ELSE
    
      l_group_number := p_rec.group_number;
      l_direct       := xxobjt_general_utils_pkg.get_valueset_attribute(p_set_code       => 'XXCS_CS_REGIONS',
                                                                        p_code           => p_rec.orig_region_name,
                                                                        p_attribute_name => 'ATTRIBUTE10');
    
      IF l_direct = 'Direct' THEN
        l_group_number := xxobjt_general_utils_pkg.get_valueset_attribute(p_set_code       => 'XXCS_CS_REGIONS',
                                                                          p_code           => p_rec.orig_region_name,
                                                                          p_attribute_name => 'ATTRIBUTE11');
    
      END IF;
    END IF;*/
  
    ---
  
    INSERT INTO xxcs_hasp_headers
      (hasp_interface_id,
       printer_sn,
       hasp_sn,
       key_pn,
       order_header_id,
       order_line_id,
       status_code,
       flow_code,
       -- region_name,
       --  orig_region_name,
       --  printers_type,
       item_type,
       item_key,
       creation_date,
       created_by,
       order_number,
       --  group_number,
       upgrade_kit,
       -- 1.1   29.06.14      Michal Tzvik    CHG0032163
       source_type,
       is_basis_hasp,
       instance_id)
    VALUES
      (xxcs_hasp_headers_seq.nextval, --hasp_interface_id,
       p_rec.printer_sn,
       
       p_rec.hasp_sn,
       p_rec.key_pn,
       p_rec.order_header_id,
       p_rec.order_line_id,
       'N',
       'NEW',
       --  l_new_region,
       --  p_rec.orig_region_name, --
       --   l_printers_type,
       p_rec.item_type,
       p_rec.item_key,
       SYSDATE,
       fnd_global.user_id,
       p_rec.order_number,
       --   l_group_number,
       p_rec.upgrade_kit,
       --1.1   29.06.14      Michal Tzvik    CHG0032163
       p_rec.source_type,
       p_rec.is_basis_hasp,
       p_rec.instance_id)
    RETURNING hasp_interface_id INTO l_seq;
  
    l_commit_flag := nvl(fnd_profile.value('XXCS_HASP_HEADER_COMMIT_FLAG'),
		 'N');
  
    IF 'Y' = l_commit_flag THEN
      COMMIT;
    END IF;
  
    update_hasp_header(l_seq);
  
    RETURN l_seq;
  END;

  --------------------------------------------------------------------
  --  customization code:
  --  name:               check_initial_params_wf
  --  create by:          Yuval Tal
  --  Revision:
  --  creation date:
  --  Purpose :           validate initial parameters, decide how to continue the process
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.1   29.06.14      Michal Tzvik    CHG0032163: Add logic for ?Installation? ? for the new process related to Order Management
  --                                      Parameter p_err_code values:
  --                                      1 - failure
  --                                      2 - create file
  --                                      3 - upload file (no need to create)
  --                                      change resultout parameter respectively
  -------------------------------
  PROCEDURE check_initial_params_wf(itemtype  IN VARCHAR2,
			itemkey   IN VARCHAR2,
			actid     IN NUMBER,
			funcmode  IN VARCHAR2,
			resultout OUT NOCOPY VARCHAR2) IS
  
    l_header_rec  xxcs_hasp_headers%ROWTYPE;
    l_err_code    NUMBER;
    l_err_message VARCHAR2(2000);
  BEGIN
    l_header_rec.hasp_interface_id := wf_engine.getitemattrnumber(itemtype => itemtype,
					      itemkey  => itemkey,
					      aname    => 'HASP_INTERFACE_ID');
  
    check_initial_params(p_hasp_interface_id => l_header_rec.hasp_interface_id,
		 p_err_code          => l_err_code,
		 p_err_message       => l_err_message);
  
    /*   IF l_err_code = 0 THEN
      resultout := wf_engine.eng_completed || ':' || 'Y';
    
    ELSE
      resultout := wf_engine.eng_completed || ':' || 'N';
    
    END IF;*/
  
    --1.1   29.06.14  Michal Tzvik  CHG0032163: start
    IF l_err_code = 1 THEN
      resultout := wf_engine.eng_completed || ':' || 'FAIL';
    
    ELSIF l_err_code = 2 THEN
      resultout := wf_engine.eng_completed || ':' || 'CREATE_FILE';
    
    ELSIF l_err_code = 3 THEN
      resultout := wf_engine.eng_completed || ':' || 'UPLOAD_XML';
    
    END IF;
    -- 1.1   29.06.14  Michal Tzvik  CHG0032163: end
  
  EXCEPTION
    WHEN OTHERS THEN
      wf_core.context('XXCS_HASP_PKG',
	          'CHECK_INITIAL_PARAMS_WF',
	          itemtype,
	          itemkey,
	          to_char(actid),
	          funcmode,
	          'Others',
	          'hasp_interface_id: ' ||
	          l_header_rec.hasp_interface_id,
	          SQLERRM);
      RAISE;
  END;

  --------------------------------------------------------------------
  --  customization code:
  --  name:               check_initial_params
  --  create by:          Yuval Tal
  --  Revision:
  --  creation date:
  --  Purpose :           Initiate hasp table
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.1   29.06.14      Michal Tzvik    CHG0032163: Add logic for ?Installation? ? for the new process related to Order Management
  --                                      Parameter p_err_code values:
  --                                      1 - failure
  --                                      2 - create file
  --                                      3 - upload file (no need to create)
  -------------------------------

  PROCEDURE check_initial_params(p_hasp_interface_id NUMBER,
		         p_err_code          OUT NUMBER,
		         p_err_message       OUT VARCHAR2) IS
    l_rec_log    xxcs_hasp_log%ROWTYPE;
    l_rec_header xxcs_hasp_headers%ROWTYPE;
    myexception EXCEPTION;
  BEGIN
  
    update_header_status(p_hasp_interface_id, 'P', g_flow_code_oracle);
  
    l_rec_log.hasp_interface_id := p_hasp_interface_id;
    l_rec_log.flow_code         := g_flow_code_oracle;
    l_rec_log.log_code          := 'I';
    l_rec_log.description       := 'Start Initial Checks';
    insert_log(l_rec_log);
  
    SELECT *
    INTO   l_rec_header
    FROM   xxcs_hasp_headers t
    WHERE  t.hasp_interface_id = p_hasp_interface_id;
  
    -- check if file already created
    -- IF l_rec_header.v2c_file_name IS NOT NULL THEN
    --    p_err_code := 'File Already created';
    --   RAISE myexception;
  
    --  END IF;
    --
  
    -- check unique
  
    --- check mandatory fields
  
    IF -- 1.1 Michal Tzvik: handle ATO
     NOT (l_rec_header.source_type = g_installation AND
      l_rec_header.order_header_id IS NULL) THEN
    
      IF l_rec_header.orig_region_name IS NULL THEN
        p_err_message := 'Region Name is missing';
        RAISE myexception;
      END IF;
    
      IF l_rec_header.region_name IS NULL THEN
        p_err_message := 'Map Region Name is missing for [' ||
		 l_rec_header.orig_region_name ||
		 '] , see Valueset XXCS_CS_REGIONS';
        RAISE myexception;
      END IF;
    END IF;
  
    IF l_rec_header.printer_sn IS NULL THEN
      p_err_message := 'Printer SN is missing';
      RAISE myexception;
    END IF;
  
    IF l_rec_header.key_pn IS NULL THEN
      p_err_message := 'Key PN is missing';
      RAISE myexception;
    END IF;
  
    IF l_rec_header.hasp_sn IS NULL THEN
      p_err_message := 'Hasp SN is missing';
      RAISE myexception;
    END IF;
  
    IF l_rec_header.printers_type IS NULL THEN
      p_err_message := 'Printer type is missing';
    
      RAISE myexception;
    END IF;
  
    IF l_rec_header.source_type = g_upgrade THEN
      -- 1.1  29.06.14  Michal Tzvik  CHG0032163
      IF l_rec_header.group_number IS NULL THEN
        p_err_message := 'Group Number is missing';
      
        RAISE myexception;
      END IF;
    END IF;
  
    --
    -- check if the printer SN was in 2 or above orders with same upgrade kit.
    --
    DECLARE
      l_tmp NUMBER := 0;
    BEGIN
      /* SELECT COUNT(*)
       INTO l_tmp -- should be only 1
       FROM oe_order_lines_all    oola,
            wsh_delivery_details  wdd,
            csi_item_instances    cii,
            xxcs_sales_ug_items_v u
      WHERE oola.inventory_item_id = u.upgrade_item_id
        AND oola.line_id = wdd.source_line_id
        AND oola.flow_status_code != 'CANCELLED'
        AND wdd.released_status = 'C'
        AND oola.attribute1 = cii.instance_id
        AND cii.serial_number = l_rec_header.printer_sn --[PRINETER_SN]
        AND oola.ordered_item = l_rec_header.upgrade_kit --[UPGRADE KIT]
        AND cii.inventory_item_id = u.before_upgrade_item;*/
    
      SELECT COUNT(DISTINCT oola.header_id)
      INTO   l_tmp -- should be only 1
      FROM   oe_order_headers_all  ooha,
	 oe_order_lines_all    oola,
	 wsh_delivery_details  wdd,
	 csi_item_instances    cii,
	 xxcs_sales_ug_items_v u
      WHERE  oola.inventory_item_id = u.upgrade_item_id
      AND    ooha.header_id = oola.header_id
      AND    oola.line_id = wdd.source_line_id
      AND    oola.flow_status_code != 'CANCELLED'
      AND    wdd.released_status = 'C'
      AND    oola.attribute1 = cii.instance_id
      AND    cii.serial_number = l_rec_header.printer_sn --[PRINETER_SN]
      AND    oola.ordered_item = l_rec_header.upgrade_kit --[UPGRADE KIT]
      AND    nvl(cii.attribute4, nvl(u.from_sw_version, 1)) =
	 nvl(u.from_sw_version, 1)
      AND    nvl(u.before_upgrade_hasp, -1) =
	 nvl((SELECT cii_child.inventory_item_id
	      FROM   csi_ii_relationships  cir,
		 csi_item_instances    cii_child,
		 csi_instance_statuses cis
	      WHERE  cir.object_id = cii.instance_id
	      AND    cir.relationship_type_code = 'COMPONENT-OF'
	      AND    cir.active_end_date IS NULL
	      AND    cii_child.instance_id = cir.subject_id
	      AND    cii_child.instance_status_id =
		 cis.instance_status_id
	      AND    cis.terminated_flag = 'N'
	      AND    cii_child.inventory_item_id =
		 u.before_upgrade_hasp),
	      -1)
      AND    cii.inventory_item_id = u.before_upgrade_item;
    
      IF l_tmp > 1 THEN
        p_err_message := 'Printer SN :' || l_rec_header.printer_sn ||
		 ' exists in 2 SO';
        RAISE myexception;
      END IF;
    
    END;
  
    ---
    -- check if the HASP_SN related to other printer
    --
    DECLARE
      l_tmp NUMBER := 0;
    BEGIN
    
      SELECT 1
      INTO   l_tmp
      FROM   csi_item_instances cii,
	 mtl_system_items_b msi
      WHERE  msi.inventory_item_id = cii.inventory_item_id
      AND    msi.organization_id =
	 xxinv_utils_pkg.get_master_organization_id(NULL)
      AND    cii.instance_id IN
	 (SELECT cir.subject_id
	   FROM   csi_ii_relationships cir
	   WHERE  cir.object_id IN
	          (SELECT cii_printer.instance_id
	           FROM   csi_item_instances cii_printer
	           WHERE  cii_printer.serial_number !=
		      l_rec_header.printer_sn))
      AND    nvl(cii.active_end_date, SYSDATE) > SYSDATE - 1
      AND    cii.serial_number = l_rec_header.hasp_sn
      AND    rownum = 1;
    
    EXCEPTION
      WHEN no_data_found THEN
        NULL;
      WHEN OTHERS THEN
        p_err_message := 'Hasp SN ' || l_rec_header.hasp_sn ||
		 ' belong to other printer';
        RAISE myexception;
    END;
  
    --
    -- check unique
    --
    /* DECLARE
      l_tmp NUMBER;
    BEGIN
      SELECT t.hasp_interface_id
        INTO l_tmp
        FROM xxcs_hasp_headers t
       WHERE t.hasp_interface_id != l_rec_header.hasp_interface_id
         AND t.hasp_sn = l_rec_header.hasp_sn
         AND t.key_pn = l_rec_header.key_pn
         AND t.printer_sn = l_rec_header.printer_sn
         AND rownum = 1;
    
      p_err_message := 'Duplicate Error : check hasp interface id number ' ||
                       l_tmp;
    
      RAISE myexception;
    EXCEPTION
      WHEN no_data_found THEN
        NULL;
    
    END;*/
    --
    --
    --
    -- 1.1  29.06.14  Michal Tzvik  CHG0032163: start
    IF l_rec_header.source_type = g_installation AND
       l_rec_header.is_basis_hasp = 'Y' THEN
      p_err_code := 3;
    ELSE
      p_err_code := 2;
    END IF;
    -- 1.1  29.06.14  Michal Tzvik  CHG0032163: end
  
    --------------------- end checks ----------------------------
    update_header_status(p_hasp_interface_id, 'S', g_flow_code_oracle);
    -- p_err_code    := 2; -- Removed.    1.1  29.06.14  Michal Tzvik  CHG0032163
    p_err_message := 'Validation Check successfuly passed';
    COMMIT;
  EXCEPTION
  
    WHEN myexception THEN
    
      p_err_code                  := 1;
      l_rec_log.hasp_interface_id := p_hasp_interface_id;
      l_rec_log.flow_code         := g_flow_code_oracle;
      l_rec_log.log_code          := 'E';
      l_rec_log.description       := p_err_message;
    
      insert_log(l_rec_log);
      update_header_status(p_hasp_interface_id, 'E');
      COMMIT;
    WHEN OTHERS THEN
      update_header_status(p_hasp_interface_id, 'E');
      l_rec_log.hasp_interface_id := p_hasp_interface_id;
      l_rec_log.flow_code         := g_flow_code_oracle;
      l_rec_log.log_code          := 'E';
      l_rec_log.description       := 'check_initial_params' || ' ' ||
			 SQLERRM;
    
      insert_log(l_rec_log);
      p_err_code    := 1;
      p_err_message := SQLERRM;
      COMMIT;
  END;

  -----------------------------------------------
  -- call_safenet_wf
  ----------------------------------------------

  PROCEDURE call_safenet_wf(itemtype  IN VARCHAR2,
		    itemkey   IN VARCHAR2,
		    actid     IN NUMBER,
		    funcmode  IN VARCHAR2,
		    resultout OUT NOCOPY VARCHAR2) IS
  
    l_header_rec  xxcs_hasp_headers%ROWTYPE;
    l_err_code    NUMBER;
    l_err_message VARCHAR2(2000);
  BEGIN
  
    l_header_rec.hasp_interface_id := wf_engine.getitemattrnumber(itemtype => itemtype,
					      itemkey  => itemkey,
					      aname    => 'HASP_INTERFACE_ID');
  
    call_safenet(p_hasp_interface_id => l_header_rec.hasp_interface_id,
	     p_err_code          => l_err_code,
	     p_err_message       => l_err_message);
  
    IF l_err_code = 0 THEN
      resultout := wf_engine.eng_completed || ':' || 'Y';
    
    ELSE
      resultout := wf_engine.eng_completed || ':' || 'N';
    
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      wf_core.context('XXCS_HASP_PKG',
	          'UPLOAD_FILES',
	          itemtype,
	          itemkey,
	          to_char(actid),
	          funcmode,
	          'Others',
	          'hasp_interface_id: ' ||
	          l_header_rec.hasp_interface_id,
	          SQLERRM);
      RAISE;
  END;

  --------------------------------------------------------------------
  --  customization code:
  --  name:               call_safenet_oic 
  --  create by:          yuval tal
  --  Revision:
  --  creation date:      31.12.20
  --  Purpose :           invoke oic WS
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.1   31.12.20      yuval tal      CHG0048579 - initial , call from call_safenet

  -------------------------------------------------------
  PROCEDURE call_safenet_oic(p_hasp_interface_id         NUMBER,
		     p_safenet_user              VARCHAR2,
		     p_safenet_password          VARCHAR2,
		     p_file_dir                  VARCHAR2,
		     p_file_prefix               VARCHAR2,
		     p_hasp_root_dir             VARCHAR2,
		     p_hasp_root_dir_bck         VARCHAR2,
		     x_response_hasp_order_id    OUT VARCHAR2,
		     x_response_bpel_instance_id OUT VARCHAR2,
		     x_response_file_name        OUT VARCHAR2,
		     x_final_root_dir_name       OUT VARCHAR2,
		     
		     x_err_code    OUT NUMBER,
		     x_err_message OUT VARCHAR2) IS
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
  
    l_resp_text  VARCHAR2(32767);
    l_error_code VARCHAR2(240);
    l_error_desc VARCHAR2(500);
  
    l_errbuf VARCHAR2(2000);
  
  BEGIN
    x_err_code := 0;
  
    xxssys_oic_util_pkg.get_service_details(g_oic_hasp_service,
			        l_enable_flag,
			        l_url,
			        l_wallet_loc,
			        l_wallet_pwd,
			        l_auth_user,
			        l_auth_pwd,
			        l_retcode,
			        l_errbuf);
  
    IF l_retcode = 0 THEN
    
      l_request_xml := ' <haspInterfaceProcessRequest>
<haspInterfaceId>' || p_hasp_interface_id ||
	           '</haspInterfaceId><batchId>' || g_batch_id ||
	           '</batchId><fileDir>' || p_file_dir ||
	           '</fileDir><rootDir>' || p_hasp_root_dir ||
	           '</rootDir><rootDirBck>' || p_hasp_root_dir_bck ||
	           '</rootDirBck>
<filePrefix>' || p_file_prefix ||
	           '</filePrefix>
</haspInterfaceProcessRequest>';
    
      --  message(l_request_xml);
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
    
      --
    
      BEGIN
        -- LOOP
        utl_http.read_text(l_http_response, l_resp, 32766);
        --  message(l_resp);
        --  END LOOP;
        utl_http.end_response(l_http_response);
      EXCEPTION
        WHEN utl_http.end_of_body THEN
          utl_http.end_response(l_http_response);
      END;
    
      xxssys_oic_util_pkg.html_parser(p_in_text    => l_resp,
			  p_out_text   => l_resp_text,
			  p_error_code => l_error_code,
			  p_error_desc => l_error_desc);
    
      IF instr(upper(l_resp_text), 'ERROR') > 0 THEN
      
        x_err_code    := 1;
        x_err_message := l_resp;
      
      ELSE
        /*  <haspInterfaceProcessResponse>
           <sysErrCode>1</sysErrCode>
           <sysErrMsg>Invalid Output Directory</sysErrMsg>
           <flowId>5212797</flowId>
           <haspOrderId>22447</haspOrderId>
           <fileName>Installation_22447_1150357926.v2c</fileName>
           <finalRootDirName>/home/orasoa/hasp/</finalRootDirName>
        </haspInterfaceProcessResponse>
        */
        SELECT decode(nvl(ERROR_CODE, 1), 0, 0, 1),
	   error_message || ' ' || substr(l_resp, 200),
	   hasp_order_id,
	   flow_id,
	   file_name,
	   final_root_dir_name
        INTO   x_err_code,
	   x_err_message,
	   x_response_hasp_order_id,
	   x_response_bpel_instance_id,
	   x_response_file_name,
	   x_final_root_dir_name
        FROM   xmltable('haspInterfaceProcessResponse' passing
		xmltype(l_resp) columns flow_id VARCHAR2(10) path
		'flowId',
		ERROR_CODE VARCHAR2(10) path 'sysErrCode',
		error_message VARCHAR2(1000) path 'sysErrMsg',
		hasp_order_id VARCHAR2(1000) path 'haspOrderId',
		file_name VARCHAR2(1000) path 'fileName',
		final_root_dir_name VARCHAR2(1000) path
		'finalRootDirName'
		
		) xt;
      END IF;
      utl_http.end_response(l_http_response);
    ELSE
    
      x_err_code    := '1';
      x_err_message := l_errbuf;
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
    
      message('get_detailed_sqlerrm' || utl_http.get_detailed_sqlerrm);
      utl_http.end_response(l_http_response);
      x_err_code    := '1';
      x_err_message := 'Error in xxcs_hasp_pkg.call_safnet_oic: ' ||
	           substr(SQLERRM, 1, 250);
  END;

  --------------------------------------------------------------------
  --  customization code:
  --  name:               call_safenet
  --  create by:          yuval tal
  --  Revision:
  --  creation date:      09.09.2012
  --  Purpose :           call bpel process
  --                      1. insert order
  --                      2. create exe file
  --                      3. save file in backup directory
  --                      4. save file in ftp directory : ??? (where system process will upload to PZ )
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.3   09.09.2012    yuval tal       CR496 HASP interface - logic change for saving at network directory
  --  1.4   03.09.2014    Michal Tzvik    CHG0032163: enable different file pefix for installation
  --                                      Enable BPEL 11G
  --                      yuval tal       add l_hasp_root_dir for exe backup : support upgrade location and installation location
  --                                      new PROFILE XXCS_HASP_FILE_ROOT_INSTALL_DIR
  --  1.5   21.4.16       YUVAL TAL       CHG0037918 - support 2 servers
  --  1.6   8.2.18        yuval tal       -- CHG0042312  add port parameter to soa
  --  1.7   12/01/2021    Yuval Tal.      CHG0048579 - OIC (Jira : OIC-352)
  -------------------------------------------------------
  PROCEDURE call_safenet(p_hasp_interface_id NUMBER,
		 p_err_code          OUT NUMBER,
		 p_err_message       OUT VARCHAR2) IS
  
    service_            sys.utl_dbws.service;
    call_               sys.utl_dbws.call;
    service_qname       sys.utl_dbws.qname;
    response            sys.xmltype;
    request             sys.xmltype;
    l_string_type_qname sys.utl_dbws.qname;
  
    --  l_error            VARCHAR2(1000);
    l_err_code            VARCHAR2(100) := NULL;
    l_err_msg             VARCHAR2(2500) := NULL;
    l_env                 VARCHAR2(20) := NULL;
    l_safenet_user        VARCHAR2(150) := NULL;
    l_safenet_password    VARCHAR2(150) := NULL;
    l_safenet_server      VARCHAR2(150);
    l_file_dir            VARCHAR2(250);
    l_final_root_dir_name VARCHAR2(250);
    -- response
    l_response_err_code         NUMBER;
    l_response_err_message      VARCHAR2(2000);
    l_response_hasp_order_id    NUMBER;
    l_response_bpel_instance_id NUMBER;
    l_response_file_name        VARCHAR2(500);
    --
    l_endpoint_service VARCHAR2(150) := NULL;
    l_endpoint_login   VARCHAR2(150) := NULL;
  
    l_rec_log    xxcs_hasp_log%ROWTYPE;
    l_header_rec xxcs_hasp_headers%ROWTYPE;
  
    l_file_prefix   VARCHAR2(15); --1.4 03.09.2014 CHG0032163 Michal Tzvik
    l_hasp_root_dir VARCHAR2(240);
  
    l_port VARCHAR2(20); -- CHG0042312
  BEGIN
    p_err_code    := 0;
    p_err_message := NULL;
    --
  
    -- init status
    update_header_status(p_hasp_interface_id, 'P', g_flow_code_safenet);
    l_rec_log.hasp_interface_id := p_hasp_interface_id;
    l_rec_log.flow_code         := g_flow_code_safenet;
    l_rec_log.log_code          := 'I';
    l_rec_log.description       := 'Start Safenet V2C file generation';
  
    insert_log(l_rec_log);
  
    COMMIT;
  
    -- get hasp info
    BEGIN
    
      SELECT *
      INTO   l_header_rec
      FROM   xxcs_hasp_headers t
      WHERE  t.hasp_interface_id = p_hasp_interface_id;
    
    EXCEPTION
    
      WHEN OTHERS THEN
        update_header_status(p_hasp_interface_id, 'E');
        l_rec_log.hasp_interface_id := p_hasp_interface_id;
        l_rec_log.flow_code         := g_flow_code_safenet;
        l_rec_log.log_code          := 'E';
        l_rec_log.description       := 'Call safenet: error getting hasp info :' ||
			   SQLERRM;
      
        insert_log(l_rec_log);
        p_err_code    := 1;
        p_err_message := SQLERRM;
        RETURN;
    END;
    --1.4 03.09.2014 CHG0032163 Michal Tzvik: Start
    IF l_header_rec.source_type = g_upgrade THEN
      l_file_prefix   := 'HaspUpdate';
      l_hasp_root_dir := fnd_profile.value('XXCS_HASP_FILE_ROOT_DIR') || '/' ||
		 sys_context('USERENV', 'DB_NAME') || '/';
    
    ELSE
      l_file_prefix   := 'Installation';
      l_hasp_root_dir := fnd_profile.value('XXCS_HASP_FILE_ROOT_INSTALL_DIR') || '/' ||
		 sys_context('USERENV', 'DB_NAME') || '/';
    END IF;
    --1.4 03.09.2014 CHG0032163 Michal Tzvik: End
  
    --- get env variables
  
    get_safenet_user_pass(l_safenet_user,
		  l_safenet_password,
		  l_safenet_server,
		  l_endpoint_service,
		  l_port, -- CHG0042312
		  l_env,
		  l_err_code,
		  l_err_msg);
  
    -- file dir without root dir
    l_file_dir := l_header_rec.region_name || '/' ||
	      l_header_rec.printers_type || '/' ||
	      l_header_rec.printer_sn;
    --------------------------------------------
    --- check oic enable CHG0048579
    --------------------------------------
    IF xxssys_oic_util_pkg.get_service_oic_enable_flag(p_service => g_oic_hasp_service) = 'Y' THEN
      -- oic has endpoint and credentials inside connector , so it is not required to pass it 
      call_safenet_oic( -- request
	           p_hasp_interface_id => p_hasp_interface_id,
	           p_safenet_user      => l_safenet_user,
	           p_safenet_password  => l_safenet_password,
	           p_file_dir          => l_file_dir,
	           p_file_prefix       => l_file_prefix,
	           p_hasp_root_dir     => l_hasp_root_dir,
	           p_hasp_root_dir_bck => g_hasp_root_dir_bck,
	           -- response                     
	           x_response_hasp_order_id    => l_response_hasp_order_id,
	           x_response_bpel_instance_id => l_response_bpel_instance_id,
	           x_response_file_name        => l_response_file_name,
	           x_final_root_dir_name       => l_final_root_dir_name,
	           x_err_code                  => l_response_err_code,
	           x_err_message               => l_response_err_message);
    
    ELSE
    
      ----
    
      service_qname       := sys.utl_dbws.to_qname('http://xmlns.oracle.com/xxHaspInterface',
				   'xxHaspInterface');
      l_string_type_qname := sys.utl_dbws.to_qname('http://www.w3.org/2001/XMLSchema',
				   'string');
      service_            := sys.utl_dbws.create_service(service_qname);
      call_               := sys.utl_dbws.create_call(service_);
    
      -- 20.11.14   Michal Tzvik   CHG003216 : Start
      /*sys.utl_dbws.set_target_endpoint_address(call_, g_bpel_host ||
      xxagile_util_pkg.get_bpel_domain ||
      '/xxHaspInterface/1.0');*/
    
      /*    IF g_enable_hasp_bpel11g = 'N' THEN
        sys.utl_dbws.set_target_endpoint_address(call_,
                                                 xxobjt_bpel_utils_pkg.get_bpel_host ||
                                                 xxagile_util_pkg.get_bpel_domain ||
                                                 '/xxHaspInterface/1.0');
      ELSE
        sys.utl_dbws.set_target_endpoint_address(call_,
                                                 xxobjt_bpel_utils_pkg.get_bpel_host2 ||
                                                 '/soa-infra/services/hasp/xxHaspInterface/client');
      
      END IF;*/
      -- CHG003216: End
    
      --  CHG0037918
      IF nvl(fnd_profile.value('XXSSYS_HASP_SOA_SRV_NUM'), '1') = '1' THEN
      
        sys.utl_dbws.set_target_endpoint_address(call_,
				 xxobjt_bpel_utils_pkg.get_bpel_host_srv1 ||
				 '/soa-infra/services/hasp/xxHaspInterface/client');
      ELSE
      
        sys.utl_dbws.set_target_endpoint_address(call_,
				 xxobjt_bpel_utils_pkg.get_bpel_host_srv2 ||
				 '/soa-infra/services/hasp/xxHaspInterface/client');
      
      END IF;
      -- CHG0037918 : End
    
      sys.utl_dbws.set_property(call_, 'SOAPACTION_USE', 'TRUE');
      sys.utl_dbws.set_property(call_, 'SOAPACTION_URI', 'process');
      sys.utl_dbws.set_property(call_, 'OPERATION_STYLE', 'document');
      sys.utl_dbws.set_property(call_,
		        'ENCODINGSTYLE_URI',
		        'http://schemas.xmlsoap.org/soap/encoding/');
    
      sys.utl_dbws.set_return_type(call_, l_string_type_qname);
    
      -- Set the input
      request := sys.xmltype('<ns1:xxHaspInterfaceProcessRequest xmlns:ns1="http://xmlns.oracle.com/xxHaspInterface">
		   <ns1:hasp_interface_id>' ||
		     p_hasp_interface_id ||
		     '</ns1:hasp_interface_id>' || ' <ns1:user>' ||
		     l_safenet_user || '</ns1:user>' ||
		     '<ns1:pass>' || l_safenet_password ||
		     '</ns1:pass>' || '<ns1:batch_id>' ||
		     g_batch_id || '</ns1:batch_id>' ||
		     '<ns1:jndi_name>' || g_db_jndi_name ||
		     '</ns1:jndi_name>' || '<ns1:safenet_server>' ||
		     l_safenet_server || '</ns1:safenet_server>' ||
		     '<ns1:endpoint_services_url>' ||
		     l_endpoint_service ||
		     '</ns1:endpoint_services_url>' ||
		     '<ns1:file_prefix>' || l_file_prefix || --1.4 03.09.2014 CHG0032163 Michal Tzvik: replace 'HaspUpdate' ||
		     '</ns1:file_prefix>' || '<ns1:file_dir>' ||
		     l_file_dir || '</ns1:file_dir>' ||
		     '<ns1:root_dir>' || l_hasp_root_dir ||
		     '</ns1:root_dir>' || '<ns1:root_dir_bck>' ||
		     g_hasp_root_dir_bck || '</ns1:root_dir_bck>' ||
		     '<ns1:port>' || l_port || '</ns1:port>' ||
		     '</ns1:xxHaspInterfaceProcessRequest>');
      /* dbms_output.put_line('<ns1:xxHaspInterfaceProcessRequest xmlns:ns1="http://xmlns.oracle.com/xxHaspInterface">
        <ns1:hasp_interface_id>' ||
      p_hasp_interface_id || '</ns1:hasp_interface_id>' ||
      ' <ns1:user>' || l_safenet_user || '</ns1:user>' ||
      '<ns1:pass>' || l_safenet_password ||
      '</ns1:pass>' || '<ns1:batch_id>' || g_batch_id ||
      '</ns1:batch_id>' || '<ns1:jndi_name>' ||
      g_db_jndi_name || '</ns1:jndi_name>' ||
      '<ns1:safenet_server>' || l_safenet_server ||
      '</ns1:safenet_server>' ||
      '<ns1:endpoint_services_url>' ||
      l_endpoint_service ||
      '</ns1:endpoint_services_url>' ||
      '<ns1:file_prefix>' || l_file_prefix || --1.4 03.09.2014 CHG0032163 Michal Tzvik: replace 'HaspUpdate' ||
      '</ns1:file_prefix>' || '<ns1:file_dir>' ||
      l_file_dir || '</ns1:file_dir>' ||
      '<ns1:root_dir>' || l_hasp_root_dir ||
      '</ns1:root_dir>' || '<ns1:root_dir_bck>' ||
      g_hasp_root_dir_bck || '</ns1:root_dir_bck>' ||
      '</ns1:xxHaspInterfaceProcessRequest>');*/
      response := sys.utl_dbws.invoke(call_, request);
      sys.utl_dbws.release_call(call_);
      sys.utl_dbws.release_service(service_);
      p_err_message := substr(response.getstringval(), 1, 240);
    
      ----------------------------
      -- parse bpel response
      ------------------------------
      SELECT extractvalue(response,
		  '/xxHaspInterfaceProcessResponse/sys_err_code/text()',
		  'xmlns="http://xmlns.oracle.com/xxHaspInterface"'),
	 extractvalue(response,
		  '/xxHaspInterfaceProcessResponse/sys_err_msg/text()',
		  'xmlns="http://xmlns.oracle.com/xxHaspInterface"'),
	 extractvalue(response,
		  '/xxHaspInterfaceProcessResponse/hasp_order_id/text()',
		  'xmlns="http://xmlns.oracle.com/xxHaspInterface"'),
	 extractvalue(response,
		  '/xxHaspInterfaceProcessResponse/bpel_instance_id/text()',
		  'xmlns="http://xmlns.oracle.com/xxHaspInterface"'),
	 extractvalue(response,
		  '/xxHaspInterfaceProcessResponse/file_name/text()',
		  'xmlns="http://xmlns.oracle.com/xxHaspInterface"'),
	 extractvalue(response,
		  '/xxHaspInterfaceProcessResponse/final_root_dir_name/text()',
		  'xmlns="http://xmlns.oracle.com/xxHaspInterface"')
      INTO   l_response_err_code,
	 l_response_err_message,
	 l_response_hasp_order_id,
	 l_response_bpel_instance_id,
	 l_response_file_name,
	 l_final_root_dir_name
      FROM   dual;
    
    END IF; -- oic check 
  
    -- update response
  
    UPDATE xxcs_hasp_headers t
    SET    t.hasp_order_id    = l_response_hasp_order_id,
           t.v2c_file_name    = l_response_file_name,
           t.v2c_directory    = l_final_root_dir_name,
           t.bpel_instance_id = l_response_bpel_instance_id
    WHERE  t.hasp_interface_id = p_hasp_interface_id;
  
    IF l_response_err_code = 1 THEN
      p_err_code                  := 1;
      p_err_message               := 'call_safenet: ' ||
			 l_response_err_message;
      l_rec_log.hasp_interface_id := p_hasp_interface_id;
      l_rec_log.flow_code         := g_flow_code_safenet;
      l_rec_log.log_code          := 'E';
      l_rec_log.description       := substr('Bpel_instance_id=' ||
			        l_response_bpel_instance_id ||
			        ' Hasp Order ID=' ||
			        l_response_hasp_order_id ||
			        ' Error=' ||
			        nvl(xxobjt_general_utils_pkg.get_valueset_desc('XXCS_HASP_SAFENET_ERROR_DESC',
							       l_response_err_message),
				l_response_err_message),
			        1,
			        2000);
    
      insert_log(l_rec_log);
      update_header_status(p_hasp_interface_id, 'E');
    ELSE
      update_header_status(p_hasp_interface_id, 'S');
      l_rec_log.hasp_interface_id := p_hasp_interface_id;
      l_rec_log.flow_code         := g_flow_code_safenet;
      l_rec_log.log_code          := 'I';
      l_rec_log.description       := 'Safenet interface created V2C file :' ||
			 l_response_file_name ||
			 ' bpel_instance_id=' ||
			 l_response_bpel_instance_id;
    
      insert_log(l_rec_log);
    END IF;
  
    COMMIT;
  
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      -- dbms_output.put_line(substr(SQLERRM, 1, 250));
    
      p_err_message := 'call_safenet: ' || substr(SQLERRM, 1, 250);
      p_err_code    := '1';
      --   sys.utl_dbws.release_call(call_);
      --   sys.utl_dbws.release_service(service_);
    
      l_rec_log.hasp_interface_id := p_hasp_interface_id;
      l_rec_log.flow_code         := g_flow_code_safenet;
      l_rec_log.log_code          := 'E';
      l_rec_log.description       := substr('xxcs_hasp_pkg.call_safenet :' ||
			        SQLERRM,
			        1,
			        500);
    
      insert_log(l_rec_log);
      update_header_status(p_hasp_interface_id, 'E');
      COMMIT;
  END call_safenet;

  --------------------------------------------------------------------
  --  customization code:
  --  name:               initiate_hasp_table
  --  create by:          Yuval Tal
  --  Revision:
  --  creation date:
  --  Purpose :           Initiate hasp table
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  ----  ------------  --------------  ------------------------------
  --  1.1   19.06.14      Michal Tzvik    CHG0032163: Add logic for ?Installation? ? for the new process related to Order Management
  --  1.2   19.06.17      Lingaraj(TCS)   CHG0040890 - updated the upgrade advisor to support selling an upgrade in an initial sale
  --  1.3   22/07/2019    Roman W.        INC0163990 - Activation key is late to come
  --  1.4   03/06/2020    Roman W.        CHG0048021 - PZ Move to MY SSYS
  ----------------------------------------------------------------------

  PROCEDURE initiate_hasp_table(p_err_message OUT VARCHAR2,
		        p_err_code    OUT NUMBER)
  
   IS
    l_rec     xxcs_hasp_headers%ROWTYPE;
    l_sysdate DATE;
    l_ret     BOOLEAN;
    CURSOR c(c_sysdate DATE) IS
      SELECT *
      FROM   xxcs_hasp_upgrade_v t
      WHERE  t.last_update_date BETWEEN
	 to_date(fnd_profile.value('XXCRM_UPGRADE_ALERT_TIMESTAMP'),
	         'mm/dd/yyyy hh24:mi:ss') AND c_sysdate;
  
    CURSOR c_inst(c_sysdate DATE) IS -- 1.1  Michal Tzvik CHG0032163
      SELECT t.*
      FROM   xxom_hasp_installation_v t
      WHERE  1 = 1
      AND    NOT EXISTS
       (SELECT 1
	  FROM   xxcs_hasp_headers h
	  WHERE  h.instance_id = t.instance_id
	  AND    h.source_type = g_installation)
      AND    t.last_update_date BETWEEN
	 to_date(fnd_profile.value('XXOM_INSTALLATION_ALERT_TIMESTAMP'),
	          'mm/dd/yyyy hh24:mi:ss') AND c_sysdate;
    l_tmp     NUMBER;
    l_count   NUMBER := 0;
    l_errbuf  VARCHAR2(1500); --v1.2 Added on 19 Jun 2017 for CHG0040890
    l_retcode VARCHAR2(1) := '0'; --v1.2 Added on 19 Jun 2017 for CHG0040890
  BEGIN
    l_sysdate  := SYSDATE;
    p_err_code := 0;
    BEGIN
      message('Start xxcs_hasp_pkg.initiate_hasp_table()');
    
      message('1.1 xxcs_utils_pkg.update_upg_instance_id()');
      --Start v1.2 Added on 19 Jun 2017 for CHG0040890----
      xxcs_utils_pkg.update_upg_instance_id(l_errbuf, l_retcode);
    
      IF l_retcode != 0 THEN
        message(l_errbuf);
      END IF;
      --End v1.2------------------------------------------
      message('1.2 FOR i IN c(l_sysdate) LOOP');
      FOR i IN c(l_sysdate)
      LOOP
        l_count := l_count + 1;
        l_rec   := NULL;
      
        l_rec.printer_sn       := i.serial_number;
        l_rec.hasp_sn          := nvl(i.dongle_sn, i.msc);
        l_rec.order_header_id  := i.header_id;
        l_rec.key_pn           := i.key_pn;
        l_rec.order_number     := i.order_number;
        l_rec.order_line_id    := i.line_id;
        l_rec.orig_region_name := i.cs_region;
        l_rec.upgrade_kit      := i.segment1;
        l_rec.source_type      := i.source_type; -- 1.1  Michal Tzvik CHG0032163
        l_rec.is_basis_hasp    := 'N'; -- 1.1  Michal Tzvik CHG0032163
      
        -- l_rec.group_number := i.owner_party_number; -- rem by Roman W. 03/06/2020 CHG0048021
        l_rec.group_number := i.owner_account_number; -- added by Roman W. 03/06/2020 CHG0048021
        l_tmp              := insert_hasp_header(l_rec);
        COMMIT;
      END LOOP;
    
      -- update profile
      l_ret := fnd_profile.save(x_name       => 'XXCRM_UPGRADE_ALERT_TIMESTAMP',
		        x_value      => to_char(l_sysdate,
				        'mm/dd/yyyy hh24:mi:ss'),
		        x_level_name => 'SITE');
      COMMIT;
    EXCEPTION
      WHEN OTHERS THEN
        p_err_message := 'Error IN initiate_hasp_table (Upgrade):' ||
		 SQLERRM;
        message(p_err_message);
        p_err_code := 2;
    END;
  
    -- 1.1 Michal Tzvik CHG0032163: Start
    BEGIN
      message('1.3 FOR i IN c_inst(l_sysdate) LOOP');
      FOR i IN c_inst(l_sysdate)
      LOOP
        l_count := l_count + 1;
        l_rec   := NULL;
      
        l_rec.printer_sn                := i.printer_sn;
        l_rec.hasp_sn                   := i.dongle_sn;
        l_rec.order_header_id           := i.header_id;
        l_rec.key_pn                    := i.key_pn;
        l_rec.order_number              := i.order_number;
        l_rec.order_line_id             := i.line_id;
        l_rec.orig_region_name          := i.org; --cs_region;
        l_rec.source_type               := i.source_type;
        l_rec.is_basis_hasp             := i.is_basis_hasp;
        l_rec.printer_inventory_item_id := i.printer_inventory_item_id;
        l_rec.printer_organization_id   := i.printer_organization_id;
        l_rec.instance_id               := i.instance_id;
      
        --l_rec.group_number := i.owner_party_number; -- rem by Roman W. 03/06/2020 CHG0048021
        l_rec.group_number := i.owner_account_number; -- added by Roman W. 03/06/2020 CHG0048021
        l_tmp              := insert_hasp_header(l_rec);
        COMMIT;
      END LOOP;
      -- update profile
      l_ret := fnd_profile.save(x_name       => 'XXOM_INSTALLATION_ALERT_TIMESTAMP',
		        x_value      => to_char(l_sysdate,
				        'mm/dd/yyyy hh24:mi:ss'),
		        x_level_name => 'SITE');
      COMMIT;
    EXCEPTION
      WHEN OTHERS THEN
        p_err_message := 'Error IN initiate_hasp_table (Installation):' ||
		 SQLERRM;
        fnd_file.put_line(fnd_file.log, p_err_message);
        p_err_code := 2;
    END;
    -- 1.1 Michal Tzvik CHG0032163: End
  
    -- initiate hasp creation
    message('1.4 initiate_process()');
    initiate_process(p_err_code          => p_err_code,
	         p_err_message       => p_err_message,
	         p_hasp_interface_id => NULL);
  
    IF p_err_code != 0 THEN
      message(p_err_message);
    END IF;
  
    message(l_count || ' Records loaded');
  
    --v1.2 Added on 19 Jun 2017 for CHG0040890
    --If Any Error occurs during the Sales Order Line Updation , The Program will complete with Error
    IF l_retcode != 0 THEN
      p_err_message := p_err_message || chr(13) || l_errbuf;
      p_err_code    := '2';
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      message('Error:' || SQLERRM);
      p_err_code    := 2;
      p_err_message := SQLERRM;
    
  END initiate_hasp_table;
  ---------------------------------------------------------------------------
  -- Ver      When         Who             Comments
  -- -------  -----------  --------------  -------------------------------------
  -- 1.0      18/05/2019   Roman W.        INC0156901 - called from XXCSHASP.fmb
  --                                            submits conc program XXCS: Hasp Initiate Process
  ---------------------------------------------------------------------------
  PROCEDURE is_row_locked(p_hasp_interface_id IN NUMBER,
		  p_is_locked         OUT VARCHAR2,
		  p_error_code        OUT VARCHAR2,
		  p_error_desc        OUT VARCHAR2) IS
  
    PRAGMA AUTONOMOUS_TRANSACTION;
  
    l_sql_code NUMBER;
    ------------------------------
    --       code section
    ------------------------------
  BEGIN
  
    p_error_code := '0';
    p_error_desc := NULL;
  
    SELECT 'N'
    INTO   p_is_locked
    FROM   xxcs_hasp_headers dd
    WHERE  dd.hasp_interface_id = p_hasp_interface_id
    FOR    UPDATE NOWAIT;
  
    ROLLBACK;
  
  EXCEPTION
    WHEN OTHERS THEN
      l_sql_code := SQLCODE;
      IF l_sql_code = -54 THEN
        p_is_locked  := 'Y';
        p_error_code := '0';
        p_error_desc := NULL;
      ELSE
        p_is_locked  := 'N';
        p_error_code := '2';
        p_error_desc := 'EXCEPTION_OTHERS xxcs_hasp_pkg.is_row_locked(' ||
		p_hasp_interface_id || ') - ' || SQLERRM;
      END IF;
      ROLLBACK;
  END is_row_locked;

  ---------------------------------------------------------------------------
  -- Ver      When         Who             Comments
  -- -------  -----------  --------------  -------------------------------------
  -- 1.0      09/04/2019   Bellona B.      INC0153077 - called from XXCSHASP.fmb
  --                                            submits conc program XXCS: Hasp Initiate Process
  ---------------------------------------------------------------------------
  PROCEDURE form_initiate_process(p_err_code          OUT VARCHAR2,
		          p_err_message       OUT VARCHAR2,
		          p_request_id        OUT NUMBER,
		          p_hasp_interface_id IN NUMBER DEFAULT NULL) IS
    l_cnt       NUMBER;
    l_is_locked VARCHAR2(300);
  BEGIN
  
    p_err_code    := '0';
    p_err_message := NULL;
  
    -- check is row locked -- added by Roman W. 09/04/2019 INC0156901
    is_row_locked(p_hasp_interface_id => p_hasp_interface_id,
	      p_is_locked         => l_is_locked,
	      p_error_code        => p_err_code,
	      p_error_desc        => p_err_message);
  
    IF p_err_code = '0' THEN
      IF l_is_locked = 'Y' THEN
        p_err_code    := '2';
        p_err_message := 'Save and then "Re-Submit"';
        RETURN;
      END IF;
    ELSE
      RETURN;
    END IF;
  
    --checking whether program running for same hasp_interface_id
    SELECT COUNT(1)
    INTO   l_cnt
    FROM   fnd_concurrent_requests    fcr,
           fnd_concurrent_programs_vl fcpv
    WHERE  fcpv.concurrent_program_name = 'XXCS_HASP_INITIATE_PROCESS'
    AND    fcpv.concurrent_program_id = fcr.concurrent_program_id
    AND    fcr.phase_code <> 'C'
    AND    fcr.argument1 = p_hasp_interface_id;
  
    IF l_cnt > 0 THEN
      message('Program already submitted for hasp_interface_id: ' ||
	  p_hasp_interface_id);
      p_err_message := 'Program already submitted for hasp_interface_id: ' ||
	           p_hasp_interface_id;
      p_request_id  := -1;
    ELSE
      COMMIT;
      --submitting concurrent program (xxcs: hasp initiate process)
      p_request_id := fnd_request.submit_request(application => 'XXOBJT',
				 program     => 'XXCS_HASP_INITIATE_PROCESS',
				 start_time  => SYSDATE,
				 sub_request => NULL,
				 argument1   => p_hasp_interface_id);
    
      COMMIT;
    
      IF p_request_id = 0 THEN
        p_err_code    := 2;
        p_err_message := 'Concurrent request(''XXCS: Hasp Initiate Process'') failed to submit';
        message(p_err_message);
      END IF;
    
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      message('Error:' || SQLERRM);
      p_err_code    := 2;
      p_err_message := SQLERRM;
      p_request_id  := -1;
    
  END form_initiate_process;
  -----------------------------------------------------------------------------------------------------
  -- initiate_process
  -----------------------------------------------------------------------------------------------------
  --  Ver     Date        Performer       Comments
  --  ------  ----------  --------------  -------------------------------------------------------------
  --  1.2     10.1.16     yuval tal       CHG0037403 - change logic of l_to_user_name/l_cc_mail_list
  --  1.3     16/05/2019  Roman W.        INC0156901 - HASP process not completeWhen clicking resubmit
  --                                             added writing to log
  --  1.4     22/07/2019  Roman W.        INC0163990 - Activation key is late to come
  -----------------------------------------------------------------------------------------------------
  PROCEDURE initiate_process(p_err_code          OUT NUMBER,
		     p_err_message       OUT VARCHAR2,
		     p_hasp_interface_id NUMBER DEFAULT NULL) IS
  
    l_rec_log xxcs_hasp_log%ROWTYPE;
  
    l_err_code    NUMBER;
    l_err_message VARCHAR2(250);
    --
    l_to_user_name VARCHAR2(50);
    l_cc_mail_list VARCHAR2(1000);
    --
    l_itemkey wf_items.item_key%TYPE;
    l_userkey wf_items.user_key%TYPE;
    myexception EXCEPTION;
  
    CURSOR c_hasp IS
      SELECT *
      FROM   xxcs_hasp_headers t
      WHERE  (t.hasp_interface_id = p_hasp_interface_id OR
	 t.flow_code = 'NEW');
  
    CURSOR c_extra_info(c_line_id NUMBER,
		c_order   VARCHAR2) IS
      SELECT *
      FROM   xxcs_hasp_upgrade_v tt
      WHERE  tt.line_id = c_line_id
      AND    tt.order_number = c_order;
  
  BEGIN
    p_err_code    := 0;
    p_err_message := 'Successfuly Submited.';
  
    message('1. START xxcs_hasp_pkg.initiate_process(' ||
	p_hasp_interface_id || ')');
    -- refresh header
  
    IF p_hasp_interface_id IS NOT NULL THEN
      update_hasp_header(p_hasp_interface_id);
    END IF;
  
    message('2.');
  
    FOR i IN c_hasp
    LOOP
      message('3.');
      close_open_erros(i.hasp_interface_id);
      message('4.');
      --CHG0037403
    
      IF i.source_type = 'Upgrade' THEN
      
        l_to_user_name := nvl(xxobjt_general_utils_pkg.get_dist_mail_list(NULL,
						  'XXCS_HASP_ALERT_USER_NAME'),
		      'SYSADMIN');
        message('5.1.1');
        l_cc_mail_list := xxobjt_general_utils_pkg.get_dist_mail_list(NULL,
					          'XXCS_HASP_ALERT_CC');
        message('5.1.2');
      
      ELSIF i.source_type = 'Installation' AND i.is_basis_hasp = 'N' THEN
        l_to_user_name := nvl(xxobjt_general_utils_pkg.get_dist_mail_list(NULL,
						  'XXOM_HASP_ALERT_USER_NAME'),
		      'SYSADMIN');
        message('5.2.1');
        l_cc_mail_list := xxobjt_general_utils_pkg.get_dist_mail_list(NULL,
					          'XXOM_HASP_ALERT_CC');
        message('5.2.2');
      
      ELSE
        l_to_user_name := nvl(xxobjt_general_utils_pkg.get_dist_mail_list(NULL,
						  'XXCS_HASP_ALERT_DUMMY_USER_NAME'),
		      'SYSADMIN');
      
        l_cc_mail_list := NULL;
        message('5.3.1');
      END IF;
    
      --
    
      -- check in process
      BEGIN
        IF i.status_code NOT IN ('N', 'E') THEN
          message('6.');
          RAISE myexception;
        
        END IF;
        ---------------------
      
        update_header_status(i.hasp_interface_id, 'P', g_flow_code_wf);
        message('7.');
      
        l_rec_log.hasp_interface_id := i.hasp_interface_id;
        l_rec_log.flow_code         := g_flow_code_wf;
        l_rec_log.log_code          := 'I';
        l_rec_log.description       := 'Start Workflow Process';
        insert_log(l_rec_log);
      
        --- create wf process
        SAVEPOINT start1;
      
        SELECT xxcs_hasp_wf_key_seq.nextval
        INTO   l_itemkey
        FROM   dual;
        message('8.');
        l_userkey := i.hasp_sn || '-' || i.order_line_id;
      
        wf_engine.createprocess(itemtype => g_item_type,
		        itemkey  => l_itemkey,
		        user_key => l_userkey,
		        process  => g_workflow_process);
        message('9.');
        wf_engine.setitemattrtext(itemtype => g_item_type,
		          itemkey  => l_itemkey,
		          aname    => 'SEND_TO',
		          avalue   => l_to_user_name);
        message('10.');
        wf_engine.setitemattrtext(itemtype => g_item_type,
		          itemkey  => l_itemkey,
		          aname    => 'ORDER_NUMBER',
		          avalue   => i.order_number);
        message('11.');
        wf_engine.setitemattrtext(itemtype => g_item_type,
		          itemkey  => l_itemkey,
		          aname    => 'HASP_SN',
		          avalue   => i.hasp_sn);
        message('12.');
        wf_engine.setitemattrtext(itemtype => g_item_type,
		          itemkey  => l_itemkey,
		          aname    => 'PRINTER_SN',
		          avalue   => i.printer_sn);
        message('13.');
        wf_engine.setitemattrtext(itemtype => g_item_type,
		          itemkey  => l_itemkey,
		          aname    => 'INITIAL_FLOW_CODE',
		          avalue   => nvl(i.flow_code, 'NEW'));
        message('14.');
        wf_engine.setitemattrtext(itemtype => g_item_type,
		          itemkey  => l_itemkey,
		          aname    => 'UPGRADE_KIT',
		          avalue   => i.upgrade_kit);
        message('15.');
        wf_engine.setitemattrtext(itemtype => g_item_type,
		          itemkey  => l_itemkey,
		          aname    => '#WFM_CC',
		          avalue   => l_cc_mail_list);
        message('16.');
        wf_engine.setitemattrnumber(itemtype => g_item_type,
			itemkey  => l_itemkey,
			aname    => 'HASP_INTERFACE_ID',
			avalue   => i.hasp_interface_id);
        message('17.');
        wf_engine.setitemattrnumber(itemtype => g_item_type,
			itemkey  => l_itemkey,
			aname    => 'XXCS_HASP_FTP_CHECK_COUNTER',
			avalue   => fnd_profile.value('XXCS_HASP_FTP_CHECK_COUNTER'));
        message('18.');
        -- GET EXTRA INFO WHICH NOT SAVED IN HASP TABLE
      
        FOR j IN c_extra_info(i.order_line_id, i.order_number)
        LOOP
          wf_engine.setitemattrtext(itemtype => g_item_type,
			itemkey  => l_itemkey,
			aname    => 'UPGRADE_KIT_DESC',
			avalue   => j.description);
          message('19.');
        
        END LOOP;
      
        -- start process
      
        wf_engine.startprocess(itemtype => g_item_type,
		       itemkey  => l_itemkey);
        message('20.');
      
        UPDATE xxcs_hasp_headers t
        SET    t.item_type = g_item_type,
	   t.item_key  = l_itemkey
        WHERE  t.hasp_interface_id = i.hasp_interface_id;
        COMMIT;
      
        message('21. End');
      
      EXCEPTION
        WHEN myexception THEN
        
          l_rec_log.hasp_interface_id := i.hasp_interface_id;
          l_rec_log.flow_code         := g_flow_code_oracle;
          l_rec_log.log_code          := 'E';
          l_rec_log.description       := 'Record Already In Process/Completed';
        
          insert_log(l_rec_log);
          update_header_status(i.hasp_interface_id, 'E');
        
          p_err_code    := 1;
          p_err_message := 'Record already in Process';
          message('22. - ' || p_err_message);
        
        WHEN OTHERS THEN
          ROLLBACK TO SAVEPOINT start1;
        
          l_rec_log.hasp_interface_id := i.hasp_interface_id;
          l_rec_log.flow_code         := g_flow_code_oracle;
          l_rec_log.log_code          := 'E';
          l_rec_log.description       := 'xxcs_hasp_pkg.initiate_process: ' ||
			     SQLERRM;
        
          insert_log(l_rec_log);
          update_header_status(i.hasp_interface_id, 'E');
        
          p_err_code    := 1;
          p_err_message := 'xxcs_hasp_pkg.initiate_process:' || SQLERRM;
        
          message('23. - ' || p_err_message);
        
      END;
    
    END LOOP;
    COMMIT;
  END;

  --------------------------------------------------------------------
  --  customization code:
  --  name:               download_upload files_oic 
  --  create by:          yuval tal
  --  Revision:
  --  creation date:      31.12.20
  --  Purpose :           invoke oic WS
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.1   31.12.20      yuval tal      CHG0048579 - initial , call from download_files,upload_files

  -------------------------------------------------------
  PROCEDURE upload_download_files_oic(p_hasp_interface_id         NUMBER,
			  p_upload_download_mode      VARCHAR2,
			  p_file_date_signature       VARCHAR2 DEFAULT NULL,
			  x_response_err_code         OUT VARCHAR2,
			  x_response_err_message      OUT VARCHAR2,
			  x_response_flow_instance_id OUT VARCHAR2,
			  x_parsed_log_status         OUT VARCHAR2,
			  x_parsed_log_message        OUT VARCHAR2) IS
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
  
    l_file_date_signature VARCHAR2(2000);
  BEGIN
    message('upload_download_files_oic');
    xxssys_oic_util_pkg.get_service_details(g_oic_hasp_ftp_service,
			        l_enable_flag,
			        l_url,
			        l_wallet_loc,
			        l_wallet_pwd,
			        l_auth_user,
			        l_auth_pwd,
			        l_retcode,
			        l_errbuf);
    message('get_service_details' || ' ' || l_retcode || ' ' || l_url);
    IF l_retcode = 0 THEN
      -- log file tag used for download and currentDate used for upload 
      l_request_xml := '<haspFtpRequest><operationName>' ||
	           p_upload_download_mode ||
	           '</operationName><operationDetails><currentDate>' ||
	           p_file_date_signature ||
	           '</currentDate><haspInterfaceId>' ||
	           p_hasp_interface_id ||
	           '</haspInterfaceId><logFileName>' ||
	           p_file_date_signature || '.xml' || '</logFileName></operationDetails>
</haspFtpRequest>';
    
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
        x_response_err_code    := 1;
        x_response_err_message := l_resp;
      ELSE
        /*   <?xml version="1.0" encoding="UTF-8" ?>
        <haspFtpResponse>
        <operationName>uploadFiles</operationName>
        <operationDetails>
        <oicInstanceId>sdsa</oicInstanceId>
        <errCode>sdsad</errCode>
        <errMessage>sadsad</errMessage>
        </operationDetails>
        </haspFtpResponse>*/
        SELECT decode(nvl(ERROR_CODE, 1), 0, 0, 1),
	   error_message,
	   flow_id,
	   log_parsed_message,
	   log_status
        
        INTO   x_response_err_code,
	   x_response_err_message,
	   x_response_flow_instance_id,
	   x_parsed_log_message,
	   x_parsed_log_status
        
        FROM   xmltable('haspFtpResponse/operationDetails' passing
		xmltype(l_resp) columns
		
		ERROR_CODE VARCHAR2(10) path 'errCode',
		error_message VARCHAR2(1000) path 'errMessage',
		flow_id VARCHAR2(50) path 'oicInstanceId',
		log_parsed_message VARCHAR2(3000) path
		'logErrorMessage',
		log_status VARCHAR2(50) path 'logStatus') xt;
      END IF;
      utl_http.end_response(l_http_response);
    ELSE
    
      x_response_err_code    := '1';
      x_response_err_message := l_errbuf;
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
    
      message('get_detailed_sqlerrm' || utl_http.get_detailed_sqlerrm);
      utl_http.end_response(l_http_response);
      x_response_err_code    := '1';
      x_response_err_message := 'Error in xxcs_hasp_pkg.download_files_oic: ' ||
		        substr(SQLERRM, 1, 250);
    
  END;
  --------------------------------------------------------------------
  --  customization code:
  --  name:               upload_files
  --  create by:          Yuval Tal
  --  Revision:
  --  creation date:
  --  Purpose :            ftp_files
  --                       upload 3 files to PZ
  --                       1. xml datafile
  --                          name File name : v2c_CurrentDateTime_inretface_id.xml
  --                          content :
  --                          <?xml version="1.0" encoding="UTF-8" ?>
  --                          <V2C>
  --                              <PRINTER_SN>35089</PRINTER_SN>
  --                              <TYPE>9</TYPE>
  --                              <GROUP_NUMBER>547656</GROUP_NUMBER>
  --                              <FILE_NAME>HaspUpdate_3408_1551420509.bin</FILE_NAME>
  --                          </V2C>

  --                       2. vtc exe file
  --                       3. completed flag file  (FLAG FILE )
  --                          file name complete_CurrentDateTime_inretface_id.txt
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.1   20.11.14      Michal Tzvik    CHG0032163: Enable BPEL 11G
  --  1.2   21.4.16       YUVAL TAL       CHG0037918 - support 2 servers
  --  1.3   15.12.20      yuval tal       CHG0048579 - support oic call
  ----------------------------------------------------------------------
  PROCEDURE upload_files(p_hasp_interface_id NUMBER,
		 p_err_code          OUT NUMBER,
		 p_err_message       OUT VARCHAR2) IS
    l_rec_log             xxcs_hasp_log%ROWTYPE;
    l_header_rec          xxcs_hasp_headers%ROWTYPE;
    l_file_date_signature VARCHAR2(50) := to_char(SYSDATE,
				  'yyyy-mm-dd_hh24miss');
    --
  
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
    l_parsed_log_file_status    VARCHAR2(50);
    l_parsed_log_message        VARCHAR2(3000);
  BEGIN
  
    g_err_ind := 'UF1';
    --
    p_err_code := 0;
    update_header_status(p_hasp_interface_id, 'P', g_flow_code_pz_send);
    g_err_ind := 'UF2';
  
    l_file_date_signature := l_file_date_signature || '_' ||
		     p_hasp_interface_id;
    g_err_ind             := 'UF3';
  
    l_rec_log.hasp_interface_id := p_hasp_interface_id;
    l_rec_log.flow_code         := g_flow_code_pz_send;
    l_rec_log.log_code          := 'I';
    l_rec_log.description       := 'Start uploading files to PZ';
    insert_log(l_rec_log);
    g_err_ind := 'UF4';
  
    --------------------------------------------
    --- check oic enable CHG0048579
    --------------------------------------
    IF xxssys_oic_util_pkg.get_service_oic_enable_flag(p_service => g_oic_hasp_ftp_service) = 'Y' THEN
      -- oic has endpoint and credentials inside connector , so it is not required to pass it 
      message('OIC Mode' || ' ' || p_hasp_interface_id);
      upload_download_files_oic(p_hasp_interface_id         => p_hasp_interface_id,
		        p_upload_download_mode      => 'upload',
		        p_file_date_signature       => l_file_date_signature,
		        x_response_err_code         => l_response_err_code,
		        x_response_err_message      => l_response_err_message,
		        x_response_flow_instance_id => l_response_bpel_instance_id,
		        x_parsed_log_status         => l_parsed_log_file_status,
		        x_parsed_log_message        => l_parsed_log_message);
      --------------------------------------------------------------
    
    ELSE
    
      -- call bpel
    
      service_qname       := sys.utl_dbws.to_qname('http://tempuri.org/',
				   'UploadFiles');
      l_string_type_qname := sys.utl_dbws.to_qname('http://www.w3.org/2001/XMLSchema',
				   'string');
    
      service_  := sys.utl_dbws.create_service(service_qname);
      call_     := sys.utl_dbws.create_call(service_);
      g_err_ind := 'UF5';
    
      -- dbms_output.put_line(g_bpel_host || xxagile_util_pkg.get_bpel_domain || '/xxHaspFTP/1.0');
    
      -- 20.11.14   Michal Tzvik   CHG003216 : Start
      /*    sys.utl_dbws.set_target_endpoint_address(call_, g_bpel_host ||
      xxagile_util_pkg.get_bpel_domain ||
      '/xxHaspFTP/1.0');*/
      -- CHG0037918
      IF nvl(fnd_profile.value('XXSSYS_HASP_SOA_SRV_NUM'), '1') = '1' THEN
      
        sys.utl_dbws.set_target_endpoint_address(call_,
				 xxobjt_bpel_utils_pkg.get_bpel_host_srv1 ||
				 'soa-infra/services/hasp/xxHaspFTP/Client');
      ELSE
      
        sys.utl_dbws.set_target_endpoint_address(call_,
				 xxobjt_bpel_utils_pkg.get_bpel_host_srv2 ||
				 'soa-infra/services/hasp/xxHaspFTP/Client');
      
      END IF;
      -- CHG0037918 : End
    
      sys.utl_dbws.set_property(call_, 'SOAPACTION_USE', 'TRUE');
      sys.utl_dbws.set_property(call_, 'SOAPACTION_URI', 'UploadFiles');
      sys.utl_dbws.set_property(call_, 'OPERATION_STYLE', 'document');
    
      sys.utl_dbws.set_property(call_,
		        'ENCODINGSTYLE_URI',
		        'http://schemas.xmlsoap.org/soap/encoding/');
    
      sys.utl_dbws.set_return_type(call_, l_string_type_qname);
    
      g_err_ind := 'UF6';
      -- Set the input
    
      request := sys.xmltype('<ns1:UploadFilesRequest xmlns:ns1="http://tempuri.org/">
     <ns1:haspInterfaceId>' ||
		     p_hasp_interface_id || '</ns1:haspInterfaceId>
    <ns1:DBjndiName>' || g_db_jndi_name ||
		     '</ns1:DBjndiName>
		    <ns1:FTPjndiName>' || g_ftp_jndi_name ||
		     '</ns1:FTPjndiName>
		   <ns1:currDate>' || l_file_date_signature ||
		     '</ns1:currDate>
    </ns1:UploadFilesRequest>');
    
      g_err_ind := 'UF7';
    
      response := sys.utl_dbws.invoke(call_, request);
      sys.utl_dbws.release_call(call_);
      sys.utl_dbws.release_service(service_);
      p_err_message := substr(response.getstringval(), 1, 240);
    
      g_err_ind := 'UF8';
      -- parse result
      ----------------------------
      -- parse bpel response
      ------------------------------
      /*
          <UploadFilesResponse xmlns="http://tempuri.org/">
        <bpelInstanceId>370031</bpelInstanceId>
        <errCode>0</errCode>
        <errMessage/>
      </UploadFilesResponse>*/
    
      l_response_err_code := response.extract('//UploadFilesResponse/errCode/text()','xmlns="http://tempuri.org/"')
		     .getstringval();
    
      l_response_err_message := response.extract('//UploadFilesResponse/errMessage/text()','xmlns="http://tempuri.org/"')
		        .getstringval();
    
      l_response_bpel_instance_id := response.extract('//UploadFilesResponse/bpelInstanceId/text()','xmlns="http://tempuri.org/"')
			 .getstringval();
    
      g_err_ind := 'UF9';
      -- update response
    END IF; -- oic check
  
    UPDATE xxcs_hasp_headers t
    SET    t.bpel_instance_id    = l_response_bpel_instance_id,
           t.file_date_signature = l_file_date_signature
    WHERE  t.hasp_interface_id = p_hasp_interface_id;
  
    g_err_ind := 'UF10';
    IF l_response_err_code = 1 THEN
      g_err_ind                   := 'UF11';
      p_err_code                  := 1;
      p_err_message               := substr('Upload files: ' ||
			        l_response_err_message,
			        1,
			        240);
      l_rec_log.hasp_interface_id := p_hasp_interface_id;
      l_rec_log.flow_code         := g_flow_code_pz_send;
      l_rec_log.log_code          := 'E';
      l_rec_log.description       := 'bpel_instance_id=' ||
			 l_response_bpel_instance_id || ' ' ||
			 substr(l_response_err_message, 1, 500);
    
      g_err_ind := 'UF12';
      insert_log(l_rec_log);
      update_header_status(p_hasp_interface_id, 'E');
      g_err_ind := 'UF13';
    ELSE
      g_err_ind := 'UF14';
      update_header_status(p_hasp_interface_id, 'S');
      l_rec_log.hasp_interface_id := p_hasp_interface_id;
      l_rec_log.flow_code         := g_flow_code_pz_send;
      l_rec_log.log_code          := 'I';
      l_rec_log.description       := 'Files uploaded successfuly : bpel_instance_id=' ||
			 l_response_bpel_instance_id;
      insert_log(l_rec_log);
      g_err_ind := 'UF15';
    END IF;
    --
    p_err_code := l_response_err_code;
    --  update_header_status(p_hasp_interface_id, 'S', g_flow_code_pz_send);
    g_err_ind := 'UF16';
    COMMIT;
  
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
    
      l_rec_log.hasp_interface_id := p_hasp_interface_id;
      l_rec_log.flow_code         := g_flow_code_pz_send;
      l_rec_log.log_code          := 'E';
      l_rec_log.description       := 'xxcs_hasp_pkg.upload_files: ' ||
			 SQLERRM || '(' || g_err_ind || ')';
    
      insert_log(l_rec_log);
      update_header_status(p_hasp_interface_id, 'E');
    
      p_err_code    := 1;
      p_err_message := 'xxcs_hasp_pkg.upload_files:' || SQLERRM;
  END upload_files;
  -----------------------------------------------------------
  -- upload_files_wf
  --
  --
  -----------------------------------------------------------
  PROCEDURE upload_files_wf(itemtype  IN VARCHAR2,
		    itemkey   IN VARCHAR2,
		    actid     IN NUMBER,
		    funcmode  IN VARCHAR2,
		    resultout OUT NOCOPY VARCHAR2) IS
  
    l_header_rec  xxcs_hasp_headers%ROWTYPE;
    l_err_code    NUMBER;
    l_err_message VARCHAR2(2000);
  BEGIN
  
    l_header_rec.hasp_interface_id := wf_engine.getitemattrnumber(itemtype => itemtype,
					      itemkey  => itemkey,
					      aname    => 'HASP_INTERFACE_ID');
  
    upload_files(p_hasp_interface_id => l_header_rec.hasp_interface_id,
	     p_err_code          => l_err_code,
	     p_err_message       => l_err_message);
  
    IF l_err_code = 0 THEN
      resultout := wf_engine.eng_completed || ':' || 'Y';
    
    ELSE
      resultout := wf_engine.eng_completed || ':' || 'N';
    
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      wf_core.context('XXCS_HASP_PKG',
	          'UPLOAD_FILES',
	          itemtype,
	          itemkey,
	          to_char(actid),
	          funcmode,
	          'Others',
	          'hasp_interface_id: ' ||
	          l_header_rec.hasp_interface_id,
	          SQLERRM);
      RAISE;
    
  END;

  --------------------------------------------
  -- download_files_wf
  ------------------------------------------

  PROCEDURE download_files_wf(itemtype  IN VARCHAR2,
		      itemkey   IN VARCHAR2,
		      actid     IN NUMBER,
		      funcmode  IN VARCHAR2,
		      resultout OUT NOCOPY VARCHAR2) IS
    l_header_rec  xxcs_hasp_headers%ROWTYPE;
    l_err_code    NUMBER;
    l_pz_status   NUMBER;
    l_err_message VARCHAR2(2000);
  BEGIN
  
    l_err_code                     := 0;
    l_header_rec.hasp_interface_id := wf_engine.getitemattrnumber(itemtype => itemtype,
					      itemkey  => itemkey,
					      aname    => 'HASP_INTERFACE_ID');
  
    download_files(p_hasp_interface_id => l_header_rec.hasp_interface_id,
	       p_err_code          => l_err_code,
	       p_pz_status         => l_pz_status,
	       p_err_message       => l_err_message);
  
    wf_engine.setitemattrnumber(itemtype => itemtype,
		        itemkey  => itemkey,
		        aname    => 'PZ_LOG_CODE',
		        avalue   => l_pz_status); -- 0 = ERR
  
    IF l_err_code = 0 THEN
      resultout := wf_engine.eng_completed || ':' || 'S'; -- found log file with status success
    
    ELSE
      resultout := wf_engine.eng_completed || ':' || 'R'; -- retry:  no file found
    
    END IF;
  END;

  --------------------------------------------------------------------
  --  customization code:
  --  name:               download_files
  --  create by:          Yuval Tal
  --  Revision:
  --  creation date:
  --  Purpose :           look for log file
  --                      name File name : log_CurrentDateTime_inretface_id.xml
  --                      p_err_code : 0 -  no bpel erros (file found)
  --                                   1 -  bpel erros (file not found for example)
  --                      p_pz_status 1 success / 0 err
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.1   20.11.14      Michal Tzvik    CHG0032163: Enable BPEL 11G
  --  1.2   21.4.16       YUVAL TAL       CHG0037918 - support 2 servers
  --  1.3   15.12.20      yuval tal       CHG0048579 - support oic call
  ----------------------------------------------------------------------
  PROCEDURE download_files(p_hasp_interface_id NUMBER,
		   p_err_code          OUT NUMBER,
		   p_pz_status         OUT NUMBER,
		   p_err_message       OUT VARCHAR2) IS
    l_header_rec xxcs_hasp_headers%ROWTYPE;
    -- l_err_code    NUMBER;
    --  l_err_message VARCHAR2(2000);
  
    l_rec_log             xxcs_hasp_log%ROWTYPE;
    l_header_rec          xxcs_hasp_headers%ROWTYPE;
    l_file_date_signature VARCHAR2(50);
    --
  
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
    l_oic_flag                  NUMBER := 0;
    l_log_parsed_message        VARCHAR2(3000);
  BEGIN
    p_err_code := 0;
  
    update_header_status(p_hasp_interface_id, 'P', g_flow_code_pz_rcv);
  
    SELECT 'log_' || t.file_date_signature
    INTO   l_file_date_signature
    FROM   xxcs_hasp_headers t
    WHERE  t.hasp_interface_id = p_hasp_interface_id;
  
    IF xxssys_oic_util_pkg.get_service_oic_enable_flag(p_service => g_oic_hasp_ftp_service) = 'Y' THEN
      -- oic has endpoint and credentials inside connector , so it is not required to pass it 
      l_oic_flag := 1;
      upload_download_files_oic(p_hasp_interface_id         => p_hasp_interface_id,
		        p_upload_download_mode      => 'download',
		        p_file_date_signature       => l_file_date_signature,
		        x_response_err_code         => l_response_err_code,
		        x_response_err_message      => l_response_err_message,
		        x_response_flow_instance_id => l_response_bpel_instance_id,
		        x_parsed_log_status         => p_pz_status,
		        x_parsed_log_message        => l_log_parsed_message);
      --------------------------------------------------------------
    
    ELSE
      -- call bpel
    
      service_qname       := sys.utl_dbws.to_qname('http://tempuri.org/',
				   'UploadFiles');
      l_string_type_qname := sys.utl_dbws.to_qname('http://www.w3.org/2001/XMLSchema',
				   'string');
    
      service_ := sys.utl_dbws.create_service(service_qname);
      call_    := sys.utl_dbws.create_call(service_);
    
      -- dbms_output.put_line(g_bpel_host || xxagile_util_pkg.get_bpel_domain || '/xxHaspFTP/1.0');
    
      -- 20.11.14   Michal Tzvik   CHG003216 : Start
      /*    sys.utl_dbws.set_target_endpoint_address(call_, g_bpel_host ||
      xxagile_util_pkg.get_bpel_domain ||
      '/xxHaspFTP/1.0');*/
      -- CHG0037918
      IF nvl(fnd_profile.value('XXSSYS_HASP_SOA_SRV_NUM'), '1') = '1' THEN
      
        sys.utl_dbws.set_target_endpoint_address(call_,
				 xxobjt_bpel_utils_pkg.get_bpel_host_srv1 ||
				 'soa-infra/services/hasp/xxHaspFTP/Client');
      ELSE
      
        sys.utl_dbws.set_target_endpoint_address(call_,
				 xxobjt_bpel_utils_pkg.get_bpel_host_srv2 ||
				 'soa-infra/services/hasp/xxHaspFTP/Client');
      
      END IF;
      -- CHG0037918 : End
    
      sys.utl_dbws.set_property(call_, 'SOAPACTION_USE', 'TRUE');
      sys.utl_dbws.set_property(call_, 'SOAPACTION_URI', 'DownLoadFiles');
      sys.utl_dbws.set_property(call_, 'OPERATION_STYLE', 'document');
    
      sys.utl_dbws.set_property(call_,
		        'ENCODINGSTYLE_URI',
		        'http://schemas.xmlsoap.org/soap/encoding/');
    
      sys.utl_dbws.set_return_type(call_, l_string_type_qname);
    
      -- Set the input
    
      request := sys.xmltype('<ns1:DownLoadFilesRequest xmlns:ns1="http://tempuri.org/">
     <ns1:haspInterfaceId>' ||
		     p_hasp_interface_id || '</ns1:haspInterfaceId>
    <ns1:DBjndiName>' || g_db_jndi_name ||
		     '</ns1:DBjndiName>
		    <ns1:FTPjndiName>' || g_ftp_jndi_name ||
		     '</ns1:FTPjndiName>
		   <ns1:logFileName>' ||
		     l_file_date_signature || '.xml' ||
		     '</ns1:logFileName>
    </ns1:DownLoadFilesRequest>');
    
      response := sys.utl_dbws.invoke(call_, request);
      sys.utl_dbws.release_call(call_);
      sys.utl_dbws.release_service(service_);
      p_err_message := substr(response.getstringval(), 1, 500);
    
      -- parse result
      ----------------------------
      -- parse bpel response
      ------------------------------
      /*
            <DownLoadFilesResponse xmlns="http://tempuri.org/">
      <bpelInstanceId>380062
      </bpelInstanceId>
      <errCode>0
      </errCode>
      -<errMessage>
      -<STATUS xmlns="">
      <SUCCESS>1
      </SUCCESS>
      </STATUS>
      </errMessage>
      </DownLoadFilesResponse*/
    
      l_response_err_code := xml_extract_no_exception(response,
				      '//DownLoadFilesResponse/errCode/text()',
				      'xmlns="http://tempuri.org/"');
    
      l_response_bpel_instance_id := xml_extract_no_exception(response,
					  '//DownLoadFilesResponse/bpelInstanceId/text()',
					  'xmlns="http://tempuri.org/"');
    
      l_response_err_message := xml_extract_no_exception(response,
				         '//DownLoadFilesResponse/errMessage',
				         'xmlns="http://tempuri.org/"');
    
    END IF; --oic check
  
    -- update response
  
    message('l_response_err_code=' || l_response_err_code);
  
    UPDATE xxcs_hasp_headers t
    SET    t.bpel_instance_id = l_response_bpel_instance_id
    WHERE  t.hasp_interface_id = p_hasp_interface_id;
  
    p_err_code := l_response_err_code;
  
    IF l_response_err_code = 1 THEN
      -- update_header_status(p_hasp_interface_id, 'E');
    
      p_err_message               := 'Download Log file: ' ||
			 l_response_err_message;
      l_rec_log.hasp_interface_id := p_hasp_interface_id;
      l_rec_log.flow_code         := g_flow_code_pz_rcv;
      l_rec_log.log_code          := 'E';
      -- check no data found
      IF instr(l_response_err_message, 'The system cannot find the file') > 0 THEN
        l_rec_log.description := 'The system cannot find log file ' ||
		         l_file_date_signature || '.xml';
      
      ELSE
      
        l_rec_log.description := substr(l_response_err_message, 1, 2000);
      END IF;
    
      --
      insert_log(l_rec_log, 'Y');
    
    ELSIF l_response_err_code = 0 THEN
      --- file found  check myssys log from message tag 
    
      ---------------------
      -- bpel mode
      ---------------------
      IF l_oic_flag = 0 THEN
        --CHG0048579
        p_pz_status := nvl(xml_extract_no_exception(response,
				    '//SUCCESS/text()',
				    ''),
		   '0');
      
        -- END IF; --CHG0048579
      
        -- dbms_output.put_line('p_pz_status=' || p_pz_status);
        -- check PZ status
        IF p_pz_status = 1 THEN
          -- 1=ok
          -- success
        
          update_header_status(p_hasp_interface_id,
		       'S',
		       g_flow_code_completed);
          l_rec_log.hasp_interface_id := p_hasp_interface_id;
          l_rec_log.flow_code         := g_flow_code_pz_rcv;
          l_rec_log.log_code          := 'I';
          l_rec_log.description       := 'PZ process ended successfuly  : instance_id=' ||
			     l_response_bpel_instance_id;
        
          insert_log(l_rec_log, 'Y');
        
        ELSE
        
          -- parse pz err log
          -- return status to upload
        
          DECLARE
	l_response_new VARCHAR2(2000);
	CURSOR c IS
	  SELECT extractvalue(VALUE(xml), '/ERROR/ERR_MESSAGE', '') err_message
	  
	  FROM   TABLE(xmlsequence(extract(xmltype(l_response_err_message),
			           '/errMessage/ERROR',
			           ''))) xml;
          
          BEGIN
          
	l_response_err_message := REPLACE(l_response_err_message,
			          'xmlns="http://tempuri.org/"',
			          '');
          
	FOR i IN c
	LOOP
	  l_response_new := l_response_new || ',' || i.err_message;
	END LOOP;
          
	l_rec_log.hasp_interface_id := p_hasp_interface_id;
	l_rec_log.flow_code         := g_flow_code_pz_rcv;
	l_rec_log.log_code          := 'E';
	l_rec_log.description       := l_response_new;
          
	insert_log(l_rec_log, 'Y');
          
          EXCEPTION
	WHEN OTHERS THEN
	  l_rec_log.hasp_interface_id := p_hasp_interface_id;
	  l_rec_log.flow_code         := g_flow_code_pz_rcv;
	  l_rec_log.log_code          := 'E';
	  l_rec_log.description       := l_response_err_message;
	  insert_log(l_rec_log, 'Y');
          END;
        
        END IF;
        -- return status to previous stage so pz process will run again
      
        update_header_status(p_hasp_interface_id, 'E', g_flow_code_pz_send);
        ---
      ELSE
        -- oic mode
        -- message('l_log_parsed_message=' || l_log_parsed_message);
        p_err_message               := l_log_parsed_message;
        l_rec_log.hasp_interface_id := p_hasp_interface_id;
        l_rec_log.flow_code         := g_flow_code_pz_rcv;
        l_rec_log.log_code          := 'E';
        l_rec_log.description       := l_log_parsed_message;
      
        insert_log(l_rec_log, 'Y');
        update_header_status(p_hasp_interface_id, 'E', g_flow_code_pz_send);
      
      END IF; -- oic parse err resp
    
    END IF; -- end oic parse condition 
  
    --
    p_err_code := l_response_err_code;
  
    COMMIT;
    /* EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
    
      l_rec_log.hasp_interface_id := p_hasp_interface_id;
      l_rec_log.flow_code         := g_flow_code_pz_send;
      l_rec_log.log_code          := 'E';
      l_rec_log.description       := 'xxcs_hasp_pkg.download_files: ' ||
                                     SQLERRM;
    
      insert_log(l_rec_log);
      update_header_status(p_hasp_interface_id, 'E');
    
      p_err_code    := 1;
      p_err_message := 'xxcs_hasp_pkg.download_files:' || SQLERRM;
    
      COMMIT;*/
  END download_files;

  -----------------------
  -- XML_EXTRACT_NO_EXCEPTION
  ----------------------
  FUNCTION xml_extract_no_exception(p_xml       IN xmltype,
			p_xpath     IN VARCHAR2,
			p_namespace IN VARCHAR2 DEFAULT NULL)
    RETURN VARCHAR2 AS
  BEGIN
    RETURN CASE WHEN p_xml.extract(p_xpath, p_namespace) IS NOT NULL THEN p_xml.extract(p_xpath,
							    p_namespace).getstringval() ELSE NULL END;
  END xml_extract_no_exception;

  ------------------------------
  -- track_selector_wf
  -------------------------------
  PROCEDURE track_selector_wf(itemtype  IN VARCHAR2,
		      itemkey   IN VARCHAR2,
		      actid     IN NUMBER,
		      funcmode  IN VARCHAR2,
		      resultout OUT NOCOPY VARCHAR2) IS
  
    l_flow xxcs_hasp_headers.flow_code%TYPE;
  BEGIN
  
    l_flow := wf_engine.getitemattrtext(itemtype => itemtype,
			    itemkey  => itemkey,
			    aname    => 'INITIAL_FLOW_CODE');
  
    resultout := wf_engine.eng_completed || ':' || l_flow;
  
  END;

  --------------------------------------------------------------------
  --  customization code:
  --  name:               is_sales_order_exist
  --  create by:          Michal Tzvik
  --  Revision:
  --  creation date:      31.07.2014
  --  Purpose :           Check if sales order exists for current HASP
  --                      interface id in XXCS_HASP_HEADERS. If yes- return Y.
  --                      If not, search for it. if exists- update XXCS_HASP_HEADERS
  --                      and return Y, else return N.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   31.07.14      Michal Tzvik    Initial Build
  -------------------------------------------------------
  PROCEDURE is_sales_order_exist(p_hasp_interface_id NUMBER,
		         p_is_so_exists      OUT VARCHAR2,
		         p_err_code          OUT NUMBER,
		         p_err_message       OUT VARCHAR2) IS
  
    l_rec_log    xxcs_hasp_log%ROWTYPE;
    l_header_rec xxcs_hasp_headers%ROWTYPE;
  
    l_order_header_id NUMBER;
    l_order_line_id   NUMBER;
    l_order_number    VARCHAR2(40);
    l_org_id          NUMBER;
    l_org             VARCHAR2(10);
    l_group_number    VARCHAR2(50);
  BEGIN
  
    p_err_code    := 0;
    p_err_message := NULL;
    --
  
    -- init status
    update_header_status(p_hasp_interface_id, 'P', g_flow_code_exists_so);
  
    -- get hasp info
    BEGIN
    
      SELECT *
      INTO   l_header_rec
      FROM   xxcs_hasp_headers t
      WHERE  t.hasp_interface_id = p_hasp_interface_id;
    
    EXCEPTION
    
      WHEN OTHERS THEN
        update_header_status(p_hasp_interface_id, 'E');
        l_rec_log.hasp_interface_id := p_hasp_interface_id;
        l_rec_log.flow_code         := g_flow_code_exists_so;
        l_rec_log.log_code          := 'E';
        l_rec_log.description       := 'Check sales order: error getting hasp info :' ||
			   SQLERRM;
      
        insert_log(l_rec_log);
        p_err_code    := 1;
        p_err_message := SQLERRM;
        RETURN;
    END;
    COMMIT;
  
    IF l_header_rec.order_header_id IS NULL OR
       l_header_rec.group_number IS NULL THEN
      -- Check group number for case of resubmit WF
      BEGIN
        SELECT oola.line_id,
	   ooha.header_id,
	   ooha.order_number,
	   ooha.org_id,
	   decode(ooha.org_id,
	          '81',
	          'IL',
	          '96',
	          'DE',
	          '89',
	          'US',
	          '737',
	          'US',
	          '103',
	          'HK',
	          '161',
	          'CN',
	          '914',
	          'KR',
	          '683',
	          'JP') org
        INTO   l_order_line_id,
	   l_order_header_id,
	   l_order_number,
	   l_org_id,
	   l_org
        FROM   oe_order_headers_all ooha,
	   oe_order_lines_all   oola,
	   csi_item_instances   cii
        WHERE  ooha.header_id = oola.header_id
        AND    cii.last_oe_order_line_id = oola.line_id
        AND    oola.flow_status_code != 'CANCELLED'
        AND    cii.instance_id = l_header_rec.instance_id;
      
      EXCEPTION
        WHEN no_data_found THEN
          p_is_so_exists := 'N';
          RETURN;
        
        WHEN OTHERS THEN
          p_err_code    := 1;
          p_err_message := 'Failed to get sales order info: ' || SQLERRM;
          update_header_status(p_hasp_interface_id, 'E');
          l_rec_log.hasp_interface_id := p_hasp_interface_id;
          l_rec_log.flow_code         := g_flow_code_exists_so;
          l_rec_log.log_code          := 'E';
          l_rec_log.description       := p_err_message;
          insert_log(l_rec_log);
          RETURN;
      END;
    
      IF l_order_header_id IS NOT NULL THEN
        l_group_number := get_inst_group_number(l_org_id);
      
        UPDATE xxcs_hasp_headers t
        SET    t.order_number     = l_order_number,
	   t.order_header_id  = l_order_header_id,
	   t.order_line_id    = l_order_line_id,
	   t.orig_region_name = l_org,
	   t.region_name      = l_org,
	   t.group_number     = l_group_number
        WHERE  t.hasp_interface_id = p_hasp_interface_id;
      
        COMMIT;
      
        p_is_so_exists := 'Y';
      
        update_header_status(p_hasp_interface_id,
		     'S',
		     g_flow_code_exists_so);
        l_rec_log.hasp_interface_id := p_hasp_interface_id;
        l_rec_log.flow_code         := g_flow_code_exists_so;
        l_rec_log.log_code          := 'I';
        l_rec_log.description       := 'Find sales order number ' ||
			   l_order_number;
        insert_log(l_rec_log);
      
      END IF;
    ELSE
      -- l_header_rec.order_header_id not is null
      p_is_so_exists := 'Y';
    
      update_header_status(p_hasp_interface_id, 'S', g_flow_code_exists_so);
      l_rec_log.hasp_interface_id := p_hasp_interface_id;
      l_rec_log.flow_code         := g_flow_code_exists_so;
      l_rec_log.log_code          := 'I';
      l_rec_log.description       := 'Sales order exists (' ||
			 l_header_rec.order_number || ')';
      insert_log(l_rec_log);
    END IF;
  
  EXCEPTION
  
    WHEN OTHERS THEN
      update_header_status(p_hasp_interface_id, 'E');
      l_rec_log.hasp_interface_id := p_hasp_interface_id;
      l_rec_log.flow_code         := g_flow_code_exists_so;
      l_rec_log.log_code          := 'E';
      l_rec_log.description       := 'Check sales order: Unecpeted error :' ||
			 SQLERRM;
    
      insert_log(l_rec_log);
      p_err_code    := 1;
      p_err_message := SQLERRM;
      RETURN;
  END is_sales_order_exist;
  --------------------------------------------------------------------
  --  customization code:
  --  name:               is_sales_order_exist_wf
  --  create by:          Michal Tzvik
  --  Revision:
  --  creation date:      31.07.2014
  --  Purpose :           Check if sales order exists for current HASP
  --                      interface id. Used by WF as a hold before uploading file to PZ.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.1   31.07.14      Michal Tzvik    Initial Build
  -------------------------------------------------------
  PROCEDURE is_sales_order_exist_wf(itemtype  IN VARCHAR2,
			itemkey   IN VARCHAR2,
			actid     IN NUMBER,
			funcmode  IN VARCHAR2,
			resultout OUT NOCOPY VARCHAR2) IS
  
    l_header_rec           xxcs_hasp_headers%ROWTYPE;
    l_is_sales_order_exist VARCHAR2(1);
    l_err_code             NUMBER;
    l_err_message          VARCHAR2(2000);
  BEGIN
  
    l_header_rec.hasp_interface_id := wf_engine.getitemattrnumber(itemtype => itemtype,
					      itemkey  => itemkey,
					      aname    => 'HASP_INTERFACE_ID');
  
    is_sales_order_exist(p_hasp_interface_id => l_header_rec.hasp_interface_id,
		 p_is_so_exists      => l_is_sales_order_exist,
		 p_err_code          => l_err_code,
		 p_err_message       => l_err_message);
  
    IF l_err_code = 0 THEN
      resultout := wf_engine.eng_completed || ':' || l_is_sales_order_exist;
    
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
    
      wf_core.context('XXCS_HASP_PKG',
	          'UPLOAD_FILES', --'IS_SALES_ORDER_EXIST_WF',
	          itemtype,
	          itemkey,
	          to_char(actid),
	          funcmode,
	          'Others',
	          'hasp_interface_id: ' ||
	          l_header_rec.hasp_interface_id,
	          SQLERRM);
      RAISE;
  END is_sales_order_exist_wf;

END xxcs_hasp_pkg;
/
