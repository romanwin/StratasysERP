CREATE OR REPLACE PACKAGE BODY xxinv_item_api IS

  --------------------------------------------------------------------
  --  name:            xxinv_item_api
  --  create by:       yuval tal
  --  Revision:        1.0
  --  ccreation date:  21.3.11 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        mass update of items according to exteranal table
  --  located at :     \\Objet-data\oracle_files\Inventory
  --  name :           ItemUpdate.csv
  --  ext table name   = XXinv_ext_mass_item_update
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  21.3.11     yuval tal       initial build
  --  1.1  27.7.11     yuval tal       CR 287:add support for updating wip_supply_type and planner
  --  1.2  4.3.12      YUVAL TAL       CR 388 : add support for COST_OF_SALES_ACCOUNT_DSP  SALES_ACCOUNT_DSP
  --  1.3  5.2.13      yuval tal       CR 674 : Massive Item Update : add SP attributes Returnable null to HQ
  --  1.4  3.9.13      yuval tal       CR 1004 nodify update_batch : add  8 attributes
  --  1.5  07/10/2014  Dalit A. RAviv  CHG0033231 - add Inventory Org to itrem att25.
  --  1.6  16-FEB-2015 Gubendran K     CHG0034563 - Addded 5 Item Fields to Inventory Update item attributes report
  --  1.4  12/07/2015  Michal Tzvik    CHG0035537 - PROCEDURE update_batch: add fields list_price_per_unit ,shrinkage_rate
  --  1.5  30.4.17     yuval tal       CHG0040441 - update_batch Cut the PO- Mass update of sourcing buyer
  --  1.6  04-Jun-2018 Dan Melamed     CHG0043127 - Add external invoker for the seeded Import Items (INCOIN)
  --  1.7 14.12.20     yuval tal       CHG0049102 - modify get_ccid, modify update_batch to work with intreface table instead of API
  --------------------------------------------------------------------

  PROCEDURE message(p_msg IN VARCHAR2) IS
    ---------------------------------
    --      Local Definition
    ---------------------------------
    l_msg VARCHAR2(2000);
    ---------------------------------
    --      Code Section
    ---------------------------------
  BEGIN
    l_msg := to_char(SYSDATE, 'YYYY-MM-DD HH24:MI:SS') || ' - ' || p_msg;
  
    IF -1 = fnd_global.conc_request_id THEN
      dbms_output.put_line(l_msg);
    ELSE
      fnd_file.put_line(fnd_file.log, l_msg);
    END IF;
  
  END message;

  ------------------------
  -- get_wip_supply_code
  -----------------------
  FUNCTION get_wip_supply_code(p_wipp_supply_name VARCHAR2) RETURN NUMBER IS
    l_tmp NUMBER;
  BEGIN
  
    SELECT flv.lookup_code
    INTO   l_tmp
    FROM   fnd_lookup_values flv
    WHERE  flv.lookup_type = 'WIP_SUPPLY'
    AND    meaning = p_wipp_supply_name
    AND    flv.language = userenv('LANG');
  
    RETURN l_tmp;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
    
  END;

  ------------------------
  -- get_item_id
  ------------------------
  FUNCTION get_item_id(p_seg             VARCHAR2,
	           p_organization_id NUMBER) RETURN NUMBER IS
    l_tmp NUMBER;
  BEGIN
  
    SELECT t.inventory_item_id
    INTO   l_tmp
    FROM   mtl_system_items_b t
    WHERE  rownum = 1
    AND    segment1 = p_seg
    AND    t.organization_id = p_organization_id;
  
    RETURN l_tmp;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
    
  END;

  ---------------------------
  -- get_CCID
  --  ver  date        name            desc
  --  1.7 14.12.20     yuval tal       CHG0049102  - support create new accounts
  ---------------------------

  FUNCTION get_ccid(p_concat_seg VARCHAR2,
	        p_org_code   VARCHAR2 DEFAULT NULL) RETURN NUMBER IS
    l_tmp         NUMBER;
    l_return_code VARCHAR2(5);
    l_err_msg     VARCHAR2(2000);
    l_coa_id      NUMBER;
  BEGIN
    BEGIN
      SELECT t.chart_of_accounts_id
      INTO   l_coa_id
      FROM   org_organization_definitions t
      WHERE  t.organization_code = nvl(p_org_code, 'OMA');
    EXCEPTION
      WHEN OTHERS THEN
        NULL;
    END;
    --   message('l_coa_id='||l_coa_id);
  
    BEGIN
      SELECT tt.code_combination_id
      INTO   l_tmp
      FROM   gl_code_combinations_kfv tt
      WHERE  tt.concatenated_segments = p_concat_seg
      AND    tt.summary_flag = 'N';
    
      RETURN l_tmp;
      --   message('p_concat_seg='||p_concat_seg);
    EXCEPTION
      -- CHG0049102
      WHEN no_data_found THEN
      
        xxgl_utils_pkg.get_and_create_account(p_concat_segment      => p_concat_seg,
			          p_coa_id              => l_coa_id,
			          p_app_short_name      => NULL,
			          x_code_combination_id => l_tmp,
			          x_return_code         => l_return_code,
			          x_err_msg             => l_err_msg);
      
        message('xxgl_utils_pkg.get_and_create_account:' || l_return_code || ' ' ||
	    l_err_msg);
        RETURN l_tmp;
    END;
  EXCEPTION
    WHEN OTHERS THEN
      message('Err:' || SQLERRM);
      RETURN NULL;
  END;

  ----------------------------
  -- get_organization_id
  ---------------------------

  FUNCTION get_organization_id(p_organization_code VARCHAR2) RETURN NUMBER IS
    l_tmp NUMBER;
  BEGIN
  
    SELECT t.organization_id
    INTO   l_tmp
    FROM   xxobjt_org_organization_def_v t
    WHERE  t.organization_code = upper(TRIM(p_organization_code));
  
    RETURN l_tmp;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END;

  --------------------------------
  -- get_buyer_id
  ---------------------------------
  FUNCTION get_buyer_id(p_full_name VARCHAR2) RETURN NUMBER IS
  
    l_tmp NUMBER;
  BEGIN
  
    SELECT t.person_id
    INTO   l_tmp
    FROM   per_all_people_f t
    WHERE  t.full_name = TRIM(p_full_name)
    AND    rownum = 1;
  
    RETURN l_tmp;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END;

  ----------------------------
  -- get_rounding_control_type
  ----------------------------
  FUNCTION get_rounding_control_type(p_rounding_control_flag VARCHAR2)
    RETURN NUMBER IS
    l_tmp NUMBER;
  BEGIN
  
    SELECT flv.lookup_code
    INTO   l_tmp
    FROM   fnd_lookup_values flv
    WHERE  flv.lookup_type = 'INV_YES_NO'
    AND    meaning = TRIM(p_rounding_control_flag)
    AND    flv.language = userenv('LANG');
  
    RETURN l_tmp;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
    
  END;

  ---------------------------
  -- get_planning_make_buy_code
  ----------------------------
  FUNCTION get_planning_make_buy_code(p_planning_make_buy_name VARCHAR2)
    RETURN NUMBER IS
    l_tmp NUMBER;
  BEGIN
  
    SELECT flv.lookup_code
    INTO   l_tmp
    FROM   fnd_lookup_values flv
    WHERE  flv.lookup_type = 'MTL_PLANNING_MAKE_BUY'
    AND    meaning = TRIM(p_planning_make_buy_name)
    AND    flv.language = userenv('LANG');
  
    RETURN l_tmp;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
    
  END;

  ---------------------------
  -- get_mrp_safety_stock_code
  ----------------------------
  FUNCTION get_mrp_safety_stock_code(p_mrp_safety_stock_name VARCHAR2)
    RETURN NUMBER IS
    l_tmp NUMBER;
  BEGIN
  
    SELECT flv.lookup_code
    INTO   l_tmp
    FROM   fnd_lookup_values flv
    WHERE  flv.lookup_type = 'MSC_SAFETY_STOCK_TYPE'
    AND    meaning = TRIM(p_mrp_safety_stock_name)
    AND    flv.language = userenv('LANG');
  
    RETURN l_tmp;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
    
  END;

  --------------------------------------------------------------------
  --  name:            update_batch
  --  create by:       yuval tal
  --  Revision:        1.0
  --  creation date:   3.9.13
  --------------------------------------------------------------------
  --  purpose :        file name  : located under oracle directory named = XX_INVENTORY_DIR
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.1  3.9.13      yuval tal       CR 1004 nodify update_batch : add  8 attributes:
  --                                   WEIGHT_UOM_code, UNIT_WEIGHT, volume_uom_code, UNIT_VOLUME,
  --                                   DIMENSION_UOM_CODE, UNIT_LENGTH, UNIT_WIDTH, UNIT_HEIGHT
  --  1.2  07/10/2014  Dalit A. RAviv  CHG0033231 - add Inventory Org to itrem att25.
  --  1.3  16-FEB-2015 Gubendran K     CHG0034563 - Addded 5 Item Fields to Inventory Update item attributes report
  --  1.4  12/07/2015  Michal Tzvik    CHG0035537 - add fields list_price_per_unit ,shrinkage_rate
  --  1.5 30.4.17      yuval tal       CHG0040441 - Cut the PO- Mass update of sourcing buyer
  --  1.6 14.12.20     yuval tal       CHG0049102 - modify update_batch to work with intreface table instead of API
  --------------------------------------------------------------------
  PROCEDURE update_batch(errbuf      OUT VARCHAR2,
		 retcode     OUT VARCHAR2,
		 p_file_name VARCHAR2 DEFAULT 'ItemUpdate.csv') IS
  
    x_inventory_item_id NUMBER;
    x_organization_id   NUMBER;
    x_return_status     VARCHAR2(4000);
    x_msg_data          VARCHAR2(4000);
    x_msg_count         NUMBER;
  
    l_errbuf  VARCHAR2(4000);
    l_retcode VARCHAR2(10);
  
    l_item_id                    NUMBER;
    l_organization_id            NUMBER;
    l_buyer_id                   NUMBER;
    l_source_buyer_id            NUMBER;
    l_entity_id                  VARCHAR2(1000);
    l_entity_type                VARCHAR2(1000);
    l_count                      NUMBER := 0;
    l_planner_code               VARCHAR2(50);
    l_wip_supply_code            NUMBER;
    l_rounding_control_type      NUMBER;
    l_planning_make_buy_code     NUMBER;
    l_mrp_safety_stock_code      NUMBER;
    l_check_message              VARCHAR2(1000);
    l_bool                       BOOLEAN;
    l_cost_of_sales_account_ccid NUMBER;
    l_sales_account_ccid         NUMBER;
    myexception EXCEPTION;
    l_profile VARCHAR(20);
    --
    l_inv_org   NUMBER; -- 07/10/2014 Dalit A. Raviv
    l_err_count NUMBER := 0;
    CURSOR c IS
      SELECT *
      FROM   xxinv_ext_mass_item_update t
      WHERE  t.segment1 IS NOT NULL;
  
  BEGIN
  
    -- disable buyer mail update
    BEGIN
      -- ORIGINAL USER LEVEL
      SELECT t.profile_value
      INTO   l_profile
      FROM   xxobjt_profiles_v t
      WHERE  t.level_type = 'USER'
      AND    t.profile_option_name = 'XXINV_NEW_BUYER_FOR_ITEM_SEND_MAIL'
      AND    t.level_id = fnd_global.user_id;
    EXCEPTION
    
      WHEN OTHERS THEN
        l_profile := NULL;
      
    END;
  
    l_bool := fnd_profile.save_user('XXINV_NEW_BUYER_FOR_ITEM_SEND_MAIL',
			'N');
  
    --
    EXECUTE IMMEDIATE 'ALTER TABLE xxobjt.xxinv_ext_mass_item_update LOCATION (''' ||
	          p_file_name || ''')';
  
    fnd_file.put_line(fnd_file.log,
	          '--------------  Update items log ----------------');
    fnd_file.put_line(fnd_file.log, 'Process file ' || p_file_name);
  
    retcode := 0;
    /* fnd_global.apps_initialize(user_id      => 3850,
    resp_id      => 50623,
    resp_appl_id => 660);*/
    FOR i IN c
    LOOP
    
      l_organization_id            := NULL;
      l_item_id                    := NULL;
      l_buyer_id                   := NULL;
      l_source_buyer_id            := NULL;
      l_planner_code               := NULL;
      l_wip_supply_code            := NULL;
      l_rounding_control_type      := NULL;
      l_planning_make_buy_code     := NULL;
      l_mrp_safety_stock_code      := NULL;
      l_cost_of_sales_account_ccid := NULL;
      l_sales_account_ccid         := NULL;
    
      BEGIN
        -- org
        l_organization_id := get_organization_id(upper(i.organization_code));
      
        IF l_organization_id IS NULL THEN
          l_check_message := ' Organiztion id not found for ' ||
		     i.organization_code;
          RAISE myexception;
        END IF;
      
        -- item
        l_item_id := get_item_id(TRIM(i.segment1), l_organization_id);
        IF l_item_id IS NULL THEN
          l_check_message := ' Item id not found for ' || TRIM(i.segment1);
          RAISE myexception;
        END IF;
      
        -- buyer
        IF TRIM(i.buyer_name) IS NOT NULL THEN
          l_buyer_id := get_buyer_id(i.buyer_name);
          IF l_buyer_id IS NULL THEN
	l_check_message := ' Buyer id not found for ' || i.buyer_name;
	RAISE myexception;
          END IF;
        END IF;
      
        --CHG0040441  sourcing buyer
        IF TRIM(i.sourcing_buyer_name) IS NOT NULL THEN
          l_source_buyer_id := get_buyer_id(i.sourcing_buyer_name);
          IF l_source_buyer_id IS NULL THEN
	l_check_message := ' Buyer id not found for ' ||
		       i.sourcing_buyer_name;
	RAISE myexception;
          END IF;
        END IF;
        -- end CHG0040441
      
        -- COST_OF_SALES_ACCOUNT_DSP
        IF TRIM(i.cost_of_sales_account) IS NOT NULL THEN
          l_cost_of_sales_account_ccid := get_ccid(i.cost_of_sales_account,
				   i.organization_code);
          IF l_cost_of_sales_account_ccid IS NULL THEN
	l_check_message := ' cant find/generate ccid for cost_of_sales_account ' ||
		       i.cost_of_sales_account;
	RAISE myexception;
          END IF;
        END IF;
      
        -- SALES_ACCOUNT_DSP
        IF TRIM(i.sales_account) IS NOT NULL THEN
          l_sales_account_ccid := get_ccid(i.sales_account,
			       i.organization_code);
          IF l_sales_account_ccid IS NULL THEN
	l_check_message := ' cant find/generate ccid for sales_account ' ||
		       i.sales_account;
	RAISE myexception;
          END IF;
        END IF;
      
        -- planner_code
        IF TRIM(i.planner_code) IS NOT NULL THEN
          l_planner_code := TRIM(i.planner_code);
        END IF;
      
        -- wip_supply_code
        IF TRIM(i.wip_supply_type) IS NOT NULL THEN
          l_wip_supply_code := get_wip_supply_code(i.wip_supply_type);
          IF l_wip_supply_code IS NULL THEN
	l_check_message := ' wip_supply_code not found for ' ||
		       i.wip_supply_type;
	RAISE myexception;
          END IF;
        END IF;
        --
      
        -- Inv Organization 07/10/2014 Dalit A. Raviv - CHG0033231
        IF TRIM(i.inv_org_code) IS NOT NULL THEN
          BEGIN
	-- i retrieve the data from xxinv_org_auto_class_v
	-- because we do want to upload value EXC Exclude that is not a real value at mtl_parameters
	SELECT organization_id --, organization_code
	INTO   l_inv_org
	FROM   xxinv_org_auto_class_v
	WHERE  organization_code = TRIM(i.inv_org_code);
          EXCEPTION
	WHEN OTHERS THEN
	  l_check_message := ' inv_org_code not found for ' ||
		         i.inv_org_code;
	  RAISE myexception;
          END;
        END IF;
      
        -- rounding_control_type
        IF TRIM(i.rounding_control_type) IS NOT NULL THEN
          l_rounding_control_type := get_rounding_control_type(i.rounding_control_type);
          IF l_rounding_control_type IS NULL THEN
	l_check_message := ' rounding_control_type not found for ' ||
		       i.rounding_control_type;
	RAISE myexception;
          END IF;
        END IF;
        --
      
        -- planning_make_buy_code
        IF TRIM(i.planning_make_buy_code) IS NOT NULL THEN
          l_planning_make_buy_code := get_planning_make_buy_code(i.planning_make_buy_code);
          IF l_planning_make_buy_code IS NULL THEN
	l_check_message := ' rounding_control_type not found for ' ||
		       i.planning_make_buy_code;
	RAISE myexception;
          END IF;
        END IF;
        --
      
        -- mrp_safety_stock_code
        IF TRIM(i.mrp_safety_stock_code) IS NOT NULL THEN
          l_mrp_safety_stock_code := get_mrp_safety_stock_code(i.mrp_safety_stock_code);
          IF l_mrp_safety_stock_code IS NULL THEN
	l_check_message := ' rounding_control_type not found for ' ||
		       i.mrp_safety_stock_code;
	RAISE myexception;
          END IF;
        END IF;
        --
        --CHG0049102
        INSERT INTO mtl_system_items_interface
          (process_flag,
           set_process_id,
           transaction_type,
           inventory_item_id,
           segment1,
           organization_id,
           wip_supply_type,
           planner_code,
           description,
           preprocessing_lead_time,
           postprocessing_lead_time,
           full_lead_time,
           buyer_id,
           fixed_order_quantity,
           fixed_days_supply,
           minimum_order_quantity,
           fixed_lot_multiplier,
           cost_of_sales_account,
           sales_account,
           attribute11,
           attribute12,
           attribute25,
           attribute27,
           weight_uom_code,
           volume_uom_code,
           unit_volume,
           dimension_uom_code,
           unit_weight,
           unit_length,
           unit_width,
           unit_height,
           rounding_control_type,
           planning_make_buy_code,
           mrp_safety_stock_code,
           safety_stock_bucket_days,
           mrp_safety_stock_percent,
           list_price_per_unit,
           shrinkage_rate)
        
        VALUES
        
          (1,
           fnd_global.conc_request_id,
           'UPDATE',
           l_item_id, --
           TRIM(i.segment1), --
           l_organization_id, --
           l_wip_supply_code,
           l_planner_code,
           TRIM(i.description),
           i.preprocessing_lead_time, --
           i.postprocessing_lead_time,
           i.full_lead_time,
           l_buyer_id,
           
           i.fixed_order_quantity,
           i.fixed_days_supply,
           i.minimum_order_quantity, --
           i.fixed_lot_multiplier, --
           l_cost_of_sales_account_ccid, --
           l_sales_account_ccid,
           i.return_to_hq,
           i.returnable,
           to_char(l_inv_org),
           
           to_char(l_source_buyer_id),
           i.weight_uom_code,
           i.volume_uom_code,
           i.unit_volume,
           i.dimension_uom_code,
           i.unit_weight,
           --
           i.unit_length,
           i.unit_width,
           i.unit_height,
           
           l_rounding_control_type,
           l_planning_make_buy_code, --
           l_mrp_safety_stock_code,
           i.safety_stock_bucket_days,
           i.mrp_safety_stock_percent,
           
           i.list_price_per_unit,
           i.shrinkage_rate
           
           );
        l_count := l_count + 1;
        /*
        ego_item_pub.process_item(p_api_version       => 1.0, --
                                  p_init_msg_list     => fnd_api.g_true, --
                                  p_commit            => fnd_api.g_true, --
                                  p_transaction_type  => 'UPDATE', --
                                  p_inventory_item_id => l_item_id, --
                                  p_segment1          => TRIM(i.segment1), --
                                  p_organization_id   => l_organization_id, --
                                  p_wip_supply_type   => nvl(l_wip_supply_code,
                                                             fnd_api.g_miss_num), --
                                  --  p_master_organization_id =>91,
                                  -- p_inventory_item_status_code => 'Active',
                                  -- p_approval_status          => 'A',
                                  p_planner_code             => nvl(l_planner_code,
                                                                    fnd_api.g_miss_char), --
                                  p_description              => nvl(TRIM(i.description),
                                                                    fnd_api.g_miss_char), --
                                  p_preprocessing_lead_time  => nvl(i.preprocessing_lead_time,
                                                                    fnd_api.g_miss_num), --
                                  p_postprocessing_lead_time => nvl(i.postprocessing_lead_time,
                                                                    fnd_api.g_miss_num), --
                                  p_full_lead_time           => nvl(i.full_lead_time,
                                                                    fnd_api.g_miss_num), --
                                  p_buyer_id                 => nvl(l_buyer_id,
                                                                    fnd_api.g_miss_num), --
                                  x_inventory_item_id        => x_inventory_item_id, --
                                  x_organization_id          => x_organization_id,
                                  
                                  p_fixed_order_quantity   => nvl(i.fixed_order_quantity,
                                                                  fnd_api.g_miss_num), --
                                  p_fixed_days_supply      => nvl(i.fixed_days_supply,
                                                                  fnd_api.g_miss_num), --
                                  p_minimum_order_quantity => nvl(i.minimum_order_quantity,
                                                                  fnd_api.g_miss_num), --
                                  p_fixed_lot_multiplier   => nvl(i.fixed_lot_multiplier,
                                                                  fnd_api.g_miss_num), --
                                  p_cost_of_sales_account  => nvl(l_cost_of_sales_account_ccid,
                                                                  fnd_api.g_miss_num), --
                                  p_sales_account          => nvl(l_sales_account_ccid,
                                                                  fnd_api.g_miss_num), --
                                  p_attribute11            => nvl(i.return_to_hq,
                                                                  fnd_api.g_miss_char), --
                                  p_attribute12            => nvl(i.returnable,
                                                                  fnd_api.g_miss_char), --
                                  p_attribute25            => nvl(to_char(l_inv_org),
                                                                  fnd_api.g_miss_char), -- Inv Organization 07/10/2014 Dalit A. Raviv
                                  -- / cr 1004
                                  
                                  p_attribute27        => nvl(to_char(l_source_buyer_id),
                                                              fnd_api.g_miss_char), -- CHG0040441 l_source_buyer_id
                                  p_weight_uom_code    => nvl(i.weight_uom_code,
                                                              fnd_api.g_miss_char), --
                                  p_volume_uom_code    => nvl(i.volume_uom_code,
                                                              fnd_api.g_miss_char), --
                                  p_unit_volume        => nvl(i.unit_volume,
                                                              fnd_api.g_miss_num), --
                                  p_dimension_uom_code => nvl(i.dimension_uom_code,
                                                              fnd_api.g_miss_char), --
                                  p_unit_weight        => nvl(i.unit_weight,
                                                              fnd_api.g_miss_num),
                                  --
                                  p_unit_length => nvl(i.unit_length,
                                                       fnd_api.g_miss_num), --
                                  p_unit_width  => nvl(i.unit_width,
                                                       fnd_api.g_miss_num), --
                                  p_unit_height => nvl(i.unit_height,
                                                       fnd_api.g_miss_num), --
                                  -- cr1004 /
                                  -- / CHG0034563
                                  p_rounding_control_type    => nvl(l_rounding_control_type,
                                                                    fnd_api.g_miss_num), --
                                  p_planning_make_buy_code   => nvl(l_planning_make_buy_code,
                                                                    fnd_api.g_miss_num), --
                                  p_mrp_safety_stock_code    => nvl(l_mrp_safety_stock_code,
                                                                    fnd_api.g_miss_num), --
                                  p_safety_stock_bucket_days => nvl(i.safety_stock_bucket_days,
                                                                    fnd_api.g_miss_num), --
                                  p_mrp_safety_stock_percent => nvl(i.mrp_safety_stock_percent,
                                                                    fnd_api.g_miss_num), --
                                  -- CHG0034563 /
                                  -- /CHG0035537
                                  p_list_price_per_unit => nvl(i.list_price_per_unit,
                                                               fnd_api.g_miss_num), --
                                  p_shrinkage_rate      => nvl(i.shrinkage_rate,
                                                               fnd_api.g_miss_num), --
                                  -- CHG0035537/
                                  x_return_status => x_return_status, --
                                  x_msg_count     => x_msg_count, --
                                  x_msg_data      => x_msg_data);
        
        --dbms_output.put_line(i.segment1 || ' status=' || x_return_status);
        IF x_return_status != 'S' THEN
          retcode := 1;
          errbuf  := 'Not All Items were updated , show log.';
        
          FOR j IN 1 .. x_msg_count
          LOOP
            l_count := j;
            error_handler.get_message(x_msg_data,
                                      l_count,
                                      l_entity_id,
                                      l_entity_type);
          
            \*dbms_output.put_line(' Row :' || c%ROWCOUNT || ' ' ||
            i.segment1 || ' Error:' ||
            x_return_status || ' ' || x_msg_data);*\
            fnd_file.put_line(fnd_file.log,
                              'Row :' || c%ROWCOUNT || ' ' || i.segment1 ||
                              ' Error:' || x_return_status || ' ' ||
                              x_msg_data);
          END LOOP;
        ELSE
          \*  dbms_output.put_line(' Row :' || c%ROWCOUNT || ' ' || i.segment1 ||
          ' status=' || x_return_status);*\
          fnd_file.put_line(fnd_file.log,
                            i.segment1 || ' Row :' || c%ROWCOUNT ||
                            ' status=' || x_return_status);
        END IF;*/
      EXCEPTION
        WHEN myexception THEN
        
          l_err_count := l_err_count + 1;
        
          retcode := 1;
          errbuf  := 'Not All Items were updated , show log.';
          message(' Row :' || c%ROWCOUNT || ' ' || i.segment1 || ' Error:' ||
	      l_check_message);
        
        WHEN OTHERS THEN
          --  ROLLBACK;
        
          message(' Row :' || c%ROWCOUNT || ' ' || i.segment1 || ' Error:' ||
	      substr(SQLERRM, 1, 100));
        
      END;
    END LOOP;
    COMMIT;
    message('-----------------------------------------------');
  
    message('Success inserted into interface table count=' || l_count);
    message('Failed Validation count=' || l_err_count);
  
    --CHG0049102
    import_items(errbuf          => l_errbuf,
	     retcode         => l_retcode,
	     p_org_id        => nvl(fnd_profile.value('MFG_ORGANIZATION_ID'),
			    '91'),
	     p_all_org       => '1',
	     p_val_item_flag => '1',
	     p_pro_item_flag => '1',
	     p_del_rec_flag  => '1', -- 2 no
	     p_xset_id       => to_char(fnd_global.conc_request_id),
	     p_run_mode      => '2',
	     p_gather_stats  => '1');
  
    message('------------------- end log ---------------------');
    l_bool  := fnd_profile.save_user('XXINV_NEW_BUYER_FOR_ITEM_SEND_MAIL',
			 l_profile);
    retcode := greatest(l_retcode, retcode);
  
  EXCEPTION
    WHEN OTHERS THEN
      l_bool := fnd_profile.save_user('XXINV_NEW_BUYER_FOR_ITEM_SEND_MAIL',
			  l_profile);
      IF NOT l_bool THEN
        message('Did not update profile XXINV_NEW_BUYER_FOR_ITEM_SEND_MAIL with the value ' ||
	    l_profile);
      END IF;
      dbms_output.put_line(SQLERRM);
      errbuf  := SQLERRM;
      retcode := 2;
  END update_batch;

  --------------------------------------------------------------------
  --  name:            import_items
  --  create by:       Dan Melamed
  --  Revision:        1.0
  --  ccreation date:  04-Jun-2018 12:01:00 PM
  --------------------------------------------------------------------
  --  purpose :        Invoke/call point for the concurrent.
  --    This procedure resets the NLS Language and invokes the seeded Import Items (INCOIN) Concurrent.
  --------------------------------------------------------------------
  --  ver     name              date         desc
  --  1.0     Dan Melamed       03-Jun-2018  Initial version : CHG0043127
  --------------------------------------------------------------------
  PROCEDURE import_items(errbuf          OUT NOCOPY VARCHAR2,
		 retcode         OUT NOCOPY NUMBER,
		 p_org_id        VARCHAR2 DEFAULT NULL,
		 p_all_org       VARCHAR2 DEFAULT NULL,
		 p_val_item_flag VARCHAR2 DEFAULT NULL,
		 p_pro_item_flag VARCHAR2 DEFAULT NULL,
		 p_del_rec_flag  VARCHAR2 DEFAULT NULL,
		 p_xset_id       VARCHAR2 DEFAULT NULL,
		 p_run_mode      VARCHAR2 DEFAULT NULL,
		 p_gather_stats  VARCHAR2 DEFAULT NULL,
		 p_language      VARCHAR2 DEFAULT NULL) IS
  
    l_nls_territory VARCHAR2(255);
    l_request_id    NUMBER;
    l_phase         VARCHAR2(255);
    l_status        VARCHAR2(255);
    l_message       VARCHAR2(32000);
    l_complete      BOOLEAN;
    l_set_lang      BOOLEAN := FALSE;
    l_devphase      VARCHAR2(255);
    l_devstatus     VARCHAR2(255);
  
  BEGIN
  
    /*  BEGIN
    
      SELECT fl.nls_territory
      INTO   l_nls_territory
      FROM   fnd_languages_vl fl
      WHERE  fl.nls_language = p_language
      AND    fl.installed_flag IN ('I') -- Installed. Discard the 'B'
      AND    rownum = 1;
    
      l_set_lang := fnd_request.set_options(LANGUAGE  => p_language,
                                            territory => l_nls_territory);
    
    EXCEPTION
      WHEN OTHERS THEN
        NULL; -- l_set_lang preinitialized as false
    END;
    
    IF l_set_lang = FALSE THEN
      retcode := 2; -- Error
      errbuf  := 'Unable to set language to ' || p_language;
      RETURN;
    END IF;*/
  
    l_request_id := fnd_request.submit_request('INV', --
			           'INCOIN',
			           'Item Open Interface', -- Description,      ? description of the concurrent program
			           SYSDATE, --         ? start time of the concurrent program
			           FALSE,
			           p_org_id,
			           p_all_org,
			           p_val_item_flag,
			           p_pro_item_flag,
			           p_del_rec_flag,
			           p_xset_id,
			           p_run_mode,
			           p_gather_stats);
    COMMIT;
  
    l_complete := fnd_concurrent.wait_for_request(request_id => l_request_id,
				  INTERVAL   => 10, -- Wait for 10 seconds before re-visiting concurrent request.
				  max_wait   => 1400,
				  phase      => l_phase,
				  status     => l_status,
				  dev_phase  => l_devphase,
				  dev_status => l_devstatus,
				  message    => l_message);
  
    fnd_file.put_line(fnd_file.log, 'Concurrent run outputs : ');
    fnd_file.put_line(fnd_file.log, '------------------------: ');
    fnd_file.put_line(fnd_file.log, 'l_request_id :  ' || l_request_id);
    fnd_file.put_line(fnd_file.log, ' l_phase : ' || l_phase);
    fnd_file.put_line(fnd_file.log, ' l_status : ' || l_status);
    fnd_file.put_line(fnd_file.log, ' l_devphase : ' || l_devphase);
    fnd_file.put_line(fnd_file.log, ' l_devstatus : ' || l_devstatus);
    fnd_file.put_line(fnd_file.log, ' l_message : ' || l_message);
  
    IF upper(l_devphase) = 'COMPLETE' AND upper(l_devstatus) IN ('ERROR') THEN
      retcode := 2; -- Error
      errbuf  := 'INV:INCOIN Item Open Interface concurrent finished with error : ' ||
	     l_message || '(Req ID: ' || l_request_id || ')';
    ELSIF upper(l_devphase) = 'COMPLETE' AND upper(l_devstatus) = 'NORMAL' THEN
      retcode := 0; -- Success
    ELSE
      retcode := 1; -- Warning
      errbuf  := 'INV:INCOIN Item Open Interface concurrent did not complete normally. (Req ID: ' ||
	     l_request_id || ')';
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      retcode := 2;
      errbuf  := SQLERRM;
  END import_items;

END xxinv_item_api;
/
