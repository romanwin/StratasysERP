CREATE OR REPLACE VIEW XXAR_SALES_AND_COGS_DISCO_V AS
select
--------------------------------------------------------------------
--  name:              XXHR_EMP_HEAD_COUNT_DET_V
--  create by:         Daniel Katz
--  Revision:          1.0
--  creation date:     18/05/2011
--------------------------------------------------------------------
--  purpose :          Sales & Cogs Disco Report.
--                     Note: this view could be used ONLY WITH THE DISCO REPORT !!! DO NOT RUN IT AS A STAND ALONE!!!
--
--                     additional relevant objects are:
--                     Package: XXAR_REVENUE_RECOGNITION_DISCO
--                     Function xxar_utils_pkg.get_item_last_il_cost_ic_trx
--------------------------------------------------------------------
--  ver  date          name              desc
--  1.0  18/05/2011    Daniel Katz       initial build
--  1.1  21/12/2011    Ofer Suad         split 'COST CM' Meaning to 2 queries due to prformance issue
--  1.2  01/10/2013    Ofer Suad         remove start period and end period  to pkg -prformance issue
--  1.3  21/05/2014    Arin Friedman     handle zero divide
--  1.4  11/06/2014    Sandeep Akula     Added New Columns "ship_to_country" and "ship_to_state" to the select statements (CHG0032350)
--  1.5  08/03/2015    Ofer Suad         CHG0034115 1. Change IL std cost., 2. Fix qty invoiced column
--                                       3. Time zone fix - take mta gl date from subleger
-- 1.6  14/06/2015     Ofer Suad        CHG0035659:
--                                      1.	Add condition – if mtl_transaction_accounts.cost_element_id is not 1 IL std cost will be zero.
--                                      2.	At the report level add function to set the average rates. Add 2 columns of accounted revenue
--                                      multiplied by average rate and Accounted cogs multiplied by average rate
--                                      3.	Set that column Usd Cogs Amount will be multiplied by the sign of mtl primary quantity.
--                                      4.	Change Cogs IL column – multiply IL cogs amount by mtl primary quantity.
--    08-Sep-2015     Ofer Suad         CHG0036330  change serial nums
-------------------------------------------------------------------
        --Revenue while cost is not rma
        decode(rctl.quantity_invoiced, null, 'REVENUE CM', 'REVENUE') Meaning,
        rctlgd.cust_trx_line_gl_dist_id,
        mmt.transaction_id material_trx_id,
        ho.short_code Operating_Unit,
        rct.org_id,
        rbs.name invoice_source,
        rctt.name invoice_trx_type,
        rctl.interface_line_attribute2 order_type,
        rct.trx_number invoice_number,
        nvl(rctl.sales_order,nvl(rctl.interface_line_attribute1, rct.ct_reference)) order_number,
        xxar_revenue_recognition_disco.get_applied_invoice_info(rct.customer_trx_id) applied_to_inv_credit_ref,
        rct.purchase_order customer_po_number,
        rct.trx_date invoice_date,
        rctl.rule_start_date,
        rctl.rule_end_date,
        hp.party_name bill_to_customer,
        hca.account_number bill_to_cust_account_number,
        rs.name sale_person_name,
        (select min(al.meaning)
          from hz_code_assignments hcodeass, ar_lookups al
         where hcodeass.owner_table_id = hp.party_id
           and hcodeass.class_category = al.lookup_type
           and hcodeass.class_code = al.lookup_code
           and hcodeass.class_category = 'Objet Business Type'
           and hcodeass.status = 'A'
           and hcodeass.start_date_active <= sysdate
           and nvl(hcodeass.end_date_active, sysdate) >= sysdate
           and hcodeass.owner_table_name = 'HZ_PARTIES') Customer_Main_Business_type,
        hca.sales_channel_code sale_channel,
        rctl.line_number invoice_line,
        rctlgd.gl_date,
        msi.segment1 item, 
        nvl(rctl.translated_description, rctl.description) description,
        decode(rctt.name,'Warranty Invoices',rctl.attribute2,decode(msi.serial_number_control_code,1,null,xxinv_utils_pkg.get_serials_and_lots(rctl.interface_line_attribute6))) serial_number,--CHG0036330  change serial nums
       -- mut.serial_number,
        nvl(rctl.quantity_invoiced, rctl.quantity_credited) invoice_line_quantity,
        rctl.uom_code,
        -- Arin 20/05/2014 handle zero divide
        case when ( nvl(rctl.quantity_invoiced, rctl.quantity_credited) ) = 0 then
                0
             else
                rctlgd.amount *
                nvl((decode(mut.transaction_id, null, -mmt.primary_quantity, -sign(mmt.primary_quantity))/
                   nvl(rctl.quantity_invoiced, rctl.quantity_credited)),1)
        end entered_rev_amount, --on credit quantity could be null
        -- end
        --base allocation = invoice qty as the amount is from distribution
        --and the spliting may be from mmt or mut.
        --on credit quantity could be null
        rct.invoice_currency_code inv_curr,
        -- Arin 20/05/2014 handle zero divide
        case when (nvl(rctl.quantity_invoiced, rctl.quantity_credited) = 0) then
               0
             else
               rctlgd.acctd_amount *
               nvl((decode(mut.transaction_id, null, -mmt.primary_quantity, -sign(mmt.primary_quantity))/
               nvl(rctl.quantity_invoiced, rctl.quantity_credited)),1)
        end accounted_rev_amount,
        null accounted_cogs_amount,
        g_ledg.currency_code ledger_curr,
        -- Arin 20/05/2014 handle zero divide
        case when ( nvl(rctl.quantity_invoiced, rctl.quantity_credited) ) = 0 then
               0
             else
               (decode(g_ledg.currency_code, 'USD', rctlgd.acctd_amount,
                decode(rct.invoice_currency_code, 'USD', rctlgd.amount,
                      (rctlgd.acctd_amount *
                       gl_currency_api.get_closest_rate( g_ledg.currency_code,
                                 'USD',  nvl(rct.exchange_date,rct.trx_date),'Corporate', 10)))) *
                       nvl((decode(mut.transaction_id, null, -mmt.primary_quantity, -sign(mmt.primary_quantity))/
                       nvl(rctl.quantity_invoiced, rctl.quantity_credited)),1))
        end USD_rev_amount,
        null USD_cogs_amount,
        null USD_IL_cogs_amount,
        gcc.segment1 comp_seg,
        gcc.segment2 depart_seg,
        gcc.segment3 account_seg,
        gcc.segment4 sub_acc_seg,
        gcc.segment5 pl_seg,
        gcc.segment6 loc_seg,
        gcc.segment7 ic_seg,
        gcc.segment8 proj_seg,
        gcc.segment9 futur_seg,
        xxgl_utils_pkg.get_dff_value_description(1013893, gcc.segment5) dist_prod_line_seg_desc,
        decode(substr(gcc.segment5, 1, 1),
                  1, 'Systems',
                  2, 'FDM-Systems',
                  5, 'Consumables',
                  7, 'FDM-Consumables',
                  8, 'Customer Support',
                  9, 'FDM-Maintenance and SP', 'Other') item_prod_line_parent,
        xxgl_utils_pkg.get_dff_value_description(1013892, gcc.segment6) dist_loc_seg_desc,
        (select min(ffv.DESCRIPTION)
           from fnd_flex_value_children_v ffvc,
                fnd_flex_values_vl        ffv,
                fnd_flex_hierarchies      ffh
          where ffvc.flex_value_set_id = 1013892
            and ffvc.flex_value_set_id = ffh.FLEX_VALUE_SET_ID
            and ffh.flex_value_set_id = ffv.flex_value_set_id
            and ffh.hierarchy_id = ffv.STRUCTURED_HIERARCHY_LEVEL
            and ffvc.parent_flex_value = ffv.FLEX_VALUE
            and ffh.hierarchy_code = 'ACCOUNTING'
            and ffvc.flex_value = gcc.segment6) dist_cust_location_parent,
        rctl.customer_trx_line_id inv_line_id,
        -- gp_start.period_name period_start, --for discoverer parametrer
        -- gp_end.period_name   period_end, --for dicoverer parameter
        -- gp_end.end_date      period_end_date,
        gp.period_name,
        null cogs_account, --for discoverer parameter
        xxar_sales_and_cogs_disco_pkg.get_ship_to_state(rct.ship_to_customer_id,rct.ship_to_site_use_id) ship_to_state,
        xxar_sales_and_cogs_disco_pkg.get_ship_to_country(rct.ship_to_customer_id,rct.ship_to_site_use_id) ship_to_country,
        decode(rctt.name,'Warranty Invoices','Y','Warranty Invoices CM','Y',rctlgd.attribute1 ) is_VSOE_Line
