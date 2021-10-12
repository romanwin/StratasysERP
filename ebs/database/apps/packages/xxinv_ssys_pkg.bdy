CREATE OR REPLACE PACKAGE BODY xxinv_ssys_pkg IS
  --------------------------------------------------------------------
  --  customization code: CUST540 - FDM Items Creation Program
  --  name:               XXINV_SSYS_PKG
  --                            
  --  create by:          vitaly
  --  $Revision:          1.0 
  --  creation date:      8.11.12
  --  Purpose:            FDM Items Creation Program
  --------------------------------------------------------------------
  --  ver   date          name             desc
  --  1.0   8.11.12       vitaly           initial build  
  --  1.1   20.3.13       yuval tal        bugfix :update_ssys_items_min_max: remove validation for quantity=0 (min or max)
  --  1.2   18.08.2013    Vitaly          CR 870 std cost - change hard-coded organization
  -------------------------------------------------------------------- 
  g_request_start_date DATE;

  FUNCTION new_ssys_items_data_validation RETURN VARCHAR2 IS
    --return values:  'S' or Error Message  
    l_err_msg         VARCHAR2(1000);
    v_step            VARCHAR2(30);
    v_numeric_dummy   NUMBER;
    l_records_updated NUMBER;
  
  BEGIN
  
    v_step := 'Step 0';
  
    UPDATE xxinv_ssys_items a
       SET a.error_message = NULL, a.message = NULL
     WHERE a.status = 'N';
  
    fnd_file.put_line(fnd_file.output,
                      '================= DATA VALIDATION =========================');
    fnd_file.put_line(fnd_file.log,
                      '================= DATA VALIDATION =========================');
  
    v_step := 'Step 5';
    UPDATE xxinv_ssys_items a SET a.status = 'N' WHERE a.status IS NULL;
  
    v_step := 'Step 10';
    SELECT COUNT(1)
      INTO v_numeric_dummy
      FROM xxinv_ssys_items a
     WHERE nvl(a.status, 'N') = 'N';
  
    IF v_numeric_dummy = 0 THEN
      fnd_file.put_line(fnd_file.output,
                        'No new records (with Status=''N'' or Status is empty)');
      fnd_file.put_line(fnd_file.log,
                        'No new records (with Status=''N'' or Status is empty)');
    END IF;
  
    v_step := 'Step 15';
    UPDATE xxinv_ssys_items a
       SET a.status           = 'E',
           a.error_message    = 'Invalid Action - should be ''I'' or ''U''  (insert or update or null (insert))',
           a.last_update_date = SYSDATE,
           a.last_updated_by  = fnd_global.user_id
     WHERE a.status = 'N'
       AND nvl(a.action, 'I') NOT IN ('I', 'U'); ---I- Insert; U- Update 
  
    l_records_updated := SQL%ROWCOUNT;
    IF l_records_updated > 0 THEN
      fnd_file.put_line(fnd_file.output,
                        l_records_updated ||
                        ' records with Invalid Action - should be ''I'' or ''U''  (insert or update or null(insert))');
      fnd_file.put_line(fnd_file.log,
                        l_records_updated ||
                        ' records with Invalid Action - should be ''I'' or ''U''  (insert or update or null(insert))');
    END IF;
    COMMIT;
  
    v_step := 'Step 30'; ----
    UPDATE xxinv_ssys_items a
       SET a.status           = 'E',
           a.error_message    = 'Missing Item Code',
           a.last_update_date = SYSDATE,
           a.last_updated_by  = fnd_global.user_id
     WHERE a.status = 'N'
       AND ltrim(rtrim(a.item_code), '-') IS NULL;
  
    l_records_updated := SQL%ROWCOUNT;
    IF l_records_updated > 0 THEN
      fnd_file.put_line(fnd_file.output,
                        l_records_updated ||
                        ' records with Missing Item_Code');
      fnd_file.put_line(fnd_file.log,
                        l_records_updated ||
                        ' records with Missing Item_Code');
    END IF;
  
    v_step := 'Step 35'; ----
    ----Check item_code value---- may be characters like . or , or < or > or ; or : or ' or " or + .. inside
    UPDATE xxinv_ssys_items a
       SET a.status           = 'E',
           a.error_message    = 'There is forbidden character in your Item Code ',
           a.last_update_date = SYSDATE,
           a.last_updated_by  = fnd_global.user_id
     WHERE a.status = 'N'
       AND (instr(ltrim(rtrim(a.item_code)), ' ', 1) > 0 OR
           instr(a.item_code, '.', 1) > 0 OR
           instr(a.item_code, ',', 1) > 0 OR
           instr(a.item_code, '<', 1) > 0 OR
           instr(a.item_code, '>', 1) > 0 OR
           instr(a.item_code, '=', 1) > 0 OR
           instr(a.item_code, '_', 1) > 0 OR
           instr(a.item_code, ';', 1) > 0 OR
           instr(a.item_code, ':', 1) > 0 OR
           instr(a.item_code, '+', 1) > 0 OR
           instr(a.item_code, ')', 1) > 0 OR
           instr(a.item_code, '(', 1) > 0 OR
           instr(a.item_code, '*', 1) > 0 OR
           instr(a.item_code, '&', 1) > 0 OR
           instr(a.item_code, '^', 1) > 0 OR
           instr(a.item_code, '%', 1) > 0 OR
           instr(a.item_code, '$', 1) > 0 OR
           instr(a.item_code, '#', 1) > 0 OR
           instr(a.item_code, '@', 1) > 0 OR
           instr(a.item_code, '!', 1) > 0 OR
           instr(a.item_code, '?', 1) > 0 OR
           instr(a.item_code, '/', 1) > 0 OR
           instr(a.item_code, '\', 1) > 0 OR
           instr(a.item_code, '''', 1) > 0 OR
           instr(a.item_code, '"', 1) > 0 OR
           instr(a.item_code, '|', 1) > 0 OR
           instr(a.item_code, '{', 1) > 0 OR
           instr(a.item_code, '}', 1) > 0 OR
           instr(a.item_code, '[', 1) > 0 OR
           instr(a.item_code, ']', 1) > 0);
  
    l_records_updated := SQL%ROWCOUNT;
    IF l_records_updated > 0 THEN
      fnd_file.put_line(fnd_file.output,
                        l_records_updated ||
                        ' records with forbidden character in Item_Code');
      fnd_file.put_line(fnd_file.log,
                        l_records_updated ||
                        ' records with forbidden character in Item_Code');
    END IF;
  
    v_step := 'Step 40'; -----
    UPDATE xxinv_ssys_items a
       SET a.status           = 'E',
           a.error_message    = 'There are more than 1 record for the same Item_Code',
           a.last_update_date = SYSDATE,
           a.last_updated_by  = fnd_global.user_id
     WHERE a.status = 'N'
       AND EXISTS (SELECT 1
              FROM xxinv_ssys_items a2
             WHERE a2.status = 'N'
               AND rtrim(a2.item_code) = rtrim(a.item_code)
               AND a2.line_id <> a.line_id);
  
    l_records_updated := SQL%ROWCOUNT;
    IF l_records_updated > 0 THEN
      fnd_file.put_line(fnd_file.output,
                        l_records_updated ||
                        ' records with ...There are more than 1 record for the same Item_Code');
      fnd_file.put_line(fnd_file.log,
                        l_records_updated ||
                        ' records with ...There are more than 1 record for the same Item_Code');
    END IF;
  
    COMMIT;
    v_step := 'Step 50';
    DELETE FROM xxinv_ssys_items a
     WHERE a.status = 'N'
       AND EXISTS (SELECT 1
              FROM mtl_system_items_b msi
             WHERE msi.organization_id = 91 --Master
               AND msi.segment1 = rtrim(a.item_code));
  
    l_records_updated := SQL%ROWCOUNT;
    IF l_records_updated > 0 THEN
      fnd_file.put_line(fnd_file.output,
                        l_records_updated ||
                        ' records are deleted from XXINV_SSYS_ITEMS (Items already exist in Master Organization');
      fnd_file.put_line(fnd_file.log,
                        l_records_updated ||
                        ' records are deleted from XXINV_SSYS_ITEMS (Items already exist in Master Organization');
    END IF;
    COMMIT;
  
    /*v_step:='Step 55';
    UPDATE XXINV_SSYS_ITEMS  a
    SET a.status  = 'E',
        a.error_message = 'Item not exists in Master Organization OMA - You cannot update this item',
        a.last_update_date=sysdate,
        a.last_updated_by=fnd_global.user_id
    WHERE a.status = 'N'
    AND nvl(a.action,'I')='U' ---Update
    AND NOT EXISTS (select 1
                from mtl_system_items_b  msi,
                     mtl_parameters      mp
                where msi.organization_id=mp.organization_id
                and   msi.segment1=ltrim(rtrim(a.item_code),'-')
                and   mp.organization_code='OMA');
    
    l_records_updated := SQL%ROWCOUNT;
    IF l_records_updated > 0 THEN
      fnd_file.put_line(fnd_file.output,l_records_updated ||' records with ...Item not exists in Master Organization OMA');
      fnd_file.put_line(fnd_file.log,   l_records_updated ||' records with ...Item not exists in Master Organization OMA');
    END IF;*/
  
    v_step := 'Step 60'; ----
    UPDATE xxinv_ssys_items a
       SET a.status           = 'E',
           a.error_message    = 'Missing Item Description',
           a.last_update_date = SYSDATE,
           a.last_updated_by  = fnd_global.user_id
     WHERE a.status = 'N'
       AND ltrim(rtrim(a.item_desc), '-') IS NULL;
  
    l_records_updated := SQL%ROWCOUNT;
    IF l_records_updated > 0 THEN
      fnd_file.put_line(fnd_file.output,
                        l_records_updated ||
                        ' records with Missing Item Description');
      fnd_file.put_line(fnd_file.log,
                        l_records_updated ||
                        ' records with Missing Item Description');
    END IF;
  
    v_step := 'Step 60'; -----
    UPDATE xxinv_ssys_items a
       SET a.status           = 'E',
           a.error_message    = 'Missing Item Template name',
           a.last_update_date = SYSDATE,
           a.last_updated_by  = fnd_global.user_id
     WHERE a.status = 'N'
       AND a.item_template_name IS NULL;
  
    l_records_updated := SQL%ROWCOUNT;
    IF l_records_updated > 0 THEN
      fnd_file.put_line(fnd_file.output,
                        l_records_updated ||
                        ' records with Missing Item Template Name');
      fnd_file.put_line(fnd_file.log,
                        l_records_updated ||
                        ' records with Missing Item Template Name');
    END IF;
  
    v_step := 'Step 65'; -----
    UPDATE xxinv_ssys_items a
       SET a.status           = 'E',
           a.error_message    = 'Invalid Item Template name',
           a.last_update_date = SYSDATE,
           a.last_updated_by  = fnd_global.user_id
     WHERE a.status = 'N'
       AND NOT EXISTS
     (SELECT mit.template_id
              FROM mtl_item_templates_vl mit
             WHERE mit.template_name = rtrim(a.item_template_name));
  
    l_records_updated := SQL%ROWCOUNT;
    IF l_records_updated > 0 THEN
      fnd_file.put_line(fnd_file.output,
                        l_records_updated ||
                        ' records with Invalid Item Template Name');
      fnd_file.put_line(fnd_file.log,
                        l_records_updated ||
                        ' records with Invalid Item Template Name');
    END IF;
  
    v_step := 'Step 70'; ----
    UPDATE xxinv_ssys_items a
       SET a.status           = 'E',
           a.error_message    = 'Missing Primary UOM',
           a.last_update_date = SYSDATE,
           a.last_updated_by  = fnd_global.user_id
     WHERE a.status = 'N'
       AND rtrim(a.primary_uom_code) IS NULL;
  
    l_records_updated := SQL%ROWCOUNT;
    IF l_records_updated > 0 THEN
      fnd_file.put_line(fnd_file.output,
                        l_records_updated ||
                        ' records with Missing Primary UOM');
      fnd_file.put_line(fnd_file.log,
                        l_records_updated ||
                        ' records with Missing Primary UOM');
    END IF;
  
    v_step := 'Step 75'; ------
    UPDATE xxinv_ssys_items a
       SET a.status           = 'E',
           a.error_message    = 'Invalid Primary UOM Code',
           a.last_update_date = SYSDATE,
           a.last_updated_by  = fnd_global.user_id
     WHERE a.status = 'N'
       AND NOT EXISTS
     (SELECT 1
              FROM mtl_units_of_measure muom
             WHERE muom.uom_code = rtrim(a.primary_uom_code));
  
    l_records_updated := SQL%ROWCOUNT;
    IF l_records_updated > 0 THEN
      fnd_file.put_line(fnd_file.output,
                        l_records_updated ||
                        ' records with Invalid Primary UOM Code');
      fnd_file.put_line(fnd_file.log,
                        l_records_updated ||
                        ' records with Invalid Primary UOM Code');
    END IF;
  
    v_step := 'Step 80'; -----
    UPDATE xxinv_ssys_items a
       SET a.message          = ltrim(a.message || chr(10) ||
                                      'Dimension properties will not be completed. Reason: Invalid Dimension_Uom_Code. ',
                                      chr(10)),
           a.last_update_date = SYSDATE,
           a.last_updated_by  = fnd_global.user_id
     WHERE a.status = 'N'
       AND rtrim(a.dimension_uom_code) IS NOT NULL
       AND NOT EXISTS
     (SELECT 1
              FROM mtl_units_of_measure muom
             WHERE muom.uom_code = nvl(rtrim(a.dimension_uom_code), 'FT') --- dimension_uom_code - is not required
               AND muom.uom_class = 'LENGTH');
  
    v_step := 'Step 85'; ----
    UPDATE xxinv_ssys_items a
       SET a.message          = ltrim(a.message || chr(10) ||
                                      'Dimension properties will not be completed. Reason: Invalid or missing one of these properties. ',
                                      chr(10)),
           a.last_update_date = SYSDATE,
           a.last_updated_by  = fnd_global.user_id
     WHERE a.status = 'N'
       AND rtrim(a.dimension_uom_code) IS NOT NULL
       AND (a.unit_length IS NULL OR a.unit_length <= 0 OR
           a.unit_width IS NULL OR a.unit_width <= 0 OR
           a.unit_height IS NULL OR a.unit_height <= 0);
  
    v_step := 'Step 90'; -----
    UPDATE xxinv_ssys_items a
       SET a.message          = ltrim(a.message || chr(10) ||
                                      'Volume properties will not be completed. Reason: Invalid Volume_Uom_Code. ',
                                      chr(10)),
           a.last_update_date = SYSDATE,
           a.last_updated_by  = fnd_global.user_id
     WHERE a.status = 'N'
       AND rtrim(a.volume_uom_code) IS NOT NULL
       AND NOT EXISTS
     (SELECT 1
              FROM mtl_units_of_measure muom
             WHERE muom.uom_code = nvl(rtrim(a.volume_uom_code), 'FT3') --- volume_uom_code - is not required
               AND muom.uom_class = 'VOLUME');
  
    v_step := 'Step 95'; -----
    UPDATE xxinv_ssys_items a
       SET a.message          = ltrim(a.message || chr(10) ||
                                      'Unit Volume will not be completed. Reason: Invalid or missing value. ',
                                      chr(10)),
           a.last_update_date = SYSDATE,
           a.last_updated_by  = fnd_global.user_id
     WHERE a.status = 'N'
       AND rtrim(a.volume_uom_code) IS NOT NULL
       AND (a.unit_volume IS NULL OR a.unit_volume <= 0);
  
    v_step := 'Step 100'; ----
    UPDATE xxinv_ssys_items a
       SET a.message          = ltrim(a.message || chr(10) ||
                                      'Weight properties will not be completed. Reason: Invalid Weight_Uom_Code. ',
                                      chr(10)),
           a.last_update_date = SYSDATE,
           a.last_updated_by  = fnd_global.user_id
     WHERE a.status = 'N'
       AND rtrim(a.weight_uom_code) IS NOT NULL
       AND NOT EXISTS
     (SELECT 1
              FROM mtl_units_of_measure muom
             WHERE muom.uom_code = nvl(rtrim(a.weight_uom_code), 'KG') --- weight_uom_code - is not required
               AND muom.uom_class = 'WEIGHT');
  
    v_step := 'Step 105'; ----
    UPDATE xxinv_ssys_items a
       SET a.message          = ltrim(a.message || chr(10) ||
                                      'Unit Weight will not be completed. Reason: Invalid or missing value. ',
                                      chr(10)),
           a.last_update_date = SYSDATE,
           a.last_updated_by  = fnd_global.user_id
     WHERE a.status = 'N'
       AND rtrim(a.weight_uom_code) IS NOT NULL
       AND nvl(a.unit_weight, -1) <= 0;
  
    v_step := 'Step 110'; ----
    UPDATE xxinv_ssys_items a
       SET a.status           = 'E',
           a.error_message    = 'Missing Item Category',
           a.last_update_date = SYSDATE,
           a.last_updated_by  = fnd_global.user_id
     WHERE a.status = 'N'
       AND rtrim(a.item_category) IS NULL;
  
    l_records_updated := SQL%ROWCOUNT;
    IF l_records_updated > 0 THEN
      fnd_file.put_line(fnd_file.output,
                        l_records_updated ||
                        ' records with Missing Item Category');
      fnd_file.put_line(fnd_file.log,
                        l_records_updated ||
                        ' records with Missing Item Category');
    END IF;
  
    v_step := 'Step 110.2';
    UPDATE xxinv_ssys_items a
       SET a.status           = 'E',
           a.error_message    = 'Missing Finish Good Flag for this new Item Category',
           a.last_update_date = SYSDATE,
           a.last_updated_by  = fnd_global.user_id
     WHERE a.status = 'N'
       AND rtrim(a.item_category) IS NOT NULL
       AND rtrim(a.finish_good_flag) IS NULL
       AND NOT EXISTS
     (SELECT 1
              FROM mtl_categories_kfv        mc,
                   mtl_category_sets_tl      t,
                   mtl_category_sets_b       mcs,
                   fnd_id_flex_structures_vl fifs,
                   mfg_lookups               ml
             WHERE mcs.category_set_id = t.category_set_id
               AND t.language = 'US'
               AND mcs.structure_id = fifs.id_flex_num
               AND fifs.application_id = 401
               AND fifs.id_flex_code = 'MCAT'
               AND mcs.control_level = ml.lookup_code
               AND ml.lookup_type = 'ITEM_CONTROL_LEVEL_GUI'
               AND fifs.id_flex_structure_code = 'XXINV_MAIN_ITEM_CATEGORY'
               AND t.category_set_name = 'Main Category Set'
               AND mc.structure_id = fifs.id_flex_num
               AND mc.concatenated_segments = rtrim(a.item_category));
  
    l_records_updated := SQL%ROWCOUNT;
    IF l_records_updated > 0 THEN
      fnd_file.put_line(fnd_file.output,
                        l_records_updated ||
                        ' records with Missing Finish Good Flag for this new Item Category');
      fnd_file.put_line(fnd_file.log,
                        l_records_updated ||
                        ' records with Missing Finish Good Flag for this new Item Category');
    END IF;
  
    COMMIT;
  
    v_step := 'Step 115'; ---
    UPDATE xxinv_ssys_items a
       SET a.status           = 'E',
           a.error_message    = 'Missing Product Line',
           a.last_update_date = SYSDATE,
           a.last_updated_by  = fnd_global.user_id
     WHERE a.status = 'N'
       AND rtrim(a.product_line) IS NULL;
  
    l_records_updated := SQL%ROWCOUNT;
    IF l_records_updated > 0 THEN
      fnd_file.put_line(fnd_file.output,
                        l_records_updated ||
                        ' records with Missing Product Line');
      fnd_file.put_line(fnd_file.log,
                        l_records_updated ||
                        ' records with Missing Product Line');
    END IF;
  
    v_step := 'Step 120'; ---
    UPDATE xxinv_ssys_items a
       SET a.status           = 'E',
           a.error_message    = 'Invalid Product Line',
           a.last_update_date = SYSDATE,
           a.last_updated_by  = fnd_global.user_id
     WHERE a.status = 'N'
       AND NOT EXISTS
     (SELECT 1
              FROM fnd_flex_value_sets fvs, fnd_flex_values_vl ffv
             WHERE fvs.flex_value_set_id = ffv.flex_value_set_id
               AND fvs.flex_value_set_name = 'XXGL_PRODUCT_LINE_SEG'
               AND ffv.flex_value = rtrim(a.product_line));
  
    l_records_updated := SQL%ROWCOUNT;
    IF l_records_updated > 0 THEN
      fnd_file.put_line(fnd_file.output,
                        l_records_updated ||
                        ' records with Invalid Product Line');
      fnd_file.put_line(fnd_file.log,
                        l_records_updated ||
                        ' records with Invalid Product Line');
    END IF;
  
    v_step := 'Step 125'; ----
    UPDATE xxinv_ssys_items a
       SET a.message          = ltrim(a.message || chr(10) ||
                                      'Item''s HTS_CODE (Attribute3) will not be completed. Reason: Invalid HTS_CODE. ',
                                      chr(10)),
           a.last_update_date = SYSDATE,
           a.last_updated_by  = fnd_global.user_id
     WHERE a.status = 'N'
       AND rtrim(a.hts_code) IS NOT NULL ---hts_code is not required
       AND NOT EXISTS
     (SELECT 1
              FROM fnd_flex_value_sets fvs, fnd_flex_values_vl ffv
             WHERE fvs.flex_value_set_id = ffv.flex_value_set_id
               AND fvs.flex_value_set_name = 'XXINV_INTRASTAT_Tariff_code' --- hts_code - is not required
               AND ffv.flex_value = rtrim(a.hts_code));
  
    v_step := 'Step 165'; ----
    UPDATE xxinv_ssys_items a
       SET a.message          = ltrim(a.message || chr(10) ||
                                      'Item''s COUNTRY (Attribute2) will not be completed. Reason: Invalid COUNTRY. ',
                                      chr(10)),
           a.last_update_date = SYSDATE,
           a.last_updated_by  = fnd_global.user_id
     WHERE a.status = 'N'
       AND NOT EXISTS
     (SELECT 1
              FROM fnd_territories_vl t
             WHERE nvl(t.territory_code, 'US') = rtrim(a.country)); --country is not required
  
    COMMIT;
  
    RETURN 'S';
  
  EXCEPTION
    WHEN OTHERS THEN
      l_err_msg := 'Unexpected ERROR in XXCONV_CATEGORIES_PKG.new_ssys_items_data_validation function: ' ||
                   v_step || ' ' || SQLERRM;
      fnd_file.put_line(fnd_file.output, '=======' || l_err_msg);
      fnd_file.put_line(fnd_file.log, '=======' || l_err_msg);
      RETURN l_err_msg;
  END new_ssys_items_data_validation;
  ------------------------------------------------------------------------------------
  FUNCTION check_new_ssys_categories RETURN VARCHAR2 IS
    --return values:  'S' or Error Message
  
    TYPE v_categsegs_rec IS RECORD(
      flex_value_set_id   NUMBER,
      flex_value_set_name VARCHAR2(100));
    TYPE v_categsegs_tab IS TABLE OF v_categsegs_rec INDEX BY BINARY_INTEGER;
    v_categsegs_arr v_categsegs_tab;
  
    TYPE v_categvalues_rec IS RECORD(
      segment_code VARCHAR2(50),
      segment_desc VARCHAR2(240));
    TYPE v_categvalues_tab IS TABLE OF v_categvalues_rec INDEX BY BINARY_INTEGER;
    v_categvalues_arr v_categvalues_tab;
  
    l_error_tbl     inv_item_grp.error_tbl_type;
    l_err_msg       VARCHAR2(300);
    v_step          VARCHAR2(100);
    v_numeric_dummy NUMBER;
    v_counter       NUMBER(6) := 0;
    v_segs_cnt      NUMBER(2) := 0;
    ---v_user_id   fnd_user.user_id%TYPE;
  
    v_new_categories_cntr    NUMBER := 0;
    v_segment_already_exists NUMBER := 0;
    v_missing_segment        NUMBER := 0;
    v_new_segments_created   NUMBER := 0;
    v_categories_success     NUMBER := 0;
    v_categories_failured    NUMBER := 0;
    ----v_categories_already_exist  number:=0;
  
    v_id_flex_num fnd_id_flex_structures.id_flex_num%TYPE;
  
    v_insert_nextcateg mtl_categories_b.category_id%TYPE;
    v_conc_categ_code  mtl_categories_tl.description%TYPE;
    v_conc_categ_desc  mtl_categories_b.description%TYPE;
  
    v_segvalue_exists CHAR(1);
    v_categ_exists    CHAR(1);
  
    v_category_set_id mtl_category_sets.category_set_id%TYPE;
    v_structure_id    mtl_category_sets.structure_id%TYPE;
  
    v_trans_to_int_error VARCHAR2(1000);
    l_value_set_name     VARCHAR2(240);
    l_validation_type    VARCHAR2(1);
    l_storage_value      VARCHAR2(80);
    --l_category_id        NUMBER;
    l_return_status    VARCHAR2(1);
    l_error_code       NUMBER;
    l_msg_count        NUMBER;
    l_msg_data         VARCHAR2(500);
    t_category_rec     inv_item_category_pub.category_rec_type;
    t_new_category_rec inv_item_category_pub.category_rec_type;
  
    CURSOR csr_valid_structures IS
      SELECT mcs.category_set_id,
             t.category_set_name,
             mcs.structure_id,
             fifs.id_flex_num,
             mcs.validate_flag,
             fifs.id_flex_structure_name structure_name,
             rtrim(ltrim(fifs.id_flex_structure_code, ' '), ' ') structure_code ---XXINV_MAIN_ITEM_CATEGORY
        FROM mtl_category_sets_tl      t,
             mtl_category_sets_b       mcs,
             fnd_id_flex_structures_vl fifs,
             mfg_lookups               ml
       WHERE mcs.category_set_id = t.category_set_id
         AND t.language = 'US'
         AND mcs.structure_id = fifs.id_flex_num
         AND fifs.application_id = 401
         AND fifs.id_flex_code = 'MCAT'
         AND mcs.control_level = ml.lookup_code
         AND ml.lookup_type = 'ITEM_CONTROL_LEVEL_GUI'
         AND fifs.id_flex_structure_code = 'XXINV_MAIN_ITEM_CATEGORY'
         AND t.category_set_name = 'Main Category Set';
  
    CURSOR get_categories IS
      SELECT a.line_id,
             a.item_category,
             instr(rtrim(a.item_category), '.', 1, 1) first_dot_position,
             instr(rtrim(a.item_category), '.', 1, 2) second_dot_position,
             CASE
               WHEN instr(rtrim(a.item_category), '.', 1, 1) = 0 THEN --first segment only
                rtrim(a.item_category)
               ELSE
                substr(rtrim(a.item_category),
                       1,
                       instr(rtrim(a.item_category), '.', 1, 1) - 1)
             END segment1,
             CASE
               WHEN instr(rtrim(a.item_category), '.', 1, 1) = 0 THEN --first segment only
                NULL
               WHEN instr(rtrim(a.item_category), '.', 1, 2) = 0 THEN --no third segment
                substr(rtrim(a.item_category),
                       instr(rtrim(a.item_category), '.', 1, 1) + 1)
               ELSE
                substr(rtrim(a.item_category),
                       instr(rtrim(a.item_category), '.', 1, 1) + 1,
                       instr(rtrim(a.item_category), '.', 1, 2) -
                       instr(rtrim(a.item_category), '.', 1, 1) - 1)
             END segment2,
             CASE
               WHEN instr(rtrim(a.item_category), '.', 1, 1) = 0 --first segment only
                    OR instr(rtrim(a.item_category), '.', 1, 2) = 0 THEN --no third segment
                NULL
               ELSE
                substr(rtrim(a.item_category),
                       instr(rtrim(a.item_category), '.', 1, 2) + 1)
             END segment3,
             upper(rtrim(a.finish_good_flag)) finish_good_flag
      
        FROM xxinv_ssys_items a
       WHERE a.status = 'N'
         AND rtrim(a.item_category) IS NOT NULL;
  
    CURSOR cr_category_segments(pc_id_flex_num IN NUMBER) IS
      SELECT s.flex_value_set_id,
             vs.flex_value_set_name, ---XXINV_ITEM_GROUP, XXINV_ITEM_FAMILY, XXINV_ITEM_CATEGORY
             s.segment_num ---10, 20, 30
        FROM fnd_id_flex_segments s, fnd_flex_value_sets vs
       WHERE s.application_id = 401
         AND s.id_flex_code = 'MCAT'
         AND s.id_flex_num = pc_id_flex_num
         AND s.enabled_flag = 'Y'
         AND s.flex_value_set_id = vs.flex_value_set_id
       ORDER BY s.segment_num;
  
    cur_structure   csr_valid_structures%ROWTYPE;
    l_validate_flag VARCHAR2(1);
    missing_segment        EXCEPTION;
    segment_already_exists EXCEPTION;
  
  BEGIN
  
    v_step := 'Step 0';
    fnd_file.put_line(fnd_file.output, ''); --empty line
    fnd_file.put_line(fnd_file.output, ''); --empty line
    fnd_file.put_line(fnd_file.output, ''); --empty line
    fnd_file.put_line(fnd_file.output,
                      '================= Check Categories =========================');
    fnd_file.put_line(fnd_file.log, ''); --empty line
    fnd_file.put_line(fnd_file.log, ''); --empty line
    fnd_file.put_line(fnd_file.log, ''); --empty line
    fnd_file.put_line(fnd_file.log,
                      '================= Check Categories =========================');
  
    v_step := 'Step 5';
    ----Check category-------------------                                
    UPDATE xxinv_ssys_items a
       SET a.status           = 'E',
           a.error_message    = 'Missing Category',
           a.last_update_date = SYSDATE,
           a.last_updated_by  = fnd_global.user_id
     WHERE a.status = 'N'
       AND rtrim(a.item_category) IS NULL;
    COMMIT;
  
    v_step := 'Step 10';
    -- get structure and value set details
    FOR cur_structure IN csr_valid_structures LOOP
      v_category_set_id := cur_structure.category_set_id;
      v_structure_id    := cur_structure.structure_id;
      v_id_flex_num     := cur_structure.id_flex_num;
      l_validate_flag   := cur_structure.validate_flag;
      v_segs_cnt        := 0;
      v_counter         := 0;
      v_step            := 'Step 15';
    
      FOR i IN cr_category_segments(v_id_flex_num) LOOP
        v_segs_cnt := v_segs_cnt + 1;
        v_categsegs_arr(v_segs_cnt).flex_value_set_id := i.flex_value_set_id;
        v_categsegs_arr(v_segs_cnt).flex_value_set_name := i.flex_value_set_name;
      END LOOP;
    
      -- Open The File For Reading
      FOR cur_category IN get_categories LOOP
        -------------------- CATEGORIES LOOP -----------------------------
        v_step := 'Step 20';
      
        BEGIN
          l_error_tbl.delete;
          l_err_msg := NULL;
          v_counter := v_counter + 1;
          v_trans_to_int_error := NULL;
          v_conc_categ_code := NULL;
          v_conc_categ_desc := NULL;
          v_categvalues_arr(1).segment_code := cur_category.segment1;
          v_categvalues_arr(2).segment_code := cur_category.segment2;
          v_categvalues_arr(3).segment_code := cur_category.segment3;
        
          v_step := 'Step 25';
          IF cur_category.segment1 IS NULL THEN
            UPDATE xxinv_ssys_items a
               SET a.status           = 'E',
                   a.error_message    = 'Invalid Category - Missing Segment1',
                   a.last_update_date = SYSDATE,
                   a.last_updated_by  = fnd_global.user_id
             WHERE a.line_id = cur_category.line_id;
            RAISE missing_segment;
          END IF;
          v_step := 'Step 30';
          IF cur_category.segment2 IS NULL THEN
            UPDATE xxinv_ssys_items a
               SET a.status           = 'E',
                   a.error_message    = 'Invalid Category - Missing Segment2',
                   a.last_update_date = SYSDATE,
                   a.last_updated_by  = fnd_global.user_id
             WHERE a.line_id = cur_category.line_id;
            RAISE missing_segment;
          END IF;
          v_step := 'Step 35';
          IF cur_category.segment3 IS NULL THEN
            UPDATE xxinv_ssys_items a
               SET a.status           = 'E',
                   a.error_message    = 'Invalid Category - Missing Segment3',
                   a.last_update_date = SYSDATE,
                   a.last_updated_by  = fnd_global.user_id
             WHERE a.line_id = cur_category.line_id;
            RAISE missing_segment;
          END IF;
        
          ----Check segments1,2,3 ... already exist in "other case"------------------- 
          v_step := 'Step 50';
          BEGIN
            SELECT 1
              INTO v_numeric_dummy
              FROM fnd_flex_value_sets ffvs, fnd_flex_values_vl ffv
             WHERE ffvs.flex_value_set_id = ffv.flex_value_set_id
               AND flex_value_set_name = 'XXINV_ITEM_GROUP' ---for Seg1  
               AND ffv.enabled_flag = 'Y'
               AND upper(flex_value) = upper(cur_category.segment1)
               AND flex_value <> cur_category.segment1;
          
            UPDATE xxinv_ssys_items a
               SET a.status           = 'E',
                   a.error_message    = 'Segment1 Already Exists in Value Set XXINV_ITEM_GROUP in other case',
                   a.last_update_date = SYSDATE,
                   a.last_updated_by  = fnd_global.user_id
             WHERE a.line_id = cur_category.line_id;
          
            RAISE segment_already_exists;
          
          EXCEPTION
            WHEN no_data_found THEN
              NULL;
          END;
          ---------------
          v_step := 'Step 55';
          BEGIN
            SELECT 1
              INTO v_numeric_dummy
              FROM fnd_flex_value_sets ffvs, fnd_flex_values_vl ffv
             WHERE ffvs.flex_value_set_id = ffv.flex_value_set_id
               AND flex_value_set_name = 'XXINV_ITEM_FAMILY' ---for Seg2 
               AND ffv.enabled_flag = 'Y'
               AND upper(flex_value) = upper(cur_category.segment2)
               AND flex_value <> cur_category.segment2;
          
            UPDATE xxinv_ssys_items a
               SET a.status           = 'E',
                   a.error_message    = 'Segment2 Already Exists in Value Set XXINV_ITEM_FAMILY in other case',
                   a.last_update_date = SYSDATE,
                   a.last_updated_by  = fnd_global.user_id
             WHERE a.line_id = cur_category.line_id;
          
            RAISE segment_already_exists;
          
          EXCEPTION
            WHEN no_data_found THEN
              NULL;
          END;
          ---------------
          v_step := 'Step 60';
          BEGIN
            SELECT 1
              INTO v_numeric_dummy
              FROM fnd_flex_value_sets ffvs, fnd_flex_values_vl ffv
             WHERE ffvs.flex_value_set_id = ffv.flex_value_set_id
               AND flex_value_set_name = 'XXINV_ITEM_CATEGORY' --for Seg3 
               AND ffv.enabled_flag = 'Y'
               AND upper(flex_value) = upper(cur_category.segment3)
               AND flex_value <> cur_category.segment3;
          
            UPDATE xxinv_ssys_items a
               SET a.status           = 'E',
                   a.error_message    = 'Segment3 Already Exists in Value Set XXINV_ITEM_CATEGORY in other case',
                   a.last_update_date = SYSDATE,
                   a.last_updated_by  = fnd_global.user_id
             WHERE a.line_id = cur_category.line_id;
          
            RAISE segment_already_exists;
          
          EXCEPTION
            WHEN no_data_found THEN
              NULL;
          END;
          ---------------              
        
          FOR cnt IN 1 .. v_segs_cnt LOOP
            -- Check If The Value Exists In Flex Values
            IF v_categvalues_arr(cnt).segment_code IS NOT NULL THEN
              v_step := 'Step 70';
              BEGIN
                SELECT 'Y'
                  INTO v_segvalue_exists
                  FROM fnd_flex_values
                 WHERE flex_value_set_id = v_categsegs_arr(cnt)
                      .flex_value_set_id
                   AND flex_value = v_categvalues_arr(cnt).segment_code;
              EXCEPTION
                WHEN no_data_found THEN
                  --fnd_file.put_line(fnd_file.log,
                  --  'XXXXXXXXXXX CNT =' || cnt);
                  CASE
                    WHEN cnt = 1 THEN
                      UPDATE xxinv_ssys_items a
                         SET a.error_message    = 'Invalid item category. Items item category segment=' || v_categvalues_arr(cnt)
                                                 .segment_code || chr(10) ||
                                                  'must exist already. Not allowed to create new value for segment=Group. Contact Israel Engineering for further handling',
                             a.status           = 'E',
                             a.last_update_date = SYSDATE,
                             a.last_updated_by  = fnd_global.user_id
                       WHERE a.line_id = cur_category.line_id
                         AND a.status = 'N';
                    
                      COMMIT;
                    
                      --  fnd_file.put_line(fnd_file.log,
                      --   'XXXXXXXXXXX  Invalid item category');
                    
                      RAISE missing_segment;
                    
                    ELSE
                    
                      v_step := 'Step 75';
                      SELECT fvs.flex_value_set_name, fvs.validation_type
                        INTO l_value_set_name, l_validation_type
                        FROM fnd_flex_value_sets fvs
                       WHERE fvs.flex_value_set_id = v_categsegs_arr(cnt)
                            .flex_value_set_id;
                      IF l_validation_type = 'I' THEN
                        fnd_flex_val_api.create_independent_vset_value(p_flex_value_set_name => l_value_set_name,
                                                                       p_flex_value          => v_categvalues_arr(cnt)
                                                                                                .segment_code,
                                                                       p_description         => v_categvalues_arr(cnt)
                                                                                                .segment_desc,
                                                                       x_storage_value       => l_storage_value);
                        v_new_segments_created := v_new_segments_created + 1;
                      
                      END IF; -- validation type  
                  
                  END CASE;
              END;
              v_conc_categ_code := v_conc_categ_code || '.' || v_categvalues_arr(cnt)
                                  .segment_code;
              v_conc_categ_desc := v_conc_categ_desc || '.' || v_categvalues_arr(cnt)
                                  .segment_desc;
            
            END IF; --segment is not null
          END LOOP; --loop over segments
        
          v_conc_categ_code := substr(v_conc_categ_code, 2);
          v_conc_categ_desc := substr(v_conc_categ_desc, 2);
        
          -- Check If The Category Exists In ITELCO_CATEGORIES (After We're Sure All Segments Are OK) 
          BEGIN
            v_step := 'Step 80';
            SELECT 'Y'
              INTO v_categ_exists
              FROM mtl_categories_kfv mc
             WHERE structure_id = v_id_flex_num
               AND mc.concatenated_segments = v_conc_categ_code;
            ----v_categories_already_exist:=v_categories_already_exist+1;              
          EXCEPTION
            WHEN no_data_found THEN
              v_step                := 'Step 85';
              v_new_categories_cntr := v_new_categories_cntr + 1;
              ---DBMS_OUTPUT.put_line('Category='''||v_conc_categ_code||''' does not exist and will be created');
              t_category_rec              := t_new_category_rec;
              t_category_rec.structure_id := v_id_flex_num;
              ---t_category_rec.last_update_date            := SYSDATE;
              ---t_category_rec.last_updated_by             := v_user_id;
              ---t_category_rec.creation_date               := SYSDATE;
              ---t_category_rec.created_by                  := v_user_id;
              ---t_category_rec.last_update_login           := -1;
              t_category_rec.segment1 := v_categvalues_arr(1).segment_code;
              t_category_rec.segment2 := v_categvalues_arr(2).segment_code;
              t_category_rec.segment3 := v_categvalues_arr(3).segment_code;
            
              IF v_categvalues_arr(1)
               .segment_code IN ('Systems', 'FG-Systems') THEN
                t_category_rec.attribute4 := 'PRINTER';
              END IF;
              t_category_rec.attribute7   := upper(cur_category.finish_good_flag); ---ASK ODED
              t_category_rec.attribute8   := 'FDM';
              t_category_rec.summary_flag := 'N';
              t_category_rec.enabled_flag := 'Y';
              ----t_category_rec.description  := v_conc_categ_code; 
              v_step := 'Step 90';
              inv_item_category_pub.create_category(p_api_version   => '1.0',
                                                    p_init_msg_list => fnd_api.g_true,
                                                    p_commit        => fnd_api.g_false,
                                                    x_return_status => l_return_status,
                                                    x_errorcode     => l_error_code,
                                                    x_msg_count     => l_msg_count,
                                                    x_msg_data      => l_msg_data,
                                                    p_category_rec  => t_category_rec,
                                                    x_category_id   => v_insert_nextcateg);
              IF l_return_status = 'S' THEN
                ---DBMS_OUTPUT.put_line('Category='''||v_conc_categ_code||''' was created successfuly (category_id='||v_insert_nextcateg||')');
                v_categories_success := v_categories_success + 1;
                /*UPDATE XXINV_SSYS_ITEMS  a
                SET a.message = ltrim(a.message||chr(10)||'New Category '||cur_category.segment1||'.'||
                                                                           cur_category.segment2||'.'||
                                                                           cur_category.segment3||' was created',chr(10)),
                    a.last_update_date=sysdate,
                    a.last_updated_by=fnd_global.user_id
                WHERE a.line_id=cur_category.line_id;*/
              ELSE
                FOR i IN 1 .. l_error_tbl.count LOOP
                  l_err_msg := l_err_msg || l_error_tbl(i).message_text ||
                               chr(10);
                
                END LOOP;
                -----DBMS_OUTPUT.put_line('Category='''||v_conc_categ_code||''' creation ERROR: '||l_err_msg);
                v_categories_failured := v_categories_failured + 1;
              END IF;
            
              BEGIN
                v_step := 'Step 95';
                inv_item_category_pub.create_valid_category(p_api_version        => '1.0',
                                                            p_init_msg_list      => fnd_api.g_true,
                                                            p_commit             => fnd_api.g_true,
                                                            p_category_id        => v_insert_nextcateg,
                                                            p_category_set_id    => v_category_set_id,
                                                            p_parent_category_id => NULL,
                                                            x_return_status      => l_return_status,
                                                            x_errorcode          => l_error_code,
                                                            x_msg_count          => l_msg_count,
                                                            x_msg_data           => l_msg_data);
                IF l_return_status = 'S' THEN
                  ---DBMS_OUTPUT.put_line('Valid Category was created successfuly');
                  NULL;
                ELSE
                  FOR i IN 1 .. l_error_tbl.count LOOP
                    l_err_msg := l_err_msg || l_error_tbl(i).message_text ||
                                 chr(10);
                  
                  END LOOP;
                  ---DBMS_OUTPUT.put_line('Valid Category creation ERROR: '||l_err_msg);
                END IF;
              EXCEPTION
                WHEN OTHERS THEN
                  NULL;
              END;
              -- IF;               
          END;
        
          IF MOD(v_counter, 100) = 0 THEN
            COMMIT;
          END IF;
        
        EXCEPTION
          WHEN missing_segment THEN
            v_missing_segment := v_missing_segment + 1;
          WHEN segment_already_exists THEN
            v_segment_already_exists := v_segment_already_exists + 1;
          WHEN OTHERS THEN
            NULL;
            ------DBMS_OUTPUT.put_line('Error when processing category='''||v_conc_categ_code||''': '||sqlerrm); 
        
        END;
        ---------------------- the end of CATEGORIES LOOP ------------------------------
      END LOOP;
      COMMIT;
    END LOOP;
    COMMIT;
    v_step := 'Step 100';
    IF v_missing_segment > 0 THEN
      fnd_file.put_line(fnd_file.output,
                        v_missing_segment ||
                        ' records with missing segment / Invalid Segment1');
      fnd_file.put_line(fnd_file.log,
                        v_missing_segment ||
                        ' records with missing segment / Invalid Segment1');
    END IF;
    IF v_segment_already_exists > 0 THEN
      fnd_file.put_line(fnd_file.output,
                        v_segment_already_exists ||
                        ' records with ... segment already exists in other case');
      fnd_file.put_line(fnd_file.log,
                        v_segment_already_exists ||
                        ' records with ... segment already exists in other case');
    END IF;
    IF v_new_segments_created > 0 THEN
      fnd_file.put_line(fnd_file.output,
                        v_new_segments_created || ' new segments created');
      fnd_file.put_line(fnd_file.log,
                        v_new_segments_created || ' new segments created');
    END IF;
    IF v_new_categories_cntr > 0 THEN
      fnd_file.put_line(fnd_file.output,
                        v_new_categories_cntr ||
                        ' new categories in this batch');
      fnd_file.put_line(fnd_file.log,
                        v_new_categories_cntr ||
                        ' new categories in this batch');
    ELSE
      fnd_file.put_line(fnd_file.output,
                        ' no new categories in this batch');
      fnd_file.put_line(fnd_file.log, ' no new categories in this batch');
    END IF;
  
    IF v_categories_success > 0 THEN
      fnd_file.put_line(fnd_file.output,
                        v_categories_success ||
                        ' categories are created successfuly');
      fnd_file.put_line(fnd_file.log,
                        v_categories_success ||
                        ' categories are created successfuly');
    END IF;
    IF v_categories_failured > 0 THEN
      fnd_file.put_line(fnd_file.output,
                        v_categories_failured ||
                        ' categories creation failure');
      fnd_file.put_line(fnd_file.log,
                        v_categories_failured ||
                        ' categories creation failure');
    END IF;
  
    RETURN 'S';
  EXCEPTION
    WHEN OTHERS THEN
      l_err_msg := 'Unexpected ERROR in XXCONV_CATEGORIES_PKG.check_new_ssys_categories function: ' ||
                   v_step || ' ' || SQLERRM;
      fnd_file.put_line(fnd_file.output, '=======' || l_err_msg);
      fnd_file.put_line(fnd_file.log, '=======' || l_err_msg);
      RETURN l_err_msg;
  END check_new_ssys_categories;
  -------------------------------------------------------------------------------------------------
  FUNCTION load_fdm_category_assignments RETURN VARCHAR2 IS
    --return values:  'S' or Error Message
  
    CURSOR get_operating_units IS
      SELECT ou.organization_id org_id, ou.name operating_unit
        FROM hr_operating_units ou
       WHERE ou.name IN ('OBJET DE (OU)', 'OBJET HK (OU)');
  
    CURSOR get_organiz_and_sourcing_rule(p_org_id NUMBER) IS
      SELECT DISTINCT s.sourcing_rule_id,
                      s.sourcing_rule_type,
                      s.sourcing_rule_name,
                      mp.organization_id,
                      mp.organization_code
        FROM mrp_sourcing_rules s,
             mrp_sr_receipt_org sr,
             mrp_sr_source_org so,
             (SELECT a.organization_id, a.organization_code
                FROM mtl_parameters a
               WHERE a.organization_id IN
                     (728 /*ESB*/ /*101 EOG*/,
                      729 /*ETF*/ /*102 EOT*/,
                      726 /*ASH*/ /*121 POH*/,
                      725 /*ATH*/ /*461 POT*/)
                 AND ((p_org_id = 96 AND
                     a.organization_id IN
                     (728 /*ESB*/ /*101 EOG*/, 729 /*ETF*/ /*102 EOT*/)) OR
                     (p_org_id = 103 AND
                     a.organization_id IN
                     (726 /*ASH*/ /*121 POH*/, 725 /*ATH*/ /*461 POT*/)))) mp
       WHERE sr.sourcing_rule_id = s.sourcing_rule_id
         AND so.sr_receipt_id = sr.sr_receipt_id
         AND s.sourcing_rule_name IN ('SSYS DE', 'SSYS HK')
         AND ((p_org_id = 96 AND s.sourcing_rule_name = 'SSYS DE') OR
             (p_org_id = 103 AND s.sourcing_rule_name = 'SSYS HK'));
  
    CURSOR get_fdm_categories IS
      SELECT c.category_id, c.description
        FROM xxinv_ssys_items a, mtl_categories_v c
       WHERE a.status = 'N'
         AND rtrim(a.item_category) = c.category_concat_segs
         AND c.attribute8 = 'FDM';
  
    invalid_operating_unit EXCEPTION;
  
    ----l_org_id                 NUMBER;
    l_error_msg     VARCHAR2(500);
    l_assignment_id NUMBER;
  
    l_success_inserted_assignments NUMBER := 0;
    l_inserting_assignment_failure NUMBER := 0;
    l_step                         VARCHAR2(100);
  BEGIN
  
    l_step := 'Step 0';
    fnd_file.put_line(fnd_file.output, ''); --empty line
    fnd_file.put_line(fnd_file.output, ''); --empty line
    fnd_file.put_line(fnd_file.output, ''); --empty line
    fnd_file.put_line(fnd_file.output,
                      '================= Category-Organization Assignments ==============');
    fnd_file.put_line(fnd_file.log, ''); --empty line
    fnd_file.put_line(fnd_file.log, ''); --empty line
    fnd_file.put_line(fnd_file.log, ''); --empty line
    fnd_file.put_line(fnd_file.log,
                      '================= Category-Organization Assignments ==============');
  
    FOR operating_unit_rec IN get_operating_units LOOP
      ---=============  OPERATING UNITS LOOP ======================
      BEGIN
        mo_global.set_org_access(p_org_id_char     => operating_unit_rec.org_id,
                                 p_sp_id_char      => NULL,
                                 p_appl_short_name => 'PO');
      EXCEPTION
        WHEN OTHERS THEN
          l_error_msg := 'Invalid Operating Unit ''' ||
                         operating_unit_rec.operating_unit || '''';
          RAISE invalid_operating_unit;
      END;
      -------
      l_step := 'Step 5';
      FOR organiz_and_sourcing_rule_rec IN get_organiz_and_sourcing_rule(operating_unit_rec.org_id) LOOP
        ---=============  ORGANIZATIONS AND SOURCING RULES LOOP ====================== 
        l_step                         := 'Step 10';
        l_success_inserted_assignments := 0;
        l_inserting_assignment_failure := 0;
        FOR fdm_category_rec IN get_fdm_categories LOOP
          ---=============  FDM CATEGORIES LOOP ======================
          l_step := 'Step 15';
          SELECT mrp_sr_assignments_s.nextval
            INTO l_assignment_id
            FROM sys.dual;
          l_step := 'Step 20';
          BEGIN
            INSERT INTO mrp_sr_assignments
              (assignment_id,
               assignment_type,
               sourcing_rule_id,
               sourcing_rule_type,
               assignment_set_id,
               last_update_date,
               last_updated_by,
               creation_date,
               created_by,
               last_update_login,
               organization_id,
               category_id,
               category_set_id)
            VALUES
              (l_assignment_id,
               5, --- category-organization
               organiz_and_sourcing_rule_rec.sourcing_rule_id,
               1, ---  1=SOURCING RULE
               1, --- 'Global Assigment' set
               SYSDATE - 1,
               fnd_global.user_id,
               SYSDATE - 1,
               fnd_global.user_id,
               -1,
               organiz_and_sourcing_rule_rec.organization_id,
               fdm_category_rec.category_id,
               1100000041); ---  Main Category Set
            l_success_inserted_assignments := l_success_inserted_assignments + 1;
          EXCEPTION
            WHEN OTHERS THEN
              l_inserting_assignment_failure := l_inserting_assignment_failure + 1;
          END;
        
        ---=============  the end of FDM CATEGORIES LOOP ======================
        END LOOP;
        COMMIT;
        IF l_success_inserted_assignments > 0 THEN
          fnd_file.put_line(fnd_file.output,
                            '======== ' || l_success_inserted_assignments ||
                            ' category-organization assignments created in organization ''' ||
                            organiz_and_sourcing_rule_rec.organization_code || '''');
          fnd_file.put_line(fnd_file.log,
                            '======== ' || l_success_inserted_assignments ||
                            ' category-organization assignments created in organization ''' ||
                            organiz_and_sourcing_rule_rec.organization_code || '''');
        END IF;
        IF l_inserting_assignment_failure > 0 THEN
          fnd_file.put_line(fnd_file.output,
                            '======== ' || l_inserting_assignment_failure ||
                            ' category-organization assignments creation FAILURED in organization ''' ||
                            organiz_and_sourcing_rule_rec.organization_code || '''');
          fnd_file.put_line(fnd_file.log,
                            '======== ' || l_inserting_assignment_failure ||
                            ' category-organization assignments creation FAILURED in organization ''' ||
                            organiz_and_sourcing_rule_rec.organization_code || '''');
        END IF;
      
      ---=============  the end of ORGANIZATIONS AND SOURCING RULES LOOP ====================== 
      END LOOP;
      ---=============  the end of OPERATING UNITS LOOP ======================
    END LOOP;
  
    RETURN 'S';
  EXCEPTION
    WHEN OTHERS THEN
      l_error_msg := 'Unexpected ERROR in XXCONV_CATEGORIES_PKG.load_fdm_category_assignments function: ' ||
                     l_step || ' ' || SQLERRM;
      fnd_file.put_line(fnd_file.output, '=======' || l_error_msg);
      fnd_file.put_line(fnd_file.log, '=======' || l_error_msg);
      RETURN l_error_msg;
  END load_fdm_category_assignments;
  ------------------------------------------------------------------------------------------------------------
  FUNCTION create_ssys_items RETURN VARCHAR2 IS
    --return values:  'S' or Error Message
  
    v_step VARCHAR2(30);
  
    CURSOR get_items IS
      SELECT rtrim(a.item_code) item_code,
             decode(mp.organization_id, 91, 1, mp.organization_id) for_order_by, --- We create Item in Master Organization first
             mp.organization_id,
             mp.organization_code,
             a.line_id,
             ltrim(rtrim(a.item_desc), '-') item_desc,
             rtrim(a.item_template_name) item_template_name,
             rtrim(a.primary_uom_code) primary_uom_code,
             rtrim(a.product_line) product_line,
             rtrim(a.country) country,
             rtrim(a.hts_code) hts_code,
             a.unit_length,
             a.unit_width,
             a.unit_height,
             a.unit_volume,
             a.unit_weight,
             rtrim(a.dimension_uom_code) dimension_uom_code,
             rtrim(a.volume_uom_code) volume_uom_code,
             rtrim(a.weight_uom_code) weight_uom_code,
             rtrim(a.auto_serial_alpha_prefix) auto_serial_alpha_prefix,
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
        FROM xxinv_ssys_items a,
             mtl_parameters mp,
             gl_code_combinations_kfv cc_sales,
             gl_code_combinations_kfv cc_encumbrance,
             gl_code_combinations_kfv cc_expense,
             gl_code_combinations_kfv cc_cost_of_sales,
             (SELECT ffv.flex_value organization_code
                FROM fnd_flex_value_sets fvs, fnd_flex_values_vl ffv
               WHERE fvs.flex_value_set_id = ffv.flex_value_set_id
                 AND fvs.flex_value_set_name =
                     'XXINV_SSYS_ITEMS_ORGANIZATIONS') organizations_tab
       WHERE a.status = 'N'
         AND mp.sales_account = cc_sales.code_combination_id
         AND mp.encumbrance_account = cc_encumbrance.code_combination_id
         AND mp.expense_account = cc_expense.code_combination_id
         AND mp.cost_of_sales_account =
             cc_cost_of_sales.code_combination_id
         AND cc_sales.enabled_flag = 'Y'
         AND cc_encumbrance.enabled_flag = 'Y'
         AND cc_expense.enabled_flag = 'Y'
         AND cc_cost_of_sales.enabled_flag = 'Y'
         AND mp.organization_code = organizations_tab.organization_code
       ORDER BY a.item_code,
                decode(mp.organization_id, 91, 1, mp.organization_id);
  
    ---v_user_id fnd_user.user_id%TYPE;
    l_counter NUMBER := 0;
    l_coa_id  NUMBER;
    ----l_org_id                    NUMBER;
    l_error_msg VARCHAR2(3000);
    ----l_err_msg                   VARCHAR2(500);
    l_return_status VARCHAR2(1);
    ----v_cat_group_id              mtl_item_catalog_groups_b.item_catalog_group_id%TYPE;
    v_planner_code       VARCHAR2(10);
    l_hts_code           VARCHAR2(50);
    l_unit_of_measure    mtl_units_of_measure_tl.unit_of_measure%TYPE;
    l_dimension_uom_code VARCHAR2(3);
    l_weight_uom_code    VARCHAR2(3);
    l_volume_uom_code    VARCHAR2(3);
  
    ---accounts------
    l_sales_account_id            NUMBER;
    l_encumbrance_account_id      NUMBER;
    l_expense_account_id          NUMBER;
    l_cogs_id                     NUMBER;
    l_sales_concat_segments       VARCHAR2(100);
    l_encumbrance_concat_segments VARCHAR2(100);
    l_expense_concat_segments     VARCHAR2(100);
    l_cogs_concat_segments        VARCHAR2(100);
  
    l_country_code          VARCHAR2(5);
    l_inventory_status_code VARCHAR2(20);
    l_template_id           NUMBER;
    invalid_item EXCEPTION;
  
    t_item_rec     inv_item_grp.item_rec_type;
    t_item_rec_out inv_item_grp.item_rec_type;
    t_rev_rec      inv_item_grp.item_revision_rec_type;
    --l_error_tbl    error_handler.error_tbl_type;
    l_error_tbl inv_item_grp.error_tbl_type;
  
    l_items_success_created_91  NUMBER := 0;
    l_items_failure_91          NUMBER := 0;
    l_items_success_created_735 NUMBER := 0;
    l_items_failure_735         NUMBER := 0;
    l_items_success_created_734 NUMBER := 0;
    l_items_failure_734         NUMBER := 0;
    l_items_success_created_733 NUMBER := 0;
    l_items_failure_733         NUMBER := 0;
    l_items_success_created_741  NUMBER := 0;
    l_items_failure_741          NUMBER := 0;
    l_items_success_created_95  NUMBER := 0;
    l_items_failure_95          NUMBER := 0;
    l_items_success_created_728 NUMBER := 0;
    l_items_failure_728         NUMBER := 0;
    l_items_success_created_729 NUMBER := 0;
    l_items_failure_729         NUMBER := 0;
    l_items_success_created_726 NUMBER := 0;
    l_items_failure_726         NUMBER := 0;
    l_items_success_created_122 NUMBER := 0;
    l_items_failure_122         NUMBER := 0;
    l_items_success_created_727 NUMBER := 0;
    l_items_failure_727         NUMBER := 0;
    l_items_success_created_742 NUMBER := 0;
    l_items_failure_742         NUMBER := 0;
    l_items_success_created_725 NUMBER := 0;
    l_items_failure_725         NUMBER := 0;
  
  BEGIN
  
    v_step := 'Step 0';
  
    fnd_file.put_line(fnd_file.output, ''); --empty line
    fnd_file.put_line(fnd_file.output, ''); --empty line
    fnd_file.put_line(fnd_file.output, ''); --empty line
    fnd_file.put_line(fnd_file.output,
                      '================= Create New SSYS Items =====================');
    fnd_file.put_line(fnd_file.log, ''); --empty line
    fnd_file.put_line(fnd_file.log, ''); --empty line
    fnd_file.put_line(fnd_file.log, ''); --empty line
    fnd_file.put_line(fnd_file.log,
                      '================= Create New SSYS Items =====================');
  
    FOR cur_item IN get_items LOOP
    
      BEGIN
        v_step                  := 'Step 10';
        l_counter               := nvl(l_counter, 0) + 1;
        l_inventory_status_code := NULL;
        ----v_planner_code                := NULL;
        l_sales_account_id            := NULL;
        l_encumbrance_account_id      := NULL;
        l_expense_account_id          := NULL;
        l_cogs_id                     := NULL;
        l_sales_concat_segments       := NULL;
        l_encumbrance_concat_segments := NULL;
        l_expense_concat_segments     := NULL;
        l_cogs_concat_segments        := NULL;
        l_country_code                := NULL;
        l_template_id                 := NULL;
        t_item_rec                    := inv_item_grp.g_miss_item_rec;
        t_rev_rec                     := inv_item_grp.g_miss_revision_rec;
        l_error_tbl.delete;
      
        l_return_status := 'S';
      
        --------------------------------------        
        BEGIN
          v_step := 'Step 15';
          SELECT inventory_item_status_code
            INTO l_inventory_status_code
            FROM mtl_item_status
           WHERE inventory_item_status_code_tl = 'Production';
        EXCEPTION
          WHEN OTHERS THEN
            l_inventory_status_code := NULL;
        END;
        --------
        v_step                        := 'Step 20';
        l_sales_concat_segments       := cur_item.sales_concat_segments_1_2_3_4 || '.' ||
                                         cur_item.product_line || '.' ||
                                         cur_item.sales_concat_segments_6_7_8_9;
        l_encumbrance_concat_segments := cur_item.encumb_concat_segments_1_2_3_4 || '.' ||
                                         cur_item.product_line || '.' ||
                                         cur_item.encumb_concat_segments_6_7_8_9;
        l_expense_concat_segments     := cur_item.expense_segment1 || '.' ||
                                         '210' || '.' || -- segment2 (Department)--const
                                         cur_item.expens_concat_segments_3_4 || '.' ||
                                         cur_item.product_line || '.' ||
                                         cur_item.expens_concat_segments_6_7_8_9;
        l_cogs_concat_segments        := cur_item.cogs_concat_segments_1_2_3_4 || '.' ||
                                         cur_item.product_line || '.' ||
                                         cur_item.cogs_concat_segments_6_7_8_9;
        ------check/create sales account-----
        BEGIN
          v_step := 'Step 25';
          SELECT code_combination_id
            INTO l_sales_account_id
            FROM gl_code_combinations_kfv
           WHERE concatenated_segments = l_sales_concat_segments
             AND enabled_flag = 'Y';
        EXCEPTION
          WHEN no_data_found THEN
            v_step := 'Step 30';
            xxgl_utils_pkg.get_and_create_account(p_concat_segment      => l_sales_concat_segments,
                                                  p_coa_id              => l_coa_id,
                                                  x_code_combination_id => l_sales_account_id,
                                                  x_return_code         => l_return_status,
                                                  x_err_msg             => l_error_msg);
          
            IF l_return_status != fnd_api.g_ret_sts_success THEN
              l_error_msg := 'Create Sales account ''' ||
                             l_sales_concat_segments || ''' Error';
              RAISE invalid_item;
            END IF;
        END;
        ------check/create encumbrance account-----
        BEGIN
          v_step := 'Step 35';
          SELECT code_combination_id
            INTO l_encumbrance_account_id
            FROM gl_code_combinations_kfv
           WHERE concatenated_segments = l_encumbrance_concat_segments
             AND enabled_flag = 'Y';
        EXCEPTION
          WHEN no_data_found THEN
            v_step := 'Step 40';
            xxgl_utils_pkg.get_and_create_account(p_concat_segment      => l_encumbrance_concat_segments,
                                                  p_coa_id              => l_coa_id,
                                                  x_code_combination_id => l_encumbrance_account_id,
                                                  x_return_code         => l_return_status,
                                                  x_err_msg             => l_error_msg);
          
            IF l_return_status != fnd_api.g_ret_sts_success THEN
              l_error_msg := 'Create Encumbrance account ''' ||
                             l_encumbrance_concat_segments || ''' Error';
              RAISE invalid_item;
            END IF;
        END;
        ------check/create expense account-----            
        BEGIN
          v_step := 'Step 45';
          SELECT code_combination_id
            INTO l_expense_account_id
            FROM gl_code_combinations_kfv
           WHERE concatenated_segments = l_expense_concat_segments
             AND enabled_flag = 'Y';
        EXCEPTION
          WHEN no_data_found THEN
            v_step := 'Step 50';
            xxgl_utils_pkg.get_and_create_account(p_concat_segment      => l_expense_concat_segments,
                                                  p_coa_id              => l_coa_id,
                                                  x_code_combination_id => l_expense_account_id,
                                                  x_return_code         => l_return_status,
                                                  x_err_msg             => l_error_msg);
          
            IF l_return_status != fnd_api.g_ret_sts_success THEN
              l_error_msg := 'Create Expense account ''' ||
                             l_expense_concat_segments || ''' Error';
              RAISE invalid_item;
            END IF;
        END;
        ------check/create cogs account-----
        BEGIN
          v_step := 'Step 55';
          SELECT code_combination_id
            INTO l_cogs_id
            FROM gl_code_combinations_kfv
           WHERE concatenated_segments = l_cogs_concat_segments
             AND enabled_flag = 'Y';
        EXCEPTION
          WHEN no_data_found THEN
            v_step := 'Step 60';
            xxgl_utils_pkg.get_and_create_account(p_concat_segment      => l_cogs_concat_segments,
                                                  p_coa_id              => l_coa_id,
                                                  x_code_combination_id => l_cogs_id,
                                                  x_return_code         => l_return_status,
                                                  x_err_msg             => l_error_msg);
          
            IF l_return_status != fnd_api.g_ret_sts_success THEN
              l_error_msg := 'Create Cogs account ''' ||
                             l_cogs_concat_segments || ''' Error';
              RAISE invalid_item;
            END IF;
        END;
        -----------
        IF cur_item.country IS NOT NULL THEN
          BEGIN
            v_step := 'Step 65';
            SELECT t.territory_code
              INTO l_country_code
              FROM fnd_territories_vl t
             WHERE t.territory_code = cur_item.country;
          EXCEPTION
            WHEN no_data_found THEN
              l_country_code := NULL;
          END;
        END IF;
        --------------------
        BEGIN
          v_step := 'Step 70';
          SELECT mit.template_id
            INTO l_template_id
            FROM mtl_item_templates_vl mit
           WHERE mit.template_name = cur_item.item_template_name;
        EXCEPTION
          WHEN OTHERS THEN
            l_error_msg := 'Invalid Template';
            RAISE invalid_item;
        END;
        --------------------
        IF rtrim(cur_item.dimension_uom_code) IS NOT NULL THEN
          ------
          BEGIN
            v_step := 'Step 70';
            SELECT muom.uom_code
              INTO l_dimension_uom_code
              FROM mtl_units_of_measure muom
             WHERE muom.uom_code = rtrim(cur_item.dimension_uom_code) --- dimension_uom_code - is not required
               AND muom.uom_class = 'LENGTH';
          EXCEPTION
            WHEN OTHERS THEN
              l_dimension_uom_code := NULL;
          END;
          ------
        END IF;
        --------------------
        IF rtrim(cur_item.weight_uom_code) IS NOT NULL THEN
          ------
          BEGIN
            v_step := 'Step 75';
            SELECT muom.uom_code
              INTO l_weight_uom_code
              FROM mtl_units_of_measure muom
             WHERE muom.uom_code = rtrim(cur_item.weight_uom_code) --- weight_uom_code - is not required
               AND muom.uom_class = 'WEIGHT';
          EXCEPTION
            WHEN OTHERS THEN
              l_weight_uom_code := NULL;
          END;
          ------
        END IF;
        --------------------
        IF rtrim(cur_item.volume_uom_code) IS NOT NULL THEN
          ------
          BEGIN
            v_step := 'Step 75';
            SELECT muom.uom_code
              INTO l_volume_uom_code
              FROM mtl_units_of_measure muom
             WHERE muom.uom_code = rtrim(cur_item.volume_uom_code) --- volume_uom_code - is not required
               AND muom.uom_class = 'VOLUME';
          EXCEPTION
            WHEN OTHERS THEN
              l_volume_uom_code := NULL;
          END;
          ------
        END IF;
        --------------------
        BEGIN
          v_step := 'Step 90';
          SELECT muom.unit_of_measure
            INTO l_unit_of_measure
            FROM mtl_units_of_measure muom
           WHERE muom.uom_code = upper(cur_item.primary_uom_code);
        
        EXCEPTION
          WHEN OTHERS THEN
            l_error_msg := 'Invalid UOM ';
            RAISE invalid_item;
        END;
        --------------------
        IF rtrim(cur_item.hts_code) IS NOT NULL THEN
          --- hts_code - is not required
          -------
          BEGIN
            v_step := 'Step 95';
            SELECT ffv.flex_value
              INTO l_hts_code
              FROM fnd_flex_value_sets fvs, fnd_flex_values_vl ffv
             WHERE fvs.flex_value_set_id = ffv.flex_value_set_id
               AND fvs.flex_value_set_name = 'XXINV_INTRASTAT_Tariff_code'
               AND ffv.flex_value = rtrim(cur_item.hts_code);
          EXCEPTION
            WHEN OTHERS THEN
              l_hts_code := NULL;
          END;
          --------
        END IF;
        --------------------
        v_step                                := 'Step 100';
        t_item_rec.item_number                := upper(cur_item.item_code);
        t_item_rec.segment1                   := upper(cur_item.item_code);
        t_item_rec.description                := cur_item.item_desc;
        t_item_rec.organization_id            := cur_item.organization_id;
        t_item_rec.primary_uom_code           := cur_item.primary_uom_code;
        t_item_rec.primary_unit_of_measure    := l_unit_of_measure;
        t_item_rec.inventory_item_status_code := l_inventory_status_code;
        t_item_rec.planner_code               := nvl(v_planner_code,
                                                     fnd_api.g_miss_char);
      
        t_item_rec.list_price_per_unit := 0;
      
        IF l_dimension_uom_code IS NOT NULL AND
           nvl(cur_item.unit_length, -1) > 0 AND
           nvl(cur_item.unit_width, -1) > 0 AND
           nvl(cur_item.unit_height, -1) > 0 THEN
          t_item_rec.dimension_uom_code := l_dimension_uom_code;
          t_item_rec.unit_length        := cur_item.unit_length;
          t_item_rec.unit_width         := cur_item.unit_width;
          t_item_rec.unit_height        := cur_item.unit_height;
        ELSE
          t_item_rec.dimension_uom_code := fnd_api.g_miss_char;
          t_item_rec.unit_length        := fnd_api.g_miss_num;
          t_item_rec.unit_width         := fnd_api.g_miss_num;
          t_item_rec.unit_height        := fnd_api.g_miss_num;
        END IF;
      
        t_item_rec.auto_serial_alpha_prefix := nvl(cur_item.auto_serial_alpha_prefix,
                                                   fnd_api.g_miss_char);
      
        IF l_weight_uom_code IS NOT NULL AND
           nvl(cur_item.unit_weight, -1) > 0 THEN
          t_item_rec.unit_weight     := cur_item.unit_weight;
          t_item_rec.weight_uom_code := l_weight_uom_code;
        ELSE
          t_item_rec.unit_weight     := fnd_api.g_miss_num;
          t_item_rec.weight_uom_code := fnd_api.g_miss_char;
        END IF;
      
        IF l_volume_uom_code IS NOT NULL AND
           nvl(cur_item.unit_volume, -1) > 0 THEN
          t_item_rec.unit_volume     := cur_item.unit_volume;
          t_item_rec.volume_uom_code := l_volume_uom_code;
        ELSE
          t_item_rec.unit_volume     := fnd_api.g_miss_num;
          t_item_rec.volume_uom_code := fnd_api.g_miss_char;
        END IF;
      
        t_item_rec.cost_of_sales_account := nvl(l_cogs_id,
                                                fnd_api.g_miss_num);
        t_item_rec.sales_account         := nvl(l_sales_account_id,
                                                fnd_api.g_miss_num);
        t_item_rec.encumbrance_account   := nvl(l_encumbrance_account_id,
                                                fnd_api.g_miss_num);
        t_item_rec.expense_account       := nvl(l_expense_account_id,
                                                fnd_api.g_miss_num);
      
        t_item_rec.attribute2      := l_country_code; ---cur_item.country;
        t_item_rec.attribute3      := l_hts_code; ---cur_item.hts_code;
        t_rev_rec.transaction_type := ego_item_pub.g_ttype_create;
        t_rev_rec.item_number      := upper(cur_item.item_code);
        t_rev_rec.organization_id  := cur_item.organization_id; -----cur_item.organization_id;
        t_rev_rec.revision_code    := '0'; ----cur_item.revision;
      
        v_step := 'Step 110';
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
          FOR i IN 1 .. l_error_tbl.count LOOP
            l_error_msg := l_error_msg || l_error_tbl(i).message_text ||
                           chr(10);
          
          END LOOP;
        
          RAISE invalid_item;
        
        END IF;
      
        v_step := 'Step 120';
        /*UPDATE XXINV_SSYS_ITEMS  a
        SET ----a.status='S',
            a.message = ltrim(a.message||chr(10)||'Item='||cur_item.item_code||' was created in '||cur_item.organization_code,chr(10)),
            a.last_update_date=sysdate,
            a.last_updated_by=fnd_global.user_id
        WHERE a.line_id = cur_item.line_id;*/
      
        v_step := 'Step 130';
        IF cur_item.organization_id = 91 THEN
          l_items_success_created_91 := l_items_success_created_91 + 1;
        ELSIF cur_item.organization_id = 735 THEN
          l_items_success_created_735 := l_items_success_created_735 + 1;
        ELSIF cur_item.organization_id = 734 THEN
          l_items_success_created_734 := l_items_success_created_734 + 1;
        ELSIF cur_item.organization_id = 733 THEN
          l_items_success_created_733 := l_items_success_created_733 + 1;
        ELSIF cur_item.organization_id = 741 THEN
          l_items_success_created_741 := l_items_success_created_741 + 1;
        ELSIF cur_item.organization_id = 95 THEN
          l_items_success_created_95 := l_items_success_created_95 + 1;
        ELSIF cur_item.organization_id = 728 THEN
          l_items_success_created_728 := l_items_success_created_728 + 1;
        ELSIF cur_item.organization_id = 729 THEN
          l_items_success_created_729 := l_items_success_created_729 + 1;
        ELSIF cur_item.organization_id = 726 THEN
          l_items_success_created_726 := l_items_success_created_726 + 1;
        ELSIF cur_item.organization_id = 122 THEN
          l_items_success_created_122 := l_items_success_created_122 + 1;
        ELSIF cur_item.organization_id = 727 THEN
          l_items_success_created_727 := l_items_success_created_727 + 1;
        ELSIF cur_item.organization_id = 742 THEN
          l_items_success_created_742 := l_items_success_created_742 + 1;
        ELSIF cur_item.organization_id = 725 THEN
          l_items_success_created_725 := l_items_success_created_725 + 1;
        END IF;
      
      EXCEPTION
      
        WHEN invalid_item THEN
          UPDATE xxinv_ssys_items a
             SET a.status           = 'E',
                 a.error_message    = l_error_msg,
                 a.last_update_date = SYSDATE,
                 a.last_updated_by  = fnd_global.user_id
           WHERE a.line_id = cur_item.line_id;
        
          IF cur_item.organization_id = 91 THEN
            l_items_failure_91 := l_items_failure_91 + 1;
          ELSIF cur_item.organization_id = 735 THEN
            l_items_failure_735 := l_items_failure_735 + 1;
          ELSIF cur_item.organization_id = 734 THEN
            l_items_failure_734 := l_items_failure_734 + 1;
          ELSIF cur_item.organization_id = 733 THEN
            l_items_failure_733 := l_items_failure_733 + 1;
          ELSIF cur_item.organization_id = 741 THEN
            l_items_failure_741 := l_items_failure_741 + 1;
          ELSIF cur_item.organization_id = 95 THEN
            l_items_failure_95 := l_items_failure_95 + 1;
          ELSIF cur_item.organization_id = 728 THEN
            l_items_failure_728 := l_items_failure_728 + 1;
          ELSIF cur_item.organization_id = 729 THEN
            l_items_failure_729 := l_items_failure_729 + 1;
          ELSIF cur_item.organization_id = 726 THEN
            l_items_failure_726 := l_items_failure_726 + 1;
          ELSIF cur_item.organization_id = 122 THEN
            l_items_failure_122 := l_items_failure_122 + 1;
          ELSIF cur_item.organization_id = 727 THEN
            l_items_failure_727 := l_items_failure_727 + 1;
          ELSIF cur_item.organization_id = 742 THEN
            l_items_failure_742 := l_items_failure_742 + 1;
          ELSIF cur_item.organization_id = 725 THEN
            l_items_failure_725 := l_items_failure_725 + 1;
          END IF;
        
        WHEN OTHERS THEN
          l_error_msg := SQLERRM;
          UPDATE xxinv_ssys_items a
             SET a.status           = 'E',
                 a.error_message    = 'When Others Error  , ' || v_step || ' ' ||
                                      l_error_msg,
                 a.last_update_date = SYSDATE,
                 a.last_updated_by  = fnd_global.user_id
           WHERE a.line_id = cur_item.line_id;
        
          IF cur_item.organization_id = 91 THEN
            l_items_failure_91 := l_items_failure_91 + 1;
          ELSIF cur_item.organization_id = 735 THEN
            l_items_failure_735 := l_items_failure_735 + 1;
          ELSIF cur_item.organization_id = 734 THEN
            l_items_failure_734 := l_items_failure_734 + 1;
          ELSIF cur_item.organization_id = 733 THEN
            l_items_failure_733 := l_items_failure_733 + 1;
          ELSIF cur_item.organization_id = 741 THEN
            l_items_failure_741 := l_items_failure_741 + 1;
          ELSIF cur_item.organization_id = 95 THEN
            l_items_failure_95 := l_items_failure_95 + 1;
          ELSIF cur_item.organization_id = 728 THEN
            l_items_failure_728 := l_items_failure_728 + 1;
          ELSIF cur_item.organization_id = 729 THEN
            l_items_failure_729 := l_items_failure_729 + 1;
          ELSIF cur_item.organization_id = 726 THEN
            l_items_failure_726 := l_items_failure_726 + 1;
          ELSIF cur_item.organization_id = 122 THEN
            l_items_failure_122 := l_items_failure_122 + 1;
          ELSIF cur_item.organization_id = 727 THEN
            l_items_failure_727 := l_items_failure_727 + 1;
          ELSIF cur_item.organization_id = 742 THEN
            l_items_failure_742 := l_items_failure_742 + 1;
          ELSIF cur_item.organization_id = 725 THEN
            l_items_failure_725 := l_items_failure_725 + 1;
          END IF;
        
      END;
    
    END LOOP;
    COMMIT;
  
    IF l_items_success_created_91 > 0 OR l_items_success_created_735 > 0 OR
       l_items_success_created_734 > 0 OR l_items_success_created_733 > 0 OR
       l_items_success_created_741 > 0 OR l_items_success_created_95 > 0 OR
       l_items_success_created_728 > 0 OR l_items_success_created_729 > 0 OR
       l_items_success_created_726 > 0 OR l_items_success_created_122 > 0 OR
       l_items_success_created_727 > 0 OR l_items_success_created_742 > 0 OR
       l_items_success_created_725 > 0 THEN
    
      fnd_file.put_line(fnd_file.output,
                        '=========================SUCCESS===========================================');
      IF l_items_success_created_91 > 0 THEN
        fnd_file.put_line(fnd_file.output,
                          l_items_success_created_91 ||
                          ' items are created successfully in organization ''OMA'' 91');
        fnd_file.put_line(fnd_file.log,
                          l_items_success_created_91 ||
                          ' items are created successfully in organization ''OMA'' 91');
      END IF;
      IF l_items_success_created_735 > 0 THEN
        fnd_file.put_line(fnd_file.output,
                          l_items_success_created_735 ||
                          ' items are created successfully in organization_id=735');
        fnd_file.put_line(fnd_file.log,
                          l_items_success_created_735 ||
                          ' items are created successfully in organization_id=735');
      END IF;
      IF l_items_success_created_734 > 0 THEN
        fnd_file.put_line(fnd_file.output,
                          l_items_success_created_734 ||
                          ' items are created successfully in organization_id=734');
        fnd_file.put_line(fnd_file.log,
                          l_items_success_created_734 ||
                          ' items are created successfully in organization_id=734');
      END IF;
      IF l_items_success_created_733 > 0 THEN
        fnd_file.put_line(fnd_file.output,
                          l_items_success_created_733 ||
                          ' items are created successfully in organization_id=733');
        fnd_file.put_line(fnd_file.log,
                          l_items_success_created_733 ||
                          ' items are created successfully in organization_id=733');
      END IF;
      IF l_items_success_created_741 > 0 THEN
        fnd_file.put_line(fnd_file.output,
                          l_items_success_created_741 ||
                          ' items are created successfully in organization_id=741');
        fnd_file.put_line(fnd_file.log,
                          l_items_success_created_741 ||
                          ' items are created successfully in organization_id=741');
      END IF;
      IF l_items_success_created_95 > 0 THEN
        fnd_file.put_line(fnd_file.output,
                          l_items_success_created_95 ||
                          ' items are created successfully in organization_id=95');
        fnd_file.put_line(fnd_file.log,
                          l_items_success_created_95 ||
                          ' items are created successfully in organization_id=95');
      END IF;
      IF l_items_success_created_728 > 0 THEN
        fnd_file.put_line(fnd_file.output,
                          l_items_success_created_728 ||
                          ' items are created successfully in organization ''ESB'' 728');
        fnd_file.put_line(fnd_file.log,
                          l_items_success_created_728 ||
                          ' items are created successfully in organization ''ESB'' 728');
      END IF;
      IF l_items_success_created_729 > 0 THEN
        fnd_file.put_line(fnd_file.output,
                          l_items_success_created_729 ||
                          ' items are created successfully in organization ''ETF'' 729');
        fnd_file.put_line(fnd_file.log,
                          l_items_success_created_729 ||
                          ' items are created successfully in organization ''ETF'' 729');
      END IF;
      IF l_items_success_created_726 > 0 THEN
        fnd_file.put_line(fnd_file.output,
                          l_items_success_created_726 ||
                          ' items are created successfully in organization ''ASH'' 726');
        fnd_file.put_line(fnd_file.log,
                          l_items_success_created_726 ||
                          ' items are created successfully in organization ''ASH'' 726');
      END IF;
      IF l_items_success_created_122 > 0 THEN
        fnd_file.put_line(fnd_file.output,
                          l_items_success_created_122 ||
                          ' items are created successfully in organization_id=122');
        fnd_file.put_line(fnd_file.log,
                          l_items_success_created_122 ||
                          ' items are created successfully in organization_id=122');
      END IF;
      IF l_items_success_created_727 > 0 THEN
        fnd_file.put_line(fnd_file.output,
                          l_items_success_created_727 ||
                          ' items are created successfully in organization ''CSS'' 727');
        fnd_file.put_line(fnd_file.log,
                          l_items_success_created_727 ||
                          ' items are created successfully in organization ''CSS'' 727');
      END IF;
      IF l_items_success_created_742 > 0 THEN
        fnd_file.put_line(fnd_file.output,
                          l_items_success_created_742 ||
                          ' items are created successfully in organization_id=742');
        fnd_file.put_line(fnd_file.log,
                          l_items_success_created_742 ||
                          ' items are created successfully in organization_id=742');
      END IF;
      IF l_items_success_created_725 > 0 THEN
        fnd_file.put_line(fnd_file.output,
                          l_items_success_created_725 ||
                          ' items are created successfully in organization ''ATH'' 725');
        fnd_file.put_line(fnd_file.log,
                          l_items_success_created_725 ||
                          ' items are created successfully in organization ''ATH'' 725');
      END IF;
    END IF;
  
    IF l_items_failure_91 > 0 OR l_items_failure_735 > 0 OR
       l_items_failure_734 > 0 OR l_items_failure_733 > 0 OR
       l_items_failure_741 > 0 OR l_items_failure_95 > 0 OR
       l_items_failure_728 > 0 OR l_items_failure_729 > 0 OR
       l_items_failure_726 > 0 OR l_items_failure_122 > 0 OR
       l_items_failure_727 > 0 OR l_items_failure_742 > 0 OR
       l_items_failure_725 > 0 THEN
      IF l_items_failure_91 > 0 THEN
        fnd_file.put_line(fnd_file.output,
                          l_items_failure_91 ||
                          ' items are failured in organization ''OMA'' 91');
        fnd_file.put_line(fnd_file.log,
                          l_items_failure_91 ||
                          ' items are failured in organization ''OMA'' 91');
      END IF;
      IF l_items_failure_735 > 0 THEN
        fnd_file.put_line(fnd_file.output,
                          l_items_failure_735 ||
                          ' items are failured in organization_id=735');
        fnd_file.put_line(fnd_file.log,
                          l_items_failure_735 ||
                          ' items are failured in organization_id=735');
      END IF;
      IF l_items_failure_734 > 0 THEN
        fnd_file.put_line(fnd_file.output,
                          l_items_failure_734 ||
                          ' items are failured in organization_id=734');
        fnd_file.put_line(fnd_file.log,
                          l_items_failure_734 ||
                          ' items are failured in organization_id=734');
      END IF;
      IF l_items_failure_733 > 0 THEN
        fnd_file.put_line(fnd_file.output,
                          l_items_failure_733 ||
                          ' items are failured in organization_id=733');
        fnd_file.put_line(fnd_file.log,
                          l_items_failure_733 ||
                          ' items are failured in organization_id=733');
      END IF;
      IF l_items_failure_741 > 0 THEN
        fnd_file.put_line(fnd_file.output,
                          l_items_failure_741 ||
                          ' items are failured in organization_id=741');
        fnd_file.put_line(fnd_file.log,
                          l_items_failure_741 ||
                          ' items are failured in organization_id=741');
      END IF;
      IF l_items_failure_95 > 0 THEN
        fnd_file.put_line(fnd_file.output,
                          l_items_failure_95 ||
                          ' items are failured in organization_id=95');
        fnd_file.put_line(fnd_file.log,
                          l_items_failure_95 ||
                          ' items are failured in organization_id=95');
      END IF;
      IF l_items_failure_728 > 0 THEN
        fnd_file.put_line(fnd_file.output,
                          l_items_failure_728 ||
                          ' items are failured in organization ''ESB'' 728');
        fnd_file.put_line(fnd_file.log,
                          l_items_failure_728 ||
                          ' items are failured in organization ''ESB'' 728');
      END IF;
      IF l_items_failure_729 > 0 THEN
        fnd_file.put_line(fnd_file.output,
                          l_items_failure_729 ||
                          ' items are failured in organization ''ETF'' 729');
        fnd_file.put_line(fnd_file.log,
                          l_items_failure_729 ||
                          ' items are failured in organization ''ETF'' 729');
      END IF;
      IF l_items_failure_726 > 0 THEN
        fnd_file.put_line(fnd_file.output,
                          l_items_failure_726 ||
                          ' items are failured in organization ''ASH'' 726');
        fnd_file.put_line(fnd_file.log,
                          l_items_failure_726 ||
                          ' items are failured in organization ''ASH'' 726');
      END IF;
      IF l_items_failure_122 > 0 THEN
        fnd_file.put_line(fnd_file.output,
                          l_items_failure_122 ||
                          ' items are failured in organization_id=122');
        fnd_file.put_line(fnd_file.log,
                          l_items_failure_122 ||
                          ' items are failured in organization_id=122');
      END IF;
      IF l_items_failure_727 > 0 THEN
        fnd_file.put_line(fnd_file.output,
                          l_items_failure_727 ||
                          ' items are failured in organization ''CSS'' 727');
        fnd_file.put_line(fnd_file.log,
                          l_items_failure_727 ||
                          ' items are failured in organization ''CSS'' 727');
      END IF;
      IF l_items_failure_742 > 0 THEN
        fnd_file.put_line(fnd_file.output,
                          l_items_failure_742 ||
                          ' items are failured in organization_id=742');
        fnd_file.put_line(fnd_file.log,
                          l_items_failure_742 ||
                          ' items are failured in organization_id=742');
      END IF;
      IF l_items_failure_725 > 0 THEN
        fnd_file.put_line(fnd_file.output,
                          l_items_failure_725 ||
                          ' items are failured in organization ''ATH'' 725');
        fnd_file.put_line(fnd_file.log,
                          l_items_failure_725 ||
                          ' items are failured in organization ''ATH'' 725');
      END IF;
    END IF;
  
    RETURN 'S';
  
  EXCEPTION
    WHEN OTHERS THEN
      l_error_msg := 'Unexpected ERROR in XXCONV_CATEGORIES_PKG.create_ssys_items function: ' ||
                     v_step || ' ' || SQLERRM;
      fnd_file.put_line(fnd_file.output, '=======' || l_error_msg);
      fnd_file.put_line(fnd_file.log, '=======' || l_error_msg);
      RETURN l_error_msg;
  END create_ssys_items;
  -------------------------------------------------------------------------------------------------
  FUNCTION create_category_assignment RETURN VARCHAR2 IS
  
    CURSOR csr_categories_assignments IS
      SELECT a.line_id,
             'XXINV_MAIN_ITEM_CATEGORY' structure_name,
             rtrim(ltrim(a.item_code, ' '), ' ') item_code,
             rtrim(ltrim(a.item_category, ' '), ' ') category,
             mp.organization_id,
             mp.organization_code
        FROM xxinv_ssys_items a, mtl_parameters mp
       WHERE a.status = 'N'
         AND mp.organization_id = 91; --OMA -- Master organization
  
    cur_category_assignment csr_categories_assignments%ROWTYPE;
    v_error                 VARCHAR2(100);
    v_step                  VARCHAR2(30);
    l_error_msg             VARCHAR2(500);
    v_categ_valid_exists    CHAR(1);
    --v_user_id               NUMBER;
    v_category_set_id   NUMBER;
    v_structure_id      NUMBER;
    v_id_flex_num       NUMBER;
    l_inventory_item_id NUMBER;
    l_category_id       NUMBER;
    l_def_category_id   NUMBER;
    l_def_category      VARCHAR2(100);
    l_return_status     VARCHAR2(1);
    l_error_code        NUMBER;
    l_msg_count         NUMBER;
    l_msg_data          VARCHAR2(2000);
  
    l_category_assignments_success NUMBER := 0;
    l_category_assignments_failure NUMBER := 0;
    invalid_category EXCEPTION;
  BEGIN
  
    v_step := 'Step 0';
    fnd_file.put_line(fnd_file.output, ''); --empty line
    fnd_file.put_line(fnd_file.output, ''); --empty line
    fnd_file.put_line(fnd_file.output, ''); --empty line
    fnd_file.put_line(fnd_file.output,
                      '================= Item Categories ========================');
    fnd_file.put_line(fnd_file.log, ''); --empty line
    fnd_file.put_line(fnd_file.log, ''); --empty line
    fnd_file.put_line(fnd_file.log, ''); --empty line
    fnd_file.put_line(fnd_file.log,
                      '================= Item Categories ========================');
  
    /*BEGIN
       SELECT user_id
         INTO v_user_id
         FROM fnd_user
        WHERE user_name = 'CONVERSION';
    EXCEPTION
       WHEN no_data_found THEN
          errbuf  := 'Invalid User';
          retcode := 2;
          RETURN;
    END;
    
    fnd_global.apps_initialize(user_id      => v_user_id,
                               resp_id      => 50606,
                               resp_appl_id => 660);*/
    v_step := 'Step 5';
    ----------  
    -- get structure and value set details
    SELECT mcs.category_set_id,
           mcs.validate_flag,
           mcs.structure_id,
           --  fifs.id_flex_structure_name structure_name,
           fifs.id_flex_num
      INTO v_category_set_id,
           v_categ_valid_exists,
           v_structure_id,
           v_id_flex_num
      FROM mtl_category_sets_tl      t,
           mtl_category_sets_b       mcs,
           fnd_id_flex_structures_vl fifs,
           mfg_lookups               ml
     WHERE mcs.category_set_id = t.category_set_id
       AND t.language = userenv('LANG')
       AND mcs.structure_id = fifs.id_flex_num
       AND fifs.application_id = 401
       AND fifs.id_flex_code = 'MCAT'
       AND mcs.control_level = ml.lookup_code
       AND ml.lookup_type = 'ITEM_CONTROL_LEVEL_GUI'
       AND fifs.id_flex_structure_code = 'XXINV_MAIN_ITEM_CATEGORY'
       AND t.category_set_name = 'Main Category Set';
  
    FOR cur_category_assignment IN csr_categories_assignments LOOP
      -------
      BEGIN
        v_error         := NULL;
        l_return_status := fnd_api.g_ret_sts_success;
        ----------
        v_step := 'Step 10';
        BEGIN
          SELECT inventory_item_id
            INTO l_inventory_item_id
            FROM mtl_system_items_b
           WHERE segment1 = cur_category_assignment.item_code
             AND organization_id = cur_category_assignment.organization_id;
        EXCEPTION
          WHEN no_data_found THEN
            UPDATE xxinv_ssys_items a
               SET a.status           = 'E',
                   a.error_message    = 'Item ' ||
                                        cur_category_assignment.item_code ||
                                        ' does not exist in organization=' ||
                                        cur_category_assignment.organization_code,
                   a.last_update_date = SYSDATE,
                   a.last_updated_by  = fnd_global.user_id
             WHERE a.line_id = cur_category_assignment.line_id
               AND a.status = 'N';
            RAISE invalid_category;
        END;
        ----------
        v_step := 'Step 15';
        BEGIN
        
          SELECT category_id
            INTO l_category_id
            FROM mtl_categories_kfv
           WHERE concatenated_segments = cur_category_assignment.category
             AND structure_id = v_structure_id;
        EXCEPTION
          WHEN no_data_found THEN
            UPDATE xxinv_ssys_items a
               SET a.status           = 'E',
                   a.error_message    = 'Item ' ||
                                        cur_category_assignment.category ||
                                        ' does not exist',
                   a.last_update_date = SYSDATE,
                   a.last_updated_by  = fnd_global.user_id
             WHERE a.line_id = cur_category_assignment.line_id
               AND a.status = 'N';
            RAISE invalid_category;
        END;
        ---------
        v_step := 'Step 20';
        inv_item_category_pub.create_valid_category(p_api_version        => '1.0',
                                                    p_init_msg_list      => fnd_api.g_true,
                                                    p_commit             => fnd_api.g_true,
                                                    p_category_id        => l_category_id,
                                                    p_category_set_id    => v_category_set_id,
                                                    p_parent_category_id => NULL,
                                                    x_return_status      => l_return_status,
                                                    x_errorcode          => l_error_code,
                                                    x_msg_count          => l_msg_count,
                                                    x_msg_data           => l_msg_data);
      
        ---------
        BEGIN
        
          SELECT mic.category_id, cat.category_concat_segs
            INTO l_def_category_id, l_def_category
            FROM mtl_item_categories mic, mtl_categories_v cat
           WHERE mic.inventory_item_id = l_inventory_item_id
             AND mic.organization_id =
                 cur_category_assignment.organization_id
             AND mic.category_set_id = v_category_set_id
             AND mic.category_id = cat.category_id;
        
          inv_item_category_pub.update_category_assignment(p_api_version       => 1.0,
                                                           p_init_msg_list     => fnd_api.g_true,
                                                           p_commit            => fnd_api.g_false,
                                                           p_category_id       => l_category_id,
                                                           p_old_category_id   => l_def_category_id,
                                                           p_category_set_id   => v_category_set_id,
                                                           p_inventory_item_id => l_inventory_item_id,
                                                           p_organization_id   => cur_category_assignment.organization_id,
                                                           x_return_status     => l_return_status,
                                                           x_errorcode         => l_error_code,
                                                           x_msg_count         => l_msg_count,
                                                           x_msg_data          => l_msg_data);
        
          IF l_return_status != fnd_api.g_ret_sts_success THEN
            l_category_assignments_failure := l_category_assignments_failure + 1;
          
            UPDATE xxinv_ssys_items a
               SET a.status           = 'E',
                   a.error_message    = 'Update Category Assignment API Error ',
                   a.last_update_date = SYSDATE,
                   a.last_updated_by  = fnd_global.user_id
             WHERE a.line_id = cur_category_assignment.line_id
               AND a.status = 'N';
            RAISE invalid_category;
          ELSE
            l_category_assignments_success := l_category_assignments_success + 1;
          
            /*UPDATE XXINV_SSYS_ITEMS  a
            SET a.message = ltrim(a.message||chr(10)||'Category Assignment updated '||
                                              ' (Old Category='||l_def_category||
                                              ', New Category='||cur_category_assignment.category||
                                              ', Category Set=Main Category Set'||
                                              ', Structure=XXINV_MAIN_ITEM_CATEGORY)',chr(10)),
                a.last_update_date=sysdate,
                a.last_updated_by=fnd_global.user_id
            WHERE a.line_id =cur_category_assignment.line_id
            AND a.status = 'N';*/
          END IF;
        
        EXCEPTION
          WHEN no_data_found THEN
            ------ -----                     
            inv_item_category_pub.create_category_assignment(p_api_version       => '1.0',
                                                             p_init_msg_list     => fnd_api.g_true,
                                                             p_commit            => fnd_api.g_true,
                                                             p_category_id       => l_category_id,
                                                             p_category_set_id   => v_category_set_id,
                                                             p_inventory_item_id => l_inventory_item_id,
                                                             p_organization_id   => cur_category_assignment.organization_id,
                                                             x_return_status     => l_return_status,
                                                             x_errorcode         => l_error_code,
                                                             x_msg_count         => l_msg_count,
                                                             x_msg_data          => l_msg_data);
            IF l_return_status != fnd_api.g_ret_sts_success THEN
              UPDATE xxinv_ssys_items a
                 SET a.status           = 'E',
                     a.error_message    = 'Create Category Assignment API Error ',
                     a.last_update_date = SYSDATE,
                     a.last_updated_by  = fnd_global.user_id
               WHERE a.line_id = cur_category_assignment.line_id
                 AND a.status = 'N';
              RAISE invalid_category;
            ELSE
              NULL;
              /*UPDATE XXINV_SSYS_ITEMS  a
              SET a.message = ltrim(a.message||chr(10)||'Category Assignment created '||
                                                ' (Category='||cur_category_assignment.category||
                                                ', Category Set=Main Category Set'||
                                                ', Structure=XXINV_MAIN_ITEM_CATEGORY)',chr(10)),
                  a.last_update_date=sysdate,
                  a.last_updated_by=fnd_global.user_id
              WHERE a.line_id =cur_category_assignment.line_id
              AND a.status = 'N';*/
            END IF;
        END;
      
        COMMIT;
      
      EXCEPTION
        WHEN invalid_category THEN
          NULL;
      END;
      -----------
    END LOOP;
  
    COMMIT;
  
    IF l_category_assignments_success > 0 THEN
      fnd_file.put_line(fnd_file.output,
                        l_category_assignments_success ||
                        ' items categories created(updated)');
      fnd_file.put_line(fnd_file.log,
                        l_category_assignments_success ||
                        ' items categories created(updated)');
    END IF;
    IF l_category_assignments_failure > 0 THEN
      fnd_file.put_line(fnd_file.output,
                        l_category_assignments_failure ||
                        ' items categories creation failure');
      fnd_file.put_line(fnd_file.log,
                        l_category_assignments_failure ||
                        ' items categories creation failure');
    END IF;
  
    RETURN 'S';
  
  EXCEPTION
    WHEN OTHERS THEN
      l_error_msg := 'Unexpected ERROR in XXCONV_CATEGORIES_PKG.create_category_assignment function: ' ||
                     v_step || ' ' || SQLERRM;
      fnd_file.put_line(fnd_file.output, '=======' || l_error_msg);
      fnd_file.put_line(fnd_file.log, '=======' || l_error_msg);
      RETURN l_error_msg;
  END create_category_assignment;
  -------------------------------------------------------------------------------------------------
  PROCEDURE create_new_ssys_items(errbuf  OUT VARCHAR2,
                                  retcode OUT VARCHAR2) IS
  
    ---v_user_id fnd_user.user_id%TYPE;
    v_step   VARCHAR2(30);
    v_result VARCHAR2(1000);
  
    l_retcode VARCHAR2(300);
    l_errbuf  VARCHAR2(300);
  
  BEGIN
  
    v_step               := 'Step 0';
    retcode              := '0';
    errbuf               := NULL;
    g_request_start_date := SYSDATE;
  
    /*-- Initialize User For Updates
    BEGIN
       SELECT user_id
         INTO v_user_id
         FROM fnd_user
        WHERE user_name = 'CONVERSION';
    EXCEPTION
       WHEN no_data_found THEN
          errbuf  := 'Invalid User CONVERSION';
          retcode := 2;
    END;
       
    fnd_global.apps_initialize(user_id      => v_user_id,
                               resp_id      => 20420,  ---System Administrator
                               resp_appl_id => 1);*/
  
    ----Data validations-----------------------------------
    v_step   := 'Step 5';
    v_result := new_ssys_items_data_validation;
    IF v_result <> 'S' THEN
      fnd_file.put_line(fnd_file.output,
                        '=======Unexpected ERROR in XXINV_SSYS_PKG.new_ssys_items_data_validation function: ' ||
                        v_step || ' ---' || v_result);
      retcode := '2';
      errbuf  := 'Unexpected Error in XXINV_SSYS_PKG.new_ssys_items_data_validation function';
    END IF;
  
    ----Check new categories (create new segments and new categories)-------
    v_step   := 'Step 10';
    v_result := check_new_ssys_categories;
    IF v_result <> 'S' THEN
      fnd_file.put_line(fnd_file.output,
                        '=======Unexpected ERROR in XXINV_SSYS_PKG.check_new_ssys_categories function: ' ||
                        v_step || ' ---' || v_result);
      retcode := '2';
      errbuf  := 'Unexpected Error in XXINV_SSYS_PKG.check_new_ssys_categories function';
    END IF;
  
    ----Create Category-Organization Assignments for new categories-------
    v_step   := 'Step 20';
    v_result := load_fdm_category_assignments;
    IF v_result <> 'S' THEN
      fnd_file.put_line(fnd_file.output,
                        '=======Unexpected ERROR in XXINV_SSYS_PKG.load_fdm_category_assignments function: ' ||
                        v_step || ' ---' || v_result);
      retcode := '2';
      errbuf  := 'Unexpected Error in XXINV_SSYS_PKG.load_fdm_category_assignments function';
    END IF;
  
    ----Create new items --------
    v_step   := 'Step 30';
    v_result := create_ssys_items;
    IF v_result <> 'S' THEN
      fnd_file.put_line(fnd_file.output,
                        '=======Unexpected ERROR in XXINV_SSYS_PKG.create_ssys_items function: ' ||
                        v_step || ' ---' || v_result);
      retcode := '2';
      errbuf  := 'Unexpected Error in XXINV_SSYS_PKG.create_ssys_items function';
    END IF;
  
    ----Create Category Assignment ----------------------------------
    v_step   := 'Step 40';
    v_result := create_category_assignment;
    IF v_result <> 'S' THEN
      fnd_file.put_line(fnd_file.output,
                        '=======Unexpected ERROR in XXINV_SSYS_PKG.create_category_assignment function: ' ||
                        v_step || ' ---' || v_result);
      retcode := '2';
      errbuf  := 'Unexpected Error in XXINV_SSYS_PKG.create_category_assignment function';
    END IF;
  
    UPDATE xxinv_ssys_items a
       SET a.status           = 'S',
           a.last_update_date = SYSDATE,
           a.last_updated_by  = fnd_global.user_id
     WHERE a.status = 'N';
    COMMIT;
  
    --- send notification log----  
    xxobjt_wf_mail.send_mail_body_proc(p_to_role     => fnd_profile.value('XX_ORACLE_OPERATION_ADMIN_USER'),
                                       p_cc_mail     => xxobjt_general_utils_pkg.get_dist_mail_list(NULL,
                                                                                                    'SSYS_ITEMS'),
                                       p_bcc_mail    => NULL,
                                       p_subject     => 'Create New SSYS Items : Alert Log',
                                       p_body_proc   => 'xxinv_ssys_notifications_pkg.create_items_notification/' ||
                                                        to_char(g_request_start_date,
                                                                'ddmmyyyy hh24:mi'),
                                       p_err_code    => l_retcode,
                                       p_err_message => l_errbuf);
    ---
  
  EXCEPTION
    WHEN OTHERS THEN
      -- send err alert
      xxobjt_wf_mail.send_mail_text(p_to_role     => fnd_profile.value('XX_ORACLE_OPERATION_ADMIN_USER'),
                                    p_subject     => 'Create New SSYS Items : Failure',
                                    p_body_text   => 'xxinv_ssys_pkg.create_new_ssys_items' ||
                                                     chr(10) ||
                                                     'Unexpected Error:' ||
                                                     SQLERRM,
                                    p_err_code    => l_retcode,
                                    p_err_message => l_errbuf);
      --
      fnd_file.put_line(fnd_file.output,
                        '=======Unexpected ERROR in XXINV_SSYS_PKG.create_new_ssys_items proc: ' ||
                        v_step || ' ---' || SQLERRM);
    
      retcode := '2';
      errbuf  := 'Unexpected ERROR in XXINV_SSYS_PKG.create_new_ssys_items proc: ' ||
                 v_step || ' ---' || SQLERRM;
  END create_new_ssys_items;
  --------------------------------------------------------------------------------------
  PROCEDURE update_ssys_items_min_max(errbuf  OUT VARCHAR2,
                                      retcode OUT VARCHAR2) IS
  
    ---v_user_id fnd_user.user_id%TYPE;
    v_step                   VARCHAR2(30);
    v_numeric_dummy          NUMBER;
    l_records_updated        NUMBER;
    v_min_minmax_quantity    NUMBER;
    v_max_minmax_quantity    NUMBER;
    v_minimum_order_quantity NUMBER;
    v_maximum_order_quantity NUMBER;
    v_fixed_lot_multiplier   NUMBER;
    v_planner_code           VARCHAR2(30);
    v_inventory_item_id      NUMBER;
  
    t_item_rec     inv_item_grp.item_rec_type;
    t_item_rec_out inv_item_grp.item_rec_type;
    --t_rev_rec      inv_item_grp.item_revision_rec_type;
    --l_error_tbl    error_handler.error_tbl_type;
    l_error_tbl     inv_item_grp.error_tbl_type;
    l_return_status VARCHAR2(1);
    l_err_msg       VARCHAR2(5000);
  
    l_retcode VARCHAR2(300);
    l_errbuf  VARCHAR2(300);
  
    CURSOR get_min_max_data IS
      SELECT a.line_id,
             rtrim(a.item_code) item_code,
             rtrim(a.organization_code) organization_code,
             mp.organization_id,
             rtrim(a.planner_first_name) planner_first_name,
             rtrim(a.planner_last_name) planner_last_name,
             a.min_minmax_quantity,
             a.max_minmax_quantity,
             a.minimum_order_quantity,
             a.maximum_order_quantity,
             a.fixed_lot_multiplier
        FROM xxinv_ssys_min_max a, mtl_parameters mp
       WHERE a.status = 'N'
         AND nvl(a.organization_code, 'ZZZ') = mp.organization_code(+);
  
  BEGIN
  
    v_step               := 'Step 0';
    retcode              := '0';
    errbuf               := NULL;
    g_request_start_date := SYSDATE;
  
    fnd_file.put_line(fnd_file.output, ''); --empty line
    fnd_file.put_line(fnd_file.output, ''); --empty line
    fnd_file.put_line(fnd_file.output, ''); --empty line
    fnd_file.put_line(fnd_file.output,
                      '================= Update SSYS Items Min Max ===================');
    fnd_file.put_line(fnd_file.log, ''); --empty line
    fnd_file.put_line(fnd_file.log, ''); --empty line
    fnd_file.put_line(fnd_file.log, ''); --empty line
    fnd_file.put_line(fnd_file.log,
                      '================= Update SSYS Items Min Max ===================');
  
    /*-- Initialize User For Updates
    BEGIN
       SELECT user_id
         INTO v_user_id
         FROM fnd_user
        WHERE user_name = 'CONVERSION';
    EXCEPTION
       WHEN no_data_found THEN
          errbuf  := 'Invalid User CONVERSION';
          retcode := 2;
    END;
       
    fnd_global.apps_initialize(user_id      => v_user_id,
                               resp_id      => 20420,  ---System Administrator
                               resp_appl_id => 1);*/
  
    ----Data validations-----------------------------------
    v_step := 'Step 5';
    UPDATE xxinv_ssys_min_max a SET a.status = 'N' WHERE a.status IS NULL;
  
    v_step := 'Step 7';
    UPDATE xxinv_ssys_min_max a
       SET a.error_message = NULL, a.message = NULL
     WHERE a.status = 'N';
  
    v_step := 'Step 10';
    SELECT COUNT(1)
      INTO v_numeric_dummy
      FROM xxinv_ssys_min_max a
     WHERE nvl(a.status, 'N') = 'N';
  
    IF v_numeric_dummy = 0 THEN
      fnd_file.put_line(fnd_file.output,
                        'No new records (with Status=''N'' or Status is empty)');
    END IF;
  
    v_step := 'Step 15'; ----
    UPDATE xxinv_ssys_min_max a
       SET a.status           = 'E',
           a.error_message    = 'Missing Item Code',
           a.last_update_date = SYSDATE,
           a.last_updated_by  = fnd_global.user_id
     WHERE a.status = 'N'
       AND ltrim(rtrim(a.item_code), '-') IS NULL;
  
    l_records_updated := SQL%ROWCOUNT;
    IF l_records_updated > 0 THEN
      fnd_file.put_line(fnd_file.output,
                        l_records_updated ||
                        ' records with Missing Item_Code');
    END IF;
  
    v_step := 'Step 20'; ----
    UPDATE xxinv_ssys_min_max a
       SET a.status           = 'E',
           a.error_message    = 'Missing Organization Code',
           a.last_update_date = SYSDATE,
           a.last_updated_by  = fnd_global.user_id
     WHERE a.status = 'N'
       AND rtrim(a.organization_code) IS NULL;
  
    l_records_updated := SQL%ROWCOUNT;
    IF l_records_updated > 0 THEN
      fnd_file.put_line(fnd_file.output,
                        l_records_updated ||
                        ' records with Missing Organization_Code');
    END IF;
  
    v_step := 'Step 25'; ----
    UPDATE xxinv_ssys_min_max a
       SET a.status           = 'E',
           a.error_message    = 'Invalid Organization',
           a.last_update_date = SYSDATE,
           a.last_updated_by  = fnd_global.user_id
     WHERE a.status = 'N'
       AND rtrim(a.organization_code) IS NOT NULL
       AND NOT EXISTS
     (SELECT 1
              FROM mtl_parameters mp
             WHERE mp.organization_code = rtrim(a.organization_code));
  
    l_records_updated := SQL%ROWCOUNT;
    IF l_records_updated > 0 THEN
      fnd_file.put_line(fnd_file.output,
                        l_records_updated ||
                        ' records with Invalid Organization');
    END IF;
  
    v_step := 'Step 30'; ----
    ----Check item_code value---- may be characters like . or , or < or > or ; or : or ' or " or + .. inside
    UPDATE xxinv_ssys_min_max a
       SET a.status           = 'E',
           a.error_message    = 'There is forbidden character in your Item Code ',
           a.last_update_date = SYSDATE,
           a.last_updated_by  = fnd_global.user_id
     WHERE a.status = 'N'
       AND (instr(ltrim(rtrim(a.item_code)), ' ', 1) > 0 OR
           instr(a.item_code, '.', 1) > 0 OR
           instr(a.item_code, ',', 1) > 0 OR
           instr(a.item_code, '<', 1) > 0 OR
           instr(a.item_code, '>', 1) > 0 OR
           instr(a.item_code, '=', 1) > 0 OR
           instr(a.item_code, '_', 1) > 0 OR
           instr(a.item_code, ';', 1) > 0 OR
           instr(a.item_code, ':', 1) > 0 OR
           instr(a.item_code, '+', 1) > 0 OR
           instr(a.item_code, ')', 1) > 0 OR
           instr(a.item_code, '(', 1) > 0 OR
           instr(a.item_code, '*', 1) > 0 OR
           instr(a.item_code, '&', 1) > 0 OR
           instr(a.item_code, '^', 1) > 0 OR
           instr(a.item_code, '%', 1) > 0 OR
           instr(a.item_code, '$', 1) > 0 OR
           instr(a.item_code, '#', 1) > 0 OR
           instr(a.item_code, '@', 1) > 0 OR
           instr(a.item_code, '!', 1) > 0 OR
           instr(a.item_code, '?', 1) > 0 OR
           instr(a.item_code, '/', 1) > 0 OR
           instr(a.item_code, '\', 1) > 0 OR
           instr(a.item_code, '''', 1) > 0 OR
           instr(a.item_code, '"', 1) > 0 OR
           instr(a.item_code, '|', 1) > 0 OR
           instr(a.item_code, '{', 1) > 0 OR
           instr(a.item_code, '}', 1) > 0 OR
           instr(a.item_code, '[', 1) > 0 OR
           instr(a.item_code, ']', 1) > 0);
  
    l_records_updated := SQL%ROWCOUNT;
    IF l_records_updated > 0 THEN
      fnd_file.put_line(fnd_file.output,
                        l_records_updated ||
                        ' records with forbidden character in Item_Code');
    END IF;
  
    v_step := 'Step 35'; -----
    UPDATE xxinv_ssys_min_max a
       SET a.status           = 'E',
           a.error_message    = 'This Item does not exist in Organization',
           a.last_update_date = SYSDATE,
           a.last_updated_by  = fnd_global.user_id
     WHERE a.status = 'N'
       AND NOT EXISTS
     (SELECT 1
              FROM mtl_system_items_b msi, mtl_parameters mp
             WHERE msi.segment1 = rtrim(a.item_code)
               AND msi.organization_id = mp.organization_id
               AND mp.organization_code = rtrim(a.organization_code)
            
            );
  
    l_records_updated := SQL%ROWCOUNT;
    IF l_records_updated > 0 THEN
      fnd_file.put_line(fnd_file.output,
                        l_records_updated ||
                        ' records with ...This Item does not exist in Organization');
    END IF;
  
    v_step := 'Step 40'; -----
    UPDATE xxinv_ssys_min_max a
       SET a.status           = 'E',
           a.error_message    = 'There are more than 1 record for the same Item_Code and Organization_Code',
           a.last_update_date = SYSDATE,
           a.last_updated_by  = fnd_global.user_id
     WHERE a.status = 'N'
       AND EXISTS
     (SELECT COUNT(1)
              FROM xxinv_ssys_min_max a2
             WHERE a2.batch_id = a.batch_id --parameter
               AND a2.status = 'N'
               AND rtrim(a2.item_code) = rtrim(a.item_code)
               AND rtrim(a2.organization_code) = rtrim(a.organization_code)
             HAVING COUNT(1) >= 2);
  
    l_records_updated := SQL%ROWCOUNT;
    IF l_records_updated > 0 THEN
      fnd_file.put_line(fnd_file.output,
                        'There are more than 1 record for the same Item_Code and Organization_Code');
    END IF;
  
    COMMIT;
  
    FOR min_max_data_rec IN get_min_max_data LOOP
      ----Data validations-----------------------------------
      v_min_minmax_quantity    := min_max_data_rec.min_minmax_quantity;
      v_max_minmax_quantity    := min_max_data_rec.max_minmax_quantity;
      v_minimum_order_quantity := min_max_data_rec.minimum_order_quantity;
      v_maximum_order_quantity := min_max_data_rec.maximum_order_quantity;
      v_fixed_lot_multiplier   := min_max_data_rec.fixed_lot_multiplier;
    
      v_step := 'Step 50';
      /* IF v_min_minmax_quantity IS NOT NULL AND v_min_minmax_quantity <= 0 THEN
        UPDATE xxinv_ssys_min_max a
           SET a.message          = ltrim(a.message || chr(10) ||
                                          'Min Quantity will not be updated. Reason: Value should be >0. ',
                                          chr(10)),
               a.last_update_date = SYSDATE,
               a.last_updated_by  = fnd_global.user_id
         WHERE a.line_id = min_max_data_rec.line_id;
      
        v_min_minmax_quantity := NULL;
      ELSIF v_max_minmax_quantity IS NOT NULL AND
            v_max_minmax_quantity <= 0 THEN
        UPDATE xxinv_ssys_min_max a
           SET a.message          = ltrim(a.message || chr(10) ||
                                          'Max Quantity will not be updated. Reason: Value should be >0. ',
                                          chr(10)),
               a.last_update_date = SYSDATE,
               a.last_updated_by  = fnd_global.user_id
         WHERE a.line_id = min_max_data_rec.line_id;
      
        v_max_minmax_quantity := NULL;*/
      IF v_min_minmax_quantity IS NOT NULL AND
         v_max_minmax_quantity IS NOT NULL AND
         v_min_minmax_quantity > v_max_minmax_quantity THEN
        UPDATE xxinv_ssys_min_max a
           SET a.message          = ltrim(a.message || chr(10) ||
                                          'Min and Max Quantities will not be updated. Reason: Min Quantity should be <= Max Quantity. ',
                                          chr(10)),
               a.last_update_date = SYSDATE,
               a.last_updated_by  = fnd_global.user_id
         WHERE a.line_id = min_max_data_rec.line_id;
      
        v_min_minmax_quantity := NULL;
        v_max_minmax_quantity := NULL;
      END IF;
    
      v_step := 'Step 60';
      /* IF v_minimum_order_quantity IS NOT NULL AND
         v_minimum_order_quantity <= 0 THEN
        UPDATE xxinv_ssys_min_max a
           SET a.message          = ltrim(a.message || chr(10) ||
                                          'Min Order Quantity will not be updated. Reason: Value should be >0. ',
                                          chr(10)),
               a.last_update_date = SYSDATE,
               a.last_updated_by  = fnd_global.user_id
         WHERE a.line_id = min_max_data_rec.line_id;
      
        v_minimum_order_quantity := NULL;
      ELSIF v_maximum_order_quantity IS NOT NULL AND
            v_maximum_order_quantity <= 0 THEN
        UPDATE xxinv_ssys_min_max a
           SET a.message          = ltrim(a.message || chr(10) ||
                                          'Max Order Quantity will not be updated. Reason: Value should be >0. ',
                                          chr(10)),
               a.last_update_date = SYSDATE,
               a.last_updated_by  = fnd_global.user_id
         WHERE a.line_id = min_max_data_rec.line_id;
      
        v_maximum_order_quantity := NULL;*/
      -- ELS
      IF v_minimum_order_quantity IS NOT NULL AND
         v_maximum_order_quantity IS NOT NULL AND
         v_minimum_order_quantity > v_maximum_order_quantity THEN
        UPDATE xxinv_ssys_min_max a
           SET a.message          = ltrim(a.message || chr(10) ||
                                          'Min and Max Order Quantities will not be updated. Reason: Min Order Quantity should be <= Max Order Quantity. ',
                                          chr(10)),
               a.last_update_date = SYSDATE,
               a.last_updated_by  = fnd_global.user_id
         WHERE a.line_id = min_max_data_rec.line_id;
      
        v_minimum_order_quantity := NULL;
        v_maximum_order_quantity := NULL;
      ELSIF v_maximum_order_quantity IS NOT NULL AND
            v_min_minmax_quantity IS NOT NULL AND
            v_max_minmax_quantity IS NOT NULL AND
            v_maximum_order_quantity <
            (v_max_minmax_quantity - v_min_minmax_quantity) THEN
      
        UPDATE xxinv_ssys_min_max a
           SET a.message          = ltrim(a.message || chr(10) ||
                                          'Max Order Quantity will not be updated. Reason: Max Order Quantity should be >= (Max Quantity-Min Quantity). ',
                                          chr(10)),
               a.last_update_date = SYSDATE,
               a.last_updated_by  = fnd_global.user_id
         WHERE a.line_id = min_max_data_rec.line_id;
        v_maximum_order_quantity := NULL;
      END IF;
    
      v_step := 'Step 70';
      IF v_fixed_lot_multiplier IS NOT NULL AND v_fixed_lot_multiplier < 0 THEN
      
        UPDATE xxinv_ssys_min_max a
           SET a.message          = ltrim(a.message || chr(10) ||
                                          'Fixed Lot Multiplier will not be updated. Reason: Fixed Lot Multiplier should be >=0. ',
                                          chr(10)),
               a.last_update_date = SYSDATE,
               a.last_updated_by  = fnd_global.user_id
         WHERE a.line_id = min_max_data_rec.line_id;
      
        v_fixed_lot_multiplier := NULL;
      END IF;
    
      v_step := 'Step 80';
      IF min_max_data_rec.planner_first_name IS NULL AND
         min_max_data_rec.planner_last_name IS NULL THEN
        UPDATE xxinv_ssys_min_max a
           SET a.message          = ltrim(a.message || chr(10) ||
                                          'Planner will not be updated. Reason: Missing Planner. ',
                                          chr(10)),
               a.last_update_date = SYSDATE,
               a.last_updated_by  = fnd_global.user_id
         WHERE a.line_id = min_max_data_rec.line_id;
      
        v_planner_code := NULL;
      ELSE
        -------- search planner-epmloyee -------
        BEGIN
          v_step := 'Step 90';
          SELECT p.planner_code
            INTO v_planner_code
            FROM mtl_planners p, per_all_people_f papf
           WHERE p.employee_id = papf.person_id
             AND lower(papf.first_name) =
                 lower(nvl(min_max_data_rec.planner_first_name, 'XYZ'))
             AND lower(papf.last_name) =
                 lower(nvl(min_max_data_rec.planner_last_name, 'XYZ'))
             AND p.organization_id = min_max_data_rec.organization_id
             AND rownum = 1;
        
        EXCEPTION
          WHEN no_data_found THEN
            v_planner_code := NULL;
        END;
        ---------
        IF v_planner_code IS NULL THEN
          ---planner-epmloyee is not found
          BEGIN
            -- search planner that NON epmloyee ------
            v_step := 'Step 100';
            SELECT p.planner_code
              INTO v_planner_code
              FROM mtl_planners p
             WHERE REPLACE(lower(p.planner_code), ' ', '') =
                   REPLACE(lower(min_max_data_rec.planner_first_name) ||
                           lower(min_max_data_rec.planner_last_name),
                           ' ',
                           '')
               AND p.organization_id = min_max_data_rec.organization_id
               AND rownum = 1;
          EXCEPTION
            WHEN no_data_found THEN
              v_step         := 'Step 110';
              v_planner_code := NULL;
              UPDATE xxinv_ssys_min_max a
                 SET a.message          = ltrim(a.message || chr(10) ||
                                                'Planner will not be updated. Reason: Invalid Planner for this Organization. ',
                                                chr(10)),
                     a.last_update_date = SYSDATE,
                     a.last_updated_by  = fnd_global.user_id
               WHERE a.line_id = min_max_data_rec.line_id;
            
          END;
        END IF;
        ------------ 
      END IF;
    
      COMMIT;
    
      -----------
      BEGIN
        v_step := 'Step 120';
        SELECT msi.inventory_item_id
          INTO v_inventory_item_id
          FROM mtl_system_items_b msi
         WHERE msi.segment1 = min_max_data_rec.item_code
           AND msi.organization_id = min_max_data_rec.organization_id;
      
      EXCEPTION
        WHEN no_data_found THEN
          v_inventory_item_id := NULL;
      END;
    
      v_step := 'Step 200';
      ----API update item
      ---t_item_rec.item_number                := v_item_segment1;
      ---t_item_rec.segment1                   := v_item_segment1;
      t_item_rec.inventory_item_id := v_inventory_item_id;
      -----t_item_rec.description                := v_item_description;
      t_item_rec.organization_id := min_max_data_rec.organization_id;
      ----t_item_rec.long_description           := nvl(cur_item.item_detail,fnd_api.g_miss_char);
      ----t_item_rec.primary_uom_code           := l_uom;
      ----t_item_rec.primary_unit_of_measure    := l_unit_of_measure;
      ----t_item_rec.inventory_item_status_code := l_inventory_status_code;
      ----t_item_rec.item_catalog_group_id      := nvl(v_cat_group_id,fnd_api.g_miss_num);
      ----t_item_rec.shelf_life_code            := nvl(l_shelf_life_code,fnd_api.g_miss_num);
      ----t_item_rec.shelf_life_days            := nvl(cur_item.shelf_life_days,fnd_api.g_miss_num);
      ------------ASK---ERROR INV_IOI_MASTER_CHILD_1A ------ first determine which of the effected attributes (buyer_id) are controlled at the master level for your company.
      --------------------t_item_rec.buyer_id                   := nvl(v_buyer_id      ,fnd_api.g_miss_num);
      t_item_rec.planner_code := nvl(v_planner_code, fnd_api.g_miss_char);
    
      t_item_rec.min_minmax_quantity := nvl(v_min_minmax_quantity,
                                            fnd_api.g_miss_num);
    
      t_item_rec.max_minmax_quantity := nvl(v_max_minmax_quantity,
                                            fnd_api.g_miss_num);
    
      t_item_rec.minimum_order_quantity := nvl(v_minimum_order_quantity,
                                               fnd_api.g_miss_num);
      t_item_rec.maximum_order_quantity := nvl(v_maximum_order_quantity,
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
    
      v_step := 'Step 220';
      IF l_return_status = 'S' THEN
        UPDATE xxinv_ssys_min_max a
           SET a.status           = 'S',
               a.last_update_date = SYSDATE,
               a.last_updated_by  = fnd_global.user_id
         WHERE a.line_id = min_max_data_rec.line_id;
      
        COMMIT;
      ELSE
        l_err_msg := NULL;
        FOR i IN 1 .. l_error_tbl.count LOOP
          l_err_msg := l_err_msg || l_error_tbl(i).message_text || chr(10);
        
        END LOOP;
        UPDATE xxinv_ssys_min_max a
           SET a.status           = 'E',
               a.error_message    = substr('API Error - ' || l_err_msg,
                                           1,
                                           3000),
               a.last_update_date = SYSDATE,
               a.last_updated_by  = fnd_global.user_id
         WHERE a.line_id = min_max_data_rec.line_id;
        fnd_file.put_line(fnd_file.output,
                          'API Update Item Error  (Item=' ||
                          min_max_data_rec.item_code || ' ,Organization=' ||
                          min_max_data_rec.organization_code || ' ) ' ||
                          l_err_msg);
      
      END IF;
    
    END LOOP;
  
    COMMIT;
  
    --- send notification log----  
    xxobjt_wf_mail.send_mail_body_proc(p_to_role     => fnd_profile.value('XX_ORACLE_OPERATION_ADMIN_USER'),
                                       p_cc_mail     => xxobjt_general_utils_pkg.get_dist_mail_list(NULL,
                                                                                                    'SSYS_MIN_MAX'),
                                       p_bcc_mail    => NULL,
                                       p_subject     => 'Update SSYS Items Min-Max : Alert Log',
                                       p_body_proc   => 'xxinv_ssys_notifications_pkg.upd_items_min_max_notification/' ||
                                                        to_char(g_request_start_date,
                                                                'ddmmyyyy hh24:mi'),
                                       p_err_code    => l_retcode,
                                       p_err_message => l_errbuf);
    ---
  
  EXCEPTION
    WHEN OTHERS THEN
      -- send err alert
      xxobjt_wf_mail.send_mail_text(p_to_role     => fnd_profile.value('XX_ORACLE_OPERATION_ADMIN_USER'),
                                    p_subject     => 'Update SSYS Items Min-Max : Failure',
                                    p_body_text   => 'xxinv_ssys_pkg.update_ssys_items_min_max' ||
                                                     chr(10) ||
                                                     'Unexpected Error:' ||
                                                     SQLERRM,
                                    p_err_code    => l_retcode,
                                    p_err_message => l_errbuf);
      --
      fnd_file.put_line(fnd_file.output,
                        '=======Unexpected ERROR in XXINV_SSYS_PKG.update_ssys_items_min_max proc: ' ||
                        v_step || ' ---' || SQLERRM);
    
      retcode := '2';
      errbuf  := 'Unexpected ERROR in XXINV_SSYS_PKG.update_ssys_items_min_max proc: ' ||
                 v_step || ' ---' || SQLERRM;
  END update_ssys_items_min_max;
  --------------------------------------------------------------------------------------
  PROCEDURE add_lines_to_blanket_po(errbuf  OUT VARCHAR2,
                                    retcode OUT VARCHAR2) IS
  
    CURSOR get_po_blanket_header IS
      SELECT poh.po_header_id,
             poh.segment1,
             poh.type_lookup_code,
             poh.vendor_id,
             v.vendor_name,
             poh.vendor_site_id,
             vs.vendor_site_code,
             poh.agent_id,
             initcap(a.agent_name) agent_name,
             poh.org_id,
             ou.name operating_unit
        FROM po_headers_all poh,
             po_vendor_sites_all vs,
             po_agents_v a,
             po_vendors v,
             hr_operating_units ou,
             po_ga_org_assignments ga,
             (SELECT ---ffv.flex_value    ssys_price_list_name, 
              ---ffv.attribute1    price_list_header_id, 
               poh.org_id,
               ffv.attribute3 blanket_po_header_id,
               poh.segment1   po_blanket_segment1, --- 2 rows (Blanket PO) should be selected
               ou.name        operating_unit
                FROM fnd_flex_value_sets fvs,
                     fnd_flex_values_vl  ffv,
                     po_headers_all      poh,
                     hr_operating_units  ou
               WHERE fvs.flex_value_set_id = ffv.flex_value_set_id
                 AND fvs.flex_value_set_name = 'XXQP_PRICELIST_UPDATES'
                 AND ffv.attribute3 = poh.po_header_id
                 AND poh.org_id = ou.organization_id) po_h_blanket_tab
       WHERE po_h_blanket_tab.po_blanket_segment1 = poh.segment1
         AND poh.global_agreement_flag = 'Y'
         AND poh.type_lookup_code = 'BLANKET'
         AND poh.vendor_id = 4472 ---  Stratasys, Inc.
         AND ou.name IN ('OBJET DE (OU)', 'OBJET HK (OU)') --- org_id in (96, 103)
         AND ga.po_header_id = poh.po_header_id
         AND nvl(ga.enabled_flag, 'N') = 'Y'
         AND ga.organization_id = poh.org_id
         AND nvl(poh.vendor_site_id, -777) = vs.vendor_site_id(+)
         AND poh.org_id = ou.organization_id
         AND nvl(poh.agent_id, -777) = a.agent_id(+)
         AND nvl(poh.vendor_id, -777) = v.vendor_id(+);
  
    CURSOR get_po_blanket_lines(p_operating_unit VARCHAR2) IS
      SELECT a.line_id, rtrim(a.item_code) item_code, a.transfer_price
        FROM xxinv_ssys_blanket_lines a
       WHERE a.status = 'N'
         AND rtrim(a.operating_unit) = rtrim(p_operating_unit); ---parameter
  
    missing_parameter_po_seg1 EXCEPTION;
    invalid_record            EXCEPTION;
    l_req_id                 NUMBER;
    l_error_msg              VARCHAR2(250);
    l_inventory_item_id      NUMBER;
    l_line_num               NUMBER;
    l_interface_header_id    NUMBER;
    l_header_counter         NUMBER := 0;
    l_inserted_lines_counter NUMBER := 0;
  
    l_retcode VARCHAR2(300);
    l_errbuf  VARCHAR2(300);
  
    v_user_id fnd_user.user_id%TYPE;
    v_step    VARCHAR2(30);
  
    x_phase       VARCHAR2(100);
    x_status      VARCHAR2(100);
    x_dev_phase   VARCHAR2(100);
    x_dev_status  VARCHAR2(100);
    x_return_bool BOOLEAN;
    x_message     VARCHAR2(100);
  
  BEGIN
  
    v_step               := 'Step 0';
    retcode              := '0';
    errbuf               := NULL;
    g_request_start_date := SYSDATE;
  
    fnd_file.put_line(fnd_file.output, ''); --empty line
    fnd_file.put_line(fnd_file.output, ''); --empty line
    fnd_file.put_line(fnd_file.output, ''); --empty line
    fnd_file.put_line(fnd_file.output,
                      '================= Add Lines To Blanket PO ===================');
    fnd_file.put_line(fnd_file.log, ''); --empty line
    fnd_file.put_line(fnd_file.log, ''); --empty line
    fnd_file.put_line(fnd_file.log, ''); --empty line
    fnd_file.put_line(fnd_file.log,
                      '================= Add Lines To Blanket PO ===================');
  
    /*-- Initialize User For Updates
    BEGIN
       SELECT user_id
         INTO v_user_id
         FROM fnd_user
        WHERE user_name = 'CONVERSION';
    EXCEPTION
       WHEN no_data_found THEN
          errbuf  := 'Invalid User CONVERSION';
          retcode := 2;
    END;
       
    fnd_global.apps_initialize(user_id      => v_user_id,
                               resp_id      => 50623,  ---- Implementation Manufacturing, OBJET
                               resp_appl_id => 660);*/
  
    UPDATE xxinv_ssys_blanket_lines a
       SET a.error_message = NULL, a.message = NULL
     WHERE a.status = 'N';
  
    v_step := 'Step 5';
    UPDATE xxinv_ssys_blanket_lines a
       SET a.status           = 'E',
           a.error_message    = 'Missing Operating Unit',
           a.last_update_date = SYSDATE,
           a.last_updated_by  = fnd_global.user_id
     WHERE a.status = 'N'
       AND rtrim(a.operating_unit) IS NULL;
  
    v_step := 'Step 10';
    UPDATE xxinv_ssys_blanket_lines a
       SET a.status           = 'E',
           a.error_message    = 'Invalid Operating Unit -- valid values are ''OBJET DE (OU)'' or ''OBJET HK (OU)'' )',
           a.last_update_date = SYSDATE,
           a.last_updated_by  = fnd_global.user_id
     WHERE a.status = 'N'
       AND rtrim(a.operating_unit) IS NOT NULL
       AND NOT EXISTS (SELECT 1
              FROM hr_operating_units ou
             WHERE ou.name = rtrim(a.operating_unit)
               AND ou.organization_id IN (96, 103) -----('OBJET DE (OU)','OBJET HK (OU)') 
            );
  
    v_step := 'Step 15';
    UPDATE xxinv_ssys_blanket_lines a
       SET a.status           = 'E',
           a.error_message    = 'Missing Item Code',
           a.last_update_date = SYSDATE,
           a.last_updated_by  = fnd_global.user_id
     WHERE a.status = 'N'
       AND rtrim(a.item_code) IS NULL;
  
    v_step := 'Step 20';
    UPDATE xxinv_ssys_blanket_lines a
       SET a.status           = 'E',
           a.error_message    = 'There is forbidden character in your Item Code ',
           a.last_update_date = SYSDATE,
           a.last_updated_by  = fnd_global.user_id
     WHERE a.status = 'N'
       AND (instr(ltrim(rtrim(a.item_code)), ' ', 1) > 0 OR
           instr(a.item_code, '.', 1) > 0 OR
           instr(a.item_code, ',', 1) > 0 OR
           instr(a.item_code, '<', 1) > 0 OR
           instr(a.item_code, '>', 1) > 0 OR
           instr(a.item_code, '=', 1) > 0 OR
           instr(a.item_code, '_', 1) > 0 OR
           instr(a.item_code, ';', 1) > 0 OR
           instr(a.item_code, ':', 1) > 0 OR
           instr(a.item_code, '+', 1) > 0 OR
           instr(a.item_code, ')', 1) > 0 OR
           instr(a.item_code, '(', 1) > 0 OR
           instr(a.item_code, '*', 1) > 0 OR
           instr(a.item_code, '&', 1) > 0 OR
           instr(a.item_code, '^', 1) > 0 OR
           instr(a.item_code, '%', 1) > 0 OR
           instr(a.item_code, '$', 1) > 0 OR
           instr(a.item_code, '#', 1) > 0 OR
           instr(a.item_code, '@', 1) > 0 OR
           instr(a.item_code, '!', 1) > 0 OR
           instr(a.item_code, '?', 1) > 0 OR
           instr(a.item_code, '/', 1) > 0 OR
           instr(a.item_code, '\', 1) > 0 OR
           instr(a.item_code, '''', 1) > 0 OR
           instr(a.item_code, '"', 1) > 0 OR
           instr(a.item_code, '|', 1) > 0 OR
           instr(a.item_code, '{', 1) > 0 OR
           instr(a.item_code, '}', 1) > 0 OR
           instr(a.item_code, '[', 1) > 0 OR
           instr(a.item_code, ']', 1) > 0);
  
    v_step := 'Step 22';
    UPDATE xxinv_ssys_blanket_lines a
       SET a.status           = 'E',
           a.error_message    = 'Missing Transfer Price',
           a.last_update_date = SYSDATE,
           a.last_updated_by  = fnd_global.user_id
     WHERE a.status = 'N'
       AND a.transfer_price IS NULL;
  
    v_step := 'Step 22.2';
    UPDATE xxinv_ssys_blanket_lines a
       SET a.status           = 'E',
           a.error_message    = 'Transfer Price should be positive value >0',
           a.last_update_date = SYSDATE,
           a.last_updated_by  = fnd_global.user_id
     WHERE a.status = 'N'
       AND a.transfer_price IS NOT NULL
       AND a.transfer_price <= 0;
  
    COMMIT;
  
    v_step := 'Step 25';
    UPDATE xxinv_ssys_blanket_lines a
       SET a.status           = 'E',
           a.error_message    = 'Item does not exist in Master Organization',
           a.last_update_date = SYSDATE,
           a.last_updated_by  = fnd_global.user_id
     WHERE a.status = 'N'
       AND NOT EXISTS
     (SELECT 1
              FROM mtl_system_items_b msi
             WHERE msi.organization_id = 91 --Master
               AND msi.segment1 = rtrim(a.item_code));
  
    v_step := 'Step 30';
    UPDATE xxinv_ssys_blanket_lines a
       SET a.status           = 'E',
           a.error_message    = 'More than 1 record for the same Item Code and Operating Unit',
           a.last_update_date = SYSDATE,
           a.last_updated_by  = fnd_global.user_id
     WHERE a.status = 'N'
       AND EXISTS
     (SELECT 1
              FROM xxinv_ssys_blanket_lines a2
             WHERE a2.status = 'N'
               AND a2.line_id <> a.line_id
               AND rtrim(a2.item_code) = rtrim(a.item_code)
               AND rtrim(a2.operating_unit) = rtrim(a.operating_unit));
  
    COMMIT;
  
    v_step := 'Step 35';
    UPDATE xxinv_ssys_blanket_lines a
       SET a.status           = 'E',
           a.error_message    = 'Item ' || rtrim(a.item_code) ||
                                ' should be assigned to ''ESB'' organization_id=728',
           a.last_update_date = SYSDATE,
           a.last_updated_by  = fnd_global.user_id
     WHERE a.status = 'N'
       AND a.operating_unit = 'OBJET DE (OU)' --org_id=96
       AND NOT EXISTS
     (SELECT 1
              FROM mtl_system_items_b msi
             WHERE msi.organization_id = 728 --- ESB
               AND msi.segment1 = rtrim(a.item_code));
  
    v_step := 'Step 40';
    UPDATE xxinv_ssys_blanket_lines a
       SET a.status           = 'E',
           a.error_message    = 'Item ' || rtrim(a.item_code) ||
                                ' in ''ESB'' organization_id=728 -- flags...purchasing_enabled,purchasing_item,inventory_item,stock_enabled,mtl_transactions_enabled,costing_enabled,inventory_asset should be Y',
           a.last_update_date = SYSDATE,
           a.last_updated_by  = fnd_global.user_id
     WHERE a.status = 'N'
       AND a.operating_unit = 'OBJET DE (OU)' --org_id=96
       AND NOT EXISTS
     (SELECT 1
              FROM mtl_system_items_b msi
             WHERE msi.organization_id = 728 --- ESB
               AND msi.segment1 = rtrim(a.item_code)
               AND nvl(msi.purchasing_enabled_flag, 'N') = 'Y'
               AND nvl(msi.purchasing_item_flag, 'N') = 'Y'
               AND nvl(msi.inventory_item_flag, 'N') = 'Y'
               AND nvl(msi.stock_enabled_flag, 'N') = 'Y'
               AND nvl(msi.mtl_transactions_enabled_flag, 'N') = 'Y'
               AND nvl(msi.costing_enabled_flag, 'N') = 'Y'
               AND nvl(msi.inventory_asset_flag, 'N') = 'Y');
  
    v_step := 'Step 45';
    UPDATE xxinv_ssys_blanket_lines a
       SET a.status           = 'E',
           a.error_message    = 'Item ' || rtrim(a.item_code) ||
                                ' should be assigned to ''ETF'' organization_id=729',
           a.last_update_date = SYSDATE,
           a.last_updated_by  = fnd_global.user_id
     WHERE a.status = 'N'
       AND a.operating_unit = 'OBJET DE (OU)' --org_id=96
       AND NOT EXISTS
     (SELECT 1
              FROM mtl_system_items_b msi
             WHERE organization_id = 729 --- ETF
               AND msi.segment1 = rtrim(a.item_code));
  
    v_step := 'Step 50';
    UPDATE xxinv_ssys_blanket_lines a
       SET a.status           = 'E',
           a.error_message    = 'Item ' || rtrim(a.item_code) ||
                                ' in ''ETF'' organization_id=729 -- flags...purchasing_enabled,purchasing_item,inventory_item,stock_enabled,mtl_transactions_enabled,costing_enabled,inventory_asset should be Y',
           a.last_update_date = SYSDATE,
           a.last_updated_by  = fnd_global.user_id
     WHERE a.status = 'N'
       AND a.operating_unit = 'OBJET DE (OU)' --org_id=96
       AND NOT EXISTS
     (SELECT 1
              FROM mtl_system_items_b msi
             WHERE msi.organization_id = 729 --- ETF
               AND msi.segment1 = rtrim(a.item_code)
               AND nvl(msi.purchasing_enabled_flag, 'N') = 'Y'
               AND nvl(msi.purchasing_item_flag, 'N') = 'Y'
               AND nvl(msi.inventory_item_flag, 'N') = 'Y'
               AND nvl(msi.stock_enabled_flag, 'N') = 'Y'
               AND nvl(msi.mtl_transactions_enabled_flag, 'N') = 'Y'
               AND nvl(msi.costing_enabled_flag, 'N') = 'Y'
               AND nvl(msi.inventory_asset_flag, 'N') = 'Y');
  
    v_step := 'Step 55';
    UPDATE xxinv_ssys_blanket_lines a
       SET a.status           = 'E',
           a.error_message    = 'Item ' || rtrim(a.item_code) ||
                                ' should be assigned to ''ASH'' organization_id=726',
           a.last_update_date = SYSDATE,
           a.last_updated_by  = fnd_global.user_id
     WHERE a.status = 'N'
       AND a.operating_unit = 'OBJET HK (OU)' --org_id=103
       AND NOT EXISTS
     (SELECT 1
              FROM mtl_system_items_b msi
             WHERE msi.organization_id = 726 --- ASH
               AND msi.segment1 = rtrim(a.item_code));
  
    v_step := 'Step 60';
    UPDATE xxinv_ssys_blanket_lines a
       SET a.status           = 'E',
           a.error_message    = 'Item ' || rtrim(a.item_code) ||
                                ' in ''ASH'' organization_id=726 -- flags (purchasing_enabled,purchasing_item,inventory_item,stock_enabled,mtl_transactions_enabled,costing_enabled,inventory_asset) should be Y',
           a.last_update_date = SYSDATE,
           a.last_updated_by  = fnd_global.user_id
     WHERE a.status = 'N'
       AND a.operating_unit = 'OBJET HK (OU)' --org_id=103
       AND NOT EXISTS
     (SELECT 1
              FROM mtl_system_items_b msi
             WHERE msi.organization_id = 726 --- ASH
               AND msi.segment1 = rtrim(a.item_code)
               AND nvl(msi.purchasing_enabled_flag, 'N') = 'Y'
               AND nvl(msi.purchasing_item_flag, 'N') = 'Y'
               AND nvl(msi.inventory_item_flag, 'N') = 'Y'
               AND nvl(msi.stock_enabled_flag, 'N') = 'Y'
               AND nvl(msi.mtl_transactions_enabled_flag, 'N') = 'Y'
               AND nvl(msi.costing_enabled_flag, 'N') = 'Y'
               AND nvl(msi.inventory_asset_flag, 'N') = 'Y');
  
    v_step := 'Step 65';
    UPDATE xxinv_ssys_blanket_lines a
       SET a.status           = 'E',
           a.error_message    = 'Item ' || rtrim(a.item_code) ||
                                ' should be assigned to ''ATH'' organization_id=725',
           a.last_update_date = SYSDATE,
           a.last_updated_by  = fnd_global.user_id
     WHERE a.status = 'N'
       AND a.operating_unit = 'OBJET HK (OU)' --org_id=103
       AND NOT EXISTS
     (SELECT 1
              FROM mtl_system_items_b msi
             WHERE msi.organization_id = 725 --- ATH
               AND msi.segment1 = rtrim(a.item_code));
  
    v_step := 'Step 70';
    UPDATE xxinv_ssys_blanket_lines a
       SET a.status           = 'E',
           a.error_message    = 'Item ' || rtrim(a.item_code) ||
                                ' in ''ATH'' organization_id=725 -- flags (purchasing_enabled,purchasing_item,inventory_item,stock_enabled,mtl_transactions_enabled,costing_enabled,inventory_asset) should be Y',
           a.last_update_date = SYSDATE,
           a.last_updated_by  = fnd_global.user_id
     WHERE a.status = 'N'
       AND a.operating_unit = 'OBJET HK (OU)' --org_id=103
       AND NOT EXISTS
     (SELECT 1
              FROM mtl_system_items_b msi
             WHERE msi.organization_id = 725 --- ATH
               AND msi.segment1 = rtrim(a.item_code)
               AND nvl(msi.purchasing_enabled_flag, 'N') = 'Y'
               AND nvl(msi.purchasing_item_flag, 'N') = 'Y'
               AND nvl(msi.inventory_item_flag, 'N') = 'Y'
               AND nvl(msi.stock_enabled_flag, 'N') = 'Y'
               AND nvl(msi.mtl_transactions_enabled_flag, 'N') = 'Y'
               AND nvl(msi.costing_enabled_flag, 'N') = 'Y'
               AND nvl(msi.inventory_asset_flag, 'N') = 'Y');
  
    COMMIT;
  
    FOR po_blanket_header_rec IN get_po_blanket_header LOOP
      ----------PO BLANKET HEADERS LOOP ----------2 records only--------------
      v_step                   := 'Step 100';
      l_header_counter         := l_header_counter + 1;
      l_error_msg              := NULL;
      l_interface_header_id    := NULL;
      l_inserted_lines_counter := 0;
    
      fnd_file.put_line(fnd_file.output,
                        '******* Blanket PO segment1=' ||
                        po_blanket_header_rec.segment1 || ' *******');
      fnd_file.put_line(fnd_file.output,
                        'po_header_id    =' ||
                        po_blanket_header_rec.po_header_id);
      fnd_file.put_line(fnd_file.output,
                        'operating unit  =' ||
                        po_blanket_header_rec.operating_unit);
      fnd_file.put_line(fnd_file.output,
                        'type_lookup_code=' ||
                        po_blanket_header_rec.type_lookup_code);
      fnd_file.put_line(fnd_file.output,
                        'vendor name     =' ||
                        po_blanket_header_rec.vendor_name);
      fnd_file.put_line(fnd_file.output,
                        'vendor site code=' ||
                        po_blanket_header_rec.vendor_site_code);
      fnd_file.put_line(fnd_file.output,
                        'agent name      =' ||
                        po_blanket_header_rec.agent_name);
    
      fnd_file.put_line(fnd_file.log,
                        '******* Blanket PO segment1=' ||
                        po_blanket_header_rec.segment1 || ' *******');
      fnd_file.put_line(fnd_file.log,
                        'po_header_id    =' ||
                        po_blanket_header_rec.po_header_id);
      fnd_file.put_line(fnd_file.log,
                        'operating unit  =' ||
                        po_blanket_header_rec.operating_unit);
      fnd_file.put_line(fnd_file.log,
                        'type_lookup_code=' ||
                        po_blanket_header_rec.type_lookup_code);
      fnd_file.put_line(fnd_file.log,
                        'vendor name     =' ||
                        po_blanket_header_rec.vendor_name);
      fnd_file.put_line(fnd_file.log,
                        'vendor site code=' ||
                        po_blanket_header_rec.vendor_site_code);
      fnd_file.put_line(fnd_file.log,
                        'agent name      =' ||
                        po_blanket_header_rec.agent_name);
    
      v_step := 'Step 110';
      UPDATE xxinv_ssys_blanket_lines a
         SET a.status           = 'E',
             a.error_message    = 'Item already exists in PO_LINES_ALL for Blanket PO Segment1=' ||
                                  po_blanket_header_rec.segment1 ||
                                  ' (Operating Unit=''' ||
                                  po_blanket_header_rec.operating_unit ||
                                  ''') ',
             a.last_update_date = SYSDATE,
             a.last_updated_by  = fnd_global.user_id
       WHERE a.status = 'N'
         AND EXISTS
       (SELECT 1
                FROM po_headers_all     poh,
                     po_lines_all       pol,
                     mtl_system_items_b msi
               WHERE msi.segment1 = rtrim(a.item_code)
                 AND poh.segment1 = po_blanket_header_rec.segment1
                 AND msi.organization_id = 91 --Master
                 AND msi.inventory_item_id = pol.item_id
                 AND poh.po_header_id = pol.po_header_id);
    
      BEGIN
      
        mo_global.set_org_access(p_org_id_char     => po_blanket_header_rec.org_id,
                                 p_sp_id_char      => NULL,
                                 p_appl_short_name => 'PO');
      EXCEPTION
        WHEN OTHERS THEN
          l_error_msg := 'Invalid Operating Unit, ' || SQLERRM;
          RAISE invalid_record;
      END;
    
      v_step := 'Step 120';
      ---Get max. existing line_num for this PO
      SELECT nvl(MAX(pol.line_num), 0)
        INTO l_line_num
        FROM po_lines_all pol
       WHERE pol.po_header_id = po_blanket_header_rec.po_header_id;
    
      l_error_msg := NULL;
      FOR blanket_lines_rec IN get_po_blanket_lines(po_blanket_header_rec.operating_unit) LOOP
        --------- Lines loop -----------------------
        BEGIN
          v_step     := 'Step 130';
          l_line_num := l_line_num + 1;
          ----------------------------------
          v_step := 'Step 140';
          IF l_interface_header_id IS NULL THEN
            SELECT apps.po_headers_interface_s.nextval
              INTO l_interface_header_id
              FROM dual;
          END IF;
          ----------------------------------
          v_step := 'Step 150';
          BEGIN
            SELECT inventory_item_id
              INTO l_inventory_item_id
              FROM mtl_system_items_b
             WHERE segment1 = blanket_lines_rec.item_code
               AND organization_id = 91; --Master
          EXCEPTION
            WHEN no_data_found THEN
              ----'This item does not exist in mtl_system_items_b';
              l_inventory_item_id := NULL;
          END;
          --------------------
          v_step := 'Step 160';
          INSERT INTO po_lines_interface
            (interface_line_id,
             interface_header_id,
             line_num,
             item_id,
             action,
             process_code,
             unit_price,
             quantity,
             ---EXPIRATION_DATE,
             creation_date,
             created_by,
             last_update_date,
             last_updated_by)
          VALUES
            (apps.po_lines_interface_s.nextval,
             l_interface_header_id,
             l_line_num,
             l_inventory_item_id,
             'ADD',
             'PENDING',
             blanket_lines_rec.transfer_price,
             999999,
             ---to_date('31-DEC-'||to_char(to_number(to_char(SYSDATE,'YYYY'))+1),'DD-MON-YYYY'),  ---EXPIRATION_DATE
             SYSDATE,
             v_user_id,
             SYSDATE,
             v_user_id);
        
          IF MOD(l_inserted_lines_counter, 100) = 0 THEN
            COMMIT;
          END IF;
          l_inserted_lines_counter := l_inserted_lines_counter + 1;
        
        EXCEPTION
        
          WHEN OTHERS THEN
            v_step := 'Step 180';
            ROLLBACK;
            l_error_msg := SQLERRM;
            UPDATE xxinv_ssys_blanket_lines a
               SET a.status           = 'E',
                   a.error_message    = 'Error when inserting into PO_LINES_INTERFACE table: ' ||
                                        l_error_msg,
                   a.last_update_date = SYSDATE,
                   a.last_updated_by  = fnd_global.user_id
             WHERE a.line_id = blanket_lines_rec.line_id;
        END;
        --------- the end of PO BLANKET LINES LOOP -----------------------                         
      END LOOP;
      COMMIT;
    
      IF l_inserted_lines_counter > 0 THEN
        v_step := 'Step 190';
        INSERT INTO po_headers_interface
          (interface_header_id,
           po_header_id, --this blanket po will be updated (new line/lines will be added)
           batch_id,
           action,
           process_code,
           document_type_code,
           approval_status,
           org_id,
           vendor_id,
           vendor_site_code,
           vendor_site_id,
           agent_id, --optional as you can enter buyer duringimport run
           -----VENDOR_DOC_NUM, --Unique Identifier used to update Blanket
           creation_date,
           created_by,
           last_update_date,
           last_updated_by)
        VALUES
          (l_interface_header_id,
           po_blanket_header_rec.po_header_id,
           1,
           'UPDATE',
           'PENDING',
           'BLANKET',
           'APPROVED',
           po_blanket_header_rec.org_id,
           po_blanket_header_rec.vendor_id,
           po_blanket_header_rec.vendor_site_code,
           po_blanket_header_rec.vendor_site_id,
           po_blanket_header_rec.agent_id,
           ----po_blanket_header_rec.segment1,
           SYSDATE,
           v_user_id,
           SYSDATE,
           v_user_id);
        COMMIT;
        -----------------------------------------------------------------------------------------------------------------------------------
        ---Concurrent program 'Import Price Catalogs' should be submitted from responsibility 'Implementation Manufacturing, OBJET'
        -----------------------------------------------------------------------------------------------------------------------------------
        v_step   := 'Step 200';
        l_req_id := fnd_request.submit_request('PO',
                                               'POXPDOI', ---Import Price Catalogs 
                                               NULL,
                                               NULL,
                                               FALSE,
                                               NULL, ---parameter  1 Default Buyer
                                               'Blanket', ---parameter  2 Document Type
                                               NULL, ---parameter  3 Document Sub Type
                                               'N', ---parameter  4 Create or Update Items
                                               'N', ---parameter  5 Create Sourcing Rules
                                               'APPROVED', ---parameter  6 Approval Status
                                               NULL, ---parameter  7 Release Generetion Method
                                               1, ---parameter  8 Batch Id
                                               po_blanket_header_rec.org_id, ---parameter  9 Operating Unit
                                               'Y', ---parameter 10 Global Agreement
                                               'Y', ---parameter 11 Enable Sourcing Level
                                               NULL, ---parameter 12 Sourcing Level
                                               NULL, ---parameter 13 Inv Org Enable
                                               NULL); ---parameter 14 Inventory Organization
        COMMIT;
      
        IF l_req_id > 0 THEN
          fnd_file.put_line(fnd_file.log,
                            'Concurrent ''Import Price Catalogs'' was submitted successfully (request_id=' ||
                            l_req_id || ')');
          dbms_output.put_line('Concurrent ''Import Price Catalogs'' was submitted successfully (request_id=' ||
                               l_req_id || ')');
          ---------
          v_step := 'Step 210';
          LOOP
            x_return_bool := fnd_concurrent.wait_for_request(l_req_id,
                                                             10, --- interval 10  seconds
                                                             600, --- max wait 300 seconds
                                                             x_phase,
                                                             x_status,
                                                             x_dev_phase,
                                                             x_dev_status,
                                                             x_message);
            EXIT WHEN x_return_bool AND upper(x_dev_phase) = 'COMPLETE';
          
          END LOOP;
        
          fnd_file.put_line(fnd_file.log,
                            '======= The ''Import Price Catalogs'' concurrent program has completed with status ' ||
                            upper(x_dev_status) ||
                            ',  See log for request_id=' || l_req_id);
          dbms_output.put_line('The ''Import Price Catalogs'' concurrent program has completed with status ' ||
                               upper(x_dev_status) ||
                               ',  See log for request_id=' || l_req_id);
        
          IF upper(x_dev_phase) = 'COMPLETE' AND
             upper(x_dev_status) IN ('ERROR', 'WARNING') THEN
            fnd_file.put_line(fnd_file.log,
                              '======= The ''Import Price Catalogs'' concurrent program completed in error. See log for request_id=' ||
                              l_req_id);
            v_step := 'Step 220';
            UPDATE xxinv_ssys_blanket_lines a
               SET a.status           = 'E',
                   a.error_message    = 'The ''Import Price Catalogs'' concurrent program was completed in error. See log for request_id=' ||
                                        l_req_id,
                   a.last_update_date = SYSDATE,
                   a.last_updated_by  = fnd_global.user_id
             WHERE a.status = 'N';
          
          ELSIF upper(x_dev_phase) = 'COMPLETE' AND
                upper(x_dev_status) = 'NORMAL' THEN
            fnd_file.put_line(fnd_file.log,
                              '======= The ''Import Price Catalogs'' program successfully completed for request_id=' ||
                              l_req_id);
            v_step := 'Step 230';
            UPDATE xxinv_ssys_blanket_lines a
               SET a.status           = 'S', --- Blanket PO Line SUCCESSFULLY created
                   a.last_update_date = SYSDATE,
                   a.last_updated_by  = fnd_global.user_id
             WHERE a.status = 'N'
               AND rtrim(a.operating_unit) =
                   po_blanket_header_rec.operating_unit ---
               AND EXISTS
             (SELECT 1
                      FROM po_headers_all     poh,
                           po_lines_all       pol,
                           mtl_system_items_b msi
                     WHERE poh.po_header_id = pol.po_header_id
                       AND nvl(pol.expiration_date, SYSDATE) >= SYSDATE
                       AND pol.item_id = msi.inventory_item_id
                       AND msi.organization_id = 91 --Master
                       AND poh.po_header_id =
                           po_blanket_header_rec.po_header_id ---
                       AND msi.segment1 = rtrim(a.item_code));
          
            v_step := 'Step 240';
            UPDATE xxinv_ssys_blanket_lines a
               SET a.status           = 'E',
                   a.error_message    = 'Open Interface (PO_LINES_INTERFACE) ERROR: ' ||
                                        (SELECT poie.error_message
                                           FROM po_lines_interface  poli,
                                                po_interface_errors poie,
                                                mtl_system_items_b  msi
                                          WHERE poli.interface_header_id =
                                                l_interface_header_id ------
                                            AND poli.interface_header_id =
                                                poie.interface_header_id
                                            AND poli.interface_line_id =
                                                poie.interface_line_id
                                            AND poli.item_id =
                                                msi.inventory_item_id
                                            AND msi.organization_id = 91 --master
                                            AND msi.segment1 =
                                                rtrim(a.item_code) ------ 
                                            AND rownum = 1),
                   a.last_update_date = SYSDATE,
                   a.last_updated_by  = fnd_global.user_id
             WHERE a.status = 'N'
               AND rtrim(a.operating_unit) =
                   po_blanket_header_rec.operating_unit ---  
               AND EXISTS
             (SELECT 1 ---poie.error_message
                      FROM po_lines_interface  poli,
                           po_interface_errors poie,
                           mtl_system_items_b  msi
                     WHERE poli.interface_header_id = l_interface_header_id ------
                       AND poli.interface_header_id =
                           poie.interface_header_id
                       AND poli.interface_line_id = poie.interface_line_id
                       AND poli.item_id = msi.inventory_item_id
                       AND msi.organization_id = 91 --master
                       AND msi.segment1 = rtrim(a.item_code) ------ 
                    ----and   rownum=1
                    );
            v_step := 'Step 250';
            UPDATE xxinv_ssys_blanket_lines a
               SET a.status           = 'E',
                   a.error_message    = 'Open Interface (PO_HEADERS_INTERFACE) ERROR: ' ||
                                        (SELECT poie.error_message
                                           FROM po_interface_errors poie
                                          WHERE poie.interface_header_id =
                                                l_interface_header_id ------
                                            AND poie.interface_line_id IS NULL
                                            AND rownum = 1),
                   a.last_update_date = SYSDATE,
                   a.last_updated_by  = fnd_global.user_id
             WHERE a.status = 'N'
               AND rtrim(a.operating_unit) =
                   po_blanket_header_rec.operating_unit --- 
               AND EXISTS
             (SELECT 1 ----poie.error_message
                      FROM po_interface_errors poie
                     WHERE poie.interface_header_id = l_interface_header_id ------
                       AND poie.interface_line_id IS NULL);
          
          ELSE
            fnd_file.put_line(fnd_file.log,
                              '======= The ''Import Price Catalogs'' request failed.Review log for Oracle request_id=' ||
                              l_req_id);
            v_step := 'Step 300';
            UPDATE xxinv_ssys_blanket_lines a
               SET a.status           = 'E',
                   a.error_message    = 'The ''Import Price Catalogs'' request failed.Review log for Oracle request_id=' ||
                                        l_req_id,
                   a.last_update_date = SYSDATE,
                   a.last_updated_by  = fnd_global.user_id
             WHERE a.status = 'N';
          END IF;
        ELSE
          fnd_file.put_line(fnd_file.log,
                            'Concurrent ''Import Price Catalogs'' submitting problem');
          dbms_output.put_line('Concurrent ''Import Price Catalogs'' submitting PROBLEM');
          UPDATE xxinv_ssys_blanket_lines a
             SET a.status           = 'E',
                 a.error_message    = 'Concurrent ''Import Price Catalogs'' submitting problem',
                 a.last_update_date = SYSDATE,
                 a.last_updated_by  = fnd_global.user_id
           WHERE a.status = 'N';
        END IF;
        --see errors  select * from PO_INTERFACE_ERRORS
      END IF; ----IF l_inserted_lines_counter>0 THEN  
      COMMIT;
      ----------the end of PO BLANKET HEADERS LOOP ---------------------
    END LOOP;
  
    COMMIT;
  
    --- send notification log----  
    xxobjt_wf_mail.send_mail_body_proc(p_to_role     => fnd_profile.value('XX_ORACLE_OPERATION_ADMIN_USER'),
                                       p_cc_mail     => xxobjt_general_utils_pkg.get_dist_mail_list(NULL,
                                                                                                    'SSYS_BPA'),
                                       p_bcc_mail    => NULL,
                                       p_subject     => 'Add Lines To Blanket PO : Alert Log',
                                       p_body_proc   => 'xxinv_ssys_notifications_pkg.add_lines_to_bpa_notification/' ||
                                                        to_char(g_request_start_date,
                                                                'ddmmyyyy hh24:mi'),
                                       p_err_code    => l_retcode,
                                       p_err_message => l_errbuf);
    ---
  
  EXCEPTION
    WHEN OTHERS THEN
      -- send err alert
      xxobjt_wf_mail.send_mail_text(p_to_role     => fnd_profile.value('XX_ORACLE_OPERATION_ADMIN_USER'),
                                    p_subject     => 'Add Lines To Blanket PO : Failure',
                                    p_body_text   => 'xxinv_ssys_pkg.add_lines_to_blanket_po' ||
                                                     chr(10) ||
                                                     'Unexpected Error:' ||
                                                     SQLERRM,
                                    p_err_code    => l_retcode,
                                    p_err_message => l_errbuf);
      --
      fnd_file.put_line(fnd_file.output,
                        '=======Unexpected ERROR in XXINV_SSYS_PKG.add_lines_to_blanket_po proc: ' ||
                        v_step || ' ---' || SQLERRM);
    
      retcode := '2';
      errbuf  := 'Unexpected ERROR in XXINV_SSYS_PKG.add_lines_to_blanket_po proc: ' ||
                 v_step || ' ---' || SQLERRM;
  END add_lines_to_blanket_po;
  ------------------------------------------------------------------------------------                                             
  PROCEDURE add_ssys_item_cost(errbuf OUT VARCHAR2, retcode OUT VARCHAR2) IS
  
    CURSOR csr_items_cost IS
      SELECT ssysic.line_id,
             cct.cost_type_id      ssys_cost_type_id,
             cct.cost_type         ssys_cost_type,
             bomr.resource_code,
             bomr.resource_id,
             msi.inventory_item_id,
             msi.organization_id,
             ----ssysic.item_cost   usage_rate_or_amount,
             ssysic.item_cost,
             bomr.cost_element_id,
             decode(nvl(msi.default_include_in_rollup_flag, 'N'), 'Y', 1, 2) based_on_rollup_flag,
             bomr.default_basis_type basis_type,
             CASE
               WHEN ((SELECT msi1.planning_make_buy_code
                        FROM mtl_system_items_b msi1
                       WHERE msi1.organization_id = 734 ---IRK  --------92---WRI
                         AND msi1.inventory_item_id = msi.inventory_item_id) = 1) THEN
                1
               ELSE
                msi.planning_make_buy_code
             END planning_make_buy_code,
             flv.lookup_code make_lookup_code_value,
             decode(nvl(ssys_cost_tab.ssys_item_cost_exists_flag, 'N'),
                    'N',
                    'CREATE',
                    'UPDATE') transaction_type
        FROM xxinv_ssys_item_cost ssysic,
             bom_resources bomr,
             mtl_system_items_b msi,
             mtl_parameters mp,
             cst_cost_types cct,
             fnd_lookup_values_vl flv,
             (SELECT rtrim(ssysic2.item_code) item_code,
                     rtrim(ssysic2.organization_code) organization_code,
                     'Y' ssys_item_cost_exists_flag
                FROM xxinv_ssys_item_cost ssysic2,
                     cst_item_costs       cic,
                     cst_cost_types       cct,
                     mtl_system_items_b   msi,
                     mtl_parameters       mp
               WHERE msi.organization_id = cic.organization_id
                 AND msi.inventory_item_id = cic.inventory_item_id
                 AND cic.organization_id = mp.organization_id
                 AND cic.cost_type_id = cct.cost_type_id
                 AND cct.cost_type = 'SSYS Cost'
                 AND ssysic2.status = 'N'
                 AND msi.segment1 = rtrim(ssysic2.item_code)
                 AND mp.organization_code = rtrim(ssysic2.organization_code)) ssys_cost_tab
       WHERE ssysic.status = 'N'
         AND cct.cost_type = 'SSYS Cost'
         AND bomr.resource_code = 'Material'
         AND bomr.organization_id = msi.organization_id
         AND msi.organization_id = mp.organization_id
         AND msi.segment1 = rtrim(ssysic.item_code)
         AND mp.organization_code = rtrim(ssysic.organization_code)
         AND rtrim(ssysic.item_code) = ssys_cost_tab.item_code(+)
         AND rtrim(ssysic.organization_code) =
             ssys_cost_tab.organization_code(+)
         AND flv.lookup_type = 'MTL_PLANNING_MAKE_BUY'
         AND flv.meaning = 'Make';
  
    --v_user_id         NUMBER;
    v_step            VARCHAR2(50);
    v_numeric_dummy   NUMBER;
    l_records_updated NUMBER;
    l_retcode         VARCHAR2(300);
    l_errbuf          VARCHAR2(300);
  
    l_group_id NUMBER;
    ---l_make_value                    NUMBER;
    l_ssys_cost_type               VARCHAR2(100);
    l_inserted_into_interface_cntr NUMBER := 0;
    l_error_msg                    VARCHAR2(3000);
    x_bool                         BOOLEAN;
  
    x_req_id      NUMBER;
    x_phase       VARCHAR2(100);
    x_status      VARCHAR2(100);
    x_dev_phase   VARCHAR2(100);
    x_dev_status  VARCHAR2(100);
    x_return_bool BOOLEAN;
    x_message     VARCHAR2(100);
  
  BEGIN
  
    v_step               := 'Step 0';
    retcode              := '0';
    errbuf               := NULL;
    g_request_start_date := SYSDATE;
  
    fnd_file.put_line(fnd_file.output, ''); --empty line
    fnd_file.put_line(fnd_file.output, ''); --empty line
    fnd_file.put_line(fnd_file.output, ''); --empty line
    fnd_file.put_line(fnd_file.output,
                      '================= SSYS Item Cost ===================');
    fnd_file.put_line(fnd_file.log, ''); --empty line
    fnd_file.put_line(fnd_file.log, ''); --empty line
    fnd_file.put_line(fnd_file.log, ''); --empty line
    fnd_file.put_line(fnd_file.log,
                      '================= SSYS Item Cost ===================');
  
    /*-- Initialize User For Updates
    BEGIN
       SELECT user_id
         INTO v_user_id
         FROM fnd_user
        WHERE user_name = 'CONVERSION';
    EXCEPTION
       WHEN no_data_found THEN
          errbuf  := 'Invalid User CONVERSION';
          retcode := 2;
    END;
       
    fnd_global.apps_initialize(user_id      => v_user_id,
                               resp_id      => 50623,  ---- Implementation Manufacturing, OBJET
                               resp_appl_id => 660);*/
  
    ----Data validations-----------------------------------
    v_step := 'Step 5';
    UPDATE xxinv_ssys_item_cost a
       SET a.status = 'N'
     WHERE a.status IS NULL;
  
    v_step := 'Step 7';
    UPDATE xxinv_ssys_item_cost a
       SET a.error_message = NULL, a.message = NULL
     WHERE a.status = 'N';
  
    v_step := 'Step 10';
    SELECT COUNT(1)
      INTO v_numeric_dummy
      FROM xxinv_ssys_item_cost a
     WHERE nvl(a.status, 'N') = 'N';
  
    IF v_numeric_dummy = 0 THEN
      fnd_file.put_line(fnd_file.output,
                        'No new records (with Status=''N'' or Status is empty)');
    END IF;
  
    v_step := 'Step 15'; ----
    UPDATE xxinv_ssys_item_cost a
       SET a.status           = 'E',
           a.error_message    = 'Missing Item Code',
           a.last_update_date = SYSDATE,
           a.last_updated_by  = fnd_global.user_id
     WHERE a.status = 'N'
       AND ltrim(rtrim(a.item_code), '-') IS NULL;
  
    l_records_updated := SQL%ROWCOUNT;
    IF l_records_updated > 0 THEN
      fnd_file.put_line(fnd_file.output,
                        l_records_updated ||
                        ' records with Missing Item_Code');
    END IF;
  
    v_step := 'Step 20'; ----
    UPDATE xxinv_ssys_item_cost a
       SET a.status           = 'E',
           a.error_message    = 'Missing Organization Code',
           a.last_update_date = SYSDATE,
           a.last_updated_by  = fnd_global.user_id
     WHERE a.status = 'N'
       AND rtrim(a.organization_code) IS NULL;
  
    l_records_updated := SQL%ROWCOUNT;
    IF l_records_updated > 0 THEN
      fnd_file.put_line(fnd_file.output,
                        l_records_updated ||
                        ' records with Missing Organization_Code');
    END IF;
  
    v_step := 'Step 25';
    UPDATE xxinv_ssys_item_cost a
       SET a.status           = 'E',
           a.error_message    = 'Invalid Organization',
           a.last_update_date = SYSDATE,
           a.last_updated_by  = fnd_global.user_id
     WHERE a.status = 'N'
       AND rtrim(a.organization_code) IS NOT NULL
       AND NOT EXISTS
     (SELECT 1
              FROM mtl_parameters mp
             WHERE mp.organization_code = rtrim(a.organization_code));
  
    l_records_updated := SQL%ROWCOUNT;
    IF l_records_updated > 0 THEN
      fnd_file.put_line(fnd_file.output,
                        l_records_updated ||
                        ' records with Invalid Organization');
    END IF;
  
    v_step := 'Step 25.2';
    UPDATE xxinv_ssys_item_cost a
       SET a.status           = 'E',
           a.error_message    = 'Invalid Organization (Not found in value set XXINV_SSYS_ITEM_COST_ORG)',
           a.last_update_date = SYSDATE,
           a.last_updated_by  = fnd_global.user_id
     WHERE a.status = 'N'
       AND rtrim(a.organization_code) IS NOT NULL
       AND NOT EXISTS
     (SELECT 1
              FROM fnd_flex_value_sets fvs, fnd_flex_values_vl ffv
             WHERE fvs.flex_value_set_id = ffv.flex_value_set_id
               AND fvs.flex_value_set_name = 'XXINV_SSYS_ITEM_COST_ORG'
               AND ffv.flex_value = rtrim(a.organization_code));
  
    l_records_updated := SQL%ROWCOUNT;
    IF l_records_updated > 0 THEN
      fnd_file.put_line(fnd_file.output,
                        l_records_updated ||
                        ' records with Invalid Organization (Not found in value set XXINV_SSYS_ITEM_COST_ORG)');
    END IF;
  
    v_step := 'Step 30'; ----
    UPDATE xxinv_ssys_item_cost a
       SET a.status           = 'E',
           a.error_message    = 'Resource Code ''Material'' is not defined in BOM_RESOURCES table for Organization=' ||
                                rtrim(a.organization_code),
           a.last_update_date = SYSDATE,
           a.last_updated_by  = fnd_global.user_id
     WHERE a.status = 'N'
       AND rtrim(a.organization_code) IS NOT NULL
       AND NOT EXISTS
     (SELECT 1
              FROM bom_resources r, mtl_parameters mp
             WHERE r.resource_code = 'Material'
               AND r.organization_id = mp.organization_id
               AND mp.organization_code = rtrim(a.organization_code));
  
    l_records_updated := SQL%ROWCOUNT;
    IF l_records_updated > 0 THEN
      fnd_file.put_line(fnd_file.output,
                        l_records_updated ||
                        ' records with Invalid Organization');
    END IF;
  
    v_step := 'Step 35'; ----
    ----Check item_code value---- may be characters like . or , or < or > or ; or : or ' or " or + .. inside
    UPDATE xxinv_ssys_item_cost a
       SET a.status           = 'E',
           a.error_message    = 'There is forbidden character in your Item Code ',
           a.last_update_date = SYSDATE,
           a.last_updated_by  = fnd_global.user_id
     WHERE a.status = 'N'
       AND (instr(ltrim(rtrim(a.item_code)), ' ', 1) > 0 OR
           instr(a.item_code, '.', 1) > 0 OR
           instr(a.item_code, ',', 1) > 0 OR
           instr(a.item_code, '<', 1) > 0 OR
           instr(a.item_code, '>', 1) > 0 OR
           instr(a.item_code, '=', 1) > 0 OR
           instr(a.item_code, '_', 1) > 0 OR
           instr(a.item_code, ';', 1) > 0 OR
           instr(a.item_code, ':', 1) > 0 OR
           instr(a.item_code, '+', 1) > 0 OR
           instr(a.item_code, ')', 1) > 0 OR
           instr(a.item_code, '(', 1) > 0 OR
           instr(a.item_code, '*', 1) > 0 OR
           instr(a.item_code, '&', 1) > 0 OR
           instr(a.item_code, '^', 1) > 0 OR
           instr(a.item_code, '%', 1) > 0 OR
           instr(a.item_code, '$', 1) > 0 OR
           instr(a.item_code, '#', 1) > 0 OR
           instr(a.item_code, '@', 1) > 0 OR
           instr(a.item_code, '!', 1) > 0 OR
           instr(a.item_code, '?', 1) > 0 OR
           instr(a.item_code, '/', 1) > 0 OR
           instr(a.item_code, '\', 1) > 0 OR
           instr(a.item_code, '''', 1) > 0 OR
           instr(a.item_code, '"', 1) > 0 OR
           instr(a.item_code, '|', 1) > 0 OR
           instr(a.item_code, '{', 1) > 0 OR
           instr(a.item_code, '}', 1) > 0 OR
           instr(a.item_code, '[', 1) > 0 OR
           instr(a.item_code, ']', 1) > 0);
  
    l_records_updated := SQL%ROWCOUNT;
    IF l_records_updated > 0 THEN
      fnd_file.put_line(fnd_file.output,
                        l_records_updated ||
                        ' records with forbidden character in Item_Code');
    END IF;
  
    v_step := 'Step 40'; -----
    UPDATE xxinv_ssys_item_cost a
       SET a.status           = 'E',
           a.error_message    = 'This Item does not exist in Organization',
           a.last_update_date = SYSDATE,
           a.last_updated_by  = fnd_global.user_id
     WHERE a.status = 'N'
       AND NOT EXISTS
     (SELECT 1
              FROM mtl_system_items_b msi, mtl_parameters mp
             WHERE msi.segment1 = rtrim(a.item_code)
               AND msi.organization_id = mp.organization_id
               AND mp.organization_code = rtrim(a.organization_code));
  
    l_records_updated := SQL%ROWCOUNT;
    IF l_records_updated > 0 THEN
      fnd_file.put_line(fnd_file.output,
                        l_records_updated ||
                        ' records with ...This Item does not exist in Organization');
    END IF;
  
    v_step := 'Step 45'; -----
    UPDATE xxinv_ssys_item_cost a
       SET a.status           = 'E',
           a.error_message    = 'There are more than 1 record for the same Item_Code and Organization_Code',
           a.last_update_date = SYSDATE,
           a.last_updated_by  = fnd_global.user_id
     WHERE a.status = 'N'
       AND EXISTS
     (SELECT 1
              FROM xxinv_ssys_item_cost a2
             WHERE a2.batch_id = a.batch_id --parameter
               AND a2.status = 'N'
               AND a2.line_id != a.line_id
               AND rtrim(a2.item_code) = rtrim(a.item_code)
               AND rtrim(a2.organization_code) = rtrim(a.organization_code));
  
    l_records_updated := SQL%ROWCOUNT;
    IF l_records_updated > 0 THEN
      fnd_file.put_line(fnd_file.output,
                        'There are more than 1 record for the same Item_Code and Organization_Code');
    END IF;
  
    v_step := 'Step 50'; -----
    UPDATE xxinv_ssys_item_cost a
       SET a.status           = 'E',
           a.error_message    = 'This organization gets costing information from another master organization',
           a.last_update_date = SYSDATE,
           a.last_updated_by  = fnd_global.user_id
     WHERE a.status = 'N'
       AND EXISTS
     (SELECT 1
              FROM mtl_parameters mp
             WHERE mp.organization_code = a.organization_code
               AND mp.organization_id <> mp.cost_organization_id);
  
    l_records_updated := SQL%ROWCOUNT;
    IF l_records_updated > 0 THEN
      fnd_file.put_line(fnd_file.output,
                        l_records_updated ||
                        ' records with ...This organization gets costing information from another master organization');
    END IF;
  
    v_step := 'Step 55';
    UPDATE xxinv_ssys_item_cost a
       SET a.status           = 'E',
           a.error_message    = 'Missing Item Cost',
           a.last_update_date = SYSDATE,
           a.last_updated_by  = fnd_global.user_id
     WHERE a.status = 'N'
       AND a.item_cost IS NULL;
  
    l_records_updated := SQL%ROWCOUNT;
    IF l_records_updated > 0 THEN
      fnd_file.put_line(fnd_file.output,
                        l_records_updated ||
                        ' records with ...Missing Item Cost');
    END IF;
  
    v_step := 'Step 60';
    UPDATE xxinv_ssys_item_cost a
       SET a.status           = 'E',
           a.error_message    = 'Item Cost should be positive value',
           a.last_update_date = SYSDATE,
           a.last_updated_by  = fnd_global.user_id
     WHERE a.status = 'N'
       AND a.item_cost IS NOT NULL
       AND a.item_cost < 0;
  
    l_records_updated := SQL%ROWCOUNT;
    IF l_records_updated > 0 THEN
      fnd_file.put_line(fnd_file.output,
                        l_records_updated ||
                        ' records with ...Item Cost should be positive value');
    END IF;
  
    v_step := 'Step 65';
    UPDATE xxinv_ssys_item_cost a
       SET a.status           = 'E',
           a.error_message    = '''SSYS Cost'' item cost is not defined in CST_COST_TYPES table for this Organization ',
           a.last_update_date = SYSDATE,
           a.last_updated_by  = fnd_global.user_id
     WHERE a.status = 'N'
       AND NOT EXISTS
     (SELECT 1
              FROM cst_cost_types cct, mtl_parameters mp
             WHERE cct.cost_type = 'SSYS Cost'
               AND nvl(cct.disable_date, SYSDATE + 1) > SYSDATE
               AND cct.frozen_standard_flag <> 1
               AND mp.organization_code = rtrim(a.organization_code)
               AND nvl(cct.organization_id, mp.organization_id) =
                   mp.organization_id);
  
    l_records_updated := SQL%ROWCOUNT;
    IF l_records_updated > 0 THEN
      fnd_file.put_line(fnd_file.output,
                        l_records_updated ||
                        ' records with ...''SSYS Cost'' item cost is not defined in CST_COST_TYPES table for this Organization');
    END IF;
  
    COMMIT;
  
    v_step                         := 'Step 100';
    l_ssys_cost_type               := NULL;
    l_inserted_into_interface_cntr := 0;
    SELECT cst_lists_s.nextval INTO l_group_id FROM dual;
  
    FOR cur_item_cost IN csr_items_cost LOOP
      -------
      l_ssys_cost_type := cur_item_cost.ssys_cost_type;
      BEGIN
        IF cur_item_cost.transaction_type = 'UPDATE' THEN
          v_step := 'Step 105';
          DELETE FROM cst_item_cost_details t
           WHERE t.inventory_item_id = cur_item_cost.inventory_item_id
             AND t.cost_type_id = cur_item_cost.ssys_cost_type_id
             AND t.organization_id = cur_item_cost.organization_id;
        
          DELETE FROM cst_item_costs t
           WHERE t.inventory_item_id = cur_item_cost.inventory_item_id
             AND t.cost_type_id = cur_item_cost.ssys_cost_type_id
             AND t.organization_id = cur_item_cost.organization_id;
        END IF;
      
        v_step := 'Step 110';
        INSERT INTO cst_item_cst_dtls_interface
          (group_id,
           inventory_item_id,
           organization_id,
           resource_id,
           cost_type_id,
           cost_element_id,
           last_update_date,
           last_updated_by,
           creation_date,
           created_by,
           last_update_login,
           process_flag,
           usage_rate_or_amount,
           based_on_rollup_flag,
           basis_type,
           group_description)
        VALUES
          (l_group_id,
           cur_item_cost.inventory_item_id,
           cur_item_cost.organization_id,
           cur_item_cost.resource_id,
           cur_item_cost.ssys_cost_type_id,
           cur_item_cost.cost_element_id,
           SYSDATE,
           fnd_global.user_id,
           SYSDATE,
           fnd_global.user_id,
           fnd_global.login_id,
           1,
           decode(cur_item_cost.planning_make_buy_code,
                  to_number(cur_item_cost.make_lookup_code_value),
                  0,
                  cur_item_cost.item_cost),
           cur_item_cost.based_on_rollup_flag,
           cur_item_cost.basis_type,
           'load ' || cur_item_cost.ssys_cost_type || ' cost type');
      
        l_inserted_into_interface_cntr := l_inserted_into_interface_cntr + 1;
      
        IF MOD(l_inserted_into_interface_cntr, 1000) = 0 THEN
          COMMIT;
        END IF;
      EXCEPTION
        WHEN OTHERS THEN
          l_error_msg := SQLERRM;
          UPDATE xxinv_ssys_item_cost a
             SET a.status           = 'E',
                 a.error_message    = 'Unexpected Error in XXINV_SSYS_PKG.add_ssys_item_cost procedure (' ||
                                      v_step || ') :' || l_error_msg,
                 a.last_update_date = SYSDATE,
                 a.last_updated_by  = fnd_global.user_id
           WHERE a.line_id = cur_item_cost.line_id;
      END;
      -------
    END LOOP;
  
    COMMIT;
  
    IF l_inserted_into_interface_cntr > 0 THEN
      v_step := 'Step 130';
      fnd_file.put_line(fnd_file.log,
                        ' ====== ' || l_inserted_into_interface_cntr ||
                        ' records are inseted into CST_ITEM_CST_DTLS_INTERFACE table');
    
      x_bool   := fnd_request.set_print_options(NULL, NULL, 0, TRUE, 'N');
      x_req_id := fnd_request.submit_request(application => 'BOM',
                                             program     => 'CSTPCIMP', --- Cost Import Process
                                             description => NULL,
                                             start_time  => NULL,
                                             sub_request => FALSE,
                                             argument1   => '4',
                                             argument2   => '1',
                                             argument3   => '1',
                                             argument4   => '1',
                                             argument5   => l_group_id,
                                             argument6   => l_ssys_cost_type,
                                             argument7   => '1');
    
      COMMIT;
    
      IF x_req_id = 0 THEN
        -- Failure
        errbuf := fnd_message.get;
        fnd_file.put_line(fnd_file.log,
                          '======ERROR submitting Concurrent Program ''Cost Import Process'' (CSTPCIMP): ' ||
                          errbuf);
        x_bool := fnd_concurrent.set_completion_status('ERROR',
                                                       substrb(errbuf, 1, 60));
      ELSE
        fnd_file.put_line(fnd_file.log,
                          ' ======Concurrent Program ''Cost Import Process'' (CSTPCIMP) was submitted (req_id=' ||
                          x_req_id || ')');
        v_step := 'Step 210';
        LOOP
          x_return_bool := fnd_concurrent.wait_for_request(x_req_id,
                                                           10, --- interval 60 seconds
                                                           600, --- am wait 600 seconds
                                                           x_phase,
                                                           x_status,
                                                           x_dev_phase,
                                                           x_dev_status,
                                                           x_message);
          EXIT WHEN x_return_bool AND upper(x_dev_phase) = 'COMPLETE';
        END LOOP;
        ---------
        fnd_file.put_line(fnd_file.log,
                          '======= The ''Cost Import Process'' concurrent program has completed with status ' ||
                          upper(x_dev_status) ||
                          ',  See log for request_id=' || x_req_id);
        dbms_output.put_line('The ''Cost Import Process'' concurrent program has completed with status ' ||
                             upper(x_dev_status) ||
                             ',  See log for request_id=' || x_req_id);
      
        IF upper(x_dev_phase) = 'COMPLETE' AND
           upper(x_dev_status) IN ('ERROR', 'WARNING') THEN
          fnd_file.put_line(fnd_file.log,
                            '======= The ''Cost Import Process'' concurrent program completed in error. See log for request_id=' ||
                            x_req_id);
          v_step := 'Step 220';
          UPDATE xxinv_ssys_item_cost a
             SET a.status           = 'E',
                 a.error_message    = 'The ''Cost Import Process'' concurrent program was completed in error. See log for request_id=' ||
                                      x_req_id,
                 a.last_update_date = SYSDATE,
                 a.last_updated_by  = fnd_global.user_id
           WHERE a.status = 'N';
        
        ELSIF upper(x_phase) = 'COMPLETED' AND upper(x_status) = 'NORMAL' THEN
          fnd_file.put_line(fnd_file.log,
                            '======= The ''Cost Import Process'' program successfully completed for request_id=' ||
                            x_req_id);
          v_step := 'Step 230';
          UPDATE xxinv_ssys_item_cost a
             SET a.status           = 'S', --- SSYS Item Cost SUCCESSFULLY created/updated
                 a.last_update_date = SYSDATE,
                 a.last_updated_by  = fnd_global.user_id
           WHERE a.status = 'N'
             AND EXISTS
           (SELECT 1
                    FROM cst_item_costs     cic,
                         cst_cost_types     cct,
                         mtl_system_items_b msi,
                         mtl_parameters     mp
                   WHERE msi.organization_id = cic.organization_id
                     AND msi.inventory_item_id = cic.inventory_item_id
                     AND cic.organization_id = mp.organization_id
                     AND cic.cost_type_id = cct.cost_type_id
                     AND cct.cost_type = 'SSYS Cost'
                     AND msi.segment1 = rtrim(a.item_code)
                     AND mp.organization_code = rtrim(a.organization_code));
        
          v_step := 'Step 240';
          UPDATE xxinv_ssys_item_cost a
             SET a.status           = 'E',
                 a.error_message    = 'Open Interface (CST_ITEM_CST_DTLS_INTERFACE) ERROR: ' ||
                                      (SELECT a.error_explanation
                                         FROM cst_item_cst_dtls_interface a,
                                              mtl_parameters              mp,
                                              mtl_system_items_b          msi
                                        WHERE a.group_id = l_group_id -----
                                          AND a.cost_type_id = 1040 ---- 
                                          AND mp.organization_code =
                                              rtrim(a.organization_code) ----
                                          AND msi.segment1 =
                                              rtrim(a.item_code) ---
                                          AND msi.organization_id = 91 --master
                                          AND a.organization_id =
                                              mp.organization_id
                                          AND a.inventory_item_id =
                                              msi.inventory_item_id
                                          AND rownum = 1),
                 a.last_update_date = SYSDATE,
                 a.last_updated_by  = fnd_global.user_id
           WHERE a.status = 'N'
             AND EXISTS
           (SELECT 1 ---a.error_explanation
                    FROM cst_item_cst_dtls_interface a,
                         mtl_parameters              mp,
                         mtl_system_items_b          msi
                   WHERE a.group_id = l_group_id -----
                     AND a.cost_type_id = 1040 ---- 
                     AND mp.organization_code = rtrim(a.organization_code) ----
                     AND msi.segment1 = rtrim(a.item_code) ---
                     AND msi.organization_id = 91 --master
                     AND a.organization_id = mp.organization_id
                     AND a.inventory_item_id = msi.inventory_item_id
                  ----and   rownum=1
                  );
        ELSE
          fnd_file.put_line(fnd_file.log,
                            '======= The ''Cost Import Process'' request failed.Review log for Oracle request_id=' ||
                            x_req_id);
          v_step := 'Step 300';
          UPDATE xxinv_ssys_item_cost a
             SET a.status           = 'E',
                 a.error_message    = 'The ''Cost Import Process'' request failed.Review log for Oracle request_id=' ||
                                      x_req_id,
                 a.last_update_date = SYSDATE,
                 a.last_updated_by  = fnd_global.user_id
           WHERE a.status = 'N';
        END IF; ---IF UPPER (x_phase) = 'COMPLETED' AND UPPER (x_status) = 'ERROR' THEN
      END IF; ---IF x_req_id = 0 THEN
    
    END IF; ---IF l_inserted_into_interface_cntr>0 then
  
    --- send notification log----  
    xxobjt_wf_mail.send_mail_body_proc(p_to_role     => fnd_profile.value('XX_ORACLE_OPERATION_ADMIN_USER'),
                                       p_cc_mail     => xxobjt_general_utils_pkg.get_dist_mail_list(NULL,
                                                                                                    'SSYS_COST'),
                                       p_bcc_mail    => NULL,
                                       p_subject     => 'Add SSYS Item Cost : Alert Log',
                                       p_body_proc   => 'xxinv_ssys_notifications_pkg.add_ssys_item_cost_notificat/' ||
                                                        to_char(g_request_start_date,
                                                                'ddmmyyyy hh24:mi'),
                                       p_err_code    => l_retcode,
                                       p_err_message => l_errbuf);
    ---
  
  EXCEPTION
    WHEN OTHERS THEN
      -- send err alert
      xxobjt_wf_mail.send_mail_text(p_to_role     => fnd_profile.value('XX_ORACLE_OPERATION_ADMIN_USER'),
                                    p_subject     => 'Add SSYS Item Cost : Failure',
                                    p_body_text   => 'xxinv_ssys_pkg.add_ssys_item_cost' ||
                                                     chr(10) ||
                                                     'Unexpected Error:' ||
                                                     SQLERRM,
                                    p_err_code    => l_retcode,
                                    p_err_message => l_errbuf);
      --
    
      fnd_file.put_line(fnd_file.output,
                        '=======Unexpected ERROR in XXINV_SSYS_PKG.add_ssys_item_cost proc: ' ||
                        v_step || ' ---' || SQLERRM);
    
      retcode := '2';
      errbuf  := 'Unexpected ERROR in XXINV_SSYS_PKG.add_ssys_item_cost proc: ' ||
                 v_step || ' ---' || SQLERRM;
  END add_ssys_item_cost;

--------------------------------------------------------------------------------------                                            
END xxinv_ssys_pkg;
/
