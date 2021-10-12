create or replace view xxar_revenue_recog_disco_v as
select
--------------------------------------------------------------------
--  customization code: CUSTxxx
--  name:               xxar_revenue_recog_disco_v
--  create by:          Daniel Katz
--  $Revision:          1.0
--  creation date:      xx/xx/2010
--  Purpose :           for Revenue Recognition Disco Report.
--                      Note: this view could be used ONLY WITH THE DISCO REPORT
--                      !!! DO NOT RUN IT AS A STAND ALONE!!!
--                      additional relevant objects are:
--                      Package: XXAR_REVENUE_RECOGNITION_DISCO
--                      Function xxar_utils_pkg.get_item_last_il_cost_ic_trx
----------------------------------------------------------------------
--  ver   date          name            desc
--  1.0   xx/xx/2010    Daniel Katz     initial build
--  1.1   01/05/2011    Ofer Suad
--  1.2   14/08/2011    Ofer Suad add Sale Order Channel
--  1.3   14/12/2011    Ofer Suad Take Product line from item insted of distribution
--  1.4   27/12/2012    Add sys booking date and Freight_Terms
-----------------------------------------------------------------------
--Revenue while cost is not rma
       decode(rctl.quantity_invoiced, null, 'REVENUE CM', 'REVENUE') Meaning,
       rctlgd.cust_trx_line_gl_dist_id,
       ho.short_code Operating_Unit,
       rct.org_id,
       rbs.name invoice_source,
       rctt.name invoice_trx_type,
       rctl.interface_line_attribute2 order_type,
       rct.trx_number invoice_number,
       nvl(rctl.interface_line_attribute1, /*rct.interface_header_attribute1*/rct.ct_reference) order_number,
       xxar_revenue_recognition_disco.get_applied_invoice_info(rct.customer_trx_id) applied_to_inv_credit_ref,
       rct.trx_date invoice_date,
       hp.party_name bill_to_customer,
       hca.account_number bill_to_cust_account_number,
       rs.name sale_person_name,
       hca.sales_channel_code sale_channel,
       rctl.line_number invoice_line,
       rctlgd.gl_date,
        (case when XXAR_REVENUE_RECOGNITION_DISCO.is_SSYS_item(rctl.inventory_item_id)=1 then
          case when XXAR_REVENUE_RECOGNITION_DISCO.is_SSYS_900_item(rctl.inventory_item_id)=1 then
       trunc(to_date(rctl.attribute12, 'YYYY/MM/DD HH24:MI:SS'))
       else
       trunc(ol.actual_shipment_date)
       end
       else
       trunc(to_date(cii.attribute7, 'YYYY/MM/DD HH24:MI:SS'))
       end) coi_date,
       trunc(cii.install_date) install_warranty_date,
       trunc(nvl(ol.actual_shipment_date, rctl.sales_order_date)) ship_or_order_date,
       msi.segment1 item,
       gcc_item.segment5 item_pl,
       nvl(rctl.translated_description, rctl.description) description,
       mut.serial_number,
       nvl(rctl.quantity_invoiced, rctl.quantity_credited) invoice_line_quantity,
       rctl.uom_code,
       rctlgd.amount *
           nvl((decode(mut.transaction_id, null, -mmt.primary_quantity, -sign(mmt.primary_quantity))/
              nvl(rctl.quantity_invoiced, rctl.quantity_credited)),1) entered_rev_amount, --base allocation = invoice qty as the amount is from distribution
                                                                                          --and the spliting may be from mmt or mut.
                                                                                          --on credit quantity could be null
       rct.invoice_currency_code inv_curr,
       rctlgd.acctd_amount *
       nvl((decode(mut.transaction_id, null, -mmt.primary_quantity, -sign(mmt.primary_quantity))/
              nvl(rctl.quantity_invoiced, rctl.quantity_credited)),1) accounted_rev_amount,
       null accounted_cogs_amount,
       g_ledg.currency_code ledger_curr,
       (decode(g_ledg.currency_code,
               'USD',
               rctlgd.acctd_amount,
               decode(rct.invoice_currency_code,
                      'USD',
                      rctlgd.amount,
                      (rctlgd.acctd_amount *
                      gl_currency_api.get_closest_rate( /*from*/g_ledg.currency_code, /*to*/
                                                        'USD', /*date*/
                                                        nvl(rct.exchange_date,
                                                            rct.trx_date),
                                                        'Corporate',
                                                        10)))) *
       nvl((decode(mut.transaction_id, null, -mmt.primary_quantity, -sign(mmt.primary_quantity))/
              nvl(rctl.quantity_invoiced, rctl.quantity_credited)),1)) USD_rev_amount,
       null USD_cogs_amount,
       null USD_IL_cogs_amount,
       (decode(rct.invoice_currency_code,
               'ILS',
               rctlgd.amount,
               (rctlgd.acctd_amount *
               gl_currency_api.get_closest_rate( /*from*/g_ledg.currency_code, /*to*/
                                                 'ILS', /*date*/
                                                 nvl(rct.exchange_date,
                                                     rct.trx_date),
                                                 'Corporate',
                                                 10))) *
       nvl((decode(mut.transaction_id, null, -mmt.primary_quantity, -sign(mmt.primary_quantity))/
              nvl(rctl.quantity_invoiced, rctl.quantity_credited)),1)) ILS_rev_amount,
       null ILS_cogs_amount,
       rctl.attribute10 average_discount_percent,
       gcc.segment1 comp_seg,
       gcc.segment2 depart_seg,
       gcc.segment3 account_seg,
       gcc.segment4 sub_acc_seg,
       gcc.segment5 pl_seg,
       xxgl_utils_pkg.replace_cc_segment(rctlgd.cust_trx_line_gl_dist_id,'SEGMENT6')/*gcc.segment6*/ loc_seg,
       gcc.segment7 ic_seg,
       gcc.segment8 proj_seg,
       gcc.segment9 futur_seg,
       rctl.customer_trx_line_id inv_line_id,
       (select sum(rctlgd_clr.amount)
          from ra_cust_trx_line_gl_dist_all rctlgd_clr,
               ra_customer_trx_lines_all    rctl_clr,
               gl_code_combinations         gcc_clr
         where rctlgd_clr.customer_trx_line_id =
               rctl_clr.customer_trx_line_id
           and rctl_clr.sales_order = rctl.sales_order
           and rctl_clr.org_id = rctl.org_id
           and rctlgd_clr.code_combination_id = gcc_clr.code_combination_id
           and rctlgd_clr.account_class in ('REV', 'SUSPENSE')
           and rctlgd_clr.account_set_flag = 'N'
           and gcc_clr.segment3 = rads.constant
           and rctlgd_clr.gl_date <= gp_end.end_date) clearing_total_SO_amount, --For Control, sum of clearing sales account for whole Sale Order. generally, the sum should be 0.
       round(xxar_revenue_recognition_disco.get_invoice_balance(rct.customer_trx_id,gp_end.end_date,'A'),2) accounted_Invoice_Balance,
       round(decode(g_ledg.currency_code,
               'USD',
               xxar_revenue_recognition_disco.get_invoice_balance(rct.customer_trx_id,gp_end.end_date,'A'),
               decode(rct.invoice_currency_code,
                      'USD',
                      xxar_revenue_recognition_disco.get_invoice_balance(rct.customer_trx_id,gp_end.end_date),
                      (xxar_revenue_recognition_disco.get_invoice_balance(rct.customer_trx_id,gp_end.end_date,'A') *
                      gl_currency_api.get_closest_rate( /*from*/g_ledg.currency_code, /*to*/
                                                        'USD', /*date*/
                                                        nvl(rct.exchange_date,
                                                            rct.trx_date),
                                                        'Corporate',
                                                        10)))),2) usd_Invoice_Balance,
       round(decode(rct.invoice_currency_code,
                      'ILS',
                      xxar_revenue_recognition_disco.get_invoice_balance(rct.customer_trx_id,gp_end.end_date),
                      (xxar_revenue_recognition_disco.get_invoice_balance(rct.customer_trx_id,gp_end.end_date,'A') *
                      gl_currency_api.get_closest_rate( /*from*/g_ledg.currency_code, /*to*/
                                                        'ILS', /*date*/
                                                        nvl(rct.exchange_date,
                                                            rct.trx_date),
                                                        'Corporate',
                                                        10))),2) ils_Invoice_Balance,
       null gl_currency,
       null gl_period_name,
       null gl_entered_rev_amount,
       null gl_accounted_rev_amount,
       null gl_entered_cogs_amount,
       null gl_accounted_cogs_amount,
       xxar_revenue_recognition_disco.get_set_warranty_data(cii.serial_number,hca.cust_account_id) warranty_start_date,
       xxar_revenue_recognition_disco.get_warranty_service warranty_type,
       xxar_revenue_recognition_disco.get_warranty_end_date warranty_end_date,
       gp_start.period_name period_start, --for discoverer parametrer
       gp_end.period_name period_end, --for dicoverer parameter
       gp_end.end_date period_end_date,
       ffv.flex_value manual_rev_account, --for discoverer parameter
       null manual_cogs_account, --for discoverer parameter
       --14/08/2011    Ofer Suad add Sale Order Channel
       (select oh.attribute7
       from oe_order_headers_all oh
       where oh.header_id=ol.header_id) Order_Channel,
       --- Ofer Suad Dec-2012 add Freight_Terms and  Sys_Booking_Date
     (select vl.MEANING
    from oe_order_lines_all ol, oe_order_headers_all oh,FND_LOOKUP_VALUES_VL vl
   where ol.line_id = rctl.interface_line_attribute6
     and oh.header_id = ol.header_id
     and rctl.interface_line_context in ('ORDER ENTRY', 'INTERCOMPANY')
     and rctl.sales_order_line is not null
     and vl.LOOKUP_TYPE = 'FREIGHT_TERMS'
   and vl.VIEW_APPLICATION_ID = 660
   And vl.LOOKUP_CODE =oh.freight_terms_code) Freight_Terms,
               (select to_date(oh.attribute2,'yyyy/mm/dd hh24:mi:ss')
       from oe_order_headers_all oh
       where oh.header_id=ol.header_id) SYS_Booking_Date
  from ra_customer_trx_all rct,
       ra_customer_trx_lines_all rctl,
       ra_cust_trx_line_gl_dist rctlgd,
       ra_account_defaults_all rad,
       ra_account_default_segments rads,
       mtl_system_items_b msi,
       oe_order_lines_all ol,
       ra_cust_trx_types_all rctt,
       ra_batch_sources_all rbs,
       hz_cust_accounts hca,
       hz_parties hp,
       ra_salesreps rs,
       hr_operating_units ho,
       gl_code_combinations gcc,
       gl_ledgers g_ledg,
       mtl_material_transactions mmt,
       mtl_unit_transactions mut,
       csi_item_instances cii,
       gl_periods gp_start,
       gl_periods gp_end,
       fnd_flex_values ffv, --for disco parameter,
       gl_code_combinations gcc_item
 where rctlgd.customer_trx_line_id = rctl.customer_trx_line_id
   and rctl.customer_trx_id = rct.customer_trx_id
   and rct.org_id = rad.org_id
   and rad.gl_default_id = rads.gl_default_id
   and rctl.inventory_item_id = msi.inventory_item_id(+)
   and msi.organization_id(+) = 91--xxinv_utils_pkg.get_master_organization_id
   and rctl.interface_line_attribute6 = ol.line_id(+)
   and rct.cust_trx_type_id = rctt.cust_trx_type_id
   and rct.org_id = rctt.org_id
   and rct.batch_source_id = rbs.batch_source_id
   and rct.org_id = rbs.org_id
   and rct.bill_to_customer_id = hca.cust_account_id
   and hca.party_id = hp.party_id
   and rct.primary_salesrep_id = rs.salesrep_id(+)
   and rct.org_id = rs.org_id(+)
   and rct.org_id = ho.organization_id
   and rctlgd.code_combination_id = gcc.code_combination_id
   and rct.set_of_books_id = g_ledg.ledger_id
   and rad.type = 'SUSPENSE'
   and rads.segment = 'SEGMENT3'
   and rctlgd.account_set_flag = 'N'
   and rctlgd.account_class = 'REV'
   and gcc.segment3 != rads.constant --without clearing account
   and (substr(gcc_item.segment5, 1, 1) in('1','2') or gcc_item.segment5 = '820')  --only systems and installation
   and nvl(rctl.interface_line_context, 'ORDER ENTRY') = 'ORDER ENTRY' --only Manual or Order Entry Sources
   and rctl.line_type = 'LINE'
   ----and rctl.quantity_invoiced is not null --non rma
   and ((rctt.attribute5 = 'Y') --only initial Transaction Types (Standard, Trade In)
       or exists (select 1
                    from ra_cust_trx_types_all rctt2
                   where rctt2.org_id = rctt.org_id
                     and rctt2.credit_memo_type_id = rctt.cust_trx_type_id
                     and rctt2.attribute5 = 'Y')) --only credits of initial Transaction Types (Standard, Trade In)
   and mmt.transaction_source_type_id(+) = 2
   and mmt.transaction_type_id(+) = 33
   and mmt.transaction_action_id(+) = 1
   and rctl.interface_line_attribute6 = mmt.source_line_id(+)
   and rctl.interface_line_attribute3 = mmt.shipment_number(+)
   and mmt.transaction_id = mut.transaction_id(+)
   and mut.serial_number = cii.serial_number(+)
   and mut.inventory_item_id=cii.inventory_item_id(+)
   and rctlgd.gl_date between gp_start.start_date and gp_end.end_date
   and gp_start.period_set_name = gp_end.period_set_name
   and gp_start.period_set_name = 'OBJET_CALENDAR'
   and gp_start.adjustment_period_flag = gp_end.adjustment_period_flag
   and gp_start.adjustment_period_flag = 'N'
   and ffv.flex_value_set_id = 1013887 --gl account value set
    and not exists
        (select 1 from mtl_material_transactions mmt2,rcv_transactions rt, hr_organization_information hoi2
         where mmt2.rcv_transaction_id = rt.transaction_id
         and to_char(mmt2.trx_source_line_id) = rctl.interface_line_attribute6
         and rt.oe_order_line_id = to_number(rctl.interface_line_attribute6)
         and hoi2.organization_id = mmt2.organization_id
         and hoi2.org_information_context = 'Accounting Information'
         and hoi2.org_information3 = rctl.org_id
         and rctl.interface_line_context = 'ORDER ENTRY'
         and mmt2.transaction_source_type_id = 12
         and mmt2.transaction_type_id = 15
         and mmt2.transaction_action_id = 27)
   and rctlgd.cust_trx_line_gl_dist_id not in
       (select jl.attribute10 dist_or_line_id --for revenue ar dist id and for cost ar line id
          from gl_je_headers        jh,
               gl_je_lines          jl,
               gl_code_combinations gcc_gl,
               gl_periods           gp,
               ar_system_parameters asp
         where jh.je_header_id = jl.je_header_id
           and jl.code_combination_id = gcc_gl.code_combination_id
           and nvl(jh.accrual_rev_period_name, jh.period_name) !=
               jh.period_name
           and jh.je_category = '21' --XX Deferred Revenue/Cogs
           and jh.status = 'P'
           and jh.actual_flag = 'A'
           and gcc_gl.segment3 = ffv.flex_value
           and jh.ledger_id = rctlgd.set_of_books_id
           and gp.adjustment_period_flag = 'N'
           and gp.period_set_name = 'OBJET_CALENDAR'
           and gp.period_name = jh.period_name
           and gp.start_date = xxar_revenue_recognition_disco.get_revrecog_glstrt_date(jh.ledger_id)
           and asp.set_of_books_id = jh.ledger_id)
   and xxar_revenue_recognition_disco.set_revrecog_glstrt_date(ffv.flex_value,null,gp_end.end_date)=1
   and gcc_item.code_combination_id=msi.cost_of_sales_account
