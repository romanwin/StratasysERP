CREATE OR REPLACE TRIGGER xxfnd_attch_docs_biud_trg3
--------------------------------------------------------------------------------------------------
  --  name:              XXFND_ATTCH_DOCS_BIUD_TRG3
  --  create by:         LINGARAJ SARANGI
  --  Revision:          1.0
  --  creation date:     18-02-2019
  --------------------------------------------------------------------------------------------------
  --  purpose :          CHG0044890 - eCommerce product restructure -Item and System interfaces
  --
  --
  --  Modification History
  --------------------------------------------------------------------------------------------------
  --  ver   date          Name                       Desc
  --  1.0   18/02/2019    LINGARAJ SARANGI           CHG0044890 - eCommerce product restructure -Item and System interfaces
  -- 1.1   08/07/20       yuval tal                  CHG0048217 - b2b ecomm add  product strataforce event
  -- 1.2   18.5.21         yuval tal                 CHG0049851 - disable hybris activities
  --------------------------------------------------------------------------------------------------
  BEFORE INSERT OR UPDATE OR DELETE ON "APPLSYS"."FND_ATTACHED_DOCUMENTS"
  FOR EACH ROW
  WHEN (nvl (new.entity_name, old.entity_name) = 'MTL_SYSTEM_ITEMS')
DECLARE

  l_error_message VARCHAR2(2000);

  -- l_xxssys_event_rec  xxssys_events%ROWTYPE;
  -- l_old_item_rec_type xxinv_ecomm_event_pkg.item_rec_type;
  -- l_new_item_rec_type xxinv_ecomm_event_pkg.item_rec_type;
  l_inv_item_id NUMBER;

  /*FUNCTION get_item_record(p_inv_item_id NUMBER)
    RETURN xxinv_ecomm_event_pkg.item_rec_type IS
    CURSOR c_item_rec IS
      SELECT msib.inventory_item_id,
             msib.segment1,
             msib.organization_id,
             msib.description,
             msib.primary_unit_of_measure,
             msib.hazardous_material_flag,
             msib.dimension_uom_code,
             msib.unit_length,
             msib.unit_width,
             msib.unit_height,
             msib.weight_uom_code,
             msib.unit_weight,
             NULL --mtl_categories_b.Segment6
            ,
             NULL --mtl_cross_references_b.attribute7
            ,
             NULL --mtl_cross_references_b.attribute8
            ,
             NULL --mtl_cross_references_b.attribute9
            ,
             msib.created_by,
             msib.last_updated_by,
             msib.orderable_on_web_flag,
             msib.customer_order_enabled_flag,
             NULL --mtl_item_categories.category_set_id
            ,
             1 --mtl_item_categories.category_id
            ,
             NULL --status
            ,
             NULL --source
      FROM   mtl_system_items_b msib
      WHERE  msib.inventory_item_id = p_inv_item_id
      AND    msib.organization_id = 91;
  
    l_item_record xxinv_ecomm_event_pkg.item_rec_type;
  BEGIN
    OPEN c_item_rec;
    IF c_item_rec%NOTFOUND THEN
      RETURN NULL;
    ELSE
      FETCH c_item_rec
        INTO l_item_record;
    END IF;
    CLOSE c_item_rec;
  
    RETURN l_item_record;
  END get_item_record;*/

BEGIN
  l_error_message := '';
  BEGIN
    SELECT 1
    INTO   l_inv_item_id
    FROM   fnd_document_categories_tl
    WHERE  category_id = nvl(:new.category_id, :old.category_id)
    AND    LANGUAGE = userenv('LANG')
    AND    user_name = 'PZ Text';
  
    l_inv_item_id := to_number(nvl(:new.pk2_value, :old.pk2_value));
  
    --  l_new_item_rec_type             := get_item_record(l_inv_item_id);
    --   l_old_item_rec_type             := l_new_item_rec_type;
    --  l_old_item_rec_type.category_id := -1; -- This value is assigned to make the Comparision successful, This Vallue will not interface
    --INSERTDATA('BEFORE EVENT CALL');
  
    -- CHG0049851 - disable hybris activities
    /* xxinv_ecomm_event_pkg.item_trigger_processor(p_old_item_rec   => l_old_item_rec_type,
    p_new_item_rec   => l_new_item_rec_type,
    p_trigger_name   => 'XXFND_ATTCH_DOCS_BIUD_TRG3',
    p_trigger_action => 'UPDATE');*/
  
    -- CHG0048217
    xxssys_strataforce_events_pkg.insert_product_event(p_inventory_item_id => l_inv_item_id,
				       p_item_code         => '',
				       p_last_updated_by   => fnd_global.user_id,
				       p_created_by        => fnd_global.user_id,
				       p_trigger_name      => 'XXFND_ATTCH_DOCS_BIUD_TRG3',
				       p_trigger_action    => '');
  
  EXCEPTION
    WHEN no_data_found THEN
      NULL;
  END;
EXCEPTION
  WHEN OTHERS THEN
    l_error_message := substrb(SQLERRM, 1, 500);
    fnd_log.string(log_level => fnd_log.level_unexpected,
	       module    => 'xxssys.XXFND_ATTCH_DOCS_BIUD_TRG3',
	       message   => l_error_message);
END xxfnd_attch_docs_biud_trg3;
/
