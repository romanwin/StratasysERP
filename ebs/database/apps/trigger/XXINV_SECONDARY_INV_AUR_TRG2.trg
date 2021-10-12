CREATE OR REPLACE TRIGGER XXINV_SECONDARY_INV_AUR_TRG2
--------------------------------------------------------------------------------------------------
--  name:              XXINV_SECONDARY_INV_AUR_TRG2
--  create by:         Diptasurjya Chatterjee
--  Revision:          1.0
--  creation date:     11/23/2015
--------------------------------------------------------------------------------------------------
--  purpose :          CHG0036886 : Change in interface condition for subinventory will trigger
--                                  onhand quantity event generation for PRONTO
--  Modification History
--------------------------------------------------------------------------------------------------
--  ver   date          Name                       Desc
--  1.0   11/11/2015    Diptasurjya Chatterjee     CHG0036886 - Initial Build
--------------------------------------------------------------------------------------------------
AFTER UPDATE ON MTL_SECONDARY_INVENTORIES
FOR EACH ROW

DECLARE
  l_trigger_name          varchar2(30) := 'XXINV_SECONDARY_INV_AUR_TRG2';

  pronto_old_onhand_rec    xxinv_pronto_event_pkg.item_onhand_rec_type;
  pronto_new_onhand_rec    xxinv_pronto_event_pkg.item_onhand_rec_type;

  l_error_message         varchar2(2000);
BEGIN
  l_error_message := '';

  pronto_old_onhand_rec.organization_id      := :old.organization_id;
  pronto_old_onhand_rec.subinventory_code    := :old.secondary_inventory_name;
  pronto_old_onhand_rec.subinv_disable_date  := :old.disable_date;
  pronto_old_onhand_rec.subinv_attribute11   := :old.attribute11;
  pronto_old_onhand_rec.created_by           := :old.created_by;
  pronto_old_onhand_rec.last_updated_by      := :old.last_updated_by;

  pronto_new_onhand_rec.organization_id      := :new.organization_id;
  pronto_new_onhand_rec.subinventory_code    := :new.secondary_inventory_name;
  pronto_new_onhand_rec.subinv_disable_date  := :new.disable_date;
  pronto_new_onhand_rec.subinv_attribute11   := :new.attribute11;
  pronto_new_onhand_rec.created_by           := :new.created_by;
  pronto_new_onhand_rec.last_updated_by      := :new.last_updated_by;


  xxinv_pronto_event_pkg.item_subinv_trigger_processor(p_old_onhand_rec   => pronto_old_onhand_rec,
                                                       p_new_onhand_rec   => pronto_new_onhand_rec,
                                                       p_trigger_name     => l_trigger_name,
                                                       p_trigger_action   => 'UPDATE');
EXCEPTION
WHEN OTHERS THEN
  l_error_message := substrb(sqlerrm,1,500);
  RAISE_APPLICATION_ERROR(-20999,l_error_message);
END XXINV_SECONDARY_INV_AIUR_TRG2;
/