union all --revenue while cost is rma credit
select decode(rctl.quantity_invoiced, null, 'REVENUE CM', 'REVENUE') Meaning,
       rctlgd.cust_trx_line_gl_dist_id,
       ho.short_code Operating_Unit,
       rct.org_id,
       rbs.name invoice_source,
       rctt.name invoice_trx_type,
       rctl.interface_line_attribute2 order_type,
       rct.trx_number invoice_number,
       nvl(rctl.interface_line_attribute1, /*rct.interface_header_attribute1*/rct.ct_reference) order_number,
       xxar_revenue_recognition_disco.get_applied_invoice_info(rct.customer_trx_id) applied_to_invoice_ref,
       rct.trx_date invoice_date,
       hp.party_name bill_to_customer,
       hca.account_number bill_to_cust_account_number,
       rs.name sale_person_name,
       hca.sales_channel_code sale_channel,
       rctl.line_number invoice_line,
       rctlgd.gl_date,
       (case when XXAR_REVENUE_RECOGNITION_DISCO.is_SSYS_item(rctl.inventory_item_id)=1 then
          case when XXAR_REVENUE_RECOGNITION_DISCO.is_SSYS_900_item(rctl.inventory_item_id)=1 then
       trunc(to_date(rctl.attribute12, 'YYYY/MM/DD HH24:MI:SS'))
       else
       trunc(mmt.transaction_date)
       end
       else
       trunc(to_date(cii.attribute7, 'YYYY/MM/DD HH24:MI:SS'))
       end) coi_date,
       trunc(cii.install_date) install_warranty_date,
       trunc(nvl(mmt.transaction_date, rctl.sales_order_date)) ship_or_order_date,
       msi.segment1 item,
       gcc_item.segment5 item_pl,
       nvl(rctl.translated_description, rctl.description) description,
       mut.serial_number,
       nvl(rctl.quantity_invoiced, rctl.quantity_credited) invoice_line_quantity,
       rctl.uom_code,
       rctlgd.amount *
       nvl((decode(mut.transaction_id, null, -mmt.primary_quantity, -sign(mmt.primary_quantity))/
                   nvl(rctl.quantity_invoiced, rctl.quantity_credited)),1) entered_rev_amount, --on credit quantity could be null
       rct.invoice_currency_code inv_curr,
       rctlgd.acctd_amount *
       nvl((decode(mut.transaction_id, null, -mmt.primary_quantity, -sign(mmt.primary_quantity))/
                   nvl(rctl.quantity_invoiced, rctl.quantity_credited)),1) accounted_rev_amount,
       null accounted_cogs_amount,
       g_ledg.currency_code ledger_curr,
       (decode(g_ledg.currency_code,
              'USD',
              rctlgd.acctd_amount,
              decode(rct.invoice_currency_code,
                     'USD',
                     rctlgd.amount,
                     (rctlgd.acctd_amount *
                           gl_currency_api.get_closest_rate( /*from*/g_ledg.currency_code, /*to*/
                                                            'USD', /*date*/
                                                            nvl(rct.exchange_date,
                                                                rct.trx_date),
                                                            'Corporate',
                                                            10)
                           ))) *
       nvl((decode(mut.transaction_id, null, -mmt.primary_quantity, -sign(mmt.primary_quantity))/
                   nvl(rctl.quantity_invoiced, rctl.quantity_credited)),1)) USD_rev_amount,
       null USD_cogs_amount,
       null USD_IL_cogs_amount,
       (decode(rct.invoice_currency_code,
              'ILS',
              rctlgd.amount,
              (rctlgd.acctd_amount *
                    gl_currency_api.get_closest_rate( /*from*/g_ledg.currency_code, /*to*/
                                                     'ILS', /*date*/
                                                     nvl(rct.exchange_date,
                                                         rct.trx_date),
                                                     'Corporate',
                                                     10)
                    )) *
       nvl((decode(mut.transaction_id, null, -mmt.primary_quantity, -sign(mmt.primary_quantity))/
                   nvl(rctl.quantity_invoiced, rctl.quantity_credited)),1)) ILS_rev_amount,
       null ILS_cogs_amount,
       rctl.attribute10          average_discount,
       gcc.segment1 comp_seg,
       gcc.segment2 depart_seg,
       gcc.segment3 account_seg,
       gcc.segment4 sub_acc_seg,
       gcc.segment5 pl_seg,
       xxgl_utils_pkg.replace_cc_segment(rctlgd.cust_trx_line_gl_dist_id,'SEGMENT6')/*gcc.segment6*/ loc_seg,
       gcc.segment7 ic_seg,
       gcc.segment8 proj_seg,
       gcc.segment9 futur_seg,
       rctl.customer_trx_line_id inv_line_id,
       null total_clearing_account,
       round(xxar_revenue_recognition_disco.get_invoice_balance(rct.customer_trx_id,gp_end.end_date,'A'),2) accounted_Invoice_Balance,
       round(decode(g_ledg.currency_code,
               'USD',
               xxar_revenue_recognition_disco.get_invoice_balance(rct.customer_trx_id,gp_end.end_date,'A'),
               decode(rct.invoice_currency_code,
                      'USD',
                      xxar_revenue_recognition_disco.get_invoice_balance(rct.customer_trx_id,gp_end.end_date),
                      (xxar_revenue_recognition_disco.get_invoice_balance(rct.customer_trx_id,gp_end.end_date,'A') *
                      gl_currency_api.get_closest_rate( /*from*/g_ledg.currency_code, /*to*/
                                                        'USD', /*date*/
                                                        nvl(rct.exchange_date,
                                                            rct.trx_date),
                                                        'Corporate',
                                                        10)))),2) usd_Invoice_Balance,
       round(decode(rct.invoice_currency_code,
                      'ILS',
                      xxar_revenue_recognition_disco.get_invoice_balance(rct.customer_trx_id,gp_end.end_date),
                      (xxar_revenue_recognition_disco.get_invoice_balance(rct.customer_trx_id,gp_end.end_date,'A') *
                      gl_currency_api.get_closest_rate( /*from*/g_ledg.currency_code, /*to*/
                                                        'ILS', /*date*/
                                                        nvl(rct.exchange_date,
                                                            rct.trx_date),
                                                        'Corporate',
                                                        10))),2) ils_Invoice_Balance,
       null gl_currency,
       null gl_period_name,
       null gl_entered_rev_amount,
       null gl_accounted_rev_amount,
       null gl_entered_cogs_amount,
       null gl_accounted_cogs_amount,
       xxar_revenue_recognition_disco.get_set_warranty_data(cii.serial_number,hca.cust_account_id) warranty_start_date,
       xxar_revenue_recognition_disco.get_warranty_service warranty_type,
       xxar_revenue_recognition_disco.get_warranty_end_date warranty_end_date,
       gp_start.period_name period_start, --for discoverer parametrer
       gp_end.period_name period_end, --for dicoverer parameter
       gp_end.end_date period_end_date,
       ffv.flex_value manual_rev_account, --for discoverer parameter
       null            manual_cogs_account, --for discoverer parameter,
        --14/08/2011    Ofer Suad add Sale Order Channel
       (select oh.attribute7
       from oe_order_headers_all oh,oe_order_lines_all ol
       where ol.header_id=oh.header_id
        and rctl.interface_line_attribute6 = ol.line_id
        and rctl.sales_order_line is not null  ) Order_Channel,
          --- Ofer Suad Dec-2012 add Freight_Terms and  Sys_Booking_Date
     (select vl.MEANING
    from oe_order_lines_all ol, oe_order_headers_all oh,FND_LOOKUP_VALUES_VL vl
   where ol.line_id = rctl.interface_line_attribute6
     and oh.header_id = ol.header_id
     and rctl.interface_line_context in ('ORDER ENTRY', 'INTERCOMPANY')
     and rctl.sales_order_line is not null
     and vl.LOOKUP_TYPE = 'FREIGHT_TERMS'
   and vl.VIEW_APPLICATION_ID = 660
   And vl.LOOKUP_CODE =oh.freight_terms_code) Freight_Terms,
         (select to_date(oh.attribute2,'yyyy/mm/dd hh24:mi:ss')
       from oe_order_headers_all oh,oe_order_lines_all ol
       where ol.header_id=oh.header_id
        and rctl.interface_line_attribute6 = ol.line_id
        and rctl.sales_order_line is not null  ) SYS_Booking_Date
  from ra_customer_trx_all rct,
       ra_customer_trx_lines_all rctl,
       ra_cust_trx_line_gl_dist rctlgd,
       ra_account_defaults_all rad,
       ra_account_default_segments rads,
       mtl_system_items_b msi,
       ra_cust_trx_types_all rctt,
       ra_batch_sources_all rbs,
       hz_cust_accounts hca,
       hz_parties hp,
       ra_salesreps rs,
       hr_operating_units ho,
       gl_code_combinations gcc,
       gl_ledgers g_ledg,
       mtl_material_transactions mmt,
       mtl_unit_transactions mut,
       csi_item_instances cii,
       gl_periods gp_start,
       gl_periods gp_end,
       fnd_flex_values ffv, --for disco parameter
       gl_code_combinations gcc_item
 where rctlgd.customer_trx_line_id = rctl.customer_trx_line_id
   and rctl.customer_trx_id = rct.customer_trx_id
   and rct.org_id = rad.org_id
   and rad.gl_default_id = rads.gl_default_id
   and rctl.inventory_item_id = msi.inventory_item_id(+)
   and msi.organization_id(+) = 91--xxinv_utils_pkg.get_master_organization_id
   and rct.cust_trx_type_id = rctt.cust_trx_type_id
   and rct.org_id = rctt.org_id
   and rct.batch_source_id = rbs.batch_source_id
   and rct.org_id = rbs.org_id
   and rct.bill_to_customer_id = hca.cust_account_id
   and hca.party_id = hp.party_id
   and rct.primary_salesrep_id = rs.salesrep_id(+)
   and rct.org_id = rs.org_id(+)
   and rct.org_id = ho.organization_id
   and rctlgd.code_combination_id = gcc.code_combination_id
   and rct.set_of_books_id = g_ledg.ledger_id
   and rad.type = 'SUSPENSE'
   and rads.segment = 'SEGMENT3'
   and rctlgd.account_set_flag = 'N'
   and rctlgd.account_class = 'REV'
   and gcc.segment3 != rads.constant --without clearing account
   and (substr(gcc_item.segment5, 1, 1) in('1','2') or gcc_item.segment5 = '820') --only systems and installation
   and rctl.interface_line_context = 'ORDER ENTRY' --only Order Entry Sources
   and rctl.line_type = 'LINE'
   ----and rctl.quantity_invoiced is null --rma
   and ((rctt.attribute5 = 'Y') --only initial Transaction Types (Standard, Trade In)
       or exists (select 1
                    from ra_cust_trx_types_all rctt2
                   where rctt2.org_id = rctt.org_id
                     and rctt2.credit_memo_type_id = rctt.cust_trx_type_id
                     and rctt2.attribute5 = 'Y')) --only credits of initial Transaction Types (Standard, Trade In)
   and mmt.transaction_source_type_id = 12
   and mmt.transaction_type_id = 15
   and mmt.transaction_action_id = 27
   and rctl.interface_line_attribute6 = mmt.trx_source_line_id
    and exists (select 1 from rcv_transactions rt
               where rt.oe_order_line_id = to_number(rctl.interface_line_attribute6)
                 and rt.transaction_id = mmt.rcv_transaction_id)
   and mmt.transaction_id = mut.transaction_id(+)
   and mut.serial_number = cii.serial_number(+)
   and mut.inventory_item_id=cii.inventory_item_id(+)
   and rctlgd.gl_date between gp_start.start_date and gp_end.end_date
   and gp_start.period_set_name = gp_end.period_set_name
   and gp_start.period_set_name = 'OBJET_CALENDAR'
   and gp_start.adjustment_period_flag = gp_end.adjustment_period_flag
   and gp_start.adjustment_period_flag = 'N'
   and ffv.flex_value_set_id = 1013887 --gl account value set
   and rctlgd.cust_trx_line_gl_dist_id not in
       (select jl.attribute10 dist_or_line_id --for revenue ar dist id and for cost ar line id
          from gl_je_headers        jh,
               gl_je_lines          jl,
               gl_code_combinations gcc_gl,
               gl_periods           gp,
               ar_system_parameters asp
         where jh.je_header_id = jl.je_header_id
           and jl.code_combination_id = gcc_gl.code_combination_id
           and nvl(jh.accrual_rev_period_name, jh.period_name) !=
               jh.period_name
           and jh.je_category = '21' --XX Deferred Revenue/Cogs
           and jh.status = 'P'
           and jh.actual_flag = 'A'
           and gcc_gl.segment3 = ffv.flex_value
           and jh.ledger_id = rctlgd.set_of_books_id
           and gp.adjustment_period_flag = 'N'
           and gp.period_set_name = 'OBJET_CALENDAR'
           and gp.period_name = jh.period_name
           and gp.start_date = xxar_revenue_recognition_disco.get_revrecog_glstrt_date(jh.ledger_id)
           and asp.set_of_books_id = jh.ledger_id)
   and xxar_revenue_recognition_disco.set_revrecog_glstrt_date(ffv.flex_value,null,gp_end.end_date)=1
   and gcc_item.code_combination_id=msi.cost_of_sales_account
