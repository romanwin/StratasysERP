CREATE OR REPLACE TRIGGER xxinv_item_cat_aiudr_trg3
--------------------------------------------------------------------------------------------------
  --  name:              XXINV_ITEM_CAT_AIUDR_TRG3
  --  create by:         Lingaraj Sarangi
  --  Revision:          1.0
  --  creation date:     12-Dec-2017
  --------------------------------------------------------------------------------------------------
  --  purpose :          CHG0035652  : Check and insert/update data into event table for Insert and Update
  --                                   triggers on QP_LIST_HEADERS_B
  --
  --  Modification History
  --------------------------------------------------------------------------------------------------
  --  ver   date          Name                       Desc
  --  1.0   12-Dec-2017   Lingaraj Sarangi           CHG0041829 - Strataforce Real Rime Product interface
  --  1.1   22.4.19       yuval tal                  CHG0045599  add Enable Pre-Order
  --  1.2   31/05/2019    Bellona                    CHG0045828 - add "Enable Pay per use"
  --------------------------------------------------------------------------------------------------
  AFTER INSERT OR UPDATE OR DELETE ON "INV"."MTL_ITEM_CATEGORIES"
  FOR EACH ROW

  when(nvl (new.organization_id, old.organization_id) = 91)
DECLARE
  l_trigger_name VARCHAR2(30) := 'XXINV_ITEM_CAT_AIUDR_TRG3';

  l_old_item_cat_rec mtl_item_categories%ROWTYPE;
  l_new_item_cat_rec mtl_item_categories%ROWTYPE;

  l_error_message  VARCHAR2(2000);
  l_trigger_ation  VARCHAR2(10) := '';
  l_push_itm_event VARCHAR2(1) := 'N';
  l_flag           NUMBER;
BEGIN
  l_error_message := '';

  IF inserting THEN
    l_trigger_ation := 'INSERT';
  ELSIF updating THEN
    l_trigger_ation := 'UPDATE';
  ELSIF deleting THEN
    l_trigger_ation := 'DELETE';
  END IF;

  --OLD Records
  IF updating OR deleting THEN
    l_old_item_cat_rec.inventory_item_id := :old.inventory_item_id;
    l_old_item_cat_rec.organization_id   := :old.organization_id;
    l_old_item_cat_rec.category_set_id   := :old.category_set_id;
    l_old_item_cat_rec.category_id       := :old.category_id;
    l_old_item_cat_rec.last_updated_by   := :old.last_updated_by;
    l_old_item_cat_rec.created_by        := :old.created_by;
  END IF;

  --New Record
  IF inserting OR updating THEN
    l_new_item_cat_rec.inventory_item_id := :new.inventory_item_id;
    l_new_item_cat_rec.organization_id   := :new.organization_id;
    l_new_item_cat_rec.category_set_id   := :new.category_set_id;
    l_new_item_cat_rec.category_id       := :new.category_id;
    l_new_item_cat_rec.last_updated_by   := :new.last_updated_by;
    l_new_item_cat_rec.created_by        := :new.created_by;
  END IF;

  --1100000161 - Japan Resin Pack Breakdown
  --1100000221 - Product Hierarchy
  --1100000316 /1100000334- SALES Price Book Product Type
  --1100000224 - CS Price Book Product Type
  BEGIN
    SELECT 1
    INTO   l_flag
    FROM   mtl_category_sets_vl t
    WHERE  category_set_name IN ('CS Price Book Product Type',
		         'SALES Price Book Product Type',
		         'Product Hierarchy',
		         'Japan Resin Pack Breakdown',
		         'Exclude from CPQ',
		         'Internal use only',
		         'Visible in PB',
		         'Brand',
		         'Activity Analysis','Enable Pre-Order' /*CHG0045599*/
                 ,'Enable Pay per use' /*CHG0045828*/)
    AND    t.category_set_id =
           nvl(:new.category_set_id, :old.category_set_id)
    AND    rownum = 1;
  EXCEPTION
    WHEN OTHERS THEN
      l_flag := 0;
  END;

  IF l_flag = 1

   THEN
    xxssys_strataforce_events_pkg.insert_product_event(p_inventory_item_id => nvl(:new.inventory_item_id,
						          :old.inventory_item_id),
				       p_last_updated_by   => nvl(:new.last_updated_by,
						          :old.last_updated_by),
				       p_created_by        => nvl(:new.created_by,
						          :old.created_by),
				       p_trigger_name      => l_trigger_name,
				       p_trigger_action    => l_trigger_ation);
  END IF;

  --Other Then the Below Categort Set ID
  --1100000181 - Commissions
  --1100000042 - Class Category Set
  -- 1100000041-  Main Category Set

  xxssys_strataforce_events_pkg.item_cat_trg_processor(p_old_item_cat_rec => l_old_item_cat_rec,
				       p_new_item_cat_rec => l_new_item_cat_rec,
				       p_trigger_name     => l_trigger_name,
				       p_trigger_action   => l_trigger_ation);

EXCEPTION
  WHEN OTHERS THEN
    l_error_message := substrb(SQLERRM, 1, 500);
    raise_application_error(-20999, l_error_message);
END xxinv_item_cat_aiudr_trg3;
/
