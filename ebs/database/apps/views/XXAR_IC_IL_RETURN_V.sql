CREATE OR REPLACE VIEW XXAR_IC_IL_RETURN_V AS
(
----------------------------------------------------------------------------------
-- Ver        When         Who           Description
-- ---------  -----------  ------------  -----------------------------------------
-- 1.0        25-07-2018   Ofer S.       CHG0042557
----------------------------------------------------------------------------------
SELECT aia.org_id,
       gp.period_name ,
      gll.name Ledger,
       'Other' Category,
       'Spreadsheet' Source,
       aia.invoice_currency_code Currency,
       aid.accounting_date "Accounting Date",
       gcci.segment1 Company,
       gcc.segment2 Department,
       '401113' Account, --gcc.segment3,
       gcci.segment4 Location,
       gcc.segment5 Product,
       gcc.segment6 "Sub Account",
       gcc.segment1 Intercompany,
       gcci.segment8 Project,
       gcci.segment9 Future,
       aid.amount Debit,
       null Credit,
       'Corporate' "Conversion Type",
       aid.accounting_date "Conversion Date",
       null "Conversion Rate",
       'Return JE For ' || gp.period_name "Batch Name",
       'Return JE For ' || gp.period_name "Batch Description",
       'Return JE For ' || gp.period_name "Journal Name",
       'Return JE For ' || gp.period_name "Journal Description",
       'Intercompany return Invoice Number ' || aia.invoice_num "Line Description"
  FROM ap_invoices_all              aia,
       ap_invoice_distributions_all aid,
       gl_periods                   gp,
       gl_ledgers                   gll,
       mtl_material_transactions    mmt,
       mtl_system_items_b           mb,
       gl_code_combinations         gcc,
       gl_code_combinations         gcci,
       ap_invoice_lines_all         ail,
       ra_customer_trx_lines_all    ril
 where source = 'Intercompany'
  -- and aia.org_id = 81
   and aid.invoice_id = aia.invoice_id
   and aid.invoice_id = ail.invoice_id
   and ail.line_number = aid.invoice_line_number
  -- and gp.period_name = 'FEB-18'
   and aid.accounting_date between gp.start_date and gp.end_date
   and gll.ledger_id = aia.set_of_books_id
   and mmt.transaction_id = aid.reference_2
   and mb.inventory_item_id = mmt.inventory_item_id
   and mb.organization_id = mmt.organization_id
   and gcc.code_combination_id = mb.sales_account
   and gcci.code_combination_id = aid.dist_code_combination_id
   and ril.customer_trx_line_id = ail.source_line_id
   and (not exists
        (SELECT 1
           FROM fnd_flex_value_sets fvs, fnd_flex_values ffv
          where fvs.flex_value_set_name = 'XXPB_OPERATING_UNITS'
            and ffv.flex_value_set_id = fvs.flex_value_set_id
            and ffv.attribute1 = ril.org_id
            and ffv.attribute2 = 'Y') or
        (aia.org_id = 81 and ril.org_id = 737 and mb.attribute2 = 'IL') or
        (ril.org_id = 737 and ril.interface_line_attribute4 = 81 and
        xxinv_item_classification.is_item_polyjet(ril.inventory_item_id) = 'Y') or
        (aia.org_id = 737 and ril.org_id = '81' and mb.attribute2 = 'US'))
union all
SELECT aia.org_id,
       gp.period_name ,
       gll.name,
       'Other',
       'Spreadsheet',
       aia.invoice_currency_code,
       aid.accounting_date,
       gcci.segment1,
       gcc.segment2,
       '501045',
       gcci.segment4,
       gcc.segment5,
       gcc.segment6,
       gcc.segment1,
       gcci.segment8,
       gcci.segment9,
       null,
       case
         when gcci.segment3 =
              (SELECT gcc.segment3
                 FROM MTL_PARAMETERS_VIEW MPA, gl_code_combinations gcc
                WHERE organization_id = mmt.organization_id
                  and gcc.code_combination_id = mpa.AP_ACCRUAL_ACCOUNT) then
          round(ril.quantity_invoiced *
                xxcst_ratam_pkg.get_il_std_cost(null,
                                                aid.accounting_date,
                                                mb.inventory_item_id) /
                nvl(aia.exchange_rate,1),
                2)
         else
          aid.amount
       end,
       'Corporate',
       aid.accounting_date,
       null,
       'Return JE For ' || gp.period_name,
       'Return JE For ' || gp.period_name,
       'Return JE For ' || gp.period_name,
       'Return JE For ' || gp.period_name,
       'Intercompany return Invoice Number ' || aia.invoice_num
  FROM ap_invoices_all              aia,
       ap_invoice_distributions_all aid,
       gl_periods                   gp,
       gl_ledgers                   gll,
       mtl_material_transactions    mmt,
       mtl_system_items_b           mb,
       gl_code_combinations         gcc,
       gl_code_combinations         gcci,
       ap_invoice_lines_all         ail,
       ra_customer_trx_lines_all    ril
 where source = 'Intercompany'
 --  and aia.org_id = 81
   and aid.invoice_id = aia.invoice_id
   and aid.invoice_id = ail.invoice_id
   and ail.line_number = aid.invoice_line_number
   --and gp.period_name = 'FEB-18'
   and aid.accounting_date between gp.start_date and gp.end_date
   and gll.ledger_id = aia.set_of_books_id
   and mmt.transaction_id = aid.reference_2
   and mb.inventory_item_id = mmt.inventory_item_id
   and mb.organization_id = mmt.organization_id
   and gcc.code_combination_id = mb.cost_of_sales_account
   and gcci.code_combination_id = aid.dist_code_combination_id
   and ril.customer_trx_line_id = ail.source_line_id
   and (not exists
        (SELECT 1
           FROM fnd_flex_value_sets fvs, fnd_flex_values ffv
          where fvs.flex_value_set_name = 'XXPB_OPERATING_UNITS'
            and ffv.flex_value_set_id = fvs.flex_value_set_id
            and ffv.attribute1 = ril.org_id
            and ffv.attribute2 = 'Y') or
        (aia.org_id = 81 and ril.org_id = 737 and mb.attribute2 = 'IL') or
        (ril.org_id = 737 and ril.interface_line_attribute4 = 81 and
        xxinv_item_classification.is_item_polyjet(ril.inventory_item_id) = 'Y') or
        (aia.org_id = 737 and ril.org_id = '81' and mb.attribute2 = 'US'))
union all
SELECT aia.org_id,
       gp.period_name ,
       gll.name,
       'Other',
       'Spreadsheet',
       aia.invoice_currency_code,
       aid.accounting_date,
       gcci.segment1,
       gcc.segment2,
       gcc.segment3,
       gcci.segment4,
       gccitem.segment5,
       gcc.segment6,
       gcci.segment7,
       gcci.segment8,
       gcci.segment9,
       null,
       case
         when gcci.segment3 =
              (SELECT gcc.segment3
                 FROM MTL_PARAMETERS_VIEW MPA, gl_code_combinations gcc
                WHERE organization_id = mmt.organization_id
                  and gcc.code_combination_id = mpa.AP_ACCRUAL_ACCOUNT) then
          aid.amount - round(ril.quantity_invoiced *
                             xxcst_ratam_pkg.get_il_std_cost(null,
                                                             aid.accounting_date,
                                                             mb.inventory_item_id) /
                             nvl(aia.exchange_rate,1),
                             2)
         else
          0
       end,
        'Corporate',
       aid.accounting_date,
       null,
       'Return JE For ' || gp.period_name,
       'Return JE For ' || gp.period_name,
       'Return JE For ' || gp.period_name,
       'Return JE For ' || gp.period_name,
       'Intercompany return Invoice Number ' || aia.invoice_num
  FROM ap_invoices_all              aia,
       ap_invoice_distributions_all aid,
       gl_periods                   gp,
       gl_ledgers                   gll,
       mtl_material_transactions    mmt,
       mtl_system_items_b           mb,
       gl_code_combinations         gcc,
       mtl_shipping_network_view    msnv,
       --mtl_parameters               mp,
       gl_code_combinations      gcci,
       gl_code_combinations      gccitem,
       ap_invoice_lines_all      ail,
       ra_customer_trx_lines_all ril
 where source = 'Intercompany'
   --and aia.org_id = 81
   and aid.invoice_id = aia.invoice_id
   and aid.invoice_id = ail.invoice_id
   and ail.line_number = aid.invoice_line_number
  -- and gp.period_name = 'FEB-18'
   and aid.accounting_date between gp.start_date and gp.end_date
   and gll.ledger_id = aia.set_of_books_id
   and mmt.transaction_id = aid.reference_2
   and mb.inventory_item_id = mmt.inventory_item_id
   and mb.organization_id = mmt.organization_id
   and gccitem.code_combination_id = mb.sales_account
   and msnv.FROM_organization_id = mmt.organization_id
   and gcc.code_combination_id = msnv.INTERORG_PRICE_VAR_ACCOUNT
   and msnv.tO_organization_id = mmt.transfer_organization_id
   and gcci.code_combination_id = aid.dist_code_combination_id
   and ril.customer_trx_line_id = ail.source_line_id
   and (not exists
        (SELECT 1
           FROM fnd_flex_value_sets fvs, fnd_flex_values ffv
          where fvs.flex_value_set_name = 'XXPB_OPERATING_UNITS'
            and ffv.flex_value_set_id = fvs.flex_value_set_id
            and ffv.attribute1 = ril.org_id
            and ffv.attribute2 = 'Y') or
        (aia.org_id = 81 and ril.org_id = 737 and mb.attribute2 = 'IL') or
        (ril.org_id = 737 and ril.interface_line_attribute4 = 81 and
        xxinv_item_classification.is_item_polyjet(ril.inventory_item_id) = 'Y') or
        (aia.org_id = 737 and ril.org_id = '81' and mb.attribute2 = 'US')))
        union all
        SELECT aia.org_id,
       gp.period_name,
       gll.name Ledger,
       'Other' Category,
       'Spreadsheet' Source,
       aia.invoice_currency_code Currency,
       aid.accounting_date "Accounting Date",
       gcci.segment1 Company,
       gcci.segment2 Department,
       gcci.segment3,
       gcci.segment4 Location,
       gcci.segment5 Product,
       gcci.segment6 "Sub Account",
       gcci.segment7 Intercompany,
       gcci.segment8 Project,
       gcci.segment9 Future,      
       -mta.base_transaction_value- aid.amount Debit,
       null Credit,
       'Corporate' "Conversion Type",
       aid.accounting_date "Conversion Date",
       null "Conversion Rate",
       'Return JE For ' || gp.period_name "Batch Name",
       'Return JE For ' || gp.period_name "Batch Description",
       'Return JE For ' || gp.period_name "Journal Name",
       'Return JE For ' || gp.period_name "Journal Description",
       'Intercompany return Invoice Number ' || aia.invoice_num "Line Description"
  FROM ap_invoices_all              aia,
       ap_invoice_distributions_all aid,
       gl_periods                   gp,
       gl_ledgers                   gll,
       mtl_material_transactions    mmt,
       mtl_system_items_b           mb,
       mtl_item_categories_v        mc,
       mtl_category_sets            mts,
       gl_code_combinations         gcci,
       ap_invoice_lines_all         ail,
       ra_customer_trx_lines_all    ril,
       mtl_transaction_accounts mta
 where source = 'Intercompany'
  -- and aia.org_id = 81
      -- and ='5014512'
   and aid.invoice_id = aia.invoice_id
   and aid.invoice_id = ail.invoice_id
   and ail.line_number = aid.invoice_line_number
   --and gp.period_name = 'JUN-18'
  -- and ril.org_id = 737
   and aid.accounting_date between gp.start_date and gp.end_date
   and gll.ledger_id = aia.set_of_books_id
   and mmt.transaction_id = aid.reference_2
   and mb.inventory_item_id = mmt.inventory_item_id
   and mb.organization_id = mmt.organization_id
      -- and gcc.code_combination_id = mb.sales_account
   and gcci.code_combination_id = aid.dist_code_combination_id
   and ril.customer_trx_line_id = ail.source_line_id
   and mc.organization_id = xxinv_utils_pkg.get_master_organization_id
   and mc.inventory_item_id = ril.inventory_item_id
   and mc.SEGMENT2 = to_char(ril.org_id)
   and mc.SEGMENT1 = to_char(aid.org_id)
   and mts.CATEGORY_SET_ID = mc.Category_Set_Id
   and mta.transaction_id=mmt.transaction_id
   and mta.reference_account=aid.dist_code_combination_id
   and mts.CATEGORY_SET_NAME = 'XX IP Operating Units'
   and -mta.base_transaction_value- aid.amount<>0
   and (not exists
        (SELECT 1
           FROM fnd_flex_value_sets fvs, fnd_flex_values ffv
          where fvs.flex_value_set_name = 'XXPB_OPERATING_UNITS'
            and ffv.flex_value_set_id = fvs.flex_value_set_id
            and ffv.attribute1 = ril.org_id
            and ffv.attribute2 = 'Y') or
        (aia.org_id = 81 and ril.org_id = 737 and mb.attribute2 = 'IL') or
        (ril.org_id = 737 and ril.interface_line_attribute4 = 81 and
        xxinv_item_classification.is_item_polyjet(ril.inventory_item_id) = 'Y') or
        (aia.org_id = 737 and ril.org_id = '81' and mb.attribute2 = 'US'))
