CREATE OR REPLACE VIEW XXBI_XLA_TRANSACTIONS_V AS
SELECT
----------------------------------------------------------------------------------------------------
-- Ver      When         Who           Description
-- -------  -----------  ------------  -------------------------------------------------------------
-- 1.0      25-Sep-2018  Offer S.      CHG0044007-Map in Oracle XLA upload program and BI view for
--                                         project details associated for move orders.
--                                       pull the project id to be used by XXBI_XLA_TRANSACTIONS_V
-- 1.1      11/02/20202  Ofer S.       CHG0047310
-- 1.2      30-JUN-2020  Diptasurjya   INC0197108 - Sub Query returns more than one row - Bug fix
----------------------------------------------------------------------------------------------------
 gl.name,
 gl.ledger_id,
 xsed.creation_date,
 xsed.source_type,
 xsed.trx_type,
 xsed.balance_type_code balance_type,
 xxxla_detail_disco.get_account_parent(gl.chart_of_accounts_id || '.' ||
                                       gcc.segment3) parent_account,
 xxxla_detail_disco.get_account_parent_desc(gl.chart_of_accounts_id || '.' ||
                                            gcc.segment3) parent_account_desc,
 gcc.segment3 account,
 xxgl_utils_pkg.get_dff_value_description(1013887, gcc.segment3) account_desc,
 xxxla_detail_disco.get_dept_parent(gl.chart_of_accounts_id || '.' ||
                                    gcc.segment2) parent_department,
 xxxla_detail_disco.get_dept_parent_desc(gl.chart_of_accounts_id || '.' ||
                                         gcc.segment2) parent_department_desc,
 gcc.segment2 department,
 xxgl_utils_pkg.get_dff_value_description(1013889, gcc.segment2) department_desc,
 gcc.segment1 || '.' || gcc.segment2 Function,
 'Q' || gps.quarter_num || '-' || gps.period_year Quarter,
 xsed.period_name,
 xsed.currency Entered_Currency,
 xsed.sum_entered entered_amount,
 xsed.sum_accounted accounted_Amount,
 gl.currency_code ledger_currency,
 xsed.gl_date,
 xsed.trx_date,
 ai.invoice_num,
 -- strat  INC0149102
 (case
   when xsed.source_type = 'GL- Encumbrance' and
        instr(xsed.description, 'JE cahge gl date of PO') != 0 then
    replace(REPLACE(SUBSTR(xsed.description,
                           INSTR(xsed.description, 'PO'),
                           (INSTR(xsed.description, 'Line') - 1) -
                           (INSTR(xsed.description, 'PO'))),
                    'PO'),
            '-')
   when xsed.source_type = 'GL- Encumbrance' and
        instr(xsed.description, 'Encumbrance Period Correction') != 0 then
    (select h.reference_3
       from gl_je_lines h
      where h.je_header_id = xsed.other_trx_id1
        and h.je_line_num = xsed.other_trx_id2)
   when xsed.application_id=101 then-- CHG0047310   trx_type = 'Accrual'
    (select h.attribute2
       from gl_je_lines h
      where h.je_header_id = xsed.other_trx_id1
        and h.je_line_num = xsed.other_trx_id2)
   else
    case
      when ph.segment1 is not null then
       ph.segment1
      else
       (select ph.segment1
          from po_distributions_all pda, po_headers_all ph
         where pda.req_distribution_id = prd.distribution_id
           and ph.po_header_id = pda.po_header_id
           and rownum = 1  -- INC0197108 add
           )
    end
 end) po_number, -- end INC0149102
 prh.segment1 req_number,
 coalesce(pap_po_requester.full_name, pap_req_requester.full_name) po_req_requester,
 coalesce(pap_po_buyer.full_name, pap_req_buyer.full_name) po_req_buyer,
 asup.segment1 sup_num,
 -- start INC0149102
 (case
   when xsed.source_type = 'GL- Encumbrance' and
        instr(xsed.description, 'JE cahge gl date of PO') != 0 then
    (select pv.VENDOR_NAME
       from po_headers_all ph, po_vendors pv
      where ph.type_lookup_code = 'STANDARD'
        and org_id <> 89
        and pv.VENDOR_ID = ph.vendor_id
        and ph.segment1 =
            trim(replace(REPLACE(SUBSTR(xsed.description,
                                        INSTR(xsed.description, 'PO'),
                                        (INSTR(xsed.description, 'Line') - 1) -
                                        (INSTR(xsed.description, 'PO'))),
                                 'PO'),
                         '-')))
   when xsed.source_type = 'GL- Encumbrance' and
        instr(xsed.description, 'Encumbrance Period Correction') != 0 then
    (select pv.VENDOR_NAME
       from po_headers_all ph, gl_je_lines h, po_vendors pv
      where h.je_header_id = xsed.other_trx_id1
        and h.je_line_num = xsed.other_trx_id2
        and to_char(h.reference_3) = ph.segment1
        and ph.type_lookup_code = 'STANDARD'
        and pv.VENDOR_ID = ph.vendor_id
        and org_id <> 89)
   else
    case
      when xsed.application_id=101 then-- CHG0047310 trx_type = 'Accrual' then
       (select pv.VENDOR_NAME
          from gl_je_lines h, po_vendors pv
         where h.je_header_id = xsed.other_trx_id1
           and h.je_line_num = to_char(xsed.other_trx_id2)
           and pv.VENDOR_ID = to_char(h.attribute1)
           )
      else
       case
         when asup.vendor_name is not null then
          asup.vendor_name
         else
          (select pv.VENDOR_NAME
             from po_distributions_all pda, po_headers_all ph, po_vendors pv
            where pda.req_distribution_id = prd.distribution_id
              and ph.po_header_id = pda.po_header_id
              and pv.VENDOR_ID = ph.vendor_id
              and rownum = 1  -- INC0197108 add
              )
       end
    end
 end) sup_name, -- end INC0149102
 gcc.segment8 project,
 xxgl_utils_pkg.get_dff_value_description(1013890, gcc.segment8) project_desc,
 xsed.description Line_Description,
 get.encumbrance_type,
 gbv.budget_name,
 gbv.status budget_status,
 gcc.concatenated_segments Account_Combination,
 gcc_sum.concatenated_segments Summary_Combination,
 gcc_sum.segment2 summary_department,
 gst.template_name summary_account_name,
 gst.concatenated_description summary_account_definition,
 xxgl_utils_pkg.get_dff_value_description(1013889, gcc.segment2) ||
 xxxla_detail_disco.get_account_parent_desc(gl.chart_of_accounts_id || '.' ||
                                            gcc.segment3) AO,
 gcc.segment6 location,
 xxgl_utils_pkg.get_dff_value_description(1013892, gcc.segment6) location_desc,
 (SELECT --h.order_number  -- INC0197108 comment
         mso.segment1  -- INC0197108 add
    FROM mtl_material_transactions mmt,
         mtl_sales_orders mso             -- INC0197108 add
         --oe_order_lines_all        ol,  -- INC0197108 comment
         --oe_order_headers_all      h    -- INC0197108 comment
   where mmt.transaction_id = xsed.other_trx_id1
     and mmt.transaction_source_type_id = 8 -- Internal order  -- INC0197108 add
     and mmt.transaction_source_id = mso.sales_order_id   -- INC0197108 add
     --and ol.line_id = mmt.source_line_id  -- INC0197108 comment
     --and h.header_id = ol.header_id       -- INC0197108 comment
     and xsed.trx_type in ('Internal order', 'Internal requisition')) Internal_Order,
 (select (ffv.FLEX_VALUE) parent_value
    from fnd_flex_value_children_v ffvc,
         fnd_flex_values_vl        ffv,
         fnd_flex_hierarchies      ffh
   where ffvc.flex_value_set_id = 1013890
     and ffvc.flex_value_set_id = ffh.FLEX_VALUE_SET_ID
     and ffh.flex_value_set_id = ffv.flex_value_set_id
     and ffh.hierarchy_id = ffv.STRUCTURED_HIERARCHY_LEVEL
     and ffvc.parent_flex_value = ffv.FLEX_VALUE
     and ffh.hierarchy_code like 'Budget%'
     and ffvc.flex_value = gcc.segment8) Parent_Project,
 (SELECT (h.orig_sys_document_ref /*|| '#' ||
                                         TO_CHAR(prh.CREATION_DATE, 'DD-MON-YYYY')*/
         ) REQ
    FROM mtl_material_transactions  mmt,
         oe_order_lines_all         ol,
         oe_order_headers_all       h,
         po_requisition_headers_all prh
   where mmt.transaction_id = xsed.other_trx_id1
     and ol.line_id = mmt.source_line_id
     and mmt.transaction_source_type_id = 8 -- Internal Order         -- INC0197108 add
     and h.header_id = ol.header_id
     and prh.segment1 = h.orig_sys_document_ref
     and xsed.trx_type in ('Internal order', 'Internal requisition')
     and rownum = 1                                                   -- INC0197108 add
  union all
  SELECT (prh.segment1 /*|| '#' ||
                                         TO_CHAR(prh.CREATION_DATE, 'DD-MON-YYYY')*/
         ) REQ
    FROM --rcv_transactions           rt,                             -- INC0197108 comment
         --po_requisition_lines_all   prl,                            -- INC0197108 comment
         po_requisition_headers_all prh,
         mtl_material_transactions  mmt
   where --rt.transaction_id = mmt.source_line_id                     -- INC0197108 comment
     --and prl.requisition_line_id = rt.requisition_line_id           -- INC0197108 comment
     --and prh.requisition_header_id = prl.requisition_header_id      -- INC0197108 comment
     mmt.transaction_id = xsed.other_trx_id1
     --and mmt.source_code = 'RCV'                                    -- INC0197108 comment
     and mmt.transaction_source_type_id = 7  -- Internal Requisition  -- INC0197108 add
     and mmt.transaction_source_id = prh.requisition_header_id        -- INC0197108 add
     and xsed.trx_type in ('Internal order', 'Internal requisition')) Internal_Requistion,
 case
   when xsed.trx_type in ('Internal order', 'Internal requisition') then

    (SELECT prh.CREATION_DATE REQ_date
       FROM mtl_material_transactions  mmt,
            oe_order_lines_all         ol,
            oe_order_headers_all       h,
            po_requisition_headers_all prh
      where mmt.transaction_id = xsed.other_trx_id1
        and ol.line_id = mmt.source_line_id
        and mmt.transaction_source_type_id = 8 -- Internal Order      -- INC0197108 add
        and h.header_id = ol.header_id
        and prh.segment1 = h.orig_sys_document_ref
        and xsed.trx_type in ('Internal order', 'Internal requisition')
        and rownum = 1                                                -- INC0197108 add
     union all
     SELECT prh.CREATION_DATE REQ_date
       FROM --rcv_transactions           rt,                          -- INC0197108 comment
            --po_requisition_lines_all   prl,                         -- INC0197108 comment
            po_requisition_headers_all prh,
            mtl_material_transactions  mmt
      where --rt.transaction_id = mmt.source_line_id                  -- INC0197108 comment
        --and prl.requisition_line_id = rt.requisition_line_id        -- INC0197108 comment
        --and prh.requisition_header_id = prl.requisition_header_id   -- INC0197108 comment
        mmt.transaction_id = xsed.other_trx_id1
        --and mmt.source_code = 'RCV'                                 -- INC0197108 comment
        and mmt.transaction_source_type_id = 7 -- Internal Requisition  -- INC0197108 add
        and mmt.transaction_source_id = prh.requisition_header_id     -- INC0197108 add
        and xsed.trx_type in ('Internal order', 'Internal requisition'))
   else
    prd.gl_encumbered_date
 end Requisition_Date,
 ai.doc_sequence_value Voucher_Number, -- Ofer Suad 13-Aug-2018 CHG0043744
 ppa.segment1 Project_Number, ---CHG0043555
 ppa.name Project_Name, ---CHG0043555
 ppa.Description Project_Description ---CHG0043555
  FROM XXXLA_SLA_EXPENSE_DETAILS  xsed,
       gl_code_combinations_kfv   gcc,
       gl_ledgers                 gl,
       gl_period_statuses         gps,
       ap_invoices_all            ai,
       po_requisition_headers_all prh,
       po_headers_all             ph,
       per_all_people_f           pap_req_buyer,
       per_all_people_f           pap_req_requester,
       per_all_people_f           pap_po_buyer,
       per_all_people_f           pap_po_requester,
       po_distributions_all       pd,
       po_req_distributions_all   prd,
       po_requisition_lines_all   prl,
       ap_suppliers               asup,
       gl_encumbrance_types       get,
       gl_budget_versions         gbv,
       gl_account_hierarchies     gah,
       gl_summary_templates       gst,
       gl_code_combinations_kfv   gcc_sum,
       pa_projects_all            ppa --CHG0043555

 where gl.ledger_id = xsed.ledger_id
   and xsed.ledger_id = gps.ledger_id
   and xsed.period_name = gps.period_name
      -- rem CHG0044007 and  ppa.project_id (+) = pd.project_id
   and ppa.project_id(+) =
       xxxla_detail_disco.get_project_id(pd.project_id,
                                         xsed.application_id,
                                         xsed.trx_type,
                                         xsed.other_trx_id1) -- CHG0044007 - Add function to get project Id

   and gps.application_id = 101
   and xsed.inv_id = ai.invoice_id(+)
   and xsed.po_id = ph.po_header_id(+)
   and xsed.req_id = prh.requisition_header_id(+)
   and prl.suggested_buyer_id = pap_req_buyer.person_id(+)
   and trunc(prl.creation_date) between
       pap_req_buyer.effective_start_date(+) and
       pap_req_buyer.effective_end_date(+)
   and trunc(prl.creation_date) between
       pap_req_requester.effective_start_date(+) and
       pap_req_requester.effective_end_date(+)

   and ph.agent_id = pap_po_buyer.person_id(+)
   and trunc(ph.creation_date) between pap_po_buyer.effective_start_date(+) and
       pap_po_buyer.effective_end_date(+)
   and pd.deliver_to_person_id = pap_po_requester.person_id(+)
   and trunc(pd.creation_date) between
       pap_po_requester.effective_start_date(+) and
       pap_po_requester.effective_end_date(+)
   and xsed.po_dist_id = pd.po_distribution_id(+)
   and xsed.req_dist_id = prd.distribution_id(+)
   and prd.requisition_line_id = prl.requisition_line_id(+)
   and xsed.vendor_id = asup.vendor_id(+)
   and xsed.encumbrance_type_id = get.encumbrance_type_id(+)
   and xsed.budget_version_id = gbv.budget_version_id(+)
   and xsed.code_combination_id = gah.detail_code_combination_id(+)
   and xsed.code_combination_id = gcc.code_combination_id
   and xsed.ledger_id = gah.ledger_id(+)
   and gah.template_id = gst.template_id(+)
   and gah.summary_code_combination_id = gcc_sum.code_combination_id(+)
   and gst.template_name(+) like 'Budget%'

   and (gcc.segment2 = '000' or
       xxxla_detail_disco.get_dept_parent(gl.chart_of_accounts_id || '.' ||
                                           gcc.segment2) =
       decode(gcc_sum.segment2,
               'T',
               xxxla_detail_disco.get_dept_parent(gl.chart_of_accounts_id || '.' ||
                                                  gcc.segment2),
               nvl(gcc_sum.segment2,
                   xxxla_detail_disco.get_dept_parent(gl.chart_of_accounts_id || '.' ||
                                                      gcc.segment2))))
   and nvl(gst.segment3_type, 'Budget') != 'Budget Report Only'
   and prl.to_person_id = pap_req_requester.person_id(+)
   and xxxla_detail_disco.set_account_parent = 1
   and xxxla_detail_disco.set_dept_parent = 1
  union all
  --  CHG0047310  add defrred balances
  select gll.name,
       gll.ledger_id,
       l.creation_date,
       xdl.source_distribution_type SOURCE_TYPE,
       h.accounting_entry_type_code TRX_TYPE,
       h.balance_type_code,
       xxxla_detail_disco.get_account_parent(gll.chart_of_accounts_id || '.' ||
                                             gcc.segment3) parent_account,
       xxxla_detail_disco.get_account_parent_desc(gll.chart_of_accounts_id || '.' ||
                                                  gcc.segment3) PARENT_ACCOUNT_DESC,
       gcc.segment3 ACCOUNT,
       xxgl_utils_pkg.get_dff_value_description(1013887, gcc.segment3) account_desc,
       xxxla_detail_disco.get_dept_parent(gll.chart_of_accounts_id || '.' ||
                                          gcc.segment2) parent_department,
       xxxla_detail_disco.get_dept_parent_desc(gll.chart_of_accounts_id || '.' ||
                                               gcc.segment2) parent_department_desc,
       gcc.segment2 department,
       xxgl_utils_pkg.get_dff_value_description(1013889, gcc.segment2) department_desc,
       gcc.segment1 || '.' || gcc.segment2 "FUNCTION",
       'Q' || gp.quarter_num || '-' || gp.period_year QUARTER,
       gp.period_name,
       l.currency_code,
       nvl(l.entered_dr, 0) - nvl(l.entered_cr, 0) ENTERED_AMOUNT,
       nvl(l.accounted_dr, 0) - nvl(l.accounted_cr, 0) ACCOUNTED_AMOUNT,
       gll.currency_code LEDGER_CURRENCY,
       l.accounting_date,
       aia.invoice_date,
       aia.invoice_num,
       ph.segment1,
       prh.segment1 REQ_NUMBER,
       coalesce(pap_po_requester.full_name, pap_req_requester.full_name) po_req_requester,
       coalesce(pap_po_buyer.full_name, pap_req_buyer.full_name) po_req_buyer,
       pv.SEGMENT1 SUP_NUM,
       pv.VENDOR_NAME SUP_NAME,
       gcc.segment8 project,
       xxgl_utils_pkg.get_dff_value_description(1013890, gcc.segment8) project_desc,
       aid.description,
       null ENCUMBRANCE_TYPE,
       null BUDGET_NAME,
       null BUDGET_STATUS,
       gcc.concatenated_segments ACCOUNT_COMBINATION,
       sum_account.concatenated_segments SUMMARY_COMBINATION,

       sum_account.segment2 SUMMARY_DEPARTMENT,
       sum_account.template_name SUMMARY_ACCOUNT_NAME,
       sum_account.concatenated_description SUMMARY_ACCOUNT_DEFINITION,
       xxxla_detail_disco.get_account_parent_desc(gll.chart_of_accounts_id || '.' ||
                                                  gcc.segment3) AO,
       gcc.segment6 "LOCATION",
       xxgl_utils_pkg.get_dff_value_description(1013892, gcc.segment6) location_desc,
       null INTERNAL_ORDER,
       (select (ffv.FLEX_VALUE) parent_value
          from fnd_flex_value_children_v ffvc,
               fnd_flex_values_vl        ffv,
               fnd_flex_hierarchies      ffh
         where ffvc.flex_value_set_id = 1013890
           and ffvc.flex_value_set_id = ffh.FLEX_VALUE_SET_ID
           and ffh.flex_value_set_id = ffv.flex_value_set_id
           and ffh.hierarchy_id = ffv.STRUCTURED_HIERARCHY_LEVEL
           and ffvc.parent_flex_value = ffv.FLEX_VALUE
           and ffh.hierarchy_code like 'Budget%'
           and ffvc.flex_value = gcc.segment8) Parent_Project,
       null INTERNAL_REQUISTION,
       null REQUISITION_DATE,
       aia.doc_sequence_value,
       ppa.segment1    Project_Number,
       ppa.name        Project_Name,
       ppa.Description Project_Description
  from xla_ae_lines l,
       xla_ae_headers h,
       gl_code_combinations_kfv gcc,
       gl_ledgers gll,
       gl_periods gp,
       xla_distribution_links xdl,
       ap_invoice_distributions_all aid,
       ap_invoices_all aia,
       po_distributions_all pda,
       po_headers_all ph,
       po_req_distributions_all prd,
       po_requisition_lines_all prl,
       po_requisition_headers_all prh,
       per_all_people_f pap_req_buyer,
       per_all_people_f pap_req_requester,
       per_all_people_f pap_po_buyer,
       per_all_people_f pap_po_requester,
       po_vendors pv,
       (select gg.concatenated_segments,
                g.detail_code_combination_id,
                gst.ledger_id,
                gg.segment2,
                gg.segment3,
                gst.template_name,
                gst.concatenated_description
           from gl_account_hierarchies   g,
                gl_code_combinations_kfv gg,
                gl_summary_templates     gst
          where /*g.detail_code_combination_id = gcc.code_combination_id
                                                                                                                                                            and*/
          gg.code_combination_id = g.summary_code_combination_id
       and gst.template_id = g.template_id
       and gst.template_name != 'Budget Report Only'
       and gst.template_name(+) like 'Budget%'
         /*and gst.ledger_id=gl.ledger_id*/
         ) sum_account,
       pa_projects_all ppa
 where l.accounting_date > sysdate
   and h.gl_transfer_status_code = 'N'
   and h.ae_header_id = l.ae_header_id
   and h.balance_type_code = 'A'
   and h.application_id = 200
   and gcc.code_combination_id = l.code_combination_id
   and gll.ledger_id = l.ledger_id
    and gp.adjustment_period_flag = 'N'
   and gp.period_type = '21'
   and gp.period_set_name = 'OBJET_CALENDAR'
   and l.accounting_date between gp.start_date and gp.end_date
   and xxxla_detail_disco.set_account_parent = 1
   and xxxla_detail_disco.set_dept_parent = 1
   and xdl.ae_header_id = l.ae_header_id
   and xdl.ae_line_num = l.ae_line_num
   and xdl.application_id = 200
   and aid.invoice_distribution_id = xdl.source_distribution_id_num_1
   and aid.invoice_id = aia.invoice_id
   and pda.po_distribution_id(+) = aid.po_distribution_id
   and ph.po_header_id(+) = pda.po_header_id
   and prd.distribution_id(+) = pda.req_distribution_id
   and prl.requisition_line_id(+) = prd.requisition_line_id
   and prh.requisition_header_id(+) = prl.requisition_header_id
   and pv.VENDOR_ID = aia.vendor_id
   and prl.to_person_id = pap_req_requester.person_id(+)
   and trunc(prl.creation_date) between
       pap_req_requester.effective_start_date(+) and
       pap_req_requester.effective_end_date(+)
   and prl.suggested_buyer_id = pap_req_buyer.person_id(+)
   and trunc(prl.creation_date) between
       pap_req_buyer.effective_start_date(+) and
       pap_req_buyer.effective_end_date(+)
   and ph.agent_id = pap_po_buyer.person_id(+)
   and trunc(ph.creation_date) between pap_po_buyer.effective_start_date(+) and
       pap_po_buyer.effective_end_date(+)
   and pda.deliver_to_person_id = pap_po_requester.person_id(+)
   and trunc(pda.creation_date) between
       pap_po_requester.effective_start_date(+) and
       pap_po_requester.effective_end_date(+)
   and gcc.code_combination_id = sum_account.detail_code_combination_id(+)
   and gll.ledger_id = sum_account.ledger_id(+)
   and ppa.project_id(+) = pda.project_id

