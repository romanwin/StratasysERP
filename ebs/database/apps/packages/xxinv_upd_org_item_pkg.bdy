CREATE OR REPLACE PACKAGE BODY xxinv_upd_org_item_pkg IS
  ----------------------------------------------------
  -- xxinv_upd_org_item_pkg
  -------------------------------------------------------------------------
  -- Version  Date          Performer       Comments
  ----------  ----------    --------------  --------------------------------
  --   1.x   19.2.13        yuval tal        CR 676 Syncronize several Item Attributes from 
  --                                         Master to Organization
  --  1.1    07.07.13       yuval tal        CR 810 - add parameters to copy_account_from_master_item   
  --  1.2     9.9.13        vitaly           cr 967 add copy_account_from_master_item2 (interface version)
  --                                                modify copy_account_from_master_item   support new coa  for SSYSUS  ,Modify copy_account_from_master_item add  get_org_coa_id   ,get_coa_name                     
  -----------------------------------------------------------

  invalid_item EXCEPTION;

  -----------------------------------------------------------
  -- get_coa_name
  -----------------------------------------------------------
  -- Version  Date          Performer       Comments
  ----------  ----------    --------------  ---------------------
  --   1.x    09.09.13      yuval tal       cr967 -- support new coa  for SSYSUS 
  FUNCTION get_coa_name(p_coa_id NUMBER) RETURN VARCHAR2 IS
    l_coa_name VARCHAR2(100);
  BEGIN
    SELECT t.chart_of_accounts_name
      INTO l_coa_name
      FROM glfg_charts_of_accounts t
     WHERE t.chart_of_accounts_id = p_coa_id;
    RETURN l_coa_name;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END;

  -----------------------------------------------------------
  -- get_org_coa_id
  -----------------------------------------------------------
  -- Version  Date          Performer       Comments
  ----------  ----------    --------------  ---------------------
  --   1.x    09.09.13      yuval tal       cr967
  FUNCTION get_org_coa_id(p_organization_id NUMBER) RETURN NUMBER IS
    l_coa_id NUMBER;
  BEGIN
  
    SELECT ood.chart_of_accounts_id
      INTO l_coa_id
      FROM org_organization_definitions ood
     WHERE ood.organization_id = p_organization_id;
  
    RETURN l_coa_id;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END;

  -----------------------------------------------------------
  -- copy_account_from_master_item
  -----------------------------------------------------------
  -- Version  Date          Performer       Comments
  ----------  ----------    --------------  ---------------------
  --   1.x    19.2.13        yuval tal        CR 676 Syncronize several Item Attributes from
  --                                          Master to Organization , add param  p_sync_entity
  --                                          p_sync_entity : 
  --                                                        ALL         All
  --                                                        ACCOUNTS    Accounts
  --                                                        EXPIRATION  Expiration Attributes
  -- 1.1      07/07/13       yuval tal       add parameters p_sync_org_id , p_batch_size  

  --  1.2    09.09.13        yuval tal       cr 967 - support new coa  for US  
  --                                         if coa name ='XX_STRATASYS_USD' adjust account combination                                                                        

  -----------------------------------------------------------

  PROCEDURE copy_account_from_master_item(p_errbuff     OUT VARCHAR2,
                                          p_errcode     OUT VARCHAR2,
                                          p_sync_entity VARCHAR2,
                                          p_sync_org_id NUMBER,
                                          p_batch_size  NUMBER) IS
  
    CURSOR c_item_att IS
      SELECT msi_master.inventory_item_id,
             msi_master.segment1,
             msi_org.organization_id,
             msi_master.attribute4,
             msi_master.attribute5,
             msi_master.attribute6,
             msi_master.attribute7
        FROM mtl_system_items_b msi_master, mtl_system_items_b msi_org
       WHERE msi_master.inventory_item_id = msi_org.inventory_item_id
         AND msi_master.organization_id =
             xxinv_utils_pkg.get_master_organization_id
         AND msi_org.organization_id !=
             xxinv_utils_pkg.get_master_organization_id
         AND (nvl(msi_master.attribute4, '-1') !=
             nvl(msi_org.attribute4, '-1') OR
             nvl(msi_master.attribute5, '-1') !=
             nvl(msi_org.attribute5, '-1') OR
             nvl(msi_master.attribute6, '-1') !=
             nvl(msi_org.attribute6, '-1') OR
             nvl(msi_master.attribute7, '-1') !=
             nvl(msi_org.attribute7, '-1'))
         AND p_sync_entity IN ('ALL', 'EXPIRATION')
         AND msi_org.organization_id =
             nvl(p_sync_org_id, msi_org.organization_id);
    ---AND msi_master.segment1 = 'OBJ-13000'
    ---AND rownum <= p_batch_size;
  
    CURSOR get_org_items IS
      SELECT msi_master.segment1,
             io_master.organization_id master_organization_id,
             msi_org.organization_id organization_id,
             io_org.name organization_name,
             org_cc_cost_of_sales.segment1 org_cost_of_sales_segment1,
             mp_cc_cost_of_sales.segment1 mp_cost_of_sales_segment1,
             org_cc_sales.segment1 org_sales_segment1,
             mp_cc_sales.segment1 mp_sales_segment1,
             master_cc_cost_of_sales.segment5 master_cost_of_sales_segment5,
             org_cc_cost_of_sales.segment5 org_cost_of_sales_segment5,
             master_cc_sales.segment5 master_sales_segment5,
             org_cc_sales.segment5 org_sales_segment5,
             org_cc_cost_of_sales.segment2 org_cost_of_sales_segment2,
             org_cc_cost_of_sales.segment3 org_cost_of_sales_segment3,
             org_cc_cost_of_sales.segment4 org_cost_of_sales_segment4,
             org_cc_cost_of_sales.segment6 org_cost_of_sales_segment6,
             org_cc_cost_of_sales.segment7 org_cost_of_sales_segment7,
             org_cc_cost_of_sales.segment8 org_cost_of_sales_segment8,
             org_cc_cost_of_sales.segment9 org_cost_of_sales_segment9,
             msi_org.cost_of_sales_account org_cost_of_sales_account,
             org_cc_sales.segment2 org_sales_segment2,
             org_cc_sales.segment3 org_sales_segment3,
             org_cc_sales.segment4 org_sales_segment4,
             org_cc_sales.segment6 org_sales_segment6,
             org_cc_sales.segment7 org_sales_segment7,
             org_cc_sales.segment8 org_sales_segment8,
             org_cc_sales.segment9 org_sales_segment9,
             msi_org.sales_account org_sales_account,
             CASE
               WHEN master_cc_cost_of_sales.segment5 <>
                    org_cc_cost_of_sales.segment5 OR
                    org_cc_cost_of_sales.segment1 <>
                    mp_cc_cost_of_sales.segment1 THEN
                'Y'
               ELSE
                'N'
             END cost_of_sales_account_dif_flag,
             CASE
               WHEN master_cc_sales.segment5 <> org_cc_sales.segment5 OR
                    org_cc_sales.segment1 <> mp_cc_sales.segment1 THEN
                'Y'
               ELSE
                'N'
             END sales_account_diff_flag,
             msi_org.inventory_item_id,
             REPLACE(msi_org.description, ',', '') description,
             msi_org.inventory_item_status_code,
             msi_org.enabled_flag,
             msi_org.primary_uom_code,
             msi_org.primary_unit_of_measure,
             msi_org.item_type,
             msi_org.contract_item_type_code,
             msi_master.attribute4,
             msi_master.attribute5,
             msi_master.attribute6,
             msi_master.attribute7
        FROM hr_all_organization_units io_master,
             hr_all_organization_units io_org,
             mtl_system_items_b        msi_master,
             mtl_system_items_b        msi_org,
             gl_code_combinations      master_cc_cost_of_sales,
             gl_code_combinations      master_cc_sales,
             gl_code_combinations      org_cc_cost_of_sales,
             gl_code_combinations      org_cc_sales,
             gl_code_combinations      mp_cc_cost_of_sales,
             gl_code_combinations      mp_cc_sales,
             mtl_parameters            mp
       WHERE io_master.organization_id =
             xxinv_utils_pkg.get_master_organization_id
         AND msi_master.organization_id = io_master.organization_id
         AND msi_master.cost_of_sales_account =
             master_cc_cost_of_sales.code_combination_id
            --msi_master.enabled_flag = 'Y' AND
            --msi_master.customer_order_enabled_flag = 'Y' AND
         AND msi_master.sales_account = master_cc_sales.code_combination_id
         AND msi_org.organization_id != msi_master.organization_id
         AND msi_org.inventory_item_id = msi_master.inventory_item_id
         AND msi_org.cost_of_sales_account =
             org_cc_cost_of_sales.code_combination_id
         AND msi_org.sales_account = org_cc_sales.code_combination_id
         AND mp.cost_of_sales_account =
             mp_cc_cost_of_sales.code_combination_id
         AND mp.sales_account = mp_cc_sales.code_combination_id
         AND mp.organization_id = io_org.organization_id
         AND p_sync_entity IN ('ALL', 'ACCOUNTS')
         AND (master_cc_cost_of_sales.segment5 <>
             org_cc_cost_of_sales.segment5 OR
             master_cc_sales.segment5 <> org_cc_sales.segment5 OR
             org_cc_cost_of_sales.segment1 <> mp_cc_cost_of_sales.segment1 OR
             org_cc_sales.segment1 <> mp_cc_sales.segment1)
         AND msi_org.organization_id = io_org.organization_id ---parameter
         AND msi_org.organization_id =
             nvl(p_sync_org_id, msi_org.organization_id)
         AND rownum <= nvl(p_batch_size, 999999999);
  
    v_item_rec     inv_item_grp.item_rec_type;
    v_item_rec_out inv_item_grp.item_rec_type;
    v_error_tbl    inv_item_grp.error_tbl_type;
  
    v_items_counter                NUMBER := 0;
    v_successfuly_updated_items    NUMBER := 0;
    v_failured_items_count         NUMBER := 0;
    v_step                         VARCHAR2(100);
    v_new_cogs_concatenated_seg    VARCHAR2(300);
    v_new_revenue_concatenated_seg VARCHAR2(300);
    v_previous_inv_organization_id NUMBER;
    v_coa_id                       NUMBER;
    v_cost_of_sales_account_id     NUMBER;
    v_sales_account_id             NUMBER;
    v_return_status                VARCHAR2(100);
    v_err_msg                      VARCHAR2(30000);
    ---v_cogs_str                     VARCHAR2(300);
    ---v_revenue_str                  VARCHAR2(300);
    --v_organization_id NUMBER;
    v_api_error_msg VARCHAR2(30000);
    l_count1        NUMBER := 0;
    l_count2        NUMBER := 0;
  
    stop_process_for_this_item EXCEPTION;
    l_coa_name VARCHAR2(150);
  
  BEGIN
  
    fnd_file.put_line(fnd_file.log,
                      '================ PARAMETERS ==============');
    fnd_file.put_line(fnd_file.log, 'p_sync_entity=' || p_sync_entity);
    fnd_file.put_line(fnd_file.log, 'p_sync_org_id=' || p_sync_org_id);
    fnd_file.put_line(fnd_file.log, 'p_batch_size =' || p_batch_size);
  
    fnd_file.put_line(fnd_file.log,
                      'Start: ' ||
                      to_char(SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));
    p_errcode := 0;
    p_errbuff := NULL;
    v_step    := 'Step 1';
  
    FOR item_rec IN get_org_items LOOP
      v_item_rec                     := inv_item_grp.g_miss_item_rec;
      v_cost_of_sales_account_id     := NULL;
      v_sales_account_id             := NULL;
      v_new_cogs_concatenated_seg    := NULL;
      v_new_revenue_concatenated_seg := NULL;
      v_api_error_msg                := NULL;
      v_err_msg                      := NULL;
      v_error_tbl.delete;
      v_items_counter := v_items_counter + 1;
    
      IF v_previous_inv_organization_id IS NULL OR
         v_previous_inv_organization_id != item_rec.organization_id THEN
      
        v_step := 'Step 2';
        ----Get coa_id-----------  
        v_coa_id   := get_org_coa_id(item_rec.organization_id); --cr967
        l_coa_name := get_coa_name(v_coa_id); -- cr967
      
        /*  v_organization_id := item_rec.organization_id;
        v_coa_id          := xxgl_utils_pkg.get_coa_id_from_inv_org(item_rec.master_organization_id,
                                                                    v_organization_id);*/
      END IF;
    
      v_previous_inv_organization_id := item_rec.organization_id;
    
      BEGIN
      
        v_step := 'Step 3';
        IF item_rec.cost_of_sales_account_dif_flag = 'Y' THEN
        
          ---There is a difference in Cogs account (Segment1 or Segment5)
          v_step := 'Step 4';
          IF l_coa_name = 'XX_STRATASYS_USD' THEN
            --cr 967 adjust segments according to chart of account
            v_new_cogs_concatenated_seg :=  -----item_rec.org_cost_of_sales_segment1 || '.' ||
             item_rec.mp_cost_of_sales_segment1 || '.' ||
                                           item_rec.org_cost_of_sales_segment2 || '.' ||
                                           item_rec.org_cost_of_sales_segment3 || '.' ||
                                           item_rec.master_cost_of_sales_segment5 || '.' ||
                                           item_rec.org_cost_of_sales_segment6 || '.' ||
                                           item_rec.org_cost_of_sales_segment7 || '.' ||
                                           '000' || '.' || '0000';
          
          ELSE
            v_new_cogs_concatenated_seg :=  -----item_rec.org_cost_of_sales_segment1 || '.' ||
             item_rec.mp_cost_of_sales_segment1 || '.' ||
                                           item_rec.org_cost_of_sales_segment2 || '.' ||
                                           item_rec.org_cost_of_sales_segment3 || '.' ||
                                           item_rec.org_cost_of_sales_segment4 || '.' ||
                                           item_rec.master_cost_of_sales_segment5 || '.' ||
                                           item_rec.org_cost_of_sales_segment6 || '.' ||
                                           item_rec.org_cost_of_sales_segment7 || '.' ||
                                           item_rec.org_cost_of_sales_segment8 || '.' ||
                                           item_rec.org_cost_of_sales_segment9;
          
          END IF;
        
          -----------Check/Create new code combination for cost_of_sales_account------------
          BEGIN
            SELECT cc.code_combination_id
              INTO v_cost_of_sales_account_id
              FROM gl_code_combinations_kfv cc
             WHERE cc.concatenated_segments = v_new_cogs_concatenated_seg
               AND cc.enabled_flag = 'Y';
          
          EXCEPTION
            WHEN no_data_found THEN
              l_count1 := l_count1 + 1;
              xxgl_utils_pkg.get_and_create_account(p_concat_segment      => v_new_cogs_concatenated_seg,
                                                    p_coa_id              => v_coa_id,
                                                    x_code_combination_id => v_cost_of_sales_account_id,
                                                    x_return_code         => v_return_status,
                                                    x_err_msg             => v_err_msg);
            
              IF v_return_status != fnd_api.g_ret_sts_success THEN
                v_api_error_msg := 'API ERROR! We cannot create new code combination for Cost Of Goods Sold Account: ' ||
                                   v_err_msg;
                RAISE stop_process_for_this_item;
              END IF;
          END;
          ----------------- 
        ELSE
          ---No difference between Master and Org Item
          v_cost_of_sales_account_id := item_rec.org_cost_of_sales_account;
        END IF;
      
        IF item_rec.sales_account_diff_flag = 'Y' THEN
        
          ---There is a difference in Revenue account (Segment1 or Segment5)
          v_step := 'Step 5';
          IF l_coa_name = 'XX_STRATASYS_USD' THEN
            -- cr 967
            --cr 967 adjust segments according to chart of account
            v_new_revenue_concatenated_seg :=  ----item_rec.org_sales_segment1 || '.' ||
             item_rec.mp_sales_segment1 || '.' ||
                                              item_rec.org_sales_segment2 || '.' ||
                                              item_rec.org_sales_segment3 || '.' ||
                                             
                                              item_rec.master_sales_segment5 || '.' ||
                                              item_rec.org_sales_segment6 || '.' ||
                                              item_rec.org_sales_segment7 || '.' ||
                                              '000' || '.' || '0000';
          
          ELSE
            v_new_revenue_concatenated_seg :=  ----item_rec.org_sales_segment1 || '.' ||
             item_rec.mp_sales_segment1 || '.' ||
                                              item_rec.org_sales_segment2 || '.' ||
                                              item_rec.org_sales_segment3 || '.' ||
                                              item_rec.org_sales_segment4 || '.' ||
                                              item_rec.master_sales_segment5 || '.' ||
                                              item_rec.org_sales_segment6 || '.' ||
                                              item_rec.org_sales_segment7 || '.' ||
                                              item_rec.org_sales_segment8 || '.' ||
                                              item_rec.org_sales_segment9;
          END IF;
        
          -----------Check/Create new code combination for sales_account--(revenue account)----------
          BEGIN
            SELECT cc.code_combination_id
              INTO v_sales_account_id
              FROM gl_code_combinations_kfv cc
             WHERE cc.concatenated_segments =
                   v_new_revenue_concatenated_seg
               AND cc.enabled_flag = 'Y';
          
          EXCEPTION
            WHEN no_data_found THEN
              l_count2 := l_count2 + 1;
              xxgl_utils_pkg.get_and_create_account(p_concat_segment      => v_new_revenue_concatenated_seg,
                                                    p_coa_id              => v_coa_id,
                                                    x_code_combination_id => v_sales_account_id,
                                                    x_return_code         => v_return_status,
                                                    x_err_msg             => v_err_msg);
            
              IF v_return_status != fnd_api.g_ret_sts_success THEN
                v_api_error_msg := 'API ERROR! We cannot create new code combination for Revenue Account ' ||
                                   v_err_msg;
                RAISE stop_process_for_this_item;
              END IF;
          END;
          -----------------
        ELSE
          ---No difference between Master and Org Item
          v_sales_account_id := item_rec.org_sales_account;
        END IF;
      
        -------------Update Organization Item------------------
        v_step                                := 'Step 40';
        v_item_rec.item_number                := item_rec.segment1;
        v_item_rec.segment1                   := item_rec.segment1;
        v_item_rec.inventory_item_id          := item_rec.inventory_item_id;
        v_item_rec.organization_id            := item_rec.organization_id;
        v_item_rec.inventory_item_status_code := item_rec.inventory_item_status_code;
        v_item_rec.enabled_flag               := item_rec.enabled_flag;
        v_item_rec.contract_item_type_code    := item_rec.contract_item_type_code;
        v_item_rec.primary_uom_code           := item_rec.primary_uom_code;
        v_item_rec.primary_unit_of_measure    := item_rec.primary_unit_of_measure;
        v_item_rec.item_type                  := item_rec.item_type;
      
        v_item_rec.cost_of_sales_account := v_cost_of_sales_account_id;
        v_item_rec.sales_account         := v_sales_account_id;
      
        v_step := 'Step 50';
        /*fnd_file.put_line(fnd_file.log,
        '===== ORG ITEMS ======== BEFORE API =================');*/
        inv_item_grp.update_item(p_commit           => fnd_api.g_false,
                                 p_validation_level => fnd_api.g_valid_level_full,
                                 p_item_rec         => v_item_rec,
                                 x_item_rec         => v_item_rec_out,
                                 x_return_status    => v_return_status,
                                 x_error_tbl        => v_error_tbl);
      
        v_step    := 'Step 60';
        v_err_msg := '';
        IF v_return_status != 'S' THEN
          -- ROLLBACK TO begin_mass_update;
          v_failured_items_count := v_failured_items_count + 1;
          -- error_handler.get_message_list(x_message_list => l_error_tbl);
          FOR i IN 1 .. v_error_tbl.count LOOP
            v_err_msg := v_err_msg || v_error_tbl(i).message_text ||
                         chr(10);
          END LOOP;
        
          v_api_error_msg := 'API ERROR! We cannot Update Organization Item ' ||
                             v_item_rec.segment1 || ' ' || v_err_msg;
          RAISE stop_process_for_this_item;
        ELSE
          ----SUCCESS----
          /*fnd_file.put_line (fnd_file.log, 
          '----API SUCCESS Item was successfuly updated');*/
          v_successfuly_updated_items := v_successfuly_updated_items + 1;
          IF MOD(get_org_items%ROWCOUNT, 200) = 0 THEN
            COMMIT;
          END IF;
        END IF;
      
      EXCEPTION
        WHEN stop_process_for_this_item THEN
          v_failured_items_count := v_failured_items_count + 1;
          fnd_file.put_line(fnd_file.log, v_api_error_msg);
      END;
      ------------add line to report---------------------
      v_step := 'Step 70';
    
    END LOOP;
  
    COMMIT;
    fnd_file.put_line(fnd_file.log, 'l_count1 ' || l_count1);
    fnd_file.put_line(fnd_file.log, 'l_count2 ' || l_count2);
  
    fnd_file.put_line(fnd_file.log,
                      'successfuly updated items=' ||
                      v_successfuly_updated_items);
    fnd_file.put_line(fnd_file.log,
                      'failures updated items count=' ||
                      v_failured_items_count);
  
    -- CR 676 Syncronize several Item Attributes from Master to Organization
    BEGIN
      v_successfuly_updated_items := 0;
      v_failured_items_count      := 0;
      fnd_file.put_line(fnd_file.log,
                        '-------------- EXPIRATION ATTRIBUTE UPDATE LOG --------------');
      FOR i IN c_item_att LOOP
        v_item_rec := inv_item_grp.g_miss_item_rec;
        v_error_tbl.delete;
        v_item_rec.organization_id   := i.organization_id;
        v_item_rec.inventory_item_id := i.inventory_item_id;
        v_item_rec.attribute4        := i.attribute4;
        v_item_rec.attribute5        := i.attribute5;
        v_item_rec.attribute6        := i.attribute6;
        v_item_rec.attribute7        := i.attribute7;
        fnd_file.put_line(fnd_file.log,
                          '===== EXPIRATION ATTRIBUTE UPDATE ======== BEFORE API ================');
        inv_item_grp.update_item(p_commit           => fnd_api.g_false,
                                 p_validation_level => fnd_api.g_valid_level_full,
                                 p_item_rec         => v_item_rec,
                                 x_item_rec         => v_item_rec_out,
                                 x_return_status    => v_return_status,
                                 x_error_tbl        => v_error_tbl);
        v_step    := 'Step 60';
        v_err_msg := '';
        IF v_return_status != 'S' THEN
          v_failured_items_count := v_failured_items_count + 1;
          v_err_msg              := NULL;
          -- error_handler.get_message_list(x_message_list => l_error_tbl);
          FOR i IN 1 .. v_error_tbl.count LOOP
            v_err_msg := v_err_msg || v_error_tbl(i).message_text ||
                         chr(10);
          END LOOP;
          fnd_file.put_line(fnd_file.log, v_err_msg);
        ELSE
          IF MOD(c_item_att%ROWCOUNT, 200) = 0 THEN
            COMMIT;
          END IF;
          v_successfuly_updated_items := v_successfuly_updated_items + 1;
        END IF;
      END LOOP;
    END;
    fnd_file.put_line(fnd_file.log,
                      'successfuly updated items=' ||
                      v_successfuly_updated_items);
    fnd_file.put_line(fnd_file.log,
                      'failures updated items count=' ||
                      v_failured_items_count);
    fnd_file.put_line(fnd_file.log,
                      '-------------- END EXPIRATION ATTRIBUTE UPDATE LOG --------------');
    -- end cr 676
    COMMIT;
  EXCEPTION
  
    WHEN OTHERS THEN
      p_errbuff := 1;
      fnd_file.put_line(fnd_file.log,
                        'XXINV_UPD_ORG_ITEM_PKG.copy_account_from_master_item unexpected ERROR (' ||
                        'Item=' || v_item_rec.item_number || ' ' || v_step ||
                        ') : ' || SQLERRM);
      fnd_file.put_line(fnd_file.log,
                        ' =============XXINV_UPD_ORG_ITEM_PKG.copy_account_from_master_item unexpected ERROR (' ||
                        v_step || ') : ' || SQLERRM);
      RAISE;
  END copy_account_from_master_item;
  -----------------------------------------------------------
  -- copy_account_from_master_item2  (insert into mtl_system_items_interface inside)
  -----------------------------------------------------------
  -- Version  Date          Performer    Comments
  ----------  ----------    ----------  ---------------------
  --   1.0    12.11.13      Vitaly      CUST655 CR967  "XX: Sync Organization Items Attributes NEW" Initial revision  
  --                                    modify original proc copy_account_from_master_item change update mode from  api to interface                                                                   
  -----------------------------------------------------------

  PROCEDURE copy_account_from_master_item2(p_errbuff              OUT VARCHAR2,
                                           p_errcode              OUT VARCHAR2,
                                           p_sync_organization_id NUMBER,
                                           p_item                 VARCHAR2) IS
  
    CURSOR get_org_items IS
      SELECT msi_master.segment1,
             io_master.organization_id master_organization_id,
             msi_org.organization_id organization_id,
             io_org.name organization_name,
             org_cc_cost_of_sales.segment1 org_cost_of_sales_segment1,
             mp_cc_cost_of_sales.segment1 mp_cost_of_sales_segment1,
             org_cc_sales.segment1 org_sales_segment1,
             mp_cc_sales.segment1 mp_sales_segment1,
             master_cc_cost_of_sales.segment5 master_cost_of_sales_segment5,
             org_cc_cost_of_sales.segment5 org_cost_of_sales_segment5,
             master_cc_sales.segment5 master_sales_segment5,
             org_cc_sales.segment5 org_sales_segment5,
             org_cc_cost_of_sales.segment2 org_cost_of_sales_segment2,
             org_cc_cost_of_sales.segment3 org_cost_of_sales_segment3,
             org_cc_cost_of_sales.segment4 org_cost_of_sales_segment4,
             org_cc_cost_of_sales.segment6 org_cost_of_sales_segment6,
             org_cc_cost_of_sales.segment7 org_cost_of_sales_segment7,
             org_cc_cost_of_sales.segment8 org_cost_of_sales_segment8,
             org_cc_cost_of_sales.segment9 org_cost_of_sales_segment9,
             msi_org.cost_of_sales_account org_cost_of_sales_account,
             org_cc_sales.segment2 org_sales_segment2,
             org_cc_sales.segment3 org_sales_segment3,
             org_cc_sales.segment4 org_sales_segment4,
             org_cc_sales.segment6 org_sales_segment6,
             org_cc_sales.segment7 org_sales_segment7,
             org_cc_sales.segment8 org_sales_segment8,
             org_cc_sales.segment9 org_sales_segment9,
             msi_org.sales_account org_sales_account,
             CASE
               WHEN master_cc_cost_of_sales.segment5 <>
                    org_cc_cost_of_sales.segment5 OR
                    org_cc_cost_of_sales.segment1 <>
                    mp_cc_cost_of_sales.segment1 THEN
                'Y'
               ELSE
                'N'
             END cost_of_sales_account_dif_flag,
             CASE
               WHEN master_cc_sales.segment5 <> org_cc_sales.segment5 OR
                    org_cc_sales.segment1 <> mp_cc_sales.segment1 THEN
                'Y'
               ELSE
                'N'
             END sales_account_diff_flag,
             msi_org.inventory_item_id,
             REPLACE(msi_org.description, ',', '') description,
             msi_org.inventory_item_status_code,
             msi_org.enabled_flag,
             msi_org.primary_uom_code,
             msi_org.primary_unit_of_measure,
             msi_org.item_type,
             msi_org.contract_item_type_code,
             msi_master.attribute4,
             msi_master.attribute5,
             msi_master.attribute6,
             msi_master.attribute7
        FROM hr_all_organization_units io_master,
             hr_all_organization_units io_org,
             mtl_system_items_b        msi_master,
             mtl_system_items_b        msi_org,
             gl_code_combinations      master_cc_cost_of_sales,
             gl_code_combinations      master_cc_sales,
             gl_code_combinations      org_cc_cost_of_sales,
             gl_code_combinations      org_cc_sales,
             gl_code_combinations      mp_cc_cost_of_sales,
             gl_code_combinations      mp_cc_sales,
             mtl_parameters            mp
       WHERE io_master.organization_id =
             xxinv_utils_pkg.get_master_organization_id
         AND msi_master.organization_id = io_master.organization_id
         AND msi_master.cost_of_sales_account =
             master_cc_cost_of_sales.code_combination_id
            --msi_master.enabled_flag = 'Y' AND
            --msi_master.customer_order_enabled_flag = 'Y' AND
         AND msi_master.sales_account = master_cc_sales.code_combination_id
         AND msi_org.organization_id != msi_master.organization_id
         AND msi_org.inventory_item_id = msi_master.inventory_item_id
         AND msi_org.cost_of_sales_account =
             org_cc_cost_of_sales.code_combination_id
         AND msi_org.sales_account = org_cc_sales.code_combination_id
         AND mp.cost_of_sales_account =
             mp_cc_cost_of_sales.code_combination_id
         AND mp.sales_account = mp_cc_sales.code_combination_id
         AND mp.organization_id = io_org.organization_id
         AND (master_cc_cost_of_sales.segment5 <>
             org_cc_cost_of_sales.segment5 OR
             master_cc_sales.segment5 <> org_cc_sales.segment5 OR
             org_cc_cost_of_sales.segment1 <> mp_cc_cost_of_sales.segment1 OR
             org_cc_sales.segment1 <> mp_cc_sales.segment1 OR
             nvl(msi_master.attribute4, '-1') !=
             nvl(msi_org.attribute4, '-1') OR
             nvl(msi_master.attribute5, '-1') !=
             nvl(msi_org.attribute5, '-1') OR
             nvl(msi_master.attribute6, '-1') !=
             nvl(msi_org.attribute6, '-1') OR
             nvl(msi_master.attribute7, '-1') !=
             nvl(msi_org.attribute7, '-1'))
         AND msi_org.organization_id = io_org.organization_id
         AND msi_org.organization_id =
             nvl(p_sync_organization_id, msi_org.organization_id) ---parameter
         AND msi_master.segment1 = nvl(p_item, msi_master.segment1); ---parameter
  
    v_item_rec inv_item_grp.item_rec_type;
    ---v_item_rec_out inv_item_grp.item_rec_type;
    v_error_tbl inv_item_grp.error_tbl_type;
  
    v_items_counter NUMBER := 0;
    ---v_successfuly_updated_items    NUMBER := 0;
    v_failured_items_count         NUMBER := 0;
    v_step                         VARCHAR2(100);
    v_new_cogs_concatenated_seg    VARCHAR2(300);
    v_new_revenue_concatenated_seg VARCHAR2(300);
    v_previous_inv_organization_id NUMBER;
    v_coa_id                       NUMBER;
    v_cost_of_sales_account_id     NUMBER;
    v_sales_account_id             NUMBER;
    v_return_status                VARCHAR2(100);
    v_err_msg                      VARCHAR2(30000);
    ---v_cogs_str                     VARCHAR2(300);
    ---v_revenue_str                  VARCHAR2(300);
    --v_organization_id NUMBER;
    v_api_error_msg               VARCHAR2(30000);
    l_cost_of_sales_accounts_cntr NUMBER := 0; ---new cost_of_sales_accounts were created
    l_sales_revenue_account_cntr  NUMBER := 0; ---new sales (revenue) accounts were created
    v_success_inserted_items_cntr NUMBER := 0; ---records were inserted into MTL_SYSTEM_ITEMS_INTERFACE
    v_conc_request_id             NUMBER := fnd_global.conc_request_id; ---for curr concurrent program
    v_concurrent_request_id       NUMBER; ---for "Import Items" concurrent program --see submit request below
    ---- out variables for fnd_concurrent.wait_for_request-----
    ---x_phase       VARCHAR2(100);
    ---x_status      VARCHAR2(100);
    ---x_dev_phase   VARCHAR2(100);
    ---x_dev_status  VARCHAR2(100);
    ---x_return_bool BOOLEAN;
    ---x_message     VARCHAR2(100);
    stop_processing            EXCEPTION;
    stop_process_for_this_item EXCEPTION;
    l_coa_name VARCHAR2(150);
  
  BEGIN
    fnd_file.put_line(fnd_file.log,
                      '============ START: ' ||
                      to_char(SYSDATE, 'DD-MON-YYYY HH24:MI:SS') ||
                      ' =============== request_id=' || v_conc_request_id ||
                      ' ===============');
    fnd_file.put_line(fnd_file.log,
                      '================ PARAMETERS ==============');
    fnd_file.put_line(fnd_file.log,
                      '====== p_sync_org_id=' || p_sync_organization_id);
    IF p_item IS NOT NULL THEN
      fnd_file.put_line(fnd_file.log, 'p_item=' || p_item);
    END IF;
  
    p_errcode := 0;
    p_errbuff := NULL;
    v_step    := 'Step 1';
  
    FOR item_rec IN get_org_items LOOP
      v_item_rec                     := inv_item_grp.g_miss_item_rec;
      v_cost_of_sales_account_id     := NULL;
      v_sales_account_id             := NULL;
      v_new_cogs_concatenated_seg    := NULL;
      v_new_revenue_concatenated_seg := NULL;
      v_api_error_msg                := NULL;
      v_err_msg                      := NULL;
      v_error_tbl.delete;
      v_items_counter := v_items_counter + 1;
    
      IF v_previous_inv_organization_id IS NULL OR
         v_previous_inv_organization_id != item_rec.organization_id THEN
      
        v_step := 'Step 2';
        ----Get coa_id-----------  
        v_coa_id   := get_org_coa_id(item_rec.organization_id); --cr967
        l_coa_name := get_coa_name(v_coa_id); -- cr967
      
        /*  v_organization_id := item_rec.organization_id;
        v_coa_id          := xxgl_utils_pkg.get_coa_id_from_inv_org(item_rec.master_organization_id,
                                                                    v_organization_id);*/
      END IF;
    
      v_previous_inv_organization_id := item_rec.organization_id;
    
      BEGIN
      
        v_step := 'Step 3';
        IF item_rec.cost_of_sales_account_dif_flag = 'Y' THEN
        
          ---There is a difference in Cogs account (Segment1 or Segment5)
          v_step := 'Step 4';
        
          -- fnd_file.put_line(fnd_file.log, 'l_coa_name=' || l_coa_name);
        
          IF l_coa_name = 'XX_STRATASYS_USD' THEN
            --cr 967 adjust segments according to chart of account
            v_new_cogs_concatenated_seg :=  -----item_rec.org_cost_of_sales_segment1 || '.' ||
             item_rec.mp_cost_of_sales_segment1 || '.' ||
                                           item_rec.org_cost_of_sales_segment2 || '.' ||
                                           item_rec.org_cost_of_sales_segment3 || '.' ||
                                           item_rec.master_cost_of_sales_segment5 || '.' ||
                                           item_rec.org_cost_of_sales_segment6 || '.' ||
                                           item_rec.org_cost_of_sales_segment7 || '.' ||
                                           '000' || '.' || '0000';
          
          ELSE
            v_new_cogs_concatenated_seg :=  -----item_rec.org_cost_of_sales_segment1 || '.' ||
             item_rec.mp_cost_of_sales_segment1 || '.' ||
                                           item_rec.org_cost_of_sales_segment2 || '.' ||
                                           item_rec.org_cost_of_sales_segment3 || '.' ||
                                           item_rec.org_cost_of_sales_segment4 || '.' ||
                                           item_rec.master_cost_of_sales_segment5 || '.' ||
                                           item_rec.org_cost_of_sales_segment6 || '.' ||
                                           item_rec.org_cost_of_sales_segment7 || '.' ||
                                           item_rec.org_cost_of_sales_segment8 || '.' ||
                                           item_rec.org_cost_of_sales_segment9;
          
          END IF;
        
          -----------Check/Create new code combination for cost_of_sales_account------------
          BEGIN
            SELECT cc.code_combination_id
              INTO v_cost_of_sales_account_id
              FROM gl_code_combinations_kfv cc
             WHERE cc.concatenated_segments = v_new_cogs_concatenated_seg
               AND cc.enabled_flag = 'Y';
          
          EXCEPTION
            WHEN no_data_found THEN
              ---new cost_of_sales_accounts should be created
              l_cost_of_sales_accounts_cntr := l_cost_of_sales_accounts_cntr + 1;
              xxgl_utils_pkg.get_and_create_account(p_concat_segment      => v_new_cogs_concatenated_seg,
                                                    p_coa_id              => v_coa_id,
                                                    x_code_combination_id => v_cost_of_sales_account_id,
                                                    x_return_code         => v_return_status,
                                                    x_err_msg             => v_err_msg);
            
              IF v_return_status != fnd_api.g_ret_sts_success THEN
                v_api_error_msg := 'API ERROR! We cannot create new code combination for Cost Of Goods Sold Account: ' ||
                                   v_err_msg;
                RAISE stop_process_for_this_item;
              END IF;
          END;
          ----------------- 
        ELSE
          ---No difference between Master and Org Item
          v_cost_of_sales_account_id := item_rec.org_cost_of_sales_account;
        END IF;
      
        IF item_rec.sales_account_diff_flag = 'Y' THEN
        
          ---There is a difference in Revenue account (Segment1 or Segment5)
          v_step := 'Step 5';
          IF l_coa_name = 'XX_STRATASYS_USD' THEN
            -- cr 967
            --cr 967 adjust segments according to chart of account
            v_new_revenue_concatenated_seg :=  ----item_rec.org_sales_segment1 || '.' ||
             item_rec.mp_sales_segment1 || '.' ||
                                              item_rec.org_sales_segment2 || '.' ||
                                              item_rec.org_sales_segment3 || '.' ||
                                             
                                              item_rec.master_sales_segment5 || '.' ||
                                              item_rec.org_sales_segment6 || '.' ||
                                              item_rec.org_sales_segment7 || '.' ||
                                              '000' || '.' || '0000';
          
          ELSE
            v_new_revenue_concatenated_seg :=  ----item_rec.org_sales_segment1 || '.' ||
             item_rec.mp_sales_segment1 || '.' ||
                                              item_rec.org_sales_segment2 || '.' ||
                                              item_rec.org_sales_segment3 || '.' ||
                                              item_rec.org_sales_segment4 || '.' ||
                                              item_rec.master_sales_segment5 || '.' ||
                                              item_rec.org_sales_segment6 || '.' ||
                                              item_rec.org_sales_segment7 || '.' ||
                                              item_rec.org_sales_segment8 || '.' ||
                                              item_rec.org_sales_segment9;
          END IF;
        
          -----------Check/Create new code combination for sales_account--(revenue account)----------
          BEGIN
            SELECT cc.code_combination_id
              INTO v_sales_account_id
              FROM gl_code_combinations_kfv cc
             WHERE cc.concatenated_segments =
                   v_new_revenue_concatenated_seg
               AND cc.enabled_flag = 'Y';
          
          EXCEPTION
            WHEN no_data_found THEN
              l_sales_revenue_account_cntr := l_sales_revenue_account_cntr + 1;
              xxgl_utils_pkg.get_and_create_account(p_concat_segment      => v_new_revenue_concatenated_seg,
                                                    p_coa_id              => v_coa_id,
                                                    x_code_combination_id => v_sales_account_id,
                                                    x_return_code         => v_return_status,
                                                    x_err_msg             => v_err_msg);
            
              IF v_return_status != fnd_api.g_ret_sts_success THEN
                v_api_error_msg := 'API ERROR! We cannot create new code combination for Revenue Account ' ||
                                   v_err_msg;
                RAISE stop_process_for_this_item;
              END IF;
          END;
          -----------------
        ELSE
          ---No difference between Master and Org Item
          v_sales_account_id := item_rec.org_sales_account;
        END IF;
        v_step := 'Step 40';
        INSERT INTO mtl_system_items_interface
          (inventory_item_id,
           organization_id,
           process_flag,
           transaction_type,
           set_process_id,
           inventory_item_status_code,
           enabled_flag,
           contract_item_type_code,
           primary_uom_code,
           primary_unit_of_measure,
           item_type,
           cost_of_sales_account,
           sales_account,
           attribute4,
           attribute5,
           attribute6,
           attribute7)
        VALUES
          (item_rec.inventory_item_id,
           item_rec.organization_id,
           1,
           'UPDATE',
           v_conc_request_id, ---set_process_id 
           item_rec.inventory_item_status_code,
           item_rec.enabled_flag,
           item_rec.contract_item_type_code,
           item_rec.primary_uom_code,
           item_rec.primary_unit_of_measure,
           item_rec.item_type,
           v_cost_of_sales_account_id,
           v_sales_account_id,
           item_rec.attribute4,
           item_rec.attribute5,
           item_rec.attribute6,
           item_rec.attribute7);
        v_success_inserted_items_cntr := v_success_inserted_items_cntr + 1;
        IF MOD(v_success_inserted_items_cntr, 500) = 0 THEN
          COMMIT;
          /*fnd_file.put_line(fnd_file.log,
          '******** ' || v_success_inserted_items_cntr ||
          ' records inserted and COMMITED' || ' ********');*/
        END IF;
      
      EXCEPTION
        WHEN stop_process_for_this_item THEN
          v_failured_items_count := v_failured_items_count + 1;
          fnd_file.put_line(fnd_file.log, v_api_error_msg);
        WHEN OTHERS THEN
          v_failured_items_count := v_failured_items_count + 1;
          fnd_file.put_line(fnd_file.log,
                            'Unexpected Error when insert into MTL_SYSTEM_ITEMS_INTERFACE' ||
                            SQLERRM);
      END;
    END LOOP;
  
    COMMIT; ---=======COMMIT=======COMMIT=======COMMIT=======
  
    v_step := 'Step 50';
    IF l_cost_of_sales_accounts_cntr > 0 THEN
      fnd_file.put_line(fnd_file.log,
                        l_cost_of_sales_accounts_cntr ||
                        ' new cost of sales accounts were created');
    END IF;
    IF l_sales_revenue_account_cntr > 0 THEN
      fnd_file.put_line(fnd_file.log,
                        l_sales_revenue_account_cntr ||
                        ' new sales (revenue) accounts were created');
    END IF;
    fnd_file.put_line(fnd_file.log,
                      v_success_inserted_items_cntr ||
                      ' ITEMS SUCCESSFULLY INSERTED into MTL_SYSTEM_ITEMS_INTERFACE with set_process_id=' ||
                      v_conc_request_id);
    IF v_failured_items_count > 0 THEN
      fnd_file.put_line(fnd_file.log,
                        v_failured_items_count ||
                        ' ITEMS FAILED before insert into MTL_SYSTEM_ITEMS_INTERFACE');
    END IF;
  
    IF v_success_inserted_items_cntr = 0 THEN
      fnd_file.put_line(fnd_file.log,
                        '==========================================================================================================');
      fnd_file.put_line(fnd_file.log,
                        '===============NO RECORDS INSERTED into MTL_SYSTEM_ITEMS_INTERFACE for update organization items==========');
      fnd_file.put_line(fnd_file.log,
                        '==========================================================================================================');
    ELSE
      --===================== SUBMIT RERQUEST ===================================
      v_step := 'Step 60';
      ---Submit concurrent program 'Import Items' / INCOIN-------------------
      ----x_return_bool := fnd_request.set_print_options(NULL, NULL, 0, TRUE, 'N');
    
      v_concurrent_request_id := fnd_request.submit_request(application => 'INV',
                                                            program     => 'INCOIN', ---Import Items
                                                            argument1   => p_sync_organization_id, --- p_org_id 
                                                            argument2   => 2, --No--- p_all_org      ---All organizations
                                                            argument3   => 1, --Yes--- p_val_item_flag---Validate Items
                                                            argument4   => 1, --Yes--- --- p_pro_item_flag---Process Items
                                                            argument5   => 1, --Yes--- --- p_del_rec_flag ---Delete Processed Rows
                                                            argument6   => v_conc_request_id, --- p_xset_id      ---Process Set (Null for All)
                                                            argument7   => 2, --Update Existing Items---p_run_mode ---Create or Update Items
                                                            argument8   => 1 --Yes--- --- p_gather_stats ---Gather Statistics
                                                            );
    
      COMMIT;
    
      v_step := 'Step 70';
      IF v_concurrent_request_id > 0 THEN
        fnd_file.put_line(fnd_file.log,
                          'Concurrent ''Import Items'' was SUBMITTED successfully (request_id=' ||
                          v_concurrent_request_id || ')');
        /* ---------
        LOOP
          x_return_bool := fnd_concurrent.wait_for_request(v_concurrent_request_id,
                                                           5, --- interval 10  seconds
                                                           3600, ---- max wait 1 hour
                                                           x_phase,
                                                           x_status,
                                                           x_dev_phase,
                                                           x_dev_status,
                                                           x_message);
          EXIT WHEN x_return_bool AND upper(x_dev_phase) = 'COMPLETE';
        
        END LOOP;
        IF upper(x_dev_phase) = 'COMPLETE' AND
           upper(x_dev_status) IN ('ERROR', 'WARNING') THEN
          fnd_file.put_line(fnd_file.log,
                            'Concurrent ''Import Items'' concurrent program completed in ' ||
                            upper(x_dev_status) ||
                            '. See log for request_id=' ||
                            v_concurrent_request_id);
        
        ELSIF upper(x_dev_phase) = 'COMPLETE' AND
              upper(x_dev_status) = 'NORMAL' THEN
          fnd_file.put_line(fnd_file.log,
                            'Concurrent ''Import Items'' was SUCCESSFULLY COMPLETED (request_id=' ||
                            v_concurrent_request_id || ')');
        ELSE
          v_err_msg := 'Concurrent ''Import Items'' failed , review log (request_id=' ||
                       v_concurrent_request_id || ')';
          fnd_file.put_line(fnd_file.log, v_err_msg);
          p_errbuff := v_err_msg;
          p_errcode := '2';
          RAISE stop_processing;
        END IF;*/
      ELSE
        fnd_file.put_line(fnd_file.log,
                          'Concurrent ''Import Items'' submitting PROBLEM');
      END IF;
    END IF;
  
    fnd_file.put_line(fnd_file.log,
                      '======================== THIS PROGRAM IS COMPLETED ============================');
  
  EXCEPTION
  
    WHEN OTHERS THEN
      p_errbuff := 1;
      fnd_file.put_line(fnd_file.log,
                        'XXINV_UPD_ORG_ITEM_PKG.copy_account_from_master_item2 unexpected ERROR (' ||
                        'Item=' || v_item_rec.item_number || ' ' || v_step ||
                        ') : ' || SQLERRM);
      fnd_file.put_line(fnd_file.log,
                        ' =============XXINV_UPD_ORG_ITEM_PKG.copy_account_from_master_item2 unexpected ERROR (' ||
                        v_step || ') : ' || SQLERRM);
      RAISE;
  END copy_account_from_master_item2;
  ----------------------------------------------

  FUNCTION get_value_from_line(p_line_string IN OUT VARCHAR2,
                               p_err_msg     IN OUT VARCHAR2,
                               p_counter     IN NUMBER,
                               c_delimiter   IN VARCHAR2) RETURN VARCHAR2 IS
  
    l_pos        NUMBER;
    l_char_value VARCHAR2(20);
  
  BEGIN
    p_err_msg := NULL;
    l_pos     := instr(p_line_string, c_delimiter);
  
    IF nvl(l_pos, 0) < 1 THEN
      l_pos := length(p_line_string);
    END IF;
  
    l_char_value := ltrim(rtrim(substr(p_line_string, 1, l_pos - 1)));
  
    p_line_string := substr(p_line_string, l_pos + 1);
  
    RETURN l_char_value;
  
  END get_value_from_line;

  PROCEDURE load_minmax_quantities(p_location IN VARCHAR2,
                                   p_filename IN VARCHAR2) IS
  
    t_item_rec     inv_item_grp.item_rec_type;
    t_item_rec_out inv_item_grp.item_rec_type;
    -- t_rev_rec      inv_item_grp.item_revision_rec_type;
    l_error_tbl inv_item_grp.error_tbl_type;
    t_orig_item mtl_system_items_b%ROWTYPE;
  
    l_file_hundler   utl_file.file_type;
    l_counter        NUMBER := 0;
    l_line_buffer    VARCHAR2(2000);
    l_err_msg        VARCHAR2(500);
    l_pos            NUMBER;
    l_return_status  VARCHAR2(1);
    l_org_code       mtl_parameters.organization_code%TYPE;
    l_item_num       mtl_system_items_b.segment1%TYPE;
    l_max_minmax_qty mtl_system_items_b.max_minmax_quantity%TYPE;
    l_min_minmax_qty mtl_system_items_b.min_minmax_quantity%TYPE;
  
    c_delimiter CONSTANT VARCHAR2(1) := ',';
  
  BEGIN
  
    BEGIN
      l_file_hundler := utl_file.fopen(location     => p_location,
                                       filename     => p_filename,
                                       open_mode    => 'r',
                                       max_linesize => 32000);
    
    EXCEPTION
      WHEN utl_file.invalid_path THEN
        fnd_file.put_line(fnd_file.log,
                          'Invalid Path for ' || ltrim(p_filename));
        RAISE;
      WHEN utl_file.invalid_mode THEN
        fnd_file.put_line(fnd_file.log,
                          'Invalid Mode for ' || ltrim(p_filename));
        RAISE;
      WHEN utl_file.invalid_operation THEN
        fnd_file.put_line(fnd_file.log,
                          'Invalid operation for ' || ltrim(p_filename) ||
                          SQLERRM);
        RAISE;
      WHEN OTHERS THEN
        fnd_file.put_line(fnd_file.log, 'Other for ' || ltrim(p_filename));
        RAISE;
    END;
    -- Loop For All File's Lines
    LOOP
    
      BEGIN
        -- goto next line
      
        l_counter        := l_counter + 1;
        l_err_msg        := NULL;
        l_return_status  := NULL;
        l_org_code       := NULL;
        l_item_num       := NULL;
        l_max_minmax_qty := NULL;
        l_min_minmax_qty := NULL;
      
        BEGIN
          utl_file.get_line(file   => l_file_hundler,
                            buffer => l_line_buffer);
        EXCEPTION
          WHEN utl_file.read_error THEN
            l_err_msg := 'Read Error for line: ' || l_counter;
            RAISE invalid_item;
          WHEN no_data_found THEN
            EXIT;
          WHEN OTHERS THEN
            l_err_msg := 'Read Error for line: ' || l_counter ||
                         ', Error: ' || SQLERRM;
            RAISE invalid_item;
        END;
      
        IF l_counter > 1 THEN
        
          l_pos := 0;
        
          l_org_code       := get_value_from_line(l_line_buffer,
                                                  l_err_msg,
                                                  l_counter,
                                                  c_delimiter);
          l_item_num       := get_value_from_line(l_line_buffer,
                                                  l_err_msg,
                                                  l_counter,
                                                  c_delimiter);
          l_min_minmax_qty := to_number(get_value_from_line(l_line_buffer,
                                                            l_err_msg,
                                                            l_counter,
                                                            c_delimiter));
          l_max_minmax_qty := to_number(get_value_from_line(l_line_buffer,
                                                            l_err_msg,
                                                            l_counter,
                                                            c_delimiter));
        
          -- Ask Hod for validations
          BEGIN
          
            SELECT msi.*
              INTO t_orig_item
              FROM mtl_system_items_b msi, mtl_parameters mp
             WHERE msi.segment1 = l_item_num
               AND msi.organization_id = mp.organization_id
               AND mp.organization_code = l_org_code;
          
          EXCEPTION
            WHEN no_data_found THEN
              l_err_msg := 'Invalid item.organization';
              RAISE invalid_item;
          END;
        
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
          t_item_rec.min_minmax_quantity        := nvl(l_min_minmax_qty,
                                                       fnd_api.g_miss_num);
          t_item_rec.max_minmax_quantity        := nvl(l_max_minmax_qty,
                                                       fnd_api.g_miss_num);
        
          inv_item_grp.update_item(p_commit           => fnd_api.g_false,
                                   p_lock_rows        => fnd_api.g_false,
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
        
        END IF; -- data rows
      
      EXCEPTION
        WHEN invalid_item THEN
          fnd_file.put_line(fnd_file.log, l_err_msg);
          ROLLBACK;
        WHEN OTHERS THEN
          l_err_msg := SQLERRM;
          fnd_file.put_line(fnd_file.log, l_err_msg);
          ROLLBACK;
      END;
    
    END LOOP;
  
    utl_file.fclose(l_file_hundler);
  
    COMMIT;
  
  END load_minmax_quantities;

END xxinv_upd_org_item_pkg;
/