union all
--Cogs not credits
-- daniel Katz Notes:
--1.) accounted cogs could come from material transactions on regular sale or from AP in case of Intercompany sale.
--2.) the evaluation of IL Cogs in USD could come from material transactions on regular sale in IL and from Intercompany process in other
--        operating units OR according to the last known cost in usd from interenal transaction from IL to the Operating Unit
--        before the transaction date (or from 31-AUG-09 if doesn't exist).
--3.) cogs in usd (or ils) is translated from ledger currency on cogs trx date in case the ledger currency is different than USD.
--4.) the difference between 2 cogs in usd above (2' and 3') is the RATAM for deffered cogs.
select 'COST' Meaning,
       null cust_trx_line_gl_dist_id,
       ho.short_code Operating_Unit,
       rct.org_id,
       rbs.name invoice_source,
       rctt.name invoice_trx_type,
       rctl.interface_line_attribute2 order_type,
       rct.trx_number invoice_number,
       nvl(rctl.interface_line_attribute1, /*rct.interface_header_attribute1*/rct.ct_reference) order_number,
       xxar_revenue_recognition_disco.get_applied_invoice_info(rct.customer_trx_id) applied_to_inv_credit_ref,
       rct.trx_date invoice_date,
       hp.party_name bill_to_customer,
       hca.account_number bill_to_cust_account_number,
       rs.name sale_person_name,
       hca.sales_channel_code sale_channel,
       rctl.line_number invoice_line,
       trunc(mmt.transaction_date) gl_date,
        (case when XXAR_REVENUE_RECOGNITION_DISCO.is_SSYS_item(rctl.inventory_item_id)=1 then
          case when XXAR_REVENUE_RECOGNITION_DISCO.is_SSYS_900_item(rctl.inventory_item_id)=1 then
       trunc(to_date(rctl.attribute12, 'YYYY/MM/DD HH24:MI:SS'))
       else
       trunc(ol.actual_shipment_date)
       end
       else
       trunc(to_date(cii.attribute7, 'YYYY/MM/DD HH24:MI:SS'))
       end) coi_date,
       trunc(cii.install_date) install_warranty_date,
       trunc(nvl(ol.actual_shipment_date, rctl.sales_order_date)) ship_or_order_date,
       msi.segment1 item,
       gcc_item.segment5 item_pl,
       nvl(rctl.translated_description, rctl.description) description,
       mut.serial_number,
       nvl(rctl.quantity_invoiced, rctl.quantity_credited) invoice_line_quantity,
       rctl.uom_code,
       null entered_rev_amount,
       rct.invoice_currency_code inv_curr,
       null accounted_rev_amount,
       (nvl(-nvl(ail.base_amount, ail.amount),
            decode(hoi.org_information3,ho.organization_id,mmt.primary_quantity * mmt.actual_cost,0)) * --the decode is to be sure it is not intercompany.
                                                                                                   --because in cases the price is 0 there is no ap i/c
                                                                                                   --and cogs should be shown as 0.
       (decode(mut.transaction_id, null, -mmt.primary_quantity, 1)) /
       (-mmt.primary_quantity)) accounted_cogs_amount, --base allocation = mmt qty as the amount is from mmt (or ail in i/c which is same)
                                                       --and the spliting may be from mut.
       g_ledg.currency_code ledger_curr,
       null USD_rev_amount,
       (nvl(-nvl(ail.base_amount, ail.amount),
            decode(hoi.org_information3,ho.organization_id,mmt.primary_quantity * mmt.actual_cost,0)) *
       decode(g_ledg.currency_code,
               'USD',
               1,
               (gl_currency_api.get_closest_rate( /*from*/g_ledg.currency_code, /*to*/
                                                 'USD', /*date*/
                                                 mmt.transaction_date,
                                                 'Corporate',
                                                 10))) *
       (decode(mut.transaction_id, null, -mmt.primary_quantity, 1)) /
       (-mmt.primary_quantity)) USD_cogs_amount,
       decode(fnd_profile.value('XXAR_ENABLE_SECURITY_COGS_REV_RECOG'),'N',(decode(hoi.org_information3,
               '81',
               /*IL cost - regular & subsidiary I/C*/
               mmt.primary_quantity * mmt.actual_cost,
               decode(rctl.org_id,
                      81, /*IL AP cost from I/C Purchasing*/
                      -nvl(ail.base_amount, ail.amount),
                      /*IL last known cost from internal trx or 31-aug-09*/
                      mmt.primary_quantity *
                      xxar_utils_pkg.get_item_last_il_cost_ic_trx(rctl.org_id,
                                                                  mmt.inventory_item_id,
                                                                  mmt.transaction_date))) *
       (decode(mut.transaction_id, null, -mmt.primary_quantity, 1)) /
       (-mmt.primary_quantity)),null) USD_IL_cogs_amount,
       null ILS_rev_amount,
       (nvl(-nvl(ail.base_amount, ail.amount),
            decode(hoi.org_information3,ho.organization_id,mmt.primary_quantity * mmt.actual_cost,0)) *
       decode(g_ledg.currency_code,
               'ILS',
               1,
               (gl_currency_api.get_closest_rate( /*from*/g_ledg.currency_code, /*to*/
                                                 'ILS', /*date*/
                                                 mmt.transaction_date,
                                                 'Corporate',
                                                 10))) *
       (decode(mut.transaction_id, null, -mmt.primary_quantity, 1)) /
       (-mmt.primary_quantity)) ILS_cogs_amount,
       rctl.attribute10 average_discount_percent,
       nvl(gcc_ap.segment1, decode(hoi.org_information3,ho.organization_id, gcc.segment1,null)) comp_seg, --in case of i/c and no AP because price 0-->shows null
       nvl(gcc_ap.segment2, gcc.segment2) depar_seg,
       nvl(gcc_ap.segment3, gcc.segment3) account_seg,
       nvl(gcc_ap.segment4, gcc.segment4) sub_acc_seg,
       nvl(gcc_ap.segment5, gcc.segment5) pl_seg,
       nvl(gcc_ap.segment6, gcc.segment6) loc_seg,
       nvl(gcc_ap.segment7, gcc.segment7) ic_seg,
       nvl(gcc_ap.segment8, gcc.segment8) proj_seg,
       nvl(gcc_ap.segment9, gcc.segment9) futur_seg,
       rctl.customer_trx_line_id inv_line_id,
       null total_clearing_account,
       null accounted_Invoice_Balance,
       null usd_Invoice_Balance,
       null ils_Invoice_Balance,
       null gl_currency,
       null gl_period_name,
       null gl_entered_rev_amount,
       null gl_accounted_rev_amount,
       null gl_entered_cogs_amount,
       null gl_accounted_cogs_amount,
       null warranty_start_date,
       null warranty_type,
       null warranty_end_date,
       gp_start.period_name period_start, --for discoverer parametrer
       gp_end.period_name period_end, --for dicoverer parameter
       gp_end.end_date period_end_date,
       null manual_rev_account, --for discoverer parameter
       ffv.flex_value manual_cogs_account, --for discoverer parameter
        --14/08/2011    Ofer Suad add Sale Order Channel
       (select oh.attribute7
       from oe_order_headers_all oh
       where oh.header_id=ol.header_id) Order_Channel,
         --- Ofer Suad Dec-2012 add Freight_Terms and  Sys_Booking_Date
     (select vl.MEANING
    from oe_order_lines_all ol, oe_order_headers_all oh,FND_LOOKUP_VALUES_VL vl
   where ol.line_id = rctl.interface_line_attribute6
     and oh.header_id = ol.header_id
     and rctl.interface_line_context in ('ORDER ENTRY', 'INTERCOMPANY')
     and rctl.sales_order_line is not null
     and vl.LOOKUP_TYPE = 'FREIGHT_TERMS'
   and vl.VIEW_APPLICATION_ID = 660
   And vl.LOOKUP_CODE =oh.freight_terms_code) Freight_Terms,
       (select to_date(oh.attribute2,'yyyy/mm/dd hh24:mi:ss')
       from oe_order_headers_all oh
       where oh.header_id=ol.header_id) SYS_Booking_Date
  from ra_customer_trx_all rct,
       ra_customer_trx_lines rctl,
       mtl_system_items_b msi,
       oe_order_lines_all ol,
       ra_cust_trx_types_all rctt,
       ra_batch_sources_all rbs,
       hz_cust_accounts hca,
       hz_parties hp,
       ra_salesreps rs,
       hr_operating_units ho,
       gl_code_combinations gcc,
       gl_code_combinations gcc_ap,
       gl_ledgers g_ledg,
       mtl_material_transactions mmt,
       mtl_unit_transactions mut,
       mtl_secondary_inventories msubi,
       csi_item_instances cii,
       ap_invoice_lines_all ail,
       hr_organization_information hoi,
       gl_periods gp_start,
       gl_periods gp_end,
       fnd_flex_values ffv, --for disco parameter
       gl_code_combinations gcc_item
 where rctl.customer_trx_id = rct.customer_trx_id
   and rctl.inventory_item_id = msi.inventory_item_id(+)
   and msi.organization_id(+) = 91--xxinv_utils_pkg.get_master_organization_id
   and rctl.interface_line_attribute6 = ol.line_id(+)
   and rct.cust_trx_type_id = rctt.cust_trx_type_id
   and rct.org_id = rctt.org_id
   and rct.batch_source_id = rbs.batch_source_id
   and rct.org_id = rbs.org_id
   and rct.bill_to_customer_id = hca.cust_account_id
   and hca.party_id = hp.party_id
   and rct.primary_salesrep_id = rs.salesrep_id(+)
   and rct.org_id = rs.org_id(+)
   and rct.org_id = ho.organization_id
   and rct.set_of_books_id = g_ledg.ledger_id
   and rctl.interface_line_context = 'ORDER ENTRY' --only Order Entry Sources
   and rctl.line_type = 'LINE'
   ----and rctl.quantity_invoiced is not null --non rma
   and nvl(mmt.primary_quantity, 0) != 0
   and ((rctt.attribute5 = 'Y') --only initial Transaction Types (Standard, Trade In)
       or exists (select 1
                    from ra_cust_trx_types_all rctt2
                   where rctt2.org_id = rctt.org_id
                     and rctt2.credit_memo_type_id = rctt.cust_trx_type_id
                     and rctt2.attribute5 = 'Y')) --only credits of initial Transaction Types (Standard, Trade In)
   and mmt.transaction_source_type_id = 2
   and mmt.transaction_type_id = 33
   and mmt.transaction_action_id = 1
   and rctl.interface_line_attribute6 = mmt.source_line_id
    and rctl.interface_line_attribute3 = decode(nvl(ol.source_type_code,'NULL'),'EXTERNAL',rctl.interface_line_attribute3,mmt.shipment_number)
   and mmt.distribution_account_id = gcc.code_combination_id
   and mmt.subinventory_code = msubi.secondary_inventory_name
   and mmt.organization_id = msubi.organization_id
   and msubi.asset_inventory =1
   and mmt.transaction_id = mut.transaction_id(+)
   and mut.serial_number = cii.serial_number(+)
   and mut.inventory_item_id=cii.inventory_item_id(+)
   and mmt.transaction_id = ail.reference_2(+)
   and ail.accounting_date(+) between mmt.transaction_date - 1 and
       mmt.transaction_date + 1
   and ail.default_dist_ccid = gcc_ap.code_combination_id(+)
   and mmt.organization_id = hoi.organization_id
   and hoi.org_information_context = 'Accounting Information'
   and gp_start.period_set_name = gp_end.period_set_name
   and gp_start.period_set_name = 'OBJET_CALENDAR'
   and gp_start.adjustment_period_flag = gp_end.adjustment_period_flag
   and gp_start.adjustment_period_flag = 'N'
   and mmt.transaction_date between trunc(gp_start.start_date) and
                       trunc(gp_end.end_date) + 0.99999
   and exists
 (select 1
          from ra_cust_trx_line_gl_dist rctlgd,
               gl_code_combinations         gcc_ar_dist
         where rctlgd.customer_trx_line_id = rctl.customer_trx_line_id
           and rctlgd.code_combination_id = gcc_ar_dist.code_combination_id
           and rctlgd.account_set_flag = 'N'
           and rctlgd.account_class = 'REV'
           and (substr(gcc_item.segment5, 1, 1) in('1','2') or gcc_item.segment5 = '820') --only systems and installation
           --and rctlgd.gl_date between gp_start.start_date and gp_end.end_date
        )
   and ffv.flex_value_set_id = 1013887 --gl account value set
   and rctl.customer_trx_line_id not in
       (select jl.attribute10 dist_or_line_id --for revenue ar dist id and for cost ar line id
          from gl_je_headers        jh,
               gl_je_lines          jl,
               gl_code_combinations gcc_gl,
               gl_periods           gp,
               ar_system_parameters asp
         where jh.je_header_id = jl.je_header_id
           and jl.code_combination_id = gcc_gl.code_combination_id
           and nvl(jh.accrual_rev_period_name, jh.period_name) !=
               jh.period_name
           and jh.je_category = '21' --XX Deferred Revenue/Cogs
           and jh.status = 'P'
           and jh.actual_flag = 'A'
           and gcc_gl.segment3 = ffv.flex_value
           and jh.ledger_id = rctl.set_of_books_id
           and gp.adjustment_period_flag = 'N'
           and gp.period_set_name = 'OBJET_CALENDAR'
           and gp.period_name = jh.period_name
           and gp.start_date = xxar_revenue_recognition_disco.get_revrecog_glstrt_date(jh.ledger_id)
           and asp.set_of_books_id = jh.ledger_id)
   and xxar_revenue_recognition_disco.set_revrecog_glstrt_date(null,ffv.flex_value,gp_end.end_date)=1
   and gcc_item.code_combination_id=msi.cost_of_sales_account
