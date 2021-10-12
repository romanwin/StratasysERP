create or replace package body "XXAR_RECEIPT_BATCHES_TO_MASAV" is
  --------------------------------------------------------------------------
  -- Concurrent : XXAR: Receipt Batches to MASAV
  --------------------------------------------------------------------------
  -- Ver   When        Who           Description
  -- ----  ----------  ------------  ---------------------------------------
  -- 1.0   22/06/2021  Roman W.      CHG0049698 - MASAV collection process
  --------------------------------------------------------------------------

  --------------------------------------------------------------------------
  -- Ver   When        Who           Description
  -- ----  ----------  ------------  ---------------------------------------
  -- 1.0   22/06/2021  Roman W.      CHG0049698 - MASAV collection process
  --------------------------------------------------------------------------
  procedure message(p_msg in varchar2) is
    ----------------------
    --   Code Section
    ----------------------
  begin
    if fnd_global.CONC_REQUEST_ID > 0 then
      fnd_file.put_line(fnd_file.LOG, p_msg);
    else
      dbms_output.put_line(p_msg);
    end if;
  end message;
  --------------------------------------------------------------------------
  -- Concurrent : XXAR: Receipt Batches to MASAV
  --------------------------------------------------------------------------
  -- Ver   When        Who           Description
  -- ----  ----------  ------------  ---------------------------------------
  -- 1.0   22/06/2021  Roman W.      CHG0049698 - MASAV collection process
  --------------------------------------------------------------------------
  procedure main(errbuf      OUT VARCHAR2,
                 retcode     OUT VARCHAR2,
                 p_batch_id  IN VARCHAR2, -- 385388/1    VS - XXAR_BATCHES_ALL4
                 p_file_path IN VARCHAR2,
                 p_file_name IN VARCHAR2) is
    -----------------------
    --  Local Definition
    -----------------------
  
    ----------------------------------
    -- Masav Receipt Batch Header
    ----------------------------------
    CURSOR header_line_cur(c_batch_id NUMBER) is
      select 'K' || fnd_profile.value('XX_MOSAD_NOSE NUM') || /*'45189669' || */ /*(select v.account_option_value
                                                                                   from IBY_BEP_ACCT_OPT_VALS v
                                                                                  where v.account_option_code = 'USER_DEFINED_CODE'
                                                                                    and bepid = 10140)*/ -- need to check base on he  bank Leumi 10140 Poalim 10101
             '00' || to_char(rb.deposit_date, 'YYMMDD') || '0' || '001' || '0' ||
             to_char(rb.creation_date, 'YYMMDD') ||
             fnd_profile.value('XXAR_STRATASYS_COMP_CODE') -- '45189'     --Company Code
             || '000000' || lpad(xxar_utils_pkg.get_company_name(o.default_legal_context_id,
                                                                 rb.org_id),
                                 30,
                                 ' ') --Company Name
             || lpad('KOT', 59, ' ') || chr(13) || chr(10) header_line,
             rb.attribute2,
             rb.attribute3
        from ar_batches_all rb, hr_operating_units o
       where rb.batch_id = c_batch_id --&batch_id_id
         and rb.org_id = o.organization_id;
    -----------------------------------------
    --  Masav Customer debit transactions
    -----------------------------------------
    CURSOR customer_debit_transact_cur(c_batch_id   NUMBER,
                                       c_attribute2 VARCHAR2,
                                       c_attribute3 VARCHAR2) is
      select '1' || --'45189669' || 
              fnd_profile.value('XX_MOSAD_NOSE NUM') || '00' || '000000' ||
              substr(ABB.BANK_NUMBER, 1, 2) || -- need to check for 2 digit code
              substr(ABB.BRANCH_NUMBER, 1, 3) || -- need to check 3 digit code
              '0000' ||
             --substr(CBA.BANK_ACCOUNT_TYPE, 1, 4) || -- need to check 4 digit bank account type
              lpad(replace(CBA.BANK_ACCOUNT_NUM, '-', ''), '9', '0') || -- need to check 9 digit bank account number
              '0' || lpad(CUST.ACCOUNT_NUMBER, 9, ' ') || -- customer number 9 digit
              lpad(SUBSTR(PARTY.PARTY_NAME, 1, 16), 16, ' ') || -- need to check query and padding in TEST instance
              lpad(CR.AMOUNT * 100, 13, '0') || -- 13 digit in which 11 for ILS 2 For Agora(1/100 ILS)
             --lpad(CR.PAY_FROM_CUSTOMER, 20, '0') || -- 20 digit customer id 
              lpad(CR.RECEIPT_NUMBER, 20, '0') || -- 20 digit customer id in Institution
             --'YYMMYYMM' || -- debit period From YYMM To YYMM 8 dogit -- Rem By Roman 29/07/2021
              c_attribute2 || c_attribute3 || -- Added By Roman 29/07/2021 
              '000' || -- Malala Code
              '504' || -- Record type
              '000000000000000000' || '  ' || chr(13) || chr(10) Debit_line
        from AR_CASH_RECEIPT_HISTORY_ALL CR_HIS,
             AR_CASH_RECEIPTS_All        CR,
             CE_BANK_ACCOUNTS            CBA,
             CE_BANK_ACCT_USES_ALL       ABA,
             CE_BANK_BRANCHES_V          ABB,
             HZ_CUST_ACCOUNTS            CUST,
             HZ_PARTIES                  PARTY
       where CR_HIS.cash_receipt_id = CR.cash_receipt_id
         and CR.REMIT_BANK_ACCT_USE_ID = ABA.BANK_ACCT_USE_ID
         and CBA.BANK_BRANCH_ID = ABB.BRANCH_PARTY_ID
         and ABA.BANK_ACCOUNT_ID = CBA.BANK_ACCOUNT_ID
         and CR.PAY_FROM_CUSTOMER = CUST.CUST_ACCOUNT_ID
         AND CUST.PARTY_ID = PARTY.PARTY_ID
         and CR_HIS.batch_id = c_batch_id --batch_id from ra_batches header record
         and CR_HIS.org_id = CR.org_id;
    -----------------------------------------
    -- Masav Total line
    -----------------------------------------
    cursor total_line_cur(c_batch_id NUMBER) is
      select '5' || fnd_profile.value('XX_MOSAD_NOSE NUM') || --'45189669'||
             '00' || to_char(rb.deposit_date, 'YYMMDD') || '0' || '001' ||
             '000000000000000' || lpad(rb.control_amount * 100, 15, '0') ||
             '0000000' || lpad(rb.control_count, 7, '0') ||
             '                                                               ' Trailer_Record
        from ar_batches_all rb
       where rb.batch_id = c_batch_id; --&batch_id_id;
  
    l_clob           CLOB;
    l_file_exists    NUMBER;
    l_file_name_old  VARCHAr2(120);
    l_save_file_flag VARCHAr2(10);
    l_attribute2     VARCHAr2(240);
    l_attribute3     VARCHAr2(240);
    -----------------------
    --  Code Section
    -----------------------
  begin
    errbuf  := '';
    retcode := '0';
  
    message('XXAR_RECEIPT_BATCHES_TO_MASAV.main( p_batch_id  => ' ||
            p_batch_id || ',' || chr(10) -- 385388
            || 'p_file_path => ' || p_file_path || ',' || chr(10) ||
            'p_file_name => ' || p_file_name || ',' || chr(10) || ')');
  
    l_file_name_old  := p_file_name || '.old';
    l_save_file_flag := 'Y';
  
    ----------------------------------
    --        Calculate Data
    ----------------------------------
    l_clob := EMPTY_CLOB();
    l_clob := '';
    message('2');
    dbms_lob.createtemporary(l_clob, TRUE);
  
    ----- HEADER ----
    for header_line_ind in header_line_cur(p_batch_id) loop
      l_attribute2 := header_line_ind.attribute2;
      l_attribute3 := header_line_ind.attribute3;
      message(header_line_ind.header_line);
      DBMS_LOB.append(dest_lob => l_clob,
                      src_lob  => header_line_ind.header_line);
    end loop;
  
    message('3');
    ----- LINES ----
    for customer_debit_transact_ind in customer_debit_transact_cur(p_batch_id,
                                                                   l_attribute2,
                                                                   l_attribute3) loop
      message(customer_debit_transact_ind.debit_line);
      DBMS_LOB.append(l_clob, customer_debit_transact_ind.debit_line);
    end loop;
  
    message('4');
    ----- FOOTER ----
    for total_line_ind in total_line_cur(p_batch_id) loop
      message(total_line_ind.trailer_record);
      DBMS_LOB.append(l_clob, total_line_ind.trailer_record);
    end loop;
  
    fnd_file.put_line(fnd_file.OUTPUT, l_clob);
  
    if p_file_path is not null and p_file_name is not null then
      ----------------------------------
      --         Make Directory
      ----------------------------------
      XXSSYS_FILE_UTIL_PKG.make_directory(p_directory_name => C_DIRECTORY,
                                          p_dir_path       => p_file_path,
                                          p_error_code     => retcode,
                                          p_error_desc     => errbuf);
    
      message('1');
      if '0' != retcode then
        return;
      end if;
    
      message('5');
      l_file_exists := XXSSYS_FILE_UTIL_PKG.file_exists(p_directory_name => C_DIRECTORY,
                                                        p_file_name      => p_file_name);
    
      message('6');
      if 1 = l_file_exists then
        utl_file.frename(src_location  => C_DIRECTORY,
                         src_filename  => p_file_name,
                         dest_location => C_DIRECTORY,
                         dest_filename => l_file_name_old,
                         overwrite     => true);
      end if;
    
      ----------------------------------
      --        Save to File
      ----------------------------------    
      message('7');
      message(to_char(l_clob));
    
      XXSSYS_FILE_UTIL_PKG.save_clob_to_file(p_directory_name => C_DIRECTORY,
                                             p_file_name      => p_file_name,
                                             p_clob           => l_clob);
      message('8');
      ----------------------------------
      --        delete old file
      ----------------------------------
      l_file_exists := XXSSYS_FILE_UTIL_PKG.file_exists(p_directory_name => C_DIRECTORY,
                                                        p_file_name      => l_file_name_old);
      if 1 = l_file_exists then
        utl_file.fremove(location => C_DIRECTORY,
                         filename => l_file_name_old);
      
        message('9');
      end if;
    end if;
  
  exception
    when others then
      errbuf  := 'EXCEPTION_OTHERS XXAR_RECEIPT_BATCHES_TO_MASAV.main(' ||
                 p_batch_id || ',' || -- 385388/1    VS - XXAR_BATCHES_ALL4
                 p_file_path || ',' || p_file_name || ') - ' || sqlerrm;
      retcode := '2';
      message(errbuf);
  end main;

end XXAR_RECEIPT_BATCHES_TO_MASAV;
/
