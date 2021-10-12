CREATE OR REPLACE TRIGGER xxinv_item_aiur_trg1
--------------------------------------------------------------------------------------------------
  --  name:              XXINV_ITEM_AIUR_TRG1
  --  create by:         Diptasurjya Chatterjee
  --  Revision:          1.0
  --  creation date:     22-06-2015
  --------------------------------------------------------------------------------------------------
  --  purpose :          CHG0035652  : Check and insert/update data into event table for Insert and Update
  --                                   triggers on MTL_SYSTEM_ITEMS_B
  --
  --  Modification History
  --------------------------------------------------------------------------------------------------
  --  ver   date          Name                       Desc
  --  1.0   22/06/2015    Diptasurjya Chatterjee     CHG0035652 - eCommerce Real Time  Product interface
  --  1.1   27/10/2015    Diptasurjya Chatterjee     CHG0036886 - Pronto Real Time  Product interface
  --  1.2   22/11/2017    Diptasurjya Chatterjee     CHG0041829 - Strataforce Real Rime Product interface
  --  1.3   17/02/2019    yuval tal                  INC0146984  - remove pronto call
  -- 1.4    14/07/2020    yuval tal                  CHG0048238 -  add BU fields chg support
  -- 1.5    15/07/2020    yuval tal                  CHG0048217  - b2b ecomm
  -- 1.6    18.5.21       yuval tal                  CHG0049851 - disable hybris activities
  --------------------------------------------------------------------------------------------------

  AFTER INSERT OR UPDATE ON "INV"."MTL_SYSTEM_ITEMS_B"
  FOR EACH ROW

DECLARE
  l_trigger_name VARCHAR2(30) := 'XXINV_ITEM_AIUR_TRG1';

  sforce_old_items_rec mtl_system_items_b%ROWTYPE; -- CHG0041829
  sforce_new_items_rec mtl_system_items_b%ROWTYPE; -- CHG0041829

  l_error_message VARCHAR2(2000);
