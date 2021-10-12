CREATE OR REPLACE VIEW XXCS_MTB_REPORT_2_V AS
SELECT
--------------------------------------------------------------------
--  name:            XXCS_MTB_REPORT_2_V
--  create by:       Yoram Zamir
--  Revision:        1.2
--  creation date:   15/03/2010
--------------------------------------------------------------------
--  purpose :        Discoverer Report
--------------------------------------------------------------------
--  ver  date        name             desc
--  1.0  15/03/2010  Yoram Zamir      initial build
--  1.1  18/03/2010  Vitaly           sales_channel_code was added
--  1.2  21/03/2010  Vitaly           marketing_classification was added
--------------------------------------------------------------------
       nvl(PAT_TAB.sales_channel_code,'NO SALES CHANNEL')  sales_channel_code,
       PAT_TAB.operating_unit_party,
       PAT_TAB.marketing_classification,
       PAT_TAB.cs_region,
       PAT_TAB.family,
       PAT_TAB.item_category,
       PAT_TAB.uom_code,
       PAT_TAB.labor_hours,--- for mttr only
       PAT_TAB.mtbc,
       PAT_TAB.mtbv,
       PAT_TAB.mtbd,
       PAT_TAB.mttr,
       PAT_TAB.hr_per_sr_mttr,
       PAT_TAB.factor,
       PAT_TAB.mtbc_f,  ---normalized to report period
       PAT_TAB.mtbv_f,  ---normalized to report period
       PAT_TAB.mtbd_f,  ---normalized to report period
       PAT_TAB.mttr_f,  ---normalized to report period
       PAT_TAB.mtbc_f_per_printer,  ---normalized to report period
       PAT_TAB.mtbv_f_per_printer,  ---normalized to report period
       PAT_TAB.mtbd_f_per_printer,  ---normalized to report period
       PAT_TAB.mttr_f_per_printer,  ---normalized to report period
       PAT_TAB.factor_year,
       PAT_TAB.mtbc_f_y,  ---normalized to year
       PAT_TAB.mtbv_f_Y,  ---normalized to year
       PAT_TAB.mtbd_f_y,  ---normalized to year
       PAT_TAB.mttr_f_y,  ---normalized to year
       PAT_TAB.mtbc_f_y_per_printer,  ---normalized to year
       PAT_TAB.mtbv_f_Y_per_printer,  ---normalized to year
       PAT_TAB.mtbd_f_y_per_printer,  ---normalized to year
       PAT_TAB.mttr_f_y_per_printer,  ---normalized to year
       PAT_TAB.mtbc_days,
       PAT_TAB.mtbv_days,
       PAT_TAB.mtbd_days,
       PAT_TAB.mttr_days,
       PAT_TAB.Number_of_printers,

       DECODE(PAT_TAB.mtbc_f_y_per_printer, 0,0,365/PAT_TAB.mtbc_f_y_per_printer)  avg_mtbc_days,
       DECODE(PAT_TAB.mtbv_f_y_per_printer, 0,0,365/PAT_TAB.mtbv_f_y_per_printer)  avg_mtbv_days,
       DECODE(PAT_TAB.mtbd_f_y_per_printer, 0,0,365/PAT_TAB.mtbd_f_y_per_printer)  avg_mtbd_days,
       DECODE(PAT_TAB.mttr_f_y_per_printer, 0,0,365/PAT_TAB.mttr_f_y_per_printer)  avg_mttr_days,

       --------------mtbc-------------------
       DECODE(PAT_TAB.mtbc_f_y_per_printer,0,0,
       365/sum(PAT_TAB.mtbc_f_y_per_printer) over
          (partition by PAT_TAB.sales_channel_code||PAT_TAB.operating_unit_party||PAT_TAB.family))      avg_mtbc_days_family,
       DECODE(PAT_TAB.mtbc_f_y_per_printer,0,0,
       365/sum(PAT_TAB.mtbc_f_y_per_printer) over
          (partition by PAT_TAB.sales_channel_code||PAT_TAB.operating_unit_party ||PAT_TAB.cs_region))  avg_mtbc_days_region,
       DECODE(PAT_TAB.mtbc_f_y_per_printer,0,0,
       365/sum(PAT_TAB.mtbc_f_y_per_printer) over
          (partition by PAT_TAB.sales_channel_code||PAT_TAB.operating_unit_party ||PAT_TAB.marketing_classification))
                                                                                                        avg_mtbc_days_market_class,
       --------------mtbv-------------------
       DECODE(PAT_TAB.mtbv_f_y_per_printer,0,0,
       365/sum(PAT_TAB.mtbv_f_y_per_printer) over
          (partition by PAT_TAB.sales_channel_code||PAT_TAB.operating_unit_party||PAT_TAB.family))      avg_mtbv_days_family,
       DECODE(PAT_TAB.mtbv_f_y_per_printer,0,0,
       365/sum(PAT_TAB.mtbv_f_y_per_printer) over
          (partition by PAT_TAB.sales_channel_code||PAT_TAB.operating_unit_party ||PAT_TAB.cs_region))  avg_mtbv_days_region,
       DECODE(PAT_TAB.mtbv_f_y_per_printer,0,0,
       365/sum(PAT_TAB.mtbv_f_y_per_printer) over
          (partition by PAT_TAB.sales_channel_code||PAT_TAB.operating_unit_party ||PAT_TAB.marketing_classification))
                                                                                                        avg_mtbv_days_market_class,
       --------------mtbd-------------------
       DECODE(PAT_TAB.mtbd_f_y_per_printer,0,0,
       365/sum(PAT_TAB.mtbd_f_y_per_printer) over
          (partition by PAT_TAB.sales_channel_code||PAT_TAB.operating_unit_party ||PAT_TAB.family))     avg_mtbd_days_family,
       DECODE(PAT_TAB.mtbd_f_y_per_printer,0,0,
       365/sum(PAT_TAB.mtbd_f_y_per_printer) over
          (partition by PAT_TAB.sales_channel_code||PAT_TAB.operating_unit_party ||PAT_TAB.cs_region )) avg_mtbd_days_region,
       DECODE(PAT_TAB.mtbd_f_y_per_printer,0,0,
       365/sum(PAT_TAB.mtbd_f_y_per_printer) over
          (partition by PAT_TAB.sales_channel_code||PAT_TAB.operating_unit_party ||PAT_TAB.marketing_classification ))
                                                                                                        avg_mtbd_days_market_class,
       --------------mttr-------------------
       DECODE(PAT_TAB.mttr_f_y_per_printer,0,0,
       365/sum(PAT_TAB.mttr_f_y_per_printer) over
          (partition by PAT_TAB.sales_channel_code||PAT_TAB.operating_unit_party ||PAT_TAB.family))     avg_mttr_days_family,
       DECODE(PAT_TAB.mttr_f_y_per_printer,0,0,
       365/sum(PAT_TAB.mttr_f_y_per_printer) over
          (partition by PAT_TAB.sales_channel_code||PAT_TAB.operating_unit_party || PAT_TAB.cs_region)) avg_mttr_days_region,
       DECODE(PAT_TAB.mttr_f_y_per_printer,0,0,
       365/sum(PAT_TAB.mttr_f_y_per_printer) over
          (partition by PAT_TAB.sales_channel_code||PAT_TAB.operating_unit_party || PAT_TAB.marketing_classification))
                                                                                                        avg_mttr_days_market_class


