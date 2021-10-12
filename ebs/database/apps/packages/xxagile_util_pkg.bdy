CREATE OR REPLACE PACKAGE BODY xxagile_util_pkg IS

   g_user_id NUMBER;

   FUNCTION get_bpel_domain RETURN VARCHAR2 IS
   
      l_database VARCHAR2(20);
   
   BEGIN
   
      SELECT decode(NAME, 'PROD', 'production', 'default')
        INTO l_database
        FROM v$database;
   
      RETURN l_database;
   
   END get_bpel_domain;

   ------------------------------------------------------------
   PROCEDURE update_status(p_launcher_instance_id IN VARCHAR2,
                           p_status               IN VARCHAR2) IS
      PRAGMA AUTONOMOUS_TRANSACTION;
   BEGIN
      /* update ac.ac_agile_oracle_file_control
         set status = P_STATUS
       where bpel_inst_id = P_LAUNCHER_INSTANCE_ID;
      commit;*/
      NULL;
   END;
   ------------------------------------------------------------
   PROCEDURE report_bpel_error(p_bpel_instance_id IN VARCHAR2,
                               p_process_name     IN VARCHAR2,
                               p_error_text       IN VARCHAR2) IS
   
      v_err_id PLS_INTEGER;
   
   BEGIN
      NULL;
   
      /* select modu_ag_oracle_err_id_seq.NEXTVAL into v_err_id from dual;
      
      insert into modu_agile_oracle_err
        (id, bpel_instance_id, process_name, err_date, err_text)
      values
        (v_err_id, p_bpel_instance_id, p_process_name, sysdate, p_error_text);*/
   
   END report_bpel_error;
   ------------------------------------------------------------
   PROCEDURE handle_sub_request(p_request_id IN NUMBER) IS
      v_phase              VARCHAR2(100);
      v_phase_code         VARCHAR2(100);
      v_status             VARCHAR2(100);
      v_status_code        VARCHAR2(100);
      v_completion_message VARCHAR2(2000);
      v_res                BOOLEAN;
   BEGIN
      IF p_request_id = 0 THEN
         NULL;
         -- RAISE_APPLICATION_ERROR(-20000, 'Failed to submit request');
      ELSE
         COMMIT;
         v_res := fnd_concurrent.wait_for_request(request_id => p_request_id,
                                                  INTERVAL   => 1,
                                                  phase      => v_phase,
                                                  status     => v_status,
                                                  dev_phase  => v_phase_code,
                                                  dev_status => v_status_code,
                                                  message    => v_completion_message);
      END IF;
   END handle_sub_request;
   ------------------------------------------------------------
   PROCEDURE run_common_bill(p_bill_name          IN VARCHAR2,
                             p_org_id             IN NUMBER,
                             p_owner_organization IN VARCHAR2) IS
   
      PRAGMA AUTONOMOUS_TRANSACTION;
   
      l_request     NUMBER;
      l_resp_id     NUMBER := fnd_profile.VALUE('AC_AGILE_AUTO_IMPL_RESP');
      l_user_id     NUMBER := fnd_profile.VALUE('AC_AGILE_AUTO_IMPL_USER');
      l_resp_app_id NUMBER := NULL;
      CURSOR get_resp_app_id_csr IS
         SELECT fr.application_id
           FROM fnd_responsibility fr
          WHERE fr.responsibility_id = l_resp_id;
   
      CURSOR lcu_get_inv_orgs(cp_org_id IN NUMBER, cp_org_context IN VARCHAR2) IS
         SELECT '2' order_by_col,
                hoi.org_information3 operating_unit_id,
                haou.organization_id inventory_org_id,
                mp.organization_code inventory_org_code,
                mp.master_organization_id master_organization_id,
                haou.NAME inventory_organization_name,
                haou1.NAME operating_unit_name
           FROM hr_organization_information hoi,
                hr_all_organization_units   haou,
                mtl_parameters              mp,
                hr_all_organization_units   haou1
          WHERE haou.organization_id = hoi.organization_id AND
                hoi.org_information_context = cp_org_context -- 'Accounting Information'
                AND
                SYSDATE BETWEEN haou.date_from AND
                nvl(haou.date_to, SYSDATE) AND
                mp.organization_id = haou.organization_id AND
                haou1.organization_id = hoi.org_information3 AND
                ((haou1.organization_id = cp_org_id AND
                cp_org_id IS NOT NULL) OR (cp_org_id IS NULL)) AND
                haou.organization_id <> mp.master_organization_id -- not selecting the master inventory org from this loop
          ORDER BY order_by_col;
   
      lr_get_inv_orgs lcu_get_inv_orgs%ROWTYPE;
   
      -- get the opetaing unit id for the provided operating unit name
      CURSOR lcu_get_org_id(cp_org_name IN VARCHAR2) IS
         SELECT organization_id operating_unit_id
           FROM hr_all_organization_units
          WHERE NAME = cp_org_name;
      n_org_id NUMBER;
   
      v_item_org_assign_profile fnd_profile_option_values.profile_option_value%TYPE;
      n_api_input_org_id        NUMBER;
   
      n_api_version    NUMBER := 1.0;
      b_init_msg       BOOLEAN := TRUE;
      v_return_status  VARCHAR2(10);
      n_msg_count      NUMBER := 0;
      v_bo_identifier  VARCHAR2(10) := 'ECO';
      v_debug          VARCHAR2(1) := 'N';
      v_output_dir     VARCHAR2(240) := '/usr/tmp';
      v_debug_filename VARCHAR2(80) := 'a20_common_bill.log';
   
      v_transaction_type VARCHAR2(10) := 'CREATE';
   
      n_des_count          NUMBER := 1;
      n_user_id            NUMBER := 0;
      tbl_error_type       error_handler.error_tbl_type;
      tbl_error_type_dummy error_handler.error_tbl_type;
   
      l_exception EXCEPTION;
      l_item_creation_exception EXCEPTION;
   
      d_effective_date DATE;
   
      CURSOR lbbom_get_id IS
         SELECT DISTINCT msib.inventory_item_id assembly_item_id
           FROM mtl_system_items_b msib
          WHERE msib.segment1 = p_bill_name;
   
      l_ass_item_id bom_bill_of_materials.assembly_item_id%TYPE;
   
   BEGIN
   
      COMMIT;
      FOR get_resp_app_id_rec IN get_resp_app_id_csr LOOP
         l_resp_app_id := get_resp_app_id_rec.application_id;
      END LOOP;
   
      IF l_resp_app_id IS NULL THEN
         RETURN;
      END IF;
      fnd_global.apps_initialize(g_user_id, l_resp_id, l_resp_app_id);
   
      OPEN lcu_get_org_id(p_owner_organization);
      FETCH lcu_get_org_id
         INTO n_org_id;
      CLOSE lcu_get_org_id;
   
      -- check if the operating unit id could be determined
      -- incase it is null then assign error message to the out parameter and
      -- raise exception
      IF (n_org_id IS NULL) THEN
         fnd_message.set_name('ACCST', 'AC_CST_A2O_INVALID_OU');
         fnd_message.set_token('OU_NAME', p_owner_organization);
         RAISE l_exception;
      END IF;
   
      -- get the value of the system profile ACCST_AGILE_ITEM_ORG_ASSIG
      -- this profile value is set at the org level, 10006 is hardcoded to get the value at the Org level
   
      v_item_org_assign_profile := fnd_profile.value_specific(org_id => n_org_id,
                                                              NAME   => 'AC_AGILE_INTERFACE_ITEM_ORG_ASSIGNMENT');
   
      --autonomous_proc.dump_temp('Profile Value :' ||
      --                           v_item_org_assign_profile ||
      --                         ' is set for Organization ID:' || n_org_id);
   
      -- check the profile value, if it is null then the current item will be assigned to
      -- all inventory organizations.
      --Profile Value :OU is set for Organization ID:22
      IF (nvl(v_item_org_assign_profile, 'ALL') = 'OU') THEN
         n_api_input_org_id := n_org_id;
      ELSE
         n_api_input_org_id := NULL;
      END IF;
   
      OPEN lbbom_get_id;
      FETCH lbbom_get_id
         INTO l_ass_item_id;
      CLOSE lbbom_get_id;
   
      --autonomous_proc.dump_temp('1 , n_api_input_org_id: ' ||
      --                        n_api_input_org_id);
   
      --autonomous_proc.dump_temp('1 , l_ass_item_id: ' || l_ass_item_id);
   
      FOR lcu_get_inv_orgs_rec IN lcu_get_inv_orgs(n_api_input_org_id,
                                                   'Accounting Information') LOOP
         /*    open lcu_get_inv_orgs(n_api_input_org_id, 'Accounting Information');
         loop
           fetch lcu_get_inv_orgs
             into lr_get_inv_orgs;
           exit when lcu_get_inv_orgs%NOTFOUND;*/
      
         BEGIN
            --autonomous_proc.dump_temp('1 , inventory_org_id: ' ||
            --                          lr_get_inv_orgs.inventory_org_id);
         
            --autonomous_proc.dump_temp('1 , l_ass_item_id: ' || l_ass_item_id);
         
            l_request := fnd_request.submit_request(application => 'BOM',
                                                    program     => 'BOMPCMBM', --BOMPCMBM
                                                    description => NULL,
                                                    start_time  => SYSDATE,
                                                    sub_request => FALSE,
                                                    argument1   => to_char(1),
                                                    argument2   => NULL,
                                                    argument3   => p_org_id,
                                                    argument4   => l_ass_item_id,
                                                    argument5   => NULL,
                                                    argument6   => lcu_get_inv_orgs_rec.inventory_org_id,
                                                    argument7   => l_ass_item_id);
         
            COMMIT;
         
         EXCEPTION
            WHEN OTHERS THEN
               NULL;
               --autonomous_proc.dump_temp('From others loop: ' || sqlerrm);
         END;
      
      END LOOP;
   
   EXCEPTION
      WHEN OTHERS THEN
         NULL;
         --autonomous_proc.dump_temp('From others: ' || sqlerrm);
   END run_common_bill;
   ------------------------------------------------------------
   PROCEDURE run_autoimpl_eco_conc(p_eco_name VARCHAR2,
                                   p_org_id   IN NUMBER,
                                   p_type     IN VARCHAR2,
                                   p_user_id  IN NUMBER) IS
   
      l_request     NUMBER;
      l_resp_id     NUMBER := fnd_profile.VALUE('AC_AGILE_AUTO_IMPL_RESP');
      l_user_id     NUMBER := g_user_id; -- fnd_profile.VALUE('AC_AGILE_AUTO_IMPL_USER');
      l_resp_app_id NUMBER := NULL;
      CURSOR get_resp_app_id_csr IS
         SELECT fr.application_id
           FROM fnd_responsibility fr
          WHERE fr.responsibility_id = l_resp_id;
   
      PRAGMA AUTONOMOUS_TRANSACTION;
   BEGIN
   
      FOR get_resp_app_id_rec IN get_resp_app_id_csr LOOP
         l_resp_app_id := get_resp_app_id_rec.application_id;
      END LOOP;
   
      IF l_resp_app_id IS NULL THEN
         RETURN;
      END IF;
   
      fnd_global.apps_initialize(l_user_id, l_resp_id, l_resp_app_id);
   
      l_request := fnd_request.submit_request(application => 'ENG',
                                              program     => 'ENCACN',
                                              description => NULL,
                                              start_time  => SYSDATE,
                                              sub_request => FALSE,
                                              argument1   => to_char(p_org_id),
                                              argument2   => p_type,
                                              argument3   => NULL,
                                              argument4   => p_eco_name,
                                              argument5   => NULL);
      COMMIT;
   END;

   PROCEDURE log_agile_file(p_directory IN VARCHAR2,
                            p_file_name IN VARCHAR2,
                            p_log_step  IN VARCHAR2) IS
   
   BEGIN
   
      NULL;
   END log_agile_file;

   PROCEDURE log_file_alert(errbuf OUT VARCHAR2, retcode OUT VARCHAR2) IS
   
   BEGIN
   
      NULL;
   END log_file_alert;

   FUNCTION get_territory(p_territory IN VARCHAR2) RETURN VARCHAR2 IS
   
      v_territory_code VARCHAR2(10);
   
   BEGIN
      BEGIN
         SELECT ft.territory_code
           INTO v_territory_code
           FROM fnd_territories_tl ft
          WHERE ft.territory_short_name = p_territory AND
                ft.LANGUAGE = 'US';
      EXCEPTION
         WHEN OTHERS THEN
            RETURN NULL;
      END;
   
      RETURN v_territory_code;
   
   END get_territory;

   PROCEDURE agile_data_manipulation(p_instance_id IN NUMBER) IS
   
      CURSOR cr_bom IS
         SELECT xa.transaction_id,
                xa.assembly ass_del,
                xa.component comp_del,
                xd.assembly ass_add,
                xd.component comp_add
           FROM xxobjt_agile_bom xa, xxobjt_agile_bom xd
          WHERE xa.transaction_id = p_instance_id AND
                xd.transaction_id = p_instance_id AND
                xa.indication = 'Deleted' AND
                xd.indication = 'Added' AND
                xa.assembly = xd.assembly AND
                xa.component = xd.component;
   
   BEGIN
   
      --Items
      UPDATE xxobjt_agile_items a
         SET transaction_id = p_instance_id,
             TRANSACTION    = decode(oldlifecycle, NULL, 'CREATE', 'UPDATE'),
             createdate     = decode(createdate,
                                     NULL,
                                     NULL,
                                     createdate || 'T00:00:00Z'),
             effectivedate  = decode(effectivedate,
                                     NULL,
                                     NULL,
                                     to_char(to_date(effectivedate,
                                                     'DD/MM/YYYY'),
                                             'YYYY-MM-DD') || 'T00:00:01Z'),
             uniqueid       = xxobj_agile_items_s.NEXTVAL,
             category_seg1  = decode(subclass, NULL, NULL, subclass),
             category_seg2  = decode(cgroup,
                                     NULL,
                                     NULL,
                                     cgroup || '.' || family || '.' ||
                                     category),
             rev            = REPLACE(rev, '*', NULL),
             coo            = xxagile_util_pkg.get_territory(coo)
       WHERE transaction_id = 1;
      --Bom  
      UPDATE xxobjt_agile_bom
         SET transaction_id = p_instance_id,
             effectivedate  = decode(effectivedate,
                                     NULL,
                                     NULL,
                                     effectivedate || ' 00:00:01'),
             indication     = decode(indication,
                                     'A',
                                     'Added',
                                     'D',
                                     'Deleted',
                                     'C',
                                     'Deleted',
                                     'U',
                                     'Unchanged'),
             uniqueid       = xxobj_agile_boms_s.NEXTVAL
       WHERE transaction_id = 1;
      --Aml
      UPDATE xxobjt_agile_aml a
         SET transaction_id = p_instance_id,
             createdate     = decode(createdate,
                                     NULL,
                                     NULL,
                                     createdate || 'T00:00:00Z'),
             indication     = decode(indication,
                                     'A',
                                     'Added',
                                     'D',
                                     'Deleted',
                                     'C',
                                     'Deleted',
                                     'U',
                                     'Unchanged'),
             uniqueid       = xxobj_agile_amls_s.NEXTVAL
       WHERE transaction_id = 1;
      COMMIT;
   
      FOR i IN cr_bom LOOP
         UPDATE xxobjt_agile_bom x
            SET indication = 'Unchanged'
          WHERE x.assembly = i.ass_del AND
                x.component = i.comp_del AND
                x.transaction_id = i.transaction_id AND
                indication = 'Deleted';
         COMMIT;
      
         UPDATE xxobjt_agile_bom x
            SET indication = 'Changed'
          WHERE x.assembly = i.ass_add AND
                x.component = i.comp_add AND
                x.transaction_id = i.transaction_id AND
                indication = 'Added';
         COMMIT;
      END LOOP;
   
   END;

   PROCEDURE process_csv_misc(p_instance_id    IN NUMBER,
                              p_item_file_name IN VARCHAR2,
                              p_aml_file_name  OUT VARCHAR2,
                              p_bom_file_name  OUT VARCHAR2,
                              p_eco_type       OUT VARCHAR2) IS
   
      v_file_seq    VARCHAR2(20);
      v_temp_status VARCHAR2(1);
      v_temp_step   VARCHAR2(10);
      v_file_seq_n  NUMBER;
      
      l_eco_name VARCHAR2(20):= NULL;
   BEGIN
   
      v_file_seq   := substr(p_item_file_name, 5, length(p_item_file_name));
      v_file_seq_n := REPLACE(v_file_seq, '.agl', NULL);
      --Update Tables With Instance Id
      IF p_instance_id IS NULL THEN
         --Return Correct Files Names
         p_aml_file_name := 'AML' || v_file_seq;
         p_bom_file_name := 'BOM' || v_file_seq;
      
         BEGIN
            INSERT INTO xxobjt.xxobjt_agile_step_log
            VALUES
               (p_item_file_name,
                v_file_seq_n,
                'AGL',
                'S',
                NULL,
                NULL,
                NULL,
                NULL);
         EXCEPTION
            WHEN OTHERS THEN
               NULL;
         END;
         COMMIT;
      ELSE
         --Get ECO Type
         BEGIN
            SELECT substr(MAX(eco), 1, 3), MAX(eco)
              INTO p_eco_type,l_eco_name
              FROM xxobjt_agile_items
             WHERE transaction_id = 1;
         EXCEPTION
            WHEN no_data_found THEN
               p_eco_type := NULL;
         END;
         --Call Manipulation Program
         agile_data_manipulation(p_instance_id);
      
         --Check Log Table & Update It
      
         BEGIN
            SELECT 'P', 'AGL'
              INTO v_temp_status, v_temp_step
              FROM xxobjt_agile_step_log x
             WHERE (x.status <> 'S' AND x.step IN ('XML', 'API', 'AGL')) OR
                   (x.status = 'S' AND x.step = 'XML') -- XML=P: previos ECO/MCO still process. API=E: waiting for fixing error. API=P: waiting to finish last run
                   AND
                   rownum = 1;
         EXCEPTION
            WHEN OTHERS THEN
               v_temp_status := 'S';
               v_temp_step   := 'XML';
         END;
      
         BEGIN
            UPDATE xxobjt_agile_step_log x
               SET x.step       = v_temp_step,
                   x.status     = v_temp_status, -- S will make next process to run. P will not make next process to run.
                   x.trx_id     = p_instance_id,
                   x.attribute1 = p_eco_type,
                   x.attribute2 = l_eco_name
             WHERE x.seq = v_file_seq_n;
            COMMIT;
         EXCEPTION
            WHEN OTHERS THEN
               NULL;
         END;
      
      END IF;
   
   END;

   --This Procedure will be called from bpel to change a record to process the next file
   PROCEDURE update_log_table(p_status OUT VARCHAR2) IS
   
      v_seq_e NUMBER;
      v_seq_p NUMBER;
   BEGIN
   
      --Get The Error record (max SEQ) to update it later to S.
      BEGIN
         SELECT MAX(seq)
           INTO v_seq_e
           FROM xxobjt_agile_step_log x
          WHERE (x.status = 'E' AND x.step = 'API') OR
                (x.status = 'P' AND x.step = 'XML');
      EXCEPTION
         WHEN no_data_found THEN
            --There are no errors, so get the next seq to process it
            v_seq_e := NULL;
      END;
   
      BEGIN
         SELECT MIN(seq)
           INTO v_seq_p
           FROM xxobjt_agile_step_log x
          WHERE x.status = 'P' AND
                x.step = 'AGL';
      EXCEPTION
         WHEN no_data_found THEN
            v_seq_p := NULL;
      END;
   
      IF v_seq_e IS NOT NULL THEN
         --Update xxobjt_agile_step_log
         fnd_global.apps_initialize(user_id      => g_user_id,
                                    resp_id      => 50623,
                                    resp_appl_id => 660);
         mo_global.set_org_context(p_org_id_char     => 81,
                                   p_sp_id_char      => NULL,
                                   p_appl_short_name => 'INV');
      
         BEGIN
            UPDATE xxobjt_agile_step_log x
               SET x.step = 'API', x.status = 'S', x.message = NULL
             WHERE x.seq = v_seq_e;
            COMMIT;
         EXCEPTION
            WHEN OTHERS THEN
               NULL;
         END;
      END IF;
   
      IF v_seq_p IS NOT NULL THEN
         --Update xxobjt_agile_step_log to process the next file 
         BEGIN
            UPDATE xxobjt_agile_step_log x
               SET x.step = 'XML', x.status = 'S' -- S will make next process to run.
             WHERE x.seq = v_seq_p;
            COMMIT;
         EXCEPTION
            WHEN OTHERS THEN
               NULL;
         END;
      END IF;
   END;

   PROCEDURE update_error_seq(p_error  IN VARCHAR2 DEFAULT NULL,
                              p_status OUT VARCHAR2) IS
   
      l_error_msg VARCHAR2(500);
   BEGIN
      fnd_global.apps_initialize(user_id      => g_user_id,
                                 resp_id      => 50623,
                                 resp_appl_id => 660);
      mo_global.set_org_context(p_org_id_char     => 81,
                                p_sp_id_char      => NULL,
                                p_appl_short_name => 'INV');
   
      --Update xxobjt_agile_step_log to stop to process. There will be always 1 record with XML type in status S
      BEGIN
         UPDATE xxobjt_agile_step_log x
            SET x.step = 'API', x.status = 'E', x.message = p_error
          WHERE x.step = 'XML' AND
                x.status = 'P';
         COMMIT;
      EXCEPTION
         WHEN OTHERS THEN
         
            l_error_msg := SQLERRM;
            UPDATE xxobjt_agile_step_log x
               SET x.step = 'API', x.status = 'E', x.message = l_error_msg
             WHERE x.step = 'XML' AND
                   x.status = 'P';
         
      END;
   
   END;

   PROCEDURE initiate_process(errbuf OUT VARCHAR2, retcode OUT NUMBER) IS
   
      v_errors_exists     VARCHAR2(1);
      service_            sys.utl_dbws.service;
      call_               sys.utl_dbws.CALL;
      service_qname       sys.utl_dbws.qname;
      response            sys.xmltype;
      request             sys.xmltype;
      v_string_type_qname sys.utl_dbws.qname;
      v_error             VARCHAR2(1000);
      l_database          VARCHAR2(20);
   
   BEGIN
   
      -- check for errors
      BEGIN
      
         SELECT DISTINCT 'Y'
           INTO v_errors_exists
           FROM xxobjt_agile_step_log asl
          WHERE asl.status = 'E' AND
                rownum < 2;
      
         retcode := 1;
         errbuf  := 'There are transactions with status E, you need to fix them before the next ECO.';
         RETURN;
      
      EXCEPTION
         WHEN no_data_found THEN
            v_errors_exists := 'N';
         WHEN too_many_rows THEN
            retcode := 1;
            errbuf  := 'There are transactions with status E, you need to fix them before the next ECO.';
            RETURN;
      END;
   
      -- check for running or stack processes
      BEGIN
      
         SELECT DISTINCT 'Y'
           INTO v_errors_exists
           FROM xxobjt_agile_step_log asl
          WHERE asl.step != 'API' OR
                asl.status != 'S' AND
                rownum < 2;
      
         retcode := 1;
         errbuf  := 'There are transactions in process.';
         RETURN;
      
      EXCEPTION
         WHEN too_many_rows THEN
            retcode := 1;
            errbuf  := 'There are transactions in process.';
            RETURN;
         WHEN OTHERS THEN
            v_errors_exists := 'N';
      END;
   
      --call bpel process xxAgileRunScript
      BEGIN
            
         service_qname       := sys.utl_dbws.to_qname('http://xmlns.oracle.com/xxAgileRunScript',
                                                      'xxAgileRunScript');
         v_string_type_qname := sys.utl_dbws.to_qname('http://www.w3.org/2001/XMLSchema',
                                                      'string');
         service_            := sys.utl_dbws.create_service(service_qname);
         call_               := sys.utl_dbws.create_call(service_);
         sys.utl_dbws.set_target_endpoint_address(call_,
                                                  'http://soaprodapps.2objet.com:7777/orabpel/'||get_bpel_domain||'/xxAgileRunScript/1.0');
      
         sys.utl_dbws.set_property(call_, 'SOAPACTION_USE', 'TRUE');
         sys.utl_dbws.set_property(call_, 'SOAPACTION_URI', 'process');
         sys.utl_dbws.set_property(call_, 'OPERATION_STYLE', 'document');
         sys.utl_dbws.set_property(call_,
                                   'ENCODINGSTYLE_URI',
                                   'http://schemas.xmlsoap.org/soap/encoding/');
      
         sys.utl_dbws.set_return_type(call_, v_string_type_qname);
      
         -- Set the input
      
         request := sys.xmltype('<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
    <soap:Body xmlns:ns1="http://xmlns.oracle.com/xxAgileRunScript">
        <ns1:xxAgileRunScriptProcessRequest>
            <ns1:input></ns1:input>
        </ns1:xxAgileRunScriptProcessRequest>
    </soap:Body>
</soap:Envelope>
');
      
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
         END IF;
         --dbms_output.put_line(response.getstringval()); 
      EXCEPTION
         WHEN OTHERS THEN
            v_error := substr(SQLERRM, 1, 250);
            retcode := '2';
            errbuf  := 'Error Run Bpel Process - xxAgileRunScript: ' ||
                       v_error;
            sys.utl_dbws.release_call(call_);
            sys.utl_dbws.release_service(service_);
      END;
   
   END initiate_process;

BEGIN
   -- Initialization
   SELECT user_id INTO g_user_id FROM fnd_user WHERE user_name = 'AGILE';
END xxagile_util_pkg;
/

