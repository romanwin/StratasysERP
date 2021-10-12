CREATE OR REPLACE PACKAGE BODY xxs3_ptm_item_recon_pkg AS
  p_item     VARCHAR2(100);
  p_org_code VARCHAR2(10);

  ----------------------------------------------------------------------------
  --  Name:            xxs3_ptm_item_recon_main_prc
  --  Create by:       V.V.SATEESH
  --  Revision:        1.0
  --  Creation date:  10/11/2016
  ----------------------------------------------------------------------------
  --  Purpose :        Item Master Extract Recon Report
  ----------------------------------------------------------------------------
  --  Ver  Date        Name                         Description
  --  1.0 17/08/2016  V.V.SATEESH                   Initial build
  ----------------------------------------------------------------------------

  PROCEDURE xxs3_ptm_item_recon_prc(x_errbuf   OUT VARCHAR2
                                   ,x_retcode  OUT NUMBER
                                   ,p_item     IN VARCHAR2
                                   ,p_org_code IN VARCHAR2) IS
  
    l_dynamic_insert      VARCHAR2(3000);
    l_dyn_statement       VARCHAR2(3000);
    l_err_code            VARCHAR2(4000);
    l_err_msg             VARCHAR2(4000);
    p_sysdate             DATE;
    l_buyer_dq_st         VARCHAR2(3000);
    l_attr_st             VARCHAR2(3000);
    l_dq_name             VARCHAR2(50);
    l_user_attribute_name VARCHAR2(150);
    l_controlled_at       VARCHAR2(150);
    l_group_name          VARCHAR2(150);
    l_attribute_name      VARCHAR2(150);
  
    CURSOR c_main IS
      SELECT *
      FROM   xxobjt.xxs3_ptm_master_items_stg
            ,xxobjt.xxs3_ptm_item_columns
      WHERE  segment1 = nvl(p_item, segment1)
      AND    legacy_organization_code = p_org_code;
  
    CURSOR c_erule IS
      SELECT segment1
      FROM   xxobjt.xxs3_ptm_master_items_stg
      WHERE  segment1 = nvl(p_item, segment1)
      AND    legacy_organization_code = p_org_code;
  
    CURSOR c_test(p_segment1 VARCHAR2) IS
      SELECT nvl(extract_rule, 'bom') extract_rule
      FROM   (SELECT 'EXT-RULE-10' extract_rule
              FROM   mtl_system_items_b msi
              WHERE  EXISTS
               (SELECT mtt.inventory_item_id
                      FROM   mtl_material_transactions mtt
                      WHERE  mtt.inventory_item_id = msi.inventory_item_id
                      AND    mtt.creation_date > SYSDATE - 730)
              AND    (SELECT organization_code
                      FROM   mtl_parameters
                      WHERE  organization_id = msi.organization_id) =
                     p_org_code -- 'OMA'
              AND    segment1 = p_segment1
              UNION
              SELECT 'EXT-RULE-20' extract_rule
              FROM   mtl_system_items_b msi
              WHERE  EXISTS
               (SELECT ool.inventory_item_id
                      FROM   oe_order_lines_all ool
                      WHERE  ool.inventory_item_id = msi.inventory_item_id
                      AND    ool.creation_date > SYSDATE - 730)
              AND    (SELECT organization_code
                      FROM   mtl_parameters
                      WHERE  organization_id = msi.organization_id) =
                     p_org_code --'OMA'
              AND    segment1 = p_segment1
              UNION
              SELECT 'EXT-RULE-30' extract_rule
              FROM   mtl_system_items_b msi
              WHERE  EXISTS
               (SELECT mmt.inventory_item_id
                      FROM   mtl_onhand_quantities mmt
                      WHERE  mmt.inventory_item_id = msi.inventory_item_id)
              AND    (SELECT organization_code
                      FROM   mtl_parameters
                      WHERE  organization_id = msi.organization_id) =
                     p_org_code --'OMA'
              AND    segment1 = p_segment1
              UNION
              SELECT 'EXT-RULE-40' extract_rule
              FROM   mtl_system_items_b msi
              WHERE  msi.inventory_item_status_code = 'Active PTO'
              AND    (SELECT organization_code
                      FROM   mtl_parameters
                      WHERE  organization_id = msi.organization_id) =
                     p_org_code --'OMA'
              AND    segment1 = p_segment1
              UNION
              SELECT 'EXT-RULE-50' extract_rule
              FROM   mtl_system_items_b msi
              WHERE  msi.inventory_item_status_code IN
                     ('XX_BETA', 'Inactive', 'Active', 'XX_PROD')
              AND    (msi.segment1 LIKE ('%-S') OR
                    msi.segment1 LIKE ('%-CS'))
              AND    (SELECT organization_code
                      FROM   mtl_parameters
                      WHERE  organization_id = msi.organization_id) =
                     p_org_code --'OMA'
              AND    segment1 = p_segment1
              UNION
              SELECT 'EXT-RULE-60' extract_rule
              FROM   mtl_system_items_b msi
              WHERE  msi.creation_date > SYSDATE - 365
              AND    (SELECT organization_code
                      FROM   mtl_parameters
                      WHERE  organization_id = msi.organization_id) =
                     p_org_code -- 'OMA'
              AND    segment1 = p_segment1
              UNION
              SELECT 'EXT-RULE-70' extract_rule
              FROM   mtl_system_items_b msi
              WHERE  msi.inventory_item_status_code IN
                     ('Obsolete', 'XX_DISCONT')
              AND    msi.comms_nl_trackable_flag IS NOT NULL
              AND    (SELECT organization_code
                      FROM   mtl_parameters
                      WHERE  organization_id = msi.organization_id) =
                     p_org_code --'OMA'
              AND    segment1 = p_segment1
              UNION
              SELECT 'EXT-RULE-75' extract_rule
              FROM   mtl_system_items_b msi
              WHERE  msi.item_type = 'PTO'
              AND    (SELECT organization_code
                      FROM   mtl_parameters
                      WHERE  organization_id = msi.organization_id) =
                     p_org_code -- 'OMA'
              AND    segment1 = p_segment1);
  
    CURSOR c_dq_name(p_dq_column VARCHAR2, p_dq_segment1 VARCHAR2) IS
      SELECT DISTINCT rule_name
      FROM   xxobjt.xxs3_ptm_mtl_mstr_items_dq_stg
      WHERE  dq_column = p_dq_column
      AND    segment1 = p_dq_segment1;
  
    l_count NUMBER := 1;
  
    l_extract_rule_conc VARCHAR2(1000);
    l_eqt_rule_con      VARCHAR2(1000);
    l_dq_concat         VARCHAR2(100);
    l_dq_concat_st      VARCHAR2(100);
    l_dq_concata        VARCHAR2(100);
    l_dq_concat_sta     VARCHAR2(100);
  
  BEGIN
    EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.XXS3_PTM_ITEM_EQT_RECON_STG';
  
    fnd_file.put_line(fnd_file.log, 'Insert Item Number and Columns in the Stage Table');
  
    FOR r IN c_main LOOP
      INSERT INTO xxobjt.xxs3_ptm_item_eqt_recon_stg
        (row_id
        ,item
        ,item_column_name)
      VALUES
        (xxs3_ptm_item_eqt_rcn_stg_seq.NEXTVAL
        ,r.segment1
        ,r.column_name);
    
    END LOOP;
    COMMIT;
    fnd_file.put_line(fnd_file.log, 'End of the Insert of Item Number and Columns in Stage table');
    BEGIN
      fnd_file.put_line(fnd_file.log, 'Get the Extract Rules Cursor');
    
      FOR k IN c_erule LOOP
        FOR i IN c_test(k.segment1) LOOP
        
          l_eqt_rule_con := l_eqt_rule_con || ',' || i.extract_rule;
        
        END LOOP;
      
      END LOOP;
      fnd_file.put_line(fnd_file.log, 'Extract Rules for Item' ||
                         l_eqt_rule_con);
    
      l_extract_rule_conc := l_eqt_rule_con;
    
    EXCEPTION
      WHEN OTHERS THEN
        fnd_file.put_line(fnd_file.log, 'Exception in Extract Rules for Item' ||
                           SQLERRM);
      
    END;
  
    l_attr_st := 'select distinct user_attribute_name,control_level_dsp,user_group_name
      FROM   mtl_item_attribute_values_v
      where SUBSTR(ATTRIBUTE_NAME,18)=:1
      AND segment1=:2 AND ORGANIZATION_ID=:3 ';
  
    fnd_file.put_line(fnd_file.log, 'Begin Update the Attribute values');
    FOR k IN c_main LOOP
    
      IF k.column_name = 'BUYER_ID' THEN
        BEGIN
        
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'BUYER_ID', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
      
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   -- p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.legacy_buyer_id, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.s3_buyer_number, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, --'',
                                   p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, -- '',
                                   p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, --'',
                                   p_attr_name_val => l_user_attribute_name, --'',
                                   p_org_mstr_cntrl_val => l_controlled_at, -- '',
                                   p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'BUYER_ID', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
    
      IF k.column_name = 'INVENTORY_ITEM_ID' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'INVENTORY_ITEM_ID', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
      
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.l_inventory_item_id, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => '', p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, --'',
                                   p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, -- '',
                                   p_attr_name_val => l_user_attribute_name, --'',
                                   p_org_mstr_cntrl_val => l_controlled_at, -- '',            
                                   p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'INVENTORY_ITEM_ID', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
    
      IF k.column_name = 'PURCHASING_ITEM_FLAG' THEN
      
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'PURCHASING_ITEM_FLAG', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
      
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.purchasing_item_flag, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.purchasing_item_flag, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, -- '',
                                   p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, --'',
                                   p_attr_name_val => l_user_attribute_name, --'',
                                   p_org_mstr_cntrl_val => l_controlled_at, --'',            
                                   p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'PURCHASING_ITEM_FLAG', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
    
      IF k.column_name = 'INVENTORY_ITEM_FLAG' THEN
      
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'INVENTORY_ITEM_FLAG', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
      
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.inventory_item_flag, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.inventory_item_flag, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'INVENTORY_ITEM_FLAG', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'ALLOW_EXPRESS_DELIVERY_FLAG' THEN
      
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'ALLOW_EXPRESS_DELIVERY_FLAG', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
      
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.allow_express_delivery_flag, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.allow_express_delivery_flag, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'ALLOW_EXPRESS_DELIVERY_FLAG', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'DAYS_EARLY_RECEIPT_ALLOWED' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'DAYS_EARLY_RECEIPT_ALLOWED', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
      
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.days_early_receipt_allowed, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.days_early_receipt_allowed, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'DAYS_EARLY_RECEIPT_ALLOWED', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'DAYS_LATE_RECEIPT_ALLOWED' THEN
      
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'DAYS_EARLY_RECEIPT_ALLOWED', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
      
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.days_late_receipt_allowed, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.days_late_receipt_allowed, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'DAYS_LATE_RECEIPT_ALLOWED', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'RECEIPT_DAYS_EXCEPTION_CODE' THEN
      
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'RECEIPT_DAYS_EXCEPTION_CODE', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
      
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.receipt_days_exception_code, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.receipt_days_exception_code, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'RECEIPT_DAYS_EXCEPTION_CODE', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'RECEIVING_ROUTING_ID' THEN
      
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'RECEIVING_ROUTING_ID', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.receiving_routing_id, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.s3_receiving_routing_id, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'RECEIVING_ROUTING_ID', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'AUTO_LOT_ALPHA_PREFIX' THEN
      
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'AUTO_LOT_ALPHA_PREFIX', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.auto_lot_alpha_prefix, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.auto_lot_alpha_prefix, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'AUTO_LOT_ALPHA_PREFIX', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'START_AUTO_LOT_NUMBER' THEN
      
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'START_AUTO_LOT_NUMBER', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
      
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.start_auto_lot_number, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.start_auto_lot_number, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'START_AUTO_LOT_NUMBER', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'LOT_CONTROL_CODE' THEN
      
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'LOT_CONTROL_CODE', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
      
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.lot_control_code, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.lot_control_code, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'LOT_CONTROL_CODE', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'SHELF_LIFE_CODE' THEN
      
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'SHELF_LIFE_CODE', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
      
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.shelf_life_code, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.shelf_life_code, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'SHELF_LIFE_CODE', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'SHELF_LIFE_DAYS' THEN
      
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'SHELF_LIFE_DAYS', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
      
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.shelf_life_days, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.shelf_life_days, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'SHELF_LIFE_DAYS', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'SERIAL_NUMBER_CONTROL_CODE' THEN
      
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'SERIAL_NUMBER_CONTROL_CODE', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.serial_number_control_code, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.serial_number_control_code, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'SERIAL_NUMBER_CONTROL_CODE', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'SOURCE_TYPE' THEN
      
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'SOURCE_TYPE', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.source_type, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.source_type, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'SOURCE_TYPE', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'SOURCE_SUBINVENTORY' THEN
      
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'SOURCE_SUBINVENTORY', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.source_subinventory, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.source_subinventory, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'SOURCE_SUBINVENTORY', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'EXPENSE_ACCOUNT' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'EXPENSE_ACCOUNT', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.expense_account, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.expense_account, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'EXPENSE_ACCOUNT', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'RESTRICT_SUBINVENTORIES_CODE' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'RESTRICT_SUBINVENTORIES_CODE', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.restrict_subinventories_code, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.restrict_subinventories_code, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'RESTRICT_SUBINVENTORIES_CODE', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'UNIT_WEIGHT' THEN
      
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'UNIT_WEIGHT', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.unit_weight, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.unit_weight, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'UNIT_WEIGHT', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'WEIGHT_UOM_CODE' THEN
      
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'WEIGHT_UOM_CODE', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
      
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.weight_uom_code, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.weight_uom_code, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'WEIGHT_UOM_CODE', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'VOLUME_UOM_CODE' THEN
      
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'VOLUME_UOM_CODE', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
        
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
      
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.volume_uom_code, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.volume_uom_code, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'VOLUME_UOM_CODE', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'UNIT_VOLUME' THEN
      
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'UNIT_VOLUME', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
      
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.unit_volume, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.unit_volume, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'UNIT_VOLUME', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'SHRINKAGE_RATE' THEN
      
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'SHRINKAGE_RATE', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
      
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.shrinkage_rate, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.shrinkage_rate, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'SHRINKAGE_RATE', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'ACCEPTABLE_EARLY_DAYS' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'ACCEPTABLE_EARLY_DAYS', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.acceptable_early_days, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.acceptable_early_days, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'ACCEPTABLE_EARLY_DAYS', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'PLANNING_TIME_FENCE_CODE' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'PLANNING_TIME_FENCE_CODE', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.planning_time_fence_code, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.planning_time_fence_code, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'PLANNING_TIME_FENCE_CODE', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'LEAD_TIME_LOT_SIZE' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'LEAD_TIME_LOT_SIZE', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.lead_time_lot_size, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.lead_time_lot_size, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'LEAD_TIME_LOT_SIZE', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'STD_LOT_SIZE' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'STD_LOT_SIZE', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.std_lot_size, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.std_lot_size, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'STD_LOT_SIZE', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'OVERRUN_PERCENTAGE' THEN
      
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'OVERRUN_PERCENTAGE', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
      
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.overrun_percentage, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.overrun_percentage, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'OVERRUN_PERCENTAGE', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'MRP_CALCULATE_ATP_FLAG' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'MRP_CALCULATE_ATP_FLAG', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
        
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.mrp_calculate_atp_flag, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.mrp_calculate_atp_flag, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'MRP_CALCULATE_ATP_FLAG', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'ACCEPTABLE_RATE_INCREASE' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'ACCEPTABLE_RATE_INCREASE', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.acceptable_rate_increase, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.acceptable_rate_increase, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'ACCEPTABLE_RATE_INCREASE', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'ACCEPTABLE_RATE_DECREASE' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'ACCEPTABLE_RATE_DECREASE', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.acceptable_rate_decrease, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.acceptable_rate_decrease, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'ACCEPTABLE_RATE_DECREASE', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'PLANNING_TIME_FENCE_DAYS' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'PLANNING_TIME_FENCE_DAYS', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
      
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.planning_time_fence_days, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.planning_time_fence_days, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'PLANNING_TIME_FENCE_DAYS', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'END_ASSEMBLY_PEGGING_FLAG' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'END_ASSEMBLY_PEGGING_FLAG', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.end_assembly_pegging_flag, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.end_assembly_pegging_flag, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'END_ASSEMBLY_PEGGING_FLAG', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'BOM_ITEM_TYPE' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'BOM_ITEM_TYPE', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.bom_item_type, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.bom_item_type, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'BOM_ITEM_TYPE', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'PICK_COMPONENTS_FLAG' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'PICK_COMPONENTS_FLAG', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.pick_components_flag, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.pick_components_flag, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'PICK_COMPONENTS_FLAG', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'REPLENISH_TO_ORDER_FLAG' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'REPLENISH_TO_ORDER_FLAG', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
        
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.replenish_to_order_flag, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.replenish_to_order_flag, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'REPLENISH_TO_ORDER_FLAG', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'ATP_COMPONENTS_FLAG' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'ATP_COMPONENTS_FLAG', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.atp_components_flag, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.atp_components_flag, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'ATP_COMPONENTS_FLAG', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'ATP_FLAG' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'ATP_FLAG', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.atp_flag, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.atp_flag, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'ATP_FLAG', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'WIP_SUPPLY_TYPE' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'WIP_SUPPLY_TYPE', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
        
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.wip_supply_type, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.wip_supply_type, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'WIP_SUPPLY_TYPE', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'PRIMARY_UOM_CODE' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'PRIMARY_UOM_CODE', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.primary_uom_code, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.primary_uom_code, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'PRIMARY_UOM_CODE', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'PRIMARY_UNIT_OF_MEASURE' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'PRIMARY_UNIT_OF_MEASURE', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.primary_unit_of_measure, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.primary_unit_of_measure, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'PRIMARY_UNIT_OF_MEASURE', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'ALLOWED_UNITS_LOOKUP_CODE' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'ALLOWED_UNITS_LOOKUP_CODE', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.allowed_units_lookup_code, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.allowed_units_lookup_code, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'ALLOWED_UNITS_LOOKUP_CODE', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'COST_OF_SALES_ACCOUNT' THEN
      
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'COST_OF_SALES_ACCOUNT', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
      
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.cost_of_sales_account, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.cost_of_sales_account, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'COST_OF_SALES_ACCOUNT', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'SALES_ACCOUNT' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'SALES_ACCOUNT', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.sales_account, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.sales_account, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'SALES_ACCOUNT', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'DEFAULT_INCLUDE_IN_ROLLUP_FLAG' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'DEFAULT_INCLUDE_IN_ROLLUP_FLAG', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.default_include_in_rollup_flag, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.default_include_in_rollup_flag, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'DEFAULT_INCLUDE_IN_ROLLUP_FLAG', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'INVENTORY_ITEM_STATUS_CODE' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'INVENTORY_ITEM_STATUS_CODE', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.inventory_item_status_code, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.s3_inventory_item_status_code, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'INVENTORY_ITEM_STATUS_CODE', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'INVENTORY_PLANNING_CODE' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'INVENTORY_PLANNING_CODE', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.inventory_planning_code, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.inventory_planning_code, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'INVENTORY_PLANNING_CODE', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'PLANNER_CODE' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'PLANNER_CODE', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
      
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.planner_code, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.s3_planner_code, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'PLANNER_CODE', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'PLANNING_MAKE_BUY_CODE' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'PLANNING_MAKE_BUY_CODE', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.planning_make_buy_code, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.planning_make_buy_code, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'PLANNING_MAKE_BUY_CODE', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'FIXED_LOT_MULTIPLIER' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'FIXED_LOT_MULTIPLIER', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.fixed_lot_multiplier, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.fixed_lot_multiplier, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'FIXED_LOT_MULTIPLIER', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'ROUNDING_CONTROL_TYPE' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'ROUNDING_CONTROL_TYPE', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.rounding_control_type, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.rounding_control_type, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'ROUNDING_CONTROL_TYPE', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'POSTPROCESSING_LEAD_TIME' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'POSTPROCESSING_LEAD_TIME', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.postprocessing_lead_time, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.postprocessing_lead_time, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'POSTPROCESSING_LEAD_TIME', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'PREPROCESSING_LEAD_TIME' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'PREPROCESSING_LEAD_TIME', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.preprocessing_lead_time, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.preprocessing_lead_time, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'PREPROCESSING_LEAD_TIME', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'FULL_LEAD_TIME' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'FULL_LEAD_TIME', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.full_lead_time, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.full_lead_time, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'FULL_LEAD_TIME', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'MRP_SAFETY_STOCK_PERCENT' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'MRP_SAFETY_STOCK_PERCENT', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.mrp_safety_stock_percent, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.mrp_safety_stock_percent, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'MRP_SAFETY_STOCK_PERCENT', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'MRP_SAFETY_STOCK_CODE' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'MRP_SAFETY_STOCK_CODE', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.mrp_safety_stock_code, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.mrp_safety_stock_code, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'MRP_SAFETY_STOCK_CODE', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'MIN_MINMAX_QUANTITY' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'MIN_MINMAX_QUANTITY', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.min_minmax_quantity, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.min_minmax_quantity, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'MIN_MINMAX_QUANTITY', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'MAX_MINMAX_QUANTITY' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'MAX_MINMAX_QUANTITY', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.max_minmax_quantity, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.max_minmax_quantity, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'MAX_MINMAX_QUANTITY', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'MINIMUM_ORDER_QUANTITY' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'MINIMUM_ORDER_QUANTITY', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.minimum_order_quantity, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.minimum_order_quantity, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'MINIMUM_ORDER_QUANTITY', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'FIXED_ORDER_QUANTITY' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'FIXED_ORDER_QUANTITY', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.fixed_order_quantity, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.fixed_order_quantity, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'FIXED_ORDER_QUANTITY', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'FIXED_DAYS_SUPPLY' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'FIXED_DAYS_SUPPLY', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.fixed_days_supply, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.fixed_days_supply, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'FIXED_DAYS_SUPPLY', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'MAXIMUM_ORDER_QUANTITY' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'MAXIMUM_ORDER_QUANTITY', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.maximum_order_quantity, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.maximum_order_quantity, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'MAXIMUM_ORDER_QUANTITY', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'ATP_RULE_ID' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'ATP_RULE_ID', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.atp_rule_name, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.s3_atp_rule_name, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'ATP_RULE_ID', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
    
      IF k.column_name = 'RESERVABLE_TYPE' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'RESERVABLE_TYPE', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.reservable_type, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.reservable_type, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'RESERVABLE_TYPE', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'VENDOR_WARRANTY_FLAG' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'VENDOR_WARRANTY_FLAG', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.vendor_warranty_flag, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.vendor_warranty_flag, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'VENDOR_WARRANTY_FLAG', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'SERVICEABLE_PRODUCT_FLAG' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'SERVICEABLE_PRODUCT_FLAG', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.serviceable_product_flag, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.serviceable_product_flag, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'SERVICEABLE_PRODUCT_FLAG', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'MATERIAL_BILLABLE_FLAG' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'MATERIAL_BILLABLE_FLAG', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.material_billable_flag, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.material_billable_flag, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'MATERIAL_BILLABLE_FLAG', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'PRORATE_SERVICE_FLAG' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'PRORATE_SERVICE_FLAG', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.prorate_service_flag, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.prorate_service_flag, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'PRORATE_SERVICE_FLAG', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'INVOICEABLE_ITEM_FLAG' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'INVOICEABLE_ITEM_FLAG', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.invoiceable_item_flag, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.invoiceable_item_flag, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'INVOICEABLE_ITEM_FLAG', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'INVOICE_ENABLED_FLAG' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'INVOICE_ENABLED_FLAG', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
        
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.invoice_enabled_flag, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.invoice_enabled_flag, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'INVOICE_ENABLED_FLAG', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'OUTSIDE_OPERATION_FLAG' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'OUTSIDE_OPERATION_FLAG', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
        
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.outside_operation_flag, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.outside_operation_flag, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'OUTSIDE_OPERATION_FLAG', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'OUTSIDE_OPERATION_UOM_TYPE' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'OUTSIDE_OPERATION_UOM_TYPE', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.outside_operation_uom_type, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.outside_operation_uom_type, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'OUTSIDE_OPERATION_UOM_TYPE', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'SAFETY_STOCK_BUCKET_DAYS' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'SAFETY_STOCK_BUCKET_DAYS', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.safety_stock_bucket_days, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.safety_stock_bucket_days, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'SAFETY_STOCK_BUCKET_DAYS', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'COSTING_ENABLED_FLAG' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'COSTING_ENABLED_FLAG', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.costing_enabled_flag, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.costing_enabled_flag, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'COSTING_ENABLED_FLAG', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'CYCLE_COUNT_ENABLED_FLAG' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'CYCLE_COUNT_ENABLED_FLAG', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.cycle_count_enabled_flag, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.cycle_count_enabled_flag, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'CYCLE_COUNT_ENABLED_FLAG', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'ITEM_TYPE' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'ITEM_TYPE', k.segment1, k.legacy_organization_id;
        
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
          
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.item_type, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.s3_item_type, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'ITEM_TYPE', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'SHIP_MODEL_COMPLETE_FLAG' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'SHIP_MODEL_COMPLETE_FLAG', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
      
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.ship_model_complete_flag, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.ship_model_complete_flag, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'SHIP_MODEL_COMPLETE_FLAG', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'MRP_PLANNING_CODE' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'MRP_PLANNING_CODE', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.mrp_planning_code, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.mrp_planning_code, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'MRP_PLANNING_CODE', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'ATO_FORECAST_CONTROL' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'ATO_FORECAST_CONTROL', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.ato_forecast_control, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.ato_forecast_control, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'ATO_FORECAST_CONTROL', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'RELEASE_TIME_FENCE_CODE' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'RELEASE_TIME_FENCE_CODE', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.release_time_fence_code, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.release_time_fence_code, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'RELEASE_TIME_FENCE_CODE', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'RELEASE_TIME_FENCE_DAYS' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'RELEASE_TIME_FENCE_DAYS', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.release_time_fence_days, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.release_time_fence_days, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'RELEASE_TIME_FENCE_DAYS', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'CONTAINER_ITEM_FLAG' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'CONTAINER_ITEM_FLAG', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.container_item_flag, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.container_item_flag, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'CONTAINER_ITEM_FLAG', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'VEHICLE_ITEM_FLAG' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'VEHICLE_ITEM_FLAG', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.vehicle_item_flag, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.vehicle_item_flag, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'VEHICLE_ITEM_FLAG', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'EFFECTIVITY_CONTROL' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'EFFECTIVITY_CONTROL', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.effectivity_control, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.effectivity_control, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'EFFECTIVITY_CONTROL', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'EVENT_FLAG' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'EVENT_FLAG', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.event_flag, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.s3_buyer_number, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'EVENT_FLAG', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'ELECTRONIC_FLAG' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'ELECTRONIC_FLAG', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.electronic_flag, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.electronic_flag, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'ELECTRONIC_FLAG', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'DOWNLOADABLE_FLAG' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'DOWNLOADABLE_FLAG', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.downloadable_flag, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.downloadable_flag, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'DOWNLOADABLE_FLAG', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'COMMS_NL_TRACKABLE_FLAG' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'COMMS_NL_TRACKABLE_FLAG', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
      
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.comms_nl_trackable_flag, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.comms_nl_trackable_flag, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'COMMS_NL_TRACKABLE_FLAG', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'ORDERABLE_ON_WEB_FLAG' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'ORDERABLE_ON_WEB_FLAG', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
        
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.orderable_on_web_flag, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.orderable_on_web_flag, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'ORDERABLE_ON_WEB_FLAG', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'WEB_STATUS' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'WEB_STATUS', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          /* EXECUTE IMMEDIATE l_buyer_dq_st 
            INTO l_dq_name
            USING 'WEB_STATUS',k.segment1; 
            
          exception when no_data_found then 
              dbms_output.put_line('no data found in dq'||l_dq_name);
              l_dq_name:=NULL;
          end;   */
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.web_status, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.web_status, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'WEB_STATUS', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'DIMENSION_UOM_CODE' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'DIMENSION_UOM_CODE', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.dimension_uom_code, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.dimension_uom_code, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'DIMENSION_UOM_CODE', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'UNIT_LENGTH' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'UNIT_LENGTH', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.unit_length, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.unit_length, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'UNIT_LENGTH', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'UNIT_WIDTH' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'UNIT_WIDTH', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.unit_width, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.unit_width, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'UNIT_WIDTH', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'UNIT_HEIGHT' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'UNIT_HEIGHT', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
        
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.unit_height, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.unit_height, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'UNIT_HEIGHT', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'DUAL_UOM_CONTROL' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'DUAL_UOM_CONTROL', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.dual_uom_control, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.dual_uom_control, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'DUAL_UOM_CONTROL', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'DUAL_UOM_DEVIATION_HIGH' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'DUAL_UOM_DEVIATION_HIGH', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.dual_uom_deviation_high, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.dual_uom_deviation_high, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'DUAL_UOM_DEVIATION_HIGH', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'DUAL_UOM_DEVIATION_LOW' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'DUAL_UOM_DEVIATION_LOW', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
        
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.dual_uom_deviation_low, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.dual_uom_deviation_low, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'DUAL_UOM_DEVIATION_LOW', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'CONTRACT_ITEM_TYPE_CODE' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'CONTRACT_ITEM_TYPE_CODE', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.contract_item_type_code, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.contract_item_type_code, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'CONTRACT_ITEM_TYPE_CODE', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'SERV_REQ_ENABLED_CODE' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'SERV_REQ_ENABLED_CODE', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.serv_req_enabled_code, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.serv_req_enabled_code, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'SERV_REQ_ENABLED_CODE', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'SERV_BILLING_ENABLED_FLAG' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'SERV_BILLING_ENABLED_FLAG', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.serv_billing_enabled_flag, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.serv_billing_enabled_flag, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'SERV_BILLING_ENABLED_FLAG', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'DEFAULT_SO_SOURCE_TYPE' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'DEFAULT_SO_SOURCE_TYPE', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.default_so_source_type, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.default_so_source_type, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'DEFAULT_SO_SOURCE_TYPE', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'OBJECT_VERSION_NUMBER' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'OBJECT_VERSION_NUMBER', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.object_version_number, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.object_version_number, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'OBJECT_VERSION_NUMBER', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'TRACKING_QUANTITY_IND' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'TRACKING_QUANTITY_IND', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.tracking_quantity_ind, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.s3_tracking_quantity_ind, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'TRACKING_QUANTITY_IND', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'SECONDARY_DEFAULT_IND' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'SECONDARY_DEFAULT_IND', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.secondary_default_ind, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.s3_secondary_default_ind, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'SECONDARY_DEFAULT_IND', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'SO_AUTHORIZATION_FLAG' THEN
      
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'SO_AUTHORIZATION_FLAG', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.so_authorization_flag, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.so_authorization_flag, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'SO_AUTHORIZATION_FLAG', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'ATTRIBUTE17' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'ATTRIBUTE17', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.attribute17, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.attribute17, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'ATTRIBUTE17', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'ATTRIBUTE18' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'ATTRIBUTE18', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.attribute18, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.attribute18, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'ATTRIBUTE18', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'ATTRIBUTE19' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'ATTRIBUTE19', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
        
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.attribute19, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.attribute19, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'ATTRIBUTE19', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'ATTRIBUTE25' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'ATTRIBUTE25', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.attribute25, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.s3_attribute25, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'ATTRIBUTE25', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'EXPIRATION_ACTION_CODE' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'EXPIRATION_ACTION_CODE', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.expiration_action_code, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.s3_expiration_action_code, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'EXPIRATION_ACTION_CODE', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'EXPIRATION_ACTION_INTERVAL' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'EXPIRATION_ACTION_INTERVAL', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.expiration_action_interval, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.s3_expiration_action_interval, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'EXPIRATION_ACTION_INTERVAL', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'HAZARDOUS_MATERIAL_FLAG' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'HAZARDOUS_MATERIAL_FLAG', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
        
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.hazardous_material_flag, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.hazardous_material_flag, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'HAZARDOUS_MATERIAL_FLAG', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'RECIPE_ENABLED_FLAG' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'RECIPE_ENABLED_FLAG', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
        
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.recipe_enabled_flag, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.recipe_enabled_flag, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'RECIPE_ENABLED_FLAG', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'RETEST_INTERVAL' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'RETEST_INTERVAL', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
        
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.retest_interval, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.retest_interval, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'RETEST_INTERVAL', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'REPAIR_LEADTIME' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'REPAIR_LEADTIME', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.repair_leadtime, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.repair_leadtime, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'REPAIR_LEADTIME', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'GDSN_OUTBOUND_ENABLED_FLAG' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'GDSN_OUTBOUND_ENABLED_FLAG', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.gdsn_outbound_enabled_flag, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.gdsn_outbound_enabled_flag, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'GDSN_OUTBOUND_ENABLED_FLAG', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'ACCOUNTING_RULE_ID' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'ACCOUNTING_RULE_ID', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.legacy_accounting_rule_name, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.s3_accounting_rule_name, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'ACCOUNTING_RULE_ID', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'ALLOW_ITEM_DESC_UPDATE_FLAG' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'ALLOW_ITEM_DESC_UPDATE_FLAG', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
        
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.allow_item_desc_update_flag, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.allow_item_desc_update_flag, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'ALLOW_ITEM_DESC_UPDATE_FLAG', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'ALLOW_SUBSTITUTE_RECEIPTS_FLAG' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'ALLOW_SUBSTITUTE_RECEIPTS_FLAG', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.allow_substitute_receipts_flag, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.allow_substitute_receipts_flag, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'ALLOW_SUBSTITUTE_RECEIPTS_FLAG', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'ALLOW_UNORDERED_RECEIPTS_FLAG' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'ALLOW_UNORDERED_RECEIPTS_FLAG', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.allow_unordered_receipts_flag, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.allow_unordered_receipts_flag, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'ALLOW_UNORDERED_RECEIPTS_FLAG', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
    
      IF k.column_name = 'ASSET_CATEGORY_ID' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'ASSET_CATEGORY_ID', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.asset_category_id, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.asset_category_id, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'ASSET_CATEGORY_ID', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'ASSET_CATEGORY_ID' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'ASSET_CATEGORY_ID', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.asset_category_id, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.asset_category_id, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'ASSET_CATEGORY_ID', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'ATTRIBUTE11' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'ATTRIBUTE11', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.attribute11, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.attribute11, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'ATTRIBUTE11', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'ATTRIBUTE12' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'ATTRIBUTE12', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.attribute12, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.attribute12, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'ATTRIBUTE12', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'ATTRIBUTE13' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'ATTRIBUTE13', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.attribute13, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.attribute13, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'ATTRIBUTE13', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'ATTRIBUTE2' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'ATTRIBUTE2', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.attribute2, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.attribute2, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'ATTRIBUTE2', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'ATTRIBUTE9' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'ATTRIBUTE9', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.attribute9, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.attribute9, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'ATTRIBUTE9', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'AUTO_SERIAL_ALPHA_PREFIX' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'AUTO_SERIAL_ALPHA_PREFIX', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.auto_serial_alpha_prefix, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.auto_serial_alpha_prefix, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'AUTO_SERIAL_ALPHA_PREFIX', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'BOM_ENABLED_FLAG' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'BOM_ENABLED_FLAG', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.bom_enabled_flag, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.bom_enabled_flag, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'BOM_ENABLED_FLAG', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'BUILD_IN_WIP_FLAG' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'BUILD_IN_WIP_FLAG', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.build_in_wip_flag, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.build_in_wip_flag, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'BUILD_IN_WIP_FLAG', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'CATALOG_STATUS_FLAG' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'CATALOG_STATUS_FLAG', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.catalog_status_flag, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.catalog_status_flag, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'CATALOG_STATUS_FLAG', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'COLLATERAL_FLAG' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'COLLATERAL_FLAG', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.collateral_flag, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.collateral_flag, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'COLLATERAL_FLAG', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'CREATED_BY' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'CREATED_BY', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.created_by, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.created_by, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'CREATED_BY', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'CREATION_DATE' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'CREATION_DATE', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.creation_date, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.creation_date, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'CREATION_DATE', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'CUSTOMER_ORDER_ENABLED_FLAG' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'CUSTOMER_ORDER_ENABLED_FLAG', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.customer_order_enabled_flag, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.customer_order_enabled_flag, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'CUSTOMER_ORDER_ENABLED_FLAG', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'CUSTOMER_ORDER_FLAG' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'CUSTOMER_ORDER_FLAG', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.customer_order_flag, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.customer_order_flag, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'CUSTOMER_ORDER_FLAG', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'DESCRIPTION' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'DESCRIPTION', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.description, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.description, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'DESCRIPTION', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'INSPECTION_REQUIRED_FLAG' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'INSPECTION_REQUIRED_FLAG', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.inspection_required_flag, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.inspection_required_flag, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'INSPECTION_REQUIRED_FLAG', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'INTERNAL_ORDER_ENABLED_FLAG' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'INTERNAL_ORDER_ENABLED_FLAG', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.internal_order_enabled_flag, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.internal_order_enabled_flag, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'INTERNAL_ORDER_ENABLED_FLAG', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'INTERNAL_ORDER_FLAG' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'INTERNAL_ORDER_FLAG', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.internal_order_flag, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.internal_order_flag, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'INTERNAL_ORDER_FLAG', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'INVENTORY_ASSET_FLAG' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'INVENTORY_ASSET_FLAG', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.inventory_asset_flag, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.inventory_asset_flag, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'INVENTORY_ASSET_FLAG', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'ITEM_CATALOG_GROUP_ID' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'ITEM_CATALOG_GROUP_ID', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.item_catalog_group_id, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.s3_item_catalog_group_id, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'ITEM_CATALOG_GROUP_ID', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'LAST_UPDATED_BY' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'LAST_UPDATED_BY', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.last_updated_by, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.last_updated_by, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'LAST_UPDATED_BY', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'LAST_UPDATE_DATE' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'LAST_UPDATE_DATE', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.last_update_date, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.last_update_date, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'LAST_UPDATE_DATE', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'LIST_PRICE_PER_UNIT' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'LIST_PRICE_PER_UNIT', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.list_price_per_unit, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.list_price_per_unit, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'LIST_PRICE_PER_UNIT', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'MTL_TRANSACTIONS_ENABLED_FLAG' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'MTL_TRANSACTIONS_ENABLED_FLAG', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.mtl_transactions_enabled_flag, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.mtl_transactions_enabled_flag, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'MTL_TRANSACTIONS_ENABLED_FLAG', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'ONT_PRICING_QTY_SOURCE' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'ONT_PRICING_QTY_SOURCE', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.ont_pricing_qty_source, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.s3_ont_pricing_qty_source, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'ONT_PRICING_QTY_SOURCE', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'ORGANIZATION_ID' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'ORGANIZATION_ID', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.legacy_organization_id, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => '', p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'ORGANIZATION_ID', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'PURCHASING_ENABLED_FLAG' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'PURCHASING_ENABLED_FLAG', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.purchasing_enabled_flag, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.purchasing_enabled_flag, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'PURCHASING_ENABLED_FLAG', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'QTY_RCV_TOLERANCE' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'QTY_RCV_TOLERANCE', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.qty_rcv_tolerance, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.qty_rcv_tolerance, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'QTY_RCV_TOLERANCE', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'RECEIPT_REQUIRED_FLAG' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'RECEIPT_REQUIRED_FLAG', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          /*EXECUTE IMMEDIATE l_buyer_dq_st 
          INTO l_dq_name
          USING 'RECEIPT_REQUIRED_FLAG',k.segment1; */
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.receipt_required_flag, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.receipt_required_flag, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'RECEIPT_REQUIRED_FLAG', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'RETURNABLE_FLAG' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'RETURNABLE_FLAG', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.returnable_flag, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.returnable_flag, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'RETURNABLE_FLAG', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'REVISION_QTY_CONTROL_CODE' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'REVISION_QTY_CONTROL_CODE', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.revision_qty_control_code, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.revision_qty_control_code, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'REVISION_QTY_CONTROL_CODE', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'SECONDARY_UOM_CODE' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'SECONDARY_UOM_CODE', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.secondary_uom_code, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.s3_secondary_uom_code, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'SECONDARY_UOM_CODE', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'SEGMENT1' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'SEGMENT1', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.segment1, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.segment1, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'SEGMENT1', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'SERVICE_ITEM_FLAG' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'SERVICE_ITEM_FLAG', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.service_item_flag, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.service_item_flag, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'SERVICE_ITEM_FLAG', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'SHIPPABLE_ITEM_FLAG' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'SHIPPABLE_ITEM_FLAG', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.shippable_item_flag, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.shippable_item_flag, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'SHIPPABLE_ITEM_FLAG', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'SO_TRANSACTIONS_FLAG' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'SO_TRANSACTIONS_FLAG', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.so_transactions_flag, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.so_transactions_flag, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'SO_TRANSACTIONS_FLAG', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'START_AUTO_SERIAL_NUMBER' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'START_AUTO_SERIAL_NUMBER', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.start_auto_serial_number, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.start_auto_serial_number, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'START_AUTO_SERIAL_NUMBER', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'STOCK_ENABLED_FLAG' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'STOCK_ENABLED_FLAG', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.stock_enabled_flag, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.stock_enabled_flag, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'STOCK_ENABLED_FLAG', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'TAXABLE_FLAG' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'TAXABLE_FLAG', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.taxable_flag, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.taxable_flag, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'TAXABLE_FLAG', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'UNIT_OF_ISSUE' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'UNIT_OF_ISSUE', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          l_dq_concat := NULL;
          FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
            l_dq_concat := l_dq_concat || ',' || r.rule_name;
          END LOOP;
          l_dq_concat_st := l_dq_concat;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_concat_st);
            l_dq_concat_st := NULL;
          WHEN OTHERS THEN
            dbms_output.put_line('error found in dq' || SQLERRM);
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.unit_of_issue, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.unit_of_issue, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'UNIT_OF_ISSUE', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
      IF k.column_name = 'WIP_SUPPLY_SUBINVENTORY' THEN
        BEGIN
          EXECUTE IMMEDIATE l_attr_st
            INTO l_user_attribute_name, l_controlled_at, l_group_name
            USING 'WIP_SUPPLY_SUBINVENTORY', k.segment1, k.legacy_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in group' ||
                                 l_user_attribute_name || l_controlled_at ||
                                 l_group_name);
            l_user_attribute_name := NULL;
            l_controlled_at       := NULL;
            l_group_name          := NULL;
        END;
        BEGIN
          EXECUTE IMMEDIATE l_buyer_dq_st
            INTO l_dq_name
            USING 'WIP_SUPPLY_SUBINVENTORY', k.segment1;
        
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('no data found in dq' || l_dq_name);
            l_dq_name := NULL;
        END;
        xxs3_item_recon_report_prc(p_stage_tab => 'XXOBJT.XXS3_PTM_ITEM_EQT_RECON_STG',
                                   --  p_stage_column => 'LEGACY_ATTRIBUTE_VALUE',               
                                   p_stage_status_col_val => k.wip_supply_subinventory, p_stage_legacy_org_code_val => k.legacy_organization_code, p_ts3_org_code_col_val => k.s3_organization_code, p_leg_attr_usr_value_val => '', p_s3_eqt_attr_value_val => k.s3_wip_supply_subinventory, p_s3_eqt_attr_usr_value_val => '', p_s3_loaded_value_val => '', p_cleanse_rule_val => '', p_dq_rpt_rule_val => l_dq_concat_st, p_dq_rjt_rule_val => '', p_transform_rule_val => '', p_extract_rule_val => l_extract_rule_conc, p_eqt_process_flag_val => k.process_flag, p_date_extracted_val => k.date_extracted_on, p_date_load_on_val => '', p_attr_grp_name_val => l_group_name, p_attr_name_val => l_user_attribute_name, p_org_mstr_cntrl_val => l_controlled_at, p_stage_primary_col => 'ITEM_COLUMN_NAME', p_stage_primary_col_val => 'WIP_SUPPLY_SUBINVENTORY', p_primary_item_col => 'ITEM', p_primary_item_col_val => k.segment1, p_err_code => l_err_code, p_err_msg => l_err_msg);
      
      END IF;
    END LOOP;
  
    COMMIT;
    fnd_file.put_line(fnd_file.log, 'end Update the Attribute values');
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      dbms_output.put_line('ERROR IN UPDATE' || SQLERRM);
    
  END xxs3_ptm_item_recon_prc;
  --------------------------------------------------------------------------------------------
  -- Purpose: This procedure is used to Update Values in stage table
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  17/11/2016  V.V.Sateesh                Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE xxs3_item_recon_report_prc(p_stage_tab IN VARCHAR2
                                       -- ,p_stage_column in varchar2
                                      ,p_stage_status_col_val      IN VARCHAR2
                                      ,p_stage_legacy_org_code_val IN VARCHAR2
                                      ,p_ts3_org_code_col_val      IN VARCHAR2
                                      ,p_leg_attr_usr_value_val    IN VARCHAR2
                                      ,p_s3_eqt_attr_value_val     IN VARCHAR2
                                      ,p_s3_eqt_attr_usr_value_val IN VARCHAR2
                                      ,p_s3_loaded_value_val       IN VARCHAR2
                                      ,p_cleanse_rule_val          IN VARCHAR2
                                      ,p_dq_rpt_rule_val           IN VARCHAR2
                                      ,p_dq_rjt_rule_val           IN VARCHAR2
                                      ,p_transform_rule_val        IN VARCHAR2
                                      ,p_extract_rule_val          IN VARCHAR2
                                      ,p_eqt_process_flag_val      IN VARCHAR2
                                      ,p_date_extracted_val        IN VARCHAR2
                                      ,p_date_load_on_val          IN VARCHAR2
                                      ,p_attr_grp_name_val         IN VARCHAR2
                                      ,p_attr_name_val             IN VARCHAR2
                                      ,p_org_mstr_cntrl_val        IN VARCHAR2
                                      ,p_stage_primary_col         IN VARCHAR2
                                      ,p_stage_primary_col_val     IN VARCHAR2
                                      ,p_primary_item_col          IN VARCHAR2
                                      ,p_primary_item_col_val      IN VARCHAR2
                                      ,p_err_code                  OUT VARCHAR2
                                      , -- Output error code
                                       p_err_msg                   OUT VARCHAR2) IS
    l_dyn_statement VARCHAR2(3000);
  BEGIN
  
    l_dyn_statement := 'update ' || p_stage_tab || ' set ' ||
                       'LEGACY_ATTRIBUTE_VALUE=:1' ||
                       ' , SOURCE_LEGACY_ORG_CODE=:2' ||
                       ' , TARGET_S3_ORG_CODE=:3' ||
                       ' , LEGACY_ATTRIBUTE_USER_VALUE=:4' ||
                       ' , S3_EQT_ATTRIBUTE_VALUE=:5' ||
                       ' , S3_EQT_ATTRIBUTE_USER_VALUE=:6' ||
                       ' , S3_LOADED_VALUE=:7' || ' , CLENASE_RULE=:8' ||
                       ' , DQ_REPORT_RULE=:9' || ' , DQ_REJECT_RULE=:10' ||
                       ' , TRANSFORM_RULE=:11' || ' , EXTRACT_RULE=:12' ||
                       ' , EQT_PROCESS_FLAG=:13' ||
                       ' , DATE_EXTRACTED_ON=:14' || ' , DATE_LOAD_ON=:15' ||
                       ' , ATTRIBUTE_GROUP_NAME=:16' ||
                       ' , ATTRIBUTE_NAME=:17' ||
                       ' , ORG_MASTER_CONTROLLED=:18' || ' where ' ||
                       p_stage_primary_col || ' = ' || ':19' ||
                       'AND ITEM = :20';
  
    BEGIN
    
      EXECUTE IMMEDIATE l_dyn_statement
        USING p_stage_status_col_val, p_stage_legacy_org_code_val, p_ts3_org_code_col_val, p_leg_attr_usr_value_val, p_s3_eqt_attr_value_val, p_s3_eqt_attr_usr_value_val, p_s3_loaded_value_val, p_cleanse_rule_val, p_dq_rpt_rule_val, p_dq_rjt_rule_val, p_transform_rule_val, p_extract_rule_val, p_eqt_process_flag_val, p_date_extracted_val, p_date_load_on_val, p_attr_grp_name_val, p_attr_name_val, p_org_mstr_cntrl_val, p_stage_primary_col_val, p_primary_item_col_val;
      COMMIT;
      --p_err_code := '0';
      -- p_err_msg  := 'SUCCESS';
    EXCEPTION
      WHEN OTHERS THEN
        ROLLBACK;
        fnd_file.put_line(fnd_file.log, 'ERROR IN UPDATE-->' ||
                           p_stage_status_col_val || 'ERROR' ||
                           SQLERRM);
    END;
  
  END xxs3_item_recon_report_prc;

END xxs3_ptm_item_recon_pkg
/