union all
--Cogs credits
select 'COST CM' Meaning,
       null cust_trx_line_gl_dist_id,
       ho.short_code Operating_Unit,
       rct.org_id,
       rbs.name invoice_source,
       rctt.name invoice_trx_type,
       rctl.interface_line_attribute2 order_type,
       rct.trx_number invoice_number,
       nvl(rctl.interface_line_attribute1, /*rct.interface_header_attribute1*/rct.ct_reference) order_number,
       xxar_revenue_recognition_disco.get_applied_invoice_info(rct.customer_trx_id) applied_to_invoice_ref,
       rct.trx_date invoice_date,
       hp.party_name bill_to_customer,
       hca.account_number bill_to_cust_account_number,
       rs.name sale_person_name,
       hca.sales_channel_code sale_channel,
       rctl.line_number invoice_line,
       trunc(mmt.transaction_date) gl_date,
      (case when XXAR_REVENUE_RECOGNITION_DISCO.is_SSYS_item(rctl.inventory_item_id)=1 then
          case when XXAR_REVENUE_RECOGNITION_DISCO.is_SSYS_900_item(rctl.inventory_item_id)=1 then
       trunc(to_date(rctl.attribute12, 'YYYY/MM/DD HH24:MI:SS'))
       else
       trunc(mmt.transaction_date)
       end
       else
       trunc(to_date(cii.attribute7, 'YYYY/MM/DD HH24:MI:SS'))
       end)  coi_date,
       trunc(cii.install_date) install_warranty_date,
       trunc(nvl(mmt.transaction_date, rctl.sales_order_date)) ship_or_order_date,
       msi.segment1 item,
       gcc_item.segment5 item_pl,
       nvl(rctl.translated_description, rctl.description) description,
       mut.serial_number,
       nvl(rctl.quantity_invoiced, rctl.quantity_credited) invoice_line_quantity,
       rctl.uom_code,
       null entered_rev_amount,
       rct.invoice_currency_code inv_curr,
       null accounted_rev_amount,
       (nvl(-nvl(ail.base_amount, ail.amount),
       decode(hoi.org_information3,ho.organization_id,mmt.primary_quantity * mmt.actual_cost,0)) * --the decode is to be sure it is not intercompany.
                                                                                                   --because in cases the price is 0 there is no ap i/c
                                                                                                   --and cogs should be shown as 0.
       (decode(mut.transaction_id, null, -mmt.primary_quantity, -1)) /
       (-mmt.primary_quantity)) accounted_cogs_amount,
       g_ledg.currency_code ledger_curr,
       null USD_rev_amount,
       (nvl(-nvl(ail.base_amount, ail.amount),
            decode(hoi.org_information3,ho.organization_id,mmt.primary_quantity * mmt.actual_cost,0)) *
       decode(g_ledg.currency_code,
               'USD',
               1,
               (gl_currency_api.get_closest_rate( /*from*/g_ledg.currency_code, /*to*/
                                                 'USD', /*date*/
                                                 mmt.transaction_date,
                                                 'Corporate',
                                                 10))) *
       (decode(mut.transaction_id, null, -mmt.primary_quantity, -1)) /
       (-mmt.primary_quantity)) USD_cogs_amount,
       decode(fnd_profile.value('XXAR_ENABLE_SECURITY_COGS_REV_RECOG'),'N',(decode(hoi.org_information3,
               '81',
               /*IL cost - regular & subsidiary I/C*/
               mmt.primary_quantity * mmt.actual_cost,
               decode(rctl.org_id,
                      81, /*IL AP cost from I/C Purchasing*/
                      -nvl(ail.base_amount, ail.amount),
                      /*IL last known cost from internal trx or 31-aug-09*/
                      mmt.primary_quantity *
                      xxar_utils_pkg.get_item_last_il_cost_ic_trx(rctl.org_id,
                                                                  mmt.inventory_item_id,
                                                                  mmt.transaction_date))) *
       (decode(mut.transaction_id, null, -mmt.primary_quantity, -1)) /
       (-mmt.primary_quantity)),null) USD_IL_cogs_amount,
       null ILS_rev_amount,
       (nvl(-nvl(ail.base_amount, ail.amount),
            decode(hoi.org_information3,ho.organization_id,mmt.primary_quantity * mmt.actual_cost,0)) *
       decode(g_ledg.currency_code,
               'ILS',
               1,
               (gl_currency_api.get_closest_rate( /*from*/g_ledg.currency_code, /*to*/
                                                 'ILS', /*date*/
                                                 mmt.transaction_date,
                                                 'Corporate',
                                                 10))) *
       (decode(mut.transaction_id, null, -mmt.primary_quantity, -1)) /
       (-mmt.primary_quantity)) ILS_cogs_amount,
       rctl.attribute10 average_discount_percent,
       nvl(gcc_ap.segment1, decode(hoi.org_information3,ho.organization_id, gcc.segment1,null)) comp_seg,
       nvl(gcc_ap.segment2, gcc.segment2) depar_seg,
       nvl(gcc_ap.segment3, gcc.segment3) account_seg,
       nvl(gcc_ap.segment4, gcc.segment4) sub_acc_seg,
       nvl(gcc_ap.segment5, gcc.segment5) pl_seg,
       nvl(gcc_ap.segment6, gcc.segment6) loc_seg,
       nvl(gcc_ap.segment7, gcc.segment7) ic_seg,
       nvl(gcc_ap.segment8, gcc.segment8) proj_seg,
       nvl(gcc_ap.segment9, gcc.segment9) futur_seg,
       rctl.customer_trx_line_id inv_line_id,
       null total_clearing_account,
       null accounted_Invoice_Balance,
       null usd_Invoice_Balance,
       null ils_Invoice_Balance,
       null gl_currency,
       null gl_period_name,
       null gl_entered_rev_amount,
       null gl_accounted_rev_amount,
       null gl_entered_cogs_amount,
       null gl_accounted_cogs_amount,
       null warranty_start_date,
       null warranty_type,
       null warranty_end_date,
       gp_start.period_name period_start, --for discoverer parametrer
       gp_end.period_name period_end, --for dicoverer parameter
       gp_end.end_date period_end_date,
       null manual_rev_account, --for discoverer parameter
       ffv.flex_value manual_cogs_account, --for discoverer parameter
        --14/08/2011    Ofer Suad add Sale Order Channel
         (select oh.attribute7
       from oe_order_headers_all oh,oe_order_lines_all ol
       where ol.header_id=oh.header_id
        and rctl.interface_line_attribute6 = ol.line_id
        and rctl.sales_order_line is not null  ) Order_Channel,
         --- Ofer Suad Dec-2012 add Freight_Terms and  Sys_Booking_Date
     (select vl.MEANING
    from oe_order_lines_all ol, oe_order_headers_all oh,FND_LOOKUP_VALUES_VL vl
   where ol.line_id = rctl.interface_line_attribute6
     and oh.header_id = ol.header_id
     and rctl.interface_line_context in ('ORDER ENTRY', 'INTERCOMPANY')
     and rctl.sales_order_line is not null
     and vl.LOOKUP_TYPE = 'FREIGHT_TERMS'
   and vl.VIEW_APPLICATION_ID = 660
   And vl.LOOKUP_CODE =oh.freight_terms_code) Freight_Terms,
         (select to_date(oh.attribute2,'yyyy/mm/dd hh24:mi:ss')
       from oe_order_headers_all oh,oe_order_lines_all ol
       where ol.header_id=oh.header_id
        and rctl.interface_line_attribute6 = ol.line_id
        and rctl.sales_order_line is not null  ) SYS_Booking_Date
  from ra_customer_trx_all rct,
       ra_customer_trx_lines rctl,
       mtl_system_items_b msi,
       ra_cust_trx_types_all rctt,
       ra_batch_sources_all rbs,
       hz_cust_accounts hca,
       hz_parties hp,
       ra_salesreps rs,
       hr_operating_units ho,
       gl_code_combinations gcc,
       gl_code_combinations gcc_ap,
       gl_ledgers g_ledg,
       mtl_material_transactions mmt,
       mtl_unit_transactions mut,
       mtl_secondary_inventories msubi,
       csi_item_instances cii,
       ap_invoice_lines_all ail,
       hr_organization_information hoi,
       gl_periods gp_start,
       gl_periods gp_end,
       fnd_flex_values ffv, --for disco parameter
       gl_code_combinations gcc_item
 where rctl.customer_trx_id = rct.customer_trx_id
   and rctl.inventory_item_id = msi.inventory_item_id(+)
   and msi.organization_id(+) = 91--xxinv_utils_pkg.get_master_organization_id
   and rct.cust_trx_type_id = rctt.cust_trx_type_id
   and rct.org_id = rctt.org_id
   and rct.batch_source_id = rbs.batch_source_id
   and rct.org_id = rbs.org_id
   and rct.bill_to_customer_id = hca.cust_account_id
   and hca.party_id = hp.party_id
   and rct.primary_salesrep_id = rs.salesrep_id(+)
   and rct.org_id = rs.org_id(+)
   and rct.org_id = ho.organization_id
   and rct.set_of_books_id = g_ledg.ledger_id
   and rctl.interface_line_context = 'ORDER ENTRY' --only Order Entry Sources
   and rctl.line_type = 'LINE'
   ----and rctl.quantity_invoiced is null --rma
   and nvl(mmt.primary_quantity, 0) != 0
   and ((rctt.attribute5 = 'Y') --only initial Transaction Types (Standard, Trade In)
       or exists (select 1
                    from ra_cust_trx_types_all rctt2
                   where rctt2.org_id = rctt.org_id
                     and rctt2.credit_memo_type_id = rctt.cust_trx_type_id
                     and rctt2.attribute5 = 'Y')) --only credits of initial Transaction Types (Standard, Trade In)
   and mmt.transaction_source_type_id = 12
   and mmt.transaction_type_id = 15
   and mmt.transaction_action_id = 27
   and rctl.interface_line_attribute6 = mmt.trx_source_line_id
   and mmt.distribution_account_id = gcc.code_combination_id
   and mmt.subinventory_code = msubi.secondary_inventory_name
   and mmt.organization_id = msubi.organization_id
   and msubi.asset_inventory =1
   and mmt.transaction_id = mut.transaction_id(+)
   and mut.serial_number = cii.serial_number(+)
   and mut.inventory_item_id=cii.inventory_item_id(+)
   and mmt.transaction_id = ail.reference_2(+)
   and ail.accounting_date(+) between mmt.transaction_date - 1 and
       mmt.transaction_date + 1
   and ail.default_dist_ccid = gcc_ap.code_combination_id(+)
   and mmt.organization_id = hoi.organization_id
   and hoi.org_information_context = 'Accounting Information'
   and gp_start.period_set_name = gp_end.period_set_name
   and gp_start.period_set_name = 'OBJET_CALENDAR'
   and gp_start.adjustment_period_flag = gp_end.adjustment_period_flag
   and gp_start.adjustment_period_flag = 'N'
   and mmt.transaction_date between trunc(gp_start.start_date) and
                       trunc(gp_end.end_date) + 0.99999
   and exists
 (select 1
          from ra_cust_trx_line_gl_dist rctlgd,
               gl_code_combinations         gcc_ar_dist
         where rctlgd.customer_trx_line_id = rctl.customer_trx_line_id
           and rctlgd.code_combination_id = gcc_ar_dist.code_combination_id
           and rctlgd.account_set_flag = 'N'
           and rctlgd.account_class = 'REV'
           and (substr(gcc_item.segment5, 1, 1) in('1','2') or gcc_item.segment5 = '820')  --only systems and installation
           --and rctlgd.gl_date between gp_start.start_date and gp_end.end_date
        )
   and ffv.flex_value_set_id = 1013887 --gl account value set
   and rctl.customer_trx_line_id not in
       (select jl.attribute10 dist_or_line_id --for revenue ar dist id and for cost ar line id
          from gl_je_headers        jh,
               gl_je_lines          jl,
               gl_code_combinations gcc_gl,
               gl_periods           gp,
               ar_system_parameters asp
         where jh.je_header_id = jl.je_header_id
           and jl.code_combination_id = gcc_gl.code_combination_id
           and nvl(jh.accrual_rev_period_name, jh.period_name) !=
               jh.period_name
           and jh.je_category = '21' --XX Deferred Revenue/Cogs
           and jh.status = 'P'
           and jh.actual_flag = 'A'
           and gcc_gl.segment3 = ffv.flex_value
           and jh.ledger_id = rctl.set_of_books_id
           and gp.adjustment_period_flag = 'N'
           and gp.period_set_name = 'OBJET_CALENDAR'
           and gp.period_name = jh.period_name
           and gp.start_date = xxar_revenue_recognition_disco.get_revrecog_glstrt_date(jh.ledger_id)
           and asp.set_of_books_id = jh.ledger_id)
   and xxar_revenue_recognition_disco.set_revrecog_glstrt_date(null,ffv.flex_value,gp_end.end_date)=1
   and gcc_item.code_combination_id=msi.cost_of_sales_account