from    ra_customer_trx_all       rct,
        ra_customer_trx_lines_all rctl,
        ra_cust_trx_line_gl_dist  rctlgd,
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
        --  gl_periods gp_start,
        --  gl_periods gp_end,
        gl_periods gp
where rctlgd.customer_trx_line_id = rctl.customer_trx_line_id
  and rctl.customer_trx_id = rct.customer_trx_id
  and rctl.inventory_item_id = msi.inventory_item_id(+)
  and msi.organization_id(+) = 91 --xxinv_utils_pkg.get_master_organization_id
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
  and rctlgd.account_set_flag = 'N'
  AND rct.complete_flag = 'Y'
  and rctlgd.account_class in ('REV', 'SUSPENSE')
  and nvl(rctl.interface_line_context, 'ORDER ENTRY') in
      ('ORDER ENTRY', 'OKS CONTRACTS','OKL_CONTRACTS') --only Manual, Order Entry or Contracts Sources
  and rctl.line_type = 'LINE'
  and mmt.transaction_source_type_id(+) = 2
  and mmt.transaction_type_id(+) = 33
  and mmt.transaction_action_id(+) = 1
  and decode(rctl.interface_line_context,'OKS CONTRACTS',-99,'OKL_CONTRACTS',-99,rctl.interface_line_attribute6) = mmt.source_line_id(+)
  and rctl.interface_line_attribute3 = mmt.shipment_number(+)
  and ((rctl.sales_order_line is not null and rctl.interface_line_context is not null) or rctl.interface_line_context is null
  or rctl.interface_line_context='OKL_CONTRACTS')--ignore freight came as charges
  and mmt.transaction_id = mut.transaction_id(+)
  and rctlgd.gl_date between xxar_sales_and_cogs_disco_pkg.get_start_date and xxar_sales_and_cogs_disco_pkg.get_end_date --gp_start.start_date and gp_end.end_date
  and rctlgd.gl_date between gp.start_date and gp.end_date
  and gp.period_set_name = 'OBJET_CALENDAR'
  and gp.adjustment_period_flag = 'N'
-- and gp_start.period_set_name = gp_end.period_set_name
--   and gp_start.period_set_name = gp.period_set_name
--   and gp_start.period_set_name = 'OBJET_CALENDAR'
--   and gp_start.adjustment_period_flag = gp_end.adjustment_period_flag
--   and gp_start.adjustment_period_flag = gp.adjustment_period_flag
--  and gp_start.adjustment_period_flag = 'N'
-- and msi.inventory_item_id in (539002,819006,1105806,539001)
  and not exists
      (select 1 from mtl_material_transactions mmt2,rcv_transactions rt, hr_organization_information hoi2
       where mmt2.rcv_transaction_id = rt.transaction_id
       and to_char(mmt2.trx_source_line_id) = rctl.interface_line_attribute6
       and to_char(rt.oe_order_line_id) = rctl.interface_line_attribute6
       and hoi2.organization_id = mmt2.organization_id
       and hoi2.org_information_context = 'Accounting Information'
       and hoi2.org_information3 = rctl.org_id
       and rctl.interface_line_context = 'ORDER ENTRY'
       and mmt2.transaction_source_type_id = 12
       and mmt2.transaction_type_id = 35
       and mmt2.transaction_action_id = 27)
