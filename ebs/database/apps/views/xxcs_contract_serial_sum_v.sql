CREATE OR REPLACE VIEW XXCS_CONTRACT_SERIAL_SUM_V AS
SELECT
--------------------------------------------------------------------
--  name:            XXCS_CONTRACT_SERIAL_SUM_V
--  create by:       Vitaly K.
--  Revision:        1.1
--  creation date:   28/01/2010
--------------------------------------------------------------------
--  purpose :       Discoverer Reports
--------------------------------------------------------------------
--  ver  date        name             desc
--  1.0  28/01/2010  Vitaly K.      initial build
--  1.1  18/04/2010  Vitaly K.      CONTRACT_DAYS calculation was changed; Outer nested loop removed
--------------------------------------------------------------------
       CONTRACT_TAB.customer_id   party_id,
       CONTRACT_TAB.customer_name,
       CONTRACT_TAB.instance_id,
       CONTRACT_TAB.serial_number,
       CONTRACT_TAB.inventory_item_id,
       CONTRACT_TAB.instance_item,
       CONTRACT_TAB.instance_item_desc,
       SUM(decode(CONTRACT_TAB.contract_days,0,0,CONTRACT_TAB.days/CONTRACT_TAB.contract_days)
                          *CONTRACT_TAB.converted_line_subtotal_usd)      converted_line_subtotal_usd
FROM
(SELECT  t.operating_unit,
         t.CS_REGION,
         t.party_id  CUSTOMER_ID,
         t.CUSTOMER_NAME,
         t.END_CUSTOMER,
         t.INSTANCE_ID,
         t.serial_number,
         t.inventory_item_id,
         t.instance_item,
         t.instance_item_desc,
         XXCS_SESSION_PARAM.get_session_param_date(1)  report_start_date,
         XXCS_SESSION_PARAM.get_session_param_date(2)  report_end_date,
         CASE
                 WHEN XXCS_SESSION_PARAM.get_session_param_date(2)  ---p_to_date
                     <= NVL(t.LINE_DATE_TERMINATED, t.LINE_END_DATE) THEN
                     XXCS_SESSION_PARAM.get_session_param_date(2)
                 ELSE
                     NVL(t.LINE_DATE_TERMINATED, t.LINE_END_DATE)
                 END
          -
         CASE
                 WHEN XXCS_SESSION_PARAM.get_session_param_date(1)  ---p_from_date
                     >= t.LINE_START_DATE THEN
                     XXCS_SESSION_PARAM.get_session_param_date(1)
                 ELSE
                     t.LINE_START_DATE
                 END  +1                             DAYS,  ---effective days
      /*(CASE
             WHEN XXCS_SESSION_PARAM.get_session_param_date(2)  ---p_to_date
                       <=NVL(t.LINE_DATE_TERMINATED, t.LINE_END_DATE) THEN
                     XXCS_SESSION_PARAM.get_session_param_date(2)
             ELSE
                     NVL(t.LINE_DATE_TERMINATED, t.LINE_END_DATE)
             END   - t.LINE_START_DATE +1)        CONTRACT_DAYS,*/
         NVL(t.LINE_DATE_TERMINATED, t.LINE_END_DATE) - t.LINE_START_DATE +1      CONTRACT_DAYS,     --Vitaly 18-Apr-2010
         t.LINE_START_DATE,
         t.LINE_END_DATE,
         t.LINE_DATE_TERMINATED,
         t.LINE_SUBTOTAL,
         t.LINE_CURRENCY_CODE,
         t.conversion_rate_to_usd,
         t.converted_line_subtotal_usd,
         t.converted_currency_code_usd,
         t.PRICE_LIST_NAME,
         t.price_list_id,
         t.SERVICE_TYPE,
         ---t.upg_orig_system_ref,
         ---t.upg_orig_system_ref_id,
         MAX(t.upg_orig_system_ref_id) OVER (PARTITION BY t.INSTANCE_ID)   upg_orig_system_ref_id

FROM XXCS_CONTRACT_ALL_V t
WHERE
-------------------------------------------------------------------------------------------------
      /*XXCS_SESSION_PARAM.set_session_param_date(to_date('01-JAN-2010','DD-MON-YYYY'),1)=1 AND
      XXCS_SESSION_PARAM.set_session_param_date(to_date('31-DEC-2010','DD-MON-YYYY'),2)=1 AND*/
-------------------------------------------------------------------------------------------------
      XXCS_SESSION_PARAM.get_session_param_date(1)  ---p_from_date
                                < nvl(t.LINE_DATE_TERMINATED,t.LINE_END_DATE) AND
      XXCS_SESSION_PARAM.get_session_param_date(2)  ---p_to_date
                                > t.LINE_START_DATE
      AND t.LINE_STATUS NOT IN ('CLOSED', 'CANCELLED')
      AND t.SERVICE_TYPE='SERVICE' -- Contracts (without warranties)
                         )  CONTRACT_TAB
GROUP BY CONTRACT_TAB.customer_id,
       CONTRACT_TAB.customer_name,
       CONTRACT_TAB.instance_id,
       CONTRACT_TAB.serial_number,
       CONTRACT_TAB.inventory_item_id,
       CONTRACT_TAB.instance_item,
       CONTRACT_TAB.instance_item_desc;

