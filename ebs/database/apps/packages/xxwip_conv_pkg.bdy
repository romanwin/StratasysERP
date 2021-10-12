CREATE OR REPLACE PACKAGE BODY xxwip_conv_pkg IS
  ------------------------------------------------------------------
  -- $Header: xxwip_conv_pkg   $
  ------------------------------------------------------------------
  -- Package: XXWIP_CONV_PKG
  -- Created:
  -- Author:  Vitaly
  ------------------------------------------------------------------
  -- Purpose: 
  ------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ----------------------------
  --     1.0  07.10.13   Vitaly         initial build
  ------------------------------------------------------------------

  ----------------------------------------------------------------------------
  -- copy_unreleased_jobs
  --------------------------------------------------------------------------
  -- Version  Date        Performer       Comments
  ----------  --------    --------------  -------------------------------------
  -- 1.0      07.10.2013  Vitaly          cr1006 initial revision
  ---------------------------------------------------------------------------
  PROCEDURE copy_unreleased_jobs(errbuf                 OUT VARCHAR2,
                                 retcode                OUT VARCHAR2,
                                 p_from_organization_id IN NUMBER,
                                 p_to_organization_id   IN NUMBER,
                                 p_group_id             IN NUMBER,
                                 p_creation_date        IN VARCHAR2) IS
    v_step                    VARCHAR2(100);
    v_from_organization_code  VARCHAR2(100);
    v_to_organization_code    VARCHAR2(100);
    v_creation_date           DATE;
    v_error_message           VARCHAR2(3000);
    v_num_of_inserted_records NUMBER;
    stop_processing EXCEPTION;
  
  BEGIN
  
    v_step  := 'Step 0';
    errbuf  := NULL;
    retcode := '0';
  
    v_step := 'Step 10';
    IF p_from_organization_id IS NULL THEN
      v_error_message := 'Error: Missing parameter p_from_organization_id';
      RAISE stop_processing;
    ELSE
      -------
      BEGIN
        SELECT
        ---a.lookup_code   old_organization_id, 
         mp_old.organization_code old_organization_code
        --a.attribute1  new_organization_id,
        ---mp_new.organization_code  new_organization_code
          INTO v_from_organization_code
          FROM fnd_lookup_values_vl a,
               mtl_parameters       mp_old,
               mtl_parameters       mp_new
         WHERE a.lookup_type = 'XXCST_INV_ORG_REPLACE' ---old organization -- new organization mapping
           AND a.lookup_code = mp_old.organization_id
           AND a.attribute1 = mp_new.organization_id
           AND a.lookup_code = p_from_organization_id; ---parameter  
      EXCEPTION
        WHEN no_data_found THEN
          v_error_message := 'Error: Invalid parameter p_from_organization_id=' ||
                             p_from_organization_id;
          RAISE stop_processing;
      END;
      -------
    END IF;
  
    v_step := 'Step 20';
    IF p_to_organization_id IS NULL THEN
      v_error_message := 'Error: Missing parameter p_to_organization_id';
      RAISE stop_processing;
    ELSE
      -------
      BEGIN
        SELECT
        ---a.lookup_code   old_organization_id, 
        --- mp_old.organization_code old_organization_code
        --a.attribute1  new_organization_id,
         mp_new.organization_code new_organization_code
          INTO v_to_organization_code
          FROM fnd_lookup_values_vl a,
               mtl_parameters       mp_old,
               mtl_parameters       mp_new
         WHERE a.lookup_type = 'XXCST_INV_ORG_REPLACE' ---old organization -- new organization mapping
           AND a.lookup_code = mp_old.organization_id
           AND a.attribute1 = mp_new.organization_id
           AND a.lookup_code = p_from_organization_id ---parameter
           AND a.attribute1 = p_to_organization_id; ---parameter  
      EXCEPTION
        WHEN no_data_found THEN
          v_error_message := 'Error: Invalid parameter p_to_organization_id=' ||
                             p_to_organization_id ||
                             ' for a choosen p_from_organization_id=' ||
                             p_from_organization_id || ' --- ' ||
                             v_from_organization_code;
          RAISE stop_processing;
      END;
      -------
    END IF;
  
    v_step := 'Step 30';
    IF p_group_id IS NULL THEN
      v_error_message := 'Error: Missing parameter p_group_id';
      RAISE stop_processing;
    END IF;
  
    v_step := 'Step 40';
    IF p_creation_date IS NULL THEN
      v_error_message := 'Error: Missing parameter p_creation_date';
      RAISE stop_processing;
    ELSE
      -------
      BEGIN
        v_creation_date := fnd_date.canonical_to_date(p_creation_date); ---parameter
      EXCEPTION
        WHEN OTHERS THEN
          v_error_message := 'Error: Invalid parameter p_creation_date=' ||
                             p_creation_date;
          RAISE stop_processing;
      END;
      -------
    
    END IF;
  
    fnd_file.put_line(fnd_file.log,
                      '=============================== PARAMETERS =======================================');
    fnd_file.put_line(fnd_file.log,
                      'p_from_organization_id=' || p_from_organization_id || ' (' ||
                      v_from_organization_code || ')');
    fnd_file.put_line(fnd_file.log,
                      'p_to_organization_id=' || p_to_organization_id || ' (' ||
                      v_to_organization_code || ')');
    fnd_file.put_line(fnd_file.log, 'p_group_id=' || p_group_id);
    fnd_file.put_line(fnd_file.log, 'p_creation_date=' || p_creation_date);
  
    v_step := 'Step 50';
    INSERT INTO wip_job_schedule_interface
      (organization_id,
       primary_item_id,
       job_name,
       start_quantity,
       net_quantity,
       first_unit_start_date,
       class_code,
       status_type,
       group_id,
       header_id,
       load_type,
       process_phase,
       process_status,
       created_by,
       creation_date,
       last_updated_by,
       last_update_date,
       attribute1,
       attribute2,
       attribute3,
       attribute9,
       attribute12,
       attribute13,
       attribute14,
       attribute15)
      SELECT p_to_organization_id, --- parameter,
             wdj.primary_item_id, --primary_item_id,
             we.wip_entity_name, --job_name
             wdj.start_quantity, --start_quantity,
             wdj.net_quantity, -- net_quantity,
             wdj.scheduled_start_date, --first_unit_start_date
             wdj.class_code, --class_code
             wdj.status_type, --status_type,
             p_group_id, --group_id
             wip_job_number_s.nextval, --header_id
             1, -- load_type
             2, --process_phase
             1, --PROCESS_STATUS
             fnd_global.user_id, --created_by
             SYSDATE, --creation_date
             fnd_global.user_id, --created_by
             SYSDATE, --last_update_date
             attribute1, --attribute1
             attribute2, --attribute2
             attribute3, --attribute3
             attribute9, --attribute9
             attribute12, --attribute12
             attribute13, --attribute13
             attribute14, --attribute14
             attribute15 -- attribute15
        FROM wip_discrete_jobs wdj, wip_entities we
       WHERE wdj.status_type = 1 --UNRELEASE 
            --  AND wdj.job_type = 1 --std
         AND we.wip_entity_id = wdj.wip_entity_id
         AND we.organization_id = wdj.organization_id
         AND wdj.organization_id = p_from_organization_id --- parameter
         AND wdj.creation_date >= v_creation_date; --- parameter
  
    v_step                    := 'Step 60';
    v_num_of_inserted_records := SQL%ROWCOUNT;
    IF v_num_of_inserted_records = 0 THEN
      fnd_file.put_line(fnd_file.log,
                        '*********** WARNING **** NO RECORDS INSERTED into table WIP_JOB_SCHEDULE_INTERFACE **********');
      errbuf  := ' No records inserted into table WIP_JOB_SCHEDULE_INTERFACE';
      retcode := '1';
    ELSE
      fnd_file.put_line(fnd_file.log,
                        '*********** ' || v_num_of_inserted_records ||
                        ' records inserted into table WIP_JOB_SCHEDULE_INTERFACE ******************');
    END IF;
    fnd_file.put_line(fnd_file.log,
                      '************** The end of program *************************************************');
  
    COMMIT;
  
  EXCEPTION
    WHEN stop_processing THEN
      fnd_file.put_line(fnd_file.log, v_error_message);
      errbuf  := v_error_message;
      retcode := '2';
    WHEN OTHERS THEN
      errbuf  := substr('Unexpected Error in xxwip_conv_pkg.copy_unreleased_jobs (' ||
                        v_step || '): ' || SQLERRM,
                        1,
                        100);
      retcode := '2';
  END copy_unreleased_jobs;
  -------------------------------------------------------------
END xxwip_conv_pkg;
/
