CREATE OR REPLACE PACKAGE xxs3_ptm_islocator_pkg
-- ----------------------------------------------------------------------------------------------------------
-- Purpose:  This Package is used for Inventory Stock Locator Extraction, Quality Check and Report generation
--
-- ----------------------------------------------------------------------------------------------------------
-- Ver  Date        Name                          Description
-- 1.0  25/07/2016  TCS                           Initial build
-- ----------------------------------------------------------------------------------------------------------

 AS

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure is used to extract data for Inventory stock locator
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  25/07/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE inv_stock_locator_extract_data(p_errbuf  OUT VARCHAR2
                                          ,p_retcode OUT NUMBER);

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure is used to cleanse data for Inventory stock locator
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  25/07/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE cleanse_data_isloc(p_errbuf  OUT VARCHAR2
                              ,p_retcode OUT NUMBER);

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure is used to create report on data cleansing for Inventory stock locator
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  25/07/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE data_cleanse_report(p_entity VARCHAR2);

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure is used to create report on data transformation for Inventory stock locator
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  25/07/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE data_transform_report(p_entity VARCHAR2);

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure is used to create report on data Quality for Inventory stock locator
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  21/09/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE dq_report_islocator(p_entity VARCHAR2);

END xxs3_ptm_islocator_pkg;
/
CREATE OR REPLACE PACKAGE BODY xxs3_ptm_islocator_pkg
-- ----------------------------------------------------------------------------------------------------------
-- Purpose:  This Package is used for Inventory Stock Locator Extraction, Quality Check and Report generation
--
-- ----------------------------------------------------------------------------------------------------------
-- Ver  Date        Name                          Description
-- 1.0  25/07/2016  TCS                           Initial build
-- ----------------------------------------------------------------------------------------------------------

 AS



  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure is used to write in the concurrent log
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  25/07/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE log_p(p_msg VARCHAR2) IS
  BEGIN
  
    fnd_file.put_line(fnd_file.log, p_msg);
  
  
  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log, 'Error in writing in the Log File. ' ||
                         SQLERRM);
  END log_p;




  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure is used to write in the concurrent output
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  25/07/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE out_p(p_msg VARCHAR2) IS
  BEGIN
  
    fnd_file.put_line(fnd_file.output, p_msg);
  
  
  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log, 'Error in writing in the Output File. ' ||
                         SQLERRM);
  END out_p;




  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used to qality check and Cleanse duplicate attribute2 data for
  -- Inventory Stock Locator
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE quality_chk_dup_loc_val(p_attribute2        IN VARCHAR2
                                   ,p_subinventory_code IN VARCHAR2
                                   ,p_check_flag        OUT VARCHAR2) IS
  
    l_chk_dup_flag VARCHAR2(2);
  
  BEGIN
  
    SELECT 'Y'
    INTO l_chk_dup_flag
    FROM (SELECT attribute2
                ,COUNT(attribute2)
          FROM mtl_item_locations
          WHERE attribute2 = p_attribute2
          GROUP BY attribute2
          HAVING COUNT(attribute2) > 1);
  
    IF l_chk_dup_flag = 'Y'
    THEN
      p_check_flag := 'FALSE';
    ELSE
      p_check_flag := 'TRUE';
    END IF;
  
  END quality_chk_dup_loc_val;




  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure is used to quality check subinventory data mapped to a locator
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  25/07/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE qlty_chk_multi_subinv_per_loc(p_attribute2 IN VARCHAR2
                                         ,p_check_flag OUT VARCHAR2) IS
  
    l_count_subinv        VARCHAR2(2);
    l_get_org             VARCHAR2(50);
    l_get_sub_inv_name    VARCHAR2(50);
    l_get_concat_segments VARCHAR2(50);
    l_get_row             VARCHAR2(50);
    l_get_rack            VARCHAR2(50);
    l_get_bin             VARCHAR2(50);
    l_error_message       VARCHAR2(2000);
  
  BEGIN
  
    xxs3_data_transform_util_pkg2.ptm_locator_attr2_parse(p_attribute2, l_get_org, l_get_sub_inv_name, l_get_concat_segments, l_get_row, l_get_rack, l_get_bin, l_error_message);
  
    SELECT COUNT(DISTINCT(subinventory_code))
    INTO l_count_subinv
    FROM xxs3_ptm_islocator
    WHERE locator_name = l_get_concat_segments
    AND subinventory_code <> l_get_sub_inv_name;
  
    IF l_count_subinv > 1
    THEN
    
      p_check_flag := 'TRUE';
    ELSE
      p_check_flag := 'FALSE';
    END IF;
  
  END qlty_chk_multi_subinv_per_loc;




  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure is used to Cleansing data for Inventory stock locator
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  25/07/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE cleanse_data_isloc(p_errbuf  OUT VARCHAR2
                              ,p_retcode OUT NUMBER) AS
  
    l_status      VARCHAR2(10) := 'SUCCESS';
    l_check_rule  VARCHAR2(10) := 'TRUE';
    l_err_message VARCHAR2(2000);
  
    CURSOR c_isloc IS
      SELECT * FROM xxobjt.xxs3_ptm_islocator;
  
  BEGIN
    FOR i IN c_isloc
    LOOP
    
    
      ---------------------------- Cleanse ENABLED_FLAG-----------------------------------
      BEGIN
      
        UPDATE xxobjt.xxs3_ptm_islocator
        SET s3_enabled_flag = 'Y'
           ,cleanse_status  = 'PASS'
        WHERE xx_inv_stock_locator_id = i.xx_inv_stock_locator_id;
      
      EXCEPTION
        WHEN OTHERS THEN
          l_err_message := SQLERRM;
        
          UPDATE xxobjt.xxs3_ptm_islocator
          SET cleanse_status = 'FAIL'
             ,cleanse_error  = cleanse_error || ' ENABLED_FLAG :' ||
                               l_err_message || ' ,'
          WHERE xx_inv_stock_locator_id = i.xx_inv_stock_locator_id;
        
      END;
    
      ---------------------------- Cleanse LOCATOR_STATUS---------------------------------
    
      BEGIN
      
        UPDATE xxobjt.xxs3_ptm_islocator
        SET s3_locator_status = 'Active'
           ,cleanse_status    = 'PASS'
        WHERE xx_inv_stock_locator_id = i.xx_inv_stock_locator_id;
      
      EXCEPTION
        WHEN OTHERS THEN
          l_err_message := SQLERRM;
        
          UPDATE xxobjt.xxs3_ptm_islocator
          SET cleanse_status = 'FAIL'
             ,cleanse_error  = cleanse_error || ' LOCATOR_STATUS :' ||
                               l_err_message || ' ,'
          WHERE xx_inv_stock_locator_id = i.xx_inv_stock_locator_id;
        
      END;
    
    END LOOP;
    COMMIT;
  
  END cleanse_data_isloc;




  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure is used to insert data into Inventory stock locator DQ table
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  25/07/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE insert_update_isloc_dq(p_inv_stock_locator_id NUMBER
                                  ,p_rule_name            IN VARCHAR2
                                  ,p_reject_code          IN VARCHAR2
                                  ,p_err_code             OUT VARCHAR2
                                  ,p_err_msg              OUT VARCHAR2) IS
  
  BEGIN
    UPDATE xxobjt.xxs3_ptm_islocator
    SET process_flag = 'Q'
    WHERE xx_inv_stock_locator_id = p_inv_stock_locator_id;
  
    INSERT INTO xxobjt.xxs3_ptm_islocator_dq
      (xx_dq_isloc_id
      ,xx_inv_stock_locator_id
      ,rule_name
      ,notes)
    VALUES
      (xxobjt.xxs3_ptm_isloc_dq_seq.NEXTVAL
      ,p_inv_stock_locator_id
      ,p_rule_name
      ,p_reject_code);
  
    p_err_code := '0';
    p_err_msg  := '';
  
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code := '2';
      p_err_msg  := 'SQLERRM: ' || SQLERRM;
      ROLLBACK;
    
  END insert_update_isloc_dq;




  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used to qality check Inventory Stock Locator
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE quality_check_isloc(p_err_code OUT VARCHAR2
                               ,p_err_msg  OUT VARCHAR2) IS
  
    l_status              VARCHAR2(10) := 'SUCCESS';
    l_check_rule          VARCHAR2(10) := 'TRUE';
    l_get_org             VARCHAR2(50);
    l_get_sub_inv_name    VARCHAR2(50);
    l_get_concat_segments VARCHAR2(50);
    l_get_row             VARCHAR2(50);
    l_get_rack            VARCHAR2(50);
    l_get_bin             VARCHAR2(50);
    l_error_message       VARCHAR2(2000);
  
  
  
  
    CURSOR c_isloc IS
      SELECT * FROM xxobjt.xxs3_ptm_islocator WHERE process_flag = 'N';
  
  BEGIN
    FOR i IN c_isloc
    LOOP
      l_status := 'SUCCESS';
    
      -------------------------stock locator is not null------------------------------------------- 
      l_check_rule := xxs3_dq_util_pkg.eqt_155(i.attribute2);
    
      IF l_check_rule = 'FALSE'
      THEN
      
        insert_update_isloc_dq(i.xx_inv_stock_locator_id, 'EQT_155:LOCATOR NAME IS NULL', 'LOCATOR NAME IS NULL', p_err_code, p_err_msg);
        l_status := 'ERR';
      
      END IF;
    
      xxs3_data_transform_util_pkg2.ptm_locator_attr2_parse(i.attribute2, l_get_org, l_get_sub_inv_name, l_get_concat_segments, l_get_row, l_get_rack, l_get_bin, l_error_message);
    
      ------------------------- Valid org code -------------------------------------------   
      l_check_rule := xxs3_dq_util_pkg.eqt_156(i.enabled_flag, l_get_org);
    
      IF l_check_rule = 'FALSE'
      THEN
      
        insert_update_isloc_dq(i.xx_inv_stock_locator_id, 'EQT_156:INVALID ORG CODE', 'INVALID ORG CODE', p_err_code, p_err_msg);
        l_status := 'ERR';
      
      END IF;
    
      ------------------------- Valid subinventory -------------------------------------------   
      l_check_rule := xxs3_dq_util_pkg.eqt_157(i.enabled_flag, l_get_sub_inv_name);
    
      IF l_check_rule = 'FALSE'
      THEN
      
        insert_update_isloc_dq(i.xx_inv_stock_locator_id, 'EQT_157:INVALID SUBINVENTORY CODE', 'INVALID SUBINVENTORY CODE', p_err_code, p_err_msg);
        l_status := 'ERR';
      
      END IF;
    
      ---------------------------locator segment length---------------------------------------------
    
      l_check_rule := xxs3_dq_util_pkg.eqt_161(l_get_concat_segments);
    
      IF l_check_rule = 'FALSE'
      THEN
      
        insert_update_isloc_dq(i.xx_inv_stock_locator_id, 'EQT_161:INVALID LOCATOR SEGMENT LENGTH', 'INVALID LOCATOR SEGMENT LENGTH', p_err_code, p_err_msg);
        l_status := 'ERR';
      
      END IF;
    
      -------------- Check for null stock locator for locator controlled subinventory  --------------
    
      l_check_rule := xxs3_dq_util_pkg.eqt_158(i.enabled_flag, l_get_sub_inv_name, l_get_concat_segments);
    
      IF l_check_rule = 'FALSE'
      THEN
      
        insert_update_isloc_dq(i.xx_inv_stock_locator_id, 'EQT_158:NULL STOCK LOCATOR FOR LOCATOR CONTROLLED SUBINVENTORY', 'NULL STOCK LOCATOR FOR LOCATOR CONTROLLED SUBINVENTORY', p_err_code, p_err_msg);
        l_status := 'ERR';
      
      END IF;
    
      -------------- Check for invalid format stock locator for locator controlled subinventory  --------------
    
      l_check_rule := xxs3_dq_util_pkg.eqt_159(i.enabled_flag, l_get_sub_inv_name, l_get_concat_segments, l_get_row, l_get_rack, l_get_bin);
    
      IF l_check_rule = 'FALSE'
      THEN
      
        insert_update_isloc_dq(i.xx_inv_stock_locator_id, 'EQT_159:INVALID STOCK LOCATOR FORMAT FOR LOCATOR CONTROLLED SUBINVENTORY ', 'INVALID STOCK LOCATOR FORMAT FOR LOCATOR CONTROLLED SUBINVENTORY', p_err_code, p_err_msg);
        l_status := 'ERR';
      
      END IF;
    
      -----------------------------------check duplicate locator for a subinventory-------------------------------------------
    
      /*      quality_chk_dup_loc_val(i.attribute2,
                              l_get_sub_inv_name,
                              l_check_rule);
      
      IF l_check_rule = 'FALSE' THEN
      
        insert_update_isloc_dq(i.xx_inv_stock_locator_id,
                               'EQT_:MULTIPLE LEGACY LOCATOR EXISTS FOR SUBINVENTORY',
                               'DUPLICATE LOCATOR EXISTS FOR SUBINVENTORY',
                               p_err_code,
                               p_err_msg);
        l_status := 'ERR';
      
      END IF;*/
    
      ------------------------------check multiple subinventory for a locator-------------------------------------------------
      /*
            qlty_chk_multi_subinv_per_loc(i.attribute2, l_check_rule);
          
            IF l_check_rule = 'FALSE' THEN
            
              insert_update_isloc_dq(i.xx_inv_stock_locator_id,
                                     'EQT_:DUPLICATE SUBINVENTORY EXISTS FOR THE LOCATOR',
                                     'DUPLICATE SUBINVENTORY EXISTS FOR THE LOCATOR',
                                     p_err_code,
                                     p_err_msg);
              l_status := 'ERR';
      
      END IF;*/
    
      IF l_status <> 'ERR'
      THEN
        UPDATE xxobjt.xxs3_ptm_islocator
        SET process_flag = 'Y'
        WHERE xx_inv_stock_locator_id = i.xx_inv_stock_locator_id;
      END IF;
    
    END LOOP;
  
  END quality_check_isloc;




  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure is used to create report on data cleansing for Inventory stock locator
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  25/07/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE data_cleanse_report(p_entity VARCHAR2) AS
  
    l_status        VARCHAR2(10) := 'SUCCESS';
    l_check_rule    VARCHAR2(10) := 'TRUE';
    l_error_message VARCHAR2(2000);
    l_err_msg       VARCHAR2(2000);
    l_count_success NUMBER;
    l_count_fail    NUMBER;
  
    p_delimiter VARCHAR2(5) := '~';
  
    CURSOR c_report_isloc IS
      SELECT xisl.xx_inv_stock_locator_id
            ,xisl.locator_status
            ,xisl.s3_locator_status
            ,xisl.enabled_flag
            ,xisl.s3_enabled_flag
            ,xisl.cleanse_status
            ,xisl.cleanse_error
      FROM xxobjt.xxs3_ptm_islocator xisl
      WHERE xisl.cleanse_status = 'PASS'
      OR xisl.cleanse_status = 'FAIL';
  
  BEGIN
    SELECT COUNT(1)
    INTO l_count_success
    FROM xxobjt.xxs3_ptm_islocator xisl
    WHERE xisl.cleanse_status = 'PASS';
  
    SELECT COUNT(1)
    INTO l_count_fail
    FROM xxobjt.xxs3_ptm_islocator xisl
    WHERE xisl.cleanse_status = 'FAIL';
  
    out_p(rpad('Report name = Automated Cleanse & Standardize Report' ||
               p_delimiter, 100, ' '));
    out_p(rpad('====================================================' ||
               p_delimiter, 100, ' '));
    out_p(rpad('Data Migration Object Name = ' || p_entity || p_delimiter, 100, ' '));
    out_p('');
    out_p(rpad('Run date and time:    ' ||
               to_char(SYSDATE, 'dd-Mon-YYYY HH24:MI') || p_delimiter, 100, ' '));
    out_p(rpad('Total Record Count Success = ' || l_count_success ||
               p_delimiter, 100, ' '));
    out_p(rpad('Total Record Count Failure = ' || l_count_fail ||
               p_delimiter, 100, ' '));
  
    out_p('');
  
    out_p(rpad('Track Name', 10, ' ') || p_delimiter ||
          rpad('Entity Name', 11, ' ') || p_delimiter ||
          rpad('XX INV STOCK LOCATOR ID  ', 14, ' ') || p_delimiter ||
          rpad('Enabled Flag', 30, ' ') || p_delimiter ||
          rpad('S3 Enabled Flag', 30, ' ') || p_delimiter ||
          rpad('Locator status', 240, ' ') || p_delimiter ||
          rpad('S3 Locator status', 240, ' ') || p_delimiter ||
          rpad('Status', 10, ' ') || p_delimiter ||
          rpad('Error Message', 200, ' '));
  
    FOR r_data IN c_report_isloc
    LOOP
      out_p(rpad('PTM', 10, ' ') || p_delimiter ||
            rpad('LOCATOR', 11, ' ') || p_delimiter ||
            rpad(r_data.xx_inv_stock_locator_id, 14, ' ') ||
            rpad(r_data.enabled_flag, 30, ' ') || p_delimiter ||
            rpad(r_data.s3_enabled_flag, 30, ' ') || p_delimiter ||
            rpad(r_data.locator_status, 240, ' ') || p_delimiter ||
            rpad(r_data.s3_locator_status, 240, ' ') || p_delimiter ||
            rpad(r_data.cleanse_status, 10, ' ') || p_delimiter ||
            rpad(nvl(r_data.cleanse_error, 'NULL'), 200, ' '));
    
    END LOOP;
  
    out_p('');
    out_p('Stratasys Confidential' || p_delimiter);
  
  EXCEPTION
  
    WHEN OTHERS THEN
      l_error_message := 'Error in creating Data Cleansing Report ' ||
                         SQLERRM;
      dbms_output.put_line(l_error_message);
    
  END data_cleanse_report;




  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure is used to extract data for Inventory stock locator
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  25/07/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE inv_stock_locator_extract_data(p_errbuf  OUT VARCHAR2
                                          ,p_retcode OUT NUMBER) AS
  
    l_error_message       VARCHAR2(2000); -- mock
    l_err_code            NUMBER;
    l_err_msg             VARCHAR2(2000);
    l_get_org             VARCHAR2(50);
    l_get_concat_segments VARCHAR2(50);
    l_get_sub_inv_name    VARCHAR2(50);
    l_get_row             VARCHAR2(50);
    l_get_rack            VARCHAR2(50);
    l_get_bin             VARCHAR2(50);
  
    CURSOR c_inv_isloc_extract IS
      SELECT DISTINCT mil.inventory_location_id
                     ,(mil.subinventory_code || '.' || mil.segment2 || '.' ||
                      mil.segment3 || '.' || mil.segment4) locator_name
                     ,mil.organization_id
                     ,ood.organization_code
                     ,mil.description
                     ,mil.descriptive_text
                     ,mil.disable_date
                     ,mil.inventory_location_type
                     ,mil.picking_order
                     ,mil.physical_location_code
                     ,mil.location_maximum_units
                     ,mil.subinventory_code
                     ,mil.location_weight_uom_code
                     ,mil.max_weight
                     ,mil.volume_uom_code
                     ,mil.max_cubic_area
                     ,mil.x_coordinate
                     ,mil.y_coordinate
                     ,mil.z_coordinate
                     ,mil.inventory_account_id
                     ,mil.segment1
                     ,mil.segment2
                     ,mil.segment3
                     ,mil.segment4
                     ,mil.segment5
                     ,mil.segment6
                     ,mil.segment7
                     ,mil.segment8
                     ,mil.segment9
                     ,mil.segment10
                     ,mil.segment11
                     ,mil.segment12
                     ,mil.segment13
                     ,mil.segment14
                     ,mil.segment15
                     ,mil.segment16
                     ,mil.segment17
                     ,mil.segment18
                     ,mil.segment19
                     ,mil.segment20
                     ,mil.summary_flag
                     ,mil.enabled_flag
                     ,mil.start_date_active
                     ,mil.end_date_active
                     ,mil.attribute_category
                     ,mil.attribute1
                     ,mil.attribute2
                     ,mil.attribute3
                     ,mil.attribute4
                     ,mil.attribute5
                     ,mil.attribute6
                     ,mil.attribute7
                     ,mil.attribute8
                     ,mil.attribute9
                     ,mil.attribute10
                     ,mil.attribute11
                     ,mil.attribute12
                     ,mil.attribute13
                     ,mil.attribute14
                     ,mil.attribute15
                     ,mil.request_id
                     ,mil.program_application_id
                     ,mil.program_id
                     ,mil.program_update_date
                     ,mil.project_id
                     ,mil.task_id
                     ,mil.physical_location_id
                     ,mil.pick_uom_code
                     ,mil.dimension_uom_code
                     ,mil.length
                     ,mil.width
                     ,mil.height
                     ,mil.locator_status
                     ,mil.status_id
                     ,mil.current_cubic_area
                     ,mil.available_cubic_area
                     ,mil.current_weight
                     ,mil.available_weight
                     ,mil.location_current_units
                     ,mil.location_available_units
                     ,mil.inventory_item_id
                     ,mil.suggested_cubic_area
                     ,mil.suggested_weight
                     ,mil.location_suggested_units
                     ,mil.empty_flag
                     ,mil.mixed_items_flag
                     ,mil.dropping_order
                     ,mil.availability_type
                     ,mil.inventory_atp_code
                     ,mil.reservable_type
                     ,mil.alias
      FROM org_organization_definitions ood
          ,mtl_item_locations           mil
      WHERE ood.organization_id = mil.organization_id
      AND ood.organization_code IN ('UME', 'USE', 'UTP')
      AND mil.enabled_flag = 'Y'
      AND mil.disable_date IS NULL;
    --and mil.attribute2 is not null; -- DUMMY
  
  
    CURSOR c_org_code_transform IS
      SELECT *
      FROM xxobjt.xxs3_ptm_islocator
      WHERE process_flag IN ('Y', 'Q');
  
  BEGIN
  
    --------------------------------- Remove existing data in staging --------------------------------
  
    EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.xxs3_ptm_islocator';
  
    EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.xxs3_ptm_islocator_dq';
  
    -------------------------------- Insert Legacy Data in Staging-----------------------------------
  
    FOR i IN c_inv_isloc_extract
    LOOP
    
      BEGIN
        INSERT INTO xxobjt.xxs3_ptm_islocator
          (xx_inv_stock_locator_id
          ,date_of_extract
          ,process_flag
          ,locator_name
          ,organization_id
          ,organization_code
          ,description
          ,descriptive_text
          ,disable_date
          ,inventory_location_type
          ,picking_order
          ,physical_location_code
          ,location_maximum_units
          ,subinventory_code
          ,location_weight_uom_code
          ,max_weight
          ,volume_uom_code
          ,max_cubic_area
          ,x_coordinate
          ,y_coordinate
          ,z_coordinate
          ,inventory_account_id
          ,segment1
          ,segment2
          ,segment3
          ,segment4
          ,segment5
          ,segment6
          ,segment7
          ,segment8
          ,segment9
          ,segment10
          ,segment11
          ,segment12
          ,segment13
          ,segment14
          ,segment15
          ,segment16
          ,segment17
          ,segment18
          ,segment19
          ,segment20
          ,summary_flag
          ,enabled_flag
          ,start_date_active
          ,end_date_active
          ,attribute_category
          ,attribute1
          ,attribute2
          ,attribute3
          ,attribute4
          ,attribute5
          ,attribute6
          ,attribute7
          ,attribute8
          ,attribute9
          ,attribute10
          ,attribute11
          ,attribute12
          ,attribute13
          ,attribute14
          ,attribute15
          ,request_id
          ,program_application_id
          ,program_id
          ,program_update_date
          ,project_id
          ,task_id
          ,physical_location_id
          ,pick_uom_code
          ,dimension_uom_code
          ,length
          ,width
          ,height
          ,locator_status
          ,status_id
          ,current_cubic_area
          ,available_cubic_area
          ,current_weight
          ,available_weight
          ,location_current_units
          ,location_available_units
          ,inventory_item_id
          ,suggested_cubic_area
          ,suggested_weight
          ,location_suggested_units
          ,empty_flag
          ,mixed_items_flag
          ,dropping_order
          ,availability_type
          ,inventory_atp_code
          ,reservable_type
          ,alias)
        VALUES
          (xxobjt.xxs3_ptm_islocator_seq.NEXTVAL
          ,SYSDATE
          ,'N'
          ,i.locator_name
          ,i.organization_id
          ,i.organization_code
          ,i.description
          ,i.descriptive_text
          ,i.disable_date
          ,i.inventory_location_type
          ,i.picking_order
          ,i.physical_location_code
          ,i.location_maximum_units
          ,i.subinventory_code
          ,i.location_weight_uom_code
          ,i.max_weight
          ,i.volume_uom_code
          ,i.max_cubic_area
          ,i.x_coordinate
          ,i.y_coordinate
          ,i.z_coordinate
          ,i.inventory_account_id
          ,i.segment1
          ,i.segment2
          ,i.segment3
          ,i.segment4
          ,i.segment5
          ,i.segment6
          ,i.segment7
          ,i.segment8
          ,i.segment9
          ,i.segment10
          ,i.segment11
          ,i.segment12
          ,i.segment13
          ,i.segment14
          ,i.segment15
          ,i.segment16
          ,i.segment17
          ,i.segment18
          ,i.segment19
          ,i.segment20
          ,i.summary_flag
          ,i.enabled_flag
          ,i.start_date_active
          ,i.end_date_active
          ,i.attribute_category
          ,i.attribute1
          ,i.attribute2
          ,i.attribute3
          ,i.attribute4
          ,i.attribute5
          ,i.attribute6
          ,i.attribute7
          ,i.attribute8
          ,i.attribute9
          ,i.attribute10
          ,i.attribute11
          ,i.attribute12
          ,i.attribute13
          ,i.attribute14
          ,i.attribute15
          ,i.request_id
          ,i.program_application_id
          ,i.program_id
          ,i.program_update_date
          ,i.project_id
          ,i.task_id
          ,i.physical_location_id
          ,i.pick_uom_code
          ,i.dimension_uom_code
          ,i.length
          ,i.width
          ,i.height
          ,i.locator_status
          ,i.status_id
          ,i.current_cubic_area
          ,i.available_cubic_area
          ,i.current_weight
          ,i.available_weight
          ,i.location_current_units
          ,i.location_available_units
          ,i.inventory_item_id
          ,i.suggested_cubic_area
          ,i.suggested_weight
          ,i.location_suggested_units
          ,i.empty_flag
          ,i.mixed_items_flag
          ,i.dropping_order
          ,i.availability_type
          ,i.inventory_atp_code
          ,i.reservable_type
          ,i.alias);
      
        COMMIT;
      
      EXCEPTION
        WHEN OTHERS THEN
          p_errbuf := 'Error in Inserting into the table ' || SQLERRM;
        
          dbms_output.put_line(p_errbuf);
      END;
    
    END LOOP;
  
    -------------------------------- Cleanse Data-----------------------------------
  
    cleanse_data_isloc(l_err_code, l_err_msg);
  
    -------------------------------- Quality check Data------------------------------
    quality_check_isloc(l_err_code, l_err_msg);
  
    -------------------------------- Transform Data-----------------------------------
  
    FOR j IN c_org_code_transform
    LOOP
    
      /*      IF j.organization_code IS NOT NULL THEN
          xxs3_data_transform_util_pkg.transform(p_mapping_type          => 'inventory_org',
                                                  p_stage_tab             => 'XXOBJT.XXS3_PTM_ISLOCATOR', --Staging Table Name
                                                  p_stage_primary_col     => 'XX_INV_STOCK_LOCATOR_ID', --Staging Table Primary Column Name
                                                  p_stage_primary_col_val => j.xx_inv_stock_locator_id, --Staging Table Primary Column Value
                                                  p_legacy_val            => j.ORGANIZATION_CODE, --Legacy Value
                                                  p_stage_col             => 'S3_ORGANIZATION_CODE', --Staging Table Name
                                                  p_err_code              => l_err_code, -- Output error code
                                                  p_err_msg               => l_err_msg);
        END IF;
      */
      ------------------- transform  subinventory, segments----------
      xxs3_data_transform_util_pkg.ptm_locator_attr2_parse(j.attribute2, l_get_org, l_get_sub_inv_name, l_get_concat_segments, l_get_row, l_get_rack, l_get_bin, l_error_message);
    
      IF l_error_message IS NULL
      THEN
      
        UPDATE xxobjt.xxs3_ptm_islocator
        SET s3_locator_name      = l_get_concat_segments
           ,s3_organization_code = l_get_org
           ,s3_subinventory_code = l_get_sub_inv_name
           ,s3_segment1          = l_get_row
           ,s3_segment2          = l_get_rack
           ,s3_segment3          = l_get_bin
           ,transform_status     = 'PASS'
        WHERE xx_inv_stock_locator_id = j.xx_inv_stock_locator_id;
      
      ELSE
      
        UPDATE xxobjt.xxs3_ptm_islocator
        SET s3_locator_name      = l_get_concat_segments
           ,s3_organization_code = l_get_org
           ,s3_subinventory_code = l_get_sub_inv_name
           ,s3_segment1          = l_get_row
           ,s3_segment2          = l_get_rack
           ,s3_segment3          = l_get_bin
           ,transform_status     = 'FAIL'
           ,transform_error      = l_error_message
        WHERE xx_inv_stock_locator_id = j.xx_inv_stock_locator_id;
      
      END IF;
    
    END LOOP;
  
    -------------------------------- Report Data-----------------------------------
  
    /*    subinv_report_data('INVENTORY STOCK LOCATOR', l_err_code, l_err_msg);*/
  
  END inv_stock_locator_extract_data;




  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used for Inventory Stocl Locator Data Quality Report
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  29/07/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------


  PROCEDURE dq_report_islocator(p_entity VARCHAR2) IS
  
    CURSOR c_dq_report_islocator IS
      SELECT nvl(xpisdl.rule_name, ' ') rule_name
            ,nvl(xpisdl.notes, ' ') notes
            ,xpisl.xx_inv_stock_locator_id
            ,xpisl.organization_code
            ,xpisl.locator_name
            ,xpisl.attribute2
            ,decode(xpisl.process_flag, 'R', 'Y', 'Q', 'N') reject_record
      FROM xxs3_ptm_islocator    xpisl
          ,xxs3_ptm_islocator_dq xpisdl
      WHERE xpisl.xx_inv_stock_locator_id = xpisdl.xx_inv_stock_locator_id
      AND xpisl.process_flag IN ('Q', 'R');
  
    p_delimiter    VARCHAR2(5) := '~';
    l_err_msg      VARCHAR2(2000);
    l_count_dq     NUMBER;
    l_count_reject NUMBER;
  
  BEGIN
  
    SELECT COUNT(1)
    INTO l_count_dq
    FROM xxs3_ptm_islocator xpisl
    WHERE xpisl.process_flag IN ('Q', 'R');
  
    SELECT COUNT(1)
    INTO l_count_reject
    FROM xxs3_ptm_islocator xpisl
    WHERE xpisl.process_flag = 'R';
  
  
  
    out_p(rpad('Report name = Data Quality Error Report' || p_delimiter, 100, ' '));
    out_p(rpad('========================================' || p_delimiter, 100, ' '));
    out_p(rpad('Data Migration Object Name = ' || p_entity || p_delimiter, 100, ' '));
    out_p('');
    out_p(rpad('Run date and time:    ' ||
               to_char(SYSDATE, 'dd-Mon-YYYY HH24:MI') || p_delimiter, 100, ' '));
    out_p(rpad('Total Record Count Having DQ Issues = ' || l_count_dq ||
               p_delimiter, 100, ' '));
    out_p(rpad('Total Record Count Rejected =  ' || l_count_reject ||
               p_delimiter, 100, ' '));
  
    out_p('');
  
    out_p(rpad('Track Name', 10, ' ') || p_delimiter ||
          rpad('Entity Name', 11, ' ') || p_delimiter ||
          rpad('XX INV STOCK LOCATOR ID  ', 25, ' ') || p_delimiter ||
          rpad('ORGANIZATION CODE', 15, ' ') || p_delimiter ||
          rpad('LOCATOR NAME', 30, ' ') || p_delimiter ||
          rpad('ATTRIBUTE2', 30, ' ') || p_delimiter ||
          rpad('Reject Record Flag(Y/N)', 22, ' ') || p_delimiter ||
          rpad('Rule Name', 45, ' ') || p_delimiter ||
          rpad('Reason Code', 50, ' '));
  
  
  
    FOR r_data IN c_dq_report_islocator
    LOOP
      out_p(rpad('PTM', 10, ' ') || p_delimiter ||
            rpad('ISLOCATOR', 11, ' ') || p_delimiter ||
            rpad(r_data.xx_inv_stock_locator_id, 25, ' ') || p_delimiter ||
            rpad(r_data.organization_code, 15, ' ') || p_delimiter ||
            rpad(r_data.locator_name, 30, ' ') || p_delimiter ||
            rpad(r_data.attribute2, 30, ' ') || p_delimiter ||
            rpad(r_data.reject_record, 22, ' ') || p_delimiter ||
            rpad(nvl(r_data.rule_name, 'NULL'), 45, ' ') || p_delimiter ||
            rpad(nvl(r_data.notes, 'NULL'), 50, ' '));
    
    END LOOP;
  
    out_p('');
    out_p('Stratasys Confidential' || p_delimiter);
  
  END dq_report_islocator;




  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure is used to create data transformation report for Inventory stock locator
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  25/07/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE data_transform_report(p_entity VARCHAR2) AS
  
    l_status        VARCHAR2(10) := 'SUCCESS';
    l_check_rule    VARCHAR2(10) := 'TRUE';
    l_error_message VARCHAR2(2000);
    l_err_msg       VARCHAR2(2000);
    l_count_success NUMBER;
    l_count_fail    NUMBER;
  
    p_delimiter VARCHAR2(5) := '~';
  
    CURSOR c_trans_report_isloc IS
      SELECT xisl.xx_inv_stock_locator_id
            ,xisl.organization_code
            ,xisl.s3_organization_code
            ,xisl.subinventory_code
            ,xisl.s3_subinventory_code
            ,xisl.segment1
            ,xisl.s3_segment1
            ,xisl.segment2
            ,xisl.s3_segment2
            ,xisl.segment3
            ,xisl.s3_segment3
            ,xisl.attribute2
            ,xisl.s3_attribute2
            ,xisl.transform_status
            ,xisl.transform_error
      FROM xxobjt.xxs3_ptm_islocator xisl
      WHERE xisl.transform_status IN ('PASS', 'FAIL');
  
  BEGIN
  
    SELECT COUNT(1)
    INTO l_count_success
    FROM xxobjt.xxs3_ptm_islocator xisl
    WHERE xisl.transform_status = 'PASS';
  
    SELECT COUNT(1)
    INTO l_count_fail
    FROM xxobjt.xxs3_ptm_islocator xisl
    WHERE xisl.transform_status = 'FAIL';
  
    out_p(rpad('Report name = Data Transformation Report' || p_delimiter, 100, ' '));
    out_p(rpad('========================================' || p_delimiter, 100, ' '));
    out_p(rpad('Data Migration Object Name = ' || p_entity || p_delimiter, 100, ' '));
    out_p('');
    out_p(rpad('Run date and time:    ' ||
               to_char(SYSDATE, 'dd-Mon-YYYY HH24:MI') || p_delimiter, 100, ' '));
    out_p(rpad('Total Record Count Success = ' || l_count_success ||
               p_delimiter, 100, ' '));
    out_p(rpad('Total Record Count Failure = ' || l_count_fail ||
               p_delimiter, 100, ' '));
  
    out_p('');
  
    out_p(rpad('Track Name', 10, ' ') || p_delimiter ||
          rpad('Entity Name', 11, ' ') || p_delimiter ||
          rpad('XX INV STOCK LOCATOR ID  ', 14, ' ') || p_delimiter ||
          rpad('Organization Code', 240, ' ') || p_delimiter ||
          rpad('S3 Organization Code', 30, ' ') || p_delimiter ||
          rpad('Subinventory Code', 30, ' ') || p_delimiter ||
          rpad('S3 Subinventory Code', 30, ' ') || p_delimiter ||
          rpad('Segment1 - Row', 30, ' ') || p_delimiter ||
          rpad('S3 Segment1 - Row', 30, ' ') || p_delimiter ||
          rpad('Segment2 - Rack', 30, ' ') || p_delimiter ||
          rpad('S3 Segment2 - Rack', 30, ' ') || p_delimiter ||
          rpad('Segment3 - Bin', 30, ' ') || p_delimiter ||
          rpad('S3 Segment3 - Bin', 30, ' ') || p_delimiter ||
          rpad('Locator DFF - Attribute2', 30, ' ') || p_delimiter ||
          rpad('S3 Locator DFF - Attribute2', 30, ' ') || p_delimiter ||
          rpad('Status', 10, ' ') || p_delimiter ||
          rpad('Error Message', 200, ' '));
  
    FOR r_data IN c_trans_report_isloc
    LOOP
      out_p(rpad('INV', 10, ' ') || p_delimiter ||
            rpad('LOCATOR', 11, ' ') || p_delimiter ||
            rpad(r_data.xx_inv_stock_locator_id, 14, ' ') || p_delimiter ||
            rpad(r_data.organization_code, 10, ' ') || p_delimiter ||
            rpad(r_data.s3_organization_code, 240, ' ') || p_delimiter ||
            rpad(r_data.subinventory_code, 30, ' ') || p_delimiter ||
            rpad(r_data.s3_subinventory_code, 30, ' ') || p_delimiter ||
            rpad(r_data.segment1, 30, ' ') || p_delimiter ||
            rpad(r_data.s3_segment1, 30, ' ') || p_delimiter ||
            rpad(r_data.segment2, 30, ' ') || p_delimiter ||
            rpad(r_data.s3_segment2, 30, ' ') || p_delimiter ||
            rpad(r_data.segment3, 30, ' ') || p_delimiter ||
            rpad(r_data.s3_segment3, 30, ' ') || p_delimiter ||
            rpad(r_data.attribute2, 30, ' ') || p_delimiter ||
            rpad(r_data.s3_attribute2, 30, ' ') || p_delimiter || -- need toc change
            rpad(r_data.transform_status, 10, ' ') || p_delimiter ||
            rpad(nvl(r_data.transform_error, 'NULL'), 200, ' '));
    
    END LOOP;
  
    out_p('');
    out_p('Stratasys Confidential' || p_delimiter);
  
  EXCEPTION
  
    WHEN OTHERS THEN
      l_error_message := 'Error in Data creating Data Transform Report ' ||
                         SQLERRM;
      dbms_output.put_line(l_error_message);
    
  END data_transform_report;

END xxs3_ptm_islocator_pkg;
/