union all -- CHG0047310
select gl.name,
       gl.ledger_id,
       to_date(xaw.inv_period, 'MON-YY') creation_date,
       'GL- Encumbrance' SOURCE_TYPE,
       'STANDARD' TRX_TYPE,
       'E' BALANCE_TYPE,
       xaw.parent_account,
       xxgl_utils_pkg.get_dff_value_description(1013887, xaw.parent_account) PARENT_ACCOUNT_DESC,
       gcc.segment3 ACCOUNT,
       xxgl_utils_pkg.get_dff_value_description(1013887, gcc.segment3) account_desc,

       xxxla_detail_disco.get_dept_parent(gl.chart_of_accounts_id || '.' ||
                                          gcc.segment2) parent_department,
       xxxla_detail_disco.get_dept_parent_desc(gl.chart_of_accounts_id || '.' ||
                                               gcc.segment2) parent_department_desc,
       gcc.segment2 department,
       xxgl_utils_pkg.get_dff_value_description(1013889, gcc.segment2) department_desc,
       gcc.segment1 || '.' || gcc.segment2 "FUNCTION",
       'Q' || gp.quarter_num || '-' || gp.period_year QUARTER,
       gp.period_name,
       xaw.currency_code,
       xaw.entered_dr - xaw.entered_cr ENTERED_AMOUNT,
       xaw.accounted_dr - xaw.accounted_cr ACCOUNTED_AMOUNT,
       gl.currency_code LEDGER_CURRENCY,
       gp.start_date GL_Date,
       gp.start_date TRX_DATE,
       xaw.invoice_num,
       xaw.po_number,
       prh.segment1 REQ_NUMBER,
       coalesce(pap_po_requester.full_name, pap_req_requester.full_name) po_req_requester,
       coalesce(pap_po_buyer.full_name, pap_req_buyer.full_name) po_req_buyer,
       pv.SEGMENT1 SUP_NUM,
       pv.VENDOR_NAME SUP_NAME,
       gcc.segment8 project,
       xxgl_utils_pkg.get_dff_value_description(1013890, gcc.segment8) project_desc,
       xaw.description,
       'Obligation' ENCUMBRANCE_TYPE,
       null BUDGET_NAME,
       null BUDGET_STATUS,
       xaw.concatenated_segments ACCOUNT_COMBINATION,

       sum_account.concatenated_segments SUMMARY_COMBINATION,

       sum_account.segment2 SUMMARY_DEPARTMENT,
       sum_account.template_name SUMMARY_ACCOUNT_NAME,
       sum_account.concatenated_description SUMMARY_ACCOUNT_DEFINITION,
       xxxla_detail_disco.get_account_parent_desc(gl.chart_of_accounts_id || '.' ||
                                                  gcc.segment3) AO,
       gcc.segment6 "LOCATION",
       xxgl_utils_pkg.get_dff_value_description(1013892, gcc.segment6) location_desc,
       null INTERNAL_ORDER,
       (select (ffv.FLEX_VALUE) parent_value
          from fnd_flex_value_children_v ffvc,
               fnd_flex_values_vl        ffv,
               fnd_flex_hierarchies      ffh
         where ffvc.flex_value_set_id = 1013890
           and ffvc.flex_value_set_id = ffh.FLEX_VALUE_SET_ID
           and ffh.flex_value_set_id = ffv.flex_value_set_id
           and ffh.hierarchy_id = ffv.STRUCTURED_HIERARCHY_LEVEL
           and ffvc.parent_flex_value = ffv.FLEX_VALUE
           and ffh.hierarchy_code like 'Budget%'
           and ffvc.flex_value = gcc.segment8) Parent_Project,
       null INTERNAL_REQUISTION,
       null REQUISITION_DATE,
       (select aia.doc_sequence_value
          from ap_invoice_distributions_all aid, ap_invoices_all aia
         where aid.invoice_distribution_id = xaw.invoice_distribution_id
           and aia.invoice_id = aid.invoice_id) VOUCHER_NUMBER,
       ppa.segment1 Project_Number,
       ppa.name Project_Name,
       ppa.Description Project_Description

  from XXAP_WRONG_PO_ENC_REVRESAL xaw,
       gl_ledgers gl,
       gl_code_combinations_kfv gcc,
       gl_periods gp,
       ap_invoice_distributions_all aid,
       po_distributions_all pda,
       po_headers_all ph,
       po_req_distributions_all prd,
       po_requisition_lines_all prl,
       po_requisition_headers_all prh,
       per_all_people_f pap_req_buyer,
       per_all_people_f pap_req_requester,
       per_all_people_f pap_po_buyer,
       per_all_people_f pap_po_requester,
       po_vendors pv,
       (select gg.concatenated_segments,
                g.detail_code_combination_id,
                gst.ledger_id,
                gg.segment2,
                gg.segment3,
                gst.template_name,
                gst.concatenated_description
           from gl_account_hierarchies   g,
                gl_code_combinations_kfv gg,
                gl_summary_templates     gst
          where
          gg.code_combination_id = g.summary_code_combination_id
       and gst.template_id = g.template_id
       and gst.template_name != 'Budget Report Only'
       and gst.template_name(+) like 'Budget%'

         ) sum_account,
       pa_projects_all ppa
 where xaw.deferred_acctg_flag = 'P'
   and gl.name = xaw.name
   and gcc.concatenated_segments = xaw.concatenated_segments
   and xxxla_detail_disco.set_account_parent = 1
   and xxxla_detail_disco.set_dept_parent = 1
   and gp.period_name = xaw.po_period
   and gp.adjustment_period_flag = 'N'
   and gp.period_type = '21'
   and gp.period_set_name = 'OBJET_CALENDAR'
   and aid.invoice_distribution_id = xaw.invoice_distribution_id
   and pda.po_distribution_id = aid.po_distribution_id
   and ph.po_header_id = pda.po_header_id
   and ph.vendor_id = pv.VENDOR_ID
   and prd.distribution_id(+) = pda.req_distribution_id
   and prl.requisition_line_id(+) = prd.requisition_line_id
   and prh.requisition_header_id(+) = prl.requisition_header_id
   and prl.to_person_id = pap_req_requester.person_id(+)
   and trunc(prl.creation_date) between
       pap_req_requester.effective_start_date(+) and
       pap_req_requester.effective_end_date(+)
   and prl.suggested_buyer_id = pap_req_buyer.person_id(+)
   and trunc(prl.creation_date) between
       pap_req_buyer.effective_start_date(+) and
       pap_req_buyer.effective_end_date(+)
   and ph.agent_id = pap_po_buyer.person_id(+)
   and trunc(ph.creation_date) between pap_po_buyer.effective_start_date(+) and
       pap_po_buyer.effective_end_date(+)
   and pda.deliver_to_person_id = pap_po_requester.person_id(+)
   and trunc(pda.creation_date) between
       pap_po_requester.effective_start_date(+) and
       pap_po_requester.effective_end_date(+)
   and gcc.code_combination_id = sum_account.detail_code_combination_id(+)
   and gl.ledger_id = sum_account.ledger_id(+)
   and ppa.project_id(+) = pda.project_id
;
/