union all --revenue while cost is rma credit
select  decode(rctl.quantity_invoiced, null, 'REVENUE CM', 'REVENUE') Meaning,
        rctlgd.cust_trx_line_gl_dist_id,
        mmt.transaction_id material_trx_id,
        ho.short_code Operating_Unit,
        rct.org_id,
        rbs.name invoice_source,
        rctt.name invoice_trx_type,
        rctl.interface_line_attribute2 order_type,
        rct.trx_number invoice_number,
        nvl(rctl.sales_order,nvl(rctl.interface_line_attribute1, rct.ct_reference)) order_number,
        xxar_revenue_recognition_disco.get_applied_invoice_info(rct.customer_trx_id) applied_to_invoice_ref,
        rct.purchase_order customer_po_number,
        rct.trx_date invoice_date,
        rctl.rule_start_date,
        rctl.rule_end_date,
        hp.party_name bill_to_customer,
        hca.account_number bill_to_cust_account_number,
        rs.name sale_person_name,
        (select min(al.meaning)
           from hz_code_assignments hcodeass, ar_lookups al
          where hcodeass.owner_table_id = hp.party_id
            and hcodeass.class_category = al.lookup_type
            and hcodeass.class_code = al.lookup_code
            and hcodeass.class_category = 'Objet Business Type'
            and hcodeass.status = 'A'
            and hcodeass.start_date_active <= sysdate
            and nvl(hcodeass.end_date_active, sysdate) >= sysdate
            and hcodeass.owner_table_name = 'HZ_PARTIES') Customer_Main_Business_type,
        hca.sales_channel_code sale_channel,
        rctl.line_number invoice_line,
        rctlgd.gl_date,
        msi.segment1 item,
        nvl(rctl.translated_description, rctl.description) description,
       decode(rctt.name,'Warranty Invoices',rctl.attribute2,decode(msi.serial_number_control_code,1,null,xxinv_utils_pkg.get_serials_and_lots(rctl.interface_line_attribute6))) serial_number,--CHG0036330  change serial nums
       -- mut.serial_number,
        nvl(rctl.quantity_invoiced, rctl.quantity_credited) invoice_line_quantity,
        rctl.uom_code,
        -- Arin 20/05/2014 handle zero divide
        case when ( nvl(rctl.quantity_invoiced, rctl.quantity_credited) ) = 0 then
               0
             else
               rctlgd.amount *
               nvl((decode(mut.transaction_id, null, -mmt.primary_quantity, -sign(mmt.primary_quantity))/
               nvl(rctl.quantity_invoiced, rctl.quantity_credited)),1)
        end entered_rev_amount, --on credit quantity could be null
        -----end
        rct.invoice_currency_code inv_curr,
        -- Arin 20/05/2014 handle zero divide
        case when ( nvl(rctl.quantity_invoiced, rctl.quantity_credited) ) = 0 then
               0
             else
               rctlgd.acctd_amount *
               nvl((decode(mut.transaction_id, null, -mmt.primary_quantity, -sign(mmt.primary_quantity))/
               nvl(rctl.quantity_invoiced, rctl.quantity_credited)),1)
        end  accounted_rev_amount,
        -----end
        null accounted_cogs_amount,
        g_ledg.currency_code ledger_curr,
        -- Arin 20/05/2014 handle zero divide
        case when ( nvl(rctl.quantity_invoiced, rctl.quantity_credited) ) = 0 then
               0
             else
               (decode(g_ledg.currency_code,
                'USD',
                rctlgd.acctd_amount,
                decode(rct.invoice_currency_code,
                       'USD',
                       rctlgd.amount,
                       (rctlgd.acctd_amount *
                       gl_currency_api.get_closest_rate( g_ledg.currency_code,
                                                         'USD',
                                                         nvl(rct.exchange_date,
                                                             rct.trx_date),
                                                         'Corporate',
                                                         10)))) *
                nvl((decode(mut.transaction_id, null, -mmt.primary_quantity, -sign(mmt.primary_quantity))/
                nvl(rctl.quantity_invoiced, rctl.quantity_credited)),1))
        end USD_rev_amount,
        -----end
        null USD_cogs_amount,
        null USD_IL_cogs_amount,
        gcc.segment1 comp_seg,
        gcc.segment2 depart_seg,
        gcc.segment3 account_seg,
        gcc.segment4 sub_acc_seg,
        gcc.segment5 pl_seg,
        gcc.segment6 loc_seg,
        gcc.segment7 ic_seg,
        gcc.segment8 proj_seg,
        gcc.segment9 futur_seg,
        xxgl_utils_pkg.get_dff_value_description(1013893, gcc.segment5) dist_prod_line_seg_desc,
        decode(substr(gcc.segment5, 1, 1),
                       1, 'Systems',
                       2, 'FDM-Systems',
                       5, 'Consumables',
                       7, 'FDM-Consumables',
                       8, 'Customer Support',
                       9, 'FDM-Maintenance and SP', 'Other') item_prod_line_parent,
        xxgl_utils_pkg.get_dff_value_description(1013892, gcc.segment6) dist_loc_seg_desc,
        (select min(ffv.DESCRIPTION)
           from fnd_flex_value_children_v ffvc,
                fnd_flex_values_vl        ffv,
                fnd_flex_hierarchies      ffh
          where ffvc.flex_value_set_id = 1013892
            and ffvc.flex_value_set_id = ffh.FLEX_VALUE_SET_ID
            and ffh.flex_value_set_id = ffv.flex_value_set_id
            and ffh.hierarchy_id = ffv.STRUCTURED_HIERARCHY_LEVEL
            and ffvc.parent_flex_value = ffv.FLEX_VALUE
            and ffh.hierarchy_code = 'ACCOUNTING'
            and ffvc.flex_value = gcc.segment6) dist_cust_location_parent,
        rctl.customer_trx_line_id inv_line_id,
        --   gp_start.period_name period_start, --for discoverer parametrer
        --   gp_end.period_name   period_end, --for dicoverer parameter
        --   gp_end.end_date      period_end_date,
        gp.period_name,
        null            cogs_account, --for discoverer parameter
        xxar_sales_and_cogs_disco_pkg.get_ship_to_state(rct.ship_to_customer_id,rct.ship_to_site_use_id) ship_to_state,
        xxar_sales_and_cogs_disco_pkg.get_ship_to_country(rct.ship_to_customer_id,rct.ship_to_site_use_id) ship_to_country,
        decode(rctt.name,'Warranty Invoices','Y','Warranty Invoices CM','Y',rctlgd.attribute1 )  is_VSOE_Line
