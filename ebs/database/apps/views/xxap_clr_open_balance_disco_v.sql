CREATE OR REPLACE VIEW XXAP_CLR_OPEN_BALANCE_DISCO_V AS
select
-----------------------------------------------------------------------------
--Created By Daniel Katz
--for AP Open Cash Clearing Balance Disco Report.
--note: run this view with disco parameter end_period + account.
-----------------------------------------------------------------------------

--additional relevant objects are:
   --Package: xxap_clr_open_balance_disco
   --table: xxap_clearing_balance
-----------------------------------------------------------------------------
       gp_end.period_name, --disco parameter + account
       gp_end.end_date,
       gp.period_name trx_gl_period,
       gp.end_date    trx_gl_period_end_date,
       a."OPERATING_UNIT",a."TRANSACTION_TYPE",a."CHECK_ID",a."CHECK_NUMBER",a."CURRENCY",a."ENTERED",a."GL_DATE",a."BANK_ACCOUNT_NAME",a."PAYMENT_METHOD_CODE",a."VENDOR_NAME",a."ACCOUNT",a."POSTED_FLAG",a."BALANCE",a."PAYMENT_TYPE_FLAG",a."ORG_ID",a."PAYMENT_HISTORY_ID"
  from (select hou.short_code Operating_Unit,
               aph.transaction_type,
               aph.check_id,
               ac.check_number,
               aph.pmt_currency_code currency,
               (case
                 when aph.transaction_type in
                      ('PAYMENT CREATED', 'PAYMENT UNCLEARING',
                       'REFUND RECORDED', 'PAYMENT MATURITY') then
                  -1
                 else
                  1
               end) * (aph.trx_pmt_amount-nvl(aph.charges_pmt_amount,0)) - (case
                 when aph.transaction_type = 'PAYMENT CREATED' and
                      ac.payment_type_flag = 'Q' then
                  (SELECT nvl(sum(aid.amount), 0) --in aphd the sum is not always correct
                     from ap_payment_hist_dists        aphd,
                          ap_invoice_distributions_all aid
                    where aphd.payment_history_id = aph.payment_history_id
                      and aphd.invoice_distribution_id =
                          aid.invoice_distribution_id
                      and aphd.pay_dist_lookup_code = 'AWT')
                 else
                  0
               end) entered,
               aph.accounting_date gl_date,
               ac.bank_account_name,
               ac.payment_method_code,
               ac.vendor_name,
               (select min(gcc.segment3)
                  from xla_ae_lines         xl,
                       xla_ae_headers       xh,
                       gl_code_combinations gcc
                 where xl.application_id = 200
                   and xl.application_id = xh.application_id
                   and xl.ae_header_id = xh.ae_header_id
                   and xl.code_combination_id = gcc.code_combination_id
                   and xh.event_id = aph.accounting_event_id
                   and xl.accounting_class_code = 'CASH_CLEARING') account,
               aph.posted_flag,
               sum((case
                     when aph.transaction_type in
                          ('PAYMENT CREATED', 'PAYMENT UNCLEARING',
                           'REFUND RECORDED', 'PAYMENT MATURITY') then
                      -1
                     else
                      1
                   end) * (aph.trx_pmt_amount-nvl(aph.charges_pmt_amount,0)) - (case
                     when aph.transaction_type = 'PAYMENT CREATED' and
                          ac.payment_type_flag = 'Q' then
                      (SELECT nvl(sum(aid.amount), 0) --in aphd the sum is not always correct
                         from ap_payment_hist_dists        aphd,
                              ap_invoice_distributions_all aid
                        where aphd.payment_history_id = aph.payment_history_id
                          and aphd.invoice_distribution_id =
                              aid.invoice_distribution_id
                          and aphd.pay_dist_lookup_code = 'AWT')
                     else
                      0
                   end)) over(partition by aph.check_id) balance,
               ac.payment_type_flag,
               aph.org_id,
               aph.payment_history_id
          from ap_checks_all          ac,
               ap_payment_history aph,
               hr_operating_units hou,
               (select xcb.payment_history_id
                  from xxap_clearing_balance xcb
                 where xcb.as_of_date =
                       xxap_clr_open_balance_disco.get_last_date
                union all
                select aph.Payment_History_Id
                  from ap_payment_history_all aph
                 where aph.accounting_date between
                       xxap_clr_open_balance_disco.get_last_date + 1 and
                       xxap_clr_open_balance_disco.get_as_of_date) relevant_id
         where ac.check_id = aph.check_id
           and ac.org_id = hou.organization_id
           and relevant_id.payment_history_id = aph.payment_history_id) a,
       gl_periods gp_end,
       gl_periods gp
 where balance != 0
   and gp_end.period_set_name = 'OBJET_CALENDAR'
   and gp_end.adjustment_period_flag = 'N'
   and gp.period_set_name = gp_end.period_set_name
   and gp.adjustment_period_flag = gp_end.adjustment_period_flag
   and gl_date between gp.start_date and gp.end_date
   and xxap_clr_open_balance_disco.set_last_date(gp_end.end_date) = 1
   and xxap_clr_open_balance_disco.set_as_of_date(gp_end.end_date) = 1;
