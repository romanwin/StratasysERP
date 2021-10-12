CREATE OR REPLACE PACKAGE xxs3_rtr_unearned_rev_pkg

-- --------------------------------------------------------------------------------------------
-- Purpose: This Package is used for GL Balances Extract, Quality Check and Report
--
-- --------------------------------------------------------------------------------------------
-- Ver  Date        Name                          Description
-- 1.0  29/07/2016  TCS                           Initial build
-- --------------------------------------------------------------------------------------------

 AS

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used for GL Balances Extract
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  29/07/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE unearned_revenue_extract(x_retcode OUT NUMBER
                                    ,x_errbuf  OUT VARCHAR2
                                    ,x_gl_date IN VARCHAR2);



  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used for GL Balance Data Quality Rules Check
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  29/07/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE quality_check_unearned_rev(p_err_code OUT VARCHAR2
                                      ,p_err_msg  OUT VARCHAR2);



  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure is used for GL Balances Transform Report
  --           
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  29/07/2016  TCS                           Initial build  
  -- --------------------------------------------------------------------------------------------

  PROCEDURE data_transform_report(p_entity VARCHAR2);



-- --------------------------------------------------------------------------------------------
-- Purpose: This Procedure is used for GL Balances Data Quality Report
--
-- --------------------------------------------------------------------------------------------
-- Ver  Date        Name                          Description
-- 1.0  29/07/2016  TCS                           Initial build
-- --------------------------------------------------------------------------------------------

-- PROCEDURE gl_balance_report_data(p_entity IN VARCHAR2);



