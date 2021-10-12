CREATE OR REPLACE VIEW xxcn_system_consumable_grid_v
-- ---------------------------------------------------------------------------------
-- Name:       xxcn_system_consumables_grid_v
-- Created By: MMAZANET
-- Revision:   1.0
-- ---------------------------------------------------------------------------------
-- Purpose: Provides a dump of all items and all consumables, linked together in this
--          custom application.
-- ---------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  06/10/2014  MMAZANET    Initial Creation for CHG0031576.
-- ---------------------------------------------------------------------------------
AS
SELECT 
   xsiv.system_id                                  system_id
,  xsiv.business_line                              system_business_line
,  xsiv.product                                    system_product
,  xsiv.family                                     system_family
,  xsiv.item_id                                    system_item_id
,  xsiv.item_number                                system_item_number
,  xsiv.item_description                           system_item_description
,  xsiv.start_date                                 system_start_date
,  xsiv.end_date                                   system_end_date
,  xciv.consumable_id                              consumable_id
,  xciv.business_line                              consumable_business_line
,  xciv.product                                    consumable_product
,  xciv.family                                     consumable_family
,  xciv.item_id                                    consumable_item_id
,  xciv.item_number                                consumable_item_number
,  xciv.item_description                           consumable_item_description
,  xsc.start_date                                  consumable_start_date
,  xsc.end_date                                    consumable_end_date
,  NVL(xsc.comm_calc_on_rel_sys_flag,'N')          comm_calc_on_rel_sys_flag
,  NVL(xsc.comm_exclude_flag,'N')                  comm_exclude_flag
FROM
   xxcn_system_to_consumable     xsc
,  xxcn_system_items_v           xsiv
,  xxcn_consumable_items_v       xciv
WHERE xsc.system_id     = xsiv.system_id 
AND   xsc.consumable_id = xciv.consumable_id (+) 
/

SHOW ERRORS