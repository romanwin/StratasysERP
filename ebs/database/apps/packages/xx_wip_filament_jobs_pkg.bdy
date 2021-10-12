create or replace package body xx_wip_filament_jobs_pkg AS
  --------------------------------------------------------------------
  --  name:            XX_WIP_FILAMENT_JOBS_PKG
  --  create by:       Rajeeb Das
  --  Revision:        1.0
  --  creation date:   17-SEP-2013
  --------------------------------------------------------------------
  --  purpose :        This Procedure to extracts Job details for
  --                   Filament Jobs for the Strat System.
  --  Parameters :     Standard Concurrent Program Parameters.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  17-SEP-2013 RDAS              Initial Version.
  --  1.1  15-APR-2014 Sandeep Akula     Added "WHEN MATCHED THEN" to the MERGE Statement  -- CHG0031835
  --                                     Added WHO columns to the table xx_wip_flmt_jobs -- CHG0031835
  --                                     Added WHO Columns to the INSERT and UPDATE in MERGE statement -- CHG0031835
  --                                     Renamed Columns from creation_date to job_creation_date -- CHG0031835
  --  1.2  23-MAR-2015 Gubendran K       CHG0034273 - Added Attribute15(remarks dff)in the Merge and delete script condition
  --  1.3  24-AUG-2015 Dalit A. Raviv    CHG0035810 - Add "Schedule group" to MCS interface table
  --  1.4  15-DEC-2016 Dovik/Yuval       CHG0039821 - JobLot partial completion
  --  1.5  18-Dec-2018 Lingaraj          CHG0044616 - manufacturing readiness
  --                                     FDM Auto Job Completion by interface
  --  1.6  20-Feb-2019 Lingaraj          CHG0045076-Job Completion Interface- Error with no reason- validation tuning
  --------------------------------------------------------------------

  --------------------------------------------------------------------------
  -- Purpose:  log messages
  --
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --     1.0  11.10.18  LINGARAJ        CHG0043027 - CTASK0038143
  --                                    log messalges
  ---------------------------------------------------------------------------
  procedure message(p_msg         in varchar2,
                    p_destination in number default fnd_file.log) is
  BEGIN
    IF fnd_global.conc_request_id = -1 THEN
      dbms_output.put_line(p_msg);
    ELSE
      fnd_file.put_line(p_destination, p_msg);
    END IF;
  END message;
  --------------------------------------------------------------------------
  -- Purpose:  This Procedure to extracts Job details for
  --           Filament Jobs for the Strat System.
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --  1.0  17-SEP-2013  RDAS            Initial Version.
  --  1.1  04-MAR-2019 Uri Landesberg   CHG0045170 - Added ALTERNATE_BOM in the Merge statement 
  ---------------------------------------------------------------------------
  PROCEDURE xx_wip_flmt_extr_jobs_extract(errbuf  OUT VARCHAR2,
                                          retcode OUT NUMBER) AS

  BEGIN
    errbuf  := null;
    retcode := 0;

    MERGE INTO xxobjt.xx_wip_flmt_jobs fljob
    USING (SELECT ent.wip_entity_id,
                  ent.wip_entity_name,
                  itm.segment1                 item_number,
                  flu.meaning                  firm_planned_flag,
                  job.start_quantity,
                  job.scheduled_start_date,
                  job.scheduled_completion_date,
                  job.date_released,
                  slu.meaning                  status,
                  job.creation_date,
                  org.organization_code        org_code,
                  job.CLASS_CODE               class_code, -- CHG0035810 24-AUG-2015 Dalit A. Raviv
                  job.alternate_bom_designator alternate_bom  -- CHG0045170  
             FROM wip_discrete_jobs            job,
                  mtl_system_items             itm,
                  mfg_lookups                  lu,
                  mfg_lookups                  slu,
                  mfg_lookups                  flu,
                  wip_operations               wo,
                  bom_departments              bd,
                  wip_schedule_groups          sg,
                  wip_entities                 ent,
                  org_organization_definitions org
            WHERE job.wip_entity_id            = ent.wip_entity_id
              AND job.schedule_group_id        = sg.schedule_group_id
              AND sg.schedule_group_name       LIKE '%Extrusion%'
              AND itm.inventory_item_id        = ent.primary_item_id
              AND itm.organization_id          = job.organization_id
              AND job.organization_id          = org.organization_id
              AND lu.lookup_code               = job.job_type
              AND lu.lookup_type               = 'WIP_DISCRETE_JOB'
              AND (lu.meaning = 'Standard' or (lu.meaning = 'Non-standard' and job.CLASS_CODE = 'Political')) ---- CHG 35810
              AND job.status_type              = slu.lookup_code
              AND slu.lookup_type              = 'WIP_JOB_STATUS'
              AND slu.meaning                  IN ('Released', 'Unreleased')
              AND job.firm_planned_flag        = flu.lookup_code
              AND flu.lookup_type              = 'SYS_YES_NO'
              AND nvl(job.quantity_completed, 0) < job.start_quantity  --CHG0039821
              AND job.start_quantity           >= 1
              AND ent.wip_entity_id            = wo.wip_entity_id
              AND wo.organization_id           = job.organization_id
              AND bd.department_id             = wo.department_id
              AND EXISTS                       (SELECT 'X'
                                                FROM   wip_operations wo1, bom_departments d1
                                                WHERE  ent.wip_entity_id   = wo1.wip_entity_id
                                                AND    wo1.organization_id = job.organization_id
                                                AND    d1.department_id    = wo1.department_id
                                                AND    d1.organization_id  = job.organization_id
                                                AND    d1.department_code  = 'F-EXTR'
                                                AND    rownum              = 1)
              AND wo.operation_seq_num         = (SELECT MIN(wi.operation_seq_num)
                                                  FROM   wip_operations     wi
                                                  WHERE  wi.wip_entity_id   = ent.wip_entity_id
                                                  AND    wi.organization_id = job.organization_id)
              AND (wo.quantity_completed <job.start_quantity OR upper(job.attribute15) = 'REPRINT')) jobs  --CHG0039821  -- CHG0034273-Added attribute15 condition
    ON (fljob.wip_entity_id = jobs.wip_entity_id)
    WHEN NOT MATCHED THEN
      INSERT
        (wip_entity_id,
         wip_entity_name,
         item_number,
         firm_planned_flag,
         start_quantity,
         scheduled_start_date,
         scheduled_completion_date,
         date_released,
         status,
         job_creation_date,  -- CHG0031835 Sandeep Akula Renamed to job_creation_date from creation_date
         org_code,
         creation_date,      -- CHG0031835 Sandeep Akula  Added Column
         created_by,         -- CHG0031835 Sandeep Akula  Added Column
         last_update_date,   -- CHG0031835 Sandeep Akula  Added Column
         last_updated_by,    -- CHG0031835 Sandeep Akula  Added Column
         class_code   ,       -- CHG0035810 24-AUG-2015 Dalit A. Raviv
         alternate_bom        --  CHG0045170 
         )
      VALUES
        (jobs.wip_entity_id,
         jobs.wip_entity_name,
         jobs.item_number,
         jobs.firm_planned_flag,
         jobs.start_quantity,
         jobs.scheduled_start_date,
         jobs.scheduled_completion_date,
         jobs.date_released,
         jobs.status,
         jobs.creation_date,
         jobs.org_code,
         SYSDATE,            -- CHG0031835 Sandeep Akula  Added Column
         FND_GLOBAL.USER_ID, -- CHG0031835 Sandeep Akula  Added Column
         SYSDATE,            -- CHG0031835 Sandeep Akula  Added Column
         FND_GLOBAL.USER_ID, -- CHG0031835 Sandeep Akula  Added Column
         jobs.class_code,    -- CHG0035810 24-AUG-2015 Dalit A. Raviv
         jobs.alternate_bom)   --CHG0045170  
    WHEN MATCHED THEN        -- CHG0031835 Sandeep Akula - Added to Update Jobs with the current data
      UPDATE SET wip_entity_name           = jobs.wip_entity_name,
                 item_number               = jobs.item_number,
                 firm_planned_flag         = jobs.firm_planned_flag,
                 start_quantity            = jobs.start_quantity,
                 scheduled_start_date      = jobs.scheduled_start_date,
                 scheduled_completion_date = jobs.scheduled_completion_date,
                 date_released             = jobs.date_released,
                 status                    = jobs.status,
                 job_creation_date         = jobs.creation_date,
                 org_code                  = jobs.org_code,
                 last_update_date          = SYSDATE,
                 last_updated_by           = FND_GLOBAL.USER_ID,
                 CLASS_CODE                = jobs.class_code, -- CHG0035810 24-AUG-2015 Dalit A. Raviv
                 alternate_bom             = jobs.alternate_bom; --CHG0045170

    COMMIT;

    DELETE FROM xxobjt.xx_wip_flmt_jobs jobs
     WHERE NOT EXISTS
     (SELECT 'X'
      FROM    wip_discrete_jobs            job,
              mtl_system_items             itm,
              mfg_lookups                  lu,
              mfg_lookups                  slu,
              mfg_lookups                  flu,
              wip_operations               wo,
              bom_departments              bd,
              wip_schedule_groups          sg,
              wip_entities                 ent,
              org_organization_definitions org
      WHERE   job.wip_entity_id            = jobs.wip_entity_id
      AND     job.wip_entity_id            = ent.wip_entity_id
      AND     job.schedule_group_id        = sg.schedule_group_id
      AND     sg.schedule_group_name       LIKE '%Extrusion%'
      AND     itm.inventory_item_id        = ent.primary_item_id
      AND     itm.organization_id          = job.organization_id
      AND     job.organization_id          = org.organization_id
      AND     lu.lookup_code               = job.job_type
      AND     lu.lookup_type               = 'WIP_DISCRETE_JOB'
      AND     (lu.meaning                   = 'Standard'
           or (lu.meaning = 'Non-standard' and job.CLASS_CODE = 'Political')) -- CHG0035810 24-AUG-2015 Dalit A. Raviv
      AND     job.status_type              = slu.lookup_code
      AND     slu.lookup_type              = 'WIP_JOB_STATUS'
      AND     slu.meaning                  IN ('Released', 'Unreleased')
      AND     job.firm_planned_flag        = flu.lookup_code
      AND     flu.lookup_type              = 'SYS_YES_NO'
      AND     nvl(job.quantity_completed, 0) < job.start_quantity --CHG0039821
      AND     job.start_quantity           >= 1
      AND     ent.wip_entity_id            = wo.wip_entity_id
      AND     wo.organization_id           = job.organization_id
      AND     bd.department_id             = wo.department_id
      AND     EXISTS                       (SELECT 'X'
                                            FROM   wip_operations wo1, bom_departments d1
                                            WHERE  ent.wip_entity_id   = wo1.wip_entity_id
                                            AND    wo1.organization_id = job.organization_id
                                            AND    d1.department_id    = wo1.department_id
                                            AND    d1.organization_id  = job.organization_id
                                            AND    d1.department_code  = 'F-EXTR'
                                            AND    rownum              = 1)
      AND wo.operation_seq_num             = (SELECT MIN(wi.operation_seq_num)
                                              FROM   wip_operations     wi
                                              WHERE  wi.wip_entity_id   = ent.wip_entity_id
                                              AND    wi.organization_id = job.organization_id)
      AND (wo.quantity_completed<job.start_quantity or upper(job.attribute15) = 'REPRINT')); --CHG0039821  -- CHG0034273-Added attribute15 condition

    COMMIT;

  exception
    when others then
      errbuf  := 'GEN ERR - xx_wip_flmt_extr_jobs_extract - '||substr(sqlerrm,0,240);
      retcode := 1;
  END xx_wip_flmt_extr_jobs_extract;
  --------------------------------------------------------------------------
  -- Purpose:  wait_for_request_compl
  --           wait for the concurrent request completion
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --     1.0  11.10.18  LINGARAJ        CHG0043027 - Intial build
  ---------------------------------------------------------------------------
  PROCEDURE wait_for_request_compl(p_request_id number,
                                   p_conc_name  varchar2,
                                   x_request_status out varchar2,
                                   x_err_msg        out varchar2
                                  )
  is
    l_phase          VARCHAR2(100);
    l_status         VARCHAR2(100);
    l_dev_phase      VARCHAR2(100);
    l_dev_status     VARCHAR2(100);
    l_message        VARCHAR2(1000);
    l_request_status BOOLEAN;
  begin
    --Waiting for the Program to Complete
    If nvl(p_request_id,0) > 0 Then
      l_request_status := fnd_concurrent.wait_for_request(request_id => p_request_id,
                                                          interval   => 5,
                                                          max_wait   => 600,
                                                          phase      => l_phase,
                                                          status     => l_status,
                                                          dev_phase  => l_dev_phase,
                                                          dev_status => l_dev_status,
                                                          message    => l_message);
      COMMIT;

      If UPPER(l_phase) = 'COMPLETED' and UPPER(l_status) = 'NORMAL' Then
        message(p_conc_name ||
                '- Concurrent Program Completed Successfully');
        x_request_status := UPPER(l_status);
      Else
        x_err_msg        := x_err_msg || l_message;
        x_request_status := UPPER(l_status);
        message(p_conc_name ||
                '- Concurrent Program Completed with Error.' || CHR(13) ||
                'Status :' || UPPER(l_status) || CHR(13) || 'Phase  :' ||
                l_phase || CHR(13) || 'Message:' || l_message);
      End If;
    End If;
  end wait_for_request_compl;
  --------------------------------------------------------------------
  --  name:            xx_wip_flmt_jobs_cmpl
  --  create by:       Lingaraj Sarangi
  --  Revision:        1.0
  --  creation date:   18-Dec-2018
  --------------------------------------------------------------------
  --  purpose :
  --
  --  Parameters :     Standard Concurrent Program Parameters.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  18-Dec-2018 Lingaraj          CHG0044616 - manufacturing readiness - FDM Auto Job Completion by interface
  --------------------------------------------------------------------
  PROCEDURE submit_concurrent_request(p_group_id       IN number DEFAULT NULL,
                                      p_program_name   IN VARCHAR2,
                                      x_request_id     OUT number,
                                      x_request_status OUT VARCHAR2,
                                      x_err_msg        OUT varchar2) is
    l_status         VARCHAR2(100);
    l_message        VARCHAR2(1000);
    l_request_status BOOLEAN;
    l_conc_name      VARCHAR2(50);
    l_chk            VARCHAR2(1) := 'N';
    l_err_msg        VARCHAR2(500);
  Begin

    l_conc_name := (Case p_program_name
                     When 'WICMLP' Then
                      'WIP Mass Load'
                     When 'WICTMS' Then
                      'WIP Move Transaction Manager'
                     Else
                      ''
                   end);

    If p_program_name = 'WICMLP' and p_group_id is not null Then
      x_request_id := fnd_request.submit_request(application => 'WIP',
                                                 program     => p_program_name,
                                                 argument1   => p_group_id --[Group ID]Used to batch interface records
                                                 );

    ElsIf p_program_name = 'WICTMS' Then
      x_request_id := fnd_request.submit_request(application => 'WIP',
                                                 program     => p_program_name);

    End If;
    message(l_conc_name || ' - Concurrent Program Submitted, Request Id: ' ||
            x_request_id);

    COMMIT;

    wait_for_request_compl(x_request_id , l_conc_name,x_request_status,l_err_msg);
    x_err_msg := x_err_msg || l_err_msg;

    If p_program_name = 'WICTMS' Then

      message('WIP Move Transaction Manager Request Id :' ||
              x_request_id);

      For rec in ( select fcr.request_id
                   from fnd_concurrent_requests fcr,
                           fnd_concurrent_programs fcp,
                           fnd_application         fa
                   where fcr.parent_request_id = x_request_id
                   and fcp.concurrent_program_id = fcr.concurrent_program_id
                   and fa.application_id         = fcp.application_id
                   and fcp.concurrent_program_name = 'WICTWS'  --wip move transaction worker
                   and fa.application_short_name  = 'WIP'
                   ) --possiable multiple Child Requests
       Loop
          l_chk := 'Y';
          l_conc_name := 'Wip Move Transaction Worker';
          message('wip move transaction worker Request Id :' || x_request_id);

          wait_for_request_compl(rec.request_id , l_conc_name,x_request_status,l_err_msg);
          x_err_msg := x_err_msg || l_err_msg;
       End Loop;

       If l_chk = 'N' Then
          l_err_msg := 'No -> Wip Move Transaction Worker concurrent Program,'||
                 ' fired for Parent concurrent Program WIP Move Transaction Manager.';
          x_request_status := 'ERROR';
          x_err_msg := x_err_msg || l_err_msg;
          message(l_err_msg);
       End if;

    End if;

  Exception
    When others Then
      x_err_msg        := sqlerrm;
      x_request_status := 'ERROR';
      Message('Unexpected Error During ' || l_conc_name ||
              '- Concurrent Program Submition. Error :' || x_err_msg);
  End submit_concurrent_request;
  --------------------------------------------------------------------
  --  name:            validate_records
  --  create by:       Lingaraj Sarangi
  --  Revision:        1.0
  --  creation date:   18-Dec-2018
  --------------------------------------------------------------------
  --  purpose :        Validate Records Before Processing The Records
  --
  --  Parameters :     Standard Concurrent Program Parameters.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  18-Dec-2018 Lingaraj          CHG0044616 - manufacturing readiness
  --------------------------------------------------------------------
  Procedure validate_records is
  begin
    Null;
  End validate_records;
   --------------------------------------------------------------------
  --  name:            get_table_record_count
  --  create by:       Lingaraj Sarangi
  --  Revision:        1.0
  --  creation date:   18-Dec-2018
  --------------------------------------------------------------------
  --  purpose :        get_table_record_count
  --
  --  Parameters :
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  18-Dec-2018 Lingaraj          CHG0044616 - manufacturing readiness
  --------------------------------------------------------------------
  Function get_table_record_count(p_group_id number  DEFAULT NULL)
  return number
  is
  l_rec_count  NUMBER := 0;
  begin
   IF p_group_id is null Then
      select count(1)
      into l_rec_count
      from xxobjt.xx_wip_flmt_jobs_cmpl
     where status = 'New';
   Else
     select count(1)
      into l_rec_count
      from xxobjt.xx_wip_flmt_jobs_cmpl
     where status = 'New'
     and nvl(group_id,-1) = p_group_id;
   End If;


   message('No of Records in the Table in New Status :'||l_rec_count);
   Return l_rec_count;

  End get_table_record_count;
  --------------------------------------------------------------------
  --  name:            xx_wip_flmt_jobs_cmpl
  --  create by:       Lingaraj Sarangi
  --  Revision:        1.0
  --  creation date:   18-Dec-2018
  --------------------------------------------------------------------
  --  purpose :
  --
  --  Parameters :     Standard Concurrent Program Parameters.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  18-Dec-2018 Lingaraj          CHG0044616 - manufacturing readiness - FDM Auto Job Completion by interface
  --  1.1  30/12/2019  Roman W.          CHG0044616 - code corection to avoid :
  --                                          single-row subquery retun more when one row.
  --  1.2  22/01/2019  Lingaraj          CHG0044616 -CTASK0040299 - manufacturing readiness - FDM Auto Job Completion by interface
  --  1.3  20-Feb-2019 Lingaraj          CHG0045076-Job Completion Interface- Error with no reason- validation tuning
  --------------------------------------------------------------------
  PROCEDURE xx_wip_flmt_jobs_cmpl(errbuf OUT VARCHAR2, retcode OUT NUMBER) is
    cursor job_c(p_group_id NUMBER) is
      select interface_id,
             organization_code,
             job_name,
             lot_number,
             process_phase,
             process_status
        from wip_job_schedule_interface
       where group_id = p_group_id
         and process_status != 4;

    cursor lot_update_c(p_group_id number) is
      select xx.rowid row_id,
             item_id,
             wip_entity_name,
             completed_quantity,
             lot_number,
             org_code,
             cage_number,
             mp.organization_id
        from xxobjt.xx_wip_flmt_jobs_cmpl xx, mtl_parameters mp
       where status = 'Inprocess'
         and process_step = 40 -- WIP Move Transaction Manager Program Completed
         and group_id = p_group_id
         and xx.org_code = mp.organization_code;

    l_group_id        number := null;
    l_old_group_id    number := null;
    l_request_id      NUMBER;
    l_request_status  VARCHAR2(100);
    l_err_msg         VARCHAR2(1000);
    l_master_inv_org  NUMBER := xxinv_utils_pkg.get_master_organization_id;
    l_expiration_date DATE;
    l_rec_count       NUMBER := 0;
    l_loop_cond       VARCHAR2(1) := 'Y';
    l_transaction_id  NUMBER;  --CHG0045076
    l_cnt             NUMBER;  --CHG0045076
    l_int_msg         VARCHAR2(3000);--CHG0045076
  begin
    message('Begin Package xx_wip_filament_jobs_pkg.xx_wip_flmt_jobs_cmpl');
    retcode := 0;

    validate_records();

 While l_loop_cond = 'Y'
 Loop

    l_request_id      := NULL;
    l_request_status  := NULL;
    l_err_msg         := NULL;
    l_expiration_date := NULL;
    l_rec_count       := NULL;



  If get_table_record_count(l_group_id) > 0 Then

      l_old_group_id := l_group_id;
      l_group_id := wip.wip_job_schedule_interface_s.nextval;
      message( 'Old Group Id & New Group Id :'|| l_old_group_id ||' & '|| l_group_id);

      If  l_old_group_id is not null Then
        --Update All the New Records with Group ID
        update xxobjt.xx_wip_flmt_jobs_cmpl xwfjc
               Set  group_id      = l_group_id,
               last_update_date = sysdate,
               last_updated_by  = fnd_global.user_id
        where status = 'New'
        and   group_id = l_old_group_id;
      Else
         --Update All the New Records with Group ID
        update xxobjt.xx_wip_flmt_jobs_cmpl xwfjc
               Set  group_id      = l_group_id,
               last_update_date = sysdate,
               last_updated_by  = fnd_global.user_id
        where status = 'New';
      End If;


      -- Change the Record Status to InProcess
      update xxobjt.xx_wip_flmt_jobs_cmpl xwfjc
         set status        = 'Inprocess',
             process_step  = 10, -- Inserted to wip_job_schedule_interface
             group_id      = l_group_id,
             error_message = 'Step 10 : Record Inserted to Interface Table wip_job_schedule_interface.',
             item_id      =
             (select wdj.primary_item_id
                from wip_discrete_jobs_v          wdj,
                     org_organization_definitions ood -- Added by Roman W. 30/12/2018
               where 1 = 1
                 and ood.ORGANIZATION_ID = wdj.organization_id -- -- Added by Roman W. 30/12/2018
                 and wdj.wip_entity_name = xwfjc.wip_entity_name
                 and ood.organization_code = xwfjc.org_code -- Added by Roman W. 30/12/2018
              ),
              last_update_date = sysdate,
              last_updated_by  = fnd_global.user_id
       where status = 'New'
         and rowid in (Select row_id
                         from (select WIP_ENTITY_NAME,
                                      ORG_CODE,
                                      lot_number,
                                      rowid row_id,
                                      RANK() OVER(PARTITION BY WIP_ENTITY_NAME, ORG_CODE ORDER BY rownum DESC) AS row_num
                                 from xx_wip_flmt_jobs_cmpl
                                where status = 'New')
                        where row_num = 1);

      --Insert data into WIP_JOB_SCHEDULE_INTERFACE
      INSERT INTO wip_job_schedule_interface
        (organization_code,
         job_name,
         Lot_number,
         group_id,
         load_type,
         process_phase,
         process_status,
         created_by,
         creation_date, -- Sysdate
         last_updated_by, -- 1111 Scheduler
         last_update_date -- Sysdate
         )
        select org_code,
               wip_entity_name,
               lot_number,
               group_id,
               3 -- 3 Update Standard or Non-Standard Discrete Job
              ,
               2 -- process_phase 2 Validation 3 Explosion 4 Complete 5 Creation
              ,
               1 -- process_status: 1 Pending 2 Running 3 Error 4 Complete 5 Warning
              ,
               fnd_global.user_id,
               SYSDATE,
               fnd_global.user_id,
               SYSDATE
          from xxobjt.xx_wip_flmt_jobs_cmpl
         where status = 'Inprocess';

      If sql%Rowcount > 0 Then
        message(sql%Rowcount ||
                '  No. of records inserted into Interface Wip_job_schedule_interface.');

        commit;

        --Submit - WIP Mass Load  Program
        submit_concurrent_request(p_group_id       => l_group_id,
                                  p_program_name   => 'WICMLP',
                                  x_request_id     => l_request_id,
                                  x_request_status => l_request_status,
                                  x_err_msg        => l_err_msg);

        -- Update Record Stage and Status
        update xxobjt.xx_wip_flmt_jobs_cmpl
           set process_step  = 20, -- WIP Mass Load  Program Submitted
               error_message = error_message || CHR(13) ||
                               'Step 20 : WIP Mass Load  Program Submitted and Completed with Status ' ||
                               l_request_status || ', Request Id :' ||
                               l_request_id || ',Group Id :' || l_group_id ||
                               NVL2(l_err_msg,
                                    ',Error Message :' || l_err_msg,
                                    '')
              ,last_update_date = sysdate
              ,last_updated_by  = fnd_global.user_id
         where status = 'Inprocess'
           and process_step = 10
           and group_id = l_group_id;

        For job_rec in job_c(l_group_id) Loop
          Update xxobjt.xx_wip_flmt_jobs_cmpl
             set error_message = error_message || CHR(13) ||
                                 'Step 20.1 : wip_job_schedule_interface process_status for the Record is ' ||
                                 Decode(job_rec.process_status,
                                        1,
                                        'Pending',
                                        2,
                                        'Running',
                                        3,
                                        'Error',
                                        4,
                                        'Complete',
                                        5,
                                        'Warning',
                                        job_rec.process_status),
                 status        = Decode(job_rec.process_status,
                                        4,
                                        status,
                                        'Error'),
                 interface_id  = job_rec.interface_id,
                 last_update_date = sysdate,
                 last_updated_by  = fnd_global.user_id
           where status = 'Inprocess'
             and org_code = job_rec.organization_code
             and wip_entity_name = job_rec.job_name
             and lot_number = job_rec.lot_number;

        End Loop;

      End If;
    --End If;

    --WIP Move and Complete
    ---  Insert data into WIP_MOVE_TXN_INTERFACE.
    INSERT INTO WIP_MOVE_TXN_INTERFACE
      (process_phase -- 1. move validation 2. move processing 3. operation backflush setup. you should always load 1 (move validation)
      ,
       process_status -- 1. pending 2. running 3. error you should always load 1 (pending)
      ,
       organization_code -- xx_wip_flmt_jobs_cmpl table
      ,
       wip_entity_name -- xx_wip_flmt_jobs_cmpl table
      ,
       transaction_date -- sysdate
      ,
       transaction_quantity -- xx_wip_flmt_jobs_cmpl table
      ,
       transaction_uom -- select b.primary_uom_code from mtl_system_items_b b where b.organization_id=xxinv_utils_pkg.get_master_organization_id and b.inventory_item_id= (select wdj.primary_item_id from wip_discrete_jobs_v wdj where wip_entity_name=xx_wip_flmt_jobs_cmpl.wip_entity_name)
      ,
       transaction_type -- transaction_type /* 1. move 2. move completion 3. move return */ you should always load 2 (move completion)
      ,
       fm_operation_seq_num --select min(wo.operation_seq_num) from wip_operations_v wo where wo.wip_entity_id= (select we.wip_entity_id from wip_entities we where we.wip_entity_name = xx_wip_flmt_jobs_cmpl.wip_entity_name)
      ,
       fm_intraoperation_step_type --fm_intraoperation_step_type /* 1. queue,2.run 3.to move,4.reject, */ . you should always load 1 (queue)
      ,
       last_update_date,
       last_updated_by,
       creation_date,
       created_by,
       REFERENCE,
       overcompletion_transaction_qty --CHG0044616 -CTASK0040299
       )
      select 1 --process_phase,
            ,
             1 --process_status,
            ,
             org_code --organization_code
            ,
             xwfjc.wip_entity_name --wip_entity_name
            ,
             sysdate --transaction_date
            ,
             completed_quantity --transaction_quantity
            ,
             (select msib.primary_uom_code
                from mtl_system_items_b msib
               where msib.organization_id = l_master_inv_org
                 and msib.inventory_item_id = xwfjc.item_id) --transaction_uom
            ,
             2 --transaction_type
            ,
             (select min(wo.operation_seq_num)
                from WIP_OPERATIONS_V wo, wip_entities we
               where wo.wip_entity_id = we.wip_entity_id
                 and we.wip_entity_name = xwfjc.wip_entity_name) --fm_operation_seq_num
            ,
             1 --fm_intraoperation_step_type
            ,
             SYSDATE,
             fnd_global.user_id,
             SYSDATE,
             fnd_global.user_id,
             group_id,
             (Case When nvl(quantity_remaining,0) <=0 Then
                        completed_quantity
                   When nvl(quantity_remaining,0) > 0 and completed_quantity <= nvl(quantity_remaining,0) Then
                        NULL
                   When nvl(quantity_remaining,0) > 0 and completed_quantity > nvl(quantity_remaining,0) Then
                   (completed_quantity - nvl(quantity_remaining,0))
                   Else NULL
              End
              ) --CHG0044616 -CTASK0040299
        from xxobjt.xx_wip_flmt_jobs_cmpl xwfjc,
             mtl_parameters mp,
             wip_discrete_jobs_v wdjv
       where status = 'Inprocess'
         and process_step = 20
         and group_id     = l_group_id
         and mp.organization_code = xwfjc.org_code
         and wdjv.wip_entity_name = xwfjc.wip_entity_name
         and wdjv.organization_id   = mp.organization_id ;

    l_rec_count := sql%Rowcount;
    message(l_rec_count ||
            '  No. of records inserted into Interface WIP_MOVE_TXN_INTERFACE.');

    update xxobjt.xx_wip_flmt_jobs_cmpl
       set process_step  = 30, -- Data Inserted into WIP_MOVE_TXN_INTERFACE
           error_message = error_message || CHR(13) ||
                           'Step 30: Records inserted into Interface Table WIP_MOVE_TXN_INTERFACE'
           ,last_update_date = sysdate
           ,last_updated_by  = fnd_global.user_id
     where status = 'Inprocess'
       and process_step = 20
       and group_id = l_group_id;

    commit;

    If l_rec_count = 0 Then
      l_loop_cond := 'N';
      EXIT;
    End If;

    --Submit -  WIP Move Transaction Manager Program
    l_request_id     := NULL;
    l_request_status := NULL;
    l_err_msg        := NULL;
    submit_concurrent_request(p_program_name   => 'WICTMS',
                              x_request_id     => l_request_id,
                              x_request_status => l_request_status,
                              x_err_msg        => l_err_msg);
     --Begin CHG0045076
    IF UPPER(l_request_status) = 'ERROR' THEN
      -- verify the data in Interface
      FOR rec in (select id,wip_entity_name ,org_code,completed_quantity
                  from xx_wip_flmt_jobs_cmpl
                  where status = 'Inprocess'
                  and process_step = 30
                  and group_id = l_group_id)
      LOOP
          l_cnt := 0;
          l_transaction_id := NULL;
          l_int_msg := 'Step 40: WIP Move Transaction Manager Program Completed.Request Id:'
                       ||l_request_id||' . With Status :' ;
          Begin
            select TRANSACTION_ID
            into l_transaction_id
            from apps.wip_move_txn_interface wmti
            where wmti.REFERENCE =  l_group_id
            and   wmti.wip_entity_name   =   rec.wip_entity_name
            and   wmti.organization_code =   rec.org_code
            and   trunc(wmti.transaction_date)  = trunc(SYSDATE)
            and   wmti.transaction_quantity = rec.completed_quantity
            and   nvl(wmti.process_status,0)= 3;
            l_cnt := 1;
          Exception
            When no_data_found Then
              l_cnt := 0;
            when too_many_rows then
              l_cnt := 2;
          End;

          IF l_cnt = 1 THEN
           -- Get the Error Details
            Begin
              select
              l_int_msg || 'ERROR. Error Details :'|| CHR(13)||
              --('ERROR in column '||ERROR_COLUMN||',and Error Message :'||ERROR_MESSAGE)
              SUBSTR((LISTAGG(ERROR_MESSAGE, CHR(13)) WITHIN GROUP (ORDER BY TRANSACTION_ID)),1,2000)
              into l_int_msg
              from WIP_TXN_INTERFACE_ERRORS
              where TRANSACTION_ID = l_transaction_id;
            Exception
            When no_data_found Then
             l_int_msg := l_int_msg ||'. No Record found in WIP_TXN_INTERFACE_ERRORS Table';
            When Others then
             l_int_msg := l_int_msg ||'. Error When fetching data from WIP_TXN_INTERFACE_ERRORS Table.'||SQLERRM;
            End;
          ELSIF l_cnt = 2 THEN
            l_int_msg := l_int_msg || 'ERROR. When Trying to find Error in Table WIP_TXN_INTERFACE_ERRORS, found more then one Row.';
          ELSIF l_cnt = 0 THEN
            -- When No Record found (So record Processed Sucessfully)
            l_int_msg := l_int_msg || 'SUCCESS';
          END IF;

          --If the Record found in the
         update xxobjt.xx_wip_flmt_jobs_cmpl xwfjc
         set xwfjc.process_step  = 40, -- WIP Move Transaction Manager Program Completed
             xwfjc.error_message = (xwfjc.error_message || CHR(13) || l_int_msg),
             xwfjc.status        = (CASE WHEN l_cnt > 0 THEN
                                    'Error'
                                   ELSE xwfjc.status
                                   END ),
             xwfjc.last_update_date = sysdate,
             xwfjc.last_updated_by  = fnd_global.user_id
        where xwfjc.status       = 'Inprocess'
         and xwfjc.process_step = 30
         and xwfjc.group_id     = l_group_id
         and xwfjc.id           = rec.id;

      END LOOP;
    ELSE
        update xxobjt.xx_wip_flmt_jobs_cmpl
           set process_step  = 40, -- WIP Move Transaction Manager Program Completed
               error_message = error_message || CHR(13) ||
                               ('Step 40: WIP Move Transaction Manager Program Completed with Status :' ||
                               l_request_status || ', Request ID :' ||
                               l_request_id),
               /*status        = Decode(UPPER(l_request_status),
                                      'ERROR',
                                      'Error',
                                      status),*/ --CHG0045076 Commented
               last_update_date = sysdate,
               last_updated_by  = fnd_global.user_id
         where status = 'Inprocess'
           and process_step = 30
           and group_id = l_group_id;
    END IF;
     commit;
    --End CHG0045076
    --Update Lot Attribute
    message('Lot Attribute Update Start...............................................');
    For lot_rec in lot_update_c(l_group_id) Loop
      Begin
        SELECT TO_DATE('15-' || TO_CHAR(expiration_date, 'MON-YYYY'))
          INTO l_expiration_date
          FROM mtl_lot_numbers
         WHERE inventory_item_id = lot_rec.item_id
           AND organization_id = lot_rec.organization_id
           AND lot_number = lot_rec.lot_number;

        --Lot Found and Update the Lot Attribute
        l_request_status := '';
        l_err_msg        := '';
        update_lot_dff(p_organization_id => lot_rec.organization_id,
                       p_inv_item_id     => lot_rec.item_id,
                       p_lot_number      => lot_rec.lot_number,
                       p_expiration_date => l_expiration_date,
                       p_attribute2      => lot_rec.cage_number,
                       x_status          => l_request_status,
                       x_err_msg         => l_err_msg);

        -- Update Job Staging Table

      Exception
        When Others Then
          message('No Lot Record found for Inventory Item Id :' ||
                  lot_rec.item_id || ',Inventory Org Code :' ||
                  lot_rec.org_code || ',Lot Number :' ||
                  lot_rec.lot_number);
          l_request_status := 'E';
          l_err_msg        := 'Lot Number ' || lot_rec.lot_number ||
                              ',not found in mtl_lot_numbers Table.' ||
                              SQLERRM;
      End;

      update xxobjt.xx_wip_flmt_jobs_cmpl
         set process_step  = 50 -- Lot Update Triggered
            ,
             status       =
             (Case l_request_status
               When 'S' Then
                'Success'
               Else
                'Error'
             End),
             error_message = error_message || CHR(13) || 'Step 50: ' ||
                             (Case l_request_status
                               When 'S' Then
                                'Cage number Updated in Lot Dff.'
                               Else
                                'Error during Lot attribute Update,' ||
                                l_err_msg
                             End)
       where rowid = lot_rec.row_id;
    End Loop;

    If get_table_record_count(l_group_id) > 0 Then
       l_loop_cond := 'Y';
       continue;
    Else
       l_loop_cond := 'N';
    End If;
  Else
      l_loop_cond := 'N';
  End If;
 End Loop;

    message('End Package xx_wip_filament_jobs_pkg.xx_wip_flmt_jobs_cmpl');
  Exception
    When Others Then
      errbuf  := 'Unexpected Error in xx_wip_filament_jobs_pkg.xx_wip_flmt_jobs_cmpl;' ||
                 SQLERRM;
      retcode := 2;
      --update Record to Error
      update xxobjt.xx_wip_flmt_jobs_cmpl
         set process_step  = 40, -- WIP Move Transaction Manager Program Completed
             error_message = error_message || CHR(13) || errbuf,
             status        = 'Error',
             last_update_date = sysdate,
             last_updated_by  = fnd_global.user_id
       where status = 'Inprocess';
  End xx_wip_flmt_jobs_cmpl;
  --------------------------------------------------------------------
  --  name:            update_lot_dff
  --  create by:       Lingaraj Sarangi
  --  Revision:        1.0
  --  creation date:   18-Dec-2018
  --------------------------------------------------------------------
  --  purpose :        Update Lot Attribute Attribute 2
  --
  --  Parameters :     Standard Concurrent Program Parameters.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  18-Dec-2018 Lingaraj          CHG0044616 - manufacturing readiness
  --------------------------------------------------------------------
  Procedure update_lot_dff(p_organization_id NUMBER,
                           p_inv_item_id     NUMBER,
                           p_lot_number      VARCHAR2,
                           p_expiration_date DATE,
                           p_attribute2      VARCHAR2, -- Case Number
                           x_status          OUT Varchar2,
                           x_err_msg         OUT Varchar2) is
    l_source    NUMBER := 2;
    l_msg_data  VARCHAR2(32767);
    l_msg_count NUMBER;

    x_mtl_lot_numbers_rec mtl_lot_numbers%ROWTYPE;
    l_mtl_lot_numbers_rec mtl_lot_numbers%ROWTYPE;
  begin

    l_mtl_lot_numbers_rec.inventory_item_id := p_inv_item_id;
    l_mtl_lot_numbers_rec.organization_id   := p_organization_id;
    l_mtl_lot_numbers_rec.lot_number        := p_lot_number;
    l_mtl_lot_numbers_rec.expiration_date   := p_expiration_date;
    l_mtl_lot_numbers_rec.attribute2        := p_attribute2;
    l_mtl_lot_numbers_rec.last_update_date  := SYSDATE;
    l_mtl_lot_numbers_rec.last_updated_by   := FND_GLOBAL.user_id;

    inv_lot_api_pub.update_inv_lot(p_api_version   => 1.0,
                                   x_return_status => x_status,
                                   x_msg_count     => l_msg_count,
                                   x_msg_data      => l_msg_data,
                                   x_lot_rec       => x_mtl_lot_numbers_rec,
                                   p_lot_rec       => l_mtl_lot_numbers_rec,
                                   p_source        => l_source);
    IF x_status = fnd_api.g_ret_sts_success THEN
      COMMIT;
      message(p_lot_number ||
              ' - Lot Number Attribute Updated Sucessfully');
    ELSE
      message(p_lot_number || ' - Lot Number Attribute failed to Update');
      ROLLBACK;
      x_status := 'E';
      FOR i IN 1 .. l_msg_count LOOP
        x_err_msg := x_err_msg || '(' || i || ')' ||
                     fnd_msg_pub.get(p_msg_index => i, p_encoded => 'F');
      END LOOP;
    END IF;
  Exception
    When Others Then
      x_status  := 'E';
      x_err_msg := sqlerrm;
  End update_lot_dff;
END xx_wip_filament_jobs_pkg;
/