END xxs3_rtr_unearned_rev_pkg;
/
CREATE OR REPLACE PACKAGE BODY xxs3_rtr_unearned_rev_pkg IS


  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Package is used to extract unearned revenues which are to be recongnized 
  -- in future periods
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  06/10/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------


  PROCEDURE log_p(p_msg VARCHAR2) IS
  BEGIN
  
    fnd_file.put_line(fnd_file.log
                     ,p_msg);
  
  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log
                       ,'Error in writting Log File. ' || SQLERRM);
  END log_p;



  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure is used to write in concurrent output
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  06/10/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE out_p(p_msg VARCHAR2) IS
  BEGIN
  
    fnd_file.put_line(fnd_file.output
                     ,p_msg);
  
  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log
                       ,'Error in writting Output File. ' || SQLERRM);
  END out_p;



  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used for GL Balances Data Quality Report
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  06/10/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  /* PROCEDURE unearned_rev_report_data(p_entity IN VARCHAR2) AS
  
    p_delimiter    VARCHAR2(5) := '~';
    l_err_msg      VARCHAR2(2000);
    l_count_dq     NUMBER;
    l_count_reject NUMBER;
  
    CURSOR c_dq_report IS
      SELECT nvl(xrurdq.rule_name, ' ') rule_name
            ,nvl(xrurdq.notes, ' ') notes
            ,xrur.xx_unearned_rev_id
            ,xrur.legacy_beg_bal_period
            ,xrur.segment1
            ,xrur.segment2
            ,xrur.segment3
            ,xrur.segment5
            ,xrur.segment6
            ,xrur.segment7
            ,xrur.segment10
            ,xrur.begin_balance_dr
            ,xrur.begin_balance_cr
            ,xrur.begin_balance_dr_beq
            ,xrur.begin_balance_cr_beq
            ,xrur.period_net_dr
            ,xrur.period_net_cr
            ,xrur.period_net_dr_beq
            ,xrur.period_net_cr_beq
            ,decode(xrur.process_flag, 'R', 'Y', 'Q', 'N') reject_record
      FROM xxs3_rtr_unearned_rev    xrur
          ,xxs3_rtr_unearned_rev_dq xrurdq
      WHERE xrur.xx_unearned_rev_id = xrurdq.xx_unearned_rev_id
      AND xrur.process_flag IN ('Q', 'R');
  
  BEGIN
  
    SELECT COUNT(1)
    INTO l_count_dq
    FROM xxs3_rtr_unearned_rev xxur
    WHERE xrur.process_flag IN ('Q', 'R');
  
    SELECT COUNT(1)
    INTO l_count_reject
    FROM xxs3_rtr_unearned_rev xxur
    WHERE xrur.process_flag = 'R';
  
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
          rpad('XX GLB Id', 14, ' ') || p_delimiter ||
          rpad('Period Name', 15, ' ') || p_delimiter ||
          rpad('Segment1', 15, ' ') || p_delimiter ||
          rpad('Segment2', 15, ' ') || p_delimiter ||
          rpad('Segment3', 15, ' ') || p_delimiter ||
          rpad('Segment5', 15, ' ') || p_delimiter ||
          rpad('Segment6', 15, ' ') || p_delimiter ||
          rpad('Segment7', 15, ' ') || p_delimiter ||
          rpad('Segment10', 15, ' ') || p_delimiter ||
          rpad('Beginning Balance DR', 25, ' ') || p_delimiter ||
          rpad('Beginning Balance CR', 25, ' ') || p_delimiter ||
          rpad('Beginning Balance DR BEQ', 25, ' ') || p_delimiter ||
          rpad('Beginning Balance CR BEQ', 25, ' ') || p_delimiter ||
          rpad('Period Net DR', 15, ' ') || p_delimiter ||
          rpad('Period Net CR', 15, ' ') || p_delimiter ||
          rpad('Period Net DR BEQ', 25, ' ') || p_delimiter ||
          rpad('Period Net CR BEQ', 25, ' ') || p_delimiter ||
          rpad('Reject Record Flag(Y/N)', 22, ' ') || p_delimiter ||
          rpad('Rule Name', 150, ' ') || p_delimiter ||
          rpad('Reason Code', 250, ' '));
  
    FOR r_data IN c_dq_report
    LOOP
      out_p(rpad('RTR', 10, ' ') || p_delimiter ||
            rpad('GL_BALANCES', 11, ' ') || p_delimiter ||
            rpad(r_data.xx_unearned_rev_id, 14, ' ') || p_delimiter ||
            rpad(r_data.legacy_beg_bal_period, 10, ' ') || p_delimiter ||
            rpad(r_data.segment1, 15, ' ') || p_delimiter ||
            rpad(r_data.segment2, 15, ' ') || p_delimiter ||
            rpad(r_data.segment3, 15, ' ') || p_delimiter ||
            rpad(r_data.segment5, 15, ' ') || p_delimiter ||
            rpad(r_data.segment6, 15, ' ') || p_delimiter ||
            rpad(r_data.segment7, 15, ' ') || p_delimiter ||
            rpad(r_data.begin_balance_dr, 25, ' ') || p_delimiter ||
            rpad(r_data.begin_balance_cr, 25, ' ') || p_delimiter ||
            rpad(r_data.begin_balance_dr_beq, 25, ' ') || p_delimiter ||
            rpad(r_data.begin_balance_cr_beq, 25, ' ') || p_delimiter ||
            rpad(r_data.begin_balance_dr_beq, 25, ' ') || p_delimiter ||
            rpad(r_data.period_net_dr, 15, ' ') || p_delimiter ||
            rpad(r_data.period_net_cr, 15, ' ') || p_delimiter ||
            rpad(r_data.period_net_dr_beq, 25, ' ') || p_delimiter ||
            rpad(r_data.period_net_cr_beq, 25, ' ') || p_delimiter ||
            rpad(r_data.reject_record, 22, ' ') || p_delimiter ||
            rpad(nvl(r_data.rule_name, 'NULL'), 150, ' ') || p_delimiter ||
            rpad(nvl(r_data.notes, 'NULL'), 250, ' '));
    
    END LOOP;
  
    out_p('');
    out_p('Stratasys Confidential' || p_delimiter);
  
  END unearned_rev_report_data;*/




  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used for Gl Balances Data Quality Report Rules
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  06/10/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE insert_update_unearned_rev_dq(p_xx_unearned_rev_id NUMBER
                                         ,p_rule_name          IN VARCHAR2
                                         ,p_reject_code        IN VARCHAR2
                                         ,p_err_code           OUT VARCHAR2
                                         ,p_err_msg            OUT VARCHAR2) IS
  
  BEGIN
  
    UPDATE xxobjt.xxs3_rtr_unearned_rev
    SET process_flag = 'Q'
    WHERE xx_unearned_rev_id = p_xx_unearned_rev_id;
  
    INSERT INTO xxs3_rtr_unearned_rev_dq
      (xx_unearned_rev_dq_id
      ,xx_unearned_rev_id
      ,rule_name
      ,notes)
    VALUES
      (xxobjt.xxs3_rtr_unearned_rev_dq_seq.NEXTVAL
      ,p_xx_unearned_rev_id
      ,p_rule_name
      ,p_reject_code);
  
    p_err_code := '0';
    p_err_msg  := '';
  
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code := '2';
      p_err_msg  := 'SQLERRM: ' || SQLERRM;
      ROLLBACK;
    
  END insert_update_unearned_rev_dq;




  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure is used for GL Balances Transform Report
  --           
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  06/10/2016  TCS                           Initial build  
  -- --------------------------------------------------------------------------------------------

  PROCEDURE data_transform_report(p_entity VARCHAR2) IS
  
    p_delimiter     VARCHAR2(5) := '~';
    l_err_msg       VARCHAR2(2000);
    l_count_success NUMBER;
    l_count_fail    NUMBER;
  
    CURSOR c_report_glb IS
      SELECT glb.xx_glb_id
            ,glb.legacy_beg_bal_period
            ,glb.segment1
            ,glb.s3_company
            ,glb.segment2
            ,glb.s3_business_unit
            ,glb.segment3
            ,glb.s3_department
            ,glb.segment5
            ,glb.s3_account
            ,glb.segment6
            ,glb.s3_product_line
            ,glb.segment7
            ,glb.s3_location
            ,glb.segment10
            ,glb.s3_intercompany
            ,glb.s3_future
            ,glb.transform_status
            ,glb.transform_error
      FROM xxs3_rtr_gl_balances glb
      WHERE glb.transform_status IN ('PASS', 'FAIL');
  
  BEGIN
  
    SELECT COUNT(1)
    INTO l_count_success
    FROM xxs3_rtr_gl_balances glb
    WHERE glb.transform_status = 'PASS';
  
    SELECT COUNT(1)
    INTO l_count_fail
    FROM xxs3_rtr_gl_balances glb
    WHERE glb.transform_status = 'FAIL';
  
    out_p(rpad('Report name = Data Transformation Report' || p_delimiter
              ,100
              ,' '));
    out_p(rpad('========================================' || p_delimiter
              ,100
              ,' '));
    out_p(rpad('Data Migration Object Name = ' || p_entity || p_delimiter
              ,100
              ,' '));
    out_p('');
    out_p(rpad('Run date and time:    ' ||
               to_char(SYSDATE
                      ,'dd-Mon-YYYY HH24:MI') || p_delimiter
              ,100
              ,' '));
    out_p(rpad('Total Record Count Success = ' || l_count_success ||
               p_delimiter
              ,100
              ,' '));
    out_p(rpad('Total Record Count Failure = ' || l_count_fail ||
               p_delimiter
              ,100
              ,' '));
  
    out_p('');
  
    out_p(rpad('Track Name'
              ,10
              ,' ') || p_delimiter ||
          rpad('Entity Name'
              ,11
              ,' ') || p_delimiter ||
          rpad('xx GLB Id'
              ,14
              ,' ') || p_delimiter ||
          rpad('Period Name'
              ,15
              ,' ') || p_delimiter ||
          rpad('Legacy Segment1'
              ,15
              ,' ') || p_delimiter ||
          rpad('S3 Company  '
              ,15
              ,' ') || p_delimiter ||
          rpad('Legacy Segment2'
              ,15
              ,' ') || p_delimiter ||
          rpad('S3 Business Unit  '
              ,15
              ,' ') || p_delimiter ||
          rpad('Legacy Segment3'
              ,15
              ,' ') || p_delimiter ||
          rpad('S3 Department   '
              ,15
              ,' ') || p_delimiter ||
          rpad('Legacy Segment5'
              ,15
              ,' ') || p_delimiter ||
          rpad('S3 Account'
              ,15
              ,' ') || p_delimiter ||
          rpad('Legacy Segment6'
              ,15
              ,' ') || p_delimiter ||
          rpad('S3 Product Line'
              ,15
              ,' ') || p_delimiter ||
          rpad('Legacy Segment7'
              ,15
              ,' ') || p_delimiter ||
          rpad('S3 Location'
              ,15
              ,' ') || p_delimiter ||
          rpad('Legacy Segment10'
              ,15
              ,' ') || p_delimiter ||
          rpad('S3 Intercompany'
              ,15
              ,' ') || p_delimiter ||
          rpad('S3 Future'
              ,15
              ,' ') || p_delimiter ||
          rpad('Status'
              ,10
              ,' ') || p_delimiter ||
          rpad('Error Message'
              ,200
              ,' '));
  
    FOR r_data IN c_report_glb
    LOOP
      out_p(rpad('RTR'
                ,10
                ,' ') || p_delimiter ||
            rpad('GL_BALANCES'
                ,11
                ,' ') || p_delimiter ||
            rpad(r_data.xx_glb_id
                ,14
                ,' ') || p_delimiter ||
            rpad(r_data.legacy_beg_bal_period
                ,15
                ,' ') || p_delimiter ||
            rpad(r_data.segment1
                ,10
                ,' ') || p_delimiter ||
            rpad(r_data.s3_company
                ,10
                ,' ') || p_delimiter ||
            rpad(r_data.segment2
                ,10
                ,' ') || p_delimiter ||
            rpad(r_data.s3_business_unit
                ,10
                ,' ') || p_delimiter ||
            rpad(r_data.segment3
                ,10
                ,' ') || p_delimiter ||
            rpad(r_data.s3_department
                ,10
                ,' ') || p_delimiter ||
            rpad(r_data.segment5
                ,10
                ,' ') || p_delimiter ||
            rpad(r_data.s3_account
                ,10
                ,' ') || p_delimiter ||
            rpad(r_data.segment6
                ,10
                ,' ') || p_delimiter ||
            rpad(r_data.s3_product_line
                ,10
                ,' ') || p_delimiter ||
            rpad(r_data.segment7
                ,10
                ,' ') || p_delimiter ||
            rpad(r_data.s3_location
                ,10
                ,' ') || p_delimiter ||
            rpad(r_data.segment10
                ,10
                ,' ') || p_delimiter ||
            rpad(r_data.s3_intercompany
                ,10
                ,' ') || p_delimiter ||
            rpad(r_data.s3_future
                ,10
                ,' ') || p_delimiter ||
            rpad(r_data.transform_status
                ,10
                ,' ') || p_delimiter ||
            rpad(nvl(r_data.transform_error
                    ,'NULL')
                ,200
                ,' '));
    END LOOP;
  
    out_p('');
    out_p('Stratasys Confidential' || p_delimiter);
  END;




  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used for Unearned Revenue Data Quality Rules Check
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  07/11/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE quality_check_unearned_rev(p_err_code OUT VARCHAR2
                                      ,p_err_msg  OUT VARCHAR2) IS
  
  
    l_status     VARCHAR2(10) := 'SUCCESS';
    l_check_rule VARCHAR2(10) := 'TRUE';
  
    CURSOR c_unearned_rev_qc IS
      SELECT * FROM xxobjt.xxs3_rtr_unearned_rev WHERE process_flag = 'N';
  
    CURSOR c_unearned_rev_line_qc IS
      SELECT legacy_customer_trx_line_id
            ,SUM(accounted_dr)
            ,SUM(accounted_cr)
      FROM xxobjt.xxs3_rtr_unearned_rev
      WHERE process_flag = 'N'
      GROUP BY legacy_customer_trx_line_id;
  
  
  BEGIN
  
    FOR i IN c_unearned_rev_qc
    LOOP
      l_status     := 'SUCCESS';
      l_check_rule := 'TRUE';
    
    
    
      l_check_rule := xxs3_dq_util_pkg.eqt_909;
    
      IF l_check_rule = 'FALSE'
      THEN
      
        insert_update_unearned_rev_dq(i.xx_unearned_rev_id
                                     ,'EQT_909:Sum of Accounted DR = Sum of Accounted CR'
                                     ,'Sum of Accounted DR <> Sum of Accounted CR'
                                     ,p_err_code
                                     ,p_err_msg);
        l_status := 'ERR';
      
      END IF;
    
    
      IF l_status <> 'ERR'
      THEN
        UPDATE xxs3_rtr_unearned_rev
        SET process_flag = 'Y'
        WHERE xx_unearned_rev_id = i.xx_unearned_rev_id;
      END IF;
    END LOOP;
  
  
    COMMIT;
  
  
    FOR i IN c_unearned_rev_line_qc
    LOOP
      l_status     := 'SUCCESS';
      l_check_rule := 'TRUE';
    
    
    
      l_check_rule := xxs3_dq_util_pkg.eqt_910(i.legacy_customer_trx_line_id);
    
      IF l_check_rule = 'FALSE'
      THEN
      
        FOR j IN (SELECT xx_unearned_rev_id
                  FROM xxs3_rtr_unearned_rev
                  WHERE legacy_customer_trx_line_id =
                        i.legacy_customer_trx_line_id)
        LOOP
        
          insert_update_unearned_rev_dq(j.xx_unearned_rev_id
                                       ,'EQT_910:Sum of Accounted DR for invoice line = Sum of Accounted CR for invoice line'
                                       ,'Sum of Accounted DR for invoice line <> Sum of Accounted CR for invoice line'
                                       ,p_err_code
                                       ,p_err_msg);
          l_status := 'ERR';
        
        END LOOP;
      
      END IF;
    
    
      COMMIT;
    
      IF l_status <> 'ERR'
      THEN
        UPDATE xxs3_rtr_unearned_rev
        SET process_flag = 'Y'
        WHERE legacy_customer_trx_line_id = i.legacy_customer_trx_line_id;
      END IF;
    END LOOP;
  
    COMMIT;
  
  END quality_check_unearned_rev;




  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used to extract unearned revenues which are to be recongnized 
  -- in future periods
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  06/10/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE unearned_revenue_extract(x_retcode OUT NUMBER
                                    ,x_errbuf  OUT VARCHAR2
                                    ,x_gl_date IN VARCHAR2) AS
  
  
    l_err_code               NUMBER;
    l_err_msg                VARCHAR2(100);
    l_error_message          VARCHAR2(2000);
    l_gl_date                DATE;
    l_s3_gl_string           VARCHAR2(200);
    l_output_code            NUMBER;
    l_output_code_coa_update NUMBER;
    l_output                 VARCHAR2(100);
    l_output_coa_update      VARCHAR2(100);
    l_step                   VARCHAR2(100);
    l_org_id                 NUMBER := fnd_global.org_id;
    l_ledger_id              NUMBER;
    l_s3_product_line        VARCHAR2(25);
    l_gl_date_char           VARCHAR2(25);
  
  
  
    CURSOR c_unearned_rev_transform IS
      SELECT xrur.* FROM xxobjt.xxs3_rtr_unearned_rev xrur;
  
    CURSOR c_unearned_rev(p_gl_date DATE) IS
      SELECT xah.ledger_id
            ,rba.NAME AS SOURCE
            ,account_class
            ,dist.gl_date
            ,arh.customer_trx_id legacy_customer_trx_id
            ,arl.customer_trx_line_id legacy_customer_trx_line_id
            ,arh.trx_number
            ,line_number
            ,im.segment1 AS item_number
            ,arl.description
            ,cc.segment1 AS legacy_company
            ,cc.segment2 AS legacy_department
            ,cc.segment3 AS legacy_account
            ,cc.segment5 AS legacy_product
            ,cc.segment6 AS legacy_location
            ,cc.segment7 AS legacy_intercompany
            ,cc.segment10 AS legacy_division
            ,arh.org_id AS legacy_org_id
            ,xah.accounting_date
            ,'SSYS Conversion' AS user_je_source_name
            ,'SSYS Unearned AR CONV' AS user_je_category_name
            ,'USD' AS currency_code
            ,balance_type_code AS actual_flag
            ,NULL AS s3_company
            , -- to be assigned via CoA Mapping
             NULL AS s3_business_unit
            , -- to be assigned via CoA Mapping
             NULL AS s3_department
            , -- to be assigned via CoA Mapping
             NULL AS s3_account
            , -- to be assigned via CoA Mapping
             NULL AS s3_product
            , -- to be assigned via CoA Mapping
             NULL AS s3_location
            , -- to be assigned via CoA Mapping
             NULL AS s3_intercompany
            , -- to be assigned via CoA Mapping
             NULL AS s3_future
            , -- to be assigned via CoA Mapping
             xdl.unrounded_accounted_dr AS accounted_dr
            ,xdl.unrounded_accounted_cr AS accounted_cr
            ,arh.trx_number || ' - ' || arl.line_number || ' - ' ||
             to_char(dist.gl_date
                    ,'YYYYMM') || ' - ' || dist.account_class AS reference1
      FROM xla_ae_headers               xah
          ,xla_ae_lines                 xal
          ,gl_code_combinations         cc
          ,xla_distribution_links       xdl
          ,ra_cust_trx_line_gl_dist_all dist
          ,ra_customer_trx_lines_all    arl
          ,ra_customer_trx_all          arh
          ,ra_batch_sources_all         rba
          ,mtl_system_items_b           im
      WHERE xal.ae_header_id = xah.ae_header_id
      AND xal.application_id = xah.application_id
      AND xah.application_id = 222
      AND xal.code_combination_id = cc.code_combination_id
      AND balance_type_code = 'A'
           --and gl_transfer_status_code = 'Y'
      AND xal.ae_header_id = xdl.ae_header_id
      AND xal.ae_line_num = xdl.ae_line_num
      AND xdl.source_distribution_type = 'RA_CUST_TRX_LINE_GL_DIST_ALL'
      AND xdl.source_distribution_id_num_1 = dist.cust_trx_line_gl_dist_id
      AND xdl.application_id = xah.application_id
      AND dist.customer_trx_line_id = arl.customer_trx_line_id
      AND arl.customer_trx_id = arh.customer_trx_id
      AND arh.org_id = l_org_id
      AND arh.org_id = arl.org_id
      AND arl.org_id = dist.org_id
      AND arl.inventory_item_id = im.inventory_item_id(+)
      AND im.organization_id(+) = 91
      AND arh.batch_source_id = rba.batch_source_id
      AND arh.org_id = rba.org_id
      AND xah.ledger_id = l_ledger_id
      AND xah.ledger_id = xal.ledger_id
      AND nvl(source_distribution_id_num_2
            ,(-99)) = -99
      AND account_class IN ('REV', 'UNEARN')
           --  and cc.segment1 = '26'  -- for performance
      AND arl.accounting_rule_id !=
            (SELECT rule_id FROM ra_rules WHERE NAME = 'Immediate')
      AND xah.accounting_date >= p_gl_date -- replace with parameter - cutover date. should be first of the month
      AND xal.accounting_date >= p_gl_date -- replace with parameter - cutover date. should be first of the month
      ORDER BY arh.trx_number
              ,line_number
              ,dist.gl_date
              ,dist.account_class;
  
  
    --  TYPE fetch_master IS TABLE OF c_unearned_rev%ROWTYPE;
    --  bulk_master fetch_master;
  
  
  
  
    ----------------------------------------------
  
  BEGIN
  
    log_p('Truncating tables...');
    EXECUTE IMMEDIATE 'TRUNCATE TABLE XXOBJT.XXS3_RTR_UNEARNED_REV';
    EXECUTE IMMEDIATE 'TRUNCATE TABLE XXOBJT.XXS3_RTR_UNEARNED_REV_DQ';
  
  
    log_p('Uneraned Revenue Extract for Organization : ' || l_org_id);
  
    l_gl_date := fnd_date.canonical_to_date(x_gl_date);
    log_p('Uneraned Revenue Extract after GL Date  : ' || l_gl_date);
  
    SELECT (SELECT ledger_id
            FROM gl_ledgers
            WHERE NAME = mo_utils.get_ledger_name(l_org_id))
    INTO l_ledger_id
    FROM dual;
  
  
    log_p('Uneraned Revenue Extract for Ledger : ' || l_ledger_id);
    log_p('Uneraned Revenue Data Extraction starting... : ');
  
    BEGIN
    
      -- OPEN c_unearned_rev(l_gl_date);
    
      FOR i IN c_unearned_rev(l_gl_date)
      
      LOOP
        /* FETCH c_unearned_rev BULK COLLECT
          INTO bulk_master LIMIT 10000;
        EXIT WHEN bulk_master.COUNT = 0;
        
        FORALL i IN 1 .. bulk_master.COUNT SAVE EXCEPTIONS
          INSERT INTO getpaid.arpay_sch_id_7i6 VALUES bulk_master (i);
        
        COMMIT;*/
      
      
        INSERT INTO xxobjt.xxs3_rtr_unearned_rev
          (xx_unearned_rev_id
          ,date_extracted_on
          ,process_flag
          ,legacy_ledger_id
          ,s3_ledger_id
          ,SOURCE
          ,account_class
          ,gl_date
          ,legacy_customer_trx_id
          ,legacy_customer_trx_line_id
          ,trx_number
          ,line_number
          ,item_number
          ,description
          ,legacy_company
          ,legacy_department
          ,legacy_account
          ,legacy_product
          ,legacy_location
          ,legacy_intercompany
          ,legacy_division
          ,legacy_org_id
          ,accounting_date
          ,user_je_source_name
          ,user_je_category_name
          ,currency_code
          ,actual_flag
          ,accounted_dr
          ,accounted_cr
          ,reference1)
        VALUES
          (xxobjt.xxs3_rtr_unearned_rev_seq.NEXTVAL
          ,SYSDATE
          ,'N'
          ,l_ledger_id
          ,NULL
          ,i.SOURCE
          ,i.account_class
          ,i.gl_date
          ,i.legacy_customer_trx_id
          ,i.legacy_customer_trx_line_id
          ,i.trx_number
          ,i.line_number
          ,i.item_number
          ,i.description
          ,i.legacy_company
          ,i.legacy_department
          ,i.legacy_account
          ,i.legacy_product
          ,i.legacy_location
          ,i.legacy_intercompany
          ,i.legacy_division
          ,i.legacy_org_id
          ,i.accounting_date
          ,i.user_je_source_name
          ,i.user_je_category_name
          ,i.currency_code
          ,i.actual_flag
          ,i.accounted_dr
          ,i.accounted_cr
          ,i.reference1);
        --  EXIT WHEN c_unearned_rev%NOTFOUND;
      
      END LOOP;
    
      --CLOSE c_unearned_rev;
      -- COMMIT;
    EXCEPTION
      /* WHEN bulk_errors THEN
      FOR j IN 1 .. SQL%BULK_EXCEPTIONS.COUNT
      LOOP
        l_error := SQLERRM(-sql%BULK_EXCEPTIONS(j).ERROR_CODE);
      
      
        x_errbuf := 'POPULATE XXS3_RTR_UNEARNED_REV BULK ERROR : ' ||
                    l_error;
        log_p(x_errbuf);
      END LOOP;
      
      COMMIT;*/
    
      WHEN OTHERS THEN
        x_errbuf := 'POPULATE XXS3_RTR_UNEARNED_REV WHEN OTHERS : ' ||
                    SQLCODE || ' - ' || SQLERRM;
        log_p(x_errbuf);
      
        COMMIT;
      
    END;
  
  
  
    out_p('Unearned Revenue Data Extraction complete... : ');
  
  
  
    ----------- Quality Check ------------
    log_p('Begin Quality check...');
  
    quality_check_unearned_rev(l_err_code
                              ,l_err_msg);
  
    log_p('End of Quality check...');
  
  
  
  
    ------------------- Transformation ----------
  
    ------------------- COA ----------
    log_p('Begin transformation...');
  
    BEGIN
      FOR k IN c_unearned_rev_transform
      LOOP
      
        IF k.legacy_company IS NOT NULL
        THEN
          l_step := 'coa_unearned_rev_generic_transform';
        
          xxs3_coa_transform_pkg.coa_transform(p_field_name => 'UNEARNED_REVENUE'
                                              ,p_legacy_company_val => k.legacy_company --Legacy Company Value
                                              ,p_legacy_department_val => k.legacy_department --Legacy Department Value
                                              ,p_legacy_account_val => k.legacy_account --Legacy Account Value
                                              ,p_legacy_product_val => k.legacy_product --Legacy Product Value
                                              ,p_legacy_location_val => k.legacy_location --Legacy Location Value
                                              ,p_legacy_intercompany_val => k.legacy_intercompany --Legacy Intercompany Value
                                              ,p_legacy_division_val => k.legacy_division --Legacy Division Value
                                              ,p_item_number => NULL
                                              ,p_s3_org => NULL
                                              ,p_trx_type => 'ALL'
                                              ,p_set_of_books_id => NULL
                                              ,p_debug_flag => 'N'
                                              ,p_s3_gl_string => l_s3_gl_string
                                              ,p_err_code => l_output_code
                                              ,p_err_msg => l_output);
        
        
        
          l_step := 'coa_unearned_rev_generic_update';
        
          xxs3_coa_transform_pkg.coa_update(p_gl_string => l_s3_gl_string
                                           ,p_stage_tab => 'xxs3_rtr_unearned_rev'
                                           ,p_stage_primary_col => 'xx_unearned_rev_id'
                                           ,p_stage_primary_col_val => k.xx_unearned_rev_id
                                           ,p_stage_company_col => 's3_company'
                                           ,p_stage_business_unit_col => 's3_business_unit'
                                           ,p_stage_department_col => 's3_department'
                                           ,p_stage_account_col => 's3_account'
                                           ,p_stage_product_line_col => 's3_product'
                                           ,p_stage_location_col => 's3_location'
                                           ,p_stage_intercompany_col => 's3_intercompany'
                                           ,p_stage_future_col => 's3_future'
                                           ,p_coa_err_msg => l_output
                                           ,p_err_code => l_output_code_coa_update
                                           ,p_err_msg => l_output_coa_update);
        
        
        
        
        END IF;
      
      
      
      /* BEGIN
                                
                                  SELECT s3_product
                                  INTO l_s3_product_line
                                  FROM xxs3_rtr_unearned_rev
                                  WHERE xx_unearned_rev_id = k.xx_unearned_rev_id;
                                
                                
                                  l_step := 'coa_unearned_rev_account_update_251290_for_product_line';
                                
                                  IF (l_s3_product_line = '5103' OR l_s3_product_line = '5203' OR
                                     l_s3_product_line = '5303')
                                  THEN
                                    UPDATE xxobjt.xxs3_rtr_unearned_rev
                                    SET s3_account       = '251290'
                                       ,transform_status = nvl(transform_status, 'PASS')
                                    WHERE account_class = 'UNEARN'
                                    AND xx_unearned_rev_id = k.xx_unearned_rev_id;
                                  
                                    l_step := 'coa_unearned_rev_account_update_251300_for_product_line';
                                  
                                  ELSE
                                    IF (l_s3_product_line = '5104' OR l_s3_product_line = '5204' OR
                                       l_s3_product_line = '5304')
                                    THEN
                                      UPDATE xxobjt.xxs3_rtr_unearned_rev
                                      SET s3_account       = '251300'
                                         ,transform_status = nvl(transform_status, 'PASS')
                                      WHERE account_class = 'UNEARN'
                                      AND xx_unearned_rev_id = k.xx_unearned_rev_id;
                                    
                                    ELSE
                                    
                                      UPDATE xxobjt.xxs3_rtr_unearned_rev
                                      SET s3_account = s3_account_temp
                                      WHERE xx_unearned_rev_id = k.xx_unearned_rev_id;
                                    
                                    END IF;
                                  
                                  
                                  END IF;
                                
                                EXCEPTION
                                  WHEN OTHERS THEN
                                    l_error_message := 'Error in transformation of GL account for Product Line - ' ||
                                                       SQLERRM;
                                  
                                    UPDATE xxobjt.xxs3_rtr_unearned_rev
                                    SET transform_status = 'FAIL'
                                       ,transform_error  = transform_error || ' , ' ||
                                                           l_error_message
                                    WHERE xx_unearned_rev_id = k.xx_unearned_rev_id;
                                  
                                END;*/
      
      END LOOP;
    
    
      log_p('End of transformation');
    
    
    EXCEPTION
      WHEN OTHERS THEN
        log_p('Unexpected error during transformation at step : ' ||
              l_step || ' - ' || SQLERRM);
    END;
  
  
  
  EXCEPTION
    WHEN OTHERS THEN
      l_error_message := (SQLERRM || 'backtrace: ' ||
                         dbms_utility.format_error_backtrace);
    
      log_p(l_error_message);
    
  END unearned_revenue_extract;


END xxs3_rtr_unearned_rev_pkg;
/
