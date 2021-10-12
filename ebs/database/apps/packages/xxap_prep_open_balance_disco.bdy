create or replace package body xxap_prep_open_balance_disco is

  -- Author  : DANIEL.KATZ
  -- Created : 11/10/2010 6:23:41 PM
  -- Purpose : prepayment open balance report
  
  t_reset_varchar varchar_table_type;
  
  -- Function and procedure implementations

  --Retrieve the last "as of date" in the xxap_prep_open_invoices before the requested end date and set it to global.
  FUNCTION set_last_date(p_end_date DATE) RETURN NUMBER AS
  
  BEGIN

        select NVL(max(xpoi.as_of_date),to_date('20090101','yyyymmdd'))
          into g_last_date
          from xxap_prep_open_invoices xpoi
         where xpoi.as_of_date <= p_end_date
           and xpoi.meaning = 'PREPAYMENT';
      
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

  --calculate and set to global the remaining amount to pay for the prepayment.
  --in addition, the function return the remaining amount.
  FUNCTION set_get_prep_to_pay(p_prep_amount number, p_prep_invoice_id number) RETURN NUMBER AS
  
  l_paid_amount number;
  l_wht_amount  number;
  
  BEGIN

        select nvl(sum(amount), 0)
          into l_paid_amount
          from ap_invoice_payments_all aip
         where aip.invoice_id = p_prep_invoice_id
           and aip.accounting_date <= g_as_of_date;
           
        select 0 - nvl(sum(amount), 0)
          into l_wht_amount
          from ap_invoice_distributions_all aid
         where aid.invoice_id = p_prep_invoice_id
           and aid.line_type_lookup_code = 'AWT'
           and aid.accounting_date <= g_as_of_date;

    g_remain_prep_amount := p_prep_amount - l_paid_amount - l_wht_amount; 
                 
    RETURN g_remain_prep_amount;
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN null;
    
  END set_get_prep_to_pay;

  FUNCTION get_prep_to_pay RETURN number IS
  BEGIN
    RETURN g_remain_prep_amount;
  END;

  --Retrieve the last "as of date" in the xxap_prep_sla_open_invoices before the requested end date and set it to global.
  FUNCTION set_sla_last_date(p_end_date DATE) RETURN NUMBER AS
  
  BEGIN

        select NVL(max(xpsoi.as_of_date),to_date('20090101','yyyymmdd'))
          into g_sla_last_date
          from xxap_prep_sla_open_invoices xpsoi
         where xpsoi.as_of_date <= p_end_date
           and xpsoi.source_distribution_type = 'AP_INV_DIST';
      
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

  --set the accounts into table global. 
  --this program (and the related view on disco) supports up to 5 accounts separated with "-" in the string.
  FUNCTION set_sla_prep_accounts(p_accounts varchar2) RETURN NUMBER AS
  
  l_cur_start_pos     number :=0;
  l_cur_end_pos       number;
  l_account           varchar2(50);

  
  BEGIN

    t_sla_prep_account  := t_reset_varchar;
    
  
    BEGIN
      FOR idx IN 1 .. 5 loop
        
        l_cur_end_pos := instr(p_accounts,'-',1,idx);
        
        if l_cur_end_pos != 0 then
          l_account := substr(p_accounts,l_cur_start_pos+1,l_cur_end_pos-l_cur_start_pos-1);
        else -- =0
          l_account := substr(p_accounts,l_cur_start_pos+1);
        end if;
        
        select l_account
          into t_sla_prep_account(idx)
          from dual;
          
        if l_cur_end_pos = 0 then exit; end if;  
        l_cur_start_pos := l_cur_end_pos;
        
              
      end loop;
    
    EXCEPTION
      WHEN OTHERS THEN
        RETURN null;
    END;

    RETURN(1);
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN null;
    
  END set_sla_prep_accounts;

  FUNCTION get_sla_prep_accounts (p_count number) RETURN varchar2 IS
  BEGIN
    RETURN t_sla_prep_account(p_count);
  END;
  
  --Returns Y (i.e. Yes) if there are no distributions with: 
  --a. expense account (600000-699999) and b. inventory item isn't assigned to line.
  --Returns C (i.e. Check) if there are mixed distributions.
  --Returns Null in other case.
  FUNCTION is_inventory_po(p_po_header_id number) RETURN VARCHAR2 AS
  
  l_count_all_dist   number;
  l_count_exists     number;
  l_is_inv           varchar2(1);
  
  BEGIN
        --count of existing expense distributions in the po
        select nvl(count(1),0)
          into l_count_exists
          from po_distributions_all pd,
               po_lines_all         pl,
               gl_code_combinations gcc
         where gcc.code_combination_id = pd.code_combination_id
           and pl.po_line_id = pd.po_line_id
           and pd.gl_cancelled_date is null
           and gcc.segment3 between '600000' and '699999'
           and pl.item_id is null
           and nvl(pl.cancel_flag,'N') = 'N'
           and pd.po_header_id = p_po_header_id;
           
         if l_count_exists != 0 then
            --there are expense dists.
            --check if there are also other distributions

            --count total distributions in current po
            select nvl(count(1),0)
              into l_count_all_dist
              from po_distributions_all pd
             where pd.gl_cancelled_date is null
               and pd.po_header_id = p_po_header_id;
            
             if l_count_all_dist != l_count_exists then
                --there are mixed dists
                l_is_inv := 'C';
             else --all exp dists
                l_is_inv := null;
             end if;
         
         else --there are no exp dists
            l_is_inv := 'Y';
         end if;
              
    RETURN l_is_inv;
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN null;
    
  END is_inventory_po;  

  --procedure to test the data (for all periods by total amount and total count) 
  --in the xxap_prep_open_invoices table and insert the data to relevant periods.
  --the relevant periods are the period that the data there was found as different and 
  --all periods after that period.
