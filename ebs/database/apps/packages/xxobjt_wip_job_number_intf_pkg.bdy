CREATE OR REPLACE PACKAGE BODY xxobjt_wip_job_number_intf_pkg AS

  /**************************************************************************************************
     Procedure Name: p_extract_jobs
     Parameters    : Standard Concurrent program parameters
     Description   : Extract WIP Jobs from Oracle meeting the conditions in the Query
                     and populating the XXOBJT.XXOBJT_WIP_JOB_NUM_INTERFACE table.
  
    MODIFICATION HISTORY
    --------------------
    DATE        NAME         DESCRIPTION
    ----------  -----------  --------------------------------------------------------------
    17-SEP-2013 RDAS         Initial Version.
    28.2.17     yuval tal    INC0088364 - Jobs Will Not Change to Serial Numbers
  
  ***************************************************************************************************/
  PROCEDURE p_extract_jobs(errbuf  OUT VARCHAR2,
		   retcode OUT NUMBER) AS
  
  BEGIN
    MERGE INTO xxobjt.xxobjt_wip_job_num_interface intf
    USING (SELECT job.wip_entity_id,
	      ent.wip_entity_name,
	      itm.segment1 item_number,
	      itm.description,
	      job.creation_date,
	      job.organization_id
           FROM   wip_discrete_jobs   job,
	      mtl_system_items    itm,
	      mfg_lookups         lu,
	      mfg_lookups         slu,
	      wip_operations      wo,
	      wip_schedule_groups sg,
	      wip_entities        ent
           WHERE  job.wip_entity_id = ent.wip_entity_id
           AND    job.creation_date >= SYSDATE - 100 -- This was added to always look for data in the past 100 days only
           AND    job.schedule_group_id = sg.schedule_group_id
           AND    sg.schedule_group_name = 'SYS_Printers'
           AND    itm.inventory_item_id = ent.primary_item_id
           AND    itm.organization_id = job.organization_id
           AND    lu.lookup_code = job.job_type
           AND    lu.lookup_type = 'WIP_DISCRETE_JOB'
           AND    lu.meaning = 'Standard'
           AND    job.status_type = slu.lookup_code
           AND    slu.lookup_type = 'WIP_JOB_STATUS'
           AND    slu.meaning = 'Released'
           AND    job.quantity_completed = 0
           AND    job.start_quantity >= 1
           AND    ent.wip_entity_id = wo.wip_entity_id
           AND    wo.organization_id = job.organization_id
	     --AND  wo.OPERATION_SEQ_NUM        =   10        -- INC0088364   TK: Op Seq 10 may not be the first Op Seq
           AND    wo.previous_operation_seq_num IS NULL -- INC0088364  TK: Op Seq 10 may not be the first Op Seq
           AND    wo.quantity_in_queue = 1) jobs
    
    ON (intf.wip_entity_id = jobs.wip_entity_id)
    WHEN NOT MATCHED THEN
      INSERT
        (intf.wip_entity_id,
         intf.wip_entity_name,
         intf.assembly,
         intf.item_description,
         intf.job_creation_date,
         intf.job_organization_id,
         intf.last_updated_by,
         intf.last_update_date,
         intf.creation_date,
         intf.created_by)
      VALUES
        (jobs.wip_entity_id,
         jobs.wip_entity_name,
         jobs.item_number,
         jobs.description,
         jobs.creation_date,
         jobs.organization_id,
         fnd_global.user_id,
         SYSDATE,
         SYSDATE,
         fnd_global.user_id);
  
    COMMIT;
  
  END p_extract_jobs;

  /**************************************************************************************************
     Procedure Name: p_wip_job_name_change
     Parameters    : Standard Concurrent program parameters
     Description   : After the Strat System has generated a new Job Number it writes the
                     new Job Number to the XXOBJT.XXOBJT_WIP_JOB_NUM_INTERFACE table. This
                     procedure picks up the new Job numbers and updates the wip_entities
                     table.
  
           NOTE: The update of the wip_entities table was done with the blessings of Oracle.
                 The Oracle SR #3-7660835211 has the details.
  
    MODIFICATION HISTORY
    --------------------
    DATE        NAME         DESCRIPTION
    ----------  -----------  --------------------------------------------------------------
    17-SEP-2013 RDAS         Initial Version.
  ***************************************************************************************************/

  PROCEDURE p_wip_job_name_change(errbuf  OUT VARCHAR2,
		          retcode OUT NUMBER) AS
    CURSOR job_change_cur IS
      SELECT wip_entity_id,
	 wip_entity_name,
	 job_sn,
	 job_organization_id,
	 job_creation_date
      FROM   xxobjt.xxobjt_wip_job_num_interface
      WHERE  nvl(job_num_imported, 'N') = 'N';
  
    ln_group_id      NUMBER;
    lv_return_status VARCHAR2(1);
    lv_error_msg     VARCHAR2(1000);
  
  BEGIN
  
    FOR job_rec IN job_change_cur LOOP
    
      BEGIN
        UPDATE wip_entities
        SET    wip_entity_name = job_rec.job_sn
        WHERE  wip_entity_id = job_rec.wip_entity_id;
      
        fnd_file.put_line(fnd_file.log,
		  'Changed job Number: From ' ||
		  job_rec.wip_entity_name || ' to ' ||
		  job_rec.job_sn);
      
        UPDATE xxobjt.xxobjt_wip_job_num_interface
        SET    job_num_imported    = 'Y',
	   job_interfaced_date = SYSDATE,
	   last_update_date    = SYSDATE,
	   last_updated_by     = fnd_global.user_id
        WHERE  wip_entity_id = job_rec.wip_entity_id;
      
        COMMIT;
      
      EXCEPTION
        WHEN OTHERS THEN
          lv_error_msg := substr(SQLERRM, 1, 200);
        
          UPDATE xxobjt.xxobjt_wip_job_num_interface
          SET    job_num_imported   = 'E',
	     job_num_import_err = lv_error_msg,
	     last_update_date   = SYSDATE,
	     last_updated_by    = fnd_global.user_id
          WHERE  wip_entity_id = job_rec.wip_entity_id;
        
          COMMIT;
        
      END;
    
    END LOOP;
  
    -- Purge the Job Number interface table any records
    -- whose creation date is less than last three years past
  
    DELETE FROM xxobjt.xxobjt_wip_job_num_interface
    WHERE  creation_date <= SYSDATE - INTERVAL '3' YEAR;
  
    COMMIT;
  
  END p_wip_job_name_change;

END xxobjt_wip_job_number_intf_pkg;
/
