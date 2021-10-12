CREATE OR REPLACE PACKAGE xxs3_rtr_gl_balances_pkg

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

  PROCEDURE gl_balance_extract(x_retcode     OUT NUMBER
                              ,x_errbuf      OUT VARCHAR2
                              ,x_period_name IN VARCHAR2);

  PROCEDURE quality_check_glb(p_err_code OUT VARCHAR2
                             ,p_err_msg  OUT VARCHAR2);

END xxs3_rtr_gl_balances_pkg;
/
CREATE OR REPLACE PACKAGE BODY xxs3_rtr_gl_balances_pkg AS


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
  -- 1.0  29/07/2016  TCS                           Initial build
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
  -- Purpose: This Procedure is used for GL Balances Data Quality Report
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  29/07/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE gl_balance_report_data(p_entity IN VARCHAR2) AS
  
    p_delimiter    VARCHAR2(5) := '~';
    l_err_msg      VARCHAR2(2000);
    l_count_dq     NUMBER;
    l_count_reject NUMBER;
  
    CURSOR c_dq_report IS
      SELECT nvl(glbdq.rule_name, ' ') rule_name
            ,nvl(glbdq.notes, ' ') notes
            ,glb.xx_glb_id
            ,glb.legacy_beg_bal_period
            ,glb.legacy_code_combination_id
            ,glb.segment1
            ,glb.segment2
            ,glb.segment3
            ,glb.segment5
            ,glb.segment6
            ,glb.segment7
            ,glb.segment10
            ,glb.begin_balance_dr
            ,glb.begin_balance_cr
            ,glb.begin_balance_dr_beq
            ,glb.begin_balance_cr_beq
            ,glb.period_net_dr
            ,glb.period_net_cr
            ,glb.period_net_dr_beq
            ,glb.period_net_cr_beq
            ,decode(glb.process_flag, 'R', 'Y', 'Q', 'N') reject_record
      FROM xxs3_rtr_gl_balances    glb
          ,xxs3_rtr_gl_balances_dq glbdq
      WHERE glb.xx_glb_id = glbdq.xx_glb_id
      AND glb.process_flag IN ('Q', 'R');
  
  BEGIN
  
    SELECT COUNT(1)
    INTO l_count_dq
    FROM xxs3_rtr_gl_balances glb
    WHERE glb.process_flag IN ('Q', 'R');
  
    SELECT COUNT(1)
    INTO l_count_reject
    FROM xxs3_rtr_gl_balances glb
    WHERE glb.process_flag = 'R';
  
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
          rpad('Legacy Code Combination Id', 30, ' ') || p_delimiter ||
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
          rpad('Reject Record Flag(Y/N)', 25, ' ') || p_delimiter ||
          rpad('Rule Name', 20, ' ') || p_delimiter ||
          rpad('Reason Code', 250, ' '));
  
    FOR r_data IN c_dq_report
    LOOP
      out_p(rpad('RTR', 10, ' ') || p_delimiter ||
            rpad('GL_BALANCES', 11, ' ') || p_delimiter ||
            rpad(r_data.xx_glb_id, 14, ' ') || p_delimiter ||
            rpad(r_data.legacy_beg_bal_period, 10, ' ') || p_delimiter ||
            rpad(r_data.legacy_code_combination_id, 30, ' ') ||
            p_delimiter || rpad(r_data.segment1, 15, ' ') || p_delimiter ||
            rpad(r_data.segment2, 15, ' ') || p_delimiter ||
            rpad(r_data.segment3, 15, ' ') || p_delimiter ||
            rpad(r_data.segment5, 15, ' ') || p_delimiter ||
            rpad(r_data.segment6, 15, ' ') || p_delimiter ||
            rpad(r_data.segment7, 15, ' ') || p_delimiter ||
            rpad(r_data.segment10, 15, ' ') || p_delimiter ||
            rpad(r_data.begin_balance_dr, 25, ' ') || p_delimiter ||
            rpad(r_data.begin_balance_cr, 25, ' ') || p_delimiter ||
            rpad(r_data.begin_balance_dr_beq, 25, ' ') || p_delimiter ||
            rpad(r_data.begin_balance_cr_beq, 25, ' ') || p_delimiter ||
            rpad(r_data.period_net_dr, 15, ' ') || p_delimiter ||
            rpad(r_data.period_net_cr, 15, ' ') || p_delimiter ||
            rpad(r_data.period_net_dr_beq, 25, ' ') || p_delimiter ||
            rpad(r_data.period_net_cr_beq, 25, ' ') || p_delimiter ||
            rpad(r_data.reject_record, 25, ' ') || p_delimiter ||
            rpad(nvl(r_data.rule_name, 'NULL'), 250, ' ') || p_delimiter ||
            rpad(nvl(r_data.notes, 'NULL'), 250, ' '));
    
    END LOOP;
  
    out_p('');
    out_p('Stratasys Confidential' || p_delimiter);
  
  END gl_balance_report_data;




  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used for Gl Balances Data Quality Report Rules
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  29/07/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE insert_update_gl_blnc_dq(p_xx_glb_id   NUMBER
                                    ,p_rule_name   IN VARCHAR2
                                    ,p_reject_code IN VARCHAR2
                                    ,p_err_code    OUT VARCHAR2
                                    ,p_err_msg     OUT VARCHAR2) IS
  
  BEGIN
  
    UPDATE xxobjt.xxs3_rtr_gl_balances
    SET process_flag = 'Q'
    WHERE xx_glb_id = p_xx_glb_id;
  
    INSERT INTO xxs3_rtr_gl_balances_dq
      (xx_glb_dq_id
      ,xx_glb_id
      ,rule_name
      ,notes)
    VALUES
      (xxobjt.xxs3_rtr_gl_balances_dq_seq.NEXTVAL
      ,p_xx_glb_id
      ,p_rule_name
      ,p_reject_code);
  
    p_err_code := '0';
    p_err_msg  := '';
  
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code := '2';
      p_err_msg  := 'SQLERRM: ' || SQLERRM;
      ROLLBACK;
    
  END insert_update_gl_blnc_dq;




  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure is used for GL Balances Transform Report
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
          rpad('xx GLB Id', 14, ' ') || p_delimiter ||
          rpad('Period Name', 15, ' ') || p_delimiter ||
          rpad('Legacy Segment1', 15, ' ') || p_delimiter ||
          rpad('S3 Company  ', 15, ' ') || p_delimiter ||
          rpad('Legacy Segment2', 15, ' ') || p_delimiter ||
          rpad('S3 Business Unit  ', 15, ' ') || p_delimiter ||
          rpad('Legacy Segment3', 15, ' ') || p_delimiter ||
          rpad('S3 Department   ', 15, ' ') || p_delimiter ||
          rpad('Legacy Segment5', 15, ' ') || p_delimiter ||
          rpad('S3 Account', 15, ' ') || p_delimiter ||
          rpad('Legacy Segment6', 15, ' ') || p_delimiter ||
          rpad('S3 Product Line', 15, ' ') || p_delimiter ||
          rpad('Legacy Segment7', 15, ' ') || p_delimiter ||
          rpad('S3 Location', 15, ' ') || p_delimiter ||
          rpad('Legacy Segment10', 15, ' ') || p_delimiter ||
          rpad('S3 Intercompany', 15, ' ') || p_delimiter ||
          rpad('S3 Future', 15, ' ') || p_delimiter ||
          rpad('Status', 10, ' ') || p_delimiter ||
          rpad('Error Message', 200, ' '));
  
    FOR r_data IN c_report_glb
    LOOP
      out_p(rpad('RTR', 10, ' ') || p_delimiter ||
            rpad('GL_BALANCES', 11, ' ') || p_delimiter ||
            rpad(r_data.xx_glb_id, 14, ' ') || p_delimiter ||
            rpad(r_data.legacy_beg_bal_period, 15, ' ') || p_delimiter ||
            rpad(r_data.segment1, 10, ' ') || p_delimiter ||
            rpad(r_data.s3_company, 10, ' ') || p_delimiter ||
            rpad(r_data.segment2, 10, ' ') || p_delimiter ||
            rpad(r_data.s3_business_unit, 10, ' ') || p_delimiter ||
            rpad(r_data.segment3, 10, ' ') || p_delimiter ||
            rpad(r_data.s3_department, 10, ' ') || p_delimiter ||
            rpad(r_data.segment5, 10, ' ') || p_delimiter ||
            rpad(r_data.s3_account, 10, ' ') || p_delimiter ||
            rpad(r_data.segment6, 10, ' ') || p_delimiter ||
            rpad(r_data.s3_product_line, 10, ' ') || p_delimiter ||
            rpad(r_data.segment7, 10, ' ') || p_delimiter ||
            rpad(r_data.s3_location, 10, ' ') || p_delimiter ||
            rpad(r_data.segment10, 10, ' ') || p_delimiter ||
            rpad(r_data.s3_intercompany, 10, ' ') || p_delimiter ||
            rpad(r_data.s3_future, 10, ' ') || p_delimiter ||
            rpad(r_data.transform_status, 10, ' ') || p_delimiter ||
            rpad(nvl(r_data.transform_error, 'NULL'), 200, ' '));
    END LOOP;
  
    out_p('');
    out_p('Stratasys Confidential' || p_delimiter);
  END;




  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used for GL Balance Data Quality Rules Check
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  29/07/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE quality_check_glb(p_err_code OUT VARCHAR2
                             ,p_err_msg  OUT VARCHAR2) IS
    l_status     VARCHAR2(10) := 'SUCCESS';
    l_check_rule VARCHAR2(10) := 'TRUE';
  
    CURSOR c_glb IS
      SELECT * FROM xxobjt.xxs3_rtr_gl_balances WHERE process_flag = 'N';
  BEGIN
    FOR i IN c_glb
    LOOP
      l_status     := 'SUCCESS';
      l_check_rule := 'TRUE';
    
      IF xxs3_dq_util_pkg.eqt_028(i.segment1)
      THEN
      
        insert_update_gl_blnc_dq(i.xx_glb_id, 'EQT_028:SEGMENT1 IS NULL', 'SEGMENT1 IS NULL', p_err_code, p_err_msg);
        l_status := 'ERR';
      
      END IF;
    
      IF xxs3_dq_util_pkg.eqt_028(i.segment2)
      THEN
      
        insert_update_gl_blnc_dq(i.xx_glb_id, 'EQT_028:SEGMENT2 IS NULL', 'SEGMENT2 IS NULL', p_err_code, p_err_msg);
        l_status := 'ERR';
      
      END IF;
    
      IF xxs3_dq_util_pkg.eqt_028(i.segment3)
      THEN
      
        insert_update_gl_blnc_dq(i.xx_glb_id, 'EQT_028:SEGMENT3 IS NULL', 'SEGMENT3 IS NULL', p_err_code, p_err_msg);
        l_status := 'ERR';
      
      END IF;
    
      IF xxs3_dq_util_pkg.eqt_028(i.segment5)
      THEN
      
        insert_update_gl_blnc_dq(i.xx_glb_id, 'EQT_028:SEGMENT5 IS NULL', 'SEGMENT5 IS NULL', p_err_code, p_err_msg);
        l_status := 'ERR';
      
      END IF;
    
      IF xxs3_dq_util_pkg.eqt_028(i.segment6)
      THEN
      
        insert_update_gl_blnc_dq(i.xx_glb_id, 'EQT_028:SEGMENT6 IS NULL', 'SEGMENT6 IS NULL', p_err_code, p_err_msg);
        l_status := 'ERR';
      
      END IF;
    
      IF xxs3_dq_util_pkg.eqt_028(i.segment7)
      THEN
      
        insert_update_gl_blnc_dq(i.xx_glb_id, 'EQT_028:SEGMENT7 IS NULL', 'SEGMENT7 IS NULL', p_err_code, p_err_msg);
        l_status := 'ERR';
      
      END IF;
    
      IF xxs3_dq_util_pkg.eqt_028(i.legacy_beg_bal_period)
      THEN
      
        insert_update_gl_blnc_dq(i.xx_glb_id, 'EQT_028:PERIOD_NAME IS NULL', 'PERIOD_NAME IS NULL', p_err_code, p_err_msg);
        l_status := 'ERR';
      
      END IF;
    
      IF xxs3_dq_util_pkg.eqt_028(i.ledger_name)
      THEN
      
        insert_update_gl_blnc_dq(i.xx_glb_id, 'EQT_028:LEDGER_NAME IS NULL', 'PERIOD_NAME IS NULL', p_err_code, p_err_msg);
        l_status := 'ERR';
      
      END IF;
    
    
    
      l_check_rule := xxs3_dq_util_pkg.eqt_904;
    
      IF l_check_rule = 'FALSE'
      THEN
      
        insert_update_gl_blnc_dq(i.xx_glb_id, 'EQT_904:Sum of Legacy beginning balance Debits <> Sum of Legacy beginning balance Credits', 'Sum of Legacy beginning balance Debits <> Sum of Legacy beginning balance Credits', p_err_code, p_err_msg);
        l_status := 'ERR';
      
      END IF;
    
      l_check_rule := xxs3_dq_util_pkg.eqt_905;
    
      IF l_check_rule = 'FALSE'
      THEN
      
        insert_update_gl_blnc_dq(i.xx_glb_id, 'EQT_905:Sum of Legacy beginning balance beq Debits <> Sum of Legacy beginning balance beq Credits', 'Sum of Legacy beginning balance beq Debits <> Sum of Legacy beginning balance beq Credits', p_err_code, p_err_msg);
        l_status := 'ERR';
      
      END IF;
    
      l_check_rule := xxs3_dq_util_pkg.eqt_906;
    
      IF l_check_rule = 'FALSE'
      THEN
      
        insert_update_gl_blnc_dq(i.xx_glb_id, 'EQT_906:Sum of Legacy period Debits = Sum of Legacy period Credits', 'Sum of Legacy period Debits <> Sum of Legacy period Credits', p_err_code, p_err_msg);
        l_status := 'ERR';
      
      END IF;
    
      l_check_rule := xxs3_dq_util_pkg.eqt_907;
    
      IF l_check_rule = 'FALSE'
      THEN
      
        insert_update_gl_blnc_dq(i.xx_glb_id, 'EQT_907:Sum of Legacy period beq Debits = Sum of Legacy period beq Credits', 'Sum of Legacy period beq Debits <> Sum of Legacy period beq Credits', p_err_code, p_err_msg);
        l_status := 'ERR';
      
      END IF;
    
      /*l_check_rule := xxs3_dq_util_pkg.eqt_908(i.xx_glb_id);
      
      IF l_check_rule = 'FALSE'
      THEN
      
        --insert_update_gl_blnc_dq(i.xx_glb_id, 'EQT_908: PERIOD_NET_DR_BEQ - PERIOD_NET_CR_BEQ <> 0 & BEGIN_BALANCE_DR_BEQ - BEGIN_BALANCE_CR_BEQ <> 0 & PERIOD_NET_DR - PERIOD_NET_CR <> 0 &  BEGIN_BALANCE_DR - BEGIN_BALANCE_CR <> 0', 'All values of (PERIOD_NET_DR_BEQ - PERIOD_NET_CR_BEQ), (BEGIN_BALANCE_DR_BEQ - BEGIN_BALANCE_CR_BEQ), (PERIOD_NET_DR - PERIOD_NET_CR), (BEGIN_BALANCE_DR - BEGIN_BALANCE_CR) is equal to 0 : NOT eligible for load', p_err_code, p_err_msg);
        insert_update_gl_blnc_dq(i.xx_glb_id, 'EQT_908: BEGIN_BALANCE_DR_BEQ - BEGIN_BALANCE_CR_BEQ <> 0  &  BEGIN_BALANCE_DR - BEGIN_BALANCE_CR <> 0', 'All values of (BEGIN_BALANCE_DR_BEQ - BEGIN_BALANCE_CR_BEQ), (BEGIN_BALANCE_DR - BEGIN_BALANCE_CR) is equal to 0 : NOT eligible for load', p_err_code, p_err_msg);
        l_status := 'ERR';
      
        UPDATE xxobjt.xxs3_rtr_gl_balances
        SET process_flag = 'R'
        WHERE xx_glb_id = i.xx_glb_id;
      
      END IF;*/
    
    
      IF l_status <> 'ERR'
      THEN
        UPDATE xxs3_rtr_gl_balances
        SET process_flag = 'Y'
        WHERE xx_glb_id = i.xx_glb_id;
      END IF;
    END LOOP;
    COMMIT;
  
  END quality_check_glb;




  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used for GL Balances Extract
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  29/07/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE gl_balance_extract(x_retcode     OUT NUMBER
                              ,x_errbuf      OUT VARCHAR2
                              ,x_period_name IN VARCHAR2) AS
  
  
    l_err_code               NUMBER;
    l_err_msg                VARCHAR2(100);
    l_count_subinv           VARCHAR2(2);
    l_get_org                VARCHAR2(50);
    l_get_sub_inv_name       VARCHAR2(50);
    l_get_concat_segments    VARCHAR2(50);
    l_get_row                VARCHAR2(50);
    l_get_rack               VARCHAR2(50);
    l_get_bin                VARCHAR2(50);
    l_error_message          VARCHAR2(2000);
    l_period_name            VARCHAR2(50);
    l_s3_gl_string           VARCHAR2(200);
    l_output_code            NUMBER;
    l_output_code_coa_update NUMBER;
    l_output                 VARCHAR2(100);
    l_output_coa_update      VARCHAR2(100);
    l_step                   VARCHAR2(100);
  
    CURSOR c_glb_transform IS
      SELECT glb.* FROM xxobjt.xxs3_rtr_gl_balances glb;
  
    CURSOR c_glb(x_period_name VARCHAR2) IS
      SELECT code_combination_id legacy_code_combination_id
            ,end_date legacy_period_end_date
            ,period_name legacy_beg_bal_period
            ,NAME ledger_name
            ,actual_flag
            ,currency_code
            ,segment1
            ,segment2
            ,segment3
            ,segment5
            ,segment6
            ,segment7
            ,segment10
            ,segment9
            ,begin_balance_dr
             -- source balances - extract and load to staging for reference and troubleshooting
            ,begin_balance_cr
            ,begin_balance_dr_beq
            ,begin_balance_cr_beq
            ,period_net_dr
            ,period_net_cr
            ,period_net_dr_beq
            ,period_net_cr_beq
            ,CASE
               WHEN entered_dr - entered_cr >= 0 THEN
                entered_dr - entered_cr
               ELSE
                NULL
             END AS entered_dr
            ,CASE
               WHEN entered_cr - entered_dr > 0 THEN
                entered_cr - entered_dr
               ELSE
                NULL
             END AS entered_cr
            ,CASE
               WHEN accounted_dr - accounted_cr >= 0 THEN
                accounted_dr - accounted_cr
               ELSE
                NULL
             END AS accounted_dr
            ,CASE
               WHEN accounted_cr - accounted_dr > 0 THEN
                accounted_cr - accounted_dr
               ELSE
                NULL
             END AS accounted_cr
            ,segment1 || '.' || segment2 || '.' || segment3 || '.' ||
             segment5 || '.' || segment6 || '.' || segment7 || '.' ||
             segment10 || '.' || segment9 AS line_description
            ,s3_ending_bal_acct_date
      FROM (SELECT pr.end_date
                  ,b.period_name
                  ,led.NAME
                  ,actual_flag
                  ,b.currency_code
                  ,segment1
                  ,segment2
                  ,segment3
                  ,segment5
                  ,segment6
                  ,segment7
                  ,segment10
                  ,segment9
                   -- source balances - extract and load to staging for reference and troubleshooting
                  ,begin_balance_dr
                  ,begin_balance_cr
                  ,begin_balance_dr_beq
                  ,begin_balance_cr_beq
                  ,period_net_dr
                  ,period_net_cr
                  ,period_net_dr_beq
                  ,period_net_cr_beq
                  ,CASE
                     WHEN b.currency_code = 'USD' THEN
                      begin_balance_dr_beq
                     ELSE
                      begin_balance_dr
                   END AS entered_dr
                  ,CASE
                     WHEN b.currency_code = 'USD' THEN
                      begin_balance_cr_beq
                     ELSE
                      begin_balance_cr
                   END AS entered_cr
                  ,begin_balance_dr_beq AS accounted_dr
                  ,begin_balance_cr_beq AS accounted_cr
                  ,b.code_combination_id
                  ,add_months(pr.end_date, -1) AS s3_ending_bal_acct_date
            FROM gl_balances          b
                ,gl_code_combinations cc
                ,gl_ledgers           led
                ,gl_periods           pr
            WHERE b.code_combination_id = cc.code_combination_id
            AND b.ledger_id = led.ledger_id
            AND b.period_name = pr.period_name
            AND nvl(begin_balance_dr_beq, 0) - nvl(begin_balance_cr_beq, 0) <> 0 -- Commented on 26-OCT-2016 
            AND led.NAME IN ('Stratasys US', 'Seurat USD')
            AND segment1 IN ('26', '29', '37', '44') -- use lookup to maintain this list
            AND b.period_name = x_period_name -- to load DEC-16 ending balance, run for JAN-17 beginning balance 
            AND actual_flag = 'A'
            ORDER BY cc.account_type
                    ,cc.segment1
                    ,cc.segment2
                    ,cc.segment3
                    ,cc.segment5
                    ,cc.segment6
                    ,cc.segment7
                    ,cc.segment10);
    ----------------------------------------------
  
  BEGIN
  
    EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.xxs3_rtr_gl_balances';
  
    EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.xxs3_rtr_gl_balances_dq';
  
    l_period_name := x_period_name;
    out_p('GL Balance Extract for Period : ' || l_period_name);
    out_p('GL Balance Data Extraction starting... : ');
  
  
    FOR i IN c_glb(l_period_name)
    LOOP
      INSERT INTO xxobjt.xxs3_rtr_gl_balances
        (xx_glb_id
        ,date_of_extract
        ,process_flag
        ,legacy_period_end_date
        ,legacy_beg_bal_period
        ,ledger_name
        ,actual_flag
        ,currency_code
        ,segment1
        ,segment2
        ,segment3
        ,segment5
        ,segment6
        ,segment7
        ,segment10
        ,entered_dr
        ,entered_cr
        ,accounted_dr
        ,accounted_cr
        ,line_description
        ,s3_ending_bal_acct_date
        ,begin_balance_dr
        ,begin_balance_cr
        ,begin_balance_dr_beq
        ,begin_balance_cr_beq
        ,period_net_dr
        ,period_net_cr
        ,period_net_dr_beq
        ,period_net_cr_beq
        ,legacy_code_combination_id)
      VALUES
        (xxobjt.xxs3_rtr_gl_blnc_seq.NEXTVAL
        ,SYSDATE
        ,'N'
        ,i.legacy_period_end_date
        ,i.legacy_beg_bal_period
        ,i.ledger_name
        ,i.actual_flag
        ,i.currency_code
        ,i.segment1
        ,i.segment2
        ,i.segment3
        ,i.segment5
        ,i.segment6
        ,i.segment7
        ,i.segment10
        ,i.entered_dr
        ,i.entered_cr
        ,i.accounted_dr
        ,i.accounted_cr
        ,i.line_description
        ,i.s3_ending_bal_acct_date
        ,i.begin_balance_dr
        ,i.begin_balance_cr
        ,i.begin_balance_dr_beq
        ,i.begin_balance_cr_beq
        ,i.period_net_dr
        ,i.period_net_cr
        ,i.period_net_dr_beq
        ,i.period_net_cr_beq
        ,i.legacy_code_combination_id);
    
    END LOOP;
  
  
    COMMIT;
  
  
    out_p('GL Balance Data Extraction complete... : ' || l_period_name);
  
    ----------- Quality Check ------------
    log_p('BEGIN  Quality check');
  
    quality_check_glb(l_err_code, l_err_msg);
  
    ------------------- transform  subinventory, segments----------
    log_p('Begin transform');
  
    BEGIN
      FOR k IN c_glb_transform
      LOOP
        IF k.segment1 IS NOT NULL
        THEN
        
          -----------------------------------------------------------------------------------------------------------------------
          --Commented on 23-Sep-2016 
        
          /* xxs3_data_transform_util_pkg.coa_transform(p_field_name              => 'GLB_ACCOUNT',
          p_legacy_company_val      => k.segment1, --Legacy Company Value
          p_legacy_department_val   => k.segment2, --Legacy Department Value
          p_legacy_account_val      => k.segment3, --Legacy Account Value
          p_legacy_product_val      => k.segment5, --Legacy Product Value
          p_legacy_location_val     => k.segment6, --Legacy Location Value
          p_legacy_intercompany_val => k.segment7, --Legacy Intercompany Value
          p_legacy_division_val     => k.segment10, --Legacy Division Value
          p_item_number             => NULL,
          p_s3_gl_string            => l_s3_gl_string,
          p_err_code                => l_output_code,
          p_err_msg                 => l_output); --Output Message */
          --Commented on 23-Sep-2016                                             
        
          -----------------------------------------------------------------------------------------------------------------------
        
          -----------------------------------------------------------------------------------------------------------------------
          --Added on 23-Sep-2016 
        
          l_step := 'coa_gl_balance_transform';
        
          xxs3_data_transform_util_pkg.coa_gl_balance_transform(p_field_name => 'GLB_ACCOUNT', p_legacy_company_val => k.segment1, --Legacy Company Value
                                                                p_legacy_department_val => k.segment2, --Legacy Department Value
                                                                p_legacy_account_val => k.segment3, --Legacy Account Value
                                                                p_legacy_product_val => k.segment5, --Legacy Product Value
                                                                p_legacy_location_val => k.segment6, --Legacy Location Value
                                                                p_legacy_intercompany_val => k.segment7, --Legacy Intercompany Value
                                                                p_legacy_division_val => k.segment10, --Legacy Division Value
                                                                p_item_number => NULL, p_s3_gl_string => l_s3_gl_string, p_err_code => l_output_code, p_err_msg => l_output); --Output Message 
          --Added on 23-Sep-2016      
        
          -----------------------------------------------------------------------------------------------------------------------
        
          l_step := 'coa_update';
        
          xxs3_data_transform_util_pkg.coa_update(p_gl_string => l_s3_gl_string, p_stage_tab => 'XXS3_RTR_GL_BALANCES', p_stage_primary_col => 'XX_GLB_ID', p_stage_primary_col_val => k.xx_glb_id, p_stage_company_col => 'S3_COMPANY', p_stage_business_unit_col => 'S3_BUSINESS_UNIT', p_stage_department_col => 'S3_DEPARTMENT', p_stage_account_col => 'S3_ACCOUNT', p_stage_product_line_col => 'S3_PRODUCT_LINE', p_stage_location_col => 'S3_LOCATION', p_stage_intercompany_col => 'S3_INTERCOMPANY', p_stage_future_col => 'S3_FUTURE', p_coa_err_msg => l_output, p_err_code => l_output_code_coa_update, p_err_msg => l_output_coa_update);
        END IF;
      END LOOP;
    
      log_p('End of transform');
    
    EXCEPTION
      WHEN OTHERS THEN
        log_p('Unexpected error during transformation at step : ' ||
              l_step || SQLERRM);
    END;
  
  
  
  EXCEPTION
    WHEN OTHERS THEN
      l_error_message := (SQLERRM || 'backtrace: ' ||
                         dbms_utility.format_error_backtrace);
    
      log_p(l_error_message);
    
  END gl_balance_extract;

END xxs3_rtr_gl_balances_pkg;
/
