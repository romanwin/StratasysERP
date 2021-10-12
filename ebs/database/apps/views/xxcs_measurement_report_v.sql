CREATE OR REPLACE VIEW xxcs_measurement_report_v AS
SELECT
--------------------------------------------------------------------
--  name:            XXCS_MEASUREMENT_REPORT_V
--  create by:       Vitaly.K
--  Revision:        1.7
--  creation date:   17/01/2010
--------------------------------------------------------------------
--  purpose :       Discoverer Reports
--------------------------------------------------------------------
--  ver  date        name             desc
--  1.0  17/01/2010  Vitaly           initial build
--  1.1  14/04/2010  Yoram Zamir      incident_id, contract_service_id, instance_id,coverage,contract_number were added
--  1.2  08/06/2010  Vitaly           Security by OU was changed
--  1.3  28/06/2010  Yoram Zamir      only reactive calls,only closed SR's, exclude sr status = 'CANCELLED'
--                                    KPI's hours as decimal, KPI's thresholds, new field cs_region
--  1.4  26/07/2010  Vitaly           New function XXCS_MTB_REPORT_PKG.get_workdays(org_id,from_date,to_date) was added to workdays (minus weekends) calculation,
--                                    SR_DATA_TAB nested loop added
--  1.5  31/08/2010  Roman            Modified sts_responded_date calcualtion
--  1.6  15/09/2010  Roman            Replaced time_to_assigned calculation with time_to_responded
--  1.7  28/02/2010  Roman            Added S/N, Printer, Printer description, resource_name
--  1.8  10/11/2011  Dalit A. Raviv   Add CS Region Group field
--------------------------------------------------------------------
         rep.sr_type,
         rep.incident_number,
         rep.incident_id,
         rep.contract_service_id,
         rep.customer_product_id instance_id,
         cont.coverage,
         cont.contract_number,
         cont.contract_or_warranty,
         cont.type        contract_type,
         cont.th_time_to_visit,
         cont.th_time_to_incomplet,
         cont.th_incomplete_to_complete,
         cont.th_time_to_assign,
         rep.first_eng_visit_task_type,
         rep.sr_status,
         rep.customer_name,
         rep.operating_unit,
         rep.owner_cs_region,
         rep.serial_number,
         rep.printer,
         rep.printer_description,
         rep.resource_name,
         rep.incident_occurred_date,
         rep.sts_responded_date,
         rep.first_eng_visit,
         rep.sts_incomplete_date,
         rep.sts_complete_date,
         rep.time_to_visit_dec                                                  time_to_visit_clndays_dec,
         rep.time_to_visit_wrkd_dec                                             time_to_visit_days_dec,      ----time_to_visit_wrkdays_dec,
         rep.time_to_visit_dec*24                                               time_to_visit_clnd_hours_dec,
         rep.time_to_visit_wrkd_dec*24                                          time_to_visit_hours_dec,     ----time_to_visit_wrkd_hours_dec,
         decode(rep.time_to_visit,':',NULL,rep.time_to_visit)                   time_to_visit_clnd,
         decode(rep.time_to_visit_wrkd,':',NULL,rep.time_to_visit_wrkd)         time_to_visit,               ----time_to_visit_wrkd,

         rep.time_to_responded_dec                                               time_to_responded_clndays_dec,
         rep.time_to_responded_wrkd_dec                                          time_to_responded_days_dec,   ----time_to_responded_wrkdays_dec,
         rep.time_to_responded_dec*24                                            time_to_responded_clnd_hrs_dec,
         rep.time_to_responded_wrkd_dec*24                                       time_to_responded_hours_dec,  ----time_to_responded_wrkd_hrs_dec,
         decode(rep.time_to_responded,':',NULL,rep.time_to_responded)             time_to_responded_clnd,
         decode(rep.time_to_responded_wrkd,':',NULL,rep.time_to_responded_wrkd)   time_to_responded,            ----time_to_responded_wrkd,

         rep.time_to_incomplete_dec                                                time_to_incomplete_clndays_dec,
         rep.time_to_incomplete_wrkd_dec                                           time_to_incomplete_days_dec,   ----time_to_incomplete_wrkdays_dec,
         rep.time_to_incomplete_dec*24                                             time_to_incompl_clnd_hrs_dec,
         rep.time_to_incomplete_wrkd_dec*24                                        time_to_incomplete_hours_dec,  ----time_to_incomplet_wrkd_hrs_dec,
         decode(rep.time_to_incomplete,':',NULL,rep.time_to_incomplete)            time_to_incomplete_clnd,
         decode(rep.time_to_incomplete_wrkd,':',NULL,rep.time_to_incomplete_wrkd)  time_to_incomplete,            ----time_to_incomplete_wrkd,


         rep.incomplete_to_complete_dec                                                   incomple_to_comple_clndays_dec,
         rep.incomplete_to_cmplt_wrkd_dec                                                 incomple_to_comple_days_dec,   ----incomple_to_cmplt_wrkdays_dec,
         rep.incomplete_to_complete_dec*24                                                incomple_to_compl_clnd_hrs_dec,
         rep.incomplete_to_cmplt_wrkd_dec*24                                              incomple_to_comple_hours_dec,   ----incomple_to_compl_wrkd_hrs_dec,
         decode(rep.incomplete_to_complete,':',NULL,rep.incomplete_to_complete)           incomplete_to_complete_clnd,
         decode(rep.incomplete_to_complete_wrkd,':',NULL,rep.incomplete_to_complete_wrkd) incomplete_to_complete,        ----incomplete_to_complete_wrkd,
         (CASE WHEN rep.time_to_visit_dec*24 > cont.th_time_to_visit
                    AND cont.th_time_to_visit<>0
               THEN 1
               ELSE 0
         END )                                                                  time_to_visit_exception_clnd,
         (CASE WHEN rep.time_to_visit_wrkd_dec*24 > cont.th_time_to_visit
                    AND cont.th_time_to_visit<>0
               THEN 1
               ELSE 0
         END )                                                                  time_to_visit_exception,    -----time_to_visit_exception_wrkd,
         (CASE WHEN rep.time_to_responded_dec*24 > cont.th_time_to_assign
                    AND cont.th_time_to_assign<>0
               THEN 1
               ELSE 0
         END )                                                                  time_to_responded_except_clnd,
         (CASE WHEN rep.time_to_responded_wrkd_dec*24 > cont.th_time_to_assign
                    AND cont.th_time_to_assign<>0
               THEN 1
               ELSE 0
         END )                                                                  time_to_responded_exception,   -----time_to_responded_except_wrkd,
         (CASE WHEN rep.time_to_incomplete_dec*24 > cont.th_time_to_incomplet
                    AND cont.th_time_to_incomplet<>0
               THEN 1
               ELSE 0
         END )                                                                  time_to_incomplete_except_clnd,
         (CASE WHEN rep.time_to_incomplete_wrkd_dec*24 > cont.th_time_to_incomplet
                    AND cont.th_time_to_incomplet<>0
               THEN 1
               ELSE 0
         END )                                                                  time_to_incomplete_exception,   ----time_to_incomplete_except_wrkd,
         (CASE WHEN rep.incomplete_to_complete_dec*24  > cont.th_incomplete_to_complete
                    AND cont.th_incomplete_to_complete<>0
               THEN 1
               ELSE 0
         END )                                                                  incomple_to_comple_except_clnd,
         (CASE WHEN rep.incomplete_to_cmplt_wrkd_dec*24  > cont.th_incomplete_to_complete
                    AND cont.th_incomplete_to_complete<>0
               THEN 1
               ELSE 0
         END )                                                                  incomple_to_comple_exception,   ----incomple_to_comple_except_wrkd

         region_gr.CS_Region_group                                              CS_Region_group -- 10/11/2011 Dalit A. Raviv
         --decode(region_gr.CS_Region_group,null,rep.owner_cs_region, region_gr.CS_Region_group) CS_Region_group
