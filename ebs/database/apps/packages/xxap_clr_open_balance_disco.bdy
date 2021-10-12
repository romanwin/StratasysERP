create or replace package body xxap_clr_open_balance_disco is

  -- Author  : DANIEL.KATZ
  -- Created : 12/05/2010 1:23:41 PM
  -- Purpose : ap cash clearing open balance report
  
  
  -- Function and procedure implementations

  --Retrieve the last "as of date" in the xxap_clearing_balance before the requested end date and set it to global.
  FUNCTION set_last_date(p_end_date DATE) RETURN NUMBER AS
  
  BEGIN

        select NVL(max(xcb.as_of_date),to_date('20090101','yyyymmdd'))
          into g_last_date
          from xxap_clearing_balance xcb
         where xcb.as_of_date <= p_end_date;
      
    RETURN(1);
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN null;
    
  END set_last_date;

  FUNCTION get_last_date RETURN DATE IS
  BEGIN
    RETURN g_last_date;
  END;

  --set the as of date to global.
  FUNCTION set_as_of_date(p_as_of_date DATE) RETURN NUMBER AS
  
  BEGIN
    g_as_of_date := p_as_of_date;      

    RETURN(1);
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN null;
    
  END set_as_of_date;

  FUNCTION get_as_of_date RETURN DATE IS
  BEGIN
    RETURN g_as_of_date;
  END;

  --Retrieve the last "as of date" in the xxap_clearing_sla_balance before the requested end date and set it to global.
  FUNCTION set_sla_last_date(p_end_date DATE) RETURN NUMBER AS
  
  BEGIN

        select NVL(max(xcsb.as_of_date),to_date('20090101','yyyymmdd'))
          into g_sla_last_date
          from xxap_clearing_sla_balance xcsb
         where xcsb.as_of_date <= p_end_date;
      
    RETURN(1);
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN null;
    
  END set_sla_last_date;

  FUNCTION get_sla_last_date RETURN DATE IS
  BEGIN
    RETURN g_sla_last_date;
  END;

  --set the as of date to global.
  FUNCTION set_sla_as_of_date(p_as_of_date DATE) RETURN NUMBER AS
  
  BEGIN
    g_sla_as_of_date := p_as_of_date;      

    RETURN(1);
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN null;
    
  END set_sla_as_of_date;

  FUNCTION get_sla_as_of_date RETURN DATE IS
  BEGIN
    RETURN g_sla_as_of_date;
  END;

  --procedure to test the data (for all relevant periods by total amount and total count) 
  --in the xxap_clearing_balance table and insert the data to relevant periods.
  --the relevant periods are the period that the data there was found as different and 
  --all periods after that period.
  
PROCEDURE test_upload_clr_open_bal_data(errbuf    OUT VARCHAR2,
                                        retcode   OUT NUMBER,
                                        p_account IN VARCHAR2) IS

  l_first_end_date_to_insert   date;
  l_first_start_date_to_insert date;
  l_first_start_date_to_check  date;
  l_first_end_date_to_check    date;
  l_last_end_date_to_insert    date;
  l_set_last_date              number;
  l_period_last_upd_date       date;

  cursor csr_periods_to_change(p_first_start_date date, p_last_end_date date) is
    select gp.end_date, gp.period_name, total_amount, total_count
      from (select sum(amount) total_amount,
                   count(1) total_count,
                   period_name
              from (select aph.trx_pmt_amount amount, gp2.period_name
                      from ap_payment_history_all aph, gl_periods gp2
                     where gp2.period_set_name = 'OBJET_CALENDAR'
                       and gp2.adjustment_period_flag = 'N'
                       and aph.accounting_date between gp2.start_date and
                           gp2.end_date
                       and p_account =
                           (select min(gcc.segment3)
                              from xla_ae_lines         xl,
                                   xla_ae_headers       xh,
                                   gl_code_combinations gcc
                             where xl.application_id = 200
                               and xl.application_id = xh.application_id
                               and xl.ae_header_id = xh.ae_header_id
                               and xl.code_combination_id =
                                   gcc.code_combination_id
                               and xh.event_id = aph.accounting_event_id
                               and xl.accounting_class_code = 'CASH_CLEARING')
                       and aph.accounting_date between p_first_start_date and
                           p_last_end_date)
             group by period_name) a,
           gl_periods gp
     where gp.period_name = a.period_name
       and gp.period_set_name = 'OBJET_CALENDAR'
       and gp.adjustment_period_flag = 'N'
     order by gp.end_date;

