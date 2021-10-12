create or replace trigger xxmtl_item_categories_bdr_trg1
  before delete on MTL_ITEM_CATEGORIES
  for each row
when (old.organization_id=91 )
DECLARE
  l_oa2sf_rec xxobjt_oa2sf_interface_pkg.t_oa2sf_rec;
  l_err_code  VARCHAR2(10) := 0;
  l_err_desc  VARCHAR2(2500) := NULL;
BEGIN
  --------------------------------------------------------------------
  --  name:            XXMTL_ITEM_CATEGORIES_BDR_TRG1
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   20/01/2014
  --------------------------------------------------------------------
  --  purpose :        Trigger that will fire each insert of new item category
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  20/01/2014  Dalit A. Raviv    initial build
  --                                     CUST776 - Customer support SF-OA interfaces CR 1215
  --
  --------------------------------------------------------------------
  -- 1) Insert row with old Source id  process_mode=’DELETE’

  IF xxobjt_oa2sf_interface_pkg.is_relate_to_sf(:old.inventory_item_id, 'PRODUCT', '') = 'Y' THEN
  
    l_oa2sf_rec.source_id := :old.organization_id || '|' ||
                             :old.inventory_item_id || '|' ||
                             :old.category_set_id || '|' ||
                             :old.category_id;
  
    l_oa2sf_rec.source_id2   := :old.category_id;
    l_oa2sf_rec.source_name  := 'CATEGORY';
    l_oa2sf_rec.process_mode := 'DELETE';
    xxobjt_oa2sf_interface_pkg.insert_into_interface(p_oa2sf_rec => l_oa2sf_rec, -- i t_oa2sf_rec,
                                                     p_err_code => l_err_code, -- o v
                                                     p_err_msg => l_err_desc); -- o v
  
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    NULL;
END xxmtl_item_categories_bdr_trg1;
/
