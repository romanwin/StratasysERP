CREATE OR REPLACE TRIGGER xxqp_pricing_att_bdr_trg1
  BEFORE INSERT OR DELETE ON "QP"."QP_PRICING_ATTRIBUTES"
  FOR EACH ROW
DECLARE
  l_trigger_name   VARCHAR2(50) := 'XXQP_PRICING_ATT_BDR_TRG1';
  l_trigger_action VARCHAR2(10) := '#';
  l_list_header_id NUMBER := nvl(:new.list_header_id, :old.list_header_id);
  l_pac            VARCHAR2(240) := nvl(nvl(:new.product_attribute_context,
			        :old.product_attribute_context),
			    '#');
              
  l_list_line_id    NUMBER :=  nvl(:new.list_line_id,:old.list_line_id);  
  l_last_updated_by NUMBER :=  nvl(:new.last_updated_by,:old.last_updated_by);   
  l_created_by      NUMBER :=  nvl(:new.created_by,:old.created_by);    
  l_product_attr_value   VARCHAR2(240) := nvl(:new.PRODUCT_ATTR_VALUE,:old.PRODUCT_ATTR_VALUE);                 
BEGIN

  --If the Price Book Header is Inactive or Sync to Sf is No , No need to Create Event
  IF (xxssys_strataforce_events_pkg.is_pricebook_sync_to_sf(l_list_header_id) = 'N') THEN
    RETURN;
  END IF;

  IF inserting THEN
    l_trigger_action := 'INSERT';   
  ELSIF deleting THEN
    l_trigger_action := 'DELETE';
  END IF;
  
  IF deleting OR inserting AND l_pac = 'ITEM'    
    AND l_product_attr_value != 'ALL'     
  THEN
     
    xxssys_strataforce_events_pkg.price_attr_trg_processor(p_list_header_id  => l_list_header_id ,
				                                           p_list_line_id    => l_list_line_id,
                                                           p_inv_item_id     => l_product_attr_value,
                                                           p_last_updated_by => l_last_updated_by,
                                                           p_created_by      => l_created_by,
                                                           p_trigger_name    => l_trigger_name,
                                                           p_trigger_action  => l_trigger_action
                                                           );
  END IF;

END xxqp_pricing_att_bdr_trg1;
/
