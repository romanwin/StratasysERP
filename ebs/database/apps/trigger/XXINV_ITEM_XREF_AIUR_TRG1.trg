CREATE OR REPLACE TRIGGER XXINV_ITEM_XREF_AIUR_TRG1
--------------------------------------------------------------------------------------------------
--  name:              XXINV_ITEM_XREF_AIUR_TRG1
--  create by:         Diptasurjya Chatterjee
--  Revision:          1.0
--  creation date:     22/06/2015
--------------------------------------------------------------------------------------------------
--  purpose :          CHG0035652  : Check and insert/update data into event table for Insert, Delete
--                                   and Update triggers on MTL_CROSS_REFERENCES_B
--
--  Modification History
--------------------------------------------------------------------------------------------------
--  ver   date          Name                       Desc
--  1.0   22/06/2015    Diptasurjya Chatterjee     CHG0035652 - eCommerce Real Time  Product interface
--  1.1   27/10/2015    Diptasurjya Chatterjee     CHG0036886 - Pronto Real Time  Product interface
--  1.2   17/02/2019    Lingaraj                   INC0146984  - remove pronto call 
--------------------------------------------------------------------------------------------------
AFTER INSERT OR DELETE OR UPDATE ON MTL_CROSS_REFERENCES_B
FOR EACH ROW

DECLARE
  l_trigger_name      varchar2(30) := 'XXINV_ITEM_XREF_AIUR_TRG1';

  old_items_rec       xxinv_ecomm_event_pkg.item_rec_type;
  new_items_rec       xxinv_ecomm_event_pkg.item_rec_type;

  --pronto_old_items_rec       xxinv_pronto_event_pkg.item_rec_type; --INC0146984
  --pronto_new_items_rec       xxinv_pronto_event_pkg.item_rec_type; --INC0146984

  l_item_detail_rec   xxinv_ecomm_event_pkg.item_rec_type;

  l_error_message     varchar2(2000);
BEGIN
  l_error_message := '';

  -- Old Values before Update
  old_items_rec.inventory_item_id           := :old.inventory_item_id;
  old_items_rec.organization_id             := :old.organization_id;
  old_items_rec.created_by                  := :old.created_by;
  old_items_rec.last_updated_by             := :old.last_updated_by;
  old_items_rec.pack                        := :old.attribute7;
  old_items_rec.color                       := :old.attribute8;
  old_items_rec.flavor                      := :old.attribute9;

  l_item_detail_rec := xxinv_ecomm_event_pkg.get_item_details(old_items_rec.inventory_item_id,
                                                              nvl(old_items_rec.organization_id,91));

  old_items_rec.orderable_on_web_flag       := l_item_detail_rec.orderable_on_web_flag;
  old_items_rec.customer_order_enabled_flag := l_item_detail_rec.customer_order_enabled_flag;

  l_item_detail_rec := null;

  -- New Values after Update
  new_items_rec.inventory_item_id           := :new.inventory_item_id;
  new_items_rec.organization_id             := :new.organization_id;
  new_items_rec.created_by                  := :new.created_by;
  new_items_rec.last_updated_by             := :new.last_updated_by;
  new_items_rec.pack                        := :new.attribute7;
  new_items_rec.color                       := :new.attribute8;
  new_items_rec.flavor                      := :new.attribute9;

  l_item_detail_rec := xxinv_ecomm_event_pkg.get_item_details(new_items_rec.inventory_item_id,
                                                              nvl(new_items_rec.organization_id,91));

  new_items_rec.orderable_on_web_flag       := l_item_detail_rec.orderable_on_web_flag;
  new_items_rec.customer_order_enabled_flag := l_item_detail_rec.customer_order_enabled_flag;

  /* -- Commented for INC0146984 
  CHG0036886 Pronto data type preparation 
  pronto_old_items_rec.inventory_item_id    := :old.inventory_item_id;
  pronto_old_items_rec.organization_id      := :old.organization_id;
  pronto_old_items_rec.sf_id                := :old.attribute1;
  pronto_old_items_rec.created_by           := :old.created_by;
  pronto_old_items_rec.last_updated_by      := :old.last_updated_by;

  pronto_new_items_rec.inventory_item_id    := :new.inventory_item_id;
  pronto_new_items_rec.organization_id      := :new.organization_id;
  pronto_new_items_rec.sf_id                := :new.attribute1;
  pronto_new_items_rec.created_by           := :new.created_by;
  pronto_new_items_rec.last_updated_by      := :new.last_updated_by;
  CHG0036886 End Pronto data type preparation 
  */

  IF updating THEN
     xxinv_ecomm_event_pkg.item_trigger_processor(p_old_item_rec   => old_items_rec,
                                                  p_new_item_rec   => new_items_rec,
                                                  p_trigger_name   => l_trigger_name,
                                                  p_trigger_action => 'UPDATE');
     /* Commented for INC0146984
     CHG0036886 Pronto event processor call 
     xxinv_pronto_event_pkg.item_trigger_processor(p_old_item_rec   => pronto_old_items_rec,
                                                   p_new_item_rec   => pronto_new_items_rec,
                                                   p_trigger_name   => l_trigger_name,
                                                   p_trigger_action => 'UPDATE');
     --CHG0036886 End Pronto event processor call 
     */
  ELSIF inserting THEN
     xxinv_ecomm_event_pkg.item_trigger_processor(p_old_item_rec   => null,
                                                  p_new_item_rec   => new_items_rec,
                                                  p_trigger_name   => l_trigger_name,
                                                  p_trigger_action => 'INSERT');
     /* Commented for INC0146984
     CHG0036886 Pronto event processor call 
     xxinv_pronto_event_pkg.item_trigger_processor(p_old_item_rec   => null,
                                                   p_new_item_rec   => pronto_new_items_rec,
                                                   p_trigger_name   => l_trigger_name,
                                                   p_trigger_action => 'INSERT');
     --CHG0036886 End Pronto event processor call 
     */
  ELSIF deleting THEN
    xxinv_ecomm_event_pkg.item_trigger_processor(p_old_item_rec   => old_items_rec,
                                                 p_new_item_rec   => null,
                                                 p_trigger_name   => l_trigger_name,
                                                 p_trigger_action => 'DELETE');
    /* Commented for INC0146984
     CHG0036886 Pronto event processor call 
    xxinv_pronto_event_pkg.item_trigger_processor(p_old_item_rec   => pronto_old_items_rec,
                                                  p_new_item_rec   => null,
                                                  p_trigger_name   => l_trigger_name,
                                                  p_trigger_action => 'DELETE');
     -- CHG0036886 End Pronto event processor call 
     */
  END IF;

EXCEPTION
WHEN OTHERS THEN
  l_error_message := substrb(sqlerrm,1,500);
  RAISE_APPLICATION_ERROR(-20999,l_error_message);
END XXINV_ITEM_XREF_AIUR_TRG1;
/
