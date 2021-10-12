CREATE OR REPLACE PACKAGE BODY xxs3_ptm_category_set_pkg

-- --------------------------------------------------------------------------------------------
-- Purpose: This Package is used for Item Category Set Extract, Quality Check and Report
--
-- --------------------------------------------------------------------------------------------
-- Ver  Date        Name                          Description
-- 1.0  18/05/2016  Santanu                           Initial build
-- --------------------------------------------------------------------------------------------

 AS

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure is used to write in concurrent log
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  Santanu                           Initial build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE log_p(p_msg VARCHAR2) IS
  BEGIN

    fnd_file.put_line(fnd_file.log, p_msg);
    /*dbms_output.put_line(i_msg);*/

  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log, 'Error in writting Log File. ' || SQLERRM);
  END log_p;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure is used to write in concurrent output
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  Santanu                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE out_p(p_msg VARCHAR2) IS
  BEGIN

    /*fnd_file.put_line(fnd_file.output, p_msg);*/
    dbms_output.put_line(p_msg);

  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log, 'Error in writting Output File. ' || SQLERRM);
  END out_p;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used for Item Category Set Data Quality Report Rules
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  Santanu                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE insert_update_cat_set_dq(p_xx_category_set_valid_cat_id NUMBER
                                    ,p_rule_name                    IN VARCHAR2
                                    ,p_reject_code                  IN VARCHAR2
                                    ,p_err_code                     OUT VARCHAR2
                                    ,p_err_msg                      OUT VARCHAR2) IS

  BEGIN

  /* Update for the DQ recrods with process flag Q*/

    UPDATE xxobjt.xxs3_ptm_category_set
       SET process_flag = 'Q'
     WHERE xx_category_set_valid_cat_id = p_xx_category_set_valid_cat_id;

  /*Insert for the DQ record details in the DQ stage table */

    INSERT INTO xxobjt.xxs3_ptm_category_set_dq
      (xx_dq_cat_set_valid_cat_id
      ,xx_category_set_valid_cat_id
      ,rule_name
      ,notes)
    VALUES
      (xxobjt.xxs3_ptm_cat_set_dq_seq.NEXTVAL
      ,p_xx_category_set_valid_cat_id
      ,p_rule_name
      ,p_reject_code);
    p_err_code := '0';
    p_err_msg  := '';

  EXCEPTION
    WHEN OTHERS THEN
      p_err_code := '2';
      p_err_msg  := 'SQLERRM: ' || SQLERRM;
      ROLLBACK;

  END insert_update_cat_set_dq;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used for Item Category Set Data Quality Reject Rules
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  Santanu                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE insert_update_cat_set_rej_dq(p_xx_category_set_valid_cat_id NUMBER
                                        ,p_rule_name                    IN VARCHAR2
                                        ,p_reject_code                  IN VARCHAR2
                                        ,p_err_code                     OUT VARCHAR2
                                        ,p_err_msg                      OUT VARCHAR2) IS

  BEGIN
   /* Update for the Reject recrods with process flag R*/
    UPDATE xxobjt.xxs3_ptm_category_set
       SET process_flag = 'R'
     WHERE xx_category_set_valid_cat_id = p_xx_category_set_valid_cat_id;

  /*Insert for the DQ Reject record details in the DQ stage table */

    INSERT INTO xxobjt.xxs3_ptm_category_set_dq
      (xx_dq_cat_set_valid_cat_id
      ,xx_category_set_valid_cat_id
      ,rule_name
      ,notes)
    VALUES
      (xxobjt.xxs3_ptm_cat_set_dq_seq.NEXTVAL
      ,p_xx_category_set_valid_cat_id
      ,p_rule_name
      ,p_reject_code);

    p_err_code := '0';
    p_err_msg  := '';

  EXCEPTION
    WHEN OTHERS THEN
      p_err_code := '2';
      p_err_msg  := 'SQLERRM: ' || SQLERRM;
      ROLLBACK;

  END insert_update_cat_set_rej_dq;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used for Item Category Set Data Quality Rules Checks
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  Santanu                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE quality_check_category_set(p_err_code OUT VARCHAR2
                                      ,p_err_msg  OUT VARCHAR2) IS
    l_status     VARCHAR2(10) := 'SUCCESS';
    l_check_rule VARCHAR2(10) := 'TRUE';

	/* Cursor for the DQ check */

    CURSOR cur_category_set IS
      SELECT *
	  FROM xxobjt.xxs3_ptm_category_set
	  WHERE process_flag = 'N';

  BEGIN
  /* Quality Check Section */

    FOR i IN cur_category_set LOOP
      l_status := 'SUCCESS';
      IF i.structure_name IS NULL THEN
        insert_update_cat_set_rej_dq(i.xx_category_set_valid_cat_id
                                    ,'EQT-028:Is Not Null'
                                    ,'Missing value ' || '' || 'for field ' || 'structure_name'
                                    ,p_err_code
                                    ,p_err_msg);
        l_status := 'ERR';
      END IF;
      IF i.segment1 IS NULL THEN
        insert_update_cat_set_rej_dq(i.xx_category_set_valid_cat_id
                                    ,'EQT-028:Is Not Null'
                                    ,'Missing value ' || '' || 'for field ' || 'SEGMENT1'
                                    ,p_err_code
                                    ,p_err_msg);
        l_status := 'ERR';
      END IF;
      IF i.enabled_flag IS NULL THEN
        insert_update_cat_set_rej_dq(i.xx_category_set_valid_cat_id
                                    ,'EQT-028:Is Not Null'
                                    ,'Missing value ' || '' || 'for field ' || 'ENABLED_FLAG'
                                    ,p_err_code
                                    ,p_err_msg);
        l_status := 'ERR';
      END IF;
      IF i.description IS NULL THEN
        insert_update_cat_set_rej_dq(i.xx_category_set_valid_cat_id
                                    ,'EQT-028:Is Not Null'
                                    ,'Missing value ' || '' || 'for field ' || 'DESCRIPTION'
                                    ,p_err_code
                                    ,p_err_msg);
        l_status := 'ERR';
      END IF;

      IF l_status <> 'ERR' THEN
        UPDATE xxobjt.xxs3_ptm_category_set
           SET process_flag = 'Y'
         WHERE xx_category_set_valid_cat_id = i.xx_category_set_valid_cat_id;
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
  END quality_check_category_set;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used for Item Category Set Extract
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  Santanu                           Initial build
  -- 1.1  05/01/2017  Sateesh                          'SSYS Import Tariff Code' Added for Dry Run 3 
  -- --------------------------------------------------------------------------------------------

  PROCEDURE extract_category_set(x_retcode OUT VARCHAR2
                                ,x_errbuf  OUT VARCHAR2) AS

    l_err_code NUMBER;
    l_err_msg  VARCHAR2(100);

	/* Main Cursor for the Extract Catagory set */

    CURSOR c_ptm_category_set IS
      SELECT set1.category_set_name
            ,set1.structure_name
            ,set1.description
            ,m.enabled_flag
            ,m.disable_date
            ,m.supplier_enabled_flag
            ,m.segment1
            ,m.segment2
            ,m.segment3
            ,m.segment4
            ,m.segment5
            ,m.segment6
            ,m.segment7
            ,m.segment8
            ,m.summary_flag
            ,m.start_date_active
            ,m.end_date_active
            ,m.attribute_category
        FROM mtl_categories m
            ,mtl_category_set_valid_cats mcs
            ,(SELECT mc.category_set_id
                    ,mc.category_set_name
                    ,mc.description
                    ,mc.structure_id
                    ,mc.structure_name
                    ,mc.control_level_disp
                    ,mc.default_category_id
                FROM mtl_category_sets_v mc
               WHERE mc.category_set_name IN
                     ('Class Category Set', 'Objet Embedded SW Version', 'Objet Studio SW Version',
                      'Objet INTRANSTAT Tariff Code', 'Product Hierarchy', 'Activity Analysis',
                      'Basis HASP', 'Commissions', 'CS Price Book Product Type',
                      'Japan Resin Pack Breakdown', 'Japan Unit of Measure Sign', --'AVA_TAX_CODE',
                      'Brand', 'DG Restriction Level','SSYS Import Tariff Code','CS Recommended stock','CS Category Set')) set1 --'SSYS Import Tariff Code'
       WHERE (m.category_id = mcs.category_id AND mcs.category_set_id = set1.category_set_id)
         AND nvl(m.disable_date, SYSDATE + 1) > SYSDATE -- m.STRUCTURE_ID = set1.structure_id
         AND (m.end_date_active IS NULL OR m.end_date_active > SYSDATE)
      UNION
      SELECT set1.category_set_name
            ,set1.structure_name
            ,set1.description
            ,m.enabled_flag
            ,m.disable_date
            ,m.supplier_enabled_flag
            ,m.segment1
            ,m.segment2
            ,m.segment3
            ,m.segment4
            ,m.segment5
            ,m.segment6
            ,m.segment7
            ,m.segment8
            ,m.summary_flag
            ,m.start_date_active
            ,m.end_date_active
            ,m.attribute_category
        FROM mtl_categories m
            , --mtl_category_set_valid_cats mcs,
             (SELECT mc.category_set_id
                    ,mc.category_set_name
                    ,mc.description
                    ,mc.structure_id
                    ,mc.structure_name
                    ,mc.control_level_disp
                    ,mc.default_category_id
                FROM mtl_category_sets_v mc
               WHERE mc.category_set_name IN
                     ('Class Category Set', 'Objet Embedded SW Version', 'Objet Studio SW Version',
                      'Objet INTRANSTAT Tariff Code', 'Product Hierarchy', 'Activity Analysis',
                      'Basis HASP', 'Commissions', 'CS Price Book Product Type',
                      'Japan Resin Pack Breakdown', 'Japan Unit of Measure Sign', --'AVA_TAX_CODE',
                      'Brand', 'DG Restriction Level','SSYS Import Tariff Code','CS Recommended stock','CS Category Set')) set1  --,'SSYS Import Tariff Code'
       WHERE m.structure_id = set1.structure_id
         AND nvl(m.disable_date, SYSDATE + 1) > SYSDATE
         AND (m.end_date_active IS NULL OR m.end_date_active > SYSDATE)
       ORDER BY 1;
       
    
  BEGIN

    mo_global.init('PO');
    mo_global.set_policy_context('M', NULL);
    x_retcode := 0;
    x_errbuf  := 'COMPLETE';

	/* Delete records before insert into stage table */
    DELETE FROM xxobjt.xxs3_ptm_category_set;

	/* Insert records in stage table */

    FOR i IN c_ptm_category_set LOOP
      INSERT INTO xxobjt.xxs3_ptm_category_set
      VALUES
        (xxobjt.xxs3_ptm_cat_set_seq.NEXTVAL
        ,SYSDATE
        ,'N'
        ,i.structure_name
        ,i.description
        ,i.enabled_flag
        ,i.disable_date
        ,i.supplier_enabled_flag
        ,i.segment1
        ,i.segment2
        ,i.segment3
        ,i.segment4
        ,i.segment5
        ,i.segment6
        ,i.segment7
        ,i.segment8
        ,i.summary_flag
        ,i.start_date_active
        ,i.end_date_active
        ,i.attribute_category
        ,NULL
        ,NULL
        ,i.category_set_name
        ,i.category_set_name
        ,NULL
        ,NULL);
    END LOOP;
    COMMIT;
	/* Calling Quality Check procedure */
    quality_check_category_set(l_err_code, l_err_msg);
    
      /*Transformation */
    BEGIN
       UPDATE xxobjt.xxs3_ptm_category_set
       SET s3_category_set_name='Applicable System'
       WHERE category_set_name='CS Price Book Product Type';
       /*
        UPDATE xxobjt.xxs3_ptm_category_set
       SET s3_category_set_name='CS Item Category'
       WHERE category_set_name='CS Category Set';*/
       
       
     EXCEPTION    
    WHEN OTHERS THEN
    fnd_file.put_line(fnd_file.log, 'Error in Transformation');
    END;
   
  END extract_category_set;
  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used for Item Category Set DQ Report
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  Santanu                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE dq_report_category_set(p_entity VARCHAR2) IS

  /* Variables */
    l_delimiter    VARCHAR2(5) := '~';
    l_err_msg      VARCHAR2(2000);
    l_count_dq     NUMBER;
    l_count_reject NUMBER;
  /*Cursor for the DQ Report */
    CURSOR c_report_category_set IS
      SELECT nvl(xcid.rule_name, ' ') rule_name
            ,nvl(xcid.notes, ' ') notes
            ,xci.xx_category_set_valid_cat_id
            ,xci.structure_name
            ,xci.segment1
            ,xci.enabled_flag
            ,xci.description
            ,decode(xci.process_flag, 'R', 'Y', 'Q', 'N') reject_record
        FROM xxs3_ptm_category_set    xci
            ,xxobjt.xxs3_ptm_category_set_dq xcid
       WHERE xci.xx_category_set_valid_cat_id = xcid.xx_category_set_valid_cat_id
         AND xci.process_flag IN ('Q', 'R')
       ORDER BY structure_name DESC;

  BEGIN
   IF p_entity = 'CATEGORY_SET' THEN
  /*Count of records */

    SELECT COUNT(1)
      INTO l_count_dq
      FROM xxs3_ptm_category_set xci
     WHERE xci.process_flag IN ('Q', 'R');

    SELECT COUNT(1)
      INTO l_count_reject
      FROM xxs3_ptm_category_set xci
     WHERE xci.process_flag = 'R';

  /* Reporting formate */
    out_p(rpad('Report name = Data Quality Error Report' || l_delimiter, 100, ' '));
    out_p(rpad('========================================' || l_delimiter, 100, ' '));
    out_p(rpad('Data Migration Object Name = ' || 'Category Set' || l_delimiter, 100, ' '));
    out_p( '');
    out_p(rpad('Run date and time:    ' || to_char(SYSDATE, 'dd-Mon-YYYY HH24:MI') ||
                           l_delimiter
                          ,100
                          ,' '));
    out_p(rpad('Total Record Count Having DQ Issues = ' || l_count_dq || l_delimiter
                          ,100
                          ,' '));
    out_p(rpad('Total Record Count Rejected =  ' || l_count_reject || l_delimiter
                          ,100
                          ,' '));

    out_p('');

    out_p(rpad('Track Name', 10, ' ') || l_delimiter || rpad('Entity Name', 13, ' ') ||
                      l_delimiter || rpad('XX_Category_Set_Valid_Cat_ID  ', 30, ' ') ||
                      l_delimiter || rpad('Structure Name', 25, ' ') || l_delimiter ||
                      /*rpad('segment1', 25, ' ') || l_delimiter || rpad('enabled_flag', 13, ' ') ||
                      l_delimiter || rpad('description', 30, ' ') || l_delimiter ||*/
                      rpad('Reject Record Flag(Y/N)', 25, ' ') || l_delimiter ||
                      rpad('Rule Name', 25, ' ') || l_delimiter || rpad('Reason Code', 50, ' '));

    FOR r_data IN c_report_category_set LOOP
      out_p(rpad('PTM', 10, ' ') || l_delimiter || rpad('CATEGORY_SET', 13, ' ') ||
                        l_delimiter || rpad(r_data.xx_category_set_valid_cat_id, 30, ' ') ||
                        l_delimiter || rpad(r_data.structure_name, 25, ' ') || l_delimiter ||
                        /*rpad(r_data.segment1, 25, ' ') || l_delimiter ||
                        rpad(r_data.enabled_flag, 13, ' ') || l_delimiter ||
                        rpad(r_data.description, 30, ' ') || l_delimiter ||*/
                        rpad(r_data.reject_record, 25, ' ') || l_delimiter ||
                        rpad(nvl(r_data.rule_name, 'NULL'), 25, ' ') || l_delimiter ||
                        rpad(nvl(r_data.notes, 'NULL'), 50, ' '));

    END LOOP;

    out_p('');
   out_p('Stratasys Confidential' || l_delimiter);
  END IF;
  END;
END xxs3_ptm_category_set_pkg;
/
