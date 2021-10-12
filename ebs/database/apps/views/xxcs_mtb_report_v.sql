CREATE OR REPLACE VIEW XXCS_MTB_REPORT_V AS
SELECT
--------------------------------------------------------------------
--  name:            XXCS_MTB_REPORT_V
--  create by:       Vitaly.K
--  Revision:        1.6
--  creation date:   01/09/2009
--------------------------------------------------------------------
--  purpose :        Disco Report
--------------------------------------------------------------------
--  ver  date        name             desc
--  1.0  01/09/2009  Vitaly.K         initial build
--  1.1  04/01/2010  Yoram Zamir      add customer name
--  1.2  07/02/2009  Yoram Zamir      add end_customer
--  1.3  07/03/2010  Vitaly --        Source for Region was changed to CSI_ITEM_INSTANCES.attribute8
--  1.4  09/03/2010  Vitaly           Operating_Unit was added
--  1.5  10/06/2010  Vitaly           Org_id and party_id fields were added
--  1.6  13/07/2010  Yoram Zamir      Group by removed, Cuurent contract information was added
--------------------------------------------------------------------
       STATISTICS_TAB.org_id,
       STATISTICS_TAB.operating_unit_party,
       STATISTICS_TAB.party_id,
       STATISTICS_TAB.serial_number,
       STATISTICS_TAB.customer,
       STATISTICS_TAB.end_customer,
       STATISTICS_TAB.printer,
       STATISTICS_TAB.printer_description,
       STATISTICS_TAB.family,
       STATISTICS_TAB.item_category,
       STATISTICS_TAB.cs_region,
       STATISTICS_TAB.printer_install_date,
       STATISTICS_TAB.printer_active_end_date,
       STATISTICS_TAB.report_days                    printer_report_days,
       STATISTICS_TAB.uom_code,
       STATISTICS_TAB.contract_or_warranty,
       STATISTICS_TAB.contract_number,
       STATISTICS_TAB.coverage,
       STATISTICS_TAB.service,
       STATISTICS_TAB.contract_type,
       round((nvl(STATISTICS_TAB.labor_hours,0)),2)  labor_hours, --- for mttr only
       nvl(STATISTICS_TAB.mtbc    ,0)                mtbc,
       nvl(STATISTICS_TAB.mtbv    ,0)                mtbv,
       nvl(STATISTICS_TAB.mtbd    ,0)                mtbd,
       nvl(STATISTICS_TAB.mttr    ,0)                mttr,
       decode((nvl(STATISTICS_TAB.mttr,0)) ,0,0, round((nvl(STATISTICS_TAB.labor_hours,0)),2)/(nvl(STATISTICS_TAB.mttr,0)))  hr_per_sr_mttr,
       STATISTICS_TAB.factor,
       decode(STATISTICS_TAB.factor,0,0,round((nvl(STATISTICS_TAB.mtbc,0))/STATISTICS_TAB.factor,2))     mtbc_f,
       decode(STATISTICS_TAB.factor,0,0,round((nvl(STATISTICS_TAB.mtbv,0))/STATISTICS_TAB.factor,2))     mtbv_f,
       decode(STATISTICS_TAB.factor,0,0,round((nvl(STATISTICS_TAB.mtbd,0))/STATISTICS_TAB.factor,2))     mtbd_f,
       decode(STATISTICS_TAB.factor,0,0,round((nvl(STATISTICS_TAB.mttr,0))/STATISTICS_TAB.factor,2))     mttr_f,
       -----STATISTICS_TAB.report_start_counter_reading,
       -----STATISTICS_TAB.report_end_counter_reading,
       CASE
           WHEN STATISTICS_TAB.report_end_counter_reading IS NULL OR STATISTICS_TAB.report_start_counter_reading IS NULL THEN
              NULL
           ELSE
              STATISTICS_TAB.report_end_counter_reading-STATISTICS_TAB.report_start_counter_reading
           END                                                      COUNTER_READING_CHANGES,
       STATISTICS_TAB.last_counter_reading,
       CASE
           WHEN STATISTICS_TAB.report_end_counter_reading IS NULL OR STATISTICS_TAB.report_start_counter_reading IS NULL THEN
              NULL
           ELSE
              decode((nvl(STATISTICS_TAB.mtbc    ,0)),0,0,
                   (STATISTICS_TAB.report_end_counter_reading-STATISTICS_TAB.report_start_counter_reading)
                                         /(nvl(STATISTICS_TAB.mtbc    ,0)))
           END                                                      PRINTINGS_PER_SR_MTBC,
       CASE
           WHEN STATISTICS_TAB.report_end_counter_reading IS NULL OR STATISTICS_TAB.report_start_counter_reading IS NULL THEN
              NULL
           ELSE
              decode((nvl(STATISTICS_TAB.mtbv    ,0)),0,0,
                   (STATISTICS_TAB.report_end_counter_reading-STATISTICS_TAB.report_start_counter_reading)
                                         /(nvl(STATISTICS_TAB.mtbv    ,0)))
           END                                                      PRINTINGS_PER_SR_MTBV,
       CASE
           WHEN STATISTICS_TAB.report_end_counter_reading IS NULL OR STATISTICS_TAB.report_start_counter_reading IS NULL THEN
              NULL
           ELSE
              decode((nvl(STATISTICS_TAB.mtbd    ,0)),0,0,
                   (STATISTICS_TAB.report_end_counter_reading-STATISTICS_TAB.report_start_counter_reading)
                                         /(nvl(STATISTICS_TAB.mtbd    ,0)))
           END                                                      PRINTINGS_PER_SR_MTBD
