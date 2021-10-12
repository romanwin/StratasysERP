CREATE OR REPLACE VIEW XXCS_MTXX_AGING_MAPPING_V AS
SELECT
--------------------------------------------------------------------
--  name:            XXCS_MTXX_AGING_MAPPING_V
--  create by:       Vitaly
--  Revision:        1.2
--  creation date:   06/07/2010
--------------------------------------------------------------------
--  purpose :        Discoverer Report
--------------------------------------------------------------------
--  ver  date        name             desc
--  1.0  06/07/2001  Vitaly           initial build
--  1.1  31/01/2010  Roman            Fixed End_customer information
--  1.2  10/02/2011  Roman            Fixed Rowed dupliaction due to language in cst table
--------------------------------------------------------------------
       AGING_TAB.org_id,
       AGING_TAB.end_customer,
       AGING_TAB.party_id,
       AGING_TAB.party_name,
       AGING_TAB.serial_number,
       AGING_TAB.instance_id,
       AGING_TAB.family,
       AGING_TAB.item_category,
       AGING_TAB.cs_region,
       AGING_TAB.operating_unit_party,
       AGING_TAB.marketing_classification,
       AGING_TAB.printer_end_report_date,
       AGING_TAB.printer_start_report_date,
       AGING_TAB.printer_install_date,
       AGING_TAB.printer_active_end_date,
       AGING_TAB.parameter_date,
       AGING_TAB.parameter_sr_aging_group,
       AGING_TAB.printer,
       AGING_TAB.printer_description,
       AGING_TAB.printer_for_parameter,
       AGING_TAB.inventory_item_id,
       xxcs_mtb_report_pkg.get_factor_for_sr_statistics(AGING_TAB.printer_start_report_date,  ---report start date
                                                        AGING_TAB.printer_end_report_date,    ---report end date
                                                        AGING_TAB.printer_install_date,
                                                        AGING_TAB.printer_active_end_date)         factor,  --- effective IB
       decode(AGING_TAB.parameter_sr_aging_group,'0-3',  1/4,
                                                 '0-6',  1/2,
                                                 '0-9',  3/4,
                                                 '0-12', 1,
                                                 '3-6',  1/4,
                                                 '6-9',  1/4,
                                                 '9-12', 1/4,
                                                 '13-24',1)                   factor_year,
       AGING_TAB.incident_number,
       AGING_TAB.customer_id,
       AGING_TAB.customer_ticket_number   incident_number_priority,
       AGING_TAB.sr_type,
       AGING_TAB.incident_occurred_date,
       AGING_TAB.mtbc,
       AGING_TAB.mtbv,
       AGING_TAB.mtbd,
       AGING_TAB.mttr,
       AGING_TAB.uom_code,
       AGING_TAB.labor_hours  ---for mttr only
