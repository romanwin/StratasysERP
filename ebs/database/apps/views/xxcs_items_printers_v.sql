CREATE OR REPLACE VIEW XXCS_ITEMS_PRINTERS_V AS
SELECT
--------------------------------------------------------------------
--  name:            XXCS_ITEMS_PRINTERS_V
--  create by:       Yoram Zamir
--  Revision:        1.0
--  creation date:   28/01/2010
--------------------------------------------------------------------
--  purpose :        For Disco Reports
--------------------------------------------------------------------
--  ver  date        name           desc
--  1.0  28/01/2010  Yoram Zamir    initial build
--  1.1  1.4.18      yuval tal      CHG0042619 change item_type logic
--------------------------------------------------------------------
       msi.inventory_item_id,
       (SELECT FFV.ATTRIBUTE1
        FROM FND_FLEX_VALUE_SETS FFVS,
             FND_FLEX_VALUES     FFV,
             FND_FLEX_VALUES_TL  FFVT
       WHERE FFVS.FLEX_VALUE_SET_NAME = 'XXCS_IB_TYPE'
         AND FFVS.FLEX_VALUE_SET_ID = FFV.FLEX_VALUE_SET_ID
         AND FFVT.FLEX_VALUE_ID = FFV.FLEX_VALUE_ID
         AND FFVT.LANGUAGE = 'US'
         AND FFV.ENABLED_FLAG = 'Y'
         AND FFVT.DESCRIPTION = mtc.segment1) ITEM_TYPE,
       DECODE(mtc.segment1,'Acc-Cleaning Equipment','WJ',MTC_hei.SEGMENT3) FAMILY,
       DECODE(mtc.segment1,'Acc-Cleaning Equipment','Water jet',MTC_hei.SEGMENT4) ITEM_CATEGORY,
       MSI.SEGMENT1 ITEM,
       MSI.DESCRIPTION ITEM_DESCRIPTION,
       MSI.SEGMENT1 || '   -   ' || MSI.DESCRIPTION ITEM_FOR_PARAMETER
  FROM MTL_SYSTEM_ITEMS_B  MSI,
       MTL_ITEM_CATEGORIES MIC,
       MTL_ITEM_CATEGORIES MIC_hei,
       MTL_CATEGORIES_B    MTC,
       MTL_CATEGORIES_B    MTC_hei
 WHERE MSI.ORGANIZATION_ID = xxinv_utils_pkg.get_master_organization_id
   AND MIC.INVENTORY_ITEM_ID = MSI.INVENTORY_ITEM_ID
   AND MIC.ORGANIZATION_ID = MSI.ORGANIZATION_ID
   AND MIC.CATEGORY_SET_ID = (SELECT mcsv.CATEGORY_SET_ID 
                              FROM   mtl_category_sets_v mcsv
                              WHERE  mcsv.CATEGORY_SET_NAME = 'Activity Analysis')

   AND MIC_hei.INVENTORY_ITEM_ID = MSI.INVENTORY_ITEM_ID
   AND MIC_hei.ORGANIZATION_ID = MSI.ORGANIZATION_ID
   AND MIC_hei.CATEGORY_SET_ID = (SELECT mcsv.CATEGORY_SET_ID 
                              FROM   mtl_category_sets_v mcsv
                              WHERE  mcsv.CATEGORY_SET_NAME = 'Product Hierarchy')
   AND MTC_hei.CATEGORY_ID = MIC_hei.CATEGORY_ID
   AND MTC_hei.ENABLED_FLAG = 'Y'
   AND MTC.CATEGORY_ID = MIC.CATEGORY_ID
   AND MTC.ENABLED_FLAG = 'Y'
   AND MSI.COMMS_NL_TRACKABLE_FLAG = 'Y'
   AND mtc.segment1 IN ('Systems (net)','Acc-Cleaning Equipment','Systems-Used');

