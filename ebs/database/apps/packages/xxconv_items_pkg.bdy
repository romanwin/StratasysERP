CREATE OR REPLACE PACKAGE BODY xxconv_items_pkg IS
  ---------------------------------------------------------------------------
  -- $Header: xxconv_items_pkg   $
  ---------------------------------------------------------------------------
  -- Package: xxconv_items_pkg
  -- Created:
  -- Author  :
  --------------------------------------------------------------------------
  -- Perpose: item conversions , data fix...
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --        xx/xx/xxxx              initial buid  
  --  1.1   15.5.13    vitaly       insert_items_into_all_org changed (CR739)
  --  1.2    1.6.13    vitaly       update_item_org_attributes added  (CR727)
  --  1.3   12.6.13    vitaly       copy_item_revisions added         (CR810)
  --  1.4   14.8.13    vitaly       rename insert_items_into_all_org to item_org_assignment (CR810)
  --                                parameter p_master_organization_id was removed from item_org_assignment
  --                                apps_initialize was removed from item_org_assignment 
  --  1.5   14.8.13    vitaly       copy_organization_planner added (CR810)
  --  1.6   18.8.13    Vitaly       CR 870 std cost - change hard-coded organization
  ------------------------------------------------------------------

  --TYPE t_organizations_type IS TABLE OF NUMBER INDEX BY BINARY_INTEGER;
  -----------------------------------------------------------------------------
  PROCEDURE message(p_message VARCHAR2) IS
  
  BEGIN
    ----dbms_output.put_line(p_message);
    fnd_file.put_line(fnd_file.log, '========= ' || p_message);
  EXCEPTION
    WHEN OTHERS THEN
      NULL;
  END message;
  ---------------------------------------------
  PROCEDURE insert_interface_master(errbuf                   OUT VARCHAR2,
                                    retcode                  OUT VARCHAR2,
                                    p_master_organization_id IN NUMBER) IS
  
    CURSOR csr_master_items IS
      SELECT *
        FROM xxobjt_conv_items
       WHERE trans_to_int_code = 'N'
       ORDER BY item_code;
  
    cur_item  csr_master_items%ROWTYPE;
    v_user_id fnd_user.user_id%TYPE;
    --v_error                  VARCHAR2(100);
    l_counter              NUMBER := 0;
    l_coa_id               NUMBER;
    l_org_id               NUMBER;
    l_error_msg            VARCHAR2(500);
    l_err_msg              VARCHAR2(500);
    l_return_status        VARCHAR2(1);
    v_cat_group_id         mtl_item_catalog_groups_b.item_catalog_group_id%TYPE;
    v_planner_code         VARCHAR2(10);
    l_unit_of_measure      mtl_units_of_measure_tl.unit_of_measure%TYPE;
    l_uom                  VARCHAR2(3);
    l_sales_account_id     NUMBER;
    l_cogs_id              NUMBER;
    l_buyer_id             NUMBER;
    l_receiving_routing_id NUMBER;
    l_country_code         VARCHAR2(5);
    --l_inventory_item_id      NUMBER;
    --l_out_organization_id    NUMBER;
    --l_msg_count              NUMBER;
    l_master_organization_id NUMBER;
    l_inventory_status_code  VARCHAR2(20);
    l_supply_type            NUMBER;
    l_shelf_life_code        NUMBER;
    l_qa_desc                VARCHAR2(2);
    l_template_id            NUMBER;
    l_plan_make_buy          NUMBER;
    invalid_item EXCEPTION;
  
    t_item_rec     inv_item_grp.item_rec_type;
    t_item_rec_out inv_item_grp.item_rec_type;
    t_rev_rec      inv_item_grp.item_revision_rec_type;
    --l_error_tbl    error_handler.error_tbl_type;
    l_error_tbl inv_item_grp.error_tbl_type;
  
  BEGIN
  
    IF p_master_organization_id IS NULL THEN
      l_master_organization_id := xxinv_utils_pkg.get_master_organization_id;
    ELSE
      l_master_organization_id := p_master_organization_id;
    END IF;
  
    l_coa_id := xxgl_utils_pkg.get_coa_id_from_inv_org(l_master_organization_id,
                                                       l_org_id);
  
    BEGIN
    
      SELECT user_id
        INTO v_user_id
        FROM fnd_user
       WHERE user_name = 'CONVERSION';
    
      fnd_global.apps_initialize(v_user_id,
                                 resp_id      => 20420,
                                 resp_appl_id => 1);
    
    EXCEPTION
      WHEN no_data_found THEN
        errbuf  := 'Invalid User';
        retcode := 2;
    END;
  
    FOR cur_item IN csr_master_items LOOP
    
      BEGIN
      
        l_counter   := nvl(l_counter, 0) + 1;
        l_error_msg := '001';
      
        IF l_master_organization_id IS NULL THEN
          l_err_msg := 'Master organization is missing';
          RAISE invalid_item;
        ELSIF cur_item.organization_id IS NULL THEN
          l_err_msg := 'Organization is missing';
          RAISE invalid_item;
        END IF;
      
        l_unit_of_measure       := NULL;
        l_inventory_status_code := NULL;
        v_cat_group_id          := NULL;
        l_buyer_id              := NULL;
        v_planner_code          := NULL;
        l_cogs_id               := NULL;
        l_sales_account_id      := NULL;
        l_receiving_routing_id  := NULL;
        l_country_code          := NULL;
        l_supply_type           := NULL;
        l_shelf_life_code       := NULL;
        l_qa_desc               := NULL;
        l_template_id           := NULL;
        l_err_msg               := NULL;
      
        t_item_rec := inv_item_grp.g_miss_item_rec;
        t_rev_rec  := inv_item_grp.g_miss_revision_rec;
        l_error_tbl.delete;
      
        l_return_status := 'S';
      
        BEGIN
        
          SELECT muom.unit_of_measure, muom.uom_code
            INTO l_unit_of_measure, l_uom
            FROM mtl_units_of_measure muom
           WHERE muom.uom_code = upper(cur_item.primary_uom);
        
        EXCEPTION
          WHEN OTHERS THEN
            l_err_msg := 'Invalid UOM ' || SQLERRM;
            RAISE invalid_item;
        END;
      
        BEGIN
        
          SELECT inventory_item_status_code
            INTO l_inventory_status_code
            FROM mtl_item_status
           WHERE inventory_item_status_code_tl = cur_item.item_status_code;
        
        EXCEPTION
          WHEN OTHERS THEN
            --l_err_msg := 'Invalid Status ' || SQLERRM;
            -- RAISE invalid_item;
            l_inventory_status_code := NULL;
        END;
      
        l_error_msg := '002';
        -- Catalog Group ID
        IF cur_item.catalog_group IS NOT NULL THEN
        
          BEGIN
          
            SELECT item_catalog_group_id
              INTO v_cat_group_id
              FROM mtl_item_catalog_groups_b
             WHERE segment1 = cur_item.catalog_group;
          
          EXCEPTION
            WHEN no_data_found THEN
              v_cat_group_id := NULL;
          END;
        
        END IF;
        l_error_msg := '003';
      
        IF cur_item.buyer_first_name IS NOT NULL THEN
          BEGIN
            SELECT papf.person_id
              INTO l_buyer_id
              FROM per_all_people_f papf
             WHERE upper(papf.first_name) =
                   upper(cur_item.buyer_first_name)
               AND EXISTS (SELECT pa.agent_id
                      FROM po.po_agents pa
                     WHERE pa.agent_id = papf.person_id);
          EXCEPTION
            WHEN OTHERS THEN
              --l_err_msg := 'Invalid buyer: ' || SQLERRM;
              --RAISE invalid_item;
              l_buyer_id := NULL;
          END;
        END IF;
        IF cur_item.make_buy IS NOT NULL THEN
          BEGIN
            SELECT lookup_code
              INTO l_plan_make_buy
              FROM fnd_lookup_values_vl
             WHERE lookup_type = 'MTL_PLANNING_MAKE_BUY'
               AND meaning = cur_item.make_buy;
          
          EXCEPTION
            WHEN OTHERS THEN
            
              l_err_msg := 'invalid Make or Buy ' || SQLERRM;
              RAISE invalid_item;
            
          END;
        
        END IF;
      
        -- planner_code
        IF cur_item.planner_first_name IS NOT NULL AND
           cur_item.planner_last_name IS NOT NULL THEN
          BEGIN
          
            SELECT p.planner_code
              INTO v_planner_code
              FROM mtl_planners p, per_all_people_f papf
             WHERE p.employee_id = papf.
             person_id
               AND lower(papf.first_name) =
                   lower(cur_item.planner_first_name)
               AND lower(papf.last_name) =
                   lower(cur_item.planner_last_name)
               AND organization_id = cur_item.organization_id;
          
          EXCEPTION
            WHEN OTHERS THEN
              --l_err_msg := 'Invalid planner: ' || SQLERRM;
              --RAISE invalid_item;
              v_planner_code := NULL;
          END;
        
        END IF;
      
        /*** call xxgl_utils_pkg.check_and_create_account with cogs and revenue values  ***/
        IF cur_item.cogs_account IS NOT NULL THEN
          BEGIN
            SELECT code_combination_id
              INTO l_cogs_id
              FROM gl_code_combinations_kfv
             WHERE concatenated_segments = cur_item.cogs_account
               AND enabled_flag = 'Y';
          EXCEPTION
            WHEN no_data_found THEN
            
              xxgl_utils_pkg.get_and_create_account(p_concat_segment      => cur_item.cogs_account,
                                                    p_coa_id              => l_coa_id,
                                                    x_code_combination_id => l_cogs_id,
                                                    x_return_code         => l_return_status,
                                                    x_err_msg             => l_err_msg);
            
              IF l_return_status != fnd_api.g_ret_sts_success THEN
                RAISE invalid_item;
              
              END IF;
          END;
        
        END IF;
      
        IF cur_item.revenue_account IS NOT NULL THEN
          BEGIN
            SELECT code_combination_id
              INTO l_sales_account_id
              FROM gl_code_combinations_kfv
             WHERE concatenated_segments = cur_item.revenue_account
               AND enabled_flag = 'Y';
          EXCEPTION
            WHEN no_data_found THEN
            
              xxgl_utils_pkg.get_and_create_account(p_concat_segment      => cur_item.revenue_account,
                                                    p_coa_id              => l_coa_id,
                                                    x_code_combination_id => l_sales_account_id,
                                                    x_return_code         => l_return_status,
                                                    x_err_msg             => l_err_msg);
            
              IF l_return_status != fnd_api.g_ret_sts_success THEN
              
                RAISE invalid_item;
              
              END IF;
          END;
        
        END IF;
      
        IF cur_item.qa_desc IS NOT NULL THEN
        
          BEGIN
          
            SELECT ffv.flex_value_meaning
              INTO l_qa_desc
              FROM fnd_flex_value_sets fvs, fnd_flex_values_vl ffv
             WHERE fvs.flex_value_set_id = ffv.flex_value_set_id
               AND fvs.flex_value_set_name = 'XXINV_QA_ITEM_CODES'
               AND ffv.description = cur_item.qa_desc;
          EXCEPTION
            WHEN no_data_found THEN
            
              l_err_msg := 'invalid qa desc';
              RAISE invalid_item;
            
          END;
        
        END IF;
      
        IF cur_item.receiving_routing IS NOT NULL THEN
          BEGIN
          
            SELECT rrh.routing_header_id
              INTO l_receiving_routing_id
              FROM rcv_routing_headers rrh
             WHERE routing_name = cur_item.receiving_routing;
          
          EXCEPTION
            WHEN no_data_found THEN
            
              l_err_msg := 'invalid routing ' || SQLERRM;
              RAISE invalid_item;
            
          END;
        
        END IF;
      
        IF cur_item.country IS NOT NULL THEN
          BEGIN
            SELECT t.territory_code
              INTO l_country_code
              FROM fnd_territories_vl t
             WHERE t.territory_code = cur_item.country;
            ---t.territory_short_name = cur_item.country;
          EXCEPTION
            WHEN no_data_found THEN
            
              l_err_msg := 'invalid country' || SQLERRM;
              RAISE invalid_item;
            
          END;
        END IF;
      
        IF cur_item.supply_type IS NOT NULL THEN
          BEGIN
            SELECT lookup_code
              INTO l_supply_type
              FROM fnd_lookup_values_vl
             WHERE lookup_type = 'WIP_SUPPLY'
               AND meaning = cur_item.supply_type;
          
          EXCEPTION
            WHEN OTHERS THEN
            
              l_err_msg := 'invalid supply type ' || SQLERRM;
              RAISE invalid_item;
            
          END;
        
        END IF;
        IF cur_item.shelf_life_code IS NOT NULL THEN
          BEGIN
            SELECT lookup_code
              INTO l_shelf_life_code
              FROM fnd_lookup_values_vl
             WHERE lookup_type LIKE 'MTL_SHELF_LIFE'
               AND meaning = cur_item.shelf_life_code;
          
          EXCEPTION
            WHEN OTHERS THEN
            
              l_err_msg := 'invalid shelf life code ' || SQLERRM;
              RAISE invalid_item;
            
          END;
        
        END IF;
      
        /*           IF cur_item.qa_desc IS NOT NULL THEN
                      BEGIN
                         SELECT flex_value
                           INTO l_qa_code
                           FROM fnd_flex_value_sets fvs, fnd_flex_values_vl ffv
                          WHERE fvs.flex_value_set_id = ffv.flex_value_set_id AND
                                fvs.flex_value_set_name = 'XXINV_QA_ITEM_CODES' AND
                                ffv.description = cur_item.qa_desc;
                      EXCEPTION
                         WHEN OTHERS THEN
                         
                            l_err_msg := 'invalid QA Code ' || SQLERRM;
                            RAISE invalid_item;
                         
                      END;
                   
                   END IF;
        */
        BEGIN
        
          SELECT mit.template_id
            INTO l_template_id
            FROM mtl_item_templates_vl mit
           WHERE mit.template_name = cur_item.item_template_name;
        EXCEPTION
          WHEN OTHERS THEN
          
            l_err_msg := 'invalid Template ' || SQLERRM;
            RAISE invalid_item;
          
        END;
      
        l_error_msg := '004';
        --Insert Into Interface
        t_item_rec.item_number                := cur_item.item_code;
        t_item_rec.segment1                   := cur_item.item_code;
        t_item_rec.description                := cur_item.item_desc;
        t_item_rec.organization_id            := cur_item.organization_id;
        t_item_rec.long_description           := nvl(cur_item.item_detail,
                                                     fnd_api.g_miss_char);
        t_item_rec.primary_uom_code           := l_uom;
        t_item_rec.primary_unit_of_measure    := l_unit_of_measure;
        t_item_rec.inventory_item_status_code := l_inventory_status_code;
        t_item_rec.item_catalog_group_id      := nvl(v_cat_group_id,
                                                     fnd_api.g_miss_num);
        t_item_rec.shelf_life_code            := nvl(l_shelf_life_code,
                                                     fnd_api.g_miss_num);
        t_item_rec.shelf_life_days            := nvl(cur_item.shelf_life_days,
                                                     fnd_api.g_miss_num);
        t_item_rec.buyer_id                   := nvl(l_buyer_id,
                                                     fnd_api.g_miss_num);
        t_item_rec.planner_code               := nvl(v_planner_code,
                                                     fnd_api.g_miss_char);
        t_item_rec.min_minmax_quantity        := nvl(cur_item.min_minmax_quantity,
                                                     fnd_api.g_miss_num);
        t_item_rec.max_minmax_quantity        := nvl(cur_item.max_minmax_quantity,
                                                     fnd_api.g_miss_num);
        t_item_rec.minimum_order_quantity := (CASE
                                               WHEN nvl(cur_item.min_order_qty, 0) = 0 THEN
                                                fnd_api.g_miss_num
                                               ELSE
                                                cur_item.min_order_qty
                                             END);
        t_item_rec.maximum_order_quantity := (CASE
                                               WHEN nvl(cur_item.min_order_qty, 0) != 0 THEN
                                                greatest(nvl(cur_item.max_order_qty,
                                                             0),
                                                         cur_item.min_order_qty)
                                               WHEN nvl(cur_item.max_order_qty, 0) = 0 THEN
                                                fnd_api.g_miss_num
                                               ELSE
                                                cur_item.max_order_qty
                                             END);
        t_item_rec.preprocessing_lead_time    := nvl(cur_item.pre_proc_lead_time,
                                                     fnd_api.g_miss_num);
        t_item_rec.full_lead_time             := nvl(cur_item.processing_lead_time,
                                                     fnd_api.g_miss_num);
        t_item_rec.postprocessing_lead_time   := nvl(cur_item.pre_proc_lead_time,
                                                     fnd_api.g_miss_num);
        t_item_rec.fixed_lead_time            := nvl(cur_item.fixed_lt_prod,
                                                     fnd_api.g_miss_num);
        t_item_rec.list_price_per_unit        := nvl(cur_item.po_list_price,
                                                     fnd_api.g_miss_num);
        t_item_rec.fixed_order_quantity       := nvl(cur_item.fixed_order_qty,
                                                     fnd_api.g_miss_num);
        t_item_rec.fixed_days_supply          := nvl(cur_item.fixed_days_supply,
                                                     fnd_api.g_miss_num);
        t_item_rec.fixed_lot_multiplier       := nvl(cur_item.fixed_lot_multiplier,
                                                     fnd_api.g_miss_num);
        t_item_rec.receiving_routing_id       := nvl(l_receiving_routing_id,
                                                     fnd_api.g_miss_num);
        t_item_rec.receipt_required_flag      := nvl(cur_item.receipt_required_flag,
                                                     fnd_api.g_miss_char);
        t_item_rec.inspection_required_flag   := nvl(cur_item.inspection_required_flag,
                                                     fnd_api.g_miss_char);
        t_item_rec.unit_weight                := nvl(cur_item.unit_weight,
                                                     fnd_api.g_miss_num);
        t_item_rec.weight_uom_code := (CASE
                                        WHEN cur_item.unit_weight IS NOT NULL THEN
                                         nvl(cur_item.weight_uom_code, 'KG')
                                        ELSE
                                         fnd_api.g_miss_char
                                      END);
        t_item_rec.shrinkage_rate             := nvl(cur_item.shrinkage_rate,
                                                     fnd_api.g_miss_num);
        t_item_rec.wip_supply_type            := nvl(l_supply_type,
                                                     fnd_api.g_miss_num);
        t_item_rec.cost_of_sales_account      := nvl(l_cogs_id,
                                                     fnd_api.g_miss_num);
        t_item_rec.sales_account              := nvl(l_sales_account_id,
                                                     fnd_api.g_miss_num);
        t_item_rec.planning_make_buy_code     := l_plan_make_buy;
        t_item_rec.attribute2                 := l_country_code;
        t_item_rec.attribute3                 := cur_item.hs_no;
        t_item_rec.attribute4                 := cur_item.exp_min_month_il;
        t_item_rec.attribute5                 := cur_item.exp_min_month_eu;
        t_item_rec.attribute6                 := cur_item.exp_min_month_usa;
        t_item_rec.attribute7                 := cur_item.min_exp_month_il_cust;
        t_item_rec.attribute8                 := l_qa_desc;
        --   t_item_rec.attribute9                 := cur_item.s_related_item;
        t_item_rec.attribute11 := cur_item.repairable;
        t_item_rec.attribute12 := cur_item.returnable;
        t_item_rec.attribute13 := (CASE
                                    WHEN cur_item.rohs = 'Y' THEN
                                     'Yes'
                                    WHEN cur_item.rohs = 'N' THEN
                                     'No'
                                    ELSE
                                     cur_item.rohs
                                  END);
        t_item_rec.attribute14 := cur_item.abc_class;
        t_item_rec.attribute16 := cur_item.part_spec_19;
        t_item_rec.attribute17 := cur_item.toxic_qty_allowed;
        t_item_rec.attribute18 := cur_item.formula;
        t_item_rec.attribute19 := cur_item.s_m;
      
        t_rev_rec.transaction_type := ego_item_pub.g_ttype_create;
        t_rev_rec.item_number      := cur_item.item_code;
        t_rev_rec.organization_id  := cur_item.organization_id;
        t_rev_rec.revision_code    := cur_item.revision;
      
        inv_item_grp.create_item(p_commit           => fnd_api.g_false,
                                 p_validation_level => fnd_api.g_valid_level_full,
                                 p_item_rec         => t_item_rec,
                                 x_item_rec         => t_item_rec_out,
                                 x_return_status    => l_return_status,
                                 x_error_tbl        => l_error_tbl,
                                 p_template_id      => l_template_id,
                                 p_template_name    => cur_item.item_template_name,
                                 p_revision_rec     => t_rev_rec);
      
        /*       ego_item_pub.process_item(p_api_version                => 1.0,
                                              p_init_msg_list              => fnd_api.g_false,
                                              p_commit                     => fnd_api.g_false,
                                              p_transaction_type           => ego_item_pub.g_ttype_create,
                                              p_item_number                => cur_item.item_code,
                                              p_segment1                   => cur_item.item_code,
                                              p_revision_code              => nvl(cur_item.revision,
                                                                                  fnd_api.g_miss_char),
                                              p_description                => cur_item.item_desc,
                                              p_template_name              => NULL, --cur_item.item_template_name,
                                              p_template_id                => l_template_id,
                                              p_language_code              => 'US',
                                              p_organization_id            => cur_item.organization_id,
                                              p_master_organization_id     => l_master_organization_id,
                                              p_long_description           => nvl(cur_item.item_detail,
                                                                                  fnd_api.g_miss_char),
                                              p_primary_uom_code           => cur_item.primary_uom,
                                              p_primary_unit_of_measure    => l_unit_of_measure,
                                              p_inventory_item_status_code => l_inventory_status_code,
                                              p_item_catalog_group_id      => nvl(v_cat_group_id,
                                                                                  fnd_api.g_miss_num),
                                              p_shelf_life_code            => nvl(l_shelf_life_code,
                                                                                  fnd_api.g_miss_num),
                                              p_shelf_life_days            => nvl(cur_item.shelf_life_days,
                                                                                  fnd_api.g_miss_num),
                                              p_buyer_id                   => nvl(l_buyer_id,
                                                                                  fnd_api.g_miss_num),
                                              p_planner_code               => nvl(v_planner_code,
                                                                                  fnd_api.g_miss_char),
                                              p_min_minmax_quantity        => nvl(cur_item.min_minmax_quantity,
                                                                                  fnd_api.g_miss_num),
                                              p_max_minmax_quantity        => nvl(cur_item.max_minmax_quantity,
                                                                                  fnd_api.g_miss_num),
                                              p_minimum_order_quantity     => (CASE WHEN nvl(cur_item.min_order_qty, 0) = 0 THEN fnd_api.g_miss_num ELSE cur_item.min_order_qty END),
                                              p_maximum_order_quantity     => (CASE WHEN nvl(cur_item.min_order_qty, 0) != 0 THEN greatest(nvl(cur_item.max_order_qty, 0), cur_item.min_order_qty) WHEN nvl(cur_item.max_order_qty, 0) = 0 THEN fnd_api.g_miss_num ELSE cur_item.max_order_qty END),
                                              p_preprocessing_lead_time    => nvl(cur_item.pre_proc_lead_time,
                                                                                  fnd_api.g_miss_num),
                                              p_full_lead_time             => nvl(cur_item.processing_lead_time,
                                                                                  fnd_api.g_miss_num),
                                              p_postprocessing_lead_time   => nvl(cur_item.pre_proc_lead_time,
                                                                                  fnd_api.g_miss_num),
                                              p_fixed_lead_time            => nvl(cur_item.fixed_lt_prod,
                                                                                  fnd_api.g_miss_num),
                                              p_list_price_per_unit        => nvl(cur_item.po_list_price,
                                                                                  fnd_api.g_miss_num),
                                              p_fixed_order_quantity       => nvl(cur_item.fixed_order_qty,
                                                                                  fnd_api.g_miss_num),
                                              p_fixed_days_supply          => nvl(cur_item.fixed_days_supply,
                                                                                  fnd_api.g_miss_num),
                                              p_fixed_lot_multiplier       => nvl(cur_item.fixed_lot_multiplier,
                                                                                  fnd_api.g_miss_num),
                                              p_receiving_routing_id       => nvl(l_receiving_routing_id,
                                                                                  fnd_api.g_miss_num),
                                              p_receipt_required_flag      => nvl(cur_item.receipt_required_flag,
                                                                                  fnd_api.g_miss_char),
                                              p_inspection_required_flag   => nvl(cur_item.inspection_required_flag,
                                                                                  fnd_api.g_miss_char),
                                              p_unit_weight                => nvl(cur_item.unit_weight,
                                                                                  fnd_api.g_miss_num),
                                              p_weight_uom_code            => nvl(cur_item.weight_uom_code,
                                                                                  fnd_api.g_miss_char),
                                              p_shrinkage_rate             => nvl(cur_item.shrinkage_rate,
                                                                                  fnd_api.g_miss_num),
                                              p_wip_supply_type            => nvl(l_supply_type,
                                                                                  fnd_api.g_miss_num),
                                              p_cost_of_sales_account      => nvl(l_cogs_id,
                                                                                  fnd_api.g_miss_num),
                                              p_sales_account              => nvl(l_sales_account_id,
                                                                                  fnd_api.g_miss_num),
                                              p_attribute2                 => l_country_code,
                                              p_attribute3                 => cur_item.hs_no,
                                              p_attribute4                 => cur_item.exp_min_month_il,
                                              p_attribute5                 => cur_item.exp_min_month_eu,
                                              p_attribute6                 => cur_item.exp_min_month_usa,
                                              p_attribute7                 => cur_item.min_exp_month_il_cust,
                                              p_attribute8                 => l_qa_code,
                                              p_attribute9                 => cur_item.s_related_item,
                                              p_attribute11                => cur_item.repairable,
                                              p_attribute12                => cur_item.returnable,
                                              p_attribute13                => (CASE WHEN cur_item.rohs = 'Y' THEN 'Yes' WHEN cur_item.rohs = 'N' THEN 'No' ELSE cur_item.rohs END),
                                              p_attribute14                => cur_item.abc_class,
                                              p_attribute16                => cur_item.part_spec_19,
                                              p_attribute17                => cur_item.toxic_qty_allowed,
                                              x_inventory_item_id          => l_inventory_item_id,
                                              x_organization_id            => l_out_organization_id,
                                              x_return_status              => l_return_status,
                                              x_msg_count                  => l_msg_count,
                                              x_msg_data                   => l_err_msg);
        */
        IF l_return_status != 'S' THEN
          -- ROLLBACK TO begin_mass_update;
        
          -- error_handler.get_message_list(x_message_list => l_error_tbl);
          FOR i IN 1 .. l_error_tbl.count LOOP
            l_err_msg := l_err_msg || l_error_tbl(i).message_text ||
                         chr(10);
          
          END LOOP;
        
          RAISE invalid_item;
        
        END IF;
      
        UPDATE xxobjt_conv_items
           SET trans_to_int_code = 'S', trans_to_int_error = NULL
         WHERE item_code = cur_item.item_code;
      
        -- l_message_text := l_message_text || '/n';
      
        /*               INSERT INTO mtl_system_items_interface
                          (segment1,
                           description,
                           revision,
                           organization_id,
                           process_flag,
                           transaction_type,
                           set_process_id,
                           template_name,
                           bom_enabled_flag,
                           creation_date,
                           created_by,
                           last_update_date,
                           last_updated_by,
                           primary_uom_code,
                           primary_unit_of_measure,
                           inventory_item_status_code,
                           min_minmax_quantity,
                           max_minmax_quantity,
                           lifecycle_id,
                           current_phase_id,
                           buyer_id, ------ add
                           item_catalog_group_id,
                           planner_code,
                           postprocessing_lead_time,
                           preprocessing_lead_time,
                           list_price_per_unit,
                           fixed_lot_multiplier,
                           full_lead_time,
                           fixed_lead_time,
                           shelf_life_days,
                           maximum_order_quantity,
                           minimum_order_quantity,
                           revision_qty_control_code,
                           long_description)
                       VALUES
                          (cur_item.item_code,
                           cur_item.item_desc,
                           cur_item.revision,
                           l_master_organization_id,
                           1,
                           'CREATE',
                           0,
                           cur_item.item_template_name,
                           'Y',
                           SYSDATE,
                           v_user_id,
                           SYSDATE,
                           v_user_id, --- fnd_global.USER_ID ,--v_user_id,
                           cur_item.primary_uom,
                           l_unit_of_measure,
                           cur_item.item_status_code,
                           cur_item.min_minmax_quantity,
                           cur_item.max_minmax_quantity,
                           cur_item.life_cycle_id,
                           cur_item.current_phase_id,
                           cur_item.buyer_id, ---add
                           v_cat_group_id,
                           v_planner_code,
                           cur_item.post_proc_lead_time,
                           cur_item.pre_proc_lead_time,
                           cur_item.po_list_price,
                           cur_item.fixed_lot_multiplier,
                           cur_item.processing_lead_time,
                           cur_item.fixed_lt_prod,
                           cur_item.shelf_life_days,
                           (CASE WHEN nvl(cur_item.min_order_qty, 0) != 0 THEN
                            greatest(nvl(cur_item.max_order_qty, 0),
                                     cur_item.min_order_qty) WHEN
                            nvl(cur_item.max_order_qty, 0) = 0 THEN NULL ELSE
                            cur_item.max_order_qty END), --minimum_purch_order_qty ,
                           (CASE WHEN nvl(cur_item.min_order_qty, 0) = 0 THEN NULL ELSE
                            cur_item.min_order_qty END), --maximum_purch_order_qty,
                           (CASE WHEN cur_item.revision IS NULL THEN 1 ELSE 2 END), -- revision controll
                           cur_item.item_detail --long_description
                           );
        */
      
        l_error_msg := '005';
      
      EXCEPTION
      
        WHEN invalid_item THEN
        
          l_error_msg := l_error_msg || ': ' || l_err_msg;
          UPDATE xxobjt_conv_items
             SET trans_to_int_code = 'E', trans_to_int_error = l_error_msg
           WHERE item_code = cur_item.item_code;
        
        WHEN OTHERS THEN
        
          l_error_msg := l_error_msg || ': ' || SQLERRM;
          UPDATE xxobjt_conv_items
             SET trans_to_int_code = 'E', trans_to_int_error = l_error_msg
           WHERE item_code = cur_item.item_code;
        
      END;
    
      IF MOD(l_counter, 1000) = 0 THEN
        COMMIT;
      END IF;
    
    END LOOP;
  
    COMMIT;
  
    -- Run Import Items Concurrent
  
    /*  errbuf := null ;
      retcode := null ;
    */
  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'exit Insert_Interface_Master' || SQLERRM;
      retcode := 2;
  END insert_interface_master;
  ------------------------------------------------------------

  PROCEDURE org_items_conv(errbuf OUT VARCHAR2, retcode OUT NUMBER) IS
  
    CURSOR csr_master_items(p_organization_id         NUMBER,
                            p_inv_def_category_set_id NUMBER) IS
      SELECT msi.inventory_item_id, msi.segment1 item_code, mc.segment1
        FROM mtl_system_items_b  msi,
             xxobjt_conv_items   xci,
             mtl_item_categories mic,
             mtl_categories_b    mc
       WHERE msi.segment1 = xci.item_code
         AND msi.inventory_item_id = mic.inventory_item_id
         AND msi.organization_id = mic.organization_id
         AND mic.category_set_id = p_inv_def_category_set_id
         AND mic.category_id = mc.category_id
         AND msi.organization_id = p_organization_id
         AND msi.segment1 IN
             (SELECT segment1
                FROM (SELECT msi.segment1,
                             msi.organization_id,
                             MAX(mir_mas.revision) mas_rev,
                             MAX(mir_org.revision) org_rev
                        FROM mtl_system_items_b   msi,
                             mtl_item_revisions_b mir_mas,
                             mtl_item_revisions_b mir_org
                       WHERE msi.inventory_item_id =
                             mir_mas.inventory_item_id
                         AND mir_mas.organization_id = 91 --Master
                         AND msi.inventory_item_id =
                             mir_org.inventory_item_id
                         AND msi.organization_id = mir_org.organization_id
                       GROUP BY msi.segment1, msi.organization_id)
               WHERE mas_rev != org_rev);
  
    CURSOR csr_organization_items(p_inventory_item_id      NUMBER,
                                  p_master_organization_id NUMBER) IS
      SELECT organization_id
        FROM mtl_system_items_b
       WHERE inventory_item_id = p_inventory_item_id
         AND organization_id != p_master_organization_id;
  
    cur_item     csr_master_items%ROWTYPE;
    cur_org_item csr_organization_items%ROWTYPE;
  
    l_return_status           VARCHAR2(1);
    l_err_msg                 VARCHAR2(2000);
    l_counter                 NUMBER := 0;
    l_msg_count               NUMBER;
    l_default_category_set_id NUMBER;
    l_organization_id         NUMBER;
    v_user_id                 NUMBER;
    l_revision                VARCHAR2(3);
    l_effective_date          DATE;
  
  BEGIN
    errbuf  := NULL;
    retcode := 0;
    BEGIN
    
      SELECT user_id
        INTO v_user_id
        FROM fnd_user
       WHERE user_name = 'CONVERSION';
    
      fnd_global.apps_initialize(v_user_id,
                                 resp_id      => 50623,
                                 resp_appl_id => 660);
    
    EXCEPTION
      WHEN no_data_found THEN
        l_return_status := 'E';
    END;
  
    l_organization_id         := xxinv_utils_pkg.get_master_organization_id;
    l_default_category_set_id := xxinv_utils_pkg.get_default_category_set_id('Inventory');
  
    FOR cur_item IN csr_master_items(l_organization_id,
                                     l_default_category_set_id) LOOP
    
      l_return_status := 'S';
      l_err_msg       := NULL;
      l_counter       := l_counter + 1;
      --l_revision      := NULL;
    
      /*xxinv_utils_pkg.org_assignment(p_inventory_item_id => cur_item.inventory_item_id,
                                     p_item_code         => cur_item.item_code,
                                     p_group             => cur_item.segment1,
                                     x_return_status     => l_return_status,
                                     x_err_message       => l_err_msg);
      
      COMMIT;*/
    
      l_revision := xxinv_utils_pkg.get_future_revision(p_inventory_item_id => cur_item.inventory_item_id,
                                                        p_organization_id   => l_organization_id,
                                                        x_effectivity_date  => l_effective_date);
    
      IF l_revision IS NOT NULL THEN
      
        FOR cur_org_item IN csr_organization_items(cur_item.inventory_item_id,
                                                   l_organization_id) LOOP
        
          ego_item_pub.process_item_revision(p_api_version       => 1.0,
                                             p_init_msg_list     => fnd_api.g_true,
                                             p_commit            => fnd_api.g_false,
                                             p_transaction_type  => 'CREATE',
                                             p_inventory_item_id => cur_item.inventory_item_id,
                                             p_organization_id   => cur_org_item.organization_id,
                                             p_revision          => l_revision,
                                             p_effectivity_date  => greatest(SYSDATE,
                                                                             l_effective_date),
                                             x_return_status     => l_return_status,
                                             x_msg_count         => l_msg_count,
                                             x_msg_data          => l_err_msg);
        
        END LOOP;
      
      END IF;
    
      UPDATE xxobjt_conv_items xc
         SET trans_to_int_code     = l_return_status,
             xc.trans_to_int_error = l_err_msg
       WHERE item_code = cur_item.item_code;
    
      --IF MOD(l_counter, 500) = 0 THEN
      COMMIT;
      --END IF;
    END LOOP;
    COMMIT;
  END org_items_conv;

  PROCEDURE insert_interface_org(errbuf                   OUT VARCHAR2,
                                 retcode                  OUT VARCHAR2,
                                 p_master_organization_id IN NUMBER) IS
  
    CURSOR csr_org_items IS
      SELECT *
        FROM xxobjt_conv_org_item_attr
       WHERE trans_to_int_code = 'N'
       ORDER BY item_code;
  
    cur_item    csr_org_items%ROWTYPE;
    t_orig_item mtl_system_items_b%ROWTYPE;
    v_user_id   fnd_user.user_id%TYPE;
    --v_error                  VARCHAR2(100);
    l_counter         NUMBER := 0;
    l_coa_id          NUMBER;
    l_org_id          NUMBER;
    l_error_msg       VARCHAR2(500);
    l_err_msg         VARCHAR2(500);
    l_return_status   VARCHAR2(1);
    v_cat_group_id    NUMBER;
    v_planner_code    VARCHAR2(10);
    l_unit_of_measure mtl_units_of_measure_tl.unit_of_measure%TYPE;
    --l_uom                    VARCHAR2(3);
    l_sales_account_id NUMBER;
    l_cogs_id          NUMBER;
    l_buyer_id         NUMBER;
    --l_receiving_routing_id   NUMBER;
    l_country_code VARCHAR2(5);
    --l_inventory_item_id      NUMBER;
    --l_out_organization_id    NUMBER;
    --l_msg_count              NUMBER;
    l_master_organization_id NUMBER;
    l_inventory_status_code  VARCHAR2(20);
    l_supply_type            NUMBER;
    --l_shelf_life_code        NUMBER;
    --l_qa_code                VARCHAR2(5);
    --l_template_id            NUMBER;
    invalid_item EXCEPTION;
    l_organization_id NUMBER;
    t_item_rec        inv_item_grp.item_rec_type;
    t_item_rec_out    inv_item_grp.item_rec_type;
    t_rev_rec         inv_item_grp.item_revision_rec_type;
    --l_error_tbl    error_handler.error_tbl_type;
    l_error_tbl inv_item_grp.error_tbl_type;
    --l_uom_code          VARCHAR2(3);
    l_inv_planning_code VARCHAR2(30);
    l_supply_locator_id NUMBER;
    l_make_or_buy       NUMBER;
  BEGIN
  
    IF p_master_organization_id IS NULL THEN
      l_master_organization_id := xxinv_utils_pkg.get_master_organization_id;
    ELSE
      l_master_organization_id := p_master_organization_id;
    END IF;
  
    l_coa_id := xxgl_utils_pkg.get_coa_id_from_inv_org(l_master_organization_id,
                                                       l_org_id);
  
    BEGIN
    
      SELECT user_id
        INTO v_user_id
        FROM fnd_user
       WHERE user_name = 'CONVERSION';
    
      fnd_global.apps_initialize(v_user_id,
                                 resp_id      => 20420,
                                 resp_appl_id => 1);
    
    EXCEPTION
      WHEN no_data_found THEN
        errbuf  := 'Invalid User';
        retcode := 2;
    END;
  
    FOR cur_item IN csr_org_items LOOP
    
      BEGIN
      
        l_counter               := nvl(l_counter, 0) + 1;
        l_error_msg             := '001';
        l_inv_planning_code     := NULL;
        l_unit_of_measure       := NULL;
        l_inventory_status_code := NULL;
        v_cat_group_id          := NULL;
        l_buyer_id              := NULL;
        v_planner_code          := NULL;
        l_cogs_id               := NULL;
        l_sales_account_id      := NULL;
        l_country_code          := NULL;
        l_supply_type           := NULL;
        l_err_msg               := NULL;
        l_supply_locator_id     := NULL;
        l_make_or_buy           := NULL;
        t_item_rec              := inv_item_grp.g_miss_item_rec;
        t_rev_rec               := inv_item_grp.g_miss_revision_rec;
        l_error_tbl.delete;
      
        BEGIN
        
          SELECT organization_id
            INTO l_organization_id
            FROM mtl_parameters
           WHERE organization_code = cur_item.org;
        
        EXCEPTION
          WHEN no_data_found THEN
            l_err_msg := 'Invalid inv organization';
            RAISE invalid_item;
        END;
      
        BEGIN
        
          SELECT *
            INTO t_orig_item
            FROM mtl_system_items_b
           WHERE segment1 = cur_item.item_code
             AND organization_id = l_organization_id;
        
        EXCEPTION
          WHEN no_data_found THEN
            l_err_msg := 'Invalid item.organization';
            RAISE invalid_item;
        END;
      
        IF l_master_organization_id = l_organization_id THEN
          IF cur_item.buyer_first_name IS NOT NULL THEN
            BEGIN
              SELECT papf.person_id
                INTO l_buyer_id
                FROM per_all_people_f papf
               WHERE upper(papf.first_name) =
                     upper(cur_item.buyer_first_name)
                 AND upper(papf.last_name) =
                     upper(cur_item.buyer_last_name)
                 AND EXISTS
               (SELECT pa.agent_id
                        FROM po.po_agents pa
                       WHERE pa.agent_id = papf.person_id);
            EXCEPTION
              WHEN OTHERS THEN
                l_err_msg := 'Invalid buyer: ' || SQLERRM;
                RAISE invalid_item;
                l_buyer_id := NULL;
            END;
          END IF;
        END IF;
      
        -- planner_code
        IF cur_item.planner_first_name IS NOT NULL AND
           cur_item.planner_last_name IS NOT NULL THEN
          BEGIN
          
            SELECT p.planner_code
              INTO v_planner_code
              FROM mtl_planners p, per_all_people_f papf
             WHERE p.employee_id = papf.
             person_id
               AND lower(papf.first_name) =
                   lower(cur_item.planner_first_name)
               AND lower(papf.last_name) =
                   lower(cur_item.planner_last_name)
               AND organization_id = l_organization_id;
          
          EXCEPTION
            WHEN OTHERS THEN
              l_err_msg := 'Invalid planner: ' || SQLERRM;
              RAISE invalid_item;
          END;
        
        END IF;
      
        /*** call xxgl_utils_pkg.check_and_create_account with cogs and revenue values  ***/
        IF cur_item.cogs_account IS NOT NULL THEN
          BEGIN
            SELECT code_combination_id
              INTO l_cogs_id
              FROM gl_code_combinations_kfv
             WHERE concatenated_segments = cur_item.cogs_account
               AND enabled_flag = 'Y';
          EXCEPTION
            WHEN no_data_found THEN
            
              xxgl_utils_pkg.get_and_create_account(p_concat_segment      => cur_item.cogs_account,
                                                    p_coa_id              => l_coa_id,
                                                    x_code_combination_id => l_cogs_id,
                                                    x_return_code         => l_return_status,
                                                    x_err_msg             => l_err_msg);
            
              IF l_return_status != fnd_api.g_ret_sts_success THEN
                RAISE invalid_item;
              
              END IF;
          END;
        
        END IF;
      
        IF cur_item.revenue_account IS NOT NULL THEN
          BEGIN
            SELECT code_combination_id
              INTO l_sales_account_id
              FROM gl_code_combinations_kfv
             WHERE concatenated_segments = cur_item.revenue_account
               AND enabled_flag = 'Y';
          EXCEPTION
            WHEN no_data_found THEN
            
              xxgl_utils_pkg.get_and_create_account(p_concat_segment      => cur_item.revenue_account,
                                                    p_coa_id              => l_coa_id,
                                                    x_code_combination_id => l_sales_account_id,
                                                    x_return_code         => l_return_status,
                                                    x_err_msg             => l_err_msg);
            
              IF l_return_status != fnd_api.g_ret_sts_success THEN
              
                RAISE invalid_item;
              
              END IF;
          END;
        
        END IF;
      
        IF cur_item.wip_supply_type IS NOT NULL THEN
          BEGIN
            SELECT lookup_code
              INTO l_supply_type
              FROM fnd_lookup_values_vl
             WHERE lookup_type = 'WIP_SUPPLY'
               AND meaning = cur_item.wip_supply_type;
          
          EXCEPTION
            WHEN OTHERS THEN
            
              l_err_msg := 'invalid supply type ' || SQLERRM;
              RAISE invalid_item;
            
          END;
        END IF;
      
        IF cur_item.make_or_buy IS NOT NULL THEN
          BEGIN
            SELECT lookup_code
              INTO l_make_or_buy
              FROM fnd_lookup_values_vl
             WHERE lookup_type = 'MTL_PLANNING_MAKE_BUY'
               AND meaning = cur_item.make_or_buy;
          
          EXCEPTION
            WHEN OTHERS THEN
            
              l_err_msg := 'invalid Make or Buy ' || SQLERRM;
              RAISE invalid_item;
            
          END;
        
        END IF;
      
        IF cur_item.inventory_planning_method IS NOT NULL THEN
          BEGIN
            SELECT lookup_code
              INTO l_inv_planning_code
              FROM fnd_lookup_values_vl
             WHERE lookup_type = 'EGO_INVENTORY_PLANNING_CODE'
               AND meaning = cur_item.inventory_planning_method;
          
          EXCEPTION
            WHEN OTHERS THEN
            
              l_err_msg := 'invalid planning_method ' || SQLERRM;
              RAISE invalid_item;
            
          END;
        
        END IF;
      
        IF cur_item.wip_supply_locator IS NOT NULL THEN
          BEGIN
            SELECT mil.inventory_location_id
              INTO l_supply_locator_id
              FROM mtl_item_locations_kfv mil
             WHERE mil.concatenated_segments = cur_item.wip_supply_locator
               AND mil.organization_id = l_organization_id;
          
          EXCEPTION
            WHEN OTHERS THEN
            
              l_err_msg := 'invalid locator ' || SQLERRM;
              RAISE invalid_item;
            
          END;
        
        END IF;
      
        l_error_msg := '004';
        --Insert Into Interface
        t_item_rec.item_number                := t_orig_item.segment1;
        t_item_rec.segment1                   := t_orig_item.segment1;
        t_item_rec.inventory_item_id          := t_orig_item.inventory_item_id;
        t_item_rec.organization_id            := t_orig_item.organization_id;
        t_item_rec.enabled_flag               := t_orig_item.enabled_flag;
        t_item_rec.description                := t_orig_item.description;
        t_item_rec.primary_uom_code           := t_orig_item.primary_uom_code;
        t_item_rec.primary_unit_of_measure    := t_orig_item.primary_unit_of_measure;
        t_item_rec.item_type                  := t_orig_item.item_type;
        t_item_rec.inventory_item_status_code := t_orig_item.inventory_item_status_code;
      
        /*  t_item_rec.shelf_life_code          := nvl(l_shelf_life_code,
        fnd_api.g_miss_num);*/
        t_item_rec.buyer_id                 := nvl(l_buyer_id,
                                                   fnd_api.g_miss_num);
        t_item_rec.planner_code             := nvl(v_planner_code,
                                                   fnd_api.g_miss_char);
        t_item_rec.min_minmax_quantity      := nvl(cur_item.minmax_minimum_qty,
                                                   fnd_api.g_miss_num);
        t_item_rec.max_minmax_quantity      := nvl(cur_item.minmax_maximum_qty,
                                                   fnd_api.g_miss_num);
        t_item_rec.minimum_order_quantity := (CASE
                                               WHEN nvl(cur_item.min_order_qty, 0) = 0 THEN
                                                fnd_api.g_miss_num
                                               ELSE
                                                cur_item.min_order_qty
                                             END);
        t_item_rec.maximum_order_quantity := (CASE
                                               WHEN nvl(cur_item.max_order_qty, -1) = -1 THEN
                                                fnd_api.g_miss_num
                                               WHEN nvl(cur_item.min_order_qty, 0) != 0 THEN
                                                greatest(nvl(cur_item.max_order_qty,
                                                             0),
                                                         cur_item.min_order_qty)
                                               ELSE
                                                cur_item.max_order_qty
                                             END);
        t_item_rec.preprocessing_lead_time  := nvl(cur_item.pre_proc_leadtime,
                                                   fnd_api.g_miss_num);
        t_item_rec.postprocessing_lead_time := nvl(cur_item.postproc_leadtime,
                                                   fnd_api.g_miss_num);
        t_item_rec.fixed_lead_time          := nvl(cur_item.fixed_lt,
                                                   fnd_api.g_miss_num);
        t_item_rec.variable_lead_time       := nvl(cur_item.variable_lt,
                                                   fnd_api.g_miss_num);
        t_item_rec.fixed_order_quantity     := nvl(cur_item.fixed_order_qty,
                                                   fnd_api.g_miss_num);
        t_item_rec.fixed_lot_multiplier     := nvl(cur_item.fixed_lot_multiplier,
                                                   fnd_api.g_miss_num);
        t_item_rec.cost_of_sales_account    := nvl(l_cogs_id,
                                                   fnd_api.g_miss_num);
        t_item_rec.sales_account            := nvl(l_sales_account_id,
                                                   fnd_api.g_miss_num);
        t_item_rec.inventory_planning_code  := nvl(l_inv_planning_code,
                                                   fnd_api.g_miss_num);
        t_item_rec.planning_make_buy_code   := nvl(l_make_or_buy,
                                                   fnd_api.g_miss_num);
        t_item_rec.full_lead_time           := nvl(cur_item.processing_leadtime,
                                                   fnd_api.g_miss_num);
        t_item_rec.wip_supply_type          := nvl(l_supply_type,
                                                   fnd_api.g_miss_num);
        t_item_rec.wip_supply_subinventory  := nvl(cur_item.wip_supply_subinv,
                                                   fnd_api.g_miss_char);
        t_item_rec.wip_supply_locator_id    := nvl(l_supply_locator_id,
                                                   fnd_api.g_miss_num);
      
        inv_item_grp.update_item(p_commit           => fnd_api.g_false,
                                 p_validation_level => fnd_api.g_valid_level_full,
                                 p_item_rec         => t_item_rec,
                                 x_item_rec         => t_item_rec_out,
                                 x_return_status    => l_return_status,
                                 x_error_tbl        => l_error_tbl);
      
        IF l_return_status != 'S' THEN
          -- ROLLBACK TO begin_mass_update;
        
          -- error_handler.get_message_list(x_message_list => l_error_tbl);
          FOR i IN 1 .. l_error_tbl.count LOOP
            l_err_msg := l_err_msg || l_error_tbl(i).message_text ||
                         chr(10);
          
          END LOOP;
        
          RAISE invalid_item;
        
        END IF;
      
        UPDATE xxobjt_conv_org_item_attr
           SET trans_to_int_code = 'S', trans_to_int_error = NULL
         WHERE item_code = cur_item.item_code
           AND org = cur_item.org
           AND trans_to_int_code = 'N';
      
        l_error_msg := '005';
      
      EXCEPTION
      
        WHEN invalid_item THEN
        
          l_error_msg := l_error_msg || ': ' || l_err_msg;
          UPDATE xxobjt_conv_org_item_attr
             SET trans_to_int_code = 'E', trans_to_int_error = l_error_msg
           WHERE item_code = cur_item.item_code
             AND org = cur_item.org
             AND trans_to_int_code = 'N';
        WHEN OTHERS THEN
        
          l_error_msg := l_error_msg || ': ' || SQLERRM;
          UPDATE xxobjt_conv_org_item_attr
             SET trans_to_int_code = 'E', trans_to_int_error = l_error_msg
           WHERE item_code = cur_item.item_code
             AND org = cur_item.org
             AND trans_to_int_code = 'N';
        
      END;
    
      IF MOD(l_counter, 1000) = 0 THEN
        COMMIT;
      END IF;
    
    END LOOP;
  
    COMMIT;
  
    -- Run Import Items Concurrent
  
  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'exit Insert_Interface_Master' || SQLERRM;
      retcode := 2;
  END insert_interface_org;

  PROCEDURE assign_wpi_org IS
  
    CURSOR csr_item_for_assignment IS
      SELECT DISTINCT msi.inventory_item_id,
                      msi.primary_uom_code,
                      msi.secondary_uom_code,
                      msi.tracking_quantity_ind,
                      msi.secondary_default_ind,
                      msi.ont_pricing_qty_source,
                      msi.dual_uom_deviation_high,
                      msi.dual_uom_deviation_low,
                      t.organization organization_code
        FROM xxobjt_conv_item_cost t, mtl_system_items_b msi
       WHERE t.item_code = msi.segment1
         AND msi.organization_id = 91 --Master
         AND NOT EXISTS
       (SELECT 1
                FROM mtl_system_items_b msi1, mtl_parameters mp
               WHERE msi1.organization_id = mp.organization_id
                 AND msi1.segment1 = t.item_code
                 AND mp.organization_code = t.organization);
  
    cur_item                 csr_item_for_assignment%ROWTYPE;
    l_master_organization_id NUMBER;
    l_organization_id        NUMBER;
  
    --l_stage VARCHAR2(10);
    invalid_assignment EXCEPTION;
    t_item_org_assign_tbl system.ego_item_org_assign_table := NEW
                                                              system.ego_item_org_assign_table();
    l_error_tbl           error_handler.error_tbl_type;
    l_org_counter         NUMBER := 1;
    l_return_status       VARCHAR2(1);
    l_err_msg             VARCHAR2(2000);
    --l_counter                 NUMBER := 0;
    l_msg_count NUMBER;
    --l_default_category_set_id NUMBER;
    v_user_id  NUMBER;
    l_revision VARCHAR2(3);
    --l_effective_date          DATE;
  
  BEGIN
  
    BEGIN
    
      SELECT user_id
        INTO v_user_id
        FROM fnd_user
       WHERE user_name = 'CONVERSION';
    
      fnd_global.apps_initialize(v_user_id,
                                 resp_id      => 50623,
                                 resp_appl_id => 660);
    
    EXCEPTION
      WHEN no_data_found THEN
        l_return_status := 'E';
    END; -- SAVEPOINT assign_item;
  
    t_item_org_assign_tbl.extend();
  
    FOR cur_item IN csr_item_for_assignment LOOP
    
      l_return_status := 'S';
    
      SELECT master_organization_id, organization_id
        INTO l_master_organization_id, l_organization_id
        FROM mtl_parameters
       WHERE organization_code = cur_item.organization_code;
    
      t_item_org_assign_tbl(1) := system.ego_item_org_assign_rec(1,
                                                                 1,
                                                                 '1',
                                                                 '1',
                                                                 1,
                                                                 '1',
                                                                 '1',
                                                                 NULL,
                                                                 NULL,
                                                                 NULL,
                                                                 NULL,
                                                                 NULL,
                                                                 NULL);
      t_item_org_assign_tbl(1).master_organization_id := l_master_organization_id;
      t_item_org_assign_tbl(1).organization_id := l_organization_id;
      t_item_org_assign_tbl(1).organization_code := 'IPK'; ----'WPI';
      t_item_org_assign_tbl(1).primary_uom_code := cur_item.primary_uom_code;
      t_item_org_assign_tbl(1).inventory_item_id := cur_item.inventory_item_id;
      t_item_org_assign_tbl(1).secondary_uom_code := cur_item.secondary_uom_code;
      t_item_org_assign_tbl(1).tracking_quantity_ind := cur_item.tracking_quantity_ind;
      t_item_org_assign_tbl(1).secondary_default_ind := cur_item.secondary_default_ind;
      t_item_org_assign_tbl(1).ont_pricing_qty_source := cur_item.ont_pricing_qty_source;
      t_item_org_assign_tbl(1).dual_uom_deviation_high := cur_item.dual_uom_deviation_high;
      t_item_org_assign_tbl(1).dual_uom_deviation_low := cur_item.dual_uom_deviation_low;
    
      xxinv_item_org_assign_pkg.process_org_assignments(p_item_org_assign_tab => t_item_org_assign_tbl,
                                                        p_commit              => fnd_api.g_false,
                                                        x_return_status       => l_return_status,
                                                        x_msg_count           => l_org_counter);
      IF l_return_status != 'S' THEN
      
        error_handler.get_message_list(x_message_list => l_error_tbl);
        FOR j IN 1 .. l_error_tbl.count LOOP
          l_err_msg := l_err_msg || l_error_tbl(j).message_text || chr(10);
        END LOOP;
        dbms_output.put_line('Item ' || cur_item.inventory_item_id || ': ' ||
                             l_err_msg);
      END IF;
    
      COMMIT;
    
      l_return_status := 'S';
      --  x_err_message   := NULL;
    
      l_revision := xxinv_utils_pkg.get_current_revision(p_inventory_item_id => cur_item.inventory_item_id,
                                                         p_organization_id   => l_master_organization_id);
    
      ego_item_pub.process_item_revision(p_api_version       => 1.0,
                                         p_init_msg_list     => fnd_api.g_true,
                                         p_commit            => fnd_api.g_false,
                                         p_transaction_type  => 'CREATE',
                                         p_inventory_item_id => cur_item.inventory_item_id,
                                         p_organization_id   => l_organization_id,
                                         p_revision          => l_revision,
                                         p_effectivity_date  => SYSDATE,
                                         x_return_status     => l_return_status,
                                         x_msg_count         => l_msg_count,
                                         x_msg_data          => l_err_msg);
    END LOOP;
  
    COMMIT;
  END assign_wpi_org;

  PROCEDURE assign_last_revision IS
  
    CURSOR csr_item_max_revision IS
      SELECT MAX(mas.revision) max_revision,
             MAX(org.revision) org_revision,
             msi.segment1,
             msi.inventory_item_id,
             org.organization_id
        FROM mtl_system_items_b   msi,
             mtl_item_revisions_b mas,
             mtl_item_revisions_b org
       WHERE msi.organization_id = 91 --Master
         AND msi.inventory_item_id = mas.inventory_item_id
         AND msi.organization_id = mas.organization_id
         AND msi.inventory_item_id = org.inventory_item_id
         AND org.organization_id != 91 --Master
       GROUP BY msi.segment1, msi.inventory_item_id, org.organization_id
      HAVING MAX(mas.revision) != MAX(org.revision);
  
    cur_rev csr_item_max_revision%ROWTYPE;
  
    l_return_status VARCHAR2(1);
    l_err_msg       VARCHAR2(2000);
    --l_counter                 NUMBER := 0;
    l_msg_count NUMBER;
    --l_default_category_set_id NUMBER;
    --l_organization_id         NUMBER;
    v_user_id NUMBER;
    --l_revision                VARCHAR2(3);
  
  BEGIN
  
    BEGIN
      SELECT user_id
        INTO v_user_id
        FROM fnd_user
       WHERE user_name = 'CONVERSION';
    
      fnd_global.apps_initialize(v_user_id,
                                 resp_id      => 50623,
                                 resp_appl_id => 660);
    
    EXCEPTION
      WHEN no_data_found THEN
        l_return_status := 'E';
    END; -- SAVEPOINT assign_item;
  
    FOR cur_rev IN csr_item_max_revision LOOP
    
      ego_item_pub.process_item_revision(p_api_version       => 1.0,
                                         p_init_msg_list     => fnd_api.g_true,
                                         p_commit            => fnd_api.g_false,
                                         p_transaction_type  => 'CREATE',
                                         p_inventory_item_id => cur_rev.inventory_item_id,
                                         p_organization_id   => cur_rev.organization_id,
                                         p_revision          => cur_rev.max_revision,
                                         p_effectivity_date  => SYSDATE,
                                         x_return_status     => l_return_status,
                                         x_msg_count         => l_msg_count,
                                         x_msg_data          => l_err_msg);
    END LOOP;
  
    COMMIT;
  
  END assign_last_revision;

  PROCEDURE update_def_receiving_subinv IS
  
    l_org_id        NUMBER;
    l_item_id       NUMBER;
    l_user_id       NUMBER;
    l_process_code  VARCHAR2(10); --'INSERT'/'SYNC';
    l_return_status VARCHAR2(1);
    l_msg_count     NUMBER;
    l_msg_data      VARCHAR2(500);
  
  BEGIN
    inv_item_sub_default_pkg.insert_upd_item_sub_defaults(p_organization_id   => l_org_id,
                                                          p_inventory_item_id => l_item_id,
                                                          p_subinventory_code => 'INTRANSUB',
                                                          p_default_type      => 2,
                                                          p_creation_date     => SYSDATE,
                                                          p_created_by        => l_user_id,
                                                          p_last_update_date  => SYSDATE,
                                                          p_last_updated_by   => l_user_id,
                                                          p_process_code      => l_process_code,
                                                          p_commit            => fnd_api.g_true,
                                                          x_return_status     => l_return_status,
                                                          x_msg_count         => l_msg_count,
                                                          x_msg_data          => l_msg_data);
  
  END update_def_receiving_subinv;
  ----------------------------------------------------------------------------------
  PROCEDURE item_org_assignment(errbuf          OUT VARCHAR2,
                                retcode         OUT VARCHAR2,
                                p_table_name    IN VARCHAR2, ---hidden parameter----default value ='XXOBJT_CONV_ITEMS' independent value set XXOBJT_LOADER_TABLES
                                p_template_name IN VARCHAR2, ---dependent value set XXOBJT_LOADER_TEMPLATES
                                p_file_name     IN VARCHAR2,
                                p_directory     IN VARCHAR2) IS
    CURSOR csr_master_items IS
      SELECT *
        FROM xxobjt_conv_items ci
       WHERE ci.trans_to_int_code = 'N'
         AND ci.organization_id IS NOT NULL
       ORDER BY ci.item_code;
  
    CURSOR get_all_organizations(p_organization_id NUMBER) IS
      SELECT ----decode(mp.organization_id, 91, 1, mp.organization_id) for_order_by,
       mp.organization_id,
       mp.organization_code,
       ----mp.sales_account,
       cc_sales.segment1 || '.' || cc_sales.segment2 || '.' ||
       cc_sales.segment3 || '.' || cc_sales.segment4 sales_concat_segments_1_2_3_4,
       cc_sales.segment6 || '.' || cc_sales.segment7 || '.' ||
       cc_sales.segment8 || '.' || cc_sales.segment9 sales_concat_segments_6_7_8_9,
       ----mp.encumbrance_account,
       cc_encumbrance.segment1 || '.' || cc_encumbrance.segment2 || '.' ||
       cc_encumbrance.segment3 || '.' || cc_encumbrance.segment4 encumb_concat_segments_1_2_3_4,
       cc_encumbrance.segment6 || '.' || cc_encumbrance.segment7 || '.' ||
       cc_encumbrance.segment8 || '.' || cc_encumbrance.segment9 encumb_concat_segments_6_7_8_9,
       ----mp.expense_account,
       ----cc_expense.segment1||'.'||cc_expense.segment2||'.'||cc_expense.segment3||'.'||cc_expense.segment4    expens_concat_segments_1_2_3_4,
       cc_expense.segment1 expense_segment1,
       cc_expense.segment3 || '.' || cc_expense.segment4 expens_concat_segments_3_4,
       cc_expense.segment6 || '.' || cc_expense.segment7 || '.' ||
       cc_expense.segment8 || '.' || cc_expense.segment9 expens_concat_segments_6_7_8_9,
       ----mp.cost_of_sales_account
       cc_cost_of_sales.segment1 || '.' || cc_cost_of_sales.segment2 || '.' ||
       cc_cost_of_sales.segment3 || '.' || cc_cost_of_sales.segment4 cogs_concat_segments_1_2_3_4,
       cc_cost_of_sales.segment6 || '.' || cc_cost_of_sales.segment7 || '.' ||
       cc_cost_of_sales.segment8 || '.' || cc_cost_of_sales.segment9 cogs_concat_segments_6_7_8_9
        FROM mtl_parameters           mp,
             gl_code_combinations_kfv cc_sales,
             gl_code_combinations_kfv cc_encumbrance,
             gl_code_combinations_kfv cc_expense,
             gl_code_combinations_kfv cc_cost_of_sales
       WHERE mp.organization_id = p_organization_id ---parameter-- ('OMA'--91--master org)
         AND mp.sales_account = cc_sales.code_combination_id
         AND mp.encumbrance_account = cc_encumbrance.code_combination_id
         AND mp.expense_account = cc_expense.code_combination_id
         AND mp.cost_of_sales_account =
             cc_cost_of_sales.code_combination_id
         AND cc_sales.enabled_flag = 'Y'
         AND cc_encumbrance.enabled_flag = 'Y'
         AND cc_expense.enabled_flag = 'Y'
         AND cc_cost_of_sales.enabled_flag = 'Y';
    ---ORDER BY 1;
  
    CURSOR get_results IS
      SELECT ci.organization_id,
             mp.organization_code,
             SUM(decode(ci.trans_to_int_code, 'S', 1, 0)) num_of_success_created_items,
             SUM(decode(ci.trans_to_int_code, 'E', 1, 0)) num_of_errors
        FROM xxobjt_conv_items ci, mtl_parameters mp
       WHERE ci.trans_to_int_code IN ('S', 'E')
         AND ci.organization_id = mp.organization_id
         AND ci.request_id = fnd_global.conc_request_id
       GROUP BY ci.organization_id, mp.organization_code;
  
    v_step VARCHAR2(100);
    stop_processing EXCEPTION;
    v_errbuf         VARCHAR2(3000);
    v_retcode        VARCHAR2(3000);
    v_error_messsage VARCHAR2(3000);
    l_request_id     NUMBER;
    cur_item         csr_master_items%ROWTYPE;
    ---v_user_id    fnd_user.user_id%TYPE;
    ---v_error                  VARCHAR2(100);
    l_numeric_dummy             NUMBER;
    l_counter                   NUMBER := 0;
    l_coa_id                    NUMBER;
    l_org_id                    NUMBER;
    l_return_status             VARCHAR2(1);
    v_cat_group_id              mtl_item_catalog_groups_b.item_catalog_group_id%TYPE;
    v_planner_code              VARCHAR2(10);
    l_unit_of_measure           mtl_units_of_measure_tl.unit_of_measure%TYPE;
    l_uom                       VARCHAR2(3);
    l_dimension_unit_of_measure mtl_units_of_measure_tl.unit_of_measure%TYPE;
    l_dimension_uom             VARCHAR2(3);
    l_unit_length               NUMBER;
    l_unit_width                NUMBER;
    l_unit_height               NUMBER;
  
    ---accounts------
    l_sales_account_id            NUMBER;
    l_encumbrance_account_id      NUMBER;
    l_expense_account_id          NUMBER;
    l_cogs_id                     NUMBER;
    l_sales_concat_segments       VARCHAR2(100);
    l_encumbrance_concat_segments VARCHAR2(100);
    l_expense_concat_segments     VARCHAR2(100);
    l_cogs_concat_segments        VARCHAR2(100);
  
    l_buyer_id             NUMBER;
    l_receiving_routing_id NUMBER;
    l_country_code         VARCHAR2(5);
  
    l_master_organization_id       NUMBER;
    l_inventory_status_code        VARCHAR2(20);
    l_supply_type                  NUMBER;
    l_shelf_life_code              NUMBER;
    l_qa_desc                      VARCHAR2(2);
    l_template_id                  NUMBER;
    l_plan_make_buy                NUMBER;
    l_default_ship_organization_id NUMBER;
  
    invalid_item EXCEPTION;
  
    t_item_rec     inv_item_grp.item_rec_type;
    t_item_rec_out inv_item_grp.item_rec_type;
    t_rev_rec      inv_item_grp.item_revision_rec_type;
    --l_error_tbl    error_handler.error_tbl_type;
    l_error_tbl inv_item_grp.error_tbl_type;
  
    l_records_updated NUMBER;
  
  BEGIN
  
    v_step       := 'Step 0';
    errbuf       := '';
    retcode      := '0';
    l_request_id := fnd_global.conc_request_id;
  
    v_step := 'Step 10';
    ---Load data from CSV-table into XXOBJT_CONV_ITEMS table---------------------
    xxobjt_table_loader_util_pkg.load_file(errbuf                 => v_errbuf,
                                           retcode                => v_retcode,
                                           p_table_name           => 'XXOBJT_CONV_ITEMS',
                                           p_template_name        => p_template_name,
                                           p_file_name            => p_file_name,
                                           p_directory            => p_directory,
                                           p_expected_num_of_rows => NULL);
    IF v_retcode <> '0' THEN
      ---WARNING or ERROR---
      v_error_messsage := v_errbuf;
      RAISE stop_processing;
    END IF;
  
    message('All records from file ' || p_file_name ||
            ' were successfully loaded into table XXOBJT_CONV_ITEMS');
  
    v_step                   := 'Step 20';
    l_master_organization_id := xxinv_utils_pkg.get_master_organization_id;
  
    l_coa_id := xxgl_utils_pkg.get_coa_id_from_inv_org(l_master_organization_id,
                                                       l_org_id);
  
    /*
     v_step := 'Step 30';
    BEGIN    
      SELECT user_id
        INTO v_user_id
        FROM fnd_user
       WHERE user_name = 'CONVERSION';
      ---changed by Vitaly 12-May-2013
      fnd_global.apps_initialize(v_user_id,
                                 resp_id      => 51057, ----INV Catalog User ---it was--20420,--System Administrator
                                 resp_appl_id => 401 ---it was--1
                                 );    
    EXCEPTION
      WHEN no_data_found THEN
        errbuf  := 'Invalid User';
        retcode := 2;
    END;*/
  
    v_step := 'Step 40';
    ---changed by Vitaly 09-May-2013
    UPDATE xxobjt_conv_items ci
       SET ci.trans_to_int_code  = 'E',
           ci.trans_to_int_error = 'Not exists in master organization', ----'Already exists in master organization'
           ci.request_id         = l_request_id
     WHERE ci.trans_to_int_code IS NOT NULL
       AND ci.trans_to_int_code <> 'E'
       AND ci.trans_to_int_code <> 'S'
       AND NOT EXISTS
     (SELECT 1
              FROM mtl_system_items_b msi
             WHERE msi.organization_id = 91 --master
               AND msi.segment1 = upper(ci.item_code));
    l_records_updated := SQL%ROWCOUNT;
    IF l_records_updated > 0 THEN
      dbms_output.put_line('=========== ' || l_records_updated ||
                           ---' items from Your file already exist in Master Organization (91)');
                           ' records -- item from Your file not exist in Master Organization (91)');
    END IF;
    COMMIT;
  
    v_step := 'Step 50';
    ----Check item_code value---- may be characters like . or , or < or > or ; or : or ' or " or + .. inside
    UPDATE xxobjt_conv_items ci
       SET ci.trans_to_int_code  = 'E',
           ci.trans_to_int_error = 'There is forbidden character in item_code',
           ci.request_id         = l_request_id
     WHERE ci.trans_to_int_code IS NOT NULL
       AND ci.trans_to_int_code <> 'E'
       AND ci.trans_to_int_code <> 'S'
       AND (instr(ci.item_code, '.', 1) > 0 OR
           instr(ci.item_code, ',', 1) > 0 OR
           instr(ci.item_code, '<', 1) > 0 OR
           instr(ci.item_code, '>', 1) > 0 OR
           instr(ci.item_code, '=', 1) > 0 OR
           instr(ci.item_code, '_', 1) > 0 OR
           instr(ci.item_code, ';', 1) > 0 OR
           instr(ci.item_code, ':', 1) > 0 OR
           instr(ci.item_code, '+', 1) > 0 OR
           instr(ci.item_code, ')', 1) > 0 OR
           instr(ci.item_code, '(', 1) > 0 OR
           instr(ci.item_code, '*', 1) > 0 OR
           instr(ci.item_code, '&', 1) > 0 OR
           instr(ci.item_code, '^', 1) > 0 OR
           instr(ci.item_code, '%', 1) > 0 OR
           instr(ci.item_code, '$', 1) > 0 OR
           instr(ci.item_code, '#', 1) > 0 OR
           instr(ci.item_code, '@', 1) > 0 OR
           instr(ci.item_code, '!', 1) > 0 OR
           instr(ci.item_code, '?', 1) > 0 OR
           instr(ci.item_code, '/', 1) > 0 OR
           instr(ci.item_code, '\', 1) > 0 OR
           instr(ci.item_code, '''', 1) > 0 OR
           instr(ci.item_code, '"', 1) > 0 OR
           instr(ci.item_code, '|', 1) > 0 OR
           instr(ci.item_code, '{', 1) > 0 OR
           instr(ci.item_code, '}', 1) > 0 OR
           instr(ci.item_code, '[', 1) > 0 OR
           instr(ci.item_code, ']', 1) > 0);
  
    l_records_updated := SQL%ROWCOUNT;
    IF l_records_updated > 0 THEN
      dbms_output.put_line('=========== ' || l_records_updated ||
                           ' item_codes with forbidden character inside');
    END IF;
    COMMIT;
  
    v_step := 'Step 60';
    ----Check item_code value---- may be characters like . or , or < or > or ; or : or ' or " or + .. inside
    UPDATE xxobjt_conv_items ci
       SET ci.trans_to_int_code  = 'E',
           ci.trans_to_int_error = 'Invalid default_so_source_type',
           ci.request_id         = l_request_id
     WHERE ci.trans_to_int_code IS NOT NULL
       AND ci.trans_to_int_code <> 'E'
       AND ci.trans_to_int_code <> 'S'
       AND nvl(upper(ci.default_so_source_type), 'INTERNAL') NOT IN
           ('INTERNAL', 'EXTERNAL');
  
    v_step := 'Step 70';
    ----Check Default Shipping Organization code----
    UPDATE xxobjt_conv_items ci
       SET ci.trans_to_int_code  = 'E',
           ci.trans_to_int_error = 'Invalid default_shipping_organization code',
           ci.request_id         = l_request_id
     WHERE ci.trans_to_int_code IS NOT NULL
       AND ci.trans_to_int_code <> 'E'
       AND ci.trans_to_int_code <> 'S'
       AND ci.default_shipping_org_code IS NOT NULL
       AND NOT EXISTS
     (SELECT 1
              FROM mtl_parameters mp
             WHERE mp.organization_code = ci.default_shipping_org_code);
  
    v_step := 'Step 80';
    ----Check Organization code----
    UPDATE xxobjt_conv_items ci
       SET ci.trans_to_int_code  = 'E',
           ci.trans_to_int_error = 'Invalid organization code',
           ci.request_id         = l_request_id
     WHERE ci.trans_to_int_code IS NOT NULL
       AND ci.trans_to_int_code <> 'E'
       AND ci.trans_to_int_code <> 'S'
       AND NOT EXISTS
     (SELECT 1
              FROM mtl_parameters mp
             WHERE mp.organization_code = ci.organization_code);
  
    v_step := 'Step 90';
    ----Translate Organization_code to organization_id----
    UPDATE xxobjt_conv_items ci
       SET ci.organization_id =
           (SELECT mp.organization_id
              FROM mtl_parameters mp
             WHERE mp.organization_code = ci.organization_code)
     WHERE ci.trans_to_int_code IS NOT NULL
       AND ci.trans_to_int_code <> 'E'
       AND ci.trans_to_int_code <> 'S';
  
    COMMIT; -----COMMIT-----COMMIT-----COMMIT-----COMMIT-----COMMIT-------             
  
    v_step := 'Step 200';
    FOR cur_item IN csr_master_items LOOP
      v_error_messsage := NULL;
      FOR organization_rec IN get_all_organizations(cur_item.organization_id) LOOP
        ----------
        BEGIN
        
          l_counter := nvl(l_counter, 0) + 1;
          IF l_master_organization_id IS NULL THEN
            v_error_messsage := 'Master organization is missing';
            RAISE invalid_item;
          END IF;
        
          l_unit_of_measure              := NULL;
          l_uom                          := NULL;
          l_inventory_status_code        := NULL;
          v_cat_group_id                 := NULL;
          l_buyer_id                     := NULL;
          v_planner_code                 := NULL;
          l_sales_account_id             := NULL;
          l_encumbrance_account_id       := NULL;
          l_expense_account_id           := NULL;
          l_cogs_id                      := NULL;
          l_sales_concat_segments        := NULL;
          l_encumbrance_concat_segments  := NULL;
          l_expense_concat_segments      := NULL;
          l_cogs_concat_segments         := NULL;
          l_receiving_routing_id         := NULL;
          l_country_code                 := NULL;
          l_supply_type                  := NULL;
          l_shelf_life_code              := NULL;
          l_qa_desc                      := NULL;
          l_template_id                  := NULL;
          v_error_messsage               := NULL;
          l_dimension_unit_of_measure    := NULL;
          l_dimension_uom                := NULL;
          l_unit_length                  := NULL;
          l_unit_width                   := NULL;
          l_unit_height                  := NULL;
          l_default_ship_organization_id := NULL;
        
          t_item_rec := inv_item_grp.g_miss_item_rec;
          t_rev_rec  := inv_item_grp.g_miss_revision_rec;
          l_error_tbl.delete;
        
          l_return_status := 'S';
          v_step          := 'Step 210';
          BEGIN
          
            SELECT muom.unit_of_measure, muom.uom_code
              INTO l_unit_of_measure, l_uom
              FROM mtl_units_of_measure muom
             WHERE muom.uom_code = upper(cur_item.primary_uom);
          
          EXCEPTION
            WHEN OTHERS THEN
              v_error_messsage := 'Invalid UOM ' || SQLERRM;
              RAISE invalid_item;
          END;
          v_step := 'Step 220';
          IF cur_item.length IS NOT NULL AND cur_item.width IS NOT NULL AND
             cur_item.height IS NOT NULL AND
             cur_item.dimension_uom IS NOT NULL THEN
            --------                    
            BEGIN
              SELECT muom.unit_of_measure, muom.uom_code
                INTO l_dimension_unit_of_measure, l_dimension_uom
                FROM mtl_units_of_measure muom
               WHERE muom.uom_code = upper(cur_item.dimension_uom);
            EXCEPTION
              WHEN OTHERS THEN
                v_error_messsage := 'Invalid Dimension UOM ' || SQLERRM;
                RAISE invalid_item;
            END;
            --------
            BEGIN
              SELECT to_number(cur_item.length)
                INTO l_unit_length
                FROM dual;
              IF l_unit_length < 0 THEN
                v_error_messsage := 'item Length should be positive >0';
                RAISE invalid_item;
              END IF;
            EXCEPTION
              WHEN OTHERS THEN
                v_error_messsage := 'item Length should be numeric value';
                RAISE invalid_item;
            END;
            --------
            BEGIN
              SELECT to_number(cur_item.width) INTO l_unit_width FROM dual;
              IF l_unit_width < 0 THEN
                v_error_messsage := 'item Width should be positive >0';
                RAISE invalid_item;
              END IF;
            EXCEPTION
              WHEN OTHERS THEN
                v_error_messsage := 'item Width should be numeric value';
                RAISE invalid_item;
            END;
            --------
            BEGIN
              SELECT to_number(cur_item.height)
                INTO l_unit_height
                FROM dual;
              IF l_unit_height < 0 THEN
                v_error_messsage := 'item Height should be positive >0';
                RAISE invalid_item;
              END IF;
            EXCEPTION
              WHEN OTHERS THEN
                v_error_messsage := 'item Heigth should be numeric value';
                RAISE invalid_item;
            END;
            --------
          END IF;
          v_step := 'Step 230';
          BEGIN
          
            SELECT inventory_item_status_code
              INTO l_inventory_status_code
              FROM mtl_item_status
             WHERE inventory_item_status_code_tl =
                   cur_item.item_status_code;
          
          EXCEPTION
            WHEN OTHERS THEN
              l_inventory_status_code := NULL;
          END;
        
          -- Catalog Group ID
          IF cur_item.catalog_group IS NOT NULL THEN
          
            BEGIN
            
              SELECT item_catalog_group_id
                INTO v_cat_group_id
                FROM mtl_item_catalog_groups_b
               WHERE segment1 = cur_item.catalog_group;
            
            EXCEPTION
              WHEN no_data_found THEN
                v_cat_group_id := NULL;
            END;
          
          END IF;
        
          IF cur_item.make_buy IS NOT NULL THEN
            -----------
            BEGIN
              SELECT lookup_code
                INTO l_plan_make_buy
                FROM fnd_lookup_values_vl
               WHERE lookup_type = 'MTL_PLANNING_MAKE_BUY'
                 AND meaning = cur_item.make_buy;
            
            EXCEPTION
              WHEN OTHERS THEN
              
                v_error_messsage := 'invalid Make or Buy ' || SQLERRM;
                RAISE invalid_item;
            END;
            -----------
          END IF;
          v_step := 'Step 240';
          IF cur_item.product_line IS NULL THEN
            v_error_messsage := 'Missing Product Line';
            RAISE invalid_item;
          END IF;
          --------                    
          BEGIN
            SELECT 1
              INTO l_numeric_dummy
              FROM fnd_flex_value_sets fvs, fnd_flex_values_vl ffv
             WHERE fvs.flex_value_set_id = ffv.flex_value_set_id
               AND fvs.flex_value_set_name = 'XXGL_PRODUCT_LINE_SEG'
               AND ffv.flex_value = cur_item.product_line; ---SEGMENT5                  
          EXCEPTION
            WHEN OTHERS THEN
              v_error_messsage := 'Invalid Product Line';
              RAISE invalid_item;
          END;
          --------
          v_step := 'Step 250';
          IF cur_item.default_shipping_org_code IS NOT NULL THEN
            --------
            BEGIN
              SELECT mp.organization_id
                INTO l_default_ship_organization_id
                FROM mtl_parameters mp
               WHERE mp.organization_code =
                     cur_item.default_shipping_org_code;
            EXCEPTION
              WHEN no_data_found THEN
                v_error_messsage := 'Invalid default_shipping_org_code';
                RAISE invalid_item;
            END;
            --------
          END IF;
          ----We have valid Product Line value
          v_step                        := 'Step 260';
          l_sales_concat_segments       := organization_rec.sales_concat_segments_1_2_3_4 || '.' ||
                                           cur_item.product_line || '.' || -- segment5 from excel
                                           organization_rec.sales_concat_segments_6_7_8_9;
          l_encumbrance_concat_segments := organization_rec.encumb_concat_segments_1_2_3_4 || '.' ||
                                           cur_item.product_line || '.' || -- segment5 from excel
                                           organization_rec.encumb_concat_segments_6_7_8_9;
          l_expense_concat_segments     := organization_rec.expense_segment1 || '.' ||
                                           '210' || '.' || -- segment2 (Department)--const
                                           organization_rec.expens_concat_segments_3_4 || '.' ||
                                           cur_item.product_line || '.' || -- segment5 from excel
                                           organization_rec.expens_concat_segments_6_7_8_9;
          l_cogs_concat_segments        := organization_rec.cogs_concat_segments_1_2_3_4 || '.' ||
                                           cur_item.product_line || '.' || -- segment5 from excel
                                           organization_rec.cogs_concat_segments_6_7_8_9;
          ------check/create sales account-----
          BEGIN
            SELECT code_combination_id
              INTO l_sales_account_id
              FROM gl_code_combinations_kfv
             WHERE concatenated_segments = l_sales_concat_segments
               AND enabled_flag = 'Y';
          EXCEPTION
            WHEN no_data_found THEN
            
              xxgl_utils_pkg.get_and_create_account(p_concat_segment      => l_sales_concat_segments,
                                                    p_coa_id              => l_coa_id,
                                                    x_code_combination_id => l_sales_account_id,
                                                    x_return_code         => l_return_status,
                                                    x_err_msg             => v_error_messsage);
            
              IF l_return_status != fnd_api.g_ret_sts_success THEN
                v_error_messsage := 'Create Sales account ''' ||
                                    l_sales_concat_segments || ''' Error';
                RAISE invalid_item;
              END IF;
          END;
          v_step := 'Step 270';
          ------check/create encumbrance account-----
          BEGIN
            SELECT code_combination_id
              INTO l_encumbrance_account_id
              FROM gl_code_combinations_kfv
             WHERE concatenated_segments = l_encumbrance_concat_segments
               AND enabled_flag = 'Y';
          EXCEPTION
            WHEN no_data_found THEN
            
              xxgl_utils_pkg.get_and_create_account(p_concat_segment      => l_encumbrance_concat_segments,
                                                    p_coa_id              => l_coa_id,
                                                    x_code_combination_id => l_encumbrance_account_id,
                                                    x_return_code         => l_return_status,
                                                    x_err_msg             => v_error_messsage);
            
              IF l_return_status != fnd_api.g_ret_sts_success THEN
                v_error_messsage := 'Create Encumbrance account ''' ||
                                    l_encumbrance_concat_segments ||
                                    ''' Error';
                RAISE invalid_item;
              END IF;
          END;
          v_step := 'Step 280';
          ------check/create expense account-----            
          BEGIN
            SELECT code_combination_id
              INTO l_expense_account_id
              FROM gl_code_combinations_kfv
             WHERE concatenated_segments = l_expense_concat_segments
               AND enabled_flag = 'Y';
          EXCEPTION
            WHEN no_data_found THEN
            
              xxgl_utils_pkg.get_and_create_account(p_concat_segment      => l_expense_concat_segments,
                                                    p_coa_id              => l_coa_id,
                                                    x_code_combination_id => l_expense_account_id,
                                                    x_return_code         => l_return_status,
                                                    x_err_msg             => v_error_messsage);
            
              IF l_return_status != fnd_api.g_ret_sts_success THEN
                v_error_messsage := 'Create Expense account ''' ||
                                    l_expense_concat_segments || ''' Error';
                RAISE invalid_item;
              END IF;
          END;
          v_step := 'Step 290';
          ------check/create cogs account-----
          BEGIN
            SELECT code_combination_id
              INTO l_cogs_id
              FROM gl_code_combinations_kfv
             WHERE concatenated_segments = l_cogs_concat_segments
               AND enabled_flag = 'Y';
          EXCEPTION
            WHEN no_data_found THEN
            
              xxgl_utils_pkg.get_and_create_account(p_concat_segment      => l_cogs_concat_segments,
                                                    p_coa_id              => l_coa_id,
                                                    x_code_combination_id => l_cogs_id,
                                                    x_return_code         => l_return_status,
                                                    x_err_msg             => v_error_messsage);
            
              IF l_return_status != fnd_api.g_ret_sts_success THEN
                v_error_messsage := 'Create Cogs account ''' ||
                                    l_cogs_concat_segments || ''' Error';
                RAISE invalid_item;
              END IF;
          END;
          -----------
          v_step := 'Step 300';
          IF cur_item.qa_desc IS NOT NULL THEN
            ----------
            BEGIN
              SELECT ffv.flex_value_meaning
                INTO l_qa_desc
                FROM fnd_flex_value_sets fvs, fnd_flex_values_vl ffv
               WHERE fvs.flex_value_set_id = ffv.flex_value_set_id
                 AND fvs.flex_value_set_name = 'XXINV_QA_ITEM_CODES'
                 AND ffv.description = cur_item.qa_desc;
            EXCEPTION
              WHEN no_data_found THEN
              
                v_error_messsage := 'invalid qa desc';
                RAISE invalid_item;
            END;
            ----------
          END IF;
          v_step := 'Step 310';
          IF cur_item.receiving_routing IS NOT NULL THEN
            --------
            BEGIN
              SELECT rrh.routing_header_id
                INTO l_receiving_routing_id
                FROM rcv_routing_headers rrh
               WHERE routing_name = cur_item.receiving_routing;
            EXCEPTION
              WHEN no_data_found THEN
              
                v_error_messsage := 'invalid routing ' || SQLERRM;
                RAISE invalid_item;
            END;
            ---------
          END IF;
          v_step := 'Step 320';
          IF cur_item.country IS NOT NULL THEN
            --------
            BEGIN
              SELECT t.territory_code
                INTO l_country_code
                FROM fnd_territories_vl t
               WHERE t.territory_code = cur_item.country;
            EXCEPTION
              WHEN no_data_found THEN
              
                v_error_messsage := 'invalid country' || SQLERRM;
                RAISE invalid_item;
            END;
            -------
          END IF;
          v_step := 'Step 330';
          IF cur_item.supply_type IS NOT NULL THEN
            ---------
            BEGIN
              SELECT lookup_code
                INTO l_supply_type
                FROM fnd_lookup_values_vl
               WHERE lookup_type = 'WIP_SUPPLY'
                 AND meaning = cur_item.supply_type;
            EXCEPTION
              WHEN OTHERS THEN
                v_error_messsage := 'invalid supply type ' || SQLERRM;
                RAISE invalid_item;
            END;
            ---------
          END IF;
          v_step := 'Step 340';
          IF cur_item.shelf_life_code IS NOT NULL THEN
            ---------
            BEGIN
              SELECT lookup_code
                INTO l_shelf_life_code
                FROM fnd_lookup_values_vl
               WHERE lookup_type LIKE 'MTL_SHELF_LIFE'
                 AND meaning = cur_item.shelf_life_code;
            EXCEPTION
              WHEN OTHERS THEN
                v_error_messsage := 'invalid shelf life code ' || SQLERRM;
                RAISE invalid_item;
            END;
            ---------
          END IF;
          v_step := 'Step 350';
          -----------
          BEGIN
          
            SELECT mit.template_id
              INTO l_template_id
              FROM mtl_item_templates_vl mit
             WHERE mit.template_name = cur_item.item_template_name;
          EXCEPTION
            WHEN OTHERS THEN
            
              v_error_messsage := 'invalid Template ' || SQLERRM;
              RAISE invalid_item;
            
          END;
          -----------
          v_step := 'Step 350';
          -----Insert Into Interface
          t_item_rec.item_number                := upper(cur_item.item_code);
          t_item_rec.segment1                   := upper(cur_item.item_code);
          t_item_rec.description                := ltrim(rtrim(ltrim(cur_item.item_desc,
                                                                     ' '),
                                                               ' '),
                                                         '-');
          t_item_rec.organization_id            := cur_item.organization_id;
          t_item_rec.long_description           := nvl(cur_item.item_detail,
                                                       fnd_api.g_miss_char);
          t_item_rec.default_so_source_type     := nvl(cur_item.default_so_source_type,
                                                       fnd_api.g_miss_char);
          t_item_rec.primary_uom_code           := l_uom;
          t_item_rec.primary_unit_of_measure    := l_unit_of_measure;
          t_item_rec.inventory_item_status_code := l_inventory_status_code;
          t_item_rec.item_catalog_group_id      := nvl(v_cat_group_id,
                                                       fnd_api.g_miss_num);
          t_item_rec.shelf_life_code            := nvl(l_shelf_life_code,
                                                       fnd_api.g_miss_num);
          t_item_rec.shelf_life_days            := nvl(cur_item.shelf_life_days,
                                                       fnd_api.g_miss_num);
          t_item_rec.buyer_id                   := nvl(l_buyer_id,
                                                       fnd_api.g_miss_num);
          t_item_rec.planner_code               := nvl(v_planner_code,
                                                       fnd_api.g_miss_char);
          t_item_rec.min_minmax_quantity        := nvl(cur_item.min_minmax_quantity,
                                                       fnd_api.g_miss_num);
          t_item_rec.max_minmax_quantity        := nvl(cur_item.max_minmax_quantity,
                                                       fnd_api.g_miss_num);
          t_item_rec.minimum_order_quantity := (CASE
                                                 WHEN nvl(cur_item.min_order_qty, 0) = 0 THEN
                                                  fnd_api.g_miss_num
                                                 ELSE
                                                  cur_item.min_order_qty
                                               END);
          t_item_rec.maximum_order_quantity := (CASE
                                                 WHEN nvl(cur_item.min_order_qty, 0) != 0 THEN
                                                  greatest(nvl(cur_item.max_order_qty,
                                                               0),
                                                           cur_item.min_order_qty)
                                                 WHEN nvl(cur_item.max_order_qty, 0) = 0 THEN
                                                  fnd_api.g_miss_num
                                                 ELSE
                                                  cur_item.max_order_qty
                                               END);
          t_item_rec.preprocessing_lead_time    := nvl(cur_item.pre_proc_lead_time,
                                                       fnd_api.g_miss_num);
          t_item_rec.full_lead_time             := nvl(cur_item.processing_lead_time,
                                                       fnd_api.g_miss_num);
          t_item_rec.postprocessing_lead_time   := nvl(cur_item.pre_proc_lead_time,
                                                       fnd_api.g_miss_num);
          t_item_rec.fixed_lead_time            := nvl(cur_item.fixed_lt_prod,
                                                       fnd_api.g_miss_num);
          t_item_rec.list_price_per_unit        := nvl(cur_item.po_list_price,
                                                       fnd_api.g_miss_num);
          t_item_rec.fixed_order_quantity       := nvl(cur_item.fixed_order_qty,
                                                       fnd_api.g_miss_num);
          t_item_rec.fixed_days_supply          := nvl(cur_item.fixed_days_supply,
                                                       fnd_api.g_miss_num);
          t_item_rec.fixed_lot_multiplier       := nvl(cur_item.fixed_lot_multiplier,
                                                       fnd_api.g_miss_num);
          t_item_rec.receiving_routing_id       := nvl(l_receiving_routing_id,
                                                       fnd_api.g_miss_num);
          t_item_rec.receipt_required_flag      := nvl(cur_item.receipt_required_flag,
                                                       fnd_api.g_miss_char);
          t_item_rec.inspection_required_flag   := nvl(cur_item.inspection_required_flag,
                                                       fnd_api.g_miss_char);
        
          t_item_rec.dimension_uom_code := l_dimension_uom;
          t_item_rec.unit_length        := l_unit_length;
          t_item_rec.unit_width         := l_unit_width;
          t_item_rec.unit_height        := l_unit_height;
        
          t_item_rec.auto_serial_alpha_prefix := nvl(cur_item.start_auto_serial_number,
                                                     fnd_api.g_miss_char);
        
          t_item_rec.unit_weight     := nvl(cur_item.unit_weight,
                                            fnd_api.g_miss_num);
          t_item_rec.weight_uom_code := (CASE
                                          WHEN cur_item.unit_weight IS NOT NULL THEN
                                           nvl(cur_item.weight_uom_code, 'KG')
                                          ELSE
                                           fnd_api.g_miss_char
                                        END);
        
          t_item_rec.unit_volume     := nvl(cur_item.unit_volume,
                                            fnd_api.g_miss_num);
          t_item_rec.volume_uom_code := nvl(cur_item.volume_uom_code,
                                            fnd_api.g_miss_char);
        
          t_item_rec.shrinkage_rate        := nvl(cur_item.shrinkage_rate,
                                                  fnd_api.g_miss_num);
          t_item_rec.wip_supply_type       := nvl(l_supply_type,
                                                  fnd_api.g_miss_num);
          t_item_rec.cost_of_sales_account := nvl(l_cogs_id,
                                                  fnd_api.g_miss_num);
          t_item_rec.sales_account         := nvl(l_sales_account_id,
                                                  fnd_api.g_miss_num);
          t_item_rec.encumbrance_account   := nvl(l_encumbrance_account_id,
                                                  fnd_api.g_miss_num);
          t_item_rec.expense_account       := nvl(l_expense_account_id,
                                                  fnd_api.g_miss_num);
        
          t_item_rec.planning_make_buy_code := l_plan_make_buy;
          t_item_rec.default_shipping_org   := l_default_ship_organization_id;
          t_item_rec.attribute2             := l_country_code;
          t_item_rec.attribute3             := cur_item.hs_no;
          t_item_rec.attribute4             := cur_item.exp_min_month_il;
          t_item_rec.attribute5             := cur_item.exp_min_month_eu;
          t_item_rec.attribute6             := cur_item.exp_min_month_usa;
          t_item_rec.attribute7             := cur_item.min_exp_month_il_cust;
          t_item_rec.attribute8             := l_qa_desc;
          --   t_item_rec.attribute9                 := cur_item.s_related_item;
          t_item_rec.attribute11 := cur_item.repairable;
          t_item_rec.attribute12 := cur_item.returnable;
          t_item_rec.attribute13 := (CASE
                                      WHEN cur_item.rohs = 'Y' THEN
                                       'Yes'
                                      WHEN cur_item.rohs = 'N' THEN
                                       'No'
                                      ELSE
                                       cur_item.rohs
                                    END);
          t_item_rec.attribute14 := cur_item.abc_class;
          t_item_rec.attribute16 := cur_item.part_spec_19;
          t_item_rec.attribute17 := cur_item.toxic_qty_allowed;
          t_item_rec.attribute18 := cur_item.formula;
          t_item_rec.attribute19 := cur_item.s_m;
        
          t_rev_rec.transaction_type := ego_item_pub.g_ttype_create;
          t_rev_rec.item_number      := upper(cur_item.item_code);
          t_rev_rec.organization_id  := cur_item.organization_id;
          t_rev_rec.revision_code    := cur_item.revision;
        
          v_step := 'Step 360';
          inv_item_grp.create_item(p_commit           => fnd_api.g_false,
                                   p_validation_level => fnd_api.g_valid_level_full,
                                   p_item_rec         => t_item_rec,
                                   x_item_rec         => t_item_rec_out,
                                   x_return_status    => l_return_status,
                                   x_error_tbl        => l_error_tbl,
                                   p_template_id      => l_template_id,
                                   p_template_name    => cur_item.item_template_name,
                                   p_revision_rec     => t_rev_rec);
        
          IF l_return_status != 'S' THEN
            -- ROLLBACK TO begin_mass_update;
          
            -- error_handler.get_message_list(x_message_list => l_error_tbl);
            FOR i IN 1 .. l_error_tbl.count LOOP
              v_error_messsage := v_error_messsage || l_error_tbl(i)
                                 .message_text || chr(10);
            
            END LOOP;
          
            RAISE invalid_item;
          
          END IF;
          v_step := 'Step 370';
          UPDATE xxobjt_conv_items
             SET trans_to_int_code  = decode(nvl(trans_to_int_code, 'ZZZ'),
                                             'E',
                                             'E',
                                             'S'),
                 trans_to_int_error = ltrim(trans_to_int_error || ';+' ||
                                            organization_rec.organization_id || '(' ||
                                            organization_rec.organization_code || ')',
                                            ';'),
                 request_id         = l_request_id,
                 last_update_date   = SYSDATE
           WHERE item_code = cur_item.item_code
             AND organization_id = cur_item.organization_id;
        EXCEPTION
        
          WHEN invalid_item THEN
          
            UPDATE xxobjt_conv_items
               SET trans_to_int_code  = 'E',
                   trans_to_int_error = ---organization_rec.organization_id||'('||organization_rec.organization_code||')'||'-invalid item-'||l_error_msg
                    ltrim(trans_to_int_error || ';-' ||
                          substr(organization_rec.organization_id || '(' ||
                                 organization_rec.organization_code || ')' ||
                                 '-invalid item-' || v_error_messsage,
                                 1,
                                 100),
                          ';'),
                   request_id         = l_request_id,
                   last_update_date   = SYSDATE
             WHERE item_code = cur_item.item_code
               AND organization_id = cur_item.organization_id; ---Vitaly
        
          WHEN OTHERS THEN
            ---l_error_msg := l_error_msg || ': ' || SQLERRM;
            v_error_messsage := SQLERRM;
            UPDATE xxobjt_conv_items
               SET trans_to_int_code  = 'E',
                   trans_to_int_error = ltrim(trans_to_int_error || ';-' ||
                                              substr(organization_rec.organization_id || '(' ||
                                                     organization_rec.organization_code || ') ' ||
                                                     ' Unexpected error (' ||
                                                     v_step || ') ' ||
                                                     v_error_messsage,
                                                     1,
                                                     100),
                                              ';'),
                   request_id         = l_request_id,
                   last_update_date   = SYSDATE
             WHERE item_code = cur_item.item_code
               AND organization_id = cur_item.organization_id;
          
        END;
      
      END LOOP; ----- cursor get_all_organizations
      COMMIT;
    END LOOP; ----cursor csr_master_items
    COMMIT;
  
    v_step := 'Step 380';
    -----count SUCCESS and count ERRORS in this running-----
    FOR result_rec IN get_results LOOP
      message(result_rec.num_of_success_created_items ||
              ' items CREATED in organization ''' ||
              result_rec.organization_code || '''');
      IF result_rec.num_of_errors > 0 THEN
        message(result_rec.num_of_errors ||
                ' creation ERRORS in organization ''' ||
                result_rec.organization_code || '''');
      
      END IF;
    END LOOP;
  
  EXCEPTION
    WHEN stop_processing THEN
      message(v_error_messsage);
      retcode := '2';
      errbuf  := v_error_messsage;
    WHEN OTHERS THEN
      v_error_messsage := 'Unexpected Error in Item_Org_Assignment (' ||
                          v_step || ') ' || SQLERRM;
      message(v_error_messsage);
      errbuf  := v_error_messsage;
      retcode := '2';
  END item_org_assignment;
  ------------------------------------------------------------------------------------  
  PROCEDURE update_ssys_item(errbuf      OUT VARCHAR2,
                             retcode     OUT VARCHAR2,
                             p_location  IN VARCHAR2,
                             p_file_name IN VARCHAR2) IS
    -- csv-file expected
    ---------------------------------------------------------
    ---csv-file expected---------first record (headers record) will not be processed----
    ---field 1-----Segment1----------------varchar2
    ---field 2-----Item Description -------varchar2
    ---field 3-----Organization Code-------varchar2
    ---field 4-----Minimum Qty-------------number
    ---field 5-----Maximum Qty-------------number
    ---field 6-----Fixed Lot Multiplier----number
    ---field 7-----Min Order Qty-----------number
    ---field 8-----Max Order Qty-----------number----should be >= (Maximum Qty-Minimum Qty)
    ---field 9-----Planner First Name------varchar2
    ---field 10----Planner Last Name-------varchar2
  
    --v_user_id                NUMBER;
    v_step      VARCHAR2(100);
    v_line_buf  VARCHAR2(2000);
    v_read_code NUMBER := 1;
    v_file      utl_file.file_type;
    --v_delimiter              CHAR(1) := ',';
    v_fetched_rows_counter   NUMBER := 0;
    v_invalid_record_counter NUMBER := 0;
    invalid_record EXCEPTION;
    --v_numeric_dummy NUMBER;
  
    t_item_rec     inv_item_grp.item_rec_type;
    t_item_rec_out inv_item_grp.item_rec_type;
    --t_rev_rec      inv_item_grp.item_revision_rec_type;
    --l_error_tbl    error_handler.error_tbl_type;
    l_error_tbl     inv_item_grp.error_tbl_type;
    l_return_status VARCHAR2(1);
    l_err_msg       VARCHAR2(5000);
  
    v_items_updated_successfuly NUMBER := 0;
    v_items_updating_failure    NUMBER := 0;
  
    ----values from csv-file--------
    v_item_segment1            VARCHAR2(200);
    v_item_description         VARCHAR2(200);
    v_organization_code        VARCHAR2(200);
    v_min_qty_str              VARCHAR2(200);
    v_max_qty_str              VARCHAR2(200);
    v_fixed_lot_multiplier_str VARCHAR2(200);
    v_min_order_qty_str        VARCHAR2(200);
    v_max_order_qty_str        VARCHAR2(200);
    v_planner_first_name       VARCHAR2(200);
    v_planner_last_name        VARCHAR2(200);
    ---v_buyer_first_name          varchar2(200); -- NOT IN USE
    ---v_buyer_last_name           varchar2(200); -- NOT IN USE
  
    --------------------------------
    v_inventory_item_id    NUMBER;
    v_organization_id      NUMBER;
    v_min_qty              NUMBER;
    v_max_qty              NUMBER;
    v_fixed_lot_multiplier NUMBER;
    v_min_order_qty        NUMBER;
    v_max_order_qty        NUMBER;
    v_planner_code         VARCHAR2(200);
    v_buyer_id             NUMBER;
  
  BEGIN
    v_step  := 'Step 0';
    retcode := '0';
    errbuf  := NULL;
    -----fnd_global.apps_initialize --- for debugging only
    /*BEGIN      
           SELECT user_id
             INTO v_user_id
             FROM fnd_user
            WHERE user_name = 'CONVERSION';      
           fnd_global.apps_initialize(v_user_id,
                                      resp_id => 20420,
                                      resp_appl_id => 1);      
        EXCEPTION
           WHEN no_data_found THEN
              errbuf  := 'Invalid User';
              retcode := '2';
    END;*/
    -------
  
    -- open the file for reading
    BEGIN
      v_file := utl_file.fopen(location  => p_location,
                               filename  => p_file_name,
                               open_mode => 'r');
      fnd_file.put_line(fnd_file.log,
                        'File ' || ltrim(p_file_name) ||
                        ' Is open For Reading ');
    EXCEPTION
      WHEN utl_file.invalid_path THEN
        retcode := '2';
        errbuf  := errbuf || 'Invalid Path for ' || ltrim(p_file_name) ||
                   chr(0);
      WHEN utl_file.invalid_mode THEN
        retcode := '2';
        errbuf  := errbuf || 'Invalid Mode for ' || ltrim(p_file_name) ||
                   chr(0);
      WHEN utl_file.invalid_operation THEN
        retcode := '2';
        errbuf  := errbuf || 'Invalid operation for ' || ltrim(p_file_name) ||
                   SQLERRM || chr(0);
      WHEN OTHERS THEN
        retcode := '2';
        errbuf  := errbuf || 'Other for ' || ltrim(p_file_name) || chr(0);
    END;
  
    v_step := 'Step 10';
    -- Loop For All File's Lines
    WHILE v_read_code <> 0 AND nvl(retcode, '0') = '0' LOOP
      BEGIN
        utl_file.get_line(file => v_file, buffer => v_line_buf);
        -- remove comma inside description between " "
        v_line_buf             := regexp_replace(v_line_buf,
                                                 '((\"|^).*?(\"|$))|,',
                                                 '\1');
        v_line_buf             := REPLACE(v_line_buf, '"');
        v_fetched_rows_counter := v_fetched_rows_counter + 1;
      EXCEPTION
        WHEN utl_file.read_error THEN
          retcode := '2';
          errbuf  := 'Read Error' || chr(0);
        WHEN no_data_found THEN
          errbuf      := 'Read Complete' || chr(0);
          v_read_code := 0;
        WHEN OTHERS THEN
          retcode := '2';
          errbuf  := 'Other for Line Read' || SQLERRM || chr(0);
      END;
      IF v_read_code <> 0 AND v_fetched_rows_counter > 1 THEN
        --dont process first fetched record (headers record)
        v_inventory_item_id    := NULL;
        v_organization_id      := NULL;
        v_min_qty              := NULL;
        v_max_qty              := NULL;
        v_fixed_lot_multiplier := NULL;
        v_min_order_qty        := NULL;
        v_max_order_qty        := NULL;
        v_planner_code         := NULL;
        v_buyer_id             := NULL;
        -------
        BEGIN
          v_step := 'Step 20';
          ----get field 1 from csv-file--------------------- 
          v_item_segment1 := substr(v_line_buf,
                                    1,
                                    instr(v_line_buf, ',', 1, 1) - 1);
          v_item_segment1 := upper(REPLACE(v_item_segment1, ' ', ''));
          ----get field 2 from csv-file--------------------- 
          v_item_description := substr(v_line_buf,
                                       instr(v_line_buf, ',', 1, 1) + 1,
                                       instr(v_line_buf, ',', 1, 2) -
                                       instr(v_line_buf, ',', 1, 1) - 1);
          v_item_description := ltrim(rtrim(v_item_description, ' '), ' ');
          ----get field 3 from csv-file---------------------                                           
          v_organization_code := substr(v_line_buf,
                                        instr(v_line_buf, ',', 1, 2) + 1,
                                        instr(v_line_buf, ',', 1, 3) -
                                        instr(v_line_buf, ',', 1, 2) - 1);
          v_organization_code := REPLACE(v_organization_code, ' ', '');
          ----get field 4 from csv-file---------------------
          v_min_qty_str := substr(v_line_buf,
                                  instr(v_line_buf, ',', 1, 3) + 1,
                                  instr(v_line_buf, ',', 1, 4) -
                                  instr(v_line_buf, ',', 1, 3) - 1);
          v_min_qty_str := REPLACE(v_min_qty_str, ' ', '');
          ----get field 5 from csv-file---------------------
          v_max_qty_str := substr(v_line_buf,
                                  instr(v_line_buf, ',', 1, 4) + 1,
                                  instr(v_line_buf, ',', 1, 5) -
                                  instr(v_line_buf, ',', 1, 4) - 1);
          v_max_qty_str := REPLACE(v_max_qty_str, ' ', '');
          ----get field 6 from csv-file---------------------
          v_fixed_lot_multiplier_str := substr(v_line_buf,
                                               instr(v_line_buf, ',', 1, 5) + 1,
                                               instr(v_line_buf, ',', 1, 6) -
                                               instr(v_line_buf, ',', 1, 5) - 1);
          v_fixed_lot_multiplier_str := REPLACE(v_fixed_lot_multiplier_str,
                                                ' ',
                                                '');
          ----get field 7 from csv-file---------------------
          v_min_order_qty_str := substr(v_line_buf,
                                        instr(v_line_buf, ',', 1, 6) + 1,
                                        instr(v_line_buf, ',', 1, 7) -
                                        instr(v_line_buf, ',', 1, 6) - 1);
          v_min_order_qty_str := REPLACE(v_min_order_qty_str, ' ', '');
          ----get field 8 from csv-file---------------------
          v_max_order_qty_str := substr(v_line_buf,
                                        instr(v_line_buf, ',', 1, 7) + 1,
                                        instr(v_line_buf, ',', 1, 8) -
                                        instr(v_line_buf, ',', 1, 7) - 1);
          v_max_order_qty_str := REPLACE(v_max_order_qty_str, ' ', '');
          ----get field 9 from csv-file---------------------
          v_planner_first_name := substr(v_line_buf,
                                         instr(v_line_buf, ',', 1, 8) + 1,
                                         instr(v_line_buf, ',', 1, 9) -
                                         instr(v_line_buf, ',', 1, 8) - 1);
          v_planner_first_name := ltrim(rtrim(v_planner_first_name, ' '),
                                        ' ');
          ----get field 10 from csv-file-------------LAST FIELD-------------remove "new line" character (chr(13) from last field value
          v_planner_last_name := substr(v_line_buf,
                                        instr(v_line_buf, ',', 1, 9) + 1);
          v_planner_last_name := rtrim(rtrim(ltrim(rtrim(v_planner_last_name,
                                                         ' '),
                                                   ' '),
                                             chr(13)),
                                       ',');
          /*----get field 11 from csv-file---------------------
          v_buyer_first_name          := substr(v_line_buf,
                                               instr(v_line_buf,',',1,10)+1,
                                               instr(v_line_buf,',',1,11)-instr(v_line_buf,',',1,10) -1 );
          v_buyer_first_name          :=ltrim(rtrim(v_buyer_first_name,' '),' ');      
          ----get field 12 from csv-file--------LAST FIELD-------------remove "new line" character (chr(13) from last field value
          v_buyer_last_name           := substr(v_line_buf,
                                               instr(v_line_buf,',',1,11)+1);
          v_buyer_last_name           :=rtrim(ltrim(rtrim(v_buyer_last_name,' '),' '),chr(13)); */
        
          v_step := 'Step 30';
          IF v_item_segment1 IS NULL THEN
            v_invalid_record_counter := v_invalid_record_counter + 1;
            fnd_file.put_line(fnd_file.output,
                              'Invalid Record #' || v_fetched_rows_counter ||
                              ' --- missing Item Code');
            -----DBMS_OUTPUT.put_line('Invalid Record #'||v_fetched_rows_counter||' --- missing Item Code');
            RAISE invalid_record;
          ELSIF instr(v_item_segment1, '.', 1) > 0 OR
                instr(v_item_segment1, ',', 1) > 0 OR
                instr(v_item_segment1, '<', 1) > 0 OR
                instr(v_item_segment1, '>', 1) > 0 OR
                instr(v_item_segment1, '=', 1) > 0 OR
                instr(v_item_segment1, '_', 1) > 0 OR
                instr(v_item_segment1, ';', 1) > 0 OR
                instr(v_item_segment1, ':', 1) > 0 OR
                instr(v_item_segment1, '+', 1) > 0 OR
                instr(v_item_segment1, ')', 1) > 0 OR
                instr(v_item_segment1, '(', 1) > 0 OR
                instr(v_item_segment1, '*', 1) > 0 OR
                instr(v_item_segment1, '&', 1) > 0 OR
                instr(v_item_segment1, '^', 1) > 0 OR
                instr(v_item_segment1, '%', 1) > 0 OR
                instr(v_item_segment1, '$', 1) > 0 OR
                instr(v_item_segment1, '#', 1) > 0 OR
                instr(v_item_segment1, '@', 1) > 0 OR
                instr(v_item_segment1, '!', 1) > 0 OR
                instr(v_item_segment1, '?', 1) > 0 OR
                instr(v_item_segment1, '/', 1) > 0 OR
                instr(v_item_segment1, '\', 1) > 0 OR
                instr(v_item_segment1, '''', 1) > 0 OR
                instr(v_item_segment1, '"', 1) > 0 OR
                instr(v_item_segment1, '|', 1) > 0 OR
                instr(v_item_segment1, '{', 1) > 0 OR
                instr(v_item_segment1, '}', 1) > 0 OR
                instr(v_item_segment1, '[', 1) > 0 OR
                instr(v_item_segment1, ']', 1) > 0 THEN
            v_invalid_record_counter := v_invalid_record_counter + 1;
            fnd_file.put_line(fnd_file.output,
                              'Invalid Record #' || v_fetched_rows_counter ||
                              ' --- forbidden character in Item Code ''' ||
                              v_item_segment1 || '''');
            ----DBMS_OUTPUT.put_line('Invalid Record #'||v_fetched_rows_counter||' --- forbidden character in Item Code '''||v_item_segment1||'''');
            RAISE invalid_record;
          END IF;
          v_step := 'Step 40';
          IF v_organization_code IS NULL THEN
            v_invalid_record_counter := v_invalid_record_counter + 1;
            fnd_file.put_line(fnd_file.output,
                              'Invalid Record #' || v_fetched_rows_counter ||
                              ' --- missing Organization Code');
            ----DBMS_OUTPUT.put_line('Invalid Record #'||v_fetched_rows_counter||' --- missing Organization Code');
            RAISE invalid_record;
          ELSE
            ----
            BEGIN
              SELECT mp.organization_id
                INTO v_organization_id
                FROM mtl_parameters mp
               WHERE mp.organization_code = v_organization_code;
            EXCEPTION
              WHEN no_data_found THEN
                v_invalid_record_counter := v_invalid_record_counter + 1;
                fnd_file.put_line(fnd_file.output,
                                  'Invalid Record #' ||
                                  v_fetched_rows_counter ||
                                  ' --- Organization ''' ||
                                  v_organization_code ||
                                  ''' does not exist (in mtl_parameters table)');
                ---DBMS_OUTPUT.put_line('Invalid Record #'||v_fetched_rows_counter||
                ---                                   ' --- Organization '''||v_organization_code||
                ---                                   ''' does not exist (in mtl_parameters table)');
                RAISE invalid_record;
            END;
            -----
          END IF;
          v_step := 'Step 50';
          BEGIN
            SELECT msi.inventory_item_id
              INTO v_inventory_item_id
              FROM mtl_system_items_b msi
             WHERE msi.segment1 = v_item_segment1
               AND msi.organization_id = v_organization_id;
          EXCEPTION
            WHEN no_data_found THEN
              v_invalid_record_counter := v_invalid_record_counter + 1;
              fnd_file.put_line(fnd_file.output,
                                'Invalid Record #' ||
                                v_fetched_rows_counter || ' --- Item ''' ||
                                v_item_segment1 ||
                                ''' does not exist in Organization ''' ||
                                v_organization_code || ''' (' ||
                                v_organization_id || ')');
              ---DBMS_OUTPUT.put_line('Invalid Record #'||v_fetched_rows_counter||
              ---                                       ' --- Item '''||v_item_segment1||
              ---                                       ''' does not exist in Organization '''||v_organization_code||''' ('||
              ---                                        v_organization_id||')');
              v_inventory_item_id := NULL;
              v_organization_id   := NULL;
              RAISE invalid_record;
          END;
        
          v_step := 'Step 60';
          BEGIN
            v_min_qty := to_number(v_min_qty_str);
            IF nvl(v_min_qty, 1) < 0 THEN
              v_invalid_record_counter := v_invalid_record_counter + 1;
              fnd_file.put_line(fnd_file.output,
                                'Invalid Record #' ||
                                v_fetched_rows_counter ||
                                ' --- Min Quantity should be positive value');
              ---DBMS_OUTPUT.put_line('Invalid Record #'||v_fetched_rows_counter||
              ---                                   ' --- Min Quantity should be positive value');
              RAISE invalid_record;
            END IF;
          EXCEPTION
            WHEN OTHERS THEN
              v_invalid_record_counter := v_invalid_record_counter + 1;
              fnd_file.put_line(fnd_file.output,
                                'Invalid Record #' ||
                                v_fetched_rows_counter ||
                                ' --- Min Quantity should be numeric value');
              ---DBMS_OUTPUT.put_line('Invalid Record #'||v_fetched_rows_counter||
              ---                                       ' --- Min Quantity should be numeric value');
              RAISE invalid_record;
          END;
        
          v_step := 'Step 70';
          BEGIN
            v_max_qty := to_number(v_max_qty_str);
            IF nvl(v_max_qty, 1) < 0 THEN
              v_invalid_record_counter := v_invalid_record_counter + 1;
              fnd_file.put_line(fnd_file.output,
                                'Invalid Record #' ||
                                v_fetched_rows_counter ||
                                ' --- Max Quantity should be positive value');
              ---DBMS_OUTPUT.put_line('Invalid Record #'||v_fetched_rows_counter||
              ---                                   ' --- Max Quantity should be positive value');
              RAISE invalid_record;
            END IF;
          EXCEPTION
            WHEN OTHERS THEN
              v_invalid_record_counter := v_invalid_record_counter + 1;
              fnd_file.put_line(fnd_file.output,
                                'Invalid Record #' ||
                                v_fetched_rows_counter ||
                                ' --- Max Quantity should be numeric value');
              ---DBMS_OUTPUT.put_line('Invalid Record #'||v_fetched_rows_counter||
              ---                                       ' --- Max Quantity should be numeric value');
              RAISE invalid_record;
          END;
        
          v_step := 'Step 80';
          BEGIN
            v_fixed_lot_multiplier := to_number(v_fixed_lot_multiplier_str);
            IF nvl(v_fixed_lot_multiplier, 1) < 0 THEN
              v_invalid_record_counter := v_invalid_record_counter + 1;
              fnd_file.put_line(fnd_file.output,
                                'Invalid Record #' ||
                                v_fetched_rows_counter ||
                                ' --- Fixed Lot Multiplier should be positive value');
              ---DBMS_OUTPUT.put_line('Invalid Record #'||v_fetched_rows_counter||
              ---                                   ' --- Fixed Lot Multiplier should be positive value');
              RAISE invalid_record;
            END IF;
          EXCEPTION
            WHEN OTHERS THEN
              v_invalid_record_counter := v_invalid_record_counter + 1;
              fnd_file.put_line(fnd_file.output,
                                'Invalid Record #' ||
                                v_fetched_rows_counter ||
                                ' --- Fixed Lot Multiplier should be numeric value');
              ---DBMS_OUTPUT.put_line('Invalid Record #'||v_fetched_rows_counter||
              ---                                       ' --- Fixed Lot Multiplier should be numeric value');
              RAISE invalid_record;
          END;
        
          v_step := 'Step 90';
          BEGIN
            v_min_order_qty := to_number(v_min_order_qty_str);
            IF nvl(v_min_order_qty, 1) < 0 THEN
              v_invalid_record_counter := v_invalid_record_counter + 1;
              fnd_file.put_line(fnd_file.output,
                                'Invalid Record #' ||
                                v_fetched_rows_counter ||
                                ' --- Min Order Quantity should be positive value');
              ---DBMS_OUTPUT.put_line('Invalid Record #'||v_fetched_rows_counter||
              ---                                   ' --- Min Order Quantity should be positive value');
              RAISE invalid_record;
            END IF;
          EXCEPTION
            WHEN OTHERS THEN
              v_invalid_record_counter := v_invalid_record_counter + 1;
              fnd_file.put_line(fnd_file.output,
                                'Invalid Record #' ||
                                v_fetched_rows_counter ||
                                ' --- Min Order Quantity should be numeric value');
              ---DBMS_OUTPUT.put_line('Invalid Record #'||v_fetched_rows_counter||
              ---                                       ' --- Min Order Quantity should be numeric value');
              RAISE invalid_record;
          END;
        
          v_step := 'Step 100';
          BEGIN
            ---DBMS_OUTPUT.put_line('v_max_order_qty_str length='||length(v_max_order_qty_str)||
            ---                     ', last ascii='''||ascii(substr(v_max_order_qty_str,length(v_max_order_qty_str)))||'''');
            v_max_order_qty := to_number(v_max_order_qty_str);
            IF nvl(v_max_order_qty, 1) < 0 THEN
              v_invalid_record_counter := v_invalid_record_counter + 1;
              fnd_file.put_line(fnd_file.output,
                                'Invalid Record #' ||
                                v_fetched_rows_counter ||
                                ' --- Max Order Quantity should be positive value');
              ---DBMS_OUTPUT.put_line('Invalid Record #'||v_fetched_rows_counter||
              ---                                   ' --- Max Order Quantity should be positive value');
              RAISE invalid_record;
            END IF;
          EXCEPTION
            WHEN OTHERS THEN
              v_invalid_record_counter := v_invalid_record_counter + 1;
              fnd_file.put_line(fnd_file.output,
                                'Invalid Record #' ||
                                v_fetched_rows_counter ||
                                ' --- Max Order Quantity should be numeric value');
              ---DBMS_OUTPUT.put_line('Invalid Record #'||v_fetched_rows_counter||
              ---                                       ' --- Max Order Quantity should be numeric value');
              RAISE invalid_record;
          END;
        
          v_step := 'Step 110';
          IF v_min_qty IS NULL AND v_max_qty IS NULL AND
             v_min_order_qty IS NULL AND v_max_order_qty IS NULL AND
             v_fixed_lot_multiplier IS NULL THEN
            v_invalid_record_counter := v_invalid_record_counter + 1;
            fnd_file.put_line(fnd_file.output,
                              'Invalid Record #' || v_fetched_rows_counter ||
                              ' --- No data for update (null is not zero)');
            ---DBMS_OUTPUT.put_line('Invalid Record #'||v_fetched_rows_counter||
            ---                                     ' --- No data for update (null is not zero)');
            RAISE invalid_record;
          END IF;
        
          v_step := 'Step 120';
          IF (v_min_qty IS NULL OR v_max_qty IS NULL) AND
             (v_min_order_qty IS NOT NULL OR v_max_order_qty IS NOT NULL OR
             v_fixed_lot_multiplier IS NOT NULL) THEN
            v_invalid_record_counter := v_invalid_record_counter + 1;
            fnd_file.put_line(fnd_file.output,
                              'Invalid Record #' || v_fetched_rows_counter ||
                              ' --- Input data is not logical');
            ---DBMS_OUTPUT.put_line('Invalid Record #'||v_fetched_rows_counter||
            ---                                     ' --- Input data is not logical');
            RAISE invalid_record;
          END IF;
        
          v_step := 'Step 130';
          ---Max Order Qty-----------number----should be >= (Maximum Qty-Minimum Qty)
          IF v_max_order_qty IS NOT NULL AND v_max_qty IS NOT NULL AND
             v_min_qty IS NOT NULL AND
             v_max_order_qty < (v_max_qty - v_min_qty) THEN
            v_invalid_record_counter := v_invalid_record_counter + 1;
            fnd_file.put_line(fnd_file.output,
                              'Invalid Record #' || v_fetched_rows_counter ||
                              ' --- Max Order Qty should be >= (Max Qty-Min Qty)');
            ---DBMS_OUTPUT.put_line('Invalid Record #'||v_fetched_rows_counter||
            ---                                  ' --- Max Order Qty should be >= (Max Qty-Min Qty)');
            RAISE invalid_record;
          END IF;
        
          IF v_planner_first_name IS NOT NULL OR
             v_planner_last_name IS NOT NULL THEN
            BEGIN
              -- search planner-epmloyee
              SELECT p.planner_code
                INTO v_planner_code
                FROM mtl_planners p, per_all_people_f papf
               WHERE p.employee_id = papf.person_id
                 AND lower(papf.first_name) =
                     lower(nvl(v_planner_first_name, 'XYZ'))
                 AND lower(papf.last_name) =
                     lower(nvl(v_planner_last_name, 'XYZ'))
                 AND organization_id = v_organization_id
                 AND rownum = 1;
            
            EXCEPTION
              WHEN OTHERS THEN
                v_planner_code := NULL;
            END;
            IF v_planner_code IS NULL THEN
              BEGIN
                -- search planner that NON epmloyee
                SELECT p.planner_code
                  INTO v_planner_code
                  FROM mtl_planners p
                 WHERE REPLACE(lower(p.planner_code), ' ', '') =
                       REPLACE(lower(v_planner_first_name) ||
                               lower(v_planner_last_name),
                               ' ',
                               '')
                   AND p.organization_id = v_organization_id
                   AND rownum = 1;
              EXCEPTION
                WHEN OTHERS THEN
                  v_planner_code           := NULL;
                  v_invalid_record_counter := v_invalid_record_counter + 1;
                  fnd_file.put_line(fnd_file.output,
                                    'Invalid Record #' ||
                                    v_fetched_rows_counter ||
                                    ' --- Invalid planner (' ||
                                    v_planner_first_name || ' ' ||
                                    v_planner_last_name || ')');
                  RAISE invalid_record;
              END;
            END IF;
          END IF;
        
          v_step := 'Step 200';
          ----API update item
          ---t_item_rec.item_number                := v_item_segment1;
          ---t_item_rec.segment1                   := v_item_segment1;
          t_item_rec.inventory_item_id := v_inventory_item_id;
          -----t_item_rec.description                := v_item_description;
          t_item_rec.organization_id := v_organization_id;
          ----t_item_rec.long_description           := nvl(cur_item.item_detail,fnd_api.g_miss_char);
          ----t_item_rec.primary_uom_code           := l_uom;
          ----t_item_rec.primary_unit_of_measure    := l_unit_of_measure;
          ----t_item_rec.inventory_item_status_code := l_inventory_status_code;
          ----t_item_rec.item_catalog_group_id      := nvl(v_cat_group_id,fnd_api.g_miss_num);
          ----t_item_rec.shelf_life_code            := nvl(l_shelf_life_code,fnd_api.g_miss_num);
          ----t_item_rec.shelf_life_days            := nvl(cur_item.shelf_life_days,fnd_api.g_miss_num);
          ------------ASK---ERROR INV_IOI_MASTER_CHILD_1A ------ first determine which of the effected attributes (buyer_id) are controlled at the master level for your company.
          --------------------t_item_rec.buyer_id                   := nvl(v_buyer_id      ,fnd_api.g_miss_num);
          t_item_rec.planner_code           := nvl(v_planner_code,
                                                   fnd_api.g_miss_char);
          t_item_rec.min_minmax_quantity    := nvl(v_min_qty,
                                                   fnd_api.g_miss_num);
          t_item_rec.max_minmax_quantity    := nvl(v_max_qty,
                                                   fnd_api.g_miss_num);
          t_item_rec.minimum_order_quantity := nvl(v_min_order_qty,
                                                   fnd_api.g_miss_num);
          t_item_rec.maximum_order_quantity := nvl(v_max_order_qty,
                                                   fnd_api.g_miss_num);
          ----t_item_rec.preprocessing_lead_time    := nvl(cur_item.pre_proc_lead_time,fnd_api.g_miss_num);
          ----t_item_rec.full_lead_time             := nvl(cur_item.processing_lead_time,fnd_api.g_miss_num);
          ----t_item_rec.postprocessing_lead_time   := nvl(cur_item.pre_proc_lead_time,fnd_api.g_miss_num);
          ----t_item_rec.fixed_lead_time            := nvl(cur_item.fixed_lt_prod,fnd_api.g_miss_num);
          ----t_item_rec.list_price_per_unit        := nvl(cur_item.po_list_price,fnd_api.g_miss_num);
          ----t_item_rec.fixed_order_quantity       := nvl(cur_item.fixed_order_qty,fnd_api.g_miss_num);
          ----t_item_rec.fixed_days_supply          := nvl(cur_item.fixed_days_supply,fnd_api.g_miss_num);
          t_item_rec.fixed_lot_multiplier := nvl(v_fixed_lot_multiplier,
                                                 fnd_api.g_miss_num);
          ----t_item_rec.receiving_routing_id       := nvl(l_receiving_routing_id,fnd_api.g_miss_num);
          ----t_item_rec.receipt_required_flag      := nvl(cur_item.receipt_required_flag,fnd_api.g_miss_char);
          ----t_item_rec.inspection_required_flag   := nvl(cur_item.inspection_required_flag,fnd_api.g_miss_char);
          ----t_item_rec.unit_weight                := nvl(cur_item.unit_weight,fnd_api.g_miss_num);
          ----t_item_rec.weight_uom_code            := nvl(cur_item.weight_uom_code.g_miss_char);
          ----t_item_rec.shrinkage_rate             := nvl(cur_item.shrinkage_rate,fnd_api.g_miss_num);
          ----t_item_rec.wip_supply_type            := nvl(l_supply_type,fnd_api.g_miss_num);
          ----t_item_rec.cost_of_sales_account      := nvl(l_cogs_id,fnd_api.g_miss_num);
          ----t_item_rec.sales_account              := nvl(l_sales_account_id,fnd_api.g_miss_num);                                                
          ----t_item_rec.planning_make_buy_code     := l_plan_make_buy;
          ----t_item_rec.attribute2                 := l_country_code;
          ----t_item_rec.attribute3                 := cur_item.hs_no;
          ----t_item_rec.attribute4                 := cur_item.exp_min_month_il;
          ----t_item_rec.attribute5                 := cur_item.exp_min_month_eu;
          ----t_item_rec.attribute6                 := cur_item.exp_min_month_usa;
          ----t_item_rec.attribute7                 := cur_item.min_exp_month_il_cust;
          ----t_item_rec.attribute8                 := l_qa_desc;
          ----t_item_rec.attribute9                 := cur_item.s_related_item;
          ----t_item_rec.attribute11 := cur_item.repairable;
          ----t_item_rec.attribute12 := cur_item.returnable;
          ----t_item_rec.attribute13 := (CASE WHEN cur_item.rohs = 'Y' THEN 'Yes' WHEN cur_item.rohs = 'N' THEN 'No' ELSE cur_item.rohs END);
          ----t_item_rec.attribute14 := cur_item.abc_class;
          ----t_item_rec.attribute16 := cur_item.part_spec_19;
          ----t_item_rec.attribute17 := cur_item.toxic_qty_allowed;
          ----t_item_rec.attribute18 := cur_item.formula;
          ----t_item_rec.attribute19 := cur_item.s_m;
        
          ----t_rev_rec.transaction_type := ego_item_pub.g_ttype_create;
          ----t_rev_rec.item_number      := upper(cur_item.item_code);
          ----t_rev_rec.organization_id  := organization_rec.organization_id;  -----cur_item.organization_id;
          ----t_rev_rec.revision_code    := cur_item.revision;
        
          -----DBMS_OUTPUT.put_line('before API');
        
          v_step := 'Step 210';
          inv_item_grp.update_item(p_commit           => fnd_api.g_false,
                                   p_validation_level => fnd_api.g_valid_level_full,
                                   p_item_rec         => t_item_rec,
                                   x_item_rec         => t_item_rec_out,
                                   x_return_status    => l_return_status,
                                   x_error_tbl        => l_error_tbl);
          ---p_template_id      => l_template_id,
          ---p_template_name    => cur_item.item_template_name,
          ---p_revision_rec     => t_rev_rec);
        
          v_step := 'Step 220';
          IF l_return_status != 'S' THEN
            -- ROLLBACK TO begin_mass_update;
          
            -- error_handler.get_message_list(x_message_list => l_error_tbl);
            v_items_updating_failure := v_items_updating_failure + 1;
            l_err_msg                := NULL;
            FOR i IN 1 .. l_error_tbl.count LOOP
              l_err_msg := l_err_msg || l_error_tbl(i).message_text ||
                           chr(10);
            
            END LOOP;
            fnd_file.put_line(fnd_file.output,
                              '======Record #' || v_fetched_rows_counter ||
                              ' --- Item ''' || v_item_segment1 ||
                              ''' ,Organization ''' || v_organization_code ||
                              ''' (' || v_organization_id ||
                              ') -- API Error: ' || l_err_msg);
            ---DBMS_OUTPUT.put_line('======Record #'||v_fetched_rows_counter||
            ---                                        ' --- Item '''||v_item_segment1||
            ---                                        ''' ,Organization '''||v_organization_code||''' ('||
            ---                                         v_organization_id||') -- API Error: '||l_err_msg);   
            RAISE invalid_record;
          
          END IF;
          v_items_updated_successfuly := v_items_updated_successfuly + 1;
        
        EXCEPTION
          WHEN invalid_record THEN
            NULL;
        END;
        ---------
      END IF; -- IF v_read_code <> 0
    
      IF MOD(v_items_updated_successfuly, 100) = 0 THEN
        ---commit for each 100 items
        COMMIT;
      END IF;
    
    END LOOP;
  
    COMMIT;
  
    v_step := 'Step 230';
    fnd_file.put_line(fnd_file.output, ' '); --empty record
    fnd_file.put_line(fnd_file.output, ' '); --empty record
    fnd_file.put_line(fnd_file.output,
                      '========= Procedure XXCONV_ITEMS_PKG.UPDATE_SSYS_ITEMS was completed Successfuly (see results below) =================');
    fnd_file.put_line(fnd_file.output,
                      '========= There are ' ||
                      to_char(v_fetched_rows_counter - 1) ||
                      ' records (exclude first headers record) in file ' ||
                      p_location || '/' || p_file_name);
    fnd_file.put_line(fnd_file.output,
                      '========= ' || v_invalid_record_counter ||
                      ' records are invalid');
    fnd_file.put_line(fnd_file.output,
                      '========= ' || v_items_updated_successfuly ||
                      ' items were updated successfuly');
    fnd_file.put_line(fnd_file.output,
                      '========= ' || v_items_updating_failure ||
                      ' items updating failured');
  
    ---DBMS_OUTPUT.put_line('Procedure XXCONV_ITEMS_PKG.UPDATE_SSYS_ITEMS was completed Successfuly'); 
    ---DBMS_OUTPUT.put_line('There are '||v_fetched_rows_counter||' records (exclude first headers record) in file '||p_location||'/'|| p_file_name); 
    ---DBMS_OUTPUT.put_line(v_invalid_record_counter||' records are invalid'); 
    ---DBMS_OUTPUT.put_line(v_items_updated_successfuly||' items were updated successfuly'); 
    ---DBMS_OUTPUT.put_line(v_items_updating_failure||' items updating failured'); 
  
  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.output,
                        '=======Unexpected ERROR in update_ssys_item proc. ' ||
                        v_step || ' ---' || SQLERRM);
      ---DBMS_OUTPUT.put_line('=======Unexpected ERROR in update_ssys_item proc. '||v_step||' ---'||sqlerrm); 
      retcode := '2';
      errbuf  := '=======Unexpected ERROR in update_ssys_item proc. ' ||
                 v_step || ' ---' || SQLERRM;
  END update_ssys_item;
  ------------------------------------------------------------------------------------
  PROCEDURE update_ssys_item_list_price(errbuf      OUT VARCHAR2,
                                        retcode     OUT VARCHAR2,
                                        p_location  IN VARCHAR2,
                                        p_file_name IN VARCHAR2) IS
    -- csv-file expected
    ---------------------------------------------------------
    ---csv-file expected---------first record (headers record) will not be processed----
    ---field 1-----Segment1----------------varchar2
    ---field 2-----Item Description -------varchar2
    ---field 3-----Organization Code-------varchar2
    ---field 4-----List Price Per Unit-----number
  
    --v_user_id                NUMBER;
    v_step      VARCHAR2(100);
    v_line_buf  VARCHAR2(2000);
    v_read_code NUMBER := 1;
    v_file      utl_file.file_type;
    --v_delimiter              CHAR(1) := ',';
    v_fetched_rows_counter   NUMBER := 0;
    v_invalid_record_counter NUMBER := 0;
    invalid_record EXCEPTION;
    --v_numeric_dummy NUMBER;
  
    t_item_rec     inv_item_grp.item_rec_type;
    t_item_rec_out inv_item_grp.item_rec_type;
    --t_rev_rec      inv_item_grp.item_revision_rec_type;
    --l_error_tbl    error_handler.error_tbl_type;
    l_error_tbl     inv_item_grp.error_tbl_type;
    l_return_status VARCHAR2(1);
    l_err_msg       VARCHAR2(5000);
  
    v_items_updated_successfuly NUMBER := 0;
    v_items_updating_failure    NUMBER := 0;
  
    ----values from csv-file--------
    v_item_segment1           VARCHAR2(200);
    v_item_description        VARCHAR2(200);
    v_organization_code       VARCHAR2(200);
    v_list_price_per_unit_str VARCHAR2(200);
  
    --------------------------------
    v_inventory_item_id   NUMBER;
    v_organization_id     NUMBER;
    v_list_price_per_unit NUMBER;
  
  BEGIN
    v_step  := 'Step 0';
    retcode := '0';
    errbuf  := NULL;
    -----fnd_global.apps_initialize --- for debugging only
    /*BEGIN      
           SELECT user_id
             INTO v_user_id
             FROM fnd_user
            WHERE user_name = 'CONVERSION';      
           fnd_global.apps_initialize(v_user_id,
                                      resp_id => 20420,
                                      resp_appl_id => 1);      
        EXCEPTION
           WHEN no_data_found THEN
              errbuf  := 'Invalid User';
              retcode := '2';
    END;*/
    -------
  
    -- open the file for reading
    BEGIN
      v_file := utl_file.fopen(location  => p_location,
                               filename  => p_file_name,
                               open_mode => 'r');
      fnd_file.put_line(fnd_file.log,
                        'File ' || ltrim(p_file_name) ||
                        ' Is open For Reading ');
    EXCEPTION
      WHEN utl_file.invalid_path THEN
        retcode := '2';
        errbuf  := errbuf || 'Invalid Path for ' || ltrim(p_file_name) ||
                   chr(0);
      WHEN utl_file.invalid_mode THEN
        retcode := '2';
        errbuf  := errbuf || 'Invalid Mode for ' || ltrim(p_file_name) ||
                   chr(0);
      WHEN utl_file.invalid_operation THEN
        retcode := '2';
        errbuf  := errbuf || 'Invalid operation for ' || ltrim(p_file_name) ||
                   SQLERRM || chr(0);
      WHEN OTHERS THEN
        retcode := '2';
        errbuf  := errbuf || 'Other for ' || ltrim(p_file_name) || chr(0);
    END;
  
    v_step := 'Step 10';
    -- Loop For All File's Lines
    WHILE v_read_code <> 0 AND nvl(retcode, '0') = '0' LOOP
      BEGIN
        utl_file.get_line(file => v_file, buffer => v_line_buf);
        -- remove comma inside description between " "
        v_line_buf := regexp_replace(v_line_buf,
                                     '((\"|^).*?(\"|$))|,',
                                     '\1');
        v_line_buf := REPLACE(v_line_buf, '"');
      
        v_fetched_rows_counter := v_fetched_rows_counter + 1;
      EXCEPTION
        WHEN utl_file.read_error THEN
          retcode := '2';
          errbuf  := 'Read Error' || chr(0);
        WHEN no_data_found THEN
          errbuf      := 'Read Complete' || chr(0);
          v_read_code := 0;
        WHEN OTHERS THEN
          retcode := '2';
          errbuf  := 'Other for Line Read' || SQLERRM || chr(0);
      END;
      IF v_read_code <> 0 AND v_fetched_rows_counter > 1 THEN
        --dont process first fetched record (headers record)
        v_inventory_item_id   := NULL;
        v_organization_id     := NULL;
        v_list_price_per_unit := NULL;
        l_error_tbl.delete;
        -------
        BEGIN
          v_step := 'Step 20';
          ----get field 1 from csv-file--------------------- 
          v_item_segment1 := substr(v_line_buf,
                                    1,
                                    instr(v_line_buf, ',', 1, 1) - 1);
          v_item_segment1 := upper(REPLACE(v_item_segment1, ' ', ''));
          ----get field 2 from csv-file--------------------- 
          v_item_description := substr(v_line_buf,
                                       instr(v_line_buf, ',', 1, 1) + 1,
                                       instr(v_line_buf, ',', 1, 2) -
                                       instr(v_line_buf, ',', 1, 1) - 1);
          v_item_description := ltrim(rtrim(v_item_description, ' '), ' ');
          ----get field 3 from csv-file---------------------                                           
          v_organization_code := substr(v_line_buf,
                                        instr(v_line_buf, ',', 1, 2) + 1,
                                        instr(v_line_buf, ',', 1, 3) -
                                        instr(v_line_buf, ',', 1, 2) - 1);
          v_organization_code := REPLACE(v_organization_code, ' ', '');
          ----get field 4 from csv-file--------LAST FIELD-------------remove "new line" character (chr(13) from last field value
          v_list_price_per_unit_str := substr(v_line_buf,
                                              instr(v_line_buf, ',', 1, 3) + 1);
          v_list_price_per_unit_str := rtrim(ltrim(rtrim(v_list_price_per_unit_str,
                                                         ' '),
                                                   ' '),
                                             chr(13));
        
          v_step := 'Step 30';
          IF v_item_segment1 IS NULL THEN
            v_invalid_record_counter := v_invalid_record_counter + 1;
            fnd_file.put_line(fnd_file.output,
                              'Invalid Record #' || v_fetched_rows_counter ||
                              ' --- missing Item Code');
            -----DBMS_OUTPUT.put_line('Invalid Record #'||v_fetched_rows_counter||' --- missing Item Code');
            RAISE invalid_record;
          ELSIF instr(v_item_segment1, '.', 1) > 0 OR
                instr(v_item_segment1, ',', 1) > 0 OR
                instr(v_item_segment1, '<', 1) > 0 OR
                instr(v_item_segment1, '>', 1) > 0 OR
                instr(v_item_segment1, '=', 1) > 0 OR
                instr(v_item_segment1, '_', 1) > 0 OR
                instr(v_item_segment1, ';', 1) > 0 OR
                instr(v_item_segment1, ':', 1) > 0 OR
                instr(v_item_segment1, '+', 1) > 0 OR
                instr(v_item_segment1, ')', 1) > 0 OR
                instr(v_item_segment1, '(', 1) > 0 OR
                instr(v_item_segment1, '*', 1) > 0 OR
                instr(v_item_segment1, '&', 1) > 0 OR
                instr(v_item_segment1, '^', 1) > 0 OR
                instr(v_item_segment1, '%', 1) > 0 OR
                instr(v_item_segment1, '$', 1) > 0 OR
                instr(v_item_segment1, '#', 1) > 0 OR
                instr(v_item_segment1, '@', 1) > 0 OR
                instr(v_item_segment1, '!', 1) > 0 OR
                instr(v_item_segment1, '?', 1) > 0 OR
                instr(v_item_segment1, '/', 1) > 0 OR
                instr(v_item_segment1, '\', 1) > 0 OR
                instr(v_item_segment1, '''', 1) > 0 OR
                instr(v_item_segment1, '"', 1) > 0 OR
                instr(v_item_segment1, '|', 1) > 0 OR
                instr(v_item_segment1, '{', 1) > 0 OR
                instr(v_item_segment1, '}', 1) > 0 OR
                instr(v_item_segment1, '[', 1) > 0 OR
                instr(v_item_segment1, ']', 1) > 0 THEN
            v_invalid_record_counter := v_invalid_record_counter + 1;
            fnd_file.put_line(fnd_file.output,
                              'Invalid Record #' || v_fetched_rows_counter ||
                              ' --- forbidden character in Item Code ''' ||
                              v_item_segment1 || '''');
            ----DBMS_OUTPUT.put_line('Invalid Record #'||v_fetched_rows_counter||' --- forbidden character in Item Code '''||v_item_segment1||'''');
            RAISE invalid_record;
          END IF;
          v_step := 'Step 40';
          IF v_organization_code IS NULL THEN
            v_invalid_record_counter := v_invalid_record_counter + 1;
            fnd_file.put_line(fnd_file.output,
                              'Invalid Record #' || v_fetched_rows_counter ||
                              ' --- missing Organization Code');
            ----DBMS_OUTPUT.put_line('Invalid Record #'||v_fetched_rows_counter||' --- missing Organization Code');
            RAISE invalid_record;
          ELSE
            ----
            BEGIN
              SELECT mp.organization_id
                INTO v_organization_id
                FROM mtl_parameters mp
               WHERE mp.organization_code = v_organization_code;
            EXCEPTION
              WHEN no_data_found THEN
                v_invalid_record_counter := v_invalid_record_counter + 1;
                fnd_file.put_line(fnd_file.output,
                                  'Invalid Record #' ||
                                  v_fetched_rows_counter ||
                                  ' --- Organization ''' ||
                                  v_organization_code ||
                                  ''' does not exist (in mtl_parameters table)');
                ---DBMS_OUTPUT.put_line('Invalid Record #'||v_fetched_rows_counter||
                ---                                   ' --- Organization '''||v_organization_code||
                ---                                   ''' does not exist (in mtl_parameters table)');
                RAISE invalid_record;
            END;
            -----
          END IF;
          v_step := 'Step 50';
          BEGIN
            SELECT msi.inventory_item_id
              INTO v_inventory_item_id
              FROM mtl_system_items_b msi
             WHERE msi.segment1 = v_item_segment1
               AND msi.organization_id = v_organization_id;
          EXCEPTION
            WHEN no_data_found THEN
              v_invalid_record_counter := v_invalid_record_counter + 1;
              fnd_file.put_line(fnd_file.output,
                                'Invalid Record #' ||
                                v_fetched_rows_counter || ' --- Item ''' ||
                                v_item_segment1 ||
                                ''' does not exist in Organization ''' ||
                                v_organization_code || ''' (' ||
                                v_organization_id || ')');
              ---DBMS_OUTPUT.put_line('Invalid Record #'||v_fetched_rows_counter||
              ---                                       ' --- Item '''||v_item_segment1||
              ---                                       ''' does not exist in Organization '''||v_organization_code||''' ('||
              ---                                        v_organization_id||')');
              v_inventory_item_id := NULL;
              v_organization_id   := NULL;
              RAISE invalid_record;
          END;
        
          v_step := 'Step 60';
          IF v_list_price_per_unit_str IS NULL THEN
            v_invalid_record_counter := v_invalid_record_counter + 1;
            fnd_file.put_line(fnd_file.output,
                              'Invalid Record #' || v_fetched_rows_counter ||
                              ' --- missing List Price Per Unit');
            ----DBMS_OUTPUT.put_line('Invalid Record #'||v_fetched_rows_counter||' --- missing List Price Per Unit');
            RAISE invalid_record;
          ELSE
            ----
            BEGIN
              v_list_price_per_unit := to_number(v_list_price_per_unit_str);
              IF nvl(v_list_price_per_unit, 1) < 0 THEN
                v_invalid_record_counter := v_invalid_record_counter + 1;
                fnd_file.put_line(fnd_file.output,
                                  'Invalid Record #' ||
                                  v_fetched_rows_counter ||
                                  ' --- List Price Per Unit should be positive value');
                ---DBMS_OUTPUT.put_line('Invalid Record #'||v_fetched_rows_counter||
                ---                                   ' --- List Price Per Unit should be positive value');
                RAISE invalid_record;
              END IF;
            EXCEPTION
              WHEN OTHERS THEN
                v_invalid_record_counter := v_invalid_record_counter + 1;
                fnd_file.put_line(fnd_file.output,
                                  'Invalid Record #' ||
                                  v_fetched_rows_counter ||
                                  ' --- List Price Per Unit should be numeric value');
                ---DBMS_OUTPUT.put_line('Invalid Record #'||v_fetched_rows_counter||
                ---                                       ' --- List Price Per Unit should be numeric value');
                RAISE invalid_record;
            END;
            -----
          END IF;
        
          v_step := 'Step 200';
          ----API update item
          ---t_item_rec.item_number                := v_item_segment1;
          ---t_item_rec.segment1                   := v_item_segment1;
          t_item_rec.inventory_item_id := v_inventory_item_id;
          -----t_item_rec.description                := v_item_description;
          t_item_rec.organization_id := v_organization_id;
          ----t_item_rec.long_description           := nvl(cur_item.item_detail,fnd_api.g_miss_char);
          ----t_item_rec.primary_uom_code           := l_uom;
          ----t_item_rec.primary_unit_of_measure    := l_unit_of_measure;
          ----t_item_rec.inventory_item_status_code := l_inventory_status_code;
          ----t_item_rec.item_catalog_group_id      := nvl(v_cat_group_id,fnd_api.g_miss_num);
          ----t_item_rec.shelf_life_code            := nvl(l_shelf_life_code,fnd_api.g_miss_num);
          ----t_item_rec.shelf_life_days            := nvl(cur_item.shelf_life_days,fnd_api.g_miss_num);
          ------------ASK---ERROR INV_IOI_MASTER_CHILD_1A ------ first determine which of the effected attributes (buyer_id) are controlled at the master level for your company.
          --------------------t_item_rec.buyer_id                   := nvl(v_buyer_id      ,fnd_api.g_miss_num);
          ----t_item_rec.planner_code               := nvl(v_planner_code  ,fnd_api.g_miss_char);
          ----t_item_rec.min_minmax_quantity        := nvl(v_min_qty       ,fnd_api.g_miss_num);
          ----t_item_rec.max_minmax_quantity        := nvl(v_max_qty       ,fnd_api.g_miss_num);
          ----t_item_rec.minimum_order_quantity     := nvl(v_min_order_qty ,fnd_api.g_miss_num);
          ----t_item_rec.maximum_order_quantity     := nvl(v_max_order_qty ,fnd_api.g_miss_num);
          ----t_item_rec.preprocessing_lead_time    := nvl(cur_item.pre_proc_lead_time,fnd_api.g_miss_num);
          ----t_item_rec.full_lead_time             := nvl(cur_item.processing_lead_time,fnd_api.g_miss_num);
          ----t_item_rec.postprocessing_lead_time   := nvl(cur_item.pre_proc_lead_time,fnd_api.g_miss_num);
          ----t_item_rec.fixed_lead_time            := nvl(cur_item.fixed_lt_prod,fnd_api.g_miss_num);
          t_item_rec.list_price_per_unit := nvl(v_list_price_per_unit,
                                                fnd_api.g_miss_num);
          ----t_item_rec.fixed_order_quantity       := nvl(cur_item.fixed_order_qty,fnd_api.g_miss_num);
          ----t_item_rec.fixed_days_supply          := nvl(cur_item.fixed_days_supply,fnd_api.g_miss_num);
          ----t_item_rec.fixed_lot_multiplier       := nvl(v_fixed_lot_multiplier,fnd_api.g_miss_num);
          ----t_item_rec.receiving_routing_id       := nvl(l_receiving_routing_id,fnd_api.g_miss_num);
          ----t_item_rec.receipt_required_flag      := nvl(cur_item.receipt_required_flag,fnd_api.g_miss_char);
          ----t_item_rec.inspection_required_flag   := nvl(cur_item.inspection_required_flag,fnd_api.g_miss_char);
          ----t_item_rec.unit_weight                := nvl(cur_item.unit_weight,fnd_api.g_miss_num);
          ----t_item_rec.weight_uom_code            := nvl(cur_item.weight_uom_code.g_miss_char);
          ----t_item_rec.shrinkage_rate             := nvl(cur_item.shrinkage_rate,fnd_api.g_miss_num);
          ----t_item_rec.wip_supply_type            := nvl(l_supply_type,fnd_api.g_miss_num);
          ----t_item_rec.cost_of_sales_account      := nvl(l_cogs_id,fnd_api.g_miss_num);
          ----t_item_rec.sales_account              := nvl(l_sales_account_id,fnd_api.g_miss_num);                                                
          ----t_item_rec.planning_make_buy_code     := l_plan_make_buy;
          ----t_item_rec.attribute2                 := l_country_code;
          ----t_item_rec.attribute3                 := cur_item.hs_no;
          ----t_item_rec.attribute4                 := cur_item.exp_min_month_il;
          ----t_item_rec.attribute5                 := cur_item.exp_min_month_eu;
          ----t_item_rec.attribute6                 := cur_item.exp_min_month_usa;
          ----t_item_rec.attribute7                 := cur_item.min_exp_month_il_cust;
          ----t_item_rec.attribute8                 := l_qa_desc;
          ----t_item_rec.attribute9                 := cur_item.s_related_item;
          ----t_item_rec.attribute11 := cur_item.repairable;
          ----t_item_rec.attribute12 := cur_item.returnable;
          ----t_item_rec.attribute13 := (CASE WHEN cur_item.rohs = 'Y' THEN 'Yes' WHEN cur_item.rohs = 'N' THEN 'No' ELSE cur_item.rohs END);
          ----t_item_rec.attribute14 := cur_item.abc_class;
          ----t_item_rec.attribute16 := cur_item.part_spec_19;
          ----t_item_rec.attribute17 := cur_item.toxic_qty_allowed;
          ----t_item_rec.attribute18 := cur_item.formula;
          ----t_item_rec.attribute19 := cur_item.s_m;
        
          ----t_rev_rec.transaction_type := ego_item_pub.g_ttype_create;
          ----t_rev_rec.item_number      := upper(cur_item.item_code);
          ----t_rev_rec.organization_id  := organization_rec.organization_id;  -----cur_item.organization_id;
          ----t_rev_rec.revision_code    := cur_item.revision;
        
          -----DBMS_OUTPUT.put_line('before API');
        
          v_step := 'Step 210';
          inv_item_grp.update_item(p_commit           => fnd_api.g_false,
                                   p_validation_level => fnd_api.g_valid_level_full,
                                   p_item_rec         => t_item_rec,
                                   x_item_rec         => t_item_rec_out,
                                   x_return_status    => l_return_status,
                                   x_error_tbl        => l_error_tbl);
          ---p_template_id      => l_template_id,
          ---p_template_name    => cur_item.item_template_name,
          ---p_revision_rec     => t_rev_rec);
        
          v_step    := 'Step 220';
          l_err_msg := NULL;
          IF l_return_status != 'S' THEN
            -- ROLLBACK TO begin_mass_update;
          
            -- error_handler.get_message_list(x_message_list => l_error_tbl);
            v_items_updating_failure := v_items_updating_failure + 1;
            l_err_msg                := NULL;
            FOR i IN 1 .. l_error_tbl.count LOOP
              l_err_msg := l_err_msg || l_error_tbl(i).message_text ||
                           chr(10);
            
            END LOOP;
            fnd_file.put_line(fnd_file.output,
                              '======Record #' || v_fetched_rows_counter ||
                              ' --- Item ''' || v_item_segment1 ||
                              ''' ,Organization ''' || v_organization_code ||
                              ''' (' || v_organization_id ||
                              ') -- API Error: ' || l_err_msg);
            ---DBMS_OUTPUT.put_line('======Record #'||v_fetched_rows_counter||
            ---                                        ' --- Item '''||v_item_segment1||
            ---                                        ''' ,Organization '''||v_organization_code||''' ('||
            ---                                         v_organization_id||') -- API Error: '||l_err_msg);   
            RAISE invalid_record;
          
          END IF;
          v_items_updated_successfuly := v_items_updated_successfuly + 1;
        
        EXCEPTION
          WHEN invalid_record THEN
            NULL;
        END;
        ---------
      END IF; -- IF v_read_code <> 0
    
      IF MOD(v_items_updated_successfuly, 100) = 0 THEN
        ---commit for each 100 items
        COMMIT;
      END IF;
    
    END LOOP;
  
    COMMIT;
  
    v_step := 'Step 230';
    fnd_file.put_line(fnd_file.output, ' '); --empty record
    fnd_file.put_line(fnd_file.output, ' '); --empty record
    fnd_file.put_line(fnd_file.output,
                      '========= Procedure XXCONV_ITEMS_PKG.UPDATE_SSYS_ITEM_LIST_PRICE was completed Successfuly (see results below) =================');
    fnd_file.put_line(fnd_file.output,
                      '========= There are ' ||
                      to_char(v_fetched_rows_counter - 1) ||
                      ' records (exclude first headers record) in file ' ||
                      p_location || '/' || p_file_name);
    fnd_file.put_line(fnd_file.output,
                      '========= ' || v_invalid_record_counter ||
                      ' records are invalid');
    fnd_file.put_line(fnd_file.output,
                      '========= ' || v_items_updated_successfuly ||
                      ' items were updated successfuly');
    fnd_file.put_line(fnd_file.output,
                      '========= ' || v_items_updating_failure ||
                      ' items updating failured');
  
    ---DBMS_OUTPUT.put_line('Procedure XXCONV_ITEMS_PKG.UPDATE_SSYS_ITEM_LIST_PRICE was completed Successfuly'); 
    ---DBMS_OUTPUT.put_line('There are '||v_fetched_rows_counter||' records (exclude first headers record) in file '||p_location||'/'|| p_file_name); 
    ---DBMS_OUTPUT.put_line(v_invalid_record_counter||' records are invalid'); 
    ---DBMS_OUTPUT.put_line(v_items_updated_successfuly||' items were updated successfuly'); 
    ---DBMS_OUTPUT.put_line(v_items_updating_failure||' items updating failured'); 
  
  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.output,
                        '=======Unexpected ERROR in update_ssys_item proc. ' ||
                        v_step || ' ---' || SQLERRM);
      ---DBMS_OUTPUT.put_line('=======Unexpected ERROR in update_ssys_item proc. '||v_step||' ---'||sqlerrm); 
      retcode := '2';
      errbuf  := '=======Unexpected ERROR in XXCONV_ITEMS_PKG.UPDATE_SSYS_ITEM_LIST_PRICE proc. ' ||
                 v_step || ' ---' || SQLERRM;
  END update_ssys_item_list_price;
  ------------------------------------------------------------------------------------  
  -- update_item_org_attributes
  --------------------------------------------------------------------------
  -- Perpose: update org attributes from interface table
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --     1.0  1.6.13   vitaly       Initial Build CR727
  ----------------------------------------------------------------------------
  PROCEDURE update_item_org_attributes(errbuf  OUT VARCHAR2,
                                       retcode OUT VARCHAR2) IS
  
    CURSOR get_items_for_upd_attr IS
      SELECT *
        FROM xxobjt_conv_item_org_attribute ci
       WHERE ci.status_code = 'N'
         AND ci.item_code IS NOT NULL
         AND ci.inv_organization_code IS NOT NULL
       ORDER BY ci.item_code;
  
    v_step    VARCHAR2(100);
    v_user_id NUMBER;
  
    t_item_rec     inv_item_grp.item_rec_type;
    t_item_rec_out inv_item_grp.item_rec_type;
    --t_rev_rec      inv_item_grp.item_revision_rec_type;
    --l_error_tbl    error_handler.error_tbl_type;
    l_error_tbl     inv_item_grp.error_tbl_type;
    l_return_status VARCHAR2(1);
    l_err_msg       VARCHAR2(5000);
  
    v_items_updated_success_cntr  NUMBER := 0;
    v_items_updating_failure_cntr NUMBER := 0;
    -------------------------------
    v_inventory_item_id      NUMBER;
    v_inv_organization_id    NUMBER;
    v_source_type            NUMBER;
    v_source_organization_id NUMBER;
    --------------------------------
    invalid_record EXCEPTION;
  
  BEGIN
  
    v_step  := 'Step 0';
    retcode := '0';
    errbuf  := NULL;
  
    ------ Apps Initialize ---------
    v_step := 'Step 10';
    BEGIN
      SELECT user_id
        INTO v_user_id
        FROM fnd_user
       WHERE user_name = 'CONVERSION';
      fnd_global.apps_initialize(v_user_id,
                                 resp_id      => 51057, ----INV Catalog User
                                 resp_appl_id => 401);
    EXCEPTION
      WHEN no_data_found THEN
        errbuf  := 'Invalid User';
        retcode := '2';
    END;
    -----------VALIDATIONS---------
    v_step := 'Step 20';
    UPDATE xxobjt_conv_item_org_attribute ci
       SET ci.status_code      = 'E',
           ci.error_message    = 'Missing item',
           ci.last_update_date = SYSDATE
     WHERE ci.status_code IS NOT NULL
       AND ci.status_code <> 'E'
       AND ci.status_code <> 'S'
       AND ci.item_code IS NULL;
  
    v_step := 'Step 20.2';
    UPDATE xxobjt_conv_item_org_attribute ci
       SET ci.status_code      = 'E',
           ci.error_message    = 'Invalid item',
           ci.last_update_date = SYSDATE
     WHERE ci.status_code IS NOT NULL
       AND ci.status_code <> 'E'
       AND ci.status_code <> 'S'
       AND ci.item_code IS NOT NULL
       AND NOT EXISTS (SELECT 1
              FROM mtl_system_items_b msi
             WHERE msi.organization_id = 91 --master
               AND msi.segment1 = ci.item_code);
  
    v_step := 'Step 20.3';
    UPDATE xxobjt_conv_item_org_attribute ci
       SET ci.status_code      = 'E',
           ci.error_message    = 'Missing inventory organization',
           ci.last_update_date = SYSDATE
     WHERE ci.status_code IS NOT NULL
       AND ci.status_code <> 'E'
       AND ci.status_code <> 'S'
       AND ci.inv_organization_code IS NULL;
  
    v_step := 'Step 20.4';
    UPDATE xxobjt_conv_item_org_attribute ci
       SET ci.status_code      = 'E',
           ci.error_message    = 'Invalid inventory organization',
           ci.last_update_date = SYSDATE
     WHERE ci.status_code IS NOT NULL
       AND ci.status_code <> 'E'
       AND ci.status_code <> 'S'
       AND ci.inv_organization_code IS NOT NULL
       AND NOT EXISTS
     (SELECT 1
              FROM mtl_parameters mp
             WHERE mp.organization_code = ci.inv_organization_code);
  
    v_step := 'Step 20.5';
    UPDATE xxobjt_conv_item_org_attribute ci
       SET ci.status_code      = 'E',
           ci.error_message    = 'Missing source organization',
           ci.last_update_date = SYSDATE
     WHERE ci.status_code IS NOT NULL
       AND ci.status_code <> 'E'
       AND ci.status_code <> 'S'
       AND ci.source_organization_code IS NULL;
  
    v_step := 'Step 20.6';
    UPDATE xxobjt_conv_item_org_attribute ci
       SET ci.status_code      = 'E',
           ci.error_message    = 'Invalid source organization',
           ci.last_update_date = SYSDATE
     WHERE ci.status_code IS NOT NULL
       AND ci.status_code <> 'E'
       AND ci.status_code <> 'S'
       AND ci.source_organization_code IS NOT NULL
       AND NOT EXISTS
     (SELECT 1
              FROM mtl_parameters mp
             WHERE mp.organization_code = ci.source_organization_code);
  
    v_step := 'Step 20.7';
    UPDATE xxobjt_conv_item_org_attribute ci
       SET ci.status_code      = 'E',
           ci.error_message    = 'Missing source type',
           ci.last_update_date = SYSDATE
     WHERE ci.status_code IS NOT NULL
       AND ci.status_code <> 'E'
       AND ci.status_code <> 'S'
       AND ci.source_type IS NULL;
  
    v_step := 'Step 20.8';
    UPDATE xxobjt_conv_item_org_attribute ci
       SET ci.status_code      = 'E',
           ci.error_message    = 'Invalid source type',
           ci.last_update_date = SYSDATE
     WHERE ci.status_code IS NOT NULL
       AND ci.status_code <> 'E'
       AND ci.status_code <> 'S'
       AND upper(ci.source_type) NOT IN
           ('INVENTORY', 'SUPPLIER', 'SUBINVENTORY');
  
    v_step := 'Step 20.9';
    UPDATE xxobjt_conv_item_org_attribute ci
       SET ci.status_code      = 'E',
           ci.error_message    = 'Negative min_minmax_quantity',
           ci.last_update_date = SYSDATE
     WHERE ci.status_code IS NOT NULL
       AND ci.status_code <> 'E'
       AND ci.status_code <> 'S'
       AND nvl(ci.min_minmax_quantity, 1) < 0;
  
    v_step := 'Step 20.10';
    UPDATE xxobjt_conv_item_org_attribute ci
       SET ci.status_code      = 'E',
           ci.error_message    = 'Negative max_minmax_quantity',
           ci.last_update_date = SYSDATE
     WHERE ci.status_code IS NOT NULL
       AND ci.status_code <> 'E'
       AND ci.status_code <> 'S'
       AND nvl(ci.max_minmax_quantity, 1) < 0;
  
    v_step := 'Step 20.11';
    UPDATE xxobjt_conv_item_org_attribute ci
       SET ci.status_code      = 'E',
           ci.error_message    = 'max_minmax_quantity should be greater or equel to min_minmax_quantity',
           ci.last_update_date = SYSDATE
     WHERE ci.status_code IS NOT NULL
       AND ci.status_code <> 'E'
       AND ci.status_code <> 'S'
       AND nvl(ci.min_minmax_quantity, 0) >
           nvl(ci.max_minmax_quantity, 1000000);
  
    v_step := 'Step 20.12';
    UPDATE xxobjt_conv_item_org_attribute ci
       SET ci.status_code      = 'E',
           ci.error_message    = 'Negative min_order_qty',
           ci.last_update_date = SYSDATE
     WHERE ci.status_code IS NOT NULL
       AND ci.status_code <> 'E'
       AND ci.status_code <> 'S'
       AND nvl(ci.min_order_qty, 1) < 0;
  
    v_step := 'Step 20.13';
    UPDATE xxobjt_conv_item_org_attribute ci
       SET ci.status_code      = 'E',
           ci.error_message    = 'Negative fixed_lot_multiplier',
           ci.last_update_date = SYSDATE
     WHERE ci.status_code IS NOT NULL
       AND ci.status_code <> 'E'
       AND ci.status_code <> 'S'
       AND nvl(ci.fixed_lot_multiplier, 1) < 0;
    ---------the end of validations----------------
    COMMIT;
  
    v_step                        := 'Step 30';
    v_items_updated_success_cntr  := 0;
    v_items_updating_failure_cntr := 0;
    l_error_tbl.delete;
  
    --------------UPDATE ORG ITEM ATTRIBUTES -------------
    v_step                        := 'Step 50';
    v_items_updated_success_cntr  := 0;
    v_items_updating_failure_cntr := 0;
    FOR item_rec IN get_items_for_upd_attr LOOP
      dbms_output.put_line( ----'start item: ''' || 
                           item_rec.item_code || ''', ''' ||
                           item_rec.inv_organization_code || '''');
      ------
      BEGIN
        v_step := 'Step 50.2';
        ----
        BEGIN
          SELECT mp.organization_id
            INTO v_inv_organization_id
            FROM mtl_parameters mp
           WHERE mp.organization_code = item_rec.inv_organization_code;
        EXCEPTION
          WHEN no_data_found THEN
            v_inv_organization_id := NULL;
            l_err_msg             := 'Inv Organization ''' ||
                                     item_rec.inv_organization_code ||
                                     ''' does not exist (in mtl_parameters table)';
            fnd_file.put_line(fnd_file.output, l_err_msg);
            RAISE invalid_record;
        END;
        -----
      
        v_step := 'Step 50.3';
        ----
        BEGIN
          SELECT mp.organization_id
            INTO v_source_organization_id
            FROM mtl_parameters mp
           WHERE mp.organization_code = item_rec.source_organization_code;
        EXCEPTION
          WHEN no_data_found THEN
            v_source_organization_id := NULL;
            l_err_msg                := 'Source Organization ''' ||
                                        item_rec.source_organization_code ||
                                        ''' does not exist (in mtl_parameters table)';
            fnd_file.put_line(fnd_file.output, l_err_msg);
            RAISE invalid_record;
        END;
        -----
      
        v_step := 'Step 50.4';
        -------
        BEGIN
          SELECT msi.inventory_item_id
            INTO v_inventory_item_id
            FROM mtl_system_items_b msi
           WHERE msi.segment1 = item_rec.item_code
             AND msi.organization_id = v_inv_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            l_err_msg := 'Item ''' || item_rec.item_code ||
                         ''' does not exist in Organization ' ||
                         v_inv_organization_id;
            fnd_file.put_line(fnd_file.output, l_err_msg);
            v_inventory_item_id   := NULL;
            v_inv_organization_id := NULL;
            RAISE invalid_record;
        END;
        --------
      
        v_step := 'Step 50.5';
        SELECT decode(upper(item_rec.source_type),
                      'INVENTORY',
                      1,
                      'SUPPLIER',
                      2,
                      'SUBINVENTORY',
                      3,
                      NULL)
          INTO v_source_type
          FROM dual;
      
        v_step := 'Step 60';
        ----API ----------------------update org item attributes
        t_item_rec                   := inv_item_grp.g_miss_item_rec;
        t_item_rec_out               := inv_item_grp.g_miss_item_rec;
        t_item_rec.inventory_item_id := v_inventory_item_id;
        t_item_rec.organization_id   := v_inv_organization_id;
      
        t_item_rec.inventory_planning_code := 2; -- Planned
        t_item_rec.source_type             := nvl(v_source_type,
                                                  fnd_api.g_miss_num);
        t_item_rec.source_organization_id  := nvl(v_source_organization_id,
                                                  fnd_api.g_miss_num);
        -----t_item_rec.source_subinventory     := fnd_api.g_miss_char;   
      
        t_item_rec.min_minmax_quantity    := nvl(item_rec.min_minmax_quantity,
                                                 fnd_api.g_miss_num);
        t_item_rec.max_minmax_quantity    := nvl(item_rec.max_minmax_quantity,
                                                 fnd_api.g_miss_num);
        t_item_rec.minimum_order_quantity := nvl(item_rec.min_order_qty,
                                                 fnd_api.g_miss_num);
        -----t_item_rec.maximum_order_quantity := nvl(v_max_order_qty,fnd_api.g_miss_num);      
        t_item_rec.fixed_lot_multiplier := nvl(item_rec.fixed_lot_multiplier,
                                               fnd_api.g_miss_num);
      
        v_step := 'Step 60.2';
        inv_item_grp.update_item(p_commit           => fnd_api.g_false,
                                 p_validation_level => fnd_api.g_valid_level_full,
                                 p_item_rec         => t_item_rec,
                                 x_item_rec         => t_item_rec_out,
                                 x_return_status    => l_return_status,
                                 x_error_tbl        => l_error_tbl);
        v_step    := 'Step 60.3';
        l_err_msg := NULL;
        IF l_return_status != 'S' THEN
          -- error_handler.get_message_list(x_message_list => l_error_tbl);
          v_items_updating_failure_cntr := v_items_updating_failure_cntr + 1;
          l_err_msg                     := NULL;
          FOR i IN 1 .. l_error_tbl.count LOOP
            v_step := 'Step 60.33';
            ---l_err_msg := l_err_msg || l_error_tbl(i).message_text;
            dbms_output.put_line('Item=''' || item_rec.item_code ||
                                 ''' , organization=''' ||
                                 item_rec.inv_organization_code ||
                                 '''---ERROR: ' || l_error_tbl(i)
                                 .message_text);
          END LOOP;
          /*fnd_file.put_line(fnd_file.output,
          'Item ''' || item_rec.item_code ||
          ''' ,Organization ' || v_inv_organization_id ||
          ' -- API Error: ' || l_err_msg);*/
          ---dbms_output.put_line('API ERROR');
          RAISE invalid_record;
        END IF;
        ---dbms_output.put_line('API SUCCESS');
        v_items_updated_success_cntr := v_items_updated_success_cntr + 1;
        UPDATE xxobjt_conv_item_org_attribute ci
           SET ci.status_code = 'S', ci.last_update_date = SYSDATE
         WHERE ci.item_code = item_rec.item_code
           AND ci.inv_organization_code = item_rec.inv_organization_code;
        ---------
      
        IF MOD(v_items_updated_success_cntr, 100) = 0 THEN
          ---commit for each 100 items
          COMMIT;
        END IF;
      EXCEPTION
        WHEN invalid_record THEN
          v_step := 'Step 1000';
          dbms_output.put_line('ERROR: Invalid record: ''' ||
                               item_rec.item_code || ''', ''' ||
                               item_rec.inv_organization_code || '''');
          UPDATE xxobjt_conv_item_org_attribute ci
             SET ci.status_code      = 'E',
                 ci.error_message    = substr(l_err_msg, 1, 2000),
                 ci.last_update_date = SYSDATE
           WHERE ci.item_code = item_rec.item_code
             AND ci.inv_organization_code = item_rec.inv_organization_code;
      END;
      -----------------------
    END LOOP;
  
    COMMIT;
  
    v_step := 'Step 230';
    fnd_file.put_line(fnd_file.output, ' '); --empty record
    fnd_file.put_line(fnd_file.output, ' '); --empty record
    fnd_file.put_line(fnd_file.output,
                      '========= Procedure XXCONV_ITEMS_PKG.UPDATE_ITEM_ORG_ATTRIBUTES was completed Successfuly (see results below) =================');
    fnd_file.put_line(fnd_file.output,
                      '========= ' || v_items_updated_success_cntr ||
                      ' items were updated successfuly');
    fnd_file.put_line(fnd_file.output,
                      '========= ' || v_items_updating_failure_cntr ||
                      ' items updating failured');
  
    dbms_output.put_line(v_items_updated_success_cntr ||
                         ' items were updated successfuly');
    dbms_output.put_line(v_items_updating_failure_cntr ||
                         ' items updating failured');
  
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      fnd_file.put_line(fnd_file.output,
                        '=======Unexpected ERROR in xxconv_items_pkg.update_item_org_attributes ' ||
                        v_step || ' ---' || SQLERRM);
      retcode := '2';
      errbuf  := 'Unexpected ERROR in xxconv_items_pkg.update_item_org_attributes ' ||
                 v_step || ' ---' || SQLERRM;
  END update_item_org_attributes;
  ----------------------------------------------------------------------------
  -- copy_item_revisions
  -- (CR810)
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --  1.3   12.6.13    vitaly           copy_item_revisions added         (CR810)
  PROCEDURE copy_item_revisions(errbuf               OUT VARCHAR2,
                                retcode              OUT VARCHAR2,
                                p_to_organization_id IN NUMBER,
                                p_inventory_item_id  IN NUMBER) IS
  
    v_error_messsage VARCHAR2(5000);
    stop_processing EXCEPTION;
    v_user_id                     NUMBER;
    v_step                        VARCHAR2(100);
    v_num_of_success_copied_items NUMBER;
    v_num_of_failure_items        NUMBER;
    l_tmp                         VARCHAR2(50);
  
    l_msg_data      VARCHAR2(5000);
    l_data          VARCHAR2(5000);
    l_return_status VARCHAR2(50);
    l_msg_count     NUMBER;
  
    l_msg_index_out NUMBER;
    ---l_object_version_number NUMBER;
    ---l_item_revision_rec     inv_item_revision_pub.item_revision_rec_type;
    CURSOR c_items IS
      SELECT *
        FROM (SELECT t.*
                FROM mtl_item_revisions_vl t, mtl_system_items_b msi
               WHERE msi.inventory_item_id = t.inventory_item_id
                 AND msi.organization_id = p_to_organization_id ---param 
                 AND t.organization_id = 91 --Master
                 AND msi.inventory_item_id =
                     nvl(p_inventory_item_id, msi.inventory_item_id) ---param
                    --- for debug only
                    -----AND msi.inventory_item_id = 14770
                 AND NOT EXISTS
               (SELECT 1
                        FROM mtl_item_revisions_vl xx
                       WHERE xx.organization_id = p_to_organization_id --param
                         AND xx.inventory_item_id = t.inventory_item_id
                         AND xx.revision = t.revision)
               ORDER BY t.inventory_item_id, t.implementation_date);
  
    CURSOR item_revision_exists_cur(p_inventory_item_id NUMBER,
                                    p_organization_id   NUMBER,
                                    p_revision          VARCHAR2) IS
      SELECT object_version_number
        FROM mtl_item_revisions_b
       WHERE inventory_item_id = p_inventory_item_id
         AND organization_id = p_organization_id
         AND revision = p_revision;
  
  BEGIN
  
    v_step  := 'Step 0';
    retcode := '0';
    errbuf  := 'Success';
  
    fnd_msg_pub.delete_msg;
  
    fnd_file.put_line(fnd_file.log,
                      '========= Start =======================================  ');
    ---*****parameters******
    fnd_file.put_line(fnd_file.log,
                      '=========Parameter p_to_organization_id=' ||
                      p_to_organization_id);
    fnd_file.put_line(fnd_file.log,
                      '=========Parameter p_inventory_item_id=' ||
                      p_inventory_item_id);
  
    IF p_to_organization_id = 91 THEN
      v_error_messsage := ' Error: You cannot copy item revisions to Master organization';
      RAISE stop_processing;
    END IF;
  
    fnd_file.put_line(fnd_file.log, ''); --empty record
  
    ----*******************
  
    ----================ INITIALIZE ================
    v_step := 'Step 10';
    BEGIN
      SELECT user_id
        INTO v_user_id
        FROM fnd_user
       WHERE user_name = 'CONVERSION';
      fnd_global.apps_initialize(v_user_id,
                                 resp_id      => 51057, ----INV Catalog User
                                 resp_appl_id => 401);
    EXCEPTION
      WHEN no_data_found THEN
        errbuf  := 'Invalid User';
        retcode := '2';
    END;
  
    v_step                        := 'Step 20';
    v_num_of_success_copied_items := 0;
    v_num_of_failure_items        := 0;
    FOR i IN c_items LOOP
      v_step := 'Step 30';
      l_tmp  := NULL;
      OPEN item_revision_exists_cur(i.inventory_item_id,
                                    p_to_organization_id,
                                    i.revision);
      FETCH item_revision_exists_cur
        INTO l_tmp;
      CLOSE item_revision_exists_cur;
    
      IF l_tmp IS NULL THEN
        v_step := 'Step 40';
        -- Call the procedure
        ego_item_pub.process_item_revision(p_api_version        => 1,
                                           p_init_msg_list      => fnd_api.g_true,
                                           p_commit             => fnd_api.g_false,
                                           p_transaction_type   => 'CREATE',
                                           p_inventory_item_id  => i.inventory_item_id,
                                           p_item_number        => ego_item_pub.g_miss_char,
                                           p_organization_id    => p_to_organization_id,
                                           p_organization_code  => ego_item_pub.g_miss_char,
                                           p_revision           => i.revision,
                                           p_description        => i.description,
                                           p_effectivity_date   => SYSDATE, -- i.effectivity_date,
                                           p_revision_label     => i.revision_label,
                                           p_revision_reason    => i.revision_reason,
                                           p_lifecycle_id       => i.lifecycle_id,
                                           p_current_phase_id   => i.current_phase_id,
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
                                           x_return_status      => l_return_status,
                                           x_msg_count          => l_msg_count,
                                           x_msg_data           => l_msg_data);
        dbms_lock.sleep(1);
        v_step := 'Step 50';
      
        /*  fnd_file.put_line(fnd_file.log,
        'l_return_status=' || l_return_status);*/
      
        IF l_return_status IN ('0', 'S') THEN
          ----SUCCESS----
          v_num_of_success_copied_items := v_num_of_success_copied_items + 1;
        ELSE
          v_step := 'Step 60';
          ----ERROR-----
          v_num_of_failure_items := v_num_of_failure_items + 1;
          fnd_file.put_line(fnd_file.log,
                            '**** inv_item_id=' || i.inventory_item_id ||
                            ', rev=' || i.revision ||
                            '***** API ERROR *****' || l_return_status);
          IF l_msg_count IS NOT NULL THEN
            FOR i IN 1 .. l_msg_count LOOP
            
              fnd_msg_pub.get(p_msg_index     => i,
                              p_data          => l_data,
                              p_encoded       => fnd_api.g_false,
                              p_msg_index_out => l_msg_index_out);
            
              fnd_file.put_line(fnd_file.log,
                                ' Debug ' || substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
                                                    1,
                                                    255));
              fnd_file.put_line(fnd_file.log, 'l_data=' || l_data);
            END LOOP;
          END IF;
          -- RAISE l_exception;
        END IF;
      
      ELSE
        NULL;
        /*dbms_output.put_line('exists');*/
        fnd_file.put_line(fnd_file.log,
                          '**** inv_item_id=' || i.inventory_item_id || ' ' ||
                          i.revision ||
                          '***** Already exists in organization_id=' ||
                          p_to_organization_id || ' ****');
      END IF;
      IF MOD(c_items%ROWCOUNT, 100) = 0 THEN
        COMMIT;
      END IF;
    END LOOP;
    COMMIT;
    ---------------------------
  
    fnd_file.put_line(fnd_file.log,
                      '======== End ====== see results below =============  ');
    fnd_file.put_line(fnd_file.log,
                      '==== ' || v_num_of_success_copied_items ||
                      ' Items were processed SUCCESSFULLY');
    fnd_file.put_line(fnd_file.log,
                      '==== ' || v_num_of_failure_items || ' Items Failed');
  
    /*    dbms_output.put_line('======== End ====== see results below =============  ');
    dbms_output.put_line('==== ' || v_num_of_success_copied_items ||
                         ' Items were processed SUCCESSFULLY');
    dbms_output.put_line('==== ' || v_num_of_failure_items ||
                         ' Items Failed');*/
  
  EXCEPTION
    WHEN stop_processing THEN
      v_error_messsage := 'ERROR in xxconv_items_pkg.copy_item_revisions: ' ||
                          v_error_messsage;
      fnd_file.put_line(fnd_file.log, '========= ' || v_error_messsage);
      retcode := '2';
      errbuf  := v_error_messsage;
    WHEN OTHERS THEN
      v_error_messsage := substr('Unexpected ERROR in xxconv_items_pkg.copy_item_revisions (' ||
                                 v_step || ') ' || SQLERRM,
                                 1,
                                 200);
      fnd_file.put_line(fnd_file.log, '========= ' || v_error_messsage);
      retcode := '2';
      errbuf  := v_error_messsage;
  END copy_item_revisions;
  ----------------------------------------------------------------------------
  -- copy_organization_planner  (insert into MTL_SYSTEM_ITEMS_INTERFACE)
  -- (CR810)
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --  1.0   15.8.13    vitaly           initial revision        (CR810)
  PROCEDURE copy_organization_planner(errbuf                 OUT VARCHAR2,
                                      retcode                OUT VARCHAR2,
                                      p_from_organization_id IN NUMBER,
                                      p_to_organization_id   IN NUMBER) IS
  
    CURSOR c_get_items IS
      SELECT msi_from.inventory_item_id,
             msi_from.segment1                item,
             msi_from.planner_code,
             msi_from.wip_supply_subinventory,
             mil_to.inventory_location_id     wip_supply_locator_id
        FROM mtl_system_items_b msi_from,
             mtl_system_items_b msi_to,
             mtl_item_locations_kfv mil_from,
             (SELECT a.concatenated_segments, a.inventory_location_id
                FROM mtl_item_locations_kfv a
               WHERE a.organization_id = p_to_organization_id ---parameter
              ) mil_to
       WHERE msi_from.organization_id = p_from_organization_id ---parameter
         AND msi_to.organization_id = p_to_organization_id ---parameter
         AND nvl(msi_from.wip_supply_locator_id, -777) =
             mil_from.inventory_location_id(+)
         AND nvl(msi_from.organization_id, -777) =
             mil_from.organization_id(+)
         AND nvl(mil_from.concatenated_segments, 'XXXXXXXX') =
             mil_to.concatenated_segments(+)
         AND msi_from.inventory_item_id = msi_to.inventory_item_id
         AND ((msi_from.planner_code IS NOT NULL AND
             msi_from.planner_code <> nvl(msi_to.planner_code, 'XYZ')) OR
             (msi_from.wip_supply_subinventory IS NOT NULL AND
             msi_from.wip_supply_subinventory <>
             nvl(msi_to.wip_supply_subinventory, 'XYZ')) OR
             (msi_from.wip_supply_locator_id IS NOT NULL AND
             mil_to.inventory_location_id <>
             nvl(msi_to.wip_supply_locator_id, -777)));
  
    v_step VARCHAR2(100);
    stop_processing EXCEPTION;
    invalid_record  EXCEPTION;
  
    v_error_message VARCHAR2(5000);
  
    v_inserted_interface_rec_cntr NUMBER := 0;
  
    v_from_organization_code VARCHAR2(100);
    v_to_organization_code   VARCHAR2(100);
  
  BEGIN
    v_step  := 'Step 0';
    retcode := '0';
    errbuf  := 'Success';
  
    v_step := 'Step 10';
    IF p_from_organization_id IS NULL THEN
      v_error_message := 'Error: Missing parameter p_from_organization_id';
      RAISE stop_processing;
    ELSE
      -------
      BEGIN
        SELECT mp.organization_code
          INTO v_from_organization_code
          FROM mtl_parameters mp
         WHERE mp.organization_id = p_from_organization_id; ---parameter  
      EXCEPTION
        WHEN no_data_found THEN
          v_error_message := 'Error: Invalid parameter p_from_organization_id=' ||
                             p_from_organization_id;
          RAISE stop_processing;
      END;
      -------
    END IF;
  
    v_step := 'Step 20';
    IF p_to_organization_id IS NULL THEN
      v_error_message := 'Error: Missing parameter p_to_organization_id';
      RAISE stop_processing;
    ELSE
      -------
      BEGIN
        SELECT mp.organization_code
          INTO v_to_organization_code
          FROM mtl_parameters mp
         WHERE mp.organization_id = p_to_organization_id; ---parameter  
      EXCEPTION
        WHEN no_data_found THEN
          v_error_message := 'Error: Invalid parameter p_to_organization_id=' ||
                             p_to_organization_id;
          RAISE stop_processing;
      END;
      -------
    END IF;
  
    v_step := 'Step 30';
    IF p_from_organization_id = p_to_organization_id THEN
      v_error_message := 'Error: parameter p_from_organization_id cannot be equel to p_to_organization_id';
      RAISE stop_processing;
    END IF;
  
    FOR item_rec IN c_get_items LOOP
      ---------- ITEMS LOOP ------------------
      v_step := 'Step 200';
      INSERT INTO mtl_system_items_interface
        (inventory_item_id,
         organization_id,
         process_flag,
         transaction_type,
         planner_code,
         wip_supply_subinventory,
         wip_supply_locator_id)
      VALUES
        (item_rec.inventory_item_id,
         p_to_organization_id,
         1,
         'UPDATE',
         nvl(item_rec.planner_code, fnd_api.g_miss_char),
         nvl(item_rec.wip_supply_subinventory, fnd_api.g_miss_char),
         nvl(item_rec.wip_supply_locator_id, fnd_api.g_miss_num));
      v_inserted_interface_rec_cntr := v_inserted_interface_rec_cntr + 1;
      ---------- the end of ITEMS LOOP ------------------
    END LOOP;
    COMMIT;
  
    v_step := 'Step 230';
    fnd_file.put_line(fnd_file.output,
                      '========= ' || v_inserted_interface_rec_cntr ||
                      ' records inserted into MTL_SYSTEM_ITEMS_INTERFACE ( for organization_id=' ||
                      p_to_organization_id || ')');
    fnd_file.put_line(fnd_file.output,
                      '========= PLEASE SUBMIT ''IMPORT ITEMS'' concurrent program ==============================================');
    fnd_file.put_line(fnd_file.output,
                      '========= Procedure XXCONV_ITEMS_PKG.copy_organization_planner was completed Successfuly =================');
  
  EXCEPTION
    WHEN stop_processing THEN
      fnd_file.put_line(fnd_file.output,
                        '=======ERROR in XXCONV_ITEMS_PKG.copy_organization_planner proc. ' ||
                        v_error_message);
      retcode := '2';
      errbuf  := '=======Unexpected ERROR in XXCONV_ITEMS_PKG.copy_organization_planner proc. ' ||
                 v_error_message;
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.output,
                        '=======Unexpected ERROR in XXCONV_ITEMS_PKG.copy_organization_planner proc. ' ||
                        v_step || ' ---' || SQLERRM);
      retcode := '2';
      errbuf  := '=======Unexpected ERROR in XXCONV_ITEMS_PKG.copy_organization_planner proc. ' ||
                 v_step || ' ---' || SQLERRM;
  END copy_organization_planner;
  ----------------------------------------------------------------------------
  -- copy_organization_planner2  (via API )
  -- (CR810)
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --  1.0   15.8.13    vitaly           initial revision        (CR810)
  PROCEDURE copy_organization_planner2(errbuf                 OUT VARCHAR2,
                                       retcode                OUT VARCHAR2,
                                       p_from_organization_id IN NUMBER,
                                       p_to_organization_id   IN NUMBER) IS
  
    CURSOR c_get_items IS
      SELECT msi_from.inventory_item_id,
             msi_from.segment1 item,
             msi_from.planner_code
        FROM mtl_system_items_b msi_from, mtl_system_items_b msi_to
       WHERE msi_from.organization_id = p_from_organization_id ---parameter
         AND msi_to.organization_id = p_to_organization_id ---parameter
         AND msi_from.inventory_item_id = msi_to.inventory_item_id
         AND msi_from.planner_code IS NOT NULL
         AND msi_from.planner_code <> nvl(msi_to.planner_code, 'XYZ');
    ----AND msi_from.segment1 = '1/4MEG-1501-S';
  
    v_step VARCHAR2(100);
    stop_processing EXCEPTION;
    invalid_record  EXCEPTION;
  
    t_item_rec     inv_item_grp.item_rec_type;
    t_item_rec_out inv_item_grp.item_rec_type;
    --t_rev_rec      inv_item_grp.item_revision_rec_type;
    --l_error_tbl    error_handler.error_tbl_type;
    l_error_tbl     inv_item_grp.error_tbl_type;
    l_return_status VARCHAR2(1);
    v_error_message VARCHAR2(5000);
  
    v_items_updated_successfuly NUMBER := 0;
    v_items_updating_failure    NUMBER := 0;
  
    v_from_organization_code VARCHAR2(100);
    v_to_organization_code   VARCHAR2(100);
  
  BEGIN
    v_step  := 'Step 0';
    retcode := '0';
    errbuf  := 'Success';
  
    v_step := 'Step 10';
    IF p_from_organization_id IS NULL THEN
      v_error_message := 'Error: Missing parameter p_from_organization_id';
      RAISE stop_processing;
    ELSE
      -------
      BEGIN
        SELECT mp.organization_code
          INTO v_from_organization_code
          FROM mtl_parameters mp
         WHERE mp.organization_id = p_from_organization_id; ---parameter  
      EXCEPTION
        WHEN no_data_found THEN
          v_error_message := 'Error: Invalid parameter p_from_organization_id=' ||
                             p_from_organization_id;
          RAISE stop_processing;
      END;
      -------
    END IF;
  
    v_step := 'Step 20';
    IF p_to_organization_id IS NULL THEN
      v_error_message := 'Error: Missing parameter p_to_organization_id';
      RAISE stop_processing;
    ELSE
      -------
      BEGIN
        SELECT mp.organization_code
          INTO v_to_organization_code
          FROM mtl_parameters mp
         WHERE mp.organization_id = p_to_organization_id; ---parameter  
      EXCEPTION
        WHEN no_data_found THEN
          v_error_message := 'Error: Invalid parameter p_to_organization_id=' ||
                             p_to_organization_id;
          RAISE stop_processing;
      END;
      -------
    END IF;
  
    v_step := 'Step 30';
    IF p_from_organization_id = p_to_organization_id THEN
      v_error_message := 'Error: parameter p_from_organization_id cannot be equel to p_to_organization_id';
      RAISE stop_processing;
    END IF;
  
    FOR item_rec IN c_get_items LOOP
      ---------- ITEMS LOOP ------------------
      BEGIN
        v_step := 'Step 200';
        ----API update item
        ---t_item_rec.item_number                := v_item_segment1;
        ---t_item_rec.segment1                   := v_item_segment1;
        t_item_rec.inventory_item_id := item_rec.inventory_item_id;
        -----t_item_rec.description                := v_item_description;
        t_item_rec.organization_id := p_to_organization_id;
        t_item_rec.planner_code    := nvl(item_rec.planner_code,
                                          fnd_api.g_miss_char);
      
        -----DBMS_OUTPUT.put_line('before API');
      
        v_step := 'Step 210';
        inv_item_grp.update_item(p_commit           => fnd_api.g_false,
                                 p_validation_level => fnd_api.g_valid_level_full,
                                 p_item_rec         => t_item_rec,
                                 x_item_rec         => t_item_rec_out,
                                 x_return_status    => l_return_status,
                                 x_error_tbl        => l_error_tbl);
      
        v_step          := 'Step 220';
        v_error_message := NULL;
        IF l_return_status != 'S' THEN
          -- ROLLBACK TO begin_mass_update;
        
          -- error_handler.get_message_list(x_message_list => l_error_tbl);
          v_items_updating_failure := v_items_updating_failure + 1;
          v_error_message          := NULL;
          FOR i IN 1 .. l_error_tbl.count LOOP
            v_error_message := v_error_message || l_error_tbl(i)
                              .message_text || chr(10);
          
          END LOOP;
          fnd_file.put_line(fnd_file.output,
                            ' --- Item ''' || item_rec.item ||
                            ''' ,Organization ''' || v_to_organization_code ||
                            ''' (' || p_to_organization_id ||
                            ') -- API Error: ' || v_error_message);
          ---DBMS_OUTPUT.put_line('======Record #'||v_fetched_rows_counter||
          ---                                        ' --- Item '''||v_item_segment1||
          ---                                        ''' ,Organization '''||v_organization_code||''' ('||
          ---                                         v_organization_id||') -- API Error: '||l_err_msg);   
          RAISE invalid_record;
        END IF;
        v_items_updated_successfuly := v_items_updated_successfuly + 1;
      
        IF MOD(v_items_updated_successfuly, 100) = 0 THEN
          ---commit for each 100 items
          COMMIT;
        END IF;
      
      EXCEPTION
        WHEN invalid_record THEN
          NULL;
      END;
      ---------- the end of ITEMS LOOP ------------------
    END LOOP;
  
    COMMIT;
  
    v_step := 'Step 230';
    fnd_file.put_line(fnd_file.output, ' '); --empty record
    fnd_file.put_line(fnd_file.output, ' '); --empty record
    fnd_file.put_line(fnd_file.output,
                      '========= Procedure XXCONV_ITEMS_PKG.copy_organization_planner2 was completed Successfuly (see results below) =================');
    fnd_file.put_line(fnd_file.output,
                      '========= ' || v_items_updated_successfuly ||
                      ' items were updated successfuly');
    fnd_file.put_line(fnd_file.output,
                      '========= ' || v_items_updating_failure ||
                      ' items updating failured');
  
    ---dbms_output.put_line('Procedure XXCONV_ITEMS_PKG.copy_organization_planner2 was completed Successfuly');
    ---dbms_output.put_line(v_items_updated_successfuly ||
    ---                     ' items were updated successfuly');
    ---dbms_output.put_line(v_items_updating_failure ||
    ---                     ' items updating failured');
  
  EXCEPTION
    WHEN stop_processing THEN
      fnd_file.put_line(fnd_file.output,
                        '=======ERROR in XXCONV_ITEMS_PKG.copy_organization_planner2 proc. ' ||
                        v_error_message);
      retcode := '2';
      errbuf  := '=======Unexpected ERROR in XXCONV_ITEMS_PKG.copy_organization_planner2 proc. ' ||
                 v_error_message;
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.output,
                        '=======Unexpected ERROR in XXCONV_ITEMS_PKG.copy_organization_planner2 proc. ' ||
                        v_step || ' ---' || SQLERRM);
      retcode := '2';
      errbuf  := '=======Unexpected ERROR in XXCONV_ITEMS_PKG.copy_organization_planner2 proc. ' ||
                 v_step || ' ---' || SQLERRM;
  END copy_organization_planner2;
  ------------------------------------------------------------------------------------ 
END xxconv_items_pkg;
/
