CREATE OR REPLACE VIEW XXCS_ENG_DAYS_IN_STOCK_V AS
SELECT
--------------------------------------------------------------------
--  name:            XXCS_ENG_DAYS_IN_STOCK_SUM_V
--  create by:       Vitaly.K
--  Revision:        1.4
--  creation date:   07/12/2009
--------------------------------------------------------------------
--  purpose :    Disco Report:  ENG_DAYS_IN_STOCK
--------------------------------------------------------------------
--  ver  date           name           desc
--  1.0  07/12/2009     Vitaly         initial build
--  1.1  10/12/2009     Vitaly         subinventory description and resource_name were added
--  1.2  08/03/2010     Vitaly         Operating_Unit_Party was added
--  1.3  09/03/2009     Vitaly         Security for resp CRM Service Super User Objet was added
--  1.4  08/06/2010     Vitaly         Security by OU was added
--------------------------------------------------------------------
       MSI.INVENTORY_ITEM_ID,
       MSI.ORGANIZATION_ID,
       ood.OPERATING_UNIT   org_id,
       ou.name              operating_unit,
       msi.segment1 ITEM,
       s.subinv_desc,--
       s.resource_name,
       oh.subinventory_code||' - '||msi.segment1   subinv_item_for_parameter,
       msi.description DESCRIPTION,
       oh.subinventory_code,
       oh.transaction_uom_code,
       oh.transaction_quantity,
       trunc(oh.date_received) date_received,
       round(SYSDATE - oh.date_received)     days_in_stock,
       oh.transaction_quantity * (SYSDATE - oh.date_received)     total_days_in_stock
FROM   mtl_onhand_quantities_detail    oh,
       xxcs_eng_subinv_v               s,
       org_organization_definitions    ood,
       hr_operating_units              ou,
       mtl_system_items_b              msi
WHERE  oh.inventory_item_id = msi.inventory_item_id
and    oh.organization_id = msi.organization_id
AND    s.default_code IS NOT NULL
AND    oh.subinventory_code=s.subinventory_code
AND    XXCS_UTILS_PKG.CHECK_SECURITY_BY_OPER_UNIT(ood.OPERATING_UNIT)='Y'
AND    s.ORGANIZATION_ID=ood.ORGANIZATION_ID
AND    ood.OPERATING_UNIT=ou.organization_id(+);