union all
--Revenue while cost is not rma  - GL
select decode(rctl.quantity_invoiced, null, 'REVENUE CM', 'REVENUE') Meaning,
       rctlgd.cust_trx_line_gl_dist_id,
       ho.short_code Operating_Unit,
       rct.org_id,
       rbs.name invoice_source,
       rctt.name invoice_trx_type,
       rctl.interface_line_attribute2 order_type,
       rct.trx_number invoice_number,
       nvl(rctl.interface_line_attribute1, /*rct.interface_header_attribute1*/rct.ct_reference) order_number,
       xxar_revenue_recognition_disco.get_applied_invoice_info(rct.customer_trx_id) applied_to_inv_credit_ref,
       rct.trx_date invoice_date,
       hp.party_name bill_to_customer,
       hca.account_number bill_to_cust_account_number,
       rs.name sale_person_name,
       hca.sales_channel_code sale_channel,
       rctl.line_number invoice_line,
       rctlgd.gl_date,
        (case when XXAR_REVENUE_RECOGNITION_DISCO.is_SSYS_item(rctl.inventory_item_id)=1 then
          case when XXAR_REVENUE_RECOGNITION_DISCO.is_SSYS_900_item(rctl.inventory_item_id)=1 then
       trunc(to_date(rctl.attribute12, 'YYYY/MM/DD HH24:MI:SS'))
       else
       trunc(ol.actual_shipment_date)
       end
       else
       trunc(to_date(cii.attribute7, 'YYYY/MM/DD HH24:MI:SS'))
       end) coi_date,
       trunc(cii.install_date) install_warranty_date,
       trunc(nvl(ol.actual_shipment_date, rctl.sales_order_date)) ship_or_order_date,
       msi.segment1 item,
       gcc_item.segment5 item_pl,
       nvl(rctl.translated_description, rctl.description) description,
       mut.serial_number,
       nvl(rctl.quantity_invoiced, rctl.quantity_credited) invoice_line_quantity,
       rctl.uom_code,
       rctlgd.amount *
       nvl((decode(mut.transaction_id, null, -mmt.primary_quantity, -sign(mmt.primary_quantity))/
              nvl(rctl.quantity_invoiced, rctl.quantity_credited)),1) entered_rev_amount,
       rct.invoice_currency_code inv_curr,
       rctlgd.acctd_amount *
       nvl((decode(mut.transaction_id, null, -mmt.primary_quantity, -sign(mmt.primary_quantity))/
              nvl(rctl.quantity_invoiced, rctl.quantity_credited)),1) accounted_rev_amount,
       null accounted_cogs_amount,
       g_ledg.currency_code ledger_curr,
       (decode(g_ledg.currency_code,
               'USD',
               rctlgd.acctd_amount,
               decode(rct.invoice_currency_code,
                      'USD',
                      rctlgd.amount,
                      (rctlgd.acctd_amount *
                      gl_currency_api.get_closest_rate( /*from*/g_ledg.currency_code, /*to*/
                                                        'USD', /*date*/
                                                        nvl(rct.exchange_date,
                                                            rct.trx_date),
                                                        'Corporate',
                                                        10)))) *
       nvl((decode(mut.transaction_id, null, -mmt.primary_quantity, -sign(mmt.primary_quantity))/
              nvl(rctl.quantity_invoiced, rctl.quantity_credited)),1)) USD_rev_amount,
       null USD_cogs_amount,
       null USD_IL_cogs_amount,
       (decode(rct.invoice_currency_code,
               'ILS',
               rctlgd.amount,
               (rctlgd.acctd_amount *
               gl_currency_api.get_closest_rate( /*from*/g_ledg.currency_code, /*to*/
                                                 'ILS', /*date*/
                                                 nvl(rct.exchange_date,
                                                     rct.trx_date),
                                                 'Corporate',
                                                 10))) *
       nvl((decode(mut.transaction_id, null, -mmt.primary_quantity, -sign(mmt.primary_quantity))/
              nvl(rctl.quantity_invoiced, rctl.quantity_credited)),1)) ILS_rev_amount,
       null ILS_cogs_amount,
       rctl.attribute10 average_discount_percent,
       gcc.segment1 comp_seg,
       gcc.segment2 depart_seg,
       gcc.segment3 account_seg,
       gcc.segment4 sub_acc_seg,
       gcc.segment5 pl_seg,
       xxgl_utils_pkg.replace_cc_segment(rctlgd.cust_trx_line_gl_dist_id,'SEGMENT6')/*gcc.segment6*/ loc_seg,
       gcc.segment7 ic_seg,
       gcc.segment8 proj_seg,
       gcc.segment9 futur_seg,
       rctl.customer_trx_line_id inv_line_id,
       (select sum(rctlgd_clr.amount)
          from ra_cust_trx_line_gl_dist_all rctlgd_clr,
               ra_customer_trx_lines_all    rctl_clr,
               gl_code_combinations         gcc_clr
         where rctlgd_clr.customer_trx_line_id =
               rctl_clr.customer_trx_line_id
           and rctl_clr.sales_order = rctl.sales_order
           and rctl_clr.org_id = rctl.org_id
           and rctlgd_clr.code_combination_id = gcc_clr.code_combination_id
           and rctlgd_clr.account_class in ('REV', 'SUSPENSE')
           and rctlgd_clr.account_set_flag = 'N'
           and gcc_clr.segment3 = rads.constant
           and rctlgd_clr.gl_date <= gp_end.end_date) clearing_total_SO_amount, --For Control, sum of clearing sales account for whole Sale Order. generally, the sum should be 0.
       round(xxar_revenue_recognition_disco.get_invoice_balance(rct.customer_trx_id,gp_end.end_date,'A'),2) accounted_Invoice_Balance,
       round(decode(g_ledg.currency_code,
               'USD',
               xxar_revenue_recognition_disco.get_invoice_balance(rct.customer_trx_id,gp_end.end_date,'A'),
               decode(rct.invoice_currency_code,
                      'USD',
                      xxar_revenue_recognition_disco.get_invoice_balance(rct.customer_trx_id,gp_end.end_date),
                      (xxar_revenue_recognition_disco.get_invoice_balance(rct.customer_trx_id,gp_end.end_date,'A') *
                      gl_currency_api.get_closest_rate( /*from*/g_ledg.currency_code, /*to*/
                                                        'USD', /*date*/
                                                        nvl(rct.exchange_date,
                                                            rct.trx_date),
                                                        'Corporate',
                                                        10)))),2) usd_Invoice_Balance,
       round(decode(rct.invoice_currency_code,
                      'ILS',
                      xxar_revenue_recognition_disco.get_invoice_balance(rct.customer_trx_id,gp_end.end_date),
                      (xxar_revenue_recognition_disco.get_invoice_balance(rct.customer_trx_id,gp_end.end_date,'A') *
                      gl_currency_api.get_closest_rate( /*from*/g_ledg.currency_code, /*to*/
                                                        'ILS', /*date*/
                                                        nvl(rct.exchange_date,
                                                            rct.trx_date),
                                                        'Corporate',
                                                        10))),2) ils_Invoice_Balance,
       gl_data.currency gl_currency,
       gl_data.gl_period_name,
       (gl_data.entered_amount *
       nvl((decode(mut.transaction_id, null, -mmt.primary_quantity, -sign(mmt.primary_quantity))/
              nvl(rctl.quantity_invoiced, rctl.quantity_credited)),1)) gl_entered_rev_amount,--base allocation = invoice qty as the amount is from
                                                                                   -- gl according to distribution
                                                                                   --and the spliting may be from mmt or mut.
       (gl_data.accounted_amount *
       nvl((decode(mut.transaction_id, null, -mmt.primary_quantity, -sign(mmt.primary_quantity))/
              nvl(rctl.quantity_invoiced, rctl.quantity_credited)),1)) gl_accounted_rev_amount,
       null gl_entered_cogs_amount,
       null gl_accounted_cogs_amount,
       xxar_revenue_recognition_disco.get_set_warranty_data(cii.serial_number,hca.cust_account_id) warranty_start_date,
       xxar_revenue_recognition_disco.get_warranty_service warranty_type,
       xxar_revenue_recognition_disco.get_warranty_end_date warranty_end_date,
       gp_start.period_name period_start, --for discoverer parametrer
       gp_end.period_name period_end, --for dicoverer parameter
       gp_end.end_date period_end_date,
       gl_data.account manual_rev_account, --for discoverer parameter
       null            manual_cogs_account, --for discoverer parameter,
        --14/08/2011    Ofer Suad add Sale Order Channel
        (select oh.attribute7
       from oe_order_headers_all oh
       where oh.header_id=ol.header_id) Order_Channel,
         --- Ofer Suad Dec-2012 add Freight_Terms and  Sys_Booking_Date
     (select vl.MEANING
    from oe_order_lines_all ol, oe_order_headers_all oh,FND_LOOKUP_VALUES_VL vl
   where ol.line_id = rctl.interface_line_attribute6
     and oh.header_id = ol.header_id
     and rctl.interface_line_context in ('ORDER ENTRY', 'INTERCOMPANY')
     and rctl.sales_order_line is not null
     and vl.LOOKUP_TYPE = 'FREIGHT_TERMS'
   and vl.VIEW_APPLICATION_ID = 660
   And vl.LOOKUP_CODE =oh.freight_terms_code) Freight_Terms,
       (select to_date(oh.attribute2,'yyyy/mm/dd hh24:mi:ss')
       from oe_order_headers_all oh
       where oh.header_id=ol.header_id) SYS_Booking_Date
  from (select gcc_gl.segment3 account, --it is only 1 account (manual rev) according to the parameter
               min(jh.currency_code) currency,
               sum(nvl(jl.entered_cr, 0) - nvl(jl.entered_dr, 0)) entered_amount,
               sum(nvl(jl.accounted_cr, 0) - nvl(jl.accounted_dr, 0)) accounted_amount,
               jl.attribute10 dist_or_line_id, --for revenue ar dist id and for cost ar line id
               gp.period_name gl_period_name, --it is only 1 period according to the function below
               jh.ledger_id
          from gl_je_headers        jh,
               gl_je_lines          jl,
               gl_code_combinations gcc_gl,
               gl_periods           gp,
               ar_system_parameters asp
         where jh.je_header_id = jl.je_header_id
           and jl.code_combination_id = gcc_gl.code_combination_id
           and nvl(jh.accrual_rev_period_name, jh.period_name) !=
               jh.period_name
           and jh.je_category = '21' --XX Deferred Revenue/Cogs
           and jh.status = 'P'
           and jh.actual_flag = 'A'
           and gp.adjustment_period_flag = 'N'
           and gp.period_set_name = 'OBJET_CALENDAR'
           and gp.period_name = jh.period_name
           and gp.start_date = xxar_revenue_recognition_disco.get_revrecog_glstrt_date(jh.ledger_id)
           and asp.set_of_books_id = jh.ledger_id
         group by gcc_gl.segment3, jl.attribute10, gp.period_name, jh.ledger_id) gl_data,
       ra_customer_trx_all rct,
       ra_customer_trx_lines_all rctl,
       ra_cust_trx_line_gl_dist rctlgd,
       ra_account_defaults_all rad,
       ra_account_default_segments rads,
       mtl_system_items_b msi,
       oe_order_lines_all ol,
       ra_cust_trx_types_all rctt,
       ra_batch_sources_all rbs,
       hz_cust_accounts hca,
       hz_parties hp,
       ra_salesreps rs,
       hr_operating_units ho,
       gl_code_combinations gcc,
       gl_ledgers g_ledg,
       mtl_material_transactions mmt,
       mtl_unit_transactions mut,
       csi_item_instances cii,
       gl_periods gp_start,
       gl_periods gp_end,
       gl_code_combinations gcc_item
 where rctlgd.cust_trx_line_gl_dist_id = gl_data.dist_or_line_id --in this case it is ar dist id because it is manual revenue account
   and rctlgd.set_of_books_id = gl_data.ledger_id
   and rctlgd.customer_trx_line_id = rctl.customer_trx_line_id
   and rctl.customer_trx_id = rct.customer_trx_id
   and rct.org_id = rad.org_id
   and rad.gl_default_id = rads.gl_default_id
   and rctl.inventory_item_id = msi.inventory_item_id(+)
   and msi.organization_id(+) = 91--xxinv_utils_pkg.get_master_organization_id
   and rctl.interface_line_attribute6 = ol.line_id(+)
   and rct.cust_trx_type_id = rctt.cust_trx_type_id
   and rct.org_id = rctt.org_id
   and rct.batch_source_id = rbs.batch_source_id
   and rct.org_id = rbs.org_id
   and rct.bill_to_customer_id = hca.cust_account_id
   and hca.party_id = hp.party_id
   and rct.primary_salesrep_id = rs.salesrep_id(+)
   and rct.org_id = rs.org_id(+)
   and rct.org_id = ho.organization_id
   and rctlgd.code_combination_id = gcc.code_combination_id
   and rct.set_of_books_id = g_ledg.ledger_id
   and rad.type = 'SUSPENSE'
   and rads.segment = 'SEGMENT3'
   and rctlgd.account_set_flag = 'N'
   and rctlgd.account_class = 'REV'
   and gcc.segment3 != rads.constant --without clearing account
   and (substr(gcc_item.segment5, 1, 1) in('1','2') or gcc_item.segment5 = '820') --only systems and installation
   and nvl(rctl.interface_line_context, 'ORDER ENTRY') = 'ORDER ENTRY' --only Manual or Order Entry Sources
   and rctl.line_type = 'LINE'
   ----and rctl.quantity_invoiced is not null --non rma
   and ((rctt.attribute5 = 'Y') --only initial Transaction Types (Standard, Trade In)
       or exists (select 1
                    from ra_cust_trx_types_all rctt2
                   where rctt2.org_id = rctt.org_id
                     and rctt2.credit_memo_type_id = rctt.cust_trx_type_id
                     and rctt2.attribute5 = 'Y')) --only credits of initial Transaction Types (Standard, Trade In)
   and mmt.transaction_source_type_id(+) = 2
   and mmt.transaction_type_id(+) = 33
   and mmt.transaction_action_id(+) = 1
   and rctl.interface_line_attribute6 = mmt.source_line_id(+)
   and rctl.interface_line_attribute3 = mmt.shipment_number(+)
   and mmt.transaction_id = mut.transaction_id(+)
   and mut.serial_number = cii.serial_number(+)
   and mut.inventory_item_id=cii.inventory_item_id(+)
   and gp_start.period_set_name = gp_end.period_set_name
   and gp_start.period_set_name = 'OBJET_CALENDAR'
   and gp_start.adjustment_period_flag = gp_end.adjustment_period_flag
   and gp_start.adjustment_period_flag = 'N'
    and not exists
        (select 1 from mtl_material_transactions mmt2,rcv_transactions rt, hr_organization_information hoi2
         where mmt2.rcv_transaction_id = rt.transaction_id
         and to_char(mmt2.trx_source_line_id) = rctl.interface_line_attribute6
         and rt.oe_order_line_id = to_number(rctl.interface_line_attribute6)
         and hoi2.organization_id = mmt2.organization_id
         and hoi2.org_information_context = 'Accounting Information'
         and hoi2.org_information3 = rctl.org_id
         and rctl.interface_line_context = 'ORDER ENTRY'
         and mmt2.transaction_source_type_id = 12
         and mmt2.transaction_type_id = 15
         and mmt2.transaction_action_id = 27)
   and xxar_revenue_recognition_disco.set_revrecog_glstrt_date(gl_data.account,null,gp_end.end_date)=1
   and gcc_item.code_combination_id=msi.cost_of_sales_account
