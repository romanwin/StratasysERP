create or replace view xxap_prep_open_balance_disco_v as
select
-----------------------------------------------------------------------------
--Created By Daniel Katz
--for AP Open Prepayment Balance Disco Report.
--note: run this view with disco parameter end_period.
-----------------------------------------------------------------------------

--additional relevant objects are:
--Package: xxap_prep_open_balance_disco
--table: xxap_prep_open_invoices
-----------------------------------------------------------------------------
 decode(aid.line_type_lookup_code,
        'ITEM',
        'PREPAYMENT',
        'PREPAY',
        'APPLIED INVOICE') meaning,
 hou.short_code Operating_Unit,
 nvl(ai_prep.invoice_num, ai.invoice_num) prepayment_num,
 (select ph.segment1
    from po_headers_all ph
   where ph.po_header_id =
         nvl(ai_prep.quick_po_header_id, ai.quick_po_header_id)) po_number_reference, --it is manual reference withought matching to po
 decode(nvl(ai_prep.quick_po_header_id, ai.quick_po_header_id),null,null,
        xxap_prep_open_balance_disco.is_inventory_po(nvl(ai_prep.quick_po_header_id, ai.quick_po_header_id))) non_exp_flag,
 ai.invoice_num trx_number,
 ai.invoice_date,
 ai.invoice_amount,
 decode(aid.line_type_lookup_code,
        'PREPAY',
        null,
        xxap_prep_open_balance_disco.set_get_prep_to_pay(ai.invoice_amount,
                                                         ai.invoice_id)) prep_remain_amount_to_pay,

 decode(aid.line_type_lookup_code,
        'PREPAY',
        null,
        round(xxap_prep_open_balance_disco.get_prep_to_pay *
              decode(ai.invoice_currency_code,
                     'USD',
                     1,
                     gl_currency_api.get_closest_rate( /*x_from_currency => */ai.invoice_currency_code,
                                                      /*x_to_currency     =>*/
                                                      'USD',
                                                      /*x_conversion_date =>*/
                                                      ai.gl_date,
                                                      /*x_conversion_type =>*/
                                                      'Corporate',
                                                      /*x_max_roll_days   =>*/
                                                      100)),
              2)) prep_remain_amount_to_pay_usd,

 decode(aid.line_type_lookup_code,
        'PREPAY',
        null,
        round(xxap_prep_open_balance_disco.get_prep_to_pay *
              nvl(ai.exchange_rate, 1),
              2)) prep_remain_amount_to_pay_func,
 asup.vendor_name,
 asup_site.vendor_site_code vendor_site,
 ai.description trx_description,
 ai.invoice_currency_code currency,
 gcc.segment3 account,
 gcc.concatenated_segments account_comb,
 (case
   when aid.line_type_lookup_code = 'ITEM' then --prepayment
    nvl(aid.base_amount, aid.amount)
   else --applied invoice
    round(aid.amount * nvl(ai_prep.exchange_rate, 1), 2) --application is according to prepayment source exchange rate
 end) func_amount,
 aid.amount ent_amount,
 aid.accounting_date gl_date,
 aid.reversal_flag current_reversal_flag,
 aid.accrual_posted_flag current_posted_flag,
 gp.period_name trx_period_name,
 gp.end_date trx_period_end_date,
 gp_end.end_date,
 gp_end.period_name end_period --parameter for disco
  from ap_invoices_all ai_prep,
       ap_invoice_distributions_all aid_prep,
       ap_invoices_all ai,
       ap_invoice_distributions_all aid,
       ap_suppliers asup,
       ap_supplier_sites_all asup_site,
       gl_code_combinations_kfv gcc,
       hr_operating_units hou,
       gl_periods gp_end,
       gl_periods gp,
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
                                   and xpoi.as_of_date =
                                       xxap_prep_open_balance_disco.get_last_date
                                union all
                                select aid.Invoice_Distribution_Id dist_id
                                  from ap_invoice_distributions aid,
                                       ap_invoices_all          ai
                                 where ai.invoice_id = aid.invoice_id
                                   and ai.invoice_type_lookup_code =
                                       'PREPAYMENT'
                                   and aid.line_type_lookup_code = 'ITEM'
                                   and aid.accounting_date between
                                       xxap_prep_open_balance_disco.get_last_date + 1 and
                                       xxap_prep_open_balance_disco.get_as_of_date) relevant_dist
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
                                 where xpoi.meaning = 'APPLIED INVOICE'
                                   and xpoi.as_of_date =
                                       xxap_prep_open_balance_disco.get_last_date
                                union all
                                select aid.Invoice_Distribution_Id dist_id
                                  from ap_invoice_distributions aid
                                 where aid.line_type_lookup_code = 'PREPAY'
                                   and aid.accounting_date between
                                       xxap_prep_open_balance_disco.get_last_date + 1 and
                                       xxap_prep_open_balance_disco.get_as_of_date
                                   and aid.prepay_distribution_id is not null /*for index use*/
                                ) relevant_dist
                         where aid_inv.prepay_distribution_id =
                               aid_prep2.invoice_distribution_id
                           and aid_inv.invoice_distribution_id =
                               relevant_dist.dist_id)prepayments)
         where balance != 0) open_prep
 where aid.prepay_distribution_id = aid_prep.invoice_distribution_id(+)
   and aid_prep.invoice_id = ai_prep.invoice_id(+)
   and aid.invoice_id = ai.invoice_id
   and ai.vendor_id = asup.vendor_id
   and ai.vendor_site_id = asup_site.vendor_site_id
   and aid.dist_code_combination_id = gcc.code_combination_id
   and hou.organization_id = aid.org_id
   and aid.invoice_distribution_id = open_prep.dist_id
   and gp_end.period_set_name = 'OBJET_CALENDAR'
   and gp_end.period_set_name = gp.period_set_name
   and gp_end.adjustment_period_flag = 'N'
   and gp_end.adjustment_period_flag = gp.adjustment_period_flag
   and aid.accounting_date between gp.start_date and gp.end_date
   and xxap_prep_open_balance_disco.set_last_date(gp_end.end_date) = 1
   and xxap_prep_open_balance_disco.set_as_of_date(gp_end.end_date) = 1;

