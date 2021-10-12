create or replace trigger XXMTL_RELATED_ITEMS_BIUDR_TRG
  before  insert or update or delete  on MTL_RELATED_ITEMS
  for each row

when (nvl(NEW.last_updated_by,OLD.last_updated_by) <> 4290)
DECLARE
  --------------------------------------------------------------------
  --  name:            XXMTL_RELATED_ITEMS_BIUDR_TRG
  --  create by:       yuval tal
  --  Revision:        1.0
  --------------------------------------------------------------------
  --  purpose :        CHG0031508  Customer support Oracle - SF interfaces project
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  15.9.14     yuval tal         CHG0031508  Customer support Oracle - SF interfaces project
  --                                     sync item to sf interface table when related information changes
  --                                     last_updated_by <> 4290 -> Salesforce
  --  1.1 19.5.16     yuval tal          CHG0037007  add nvl to when (nvl(NEW.last_updated_by,old.last_updated_by) <> 4290)                                                     
  --------------------------------------------------------------------

  l_oa2sf_rec xxobjt_oa2sf_interface_pkg.t_oa2sf_rec;
  l_err_code  VARCHAR2(10) := 0;
  l_err_desc  VARCHAR2(2500) := NULL;
  l_entity_id NUMBER := NULL;
BEGIN

  l_entity_id := xxobjt_oa2sf_interface_pkg.is_valid_to_sf('PRODUCT',
				           nvl(:old.inventory_item_id,
					   :new.inventory_item_id));

  IF l_entity_id IS NOT NULL THEN
    l_oa2sf_rec.source_id   := nvl(:old.inventory_item_id,
		           :new.inventory_item_id);
    l_oa2sf_rec.source_name := 'PRODUCT';
    xxobjt_oa2sf_interface_pkg.insert_into_interface(p_oa2sf_rec => l_oa2sf_rec, -- i t_oa2sf_rec,
				     p_err_code  => l_err_code, -- o v
				     p_err_msg   => l_err_desc); -- o v
  END IF;
  /*EXCEPTION
  WHEN OTHERS THEN
    NULL;*/
END;
/