Union all
----revenue while cost is rma credit - GL
select decode(rctl.quantity_invoiced, null, 'REVENUE CM', 'REVENUE') Meaning,
       rctlgd.cust_trx_line_gl_dist_id,
       ho.short_code Operating_Unit,
       rct.org_id,
       rbs.name invoice_source,
       rctt.name invoice_trx_type,
       rctl.interface_line_attribute2 order_type,
       rct.trx_number invoice_number,
       nvl(rctl.interface_line_attribute1, /*rct.interface_header_attribute1*/rct.ct_reference) order_number,
       xxar_revenue_recognition_disco.get_applied_invoice_info(rct.customer_trx_id) applied_to_invoice_ref,
       rct.trx_date invoice_date,
       hp.party_name bill_to_customer,
       hca.account_number bill_to_cust_account_number,
       rs.name sale_person_name,
       hca.sales_channel_code sale_channel,
       rctl.line_number invoice_line,
       rctlgd.gl_date,
       (case when XXAR_REVENUE_RECOGNITION_DISCO.is_SSYS_item(rctl.inventory_item_id)=1 then
          case when XXAR_REVENUE_RECOGNITION_DISCO.is_SSYS_900_item(rctl.inventory_item_id)=1 then
       trunc(to_date(rctl.attribute12, 'YYYY/MM/DD HH24:MI:SS'))
       else
       trunc(mmt.transaction_date)
       end
       else
       trunc(to_date(cii.attribute7, 'YYYY/MM/DD HH24:MI:SS'))
       end) coi_date,
       trunc(cii.install_date) install_warranty_date,
       trunc(nvl(mmt.transaction_date, rctl.sales_order_date)) ship_or_order_date,
       msi.segment1 item,
       gcc_item.segment5 item_pl,
       nvl(rctl.translated_description, rctl.description) description,
       mut.serial_number,
       nvl(rctl.quantity_invoiced, rctl.quantity_credited) invoice_line_quantity,
       rctl.uom_code,
       rctlgd.amount *
       nvl((decode(mut.transaction_id, null, -mmt.primary_quantity, -sign(mmt.primary_quantity))/
                   nvl(rctl.quantity_invoiced, rctl.quantity_credited)),1) entered_rev_amount, --on credit quantity could be null
       rct.invoice_currency_code inv_curr,
       rctlgd.acctd_amount *
       nvl((decode(mut.transaction_id, null, -mmt.primary_quantity, -sign(mmt.primary_quantity))/
                   nvl(rctl.quantity_invoiced, rctl.quantity_credited)),1) accounted_rev_amount,
       null accounted_cogs_amount,
       g_ledg.currency_code ledger_curr,
       (decode(g_ledg.currency_code,
              'USD',
              rctlgd.acctd_amount,
              decode(rct.invoice_currency_code,
                     'USD',
                     rctlgd.amount,
                     (rctlgd.acctd_amount *
                           gl_currency_api.get_closest_rate( /*from*/g_ledg.currency_code, /*to*/
                                                            'USD', /*date*/
                                                            nvl(rct.exchange_date,
                                                                rct.trx_date),
                                                            'Corporate',
                                                            10)
                           ))) *
       nvl((decode(mut.transaction_id, null, -mmt.primary_quantity, -sign(mmt.primary_quantity))/
                   nvl(rctl.quantity_invoiced, rctl.quantity_credited)),1)) USD_rev_amount,
       null USD_cogs_amount,
       null USD_IL_cogs_amount,
       (decode(rct.invoice_currency_code,
              'ILS',
              rctlgd.amount,
              (rctlgd.acctd_amount *
                    gl_currency_api.get_closest_rate( /*from*/g_ledg.currency_code, /*to*/
                                                     'ILS', /*date*/
                                                     nvl(rct.exchange_date,
                                                         rct.trx_date),
                                                     'Corporate',
                                                     10)
                    )) *
       nvl((decode(mut.transaction_id, null, -mmt.primary_quantity, -sign(mmt.primary_quantity))/
                   nvl(rctl.quantity_invoiced, rctl.quantity_credited)),1)) ILS_rev_amount,
       null ILS_cogs_amount,
       rctl.attribute10          average_discount,
       gcc.segment1 comp_seg,
       gcc.segment2 depart_seg,
       gcc.segment3 account_seg,
       gcc.segment4 sub_acc_seg,
       gcc.segment5 pl_seg,
       xxgl_utils_pkg.replace_cc_segment(rctlgd.cust_trx_line_gl_dist_id,'SEGMENT6')/*gcc.segment6*/ loc_seg,
       gcc.segment7 ic_seg,
       gcc.segment8 proj_seg,
       gcc.segment9 futur_seg,
       rctl.customer_trx_line_id inv_line_id,
       null total_clearing_account,
       round(xxar_revenue_recognition_disco.get_invoice_balance(rct.customer_trx_id,gp_end.end_date,'A'),2) accounted_Invoice_Balance,
       round(decode(g_ledg.currency_code,
               'USD',
               xxar_revenue_recognition_disco.get_invoice_balance(rct.customer_trx_id,gp_end.end_date,'A'),
               decode(rct.invoice_currency_code,
                      'USD',
                      xxar_revenue_recognition_disco.get_invoice_balance(rct.customer_trx_id,gp_end.end_date),
                      (xxar_revenue_recognition_disco.get_invoice_balance(rct.customer_trx_id,gp_end.end_date,'A') *
                      gl_currency_api.get_closest_rate( /*from*/g_ledg.currency_code, /*to*/
                                                        'USD', /*date*/
                                                        nvl(rct.exchange_date,
                                                            rct.trx_date),
                                                        'Corporate',
                                                        10)))),2) usd_Invoice_Balance,
       round(decode(rct.invoice_currency_code,
                      'ILS',
                      xxar_revenue_recognition_disco.get_invoice_balance(rct.customer_trx_id,gp_end.end_date),
                      (xxar_revenue_recognition_disco.get_invoice_balance(rct.customer_trx_id,gp_end.end_date,'A') *
                      gl_currency_api.get_closest_rate( /*from*/g_ledg.currency_code, /*to*/
                                                        'ILS', /*date*/
                                                        nvl(rct.exchange_date,
                                                            rct.trx_date),
                                                        'Corporate',
                                                        10))),2) ils_Invoice_Balance,
       gl_data.currency gl_currency,
       gl_data.gl_period_name,
       (gl_data.entered_amount *
       nvl((decode(mut.transaction_id, null, -mmt.primary_quantity, -sign(mmt.primary_quantity))/
                   nvl(rctl.quantity_invoiced, rctl.quantity_credited)),1)) gl_entered_rev_amount,
       (gl_data.accounted_amount *
       nvl((decode(mut.transaction_id, null, -mmt.primary_quantity, -sign(mmt.primary_quantity))/
                   nvl(rctl.quantity_invoiced, rctl.quantity_credited)),1)) gl_accounted_rev_amount,
       null gl_entered_cogs_amount,
       null gl_accounted_cogs_amount,
       xxar_revenue_recognition_disco.get_set_warranty_data(cii.serial_number,hca.cust_account_id) warranty_start_date,
       xxar_revenue_recognition_disco.get_warranty_service warranty_type,
       xxar_revenue_recognition_disco.get_warranty_end_date warranty_end_date,
       gp_start.period_name period_start, --for discoverer parametrer
       gp_end.period_name period_end, --for dicoverer parameter
       gp_end.end_date period_end_date,
       gl_data.account manual_rev_account, --for discoverer parameter
       null            manual_cogs_account, --for discoverer parameter
        --14/08/2011    Ofer Suad add Sale Order Channel
        (select oh.attribute7
       from oe_order_headers_all oh,oe_order_lines_all ol
       where ol.header_id=oh.header_id
        and rctl.interface_line_attribute6 = ol.line_id
        and rctl.sales_order_line is not null  ) Order_Channel,
          --- Ofer Suad Dec-2012 add Freight_Terms and  Sys_Booking_Date
     (select vl.MEANING
    from oe_order_lines_all ol, oe_order_headers_all oh,FND_LOOKUP_VALUES_VL vl
   where ol.line_id = rctl.interface_line_attribute6
     and oh.header_id = ol.header_id
     and rctl.interface_line_context in ('ORDER ENTRY', 'INTERCOMPANY')
     and rctl.sales_order_line is not null
     and vl.LOOKUP_TYPE = 'FREIGHT_TERMS'
   and vl.VIEW_APPLICATION_ID = 660
   And vl.LOOKUP_CODE =oh.freight_terms_code) Freight_Terms,
         (select to_date(oh.attribute2,'yyyy/mm/dd hh24:mi:ss')
       from oe_order_headers_all oh,oe_order_lines_all ol
       where ol.header_id=oh.header_id
        and rctl.interface_line_attribute6 = ol.line_id
        and rctl.sales_order_line is not null  ) SYS_Booking_Date
  from (select gcc_gl.segment3 account, --it is only 1 account (manual rev) according to the parameter
               min(jh.currency_code) currency,
               sum(nvl(jl.entered_cr, 0) - nvl(jl.entered_dr, 0)) entered_amount,
               sum(nvl(jl.accounted_cr, 0) - nvl(jl.accounted_dr, 0)) accounted_amount,
               jl.attribute10 dist_or_line_id, --for revenue ar dist id and for cost ar line id
               gp.period_name gl_period_name, --it is only 1 period according to the function below
               jh.ledger_id
          from gl_je_headers        jh,
               gl_je_lines          jl,
               gl_code_combinations gcc_gl,
               gl_periods           gp,
               ar_system_parameters asp
         where jh.je_header_id = jl.je_header_id
           and jl.code_combination_id = gcc_gl.code_combination_id
           and nvl(jh.accrual_rev_period_name, jh.period_name) !=
               jh.period_name
           and jh.je_category = '21' --XX Deferred Revenue/Cogs
           and jh.status = 'P'
           and jh.actual_flag = 'A'
           and gp.adjustment_period_flag = 'N'
           and gp.period_set_name = 'OBJET_CALENDAR'
           and gp.period_name = jh.period_name
           and gp.start_date = xxar_revenue_recognition_disco.get_revrecog_glstrt_date(jh.ledger_id)
           and asp.set_of_books_id = jh.ledger_id
         group by gcc_gl.segment3, jl.attribute10, gp.period_name,jh.ledger_id) gl_data,
       ra_customer_trx_all rct,
       ra_customer_trx_lines_all rctl,
       ra_cust_trx_line_gl_dist rctlgd,
       ra_account_defaults_all rad,
       ra_account_default_segments rads,
       mtl_system_items_b msi,
       ra_cust_trx_types_all rctt,
       ra_batch_sources_all rbs,
       hz_cust_accounts hca,
       hz_parties hp,
       ra_salesreps rs,
       hr_operating_units ho,
       gl_code_combinations gcc,
       gl_ledgers g_ledg,
       mtl_material_transactions mmt,
       mtl_unit_transactions mut,
       csi_item_instances cii,
       gl_periods gp_start,
       gl_periods gp_end,
       gl_code_combinations gcc_item
 where rctlgd.cust_trx_line_gl_dist_id = gl_data.dist_or_line_id --in this case it is ar dist id because it is manual revenue account
   and rctlgd.set_of_books_id = gl_data.ledger_id
   and rctlgd.customer_trx_line_id = rctl.customer_trx_line_id
   and rctl.customer_trx_id = rct.customer_trx_id
   and rct.org_id = rad.org_id
   and rad.gl_default_id = rads.gl_default_id
   and rctl.inventory_item_id = msi.inventory_item_id(+)
   and msi.organization_id(+) = 91--xxinv_utils_pkg.get_master_organization_id
   and rct.cust_trx_type_id = rctt.cust_trx_type_id
   and rct.org_id = rctt.org_id
   and rct.batch_source_id = rbs.batch_source_id
   and rct.org_id = rbs.org_id
   and rct.bill_to_customer_id = hca.cust_account_id
   and hca.party_id = hp.party_id
   and rct.primary_salesrep_id = rs.salesrep_id(+)
   and rct.org_id = rs.org_id(+)
   and rct.org_id = ho.organization_id
   and rctlgd.code_combination_id = gcc.code_combination_id
   and rct.set_of_books_id = g_ledg.ledger_id
   and rad.type = 'SUSPENSE'
   and rads.segment = 'SEGMENT3'
   and rctlgd.account_set_flag = 'N'
   and rctlgd.account_class = 'REV'
   and gcc.segment3 != rads.constant --without clearing account
   and (substr(gcc_item.segment5, 1, 1) in('1','2') or gcc_item.segment5 = '820') --only systems and installation
   and rctl.interface_line_context = 'ORDER ENTRY' --only Order Entry Sources
   and rctl.line_type = 'LINE'
   ----and rctl.quantity_invoiced is null --rma
   and ((rctt.attribute5 = 'Y') --only initial Transaction Types (Standard, Trade In)
       or exists (select 1
                    from ra_cust_trx_types_all rctt2
                   where rctt2.org_id = rctt.org_id
                     and rctt2.credit_memo_type_id = rctt.cust_trx_type_id
                     and rctt2.attribute5 = 'Y')) --only credits of initial Transaction Types (Standard, Trade In)
   and mmt.transaction_source_type_id = 12
   and mmt.transaction_type_id = 15
   and mmt.transaction_action_id = 27
   and rctl.interface_line_attribute6 = mmt.trx_source_line_id
   and exists (select 1 from rcv_transactions rt
                       where rt.oe_order_line_id = to_number(rctl.interface_line_attribute6)
                         and rt.transaction_id = mmt.rcv_transaction_id)
   and mmt.transaction_id = mut.transaction_id(+)
   and mut.serial_number = cii.serial_number(+)
   and mut.inventory_item_id=cii.inventory_item_id(+)
   and gp_start.period_set_name = gp_end.period_set_name
   and gp_start.period_set_name = 'OBJET_CALENDAR'
   and gp_start.adjustment_period_flag = gp_end.adjustment_period_flag
   and gp_start.adjustment_period_flag = 'N'
   and xxar_revenue_recognition_disco.set_revrecog_glstrt_date(gl_data.account,null,gp_end.end_date)=1
   and msi.cost_of_sales_account=gcc_item.code_combination_id