BEGIN

  fnd_file.PUT_LINE(fnd_file.log,
                    'starting program at: ' ||
                    to_char(sysdate, 'hh24:mi:ss'));

  select max(gp.end_date)
    into l_last_end_date_to_insert
    from gl_periods gp
   where gp.period_set_name = 'OBJET_CALENDAR'
     and gp.adjustment_period_flag = 'N'
     and gp.end_date < sysdate - 3; --3 DAYS GRACE

  select min(end_date), min(start_date)
    into l_first_end_date_to_check, l_first_start_date_to_check
    from (select gps.start_date,
                 gps.end_date,
                 max(decode(gps.closing_status,
                            'C',
                            gps.last_update_date,
                            'O',
                            sysdate + 100)) last_update_date
            from gl_period_statuses gps, gl_ledgers gl
           where gps.application_id = 200
             and gps.adjustment_period_flag = 'N'
             and gl.ledger_id = gps.ledger_id
             and gl.ledger_category_code = 'PRIMARY'
             and gps.closing_status in ('C', 'O')
             and gps.effective_period_num >= 20090009 --go live effective period num
           group by gps.period_name,gps.start_date, gps.end_date
          minus
          select trunc(xcb.as_of_date, 'mm'),
                 xcb.as_of_date,
                 min(xcb.test_period_last_upd_date)
            from xxap_clearing_balance xcb
           where xcb.as_of_date <= l_last_end_date_to_insert
           group by xcb.as_of_date);

  fnd_file.PUT_LINE(fnd_file.log,
                    'l_first_start_date_to_check = ' ||
                    l_first_start_date_to_check);
  fnd_file.PUT_LINE(fnd_file.log,
                    'before testing periods, program at: ' ||
                    to_char(sysdate, 'hh24:mi:ss'));

  select min(end_date), min(start_date)
    into l_first_end_date_to_insert, l_first_start_date_to_insert
    from (select gp.end_date, gp.start_date, a.total_amount, a.total_count
            from (select sum(amount) total_amount,
                         count(1) total_count,
                         period_name
                    from (select aph.trx_pmt_amount amount, gp2.period_name
                            from ap_payment_history_all aph, gl_periods gp2
                           where gp2.period_set_name = 'OBJET_CALENDAR'
                             and gp2.adjustment_period_flag = 'N'
                             and aph.accounting_date between gp2.start_date and
                                 gp2.end_date
                             and p_account =
                                 (select min(gcc.segment3)
                                    from xla_ae_lines         xl,
                                         xla_ae_headers       xh,
                                         gl_code_combinations gcc
                                   where xl.application_id = 200
                                     and xl.application_id = xh.application_id
                                     and xl.ae_header_id = xh.ae_header_id
                                     and xl.code_combination_id =
                                         gcc.code_combination_id
                                     and xh.event_id = aph.accounting_event_id
                                     and xl.accounting_class_code =
                                         'CASH_CLEARING')
                             and aph.accounting_date between
                                 l_first_start_date_to_check and
                                 l_last_end_date_to_insert)
                   group by period_name) a,
                 gl_periods gp
           where gp.period_name = a.period_name
             and gp.period_set_name = 'OBJET_CALENDAR'
             and gp.adjustment_period_flag = 'N'
          minus
          select xcb.as_of_date,
                 trunc(xcb.as_of_date, 'mm'),
                 min(xcb.test_total_amount),
                 min(xcb.test_total_count)
            from xxap_clearing_balance xcb
           where xcb.as_of_date between l_first_end_date_to_check and
                 l_last_end_date_to_insert
           group by xcb.as_of_date);

  fnd_file.PUT_LINE(fnd_file.log,
                    'after testing periods, program at: ' ||
                    to_char(sysdate, 'hh24:mi:ss'));

  fnd_file.PUT_LINE(fnd_file.log,
                    'l_last_end_date_to_insert = ' ||
                    l_last_end_date_to_insert);
  fnd_file.PUT_LINE(fnd_file.log,
                    'l_first_end_date_to_insert = ' ||
                    l_first_end_date_to_insert);
  fnd_file.PUT_LINE(fnd_file.log,
                    'l_first_start_date_to_insert = ' ||
                    l_first_start_date_to_insert);

  if l_last_end_date_to_insert >=
     nvl(l_first_end_date_to_insert, l_last_end_date_to_insert + 1) then
    --addition of data is needed for periods between first & last end dates
  
    fnd_file.PUT_LINE(fnd_file.log, 'Data Addition process....');
  
    --delete existing data
    delete xxap_clearing_balance xcb
     where xcb.as_of_date between l_first_end_date_to_insert and
           l_last_end_date_to_insert;
  
    commit;
  
    fnd_file.PUT_LINE(fnd_file.log, 'deleted records');
    fnd_file.PUT_LINE(fnd_file.log,
                      'after deleting records, program at: ' ||
                      to_char(sysdate, 'hh24:mi:ss'));
  
    --insert new data for each relevant period (based on previous period data)
    for periods_to_change_csr in csr_periods_to_change(l_first_start_date_to_insert,
                                                       l_last_end_date_to_insert) loop
    
      --initialize last end date from table to use
      l_set_last_date := set_last_date(periods_to_change_csr.end_date);
    
      fnd_file.PUT_LINE(fnd_file.log,
                        'last end date used from table = ' || get_last_date);
    
      --maximum period last update date
      select max(gps.last_update_date)
        into l_period_last_upd_date
        from gl_period_statuses gps, gl_ledgers gl
       where gps.application_id = 200
         and gps.period_name = periods_to_change_csr.period_name
         and gl.ledger_id = gps.ledger_id
         and gl.ledger_category_code = 'PRIMARY'
         and gps.closing_status in ('C', 'O');

      --insert the data into the relevant period (based on pervious period)
      --the insert logic is based on the view for the disco: xxap_clr_open_balance_disco_v
      insert into xxap_clearing_balance
        (select periods_to_change_csr.end_date,
                payment_history_id,
                sysdate,
                periods_to_change_csr.total_amount,
                periods_to_change_csr.total_count,
                l_period_last_upd_date
           from (select aph.payment_history_id,
                        aph.accounting_event_id,
                        sum((case
                              when aph.transaction_type in
                                   ('PAYMENT CREATED', 'PAYMENT UNCLEARING',
                                    'REFUND RECORDED', 'PAYMENT MATURITY') then
                               -1
                              else
                               1
                            end) * aph.trx_pmt_amount - (case
                              when aph.transaction_type = 'PAYMENT CREATED' and
                                   ac.payment_type_flag = 'Q' then
                               (SELECT nvl(sum(aid.amount), 0) --in aphd the sum is not always correct
                                  from ap_payment_hist_dists        aphd,
                                       ap_invoice_distributions_all aid
                                 where aphd.payment_history_id =
                                       aph.payment_history_id
                                   and aphd.invoice_distribution_id =
                                       aid.invoice_distribution_id
                                   and aphd.pay_dist_lookup_code = 'AWT')
                              else
                               0
                            end)) over(partition by aph.check_id) balance
                   from ap_payment_history_all aph,
                        ap_checks_all ac,
                        (select xcb.payment_history_id
                           from xxap_clearing_balance xcb
                          where xcb.as_of_date = get_last_date
                         union all
                         select aph.Payment_History_Id
                           from ap_payment_history_all aph
                          where aph.accounting_date between get_last_date + 1 and
                                periods_to_change_csr.end_date) relevant_id
                  where relevant_id.payment_history_id =
                        aph.payment_history_id
                    and aph.check_id = ac.check_id) a
          where a.balance != 0
            and p_account =
                (select min(gcc.segment3)
                   from xla_ae_lines         xl,
                        xla_ae_headers       xh,
                        gl_code_combinations gcc
                  where xl.application_id = 200
                    and xl.application_id = xh.application_id
                    and xl.ae_header_id = xh.ae_header_id
                    and xl.code_combination_id = gcc.code_combination_id
                    and xh.event_id = a.accounting_event_id
                    and xl.accounting_class_code = 'CASH_CLEARING'));
    
      commit;
    
      fnd_file.PUT_LINE(fnd_file.log,
                        'inserted records for end as of date: ' ||
                        periods_to_change_csr.end_date);
      fnd_file.PUT_LINE(fnd_file.log,
                        'after inserting, program at: ' ||
                        to_char(sysdate, 'hh24:mi:ss'));
    
    end loop;
  end if;

  --update period last update date in test column for periods that aren't needed to be deleted and inserted again 
  if l_first_end_date_to_check < nvl(l_first_end_date_to_insert, l_last_end_date_to_insert) then

      fnd_file.PUT_LINE(fnd_file.log, 'updating period''s last_update_date in test column...');
      
      update xxap_clearing_balance xcb
         set xcb.test_period_last_upd_date = 
                                  (select max(gps.last_update_date)
                                    from gl_period_statuses gps, gl_ledgers gl
                                   where gps.application_id = 200
                                     and gps.end_date = xcb.as_of_date
                                     and gl.ledger_id = gps.ledger_id
                                     and gl.ledger_category_code = 'PRIMARY'
                                     and gps.closing_status in ('C', 'O'))
       where xcb.as_of_date >= l_first_end_date_to_check 
         and xcb.as_of_date < nvl(l_first_end_date_to_insert, l_last_end_date_to_insert);
       
       commit;
  end if;