from    ra_customer_trx_all       rct,
        ra_customer_trx_lines_all rctl,
        ra_cust_trx_line_gl_dist  rctlgd,
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
        --   gl_periods gp_start,
        --    gl_periods gp_end,
        gl_periods gp
  where rctlgd.customer_trx_line_id = rctl.customer_trx_line_id
    and rctl.customer_trx_id = rct.customer_trx_id
    and rctl.inventory_item_id = msi.inventory_item_id(+)
    and msi.organization_id(+) = 91 --xxinv_utils_pkg.get_master_organization_id
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
    and rctlgd.account_set_flag = 'N'
    AND rct.complete_flag = 'Y'
    and rctlgd.account_class in ('REV', 'SUSPENSE')
    and rctl.interface_line_context = 'ORDER ENTRY' --only Order Entry
    and rctl.line_type = 'LINE'
    and mmt.transaction_source_type_id = 12
    and mmt.transaction_type_id = 35
    and mmt.transaction_action_id = 27
    and rctl.interface_line_attribute6 = to_char(mmt.trx_source_line_id)
    and exists (select 1 from rcv_transactions rt
               where to_char(rt.oe_order_line_id) = rctl.interface_line_attribute6
                 and rt.transaction_id = mmt.rcv_transaction_id)
    and rctl.sales_order_line is not null --ignore freight came as charges
    and mmt.transaction_id = mut.transaction_id(+)
    and rctlgd.gl_date between xxar_sales_and_cogs_disco_pkg.get_start_date and xxar_sales_and_cogs_disco_pkg.get_end_date--gp_start.start_date and gp_end.end_date
    and rctlgd.gl_date between gp.start_date and gp.end_date
     and gp.period_set_name = 'OBJET_CALENDAR'
    and gp.adjustment_period_flag = 'N'
