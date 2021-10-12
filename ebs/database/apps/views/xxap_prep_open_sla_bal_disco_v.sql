create or replace view xxap_prep_open_sla_bal_disco_v as
select
-----------------------------------------------------------------------------
--Created By Daniel Katz
--for AP SLA Open Prepayment Balance Disco Report.
--note: run this view only with the disco report
--      it adds parameters of end_period and the relevant prepayment accounts.
--     for the relevant prep accounts it initialize xxap_prep_open_balance_disco.set_sla_prep_accounts('&account')=1
--      the &account is a string of concatenated accounts (up to 5 accounts) separated by '-' character.
-----------------------------------------------------------------------------

--additional relevant objects are:
--Package: xxap_prep_open_balance_disco
--table: xxap_prep_sla_open_invoices
-----------------------------------------------------------------------------
 aa."PREP_REMAIN",aa."LEDGER_ID",aa."LEDGER",aa."CURRENT_TRANSFER_FLAG",aa."VENDOR_NAME",aa."VENDOR_NUMBER",aa."ACCOUNT",aa."ACCOUNTED",aa."ENTERED",aa."PREPAYMENT_NUM",aa."INVOICE_NUM",aa."INVOICE_DATE",aa."GL_DATE",aa."INVOICE_CURRENCY_CODE",aa."INVOICE_TYPE_LOOKUP_CODE",aa."LINE_TYPE_LOOKUP_CODE",aa."AE_HEADER_ID",aa."AE_LINE_NUM",aa."PREPAYMENT_ID",gp_end.period_name end_period
  from (select sum(entered) over(partition by prepayment_id) prep_remain,
               a.*
          from (select xh.ledger_id,
                       gl.short_name ledger,
                       xh.gl_transfer_status_code current_transfer_flag,
                       asup.vendor_name,
                       asup.segment1 vendor_number,
                       gcc.segment3 account,
                       nvl(xdl.unrounded_accounted_dr, 0) -
                       nvl(xdl.unrounded_accounted_cr, 0) accounted,
                       nvl(xdl.unrounded_entered_dr, 0) -
                       nvl(xdl.unrounded_entered_cr, 0) entered ,
                       decode(ai.invoice_type_lookup_code,
                              'PREPAYMENT',
                              ai.invoice_num,
                              null) prepayment_num,
                       ai.invoice_num,
                       ai.invoice_date,
                       xh.accounting_date gl_date,
                       ai.invoice_currency_code,
                       AI.INVOICE_TYPE_LOOKUP_CODE,
                       aid.line_type_lookup_code,
                       xl.ae_header_id,
                       xl.ae_line_num,
                       decode(ai.invoice_type_lookup_code,
                              'PREPAYMENT',
                              ai.invoice_id,
                              -ai.org_id||xl.code_combination_id) prepayment_id
                  from xla_ae_lines         xl,
                       gl_code_combinations gcc,
                       xla_ae_headers       xh,
                       ap_suppliers         asup,
                       ap_invoices_all ai,
                       xla_distribution_links xdl,
                       ap_invoice_distributions aid,
                       gl_ledgers gl,
                       (select xpsoi.ae_header_id, xpsoi.ae_line_num
                          from xxap_prep_sla_open_invoices xpsoi
                         where xpsoi.source_distribution_type = 'AP_INV_DIST'
                           and xpsoi.as_of_date =
                               xxap_prep_open_balance_disco.get_sla_last_date
                        union all
                        select xl2.ae_header_id, xl2.ae_line_num
                          from xla_ae_lines          xl2,
                               gl_access_set_ledgers gasl,
                               gl_code_combinations  gcc
                         where xl2.application_id = 200
                           and xl2.accounting_date between
                               xxap_prep_open_balance_disco.get_sla_last_date + 1 and
                               xxap_prep_open_balance_disco.get_sla_as_of_date
                           and xl2.ledger_id = gasl.ledger_id
                           and gasl.access_set_id =
                               fnd_profile.VALUE('GL_ACCESS_SET_ID')
                           and gcc.code_combination_id =
                               xl2.code_combination_id
                           and (gcc.segment3 =
                               xxap_prep_open_balance_disco.get_sla_prep_accounts(1) or --done like this to use the index
                               gcc.segment3 =
                               xxap_prep_open_balance_disco.get_sla_prep_accounts(2) or
                               gcc.segment3 =
                               xxap_prep_open_balance_disco.get_sla_prep_accounts(3) or
                               gcc.segment3 =
                               xxap_prep_open_balance_disco.get_sla_prep_accounts(4) or
                               gcc.segment3 =
                               xxap_prep_open_balance_disco.get_sla_prep_accounts(5))) relevant_ae_lines
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
                   and xh.accounting_entry_type_code !='MANUAL'
                   and xl.code_combination_id = gcc.code_combination_id
                   and asup.vendor_id = ai.vendor_id
                   and xh.balance_type_code = 'A'
                   and aid.invoice_id = ai.invoice_id
                   and xh.ledger_id = gl.ledger_id
                   and relevant_ae_lines.ae_header_id = xl.ae_header_id
                   and relevant_ae_lines.ae_line_num = xl.ae_line_num
                union all
                select xh.ledger_id,
                       gl.short_name ledger,
                       xh.gl_transfer_status_code,
                       asup.vendor_name,
                       asup.segment1 vendor_number,
                       gcc.segment3 account,
                       nvl(xdl.unrounded_accounted_dr, 0) -
                       nvl(xdl.unrounded_accounted_cr, 0) accounted,
                       nvl(xdl.unrounded_entered_dr, 0) -
                       nvl(xdl.unrounded_entered_cr, 0) entered ,
                       ai_prep.invoice_num prepayment_num,
                       ai.invoice_num,
                       ai.invoice_date,
                       xh.accounting_date,
                       ai.invoice_currency_code,
                       AI.INVOICE_TYPE_LOOKUP_CODE,
                       aid.line_type_lookup_code,
                       xl.ae_header_id,
                       xl.ae_line_num,
                       ai_prep.invoice_id prep_id
                  from xla_ae_lines         xl,
                       gl_code_combinations gcc,
                       xla_ae_headers       xh,
                       Ap_Suppliers         asup,
                       ap_invoices_all              ai,
                       ap_invoices_all              ai_prep,
                       xla_distribution_links       xdl,
                       ap_invoice_distributions     aid,
                       ap_invoice_distributions_all aid_prep,
                       ap_prepay_app_dists          apad,
                       gl_ledgers                   gl,
                       (select xpsoi.ae_header_id, xpsoi.ae_line_num
                          from xxap_prep_sla_open_invoices xpsoi
                         where xpsoi.source_distribution_type = 'AP_PREPAY'
                           and xpsoi.as_of_date =
                               xxap_prep_open_balance_disco.get_sla_last_date
                        union all
                        select xl2.ae_header_id, xl2.ae_line_num
                          from xla_ae_lines          xl2,
                               gl_access_set_ledgers gasl,
                               gl_code_combinations  gcc
                         where xl2.application_id = 200
                           and xl2.accounting_date between
                               xxap_prep_open_balance_disco.get_sla_last_date + 1 and
                               xxap_prep_open_balance_disco.get_sla_as_of_date
                           and xl2.ledger_id = gasl.ledger_id
                           and gasl.access_set_id =
                               fnd_profile.VALUE('GL_ACCESS_SET_ID')
                           and gcc.code_combination_id =
                               xl2.code_combination_id
                           and (gcc.segment3 =
                               xxap_prep_open_balance_disco.get_sla_prep_accounts(1) or --done like this to use the index
                               gcc.segment3 =
                               xxap_prep_open_balance_disco.get_sla_prep_accounts(2) or
                               gcc.segment3 =
                               xxap_prep_open_balance_disco.get_sla_prep_accounts(3) or
                               gcc.segment3 =
                               xxap_prep_open_balance_disco.get_sla_prep_accounts(4) or
                               gcc.segment3 =
                               xxap_prep_open_balance_disco.get_sla_prep_accounts(5))) relevant_ae_lines
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
                   and xh.accounting_entry_type_code !='MANUAL'
                   and xl.code_combination_id = gcc.code_combination_id
                   and asup.vendor_id = ai.vendor_id
                   and xh.balance_type_code = 'A'
                   and aid.invoice_distribution_id =
                       apad.prepay_app_distribution_id
                   and aid.invoice_id = ai.invoice_id
                   and aid_prep.invoice_distribution_id =
                       aid.prepay_distribution_id
                   and aid_prep.invoice_id = ai_prep.invoice_id
                   and gl.ledger_id = xh.ledger_id
                   and relevant_ae_lines.ae_header_id = xl.ae_header_id
                   and relevant_ae_lines.ae_line_num = xl.ae_line_num

                --xla manual transactions from data fixes doesn't have the relation to distribution id.
                --thus, i use here the ref accounting event to retrieve the data.
                 union all
               select xh.ledger_id,
                       gl.short_name ledger,
                       xh.gl_transfer_status_code,
                       asup.vendor_name,
                       asup.segment1 vendor_number,
                       gcc.segment3 account,
                       nvl(xdl.unrounded_accounted_dr, 0) -
                       nvl(xdl.unrounded_accounted_cr, 0) accounted,
                       nvl(xdl.unrounded_entered_dr, 0) -
                       nvl(xdl.unrounded_entered_cr, 0) entered ,
                       decode(ai.invoice_type_lookup_code,
                              'PREPAYMENT',
                              ai.invoice_num,
                              'STANDARD',
                              --if it is not prepay distribution then the following will be null
                              ai_prep.invoice_num) prepayment_num,
                       ai.invoice_num,
                       ai.invoice_date,
                       xh.accounting_date,
                       ai.invoice_currency_code,
                       AI.INVOICE_TYPE_LOOKUP_CODE,
                       aid.line_type_lookup_code,
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
                       gl_code_combinations gcc,
                       xla_ae_headers       xh,
                       Ap_Suppliers         asup,
                       ap_invoices_all              ai,
                       ap_invoices_all              ai_prep,
                       xla_distribution_links       xdl,
                       ap_invoice_distributions     aid,
                       ap_invoice_distributions_all aid_prep,
                       gl_ledgers                   gl,
                       (select xpsoi.ae_header_id, xpsoi.ae_line_num
                          from xxap_prep_sla_open_invoices xpsoi
                         where xpsoi.source_distribution_type = 'XLA_MANUAL'
                           and xpsoi.as_of_date =
                               xxap_prep_open_balance_disco.get_sla_last_date
                        union all
                        select xl2.ae_header_id, xl2.ae_line_num
                          from xla_ae_lines          xl2,
                               gl_access_set_ledgers gasl,
                               gl_code_combinations  gcc
                         where xl2.application_id = 200
                           and xl2.accounting_date between
                               xxap_prep_open_balance_disco.get_sla_last_date + 1 and
                               xxap_prep_open_balance_disco.get_sla_as_of_date
                           and xl2.ledger_id = gasl.ledger_id
                           and gasl.access_set_id =
                               fnd_profile.VALUE('GL_ACCESS_SET_ID')
                           and gcc.code_combination_id =
                               xl2.code_combination_id
                           and (gcc.segment3 =
                               xxap_prep_open_balance_disco.get_sla_prep_accounts(1) or --done like this to use the index
                               gcc.segment3 =
                               xxap_prep_open_balance_disco.get_sla_prep_accounts(2) or
                               gcc.segment3 =
                               xxap_prep_open_balance_disco.get_sla_prep_accounts(3) or
                               gcc.segment3 =
                               xxap_prep_open_balance_disco.get_sla_prep_accounts(4) or
                               gcc.segment3 =
                               xxap_prep_open_balance_disco.get_sla_prep_accounts(5))) relevant_ae_lines
                 where xl.application_id = 200
                   and xl.application_id = xh.application_id
                   and xl.application_id = xdl.application_id
                   and xl.ae_header_id = xh.ae_header_id
                   and xdl.ae_header_id = xl.ae_header_id
                   and xdl.ae_line_num = xl.ae_line_num
                   and xdl.source_distribution_type = 'XLA_MANUAL'
                   --AND XH.ACCOUNTING_ENTRY_TYPE_CODE = 'MANUAL'
                   and xl.code_combination_id = gcc.code_combination_id
                   and asup.vendor_id = ai.vendor_id
                   and xh.balance_type_code = 'A'
                   and aid.accounting_event_id = xdl.ref_event_id
                   and aid.invoice_id = ai.invoice_id
                   and aid_prep.invoice_distribution_id(+) =
                       aid.prepay_distribution_id
                   and aid_prep.invoice_id = ai_prep.invoice_id(+)
                   and gl.ledger_id = xh.ledger_id
                   and relevant_ae_lines.ae_header_id = xl.ae_header_id
                   and relevant_ae_lines.ae_line_num = xl.ae_line_num

                --Manual transactions from data fixes for ap_prepay source has source id but it sometimes doesn't have a related value
                --in ap_prepay_app_dist table.
                --thus, i use here the applied to dist num to retrieve the data.
                 union all
               select xh.ledger_id,
                       gl.short_name ledger,
                       xh.gl_transfer_status_code,
                       asup.vendor_name,
                       asup.segment1 vendor_number,
                       gcc.segment3 account,
                       nvl(xdl.unrounded_accounted_dr, 0) -
                       nvl(xdl.unrounded_accounted_cr, 0) accounted,
                       nvl(xdl.unrounded_entered_dr, 0) -
                       nvl(xdl.unrounded_entered_cr, 0) entered ,
                       ai_prep.invoice_num prepayment_num,
                       ai.invoice_num,
                       ai.invoice_date,
                       xh.accounting_date,
                       ai.invoice_currency_code,
                       AI.INVOICE_TYPE_LOOKUP_CODE,
                       null line_type_lookup_code,
                       xl.ae_header_id,
                       xl.ae_line_num,
                       ai_prep.invoice_id prepayment_id
                  from xla_ae_lines         xl,
                       gl_code_combinations gcc,
                       xla_ae_headers       xh,
                       xla_transaction_entities_upg xte,
                       Ap_Suppliers         asup,
                       ap_invoices_all              ai,
                       ap_invoices_all              ai_prep,
                       xla_distribution_links       xdl,
                       --ap_invoice_distributions     aid,
                       ap_invoice_distributions_all aid_prep,
                       gl_ledgers                   gl,
                       (select xpsoi.ae_header_id, xpsoi.ae_line_num
                          from xxap_prep_sla_open_invoices xpsoi
                         where xpsoi.source_distribution_type = 'AP_PREPAY'
                           and xpsoi.as_of_date =
                               xxap_prep_open_balance_disco.get_sla_last_date
                        union all
                        select xl2.ae_header_id, xl2.ae_line_num
                          from xla_ae_lines          xl2,
                               gl_access_set_ledgers gasl,
                               gl_code_combinations  gcc
                         where xl2.application_id = 200
                           and xl2.accounting_date between
                               xxap_prep_open_balance_disco.get_sla_last_date + 1 and
                               xxap_prep_open_balance_disco.get_sla_as_of_date
                           and xl2.ledger_id = gasl.ledger_id
                           and gasl.access_set_id =
                               fnd_profile.VALUE('GL_ACCESS_SET_ID')
                           and gcc.code_combination_id =
                               xl2.code_combination_id
                           and (gcc.segment3 =
                               xxap_prep_open_balance_disco.get_sla_prep_accounts(1) or --done like this to use the index
                               gcc.segment3 =
                               xxap_prep_open_balance_disco.get_sla_prep_accounts(2) or
                               gcc.segment3 =
                               xxap_prep_open_balance_disco.get_sla_prep_accounts(3) or
                               gcc.segment3 =
                               xxap_prep_open_balance_disco.get_sla_prep_accounts(4) or
                               gcc.segment3 =
                               xxap_prep_open_balance_disco.get_sla_prep_accounts(5))) relevant_ae_lines
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
                   and xl.code_combination_id = gcc.code_combination_id
                   and asup.vendor_id = ai_prep.vendor_id
                   and xh.balance_type_code = 'A'
                   and aid_prep.invoice_distribution_id = xdl.applied_to_dist_id_num_1
                   and xte.source_id_int_1 = ai.invoice_id
                   and aid_prep.invoice_id = ai_prep.invoice_id
                   and gl.ledger_id = xh.ledger_id
                   and relevant_ae_lines.ae_header_id = xl.ae_header_id
                   and relevant_ae_lines.ae_line_num = xl.ae_line_num
                   ) a)aa,
       gl_periods gp_end
 where prep_remain != 0
   and gp_end.period_set_name = 'OBJET_CALENDAR'
   and gp_end.adjustment_period_flag = 'N'
   and xxap_prep_open_balance_disco.set_sla_last_date(gp_end.end_date) = 1
   and xxap_prep_open_balance_disco.set_sla_as_of_date(gp_end.end_date) = 1;

