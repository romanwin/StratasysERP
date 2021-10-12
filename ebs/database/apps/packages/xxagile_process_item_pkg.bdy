CREATE OR REPLACE PACKAGE BODY xxagile_process_item_pkg IS

  ---------------------------------------------------------------------------
  -- $Header: xxagile_process_item_pkg   $
  ---------------------------------------------------------------------------
  -- Package: xxagile_process_item_pkg
  -- Created: 
  -- Author  : 
  --------------------------------------------------------------------------
  -- Perpose: xxagile_process_item_pkg
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --     1.x  14.3.13   yuval tal       12.1.3 project : modify create_item_revision
  --    

  /********************************************************************************************
   AudioCodes LTd.
   Package Name : ac_a2o_process_item_categ_pkg
   Description : Wrapper package containing all customer item category wrapper procedure for item interface from Agile System
   Written by : Vinay Chappidi
   Date : 05-Dec-2007
  
   Change History
   ==============
   Date         Name              Ver       Change Description
   -----        ---------------   --------  ----------------------------------
   05-Dec-2007  Vinay Chappidi    DRAFT1A   Created this package, Initial Version
  ********************************************************************************************/

  g_miss_num  CONSTANT NUMBER := 9.99e125;
  g_miss_char CONSTANT VARCHAR2(1) := chr(0);

  -- package body level fndlog variable for getting the current runtime level
  gn_debug_level CONSTANT NUMBER := fnd_log.g_current_runtime_level;
  gv_module_name CONSTANT VARCHAR2(50) := 'Process_Item_Interface';
  gv_level       CONSTANT VARCHAR2(240) := fnd_log.level_statement;
  gv_error_text VARCHAR2(2000);

  FUNCTION get_chr_val_from_template(p_template_id    NUMBER,
                                     p_attribute_name VARCHAR2)
    RETURN VARCHAR2 IS
  
    l_attr_templ_value VARCHAR2(240);
  
  BEGIN
  
    SELECT a.attribute_value
      INTO l_attr_templ_value
      FROM mtl_item_templ_attributes a
     WHERE template_id = p_template_id
       AND a.attribute_name = p_attribute_name;
  
    RETURN l_attr_templ_value;
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_chr_val_from_template;

  PROCEDURE init_app(p_user_id NUMBER, p_resp_id NUMBER) IS
  
    l_resp_app NUMBER;
    l_user_id  NUMBER;
  BEGIN
    /*
    SELECT user_id
      INTO l_user_id
      FROM fnd_user
     WHERE user_name = p_user_name;*/
  
    SELECT application_id
      INTO l_resp_app
      FROM fnd_responsibility
     WHERE responsibility_id = p_resp_id;
  
    fnd_global.apps_initialize(user_id      => l_user_id,
                               resp_id      => p_resp_id,
                               resp_appl_id => l_resp_app);
  
  END init_app;
  /********************************************************************************************
  AudioCodes LTd.
  Procedure Name : write_to_log
  Description : procedure will log messages to fnd_log_messages table when logging is enabled
  Written by : Vinay Chappidi
  Date : 05-Dec-2007
  ********************************************************************************************/
  PROCEDURE write_to_log(p_module IN VARCHAR2, p_msg IN VARCHAR2) IS
  BEGIN
    IF (gv_level >= gn_debug_level) THEN
      fnd_log.string(gv_level, gv_module_name || '.' || p_module, p_msg);
    END IF;
  END write_to_log;

  /********************************************************************************************
  AudioCodes LTd.
  Procedure Name : add_error_text
  Description : procedure will
  Written by : Vinay Chappidi
  Date : 05-Dec-2007
  ********************************************************************************************/
  PROCEDURE add_error_text(p_error_text IN VARCHAR2) IS
    n_gerror_length NUMBER;
    n_error_length  NUMBER;
  BEGIN
    n_gerror_length := nvl(length(gv_error_text), 0);
    n_error_length  := nvl(length(p_error_text), 0);
  
    ----autonomous_proc.dump_temp('Error:'||p_error_text||', Length:'||n_error_length||', Global Error:'||n_gerror_length);
  
    IF (n_gerror_length < 2000) THEN
      IF (((2000 - n_gerror_length) - 1) >= n_error_length) THEN
        IF (gv_error_text IS NULL) THEN
          gv_error_text := p_error_text;
        ELSE
          gv_error_text := gv_error_text || ' ' || p_error_text;
        END IF;
      
      ELSE
        gv_error_text := gv_error_text || ' ' ||
                         substr(p_error_text,
                                1,
                                (2000 - n_gerror_length) - 1);
      END IF;
    END IF;
    ----autonomous_proc.dump_temp('Returning Error Message: '||gv_error_text);
  END add_error_text;

  /********************************************************************************************
  AudioCodes LTd.
  Procedure Name : create_item_revision
  Description : will create a new version for a given item for all organizations
  Written by : Vinay Chappidi
  Date : 05-Dec-2007
  
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --     1.0  14.3.13   yuval tal       12.1.3 project : change call to inv_item_revision_pub.create_item_revision
  --                                           instead of ego_item_pub.process_item_revision
  ********************************************************************************************/
  PROCEDURE create_item_revision(p_transaction_type  IN VARCHAR2,
                                 p_inventory_item_id IN NUMBER,
                                 p_revision          IN VARCHAR2,
                                 p_description       IN VARCHAR2 DEFAULT NULL,
                                 p_effectivity_date  IN DATE DEFAULT SYSDATE,
                                 p_revision_label    IN VARCHAR2 DEFAULT ego_item_pub.g_miss_char,
                                 p_revision_reason   IN VARCHAR2 DEFAULT NULL,
                                 p_lifecycle_id      IN NUMBER DEFAULT ego_item_pub.g_miss_num,
                                 p_current_phase_id  IN NUMBER DEFAULT ego_item_pub.g_miss_num,
                                 x_return_status     OUT NOCOPY VARCHAR2,
                                 x_msg_data          OUT NOCOPY VARCHAR2) IS
  
    n_api_version   NUMBER := 1.0;
    v_init_msg_list VARCHAR2(1) := fnd_api.g_true;
    v_commit        VARCHAR2(1) := fnd_api.g_false;
  
    v_return_status VARCHAR2(1);
    n_msg_count     NUMBER;
    v_msg_data      VARCHAR2(2000);
    v_msg_text      VARCHAR2(2000);
    n_temp          NUMBER;
    v_rev_exist     NUMBER;
  
    lc_error_message VARCHAR2(2000);
    lc_entity_id     VARCHAR2(1000);
    lc_entity_type   VARCHAR2(1000);
    ln_count         NUMBER := 0;
  
    l_out_message   VARCHAR2(500);
    l_msg_index_out VARCHAR2(500);
  
    l_item_revision_rec inv_item_revision_pub.item_revision_rec_type;
    CURSOR lcu_get_inv_orgs(cp_inventory_item_id IN NUMBER) IS
      SELECT organization_id
        FROM mtl_system_items
       WHERE inventory_item_id = cp_inventory_item_id;
    --  AND organization_id = 91;
    l_exception EXCEPTION;
  BEGIN
  
    gv_error_text := NULL; -- remove this line
    IF (p_inventory_item_id IS NOT NULL AND p_transaction_type = 'CREATE' AND
       p_revision IS NOT NULL) THEN
      FOR revision_rec IN lcu_get_inv_orgs(p_inventory_item_id) LOOP
      
        BEGIN
          SELECT 1
            INTO v_rev_exist
            FROM mtl_item_revisions mi
           WHERE mi.revision = p_revision
             AND mi.inventory_item_id = p_inventory_item_id
             AND mi.organization_id = revision_rec.organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            v_rev_exist := 0;
        END;
        IF v_rev_exist = 0 THEN
        
          -- 12.1.3 
        
          dbms_output.put_line('revision_rec.organization_id=' ||
                               revision_rec.organization_id);
        
          l_item_revision_rec                   := inv_item_revision_pub.g_miss_item_revision_rec;
          l_item_revision_rec.inventory_item_id := p_inventory_item_id; --687015; -- Item Id 
          l_item_revision_rec.organization_id   := revision_rec.organization_id; --91; -- Organization Id 
          l_item_revision_rec.revision          := p_revision; -- 'B7'; -- Revision 
          l_item_revision_rec.description       := p_description; -- Revision description 
          -- l_item_revision_rec.change_notice     := NULL;
          l_item_revision_rec.transaction_type := p_transaction_type; --'CREATE';
          l_item_revision_rec.effectivity_date := p_effectivity_date; --'07-apr-13'; -- effectivity_date 
          l_item_revision_rec.revision_label   := p_revision_label;
          l_item_revision_rec.revision_reason  := p_revision_reason;
        
          l_item_revision_rec.lifecycle_id     := p_lifecycle_id;
          l_item_revision_rec.current_phase_id := p_current_phase_id;
        
          l_item_revision_rec.implementation_date := l_item_revision_rec.effectivity_date;
        
          inv_item_revision_pub.create_item_revision(p_api_version       => n_api_version,
                                                     p_commit            => v_commit,
                                                     p_init_msg_list     => v_init_msg_list,
                                                     p_validation_level  => fnd_api.g_valid_level_full,
                                                     p_item_revision_rec => l_item_revision_rec,
                                                     x_return_status     => v_return_status,
                                                     x_msg_count         => n_msg_count,
                                                     x_msg_data          => v_msg_data);
        
          --
          dbms_output.put_line('RETURN STATUS IS :' || v_return_status);
          add_error_text('Error :failed revision creation for org =' ||
                         revision_rec.organization_id);
        
          IF (v_return_status != 'S') THEN
            dbms_output.put_line(' MESSAGE :' || v_msg_data || ' ' ||
                                 n_msg_count);
            FOR i IN 1 .. n_msg_count LOOP
            
              fnd_msg_pub.get(p_msg_index     => i,
                              p_encoded       => 'F',
                              p_data          => l_out_message,
                              p_msg_index_out => l_msg_index_out);
              dbms_output.put_line('l_msg_data :' || l_out_message);
            
              add_error_text(l_out_message);
            
            END LOOP;
            RAISE l_exception;
          END IF;
        
          -- END 12.1.3 
        
          /* ego_item_pub.process_item_revision(p_api_version        => n_api_version,
          p_init_msg_list      => v_init_msg_list,
          p_commit             => v_commit,
          p_transaction_type   => p_transaction_type,
          p_inventory_item_id  => p_inventory_item_id,
          p_item_number        => ego_item_pub.g_miss_char,
          p_organization_id    => revision_rec.organization_id,
          p_organization_code  => ego_item_pub.g_miss_char,
          p_revision           => p_revision,
          p_description        => p_description,
          p_effectivity_date   => p_effectivity_date,
          p_revision_label     => p_revision_label,
          p_revision_reason    => p_revision_reason,
          p_lifecycle_id       => p_lifecycle_id,
          p_current_phase_id   => p_current_phase_id,
          p_attribute_category => ego_item_pub.g_miss_char,
          p_attribute1         => ego_item_pub.g_miss_char,
          p_attribute2         => ego_item_pub.g_miss_char,
          p_attribute3         => ego_item_pub.g_miss_char,
          p_attribute4         => ego_item_pub.g_miss_char,
          p_attribute5         => ego_item_pub.g_miss_char,
          p_attribute6         => ego_item_pub.g_miss_char,
          p_attribute7         => ego_item_pub.g_miss_char,
          p_attribute8         => ego_item_pub.g_miss_char,
          p_attribute9         => ego_item_pub.g_miss_char,
          p_attribute10        => ego_item_pub.g_miss_char,
          p_attribute11        => ego_item_pub.g_miss_char,
          p_attribute12        => ego_item_pub.g_miss_char,
          p_attribute13        => ego_item_pub.g_miss_char,
          p_attribute14        => ego_item_pub.g_miss_char,
          p_attribute15        => ego_item_pub.g_miss_char,
          x_return_status      => v_return_status,
          x_msg_count          => n_msg_count,
          x_msg_data           => v_msg_data);*/
        
          --autonomous_proc.dump_temp('Error 1: v_return_status=v_return_status'|| v_return_status);
          /*               IF (nvl(v_return_status, 'E') <> 'S') THEN
                            --autonomous_proc.dump_temp('Error 1:'|| n_msg_count);
                            IF (n_msg_count = 1) THEN
                               fnd_msg_pub.get(n_msg_count, 'F', v_msg_data, n_temp);
                               fnd_message.set_encoded(v_msg_text);
                               v_msg_text := fnd_message.get;
                               --autonomous_proc.dump_temp('Error 2:'|| v_msg_text);
                               add_error_text(v_msg_text);
                            ELSIF (n_msg_count > 1) THEN
                               FOR n_cnt IN 1 .. n_msg_count LOOP
                                  --autonomous_proc.dump_temp('Error 3:');
                                  fnd_msg_pub.get(n_cnt, 'F', v_msg_data, n_temp);
                                  fnd_message.set_encoded(v_msg_data);
                                  v_msg_text := fnd_message.get;
                                  --autonomous_proc.dump_temp('Error 4:'|| v_msg_text);
                                  add_error_text(v_msg_text);
                               END LOOP;
                            END IF;
                            RAISE l_exception;
                         END IF;
          */
        
          /*  IF (nvl(v_return_status, 'E') <> fnd_api.g_ret_sts_success) THEN
            FOR ro_msg_lst IN 1 .. n_msg_count LOOP
              ln_count := ro_msg_lst;
              error_handler.get_message(lc_error_message,
                                        ln_count,
                                        lc_entity_id,
                                        lc_entity_type);
              write_to_log('create_item_revision',
                           lc_error_message || ',Entity ID:' ||
                           lc_entity_id || ', Entity Type:' ||
                           lc_entity_type);
              add_error_text(lc_error_message);
            END LOOP;
            RAISE l_exception;
          END IF;*/
        
        END IF;
      END LOOP;
    END IF;
    x_return_status := 'S';
  
  EXCEPTION
    WHEN l_exception THEN
      x_return_status := 'E';
      x_msg_data      := gv_error_text;
    
    WHEN OTHERS THEN
      x_return_status := 'U';
      v_msg_text      := 'SQLCODE: ' || SQLCODE || ', SQL Error: ' ||
                         SQLERRM;
      add_error_text(v_msg_text);
      x_msg_data := gv_error_text;
  END create_item_revision;

  --------------------------------------------------------------------------------------------------------------------------------
  FUNCTION check_item_chr_value(p_template_id IN NUMBER,
                                p_agile_value IN VARCHAR2,
                                p_orig_value  IN VARCHAR2) RETURN VARCHAR2 IS
    lv_ret VARCHAR2(4000);
  BEGIN
  
    ----autonomous_proc.dump_temp('check_item_chr_value p_agile_value='||p_agile_value||'    p_orig_value=' || p_orig_value);
    RETURN nvl(p_orig_value, fnd_api.g_miss_char);
  
    SELECT nvl(p_agile_value,
               decode(p_template_id,
                      NULL,
                      nvl(p_orig_value, ego_item_pub.g_miss_char),
                      ego_item_pub.g_miss_char))
      INTO lv_ret
      FROM dual;
  
    RETURN lv_ret;
  EXCEPTION
    WHEN OTHERS THEN
      ----autonomous_proc.dump_temp(' error check_item_chr_value p_agile_value='||p_agile_value||'    p_orig_value=' || p_orig_value);
      RETURN nvl(p_agile_value, ego_item_pub.g_miss_char);
  END check_item_chr_value;
  --------------------------------------------------------------------------------------------------------------------------------
  FUNCTION check_item_num_value(p_template_id IN NUMBER,
                                p_agile_value IN NUMBER,
                                p_orig_value  IN VARCHAR2) RETURN NUMBER IS
    lv_ret NUMBER;
  BEGIN
  
    ----autonomous_proc.dump_temp('check_item_num_value p_agile_value='||p_agile_value||'    p_orig_value=' || p_orig_value);
    RETURN nvl(p_orig_value, fnd_api.g_miss_num);
  
    SELECT nvl(p_agile_value,
               decode(p_template_id,
                      NULL,
                      nvl(p_orig_value, ego_item_pub.g_miss_num),
                      ego_item_pub.g_miss_num))
      INTO lv_ret
      FROM dual;
  
    RETURN lv_ret;
  EXCEPTION
    WHEN OTHERS THEN
      ----autonomous_proc.dump_temp(' error check_item_num_value p_agile_value='||p_agile_value||'    p_orig_value=' || p_orig_value);
      RETURN nvl(p_agile_value, ego_item_pub.g_miss_num);
  END check_item_num_value;
  --------------------------------------------------------------------------------------------------------------------------------
  FUNCTION check_item_date_value(p_template_id IN NUMBER,
                                 p_agile_value IN DATE,
                                 p_orig_value  IN DATE) RETURN DATE IS
    lv_ret DATE;
  BEGIN
  
    RETURN nvl(p_orig_value, fnd_api.g_miss_date);
    ----autonomous_proc.dump_temp('check_item_date_value p_agile_value='||p_agile_value||'    p_orig_value=' || p_orig_value);
  
    SELECT nvl(p_agile_value,
               decode(p_template_id,
                      NULL,
                      nvl(p_orig_value, ego_item_pub.g_miss_date),
                      ego_item_pub.g_miss_date))
      INTO lv_ret
      FROM dual;
  
    RETURN lv_ret;
  EXCEPTION
    WHEN OTHERS THEN
      ----autonomous_proc.dump_temp(' error check_item_date_value p_agile_value='||p_agile_value||'    p_orig_value=' || p_orig_value);
      RETURN nvl(p_agile_value, ego_item_pub.g_miss_date);
  END check_item_date_value;
  --------------------------------------------------------------------------------------------------------------------------------

  FUNCTION nvl2_user(p_auto_serial_alpha_prefix_old VARCHAR2,
                     p_auto_serial_alpha_prefix_new VARCHAR2) RETURN VARCHAR2 IS
    auto_serial_alpha_prefix VARCHAR2(300);
  BEGIN
    SELECT nvl2(p_auto_serial_alpha_prefix_old,
                ego_item_pub.g_miss_char,
                p_auto_serial_alpha_prefix_new)
      INTO auto_serial_alpha_prefix
      FROM dual;
    RETURN auto_serial_alpha_prefix;
  END nvl2_user;

  /********************************************************************************************
  AudioCodes LTd.
  Procedure Name : process_item
  Description : procedure create items in all organizations depending on a organization profile
  Written by : Vinay Chappidi
  Date : 05-Dec-2007
  ********************************************************************************************/
  PROCEDURE process_item(p_transaction_type            IN VARCHAR2,
                         p_language_code               IN VARCHAR2,
                         p_template_id                 IN NUMBER DEFAULT NULL,
                         p_template_name               IN VARCHAR2,
                         p_copy_inventory_item_id      IN NUMBER DEFAULT NULL,
                         p_inventory_item_id           IN NUMBER DEFAULT NULL,
                         p_organization_id             IN NUMBER DEFAULT NULL,
                         p_master_organization_id      IN NUMBER DEFAULT NULL,
                         p_description                 IN VARCHAR2 DEFAULT NULL,
                         p_long_description            IN VARCHAR2 DEFAULT NULL,
                         p_primary_uom_code            IN VARCHAR2 DEFAULT NULL,
                         p_primary_unit_of_measure     IN VARCHAR2 DEFAULT NULL,
                         p_item_type                   IN VARCHAR2 DEFAULT NULL,
                         p_inventory_item_status_code  IN VARCHAR2 DEFAULT NULL,
                         p_allowed_units_lookup_code   IN NUMBER DEFAULT NULL,
                         p_item_catalog_group_id       IN NUMBER DEFAULT NULL,
                         p_catalog_status_flag         IN VARCHAR2 DEFAULT NULL,
                         p_inventory_item_flag         IN VARCHAR2 DEFAULT NULL,
                         p_stock_enabled_flag          IN VARCHAR2 DEFAULT NULL,
                         p_mtl_transactions_enabled_fl IN VARCHAR2 DEFAULT NULL,
                         p_check_shortages_flag        IN VARCHAR2 DEFAULT NULL,
                         p_revision_qty_control_code   IN NUMBER DEFAULT NULL,
                         p_reservable_type             IN NUMBER DEFAULT NULL,
                         p_shelf_life_code             IN NUMBER DEFAULT NULL,
                         p_shelf_life_days             IN NUMBER DEFAULT NULL,
                         p_cycle_count_enabled_flag    IN VARCHAR2 DEFAULT NULL,
                         p_negative_measurement_error  IN NUMBER DEFAULT NULL,
                         p_positive_measurement_error  IN NUMBER DEFAULT NULL,
                         p_lot_control_code            IN NUMBER DEFAULT NULL,
                         p_auto_lot_alpha_prefix       IN VARCHAR2 DEFAULT NULL,
                         p_start_auto_lot_number       IN VARCHAR2 DEFAULT NULL,
                         p_serial_number_control_code  IN NUMBER DEFAULT NULL,
                         p_auto_serial_alpha_prefix    IN VARCHAR2 DEFAULT NULL,
                         p_start_auto_serial_number    IN VARCHAR2 DEFAULT NULL,
                         p_location_control_code       IN NUMBER DEFAULT NULL,
                         p_restrict_subinventories_cod IN NUMBER DEFAULT NULL,
                         p_restrict_locators_code      IN NUMBER DEFAULT NULL,
                         p_bom_enabled_flag            IN VARCHAR2 DEFAULT NULL,
                         p_bom_item_type               IN NUMBER DEFAULT NULL,
                         p_base_item_id                IN NUMBER DEFAULT NULL,
                         p_effectivity_control         IN NUMBER DEFAULT NULL,
                         p_eng_item_flag               IN VARCHAR2 DEFAULT NULL,
                         p_engineering_ecn_code        IN VARCHAR2 DEFAULT NULL,
                         p_engineering_item_id         IN NUMBER DEFAULT NULL,
                         p_engineering_date            IN DATE DEFAULT NULL,
                         p_product_family_item_id      IN NUMBER DEFAULT NULL,
                         p_auto_created_config_flag    IN VARCHAR2 DEFAULT NULL,
                         p_model_config_clause_name    IN VARCHAR2 DEFAULT NULL,
                         p_new_revision_code           IN VARCHAR2 DEFAULT NULL,
                         p_costing_enabled_flag        IN VARCHAR2 DEFAULT NULL,
                         p_inventory_asset_flag        IN VARCHAR2 DEFAULT NULL,
                         p_default_include_in_rollup_f IN VARCHAR2 DEFAULT NULL,
                         p_cost_of_sales_account       IN NUMBER DEFAULT NULL,
                         p_std_lot_size                IN NUMBER DEFAULT NULL,
                         p_purchasing_item_flag        IN VARCHAR2 DEFAULT NULL,
                         p_purchasing_enabled_flag     IN VARCHAR2 DEFAULT NULL,
                         p_must_use_approved_vendor_fl IN VARCHAR2 DEFAULT NULL,
                         p_allow_item_desc_update_flag IN VARCHAR2 DEFAULT NULL,
                         p_rfq_required_flag           IN VARCHAR2 DEFAULT NULL,
                         p_outside_operation_flag      IN VARCHAR2 DEFAULT NULL,
                         p_outside_operation_uom_type  IN VARCHAR2 DEFAULT NULL,
                         p_taxable_flag                IN VARCHAR2 DEFAULT NULL,
                         p_purchasing_tax_code         IN VARCHAR2 DEFAULT NULL,
                         p_receipt_required_flag       IN VARCHAR2 DEFAULT NULL,
                         p_inspection_required_flag    IN VARCHAR2 DEFAULT NULL,
                         p_buyer_id                    IN NUMBER DEFAULT NULL,
                         p_unit_of_issue               IN VARCHAR2 DEFAULT NULL,
                         p_receive_close_tolerance     IN NUMBER DEFAULT NULL,
                         p_invoice_close_tolerance     IN NUMBER DEFAULT NULL,
                         p_un_number_id                IN NUMBER DEFAULT NULL,
                         p_hazard_class_id             IN NUMBER DEFAULT NULL,
                         p_list_price_per_unit         IN NUMBER DEFAULT NULL,
                         p_market_price                IN NUMBER DEFAULT NULL,
                         p_price_tolerance_percent     IN NUMBER DEFAULT NULL,
                         p_rounding_factor             IN NUMBER DEFAULT NULL,
                         p_encumbrance_account         IN NUMBER DEFAULT NULL,
                         p_expense_account             IN NUMBER DEFAULT NULL,
                         p_expense_billable_flag       IN VARCHAR2 DEFAULT NULL,
                         p_asset_category_id           IN NUMBER DEFAULT NULL,
                         p_receipt_days_exception_code IN VARCHAR2 DEFAULT NULL,
                         p_days_early_receipt_allowed  IN NUMBER DEFAULT NULL,
                         p_days_late_receipt_allowed   IN NUMBER DEFAULT NULL,
                         p_allow_substitute_receipts_f IN VARCHAR2 DEFAULT NULL,
                         p_allow_unordered_receipts_fl IN VARCHAR2 DEFAULT NULL,
                         p_allow_express_delivery_flag IN VARCHAR2 DEFAULT NULL,
                         p_qty_rcv_exception_code      IN VARCHAR2 DEFAULT NULL,
                         p_qty_rcv_tolerance           IN NUMBER DEFAULT NULL,
                         p_receiving_routing_id        IN NUMBER DEFAULT NULL,
                         p_enforce_ship_to_location_c  IN VARCHAR2 DEFAULT NULL,
                         p_weight_uom_code             IN VARCHAR2 DEFAULT NULL,
                         p_unit_weight                 IN NUMBER DEFAULT NULL,
                         p_volume_uom_code             IN VARCHAR2 DEFAULT NULL,
                         p_unit_volume                 IN NUMBER DEFAULT NULL,
                         p_container_item_flag         IN VARCHAR2 DEFAULT NULL,
                         p_vehicle_item_flag           IN VARCHAR2 DEFAULT NULL,
                         p_container_type_code         IN VARCHAR2 DEFAULT NULL,
                         p_internal_volume             IN NUMBER DEFAULT NULL,
                         p_maximum_load_weight         IN NUMBER DEFAULT NULL,
                         p_minimum_fill_percent        IN NUMBER DEFAULT NULL,
                         p_inventory_planning_code     IN NUMBER DEFAULT NULL,
                         p_planner_code                IN VARCHAR2 DEFAULT NULL,
                         p_planning_make_buy_code      IN NUMBER DEFAULT NULL,
                         p_min_minmax_quantity         IN NUMBER DEFAULT NULL,
                         p_max_minmax_quantity         IN NUMBER DEFAULT NULL,
                         p_minimum_order_quantity      IN NUMBER DEFAULT NULL,
                         p_maximum_order_quantity      IN NUMBER DEFAULT NULL,
                         p_order_cost                  IN NUMBER DEFAULT NULL,
                         p_carrying_cost               IN NUMBER DEFAULT NULL,
                         p_source_type                 IN NUMBER DEFAULT NULL,
                         p_source_organization_id      IN NUMBER DEFAULT NULL,
                         p_source_subinventory         IN VARCHAR2 DEFAULT NULL,
                         p_mrp_safety_stock_code       IN NUMBER DEFAULT NULL,
                         p_safety_stock_bucket_days    IN NUMBER DEFAULT NULL,
                         p_mrp_safety_stock_percent    IN NUMBER DEFAULT NULL,
                         p_fixed_order_quantity        IN NUMBER DEFAULT NULL,
                         p_fixed_days_supply           IN NUMBER DEFAULT NULL,
                         p_fixed_lot_multiplier        IN NUMBER DEFAULT NULL,
                         p_mrp_planning_code           IN NUMBER DEFAULT NULL,
                         p_ato_forecast_control        IN NUMBER DEFAULT NULL,
                         p_planning_exception_set      IN VARCHAR2 DEFAULT NULL,
                         p_end_assembly_pegging_flag   IN VARCHAR2 DEFAULT NULL,
                         p_shrinkage_rate              IN NUMBER DEFAULT NULL,
                         p_rounding_control_type       IN NUMBER DEFAULT NULL,
                         p_acceptable_early_days       IN NUMBER DEFAULT NULL,
                         p_repetitive_planning_flag    IN VARCHAR2 DEFAULT NULL,
                         p_overrun_percentage          IN NUMBER DEFAULT NULL,
                         p_acceptable_rate_increase    IN NUMBER DEFAULT NULL,
                         p_acceptable_rate_decrease    IN NUMBER DEFAULT NULL,
                         p_mrp_calculate_atp_flag      IN VARCHAR2 DEFAULT NULL,
                         p_auto_reduce_mps             IN NUMBER DEFAULT NULL,
                         p_planning_time_fence_code    IN NUMBER DEFAULT NULL,
                         p_planning_time_fence_days    IN NUMBER DEFAULT NULL,
                         p_demand_time_fence_code      IN NUMBER DEFAULT NULL,
                         p_demand_time_fence_days      IN NUMBER DEFAULT NULL,
                         p_release_time_fence_code     IN NUMBER DEFAULT NULL,
                         p_release_time_fence_days     IN NUMBER DEFAULT NULL,
                         p_preprocessing_lead_time     IN NUMBER DEFAULT NULL,
                         p_full_lead_time              IN NUMBER DEFAULT NULL,
                         p_postprocessing_lead_time    IN NUMBER DEFAULT NULL,
                         p_fixed_lead_time             IN NUMBER DEFAULT NULL,
                         p_variable_lead_time          IN NUMBER DEFAULT NULL,
                         p_cum_manufacturing_lead_time IN NUMBER DEFAULT NULL,
                         p_cumulative_total_lead_time  IN NUMBER DEFAULT NULL,
                         p_lead_time_lot_size          IN NUMBER DEFAULT NULL,
                         p_build_in_wip_flag           IN VARCHAR2 DEFAULT NULL,
                         p_wip_supply_type             IN NUMBER DEFAULT NULL,
                         p_wip_supply_subinventory     IN VARCHAR2 DEFAULT NULL,
                         p_wip_supply_locator_id       IN NUMBER DEFAULT NULL,
                         p_overcompletion_tolerance_ty IN NUMBER DEFAULT NULL,
                         p_overcompletion_tolerance_va IN NUMBER DEFAULT NULL,
                         p_customer_order_flag         IN VARCHAR2 DEFAULT NULL,
                         p_customer_order_enabled_flag IN VARCHAR2 DEFAULT NULL,
                         p_shippable_item_flag         IN VARCHAR2 DEFAULT NULL,
                         p_internal_order_flag         IN VARCHAR2 DEFAULT NULL,
                         p_internal_order_enabled_flag IN VARCHAR2 DEFAULT NULL,
                         p_so_transactions_flag        IN VARCHAR2 DEFAULT NULL,
                         p_pick_components_flag        IN VARCHAR2 DEFAULT NULL,
                         p_atp_flag                    IN VARCHAR2 DEFAULT NULL,
                         p_replenish_to_order_flag     IN VARCHAR2 DEFAULT NULL,
                         p_atp_rule_id                 IN NUMBER DEFAULT NULL,
                         p_atp_components_flag         IN VARCHAR2 DEFAULT NULL,
                         p_ship_model_complete_flag    IN VARCHAR2 DEFAULT NULL,
                         p_picking_rule_id             IN NUMBER DEFAULT NULL,
                         p_collateral_flag             IN VARCHAR2 DEFAULT NULL,
                         p_default_shipping_org        IN NUMBER DEFAULT NULL,
                         p_returnable_flag             IN VARCHAR2 DEFAULT NULL,
                         p_return_inspection_requireme IN NUMBER DEFAULT NULL,
                         p_over_shipment_tolerance     IN NUMBER DEFAULT NULL,
                         p_under_shipment_tolerance    IN NUMBER DEFAULT NULL,
                         p_over_return_tolerance       IN NUMBER DEFAULT NULL,
                         p_under_return_tolerance      IN NUMBER DEFAULT NULL,
                         p_invoiceable_item_flag       IN VARCHAR2 DEFAULT NULL,
                         p_invoice_enabled_flag        IN VARCHAR2 DEFAULT NULL,
                         p_accounting_rule_id          IN NUMBER DEFAULT NULL,
                         p_invoicing_rule_id           IN NUMBER DEFAULT NULL,
                         p_tax_code                    IN VARCHAR2 DEFAULT NULL,
                         p_sales_account               IN NUMBER DEFAULT NULL,
                         p_payment_terms_id            IN NUMBER DEFAULT NULL,
                         p_coverage_schedule_id        IN NUMBER DEFAULT NULL,
                         p_service_duration            IN NUMBER DEFAULT NULL,
                         p_service_duration_period_cod IN VARCHAR2 DEFAULT NULL,
                         p_serviceable_product_flag    IN VARCHAR2 DEFAULT NULL,
                         p_service_starting_delay      IN NUMBER DEFAULT NULL,
                         p_material_billable_flag      IN VARCHAR2 DEFAULT NULL,
                         p_serviceable_component_flag  IN VARCHAR2 DEFAULT NULL,
                         p_preventive_maintenance_flag IN VARCHAR2 DEFAULT NULL,
                         p_prorate_service_flag        IN VARCHAR2 DEFAULT NULL,
                         p_serviceable_item_class_id   IN NUMBER DEFAULT NULL,
                         p_base_warranty_service_id    IN NUMBER DEFAULT NULL,
                         p_warranty_vendor_id          IN NUMBER DEFAULT NULL,
                         p_max_warranty_amount         IN NUMBER DEFAULT NULL,
                         p_response_time_period_code   IN VARCHAR2 DEFAULT NULL,
                         p_response_time_value         IN NUMBER DEFAULT NULL,
                         p_primary_specialist_id       IN NUMBER DEFAULT NULL,
                         p_secondary_specialist_id     IN NUMBER DEFAULT NULL,
                         p_wh_update_date              IN DATE DEFAULT NULL,
                         p_equipment_type              IN NUMBER DEFAULT NULL,
                         p_recovered_part_disp_code    IN VARCHAR2 DEFAULT NULL,
                         p_defect_tracking_on_flag     IN VARCHAR2 DEFAULT NULL,
                         p_event_flag                  IN VARCHAR2 DEFAULT NULL,
                         p_electronic_flag             IN VARCHAR2 DEFAULT NULL,
                         p_downloadable_flag           IN VARCHAR2 DEFAULT NULL,
                         p_vol_discount_exempt_flag    IN VARCHAR2 DEFAULT NULL,
                         p_coupon_exempt_flag          IN VARCHAR2 DEFAULT NULL,
                         p_comms_nl_trackable_flag     IN VARCHAR2 DEFAULT NULL,
                         p_asset_creation_code         IN VARCHAR2 DEFAULT NULL,
                         p_comms_activation_reqd_flag  IN VARCHAR2 DEFAULT NULL,
                         p_orderable_on_web_flag       IN VARCHAR2 DEFAULT NULL,
                         p_back_orderable_flag         IN VARCHAR2 DEFAULT NULL,
                         p_web_status                  IN VARCHAR2 DEFAULT NULL,
                         p_indivisible_flag            IN VARCHAR2 DEFAULT NULL,
                         p_dimension_uom_code          IN VARCHAR2 DEFAULT NULL,
                         p_unit_length                 IN NUMBER DEFAULT NULL,
                         p_unit_width                  IN NUMBER DEFAULT NULL,
                         p_unit_height                 IN NUMBER DEFAULT NULL,
                         p_bulk_picked_flag            IN VARCHAR2 DEFAULT NULL,
                         p_lot_status_enabled          IN VARCHAR2 DEFAULT NULL,
                         p_default_lot_status_id       IN NUMBER DEFAULT NULL,
                         p_serial_status_enabled       IN VARCHAR2 DEFAULT NULL,
                         p_default_serial_status_id    IN NUMBER DEFAULT NULL,
                         p_lot_split_enabled           IN VARCHAR2 DEFAULT NULL,
                         p_lot_merge_enabled           IN VARCHAR2 DEFAULT NULL,
                         p_inventory_carry_penalty     IN NUMBER DEFAULT NULL,
                         p_operation_slack_penalty     IN NUMBER DEFAULT NULL,
                         p_financing_allowed_flag      IN VARCHAR2 DEFAULT NULL,
                         p_eam_item_type               IN NUMBER DEFAULT NULL,
                         p_eam_activity_type_code      IN VARCHAR2 DEFAULT NULL,
                         p_eam_activity_cause_code     IN VARCHAR2 DEFAULT NULL,
                         p_eam_act_notification_flag   IN VARCHAR2 DEFAULT NULL,
                         p_eam_act_shutdown_status     IN VARCHAR2 DEFAULT NULL,
                         p_dual_uom_control            IN NUMBER DEFAULT NULL,
                         p_secondary_uom_code          IN VARCHAR2 DEFAULT NULL,
                         p_dual_uom_deviation_high     IN NUMBER DEFAULT NULL,
                         p_dual_uom_deviation_low      IN NUMBER DEFAULT NULL,
                         p_contract_item_type_code     IN VARCHAR2 DEFAULT NULL,
                         p_subscription_depend_flag    IN VARCHAR2 DEFAULT NULL,
                         p_serv_req_enabled_code       IN VARCHAR2 DEFAULT NULL,
                         p_serv_billing_enabled_flag   IN VARCHAR2 DEFAULT NULL,
                         p_serv_importance_level       IN NUMBER DEFAULT NULL,
                         p_planned_inv_point_flag      IN VARCHAR2 DEFAULT NULL,
                         p_lot_translate_enabled       IN VARCHAR2 DEFAULT NULL,
                         p_default_so_source_type      IN VARCHAR2 DEFAULT NULL,
                         p_create_supply_flag          IN VARCHAR2 DEFAULT NULL,
                         p_substitution_window_code    IN NUMBER DEFAULT NULL,
                         p_substitution_window_days    IN NUMBER DEFAULT NULL,
                         p_ib_item_instance_class      IN VARCHAR2 DEFAULT NULL,
                         p_config_model_type           IN VARCHAR2 DEFAULT NULL,
                         p_lot_substitution_enabled    IN VARCHAR2 DEFAULT NULL,
                         p_minimum_license_quantity    IN NUMBER DEFAULT NULL,
                         p_eam_activity_source_code    IN VARCHAR2 DEFAULT NULL,
                         p_approval_status             IN VARCHAR2 DEFAULT NULL,
                         p_tracking_quantity_ind       IN VARCHAR2 DEFAULT NULL,
                         p_ont_pricing_qty_source      IN VARCHAR2 DEFAULT NULL,
                         p_secondary_default_ind       IN VARCHAR2 DEFAULT NULL,
                         p_option_specific_sourced     IN NUMBER DEFAULT NULL,
                         p_vmi_minimum_units           IN NUMBER DEFAULT NULL,
                         p_vmi_minimum_days            IN NUMBER DEFAULT NULL,
                         p_vmi_maximum_units           IN NUMBER DEFAULT NULL,
                         p_vmi_maximum_days            IN NUMBER DEFAULT NULL,
                         p_vmi_fixed_order_quantity    IN NUMBER DEFAULT NULL,
                         p_so_authorization_flag       IN NUMBER DEFAULT NULL,
                         p_consigned_flag              IN NUMBER DEFAULT NULL,
                         p_asn_autoexpire_flag         IN NUMBER DEFAULT NULL,
                         p_vmi_forecast_type           IN NUMBER DEFAULT NULL,
                         p_forecast_horizon            IN NUMBER DEFAULT NULL,
                         p_exclude_from_budget_flag    IN NUMBER DEFAULT NULL,
                         p_days_tgt_inv_supply         IN NUMBER DEFAULT NULL,
                         p_days_tgt_inv_window         IN NUMBER DEFAULT NULL,
                         p_days_max_inv_supply         IN NUMBER DEFAULT NULL,
                         p_days_max_inv_window         IN NUMBER DEFAULT NULL,
                         p_drp_planned_flag            IN NUMBER DEFAULT NULL,
                         p_critical_component_flag     IN NUMBER DEFAULT NULL,
                         p_continous_transfer          IN NUMBER DEFAULT NULL,
                         p_convergence                 IN NUMBER DEFAULT NULL,
                         p_divergence                  IN NUMBER DEFAULT NULL,
                         p_config_orgs                 IN VARCHAR2 DEFAULT NULL,
                         p_config_match                IN VARCHAR2 DEFAULT NULL,
                         p_item_number                 IN VARCHAR2,
                         p_segment1                    IN VARCHAR2 DEFAULT NULL,
                         p_segment2                    IN VARCHAR2 DEFAULT NULL,
                         p_segment3                    IN VARCHAR2 DEFAULT NULL,
                         p_segment4                    IN VARCHAR2 DEFAULT NULL,
                         p_segment5                    IN VARCHAR2 DEFAULT NULL,
                         p_segment6                    IN VARCHAR2 DEFAULT NULL,
                         p_segment7                    IN VARCHAR2 DEFAULT NULL,
                         p_segment8                    IN VARCHAR2 DEFAULT NULL,
                         p_segment9                    IN VARCHAR2 DEFAULT NULL,
                         p_segment10                   IN VARCHAR2 DEFAULT NULL,
                         p_segment11                   IN VARCHAR2 DEFAULT NULL,
                         p_segment12                   IN VARCHAR2 DEFAULT NULL,
                         p_segment13                   IN VARCHAR2 DEFAULT NULL,
                         p_segment14                   IN VARCHAR2 DEFAULT NULL,
                         p_segment15                   IN VARCHAR2 DEFAULT NULL,
                         p_segment16                   IN VARCHAR2 DEFAULT NULL,
                         p_segment17                   IN VARCHAR2 DEFAULT NULL,
                         p_segment18                   IN VARCHAR2 DEFAULT NULL,
                         p_segment19                   IN VARCHAR2 DEFAULT NULL,
                         p_segment20                   IN VARCHAR2 DEFAULT NULL,
                         p_summary_flag                IN VARCHAR2 DEFAULT NULL,
                         p_enabled_flag                IN VARCHAR2 DEFAULT NULL,
                         p_start_date_active           IN DATE DEFAULT NULL,
                         p_end_date_active             IN DATE DEFAULT NULL,
                         p_attribute_category          IN VARCHAR2 DEFAULT NULL,
                         p_attribute1                  IN VARCHAR2 DEFAULT NULL,
                         p_attribute2                  IN VARCHAR2 DEFAULT NULL,
                         p_attribute3                  IN VARCHAR2 DEFAULT NULL,
                         p_attribute4                  IN VARCHAR2 DEFAULT NULL,
                         p_attribute5                  IN VARCHAR2 DEFAULT NULL,
                         p_attribute6                  IN VARCHAR2 DEFAULT NULL,
                         p_attribute7                  IN VARCHAR2 DEFAULT NULL,
                         p_attribute8                  IN VARCHAR2 DEFAULT NULL,
                         p_attribute9                  IN VARCHAR2 DEFAULT NULL,
                         p_attribute10                 IN VARCHAR2 DEFAULT NULL,
                         p_attribute11                 IN VARCHAR2 DEFAULT NULL,
                         p_attribute12                 IN VARCHAR2 DEFAULT NULL,
                         p_attribute13                 IN VARCHAR2 DEFAULT NULL,
                         p_attribute14                 IN VARCHAR2 DEFAULT NULL,
                         p_attribute15                 IN VARCHAR2 DEFAULT NULL,
                         p_global_attribute_category   IN VARCHAR2 DEFAULT NULL,
                         p_global_attribute1           IN VARCHAR2 DEFAULT NULL,
                         p_global_attribute2           IN VARCHAR2 DEFAULT NULL,
                         p_global_attribute3           IN VARCHAR2 DEFAULT NULL,
                         p_global_attribute4           IN VARCHAR2 DEFAULT NULL,
                         p_global_attribute5           IN VARCHAR2 DEFAULT NULL,
                         p_global_attribute6           IN VARCHAR2 DEFAULT NULL,
                         p_global_attribute7           IN VARCHAR2 DEFAULT NULL,
                         p_global_attribute8           IN VARCHAR2 DEFAULT NULL,
                         p_global_attribute9           IN VARCHAR2 DEFAULT NULL,
                         p_global_attribute10          IN VARCHAR2 DEFAULT NULL,
                         p_creation_date               IN DATE DEFAULT NULL,
                         p_created_by                  IN NUMBER DEFAULT NULL,
                         p_last_update_date            IN DATE DEFAULT NULL,
                         p_last_updated_by             IN NUMBER DEFAULT NULL,
                         p_last_update_login           IN NUMBER DEFAULT NULL,
                         p_request_id                  IN NUMBER DEFAULT NULL,
                         p_program_application_id      IN NUMBER DEFAULT NULL,
                         p_program_id                  IN NUMBER DEFAULT NULL,
                         p_program_update_date         IN DATE DEFAULT NULL,
                         p_lifecycle_id                IN NUMBER DEFAULT NULL,
                         p_current_phase_id            IN NUMBER DEFAULT NULL,
                         p_revision_id                 IN NUMBER DEFAULT NULL,
                         p_revision_code               IN VARCHAR2 DEFAULT NULL,
                         p_revision_label              IN VARCHAR2 DEFAULT NULL,
                         p_revision_description        IN VARCHAR2 DEFAULT NULL,
                         p_effectivity_date            IN DATE DEFAULT NULL,
                         p_rev_lifecycle_id            IN NUMBER DEFAULT NULL,
                         p_rev_current_phase_id        IN NUMBER DEFAULT NULL,
                         p_rev_attribute_category      IN VARCHAR2 DEFAULT NULL,
                         p_rev_attribute1              IN VARCHAR2 DEFAULT NULL,
                         p_rev_attribute2              IN VARCHAR2 DEFAULT NULL,
                         p_rev_attribute3              IN VARCHAR2 DEFAULT NULL,
                         p_rev_attribute4              IN VARCHAR2 DEFAULT NULL,
                         p_rev_attribute5              IN VARCHAR2 DEFAULT NULL,
                         p_rev_attribute6              IN VARCHAR2 DEFAULT NULL,
                         p_rev_attribute7              IN VARCHAR2 DEFAULT NULL,
                         p_rev_attribute8              IN VARCHAR2 DEFAULT NULL,
                         p_rev_attribute9              IN VARCHAR2 DEFAULT NULL,
                         p_rev_attribute10             IN VARCHAR2 DEFAULT NULL,
                         p_rev_attribute11             IN VARCHAR2 DEFAULT NULL,
                         p_rev_attribute12             IN VARCHAR2 DEFAULT NULL,
                         p_rev_attribute13             IN VARCHAR2 DEFAULT NULL,
                         p_rev_attribute14             IN VARCHAR2 DEFAULT NULL,
                         p_rev_attribute15             IN VARCHAR2 DEFAULT NULL,
                         p_apply_template              IN VARCHAR2 DEFAULT NULL,
                         p_object_version_number       IN NUMBER DEFAULT NULL,
                         px_inventory_item_id          OUT NOCOPY NUMBER,
                         px_organization_id            OUT NOCOPY NUMBER,
                         px_return_status              OUT NOCOPY VARCHAR2,
                         px_msg_count                  OUT NOCOPY NUMBER,
                         px_msg_data                   OUT NOCOPY VARCHAR2) IS
  
    -- get the opetaing unit id for the provided operating unit name
    CURSOR lcu_get_org_id(cp_org_name IN VARCHAR2) IS
      SELECT organization_id operating_unit_id
        FROM hr_all_organization_units
       WHERE NAME = cp_org_name;
    n_org_id NUMBER;
    -- for the operating unit id get the profile value AC_AGILE_ITEM_ORG_ASSIG
    v_item_org_assign_profile fnd_profile_option_values.profile_option_value%TYPE;
    -- Get all Inventory Organizations depending on the system profile AC_AGILE_ITEM_ORG_ASSIG
  
    CURSOR lcu_get_inv_orgs(cp_org_id      IN NUMBER,
                            cp_org_context IN VARCHAR2) IS
      SELECT mp.organization_id        inventory_org_id,
             mp.master_organization_id master_organization_id
        FROM /*hr_all_organization_units haou, */ mtl_parameters mp
       WHERE mp.organization_id = cp_org_id /*haou.organization_id AND
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   haou.NAME = 'OMA - Objet Master (IO)'*/
      ;
  
    lr_get_inv_orgs lcu_get_inv_orgs%ROWTYPE;
  
    -- if the attribute2 is not having a value then treat it as not updateable
    -- get all parameters which are not updateable and use them in checking if there is a
    -- value for these parameters when the api is invoked.
    CURSOR lcu_check_field_update(cp_lookup_type    IN VARCHAR2,
                                  cp_update_allowed IN VARCHAR2) IS
      SELECT lookup_code
        FROM fnd_lookup_values_vl
       WHERE lookup_type = cp_lookup_type
         AND nvl(attribute2, cp_update_allowed) = cp_update_allowed;
  
    -- get the items based on the item number
    -- for modifying item attributes
    CURSOR lcu_mtl_items(cp_item_number IN VARCHAR2) IS
      SELECT msi.*, mp.master_organization_id
        FROM mtl_system_items msi, mtl_parameters mp
       WHERE msi.segment1 = cp_item_number
         AND msi.organization_id = mp.organization_id
       ORDER BY decode(msi.organization_id, mp.master_organization_id, 1, 2);
  
    lr_mtl_items_rec lcu_mtl_items%ROWTYPE;
  
    -- cursor to check if the revision is already existing
    -- if exists then revision is not created
    CURSOR lcu_check_revision(cp_inventory_item_id IN NUMBER,
                              cp_revision          IN VARCHAR2) IS
      SELECT 1
        FROM mtl_item_revisions mir, mtl_parameters mp
       WHERE mir.inventory_item_id = cp_inventory_item_id
         AND mir.revision = cp_revision
         AND mir.organization_id = mp.master_organization_id;
  
    CURSOR lcu_get_prim_uom_code(cp_uom_name IN VARCHAR2) IS
      SELECT uom_code, unit_of_measure
        FROM mtl_units_of_measure_tl
       WHERE nvl(attribute1, uom_code) = cp_uom_name
         AND LANGUAGE = 'US';
  
    CURSOR lcu_get_uom_code(cp_uom_name IN VARCHAR2) IS
      SELECT uom_code
        FROM mtl_units_of_measure_vl
       WHERE uom_code = cp_uom_name;
  
    CURSOR lcu_get_obj_version_num(cp_inventory_item_id IN NUMBER,
                                   cp_organization_id   IN NUMBER) IS
      SELECT object_version_number
        FROM mtl_system_items_b
       WHERE inventory_item_id = cp_inventory_item_id
         AND organization_id = cp_organization_id;
  
    CURSOR lcu_template(cp_temp_name       IN VARCHAR2,
                        cp_organization_id IN NUMBER) IS
      SELECT template_id
        FROM mtl_item_templates
       WHERE template_name = cp_temp_name
         AND (context_organization_id = cp_organization_id OR
             context_organization_id IS NULL);
  
    CURSOR lcu_template_orig(cp_temp_name IN VARCHAR2) IS
      SELECT ffvt.description
        FROM fnd_flex_value_sets ffvs,
             fnd_flex_values     ffv,
             fnd_flex_values_tl  ffvt
       WHERE upper(ffvs.flex_value_set_name) =
             upper('AC_Agile_Item_Template')
         AND ffv.flex_value_set_id = ffvs.flex_value_set_id
         AND ffvt.flex_value_id = ffv.flex_value_id
         AND ffv.enabled_flag = 'Y'
         AND SYSDATE BETWEEN nvl(ffv.start_date_active, SYSDATE) AND
             nvl(ffv.end_date_active, SYSDATE)
         AND ffv.flex_value = cp_temp_name;
  
    v_primary_uom_code     mtl_system_items.primary_uom_code%TYPE;
    v_primary_unit_of_meas mtl_system_items.primary_unit_of_measure%TYPE;
    v_weight_uom_code      mtl_system_items.weight_uom_code%TYPE;
    v_volume_uom_code      mtl_system_items.volume_uom_code%TYPE;
    v_dimension_uom_code   mtl_system_items.dimension_uom_code%TYPE;
    v_secondary_uom_code   mtl_system_items.secondary_uom_code%TYPE;
  
    l_error_tbl error_handler.error_tbl_type;
  
    n_msg_count          NUMBER;
    v_msg_data           VARCHAR2(2000);
    v_api_return_status  VARCHAR2(30);
    n_api_return_org_id  NUMBER;
    n_inv_item_id        NUMBER;
    d_effectivity_date   DATE;
    v_template_name      VARCHAR(240);
    v_template_name_temp VARCHAR(240);
    v_update_template    NUMBER;
    v_category           VARCHAR2(100);
    v_category_m         VARCHAR2(50);
    v_category_c         VARCHAR2(50);
    v_temp_date          DATE;
    n_temp_num           NUMBER;
    n_user_id            NUMBER := 0;
    v_item_status_code   VARCHAR2(50);
    v_family             VARCHAR2(50);
    v_group              VARCHAR2(50);
    v_unit_weight        VARCHAR2(15);
    v_length             VARCHAR2(15);
    v_width              VARCHAR2(15);
    v_height             VARCHAR2(15);
  
    l_exception               EXCEPTION;
    l_item_creation_exception EXCEPTION;
    l_template_exception      EXCEPTION;
    l_misc_exception          EXCEPTION;
    n_api_input_org_id NUMBER;
  
    v_mandatory_cols     VARCHAR2(1000);
    b_man_parameters     BOOLEAN := FALSE;
    lc_error_message     VARCHAR2(2000);
    lc_entity_id         VARCHAR2(1000);
    lc_entity_type       VARCHAR2(1000);
    ln_count             NUMBER := 0;
    n_object_version_num NUMBER;
    n_template_id        NUMBER;
  
    n_customer_enabled_flag    mtl_system_items_b.customer_order_enabled_flag%TYPE;
    n_serviceable_product_flag mtl_system_items_b.serviceable_product_flag%TYPE;
    n_comms_nl_trackable_flag  mtl_system_items_b.comms_nl_trackable_flag%TYPE;
    n_customer_order_flag      mtl_system_items_b.customer_order_flag%TYPE;
  
  BEGIN
    --init_app(p_created_by,50623);
  
    IF p_unit_weight IS NOT NULL THEN
      v_weight_uom_code := 'KG';
    END IF;
  
    IF p_segment2 IS NOT NULL AND p_segment2 LIKE '%x% ' THEN
      v_length := substr(p_segment2, 1, instr(p_segment2, 'x') - 1);
      v_width  := substr(substr(p_segment2, instr(p_segment2, 'x') + 1),
                         1,
                         instr(p_segment2, 'x') - 1);
      v_height := REPLACE(REPLACE(REPLACE(p_segment2, v_length, NULL),
                                  v_width,
                                  NULL),
                          'xx',
                          NULL);
    ELSIF p_segment2 IS NOT NULL AND p_segment2 LIKE '%*% ' THEN
      v_length := substr(p_segment2, 1, instr(p_segment2, '*') - 1);
      v_width  := substr(substr(p_segment2, instr(p_segment2, '*') + 1),
                         1,
                         instr(p_segment2, '*') - 1);
      v_height := REPLACE(REPLACE(REPLACE(p_segment2, v_length, NULL),
                                  v_width,
                                  NULL),
                          '**',
                          NULL);
    END IF;
  
    -- initialize this package level variable it will comtain previous error messages when this is not initialized
    gv_error_text := NULL;
    write_to_log('process_item',
                 'Transaction Type :' || p_transaction_type);
    --IF (upper(p_transaction_type) = 'CREATE') THEN
    --   n_user_id := 0; --nvl(p_created_by,0);
    --ELSIF (upper(p_transaction_type) = 'UPDATE') THEN
    --   n_user_id := 0; --nvl(p_last_updated_by,0);
    --END IF;
    SELECT user_id INTO n_user_id FROM fnd_user WHERE user_name = 'AGILE';
  
    write_to_log('process_item', 'User ID :' || n_user_id);
    -- set the apps context  
    IF fnd_global.user_id = -1 THEN
      -- Added due to 10g Upgrade Gabriel Coronel 18/05/2008      
      fnd_global.apps_initialize(n_user_id, 50623, 660);
    END IF;
  
    -- get the UOM codes for the UOM names provided
    IF (nvl(p_primary_uom_code, p_primary_unit_of_measure) IS NOT NULL) OR
       p_template_name = 'OBJ_Document' THEN
      OPEN lcu_get_prim_uom_code(nvl(nvl(p_primary_uom_code,
                                         p_primary_unit_of_measure),
                                     'EA'));
      FETCH lcu_get_prim_uom_code
        INTO v_primary_uom_code, v_primary_unit_of_meas;
      CLOSE lcu_get_prim_uom_code;
    END IF;
  
    -- get the UOM codes for the UOM names provided
    IF (p_weight_uom_code IS NOT NULL) THEN
      OPEN lcu_get_uom_code(p_weight_uom_code);
      FETCH lcu_get_uom_code
        INTO v_weight_uom_code;
      CLOSE lcu_get_uom_code;
    END IF;
  
    -- get the UOM codes for the UOM names provided
    IF (p_volume_uom_code IS NOT NULL) THEN
      OPEN lcu_get_uom_code(p_volume_uom_code);
      FETCH lcu_get_uom_code
        INTO v_volume_uom_code;
      CLOSE lcu_get_uom_code;
    END IF;
  
    -- get the UOM codes for the UOM names provided
    IF (p_dimension_uom_code IS NOT NULL) THEN
      OPEN lcu_get_uom_code(p_dimension_uom_code);
      FETCH lcu_get_uom_code
        INTO v_dimension_uom_code;
      CLOSE lcu_get_uom_code;
    END IF;
    IF p_segment2 IS NOT NULL THEN
      v_dimension_uom_code := 'CM';
    END IF;
    -- get the UOM codes for the UOM names provided
    IF (p_secondary_uom_code IS NOT NULL) THEN
      OPEN lcu_get_uom_code(p_secondary_uom_code);
      FETCH lcu_get_uom_code
        INTO v_secondary_uom_code;
      CLOSE lcu_get_uom_code;
    END IF;
  
    write_to_log('process_item', 'Operating Unit Name :' || p_attribute13);
  
    --Commented by Ella 03-AUG-2009 - The organization should be always MASTER 
    n_org_id := fnd_profile.value('ORG_ID');
    /* IF (p_transaction_type = 'CREATE') THEN
    
       -- check if the operating unit id could be determined
       -- incase it is null then assign error message to the out parameter and
       -- raise exception
       IF (n_org_id IS NULL) THEN
          fnd_message.set_name('ACCST', 'AC_CST_A2O_INVALID_OU');
          fnd_message.set_token('OU_NAME', p_attribute13);
          RAISE l_exception;
       END IF;
    
       -- get the value of the system profile ACCST_AGILE_ITEM_ORG_ASSIG
       -- this profile value is set at the org level, 10006 is hardcoded to get the value at the Org level
       v_item_org_assign_profile := fnd_profile.value_specific(org_id => n_org_id,
                                                               NAME   => 'AC_AGILE_ITEM_ORG_ASSIG');
       write_to_log('process_item',
                    'Profile Value :' || v_item_org_assign_profile ||
                    ' is set for Organization ID:' || n_org_id);
    
       -- check the profile value, if it is null then the current item will be assigned to
       -- all inventory organizations.
       IF (nvl(v_item_org_assign_profile, 'ALL') = 'OU') THEN
          n_api_input_org_id := n_org_id;
       ELSE
          n_api_input_org_id := NULL;
       END IF;
    END IF;
    */
    -- if the transaction type is update then check if any of the non updateable fields are passed.
    IF (p_transaction_type = 'CREATE') THEN
      IF (p_planning_make_buy_code IS NOT NULL) THEN
        v_mandatory_cols := 'P_PLANNING_MAKE_BUY_CODE';
        ----autonomous_proc.dump_temp('p_planning_make_buy_code is not null');
        b_man_parameters := TRUE;
      END IF;
    
      IF v_primary_uom_code IS NULL THEN
        px_msg_data := 'UOM Does Not Exist';
        RAISE l_misc_exception;
      END IF;
      -- if the transaction type is update then check if any of the non updateable fields are passed.
    ELSIF (p_transaction_type = 'UPDATE') THEN
      IF (p_primary_uom_code IS NOT NULL AND (p_primary_uom_code <> '!')) THEN
        IF NOT (b_man_parameters) THEN
          v_mandatory_cols := 'P_PRIMARY_UOM_CODE';
          b_man_parameters := TRUE;
        ELSE
          v_mandatory_cols := v_mandatory_cols || ', ' ||
                              'P_PRIMARY_UOM_CODE';
        END IF;
      END IF;
    
      IF (p_created_by IS NOT NULL) THEN
        IF NOT (b_man_parameters) THEN
          v_mandatory_cols := 'P_CREATED_BY';
          b_man_parameters := TRUE;
        ELSE
          v_mandatory_cols := v_mandatory_cols || ', ' || 'P_CREATED_BY';
        END IF;
      END IF;
    
      IF (p_creation_date IS NOT NULL) THEN
        IF NOT (b_man_parameters) THEN
          v_mandatory_cols := 'P_CREATION_DATE';
          b_man_parameters := TRUE;
        ELSE
          v_mandatory_cols := v_mandatory_cols || ', ' || 'P_CREATION_DATE';
        END IF;
      END IF;
    END IF;
  
    IF b_man_parameters THEN
      write_to_log('process_item',
                   initcap(p_transaction_type) ||
                   ' not allowed parameters: ' || v_mandatory_cols);
      ----autonomous_proc.dump_temp(initcap(p_transaction_type)||' not allowed parameters: '||v_mandatory_cols);
      fnd_message.set_name('ACCST', 'AC_CST_A2O_NO_CRT_UPDT');
      fnd_message.set_token('TRAN_TYPE', initcap(p_transaction_type));
      fnd_message.set_token('PARAMS', v_mandatory_cols);
      RAISE l_exception;
    END IF;
  
    -- effectivity date can be current system date and future date
    -- cannot be less than the sysdate
    IF (p_effectivity_date IS NULL OR p_effectivity_date < SYSDATE) THEN
      d_effectivity_date := SYSDATE;
    ELSE
      d_effectivity_date := p_effectivity_date; -- this is for future dated effectivity
    END IF;
  
    --Check If Category Not Exist -> Error
    BEGIN
      SELECT MAX(xa.creation_date),
             xa.category_seg1,
             xa.category_seg2,
             xa.cgroup,
             xa.family
        INTO v_temp_date, v_category_c, v_category_m, v_group, v_family
        FROM xxobjt_agile_items xa
       WHERE xa.item_number = p_item_number
         AND xa.attribute1 IS NULL
       GROUP BY xa.category_seg1, xa.category_seg2, xa.cgroup, xa.family;
    EXCEPTION
      WHEN OTHERS THEN
        v_msg_data   := SQLERRM;
        v_category_c := NULL;
        v_category_m := NULL;
    END;
  
    IF (p_transaction_type = 'CREATE') AND
       (v_category_c IS NULL OR v_category_m IS NULL) THEN
      px_msg_data := 'Category Does Not Exist';
      RAISE l_misc_exception;
    ELSE
      --Update Or Category Is Not Null
    
      BEGIN
        SELECT category_concat_segs
          INTO v_category_c
          FROM mtl_category_sets_v mcs, mtl_categories_v mc
         WHERE mcs.category_set_name = 'Class Category Set'
           AND mcs.structure_id = mc.structure_id
           AND mc.category_concat_segs LIKE '%' || v_category_c || '%'
           AND rownum = 1;
      EXCEPTION
        WHEN no_data_found THEN
          v_category_c := NULL;
      END;
    
      BEGIN
        SELECT category_concat_segs
          INTO v_category_m
          FROM mtl_category_sets_v mcs, mtl_categories_v mc
         WHERE mcs.category_set_name = 'Main Category Set'
           AND mcs.structure_id = mc.structure_id
           AND mc.category_concat_segs = v_category_m;
      EXCEPTION
        WHEN no_data_found THEN
          v_category_m := NULL;
      END;
    
      --Item creation - No Category/Wrong Category = Error (v_temp_date Will have a value).                 
      --Item update   - No Category = Continue/Wrong Category = Error(v_temp_date Will have a value).                  
      IF v_category_c IS NULL OR v_category_m IS NULL THEN
        px_msg_data := 'Category Does Not Exist';
        RAISE l_misc_exception;
      END IF;
    
    END IF;
  
    IF instr(p_revision_code, '-') > 0 THEN
      px_msg_data := 'Revision Contain "-"';
      RAISE l_misc_exception;
    END IF;
  
    IF p_inventory_item_status_code IS NULL THEN
      px_msg_data := 'Life Cycle Phase Is Empty';
      RAISE l_misc_exception;
    ELSE
      BEGIN
        SELECT m.inventory_item_status_code
          INTO v_item_status_code
          FROM mtl_item_status_tl m
         WHERE m.inventory_item_status_code_tl =
               p_inventory_item_status_code
           AND m.language = 'US';
      EXCEPTION
        WHEN no_data_found THEN
          px_msg_data := 'Life Cycle Phase Not Exist';
          RAISE l_misc_exception;
      END;
    END IF;
  
    --TEMP !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    IF p_template_name = 'OBJ_Service Courses & Trainings' THEN
      v_template_name_temp := 'OBJ_Service Courses';
    ELSE
      v_template_name_temp := p_template_name;
    END IF;
    ---------------
    BEGIN
      SELECT template_id
        INTO n_template_id
        FROM mtl_item_templates mit
       WHERE upper(mit.template_name) = upper(v_template_name_temp);
    EXCEPTION
      WHEN OTHERS THEN
        n_template_id := NULL;
        px_msg_data   := 'Template Does Not Exist';
        RAISE l_misc_exception;
    END;
  
    n_api_input_org_id := xxinv_utils_pkg.get_master_organization_id;
  
    IF (p_transaction_type = 'CREATE') THEN
    
      -- get all inventory organizations depending on the value returned from the above profile
      -- if ALL then we shall assign the item to all inventory organizations
      -- if OU then we have to assign to only to those inventory organizations for the current operating unit.
    
      OPEN lcu_get_inv_orgs(n_api_input_org_id, 'Accounting Information');
      LOOP
        FETCH lcu_get_inv_orgs
          INTO lr_get_inv_orgs;
        EXIT WHEN lcu_get_inv_orgs%NOTFOUND;
      
        write_to_log('process_item',
                     'Invoking Process Item with following parameters: Template Name: ' ||
                     v_template_name_temp || ', Master Organization ID: ' ||
                     lr_get_inv_orgs.master_organization_id ||
                     ', Inventory Organization ID:' ||
                     lr_get_inv_orgs.inventory_org_id);
        ego_item_pub.process_item(p_api_version                 => '1.0',
                                  p_init_msg_list               => ego_item_pub.g_true,
                                  p_commit                      => ego_item_pub.g_false,
                                  p_transaction_type            => p_transaction_type,
                                  p_language_code               => p_language_code,
                                  p_template_id                 => n_template_id,
                                  p_template_name               => NULL,
                                  p_copy_inventory_item_id      => p_copy_inventory_item_id,
                                  p_inventory_item_id           => p_inventory_item_id,
                                  p_organization_id             => lr_get_inv_orgs.inventory_org_id,
                                  p_master_organization_id      => lr_get_inv_orgs.master_organization_id,
                                  p_description                 => nvl(p_description,
                                                                       g_miss_char),
                                  p_long_description            => p_long_description,
                                  p_primary_uom_code            => nvl(v_primary_uom_code,
                                                                       'EA'), --p_primary_unit_of_measure,--nvl(v_primary_uom_code, G_MISS_CHAR) , Arik
                                  p_primary_unit_of_measure     => nvl(v_primary_unit_of_meas,
                                                                       'EACH'),
                                  p_item_type                   => nvl(p_item_type,
                                                                       g_miss_char),
                                  p_inventory_item_status_code  => nvl(v_item_status_code,
                                                                       g_miss_char),
                                  p_allowed_units_lookup_code   => nvl(p_allowed_units_lookup_code,
                                                                       g_miss_num),
                                  p_item_catalog_group_id       => p_item_catalog_group_id,
                                  p_catalog_status_flag         => p_catalog_status_flag,
                                  p_inventory_item_flag         => nvl(p_inventory_item_flag,
                                                                       g_miss_char),
                                  p_stock_enabled_flag          => nvl(p_stock_enabled_flag,
                                                                       g_miss_char),
                                  p_mtl_transactions_enabled_fl => nvl(p_mtl_transactions_enabled_fl,
                                                                       g_miss_char),
                                  p_check_shortages_flag        => nvl(p_check_shortages_flag,
                                                                       g_miss_char),
                                  p_revision_qty_control_code   => nvl(p_revision_qty_control_code,
                                                                       g_miss_num),
                                  p_reservable_type             => nvl(p_reservable_type,
                                                                       g_miss_num),
                                  p_shelf_life_code             => nvl(p_shelf_life_code,
                                                                       g_miss_num),
                                  p_shelf_life_days             => nvl(p_shelf_life_days,
                                                                       g_miss_num),
                                  p_cycle_count_enabled_flag    => nvl(p_cycle_count_enabled_flag,
                                                                       g_miss_char),
                                  p_negative_measurement_error  => nvl(p_negative_measurement_error,
                                                                       g_miss_num),
                                  p_positive_measurement_error  => nvl(p_positive_measurement_error,
                                                                       g_miss_num),
                                  p_lot_control_code            => nvl(p_lot_control_code,
                                                                       g_miss_num),
                                  p_auto_lot_alpha_prefix       => nvl(p_auto_lot_alpha_prefix,
                                                                       g_miss_char),
                                  p_start_auto_lot_number       => nvl(p_start_auto_lot_number,
                                                                       g_miss_char),
                                  p_serial_number_control_code  => nvl(p_serial_number_control_code,
                                                                       g_miss_num),
                                  p_auto_serial_alpha_prefix    => nvl(p_auto_serial_alpha_prefix,
                                                                       g_miss_char),
                                  p_start_auto_serial_number    => nvl(p_start_auto_serial_number,
                                                                       g_miss_char),
                                  p_location_control_code       => nvl(p_location_control_code,
                                                                       g_miss_num),
                                  p_restrict_subinventories_cod => nvl(p_restrict_subinventories_cod,
                                                                       g_miss_num),
                                  p_restrict_locators_code      => nvl(p_restrict_locators_code,
                                                                       g_miss_num),
                                  p_bom_enabled_flag            => nvl(p_bom_enabled_flag,
                                                                       g_miss_char),
                                  p_bom_item_type               => nvl(p_bom_item_type,
                                                                       g_miss_num),
                                  p_base_item_id                => nvl(p_base_item_id,
                                                                       g_miss_num),
                                  p_effectivity_control         => nvl(p_effectivity_control,
                                                                       g_miss_num),
                                  p_eng_item_flag               => p_eng_item_flag,
                                  p_engineering_ecn_code        => p_engineering_ecn_code,
                                  p_engineering_item_id         => p_engineering_item_id,
                                  p_engineering_date            => p_engineering_date,
                                  p_product_family_item_id      => p_product_family_item_id,
                                  p_auto_created_config_flag    => p_auto_created_config_flag,
                                  p_model_config_clause_name    => p_model_config_clause_name,
                                  p_new_revision_code           => substr(p_new_revision_code,
                                                                          1,
                                                                          3),
                                  p_costing_enabled_flag        => nvl(p_costing_enabled_flag,
                                                                       g_miss_char),
                                  p_inventory_asset_flag        => nvl(p_inventory_asset_flag,
                                                                       g_miss_char),
                                  p_default_include_in_rollup_f => nvl(p_default_include_in_rollup_f,
                                                                       g_miss_char),
                                  p_cost_of_sales_account       => nvl(p_cost_of_sales_account,
                                                                       g_miss_num),
                                  p_std_lot_size                => nvl(p_std_lot_size,
                                                                       g_miss_num),
                                  p_purchasing_item_flag        => nvl(p_purchasing_item_flag,
                                                                       g_miss_char),
                                  p_purchasing_enabled_flag     => nvl(p_purchasing_enabled_flag,
                                                                       g_miss_char),
                                  p_must_use_approved_vendor_fl => nvl(p_must_use_approved_vendor_fl,
                                                                       g_miss_char),
                                  p_allow_item_desc_update_flag => nvl(p_allow_item_desc_update_flag,
                                                                       g_miss_char),
                                  p_rfq_required_flag           => nvl(p_rfq_required_flag,
                                                                       g_miss_char),
                                  p_outside_operation_flag      => nvl(p_outside_operation_flag,
                                                                       g_miss_char),
                                  p_outside_operation_uom_type  => nvl(p_outside_operation_uom_type,
                                                                       g_miss_char),
                                  p_taxable_flag                => nvl(p_taxable_flag,
                                                                       g_miss_char),
                                  p_purchasing_tax_code         => nvl(p_purchasing_tax_code,
                                                                       g_miss_char),
                                  p_receipt_required_flag       => nvl(p_receipt_required_flag,
                                                                       g_miss_char),
                                  p_inspection_required_flag    => nvl(p_inspection_required_flag,
                                                                       g_miss_char),
                                  p_buyer_id                    => nvl(p_buyer_id,
                                                                       g_miss_num), --  getting error saying that the value passed is invalid INV_IOI_BUYER_ID
                                  p_unit_of_issue               => nvl(p_unit_of_issue,
                                                                       g_miss_char),
                                  p_receive_close_tolerance     => nvl(p_receive_close_tolerance,
                                                                       g_miss_num),
                                  p_invoice_close_tolerance     => nvl(p_invoice_close_tolerance,
                                                                       g_miss_num),
                                  p_un_number_id                => nvl(p_un_number_id,
                                                                       g_miss_num),
                                  p_hazard_class_id             => nvl(p_hazard_class_id,
                                                                       g_miss_num),
                                  p_list_price_per_unit         => nvl(p_list_price_per_unit,
                                                                       g_miss_num),
                                  p_market_price                => nvl(p_market_price,
                                                                       g_miss_num),
                                  p_price_tolerance_percent     => nvl(p_price_tolerance_percent,
                                                                       g_miss_num),
                                  p_rounding_factor             => nvl(p_rounding_factor,
                                                                       g_miss_num),
                                  p_encumbrance_account         => nvl(p_encumbrance_account,
                                                                       g_miss_num),
                                  p_expense_account             => nvl(p_expense_account,
                                                                       g_miss_num),
                                  p_expense_billable_flag       => p_expense_billable_flag,
                                  p_asset_category_id           => nvl(p_asset_category_id,
                                                                       g_miss_num),
                                  p_receipt_days_exception_code => nvl(p_receipt_days_exception_code,
                                                                       g_miss_char),
                                  p_days_early_receipt_allowed  => nvl(p_days_early_receipt_allowed,
                                                                       g_miss_num),
                                  p_days_late_receipt_allowed   => nvl(p_days_late_receipt_allowed,
                                                                       g_miss_num),
                                  p_allow_substitute_receipts_f => nvl(p_allow_substitute_receipts_f,
                                                                       g_miss_char),
                                  p_allow_unordered_receipts_fl => nvl(p_allow_unordered_receipts_fl,
                                                                       g_miss_char),
                                  p_allow_express_delivery_flag => nvl(p_allow_express_delivery_flag,
                                                                       g_miss_char),
                                  p_qty_rcv_exception_code      => nvl(p_qty_rcv_exception_code,
                                                                       g_miss_char),
                                  p_qty_rcv_tolerance           => nvl(p_qty_rcv_tolerance,
                                                                       g_miss_num),
                                  p_receiving_routing_id        => nvl(p_receiving_routing_id,
                                                                       g_miss_num),
                                  p_enforce_ship_to_location_c  => nvl(p_enforce_ship_to_location_c,
                                                                       g_miss_char),
                                  p_weight_uom_code             => nvl(v_weight_uom_code,
                                                                       g_miss_char), --nvl(v_weight_uom_code, G_MISS_CHAR) ,
                                  p_unit_weight                 => nvl(p_unit_weight,
                                                                       g_miss_num),
                                  p_volume_uom_code             => nvl(v_volume_uom_code,
                                                                       g_miss_char),
                                  p_unit_volume                 => nvl(p_unit_volume,
                                                                       g_miss_num),
                                  p_container_item_flag         => NULL, --nvl(p_container_item_flag, G_MISS_CHAR) ,   Arik
                                  p_vehicle_item_flag           => NULL, --nvl(p_vehicle_item_flag, G_MISS_CHAR) ,  Arik
                                  p_container_type_code         => nvl(p_container_type_code,
                                                                       g_miss_char),
                                  p_internal_volume             => nvl(p_internal_volume,
                                                                       g_miss_num),
                                  p_maximum_load_weight         => nvl(p_maximum_load_weight,
                                                                       g_miss_num),
                                  p_minimum_fill_percent        => nvl(p_minimum_fill_percent,
                                                                       g_miss_num),
                                  p_inventory_planning_code     => nvl(p_inventory_planning_code,
                                                                       g_miss_num),
                                  p_planner_code                => nvl(p_planner_code,
                                                                       g_miss_char),
                                  p_planning_make_buy_code      => nvl(p_planning_make_buy_code,
                                                                       g_miss_num),
                                  p_min_minmax_quantity         => nvl(p_min_minmax_quantity,
                                                                       g_miss_num),
                                  p_max_minmax_quantity         => nvl(p_max_minmax_quantity,
                                                                       g_miss_num),
                                  p_minimum_order_quantity      => nvl(p_minimum_order_quantity,
                                                                       g_miss_num),
                                  p_maximum_order_quantity      => nvl(p_maximum_order_quantity,
                                                                       g_miss_num),
                                  p_order_cost                  => nvl(p_order_cost,
                                                                       g_miss_num),
                                  p_carrying_cost               => nvl(p_carrying_cost,
                                                                       g_miss_num),
                                  p_source_type                 => nvl(p_source_type,
                                                                       g_miss_num),
                                  p_source_organization_id      => nvl(p_source_organization_id,
                                                                       g_miss_num),
                                  p_source_subinventory         => nvl(p_source_subinventory,
                                                                       g_miss_char),
                                  p_mrp_safety_stock_code       => nvl(p_mrp_safety_stock_code,
                                                                       g_miss_num),
                                  p_safety_stock_bucket_days    => nvl(p_safety_stock_bucket_days,
                                                                       g_miss_num),
                                  p_mrp_safety_stock_percent    => nvl(p_mrp_safety_stock_percent,
                                                                       g_miss_num),
                                  p_fixed_order_quantity        => nvl(p_fixed_order_quantity,
                                                                       g_miss_num),
                                  p_fixed_days_supply           => nvl(p_fixed_days_supply,
                                                                       g_miss_num),
                                  p_fixed_lot_multiplier        => nvl(p_fixed_lot_multiplier,
                                                                       g_miss_num),
                                  p_mrp_planning_code           => nvl(p_mrp_planning_code,
                                                                       g_miss_num),
                                  p_ato_forecast_control        => nvl(p_ato_forecast_control,
                                                                       g_miss_num),
                                  p_planning_exception_set      => nvl(p_planning_exception_set,
                                                                       g_miss_char),
                                  p_end_assembly_pegging_flag   => nvl(p_end_assembly_pegging_flag,
                                                                       g_miss_char),
                                  p_shrinkage_rate              => nvl(p_shrinkage_rate,
                                                                       g_miss_num),
                                  p_rounding_control_type       => nvl(p_rounding_control_type,
                                                                       g_miss_num),
                                  p_acceptable_early_days       => nvl(p_acceptable_early_days,
                                                                       g_miss_num),
                                  p_repetitive_planning_flag    => nvl(p_repetitive_planning_flag,
                                                                       g_miss_char),
                                  p_overrun_percentage          => nvl(p_overrun_percentage,
                                                                       g_miss_num),
                                  p_acceptable_rate_increase    => nvl(p_acceptable_rate_increase,
                                                                       g_miss_num),
                                  p_acceptable_rate_decrease    => nvl(p_acceptable_rate_decrease,
                                                                       g_miss_num),
                                  p_mrp_calculate_atp_flag      => nvl(p_mrp_calculate_atp_flag,
                                                                       g_miss_char),
                                  p_auto_reduce_mps             => nvl(p_auto_reduce_mps,
                                                                       g_miss_num),
                                  p_planning_time_fence_code    => nvl(p_planning_time_fence_code,
                                                                       g_miss_num),
                                  p_planning_time_fence_days    => nvl(p_planning_time_fence_days,
                                                                       g_miss_num),
                                  p_demand_time_fence_code      => nvl(p_demand_time_fence_code,
                                                                       g_miss_num),
                                  p_demand_time_fence_days      => nvl(p_demand_time_fence_days,
                                                                       g_miss_num),
                                  p_release_time_fence_code     => nvl(p_release_time_fence_code,
                                                                       g_miss_num),
                                  p_release_time_fence_days     => nvl(p_release_time_fence_days,
                                                                       g_miss_num),
                                  p_preprocessing_lead_time     => nvl(p_preprocessing_lead_time,
                                                                       g_miss_num),
                                  p_full_lead_time              => nvl(p_full_lead_time,
                                                                       g_miss_num),
                                  p_postprocessing_lead_time    => nvl(p_postprocessing_lead_time,
                                                                       g_miss_num),
                                  p_fixed_lead_time             => nvl(p_fixed_lead_time,
                                                                       g_miss_num),
                                  p_variable_lead_time          => nvl(p_variable_lead_time,
                                                                       g_miss_num),
                                  p_cum_manufacturing_lead_time => nvl(p_cum_manufacturing_lead_time,
                                                                       g_miss_num),
                                  p_cumulative_total_lead_time  => nvl(p_cumulative_total_lead_time,
                                                                       g_miss_num),
                                  p_lead_time_lot_size          => nvl(p_lead_time_lot_size,
                                                                       g_miss_num),
                                  p_build_in_wip_flag           => nvl(p_build_in_wip_flag,
                                                                       g_miss_char),
                                  p_wip_supply_type             => nvl(p_wip_supply_type,
                                                                       g_miss_num),
                                  p_wip_supply_subinventory     => nvl(p_wip_supply_subinventory,
                                                                       g_miss_char),
                                  p_wip_supply_locator_id       => nvl(p_wip_supply_locator_id,
                                                                       g_miss_num),
                                  p_overcompletion_tolerance_ty => nvl(p_overcompletion_tolerance_ty,
                                                                       g_miss_num),
                                  p_overcompletion_tolerance_va => nvl(p_overcompletion_tolerance_va,
                                                                       g_miss_num),
                                  p_customer_order_flag         => nvl(p_customer_order_flag,
                                                                       g_miss_char),
                                  p_customer_order_enabled_flag => nvl(p_customer_order_enabled_flag,
                                                                       g_miss_char),
                                  p_shippable_item_flag         => nvl(p_shippable_item_flag,
                                                                       g_miss_char),
                                  p_internal_order_flag         => nvl(p_internal_order_flag,
                                                                       g_miss_char),
                                  p_internal_order_enabled_flag => nvl(p_internal_order_enabled_flag,
                                                                       g_miss_char),
                                  p_so_transactions_flag        => nvl(p_so_transactions_flag,
                                                                       g_miss_char),
                                  p_pick_components_flag        => nvl(p_pick_components_flag,
                                                                       g_miss_char),
                                  p_atp_flag                    => nvl(p_atp_flag,
                                                                       g_miss_char),
                                  p_replenish_to_order_flag     => nvl(p_replenish_to_order_flag,
                                                                       g_miss_char),
                                  p_atp_rule_id                 => nvl(p_atp_rule_id,
                                                                       g_miss_num),
                                  p_atp_components_flag         => nvl(p_atp_components_flag,
                                                                       g_miss_char),
                                  p_ship_model_complete_flag    => nvl(p_ship_model_complete_flag,
                                                                       g_miss_char),
                                  p_picking_rule_id             => nvl(p_picking_rule_id,
                                                                       g_miss_num),
                                  p_collateral_flag             => NULL, --nvl(p_collateral_flag, G_MISS_CHAR) , Arik
                                  p_default_shipping_org        => nvl(p_default_shipping_org,
                                                                       g_miss_num),
                                  p_returnable_flag             => NULL, --nvl(p_returnable_flag, G_MISS_CHAR) ,  Arik
                                  p_return_inspection_requireme => nvl(p_return_inspection_requireme,
                                                                       g_miss_num),
                                  p_over_shipment_tolerance     => nvl(p_over_shipment_tolerance,
                                                                       g_miss_num),
                                  p_under_shipment_tolerance    => nvl(p_under_shipment_tolerance,
                                                                       g_miss_num),
                                  p_over_return_tolerance       => nvl(p_over_return_tolerance,
                                                                       g_miss_num),
                                  p_under_return_tolerance      => nvl(p_under_return_tolerance,
                                                                       g_miss_num),
                                  p_invoiceable_item_flag       => nvl(p_invoiceable_item_flag,
                                                                       g_miss_char),
                                  p_invoice_enabled_flag        => nvl(p_invoice_enabled_flag,
                                                                       g_miss_char),
                                  p_accounting_rule_id          => nvl(p_accounting_rule_id,
                                                                       g_miss_num),
                                  p_invoicing_rule_id           => nvl(p_invoicing_rule_id,
                                                                       g_miss_num),
                                  p_tax_code                    => nvl(p_tax_code,
                                                                       g_miss_char),
                                  p_sales_account               => nvl(p_sales_account,
                                                                       g_miss_num),
                                  p_payment_terms_id            => nvl(p_payment_terms_id,
                                                                       g_miss_num),
                                  p_coverage_schedule_id        => nvl(p_coverage_schedule_id,
                                                                       g_miss_num),
                                  p_service_duration            => nvl(p_service_duration,
                                                                       g_miss_num),
                                  p_service_duration_period_cod => nvl(p_service_duration_period_cod,
                                                                       g_miss_char),
                                  p_serviceable_product_flag    => nvl(p_serviceable_product_flag,
                                                                       g_miss_char),
                                  p_service_starting_delay      => nvl(p_service_starting_delay,
                                                                       g_miss_num),
                                  p_material_billable_flag      => nvl(p_material_billable_flag,
                                                                       g_miss_char),
                                  p_serviceable_component_flag  => p_serviceable_component_flag,
                                  p_preventive_maintenance_flag => p_preventive_maintenance_flag,
                                  p_prorate_service_flag        => p_prorate_service_flag,
                                  p_serviceable_item_class_id   => p_serviceable_item_class_id,
                                  p_base_warranty_service_id    => p_base_warranty_service_id,
                                  p_warranty_vendor_id          => p_warranty_vendor_id,
                                  p_max_warranty_amount         => p_max_warranty_amount,
                                  p_response_time_period_code   => p_response_time_period_code,
                                  p_response_time_value         => p_response_time_value,
                                  p_primary_specialist_id       => p_primary_specialist_id,
                                  p_secondary_specialist_id     => p_secondary_specialist_id,
                                  p_wh_update_date              => p_wh_update_date,
                                  p_equipment_type              => nvl(p_equipment_type,
                                                                       g_miss_num),
                                  p_recovered_part_disp_code    => nvl(p_recovered_part_disp_code,
                                                                       g_miss_char),
                                  p_defect_tracking_on_flag     => nvl(p_defect_tracking_on_flag,
                                                                       g_miss_char),
                                  p_event_flag                  => nvl(p_event_flag,
                                                                       g_miss_char),
                                  p_electronic_flag             => nvl(p_electronic_flag,
                                                                       g_miss_char),
                                  p_downloadable_flag           => nvl(p_downloadable_flag,
                                                                       g_miss_char),
                                  p_vol_discount_exempt_flag    => nvl(p_vol_discount_exempt_flag,
                                                                       g_miss_char),
                                  p_coupon_exempt_flag          => nvl(p_coupon_exempt_flag,
                                                                       g_miss_char),
                                  p_comms_nl_trackable_flag     => nvl(p_comms_nl_trackable_flag,
                                                                       g_miss_char),
                                  p_asset_creation_code         => nvl(p_asset_creation_code,
                                                                       g_miss_char),
                                  p_comms_activation_reqd_flag  => nvl(p_comms_activation_reqd_flag,
                                                                       g_miss_char),
                                  p_orderable_on_web_flag       => nvl(p_orderable_on_web_flag,
                                                                       g_miss_char),
                                  p_back_orderable_flag         => nvl(p_back_orderable_flag,
                                                                       g_miss_char),
                                  p_web_status                  => nvl(p_web_status,
                                                                       g_miss_char),
                                  p_indivisible_flag            => nvl(p_indivisible_flag,
                                                                       g_miss_char),
                                  p_dimension_uom_code          => nvl(v_dimension_uom_code,
                                                                       g_miss_char),
                                  p_unit_length                 => v_length,
                                  p_unit_width                  => v_width,
                                  p_unit_height                 => v_height,
                                  p_bulk_picked_flag            => nvl(p_bulk_picked_flag,
                                                                       g_miss_char),
                                  p_lot_status_enabled          => nvl(p_lot_status_enabled,
                                                                       g_miss_char),
                                  p_default_lot_status_id       => nvl(p_default_lot_status_id,
                                                                       g_miss_num),
                                  p_serial_status_enabled       => nvl(p_serial_status_enabled,
                                                                       g_miss_char),
                                  p_default_serial_status_id    => nvl(p_default_serial_status_id,
                                                                       g_miss_num),
                                  p_lot_split_enabled           => nvl(p_lot_split_enabled,
                                                                       g_miss_char),
                                  p_lot_merge_enabled           => nvl(p_lot_merge_enabled,
                                                                       g_miss_char),
                                  p_inventory_carry_penalty     => nvl(p_inventory_carry_penalty,
                                                                       g_miss_num),
                                  p_operation_slack_penalty     => nvl(p_operation_slack_penalty,
                                                                       g_miss_num),
                                  p_financing_allowed_flag      => nvl(p_financing_allowed_flag,
                                                                       g_miss_char),
                                  p_eam_item_type               => nvl(p_eam_item_type,
                                                                       g_miss_num),
                                  p_eam_activity_type_code      => nvl(p_eam_activity_type_code,
                                                                       g_miss_char),
                                  p_eam_activity_cause_code     => nvl(p_eam_activity_cause_code,
                                                                       g_miss_char),
                                  p_eam_act_notification_flag   => nvl(p_eam_act_notification_flag,
                                                                       g_miss_char),
                                  p_eam_act_shutdown_status     => nvl(p_eam_act_shutdown_status,
                                                                       g_miss_char),
                                  p_dual_uom_control            => nvl(p_dual_uom_control,
                                                                       g_miss_num),
                                  p_secondary_uom_code          => nvl(v_secondary_uom_code,
                                                                       g_miss_char),
                                  p_dual_uom_deviation_high     => nvl(p_dual_uom_deviation_high,
                                                                       g_miss_num),
                                  p_dual_uom_deviation_low      => nvl(p_dual_uom_deviation_low,
                                                                       g_miss_num),
                                  p_contract_item_type_code     => nvl(p_contract_item_type_code,
                                                                       g_miss_char),
                                  p_subscription_depend_flag    => nvl(p_subscription_depend_flag,
                                                                       g_miss_char),
                                  p_serv_req_enabled_code       => nvl(p_serv_req_enabled_code,
                                                                       g_miss_char),
                                  p_serv_billing_enabled_flag   => nvl(p_serv_billing_enabled_flag,
                                                                       g_miss_char),
                                  p_serv_importance_level       => nvl(p_serv_importance_level,
                                                                       g_miss_num),
                                  p_planned_inv_point_flag      => nvl(p_planned_inv_point_flag,
                                                                       g_miss_char),
                                  p_lot_translate_enabled       => nvl(p_lot_translate_enabled,
                                                                       g_miss_char),
                                  p_default_so_source_type      => nvl(p_default_so_source_type,
                                                                       g_miss_char),
                                  p_create_supply_flag          => nvl(p_create_supply_flag,
                                                                       g_miss_char),
                                  p_substitution_window_code    => nvl(p_substitution_window_code,
                                                                       g_miss_num),
                                  p_substitution_window_days    => NULL, --p_substitution_window_days ,
                                  p_ib_item_instance_class      => nvl(p_ib_item_instance_class,
                                                                       g_miss_char),
                                  p_config_model_type           => nvl(p_config_model_type,
                                                                       g_miss_char),
                                  p_lot_substitution_enabled    => nvl(p_lot_substitution_enabled,
                                                                       g_miss_char),
                                  p_minimum_license_quantity    => nvl(p_minimum_license_quantity,
                                                                       g_miss_num),
                                  p_eam_activity_source_code    => nvl(p_eam_activity_source_code,
                                                                       g_miss_char),
                                  p_approval_status             => p_approval_status,
                                  p_tracking_quantity_ind       => nvl(p_tracking_quantity_ind,
                                                                       g_miss_char),
                                  p_ont_pricing_qty_source      => nvl(p_ont_pricing_qty_source,
                                                                       g_miss_char),
                                  p_secondary_default_ind       => nvl(p_secondary_default_ind,
                                                                       g_miss_char),
                                  p_option_specific_sourced     => nvl(p_option_specific_sourced,
                                                                       g_miss_num),
                                  p_vmi_minimum_units           => nvl(p_vmi_minimum_units,
                                                                       g_miss_num),
                                  p_vmi_minimum_days            => nvl(p_vmi_minimum_days,
                                                                       g_miss_num),
                                  p_vmi_maximum_units           => nvl(p_vmi_maximum_units,
                                                                       g_miss_num),
                                  p_vmi_maximum_days            => nvl(p_vmi_maximum_days,
                                                                       g_miss_num),
                                  p_vmi_fixed_order_quantity    => nvl(p_vmi_fixed_order_quantity,
                                                                       g_miss_num),
                                  p_so_authorization_flag       => nvl(p_so_authorization_flag,
                                                                       g_miss_num),
                                  p_consigned_flag              => nvl(p_consigned_flag,
                                                                       g_miss_num),
                                  p_asn_autoexpire_flag         => nvl(p_asn_autoexpire_flag,
                                                                       g_miss_num),
                                  p_vmi_forecast_type           => nvl(p_vmi_forecast_type,
                                                                       g_miss_num),
                                  p_forecast_horizon            => nvl(p_forecast_horizon,
                                                                       g_miss_num),
                                  p_exclude_from_budget_flag    => nvl(p_exclude_from_budget_flag,
                                                                       g_miss_num),
                                  p_days_tgt_inv_supply         => nvl(p_days_tgt_inv_supply,
                                                                       g_miss_num),
                                  p_days_tgt_inv_window         => nvl(p_days_tgt_inv_window,
                                                                       g_miss_num),
                                  p_days_max_inv_supply         => nvl(p_days_max_inv_supply,
                                                                       g_miss_num),
                                  p_days_max_inv_window         => nvl(p_days_max_inv_window,
                                                                       g_miss_num),
                                  p_drp_planned_flag            => nvl(p_drp_planned_flag,
                                                                       g_miss_num),
                                  p_critical_component_flag     => nvl(p_critical_component_flag,
                                                                       g_miss_num),
                                  p_continous_transfer          => nvl(p_continous_transfer,
                                                                       g_miss_num),
                                  p_convergence                 => nvl(p_convergence,
                                                                       g_miss_num),
                                  p_divergence                  => nvl(p_divergence,
                                                                       g_miss_num),
                                  p_config_orgs                 => nvl(p_config_orgs,
                                                                       g_miss_char),
                                  p_config_match                => nvl(p_config_match,
                                                                       g_miss_char),
                                  p_item_number                 => p_item_number,
                                  p_segment1                    => p_segment1,
                                  p_segment2                    => NULL,
                                  p_segment3                    => p_segment3,
                                  p_segment4                    => p_segment4,
                                  p_segment5                    => p_segment5,
                                  p_segment6                    => p_segment6,
                                  p_segment7                    => p_segment7,
                                  p_segment8                    => p_segment8,
                                  p_segment9                    => p_segment9,
                                  p_segment10                   => p_segment10,
                                  p_segment11                   => p_segment11,
                                  p_segment12                   => p_segment12,
                                  p_segment13                   => p_segment13,
                                  p_segment14                   => p_segment14,
                                  p_segment15                   => p_segment15,
                                  p_segment16                   => p_segment16,
                                  p_segment17                   => p_segment17,
                                  p_segment18                   => p_segment18,
                                  p_segment19                   => p_segment19,
                                  p_segment20                   => p_segment20,
                                  p_summary_flag                => p_summary_flag,
                                  p_enabled_flag                => p_enabled_flag,
                                  p_start_date_active           => p_start_date_active,
                                  p_end_date_active             => p_end_date_active,
                                  p_attribute_category          => p_attribute_category,
                                  p_attribute1                  => p_attribute1,
                                  p_attribute2                  => p_attribute2,
                                  p_attribute3                  => p_attribute3,
                                  p_attribute4                  => p_attribute4,
                                  p_attribute5                  => p_attribute5,
                                  p_attribute6                  => p_attribute6,
                                  p_attribute7                  => p_attribute7,
                                  p_attribute8                  => p_attribute8,
                                  p_attribute9                  => p_attribute9,
                                  p_attribute10                 => p_attribute10,
                                  p_attribute11                 => p_attribute11,
                                  p_attribute12                 => p_attribute12,
                                  p_attribute13                 => p_attribute13, -- storing ID instead
                                  p_attribute14                 => p_attribute14, -- always passed as Y
                                  p_attribute15                 => p_attribute15,
                                  p_global_attribute_category   => p_global_attribute_category,
                                  p_global_attribute1           => p_global_attribute1,
                                  p_global_attribute2           => p_global_attribute2,
                                  p_global_attribute3           => p_global_attribute3,
                                  p_global_attribute4           => p_global_attribute4,
                                  p_global_attribute5           => p_global_attribute5,
                                  p_global_attribute6           => p_global_attribute6,
                                  p_global_attribute7           => p_global_attribute7,
                                  p_global_attribute8           => p_global_attribute8,
                                  p_global_attribute9           => p_global_attribute9,
                                  p_global_attribute10          => p_global_attribute10,
                                  p_creation_date               => p_creation_date,
                                  p_created_by                  => p_created_by,
                                  p_last_update_date            => p_last_update_date,
                                  p_last_updated_by             => p_last_updated_by,
                                  p_last_update_login           => p_last_update_login,
                                  p_request_id                  => p_request_id,
                                  p_program_application_id      => p_program_application_id,
                                  p_program_id                  => p_program_id,
                                  p_program_update_date         => p_program_update_date,
                                  p_lifecycle_id                => p_lifecycle_id,
                                  p_current_phase_id            => p_current_phase_id,
                                  p_revision_id                 => p_revision_id,
                                  p_revision_code               => substr(p_revision_code,
                                                                          1,
                                                                          3),
                                  p_revision_label              => p_revision_label,
                                  p_revision_description        => p_revision_description,
                                  p_effectivity_date            => d_effectivity_date,
                                  p_rev_lifecycle_id            => p_rev_lifecycle_id,
                                  p_rev_current_phase_id        => p_rev_current_phase_id,
                                  p_rev_attribute_category      => p_rev_attribute_category,
                                  p_rev_attribute1              => p_rev_attribute1,
                                  p_rev_attribute2              => p_rev_attribute2,
                                  p_rev_attribute3              => p_rev_attribute3,
                                  p_rev_attribute4              => p_rev_attribute4,
                                  p_rev_attribute5              => p_rev_attribute5,
                                  p_rev_attribute6              => p_rev_attribute6,
                                  p_rev_attribute7              => p_rev_attribute7,
                                  p_rev_attribute8              => p_rev_attribute8,
                                  p_rev_attribute9              => p_rev_attribute9,
                                  p_rev_attribute10             => p_rev_attribute10,
                                  p_rev_attribute11             => p_rev_attribute11,
                                  p_rev_attribute12             => p_rev_attribute12,
                                  p_rev_attribute13             => p_rev_attribute13,
                                  p_rev_attribute14             => p_rev_attribute14,
                                  p_rev_attribute15             => p_rev_attribute15,
                                  p_apply_template              => nvl(p_apply_template,
                                                                       'ALL'),
                                  p_object_version_number       => p_object_version_number,
                                  p_process_control             => 'aaaa',
                                  x_inventory_item_id           => n_inv_item_id,
                                  x_organization_id             => n_api_return_org_id,
                                  x_return_status               => v_api_return_status,
                                  x_msg_count                   => n_msg_count,
                                  x_msg_data                    => v_msg_data);
      
        ----autonomous_proc.dump_temp('Return Status: '||v_api_return_status||', error message:'||v_msg_data||', last:'||', EGO_Item_PVT.G_Item_indx'|| EGO_Item_PVT.G_Item_indx);
      
        IF v_api_return_status <> fnd_api.g_ret_sts_success THEN
          FOR ro_msg_lst IN 1 .. n_msg_count LOOP
            ln_count := ro_msg_lst;
            error_handler.get_message(lc_error_message,
                                      ln_count,
                                      lc_entity_id,
                                      lc_entity_type);
            write_to_log('process_item',
                         lc_error_message || ',Entity ID:' || lc_entity_id ||
                         ', Entity Type:' || lc_entity_type);
            add_error_text(lc_error_message);
          END LOOP;
        
          RAISE l_item_creation_exception;
        END IF;
      END LOOP;
      CLOSE lcu_get_inv_orgs;
      dbms_lock.sleep(seconds => 5);
      --Assign Item Into Organization
      v_api_return_status := 'S';
      v_msg_data          := NULL;
    
      xxinv_utils_pkg.org_assignment(p_inventory_item_id => n_inv_item_id,
                                     p_item_code         => p_item_number,
                                     p_group             => v_group,
                                     p_family            => v_family,
                                     x_return_status     => v_api_return_status,
                                     x_err_message       => v_msg_data);
    
      COMMIT;
      IF v_api_return_status <> 'S' THEN
        px_msg_data := 'Can Not Assign Item Into Organization: ' ||
                       v_msg_data;
        RAISE l_misc_exception;
      END IF;
      dbms_lock.sleep(seconds => 5);
      px_inventory_item_id := n_inv_item_id;
      px_organization_id   := n_api_return_org_id;
      px_return_status     := ego_item_pub.g_ret_sts_success;
      px_msg_count         := 0;
      px_msg_data          := NULL;
    
    ELSIF (p_transaction_type = 'UPDATE') THEN
    
      OPEN lcu_mtl_items(p_item_number);
      LOOP
        FETCH lcu_mtl_items
          INTO lr_mtl_items_rec;
      
        EXIT WHEN lcu_mtl_items%NOTFOUND;
        -- getting the template ID for the template name and organization
        -- n_template_id := NULL;
      
        /*           BEGIN
                       SELECT template_id, template_name
                         INTO n_template_id, v_template_name
                         FROM mtl_item_templates mit
                        WHERE upper(mit.template_name) =
                              upper(v_template_name_temp);
                    
                    EXCEPTION
                       WHEN OTHERS THEN
                          n_template_id   := NULL;
                          v_template_name := NULL;
                    END;
        */
        IF get_chr_val_from_template(n_template_id,
                                     'MTL_SYSTEM_ITEMS.ITEM_TYPE') !=
           lr_mtl_items_rec.item_type THEN
          px_msg_data := 'Can Not change template, please make the changes manually';
          RAISE l_misc_exception;
        END IF;
      
        n_object_version_num := NULL;
      
        OPEN lcu_get_obj_version_num(cp_inventory_item_id => nvl(p_inventory_item_id,
                                                                 lr_mtl_items_rec.inventory_item_id),
                                     cp_organization_id   => lr_mtl_items_rec.organization_id);
        FETCH lcu_get_obj_version_num
          INTO n_object_version_num;
        CLOSE lcu_get_obj_version_num;
      
        n_template_id := NULL;
        --customer enable flag added by yan
        IF n_template_id IS NULL THEN
          n_customer_enabled_flag    := lr_mtl_items_rec.customer_order_enabled_flag;
          n_customer_order_flag      := lr_mtl_items_rec.customer_order_flag;
          n_serviceable_product_flag := lr_mtl_items_rec.serviceable_product_flag;
          n_comms_nl_trackable_flag  := lr_mtl_items_rec.comms_nl_trackable_flag;
        END IF;
      
        ego_item_pub.process_item(p_api_version      => '1.0',
                                  p_init_msg_list    => ego_item_pub.g_true,
                                  p_commit           => ego_item_pub.g_false,
                                  p_transaction_type => p_transaction_type,
                                  p_language_code    => nvl(p_language_code,
                                                            'US'),
                                  -- p_template_id                => n_template_id, ---nvl(n_template_id,EGO_ITEM_PUB.g_miss_num),
                                  -- p_template_name              => v_template_name, --nvl(v_template_name,EGO_ITEM_PUB.g_miss_char ),
                                  p_copy_inventory_item_id     => nvl(p_copy_inventory_item_id,
                                                                      ego_item_pub.g_miss_num),
                                  p_inventory_item_id          => nvl(p_inventory_item_id,
                                                                      lr_mtl_items_rec.inventory_item_id),
                                  p_organization_id            => nvl(p_organization_id,
                                                                      lr_mtl_items_rec.organization_id),
                                  p_master_organization_id     => nvl(p_master_organization_id,
                                                                      lr_mtl_items_rec.master_organization_id),
                                  p_description                => nvl(p_description,
                                                                      ego_item_pub.g_miss_char),
                                  p_long_description           => nvl(p_long_description,
                                                                      ego_item_pub.g_miss_char),
                                  p_primary_uom_code           => nvl(v_primary_uom_code,
                                                                      lr_mtl_items_rec.primary_uom_code),
                                  p_primary_unit_of_measure    => nvl(v_primary_unit_of_meas,
                                                                      lr_mtl_items_rec.primary_unit_of_measure),
                                  p_item_type                  => check_item_chr_value(n_template_id,
                                                                                       p_item_type,
                                                                                       lr_mtl_items_rec.item_type), -- nvl(p_item_type,EGO_ITEM_PUB.G_MISS_CHAR),
                                  p_inventory_item_status_code => v_item_status_code,
                                  p_allowed_units_lookup_code  => nvl(p_allowed_units_lookup_code,
                                                                      ego_item_pub.g_miss_num),
                                  p_item_catalog_group_id      => check_item_num_value(n_template_id,
                                                                                       p_item_catalog_group_id,
                                                                                       lr_mtl_items_rec.item_catalog_group_id), --nvl(p_item_catalog_group_id,lr_mtl_items_rec.item_catalog_group_id ),
                                  p_catalog_status_flag        => check_item_chr_value(n_template_id,
                                                                                       p_catalog_status_flag,
                                                                                       lr_mtl_items_rec.catalog_status_flag), --nvl(p_catalog_status_flag,lr_mtl_items_rec.catalog_status_flag ),
                                  p_inventory_item_flag        => check_item_chr_value(n_template_id,
                                                                                       p_inventory_item_flag,
                                                                                       lr_mtl_items_rec.inventory_item_flag), -- nvl(p_inventory_item_flag,EGO_ITEM_PUB.G_MISS_CHAR ),
                                  --p_stock_enabled_flag => check_item_chr_value(n_template_id,p_stock_enabled_flag,lr_mtl_items_rec.stock_enabled_flag ),
                                  p_stock_enabled_flag => nvl(p_stock_enabled_flag,
                                                              ego_item_pub.g_miss_char),
                                  --p_mtl_transactions_enabled_fl =>check_item_chr_value(n_template_id,p_mtl_transactions_enabled_fl,lr_mtl_items_rec.mtl_transactions_enabled_flag ),
                                  p_mtl_transactions_enabled_fl => nvl(p_mtl_transactions_enabled_fl,
                                                                       ego_item_pub.g_miss_char),
                                  p_check_shortages_flag        => check_item_chr_value(n_template_id,
                                                                                        p_check_shortages_flag,
                                                                                        lr_mtl_items_rec.check_shortages_flag), --p_check_shortages_flag => nvl(p_check_shortages_flag,EGO_ITEM_PUB.G_MISS_CHAR ),
                                  p_revision_qty_control_code   => check_item_num_value(n_template_id,
                                                                                        p_revision_qty_control_code,
                                                                                        lr_mtl_items_rec.revision_qty_control_code), --  p_revision_qty_control_code => nvl(p_revision_qty_control_code,EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_reservable_type             => check_item_num_value(n_template_id,
                                                                                        p_reservable_type,
                                                                                        lr_mtl_items_rec.reservable_type), -- p_reservable_type => nvl(p_reservable_type,EGO_ITEM_PUB.G_MISS_NUM ),
                                  -- p_shelf_life_code             => check_item_num_value(n_template_id,
                                  --                                                       p_shelf_life_code,
                                  --                                                       lr_mtl_items_rec.shelf_life_code), -- p_shelf_life_code => nvl(p_shelf_life_code, EGO_ITEM_PUB.G_MISS_NUM ),
                                  -- p_shelf_life_days             => check_item_num_value(n_template_id,
                                  --                                                       p_shelf_life_days,
                                  --                                                       lr_mtl_items_rec.shelf_life_days), -- p_shelf_life_days => nvl(p_shelf_life_days,EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_cycle_count_enabled_flag   => check_item_chr_value(n_template_id,
                                                                                       p_cycle_count_enabled_flag,
                                                                                       lr_mtl_items_rec.cycle_count_enabled_flag), --p_cycle_count_enabled_flag => nvl(p_cycle_count_enabled_flag, EGO_ITEM_PUB.G_MISS_CHAR ),
                                  p_negative_measurement_error => check_item_num_value(n_template_id,
                                                                                       p_negative_measurement_error,
                                                                                       lr_mtl_items_rec.negative_measurement_error), -- p_negative_measurement_error => nvl(p_negative_measurement_error, EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_positive_measurement_error => check_item_num_value(n_template_id,
                                                                                       p_positive_measurement_error,
                                                                                       lr_mtl_items_rec.positive_measurement_error), -- p_positive_measurement_error => nvl(p_positive_measurement_error, EGO_ITEM_PUB.G_MISS_NUM ),
                                  --  p_lot_control_code            => check_item_num_value(n_template_id,
                                  --                                                        p_lot_control_code,
                                  --                                                        lr_mtl_items_rec.lot_control_code), -- p_lot_control_code => nvl(p_lot_control_code, EGO_ITEM_PUB.G_MISS_NUM ),
                                  --  p_auto_lot_alpha_prefix       => check_item_chr_value(n_template_id,
                                  --                                                        p_auto_lot_alpha_prefix,
                                  --                                                        lr_mtl_items_rec.auto_lot_alpha_prefix), -- p_auto_lot_alpha_prefix => nvl(p_auto_lot_alpha_prefix, EGO_ITEM_PUB.G_MISS_CHAR ),
                                  --  p_start_auto_lot_number       => check_item_chr_value(n_template_id,
                                  --                                                        p_start_auto_lot_number,
                                  --                                                        lr_mtl_items_rec.start_auto_lot_number), -- p_start_auto_lot_number => nvl(p_start_auto_lot_number,EGO_ITEM_PUB.G_MISS_CHAR ),
                                  --  p_serial_number_control_code  => check_item_num_value(n_template_id,
                                  --                                                        p_serial_number_control_code,
                                  --
                                  --                    lr_mtl_items_rec.serial_number_control_code), -- p_serial_number_control_code => nvl(p_serial_number_control_code, EGO_ITEM_PUB.G_MISS_NUM ),
                                  -- p_auto_serial_alpha_prefix => check_item_chr_value (n_template_id,p_auto_serial_alpha_prefix,lr_mtl_items_rec.auto_serial_alpha_prefix),-- p_auto_serial_alpha_prefix => nvl(p_auto_serial_alpha_prefix, EGO_ITEM_PUB.G_MISS_CHAR ),
                                  --amirt 20/02/08
                                  --  p_auto_serial_alpha_prefix    => nvl2_user(lr_mtl_items_rec.auto_serial_alpha_prefix,
                                  --                                             p_auto_serial_alpha_prefix),
                                  --  p_start_auto_serial_number    => check_item_chr_value(n_template_id,
                                  --                                                        p_start_auto_serial_number,
                                  --                                                        lr_mtl_items_rec.start_auto_serial_number), -- p_start_auto_serial_number => nvl(p_start_auto_serial_number, EGO_ITEM_PUB.G_MISS_CHAR ),
                                  p_location_control_code       => check_item_num_value(n_template_id,
                                                                                        p_location_control_code,
                                                                                        lr_mtl_items_rec.location_control_code), -- p_location_control_code => nvl(p_location_control_code, EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_restrict_subinventories_cod => check_item_num_value(n_template_id,
                                                                                        p_restrict_subinventories_cod,
                                                                                        lr_mtl_items_rec.restrict_subinventories_code), -- p_restrict_subinventories_cod => nvl(p_restrict_subinventories_cod, EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_restrict_locators_code      => check_item_num_value(n_template_id,
                                                                                        p_restrict_locators_code,
                                                                                        lr_mtl_items_rec.restrict_locators_code), -- p_restrict_locators_code => nvl(p_restrict_locators_code, EGO_ITEM_PUB.G_MISS_NUM ),
                                  --p_bom_enabled_flag => check_item_chr_value (n_template_id,p_bom_enabled_flag,lr_mtl_items_rec.bom_enabled_flag),
                                  p_bom_enabled_flag         => nvl(p_bom_enabled_flag,
                                                                    ego_item_pub.g_miss_char),
                                  p_bom_item_type            => check_item_num_value(n_template_id,
                                                                                     p_bom_item_type,
                                                                                     lr_mtl_items_rec.bom_item_type), --  p_bom_item_type => nvl(p_bom_item_type,EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_base_item_id             => check_item_num_value(n_template_id,
                                                                                     p_base_item_id,
                                                                                     lr_mtl_items_rec.base_item_id), --   p_base_item_id => nvl(p_base_item_id, EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_effectivity_control      => check_item_num_value(n_template_id,
                                                                                     p_effectivity_control,
                                                                                     lr_mtl_items_rec.effectivity_control), -- p_effectivity_control => nvl(p_effectivity_control, EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_eng_item_flag            => check_item_chr_value(n_template_id,
                                                                                     p_eng_item_flag,
                                                                                     lr_mtl_items_rec.eng_item_flag), --  p_eng_item_flag => nvl(p_eng_item_flag,lr_mtl_items_rec.eng_item_flag ),
                                  p_engineering_ecn_code     => check_item_chr_value(n_template_id,
                                                                                     p_engineering_ecn_code,
                                                                                     lr_mtl_items_rec.engineering_ecn_code), -- p_engineering_ecn_code => nvl(p_engineering_ecn_code,lr_mtl_items_rec.engineering_ecn_code ),
                                  p_engineering_item_id      => check_item_num_value(n_template_id,
                                                                                     p_engineering_item_id,
                                                                                     lr_mtl_items_rec.engineering_item_id), --  p_engineering_item_id => nvl(p_engineering_item_id,ego_item_pub.g_miss_num),
                                  p_engineering_date         => check_item_date_value(n_template_id,
                                                                                      p_engineering_date,
                                                                                      lr_mtl_items_rec.engineering_date), -- p_engineering_date => nvl(p_engineering_date,lr_mtl_items_rec.engineering_date ),
                                  p_product_family_item_id   => check_item_num_value(n_template_id,
                                                                                     p_product_family_item_id,
                                                                                     lr_mtl_items_rec.product_family_item_id), --   p_product_family_item_id => nvl(p_product_family_item_id,lr_mtl_items_rec.product_family_item_id ),
                                  p_auto_created_config_flag => check_item_chr_value(n_template_id,
                                                                                     p_auto_created_config_flag,
                                                                                     lr_mtl_items_rec.auto_created_config_flag), -- p_auto_created_config_flag => nvl(p_auto_created_config_flag,lr_mtl_items_rec.auto_created_config_flag ),
                                  p_model_config_clause_name => check_item_chr_value(n_template_id,
                                                                                     p_model_config_clause_name,
                                                                                     lr_mtl_items_rec.model_config_clause_name), --    p_model_config_clause_name => nvl(p_model_config_clause_name,lr_mtl_items_rec.model_config_clause_name ),
                                  --bug 2-10-2008 copy/past problem
                                  p_new_revision_code           => check_item_chr_value(n_template_id,
                                                                                        substr(p_new_revision_code,
                                                                                               1,
                                                                                               3),
                                                                                        lr_mtl_items_rec.new_revision_code), --  p_new_revision_code => nvl(substr(p_new_revision_code,1,3),lr_mtl_items_rec.new_revision_code ),
                                  p_costing_enabled_flag        => check_item_chr_value(n_template_id,
                                                                                        p_costing_enabled_flag,
                                                                                        lr_mtl_items_rec.costing_enabled_flag), --   p_costing_enabled_flag => nvl(p_costing_enabled_flag, EGO_ITEM_PUB.G_MISS_CHAR ),
                                  p_inventory_asset_flag        => check_item_chr_value(n_template_id,
                                                                                        p_inventory_asset_flag,
                                                                                        lr_mtl_items_rec.inventory_asset_flag), -- p_inventory_asset_flag => nvl(p_inventory_asset_flag, EGO_ITEM_PUB.G_MISS_CHAR ),
                                  p_default_include_in_rollup_f => check_item_chr_value(n_template_id,
                                                                                        p_default_include_in_rollup_f,
                                                                                        lr_mtl_items_rec.default_include_in_rollup_flag), -- p_default_include_in_rollup_f => nvl(p_default_include_in_rollup_f, EGO_ITEM_PUB.G_MISS_CHAR),--lr_mtl_items_rec.default_include_in_rollup_flag ),
                                  p_cost_of_sales_account       => check_item_num_value(n_template_id,
                                                                                        p_cost_of_sales_account,
                                                                                        lr_mtl_items_rec.cost_of_sales_account), --    p_cost_of_sales_account => nvl(p_cost_of_sales_account, EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_std_lot_size                => check_item_num_value(n_template_id,
                                                                                        p_std_lot_size,
                                                                                        lr_mtl_items_rec.std_lot_size), -- p_std_lot_size => nvl(p_std_lot_size, EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_purchasing_item_flag        => check_item_chr_value(n_template_id,
                                                                                        p_purchasing_item_flag,
                                                                                        lr_mtl_items_rec.purchasing_item_flag), --  p_purchasing_item_flag => nvl(p_purchasing_item_flag, EGO_ITEM_PUB.G_MISS_CHAR ),
                                  p_purchasing_enabled_flag     => nvl(p_purchasing_enabled_flag,
                                                                       ego_item_pub.g_miss_char),
                                  -- p_purchasing_enabled_flag => check_item_chr_value (n_template_id,p_purchasing_enabled_flag,lr_mtl_items_rec.purchasing_enabled_flag),-- p_purchasing_enabled_flag => nvl(p_purchasing_enabled_flag, EGO_ITEM_PUB.G_MISS_CHAR ),
                                  p_must_use_approved_vendor_fl => check_item_chr_value(n_template_id,
                                                                                        p_must_use_approved_vendor_fl,
                                                                                        lr_mtl_items_rec.must_use_approved_vendor_flag), --p_must_use_approved_vendor_fl => nvl(p_must_use_approved_vendor_fl, EGO_ITEM_PUB.G_MISS_CHAR ),
                                  p_allow_item_desc_update_flag => check_item_chr_value(n_template_id,
                                                                                        p_allow_item_desc_update_flag,
                                                                                        lr_mtl_items_rec.allow_item_desc_update_flag), -- p_allow_item_desc_update_flag => nvl(p_allow_item_desc_update_flag, EGO_ITEM_PUB.G_MISS_CHAR ),
                                  p_rfq_required_flag           => check_item_chr_value(n_template_id,
                                                                                        p_rfq_required_flag,
                                                                                        lr_mtl_items_rec.rfq_required_flag), -- p_rfq_required_flag => nvl(p_rfq_required_flag, EGO_ITEM_PUB.G_MISS_CHAR ),
                                  p_outside_operation_flag      => check_item_chr_value(n_template_id,
                                                                                        p_outside_operation_flag,
                                                                                        lr_mtl_items_rec.outside_operation_flag), -- p_outside_operation_flag => nvl(p_outside_operation_flag, EGO_ITEM_PUB.G_MISS_CHAR ),
                                  p_outside_operation_uom_type  => check_item_chr_value(n_template_id,
                                                                                        p_outside_operation_uom_type,
                                                                                        lr_mtl_items_rec.outside_operation_uom_type), -- p_outside_operation_uom_type => nvl(p_outside_operation_uom_type, EGO_ITEM_PUB.G_MISS_CHAR ),
                                  p_taxable_flag                => check_item_chr_value(n_template_id,
                                                                                        p_taxable_flag,
                                                                                        lr_mtl_items_rec.taxable_flag), -- p_taxable_flag => nvl(p_taxable_flag, EGO_ITEM_PUB.G_MISS_CHAR ),
                                  p_purchasing_tax_code         => check_item_chr_value(n_template_id,
                                                                                        p_purchasing_tax_code,
                                                                                        lr_mtl_items_rec.purchasing_tax_code), --p_purchasing_tax_code => nvl(p_purchasing_tax_code, EGO_ITEM_PUB.G_MISS_CHAR ),
                                  p_receipt_required_flag       => check_item_chr_value(n_template_id,
                                                                                        p_receipt_required_flag,
                                                                                        lr_mtl_items_rec.receipt_required_flag), -- p_receipt_required_flag => nvl(p_receipt_required_flag, EGO_ITEM_PUB.G_MISS_CHAR ),
                                  p_inspection_required_flag    => check_item_chr_value(n_template_id,
                                                                                        p_inspection_required_flag,
                                                                                        lr_mtl_items_rec.inspection_required_flag), -- p_inspection_required_flag => nvl(p_inspection_required_flag,EGO_ITEM_PUB.G_MISS_CHAR ),
                                  p_buyer_id                    => check_item_num_value(n_template_id,
                                                                                        p_buyer_id,
                                                                                        lr_mtl_items_rec.buyer_id), --p_buyer_id => nvl(p_buyer_id, EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_unit_of_issue               => check_item_chr_value(n_template_id,
                                                                                        p_unit_of_issue,
                                                                                        lr_mtl_items_rec.unit_of_issue), -- p_unit_of_issue => nvl(p_unit_of_issue,EGO_ITEM_PUB.G_MISS_CHAR ),
                                  p_receive_close_tolerance     => check_item_num_value(n_template_id,
                                                                                        p_receive_close_tolerance,
                                                                                        lr_mtl_items_rec.receive_close_tolerance), --p_receive_close_tolerance => nvl(p_receive_close_tolerance, EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_invoice_close_tolerance     => check_item_num_value(n_template_id,
                                                                                        p_invoice_close_tolerance,
                                                                                        lr_mtl_items_rec.invoice_close_tolerance), --p_invoice_close_tolerance => nvl(p_invoice_close_tolerance, EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_un_number_id                => check_item_num_value(n_template_id,
                                                                                        p_un_number_id,
                                                                                        lr_mtl_items_rec.un_number_id), -- p_un_number_id => nvl(p_un_number_id, EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_hazard_class_id             => check_item_num_value(n_template_id,
                                                                                        p_hazard_class_id,
                                                                                        lr_mtl_items_rec.hazard_class_id), -- p_hazard_class_id => nvl(p_hazard_class_id, EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_list_price_per_unit         => check_item_num_value(n_template_id,
                                                                                        p_list_price_per_unit,
                                                                                        lr_mtl_items_rec.list_price_per_unit), -- p_list_price_per_unit => nvl(p_list_price_per_unit,EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_market_price                => check_item_num_value(n_template_id,
                                                                                        p_market_price,
                                                                                        lr_mtl_items_rec.market_price), -- p_market_price => nvl(p_market_price,EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_price_tolerance_percent     => check_item_num_value(n_template_id,
                                                                                        p_price_tolerance_percent,
                                                                                        lr_mtl_items_rec.price_tolerance_percent), --p_price_tolerance_percent => nvl(p_price_tolerance_percent,EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_rounding_factor             => check_item_num_value(n_template_id,
                                                                                        p_rounding_factor,
                                                                                        lr_mtl_items_rec.rounding_factor), --   p_rounding_factor => nvl(p_rounding_factor, EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_encumbrance_account         => check_item_num_value(n_template_id,
                                                                                        p_encumbrance_account,
                                                                                        lr_mtl_items_rec.encumbrance_account), --p_encumbrance_account => nvl(p_encumbrance_account, EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_expense_account             => check_item_num_value(n_template_id,
                                                                                        p_expense_account,
                                                                                        lr_mtl_items_rec.expense_account), --  p_expense_account => nvl(p_expense_account, EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_expense_billable_flag       => check_item_chr_value(n_template_id,
                                                                                        p_expense_billable_flag,
                                                                                        lr_mtl_items_rec.expense_billable_flag), --p_expense_billable_flag => nvl(p_expense_billable_flag,lr_mtl_items_rec.expense_billable_flag ),
                                  p_asset_category_id           => check_item_num_value(n_template_id,
                                                                                        p_asset_category_id,
                                                                                        lr_mtl_items_rec.asset_category_id), -- p_asset_category_id => nvl(p_asset_category_id, EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_receipt_days_exception_code => check_item_chr_value(n_template_id,
                                                                                        p_receipt_days_exception_code,
                                                                                        lr_mtl_items_rec.receipt_days_exception_code), -- p_receipt_days_exception_code => nvl(p_receipt_days_exception_code, EGO_ITEM_PUB.G_MISS_CHAR ),
                                  p_days_early_receipt_allowed  => check_item_num_value(n_template_id,
                                                                                        p_days_early_receipt_allowed,
                                                                                        lr_mtl_items_rec.days_early_receipt_allowed), --  p_days_early_receipt_allowed => nvl(p_days_early_receipt_allowed,EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_days_late_receipt_allowed   => check_item_num_value(n_template_id,
                                                                                        p_days_late_receipt_allowed,
                                                                                        lr_mtl_items_rec.days_late_receipt_allowed), --   p_days_late_receipt_allowed => nvl(p_days_late_receipt_allowed,EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_allow_substitute_receipts_f => check_item_chr_value(n_template_id,
                                                                                        p_allow_substitute_receipts_f,
                                                                                        lr_mtl_items_rec.allow_substitute_receipts_flag), --  p_allow_substitute_receipts_f => nvl(p_allow_substitute_receipts_f, EGO_ITEM_PUB.G_MISS_CHAR ),
                                  p_allow_unordered_receipts_fl => check_item_chr_value(n_template_id,
                                                                                        p_allow_unordered_receipts_fl,
                                                                                        lr_mtl_items_rec.allow_unordered_receipts_flag), -- p_allow_unordered_receipts_fl => nvl(p_allow_unordered_receipts_fl, EGO_ITEM_PUB.G_MISS_CHAR ),
                                  p_allow_express_delivery_flag => check_item_chr_value(n_template_id,
                                                                                        p_allow_express_delivery_flag,
                                                                                        lr_mtl_items_rec.allow_express_delivery_flag), -- p_allow_express_delivery_flag => nvl(p_allow_express_delivery_flag, EGO_ITEM_PUB.G_MISS_CHAR ),
                                  p_qty_rcv_exception_code      => check_item_chr_value(n_template_id,
                                                                                        p_qty_rcv_exception_code,
                                                                                        lr_mtl_items_rec.qty_rcv_exception_code), --  p_qty_rcv_exception_code => nvl(p_qty_rcv_exception_code, EGO_ITEM_PUB.G_MISS_CHAR ),
                                  p_qty_rcv_tolerance           => check_item_num_value(n_template_id,
                                                                                        p_qty_rcv_tolerance,
                                                                                        lr_mtl_items_rec.qty_rcv_tolerance), --   p_qty_rcv_tolerance => nvl(p_qty_rcv_tolerance, EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_receiving_routing_id        => check_item_num_value(n_template_id,
                                                                                        p_receiving_routing_id,
                                                                                        lr_mtl_items_rec.receiving_routing_id), -- p_receiving_routing_id => nvl(p_receiving_routing_id, EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_enforce_ship_to_location_c  => check_item_chr_value(n_template_id,
                                                                                        p_enforce_ship_to_location_c,
                                                                                        lr_mtl_items_rec.enforce_ship_to_location_code), -- p_enforce_ship_to_location_c => nvl(p_enforce_ship_to_location_c, EGO_ITEM_PUB.G_MISS_CHAR ),
                                  p_weight_uom_code             => lr_mtl_items_rec.weight_uom_code, --nvl(v_weight_uom_code, G_MISS_CHAR) ,
                                  p_unit_weight                 => nvl(p_unit_weight,
                                                                       g_miss_num),
                                  p_volume_uom_code             => check_item_chr_value(n_template_id,
                                                                                        v_volume_uom_code,
                                                                                        lr_mtl_items_rec.volume_uom_code), -- p_volume_uom_code => nvl(v_volume_uom_code, EGO_ITEM_PUB.G_MISS_CHAR ),
                                  p_unit_volume                 => check_item_num_value(n_template_id,
                                                                                        p_unit_volume,
                                                                                        lr_mtl_items_rec.unit_volume), --  p_unit_volume => nvl(p_unit_volume, EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_container_item_flag         => check_item_chr_value(n_template_id,
                                                                                        p_container_item_flag,
                                                                                        lr_mtl_items_rec.container_item_flag), -- p_container_item_flag => nvl(p_container_item_flag, EGO_ITEM_PUB.G_MISS_CHAR ),
                                  p_vehicle_item_flag           => check_item_chr_value(n_template_id,
                                                                                        p_vehicle_item_flag,
                                                                                        lr_mtl_items_rec.vehicle_item_flag), --   p_vehicle_item_flag => nvl(p_vehicle_item_flag, EGO_ITEM_PUB.G_MISS_CHAR ),
                                  p_container_type_code         => check_item_chr_value(n_template_id,
                                                                                        p_container_type_code,
                                                                                        lr_mtl_items_rec.container_type_code), -- p_container_type_code => nvl(p_container_type_code, EGO_ITEM_PUB.G_MISS_CHAR ),
                                  p_internal_volume             => check_item_num_value(n_template_id,
                                                                                        p_internal_volume,
                                                                                        lr_mtl_items_rec.internal_volume), -- p_internal_volume => nvl(p_internal_volume, EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_maximum_load_weight         => check_item_num_value(n_template_id,
                                                                                        p_maximum_load_weight,
                                                                                        lr_mtl_items_rec.maximum_load_weight), -- p_maximum_load_weight => nvl(p_maximum_load_weight, EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_minimum_fill_percent        => check_item_num_value(n_template_id,
                                                                                        p_minimum_fill_percent,
                                                                                        lr_mtl_items_rec.minimum_fill_percent), -- p_minimum_fill_percent => nvl(p_minimum_fill_percent, EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_inventory_planning_code     => check_item_num_value(n_template_id,
                                                                                        p_inventory_planning_code,
                                                                                        lr_mtl_items_rec.inventory_planning_code), -- p_inventory_planning_code => nvl(p_inventory_planning_code, EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_planner_code                => check_item_chr_value(n_template_id,
                                                                                        p_planner_code,
                                                                                        lr_mtl_items_rec.planner_code), --  p_planner_code => nvl(p_planner_code, EGO_ITEM_PUB.G_MISS_CHAR ),
                                  p_planning_make_buy_code      => check_item_num_value(n_template_id,
                                                                                        p_planning_make_buy_code,
                                                                                        lr_mtl_items_rec.planning_make_buy_code), -- p_planning_make_buy_code => nvl(p_planning_make_buy_code, EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_min_minmax_quantity         => check_item_num_value(n_template_id,
                                                                                        p_min_minmax_quantity,
                                                                                        lr_mtl_items_rec.min_minmax_quantity), --   p_min_minmax_quantity => nvl(p_min_minmax_quantity, EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_max_minmax_quantity         => check_item_num_value(n_template_id,
                                                                                        p_max_minmax_quantity,
                                                                                        lr_mtl_items_rec.max_minmax_quantity), --   p_max_minmax_quantity => nvl(p_max_minmax_quantity, EGO_ITEM_PUB.G_MISS_NUM ),
                                  --     p_minimum_order_quantity      => check_item_num_value(n_template_id,
                                  --                                                           p_minimum_order_quantity,
                                  --                                                           lr_mtl_items_rec.minimum_order_quantity), --    p_minimum_order_quantity => nvl(p_minimum_order_quantity, EGO_ITEM_PUB.G_MISS_NUM ),
                                  --     p_maximum_order_quantity      => check_item_num_value(n_template_id,
                                  --                                                           p_maximum_order_quantity,
                                  --                                                           lr_mtl_items_rec.maximum_order_quantity), --  p_maximum_order_quantity => nvl(p_maximum_order_quantity, EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_order_cost                  => check_item_num_value(n_template_id,
                                                                                        p_order_cost,
                                                                                        lr_mtl_items_rec.order_cost), -- p_order_cost => nvl(p_order_cost, EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_carrying_cost               => check_item_num_value(n_template_id,
                                                                                        p_carrying_cost,
                                                                                        lr_mtl_items_rec.carrying_cost), -- p_carrying_cost => nvl(p_carrying_cost, EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_source_type                 => check_item_num_value(n_template_id,
                                                                                        p_source_type,
                                                                                        lr_mtl_items_rec.source_type), -- p_source_type => nvl(p_source_type, EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_source_organization_id      => check_item_num_value(n_template_id,
                                                                                        p_source_organization_id,
                                                                                        lr_mtl_items_rec.source_organization_id), --  p_source_organization_id => nvl(p_source_organization_id, EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_source_subinventory         => check_item_chr_value(n_template_id,
                                                                                        p_source_subinventory,
                                                                                        lr_mtl_items_rec.source_subinventory), --  p_source_subinventory => nvl(p_source_subinventory, EGO_ITEM_PUB.G_MISS_CHAR ),
                                  p_mrp_safety_stock_code       => check_item_num_value(n_template_id,
                                                                                        p_mrp_safety_stock_code,
                                                                                        lr_mtl_items_rec.mrp_safety_stock_code), --  p_mrp_safety_stock_code => nvl(p_mrp_safety_stock_code,  EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_safety_stock_bucket_days    => check_item_num_value(n_template_id,
                                                                                        p_safety_stock_bucket_days,
                                                                                        lr_mtl_items_rec.safety_stock_bucket_days), -- p_safety_stock_bucket_days => nvl(p_safety_stock_bucket_days,  EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_mrp_safety_stock_percent    => check_item_num_value(n_template_id,
                                                                                        p_mrp_safety_stock_percent,
                                                                                        lr_mtl_items_rec.mrp_safety_stock_percent), -- p_mrp_safety_stock_percent => nvl(p_mrp_safety_stock_percent,  EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_fixed_order_quantity        => check_item_num_value(n_template_id,
                                                                                        p_fixed_order_quantity,
                                                                                        lr_mtl_items_rec.fixed_order_quantity), -- p_fixed_order_quantity => nvl(p_fixed_order_quantity,  EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_fixed_days_supply           => check_item_num_value(n_template_id,
                                                                                        p_fixed_days_supply,
                                                                                        lr_mtl_items_rec.fixed_days_supply), --  p_fixed_days_supply => nvl(p_fixed_days_supply,  EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_fixed_lot_multiplier        => check_item_num_value(n_template_id,
                                                                                        p_fixed_lot_multiplier,
                                                                                        lr_mtl_items_rec.fixed_lot_multiplier), --p_fixed_lot_multiplier => nvl(p_fixed_lot_multiplier,  EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_mrp_planning_code           => check_item_num_value(n_template_id,
                                                                                        p_mrp_planning_code,
                                                                                        lr_mtl_items_rec.mrp_planning_code), -- p_mrp_planning_code => nvl(p_mrp_planning_code,  EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_ato_forecast_control        => check_item_num_value(n_template_id,
                                                                                        p_ato_forecast_control,
                                                                                        lr_mtl_items_rec.ato_forecast_control), -- p_ato_forecast_control => nvl(p_ato_forecast_control,  EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_planning_exception_set      => check_item_chr_value(n_template_id,
                                                                                        p_planning_exception_set,
                                                                                        lr_mtl_items_rec.planning_exception_set), --p_planning_exception_set => nvl(p_planning_exception_set,  EGO_ITEM_PUB.G_MISS_CHAR ),
                                  p_end_assembly_pegging_flag   => check_item_chr_value(n_template_id,
                                                                                        p_end_assembly_pegging_flag,
                                                                                        lr_mtl_items_rec.end_assembly_pegging_flag), --p_end_assembly_pegging_flag => nvl(p_end_assembly_pegging_flag, EGO_ITEM_PUB.G_MISS_CHAR ),
                                  p_shrinkage_rate              => check_item_num_value(n_template_id,
                                                                                        p_shrinkage_rate,
                                                                                        lr_mtl_items_rec.shrinkage_rate), -- p_shrinkage_rate => nvl(p_shrinkage_rate,  EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_rounding_control_type       => check_item_num_value(n_template_id,
                                                                                        p_rounding_control_type,
                                                                                        lr_mtl_items_rec.rounding_control_type), --p_rounding_control_type => nvl(p_rounding_control_type, EGO_ITEM_PUB.G_MISS_NUM), --lr_mtl_items_rec.rounding_control_type ),
                                  p_acceptable_early_days       => check_item_num_value(n_template_id,
                                                                                        p_acceptable_early_days,
                                                                                        lr_mtl_items_rec.acceptable_early_days), -- p_acceptable_early_days => nvl(p_acceptable_early_days, EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_repetitive_planning_flag    => check_item_chr_value(n_template_id,
                                                                                        p_repetitive_planning_flag,
                                                                                        lr_mtl_items_rec.repetitive_planning_flag), -- p_repetitive_planning_flag => nvl(p_repetitive_planning_flag, EGO_ITEM_PUB.G_MISS_CHAR ),
                                  p_overrun_percentage          => check_item_num_value(n_template_id,
                                                                                        p_overrun_percentage,
                                                                                        lr_mtl_items_rec.overrun_percentage), -- p_overrun_percentage => nvl(p_overrun_percentage,  EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_acceptable_rate_increase    => check_item_num_value(n_template_id,
                                                                                        p_acceptable_rate_increase,
                                                                                        lr_mtl_items_rec.acceptable_rate_increase), -- p_acceptable_rate_increase => nvl(p_acceptable_rate_increase,  EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_acceptable_rate_decrease    => check_item_num_value(n_template_id,
                                                                                        p_acceptable_rate_decrease,
                                                                                        lr_mtl_items_rec.acceptable_rate_decrease), -- p_acceptable_rate_decrease => nvl(p_acceptable_rate_decrease,  EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_mrp_calculate_atp_flag      => check_item_chr_value(n_template_id,
                                                                                        p_mrp_calculate_atp_flag,
                                                                                        lr_mtl_items_rec.mrp_calculate_atp_flag), --  p_mrp_calculate_atp_flag => nvl(p_mrp_calculate_atp_flag,'N'),--lr_mtl_items_rec.mrp_calculate_atp_flag ),
                                  p_auto_reduce_mps             => check_item_num_value(n_template_id,
                                                                                        p_auto_reduce_mps,
                                                                                        lr_mtl_items_rec.auto_reduce_mps), -- p_auto_reduce_mps => nvl(p_auto_reduce_mps,  EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_planning_time_fence_code    => check_item_num_value(n_template_id,
                                                                                        p_planning_time_fence_code,
                                                                                        lr_mtl_items_rec.planning_time_fence_code), --  p_planning_time_fence_code => nvl(p_planning_time_fence_code,  EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_planning_time_fence_days    => check_item_num_value(n_template_id,
                                                                                        p_planning_time_fence_days,
                                                                                        lr_mtl_items_rec.planning_time_fence_days), -- p_planning_time_fence_days => nvl(p_planning_time_fence_days,  EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_demand_time_fence_code      => check_item_num_value(n_template_id,
                                                                                        p_demand_time_fence_code,
                                                                                        lr_mtl_items_rec.demand_time_fence_code), -- p_demand_time_fence_code => nvl(p_demand_time_fence_code,  EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_demand_time_fence_days      => check_item_num_value(n_template_id,
                                                                                        p_demand_time_fence_days,
                                                                                        lr_mtl_items_rec.demand_time_fence_days), --  p_demand_time_fence_days => nvl(p_demand_time_fence_days,  EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_release_time_fence_code     => check_item_num_value(n_template_id,
                                                                                        p_release_time_fence_code,
                                                                                        lr_mtl_items_rec.release_time_fence_code), --p_release_time_fence_code => nvl(p_release_time_fence_code, EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_release_time_fence_days     => check_item_num_value(n_template_id,
                                                                                        p_release_time_fence_days,
                                                                                        lr_mtl_items_rec.release_time_fence_days), -- p_release_time_fence_days => nvl(p_release_time_fence_days, EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_preprocessing_lead_time     => check_item_num_value(n_template_id,
                                                                                        p_preprocessing_lead_time,
                                                                                        lr_mtl_items_rec.preprocessing_lead_time), -- p_preprocessing_lead_time => nvl(p_preprocessing_lead_time,  EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_full_lead_time              => check_item_num_value(n_template_id,
                                                                                        p_full_lead_time,
                                                                                        lr_mtl_items_rec.full_lead_time), -- p_full_lead_time => nvl(p_full_lead_time,  EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_postprocessing_lead_time    => check_item_num_value(n_template_id,
                                                                                        p_postprocessing_lead_time,
                                                                                        lr_mtl_items_rec.postprocessing_lead_time), -- p_postprocessing_lead_time => nvl(p_postprocessing_lead_time, EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_fixed_lead_time             => check_item_num_value(n_template_id,
                                                                                        p_fixed_lead_time,
                                                                                        lr_mtl_items_rec.fixed_lead_time), -- p_fixed_lead_time => nvl(p_fixed_lead_time,  EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_variable_lead_time          => check_item_num_value(n_template_id,
                                                                                        p_variable_lead_time,
                                                                                        lr_mtl_items_rec.variable_lead_time), -- p_variable_lead_time => nvl(p_variable_lead_time,  EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_cum_manufacturing_lead_time => check_item_num_value(n_template_id,
                                                                                        p_cum_manufacturing_lead_time,
                                                                                        lr_mtl_items_rec.cum_manufacturing_lead_time), -- p_cum_manufacturing_lead_time => nvl(p_cum_manufacturing_lead_time,  EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_cumulative_total_lead_time  => check_item_num_value(n_template_id,
                                                                                        p_cumulative_total_lead_time,
                                                                                        lr_mtl_items_rec.cumulative_total_lead_time), --  p_cumulative_total_lead_time => nvl(p_cumulative_total_lead_time,  EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_lead_time_lot_size          => check_item_num_value(n_template_id,
                                                                                        p_lead_time_lot_size,
                                                                                        lr_mtl_items_rec.lead_time_lot_size), -- p_lead_time_lot_size => nvl(p_lead_time_lot_size, EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_build_in_wip_flag           => nvl(p_build_in_wip_flag,
                                                                       ego_item_pub.g_miss_char),
                                  -- p_build_in_wip_flag => check_item_chr_value (n_template_id,p_build_in_wip_flag,lr_mtl_items_rec.build_in_wip_flag),--  p_build_in_wip_flag => nvl(p_build_in_wip_flag, EGO_ITEM_PUB.G_MISS_CHAR ),
                                  p_wip_supply_type             => check_item_num_value(n_template_id,
                                                                                        p_wip_supply_type,
                                                                                        lr_mtl_items_rec.wip_supply_type), --  p_wip_supply_type => nvl(p_wip_supply_type,  EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_wip_supply_subinventory     => check_item_chr_value(n_template_id,
                                                                                        p_wip_supply_subinventory,
                                                                                        lr_mtl_items_rec.wip_supply_subinventory), --  p_wip_supply_subinventory => nvl(p_wip_supply_subinventory, EGO_ITEM_PUB.G_MISS_CHAR ),
                                  p_wip_supply_locator_id       => check_item_num_value(n_template_id,
                                                                                        p_wip_supply_locator_id,
                                                                                        lr_mtl_items_rec.wip_supply_locator_id), -- p_wip_supply_locator_id => nvl(p_wip_supply_locator_id,  EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_overcompletion_tolerance_ty => check_item_num_value(n_template_id,
                                                                                        p_overcompletion_tolerance_ty,
                                                                                        lr_mtl_items_rec.overcompletion_tolerance_type), -- p_overcompletion_tolerance_ty => nvl(p_overcompletion_tolerance_ty, EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_overcompletion_tolerance_va => check_item_num_value(n_template_id,
                                                                                        p_overcompletion_tolerance_va,
                                                                                        lr_mtl_items_rec.overcompletion_tolerance_value), -- p_overcompletion_tolerance_va => nvl(p_overcompletion_tolerance_va,  EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_customer_order_flag         => check_item_chr_value(n_template_id,
                                                                                        p_customer_order_flag,
                                                                                        lr_mtl_items_rec.customer_order_flag), -- p_customer_order_flag => nvl(p_customer_order_flag, nvl(n_customer_order_flag,EGO_ITEM_PUB.G_MISS_CHAR)), --added by yan
                                  p_customer_order_enabled_flag => nvl(p_customer_order_enabled_flag,
                                                                       ego_item_pub.g_miss_char),
                                  --p_customer_order_enabled_flag => check_item_chr_value (n_template_id,p_customer_order_enabled_flag ,lr_mtl_items_rec.customer_order_enabled_flag),-- p_customer_order_enabled_flag => nvl(p_customer_order_enabled_flag,nvl(n_customer_enabled_flag, EGO_ITEM_PUB.G_MISS_CHAR) ), --yan added
                                  p_shippable_item_flag         => check_item_chr_value(n_template_id,
                                                                                        p_shippable_item_flag,
                                                                                        lr_mtl_items_rec.shippable_item_flag), -- p_shippable_item_flag => nvl(p_shippable_item_flag, EGO_ITEM_PUB.G_MISS_CHAR ),
                                  p_internal_order_flag         => check_item_chr_value(n_template_id,
                                                                                        p_internal_order_flag,
                                                                                        lr_mtl_items_rec.internal_order_flag), -- p_internal_order_flag => nvl(p_internal_order_flag,EGO_ITEM_PUB.G_MISS_CHAR ),
                                  p_internal_order_enabled_flag => nvl(p_internal_order_enabled_flag,
                                                                       ego_item_pub.g_miss_char),
                                  -- p_internal_order_enabled_flag => check_item_chr_value (n_template_id,p_internal_order_enabled_flag,lr_mtl_items_rec.internal_order_enabled_flag),-- p_internal_order_enabled_flag => nvl(p_internal_order_enabled_flag, EGO_ITEM_PUB.G_MISS_CHAR ),
                                  p_so_transactions_flag        => check_item_chr_value(n_template_id,
                                                                                        p_so_transactions_flag,
                                                                                        lr_mtl_items_rec.so_transactions_flag), --  p_so_transactions_flag => nvl(p_so_transactions_flag, EGO_ITEM_PUB.G_MISS_CHAR ),
                                  p_pick_components_flag        => check_item_chr_value(n_template_id,
                                                                                        p_pick_components_flag,
                                                                                        lr_mtl_items_rec.pick_components_flag), --  p_pick_components_flag => nvl(p_pick_components_flag, EGO_ITEM_PUB.G_MISS_CHAR ),
                                  p_atp_flag                    => check_item_chr_value(n_template_id,
                                                                                        p_atp_flag,
                                                                                        lr_mtl_items_rec.atp_flag), --  p_atp_flag => nvl(p_atp_flag, EGO_ITEM_PUB.G_MISS_CHAR ),
                                  p_replenish_to_order_flag     => check_item_chr_value(n_template_id,
                                                                                        p_replenish_to_order_flag,
                                                                                        lr_mtl_items_rec.replenish_to_order_flag), --  p_replenish_to_order_flag => nvl(p_replenish_to_order_flag, EGO_ITEM_PUB.G_MISS_CHAR ),
                                  p_atp_rule_id                 => check_item_num_value(n_template_id,
                                                                                        p_atp_rule_id,
                                                                                        lr_mtl_items_rec.atp_rule_id), --   p_atp_rule_id => nvl(p_atp_rule_id, EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_atp_components_flag         => check_item_chr_value(n_template_id,
                                                                                        p_atp_components_flag,
                                                                                        lr_mtl_items_rec.atp_components_flag), -- p_atp_components_flag => nvl(p_atp_components_flag, EGO_ITEM_PUB.G_MISS_CHAR ),
                                  p_ship_model_complete_flag    => check_item_chr_value(n_template_id,
                                                                                        p_ship_model_complete_flag,
                                                                                        lr_mtl_items_rec.ship_model_complete_flag), --   p_ship_model_complete_flag => nvl(p_ship_model_complete_flag, EGO_ITEM_PUB.G_MISS_CHAR ),
                                  p_picking_rule_id             => check_item_num_value(n_template_id,
                                                                                        p_picking_rule_id,
                                                                                        lr_mtl_items_rec.picking_rule_id), -- p_picking_rule_id => nvl(p_picking_rule_id, EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_collateral_flag             => check_item_chr_value(n_template_id,
                                                                                        p_collateral_flag,
                                                                                        lr_mtl_items_rec.collateral_flag), --  p_collateral_flag => nvl(p_collateral_flag, EGO_ITEM_PUB.G_MISS_CHAR),
                                  p_default_shipping_org        => check_item_num_value(n_template_id,
                                                                                        p_default_shipping_org,
                                                                                        lr_mtl_items_rec.default_shipping_org), -- p_default_shipping_org => nvl(p_default_shipping_org, EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_returnable_flag             => check_item_chr_value(n_template_id,
                                                                                        p_returnable_flag,
                                                                                        lr_mtl_items_rec.returnable_flag), --  p_returnable_flag => nvl(p_returnable_flag, EGO_ITEM_PUB.G_MISS_CHAR ),
                                  p_return_inspection_requireme => check_item_num_value(n_template_id,
                                                                                        p_return_inspection_requireme,
                                                                                        lr_mtl_items_rec.return_inspection_requirement), --  p_return_inspection_requireme => nvl(p_return_inspection_requireme, EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_over_shipment_tolerance     => check_item_num_value(n_template_id,
                                                                                        p_over_shipment_tolerance,
                                                                                        lr_mtl_items_rec.over_shipment_tolerance), --  p_over_shipment_tolerance => nvl(p_over_shipment_tolerance, EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_under_shipment_tolerance    => check_item_num_value(n_template_id,
                                                                                        p_under_shipment_tolerance,
                                                                                        lr_mtl_items_rec.under_shipment_tolerance), -- p_under_shipment_tolerance => nvl(p_under_shipment_tolerance, EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_over_return_tolerance       => check_item_num_value(n_template_id,
                                                                                        p_over_return_tolerance,
                                                                                        lr_mtl_items_rec.over_return_tolerance), --  p_over_return_tolerance => nvl(p_over_return_tolerance, EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_under_return_tolerance      => check_item_num_value(n_template_id,
                                                                                        p_under_return_tolerance,
                                                                                        lr_mtl_items_rec.under_return_tolerance), -- p_under_return_tolerance => nvl(p_under_return_tolerance, EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_invoiceable_item_flag       => check_item_chr_value(n_template_id,
                                                                                        p_invoiceable_item_flag,
                                                                                        lr_mtl_items_rec.invoiceable_item_flag), -- p_invoiceable_item_flag => nvl(p_invoiceable_item_flag, EGO_ITEM_PUB.G_MISS_CHAR ),
                                  --p_invoice_enabled_flag => check_item_chr_value (n_template_id,p_invoice_enabled_flag ,lr_mtl_items_rec.invoice_enabled_flag),
                                  p_invoice_enabled_flag        => nvl(p_invoice_enabled_flag,
                                                                       ego_item_pub.g_miss_char),
                                  p_accounting_rule_id          => check_item_num_value(n_template_id,
                                                                                        p_accounting_rule_id,
                                                                                        lr_mtl_items_rec.accounting_rule_id), -- p_accounting_rule_id => nvl(p_accounting_rule_id, EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_invoicing_rule_id           => check_item_num_value(n_template_id,
                                                                                        p_invoicing_rule_id,
                                                                                        lr_mtl_items_rec.invoicing_rule_id), -- p_invoicing_rule_id => nvl(p_invoicing_rule_id, EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_tax_code                    => check_item_chr_value(n_template_id,
                                                                                        p_tax_code,
                                                                                        lr_mtl_items_rec.tax_code), --  p_tax_code => nvl(p_tax_code, EGO_ITEM_PUB.G_MISS_CHAR ),
                                  p_sales_account               => check_item_num_value(n_template_id,
                                                                                        p_sales_account,
                                                                                        lr_mtl_items_rec.sales_account), -- p_sales_account => nvl(p_sales_account, EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_payment_terms_id            => check_item_num_value(n_template_id,
                                                                                        p_payment_terms_id,
                                                                                        lr_mtl_items_rec.payment_terms_id), -- p_payment_terms_id => nvl(p_payment_terms_id, EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_coverage_schedule_id        => check_item_num_value(n_template_id,
                                                                                        p_coverage_schedule_id,
                                                                                        lr_mtl_items_rec.coverage_schedule_id), -- p_coverage_schedule_id => nvl(p_coverage_schedule_id, EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_service_duration            => check_item_num_value(n_template_id,
                                                                                        p_service_duration,
                                                                                        lr_mtl_items_rec.service_duration), -- p_service_duration => nvl(p_service_duration, EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_service_duration_period_cod => check_item_chr_value(n_template_id,
                                                                                        p_service_duration_period_cod,
                                                                                        lr_mtl_items_rec.service_duration_period_code), -- p_service_duration_period_cod => nvl(p_service_duration_period_cod, EGO_ITEM_PUB.G_MISS_CHAR ),
                                  p_serviceable_product_flag    => check_item_chr_value(n_template_id,
                                                                                        p_serviceable_product_flag,
                                                                                        lr_mtl_items_rec.serviceable_product_flag), -- p_serviceable_product_flag => nvl(p_serviceable_product_flag,nvl(n_serviceable_product_flag, EGO_ITEM_PUB.G_MISS_CHAR) ), --yan added
                                  p_service_starting_delay      => check_item_num_value(n_template_id,
                                                                                        p_service_starting_delay,
                                                                                        lr_mtl_items_rec.service_starting_delay), -- p_service_starting_delay => nvl(p_service_starting_delay, EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_material_billable_flag      => check_item_chr_value(n_template_id,
                                                                                        p_material_billable_flag,
                                                                                        lr_mtl_items_rec.material_billable_flag), -- p_material_billable_flag => nvl(p_material_billable_flag, EGO_ITEM_PUB.G_MISS_CHAR ),
                                  p_serviceable_component_flag  => check_item_chr_value(n_template_id,
                                                                                        p_serviceable_component_flag,
                                                                                        lr_mtl_items_rec.serviceable_component_flag), -- p_serviceable_component_flag => nvl(p_serviceable_component_flag,lr_mtl_items_rec.serviceable_component_flag ),
                                  p_preventive_maintenance_flag => check_item_chr_value(n_template_id,
                                                                                        p_preventive_maintenance_flag,
                                                                                        lr_mtl_items_rec.preventive_maintenance_flag), -- p_preventive_maintenance_flag => nvl(p_preventive_maintenance_flag,lr_mtl_items_rec.preventive_maintenance_flag ),
                                  p_prorate_service_flag        => check_item_chr_value(n_template_id,
                                                                                        p_prorate_service_flag,
                                                                                        lr_mtl_items_rec.prorate_service_flag), -- p_prorate_service_flag => nvl(p_prorate_service_flag,lr_mtl_items_rec.prorate_service_flag ),
                                  p_serviceable_item_class_id   => check_item_num_value(n_template_id,
                                                                                        p_serviceable_item_class_id,
                                                                                        lr_mtl_items_rec.serviceable_item_class_id), -- p_serviceable_item_class_id => nvl(p_serviceable_item_class_id,lr_mtl_items_rec.serviceable_item_class_id ),
                                  p_base_warranty_service_id    => check_item_num_value(n_template_id,
                                                                                        p_base_warranty_service_id,
                                                                                        lr_mtl_items_rec.base_warranty_service_id), -- p_base_warranty_service_id => nvl(p_base_warranty_service_id,lr_mtl_items_rec.base_warranty_service_id ),
                                  p_warranty_vendor_id          => check_item_num_value(n_template_id,
                                                                                        p_warranty_vendor_id,
                                                                                        lr_mtl_items_rec.warranty_vendor_id), -- p_warranty_vendor_id => nvl(p_warranty_vendor_id,lr_mtl_items_rec.warranty_vendor_id ),
                                  p_max_warranty_amount         => check_item_num_value(n_template_id,
                                                                                        p_max_warranty_amount,
                                                                                        lr_mtl_items_rec.max_warranty_amount), -- p_max_warranty_amount => nvl(p_max_warranty_amount,lr_mtl_items_rec.max_warranty_amount ),
                                  p_response_time_period_code   => check_item_chr_value(n_template_id,
                                                                                        p_response_time_period_code,
                                                                                        lr_mtl_items_rec.response_time_period_code), -- p_response_time_period_code => nvl(p_response_time_period_code,lr_mtl_items_rec.response_time_period_code ),
                                  p_response_time_value         => check_item_num_value(n_template_id,
                                                                                        p_response_time_value,
                                                                                        lr_mtl_items_rec.response_time_value), -- p_response_time_value => nvl(p_response_time_value,lr_mtl_items_rec.response_time_value ),
                                  p_primary_specialist_id       => check_item_num_value(n_template_id,
                                                                                        p_primary_specialist_id,
                                                                                        lr_mtl_items_rec.primary_specialist_id), -- p_primary_specialist_id => nvl(p_primary_specialist_id,lr_mtl_items_rec.primary_specialist_id ),
                                  p_secondary_specialist_id     => check_item_num_value(n_template_id,
                                                                                        p_secondary_specialist_id,
                                                                                        lr_mtl_items_rec.secondary_specialist_id), --p_secondary_specialist_id => nvl(p_secondary_specialist_id,lr_mtl_items_rec.secondary_specialist_id ),
                                  p_wh_update_date              => check_item_date_value(n_template_id,
                                                                                         p_wh_update_date,
                                                                                         lr_mtl_items_rec.wh_update_date), -- p_wh_update_date => nvl(p_wh_update_date,lr_mtl_items_rec.wh_update_date ),
                                  p_equipment_type              => check_item_num_value(n_template_id,
                                                                                        p_equipment_type,
                                                                                        lr_mtl_items_rec.equipment_type), -- p_equipment_type => nvl(p_equipment_type,EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_recovered_part_disp_code    => check_item_chr_value(n_template_id,
                                                                                        p_recovered_part_disp_code,
                                                                                        lr_mtl_items_rec.recovered_part_disp_code), -- p_recovered_part_disp_code => nvl(p_recovered_part_disp_code, EGO_ITEM_PUB.G_MISS_CHAR ),
                                  p_defect_tracking_on_flag     => check_item_chr_value(n_template_id,
                                                                                        p_defect_tracking_on_flag,
                                                                                        lr_mtl_items_rec.defect_tracking_on_flag), -- p_defect_tracking_on_flag => nvl(p_defect_tracking_on_flag, EGO_ITEM_PUB.G_MISS_CHAR ),
                                  p_event_flag                  => check_item_chr_value(n_template_id,
                                                                                        p_event_flag,
                                                                                        lr_mtl_items_rec.event_flag), -- p_event_flag => nvl(p_event_flag, EGO_ITEM_PUB.G_MISS_CHAR ),
                                  p_electronic_flag             => check_item_chr_value(n_template_id,
                                                                                        p_electronic_flag,
                                                                                        lr_mtl_items_rec.electronic_flag), -- p_electronic_flag => nvl(p_electronic_flag, EGO_ITEM_PUB.G_MISS_CHAR ),
                                  p_downloadable_flag           => check_item_chr_value(n_template_id,
                                                                                        p_downloadable_flag,
                                                                                        lr_mtl_items_rec.downloadable_flag), -- p_downloadable_flag => nvl(p_downloadable_flag, EGO_ITEM_PUB.G_MISS_CHAR ),
                                  p_vol_discount_exempt_flag    => check_item_chr_value(n_template_id,
                                                                                        p_vol_discount_exempt_flag,
                                                                                        lr_mtl_items_rec.vol_discount_exempt_flag), -- p_vol_discount_exempt_flag => nvl(p_vol_discount_exempt_flag, EGO_ITEM_PUB.G_MISS_CHAR ),
                                  p_coupon_exempt_flag          => check_item_chr_value(n_template_id,
                                                                                        p_coupon_exempt_flag,
                                                                                        lr_mtl_items_rec.coupon_exempt_flag), -- p_coupon_exempt_flag => nvl(p_coupon_exempt_flag, EGO_ITEM_PUB.G_MISS_CHAR ),
                                  p_comms_nl_trackable_flag     => check_item_chr_value(n_template_id,
                                                                                        p_comms_nl_trackable_flag,
                                                                                        lr_mtl_items_rec.comms_nl_trackable_flag), -- p_comms_nl_trackable_flag => nvl(p_comms_nl_trackable_flag,nvl(n_comms_nl_trackable_flag, EGO_ITEM_PUB.G_MISS_CHAR )),--add by yan
                                  p_asset_creation_code         => check_item_chr_value(n_template_id,
                                                                                        p_asset_creation_code,
                                                                                        lr_mtl_items_rec.asset_creation_code), -- p_asset_creation_code => nvl(p_asset_creation_code, EGO_ITEM_PUB.G_MISS_CHAR ),
                                  p_comms_activation_reqd_flag  => check_item_chr_value(n_template_id,
                                                                                        p_comms_activation_reqd_flag,
                                                                                        lr_mtl_items_rec.comms_activation_reqd_flag), -- p_comms_activation_reqd_flag => nvl(p_comms_activation_reqd_flag, EGO_ITEM_PUB.G_MISS_CHAR ),
                                  p_orderable_on_web_flag       => check_item_chr_value(n_template_id,
                                                                                        p_orderable_on_web_flag,
                                                                                        lr_mtl_items_rec.orderable_on_web_flag), -- p_orderable_on_web_flag => nvl(p_orderable_on_web_flag, EGO_ITEM_PUB.G_MISS_CHAR ),
                                  p_back_orderable_flag         => check_item_chr_value(n_template_id,
                                                                                        p_back_orderable_flag,
                                                                                        lr_mtl_items_rec.back_orderable_flag), -- p_back_orderable_flag => nvl(p_back_orderable_flag, EGO_ITEM_PUB.G_MISS_CHAR ),
                                  p_web_status                  => check_item_chr_value(n_template_id,
                                                                                        p_web_status,
                                                                                        lr_mtl_items_rec.web_status), --  p_web_status => nvl(p_web_status, EGO_ITEM_PUB.G_MISS_CHAR ),
                                  p_indivisible_flag            => check_item_chr_value(n_template_id,
                                                                                        p_indivisible_flag,
                                                                                        lr_mtl_items_rec.indivisible_flag), --  p_indivisible_flag => nvl(p_indivisible_flag, EGO_ITEM_PUB.G_MISS_CHAR ),
                                  p_dimension_uom_code          => nvl(v_dimension_uom_code,
                                                                       g_miss_char),
                                  p_unit_length                 => v_length,
                                  p_unit_width                  => v_width,
                                  p_unit_height                 => v_height,
                                  p_bulk_picked_flag            => check_item_chr_value(n_template_id,
                                                                                        p_bulk_picked_flag,
                                                                                        lr_mtl_items_rec.bulk_picked_flag), -- p_bulk_picked_flag => nvl(p_bulk_picked_flag, EGO_ITEM_PUB.G_MISS_CHAR ),
                                  p_lot_status_enabled          => check_item_chr_value(n_template_id,
                                                                                        p_lot_status_enabled,
                                                                                        lr_mtl_items_rec.lot_status_enabled), -- p_lot_status_enabled => nvl(p_lot_status_enabled, EGO_ITEM_PUB.G_MISS_CHAR ),
                                  p_default_lot_status_id       => check_item_num_value(n_template_id,
                                                                                        p_default_lot_status_id,
                                                                                        lr_mtl_items_rec.default_lot_status_id), -- p_default_lot_status_id => nvl(p_default_lot_status_id, EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_serial_status_enabled       => check_item_chr_value(n_template_id,
                                                                                        p_serial_status_enabled,
                                                                                        lr_mtl_items_rec.serial_status_enabled), -- p_serial_status_enabled => nvl(p_serial_status_enabled, EGO_ITEM_PUB.G_MISS_CHAR  ),
                                  p_default_serial_status_id    => check_item_num_value(n_template_id,
                                                                                        p_default_serial_status_id,
                                                                                        lr_mtl_items_rec.default_serial_status_id), --  p_default_serial_status_id => nvl(p_default_serial_status_id, EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_lot_split_enabled           => check_item_chr_value(n_template_id,
                                                                                        p_lot_split_enabled,
                                                                                        lr_mtl_items_rec.lot_split_enabled), -- p_lot_split_enabled => nvl(p_lot_split_enabled, EGO_ITEM_PUB.G_MISS_CHAR  ),
                                  p_lot_merge_enabled           => check_item_chr_value(n_template_id,
                                                                                        p_lot_merge_enabled,
                                                                                        lr_mtl_items_rec.lot_merge_enabled), -- p_lot_merge_enabled => nvl(p_lot_merge_enabled, EGO_ITEM_PUB.G_MISS_CHAR  ),
                                  p_inventory_carry_penalty     => check_item_num_value(n_template_id,
                                                                                        p_inventory_carry_penalty,
                                                                                        lr_mtl_items_rec.inventory_carry_penalty), -- p_inventory_carry_penalty => nvl(p_inventory_carry_penalty, EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_operation_slack_penalty     => check_item_num_value(n_template_id,
                                                                                        p_operation_slack_penalty,
                                                                                        lr_mtl_items_rec.operation_slack_penalty), -- p_operation_slack_penalty => nvl(p_operation_slack_penalty, EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_financing_allowed_flag      => check_item_chr_value(n_template_id,
                                                                                        p_financing_allowed_flag,
                                                                                        lr_mtl_items_rec.financing_allowed_flag), -- p_financing_allowed_flag => nvl(p_financing_allowed_flag, EGO_ITEM_PUB.G_MISS_CHAR  ),
                                  p_eam_item_type               => check_item_num_value(n_template_id,
                                                                                        p_eam_item_type,
                                                                                        lr_mtl_items_rec.eam_item_type), -- p_eam_item_type => nvl(p_eam_item_type, EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_eam_activity_type_code      => check_item_chr_value(n_template_id,
                                                                                        p_eam_activity_type_code,
                                                                                        lr_mtl_items_rec.eam_activity_type_code), -- p_eam_activity_type_code => nvl(p_eam_activity_type_code, EGO_ITEM_PUB.G_MISS_CHAR  ),
                                  p_eam_activity_cause_code     => check_item_chr_value(n_template_id,
                                                                                        p_eam_activity_cause_code,
                                                                                        lr_mtl_items_rec.eam_activity_cause_code), --  p_eam_activity_cause_code => nvl(p_eam_activity_cause_code, EGO_ITEM_PUB.G_MISS_CHAR  ),
                                  p_eam_act_notification_flag   => check_item_chr_value(n_template_id,
                                                                                        p_eam_act_notification_flag,
                                                                                        lr_mtl_items_rec.eam_act_notification_flag), -- p_eam_act_notification_flag => nvl(p_eam_act_notification_flag, EGO_ITEM_PUB.G_MISS_CHAR  ),
                                  p_eam_act_shutdown_status     => check_item_chr_value(n_template_id,
                                                                                        p_eam_act_shutdown_status,
                                                                                        lr_mtl_items_rec.eam_act_shutdown_status), -- p_eam_act_shutdown_status => nvl(p_eam_act_shutdown_status, EGO_ITEM_PUB.G_MISS_CHAR  ),
                                  p_dual_uom_control            => check_item_num_value(n_template_id,
                                                                                        p_dual_uom_control,
                                                                                        lr_mtl_items_rec.dual_uom_control), --  p_dual_uom_control => nvl(p_dual_uom_control, EGO_ITEM_PUB.G_MISS_NUM  ),
                                  p_secondary_uom_code          => check_item_chr_value(n_template_id,
                                                                                        v_secondary_uom_code,
                                                                                        lr_mtl_items_rec.secondary_uom_code), -- p_secondary_uom_code => nvl(v_secondary_uom_code,EGO_ITEM_PUB.G_MISS_CHAR ),
                                  p_dual_uom_deviation_high     => check_item_num_value(n_template_id,
                                                                                        p_dual_uom_deviation_high,
                                                                                        lr_mtl_items_rec.dual_uom_deviation_high), --  p_dual_uom_deviation_high => nvl(p_dual_uom_deviation_high, EGO_ITEM_PUB.G_MISS_NUM  ),
                                  p_dual_uom_deviation_low      => check_item_num_value(n_template_id,
                                                                                        p_dual_uom_deviation_low,
                                                                                        lr_mtl_items_rec.dual_uom_deviation_low), --  p_dual_uom_deviation_low => nvl(p_dual_uom_deviation_low, EGO_ITEM_PUB.G_MISS_NUM  ),
                                  p_contract_item_type_code     => check_item_chr_value(n_template_id,
                                                                                        p_contract_item_type_code,
                                                                                        lr_mtl_items_rec.contract_item_type_code), -- p_contract_item_type_code => nvl(p_contract_item_type_code, EGO_ITEM_PUB.G_MISS_CHAR ),
                                  p_subscription_depend_flag    => check_item_chr_value(n_template_id,
                                                                                        p_subscription_depend_flag,
                                                                                        lr_mtl_items_rec.subscription_depend_flag), --  p_subscription_depend_flag => nvl(p_subscription_depend_flag, EGO_ITEM_PUB.G_MISS_CHAR ),
                                  p_serv_req_enabled_code       => check_item_chr_value(n_template_id,
                                                                                        p_serv_req_enabled_code,
                                                                                        lr_mtl_items_rec.serv_req_enabled_code), -- p_serv_req_enabled_code => nvl(p_serv_req_enabled_code, EGO_ITEM_PUB.G_MISS_CHAR ),
                                  p_serv_billing_enabled_flag   => check_item_chr_value(n_template_id,
                                                                                        p_serv_billing_enabled_flag,
                                                                                        lr_mtl_items_rec.serv_billing_enabled_flag), --  p_serv_billing_enabled_flag => nvl(p_serv_billing_enabled_flag, EGO_ITEM_PUB.G_MISS_CHAR ),
                                  p_serv_importance_level       => check_item_num_value(n_template_id,
                                                                                        p_serv_importance_level,
                                                                                        lr_mtl_items_rec.serv_importance_level), --  p_serv_importance_level => nvl(p_serv_importance_level, EGO_ITEM_PUB.G_MISS_NUM  ),
                                  p_planned_inv_point_flag      => check_item_chr_value(n_template_id,
                                                                                        p_planned_inv_point_flag,
                                                                                        lr_mtl_items_rec.planned_inv_point_flag), --    p_planned_inv_point_flag => nvl(p_planned_inv_point_flag, EGO_ITEM_PUB.G_MISS_CHAR ),
                                  p_lot_translate_enabled       => check_item_chr_value(n_template_id,
                                                                                        p_lot_translate_enabled,
                                                                                        lr_mtl_items_rec.lot_translate_enabled), -- p_lot_translate_enabled => nvl(p_lot_translate_enabled, EGO_ITEM_PUB.G_MISS_CHAR ),
                                  p_default_so_source_type      => check_item_chr_value(n_template_id,
                                                                                        p_default_so_source_type,
                                                                                        lr_mtl_items_rec.default_so_source_type), -- p_default_so_source_type => nvl(p_default_so_source_type, EGO_ITEM_PUB.G_MISS_CHAR ),
                                  p_create_supply_flag          => check_item_chr_value(n_template_id,
                                                                                        p_create_supply_flag,
                                                                                        lr_mtl_items_rec.create_supply_flag), -- p_create_supply_flag => nvl(p_create_supply_flag, EGO_ITEM_PUB.G_MISS_CHAR ),
                                  p_substitution_window_code    => check_item_num_value(n_template_id,
                                                                                        p_substitution_window_code,
                                                                                        lr_mtl_items_rec.substitution_window_code), -- p_substitution_window_code => nvl(p_substitution_window_code, EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_substitution_window_days    => check_item_num_value(n_template_id,
                                                                                        p_substitution_window_days,
                                                                                        lr_mtl_items_rec.substitution_window_days), -- p_substitution_window_days => nvl(p_substitution_window_days,lr_mtl_items_rec.substitution_window_days ),
                                  p_ib_item_instance_class      => check_item_chr_value(n_template_id,
                                                                                        p_ib_item_instance_class,
                                                                                        lr_mtl_items_rec.ib_item_instance_class), -- p_ib_item_instance_class => nvl(p_ib_item_instance_class, EGO_ITEM_PUB.G_MISS_CHAR ),
                                  p_config_model_type           => check_item_chr_value(n_template_id,
                                                                                        p_config_model_type,
                                                                                        lr_mtl_items_rec.config_model_type), -- p_config_model_type => nvl(p_config_model_type, EGO_ITEM_PUB.G_MISS_CHAR ),
                                  p_lot_substitution_enabled    => check_item_chr_value(n_template_id,
                                                                                        p_lot_substitution_enabled,
                                                                                        lr_mtl_items_rec.lot_substitution_enabled), -- p_lot_substitution_enabled => nvl(p_lot_substitution_enabled, EGO_ITEM_PUB.G_MISS_CHAR ),
                                  p_minimum_license_quantity    => check_item_num_value(n_template_id,
                                                                                        p_minimum_license_quantity,
                                                                                        lr_mtl_items_rec.minimum_license_quantity), --p_minimum_license_quantity => nvl(p_minimum_license_quantity, EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_eam_activity_source_code    => check_item_chr_value(n_template_id,
                                                                                        p_eam_activity_source_code,
                                                                                        lr_mtl_items_rec.eam_activity_source_code), -- p_eam_activity_source_code => nvl(p_eam_activity_source_code, EGO_ITEM_PUB.G_MISS_CHAR ),
                                  p_approval_status             => check_item_chr_value(n_template_id,
                                                                                        p_approval_status,
                                                                                        lr_mtl_items_rec.approval_status), -- p_approval_status => nvl(p_approval_status,lr_mtl_items_rec.approval_status ),
                                  p_tracking_quantity_ind       => check_item_chr_value(n_template_id,
                                                                                        p_tracking_quantity_ind,
                                                                                        lr_mtl_items_rec.tracking_quantity_ind), -- p_tracking_quantity_ind => nvl(p_tracking_quantity_ind, EGO_ITEM_PUB.G_MISS_CHAR ),
                                  p_ont_pricing_qty_source      => check_item_chr_value(n_template_id,
                                                                                        p_ont_pricing_qty_source,
                                                                                        lr_mtl_items_rec.ont_pricing_qty_source), -- p_ont_pricing_qty_source => nvl(p_ont_pricing_qty_source, EGO_ITEM_PUB.G_MISS_CHAR ),
                                  p_secondary_default_ind       => check_item_chr_value(n_template_id,
                                                                                        p_secondary_default_ind,
                                                                                        lr_mtl_items_rec.secondary_default_ind), --p_secondary_default_ind => nvl(p_secondary_default_ind, EGO_ITEM_PUB.G_MISS_CHAR ),
                                  p_option_specific_sourced     => check_item_num_value(n_template_id,
                                                                                        p_option_specific_sourced,
                                                                                        lr_mtl_items_rec.option_specific_sourced), -- p_option_specific_sourced => nvl(p_option_specific_sourced, EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_vmi_minimum_units           => check_item_num_value(n_template_id,
                                                                                        p_vmi_minimum_units,
                                                                                        lr_mtl_items_rec.vmi_minimum_units), -- p_vmi_minimum_units => nvl(p_vmi_minimum_units, EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_vmi_minimum_days            => check_item_num_value(n_template_id,
                                                                                        p_vmi_minimum_days,
                                                                                        lr_mtl_items_rec.vmi_minimum_days), -- p_vmi_minimum_days => nvl(p_vmi_minimum_days, EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_vmi_maximum_units           => check_item_num_value(n_template_id,
                                                                                        p_vmi_maximum_units,
                                                                                        lr_mtl_items_rec.vmi_maximum_units), -- p_vmi_maximum_units => nvl(p_vmi_maximum_units, EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_vmi_maximum_days            => check_item_num_value(n_template_id,
                                                                                        p_vmi_maximum_days,
                                                                                        lr_mtl_items_rec.vmi_maximum_days), -- p_vmi_maximum_days => nvl(p_vmi_maximum_days, EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_vmi_fixed_order_quantity    => check_item_num_value(n_template_id,
                                                                                        p_vmi_fixed_order_quantity,
                                                                                        lr_mtl_items_rec.vmi_fixed_order_quantity), -- p_vmi_fixed_order_quantity => nvl(p_vmi_fixed_order_quantity, EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_so_authorization_flag       => check_item_num_value(n_template_id,
                                                                                        p_so_authorization_flag,
                                                                                        lr_mtl_items_rec.so_authorization_flag), -- p_so_authorization_flag => nvl(p_so_authorization_flag, EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_consigned_flag              => check_item_num_value(n_template_id,
                                                                                        p_consigned_flag,
                                                                                        lr_mtl_items_rec.consigned_flag), -- p_consigned_flag => nvl(p_consigned_flag, EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_asn_autoexpire_flag         => check_item_num_value(n_template_id,
                                                                                        p_asn_autoexpire_flag,
                                                                                        lr_mtl_items_rec.asn_autoexpire_flag), -- p_asn_autoexpire_flag => nvl(p_asn_autoexpire_flag, EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_vmi_forecast_type           => check_item_num_value(n_template_id,
                                                                                        p_vmi_forecast_type,
                                                                                        lr_mtl_items_rec.vmi_forecast_type), -- p_vmi_forecast_type => nvl(p_vmi_forecast_type, EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_forecast_horizon            => check_item_num_value(n_template_id,
                                                                                        p_forecast_horizon,
                                                                                        lr_mtl_items_rec.forecast_horizon), -- p_forecast_horizon => nvl(p_forecast_horizon, EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_exclude_from_budget_flag    => check_item_num_value(n_template_id,
                                                                                        p_exclude_from_budget_flag,
                                                                                        lr_mtl_items_rec.exclude_from_budget_flag), -- p_exclude_from_budget_flag => nvl(p_exclude_from_budget_flag, EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_days_tgt_inv_supply         => check_item_num_value(n_template_id,
                                                                                        p_days_tgt_inv_supply,
                                                                                        lr_mtl_items_rec.days_tgt_inv_supply), -- p_days_tgt_inv_supply => nvl(p_days_tgt_inv_supply, EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_days_tgt_inv_window         => check_item_num_value(n_template_id,
                                                                                        p_days_tgt_inv_window,
                                                                                        lr_mtl_items_rec.days_tgt_inv_window), --  p_days_tgt_inv_window => nvl(p_days_tgt_inv_window, EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_days_max_inv_supply         => check_item_num_value(n_template_id,
                                                                                        p_days_max_inv_supply,
                                                                                        lr_mtl_items_rec.days_max_inv_supply), --  p_days_max_inv_supply => nvl(p_days_max_inv_supply, EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_days_max_inv_window         => check_item_num_value(n_template_id,
                                                                                        p_days_max_inv_window,
                                                                                        lr_mtl_items_rec.days_max_inv_window), -- p_days_max_inv_window => nvl(p_days_max_inv_window, EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_drp_planned_flag            => check_item_num_value(n_template_id,
                                                                                        p_drp_planned_flag,
                                                                                        lr_mtl_items_rec.drp_planned_flag), -- p_drp_planned_flag => nvl(p_drp_planned_flag, EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_critical_component_flag     => check_item_num_value(n_template_id,
                                                                                        p_critical_component_flag,
                                                                                        lr_mtl_items_rec.critical_component_flag), --  p_critical_component_flag => nvl(p_critical_component_flag, EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_continous_transfer          => check_item_num_value(n_template_id,
                                                                                        p_continous_transfer,
                                                                                        lr_mtl_items_rec.continous_transfer), -- p_continous_transfer => nvl(p_continous_transfer, EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_convergence                 => check_item_num_value(n_template_id,
                                                                                        p_convergence,
                                                                                        lr_mtl_items_rec.convergence), -- p_convergence => nvl(p_convergence, EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_divergence                  => check_item_num_value(n_template_id,
                                                                                        p_divergence,
                                                                                        lr_mtl_items_rec.divergence), -- p_divergence => nvl(p_divergence, EGO_ITEM_PUB.G_MISS_NUM ),
                                  p_config_orgs                 => check_item_chr_value(n_template_id,
                                                                                        p_config_orgs,
                                                                                        lr_mtl_items_rec.config_orgs), -- p_config_orgs => nvl(p_config_orgs, EGO_ITEM_PUB.G_MISS_CHAR ),
                                  p_config_match                => check_item_chr_value(n_template_id,
                                                                                        p_config_match,
                                                                                        lr_mtl_items_rec.config_match), -- p_config_match => nvl(p_config_match, EGO_ITEM_PUB.G_MISS_CHAR ),
                                  p_item_number                 => p_item_number,
                                  p_segment1                    => check_item_chr_value(n_template_id,
                                                                                        p_segment1,
                                                                                        lr_mtl_items_rec.segment1), --  p_segment1 => nvl(p_segment1,lr_mtl_items_rec.segment1 ),
                                  p_segment2                    => NULL, --  p_segment2 => nvl(p_segment2,lr_mtl_items_rec.segment2 ),
                                  p_segment3                    => check_item_chr_value(n_template_id,
                                                                                        p_segment3,
                                                                                        lr_mtl_items_rec.segment3), --  p_segment3 => nvl(p_segment3,lr_mtl_items_rec.segment3 ),
                                  p_segment4                    => check_item_chr_value(n_template_id,
                                                                                        p_segment4,
                                                                                        lr_mtl_items_rec.segment4), --  p_segment4 => nvl(p_segment4,lr_mtl_items_rec.segment4 ),
                                  p_segment5                    => check_item_chr_value(n_template_id,
                                                                                        p_segment5,
                                                                                        lr_mtl_items_rec.segment5), --  p_segment5 => nvl(p_segment5,lr_mtl_items_rec.segment5 ),
                                  p_segment6                    => check_item_chr_value(n_template_id,
                                                                                        p_segment6,
                                                                                        lr_mtl_items_rec.segment6), -- p_segment6 => nvl(p_segment6,lr_mtl_items_rec.segment6 ),
                                  p_segment7                    => check_item_chr_value(n_template_id,
                                                                                        p_segment7,
                                                                                        lr_mtl_items_rec.segment7), -- p_segment7 => nvl(p_segment7,lr_mtl_items_rec.segment7 ),
                                  p_segment8                    => check_item_chr_value(n_template_id,
                                                                                        p_segment8,
                                                                                        lr_mtl_items_rec.segment8), -- p_segment8 => nvl(p_segment8,lr_mtl_items_rec.segment8 ),
                                  p_segment9                    => check_item_chr_value(n_template_id,
                                                                                        p_segment9,
                                                                                        lr_mtl_items_rec.segment9), -- p_segment9 => nvl(p_segment9,lr_mtl_items_rec.segment9 ),
                                  p_segment10                   => check_item_chr_value(n_template_id,
                                                                                        p_segment10,
                                                                                        lr_mtl_items_rec.segment10), -- p_segment10 => nvl(p_segment10,lr_mtl_items_rec.segment10 ),
                                  p_segment11                   => check_item_chr_value(n_template_id,
                                                                                        p_segment11,
                                                                                        lr_mtl_items_rec.segment11), -- p_segment11 => nvl(p_segment11,lr_mtl_items_rec.segment11 ),
                                  p_segment12                   => check_item_chr_value(n_template_id,
                                                                                        p_segment12,
                                                                                        lr_mtl_items_rec.segment12), -- p_segment12 => nvl(p_segment12,lr_mtl_items_rec.segment12 ),
                                  p_segment13                   => check_item_chr_value(n_template_id,
                                                                                        p_segment13,
                                                                                        lr_mtl_items_rec.segment13), --p_segment13 => nvl(p_segment13,lr_mtl_items_rec.segment13 ),
                                  p_segment14                   => check_item_chr_value(n_template_id,
                                                                                        p_segment14,
                                                                                        lr_mtl_items_rec.segment14), --p_segment14 => nvl(p_segment14,lr_mtl_items_rec.segment14 ),
                                  p_segment15                   => check_item_chr_value(n_template_id,
                                                                                        p_segment15,
                                                                                        lr_mtl_items_rec.segment15), -- p_segment15 => nvl(p_segment15,lr_mtl_items_rec.segment15 ),
                                  p_segment16                   => check_item_chr_value(n_template_id,
                                                                                        p_segment16,
                                                                                        lr_mtl_items_rec.segment16), --p_segment16 => nvl(p_segment16,lr_mtl_items_rec.segment16 ),
                                  p_segment17                   => check_item_chr_value(n_template_id,
                                                                                        p_segment17,
                                                                                        lr_mtl_items_rec.segment17), -- p_segment17 => nvl(p_segment17,lr_mtl_items_rec.segment17 ),
                                  p_segment18                   => check_item_chr_value(n_template_id,
                                                                                        p_segment18,
                                                                                        lr_mtl_items_rec.segment18), -- p_segment18 => nvl(p_segment18,lr_mtl_items_rec.segment18 ),
                                  p_segment19                   => check_item_chr_value(n_template_id,
                                                                                        p_segment19,
                                                                                        lr_mtl_items_rec.segment19), -- p_segment19 => nvl(p_segment19,lr_mtl_items_rec.segment19 ),
                                  p_segment20                   => check_item_chr_value(n_template_id,
                                                                                        p_segment20,
                                                                                        lr_mtl_items_rec.segment20), -- p_segment20 => nvl(p_segment20,lr_mtl_items_rec.segment20 ),
                                  p_summary_flag                => check_item_chr_value(n_template_id,
                                                                                        p_summary_flag,
                                                                                        lr_mtl_items_rec.summary_flag), -- p_summary_flag => nvl(p_summary_flag,lr_mtl_items_rec.summary_flag ),
                                  p_enabled_flag                => check_item_chr_value(n_template_id,
                                                                                        p_enabled_flag,
                                                                                        lr_mtl_items_rec.enabled_flag), -- p_enabled_flag => nvl(p_enabled_flag,lr_mtl_items_rec.enabled_flag ),
                                  p_start_date_active           => check_item_date_value(n_template_id,
                                                                                         p_start_date_active,
                                                                                         lr_mtl_items_rec.start_date_active), -- p_start_date_active => nvl(p_start_date_active,lr_mtl_items_rec.start_date_active ),
                                  p_end_date_active             => check_item_date_value(n_template_id,
                                                                                         p_end_date_active,
                                                                                         lr_mtl_items_rec.end_date_active), -- p_end_date_active => nvl(p_end_date_active,lr_mtl_items_rec.end_date_active ),
                                  p_attribute_category          => check_item_chr_value(n_template_id,
                                                                                        p_attribute_category,
                                                                                        lr_mtl_items_rec.attribute_category), --  p_attribute_category => nvl(p_attribute_category,lr_mtl_items_rec.attribute_category ),
                                  p_attribute1                  => check_item_chr_value(n_template_id,
                                                                                        p_attribute1,
                                                                                        lr_mtl_items_rec.attribute1), --  p_attribute1 => nvl(p_attribute1,lr_mtl_items_rec.attribute1 ),
                                  p_attribute2                  => p_attribute2, --check_item_chr_value (n_template_id,p_attribute2,lr_mtl_items_rec.attribute2),--  p_attribute2 => nvl(p_attribute2,lr_mtl_items_rec.attribute2 ),
                                  p_attribute3                  => check_item_chr_value(n_template_id,
                                                                                        p_attribute3,
                                                                                        lr_mtl_items_rec.attribute3), --  p_attribute3 => nvl(p_attribute3,lr_mtl_items_rec.attribute3 ),
                                  p_attribute4                  => check_item_chr_value(n_template_id,
                                                                                        p_attribute4,
                                                                                        lr_mtl_items_rec.attribute4), --  p_attribute4 => nvl(p_attribute4,lr_mtl_items_rec.attribute4 ),
                                  p_attribute5                  => check_item_chr_value(n_template_id,
                                                                                        p_attribute5,
                                                                                        lr_mtl_items_rec.attribute5), --  p_attribute5 => nvl(p_attribute5,lr_mtl_items_rec.attribute5 ),
                                  p_attribute6                  => check_item_chr_value(n_template_id,
                                                                                        p_attribute6,
                                                                                        lr_mtl_items_rec.attribute6), -- p_attribute6 => nvl(p_attribute6,lr_mtl_items_rec.attribute6 ),
                                  p_attribute7                  => check_item_chr_value(n_template_id,
                                                                                        p_attribute7,
                                                                                        lr_mtl_items_rec.attribute7), -- p_attribute7 => nvl(p_attribute7,lr_mtl_items_rec.attribute7 ),
                                  p_attribute8                  => check_item_chr_value(n_template_id,
                                                                                        p_attribute8,
                                                                                        lr_mtl_items_rec.attribute8), -- p_attribute8 => nvl(p_attribute8,lr_mtl_items_rec.attribute8 ),
                                  p_attribute9                  => check_item_chr_value(n_template_id,
                                                                                        p_attribute9,
                                                                                        lr_mtl_items_rec.attribute9), -- p_attribute9 => nvl(p_attribute9,lr_mtl_items_rec.attribute9 ),
                                  p_attribute10                 => check_item_chr_value(n_template_id,
                                                                                        p_attribute10,
                                                                                        lr_mtl_items_rec.attribute10), -- p_attribute10 => nvl(p_attribute10,lr_mtl_items_rec.attribute10 ),
                                  p_attribute11                 => check_item_chr_value(n_template_id,
                                                                                        p_attribute11,
                                                                                        lr_mtl_items_rec.attribute11), -- p_attribute11 => nvl(p_attribute11,lr_mtl_items_rec.attribute11 ),
                                  p_attribute12                 => check_item_chr_value(n_template_id,
                                                                                        p_attribute12,
                                                                                        lr_mtl_items_rec.attribute12), -- p_attribute12 => nvl(p_attribute12,lr_mtl_items_rec.attribute12 ),
                                  p_attribute13                 => p_attribute13, --check_item_chr_value (n_template_id,p_attribute13,lr_mtl_items_rec.attribute13),--p_attribute13 => nvl(p_attribute13,lr_mtl_items_rec.attribute13 ),
                                  p_attribute14                 => check_item_chr_value(n_template_id,
                                                                                        p_attribute14,
                                                                                        lr_mtl_items_rec.attribute14), --p_attribute14 => nvl(p_attribute14,lr_mtl_items_rec.attribute14 ),
                                  p_attribute15                 => check_item_chr_value(n_template_id,
                                                                                        p_attribute15,
                                                                                        lr_mtl_items_rec.attribute15), -- p_attribute15 => nvl(p_attribute15,lr_mtl_items_rec.attribute15 ),
                                  p_global_attribute_category   => check_item_chr_value(n_template_id,
                                                                                        p_global_attribute_category,
                                                                                        lr_mtl_items_rec.global_attribute_category), -- p_global_attribute_category => nvl(p_global_attribute_category,lr_mtl_items_rec.global_attribute_category ),
                                  p_global_attribute1           => check_item_chr_value(n_template_id,
                                                                                        p_global_attribute1,
                                                                                        lr_mtl_items_rec.global_attribute1), --  p_global_attribute1 => nvl(p_global_attribute1,lr_mtl_items_rec.global_attribute1 ),
                                  p_global_attribute2           => check_item_chr_value(n_template_id,
                                                                                        p_global_attribute2,
                                                                                        lr_mtl_items_rec.global_attribute2), --  p_global_attribute2 => nvl(p_global_attribute2,lr_mtl_items_rec.global_attribute2 ),
                                  p_global_attribute3           => check_item_chr_value(n_template_id,
                                                                                        p_global_attribute3,
                                                                                        lr_mtl_items_rec.global_attribute3), --  p_global_attribute3 => nvl(p_global_attribute3,lr_mtl_items_rec.global_attribute3 ),
                                  p_global_attribute4           => check_item_chr_value(n_template_id,
                                                                                        p_global_attribute4,
                                                                                        lr_mtl_items_rec.global_attribute4), --  p_global_attribute4 => nvl(p_global_attribute4,lr_mtl_items_rec.global_attribute4 ),
                                  p_global_attribute5           => check_item_chr_value(n_template_id,
                                                                                        p_global_attribute5,
                                                                                        lr_mtl_items_rec.global_attribute5), --  p_global_attribute5 => nvl(p_global_attribute5,lr_mtl_items_rec.global_attribute5 ),
                                  p_global_attribute6           => check_item_chr_value(n_template_id,
                                                                                        p_global_attribute6,
                                                                                        lr_mtl_items_rec.global_attribute6), -- p_global_attribute6 => nvl(p_global_attribute6,lr_mtl_items_rec.global_attribute6 ),
                                  p_global_attribute7           => check_item_chr_value(n_template_id,
                                                                                        p_global_attribute7,
                                                                                        lr_mtl_items_rec.global_attribute7), -- p_global_attribute7 => nvl(p_global_attribute7,lr_mtl_items_rec.global_attribute7 ),
                                  p_global_attribute8           => check_item_chr_value(n_template_id,
                                                                                        p_global_attribute8,
                                                                                        lr_mtl_items_rec.global_attribute8), -- p_global_attribute8 => nvl(p_global_attribute8,lr_mtl_items_rec.global_attribute8 ),
                                  p_global_attribute9           => check_item_chr_value(n_template_id,
                                                                                        p_global_attribute9,
                                                                                        lr_mtl_items_rec.global_attribute9), -- p_global_attribute9 => nvl(p_global_attribute9,lr_mtl_items_rec.global_attribute9 ),
                                  p_global_attribute10          => check_item_chr_value(n_template_id,
                                                                                        p_global_attribute10,
                                                                                        lr_mtl_items_rec.global_attribute10), -- p_global_attribute10 => nvl(p_global_attribute10,lr_mtl_items_rec.global_attribute10 ),
                                  p_creation_date               => check_item_date_value(n_template_id,
                                                                                         p_creation_date,
                                                                                         lr_mtl_items_rec.creation_date), --  p_creation_date => nvl(p_creation_date,lr_mtl_items_rec.creation_date ),
                                  p_created_by                  => check_item_num_value(n_template_id,
                                                                                        p_created_by,
                                                                                        lr_mtl_items_rec.created_by), -- p_created_by => nvl(p_created_by,lr_mtl_items_rec.created_by ),
                                  p_last_update_date            => check_item_date_value(n_template_id,
                                                                                         p_last_update_date,
                                                                                         lr_mtl_items_rec.last_update_date), --  p_last_update_date => nvl(p_last_update_date,lr_mtl_items_rec.last_update_date ),
                                  p_last_updated_by             => check_item_num_value(n_template_id,
                                                                                        p_last_updated_by,
                                                                                        lr_mtl_items_rec.last_updated_by), --  p_last_updated_by => nvl(p_last_updated_by,lr_mtl_items_rec.last_updated_by ),
                                  p_last_update_login           => check_item_num_value(n_template_id,
                                                                                        p_last_update_login,
                                                                                        lr_mtl_items_rec.last_update_login), -- p_last_update_login => nvl(p_last_update_login,lr_mtl_items_rec.last_update_login ),
                                  p_request_id                  => check_item_num_value(n_template_id,
                                                                                        p_request_id,
                                                                                        lr_mtl_items_rec.request_id), -- p_request_id => nvl(p_request_id,lr_mtl_items_rec.request_id ),
                                  p_program_application_id      => check_item_num_value(n_template_id,
                                                                                        p_program_application_id,
                                                                                        lr_mtl_items_rec.program_application_id), -- p_program_application_id => nvl(p_program_application_id,lr_mtl_items_rec.program_application_id ),
                                  p_program_id                  => check_item_num_value(n_template_id,
                                                                                        p_program_id,
                                                                                        lr_mtl_items_rec.program_id), -- p_program_id => nvl(p_program_id,lr_mtl_items_rec.program_id ),
                                  p_program_update_date         => check_item_date_value(n_template_id,
                                                                                         p_program_update_date,
                                                                                         lr_mtl_items_rec.program_update_date), -- p_program_update_date => nvl(p_program_update_date,lr_mtl_items_rec.program_update_date ),
                                  p_lifecycle_id                => check_item_num_value(n_template_id,
                                                                                        p_lifecycle_id,
                                                                                        lr_mtl_items_rec.lifecycle_id), --  p_lifecycle_id => nvl(p_lifecycle_id,lr_mtl_items_rec.lifecycle_id ),
                                  p_current_phase_id            => check_item_num_value(n_template_id,
                                                                                        p_current_phase_id,
                                                                                        lr_mtl_items_rec.current_phase_id), -- current_phase_id => nvl(p_current_phase_id,lr_mtl_items_rec.current_phase_id ),
                                  p_revision_id                 => nvl(p_revision_id,
                                                                       ego_item_pub.g_miss_num),
                                  p_revision_code               => nvl(substr(p_revision_code,
                                                                              1,
                                                                              3),
                                                                       lr_mtl_items_rec.new_revision_code),
                                  p_revision_label              => nvl(p_revision_label,
                                                                       ego_item_pub.g_miss_char),
                                  p_revision_description        => nvl(p_revision_description,
                                                                       ego_item_pub.g_miss_char),
                                  p_effectivity_date            => nvl(d_effectivity_date,
                                                                       SYSDATE),
                                  p_rev_lifecycle_id            => nvl(p_rev_lifecycle_id,
                                                                       ego_item_pub.g_miss_num),
                                  p_rev_current_phase_id        => nvl(p_rev_current_phase_id,
                                                                       ego_item_pub.g_miss_num),
                                  p_rev_attribute_category      => nvl(p_rev_attribute_category,
                                                                       ego_item_pub.g_miss_char),
                                  p_rev_attribute1              => nvl(p_rev_attribute1,
                                                                       ego_item_pub.g_miss_char),
                                  p_rev_attribute2              => nvl(p_rev_attribute2,
                                                                       ego_item_pub.g_miss_char),
                                  p_rev_attribute3              => nvl(p_rev_attribute3,
                                                                       ego_item_pub.g_miss_char),
                                  p_rev_attribute4              => nvl(p_rev_attribute4,
                                                                       ego_item_pub.g_miss_char),
                                  p_rev_attribute5              => nvl(p_rev_attribute5,
                                                                       ego_item_pub.g_miss_char),
                                  p_rev_attribute6              => nvl(p_rev_attribute6,
                                                                       ego_item_pub.g_miss_char),
                                  p_rev_attribute7              => nvl(p_rev_attribute7,
                                                                       ego_item_pub.g_miss_char),
                                  p_rev_attribute8              => nvl(p_rev_attribute8,
                                                                       ego_item_pub.g_miss_char),
                                  p_rev_attribute9              => nvl(p_rev_attribute9,
                                                                       ego_item_pub.g_miss_char),
                                  p_rev_attribute10             => nvl(p_rev_attribute10,
                                                                       ego_item_pub.g_miss_char),
                                  p_rev_attribute11             => nvl(p_rev_attribute11,
                                                                       ego_item_pub.g_miss_char),
                                  p_rev_attribute12             => nvl(p_rev_attribute12,
                                                                       ego_item_pub.g_miss_char),
                                  p_rev_attribute13             => nvl(p_rev_attribute13,
                                                                       ego_item_pub.g_miss_char),
                                  p_rev_attribute14             => nvl(p_rev_attribute14,
                                                                       ego_item_pub.g_miss_char),
                                  p_rev_attribute15             => nvl(p_rev_attribute15,
                                                                       ego_item_pub.g_miss_char),
                                  p_process_control             => 'aaaa', --Arik
                                  --problem here !!!
                                  p_apply_template        => 'ALL', --Arik   --check_item_chr_value(n_template_id,null, 'ALL' ), --nvl(p_apply_template,'ALL'),
                                  p_object_version_number => n_object_version_num, --lr_mtl_items_rec.object_version_number,
                                  x_inventory_item_id     => n_inv_item_id,
                                  x_organization_id       => n_api_return_org_id,
                                  x_return_status         => v_api_return_status,
                                  x_msg_count             => n_msg_count,
                                  x_msg_data              => v_msg_data);
        --autonomous_proc.dump_temp('After Update Call:'||v_api_return_status);
        IF v_api_return_status <> fnd_api.g_ret_sts_success THEN
          FOR ro_msg_lst IN 1 .. n_msg_count LOOP
            ln_count := ro_msg_lst;
            error_handler.get_message(lc_error_message,
                                      ln_count,
                                      lc_entity_id,
                                      lc_entity_type);
            -- --autonomous_proc.dump_temp(lc_error_message);
            write_to_log('process_item',
                         lc_error_message || ',Entity ID:' || lc_entity_id ||
                         ', Entity Type:' || lc_entity_type);
            add_error_text(lc_error_message);
          END LOOP;
          RAISE l_item_creation_exception;
        END IF;
      
      END LOOP;
      CLOSE lcu_mtl_items;
      px_inventory_item_id := lr_mtl_items_rec.inventory_item_id;
      px_organization_id   := n_api_return_org_id;
      px_return_status     := ego_item_pub.g_ret_sts_success;
      px_msg_count         := 0;
      px_msg_data          := NULL;
    END IF;
  
    /* open lcu_check_revision(px_inventory_item_id,  substr(p_revision_code,1,3));
    fetch lcu_check_revision into n_temp_num;
    close lcu_check_revision;*/
  
    --autonomous_proc.dump_temp( '  v_api_return_status amir='||v_api_return_status);
    --if (nvl(n_temp_num,0) <> 1) then
    -- create new revision for the inventory item id created
    create_item_revision(p_transaction_type  => 'CREATE',
                         p_inventory_item_id => px_inventory_item_id,
                         p_revision          => substr(p_revision_code, 1, 3),
                         p_description       => p_revision_description,
                         p_effectivity_date  => nvl(d_effectivity_date,
                                                    SYSDATE),
                         p_revision_reason   => '',
                         p_revision_label    => substr(p_revision_label,
                                                       1,
                                                       3),
                         p_lifecycle_id      => p_rev_lifecycle_id,
                         p_current_phase_id  => p_rev_current_phase_id,
                         x_return_status     => v_api_return_status,
                         x_msg_data          => v_msg_data);
  
    --autonomous_proc.dump_temp( ' v_api_return_status amir1='||v_api_return_status);
  
    IF (v_api_return_status <> 'S') THEN
      px_inventory_item_id := NULL;
      px_organization_id   := NULL;
      px_return_status     := ego_item_pub.g_ret_sts_error;
      px_msg_count         := 1;
      px_msg_data          := 'REV: ' || v_msg_data;
    ELSE
      px_inventory_item_id := px_inventory_item_id;
      px_organization_id   := n_api_return_org_id;
      px_return_status     := ego_item_pub.g_ret_sts_success;
      px_msg_count         := 0;
      px_msg_data          := NULL;
    END IF;
  
    --  end if;
  
    --Update table for next XML file creation 
    UPDATE xxobjt.xxobjt_agile_items xx
       SET xx.attribute1 = v_api_return_status,
           xx.attribute2 = substr(px_msg_data, 1, 1000)
     WHERE xx.item_number = p_item_number
       AND xx.attribute1 IS NULL;
    COMMIT;
  
  EXCEPTION
    WHEN l_misc_exception THEN
      px_return_status := 'E';
    
      --Update table for next XML file creation 
      UPDATE xxobjt.xxobjt_agile_items xx
         SET xx.attribute1 = 'E', xx.attribute2 = px_msg_data
       WHERE xx.item_number = p_item_number
         AND xx.attribute1 IS NULL;
      COMMIT;
    WHEN l_exception THEN
    
      --autonomous_proc.dump_temp('From l_Exception:'||fnd_message.get || sqlerrm);
      px_inventory_item_id := NULL;
      px_organization_id   := NULL;
      px_return_status     := 'E';
      px_msg_count         := 1;
      px_msg_data          := 'Template Is Not Exist For Item: ' ||
                              p_item_number;
    
      --Update table for next XML file creation 
      UPDATE xxobjt.xxobjt_agile_items xx
         SET xx.attribute1 = 'E',
             xx.attribute2 = 'Template Is Not Exist For Item: ' ||
                             p_item_number
       WHERE xx.item_number = p_item_number
         AND xx.attribute1 IS NULL;
      COMMIT;
    WHEN l_item_creation_exception THEN
    
      --autonomous_proc.dump_temp('From l_item_creation_exception gv_error_text=:'||gv_error_text);
      --autonomous_proc.dump_temp('From l_item_creation_exception sqlerrm=:'||sqlerrm);
      px_inventory_item_id := NULL;
      px_organization_id   := NULL;
      px_return_status     := ego_item_pub.g_ret_sts_error;
      px_msg_count         := n_msg_count;
      px_msg_data          := substr(lc_error_message, 1, 240); --gv_error_text || '  ' || SQLERRM; -- this is set in the loop for error messages
    
      --Update table for next XML file creation 
      UPDATE xxobjt.xxobjt_agile_items xx
         SET xx.attribute1 = ego_item_pub.g_ret_sts_error,
             xx.attribute2 = px_msg_data
       WHERE xx.item_number = p_item_number
         AND xx.attribute1 IS NULL;
      COMMIT;
    
    WHEN OTHERS THEN
    
      --autonomous_proc.dump_temp('From others: '|| sqlerrm);
      fnd_message.set_name('INV', 'INV_ITEM_UNEXPECTED_ERROR');
      fnd_message.set_token('PACKAGE_NAME', 'XXAGILE_PROCESS_ITEM_PKG');
      fnd_message.set_token('PROCEDURE_NAME', 'PROCESS_ITEM');
      fnd_message.set_token('ERROR_TEXT',
                            'Item Number: ' || p_item_number || ': ' ||
                            SQLERRM);
      px_msg_data          := fnd_message.get || '  ' || SQLERRM;
      px_inventory_item_id := NULL;
      px_organization_id   := NULL;
      px_return_status     := ego_item_pub.g_ret_sts_unexp_error;
      px_msg_count         := 1;
    
      --Update table for next XML file creation 
      UPDATE xxobjt.xxobjt_agile_items xx
         SET xx.attribute1 = ego_item_pub.g_ret_sts_unexp_error,
             xx.attribute2 = substr(px_msg_data, 1, 240)
       WHERE xx.item_number = p_item_number
         AND xx.attribute1 IS NULL;
      COMMIT;
    
  END process_item;

END xxagile_process_item_pkg;
/
