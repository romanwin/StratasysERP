CREATE OR REPLACE TRIGGER xxmtl_system_items_tl_bur_trg1
  before update on MTL_SYSTEM_ITEMS_TL
  for each row
/*Commented for CHG0043924 On 05SEP18
when( (NEW.language  = 'JA') and (NEW.organization_id = 91) and (nvl(NEW.description,'DAR') <> nvl(OLD.description,'DAR')) and (NEW.last_updated_by <> 4290) )
*/
WHEN (NEW.organization_id = 91) --Added for CHG0043924 On 05SEP18
DECLARE
  l_relate_to_sf VARCHAR2(5) := 'N';
  l_oa2sf_rec    xxobjt_oa2sf_interface_pkg.t_oa2sf_rec;
  l_err_code     VARCHAR2(10) := 0;
  l_err_desc     VARCHAR2(2500) := NULL;
  l_trigger_name   VARCHAR2(30) := 'XXMTL_SYSTEM_ITEMS_TL_BUR_TRG1'; --CHG0043924
  l_trigger_action VARCHAR2(10) := (CASE WHEN INSERTING THEN 'INSERT'
                                         WHEN UPDATING THEN  'UPDATE'
                                         ELSE '' 
                                    END
                                    ); --CHG0043924
BEGIN
  --------------------------------------------------------------------
  --  name:            XXMTL_SYSTEM_ITEMS_TL_BUR_TRG1
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   06/01/2014
  --------------------------------------------------------------------
  --  purpose :        Trigger that will fire each update of item description only for Japan
  --                   CUST776 - Customer support SF-OA interfaces CR 1215
  --                   last_updated_by <> 4290 -> Salesforce
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  06/01/2014  Dalit A. Raviv    initial build
  --  1.1  05.Sep.2018 Lingaraj          CHG0043924-need to create STRATAFORCE product event for long description
  --------------------------------------------------------------------
  
  --The Trigger WHEN Condition moved to If Condition # Added for CHG0043924 On 05SEP18
  If ((:NEW.language  = 'JA')  
     and  nvl(:NEW.description,'DAR') <> nvl(:OLD.description,'DAR'))
     and (:NEW.last_updated_by <> 4290)
  Then   
  l_oa2sf_rec.source_id   := :new.inventory_item_id;
  l_oa2sf_rec.source_name := 'PRODUCT';
  xxobjt_oa2sf_interface_pkg.insert_into_interface(p_oa2sf_rec => l_oa2sf_rec, -- i t_oa2sf_rec,
                                                   p_err_code  => l_err_code, -- o v
                                                   p_err_msg   => l_err_desc); -- o v
  End If;
  
  --CHG0043924 On 05SEP18 
  -- Strataforce PRODUCT Event Generation on Item Long Description Change                                                 
  xxssys_strataforce_events_pkg.insert_product_event(p_inventory_item_id =>:new.inventory_item_id,                                                     
                                                     p_last_updated_by   =>:new.last_updated_by,
                                                     p_created_by        =>:new.created_by,
                                                     p_trigger_name      =>l_trigger_name,
                                                     p_trigger_action    =>l_trigger_action 
                                                     );
EXCEPTION
  WHEN OTHERS THEN
    NULL;
END xxmtl_system_items_bur_trg1;
/
