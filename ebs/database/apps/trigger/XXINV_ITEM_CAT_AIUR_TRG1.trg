CREATE OR REPLACE TRIGGER XXINV_ITEM_CAT_AIUR_TRG1
--------------------------------------------------------------------------------------------------
--  name:              XXINV_ITEM_CAT_AIUR_TRG1
--  create by:         Diptasurjya Chatterjee
--  Revision:          1.0
--  creation date:     22-06-2015
--------------------------------------------------------------------------------------------------
--  purpose :          CHG0035652  : Check and insert/update data into event table for Insert, Delete
--                                   and Update triggers on MTL_ITEM_CATEGORIES
--
--  Modification History
--------------------------------------------------------------------------------------------------
--  ver   date          Name                       Desc
--  1.0   22/06/2015    Diptasurjya Chatterjee     CHG0035652 - eCommerce Real Time  Product interface
--  1.1   02/03/2016    Debarati Banerjee       CHG0037925– Add new category_set_id 1100000247
--                                                 for new item category set DG Restriction level
--------------------------------------------------------------------------------------------------
AFTER INSERT OR DELETE OR UPDATE ON MTL_ITEM_CATEGORIES
FOR EACH ROW

WHEN (OLD.category_set_id IN (1100000221,1100000201,1100000247) OR NEW.category_set_id IN (1100000221,1100000201,1100000247))

DECLARE
  l_trigger_name      varchar2(30) := 'XXINV_ITEM_CAT_AIUR_TRG1';

  old_items_rec       xxinv_ecomm_event_pkg.item_rec_type;
  new_items_rec       xxinv_ecomm_event_pkg.item_rec_type;

  l_item_detail_rec   xxinv_ecomm_event_pkg.item_rec_type;

  l_error_message     varchar2(2000);
BEGIN
  l_error_message := '';

  -- Old Values before Update
  old_items_rec.inventory_item_id           := :old.inventory_item_id;
  old_items_rec.organization_id             := :old.organization_id;
  old_items_rec.category_set_id             := :old.category_set_id;
  old_items_rec.category_id                 := :old.category_id;
  old_items_rec.created_by                  := :old.created_by;
  old_items_rec.last_updated_by             := :old.last_updated_by;
  l_item_detail_rec := xxinv_ecomm_event_pkg.get_item_details(old_items_rec.inventory_item_id,
                                                              old_items_rec.organization_id);

  old_items_rec.orderable_on_web_flag       := l_item_detail_rec.orderable_on_web_flag;
  old_items_rec.customer_order_enabled_flag := l_item_detail_rec.customer_order_enabled_flag;

  l_item_detail_rec := null;

  -- New Values after Update
  new_items_rec.inventory_item_id           := :new.inventory_item_id;
  new_items_rec.organization_id             := :new.organization_id;
  new_items_rec.created_by                  := :new.created_by;
  new_items_rec.last_updated_by             := :new.last_updated_by;
  new_items_rec.category_set_id             := :new.category_set_id;
  new_items_rec.category_id                 := :new.category_id;

  l_item_detail_rec := xxinv_ecomm_event_pkg.get_item_details(new_items_rec.inventory_item_id,
                                                              new_items_rec.organization_id);

  new_items_rec.orderable_on_web_flag       := l_item_detail_rec.orderable_on_web_flag;
  new_items_rec.customer_order_enabled_flag := l_item_detail_rec.customer_order_enabled_flag;

  IF updating THEN
     xxinv_ecomm_event_pkg.item_trigger_processor(p_old_item_rec   => old_items_rec,
                                                  p_new_item_rec   => new_items_rec,
                                                  p_trigger_name   => l_trigger_name,
                                                  p_trigger_action => 'UPDATE');

  ELSIF inserting THEN
     xxinv_ecomm_event_pkg.item_trigger_processor(p_old_item_rec   => null,
                                                  p_new_item_rec   => new_items_rec,
                                                  p_trigger_name   => l_trigger_name,
                                                  p_trigger_action => 'INSERT');

  ELSIF deleting THEN
    xxinv_ecomm_event_pkg.item_trigger_processor(p_old_item_rec    => old_items_rec,
                                                  p_new_item_rec   => null,
                                                  p_trigger_name   => l_trigger_name,
                                                  p_trigger_action => 'DELETE');
  END IF;

EXCEPTION
WHEN OTHERS THEN
  l_error_message := substrb(sqlerrm,1,500);
  RAISE_APPLICATION_ERROR(-20999,l_error_message);
END XXINV_ITEM_CAT_AIUR_TRG1;
/