PROCEDURE test_upload_prep_open_inv_data(errbuf  OUT VARCHAR2,
                                         retcode OUT NUMBER) IS

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
              from (select aid.amount, aid.period_name
                      from ap_invoice_distributions_all aid,
                           ap_invoices_all              ai
                     where aid.invoice_id = ai.invoice_id
                       and ai.invoice_type_lookup_code = 'PREPAYMENT'
                       and aid.line_type_lookup_code = 'ITEM'
                       and aid.accounting_date between p_first_start_date and
                           p_last_end_date
                    union all
                    select aid.amount, aid.period_name
                      from ap_invoice_distributions_all aid
                     where aid.line_type_lookup_code = 'PREPAY'
                       and aid.prepay_distribution_id is not null
                       and aid.accounting_date between p_first_start_date and
                           p_last_end_date)
             group by period_name) a,
           gl_periods gp
     where gp.period_name = a.period_name
       and gp.period_set_name = 'OBJET_CALENDAR'
       and gp.adjustment_period_flag = 'N'
     order by gp.end_date;

BEGIN

  fnd_file.PUT_LINE(fnd_file.log, 'starting program at: ' ||to_char(sysdate,'hh24:mi:ss'));

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
          select trunc(xpoi.as_of_date, 'mm'),
                 xpoi.as_of_date,
                 min(xpoi.test_period_last_upd_date)
            from xxap_prep_open_invoices xpoi
           where xpoi.as_of_date <= l_last_end_date_to_insert
           group by xpoi.as_of_date);

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
                    from (select aid.amount, aid.period_name
                            from ap_invoice_distributions_all aid,
                                 ap_invoices_all              ai
                           where aid.invoice_id = ai.invoice_id
                             and ai.invoice_type_lookup_code = 'PREPAYMENT'
                             and aid.line_type_lookup_code = 'ITEM'
                             and aid.accounting_date between
                                 l_first_start_date_to_check and
                                 l_last_end_date_to_insert
                          union all
                          select aid.amount, aid.period_name
                            from ap_invoice_distributions_all aid
                           where aid.line_type_lookup_code = 'PREPAY'
                             and aid.prepay_distribution_id is not null
                             and aid.accounting_date between
                                 l_first_start_date_to_check and
                                 l_last_end_date_to_insert)
                   group by period_name) a,
                 gl_periods gp
           where gp.period_name = a.period_name
             and gp.period_set_name = 'OBJET_CALENDAR'
             and gp.adjustment_period_flag = 'N'
          minus
          select xpoi.as_of_date,
                 trunc(xpoi.as_of_date, 'mm'),
                 min(xpoi.test_total_amount),
                 min(xpoi.test_total_count)
            from xxap_prep_open_invoices xpoi
           where xpoi.as_of_date between l_first_end_date_to_check and
                 l_last_end_date_to_insert
           group by xpoi.as_of_date);

  fnd_file.PUT_LINE(fnd_file.log,
                    'after testing periods, program at: ' || to_char(sysdate,'hh24:mi:ss'));
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
    delete xxap_prep_open_invoices xpoi
     where xpoi.as_of_date between l_first_end_date_to_insert and
           l_last_end_date_to_insert;
  
    commit;
  
    fnd_file.PUT_LINE(fnd_file.log, 'deleted records');
    fnd_file.PUT_LINE(fnd_file.log,
                      'after deleting records, program at: ' || to_char(sysdate,'hh24:mi:ss'));
  
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
      --the insert logic is based on the view for the disco: xxap_prep_open_balance_disco_v
      insert into xxap_prep_open_invoices
        (select periods_to_change_csr.end_date,
                aid.invoice_distribution_id,
                decode(aid.line_type_lookup_code,
                       'ITEM',
                       'PREPAYMENT',
                       'PREPAY',
                       'APPLIED INVOICE') meaning,
                sysdate,
                periods_to_change_csr.total_amount,
                periods_to_change_csr.total_count,
                l_period_last_upd_date
           from ap_invoice_distributions_all aid_prep,
                ap_invoice_distributions_all aid,
                (select *
                   from (select prepayments.dist_id,
                                sum(prepayments.amount) over(partition by prepayments.prep_inv_id) balance
                           from (select aid_prep.invoice_id prep_inv_id,
                                        aid_prep.invoice_distribution_id dist_id,
                                        aid_prep.amount
                                   from ap_invoice_distributions aid_prep,
                                        (select xpoi.invoice_dist_id dist_id
                                           from xxap_prep_open_invoices xpoi
                                          where xpoi.meaning = 'PREPAYMENT'
                                            and xpoi.as_of_date = get_last_date
                                         union all
                                         select aid.Invoice_Distribution_Id dist_id
                                           from ap_invoice_distributions_all aid,
                                                ap_invoices_all              ai
                                          where ai.invoice_id = aid.invoice_id
                                            and ai.invoice_type_lookup_code =
                                                'PREPAYMENT'
                                            and aid.line_type_lookup_code =
                                                'ITEM'
                                            and aid.accounting_date between
                                                get_last_date + 1 and
                                                periods_to_change_csr.end_date) relevant_dist
                                  where aid_prep.invoice_distribution_id =
                                        relevant_dist.dist_id
                                 union all
                                 select aid_prep2.invoice_id prep_inv_id,
                                        aid_inv.invoice_distribution_id dist_id,
                                        aid_inv.amount
                                   from ap_invoice_distributions aid_inv,
                                        ap_invoice_distributions_all aid_prep2,
                                        (select xpoi.invoice_dist_id dist_id
                                           from xxap_prep_open_invoices xpoi
                                          where xpoi.meaning =
                                                'APPLIED INVOICE'
                                            and xpoi.as_of_date = get_last_date
                                         union all
                                         select aid.Invoice_Distribution_Id dist_id
                                           from ap_invoice_distributions_all aid
                                          where aid.line_type_lookup_code =
                                                'PREPAY'
                                            and aid.accounting_date between
                                                get_last_date + 1 and
                                                periods_to_change_csr.end_date
                                            and aid.prepay_distribution_id is not null /*for index use*/
                                         ) relevant_dist
                                  where aid_inv.prepay_distribution_id =
                                        aid_prep2.invoice_distribution_id
                                    and aid_inv.invoice_distribution_id =
                                        relevant_dist.dist_id) prepayments)
                  where balance != 0) open_prep
          where aid.prepay_distribution_id =
                aid_prep.invoice_distribution_id(+)
            and aid.invoice_distribution_id = open_prep.dist_id);
    
      commit;
    
      fnd_file.PUT_LINE(fnd_file.log,
                        'inserted records for end as of date: ' ||
                        periods_to_change_csr.end_date);
      fnd_file.PUT_LINE(fnd_file.log,
                        'after inserting, program at: ' || to_char(sysdate,'hh24:mi:ss'));
    
    end loop;
  end if;

  --update period last update date in test column for periods that aren't needed to be deleted and inserted again 
  if l_first_end_date_to_check < nvl(l_first_end_date_to_insert, l_last_end_date_to_insert) then

      fnd_file.PUT_LINE(fnd_file.log, 'updating period''s last_update_date in test column...');
      
      update xxap_prep_open_invoices xpoi
         set xpoi.test_period_last_upd_date = 
                                  (select max(gps.last_update_date)
                                    from gl_period_statuses gps, gl_ledgers gl
                                   where gps.application_id = 200
                                     and gps.end_date = xpoi.as_of_date
                                     and gl.ledger_id = gps.ledger_id
                                     and gl.ledger_category_code = 'PRIMARY'
                                     and gps.closing_status in ('C', 'O'))
       where xpoi.as_of_date >= l_first_end_date_to_check 
         and xpoi.as_of_date < nvl(l_first_end_date_to_insert, l_last_end_date_to_insert);
       
       commit;
  end if;

