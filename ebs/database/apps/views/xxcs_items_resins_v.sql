CREATE OR REPLACE VIEW XXCS_ITEMS_RESINS_V AS
SELECT
--------------------------------------------------------------------
--  name:            XXCS_ITEMS_RESINS_V
--  create by:       Yoram Zamir
--  Revision:        1.0
--  creation date:   28/01/2010
--------------------------------------------------------------------
--  purpose :        For Disco Reports
--------------------------------------------------------------------
--  ver  date        name           desc
--  1.0  28/01/2010  Yoram Zamir    initial build
--------------------------------------------------------------------
       msi.inventory_item_id,
       mtc.segment1,
       mtc.segment2,
       MTC.SEGMENT3,
       MSI.SEGMENT1 ITEM,
       MSI.DESCRIPTION ITEM_DESCRIPTION,
       MSI.SEGMENT1 || '   -   ' || MSI.DESCRIPTION ITEM_FOR_PARAMETER
  FROM MTL_SYSTEM_ITEMS_B  MSI,
       MTL_ITEM_CATEGORIES MIC,
       MTL_CATEGORIES_B    MTC
 WHERE MSI.ORGANIZATION_ID = 91
   AND MIC.INVENTORY_ITEM_ID = MSI.INVENTORY_ITEM_ID
   AND MIC.ORGANIZATION_ID = MSI.ORGANIZATION_ID
   AND MIC.ORGANIZATION_ID = 91
   AND MIC.CATEGORY_SET_ID = 1100000041
   AND MTC.CATEGORY_ID = MIC.CATEGORY_ID
   AND MTC.ENABLED_FLAG = 'Y'
   AND mtc.segment1 = 'Resins';

