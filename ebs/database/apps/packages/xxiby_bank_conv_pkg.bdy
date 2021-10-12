CREATE OR REPLACE PACKAGE BODY xxiby_bank_conv_pkg IS
  --------------------------------------------------------------------
  --  name:            XXIBY_BANK_CONV_PKG
  --  create by:       Michal Tzvik
  --  Revision:        1.0
  --  creation date:   03/08/2015
  --------------------------------------------------------------------
  --  purpose :        CHG0035411 – Global Banking Change to JP Morgan Chase Phase III
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  03/08/2015  Michal Tzvik    initial build
  -------------------------------------------------------------------- 

  --------------------------------------------------------------------
  --  name:            XXIBY_BANK_CONV_PKG
  --  create by:       Michal Tzvik
  --  Revision:        1.0
  --  creation date:   03/08/2015
  --------------------------------------------------------------------
  --  purpose :        CHG0035411 : bank conversion interface package
  --------------------------------------------------------------------
  --  ver  date         name             desc
  --  1.0  03/08/2015   Michal Tzvik     CHG0035411 - initial build
  --------------------------------------------------------------------

  c_sts_new        CONSTANT VARCHAR2(15) := 'NEW';
  c_sts_in_process CONSTANT VARCHAR2(15) := 'IN_PROCESS';
  c_sts_valid      CONSTANT VARCHAR2(15) := 'VALID';
  c_sts_success    CONSTANT VARCHAR2(15) := 'SUCCESS';
  c_sts_error      CONSTANT VARCHAR2(15) := 'ERROR';

  c_action_create CONSTANT VARCHAR2(25) := 'CREATE';
  c_action_update CONSTANT VARCHAR2(25) := 'UPDATE';

  c_module CONSTANT VARCHAR2(25) := 'CE';
  g_simulation_mode VARCHAR2(1); -- indicates run mode 

  g_batch_id NUMBER;

  -- Bank Cursor
  CURSOR c_bank IS
    SELECT DISTINCT --xbci.xx_status,
                    xx_bank_act_status,
                    xbci.xx_err_msg,
                    xbci.xx_bank_action,
                    xbci.country,
                    xbci.bank_number,
                    xbci.bank_name,
                    xbci.institution_type,
                    xbci.bank_alt_name,
                    xbci.bank_description,
                    xbci.tax_payer_id,
                    xbci.tax_registration_number,
                    xbci.bank_attribute_category,
                    xbci.bank_attribute1,
                    xbci.bank_attribute2,
                    xbci.bank_attribute3,
                    xbci.bank_attribute4,
                    xbci.bank_attribute5,
                    xbci.bank_attribute6,
                    xbci.bank_attribute7,
                    xbci.bank_attribute8,
                    xbci.bank_attribute9,
                    xbci.bank_attribute10,
                    xbci.bank_attribute11,
                    xbci.bank_attribute12,
                    xbci.bank_attribute13,
                    xbci.bank_attribute14,
                    xbci.bank_attribute15,
                    xbci.bank_attribute16,
                    xbci.bank_attribute17,
                    xbci.bank_attribute18,
                    xbci.bank_attribute19,
                    xbci.bank_attribute20,
                    xbci.bank_attribute21,
                    xbci.bank_attribute22,
                    xbci.bank_attribute23,
                    xbci.bank_attribute24,
                    xbci.bank_party_id,
                    xbci.location_id
    FROM   xxiby_bank_conv_interface xbci
    WHERE  1 = 1
    AND    xbci.xx_bank_action IS NOT NULL
    AND    xbci.xx_status != c_sts_error
    AND    xbci.xx_batch_id = g_batch_id;

  -- Branch Cursor
  CURSOR c_branch /*(p_status VARCHAR2)*/
  IS
    SELECT DISTINCT xbci.xx_branch_act_status,
                    xbci.xx_err_msg,
                    xbci.xx_branch_action,
                    xbci.country,
                    xbci.bank_number,
                    xbci.bank_name,
                    xbci.branch_name,
                    xbci.branch_number,
                    xbci.branch_type,
                    xbci.alternate_branch_name,
                    xbci.branch_description,
                    xbci.bic,
                    xbci.eft_number,
                    xbci.rfc_identifier,
                    xbci.branch_attribute_category,
                    xbci.branch_attribute1,
                    xbci.branch_attribute2,
                    xbci.branch_attribute3,
                    xbci.branch_attribute4,
                    xbci.branch_attribute5,
                    xbci.branch_attribute6,
                    xbci.branch_attribute7,
                    xbci.branch_attribute8,
                    xbci.branch_attribute9,
                    xbci.branch_attribute10,
                    xbci.branch_attribute11,
                    xbci.branch_attribute12,
                    xbci.branch_attribute13,
                    xbci.branch_attribute14,
                    xbci.branch_attribute15,
                    xbci.branch_attribute16,
                    xbci.branch_attribute17,
                    xbci.branch_attribute18,
                    xbci.branch_attribute19,
                    xbci.branch_attribute20,
                    xbci.branch_attribute21,
                    xbci.branch_attribute22,
                    xbci.branch_attribute23,
                    xbci.branch_attribute24,
                    xbci.branch_country,
                    xbci.branch_address1,
                    xbci.branch_address2,
                    xbci.branch_address3,
                    xbci.branch_address4,
                    xbci.branch_city,
                    xbci.branch_postal_code,
                    xbci.branch_state,
                    xbci.branch_county,
                    xbci.branch_province,
                    xbci.bank_party_id,
                    xbci.branch_party_id,
                    xbci.bank_account_id,
                    xbci.location_id
    FROM   xxiby_bank_conv_interface xbci
    WHERE  1 = 1
    AND    xbci.xx_branch_action IS NOT NULL
    AND    xbci.xx_status != c_sts_error
    AND    xbci.xx_batch_id = g_batch_id
    --AND    xbci.branch_number IS NOT NULL
    ;

  -- Account Cursor
  CURSOR c_account IS
    SELECT *
    FROM   xxiby_bank_conv_interface xbci
    WHERE  1 = 1
    AND    xbci.xx_status != c_sts_error
    AND    xbci.xx_batch_id = g_batch_id
    AND    xbci.account_number IS NOT NULL;

  -- Payment Details Cursor
  CURSOR c_pmt_dtl(p_level VARCHAR2) IS
    SELECT 'VENDOR' data_level,
           xbci.xx_interface_id,
           xbci.xx_err_msg,
           xbci.xx_pmt_dtl_vendor_status,
           xbci.xx_pmt_dtl_site_status,
           xbci.vendor_number,
           xbci.vendor_site_code,
           xbci.vendor_default_payment_method default_payment_method,
           xbci.vendor_bank_instr1_code bank_instr1_code,
           xbci.vendor_bank_instr2_code bank_instr2_code,
           xbci.vendor_payment_reason_code payment_reason_code,
           xbci.vendor_remit_delivery_method delivery_method,
           xbci.vendor_remit_email_address email_address,
           xbci.vendor_party_id,
           xbci.vendor_party_site_id,
           xbci.org_id,
           xbci.vendor_id,
           xbci.vendor_site_id,
           NULL default_payment_method_code
    FROM   xxiby_bank_conv_interface xbci
    WHERE  1 = 1
    AND    xbci.xx_status != c_sts_error
    AND    xbci.xx_batch_id = g_batch_id
    AND    p_level = 'VENDOR'
    AND    (xbci.vendor_default_payment_method IS NOT NULL OR
          xbci.vendor_bank_instr1_code IS NOT NULL OR
          xbci.vendor_bank_instr2_code IS NOT NULL OR
          xbci.vendor_payment_reason_code IS NOT NULL OR
          xbci.vendor_remit_delivery_method IS NOT NULL OR
          xbci.vendor_remit_email_address IS NOT NULL)
    UNION ALL
    SELECT 'SITE' data_level,
           xbci.xx_interface_id,
           xbci.xx_err_msg,
           xbci.xx_pmt_dtl_vendor_status,
           xbci.xx_pmt_dtl_site_status,
           xbci.vendor_number,
           xbci.vendor_site_code,
           xbci.site_default_payment_method default_payment_method,
           xbci.site_bank_instr1_code bank_instr1_code,
           xbci.site_bank_instr2_code bank_instr2_code,
           xbci.site_payment_reason_code payment_reason_code,
           xbci.site_remit_delivery_method delivery_method,
           xbci.site_remit_email_address email_address,
           xbci.vendor_party_id,
           xbci.vendor_party_site_id,
           xbci.org_id,
           xbci.vendor_id,
           xbci.vendor_site_id,
           NULL default_payment_method_code
    FROM   xxiby_bank_conv_interface xbci
    WHERE  1 = 1
    AND    xbci.xx_status != c_sts_error
    AND    xbci.xx_batch_id = g_batch_id
    AND    p_level = 'SITE'
    AND    (xbci.site_default_payment_method IS NOT NULL OR
          xbci.site_bank_instr1_code IS NOT NULL OR
          xbci.site_bank_instr2_code IS NOT NULL OR
          xbci.site_payment_reason_code IS NOT NULL OR
          xbci.site_remit_delivery_method IS NOT NULL OR
          xbci.site_remit_email_address IS NOT NULL);

  --------------------------------------------------------------------
  --  name:              report_data
  --  create by:         Michal Tzvik
  --  Revision:          1.0
  --  creation date:     30/08/2015
  --------------------------------------------------------------------
  --  purpose :          write report to output
  --                     
  --------------------------------------------------------------------
  --  ver  date          name             desc
  --  1.0  30/08/2015    Michal Tzvik     CHG0035411 - initial build
  --------------------------------------------------------------------
  PROCEDURE report_data(x_err_code OUT NUMBER,
                        x_err_msg  OUT VARCHAR2) IS
    CURSOR c_data IS
      SELECT to_char(rownum) row_num,
             nvl(xbci.xx_bank_action, ' ') xx_bank_action,
             nvl(xbci.xx_branch_action, ' ') xx_branch_action,
             nvl(xbci.xx_account_action, ' ') xx_account_action,
             nvl(xbci.xx_acct_assignment_level, ' ') xx_acct_assignment_level,
             nvl(xbci.country, ' ') country,
             nvl(xbci.bank_name, ' ') bank_name,
             nvl(xbci.bank_number, ' ') bank_number,
             nvl(xbci.bank_alt_name, ' ') bank_alt_name,
             nvl(xbci.bank_description, ' ') bank_description,
             nvl(xbci.branch_name, ' ') branch_name,
             nvl(xbci.branch_number, ' ') branch_number,
             nvl(xbci.alternate_branch_name, ' ') alternate_branch_name,
             nvl(xbci.branch_description, ' ') branch_description,
             nvl(xbci.bic, ' ') bic,
             nvl(xbci.branch_type, ' ') branch_type,
             nvl(xbci.branch_address1, ' ') branch_address1,
             nvl(xbci.branch_address2, ' ') branch_address2,
             nvl(xbci.branch_city, ' ') branch_city,
             nvl(xbci.branch_province, ' ') branch_province,
             nvl(xbci.branch_postal_code, ' ') branch_postal_code,
             nvl(xbci.branch_country, ' ') branch_country,
             nvl(xbci.account_number, ' ') account_number,
             nvl(xbci.account_name, ' ') account_name,
             nvl(xbci.currency, ' ') currency,
             nvl(xbci.acct_type, ' ') acct_type,
             nvl(xbci.account_start_date, ' ') account_start_date,
             nvl(xbci.account_end_date, ' ') account_end_date,
             nvl(xbci.iban, ' ') iban,
             nvl(xbci.vendor_number, ' ') vendor_number,
             nvl(xbci.vendor_site_code, ' ') vendor_site_code,
             nvl(xbci.vendor_default_payment_method, ' ') vendor_default_payment_method,
             nvl(xbci.vendor_bank_instr1_code, ' ') vendor_bank_instr1_code,
             nvl(xbci.vendor_bank_instr2_code, ' ') vendor_bank_instr2_code,
             nvl(xbci.vendor_payment_reason_code, ' ') vendor_payment_reason_code,
             nvl(xbci.vendor_remit_delivery_method, ' ') vendor_remit_delivery_method,
             nvl(xbci.vendor_remit_email_address, ' ') vendor_remit_email_address,
             nvl(xbci.site_default_payment_method, ' ') site_default_payment_method,
             nvl(xbci.site_bank_instr1_code, ' ') site_bank_instr1_code,
             nvl(xbci.site_bank_instr2_code, ' ') site_bank_instr2_code,
             nvl(xbci.site_payment_reason_code, ' ') site_payment_reason_code,
             nvl(xbci.site_remit_delivery_method, ' ') site_remit_delivery_method,
             nvl(xbci.site_remit_email_address, ' ') site_remit_email_address,
             nvl(to_char(xbci.xx_batch_id), ' ') xx_batch_id,
             nvl(xbci.xx_bank_act_status, ' ') xx_bank_act_status,
             nvl(xbci.xx_branch_act_status, ' ') xx_branch_act_status,
             nvl(xbci.xx_account_act_status, ' ') xx_account_act_status,
             nvl(xbci.xx_acct_assignment_status, ' ') xx_acct_assignment_status,
             nvl(xbci.xx_pmt_dtl_vendor_status, ' ') xx_pmt_dtl_vendor_status,
             nvl(xbci.xx_pmt_dtl_site_status, ' ') xx_pmt_dtl_site_status,
             nvl(xbci.xx_status, ' ') xx_status,
             nvl(xbci.xx_err_msg, ' ') xx_err_msg
      FROM   xxiby_bank_conv_interface xbci
      WHERE  xbci.xx_batch_id = g_batch_id;
  
  BEGIN
  
    x_err_code := 0;
    x_err_msg  := '';
  
    fnd_file.put_line(fnd_file.output, rpad('Bank conversion status report', 100, ' '));
    fnd_file.put_line(fnd_file.output, rpad('=============================', 100, ' '));
    fnd_file.put_line(fnd_file.output, '');
    fnd_file.put_line(fnd_file.output, 'Batch id:' || g_batch_id);
    fnd_file.put_line(fnd_file.output, 'Date:    ' ||
                       to_char(SYSDATE, 'dd-Mon-YYYY HH24:MI'));
  
    fnd_file.put_line(fnd_file.output, '');
  
    fnd_file.put_line(fnd_file.output, ' #  ' || '|' ||
                       rpad('Final Status', 17, ' ') || '|' ||
                       rpad('Bank Action', 17, ' ') || '|' ||
                       rpad('Branch Action', 17, ' ') || '|' ||
                       rpad('Account Action', 17, ' ') || '|' ||
                       rpad('Acct Assignment Level', 21, ' ') || '|' ||
                       rpad('Bank Act Status', 17, ' ') || '|' ||
                       rpad('Branch Act Status', 17, ' ') || '|' ||
                       rpad('Account Act Status', 18, ' ') || '|' ||
                       rpad('Acct Assignment Status', 22, ' ') || '|' ||
                       rpad('Pmt Dtl Vendor Status', 22, ' ') || '|' ||
                       rpad('Pmt Dtl Site Status', 22, ' ') || '|' ||
                       rpad('Country', 17, ' ') || '|' ||
                       rpad('Bank Number', 17, ' ') || '|' ||
                       rpad('Bank Name', 17, ' ') || '|' ||
                       rpad('Bank Alt Name', 17, ' ') || '|' ||
                       rpad('Bank Description', 17, ' ') || '|' ||
                       rpad('Branch Name', 17, ' ') || '|' ||
                       rpad('Branch Number', 17, ' ') || '|' ||
                       rpad('alternate Branch Name', 17, ' ') || '|' ||
                       rpad('Branch Description', 17, ' ') || '|' ||
                       rpad('Bic', 17, ' ') || '|' ||
                       rpad('Branch type', 17, ' ') || '|' ||
                       rpad('Address1', 17, ' ') || '|' ||
                       rpad('Address2', 17, ' ') || '|' ||
                       rpad('City', 17, ' ') || '|' ||
                       rpad('Province', 17, ' ') || '|' ||
                       rpad('Postal Code', 17, ' ') || '|' ||
                       rpad('Country', 17, ' ') || '|' ||
                       rpad('Account Number', 17, ' ') || '|' ||
                       rpad('Account Name', 17, ' ') || '|' ||
                       rpad('Currency', 8, ' ') || '|' ||
                       rpad('Acct Type', 17, ' ') || '|' ||
                       rpad('Start Date', 13, ' ') || '|' ||
                       rpad('End Date', 13, ' ') || '|' ||
                       rpad('iban', 17, ' ') || '|' ||
                       rpad('Vendor Number', 17, ' ') || '|' ||
                       rpad('Vendor Site Code', 17, ' ') || '|' ||
                       rpad('Vendor default Payment Method', 17, ' ') || '|' ||
                       rpad('Vendor Bank Instr1 Code', 17, ' ') || '|' ||
                       rpad('Vendor Bank Instr2 Code', 17, ' ') || '|' ||
                       rpad('Vendor Payment Reason Code', 17, ' ') || '|' ||
                       rpad('Vendor Delivery Method', 23, ' ') || '|' ||
                       rpad('Vendor Remit Email', 25, ' ') || '|' ||
                       rpad('Site Default Payment Method', 17, ' ') || '|' ||
                       rpad('Site Bank Instr1 Code', 17, ' ') || '|' ||
                       rpad('Site Bank Instr2 Code', 17, ' ') || '|' ||
                       rpad('Site Payment Reason Code', 17, ' ') || '|' ||
                       rpad('Site Delivery Method', 23, ' ') || '|' ||
                       rpad('Site Remit Email', 25, ' ') || '|' ||
                       'Err Msg');
  
    fnd_file.put_line(fnd_file.output, '----' || '|' || rpad('-', 17, '-') || '|' ||
                       rpad('-', 17, '-') || '|' ||
                       rpad('-', 17, '-') || '|' ||
                       rpad('-', 17, '-') || '|' ||
                       rpad('-', 21, '-') || '|' ||
                       rpad('-', 17, '-') || '|' ||
                       rpad('-', 17, '-') || '|' ||
                       rpad('-', 18, '-') || '|' ||
                       rpad('-', 22, '-') || '|' ||
                       rpad('-', 22, '-') || '|' ||
                       rpad('-', 22, '-') || '|' ||
                       rpad('-', 17, '-') || '|' ||
                       rpad('-', 17, '-') || '|' ||
                       rpad('-', 17, '-') || '|' ||
                       rpad('-', 17, '-') || '|' ||
                       rpad('-', 17, '-') || '|' ||
                       rpad('-', 17, '-') || '|' ||
                       rpad('-', 17, '-') || '|' ||
                       rpad('-', 17, '-') || '|' ||
                       rpad('-', 17, '-') || '|' ||
                       rpad('-', 17, '-') || '|' ||
                       rpad('-', 17, '-') || '|' ||
                       rpad('-', 17, '-') || '|' ||
                       rpad('-', 17, '-') || '|' ||
                       rpad('-', 17, '-') || '|' ||
                       rpad('-', 17, '-') || '|' ||
                       rpad('-', 17, '-') || '|' ||
                       rpad('-', 17, '-') || '|' ||
                       rpad('-', 17, '-') || '|' ||
                       rpad('-', 17, '-') || '|' ||
                       rpad('-', 8, '-') || '|' ||
                       rpad('-', 17, '-') || '|' ||
                       rpad('-', 13, '-') || '|' ||
                       rpad('-', 13, '-') || '|' ||
                       rpad('-', 17, '-') || '|' ||
                       rpad('-', 17, '-') || '|' ||
                       rpad('-', 17, '-') || '|' ||
                       rpad('-', 17, '-') || '|' ||
                       rpad('-', 17, '-') || '|' ||
                       rpad('-', 17, '-') || '|' ||
                       rpad('-', 17, '-') || '|' ||
                       rpad('-', 23, '-') || '|' ||
                       rpad('-', 25, '-') || '|' ||
                       rpad('-', 17, '-') || '|' ||
                       rpad('-', 17, '-') || '|' ||
                       rpad('-', 17, '-') || '|' ||
                       rpad('-', 17, '-') || '|' ||
                       rpad('-', 23, '-') || '|' ||
                       rpad('-', 25, '-') || '|' ||
                       '-------------------------------------------');
  
    FOR r_data IN c_data LOOP
      fnd_file.put_line(fnd_file.output, rpad(r_data.row_num, 4, ' ') || '|' ||
                         rpad(r_data.xx_status, 17, ' ') || '|' ||
                         rpad(r_data.xx_bank_action, 17, ' ') || '|' ||
                         rpad(r_data.xx_branch_action, 17, ' ') || '|' ||
                         rpad(r_data.xx_account_action, 17, ' ') || '|' ||
                         rpad(r_data.xx_acct_assignment_level, 21, ' ') || '|' ||
                         rpad(r_data.xx_bank_act_status, 17, ' ') || '|' ||
                         rpad(r_data.xx_branch_act_status, 17, ' ') || '|' ||
                         rpad(r_data.xx_account_act_status, 18, ' ') || '|' ||
                         rpad(r_data.xx_acct_assignment_status, 22, ' ') || '|' ||
                         rpad(r_data.xx_pmt_dtl_vendor_status, 22, ' ') || '|' ||
                         rpad(r_data.xx_pmt_dtl_site_status, 22, ' ') || '|' ||
                         rpad(r_data.country, 17, ' ') || '|' ||
                         rpad(r_data.bank_number, 17, ' ') || '|' ||
                         rpad(r_data.bank_name, 17, ' ') || '|' ||
                         rpad(r_data.bank_alt_name, 17, ' ') || '|' ||
                         rpad(r_data.bank_description, 17, ' ') || '|' ||
                         rpad(r_data.branch_name, 17, ' ') || '|' ||
                         rpad(r_data.branch_number, 17, ' ') || '|' ||
                         rpad(r_data.alternate_branch_name, 17, ' ') || '|' ||
                         rpad(r_data.branch_description, 17, ' ') || '|' ||
                         rpad(r_data.bic, 17, ' ') || '|' ||
                         rpad(r_data.branch_type, 17, ' ') || '|' ||
                         rpad(r_data.branch_address1, 17, ' ') || '|' ||
                         rpad(r_data.branch_address2, 17, ' ') || '|' ||
                         rpad(r_data.branch_city, 17, ' ') || '|' ||
                         rpad(r_data.branch_province, 17, ' ') || '|' ||
                         rpad(r_data.branch_postal_code, 17, ' ') || '|' ||
                         rpad(r_data.branch_country, 17, ' ') || '|' ||
                         rpad(r_data.account_number, 17, ' ') || '|' ||
                         rpad(r_data.account_name, 17, ' ') || '|' ||
                         rpad(r_data.currency, 8, ' ') || '|' ||
                         rpad(r_data.acct_type, 17, ' ') || '|' ||
                         rpad(r_data.account_start_date, 13, ' ') || '|' ||
                         rpad(r_data.account_end_date, 13, ' ') || '|' ||
                         rpad(r_data.iban, 17, ' ') || '|' ||
                         rpad(r_data.vendor_number, 17, ' ') || '|' ||
                         rpad(r_data.vendor_site_code, 17, ' ') || '|' ||
                         rpad(r_data.vendor_default_payment_method, 17, ' ') || '|' ||
                         rpad(r_data.vendor_bank_instr1_code, 17, ' ') || '|' ||
                         rpad(r_data.vendor_bank_instr2_code, 17, ' ') || '|' ||
                         rpad(r_data.vendor_payment_reason_code, 17, ' ') || '|' ||
                         rpad(r_data.vendor_remit_delivery_method, 23, ' ') || '|' ||
                         rpad(r_data.vendor_remit_email_address, 25, ' ') || '|' ||
                         rpad(r_data.site_default_payment_method, 17, ' ') || '|' ||
                         rpad(r_data.site_bank_instr1_code, 17, ' ') || '|' ||
                         rpad(r_data.site_bank_instr2_code, 17, ' ') || '|' ||
                         rpad(r_data.site_payment_reason_code, 17, ' ') || '|' ||
                         rpad(r_data.site_remit_delivery_method, 23, ' ') || '|' ||
                         rpad(r_data.site_remit_email_address, 25, ' ') || '|' ||
                         r_data.xx_err_msg);
    
    END LOOP;
  
  EXCEPTION
    WHEN OTHERS THEN
      x_err_code := 1;
      x_err_msg  := 'Failed to generate report: ' || SQLERRM;
      fnd_file.put_line(fnd_file.log, x_err_msg);
    
  END report_data;
  --------------------------------------------------------------------
  --  name:              get_bank_account_id
  --  create by:         Michal Tzvik
  --  Revision:          1.0
  --  creation date:     03/08/2015
  --------------------------------------------------------------------
  --  purpose :          get external bank account id
  --                     
  --------------------------------------------------------------------
  --  ver  date          name             desc
  --  1.0  03/08/2015    Michal Tzvik     CHG0035411 - initial build
  --------------------------------------------------------------------
  FUNCTION get_bank_account_id(p_bank_party_id   NUMBER,
                               p_branch_party_id NUMBER,
                               p_account_num     VARCHAR2,
                               p_territory_code  VARCHAR2) RETURN NUMBER IS
    l_account_id NUMBER;
  BEGIN
  
    SELECT ieba.ext_bank_account_id
    INTO   l_account_id
    FROM   iby_ext_bank_accounts ieba
    WHERE  ieba.bank_account_num = p_account_num
    AND    ((p_bank_party_id IS NULL AND ieba.bank_id IS NULL) OR
          (ieba.bank_id = p_bank_party_id))
    AND    ((p_branch_party_id IS NULL AND ieba.branch_id IS NULL) OR
          (ieba.branch_id = p_branch_party_id))
    AND    ieba.country_code = p_territory_code;
  
    RETURN l_account_id;
    -- Handle exception when call this function. Sometimes "no data found" is valis... 
  END get_bank_account_id;

  --------------------------------------------------------------------
  --  name:              get_account_type_code
  --  create by:         Michal Tzvik
  --  Revision:          1.0
  --  creation date:     03/08/2015
  --------------------------------------------------------------------
  --  purpose :          get external bank account type code
  --                     
  --------------------------------------------------------------------
  --  ver  date          name             desc
  --  1.0  16/09/2015    Michal Tzvik     CHG0035411 - initial build
  --------------------------------------------------------------------
  PROCEDURE get_account_type_code(x_err_code          OUT NUMBER,
                                  x_err_msg           OUT VARCHAR2,
                                  p_account_type      IN VARCHAR2,
                                  x_account_type_code OUT VARCHAR2) IS
  BEGIN
    x_err_code := 0;
    x_err_msg  := '';
  
    SELECT flvv.lookup_code
    INTO   x_account_type_code
    FROM   fnd_lookup_values_vl flvv
    WHERE  flvv.lookup_type LIKE 'BANK_ACCOUNT_TYPE'
    AND    flvv.enabled_flag = 'Y'
    AND    SYSDATE BETWEEN nvl(flvv.start_date_active, SYSDATE - 1) AND
           nvl(flvv.end_date_active, SYSDATE + 1)
    AND    flvv.meaning = p_account_type;
  
  EXCEPTION
    WHEN OTHERS THEN
      x_err_code          := 1;
      x_err_msg           := 'Failed to get account type code of ' ||
                             p_account_type || ': ' || SQLERRM;
      x_account_type_code := '';
  END get_account_type_code;

  --------------------------------------------------------------------
  --  name:              get_bank_branch_party_id
  --  create by:         Michal Tzvik
  --  Revision:          1.0
  --  creation date:     03/08/2015
  --------------------------------------------------------------------
  --  purpose :          get external bank branch party id
  --                     
  --------------------------------------------------------------------
  --  ver  date          name             desc
  --  1.0  03/08/2015    Michal Tzvik     CHG0035411 - initial build
  --------------------------------------------------------------------
  FUNCTION get_bank_branch_party_id(p_bank_party_id  NUMBER,
                                    p_territory_code VARCHAR2,
                                    p_branch_number  VARCHAR2) RETURN NUMBER IS
    l_party_id NUMBER;
  BEGIN
    SELECT cbbv.branch_party_id
    INTO   l_party_id
    FROM   ce_bank_branches_v cbbv
    WHERE  cbbv.bank_party_id = p_bank_party_id
    AND    cbbv.bank_home_country = p_territory_code
    AND    cbbv.branch_number = to_char(p_branch_number);
  
    RETURN l_party_id;
  
    -- Handle exception when call this function. Sometimes "no data found" is valis... 
  END get_bank_branch_party_id;

  --------------------------------------------------------------------
  --  name:              get_bank_party_id
  --  create by:         Michal Tzvik
  --  Revision:          1.0
  --  creation date:     03/08/2015
  --------------------------------------------------------------------
  --  purpose :          get external bank party id
  --                     
  --------------------------------------------------------------------
  --  ver  date          name             desc
  --  1.0  03/08/2015    Michal Tzvik     CHG0035411 - initial build
  --------------------------------------------------------------------
  FUNCTION get_bank_party_id(p_bank_number    VARCHAR2,
                             p_bank_name      VARCHAR2,
                             p_territory_code VARCHAR2) RETURN NUMBER IS
    l_party_id NUMBER;
  BEGIN
    SELECT cbv.bank_party_id
    INTO   l_party_id
    FROM   ce_banks_v cbv
    WHERE  ((cbv.bank_number IS NULL AND p_bank_number IS NULL) OR
           cbv.bank_number = p_bank_number)
    AND    cbv.bank_name = p_bank_name
    AND    cbv.home_country = p_territory_code;
  
    RETURN l_party_id;
    -- Handle exception when call this function. Sometimes "no data found" is valis... 
  END get_bank_party_id;

  --------------------------------------------------------------------
  --  name:              get_vendor_details
  --  create by:         Michal Tzvik
  --  Revision:          1.0
  --  creation date:     27/08/2015
  --------------------------------------------------------------------
  --  purpose :          get vendor site details
  --                     
  --------------------------------------------------------------------
  --  ver  date          name             desc
  --  1.0  27/08/2015    Michal Tzvik     CHG0035411 - initial build
  --------------------------------------------------------------------
  PROCEDURE get_vendor_site_details(x_err_code      OUT NUMBER,
                                    x_err_msg       OUT VARCHAR2,
                                    p_vendor_id     IN NUMBER,
                                    p_site_code     IN VARCHAR2,
                                    x_org_id        OUT NUMBER,
                                    x_site_id       OUT NUMBER,
                                    x_party_site_id OUT NUMBER) IS
  BEGIN
    x_err_code := 0;
    x_err_msg  := '';
  
    SELECT assa.party_site_id,
           assa.vendor_site_id,
           assa.org_id
    INTO   x_party_site_id,
           x_site_id,
           x_org_id
    FROM   ap_supplier_sites_all assa
    WHERE  assa.vendor_site_code = p_site_code
    AND    assa.vendor_id = p_vendor_id;
  
  EXCEPTION
    WHEN no_data_found THEN
      x_err_code := 1;
      x_err_msg  := 'Supplier site does not exist';
  END get_vendor_site_details;

  --------------------------------------------------------------------
  --  name:              get_vendor_details
  --  create by:         Michal Tzvik
  --  Revision:          1.0
  --  creation date:     27/08/2015
  --------------------------------------------------------------------
  --  purpose :          get vendor details
  --                     
  --------------------------------------------------------------------
  --  ver  date          name             desc
  --  1.0  27/08/2015    Michal Tzvik     CHG0035411 - initial build
  --------------------------------------------------------------------
  PROCEDURE get_vendor_details(x_err_code        OUT NUMBER,
                               x_err_msg         OUT VARCHAR2,
                               p_vendor_number   IN VARCHAR2,
                               x_vendor_id       OUT NUMBER,
                               x_vendor_party_id OUT NUMBER) IS
  BEGIN
    x_err_code := 0;
    x_err_msg  := '';
  
    SELECT a.party_id,
           a.vendor_id
    INTO   x_vendor_party_id,
           x_vendor_id
    FROM   ap_suppliers a
    WHERE  a.segment1 = p_vendor_number;
  
  EXCEPTION
    WHEN no_data_found THEN
      x_vendor_party_id := NULL;
      x_vendor_id       := NULL;
      x_err_code        := 1;
      x_err_msg         := 'Supplier does not exist';
  END get_vendor_details;

  --------------------------------------------------------------------
  --  name:              get_location_id
  --  create by:         Michal Tzvik
  --  Revision:          1.0
  --  creation date:     03/08/2015
  --------------------------------------------------------------------
  --  purpose :          get location id
  --                     
  --------------------------------------------------------------------
  --  ver  date          name             desc
  --  1.0  03/08/2015    Michal Tzvik     CHG0035411 - initial build
  --------------------------------------------------------------------
  PROCEDURE get_location_id(x_err_code    OUT NUMBER,
                            x_err_msg     OUT VARCHAR2,
                            p_party_id    NUMBER,
                            x_location_id OUT NUMBER) IS
  BEGIN
  
    x_err_code := 0;
    x_err_msg  := '';
  
    SELECT hl.location_id
    INTO   x_location_id
    FROM   hz_locations   hl,
           hz_party_sites hps
    WHERE  hps.location_id = hl.location_id
    AND    hps.party_id = p_party_id
    AND    hps.status = 'A'
    AND    hps.identifying_address_flag = 'Y';
  
  EXCEPTION
    WHEN no_data_found THEN
      x_location_id := NULL;
    WHEN too_many_rows THEN
      x_err_code := 1;
      x_err_msg  := 'More than one address exist.';
  END get_location_id;
  /*  
  function is_length_valid(x_err_code     OUT NUMBER,
                           x_err_msg      OUT VARCHAR2,
                           p_interface_value in varchar2,
                           p_destination_length in number*/

  --------------------------------------------------------------------
  --  name:              is_bank_instruction_valid
  --  create by:         Michal Tzvik
  --  Revision:          1.0
  --  creation date:     27/08/2015
  --------------------------------------------------------------------
  --  purpose :          Check if bank instruction is valid
  --                     Return Y or N
  --------------------------------------------------------------------
  --  ver  date          name             desc
  --  1.0  27/08/2015    Michal Tzvik     CHG0035411 - initial build
  --------------------------------------------------------------------
  FUNCTION is_bank_instruction_valid(p_bank_instruction VARCHAR2)
    RETURN VARCHAR2 IS
    l_result VARCHAR2(1);
  BEGIN
  
    SELECT 'Y'
    INTO   l_result
    FROM   iby_bank_instructions_b ibib
    WHERE  ibib.bank_instruction_code = p_bank_instruction
    AND    (ibib.inactive_date IS NULL OR
          ibib.inactive_date >= trunc(SYSDATE))
    AND    SYSDATE > nvl(ibib.inactive_date, SYSDATE - 1);
  
    RETURN l_result;
  
  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log, 'Error in is_bank_instruction_valid (' ||
                         p_bank_instruction || ':' || SQLERRM);
      RETURN 'N';
  END is_bank_instruction_valid;

  --------------------------------------------------------------------
  --  name:              is_delivery_method_valid
  --  create by:         Michal Tzvik
  --  Revision:          1.0
  --  creation date:     27/08/2015
  --------------------------------------------------------------------
  --  purpose :          Check if delivery method is valid
  --                     Return Y or N
  --------------------------------------------------------------------
  --  ver  date          name             desc
  --  1.0  27/08/2015    Michal Tzvik     CHG0035411 - initial build
  --------------------------------------------------------------------
  FUNCTION is_delivery_method_valid(p_delivery_method VARCHAR2)
    RETURN VARCHAR2 IS
    l_result VARCHAR2(1);
  BEGIN
  
    SELECT 'Y'
    INTO   l_result
    FROM   fnd_lookup_values flv
    WHERE  flv.lookup_type LIKE 'IBY_DELIVERY_METHODS'
    AND    flv.language = 'US'
    AND    flv.lookup_code = p_delivery_method;
  
    RETURN l_result;
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 'N';
  END is_delivery_method_valid;

  --------------------------------------------------------------------
  --  name:              get_payment_method_code
  --  create by:         Michal Tzvik
  --  Revision:          1.0
  --  creation date:     27/08/2015
  --------------------------------------------------------------------
  --  purpose :          get payment method code
  --------------------------------------------------------------------
  --  ver  date          name             desc
  --  1.0  27/08/2015    Michal Tzvik     CHG0035411 - initial build
  --------------------------------------------------------------------
  PROCEDURE get_payment_method_code(x_err_code            OUT NUMBER,
                                    x_err_msg             OUT VARCHAR2,
                                    p_payment_method_name VARCHAR2,
                                    x_payment_method_code OUT VARCHAR2) IS
  BEGIN
    x_err_code := 0;
    x_err_msg  := '';
  
    IF p_payment_method_name IS NULL THEN
      x_payment_method_code := '';
      RETURN;
    END IF;
  
    SELECT m.payment_method_code
    INTO   x_payment_method_code
    FROM   iby_payment_methods_vl m
    WHERE  (m.inactive_date IS NULL OR m.inactive_date >= trunc(SYSDATE))
    AND    m.payment_method_name = p_payment_method_name;
  
  EXCEPTION
    WHEN OTHERS THEN
      x_err_code := 0;
      x_err_msg  := 'Failed to get payment method code: ' || SQLERRM;
  END get_payment_method_code;

  /*  FUNCTION is_payment_method_valid(p_payment_method VARCHAR2) RETURN VARCHAR2 IS
      l_result VARCHAR2(1);
    BEGIN
    
      SELECT 'Y'
      INTO   l_result
      FROM   iby_payment_methods_vl m
      WHERE  (m.inactive_date IS NULL OR m.inactive_date >= trunc(SYSDATE))
      AND    m.payment_method_name = p_payment_method;
    
      RETURN l_result;
    
    EXCEPTION
      WHEN OTHERS THEN
        RETURN 'N';
    END is_payment_method_valid;
  */
  --------------------------------------------------------------------
  --  name:              is_payment_reason_valid
  --  create by:         Michal Tzvik
  --  Revision:          1.0
  --  creation date:     27/08/2015
  --------------------------------------------------------------------
  --  purpose :          Check if payment reason code is valid
  --                     Return Y or N
  --------------------------------------------------------------------
  --  ver  date          name             desc
  --  1.0  27/08/2015    Michal Tzvik     CHG0035411 - initial build
  --------------------------------------------------------------------
  FUNCTION is_payment_reason_valid(p_payment_reason_code VARCHAR2)
    RETURN VARCHAR2 IS
    l_result VARCHAR2(1);
  BEGIN
    SELECT 'Y'
    INTO   l_result
    FROM   iby_payment_reasons_b iprb
    WHERE  iprb.payment_reason_code = p_payment_reason_code
    AND    (iprb.inactive_date IS NULL OR
          iprb.inactive_date >= trunc(SYSDATE));
  
    RETURN l_result;
  
  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log, 'Error in is_payment_reason_valid:' ||
                         SQLERRM);
      RETURN 'N';
  END is_payment_reason_valid;
  --------------------------------------------------------------------
  --  name:              set_interface_final_status
  --  create by:         Michal Tzvik
  --  Revision:          1.0
  --  creation date:     03/08/2015
  --------------------------------------------------------------------
  --  purpose :          update record in interface table: xxiby_bank_conv_interface
  --                     if no error exists, then set record's status to SUCCESS
  --------------------------------------------------------------------
  --  ver  date          name             desc
  --  1.0  03/08/2015    Michal Tzvik     CHG0035411 - initial build
  --------------------------------------------------------------------
  PROCEDURE set_interface_final_status IS
    l_success_status xxiby_bank_conv_interface.xx_status%TYPE;
  
  BEGIN
    IF g_simulation_mode = 'Y' THEN
      l_success_status := c_sts_valid;
    ELSE
      l_success_status := c_sts_success;
    END IF;
  
    UPDATE xxiby_bank_conv_interface xbci
    SET    xbci.xx_status = l_success_status
    WHERE  nvl(xbci.xx_pmt_dtl_site_status, l_success_status) =
           l_success_status
    AND    nvl(xbci.xx_pmt_dtl_vendor_status, l_success_status) =
           l_success_status
    AND    nvl(xbci.xx_acct_assignment_status, l_success_status) =
           l_success_status
    AND    nvl(xbci.xx_account_act_status, l_success_status) =
           l_success_status
    AND    nvl(xbci.xx_branch_act_status, l_success_status) =
           l_success_status
    AND    nvl(xbci.xx_bank_act_status, l_success_status) =
           l_success_status
    AND    (xbci.xx_pmt_dtl_site_status IS NOT NULL OR
            xbci.xx_pmt_dtl_vendor_status IS NOT NULL OR
            xbci.xx_acct_assignment_status IS NOT NULL OR
            xbci.xx_account_act_status IS NOT NULL OR
            xbci.xx_branch_act_status IS NOT NULL OR
            xbci.xx_bank_act_status IS NOT NULL);
  
    COMMIT;
  
  END set_interface_final_status;

  --------------------------------------------------------------------
  --  name:              update_pmt_dtl_int_rec
  --  create by:         Michal Tzvik
  --  Revision:          1.0
  --  creation date:     27/08/2015
  --------------------------------------------------------------------
  --  purpose :          update record in interface table
  --------------------------------------------------------------------
  --  ver  date          name             desc
  --  1.0  27/08/2015    Michal Tzvik     CHG0035411 - initial build
  --------------------------------------------------------------------
  PROCEDURE update_pmt_dtl_int_rec(p_pmt_dtl_int_rec IN OUT c_pmt_dtl%ROWTYPE) IS
    l_status xxiby_bank_conv_interface.xx_status%TYPE;
  BEGIN
    IF nvl(p_pmt_dtl_int_rec.xx_pmt_dtl_site_status, 'x') = c_sts_error OR
       nvl(p_pmt_dtl_int_rec.xx_pmt_dtl_vendor_status, 'x') = c_sts_error THEN
      l_status := c_sts_error;
    ELSE
      l_status := c_sts_in_process;
    END IF;
  
    UPDATE xxiby_bank_conv_interface xbi
    SET    xbi.last_update_date     = SYSDATE,
           xbi.last_updated_by      = fnd_global.user_id,
           xbi.xx_status            = l_status,
           xbi.xx_err_msg           = decode(xbi.xx_err_msg, NULL, p_pmt_dtl_int_rec.xx_err_msg, xbi.xx_err_msg || ';' ||
                                              p_pmt_dtl_int_rec.xx_err_msg),
           xbi.vendor_id            = nvl(p_pmt_dtl_int_rec.vendor_id, xbi.vendor_id),
           xbi.vendor_party_id      = nvl(p_pmt_dtl_int_rec.vendor_party_id, xbi.vendor_party_id),
           xbi.vendor_party_site_id = nvl(p_pmt_dtl_int_rec.vendor_party_site_id, xbi.vendor_party_site_id),
           xbi.vendor_site_id       = nvl(p_pmt_dtl_int_rec.vendor_site_id, xbi.vendor_site_id),
           xbi.org_id               = nvl(p_pmt_dtl_int_rec.org_id, xbi.org_id),
           xx_pmt_dtl_site_status   = nvl(p_pmt_dtl_int_rec.xx_pmt_dtl_site_status, xbi.xx_pmt_dtl_site_status),
           xx_pmt_dtl_vendor_status = nvl(p_pmt_dtl_int_rec.xx_pmt_dtl_vendor_status, xbi.xx_pmt_dtl_vendor_status)
    WHERE  xbi.xx_batch_id = g_batch_id
    AND    xbi.xx_interface_id = p_pmt_dtl_int_rec.xx_interface_id
    AND    xbi.xx_status != c_sts_error;
  
  END update_pmt_dtl_int_rec;
  --------------------------------------------------------------------
  --  name:              update_bank_account_int_rec
  --  create by:         Michal Tzvik
  --  Revision:          1.0
  --  creation date:     03/08/2015
  --------------------------------------------------------------------
  --  purpose :          update record in interface table
  --------------------------------------------------------------------
  --  ver  date          name             desc
  --  1.0  03/08/2015    Michal Tzvik     CHG0035411 - initial build
  --------------------------------------------------------------------
  PROCEDURE update_bank_account_int_rec(p_bank_account_int_rec IN OUT c_account%ROWTYPE) IS
    l_status xxiby_bank_conv_interface.xx_status%TYPE;
  BEGIN
  
    IF nvl(p_bank_account_int_rec.xx_acct_assignment_status, 'x') =
       c_sts_error OR
       nvl(p_bank_account_int_rec.xx_account_act_status, 'x') = c_sts_error THEN
      l_status := c_sts_error;
    ELSE
      l_status := c_sts_in_process;
    END IF;
  
    UPDATE xxiby_bank_conv_interface xbi
    SET    xbi.last_update_date      = SYSDATE,
           xbi.last_updated_by       = fnd_global.user_id,
           xbi.xx_status             = l_status,
           xbi.xx_err_msg            = decode(xbi.xx_err_msg, NULL, p_bank_account_int_rec.xx_err_msg, xbi.xx_err_msg || ';' ||
                                               p_bank_account_int_rec.xx_err_msg),
           xbi.bank_party_id         = nvl(p_bank_account_int_rec.bank_party_id, xbi.bank_party_id),
           xbi.branch_party_id       = nvl(p_bank_account_int_rec.branch_party_id, xbi.branch_party_id),
           xbi.bank_account_id       = nvl(p_bank_account_int_rec.bank_account_id, xbi.bank_account_id),
           xbi.vendor_id             = nvl(p_bank_account_int_rec.vendor_id, xbi.vendor_id),
           xbi.vendor_party_id       = nvl(p_bank_account_int_rec.vendor_party_id, xbi.vendor_party_id),
           xbi.vendor_party_site_id  = nvl(p_bank_account_int_rec.vendor_party_site_id, xbi.vendor_party_site_id),
           xbi.vendor_site_id        = nvl(p_bank_account_int_rec.vendor_site_id, xbi.vendor_site_id),
           xbi.org_id                = nvl(p_bank_account_int_rec.org_id, xbi.org_id),
           xbi.location_id           = nvl(p_bank_account_int_rec.location_id, xbi.location_id),
           xx_acct_assignment_status = nvl(p_bank_account_int_rec.xx_acct_assignment_status, xbi.xx_acct_assignment_status),
           xx_account_act_status     = nvl(p_bank_account_int_rec.xx_account_act_status, xbi.xx_account_act_status)
    WHERE  xbi.xx_batch_id = g_batch_id
    AND    xbi.xx_interface_id = p_bank_account_int_rec.xx_interface_id
          -- AND    nvl(xbi.country, 'x') = nvl(p_bank_account_int_rec.country, 'x')
          -- AND    nvl(xbi.bank_number, 'x') =
          --        nvl(p_bank_account_int_rec.bank_number, 'x')
          -- AND    nvl(xbi.branch_number, 'x') =
          --        nvl(p_bank_account_int_rec.branch_number, 'x')
          -- AND    nvl(xbi.account_number, 'x') =
          --        nvl(p_bank_account_int_rec.account_number, 'x')
    AND    xbi.xx_status != c_sts_error;
  
  END update_bank_account_int_rec;
  --------------------------------------------------------------------
  --  name:              update_bank_branch_int_rec
  --  create by:         Michal Tzvik
  --  Revision:          1.0
  --  creation date:     03/08/2015
  --------------------------------------------------------------------
  --  purpose :          update record in interface table
  --------------------------------------------------------------------
  --  ver  date          name             desc
  --  1.0  03/08/2015    Michal Tzvik     CHG0035411 - initial build
  --------------------------------------------------------------------
  PROCEDURE update_bank_branch_int_rec(p_bank_branch_int_rec IN OUT c_branch%ROWTYPE) IS
    l_status xxiby_bank_conv_interface.xx_status%TYPE;
  BEGIN
  
    IF nvl(p_bank_branch_int_rec.xx_branch_act_status, 'x') = c_sts_error THEN
      l_status := c_sts_error;
    ELSE
      l_status := c_sts_in_process;
    END IF;
  
    UPDATE xxiby_bank_conv_interface xbi
    SET    xbi.last_update_date = SYSDATE,
           xbi.last_updated_by  = fnd_global.user_id,
           xbi.xx_status        = l_status,
           xbi.xx_err_msg       = decode(xbi.xx_err_msg, NULL, p_bank_branch_int_rec.xx_err_msg, xbi.xx_err_msg || ';' ||
                                          p_bank_branch_int_rec.xx_err_msg),
           xbi.bank_party_id    = nvl(p_bank_branch_int_rec.bank_party_id, xbi.bank_party_id),
           xbi.branch_party_id  = nvl(p_bank_branch_int_rec.branch_party_id, xbi.branch_party_id),
           xbi.location_id      = nvl(p_bank_branch_int_rec.location_id, xbi.location_id),
           xx_branch_act_status = nvl(p_bank_branch_int_rec.xx_branch_act_status, xbi.xx_branch_act_status)
    WHERE  xbi.xx_batch_id = g_batch_id
    AND    nvl(xbi.country, 'x') = nvl(p_bank_branch_int_rec.country, 'x')
    AND    nvl(xbi.bank_number, 'x') =
           nvl(p_bank_branch_int_rec.bank_number, 'x')
    AND    nvl(xbi.branch_number, 'x') =
           nvl(p_bank_branch_int_rec.branch_number, 'x')
    AND    xbi.xx_status != c_sts_error;
  
  END update_bank_branch_int_rec;

  --------------------------------------------------------------------
  --  name:              update_bank_int_rec
  --  create by:         Michal Tzvik
  --  Revision:          1.0
  --  creation date:     03/08/2015
  --------------------------------------------------------------------
  --  purpose :          update record in interface table
  --------------------------------------------------------------------
  --  ver  date          name             desc
  --  1.0  03/08/2015    Michal Tzvik     CHG0035411 - initial build
  --------------------------------------------------------------------
  PROCEDURE update_bank_int_rec(p_bank_int_rec IN OUT c_bank%ROWTYPE) IS
    l_status xxiby_bank_conv_interface.xx_status%TYPE;
  BEGIN
  
    IF nvl(p_bank_int_rec.xx_bank_act_status, 'x') = c_sts_error THEN
      l_status := c_sts_error;
    ELSE
      l_status := c_sts_in_process;
    END IF;
  
    UPDATE xxiby_bank_conv_interface xbi
    SET    xbi.last_update_date = SYSDATE,
           xbi.last_updated_by  = fnd_global.user_id,
           xbi.xx_status        = l_status,
           xbi.xx_err_msg       = decode(xbi.xx_err_msg, NULL, p_bank_int_rec.xx_err_msg, xbi.xx_err_msg || ';' ||
                                          p_bank_int_rec.xx_err_msg),
           xbi.bank_party_id    = nvl(p_bank_int_rec.bank_party_id, xbi.bank_party_id),
           xbi.location_id      = nvl(p_bank_int_rec.location_id, xbi.location_id),
           xx_bank_act_status   = nvl(p_bank_int_rec.xx_bank_act_status, xbi.xx_bank_act_status)
    WHERE  xbi.xx_batch_id = g_batch_id
    AND    nvl(xbi.country, 'x') = nvl(p_bank_int_rec.country, 'x')
    AND    nvl(xbi.bank_number, 'x') = nvl(p_bank_int_rec.bank_number, 'x')
    AND    xbi.xx_status != c_sts_error;
  
  END update_bank_int_rec;

  --------------------------------------------------------------------
  --  name:              validate_payment_details
  --  create by:         Michal Tzvik
  --  Revision:          1.0
  --  creation date:     03/08/2015
  --------------------------------------------------------------------
  --  purpose :          get missing values and validate data
  --------------------------------------------------------------------
  --  ver  date          name             desc
  --  1.0  03/08/2015    Michal Tzvik     CHG0035411 - initial build
  --------------------------------------------------------------------
  PROCEDURE validate_payment_details(x_err_code        OUT NUMBER,
                                     x_err_msg         OUT VARCHAR2,
                                     p_pmt_dtl_int_rec IN OUT c_pmt_dtl%ROWTYPE) IS
  
  BEGIN
    x_err_code := 0;
    x_err_msg  := '';
  
    -- validate vendor
    IF p_pmt_dtl_int_rec.vendor_id IS NULL THEN
      get_vendor_details(x_err_code => x_err_code, --
                         x_err_msg => x_err_msg, --
                         p_vendor_number => p_pmt_dtl_int_rec.vendor_number, --
                         x_vendor_id => p_pmt_dtl_int_rec.vendor_id, --
                         x_vendor_party_id => p_pmt_dtl_int_rec.vendor_party_id);
      IF x_err_code != 0 THEN
        RETURN;
      END IF;
    END IF;
  
    -- validate vendor site
    IF p_pmt_dtl_int_rec.vendor_site_code IS NOT NULL AND
       p_pmt_dtl_int_rec.vendor_site_id IS NULL THEN
      get_vendor_site_details(x_err_code => x_err_code, --
                              x_err_msg => x_err_msg, --
                              p_vendor_id => p_pmt_dtl_int_rec.vendor_id, --
                              p_site_code => p_pmt_dtl_int_rec.vendor_site_code, --
                              x_org_id => p_pmt_dtl_int_rec.org_id, --
                              x_site_id => p_pmt_dtl_int_rec.vendor_site_id, --
                              x_party_site_id => p_pmt_dtl_int_rec.vendor_party_site_id);
      IF x_err_code != 0 THEN
        RETURN;
      END IF;
    END IF;
  
    IF p_pmt_dtl_int_rec.payment_reason_code IS NOT NULL THEN
      IF is_payment_reason_valid(p_pmt_dtl_int_rec.payment_reason_code) = 'N' THEN
        x_err_msg  := 'Invalid value for payment_reason_code field ' ||
                      p_pmt_dtl_int_rec.payment_reason_code || ' (' ||
                      p_pmt_dtl_int_rec.data_level || ')';
        x_err_code := 1;
        RETURN;
      END IF;
    END IF;
  
    /*IF p_pmt_dtl_int_rec.default_payment_method IS NOT NULL THEN
      IF is_payment_method_valid(p_pmt_dtl_int_rec.default_payment_method) = 'N' THEN
        x_err_msg  := 'Invalid value for default_payment_method field (' ||
                      p_pmt_dtl_int_rec.data_level || ')';
        x_err_code := 1;
        RETURN;
      END IF;
    END IF;*/
    get_payment_method_code(x_err_code => x_err_code, x_err_msg => x_err_msg, p_payment_method_name => p_pmt_dtl_int_rec.default_payment_method, x_payment_method_code => p_pmt_dtl_int_rec.default_payment_method_code);
    IF x_err_code != 0 THEN
      RETURN;
    END IF;
  
    IF p_pmt_dtl_int_rec.delivery_method IS NOT NULL THEN
      IF is_delivery_method_valid(p_pmt_dtl_int_rec.delivery_method) = 'N' THEN
        x_err_msg  := 'Invalid value for delivery_method field (' ||
                      p_pmt_dtl_int_rec.data_level || ')';
        x_err_code := 1;
        RETURN;
      END IF;
    END IF;
  
    IF p_pmt_dtl_int_rec.bank_instr1_code IS NOT NULL THEN
      IF is_bank_instruction_valid(p_pmt_dtl_int_rec.bank_instr1_code) = 'N' THEN
        x_err_msg  := 'Invalid value for bank_instr1_code field (' ||
                      p_pmt_dtl_int_rec.data_level || ')';
        x_err_code := 1;
        RETURN;
      END IF;
    END IF;
  
    IF p_pmt_dtl_int_rec.bank_instr2_code IS NOT NULL THEN
      IF is_bank_instruction_valid(p_pmt_dtl_int_rec.bank_instr2_code) = 'N' THEN
        x_err_msg  := 'Invalid value for bank_instr2_code field (' ||
                      p_pmt_dtl_int_rec.data_level || ')';
        x_err_code := 1;
        RETURN;
      END IF;
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      x_err_code := 1;
      x_err_msg  := 'Unexpected error in xxiby_bank_conv_pkg.validate_payment_details: ' ||
                    SQLERRM;
  END validate_payment_details;

  --------------------------------------------------------------------
  --  name:              validate_ext_bank_account
  --  create by:         Michal Tzvik
  --  Revision:          1.0
  --  creation date:     03/08/2015
  --------------------------------------------------------------------
  --  purpose :          get missing values and validate data
  --------------------------------------------------------------------
  --  ver  date          name             desc
  --  1.0  03/08/2015    Michal Tzvik     CHG0035411 - initial build
  --------------------------------------------------------------------
  PROCEDURE validate_ext_bank_account(x_err_code             OUT NUMBER,
                                      x_err_msg              OUT VARCHAR2,
                                      p_bank_account_int_rec IN OUT c_account%ROWTYPE) IS
    l_lengthb NUMBER;
  BEGIN
    x_err_code := 0;
    x_err_msg  := '';
  
    -- Handle byte length error which occur in several languages, such as Japanese
    l_lengthb := lengthb(p_bank_account_int_rec.account_name);
    IF l_lengthb > 80 THEN
      x_err_code := 1;
      x_err_msg  := 'Account_name value is too long (actual ' || l_lengthb ||
                    ', maximum 80)';
      RETURN;
    END IF;
  
    IF p_bank_account_int_rec.country IS NULL THEN
      x_err_code := 1;
      x_err_msg  := 'Country is required';
      RETURN;
    END IF;
  
    IF p_bank_account_int_rec.bank_party_id IS NULL THEN
      BEGIN
        p_bank_account_int_rec.bank_party_id := get_bank_party_id(p_bank_account_int_rec.bank_number, p_bank_account_int_rec.bank_name, p_bank_account_int_rec.country);
      
      EXCEPTION
        WHEN no_data_found THEN
          x_err_code := 1;
          x_err_msg  := 'Bank does not exit';
          RETURN;
        WHEN too_many_rows THEN
          x_err_code := 1;
          x_err_msg  := 'More than one bank exists for bank_number and country';
          RETURN;
        WHEN OTHERS THEN
          x_err_code := 1;
          x_err_msg  := 'Unexpected error in xxiby_bank_conv_pkg.get_bank_party_id: ' ||
                        SQLERRM;
          RETURN;
      END;
    END IF;
  
    BEGIN
      p_bank_account_int_rec.branch_party_id := get_bank_branch_party_id(p_bank_party_id => p_bank_account_int_rec.bank_party_id, --
                                                                         p_territory_code => p_bank_account_int_rec.country, --
                                                                         p_branch_number => p_bank_account_int_rec.branch_number);
    
    EXCEPTION
      WHEN no_data_found THEN
        x_err_code := 1;
        x_err_msg  := 'Bank branch does not exist';
        RETURN;
      WHEN too_many_rows THEN
        x_err_code := 1;
        x_err_msg  := 'More than one bank branch exists for bank_number, branch_number and country';
        RETURN;
      WHEN OTHERS THEN
        x_err_code := 1;
        x_err_msg  := 'Unexpected error in xxiby_bank_conv_pkg.get_bank_branch_party_id: ' ||
                      SQLERRM;
        RETURN;
    END;
  
    IF p_bank_account_int_rec.branch_party_id IS NULL THEN
      x_err_msg  := 'Bank branch does not exist';
      x_err_code := 1;
      RETURN;
    END IF;
  
    BEGIN
      p_bank_account_int_rec.bank_account_id := get_bank_account_id(p_bank_party_id => p_bank_account_int_rec.bank_party_id, --
                                                                    p_branch_party_id => p_bank_account_int_rec.branch_party_id, --
                                                                    p_account_num => p_bank_account_int_rec.account_number, --
                                                                    p_territory_code => p_bank_account_int_rec.country);
    
    EXCEPTION
      WHEN no_data_found THEN
        IF p_bank_account_int_rec.xx_account_action = c_action_update THEN
          x_err_code := 1;
          x_err_msg  := 'Bank account does not exit';
          RETURN;
        END IF;
      WHEN too_many_rows THEN
        x_err_code := 1;
        x_err_msg  := 'More than one bank account exists for bank_number, branch_number, account_number and country';
        RETURN;
      WHEN OTHERS THEN
        x_err_code := 1;
        x_err_msg  := 'Unexpected error in xxiby_bank_conv_pkg.get_bank_account_id: ' ||
                      SQLERRM;
        RETURN;
    END;
  
    IF p_bank_account_int_rec.xx_account_action = c_action_create THEN
      IF p_bank_account_int_rec.bank_account_id IS NOT NULL THEN
        x_err_msg  := 'Bank account already exists';
        x_err_code := 1;
        RETURN;
      END IF;
    
    ELSIF p_bank_account_int_rec.xx_account_action != c_action_update THEN
      x_err_code := 1;
      x_err_msg  := 'Invalid value for XX_ACCOUNT_ACTION field';
      RETURN;
    END IF;
  
    IF p_bank_account_int_rec.vendor_number IS NOT NULL THEN
      get_vendor_details(x_err_code => x_err_code, --
                         x_err_msg => x_err_msg, --
                         p_vendor_number => p_bank_account_int_rec.vendor_number, --
                         x_vendor_id => p_bank_account_int_rec.vendor_id, --
                         x_vendor_party_id => p_bank_account_int_rec.vendor_party_id);
      IF x_err_code != 0 THEN
        RETURN;
      END IF;
    END IF;
  
    IF p_bank_account_int_rec.vendor_site_code IS NOT NULL THEN
      get_vendor_site_details(x_err_code => x_err_code, --
                              x_err_msg => x_err_msg, --
                              p_vendor_id => p_bank_account_int_rec.vendor_id, --
                              p_site_code => p_bank_account_int_rec.vendor_site_code, --
                              x_org_id => p_bank_account_int_rec.org_id, --
                              x_site_id => p_bank_account_int_rec.vendor_site_id, --
                              x_party_site_id => p_bank_account_int_rec.vendor_party_site_id);
      IF x_err_code != 0 THEN
        RETURN;
      END IF;
    END IF;
  
    IF p_bank_account_int_rec.acct_type IS NOT NULL THEN
      get_account_type_code(x_err_code => x_err_code, --
                            x_err_msg => x_err_msg, --
                            p_account_type => p_bank_account_int_rec.acct_type, --
                            x_account_type_code => p_bank_account_int_rec.acct_type_code);
      IF x_err_code != 0 THEN
        RETURN;
      END IF;
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      x_err_code := 1;
      x_err_msg  := 'Unexpected error in xxiby_bank_conv_pkg.validate_ext_bank_account: ' ||
                    SQLERRM;
  END validate_ext_bank_account;

  --------------------------------------------------------------------
  --  name:              validate_ext_bank_branch
  --  create by:         Michal Tzvik
  --  Revision:          1.0
  --  creation date:     03/08/2015
  --------------------------------------------------------------------
  --  purpose :          get missing values and validate data
  --------------------------------------------------------------------
  --  ver  date          name             desc
  --  1.0  03/08/2015    Michal Tzvik     CHG0035411 - initial build
  --------------------------------------------------------------------
  PROCEDURE validate_ext_bank_branch(x_err_code            OUT NUMBER,
                                     x_err_msg             OUT VARCHAR2,
                                     p_bank_branch_int_rec IN OUT c_branch%ROWTYPE) IS
    l_lengthb NUMBER;
  BEGIN
    x_err_code := 0;
    x_err_msg  := '';
  
    -- Handle byte length error which occur in several languages, such as Japanese
    l_lengthb := lengthb(p_bank_branch_int_rec.alternate_branch_name);
    IF l_lengthb > 320 THEN
      x_err_code := 1;
      x_err_msg  := 'alternate_branch_name value is too long (actual ' ||
                    l_lengthb || ', maximum 320)';
      RETURN;
    END IF;
  
    l_lengthb := lengthb(p_bank_branch_int_rec.branch_description);
    IF l_lengthb > 2000 THEN
      x_err_code := 1;
      x_err_msg  := 'branch_description value is too long (actual ' ||
                    l_lengthb || ', maximum 2000)';
      RETURN;
    END IF;
  
    IF p_bank_branch_int_rec.country IS NULL THEN
      x_err_code := 1;
      x_err_msg  := 'Country is required';
      RETURN;
    END IF;
  
    IF p_bank_branch_int_rec.bank_party_id IS NULL THEN
      BEGIN
        p_bank_branch_int_rec.bank_party_id := get_bank_party_id(p_bank_branch_int_rec.bank_number, p_bank_branch_int_rec.bank_name, p_bank_branch_int_rec.country);
      EXCEPTION
      
        WHEN no_data_found THEN
          x_err_code := 1;
          x_err_msg  := 'Bank does not exit';
          RETURN;
        WHEN too_many_rows THEN
          x_err_code := 1;
          x_err_msg  := 'More than one bank exists for bank_number and country';
          RETURN;
        WHEN OTHERS THEN
          x_err_code := 1;
          x_err_msg  := 'Unexpected error in xxiby_bank_conv_pkg.get_bank_party_id: ' ||
                        SQLERRM;
          RETURN;
      END;
    END IF;
  
    BEGIN
      p_bank_branch_int_rec.branch_party_id := get_bank_branch_party_id(p_bank_party_id => p_bank_branch_int_rec.bank_party_id, --
                                                                        p_territory_code => p_bank_branch_int_rec.country, --
                                                                        p_branch_number => p_bank_branch_int_rec.branch_number);
    
    EXCEPTION
      WHEN no_data_found THEN
        IF p_bank_branch_int_rec.xx_branch_action = c_action_update THEN
          x_err_code := 1;
          x_err_msg  := 'Bank branch does not exist';
          RETURN;
        END IF;
      WHEN too_many_rows THEN
        x_err_code := 1;
        x_err_msg  := 'More than one bank branch exists for bank_number, branch_number and country';
        RETURN;
      WHEN OTHERS THEN
        x_err_code := 1;
        x_err_msg  := 'Unexpected error in xxiby_bank_conv_pkg.get_bank_branch_party_id: ' ||
                      SQLERRM;
        RETURN;
    END;
  
    IF p_bank_branch_int_rec.xx_branch_action = c_action_create THEN
      IF p_bank_branch_int_rec.branch_party_id IS NOT NULL THEN
        x_err_msg  := 'Bank branch already exists';
        x_err_code := 1;
        RETURN;
      END IF;
    
    ELSIF p_bank_branch_int_rec.xx_branch_action != c_action_update THEN
      x_err_code := 1;
      x_err_msg  := 'Invalid value for XX_BRANCH_ACTION field';
      RETURN;
    END IF;
  
    get_location_id(x_err_code => x_err_code, --
                    x_err_msg => x_err_msg, --
                    p_party_id => p_bank_branch_int_rec.branch_party_id, --
                    x_location_id => p_bank_branch_int_rec.location_id);
    IF x_err_code != 0 THEN
      RETURN;
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      x_err_code := 1;
      x_err_msg  := 'Unexpected error in xxiby_bank_conv_pkg.validate_ext_bank_branch: ' ||
                    SQLERRM;
  END validate_ext_bank_branch;

  --------------------------------------------------------------------
  --  name:              validate_ext_bank
  --  create by:         Michal Tzvik
  --  Revision:          1.0
  --  creation date:     03/08/2015
  --------------------------------------------------------------------
  --  purpose :          get missing values and validate data
  --------------------------------------------------------------------
  --  ver  date          name             desc
  --  1.0  03/08/2015    Michal Tzvik     CHG0035411 - initial build
  --------------------------------------------------------------------
  PROCEDURE validate_ext_bank(x_err_code     OUT NUMBER,
                              x_err_msg      OUT VARCHAR2,
                              p_bank_int_rec IN OUT c_bank%ROWTYPE) IS
    l_lengthb NUMBER;
  BEGIN
    x_err_code := 0;
    x_err_msg  := '';
  
    l_lengthb := lengthb(p_bank_int_rec.bank_alt_name);
    IF l_lengthb > 320 THEN
      x_err_code := 1;
      x_err_msg  := 'bank_alt_name value is too long (actual ' || l_lengthb ||
                    ', maximum 320)';
      RETURN;
    END IF;
  
    l_lengthb := lengthb(p_bank_int_rec.bank_description);
    IF l_lengthb > 2000 THEN
      x_err_code := 1;
      x_err_msg  := 'bank_description value is too long (actual ' ||
                    l_lengthb || ', maximum 2000)';
      RETURN;
    END IF;
  
    IF p_bank_int_rec.country IS NULL THEN
      x_err_code := 1;
      x_err_msg  := 'Country is required';
      RETURN;
    END IF;
  
    BEGIN
      p_bank_int_rec.bank_party_id := get_bank_party_id(p_bank_int_rec.bank_number, p_bank_int_rec.bank_name, p_bank_int_rec.country);
    
    EXCEPTION
      WHEN no_data_found THEN
        IF p_bank_int_rec.xx_bank_action = c_action_update THEN
          x_err_code := 1;
          x_err_msg  := 'Bank does not exist';
          RETURN;
        END IF;
      WHEN too_many_rows THEN
        x_err_code := 1;
        x_err_msg  := 'More than one bank exists for bank_number and country';
        RETURN;
      WHEN OTHERS THEN
        x_err_code := 1;
        x_err_msg  := 'Unexpected error in xxiby_bank_conv_pkg.get_bank_party_id: ' ||
                      SQLERRM;
        RETURN;
    END;
  
    IF p_bank_int_rec.xx_bank_action = c_action_create THEN
      IF p_bank_int_rec.bank_party_id IS NOT NULL THEN
        x_err_code := 1;
        x_err_msg  := 'Bank already exists';
        RETURN;
      END IF;
    
    ELSIF p_bank_int_rec.xx_bank_action != c_action_update THEN
      x_err_code := 1;
      x_err_msg  := 'Invalid value for XX_BANK_ACTION field';
      RETURN;
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      x_err_code := 1;
      x_err_msg  := 'Unexpected error in xxiby_bank_conv_pkg.validate_ext_bank: ' ||
                    SQLERRM;
  END validate_ext_bank;

  --------------------------------------------------------------------
  --  name:              assign_account_to_owner_api
  --  create by:         Michal Tzvik
  --  Revision:          1.0
  --  creation date:     03/08/2015
  --------------------------------------------------------------------
  --  purpose :          Assign bank account to a supplier / supplier
  --                     site by api
  --------------------------------------------------------------------
  --  ver  date          name             desc
  --  1.0  03/08/2015    Michal Tzvik     CHG0035411 - initial build
  --------------------------------------------------------------------
  PROCEDURE assign_account_to_owner_api(x_err_code             OUT NUMBER,
                                        x_err_msg              OUT VARCHAR2,
                                        p_bank_account_int_rec IN OUT c_account%ROWTYPE) IS
  
    l_joint_acct_owner_id NUMBER;
    l_return_status       VARCHAR2(20);
    l_msg_count           NUMBER;
    l_msg_data            VARCHAR2(2000);
    l_data                VARCHAR2(1000);
    l_msg_index_out       NUMBER;
    l_response            iby_fndcpt_common_pub.result_rec_type;
  
    l_payee              iby_disbursement_setup_pub.payeecontext_rec_type;
    l_instrument         iby_fndcpt_setup_pub.pmtinstrument_rec_type;
    l_assignment_attribs iby_fndcpt_setup_pub.pmtinstrassignment_rec_type;
    l_assign_id          NUMBER;
    l_owner_party_id     NUMBER;
  BEGIN
    x_err_code := 0;
    x_err_msg  := '';
  
    IF p_bank_account_int_rec.xx_acct_assignment_level = 'SUPPLIER' THEN
      IF p_bank_account_int_rec.vendor_party_id IS NULL THEN
        x_err_code := 1;
        x_err_msg  := 'Cannot assign bank account to vendor; vendor_party_id is null';
        RETURN;
      END IF;
      l_owner_party_id := p_bank_account_int_rec.vendor_party_id;
    
    ELSIF p_bank_account_int_rec.xx_acct_assignment_level = 'SITE' THEN
      IF p_bank_account_int_rec.vendor_party_id IS NULL THEN
        x_err_code := 1;
        x_err_msg  := 'Cannot assign bank account to vendor site; vendor_party_site_id is null';
        RETURN;
      END IF;
      l_owner_party_id := p_bank_account_int_rec.vendor_party_site_id;
    
    ELSIF p_bank_account_int_rec.xx_acct_assignment_level IS NOT NULL THEN
      x_err_code := 1;
      x_err_msg  := 'Invalid value for field XX_ACCT_ASSIGNMENT_LEVEL';
      RETURN;
    
    ELSE
      RETURN; -- no assignment is required
    END IF;
  
    BEGIN
      l_payee.party_id         := p_bank_account_int_rec.vendor_party_id;
      l_payee.payment_function := 'PAYABLES_DISB';
      IF p_bank_account_int_rec.xx_acct_assignment_level = 'SITE' THEN
        l_payee.party_site_id    := p_bank_account_int_rec.vendor_party_site_id;
        l_payee.supplier_site_id := p_bank_account_int_rec.vendor_site_id;
        l_payee.org_id           := p_bank_account_int_rec.org_id;
        l_payee.org_type         := 'OPERATING_UNIT';
      END IF;
    
      l_instrument.instrument_type    := 'BANKACCOUNT';
      l_instrument.instrument_id      := p_bank_account_int_rec.bank_account_id;
      l_assignment_attribs.instrument := l_instrument;
      --l_assignment_attribs.priority := 1;
      l_assignment_attribs.start_date := to_date(p_bank_account_int_rec.account_start_date, 'DD-MM-YYYY');
      l_assignment_attribs.end_date   := to_date(p_bank_account_int_rec.account_end_date, 'DD-MM-YYYY');
      l_msg_count                     := 0;
      l_msg_data                      := NULL;
      l_return_status                 := NULL;
      l_response                      := NULL;
    
      iby_disbursement_setup_pub.set_payee_instr_assignment(p_api_version => 1.0, --
                                                            p_init_msg_list => fnd_api.g_true, --
                                                            p_commit => fnd_api.g_true, --
                                                            x_return_status => l_return_status, --
                                                            x_msg_count => l_msg_count, --
                                                            x_msg_data => l_msg_data, --
                                                            p_payee => l_payee, --
                                                            p_assignment_attribs => l_assignment_attribs, --
                                                            x_assign_id => l_assign_id, --
                                                            x_response => l_response);
    
      COMMIT;
    
      IF l_return_status = fnd_api.g_ret_sts_success THEN
        p_bank_account_int_rec.xx_acct_assignment_status := c_sts_success;
      ELSE
        FOR i IN 1 .. l_msg_count LOOP
          fnd_msg_pub.get(p_msg_index => i, p_data => l_data, p_encoded => fnd_api.g_false, p_msg_index_out => l_msg_index_out);
          x_err_msg := x_err_msg || l_data || chr(10);
        END LOOP;
        x_err_code := 1;
        x_err_msg  := 'API failure (set_payee_instr_assignment): ' ||
                      x_err_msg;
      END IF;
    
    EXCEPTION
      WHEN OTHERS THEN
        x_err_code := 1;
        x_err_msg  := 'Failed to run set_payee_instr_assignment';
        dbms_output.put_line('Error occurred during procedure.');
        dbms_output.put_line('sqlcode: ' || SQLCODE || ' Sqlerrm: ' ||
                             substr(SQLERRM, 1, 255));
        NULL;
    END;
    IF x_err_code != 0 THEN
      p_bank_account_int_rec.xx_acct_assignment_status := c_sts_error;
      p_bank_account_int_rec.xx_err_msg                := x_err_msg;
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      x_err_code                                       := 1;
      x_err_msg                                        := 'Unexpected error in xxiby_bank_conv_pkg.assign_account_to_owner_api: ' ||
                                                          SQLERRM;
      p_bank_account_int_rec.xx_acct_assignment_status := c_sts_error;
      p_bank_account_int_rec.xx_err_msg                := x_err_msg;
  END assign_account_to_owner_api;

  --------------------------------------------------------------------
  --  name:              update_payment_details_api
  --  create by:         Michal Tzvik
  --  Revision:          1.0
  --  creation date:     23/08/2015
  --------------------------------------------------------------------
  --  purpose :          update payment details by api
  --------------------------------------------------------------------
  --  ver  date          name             desc
  --  1.0  23/08/2015    Michal Tzvik     CHG0035411 - initial build
  --------------------------------------------------------------------
  PROCEDURE update_payment_details_api(x_err_code         OUT NUMBER,
                                       x_err_msg          OUT VARCHAR2,
                                       p_ext_payee_id_tab iby_disbursement_setup_pub.ext_payee_id_tab_type,
                                       p_ext_payee_tab    iby_disbursement_setup_pub.external_payee_tab_type) IS
  
    x_ext_payee_status_tab iby_disbursement_setup_pub.ext_payee_update_tab_type;
    x_msg_count            NUMBER := 0;
    x_msg_data             VARCHAR2(256);
    x_return_status        VARCHAR2(10);
    l_data                 VARCHAR2(1000);
    l_msg_index_out        NUMBER;
  BEGIN
    x_err_code  := 0;
    x_err_msg   := '';
    x_msg_count := 0;
  
    iby_disbursement_setup_pub.update_external_payee(p_api_version => 1.0, --
                                                     p_init_msg_list => fnd_api.g_true, --
                                                     p_ext_payee_tab => p_ext_payee_tab, --
                                                     p_ext_payee_id_tab => p_ext_payee_id_tab, --
                                                     x_return_status => x_return_status, --
                                                     x_msg_count => x_msg_count, --
                                                     x_msg_data => x_msg_data, --
                                                     x_ext_payee_status_tab => x_ext_payee_status_tab);
  
    FOR i IN 1 .. x_msg_count LOOP
      fnd_msg_pub.get(p_msg_index => i, p_data => l_data, p_encoded => fnd_api.g_false, p_msg_index_out => l_msg_index_out);
      dbms_output.put_line(l_msg_index_out || '.' || l_data);
    END LOOP;
  
    FOR j IN 0 .. x_ext_payee_status_tab.count - 1 LOOP
      dbms_output.put_line('Error Message from table type : ' || x_ext_payee_status_tab(j)
                           .payee_update_msg);
    END LOOP;
    COMMIT;
  
  EXCEPTION
    WHEN OTHERS THEN
      x_err_code := 1;
      x_err_msg  := 'Unexpected error in xxiby_bank_conv_pkg.update_payment_details_api: ' ||
                    SQLERRM;
  END update_payment_details_api;

  --------------------------------------------------------------------
  --  name:              handle_payment_details
  --  create by:         Michal Tzvik
  --  Revision:          1.0
  --  creation date:     23/08/2015
  --------------------------------------------------------------------
  --  purpose :          handle supplier/site payment details (create/update)
  --------------------------------------------------------------------
  --  ver  date          name             desc
  --  1.0  23/08/2015    Michal Tzvik     CHG0035411 - initial build
  --------------------------------------------------------------------
  PROCEDURE handle_payment_details(x_err_code        OUT NUMBER,
                                   x_err_msg         OUT VARCHAR2,
                                   p_pmt_dtl_int_rec IN OUT c_pmt_dtl%ROWTYPE) IS
    l_external_payees_rec iby_external_payees_all%ROWTYPE;
    p_ext_payee_id_tab    iby_disbursement_setup_pub.ext_payee_id_tab_type;
    p_ext_payee_tab       iby_disbursement_setup_pub.external_payee_tab_type;
    l_ext_payee_rec_api   iby_disbursement_setup_pub.external_payee_rec_type;
  
  BEGIN
    x_err_code := 0;
    x_err_msg  := '';
  
    mo_global.set_policy_context('S', p_pmt_dtl_int_rec.org_id);
  
    -- get current record of payment details 
    IF p_pmt_dtl_int_rec.data_level = 'VENDOR' THEN
      BEGIN
        SELECT iepa.*
        INTO   l_external_payees_rec
        FROM   ap_suppliers            aps,
               iby_external_payees_all iepa
        WHERE  iepa.payee_party_id = aps.party_id
        AND    iepa.org_id IS NULL
        AND    aps.vendor_id = p_pmt_dtl_int_rec.vendor_id;
      EXCEPTION
        WHEN no_data_found THEN
          NULL;
      END;
    
    ELSE
      -- data_level = 'SITE'
      BEGIN
        SELECT iepa.*
        INTO   l_external_payees_rec
        FROM   ap_suppliers            aps,
               ap_supplier_sites_all   assa,
               iby_external_payees_all iepa
        WHERE  iepa.payee_party_id = aps.party_id
        AND    iepa.supplier_site_id = assa.vendor_site_id
        AND    iepa.org_id IS NOT NULL
        AND    aps.vendor_id = p_pmt_dtl_int_rec.vendor_id
        AND    assa.party_site_id = p_pmt_dtl_int_rec.vendor_party_site_id;
      
      EXCEPTION
        WHEN no_data_found THEN
          NULL;
      END;
    
    END IF;
    p_ext_payee_id_tab(0).ext_payee_id := l_external_payees_rec.ext_payee_id;
  
    -- Check if payment details in interface are different then existing data in Oracle
    IF (p_pmt_dtl_int_rec.default_payment_method_code IS NOT NULL AND
       p_pmt_dtl_int_rec.default_payment_method_code !=
       nvl(l_external_payees_rec.default_payment_method_code, '-1')) OR
       (p_pmt_dtl_int_rec.bank_instr1_code IS NOT NULL AND
       p_pmt_dtl_int_rec.bank_instr1_code !=
       nvl(l_external_payees_rec.bank_instruction1_code, '-1')) OR
       (p_pmt_dtl_int_rec.bank_instr2_code IS NOT NULL AND
       p_pmt_dtl_int_rec.bank_instr2_code !=
       nvl(l_external_payees_rec.bank_instruction2_code, '-1')) OR
       (p_pmt_dtl_int_rec.payment_reason_code IS NOT NULL AND
       p_pmt_dtl_int_rec.payment_reason_code !=
       nvl(l_external_payees_rec.payment_reason_code, '-1')) OR
       (p_pmt_dtl_int_rec.delivery_method IS NOT NULL AND
       p_pmt_dtl_int_rec.delivery_method !=
       nvl(l_external_payees_rec.remit_advice_delivery_method, '-1')) OR
       (p_pmt_dtl_int_rec.email_address IS NOT NULL AND
       p_pmt_dtl_int_rec.email_address !=
       nvl(l_external_payees_rec.remit_advice_email, '-1')) THEN
    
      IF p_pmt_dtl_int_rec.vendor_number IS NULL THEN
        x_err_code := 1;
        x_err_msg  := 'VENDOR_NUMBER is required for updating payment details';
        RETURN;
      ELSE
        --party_id from ap_suppliers table for the vendor_id
        l_ext_payee_rec_api.payee_party_id               := p_pmt_dtl_int_rec.vendor_party_id;
        l_ext_payee_rec_api.payment_function             := 'PAYABLES_DISB';
        l_ext_payee_rec_api.exclusive_pay_flag           := 'N';
        l_ext_payee_rec_api.default_pmt_method           := p_pmt_dtl_int_rec.default_payment_method_code;
        l_ext_payee_rec_api.bank_instr1_code             := p_pmt_dtl_int_rec.bank_instr1_code;
        l_ext_payee_rec_api.bank_instr2_code             := p_pmt_dtl_int_rec.bank_instr2_code;
        l_ext_payee_rec_api.pay_reason_code              := p_pmt_dtl_int_rec.payment_reason_code;
        l_ext_payee_rec_api.remit_advice_delivery_method := p_pmt_dtl_int_rec.delivery_method;
        l_ext_payee_rec_api.remit_advice_email           := p_pmt_dtl_int_rec.email_address;
      
        IF p_pmt_dtl_int_rec.data_level = 'SITE' THEN
          IF p_pmt_dtl_int_rec.vendor_site_code IS NULL THEN
            x_err_code := 1;
            x_err_msg  := 'VENDOR_NUMBER and VENDOR_SITE_CODE are required for updating vendor site''s payment details';
            RETURN;
          END IF;
          l_ext_payee_rec_api.payer_org_id        := p_pmt_dtl_int_rec.org_id;
          l_ext_payee_rec_api.payer_org_type      := 'OPERATING_UNIT';
          l_ext_payee_rec_api.supplier_site_id    := p_pmt_dtl_int_rec.vendor_site_id;
          l_ext_payee_rec_api.payee_party_site_id := p_pmt_dtl_int_rec.vendor_party_site_id;
        
        END IF;
      
        p_ext_payee_tab(0) := l_ext_payee_rec_api;
      
        update_payment_details_api(x_err_code => x_err_code, --
                                   x_err_msg => x_err_msg, --
                                   p_ext_payee_id_tab => p_ext_payee_id_tab, --
                                   p_ext_payee_tab => p_ext_payee_tab);
        IF x_err_code = 0 THEN
          NULL;
        ELSE
          p_pmt_dtl_int_rec.xx_err_msg := x_err_msg;
        END IF;
      END IF;
    
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      x_err_code := 1;
      x_err_msg  := 'Unexpected error in xxiby_bank_conv_pkg.handle_payment_details: ' ||
                    SQLERRM;
  END handle_payment_details;
  --------------------------------------------------------------------
  --  name:              update_address_api
  --  create by:         Michal Tzvik
  --  Revision:          1.0
  --  creation date:     03/08/2015
  --------------------------------------------------------------------
  --  purpose :          update address by api 
  --------------------------------------------------------------------
  --  ver  date          name             desc
  --  1.0  13/08/2015    Michal Tzvik     CHG0035411 - initial build
  --------------------------------------------------------------------
  PROCEDURE update_address_api(x_err_code     OUT NUMBER,
                               x_err_msg      OUT VARCHAR2,
                               p_location_rec IN hz_location_v2pub.location_rec_type) IS
    p_object_version_number NUMBER;
    l_return_status         VARCHAR2(1);
    l_msg_count             NUMBER;
    l_msg_data              VARCHAR2(1000);
    l_data                  VARCHAR2(1000);
    l_msg_index_out         NUMBER;
  
  BEGIN
    x_err_code := 0;
    x_err_msg  := '';
  
    SELECT hl.object_version_number
    INTO   p_object_version_number
    FROM   hz_locations hl
    WHERE  hl.location_id = p_location_rec.location_id;
  
    hz_location_v2pub.update_location(p_init_msg_list => fnd_api.g_true, --
                                      p_location_rec => p_location_rec, --
                                      p_object_version_number => p_object_version_number, --
                                      x_return_status => l_return_status, --
                                      x_msg_count => l_msg_count, --
                                      x_msg_data => l_msg_data);
  
    IF l_return_status = fnd_api.g_ret_sts_success THEN
      COMMIT;
    ELSE
    
      FOR i IN 1 .. l_msg_count LOOP
        fnd_msg_pub.get(p_msg_index => i, p_data => l_data, p_encoded => fnd_api.g_false, p_msg_index_out => l_msg_index_out);
        x_err_msg := x_err_msg || l_data || chr(10);
      END LOOP;
      x_err_code := 1;
      x_err_msg  := 'API failure (update_location): ' || x_err_msg;
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      x_err_code := 1;
      x_err_msg  := 'Unexpected error in xxiby_bank_conv_pkg.update_address_api: ' ||
                    SQLERRM;
  END update_address_api;

  --------------------------------------------------------------------
  --  name:              create_address_api
  --  create by:         Michal Tzvik
  --  Revision:          1.0
  --  creation date:     03/08/2015
  --------------------------------------------------------------------
  --  purpose :          create address and party site by api and assign 
  --                     it to party (bank/branch)
  --------------------------------------------------------------------
  --  ver  date          name             desc
  --  1.0  13/08/2015    Michal Tzvik     CHG0035411 - initial build
  --------------------------------------------------------------------
  PROCEDURE create_address_api(x_err_code     OUT NUMBER,
                               x_err_msg      OUT VARCHAR2,
                               p_location_rec IN hz_location_v2pub.location_rec_type,
                               p_party_id     IN NUMBER,
                               x_location_id  OUT NUMBER) IS
  
    l_addr_val_status VARCHAR2(240);
    l_addr_warn_msg   VARCHAR2(1000);
    l_return_status   VARCHAR2(1);
    l_msg_count       NUMBER;
    l_msg_data        VARCHAR2(1000);
    l_data            VARCHAR2(1000);
    l_msg_index_out   NUMBER;
    l_output          VARCHAR2(1000);
    l_msg_dummy       VARCHAR2(1000);
  
    l_party_site_rec    hz_party_site_v2pub.party_site_rec_type;
    x_party_site_id     NUMBER;
    x_party_site_number VARCHAR2(2000);
  BEGIN
    x_err_code := 0;
    x_err_msg  := '';
  
    hz_location_v2pub.create_location(p_init_msg_list => 'T', --
                                      p_location_rec => p_location_rec, --
                                      p_do_addr_val => 'Y', --
                                      x_location_id => x_location_id, --
                                      x_addr_val_status => l_addr_val_status, --
                                      x_addr_warn_msg => l_addr_warn_msg, --
                                      x_return_status => l_return_status, --
                                      x_msg_count => l_msg_count, --
                                      x_msg_data => l_msg_data);
  
    IF l_return_status <> 'S' THEN
      FOR i IN 1 .. l_msg_count LOOP
        fnd_msg_pub.get(p_msg_index => i, p_data => l_data, p_encoded => fnd_api.g_false, p_msg_index_out => l_msg_index_out);
        x_err_msg := x_err_msg || l_data || chr(10);
      END LOOP;
      x_err_code := 1;
      x_err_msg  := 'API failure (create_location): ' || x_err_msg;
    
    ELSE
    
      l_party_site_rec.party_id                 := p_party_id;
      l_party_site_rec.location_id              := x_location_id;
      l_party_site_rec.identifying_address_flag := 'Y';
      l_party_site_rec.created_by_module        := c_module;
    
      hz_party_site_v2pub.create_party_site(p_init_msg_list => 'T', --
                                            p_party_site_rec => l_party_site_rec, --
                                            x_party_site_id => x_party_site_id, --
                                            x_party_site_number => x_party_site_number, --
                                            x_return_status => l_return_status, --
                                            x_msg_count => l_msg_count, --
                                            x_msg_data => l_msg_data);
    
      IF l_return_status <> 'S' THEN
        FOR i IN 1 .. l_msg_count LOOP
          fnd_msg_pub.get(p_msg_index => i, p_data => l_data, p_encoded => fnd_api.g_false, p_msg_index_out => l_msg_index_out);
          x_err_msg := x_err_msg || l_data || chr(10);
        END LOOP;
        x_err_code := 1;
        x_err_msg  := 'API failure (create_party_site): ' || x_err_msg;
      END IF;
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      x_err_code := 1;
      x_err_msg  := 'Unexpected error in xxiby_bank_conv_pkg.create_address_api: ' ||
                    SQLERRM;
  END create_address_api;

  --------------------------------------------------------------------
  --  name:              handle_branch_address
  --  create by:         Michal Tzvik
  --  Revision:          1.0
  --  creation date:     03/08/2015
  --------------------------------------------------------------------
  --  purpose :          handle external bank branch address (update/create)
  --------------------------------------------------------------------
  --  ver  date          name             desc
  --  1.0  03/08/2015    Michal Tzvik     CHG0035411 - initial build
  --------------------------------------------------------------------
  PROCEDURE handle_branch_address(x_err_code            OUT NUMBER,
                                  x_err_msg             OUT VARCHAR2,
                                  p_bank_branch_int_rec IN OUT c_branch%ROWTYPE) IS
    l_location_rec     hz_locations%ROWTYPE;
    l_location_api_rec hz_location_v2pub.location_rec_type;
  
  BEGIN
    x_err_code := 0;
    x_err_msg  := '';
  
    -- Get current address data
    IF p_bank_branch_int_rec.location_id IS NOT NULL THEN
      SELECT *
      INTO   l_location_rec
      FROM   hz_locations hl
      WHERE  hl.location_id = p_bank_branch_int_rec.location_id;
    END IF;
  
    -- Check if address details in interface are different then existing data in Oracle
    IF (p_bank_branch_int_rec.branch_address1 IS NOT NULL AND
       p_bank_branch_int_rec.branch_address1 !=
       nvl(l_location_rec.address1, '-1')) OR
       (p_bank_branch_int_rec.branch_address2 IS NOT NULL AND
       p_bank_branch_int_rec.branch_address2 !=
       nvl(l_location_rec.address2, '-1')) OR
       (p_bank_branch_int_rec.branch_address3 IS NOT NULL AND
       p_bank_branch_int_rec.branch_address3 !=
       nvl(l_location_rec.address3, '-1')) OR
       (p_bank_branch_int_rec.branch_address4 IS NOT NULL AND
       p_bank_branch_int_rec.branch_address4 !=
       nvl(l_location_rec.address4, '-1')) OR
       (p_bank_branch_int_rec.branch_country IS NOT NULL AND
       p_bank_branch_int_rec.branch_country !=
       nvl(l_location_rec.country, '-1')) OR
       (p_bank_branch_int_rec.branch_city IS NOT NULL AND
       p_bank_branch_int_rec.branch_city != nvl(l_location_rec.city, '-1')) OR
       (p_bank_branch_int_rec.branch_postal_code IS NOT NULL AND
       p_bank_branch_int_rec.branch_postal_code !=
       nvl(l_location_rec.postal_code, '-1')) OR
       (p_bank_branch_int_rec.branch_state IS NOT NULL AND
       p_bank_branch_int_rec.branch_state !=
       nvl(l_location_rec.state, '-1')) OR
       (p_bank_branch_int_rec.branch_county IS NOT NULL AND
       p_bank_branch_int_rec.branch_county !=
       nvl(l_location_rec.county, '-1')) OR
       (p_bank_branch_int_rec.branch_province IS NOT NULL AND
       p_bank_branch_int_rec.branch_province !=
       nvl(l_location_rec.province, '-1')) THEN
    
      l_location_api_rec.location_id := p_bank_branch_int_rec.location_id;
      l_location_api_rec.country     := p_bank_branch_int_rec.branch_country;
      l_location_api_rec.address1    := p_bank_branch_int_rec.branch_address1;
      l_location_api_rec.address2    := p_bank_branch_int_rec.branch_address2;
      l_location_api_rec.address3    := p_bank_branch_int_rec.branch_address3;
      l_location_api_rec.address4    := p_bank_branch_int_rec.branch_address4;
      l_location_api_rec.city        := p_bank_branch_int_rec.branch_city;
      l_location_api_rec.postal_code := p_bank_branch_int_rec.branch_postal_code;
      l_location_api_rec.state       := p_bank_branch_int_rec.branch_state;
      l_location_api_rec.county      := p_bank_branch_int_rec.branch_county;
      l_location_api_rec.province    := p_bank_branch_int_rec.branch_province;
    
      IF p_bank_branch_int_rec.location_id IS NULL THEN
      
        l_location_api_rec.created_by_module := c_module;
        create_address_api(x_err_code => x_err_code, --
                           x_err_msg => x_err_msg, --
                           p_location_rec => l_location_api_rec, --
                           p_party_id => p_bank_branch_int_rec.branch_party_id, --
                           x_location_id => p_bank_branch_int_rec.location_id); --      
      
      ELSE
        update_address_api(x_err_code => x_err_code, --
                           x_err_msg => x_err_msg, --
                           p_location_rec => l_location_api_rec);
      END IF;
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      x_err_code := 1;
      x_err_msg  := 'Unexpected error in xxiby_bank_conv_pkg.handle_branch_address: ' ||
                    SQLERRM;
  END handle_branch_address;

  --------------------------------------------------------------------
  --  name:              create_ext_bank_account_api
  --  create by:         Michal Tzvik
  --  Revision:          1.0
  --  creation date:     03/08/2015
  --------------------------------------------------------------------
  --  purpose :          create external bank account by api
  --------------------------------------------------------------------
  --  ver  date          name             desc
  --  1.0  03/08/2015    Michal Tzvik     CHG0035411 - initial build
  --------------------------------------------------------------------
  PROCEDURE create_ext_bank_account_api(x_err_code             OUT NUMBER,
                                        x_err_msg              OUT VARCHAR2,
                                        p_bank_account_int_rec IN OUT c_account%ROWTYPE) IS
  
    l_ext_bank_account_rec iby_ext_bankacct_pub.extbankacct_rec_type;
    l_response             iby_fndcpt_common_pub.result_rec_type;
  
    l_return_status VARCHAR2(20);
    l_msg_count     NUMBER;
    l_msg_data      VARCHAR2(2000);
    l_data          VARCHAR2(1000);
    l_msg_index_out NUMBER;
  
  BEGIN
    x_err_code := 0;
    x_err_msg  := '';
  
    l_ext_bank_account_rec.bank_account_id              := NULL;
    l_ext_bank_account_rec.bank_id                      := p_bank_account_int_rec.bank_party_id;
    l_ext_bank_account_rec.branch_id                    := p_bank_account_int_rec.branch_party_id;
    l_ext_bank_account_rec.acct_owner_party_id          := p_bank_account_int_rec.vendor_party_id;
    l_ext_bank_account_rec.bank_account_name            := p_bank_account_int_rec.account_name;
    l_ext_bank_account_rec.country_code                 := p_bank_account_int_rec.country;
    l_ext_bank_account_rec.bank_account_num             := p_bank_account_int_rec.account_number;
    l_ext_bank_account_rec.acct_type                    := p_bank_account_int_rec.acct_type_code;
    l_ext_bank_account_rec.description                  := p_bank_account_int_rec.account_description;
    l_ext_bank_account_rec.currency                     := p_bank_account_int_rec.currency;
    l_ext_bank_account_rec.iban                         := p_bank_account_int_rec.iban;
    l_ext_bank_account_rec.start_date                   := to_date(p_bank_account_int_rec.account_start_date, 'DD-MON-YYYY');
    l_ext_bank_account_rec.end_date                     := to_date(p_bank_account_int_rec.account_end_date, 'DD-MON-YYYY');
    l_ext_bank_account_rec.check_digits                 := p_bank_account_int_rec.check_digits;
    l_ext_bank_account_rec.multi_currency_allowed_flag  := p_bank_account_int_rec.multi_currency_allowed_flag;
    l_ext_bank_account_rec.alternate_acct_name          := p_bank_account_int_rec.alternate_acct_name;
    l_ext_bank_account_rec.short_acct_name              := p_bank_account_int_rec.short_acct_name;
    l_ext_bank_account_rec.acct_suffix                  := p_bank_account_int_rec.acct_suffix;
    l_ext_bank_account_rec.agency_location_code         := p_bank_account_int_rec.agency_location_code;
    l_ext_bank_account_rec.foreign_payment_use_flag     := p_bank_account_int_rec.foreign_payment_use_flag;
    l_ext_bank_account_rec.exchange_rate_agreement_num  := p_bank_account_int_rec.exchange_rate_agreement_num;
    l_ext_bank_account_rec.exchange_rate_agreement_type := p_bank_account_int_rec.exchange_rate_agreement_type;
    l_ext_bank_account_rec.exchange_rate                := p_bank_account_int_rec.exchange_rate;
    l_ext_bank_account_rec.payment_factor_flag          := p_bank_account_int_rec.payment_factor_flag;
    l_ext_bank_account_rec.status                       := p_bank_account_int_rec.account_status;
    l_ext_bank_account_rec.hedging_contract_reference   := p_bank_account_int_rec.hedging_contract_reference;
    l_ext_bank_account_rec.attribute_category           := p_bank_account_int_rec.account_attribute_category;
    l_ext_bank_account_rec.attribute1                   := p_bank_account_int_rec.account_attribute1;
    l_ext_bank_account_rec.attribute2                   := p_bank_account_int_rec.account_attribute2;
    l_ext_bank_account_rec.attribute3                   := p_bank_account_int_rec.account_attribute3;
    l_ext_bank_account_rec.attribute4                   := p_bank_account_int_rec.account_attribute4;
    l_ext_bank_account_rec.attribute5                   := p_bank_account_int_rec.account_attribute5;
    l_ext_bank_account_rec.attribute6                   := p_bank_account_int_rec.account_attribute6;
    l_ext_bank_account_rec.attribute7                   := p_bank_account_int_rec.account_attribute7;
    l_ext_bank_account_rec.attribute8                   := p_bank_account_int_rec.account_attribute8;
    l_ext_bank_account_rec.attribute9                   := p_bank_account_int_rec.account_attribute9;
    l_ext_bank_account_rec.attribute10                  := p_bank_account_int_rec.account_attribute10;
    l_ext_bank_account_rec.attribute11                  := p_bank_account_int_rec.account_attribute11;
    l_ext_bank_account_rec.attribute12                  := p_bank_account_int_rec.account_attribute12;
    l_ext_bank_account_rec.attribute13                  := p_bank_account_int_rec.account_attribute13;
    l_ext_bank_account_rec.attribute14                  := p_bank_account_int_rec.account_attribute14;
    l_ext_bank_account_rec.attribute15                  := p_bank_account_int_rec.account_attribute15;
    l_ext_bank_account_rec.secondary_account_reference  := p_bank_account_int_rec.secondary_account_reference;
    l_ext_bank_account_rec.contact_name                 := p_bank_account_int_rec.contact_name;
    l_ext_bank_account_rec.contact_phone                := p_bank_account_int_rec.contact_phone;
    l_ext_bank_account_rec.contact_email                := p_bank_account_int_rec.contact_email;
    l_ext_bank_account_rec.contact_fax                  := p_bank_account_int_rec.contact_fax;
    l_ext_bank_account_rec.object_version_number        := 1;
  
    iby_ext_bankacct_pub.create_ext_bank_acct(p_api_version => 1.0, --
                                              p_init_msg_list => 'T', --
                                              p_ext_bank_acct_rec => l_ext_bank_account_rec, --
                                              x_acct_id => p_bank_account_int_rec.bank_account_id, --
                                              x_return_status => l_return_status, --
                                              x_msg_count => l_msg_count, --
                                              x_msg_data => l_msg_data, --
                                              x_response => l_response);
  
    IF l_return_status = fnd_api.g_ret_sts_success THEN
      p_bank_account_int_rec.xx_account_act_status := c_sts_success;
    ELSE
      FOR i IN 1 .. l_msg_count LOOP
        fnd_msg_pub.get(p_msg_index => i, p_data => l_data, p_encoded => fnd_api.g_false, p_msg_index_out => l_msg_index_out);
        x_err_msg := x_err_msg || l_data || chr(10);
      END LOOP;
      x_err_code := 1;
      x_err_msg  := 'API failure (create_ext_bank_acct): ' || x_err_msg;
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      x_err_code := 1;
      x_err_msg  := 'Unexpected error in xxiby_bank_conv_pkg.create_ext_bank_account_api: ' ||
                    SQLERRM;
  END create_ext_bank_account_api;

  --------------------------------------------------------------------
  --  name:              create_ext_bank_branch_api
  --  create by:         Michal Tzvik
  --  Revision:          1.0
  --  creation date:     03/08/2015
  --------------------------------------------------------------------
  --  purpose :          create external bank branch by api
  --------------------------------------------------------------------
  --  ver  date          name             desc
  --  1.0  03/08/2015    Michal Tzvik     CHG0035411 - initial build
  --------------------------------------------------------------------
  PROCEDURE create_ext_bank_branch_api(x_err_code            OUT NUMBER,
                                       x_err_msg             OUT VARCHAR2,
                                       p_bank_branch_int_rec IN OUT c_branch%ROWTYPE) IS
  
    l_ext_bank_branch_rec iby_ext_bankacct_pub.extbankbranch_rec_type;
    l_response            iby_fndcpt_common_pub.result_rec_type;
  
    l_return_status VARCHAR2(20);
    l_msg_count     NUMBER;
    l_msg_data      VARCHAR2(2000);
    l_data          VARCHAR2(1000);
    l_msg_index_out NUMBER;
  
    l_location_rec hz_location_v2pub.location_rec_type;
  BEGIN
    x_err_code := 0;
    x_err_msg  := '';
  
    l_ext_bank_branch_rec.branch_party_id       := NULL;
    l_ext_bank_branch_rec.bank_party_id         := p_bank_branch_int_rec.bank_party_id;
    l_ext_bank_branch_rec.branch_name           := p_bank_branch_int_rec.branch_name;
    l_ext_bank_branch_rec.branch_number         := p_bank_branch_int_rec.branch_number;
    l_ext_bank_branch_rec.branch_type           := p_bank_branch_int_rec.branch_type;
    l_ext_bank_branch_rec.description           := p_bank_branch_int_rec.branch_description;
    l_ext_bank_branch_rec.bic                   := p_bank_branch_int_rec.bic;
    l_ext_bank_branch_rec.eft_number            := p_bank_branch_int_rec.eft_number;
    l_ext_bank_branch_rec.alternate_branch_name := p_bank_branch_int_rec.alternate_branch_name;
    l_ext_bank_branch_rec.rfc_identifier        := p_bank_branch_int_rec.rfc_identifier;
    l_ext_bank_branch_rec.attribute_category    := p_bank_branch_int_rec.branch_attribute_category;
    l_ext_bank_branch_rec.attribute1            := p_bank_branch_int_rec.branch_attribute1;
    l_ext_bank_branch_rec.attribute2            := p_bank_branch_int_rec.branch_attribute2;
    l_ext_bank_branch_rec.attribute3            := p_bank_branch_int_rec.branch_attribute3;
    l_ext_bank_branch_rec.attribute4            := p_bank_branch_int_rec.branch_attribute4;
    l_ext_bank_branch_rec.attribute5            := p_bank_branch_int_rec.branch_attribute5;
    l_ext_bank_branch_rec.attribute6            := p_bank_branch_int_rec.branch_attribute6;
    l_ext_bank_branch_rec.attribute7            := p_bank_branch_int_rec.branch_attribute7;
    l_ext_bank_branch_rec.attribute8            := p_bank_branch_int_rec.branch_attribute8;
    l_ext_bank_branch_rec.attribute9            := p_bank_branch_int_rec.branch_attribute9;
    l_ext_bank_branch_rec.attribute10           := p_bank_branch_int_rec.branch_attribute10;
    l_ext_bank_branch_rec.attribute11           := p_bank_branch_int_rec.branch_attribute11;
    l_ext_bank_branch_rec.attribute12           := p_bank_branch_int_rec.branch_attribute12;
    l_ext_bank_branch_rec.attribute13           := p_bank_branch_int_rec.branch_attribute13;
    l_ext_bank_branch_rec.attribute14           := p_bank_branch_int_rec.branch_attribute14;
    l_ext_bank_branch_rec.attribute15           := p_bank_branch_int_rec.branch_attribute15;
    l_ext_bank_branch_rec.attribute16           := p_bank_branch_int_rec.branch_attribute16;
    l_ext_bank_branch_rec.attribute17           := p_bank_branch_int_rec.branch_attribute17;
    l_ext_bank_branch_rec.attribute18           := p_bank_branch_int_rec.branch_attribute18;
    l_ext_bank_branch_rec.attribute19           := p_bank_branch_int_rec.branch_attribute19;
    l_ext_bank_branch_rec.attribute20           := p_bank_branch_int_rec.branch_attribute20;
    l_ext_bank_branch_rec.attribute21           := p_bank_branch_int_rec.branch_attribute21;
    l_ext_bank_branch_rec.attribute22           := p_bank_branch_int_rec.branch_attribute22;
    l_ext_bank_branch_rec.attribute23           := p_bank_branch_int_rec.branch_attribute23;
    l_ext_bank_branch_rec.attribute24           := p_bank_branch_int_rec.branch_attribute24;
  
    iby_ext_bankacct_pub.create_ext_bank_branch(p_api_version => 1.0, --
                                                p_init_msg_list => 'T', --
                                                p_ext_bank_branch_rec => l_ext_bank_branch_rec, --
                                                x_branch_id => /*l_ext_bank_branch_rec*/ p_bank_branch_int_rec.branch_party_id, --
                                                x_return_status => l_return_status, --
                                                x_msg_count => l_msg_count, --
                                                x_msg_data => l_msg_data, --
                                                x_response => l_response);
  
    IF l_return_status = fnd_api.g_ret_sts_success THEN
      p_bank_branch_int_rec.xx_branch_act_status := c_sts_success;
    
      -- Create/update address
      handle_branch_address(x_err_code => x_err_code, --
                            x_err_msg => x_err_msg, --
                            p_bank_branch_int_rec => p_bank_branch_int_rec);
    ELSE
      FOR i IN 1 .. l_msg_count LOOP
        fnd_msg_pub.get(p_msg_index => i, p_data => l_data, p_encoded => fnd_api.g_false, p_msg_index_out => l_msg_index_out);
        x_err_msg := x_err_msg || l_data || chr(10);
      END LOOP;
      x_err_code := 1;
      x_err_msg  := 'API failure (create_ext_bank_branch): ' || x_err_msg;
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      x_err_code := 1;
      x_err_msg  := 'Unexpected error in xxiby_bank_conv_pkg.create_ext_bank_api: ' ||
                    SQLERRM;
  END create_ext_bank_branch_api;
  --------------------------------------------------------------------
  --  name:              create_ext_bank_api
  --  create by:         Michal Tzvik
  --  Revision:          1.0
  --  creation date:     03/08/2015
  --------------------------------------------------------------------
  --  purpose :          create external bank by api
  --------------------------------------------------------------------
  --  ver  date          name             desc
  --  1.0  03/08/2015    Michal Tzvik     CHG0035411 - initial build
  --------------------------------------------------------------------
  PROCEDURE create_ext_bank_api(x_err_code     OUT NUMBER,
                                x_err_msg      OUT VARCHAR2,
                                p_bank_int_rec IN OUT c_bank%ROWTYPE) IS
  
    l_ext_bank_rec iby_ext_bankacct_pub.extbank_rec_type;
    l_response     iby_fndcpt_common_pub.result_rec_type;
  
    l_return_status VARCHAR2(20);
    l_msg_count     NUMBER;
    l_msg_data      VARCHAR2(2000);
    l_data          VARCHAR2(1000);
    l_msg_index_out NUMBER;
  
  BEGIN
    x_err_code := 0;
    x_err_msg  := '';
  
    l_ext_bank_rec.bank_id                 := NULL;
    l_ext_bank_rec.bank_name               := p_bank_int_rec.bank_name;
    l_ext_bank_rec.bank_number             := p_bank_int_rec.bank_number;
    l_ext_bank_rec.country_code            := p_bank_int_rec.country;
    l_ext_bank_rec.bank_alt_name           := p_bank_int_rec.bank_alt_name;
    l_ext_bank_rec.description             := p_bank_int_rec.bank_description;
    l_ext_bank_rec.institution_type        := p_bank_int_rec.institution_type;
    l_ext_bank_rec.tax_payer_id            := p_bank_int_rec.tax_payer_id;
    l_ext_bank_rec.tax_registration_number := p_bank_int_rec.tax_registration_number;
    l_ext_bank_rec.attribute_category      := p_bank_int_rec.bank_attribute_category;
    l_ext_bank_rec.attribute1              := p_bank_int_rec.bank_attribute1;
    l_ext_bank_rec.attribute2              := p_bank_int_rec.bank_attribute2;
    l_ext_bank_rec.attribute3              := p_bank_int_rec.bank_attribute3;
    l_ext_bank_rec.attribute4              := p_bank_int_rec.bank_attribute4;
    l_ext_bank_rec.attribute5              := p_bank_int_rec.bank_attribute5;
    l_ext_bank_rec.attribute6              := p_bank_int_rec.bank_attribute6;
    l_ext_bank_rec.attribute7              := p_bank_int_rec.bank_attribute7;
    l_ext_bank_rec.attribute8              := p_bank_int_rec.bank_attribute8;
    l_ext_bank_rec.attribute9              := p_bank_int_rec.bank_attribute9;
    l_ext_bank_rec.attribute10             := p_bank_int_rec.bank_attribute10;
    l_ext_bank_rec.attribute11             := p_bank_int_rec.bank_attribute11;
    l_ext_bank_rec.attribute12             := p_bank_int_rec.bank_attribute12;
    l_ext_bank_rec.attribute13             := p_bank_int_rec.bank_attribute13;
    l_ext_bank_rec.attribute14             := p_bank_int_rec.bank_attribute14;
    l_ext_bank_rec.attribute15             := p_bank_int_rec.bank_attribute15;
    l_ext_bank_rec.attribute16             := p_bank_int_rec.bank_attribute16;
    l_ext_bank_rec.attribute17             := p_bank_int_rec.bank_attribute17;
    l_ext_bank_rec.attribute18             := p_bank_int_rec.bank_attribute18;
    l_ext_bank_rec.attribute19             := p_bank_int_rec.bank_attribute19;
    l_ext_bank_rec.attribute20             := p_bank_int_rec.bank_attribute20;
    l_ext_bank_rec.attribute21             := p_bank_int_rec.bank_attribute21;
    l_ext_bank_rec.attribute22             := p_bank_int_rec.bank_attribute22;
    l_ext_bank_rec.attribute23             := p_bank_int_rec.bank_attribute23;
    l_ext_bank_rec.attribute24             := p_bank_int_rec.bank_attribute24;
    l_ext_bank_rec.object_version_number   := 1;
  
    iby_ext_bankacct_pub.create_ext_bank(p_api_version => 1.0, --
                                         p_init_msg_list => 'T', --
                                         p_ext_bank_rec => l_ext_bank_rec, --
                                         x_bank_id => l_ext_bank_rec.bank_id, --
                                         x_return_status => l_return_status, --
                                         x_msg_count => l_msg_count, --
                                         x_msg_data => l_msg_data, --
                                         x_response => l_response);
  
    IF l_return_status = fnd_api.g_ret_sts_success THEN
      p_bank_int_rec.bank_party_id      := l_ext_bank_rec.bank_id;
      p_bank_int_rec.xx_bank_act_status := c_sts_success;
    ELSE
      FOR i IN 1 .. l_msg_count LOOP
        fnd_msg_pub.get(p_msg_index => i, p_data => l_data, p_encoded => fnd_api.g_false, p_msg_index_out => l_msg_index_out);
        x_err_msg := x_err_msg || l_data || chr(10);
      END LOOP;
      x_err_code := 1;
      x_err_msg  := 'API failure (create_ext_bank): ' || x_err_msg;
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      x_err_code := 1;
      x_err_msg  := 'Unexpected error in xxiby_bank_conv_pkg.create_ext_bank_api: ' ||
                    SQLERRM;
  END create_ext_bank_api;

  --------------------------------------------------------------------
  --  name:              update_ext_bank_account_api
  --  create by:         Michal Tzvik
  --  Revision:          1.0
  --  creation date:     03/08/2015
  --------------------------------------------------------------------
  --  purpose :          update external bank account by api
  --------------------------------------------------------------------
  --  ver  date          name             desc
  --  1.0  03/08/2015    Michal Tzvik     CHG0035411 - initial build
  --------------------------------------------------------------------
  PROCEDURE update_ext_bank_account_api(x_err_code             OUT NUMBER,
                                        x_err_msg              OUT VARCHAR2,
                                        p_bank_account_int_rec IN OUT c_account%ROWTYPE) IS
  
    l_ext_bank_account_rec iby_ext_bankacct_pub.extbankacct_rec_type;
    l_response             iby_fndcpt_common_pub.result_rec_type;
  
    l_return_status VARCHAR2(20);
    l_msg_count     NUMBER;
    l_msg_data      VARCHAR2(2000);
    l_data          VARCHAR2(1000);
    l_msg_index_out NUMBER;
  
  BEGIN
    x_err_code                                          := 0;
    x_err_msg                                           := '';
    l_ext_bank_account_rec.bank_id                      := p_bank_account_int_rec.bank_party_id;
    l_ext_bank_account_rec.branch_id                    := p_bank_account_int_rec.branch_party_id;
    l_ext_bank_account_rec.bank_account_id              := p_bank_account_int_rec.bank_account_id;
    l_ext_bank_account_rec.acct_owner_party_id          := p_bank_account_int_rec.vendor_party_id;
    l_ext_bank_account_rec.bank_account_name            := p_bank_account_int_rec.account_name;
    l_ext_bank_account_rec.country_code                 := p_bank_account_int_rec.country;
    l_ext_bank_account_rec.bank_account_num             := p_bank_account_int_rec.account_number;
    l_ext_bank_account_rec.acct_type                    := p_bank_account_int_rec.acct_type_code;
    l_ext_bank_account_rec.description                  := p_bank_account_int_rec.account_description;
    l_ext_bank_account_rec.currency                     := p_bank_account_int_rec.currency;
    l_ext_bank_account_rec.iban                         := p_bank_account_int_rec.iban;
    l_ext_bank_account_rec.start_date                   := to_date(p_bank_account_int_rec.account_start_date, 'DD-MON-YYYY');
    l_ext_bank_account_rec.end_date                     := to_date(p_bank_account_int_rec.account_end_date, 'DD-MON-YYYY');
    l_ext_bank_account_rec.check_digits                 := p_bank_account_int_rec.check_digits;
    l_ext_bank_account_rec.multi_currency_allowed_flag  := p_bank_account_int_rec.multi_currency_allowed_flag;
    l_ext_bank_account_rec.alternate_acct_name          := p_bank_account_int_rec.alternate_acct_name;
    l_ext_bank_account_rec.short_acct_name              := p_bank_account_int_rec.short_acct_name;
    l_ext_bank_account_rec.acct_suffix                  := p_bank_account_int_rec.acct_suffix;
    l_ext_bank_account_rec.agency_location_code         := p_bank_account_int_rec.agency_location_code;
    l_ext_bank_account_rec.foreign_payment_use_flag     := p_bank_account_int_rec.foreign_payment_use_flag;
    l_ext_bank_account_rec.exchange_rate_agreement_num  := p_bank_account_int_rec.exchange_rate_agreement_num;
    l_ext_bank_account_rec.exchange_rate_agreement_type := p_bank_account_int_rec.exchange_rate_agreement_type;
    l_ext_bank_account_rec.exchange_rate                := p_bank_account_int_rec.exchange_rate;
    l_ext_bank_account_rec.payment_factor_flag          := p_bank_account_int_rec.payment_factor_flag;
    l_ext_bank_account_rec.status                       := p_bank_account_int_rec.account_status;
    l_ext_bank_account_rec.hedging_contract_reference   := p_bank_account_int_rec.hedging_contract_reference;
    l_ext_bank_account_rec.attribute_category           := p_bank_account_int_rec.account_attribute_category;
    l_ext_bank_account_rec.attribute1                   := p_bank_account_int_rec.account_attribute1;
    l_ext_bank_account_rec.attribute2                   := p_bank_account_int_rec.account_attribute2;
    l_ext_bank_account_rec.attribute3                   := p_bank_account_int_rec.account_attribute3;
    l_ext_bank_account_rec.attribute4                   := p_bank_account_int_rec.account_attribute4;
    l_ext_bank_account_rec.attribute5                   := p_bank_account_int_rec.account_attribute5;
    l_ext_bank_account_rec.attribute6                   := p_bank_account_int_rec.account_attribute6;
    l_ext_bank_account_rec.attribute7                   := p_bank_account_int_rec.account_attribute7;
    l_ext_bank_account_rec.attribute8                   := p_bank_account_int_rec.account_attribute8;
    l_ext_bank_account_rec.attribute9                   := p_bank_account_int_rec.account_attribute9;
    l_ext_bank_account_rec.attribute10                  := p_bank_account_int_rec.account_attribute10;
    l_ext_bank_account_rec.attribute11                  := p_bank_account_int_rec.account_attribute11;
    l_ext_bank_account_rec.attribute12                  := p_bank_account_int_rec.account_attribute12;
    l_ext_bank_account_rec.attribute13                  := p_bank_account_int_rec.account_attribute13;
    l_ext_bank_account_rec.attribute14                  := p_bank_account_int_rec.account_attribute14;
    l_ext_bank_account_rec.attribute15                  := p_bank_account_int_rec.account_attribute15;
    l_ext_bank_account_rec.secondary_account_reference  := p_bank_account_int_rec.secondary_account_reference;
    l_ext_bank_account_rec.contact_name                 := p_bank_account_int_rec.contact_name;
    l_ext_bank_account_rec.contact_phone                := p_bank_account_int_rec.contact_phone;
    l_ext_bank_account_rec.contact_email                := p_bank_account_int_rec.contact_email;
    l_ext_bank_account_rec.contact_fax                  := p_bank_account_int_rec.contact_fax;
  
    SELECT MAX(ieba.object_version_number)
    INTO   l_ext_bank_account_rec.object_version_number
    FROM   iby_ext_bank_accounts ieba
    WHERE  ieba.ext_bank_account_id = l_ext_bank_account_rec.
     bank_account_id;
  
    iby_ext_bankacct_pub.update_ext_bank_acct(p_api_version => 1.0, --
                                              p_init_msg_list => 'T', --
                                              p_ext_bank_acct_rec => l_ext_bank_account_rec, --
                                              x_return_status => l_return_status, --
                                              x_msg_count => l_msg_count, --
                                              x_msg_data => l_msg_data, --
                                              x_response => l_response);
  
    IF l_return_status = fnd_api.g_ret_sts_success THEN
      p_bank_account_int_rec.xx_account_act_status := c_sts_success;
    ELSE
      FOR i IN 1 .. l_msg_count LOOP
        fnd_msg_pub.get(p_msg_index => i, p_data => l_data, p_encoded => fnd_api.g_false, p_msg_index_out => l_msg_index_out);
        x_err_msg := x_err_msg || l_data || chr(10);
      END LOOP;
      x_err_code := 1;
      x_err_msg  := 'API failure (update_ext_bank_acct): ' || x_err_msg;
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      x_err_code := 1;
      x_err_msg  := 'Unexpected error in xxiby_bank_conv_pkg.update_ext_bank_account_api: ' ||
                    SQLERRM;
  END update_ext_bank_account_api;

  --------------------------------------------------------------------
  --  name:              update_ext_bank_branch_api
  --  create by:         Michal Tzvik
  --  Revision:          1.0
  --  creation date:     03/08/2015
  --------------------------------------------------------------------
  --  purpose :          update external bank branch by api
  --------------------------------------------------------------------
  --  ver  date          name             desc
  --  1.0  03/08/2015    Michal Tzvik     CHG0035411 - initial build
  --------------------------------------------------------------------
  PROCEDURE update_ext_bank_branch_api(x_err_code            OUT NUMBER,
                                       x_err_msg             OUT VARCHAR2,
                                       p_bank_branch_int_rec IN OUT c_branch%ROWTYPE) IS
  
    l_ext_bank_branch_rec iby_ext_bankacct_pub.extbankbranch_rec_type;
    l_response            iby_fndcpt_common_pub.result_rec_type;
    l_branch_rec          ce_bank_branches_v%ROWTYPE;
  
    l_return_status VARCHAR2(20);
    l_msg_count     NUMBER;
    l_msg_data      VARCHAR2(2000);
    l_data          VARCHAR2(1000);
    l_msg_index_out NUMBER;
  
  BEGIN
    x_err_code := 0;
    x_err_msg  := '';
  
    SELECT *
    INTO   l_branch_rec
    FROM   ce_bank_branches_v cbbv
    WHERE  cbbv.branch_party_id = p_bank_branch_int_rec.branch_party_id;
  
    -- Check if branch details in interface are different then existing data in Oracle
    IF (p_bank_branch_int_rec.branch_type IS NOT NULL AND
       p_bank_branch_int_rec.branch_type !=
       nvl(l_branch_rec.bank_branch_type, '-1')) OR
       (p_bank_branch_int_rec.branch_description IS NOT NULL AND
       p_bank_branch_int_rec.branch_description !=
       nvl(l_branch_rec.description, '-1')) OR (p_bank_branch_int_rec.bic IS NOT NULL -- AND
       -- p_bank_branch_int_rec.bic != nvl(l_branch_rec., '-1')*/
       ) OR (p_bank_branch_int_rec.eft_number IS NOT NULL
       -- p_bank_branch_int_rec.eft_number !=
       -- nvl(l_branch_rec.eft_number, '-1')
       ) OR (p_bank_branch_int_rec.alternate_branch_name IS NOT NULL AND
       p_bank_branch_int_rec.alternate_branch_name !=
       nvl(l_branch_rec.bank_branch_name_alt, '-1')) THEN
    
      l_ext_bank_branch_rec.bank_party_id         := p_bank_branch_int_rec.bank_party_id;
      l_ext_bank_branch_rec.branch_party_id       := p_bank_branch_int_rec.branch_party_id;
      l_ext_bank_branch_rec.branch_name           := p_bank_branch_int_rec.branch_name;
      l_ext_bank_branch_rec.branch_number         := p_bank_branch_int_rec.branch_number;
      l_ext_bank_branch_rec.branch_type           := p_bank_branch_int_rec.branch_type;
      l_ext_bank_branch_rec.description           := p_bank_branch_int_rec.branch_description;
      l_ext_bank_branch_rec.bic                   := p_bank_branch_int_rec.bic;
      l_ext_bank_branch_rec.eft_number            := p_bank_branch_int_rec.eft_number;
      l_ext_bank_branch_rec.alternate_branch_name := p_bank_branch_int_rec.alternate_branch_name;
      l_ext_bank_branch_rec.rfc_identifier        := p_bank_branch_int_rec.rfc_identifier;
      l_ext_bank_branch_rec.attribute_category    := p_bank_branch_int_rec.branch_attribute_category;
      l_ext_bank_branch_rec.attribute1            := p_bank_branch_int_rec.branch_attribute1;
      l_ext_bank_branch_rec.attribute2            := p_bank_branch_int_rec.branch_attribute2;
      l_ext_bank_branch_rec.attribute3            := p_bank_branch_int_rec.branch_attribute3;
      l_ext_bank_branch_rec.attribute4            := p_bank_branch_int_rec.branch_attribute4;
      l_ext_bank_branch_rec.attribute5            := p_bank_branch_int_rec.branch_attribute5;
      l_ext_bank_branch_rec.attribute6            := p_bank_branch_int_rec.branch_attribute6;
      l_ext_bank_branch_rec.attribute7            := p_bank_branch_int_rec.branch_attribute7;
      l_ext_bank_branch_rec.attribute8            := p_bank_branch_int_rec.branch_attribute8;
      l_ext_bank_branch_rec.attribute9            := p_bank_branch_int_rec.branch_attribute9;
      l_ext_bank_branch_rec.attribute10           := p_bank_branch_int_rec.branch_attribute10;
      l_ext_bank_branch_rec.attribute11           := p_bank_branch_int_rec.branch_attribute11;
      l_ext_bank_branch_rec.attribute12           := p_bank_branch_int_rec.branch_attribute12;
      l_ext_bank_branch_rec.attribute13           := p_bank_branch_int_rec.branch_attribute13;
      l_ext_bank_branch_rec.attribute14           := p_bank_branch_int_rec.branch_attribute14;
      l_ext_bank_branch_rec.attribute15           := p_bank_branch_int_rec.branch_attribute15;
      l_ext_bank_branch_rec.attribute16           := p_bank_branch_int_rec.branch_attribute16;
      l_ext_bank_branch_rec.attribute17           := p_bank_branch_int_rec.branch_attribute17;
      l_ext_bank_branch_rec.attribute18           := p_bank_branch_int_rec.branch_attribute18;
      l_ext_bank_branch_rec.attribute19           := p_bank_branch_int_rec.branch_attribute19;
      l_ext_bank_branch_rec.attribute20           := p_bank_branch_int_rec.branch_attribute20;
      l_ext_bank_branch_rec.attribute21           := p_bank_branch_int_rec.branch_attribute21;
      l_ext_bank_branch_rec.attribute22           := p_bank_branch_int_rec.branch_attribute22;
      l_ext_bank_branch_rec.attribute23           := p_bank_branch_int_rec.branch_attribute23;
      l_ext_bank_branch_rec.attribute24           := p_bank_branch_int_rec.branch_attribute24;
    
      SELECT MAX(object_version_number)
      INTO   l_ext_bank_branch_rec.bch_object_version_number
      FROM   hz_parties
      WHERE  party_id = p_bank_branch_int_rec.branch_party_id;
    
      SELECT MAX(object_version_number)
      INTO   l_ext_bank_branch_rec.typ_object_version_number
      FROM   hz_organization_profiles
      WHERE  party_id = p_bank_branch_int_rec.branch_party_id;
    
      SELECT MAX(object_version_number)
      INTO   l_ext_bank_branch_rec.eft_object_version_number
      FROM   hz_contact_points
      WHERE  contact_point_type = 'EFT'
      AND    owner_table_name = 'HZ_PARTIES'
      AND    owner_table_id = p_bank_branch_int_rec.branch_party_id;
    
      iby_ext_bankacct_pub.update_ext_bank_branch(p_api_version => 1.0, --
                                                  p_init_msg_list => 'T', --
                                                  p_ext_bank_branch_rec => l_ext_bank_branch_rec, --
                                                  x_return_status => l_return_status, --
                                                  x_msg_count => l_msg_count, --
                                                  x_msg_data => l_msg_data, --
                                                  x_response => l_response);
    
      IF l_return_status <> fnd_api.g_ret_sts_success THEN
        FOR i IN 1 .. l_msg_count LOOP
          fnd_msg_pub.get(p_msg_index => i, p_data => l_data, p_encoded => fnd_api.g_false, p_msg_index_out => l_msg_index_out);
          x_err_msg := x_err_msg || l_data || chr(10);
        END LOOP;
        x_err_code := 1;
        x_err_msg  := 'API failure (update_ext_bank_branch): ' || x_err_msg;
      END IF;
    END IF;
  
    IF x_err_code = 0 THEN
      -- Create/update address
      handle_branch_address(x_err_code => x_err_code, --
                            x_err_msg => x_err_msg, --
                            p_bank_branch_int_rec => p_bank_branch_int_rec);
    END IF;
  
    IF x_err_code = 0 THEN
      p_bank_branch_int_rec.xx_branch_act_status := c_sts_success;
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      x_err_code := 1;
      x_err_msg  := 'Unexpected error in xxiby_bank_conv_pkg.create_ext_bank_api: ' ||
                    SQLERRM;
  END update_ext_bank_branch_api;

  --------------------------------------------------------------------
  --  name:              update_ext_bank_api
  --  create by:         Michal Tzvik
  --  Revision:          1.0
  --  creation date:     03/08/2015
  --------------------------------------------------------------------
  --  purpose :          update external bank by api
  --------------------------------------------------------------------
  --  ver  date          name             desc
  --  1.0  03/08/2015    Michal Tzvik     CHG0035411 - initial build
  --------------------------------------------------------------------
  PROCEDURE update_ext_bank_api(x_err_code     OUT NUMBER,
                                x_err_msg      OUT VARCHAR2,
                                p_bank_int_rec IN OUT c_bank%ROWTYPE) IS
  
    l_ext_bank_rec iby_ext_bankacct_pub.extbank_rec_type;
    l_response     iby_fndcpt_common_pub.result_rec_type;
  
    l_return_status VARCHAR2(20);
    l_msg_count     NUMBER;
    l_msg_data      VARCHAR2(2000);
    l_data          VARCHAR2(1000);
    l_msg_index_out NUMBER;
  
  BEGIN
    x_err_code := 0;
    x_err_msg  := '';
  
    l_ext_bank_rec.bank_id                 := p_bank_int_rec.bank_party_id;
    l_ext_bank_rec.bank_name               := p_bank_int_rec.bank_name;
    l_ext_bank_rec.bank_number             := p_bank_int_rec.bank_number;
    l_ext_bank_rec.country_code            := p_bank_int_rec.country;
    l_ext_bank_rec.bank_alt_name           := p_bank_int_rec.bank_alt_name;
    l_ext_bank_rec.description             := p_bank_int_rec.bank_description;
    l_ext_bank_rec.institution_type        := p_bank_int_rec.institution_type;
    l_ext_bank_rec.tax_payer_id            := p_bank_int_rec.tax_payer_id;
    l_ext_bank_rec.tax_registration_number := p_bank_int_rec.tax_registration_number;
    l_ext_bank_rec.attribute_category      := p_bank_int_rec.bank_attribute_category;
    l_ext_bank_rec.attribute1              := p_bank_int_rec.bank_attribute1;
    l_ext_bank_rec.attribute2              := p_bank_int_rec.bank_attribute2;
    l_ext_bank_rec.attribute3              := p_bank_int_rec.bank_attribute3;
    l_ext_bank_rec.attribute4              := p_bank_int_rec.bank_attribute4;
    l_ext_bank_rec.attribute5              := p_bank_int_rec.bank_attribute5;
    l_ext_bank_rec.attribute6              := p_bank_int_rec.bank_attribute6;
    l_ext_bank_rec.attribute7              := p_bank_int_rec.bank_attribute7;
    l_ext_bank_rec.attribute8              := p_bank_int_rec.bank_attribute8;
    l_ext_bank_rec.attribute9              := p_bank_int_rec.bank_attribute9;
    l_ext_bank_rec.attribute10             := p_bank_int_rec.bank_attribute10;
    l_ext_bank_rec.attribute11             := p_bank_int_rec.bank_attribute11;
    l_ext_bank_rec.attribute12             := p_bank_int_rec.bank_attribute12;
    l_ext_bank_rec.attribute13             := p_bank_int_rec.bank_attribute13;
    l_ext_bank_rec.attribute14             := p_bank_int_rec.bank_attribute14;
    l_ext_bank_rec.attribute15             := p_bank_int_rec.bank_attribute15;
    l_ext_bank_rec.attribute16             := p_bank_int_rec.bank_attribute16;
    l_ext_bank_rec.attribute17             := p_bank_int_rec.bank_attribute17;
    l_ext_bank_rec.attribute18             := p_bank_int_rec.bank_attribute18;
    l_ext_bank_rec.attribute19             := p_bank_int_rec.bank_attribute19;
    l_ext_bank_rec.attribute20             := p_bank_int_rec.bank_attribute20;
    l_ext_bank_rec.attribute21             := p_bank_int_rec.bank_attribute21;
    l_ext_bank_rec.attribute22             := p_bank_int_rec.bank_attribute22;
    l_ext_bank_rec.attribute23             := p_bank_int_rec.bank_attribute23;
    l_ext_bank_rec.attribute24             := p_bank_int_rec.bank_attribute24;
  
    SELECT MAX(hp.object_version_number)
    INTO   l_ext_bank_rec.object_version_number
    FROM   hz_parties hp
    WHERE  hp.party_id = p_bank_int_rec.bank_party_id;
  
    iby_ext_bankacct_pub.update_ext_bank(p_api_version => 1.0, --
                                         p_init_msg_list => 'T', --
                                         p_ext_bank_rec => l_ext_bank_rec, --
                                         x_return_status => l_return_status, --
                                         x_msg_count => l_msg_count, --
                                         x_msg_data => l_msg_data, --
                                         x_response => l_response);
  
    IF l_return_status = fnd_api.g_ret_sts_success THEN
      p_bank_int_rec.xx_bank_act_status := c_sts_success;
    ELSE
      FOR i IN 1 .. l_msg_count LOOP
        fnd_msg_pub.get(p_msg_index => i, p_data => l_data, p_encoded => fnd_api.g_false, p_msg_index_out => l_msg_index_out);
        x_err_msg := x_err_msg || l_data || chr(10);
      END LOOP;
      x_err_code := 1;
      x_err_msg  := 'API failure (update_ext_bank): ' || x_err_msg;
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      x_err_code := 1;
      x_err_msg  := 'Unexpected error in xxiby_bank_conv_pkg.update_ext_bank_api: ' ||
                    SQLERRM;
  END update_ext_bank_api;

  --------------------------------------------------------------------
  --  name:              process_ext_bank_account
  --  create by:         Michal Tzvik
  --  Revision:          1.0
  --  creation date:     27/08/2015
  --------------------------------------------------------------------
  --  purpose :          main procedure for processing vendor/site payment details
  --------------------------------------------------------------------
  --  ver  date          name             desc
  --  1.0  27/08/2015    Michal Tzvik     CHG0035411 - initial build
  --------------------------------------------------------------------
  PROCEDURE process_payment_details(x_err_code OUT NUMBER,
                                    x_err_msg  OUT VARCHAR2) IS
    l_err_code NUMBER;
    l_err_msg  VARCHAR2(2000);
    data_error EXCEPTION;
  
    l_pmt_dtl_rec c_pmt_dtl%ROWTYPE;
  BEGIN
    x_err_code := 0;
    x_err_msg  := '';
  
    --------------- Vendor Level ------------------
    FOR r_pmt_dtl IN c_pmt_dtl('VENDOR') LOOP
      BEGIN
        dbms_output.put_line('payment details vendor');
        l_pmt_dtl_rec := r_pmt_dtl;
      
        -- Run validations
        validate_payment_details(l_err_code, l_err_msg, l_pmt_dtl_rec);
      
        IF l_err_code != 0 THEN
          RAISE data_error;
        END IF;
        l_pmt_dtl_rec.xx_pmt_dtl_vendor_status := c_sts_valid;
      
        -- Run API
        IF g_simulation_mode = 'N' THEN
          handle_payment_details(x_err_code => l_err_code, --
                                 x_err_msg => l_err_msg, --
                                 p_pmt_dtl_int_rec => l_pmt_dtl_rec);
        
          IF l_err_code != 0 THEN
            RAISE data_error;
          END IF;
        
          l_pmt_dtl_rec.xx_pmt_dtl_vendor_status := c_sts_success;
        END IF;
      
        -- Update interface record
        update_pmt_dtl_int_rec(l_pmt_dtl_rec);
      
      EXCEPTION
        WHEN OTHERS THEN
          x_err_code                             := 1;
          x_err_msg                              := 'Failed to process payment details. ' ||
                                                    x_err_msg;
          l_pmt_dtl_rec.xx_err_msg               := nvl(l_err_msg, SQLERRM);
          l_pmt_dtl_rec.xx_pmt_dtl_vendor_status := c_sts_error;
          update_pmt_dtl_int_rec(l_pmt_dtl_rec);
      END;
    END LOOP;
  
    --------------- Site Level ------------------
    FOR r_pmt_dtl IN c_pmt_dtl('SITE') LOOP
      BEGIN
        l_pmt_dtl_rec := r_pmt_dtl;
      
        -- Run validations
        validate_payment_details(l_err_code, l_err_msg, l_pmt_dtl_rec);
      
        IF l_err_code != 0 THEN
          RAISE data_error;
        END IF;
        l_pmt_dtl_rec.xx_pmt_dtl_site_status := c_sts_valid;
      
        -- Run API
        IF g_simulation_mode = 'N' THEN
          handle_payment_details(x_err_code => l_err_code, --
                                 x_err_msg => l_err_msg, --
                                 p_pmt_dtl_int_rec => l_pmt_dtl_rec);
          dbms_output.put_line('handle payment details site');
        
          IF l_err_code != 0 THEN
            RAISE data_error;
          END IF;
        
          l_pmt_dtl_rec.xx_pmt_dtl_site_status := c_sts_success;
        END IF;
      
        -- Update interface record
        update_pmt_dtl_int_rec(l_pmt_dtl_rec);
      
      EXCEPTION
        WHEN OTHERS THEN
          x_err_code                           := 1;
          x_err_msg                            := 'Failed to process payment details. ' ||
                                                  x_err_msg;
          l_pmt_dtl_rec.xx_err_msg             := nvl(l_err_msg, SQLERRM);
          l_pmt_dtl_rec.xx_pmt_dtl_site_status := c_sts_error;
          update_pmt_dtl_int_rec(l_pmt_dtl_rec);
      END;
    END LOOP;
  
  EXCEPTION
    WHEN data_error THEN
      x_err_code := 1;
      x_err_msg  := 'Failed to process data (XXIBY_BANK_CONV_PKG.process_payment_details):' ||
                    l_err_msg;
    WHEN OTHERS THEN
      x_err_code := 1;
      x_err_msg  := 'Unexpected error in XXIBY_BANK_CONV_PKG.process_payment_details:' ||
                    SQLERRM;
  END process_payment_details;

  --------------------------------------------------------------------
  --  name:              process_ext_bank_account
  --  create by:         Michal Tzvik
  --  Revision:          1.0
  --  creation date:     03/08/2015
  --------------------------------------------------------------------
  --  purpose :          main procedure for processing external bank account
  --------------------------------------------------------------------
  --  ver  date          name             desc
  --  1.0  03/08/2015    Michal Tzvik     CHG0035411 - initial build
  --------------------------------------------------------------------
  PROCEDURE process_ext_bank_account(x_err_code OUT NUMBER,
                                     x_err_msg  OUT VARCHAR2) IS
  
    l_err_code NUMBER;
    l_err_msg  VARCHAR2(2000);
    data_error EXCEPTION;
  
    l_account_rec c_account%ROWTYPE;
  BEGIN
    x_err_code := 0;
    x_err_msg  := '';
  
    FOR r_account IN c_account LOOP
      BEGIN
        l_account_rec := r_account;
      
        l_err_code := 0;
        l_err_msg  := '';
      
        -- Run validations
        validate_ext_bank_account(l_err_code, l_err_msg, l_account_rec);
      
        IF l_err_code != 0 THEN
          l_account_rec.xx_account_act_status := c_sts_error;
          RAISE data_error;
        END IF;
        l_account_rec.xx_account_act_status := c_sts_valid;
      
        -- Run API
        IF g_simulation_mode = 'N' THEN
          IF l_account_rec.xx_account_action = c_action_create THEN
            create_ext_bank_account_api(x_err_code => l_err_code, x_err_msg => l_err_msg, p_bank_account_int_rec => l_account_rec);
          
          ELSIF l_account_rec.xx_account_action = c_action_update THEN
            update_ext_bank_account_api(x_err_code => l_err_code, x_err_msg => l_err_msg, p_bank_account_int_rec => l_account_rec);
          
          END IF;
        
          IF l_err_code != 0 THEN
            l_account_rec.xx_account_act_status := c_sts_error;
            RAISE data_error;
          END IF;
        
          assign_account_to_owner_api(x_err_code => l_err_code, x_err_msg => l_err_msg, p_bank_account_int_rec => l_account_rec);
          IF l_err_code != 0 THEN
            RAISE data_error;
          END IF;
          l_account_rec.xx_account_act_status := c_sts_success;
        END IF;
      
        -- Update interface record
        update_bank_account_int_rec(l_account_rec);
      
      EXCEPTION
        WHEN OTHERS THEN
          x_err_code                          := 1;
          x_err_msg                           := 'Failed to process bank account records. ' ||
                                                 x_err_msg;
          l_account_rec.xx_err_msg            := nvl(l_err_msg, SQLERRM);
          l_account_rec.xx_account_act_status := c_sts_error;
          update_bank_account_int_rec(l_account_rec);
      END;
    END LOOP;
  
    COMMIT;
  
  EXCEPTION
    WHEN OTHERS THEN
      x_err_code := 1;
      x_err_msg  := 'Unexpected error in XXIBY_BANK_CONV_PKG.process_ext_bank_account:' ||
                    SQLERRM;
  END process_ext_bank_account;

  --------------------------------------------------------------------
  --  name:              process_ext_bank_branch
  --  create by:         Michal Tzvik
  --  Revision:          1.0
  --  creation date:     03/08/2015
  --------------------------------------------------------------------
  --  purpose :          main procedure for processing external bank branch
  --------------------------------------------------------------------
  --  ver  date          name             desc
  --  1.0  03/08/2015    Michal Tzvik     CHG0035411 - initial build
  --------------------------------------------------------------------
  PROCEDURE process_ext_bank_branch(x_err_code OUT NUMBER,
                                    x_err_msg  OUT VARCHAR2) IS
  
    l_err_code NUMBER;
    l_err_msg  VARCHAR2(2000);
    data_error EXCEPTION;
    l_branch_rec c_branch%ROWTYPE;
  BEGIN
    x_err_code := 0;
    x_err_msg  := '';
  
    FOR r_branch IN c_branch LOOP
      BEGIN
        l_err_code   := 0;
        l_err_msg    := '';
        l_branch_rec := r_branch;
      
        -- Run validations
        validate_ext_bank_branch(l_err_code, l_err_msg, l_branch_rec);
      
        IF l_err_code != 0 THEN
          RAISE data_error;
        END IF;
      
        l_branch_rec.xx_branch_act_status := c_sts_valid;
      
        -- Run API
        IF g_simulation_mode = 'N' THEN
          IF l_branch_rec.xx_branch_action = c_action_create THEN
            create_ext_bank_branch_api(x_err_code => l_err_code, x_err_msg => l_err_msg, p_bank_branch_int_rec => l_branch_rec);
          
          ELSIF l_branch_rec.xx_branch_action = c_action_update THEN
            update_ext_bank_branch_api(x_err_code => l_err_code, x_err_msg => l_err_msg, p_bank_branch_int_rec => l_branch_rec);
          
          END IF;
        
          IF l_err_code != 0 THEN
            RAISE data_error;
          END IF;
          l_branch_rec.xx_branch_act_status := c_sts_success;
        
        END IF;
      
        --Update interface record
        update_bank_branch_int_rec(l_branch_rec);
      EXCEPTION
        WHEN OTHERS THEN
          x_err_code                        := 1;
          x_err_msg                         := 'Failed to process bank branch records';
          l_branch_rec.xx_branch_act_status := c_sts_error;
          l_branch_rec.xx_err_msg           := nvl(l_err_msg, SQLERRM);
          update_bank_branch_int_rec(l_branch_rec);
      END;
    END LOOP;
  
    COMMIT;
  
  EXCEPTION
    WHEN OTHERS THEN
      x_err_code := 1;
      x_err_msg  := 'Unexpected error in XXIBY_BANK_CONV_PKG.process_ext_bank_account:' ||
                    SQLERRM;
  END process_ext_bank_branch;
  --------------------------------------------------------------------
  --  name:              process_ext_bank
  --  create by:         Michal Tzvik
  --  Revision:          1.0
  --  creation date:     03/08/2015
  --------------------------------------------------------------------
  --  purpose :          main procedure for processing external bank 
  --------------------------------------------------------------------
  --  ver  date          name             desc
  --  1.0  03/08/2015    Michal Tzvik     CHG0035411 - initial build
  --------------------------------------------------------------------
  PROCEDURE process_ext_bank(x_err_code OUT NUMBER,
                             x_err_msg  OUT VARCHAR2) IS
  
    l_err_code NUMBER;
    l_err_msg  VARCHAR2(2000);
    data_error EXCEPTION;
    l_bank_rec c_bank%ROWTYPE;
  BEGIN
    x_err_code := 0;
    x_err_msg  := '';
  
    FOR r_bank IN c_bank LOOP
      BEGIN
        l_err_code := 0;
        l_err_msg  := '';
      
        l_bank_rec := r_bank;
      
        -- Run validations
        validate_ext_bank(l_err_code, l_err_msg, l_bank_rec);
      
        IF l_err_code != 0 THEN
          RAISE data_error;
        END IF;
      
        l_bank_rec.xx_bank_act_status := c_sts_valid;
      
        -- Run API
        IF g_simulation_mode = 'N' THEN
          IF l_bank_rec.xx_bank_action = c_action_create THEN
            create_ext_bank_api(x_err_code => l_err_code, x_err_msg => l_err_msg, p_bank_int_rec => l_bank_rec);
          
          ELSIF l_bank_rec.xx_bank_action = c_action_update THEN
            update_ext_bank_api(x_err_code => l_err_code, x_err_msg => l_err_msg, p_bank_int_rec => l_bank_rec);
          
          END IF;
        
          IF l_err_code != 0 THEN
            RAISE data_error;
          END IF;
          l_bank_rec.xx_bank_act_status := c_sts_success;
        END IF;
      
        -- Update interface record
        update_bank_int_rec(l_bank_rec);
      EXCEPTION
        WHEN OTHERS THEN
          x_err_code                    := 1;
          x_err_msg                     := 'Failed to process bank record';
          l_bank_rec.xx_bank_act_status := c_sts_error;
          l_bank_rec.xx_err_msg         := nvl(l_err_msg, SQLERRM);
          update_bank_int_rec(l_bank_rec);
      END;
    END LOOP;
  
    COMMIT;
  
  EXCEPTION
    WHEN OTHERS THEN
      x_err_code                    := 1;
      x_err_msg                     := 'Unexpected error in XXIBY_BANK_CONV_PKG.process_ext_bank_account:' ||
                                       SQLERRM;
      l_bank_rec.xx_bank_act_status := c_sts_error;
      l_bank_rec.xx_err_msg         := x_err_msg;
      update_bank_int_rec(l_bank_rec);
  END process_ext_bank;

  --------------------------------------------------------------------
  --  name:              main
  --  create by:         Michal Tzvik
  --  Revision:          1.0
  --  creation date:     24/08/2015
  --------------------------------------------------------------------
  --  purpose :   main procedure. Used by concurrent executable 
  --              XXIBY_BANK_CONV_INTERFACE
  --
  --  Logic:     1. upload data from csv to interface table 
  --             2. process data
  --             3. set final status to records in interface table
  --             4. generate output report
  --
  --  parameters:
  --       x_err_code        OUT : 0- success, 1-warning, 2-error
  --       x_err_msg         OUT : error message
  --       p_table_name      IN  : Table name for uploading csv file: XXIBY_BANK_CONV_INTERFACE
  --       p_template_name   IN  : Template name for uploading csv file: JPMC
  --       p_file_name       IN  : File name for uploading csv file
  --       p_directory       IN  : Directory path for uploading csv file 
  --       p_simulation_mode IN  : If Y then run validations without API

  --------------------------------------------------------------------
  --  ver  date          name             desc
  --  1.0  24/08/2015    Michal Tzvik     CHG0035411 - initial build
  --------------------------------------------------------------------
  PROCEDURE main(errbuf            OUT VARCHAR2,
                 retcode           OUT VARCHAR2,
                 p_table_name      IN VARCHAR2, -- XXIBY_BANK_CONV_INTERFACE
                 p_template_name   IN VARCHAR2, -- JPMC
                 p_file_name       IN VARCHAR2,
                 p_directory       IN VARCHAR2,
                 p_simulation_mode IN VARCHAR2 -- Y/N
                 ) IS
  
    l_err_code NUMBER;
    l_err_msg  VARCHAR2(2000);
    data_error      EXCEPTION;
    load_file_error EXCEPTION;
  BEGIN
    retcode := '0';
    errbuf  := '';
  
    g_batch_id := fnd_global.conc_request_id;
  
    g_simulation_mode := p_simulation_mode;
  
    fnd_file.put_line(fnd_file.log, '====================================');
    fnd_file.put_line(fnd_file.log, 'Parameters ');
    fnd_file.put_line(fnd_file.log, '----------');
    fnd_file.put_line(fnd_file.log, 'p_table_name:      ' || p_table_name);
    fnd_file.put_line(fnd_file.log, 'p_template_name:   ' ||
                       p_template_name);
    fnd_file.put_line(fnd_file.log, 'p_file_name:       ' || p_file_name);
    fnd_file.put_line(fnd_file.log, 'p_directory:       ' || p_directory);
    fnd_file.put_line(fnd_file.log, 'p_simulation_mode: ' ||
                       p_simulation_mode);
    fnd_file.put_line(fnd_file.log, '====================================');
    fnd_file.put_line(fnd_file.log, '');
    fnd_file.put_line(fnd_file.log, '');
  
    -- 1. upload data from csv to interface table 
    xxobjt_table_loader_util_pkg.load_file(errbuf => l_err_msg, --
                                           retcode => l_err_code, --
                                           p_table_name => p_table_name, --
                                           p_template_name => p_template_name, --
                                           p_file_name => p_file_name, --
                                           p_directory => p_directory, --
                                           p_expected_num_of_rows => NULL);
  
    IF l_err_code != 0 THEN
      RAISE load_file_error;
    END IF;
  
    -- 2. process data
    process_ext_bank(l_err_code, l_err_msg);
    IF l_err_code != 0 THEN
      retcode := '1';
      errbuf  := l_err_msg;
    END IF;
  
    process_ext_bank_branch(l_err_code, l_err_msg);
    IF l_err_code != 0 THEN
      retcode := '1';
      errbuf  := l_err_msg;
    END IF;
  
    process_ext_bank_account(l_err_code, l_err_msg);
    IF l_err_code != 0 THEN
      retcode := '1';
      errbuf  := l_err_msg;
    END IF;
  
    process_payment_details(l_err_code, l_err_msg);
    IF l_err_code != 0 THEN
      retcode := '1';
      errbuf  := l_err_msg;
    END IF;
  
    -- 3. set final status to records in interface table
    set_interface_final_status;
  
    -- 4. generate output report
    report_data(l_err_code, l_err_msg);
    IF l_err_code != 0 THEN
      retcode := 1;
    END IF;
  
  EXCEPTION
    WHEN load_file_error THEN
      IF l_err_msg LIKE '%ORA-29400%' THEN
        fnd_file.put_line(fnd_file.log, 'Error: File ''' || p_file_name ||
                           ''' does not exist');
        retcode := 2;
        errbuf  := 'Invalid file name or path';
      ELSE
        -- file exists, but data is invalid (for example)
        retcode := 2;
        errbuf  := 'Unexpected error in uploading file';
      END IF;
      /*
      WHEN data_error THEN
        retcode := '1';
        errbuf  := 'Failed to process data:' || l_err_msg;
        set_interface_final_status;
        report_data(l_err_code, l_err_msg);*/
  
    WHEN OTHERS THEN
      retcode := '1';
      errbuf  := 'Unexpected error in XXIBY_BANK_CONV_PKG.main:' || SQLERRM;
      set_interface_final_status;
      report_data(l_err_code, l_err_msg);
  END main;

END xxiby_bank_conv_pkg;
/
