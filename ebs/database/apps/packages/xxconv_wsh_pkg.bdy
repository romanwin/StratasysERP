CREATE OR REPLACE PACKAGE BODY xxconv_wsh_pkg IS
  ---------------------------------------------------------------------------
  -- $Header: xxconv_wsh_pkg   $
  ---------------------------------------------------------------------------
  -- Package: xxconv_wsh_pkg
  -- Created:
  -- Author:
  --------------------------------------------------------------------------
  -- Purpose: Shipping Methods Assignments to new organizations
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --     1.0  8.7.13    Vitaly      initial build
  ------------------------------------------------------------------

  -----------------------------------------------------------------------------
  PROCEDURE message(p_message VARCHAR2) IS
  
  BEGIN
    ---dbms_output.put_line(p_message);
    fnd_file.put_line(fnd_file.log, '========= ' || p_message);
  EXCEPTION
    WHEN OTHERS THEN
      NULL;
  END message;

  --------------------------------------------------------------------
  -- org_carrier_assignment 
  -------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -----------------------------
  --     1.0  7.7.13    Vitaly      initial build
  -------------------------------------------------------------------- 
  PROCEDURE org_carrier_assignment(errbuf                 OUT VARCHAR2,
                                   retcode                OUT VARCHAR2,
                                   p_from_organization_id IN NUMBER,
                                   p_to_organization_id   IN NUMBER) IS
  
    CURSOR c_get_org_carrier_services IS
      SELECT woc.carrier_service_id, woc.enabled_flag
        FROM wsh_carrier_services wcs, wsh_org_carrier_services woc
       WHERE wcs.carrier_service_id = woc.carrier_service_id
         AND woc.enabled_flag = 'Y'
         AND woc.organization_id = p_from_organization_id; ----parameter
  
    CURSOR c_get_carrier_ship_methods IS
      SELECT a.*
        FROM wsh_carrier_ship_methods a
       WHERE a.enabled_flag = 'Y'
         AND a.organization_id = p_from_organization_id; ----parameter   
  
    CURSOR c_get_org_freight_tl IS
      SELECT a.*
        FROM org_freight_tl a
       WHERE a.organization_id = p_from_organization_id; ----parameter    
  
    v_step VARCHAR2(100);
    stop_processing EXCEPTION;
    v_error_message              VARCHAR2(5000);
    v_inserted_records_counter   NUMBER := 0;
    v_already_exist_records_cntr NUMBER := 0;
  
  BEGIN
  
    v_step  := 'Step 0';
    retcode := '0';
    errbuf  := 'Success';
  
    ---*****parameters******
    message('Parameter p_from_organization_id=' || p_from_organization_id);
    message('Parameter p_to_organization_id=' || p_to_organization_id);
    ----*******************
  
    IF p_from_organization_id IS NULL THEN
      ---Error----
      v_error_message := 'Missing parameter p_from_organization_id';
      RAISE stop_processing;
    END IF;
    IF p_to_organization_id IS NULL THEN
      ---Error----
      v_error_message := 'Missing parameter p_to_organization_id';
      RAISE stop_processing;
    END IF;
    IF p_from_organization_id = p_to_organization_id THEN
      ---Error----
      v_error_message := 'Parameter p_to_organization_id cannot be equel to p_from_organization_id=' ||
                         p_from_organization_id;
      RAISE stop_processing;
    END IF;
  
    v_step                       := 'Step 10';
    v_inserted_records_counter   := 0;
    v_already_exist_records_cntr := 0;
    FOR data_rec IN c_get_org_carrier_services LOOP
      ---========================= org_carrier_services LOOP ==============================
      BEGIN
        INSERT INTO wsh_org_carrier_services
          (org_carrier_service_id,
           carrier_service_id,
           organization_id,
           enabled_flag,
           creation_date,
           created_by,
           last_update_date,
           last_updated_by)
        VALUES
          (wsh_org_carrier_services_s.nextval, --  org_Carrier_Service_id,
           data_rec.carrier_service_id,
           p_to_organization_id,
           data_rec.enabled_flag, --.Enabled_Flag,
           SYSDATE, --creation_date
           fnd_global.user_id, --created_by,
           SYSDATE, --last_update_date
           fnd_global.user_id --last_updated_by
           );
        COMMIT;
        v_inserted_records_counter := v_inserted_records_counter + 1;
      EXCEPTION
        WHEN dup_val_on_index THEN
          -----ORA-00001: unique constraint (WSH_ORG_CARRIER_SERVICES_U2) violated
          -------unique constraint WSH_ORG_CARRIER_SERVICES_U2 (organization_id,carrier_service_id) 
          v_already_exist_records_cntr := v_already_exist_records_cntr + 1;
      END;
      ---=================== the end of org_carrier_services LOOP ==============================
    END LOOP;
    COMMIT;
    IF v_inserted_records_counter > 0 THEN
      message(v_inserted_records_counter ||
              ' records were inserted into WSH_ORG_CARRIER_SERVICES for organization_id=' ||
              p_to_organization_id || '==============');
    END IF;
    IF v_already_exist_records_cntr > 0 THEN
      message(v_already_exist_records_cntr ||
              ' records already exist in WSH_ORG_CARRIER_SERVICES for organization_id=' ||
              p_to_organization_id || '==============');
    END IF;
  
    v_step                       := 'Step 20';
    v_inserted_records_counter   := 0;
    v_already_exist_records_cntr := 0;
    FOR data_rec IN c_get_carrier_ship_methods LOOP
      ---========================= carrier_ship_methods LOOP ==============================
      BEGIN
        INSERT INTO wsh_carrier_ship_methods
          (carrier_ship_method_id,
           service_level,
           carrier_id,
           freight_code,
           ship_method_code,
           organization_id,
           web_enabled,
           enabled_flag,
           creation_date,
           created_by,
           last_update_date,
           last_updated_by)
        VALUES
          (wsh_carrier_ship_methods_s.nextval, --  carrier_ship_method_id,
           data_rec.service_level,
           data_rec.carrier_id,
           data_rec.freight_code,
           data_rec.ship_method_code,
           p_to_organization_id,
           data_rec.web_enabled,
           data_rec.enabled_flag,
           SYSDATE, --creation_date
           fnd_global.user_id, --created_by,
           SYSDATE, --last_update_date
           fnd_global.user_id --last_updated_by
           );
        COMMIT;
        v_inserted_records_counter := v_inserted_records_counter + 1;
      EXCEPTION
        WHEN dup_val_on_index THEN
          -----ORA-00001: unique constraint ...
          v_already_exist_records_cntr := v_already_exist_records_cntr + 1;
      END;
      ---=================== the end of carrier_ship_methods LOOP ==============================
    END LOOP;
    COMMIT;
    IF v_inserted_records_counter > 0 THEN
      message(v_inserted_records_counter ||
              ' records were inserted into WSH_CARRIER_SHIP_METHODS for organization_id=' ||
              p_to_organization_id || '==============');
    END IF;
    IF v_already_exist_records_cntr > 0 THEN
      message(v_already_exist_records_cntr ||
              ' records already exist in WSH_CARRIER_SHIP_METHODS for organization_id=' ||
              p_to_organization_id || '==============');
    END IF;
  
    v_step                       := 'Step 30';
    v_inserted_records_counter   := 0;
    v_already_exist_records_cntr := 0;
    FOR data_rec IN c_get_org_freight_tl LOOP
      ---========================= org_freight_tl LOOP ==============================
      BEGIN
        INSERT INTO org_freight_tl
          (source_lang,
           LANGUAGE,
           description,
           party_id,
           organization_id,
           freight_code_tl,
           freight_code,
           disable_date,
           creation_date,
           created_by,
           last_update_date,
           last_updated_by)
        VALUES
          (data_rec.source_lang,
           data_rec.language,
           data_rec.description,
           data_rec.party_id,
           p_to_organization_id,
           data_rec.freight_code_tl,
           data_rec.freight_code,
           data_rec.disable_date,
           SYSDATE, --creation_date
           fnd_global.user_id, --created_by,
           SYSDATE, --last_update_date
           fnd_global.user_id --last_updated_by
           );
        COMMIT;
        v_inserted_records_counter := v_inserted_records_counter + 1;
      EXCEPTION
        WHEN dup_val_on_index THEN
          -----ORA-00001: unique constraint ...
          v_already_exist_records_cntr := v_already_exist_records_cntr + 1;
      END;
      ---=================== the end of org_freight_tl LOOP ==============================
    END LOOP;
    COMMIT;
    IF v_inserted_records_counter > 0 THEN
      message(v_inserted_records_counter ||
              ' records were inserted into ORG_FREIGHT_TL for organization_id=' ||
              p_to_organization_id || '==============');
    END IF;
    IF v_already_exist_records_cntr > 0 THEN
      message(v_already_exist_records_cntr ||
              ' records already exist in ORG_FREIGHT_TL for organization_id=' ||
              p_to_organization_id || '==============');
    END IF;
  
    v_step := 'Step 400';
    message('RESULTS =========================================================');
    message('Concurrent program was completed successfully ===================');
    message('=================================================================');
  
  EXCEPTION
    WHEN stop_processing THEN
      v_error_message := 'ERROR in xxconv_wsh_pkg.org_carrier_assignment : ' ||
                         v_error_message;
      message(v_error_message);
      retcode := '2';
      errbuf  := v_error_message;
    WHEN OTHERS THEN
      v_error_message := substr('Unexpected ERROR in xxconv_wsh_pkg.org_carrier_assignment  (' ||
                                v_step || ') ' || SQLERRM,
                                1,
                                200);
      message(v_error_message);
      retcode := '2';
      errbuf  := v_error_message;
  END org_carrier_assignment;
  ----------------------------------------------------------------------------------------- 
END xxconv_wsh_pkg;
/
