CREATE OR REPLACE PACKAGE BODY xx_wip_filament_jobs_pkg
AS


/******************************************************************************************************
  Procedure  : XX_WIP_FLMT_EXTR_JOBS_EXTRACT
  Author     : Rajeeb Das
  Date       : 17-SEP-2013
  
  Description: This Procedure to extracts Job details for 
               Filament Jobs for the Strat System.
  Parameters : Standard Concurrent Program Parameters.

  MODIFICATION HISTORY
  --------------------
  DATE        NAME         DESCRIPTION
  ----------  -----------  --------------------------------------------------------------
  17-SEP-2013 RDAS         Initial Version.

*******************************************************************************************************/
  PROCEDURE XX_WIP_FLMT_EXTR_JOBS_EXTRACT(errbuf     OUT varchar2
                                         ,retcode   OUT number)
  AS  

    BEGIN

      MERGE INTO  XXOBJT.XX_WIP_FLMT_JOBS fljob
      USING  (SELECT    ent.WIP_ENTITY_ID
                   ,ent.WIP_ENTITY_NAME
                   ,itm.SEGMENT1 item_number
                   ,flu.MEANING   FIRM_PLANNED_FLAG
                   ,job.START_QUANTITY
                   ,job.SCHEDULED_START_DATE
                   ,job.SCHEDULED_COMPLETION_DATE
                   ,job.DATE_RELEASED 
                   ,slu.MEANING  status               
                   ,job.CREATION_DATE
                   ,org.ORGANIZATION_CODE org_code
              FROM  WIP_DISCRETE_JOBS job,
                    MTL_SYSTEM_ITEMS  itm,
                    MFG_LOOKUPS lu,
                    MFG_LOOKUPS slu,
                    MFG_LOOKUPS flu,
                    WIP_OPERATIONS wo,
                    BOM_DEPARTMENTS bd,
                    WIP_SCHEDULE_GROUPS sg,
                    WIP_ENTITIES   ent,
                    ORG_ORGANIZATION_DEFINITIONS org
             WHERE  job.WIP_ENTITY_ID              =   ent.WIP_ENTITY_ID
               AND  job.SCHEDULE_GROUP_ID          =   sg.SCHEDULE_GROUP_ID
               AND  sg.SCHEDULE_GROUP_NAME         LIKE '%Extrusion%'
               AND  itm.INVENTORY_ITEM_ID          =   ent.PRIMARY_ITEM_ID
               AND  itm.ORGANIZATION_ID            =   job.ORGANIZATION_ID
               AND  job.ORGANIZATION_ID            =   org.ORGANIZATION_ID
               AND  lu.LOOKUP_CODE                 =   job.JOB_TYPE
               AND  lu.LOOKUP_TYPE                 =  'WIP_DISCRETE_JOB'
               AND  lu.meaning                     =   'Standard'
               AND  job.status_type                =   slu.LOOKUP_CODE
               AND  slu.LOOKUP_TYPE                =   'WIP_JOB_STATUS'
               AND  slu.meaning                    in  ('Released', 'Unreleased')
               AND  job.FIRM_PLANNED_FLAG          =   flu.LOOKUP_CODE
               AND  flu.LOOKUP_TYPE                =   'SYS_YES_NO'
               AND  NVL(job.QUANTITY_COMPLETED,0)  =   0
               AND  job.START_QUANTITY             >=  1
               AND  ent.WIP_ENTITY_ID              =   wo.WIP_ENTITY_ID
               AND  wo.ORGANIZATION_ID             =   job.ORGANIZATION_ID
               AND  bd.DEPARTMENT_ID               =   wo.DEPARTMENT_ID
               AND  EXISTS (Select 'X'
                              from WIP_OPERATIONS wo1,
                                   BOM_DEPARTMENTS d1
                             where ent.WIP_ENTITY_ID     = wo1.WIP_ENTITY_ID                             
                               and wo1.ORGANIZATION_ID   = job.ORGANIZATION_ID
                               and d1.DEPARTMENT_ID      = wo1.DEPARTMENT_ID
                               and d1.ORGANIZATION_ID    = job.ORGANIZATION_ID
                               and d1.DEPARTMENT_CODE    =   'F-EXTR'
                               and rownum = 1)
               AND  wo.OPERATION_SEQ_NUM           =   (select  min(wi.OPERATION_SEQ_NUM)
                                                          from  WIP_OPERATIONS wi
                                                         where  wi.WIP_ENTITY_ID = ent.WIP_ENTITY_ID
                                                           and  wi.ORGANIZATION_ID = job.ORGANIZATION_ID)
               AND  wo.QUANTITY_COMPLETED          =   0) jobs
          ON   (fljob.WIP_ENTITY_ID = jobs.WIP_ENTITY_ID)
          WHEN not matched THEN
          INSERT (WIP_ENTITY_ID
                  ,WIP_ENTITY_NAME
                  ,ITEM_NUMBER
                  ,FIRM_PLANNED_FLAG
                  ,START_QUANTITY
                  ,SCHEDULED_START_DATE
                  ,SCHEDULED_COMPLETION_DATE
                  ,DATE_RELEASED
                  ,STATUS
                  ,CREATION_DATE
                  ,ORG_CODE)
          VALUES (jobs.WIP_ENTITY_ID
                  ,jobs.WIP_ENTITY_NAME
                  ,jobs.ITEM_NUMBER
                  ,jobs.FIRM_PLANNED_FLAG
                  ,jobs.START_QUANTITY
                  ,jobs.SCHEDULED_START_DATE
                  ,jobs.SCHEDULED_COMPLETION_DATE
                  ,jobs.DATE_RELEASED
                  ,jobs.STATUS
                  ,jobs.CREATION_DATE
                  ,jobs.ORG_CODE);

          commit;

          DELETE FROM XXOBJT.XX_WIP_FLMT_JOBS jobs
           WHERE NOT EXISTS (select  'X'
                               FROM  WIP_DISCRETE_JOBS job,
                                     MTL_SYSTEM_ITEMS  itm,
                                     MFG_LOOKUPS lu,
                                     MFG_LOOKUPS slu,
                                     MFG_LOOKUPS flu,
                                     WIP_OPERATIONS wo,
                                     BOM_DEPARTMENTS bd,
                                     WIP_SCHEDULE_GROUPS sg,
                                     WIP_ENTITIES   ent,
                                     ORG_ORGANIZATION_DEFINITIONS org
                              WHERE  job.WIP_ENTITY_ID              =   jobs.WIP_ENTITY_ID
                                AND  job.WIP_ENTITY_ID              =   ent.WIP_ENTITY_ID
                                AND  job.SCHEDULE_GROUP_ID          =   sg.SCHEDULE_GROUP_ID
                                AND  sg.SCHEDULE_GROUP_NAME         LIKE '%Extrusion%'
                                AND  itm.INVENTORY_ITEM_ID          =   ent.PRIMARY_ITEM_ID
                                AND  itm.ORGANIZATION_ID            =   job.ORGANIZATION_ID
                                AND  job.ORGANIZATION_ID            =   org.ORGANIZATION_ID
                                AND  lu.LOOKUP_CODE                 =   job.JOB_TYPE
                                AND  lu.LOOKUP_TYPE                 =  'WIP_DISCRETE_JOB'
                                AND  lu.meaning                     =   'Standard'
                                AND  job.status_type                =   slu.LOOKUP_CODE
                                AND  slu.LOOKUP_TYPE                =   'WIP_JOB_STATUS'
                                AND  slu.meaning                    in  ('Released', 'Unreleased')
                                AND  job.FIRM_PLANNED_FLAG          =   flu.LOOKUP_CODE
                                AND  flu.LOOKUP_TYPE                =   'SYS_YES_NO'
                                AND  NVL(job.QUANTITY_COMPLETED,0)  =   0
                                AND  job.START_QUANTITY             >=  1
                                AND  ent.WIP_ENTITY_ID              =   wo.WIP_ENTITY_ID
                                AND  wo.ORGANIZATION_ID             =   job.ORGANIZATION_ID
                                AND  bd.DEPARTMENT_ID               =   wo.DEPARTMENT_ID
                                AND  EXISTS (Select 'X'
                                               from WIP_OPERATIONS wo1,
                                                    BOM_DEPARTMENTS d1
                                              where ent.WIP_ENTITY_ID     = wo1.WIP_ENTITY_ID                             
                                                and wo1.ORGANIZATION_ID   = job.ORGANIZATION_ID
                                                and d1.DEPARTMENT_ID      = wo1.DEPARTMENT_ID
                                                and d1.ORGANIZATION_ID    = job.ORGANIZATION_ID
                                                and d1.DEPARTMENT_CODE    =   'F-EXTR'
                                                and rownum = 1)
                                AND  wo.OPERATION_SEQ_NUM           =   (select  min(wi.OPERATION_SEQ_NUM)
                                                                           from  WIP_OPERATIONS wi
                                                                          where  wi.WIP_ENTITY_ID = ent.WIP_ENTITY_ID
                                                                            and  wi.ORGANIZATION_ID = job.ORGANIZATION_ID)
                                AND  wo.QUANTITY_COMPLETED          =   0);

            commit;  

    

  END XX_WIP_FLMT_EXTR_JOBS_EXTRACT;


END xx_wip_filament_jobs_pkg;
/
show errors
exit