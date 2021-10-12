CREATE OR REPLACE VIEW XXCS_CHARGES_EXPENCE_V AS
SELECT
--------------------------------------------------------------------
--  name:            XXCS_CHARGES_EXPENCE_V
--  create by:       Yoram Zamir
--  Revision:        1.2
--  creation date:   02/02/2010
--------------------------------------------------------------------
--  purpose :       Discoverer Reports
--------------------------------------------------------------------
--  ver  date        name             desc
--  1.0  02/02/2010  Yoram Zamir      initial build
--  1.1  04/03/2010  Yoram Zamir      exclude "FSR" business process and Service activity;   cost from WSI (93) instead of WPI (90)
--  1.2  13/06/2010  Vitaly           labour_hours_amount and material_amount were added
--  1.3  10/10/2013  Yair Lahav       Cust 695 CR 870, change hard coded organization_id/code for std costing project
--------------------------------------------------------------------
       CHARGE_TAB.customer_id      party_id,
       CHARGE_TAB.customer_name,
       CHARGE_TAB.instance_id,
       CHARGE_TAB.serial_number,
       CHARGE_TAB.inventory_item_id,
       CHARGE_TAB.item,
       CHARGE_TAB.item_desc,
       SUM(decode(CHARGE_TAB.charges_line_category,'LABOUR HOURS',CHARGE_TAB.amount,0))    labour_hours_amount,
       SUM(decode(CHARGE_TAB.charges_line_category,'MATERIAL',    CHARGE_TAB.amount,0))    material_amount,
       SUM(CHARGE_TAB.amount)    amount
