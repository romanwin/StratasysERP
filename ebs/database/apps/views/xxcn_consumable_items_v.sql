CREATE OR REPLACE VIEW xxcn_consumable_items_v
-- ---------------------------------------------------------------------------------
-- Name:       xxcn_consumable_items_v
-- Created By: MMAZANET
-- Revision:   1.0
-- ---------------------------------------------------------------------------------
-- Purpose: View used by the XXOERESELLORDRREL form to show consumable items
-- ---------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  06/10/2014  MMAZANET    Initial Creation for CHG0031576.
-- ---------------------------------------------------------------------------------
AS
SELECT 
   xci.consumable_id                      consumable_id
,  xci.product                            product 
,  xci.family                             family
,  xci.business_line                      business_line 
,  xci.inventory_item_id                  item_id
,  NULL                                   item_org_id
,  item_master.item_number                item_number
,  item_master.item_description           item_description
,  NULL                                   item_org
,  xci.creation_date                      creation_date
,  xci.created_by                         created_by
,  fu_create.user_name                    created_by_name
,  xci.last_update_date                   last_update_date
,  fu_update.user_name                    updated_by_name 
,  xci.last_update_login                  last_update_login
FROM 
   xxcn_consumable_items            xci
/* item_master... */
, (SELECT 
      msib.inventory_item_id        inventory_item_id
   ,  msib.segment1                 item_number
   ,  msib.description              item_description
   FROM 
      mtl_system_items_b   msib
   ,  mtl_parameters       mp
   WHERE msib.organization_id = mp.organization_id
   AND   mp.organization_id   = mp.master_organization_id)      
                                    item_master
/* ... item_master */
--,  hr_all_organization_units        haou
,  fnd_user                         fu_create
,  fnd_user                         fu_update
WHERE xci.inventory_item_id         = item_master.inventory_item_id (+)
--AND   msi.organization_id           = haou.organization_id (+)
AND   xci.created_by                = fu_create.user_id (+)
AND   xci.last_updated_by           = fu_update.user_id (+)
/

SHOW ERRORS