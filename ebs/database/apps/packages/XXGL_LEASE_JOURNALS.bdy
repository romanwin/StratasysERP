create or replace package body XXGL_LEASE_JOURNALS is
  --  g_start_date date;
  --  g_end_date   date;
  --------------------------------------------------------------------
  --  name:            XXGL_LEASE_JOURNALS
  --  create by:       OFER.SUAD
  --  Revision:        1.0
  --  creation date:   13/08/2019
  --------------------------------------------------------------------
  --  purpose :       JE ForLease contract ASC 842 and IFRS 16
  --------------------------------------------------------------------
  --  ver  date        name           desc
  --  1.0    15/08/2011  Ofer Suad     CHG0041583  initial build
  --                                     profiles : XXGL_ASC842_SOURCE
  --                                                XXGL_ASC842_LT_LIABILITY_ACCOUNT'
  --                                                XXGL_ASC842_ASSET_ACCOUNT
  --------------------------------------------------------------------

  -----------------------------------------------------------------------------
  -- Ver     When        Who          Description
  -- ------  ----------  -----------  -----------------------------------------
  -- 1.0     2019-08-27  Roman W.     CHG0041583
  -----------------------------------------------------------------------------    
  procedure message(p_msg in varchar2) is
    ---------------------------------
    --      Local Definition
    ---------------------------------
    l_msg varchar2(2000);
    ---------------------------------
    --      Code Section
    ---------------------------------    
  begin
    l_msg := to_char(sysdate, 'YYYY-MM-DD HH24:MI:SS') || ' - ' || p_msg;
  
    if -1 = fnd_global.conc_request_id then
      dbms_output.put_line(l_msg);
    else
      fnd_file.PUT_LINE(fnd_file.LOG, l_msg);
    end if;
  
  end message;

  -------------------------------------------------------------------
  --  name:            get_contract_avg_pmt
  --  create by:       OFER.SUAD
  --  Revision:        1.0
  --  creation date:   13/08/2019
  --------------------------------------------------------------------
  --  purpose :       Calculate the contract avarage payment amount   
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  13/08/2019  OFER.SUAD   initial build
  --------------------------------------------------------------------
  function get_contract_avg_pmt(l_payment_schedule_id number,
                                p_as_of_date          date,
                                p_from_date           date) return number is
    l_avg_amount   number;
    l_cut_exist    number;
    l_cut_low_date date;
    l_cut_ratio    number;
    l_freq         number;
    l_pmt_count    number;
  
  begin
    select round(sum(fas.payment_amount) / count(payment_amount))
      into l_avg_amount
      from FA_AMORT_SCHEDULES fas
     where fas.payment_schedule_id = l_payment_schedule_id;
  
    select count(*)
      into l_pmt_count
      from FA_AMORT_SCHEDULES fas
     where fas.payment_schedule_id = l_payment_schedule_id
       and fas.payment_date between p_from_date and p_as_of_date;
  
    select (case fls.frequency
             when 'MONTHLY' then
              1
             when 'QUARTERLY' then
              3
             when 'SEMI-ANNUALLY' then
              6
             when 'ANNUALLY' then
              12
             else
              null
           end) freq
      into l_freq
      from FA_LEASE_SCHEDULES fls
     where fls.payment_schedule_id = l_payment_schedule_id;
  
    begin
      select 1
        into l_cut_exist
        from FA_AMORT_SCHEDULES fas
       where fas.payment_schedule_id = l_payment_schedule_id
         and fas.payment_date = p_as_of_date;
    
    exception
      when no_data_found then
        l_cut_exist := 1;
    end;
  
    if l_cut_exist = 1 then
      select max(fas.payment_date)
        into l_cut_low_date
        from FA_AMORT_SCHEDULES fas
       where fas.payment_schedule_id = l_payment_schedule_id
         and fas.payment_date < p_as_of_date;
    
      if l_cut_low_date is null then
        begin
          select fls.lease_inception_date
            into l_cut_low_date
            from fa_lease_schedules fls
           where fls.payment_schedule_id = l_payment_schedule_id;
        exception
          when no_data_found then
            null;
        end;
      end if;
    
      if l_cut_low_date < p_from_date then
        l_cut_low_date := p_from_date - 1;
      end if;
    
      if nvl(l_cut_low_date, p_as_of_date + 1) < p_as_of_date then
        l_cut_ratio := (months_between(p_as_of_date + 1, l_cut_low_date)) /
                       l_freq;
      else
        l_cut_ratio := 1;
      end if;
    end if;
  
    return l_avg_amount *(l_pmt_count + l_cut_ratio);
  
  end get_contract_avg_pmt;
  ----------------------------------------------------------------------
  -------------------------------------------------------------------
  --  name:            get_contract_avg_pmt
  --  create by:       OFER.SUAD
  --  Revision:        1.0
  --  creation date:   13/08/2019
  --------------------------------------------------------------------
  --  purpose :       Check if Journal already crated for the Q   
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  13/08/2019  OFER.SUAD   initial build
  --------------------------------------------------------------------

  function check_je_exits(l_period_name varchar2) return boolean is
  
    l_count number;
  begin
  
    l_count := 0;
  
    select count(1)
      into l_count
      from gl_je_headers gjh, gl_je_sources gjs
     where gjh.period_name = l_period_name
       and gjh.je_source = gjs.je_source_name
       and gjs.user_je_source_name =
           fnd_profile.VALUE('XXGL_ASC842_SOURCE');
  
    message('check_je_exits : ' || l_count);
    if l_count = 0 then
      return false;
    else
      return true;
    end if;
  
  end check_je_exits;
  -------------------------------------------------------------------
  --  name:            get_lease_liability
  --  create by:       OFER.SUAD
  --  Revision:        1.0
  --  creation date:   13/08/2019
  --------------------------------------------------------------------
  --  purpose :       Calculate leablity (Short+Long terms for specific date 
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  13/08/2019  OFER.SUAD   initial build
  --------------------------------------------------------------------       
  function get_lease_liability(l_payment_schedule_id number,
                               p_as_of_date          date) return number is
    l_liability_amt   number;
    l_future_balance  number;
    l_cut_exist       number;
    l_cut_low_date    date;
    l_cut_high_date   date;
    l_cut_amt         number;
    l_cut_low_amount  number;
    l_cut_high_amount number;
    l_rate            number;
  begin
  
    select nvl(sum(fas.principal), 0)
      into l_future_balance
      from FA_AMORT_SCHEDULES fas
     where fas.payment_schedule_id = l_payment_schedule_id
       and fas.payment_date > p_as_of_date;
  
    select interest_rate
      into l_rate
      from fa_lease_schedules fls
     where payment_schedule_id = l_payment_schedule_id;
  
    l_cut_exist := 0;
    l_cut_amt   := 0;
  
    begin
      select 1
        into l_cut_exist
        from FA_AMORT_SCHEDULES fas
       where fas.payment_schedule_id = l_payment_schedule_id
         and fas.payment_date = p_as_of_date;
    
    exception
      when no_data_found then
        l_cut_exist := 1;
    end;
  
    if l_cut_exist = 1 then
      select max(fas.payment_date)
        into l_cut_low_date
        from FA_AMORT_SCHEDULES fas
       where fas.payment_schedule_id = l_payment_schedule_id
         and fas.payment_date < p_as_of_date;
    
      if l_cut_low_date is null then
        begin
          select fls.lease_inception_date, fls.present_value
            into l_cut_low_date, l_cut_low_amount
            from fa_lease_schedules fls
           where fls.payment_schedule_id = l_payment_schedule_id;
        exception
          when no_data_found then
            null;
        end;
      end if;
    
      if nvl(l_cut_low_date, p_as_of_date + 1) < p_as_of_date then
      
        select nvl(sum(fas.principal), 0)
          into l_cut_low_amount
          from FA_AMORT_SCHEDULES fas
         where fas.payment_schedule_id = l_payment_schedule_id
           and fas.payment_date > l_cut_low_date;
      
        l_cut_amt := round(l_cut_low_amount *
                           (power(1 + l_rate / 100,
                                  (p_as_of_date + 1 - l_cut_low_date) / 365))) -
                     l_cut_low_amount;
      
      end if;
    
    end if;
  
    return l_future_balance + l_cut_amt;
  exception
    when others then
      return null;
  end get_lease_liability;

  -------------------------------------------------------------------
  --  name:            create_journal
  --  create by:       OFER.SUAD
  --  Revision:        1.0
  --  creation date:   13/08/2019
  --------------------------------------------------------------------
  --  purpose :       Insert data to GL Interface and import the journals 
  --------------------------------------------------------------------
  --  ver  date        name         desc
  --  ---  ----------  -----------  ----------------------------------
  --  1.0  13/08/2019  OFER.SUAD    initial build
  --  1.1  27/08/2019  Roman W.     CHG0041583 
  --------------------------------------------------------------------
  procedure create_journal(p_period_name in varchar2,
                           p_start_date  in date,
                           p_end_date    in date,
                           errbuf        out varchar2,
                           retcode       out varchar2) is
    cursor c_ledgers is
      select g.ledger_id
        from gl_ledgers g
       where g.ledger_category_code = 'PRIMARY';
    --and g.ledger_id!=2021;
  
    cursor c_lease_contracts(c_period_name varchar2,
                             c_ledger_id   number,
                             c_start_date  date,
                             c_end_date    date) is
      select a.payment_schedule_id,
             fl.lease_number,
             fl.description,
             fl.currency_code contract_curr_code,
             sum(short_term_liability_amt) short_term_liability_amt,
             sum(long_term_liability_amt) long_term_liability_amt,
             sum(asset_amt) asset_amt,
             gll.ledger_id,
             gll.currency_code ledger_currency_code,
             gp.period_name, -- period_name
             gp.end_date, --accounting_date
             fl.currency_code, --currency_code,
             gcc.segment1, --segment1, --
             '000' segment2,
             gcc.segment3,
             gcc.segment4,
             gcc.segment5, --
             gcc.segment6, --
             gcc.segment7, --
             gcc.segment8, --
             gcc.segment9, --
             gcc.segment10
        from (select xl.payment_schedule_id,
                     xl.short_term_liability_amt,
                     xl.long_term_liability_amt,
                     xl.asset_amt
                from XXGL_LEASE xl
               where xl.as_of_date = c_end_date
                 and xl.short_term_liability_amt <> 0
              union all
              select xl.payment_schedule_id,
                     -xl.short_term_liability_amt,
                     -xl.long_term_liability_amt,
                     -xl.asset_amt
                from XXGL_LEASE xl
               where xl.as_of_date = c_start_date - 1
                 and xl.short_term_liability_amt <> 0) a,
             fa_LEASES fl,
             po_vendor_sites_all pvs,
             hr_organization_information hri,
             gl_periods gp,
             gl_ledgers gll,
             gl_code_combinations gcc,
             fnd_flex_values ffv
       where a.payment_schedule_id = FL.Payment_Schedule_Id
         and pvs.VENDOR_SITE_ID = fl.lessor_site_id
         and hri.org_information_context = 'Operating Unit Information'
         and hri.organization_id = pvs.ORG_ID
         and gp.period_set_name = 'OBJET_CALENDAR'
         and gp.adjustment_period_flag = 'N'
         and gp.period_type = 21
         and gp.period_name = c_period_name
         and gll.ledger_id = c_ledger_id
         and gll.ledger_id = hri.org_information3
         and gcc.code_combination_id = fl.dist_code_combination_id
         and ffv.flex_value_set_id = 1013888 ---????
         and ffv.flex_value = gcc.segment1
         and ffv.attribute3 = 'Y'
       group by a.payment_schedule_id,
                fl.lease_number,
                fl.description,
                fl.currency_code,
                gll.ledger_id,
                gp.period_name, -- period_name
                gp.end_date, --accounting_date
                gll.currency_code, --currency_code,
                gcc.segment1, --segment1, --
                gcc.segment3,
                gcc.segment4,
                gcc.segment5, --
                gcc.segment6, --
                gcc.segment7, --
                gcc.segment8, --
                gcc.segment9, --
                gcc.segment10;
  
    l_conc_id              NUMBER;
    l_bool                 BOOLEAN;
    l_group_id             NUMBER;
    l_interface_run_id     NUMBER;
    l_phase                VARCHAR2(100);
    l_status               VARCHAR2(100);
    l_dev_phase            VARCHAR2(100);
    l_dev_status           VARCHAR2(100);
    l_message              VARCHAR2(100);
    l_je_source_name       VARCHAR2(100);
    l_source_name          VARCHAR2(100);
    l_found                number;
    l_liability_account_st VARCHAR2(25);
    l_liability_account_lt VARCHAR2(25);
    l_asset_account        VARCHAR2(25);
    l_st_liability_amount  number;
    l_lt_liability_amount  number;
    l_asset_amount         number;
  begin
    l_source_name          := fnd_profile.VALUE('XXGL_ASC842_SOURCE');
    l_liability_account_st := fnd_profile.VALUE('XXGL_ASC842_ST_LIABILITY_ACCOUNT');
    l_liability_account_lt := fnd_profile.VALUE('XXGL_ASC842_LT_LIABILITY_ACCOUNT');
    l_asset_account        := fnd_profile.VALUE('XXGL_ASC842_ASSET_ACCOUNT');
  
    select gjs.je_source_name
      into l_je_source_name
      from gl_je_sources gjs
     where gjs.user_je_source_name = l_source_name;
  
    for j in c_ledgers loop
    
      l_found := 0;
    
      l_group_id         := gl_interface_control_s.NEXTVAL;
      l_interface_run_id := gl_journal_import_s.NEXTVAL;
    
      for i in c_lease_contracts(p_period_name,
                                 j.ledger_id,
                                 p_start_date,
                                 p_end_date) loop
      
        if i.short_term_liability_amt != 0 or
           i.long_term_liability_amt != 0 or i.asset_amt != 0 then
          l_found := 1;
        
          message('create_journal in LOOP->IF');
          --- short term liablity
          INSERT INTO gl_interface
            (status,
             actual_flag,
             date_created,
             created_by,
             set_of_books_id, --5
             ledger_id, --
             period_name, --
             accounting_date, --
             currency_code, --
             user_currency_conversion_type,
             currency_conversion_date,
             user_je_source_name, --10
             user_je_category_name, --
             entered_dr, --
             entered_cr, --
             segment1, --
             segment2, --15
             segment3, --
             segment4, --
             segment5, --
             segment6, --
             segment7, --20
             segment8, --
             segment9, --
             segment10, --
             reference1, --
             reference2, --25
             reference4, --
             reference5, --
             reference10, --             
             group_id)
          VALUES
            ('NEW', --
             'A', --
             SYSDATE, --
             fnd_global.USER_ID,
             j.ledger_id, --5
             j.ledger_id, --
             i.period_name, --
             i.end_date, --
             i.currency_code, --
             case when i.ledger_currency_code=i.currency_code then 
               null
               else
                 'Corporate'
             end,  
             case when i.ledger_currency_code=i.currency_code then 
               null
               else
                 i.end_date
             end,       
             l_source_name, --10
             'Other', --
             case when i.short_term_liability_amt > 0 then null
             else - i.short_term_liability_amt end,
             case when i.short_term_liability_amt > 0 then
             i.short_term_liability_amt else null end,
             i.segment1, --
             '000', --
             l_liability_account_st, --
             i.segment4,
             i.segment5, --
             i.segment6, --
             i.segment7, --
             i.segment8,
             i.segment9,
             i.segment10,
             'ASC 842 JE ' || i.period_name, --i."Batch Name", --
             'ASC 842 JE ' || i.period_name, --i."Batch Description", --
             'ASC 842 JE ' || i.period_name, --i."Journal Name", --
             'ASC 842 JE ' || i.period_name, --i."Journal Description", --
             'Lease Liability ' || i.payment_schedule_id || '-' ||
             i.lease_number || '-' || i.description, --
             l_group_id);
        
          --long term liablity
          INSERT INTO gl_interface
            (status,
             actual_flag,
             date_created,
             created_by,
             set_of_books_id, --5
             ledger_id, --
             period_name, --
             accounting_date, --
             currency_code, --
             user_currency_conversion_type,
             currency_conversion_date,
             user_je_source_name, --10
             user_je_category_name, --
             entered_dr, --
             entered_cr, --
             segment1, --
             segment2, --15
             segment3, --
             segment4, --
             segment5, --
             segment6, --
             segment7, --20
             segment8, --
             segment9, --
             segment10, --
             reference1, --
             reference2, --25
             reference4, --
             reference5, --
             reference10, --
             
             group_id)
          VALUES
            ('NEW', --
             'A', --
             SYSDATE, --
             fnd_global.USER_ID, --
             j.ledger_id, --5
             j.ledger_id, --
             i.period_name, --
             i.end_date, --
             i.currency_code, --
             case when i.ledger_currency_code=i.currency_code then 
               null
               else
                 'Corporate'
             end,  
             case when i.ledger_currency_code=i.currency_code then 
               null
               else
                 i.end_date
             end,   
             l_source_name, --10
             'Other', --
             case when i.long_term_liability_amt > 0 then null
             else - i.long_term_liability_amt end,
             case when i.long_term_liability_amt > 0 then
             i.long_term_liability_amt else null end,
             i.segment1, --
             '000', --
             l_liability_account_lt, --
             i.segment4,
             i.segment5, --
             i.segment6, --
             i.segment7, --
             i.segment8,
             i.segment9,
             i.segment10,
             'ASC 842 JE ' || i.period_name, --i."Batch Name", --
             'ASC 842 JE ' || i.period_name, --i."Batch Description", --
             'ASC 842 JE ' || i.period_name, --i."Journal Name", --
             'ASC 842 JE ' || i.period_name, --i."Journal Description", --
             'Lease Liability' || i.payment_schedule_id || '-' ||
             i.lease_number || '-' || i.description, --
             l_group_id);
        
          -- asset 
          INSERT INTO gl_interface
            (status,
             actual_flag,
             date_created,
             created_by,
             set_of_books_id, --5
             ledger_id, --
             period_name, --
             accounting_date, --
             currency_code, --
             user_currency_conversion_type,
             currency_conversion_date,
             user_je_source_name, --10
             user_je_category_name, --
             entered_dr, --
             entered_cr, --             
             
             segment1, --
             segment2, --15
             segment3, --
             segment4, --
             segment5, --
             segment6, --
             segment7, --20
             segment8, --
             segment9, --
             segment10, --
             reference1, --
             reference2, --25
             reference4, --
             reference5, --
             reference10, --
             
             group_id)
          VALUES
            ('NEW', --
             'A', --
             SYSDATE, --
             fnd_global.USER_ID, --
             j.ledger_id, --5
             j.ledger_id, --
             i.period_name, --
             i.end_date, --
             i.currency_code, --
             case when i.ledger_currency_code=i.currency_code then 
               null
               else
                 'Corporate'
             end,  
             case when i.ledger_currency_code=i.currency_code then 
               null
               else
                 i.end_date
             end,   
             l_source_name, --10
             'Other', --
             case when i.asset_amt > 0 then i.asset_amt else null end,
             case when i.asset_amt > 0 then null else - i.asset_amt end,
             i.segment1, --
             '000', --
             l_asset_account, --
             i.segment4,
             i.segment5, --
             i.segment6, --
             i.segment7, --
             i.segment8,
             i.segment9,
             i.segment10,
             'ASC 842 JE ' || i.period_name, --i."Batch Name", --
             'ASC 842 JE ' || i.period_name, --i."Batch Description", --
             'ASC 842 JE ' || i.period_name, --i."Journal Name", --
             'ASC 842 JE ' || i.period_name, --i."Journal Description", --
             'Right Of Use Asset' || i.payment_schedule_id || '-' ||
             i.lease_number || '-' || i.description, --
             l_group_id);
        
        end if;
      end loop;
    
      if l_found = 1 then
      
        INSERT INTO gl_interface_control
          (status,
           je_source_name,
           group_id,
           set_of_books_id,
           interface_run_id)
        VALUES
          ('S',
           l_je_source_name,
           l_group_id,
           j.ledger_id,
           l_interface_run_id);
        COMMIT;
        l_conc_id := fnd_request.submit_request(application => 'SQLGL',
                                                program     => 'GLLEZL',
                                                description => NULL,
                                                start_time  => SYSDATE,
                                                sub_request => FALSE,
                                                argument1   => l_interface_run_id,
                                                argument2   => j.ledger_id,
                                                argument3   => 'N',
                                                argument4   => NULL,
                                                argument5   => NULL,
                                                argument6   => 'N',
                                                argument7   => 'W');
        COMMIT;
      
        if l_conc_id = 0 then
          errbuf  := 'ERROR request submission failed : ' ||
                     fnd_message.get;
          retcode := 2;
          return;
        else
          message('CONC_REQUEST_ID : ' || l_conc_id);
        
          l_bool := fnd_concurrent.wait_for_request(l_conc_id,
                                                    5,
                                                    1000,
                                                    l_phase,
                                                    l_status,
                                                    l_dev_phase,
                                                    l_dev_status,
                                                    l_message);
          COMMIT;
        end if;
      end if;
    
    end loop;
  exception
    when others then
      errbuf  := 'EXCEPTION_OTHERS XXGL_LEASE_JOURNALS.create_journal(' ||
                 p_period_name || ') - ' || sqlerrm;
      retcode := '2';
    
  end create_journal;
  -------------------------------------------------------------------
  --  name:            get_st_lease_liability
  --  create by:       OFER.SUAD
  --  Revision:        1.0
  --  creation date:   13/08/2019
  --------------------------------------------------------------------
  --  purpose :       Calculate Short term leablity   for specific date 
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  13/08/2019  OFER.SUAD   initial build
  --------------------------------------------------------------------    
  function get_st_lease_liability(l_payment_schedule_id number,
                                  p_as_of_date          date) return number is
    l_st_liability number := 0;
    l_max_date     date;
  begin
    select max(fas.payment_date)
      into l_max_date
      from FA_AMORT_SCHEDULES fas
     where fas.payment_schedule_id = l_payment_schedule_id;
  
    if l_max_date < add_months(p_as_of_date, 12) - 1 then
      return get_lease_liability(l_payment_schedule_id, p_as_of_date - 1);
    end if;
  
    select sum(fas.payment_amount /
               power((1 + (fls.interest_rate / 1200)),
                     months_between(fas.payment_date, p_as_of_date)))
      into l_st_liability
    
      from FA_AMORT_SCHEDULES fas, FA_LEASE_SCHEDULES fls
     where fas.payment_schedule_id = l_payment_schedule_id
       and fas.payment_date between p_as_of_date and
           add_months(p_as_of_date, 12) - 1
          --'30-jun-2020'
       and fas.payment_schedule_id = fls.payment_schedule_id;
  
    return nvl(l_st_liability, 0);
  end get_st_lease_liability;
  --------------------------------------------------------------------
  --  purpose :       Intiate Global parameters strat date and end date 
  --------------------------------------------------------------------
  --  ver  date        name        desc
  --  ---  ----------  ----------  -----------------------------------
  --  1.0  13/08/2019  OFER.SUAD   initial build
  --  1.1  27/08/2019  Roman W.    CHG0041583
  --------------------------------------------------------------------   
  procedure init_date(p_start_date out date,
                      p_end_date   out date,
                      p_error_desc out varchar2,
                      p_error_code out varchar2) is
    --------------------------
    --    Code Section
    --------------------------    
  begin
    p_error_code := '0';
    p_error_desc := null;
  
    select gp.quarter_start_date, add_months(gp.quarter_start_date, 3) - 1
      into p_start_date, p_end_date
      from gl_periods gp
     where gp.period_set_name = 'OBJET_CALENDAR'
       and gp.adjustment_period_flag = 'N'
       and gp.period_type = '21'
       and trunc(add_months(sysdate, -1)) between gp.start_date and
           gp.end_date;
  
  exception
    when others then
      p_error_code := '2';
      p_error_desc := 'EXCEPTION_OTHERS XXGL_LEASE_JOURNALS.init_date() - ' ||
                      sqlerrm;
  end init_date;

  -------------------------------------------------------------------
  --  name:            populate_table
  --  create by:       OFER.SUAD
  --  Revision:        1.0
  --  creation date:   13/08/2019
  --------------------------------------------------------------------
  --  purpose :       Insert ending balance to  XXGL_LEASE table
  --------------------------------------------------------------------
  --  ver  date        name        desc
  --  ---  ----------  ----------  -----------------------------------
  --  1.0  13/08/2019  OFER.SUAD   initial build
  --  1.1  27/08/2019  Roman W.    CHG0041583 
  --------------------------------------------------------------------
  procedure populate_table(p_end_date in date,
                           errbuf     out varchar2,
                           retcode    out varchar2) is
  
    cursor c_lines is
      select gll.name,
             fl.lease_number,
             fl.description,
             fl.currency_code,
             fls.interest_rate,
             fls.lease_inception_date start_date,
             fls.frequency,
             fls.payment_schedule_id,
             xxgl_lease_journals.get_lease_liability(fls.payment_schedule_id,
                                                     p_end_date) laibility_amount,
             xxgl_lease_journals.get_st_lease_liability(fls.payment_schedule_id,
                                                        p_end_date + 1) laibility_amount_st,
             (select round(sum(fas.payment_amount) / count(payment_amount))
              -- into l_avg_amount
                from fa_amort_schedules fas
               where fas.payment_schedule_id = fls.payment_schedule_id) avg_pym,
             (select count(payment_amount)
              -- into l_avg_amount
                from fa_amort_schedules fas
               where fas.payment_schedule_id = fls.payment_schedule_id) pym_count,
             ( --select 'Y' -- rem by Roman
              select decode(count(*), 0, 'N', 'Y')
                from fa_amort_schedules gg
               where exists
               (select 1
                        from fa_amort_schedules gg1
                       where gg1.payment_schedule_id = gg.payment_schedule_id
                         and gg.payment_amount <> gg1.payment_amount)
                 and gg.payment_schedule_id = fls.payment_schedule_id
                 and rownum = 1) has_multiple_pmt
        from fa_lease_schedules          fls,
             po_vendor_sites_all         pvs,
             hr_organization_information hri,
             fa_leases                   fl,
             gl_ledgers                  gll
       where fl.payment_schedule_id = fls.payment_schedule_id
         and pvs.vendor_site_id = fl.lessor_site_id
         and hri.org_information_context = 'Operating Unit Information'
         and hri.organization_id = pvs.org_id
         and gll.ledger_id = hri.org_information3;
  
    l_amt number;
  
    l_date              date;
    l_liability_op      number;
    l_liability_cb      number;
    l_start_date        date;
    l_end_date          date;
    l_amt_liability     number;
    l_amt_st_liability  number;
    l_amt_lt_liability  number;
    l_asset_amt         number;
    l_prev_st_liability number;
    l_prev_lt_liability number;
    l_end_of_year       date;
    l_flag              number;
  
  begin
    errbuf  := null;
    retcode := '0';
    -- clear existsin data if there is 
  
    delete from XXGL_LEASE xl where xl.as_of_date = p_end_date;
  
    for i in c_lines /*(g_start_date, g_end_date)*/
     loop
    
      insert into XXGL_LEASE
      values
        (i.payment_schedule_id,
         p_end_date, --i.LEASE_INCEPTION_DATE,
         round(i.laibility_amount_st, 2),
         round(i.laibility_amount - i.laibility_amount_st, 2),
         round(i.laibility_amount, 2));
      -- dbms_output.put_line('l_cut_amt ');
    
    end loop;
    -- all contact curent --
  
    commit;
  
  exception
    when others then
      errbuf  := 'EXCEPTION_OTHERS XXGL_LEASE_JOURNALS.populate_table() - ' ||
                 sqlerrm;
      retcode := '2';
    
  end populate_table;

  --------------------------------------------------------------------
  --  name:            main
  --  create by:       OFER.SUAD
  --  Revision:        1.0
  --  creation date:   13/08/2019
  --------------------------------------------------------------------
  --  purpose :        Main produre called from concurent - will call functios to
  --                   calcualte amounts and create the Journals   
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  13/08/2019  OFER.SUAD   initial build
  --------------------------------------------------------------------
  procedure main(errbuf out varchar2, retcode out varchar2) is
  
    l_period_name gl_periods.period_name%type;
    l_flag        number;
    l_start_date  date;
    l_end_date    date;
  begin
  
    select period_name
      into l_period_name
      from gl_periods gp
     where add_months(trunc(sysdate), -1) between gp.start_date and
           gp.end_date;
  
    -- Rem By Roman 2019-08-27    l_flag := init_date;
    init_date(l_start_date, l_end_date, errbuf, retcode);
    message('l_start_date :' || l_start_date);
    message('l_end_date :' || l_end_date);
    if '0' = retcode then
      if not check_je_exits(l_period_name) then
        message('call : populate_table(' || l_end_date || ')');
        populate_table(l_end_date, errbuf, retcode);
        if '0' != retcode then
          return;
        end if;
      
        message('call : create_journal(' || l_period_name || ',' ||
                l_start_date || ',' || l_end_date || ')');
        create_journal(l_period_name,
                       l_start_date,
                       l_end_date,
                       errbuf,
                       retcode);
      
        if '0' != retcode then
          return;
        end if;
      else
        retcode := '1';
        errbuf  := 'Journal Entery already created for period ' ||
                   l_period_name;
        message('-------------------------------------------------------------');
        message(errbuf);
        message('-------------------------------------------------------------');
      end if;
    end if;
  exception
    when others then
      retcode := '2';
      errbuf  := 'EXCEPTION_OTHERS XXGL_LEASE_JOURNALS.main() - ' ||
                 sqlerrm;
    
  end main;

end XXGL_LEASE_JOURNALS;
/