FROM ( SELECT
       TOTAL_TAB.operating_unit_party,
       TOTAL_TAB.marketing_classification,
       nvl(TOTAL_TAB.cs_region, 'No Region')         cs_region,
       TOTAL_TAB.family,
       TOTAL_TAB.item_category,
       TOTAL_TAB.uom_code,
       TOTAL_TAB.sales_channel_code,
       sum(TOTAL_TAB.labor_hours)                    labor_hours,--- for mttr only
       sum(TOTAL_TAB.mtbc)                           mtbc,
       sum(TOTAL_TAB.mtbv)                           mtbv,
       sum(TOTAL_TAB.mtbd)                           mtbd,
       sum(TOTAL_TAB.mttr)                           mttr,
       sum(TOTAL_TAB.hr_per_sr_mttr)                 hr_per_sr_mttr,
       sum(TOTAL_TAB.factor)                         factor,
       sum(TOTAL_TAB.mtbc_f)                         mtbc_f,  ---normalized to report period
       sum(TOTAL_TAB.mtbv_f)                         mtbv_f,  ---normalized to report period
       sum(TOTAL_TAB.mtbd_f)                         mtbd_f,  ---normalized to report period
       sum(TOTAL_TAB.mttr_f)                         mttr_f,  ---normalized to report period
       sum(TOTAL_TAB.mtbc_f)/COUNT(TOTAL_TAB.instance_id) mtbc_f_per_printer,  ---normalized to report period
       sum(TOTAL_TAB.mtbv_f)/COUNT(TOTAL_TAB.instance_id) mtbv_f_per_printer,  ---normalized to report period
       sum(TOTAL_TAB.mtbd_f)/COUNT(TOTAL_TAB.instance_id) mtbd_f_per_printer,  ---normalized to report period
       sum(TOTAL_TAB.mttr_f)/COUNT(TOTAL_TAB.instance_id) mttr_f_per_printer,  ---normalized to report period
       MAX(TOTAL_TAB.factor_year)                    factor_year,
       sum(TOTAL_TAB.mtbc_f_y)                       mtbc_f_y,  ---normalized to year
       sum(TOTAL_TAB.mtbv_f_Y)                       mtbv_f_Y,  ---normalized to year
       sum(TOTAL_TAB.mtbd_f_y)                       mtbd_f_y,  ---normalized to year
       sum(TOTAL_TAB.mttr_f_y)                       mttr_f_y,  ---normalized to year
       sum(TOTAL_TAB.mtbc_f_y)/COUNT(TOTAL_TAB.instance_id)  mtbc_f_y_per_printer,  ---normalized to year
       sum(TOTAL_TAB.mtbv_f_Y)/COUNT(TOTAL_TAB.instance_id)  mtbv_f_Y_per_printer,  ---normalized to year
       sum(TOTAL_TAB.mtbd_f_y)/COUNT(TOTAL_TAB.instance_id)  mtbd_f_y_per_printer,  ---normalized to year
       sum(TOTAL_TAB.mttr_f_y)/COUNT(TOTAL_TAB.instance_id)  mttr_f_y_per_printer,  ---normalized to year
       sum(TOTAL_TAB.mtbc_days)                      mtbc_days,
       sum(TOTAL_TAB.mtbv_days)                      mtbv_days,
       sum(TOTAL_TAB.mtbd_days)                      mtbd_days,
       sum(TOTAL_TAB.mttr_days)                      mttr_days,
       COUNT(TOTAL_TAB.instance_id)                Number_of_printers
FROM
(SELECT
       STAT_TAB.operating_unit_party,
       STAT_TAB.marketing_classification,
       STAT_TAB.serial_number,
       STAT_TAB.instance_id,
       STAT_TAB.family,
       STAT_TAB.item_category,
       STAT_TAB.cs_region,
       STAT_TAB.uom_code,
       STAT_TAB.labor_hours,  --- for mttr only
       STAT_TAB.mtbc,
       STAT_TAB.mtbv,
       STAT_TAB.mtbd,
       STAT_TAB.mttr,
       STAT_TAB.hr_per_sr_mttr,
       STAT_TAB.factor,
       STAT_TAB.mtbc_f,  ---normalized to report period
       STAT_TAB.mtbv_f,  ---normalized to report period
       STAT_TAB.mtbd_f,  ---normalized to report period
       STAT_TAB.mttr_f,  ---normalized to report period
       STAT_TAB.factor_year,
       STAT_TAB.mtbc_f*STAT_TAB.factor_year   mtbc_f_y,  ---normalized to year
       STAT_TAB.mtbv_f*STAT_TAB.factor_year   mtbv_f_Y,  ---normalized to year
       STAT_TAB.mtbd_f*STAT_TAB.factor_year   mtbd_f_y,  ---normalized to year
       STAT_TAB.mttr_f*STAT_TAB.factor_year   mttr_f_y,  ---normalized to year
       decode(STAT_TAB.mtbc_f*STAT_TAB.factor_year,0,0,365/(STAT_TAB.mtbc_f*STAT_TAB.factor_year))   mtbc_days,
       decode(STAT_TAB.mtbv_f*STAT_TAB.factor_year,0,0,365/(STAT_TAB.mtbv_f*STAT_TAB.factor_year))   mtbv_days,
       decode(STAT_TAB.mtbd_f*STAT_TAB.factor_year,0,0,365/(STAT_TAB.mtbd_f*STAT_TAB.factor_year))   mtbd_days,
       decode(STAT_TAB.mttr_f*STAT_TAB.factor_year,0,0,365/(STAT_TAB.mttr_f*STAT_TAB.factor_year))   mttr_days,
       STAT_TAB.sales_channel_code  ----====================================
FROM(SELECT
       STATISTICS_TAB.operating_unit_party,
       STATISTICS_TAB.marketing_classification,
       STATISTICS_TAB.serial_number,
       STATISTICS_TAB.instance_id,
       STATISTICS_TAB.family,
       STATISTICS_TAB.item_category,
       STATISTICS_TAB.cs_region,
       STATISTICS_TAB.uom_code,
       round(SUM(nvl(STATISTICS_TAB.labor_hours,0)),2)     labor_hours,  --- for mttr only
       SUM(nvl(STATISTICS_TAB.mtbc    ,0))     mtbc,
       SUM(nvl(STATISTICS_TAB.mtbv    ,0))     mtbv,
       SUM(nvl(STATISTICS_TAB.mtbd    ,0))     mtbd,
       SUM(nvl(STATISTICS_TAB.mttr    ,0))     mttr,
       decode(SUM(nvl(STATISTICS_TAB.mttr,0)) ,0,0, round(SUM(nvl(STATISTICS_TAB.labor_hours,0)),2)/SUM(nvl(STATISTICS_TAB.mttr,0)))  hr_per_sr_mttr,
       STATISTICS_TAB.factor,
       decode(STATISTICS_TAB.factor,0,0,SUM(nvl(STATISTICS_TAB.mtbc,0))/STATISTICS_TAB.factor)     mtbc_f,
       decode(STATISTICS_TAB.factor,0,0,SUM(nvl(STATISTICS_TAB.mtbv,0))/STATISTICS_TAB.factor)     mtbv_f,
       decode(STATISTICS_TAB.factor,0,0,SUM(nvl(STATISTICS_TAB.mtbd,0))/STATISTICS_TAB.factor)     mtbd_f,
       decode(STATISTICS_TAB.factor,0,0,SUM(nvl(STATISTICS_TAB.mttr,0))/STATISTICS_TAB.factor)     mttr_f,
       STATISTICS_TAB.factor_year,
       STATISTICS_TAB.sales_channel_code
FROM
(SELECT ib.serial_number,
       ib.instance_id,
       ib.family,
       ib.item_category,
       ib.cs_region,
       ib.operating_unit_party,
       ib.marketing_classification,
       SR_TAB.sales_channel_code,
       ---SR_TAB.mtbc_flag,
       case
           when SR_TAB.mtbc_flag='Y' THEN 1
           when SR_TAB.mtbc_flag='N' THEN 0
           when SR_TAB.mtbc_flag='C' AND SR_TAB.travel_hours_flag='Y' THEN 1
           else 0
           end         mtbc,
       ---SR_TAB.mtbv_flag,
       case
           when SR_TAB.mtbv_flag='Y' THEN 1
           when SR_TAB.mtbv_flag='N' THEN 0
           when SR_TAB.mtbv_flag='C' AND SR_TAB.travel_hours_flag='Y' THEN 1
           else 0
           end         mtbv,
       ---SR_TAB.mtbd_flag,
       case
           when SR_TAB.mtbd_flag='Y' THEN 1
           when SR_TAB.mtbd_flag='N' THEN 0
           when SR_TAB.mtbd_flag='C' AND SR_TAB.travel_hours_flag='Y' THEN 1
           else 0
           end         mtbd,
       ---SR_TAB.mttr_flag,
       case
           when SR_TAB.mttr_flag='Y' THEN 1
           when SR_TAB.mttr_flag='N' THEN 0
           when SR_TAB.mttr_flag='C' AND SR_TAB.travel_hours_flag='Y' THEN 1
           else 0
           end         mttr,
       ----SR_TAB.travel_hours_flag,
       SR_TAB.uom_code,
       SR_TAB.labor_hours,
       CASE
          WHEN ib.printer_active_end_date< XXCS_SESSION_PARAM.get_session_param_date(2) THEN
               ib.printer_active_end_date
          ELSE
               XXCS_SESSION_PARAM.get_session_param_date(2)  ---p_to_date
          END      printer_end_report_date,
       CASE
          WHEN ib.printer_install_date   > XXCS_SESSION_PARAM.get_session_param_date(1) THEN
               ib.printer_install_date
          ELSE
               XXCS_SESSION_PARAM.get_session_param_date(1)  ---p_from_date
          END      printer_start_report_date,
       xxcs_mtb_report_pkg.get_factor_for_sr_statistics(XXCS_SESSION_PARAM.get_session_param_date(1),  ---p_from_date
                                                        XXCS_SESSION_PARAM.get_session_param_date(2),  ---p_to_date
                                                        ib.printer_install_date,
                                                        ib.printer_active_end_date)    factor,
       decode(XXCS_SESSION_PARAM.get_session_param_date(2)  ---p_to_date
                     - XXCS_SESSION_PARAM.get_session_param_date(1)  ---p_from_date
                       +1,0,0,
                       365/(XXCS_SESSION_PARAM.get_session_param_date(2)  ---p_to_date
                             - XXCS_SESSION_PARAM.get_session_param_date(1)  ---p_from_date
                              +1)                                                 )   factor_year
FROM (select ii.instance_id,
             ii.serial_number,
             mtc.segment2         family,
             mtc.segment3         item_category,
             ii.attribute8        cs_region,
             oup.name             operating_unit_party,
             p.marketing_classification,
             trunc(nvl(ii.install_date,   to_date('01-JAN-2000','DD-MON-YYYY')))   printer_install_date,
             trunc(nvl(ii.active_end_date,to_date('31-JAN-2049','DD-MON-YYYY')))   printer_active_end_date
      from   csi_item_instances                           ii,
             csi_systems_v                                csv,
             ----hz_parties                                   p,
            (SELECT         ----hp.party_id,
                            to_number(hp.attribute3)   org_id,
                            hp.party_name,
                            --ca.class_code,
                            MAX(lu.MEANING)   marketing_classification
              FROM          hz_parties hp,
                            hz_code_assignments ca,
                            hz_classcode_relations_v lu
              WHERE         hp.party_id = ca.owner_table_id (+) AND
                            ca.class_category =  'Objet Business Type' AND
                            hp.party_type = 'ORGANIZATION' AND
                            ca.status = 'A' AND
                            hp.status = 'A' AND
                            SYSDATE BETWEEN ca.start_date_active AND nvl(ca.end_date_active, SYSDATE) AND
                            lu.lookup_type = 'Objet Business Type' AND
                            lu.language = 'US' AND
                            ca.class_code = lu.LOOKUP_CODE
              GROUP BY ----hp.party_id,
                       to_number(hp.attribute3),
                       hp.party_name)
                                                          P,
             hr_operating_units                           oup,
             mtl_item_categories                          mic,
             mtl_categories_b                             mtc,
             mtl_system_items_b                           msi
      where  ----p.party_id =                                 ii.owner_party_id
             csv.name              =p.party_name(+)
      AND    p.org_id              =oup.organization_id(+)
      AND    ii.system_id          =csv.system_id (+)
      and    ii.inventory_item_id  =mic.inventory_item_id
      and    mtc.category_id       =mic.category_id
      and    mic.inventory_item_id =msi.inventory_item_id
      and    mic.organization_id   =msi.organization_id
      and    mic.category_set_id   =1100000041
      and    mtc.enabled_flag      = 'Y'
      and    msi.organization_id   = 91
      and    mtc.attribute4='PRINTER'
                           )       IB,
    (SELECT   sr.incident_id,
              sr.incident_number,
              sr.customer_ticket_number,
              srt.NAME    sr_type,
              ca.sales_channel_code,
              fval.attribute1    mtbc_flag,
              fval.attribute2    mtbv_flag,
              fval.attribute3    mtbd_flag,
              fval.attribute4    mttr_flag,
              sr.customer_product_id,
              nvl(LABOR_HOURS_TAB.Travel_Hours_Flag,'N')    travel_hours_flag,
              'HR'      uom_code,
              decode(fval.attribute4,'Y',1,   -------mttr-flag
                                     'C',decode(nvl(LABOR_HOURS_TAB.Travel_Hours_Flag,'N'),'Y',1,0),
                                          0)*
              decode(LABOR_HOURS_TAB.uom_code,'HR',LABOR_HOURS_TAB.labor_hours,
                     xxcs_mtb_report_pkg.convert_duration_uom(LABOR_HOURS_TAB.uom_code,'HR',LABOR_HOURS_TAB.labor_hours))   labor_hours
      FROM   cs_incidents_all_b   sr,
             hz_cust_accounts     ca,
             CS_INCIDENT_TYPES    srt,
             FND_FLEX_VALUES_VL   fval,
             (SELECT h.incident_id,
                     t.uom_code,
                     SUM(decode(t.inventory_item_id,3023,decode(bp.name,'On-Site Support',t.quantity,0)
                                                                    ,0))    labor_hours,
                     MAX(decode(t.inventory_item_id,3024,'Y',''))           travel_hours_flag
              FROM   CSF_DEBRIEF_LAB_LINES_V    t,
                     CS_BUSINESS_PROCESSES      bp,
                     CSF_DEBRIEF_HEADERS_V      h
              WHERE  h.debrief_header_id=t.debrief_header_id
              AND    h.organization_id=91
              AND    t.business_process_id=bp.business_process_id
              GROUP BY h.incident_id,
                       t.uom_code
                                 )   LABOR_HOURS_TAB

      WHERE
            ----------------------------------------------------------------------------------------
            /*XXCS_SESSION_PARAM.set_session_param_date(to_date('01-JAN-2009','DD-MON-YYYY'),1)=1 AND
            XXCS_SESSION_PARAM.set_session_param_date(to_date('31-DEC-2010','DD-MON-YYYY'),2)=1 AND*/
            ----------------------------------------------------------------------------------------
            sr.account_id=ca.cust_account_id(+)
      AND   fval.VALUE_CATEGORY = 'XXCS_MTB_SR_TYPES'
      AND   fval.ENABLED_FLAG = 'Y'
      AND   trunc(SYSDATE) BETWEEN trunc(nvl(fval.START_DATE_ACTIVE, SYSDATE-1)) AND trunc(nvl(fval.end_DATE_ACTIVE, SYSDATE+1))
      and   srt.NAME= fval.FLEX_VALUE   ----SR TYPE
      and   sr.incident_id=LABOR_HOURS_TAB.incident_id(+)
      and   trunc(SYSDATE) BETWEEN trunc(nvl(srt.START_DATE_ACTIVE, SYSDATE-1)) AND trunc(nvl(srt.end_DATE_ACTIVE, SYSDATE+1))
      and   sr.INCIDENT_TYPE_ID=srt.INCIDENT_TYPE_ID
      --AND   SR.customer_ticket_number IS NOT NULL --------******************
      and   sr.incident_occurred_date between XXCS_SESSION_PARAM.get_session_param_date(1)  ---p_from_date
                                          and XXCS_SESSION_PARAM.get_session_param_date(2)  ---p_to_date
                                  )    SR_TAB
WHERE ib.instance_id=SR_TAB.customer_product_id (+)
                        )   STATISTICS_TAB
GROUP BY STATISTICS_TAB.operating_unit_party,
         STATISTICS_TAB.marketing_classification,
         STATISTICS_TAB.serial_number,
         STATISTICS_TAB.instance_id,
         STATISTICS_TAB.family,
         STATISTICS_TAB.item_category,
         STATISTICS_TAB.cs_region,
         STATISTICS_TAB.uom_code,
         STATISTICS_TAB.factor,
         STATISTICS_TAB.sales_channel_code
                   )  STAT_TAB
                                 ) TOTAL_TAB
GROUP BY
             TOTAL_TAB.operating_unit_party,
             TOTAL_TAB.marketing_classification,
             nvl(TOTAL_TAB.cs_region, 'No Region'),
             TOTAL_TAB.family,
             TOTAL_TAB.item_category,
             TOTAL_TAB.uom_code,
             TOTAL_TAB.sales_channel_code
                                      ) PAT_TAB;