EXCEPTION
  WHEN OTHERS THEN
    retcode := 2;
    errbuf  := SQLERRM;
END test_upload_prep_open_inv_data;


  --procedure to test the data (for all periods by total amount and total count) 
  --in the xxap_prep_sla_open_invoices table and insert the data to relevant periods.
  --the relevant periods are the period that the data there was found as different and 
  --all periods after that period.
PROCEDURE test_upl_prep_sla_open_inv_dat(errbuf     OUT VARCHAR2,
                                         retcode    OUT NUMBER,
                                         p_accounts IN VARCHAR2) IS

  l_first_end_date_to_insert   date;
  l_first_start_date_to_insert date;
  l_first_start_date_to_check  date;
  l_first_end_date_to_check    date;
  l_last_end_date_to_insert    date;
  l_set_last_date              number;
  l_set_prep_accounts          number;
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
               and (gcc.segment3 = get_sla_prep_accounts(1) or --done like this to use the index
                   gcc.segment3 = get_sla_prep_accounts(2) or
                   gcc.segment3 = get_sla_prep_accounts(3) or
                   gcc.segment3 = get_sla_prep_accounts(4) or
                   gcc.segment3 = get_sla_prep_accounts(5))
             group by xh.period_name) a,
           gl_periods gp
     where gp.period_name = a.period_name
       and gp.period_set_name = 'OBJET_CALENDAR'
       and gp.adjustment_period_flag = 'N'
     order by gp.end_date;

