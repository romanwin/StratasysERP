CREATE OR REPLACE VIEW APPS.XXCS_TASKS_ALL_V AS
SELECT
--------------------------------------------------------------------
--  name:            XXCS_TASKS_ALL_V
--  create by:       Yoram Zamir
--  Revision:        1.4
--  creation date:   17/02/2010
--------------------------------------------------------------------
--  purpose :       Discoverer Reports
--------------------------------------------------------------------
--  ver  date        name             desc
--  1.0  17/02/2010  Yoram Zamir      initial build
--  1.1  09/03/2010  Vitaly           Sales_Channel was added
--  1.2  15/06/2010  Vitaly           Security by OU and party was added (old security removed)
--  1.3  07/08/2011  Roman            Added task_assignment_date, contract and warranty data
--  1.4  08/08/2011  Roman            Added task type and SR type
--------------------------------------------------------------------
        tm.org_id,
        tm.task_id,
        tm.task_number,
        tm.debrief_header_id,
        tm.debrief_number,
        tm.incident_number,
        tm.customer_name,
        tm.region,
        tm.operating_unit,
        tm.task_type_id,
        tm.resource_id,
        tm.resource_name,
        tm.task_category,
        tm.task_status,
        tm.TASK_TYPE,
        tm.task_status_category,
        tm.task_assignment_date,
        sr.end_customer,
        sr.serial_number,
        sr.printer,
        sr.printer_desc,
        sr.printer_for_parameter,
        sr.incident_type_name,
        tm.sales_channel_code,
        ic.CONTRACT_NUMBER,
        ic.CONTRACT_TYPE,
        iw.WARRANTY_NUMBER,
        sum(tm.WK_HR)    WK_HR,  ---NO Travel hours
        sum(tm.TVL_HR)   TVL_HR  --Travel hours
FROM    XXCS_TASK_MAPPING_V tm,
        XXCS_SERVICE_CALLS  sr,
        xxcs_instance_contract  IC,
        xxcs_instance_warranty  IW
WHERE   XXCS_UTILS_PKG.CHECK_SECURITY_BY_OPER_UNIT(tm.org_id,tm.customer_id)='Y' AND
        sr.instance_id = ic.CONTRACT_INSTANCE_ID (+) AND
        sr.instance_id = iW.WARRANTY_INSTANCE_ID (+) AND
        IW.WARRANTY_LINE_STATUS (+) = 'ACTIVE' AND
---------------------------------------------------------------------------------------------
        /*XXCS_SESSION_PARAM.set_session_param_date(to_date('01-JUL-2011','DD-MON-YYYY'),1)=1
AND     XXCS_SESSION_PARAM.set_session_param_date(to_date('31-JUL-2011','DD-MON-YYYY'),2)=1 AND*/
----------------------------------------------------------------------------------------------
        tm.incident_id = sr.incident_id AND
        tm.incident_occurred_date BETWEEN XXCS_SESSION_PARAM.get_session_param_date(1)  ---p_from_date
                                      AND XXCS_SESSION_PARAM.get_session_param_date(2)  ---p_to_date
GROUP BY
        tm.org_id,
        tm.task_id,
        tm.task_number,
        tm.debrief_header_id,
        tm.debrief_number,
        tm.incident_number,
        tm.customer_name,
        tm.region,
        tm.operating_unit,
        tm.task_type_id,
        tm.resource_id,
        tm.resource_name,
        tm.task_category,
        tm.task_status,
        tm.TASK_TYPE,
        tm.task_status_category,
        tm.task_assignment_date,
        sr.end_customer,
        sr.serial_number,
        sr.printer,
        sr.printer_desc,
        sr.printer_for_parameter,
        sr.incident_type_name,
        tm.sales_channel_code,
        ic.CONTRACT_NUMBER,
        ic.CONTRACT_TYPE,
        iw.WARRANTY_NUMBER;