union all
--Cogs not credits - GL
select 'COST' Meaning,
       null cust_trx_line_gl_dist_id,
       ho.short_code Operating_Unit,
       rct.org_id,
       rbs.name invoice_source,
       rctt.name invoice_trx_type,
       rctl.interface_line_attribute2 order_type,
       rct.trx_number invoice_number,
       nvl(rctl.interface_line_attribute1, /*rct.interface_header_attribute1*/rct.ct_reference) order_number,
       xxar_revenue_recognition_disco.get_applied_invoice_info(rct.customer_trx_id) applied_to_inv_credit_ref,
       rct.trx_date invoice_date,
       hp.party_name bill_to_customer,
       hca.account_number bill_to_cust_account_number,
       rs.name sale_person_name,
       hca.sales_channel_code sale_channel,
       rctl.line_number invoice_line,
       trunc(mmt.transaction_date) gl_date,
       (case when XXAR_REVENUE_RECOGNITION_DISCO.is_SSYS_item(rctl.inventory_item_id)=1 then
          case when XXAR_REVENUE_RECOGNITION_DISCO.is_SSYS_900_item(rctl.inventory_item_id)=1 then
       trunc(to_date(rctl.attribute12, 'YYYY/MM/DD HH24:MI:SS'))
       else
       trunc(ol.actual_shipment_date)
       end
       else
       trunc(to_date(cii.attribute7, 'YYYY/MM/DD HH24:MI:SS'))
       end) coi_date,
       trunc(cii.install_date) install_warranty_date,
       trunc(nvl(ol.actual_shipment_date, rctl.sales_order_date)) ship_or_order_date,
       msi.segment1 item,
       gcc_item.segment5 pl_item,
       nvl(rctl.translated_description, rctl.description) description,
       mut.serial_number,
       nvl(rctl.quantity_invoiced, rctl.quantity_credited) invoice_line_quantity,
       rctl.uom_code,
       null entered_rev_amount,
       rct.invoice_currency_code inv_curr,
       null accounted_rev_amount,
       (nvl(-nvl(ail.base_amount, ail.amount),
            decode(hoi.org_information3,ho.organization_id,mmt.primary_quantity * mmt.actual_cost,0)) *
       (decode(mut.transaction_id, null, -mmt.primary_quantity, 1)) /
       (-mmt.primary_quantity)) accounted_cogs_amount,
       g_ledg.currency_code ledger_curr,
       null USD_rev_amount,
       (nvl(-nvl(ail.base_amount, ail.amount),
            decode(hoi.org_information3,ho.organization_id,mmt.primary_quantity * mmt.actual_cost,0)) *
       decode(g_ledg.currency_code,
               'USD',
               1,
               (gl_currency_api.get_closest_rate( /*from*/g_ledg.currency_code, /*to*/
                                                 'USD', /*date*/
                                                 mmt.transaction_date,
                                                 'Corporate',
                                                 10))) *
       (decode(mut.transaction_id, null, -mmt.primary_quantity, 1)) /
       (-mmt.primary_quantity)) USD_cogs_amount,
       decode(fnd_profile.value('XXAR_ENABLE_SECURITY_COGS_REV_RECOG'),'N',(decode(hoi.org_information3,
               '81',
               /*IL cost - regular & subsidiary I/C*/
               mmt.primary_quantity * mmt.actual_cost,
               decode(rctl.org_id,
                      81, /*IL AP cost from I/C Purchasing*/
                      -nvl(ail.base_amount, ail.amount),
                      /*IL last known cost from internal trx or 31-aug-09*/
                      mmt.primary_quantity *
                      xxar_utils_pkg.get_item_last_il_cost_ic_trx(rctl.org_id,
                                                                  mmt.inventory_item_id,
                                                                  mmt.transaction_date))) *
       (decode(mut.transaction_id, null, -mmt.primary_quantity, 1)) /
       (-mmt.primary_quantity)),null) USD_IL_cogs_amount,
       null ILS_rev_amount,
       (nvl(-nvl(ail.base_amount, ail.amount),
            decode(hoi.org_information3,ho.organization_id,mmt.primary_quantity * mmt.actual_cost,0)) *
       decode(g_ledg.currency_code,
               'ILS',
               1,
               (gl_currency_api.get_closest_rate( /*from*/g_ledg.currency_code, /*to*/
                                                 'ILS', /*date*/
                                                 mmt.transaction_date,
                                                 'Corporate',
                                                 10))) *
       (decode(mut.transaction_id, null, -mmt.primary_quantity, 1)) /
       (-mmt.primary_quantity)) ILS_cogs_amount,
       rctl.attribute10 average_discount_percent,
       nvl(gcc_ap.segment1, decode(hoi.org_information3,ho.organization_id, gcc.segment1,null)) comp_seg,
       nvl(gcc_ap.segment2, gcc.segment2) depar_seg,
       nvl(gcc_ap.segment3, gcc.segment3) account_seg,
       nvl(gcc_ap.segment4, gcc.segment4) sub_acc_seg,
       nvl(gcc_ap.segment5, gcc.segment5) pl_seg,
       nvl(gcc_ap.segment6, gcc.segment6) loc_seg,
       nvl(gcc_ap.segment7, gcc.segment7) ic_seg,
       nvl(gcc_ap.segment8, gcc.segment8) proj_seg,
       nvl(gcc_ap.segment9, gcc.segment9) futur_seg,
       rctl.customer_trx_line_id inv_line_id,
       null total_clearing_account,
       null accounted_Invoice_Balance,
       null usd_Invoice_Balance,
       null ils_Invoice_Balance,
       gl_data.currency gl_currency,
       gl_data.gl_period_name,
       null gl_entered_rev_amount,
       null gl_accounted_rev_amount,
       (gl_data.entered_amount *
       nvl((decode(mut.transaction_id, null, -mmt.primary_quantity, -sign(mmt.primary_quantity))/
              nvl(rctl.quantity_invoiced, rctl.quantity_credited)),1)) gl_entered_cogs_amount, --differently than above!!! base allocation = invoice qty!!! as the amount is from
                                                        -- gl according to mmt but it is transformated back to report by invoice line id
                                                        --and the spliting may be from mmt or mut. (i.e. in case there are more than 1 mmt line
                                                        --for same invoice line id it should be allocated when the base allocation is inv qty)
       (gl_data.accounted_amount *
       nvl((decode(mut.transaction_id, null, -mmt.primary_quantity, -sign(mmt.primary_quantity))/
              nvl(rctl.quantity_invoiced, rctl.quantity_credited)),1)) gl_accounted_cogs_amount,
       null warranty_start_date,
       null warranty_type,
       null warranty_end_date,
       gp_start.period_name period_start, --for discoverer parametrer
       gp_end.period_name period_end, --for dicoverer parameter
       gp_end.end_date period_end_date,
       null manual_rev_account, --for discoverer parameter
       gl_data.account manual_cogs_account, --for discoverer parameter
        --14/08/2011    Ofer Suad add Sale Order Channel
        (select oh.attribute7
       from oe_order_headers_all oh
       where ol.header_id=oh.header_id
        and rctl.sales_order_line is not null  ) Order_Channel,
        --- Ofer Suad Dec-2012 add Freight_Terms and  Sys_Booking_Date
     (select vl.MEANING
    from oe_order_lines_all ol, oe_order_headers_all oh,FND_LOOKUP_VALUES_VL vl
   where ol.line_id = rctl.interface_line_attribute6
     and oh.header_id = ol.header_id
     and rctl.interface_line_context in ('ORDER ENTRY', 'INTERCOMPANY')
     and rctl.sales_order_line is not null
     and vl.LOOKUP_TYPE = 'FREIGHT_TERMS'
   and vl.VIEW_APPLICATION_ID = 660
   And vl.LOOKUP_CODE =oh.freight_terms_code) Freight_Terms,
       (select to_date(oh.attribute2,'yyyy/mm/dd hh24:mi:ss')
       from oe_order_headers_all oh
       where oh.header_id=ol.header_id) SYS_Booking_Date
  from (select gcc_gl.segment3 account, --it is only 1 account (manual cogs) according to the parameter
               min(jh.currency_code) currency,
               sum(nvl(jl.entered_cr, 0) - nvl(jl.entered_dr, 0)) entered_amount,
               sum(nvl(jl.accounted_cr, 0) - nvl(jl.accounted_dr, 0)) accounted_amount,
               jl.attribute10 dist_or_line_id, --for revenue ar dist id and for cost ar line id
               gp.period_name gl_period_name, --it is only 1 period according to the function below
               jh.ledger_id
          from gl_je_headers        jh,
               gl_je_lines          jl,
               gl_code_combinations gcc_gl,
               gl_periods           gp,
               ar_system_parameters asp
         where jh.je_header_id = jl.je_header_id
           and jl.code_combination_id = gcc_gl.code_combination_id
           and nvl(jh.accrual_rev_period_name, jh.period_name) !=
               jh.period_name
           and jh.je_category = '21' --XX Deferred Revenue/Cogs
           and jh.status = 'P'
           and jh.actual_flag = 'A'
           and gp.adjustment_period_flag = 'N'
           and gp.period_set_name = 'OBJET_CALENDAR'
           and gp.period_name = jh.period_name
           and gp.start_date = xxar_revenue_recognition_disco.get_revrecog_glstrt_date(jh.ledger_id)
           and asp.set_of_books_id = jh.ledger_id
         group by gcc_gl.segment3, jl.attribute10, gp.period_name,jh.ledger_id) gl_data,
       ra_customer_trx_all rct,
       ra_customer_trx_lines rctl,
       mtl_system_items_b msi,
       oe_order_lines_all ol,
       ra_cust_trx_types_all rctt,
       ra_batch_sources_all rbs,
       hz_cust_accounts hca,
       hz_parties hp,
       ra_salesreps rs,
       hr_operating_units ho,
       gl_code_combinations gcc,
       gl_code_combinations gcc_ap,
       gl_ledgers g_ledg,
       mtl_material_transactions mmt,
       mtl_unit_transactions mut,
       mtl_secondary_inventories msubi,
       csi_item_instances cii,
       ap_invoice_lines_all ail,
       hr_organization_information hoi,
       gl_periods gp_start,
       gl_periods gp_end,
       gl_code_combinations gcc_item
 where rctl.customer_trx_line_id = gl_data.dist_or_line_id --in this case it is ar line id because it is manual cogs account
   and rctl.set_of_books_id = gl_data.ledger_id
   and rctl.customer_trx_id = rct.customer_trx_id
   and rctl.inventory_item_id = msi.inventory_item_id(+)
   and msi.organization_id(+) = 91--xxinv_utils_pkg.get_master_organization_id
   and rctl.interface_line_attribute6 = ol.line_id(+)
   and rct.cust_trx_type_id = rctt.cust_trx_type_id
   and rct.org_id = rctt.org_id
   and rct.batch_source_id = rbs.batch_source_id
   and rct.org_id = rbs.org_id
   and rct.bill_to_customer_id = hca.cust_account_id
   and hca.party_id = hp.party_id
   and rct.primary_salesrep_id = rs.salesrep_id(+)
   and rct.org_id = rs.org_id(+)
   and rct.org_id = ho.organization_id
   and rct.set_of_books_id = g_ledg.ledger_id
   and rctl.interface_line_context = 'ORDER ENTRY' --only Order Entry Sources
   and rctl.line_type = 'LINE'
   ----and rctl.quantity_invoiced is not null --non rma
   and nvl(mmt.primary_quantity, 0) != 0
   and ((rctt.attribute5 = 'Y') --only initial Transaction Types (Standard, Trade In)
       or exists (select 1
                    from ra_cust_trx_types_all rctt2
                   where rctt2.org_id = rctt.org_id
                     and rctt2.credit_memo_type_id = rctt.cust_trx_type_id
                     and rctt2.attribute5 = 'Y')) --only credits of initial Transaction Types (Standard, Trade In)
   and mmt.transaction_source_type_id = 2
   and mmt.transaction_type_id = 33
   and mmt.transaction_action_id = 1
   and rctl.interface_line_attribute6 = mmt.source_line_id
   and rctl.interface_line_attribute3 = decode(ol.source_type_code,'EXTERNAL',rctl.interface_line_attribute3,mmt.shipment_number)
   and mmt.distribution_account_id = gcc.code_combination_id
   and mmt.subinventory_code = msubi.secondary_inventory_name
   and mmt.organization_id = msubi.organization_id
   and msubi.asset_inventory =1
   and mmt.transaction_id = mut.transaction_id(+)
   and mut.serial_number = cii.serial_number(+)
   and mut.inventory_item_id=cii.inventory_item_id(+)
   and mmt.transaction_id = ail.reference_2(+)
   and ail.accounting_date(+) between mmt.transaction_date - 1 and
       mmt.transaction_date + 1
   and ail.default_dist_ccid = gcc_ap.code_combination_id(+)
   and mmt.organization_id = hoi.organization_id
   and hoi.org_information_context = 'Accounting Information'
   and gp_start.period_set_name = gp_end.period_set_name
   and gp_start.period_set_name = 'OBJET_CALENDAR'
   and gp_start.adjustment_period_flag = gp_end.adjustment_period_flag
   and gp_start.adjustment_period_flag = 'N'
   and xxar_revenue_recognition_disco.set_revrecog_glstrt_date(null,gl_data.account,gp_end.end_date)=1
   and gcc_item.code_combination_id=msi.cost_of_sales_account
