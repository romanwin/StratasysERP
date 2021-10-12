CREATE OR REPLACE PACKAGE xxs3_rtr_fixed_assets_pkg

-- --------------------------------------------------------------------------------------------
-- Purpose: This Package is used for Fixed Assets Extract, Quality Check and Report
--
-- --------------------------------------------------------------------------------------------
-- Ver  Date        Name                          Description
-- 1.0  18/05/2016  TCS                           Initial build
-- --------------------------------------------------------------------------------------------

 AS

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Package is used for Fixed Assets Distribution Extract
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE distribution_extract_data(x_errbuf  OUT VARCHAR2
                                     ,x_retcode OUT NUMBER);

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Package is used for Fixed Assets Description Extract
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------                                     

  PROCEDURE description_extract_data(x_errbuf  OUT VARCHAR2
                                    ,x_retcode OUT NUMBER);

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Package is used for Fixed Assets Books Quality Check
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------                                      
  PROCEDURE quality_check_books(p_err_code OUT VARCHAR2
                               ,p_err_msg  OUT VARCHAR2);

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Package is used for Fixed Assets Books Extract
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------                                 
  PROCEDURE books_extract_data(x_errbuf  OUT VARCHAR2
                              ,x_retcode OUT NUMBER);

  PROCEDURE consolidated_extract_data(x_errbuf  OUT VARCHAR2
                                     ,x_retcode OUT NUMBER);

  PROCEDURE fa_dist_report_data(p_entity_name IN VARCHAR2);
  PROCEDURE fa_dist_transform_report(p_entity_name IN VARCHAR2);
  PROCEDURE fa_desc_report_data(p_entity_name IN VARCHAR2);
  PROCEDURE fa_desc_transform_report(p_entity_name IN VARCHAR2);
  PROCEDURE fa_books_report_data(p_entity_name IN VARCHAR2);
  PROCEDURE fa_books_transform_report(p_entity_name IN VARCHAR2);
END xxs3_rtr_fixed_assets_pkg;
/
CREATE OR REPLACE PACKAGE BODY xxs3_rtr_fixed_assets_pkg