EXCEPTION
  WHEN OTHERS THEN
    retcode := 2;
    errbuf  := SQLERRM;
END test_upload_clr_open_bal_data;


  --procedure to test the data (for all relevant periods by total amount and total count) 
  --in the xxap_clearing_sla_balance table and insert the data to relevant periods.
  --the relevant periods are the period that the data there was found as different and 
  --all periods after that period.
PROCEDURE test_upl_clr_sla_open_bal_dat(errbuf    OUT VARCHAR2,
                                        retcode   OUT NUMBER,
                                        p_account IN VARCHAR2) IS

  l_first_end_date_to_insert   date;
  l_first_start_date_to_insert date;
  l_first_start_date_to_check  date;
  l_first_end_date_to_check    date;
  l_last_end_date_to_insert    date;
  l_set_last_date              number;
  l_period_last_upd_date       date;

  cursor csr_periods_to_change(p_first_start_date date, p_last_end_date date) is
    select gp.end_date, gp.period_name, total_amount, total_count
      from (select sum(nvl(xl.entered_dr, 0) - nvl(xl.entered_cr, 0)) total_amount,
                   count(1) total_count,
                   xh.period_name
              from xla_ae_lines         xl,
                   gl_code_combinations gcc,
                   xla_ae_headers       xh
             where xl.application_id = 200
               and xl.application_id = xh.application_id
               and xl.ae_header_id = xh.ae_header_id
               and xl.accounting_date between p_first_start_date AND
                   p_last_end_date
               and gcc.code_combination_id = xl.code_combination_id
               and gcc.segment3 = p_account
             group by xh.period_name) a,
           gl_periods gp
     where gp.period_name = a.period_name
       and gp.period_set_name = 'OBJET_CALENDAR'
       and gp.adjustment_period_flag = 'N'
     order by gp.end_date;