union all
--Cogs credits - GL
select 'COST CM' Meaning,
       null cust_trx_line_gl_dist_id,
       ho.short_code Operating_Unit,
       rct.org_id,
       rbs.name invoice_source,
       rctt.name invoice_trx_type,
       rctl.interface_line_attribute2 order_type,
       rct.trx_number invoice_number,
       nvl(rctl.interface_line_attribute1, /*rct.interface_header_attribute1*/rct.ct_reference) order_number,
       xxar_revenue_recognition_disco.get_applied_invoice_info(rct.customer_trx_id) applied_to_invoice_ref,
       rct.trx_date invoice_date,
       hp.party_name bill_to_customer,
       hca.account_number bill_to_cust_account_number,
       rs.name sale_person_name,
       hca.sales_channel_code sale_channel,
       rctl.line_number invoice_line,
       trunc(mmt.transaction_date) gl_date,
       (case when XXAR_REVENUE_RECOGNITION_DISCO.is_SSYS_item(rctl.inventory_item_id)=1 then
          case when XXAR_REVENUE_RECOGNITION_DISCO.is_SSYS_900_item(rctl.inventory_item_id)=1 then
       trunc(to_date(rctl.attribute12, 'YYYY/MM/DD HH24:MI:SS'))
       else
       trunc(mmt.transaction_date)
       end
       else
       trunc(to_date(cii.attribute7, 'YYYY/MM/DD HH24:MI:SS'))
       end) coi_date,
       trunc(cii.install_date) install_warranty_date,
       trunc(nvl(mmt.transaction_date, rctl.sales_order_date)) ship_or_order_date,
       msi.segment1 item,
       gcc_item.segment5 pl_item,
       nvl(rctl.translated_description, rctl.description) description,
       mut.serial_number,
       nvl(rctl.quantity_invoiced, rctl.quantity_credited) invoice_line_quantity,
       rctl.uom_code,
       null entered_rev_amount,
       rct.invoice_currency_code inv_curr,
       null accounted_rev_amount,
       (nvl(-nvl(ail.base_amount, ail.amount),
            decode(hoi.org_information3,ho.organization_id,mmt.primary_quantity * mmt.actual_cost,0)) *
       (decode(mut.transaction_id, null, -mmt.primary_quantity, -1)) /
       (-mmt.primary_quantity)) accounted_cogs_amount,
       g_ledg.currency_code ledger_curr,
       null USD_rev_amount,
       (nvl(-nvl(ail.base_amount, ail.amount),
            decode(hoi.org_information3,ho.organization_id,mmt.primary_quantity * mmt.actual_cost,0)) *
       decode(g_ledg.currency_code,
               'USD',
               1,
               (gl_currency_api.get_closest_rate( /*from*/g_ledg.currency_code, /*to*/
                                                 'USD', /*date*/
                                                 mmt.transaction_date,
                                                 'Corporate',
                                                 10))) *
       (decode(mut.transaction_id, null, -mmt.primary_quantity, -1)) /
       (-mmt.primary_quantity)) USD_cogs_amount,
       decode(fnd_profile.value('XXAR_ENABLE_SECURITY_COGS_REV_RECOG'),'N',(decode(hoi.org_information3,
               '81',
               /*IL cost - regular & subsidiary I/C*/
               mmt.primary_quantity * mmt.actual_cost,
               decode(rctl.org_id,
                      81, /*IL AP cost from I/C Purchasing*/
                      -nvl(ail.base_amount, ail.amount),
                      /*IL last known cost from internal trx or 31-aug-09*/
                      mmt.primary_quantity *
                      xxar_utils_pkg.get_item_last_il_cost_ic_trx(rctl.org_id,
                                                                  mmt.inventory_item_id,
                                                                  mmt.transaction_date))) *
       (decode(mut.transaction_id, null, -mmt.primary_quantity, -1)) /
       (-mmt.primary_quantity)),null) USD_IL_cogs_amount,
       null ILS_rev_amount,
       (nvl(-nvl(ail.base_amount, ail.amount),
            decode(hoi.org_information3,ho.organization_id,mmt.primary_quantity * mmt.actual_cost,0)) *
       decode(g_ledg.currency_code,
               'ILS',
               1,
               (gl_currency_api.get_closest_rate( /*from*/g_ledg.currency_code, /*to*/
                                                 'ILS', /*date*/
                                                 mmt.transaction_date,
                                                 'Corporate',
                                                 10))) *
       (decode(mut.transaction_id, null, -mmt.primary_quantity, -1)) /
       (-mmt.primary_quantity)) ILS_cogs_amount,
       rctl.attribute10 average_discount_percent,
       nvl(gcc_ap.segment1, decode(hoi.org_information3,ho.organization_id, gcc.segment1,null)) comp_seg,
       nvl(gcc_ap.segment2, gcc.segment2) depar_seg,
       nvl(gcc_ap.segment3, gcc.segment3) account_seg,
       nvl(gcc_ap.segment4, gcc.segment4) sub_acc_seg,
       nvl(gcc_ap.segment5, gcc.segment5) pl_seg,
       nvl(gcc_ap.segment6, gcc.segment6) loc_seg,
       nvl(gcc_ap.segment7, gcc.segment7) ic_seg,
       nvl(gcc_ap.segment8, gcc.segment8) proj_seg,
       nvl(gcc_ap.segment9, gcc.segment9) futur_seg,
       rctl.customer_trx_line_id inv_line_id,
       null total_clearing_account,
       null accounted_Invoice_Balance,
       null usd_Invoice_Balance,
       null ils_Invoice_Balance,
       gl_data.currency gl_currency,
       gl_data.gl_period_name,
       null gl_entered_rev_amount,
       null gl_accounted_rev_amount,
       (gl_data.entered_amount *
       nvl((decode(mut.transaction_id, null, -mmt.primary_quantity, -sign(mmt.primary_quantity))/
              nvl(rctl.quantity_invoiced, rctl.quantity_credited)),1)) gl_entered_cogs_amount,  --differently than above!!! base allocation = invoice qty!!! as explained above
       (gl_data.accounted_amount *
       nvl((decode(mut.transaction_id, null, -mmt.primary_quantity, -sign(mmt.primary_quantity))/
              nvl(rctl.quantity_invoiced, rctl.quantity_credited)),1)) gl_accounted_cogs_amount,
       null warranty_start_date,
       null warranty_type,
       null warranty_end_date,
       gp_start.period_name period_start, --for discoverer parametrer
       gp_end.period_name period_end, --for dicoverer parameter
       gp_end.end_date period_end_date,
       null manual_rev_account, --for discoverer parameter
       gl_data.account manual_cogs_account, --for discoverer parameter
        --14/08/2011    Ofer Suad add Sale Order Channel
        (select oh.attribute7
       from oe_order_headers_all oh,oe_order_lines_all ol
       where ol.header_id=oh.header_id
        and rctl.interface_line_attribute6 = ol.line_id
        and rctl.sales_order_line is not null  ) Order_Channel,
          --- Ofer Suad Dec-2012 add Freight_Terms and  Sys_Booking_Date
     (select vl.MEANING
    from oe_order_lines_all ol, oe_order_headers_all oh,FND_LOOKUP_VALUES_VL vl
   where ol.line_id = rctl.interface_line_attribute6
     and oh.header_id = ol.header_id
     and rctl.interface_line_context in ('ORDER ENTRY', 'INTERCOMPANY')
     and rctl.sales_order_line is not null
     and vl.LOOKUP_TYPE = 'FREIGHT_TERMS'
   and vl.VIEW_APPLICATION_ID = 660
   And vl.LOOKUP_CODE =oh.freight_terms_code) Freight_Terms,
         (select to_date(oh.attribute2,'yyyy/mm/dd hh24:mi:ss')
       from oe_order_headers_all oh,oe_order_lines_all ol
       where ol.header_id=oh.header_id
        and rctl.interface_line_attribute6 = ol.line_id
        and rctl.sales_order_line is not null  ) SYS_Booking_Date
  from (select gcc_gl.segment3 account, --it is only 1 account (manual cogs) according to the parameter
               min(jh.currency_code) currency,
               sum(nvl(jl.entered_cr, 0) - nvl(jl.entered_dr, 0)) entered_amount,
               sum(nvl(jl.accounted_cr, 0) - nvl(jl.accounted_dr, 0)) accounted_amount,
               jl.attribute10 dist_or_line_id, --for revenue ar dist id and for cost ar line id
               gp.period_name gl_period_name, --it is only 1 period according to the function below
               jh.ledger_id
          from gl_je_headers        jh,
               gl_je_lines          jl,
               gl_code_combinations gcc_gl,
               gl_periods           gp ,
               ar_system_parameters asp
         where jh.je_header_id = jl.je_header_id
           and jl.code_combination_id = gcc_gl.code_combination_id
           and nvl(jh.accrual_rev_period_name, jh.period_name) !=
               jh.period_name
           and jh.je_category = '21' --XX Deferred Revenue/Cogs
           and jh.status = 'P'
           and jh.actual_flag = 'A'
           and gp.adjustment_period_flag = 'N'
           and gp.period_set_name = 'OBJET_CALENDAR'
           and gp.period_name = jh.period_name
           and gp.start_date = xxar_revenue_recognition_disco.get_revrecog_glstrt_date(jh.ledger_id)
           and asp.set_of_books_id = jh.ledger_id
         group by gcc_gl.segment3, jl.attribute10, gp.period_name,jh.ledger_id) gl_data,
       ra_customer_trx_all rct,
       ra_customer_trx_lines rctl,
       mtl_system_items_b msi,
       ra_cust_trx_types_all rctt,
       ra_batch_sources_all rbs,
       hz_cust_accounts hca,
       hz_parties hp,
       ra_salesreps rs,
       hr_operating_units ho,
       gl_code_combinations gcc,
       gl_code_combinations gcc_ap,
       gl_ledgers g_ledg,
       mtl_material_transactions mmt,
       mtl_unit_transactions mut,
       mtl_secondary_inventories msubi,
       csi_item_instances cii,
       ap_invoice_lines_all ail,
       hr_organization_information hoi,
       gl_periods gp_start,
       gl_periods gp_end,
       gl_code_combinations gcc_item
 where rctl.customer_trx_line_id = gl_data.dist_or_line_id --in this case it is ar line id because it is manual cogs account
   and rctl.set_of_books_id = gl_data.ledger_id
   and rctl.customer_trx_id = rct.customer_trx_id
   and rctl.inventory_item_id = msi.inventory_item_id(+)
   and msi.organization_id(+) = 91--xxinv_utils_pkg.get_master_organization_id
   and rct.cust_trx_type_id = rctt.cust_trx_type_id
   and rct.org_id = rctt.org_id
   and rct.batch_source_id = rbs.batch_source_id
   and rct.org_id = rbs.org_id
   and rct.bill_to_customer_id = hca.cust_account_id
   and hca.party_id = hp.party_id
   and rct.primary_salesrep_id = rs.salesrep_id(+)
   and rct.org_id = rs.org_id(+)
   and rct.org_id = ho.organization_id
   and rct.set_of_books_id = g_ledg.ledger_id
   and rctl.interface_line_context = 'ORDER ENTRY' --only Order Entry Sources
   and rctl.line_type = 'LINE'
   ----and rctl.quantity_invoiced is null --rma
   and nvl(mmt.primary_quantity, 0) != 0
   and ((rctt.attribute5 = 'Y') --only initial Transaction Types (Standard, Trade In)
       or exists (select 1
                    from ra_cust_trx_types_all rctt2
                   where rctt2.org_id = rctt.org_id
                     and rctt2.credit_memo_type_id = rctt.cust_trx_type_id
                     and rctt2.attribute5 = 'Y')) --only credits of initial Transaction Types (Standard, Trade In)
   and mmt.transaction_source_type_id = 12
   and mmt.transaction_type_id = 15
   and mmt.transaction_action_id = 27
   and rctl.interface_line_attribute6 = mmt.trx_source_line_id
   and mmt.distribution_account_id = gcc.code_combination_id
   and mmt.subinventory_code = msubi.secondary_inventory_name
   and mmt.organization_id = msubi.organization_id
   and msubi.asset_inventory =1
   and mmt.transaction_id = mut.transaction_id(+)
   and mut.serial_number = cii.serial_number(+)
   and mut.inventory_item_id=cii.inventory_item_id(+)
   and mmt.transaction_id = ail.reference_2(+)
   and ail.accounting_date(+) between mmt.transaction_date - 1 and
       mmt.transaction_date + 1
   and ail.default_dist_ccid = gcc_ap.code_combination_id(+)
   and mmt.organization_id = hoi.organization_id
   and hoi.org_information_context = 'Accounting Information'
   and gp_start.period_set_name = gp_end.period_set_name
   and gp_start.period_set_name = 'OBJET_CALENDAR'
   and gp_start.adjustment_period_flag = gp_end.adjustment_period_flag
   and gp_start.adjustment_period_flag = 'N'
   and gcc_item.code_combination_id=msi.cost_of_sales_account
   and xxar_revenue_recognition_disco.set_revrecog_glstrt_date(null,gl_data.account,gp_end.end_date)=1;
