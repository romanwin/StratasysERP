CREATE OR REPLACE PACKAGE BODY XXAR_OPYO_PKG is
  -----------------------------------------------------------------------------------------------------
  -- Ver   When         Who         Descr
  -- ----  -----------  ----------  -------------------------------------------------------------------
  -- 1.0   12/08/2020   Roman W.    CHG0048031- Daily upload of customer open balances to OPYO BI tool
  -- 1.1   24/08/2020   Roman W.    CHG0048031- added old zip file deleting
  -- 1.2   26/10/2020   Roman W.    CHG0048802 - improve invoice file creation performance
  -----------------------------------------------------------------------------------------------------

  -----------------------------------------------------------------------------------------------------
  -- Ver   When         Who         Descr
  -- ----  -----------  ----------  -------------------------------------------------------------------
  -- 1.0   12/08/2020   Roman W.    CHG0048031- Daily upload of customer open balances to OPYO BI tool
  -----------------------------------------------------------------------------------------------------
  PROCEDURE message(p_msg VARCHAR2) IS
    l_msg VARCHAR2(1000);
  BEGIN
    l_msg := to_char(sysdate, 'DD/MM/YYYY HH24:MI:SS  ') || p_msg;
  
    if fnd_global.CONC_REQUEST_ID > 0 then
      fnd_file.put_line(fnd_file.LOG, l_msg);
    else
      dbms_output.put_line(l_msg);
    end if;
  END message;
  /*
  -------------------------------------------------------------------------
  -- Ver    When          Who             Descr
  -- -----  ------------  -------------   ---------------------------------
  -- 1.0    20/10/2020    Roman W.        CHG0046921
  -------------------------------------------------------------------------
  procedure copy_to_archave(p_location_from  in varchar2,
                            p_file_name_from in varchar2,
                            p_location_to    in varchar2,
                            p_file_name_to   in varchar2,
                            p_error_code     out varchar2,
                            p_error_desc     out varchar2) is
    ------------------------------
    --     Local Definition
    ------------------------------
    l_count      NUMBER;
    l_blob       BLOB;
    l_request_id NUMBER;
    ------------------------------
    --      Code Section
    ------------------------------
  begin
    p_error_code := '0';
    p_error_desc := null;
  
    l_count := dbms_lob.fileexists(bfilename(C_DIRECTORY, p_file_name_from));
  
    if 1 = l_count then
      l_blob := xxssys_file_util_pkg.get_blob_from_file(p_directory_name => C_DIRECTORY,
                                                        p_file_name      => p_file_name_from);
      xxssys_file_util_pkg.save_blob_to_file(p_directory_name => C_ARC_DIRECTORY,
                                             p_file_name      => p_file_name_to,
                                             p_blob           => l_blob);
    
    
    end if;
  exception
    when others then
      p_error_code := '2';
      p_error_desc := 'EXCEPTION_OTHERS XXAR_OPYO_PKG.copy_to_archave(' ||
                      p_location_from || ',' || p_file_name_from || ',' ||
                      p_location_to || ',' || p_file_name_to || ') - ' ||
                      sqlerrm;
      message(p_msg => p_error_desc);
    
  end copy_to_archave;
  */
  -------------------------------------------------------------------------
  -- Ver   When         Who          Descr
  -- ----  -----------  -----------  --------------------------------------
  -- 1.0   09/09/2020   Roman W.     CHG0046921
  -------------------------------------------------------------------------
  procedure remove_file(p_directory  in varchar2,
                        p_file_name  in varchar2,
                        p_error_code out varchar2,
                        p_error_desc out varchar2) is
    l_count NUMBER;
  begin
    p_error_code := '0';
    p_error_desc := null;
  
    l_count := dbms_lob.fileexists(bfilename(p_directory, p_file_name));
  
    message('XXAR_OPYO_PKG.remove_file(' || p_directory || ',' ||
            p_file_name || ') - count = ' || l_count);
  
    if 1 = l_count then
      utl_file.fremove(location => p_directory, filename => p_file_name);
    end if;
  
  exception
    when others then
      p_error_code := '2';
      p_error_desc := 'EXCEPTION_OTHERS XXAR_OPYO_PKG.remove_file(' ||
                      p_directory || ',' || p_file_name || ') - ' ||
                      sqlerrm;
      message(p_error_desc);
    
  end remove_file;
  ----------------------------------------------------------------------------------
  -- Ver   When        Who         Descr
  -- ----  ----------  ----------  -------------------------------------------------
  -- 1.0   02/09/2020  Roman W.    CHG0048031 - calculation closest conversion rate
  ----------------------------------------------------------------------------------
  function get_closest_conversion_rate(p_date            DATE,
                                       p_from            VARCHAR2,
                                       p_to              VARCHAR2,
                                       p_conversion_type VARCHAR2)
    return DATE is
    ----------------------------
    --    Local Definition
    ----------------------------
    l_ret_val           DATE;
    l_lower_date        DATE;
    l_higher_date       DATE;
    l_lower_difference  NUMBER;
    l_higher_difference NUMBER;
    l_closer_difference NUMBER;
    ----------------------------
    --    Code Section
    ----------------------------
  begin
  
    select max(gdr.conversion_date)
      into l_lower_date
      from GL_DAILY_RATES gdr
     where gdr.from_currency = p_from
       and gdr.to_currency = p_to
       and conversion_type = p_conversion_type
       and gdr.conversion_date <= p_date;
  
    select min(gdr.conversion_date)
      into l_higher_date
      from GL_DAILY_RATES gdr
     where gdr.from_currency = p_from
       and gdr.to_currency = p_to
       and conversion_type = p_conversion_type
       and gdr.conversion_date >= p_date;
  
    select to_number(trunc(p_date) - trunc(l_lower_date)),
           to_number(trunc(l_higher_date) - trunc(p_date))
      into l_lower_difference, l_higher_difference
      from dual;
  
    select least(nvl(l_lower_difference, 300),
                 nvl(l_higher_difference, 300))
      into l_closer_difference
      from dual;
  
    if l_closer_difference = l_lower_difference then
      l_ret_val := l_lower_date;
    else
      l_ret_val := l_higher_date;
    end if;
  
    return l_ret_val;
  
  end get_closest_conversion_rate;
  /*
  -----------------------------------------------------------------------------------------------------
  -- Ver   When         Who         Descr
  -- ----  -----------  ----------  -------------------------------------------------------------------
  -- 1.0   12/08/2020   Roman W.    CHG0048031- Daily upload of customer open balances to OPYO BI tool
  -----------------------------------------------------------------------------------------------------
  procedure mv_file(p_location_from  in varchar2,
                    p_file_name_from in varchar2,
                    p_location_to    in varchar2,
                    p_file_name_to   in varchar2,
                    p_error_code     out varchar2,
                    p_error_desc     out varchar2) is
    ---------------------------
    --    Code Section
    ---------------------------
    l_request_id      NUMBER;
    l_exist_file_flag NUMBER;
    ---------------------------
    --    Local Definition
    ---------------------------
  begin
    p_error_code := '0';
    p_error_desc := null;
  
    l_exist_file_flag := DBMS_LOB.FILEEXISTS(BFILENAME(C_DIRECTORY,
                                                       p_file_name_from));
  
    if 0 = l_exist_file_flag then
      return;
    end if;
  
    l_request_id := fnd_request.submit_request(application => 'XXOBJT',
                                               program     => 'XXMVFILE',
                                               description => 'XXMVFILE( XXAR_OPYO_PKG.mv_file )',
                                               start_time  => sysdate,
                                               sub_request => FALSE,
                                               argument1   => p_location_from,
                                               argument2   => p_file_name_from,
                                               argument3   => p_location_to,
                                               argument4   => p_file_name_to);
  
    if 0 = l_request_id then
      p_error_code := '2';
      p_error_desc := 'Concurrent "XXMVFILE/XXMVFILE(' || p_location_from || ',' ||
                      p_file_name_from || ',' || p_location_to || ',' ||
                      p_file_name_to || ',' || ')" - Not Submitted ';
    else
      commit;
      message('REQUEST_ID( ' || l_request_id || ' )' ||
              ' - XXMVFILE/XXMVFILE');
      xxssys_dpl_pkg.wait_for_request(p_request_id => l_request_id,
                                      p_error_code => p_error_code,
                                      p_error_desc => p_error_desc);
  
    end if;
  exception
    when others then
      p_error_code := '2';
      p_error_desc := 'EXCEPTION_OTHERS XXAR_OPYO_PKG.mv_file(' ||
                      p_location_from || ',' || p_file_name_from || ',' ||
                      p_location_to || ',' || p_file_name_to || ') - ' ||
                      sqlerrm;
      message(p_msg => p_error_desc);
  
  end mv_file;
  */
  -----------------------------------------------------------------------------------------------------
  -- Ver   When         Who         Descr
  -- ----  -----------  ----------  -------------------------------------------------------------------
  -- 1.0   12/08/2020   Roman W.    CHG0048031- Daily upload of customer open balances to OPYO BI tool
  -----------------------------------------------------------------------------------------------------
  procedure zip_file(p_location      in varchar2,
                     p_file_name     in varchar2,
                     p_zip_file_name in varchar2,
                     p_error_code    out varchar2,
                     p_error_desc    out varchar2) is
    ---------------------------
    --    Code Section
    ---------------------------
    l_request_id NUMBER;
    ---------------------------
    --    Local Definition
    ---------------------------
  begin
    p_error_code := '0';
    p_error_desc := null;
  
    l_request_id := fnd_request.submit_request(application => 'XXOBJT',
                                               program     => 'XXSSYS_CREATE_ZIP_FILE2',
                                               description => 'XX SSYS: Create ZIP File 2',
                                               start_time  => sysdate,
                                               sub_request => FALSE,
                                               argument1   => p_location,
                                               argument2   => p_file_name,
                                               argument3   => p_zip_file_name);
  
    if 0 = l_request_id then
      p_error_code := '2';
      p_error_desc := 'Concurrent "XX SSYS: Create ZIP File/XXSSYS_CREATE_ZIP_FILE(' ||
                      p_location || ',' || p_file_name ||
                      ')" - Not Submitted ';
    else
      commit;
      message('REQUEST_ID( ' || l_request_id || ' )' ||
              ' - XX SSYS: Create ZIP File/XXSSYS_CREATE_ZIP_FILE');
      xxssys_dpl_pkg.wait_for_request(p_request_id => l_request_id,
                                      p_error_code => p_error_code,
                                      p_error_desc => p_error_desc);
    
      message(p_error_code || ' - ' || p_error_desc);
    
    end if;
  exception
    when others then
      p_error_code := '2';
      p_error_desc := 'EXCEPTION_OTHERS XXAR_OPYO_PKG.zip_file(' ||
                      p_location || ',' || p_file_name || ') - ' || sqlerrm;
      message(p_msg => p_error_desc);
    
  end zip_file;
  -----------------------------------------------------------------------------------------------------
  -- Ver   When         Who         Descr
  -- ----  -----------  ----------  -------------------------------------------------------------------
  -- 1.0   14/09/2020   Roman W.    CHG0048031- coma delimiter handling in "hl.address1"
  -----------------------------------------------------------------------------------------------------
  function remove_special_char(p_str varchar2) return varchar2 is
    lv_str VARCHAR2(32000);
  begin
  
    lv_str := replace(p_str, '"', '');
    lv_str := replace(lv_str, chr(10), ' ');
    lv_str := replace(lv_str, chr(9), ' ');
    lv_str := replace(lv_str, CHR(13), ' ');
  
    --select decode(instr(lv_str, ','), 0, lv_str, '"' || lv_str || '"')
    -- into lv_str
    -- from dual;
  
    lv_str := '"' || trim(lv_str) || '"';
  
    --regexp_replace(srcstr     => lv_str,
    --                        pattern    => '[^A-Za-z0-9_ :;=''.()><,-/\#\t\n\r%*+!{}||?"&\[\]]',
    --                         replacestr => '');
  
    return lv_str;
  end remove_special_char;

  -----------------------------------------------------------------------------------------------------
  -- Ver   When         Who         Descr
  -- ----  -----------  ----------  -------------------------------------------------------------------
  -- 1.0   12/08/2020   Roman W.    CHG0048031- Daily upload of customer open balances to OPYO BI tool
  -- 1.1   14/09/2020   Roman W.    CHG0048031- coma delimiter handling in "hl.address1"
  -----------------------------------------------------------------------------------------------------
  procedure get_strat_buyers_clob(p_error_code OUT VARCHAR2,
                                  p_error_desc OUT VARCHAR2,
                                  p_clob       OUT CLOB) is
    ------------------------
    --  Local Definition
    ------------------------
    cursor strat_buyers_cur is
      SELECT distinct 'Oracle' SOURCE_SYSTEM_INSTANCE,
                      HC.CUST_ACCOUNT_ID BUYER_SYSTEM_ID,
                      HC.ACCOUNT_NUMBER BUYER_NUMBER,
                      decode(instr(HP.PARTY_NAME, ','),
                             0,
                             HP.PARTY_NAME,
                             '"' || HP.PARTY_NAME || '"') BUYER_NAME,
                      null BUYER_NAME_LONG,
                      null BUYER_TAX_REF,
                      XXAR_OPYO_PKG.remove_special_char(hop.tax_reference) BUYER_TAXPAYER_ID,
                      null BUYER_CLASS_ID,
                      (select min(al.meaning)
                         from apps.hz_code_assignments hcodeass,
                              apps.ar_lookups          al
                        where hcodeass.owner_table_id = hp.party_id
                          and hcodeass.class_category = al.lookup_type
                          and hcodeass.class_code = al.lookup_code
                          and hcodeass.class_category =
                              'Objet Business Type'
                          and hcodeass.status = 'A'
                          and hcodeass.start_date_active <= sysdate
                          and nvl(hcodeass.end_date_active, sysdate) >=
                              sysdate
                          and hcodeass.owner_table_name = 'HZ_PARTIES') BUYER_CLASS,
                      XXAR_OPYO_PKG.remove_special_char(hl.address1) BUYER_ADDRESS,
                      XXAR_OPYO_PKG.remove_special_char(hl.city) BUYER_CITY,
                      null BUYER_COUNTRY_ID,
                      XXAR_OPYO_PKG.remove_special_char(ft.territory_short_name) BUYER_COUNTRY_NAME,
                      null SALES_REP_NAME,
                      null BUYER_CONTACT_PHONE_NUMBER,
                      null BUYER_ZIP_CODE,
                      null BUYER_MAIN_CONTACT,
                      null BUYER_MAIL_ADDRESS,
                      decode(hc.customer_type, 'I', 'Y', 'N') INTERCOMPANY_YES_NO,
                      null BUYER_REGION_ID,
                      null BUYER_REGION_NAME,
                      hcs.cust_acct_site_id BUYER_SITE_ID,
                      hp.duns_number BUYER_DUNS_ID,
                      r_terms.term_id BUYER_PAYMENT_TERMS_ID,
                      XXAR_OPYO_PKG.remove_special_char(r_terms.name) BUYER_PAYMENT_TERMS_SALES,
                      /* (select rt.name
                       from hz_customer_profiles hcp, ra_terms_tl rt
                      where hcp.site_use_id is null
                        and hcp.cust_account_id = hc.cust_account_id
                        and rt.term_id = hcp.standard_terms
                        and rt.language = 'US') BUYER_PAYMENT_TERMS_COMPANY,*/
                      to_char(hc.creation_date, 'dd-Mon-yyyy hh:mm') BUYER_CREATION_DATE,
                      to_char(hc.last_update_date, 'dd-Mon-yyyy hh:mm') BUYER_LAST_UPDATE_DATE,
                      to_char(sysdate, 'dd-Mon-yyyy hh:mm') DATA_EXTRACT_DATE,
                      null BUYER_CURRENCY_ID,
                      null BUYER_CURRENCY_NAME,
                      null BUYER_CREDIT_LIMIT,
                      to_char(sysdate, 'dd-Mon-yyyy hh:mm') FILE_CREATION_DATE,
                      null PARENT_BUYER_SYSTEM_ID,
                      null PARENT_BUYER_NUMBER,
                      null PARENT_BUYER_NAME,
                      null BILLING_BUYER_SYSTEM_ID,
                      null BILLING_BUYER_NUMBER,
                      null BILLING_BUYER_NAME,
                      (select pcpa.attribute1
                         from hz_cust_profile_amts pcpa
                        where pcpa.site_use_id is null
                          and pcpa.currency_code = 'USD'
                          and pcpa.cust_account_id = hc.cust_account_id) INSURER_ID
        FROM HZ_CUST_ACCOUNTS         HC,
             HZ_PARTIES               HP,
             HZ_ORGANIZATION_PROFILES hop,
             hz_party_sites           hps,
             hz_cust_acct_sites_all   hcs,
             hz_cust_site_uses_all    hcu,
             hz_locations             hl,
             ra_terms_tl              r_terms,
             HZ_CUSTOMER_PROFILES     hcp,
             fnd_territories_tl       ft
       WHERE HC.PARTY_ID = HP.PARTY_ID
         and hp.party_type = 'ORGANIZATION'
         and hp.status = 'A'
         and hc.status = 'A'
         and hps.status = 'A'
         and r_terms.language(+) = 'US'
         and hop.party_id = HP.PARTY_ID
         and hps.party_id = hp.party_id
         and hl.location_id = hps.location_id
         and hcp.cust_account_id = hc.cust_account_id
         and hcs.party_site_id(+) = hps.party_site_id
         and hcu.cust_acct_site_id(+) = hcs.cust_acct_site_id
         and hcu.payment_term_id = r_terms.term_id(+)
         and ft.territory_code = hl.country
         and ft.language = 'US'
         and hcs.org_id <> 89
         and hcu.org_id <> 89;
  
    l_clob CLOB := EMPTY_CLOB();
    l_row  VARCHAR2(32000);
    ------------------------
    --  Code Section
    ------------------------
  begin
    p_error_code := '0';
    p_error_desc := null;
  
    dbms_lob.createtemporary(lob_loc => p_clob,
                             cache   => TRUE,
                             dur     => DBMS_LOB.SESSION);
  
    -- file headers --
    l_row := 'SOURCE_SYSTEM_INSTANCE,BUYER_SYSTEM_ID,BUYER_NUMBER,BUYER_NAME,BUYER_NAME_LONG,BUYER_TAX_REF,BUYER_TAXPAYER_ID,BUYER_CLASS_ID,BUYER_CLASS,BUYER_ADDRESS,BUYER_CITY,BUYER_COUNTRY_ID,BUYER_COUNTRY_NAME,SALES_REP_NAME,BUYER_CONTACT_PHONE_NUMBER,BUYER_ZIP_CODE,BUYER_MAIN_CONTACT,BUYER_MAIL_ADDRESS,INTERCOMPANY_YES_NO,BUYER_REGION_ID,BUYER_REGION_NAME,BUYER_SITE_ID,BUYER_DUNS_ID,BUYER_PAYMENT_TERMS_ID,BUYER_PAYMENT_TERMS_SALES,BUYER_CREATION_DATE,BUYER_LAST_UPDATE_DATE,DATA_EXTRACT_DATE,BUYER_CURRENCY_ID,BUYER_CURRENCY_NAME,BUYER_CREDIT_LIMIT,FILE_CREATION_DATE,PARENT_BUYER_SYSTEM_ID,PARENT_BUYER_NUMBER,PARENT_BUYER_NAME,BILLING_BUYER_SYSTEM_ID,BILLING_BUYER_NUMBER,BILLING_BUYER_NAME,INSURER_ID' ||
             chr(10);
  
    dbms_lob.append(p_clob, l_row);
  
    for strat_buyers_ind in strat_buyers_cur loop
    
      --      DBMS_LOB. append(l_clob,
      begin
        l_row := strat_buyers_ind.SOURCE_SYSTEM_INSTANCE || ',' ||
                 strat_buyers_ind.BUYER_SYSTEM_ID || ',' ||
                 strat_buyers_ind.BUYER_NUMBER || ',' ||
                 strat_buyers_ind.BUYER_NAME || ',' ||
                 strat_buyers_ind.BUYER_NAME_LONG || ',' ||
                 strat_buyers_ind.BUYER_TAX_REF || ',' ||
                 strat_buyers_ind.BUYER_TAXPAYER_ID || ',' ||
                 strat_buyers_ind.BUYER_CLASS_ID || ',' ||
                 strat_buyers_ind.BUYER_CLASS || ',' ||
                 strat_buyers_ind.BUYER_ADDRESS || ',' ||
                 strat_buyers_ind.BUYER_CITY || ',' ||
                 strat_buyers_ind.BUYER_COUNTRY_ID || ',' ||
                 strat_buyers_ind.BUYER_COUNTRY_NAME || ',' ||
                 strat_buyers_ind.SALES_REP_NAME || ',' ||
                 strat_buyers_ind.BUYER_CONTACT_PHONE_NUMBER || ',' ||
                 strat_buyers_ind.BUYER_ZIP_CODE || ',' ||
                 strat_buyers_ind.BUYER_MAIN_CONTACT || ',' ||
                 strat_buyers_ind.BUYER_MAIL_ADDRESS || ',' ||
                 strat_buyers_ind.INTERCOMPANY_YES_NO || ',' ||
                 strat_buyers_ind.BUYER_REGION_ID || ',' ||
                 strat_buyers_ind.BUYER_REGION_NAME || ',' ||
                 strat_buyers_ind.BUYER_SITE_ID || ',' ||
                 strat_buyers_ind.BUYER_DUNS_ID || ',' ||
                 strat_buyers_ind.BUYER_PAYMENT_TERMS_ID || ',' ||
                 strat_buyers_ind.BUYER_PAYMENT_TERMS_SALES || ',' ||
                 strat_buyers_ind.BUYER_CREATION_DATE || ',' ||
                 strat_buyers_ind.BUYER_LAST_UPDATE_DATE || ',' ||
                 strat_buyers_ind.DATA_EXTRACT_DATE || ',' ||
                 strat_buyers_ind.BUYER_CURRENCY_ID || ',' ||
                 strat_buyers_ind.BUYER_CURRENCY_NAME || ',' ||
                 strat_buyers_ind.BUYER_CREDIT_LIMIT || ',' ||
                 strat_buyers_ind.FILE_CREATION_DATE || ',' ||
                 strat_buyers_ind.PARENT_BUYER_SYSTEM_ID || ',' ||
                 strat_buyers_ind.PARENT_BUYER_NUMBER || ',' ||
                 strat_buyers_ind.PARENT_BUYER_NAME || ',' ||
                 strat_buyers_ind.BILLING_BUYER_SYSTEM_ID || ',' ||
                 strat_buyers_ind.BILLING_BUYER_NUMBER || ',' ||
                 strat_buyers_ind.BILLING_BUYER_NAME || ',' ||
                 strat_buyers_ind.INSURER_ID || chr(10);
      
        dbms_lob.append(p_clob, l_row);
      exception
        when others then
          message('EXCEPTION : ' || l_row);
      end;
    end loop;
  
  exception
    when others then
      p_error_code := '2';
      p_error_desc := 'EXCEPTION_OTHERS XXAR_OPYO_PKG.get_strat_buyers_clob() - ' ||
                      sqlerrm;
  end get_strat_buyers_clob;
  -----------------------------------------------------------------------------------------------------
  -- Ver   When         Who         Descr
  -- ----  -----------  ----------  -------------------------------------------------------------------
  -- 1.0   12/08/2020   Roman W.    CHG0048031- Daily upload of customer open balances to OPYO BI tool
  -- 1.1   20/10/2020   Roman W.    CHG0048802 - improve invoice file creation performance
  -- 1.2   22/10/2020   Roman W.    CHG0048802 - improve invoice file creation performance 
  -----------------------------------------------------------------------------------------------------

  procedure get_strat_invoices_clob(p_error_code OUT VARCHAR2,
                                    p_error_desc OUT VARCHAR2,
                                    p_clob       OUT CLOB) is
    ------------------------------------
    --      Local Definition
    ------------------------------------
    cursor strat_invoices_cur is
      with xxar_payment_schedules_all as
       (select asa.customer_trx_id
          from ar_payment_schedules_all asa
         where 1 = 1
           and asa.customer_trx_id is not null
           and asa.actual_date_closed > add_months(sysdate, -36)
         group by asa.customer_trx_id)
      select rt.org_id OPERATING_BUSINESS_UNIT_ID,
             hu.name OPERATING_BUSINESS_UNIT_NAME,
             'Oracle' SOURCE_SYSTEM_INSTANCE,
             rt.sold_to_customer_id SOLD_TO_BUYER_ID,
             rt.sold_to_site_use_id SOLD_TO_BUYER_SITE,
             rt.customer_trx_id DOCUMENT_ID,
             rt.trx_number DOCUMENT_NUMBER,
             rt.interface_header_attribute1 REFERENCE_NUMBER,
             null JOURNAL_LINE,
             to_char(rt.creation_date, 'dd-Mon-yyyy hh:mm') CREATION_DATE,
             to_char(rt.last_update_date, 'dd-Mon-yyyy hh:mm') LAST_UPDATE_DATE,
             to_char(rt.trx_date, 'dd-Mon-yyyy hh:mm') TRANSACTION_DATE,
             (select to_char(min(apsa.due_date), 'dd-Mon-yyyy hh:mm')
                from ar_payment_schedules_all apsa
               where apsa.customer_trx_id = rt.customer_trx_id) DUE_DATE,
             rt.cust_trx_type_id TRANSACTION_TYPE_ID,
             rtt.name TRANSACTION_TYPE,
             rt.invoice_currency_code "TRANS_ORIGINAL_CURRENCY_CODE",
             null TRANSACTONAL_ORIGINAL_CURRENCY,
             gll.currency_code FUNCTIONAL_CURRENCY_CODE,
             null FUNCTIONAL_CURRENCY,
             'USD' MRC_CURRENCY_CODE,
             null MRC_CURRENCY,
             least(sysdate, nvl(rt.exchange_date, rt.trx_date)) rt_exchange_trx_date,
             null CANCELLATION_DATE,
             null CANCELLATION_FLAG,
             null REVERSED_FLAG,
             null REVERSE_REF_TRANSACTION_ID,
             null SITE_ID_SHIPPING_FROM,
             null SITE_NAME_SHIPPING_FROM,
             rt.ship_to_customer_id SHIP_TO_BUYER_ID,
             rt.ship_to_site_use_id SHIP_TO_SITE_ID,
             null SHIP_TO_BUYER_SITE_NAME,
             terms.term_id PAYMENT_TERMS_ID,
             terms.name PAYMENT_TERMS_NAME,
             terms.description PAYMENT_TERMS_LONG_DESC,
             null MRC_EXCH_RATE,
             rt.bill_to_customer_id BILL_TO_BUYER_ID,
             rt.bill_to_site_use_id BILL_TO_CUSTOMER_SITE,
             rtt.type TRANSACTION_CLASS_ID,
             fl.MEANING TRANSACTION_CLASS,
             null TRANSACTION_LAST_UPDATE_DATE,
             to_char(sysdate, 'dd-Mon-yyyy hh:mm') DATA_EXTRACT_DATE,
             to_char(sysdate, 'dd-Mon-yyyy hh:mm') FILE_CREATION_DATE,
             rt.customer_trx_id,
             rt.org_id,
             rt.set_of_books_id
        from ra_customer_trx_all        rt,
             ra_cust_trx_types_all      rtt,
             fnd_lookups                fl,
             gl_ledgers                 gll,
             hr_operating_units         hu,
             ra_terms_tl                terms,
             xxar_payment_schedules_all xpsa
       where 1 = 1
         and xpsa.customer_trx_id = rt.customer_trx_id
         and rtt.cust_trx_type_id = rt.cust_trx_type_id
         and fl.LOOKUP_type = 'JEBE_AR_OF_TRANS_TYPE'
         and fl.LOOKUP_CODE = rtt.type
         and gll.ledger_id = rt.set_of_books_id
         and hu.organization_id = rt.org_id
         and rt.term_id = terms.term_id(+)
         and terms.language(+) = 'US'
         and rt.org_id <> 89
         and rtt.org_id <> 89;
  
    --------- 1 ----------
    l_gl_date        varchar2(300);
    l_gl_posted_date varchar2(300);
    -------- 2 -----------
    l_count          number;
    l_closed_date    varchar2(300);
    l_gl_closed_date varchar2(300);
    -------- 3 -----------
    l_intercompany        varchar2(300);
    l_accounting_segments varchar2(300);
    l_seg7                varchar2(300);
    l_coa                 number; --22102020
    -------- 4 -----------
    l_amount_trans_original_cur  NUMBER;
    l_amount_functional_currency NUMBER;
  
    l_row           varchar2(32000);
    l_continue_flag varchar2(10);
  
    l_mrc_currency_amount number;
    l_exchange_trx_date   date;
  
    ------------------------------------
    --      Code Section
    ------------------------------------
  begin
    message('Start get_strat_invoices_clob');
    p_error_code := '0';
    p_error_desc := null;
  
    p_clob := EMPTY_CLOB();
  
    dbms_lob.createtemporary(lob_loc => p_clob,
                             cache   => TRUE,
                             dur     => DBMS_LOB.SESSION);
  
    l_row := 'OPERATING_BUSINESS_UNIT_ID,OPERATING_BUSINESS_UNIT_NAME,SOURCE_SYSTEM_INSTANCE,SOLD_TO_BUYER_ID,SOLD_TO_BUYER_SITE,DOCUMENT_ID,DOCUMENT_NUMBER,REFERENCE_NUMBER,JOURNAL_LINE,CREATION_DATE,LAST_UPDATE_DATE,TRANSACTION_DATE,DUE_DATE,GL_DATE,GL_POSTED_DATE,CLOSED_DATE,GL_CLOSED_DATE,TRANSACTION_TYPE_ID,TRANSACTION_TYPE,TRANS_ORIGINAL_CURRENCY_CODE,TRANSACTONAL_ORIGINAL_CURRENCY,FUNCTIONAL_CURRENCY_CODE,FUNCTIONAL_CURRENCY,MRC_CURRENCY_CODE,MRC_CURRENCY,AMOUNT_TRANS_ORIGINAL_CURRENCY,AMOUNT_FUNCTIONAL_CURRENCY,MRC_CURRENCY_AMOUNT,CANCELLATION_DATE,CANCELLATION_FLAG,REVERSED_FLAG,REVERSE_REF_TRANSACTION_ID,SITE_ID_SHIPPING_FROM,SITE_NAME_SHIPPING_FROM,SHIP_TO_BUYER_ID,SHIP_TO_SITE_ID,SHIP_TO_BUYER_SITE_NAME,PAYMENT_TERMS_ID,PAYMENT_TERMS_NAME,PAYMENT_TERMS_LONG_DESC,INTERCOMPANY,MRC_EXCH_RATE,BILL_TO_BUYER_ID,BILL_TO_CUSTOMER_SITE,TRANSACTION_CLASS_ID,TRANSACTION_CLASS,TRANSACTION_LAST_UPDATE_DATE,ACCOUNTING_SEGMENTS,DATA_EXTRACT_DATE,FILE_CREATION_DATE' ||
             chr(10);
  
    DBMS_LOB.append(p_clob, l_row);
  
    for strat_invoices_ind in strat_invoices_cur loop
      begin
        l_continue_flag := 'N';
      
        ------------------ 1 ----------------
        begin
          l_gl_date             := null;
          l_gl_posted_date      := null;
          l_accounting_segments := null; --- OFER take account from Dist
          l_coa                 := null; --22102020
        
          select to_char(rctd.gl_date, 'dd-Mon-yyyy hh:mm'),
                 to_char(rctd.gl_posted_date, 'dd-Mon-yyyy hh:mm'),
                 gcc.concatenated_segments,
                 gcc.chart_of_accounts_id --22102020
            into l_gl_date, l_gl_posted_date, l_accounting_segments, l_coa --22102020
            from ra_cust_trx_line_gl_dist_all rctd,
                 gl_code_combinations_kfv     gcc --- OFER take account from Dist
           where rctd.customer_trx_id = strat_invoices_ind.customer_trx_id
             and rctd.org_id = strat_invoices_ind.org_id
             and gcc.code_combination_id = rctd.code_combination_id --- OFER take account from Dist
             and rctd.account_class = 'REC'
             and rctd.latest_rec_flag = 'Y';
        
        exception
          when no_data_found then
            message('EXCEPTION_OTHERS_1 : ' || 'my_ind.customer_trx_id = ' ||
                    strat_invoices_ind.customer_trx_id ||
                    ', my_ind.org_id = ' || strat_invoices_ind.org_id ||
                    ' . SQLERRM = ' || sqlerrm);
        end;
      
        ----------------- 2 -------------------------
        begin
          l_closed_date    := null;
          l_gl_closed_date := null;
          l_count          := null;
        
          select count(1)
            into l_count
            from ar_payment_schedules_all apsa
           where apsa.customer_trx_id = strat_invoices_ind.customer_trx_id
             and apsa.org_id = strat_invoices_ind.org_id
             and apsa.status = 'OP';
        
          if l_count > 0 then
            l_closed_date    := null;
            l_gl_closed_date := null;
          else
            select to_char(max(apsa.actual_date_closed),
                           'dd-Mon-yyyy hh:mm') closed_date,
                   to_char(max(apsa.gl_date_closed), 'dd-Mon-yyyy hh:mm') GL_CLOSED_DATE
              into l_closed_date, l_gl_closed_date
              from ar_payment_schedules_all apsa
             where apsa.customer_trx_id =
                   strat_invoices_ind.customer_trx_id
               and apsa.org_id = strat_invoices_ind.org_id;
          end if;
        exception
          when others then
            message('EXCEPTION_OTHERS_2 : ' ||
                    'strat_invoices_ind.customer_trx_id = ' ||
                    strat_invoices_ind.customer_trx_id ||
                    ', strat_invoices_ind.org_id = ' ||
                    strat_invoices_ind.org_id || ' . SQLERRM = ' ||
                    sqlerrm);
        end;
        ----------------- 3 --------------------------
        begin
        
          l_intercompany := null;
          l_seg7         := null;
        
          select decode(gcc.segment7, '00', 'N', 'Y') intercompany,
                 gcc.segment7 --, -- ofer
            into l_intercompany, l_seg7
            from hz_cust_site_uses_all hcu, gl_code_combinations_kfv gcc
           where hcu.site_use_id = strat_invoices_ind.BILL_TO_CUSTOMER_SITE
             and hcu.org_id = strat_invoices_ind.org_id
             and gcc.code_combination_id = hcu.gl_id_rec;
        exception
          when no_data_found then
            l_intercompany := 'N';
        end;
        if l_intercompany = 'Y' then
          --22102020 begin
          if l_coa = 50449 then
            l_accounting_segments := substr(l_accounting_segments, 0, 7) ||
                                    -- '112110' || -- profile
                                     fnd_profile.VALUE('XXAR_IC_GL_ACCOUNT') ||
                                     substr(l_accounting_segments, 14, 9) ||
                                     l_seg7 ||
                                     substr(l_accounting_segments, 25);
          else
            l_accounting_segments := substr(l_accounting_segments, 0, 7) ||
                                    -- '112110' || -- profile
                                     fnd_profile.VALUE('XXAR_IC_GL_ACCOUNT') ||
                                     substr(l_accounting_segments, 14, 17) ||
                                     l_seg7 ||
                                     substr(l_accounting_segments, 33);
          end if;
        
          --22102020 end                         
        end if;
      
        ------------------- 4 --------------------------
        begin
          l_amount_trans_original_cur  := null;
          l_amount_functional_currency := null;
        
          select rctd.amount       amount_trans_original_currency,
                 rctd.acctd_amount amount_functional_currency
            into l_amount_trans_original_cur, l_amount_functional_currency
            from ra_cust_trx_line_gl_dist_all rctd
           where rctd.customer_trx_id = strat_invoices_ind.customer_trx_id
             and rctd.org_id = strat_invoices_ind.org_id
             and rctd.account_class = 'REC'
             and rctd.latest_rec_flag = 'Y';
        exception
          when others then
            dbms_output.put_line('EXCEPTION_OTHERS_4 : ' ||
                                 'my_ind.customer_trx_id = ' ||
                                 strat_invoices_ind.customer_trx_id ||
                                 ', my_ind.org_id = ' ||
                                 strat_invoices_ind.org_id ||
                                 ' . SQLERRM = ' || sqlerrm);
        end;
      
        begin
          l_mrc_currency_amount := null;
          l_exchange_trx_date   := null;
        
          select round(rctd.amount *
                       gl_currency_api.get_closest_rate(strat_invoices_ind.TRANS_ORIGINAL_CURRENCY_CODE,
                                                        'USD',
                                                        strat_invoices_ind.rt_exchange_trx_date,
                                                        'Corporate',
                                                        10),
                       2)
            into l_mrc_currency_amount
            from ra_cust_trx_line_gl_dist_all rctd
           where rctd.customer_trx_id = strat_invoices_ind.document_id
             and rctd.account_class = 'REC'
             and rctd.latest_rec_flag = 'Y';
        
        exception
          when others then
            begin
              l_exchange_trx_date := xxar_opyo_pkg.get_closest_conversion_rate(p_date            => strat_invoices_ind.rt_exchange_trx_date,
                                                                               p_from            => strat_invoices_ind.TRANS_ORIGINAL_CURRENCY_CODE,
                                                                               p_to              => 'USD',
                                                                               p_conversion_type => 'Corporate');
              select round(rctd.amount *
                           gl_currency_api.get_closest_rate(strat_invoices_ind.TRANS_ORIGINAL_CURRENCY_CODE,
                                                            'USD',
                                                            l_exchange_trx_date,
                                                            'Corporate',
                                                            10),
                           2)
                into l_mrc_currency_amount
                from ra_cust_trx_line_gl_dist_all rctd
               where rctd.customer_trx_id = strat_invoices_ind.document_id
                 and rctd.account_class = 'REC'
                 and rctd.latest_rec_flag = 'Y';
            exception
              when others then
                l_continue_flag := 'Y';
                p_error_code    := '1';
                p_error_desc    := chr(10) ||
                                   'EXCEPTION_MRC_CURRENCY_AMOUNT : Missing currency rate for CUSTOMER_TRX_ID = ' ||
                                   strat_invoices_ind.DOCUMENT_ID || ' . ' ||
                                   sqlerrm;
                message(p_error_desc);
            end;
        end;
      
        l_row := strat_invoices_ind.OPERATING_BUSINESS_UNIT_ID || ',' ||
                 strat_invoices_ind.OPERATING_BUSINESS_UNIT_NAME || ',' ||
                 strat_invoices_ind.SOURCE_SYSTEM_INSTANCE || ',' ||
                 strat_invoices_ind.SOLD_TO_BUYER_ID || ',' ||
                 strat_invoices_ind.SOLD_TO_BUYER_SITE || ',' ||
                 strat_invoices_ind.DOCUMENT_ID || ',' ||
                 XXAR_OPYO_PKG.remove_special_char(strat_invoices_ind.DOCUMENT_NUMBER) || ',' ||
                 XXAR_OPYO_PKG.remove_special_char(strat_invoices_ind.REFERENCE_NUMBER) || ',' ||
                 strat_invoices_ind.JOURNAL_LINE || ',' ||
                 strat_invoices_ind.CREATION_DATE || ',' ||
                 strat_invoices_ind.LAST_UPDATE_DATE || ',' ||
                 strat_invoices_ind.TRANSACTION_DATE || ',' ||
                 strat_invoices_ind.DUE_DATE || ',' || l_gl_date || ',' || -- added by Roman W. 20/10/2020 INC0209542
                 l_gl_posted_date || ',' || -- added by Roman W. 20/10/2020 INC0209542
                 l_closed_date || ',' || -- added by Roman W. 20/10/2020 INC0209542
                 l_gl_closed_date || ',' || -- added by Roman W. 20/10/2020 INC0209542
                 strat_invoices_ind.TRANSACTION_TYPE_ID || ',' ||
                 XXAR_OPYO_PKG.remove_special_char(strat_invoices_ind.TRANSACTION_TYPE) || ',' ||
                 strat_invoices_ind.TRANS_ORIGINAL_CURRENCY_CODE || ',' ||
                 strat_invoices_ind.TRANSACTONAL_ORIGINAL_CURRENCY || ',' ||
                 strat_invoices_ind.FUNCTIONAL_CURRENCY_CODE || ',' ||
                 strat_invoices_ind.FUNCTIONAL_CURRENCY || ',' ||
                 strat_invoices_ind.MRC_CURRENCY_CODE || ',' ||
                 strat_invoices_ind.MRC_CURRENCY || ',' ||
                 l_amount_trans_original_cur || ',' || -- added by Roman W. 20/10/2020 INC0209542
                 l_amount_functional_currency || ',' || -- added by Roman W. 20/10/2020 INC0209542
                 l_MRC_CURRENCY_AMOUNT || ',' ||
                 strat_invoices_ind.CANCELLATION_DATE || ',' ||
                 strat_invoices_ind.CANCELLATION_FLAG || ',' ||
                 strat_invoices_ind.REVERSED_FLAG || ',' ||
                 strat_invoices_ind.REVERSE_REF_TRANSACTION_ID || ',' ||
                 strat_invoices_ind.SITE_ID_SHIPPING_FROM || ',' ||
                 strat_invoices_ind.SITE_NAME_SHIPPING_FROM || ',' ||
                 strat_invoices_ind.SHIP_TO_BUYER_ID || ',' ||
                 strat_invoices_ind.SHIP_TO_SITE_ID || ',' ||
                 strat_invoices_ind.SHIP_TO_BUYER_SITE_NAME || ',' ||
                 strat_invoices_ind.PAYMENT_TERMS_ID || ',' ||
                 XXAR_OPYO_PKG.remove_special_char(strat_invoices_ind.PAYMENT_TERMS_NAME) || ',' ||
                 XXAR_OPYO_PKG.remove_special_char(strat_invoices_ind.PAYMENT_TERMS_LONG_DESC) || ',' ||
                 l_intercompany || ',' || -- added by Roman W. 20/10/2020 INC0209542
                 strat_invoices_ind.MRC_EXCH_RATE || ',' ||
                 strat_invoices_ind.BILL_TO_BUYER_ID || ',' ||
                 strat_invoices_ind.BILL_TO_CUSTOMER_SITE || ',' ||
                 strat_invoices_ind.TRANSACTION_CLASS_ID || ',' ||
                 strat_invoices_ind.TRANSACTION_CLASS || ',' ||
                 strat_invoices_ind.TRANSACTION_LAST_UPDATE_DATE || ',' ||
                 l_accounting_segments || ',' || -- added  by Roman W. 20/10/2020 INC0209542
                 strat_invoices_ind.DATA_EXTRACT_DATE || ',' ||
                 strat_invoices_ind.FILE_CREATION_DATE || chr(10);
      
        DBMS_LOB.append(p_clob, l_row);
      exception
        when others then
          message('EXCEPTION_CLOB_APPEND : ' || l_row);
          p_error_code := '2';
          p_error_desc := 'EXCEPTION_CLOB_APPEND : ' || l_row || ' . ' ||
                          sqlerrm;
      end;
    end loop;
  
  exception
    when others then
    
      p_error_code := '2';
      p_error_desc := 'EXCEPTION_OTHERS XXAR_OPYO_PKG.get_strat_invoices_clob() - ' ||
                      sqlerrm;
      message(p_error_desc);
    
  end get_strat_invoices_clob;
  /* rem by Roman W. as a part of performance improvement 21/10/2020 CHG0048802
  -----------------------------------------------------------------------------------------------------
  -- Ver   When         Who         Descr
  -- ----  -----------  ----------  -------------------------------------------------------------------
  -- 1.0   12/08/2020   Roman W.    CHG0048031- Daily upload of customer open balances to OPYO BI tool
  -----------------------------------------------------------------------------------------------------
  procedure get_strat_invoices_clob(p_error_code OUT VARCHAR2,
                                    p_error_desc OUT VARCHAR2,
                                    p_clob       OUT CLOB) is
    ------------------------
    --  Local Definition
    ------------------------
    cursor strat_invoices_cur is
      select rt.org_id OPERATING_BUSINESS_UNIT_ID,
             hu.name OPERATING_BUSINESS_UNIT_NAME,
             'Oracle' SOURCE_SYSTEM_INSTANCE,
             rt.sold_to_customer_id SOLD_TO_BUYER_ID,
             rt.sold_to_site_use_id SOLD_TO_BUYER_SITE,
             rt.customer_trx_id DOCUMENT_ID,
             rt.trx_number DOCUMENT_NUMBER,
             rt.interface_header_attribute1 REFERENCE_NUMBER,
             null JOURNAL_LINE,
             to_char(rt.creation_date, 'dd-Mon-yyyy hh:mm') CREATION_DATE,
             to_char(rt.last_update_date, 'dd-Mon-yyyy hh:mm') LAST_UPDATE_DATE,
             to_char(rt.trx_date, 'dd-Mon-yyyy hh:mm') TRANSACTION_DATE,
             (select to_char(min(apsa.due_date), 'dd-Mon-yyyy hh:mm')
                from ar_payment_schedules_all apsa
               where apsa.customer_trx_id = rt.customer_trx_id) DUE_DATE,
             (select to_char(rctd.gl_date, 'dd-Mon-yyyy hh:mm')
                from ra_cust_trx_line_gl_dist_all rctd
               where rctd.customer_trx_id = rt.customer_trx_id
                 and rctd.account_class = 'REC'
                 and rctd.latest_rec_flag = 'Y') GL_DATE,
             (select to_char(rctd.gl_posted_date, 'dd-Mon-yyyy hh:mm')
                from ra_cust_trx_line_gl_dist_all rctd
               where rctd.customer_trx_id = rt.customer_trx_id
                 and rctd.account_class = 'REC'
                 and rctd.latest_rec_flag = 'Y') GL_POSTED_DATE,
  
             case
               when (select count(1)
                       from ar_payment_schedules_all apsa
                      where apsa.customer_trx_id = rt.customer_trx_id
                        and apsa.status = 'OP') > 0 then
                null
               else
                (select to_char(max(apsa.actual_date_closed),
                                'dd-Mon-yyyy hh:mm')
                   from ar_payment_schedules_all apsa
                  where apsa.customer_trx_id = rt.customer_trx_id)
  
             end CLOSED_DATE,
             case
               when (select count(1)
                       from ar_payment_schedules_all apsa
                      where apsa.customer_trx_id = rt.customer_trx_id
                        and apsa.status = 'OP') > 0 then
                null
               else
                (select to_char(max(apsa.gl_date_closed), 'dd-Mon-yyyy hh:mm')
                   from ar_payment_schedules_all apsa
                  where apsa.customer_trx_id = rt.customer_trx_id)
  
             end GL_CLOSED_DATE,
             rt.cust_trx_type_id TRANSACTION_TYPE_ID,
             rtt.name TRANSACTION_TYPE,
             rt.invoice_currency_code "TRANS_ORIGINAL_CURRENCY_CODE",
             null TRANSACTONAL_ORIGINAL_CURRENCY,
             gll.currency_code FUNCTIONAL_CURRENCY_CODE,
             null FUNCTIONAL_CURRENCY,
             'USD' MRC_CURRENCY_CODE,
             null MRC_CURRENCY,
             (select rctd.amount
                from ra_cust_trx_line_gl_dist_all rctd
               where rctd.customer_trx_id = rt.customer_trx_id
                 and rctd.account_class = 'REC'
                 and rctd.latest_rec_flag = 'Y') AMOUNT_TRANS_ORIGINAL_CURRENCY,
             (select rctd.acctd_amount
                from ra_cust_trx_line_gl_dist_all rctd
               where rctd.customer_trx_id = rt.customer_trx_id
                 and rctd.account_class = 'REC'
                 and rctd.latest_rec_flag = 'Y') AMOUNT_FUNCTIONAL_CURRENCY,
             least(sysdate, nvl(rt.exchange_date, rt.trx_date)) rt_exchange_trx_date,
             null CANCELLATION_DATE,
             null CANCELLATION_FLAG,
             null REVERSED_FLAG,
             null REVERSE_REF_TRANSACTION_ID,
             null SITE_ID_SHIPPING_FROM,
             null SITE_NAME_SHIPPING_FROM,
             rt.ship_to_customer_id SHIP_TO_BUYER_ID,
             rt.ship_to_site_use_id SHIP_TO_SITE_ID,
             null SHIP_TO_BUYER_SITE_NAME,
             terms.term_id PAYMENT_TERMS_ID,
             terms.name PAYMENT_TERMS_NAME,
             terms.description PAYMENT_TERMS_LONG_DESC,
             case
               when (select gcc.segment7
                       from ra_cust_trx_line_gl_dist_all rctd,
                            xla_distribution_links       xdl,
                            xla_ae_lines                 xll,
                            gl_code_combinations         gcc
                      where rctd.customer_trx_id = rt.customer_trx_id
                        and xll.ledger_id = rt.set_of_books_id
                        and rctd.account_class = 'REC'
                        and rctd.latest_rec_flag = 'Y'
                        and xdl.application_id = 222
                        and xdl.source_distribution_id_num_1 =
                            rctd.cust_trx_line_gl_dist_id
                        and xdl.source_distribution_type =
                            'RA_CUST_TRX_LINE_GL_DIST_ALL'
                        and xdl.accounting_line_code = 'INV_DEFAULT_REC'
                        and xll.ae_header_id = xdl.ae_header_id
                        and xll.ae_line_num = xdl.ae_line_num
                        and gcc.code_combination_id = xll.code_combination_id) = '00' then
                'N'
               else
                'Y'
             end INTERCOMPANY,
             null MRC_EXCH_RATE,
             rt.bill_to_customer_id BILL_TO_BUYER_ID,
             rt.bill_to_site_use_id BILL_TO_CUSTOMER_SITE,
             rtt.type TRANSACTION_CLASS_ID,
             fl.MEANING TRANSACTION_CLASS,
             null TRANSACTION_LAST_UPDATE_DATE,
             (select gcc.concatenated_segments
                from ra_cust_trx_line_gl_dist_all rctd,
                     xla_distribution_links       xdl,
                     xla_ae_lines                 xll,
                     gl_code_combinations_kfv     gcc
               where rctd.customer_trx_id = rt.customer_trx_id
                 and xll.ledger_id = rt.set_of_books_id
                 and rctd.account_class = 'REC'
                 and rctd.latest_rec_flag = 'Y'
                 and xdl.application_id = 222
                 and xdl.source_distribution_id_num_1 =
                     rctd.cust_trx_line_gl_dist_id
                 and xdl.source_distribution_type =
                     'RA_CUST_TRX_LINE_GL_DIST_ALL'
                 and xdl.accounting_line_code = 'INV_DEFAULT_REC'
                 and xll.ae_header_id = xdl.ae_header_id
                 and xll.ae_line_num = xdl.ae_line_num
                 and gcc.code_combination_id = xll.code_combination_id) ACCOUNTING_SEGMENTS,
             to_char(sysdate, 'dd-Mon-yyyy hh:mm') DATA_EXTRACT_DATE,
             to_char(sysdate, 'dd-Mon-yyyy hh:mm') FILE_CREATION_DATE
        from ra_customer_trx_all   rt,
             ra_cust_trx_types_all rtt,
             fnd_lookups           fl,
             gl_ledgers            gll,
             hr_operating_units    hu,
             ra_terms_tl           terms
       where exists
       (select 1
                from ar_payment_schedules_all asa
               where asa.customer_trx_id = rt.customer_trx_id
                 and asa.actual_date_closed > add_months(sysdate, -36))
         and rtt.cust_trx_type_id = rt.cust_trx_type_id
         and fl.LOOKUP_type = 'JEBE_AR_OF_TRANS_TYPE'
         and fl.LOOKUP_CODE = rtt.type
         and gll.ledger_id = rt.set_of_books_id
         and hu.organization_id = rt.org_id
         and rt.term_id = terms.term_id(+)
         and terms.language(+) = 'US'
         and rt.org_id <> 89
         and rtt.org_id <> 89;
    -- and rt.trx_number='1008572'
    -- and rt.customer_trx_id=8561408
    --and rtt.type='INV'"
  
    l_row                 varchar2(32000);
    l_continue_flag       varchar2(10);
    l_mrc_currency_amount number;
    --    l_date                date;
    l_exchange_trx_date date;
    ------------------------
    --  Code Section
    ------------------------
  begin
    message('Start get_strat_invoices_clob');
    p_error_code := '0';
    p_error_desc := null;
  
    p_clob := EMPTY_CLOB();
  
    dbms_lob.createtemporary(lob_loc => p_clob,
                             cache   => TRUE,
                             dur     => DBMS_LOB.SESSION);
  
    l_row := 'OPERATING_BUSINESS_UNIT_ID,OPERATING_BUSINESS_UNIT_NAME,SOURCE_SYSTEM_INSTANCE,SOLD_TO_BUYER_ID,SOLD_TO_BUYER_SITE,DOCUMENT_ID,DOCUMENT_NUMBER,REFERENCE_NUMBER,JOURNAL_LINE,CREATION_DATE,LAST_UPDATE_DATE,TRANSACTION_DATE,DUE_DATE,GL_DATE,GL_POSTED_DATE,CLOSED_DATE,GL_CLOSED_DATE,TRANSACTION_TYPE_ID,TRANSACTION_TYPE,TRANS_ORIGINAL_CURRENCY_CODE,TRANSACTONAL_ORIGINAL_CURRENCY,FUNCTIONAL_CURRENCY_CODE,FUNCTIONAL_CURRENCY,MRC_CURRENCY_CODE,MRC_CURRENCY,AMOUNT_TRANS_ORIGINAL_CURRENCY,AMOUNT_FUNCTIONAL_CURRENCY,MRC_CURRENCY_AMOUNT,CANCELLATION_DATE,CANCELLATION_FLAG,REVERSED_FLAG,REVERSE_REF_TRANSACTION_ID,SITE_ID_SHIPPING_FROM,SITE_NAME_SHIPPING_FROM,SHIP_TO_BUYER_ID,SHIP_TO_SITE_ID,SHIP_TO_BUYER_SITE_NAME,PAYMENT_TERMS_ID,PAYMENT_TERMS_NAME,PAYMENT_TERMS_LONG_DESC,INTERCOMPANY,MRC_EXCH_RATE,BILL_TO_BUYER_ID,BILL_TO_CUSTOMER_SITE,TRANSACTION_CLASS_ID,TRANSACTION_CLASS,TRANSACTION_LAST_UPDATE_DATE,ACCOUNTING_SEGMENTS,DATA_EXTRACT_DATE,FILE_CREATION_DATE' ||
             chr(10);
  
    DBMS_LOB.append(p_clob, l_row);
  
    for strat_invoices_ind in strat_invoices_cur loop
      begin
        l_continue_flag := 'N';
        begin
  
          select round(rctd.amount *
                       gl_currency_api.get_closest_rate(strat_invoices_ind.TRANS_ORIGINAL_CURRENCY_CODE,
                                                        'USD',
                                                        strat_invoices_ind.rt_exchange_trx_date,
                                                        'Corporate',
                                                        10),
                       2)
            into l_mrc_currency_amount
            from ra_cust_trx_line_gl_dist_all rctd
           where rctd.customer_trx_id = strat_invoices_ind.document_id
             and rctd.account_class = 'REC'
             and rctd.latest_rec_flag = 'Y';
  
        exception
          when others then
            begin
              l_exchange_trx_date := xxar_opyo_pkg.get_closest_conversion_rate(p_date            => strat_invoices_ind.rt_exchange_trx_date,
                                                                               p_from            => strat_invoices_ind.TRANS_ORIGINAL_CURRENCY_CODE,
                                                                               p_to              => 'USD',
                                                                               p_conversion_type => 'Corporate');
              select round(rctd.amount *
                           gl_currency_api.get_closest_rate(strat_invoices_ind.TRANS_ORIGINAL_CURRENCY_CODE,
                                                            'USD',
                                                            l_exchange_trx_date,
                                                            'Corporate',
                                                            10),
                           2)
                into l_mrc_currency_amount
                from ra_cust_trx_line_gl_dist_all rctd
               where rctd.customer_trx_id = strat_invoices_ind.document_id
                 and rctd.account_class = 'REC'
                 and rctd.latest_rec_flag = 'Y';
            exception
              when others then
                l_continue_flag := 'Y';
                p_error_code    := '1';
                p_error_desc    := chr(10) ||
                                   'EXCEPTION_MRC_CURRENCY_AMOUNT : Missing currency rate for CUSTOMER_TRX_ID = ' ||
                                   strat_invoices_ind.DOCUMENT_ID || ' . ' ||
                                   sqlerrm;
                message(p_error_desc);
            end;
        end;
        l_row := strat_invoices_ind.OPERATING_BUSINESS_UNIT_ID || ',' ||
                 strat_invoices_ind.OPERATING_BUSINESS_UNIT_NAME || ',' ||
                 strat_invoices_ind.SOURCE_SYSTEM_INSTANCE || ',' ||
                 strat_invoices_ind.SOLD_TO_BUYER_ID || ',' ||
                 strat_invoices_ind.SOLD_TO_BUYER_SITE || ',' ||
                 strat_invoices_ind.DOCUMENT_ID || ',' ||
                 XXAR_OPYO_PKG.remove_special_char(strat_invoices_ind.DOCUMENT_NUMBER) || ',' ||
                 XXAR_OPYO_PKG.remove_special_char(strat_invoices_ind.REFERENCE_NUMBER) || ',' ||
                 strat_invoices_ind.JOURNAL_LINE || ',' ||
                 strat_invoices_ind.CREATION_DATE || ',' ||
                 strat_invoices_ind.LAST_UPDATE_DATE || ',' ||
                 strat_invoices_ind.TRANSACTION_DATE || ',' ||
                 strat_invoices_ind.DUE_DATE || ',' ||
                 strat_invoices_ind.GL_DATE || ',' ||
                 strat_invoices_ind.GL_POSTED_DATE || ',' ||
                 strat_invoices_ind.CLOSED_DATE || ',' ||
                 strat_invoices_ind.GL_CLOSED_DATE || ',' ||
                 strat_invoices_ind.TRANSACTION_TYPE_ID || ',' ||
                 XXAR_OPYO_PKG.remove_special_char(strat_invoices_ind.TRANSACTION_TYPE) || ',' ||
                 strat_invoices_ind.TRANS_ORIGINAL_CURRENCY_CODE || ',' ||
                 strat_invoices_ind.TRANSACTONAL_ORIGINAL_CURRENCY || ',' ||
                 strat_invoices_ind.FUNCTIONAL_CURRENCY_CODE || ',' ||
                 strat_invoices_ind.FUNCTIONAL_CURRENCY || ',' ||
                 strat_invoices_ind.MRC_CURRENCY_CODE || ',' ||
                 strat_invoices_ind.MRC_CURRENCY || ',' ||
                 strat_invoices_ind.AMOUNT_TRANS_ORIGINAL_CURRENCY || ',' ||
                 strat_invoices_ind.AMOUNT_FUNCTIONAL_CURRENCY || ',' ||
                -- strat_invoices_ind.MRC_CURRENCY_AMOUNT || ',' || -- rem by Roman W.
                 l_MRC_CURRENCY_AMOUNT || ',' ||
                 strat_invoices_ind.CANCELLATION_DATE || ',' ||
                 strat_invoices_ind.CANCELLATION_FLAG || ',' ||
                 strat_invoices_ind.REVERSED_FLAG || ',' ||
                 strat_invoices_ind.REVERSE_REF_TRANSACTION_ID || ',' ||
                 strat_invoices_ind.SITE_ID_SHIPPING_FROM || ',' ||
                 strat_invoices_ind.SITE_NAME_SHIPPING_FROM || ',' ||
                 strat_invoices_ind.SHIP_TO_BUYER_ID || ',' ||
                 strat_invoices_ind.SHIP_TO_SITE_ID || ',' ||
                 strat_invoices_ind.SHIP_TO_BUYER_SITE_NAME || ',' ||
                 strat_invoices_ind.PAYMENT_TERMS_ID || ',' ||
                 XXAR_OPYO_PKG.remove_special_char(strat_invoices_ind.PAYMENT_TERMS_NAME) || ',' ||
                 XXAR_OPYO_PKG.remove_special_char(strat_invoices_ind.PAYMENT_TERMS_LONG_DESC) || ',' ||
                 strat_invoices_ind.INTERCOMPANY || ',' ||
                 strat_invoices_ind.MRC_EXCH_RATE || ',' ||
                 strat_invoices_ind.BILL_TO_BUYER_ID || ',' ||
                 strat_invoices_ind.BILL_TO_CUSTOMER_SITE || ',' ||
                 strat_invoices_ind.TRANSACTION_CLASS_ID || ',' ||
                 strat_invoices_ind.TRANSACTION_CLASS || ',' ||
                 strat_invoices_ind.TRANSACTION_LAST_UPDATE_DATE || ',' ||
                 strat_invoices_ind.ACCOUNTING_SEGMENTS || ',' ||
                 strat_invoices_ind.DATA_EXTRACT_DATE || ',' ||
                 strat_invoices_ind.FILE_CREATION_DATE || chr(10);
  
        DBMS_LOB.append(p_clob, l_row);
      exception
        when others then
          message('EXCEPTION_CLOB_APPEND : ' || l_row);
          p_error_code := '2';
          p_error_desc := 'EXCEPTION_CLOB_APPEND : ' || l_row || ' . ' ||
                          sqlerrm;
      end;
    end loop;
  
  exception
    when others then
  
      p_error_code := '2';
      p_error_desc := 'EXCEPTION_OTHERS XXAR_OPYO_PKG.get_strat_invoices_clob() - ' ||
                      sqlerrm;
      message(p_error_desc);
  end get_strat_invoices_clob;
  */
  -----------------------------------------------------------------------------------------------------
  -- Ver   When         Who         Descr
  -- ----  -----------  ----------  -------------------------------------------------------------------
  -- 1.0   12/08/2020   Roman W.    CHG0048031- Daily upload of customer open balances to OPYO BI tool
  -----------------------------------------------------------------------------------------------------
  procedure get_strat_reciepts_clob(p_error_code OUT VARCHAR2,
                                    p_error_desc OUT VARCHAR2,
                                    p_clob       OUT CLOB) is
    ------------------------
    --  Local Definition
    ------------------------
    cursor strat_reciepts_cur is
      SELECT ROWNUM XX_ROWNUM,
             CR.ORG_ID OPERATING_BUSINESS_UNIT_ID,
             hu.name OPERATING_BUSINESS_UNIT_NAME,
             'Oracle' SOURCE_SYSTEM_INSTANCE,
             CR.CASH_RECEIPT_ID RECEIPT_ID,
             rt.trx_number DOCUMENT_ID,
             rt.customer_trx_id BUYER_TRX_ID,
             CR.RECEIPT_NUMBER DOCUMENT_NUMBER,
             to_char(cr.creation_date, 'dd-Mon-yyyy hh:mm') creation_date,
             to_char(cr.last_update_date, 'dd-Mon-yyyy hh:mm') last_update_date,
             to_char(CR.RECEIPT_DATE, 'dd-Mon-yyyy hh:mm') TRANSACTION_DATE,
             to_char(ps.DUE_DATE, 'dd-Mon-yyyy hh:mm') DUE_DATE,
             to_char(hist.gl_date, 'dd-Mon-yyyy hh:mm') gl_date,
             to_char(hist.gl_posted_date, 'dd-Mon-yyyy hh:mm') gl_posted_date,
             case
               when hist.status = 'CLEARED' then
                to_char(HIST.Trx_Date, 'dd-Mon-yyyy hh:mm')
               else
                null
             end CLEARED_DATE,
             ARM.RECEIPT_METHOD_ID TRANSACTION_TYPE_ID,
             ARM.NAME TRANSACTION_TYPE,
             cr.currency_code TRANS_ORG_CURRENCY_CODE,
             null TRANSACTONAL_ORIGINAL_CURRENCY,
             gll.currency_code FUNCTIONAL_CURRENCY_CODE,
             null FUNCTIONAL_CURRENCY,
             'USD' MRC_CURRENCY_CODE,
             null MRC_CURRENCY,
             cr.amount AMOUNT_TRANS_ORIGINAL_CURRENCY,
             /*------------ Added By Roman --------------*/
             cr.amount cr_amount,
             cr.currency_code cr_currency_code,
             gll.currency_code gll_currency_code,
             least(sysdate, cr.receipt_date) cr_receipt_date,
             0 AMOUNT_FUNCTIONAL_CURRENCY,
             0 AMOUNT_MRC_CURRENCY,
             app.amount_applied APPLIED_AMOUNT_TRANS_ORIG_CURR,
             null APPLIED_AMOUNT_FUNCT_CURRENCY,
             null APPLIED_AMOUNT_MRC_CURRENCY,
             case
               when hist.status = 'REVERSED' then
                'Y'
               else
                'N'
             end REVERSED_FLAG,
             to_char(cr.reversal_date, 'dd-Mon-yyyy hh:mm') REVERSED_DATE,
             null TRANSACTION_CLASS_ID,
             RC.NAME TRANSACTION_CLASS,
             null TRANSACTION_LAST_UPDATE_DATE,
             (select sum(TO_NUMBER(DECODE(SIGN(APP.APPLIED_PAYMENT_SCHEDULE_ID),
                                          -1,
                                          NULL,
                                          APP.ACCTD_AMOUNT_APPLIED_FROM -
                                          NVL(APP.ACCTD_AMOUNT_APPLIED_TO,
                                              APP.ACCTD_AMOUNT_APPLIED_FROM))))
                from Ar_Receivable_Applications_all APP
               where APP.Cash_Receipt_Id = hist.cash_receipt_id) EXCHANGE_GAIN_LOSS,
             to_char(sysdate, 'dd-Mon-yyyy hh:mm') DATA_EXTRACT_DATE,
             to_char(sysdate, 'dd-Mon-yyyy hh:mm') FILE_CREATION_DATE,
             gcc.concatenated_segments ACCOUNTING_SEGMENTS,
             to_char(app.apply_date, 'dd-Mon-yyyy') APPLY_DATE,
             to_char(app.gl_date, 'dd-Mon-yyyy') APPLY_GL_DATE
        FROM AR_RECEIPT_METHODS             ARM,
             AR_CASH_RECEIPTS_ALL           CR,
             AR_RECEIPT_CLASSES             RC,
             AR_CASH_RECEIPT_HISTORY_ALL    HIST,
             AR_PAYMENT_SCHEDULES_ALL       ps,
             gl_ledgers                     gll,
             hr_operating_units             hu,
             hz_cust_site_uses_all          hCU,
             HZ_CUST_ACCT_SITES_ALL         hcs,
             gl_code_combinations_kfv       gcc,
             AR_RECEIVABLE_APPLICATIONS_ALL app,
             ra_customer_trx_all            rt
       WHERE CR.RECEIPT_METHOD_ID = ARM.RECEIPT_METHOD_ID
         and cr.type != 'MISC'
         AND CR.RECEIPT_DATE > add_months(SYSDATE, -36)
         AND RC.RECEIPT_CLASS_ID = ARM.RECEIPT_CLASS_ID
         AND HIST.Cash_Receipt_Id = CR.CASH_RECEIPT_ID
         AND HIST.CURRENT_RECORD_FLAG = NVL('Y', CR.RECEIPT_NUMBER)
         AND PS.CASH_RECEIPT_ID(+) = CR.CASH_RECEIPT_ID
         AND PS.ORG_ID(+) = CR.ORG_ID
         and cr.set_of_books_id = gll.ledger_id
         and hu.organization_id = CR.ORG_ID
         AND hCU.SITE_USE_ID(+) = Cr.Customer_Site_Use_Id
         and hcs.cust_acct_site_id(+) = hcu.cust_acct_site_id
         and hist.account_code_combination_id = gcc.code_combination_id
         and app.cash_receipt_id(+) = cr.cash_receipt_id
         and app.status(+) = 'APP'
         and app.applied_customer_trx_id = rt.customer_trx_id(+)
         and CR.org_id <> 89
         and hcs.org_id <> 89
         and app.org_id <> 89
         and rt.org_id <> 89;
  
    l_row VARCHAR2(32000);
  
    l_amount_functional_currency number;
    l_amount_mrc_currency        number;
    l_continue_flag              varchar2(10);
    l_receipt_date               date;
    ------------------------
    --  Code Section
    ------------------------
  begin
    p_error_code := '0';
    p_error_desc := null;
  
    p_clob := EMPTY_CLOB();
  
    dbms_lob.createtemporary(lob_loc => p_clob,
                             cache   => TRUE,
                             dur     => DBMS_LOB.SESSION);
    l_row := 'OPERATING_BUSINESS_UNIT_ID,OPERATING_BUSINESS_UNIT_NAME,SOURCE_SYSTEM_INSTANCE,RECEIPT_ID,DOCUMENT_ID,BUYER_TRX_ID,DOCUMENT_NUMBER,creation_date,last_update_date,TRANSACTION_DATE,DUE_DATE,GL_DATE,GL_POSTED_DATE,CLEARED_DATE,TRANSACTION_TYPE_ID,TRANSACTION_TYPE,TRANS_ORG_CURRENCY_CODE,TRANSACTONAL_ORIGINAL_CURRENCY,FUNCTIONAL_CURRENCY_CODE,FUNCTIONAL_CURRENCY,MRC_CURRENCY_CODE,MRC_CURRENCY,AMOUNT_TRANS_ORIGINAL_CURRENCY,AMOUNT_FUNCTIONAL_CURRENCY,AMOUNT_MRC_CURRENCY,APPLIED_AMOUNT_TRANS_ORIG_CURR,APPLIED_AMOUNT_FUNCT_CURRENCY,APPLIED_AMOUNT_MRC_CURRENCY,REVERSED_FLAG,REVERSED_DATE,TRANSACTION_CLASS_ID,TRANSACTION_CLASS,TRANSACTION_LAST_UPDATE_DATE,EXCHANGE_GAIN_LOSS,DATA_EXTRACT_DATE,FILE_CREATION_DATE,ACCOUNTING_SEGMENTS,APPLY_DATE,APPLY_GL_DATE' ||
             chr(10);
  
    DBMS_LOB.append(p_clob, l_row);
    for strat_reciepts_ind in strat_reciepts_cur loop
      begin
        l_continue_flag := 'N';
      
        begin
          l_amount_functional_currency := round(strat_reciepts_ind.cr_amount *
                                                gl_currency_api.get_closest_rate(strat_reciepts_ind.cr_currency_code,
                                                                                 strat_reciepts_ind.gll_currency_code,
                                                                                 strat_reciepts_ind.cr_receipt_date,
                                                                                 'Corporate',
                                                                                 10));
        exception
          when others then
            begin
              l_receipt_date := xxar_opyo_pkg.get_closest_conversion_rate(p_from            => strat_reciepts_ind.cr_currency_code,
                                                                          p_to              => strat_reciepts_ind.gll_currency_code,
                                                                          p_date            => strat_reciepts_ind.cr_receipt_date,
                                                                          p_conversion_type => 'Corporate');
            
              l_amount_functional_currency := round(strat_reciepts_ind.cr_amount *
                                                    gl_currency_api.get_closest_rate(strat_reciepts_ind.cr_currency_code,
                                                                                     strat_reciepts_ind.gll_currency_code,
                                                                                     l_receipt_date,
                                                                                     'Corporate',
                                                                                     10));
            exception
              when others then
                l_continue_flag := 'Y';
                p_error_code    := '1';
                p_error_desc    := 'EXCEPTION_AMOUNT_FUNCTIONAL_CURRENCY (' ||
                                   strat_reciepts_ind.xx_rownum ||
                                   ') Missing currency rate : round(' ||
                                   strat_reciepts_ind.cr_amount || ' * ' ||
                                   chr(10) ||
                                   ' gl_currency_api.get_closest_rate(' ||
                                   strat_reciepts_ind.cr_currency_code || ',' ||
                                   chr(10) ||
                                   strat_reciepts_ind.gll_currency_code || ',' ||
                                   chr(10) ||
                                   strat_reciepts_ind.cr_receipt_date || ',' ||
                                   chr(10) || 'Corporate, 10)) - ' ||
                                   sqlerrm;
                message(p_error_desc);
            end;
        end;
      
        begin
          l_amount_mrc_currency := round(strat_reciepts_ind.cr_amount *
                                         gl_currency_api.get_closest_rate(strat_reciepts_ind.cr_currency_code,
                                                                          'USD',
                                                                          strat_reciepts_ind.cr_receipt_date,
                                                                          'Corporate',
                                                                          10));
        exception
          when others then
            begin
              l_receipt_date := xxar_opyo_pkg.get_closest_conversion_rate(p_from            => strat_reciepts_ind.cr_currency_code,
                                                                          p_to              => 'USD',
                                                                          p_date            => strat_reciepts_ind.cr_receipt_date,
                                                                          p_conversion_type => 'Corporate');
            
              l_amount_mrc_currency := round(strat_reciepts_ind.cr_amount *
                                             gl_currency_api.get_closest_rate(strat_reciepts_ind.cr_currency_code,
                                                                              'USD',
                                                                              l_receipt_date,
                                                                              'Corporate',
                                                                              10));
            exception
              when others then
                l_continue_flag := 'Y';
                p_error_code    := '1';
                p_error_desc    := 'EXCEPTION_AMOUNT_MRC_CURRENCY(' ||
                                   strat_reciepts_ind.xx_rownum ||
                                   ') Missing currency rate : round(' ||
                                   strat_reciepts_ind.cr_amount || ' * ' ||
                                   chr(10) ||
                                   ' gl_currency_api.get_closest_rate(' ||
                                   strat_reciepts_ind.cr_currency_code || ',' ||
                                   chr(10) || 'USD' || ',' || chr(10) ||
                                   strat_reciepts_ind.cr_receipt_date || ',' ||
                                   chr(10) || 'Corporate, 10)) - ' ||
                                   sqlerrm;
                message(p_error_desc);
            end;
          
        end;
        if 'N' = l_continue_flag then
          l_row := strat_reciepts_ind.OPERATING_BUSINESS_UNIT_ID || ',' ||
                   strat_reciepts_ind.OPERATING_BUSINESS_UNIT_NAME || ',' ||
                   strat_reciepts_ind.SOURCE_SYSTEM_INSTANCE || ',' ||
                   strat_reciepts_ind.RECEIPT_ID || ',' ||
                   strat_reciepts_ind.DOCUMENT_ID || ',' ||
                   strat_reciepts_ind.BUYER_TRX_ID || ',' ||
                   XXAR_OPYO_PKG.remove_special_char(strat_reciepts_ind.DOCUMENT_NUMBER) || ',' ||
                   strat_reciepts_ind.creation_date || ',' ||
                   strat_reciepts_ind.last_update_date || ',' ||
                   strat_reciepts_ind.TRANSACTION_DATE || ',' ||
                   strat_reciepts_ind.DUE_DATE || ',' ||
                   strat_reciepts_ind.GL_DATE || ',' ||
                   strat_reciepts_ind.GL_POSTED_DATE || ',' ||
                   strat_reciepts_ind.CLEARED_DATE || ',' ||
                   strat_reciepts_ind.TRANSACTION_TYPE_ID || ',' ||
                   strat_reciepts_ind.TRANSACTION_TYPE || ',' ||
                   strat_reciepts_ind.TRANS_ORG_CURRENCY_CODE || ',' ||
                   strat_reciepts_ind.TRANSACTONAL_ORIGINAL_CURRENCY || ',' ||
                   strat_reciepts_ind.FUNCTIONAL_CURRENCY_CODE || ',' ||
                   strat_reciepts_ind.FUNCTIONAL_CURRENCY || ',' ||
                   strat_reciepts_ind.MRC_CURRENCY_CODE || ',' ||
                   strat_reciepts_ind.MRC_CURRENCY || ',' ||
                   strat_reciepts_ind.AMOUNT_TRANS_ORIGINAL_CURRENCY || ',' ||
                   l_AMOUNT_FUNCTIONAL_CURRENCY || ',' || -- Added By R.W.
                   l_AMOUNT_MRC_CURRENCY || ',' || -- Added by R.W.
                   strat_reciepts_ind.APPLIED_AMOUNT_TRANS_ORIG_CURR || ',' ||
                   strat_reciepts_ind.APPLIED_AMOUNT_FUNCT_CURRENCY || ',' ||
                   strat_reciepts_ind.APPLIED_AMOUNT_MRC_CURRENCY || ',' ||
                   strat_reciepts_ind.REVERSED_FLAG || ',' ||
                   strat_reciepts_ind.REVERSED_DATE || ',' ||
                   strat_reciepts_ind.TRANSACTION_CLASS_ID || ',' ||
                   strat_reciepts_ind.TRANSACTION_CLASS || ',' ||
                   strat_reciepts_ind.TRANSACTION_LAST_UPDATE_DATE || ',' ||
                   strat_reciepts_ind.EXCHANGE_GAIN_LOSS || ',' ||
                   strat_reciepts_ind.DATA_EXTRACT_DATE || ',' ||
                   strat_reciepts_ind.FILE_CREATION_DATE || ',' ||
                   strat_reciepts_ind.ACCOUNTING_SEGMENTS || ',' ||
                   strat_reciepts_ind.APPLY_DATE || ',' ||
                   strat_reciepts_ind.APPLY_GL_DATE || chr(10);
        
          DBMS_LOB.append(p_clob, l_row);
        end if;
      exception
        when others then
        
          message('EXCEPTION_LOOP (' || strat_reciepts_ind.xx_rownum ||
                  ') :' || sqlerrm);
          p_error_code := '1';
          p_error_desc := 'EXCEPTION_CLOB_APPEND : ( ' ||
                          strat_reciepts_ind.xx_rownum || ' ) ' || l_row || ' .' ||
                          sqlerrm;
          message(p_error_desc);
      end;
    end loop;
  exception
    when others then
      p_error_code := '2';
      p_error_desc := 'EXCEPTION_OTHERS XXAR_OPYO_PKG.get_strat_reciepts_clob() - ' ||
                      sqlerrm;
  end get_strat_reciepts_clob;
  -----------------------------------------------------------------------------------------------------
  -- CONCURRENT : XXAR_OPYO_FILES_EXTRACTION / XXAR : OPYO open balances file extraction
  -----------------------------------------------------------------------------------------------------
  -- Ver   When         Who         Descr
  -- ----  -----------  ----------  -------------------------------------------------------------------
  -- 1.0   12/08/2020   Roman W.    CHG0048031- Daily upload of customer open balances to OPYO BI tool
  -- 1.2   20/10/2020   Roman W.    CHG0048802 - improve invoice file creation performance
  -----------------------------------------------------------------------------------------------------
  procedure extract_files_prog(errbuf         out varchar2,
                               retcode        out varchar2,
                               p_location     in varchar2,
                               p_arc_location in varchar2,
                               p_file_name    in varchar2) is
    ------------------------
    --   Local Definition
    ------------------------
    lc_strat_buyers_clob   CLOB := EMPTY_CLOB();
    lc_strat_invoices_clob CLOB := EMPTY_CLOB();
    lc_strat_reciepts_clob CLOB := EMPTY_CLOB();
  
    lv_error_code VARCHAR2(10);
    lv_error_desc VARCHAR2(32500);
    ------------------------
    --    Code Section
    ------------------------
  begin
    errbuf  := null;
    retcode := '0';
  
    message('-----------------------------------------------');
    message('-- START : xxar_opyo_pkg.extract_files_prog() --');
    message('p_location : ' || p_location);
    message('p_arc_location : ' || p_arc_location);
    message('-----------------------------------------------');
  
    message('1) Call to xxssys_dpl_pkg.make_directory( p_dir_path  => ' ||
            p_location || chr(10) ||
            '                                         ,p_directory => ' ||
            C_DIRECTORY || ')');
  
    -------------------------------------------------------------
    --                   DIRECTION
    -------------------------------------------------------------
    xxssys_dpl_pkg.make_directory(p_dir_path   => p_location,
                                  p_directory  => C_DIRECTORY,
                                  p_error_code => lv_error_code,
                                  p_error_desc => lv_error_desc);
  
    if '0' != lv_error_code then
      errbuf  := errbuf || chr(10) || lv_error_desc;
      retcode := '2';
      message(errbuf);
    
      return;
    end if;
  
    -------------------------------------------------------------
    --                  ARC DIRECTION
    -------------------------------------------------------------
    xxssys_dpl_pkg.make_directory(p_dir_path   => p_arc_location,
                                  p_directory  => C_ARC_DIRECTORY,
                                  p_error_code => lv_error_code,
                                  p_error_desc => lv_error_desc);
  
    if '0' != lv_error_code then
      errbuf  := errbuf || chr(10) || lv_error_desc;
      retcode := '2';
      message(errbuf);
      return;
    end if;
  
    -------------------------------------------------------------
    --                 STRAT_BUYERS
    -------------------------------------------------------------
    if nvl(p_file_name, C_STRAT_BUYERS_FILE_NAME) =
       C_STRAT_BUYERS_FILE_NAME then
    
      message('directory || ' || C_DIRECTORY || ' ||created SUCCESS');
    
      message('2) Call XXAR_OPYO_PKG.get_strat_buyers_clob()');
      get_strat_buyers_clob(p_error_code => lv_error_code,
                            p_error_desc => lv_error_desc,
                            p_clob       => lc_strat_buyers_clob);
    
      if '2' = lv_error_code then
      
        errbuf  := errbuf || chr(10) || lv_error_desc;
        retcode := '2';
      else
        errbuf  := nvl(lv_error_desc, errbuf);
        retcode := greatest(lv_error_code, retcode);
      
        if lc_strat_buyers_clob = empty_clob() then
          message('2.1) file ' || C_STRAT_BUYERS_FILE_NAME ||
                  ' empty ,not extracted.');
        else
        
          message('2.1) file ' || C_STRAT_BUYERS_FILE_NAME ||
                  ' extraction ');
        
          begin
          
            xxssys_file_util_pkg.save_clob_to_file(p_directory_name => C_DIRECTORY,
                                                   p_file_name      => C_STRAT_BUYERS_FILE_NAME,
                                                   p_clob           => lc_strat_buyers_clob);
          
            message('2.2) zip file ' || C_STRAT_BUYERS_FILE_NAME);
            zip_file(p_location      => p_location,
                     p_file_name     => C_STRAT_BUYERS_FILE_NAME,
                     p_zip_file_name => C_STRAT_BUYERS_FILE_NAME_ZIP,
                     p_error_code    => lv_error_code,
                     p_error_desc    => lv_error_desc);
          
            if '0' != lv_error_code then
              errbuf  := lv_error_desc;
              retcode := greatest(lv_error_code, retcode);
            end if;
          
          exception
            when others then
              lv_error_desc := 'EXCEPTION_OTHERS xxssys_file_util_pkg.save_clob_to_file(' ||
                               C_DIRECTORY || ',' ||
                               C_STRAT_BUYERS_FILE_NAME || ') - ' ||
                               sqlerrm;
              message(lv_error_desc);
            
              errbuf  := lv_error_desc;
              retcode := '2';
          end;
        end if;
      
      end if;
    end if; -- end C_STRAT_BUYERS_FILE_NAME
  
    ----------------------------------------------------------------------------
    --                      STRAT_INVOICES
    ----------------------------------------------------------------------------
  
    if C_STRAT_INVOICES_FILE_NAME =
       nvl(p_file_name, C_STRAT_INVOICES_FILE_NAME) then
    
      message('3) Call XXAR_OPYO_PKG.get_strat_invoices_clob()');
      get_strat_invoices_clob(p_error_code => lv_error_code,
                              p_error_desc => lv_error_desc,
                              p_clob       => lc_strat_invoices_clob);
    
      if '2' = lv_error_code then
        errbuf  := lv_error_desc;
        retcode := lv_error_code;
      else
        retcode := greatest(lv_error_code, retcode);
      
        if lc_strat_invoices_clob = empty_clob() then
        
          message('3.0) file ' || C_STRAT_INVOICES_FILE_NAME ||
                  ' empty ,not extracted.');
        else
        
          message('3.1) file ' || C_STRAT_INVOICES_FILE_NAME ||
                  ' extraction ');
        
          begin
          
            xxssys_file_util_pkg.save_clob_to_file(p_directory_name => C_DIRECTORY,
                                                   p_file_name      => C_STRAT_INVOICES_FILE_NAME,
                                                   p_clob           => lc_strat_invoices_clob);
          
            if '2' = lv_error_code then
              errbuf  := lv_error_desc;
              retcode := lv_error_code;
            else
              message('3.2) zip file ' || C_STRAT_INVOICES_FILE_NAME);
              retcode := greatest(lv_error_code, retcode);
            
              zip_file(p_location      => p_location,
                       p_file_name     => C_STRAT_INVOICES_FILE_NAME,
                       p_zip_file_name => C_STRAT_INVOICES_FILE_NAME_ZIP,
                       p_error_code    => lv_error_code,
                       p_error_desc    => lv_error_desc);
            
              if '0' != lv_error_code then
                errbuf  := errbuf || chr(10) || lv_error_desc;
                retcode := '2';
              end if;
            end if;
          exception
            when others then
              errbuf  := 'EXCEPTION_OTHERS xxssys_file_util_pkg.save_clob_to_file(' ||
                         C_DIRECTORY || ',' || C_STRAT_INVOICES_FILE_NAME ||
                         ') - ' || sqlerrm;
              retcode := '2';
              message(errbuf);
          end;
        end if;
      end if;
    end if;
    -------------------------------------------------------------------
    --                    STRAT_RECIEPTS
    -------------------------------------------------------------------
    if C_STRAT_RECIEPTS_FILE_NAME =
       nvl(p_file_name, C_STRAT_RECIEPTS_FILE_NAME) then
    
      message('4) Call XXAR_OPYO_PKG.get_strat_reciepts_clob()');
      get_strat_reciepts_clob(p_error_code => lv_error_code,
                              p_error_desc => lv_error_desc,
                              p_clob       => lc_strat_reciepts_clob);
    
      if '2' = lv_error_code then
        errbuf  := lv_error_desc;
        retcode := lv_error_code;
      else
        if lc_strat_reciepts_clob = empty_clob() then
        
          message('4.0) file ' || C_STRAT_RECIEPTS_FILE_NAME ||
                  ' empty ,not extracted.');
        else
          retcode := greatest(lv_error_code, retcode);
          message('4.1) file ' || C_STRAT_RECIEPTS_FILE_NAME ||
                  ' extraction ');
        
          begin
          
            xxssys_file_util_pkg.save_clob_to_file(p_directory_name => C_DIRECTORY,
                                                   p_file_name      => C_STRAT_RECIEPTS_FILE_NAME,
                                                   p_clob           => lc_strat_reciepts_clob);
          
            message('4.2) zip file ' || C_STRAT_RECIEPTS_FILE_NAME);
          
            zip_file(p_location      => p_location,
                     p_file_name     => C_STRAT_RECIEPTS_FILE_NAME,
                     p_zip_file_name => C_STRAT_RECIEPTS_FILE_NAME_ZIP,
                     p_error_code    => lv_error_code,
                     p_error_desc    => lv_error_desc);
          
            if '0' != lv_error_code then
              message(lv_error_desc);
              errbuf  := errbuf || chr(10) || lv_error_desc;
              retcode := '2';
            end if;
          
          exception
            when others then
              lv_error_desc := 'EXCEPTION_OTHERS xxssys_file_util_pkg.save_clob_to_file(' ||
                               C_DIRECTORY || ',' ||
                               C_STRAT_RECIEPTS_FILE_NAME || ') - ' ||
                               sqlerrm;
              message(lv_error_desc);
            
              errbuf  := errbuf || chr(10) || lv_error_desc;
              retcode := '2';
          end;
        end if;
      end if;
    end if;
  
  exception
    when others then
      errbuf  := errbuf || chr(10) ||
                 'EXCEPTION_OTHERS XXAR_OPYO_PKG.extract_files_prog(' ||
                 p_location || ') - ' || sqlerrm;
      retcode := '2';
  end extract_files_prog;
end XXAR_OPYO_PKG;
/
