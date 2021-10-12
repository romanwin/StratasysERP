create or replace trigger xxmtl_item_categories_bur_trg1
  before Update on MTL_ITEM_CATEGORIES
  for each row

when ((NEW.last_updated_by <> 4290) and (NEW.category_id <> OLD.category_id ) and new.organization_id=91)
DECLARE
  l_oa2sf_rec xxobjt_oa2sf_interface_pkg.t_oa2sf_rec;
  l_err_code  VARCHAR2(10) := 0;
  l_err_desc  VARCHAR2(2500) := NULL;
BEGIN
  --------------------------------------------------------------------
  --  name:            XXMTL_ITEM_CATEGORIES_BUR_TRG1
  --  create by:       Dalit A. Raviv
  --  Revision:        1.1
  --  creation date:   20/01/2014
  --------------------------------------------------------------------
  --  purpose :        Trigger that will fire each insert of new item category
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  20/01/2014  Dalit A. Raviv    initial build
  --                                     CUST776 - Customer support SF-OA interfaces CR 1215
  --                                     last_updated_by <> 4290 -> Salesforce
  --------------------------------------------------------------------
  -- 1) Insert row with old Source id  process_mode=’DELETE’
  IF xxobjt_oa2sf_interface_pkg.is_valid_to_sf('PRODUCT', :old.inventory_item_id) = 1 THEN
  
    l_oa2sf_rec.source_id := :old.organization_id || '|' ||
                             :old.inventory_item_id || '|' ||
                             :old.category_set_id || '|' ||
                             :old.category_id;
  
    l_oa2sf_rec.source_id2 := :old.category_id;
  
    l_oa2sf_rec.source_name  := 'CATEGORY';
    l_oa2sf_rec.process_mode := 'DELETE';
    xxobjt_oa2sf_interface_pkg.insert_into_interface(p_oa2sf_rec => l_oa2sf_rec, -- i t_oa2sf_rec,
                                                     p_err_code => l_err_code, -- o v
                                                     p_err_msg => l_err_desc); -- o v
  
  END IF;
  -- 2) Insert row with new Source id

  IF xxobjt_oa2sf_interface_pkg.is_relate_to_sf(:new.inventory_item_id, 'PRODUCT', '') = 'Y' THEN
    l_oa2sf_rec.source_id := :new.organization_id || '|' ||
                             :new.inventory_item_id || '|' ||
                             :new.category_set_id || '|' ||
                             :new.category_id;
  
    l_oa2sf_rec.source_id2   := :new.category_id;
    l_oa2sf_rec.source_name  := 'CATEGORY';
    l_oa2sf_rec.process_mode := NULL;
    xxobjt_oa2sf_interface_pkg.insert_into_interface(p_oa2sf_rec => l_oa2sf_rec, -- i t_oa2sf_rec,
                                                     p_err_code => l_err_code, -- o v
                                                     p_err_msg => l_err_desc); -- o v
  
    -- handle change in Main category, need to enter Product row to interface
    IF :new.category_set_id = 1100000041 THEN
      -- Main Category set;
      l_oa2sf_rec.source_id    := :new.inventory_item_id;
      l_oa2sf_rec.source_name  := 'PRODUCT';
      l_oa2sf_rec.process_mode := NULL;
      xxobjt_oa2sf_interface_pkg.insert_into_interface(p_oa2sf_rec => l_oa2sf_rec, -- i t_oa2sf_rec,
                                                       p_err_code => l_err_code, -- o v
                                                       p_err_msg => l_err_desc); -- o v
    END IF;
  
  END IF;
  --

EXCEPTION
  WHEN OTHERS THEN
    NULL;
END xxmtl_item_categories_bur_trg1;
/
