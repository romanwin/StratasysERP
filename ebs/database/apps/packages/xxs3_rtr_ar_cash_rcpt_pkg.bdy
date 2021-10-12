CREATE OR REPLACE PACKAGE xxs3_rtr_ar_cash_rcpt_pkg

-- --------------------------------------------------------------------------------------------
-- Purpose: This Package is used for Item Cost Extract, Quality Check and Report
--
-- --------------------------------------------------------------------------------------------
-- Ver  Date        Name                          Description
-- 1.0  29/07/2016  TCS                           Initial build
-- --------------------------------------------------------------------------------------------

 AS

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used for Item Cost Extract
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  29/07/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE ar_cash_rcpt_extract_data(x_retcode    OUT NUMBER,
                                      x_errbuf     OUT VARCHAR2,
                                      x_s3_gl_date IN OUT VARCHAR2);

  PROCEDURE cash_rcpt_report_data(p_entity_name IN VARCHAR2);

  PROCEDURE data_transform_report(p_entity VARCHAR2);

END xxs3_rtr_ar_cash_rcpt_pkg;
/
CREATE OR REPLACE PACKAGE BODY xxs3_rtr_ar_cash_rcpt_pkg AS

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure is used to write in concurrent log
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  19/08/2016  TCS                           Initial build
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
  -- 1.0  19/08/2016  TCS                           Initial build
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
  -- Purpose: This Procedure is used for Item cost Data Quality Report
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  19/08/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE cash_rcpt_report_data(p_entity_name IN VARCHAR2) AS
  
    CURSOR c_report IS
      SELECT xicd.*
        FROM xxs3_rtr_ar_cash_rcpt xic, xxs3_rtr_ar_cash_rcpt_dq xicd
       WHERE xic.xx_cash_rcpt_id = xicd.xx_cash_rcpt_id
         AND xic.process_flag IN ('Q', 'R')
       ORDER BY 1;
    p_delimiter VARCHAR2(5) := '~';
  BEGIN
    out_p(rpad('Item Cost DQ status report', 100, ' '));
    out_p(rpad('=============================', 100, ' '));
    out_p('');
    out_p('Date:    ' || to_char(SYSDATE, 'dd-Mon-YYYY HH24:MI'));
  
    out_p('');
  
    out_p(rpad('Track Name', 15, ' ') || p_delimiter ||
          rpad('Entity Name', 20, ' ') || p_delimiter ||
          rpad('XX CASH RCPT ID  ', 20, ' ') || p_delimiter ||
          rpad('Rule Name', 50, ' ') || p_delimiter ||
          rpad('Reason Code', 50, ' '));
  
    FOR i IN c_report LOOP
      out_p(rpad('RTR', 15, ' ') || p_delimiter ||
            rpad('OPEN CASH RECEIPT', 20, ' ') || p_delimiter ||
            rpad(i.xx_cash_rcpt_id, 20, ' ') || p_delimiter ||
            rpad(i.rule_name, 50, ' ') || p_delimiter ||
            rpad(i.notes, 50, ' '));
    END LOOP;
  
    --  p_err_code := '0';
    --  p_err_msg  := '';
  EXCEPTION
    WHEN OTHERS THEN
      --  p_err_code := '2';
      --  p_err_msg  := 'SQLERRM: ' || SQLERRM;
      log_p('Failed to generate report: ' || SQLERRM);
  END cash_rcpt_report_data;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure is used for Approved Suppliers Transform Report
  --           
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  19/08/2016  TCS                           Initial build  
  -- --------------------------------------------------------------------------------------------

  PROCEDURE data_transform_report(p_entity VARCHAR2) IS
    CURSOR c_report_item_cost IS
      SELECT *
        FROM xxs3_rtr_ar_cash_rcpt xic
       WHERE xic.transform_status IN ('PASS', 'FAIL');
    p_delimiter     VARCHAR2(5) := '~';
    l_err_msg       VARCHAR2(2000);
    l_count_success NUMBER;
    l_count_fail    NUMBER;
  BEGIN
  
    SELECT COUNT(1)
      INTO l_count_success
      FROM xxs3_rtr_ar_cash_rcpt xic
     WHERE xic.transform_status = 'PASS';
  
    SELECT COUNT(1)
      INTO l_count_fail
      FROM xxs3_rtr_ar_cash_rcpt xic
     WHERE xic.transform_status = 'FAIL';
  
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
          rpad('XX CASH RCPT ID  ', 14, ' ') || p_delimiter ||
          rpad('GL Date', 240, ' ') || p_delimiter ||
          rpad('S3 GL Date', 30, ' ') || p_delimiter ||
          rpad('Status', 10, ' ') || p_delimiter ||
          rpad('Error Message', 200, ' '));
  
    FOR r_data IN c_report_item_cost LOOP
      out_p(rpad('RTR', 10, ' ') || p_delimiter ||
            rpad('CASH RECEIPT', 11, ' ') || p_delimiter ||
            rpad(r_data.xx_cash_rcpt_id, 14, ' ') || p_delimiter ||
            rpad(r_data.GL_DATE, 240, ' ') || p_delimiter ||
            rpad(r_data.S3_GL_DATE, 30, ' ') || p_delimiter ||
            rpad(r_data.transform_status, 10, ' ') || p_delimiter ||
            rpad(nvl(r_data.transform_error, 'NULL'), 200, ' '));
    END LOOP;
  
    fnd_file.put_line(fnd_file.output, '');
    fnd_file.put_line(fnd_file.output,
                      'Stratasys Confidential' || p_delimiter);
  END;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used for Item Cost Extract
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  19/08/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE ar_cash_rcpt_extract_data(x_retcode    OUT NUMBER,
                                      x_errbuf     OUT VARCHAR2,
                                      x_s3_gl_date IN OUT VARCHAR2) AS
    l_err_code            NUMBER;
    l_err_msg             VARCHAR2(100);
    l_error_message       VARCHAR2(2000); -- mock
    l_get_org             VARCHAR2(50);
    l_get_concat_segments VARCHAR2(50);
    l_get_sub_inv_name    VARCHAR2(50);
    l_get_row             VARCHAR2(50);
    l_get_rack            VARCHAR2(50);
    l_get_bin             VARCHAR2(50);
    l_date_param          DATE;
  
    CURSOR cur_cash_rcpt IS
      select 'Stratasys US OU' Operating_unit,
             ac.cash_receipt_id as legacy_cash_receipt_id,
             PAYMENT_METHOD_DSP as legacy_receipt_method,
             case
               when ac.currency_code = 'USD' then
                'CONV USD'
               when ac.currency_code = 'EUR' then
                'CONV EUR'
               else
                NULL
             end as s3_receipt_method,
             receipt_number,
             ac.currency_code as receipt_currency,
             case
               when ac.currency_code = 'USD' then
                null
               else
                'User'
             end as exchange_rate_type,
             ps.exchange_date,
             ps.exchange_rate,
             ROUND(ps.exchange_rate, 4) s3_exchange_rate,
             amount_due_remaining * -1 as receipt_amount,
             type as receipt_type,
             receipt_date,
             ac.gl_date, -- set to Last day of the Period in in S3 for which the Data Conversion will occur.
             '31-JUL-2016' as s3_gl_date,
             maturity_date,
             customer_number,
             location,
             comments as receipt_comments,
             CUSTOMER_RECEIPT_REFERENCE,
             postmark_date,
             case
               when on_acc.status = 'ACC' then
                'On-Account'
               else
                null
             end as activity,
             on_acc.amount_applied,
             on_acc.apply_date,
             --    null as applied_gl_date, -- set to Last day of the Period in in S3 for which the Data Conversion will occur.
             decode(on_acc.status, 'ACC', '31-JUL-2016', null) as S3_Apply_GL_Date,
             receipt_status,
             ON_ACC.status as on_account,
             ac.amount as receipt_amount_original,
             amount_due_original,
             ac.customer_site_use_id as legacy_customer_site_use_id
        from ar_payment_schedules_all ps,
             ar_cash_receipts_v ac, -- initialize environment variables to use an AR responsibility
             (select cash_receipt_id,
                     arr.status,
                     sum(arr.amount_applied) as amount_applied,
                     max(apply_date) as apply_date
                from ar_receivable_applications_all arr
               where status = 'ACC'
               group by cash_receipt_id, arr.status
              having sum(arr.amount_applied) <> 0) ON_ACC
       where class = 'PMT'
         AND ps.org_id = 737
         AND ps.status = 'OP'
         and ps.cash_receipt_id = ac.cash_receipt_id
         and ac.cash_receipt_id = ON_ACC.cash_receipt_id(+)
         and type = 'CASH'
       order by ac.receipt_date desc, ac.receipt_number;
  
    CURSOR cur_transform IS
      SELECT * FROM xxs3_rtr_ar_cash_rcpt WHERE process_flag IN ('Y', 'Q');
  
  BEGIN
  
    fnd_file.put_line(fnd_file.log, 'STARTING');
  
    fnd_file.put_line(fnd_file.log, to_char(x_s3_gl_date));
  
    l_date_param := to_date(x_s3_gl_date, 'YYYY/MM/DD HH24:MI:SS');
  
    fnd_file.put_line(fnd_file.log, l_date_param);
  
    fnd_file.put_line(fnd_file.log, 'STARTING 11');
    --------------------------------- Remove existing data in staging --------------------------------
  
    DELETE FROM xxobjt.xxs3_rtr_ar_cash_rcpt;
  
    -------------------------------- Insert Legacy Data in Staging-----------------------------------
  
    FOR i IN cur_cash_rcpt LOOP
    
      insert into xxobjt.xxs3_rtr_ar_cash_rcpt
        (xx_cash_rcpt_id,
         date_of_extract,
         process_flag,
         Operating_unit,
         legacy_cash_rcpt_id,
         receipt_method,
         s3_receipt_method,
         receipt_number,
         receipt_currency,
         exchange_rate_type,
         exchange_rate_date,
         exchange_rate,
         -- s3_exchange_rate,
         receipt_amount,
         receipt_type,
         receipt_date,
         gl_date, -- legacy
         s3_gl_date, -- 31st JUL 2016
         maturity_date,
         customer_number,
         location,
         receipt_comments,
         CUSTOMER_RECEIPT_REFERENCE,
         postmark_date,
         activity,
         amount_applied,
         apply_date,
         s3_Apply_GL_Date,
         receipt_status,
         on_account_status,
         receipt_amount_original,
         amount_due_original,
         legacy_customer_site_use_id)
      values
        (xxobjt.xxs3_rtr_ar_cash_rcpt_seq.nextval,
         sysdate,
         'N',
         i.Operating_Unit,
         i.legacy_cash_receipt_id,
         i.legacy_receipt_method,
         i.s3_receipt_method,
         i.receipt_number,
         i.receipt_currency,
         i.exchange_rate_type,
         i.exchange_date,
         i.exchange_rate,
         --  i.s3_exchange_rate,
         i.receipt_amount,
         i.receipt_type,
         i.receipt_date,
         i.gl_date,
         i.s3_gl_date,
         i.maturity_date,
         i.customer_number,
         i.location,
         i.receipt_comments,
         i.CUSTOMER_RECEIPT_REFERENCE,
         i.postmark_date,
         i.activity,
         i.amount_applied,
         i.apply_date, --- legacy
         i.S3_Apply_GL_Date, ---31st Jul2016
         i.receipt_status,
         i.on_account,
         i.receipt_amount_original,
         i.amount_due_original,
         i.legacy_customer_site_use_id);
    
    END LOOP;
  
    -------------------------------- Transform Data------------------------------
  
    FOR j IN cur_transform LOOP
    
      IF l_date_param IS NOT NULL THEN
      
        BEGIN
          update xxobjt.xxs3_rtr_ar_cash_rcpt
             set S3_GL_Date       = l_date_param,
                 S3_Apply_GL_Date = l_date_param,
                 transform_status = 'PASS'
           where xx_cash_rcpt_id = j.xx_cash_rcpt_id;
        
        EXCEPTION
        
          WHEN OTHERS THEN
            l_error_message := SQLERRM;
          
            update xxobjt.xxs3_rtr_ar_cash_rcpt
               set transform_status = 'FAIL',
                   transform_error  = transform_error || ',' ||
                                      l_error_message
             where xx_cash_rcpt_id = j.xx_cash_rcpt_id;
          
        END;
      
      ELSE
      
        l_error_message := 'Date parameter not found';
      
        update xxobjt.xxs3_rtr_ar_cash_rcpt
           set transform_status = 'FAIL',
               transform_error  = transform_error || ',' || l_error_message
         where xx_cash_rcpt_id = j.xx_cash_rcpt_id;
      
      END IF;
    
    END LOOP;
  
    -------------------------------- Report Data ----------------------------------------   
    cash_rcpt_report_data('AR CASH RECEIPT');
  
  END ar_cash_rcpt_extract_data;
END xxs3_rtr_ar_cash_rcpt_pkg;
/