BEGIN

  fnd_file.PUT_LINE(fnd_file.log,
                    'starting program at: ' ||
                    to_char(sysdate, 'hh24:mi:ss'));

  select max(gp.end_date)
    into l_last_end_date_to_insert
    from gl_periods gp
   where gp.period_set_name = 'OBJET_CALENDAR'
     and gp.adjustment_period_flag = 'N'
     and gp.end_date < sysdate - 3; --3 DAYS GRACE

  select min(end_date), min(start_date)
    into l_first_end_date_to_check, l_first_start_date_to_check
    from (select gps.start_date,
                 gps.end_date,
                 max(decode(gps.closing_status,
                            'C',
                            gps.last_update_date,
                            'O',
                            sysdate + 100)) last_update_date
            from gl_period_statuses gps, gl_ledgers gl
           where gps.application_id = 200
             and gps.adjustment_period_flag = 'N'
             and gl.ledger_id = gps.ledger_id
             and gl.ledger_category_code = 'PRIMARY'
             and gps.closing_status in ('C', 'O')
             and gps.effective_period_num >= 20090009 --go live effective period num             
           group by gps.period_name, gps.start_date, gps.end_date
          minus
          select trunc(xcsb.as_of_date, 'mm'),
                 xcsb.as_of_date,
                 min(xcsb.test_period_last_upd_date)
            from xxap_clearing_sla_balance xcsb
           where xcsb.as_of_date <= l_last_end_date_to_insert
           group by xcsb.as_of_date);

  fnd_file.PUT_LINE(fnd_file.log,
                    'l_first_start_date_to_check = ' ||
                    l_first_start_date_to_check);
  fnd_file.PUT_LINE(fnd_file.log,
                    'before testing periods, program at: ' ||
                    to_char(sysdate, 'hh24:mi:ss'));

  select min(end_date), min(start_date)
    into l_first_end_date_to_insert, l_first_start_date_to_insert
    from (select gp.end_date, gp.start_date, a.total_amount, a.total_count
            from (select sum(nvl(xl.entered_dr, 0) - nvl(xl.entered_cr, 0)) total_amount,
                         count(1) total_count,
                         xh.period_name
                    from xla_ae_lines         xl,
                         gl_code_combinations gcc,
                         xla_ae_headers       xh
                   where xl.application_id = 200
                     and xl.application_id = xh.application_id
                     and xl.ae_header_id = xh.ae_header_id
                     and xl.accounting_date between
                         l_first_start_date_to_check and
                         l_last_end_date_to_insert
                     and gcc.code_combination_id = xl.code_combination_id
                     and gcc.segment3 = p_account
                   group by xh.period_name) a,
                 gl_periods gp
           where gp.period_name = a.period_name
             and gp.period_set_name = 'OBJET_CALENDAR'
             and gp.adjustment_period_flag = 'N'
          minus
          select xcsb.as_of_date,
                 trunc(xcsb.as_of_date, 'mm'),
                 min(xcsb.test_total_amount),
                 min(xcsb.test_total_count)
            from xxap_clearing_sla_balance xcsb
           where xcsb.as_of_date between l_first_end_date_to_check and
                 l_last_end_date_to_insert
           group by xcsb.as_of_date);

  fnd_file.PUT_LINE(fnd_file.log,
                    'after testing periods, program at: ' ||
                    to_char(sysdate, 'hh24:mi:ss'));
  fnd_file.PUT_LINE(fnd_file.log,
                    'l_last_end_date_to_insert = ' ||
                    l_last_end_date_to_insert);
  fnd_file.PUT_LINE(fnd_file.log,
                    'l_first_end_date_to_insert = ' ||
                    l_first_end_date_to_insert);
  fnd_file.PUT_LINE(fnd_file.log,
                    'l_first_start_date_to_insert = ' ||
                    l_first_start_date_to_insert);

  if l_last_end_date_to_insert >=
     nvl(l_first_end_date_to_insert, l_last_end_date_to_insert + 1) then
    --addition of data is needed for periods between first & last end dates
  
    fnd_file.PUT_LINE(fnd_file.log, 'Data Addition process....');
  
    --delete existing data
    delete xxap_clearing_sla_balance xcsb
     where xcsb.as_of_date between l_first_end_date_to_insert and
           l_last_end_date_to_insert;
  
    commit;
  
    fnd_file.PUT_LINE(fnd_file.log, 'deleted records');
    fnd_file.PUT_LINE(fnd_file.log,
                      'after deleting records, program at: ' ||
                      to_char(sysdate, 'hh24:mi:ss'));
  
    --insert new data for each relevant period (based on previous period data)
    for periods_to_change_csr in csr_periods_to_change(l_first_start_date_to_insert,
                                                       l_last_end_date_to_insert) loop
    
      --initialize last end date from table to use
      l_set_last_date := set_sla_last_date(periods_to_change_csr.end_date);
    
      fnd_file.PUT_LINE(fnd_file.log,
                        'last end date used from table = ' ||
                        get_sla_last_date);
    
      --maximum period last update date
      select max(gps.last_update_date)
        into l_period_last_upd_date
        from gl_period_statuses gps, gl_ledgers gl
       where gps.application_id = 200
         and gps.period_name = periods_to_change_csr.period_name
         and gl.ledger_id = gps.ledger_id
         and gl.ledger_category_code = 'PRIMARY'
         and gps.closing_status in ('C', 'O');
    
      --insert the data into the relevant period (based on pervious period)
      --the insert logic is based on the view for the disco: xxap_clr_sla_open_bal_disco_v
    
      insert into xxap_clearing_sla_balance
        (select distinct periods_to_change_csr.end_date,
                         aa.ae_header_id,
                         aa.ae_line_num,
                         sysdate,
                         periods_to_change_csr.total_amount,
                         periods_to_change_csr.total_count,
                         l_period_last_upd_date
           from (select sum(entered) over(partition by check_id) balance,
                        a.*
                   from (select nvl(xl.entered_dr, 0) - nvl(xl.entered_cr, 0) entered,
                                xl.ae_header_id,
                                xl.ae_line_num,
                                decode(xl.accounting_class_code,
                                       'CASH_CLEARING',
                                       ac.check_id,
                                       -xl.ledger_id || xl.code_combination_id) check_id
                           from xla_ae_lines xl,
                                gl_code_combinations gcc,
                                xla_AE_HEADERS XH,
                                xla_transaction_entities_upg xte,
                                ap_checks_all ac,
                                (select xcsb.ae_header_id, xcsb.ae_line_num
                                   from xxap_clearing_sla_balance xcsb
                                  where xcsb.as_of_date = get_sla_last_date
                                 union all
                                 select xl.ae_header_id, xl.ae_line_num
                                   from xla_ae_lines         xl,
                                        gl_code_combinations gcc
                                  where gcc.code_combination_id =
                                        xl.code_combination_id
                                    and xl.application_id = 200
                                    and xl.accounting_date between
                                        get_sla_last_date + 1 and
                                        periods_to_change_csr.end_date
                                    and gcc.segment3 = p_account) relevant_id
                          where xl.code_combination_id =
                                gcc.code_combination_id
                            AND xl.ae_header_id = xh.ae_header_id
                            and xl.application_id = xh.application_id
                            and xh.application_id = xte.application_id
                            and xh.entity_id = xte.entity_id
                            and xh.application_id = 200
                            and xh.accounting_entry_status_code = 'F'
                            and xte.source_id_int_1 = ac.check_id(+)
                            and relevant_id.ae_header_id = xl.ae_header_id
                            and relevant_id.ae_line_num = xl.ae_line_num
                            and xh.balance_type_code = 'A') a) aa
          where balance != 0);
    
      commit;
    
      fnd_file.PUT_LINE(fnd_file.log,
                        'inserted records for end as of date: ' ||
                        periods_to_change_csr.end_date);
      fnd_file.PUT_LINE(fnd_file.log,
                        'after inserting, program at: ' ||
                        to_char(sysdate, 'hh24:mi:ss'));
    
    end loop;
  end if;

  --delete ids related to sla accounting corruptions from xxap_clearing_sla_balance table
  --Accounting corruptions in SLA - payments cleared in same period but accounting was wrong.
  -- manual GL Journals done as Payables Source ans Adjustment Category.
  --check_ids 24822, 19476, 25071, 17465, 14368 are all before APR-10
  if l_first_end_date_to_insert < to_date('20100401', 'yyyymmdd') then
    delete xxap_clearing_sla_balance xcsb
     where exists (select 1
              from ap_checks_all          ac,
                   ap_payment_history_all aph,
                   xla_ae_headers         xh,
                   xla_ae_lines           xl
             where ac.check_id in (24822, 19476, 25071, 17465, 14368)
               and ac.check_id = aph.check_id
               and xh.event_id = aph.accounting_event_id
               and xh.application_id = 200
               and xh.application_id = xl.application_id
               and xh.ae_header_id = xl.ae_header_id
               and xl.accounting_class_code = 'CASH_CLEARING'
               and xl.ae_header_id = xcsb.ae_header_id
               and xl.ae_line_num = xcsb.ae_line_num);
     commit;
     
    fnd_file.PUT_LINE(fnd_file.log,
                      'deleted records with SLA corruptions');
  end if;

  --update period last update date in test column for periods that aren't needed to be deleted and inserted again 
  if l_first_end_date_to_check <
     nvl(l_first_end_date_to_insert, l_last_end_date_to_insert) then
  
    fnd_file.PUT_LINE(fnd_file.log,
                      'updating period''s last_update_date in test column...');
  
    update xxap_clearing_sla_balance xcsb
       set xcsb.test_period_last_upd_date = (select max(gps.last_update_date)
                                               from gl_period_statuses gps,
                                                    gl_ledgers         gl
                                              where gps.application_id = 200
                                                and gps.end_date =
                                                    xcsb.as_of_date
                                                and gl.ledger_id =
                                                    gps.ledger_id
                                                and gl.ledger_category_code =
                                                    'PRIMARY'
                                                and gps.closing_status in
                                                    ('C', 'O'))
     where xcsb.as_of_date >= l_first_end_date_to_check
       and xcsb.as_of_date <
           nvl(l_first_end_date_to_insert, l_last_end_date_to_insert);
  
    commit;
  end if;

EXCEPTION
  WHEN OTHERS THEN
    retcode := 2;
    errbuf  := SQLERRM;
END test_upl_clr_sla_open_bal_dat;

end xxap_clr_open_balance_disco;
/