BEGIN
  l_error_message := '';

  /* CHG0041829 Start Strataforce data type preparation */
  sforce_old_items_rec.inventory_item_id           := :old.inventory_item_id;
  sforce_old_items_rec.segment1                    := :old.segment1;
  sforce_old_items_rec.description                 := :old.description;
  sforce_old_items_rec.item_type                   := :old.item_type;
  sforce_old_items_rec.organization_id             := :old.organization_id;
  sforce_old_items_rec.customer_order_enabled_flag := :old.customer_order_enabled_flag;
  sforce_old_items_rec.customer_order_flag         := :old.customer_order_flag;
  sforce_old_items_rec.returnable_flag             := :old.returnable_flag;
  sforce_old_items_rec.primary_uom_code            := :old.primary_uom_code;
  sforce_old_items_rec.weight_uom_code             := :old.weight_uom_code;
  sforce_old_items_rec.unit_weight                 := :old.unit_weight;
  sforce_old_items_rec.volume_uom_code             := :old.volume_uom_code;
  sforce_old_items_rec.unit_volume                 := :old.unit_volume;
  sforce_old_items_rec.inventory_item_status_code  := :old.inventory_item_status_code;
  sforce_old_items_rec.created_by                  := :old.created_by;
  sforce_old_items_rec.last_updated_by             := :old.last_updated_by;
  sforce_old_items_rec.sales_account               := :old.sales_account; --CHG0048238

  sforce_old_items_rec.unit_length             := :old.unit_length; --CHG0048217
  sforce_old_items_rec.unit_width              := :old.unit_width; --CHG0048217
  sforce_old_items_rec.unit_height             := :old.unit_height; --CHG0048217
  sforce_old_items_rec.dimension_uom_code      := :old.dimension_uom_code; --CHG0048217
  sforce_old_items_rec.attribute26             := :old.attribute26; --CHG0048217
  sforce_old_items_rec.orderable_on_web_flag   := :old.orderable_on_web_flag; -- CHG0048217
  sforce_old_items_rec.hazardous_material_flag := :old.hazardous_material_flag; --CHG0048217
  sforce_old_items_rec.default_shipping_org    := :old.default_shipping_org; --CHG0048217

  sforce_new_items_rec.inventory_item_id           := :new.inventory_item_id;
  sforce_new_items_rec.segment1                    := :new.segment1;
  sforce_new_items_rec.description                 := :new.description;
  sforce_new_items_rec.item_type                   := :new.item_type;
  sforce_new_items_rec.organization_id             := :new.organization_id;
  sforce_new_items_rec.customer_order_enabled_flag := :new.customer_order_enabled_flag;
  sforce_new_items_rec.customer_order_flag         := :new.customer_order_flag;
  sforce_new_items_rec.returnable_flag             := :new.returnable_flag;
  sforce_new_items_rec.primary_uom_code            := :new.primary_uom_code;
  sforce_new_items_rec.weight_uom_code             := :new.weight_uom_code;
  sforce_new_items_rec.unit_weight                 := :new.unit_weight;
  sforce_new_items_rec.volume_uom_code             := :new.volume_uom_code;
  sforce_new_items_rec.unit_volume                 := :new.unit_volume;
  sforce_new_items_rec.inventory_item_status_code  := :new.inventory_item_status_code;
  sforce_new_items_rec.created_by                  := :new.created_by;
  sforce_new_items_rec.last_updated_by             := :new.last_updated_by;

  /* CHG0041829 End Strataforce data type preparation */
  sforce_new_items_rec.sales_account := :new.sales_account; --CHG0048238

  sforce_new_items_rec.unit_length             := :new.unit_length; --CHG0048217
  sforce_new_items_rec.unit_width              := :new.unit_width; --CHG0048217
  sforce_new_items_rec.unit_height             := :new.unit_height; --CHG0048217
  sforce_new_items_rec.dimension_uom_code      := :new.dimension_uom_code; --CHG0048217
  sforce_new_items_rec.attribute26             := :new.attribute26; --CHG0048217
  sforce_new_items_rec.orderable_on_web_flag   := :new.orderable_on_web_flag; --CHG0048217
  sforce_new_items_rec.hazardous_material_flag := :new.hazardous_material_flag; --CHG0048217
  sforce_new_items_rec.default_shipping_org    := :new.default_shipping_org; --CHG0048217

  IF updating THEN
    --CHG0049851
    /* xxinv_ecomm_event_pkg.item_trigger_processor(p_old_item_rec   => old_items_rec,
    p_new_item_rec   => new_items_rec,
    p_trigger_name   => l_trigger_name,
    p_trigger_action => 'UPDATE');*/
  
    /* CHG0041829 Start Strataforce event processor call */
    IF :old.organization_id IN (91, 740) THEN
      --  CHG0048217
      xxssys_strataforce_events_pkg.item_trg_processor(p_old_item_rec   => sforce_old_items_rec,
				       p_new_item_rec   => sforce_new_items_rec,
				       p_trigger_name   => l_trigger_name,
				       p_trigger_action => 'UPDATE');
    END IF;
  
    /* CHG0041829 End Strataforce event processor call */
  ELSIF inserting THEN
    --CHG0049851
    /* xxinv_ecomm_event_pkg.item_trigger_processor(p_old_item_rec   => NULL,
    p_new_item_rec   => new_items_rec,
    p_trigger_name   => l_trigger_name,
    p_trigger_action => 'INSERT');*/
  
    /* CHG0041829 Start Strataforce event processor call */
    IF :new.organization_id IN (91, 740) THEN
      --  CHG0048217
      xxssys_strataforce_events_pkg.item_trg_processor(p_old_item_rec   => NULL,
				       p_new_item_rec   => sforce_new_items_rec,
				       p_trigger_name   => l_trigger_name,
				       p_trigger_action => 'INSERT');
    END IF;
    /* CHG0041829 End Strataforce event processor call */
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    l_error_message := substrb(SQLERRM, 1, 500);
    raise_application_error(-20999, l_error_message);
END xxinv_item_aiur_trg1;
/
