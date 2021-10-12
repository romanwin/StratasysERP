CREATE OR REPLACE VIEW XXCS_MTL_QOH_SUB_ALL_V AS
SELECT
--------------------------------------------------------------------
--  name:            XXCS_MTL_QOH_SUB_ALL_V
--  create by:       Yoram Zamir
--  Revision:        1.1
--  creation date:   21/12/2010
--------------------------------------------------------------------
--  purpose :       Discoverer Reports
--------------------------------------------------------------------
--  ver  date        name             desc
--  1.0  07/09/2009  Yoram Zamir      initial build
--  1.1  21/12/2010  Roman            Added Date_received
--------------------------------------------------------------------
       A.ORGANIZATION_ID,
       A.INVENTORY_ITEM_ID,
       A.REVISION,
       A.SUBINVENTORY_CODE,
       B.segment1 Item,
       B.DESCRIPTION,
       a.transaction_quantity,
       a.transaction_uom_code,
       a.onhand_quantities_id,
       a.create_transaction_id,
       a.update_transaction_id,
       a.date_received
FROM   MTL_ONHAND_QUANTITIES_DETAIL A,
       MTL_SYSTEM_ITEMS B
WHERE  A.INVENTORY_ITEM_ID = B.INVENTORY_ITEM_ID
   AND A.ORGANIZATION_ID = B.ORGANIZATION_ID

UNION

SELECT C.ORGANIZATION_ID,
       C.INVENTORY_ITEM_ID,
       C.REVISION,
       C.SUBINVENTORY_CODE,
       D.segment1 Item,
       D.DESCRIPTION,
       C.transaction_quantity,
       D.PRIMARY_UOM_CODE,
       NULL,
       c.transaction_header_id,
       c.transaction_temp_id,
       c.transaction_date date_received
FROM   MTL_MATERIAL_TRANSACTIONS_TEMP C, MTL_SYSTEM_ITEMS D
WHERE  C.INVENTORY_ITEM_ID = D.INVENTORY_ITEM_ID
   AND C.ORGANIZATION_ID = D.ORGANIZATION_ID;