FROM
(SELECT ib.serial_number,
       ib.instance_id,
       ib.org_id,
       ib.end_customer,
       ib.party_id,
       ib.party_name,
       nvl(ib.family,'NO_PLATFORM')                          family,
       nvl(ib.item_category,'NO_TYPE')                       item_category,
       nvl(ib.cs_region,'NO_REGION')                         cs_region,
       nvl(ib.operating_unit_party,'NO_OPERATING_UNIT')      operating_unit_party,
       nvl(ib.marketing_classification,'NO_CLASSIFICATION')  marketing_classification,
       ib.printer_install_date,
       ib.printer_active_end_date,
       ib.parameter_date,
       ib.parameter_sr_aging_group,
       ib.printer,
       ib.printer_description,
       ib.printer_for_parameter,
       SR_TAB.mtbc,
       SR_TAB.mtbv,
       SR_TAB.mtbd,
       SR_TAB.mttr,
       SR_TAB.uom_code,
       SR_TAB.labor_hours,
       SR_TAB.incident_number,
       SR_TAB.customer_id,
       SR_TAB.customer_ticket_number,
       SR_TAB.sr_type,
       SR_TAB.incident_occurred_date,
       SR_TAB.inventory_item_id,
       decode(ib.parameter_sr_aging_group,'0-3',  ib.printer_install_date+ 365/4,
                                          '0-6',  ib.printer_install_date+ 365/2,
                                          '0-9',  ib.printer_install_date+(365/4)*3,
                                          '0-12', ib.printer_install_date+ 365,
                                          '3-6',  ib.printer_install_date+(365/4)*2,
                                          '6-9',  ib.printer_install_date+(365/4)*3,
                                          '9-12', ib.printer_install_date+ 365,
                                          '13-24',ib.printer_install_date+ 365*2)      printer_end_report_date,
       decode(ib.parameter_sr_aging_group,'0-3',  ib.printer_install_date+  0,
                                          '0-6',  ib.printer_install_date+  0,
                                          '0-9',  ib.printer_install_date+  0,
                                          '0-12', ib.printer_install_date+  0,
                                          '3-6',  ib.printer_install_date+ 365/4,
                                          '6-9',  ib.printer_install_date+(365/4)*2,
                                          '9-12', ib.printer_install_date+(365/4)*3,
                                          '13-24',ib.printer_install_date+ 365 )      printer_start_report_date
FROM (select ii.instance_id,
             ii.serial_number,
             to_number(hzp.attribute3)    org_id,
             cst.name   end_customer,
             hzp.party_id,
             hzp.party_name,
             mtc.segment2         family,
             mtc.segment3         item_category,
             decode(ii.attribute8,'FE South Region','FE',
                                  'FE North Region','FE',
                                   nvl(ii.attribute8,'No Region'))    cs_region,
             oup.name             operating_unit_party,
             p.marketing_classification,
             ---trunc(nvl(ii.install_date,   to_date('01-JAN-2000','DD-MON-YYYY')))   printer_install_date,
             ii.install_date                                                       printer_install_date,
             trunc(nvl(ii.active_end_date,to_date('31-JAN-2049','DD-MON-YYYY')))   printer_active_end_date,
             XXCS_SESSION_PARAM.get_session_param_date(1)                          parameter_date,
             XXCS_SESSION_PARAM.get_session_param_char(1)                          parameter_sr_aging_group,
             sr.incident_id,
             msi.segment1                               printer,
             msi.description                            printer_description,
             msi.segment1||'   -   '||msi.description   printer_for_parameter
      from   csi_item_instances                          ii,
            hz_parties                                   hzp,
            csi_systems_b                                  csb,
            csi_systems_tl                                 cst,
            (SELECT         hp.party_id,
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
              GROUP BY      hp.party_id)
                                                          P,
             hr_operating_units                           oup,
             mtl_item_categories                          mic,
             mtl_categories_b                             mtc,
             mtl_system_items_b                           msi,
             cs_incidents_all_b                           sr
      where
            ----------------------------------------------------------------------------------------
            /*XXCS_SESSION_PARAM.set_session_param_date(to_date('01-JAN-2010','DD-MON-YYYY'),1)=1 AND
            XXCS_SESSION_PARAM.set_session_param_char('0-3',1)=1 AND*/
            ----------------------------------------------------------------------------------------
             hzp.party_id          =ii.owner_party_id
      AND    csb.attribute2            =p.party_id(+)
      AND    to_number(hzp.attribute3) =oup.organization_id(+)
      AND    ii.system_id              =csb.system_id (+)
      AND    csb.system_id            = cst.system_id (+)
      AND    cst.language (+)         = 'US'
      and    ii.inventory_item_id  =mic.inventory_item_id
      and    mtc.category_id       =mic.category_id
      and    mic.inventory_item_id =msi.inventory_item_id
      and    mic.organization_id   =msi.organization_id
      and    mic.category_set_id   =1100000041
      and    mtc.enabled_flag      = 'Y'
      and    msi.organization_id   = 91
      and    mtc.attribute4='PRINTER'
      AND    ii.instance_id=sr.customer_product_id(+)
      AND    ii.install_date IS NOT NULL   ----Installed printers ONLY
      AND    trunc(ii.install_date)>=XXCS_SESSION_PARAM.get_session_param_date(2)   ---p_installation_date  parameter
      AND   (((XXCS_SESSION_PARAM.get_session_param_date(1)  ---p_date parameter
                  -ii.install_date) > 365/4     AND XXCS_SESSION_PARAM.get_session_param_char(1)='0-3')  ---p_sr_aging_droup   sr occurred date vs install date aging droup
                         OR
             ((XXCS_SESSION_PARAM.get_session_param_date(1)  ---p_date parameter
                  -ii.install_date) > 365/2     AND XXCS_SESSION_PARAM.get_session_param_char(1)='0-6')  ---p_sr_aging_droup   sr occurred date vs install date aging droup
                         OR
             ((XXCS_SESSION_PARAM.get_session_param_date(1)  ---p_date parameter
                  -ii.install_date) > (365/4)*3 AND XXCS_SESSION_PARAM.get_session_param_char(1)='0-9')  ---p_sr_aging_droup   sr occurred date vs install date aging droup
                         OR
             ((XXCS_SESSION_PARAM.get_session_param_date(1)  ---p_date parameter
                  -ii.install_date) > 365       AND XXCS_SESSION_PARAM.get_session_param_char(1)='0-12')  ---p_sr_aging_droup   sr occurred date vs install date aging droup
                         OR
             ((XXCS_SESSION_PARAM.get_session_param_date(1)  ---p_date parameter
                  -ii.install_date) > (365/4)*2 AND XXCS_SESSION_PARAM.get_session_param_char(1)='3-6')  ---p_sr_aging_droup   sr occurred date vs install date aging droup
                         OR
             ((XXCS_SESSION_PARAM.get_session_param_date(1)  ---p_date parameter
                  -ii.install_date) > (365/4)*3 AND XXCS_SESSION_PARAM.get_session_param_char(1)='6-9')  ---p_sr_aging_droup   sr occurred date vs install date aging droup
                         OR
             ((XXCS_SESSION_PARAM.get_session_param_date(1)  ---p_date parameter
                  -ii.install_date) > 365       AND XXCS_SESSION_PARAM.get_session_param_char(1)='9-12') ---p_sr_aging_droup   sr occurred date vs install date aging droup
                         OR
             ((XXCS_SESSION_PARAM.get_session_param_date(1)  ---p_date parameter
                  -ii.install_date) > 365*2     AND XXCS_SESSION_PARAM.get_session_param_char(1)='13-24') ---p_sr_aging_droup   sr occurred date vs install date aging droup
            )
       AND   (sr.incident_occurred_date IS NULL  --- No SR for this Instance_Id (printer)
       OR
           ( ((sr.incident_occurred_date - ii.install_date) BETWEEN 0         AND 365/4
                             AND XXCS_SESSION_PARAM.get_session_param_char(1)='0-3')  ---p_sr_aging_droup   sr occurred date vs install date aging droup
                         OR
             ((sr.incident_occurred_date - ii.install_date) BETWEEN 0         AND 365/2
                             AND XXCS_SESSION_PARAM.get_session_param_char(1)='0-6')  ---p_sr_aging_droup   sr occurred date vs install date aging droup
                         OR
             ((sr.incident_occurred_date - ii.install_date) BETWEEN 0         AND (365/4)*3
                             AND XXCS_SESSION_PARAM.get_session_param_char(1)='0-9')  ---p_sr_aging_droup   sr occurred date vs install date aging droup
                         OR
             ((sr.incident_occurred_date - ii.install_date) BETWEEN 0         AND 365
                             AND XXCS_SESSION_PARAM.get_session_param_char(1)='0-12')  ---p_sr_aging_droup   sr occurred date vs install date aging droup
                         OR
             ((sr.incident_occurred_date - ii.install_date) BETWEEN 365/4     AND (365/4)*2
                             AND XXCS_SESSION_PARAM.get_session_param_char(1)='3-6')  ---p_sr_aging_droup   sr occurred date vs install date aging droup
                         OR
             ((sr.incident_occurred_date - ii.install_date) BETWEEN (365/4)*2 AND (365/4)*3
                             AND XXCS_SESSION_PARAM.get_session_param_char(1)='6-9')  ---p_sr_aging_droup   sr occurred date vs install date aging droup
                         OR
             ((sr.incident_occurred_date - ii.install_date) BETWEEN (365/4)*3 AND 365
                             AND XXCS_SESSION_PARAM.get_session_param_char(1)='9-12')  ---p_sr_aging_droup   sr occurred date vs install date aging droup
                         OR
             ((sr.incident_occurred_date - ii.install_date) BETWEEN 365       AND 365*2
                             AND XXCS_SESSION_PARAM.get_session_param_char(1)='13-24')  ---p_sr_aging_droup   sr occurred date vs install date aging droup
           )))       IB,
    (SELECT   srmn.incident_id,
              srmn.incident_number,
              srmn.customer_id,
              srmn.incident_occurred_date,
              srmn.Incident_Number_Priority     customer_ticket_number,
              srmn.inventory_item_id,
              srmn.sr_type,
              srmn.mtbc,
              srmn.mtbv,
              srmn.mtbd,
              srmn.mttr,
              srmn.instance_id     customer_product_id,
              'HR'      uom_code,
              srmn.labor_hours
      FROM   XXCS_MTXX_SR_MAPPING_NEW_V   srmn
                                 )    SR_TAB
WHERE  nvl(IB.incident_id,-777)=SR_TAB.incident_id (+)
                       ) AGING_TAB;

