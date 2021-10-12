create or replace view xxap_clr_sla_open_bal_disco_v as
select
-----------------------------------------------------------------------------
--Created By Daniel Katz
--for AP Open Cash Clearing SLA Balance Disco Report.
--note: run this view only with the disco report
--     it adds parameters of end_period and the relevant clearing account.
--     for the relevant clearing account it initialize xxap_prep_open_balance_disco.set_sla_prep_accounts('&account')=1
-----------------------------------------------------------------------------

--additional relevant objects are:
   --Package: xxap_clr_open_balance_disco
   --table: xxap_clearing_sla_balance
   --Package: xxap_prep_open_balance_disco
-----------------------------------------------------------------------------

a."LEDGER",a."LEDGER_ID",a."GL_TRANSFER_STATUS_CODE",a."VENDOR_NAME",a."ACCOUNT",a."ENTERED",a."ACCOUNTED",a."ENTITY_CODE",a."CHECK_NUMBER",a."INVOICE_NUM",a."GL_DATE",a."CURRENCY_CODE",a."ACCOUNTING_CLASS_CODE",a."DESCRIPTION",a."AE_HEADER_ID",a."AE_LINE_NUM",a."JE_CATEGORY_NAME",a."DOC_CATEGORY_CODE",a."DOC_SEQUENCE_ID",a."DOC_SEQUENCE_VALUE",a."PERIOD_NAME",a."BANK_ACCOUNT_NAME",a."PAYMENT_METHOD_CODE",a."CHECK_ID",a."BALANCE", gp_end.end_date, gp_end.period_name end_period --disco parameter
  from (select gl.short_name ledger,
               xh.ledger_id,
               xh.gl_transfer_status_code,
               decode(xl.accounting_class_code,
                      'CASH_CLEARING',
                      ac.vendor_name,
                      asup.vendor_name) vendor_name,
               gcc.segment3 account,
               nvl(xl.entered_dr, 0) - nvl(xl.entered_cr, 0) entered,
               nvl(xl.accounted_dr, 0) - nvl(xl.accounted_cr, 0) accounted,
               xte.entity_code,
               decode(xl.accounting_class_code,
                      'CASH_CLEARING',
                      ac.check_number,
                      null) check_number,
               decode(xl.accounting_class_code,
                      'CASH_CLEARING',
                      null,
                      ai.invoice_num) invoice_num,
               xh.accounting_date gl_date,
               xl.currency_code,
               xl.accounting_class_code,
               xl.description,
               xl.ae_header_id,
               xl.ae_line_num,
               xh.je_category_name,
               xh.doc_category_code,
               xh.doc_sequence_id,
               xh.doc_sequence_value,
               xh.period_name,
               decode(xl.accounting_class_code,
                      'CASH_CLEARING',
                      ac.bank_account_name,
                      null) bank_account_name,
               decode(xl.accounting_class_code,
                      'CASH_CLEARING',
                      ac.payment_method_code,
                      null) payment_method_code,
               decode(xl.accounting_class_code,
                      'CASH_CLEARING',
                      ac.check_id,
                      -xh.ledger_id || xl.code_combination_id) check_id,
               sum(nvl(xl.entered_dr, 0) - nvl(xl.entered_cr, 0)) over(partition by decode(xl.accounting_class_code, 'CASH_CLEARING', ac.check_id, -xh.ledger_id || xl.code_combination_id)) balance
          from xla_ae_lines xl,
               gl_code_combinations gcc,
               xla_AE_HEADERS XH,
               xla_transaction_entities xte,
               ap_checks_all ac,
               ap_invoices_all ai,
               ap_suppliers asup,
               gl_ledgers gl,
               (select xcsb.ae_header_id, xcsb.ae_line_num
                  from xxap_clearing_sla_balance xcsb
                 where xcsb.as_of_date =
                       xxap_clr_open_balance_disco.get_sla_last_date
                union all
                select xl.ae_header_id, xl.ae_line_num
                  from xla_ae_lines          xl,
                       gl_code_combinations  gcc,
                       gl_access_set_ledgers gasl
                 where gcc.code_combination_id = xl.code_combination_id
                   and xl.application_id = 200
                   and xl.ledger_id = gasl.ledger_id
                   and gasl.access_set_id =
                       fnd_profile.VALUE('GL_ACCESS_SET_ID')
                   and xl.accounting_date between
                       xxap_clr_open_balance_disco.get_sla_last_date + 1 and
                       xxap_clr_open_balance_disco.get_sla_as_of_date
                   and gcc.segment3 =
                       xxap_prep_open_balance_disco.get_sla_prep_accounts(1) /*using function from prep pkg*/
                ) relevant_id
         where xl.code_combination_id = gcc.code_combination_id
           AND xl.ae_header_id = xh.ae_header_id
           and xl.application_id = xh.application_id
           and xh.application_id = xte.application_id
           and xh.entity_id = xte.entity_id
           and xh.application_id = 200
           and xh.accounting_entry_status_code = 'F'
           and xte.source_id_int_1 = ac.check_id(+)
           and xte.source_id_int_1 = ai.invoice_id(+)
           and ai.vendor_id = asup.vendor_id(+)
           and xh.ledger_id = gl.ledger_id
           and relevant_id.ae_header_id = xl.ae_header_id
           and relevant_id.ae_line_num = xl.ae_line_num
           and xh.balance_type_code = 'A') a,
       gl_periods gp_end
 where balance != 0
   and gp_end.period_set_name = 'OBJET_CALENDAR'
   and gp_end.adjustment_period_flag = 'N'
      --Accounting corruptions in SLA - payments cleared in same period but accounting was wrong.
      -- manual GL Journals done as Payables Source ans Adjustment Category.
      -- they will be deleted directly from the xxap_clearing_sla_balance table by the program in package.
      --and check_id not in (24822, 19476, 25071, 17465, 14368)
   and xxap_clr_open_balance_disco.set_sla_last_date(gp_end.end_date) = 1
   and xxap_clr_open_balance_disco.set_sla_as_of_date(gp_end.end_date) = 1;

