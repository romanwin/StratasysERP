CREATE OR REPLACE VIEW XXCS_ENG_DAYS_IN_STOCK_SUM_V AS
SELECT

--------------------------------------------------------------------
--  name:            XXCS_ENG_DAYS_IN_STOCK_SUM_V
--  create by:       Vitaly.K
--  Revision:        1.3
--  creation date:   07/12/2009
--------------------------------------------------------------------
--  purpose :    Disco Report:  ENG_DAYS_IN_STOCK
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  07/12/2009  Vitaly            initial build
--  1.1  09/12/2009  Vitaly            View XXCS_ENG_SUBINV_V was added
--  1.2  10/12/2009  Vitaly            View XXCS_ENG_SUBINV_V was removed
--  1.3  08/03/2010  Vitaly            Operating_Unit was added
--------------------------------------------------------------------

       d.subinventory_code,
       d.subinventory_code||' - '||d.resource_name     subinv_resource_for_param,
       d.ITEM,
       d.subinv_desc,
       d.subinv_item_for_parameter,
       d.INVENTORY_ITEM_ID,
       d.ORGANIZATION_ID,
       d.org_id,
       d.OPERATING_UNIT,
       d.DESCRIPTION,
       d.transaction_uom_code,
       SUM(d.transaction_quantity)   qty,
       round(SUM(d.total_days_in_stock))     total_days_in_stock ,
       round(SUM(d.total_days_in_stock)/SUM(d.transaction_quantity))   avg_days_in_stock
FROM   XXCS_ENG_DAYS_IN_STOCK_V  d
WHERE 1=1
GROUP BY d.subinventory_code,
       d.subinventory_code||' - '||d.resource_name,
       d.ITEM,
       d.subinv_desc,
       d.INVENTORY_ITEM_ID,
       d.ORGANIZATION_ID,
       d.org_id,
       d.OPERATING_UNIT,
       d.DESCRIPTION,
       d.transaction_uom_code;