FROM
(SELECT
       mt.org_id,
       mt.party_id,
       mt.serial_number,
       mt.customer_name        customer,
       mt.end_customer ,
       mt.printer,
       mt.printer_description,
       mt.platform             family,
       mt.type                 item_category,
       mt.cs_region,
       mt.printer_install_date,
       mt.printer_active_end_date,
       mt.operating_unit_party,
       mt.mtbc,
       mt.mtbv,
       mt.mtbd,
       mt.mttr,
       mt.uom_code,
       mt.report_days,
       mt.labor_hours,
       mt.effective_ib         factor,
       cont.contract_or_warranty,
       cont.contract_number,
       cont.coverage,
       cont.service,
       cont.contract_type,
       xxcs_mtb_report_pkg.get_counter_reading(XXCS_SESSION_PARAM.get_session_param_date(1),  ---p_from_date
                                               mt.serial_number)      report_start_counter_reading,
       xxcs_mtb_report_pkg.get_counter_reading(XXCS_SESSION_PARAM.get_session_param_date(2),  ---p_to_date
                                               mt.serial_number)      report_end_counter_reading,
       xxcs_mtb_report_pkg.get_last_counter_reading(mt.serial_number) last_counter_reading
FROM   XXCS_MTXX_REPORT_DETAILS_V    mt,  ---Security by OU and party inside
       (SELECT
                 active_contracts.instance_id,
                 active_contracts.party_id,
                 active_contracts.contract_or_warranty,
                 active_contracts.contract_number,
                 active_contracts.coverage,
                 active_contracts.service,
                 active_contracts.contract_type
        FROM
                (SELECT
                       zz.instance_id,
                       zz.party_id,
                       zz.contract_or_warranty,
                       zz.contract_number,
                       zz.coverage,
                       zz.service,
                       zz.type contract_type,
                       DENSE_RANK() OVER (PARTITION BY zz.instance_id ORDER BY zz.line_end_date DESC) rank
                FROM   XXCS_INST_CONTR_AND_WARR_ALL_V zz
                WHERE  zz.status = 'ACTIVE'
                AND    zz.line_status ='ACTIVE'
                AND    SYSDATE BETWEEN zz.line_start_date AND nvl(zz.line_date_terminated, zz.line_end_date)
                               ) active_contracts
        WHERE active_contracts.rank = 1 ) cont
WHERE  mt.party_id      = cont.party_id (+)
AND    mt.instance_id   = cont.instance_id (+)
                    )   STATISTICS_TAB;

