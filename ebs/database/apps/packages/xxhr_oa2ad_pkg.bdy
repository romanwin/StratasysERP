CREATE OR REPLACE PACKAGE BODY xxhr_oa2ad_pkg IS

  --------------------------------------------------------------------
  --  name:            XXHR_OA2AD_PKG
  --  create by:       Dalit A. Raviv
  --  Revision:        1.7
  --  creation date:   10/10/2011 1:45:30 PM
  --------------------------------------------------------------------
  --  purpose :        CUST460 - Active directory interface
  --
  --                   This Package handle Active directory interface
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  10/10/2011  Dalit A. Raviv    initial build
  --  1.1  09/01/2012  Dalit A. Raviv    procedure populate diff interface - changed logic
  --  1.2  19/01/2012  Dalit A. Raviv    HR department requested not to show employee
  --                                     position(Title) at AD.
  --                                     therfor i need to take position from the program
  --                                     procedures - populate_interface, populate_diff_interface xxhr_oa2ad_pkg
  --  1.3  14/02/2012  Dalit A. raviv    Add handling of changed position interface
  --                                     new procedure - insert_position_diff
  --                                     new procedure - populate_diff_position
  --                                     new procedure - update_diff_position_int
  --                                     new procedure - position_send_mail
  --  1.4  28/02/2012  Dalit A. Raviv    Procedure send_mail_position
  --                                     Change select that check if there are rows to send mail.
  --  1.5  30/04/2012  Dalit A. Raviv    Proceduer populate_interface - Hadle exception persons
  --  1.6  5.12.2012   yuval tal         bugfix for populate_diff_position : hirarchy location for employee with no old position
  --  1.7  09/02/2014  Dalit A. Raviv    Handle change in Organization name and not id
  --------------------------------------------------------------------

  g_user_id      NUMBER := nvl(fnd_profile.value('USER_ID'), 2470);
  g_batch_id     NUMBER := NULL;
  g_max_batch_id NUMBER := NULL;

  --------------------------------------------------------------------
  --  name:            insert_person_interface
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   10/10/2011 1:45:30 PM
  --------------------------------------------------------------------
  --  purpose :        CUST460 - Active directory interface
  --
  --                   Insert row to person interface table
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  10/10/2011  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE insert_person_interface(p_person_rec IN t_person_rec,
                                    p_batch_id   IN NUMBER,
                                    p_err_code   OUT NUMBER,
                                    p_err_desc   OUT VARCHAR2) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
    l_entity_id NUMBER := NULL;
  BEGIN
    p_err_code := 0;
    p_err_desc := NULL;
    -- get entity id
    SELECT xxhr_persons_interface_seq.nextval INTO l_entity_id FROM dual;
  
    INSERT INTO xxhr_persons_interface
      (enttity_id, -- n
       batch_id, -- n
       person_id, -- n
       user_person_type, -- v 240
       location_id, -- n
       position_id, -- n
       organization_id, -- n
       organization_name,  -- Dalit A. Raviv 09/02/2014
       mobile_number, -- v 60
       supervisor_id, -- n
       period_terminate_date, -- d
       grade_id, -- n
       office_phone_extension, -- v
       office_phone_full, -- v
       office_fax, -- v
       last_update_date, -- d
       last_updated_by, -- n
       last_update_login, -- n
       creation_date, -- d
       created_by) -- n
    VALUES
      (l_entity_id,
       p_batch_id,
       p_person_rec.person_id,
       p_person_rec.user_person_type,
       p_person_rec.location_id,
       p_person_rec.position_id,
       p_person_rec.organization_id,
       p_person_rec.organization_name, -- Dalit A. Raviv 09/02/2014
       p_person_rec.mobile_number,
       p_person_rec.supervisor_id,
       p_person_rec.period_terminate_date,
       p_person_rec.grade_id,
       p_person_rec.office_phone_extension,
       p_person_rec.office_phone_full,
       p_person_rec.office_fax,
       SYSDATE,
       g_user_id,
       -1,
       SYSDATE,
       g_user_id);
  
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log,
                        'Procedure insert_person_interface - Failed - ' ||
                        substr(SQLERRM, 1, 240));
      ROLLBACK;
      p_err_code := 1;
      p_err_desc := 'Procedure insert_person_interface - Failed - ' ||
                    substr(SQLERRM, 1, 240);
  END insert_person_interface;

  --------------------------------------------------------------------
  --  name:            insert_person_interface
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   10/10/2011 1:45:30 PM
  --------------------------------------------------------------------
  --  purpose :        CUST460 - Active directory interface
  --
  --                   Insert row to XXHR_DIFF_PERSONS_INTERFACE table
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  10/10/2011  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE insert_diff_person_interface(p_person_diff_rec IN t_person_rec,
                                         p_status          IN VARCHAR2,
                                         p_batch_id        IN NUMBER,
                                         p_err_code        OUT NUMBER,
                                         p_err_desc        OUT VARCHAR2) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
    l_entity_id NUMBER := NULL;
  
  BEGIN
    p_err_code := 0;
    p_err_desc := NULL;
    -- get entity id
    SELECT xxhr_diff_persons_inter_seq.nextval INTO l_entity_id FROM dual;
  
    INSERT INTO xxhr_diff_persons_interface
      (enttity_id, -- n
       batch_id, -- n
       person_id, -- n
       user_person_type, -- v 240
       location_id, -- n
       position_id, -- n
       organization_id, -- n
       organization_name, -- Dalit A. Raviv 09/02/2014
       mobile_number, -- v 60
       supervisor_id, -- n
       grade_id, -- n
       office_phone_extension, -- v
       office_phone_full, -- v
       office_fax, -- v
       status, -- v 20 NEW/UPDATE/END
       process_mode, -- v 20 NEW/INPROCESS/SENDMAIL/PREMAIL/ERROR/
       log_code, -- v 50
       log_msg, -- v 2000
       last_update_date, -- d
       last_updated_by, -- n
       last_update_login, -- n
       creation_date, -- d
       created_by) -- n
    VALUES
      (l_entity_id,
       p_batch_id,
       p_person_diff_rec.person_id,
       p_person_diff_rec.user_person_type,
       p_person_diff_rec.location_id,
       p_person_diff_rec.position_id,
       p_person_diff_rec.organization_id,
       p_person_diff_rec.organization_name,
       p_person_diff_rec.mobile_number,
       p_person_diff_rec.supervisor_id,
       p_person_diff_rec.grade_id,
       p_person_diff_rec.office_phone_extension,
       p_person_diff_rec.office_phone_full,
       p_person_diff_rec.office_fax,
       p_status,
       'NEW',
       NULL,
       NULL,
       SYSDATE,
       g_user_id,
       -1,
       SYSDATE,
       g_user_id);
    COMMIT;
  
  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log,
                        'Procedure insert_diff_person_interface - Failed - ' ||
                        substr(SQLERRM, 1, 240));
      ROLLBACK;
      p_err_code := 1;
      p_err_desc := 'Procedure insert_diff_person_interface - Failed - ' ||
                    substr(SQLERRM, 1, 240);
  END insert_diff_person_interface;

  --------------------------------------------------------------------
  --  name:            update_diff_person_interface
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   23/10/2011 1:45:30 PM
  --------------------------------------------------------------------
  --  purpose :        CUST460 - Active directory interface
  --
  --                   update XXHR_DIFF_PERSONS_INTERFACE table with process_mode
  --                   and log messages
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  23/10/2011  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE update_diff_person_interface(errbuf              OUT VARCHAR2,
                                         retcode             OUT NUMBER,
                                         p_to_process_mode   IN VARCHAR2,
                                         p_from_process_mode IN VARCHAR2,
                                         p_log_message       IN VARCHAR2) IS
    --PRAGMA AUTONOMOUS_TRANSACTION;
  BEGIN
    retcode := 0;
    errbuf  := NULL;
  
    IF p_log_message IS NULL THEN
      UPDATE xxhr_diff_persons_interface diff
         SET diff.process_mode     = p_to_process_mode,
             diff.last_update_date = SYSDATE
       WHERE diff.process_mode = p_from_process_mode;
    ELSIF p_log_message IS NOT NULL THEN
      UPDATE xxhr_diff_persons_interface diff
         SET diff.log_msg          = p_log_message,
             diff.log_code         = 1,
             diff.last_update_date = SYSDATE
       WHERE diff.process_mode = p_from_process_mode;
    END IF;
  
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log,
                        'Procedure update_diff_person_interface - Failed - ' ||
                        substr(SQLERRM, 1, 240));
      ROLLBACK;
      retcode := 1;
      errbuf  := 'Procedure update_diff_person_interface - Failed - ' ||
                 substr(SQLERRM, 1, 240);
    
  END update_diff_person_interface;

  --------------------------------------------------------------------
  --  name:            get_company_name
  --  create by:       Dalit A. Raviv
  --  Revision:        1.1
  --  creation date:   10/10/2011 1:45:30 PM
  --------------------------------------------------------------------
  --  purpose :        CUST460 - Active directory interface
  --
  --                   Get company name by location of the person (from assignment)
  --                   determin the company name she/he belong too.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  10/10/2011  Dalit A. Raviv    initial build
  --  1.1  09/02/2014  Dalit A. Raviv    Handle change in Organization name and not id
  --------------------------------------------------------------------
  PROCEDURE check_diff_fields(p_person_diff_rec IN OUT t_person_rec,
                              p_err_code        OUT NUMBER,
                              p_err_desc        OUT VARCHAR2) IS
  
    l_person_type            VARCHAR2(240);
    l_location_id            NUMBER;
    l_position_id            NUMBER;
    l_organization_id        NUMBER;
    l_mobile_number          VARCHAR2(60);
    l_supervisor_id          NUMBER;
    l_period_terminate_date  DATE;
    l_grade_id               NUMBER;
    l_office_phone_extension VARCHAR2(150);
    l_office_phone_full      VARCHAR2(150);
    l_office_fax             VARCHAR2(150);
    l_organization_name      VARCHAR2(150);
  
  BEGIN
    p_err_code := 0;
    p_err_desc := NULL;
  
    BEGIN
      SELECT user_person_type,
             location_id,
             position_id,
             organization_id,
             organization_name, -- Dalit A. Raviv 09/02/2014
             mobile_number,
             supervisor_id,
             period_terminate_date,
             grade_id,
             b.office_phone_extension,
             b.office_phone_full,
             b.office_fax
        INTO l_person_type,
             l_location_id,
             l_position_id,
             l_organization_id,
             l_organization_name, -- Dalit A. Raviv 09/02/2014
             l_mobile_number,
             l_supervisor_id,
             l_period_terminate_date,
             l_grade_id,
             l_office_phone_extension,
             l_office_phone_full,
             l_office_fax
        FROM xxhr_persons_interface b
       WHERE batch_id = g_max_batch_id
         AND person_id = p_person_diff_rec.person_id;
    
      IF l_person_type = p_person_diff_rec.user_person_type THEN
        p_person_diff_rec.user_person_type := NULL;
      END IF;
      IF l_location_id = p_person_diff_rec.location_id THEN
        p_person_diff_rec.location_id := NULL;
      END IF;
      IF l_position_id = p_person_diff_rec.position_id THEN
        p_person_diff_rec.position_id := NULL;
      END IF;
      IF l_organization_id = p_person_diff_rec.organization_id THEN
        p_person_diff_rec.organization_id := NULL;
      END IF;
      -- Dalit A. Raviv 09/02/2014
      IF l_organization_name = p_person_diff_rec.organization_name THEN
        p_person_diff_rec.organization_name := NULL;
      else
        p_person_diff_rec.organization_id := l_organization_id;
      END IF;
      --
      IF l_mobile_number = p_person_diff_rec.mobile_number THEN
        p_person_diff_rec.mobile_number := NULL;
      END IF;
      IF l_supervisor_id = p_person_diff_rec.supervisor_id THEN
        p_person_diff_rec.supervisor_id := NULL;
      END IF;
      IF l_period_terminate_date = p_person_diff_rec.period_terminate_date THEN
        p_person_diff_rec.period_terminate_date := NULL;
      END IF;
      IF l_grade_id = p_person_diff_rec.grade_id THEN
        p_person_diff_rec.grade_id := NULL;
      END IF;
      IF l_office_phone_extension =
         p_person_diff_rec.office_phone_extension THEN
        p_person_diff_rec.office_phone_extension := NULL;
      END IF;
      IF l_office_phone_full = p_person_diff_rec.office_phone_full THEN
        p_person_diff_rec.office_phone_full := NULL;
      END IF;
      IF l_office_fax = p_person_diff_rec.office_fax THEN
        p_person_diff_rec.office_fax := NULL;
      END IF;
    
    EXCEPTION
      -- this is a new employee
      WHEN OTHERS THEN
        NULL;
    END;
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code := 1;
      p_err_desc := 'Procedure check_diff_fields - Failed - ' ||
                    substr(SQLERRM, 1, 240);
  END check_diff_fields;

  --------------------------------------------------------------------
  --  name:            delete_person_interface
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   16/11/2011
  --------------------------------------------------------------------
  --  purpose :        CUST460 - Active directory interface
  --
  --                   delete interface table data that is old then 45 days.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  16/11/2011  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE delete_person_interface(errbuf  OUT VARCHAR2,
                                    retcode OUT NUMBER) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
  
    l_days NUMBER := NULL;
  BEGIN
    l_days := fnd_profile.value('XXHR_OA2AD_DAYS_TO_DEL_EMP_INTERFACE'); -- 45
  
    DELETE xxhr_persons_interface INT
     WHERE int.creation_date < SYSDATE - l_days;
  
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      retcode := 1;
      errbuf  := 'Procedure delete_person_interface - Failed - ' ||
                 substr(SQLERRM, 1, 240);
  END delete_person_interface;

  --------------------------------------------------------------------
  --  name:            delete_diff_person_interface
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   16/11/2011
  --------------------------------------------------------------------
  --  purpose :        CUST460 - Active directory interface
  --
  --                   delete interface table data that is old then 45 days.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  16/11/2011  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE delete_diff_person_interface(errbuf  OUT VARCHAR2,
                                         retcode OUT NUMBER) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
  
    l_days NUMBER := NULL;
  BEGIN
    l_days := fnd_profile.value('XXHR_OA2AD_DAYS_TO_DEL_EMP_DIFF_INTERFACE'); -- 180
  
    DELETE xxhr_diff_persons_interface diff
     WHERE diff.creation_date < SYSDATE - l_days;
  
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      retcode := 1;
      errbuf  := 'Procedure delete_person_interface - Failed - ' ||
                 substr(SQLERRM, 1, 240);
  END delete_diff_person_interface;

  --------------------------------------------------------------------
  --  name:            populate_interface
  --  create by:       Dalit A. Raviv
  --  Revision:        1.3
  --  creation date:   10/10/2011 1:45:30 PM
  --------------------------------------------------------------------
  --  purpose :        CUST460 - Active directory interface
  --
  --                   Populate interface with today all Objet persons data
  --                   today - yesterday will give all persons that had changes.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  10/10/2011  Dalit A. Raviv    initial build
  --  1.1  19/01/2012  Dalit A. Raviv    HR department requested not to show employee
  --                                     position(Title) at AD.
  --                                     therfor i need to take position from the program
  --                                     set position field to null
  --  1.2  30/04/2012  Dalit A. Raviv    Hadle exception persons
  --  1.3  09/02/2014  Dalit A. Raviv    Handle change in Organization name and not id
  --------------------------------------------------------------------
  PROCEDURE populate_interface(p_batch_id OUT NUMBER,
                               p_err_code OUT NUMBER,
                               p_err_desc OUT VARCHAR2) IS
  
    CURSOR today_population_c IS
      SELECT paa.person_id,
             xxper.user_person_type,
             paa.location_id,
             ---- 1.1  19/01/2012  Dalit A. Raviv
             paa.position_id,
             --to_number(null)               position_id,
             ---- end 1.1
             paa.organization_id,
             --  1.3  09/02/2014  Dalit A. Raviv
             xxhr_util_pkg.get_org_name(paa.organization_id) organization_name, 
             -- 
             (SELECT phone.cellular_phone
                FROM xxhr_cell_phone_eit_v phone
               WHERE phone.person_id = paa.person_id
                 AND rownum = 1) mobile_number,
             paa.supervisor_id,
             xxper.period_actual_termination_date,
             -- 1.1  19/01/2012  Dalit A. Raviv
             --paa.grade_id,,
             to_number(NULL) grade_id,
             --
             it.office_phone_extension,
             it.office_phone_full,
             it.office_fax
        FROM per_all_assignments_f         paa,
             per_assignment_status_types   paat,
             xxhr_person_periods_details_v xxper,
             xxhr_it_eit_v                 it
       WHERE 1 = 1
         AND paat.assignment_status_type_id = paa.assignment_status_type_id
         AND paa.assignment_type IN ('E', 'C')
         AND paa.primary_flag = 'Y'
         AND trunc(SYSDATE) BETWEEN paa.effective_start_date AND
             paa.effective_end_date
         AND trunc(SYSDATE) BETWEEN xxper.person_effective_start_date AND
             xxper.person_effective_end_date
         AND xxper.period_actual_termination_date >= trunc(SYSDATE)
            --and    (xxper.period_actual_termination_date    = trunc(sysdate - 1)
            --        or xxper.period_actual_termination_date = '31-DEC-4712')
         AND xxper.per_person_id = paa.person_id
         AND it.person_id(+) = paa.person_id
            --and    paa.person_id                  not in (61,1121,1122,5721);--( 145, 861);
            --  1.2  30/04/2012  Dalit A. Raviv    Hadle exception persons
         AND paa.person_id NOT IN
             (SELECT fv.flex_value
                FROM fnd_flex_values_vl fv, fnd_flex_value_sets fvs
               WHERE fv.flex_value_set_id = fvs.flex_value_set_id
                 AND fvs.flex_value_set_name LIKE 'XXHR_EXCEPTION_PERSONS'
                 AND fv.enabled_flag = 'Y'
                 AND trunc(SYSDATE) BETWEEN
                     nvl(fv.start_date_active, SYSDATE - 1) AND
                     nvl(fv.end_date_active, SYSDATE + 1));
  
    l_person_rec t_person_rec;
    l_err_code   NUMBER;
    l_err_desc   VARCHAR2(500);
  BEGIN
    p_err_code := 0;
    p_err_desc := NULL;
  
    -- get batch id for all the program
    SELECT xxhr_persons_inter_batch_seq.nextval INTO g_batch_id FROM dual;
    dbms_output.put_line('Batch - ' || p_batch_id);
  
    p_batch_id := g_batch_id;
  
    FOR today_population_r IN today_population_c LOOP
      l_person_rec := today_population_r;
      insert_person_interface(p_person_rec => l_person_rec, -- i t_person_rec,
                              p_batch_id   => g_batch_id, -- i n
                              p_err_code   => l_err_code, -- o n
                              p_err_desc   => l_err_desc); -- o v
      IF l_err_code > 0 THEN
        fnd_file.put_line(fnd_file.log,
                          'Failed to insert diff row, Person id - ' ||
                          today_population_r.person_id);
        dbms_output.put_line('F1 Person id - ' ||
                             today_population_r.person_id);
        --else
        --  dbms_output.put_line('S1 entity id - '||today_population_r.entity_id);
      END IF;
    END LOOP;
  
  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log,
                        'Procedure populate_interfac - Failed - ' ||
                        substr(SQLERRM, 1, 240));
      p_err_code := 1;
      p_err_desc := 'Procedure populate_interface - Failed - ' ||
                    substr(SQLERRM, 1, 240);
  END populate_interface;

  --------------------------------------------------------------------
  --  name:            populate_diff_interface
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   10/10/2011 1:45:30 PM
  --------------------------------------------------------------------
  --  purpose :        CUST460 - Active directory interface
  --
  --                   Find the diff between today and yesterday
  --                   today - yesterday will give all persons that had changes.
  --                   mark all rows with NEW process_mode
  --                   mark each row if status is NEW or UPDATE TERMINATE
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  10/10/2011  Dalit A. Raviv    initial build
  --  1.1  09/01/2012  Dalit A. Raviv    when employee finish working at Objet company
  --                                     Termination process start. field period_terminate_date
  --                                     get value (even if it is in the future)
  --                                     at this time program see change at person details but it is not correct.
  --                                     the mail send empty line to Helpdesk.
  --  1.2  19/01/2012  Dalit A. Raviv    HR department requested not to show employee
  --                                     position(Title) at AD.
  --                                     therfor i need to take position from the program
  --                                     set position field to null
  --  1.3  09/02/2014  Dalit A. Raviv    Handl echange in Organization name and not id
  --------------------------------------------------------------------
  PROCEDURE populate_diff_interface(p_batch_id IN NUMBER,
                                    p_err_code OUT NUMBER,
                                    p_err_desc OUT VARCHAR2) IS
  
    CURSOR get_diff_pop_c IS
    -- today run
    -- 1.1 Dalit A. Raviv 09/01/2012 take off period_termination_date
      SELECT person_id,
             user_person_type,
             location_id,
             to_number(NULL) /*position_id*/,
             organization_id,
             -- 1.3 09/02/2014 Dalit A. Raviv 
             organization_name,
             --
             mobile_number,
             supervisor_id, /*period_terminate_date*/
             to_date(NULL),
             to_number(NULL) /*grade_id*/,
             office_phone_extension,
             office_phone_full,
             office_fax
        FROM xxhr_persons_interface a
       WHERE batch_id = p_batch_id
      MINUS
      -- last run
      SELECT person_id,
             user_person_type,
             location_id,
             to_number(NULL) /*position_id*/,
             organization_id,
             -- 1.3 09/02/2014 Dalit A. Raviv
             organization_name,
             --
             mobile_number,
             supervisor_id, /*period_terminate_date*/
             to_date(NULL),
             to_number(NULL) /*grade_id*/,
             office_phone_extension,
             office_phone_full,
             office_fax
        FROM xxhr_persons_interface b
       WHERE batch_id = g_max_batch_id;
  
    CURSOR ex_emp_pop_c IS
    -- last run
      SELECT person_id,
             user_person_type,
             location_id,
             to_number(NULL) /*position_id*/,
             organization_id,
             organization_name, -- 1.3 Dalit A. Raviv
             mobile_number,
             supervisor_id, /*period_terminate_date*/
             to_date(NULL),
             to_number(NULL) /*grade_id*/,
             office_phone_extension,
             office_phone_full,
             office_fax
        FROM xxhr_persons_interface b
       WHERE batch_id = g_max_batch_id
      MINUS
      -- today run
      SELECT person_id,
             user_person_type,
             location_id,
             to_number(NULL) /*position_id*/,
             organization_id,
             organization_name, -- 1.3 Dalit A. Raviv
             mobile_number,
             supervisor_id, /*period_terminate_date*/
             to_date(NULL),
             to_number(NULL) /*grade_id*/,
             office_phone_extension,
             office_phone_full,
             office_fax
        FROM xxhr_persons_interface a
       WHERE batch_id = p_batch_id;
  
    l_person_diff_rec t_person_rec;
    l_err_code        NUMBER;
    l_err_desc        VARCHAR2(500);
    l_exist           VARCHAR2(5) := 'N';
  BEGIN
    p_err_code := 0;
    p_err_desc := NULL;
    dbms_output.put_line('Diff Batch - ' || p_batch_id);
    FOR get_diff_pop_r IN get_diff_pop_c LOOP
      l_person_diff_rec := get_diff_pop_r;
      -- i want the mail to send only data that changed
      check_diff_fields(p_person_diff_rec => l_person_diff_rec, -- i o t_person_rec
                        p_err_code        => l_err_code, -- o   n
                        p_err_desc        => l_err_desc); -- o   v
    
      -- to check at last run if this person exists and if yes if this is termination
      insert_diff_person_interface(p_person_diff_rec => l_person_diff_rec, -- i t_person_rec,
                                   p_status          => NULL, -- i v
                                   p_batch_id        => p_batch_id, -- i n
                                   p_err_code        => l_err_code, -- o n
                                   p_err_desc        => l_err_desc); -- o v
      IF l_err_code > 0 THEN
        fnd_file.put_line(fnd_file.log,
                          'Failed to insert diff row : ' ||
                          l_person_diff_rec.person_id);
        dbms_output.put_line('F Person id - ' ||
                             l_person_diff_rec.person_id);
      ELSE
        dbms_output.put_line('S person id - ' ||
                             l_person_diff_rec.person_id);
      END IF;
    END LOOP;
    -- this cursor handle employees that where terminate working at Objet
    FOR ex_emp_pop_r IN ex_emp_pop_c LOOP
      l_person_diff_rec := ex_emp_pop_r;
      BEGIN
        SELECT 'Y'
          INTO l_exist
          FROM xxhr_diff_persons_interface diff
         WHERE diff.person_id = ex_emp_pop_r.person_id
           AND batch_id = p_batch_id;
      
      EXCEPTION
        WHEN OTHERS THEN
          check_diff_fields(p_person_diff_rec => l_person_diff_rec, -- i o t_person_rec
                            p_err_code        => l_err_code, -- o   n
                            p_err_desc        => l_err_desc); -- o   v
          -- to check at last run if this person exists and if yes if this is termination
          insert_diff_person_interface(p_person_diff_rec => l_person_diff_rec, -- i t_person_rec,
                                       p_status          => 'EX', -- i v
                                       p_batch_id        => p_batch_id, -- i n
                                       p_err_code        => l_err_code, -- o n
                                       p_err_desc        => l_err_desc); -- o v
      END;
    END LOOP;
  
  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log,
                        'Procedure populate_diff_interface - Failed - ' ||
                        substr(SQLERRM, 1, 240));
      p_err_code := 1;
      p_err_desc := 'Procedure populate_diff_interface - Failed - ' ||
                    substr(SQLERRM, 1, 240);
  END populate_diff_interface;

  --------------------------------------------------------------------
  --  name:            update_missing_date
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   10/10/2011 1:45:30 PM
  --------------------------------------------------------------------
  --  purpose :        CUST460 - Active directory interface
  --
  --                   update status and process mode at diff table
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  10/10/2011  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE update_missing_date(p_batch_id IN NUMBER,
                                p_err_code OUT NUMBER,
                                p_err_desc OUT VARCHAR2) IS
  
    PRAGMA AUTONOMOUS_TRANSACTION;
    CURSOR get_difrf_pop_c IS
      SELECT *
        FROM xxhr_diff_persons_interface diff
       WHERE diff.batch_id = p_batch_id;
  
    l_status VARCHAR2(20) := NULL;
    l_count  NUMBER := 0;
    l_exist  VARCHAR2(2) := 'N';
    l_log    VARCHAR2(20) := NULL;
  BEGIN
    p_err_code := 0;
    p_err_desc := NULL;
  
    FOR get_difrf_pop_r IN get_difrf_pop_c LOOP
    
      l_exist := 'N';
      l_count := 0;
      l_log   := NULL;
      -- 1 find new / upd
      SELECT COUNT(*)
        INTO l_count
        FROM xxhr_persons_interface pi
       WHERE pi.person_id = get_difrf_pop_r.person_id
         AND pi.batch_id = g_max_batch_id;
    
      IF l_count > 0 THEN
        -- check if employee become Ex-Employee
        BEGIN
          SELECT 'Y'
            INTO l_exist
            FROM xxhr_diff_persons_interface diff
           WHERE diff.person_id = get_difrf_pop_r.person_id
             AND diff.batch_id = p_batch_id
             AND diff.status = 'EX'
                --and    diff.user_person_type       like 'Ex%'
             AND rownum = 1;
        EXCEPTION
          WHEN OTHERS THEN
            l_exist := 'N';
        END;
      
        IF l_exist = 'Y' THEN
          l_status := 'CLOSE';
          l_log    := 'Close AD User';
        ELSE
          l_status := 'UPDATE';
          l_log    := 'Update AD User';
        END IF;
      ELSIF l_count = 0 THEN
        l_status := 'NEW';
        l_log    := 'New AD User';
      END IF;
    
      -- 2 update diff table
      UPDATE xxhr_diff_persons_interface diff
         SET diff.status           = l_status,
             diff.process_mode     = 'INPROCESS',
             diff.log_msg          = l_log,
             diff.last_update_date = SYSDATE
       WHERE diff.enttity_id = get_difrf_pop_r.enttity_id;
    
      COMMIT;
    END LOOP;
  
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      fnd_file.put_line(fnd_file.log,
                        'Procedure update_missing_date - Failed - ' ||
                        substr(SQLERRM, 1, 240));
      p_err_code := 1;
      p_err_desc := 'Procedure update_missing_date - Failed - ' ||
                    substr(SQLERRM, 1, 240);
  END;

  --------------------------------------------------------------------
  --  name:            send_mail
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   10/10/2011 1:45:30 PM
  --------------------------------------------------------------------
  --  purpose :        CUST460 - Active directory interface
  --
  --                   Send mail
  --                   from diff interface tbl find population to send mail to IT group (Helpdesk)
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  10/10/2011  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE send_mail(errbuf OUT VARCHAR2, retcode OUT NUMBER) IS
  
    l_err_code     NUMBER;
    l_err_desc     VARCHAR2(500);
    l_to_user_name VARCHAR2(150) := NULL;
    l_cc           VARCHAR2(150) := NULL;
    l_bcc          VARCHAR2(150) := NULL;
    l_subject      VARCHAR2(360) := NULL;
    l_att1_proc    VARCHAR2(150) := NULL;
    l_att2_proc    VARCHAR2(150) := NULL;
    l_att3_proc    VARCHAR2(150) := NULL;
    l_count        NUMBER := 0;
  
  BEGIN
  
    l_err_code := 0;
    l_err_desc := NULL;
    /*
    -- 1) mark all INPROCESS rows to PREMAIL
    update_diff_person_interface (errbuf              => l_err_desc,  -- o v
                                  retcode             => l_err_code,  -- o n
                                  p_to_process_mode   => 'PREMAIL',   -- i v
                                  p_from_process_mode => 'INPROCESS', -- i v
                                  p_log_message       => null);       -- o v
    
    */
    SELECT COUNT(1)
      INTO l_count
      FROM xxhr_diff_persons_interface diff
     WHERE diff.process_mode = 'PREMAIL';
  
    IF l_count > 0 THEN
      -- 2) send mail
      -- to will be Helpdesk@objet.com helpdesc do not have user so the WF will
      -- send the mail to user dalit.raviv (HR implementer)
      l_to_user_name := fnd_profile.value('XXHR_AD_SEND_MAIL_TO'); -- 'MICHAL.YAOZ'
      l_cc           := fnd_profile.value('XXHR_AD_SEND_MAIL_CC'); -- Helpdesk@objet.com
      IF nvl(fnd_profile.value('XXHR_ENABLE_BCC_AD_MAIL'), 'N') = 'Y' THEN
        l_bcc := fnd_profile.value('XXHR_AD_SEND_MAIL_BCC'); -- Oracle_HR.Oracle_HR@objet.com
      END IF;
      fnd_message.set_name('XXOBJT', 'XXHR_AD_SEND_MAIL_SUBJECT');
      l_subject  := fnd_message.get;
      l_err_code := 0;
      l_err_desc := NULL;
    
      xxobjt_wf_mail.send_mail_body_proc(p_to_role     => l_to_user_name, -- i v
                                         p_cc_mail     => l_cc, -- i v
                                         p_bcc_mail    => l_bcc, -- i v
                                         p_subject     => l_subject, -- i v
                                         p_body_proc   => 'XXHR_WF_SEND_MAIL_PKG.prepare_AD_clob_body/PREMAIL', -- i v
                                         p_att1_proc   => l_att1_proc, -- i v
                                         p_att2_proc   => l_att2_proc, -- i v
                                         p_att3_proc   => l_att3_proc, -- i v
                                         p_err_code    => l_err_code, -- o n
                                         p_err_message => l_err_desc); -- o v
    
      /*
      if nvl(l_err_code,0) <> 0 then
        -- 3) if send mail failed update with error message.
        update_diff_person_interface (errbuf              => l_err_desc,  -- o v
                                      retcode             => l_err_code,  -- o n
                                      p_to_process_mode   => null,        -- i v
                                      p_from_process_mode => 'PREMAIL',   -- i v
                                      p_log_message       => l_err_desc); -- o v
        errbuf   := l_err_desc;
        retcode  := 1;
      else
        -- 3) mark all PREMAIL rows to SENDMAIL
        update_diff_person_interface (errbuf              => l_err_desc,  -- o v
                                      retcode             => l_err_code,  -- o n
                                      p_to_process_mode   => 'SENDMAIL',  -- i v
                                      p_from_process_mode => 'PREMAIL',   -- i v
                                      p_log_message       => null);       -- o v
        errbuf   := null;
        retcode  := 0;
      end if;
      */
      retcode := l_err_code;
      errbuf  := l_err_desc;
    
    ELSE
      fnd_file.put_line(fnd_file.log,
                        'No rows found to update at Active Directory');
      dbms_output.put_line('No rows found to update at Active Directory');
    END IF; -- l_count
  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log,
                        'Procedure populate_diff_interface - Failed - ' ||
                        substr(SQLERRM, 1, 240));
      retcode := 1;
      errbuf  := 'Procedure populate_diff_interface - Failed - ' ||
                 substr(SQLERRM, 1, 240);
  END send_mail;

  --------------------------------------------------------------------
  --  name:            insert_person_interface
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   14/02/2012
  --------------------------------------------------------------------
  --  purpose :        CUST482 - Employee Position Changed - notify Oracle_Operations - Alert
  --
  --                   Insert row to XXHR_EMP_CHANGE_POSITION_INT table
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  14/02/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE insert_position_diff(p_position_diff_rec IN t_position_diff_rec,
                                 p_batch_id          IN NUMBER,
                                 p_err_code          OUT NUMBER,
                                 p_err_desc          OUT VARCHAR2) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
    l_entity_id NUMBER := NULL;
  BEGIN
    p_err_code := 0;
    p_err_desc := NULL;
    -- get entity id
    SELECT xxhr_emp_change_position_int_s.nextval
      INTO l_entity_id
      FROM dual;
  
    INSERT INTO xxhr_emp_change_position_int
      (enttity_id,
       batch_id,
       person_id,
       user_person_type,
       position_id,
       organization_id,
       send_mail,
       log_msg,
       last_update_date,
       last_updated_by,
       last_update_login,
       creation_date,
       created_by,
       position_info)
    VALUES
      (l_entity_id,
       p_batch_id,
       p_position_diff_rec.person_id,
       p_position_diff_rec.user_person_type,
       p_position_diff_rec.position_id,
       p_position_diff_rec.organization_id,
       p_position_diff_rec.send_mail,
       p_position_diff_rec.log_msg,
       SYSDATE,
       g_user_id,
       -1,
       SYSDATE,
       g_user_id,
       p_position_diff_rec.position_info);
    COMMIT;
  
  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log,
                        'Procedure insert_position_diff - Failed - ' ||
                        substr(SQLERRM, 1, 240));
      ROLLBACK;
      p_err_code := 1;
      p_err_desc := 'Procedure insert_position_diff - Failed - ' ||
                    substr(SQLERRM, 1, 240);
  END insert_position_diff;

  --------------------------------------------------------------------
  --  name:            populate_diff_position
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   14/02/2012
  --------------------------------------------------------------------
  --  purpose :        CUST482 - Employee Position Changed - notify Oracle_Operations - Alert
  --
  --                   Insert row to XXHR_EMP_CHANGE_POSITION_INT table
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  14/02/2012  Dalit A. Raviv    initial build
  --  1.1  19.11.2012  yuval tal         add old position/manager position  location to log message
  --  1.2  05.12.2012  yuval.tal         bugfix for 1.1
  --------------------------------------------------------------------
  PROCEDURE populate_diff_position(p_batch_id IN NUMBER,
                                   p_err_code OUT NUMBER,
                                   p_err_desc OUT VARCHAR2) IS
  
    CURSOR get_diff_pop_c IS
    -- today run
    -- 1.1 Dalit A. Raviv 09/01/2012 take off period_termination_date
      SELECT person_id, position_id
        FROM xxhr_persons_interface a
       WHERE batch_id = p_batch_id
      MINUS
      -- last run
      SELECT person_id, position_id
        FROM xxhr_persons_interface b
       WHERE batch_id = g_max_batch_id;
  
    l_position_diff_rec t_position_diff_rec;
    l_err_code          NUMBER;
    l_err_desc          VARCHAR2(500);
    l_position          NUMBER;
    l_position_name     VARCHAR2(250);
    l_old_pos_location  VARCHAR2(500);
    l_mgr_pos_loction   VARCHAR2(500);
  BEGIN
    p_err_code := 0;
    p_err_desc := NULL;
    dbms_output.put_line('Diff Batch - ' || p_batch_id);
  
    FOR get_diff_pop_r IN get_diff_pop_c LOOP
    
      BEGIN
        -- get detail from the row found
        SELECT person_id,
               user_person_type,
               position_id,
               organization_id,
               organization_name,
               x.supervisor_id,
               'N',
               NULL,
               NULL
          INTO l_position_diff_rec
          FROM xxhr_persons_interface x
         WHERE x.person_id = get_diff_pop_r.person_id
           AND x.batch_id = p_batch_id;
        ---
      
        l_mgr_pos_loction := xxhr_oa2ad_pkg.get_concate_position_hierarchy(xxhr_util_pkg.get_position_id(l_position_diff_rec.supervisor_id));
      
        -------------
        BEGIN
          -- get old position name
          SELECT b.position_id
            INTO l_position
            FROM xxhr_persons_interface b
           WHERE batch_id = g_max_batch_id
             AND b.person_id = get_diff_pop_r.person_id;
        
          IF l_position IS NOT NULL THEN
            BEGIN
              SELECT pp.name
                INTO l_position_name
                FROM per_all_positions pp
               WHERE position_id = l_position;
            
              l_old_pos_location          := xxhr_oa2ad_pkg.get_concate_position_hierarchy(l_position);
              l_position_diff_rec.log_msg := 'Old Position - ' ||
                                             l_position_name;
            
            EXCEPTION
              WHEN OTHERS THEN
                NULL;
            END;
          END IF; -- position is not null
          -------------
          IF l_old_pos_location IS NOT NULL OR
             l_mgr_pos_loction IS NOT NULL THEN
            l_position_diff_rec.position_info := 'Old Position - ' ||
                                                 l_position_name || chr(10) ||
                                                 'Old Position locations - ' ||
                                                 l_old_pos_location ||
                                                 chr(10) ||
                                                 'Manager Position- ' ||
                                                 xxhr_util_pkg.get_position_name(l_position_diff_rec.supervisor_id) ||
                                                 chr(10) ||
                                                 'Mgr Position Location - ' ||
                                                 l_mgr_pos_loction;
          END IF;
          -------------
        EXCEPTION
          WHEN OTHERS THEN
            l_position_diff_rec.log_msg := 'New Person';
            IF l_mgr_pos_loction IS NOT NULL THEN
              l_position_diff_rec.position_info := 'New Person - ' ||
                                                   chr(10) ||
                                                   'Manager Position Location - ' ||
                                                   l_mgr_pos_loction;
            END IF;
        END;
      
        insert_position_diff(p_position_diff_rec => l_position_diff_rec,
                             p_batch_id          => p_batch_id, -- i n
                             p_err_code          => l_err_code, -- o n
                             p_err_desc          => l_err_desc); -- o v
      
        IF l_err_code > 0 THEN
          fnd_file.put_line(fnd_file.log,
                            'Failed to insert diff row : ' ||
                            get_diff_pop_r.person_id);
          dbms_output.put_line('F Person id - ' ||
                               get_diff_pop_r.person_id);
        ELSE
          dbms_output.put_line('S person id - ' ||
                               get_diff_pop_r.person_id);
        END IF;
      EXCEPTION
        WHEN OTHERS THEN
          fnd_file.put_line(fnd_file.log,
                            'Did not found details at tbl for person_id: ' ||
                            get_diff_pop_r.person_id || ' Batch_id: ' ||
                            p_batch_id);
      END;
    
    END LOOP;
  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log,
                        'Procedure populate_diff_position - Failed - ' ||
                        substr(SQLERRM, 1, 240));
      p_err_code := 1;
      p_err_desc := 'Procedure populate_diff_position - Failed - ' ||
                    substr(SQLERRM, 1, 240);
  END populate_diff_position;

  --------------------------------------------------------------------
  --  name:            update_diff_position_int
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   16/02/2012
  --------------------------------------------------------------------
  --  purpose :        CUST482 - Employee Position Changed - notify Oracle_Operations - Alert
  --
  --                   update XXHR_EMP_CHANGE_POSITION_INT table
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  16/02/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE update_diff_position_int(errbuf           OUT VARCHAR2,
                                     retcode          OUT NUMBER,
                                     p_to_send_mail   IN VARCHAR2, -- P
                                     p_from_send_mail IN VARCHAR2) IS -- N
    --PRAGMA AUTONOMOUS_TRANSACTION;
  BEGIN
    retcode := 0;
    errbuf  := NULL;
  
    UPDATE xxhr_emp_change_position_int diff
       SET diff.send_mail = p_to_send_mail, diff.last_update_date = SYSDATE
     WHERE diff.send_mail = p_from_send_mail;
  
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log,
                        'Procedure update_diff_position_int - Failed - ' ||
                        substr(SQLERRM, 1, 240));
      ROLLBACK;
      retcode := 1;
      errbuf  := 'Procedure update_diff_position_int - Failed - ' ||
                 substr(SQLERRM, 1, 240);
    
  END update_diff_position_int;

  --------------------------------------------------------------------
  --  name:            send_mail_position
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   16/02/2012
  --------------------------------------------------------------------
  --  purpose :        CUST482 - Employee Position Changed - notify Oracle_Operations - Alert
  --
  --                   send mail oo employees that changed positions to oracle_operations
  --                   they need to change in position heirarchy
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  16/02/2012  Dalit A. Raviv    initial build
  --  1.1  28/02/2012  Dalit A. Raviv    change select that check if there are rows to send mail.
  --  1.2  19.11.2012  yuval tal         change mail to profile XXHR_POSITION_MAIL for sox alert , add call for operation position mail
  --------------------------------------------------------------------
  PROCEDURE send_mail_position(errbuf OUT VARCHAR2, retcode OUT NUMBER) IS
  
    l_err_code NUMBER;
    l_err_desc VARCHAR2(500);
  
    l_to_user_name VARCHAR2(150) := NULL;
    l_cc           VARCHAR2(150) := NULL;
    l_bcc          VARCHAR2(150) := NULL;
    l_subject      VARCHAR2(360) := NULL;
    l_att1_proc    VARCHAR2(150) := NULL;
    l_att2_proc    VARCHAR2(150) := NULL;
    l_att3_proc    VARCHAR2(150) := NULL;
    l_count        NUMBER := 0;
  
  BEGIN
  
    l_err_code := 0;
    l_err_desc := NULL;
    /*
    select count(1)
    into   l_count
    from   xxhr_emp_change_position_int diff
    where  diff.send_mail               = 'P';
    */
    -- 1.1 Dalit A. Raviv 28/02/2012
  
    ------------------------
    -- send SOX Alert
    -------------------------
    SELECT COUNT(1)
      INTO l_count
      FROM xxhr_emp_change_position_int pos_int, per_all_assignments_f paaf
     WHERE 1 = 1
       AND pos_int.person_id = paaf.person_id
       AND trunc(SYSDATE) BETWEEN paaf.effective_start_date AND
           paaf.effective_end_date
       AND pos_int.send_mail = 'P';
    --   AND xxhr_util_pkg.get_organization_by_hierarchy(paaf.organization_id,
    --       'DIV',
    --       'NAME') =
    --   'Operation Division IL';
  
    IF l_count > 0 THEN
      -- 2) send mail
      -- to will be Helpdesk@objet.com helpdesc do not have user so the WF will
      -- send the mail to user dalit.raviv (HR implementer)
    
      l_to_user_name := fnd_profile.value('XXHR_POSITION_MAIL');
      IF nvl(fnd_profile.value('XXHR_ENABLE_BCC_POS_MAIL'), 'N') = 'Y' THEN
        l_cc := fnd_profile.value('XXHR_ELEMENT_SEND_MAIL_BCC'); -- Dalit.Raviv@objet.com
      END IF;
      l_bcc := NULL;
      fnd_message.set_name('XXOBJT', 'XXHR_POSITION_CHANGE_MAIL_SUBJ');
      l_subject  := fnd_message.get;
      l_err_code := 0;
      l_err_desc := NULL;
    
      xxobjt_wf_mail.send_mail_body_proc(p_to_role     => l_to_user_name, -- i v
                                         p_cc_mail     => l_cc, -- i v
                                         p_bcc_mail    => l_bcc, -- i v
                                         p_subject     => l_subject, -- i v
                                         p_body_proc   => 'XXHR_WF_SEND_MAIL_PKG.prepare_position_changed_body/P', -- i v
                                         p_att1_proc   => l_att1_proc, -- i v
                                         p_att2_proc   => l_att2_proc, -- i v
                                         p_att3_proc   => l_att3_proc, -- i v
                                         p_err_code    => l_err_code, -- o n
                                         p_err_message => l_err_desc); -- o v
    
      retcode := l_err_code;
      errbuf  := l_err_desc;
    
    ELSE
      fnd_file.put_line(fnd_file.log, 'No rows found ');
      dbms_output.put_line('No rows found ');
    END IF; -- l_count
  
    ------------------------------------
    ---- Send oracle operation alert
    -----------------------------------
    SELECT COUNT(1)
      INTO l_count
      FROM xxhr_emp_change_position_int pos_int, per_all_assignments_f paaf
     WHERE 1 = 1
       AND pos_int.person_id = paaf.person_id
       AND trunc(SYSDATE) BETWEEN paaf.effective_start_date AND
           paaf.effective_end_date
       AND pos_int.send_mail = 'P'
       AND pos_int.position_info IS NOT NULL;
  
    IF l_count > 0 THEN
    
      l_to_user_name := fnd_profile.value('XX_ORACLE_OPERATION_ADMIN_USER');
      IF nvl(fnd_profile.value('XXHR_ENABLE_BCC_POS_MAIL'), 'N') = 'Y' THEN
        l_cc := fnd_profile.value('XXHR_ELEMENT_SEND_MAIL_BCC'); -- Dalit.Raviv@objet.com
      END IF;
      l_bcc := NULL;
      fnd_message.set_name('XXOBJT', 'XXHR_POSITION_CHANGE_MAIL_SUBJ');
      l_subject  := fnd_message.get || ' Operation';
      l_err_code := 0;
      l_err_desc := NULL;
    
      xxobjt_wf_mail.send_mail_body_proc(p_to_role     => l_to_user_name, -- i v
                                         p_cc_mail     => l_cc, -- i v
                                         p_bcc_mail    => l_bcc, -- i v
                                         p_subject     => l_subject, -- i v
                                         p_body_proc   => 'XXHR_WF_SEND_MAIL_PKG.prepare_position_chg_opr_body/P', -- i v
                                         p_att1_proc   => l_att1_proc, -- i v
                                         p_att2_proc   => l_att2_proc, -- i v
                                         p_att3_proc   => l_att3_proc, -- i v
                                         p_err_code    => l_err_code, -- o n
                                         p_err_message => l_err_desc); -- o v
    
      retcode := l_err_code;
      errbuf  := l_err_desc;
    
    ELSE
      fnd_file.put_line(fnd_file.log, 'Operation Alert:  No rows found ');
      dbms_output.put_line('Operation Alert: No rows found ');
    END IF; -- l_count
  
  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log,
                        'Procedure position_send_mail - Failed - ' ||
                        substr(SQLERRM, 1, 240));
      retcode := 1;
      errbuf  := 'Procedure position_send_mail - Failed - ' ||
                 substr(SQLERRM, 1, 240);
    
      xxobjt_wf_mail.send_mail_text(p_to_role => fnd_profile.value('XX_ORACLE_OPERATION_ADMIN_USER'),
                                    p_subject => 'Failure: xxhr_oa2ad_pkg.send_mail_position',
                                    
                                    p_body_text   => 'Error : ' || chr(13) ||
                                                     errbuf || chr(13) ||
                                                     l_err_desc || chr(13) ||
                                                     chr(13) ||
                                                     'Oracle Admin',
                                    p_err_code    => l_err_code,
                                    p_err_message => l_err_desc);
    
  END send_mail_position;

  --------------------------------------------------------------------
  --  name:            main
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   10/10/2011 1:45:30 PM
  --------------------------------------------------------------------
  --  purpose :        CUST460 - Active directory interface
  --
  --                   Procedure will call from concurrent program and will run once a day.
  --                   1) check that there are rows at table - handle first time run
  --                   2) get max batch id to get last population to compare too
  --                   3) populate interface with today all Objet persons data
  --                   4) populate diff interface table
  --                   5) send mail to IT (HELPDESK)
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  10/10/2011  Dalit A. Raviv    initial build
  --  1.1  14/02/2012  Dalit A. Raviv    add handle of changes in position that have
  --                                     separate interface and mail system.
  --                                     add call to update_diff_position_int P to S
  --                                     add call to procedure populate_diff_position
  --------------------------------------------------------------------
  PROCEDURE main(errbuf OUT VARCHAR2, retcode OUT NUMBER) IS
    l_batch_id NUMBER;
    l_err_code NUMBER := 0;
    l_err_desc VARCHAR2(500) := NULL;
    l_count    NUMBER := 0;
  BEGIN
    errbuf  := NULL;
    retcode := 0;
  
    -- 1) update process_mode
    -- 3) mark all PREMAIL rows to SENDMAIL
    update_diff_person_interface(errbuf              => l_err_desc, -- o v
                                 retcode             => l_err_code, -- o n
                                 p_to_process_mode   => 'SENDMAIL', -- i v
                                 p_from_process_mode => 'PREMAIL', -- i v
                                 p_log_message       => NULL); -- o v
  
    delete_person_interface(errbuf  => l_err_desc, -- o v
                            retcode => l_err_code); -- o n
  
    delete_diff_person_interface(errbuf  => l_err_desc, -- o v
                                 retcode => l_err_code); -- o n
  
    -- 1.1 14/02/2012 Dalit A. Raviv
    update_diff_position_int(errbuf           => l_err_desc, -- o v
                             retcode          => l_err_code, -- o n
                             p_to_send_mail   => 'S', -- i v S = Send mail
                             p_from_send_mail => 'P'); -- i v P = In Process
  
    -- 1) check that there are rows at table - handle first time run
    -- 2) get max batch id to get last population to compare too
    --    if for any reason one day theprogram did not run we will steel be able to
    --    run this program and compare older population to today population.
    SELECT COUNT(1), nvl(MAX(batch_id), 0)
      INTO l_count, g_max_batch_id
      FROM xxhr_persons_interface;
  
    -- 3) populate interface with today all Objet persons data
    --    today - yesterday will give all persons that had changes.
    populate_interface(p_batch_id => l_batch_id, -- o n
                       p_err_code => l_err_code, -- o n
                       p_err_desc => l_err_desc); -- o v
    -- handle first run
    IF l_count > 0 THEN
      -- 4) find the diff between today and yesterday
      --    mark all rows with NEW process_mode
      --    mark each row if status is NEW or UPDATE TERMINATE
      populate_diff_interface(p_batch_id => l_batch_id, -- i n
                              p_err_code => l_err_code, -- o n
                              p_err_desc => l_err_desc); -- o v
    
      IF nvl(l_err_code, 0) = 0 THEN
        errbuf  := 'SUCCESS';
        retcode := 0;
      END IF;
      update_missing_date(p_batch_id => l_batch_id, -- i n
                          p_err_code => l_err_code, -- o n
                          p_err_desc => l_err_desc); -- o v
      IF nvl(l_err_code, 0) = 0 THEN
        errbuf  := 'SUCCESS';
        retcode := 0;
      END IF;
      populate_diff_position(p_batch_id => l_batch_id, -- i n
                             p_err_code => l_err_code, -- o n
                             p_err_desc => l_err_desc); -- o v
      --
      -- 5) send mail  will be at stand alone concurrent
      --    from diff interface find population to send mail to IT group (Helpdesk)
      /*
      send_mail(errbuf     => l_err_desc, -- o v
                retcode    => l_err_code);-- i n
      */
      IF nvl(l_err_code, 0) = 0 THEN
        errbuf  := 'SUCCESS';
        retcode := 0;
      ELSE
        errbuf  := l_err_desc;
        retcode := 1;
      END IF;
    
    ELSE
      errbuf  := 'First run';
      retcode := 0;
    END IF; -- l_count
  
  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log,
                        'Procedure main - Failed - ' ||
                        substr(SQLERRM, 1, 240));
      errbuf  := 'Procedure main - Failed - ' || substr(SQLERRM, 1, 240);
      retcode := 1;
  END main;

  --------------------------------------------------------------------
  --  name:            get_concate_position_Hierarchy
  --  create by:       yuval tal
  --  Revision:        1.0
  --  creation date:   19.11.2012
  --------------------------------------------------------------------
  --  purpose :        CUST482 /CR418 - Employee Position Changed - get position  location in Hierarchys
  --
  --                   
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  19.11.2012  yuval tal          initial build

  --------------------------------------------------------------------

  FUNCTION get_concate_position_hierarchy(p_position_id NUMBER)
    RETURN VARCHAR2 IS
    CURSOR c IS
      SELECT -- position_id,
       rtrim(xmlagg(xmlelement(e, NAME || ',')).extract('//text()'), ',') NAME
        FROM (SELECT h.name, pos.position_id
                FROM per_pos_structure_elements   pse,
                     hr_all_positions_f           pos,
                     hr_all_positions_f_tl        pft,
                     per_position_structures_v    h,
                     per_pos_structure_versions_v v
               WHERE h.position_structure_id = v.position_structure_id
                 AND v.pos_structure_version_id =
                     pse.pos_structure_version_id
                 AND pse.subordinate_position_id(+) = pos.position_id
                 AND pos.effective_end_date =
                     to_date('31124712', 'DDMMYYYY')
                 AND v.pos_structure_version_id = h.position_structure_id
                 AND trunc(SYSDATE) BETWEEN v.date_from AND
                     nvl(v.date_to, SYSDATE + 1)
                 AND pos.position_id = pft.position_id
                 AND pft.language = userenv('LANG')
                 AND pos.business_group_id = 0
              UNION
              SELECT h.name, pse.parent_position_id
                FROM per_pos_structure_elements   pse,
                     hr_all_positions_f           pos,
                     hr_all_positions_f_tl        pft,
                     per_position_structures_v    h,
                     per_pos_structure_versions_v v
               WHERE h.position_structure_id = v.position_structure_id
                 AND v.pos_structure_version_id =
                     pse.pos_structure_version_id
                 AND pse.subordinate_position_id(+) = pos.position_id
                 AND pos.effective_end_date =
                     to_date('31124712', 'DDMMYYYY')
                 AND v.pos_structure_version_id = h.position_structure_id
                 AND trunc(SYSDATE) BETWEEN v.date_from AND
                     nvl(v.date_to, SYSDATE + 1)
                 AND pse.parent_position_id = pft.position_id
                 AND pft.language = userenv('LANG')
                 AND pos.business_group_id = 0)
       WHERE position_id = p_position_id
       GROUP BY position_id;
    l_loc VARCHAR2(500);
  BEGIN
    OPEN c;
    FETCH c
      INTO l_loc;
    CLOSE c;
    RETURN l_loc;
  END;

END xxhr_oa2ad_pkg;
/
