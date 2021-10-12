create or replace trigger xxmtl_categories_bur_trg1
  before update on MTL_CATEGORIES_B
  for each row


when (NEW.last_updated_by <> 4290 )
DECLARE
  l_oa2sf_rec xxobjt_oa2sf_interface_pkg.t_oa2sf_rec;
  l_err_code  VARCHAR2(10) := 0;
  l_err_desc  VARCHAR2(2500) := NULL;

  CURSOR c_cat(p_category_id IN NUMBER) IS
    SELECT inventory_item_id,
           organization_id || '|' || inventory_item_id || '|' ||
           category_set_id || '|' || category_id source_id,
           category_id
      FROM mtl_item_categories t
     WHERE t.category_id = p_category_id
       AND organization_id = 91;

BEGIN
  --------------------------------------------------------------------
  --  name:            XXMTL_CATEGORIES_BUR_TRG1
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
  -- 1) when any change done to category enter raws for all items relate to it
  FOR i IN c_cat(:new.category_id) LOOP
  
    IF xxobjt_oa2sf_interface_pkg.is_relate_to_sf(i.inventory_item_id, 'PRODUCT', '') = 'Y' THEN
      l_oa2sf_rec.source_id   := i.source_id;
      l_oa2sf_rec.source_id2  := i.category_id;
      l_oa2sf_rec.source_name := 'CATEGORY';
      xxobjt_oa2sf_interface_pkg.insert_into_interface(p_oa2sf_rec => l_oa2sf_rec, -- i t_oa2sf_rec,
                                                       p_err_code => l_err_code, -- o v
                                                       p_err_msg => l_err_desc); -- o v
    END IF;
  END LOOP;
EXCEPTION
  WHEN OTHERS THEN
    NULL;
END xxmtl_categories_bur_trg1;
/