union all
--Cogs not credits
-- daniel Katz Notes:
--1.) the evaluation of IL Cogs in USD could come from material transactions on regular sale in IL and from Intercompany process in other
--    operating units OR according to the last known cost in usd from interenal transaction from IL to the Operating Unit
--    before the transaction date (or from 31-AUG-09 if doesn't exist).
--    CHG0034115 replace queries to take accounting from subledger
SELECT   decode(mta.transaction_source_type_id, 2, decode(rt.customer_trx_id,null,'COST NO INV','COST'), 12, 'COST CM'), --CHG0035659 Add decode to bring CM in case it is RMA
--decode(rt.customer_trx_id,null,'COST NO INV',decode(mta.transaction_source_type_id, 2, 'COST', 12, 'COST CM')),
        null cust_trx_line_gl_dist_id,
        mmt.transaction_id material_trx_id,
        ho.short_code Operating_Unit,
        nvl(rt.org_id,ho.organization_id),
        rbs.name invoice_source,
        rctt.name invoice_trx_type,
        otl.name order_type,
        rt.trx_number invoice_number,
        to_char(oh.order_number) order_number,
        xxar_revenue_recognition_disco.get_applied_invoice_info(rt.customer_trx_id) applied_to_inv_credit_ref,
        rt.purchase_order customer_po_number,
        rt.trx_date invoice_date,
        rctl.rule_start_date,
        rctl.rule_end_date,
        hp.party_name bill_to_customer,
        hca.account_number bill_to_cust_account_number,
        rs.name,
       (select min(al.meaning)
          from hz_code_assignments hcodeass, ar_lookups al
         where hcodeass.owner_table_id = hp.party_id
           and hcodeass.class_category = al.lookup_type
           and hcodeass.class_code = al.lookup_code
           and hcodeass.class_category = 'Objet Business Type'
           and hcodeass.status = 'A'
           and hcodeass.start_date_active <= sysdate
           and nvl(hcodeass.end_date_active, sysdate) >= sysdate
           and hcodeass.owner_table_name = 'HZ_PARTIES') Customer_Main_Business_type,
       hca.sales_channel_code sale_channel,
       rctl.line_number invoice_line,--
       l.accounting_date gl_date,
       msi.segment1 item,
       nvl(rctl.translated_description, rctl.description) description,
       decode (msi.serial_number_control_code,1,null,xxinv_utils_pkg.get_serials_and_lots(ol.line_id)) serial_number,--CHG0036330  change serial nums
       --mut.serial_number,
       --nvl(rctl.quantity_invoiced, rctl.quantity_credited) -- CHG0034115
       mta.primary_quantity quantity,
       rctl.uom_code uom_code,
       null entered_rev_amount,
       rt.invoice_currency_code  inv_curr,
       null accounted_rev_amount,
       -(nvl(l.accounted_dr, 0) - nvl(l.accounted_cr, 0))/(decode(mut.transaction_id,null,1,abs(mta.primary_quantity))) accounted_cogs_amount,
       gl.currency_code,
       null USD_rev_amount,
       -(nvl(l.accounted_dr, 0) - nvl(l.accounted_cr, 0))/(decode(mut.transaction_id,null,1,abs(mta.primary_quantity))) *
       gl_currency_api.get_closest_rate(gl.currency_code,
                                        'USD',
                                        mmt.transaction_date,
                                        'Corporate',
                                        10) USD_cogs_amount,
        (case--CHG0035659 add case to bring USD_IL_cogs_amount only if cost_element_id!=1
         when
         nvl(mta.cost_element_id,1)!=1
         then
         0
         else
           decode(fnd_profile.value('XXAR_ENABLE_SECURITY_COGS_REV_RECOG'),
              'N', -xxcst_ratam_pkg.get_IL_Std_Cost(81,  sysdate, mmt.inventory_item_id),
              null)* mta.primary_quantity
              end) USD_IL_cogs_amount ,
       gcc.segment1 comp_seg,
       gcc.segment2 depar_seg,
       gcc.segment3 account_seg,
       gcc.segment4 sub_acc_seg,
       gcc.segment5 pl_seg,
       gcc.segment6 loc_seg,
       gcc.segment7 ic_seg,
       gcc.segment8 proj_seg,
       gcc.segment9 futur_seg,
       xxgl_utils_pkg.get_dff_value_description(1013893, gcc.segment5) dist_prod_line_seg_desc,
       decode(substr(gcc.segment5, 1, 1),
              1, 'Systems',
              2, 'FDM-Systems',
              5, 'Consumables',
              7, 'FDM-Consumables',
              8, 'Customer Support',
              9, 'FDM-Maintenance and SP', 'Other') item_prod_line_parent,
       xxgl_utils_pkg.get_dff_value_description(1013892, gcc.segment6) dist_loc_seg_desc,
       (select (ffv.DESCRIPTION)
          from fnd_flex_value_children_v ffvc,
               fnd_flex_values_vl        ffv,
               fnd_flex_hierarchies      ffh
         where ffvc.flex_value_set_id = 1013892
           and ffvc.flex_value_set_id = ffh.FLEX_VALUE_SET_ID
           and ffh.flex_value_set_id = ffv.flex_value_set_id
           and ffh.hierarchy_id = ffv.STRUCTURED_HIERARCHY_LEVEL
           and ffvc.parent_flex_value = ffv.FLEX_VALUE
           and ffh.hierarchy_code = 'ACCOUNTING'
           and ffvc.flex_value = gcc.segment6) dist_cust_location_parent,
        rctl.customer_trx_line_id inv_line_id,
       h.period_name,
       null cogs_account, --for discoverer parameter
      xxar_sales_and_cogs_disco_pkg.get_ship_to_state(rt.ship_to_customer_id,
                                                       rt.ship_to_site_use_id) ship_to_state,
       xxar_sales_and_cogs_disco_pkg.get_ship_to_country(rt.ship_to_customer_id,
                                                         rt.ship_to_site_use_id) ship_to_country,
       null is_VSOE_Line
FROM   mtl_transaction_accounts     mta,
       org_organization_definitions odf,
       gl_code_combinations         gcc,
       xla_transaction_entities_upg u,
       xla_ae_headers               h,
       xla_ae_lines                 l,
       mtl_material_transactions    mmt,
       hr_operating_units           ho,
       oe_order_lines_all           ol,
       oe_order_headers_all         oh,
       ra_customer_trx_lines_all    rctl,
       ra_customer_trx_all          rt,
       ra_batch_sources_all         rbs,
       ra_cust_trx_types_all        rctt,
       hz_cust_accounts             hca,
       hz_parties                   hp,
       ra_salesreps                 rs,
       mtl_system_items_b           msi,
       mtl_unit_transactions        mut,
       Oe_Transaction_Types_Tl      otl,
       xla_distribution_links       xdl,
       gl_ledgers                   gl,
       ar_system_parameters         asp
 where l.accounting_date between xxar_sales_and_cogs_disco_pkg.get_start_date and xxar_sales_and_cogs_disco_pkg.get_end_date
   and odf.ORGANIZATION_ID = mta.organization_id
   and odf.OPERATING_UNIT = ho.organization_id
   and ho.organization_id = asp.org_id
   and nvl(rt.org_id,ho.organization_id)=ho.organization_id
   and gcc.code_combination_id = mta.reference_account
   and u.application_id = 707
   and nvl(u.source_id_int_1, -99) = mta.transaction_id
   and u.entity_code = 'MTL_ACCOUNTING_EVENTS'
   and u.security_id_int_1 = odf.ORGANIZATION_ID
   and u.security_id_int_2 = ho.organization_id
   and u.ledger_id = l.ledger_id
   and mta.transaction_source_type_id in (2, 12)
   and h.entity_id = u.entity_id
   and h.application_id = 707
   and mta.accounting_line_type in (2, 35,37)
   and l.ae_header_id = h.ae_header_id
   and l.code_combination_id = gcc.code_combination_id
   and mta.transaction_date between add_months(xxar_sales_and_cogs_disco_pkg.get_start_date,-1) and add_months(xxar_sales_and_cogs_disco_pkg.get_end_date,+1)
   and mmt.transaction_id = mta.transaction_id
   and ol.line_id = trx_source_line_id
   and rctl.interface_line_attribute6 (+)= to_char(ol.line_id)
   and rt.customer_trx_id (+)= rctl.customer_trx_id
   and rt.batch_source_id = rbs.batch_source_id(+)
   and rt.org_id = rbs.org_id(+)
   and rt.cust_trx_type_id = rctt.cust_trx_type_id(+)
   and rt.org_id = rctt.org_id(+)
   and oh.sold_to_org_id = hca.cust_account_id
   and hca.party_id = hp.party_id
   and rt.primary_salesrep_id = rs.salesrep_id(+)
   and rt.org_id = rs.org_id(+)
   and mmt.inventory_item_id = msi.inventory_item_id(+)
   and msi.organization_id(+) = xxinv_utils_pkg.get_master_organization_id
   and mmt.transaction_id = mut.transaction_id(+)
   and oh.header_id=ol.header_id
   and otl.transaction_type_id=oh.order_type_id
   and otl.language='US'
   and xdl.ae_line_num=l.ae_line_num
   and xdl.ae_header_id=l.ae_header_id
   and xdl.source_distribution_type='MTL_TRANSACTION_ACCOUNTS'
   and xdl.source_distribution_id_num_1=mta.inv_sub_ledger_id
   and gl.ledger_id=l.ledger_id
   and asp.accounting_method='ACCRUAL'
union all
SELECT 'COST OTHER',
       null cust_trx_line_gl_dist_id,
       mmt.transaction_id material_trx_id,
       ho.short_code Operating_Unit,
       ho.organization_id org_id,
       mtst.transaction_source_type_name || ', ' || flv_action.meaning trx_source,
       mtt.transaction_type_name || ', ' || flv_acct_type.meaning trx_type,
       null order_type,
       null invoice_number,
       null order_number,
       null applied_to_inv_credit_ref,
       null customer_po_number,
       null invoice_date,
       null rule_start_date,
       null rule_end_date,
       null bill_to_customer,
       null bill_to_cust_account_number,
       null sale_person_name,
       null Customer_Main_Business_type,
       null sale_channel,
       null invoice_line,
       l.accounting_date gl_date, -- CHG0034115
       msi.segment1 item,
       msi.description description,
       mut.serial_number,
       --nvl(rctl.quantity_invoiced, rctl.quantity_credited) -- CHG0034115
       mta.primary_quantity invoice_line_quantity,
       mmt.transaction_uom,
       null entered_rev_amount,
       null inv_curr,
       null accounted_rev_amount,
       -(nvl(l.accounted_dr, 0) - nvl(l.accounted_cr, 0))/(decode(mut.transaction_id,null,1,abs(mta.primary_quantity))) accounted_cogs_amount,
       gl.currency_code,
       null USD_rev_amount,
       -(nvl(l.accounted_dr, 0) - nvl(l.accounted_cr, 0))/(decode(mut.transaction_id,null,1,abs(mta.primary_quantity))) *
       gl_currency_api.get_closest_rate(gl.currency_code,
                                        'USD',
                                        mmt.transaction_date,
                                        'Corporate',
                                        10) USD_cogs_amount,
        (case
         when
         nvl(mta.cost_element_id,1)!=1
         then
         0
         else
           decode(fnd_profile.value('XXAR_ENABLE_SECURITY_COGS_REV_RECOG'),
              'N', -xxcst_ratam_pkg.get_IL_Std_Cost(81, sysdate, mmt.inventory_item_id),
              null)* mta.primary_quantity
        end) USD_IL_cogs_amount,
       gcc.segment1 comp_seg,
       gcc.segment2 depar_seg,
       gcc.segment3 account_seg,
       gcc.segment4 sub_acc_seg,
       gcc.segment5 pl_seg,
       gcc.segment6 loc_seg,
       gcc.segment7 ic_seg,
       gcc.segment8 proj_seg,
       gcc.segment9 futur_seg,
       xxgl_utils_pkg.get_dff_value_description(1013893, gcc.segment5) dist_prod_line_seg_desc,
       decode(substr(gcc.segment5, 1, 1),
              1, 'Systems',
              2, 'FDM-Systems',
              5, 'Consumables',
              7, 'FDM-Consumables',
              8, 'Customer Support',
              9, 'FDM-Maintenance and SP', 'Other') item_prod_line_parent,
       xxgl_utils_pkg.get_dff_value_description(1013892, gcc.segment6) dist_loc_seg_desc,
       (select (ffv.DESCRIPTION)
          from fnd_flex_value_children_v ffvc,
               fnd_flex_values_vl        ffv,
               fnd_flex_hierarchies      ffh
         where ffvc.flex_value_set_id = 1013892
           and ffvc.flex_value_set_id = ffh.FLEX_VALUE_SET_ID
           and ffh.flex_value_set_id = ffv.flex_value_set_id
           and ffh.hierarchy_id = ffv.STRUCTURED_HIERARCHY_LEVEL
           and ffvc.parent_flex_value = ffv.FLEX_VALUE
           and ffh.hierarchy_code = 'ACCOUNTING'
           and ffvc.flex_value = gcc.segment6) dist_cust_location_parent,
       null inv_line_id,
       h.period_name,
       null cogs_account, --for discoverer parameter
       null ship_to_state,
       null ship_to_country,
       null is_VSOE_Line
  FROM mtl_transaction_accounts     mta,
       org_organization_definitions odf,
       gl_code_combinations         gcc,
       xla_transaction_entities_upg u,
       xla_ae_headers               h,
       xla_ae_lines                 l,
       mtl_material_transactions    mmt,
       hr_operating_units           ho,
       mtl_txn_source_types         mtst,
       mtl_transaction_types mtt,
       fnd_lookup_values            flv_action,
       mtl_system_items_b           msi,
       mtl_unit_transactions        mut,
       fnd_lookup_values            flv_acct_type,
       xla_distribution_links xdl,
       gl_ledgers gl,
       ar_system_parameters asp
 where l.accounting_date between xxar_sales_and_cogs_disco_pkg.get_start_date and xxar_sales_and_cogs_disco_pkg.get_end_date
   and odf.ORGANIZATION_ID = mta.organization_id
   and odf.OPERATING_UNIT = ho.organization_id
   and ho.organization_id = asp.org_id
   and gcc.code_combination_id = mta.reference_account
   and u.application_id = 707
   and nvl(u.source_id_int_1, -99) = mta.transaction_id
   and u.entity_code = 'MTL_ACCOUNTING_EVENTS'
   and u.security_id_int_1 = odf.ORGANIZATION_ID
   and u.security_id_int_2 = ho.organization_id
   and u.ledger_id = l.ledger_id
   and mta.transaction_source_type_id in (3, 4,8, 7,13)
   and h.entity_id = u.entity_id
   and h.application_id = 707
   and mta.accounting_line_type in (2, 35,37)
   and l.ae_header_id = h.ae_header_id
   and l.code_combination_id = gcc.code_combination_id
   and mta.transaction_date between add_months(xxar_sales_and_cogs_disco_pkg.get_start_date,-1) and add_months(xxar_sales_and_cogs_disco_pkg.get_end_date,+1)
   and mmt.transaction_id = mta.transaction_id
   and mta.transaction_source_type_id = mtst.transaction_source_type_id
   and mmt.inventory_item_id = msi.inventory_item_id(+)
   and msi.organization_id(+) = xxinv_utils_pkg.get_master_organization_id
   and mmt.transaction_id = mut.transaction_id(+)
   and flv_action.lookup_type = 'MTL_TRANSACTION_ACTION'
   and mmt.transaction_action_id = flv_action.lookup_code
   and flv_action.language = 'US'
   and flv_acct_type.LOOKUP_TYPE = 'CST_ACCOUNTING_LINE_TYPE'
   and mta.accounting_line_type = flv_acct_type.lookup_code
   and flv_acct_type.language = 'US'
   and mmt.transaction_type_id = mtt.transaction_type_id
   and xdl.ae_line_num=l.ae_line_num
   and xdl.ae_header_id=l.ae_header_id
   and xdl.source_distribution_type='MTL_TRANSACTION_ACCOUNTS'
   and xdl.source_distribution_id_num_1=mta.inv_sub_ledger_id
   and asp.accounting_method='ACCRUAL'
   and gl.ledger_id=l.ledger_id
   union all
   SELECT decode(rt.customer_trx_id, null, 'COST NO INV', 'COST'),
       null cust_trx_line_gl_dist_id,
       mmt.transaction_id material_trx_id,
       ho.short_code,
       ho.organization_id,
       rbs.name invoice_source,
       rctt.name invoice_trx_type,
       otl.name order_type,
       rt.trx_number invoice_number,
       to_char(h.order_number) order_number,
       xxar_revenue_recognition_disco.get_applied_invoice_info(rt.customer_trx_id) applied_to_inv_credit_ref,
       rt.purchase_order customer_po_number,
       rt.trx_date invoice_date,
       rctl.rule_start_date,
       rctl.rule_end_date,
       hp.party_name bill_to_customer,
       hca.account_number bill_to_cust_account_number,
       rs.name,
       (select min(al.meaning)
          from hz_code_assignments hcodeass, ar_lookups al
         where hcodeass.owner_table_id = hp.party_id
           and hcodeass.class_category = al.lookup_type
           and hcodeass.class_code = al.lookup_code
           and hcodeass.class_category = 'Objet Business Type'
           and hcodeass.status = 'A'
           and hcodeass.start_date_active <= sysdate
           and nvl(hcodeass.end_date_active, sysdate) >= sysdate
           and hcodeass.owner_table_name = 'HZ_PARTIES') Customer_Main_Business_type,
       hca.sales_channel_code sale_channel,
       rctl.line_number invoice_line,
       ail.accounting_date,
       mb.segment1,
       nvl(rctl.translated_description, rctl.description) description,
         decode (mb.serial_number_control_code,1,null,xxinv_utils_pkg.get_serials_and_lots(oel.line_id)) serial_number,--CHG0036330  change serial nums
      -- mut.serial_number,
       -mmt.primary_quantity quantity,
       rctl.uom_code uom_code,
       null entered_rev_amount,
       rt.invoice_currency_code inv_curr,
       null accounted_rev_amount,
       -nvl(ail.base_amount, ail.amount) accounted_cogs_amount,
       gl.currency_code,
       null USD_rev_amount,
       -nvl(ail.base_amount, ail.amount) *
       gl_currency_api.get_closest_rate(gl.currency_code,
                                        'USD',
                                        mmt.transaction_date,
                                        'Corporate',
                                        10) USD_cogs_amount,
       decode(fnd_profile.value('XXAR_ENABLE_SECURITY_COGS_REV_RECOG'),
              'N', -xxcst_ratam_pkg.get_IL_Std_Cost(81, sysdate, mmt.inventory_item_id),
              null)* mmt.primary_quantity USD_IL_cogs_amount,
       gcc.segment1 comp_seg,
       gcc.segment2 depar_seg,
       gcc.segment3 account_seg,
       gcc.segment4 sub_acc_seg,
       gcc.segment5 pl_seg,
       gcc.segment6 loc_seg,
       gcc.segment7 ic_seg,
       gcc.segment8 proj_seg,
       gcc.segment9 futur_seg,
       xxgl_utils_pkg.get_dff_value_description(1013893, gcc.segment5) dist_prod_line_seg_desc,
       decode(substr(gcc.segment5, 1, 1),
              1,'Systems',
              2,'FDM-Systems',
              5,'Consumables',
              7,'FDM-Consumables',
              8,'Customer Support',
              9,'FDM-Maintenance and SP',
              'Other') item_prod_line_parent,
       xxgl_utils_pkg.get_dff_value_description(1013892, gcc.segment6) dist_loc_seg_desc,
       (select (ffv.DESCRIPTION)
          from fnd_flex_value_children_v ffvc,
               fnd_flex_values_vl        ffv,
               fnd_flex_hierarchies      ffh
         where ffvc.flex_value_set_id = 1013892
           and ffvc.flex_value_set_id = ffh.FLEX_VALUE_SET_ID
           and ffh.flex_value_set_id = ffv.flex_value_set_id
           and ffh.hierarchy_id = ffv.STRUCTURED_HIERARCHY_LEVEL
           and ffvc.parent_flex_value = ffv.FLEX_VALUE
           and ffh.hierarchy_code = 'ACCOUNTING'
           and ffvc.flex_value = gcc.segment6) dist_cust_location_parent,
       rctl.customer_trx_line_id inv_line_id,
       ail.period_name,
       null cogs_account, --for discoverer parameter
       xxar_sales_and_cogs_disco_pkg.get_ship_to_state(rt.ship_to_customer_id,
                                                       rt.ship_to_site_use_id) ship_to_state,
       xxar_sales_and_cogs_disco_pkg.get_ship_to_country(rt.ship_to_customer_id,
                                                         rt.ship_to_site_use_id) ship_to_country,
       null is_VSOE_Line
  FROM oe_order_headers_all      h,
       oe_order_lines_all        oel,
       mtl_material_transactions mmt,
       ap_invoice_lines_all      ail,
       ar_system_parameters  asp,
       gl_code_combinations      gcc,
       hr_operating_units        ho,
       mtl_system_items_b        mb,
       mtl_unit_transactions     mut,
       ra_customer_trx_lines_all rctl,
       ra_customer_trx_all       rt,
       ra_batch_sources_all      rbs,
       ra_cust_trx_types_all     rctt,
       Oe_Transaction_Types_Tl   otl,
       hz_cust_accounts          hca,
       hz_parties                hp,
       ra_salesreps              rs,
       gl_ledgers                gl
 where oel.header_id = h.header_id
   and mmt.trx_source_line_id = oel.line_id
   and ail.reference_2 = mmt.transaction_id
   and mmt.transaction_id = ail.reference_2(+)
   and ail.org_id = asp.org_id
   and oel.org_id = asp.org_id
   and asp.accounting_method = 'ACCRUAL'
   and ho.organization_id = asp.org_id
   and mmt.transaction_source_type_id = 2
   and mmt.transaction_type_id = 33
   and mmt.transaction_action_id = 1
   and mmt.transaction_date between add_months(xxar_sales_and_cogs_disco_pkg.get_start_date,-1) and add_months(xxar_sales_and_cogs_disco_pkg.get_end_date,+1)
   and ail.accounting_date(+) between xxar_sales_and_cogs_disco_pkg.get_start_date and xxar_sales_and_cogs_disco_pkg.get_end_date
   and gcc.code_combination_id = ail.default_dist_ccid
   and mb.organization_id = mmt.organization_id
   and mb.inventory_item_id = mmt.inventory_item_id
   and rctl.org_id(+) = oel.org_id
   and rctl.interface_line_attribute6(+) = to_char(oel.line_id)
   and rt.customer_trx_id(+) = rctl.customer_trx_id
   and rt.batch_source_id = rbs.batch_source_id(+)
   and rt.org_id = rbs.org_id(+)
   and rt.cust_trx_type_id = rctt.cust_trx_type_id(+)
   and rt.org_id = rctt.org_id(+)
   and otl.transaction_type_id = h.order_type_id
   and otl.language = 'US'
   and h.sold_to_org_id = hca.cust_account_id
   and hca.party_id = hp.party_id
   and rt.primary_salesrep_id = rs.salesrep_id(+)
   and rt.org_id = rs.org_id(+)
   and mmt.transaction_id = mut.transaction_id(+)
   and gl.ledger_id = ail.set_of_books_id
   union all  --  CHG0035659 bring lines when STD cost is Zero
   SELECT decode(rt.customer_trx_id, null, 'COST NO INV', 'COST'),
       null cust_trx_line_gl_dist_id,
       mmt.transaction_id material_trx_id,
       ho.short_code,
       ho.organization_id,
       rbs.name invoice_source,
       rctt.name invoice_trx_type,
       otl.name order_type,
       rt.trx_number invoice_number,
       to_char(h.order_number) order_number,
       xxar_revenue_recognition_disco.get_applied_invoice_info(rt.customer_trx_id) applied_to_inv_credit_ref,
       rt.purchase_order customer_po_number,
       rt.trx_date invoice_date,
       rctl.rule_start_date,
       rctl.rule_end_date,
       hp.party_name bill_to_customer,
       hca.account_number bill_to_cust_account_number,
       rs.name,
       (select min(al.meaning)
          from hz_code_assignments hcodeass, ar_lookups al
         where hcodeass.owner_table_id = hp.party_id
           and hcodeass.class_category = al.lookup_type
           and hcodeass.class_code = al.lookup_code
           and hcodeass.class_category = 'Objet Business Type'
           and hcodeass.status = 'A'
           and hcodeass.start_date_active <= sysdate
           and nvl(hcodeass.end_date_active, sysdate) >= sysdate
           and hcodeass.owner_table_name = 'HZ_PARTIES') Customer_Main_Business_type,
       hca.sales_channel_code sale_channel,
       rctl.line_number invoice_line,
       mmt.transaction_date,
       mb.segment1,
       nvl(rctl.translated_description, rctl.description) description,
        decode (mb.serial_number_control_code,1,null,xxinv_utils_pkg.get_serials_and_lots(oel.line_id)) serial_number,--CHG0036330  change serial nums
      -- mut.serial_number,
       -mmt.primary_quantity quantity,
       rctl.uom_code uom_code,
       null entered_rev_amount,
       rt.invoice_currency_code inv_curr,
       null accounted_rev_amount,
       0 accounted_cogs_amount,
       h.transactional_curr_code currency_code,
       null USD_rev_amount,
       0 USD_cogs_amount,
        decode(fnd_profile.value('XXAR_ENABLE_SECURITY_COGS_REV_RECOG'),
              'N', -xxcst_ratam_pkg.get_IL_Std_Cost(81, sysdate, mmt.inventory_item_id),
              null)*mmt.primary_quantity USD_IL_cogs_amount,
       gcc.segment1 comp_seg,
       gcc.segment2 depar_seg,
       gcc.segment3 account_seg,
       gcc.segment4 sub_acc_seg,
       gcc.segment5 pl_seg,
       gcc.segment6 loc_seg,
       gcc.segment7 ic_seg,
       gcc.segment8 proj_seg,
       gcc.segment9 futur_seg,
       xxgl_utils_pkg.get_dff_value_description(1013893, gcc.segment5) dist_prod_line_seg_desc,
       decode(substr(gcc.segment5, 1, 1),
              1,'Systems',
              2,'FDM-Systems',
              5,'Consumables',
              7,'FDM-Consumables',
              8,'Customer Support',
              9,'FDM-Maintenance and SP',
              'Other') item_prod_line_parent,
       xxgl_utils_pkg.get_dff_value_description(1013892, gcc.segment6) dist_loc_seg_desc,
       (select (ffv.DESCRIPTION)
          from fnd_flex_value_children_v ffvc,
               fnd_flex_values_vl        ffv,
               fnd_flex_hierarchies      ffh
         where ffvc.flex_value_set_id = 1013892
           and ffvc.flex_value_set_id = ffh.FLEX_VALUE_SET_ID
           and ffh.flex_value_set_id = ffv.flex_value_set_id
           and ffh.hierarchy_id = ffv.STRUCTURED_HIERARCHY_LEVEL
           and ffvc.parent_flex_value = ffv.FLEX_VALUE
           and ffh.hierarchy_code = 'ACCOUNTING'
           and ffvc.flex_value = gcc.segment6) dist_cust_location_parent,
       rctl.customer_trx_line_id inv_line_id,
       to_char(mmt.transaction_date, 'MON-YY'),
       null cogs_account, --for discoverer parameter
       xxar_sales_and_cogs_disco_pkg.get_ship_to_state(rt.ship_to_customer_id,
                                                       rt.ship_to_site_use_id) ship_to_state,
       xxar_sales_and_cogs_disco_pkg.get_ship_to_country(rt.ship_to_customer_id,
                                                         rt.ship_to_site_use_id) ship_to_country,
       null is_VSOE_Line
  FROM oe_order_headers_all      h,
       oe_order_lines_all        oel,
       mtl_material_transactions mmt,
       ar_system_parameters  asp,
       gl_code_combinations      gcc,
       hr_operating_units        ho,
       mtl_system_items_b        mb,
       mtl_unit_transactions     mut,
       ra_customer_trx_lines_all rctl,
       ra_customer_trx_all       rt,
       ra_batch_sources_all      rbs,
       ra_cust_trx_types_all     rctt,
       Oe_Transaction_Types_Tl   otl,
       hz_cust_accounts          hca,
       hz_parties                hp,
       ra_salesreps              rs
 where oel.header_id = h.header_id
   and mmt.trx_source_line_id = oel.line_id
   and oel.org_id = asp.org_id
   and asp.accounting_method = 'ACCRUAL'
   and ho.organization_id = asp.org_id
   and mmt.transaction_source_type_id = 2
   and mmt.transaction_type_id = 33
   and mmt.transaction_action_id = 1
   and mmt.transaction_date between  xxar_sales_and_cogs_disco_pkg.get_start_date and xxar_sales_and_cogs_disco_pkg.get_end_date
   and mb.organization_id = mmt.organization_id
   and mb.inventory_item_id = mmt.inventory_item_id
   and rctl.org_id(+) = oel.org_id
   and rctl.interface_line_attribute6(+) = to_char(oel.line_id)
   and rt.customer_trx_id(+) = rctl.customer_trx_id
   and rt.batch_source_id = rbs.batch_source_id(+)
   and rt.org_id = rbs.org_id(+)
   and rt.cust_trx_type_id = rctt.cust_trx_type_id(+)
   and rt.org_id = rctt.org_id(+)
   and otl.transaction_type_id = h.order_type_id
   and otl.language = 'US'
   and h.sold_to_org_id = hca.cust_account_id
   and hca.party_id = hp.party_id
   and rt.primary_salesrep_id = rs.salesrep_id(+)
   and rt.org_id = rs.org_id(+)
   and mmt.transaction_id = mut.transaction_id(+)
   and gcc.code_combination_id=mmt.distribution_account_id
   and mmt.actual_cost = 0;