-- --------------------------------------------------------------------------------------------
-- Purpose: This Package is used for Fixed Assets Extract, Quality Check and Report
--
-- --------------------------------------------------------------------------------------------
-- Ver  Date        Name                          Description
-- 1.0  18/05/2016  TCS                           Initial build
-- --------------------------------------------------------------------------------------------

 AS



  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure is used to write in concurrent log
  --           
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  TCS                           Initial build  
  -- --------------------------------------------------------------------------------------------

  PROCEDURE log_p(p_msg VARCHAR2) IS
  BEGIN
  
    fnd_file.put_line(fnd_file.log, p_msg);
  
  
  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log, 'Error in writting Log File. ' ||
                         SQLERRM);
  END log_p;




  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure is used to write in concurrent output
  --           
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  TCS                           Initial build  
  -- --------------------------------------------------------------------------------------------

  PROCEDURE out_p(p_msg VARCHAR2) IS
  BEGIN
  
    fnd_file.put_line(fnd_file.output, p_msg);
  
  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log, 'Error in writting Output File. ' ||
                         SQLERRM);
  END out_p;





  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used to Update process flag and Quality Check Result
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE insert_update_fa_books_dq(p_xx_fa_books_id NUMBER
                                     ,p_rule_name      IN VARCHAR2
                                     ,p_reject_code    IN VARCHAR2
                                     ,p_err_code       OUT VARCHAR2
                                     ,p_err_msg        OUT VARCHAR2) IS
  
  BEGIN
    UPDATE xxobjt.xxs3_rtr_fa_books
    SET process_flag = 'Q'
    WHERE xx_fa_books_id = p_xx_fa_books_id;
  
    INSERT INTO xxobjt.xxs3_rtr_fa_books_dq
      (xx_dq_fa_books_id
      ,xx_fa_books_id
      ,rule_name
      ,notes)
    VALUES
      (xxobjt.xxs3_rtr_fa_books_dq_seq.NEXTVAL
      ,p_xx_fa_books_id
      ,p_rule_name
      ,p_reject_code);
    p_err_code := '0';
    p_err_msg  := '';
  
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code := '2';
      p_err_msg  := 'SQLERRM: ' || SQLERRM;
      ROLLBACK;
    
  END insert_update_fa_books_dq;




  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used to Update process flag and Quality Check Result
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE insert_update_fa_books_rej_dq(p_xx_fa_books_id NUMBER
                                         ,p_rule_name      IN VARCHAR2
                                         ,p_reject_code    IN VARCHAR2
                                         ,p_err_code       OUT VARCHAR2
                                         ,p_err_msg        OUT VARCHAR2) IS
  
  BEGIN
    UPDATE xxobjt.xxs3_rtr_fa_books
    SET process_flag = 'R'
    WHERE xx_fa_books_id = p_xx_fa_books_id;
  
    INSERT INTO xxobjt.xxs3_rtr_fa_books_dq
      (xx_dq_fa_books_id
      ,xx_fa_books_id
      ,rule_name
      ,notes)
    VALUES
      (xxobjt.xxs3_rtr_fa_books_dq_seq.NEXTVAL
      ,p_xx_fa_books_id
      ,p_rule_name
      ,p_reject_code);
    p_err_code := '0';
    p_err_msg  := '';
  
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code := '2';
      p_err_msg  := 'SQLERRM: ' || SQLERRM;
      ROLLBACK;
    
  END insert_update_fa_books_rej_dq;




  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used to Update process flag and Quality Check Result
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE insert_update_fa_desc_dq(p_xx_fa_desc_id NUMBER
                                    ,p_rule_name     IN VARCHAR2
                                    ,p_reject_code   IN VARCHAR2
                                    ,p_err_code      OUT VARCHAR2
                                    ,p_err_msg       OUT VARCHAR2) IS
  
  BEGIN
    UPDATE xxobjt.xxs3_rtr_fa_description
    SET process_flag = 'Q'
    WHERE xx_fa_desc_id = p_xx_fa_desc_id;
  
    INSERT INTO xxobjt.xxs3_rtr_fa_desc_dq
      (xx_dq_fa_desc_id
      ,xx_fa_desc_id
      ,rule_name
      ,notes)
    VALUES
      (xxobjt.xxs3_rtr_fa_desc_dq_seq.NEXTVAL
      ,p_xx_fa_desc_id
      ,p_rule_name
      ,p_reject_code);
    p_err_code := '0';
    p_err_msg  := '';
  
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code := '2';
      p_err_msg  := 'SQLERRM: ' || SQLERRM;
      ROLLBACK;
    
  END insert_update_fa_desc_dq;




  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used to Update process flag and Quality Check Result
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE insert_update_fa_desc_rej_dq(p_xx_fa_desc_id NUMBER
                                        ,p_rule_name     IN VARCHAR2
                                        ,p_reject_code   IN VARCHAR2
                                        ,p_err_code      OUT VARCHAR2
                                        ,p_err_msg       OUT VARCHAR2) IS
  
  BEGIN
    UPDATE xxobjt.xxs3_rtr_fa_description
    SET process_flag = 'R'
    WHERE xx_fa_desc_id = p_xx_fa_desc_id;
  
    INSERT INTO xxobjt.xxs3_rtr_fa_desc_dq
      (xx_dq_fa_desc_id
      ,xx_fa_desc_id
      ,rule_name
      ,notes)
    VALUES
      (xxobjt.xxs3_rtr_fa_desc_dq_seq.NEXTVAL
      ,p_xx_fa_desc_id
      ,p_rule_name
      ,p_reject_code);
    p_err_code := '0';
    p_err_msg  := '';
  
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code := '2';
      p_err_msg  := 'SQLERRM: ' || SQLERRM;
      ROLLBACK;
    
  END insert_update_fa_desc_rej_dq;




  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used to Update process flag and Quality Check Result
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE insert_update_fa_dist_dq(p_xx_fa_dist_id NUMBER
                                    ,p_rule_name     IN VARCHAR2
                                    ,p_reject_code   IN VARCHAR2
                                    ,p_err_code      OUT VARCHAR2
                                    ,p_err_msg       OUT VARCHAR2) IS
  
  BEGIN
    UPDATE xxobjt.xxs3_rtr_fa_distributions
    SET process_flag = 'Q'
    WHERE xx_fa_dist_id = p_xx_fa_dist_id;
  
    INSERT INTO xxobjt.xxs3_rtr_fa_dist_dq
      (xx_dq_fa_dist_id
      ,xx_fa_dist_id
      ,rule_name
      ,notes)
    VALUES
      (xxobjt.xxs3_rtr_fa_dist_dq_seq.NEXTVAL
      ,p_xx_fa_dist_id
      ,p_rule_name
      ,p_reject_code);
    p_err_code := '0';
    p_err_msg  := '';
  
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code := '2';
      p_err_msg  := 'SQLERRM: ' || SQLERRM;
      ROLLBACK;
    
  END insert_update_fa_dist_dq;




  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used to Update process flag and Quality Check Result
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE insert_update_fa_dist_rej_dq(p_xx_fa_dist_id NUMBER
                                        ,p_rule_name     IN VARCHAR2
                                        ,p_reject_code   IN VARCHAR2
                                        ,p_err_code      OUT VARCHAR2
                                        ,p_err_msg       OUT VARCHAR2) IS
  
  BEGIN
    UPDATE xxobjt.xxs3_rtr_fa_distributions
    SET process_flag = 'R'
    WHERE xx_fa_dist_id = p_xx_fa_dist_id;
  
    INSERT INTO xxobjt.xxs3_rtr_fa_dist_dq
      (xx_dq_fa_dist_id
      ,xx_fa_dist_id
      ,rule_name
      ,notes)
    VALUES
      (xxobjt.xxs3_fa_dist_dq_seq.NEXTVAL
      ,p_xx_fa_dist_id
      ,p_rule_name
      ,p_reject_code);
    p_err_code := '0';
    p_err_msg  := '';
  
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code := '2';
      p_err_msg  := 'SQLERRM: ' || SQLERRM;
      ROLLBACK;
    
  END insert_update_fa_dist_rej_dq;



  /*  procedure cleanse_distribution_extract(p_err_code OUT VARCHAR2
                                 ,p_err_msg  OUT VARCHAR2) is
           
           l_cleanse_status varchar2(50):='PASS';
           l_cleanse_error  varchar2(2000);      
           l_clean_done number:=0;                
  begin 
  for i in (select * from xxobjt.xx_fa_distributions) loop
  begin
  l_clean_done:=0;
  --EQT_058
  IF i.location_segment1='USA' AND  i.location_segment2='BILLERICA' THEN
  l_clean_done:=1;
  UPDATE xxobjt.xx_fa_distributions SET location_segment1='USA-MA' WHERE XX_FA_DIST_ID=I.XX_FA_DIST_ID;
  END IF;
  IF i.location_segment2 is null THEN
  l_clean_done:=1;
  UPDATE xxobjt.xx_fa_distributions SET location_segment2='UNKNOWN' WHERE XX_FA_DIST_ID=I.XX_FA_DIST_ID;
  END IF;
  IF i.location_segment2 =i.location_segment3 THEN
  l_clean_done:=1;
  UPDATE xxobjt.xx_fa_distributions SET location_segment3=NULL WHERE XX_FA_DIST_ID=I.XX_FA_DIST_ID;
  END IF;
  
  EXCEPTION WHEN OTHERS THEN
  l_cleanse_status:='FAIL';
  l_CLEANSE_ERROR:=SUBSTR(SQLERRM,1,2000);
  end;
  if l_clean_done=1 then
  update xxobjt.xx_fa_distributions SET cleanse_status=l_cleanse_status ,cleanse_error=l_cleanse_error
  where XX_FA_DIST_ID=I.XX_FA_DIST_ID;
  end if;
  end loop;
  
  end;*/




  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used for Fixed Assets Books Quality Check
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  TCS                           Initial build
  -- -------------------------------------------------------------------------------------------- 

  PROCEDURE quality_check_books(p_err_code OUT VARCHAR2
                               ,p_err_msg  OUT VARCHAR2) IS
    l_status     VARCHAR2(10) := 'SUCCESS';
    l_check_rule VARCHAR2(10) := 'TRUE';
  
    CURSOR cur_books IS
      SELECT * FROM xxobjt.xxs3_rtr_fa_books WHERE process_flag = 'N';
  
  
  BEGIN
  
    FOR i IN cur_books
    LOOP
      l_status := 'SUCCESS';
    
    
      --DEPRN_START_DATE------
      l_check_rule := xxs3_dq_util_pkg.eqt_072(i.deprn_start_date);
    
      IF l_check_rule = 'FALSE'
      THEN
        insert_update_fa_books_rej_dq(i.xx_fa_books_id, 'EQT_072:Depreciation Start Date US', 'Missing Depreciation Start Date', p_err_code, p_err_msg);
        l_status := 'ERR';
      END IF;
      --DEPRECIATE_FLAG------
      l_check_rule := xxs3_dq_util_pkg.eqt_061(i.depreciate);
    
      IF l_check_rule = 'FALSE'
      THEN
        insert_update_fa_books_dq(i.xx_fa_books_id, 'EQT_061:Always equals Yes - US', 'DEPRECIATE_FLAG Should be Yes', p_err_code, p_err_msg);
        l_status := 'ERR';
      END IF;
    
    
      --BASIC_RATE-----
      IF i.method = 'OBJ FLAT'
      THEN
      
        l_check_rule := xxs3_dq_util_pkg.eqt_062(i.basic_rate, i.attribute_category_code);
        IF l_check_rule = 'FALSE'
        THEN
          insert_update_fa_books_rej_dq(i.xx_fa_books_id, 'EQT_062:Missing Basic Rate US', 'Missing Basic Rate', p_err_code, p_err_msg);
          l_status := 'ERR';
        END IF;
      END IF;
    
    
      --ADJUSTED_RATE----
      IF i.method = 'OBJ FLAT'
      THEN
        l_check_rule := xxs3_dq_util_pkg.eqt_063(i.adjusted_rate, i.attribute_category_code);
        IF l_check_rule = 'FALSE'
        THEN
          insert_update_fa_books_rej_dq(i.xx_fa_books_id, 'EQT_063:Missing Adjusted Rate US', 'Missing Adjusted Rate', p_err_code, p_err_msg);
          l_status := 'ERR';
        END IF;
      END IF;
      --EOFY_ADJ_COST----
      l_check_rule := xxs3_dq_util_pkg.eqt_064(i.eofy_adj_cost, i.retirement_id, i.date_in_service);
      IF l_check_rule = 'FALSE'
      THEN
        insert_update_fa_books_dq(i.xx_fa_books_id, 'EQT_064:EOFY ADJ Cost', 'EOFY ADJ Cost Check', p_err_code, p_err_msg);
        l_status := 'ERR';
      END IF;
    
    
      --EOFY_FORMULA_FACTOR----
      l_check_rule := xxs3_dq_util_pkg.eqt_065(i.eofy_adj_cost, i.eofy_formula_factor);
    
      IF l_check_rule = 'FALSE'
      THEN
        insert_update_fa_books_dq(i.xx_fa_books_id, 'EQT_065:EOY Formula Factor', 'EOY Formula Factor Check', p_err_code, p_err_msg);
        l_status := 'ERR';
      END IF;
    
    
      -- DATE_PLACED_IN_SERVICE-----
      IF i.date_in_service IS NULL
      THEN
        insert_update_fa_books_rej_dq(i.xx_fa_books_id, 'EQT-028:Is Not Null', 'Missing value ' || '' ||
                                       'for field ' ||
                                       'DATE_PLACED_IN_SERVICE', p_err_code, p_err_msg);
        l_status := 'ERR';
      END IF;
    
    
      --DATE_EFFECTIVE------
      IF i.date_effective IS NULL
      THEN
        insert_update_fa_books_rej_dq(i.xx_fa_books_id, 'EQT-028:Is Not Null', 'Missing value ' || '' ||
                                       'for field ' ||
                                       'DATE_EFFECTIVE', p_err_code, p_err_msg);
        l_status := 'ERR';
      END IF;
    
    
      --DEPRN_METHOD_CODE----
      IF i.method IS NULL
      THEN
        insert_update_fa_books_rej_dq(i.xx_fa_books_id, 'EQT-028:Is Not Null', 'Missing value ' || '' ||
                                       'for field ' ||
                                       'DEPRN_METHOD_CODE', p_err_code, p_err_msg);
        l_status := 'ERR';
      END IF;
    
    
      --EOFY_RESERVE----
      IF i.eofy_reserve IS NULL
      THEN
        insert_update_fa_books_dq(i.xx_fa_books_id, 'EQT-028:Is Not Null', 'Missing value ' || '' ||
                                   'for field ' ||
                                   'EOFY_RESERVE', p_err_code, p_err_msg);
        l_status := 'ERR';
      END IF;
    
    
      IF l_status <> 'ERR'
      THEN
        UPDATE xxobjt.xxs3_rtr_fa_books
        SET process_flag = 'Y'
        WHERE xx_fa_books_id = i.xx_fa_books_id;
      END IF;
    
    END LOOP;
    COMMIT;
    p_err_code := '0';
    p_err_msg  := '';
  
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code := '2';
      p_err_msg  := 'SQLERRM: ' || SQLERRM;
      ROLLBACK;
  END quality_check_books;




  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used for Fixed Assets Description Quality Check
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  TCS                           Initial build
  -- -------------------------------------------------------------------------------------------- 

  PROCEDURE quality_check_description(p_err_code OUT VARCHAR2
                                     ,p_err_msg  OUT VARCHAR2) IS
    l_status     VARCHAR2(10) := 'SUCCESS';
    l_check_rule VARCHAR2(10) := 'TRUE';
  
    CURSOR cur_description IS
      SELECT *
      FROM xxobjt.xxs3_rtr_fa_description
      WHERE process_flag = 'N';
  
  
  BEGIN
  
    FOR i IN cur_description
    LOOP
      l_status := 'SUCCESS';
    
    
      --ASSET_NUMBER---
      IF xxs3_dq_util_pkg.eqt_028(i.asset_number)
      THEN
        insert_update_fa_desc_rej_dq(i.xx_fa_desc_id, 'EQT_028:Is Not Null', 'Missing value ' || '' ||
                                      'for field ' ||
                                      'ASSET_NUMBER', p_err_code, p_err_msg);
        l_status := 'ERR';
      END IF;
    
    
      --ASSET_KEY---
      l_check_rule := xxs3_dq_util_pkg.eqt_151(i.asset_key_segment1, i.asset_key_segment2);
      IF l_check_rule = 'FALSE'
      THEN
        insert_update_fa_desc_rej_dq(i.xx_fa_desc_id, 'EQT-151:Invalid Asset Key', 'Invalid Asset Key', p_err_code, p_err_msg);
        l_status := 'ERR';
      END IF;
    
    
      --CURRENT_UNITS---
      l_check_rule := xxs3_dq_util_pkg.eqt_066(i.unit);
      IF l_check_rule = 'FALSE'
      THEN
        insert_update_fa_desc_dq(i.xx_fa_desc_id, 'EQT_066:Invalid Current Units value', 'Invalid Current Units value', p_err_code, p_err_msg);
        l_status := 'ERR';
      END IF;
    
    
      /*--TAG_NUMBER
      IF xxs3_dq_util_pkg.eqt_030(i.tag_number) THEN
        insert_update_fa_desc_rej_dq(i.xx_fa_desc_id, 'EQT_030:Should be NULL', 'TAG_NUMBER Should be NULL', p_err_code, p_err_msg);
        l_status := 'ERR';
      END IF;*/
    
    
      --MANUFACTURER_NAME----
      l_check_rule := xxs3_dq_util_pkg.eqt_067(i.manufacturer, i.attribute_category_code);
      IF l_check_rule = 'FALSE'
      THEN
        insert_update_fa_desc_dq(i.xx_fa_desc_id, 'EQT_067:Missing Manufacture Name', 'Missing Manufacture Name', p_err_code, p_err_msg);
        l_status := 'ERR';
      END IF;
    
    
      --SERIAL_NUMBER-----
      l_check_rule := xxs3_dq_util_pkg.eqt_068(i.serial_number, i.attribute_category_code);
      IF l_check_rule = 'FALSE'
      THEN
        insert_update_fa_desc_rej_dq(i.xx_fa_desc_id, 'EQT-068:Missing Serial Number', 'Missing Serial Number', p_err_code, p_err_msg);
        l_status := 'ERR';
      END IF;
    
    
      --MODEL_NUMBER-----
      l_check_rule := xxs3_dq_util_pkg.eqt_069(i.serial_number, i.attribute_category_code);
      IF l_check_rule = 'FALSE'
      THEN
        insert_update_fa_desc_dq(i.xx_fa_desc_id, 'EQT-068:Missing Serial Number', 'Missing Serial Number', p_err_code, p_err_msg);
        l_status := 'ERR';
      END IF;
    
    
      --PROPERTY_TYPE_CODE----
      IF xxs3_dq_util_pkg.eqt_030(i.property_type_code)
      THEN
        insert_update_fa_desc_dq(i.xx_fa_desc_id, 'EQT_030:Should be NULL', 'PROPERTY_TYPE_CODE Should be NULL', p_err_code, p_err_msg);
        l_status := 'ERR';
      END IF;
    
    
      --PROPERTY_1245_1250_CODE-----
      IF xxs3_dq_util_pkg.eqt_030(i.property_class)
      THEN
        insert_update_fa_desc_dq(i.xx_fa_desc_id, 'EQT_030:Should be NULL', 'PROPERTY_CLASS Should be NULL', p_err_code, p_err_msg);
        l_status := 'ERR';
      END IF;
    
    
      --ATTRIBUTE_CATEGORY_CODE----
      l_check_rule := xxs3_dq_util_pkg.eqt_070(i.category_segment1, i.category_segment2);
      IF l_check_rule = 'FALSE'
      THEN
        insert_update_fa_desc_dq(i.xx_fa_desc_id, 'EQT-070:Valid Attribute Category Code', 'Invalid Attribute Category Code', p_err_code, p_err_msg);
        l_status := 'ERR';
      END IF;
    
    
      --INVENTORIAL----
      l_check_rule := xxs3_dq_util_pkg.eqt_071(i.in_physical_inventory, i.attribute_category_code);
      IF l_check_rule = 'FALSE'
      THEN
        insert_update_fa_desc_dq(i.xx_fa_desc_id, 'EQT_071:Valid Inventorial Flag', 'Invalid Inventorial Flag', p_err_code, p_err_msg);
        l_status := 'ERR';
      END IF;
    
    
      IF l_status <> 'ERR'
      THEN
        UPDATE xxobjt.xxs3_rtr_fa_description
        SET process_flag = 'Y'
        WHERE xx_fa_desc_id = i.xx_fa_desc_id;
      
      END IF;
    
    END LOOP;
  
  END;




  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used for Fixed Assets Distribution Quality Check
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  TCS                           Initial build
  -- -------------------------------------------------------------------------------------------- 

  PROCEDURE quality_check_distribution(p_err_code OUT VARCHAR2
                                      ,p_err_msg  OUT VARCHAR2) IS
    l_status     VARCHAR2(10) := 'SUCCESS';
    l_check_rule VARCHAR2(10) := 'TRUE';
  
    CURSOR cur_distributions IS
      SELECT *
      FROM xxobjt.xxs3_rtr_fa_distributions
      WHERE process_flag = 'N';
  
  
  BEGIN
  
    FOR i IN cur_distributions
    LOOP
      l_status := 'SUCCESS';
    
      /*      --SEGMENT1
      l_check_rule := xxs3_dq_util_pkg.eqt_057(i.location_segment1);
      IF l_check_rule = 'FALSE' THEN
        insert_update_fa_dist_rej_dq(i.xx_fa_dist_id, 'EQT_057:FA Locations Segment 1 US', 'Invalid FA Loc Segment 1', p_err_code, p_err_msg);
        l_status := 'ERR';
      END IF;
      --SEGMENT2
      l_check_rule := xxs3_dq_util_pkg.eqt_058(i.location_segment2);
      IF l_check_rule = 'FALSE' THEN
        insert_update_fa_dist_rej_dq(i.xx_fa_dist_id, 'EQT_058:FA Locations Segment 2 US', 'Invalid FA Loc Segment 2', p_err_code, p_err_msg);
        l_status := 'ERR';
      END IF;
      --SEGMENT3
      l_check_rule := xxs3_dq_util_pkg.eqt_059(i.location_segment3);
      IF l_check_rule = 'FALSE' THEN
        insert_update_fa_dist_rej_dq(i.xx_fa_dist_id, 'EQT_059:FA Locations Segment 3 US', 'Invalid FA Loc Segment 3', p_err_code, p_err_msg);
        l_status := 'ERR';
      END IF;*/
    
    
      --SUMMARY_FLAG-----
      IF NOT xxs3_dq_util_pkg.eqt_035(i.summary_flag)
      THEN
        insert_update_fa_dist_rej_dq(i.xx_fa_dist_id, 'EQT_035:Always Equals N - US', 'SUMMARY_FLAG Should be N', p_err_code, p_err_msg);
        l_status := 'ERR';
      END IF;
    
    
      --ENABLED_FLAG-----
      IF xxs3_dq_util_pkg.eqt_044(i.enabled_flag)
      THEN
        insert_update_fa_dist_rej_dq(i.xx_fa_dist_id, 'EQT_044:Always Equals Y - US', 'ENABLED_FLAG Should be Y', p_err_code, p_err_msg);
        l_status := 'ERR';
      END IF;
    
    
      --END_DATE_ACTIVE----
      IF xxs3_dq_util_pkg.eqt_030(i.end_date_active)
      THEN
        insert_update_fa_dist_dq(i.xx_fa_dist_id, 'EQT_030:Should be NULL', 'END_DATE_ACTIVE Should be NULL', p_err_code, p_err_msg);
        l_status := 'ERR';
      END IF;
    
    
      IF l_status <> 'ERR'
      THEN
        UPDATE xxobjt.xxs3_rtr_fa_distributions
        SET process_flag = 'Y'
        WHERE xx_fa_dist_id = i.xx_fa_dist_id;
      END IF;
    END LOOP;
  END quality_check_distribution;




  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure is used for a COnsolidated Fixed Assets Extract of Books, Description 
  -- and Distribution
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  21/09/2016  TCS                           Initial build
  -- -------------------------------------------------------------------------------------------- 

  PROCEDURE consolidated_extract_data(x_errbuf  OUT VARCHAR2
                                     ,x_retcode OUT NUMBER) AS
    l_err_code NUMBER;
    l_err_msg  VARCHAR2(100);
  
    CURSOR cur_fa_consol_data IS
      SELECT xfdsc.asset_number asset_number
            ,xfdsc.tag_number tag_number
            ,xfdsc.description description
            ,xfdsc.asset_type asset_type
            ,xfdsc.serial_number serial_number
            ,xfdsc.category_segment1 || '.' || xfdsc.category_segment2 asset_category
            ,xfdsc.asset_key_segment1 || '.' || xfdsc.asset_key_segment2 asset_key
            ,xfdsc.s3_category s3_category
            ,xfdsc.s3_asset_key s3_asset_key
            ,xfdst.units fixed_assets_units
            ,xfdsc.manufacturer manufacturer_name
            ,xfdsc.model model_number
            ,xfdsc.in_use in_use_flag
            ,xfdsc.property_type_code property_type_code
            ,xfdsc.ownership owned_leased
            ,xfdsc.property_class property_class
            ,xfdsc.bought new_used
            ,xfdsc.lease_number lease_number
            ,xfdsc.lessor lessor
            ,xfb.book_type_code book_type_code
            ,xfb.s3_book_type_code s3_book_type_code
            ,xfb.current_cost fixed_assets_cost
            ,xfb.ytd_depreciation ytd_deprn
            ,xfb.accumulated_depreciation accu_deprn
            ,decode(xfb.salvage_value_type, 'AMT', 'AMOUNT', 'PCT', 'PERCENTAGE', NULL) salvage_type
            ,xfb.salvage_value_percent percent_salvage_value
            ,xfb.salvage_value salvage_value
            ,xfb.method method_code
            ,xfb.basic_rate basic_rate
            ,xfb.adjusted_rate adjusted_rate
            ,xfb.date_in_service date_placed_in_service
            ,xfb.prorate_convention prorate_convention
            ,xfb.depreciate depreciate_flag
            ,xfdst.units units
            ,xfdst.employee_number employee_number
            ,xfdst.employee_name full_name
            ,xfdst.expense_acct_segment1 || '.' ||
             xfdst.expense_acct_segment2 || '.' ||
             xfdst.expense_acct_segment3 || '.' ||
             xfdst.expense_acct_segment5 || '.' ||
             xfdst.expense_acct_segment6 || '.' ||
             xfdst.expense_acct_segment7 || '.' ||
             xfdst.expense_acct_segment10 legacy_expense_account
            ,xfdst.s3_expense_account s3_expense_account
            ,xfdst.location_segment1 || '.' || xfdst.location_segment2 || '.' ||
             xfdst.location_segment3 || '.' || xfdst.location_segment4 || '.' ||
             xfdst.location_segment5 legacy_location
            ,xfdst.s3_location s3_location
            ,xfb.life_in_months life_in_months
            ,CASE
               WHEN nvl(xfdsc.transform_status, 'PASS') = 'PASS'
                    AND nvl(xfb.transform_status, 'PASS') = 'PASS'
                    AND nvl(xfdst.transform_status, 'PASS') = 'PASS' THEN
                'PASS'
               ELSE
                'FAIL'
             END AS transform_status_consol
            ,xfdsc.transform_error transform_error_desc
            ,xfb.transform_error transform_error_bk
            ,xfdst.transform_error transform_error_dst
      FROM xxs3_rtr_fa_description   xfdsc
          ,xxs3_rtr_fa_books         xfb
          ,xxs3_rtr_fa_distributions xfdst
      WHERE xfdsc.asset_id = xfb.asset_id
      AND xfb.asset_id = xfdst.asset_id
      AND ((xfdsc.process_flag <> 'R') AND (xfb.process_flag <> 'R') AND
            (xfdst.process_flag <> 'R'));
  
  BEGIN
  
    -- --------------------------------------------------------------------------------------------
    -- Purpose: This procedures are being called to populate custom tables to Extract data of Asset 
    -- Books, Description, Description
    --
    -- --------------------------------------------------------------------------------------------
    -- Ver  Date        Name                          Description
    -- 1.0  22/09/2016  TCS                           Initial build
    -- -------------------------------------------------------------------------------------------- 
  
    log_p('Executing distribution_extract_data...');
  
    distribution_extract_data(x_errbuf, x_retcode);
  
    log_p('Executing description_extract_data...');
  
    description_extract_data(x_errbuf, x_retcode);
  
    log_p('Executing books_extract_data...');
  
    books_extract_data(x_errbuf, x_retcode);
  
    log_p('Deleting data from xxobjt.XXS3_RTR_FA_CONSOL...');
  
  
  
    log_p('Truncating consolidated table...');
    EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.XXS3_RTR_FA_CONSOL';
  
  
  
    log_p('Inserting data from xxobjt.XXS3_RTR_FA_CONSOL...');
  
  
    FOR i IN cur_fa_consol_data
    LOOP
      BEGIN
        INSERT INTO xxobjt.xxs3_rtr_fa_consol
          (xx_fa_consol_id
          ,date_extracted_on
          ,process_flag
          ,asset_number
          ,tag_number
          ,description
          ,asset_type
          ,serial_number
          ,asset_category
          ,asset_key
          ,s3_asset_category
          ,s3_asset_key
          ,fixed_assets_units
          ,manufacturer_name
          ,model_number
          ,warranty
          ,in_use_flag
          ,inventorial
          ,owned_leased
          ,property_class
          ,bought
          ,lease_number
          ,lessor
          ,group_asset_id
          ,attribute1
          ,attribute2
          ,attribute3
          ,book_type_code
          ,s3_book_type_code
          ,reviewer_comments
          ,fixed_assets_cost
          ,ytd_depreciation
          ,accumulated_depreciation
          ,salvage_type
          ,percent_salvage_value
          ,salvage_value
          ,method_code
          ,basic_rate
          ,adjusted_rate
          ,date_placed_in_service
          ,prorate_convention
          ,depreciate_flag
          ,units
          ,employee_number
          ,full_name
          ,legacy_expense_account
          ,s3_expense_account
          ,legacy_location
          ,s3_location
          ,life_in_months
          ,transform_status
          ,transform_error)
        
        VALUES
          (xxobjt.xxs3_rtr_fa_consol_seq.NEXTVAL
          ,SYSDATE
          ,'N'
          ,i.asset_number
          ,i.tag_number
          ,i.description
          ,i.asset_type
          ,i.serial_number
          ,i.asset_category
          ,i.asset_key
          ,i.s3_category
          ,i.s3_asset_key
          ,i.fixed_assets_units
          ,i.manufacturer_name
          ,i.model_number
          ,NULL
          ,i.in_use_flag
          ,NULL
          ,i.owned_leased
          ,i.property_class
          ,i.new_used
          ,i.lease_number
          ,i.lessor
          ,NULL
          ,NULL
          ,NULL
          ,NULL
          ,i.book_type_code
          ,i.s3_book_type_code
          ,NULL
          ,i.fixed_assets_cost
          ,i.ytd_deprn
          ,i.accu_deprn
          ,i.salvage_type
          ,i.percent_salvage_value
          ,i.salvage_value
          ,i.method_code
          ,i.basic_rate
          ,i.adjusted_rate
          ,i.date_placed_in_service
          ,i.prorate_convention
          ,i.depreciate_flag
          ,i.units
          ,i.employee_number
          ,i.full_name
          ,i.legacy_expense_account
          ,i.s3_expense_account
          ,i.legacy_location
          ,i.s3_location
          ,i.life_in_months
          ,i.transform_status_consol
          ,decode(i.transform_status_consol, 'PASS', NULL, i.transform_error_desc || ';' ||
                   i.transform_error_bk || ';' ||
                   i.transform_error_dst));
      
      
      EXCEPTION
        WHEN OTHERS THEN
          x_errbuf := 'Error while Inserting into the table XXS3_RTR_FA_CONSOL : ' ||
                      SQLERRM;
        
          dbms_output.put_line(x_errbuf);
      END;
    END LOOP;
  
  END consolidated_extract_data;




  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Package is used for Fixed Assets Distribution Extract
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  TCS                           Initial build
  -- -------------------------------------------------------------------------------------------- 

  PROCEDURE distribution_extract_data(x_errbuf  OUT VARCHAR2
                                     ,x_retcode OUT NUMBER) AS
  
    l_output_code_expense    VARCHAR2(50);
    l_output_message_expense VARCHAR2(400);
    l_err_code               NUMBER;
    l_err_msg                VARCHAR2(100);
    l_output                 VARCHAR2(4000);
    l_output_code            VARCHAR2(100);
    l_output_coa_update      VARCHAR2(4000);
    l_output_code_coa_update VARCHAR2(100);
    l_s3_gl_string           VARCHAR2(2000);
  
    CURSOR cur_transform IS
      SELECT *
      FROM xxs3_rtr_fa_distributions
      WHERE process_flag IN ('Y', 'Q');
  
    CURSOR cur_fa_distribution IS
      SELECT fdh.asset_id
            ,fav.asset_number
            ,fdh.book_type_code
            ,fdh.units_assigned units
            ,fdh.assigned_to employee_number
            ,pap.full_name employee_name
            ,fal.summary_flag
            ,fal.enabled_flag
            ,fal.end_date_active
            ,gcc.segment1 expense_acct_segment1
            ,gcc.segment2 expense_acct_segment2
            ,gcc.segment3 expense_acct_segment3
            ,gcc.segment5 expense_acct_segment5
            ,gcc.segment6 expense_acct_segment6
            ,gcc.segment7 expense_acct_segment7
            ,gcc.segment10 expense_acct_segment10
            ,gcc.segment9 expense_acct_segment9
            ,fdh.code_combination_id
            ,fal.segment1 location_segment1
            ,fal.segment2 location_segment2
            ,fal.segment3 location_segment3
            ,fal.segment4 location_segment4
            ,fal.segment5 location_segment5
      FROM fa_distribution_history fdh
          ,fa_locations            fal
          ,gl_code_combinations    gcc
          ,per_all_people_f        pap
          ,fa_additions_v          fav
      WHERE fdh.book_type_code IN ('STRATASYS CORP' /* , 'STRATASYS AMT', 'STRATASYS FEDER', 'GENERIC'*/
            )
      AND fdh.asset_id = fav.asset_id
      AND fdh.location_id = fal.location_id(+)
      AND fdh.code_combination_id = gcc.code_combination_id(+)
      AND fdh.assigned_to = pap.person_id(+)
      AND nvl((SELECT MAX(object_version_number)
             FROM per_all_people_f
             WHERE person_id = fdh.assigned_to), -99) =
            nvl(pap.object_version_number, -99)
      AND fdh.date_ineffective IS NULL
      AND NOT EXISTS
       (SELECT 1
             FROM fa_transaction_history_trx_v fth
             WHERE fth.asset_id = fav.asset_id
             AND fth.last_update_date =
                   (SELECT MAX(last_update_date)
                    FROM fa_transaction_history_trx_v fth1
                    WHERE fth1.asset_id = fth.asset_id)
             AND transaction_type_code = 'FULL RETIREMENT');
  
  BEGIN
  
  
    log_p('Truncating Asset Distribution Tables...');
    EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.XXS3_RTR_FA_DISTRIBUTIONS';
    EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.XXS3_RTR_FA_DIST_DQ';
  
  
    FOR i IN cur_fa_distribution
    LOOP
      BEGIN
        INSERT INTO xxobjt.xxs3_rtr_fa_distributions
          (xx_fa_dist_id
          ,date_extracted_on
          ,process_flag
          ,asset_id
          ,asset_number
          ,book_type_code
          ,units
          ,employee_number
          ,employee_name
          ,summary_flag
          ,enabled_flag
          ,end_date_active
          ,expense_acct_segment1
          ,expense_acct_segment2
          ,expense_acct_segment3
          ,expense_acct_segment5
          ,expense_acct_segment6
          ,expense_acct_segment7
          ,expense_acct_segment10
          ,expense_acct_segment9
          ,location_segment1
          ,location_segment2
          ,location_segment3
          ,location_segment4
          ,location_segment5)
        
        VALUES
          (xxobjt.xxs3_rtr_fa_distributions_seq.NEXTVAL
          ,SYSDATE
          ,'N'
          ,i.asset_id
          ,i.asset_number
          ,i.book_type_code
          ,i.units
          ,i.employee_number
          ,i.employee_name
          ,i.summary_flag
          ,i.enabled_flag
          ,i.end_date_active
          ,i.expense_acct_segment1
          ,i.expense_acct_segment2
          ,i.expense_acct_segment3
          ,i.expense_acct_segment5
          ,i.expense_acct_segment6
          ,i.expense_acct_segment7
          ,i.expense_acct_segment10
          ,i.expense_acct_segment9
          ,i.location_segment1
          ,i.location_segment2
          ,i.location_segment3
          ,i.location_segment4
          ,i.location_segment5);
      
      
      EXCEPTION
        WHEN OTHERS THEN
          x_errbuf := 'Error while Inserting into the table XXS3_RTR_FA_DISTRIBUTIONS :' ||
                      SQLERRM;
        
          dbms_output.put_line(x_errbuf);
        
      END;
    
    END LOOP;
  
    /* cleanse_distribution_extract(l_err_code ,l_err_msg );*/
    quality_check_distribution(l_err_code, l_err_msg);
  
  
    FOR k IN cur_transform
    LOOP
      BEGIN
        IF k.expense_acct_segment1 IS NOT NULL
        THEN
          xxs3_data_transform_util_pkg1.coa_transform(p_field_name => 'EXPENSE_ACCOUNT', p_legacy_company_val => k.expense_acct_segment1, --Legacy Company Value
                                                      p_legacy_department_val => k.expense_acct_segment2, --Legacy Department Value
                                                      p_legacy_account_val => k.expense_acct_segment3, --Legacy Account Value
                                                      p_legacy_product_val => k.expense_acct_segment5, --Legacy Product Value
                                                      p_legacy_location_val => k.expense_acct_segment6, --Legacy Location Value
                                                      p_legacy_intercompany_val => k.expense_acct_segment7, --Legacy Intercompany Value
                                                      p_legacy_division_val => k.expense_acct_segment10, --Legacy Division Value
                                                      p_item_number => NULL, p_s3_gl_string => l_s3_gl_string, p_err_code => l_output_code, p_err_msg => l_output); --Output Message 
        
          xxs3_data_transform_util_pkg1.coa_update(p_gl_string => l_s3_gl_string, p_stage_tab => 'xxobjt.xx_fa_distributions', p_stage_primary_col => 'XX_FA_DIST_ID', p_stage_primary_col_val => k.xx_fa_dist_id, p_stage_company_col => 'S3_EXPENSE_ACCT_SEGMENT1', p_stage_business_unit_col => 'S3_EXPENSE_ACCT_SEGMENT2', p_stage_department_col => 'S3_EXPENSE_ACCT_SEGMENT3', p_stage_account_col => 'S3_EXPENSE_ACCT_SEGMENT4', p_stage_product_line_col => 'S3_EXPENSE_ACCT_SEGMENT5', p_stage_location_col => 'S3_EXPENSE_ACCT_SEGMENT6', p_stage_intercompany_col => 'S3_EXPENSE_ACCT_SEGMENT7', p_stage_future_col => 'S3_EXPENSE_ACCT_SEGMENT8', p_coa_err_msg => l_output, p_err_code => l_output_code_coa_update, p_err_msg => l_output_coa_update);
        END IF;
        /* END LOOP;*/
      
        xxs3_data_transform_util_pkg1.transform(p_mapping_type => 'fa_location', p_stage_tab => 'XXS3_RTR_FA_DISTRIBUTIONS', --Staging Table Name
                                                p_stage_primary_col => 'XX_FA_DIST_ID', --Staging Table Primary Column Name
                                                p_stage_primary_col_val => k.xx_fa_dist_id, --Staging Table Primary Column Value
                                                p_legacy_val => k.location_segment1 || '.' ||
                                                                 k.location_segment2 || '.' ||
                                                                 k.location_segment3 || '.' ||
                                                                 k.location_segment4 || '.' ||
                                                                 k.location_segment5, --Legacy Value
                                                p_stage_col => 'S3_LOCATION', --Staging Table Name
                                                p_err_code => l_err_code, -- Output error code
                                                p_err_msg => l_err_msg);
      
        /*IF k.location_segment1 IS NOT NULL THEN*/
        /*        xxs3_data_transform_util_pkg1.transform(p_mapping_type          => 'fa_location_segment1'
                                                  ,p_stage_tab             => 'XX_FA_DISTRIBUTIONS'
                                                  , --Staging Table Name
                                                   p_stage_primary_col     => 'XX_FA_DIST_ID'
                                                  , --Staging Table Primary Column Name
                                                   p_stage_primary_col_val => k.xx_fa_dist_id
                                                  , --Staging Table Primary Column Value
                                                   p_legacy_val            => nvl(k.location_segment1,'NULL')
                                                  , --Legacy Value
                                                   p_stage_col             => 'S3_LOCATION_SEGMENT1'
                                                  , --Staging Table Name
                                                   p_err_code              => l_err_code
                                                  , -- Output error code
                                                   p_err_msg               => l_err_msg);
        \* END IF;*\
         \*IF k.location_segment2 IS NOT NULL THEN*\
           xxs3_data_transform_util_pkg1.transform(p_mapping_type          => 'fa_location_segment2'
                                                  ,p_stage_tab             => 'XX_FA_DISTRIBUTIONS'
                                                  , --Staging Table Name
                                                   p_stage_primary_col     => 'XX_FA_DIST_ID'
                                                  , --Staging Table Primary Column Name
                                                   p_stage_primary_col_val => k.xx_fa_dist_id
                                                  , --Staging Table Primary Column Value
                                                   p_legacy_val            => NVL(k.location_segment2,'NULL')
                                                  , --Legacy Value
                                                   p_stage_col             => 'S3_LOCATION_SEGMENT2'
                                                  , --Staging Table Name
                                                   p_err_code              => l_err_code
                                                  , -- Output error code
                                                   p_err_msg               => l_err_msg);
        \* END IF;*\
         \*IF k.location_segment3 IS NOT NULL THEN*\
           xxs3_data_transform_util_pkg1.transform(p_mapping_type          => 'fa_location_segment3'
                                                  ,p_stage_tab             => 'XX_FA_DISTRIBUTIONS'
                                                  , --Staging Table Name
                                                   p_stage_primary_col     => 'XX_FA_DIST_ID'
                                                  , --Staging Table Primary Column Name
                                                   p_stage_primary_col_val => k.xx_fa_dist_id
                                                  , --Staging Table Primary Column Value
                                                   p_legacy_val            => NVL(k.location_segment3,'NULL')
                                                  , --Legacy Value
                                                   p_stage_col             => 'S3_LOCATION_SEGMENT3'
                                                  , --Staging Table Name
                                                   p_err_code              => l_err_code
                                                  , -- Output error code
                                                   p_err_msg               => l_err_msg);*/
        /*END IF;*/
        /*IF k.book_type_code IS NOT NULL THEN*/
        xxs3_data_transform_util_pkg1.transform(p_mapping_type => 'fa_asset_book', p_stage_tab => 'XXS3_RTR_FA_DISTRIBUTIONS', --Staging Table Name
                                                p_stage_primary_col => 'XX_FA_DIST_ID', --Staging Table Primary Column Name
                                                p_stage_primary_col_val => k.xx_fa_dist_id, --Staging Table Primary Column Value
                                                p_legacy_val => nvl(k.book_type_code, 'NULL'), --Legacy Value
                                                p_stage_col => 'S3_BOOK_TYPE_CODE', --Staging Table Name
                                                p_err_code => l_err_code, -- Output error code
                                                p_err_msg => l_err_msg);
        /*END IF;*/
      
      
      
      
      
      EXCEPTION
        WHEN OTHERS THEN
          ROLLBACK;
          x_retcode := 2;
          x_errbuf  := 'Unexpected error in inserting Value while transforming asset distribution 1: ' ||
                       SQLERRM || dbms_utility.format_error_backtrace;
        
      END;
    
    END LOOP;
  
  
  
    FOR l IN (SELECT *
              FROM xxobjt.xxs3_rtr_fa_distributions
              WHERE process_flag IN ('Y', 'Q'))
    LOOP
      BEGIN
        IF l.s3_expense_acct_segment1 IS NOT NULL
        THEN
          UPDATE xxobjt.xxs3_rtr_fa_distributions
          SET s3_expense_account = l.s3_expense_acct_segment1 || '.' ||
                                   l.s3_expense_acct_segment2 || '.' ||
                                   l.s3_expense_acct_segment3 || '.' ||
                                   l.s3_expense_acct_segment4 || '.' ||
                                   l.s3_expense_acct_segment5 || '.' ||
                                   l.s3_expense_acct_segment6 || '.' ||
                                   l.s3_expense_acct_segment7 || '.' ||
                                   l.s3_expense_acct_segment8
          WHERE xx_fa_dist_id = l.xx_fa_dist_id;
        END IF;
      
      
        /*      IF l.s3_location_segment1 IS NOT NULL AND l.s3_location_segment2 IS NOT NULL AND
           l.s3_location_segment3 IS NOT NULL THEN
          UPDATE xxobjt.xx_fa_distributions
             SET s3_location = l.s3_location_segment1 || '.' || l.s3_location_segment2 || '.' ||
                               l.s3_location_segment3
           WHERE xx_fa_dist_id = l.xx_fa_dist_id;
        END IF;*/
      
      
      
      
      
      EXCEPTION
        WHEN OTHERS THEN
          ROLLBACK;
          x_retcode := 2;
          x_errbuf  := 'Unexpected error in inserting Value while transforming asset distribution 2: ' ||
                       SQLERRM || dbms_utility.format_error_backtrace;
        
      
      END;
    
    END LOOP;
  
    COMMIT;
  
  END distribution_extract_data;




  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Package is used for Fixed Assets Description Extract
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  TCS                           Initial build
  -- -------------------------------------------------------------------------------------------- 

  PROCEDURE description_extract_data(x_errbuf  OUT VARCHAR2
                                    ,x_retcode OUT NUMBER) AS
    l_err_code NUMBER;
    l_err_msg  VARCHAR2(100);
  
    CURSOR cur_transform IS
      SELECT xx_fa_desc_id
            ,category_segment1
            ,category_segment2
            ,asset_key_segment1
            ,asset_key_segment2
      FROM xxs3_rtr_fa_description
      WHERE process_flag IN ('Y', 'Q');
  
    CURSOR cur_fa_description IS
      SELECT fav.asset_id
            ,fav.asset_number
            ,fav.tag_number
            ,fav.description
            ,fav.asset_type
            ,fav.serial_number
            ,fcv.segment1 category_segment1
            ,fcv.segment2 category_segment2
            ,fak.segment1 asset_key_segment1
            ,fak.segment2 asset_key_segment2
            ,fav.current_units unit
            ,fav.manufacturer_name manufacturer
            ,fav.model_number model
            ,fav.in_use_flag in_use
            ,fav.inventorial in_physical_inventory
            ,fav.property_type_meaning property_type
            ,fav.owned_leased ownership
            ,fav.property_1245_1250_meaning property_class
            ,fav.new_used bought
            ,fav.lease_number
            ,fav.lessor
            ,fav.attribute1 existing_asset_number
            ,fav.attribute2 legacy_asset_number
            ,fav.attribute3 project_po_details
            ,fav.attribute_category_code
            ,fav.property_type_code
      FROM fa_additions_v    fav
          ,fa_categories_vl  fcv
          ,fa_asset_keywords fak
      WHERE fav.asset_category_id = fcv.category_id(+)
      AND fav.asset_key_ccid = fak.code_combination_id(+)
      AND (EXISTS (SELECT 1
                  FROM fa_books fab
                  WHERE fab.asset_id = fav.asset_id
                  AND fab.book_type_code = 'STRATASYS CORP') OR EXISTS
             (SELECT 1
              FROM fa_distribution_history fdh
              WHERE fdh.asset_id = fav.asset_id
              AND fdh.book_type_code = 'STRATASYS CORP'))
      AND NOT EXISTS
       (SELECT 1
             FROM fa_transaction_history_trx_v fth
             WHERE fth.asset_id = fav.asset_id
             AND fth.last_update_date =
                   (SELECT MAX(last_update_date)
                    FROM fa_transaction_history_trx_v fth1
                    WHERE fth1.asset_id = fth.asset_id)
             AND transaction_type_code = 'FULL RETIREMENT');
  
  BEGIN
  
    log_p('Truncating Asset Description Table...');
    EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.XXS3_RTR_FA_DESCRIPTION';
    EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.XXS3_RTR_FA_DESC_DQ';
  
  
    FOR i IN cur_fa_description
    LOOP
      BEGIN
      
        INSERT INTO xxobjt.xxs3_rtr_fa_description
          (xx_fa_desc_id
          ,date_extracted_on
          ,process_flag
          ,asset_id
          ,asset_number
          ,tag_number
          ,description
          ,asset_type
          ,serial_number
          ,category_segment1
          ,category_segment2
          ,asset_key_segment1
          ,asset_key_segment2
          ,unit
          ,manufacturer
          ,model
          ,in_use
          ,in_physical_inventory
          ,property_type
          ,ownership
          ,property_class
          ,bought
          ,lease_number
          ,lessor
          ,existing_asset_number
          ,legacy_asset_number
          ,project_po_details
          ,attribute_category_code
          ,property_type_code)
        VALUES
          (xxobjt.xxs3_rtr_fa_description_seq.NEXTVAL
          ,SYSDATE
          ,'N'
          ,i.asset_id
          ,i.asset_number
          ,i.tag_number
          ,i.description
          ,i.asset_type
          ,i.serial_number
          ,i.category_segment1
          ,i.category_segment2
          ,i.asset_key_segment1
          ,i.asset_key_segment2
          ,i.unit
          ,i.manufacturer
          ,i.model
          ,i.in_use
          ,i.in_physical_inventory
          ,i.property_type
          ,i.ownership
          ,i.property_class
          ,i.bought
          ,i.lease_number
          ,i.lessor
          ,i.existing_asset_number
          ,i.legacy_asset_number
          ,i.project_po_details
          ,i.attribute_category_code
          ,i.property_type_code);
      
      
      EXCEPTION
        WHEN OTHERS THEN
          x_errbuf := 'Error while Inserting into the table XXS3_RTR_FA_DESCRIPTION :' ||
                      SQLERRM;
        
          dbms_output.put_line(x_errbuf);
        
      
      END;
    
    END LOOP;
  
    log_p('Quality Check for Description...');
    quality_check_description(l_err_code, l_err_msg);
  
  
    log_p('Starting Transformation for Asset Description...');
  
    FOR k IN cur_transform
    LOOP
    
      BEGIN
        IF k.category_segment1 IS NOT NULL
        THEN
          xxs3_data_transform_util_pkg1.transform(p_mapping_type => 'fa_asset_category_segment1', p_stage_tab => 'XXS3_RTR_FA_DESCRIPTION', --Staging Table Name
                                                  p_stage_primary_col => 'XX_FA_DESC_ID', --Staging Table Primary Column Name
                                                  p_stage_primary_col_val => k.xx_fa_desc_id, --Staging Table Primary Column Value
                                                  p_legacy_val => k.category_segment1, --Legacy Value
                                                  p_stage_col => 'S3_CATEGORY_SEGMENT1', --Staging Table Name
                                                  p_err_code => l_err_code, -- Output error code
                                                  p_err_msg => l_err_msg);
        END IF;
      
      
        IF k.category_segment2 IS NOT NULL
        THEN
          xxs3_data_transform_util_pkg1.transform(p_mapping_type => 'fa_asset_category_segment2', p_stage_tab => 'XXS3_RTR_FA_DESCRIPTION', --Staging Table Name
                                                  p_stage_primary_col => 'XX_FA_DESC_ID', --Staging Table Primary Column Name
                                                  p_stage_primary_col_val => k.xx_fa_desc_id, --Staging Table Primary Column Value
                                                  p_legacy_val => k.category_segment2, --Legacy Value
                                                  p_stage_col => 'S3_CATEGORY_SEGMENT2', --Staging Table Name
                                                  p_err_code => l_err_code, -- Output error code
                                                  p_err_msg => l_err_msg);
        END IF;
      
      
        IF k.asset_key_segment1 IS NOT NULL
        THEN
          xxs3_data_transform_util_pkg1.transform(p_mapping_type => 'fa_asset_key_segment1', p_stage_tab => 'XXS3_RTR_FA_DESCRIPTION', --Staging Table Name
                                                  p_stage_primary_col => 'XX_FA_DESC_ID', --Staging Table Primary Column Name
                                                  p_stage_primary_col_val => k.xx_fa_desc_id, --Staging Table Primary Column Value
                                                  p_legacy_val => k.asset_key_segment1, --Legacy Value
                                                  p_stage_col => 'S3_ASSET_KEY_SEGMENT1', --Staging Table Name
                                                  p_err_code => l_err_code, -- Output error code
                                                  p_err_msg => l_err_msg);
        END IF;
      
      
        IF k.asset_key_segment2 IS NOT NULL
        THEN
          xxs3_data_transform_util_pkg1.transform(p_mapping_type => 'fa_asset_key_segment2', p_stage_tab => 'XXS3_RTR_FA_DESCRIPTION', --Staging Table Name
                                                  p_stage_primary_col => 'XX_FA_DESC_ID', --Staging Table Primary Column Name
                                                  p_stage_primary_col_val => k.xx_fa_desc_id, --Staging Table Primary Column Value
                                                  p_legacy_val => k.asset_key_segment2, --Legacy Value
                                                  p_stage_col => 'S3_ASSET_KEY_SEGMENT2', --Staging Table Name
                                                  p_err_code => l_err_code, -- Output error code
                                                  p_err_msg => l_err_msg);
        END IF;
      
      
      
      
      
      EXCEPTION
        WHEN OTHERS THEN
          ROLLBACK;
          x_retcode := 2;
          x_errbuf  := 'Unexpected error in inserting Value while transforming asset description 1: ' ||
                       SQLERRM || dbms_utility.format_error_backtrace;
        
      END;
    END LOOP;
  
  
  
    FOR l IN (SELECT *
              FROM xxobjt.xxs3_rtr_fa_description
              WHERE process_flag IN ('Y', 'Q'))
    LOOP
      BEGIN
      
        IF l.s3_category_segment1 IS NOT NULL
           AND l.s3_category_segment2 IS NOT NULL
        THEN
          UPDATE xxobjt.xxs3_rtr_fa_description
          SET s3_category = l.s3_category_segment1 || '.' ||
                            l.s3_category_segment2
          WHERE xx_fa_desc_id = l.xx_fa_desc_id;
        END IF;
      
      
        IF l.s3_asset_key_segment1 IS NOT NULL
           AND l.s3_asset_key_segment2 IS NOT NULL
        THEN
          UPDATE xxobjt.xxs3_rtr_fa_description
          SET s3_asset_key = l.s3_asset_key_segment1 || '.' ||
                             l.s3_asset_key_segment2
          WHERE xx_fa_desc_id = l.xx_fa_desc_id;
        END IF;
      
      
      
      EXCEPTION
        WHEN OTHERS THEN
          ROLLBACK;
          x_retcode := 2;
          x_errbuf  := 'Unexpected error in inserting Value while transforming asset description 2: ' ||
                       SQLERRM || dbms_utility.format_error_backtrace;
        
      END;
    END LOOP;
  
    log_p('Transformation for Asset Description completed...');
  
  
  END description_extract_data;




  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Package is used for Fixed Assets Books Extract
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  TCS                           Initial build
  -- -------------------------------------------------------------------------------------------- 

  PROCEDURE books_extract_data(x_errbuf  OUT VARCHAR2
                              ,x_retcode OUT NUMBER) AS
    l_err_code NUMBER;
    l_err_msg  VARCHAR2(100);
  
    CURSOR cur_transform IS
      SELECT xx_fa_books_id
            ,book_type_code
      FROM xx_fa_books
      WHERE process_flag IN ('Y', 'Q');
  
    CURSOR cur_fa_books IS
      SELECT fbv.asset_id
            ,fav.asset_number
            ,fbv.book_type_code
            ,fbv.group_asset_id group_asset
            ,fbv.cost current_cost
            ,fds.ytd_deprn ytd_depreciation
            ,fds.deprn_reserve accumulated_depreciation
            ,fbv.salvage_type salvage_value_type
            ,fbv.percent_salvage_value salvage_value_percent
            ,fbv.salvage_value
            ,fbv.deprn_method_code method
            ,fbv.basic_rate
            ,fbv.adjusted_rate
            ,fbv.life_in_months
            ,fbv.date_placed_in_service date_in_service
            ,fbv.prorate_convention_code prorate_convention
            ,fbv.depreciate_flag depreciate
            ,fbv.date_effective
            ,fbv.deprn_start_date
            ,fbv.eofy_adj_cost
            ,fbv.eofy_formula_factor
            ,fbv.eofy_reserve
            ,fav.attribute_category_code
            ,fbv.retirement_id
      FROM fa_books         fbv
          ,fa_deprn_summary fds
          ,fa_additions_v   fav
      WHERE fbv.asset_id = fav.asset_id
      AND fbv.asset_id = fds.asset_id
      AND fbv.book_type_code = fds.book_type_code
      AND fbv.book_type_code IN ('STRATASYS CORP' /*, 'STRATASYS AMT', 'STRATASYS FEDER', 'GENERIC'*/
            )
      AND fds.period_counter =
            (SELECT MAX(period_counter)
             FROM apps.fa_deprn_detail fdd2
             WHERE fdd2.asset_id = fds.asset_id
             AND fdd2.book_type_code = fds.book_type_code)
      AND fbv.date_ineffective IS NULL
      AND NOT EXISTS
       (SELECT 1
             FROM fa_transaction_history_trx_v fth
             WHERE fth.asset_id = fav.asset_id
             AND fth.last_update_date =
                   (SELECT MAX(last_update_date)
                    FROM fa_transaction_history_trx_v fth1
                    WHERE fth1.asset_id = fth.asset_id)
             AND transaction_type_code = 'FULL RETIREMENT');
  
  
  
  BEGIN
  
    log_p('Truncating Asset Books Table...');
    EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.XXS3_RTR_FA_BOOKS';
    EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.XXS3_RTR_FA_BOOKS_DQ';
  
  
    FOR i IN cur_fa_books
    LOOP
      BEGIN
      
        INSERT INTO xxobjt.xxs3_rtr_fa_books
          (xx_fa_books_id
          ,date_extracted_on
          ,process_flag
          ,asset_id
          ,asset_number
          ,book_type_code
          ,group_asset
          ,current_cost
          ,ytd_depreciation
          ,accumulated_depreciation
          ,salvage_value_type
          ,salvage_value_percent
          ,salvage_value
          ,method
          ,basic_rate
          ,adjusted_rate
          ,life_in_months
          ,date_in_service
          ,prorate_convention
          ,depreciate
          ,date_effective
          ,deprn_start_date
          ,eofy_adj_cost
          ,eofy_formula_factor
          ,eofy_reserve
          ,attribute_category_code
          ,retirement_id)
        VALUES
          (xxobjt.xxs3_rtr_fa_books_seq.NEXTVAL
          ,SYSDATE
          ,'N'
          ,i.asset_id
          ,i.asset_number
          ,i.book_type_code
          ,i.group_asset
          ,i.current_cost
          ,i.ytd_depreciation
          ,i.accumulated_depreciation
          ,i.salvage_value_type
          ,i.salvage_value_percent
          ,i.salvage_value
          ,i.method
          ,i.basic_rate
          ,i.adjusted_rate
          ,i.life_in_months
          ,i.date_in_service
          ,i.prorate_convention
          ,i.depreciate
          ,i.date_effective
          ,i.deprn_start_date
          ,i.eofy_adj_cost
          ,i.eofy_formula_factor
          ,i.eofy_reserve
          ,i.attribute_category_code
          ,i.retirement_id);
      
      
      EXCEPTION
        WHEN OTHERS THEN
          x_errbuf := 'Error while Inserting into the table XXS3_RTR_FA_BOOKS :' ||
                      SQLERRM;
        
          dbms_output.put_line(x_errbuf);
        
      END;
    
    END LOOP;
  
  
  
    log_p('Quality check for FA Books...');
    quality_check_books(l_err_code, l_err_msg);
  
  
    log_p('Starting Transformation for FA Books...');
  
    FOR k IN cur_transform
    LOOP
      BEGIN
      
        IF k.book_type_code IS NOT NULL
        THEN
          xxs3_data_transform_util_pkg1.transform(p_mapping_type => 'fa_asset_book', p_stage_tab => 'XXS3_RTR_FA_BOOKS', --Staging Table Name
                                                  p_stage_primary_col => 'XX_FA_BOOKS_ID', --Staging Table Primary Column Name
                                                  p_stage_primary_col_val => k.xx_fa_books_id, --Staging Table Primary Column Value
                                                  p_legacy_val => k.book_type_code, --Legacy Value
                                                  p_stage_col => 'S3_BOOK_TYPE_CODE', --Staging Table Name
                                                  p_err_code => l_err_code, -- Output error code
                                                  p_err_msg => l_err_msg);
        
        
        
        END IF;
      
      
      EXCEPTION
        WHEN OTHERS THEN
          ROLLBACK;
          x_retcode := 2;
          x_errbuf  := 'Unexpected error in inserting Value while transforming asset books 1: ' ||
                       SQLERRM || dbms_utility.format_error_backtrace;
        
      
      END;
    
    END LOOP;
  
  
    UPDATE xxs3_rtr_fa_books
    SET prorate_convention = 'SSYS MNTLY'
    WHERE process_flag != 'R';
  
  
    log_p('Transformation for FA Books completed...');
  
  
  END books_extract_data;




  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used for Fixed Asset Books Data Quality Report
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  29/07/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------


  PROCEDURE fa_books_report_data(p_entity_name IN VARCHAR2) AS
  
    CURSOR c_report IS
      SELECT xfb.xx_fa_books_id
            ,xfb.process_flag
            ,xfb.asset_id
            ,xfb.asset_number
            ,xfb.book_type_code
            ,xfb.attribute_category_code
            ,xfb.method
            ,xfb.basic_rate
            ,xfb.eofy_reserve
            ,xfb.depreciate
            ,xfq.rule_name
            ,xfq.notes
            ,decode(xfb.process_flag, 'R', 'Y', 'Q', 'N') reject_record
      FROM xxobjt.xxs3_rtr_fa_books    xfb
          ,xxobjt.xxs3_rtr_fa_books_dq xfq
      WHERE xfb.xx_fa_books_id = xfq.xx_fa_books_id
      AND process_flag IN ('R', 'Q')
      ORDER BY 1;
  
    p_delimiter     VARCHAR2(5) := '~';
    l_total_account NUMBER := 0;
    l_report_count  NUMBER := 0;
    l_reject_count  NUMBER := 0;
  
  BEGIN
  
    SELECT COUNT(1) INTO l_total_account FROM xxobjt.xxs3_rtr_fa_books;
  
    SELECT COUNT(1)
    INTO l_report_count
    FROM xxobjt.xxs3_rtr_fa_books
    WHERE process_flag IN ('R', 'Q');
  
    SELECT COUNT(1)
    INTO l_reject_count
    FROM xxobjt.xxs3_rtr_fa_books
    WHERE process_flag = 'R';
  
    out_p(rpad('Report name = Data Quality Error Report' || p_delimiter, 100, ' '));
    out_p(rpad('========================================' || p_delimiter, 100, ' '));
    out_p(rpad('Data Migration Object Name = ' || 'Fixed Asset Books' ||
               p_delimiter, 100, ' '));
    out_p('');
    out_p(rpad('Run date and time:    ' ||
               to_char(SYSDATE, 'dd-Mon-YYYY HH24:MI') || p_delimiter, 100, ' '));
    out_p(rpad('Total Record Count Having DQ Issues = ' || l_report_count ||
               p_delimiter, 100, ' '));
    out_p(rpad('Total Record Count Rejected =  ' || l_reject_count ||
               p_delimiter, 100, ' '));
  
    out_p('');
  
    out_p(rpad('Track Name', 10, ' ') || p_delimiter ||
          rpad('Entity Name', 12, ' ') || p_delimiter ||
          rpad('XX_FA_BOOKS_ID  ', 14, ' ') || p_delimiter ||
          rpad('ASSET ID', 10, ' ') || p_delimiter ||
          rpad('Asset Number', 13, ' ') || p_delimiter ||
          rpad('Book Type Code', 20, ' ') || p_delimiter ||
          rpad('Reject Record Flag(Y/N)', 25, ' ') || p_delimiter ||
          rpad('Rule Name', 35, ' ') || p_delimiter ||
          rpad('Reason Code', 100, ' '));
  
    FOR i IN c_report
    LOOP
      out_p(rpad('FA', 10, ' ') || p_delimiter ||
            rpad('FA BOOKS', 12, ' ') || p_delimiter ||
            rpad(i.xx_fa_books_id, 14, ' ') || p_delimiter ||
            rpad(i.asset_id, 10, ' ') || p_delimiter ||
            rpad(i.asset_number, 13, ' ') || p_delimiter ||
            rpad(i.book_type_code, 20, ' ') || p_delimiter ||
            rpad(i.reject_record, 25, ' ') || p_delimiter ||
            rpad(i.rule_name, 35, ' ') || p_delimiter ||
            rpad(i.notes, 100, ' '));
    END LOOP;
  
    out_p('');
    out_p('Stratasys Confidential' || p_delimiter);
  EXCEPTION
    WHEN OTHERS THEN
      log_p('Failed to generate report: ' || SQLERRM);
  END fa_books_report_data;



  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used for Fixed Asset Distribution Data Quality Report
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  29/07/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------


  PROCEDURE fa_dist_report_data(p_entity_name IN VARCHAR2) AS
  
    CURSOR c_report IS
      SELECT xfb.xx_fa_dist_id
            ,xfb.process_flag
            ,xfb.asset_id
            ,xfb.asset_number
            ,xfb.book_type_code
            ,xfb.summary_flag
            ,xfb.enabled_flag
            ,xfb.end_date_active
            ,xfd.rule_name
            ,xfd.notes
            ,decode(xfb.process_flag, 'R', 'Y', 'Q', 'N') reject_record
      FROM xxobjt.xxs3_rtr_fa_distributions xfb
          ,xxobjt.xxs3_rtr_fa_dist_dq       xfd
      WHERE xfb.xx_fa_dist_id = xfd.xx_fa_dist_id
      AND xfb.process_flag IN ('Q', 'R')
      ORDER BY 1;
  
    p_delimiter     VARCHAR2(5) := '~';
    l_total_account NUMBER := 0;
    l_report_count  NUMBER := 0;
    l_reject_count  NUMBER := 0;
  
  
  BEGIN
  
    SELECT COUNT(1)
    INTO l_total_account
    FROM xxobjt.xxs3_rtr_fa_distributions;
  
    SELECT COUNT(1)
    INTO l_report_count
    FROM xxobjt.xxs3_rtr_fa_distributions
    WHERE process_flag IN ('R', 'Q');
  
    SELECT COUNT(1)
    INTO l_reject_count
    FROM xxobjt.xxs3_rtr_fa_distributions
    WHERE process_flag = 'R';
  
  
    out_p(rpad('Report name = Data Quality Error Report' || p_delimiter, 100, ' '));
    out_p(rpad('========================================' || p_delimiter, 100, ' '));
    out_p(rpad('Data Migration Object Name = ' || 'FA DISTRIBUTION' ||
               p_delimiter, 100, ' '));
    out_p('');
    out_p(rpad('Run date and time:    ' ||
               to_char(SYSDATE, 'dd-Mon-YYYY HH24:MI') || p_delimiter, 100, ' '));
    out_p(rpad('Total Record Count Having DQ Issues = ' || l_report_count ||
               p_delimiter, 100, ' '));
    out_p(rpad('Total Record Count Rejected =  ' || l_reject_count ||
               p_delimiter, 100, ' '));
  
    out_p('');
  
    out_p(rpad('Track Name', 10, ' ') || p_delimiter ||
          rpad('Entity Name', 16, ' ') || p_delimiter ||
          rpad('XX_FA_DIST_ID', 14, ' ') || p_delimiter ||
          rpad('ASSET ID', 10, ' ') || p_delimiter ||
          rpad('Asset Number', 13, ' ') || p_delimiter ||
          rpad('Book Type Code', 20, ' ') || p_delimiter ||
          rpad('Reject Record Flag(Y/N)', 25, ' ') || p_delimiter ||
          rpad('Rule Name', 35, ' ') || p_delimiter ||
          rpad('Reason Code', 100, ' '));
  
    FOR i IN c_report
    LOOP
      out_p(rpad('FA', 10, ' ') || p_delimiter ||
            rpad('FA DISTRIBUTION', 16, ' ') || p_delimiter ||
            rpad(i.xx_fa_dist_id, 14, ' ') || p_delimiter ||
            rpad(i.asset_id, 10, ' ') || p_delimiter ||
            rpad(i.asset_number, 13, ' ') || p_delimiter ||
            rpad(i.book_type_code, 20, ' ') || p_delimiter ||
            rpad(i.reject_record, 25, ' ') || p_delimiter ||
            rpad(i.rule_name, 35, ' ') || p_delimiter ||
            rpad(i.notes, 100, ' '));
    END LOOP;
  
  
    out_p('');
    out_p('Stratasys Confidential' || p_delimiter);
  
  EXCEPTION
    WHEN OTHERS THEN
      log_p('Failed to generate report: ' || SQLERRM);
    
  
  END fa_dist_report_data;



  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used for Fixed Asset Description Data Quality Report
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  29/07/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE fa_desc_report_data(p_entity_name IN VARCHAR2) AS
  
    CURSOR c_report IS
      SELECT xfb.xx_fa_desc_id
            ,xfb.asset_id
            ,xfb.asset_number
            ,xfb.process_flag
            ,xfb.serial_number
            ,xfb.property_class
            ,xfb.property_type_code
            ,xfb.category_segment1
            ,xfb.category_segment2
            ,xfb.unit
            ,xfb.manufacturer
            ,attribute_category_code
            ,xfd.rule_name
            ,xfd.notes
            ,decode(xfb.process_flag, 'R', 'Y', 'Q', 'N') reject_record
      FROM xxobjt.xxs3_rtr_fa_description xfb
          ,xxobjt.xxs3_rtr_fa_desc_dq     xfd
      WHERE xfb.xx_fa_desc_id = xfd.xx_fa_desc_id
      AND xfb.process_flag IN ('Q', 'R')
      ORDER BY 1;
  
    /*   
    SELECT xfb.xx_fa_desc_id
          ,xfb.asset_id
          ,xfb.asset_number
          ,xfd.rule_name
          ,xfd.notes
      FROM xxobjt.XXS3_RTR_FA_DESCRIPTION xfb
          ,xxobjt.xxs3_fa_desc_dq   xfd
     WHERE xfb.xx_fa_desc_id = xfd.xx_fa_desc_id
       AND xfb.process_flag IN ('Q', 'R')
     ORDER BY 1;*/
  
    p_delimiter     VARCHAR2(5) := '~';
    l_total_account NUMBER := 0;
    l_report_count  NUMBER := 0;
    l_reject_count  NUMBER := 0;
  
  BEGIN
  
    SELECT COUNT(1)
    INTO l_total_account
    FROM xxobjt.xxs3_rtr_fa_description;
  
    SELECT COUNT(1)
    INTO l_report_count
    FROM xxobjt.xxs3_rtr_fa_description
    WHERE process_flag IN ('R', 'Q');
  
    SELECT COUNT(1)
    INTO l_reject_count
    FROM xxobjt.xxs3_rtr_fa_description
    WHERE process_flag = 'R';
  
  
    out_p(rpad('Report name = Data Quality Error Report' || p_delimiter, 100, ' '));
    out_p(rpad('========================================' || p_delimiter, 100, ' '));
    out_p(rpad('Data Migration Object Name = ' || 'FA DESCRIPTION' ||
               p_delimiter, 100, ' '));
    out_p('');
    out_p(rpad('Run date and time:    ' ||
               to_char(SYSDATE, 'dd-Mon-YYYY HH24:MI') || p_delimiter, 100, ' '));
    out_p(rpad('Total Record Count Having DQ Issues = ' || l_report_count ||
               p_delimiter, 100, ' '));
    out_p(rpad('Total Record Count Rejected =  ' || l_reject_count ||
               p_delimiter, 100, ' '));
  
    out_p('');
  
    out_p(rpad('Track Name', 10, ' ') || p_delimiter ||
          rpad('Entity Name', 14, ' ') || p_delimiter ||
          rpad('XX_FA_DESC_ID  ', 14, ' ') || p_delimiter ||
          rpad('ASSET ID', 10, ' ') || p_delimiter ||
          rpad('Asset Number', 13, ' ') || p_delimiter ||
          rpad('Reject Record Flag(Y/N)', 25, ' ') || p_delimiter ||
          rpad('Rule Name', 35, ' ') || p_delimiter ||
          rpad('Reason Code', 100, ' '));
  
    FOR i IN c_report
    LOOP
      out_p(rpad('FA', 10, ' ') || p_delimiter ||
            rpad('FA DESCRIPTION', 14, ' ') || p_delimiter ||
            rpad(i.xx_fa_desc_id, 14, ' ') || p_delimiter ||
            rpad(i.asset_id, 10, ' ') || p_delimiter ||
            rpad(i.asset_number, 13, ' ') || p_delimiter ||
            rpad(i.reject_record, 25, ' ') || p_delimiter ||
            rpad(i.rule_name, 35, ' ') || p_delimiter ||
            rpad(i.notes, 100, ' '));
    END LOOP;
  
  
    out_p('');
    out_p('Stratasys Confidential' || p_delimiter);
  
  EXCEPTION
    WHEN OTHERS THEN
      log_p('Failed to generate report: ' || SQLERRM);
  END fa_desc_report_data;





  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used for Fixed Asset Description Transform Report
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  29/07/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------


  PROCEDURE fa_desc_transform_report(p_entity_name IN VARCHAR2) AS
  
    CURSOR c_report IS
      SELECT xfb.xx_fa_desc_id
            ,xfb.asset_id
            ,xfb.asset_number
            ,xfb.asset_key_segment1
            ,xfb.asset_key_segment2
            ,xfb.s3_asset_key_segment1
            ,xfb.s3_asset_key_segment2
            ,xfb.category_segment1
            ,xfb.category_segment2
            ,xfb.s3_category_segment1
            ,xfb.s3_category_segment2
            ,xfb.transform_status
            ,xfb.transform_error
      FROM xxobjt.xxs3_rtr_fa_description xfb
      WHERE xfb.transform_status IN ('PASS', 'FAIL')
      ORDER BY 1;
  
    p_delimiter     VARCHAR2(5) := '~';
    l_total_account NUMBER := 0;
    l_pass_count    NUMBER := 0;
    l_fail_count    NUMBER := 0;
  
  BEGIN
  
    SELECT COUNT(1)
    INTO l_total_account
    FROM xxobjt.xxs3_rtr_fa_description
    WHERE process_flag IN ('Y', 'Q')
    AND transform_status IN ('PASS', 'FAIL');
  
    SELECT COUNT(1)
    INTO l_pass_count
    FROM xxobjt.xxs3_rtr_fa_description
    WHERE process_flag IN ('Y', 'Q')
    AND transform_status IN ('PASS');
  
    SELECT COUNT(1)
    INTO l_fail_count
    FROM xxobjt.xxs3_rtr_fa_description
    WHERE process_flag IN ('Y', 'Q')
    AND transform_status IN ('FAIL');
  
  
    out_p(rpad('Report name = Data Transformation Report' || p_delimiter, 100, ' '));
    out_p(rpad('========================================' || p_delimiter, 100, ' '));
    out_p(rpad('Data Migration Object Name = ' || 'FA Description' ||
               p_delimiter, 100, ' '));
    out_p('');
    out_p(rpad('Run date and time:    ' ||
               to_char(SYSDATE, 'dd-Mon-YYYY HH24:MI') || p_delimiter, 100, ' '));
    out_p(rpad('Total Record Count Success = ' || l_pass_count ||
               p_delimiter, 100, ' '));
    out_p(rpad('Total Record Count Failure = ' || l_fail_count ||
               p_delimiter, 100, ' '));
  
    out_p('');
  
    out_p(rpad('Track Name', 10, ' ') || p_delimiter ||
          rpad('Entity Name', 14, ' ') || p_delimiter ||
          rpad('XX_FA_DESC_ID', 14, ' ') || p_delimiter ||
          rpad('ASSET ID', 10, ' ') || p_delimiter ||
          rpad('Asset Number', 13, ' ') || p_delimiter ||
          rpad('Asset Key Segment1', 30, ' ') || p_delimiter ||
          rpad('Asset Key Segment2', 30, ' ') || p_delimiter ||
          rpad('S3 Asset Key Segment1', 30, ' ') || p_delimiter ||
          rpad('S3 Asset Key Segment2', 30, ' ') || p_delimiter ||
          rpad('Category Segment1', 30, ' ') || p_delimiter ||
          rpad('Category Segment2', 30, ' ') || p_delimiter ||
          rpad('S3 Category Segment1', 30, ' ') || p_delimiter ||
          rpad('S3 Category Segment2', 30, ' ') || p_delimiter ||
          rpad('Transform Status', 35, ' ') || p_delimiter ||
          rpad('Transform Error', 100, ' '));
  
    FOR i IN c_report
    LOOP
      out_p(rpad('FA', 10, ' ') || p_delimiter ||
            rpad('FA DESCRIPTION', 14, ' ') || p_delimiter ||
            rpad(i.xx_fa_desc_id, 14, ' ') || p_delimiter ||
            rpad(i.asset_id, 10, ' ') || p_delimiter ||
            rpad(i.asset_number, 13, ' ') || p_delimiter ||
            rpad(i.asset_key_segment1, 30, ' ') || p_delimiter ||
            rpad(i.asset_key_segment2, 30, ' ') || p_delimiter ||
            rpad(i.s3_asset_key_segment1, 30, ' ') || p_delimiter ||
            rpad(i.s3_asset_key_segment2, 30, ' ') || p_delimiter ||
            rpad(i.category_segment1, 30, ' ') || p_delimiter ||
            rpad(i.category_segment2, 30, ' ') || p_delimiter ||
            rpad(i.s3_category_segment1, 30, ' ') || p_delimiter ||
            rpad(i.s3_category_segment2, 30, ' ') || p_delimiter ||
            rpad(i.transform_status, 35, ' ') || p_delimiter ||
            rpad(i.transform_error, 100, ' '));
    END LOOP;
  
  
    out_p('');
    out_p('Stratasys Confidential' || p_delimiter);
  
  EXCEPTION
    WHEN OTHERS THEN
      log_p('Failed to generate report: ' || SQLERRM);
  END fa_desc_transform_report;



  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used for Fixed Asset Distribution Transform Report
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  29/07/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE fa_dist_transform_report(p_entity_name IN VARCHAR2) AS
  
    CURSOR c_report IS
      SELECT xfb.xx_fa_dist_id
            ,xfb.asset_id
            ,xfb.asset_number
            ,xfb.book_type_code
            ,xfb.s3_book_type_code
            ,xfb.location_segment1 || '.' || xfb.location_segment2 || '.' ||
             xfb.location_segment3 || '.' || xfb.location_segment4 || '.' ||
             xfb.location_segment5 legacy_location
             /*            ,xfb.location_segment2
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   ,xfb.location_segment3
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   ,xfb.location_segment4
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   ,xfb.location_segment5*/
             /*            ,xfb.s3_location_segment1
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   ,xfb.s3_location_segment2
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   ,xfb.s3_location_segment3*/
            ,s3_location
            ,xfb.expense_acct_segment1
            ,xfb.expense_acct_segment2
            ,xfb.expense_acct_segment3
            ,xfb.expense_acct_segment5
            ,xfb.expense_acct_segment6
            ,xfb.expense_acct_segment7
            ,xfb.expense_acct_segment9
            ,xfb.expense_acct_segment10
            ,xfb.s3_expense_acct_segment1
            ,xfb.s3_expense_acct_segment2
            ,xfb.s3_expense_acct_segment3
            ,xfb.s3_expense_acct_segment4
            ,xfb.s3_expense_acct_segment5
            ,xfb.s3_expense_acct_segment6
            ,xfb.s3_expense_acct_segment7
            ,xfb.s3_expense_acct_segment8
            ,xfb.transform_status
            ,xfb.transform_error
      FROM xxobjt.xxs3_rtr_fa_distributions xfb
      WHERE xfb.transform_status IN ('PASS', 'FAIL')
      AND process_flag IN ('Y', 'Q')
      ORDER BY 1;
  
    p_delimiter     VARCHAR2(5) := '~';
    l_total_account NUMBER := 0;
    l_pass_count    NUMBER := 0;
    l_fail_count    NUMBER := 0;
  
  BEGIN
  
    SELECT COUNT(1)
    INTO l_total_account
    FROM xxobjt.xxs3_rtr_fa_distributions
    WHERE process_flag IN ('Y', 'Q')
    AND transform_status IN ('PASS', 'FAIL');
  
    SELECT COUNT(1)
    INTO l_pass_count
    FROM xxobjt.xxs3_rtr_fa_distributions
    WHERE process_flag IN ('Y', 'Q')
    AND transform_status IN ('PASS');
  
    SELECT COUNT(1)
    INTO l_fail_count
    FROM xxobjt.xxs3_rtr_fa_distributions
    WHERE process_flag IN ('Y', 'Q')
    AND transform_status IN ('FAIL');
  
  
    out_p(rpad('Report name = Data Transformation Report' || p_delimiter, 100, ' '));
    out_p(rpad('========================================' || p_delimiter, 100, ' '));
    out_p(rpad('Data Migration Object Name = ' || 'FA Description' ||
               p_delimiter, 100, ' '));
    out_p('');
    out_p(rpad('Run date and time:    ' ||
               to_char(SYSDATE, 'dd-Mon-YYYY HH24:MI') || p_delimiter, 100, ' '));
    out_p(rpad('Total Record Count Success = ' || l_pass_count ||
               p_delimiter, 100, ' '));
    out_p(rpad('Total Record Count Failure = ' || l_fail_count ||
               p_delimiter, 100, ' '));
  
    out_p('');
  
    out_p(rpad('Track Name', 10, ' ') || p_delimiter ||
          rpad('Entity Name', 15, ' ') || p_delimiter ||
          rpad('XX_FA_DIST_ID', 14, ' ') || p_delimiter ||
          rpad('ASSET ID', 10, ' ') || p_delimiter ||
          rpad('Asset Number', 13, ' ') || p_delimiter ||
          rpad('Book Type Code', 20, ' ') || p_delimiter ||
          rpad('LEGACY_LOCATION', 30, ' ') || p_delimiter ||
          rpad('S3 LEGACY_LOCATION', 30, ' ') || p_delimiter ||
          rpad('expense_acct_segment1', 30, ' ') || p_delimiter ||
          rpad('expense_acct_segment2', 30, ' ') || p_delimiter ||
          rpad('expense_acct_segment3', 30, ' ') || p_delimiter ||
          rpad('expense_acct_segment5', 30, ' ') || p_delimiter ||
          rpad('expense_acct_segment6', 30, ' ') || p_delimiter ||
          rpad('expense_acct_segment7', 30, ' ') || p_delimiter ||
          rpad('expense_acct_segment9', 30, ' ') || p_delimiter ||
          rpad('expense_acct_segment10', 30, ' ') || p_delimiter ||
          rpad('S3_expense_acct_segment1', 30, ' ') || p_delimiter ||
          rpad('S3_expense_acct_segment2', 30, ' ') || p_delimiter ||
          rpad('S3_expense_acct_segment3', 30, ' ') || p_delimiter ||
          rpad('S3_expense_acct_segment4', 30, ' ') || p_delimiter ||
          rpad('S3_expense_acct_segment5', 30, ' ') || p_delimiter ||
          rpad('S3_expense_acct_segment6', 30, ' ') || p_delimiter ||
          rpad('S3_expense_acct_segment7', 30, ' ') || p_delimiter ||
          rpad('S3_expense_acct_segment8', 30, ' ') || p_delimiter ||
          rpad('Status', 35, ' ') || p_delimiter ||
          rpad('Error Message', 50, ' '));
  
    FOR i IN c_report
    LOOP
      out_p(rpad('FA', 10, ' ') || p_delimiter ||
            rpad('FA_DISTRIBUTION', 15, ' ') || p_delimiter ||
            rpad(i.xx_fa_dist_id, 14, ' ') || p_delimiter ||
            rpad(i.asset_id, 10, ' ') || p_delimiter ||
            rpad(i.asset_number, 13, ' ') || p_delimiter ||
            rpad(i.book_type_code, 20, ' ') || p_delimiter ||
            rpad(i.expense_acct_segment1, 30, ' ') || p_delimiter ||
            rpad(i.expense_acct_segment2, 30, ' ') || p_delimiter ||
            rpad(i.expense_acct_segment3, 30, ' ') || p_delimiter ||
            rpad(i.expense_acct_segment5, 30, ' ') || p_delimiter ||
            rpad(i.expense_acct_segment6, 30, ' ') || p_delimiter ||
            rpad(i.expense_acct_segment7, 30, ' ') || p_delimiter ||
            rpad(i.expense_acct_segment9, 30, ' ') || p_delimiter ||
            rpad(i.expense_acct_segment10, 30, ' ') || p_delimiter ||
            rpad(i.s3_expense_acct_segment1, 30, ' ') || p_delimiter ||
            rpad(i.s3_expense_acct_segment2, 30, ' ') || p_delimiter ||
            rpad(i.s3_expense_acct_segment3, 30, ' ') || p_delimiter ||
            rpad(i.s3_expense_acct_segment4, 30, ' ') || p_delimiter ||
            rpad(i.s3_expense_acct_segment5, 30, ' ') || p_delimiter ||
            rpad(i.s3_expense_acct_segment6, 30, ' ') || p_delimiter ||
            rpad(i.s3_expense_acct_segment7, 30, ' ') || p_delimiter ||
            rpad(i.s3_expense_acct_segment8, 30, ' ') || p_delimiter ||
            
            rpad(i.transform_status, 35, ' ') || p_delimiter ||
            rpad(i.transform_error, 50, ' '));
    END LOOP;
  
  
    out_p('');
    out_p('Stratasys Confidential' || p_delimiter);
  
  EXCEPTION
    WHEN OTHERS THEN
      log_p('Failed to generate report: ' || SQLERRM);
  END fa_dist_transform_report;





  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used for Fixed Asset Books Transform Report
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  29/07/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------


  PROCEDURE fa_books_transform_report(p_entity_name IN VARCHAR2) AS
  
    CURSOR c_report IS
      SELECT xfb.xx_fa_books_id
            ,xfb.asset_id
            ,xfb.asset_number
            ,xfb.book_type_code
            ,xfb.s3_book_type_code
            ,xfb.transform_status
            ,xfb.transform_error
      FROM xxobjt.xxs3_rtr_fa_books xfb
      WHERE xfb.transform_status IN ('PASS', 'FAIL')
      ORDER BY 1;
  
    p_delimiter     VARCHAR2(5) := '~';
    l_total_account NUMBER := 0;
    l_pass_count    NUMBER := 0;
    l_fail_count    NUMBER := 0;
  
  BEGIN
  
    SELECT COUNT(1)
    INTO l_total_account
    FROM xxobjt.xxs3_rtr_fa_books
    WHERE process_flag IN ('Y', 'Q')
    AND transform_status IN ('PASS', 'FAIL');
  
    SELECT COUNT(1)
    INTO l_pass_count
    FROM xxobjt.xxs3_rtr_fa_books
    WHERE process_flag IN ('Y', 'Q')
    AND transform_status IN ('PASS');
  
    SELECT COUNT(1)
    INTO l_fail_count
    FROM xxobjt.xxs3_rtr_fa_books
    WHERE process_flag IN ('Y', 'Q')
    AND transform_status IN ('FAIL');
  
  
    out_p(rpad('Report name = Data Transformation Report' || p_delimiter, 100, ' '));
    out_p(rpad('========================================' || p_delimiter, 100, ' '));
    out_p(rpad('Data Migration Object Name = ' || 'FA Books' ||
               p_delimiter, 100, ' '));
    out_p('');
    out_p(rpad('Run date and time:    ' ||
               to_char(SYSDATE, 'dd-Mon-YYYY HH24:MI') || p_delimiter, 100, ' '));
    out_p(rpad('Total Record Count Success = ' || l_pass_count ||
               p_delimiter, 100, ' '));
    out_p(rpad('Total Record Count Failure = ' || l_fail_count ||
               p_delimiter, 100, ' '));
  
    out_p('');
  
    out_p(rpad('Track Name', 10, ' ') || p_delimiter ||
          rpad('Entity Name', 11, ' ') || p_delimiter ||
          rpad('XX_FA_BOOKS_ID  ', 14, ' ') || p_delimiter ||
          rpad('ASSET ID', 10, ' ') || p_delimiter ||
          rpad('Asset Number', 13, ' ') || p_delimiter ||
          rpad('Book Type Code', 20, ' ') || p_delimiter ||
          rpad('S3 Book Type Code', 20, ' ') || p_delimiter ||
          rpad('Transform Status', 35, ' ') || p_delimiter ||
          rpad('Transform Error', 50, ' '));
  
    FOR i IN c_report
    LOOP
      out_p(rpad('FA', 10, ' ') || p_delimiter ||
            rpad('FA BOOKS', 11, ' ') || p_delimiter ||
            rpad(i.xx_fa_books_id, 14, ' ') || p_delimiter ||
            rpad(i.asset_id, 10, ' ') || p_delimiter ||
            rpad(i.asset_number, 13, ' ') || p_delimiter ||
            rpad(i.book_type_code, 20, ' ') || p_delimiter ||
            rpad(i.s3_book_type_code, 20, ' ') || p_delimiter ||
            rpad(i.transform_status, 35, ' ') || p_delimiter ||
            rpad(i.transform_error, 50, ' '));
    END LOOP;
  
  
    out_p('');
    out_p('Stratasys Confidential' || p_delimiter);
  
  EXCEPTION
    WHEN OTHERS THEN
      log_p('Failed to generate report: ' || SQLERRM);
  END fa_books_transform_report;

END xxs3_rtr_fixed_assets_pkg;
/