FROM
(SELECT  MEASUR.sr_type,
         MEASUR.incident_number,
         MEASUR.incident_id,
         MEASUR.contract_service_id,
         MEASUR.customer_product_id,
         MEASUR.first_eng_visit_task_type,
         MEASUR.sr_status,
         MEASUR.customer_name,
         MEASUR.operating_unit,
         MEASUR.owner_cs_region,
         MEASUR.serial_number,
         MEASUR.printer,
         MEASUR.printer_description,
         MEASUR.resource_name,
         MEASUR.incident_occurred_date,
         MEASUR.sts_responded_date,
         MEASUR.first_eng_visit,
         MEASUR.sts_incomplete_date,
         MEASUR.sts_complete_date,
         MEASUR.time_to_visit                                                                                          time_to_visit_dec,
         MEASUR.time_to_visit_wrkd                                                                                     time_to_visit_wrkd_dec,
         trunc(MEASUR.time_to_visit_HR) ||':'|| trunc(MEASUR.time_to_visit_MM)                                         time_to_visit,
         trunc(MEASUR.time_to_visit_wrkd_HR) ||':'|| trunc(MEASUR.time_to_visit_wrkd_MM)                               time_to_visit_wrkd,
         MEASUR.time_to_responded                                                                                       time_to_responded_dec,
         MEASUR.time_to_responded_wrkd                                                                                  time_to_responded_wrkd_dec,
         trunc(MEASUR.time_to_responded_HR) ||':'|| trunc(MEASUR.time_to_responded_MM)                                   time_to_responded,
         trunc(MEASUR.time_to_responded_wrkd_HR) ||':'|| trunc(MEASUR.time_to_responded_wrkd_MM)                         time_to_responded_wrkd,
         MEASUR.time_to_incomplete                                                                                     time_to_incomplete_dec,
         MEASUR.time_to_incomplete_wrkd                                                                                time_to_incomplete_wrkd_dec,
         trunc(MEASUR.time_to_incomplete_HR) ||':'||trunc(MEASUR.time_to_incomplete_MM)                                time_to_incomplete,
         trunc(MEASUR.time_to_incomplete_wrkd_HR) ||':'||trunc(MEASUR.time_to_incomplete_wrkd_MM)                      time_to_incomplete_wrkd,
         MEASUR.incomplete_to_complete                                                                                 incomplete_to_complete_dec,
         MEASUR.incomplete_to_complete_wrkd                                                                            incomplete_to_cmplt_wrkd_dec,
         trunc(MEASUR.incomplete_to_complete_HR) ||':'||trunc(MEASUR.incomplete_to_complete_MM)                        incomplete_to_complete,
         trunc(MEASUR.incomplete_to_complete_wrkd_HR) ||':'||trunc(MEASUR.incomplete_to_complete_wrkd_MM)              incomplete_to_complete_wrkd
FROM
(SELECT
       SR_TAB.sr_type,
       SR_TAB.incident_number,
       SR_TAB.incident_id,
       SR_TAB.contract_service_id,
       SR_TAB.customer_product_id,
       SR_TAB.first_eng_visit_task_type,
       SR_TAB.sr_status,
       SR_TAB.customer_name,
       SR_TAB.operating_unit,
       SR_TAB.owner_cs_region,
       SR_TAB.serial_number,
       SR_TAB.printer,
       SR_TAB.printer_description,
       SR_TAB.resource_name,
       SR_TAB.incident_occurred_date,
       SR_TAB.sts_responded_date,
       SR_TAB.first_eng_visit,  --- task types = On Site Support
       SR_TAB.sts_incomplete_date,
       SR_TAB.sts_complete_date,
       decode(SR_TAB.first_eng_visit,NULL,NULL,(SR_TAB.first_eng_visit_calc-SR_TAB.incident_occurred_date))                                                                  time_to_visit,
       SR_TAB.time_to_visit_wrkd,
       trunc(to_number(decode(SR_TAB.first_eng_visit,NULL,NULL,round((SR_TAB.first_eng_visit_calc-SR_TAB.incident_occurred_date)*24,2))),0)                                  time_to_visit_HR,
       SR_TAB.time_to_visit_wrkd*24                time_to_visit_wrkd_HR,
       mod(to_number(decode(SR_TAB.first_eng_visit,  NULL,NULL,round((SR_TAB.first_eng_visit_calc-SR_TAB.incident_occurred_date)*24*60,2))),60)                              time_to_visit_MM,
       mod(SR_TAB.time_to_visit_wrkd*24*60,60)     time_to_visit_wrkd_MM,

       decode(SR_TAB.sts_responded_date,NULL,NULL,(SR_TAB.sts_responded_date-SR_TAB.incident_occurred_date))                                                              time_to_responded,
       SR_TAB.time_to_responded_wrkd,
       trunc(to_number(decode(SR_TAB.sts_responded_date,NULL,NULL,round((SR_TAB.sts_responded_date-SR_TAB.incident_occurred_date)*24,2))),0)                              time_to_responded_HR,
       SR_TAB.time_to_responded_wrkd*24             time_to_responded_wrkd_HR,
       mod(to_number(decode(SR_TAB.sts_responded_date,  NULL,NULL,round((SR_TAB.sts_responded_date-SR_TAB.incident_occurred_date)*24*60,2))),60)                          time_to_responded_MM,
       mod(SR_TAB.time_to_responded_wrkd*24*60,60)  time_to_responded_wrkd_MM,

       decode(SR_TAB.sts_incomplete_date,NULL,NULL,(SR_TAB.sts_incomplete_date-SR_TAB.incident_occurred_date))                                                              time_to_incomplete,
       SR_TAB.time_to_incomplete_wrkd,
       trunc(to_number(decode(SR_TAB.sts_incomplete_date,NULL,NULL,round((SR_TAB.sts_incomplete_date-SR_TAB.incident_occurred_date)*24,2))),0)                              time_to_incomplete_HR,
       SR_TAB.time_to_incomplete_wrkd*24           time_to_incomplete_wrkd_HR,
       mod(to_number(decode(SR_TAB.sts_incomplete_date,  NULL,NULL,round((SR_TAB.sts_incomplete_date-SR_TAB.incident_occurred_date)*24*60,2))),60)                          time_to_incomplete_MM,
       mod(SR_TAB.time_to_incomplete_wrkd*24*60,60) time_to_incomplete_wrkd_MM,

       decode(SR_TAB.sts_complete_date,NULL,NULL,(SR_TAB.sts_complete_date-SR_TAB.sts_incomplete_date))                                                        incomplete_to_complete,
       SR_TAB.incomplete_to_complete_wrkd,
       trunc(round((SR_TAB.sts_complete_date-SR_TAB.sts_incomplete_date)*24,2),0)                                                                              incomplete_to_complete_HR,
       SR_TAB.incomplete_to_complete_wrkd*24               incomplete_to_complete_wrkd_HR,
       mod(round((SR_TAB.sts_complete_date-SR_TAB.sts_incomplete_date)*24*60,2),60)                                                                            incomplete_to_complete_MM,
       mod(SR_TAB.incomplete_to_complete_wrkd*24*60,60)    incomplete_to_complete_wrkd_MM
FROM (
SELECT SR_DATA_TAB.SR_TYPE,
       SR_DATA_TAB.incident_number,
       SR_DATA_TAB.incident_id,
       SR_DATA_TAB.contract_service_id,
       SR_DATA_TAB.customer_product_id,
       SR_DATA_TAB.incident_occurred_date,
       SR_DATA_TAB.sts_responded_date,
       decode(SR_DATA_TAB.sts_responded_date,NULL,NULL,
              XXCS_MTB_REPORT_PKG.get_workdays(SR_DATA_TAB.org_id,SR_DATA_TAB.incident_occurred_date,SR_DATA_TAB.sts_responded_date))       time_to_responded_wrkd,
       SR_DATA_TAB.sts_incomplete_date,
       decode(SR_DATA_TAB.sts_incomplete_date,NULL,NULL,
              XXCS_MTB_REPORT_PKG.get_workdays(SR_DATA_TAB.org_id,SR_DATA_TAB.incident_occurred_date,SR_DATA_TAB.sts_incomplete_date))     time_to_incomplete_wrkd,
       SR_DATA_TAB.sts_complete_date,
       decode(SR_DATA_TAB.sts_complete_date,NULL,NULL,
              decode(SR_DATA_TAB.sts_incomplete_date,NULL,NULL,
                     XXCS_MTB_REPORT_PKG.get_workdays(SR_DATA_TAB.org_id,SR_DATA_TAB.sts_incomplete_date,SR_DATA_TAB.sts_complete_date)))  incomplete_to_complete_wrkd,
       SR_DATA_TAB.first_eng_visit,       --- task types = On Site Support
       SR_DATA_TAB.first_eng_visit_calc,  --- task types = On Site Support
       decode(SR_DATA_TAB.first_eng_visit,NULL,NULL,
              XXCS_MTB_REPORT_PKG.get_workdays(SR_DATA_TAB.org_id,SR_DATA_TAB.incident_occurred_date,SR_DATA_TAB.first_eng_visit))         time_to_visit_wrkd,
       SR_DATA_TAB.first_eng_visit_task_type,
       SR_DATA_TAB.SR_STATUS,
       SR_DATA_TAB.sr_close_flag,
       SR_DATA_TAB.customer_name,
       SR_DATA_TAB.org_id,
       SR_DATA_TAB.operating_unit,
       SR_DATA_TAB.owner_cs_region,
       SR_DATA_TAB.serial_number,
       SR_DATA_TAB.printer,
       SR_DATA_TAB.printer_description,
       SR_DATA_TAB.resource_name
FROM (
SELECT ITT.NAME                          SR_TYPE,
       sr.incident_number,
       sr.incident_id,
       nvl(sr.contract_service_id, -111) contract_service_id,
       sr.customer_product_id,
       sr.incident_occurred_date,
       ----DIARY_TAB.status,
       CASE WHEN  EXISTS (SELECT 1 --for cases with Phone Call only
                                              FROM jtf_tasks_b jtb1,
                                                   jtf_task_types_b_dfv jttb_dfv,
                                                   jtf_task_types_b jttb
                                             WHERE jtb1.task_type_id = jttb.task_type_id
                                               AND jttb.rowid = jttb_dfv.row_id
                                               AND jttb_dfv.xxcs_on_site = 'N'
                                               AND jtb1.source_object_id = sr.incident_id)
           THEN
       MIN(decode(DIARY_TAB.status,'RESPONDED', DIARY_TAB.MIN_DATE,NULL))
          ELSE NULL
          END sts_responded_date,--Roman 31/08/2010
       MIN(decode(DIARY_TAB.status,'INCOMPLETE',DIARY_TAB.MIN_DATE,NULL))    sts_incomplete_date,
       MIN(decode(DIARY_TAB.status,'COMPLETE',  DIARY_TAB.MIN_DATE,NULL))    sts_complete_date,
       SERVICE_TAB.service_date    first_eng_visit,  --- task types = On Site Support
       case
           when sr.incident_occurred_date>service_tab.service_date then
                sr.incident_occurred_date
           else
                service_tab.service_date
           end first_eng_visit_calc,  --- task types = on site support
       SERVICE_TAB.task_type_name        first_eng_visit_task_type,
       SERVICE_TAB.resource_name,
       T.NAME                            SR_STATUS,
       nvl(st.close_flag,'N')            sr_close_flag,
       hzp.party_name                    customer_name,
       sr.org_id,
       ou.name                           operating_unit,
       cii.attribute8                    owner_cs_region,
       cii.serial_number,
       msib.segment1                     printer,
       msib.description                  printer_description
FROM   cs_incidents_all_b          sr,
       csi_item_instances          cii,
       cs_incident_types_b         it,
       cs_incident_types_tl        itt,
       cs_incident_statuses_b      st,
       cs_incident_statuses_tl     t,
       hz_parties                  hzp,
       hr_operating_units          ou,
       mtl_system_items_b          msib,
       XXCS_SR_DIARY_STS_DATES_V   DIARY_TAB,
       (SELECT t.INCIDENT_TYPE_ID,
               t.NAME,
               t.ATTRIBUTE4   reactive_proactive,
               t.ATTRIBUTE5   sr_type_category
        FROM cs_incident_types_vl   t
        WHERE SYSDATE BETWEEN nvl(t.START_DATE_ACTIVE,SYSDATE)
                          AND nvl(t.END_DATE_ACTIVE,SYSDATE+1)
                                                         ) PROACTIVE_REACTIVE,
      (SELECT TASK_TAB.incident_id,
              TASK_TAB.task_type_name,
              TASK_TAB.service_date,
              TASK_TAB.resource_name
       FROM (SELECT     cia.incident_id,
                        tstt.name   task_type_name,
                        dl.service_date,
                        rs.resource_name,
                        ROW_NUMBER( ) OVER (PARTITION BY cia.incident_id ORDER BY dl.service_date,jtv.TASK_ID  NULLS LAST) task_rownum
              FROM      csf_debrief_lines      dl,
                        csf_debrief_headers    dh,
                        JTF_TASK_STATUSES_VL   JTS1,
                        JTF_TASK_STATUSES_VL   JTS2,
                        MTL_SYSTEM_ITEMS_B_KFV MSIBK,
                        JTF_PARTIES_ALL_V      JPA,
                        CS_INCIDENTS_ALL_B     CIA,
                        CSF_DEBRIEF_HEADERS    CDH,
                        JTF_TASKS_VL           JTV,
                        JTF_TASK_ASSIGNMENTS   JTA,
                        jtf_task_types_b       tst,
                        jtf_task_types_tl      tstt,
                        jtf_rs_all_resources_vl  rs
              WHERE     dh.debrief_header_id = dl.debrief_header_id
                 AND    JTV.SOURCE_OBJECT_ID = CIA.INCIDENT_ID(+)
                 AND    CDH.TASK_ASSIGNMENT_ID = JTA.TASK_ASSIGNMENT_ID
                 AND    jta.RESOURCE_ID = rs.resource_id
                 AND    JTA.TASK_ID = JTV.TASK_ID
                 AND    JTA.ASSIGNEE_ROLE = 'ASSIGNEE'
                 AND    NVL(JTV.DELETED_FLAG, 'N') != 'Y'
                 AND    JTV.CUSTOMER_ID = JPA.PARTY_ID(+)
                 AND    JTV.TASK_STATUS_ID = JTS1.TASK_STATUS_ID
                 AND    JTA.ASSIGNMENT_STATUS_ID = JTS2.TASK_STATUS_ID
                 AND    CIA.INVENTORY_ITEM_ID = MSIBK.INVENTORY_ITEM_ID(+)
                 AND    jta.TASK_ASSIGNMENT_ID = dh.task_assignment_id
                 AND    MSIBK.organization_id = xxinv_utils_pkg.get_master_organization_id  ----Master organization--91
                 AND    tst.task_type_id = jtv.TASK_TYPE_ID
                 AND    tst.task_type_id = tstt.task_type_id
                 AND    tstt.language = userenv('LANG')
                 AND EXISTS (SELECT 1  ----check On Site Support ONLY
                              FROM   jtf_task_types_b t,
                                     jtf_task_types_b_dfv tf,
                                     jtf_task_types_tl tt
                              WHERE  t.rowid = tf.row_id AND
                                     t.task_type_id = tt.task_type_id AND
                                     tt.language = userenv('LANG') AND
                                     t.rule = 'DISPATCH' AND
                                     tf.xxcs_on_site = 'Y' AND
                                     t.task_type_id=jtv.TASK_TYPE_ID
                             UNION ALL
                             SELECT 1
                             FROM   dual
                             WHERE  jtv.TASK_TYPE_ID = 11007 AND dl.business_process_id IN (1100,1001)
                                    ) ) TASK_TAB
        WHERE task_rownum=1
                                    )    SERVICE_TAB  ----first enineer on site visit date
WHERE  sr.incident_type_id          = it.incident_type_id                 AND
       sr.incident_type_id          = PROACTIVE_REACTIVE.incident_type_id AND
       sr.customer_product_id       = cii.instance_id                     AND
       msib.inventory_item_id       = cii.inventory_item_id               AND
       msib.organization_id         = 91                                  AND
       it.incident_type_id          = itt.incident_type_id                AND
       itt.language                 = userenv('LANG')                     AND
       sr.incident_status_id        = st.incident_status_id               AND
       t.language                   = userenv('LANG')                     AND
       upper(t.NAME)                <> 'CANCELLED'                        AND
       st.incident_status_id        = t.incident_status_id                AND
       --nvl(st.close_flag,'N')       = 'Y'                                 AND
       EXISTS (SELECT 1
               FROM  XXCS_SR_DIARY_STS_DATES_V diary
               WHERE diary.status ='COMPLETE' AND
                     diary.incident_id = sr.incident_id)                  AND
       st.incident_subtype          = 'INC'                               AND
       sr.customer_id               = hzp.party_id(+)                     AND
       sr.org_id                    = ou.organization_id(+)               AND
       sr.incident_id               = DIARY_TAB.incident_id(+)            AND
       sr.incident_id               = SERVICE_TAB.incident_id(+)          AND
       PROACTIVE_REACTIVE.reactive_proactive = 'REACTIVE'                 AND
       XXCS_UTILS_PKG.CHECK_SECURITY_BY_OPER_UNIT(sr.org_id,sr.customer_id)='Y'
GROUP BY ITT.NAME,
       sr.incident_number,
       sr.incident_id,
       nvl(sr.contract_service_id, -111),
       sr.customer_product_id,
       sr.incident_occurred_date,
       SERVICE_TAB.service_date,
       SERVICE_TAB.task_type_name,
       SERVICE_TAB.resource_name,
       T.NAME,
       nvl(st.close_flag,'N'),
       hzp.party_name,
       sr.org_id,
       ou.name,
       cii.attribute8,
       cii.serial_number,
       msib.segment1,
       msib.description
                       )     SR_DATA_TAB
                             )    SR_TAB
                                   ) MEASUR
                                         ) REP,
       (SELECT    cn.contract_service_id,
                  cn.coverage,
                  cn.contract_number,
                  cn.instance_id,
                  cn.contract_or_warranty,
                  cn.type,
                  threshold.time_to_visit           th_time_to_visit,
                  threshold.time_to_incomplete      th_time_to_incomplet,
                  threshold.incomplete_to_complete  th_incomplete_to_complete,
                  threshold.time_to_assign          th_time_to_assign
       FROM      (SELECT
                  zz.contract_service_id,
                  zz.coverage,
                  zz.contract_number,
                  zz.instance_id,
                  zz.contract_or_warranty,
                  zz.type
                  FROM xxcs_inst_contr_and_warr_all_v zz
                  UNION ALL
                  SELECT
                         -111 contract_service_id,
                         NULL coverage,
                         NULL contract_number,
                         NULL instance_id,
                         NULL contract_or_warranty,
                         'T'||chr(38)||'M'              TYPE
                  FROM dual
                                                    )  CN,
                 (SELECT
                         ffvv.FLEX_VALUE,
                         ffvv.FLEX_VALUE_MEANING,
                         ffvv.DESCRIPTION,
                         ffvv.ENABLED_FLAG,
                         ffvv.START_DATE_ACTIVE,
                         ffvv.END_DATE_ACTIVE,
                         ffvv.FLEX_VALUE_SET_ID,
                         ffvv.FLEX_VALUE_ID,
                         ffvv.VALUE_CATEGORY,
                         ffvd.TIME_TO_VISIT,
                         ffvd.TIME_TO_INCOMPLETE,
                         ffvd.INCOMPLETE_TO_COMPLETE,
                         ffvd.TIME_TO_ASSIGN
                  FROM   FND_FLEX_VALUES_VL  ffvv,
                         fnd_flex_values_dfv ffvd
                  WHERE  ffvv.FLEX_VALUE_SET_ID = 1016067  --XXCS_MEASUREMENT_REPORT_V
                  AND    ffvv.ROW_ID = ffvd.row_id
                  AND    ffvv.ENABLED_FLAG = 'Y'
                  AND    SYSDATE BETWEEN nvl(ffvv.START_DATE_ACTIVE, SYSDATE) AND nvl(ffvv.END_DATE_ACTIVE, SYSDATE)
                       ) THRESHOLD
       WHERE     cn.contract_service_id IS NOT NULL
       AND       cn.type = THRESHOLD.FLEX_VALUE
                                          ) CONT,
       xxcs_regions_v                       region_gr -- 10/11/2011 Dalit A. Raviv
WHERE  rep.contract_service_id = cont.contract_service_id (+)
AND    rep.customer_product_id = nvl(cont.instance_id,rep.customer_product_id)
and    region_gr.CS_Region(+)  = rep.owner_cs_region;
