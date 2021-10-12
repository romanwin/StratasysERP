CREATE OR REPLACE PACKAGE xxs3_ptm_onh_inventories_pkg

-- --------------------------------------------------------------------------------------------
-- Purpose: This Package is used for Onhand Inventories Extract, Quality Check and Report
--
-- --------------------------------------------------------------------------------------------
-- Ver  Date        Name                          Description
-- 1.0  29/07/2016  TCS                           Initial build
-- --------------------------------------------------------------------------------------------

 AS

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used for  Onhand Inventories Extract
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  29/07/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE onh_inventories_extract_data(x_errbuf  OUT VARCHAR2,
                                         x_retcode OUT NUMBER);

  PROCEDURE quality_check_onh_inventories(p_err_code OUT VARCHAR2,
                                          p_err_msg  OUT VARCHAR2);
END xxs3_ptm_onh_inventories_pkg;
/
CREATE OR REPLACE PACKAGE BODY xxs3_ptm_onh_inventories_pkg AS

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure is used to write in concurrent log
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  29/07/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE log_p(p_msg VARCHAR2) IS
  BEGIN
  
    fnd_file.put_line(fnd_file.log, p_msg);
    /*dbms_output.put_line(i_msg);*/
  
  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log,
                        'Error in writing Log File. ' || SQLERRM);
  END log_p;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure is used to write in concurrent output
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  29/07/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE out_p(p_msg VARCHAR2) IS
  BEGIN
  
    fnd_file.put_line(fnd_file.output, p_msg);
    /*dbms_output.put_line(p_msg);*/
  
  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log,
                        'Error in writting Output File. ' || SQLERRM);
  END out_p;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used for  Onhand Inventories Data Quality Report
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  29/07/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE onh_inv_report_data(p_entity_name IN VARCHAR2,
                                p_err_code    OUT VARCHAR2,
                                p_err_msg     OUT VARCHAR2) AS
  
    p_delimiter VARCHAR2(5) := '~';
    CURSOR c_report IS
      SELECT xod.*
        FROM XXS3_PTM_ONH_INVENTORY xoi, XXS3_PTM_ONH_INVENTORY_DQ xod
       WHERE xoi.xx_onh_inv_id = xod.xx_onh_inv_id
         AND xoi.process_flag IN ('Q', 'R')
       ORDER BY 1;
  
  BEGIN
  
    out_p(rpad('On Hand Inventory DQ status report', 100, ' '));
    out_p(rpad('==================================', 100, ' '));
    out_p('');
    out_p('Date:    ' || to_char(SYSDATE, 'dd-Mon-YYYY HH24:MI'));
  
    out_p('');
  
    out_p(rpad('Track Name', 15, ' ') || p_delimiter ||
          rpad('Entity Name', 20, ' ') || p_delimiter ||
          rpad('XX ONH INV ID  ', 15, ' ') || p_delimiter ||
          rpad('Rule Name', 50, ' ') || p_delimiter ||
          rpad('Reason Code', 50, ' '));
  
    FOR i IN c_report LOOP
      out_p(rpad('PTM', 15, ' ') || p_delimiter ||
            rpad('ON HAND INVENTORY', 20, ' ') || p_delimiter ||
            rpad(i.xx_onh_inv_id, 15, ' ') || p_delimiter ||
            rpad(i.rule_name, 50, ' ') || p_delimiter ||
            rpad(i.notes, 50, ' '));
    END LOOP;
    p_err_code := '0';
    p_err_msg  := '';
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code := '2';
      p_err_msg  := 'SQLERRM: ' || SQLERRM;
      log_p('Failed to generate report: ' || SQLERRM);
  END onh_inv_report_data;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used for Subinventories Data Quality Report Rules
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  29/07/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE insert_update_onh_inv_dq(p_xx_onhinv_id NUMBER,
                                     p_rule_name    IN VARCHAR2,
                                     p_reject_code  IN VARCHAR2,
                                     p_err_code     OUT VARCHAR2,
                                     p_err_msg      OUT VARCHAR2) IS
  
  BEGIN
  
    UPDATE xxobjt.XXS3_PTM_ONH_INVENTORY
       SET process_flag = 'Q'
     WHERE xx_onh_inv_id = p_xx_onhinv_id;
  
    INSERT INTO XXS3_PTM_ONH_INVENTORY_DQ
      (xx_dq_onh_inv_id, xx_onh_inv_id, rule_name, notes)
    VALUES
      (xxobjt.xxs3_ptm_onh_inv_dq_seq.NEXTVAL,
       p_xx_onhinv_id,
       p_rule_name,
       p_reject_code);
  
    p_err_code := '0';
    p_err_msg  := '';
  
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code := '2';
      p_err_msg  := 'SQLERRM: ' || SQLERRM;
      ROLLBACK;
    
  END insert_update_onh_inv_dq;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure is used for Approved Suppliers Transform Report
  --           
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  29/07/2016  TCS                           Initial build  
  -- --------------------------------------------------------------------------------------------

  PROCEDURE data_transform_report(p_entity VARCHAR2) IS
  
    p_delimiter     VARCHAR2(5) := '~';
    l_err_msg       VARCHAR2(2000);
    l_count_success NUMBER;
    l_count_fail    NUMBER;
  
    CURSOR c_report_onhinv IS
      SELECT xon.xx_onh_inv_id,
             xon.organization_id,
             xon.organization_code,
             xon.s3_organization_code,
             xon.subinventory_code,
             xon.s3_subinventory_code,
             xon.locator_type,
             xon.s3_locator_type,
             xon.serial_number_control_code,
             xon.s3_serial_number_control_code,
             xon.shelf_life_code,
             xon.s3_shelf_life_code,
             xon.transform_status,
             xon.transform_error
        FROM XXS3_PTM_ONH_INVENTORY xon
       WHERE xon.transform_status IN ('PASS', 'FAIL');
  
  BEGIN
  
    SELECT COUNT(1)
      INTO l_count_success
      FROM XXS3_PTM_ONH_INVENTORY xps
     WHERE xps.transform_status = 'PASS';
  
    SELECT COUNT(1)
      INTO l_count_fail
      FROM XXS3_PTM_ONH_INVENTORY xps
     WHERE xps.transform_status = 'FAIL';
  
    out_p(rpad('Report name = Data Transformation Report' || p_delimiter,
               100,
               ' '));
    out_p(rpad('========================================' || p_delimiter,
               100,
               ' '));
    out_p(rpad('Data Migration Object Name = ' || p_entity || p_delimiter,
               100,
               ' '));
    out_p('');
    out_p(rpad('Run date and time:    ' ||
               to_char(SYSDATE, 'dd-Mon-YYYY HH24:MI') || p_delimiter,
               100,
               ' '));
    out_p(rpad('Total Record Count Success = ' || l_count_success ||
               p_delimiter,
               100,
               ' '));
    out_p(rpad('Total Record Count Failure = ' || l_count_fail ||
               p_delimiter,
               100,
               ' '));
  
    out_p('');
  
    out_p(rpad('Track Name', 10, ' ') || p_delimiter ||
          rpad('Entity Name', 11, ' ') || p_delimiter ||
          rpad('XX ONH INV ID  ', 14, ' ') || p_delimiter ||
          rpad('Organization Code', 240, ' ') || p_delimiter ||
          rpad('S3 Organization Code', 30, ' ') || p_delimiter ||
          rpad('Subinventory Code', 240, ' ') || p_delimiter ||
          rpad('S3 Subinventory Code', 30, ' ') || p_delimiter ||
          rpad('Locator Type', 240, ' ') || p_delimiter ||
          rpad('S3 Locator Type', 30, ' ') || p_delimiter ||
          rpad('Serial Number Control Code', 240, ' ') || p_delimiter ||
          rpad('S3 Serial Number Control Code', 30, ' ') || p_delimiter ||
          rpad('Shelf life Code', 240, ' ') || p_delimiter ||
          rpad('S3 Shelf life Code', 30, ' ') || p_delimiter ||
          rpad('Status', 10, ' ') || p_delimiter ||
          rpad('Error Message', 200, ' '));
  
    FOR r_data IN c_report_onhinv LOOP
      out_p(rpad('PTM', 10, ' ') || p_delimiter ||
            rpad('ON-HAND INVENTORY', 11, ' ') || p_delimiter ||
            rpad(r_data.xx_onh_inv_id, 14, ' ') || p_delimiter ||
            rpad(r_data.organization_code, 240, ' ') || p_delimiter ||
            rpad(r_data.s3_organization_code, 30, ' ') || p_delimiter ||
            rpad(r_data.subinventory_code, 240, ' ') || p_delimiter ||
            rpad(r_data.s3_subinventory_code, 30, ' ') || p_delimiter ||
            rpad(r_data.locator_type, 240, ' ') || p_delimiter ||
            rpad(r_data.s3_locator_type, 30, ' ') || p_delimiter ||
            rpad(r_data.serial_number_control_code, 240, ' ') ||
            p_delimiter ||
            rpad(r_data.s3_serial_number_control_code, 30, ' ') ||
            p_delimiter || rpad(r_data.shelf_life_code, 240, ' ') ||
            p_delimiter || rpad(r_data.s3_shelf_life_code, 30, ' ') ||
            p_delimiter || rpad(r_data.transform_status, 10, ' ') ||
            p_delimiter ||
            rpad(nvl(r_data.transform_error, 'NULL'), 200, ' '));
    END LOOP;
  
    fnd_file.put_line(fnd_file.output, '');
    fnd_file.put_line(fnd_file.output,
                      'Stratasys Confidential' || p_delimiter);
  END;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used to cleanse Transaction date
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE cleanse_trx_date(p_xx_onh_inv_id    NUMBER,
                             p_transaction_date DATE) IS
  
    l_count       NUMBER := 0;
    l_err_message VARCHAR2(1000);
  BEGIN
    IF p_transaction_date IS NULL THEN
    
      BEGIN
        UPDATE xxobjt.XXS3_PTM_ONH_INVENTORY
           SET s3_transaction_date = sysdate,
               cleanse_status      = cleanse_status ||
                                     ' TRANSACTION_DATE :PASS, '
         WHERE xx_onh_inv_id = p_xx_onh_inv_id;
      EXCEPTION
        WHEN OTHERS THEN
          l_err_message := SQLERRM;
          UPDATE xxobjt.XXS3_PTM_ONH_INVENTORY
             SET cleanse_status = cleanse_status ||
                                  ' TRANSACTION_DATE :FAIL, ',
                 cleanse_error  = cleanse_error || ' TRANSACTION_DATE :' ||
                                  l_err_message || ' ,'
           WHERE xx_onh_inv_id = p_xx_onh_inv_id;
      END;
    END IF;
  END;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used to cleanse Transaction date
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE cleanse_trx_type(p_xx_onh_inv_id    NUMBER,
                             p_transaction_type VARCHAR2) IS
    l_count       NUMBER := 0;
    l_err_message VARCHAR2(1000);
  BEGIN
    IF p_transaction_type != 'Miscellaneous receipt' OR
       p_transaction_type IS NULL THEN
    
      BEGIN
        UPDATE xxobjt.XXS3_PTM_ONH_INVENTORY
           SET s3_transaction_type_name = 'Miscellaneous receipt',
               cleanse_status           = cleanse_status ||
                                          ' TRANSACTION_TYPE :PASS, '
         WHERE xx_onh_inv_id = p_xx_onh_inv_id;
      EXCEPTION
        WHEN OTHERS THEN
          l_err_message := SQLERRM;
          UPDATE xxobjt.XXS3_PTM_ONH_INVENTORY
             SET cleanse_status = cleanse_status ||
                                  ' TRANSACTION_TYPE_NAME :FAIL, ',
                 cleanse_error  = cleanse_error ||
                                  ' TRANSACTION_TYPE_NAME :' ||
                                  l_err_message || ' ,'
           WHERE xx_onh_inv_id = p_xx_onh_inv_id;
      END;
    END IF;
  END;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used to cleanse Transaction date
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE cleanse_source_code(p_xx_onh_inv_id NUMBER,
                                p_source_code   VARCHAR2) IS
    l_count       NUMBER := 0;
    l_err_message VARCHAR2(1000);
  BEGIN
    IF p_source_code != 'Inventory' or p_source_code IS NULL THEN
    
      BEGIN
        UPDATE xxobjt.XXS3_PTM_ONH_INVENTORY
           SET s3_source_code = 'Inventory',
               cleanse_status = cleanse_status || ' SOURCE_CODE :PASS, '
         WHERE xx_onh_inv_id = p_xx_onh_inv_id;
      EXCEPTION
        WHEN OTHERS THEN
          l_err_message := SQLERRM;
          UPDATE xxobjt.XXS3_PTM_ONH_INVENTORY
             SET cleanse_status = cleanse_status || ' SOURCE_CODE :FAIL, ',
                 cleanse_error  = cleanse_error || ' SOURCE_CODE :' ||
                                  l_err_message || ' ,'
           WHERE xx_onh_inv_id = p_xx_onh_inv_id;
      END;
    END IF;
  END;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used for Subinventories Data Quality Rules Check
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  29/07/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE cleanse_onh_inv(p_err_code OUT VARCHAR2,
                            p_err_msg  OUT VARCHAR2) IS
    l_status     VARCHAR2(10) := 'SUCCESS';
    l_check_rule VARCHAR2(10) := 'TRUE';
    CURSOR cur_onh IS
      SELECT * FROM xxobjt.XXS3_PTM_ONH_INVENTORY;
  BEGIN
    FOR i IN cur_onh LOOP
    
      cleanse_trx_date(i.xx_onh_inv_id, i.S3_TRANSACTION_DATE);
    
      cleanse_trx_type(i.xx_onh_inv_id, i.S3_TRANSACTION_TYPE_NAME);
    
      cleanse_source_code(i.xx_onh_inv_id, i.S3_SOURCE_CODE);
    
    END LOOP;
    COMMIT;
  END;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used for Subinventories Data Quality Rules Check
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  29/07/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE quality_check_onh_inventories(p_err_code OUT VARCHAR2,
                                          p_err_msg  OUT VARCHAR2) IS
    l_status              VARCHAR2(10) := 'SUCCESS';
    l_check_rule          VARCHAR2(10) := 'TRUE';
    l_get_org             VARCHAR2(50);
    l_get_sub_inv_name    VARCHAR2(50);
    l_get_concat_segments VARCHAR2(50);
    l_get_row             VARCHAR2(50);
    l_get_rack            VARCHAR2(50);
    l_get_bin             VARCHAR2(50);
    l_error_message       VARCHAR2(2000);
  
    CURSOR cur_ohinv IS
      SELECT onh.*
        FROM XXS3_PTM_ONH_INVENTORY onh
       WHERE process_flag = 'N';
  BEGIN
    FOR i IN cur_ohinv LOOP
    
      l_status := 'SUCCESS';
    
      --S3_ORGANIZATION_CODE
    
      IF xxs3_dq_util_pkg.eqt_030(i.organization_code) THEN
        --- change to S3_ORGANIZATION_CODE
        insert_update_onh_inv_dq(i.xx_onh_inv_id,
                                 'EQT_030:Should be NULL',
                                 'S3_ORGANIZATION_CODE Should be NULL',
                                 p_err_code,
                                 p_err_msg);
        l_status := 'ERR';
      END IF;
    
      --S3_SUBINVENTORY_CODE 
      IF xxs3_dq_util_pkg.eqt_030(i.subinventory_code) THEN
        --- change to S3_SUBINVENTORY_CODE
        insert_update_onh_inv_dq(i.xx_onh_inv_id,
                                 'EQT_030:Should be NULL',
                                 'S3_SUBINVENTORY_CODE Should be NULL',
                                 p_err_code,
                                 p_err_msg);
        l_status := 'ERR';
      
      END IF;
    
      --S3_STOCK_LOCATOR and 
      xxs3_data_transform_util_pkg2.ptm_locator_attr2_parse(i.LOC_ATTRIBUTE2,
                                                            l_get_org,
                                                            l_get_sub_inv_name,
                                                            l_get_concat_segments,
                                                            l_get_row,
                                                            l_get_rack,
                                                            l_get_bin,
                                                            l_error_message);
    
      l_check_rule := xxs3_dq_util_pkg.eqt_170(l_get_concat_segments,
                                               i.serial_number_control_code);
    
      IF l_check_rule = 'TRUE' THEN
        --- change to S3_STOCK_LOCATOR
        insert_update_onh_inv_dq(i.xx_onh_inv_id,
                                 'EQT_170:Stock locator required if SN',
                                 'Stock locator required if SN',
                                 p_err_code,
                                 p_err_msg);
        l_status := 'ERR';
      
      END IF;
    
      --S3_SEGMENT1 
    
      IF l_check_rule = 'FALSE' THEN
        --- change to S3_SEGMENT1
        insert_update_onh_inv_dq(i.xx_onh_inv_id,
                                 'EQT_171:Inventory On-Hand Exists without Item Master',
                                 'Inventory On-Hand Exists without Item Master',
                                 p_err_code,
                                 p_err_msg);
        l_status := 'ERR';
      
      END IF;
    
      IF l_status <> 'ERR' THEN
        UPDATE xxobjt.XXS3_PTM_ONH_INVENTORY
           SET process_flag = 'Y'
         WHERE xx_onh_inv_id = i.xx_onh_inv_id;
      END IF;
    END LOOP;
  
  END quality_check_onh_inventories;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used for On Hand inventories Extract
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  29/07/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE onh_inventories_extract_data(x_errbuf  OUT VARCHAR2,
                                         x_retcode OUT NUMBER) AS
    l_err_code            NUMBER;
    l_err_msg             VARCHAR2(100);
    l_count_subinv        VARCHAR2(2);
    l_get_org             VARCHAR2(50);
    l_get_sub_inv_name    VARCHAR2(50);
    l_get_concat_segments VARCHAR2(50);
    l_get_row             VARCHAR2(50);
    l_get_rack            VARCHAR2(50);
    l_get_bin             VARCHAR2(50);
    l_error_message       VARCHAR2(2000);
  
    cursor cur_onh_inv_transform is
      SELECT onh.*
        FROM xxobjt.XXS3_PTM_ONH_INVENTORY onh
       WHERE process_flag IN ('Y', 'Q');
  
    cursor cur_onh_inv_insert is
    -- serial control
      select items.inventory_item_id,
             items.segment1,
             items.organization_id,
             (select organization_code
                from org_organization_definitions
               where organization_id = items.organization_id) organization_code,
             items.subinventory_code,
             items.revision,
             items.serial_number_control_code,
             items.shelf_life_code,
             items.locator_id,
             (select attribute2
                from mtl_item_locations
               where inventory_location_id = items.locator_id
                 and organization_id = items.organization_id
                 and subinventory_code = items.subinventory_code) loc_attribute2,
             items.locator_type,
             (select concatenated_segments
                from mtl_item_locations_kfv
               where inventory_location_id = items.locator_id
                 and organization_id = items.organization_id
                 and subinventory_code = items.subinventory_code) concatenated_segments,
             calculate_onh_quant(items.organization_id,
                                 items.INVENTORY_ITEM_ID,
                                 items.SUBINVENTORY_CODE,
                                 items.serial_number_control_code,
                                 items.lot_control_code,
                                 items.lot_number,
                                 items.locator_id) primary_transaction_quantity,
             items.transaction_uom_code,
             items.lot_number,
             (select expiration_date
                from mtl_lot_numbers
               where lot_number = items.lot_number
                 and inventory_item_id = items.inventory_item_id
                 and organization_id = items.organization_id) expiration_date,
             msn.serial_number
        from mtl_serial_numbers msn,
             (select distinct (moq.inventory_item_id),
                              msib.segment1,
                              msib.lot_control_code,
                              moq.lot_number,
                              msib.serial_number_control_code,
                              msib.shelf_life_code,
                              moq.locator_id,
                              moq.subinventory_code,
                              moq.organization_id,
                              moq.revision,
                              moq.transaction_uom_code,
                              -- moq.primary_transaction_quantity, removed 18 aug
                              siv.locator_type
                from mtl_system_items_b           msib,
                     mtl_onhand_quantities_detail moq,
                     mtl_secondary_inventories    siv
               where moq.inventory_item_id = msib.inventory_item_id
                 and moq.organization_id = msib.organization_id
                 and siv.secondary_inventory_name = moq.subinventory_code
                 and siv.organization_id = moq.organization_id
                 and moq.organization_id in (739, 740, 741, 742)) items
       where items.serial_number_control_code <> 1
         and items.lot_control_code = 1
         and items.inventory_item_id = msn.inventory_item_id
         and msn.current_organization_id = items.organization_id
            --   and msn.current_subinventory_code = items.subinventory_code
         and msn.current_locator_id = items.locator_id -- added 18 Aug 
         and msn.current_status = 3
      
      union all -- lot control
      select distinct items.inventory_item_id,
                      items.segment1,
                      items.organization_id,
                      (select organization_code
                         from org_organization_definitions
                        where organization_id = items.organization_id) organization_code,
                      items.subinventory_code,
                      items.revision,
                      items.serial_number_control_code,
                      items.shelf_life_code,
                      items.locator_id,
                      (select attribute2
                         from mtl_item_locations
                        where inventory_location_id = items.locator_id
                          and organization_id = items.organization_id
                          and subinventory_code = items.subinventory_code) loc_attribute2,
                      items.locator_type,
                      (select concatenated_segments
                         from mtl_item_locations_kfv
                        where inventory_location_id = items.locator_id
                          and organization_id = items.organization_id
                          and subinventory_code = items.subinventory_code) concatenated_segments,
                      calculate_onh_quant(items.organization_id,
                                          items.INVENTORY_ITEM_ID,
                                          items.SUBINVENTORY_CODE,
                                          items.serial_number_control_code,
                                          items.lot_control_code,
                                          items.lot_number,
                                          items.locator_id) primary_transaction_quantity,
                      items.transaction_uom_code,
                      items.lot_number,
                      (select expiration_date
                         from mtl_lot_numbers
                        where lot_number = items.lot_number
                          and inventory_item_id = items.inventory_item_id
                          and organization_id = items.organization_id) expiration_date,
                      '' serial_number
        from mtl_lot_numbers mln,
             (select distinct (moq.inventory_item_id),
                              msib.segment1,
                              msib.lot_control_code,
                              moq.lot_number,
                              msib.serial_number_control_code,
                              msib.shelf_life_code,
                              moq.locator_id,
                              moq.subinventory_code,
                              moq.organization_id,
                              moq.revision,
                              moq.transaction_uom_code,
                              -- moq.primary_transaction_quantity,
                              siv.locator_type
                from mtl_system_items_b           msib,
                     mtl_onhand_quantities_detail moq,
                     mtl_secondary_inventories    siv
               where moq.inventory_item_id = msib.inventory_item_id
                 and moq.organization_id = msib.organization_id
                 and siv.secondary_inventory_name = moq.subinventory_code
                 and siv.organization_id = moq.organization_id
                 and moq.organization_id in (739, 740, 741, 742)) items
       where items.serial_number_control_code = 1
         and items.lot_control_code = 2
         and items.inventory_item_id = mln.inventory_item_id
         and items.organization_id = mln.organization_id
         and items.lot_number = mln.lot_number
      
      union all -- no control
      select distinct items.inventory_item_id,
                      items.segment1,
                      items.organization_id,
                      (select organization_code
                         from org_organization_definitions
                        where organization_id = items.organization_id) organization_code,
                      items.subinventory_code,
                      items.revision,
                      items.serial_number_control_code,
                      items.shelf_life_code,
                      items.locator_id,
                      (select attribute2
                         from mtl_item_locations
                        where inventory_location_id = items.locator_id
                          and organization_id = items.organization_id
                          and subinventory_code = items.subinventory_code) loc_attribute2,
                      items.locator_type,
                      (select concatenated_segments
                         from mtl_item_locations_kfv
                        where inventory_location_id = items.locator_id
                          and organization_id = items.organization_id
                          and subinventory_code = items.subinventory_code) concatenated_segments,
                      calculate_onh_quant(items.organization_id,
                                          items.INVENTORY_ITEM_ID,
                                          items.SUBINVENTORY_CODE,
                                          items.serial_number_control_code,
                                          items.lot_control_code,
                                          items.lot_number,
                                          items.locator_id) primary_transaction_quantity,
                      items.transaction_uom_code,
                      items.lot_number,
                      (select expiration_date
                         from mtl_lot_numbers
                        where lot_number = items.lot_number
                          and inventory_item_id = items.inventory_item_id
                          and organization_id = items.organization_id) expiration_date,
                      '' serial_number
        from (select distinct (moq.inventory_item_id),
                              msib.segment1,
                              msib.lot_control_code,
                              moq.lot_number,
                              msib.serial_number_control_code,
                              msib.shelf_life_code,
                              moq.locator_id,
                              moq.subinventory_code,
                              moq.organization_id,
                              moq.revision,
                              moq.transaction_uom_code,
                              --   moq.primary_transaction_quantity,
                              siv.locator_type
                from mtl_system_items_b           msib,
                     mtl_onhand_quantities_detail moq,
                     mtl_secondary_inventories    siv
               where moq.inventory_item_id = msib.inventory_item_id
                 and moq.organization_id = msib.organization_id
                 and siv.secondary_inventory_name = moq.subinventory_code
                 and siv.organization_id = moq.organization_id
                 and moq.organization_id in (739, 740, 741, 742)) items
       where items.serial_number_control_code = 1
         and items.lot_control_code = 1;
  
    ----------------------------------------------
  
  BEGIN
  
    DELETE FROM xxobjt.XXS3_PTM_ONH_INVENTORY;
  
    DELETE FROM xxobjt.XXS3_PTM_ONH_INVENTORY_DQ;
  
    for i in cur_onh_inv_insert loop
      insert into XXS3_PTM_ONH_INVENTORY
        (xx_onh_inv_id,
         date_of_extract,
         process_flag,
         INVENTORY_ITEM_ID,
         ITEM_SEGMENT1,
         ORGANIZATION_ID,
         ORGANIZATION_CODE,
         SUBINVENTORY_CODE,
         REVISION,
         SERIAL_NUMBER_CONTROL_CODE,
         SHELF_LIFE_CODE,
         LOCATOR_ID,
         LOC_ATTRIBUTE2,
         LOCATOR_TYPE,
         CONCATENATED_SEGMENTS,
         PRIMARY_TRANSACTION_QUANTITY,
         TRANSACTION_UOM_CODE,
         LOT_NUMBER,
         EXPIRATION_DATE,
         SERIAL_NUMBER)
      values
        (xxobjt.xxs3_ptm_onh_inventory_seq.NEXTVAL,
         sysdate,
         'N',
         i.INVENTORY_ITEM_ID,
         i.SEGMENT1,
         i.ORGANIZATION_ID,
         i.ORGANIZATION_CODE,
         i.SUBINVENTORY_CODE,
         i.REVISION,
         i.SERIAL_NUMBER_CONTROL_CODE,
         i.SHELF_LIFE_CODE,
         i.LOCATOR_ID,
         i.LOC_ATTRIBUTE2,
         i.LOCATOR_TYPE,
         i.CONCATENATED_SEGMENTS,
         i.PRIMARY_TRANSACTION_QUANTITY,
         i.TRANSACTION_UOM_CODE,
         i.LOT_NUMBER,
         i.EXPIRATION_DATE,
         i.SERIAL_NUMBER);
    end loop;
    ----------- Cleanse ------------
    cleanse_onh_inv(l_err_code, l_err_msg);
  
    ----------- Quality ------------
  
    quality_check_onh_inventories(l_err_code, l_err_msg);
  
    ------------------- transform  subinventory, segments----------
  
    FOR j IN cur_onh_inv_transform LOOP
    
      /* Source Organization code transformation */
      IF j.organization_code IS NOT NULL THEN
        xxs3_data_transform_util_pkg.transform(p_mapping_type          => 'inventory_org', /* Mapping type */
                                               p_stage_tab             => 'XXS3_PTM_ONH_INVENTORY', /* Staging Table Name */
                                               p_stage_primary_col     => 'XX_ONH_INV_ID', /* Staging Table Primary Column Name */
                                               p_stage_primary_col_val => j.xx_onh_inv_id, /* Staging Table Primary Column Value */
                                               p_legacy_val            => j.organization_code, /* Legacy Value */
                                               p_stage_col             => 's3_organization_code', /* Staging Table Name */
                                               p_err_code              => l_err_code, /* Output error code  */
                                               p_err_msg               => l_err_msg); /* Error Message */
      
      END IF;
      IF j.locator_type IS NOT NULL THEN
        xxs3_data_transform_util_pkg.transform(p_mapping_type          => 'onh_inv_locator_type',
                                               p_stage_tab             => 'XXS3_PTM_ONH_INVENTORY', --Staging Table Name
                                               p_stage_primary_col     => 'XX_ONH_INV_ID', --Staging Table Primary Column Name
                                               p_stage_primary_col_val => j.xx_onh_inv_id, --Staging Table Primary Column Value
                                               p_legacy_val            => j.locator_type, --Legacy Value
                                               p_stage_col             => 'S3_LOCATOR_TYPE', --Staging Table Name
                                               p_err_code              => l_err_code, -- Output error code
                                               p_err_msg               => l_err_msg);
      END IF;
    
      IF j.serial_number_control_code IS NOT NULL THEN
        xxs3_data_transform_util_pkg.transform(p_mapping_type          => 'onh_inv_serial_number_control_code',
                                               p_stage_tab             => 'XXS3_PTM_ONH_INVENTORY', --Staging Table Name
                                               p_stage_primary_col     => 'XX_ONH_INV_ID', --Staging Table Primary Column Name
                                               p_stage_primary_col_val => j.xx_onh_inv_id, --Staging Table Primary Column Value
                                               p_legacy_val            => j.serial_number_control_code, --Legacy Value
                                               p_stage_col             => 'S3_SERIAL_NUMBER_CONTROL_CODE', --Staging Table Name
                                               p_err_code              => l_err_code, -- Output error code
                                               p_err_msg               => l_err_msg);
      END IF;
    
      IF j.shelf_life_code IS NOT NULL THEN
        xxs3_data_transform_util_pkg.transform(p_mapping_type          => 'onh_inv_shelf_life_code',
                                               p_stage_tab             => 'XXS3_PTM_ONH_INVENTORY', --Staging Table Name
                                               p_stage_primary_col     => 'XX_ONH_INV_ID', --Staging Table Primary Column Name
                                               p_stage_primary_col_val => j.xx_onh_inv_id, --Staging Table Primary Column Value
                                               p_legacy_val            => j.shelf_life_code, --Legacy Value
                                               p_stage_col             => 'S3_SHELF_LIFE_CODE', --Staging Table Name
                                               p_err_code              => l_err_code, -- Output error code
                                               p_err_msg               => l_err_msg);
      END IF;
    
      ------------------ Get Subinventory_name and Locator Id and segments --------------------------
    
      xxs3_data_transform_util_pkg.ptm_locator_attr2_parse(j.LOC_ATTRIBUTE2,
                                                           l_get_org,
                                                           l_get_sub_inv_name,
                                                           l_get_concat_segments,
                                                           l_get_row,
                                                           l_get_rack,
                                                           l_get_bin,
                                                           l_error_message);
    
      IF l_error_message IS NULL THEN
      
        update xxobjt.XXS3_PTM_ONH_INVENTORY
           set s3_organization_code = l_get_org,
               s3_subinventory_code = l_get_sub_inv_name,
               s3_loc_segment1      = l_get_row,
               s3_loc_segment2      = l_get_rack,
               s3_loc_segment3      = l_get_bin,
               transform_status     = 'PASS'
         where xx_onh_inv_id = j.xx_onh_inv_id;
      
      ELSE
      
        update xxobjt.XXS3_PTM_ONH_INVENTORY
           set transform_status = 'FAIL', transform_error = l_error_message
         where xx_onh_inv_id = j.xx_onh_inv_id;
      
      END IF;
    
    END LOOP;
  
    onh_inv_report_data('ON-HAND INVENTORY', l_err_code, l_err_msg);
  
  END onh_inventories_extract_data;

END xxs3_ptm_onh_inventories_pkg;
/
