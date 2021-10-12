CREATE OR REPLACE PACKAGE xxinv_ecomm_event_pkg AUTHID CURRENT_USER AS
  ----------------------------------------------------------------------------
  --  name:            xxinv_ecomm_event_pkg
  --  create by:       Diptasurjya Chatterjee (TCS)
  --  Revision:        1.0
  --  creation date:   22/06/2015
  ----------------------------------------------------------------------------
  --  purpose :        CHG0035652 - Generic container package to handle all
  --                   inventory module related event invocations. For item
  --                   as no suitable business events were identified, triggers
  --                   has been created on base tables and processed by this API
  ----------------------------------------------------------------------------
  --  ver  date        name                         desc
  --  1.0  22/06/2015  Diptasurjya Chatterjee(TCS)  CHG0035652 - initial build
  --  1.1  29/06/2015  Diptasurjya Chatterjee(TCS)  CHG0035700 - printer flavor 
  --                                                relation trigger processor
  ----------------------------------------------------------------------------

  TYPE item_rec_type IS RECORD(inventory_item_id           mtl_system_items.inventory_item_id%type,
                               segment1                    mtl_system_items.segment1%type,
                               organization_id             mtl_system_items.organization_id%type,
                               description                 mtl_system_items.description%type,
                               primary_unit_of_measure     mtl_system_items.primary_unit_of_measure%type,
                               hazardous_material_flag     mtl_system_items.hazardous_material_flag%type,
                               dimension_uom_code          mtl_system_items.dimension_uom_code%type,
                               unit_length                 mtl_system_items.unit_length%type,
                               unit_width                  mtl_system_items.unit_width%type,
                               unit_height                 mtl_system_items.unit_height%type,
                               weight_uom_code             mtl_system_items.weight_uom_code%type,
                               unit_weight                 mtl_system_items.unit_weight%type,
                               technology                  mtl_categories_b.Segment6%type,
                               pack                        mtl_cross_references_b.attribute7%type,
                               color                       mtl_cross_references_b.attribute8%type,
                               flavor                      mtl_cross_references_b.attribute9%type,
                               created_by                  mtl_system_items.created_by%type,
                               last_updated_by             mtl_system_items.last_updated_by%type,
                               orderable_on_web_flag       mtl_system_items.orderable_on_web_flag%type,
                               customer_order_enabled_flag mtl_system_items.customer_order_enabled_flag%type,
                               category_set_id             mtl_item_categories.category_set_id%type,
                               category_id                 mtl_item_categories.category_id%type,
                               status                      VARCHAR2(10),
                               source                      VARCHAR2(150)
                               );
  
  TYPE printer_flavor_rec_type IS RECORD(flex_value_set_id     number,
                                         flex_value_set_name   varchar2(60),
                                         flex_value_id         number,
                                         flavor_name           varchar2(200),
                                         printer_name          varchar2(200),
                                         created_by            number,
                                         last_updated_by       number,
                                         status                varchar2(10));
  
  -- --------------------------------------------------------------------------------------------
  -- Name:              compare_old_new_items
  -- Create by:         Diptasurjya Chatterjee
  -- Revision:          1.0
  -- Creation date:     22/06/2015                            
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035652
  --          This function will be used to compare item before update with item after update
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  22/06/2015  Diptasurjya Chatterjee             Initial Build
  -- --------------------------------------------------------------------------------------------

  function compare_old_new_items (p_old_item_rec item_rec_type,
                                  p_new_item_rec item_rec_type) RETURN VARCHAR2;


  -- --------------------------------------------------------------------------------------------
  -- Name:              get_item_details
  -- Create by:         Diptasurjya Chatterjee
  -- Revision:          1.0
  -- Creation date:     22/06/2015
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035652
  --          This function will be used to fetch web-enabled attribute values for an item
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  22/06/2015  Diptasurjya Chatterjee             Initial Build
  -- --------------------------------------------------------------------------------------------

  function get_item_details(p_inventory_item_id IN NUMBER,
                         p_organization_id IN NUMBER) return item_rec_type;

  -- --------------------------------------------------------------------------------------------
  -- Name:              send_mail
  -- Create by:         Diptasurjya Chatterjee
  -- Revision:          1.0
  -- Creation date:     22/06/2015
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035652
  --          Send Mail for errors
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  22/06/2015  Diptasurjya Chatterjee             Initial Build
  -- --------------------------------------------------------------------------------------------

  procedure send_mail (p_program_name_to   IN varchar2,
                       p_program_name_cc   IN varchar2,
                       p_entity            IN varchar2,
                       p_body              IN varchar2,
                       p_api_phase         IN varchar2 DEFAULT NULL);

  -- --------------------------------------------------------------------------------------------
  -- Name:              item_trigger_processor
  -- Create by:         Diptasurjya Chatterjee
  -- Revision:          1.0
  -- Creation date:     22/06/2015
  -- Calling Entity:    Trigger: XXINV_ITEM_AIUR_TRG1, XXINV_ITEM_CAT_AIUR_TRG1, XXINV_ITEM_XREF_AIUR_TRG1
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035652
  --          This function will be used for processing all activated triggers
  --          for item/category/cross-reference creation or update or delete
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  22/06/2015  Diptasurjya Chatterjee             Initial Build
  -- --------------------------------------------------------------------------------------------

  procedure item_trigger_processor (p_old_item_rec   IN item_rec_type,
                                    p_new_item_rec   IN item_rec_type,
                                    p_trigger_name   IN varchar2,
                                    p_trigger_action IN varchar2);

  -- --------------------------------------------------------------------------------------------
  -- Name:              print_flav_trigger_processor
  -- Create by:         Diptasurjya Chatterjee
  -- Revision:          1.0
  -- Creation date:     29/06/2015
  -- Calling Entity:    Trigger: XXFND_VSET_VALUE_AIU_TRG1
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035700
  --          This function will be used for processing all activated triggers
  --          for value set values creation or update
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  29/06/2015  Diptasurjya Chatterjee             Initial Build
  -- --------------------------------------------------------------------------------------------                                  
                                    
  procedure print_flav_trigger_processor (p_old_print_flav_rec   IN printer_flavor_rec_type,
                                          p_new_print_flav_rec   IN printer_flavor_rec_type,
                                          p_trigger_name         IN varchar2,
                                          p_trigger_action       IN varchar2);                                  

END xxinv_ecomm_event_pkg;
/
