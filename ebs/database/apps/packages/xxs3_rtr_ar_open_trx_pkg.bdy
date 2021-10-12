CREATE OR REPLACE PACKAGE xxs3_rtr_ar_open_trx_pkg

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

  PROCEDURE open_trx_extract(x_errbuf  OUT VARCHAR2
                            ,x_retcode OUT NUMBER);
  PROCEDURE quality_check_open_trx(p_err_code OUT VARCHAR2
                                  ,p_err_msg  OUT VARCHAR2);
  /*  PROCEDURE cleanse_multi_code_combination(p_customer_trx_id      VARCHAR2,
                                        p_customer_trx_line_id VARCHAR2)
  RETURN VARCHAR2;*/

  PROCEDURE ar_open_trx_report_data(p_entity_name IN VARCHAR2);

  PROCEDURE data_transform_report(p_entity VARCHAR2);

  PROCEDURE data_cleanse_report(p_entity VARCHAR2);

END xxs3_rtr_ar_open_trx_pkg;
/
CREATE OR REPLACE PACKAGE BODY xxs3_rtr_ar_open_trx_pkg AS


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
  -- Purpose: This Procedure is used for AR Open Transactions Data Quality Report
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  29/07/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE ar_open_trx_report_data(p_entity_name IN VARCHAR2) AS
  
    CURSOR c_report IS
      SELECT nvl(distdq.rule_name, ' ') rule_name
            ,nvl(distdq.notes, ' ') notes
            ,dist.xx_open_trx_dist_id
            ,decode(dist.process_flag, 'R', 'Y', 'Q', 'N') reject_record
            ,legacy_customer_trx_id
            ,legacy_customer_trx_line_id
            ,legacy_invoice_source
            ,order_number
            ,trx_number
            ,legacy_code_combination
      FROM xxobjt.xxs3_rtr_open_trx_distribution dist
          ,xxobjt.xxs3_rtr_open_trx_distbn_dq    distdq
      WHERE dist.xx_open_trx_dist_id = distdq.xx_open_trx_dist_id
      AND dist.process_flag IN ('Q', 'R')
      ORDER BY 1;
  
    p_delimiter    VARCHAR2(5) := '~';
    l_err_msg      VARCHAR2(2000);
    l_count_dq     NUMBER;
    l_count_reject NUMBER;
  
  BEGIN
  
    SELECT COUNT(1)
    INTO l_count_dq
    FROM xxs3_ptp_suppliers xci
    WHERE xci.process_flag IN ('Q', 'R');
  
    SELECT COUNT(1)
    INTO l_count_reject
    FROM xxs3_ptp_suppliers xci
    WHERE xci.process_flag = 'R';
  
  
  
    out_p(rpad('Report name = AR Open Trx Data Quality Error Report' ||
               p_delimiter, 100, ' '));
    out_p(rpad('========================================' || p_delimiter, 100, ' '));
    out_p(rpad('Data Migration Object Name = ' || p_entity_name ||
               p_delimiter, 100, ' '));
    out_p('');
    out_p(rpad('Run date and time:    ' ||
               to_char(SYSDATE, 'dd-Mon-YYYY HH24:MI') || p_delimiter, 100, ' '));
    out_p(rpad('Total Record Count Having DQ Issues = ' || l_count_dq ||
               p_delimiter, 100, ' '));
    out_p(rpad('Total Record Count Rejected =  ' || l_count_reject ||
               p_delimiter, 100, ' '));
  
    out_p('');
  
  
  
    out_p(rpad('Track Name', 15, ' ') || p_delimiter ||
          rpad('Entity Name', 20, ' ') || p_delimiter ||
          rpad('XX_OPEN_TRX_DIST_ID  ', 30, ' ') || p_delimiter ||
          rpad('Legacy Customer Trx Id', 30, ' ') || p_delimiter ||
          rpad('Legacy Customer Trx Line Id', 40, ' ') || p_delimiter ||
          rpad('Legacy Invoice Source', 25, ' ') || p_delimiter ||
          rpad('Order Number', 25, ' ') || p_delimiter ||
          rpad('Transaction Number', 25, ' ') || p_delimiter ||
          rpad('Legacy Code Combination', 240, ' ') || p_delimiter ||
          rpad('Reject Record Flag(Y/N)', 30, ' ') || p_delimiter ||
          rpad('Rule Name', 50, ' ') || p_delimiter ||
          rpad('Reason Code', 50, ' '));
  
  
  
    FOR i IN c_report
    LOOP
      out_p(rpad('RTR', 15, ' ') || p_delimiter ||
            rpad(p_entity_name, 20, ' ') || p_delimiter ||
            rpad(i.xx_open_trx_dist_id, 30, ' ') || p_delimiter ||
            rpad(i.legacy_customer_trx_id, 30, ' ') || p_delimiter ||
            rpad(i.legacy_customer_trx_line_id, 40, ' ') || p_delimiter ||
            rpad(i.legacy_invoice_source, 25, ' ') || p_delimiter ||
            rpad(i.order_number, 25, ' ') || p_delimiter ||
            rpad(i.trx_number, 25, ' ') || p_delimiter ||
            rpad(i.legacy_code_combination, 240, ' ') || p_delimiter ||
            rpad(i.reject_record, 20, ' ') || p_delimiter ||
            rpad(i.rule_name, 50, ' ') || p_delimiter ||
            rpad(i.notes, 50, ' '));
    END LOOP;
  
  
  EXCEPTION
    WHEN OTHERS THEN
      log_p('Failed to generate report: ' || SQLERRM);
  END ar_open_trx_report_data;





  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used for AR Open Transactions Data Quality Report Rules
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  29/07/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE insert_update_open_trx_dq(p_xx_open_trx_dist_id NUMBER
                                     ,p_rule_name           IN VARCHAR2
                                     ,p_reject_code         IN VARCHAR2
                                     ,p_err_code            OUT VARCHAR2
                                     ,p_err_msg             OUT VARCHAR2) IS
  
  BEGIN
  
    UPDATE xxobjt.xxs3_rtr_open_trx_distribution
    SET process_flag = 'Q'
    WHERE xx_open_trx_dist_id = p_xx_open_trx_dist_id;
  
    INSERT INTO xxobjt.xxs3_rtr_open_trx_distbn_dq
      (xx_open_trx_dist_dq_id
      ,xx_open_trx_dist_id
      ,rule_name
      ,notes)
    VALUES
      (xxobjt.xxs3_rtr_open_trx_dist_dq_seq.NEXTVAL
      ,p_xx_open_trx_dist_id
      ,p_rule_name
      ,p_reject_code);
  
    p_err_code := '0';
    p_err_msg  := '';
  
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code := '2';
      p_err_msg  := 'SQLERRM: ' || SQLERRM;
      ROLLBACK;
    
  END insert_update_open_trx_dq;




  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure is used for AR Open Transactions Transform Report
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
  
    CURSOR c_report_open_trx_lines IS
      SELECT *
      FROM xxs3_rtr_open_trx_lines
      WHERE transform_status IN ('PASS', 'FAIL');
  
    CURSOR c_report_open_trx_dist IS
      SELECT *
      FROM xxs3_rtr_open_trx_distribution
      WHERE transform_status IN ('PASS', 'FAIL');
  
  BEGIN
  
    IF p_entity = 'OPEN_TRX_LINES'
    THEN
    
      SELECT COUNT(1)
      INTO l_count_success
      FROM xxs3_rtr_open_trx_lines xrotl
      WHERE xrotl.transform_status = 'PASS';
    
      SELECT COUNT(1)
      INTO l_count_fail
      FROM xxs3_rtr_open_trx_lines xrotl
      WHERE xrotl.transform_status = 'FAIL';
    
      out_p(rpad('Report name = Data Transformation Report for Open Trx Lines' ||
                 p_delimiter, 100, ' '));
      out_p(rpad('========================================' || p_delimiter, 100, ' '));
      out_p(rpad('Data Migration Object Name = ' || p_entity ||
                 p_delimiter, 100, ' '));
      out_p('');
      out_p(rpad('Run date and time:    ' ||
                 to_char(SYSDATE, 'dd-Mon-YYYY HH24:MI') || p_delimiter, 100, ' '));
      out_p(rpad('Total Record Count Success = ' || l_count_success ||
                 p_delimiter, 100, ' '));
      out_p(rpad('Total Record Count Failure = ' || l_count_fail ||
                 p_delimiter, 100, ' '));
    
      out_p('');
    
      out_p(rpad('Track Name', 10, ' ') || p_delimiter ||
            rpad('Entity Name', 25, ' ') || p_delimiter ||
            rpad('XX OPEN TRX ID', 14, ' ') || p_delimiter ||
            rpad('Legacy Customer Trx Id', 50, ' ') || p_delimiter ||
            rpad('Trx Number', 20, ' ') || p_delimiter ||
            rpad('Line Number', 15, ' ') || p_delimiter ||
            rpad('Legacy Invoice Source', 50, ' ') || p_delimiter ||
            rpad('INTERFACE_LINE_ATTRIBUTE1', 50, ' ') || p_delimiter ||
            rpad('Status', 10, ' ') || p_delimiter ||
            rpad('Error Message', 200, ' '));
    
    
      FOR l_data IN c_report_open_trx_lines
      LOOP
        out_p(rpad('RTR', 10, ' ') || p_delimiter ||
              rpad('OPEN_TRX_LINES', 25, ' ') || p_delimiter ||
              rpad(l_data.xx_open_trx_id, 14, ' ') || p_delimiter ||
              rpad(l_data.legacy_invoice_source, 50, ' ') || p_delimiter ||
              rpad(l_data.legacy_customer_trx_id, 50, ' ') || p_delimiter ||
              rpad(l_data.trx_number, 20, ' ') || p_delimiter ||
              rpad(l_data.line_number, 15, ' ') || p_delimiter ||
              rpad(l_data.interface_line_attribute1, 50, ' ') ||
              p_delimiter || rpad(l_data.transform_status, 10, ' ') ||
              p_delimiter ||
              rpad(nvl(l_data.transform_error, 'NULL'), 200, ' '));
      END LOOP;
    
      out_p('');
      out_p('Stratasys Confidential' || p_delimiter);
    
    END IF;
  
  
  
  
    IF p_entity = 'OPEN_TRX_DISTRIBUTIONS'
    THEN
    
      SELECT COUNT(1)
      INTO l_count_success
      FROM xxs3_rtr_open_trx_distribution xrotd
      WHERE xrotd.transform_status = 'PASS';
    
      SELECT COUNT(1)
      INTO l_count_fail
      FROM xxs3_rtr_open_trx_distribution xrotd
      WHERE xrotd.transform_status = 'FAIL';
    
      out_p(rpad('Report name = Data Transformation Report for Open Trx Distribution' ||
                 p_delimiter, 100, ' '));
      out_p(rpad('========================================' || p_delimiter, 100, ' '));
      out_p(rpad('Data Migration Object Name = ' || p_entity ||
                 p_delimiter, 100, ' '));
      out_p('');
      out_p(rpad('Run date and time:    ' ||
                 to_char(SYSDATE, 'dd-Mon-YYYY HH24:MI') || p_delimiter, 100, ' '));
      out_p(rpad('Total Record Count Success = ' || l_count_success ||
                 p_delimiter, 100, ' '));
      out_p(rpad('Total Record Count Failure = ' || l_count_fail ||
                 p_delimiter, 100, ' '));
    
      out_p('');
    
      out_p(rpad('Track Name', 10, ' ') || p_delimiter ||
            rpad('Entity Name', 25, ' ') || p_delimiter ||
            rpad('XX_OPEN_TRX_DIST_ID', 30, ' ') || p_delimiter ||
            rpad('Legacy Customer Trx Id', 30, ' ') || p_delimiter ||
            rpad('Legacy Customer Trx Line Id', 40, ' ') || p_delimiter ||
            rpad('Legacy Invoice Source', 25, ' ') || p_delimiter ||
            rpad('Order Number', 25, ' ') || p_delimiter ||
            rpad('Trx Number', 20, ' ') || p_delimiter ||
            rpad('Line Number', 15, ' ') || p_delimiter ||
            rpad('INTERFACE_LINE_ATTRIBUTE1', 50, ' ') || p_delimiter ||
            rpad('legacy_company', 20, ' ') || p_delimiter ||
            rpad('legacy_department', 20, ' ') || p_delimiter ||
            rpad('legacy_account', 20, ' ') || p_delimiter ||
            rpad('legacy_product', 20, ' ') || p_delimiter ||
            rpad('legacy_location', 20, ' ') || p_delimiter ||
            rpad('legacy_intercompany', 25, ' ') || p_delimiter ||
            rpad('legacy_division', 20, ' ') || p_delimiter ||
            rpad('S3_COMPANY', 20, ' ') || p_delimiter ||
            rpad('S3_BUSINESS_UNIT', 20, ' ') || p_delimiter ||
            rpad('S3_DEPARTMENT', 20, ' ') || p_delimiter ||
            rpad('S3_ACCOUNT', 20, ' ') || p_delimiter ||
            rpad('S3_PRODUCT', 20, ' ') || p_delimiter ||
            rpad('S3_LOCATION', 20, ' ') || p_delimiter ||
            rpad('S3_INTERCOMPANY', 25, ' ') || p_delimiter ||
            rpad('S3_FUTURE', 20, ' ') || p_delimiter ||
            rpad('Status', 10, ' ') || p_delimiter ||
            rpad('Error Message', 200, ' '));
    
      FOR d_data IN c_report_open_trx_dist
      LOOP
        out_p(rpad('RTR', 10, ' ') || p_delimiter ||
              rpad('OPEN_TRX_DISTRIBUTIONS', 25, ' ') || p_delimiter ||
              rpad(d_data.xx_open_trx_dist_id, 30, ' ') || p_delimiter ||
              rpad(d_data.legacy_customer_trx_id, 30, ' ') || p_delimiter ||
              rpad(d_data.legacy_customer_trx_line_id, 30, ' ') ||
              p_delimiter || rpad(d_data.legacy_invoice_source, 50, ' ') ||
              p_delimiter || rpad(d_data.order_number, 20, ' ') ||
              p_delimiter || rpad(d_data.trx_number, 20, ' ') ||
              p_delimiter || rpad(d_data.line_number, 15, ' ') ||
              p_delimiter ||
              rpad(d_data.interface_line_attribute1, 50, ' ') ||
              p_delimiter || rpad(d_data.legacy_company, 20, ' ') ||
              p_delimiter || rpad(d_data.legacy_department, 20, ' ') ||
              p_delimiter || rpad(d_data.legacy_account, 20, ' ') ||
              p_delimiter || rpad(d_data.legacy_product, 20, ' ') ||
              p_delimiter || rpad(d_data.legacy_location, 20, ' ') ||
              p_delimiter || rpad(d_data.legacy_intercompany, 25, ' ') ||
              p_delimiter || rpad(d_data.legacy_division, 20, ' ') ||
              p_delimiter || rpad(d_data.s3_company, 20, ' ') ||
              p_delimiter || rpad(d_data.s3_business_unit, 20, ' ') ||
              p_delimiter || rpad(d_data.s3_department, 20, ' ') ||
              p_delimiter || rpad(d_data.s3_account, 20, ' ') ||
              p_delimiter || rpad(d_data.s3_product, 20, ' ') ||
              p_delimiter || rpad(d_data.s3_location, 20, ' ') ||
              p_delimiter || rpad(d_data.s3_intercompany, 20, ' ') ||
              p_delimiter || rpad(d_data.s3_future, 20, ' ') ||
              p_delimiter || rpad(d_data.transform_status, 10, ' ') ||
              p_delimiter ||
              rpad(nvl(d_data.transform_error, 'NULL'), 200, ' '));
      END LOOP;
    
      out_p('');
      out_p('Stratasys Confidential' || p_delimiter);
    
    END IF;
  
  END;




  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used for AR Open Transactions Data Cleanse Report
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  29/07/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------


  PROCEDURE data_cleanse_report(p_entity VARCHAR2) IS
  
    CURSOR c_report_open_trx_lines IS
      SELECT xrotl.xx_open_trx_id
            ,xrotl.trx_number
            ,xrotl.legacy_invoice_source
            ,xrotl.legacy_invoice_source_number
            ,xrotl.interface_line_attribute1
            ,xrotl.line_description
            ,xrotl.s3_line_description
            ,xrotl.cleanse_status
            ,xrotl.cleanse_error
      FROM xxs3_rtr_open_trx_lines xrotl
      WHERE xrotl.cleanse_status IN ('PASS', 'FAIL');
  
    CURSOR c_report_open_trx_dstrbn IS
      SELECT xrotd.xx_open_trx_dist_id
            ,xrotd.trx_number
            ,xrotd.line_number
            ,xrotd.order_number
            ,xrotd.interface_line_attribute1
            ,xrotd.line_description
            ,xrotd.legacy_code_combination
            ,xrotd.legacy_company
            ,xrotd.legacy_account
            ,xrotd.legacy_product
            ,xrotd.legacy_location
            ,xrotd.legacy_intercompany
            ,xrotd.legacy_department
            ,xrotd.cleanse_status
            ,xrotd.cleanse_error
      FROM xxs3_rtr_open_trx_distribution xrotd
      WHERE xrotd.cleanse_status IN ('PASS', 'FAIL');
  
    p_delimiter     VARCHAR2(5) := '~';
    l_err_msg       VARCHAR2(2000);
    l_count_success NUMBER;
    l_count_fail    NUMBER;
  
  BEGIN
  
    IF p_entity = 'OPEN_TRX_LINES'
    THEN
    
      SELECT COUNT(1)
      INTO l_count_success
      FROM xxs3_rtr_open_trx_lines xrotl
      WHERE xrotl.cleanse_status = 'PASS';
    
      SELECT COUNT(1)
      INTO l_count_fail
      FROM xxs3_rtr_open_trx_lines xrotl
      WHERE xrotl.cleanse_status = 'FAIL';
    
      out_p(rpad('Report name = Automated Cleanse & Standardize Report' ||
                 p_delimiter, 100, ' '));
      out_p(rpad('====================================================' ||
                 p_delimiter, 100, ' '));
      out_p(rpad('Data Migration Object Name = ' || p_entity ||
                 p_delimiter, 100, ' '));
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
            rpad('XX Open Trx ID ', 14, ' ') || p_delimiter ||
            rpad('Trx Number', 15, ' ') || p_delimiter ||
            rpad('Legacy Invoice Source', 50, ' ') || p_delimiter ||
            rpad('Legacy Invoice Source Number', 50, ' ') || p_delimiter ||
            rpad('INTERFACE_LINE_ATTRIBUTE1', 50, ' ') || p_delimiter ||
            rpad('Line Description', 250, ' ') || p_delimiter ||
            rpad('S3 Line Description', 250, ' ') || p_delimiter ||
            rpad('Status', 10, ' ') || p_delimiter ||
            rpad('Error Message', 200, ' '));
    
      FOR r_data IN c_report_open_trx_lines
      LOOP
        out_p(rpad('RTR', 10, ' ') || p_delimiter ||
              rpad('OPEN_TRX_LINES', 20, ' ') || p_delimiter ||
              rpad(r_data.xx_open_trx_id, 14, ' ') || p_delimiter ||
              rpad(r_data.trx_number, 15, ' ') || p_delimiter ||
              rpad(r_data.legacy_invoice_source, 50, ' ') || p_delimiter ||
              rpad(r_data.legacy_invoice_source_number, 50, ' ') ||
              p_delimiter ||
              rpad(r_data.interface_line_attribute1, 50, ' ') ||
              p_delimiter || rpad(r_data.line_description, 250, ' ') ||
              p_delimiter || rpad(r_data.s3_line_description, 250, ' ') ||
              p_delimiter || rpad(r_data.cleanse_status, 10, ' ') ||
              p_delimiter ||
              rpad(nvl(r_data.cleanse_error, 'NULL'), 200, ' '));
      
      END LOOP;
    
      out_p('');
      out_p('Stratasys Confidential' || p_delimiter);
    
    END IF;
  
    IF p_entity = 'OPEN_TRX_DISTRIBUTIONS'
    THEN
    
      SELECT COUNT(1)
      INTO l_count_success
      FROM xxs3_rtr_open_trx_distribution xrotd
      WHERE xrotd.cleanse_status = 'PASS';
    
      SELECT COUNT(1)
      INTO l_count_fail
      FROM xxs3_rtr_open_trx_distribution xrotd
      WHERE xrotd.cleanse_status = 'FAIL';
    
      out_p(rpad('Report name = Automated Cleanse & Standardize Report' ||
                 p_delimiter, 100, ' '));
      out_p(rpad('====================================================', 100, ' '));
      out_p(rpad('Data Migration Object Name = ' || p_entity ||
                 p_delimiter, 100, ' '));
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
            rpad('XX OPEN TRX DIST ID ', 20, ' ') || p_delimiter ||
            rpad('Trx Number', 15, ' ') || p_delimiter ||
            rpad('Line Number', 15, ' ') || p_delimiter ||
            rpad('Order Number', 15, ' ') || p_delimiter ||
            rpad('INTERFACE_LINE_ATTRIBUTE1', 50, ' ') || p_delimiter ||
            rpad('line Description', 250, ' ') || p_delimiter ||
            rpad('legacy Code Combination', 50, ' ') || p_delimiter ||
            rpad('legacy Company', 15, ' ') || p_delimiter ||
            rpad('legacy Account', 15, ' ') || p_delimiter ||
            rpad('legacy Product', 15, ' ') || p_delimiter ||
            rpad('legacy Location', 15, ' ') || p_delimiter ||
            rpad('legacy Intercompany', 15, ' ') || p_delimiter ||
            rpad('legacy Department', 15, ' ') || p_delimiter ||
            rpad('Status', 10, ' ') || p_delimiter ||
            rpad('Error Message', 200, ' '));
    
      FOR r_data IN c_report_open_trx_dstrbn
      LOOP
        out_p(rpad('RTR', 10, ' ') || p_delimiter ||
              rpad('OPEN_TRX_DISTRIBUTIONS', 25, ' ') || p_delimiter ||
              rpad(r_data.xx_open_trx_dist_id, 14, ' ') || p_delimiter ||
              rpad(r_data.trx_number, 15, ' ') || p_delimiter ||
              rpad(r_data.line_number, 15, ' ') || p_delimiter ||
              rpad(r_data.order_number, 15, ' ') || p_delimiter ||
              rpad(r_data.interface_line_attribute1, 50, ' ') ||
              p_delimiter || rpad(r_data.line_description, 250, ' ') ||
              p_delimiter || rpad(r_data.legacy_code_combination, 50, ' ') ||
              p_delimiter || rpad(r_data.legacy_company, 15, ' ') ||
              p_delimiter || rpad(r_data.legacy_account, 15, ' ') ||
              p_delimiter || rpad(r_data.legacy_product, 15, ' ') ||
              p_delimiter || rpad(r_data.legacy_location, 15, ' ') ||
              p_delimiter || rpad(r_data.legacy_intercompany, 15, ' ') ||
              p_delimiter || rpad(r_data.legacy_company, 15, ' ') ||
              p_delimiter || rpad(r_data.legacy_department, 15, ' ') ||
              p_delimiter || rpad(r_data.cleanse_status, 10, ' ') ||
              p_delimiter ||
              rpad(nvl(r_data.cleanse_error, 'NULL'), 200, ' '));
      
      END LOOP;
    
      out_p('');
      out_p('Stratasys Confidential' || p_delimiter);
    END IF;
  
  END data_cleanse_report;



  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used for AR Open Transactions Cleanse Rules Check
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  29/07/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE cleanse_open_trx_code_comb(p_err_code OUT VARCHAR2
                                      ,p_err_msg  OUT VARCHAR2) IS
  
    l_status        VARCHAR2(10) := 'SUCCESS';
    l_check_rule    VARCHAR2(10) := 'TRUE';
    l_period_name   VARCHAR2(10);
    l_error_message VARCHAR2(1000) := '';
    l_s3_line_desc  VARCHAR2(240) := '';
  
    CURSOR c_cleanse_stg IS
      SELECT *
      FROM xxobjt.xxs3_rtr_open_trx_lines
      WHERE line_description NOT IN
            ('Original Tax Amount', 'Conv Application');
  
  BEGIN
  
    FOR i IN c_cleanse_stg
    LOOP
    
      BEGIN
        SELECT stg.item_number || '-' || stg.line_description || '-' ||
               dist.legacy_code_combination
        INTO l_s3_line_desc
        FROM xxobjt.xxs3_rtr_open_trx_lines        stg
            ,xxobjt.xxs3_rtr_open_trx_distribution dist
        WHERE dist.legacy_customer_trx_id = stg.legacy_customer_trx_id
        AND dist.legacy_customer_trx_line_id =
              stg.legacy_customer_trx_line_id
        AND dist.account_class = 'REV'
        AND stg.legacy_customer_trx_line_id = i.legacy_customer_trx_line_id
        AND stg.legacy_customer_trx_id = i.legacy_customer_trx_id;
      
        UPDATE xxs3_rtr_open_trx_lines
        SET s3_line_description = substr(TRIM(REPLACE(REPLACE(REPLACE(REPLACE(l_s3_line_desc, ',', ' '), '"', ' '), chr(10), ' '), chr(13), ' ')), 1, 240)
           ,cleanse_status      = 'PASS'
        WHERE xx_open_trx_id = i.xx_open_trx_id;
      
      EXCEPTION
        WHEN OTHERS THEN
          l_error_message := substr(SQLERRM, 1, 200);
        
          UPDATE xxs3_rtr_open_trx_lines
          
          SET cleanse_status = 'FAIL'
             ,cleanse_error  = i.cleanse_error || ' S3 Line Description :' ||
                               l_error_message || ' ,'
          WHERE xx_open_trx_id = i.xx_open_trx_id;
        
      END;
    
    END LOOP;
  
  EXCEPTION
    WHEN OTHERS THEN
    
      l_error_message := (SQLERRM || 'backtrace: ' ||
                         dbms_utility.format_error_backtrace);
      log_p(l_error_message);
    
  END cleanse_open_trx_code_comb;




  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used for AR Open Transactions Cleanse Rules Check
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  29/07/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE cleanse_intf_line_attr_lines(p_err_code OUT VARCHAR2
                                        ,p_err_msg  OUT VARCHAR2) IS
  
    l_status        VARCHAR2(10) := 'SUCCESS';
    l_check_rule    VARCHAR2(10) := 'TRUE';
    l_period_name   VARCHAR2(10);
    l_error_message VARCHAR2(1000) := '';
    l_s3_line_desc  VARCHAR2(240) := '';
  
    CURSOR c_cleanse_stg IS
      SELECT * FROM xxobjt.xxs3_rtr_open_trx_lines;
  
  BEGIN
  
    log_p('start  INTERFACE_LINE_ATTRIBUTE1 cleanse ');
  
    FOR i IN c_cleanse_stg
    LOOP
    
      BEGIN
        IF i.legacy_invoice_source_number IS NOT NULL
        THEN
        
          UPDATE xxs3_rtr_open_trx_lines
          SET interface_line_attribute1 = (i.interface_line_attribute1 || '-' ||
                                          i.legacy_invoice_source_number)
             ,cleanse_status            = 'PASS'
          WHERE xx_open_trx_id = i.xx_open_trx_id;
        
        ELSE
        
          UPDATE xxs3_rtr_open_trx_lines
          SET interface_line_attribute1 = ('AR - ' || i.trx_number)
             ,cleanse_status            = 'PASS'
          WHERE xx_open_trx_id = i.xx_open_trx_id;
        
        END IF;
      
      EXCEPTION
        WHEN OTHERS THEN
          l_error_message := substr(SQLERRM, 1, 200);
        
          log_p(SQLERRM);
        
          UPDATE xxs3_rtr_open_trx_lines
          
          SET cleanse_status = 'FAIL'
             ,cleanse_error  = i.cleanse_error ||
                               ' INTERFACE_LINE_ATTRIBUTE1 FLAG  :' ||
                               l_error_message || ' ,'
          WHERE xx_open_trx_id = i.xx_open_trx_id;
        
      END;
    
    END LOOP;
  
  EXCEPTION
    WHEN OTHERS THEN
      l_error_message := (SQLERRM || 'backtrace: ' ||
                         dbms_utility.format_error_backtrace);
      log_p(l_error_message);
    
  END cleanse_intf_line_attr_lines;




  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used for AR Open Transactions Cleanse Rules Check
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  29/07/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE cleanse_intf_line_attr_dist(p_err_code OUT VARCHAR2
                                       ,p_err_msg  OUT VARCHAR2) IS
  
    l_status        VARCHAR2(10) := 'SUCCESS';
    l_check_rule    VARCHAR2(10) := 'TRUE';
    l_period_name   VARCHAR2(10);
    l_error_message VARCHAR2(1000) := '';
    l_s3_line_desc  VARCHAR2(240) := '';
  
    CURSOR c_cleanse_dist IS
      SELECT * FROM xxobjt.xxs3_rtr_open_trx_distribution;
  
  BEGIN
  
    FOR j IN c_cleanse_dist
    LOOP
    
      BEGIN
        IF j.order_number IS NOT NULL
        THEN
        
          UPDATE xxs3_rtr_open_trx_distribution
          SET interface_line_attribute1 = (j.interface_line_attribute1 || '-' ||
                                          j.order_number)
             ,cleanse_status            = 'PASS'
          WHERE xx_open_trx_dist_id = j.xx_open_trx_dist_id;
        
        ELSE
        
          UPDATE xxs3_rtr_open_trx_distribution
          SET interface_line_attribute1 = ('AR - ' || j.trx_number)
             ,cleanse_status            = 'PASS'
          WHERE xx_open_trx_dist_id = j.xx_open_trx_dist_id;
        
        END IF;
      
      EXCEPTION
        WHEN OTHERS THEN
          l_error_message := substr(SQLERRM, 1, 200);
        
          UPDATE xxs3_rtr_open_trx_distribution
          
          SET cleanse_status = 'FAIL'
             ,cleanse_error  = j.cleanse_error ||
                               ' INTERFACE_LINE_ATTRIBUTE1 FLAG  :' ||
                               l_error_message || ' ,'
          WHERE xx_open_trx_dist_id = j.xx_open_trx_dist_id;
        
      END;
    
    END LOOP;
  
  EXCEPTION
    WHEN OTHERS THEN
      l_error_message := (SQLERRM || 'backtrace: ' ||
                         dbms_utility.format_error_backtrace);
      log_p(l_error_message);
  END cleanse_intf_line_attr_dist;




  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used for AR Open Transactions Cleanse Rules Check
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  29/07/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE cleanse_multi_code_combination(p_err_code OUT VARCHAR2
                                          ,p_err_msg  OUT VARCHAR2) IS
  
    l_concatenated_segment   VARCHAR2(1000) := NULL;
    l_concatenated_segment_x VARCHAR2(240) := NULL;
    l_legacy_company         VARCHAR2(25) := NULL;
    l_legacy_account         VARCHAR2(25) := NULL;
    l_legacy_product         VARCHAR2(25) := NULL;
    l_legacy_location        VARCHAR2(25) := NULL;
    l_legacy_intercompany    VARCHAR2(25) := NULL;
    l_legacy_department      VARCHAR2(25) := NULL;
    l_error_message          VARCHAR2(200);
  
    CURSOR c_line_distribution IS
      SELECT *
      FROM xxs3_rtr_open_trx_distribution
      WHERE account_class = 'REV'
      AND line_description NOT IN
            ('Original Tax Amount', 'Conv Application');
  
    CURSOR c_code_combi(p_customer_trx_line_id VARCHAR2) IS
      SELECT cc.concatenated_segments legacy_code_combination
            ,cc.segment1              AS legacy_company
            ,cc.segment2              AS legacy_department
            ,cc.segment3              AS legacy_account
            ,cc.segment5              AS legacy_product
            ,cc.segment6              AS legacy_location
            ,cc.segment7              AS legacy_intercompany
      FROM xla_ae_headers               xah
          ,xla_ae_lines                 xal
          ,gl_code_combinations_kfv     cc
          ,xla_distribution_links       xdl
          ,ra_cust_trx_line_gl_dist_all dist
          ,ra_customer_trx_lines_all    arl
          ,ra_customer_trx_all          arh
          ,ra_batch_sources_all         rba
      WHERE xal.ae_header_id = xah.ae_header_id
      AND xal.code_combination_id = cc.code_combination_id
      AND balance_type_code = 'A'
      AND gl_transfer_status_code = 'Y'
      AND xal.ae_header_id = xdl.ae_header_id
      AND xal.ae_line_num = xdl.ae_line_num
      AND xdl.source_distribution_type = 'RA_CUST_TRX_LINE_GL_DIST_ALL'
      AND xdl.source_distribution_id_num_1 = dist.cust_trx_line_gl_dist_id
      AND dist.customer_trx_line_id = arl.customer_trx_line_id
      AND arl.customer_trx_id = arh.customer_trx_id
      AND arh.batch_source_id = rba.batch_source_id
      AND arh.org_id = rba.org_id
      AND arl.customer_trx_line_id = p_customer_trx_line_id
      AND account_class = 'REV'
      ORDER BY arl.customer_trx_line_id;
  
  BEGIN
  
    FOR k IN c_line_distribution
    LOOP
      l_concatenated_segment   := NULL;
      l_concatenated_segment_x := NULL;
      l_legacy_company         := NULL;
      l_legacy_department      := NULL;
      l_legacy_account         := NULL;
      l_legacy_product         := NULL;
      l_legacy_location        := NULL;
      l_legacy_intercompany    := NULL;
    
      FOR i IN c_code_combi(k.legacy_customer_trx_line_id)
      LOOP
      
        IF l_concatenated_segment IS NULL
        THEN
          --1st rec or 1 rec
        
          l_concatenated_segment := i.legacy_code_combination;
        
          l_legacy_company      := i.legacy_company;
          l_legacy_account      := i.legacy_account;
          l_legacy_product      := i.legacy_product;
          l_legacy_location     := i.legacy_location;
          l_legacy_intercompany := i.legacy_intercompany;
          l_legacy_department   := i.legacy_department;
        
        ELSE
          -- multiple rec
        
          l_concatenated_segment := to_char(i.legacy_code_combination) || '/' ||
                                    l_concatenated_segment;
        
          l_legacy_company      := NULL;
          l_legacy_department   := NULL;
          l_legacy_account      := NULL;
          l_legacy_product      := NULL;
          l_legacy_location     := NULL;
          l_legacy_intercompany := NULL;
        
        END IF;
      
        l_concatenated_segment_x := substr(l_concatenated_segment, 1, 200);
      
        UPDATE xxobjt.xxs3_rtr_open_trx_distribution
        SET legacy_code_combination = l_concatenated_segment_x
           ,legacy_company          = l_legacy_company
           ,legacy_department       = l_legacy_department
           ,legacy_account          = l_legacy_account
           ,legacy_product          = l_legacy_product
           ,legacy_location         = l_legacy_location
           ,legacy_intercompany     = l_legacy_intercompany
        
        WHERE legacy_customer_trx_line_id = k.legacy_customer_trx_line_id
        AND legacy_customer_trx_id = k.legacy_customer_trx_id;
      
      END LOOP;
    
    END LOOP;
  
  EXCEPTION
  
    WHEN OTHERS THEN
      l_error_message := (SQLERRM || 'backtrace: ' ||
                         dbms_utility.format_error_backtrace);
      log_p(l_error_message);
    
  END;



  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used for AR Open Transactions Data Quality Rules Check
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  29/07/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE quality_check_open_trx(p_err_code OUT VARCHAR2
                                  ,p_err_msg  OUT VARCHAR2) IS
    l_status     VARCHAR2(10) := 'SUCCESS';
    l_check_rule VARCHAR2(10) := 'TRUE';
  
    CURSOR c_open_trx IS
      SELECT *
      FROM xxobjt.xxs3_rtr_open_trx_distribution
      WHERE process_flag = 'N';
  BEGIN
    FOR i IN c_open_trx
    LOOP
      l_status     := 'SUCCESS';
      l_check_rule := 'TRUE';
      --EQT-202
      IF NOT xxs3_dq_util_pkg.eqt_202(i.legacy_customer_trx_id)
      THEN
        insert_update_open_trx_dq(i.xx_open_trx_dist_id, 'EQT-202:REC Distribution Missing', 'REC Distribution Missing', p_err_code, p_err_msg);
        l_status := 'ERR';
      END IF;
    
      --EQT-203
      IF NOT xxs3_dq_util_pkg.eqt_203(i.legacy_customer_trx_id)
      THEN
        insert_update_open_trx_dq(i.xx_open_trx_dist_id, 'EQT-203:More than one REC distribution exists for invoice', 'More than one REC distribution exists for invoice', p_err_code, p_err_msg);
        l_status := 'ERR';
      END IF;
    
      --EQT-204
      IF NOT xxs3_dq_util_pkg.eqt_204(i.legacy_customer_trx_line_id)
      THEN
        insert_update_open_trx_dq(i.xx_open_trx_dist_id, 'EQT-204:REV Distribution Missing for Invoice Line', 'REV Distribution Missing for Invoice Line', p_err_code, p_err_msg);
        l_status := 'ERR';
      END IF;
    
      --EQT-205
      IF NOT xxs3_dq_util_pkg.eqt_205(i.legacy_customer_trx_line_id)
      THEN
        insert_update_open_trx_dq(i.xx_open_trx_dist_id, 'EQT-205:More than one REV distribution exists for Invoice Line', 'More than one REV distribution exists for Invoice Line', p_err_code, p_err_msg);
        l_status := 'ERR';
      END IF;
    
      --EQT-206
      IF NOT xxs3_dq_util_pkg.eqt_206(i.legacy_customer_trx_id)
      THEN
        insert_update_open_trx_dq(i.xx_open_trx_dist_id, 'EQT-205:The sum of the REV distributions does not equal the REC distribution', 'The sum of the REV distributions does not equal the REC distribution', p_err_code, p_err_msg);
        l_status := 'ERR';
      END IF;
    
      --EQT-207
      IF NOT xxs3_dq_util_pkg.eqt_207(i.legacy_customer_trx_id)
      THEN
        insert_update_open_trx_dq(i.xx_open_trx_dist_id, 'EQT-205:REC distribution is equal to remaining due accounts', 'REC distribution is equal to remaining due accounts', p_err_code, p_err_msg);
        l_status := 'ERR';
      END IF;
    
      IF l_status <> 'ERR'
      THEN
        UPDATE xxobjt.xxs3_rtr_open_trx_distribution
        SET process_flag = 'Y'
        WHERE xx_open_trx_dist_id = i.xx_open_trx_dist_id;
      END IF;
    END LOOP;
    COMMIT;
  
  END quality_check_open_trx;




  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used for AR Open Transactions Extract
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  29/07/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE open_trx_extract(x_errbuf  OUT VARCHAR2
                            ,x_retcode OUT NUMBER) AS
    l_err_code               NUMBER;
    l_error_message          VARCHAR2(2000);
    l_s3_gl_string           VARCHAR2(200);
    l_output_code            NUMBER; --
    l_output_code_coa_update NUMBER; --
    l_output                 VARCHAR2(100); --
    l_output_coa_update      VARCHAR2(100); --
    l_line_number            NUMBER; --
    l_open_trx_id            NUMBER;
    l_org_id                 NUMBER := fnd_global.org_id; -- stratasys ou
    l_start                  NUMBER;
  
  
  
    ----------------------------------------------
  
  
    CURSOR c_invoice_lines IS
      SELECT arh.org_id legacy_org_id
            ,l_org_id AS s3_org_id
            ,arh.customer_trx_id legacy_customer_trx_id
            ,customer_trx_line_id legacy_customer_trx_line_id
            ,cust.cust_account_id
            ,b_su.cust_acct_site_id legacy_bill_to_site_id
            ,s_su.cust_acct_site_id legacy_ship_to_site_id
            ,b_su.site_use_id AS legacy_bill_to_site_use_id
            ,s_su.site_use_id AS legacy_ship_to_site_use_id
            ,arh.trx_number
            ,arh.trx_date
            ,rba.NAME AS legacy_invoice_source
            ,'Conversion' AS batch_source_name
            ,ct_reference AS legacy_invoice_source_number
            , --- changed from interface_header_attribute1 to ct_reference
             'CONVERSION' AS interface_line_context
            ,rctt.NAME AS legacy_transaction_type
            ,cust.account_number legacy_account_number
            ,cust.account_name
            ,b_su.location AS bill_to_location
            ,s_cust.account_number AS legacy_ship_to_account_number
            , -- added 8/10
             s_su.location AS ship_to_location
            ,pt.NAME AS legacy_payment_terms
            ,line_number
            ,segment1 AS item_number
            ,TRIM(REPLACE(REPLACE(REPLACE(REPLACE(arl.description, ',', ' '), '"', ' '), chr(10), ' '), chr(13), ' ')) AS line_description
            ,'US001_USD_P' AS s3_ledger_id
            ,line_type
            ,CASE
               WHEN CLASS = 'CM' THEN
                quantity_credited
               WHEN CLASS = 'INV' THEN
                quantity_invoiced
               ELSE
                NULL
             END AS quantity_invoiced
            ,unit_selling_price
            ,quantity_invoiced * unit_selling_price invoiced_quant_sell_price
            ,extended_amount
            ,revenue_amount
            ,ps.invoice_currency_code
            ,'User' AS exchange_rate_type
            ,ps.exchange_rate
            ,ps.exchange_date
            ,ps.number_of_due_dates
            ,ps.amount_due_original
            ,ps.amount_due_remaining
            ,tax_original
            ,tax_remaining
            ,CLASS
            ,CASE
               WHEN CLASS = 'INV' THEN
                'LEGACY CONV INV'
               ELSE
                'LEGACY CONV CM'
             END AS cust_trx_type_name
            ,arh.primary_salesrep_id
            ,'N' AS printing_option
            ,'Stratasys, Inc.' AS legal_entity_id
            ,'N' taxable_flag
            ,'EA' oum_code
            ,'31-JUL-2016' AS s3_gl_date
      FROM ra_customer_trx_lines_all arl
          ,ra_customer_trx_all       arh
          ,ra_cust_trx_types_all     rctt
          ,ra_batch_sources_all      rba
          ,hz_cust_accounts          cust
          ,hz_cust_accounts          s_cust
          ,hz_cust_site_uses_all     b_su
          ,hz_cust_site_uses_all     s_su
          ,ar_payment_schedules_all  ps
          ,mtl_system_items_b        im
          ,ra_terms_vl               pt
      WHERE arl.customer_trx_id = arh.customer_trx_id
      AND arh.batch_source_id = rba.batch_source_id
      AND arh.org_id = rba.org_id
      AND arh.cust_trx_type_id = rctt.cust_trx_type_id
      AND arh.org_id = rctt.org_id
      AND arh.bill_to_customer_id = cust.cust_account_id
      AND arh.ship_to_customer_id = s_cust.cust_account_id(+)
      AND arh.bill_to_site_use_id = b_su.site_use_id(+)
      AND arh.ship_to_site_use_id = s_su.site_use_id(+)
      AND arh.customer_trx_id = ps.customer_trx_id
      AND arl.inventory_item_id = im.inventory_item_id(+)
      AND im.organization_id(+) = 91
      AND arh.term_id = pt.term_id(+)
      AND arh.org_id = 737
      AND ps.status = 'OP'
      AND line_type IN ('LINE')
      AND CLASS IN ('INV', 'CM')
      AND number_of_due_dates = 1 -- temporary, to be removed once inline view for PS is created to support installment
      ORDER BY arh.trx_date DESC;
  
  
  
  
    CURSOR c_dist_cust_trx_id IS
      SELECT DISTINCT (legacy_customer_trx_id)
      FROM xxobjt.xxs3_rtr_open_trx_lines;
  
  
    CURSOR c_tax_conv(p_customer_trx_id NUMBER) IS
      SELECT arh.org_id legacy_org_id
            ,l_org_id AS s3_org_id /*'Stratasys US OU' s3_org_id*/
            ,arh.customer_trx_id legacy_customer_trx_id
            ,decode(tax_and_app_lines.description, 'Original Tax Amount', arh.customer_trx_id, /*|| '-T',*/ 'Conv Application', arh.customer_trx_id /*|| '-A'*/) legacy_customer_trx_line_id
             --CUST_TRX_ID_T--NULL as legacy_CUSTOMER_TRX_LINE_ID, -- to be replaced by a system generated line id since this does exist as a single line in legacy )
            ,cust.cust_account_id
            ,b_su.cust_acct_site_id legacy_bill_to_site_id
            ,s_su.cust_acct_site_id legacy_ship_to_site_id
            ,b_su.site_use_id AS legacy_bill_to_site_use_id
            ,s_su.site_use_id AS legacy_ship_to_site_use_id
            ,arh.trx_number
            ,arh.trx_date
            ,rba.NAME AS legacy_invoice_source
            ,'Conversion' AS batch_source_name
            ,ct_reference AS legacy_invoice_source_number
            , --- changed from  interface_header_attribute1 to ct_reference
             'CONVERSION' AS interface_line_context
            ,rctt.NAME AS legacy_transaction_type
            ,cust.account_number legacy_account_number
            ,cust.account_name
            ,b_su.location AS bill_to_location
            ,s_cust.account_number AS legacy_ship_to_account_number
            , -- added 8/10
             s_su.location AS ship_to_location
            ,pt.NAME AS legacy_payment_terms
            ,NULL AS line_number
            ,NULL AS item_number
            ,TRIM(REPLACE(REPLACE(REPLACE(REPLACE(tax_and_app_lines.description, ',', ' '), '"', ' '), chr(10), ' '), chr(13), ' ')) AS line_description
            ,TRIM(REPLACE(REPLACE(REPLACE(REPLACE(tax_and_app_lines.description, ',', ' '), '"', ' '), chr(10), ' '), chr(13), ' ')) AS s3_line_description
            ,'US001_USD_P' AS s3_ledger_id
            ,'LINE' AS line_type
            ,1 AS quantity_invoiced
            ,amount AS unit_selling_price
            ,NULL invoiced_quant_sell_price
            ,amount AS extended_amount
            ,NULL revenue_amount
            ,tax_and_app_lines.invoice_currency_code
            ,'User' AS exchange_rate_type
            ,tax_and_app_lines.exchange_rate
            ,tax_and_app_lines. exchange_date
            ,tax_and_app_lines.number_of_due_dates
            ,tax_and_app_lines.amount_due_original
            ,tax_and_app_lines.amount_due_remaining
            ,tax_original
            ,tax_remaining
            ,CLASS
            ,CASE
               WHEN CLASS = 'INV' THEN
                'LEGACY CONV INV'
               ELSE
                'LEGACY CONV CM'
             END AS cust_trx_type_name
            ,arh.primary_salesrep_id
            ,'N' AS printing_option
            ,'Stratasys, Inc.' AS legal_entity_id
            ,'N' taxable_flag
            ,'EA' oum_code
            ,'31-JUL-2016' AS s3_gl_date
      
      FROM (SELECT customer_trx_id
                  ,CLASS
                  ,number_of_due_dates
                  ,invoice_currency_code
                  ,ps.exchange_rate
                  ,ps.exchange_date
                  ,ps.amount_due_original
                  ,ps.amount_due_remaining
                  ,tax_original
                  ,tax_remaining
                  ,'Original Tax Amount' AS description
                  ,tax_original AS amount
            FROM ar_payment_schedules_all ps
            UNION ALL
            SELECT customer_trx_id
                  ,CLASS
                  ,number_of_due_dates
                  ,invoice_currency_code
                  ,ps.exchange_rate
                  ,ps.exchange_date
                  ,ps.amount_due_original
                  ,ps.amount_due_remaining
                  ,tax_original
                  ,tax_remaining
                  ,'Conv Application' AS description
                  ,(ps.amount_due_remaining - ps.amount_due_original) AS amount
            FROM ar_payment_schedules_all ps) tax_and_app_lines
          ,ra_customer_trx_all arh
          ,ra_cust_trx_types_all rctt
          ,ra_batch_sources_all rba
          ,hz_cust_accounts cust
          ,hz_cust_accounts s_cust
          ,hz_cust_site_uses_all b_su
          ,hz_cust_site_uses_all s_su
          ,ra_terms_vl pt
      WHERE arh.customer_trx_id = tax_and_app_lines.customer_trx_id
      AND arh.batch_source_id = rba.batch_source_id
      AND arh.org_id = rba.org_id
      AND arh.cust_trx_type_id = rctt.cust_trx_type_id
      AND arh.org_id = rctt.org_id
      AND arh.bill_to_customer_id = cust.cust_account_id
      AND arh.ship_to_customer_id = s_cust.cust_account_id(+)
      AND arh.bill_to_site_use_id = b_su.site_use_id(+)
      AND arh.ship_to_site_use_id = s_su.site_use_id(+)
      AND arh.term_id = pt.term_id(+)
      AND amount <> 0 -- added 8/10
      AND arh.customer_trx_id = p_customer_trx_id;
  
  
  
  
  
  
    CURSOR c_dist_cust_trx_line_id IS
      SELECT DISTINCT (legacy_customer_trx_line_id)
      FROM xxobjt.xxs3_rtr_open_trx_lines;
  
  
    CURSOR c_rev_distbn(p_customer_trx_line_id NUMBER) IS
      SELECT DISTINCT rba.NAME AS legacy_invoice_source
                     ,ct_reference AS order_number
                     , --- changed from  interface_header_attribute1 to ct_reference
                      'CONVERSION' AS interface_line_context
                     ,arh.customer_trx_id legacy_customer_trx_id
                     ,arl.customer_trx_line_id legacy_customer_trx_line_id
                     ,
                      /*TRIM(REPLACE(REPLACE(arl.description, CHR(13)),
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               CHR(10))) AS line_description,*/TRIM(REPLACE(REPLACE(REPLACE(REPLACE(arl.description, ',', ' '), '"', ' '), chr(10), ' '), chr(13), ' ')) AS line_description
                     ,arh.trx_number
                     ,line_number
                     ,extended_amount AS amount
                     ,account_class
                     ,'US001_USD_P' AS s3_ledger_id
                     ,'' legacy_code_combination
                     ,'' legacy_company
                     ,'' legacy_department
                     ,'' legacy_account
                     ,'' legacy_product
                     ,'' legacy_location
                     ,'' legacy_intercompany
                     ,'' legacy_division
                     ,arh.org_id AS legacy_org_id
                     ,l_org_id s3_org_id
                     , -- 'Stratasys US OU' s3_org_id,
                      '401' AS s3_company
                     ,'000' AS s3_business_unit
                     ,'0000' AS s3_department
                     ,'900000' AS s3_account
                     ,'0000' AS s3_product
                     ,'000' AS s3_location
                     ,'000' AS s3_intercompany
                     ,'000' AS s3_future
      FROM ra_cust_trx_line_gl_dist_all dist
          ,ra_customer_trx_lines_all    arl
          ,ra_customer_trx_all          arh
          ,ra_batch_sources_all         rba
      WHERE dist.customer_trx_line_id = arl.customer_trx_line_id
      AND arl.customer_trx_id = arh.customer_trx_id
      AND arh.batch_source_id = rba.batch_source_id
      AND arh.org_id = rba.org_id
           --and arl.customer_trx_line_id = 3376949 for testing
      AND arl.customer_trx_line_id = p_customer_trx_line_id
      AND account_class = 'REV';
  
  
  
  
  
  
    CURSOR c_recv_distbn(p_customer_trx_id NUMBER) IS
      SELECT rba.NAME AS legacy_invoice_source
            ,ct_reference AS order_number
            , --- changed from  interface_header_attribute1 to ct_reference
             'CONVERSION' AS interface_line_context
            ,arh.customer_trx_id legacy_customer_trx_id
            ,NULL legacy_customer_trx_line_id
            ,'Receivables-' || arh.customer_trx_id AS line_description
            ,arh.trx_number
            ,NULL line_number
            ,amount_due_remaining AS amount
            ,account_class
            ,'US001_USD_P' AS s3_ledger_id
            ,cc.concatenated_segments legacy_code_combination
            ,cc.segment1 AS legacy_company
            ,cc.segment2 AS legacy_department
            ,cc.segment3 AS legacy_account
            ,cc.segment5 AS legacy_product
            ,cc.segment6 AS legacy_location
            ,cc.segment7 AS legacy_intercompany
            ,cc.segment10 AS legacy_division --
            ,arh.org_id AS legacy_org_id
            ,l_org_id AS s3_org_id
            , --'Stratasys US OU' s3_org_id,
             NULL AS s3_company
            , -- to be assigned by CoA mapping
             NULL AS s3_business_unit
            , -- to be assigned by CoA mapping
             NULL AS s3_department
            , -- to be assigned by CoA mapping
             NULL AS s3_account
            , -- to be assigned by CoA mapping
             NULL AS s3_product
            , -- to be assigned by CoA mapping
             NULL AS s3_location
            , -- to be assigned by CoA mapping
             NULL AS s3_intercompany
            , -- to be assigned by CoA mapping
             NULL AS s3_future -- to be assigned by CoA mapping
      FROM xla_ae_headers               xah
          ,xla_ae_lines                 xal
          ,gl_code_combinations_kfv     cc
          ,xla_distribution_links       xdl
          ,ra_cust_trx_line_gl_dist_all dist
          ,ra_customer_trx_all          arh
          ,ar_payment_schedules_all     ps
          ,ra_batch_sources_all         rba
      WHERE xal.ae_header_id = xah.ae_header_id
      AND xal.code_combination_id = cc.code_combination_id
      AND balance_type_code = 'A'
      AND gl_transfer_status_code = 'Y'
      AND xal.ae_header_id = xdl.ae_header_id
      AND xal.ae_line_num = xdl.ae_line_num
      AND xdl.source_distribution_type = 'RA_CUST_TRX_LINE_GL_DIST_ALL'
      AND xdl.source_distribution_id_num_1 = dist.cust_trx_line_gl_dist_id
      AND dist.customer_trx_id = arh.customer_trx_id
      AND arh.customer_trx_id = ps.customer_trx_id
      AND arh.batch_source_id = rba.batch_source_id
      AND arh.org_id = rba.org_id
      AND arh.customer_trx_id = p_customer_trx_id
      AND account_class = 'REC';
  
  
  
  
  
  
    CURSOR c_tax_app_distbn(p_customer_trx_id NUMBER) IS
      SELECT legacy_invoice_source
            ,legacy_invoice_source_number AS order_number
            ,'CONVERSION' AS interface_line_context
            ,legacy_customer_trx_id
            ,
             /*NULL */legacy_customer_trx_line_id
            , -- should be system generated line id 
             line_description
            ,trx_number
            ,line_number
            ,extended_amount AS amount
            ,'REV' AS account_class
            ,'US001_USD_P' AS s3_ledger_id
            ,NULL AS legacy_code_combination
            ,NULL AS legacy_company
            ,NULL AS legacy_department
            ,NULL AS legacy_account
            ,NULL AS legacy_product
            ,NULL AS legacy_location
            ,NULL AS legacy_intercompany
            ,NULL AS legacy_division
            ,legacy_org_id
            ,l_org_id AS s3_org_id
            , -- 'Stratasys US OU' s3_org_id,
             '401' AS s3_company
            ,'000' AS s3_business_unit
            ,'0000' AS s3_department
            ,CASE
               WHEN line_description = 'Original Tax Amount' THEN
                '900001'
               ELSE
                '900000'
             END AS s3_account
            ,'0000' AS s3_product
            ,'000' AS s3_location
            ,'000' AS s3_intercompany
            ,'000' AS s3_future
      FROM xxobjt.xxs3_rtr_open_trx_lines
      WHERE line_description IN ('Original Tax Amount', 'Conv Application')
      AND legacy_customer_trx_id = p_customer_trx_id;
  
    CURSOR c_distinct_trx_no IS
      SELECT DISTINCT (legacy_customer_trx_id)
      FROM xxobjt.xxs3_rtr_open_trx_lines;
  
  
  
  
  
  
  
    ----------------------------------------------
  
  BEGIN
  
    l_start := dbms_utility.get_time;
  
  
    log_p('Truncating Tables...');
    EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.xxs3_rtr_open_trx_lines';
  
    EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.xxs3_rtr_open_trx_distribution';
  
    EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.xxs3_rtr_open_trx_lines_dq';
  
    EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.xxs3_rtr_open_trx_distbn_dq';
  
    BEGIN
    
      log_p('BEGIN SQL1 : Extract for Lines');
    
      FOR i IN c_invoice_lines
      LOOP
      
        INSERT INTO xxobjt.xxs3_rtr_open_trx_lines
          (xx_open_trx_id
          ,date_of_extract
          ,process_flag
          ,legacy_org_id
          ,s3_org_id
          ,legacy_customer_trx_id
          ,legacy_customer_trx_line_id
          ,cust_account_id
          ,legacy_bill_to_site_id
          ,legacy_ship_to_site_id
          ,legacy_bill_to_site_use_id
          ,legacy_ship_to_site_use_id
          ,trx_number
          ,trx_date
          ,legacy_invoice_source
          ,batch_source_name
          ,legacy_invoice_source_number
          ,interface_line_context
          ,legacy_transaction_type
          ,legacy_account_number
          ,account_name
          ,bill_to_location
          ,legacy_ship_to_account_number
          ,ship_to_location
          ,legacy_payment_terms
          ,line_number
          ,item_number
          ,line_description
          ,s3_ledger_id
          ,line_type
          ,quantity_invoiced
          ,unit_selling_price
          ,invoiced_quant_sell_price
          ,extended_amount
          ,revenue_amount
          ,invoice_currency_code
          ,exchange_rate_type
          ,exchange_rate
          ,exchange_date
          ,number_of_due_dates
          ,amount_due_original
          ,amount_due_remaining
          ,tax_original
          ,tax_remaining
          ,CLASS
          ,cust_trx_type_name
          ,primary_salesrep_id
          ,printing_option
          ,legal_entity_id
          ,taxable_flag
          ,oum_code
          ,s3_gl_date)
        VALUES
          (xxobjt.xxs3_rtr_open_trx_lines_seq.NEXTVAL
          ,SYSDATE
          ,'N'
          ,i.legacy_org_id
          ,i.s3_org_id
          ,i.legacy_customer_trx_id
          ,i.legacy_customer_trx_line_id
          ,i.cust_account_id
          ,i.legacy_bill_to_site_id
          ,i.legacy_ship_to_site_id
          ,i.legacy_bill_to_site_use_id
          ,i.legacy_ship_to_site_use_id
          ,i.trx_number
          ,i.trx_date
          ,i.legacy_invoice_source
          ,i.batch_source_name
          ,i.legacy_invoice_source_number
          ,i.interface_line_context -- 'CONVERSION'
          ,i.legacy_transaction_type
          ,i.legacy_account_number
          ,i.account_name
          ,i.bill_to_location
          ,i.legacy_ship_to_account_number
          ,i.ship_to_location
          ,i.legacy_payment_terms
          ,i.line_number
          ,i.item_number
          ,i.line_description
          ,i.s3_ledger_id
          ,i.line_type
          ,i.quantity_invoiced
          ,i.unit_selling_price
          ,i.invoiced_quant_sell_price
          ,i.extended_amount
          ,i.revenue_amount
          ,i.invoice_currency_code
          ,i.exchange_rate_type
          ,i.exchange_rate
          ,i.exchange_date
          ,i.number_of_due_dates
          ,i.amount_due_original
          ,i.amount_due_remaining
          ,i.tax_original
          ,i.tax_remaining
          ,i.CLASS
          ,i.cust_trx_type_name
          ,i.primary_salesrep_id
          ,i.printing_option
          ,i.legal_entity_id
          ,i.taxable_flag
          ,i.oum_code
          ,i.s3_gl_date);
      
      END LOOP; -- query 1 end
    
      log_p('END SQL1 : Extract for Lines');
    
    
    
    
      log_p('BEGIN SQL2 : Extract for Original tax and Conv App per customer_trx_id');
    
      FOR i IN c_dist_cust_trx_id
      LOOP
      
        FOR j IN c_tax_conv(i.legacy_customer_trx_id)
        LOOP
          INSERT INTO xxobjt.xxs3_rtr_open_trx_lines
            (xx_open_trx_id
            ,date_of_extract
            ,process_flag
            ,legacy_org_id
            ,s3_org_id
            ,legacy_customer_trx_id
            ,legacy_customer_trx_line_id
            ,cust_account_id
            ,legacy_bill_to_site_id
            ,legacy_ship_to_site_id
            ,legacy_bill_to_site_use_id
            ,legacy_ship_to_site_use_id
            ,trx_number
            ,trx_date
            ,legacy_invoice_source
            ,batch_source_name
            ,legacy_invoice_source_number
            ,interface_line_context
            ,legacy_transaction_type
            ,legacy_account_number
            ,account_name
            ,bill_to_location
            ,legacy_ship_to_account_number
            ,ship_to_location
            ,legacy_payment_terms
            ,line_number
            ,item_number
            ,line_description
            ,s3_line_description
            ,s3_ledger_id
            ,line_type
            ,quantity_invoiced
            ,unit_selling_price
            ,invoiced_quant_sell_price
            ,extended_amount
            ,revenue_amount
            ,invoice_currency_code
            ,exchange_rate_type
            ,exchange_rate
            ,exchange_date
            ,number_of_due_dates
            ,amount_due_original
            ,amount_due_remaining
            ,tax_original
            ,tax_remaining
            ,CLASS
            ,cust_trx_type_name
            ,primary_salesrep_id
            ,printing_option
            ,legal_entity_id
            ,taxable_flag
            ,oum_code
            ,s3_gl_date)
          VALUES
            (xxobjt.xxs3_rtr_open_trx_lines_seq.NEXTVAL
            ,SYSDATE
            ,'N'
            ,j.legacy_org_id
            ,j.s3_org_id
            ,j.legacy_customer_trx_id
            ,j.legacy_customer_trx_line_id
            ,j.cust_account_id
            ,j.legacy_bill_to_site_id
            ,j.legacy_ship_to_site_id
            ,j.legacy_bill_to_site_use_id
            ,j.legacy_ship_to_site_use_id
            ,j.trx_number
            ,j.trx_date
            ,j.legacy_invoice_source
            ,j.batch_source_name
            ,j.legacy_invoice_source_number
            ,j.interface_line_context -- 'CONVERSION'
            ,j.legacy_transaction_type
            ,j.legacy_account_number
            ,j.account_name
            ,j.bill_to_location
            ,j.legacy_ship_to_account_number
            ,j.ship_to_location
            ,j.legacy_payment_terms
            ,j.line_number
            ,j.item_number
            ,j.line_description
            ,j.s3_line_description
            ,j.s3_ledger_id
            ,j.line_type
            ,j.quantity_invoiced
            ,j.unit_selling_price
            ,j.invoiced_quant_sell_price
            ,j.extended_amount
            ,j.revenue_amount
            ,j.invoice_currency_code
            ,j.exchange_rate_type
            ,j.exchange_rate
            ,j.exchange_date
            ,j.number_of_due_dates
            ,j.amount_due_original
            ,j.amount_due_remaining
            ,j.tax_original
            ,j.tax_remaining
            ,j.CLASS
            ,j.cust_trx_type_name
            ,j.primary_salesrep_id
            ,j.printing_option
            ,j.legal_entity_id
            ,j.taxable_flag
            ,j.oum_code
            ,j.s3_gl_date);
        
        END LOOP;
      
      END LOOP;
    
      COMMIT;
      log_p('END SQL2 : Extract for Original tax and Conv App');
    
    
    
    
    
      log_p('BEGIN SQL3 : Update line numbers for Tax and Conv App in for Lines stage');
    
      FOR i IN (SELECT *
                FROM xxobjt.xxs3_rtr_open_trx_lines
                WHERE line_description = 'Original Tax Amount')
      LOOP
      
        IF i.line_number IS NULL
        THEN
          UPDATE xxobjt.xxs3_rtr_open_trx_lines
          SET line_number = (nvl((SELECT MAX(line_number)
                                 FROM xxs3_rtr_open_trx_lines
                                 WHERE legacy_customer_trx_id =
                                       i.legacy_customer_trx_id), 0) + 1)
          WHERE legacy_customer_trx_id = i.legacy_customer_trx_id
          AND line_description = 'Original Tax Amount';
        
        END IF;
      
      END LOOP;
    
      FOR i IN (SELECT *
                FROM xxobjt.xxs3_rtr_open_trx_lines
                WHERE line_description = 'Conv Application')
      LOOP
      
        IF i.line_number IS NULL
        THEN
          UPDATE xxobjt.xxs3_rtr_open_trx_lines
          SET line_number = (nvl((SELECT MAX(line_number)
                                 FROM xxs3_rtr_open_trx_lines
                                 WHERE legacy_customer_trx_id =
                                       i.legacy_customer_trx_id), 0) + 1)
          WHERE legacy_customer_trx_id = i.legacy_customer_trx_id
          AND line_description = 'Conv Application';
        
        END IF;
      
      END LOOP;
      COMMIT;
      log_p('END SQL3 : Update line numbers for Tax and conv app');
    
    
    
    
    
    
      log_p('BEGIN SQL4 : Extract for Revenue Distributions for each customer_trx_line_id ');
    
      FOR i IN c_dist_cust_trx_line_id
      LOOP
      
        FOR j IN c_rev_distbn(i.legacy_customer_trx_line_id)
        LOOP
        
          INSERT INTO xxobjt.xxs3_rtr_open_trx_distribution
            (xx_open_trx_dist_id
            ,date_of_extract
            ,process_flag
            ,legacy_invoice_source
            ,order_number
            ,interface_line_context
            ,legacy_customer_trx_id
            ,legacy_customer_trx_line_id
            ,line_description
            ,trx_number
            ,line_number
            ,amount
            ,account_class
            ,s3_ledger_id
            ,legacy_code_combination
            ,legacy_company
            ,legacy_department
            ,legacy_account
            ,legacy_product
            ,legacy_location
            ,legacy_intercompany
            ,legacy_division
            ,legacy_org_id
            ,s3_org_id
            ,s3_company
            ,s3_business_unit
            ,s3_department
            ,s3_account
            ,s3_product
            ,s3_location
            ,s3_intercompany
            ,s3_future)
          VALUES
            (xxobjt.xxs3_rtr_open_trx_distbn_seq.NEXTVAL
            ,SYSDATE
            ,'N'
            ,j.legacy_invoice_source
            ,j.order_number
            ,j.interface_line_context
            ,j.legacy_customer_trx_id
            ,j.legacy_customer_trx_line_id
            ,j.line_description
            ,j.trx_number
            ,j.line_number
            ,j.amount
            ,j.account_class
            ,j.s3_ledger_id
            ,j.legacy_code_combination
            ,j.legacy_company
            ,j.legacy_department
            ,j.legacy_account
            ,j.legacy_product
            ,j.legacy_location
            ,j.legacy_intercompany
            ,j.legacy_division
            ,j.legacy_org_id
            ,j.s3_org_id
            ,j.s3_company
            ,j.s3_business_unit
            ,j.s3_department
            ,j.s3_account
            ,j.s3_product
            ,j.s3_location
            ,j.s3_intercompany
            ,j.s3_future);
        
        END LOOP;
      
      END LOOP;
      COMMIT;
      log_p('END SQL4 : Extract for Revenue Distributions for each customer_trx_line_id');
    
    
    
    
    
      log_p('BEGIN SQL5 : Extract for Receivables Distributions for each customer_trx_id');
    
      FOR i IN c_dist_cust_trx_id
      LOOP
      
        FOR j IN c_recv_distbn(i.legacy_customer_trx_id)
        LOOP
        
          INSERT INTO xxobjt.xxs3_rtr_open_trx_distribution
            (xx_open_trx_dist_id
            ,date_of_extract
            ,process_flag
            ,legacy_invoice_source
            ,order_number
            ,interface_line_context
            ,legacy_customer_trx_id
            ,legacy_customer_trx_line_id
            ,line_description
            ,trx_number
            ,line_number
            ,amount
            ,account_class
            ,s3_ledger_id
            ,legacy_code_combination
            ,legacy_company
            ,legacy_department
            ,legacy_account
            ,legacy_product
            ,legacy_location
            ,legacy_intercompany
            ,legacy_division
            ,legacy_org_id
            ,s3_org_id
            ,s3_company
            ,s3_business_unit
            ,s3_department
            ,s3_account
            ,s3_product
            ,s3_location
            ,s3_intercompany
            ,s3_future)
          VALUES
            (xxobjt.xxs3_rtr_open_trx_distbn_seq.NEXTVAL
            ,SYSDATE
            ,'N'
            ,j.legacy_invoice_source
            ,j.order_number
            ,j.interface_line_context
            ,j.legacy_customer_trx_id
            ,j.legacy_customer_trx_line_id
            ,j.line_description
            ,j.trx_number
            ,j.line_number
            ,j.amount
            ,j.account_class
            ,j.s3_ledger_id
            ,j.legacy_code_combination
            ,j.legacy_company
            ,j.legacy_department
            ,j.legacy_account
            ,j.legacy_product
            ,j.legacy_location
            ,j.legacy_intercompany
            ,j.legacy_division
            ,j.legacy_org_id
            ,j.s3_org_id
            ,j.s3_company
            ,j.s3_business_unit
            ,j.s3_department
            ,j.s3_account
            ,j.s3_product
            ,j.s3_location
            ,j.s3_intercompany
            ,j.s3_future);
        
        END LOOP;
      
      END LOOP;
      COMMIT;
      log_p('END SQL5 : Extract for Receivables Distributions for each customer_trx_id ');
    
    
    
    
      log_p('BEGIN SQL6 : Extract for Tax and App Distributions ');
    
      FOR i IN c_dist_cust_trx_id
      LOOP
      
        FOR j IN c_tax_app_distbn(i.legacy_customer_trx_id)
        LOOP
        
          INSERT INTO xxobjt.xxs3_rtr_open_trx_distribution
            (xx_open_trx_dist_id
            ,date_of_extract
            ,process_flag
            ,legacy_invoice_source
            ,order_number
            ,interface_line_context
            ,legacy_customer_trx_id
            ,legacy_customer_trx_line_id
            ,line_description
            ,trx_number
            ,line_number
            ,amount
            ,account_class
            ,s3_ledger_id
            ,legacy_code_combination
            ,legacy_company
            ,legacy_department
            ,legacy_account
            ,legacy_product
            ,legacy_location
            ,legacy_intercompany
            ,legacy_division
            ,legacy_org_id
            ,s3_org_id
            ,s3_company
            ,s3_business_unit
            ,s3_department
            ,s3_account
            ,s3_product
            ,s3_location
            ,s3_intercompany
            ,s3_future)
          VALUES
            (xxobjt.xxs3_rtr_open_trx_distbn_seq.NEXTVAL
            ,SYSDATE
            ,'N'
            ,j.legacy_invoice_source
            ,j.order_number
            ,j.interface_line_context
            ,j.legacy_customer_trx_id
            ,j.legacy_customer_trx_line_id
            ,j.line_description
            ,j.trx_number
            ,j.line_number
            ,j.amount
            ,j.account_class
            ,j.s3_ledger_id
            ,j.legacy_code_combination
            ,j.legacy_company
            ,j.legacy_department
            ,j.legacy_account
            ,j.legacy_product
            ,j.legacy_location
            ,j.legacy_intercompany
            ,j.legacy_division
            ,j.legacy_org_id
            ,j.s3_org_id
            ,j.s3_company
            ,j.s3_business_unit
            ,j.s3_department
            ,j.s3_account
            ,j.s3_product
            ,j.s3_location
            ,j.s3_intercompany
            ,j.s3_future);
        
        END LOOP;
      
      END LOOP;
      COMMIT;
      log_p('END SQL6 : Extract for Tax and App Distributions ');
    
    
    
    
    
      log_p('BEGIN : Update line numbers for Tax and Conv app in Distribution Stage');
    
      FOR i IN (SELECT *
                FROM xxobjt.xxs3_rtr_open_trx_distribution
                WHERE line_description = 'Original Tax Amount')
      LOOP
      
        IF i.line_number IS NULL
        THEN
          UPDATE xxobjt.xxs3_rtr_open_trx_distribution
          SET line_number = (nvl((SELECT MAX(line_number)
                                 FROM xxs3_rtr_open_trx_distribution
                                 WHERE legacy_customer_trx_id =
                                       i.legacy_customer_trx_id), 0) + 1)
          WHERE legacy_customer_trx_id = i.legacy_customer_trx_id
          AND line_description = 'Original Tax Amount';
        
        END IF;
      
      END LOOP;
    
      FOR i IN (SELECT *
                FROM xxobjt.xxs3_rtr_open_trx_distribution
                WHERE line_description = 'Conv Application')
      LOOP
      
        IF i.line_number IS NULL
        THEN
          UPDATE xxobjt.xxs3_rtr_open_trx_distribution
          SET line_number = (nvl((SELECT MAX(line_number)
                                 FROM xxs3_rtr_open_trx_distribution
                                 WHERE legacy_customer_trx_id =
                                       i.legacy_customer_trx_id), 0) + 1)
          WHERE legacy_customer_trx_id = i.legacy_customer_trx_id
          AND line_description = 'Conv Application';
        
        END IF;
      
      END LOOP;
    
      FOR i IN (SELECT *
                FROM xxobjt.xxs3_rtr_open_trx_distribution
                WHERE line_description LIKE 'Receivables%')
      LOOP
      
        IF i.line_number IS NULL
        THEN
          UPDATE xxobjt.xxs3_rtr_open_trx_distribution
          SET line_number = (nvl((SELECT MAX(line_number)
                                 FROM xxs3_rtr_open_trx_distribution
                                 WHERE legacy_customer_trx_id =
                                       i.legacy_customer_trx_id), 0) + 1)
          WHERE legacy_customer_trx_id = i.legacy_customer_trx_id
          AND line_description LIKE 'Receivables%';
        
        END IF;
      
      END LOOP;
      log_p('END : Update line numbers for Tax and conv app in Distribution Stage');
    
      log_p('End Of Extraction : Time Taken : ' ||
            (dbms_utility.get_time - l_start));
    
    
      l_start := dbms_utility.get_time;
    
      log_p('Cleansing multi code combination for distribition');
      cleanse_multi_code_combination(l_err_code, l_error_message);
    
      log_p('End Of cleanse_multi_code_combination : Time Taken : ' ||
            (dbms_utility.get_time - l_start));
    
      l_start := dbms_utility.get_time;
    
      log_p('Cleansing open trx code combination for distribition');
      cleanse_open_trx_code_comb(l_err_code, l_error_message);
    
      log_p('End Of cleanse_open_trx_code_comb : Time Taken : ' ||
            (dbms_utility.get_time - l_start));
    
      l_start := dbms_utility.get_time;
    
      log_p('BEGIN  Quality check');
      quality_check_open_trx(l_err_code, l_error_message);
    
      log_p('End Of quality_check_open_trx : Time Taken : ' ||
            (dbms_utility.get_time - l_start));
    
    
    
    
      ------------------- Transformation--------------------
    
      l_start := dbms_utility.get_time;
    
      log_p('BEGIN Transformation');
    
      FOR k IN (SELECT *
                FROM xxobjt.xxs3_rtr_open_trx_distribution
                WHERE account_class = 'REC')
      LOOP
        IF k.legacy_company IS NOT NULL
        THEN
          xxs3_data_transform_util_pkg.coa_transform(p_field_name => 'REC_ACCOUNT', p_legacy_company_val => k.legacy_company, --Legacy Company Value
                                                     p_legacy_department_val => k.legacy_department, --Legacy Department Value
                                                     p_legacy_account_val => k.legacy_account, --Legacy Account Value
                                                     p_legacy_product_val => k.legacy_product, --Legacy Product Value
                                                     p_legacy_location_val => k.legacy_location, --Legacy Location Value
                                                     p_legacy_intercompany_val => k.legacy_intercompany, --Legacy Intercompany Value
                                                     p_legacy_division_val => k.legacy_division, --Legacy Division Value
                                                     p_item_number => NULL, p_s3_gl_string => l_s3_gl_string, p_err_code => l_output_code, p_err_msg => l_output); --Output Message 
        
          xxs3_data_transform_util_pkg.coa_update(p_gl_string => l_s3_gl_string, p_stage_tab => 'xxobjt.XXS3_RTR_OPEN_TRX_DISTRIBUTION', p_stage_primary_col => 'XX_OPEN_TRX_DIST_ID', p_stage_primary_col_val => k.xx_open_trx_dist_id, p_stage_company_col => 'S3_COMPANY', p_stage_business_unit_col => 'S3_BUSINESS_UNIT', p_stage_department_col => 'S3_DEPARTMENT', p_stage_account_col => 'S3_ACCOUNT', p_stage_product_line_col => 'S3_PRODUCT', p_stage_location_col => 'S3_LOCATION', p_stage_intercompany_col => 'S3_INTERCOMPANY', p_stage_future_col => 'S3_FUTURE', p_coa_err_msg => l_output, p_err_code => l_output_code_coa_update, p_err_msg => l_output_coa_update);
        END IF;
      END LOOP;
      -------------------------------------------------------------------------------------------------- 
    
      -- Commented on 22-Sep-2016 as instructed by Deb frost
    
      /* FOR l IN (SELECT * FROM xxobjt.XXS3_RTR_OPEN_TRX_LINES) LOOP
        IF l.legacy_payment_terms IS NOT NULL THEN
        
          xxs3_data_transform_util_pkg.transform(p_mapping_type          => 'payment_terms',
                                                 p_stage_tab             => 'XXOBJT.XXS3_RTR_OPEN_TRX_LINES', --Staging Table Name
                                                 p_stage_primary_col     => 'XX_OPEN_TRX_ID', --Staging Table Primary Column Name
                                                 p_stage_primary_col_val => l.xx_open_trx_id, --Staging Table Primary Column Value
                                                 p_legacy_val            => l.legacy_payment_terms, --Legacy Value
                                                 p_stage_col             => 'S3_PAYMENT_TERMS', --Staging Table Name
                                                 p_err_code              => l_err_code, -- Output error code
                                                 p_err_msg               => l_error_message);
        
        END IF;
      
      END LOOP; */
    
      -- Commented on 22-Sep-2016 as instructed by Deb frost
    
      ---------------------------------------------------------------------------------------------------
      FOR m IN (SELECT * FROM xxobjt.xxs3_rtr_open_trx_lines)
      LOOP
        IF m.legacy_invoice_source IS NOT NULL
        THEN
        
          xxs3_data_transform_util_pkg.transform(p_mapping_type => 'rtr_interface_line_attribute1', p_stage_tab => 'XXOBJT.XXS3_RTR_OPEN_TRX_LINES', --Staging Table Name
                                                 p_stage_primary_col => 'XX_OPEN_TRX_ID', --Staging Table Primary Column Name
                                                 p_stage_primary_col_val => m.xx_open_trx_id, --Staging Table Primary Column Value
                                                 p_legacy_val => m.legacy_invoice_source, --Legacy Value
                                                 p_stage_col => 'INTERFACE_LINE_ATTRIBUTE1', --Staging Table Name
                                                 p_err_code => l_err_code, -- Output error code
                                                 p_err_msg => l_error_message);
        
        END IF;
      
      END LOOP;
      log_p('END Transformation');
    
      FOR m IN (SELECT * FROM xxobjt.xxs3_rtr_open_trx_distribution)
      LOOP
        IF m.legacy_invoice_source IS NOT NULL
        THEN
        
          xxs3_data_transform_util_pkg.transform(p_mapping_type => 'rtr_interface_line_attribute1', p_stage_tab => 'XXOBJT.XXS3_RTR_OPEN_TRX_DISTRIBUTION', --Staging Table Name
                                                 p_stage_primary_col => 'XX_OPEN_TRX_DIST_ID', --Staging Table Primary Column Name
                                                 p_stage_primary_col_val => m.xx_open_trx_dist_id, --Staging Table Primary Column Value
                                                 p_legacy_val => m.legacy_invoice_source, --Legacy Value
                                                 p_stage_col => 'INTERFACE_LINE_ATTRIBUTE1', --Staging Table Name
                                                 p_err_code => l_err_code, -- Output error code
                                                 p_err_msg => l_error_message);
        
        END IF;
      
      END LOOP;
      log_p('END Transformation');
    
    
      log_p('End Of Transformation : Time Taken : ' ||
            (dbms_utility.get_time - l_start));
    
      log_p('BEGIN Cleanse INTERFACE LINE ATTRIBUTE for lines and Distributions');
    
    
      l_start := dbms_utility.get_time;
    
      cleanse_intf_line_attr_lines(l_err_code, l_error_message);
    
      log_p('End Of cleanse_intf_line_attr_lines : Time Taken : ' ||
            (dbms_utility.get_time - l_start));
    
      l_start := dbms_utility.get_time;
    
      cleanse_intf_line_attr_dist(l_err_code, l_error_message);
    
      log_p('End Of cleanse_intf_line_attr_dist : Time Taken : ' ||
            (dbms_utility.get_time - l_start));
    
      log_p('Complete');
    
    EXCEPTION
      WHEN OTHERS THEN
        l_error_message := (SQLERRM || 'backtrace: ' ||
                           dbms_utility.format_error_backtrace);
        log_p(l_error_message);
    END;
  
  EXCEPTION
    WHEN OTHERS THEN
      l_error_message := (SQLERRM || 'backtrace: ' ||
                         dbms_utility.format_error_backtrace);
    
      log_p(l_error_message);
    
      dbms_output.put_line(l_error_message);
    
  END open_trx_extract;


  PROCEDURE ar_installments_extract(x_errbuf  OUT VARCHAR2
                                   ,x_retcode OUT NUMBER) AS
  
    l_err_code      NUMBER;
    l_error_message VARCHAR2(2000);
  
  
  
  
    CURSOR c_ar_install IS
      SELECT ps.org_id -- to be assigned by cleansing rules
            ,ps_summ.customer_trx_id
            ,arh.trx_number
            ,ps.terms_sequence_number
            ,ps_summ.CLASS
            ,ps_summ.invoice_currency_code
            ,ps.amount_due_remaining AS amount_due_original
             -- this is not a typo. the amount due remaining is to be loaded as the original amount
            ,ps.amount_due_remaining AS amount_due_remaining
            ,ps.payment_schedule_id  AS legacy_payment_schedule_id
             -- reference only
            ,ps_summ.amount_due_remaining AS legacy_inv_amount_due
             -- reference only
            ,ps.due_date -- refernece only
      FROM xxar_payment_schedule_summary ps_summ
           -- at least one entry in the payment schedule is open
          ,ar_payment_schedules_all ps
          ,ra_customer_trx_all      arh
      WHERE ps_summ.customer_trx_id = arh.customer_trx_id
      AND ps_summ.number_of_due_dates <> 1 -- the need to reallocate the schedule only applies to partially paid installment invoices 
      AND ps_summ.amount_due_original <> ps_summ.amount_due_remaining -- the need to reallocate the schedule only applies to partially paid installment invoices
      AND ps_summ.customer_trx_id = ps.customer_trx_id
      AND ps.CLASS IN ('INV', 'CM')
      ORDER BY trx_number
              ,terms_sequence_number;
  
  BEGIN
  
    log_p('Truncating Tables...');
    EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.xxs3_rtr_ar_installments';
  
  
    log_p('Extracting for Installments...');
  
    FOR i IN c_ar_install
    LOOP
    
      BEGIN
        INSERT INTO xxobjt.xxs3_rtr_ar_installments
          (xx_ar_install_id
          ,date_extracted_on
          ,process_flag
          ,legacy_org_id
          ,org_id
          ,customer_trx_id
          ,trx_number
          ,terms_sequence_number
          ,CLASS
          ,invoice_currency_code
          ,amount_due_original
          ,amount_due_remaining
          ,legacy_payment_schedule_id
          ,legacy_inv_amount_due
          ,due_date)
        
        VALUES
          (xxobjt.xxs3_rtr_ar_install_seq.NEXTVAL
          ,SYSDATE
          ,'N'
          ,i.org_id
          ,NULL
          ,i.customer_trx_id
          ,i.trx_number
          ,i.terms_sequence_number
          ,i.CLASS
          ,i.invoice_currency_code
          ,i.amount_due_original
          ,i.amount_due_remaining
          ,i.legacy_payment_schedule_id
          ,i.legacy_inv_amount_due
          ,i.due_date);
      
      
      EXCEPTION
        WHEN OTHERS THEN
          l_error_message := 'Error in Inserting into the installment table ' ||
                             SQLERRM;
          log_p(l_error_message);
        
      
      END;
    END LOOP;
  
    log_p('End of Extraction...');
  
  
  END ar_installments_extract;


END xxs3_rtr_ar_open_trx_pkg;
/