BEGIN

  fnd_file.PUT_LINE(fnd_file.log, 'starting program at: '||to_char(sysdate,'hh24:mi:ss'));
  --initialize prepayment accounts
  l_set_prep_accounts := set_sla_prep_accounts(p_accounts);

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
          select trunc(xpsoi.as_of_date, 'mm'),
                 xpsoi.as_of_date,
                 min(xpsoi.test_period_last_upd_date)
            from xxap_prep_sla_open_invoices xpsoi
           where xpsoi.as_of_date <= l_last_end_date_to_insert
           group by xpsoi.as_of_date);

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
                     and (gcc.segment3 = get_sla_prep_accounts(1) or --done like this to use the index
                         gcc.segment3 = get_sla_prep_accounts(2) or
                         gcc.segment3 = get_sla_prep_accounts(3) or
                         gcc.segment3 = get_sla_prep_accounts(4) or
                         gcc.segment3 = get_sla_prep_accounts(5))
                   group by xh.period_name) a,
                 gl_periods gp
           where gp.period_name = a.period_name
             and gp.period_set_name = 'OBJET_CALENDAR'
             and gp.adjustment_period_flag = 'N'
          minus
          select xpsoi.as_of_date,
                 trunc(xpsoi.as_of_date, 'mm'),
                 min(xpsoi.test_total_amount),
                 min(xpsoi.test_total_count)
            from xxap_prep_sla_open_invoices xpsoi
           where xpsoi.as_of_date between l_first_end_date_to_check and
                 l_last_end_date_to_insert
           group by xpsoi.as_of_date);

  fnd_file.PUT_LINE(fnd_file.log, 'after testing periods, program at: '||to_char(sysdate,'hh24:mi:ss'));
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
    delete xxap_prep_sla_open_invoices xpsoi
     where xpsoi.as_of_date between l_first_end_date_to_insert and
           l_last_end_date_to_insert;
  
    commit;
  
    fnd_file.PUT_LINE(fnd_file.log, 'deleted records');
    fnd_file.PUT_LINE(fnd_file.log, 'after deleting records, program at: '||to_char(sysdate,'hh24:mi:ss'));    
  
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
      --the insert logic is based on the view for the disco: xxap_prep_open_sla_bal_disco_v
    
      insert into xxap_prep_sla_open_invoices
        (select distinct periods_to_change_csr.end_date,
                         aa.ae_header_id,
                         aa.ae_line_num,
                         aa.source_distribution_type,
                         sysdate,
                         periods_to_change_csr.total_amount,
                         periods_to_change_csr.total_count,
                         l_period_last_upd_date
           from (select sum(entered) over(partition by prepayment_id) prep_remain,
                        a.*
                   from (select nvl(xdl.unrounded_entered_dr, 0) -
                                nvl(xdl.unrounded_entered_cr, 0) entered,
                                xdl.source_distribution_type,
                                xl.ae_header_id,
                                xl.ae_line_num,
                                decode(ai.invoice_type_lookup_code,
                                       'PREPAYMENT',
                                       ai.invoice_id,
                                       -ai.org_id||xl.code_combination_id) prepayment_id
                           from xla_ae_lines xl,
                                xla_ae_headers xh,
                                ap_invoices_all ai,
                                xla_distribution_links xdl,
                                ap_invoice_distributions_all aid,
                                (select xpsoi.ae_header_id, xpsoi.ae_line_num
                                   from xxap_prep_sla_open_invoices xpsoi
                                  where xpsoi.source_distribution_type =
                                        'AP_INV_DIST'
                                    and xpsoi.as_of_date = get_sla_last_date
                                 union all
                                 select xl2.ae_header_id, xl2.ae_line_num
                                   from xla_ae_lines         xl2,
                                        gl_code_combinations gcc
                                  where xl2.application_id = 200
                                    and xl2.accounting_date between
                                        get_sla_last_date + 1 and
                                        periods_to_change_csr.end_date
                                    and gcc.code_combination_id =
                                        xl2.code_combination_id
                                    and (gcc.segment3 =
                                        get_sla_prep_accounts(1) or --done like this to use the index
                                        gcc.segment3 =
                                        get_sla_prep_accounts(2) or
                                        gcc.segment3 =
                                        get_sla_prep_accounts(3) or
                                        gcc.segment3 =
                                        get_sla_prep_accounts(4) or
                                        gcc.segment3 =
                                        get_sla_prep_accounts(5))) relevant_ae_lines
                          where xl.application_id = 200
                            and xl.application_id = xh.application_id
                            and xl.application_id = xdl.application_id
                            and xl.ae_header_id = xh.ae_header_id
                            and xdl.ae_header_id = xl.ae_header_id
                            and xdl.ae_line_num = xl.ae_line_num
                            and xdl.source_distribution_id_num_1 =
                                aid.invoice_distribution_id
                            and nvl(xdl.source_distribution_id_char_2, (-99)) = -99
                            and xdl.source_distribution_type = 'AP_INV_DIST'
                            AND XH.ACCOUNTING_ENTRY_TYPE_CODE != 'MANUAL'
                            and xh.balance_type_code = 'A'
                            and aid.invoice_id = ai.invoice_id
                            and relevant_ae_lines.ae_header_id =
                                xl.ae_header_id
                            and relevant_ae_lines.ae_line_num =
                                xl.ae_line_num
                         union all
                         select nvl(xdl.unrounded_entered_dr, 0) -
                                nvl(xdl.unrounded_entered_cr, 0) entered,
                                xdl.source_distribution_type,
                                xl.ae_header_id,
                                xl.ae_line_num,
                                ai_prep.invoice_id prep_id
                           from xla_ae_lines xl,
                                xla_ae_headers xh,
                                ap_invoices_all ai_prep,
                                xla_distribution_links xdl,
                                ap_invoice_distributions_all aid,
                                ap_invoice_distributions_all aid_prep,
                                ap_prepay_app_dists apad,
                                (select xpsoi.ae_header_id, xpsoi.ae_line_num
                                   from xxap_prep_sla_open_invoices xpsoi
                                  where xpsoi.source_distribution_type =
                                        'AP_PREPAY'
                                    and xpsoi.as_of_date = get_sla_last_date
                                 union all
                                 select xl2.ae_header_id, xl2.ae_line_num
                                   from xla_ae_lines         xl2,
                                        gl_code_combinations gcc
                                  where xl2.application_id = 200
                                    and xl2.accounting_date between
                                        get_sla_last_date + 1 and
                                        periods_to_change_csr.end_date
                                    and gcc.code_combination_id =
                                        xl2.code_combination_id
                                    and (gcc.segment3 =
                                        get_sla_prep_accounts(1) or --done like this to use the index
                                        gcc.segment3 =
                                        get_sla_prep_accounts(2) or
                                        gcc.segment3 =
                                        get_sla_prep_accounts(3) or
                                        gcc.segment3 =
                                        get_sla_prep_accounts(4) or
                                        gcc.segment3 =
                                        get_sla_prep_accounts(5))) relevant_ae_lines
                          where xl.application_id = 200
                            and xl.application_id = xh.application_id
                            and xl.application_id = xdl.application_id
                            and xl.ae_header_id = xh.ae_header_id
                            and xdl.ae_header_id = xl.ae_header_id
                            and xdl.ae_line_num = xl.ae_line_num
                            and xdl.source_distribution_id_num_1 =
                                apad.prepay_app_dist_id
                            and nvl(xdl.source_distribution_id_char_2, (-99)) = -99
                            and xdl.source_distribution_type = 'AP_PREPAY'
                            AND XH.ACCOUNTING_ENTRY_TYPE_CODE != 'MANUAL'
                            and xh.balance_type_code = 'A'
                            and aid.invoice_distribution_id =
                                apad.prepay_app_distribution_id
                            and aid_prep.invoice_distribution_id =
                                aid.prepay_distribution_id
                            and aid_prep.invoice_id = ai_prep.invoice_id
                            and relevant_ae_lines.ae_header_id =
                                xl.ae_header_id
                            and relevant_ae_lines.ae_line_num =
                                xl.ae_line_num
                          
                          --xla manual transactions from data fixes doesn't have the relation to distribution id.
                          --thus, i use here the ref accounting event to retrieve the data.
                         union all
                         select nvl(xdl.unrounded_entered_dr, 0) -
                                nvl(xdl.unrounded_entered_cr, 0) entered,
                                xdl.source_distribution_type,
                                xl.ae_header_id,
                                xl.ae_line_num,
                                 decode(ai.invoice_type_lookup_code,
                                        'PREPAYMENT',
                                        ai.invoice_id,
                                        'STANDARD',
                                        --if it is a prepay distribution then the ai_prep.invoice id will be returned,
                                        --otherwise, concatenated org id with code combination id will be retruned (it is prepayment account on standard invoice case)
                                        nvl(ai_prep.invoice_id,-ai.org_id||xl.code_combination_id)) prepayment_id
                            from xla_ae_lines         xl,
                                 xla_ae_headers       xh,
                                 ap_invoices_all              ai,
                                 ap_invoices_all              ai_prep,
                                 xla_distribution_links       xdl,
                                 ap_invoice_distributions     aid,
                                 ap_invoice_distributions_all aid_prep,
                                (select xpsoi.ae_header_id, xpsoi.ae_line_num
                                   from xxap_prep_sla_open_invoices xpsoi
                                  where xpsoi.source_distribution_type =
                                        'XLA_MANUAL'
                                    and xpsoi.as_of_date = get_sla_last_date
                                 union all
                                 select xl2.ae_header_id, xl2.ae_line_num
                                   from xla_ae_lines         xl2,
                                        gl_code_combinations gcc
                                  where xl2.application_id = 200
                                    and xl2.accounting_date between
                                        get_sla_last_date + 1 and
                                        periods_to_change_csr.end_date
                                    and gcc.code_combination_id =
                                        xl2.code_combination_id
                                    and (gcc.segment3 =
                                        get_sla_prep_accounts(1) or --done like this to use the index
                                        gcc.segment3 =
                                        get_sla_prep_accounts(2) or
                                        gcc.segment3 =
                                        get_sla_prep_accounts(3) or
                                        gcc.segment3 =
                                        get_sla_prep_accounts(4) or
                                        gcc.segment3 =
                                        get_sla_prep_accounts(5))) relevant_ae_lines
                               where xl.application_id = 200
                                 and xl.application_id = xh.application_id
                                 and xl.application_id = xdl.application_id
                                 and xl.ae_header_id = xh.ae_header_id
                                 and xdl.ae_header_id = xl.ae_header_id
                                 and xdl.ae_line_num = xl.ae_line_num
                                 and xdl.source_distribution_type = 'XLA_MANUAL'
                                 --AND XH.ACCOUNTING_ENTRY_TYPE_CODE = 'MANUAL'                   
                                 and xh.balance_type_code = 'A'
                                 and aid.accounting_event_id = xdl.ref_event_id
                                 and aid.invoice_id = ai.invoice_id
                                 and aid_prep.invoice_distribution_id(+) =
                                     aid.prepay_distribution_id
                                 and aid_prep.invoice_id = ai_prep.invoice_id(+)
                                 and relevant_ae_lines.ae_header_id = xl.ae_header_id
                                 and relevant_ae_lines.ae_line_num = xl.ae_line_num                                   

                          --Manual transactions from data fixes for ap_prepay source has source id but it sometimes doesn't have a related value
                          --in ap_prepay_app_dist table. 
                          --thus, i use here the applied to dist num to retrieve the data.
                         union all
                         select nvl(xdl.unrounded_entered_dr, 0) -
                                nvl(xdl.unrounded_entered_cr, 0) entered,
                                xdl.source_distribution_type,
                                xl.ae_header_id,
                                xl.ae_line_num,
                                ai_prep.invoice_id prepayment_id
                            from xla_ae_lines         xl,
                                 xla_ae_headers       xh,
                                 xla_transaction_entities_upg xte,
                                 ap_invoices_all              ai,
                                 ap_invoices_all              ai_prep,
                                 xla_distribution_links       xdl,
                                 ap_invoice_distributions_all aid_prep,
                                (select xpsoi.ae_header_id, xpsoi.ae_line_num
                                   from xxap_prep_sla_open_invoices xpsoi
                                  where xpsoi.source_distribution_type =
                                        'AP_PREPAY'
                                    and xpsoi.as_of_date = get_sla_last_date
                                 union all
                                 select xl2.ae_header_id, xl2.ae_line_num
                                   from xla_ae_lines         xl2,
                                        gl_code_combinations gcc
                                  where xl2.application_id = 200
                                    and xl2.accounting_date between
                                        get_sla_last_date + 1 and
                                        periods_to_change_csr.end_date
                                    and gcc.code_combination_id =
                                        xl2.code_combination_id
                                    and (gcc.segment3 =
                                        get_sla_prep_accounts(1) or --done like this to use the index
                                        gcc.segment3 =
                                        get_sla_prep_accounts(2) or
                                        gcc.segment3 =
                                        get_sla_prep_accounts(3) or
                                        gcc.segment3 =
                                        get_sla_prep_accounts(4) or
                                        gcc.segment3 =
                                        get_sla_prep_accounts(5))) relevant_ae_lines
                             where xl.application_id = 200
                               and xl.application_id = xh.application_id
                               and xl.application_id = xdl.application_id
                               and xl.application_id = xte.application_id
                               and xl.ae_header_id = xh.ae_header_id
                               and xh.entity_id = xte.entity_id
                               and xdl.ae_header_id = xl.ae_header_id
                               and xdl.ae_line_num = xl.ae_line_num
                               and xdl.source_distribution_type = 'AP_PREPAY' --CURRENTLY THERE IS NO CASE FOR 'AP INV DIST' BUT IN FUTRE IF IT WILL BE 
                                                                              --THEN ADDITIONAL UNION SHOULD BE ADDED WITH RELEVANT ADJUSTMENTS!!!
                               AND XH.ACCOUNTING_ENTRY_TYPE_CODE = 'MANUAL'                   
                               and xh.balance_type_code = 'A'
                               and aid_prep.invoice_distribution_id = xdl.applied_to_dist_id_num_1
                               and xte.source_id_int_1 = ai.invoice_id
                               and aid_prep.invoice_id = ai_prep.invoice_id
                               and relevant_ae_lines.ae_header_id = xl.ae_header_id
                               and relevant_ae_lines.ae_line_num = xl.ae_line_num                
                                ) a) aa
          where prep_remain != 0);
    
      commit;
    
      fnd_file.PUT_LINE(fnd_file.log,
                        'insert records for end as of date: ' ||
                        periods_to_change_csr.end_date);
      fnd_file.PUT_LINE(fnd_file.log, 'after inserting, program at: '||to_char(sysdate,'hh24:mi:ss'));                        
    
    end loop;
  end if;

  --update period last update date in test column for periods that aren't needed to be deleted and inserted again 
  if l_first_end_date_to_check < nvl(l_first_end_date_to_insert, l_last_end_date_to_insert) then

      fnd_file.PUT_LINE(fnd_file.log, 'updating period''s last_update_date in test column...');
      
      update xxap_prep_sla_open_invoices xpsoi
         set xpsoi.test_period_last_upd_date = 
                                  (select max(gps.last_update_date)
                                    from gl_period_statuses gps, gl_ledgers gl
                                   where gps.application_id = 200
                                     and gps.end_date = xpsoi.as_of_date
                                     and gl.ledger_id = gps.ledger_id
                                     and gl.ledger_category_code = 'PRIMARY'
                                     and gps.closing_status in ('C', 'O'))
       where xpsoi.as_of_date >= l_first_end_date_to_check 
         and xpsoi.as_of_date < nvl(l_first_end_date_to_insert, l_last_end_date_to_insert);
       
       commit;
  end if;

EXCEPTION
  WHEN OTHERS THEN
    retcode := 2;
    errbuf  := SQLERRM;
END test_upl_prep_sla_open_inv_dat;

end xxap_prep_open_balance_disco;
/