FROM (SELECT
       -----=========== 1 ============ Work Hours (ON_SITE,PHONE_SUPPORT,TRAVEL) =======================
       ou.name             operating_unit,
       sr.org_id,
       hp.attribute1       region,
       sr.customer_id,
       hp.party_name       customer_name,
       s.name              end_customer,
       chd.charge_line_type,
       chd.ttype           service_activity,
       chd.business_process_name,
       sr.incident_number,
       ib.serial_number,
       ib.instance_id,
       sr.inventory_item_id,
       msi.segment1        item,
       msi.description     item_desc,
       WH_COST_TAB.item    charges_item,
       ----chd.ttype CHARGES_LINE_CATEGORY,
       'LABOUR HOURS'      charges_line_category,
       XXCS_MTB_REPORT_PKG.CONVERT_DURATION_UOM(nvl(chd.unit_of_measure_code,'HR'),'HR',chd.quantity_required)   qty,   ----qty hours
       chd.unit_of_measure_code   charges_item_uom,
       nvl(nvl(WH_COST_TAB.work_hour_cost_usd,0)  --- setup in USD
                *XXCS_MTB_REPORT_PKG.CONVERT_DURATION_UOM(nvl(chd.unit_of_measure_code,'HR'),'HR',chd.quantity_required),0)    amount  --USD
FROM   CS_CHARGE_DETAILS_V             chd,
       CS_INCIDENTS_ALL_B              sr,
       CSI_ITEM_INSTANCES              ib,
       CSI_SYSTEMS_V                   s,
       MTL_SYSTEM_ITEMS_B              msi,
       HR_OPERATING_UNITS              ou,
       HZ_PARTIES                      hp,
       XXCS_SERVICE_ITEMS_MAPPING_V    wh_cost_tab
WHERE
       ----------------------------------------------------------------------------------------------
       /*XXCS_SESSION_PARAM.set_session_param_date(to_date('01-JAN-2009','DD-MON-YYYY'),1)=1 AND
       XXCS_SESSION_PARAM.set_session_param_date(to_date('31-DEC-2010','DD-MON-YYYY'),2)=1   AND*/
       ----------------------------------------------------------------------------------------------
       chd.incident_id=sr.incident_id
AND    ib.system_id            = s.system_id (+)
AND    sr.customer_product_id  = ib.instance_id(+)
AND   (chd.order_header_id IS NULL
        OR  NOT EXISTS (SELECT 1 FROM OE_ORDER_HEADERS_ALL  h WHERE h.header_id=chd.order_header_id AND h.flow_status_code<>'CANCELLED')
       )
AND    chd.charge_line_type='ACTUAL'
AND    chd.business_process_name <> 'FSR'
AND    chd.ttype IN ('Labor Hours','Travel Hours','Expense'/*,'FSR Expense', 'FSR Labor Hours'*/)
AND    sr.org_id=ou.organization_id(+)
AND    sr.customer_id=hp.party_id(+)
AND    sr.incident_occurred_date between XXCS_SESSION_PARAM.get_session_param_date(1)  ---p_from_date
                                     and XXCS_SESSION_PARAM.get_session_param_date(2)  ---p_to_date
AND    sr.incident_status_id <> 104 -- Cancelled
AND    chd.inventory_item_id=WH_COST_TAB.inventory_item_id(+)
AND    chd.org_id           =WH_COST_TAB.org_id(+)
AND    msi.organization_id=91 --master
AND    sr.inventory_item_id=msi.inventory_item_id  --printer
UNION ALL
SELECT -----=========== 2 ============ Material =======================
       ou.name                 operating_unit,
       sr.org_id,
       hp.attribute1           region,
       sr.customer_id,
       hp.party_name           customer_name,
       s.name                  end_customer,
       chd.charge_line_type,
       chd.ttype               service_activity,
       chd.business_process_name,
       sr.incident_number,
       ib.serial_number,
       ib.instance_id,
       sr.inventory_item_id,
       msi.segment1            item,
       msi.description         item_desc,
       msi_charge.segment1     charges_item,
       'MATERIAL'                 charges_line_category,
       chd.quantity_required      qty,
       chd.unit_of_measure_code   charges_item_uom,
       nvl(XXCS_MTB_REPORT_PKG.GET_ITEM_COST(733, --93 Y.L. 10/10/2013  ,  ---organization_id  for WSI
                                             chd.inventory_item_id,
                                             2,      ---precision,
                                             chd.quantity_required, --qty
                                             chd.unit_of_measure_code ---from_uom
                                               ),
           XXCS_MTB_REPORT_PKG.GET_ITEM_COST(735, --90, Y.L. 10/10/2013    ---organization_id  for WPI
                                             chd.inventory_item_id,
                                             2,      ---precision,
                                             chd.quantity_required, --qty
                                             chd.unit_of_measure_code ---from_uom
                                               ))       AMOUNT --USD
FROM   CS_CHARGE_DETAILS_V             chd,
       CS_INCIDENTS_ALL_B              sr,
       CSI_ITEM_INSTANCES              ib,
       CSI_SYSTEMS_V                   s,
       MTL_SYSTEM_ITEMS_B              msi,
       MTL_SYSTEM_ITEMS_B              msi_charge,
      (SELECT c.inventory_item_id,
              c.currency_code,
              c.ITEM_COST
       FROM   XXCS_ITEM_COGS_V  c
       WHERE  c.ORG='ISK'/*'WSI'*/)         cogs,  ---instead of 'WPI' -- Y.L. 10/10/2013
       (SELECT    ou.organization_id
                 ,ou.name
                 ,gl.currency_code
        FROM     hr_operating_units  ou,
                 gl_ledgers          gl
        WHERE   ou.set_of_books_id  = gl.ledger_id)    ou,
       HZ_PARTIES                      hp
WHERE
       ----------------------------------------------------------------------------------------------
       /*XXCS_SESSION_PARAM.set_session_param_date(to_date('01-JAN-2009','DD-MON-YYYY'),1)=1 AND
       XXCS_SESSION_PARAM.set_session_param_date(to_date('31-DEC-2010','DD-MON-YYYY'),2)=1   AND*/
       ----------------------------------------------------------------------------------------------
       chd.incident_id=sr.incident_id
AND    ib.system_id            = s.system_id (+)
AND    sr.customer_product_id  = ib.instance_id(+)
AND    chd.business_process_name <> 'FSR'
AND    chd.ttype NOT IN ('Labor Hours','Travel Hours','Expense', 'FSR Expense', 'FSR Labor Hours', 'FSR Replace Part',
                         'Return for Replacement','Return Head for Replacement','FSR Return Part','Return Part',
                         'Return Head')
AND   (chd.order_header_id IS NULL
        OR  NOT EXISTS (SELECT 1 FROM OE_ORDER_HEADERS_ALL  h WHERE h.header_id=chd.order_header_id AND h.flow_status_code<>'CANCELLED')
       )
AND    chd.charge_line_type='ACTUAL'
AND    sr.org_id=ou.organization_id(+)
AND    sr.customer_id=hp.party_id(+)
AND    sr.incident_occurred_date between XXCS_SESSION_PARAM.get_session_param_date(1)  ---p_from_date
                                     and XXCS_SESSION_PARAM.get_session_param_date(2)  ---p_to_date
AND    sr.incident_status_id <> 104 -- Cancelled
AND    msi.organization_id=91 --master
AND    sr.inventory_item_id=msi.inventory_item_id
AND    msi_charge.organization_id=91 --master
AND    chd.inventory_item_id=msi_charge.inventory_item_id
AND    chd.inventory_item_id=cogs.inventory_item_id(+)
                              )  CHARGE_TAB
GROUP BY CHARGE_TAB.customer_id,
       CHARGE_TAB.customer_name,
       CHARGE_TAB.instance_id,
       CHARGE_TAB.serial_number,
       CHARGE_TAB.inventory_item_id,
       CHARGE_TAB.item,
       CHARGE_TAB.item_desc;
