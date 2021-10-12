CREATE OR REPLACE PACKAGE xxs3_ptm_item_trx_def_pkg

-- --------------------------------------------------------------------------------------------
-- Purpose: This Package is used for Subinventories Extract, Quality Check and Report
--
-- --------------------------------------------------------------------------------------------
-- Ver  Date        Name                          Description
-- 1.0  29/07/2016  TCS                           Initial build
-- --------------------------------------------------------------------------------------------

 AS

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used for Subinventories Extract
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  29/07/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE item_trx_def_extract_data(x_errbuf  OUT VARCHAR2,
                                      x_retcode OUT NUMBER);

  PROCEDURE data_cleanse_report(p_entity VARCHAR2);

  PROCEDURE data_transform_report(p_entity VARCHAR2);

END xxs3_ptm_item_trx_def_pkg;
/
CREATE OR REPLACE PACKAGE BODY xxs3_ptm_item_trx_def_pkg AS

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
                        'Error in writting Log File. ' || SQLERRM);
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
  -- Purpose: This Procedure is used for Subinventories Data Quality Report
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  29/07/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE item_trx_def_report_data(p_entity_name IN VARCHAR2,
                                     p_err_code    OUT VARCHAR2,
                                     p_err_msg     OUT VARCHAR2) AS
  
    p_delimiter VARCHAR2(5) := '~';
    CURSOR c_report IS
      SELECT *
        FROM XXS3_PTM_ITEM_TRX_DEF xoi, XXS3_PTM_ITEM_TRX_DEF_DQ xod
       WHERE xoi.xx_item_trx_def_id = xod.xx_item_trx_def_id
         AND xoi.process_flag IN ('Q', 'R')
       ORDER BY 1;
  
  BEGIN
  
    out_p(rpad('Item Transaction Default status report', 100, ' '));
    out_p(rpad('==================================', 100, ' '));
    out_p('');
    out_p('Date:    ' || to_char(SYSDATE, 'dd-Mon-YYYY HH24:MI'));
  
    out_p('');
  
    out_p(rpad('Track Name', 15, ' ') || p_delimiter ||
          rpad('Entity Name', 20, ' ') || p_delimiter ||
          rpad('XX ONH INV ID  ', 15, ' ') || p_delimiter ||
          rpad('ON HAND INVENTORY NAME', 25, ' ') || p_delimiter ||
          rpad('Rule Name', 50, ' ') || p_delimiter ||
          rpad('Reason Code', 50, ' '));
  
    /*  
    FOR i IN c_report LOOP
      out_p(rpad('PTM', 15, ' ') || p_delimiter ||
            rpad('ON HAND INVENTORY', 20, ' ') || p_delimiter ||
            rpad(i.xx_item_trx_def_id, 15, ' ') || p_delimiter ||
            rpad(i.S3_ORGANIZATION_CODE , 25, ' ') || p_delimiter ||
            rpad(i.S3_SUBINVENTORY_CODE  , 25, ' ') || p_delimiter ||
            rpad(i.S3_STOCK_LOCATOR   , 25, ' ') || p_delimiter || 
             rpad(i.SEGMENT1   , 25, ' ') || p_delimiter ||
            rpad(i.rule_name, 50, ' ') || p_delimiter ||
            rpad(i.notes, 50, ' '));
    END LOOP;*/
    p_err_code := '0';
    p_err_msg  := '';
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code := '2';
      p_err_msg  := 'SQLERRM: ' || SQLERRM;
      log_p('Failed to generate report: ' || SQLERRM);
  END item_trx_def_report_data;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used for Subinventories Data Quality Report Rules
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  29/07/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE insert_update_trx_def_dq(p_item_trx_def_id NUMBER,
                                     p_rule_name       IN VARCHAR2,
                                     p_reject_code     IN VARCHAR2,
                                     p_err_code        OUT VARCHAR2,
                                     p_err_msg         OUT VARCHAR2) IS
  
  BEGIN
  
    UPDATE xxobjt.XXS3_PTM_ITEM_TRX_DEF
       SET process_flag = 'Q'
     WHERE xx_item_trx_def_id = p_item_trx_def_id;
  
    INSERT INTO XXS3_PTM_ITEM_TRX_DEF_DQ
      (xx_dq_item_trx_def_id, xx_item_trx_def_id, rule_name, notes)
    VALUES
      (xxobjt.XXS3_PTM_ITEM_TRX_DEF_DQ_SEQ.NEXTVAL,
       p_item_trx_def_id,
       p_rule_name,
       p_reject_code);
  
    p_err_code := '0';
    p_err_msg  := '';
  
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code := '2';
      p_err_msg  := 'SQLERRM: ' || SQLERRM;
      ROLLBACK;
    
  END insert_update_trx_def_dq;

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
  
    CURSOR c_report_trx_default IS
      SELECT xps.xx_item_trx_def_id,
             xps.inventory_item_id,
             xps.inventory_item_name,
             xps.organization_code,
             xps.s3_organization_code,
             xps.loc_attribute2,
             xps.subinventory_code,
             xps.s3_subinventory_code,
             xps.loc_segment1,
             xps.s3_loc_segment1,
             xps.loc_segment2,
             xps.s3_loc_segment2,
             xps.loc_segment3,
             xps.s3_loc_segment3,
             xps.transform_status,
             xps.transform_error
        FROM XXS3_PTM_ITEM_TRX_DEF xps
       WHERE xps.transform_status IN ('PASS', 'FAIL');
  
  BEGIN
  
    SELECT COUNT(1)
      INTO l_count_success
      FROM XXS3_PTM_ITEM_TRX_DEF xps
     WHERE xps.transform_status = 'PASS';
  
    SELECT COUNT(1)
      INTO l_count_fail
      FROM XXS3_PTM_ITEM_TRX_DEF xps
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
          rpad('Entity Name', 20, ' ') || p_delimiter ||
          rpad('xx item trx def id', 30, ' ') || p_delimiter ||
          rpad('INVENTORY ITEM ID', 10, ' ') || p_delimiter ||
          rpad('INVENTORY ITEM NAME', 10, ' ') || p_delimiter ||
          rpad('ORGANIZATION CODE', 30, ' ') || p_delimiter ||
          rpad('S3 ORGANIZATION CODE', 30, ' ') || p_delimiter ||
          rpad('LOC ATTRIBUTE2', 30, ' ') || p_delimiter ||
          rpad('SUBINVENTORY COODE', 30, ' ') || p_delimiter ||
          rpad('S3 SUBINVENTORY COODE', 30, ' ') || p_delimiter ||
          rpad('LOC SEGMENT1', 20, ' ') || p_delimiter ||
          rpad('S3 LOC SEGMENT1', 20, ' ') || p_delimiter ||
          rpad('LOC SEGMENT2', 20, ' ') || p_delimiter ||
          rpad('S3 LOC SEGMENT2', 20, ' ') || p_delimiter ||
          rpad('LOC SEGMENT3', 20, ' ') || p_delimiter ||
          rpad('S3 LOC SEGMENT3', 20, ' ') || p_delimiter ||
          rpad('Status', 10, ' ') || p_delimiter ||
          rpad('Error Message', 200, ' '));
  
    FOR r_data IN c_report_trx_default LOOP
      out_p(rpad('PTM', 10, ' ') || p_delimiter ||
            rpad('ITEM TRX DEFAULT', 20, ' ') || p_delimiter ||
            rpad(r_data.xx_item_trx_def_id, 14, ' ') || p_delimiter ||
            rpad(r_data.inventory_item_id, 10, ' ') || p_delimiter ||
            rpad(r_data.inventory_item_name, 50, ' ') || p_delimiter ||
            rpad(r_data.organization_code, 10, ' ') || p_delimiter ||
            rpad(r_data.s3_organization_code, 10, ' ') || p_delimiter ||
            rpad(r_data.loc_attribute2, 10, ' ') || p_delimiter ||
            rpad(r_data.subinventory_code, 10, ' ') || p_delimiter ||
            rpad(r_data.s3_subinventory_code, 10, ' ') || p_delimiter ||
            rpad(r_data.loc_segment1, 10, ' ') || p_delimiter ||
            rpad(r_data.s3_loc_segment1, 10, ' ') || p_delimiter ||
            rpad(r_data.loc_segment2, 10, ' ') || p_delimiter ||
            rpad(r_data.s3_loc_segment2, 10, ' ') || p_delimiter ||
            rpad(r_data.loc_segment3, 10, ' ') || p_delimiter ||
            rpad(r_data.s3_loc_segment3, 10, ' ') || p_delimiter ||
            rpad(r_data.transform_status, 10, ' ') || p_delimiter ||
            rpad(nvl(r_data.transform_error, 'NULL'), 200, ' '));
    END LOOP;
  
    fnd_file.put_line(fnd_file.output, '');
    fnd_file.put_line(fnd_file.output,
                      'Stratasys Confidential' || p_delimiter);
  END;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure is used to Cleansing data for Item Transactions Default
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  25/07/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE cleanse_data_item_def(p_errbuf  OUT VARCHAR2,
                                  p_retcode OUT NUMBER) AS
  
    l_status      VARCHAR2(10) := 'SUCCESS';
    l_check_rule  VARCHAR2(10) := 'TRUE';
    l_err_message VARCHAR2(2000);
  
    CURSOR cur_itd IS
      SELECT * FROM xxobjt.XXS3_PTM_ITEM_TRX_DEF;
  
  BEGIN
    l_check_rule := 'TRUE';
  
    FOR i IN cur_itd LOOP
    
      BEGIN
      
        UPDATE xxobjt.XXS3_PTM_ITEM_TRX_DEF
           SET s3_subinventory_code = 'STORES', cleanse_status = 'PASS'
         WHERE xx_item_trx_def_id = i.xx_item_trx_def_id
           and i.S3_organization_code = 'T03';
      
      EXCEPTION
        WHEN OTHERS THEN
          l_err_message := SQLERRM;
        
          UPDATE xxobjt.XXS3_PTM_ITEM_TRX_DEF
             SET cleanse_status = 'FAIL',
                 cleanse_error  = cleanse_error || ' SUBINVENTORY CODE:' ||
                                  l_err_message || ' ,'
           WHERE xx_item_trx_def_id = i.xx_item_trx_def_id;
        
      END;
    
    END LOOP;
    COMMIT;
  
  END cleanse_data_item_def;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used for On Hand inventories Extract
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  29/07/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE item_trx_def_extract_data(x_errbuf  OUT VARCHAR2,
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
  
    cursor cur_itd_transform is
      SELECT itd.* FROM xxobjt.XXS3_PTM_ITEM_TRX_DEF itd;
    -- WHERE process_flag IN ('Y', 'Q'); -- As there is no DQ
  
    cursor cur_item_trx_def is -- change
      SELECT msd.inventory_item_id inventory_item_id,
             msi.segment1 inventory_item_name,
             msd.organization_id organization_id,
             (SELECT organization_code
                FROM org_organization_definitions
               WHERE organization_id = msd.organization_id) organization_code,
             msd.subinventory_code subinventory_code,
             msd.default_type default_type,
             ml.attribute2 loc_attribute2,
             ml.segment1 loc_segment1,
             ml.segment2 loc_segment2,
             ml.segment3 loc_segment3,
             ml.segment4 loc_segment4 --msi.description, ml.segment1, mld.*
        FROM mtl_item_sub_defaults msd,
             mtl_system_items_b    msi,
             mtl_item_loc_defaults mld,
             mtl_item_locations    ml
       WHERE 1 = 1
         AND msi.inventory_item_id = msd.inventory_item_id
         AND msi.organization_id = msd.organization_id
         AND mld.inventory_item_id(+) = msi.inventory_item_id
         AND mld.organization_id(+) = msi.organization_id
         AND ml.inventory_location_id(+) = mld.locator_id
         AND ml.organization_id(+) = mld.organization_id
         AND msi.organization_id = 739
         AND msd.default_type = 2
         AND msi.planning_make_buy_code = 2;
  
    ----------------------------------------------
  
  BEGIN
  
    DELETE FROM xxobjt.XXS3_PTM_ITEM_TRX_DEF;
  
    DELETE FROM xxobjt.XXS3_PTM_ITEM_TRX_DEF_DQ;
  
    for i in cur_item_trx_def loop
    
      INSERT INTO xxobjt.XXS3_PTM_ITEM_TRX_DEF
        (xx_item_trx_def_id,
         date_of_extract,
         process_flag,
         inventory_item_id,
         inventory_item_name,
         organization_id,
         organization_code,
         subinventory_code,
         default_type,
         loc_attribute2,
         loc_segment1,
         loc_segment2,
         loc_segment3,
         loc_segment4)
      values
        (XXS3_PTM_ITEM_TRX_DEF_SEQ.NEXTVAL,
         sysdate,
         'N',
         i.inventory_item_id,
         i.inventory_item_name,
         i.organization_id,
         i.organization_code,
         i.subinventory_code,
         i.default_type,
         i.loc_attribute2,
         i.loc_segment1,
         i.loc_segment2,
         i.loc_segment3,
         i.loc_segment4);
    end loop;
  
    ------------------- transform  subinventory, segments----------
  
    FOR j IN cur_itd_transform LOOP
    
      IF j.organization_code IS NOT NULL THEN
        xxs3_data_transform_util_pkg.transform(p_mapping_type          => 'inventory_org',
                                               p_stage_tab             => 'XXOBJT.XXS3_PTM_ITEM_TRX_DEF', --Staging Table Name
                                               p_stage_primary_col     => 'XX_ITEM_TRX_DEF_ID', --Staging Table Primary Column Name
                                               p_stage_primary_col_val => j.xx_item_trx_def_id, --Staging Table Primary Column Value
                                               p_legacy_val            => j.organization_code, --Legacy Value
                                               p_stage_col             => 'S3_ORGANIZATION_CODE', --Staging Table Name
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
      
        update xxobjt.XXS3_PTM_ITEM_TRX_DEF
           set s3_organization_code = l_get_org,
               s3_subinventory_code = l_get_sub_inv_name,
               s3_loc_segment1      = l_get_row,
               s3_loc_segment2      = l_get_rack,
               s3_loc_segment3      = l_get_bin,
               transform_status     = 'PASS'
         where xx_item_trx_def_id = j.xx_item_trx_def_id;
      
      ELSE
      
        update xxobjt.XXS3_PTM_ITEM_TRX_DEF
           set transform_status = 'FAIL', transform_error = l_error_message
         where xx_item_trx_def_id = j.xx_item_trx_def_id;
      
      END IF;
    
    END LOOP;
    ----------------------------------------------------------------------------------------------------
    item_trx_def_report_data('ITEM TRANSACTION DEFAULT',
                             l_err_code,
                             l_err_msg);
  
  END item_trx_def_extract_data;

  --------------------------------------------------------------------
  --  name:              data_cleanse_report
  --  create by:         Debarati banerjee
  --  Revision:          1.0
  --  creation date:     13/05/2016
  --------------------------------------------------------------------
  --  purpose :          write data cleanse report to output
  --
  --------------------------------------------------------------------
  --  ver  date          name                   desc
  --  1.0  13/05/2016    Debarati banerjee     report data cleanse
  --------------------------------------------------------------------

  PROCEDURE data_cleanse_report(p_entity VARCHAR2) IS
  
    CURSOR c_report_trx_def IS
      SELECT xps.xx_item_trx_def_id,
             xps.inventory_item_id,
             xps.inventory_item_name,
             xps.organization_code,
             xps.subinventory_code,
             xps.s3_subinventory_code,
             xps.cleanse_status,
             xps.cleanse_error
        FROM XXS3_PTM_ITEM_TRX_DEF xps
       WHERE xps.cleanse_status IN ('PASS', 'FAIL');
  
    p_delimiter     VARCHAR2(5) := '~';
    l_err_msg       VARCHAR2(2000);
    l_count_success NUMBER;
    l_count_fail    NUMBER;
  
  BEGIN
    /*
    x_err_code := 0;
    x_err_msg  := '';*/
  
    SELECT count(1)
      INTO l_count_success
      FROM XXS3_PTM_ITEM_TRX_DEF xps
     WHERE xps.cleanse_status = 'PASS';
  
    SELECT count(1)
      INTO l_count_fail
      FROM XXS3_PTM_ITEM_TRX_DEF xps
     WHERE xps.cleanse_status = 'FAIL';
  
    fnd_file.put_line(fnd_file.output,
                      rpad('Report name = Automated Cleanse & Standardize Report' ||
                           p_delimiter,
                           100,
                           ' '));
    fnd_file.put_line(fnd_file.output,
                      rpad('====================================================' ||
                           p_delimiter,
                           100,
                           ' '));
    fnd_file.put_line(fnd_file.output,
                      rpad('Data Migration Object Name = ' || p_entity ||
                           p_delimiter,
                           100,
                           ' '));
    fnd_file.put_line(fnd_file.output, '');
    fnd_file.put_line(fnd_file.output,
                      rpad('Run date and time:    ' ||
                           to_char(SYSDATE, 'dd-Mon-YYYY HH24:MI') ||
                           p_delimiter,
                           100,
                           ' '));
    fnd_file.put_line(fnd_file.output,
                      rpad('Total Record Count Success = ' ||
                           l_count_success || p_delimiter,
                           100,
                           ' '));
    fnd_file.put_line(fnd_file.output,
                      rpad('Total Record Count Failure = ' || l_count_fail ||
                           p_delimiter,
                           100,
                           ' '));
  
    fnd_file.put_line(fnd_file.output, '');
  
    fnd_file.put_line(fnd_file.output,
                      rpad('Track Name', 10, ' ') || p_delimiter ||
                      rpad('Entity Name', 11, ' ') || p_delimiter ||
                      rpad('XX Item Trx Def ID  ', 14, ' ') || p_delimiter ||
                      rpad('Inventory Item ID', 10, ' ') || p_delimiter ||
                      rpad('Inventory Item Name', 240, ' ') || p_delimiter ||
                      rpad('Oraganization Code', 10, ' ') || p_delimiter ||
                      rpad('Subinventory Code', 30, ' ') || p_delimiter ||
                      rpad('S3 Subinventory Code', 30, ' ') || p_delimiter ||
                      rpad('Status', 10, ' ') || p_delimiter ||
                      rpad('Error Message', 200, ' '));
  
    FOR r_data IN c_report_trx_def LOOP
      fnd_file.put_line(fnd_file.output,
                        rpad('PTM', 10, ' ') || p_delimiter ||
                        rpad('ITEM TRX DEFAULT', 20, ' ') || p_delimiter ||
                        rpad(r_data.xx_item_trx_def_id, 14, ' ') ||
                        p_delimiter ||
                        rpad(r_data.inventory_item_id, 10, ' ') ||
                        p_delimiter ||
                        rpad(r_data.inventory_item_name, 240, ' ') ||
                        p_delimiter ||
                        rpad(r_data.organization_code, 240, ' ') ||
                        p_delimiter ||
                        rpad(r_data.subinventory_code, 30, ' ') ||
                        p_delimiter ||
                        rpad(r_data.s3_subinventory_code, 30, ' ') ||
                        p_delimiter || rpad(r_data.cleanse_status, 10, ' ') ||
                        p_delimiter ||
                        rpad(nvl(r_data.cleanse_error, 'NULL'), 200, ' '));
    
    END LOOP;
  
    fnd_file.put_line(fnd_file.output, '');
    fnd_file.put_line(fnd_file.output,
                      'Stratasys Confidential' || p_delimiter);
  
  END data_cleanse_report;

END xxs3_ptm_item_trx_def_pkg;
/
