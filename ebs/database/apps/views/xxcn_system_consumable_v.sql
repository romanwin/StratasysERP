CREATE OR REPLACE VIEW xxcn_system_consumable_v
-- ---------------------------------------------------------------------------------
-- Name:       xxcn_system_consumables_v
-- Created By: MMAZANET
-- Revision:   1.0
-- ---------------------------------------------------------------------------------
-- Purpose: View used by the XXOERESELLORDRREL form to show system to consumable
--          items.  The form shows the many-to-many relationship between systems
--          and consumables.  
--          
--          Initially, the form was written to show either the system or consumable
--          as the master, but I've simplified to have system as the master and 
--          consumable as the child.  In the event we want to go back to the original
--          model, the rn column allows us to use either one as a master
--          or detail, which allows us to look at the data with either system or
--          consumable being the master.  See the "WHERE Clause " property on the
--          XXCN_SYSTEM_DTL block and/or XXCN_CONSUMABLE_DTL to see how this is 
--          used.
-- ---------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  06/10/2014  MMAZANET    Initial Creation for CHG0031576.
-- ---------------------------------------------------------------------------------
AS
SELECT 
   xsi.system_id                          system_id                                                    
,  xsc.consumable_id                      consumable_id                                                
,  xsi.parent_system_id                   parent_system_id                                             
,  'SYSTEM'                               system_consumable                                            
,  xsi.product                            product                                                      
,  xsi.family                             family                                                       
,  xsi.business_line                      business_line                                                
,  xsi.item_id                            item_id                                                      
,  xsi.item_org_id                        item_org_id                                                  
,  xsi.item_number                        item_number                                                  
,  xsi.item_description                   item_description                                             
,  xsi.item_org                           item_org                                                     
,  xsi.start_date                         start_date                                                   
,  xsi.end_date                           end_date     
,  NULL                                   comm_calc_on_rel_sys_flag
,  NULL                                   comm_exclude_flag
,  xsi.creation_date                      creation_date                                                
,  xsi.created_by                         created_by                                                   
,  xsi.created_by_name                    created_by_name                                              
,  xsi.last_update_date                   last_update_date                                             
,  xsi.updated_by_name                    updated_by_name                                              
,  xsi.last_update_login                  last_update_login                                            
,  ROW_NUMBER() OVER (PARTITION BY xsi.system_id ORDER BY xsi.creation_date)                           
                                          rn                                                           
FROM 
   xxcn_system_to_consumable        xsc
,  xxcn_system_items_v              xsi
WHERE xsi.system_id                 = xsc.system_id (+)
AND   'Y'                           = xsi.parent_system_flag 
UNION ALL
SELECT 
   xsc.system_id                          system_id
,  xsc.consumable_id                      consumable_id
,  NULL                                   parent_system_id
,  'CONSUMABLE'                           system_consumable
,  xci.product                            product 
,  xci.family                             family
,  xci.business_line                      business_line 
,  xci.item_id                            item_id
,  xci.item_org_id                        item_org_id
,  xci.item_number                        item_number
,  xci.item_description                   item_description
,  xci.item_org                           item_org
,  xsc.start_date                         start_date
,  xsc.end_date                           end_date
,  NVL(xsc.comm_calc_on_rel_sys_flag,'N') comm_calc_on_rel_sys_flag
,  NVL(xsc.comm_exclude_flag,'N')         comm_exclude_flag
,  xci.creation_date                      creation_date
,  xci.created_by                         created_by
,  xci.created_by_name                    created_by_name
,  xci.last_update_date                   last_update_date
,  xci.updated_by_name                    updated_by_name 
,  xci.last_update_login                  last_update_login
,  ROW_NUMBER() OVER (PARTITION BY xsc.consumable_id ORDER BY xci.creation_date)
                                          rn
FROM 
   xxcn_system_to_consumable        xsc
,  xxcn_consumable_items_v          xci
WHERE xsc.consumable_id             = xci.consumable_id
/

SHOW ERRORS