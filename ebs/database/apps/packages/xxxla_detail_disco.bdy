CREATE OR REPLACE PACKAGE BODY xxxla_detail_disco IS
  --------------------------------------------------------------------
  --  name:            XXXLA_DETAIL_DISCO
  --  create by:       DANIEL.KATZ
  --  Revision:        1.0
  --  creation date:   12/19/2010
  --------------------------------------------------------------------
  --  purpose :        xla details report
  --------------------------------------------------------------------
  --  Ver   When         Who              Desc
  --  ----  ----------   --------------   ----------------------------
  --  1.0   12/19/2010   DANIEL.KATZ      initial build
  --  1.1   28/10/2014   Ofer Suad        CHG0033589 - XLA Detail Report - add project accounting journal and RECEIVING_SUB_LEDGER data
  --  1.2   25-Sep-2018  Offer S.         CHG0044007 - Map in Oracle XLA upload program and BI view for
  --                                         project details associated for move orders.
  --                                       pull the project id to be used by XXBI_XLA_TRANSACTIONS_V
  -- 1.3   15-Oct-2020 Ofer Suad           CHG0048772 XLA not including Cost Management write-off  Entries 
  --------------------------------------------------------------------

  --------------------------------------------------------------------
  --  name:            test_upl_detail_data
  --  create by:       DANIEL.KATZ
  --  Revision:        1.0
  --  creation date:   12/19/2010
  --------------------------------------------------------------------
  --  purpose :        xla details report
  --                   procedure to test the data (for all relevant lines in relevant periods by last updated date)
  --                   in the XXXLA_SLA_EXPENSE_DETAILS table and insert the data to relevant lines related to accounting dates.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  12/19/2010  DANIEL.KATZ       initial build
  --  1.1  28/10/2014  Ofer Suad         CHG0033589
  --                                     XLA Detail Report - add project accounting journal and RECEIVING_SUB_LEDGER data
  -- 1.2   18/01/2015  Ofer Suad         CHG0034238 -  Add set and get Account/Department parents

  -- 18/01/2015  Ofer Suad CHG0034238 - Global arrays to keep Account/Department parents and description
  p_accts parent_accounts;
  p_depts parent_depts;

  p_acct_desc parent_account_desc;
  p_dept_desc parent_dept_desc;

  ------------------------------------------------------------------------------------------------------
  -- Ver   When         Who            Descr 
  -- ----  -----------  -------------  -----------------------------------------------------------------
  -- 1.0   21/10/2020   Ofer S.        CHG0048772 - XLA not including Cost Management writeoff  Entries
  ------------------------------------------------------------------------------------------------------  
  PROCEDURE test_upl_detail_data(errbuf          OUT VARCHAR2,
                                 retcode         OUT NUMBER,
                                 p_ledger_set_id IN NUMBER) IS
  
    --constant account values
    c_exp_account_from      VARCHAR2(25) := '600000';
    c_exp_account_to        VARCHAR2(25) := '699999';
    c_bud_account_from      VARCHAR2(25) := '950000';
    c_bud_account_to        VARCHAR2(25) := '959999';
    c_fa_clr_account_from   VARCHAR2(25) := '189000';
    c_fa_clr_account_to     VARCHAR2(25) := '189199';
    c_fa_account_from       VARCHAR2(25) := '181000';
    c_fa_account_to         VARCHAR2(25) := '181999';
    c_prep_exp_account_from VARCHAR2(25) := '141300';
    c_prep_exp_account_to   VARCHAR2(25) := '141399';
  
    --varialbes
    l_closing_status_period        VARCHAR2(1);
    l_period_last_upd_date         DATE;
    l_is_exist_table_update_record VARCHAR2(1);
    l_max_header_id_saved          NUMBER;
    l_max_header_id                NUMBER;
    l_min_header_id_not_posted     NUMBER;
    l_max_header_id_to_save        NUMBER;
  
    --bring all relevant periods to check:
    -- open or future periods or closed periods in case their last update date was changed
    CURSOR csr_periods_to_change IS(
      SELECT gps.application_id,
             gps.ledger_id,
             gps.period_name,
             gps.start_date,
             gps.end_date,
             (CASE
               WHEN gps.closing_status IN ('C', 'P') THEN
                gps.last_update_date
               WHEN gps.closing_status IN ('O', 'F') THEN
                SYSDATE + 100
             END) last_update_date
        FROM gl_period_statuses gps, gl_ledgers gl
       WHERE gps.application_id IN (200, 201) --AP and Purchasing
         AND gps.adjustment_period_flag = 'N'
         AND gl.ledger_id = gps.ledger_id
         AND gl.ledger_category_code = 'PRIMARY'
         AND gps.closing_status IN ('C', 'O', 'F', 'P')
         AND gps.effective_period_num >= 20090009 --go live effective period num
         AND (gl.ledger_id IN
             (SELECT glsa.ledger_id
                 FROM gl_ledger_set_assignments glsa
                WHERE glsa.ledger_set_id = p_ledger_set_id))
      ------------------------------------------------------------------------------
      --and gps.end_date between l_from_date and l_to_date
      ------------------------------------------------------------------------------
      UNION ALL
      --relevant inventory periods are according to the GL periods status,
      --because inv closing period cannot sure that create accounting was done.
      --Anyway, the maximum relevant period is according to existing inventory periods.
      SELECT 707 application_id,
             gps.ledger_id,
             gps.period_name,
             gps.start_date,
             gps.end_date,
             (CASE
               WHEN gps.closing_status IN ('C', 'P') THEN
                gps.last_update_date
               WHEN gps.closing_status IN ('O', 'F') THEN
                SYSDATE + 100
             END) last_update_date
        FROM gl_period_statuses gps,
             gl_ledgers gl,
             (SELECT hoi.org_information1 ledger_id, oap.period_name
                FROM org_acct_periods oap, hr_organization_information hoi
               WHERE oap.organization_id = hoi.organization_id
                 AND hoi.org_information_context = 'Accounting Information'
               GROUP BY hoi.org_information1, oap.period_name) inv_periods
       WHERE gps.ledger_id = inv_periods.ledger_id
         AND gps.period_name = inv_periods.period_name
         AND gps.application_id = 101 --GL for Inventory
         AND gps.adjustment_period_flag = 'N'
         AND gl.ledger_id = gps.ledger_id
         AND gl.ledger_category_code = 'PRIMARY'
         AND gps.closing_status IN ('C', 'O', 'F', 'P')
         AND gps.effective_period_num >= 20090009 --go live effective period num
         AND (gl.ledger_id IN
             (SELECT glsa.ledger_id
                 FROM gl_ledger_set_assignments glsa
                WHERE glsa.ledger_set_id = p_ledger_set_id))
      ------------------------------------------------------------------------------
      --and gps.end_date between l_from_date and l_to_date
      ------------------------------------------------------------------------------
      UNION ALL
      --relevant FA periods are according to the GL periods status,
      --because FA closing period cannot sure that create accounting was done.
      --Anyway, the maximum relevant period is according to existing FA periods.
      SELECT 140 application_id,
             gps.ledger_id,
             gps.period_name,
             gps.start_date,
             gps.end_date,
             (CASE
               WHEN gps.closing_status IN ('C', 'P') THEN
                gps.last_update_date
               WHEN gps.closing_status IN ('O', 'F') THEN
                SYSDATE + 100
             END) last_update_date
        FROM gl_period_statuses gps,
             gl_ledgers gl,
             (SELECT fbc.set_of_books_id ledger_id, fdp.period_name
                FROM fa_deprn_periods fdp, fa_book_controls fbc
               WHERE fdp.book_type_code = fbc.book_type_code
               GROUP BY fbc.set_of_books_id, fdp.period_name) fa_periods
       WHERE gps.ledger_id = fa_periods.ledger_id
         AND gps.period_name = fa_periods.period_name
         AND gps.application_id = 101 --GL for FA
         AND gps.adjustment_period_flag = 'N'
         AND gl.ledger_id = gps.ledger_id
         AND gl.ledger_category_code = 'PRIMARY'
         AND gps.closing_status IN ('C', 'O', 'F', 'P')
         AND gps.effective_period_num >= 20090009 --go live effective period num
         AND (gl.ledger_id IN
             (SELECT glsa.ledger_id
                 FROM gl_ledger_set_assignments glsa
                WHERE glsa.ledger_set_id = p_ledger_set_id))
      ------------------------------------------------------------------------------
      --and gps.end_date between l_from_date and l_to_date
      ------------------------------------------------------------------------------
      UNION ALL
      --GL Periods are relevant only to Actual GL Journals
      --Manual GL Transactions for Budget or Encumbrance will be updated once
      --according to last header id for each ledger.
      SELECT 101,
             gps.ledger_id,
             gps.period_name,
             gps.start_date,
             gps.end_date,
             (CASE
               WHEN gps.closing_status IN ('C', 'P') THEN
                gps.last_update_date
               WHEN gps.closing_status IN ('O', 'F') THEN
                SYSDATE + 100
             END) last_update_date
        FROM gl_period_statuses gps
       WHERE gps.application_id = 101 --GL
         AND gps.adjustment_period_flag = 'N'
         AND gps.closing_status IN ('C', 'O', 'F', 'P')
         AND gps.effective_period_num >= 20090009 --go live effective period num
         AND (gps.ledger_id IN
             (SELECT glsa.ledger_id
                 FROM gl_ledger_set_assignments glsa
                WHERE glsa.ledger_set_id = p_ledger_set_id))
      ------------------------------------------------------------------------------
      --and gps.end_date between l_from_date and l_to_date
      ------------------------------------------------------------------------------
      UNION ALL
      --  CHG0033589  28-Oct-2014   Ofer Suad Add Projets module
      SELECT 275,
             gps.set_of_books_id,
             gps.period_name,
             gps.pa_start_date,
             gps.pa_end_date,
             (CASE
               WHEN gps.status IN ('C', 'P', 'W') THEN
                gps.last_update_date
               WHEN gps.status IN ('O', 'F') THEN
                SYSDATE + 100
             END) last_update_date
        FROM pa_periods_v gps
       WHERE gps.status IN ('C', 'O', 'F', 'P', 'W')
         AND gps.pa_start_date >= '01-jan-2014' --go live effective period num
         AND (gps.set_of_books_id IN
             (SELECT glsa.ledger_id
                 FROM gl_ledger_set_assignments glsa
                WHERE glsa.ledger_set_id = p_ledger_set_id)))
      MINUS
      SELECT xpslud.application_id,
             xpslud.ledger_id,
             xpslud.period_name,
             gp.start_date,
             gp.end_date,
             xpslud.test_period_last_upd_date
        FROM xx_periods_status_lst_upd_date xpslud, gl_periods gp
       WHERE gp.period_set_name = 'OBJET_CALENDAR'
         AND gp.period_name = xpslud.period_name
         AND (xpslud.ledger_id IN
             (SELECT glsa.ledger_id
                 FROM gl_ledger_set_assignments glsa
                WHERE glsa.ledger_set_id = p_ledger_set_id));
  
    --all relevant ledger ids related to primary ledger ids.
    --for application id 101 it bypasses the ledger id (only once) as in this case the previous cursor will bring also the reporting ledger!!!
    CURSOR csr_ledger_ids(p_csr_primary_ledger_id NUMBER,
                          p_csr_application_id    NUMBER) IS
      SELECT decode(p_csr_application_id,
                    101,
                    p_csr_primary_ledger_id,
                    gl.ledger_id) ledger_id
        FROM gl_ledgers gl
       WHERE decode(p_csr_application_id,
                    101,
                    gl.ledger_id,
                    gl.configuration_id) =
             decode(p_csr_application_id,
                    101,
                    p_csr_primary_ledger_id,
                    (SELECT gl2.configuration_id
                       FROM gl_ledgers gl2
                      WHERE gl2.ledger_id = p_csr_primary_ledger_id));
  
    --brings lines (of xla or gl) for particular application, ledger, period and accounting date (according to previous cursors)
    --that their count of records was changed.
    --this isn't relevant to GL Encumbrance & Budget transactions.
    --Manual GL Transactions for Budget or Encumbrance will be updated once
    --according to last header id for each ledger (because they aren't related to any Actual Period status).
    CURSOR csr_acc_dates_to_change(p_csr_application_id NUMBER,
                                   p_csr_ledger_id      NUMBER,
                                   p_csr_strt_date      DATE,
                                   p_csr_end_date       DATE,
                                   p_csr_period_name    VARCHAR2) IS(
      SELECT xh.application_id,
             xh.ledger_id,
             xh.accounting_date,
             COUNT(1) count_records
        FROM gl_code_combinations gcc, xla_ae_lines xl, xla_ae_headers xh /* xh for additional index use*/
       WHERE xl.application_id = xh.application_id
         AND xl.ae_header_id = xh.ae_header_id
         AND xh.accounting_entry_status_code = 'F'
         AND (abs(nvl(xl.unrounded_entered_dr, 0) -
                  nvl(xl.unrounded_entered_cr, 0)) +
             abs(nvl(xl.unrounded_accounted_dr, 0) -
                  nvl(xl.unrounded_accounted_cr, 0))) != 0
         AND xh.application_id = p_csr_application_id
         AND xh.ledger_id = p_csr_ledger_id
         AND xh.accounting_date BETWEEN p_csr_strt_date AND p_csr_end_date
         AND xh.ledger_id = xl.ledger_id
         AND xl.accounting_date BETWEEN p_csr_strt_date AND p_csr_end_date
         AND gcc.code_combination_id = xl.code_combination_id
         AND (gcc.segment3 BETWEEN c_exp_account_from AND c_exp_account_to OR
             gcc.segment3 BETWEEN c_bud_account_from AND c_bud_account_to OR
             gcc.segment3 BETWEEN c_fa_clr_account_from AND
             c_fa_clr_account_to OR
             gcc.segment3 BETWEEN c_fa_account_from AND c_fa_account_to OR
             gcc.segment3 BETWEEN c_prep_exp_account_from AND
             c_prep_exp_account_to)
       GROUP BY xh.accounting_date, xh.ledger_id, xh.application_id
      UNION ALL
      SELECT 101, jh.ledger_id, jl.effective_date, COUNT(1)
        FROM gl_code_combinations gcc, gl_je_lines jl, gl_je_headers jh /* jh for additional index use*/
       WHERE jl.je_header_id = jh.je_header_id
         AND 101 = p_csr_application_id
         AND (abs(nvl(jl.entered_dr, 0) - nvl(jl.entered_cr, 0)) +
             abs(nvl(jl.accounted_dr, 0) - nvl(jl.accounted_cr, 0))) != 0
         AND jh.period_name = p_csr_period_name
         AND jh.ledger_id = p_csr_ledger_id
         AND jh.period_name = jl.period_name
         AND jl.code_combination_id = gcc.code_combination_id
            --and jh.je_source not in ('Purchasing', 'Assets', 'Cost Management', 'Payables')
         AND (nvl(jh.je_from_sla_flag, 'N') = 'N' OR
             jh.je_source = 'Receivables')
         AND jh.status = 'P'
         AND jh.actual_flag = 'A' --relevant only for Actual
         AND (gcc.segment3 BETWEEN c_exp_account_from AND c_exp_account_to OR
             gcc.segment3 BETWEEN c_bud_account_from AND c_bud_account_to OR
             gcc.segment3 BETWEEN c_fa_clr_account_from AND
             c_fa_clr_account_to OR
             gcc.segment3 BETWEEN c_fa_account_from AND c_fa_account_to OR
             gcc.segment3 BETWEEN c_prep_exp_account_from AND
             c_prep_exp_account_to)
       GROUP BY jh.ledger_id, jl.effective_date)
      MINUS
      SELECT xsed.application_id,
             xsed.ledger_id,
             xsed.gl_date,
             MAX(xsed.test_total_count) --in Manual GL Budget & Encumbrance the field is null, so it won't influence
        FROM xxxla_sla_expense_details xsed
       WHERE xsed.application_id = p_csr_application_id
         AND xsed.ledger_id = p_csr_ledger_id
         AND xsed.gl_date BETWEEN p_csr_strt_date AND p_csr_end_date
       GROUP BY xsed.gl_date, xsed.application_id, xsed.ledger_id;
  
    --ledgers cursor for GL encumbrance & budget transactions
    CURSOR csr_ledger_ids_enc_bud IS
      SELECT gl.ledger_id
        FROM gl_ledgers gl
       WHERE gl.object_type_code = 'L'
         AND (gl.ledger_id IN
             (SELECT glsa.ledger_id
                 FROM gl_ledger_set_assignments glsa
                WHERE glsa.ledger_set_id = p_ledger_set_id));
  
  BEGIN
  
    fnd_file.put_line(fnd_file.log,
                      'starting program at: ' ||
                      to_char(SYSDATE, 'hh24:mi:ss'));
  
    FOR periods_to_change_csr IN csr_periods_to_change LOOP
    
      fnd_file.put_line(fnd_file.log,
                        'program in first for loop at: ' ||
                        to_char(SYSDATE, 'hh24:mi:ss') ||
                        ', for application id: ' ||
                        periods_to_change_csr.application_id ||
                        ', ledger id: ' || periods_to_change_csr.ledger_id ||
                        ', period name: ' ||
                        periods_to_change_csr.period_name);
    
      FOR ledger_ids_csr IN csr_ledger_ids(periods_to_change_csr.ledger_id,
                                           periods_to_change_csr.application_id) LOOP
      
        fnd_file.put_line(fnd_file.log,
                          'program in second for loop at: ' ||
                          to_char(SYSDATE, 'hh24:mi:ss') ||
                          ', ledger_id = ' || ledger_ids_csr.ledger_id ||
                          chr(10) ||
                          '---------------------------------------------------------');
      
        FOR acc_dates_to_change_csr IN csr_acc_dates_to_change(periods_to_change_csr.application_id,
                                                               ledger_ids_csr.ledger_id,
                                                               periods_to_change_csr.start_date,
                                                               periods_to_change_csr.end_date,
                                                               periods_to_change_csr.period_name) LOOP
        
          fnd_file.put_line(fnd_file.log,
                            'program in third for loop at: ' ||
                            to_char(SYSDATE, 'hh24:mi:ss') ||
                            ', accounting_date = ' ||
                            acc_dates_to_change_csr.accounting_date);
        
          --delete existing data
          DELETE xxxla_sla_expense_details xsed
           WHERE xsed.gl_date = acc_dates_to_change_csr.accounting_date
             AND xsed.application_id =
                 acc_dates_to_change_csr.application_id
             AND xsed.ledger_id = acc_dates_to_change_csr.ledger_id
                --following condition to not delete lines related to budget or enc from manaul GL
             AND xsed.test_total_count IS NOT NULL;
        
          COMMIT;
        
          fnd_file.put_line(fnd_file.log,
                            'deleted related records, program at: ' ||
                            to_char(SYSDATE, 'hh24:mi:ss'));
        
          --insert new data instead of the deleted data (for current application id, ledger id and accounting date)
          INSERT INTO xxxla_sla_expense_details
            (SELECT a.ledger_id,
                    a.code_combination_id,
                    a.period_name,
                    a.application_id,
                    a.gl_date,
                    a.trx_date,
                    a.balance_type_code,
                    a.budget_version_id,
                    a.encumbrance_type_id,
                    a.source_type,
                    a.trx_type,
                    a.description,
                    a.inv_dist_id,
                    a.po_dist_id,
                    a.req_dist_id,
                    a.inv_id,
                    a.po_id,
                    a.req_id,
                    a.vendor_id,
                    a.other_trx_id1,
                    a.other_trx_id2,
                    a.currency,
                    SUM(a.entered) sum_entered,
                    SUM(a.accounted) sum_accounted,
                    SYSDATE,
                    acc_dates_to_change_csr.count_records test_total_count,
                    NULL
               FROM (
                      --first union - ap invoice distributions
                      SELECT xl.ledger_id,
                              xl.code_combination_id,
                              xh.period_name,
                              xl.application_id,
                              xl.accounting_date gl_date,
                              ai.invoice_date trx_date,
                              xh.balance_type_code,
                              NULL budget_version_id,
                              xl.encumbrance_type_id,
                              xdl.source_distribution_type source_type,
                              ai.invoice_type_lookup_code trx_type,
                              xl.description,
                              aid.invoice_distribution_id inv_dist_id,
                              pd.po_distribution_id po_dist_id,
                              prd.distribution_id req_dist_id,
                              ai.invoice_id inv_id,
                              ph.po_header_id po_id,
                              prh.requisition_header_id req_id,
                              ai.vendor_id,
                              NULL other_trx_id1,
                              NULL other_trx_id2,
                              ai.invoice_currency_code currency,
                              nvl(xdl.unrounded_entered_dr, 0) -
                              nvl(xdl.unrounded_entered_cr, 0) entered,
                              nvl(xdl.unrounded_accounted_dr, 0) -
                              nvl(xdl.unrounded_accounted_cr, 0) accounted,
                              xl.last_update_date trx_last_upd_date
                        FROM xla_distribution_links       xdl,
                              xla_ae_lines                 xl,
                              gl_code_combinations         gcc,
                              xla_ae_headers               xh,
                              ap_invoices_all              ai,
                              ap_invoice_distributions_all aid,
                              po_distributions_all         pd,
                              po_headers_all               ph,
                              po_req_distributions_all     prd,
                              po_requisition_lines_all     prl,
                              po_requisition_headers_all   prh
                       WHERE xl.application_id = 200
                         AND xl.application_id = xh.application_id
                         AND xl.application_id = xdl.application_id
                         AND xl.ae_header_id = xh.ae_header_id
                         AND xdl.ae_header_id = xl.ae_header_id
                         AND xdl.ae_line_num = xl.ae_line_num
                         AND xl.code_combination_id = gcc.code_combination_id
                         AND xdl.source_distribution_id_num_1 =
                             aid.invoice_distribution_id
                         AND nvl(xdl.source_distribution_id_num_2, (-99)) = -99
                         AND xdl.source_distribution_type = 'AP_INV_DIST'
                         AND aid.invoice_id = ai.invoice_id
                         AND aid.po_distribution_id = pd.po_distribution_id(+)
                         AND pd.po_header_id = ph.po_header_id(+)
                         AND pd.req_distribution_id = prd.distribution_id(+)
                         AND prd.requisition_line_id =
                             prl.requisition_line_id(+)
                         AND prl.requisition_header_id =
                             prh.requisition_header_id(+)
                         AND xh.accounting_entry_status_code = 'F'
                            --the below condition is due to a bug.
                            --in this case in the line the amount is 0 while in the dist is not.
                            --anyway, the funds already were passed in this case so it should be 0.
                            --note: in the reporting book there wasn't F01 code and the balances wasn't cleared
                            -- manual encumbrance journals were uploaded to fix the balance.
                         AND nvl(xl.funds_status_code, 'xx') != 'F01'
                            
                            /* --note: in the reporting book there is no F01 code so i use the event id
                            and xdl.event_id not in
                                (select xdl2.event_id
                                   from xla_distribution_links xdl2,
                                        xla_ae_lines           xl2
                                  where xdl2.application_id = xdl.application_id
                                    and xdl2.source_distribution_id_num_1 =
                                        aid.invoice_distribution_id
                                    and xdl2.source_distribution_type =
                                        'AP_INV_DIST'
                                    and nvl(xdl2.source_distribution_id_num_2,
                                            (-99)) = -99
                                    and xdl2.application_id = xl2.application_id
                                    and xdl2.ae_header_id = xl2.ae_header_id
                                    and xdl2.ae_line_num = xl2.ae_line_num
                                    and nvl(xl2.funds_status_code, 'xx') = 'F01') */
                         AND xl.accounting_date =
                             acc_dates_to_change_csr.accounting_date
                         AND xh.accounting_date =
                             acc_dates_to_change_csr.accounting_date
                         AND xh.ledger_id = xl.ledger_id
                         AND xl.ledger_id = acc_dates_to_change_csr.ledger_id
                         AND xl.application_id =
                             acc_dates_to_change_csr.application_id
                         AND (gcc.segment3 BETWEEN c_exp_account_from AND
                             c_exp_account_to OR
                             gcc.segment3 BETWEEN c_bud_account_from AND
                             c_bud_account_to OR
                             gcc.segment3 BETWEEN c_fa_clr_account_from AND
                             c_fa_clr_account_to OR
                             gcc.segment3 BETWEEN c_fa_account_from AND
                             c_fa_account_to OR
                             gcc.segment3 BETWEEN c_prep_exp_account_from AND
                             c_prep_exp_account_to)
                      --and log_union('sql first union at: ' || to_char(sysdate, 'hh24:mi:ss'))=1
                      
                      UNION ALL
                      --first union b - xla_manual ap invoices
                      SELECT xl.ledger_id,
                              xl.code_combination_id,
                              xh.period_name,
                              xl.application_id,
                              xl.accounting_date gl_date,
                              ai.invoice_date trx_date,
                              xh.balance_type_code,
                              NULL budget_version_id,
                              xl.encumbrance_type_id,
                              'AP- ' || xdl.source_distribution_type source_type,
                              ai.invoice_type_lookup_code trx_type,
                              xl.description,
                              NULL inv_dist_id,
                              NULL po_dist_id,
                              NULL req_dist_id,
                              ai.invoice_id inv_id,
                              NULL po_id,
                              NULL req_id,
                              ai.vendor_id,
                              NULL other_trx_id1,
                              NULL other_trx_id2,
                              ai.invoice_currency_code currency,
                              nvl(xdl.unrounded_entered_dr, 0) -
                              nvl(xdl.unrounded_entered_cr, 0) entered,
                              nvl(xdl.unrounded_accounted_dr, 0) -
                              nvl(xdl.unrounded_accounted_cr, 0) accounted,
                              xl.last_update_date trx_last_upd_date
                        FROM xla_distribution_links       xdl,
                              xla_ae_lines                 xl,
                              gl_code_combinations         gcc,
                              xla_ae_headers               xh,
                              xla_transaction_entities_upg xte,
                              ap_invoices_all              ai
                       WHERE xl.application_id = 200
                         AND xl.application_id = xh.application_id
                         AND xl.application_id = xdl.application_id
                         AND xl.ae_header_id = xh.ae_header_id
                         AND xdl.ae_header_id = xl.ae_header_id
                         AND xdl.ae_line_num = xl.ae_line_num
                         AND xl.code_combination_id = gcc.code_combination_id
                         AND xte.entity_id = xh.entity_id
                         AND xte.application_id = xh.application_id
                         AND xte.source_id_int_1 = ai.invoice_id
                         AND nvl(xdl.source_distribution_id_num_2, (-99)) = -99
                         AND xdl.source_distribution_type = 'XLA_MANUAL'
                         AND xh.accounting_entry_status_code = 'F'
                            
                         AND xl.accounting_date =
                             acc_dates_to_change_csr.accounting_date
                         AND xh.accounting_date =
                             acc_dates_to_change_csr.accounting_date
                         AND xh.ledger_id = xl.ledger_id
                         AND xl.ledger_id = acc_dates_to_change_csr.ledger_id
                         AND xl.application_id =
                             acc_dates_to_change_csr.application_id
                         AND (gcc.segment3 BETWEEN c_exp_account_from AND
                             c_exp_account_to OR
                             gcc.segment3 BETWEEN c_bud_account_from AND
                             c_bud_account_to OR
                             gcc.segment3 BETWEEN c_fa_clr_account_from AND
                             c_fa_clr_account_to OR
                             gcc.segment3 BETWEEN c_fa_account_from AND
                             c_fa_account_to OR
                             gcc.segment3 BETWEEN c_prep_exp_account_from AND
                             c_prep_exp_account_to)
                      --and log_union('sql first union b at: ' || to_char(sysdate, 'hh24:mi:ss'))=1
                      
                      UNION ALL
                      --second union - po distributions
                      SELECT xl.ledger_id,
                              xl.code_combination_id,
                              xh.period_name,
                              xl.application_id,
                              xl.accounting_date gl_date,
                              ph.creation_date trx_date,
                              xh.balance_type_code,
                              NULL budget_version_id,
                              xl.encumbrance_type_id,
                              xdl.source_distribution_type source_type,
                              nvl(ph.type_lookup_code,
                                  'Corrupted PO ' || xte.transaction_number) trx_type,
                              xl.description,
                              NULL inv_dist_id,
                              pd.po_distribution_id po_dist_id,
                              prd.distribution_id req_dist_id,
                              NULL inv_id,
                              nvl(ph.po_header_id, xte.source_id_int_1) po_id,
                              prh.requisition_header_id req_id,
                              ph.vendor_id,
                              NULL other_trx_id1,
                              NULL other_trx_id2,
                              nvl(ph.currency_code, xl.currency_code) currency,
                              nvl(xdl.unrounded_entered_dr, 0) -
                              nvl(xdl.unrounded_entered_cr, 0) entered,
                              nvl(xdl.unrounded_accounted_dr, 0) -
                              nvl(xdl.unrounded_accounted_cr, 0) accounted,
                              xl.last_update_date trx_last_upd_date
                        FROM xla_distribution_links       xdl,
                              xla_ae_lines                 xl,
                              gl_code_combinations         gcc,
                              xla_ae_headers               xh,
                              po_distributions_all         pd,
                              po_headers_all               ph,
                              po_req_distributions_all     prd,
                              po_requisition_lines_all     prl,
                              po_requisition_headers_all   prh,
                              xla_transaction_entities_upg xte
                       WHERE xl.application_id = 201
                         AND xl.application_id = xh.application_id
                         AND xl.application_id = xdl.application_id
                         AND xl.ae_header_id = xh.ae_header_id
                         AND xdl.ae_header_id = xl.ae_header_id
                         AND xdl.ae_line_num = xl.ae_line_num
                         AND xte.application_id = xh.application_id
                         AND xte.entity_id = xh.entity_id
                         AND xl.code_combination_id = gcc.code_combination_id
                         AND xdl.source_distribution_id_num_1 =
                             pd.po_distribution_id(+) --there are lines not match to dist id (it looks like a BUG)
                         AND nvl(xdl.source_distribution_id_num_2, (-99)) = -99
                         AND xdl.source_distribution_type =
                             'PO_DISTRIBUTIONS_ALL'
                         AND pd.po_header_id = ph.po_header_id(+)
                         AND pd.req_distribution_id = prd.distribution_id(+)
                         AND prd.requisition_line_id =
                             prl.requisition_line_id(+)
                         AND prl.requisition_header_id =
                             prh.requisition_header_id(+)
                         AND xh.accounting_entry_status_code = 'F'
                            --the below condition is due to a bug.
                            --in this case in the line the amount is 0 while in the dist is not.
                            --anyway, the funds already were passed in this case so it should be 0.
                            --note: in the reporting book there wasn't F01 code and the balances wasn't cleared
                            -- manual encumbrance journals were uploaded to fix the balance.
                         AND nvl(xl.funds_status_code, 'xx') != 'F01'
                         AND xl.accounting_date =
                             acc_dates_to_change_csr.accounting_date
                         AND xh.accounting_date =
                             acc_dates_to_change_csr.accounting_date
                         AND xh.ledger_id = xl.ledger_id
                         AND xl.ledger_id = acc_dates_to_change_csr.ledger_id
                         AND xl.application_id =
                             acc_dates_to_change_csr.application_id
                         AND (gcc.segment3 BETWEEN c_exp_account_from AND
                             c_exp_account_to OR
                             gcc.segment3 BETWEEN c_bud_account_from AND
                             c_bud_account_to OR
                             gcc.segment3 BETWEEN c_fa_clr_account_from AND
                             c_fa_clr_account_to OR
                             gcc.segment3 BETWEEN c_fa_account_from AND
                             c_fa_account_to OR
                             gcc.segment3 BETWEEN c_prep_exp_account_from AND
                             c_prep_exp_account_to)
                      --and log_union('sql second union at: ' || to_char(sysdate, 'hh24:mi:ss'))=1
                      UNION ALL
                      --third union - po req distributions
                      SELECT xl.ledger_id,
                              xl.code_combination_id,
                              xh.period_name,
                              xl.application_id,
                              xl.accounting_date gl_date,
                              prh.creation_date trx_date,
                              xh.balance_type_code,
                              NULL budget_version_id,
                              xl.encumbrance_type_id,
                              xdl.source_distribution_type source_type,
                              nvl(prh.type_lookup_code,
                                  'Corrupted REQ ' || xte.transaction_number) trx_type,
                              xl.description,
                              NULL inv_dist_id,
                              NULL po_dist_id,
                              prd.distribution_id req_dist_id,
                              NULL inv_id,
                              NULL po_id,
                              nvl(prh.requisition_header_id,
                                  xte.source_id_int_1) req_id,
                              prl.vendor_id,
                              NULL other_trx_id1,
                              NULL other_trx_id2,
                              nvl(nvl(prl.currency_code, xl.currency_code),
                                  gl_primary.currency_code) currency,
                              nvl(xdl.unrounded_entered_dr, 0) -
                              nvl(xdl.unrounded_entered_cr, 0) entered,
                              nvl(xdl.unrounded_accounted_dr, 0) -
                              nvl(xdl.unrounded_accounted_cr, 0) accounted,
                              xl.last_update_date trx_last_upd_date
                        FROM xla_distribution_links       xdl,
                              xla_ae_lines                 xl,
                              gl_code_combinations         gcc,
                              xla_ae_headers               xh,
                              po_req_distributions_all     prd,
                              po_requisition_lines_all     prl,
                              po_requisition_headers_all   prh,
                              gl_ledgers                   gl,
                              gl_ledgers                   gl_primary, --it is to retrieve primary's ledger currency for requisitions where no currency
                             xla_transaction_entities_upg xte
                      WHERE xl.application_id = 201
                        AND xl.application_id = xh.application_id
                        AND xl.application_id = xdl.application_id
                        AND xl.ae_header_id = xh.ae_header_id
                        AND xdl.ae_header_id = xl.ae_header_id
                        AND xdl.ae_line_num = xl.ae_line_num
                        AND xte.application_id = xh.application_id
                        AND xte.entity_id = xh.entity_id
                        AND xl.code_combination_id = gcc.code_combination_id
                        AND xdl.source_distribution_id_num_1 =
                            prd.distribution_id(+) --there are lines not match to dist id (it seems as a BUG)
                        AND nvl(xdl.source_distribution_id_num_2, (-99)) = -99
                        AND xdl.source_distribution_type =
                            'PO_REQ_DISTRIBUTIONS_ALL'
                        AND prd.requisition_line_id =
                            prl.requisition_line_id(+)
                        AND prl.requisition_header_id =
                            prh.requisition_header_id(+)
                        AND gl.ledger_id = xl.ledger_id
                        AND gl.configuration_id =
                            gl_primary.configuration_id(+)
                        AND gl_primary.ledger_category_code(+) = 'PRIMARY'
                        AND xh.accounting_entry_status_code = 'F'
                           --the below condition is due to a bug.
                           --in this case in the line the amount is 0 while in the dist is not.
                           --anyway, the funds already were passed in this case so it should be 0.
                           --note: in the reporting book there wasn't F01 code and the balances wasn't cleared
                           -- manual encumbrance journals were uploaded to fix the balance.
                        AND nvl(xl.funds_status_code, 'xx') != 'F01'
                        AND xl.accounting_date =
                            acc_dates_to_change_csr.accounting_date
                        AND xh.accounting_date =
                            acc_dates_to_change_csr.accounting_date
                        AND xh.ledger_id = xl.ledger_id
                        AND xl.ledger_id = acc_dates_to_change_csr.ledger_id
                        AND xl.application_id =
                            acc_dates_to_change_csr.application_id
                        AND (gcc.segment3 BETWEEN c_exp_account_from AND
                            c_exp_account_to OR
                            gcc.segment3 BETWEEN c_bud_account_from AND
                            c_bud_account_to OR
                            gcc.segment3 BETWEEN c_fa_clr_account_from AND
                            c_fa_clr_account_to OR
                            gcc.segment3 BETWEEN c_fa_account_from AND
                            c_fa_account_to OR
                            gcc.segment3 BETWEEN c_prep_exp_account_from AND
                            c_prep_exp_account_to)
                     --and log_union('sql third union at: ' || to_char(sysdate, 'hh24:mi:ss'))=1
                     UNION ALL
                     -- 4th union from cost mgmt (mtl transaction accounts)
                     SELECT xl.ledger_id,
                             xl.code_combination_id,
                             xh.period_name,
                             xl.application_id,
                             xl.accounting_date gl_date,
                             mmt.creation_date trx_date,
                             xh.balance_type_code,
                             NULL budget_version_id,
                             xl.encumbrance_type_id,
                             xdl.source_distribution_type source_type,
                             mtst.transaction_source_type_name trx_type,
                             mp.organization_code || ', ' || msi.description description,
                             NULL inv_dist_id,
                             NULL po_dist_id,
                             NULL req_dist_id,
                             NULL inv_id,
                             NULL po_id,
                             NULL req_id,
                             NULL vendor_id,
                             mmt.transaction_id other_trx_id1, --mmt_id
                             NULL other_trx_id2,
                             xl.currency_code currency,
                             nvl(xdl.unrounded_entered_dr, 0) -
                             nvl(xdl.unrounded_entered_cr, 0) entered,
                             nvl(xdl.unrounded_accounted_dr, 0) -
                             nvl(xdl.unrounded_accounted_cr, 0) accounted,
                             xl.last_update_date trx_last_upd_date
                       FROM xla_distribution_links       xdl,
                             xla_ae_lines                 xl,
                             gl_code_combinations         gcc,
                             xla_ae_headers               xh,
                             xla_transaction_entities_upg xte,
                             mtl_transaction_accounts     mta,
                             mtl_material_transactions    mmt,
                             mtl_system_items_b           msi,
                             mtl_parameters               mp,
                             mtl_txn_source_types         mtst
                      WHERE xl.application_id = 707
                        AND xl.application_id = xh.application_id
                        AND xl.application_id = xdl.application_id
                        AND xl.ae_header_id = xh.ae_header_id
                        AND xdl.ae_header_id = xl.ae_header_id
                        AND xdl.ae_line_num = xl.ae_line_num
                        AND xl.code_combination_id = gcc.code_combination_id
                        AND xte.entity_id = xh.entity_id
                        AND xte.application_id = xh.application_id
                        AND xte.source_id_int_1 = mta.transaction_id
                        AND xdl.source_distribution_id_num_1 =
                            mta.inv_sub_ledger_id
                        AND nvl(xdl.source_distribution_id_num_2, (-99)) = -99
                        AND xdl.source_distribution_type =
                            'MTL_TRANSACTION_ACCOUNTS'
                        AND mta.transaction_id = mmt.transaction_id
                        AND mta.inventory_item_id = msi.inventory_item_id
                        AND mta.organization_id = msi.organization_id
                        AND mta.organization_id = mp.organization_id
                        AND mta.transaction_source_type_id =
                            mtst.transaction_source_type_id
                        AND xh.accounting_entry_status_code = 'F'
                        AND xl.accounting_date =
                            acc_dates_to_change_csr.accounting_date
                        AND xh.accounting_date =
                            acc_dates_to_change_csr.accounting_date
                        AND xh.ledger_id = xl.ledger_id
                        AND xl.ledger_id = acc_dates_to_change_csr.ledger_id
                        AND xl.application_id =
                            acc_dates_to_change_csr.application_id
                        AND (gcc.segment3 BETWEEN c_exp_account_from AND
                            c_exp_account_to OR
                            gcc.segment3 BETWEEN c_bud_account_from AND
                            c_bud_account_to OR
                            gcc.segment3 BETWEEN c_fa_clr_account_from AND
                            c_fa_clr_account_to OR
                            gcc.segment3 BETWEEN c_fa_account_from AND
                            c_fa_account_to OR
                            gcc.segment3 BETWEEN c_prep_exp_account_from AND
                            c_prep_exp_account_to)
                     --and log_union('sql 4th union at: ' || to_char(sysdate, 'hh24:mi:ss'))=1
                     UNION ALL
                     -- 4th b union from cost mgmt (wip transaction accounts)
                     SELECT xl.ledger_id,
                             xl.code_combination_id,
                             xh.period_name,
                             xl.application_id,
                             xl.accounting_date gl_date,
                             wt.creation_date trx_date,
                             xh.balance_type_code,
                             NULL budget_version_id,
                             xl.encumbrance_type_id,
                             xdl.source_distribution_type source_type,
                             'job name: ' || we.wip_entity_name || ', ' ||
                             we.description trx_type,
                             mp.organization_code || ', ' || msi.description description,
                             NULL inv_dist_id,
                             NULL po_dist_id,
                             NULL req_dist_id,
                             NULL inv_id,
                             NULL po_id,
                             NULL req_id,
                             NULL vendor_id,
                             wt.transaction_id other_trx_id1, --wt_id
                             NULL other_trx_id2,
                             xl.currency_code currency,
                             nvl(xdl.unrounded_entered_dr, 0) -
                             nvl(xdl.unrounded_entered_cr, 0) entered,
                             nvl(xdl.unrounded_accounted_dr, 0) -
                             nvl(xdl.unrounded_accounted_cr, 0) accounted,
                             xl.last_update_date trx_last_upd_date
                       FROM xla_distribution_links       xdl,
                             xla_ae_lines                 xl,
                             gl_code_combinations         gcc,
                             xla_ae_headers               xh,
                             xla_transaction_entities_upg xte,
                             wip_transaction_accounts     wta,
                             wip_transactions             wt,
                             mtl_system_items_b           msi,
                             mtl_parameters               mp,
                             wip_entities                 we
                      WHERE xl.application_id = 707
                        AND xl.application_id = xh.application_id
                        AND xl.application_id = xdl.application_id
                        AND xl.ae_header_id = xh.ae_header_id
                        AND xdl.ae_header_id = xl.ae_header_id
                        AND xdl.ae_line_num = xl.ae_line_num
                        AND xl.code_combination_id = gcc.code_combination_id
                        AND xte.entity_id = xh.entity_id
                        AND xte.application_id = xh.application_id
                        AND xte.source_id_int_1 = wta.transaction_id
                        AND xdl.source_distribution_id_num_1 =
                            wta.wip_sub_ledger_id
                        AND nvl(xdl.source_distribution_id_num_2, (-99)) = -99
                        AND xdl.source_distribution_type =
                            'WIP_TRANSACTION_ACCOUNTS'
                        AND wta.transaction_id = wt.transaction_id
                        AND wt.primary_item_id = msi.inventory_item_id(+)
                        AND wt.organization_id = msi.organization_id(+)
                        AND wta.organization_id = mp.organization_id
                        AND wta.wip_entity_id = we.wip_entity_id
                        AND xh.accounting_entry_status_code = 'F'
                        AND xl.accounting_date =
                            acc_dates_to_change_csr.accounting_date
                        AND xh.accounting_date =
                            acc_dates_to_change_csr.accounting_date
                        AND xh.ledger_id = xl.ledger_id
                        AND xl.ledger_id = acc_dates_to_change_csr.ledger_id
                        AND xl.application_id =
                            acc_dates_to_change_csr.application_id
                        AND (gcc.segment3 BETWEEN c_exp_account_from AND
                            c_exp_account_to OR
                            gcc.segment3 BETWEEN c_bud_account_from AND
                            c_bud_account_to OR
                            gcc.segment3 BETWEEN c_fa_clr_account_from AND
                            c_fa_clr_account_to OR
                            gcc.segment3 BETWEEN c_fa_account_from AND
                            c_fa_account_to OR
                            gcc.segment3 BETWEEN c_prep_exp_account_from AND
                            c_prep_exp_account_to)
                     --  CHG0048772 XLA not including Cost Management write-off  Entries
                     UNION ALL
                     -- 4th c union from cost mgmt (not mtl transaction accounts, WIP_TRANSACTION_ACCOUNTS)
                     SELECT xl.ledger_id,
                             xl.code_combination_id,
                             xh.period_name,
                             xl.application_id,
                             xl.accounting_date gl_date,
                             NULL trx_date,
                             xh.balance_type_code,
                             NULL budget_version_id,
                             xl.encumbrance_type_id,
                             xdl.source_distribution_type source_type,
                             'Write Off ' ||
                             to_char(xdl.source_distribution_id_num_1) trx_type,
                             nvl(xl.description, pll.item_description) description,
                             NULL inv_dist_id,
                             pda.po_distribution_id po_dist_id,
                             NULL req_dist_id,
                             NULL inv_id,
                             ph.po_header_id po_id,
                             NULL req_id,
                             ph.vendor_id vendor_id,
                             xte.source_id_int_1 other_trx_id1,
                             NULL other_trx_id2,
                             xl.currency_code currency,
                             nvl(xdl.unrounded_entered_dr, 0) -
                             nvl(xdl.unrounded_entered_cr, 0) entered,
                             nvl(xdl.unrounded_accounted_dr, 0) -
                             nvl(xdl.unrounded_accounted_cr, 0) accounted,
                             xl.last_update_date trx_last_upd_date
                       FROM xla_distribution_links       xdl,
                             xla_ae_lines                 xl,
                             gl_code_combinations         gcc,
                             xla_ae_headers               xh,
                             xla_transaction_entities_upg xte,
                             cst_write_offs               cw,
                             po_distributions_all         pda,
                             po_lines_all                 pll,
                             po_headers_all               ph
                      WHERE xl.application_id = 707
                        AND xl.application_id = xh.application_id
                        AND xl.application_id = xdl.application_id
                        AND xl.ae_header_id = xh.ae_header_id
                        AND xdl.ae_header_id = xl.ae_header_id
                        AND xdl.ae_line_num = xl.ae_line_num
                        AND xte.application_id = xh.application_id
                        AND xte.entity_id = xh.entity_id
                        AND xl.code_combination_id = gcc.code_combination_id
                        AND xdl.source_distribution_type = 'CST_WRITE_OFFS'
                        AND xh.accounting_entry_status_code = 'F'
                        AND xl.accounting_date =
                            acc_dates_to_change_csr.accounting_date
                        AND xh.accounting_date =
                            acc_dates_to_change_csr.accounting_date
                        AND xh.ledger_id = xl.ledger_id
                        AND xl.ledger_id = acc_dates_to_change_csr.ledger_id
                        AND xl.application_id =
                            acc_dates_to_change_csr.application_id
                        AND (gcc.segment3 BETWEEN c_exp_account_from AND
                            c_exp_account_to OR
                            gcc.segment3 BETWEEN c_bud_account_from AND
                            c_bud_account_to OR
                            gcc.segment3 BETWEEN c_fa_clr_account_from AND
                            c_fa_clr_account_to OR
                            gcc.segment3 BETWEEN c_fa_account_from AND
                            c_fa_account_to OR
                            gcc.segment3 BETWEEN c_prep_exp_account_from AND
                            c_prep_exp_account_to)
                        and pda.po_distribution_id = cw.po_distribution_id
                        and ph.po_header_id = pda.po_header_id
                        and pll.po_line_id = pda.po_line_id
                        and cw.write_off_id =
                            xdl.source_distribution_id_num_1
                     -- end CHG0048772
                     UNION ALL
                     -- 5th c union from cost mgmt (not mtl transaction accounts, WIP_TRANSACTION_ACCOUNTS)
                     SELECT xl.ledger_id,
                             xl.code_combination_id,
                             xh.period_name,
                             xl.application_id,
                             xl.accounting_date gl_date,
                             NULL trx_date,
                             xh.balance_type_code,
                             NULL budget_version_id,
                             xl.encumbrance_type_id,
                             xdl.source_distribution_type source_type,
                             to_char(xdl.source_distribution_id_num_1) trx_type,
                             nvl(xl.description, po.item_description) description,
                             NULL inv_dist_id,
                             po.po_distribution_id po_dist_id,
                             NULL req_dist_id,
                             NULL inv_id,
                             po.po_header_id po_id,
                             NULL req_id,
                             po.vendor_id vendor_id,
                             xte.source_id_int_1 other_trx_id1,
                             NULL other_trx_id2,
                             xl.currency_code currency,
                             nvl(xdl.unrounded_entered_dr, 0) -
                             nvl(xdl.unrounded_entered_cr, 0) entered,
                             nvl(xdl.unrounded_accounted_dr, 0) -
                             nvl(xdl.unrounded_accounted_cr, 0) accounted,
                             xl.last_update_date trx_last_upd_date
                       FROM xla_distribution_links       xdl,
                             xla_ae_lines                 xl,
                             gl_code_combinations         gcc,
                             xla_ae_headers               xh,
                             xla_transaction_entities_upg xte,
                             --  CHG0033589  28-Oct-2014   Ofer Suad Add vendor details
                             (SELECT ph.vendor_id,
                                     ph.po_header_id,
                                     pll.item_description,
                                     pda.po_distribution_id
                                FROM po_headers_all       ph,
                                     po_lines_all         pll,
                                     po_distributions_all pda
                               WHERE pll.po_header_id = ph.po_header_id
                                 AND pda.po_line_id = pll.po_line_id) po
                      WHERE xl.application_id = 707
                        AND xl.application_id = xh.application_id
                        AND xl.application_id = xdl.application_id
                        AND xl.ae_header_id = xh.ae_header_id
                        AND xdl.ae_header_id = xl.ae_header_id
                        AND xdl.ae_line_num = xl.ae_line_num
                        AND xte.application_id = xh.application_id
                        AND xte.entity_id = xh.entity_id
                        AND xl.code_combination_id = gcc.code_combination_id
                        AND xdl.source_distribution_type NOT IN
                            ('MTL_TRANSACTION_ACCOUNTS',
                             'WIP_TRANSACTION_ACCOUNTS')
                        AND xh.accounting_entry_status_code = 'F'
                        AND xl.accounting_date =
                            acc_dates_to_change_csr.accounting_date
                        AND xh.accounting_date =
                            acc_dates_to_change_csr.accounting_date
                        AND xh.ledger_id = xl.ledger_id
                        AND xl.ledger_id = acc_dates_to_change_csr.ledger_id
                        AND xl.application_id =
                            acc_dates_to_change_csr.application_id
                        AND (gcc.segment3 BETWEEN c_exp_account_from AND
                            c_exp_account_to OR
                            gcc.segment3 BETWEEN c_bud_account_from AND
                            c_bud_account_to OR
                            gcc.segment3 BETWEEN c_fa_clr_account_from AND
                            c_fa_clr_account_to OR
                            gcc.segment3 BETWEEN c_fa_account_from AND
                            c_fa_account_to OR
                            gcc.segment3 BETWEEN c_prep_exp_account_from AND
                            c_prep_exp_account_to)
                        AND po.po_header_id = xdl.applied_to_source_id_num_1
                        AND po.po_distribution_id =
                            xdl.applied_to_dist_id_num_1
                     --and log_union('sql 4th c union at: ' || to_char(sysdate, 'hh24:mi:ss'))=1
                     UNION ALL
                     --5th union - fa depreciation
                     SELECT xl.ledger_id,
                             xl.code_combination_id,
                             xh.period_name,
                             xl.application_id,
                             xl.accounting_date gl_date,
                             fa_b.creation_date trx_date,
                             xh.balance_type_code,
                             NULL budget_version_id,
                             xl.encumbrance_type_id,
                             'FA- ' || xte.entity_code source_type,
                             xh.event_type_code || '- ' ||
                             fa_b.attribute_category_code trx_type,
                             'asset: ' || fa_b.asset_number || ', ' ||
                             fa_tl.description description,
                             NULL inv_dist_id,
                             NULL po_dist_id,
                             NULL req_dist_id,
                             fai2.inv_id,
                             fai2.po_id,
                             fai2.req_id,
                             fai2.vendor_id,
                             fa_b.asset_id other_trx_id1, --fa_asset_id
                             NULL other_trx_id2,
                             xl.currency_code currency,
                             nvl(xl.unrounded_entered_dr, 0) -
                             nvl(xl.unrounded_entered_cr, 0) entered,
                             nvl(xl.unrounded_accounted_dr, 0) -
                             nvl(xl.unrounded_accounted_cr, 0) accounted,
                             xl.last_update_date trx_last_upd_date
                       FROM xla_ae_lines             xl,
                             gl_code_combinations     gcc,
                             xla_ae_headers           xh,
                             xla_transaction_entities xte,
                             fa_additions_b           fa_b,
                             fa_additions_tl          fa_tl,
                             --assumption - mostly there is one to one relation between asset-invoice-po-req
                             --but, because it doesn't have to be like that, i grouped the following by asset id
                              --and take only 1 of the values.
                              --thus, mostly, the data will be sufficient
                              (SELECT fai.asset_id,
                                      MIN(fai.invoice_id) inv_id,
                                      MIN(fai.po_vendor_id) vendor_id,
                                      MIN(ph.po_header_id) po_id,
                                      MIN(prh.requisition_header_id) req_id
                                 FROM fa_asset_invoices            fai,
                                      ap_invoice_distributions_all aid,
                                      po_distributions_all         pd,
                                      po_req_distributions_all     prd,
                                      po_headers_all               ph,
                                      po_requisition_lines_all     prl,
                                      po_requisition_headers_all   prh
                                WHERE fai.date_ineffective IS NULL
                                  AND fai.invoice_id = aid.invoice_id --can't use the dist id from fai because it doesn't always exist
                                  AND aid.po_distribution_id =
                                      pd.po_distribution_id(+)
                                  AND pd.req_distribution_id =
                                      prd.distribution_id(+)
                                  AND pd.po_header_id = ph.po_header_id(+)
                                  AND prd.requisition_line_id =
                                      prl.requisition_line_id(+)
                                  AND prl.requisition_header_id =
                                      prh.requisition_header_id(+)
                                GROUP BY fai.asset_id) fai2
                       WHERE xl.application_id = 140
                         AND xl.application_id = xh.application_id
                         AND xl.ae_header_id = xh.ae_header_id
                         AND xl.code_combination_id = gcc.code_combination_id
                         AND xte.application_id = xh.application_id
                         AND xte.entity_id = xh.entity_id
                         AND xte.source_id_int_1 = fa_b.asset_id
                         AND xte.entity_code = 'DEPRECIATION'
                         AND fa_b.asset_id = fa_tl.asset_id
                         AND fa_tl.language = 'US'
                         AND fa_b.asset_id = fai2.asset_id(+)
                         AND xh.accounting_entry_status_code = 'F'
                         AND xh.gl_transfer_status_code = 'Y'
                         AND xl.accounting_date =
                             acc_dates_to_change_csr.accounting_date
                         AND xh.accounting_date =
                             acc_dates_to_change_csr.accounting_date
                         AND xh.ledger_id = xl.ledger_id
                         AND xl.ledger_id = acc_dates_to_change_csr.ledger_id
                         AND xl.application_id =
                             acc_dates_to_change_csr.application_id
                      --and log_union('sql 5th union at: ' || to_char(sysdate, 'hh24:mi:ss'))=1
                      UNION ALL
                      --5th b union - fa transactions
                      SELECT xl.ledger_id,
                              xl.code_combination_id,
                              xh.period_name,
                              xl.application_id,
                              xl.accounting_date gl_date,
                              fth.transaction_date_entered trx_date,
                              xh.balance_type_code,
                              NULL budget_version_id,
                              xl.encumbrance_type_id,
                              'FA- ' || xte.entity_code source_type,
                              xh.event_type_code || '- ' ||
                              fa_b.attribute_category_code trx_type,
                              'asset: ' || fa_b.asset_number || ', ' ||
                              fa_tl.description description,
                              NULL inv_dist_id,
                              NULL po_dist_id,
                              NULL req_dist_id,
                              fai2.inv_id,
                              fai2.po_id,
                              fai2.req_id,
                              fai2.vendor_id,
                              fa_b.asset_id other_trx_id1, --fa_asset_id
                              NULL other_trx_id2,
                              xl.currency_code currency,
                              nvl(xl.unrounded_entered_dr, 0) -
                              nvl(xl.unrounded_entered_cr, 0) entered,
                              nvl(xl.unrounded_accounted_dr, 0) -
                              nvl(xl.unrounded_accounted_cr, 0) accounted,
                              xl.last_update_date trx_last_upd_date
                        FROM xla_ae_lines             xl,
                              gl_code_combinations     gcc,
                              xla_ae_headers           xh,
                              xla_transaction_entities xte,
                              fa_additions_b           fa_b,
                              fa_additions_tl          fa_tl,
                              fa_transaction_headers   fth,
                              --assumption - mostly there is one to one relation between asset-invoice-po-req
                              --but, because it doesn't have to be like that, i grouped the following by asset id
                             --and take only 1 of the values.
                             --thus, mostly, the data will be sufficient
                             (SELECT fai.asset_id,
                                     MIN(fai.invoice_id) inv_id,
                                     MIN(fai.po_vendor_id) vendor_id,
                                     MIN(ph.po_header_id) po_id,
                                     MIN(prh.requisition_header_id) req_id
                                FROM fa_asset_invoices            fai,
                                     ap_invoice_distributions_all aid,
                                     po_distributions_all         pd,
                                     po_req_distributions_all     prd,
                                     po_headers_all               ph,
                                     po_requisition_lines_all     prl,
                                     po_requisition_headers_all   prh
                               WHERE fai.date_ineffective IS NULL
                                 AND fai.invoice_id = aid.invoice_id --can't use the dist id from fai because it doesn't always exist
                                 AND aid.po_distribution_id =
                                     pd.po_distribution_id(+)
                                 AND pd.req_distribution_id =
                                     prd.distribution_id(+)
                                 AND pd.po_header_id = ph.po_header_id(+)
                                 AND prd.requisition_line_id =
                                     prl.requisition_line_id(+)
                                 AND prl.requisition_header_id =
                                     prh.requisition_header_id(+)
                               GROUP BY fai.asset_id) fai2
                      WHERE xl.application_id = 140
                        AND xl.application_id = xh.application_id
                        AND xl.ae_header_id = xh.ae_header_id
                        AND xl.code_combination_id = gcc.code_combination_id
                        AND xte.application_id = xh.application_id
                        AND xte.entity_id = xh.entity_id
                        AND xte.source_id_int_1 = fth.transaction_header_id
                        AND xte.entity_code = 'TRANSACTIONS'
                        AND fth.asset_id = fa_b.asset_id
                        AND fa_b.asset_id = fa_tl.asset_id
                        AND fa_tl.language = 'US'
                        AND fa_b.asset_id = fai2.asset_id(+)
                        AND xh.accounting_entry_status_code = 'F'
                        AND xh.gl_transfer_status_code = 'Y'
                        AND xl.accounting_date =
                            acc_dates_to_change_csr.accounting_date
                        AND xh.accounting_date =
                            acc_dates_to_change_csr.accounting_date
                        AND xh.ledger_id = xl.ledger_id
                        AND xl.ledger_id = acc_dates_to_change_csr.ledger_id
                        AND xl.application_id =
                            acc_dates_to_change_csr.application_id
                     --and log_union('sql 5th union at: ' || to_char(sysdate, 'hh24:mi:ss'))=1
                     UNION ALL
                     --6th union from GL for balances from Sources not from XLA
                     --it is not relevant for GL Manual Budtet & Encumbrance transactions.
                     --these transactions will be updated by checking header id and ledger later on the program.
                     SELECT jl.ledger_id,
                             jl.code_combination_id,
                             jh.period_name,
                             101 application_id,
                             jl.effective_date gl_date,
                             jh.creation_date trx_date,
                             jh.actual_flag balance_type_code,
                             jh.budget_version_id budget_version_id,
                             jh.encumbrance_type_id,
                             'GL- ' || jh.je_source source_type,
                             jh.je_category trx_type,
                             jl.description description,
                             NULL inv_dist_id,
                             NULL po_dist_id,
                             NULL req_dist_id,
                             NULL inv_id,
                             NULL po_id,
                             NULL req_id,
                             --  21-12-2011 Ofer Suad - add vendor id in case of Accrual JE line
                             decode(jh.je_category,
                                    'Accrual',
                                    to_number(jl.attribute1),
                                    NULL) vendor_id,
                             jl.je_header_id other_trx_id1, --je_header_id
                             jl.je_line_num other_trx_id2, --je_line_number
                             jh.currency_code currency,
                             (nvl(jl.entered_dr, 0) - nvl(jl.entered_cr, 0)) entered,
                             (nvl(jl.accounted_dr, 0) -
                             nvl(jl.accounted_cr, 0)) accounted,
                             jl.last_update_date trx_last_upd_date
                       FROM gl_je_headers        jh,
                             gl_je_lines          jl,
                             gl_code_combinations gcc
                      WHERE jh.je_header_id = jl.je_header_id
                        AND jl.code_combination_id = gcc.code_combination_id
                        AND (nvl(jh.je_from_sla_flag, 'N') = 'N' OR
                            jh.je_source = 'Receivables')
                        AND jh.status = 'P'
                        AND jh.actual_flag = 'A' --relevant only for actual transactions
                        AND jl.effective_date =
                            acc_dates_to_change_csr.accounting_date
                        AND jl.period_name =
                            periods_to_change_csr.period_name --for index
                        AND jl.period_name = jh.period_name
                        AND jl.ledger_id = acc_dates_to_change_csr.ledger_id
                        AND 101 = acc_dates_to_change_csr.application_id
                        AND (gcc.segment3 BETWEEN c_exp_account_from AND
                            c_exp_account_to OR
                            gcc.segment3 BETWEEN c_bud_account_from AND
                            c_bud_account_to OR
                            gcc.segment3 BETWEEN c_fa_clr_account_from AND
                            c_fa_clr_account_to OR
                            gcc.segment3 BETWEEN c_fa_account_from AND
                            c_fa_account_to OR
                            gcc.segment3 BETWEEN c_prep_exp_account_from AND
                            c_prep_exp_account_to)
                     --and log_union('sql 6th union at: ' || to_char(sysdate, 'hh24:mi:ss'))=1
                     UNION ALL
                     --  CHG0033589  28-Oct-2014   Ofer Suad Add Projets module
                     SELECT xl.ledger_id,
                             xl.code_combination_id,
                             xh.period_name,
                             xl.application_id,
                             xl.accounting_date gl_date,
                             pei.expenditure_item_date trx_date,
                             xh.balance_type_code,
                             NULL budget_version_id,
                             xl.encumbrance_type_id,
                             'Projects' source_type,
                             pei.expenditure_type trx_type,
                             pei.expenditure_comment description,
                             NULL inv_dist_id,
                             NULL po_dist_id,
                             NULL req_dist_id,
                             NULL inv_id,
                             NULL po_id,
                             NULL req_id,
                             pei.vendor_id,
                             pei.expenditure_id other_trx_id1,
                             pei.expenditure_item_id other_trx_id2,
                             pei.project_currency_code currency,
                             nvl(xdl.unrounded_entered_dr, 0) -
                             nvl(xdl.unrounded_entered_cr, 0) entered,
                             nvl(xdl.unrounded_accounted_dr, 0) -
                             nvl(xdl.unrounded_accounted_cr, 0) accounted,
                             xl.last_update_date trx_last_upd_date
                       FROM xla_distribution_links    xdl,
                             xla_ae_lines              xl,
                             gl_code_combinations      gcc,
                             xla_ae_headers            xh,
                             pa_expend_items_adjust2_v pei
                      WHERE xl.application_id = 275
                        AND xl.application_id = xh.application_id
                        AND xl.application_id = xdl.application_id
                        AND xl.ae_header_id = xh.ae_header_id
                        AND xdl.ae_header_id = xl.ae_header_id
                        AND xdl.ae_line_num = xl.ae_line_num
                        AND xl.code_combination_id = gcc.code_combination_id
                        AND xh.accounting_entry_status_code = 'F'
                        AND xdl.source_distribution_id_num_1 =
                            pei.expenditure_item_id
                           --the below condition is due to a bug.
                           --in this case in the line the amount is 0 while in the dist is not.
                           --anyway, the funds already were passed in this case so it should be 0.
                           --note: in the reporting book there wasn't F01 code and the balances wasn't cleared
                           -- manual encumbrance journals were uploaded to fix the balance.
                        AND nvl(xl.funds_status_code, 'xx') != 'F01'
                           
                        AND xl.accounting_date =
                            acc_dates_to_change_csr.accounting_date
                        AND xh.accounting_date =
                            acc_dates_to_change_csr.accounting_date
                        AND xh.ledger_id = xl.ledger_id
                        AND xl.ledger_id = acc_dates_to_change_csr.ledger_id
                        AND xl.application_id =
                            acc_dates_to_change_csr.application_id
                        AND (gcc.segment3 BETWEEN c_exp_account_from AND
                            c_exp_account_to OR
                            gcc.segment3 BETWEEN c_bud_account_from AND
                            c_bud_account_to OR
                            gcc.segment3 BETWEEN c_fa_clr_account_from AND
                            c_fa_clr_account_to OR
                            gcc.segment3 BETWEEN c_fa_account_from AND
                            c_fa_account_to OR
                            gcc.segment3 BETWEEN c_prep_exp_account_from AND
                            c_prep_exp_account_to)) a
              WHERE abs(a.entered) + abs(a.accounted) != 0
             --and log_union('sql union where at: ' || to_char(sysdate, 'hh24:mi:ss'))=1
              GROUP BY a.ledger_id,
                       a.code_combination_id,
                       a.period_name,
                       a.application_id,
                       a.gl_date,
                       a.trx_date,
                       a.balance_type_code,
                       a.budget_version_id,
                       a.encumbrance_type_id,
                       a.source_type,
                       a.trx_type,
                       a.description,
                       a.inv_dist_id,
                       a.po_dist_id,
                       a.req_dist_id,
                       a.inv_id,
                       a.po_id,
                       a.req_id,
                       a.vendor_id,
                       a.other_trx_id1,
                       a.other_trx_id2,
                       a.currency);
        
          COMMIT;
        
          fnd_file.put_line(fnd_file.log,
                            'inserted related records, program at: ' ||
                            to_char(SYSDATE, 'hh24:mi:ss'));
        
        END LOOP;
      END LOOP;
    
      --insert records in xpslud table
      --or just update in case record exists for application id, ledger id and period name.
      --don't update for Open or Future statuses.
      BEGIN
      
        SELECT closing_status
          INTO l_closing_status_period
          FROM (SELECT gps.closing_status
                  FROM xx_periods_status_lst_upd_date xpslud,
                       gl_period_statuses             gps
                 WHERE gps.application_id =
                      --for INV or FA look for GL status period
                       decode(xpslud.application_id,
                              707,
                              101,
                              140,
                              101,
                              xpslud.application_id)
                   AND xpslud.ledger_id = gps.ledger_id
                   AND xpslud.period_name = gps.period_name
                   AND xpslud.application_id =
                       periods_to_change_csr.application_id
                   AND xpslud.ledger_id = periods_to_change_csr.ledger_id
                   AND xpslud.period_name =
                       periods_to_change_csr.period_name
                UNION ALL
                --  CHG0033589  28-Oct-2014   Ofer Suad Add Projets module
                SELECT pv.status
                  FROM pa_periods_v pv
                 WHERE pv.set_of_books_id = periods_to_change_csr.ledger_id
                   AND pv.period_name = periods_to_change_csr.period_name
                   AND periods_to_change_csr.application_id = 275);
      
        --record exists then only update last update date (not for open or future statuses)
        IF l_closing_status_period NOT IN ('O', 'F') THEN
          UPDATE xx_periods_status_lst_upd_date xpslud
             SET xpslud.test_period_last_upd_date = periods_to_change_csr.last_update_date
           WHERE xpslud.application_id =
                 periods_to_change_csr.application_id
             AND xpslud.ledger_id = periods_to_change_csr.ledger_id
             AND xpslud.period_name = periods_to_change_csr.period_name;
        
          COMMIT;
          fnd_file.put_line(fnd_file.log,
                            'xpslud table was updated with last update date = ' ||
                            periods_to_change_csr.last_update_date);
        END IF;
      
      EXCEPTION
        WHEN OTHERS THEN
          --record doesn't exist then insert new record...
        
          --retrieve the current last update date
          SELECT last_update_date
            INTO l_period_last_upd_date
            FROM (SELECT gps.last_update_date
                  
                    FROM gl_period_statuses gps
                   WHERE gps.application_id =
                        --for INV or FA look for GL status period
                         decode(periods_to_change_csr.application_id,
                                707,
                                101,
                                140,
                                101,
                                periods_to_change_csr.application_id)
                     AND gps.ledger_id = periods_to_change_csr.ledger_id
                     AND gps.period_name = periods_to_change_csr.period_name
                  UNION ALL
                  --  CHG0033589  28-Oct-2014   Ofer Suad Add Projets module
                  SELECT pv.last_update_date
                    FROM pa_periods_v pv
                   WHERE pv.set_of_books_id =
                         periods_to_change_csr.ledger_id
                     AND pv.period_name = periods_to_change_csr.period_name
                     AND periods_to_change_csr.application_id = 275);
          --insert record
          INSERT INTO xx_periods_status_lst_upd_date xpslud
          VALUES
            (periods_to_change_csr.application_id,
             periods_to_change_csr.ledger_id,
             periods_to_change_csr.period_name,
             SYSDATE,
             l_period_last_upd_date);
        
          COMMIT;
          fnd_file.put_line(fnd_file.log,
                            'new line was inserted to xpslud table with last update date = ' ||
                            periods_to_change_csr.last_update_date);
        
      END;
    
    END LOOP;
  
    --test and insert GL Manual Budget & Encumbrance transactions according to header id and ledger.
    --min header id for not posted Bud & Enc transactions is saved in xsed table for reference
    --on next run (field TEST_TRX_LAST_ID). in case all trx are posted then it saves
    --the max header id.
    FOR ledger_ids_enc_bud_csr IN csr_ledger_ids_enc_bud LOOP
    
      --max saved header id for current ledger in xsed table
      SELECT nvl(MAX(xsed.test_trx_last_id), 1)
        INTO l_max_header_id_saved
        FROM xxxla_sla_expense_details xsed
       WHERE xsed.ledger_id = ledger_ids_enc_bud_csr.ledger_id
         AND xsed.application_id = 101
         AND xsed.balance_type_code != 'A';
    
      --max header id for current ledger in GL
      SELECT nvl(MAX(jh.je_header_id), 1)
        INTO l_max_header_id
        FROM gl_je_headers jh
       WHERE jh.actual_flag != 'A'
         AND nvl(jh.je_from_sla_flag, 'N') = 'N'
         AND jh.ledger_id = ledger_ids_enc_bud_csr.ledger_id
         AND jh.je_header_id >= l_max_header_id_saved;
    
      --min header id for current ledger in GL for non posted trx
      SELECT MIN(jh.je_header_id)
        INTO l_min_header_id_not_posted --can be null
        FROM gl_je_headers jh
       WHERE jh.actual_flag != 'A'
         AND nvl(jh.je_from_sla_flag, 'N') = 'N'
         AND jh.ledger_id = ledger_ids_enc_bud_csr.ledger_id
         AND jh.status != 'P'
         AND jh.je_header_id >= l_max_header_id_saved;
    
      --header id to save
      l_max_header_id_to_save := nvl(l_min_header_id_not_posted - 1, -- -1 to catch unposted trx on next run
                                     l_max_header_id);
    
      --check whether update might be needed for current ledger
      IF l_max_header_id != l_max_header_id_saved THEN
      
        --insert relevant BUD & ENC lines for current ledger
        INSERT INTO xxxla_sla_expense_details
          (SELECT a.ledger_id,
                  a.code_combination_id,
                  a.period_name,
                  a.application_id,
                  a.gl_date,
                  a.trx_date,
                  a.balance_type_code,
                  a.budget_version_id,
                  a.encumbrance_type_id,
                  a.source_type,
                  a.trx_type,
                  a.description,
                  a.inv_dist_id,
                  a.po_dist_id,
                  a.req_dist_id,
                  a.inv_id,
                  a.po_id,
                  a.req_id,
                  a.vendor_id,
                  a.other_trx_id1,
                  a.other_trx_id2,
                  a.currency,
                  SUM(a.entered) sum_entered,
                  SUM(a.accounted) sum_accounted,
                  SYSDATE,
                  NULL, --this field for test_total_count must be null to not influence on csr_acc_dates_to_change
                  l_max_header_id_to_save
             FROM (SELECT jl.ledger_id,
                          jl.code_combination_id,
                          jh.period_name,
                          101 application_id,
                          jl.effective_date gl_date,
                          jh.creation_date trx_date,
                          jh.actual_flag balance_type_code,
                          jh.budget_version_id budget_version_id,
                          jh.encumbrance_type_id,
                          'GL- ' || jh.je_source source_type,
                          jh.je_category trx_type,
                          jl.description description,
                          NULL inv_dist_id,
                          NULL po_dist_id,
                          NULL req_dist_id,
                          NULL inv_id,
                          NULL po_id,
                          NULL req_id,
                          NULL vendor_id,
                          jl.je_header_id other_trx_id1, --je_header_id
                          jl.je_line_num other_trx_id2, --je_line_number
                          jh.currency_code currency,
                          (nvl(jl.entered_dr, 0) - nvl(jl.entered_cr, 0)) entered,
                          (nvl(jl.accounted_dr, 0) - nvl(jl.accounted_cr, 0)) accounted,
                          jl.last_update_date trx_last_upd_date
                     FROM gl_je_headers        jh,
                          gl_je_lines          jl,
                          gl_code_combinations gcc
                    WHERE jh.je_header_id = jl.je_header_id
                      AND jl.code_combination_id = gcc.code_combination_id
                      AND nvl(jh.je_from_sla_flag, 'N') = 'N'
                      AND jh.status = 'P'
                      AND jh.actual_flag != 'A' --for Budget & Encumbrance transactions
                      AND jh.je_header_id > l_max_header_id_saved
                      AND NOT EXISTS
                    (SELECT 'je_header_id_already_exists'
                             FROM xxxla_sla_expense_details xsed
                            WHERE xsed.ledger_id = jh.ledger_id
                              AND xsed.application_id = 101
                              AND xsed.balance_type_code != 'A'
                              AND xsed.other_trx_id1 = jh.je_header_id)
                      AND gcc.segment3 != '999999' --encumbrance offset account
                      AND jh.ledger_id = ledger_ids_enc_bud_csr.ledger_id) a
            WHERE abs(a.entered) + abs(a.accounted) != 0
            GROUP BY a.ledger_id,
                     a.code_combination_id,
                     a.period_name,
                     a.application_id,
                     a.gl_date,
                     a.trx_date,
                     a.balance_type_code,
                     a.budget_version_id,
                     a.encumbrance_type_id,
                     a.source_type,
                     a.trx_type,
                     a.description,
                     a.inv_dist_id,
                     a.po_dist_id,
                     a.req_dist_id,
                     a.inv_id,
                     a.po_id,
                     a.req_id,
                     a.vendor_id,
                     a.other_trx_id1,
                     a.other_trx_id2,
                     a.currency);
      
        COMMIT;
        fnd_file.put_line(fnd_file.log,
                          'inserted Manual GL Budget or Encumbrance lines for ledger: ' ||
                          ledger_ids_enc_bud_csr.ledger_id);
      
      END IF;
    END LOOP;
  
    --insert (or just update in case record exists) special record in xpslud table
    --with last update date of the table for ledger id
    --(application id = -999, ledger id = relevant ledger id, period name = 'LST_UPDATE_DATE'
    FOR ledger_ids_enc_bud_csr IN csr_ledger_ids_enc_bud LOOP
    
      BEGIN
        SELECT 1
          INTO l_is_exist_table_update_record
          FROM xx_periods_status_lst_upd_date xpslud
         WHERE xpslud.application_id = -999
           AND xpslud.ledger_id = ledger_ids_enc_bud_csr.ledger_id
           AND xpslud.period_name = 'LST_UPDATE_DATE';
      
        --record exists then only update
        UPDATE xx_periods_status_lst_upd_date xpslud
           SET xpslud.test_period_last_upd_date = SYSDATE
         WHERE xpslud.application_id = -999
           AND xpslud.ledger_id = ledger_ids_enc_bud_csr.ledger_id
           AND xpslud.period_name = 'LST_UPDATE_DATE';
      
        COMMIT;
        fnd_file.put_line(fnd_file.log,
                          'xpslud table was updated in the -999 special line with table update date for ledger: ' ||
                          ledger_ids_enc_bud_csr.ledger_id);
      EXCEPTION
        WHEN OTHERS THEN
          --record doesn't exist then insert new record
          INSERT INTO xx_periods_status_lst_upd_date xpslud
          VALUES
            (-999,
             ledger_ids_enc_bud_csr.ledger_id,
             'LST_UPDATE_DATE',
             SYSDATE,
             SYSDATE);
        
          COMMIT;
          fnd_file.put_line(fnd_file.log,
                            'new line was inserted to xpslud table in the -999 special line with table update date for ledger: ' ||
                            ledger_ids_enc_bud_csr.ledger_id);
        
      END;
    END LOOP;
  
  EXCEPTION
    WHEN OTHERS THEN
      retcode := 2;
      errbuf  := SQLERRM;
  END test_upl_detail_data;

  --------------------------------------------------------------------
  --  name:            log_union
  --  create by:       DANIEL.KATZ
  --  Revision:        1.0
  --  creation date:   12/19/2010
  --------------------------------------------------------------------
  --  purpose :        xla details report
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  12/19/2010  DANIEL.KATZ       initial build
  --------------------------------------------------------------------
  FUNCTION log_union(p_string VARCHAR2) RETURN NUMBER IS
  BEGIN
    fnd_file.put_line(fnd_file.log, p_string);
    RETURN 1;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 1;
  END log_union;
  --------------------------------------------------------------------
  --  name:            set_account_parent
  --  create by:       Ofer.Suad
  --  Revision:        1.0
  --  creation date:   18/01/2014
  --------------------------------------------------------------------
  --  purpose :        set parent accounts values and description

  --------------------------------------------------------------------
  FUNCTION set_account_parent RETURN NUMBER is
  
    cursor c_parent_accounts is
      select ffvc.flex_value child_value,
             min(ffv.FLEX_VALUE) parent_value,
             min(ffv.DESCRIPTION) parent_description,
             fil.ID_FLEX_NUM
        from fnd_flex_value_children_v ffvc,
             fnd_flex_values_vl        ffv,
             fnd_flex_hierarchies      ffh,
             FND_ID_FLEX_SEGMENTS_VL   fil
       where ffvc.flex_value_set_id in (1013887, 1020162)
         and ffvc.flex_value_set_id = ffh.FLEX_VALUE_SET_ID
         and ffh.flex_value_set_id = ffv.flex_value_set_id
         and ffh.hierarchy_id = ffv.STRUCTURED_HIERARCHY_LEVEL
         and ffvc.parent_flex_value = ffv.FLEX_VALUE
         and ffh.hierarchy_code like 'Budget%'
         and fil.APPLICATION_ID = 101
         and fil.ID_FLEX_CODE = 'GL#'
         and fil.APPLICATION_COLUMN_NAME = 'SEGMENT3'
         and fil.FLEX_VALUE_SET_ID = ffvc.flex_value_set_id
       group by ffvc.flex_value, fil.ID_FLEX_NUM;
  
  begin
    for i in c_parent_accounts loop
      p_accts(i.ID_FLEX_NUM || '.' || i.child_value) := i.parent_value;
      p_acct_desc(i.ID_FLEX_NUM || '.' || i.child_value) := i.parent_description;
    end loop;
  
    return 1;
  end;
  --------------------------------------------------------------------
  --  name:            get_account_parent
  --  create by:       Ofer.Suad
  --  Revision:        1.0
  --  creation date:   18/01/2014
  --------------------------------------------------------------------
  --  purpose :        get parent accounts value

  --------------------------------------------------------------------
  FUNCTION get_account_parent(p_coa_and_child varchar2) RETURN VARCHAR2 is
  begin
    return p_accts(p_coa_and_child);
  end;
  --------------------------------------------------------------------
  --  name:            get_account_parent
  --  create by:       Ofer.Suad
  --  Revision:        1.0
  --  creation date:   18/01/2014
  --------------------------------------------------------------------
  --  purpose :        get parent accounts description

  --------------------------------------------------------------------
  FUNCTION get_account_parent_desc(p_coa_and_child varchar2) RETURN varchar2 is
  begin
    return p_acct_desc(p_coa_and_child);
  end;
  --------------------------------------------------------------------
  --  name:            set_dept_parent
  --  create by:       Ofer.Suad
  --  Revision:        1.0
  --  creation date:   18/01/2014
  --------------------------------------------------------------------
  --  purpose :        set parent departments values and description

  --------------------------------------------------------------------
  FUNCTION set_dept_parent RETURN NUMBER is
  
    cursor c_parent_depts is
      select ffvc.flex_value child_value,
             min(ffv.FLEX_VALUE) parent_value,
             min(ffv.DESCRIPTION) parent_description,
             fil.ID_FLEX_NUM
        from fnd_flex_value_children_v ffvc,
             fnd_flex_values_vl        ffv,
             fnd_flex_hierarchies      ffh,
             FND_ID_FLEX_SEGMENTS_VL   fil
       where ffvc.flex_value_set_id in (1013889, 1020161)
         and ffvc.flex_value_set_id = ffh.FLEX_VALUE_SET_ID
         and ffh.flex_value_set_id = ffv.flex_value_set_id
         and ffh.hierarchy_id = ffv.STRUCTURED_HIERARCHY_LEVEL
         and ffvc.parent_flex_value = ffv.FLEX_VALUE
         and ffh.hierarchy_code like 'Budget%'
         and fil.APPLICATION_ID = 101
         and fil.ID_FLEX_CODE = 'GL#'
         and fil.APPLICATION_COLUMN_NAME = 'SEGMENT2'
         and fil.FLEX_VALUE_SET_ID = ffvc.flex_value_set_id
       group by ffvc.flex_value, fil.ID_FLEX_NUM;
  
  begin
    for i in c_parent_depts loop
      p_depts(i.ID_FLEX_NUM || '.' || i.child_value) := i.parent_value;
      p_dept_desc(i.ID_FLEX_NUM || '.' || i.child_value) := i.parent_description;
    
    end loop;
  
    return 1;
  end;
  --------------------------------------------------------------------
  --  name:            get_account_parent
  --  create by:       Ofer.Suad
  --  Revision:        1.0
  --  creation date:   18/01/2014
  --------------------------------------------------------------------
  --  purpose :        get parent department value

  --------------------------------------------------------------------
  FUNCTION get_dept_parent(p_coa_and_child varchar2) RETURN VARCHAR2 is
  begin
    return p_depts(p_coa_and_child);
  end;
  --------------------------------------------------------------------
  --  name:            get_dept_parent_desc
  --  create by:       Ofer.Suad
  --  Revision:        1.0
  --  creation date:   18/01/2014
  --------------------------------------------------------------------
  --  purpose :        get parent department description

  --------------------------------------------------------------------
  FUNCTION get_dept_parent_desc(p_coa_and_child varchar2) RETURN varchar2 is
  begin
    return p_dept_desc(p_coa_and_child);
  end;

  ----------------------------------------------------------------------------------------
  -- Ver      When         Who           Description
  -- -------  -----------  ------------  -------------------------------------------------
  -- 1.0      25-Sep-2018  Offer S.      CHG0044007-Map in Oracle XLA upload program and BI view for
  --                                         project details associated for move orders.
  --                                       pull the project id to be used by XXBI_XLA_TRANSACTIONS_V
  ----------------------------------------------------------------------------------------
  function get_project_id(p_dist_project_id number,
                          p_application_id  number,
                          p_trx_type        varchar2,
                          p_trx_id          number) return number is
    --------------------------
    --   Local Definition
    --------------------------
    l_return number;
    --------------------------
    --   Code Section
    --------------------------
  begin
    if p_dist_project_id is not null then
    
      l_return := p_dist_project_id;
    
    elsif p_application_id = 707 and p_trx_type = 'Move order' then
    
      begin
      
        select mtrl.project_id
          into l_return
          from mtl_material_transactions mmt, MTL_TXN_REQUEST_LINES mtrl
         where mmt.transaction_id = p_trx_id
           and mtrl.line_id = mmt.trx_source_line_id;
      
      exception
        when others then
        
          l_return := null;
        
      end;
    else
    
      l_return := null;
    
    end if;
  
    return l_return;
  end get_project_id;

END xxxla_detail_disco;
/
