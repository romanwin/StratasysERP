CREATE OR REPLACE PACKAGE xxinv_pronto_event_pkg AUTHID CURRENT_USER AS
  ----------------------------------------------------------------------------
  --  name:            xxinv_pronto_event_pkg
  --  create by:       Diptasurjya Chatterjee (TCS)
  --  Revision:        1.0
  --  creation date:   27/10/2015
  ----------------------------------------------------------------------------
  --  purpose :        CHG0036886 - Generic container package to handle all
  --                   inventory module related event invocations for PRONTO target. For item
  --                   as no suitable business events were identified, triggers
  --                   has been created on base tables and processed by this API
  ----------------------------------------------------------------------------
  --  ver  date        name                         desc
  --  1.0  27/10/2015  Diptasurjya Chatterjee(TCS)  CHG0036886 - initial build
  ----------------------------------------------------------------------------

  TYPE item_rec_type IS RECORD(
    inventory_item_id           mtl_system_items.inventory_item_id%TYPE,
    segment1                    mtl_system_items.segment1%TYPE,
    organization_id             mtl_system_items.organization_id%TYPE,
    description                 mtl_system_items.description%TYPE,
    customer_order_enabled_flag mtl_system_items.customer_order_enabled_flag%TYPE,
    service_item_flag           mtl_system_items.service_item_flag%TYPE,
    material_billable_flag      mtl_system_items.material_billable_flag%TYPE,
    item_returnable             mtl_system_items.attribute12%TYPE,
    related_item_id             NUMBER,
    relationship_type_id        mtl_related_items.relationship_type_id%TYPE,
    created_by                  mtl_system_items.created_by%TYPE,
    last_updated_by             mtl_system_items.last_updated_by%TYPE,
    status                      VARCHAR2(10),
    sf_id                       VARCHAR2(240),
    category_set_id             NUMBER,
    category_id                 NUMBER);

  TYPE item_onhand_rec_type IS RECORD(
    onhand_quantities_id NUMBER,
    inventory_item_id    NUMBER,
    segment1             VARCHAR2(240),
    organization_id      NUMBER,
    organization_code    VARCHAR2(3),
    subinventory_code    VARCHAR2(10),
    sf_product_id        VARCHAR2(240),
    revision_name        VARCHAR2(200),
    onhand_quantity      NUMBER,
    is_consigned         NUMBER,
    subinv_disable_date  DATE,
    subinv_attribute11   VARCHAR2(240),
    created_by           NUMBER,
    last_updated_by      NUMBER);

  -- --------------------------------------------------------------------------------------------
  -- Name:              send_mail
  -- Create by:         Diptasurjya Chatterjee
  -- Revision:          1.0
  -- Creation date:     22/06/2015
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0036886
  --          Send Mail for errors
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  27/10/2015  Diptasurjya Chatterjee             Initial Build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE send_mail(p_program_name_to IN VARCHAR2,
	          p_program_name_cc IN VARCHAR2,
	          p_entity          IN VARCHAR2,
	          p_body            IN VARCHAR2,
	          p_api_phase       IN VARCHAR2 DEFAULT NULL);

  -- --------------------------------------------------------------------------------------------
  -- Name:              check_item_eligibility
  -- Create by:         Diptasurjya Chatterjee
  -- Revision:          1.0
  -- Creation date:     27/10/2015
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0036886
  --          This function will be used to check if item is eligible for interfacing
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  27/10/2015  Diptasurjya Chatterjee             Initial Build
  -- --------------------------------------------------------------------------------------------
  FUNCTION check_item_eligibility(p_customer_order_enabled VARCHAR2,
		          p_item_status_code       VARCHAR2,
		          p_inventory_item_id      NUMBER)
    RETURN VARCHAR2;

  -- --------------------------------------------------------------------------------------------
  -- Name:              item_trigger_processor
  -- Create by:         Diptasurjya Chatterjee
  -- Revision:          1.0
  -- Creation date:     27/10/2015
  -- Calling Entity:    Trigger: XXINV_ITEM_AIUR_TRG1, XXINV_ITEM_XREF_AIUR_TRG1
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0036886
  --          This function will be used for processing all activated triggers
  --          for item/cross-reference creation or update or delete
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  27/10/2015  Diptasurjya Chatterjee             Initial Build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE item_trigger_processor(p_old_item_rec   IN item_rec_type,
		           p_new_item_rec   IN item_rec_type,
		           p_trigger_name   IN VARCHAR2,
		           p_trigger_action IN VARCHAR2);

  -- --------------------------------------------------------------------------------------------
  -- Name:              item_onhand_trigger_processor
  -- Create by:         Diptasurjya Chatterjee
  -- Revision:          1.0
  -- Creation date:     26/10/2015
  -- Calling Entity:    Trigger: XXINV_ITEM_ONHAND_AIUR_TRG1
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0036886
  --          This function will be used for processing all activated triggers
  --          for item onhand create/update/delete
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  26/10/2015  Diptasurjya Chatterjee             Initial Build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE item_onhand_trigger_processor(p_old_item_rec   IN item_onhand_rec_type,
			      p_new_item_rec   IN item_onhand_rec_type,
			      p_trigger_name   IN VARCHAR2,
			      p_trigger_action IN VARCHAR2);

  -- --------------------------------------------------------------------------------------------
  -- Name:              item_subinv_trigger_processor
  -- Create by:         Diptasurjya Chatterjee
  -- Revision:          1.0
  -- Creation date:     23/11/2015
  -- Calling Entity:    Trigger: XXINV_SECONDARY_INV_AUR_TRG2
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0036886
  --          This function will be used for processing all onhand events
  --          for change in subinventory SF eligibility
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  23/11/2015  Diptasurjya Chatterjee             Initial Build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE item_subinv_trigger_processor(p_old_onhand_rec IN item_onhand_rec_type,
			      p_new_onhand_rec IN item_onhand_rec_type,
			      p_trigger_name   IN VARCHAR2,
			      p_trigger_action IN VARCHAR2);

  -- --------------------------------------------------------------------------------------------
  -- Name:              is_valid_subinventory
  -- Create by:         yuval tal
  -- Revision:          1.0
  -- Creation date:     23/11/2015
  -- Calling Entity:    
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0036886
  --          This function will be used for checking  subinventory if valid  for pronto sync  
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  23/11/2015  yuval tal                            Initial Build
  -- --------------------------------------------------------------------------------------------
  FUNCTION is_valid_subinventory(p_sub_inventory_code VARCHAR2)
    RETURN VARCHAR2;

END xxinv_pronto_event_pkg;
/