--and  aid.amount !=ril.extended_amount
union all
  SELECT aia.org_id,
       gp.period_name,
       gll.name Ledger,
       'Other' Category,
       'Spreadsheet' Source,
       aia.invoice_currency_code Currency,
       aid.accounting_date "Accounting Date",
       gccinv.segment1 Company,
       gcci.segment2 Department,
       gcc.segment3,
       gcci.segment4 Location,
       gcci.segment5 Product,
       gcci.segment6 "Sub Account",
       gccinv.segment7 Intercompany,
       gcci.segment8 Project,
       gcci.segment9 Future,      
       null Debit,
       -mta.base_transaction_value- aid.amount Credit,
       'Corporate' "Conversion Type",
       aid.accounting_date "Conversion Date",
       null "Conversion Rate",
       'Return JE For ' || gp.period_name "Batch Name",
       'Return JE For ' || gp.period_name "Batch Description",
       'Return JE For ' || gp.period_name "Journal Name",
       'Return JE For ' || gp.period_name "Journal Description",
       'Intercompany return Invoice Number ' || aia.invoice_num "Line Description"
  FROM ap_invoices_all              aia,
       ap_invoice_distributions_all aid,
       gl_periods                   gp,
       gl_ledgers                   gll,
       mtl_material_transactions    mmt,
       mtl_system_items_b           mb,
       mtl_item_categories_v        mc,
       mtl_category_sets            mts,
       gl_code_combinations         gcci,
       gl_code_combinations         gcc,
       gl_code_combinations         gccinv,
       ap_invoice_lines_all         ail,
       ra_customer_trx_lines_all    ril,
       mtl_transaction_accounts mta,
       mtl_shipping_network_view    msnv
 where source = 'Intercompany'
  -- and aia.org_id = 81
      -- and ='5014512'
   and aid.invoice_id = aia.invoice_id
   and aid.invoice_id = ail.invoice_id
   and ail.line_number = aid.invoice_line_number
   --and gp.period_name = 'JUN-18'
  -- and ril.org_id = 737
   and aid.accounting_date between gp.start_date and gp.end_date
   and gll.ledger_id = aia.set_of_books_id
   and mmt.transaction_id = aid.reference_2
   and mb.inventory_item_id = mmt.inventory_item_id
   and mb.organization_id = mmt.organization_id
   and gccinv.code_combination_id = aid.dist_code_combination_id
   and gcci.code_combination_id = mb.cost_of_sales_account
   and ril.customer_trx_line_id = ail.source_line_id
   and mc.organization_id = xxinv_utils_pkg.get_master_organization_id
   and mc.inventory_item_id = ril.inventory_item_id
   and mc.SEGMENT2 = to_char(ril.org_id)
   and mc.SEGMENT1 = to_char(aid.org_id)
   and mts.CATEGORY_SET_ID = mc.Category_Set_Id
   and mta.transaction_id=mmt.transaction_id
   and mta.reference_account=aid.dist_code_combination_id
   and mts.CATEGORY_SET_NAME = 'XX IP Operating Units'
   and -mta.base_transaction_value- aid.amount<>0
   and msnv.FROM_organization_id = mmt.organization_id
   and gcc.code_combination_id = msnv.INTERORG_PRICE_VAR_ACCOUNT
   and msnv.tO_organization_id = mmt.transfer_organization_id
   and (not exists
        (SELECT 1
           FROM fnd_flex_value_sets fvs, fnd_flex_values ffv
          where fvs.flex_value_set_name = 'XXPB_OPERATING_UNITS'
            and ffv.flex_value_set_id = fvs.flex_value_set_id
            and ffv.attribute1 = ril.org_id
            and ffv.attribute2 = 'Y') or
        (aia.org_id = 81 and ril.org_id = 737 and mb.attribute2 = 'IL') or
        (ril.org_id = 737 and ril.interface_line_attribute4 = 81 and
        xxinv_item_classification.is_item_polyjet(ril.inventory_item_id) = 'Y') or
        (aia.org_id = 737 and ril.org_id = '81' and mb.attribute2 = 'US'))
;
