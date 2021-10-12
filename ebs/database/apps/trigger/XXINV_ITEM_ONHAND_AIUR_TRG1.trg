CREATE OR REPLACE TRIGGER XXINV_ITEM_ONHAND_AIUR_TRG1
--------------------------------------------------------------------------------------------------
--  name:              XXINV_ITEM_ONHAND_AIUR_TRG1
--  create by:         Diptasurjya Chatterjee
--  Revision:          1.0
--  creation date:     26-10-2015
--------------------------------------------------------------------------------------------------
--  purpose :          CHGxxx  : Insert/Update/Delete trigger on MTL_ONHAND_QUANTITIES_DETAIL to
--                               for real time integration of item onhand with interfacing applications
--
--  Modification History
--------------------------------------------------------------------------------------------------
--  ver   date          Name                       Desc
--  1.0   26/10/2015    Diptasurjya Chatterjee     CHG0036886 - Real time item onhand interface
--------------------------------------------------------------------------------------------------

AFTER INSERT OR UPDATE OR DELETE ON MTL_ONHAND_QUANTITIES_DETAIL
FOR EACH ROW

DECLARE
  l_trigger_name      varchar2(30) := 'XXINV_ITEM_ONHAND_AIUR_TRG1';
  old_items_rec       xxinv_pronto_event_pkg.item_onhand_rec_type;
  new_items_rec       xxinv_pronto_event_pkg.item_onhand_rec_type;
  l_error_message     varchar2(2000);
BEGIN
  l_error_message := '';

  -- Old Values before Update
  old_items_rec.onhand_quantities_id        := :old.onhand_quantities_id;
  old_items_rec.inventory_item_id           := :old.inventory_item_id;
  old_items_rec.organization_id             := :old.organization_id;
  old_items_rec.subinventory_code           := :old.subinventory_code;
  old_items_rec.revision_name               := :old.revision;
  old_items_rec.is_consigned                := :old.is_consigned;
  old_items_rec.created_by                  := :old.created_by;
  old_items_rec.last_updated_by             := :old.last_updated_by;

  -- New Values after Update
  new_items_rec.onhand_quantities_id        := :new.onhand_quantities_id;
  new_items_rec.inventory_item_id           := :new.inventory_item_id;
  new_items_rec.organization_id             := :new.organization_id;
  new_items_rec.subinventory_code           := :new.subinventory_code;
  new_items_rec.revision_name               := :new.revision;
  new_items_rec.is_consigned                := :new.is_consigned;
  new_items_rec.created_by                  := :new.created_by;
  new_items_rec.last_updated_by             := :new.last_updated_by;


  IF updating THEN
    xxinv_pronto_event_pkg.item_onhand_trigger_processor(p_old_item_rec   => old_items_rec,
                                                         p_new_item_rec   => new_items_rec,
                                                         p_trigger_name   => l_trigger_name,
                                                         p_trigger_action => 'UPDATE');

  ELSIF inserting THEN
    xxinv_pronto_event_pkg.item_onhand_trigger_processor(p_old_item_rec => null,
                                                         p_new_item_rec => new_items_rec,
                                                         p_trigger_name   => l_trigger_name,
                                                         p_trigger_action => 'INSERT');
  ELSE
    xxinv_pronto_event_pkg.item_onhand_trigger_processor(p_old_item_rec => old_items_rec,
                                                         p_new_item_rec => null,
                                                         p_trigger_name   => l_trigger_name,
                                                         p_trigger_action => 'DELETE');
  END IF;
EXCEPTION
WHEN OTHERS THEN
  l_error_message := substrb(sqlerrm,1,500);
  RAISE_APPLICATION_ERROR(-20999,l_error_message);
END XXINV_ITEM_AIUR_TRG1;
/
