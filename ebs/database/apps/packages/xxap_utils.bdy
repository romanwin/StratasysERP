CREATE OR REPLACE PACKAGE BODY xxap_utils IS
  --------------------------------------------------------------------
  --  name:              XXAP_UTILS
  --  create by:         Ofer Suad
  --  Revision:          1.0
  --  creation date:     13/11/2011
  --------------------------------------------------------------------
  --  purpose :      Utils for Paybles
  --------------------------------------------------------------------
  --  ver  date          name              desc
  --  1.0  13/11/2011    Ofer Suad         initial build
  --  1.1  11-MAY-2015 Gubendran K       CHG0034754 – Automate Journal Entry to Correct Encumbrance Period,
  --                                     also disable existing mailing notification and enable Journal Import Process
  --  1.2  29/01/2018  Ofer Suad         CHG0041827 bug fix changes
  --  1.3  07/04/2019 Ofer Suad          CHG0045333  remove restriction of Prepaid expense
  --  1.4  23/04/2019 Ofer Suad          CHG0045608-None USD deferred Encumbrance Journal fix created with entered amount instead of accounted amount 
  --  1.5  10/02/2020 Ofer Suad          CHG0047436 -encumbrace reversal fix does not taking the invoice discard
  --------------------------------------------------------------------

  --------------------------------------------------------------------
  --  name:            Update_IC_Interafce_GLDate
  --  create by:       Ofer Suad
  --  Revision:        1.0
  --  creation date:   24/07/2014
  --------------------------------------------------------------------
  --  purpose :        Create Wrper to oracle undo accounting
  --------------------------------------------------------------------
  --  ver  date        name              desc
  -- 1.0  24/07/2014  ofer suad         initial build
  --------------------------------------------------------------------

  PROCEDURE update_ic_interafce_gldate(errbuf        OUT NOCOPY VARCHAR2,
                                       retcode       OUT NOCOPY NUMBER,
                                       p_new_gl_date VARCHAR2) IS

  BEGIN

    retcode := 0;
    UPDATE ap_invoices_interface aii
       SET aii.gl_date = fnd_date.canonical_to_date(p_new_gl_date)
     WHERE aii.org_id = fnd_global.org_id
       AND aii.source = 'Intercompany'
       AND aii.status = 'REJECTED'
       AND EXISTS
     (SELECT 1
              FROM ap_interface_rejections    aij,
                   ap_invoice_lines_interface ail
             WHERE aij.reject_lookup_code = 'ACCT DATE NOT IN OPEN PD'
               AND ail.invoice_line_id = aij.parent_id
               AND ail.invoice_id = aii.invoice_id);
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      retcode := 1;
      errbuf  := SQLERRM;
  END;
  -------------------------------------
  --------------------------------------------------------------------
  --  name:            Get Defred Flag
  --  create by:       Ofer Suad
  --  Revision:        1.0
  --  creation date:   31/03/2019  CHG0045333
  --------------------------------------------------------------------
  function get_deferred_flag(p_inv_dist_id number) return varchar is
    l_ret varchar2(1) := 'N';
  begin

    select 'P'
      into l_ret
      from ap_invoice_distributions_all aid
     where aid.invoice_distribution_id = p_inv_dist_id
       and exists (select 1
              from ap_invoice_distributions_all aidd
             where aid.invoice_id = aidd.invoice_id
               and aidd.amount < 0
               and aidd.po_distribution_id is null
               and aidd.dist_code_combination_id =
                   aid.dist_code_combination_id)
       and exists (select 1
              from ap_invoice_distributions_all aide,
                   ap_invoice_lines_all         ail
             where aid.invoice_id = aide.invoice_id
               and aide.amount > 0
               and aide.po_distribution_id is null
               and aide.dist_code_combination_id =
                   aid.dist_code_combination_id
               and ail.invoice_id = aide.invoice_id
               and ail.line_number = aide.invoice_line_number
               and ail.deferred_acctg_flag = 'Y');
    return l_ret;
  exception
    when no_data_found then
      return 'N';
  end;

  --------------------------------------------------------------------
  --  name:            wrong_po_encum_reversal_lines
  --  create by:       Ofer Suad
  --  Revision:        1.0
  --  creation date:   13/11/2011  10:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Procedure to send mail in cases of Invoice Gl Date is prior
  --                   to PO Gl Date . In these cases the Encumrance is wrog and
  --                   users will have to Crate Manual Encumbarcne JE in order to
  --                   fix the wrong Encumbarcne.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  13/11/2011  Ofer Suad         Initial Build
  --  1.1  04/12/2011  Ofer Suad         change min mail amount to 500 USD (profile
  --                                     XXAP_MIN_DIST_MAIL_AMOUNT)
  --       25/03/2012  Ofer Suad         Add parent accoun and PO number to mail ssent
  --  1.2  24/07/2014  ofer suad         CHG0032811 - add Update_IC_Interafce_GLDate
  --  1.2  11-MAY-2015 Gubendran K       CHG0034754 – Automate Journal Entry to Correct Encumbrance Period,
  --                                     also disable existing mailing notification and enable Journal Import Process
  --  1.3  29/01/2018  Ofer Suad         CHG0041827 bug fix changes
  --------------------------------------------------------------------

  PROCEDURE wrong_po_encum_reversal_lines(errbuf  OUT NOCOPY VARCHAR2,
                                          retcode OUT NOCOPY NUMBER,
                                          p_date  VARCHAR2) IS
    l_from_date   DATE;
    l_to_date     DATE;
    l_send_mail   NUMBER := 0;
    l_period_year NUMBER;
    l_period_num  NUMBER;
    l_ledger_name VARCHAR2(30);
    --CHG0034754
    l_group_id         NUMBER;
    l_ledger_id        NUMBER;
    l_interface_run_id NUMBER;
    l_conc_id          NUMBER;
    l_bool             BOOLEAN;
    l_phase            VARCHAR2(100);
    l_status           VARCHAR2(100);
    l_dev_phase        VARCHAR2(100);
    l_dev_status       VARCHAR2(100);
    l_message          VARCHAR2(100);
    l_rev_account_id   NUMBER;
    l_gl_exists        NUMBER;
    --CHG0034754
    l_err_code NUMBER;
    l_err_msg  VARCHAR2(200);
    g_request_id CONSTANT NUMBER := fnd_global.conc_request_id;
    l_return_status        VARCHAR2(2000);
    l_error_message        VARCHAR2(2000);
    l_transfer_status_code VARCHAR2(1);

    CURSOR c_enc_lines IS
      SELECT gl.name,
             aid.invoice_distribution_id,
             aid.invoice_line_number,
             aia.invoice_num,
             gp_inv.period_name inv_period,
             gp_po.period_name po_period,
             gcc.concatenated_segments,
             SUM(nvl(l.entered_dr, 0)) entered_dr,
             SUM(nvl(l.entered_cr, 0)) entered_cr,
             SUM(nvl(l.accounted_dr, 0)) accounted_dr,
             SUM(nvl(l.accounted_cr, 0)) accounted_cr,
             substr(l.description, 0, 200) description,
             gl.currency_code,
             nvl(l.currency_conversion_rate, 1) rate,
             'NEW' mail_status,
             ph.segment1 po_number,
             parent_accounts.parent_value,
             gcc.chart_of_accounts_id,
             gcc.segment1,
             gcc.segment2,
             gcc.segment3,
             gcc.segment4,
             gcc.segment5,
             gcc.segment6,
             gcc.segment7,
             gcc.segment8,
             gcc.segment9,
             gcc.segment10,
             gl.ledger_id,
             aid.accounting_date,
             gp_inv.end_date inv_period_last_day,
             gp_po.end_date po_period_last_day,
             case
               when ail.deferred_acctg_flag = 'Y' then
                'P' --ail.deferred_acctg_flag
               else
                xxap_utils.get_deferred_flag(aid.invoice_distribution_id)
             end deferred_acctg_flag

        FROM ap_invoice_distributions aid,
             ap_invoices_all aia,
             po_distributions pda,
             ap_invoice_lines ail,
             gl_periods gp_inv,
             gl_periods gp_po,
             xla_transaction_entities_upg g,
             xla_ae_headers h,
             xla_distribution_links d,
             gl_code_combinations_kfv gcc,
             xla_ae_lines l,
             gl_ledgers gl,
             po_headers_all ph,
             (SELECT ffvc.flex_value child_value,
                     MIN(ffv.flex_value) parent_value
                FROM fnd_flex_value_children_v ffvc,
                     fnd_flex_values_vl        ffv,
                     fnd_flex_hierarchies      ffh
               WHERE ffvc.flex_value_set_id IN (1013887)
                 AND ffvc.flex_value_set_id = ffh.flex_value_set_id
                 AND ffh.flex_value_set_id = ffv.flex_value_set_id
                 AND ffh.hierarchy_id = ffv.structured_hierarchy_level
                 AND ffvc.parent_flex_value = ffv.flex_value
                 AND ffh.hierarchy_code LIKE 'Budget%'
               GROUP BY ffvc.flex_value) parent_accounts
       WHERE aid.accounting_date BETWEEN l_from_date AND l_to_date
         AND aid.line_type_lookup_code = 'ITEM'
         AND pda.po_distribution_id = aid.po_distribution_id
         AND aid.accounting_date BETWEEN gp_inv.start_date AND
             gp_inv.end_date
         AND pda.gl_encumbered_date BETWEEN gp_po.start_date AND
             gp_po.end_date
            --AND gp_inv.period_year <= gp_po.period_year  CHG0041827 bug fix changes
         AND gp_inv.period_set_name = 'OBJET_CALENDAR'
         AND gp_po.period_set_name = 'OBJET_CALENDAR'
         AND gp_po.adjustment_period_flag = 'N'
         AND gp_inv.adjustment_period_flag = 'N'
            --CHG0041827 bug fix changes
         and ((gp_inv.period_year < gp_po.period_year) or
             (gp_inv.period_year = gp_po.period_year AND
             gp_inv.quarter_num < gp_po.quarter_num))
            -- end CHG0041827 bug fix changes
         AND nvl(aid.posted_flag, 'N') = 'Y'
         AND aia.invoice_id = aid.invoice_id
         AND g.application_id = 200
         AND g.transaction_number = aia.invoice_num
         AND h.application_id = 200
         AND h.entity_id = g.entity_id
         AND d.ae_header_id = h.ae_header_id
         AND d.source_distribution_id_num_1 =
             to_char(aid.invoice_distribution_id)
         AND gcc.code_combination_id = pda.code_combination_id
         AND d.accounting_line_code in ( 'AP_INV_PO_ENC','AP_INV_PO_ENC_REV')--CHG0047436 -encumbrace reversal fix does not taking the invoice discard
         AND d.source_distribution_type = 'AP_INV_DIST'
         AND l.ae_header_id = d.ae_header_id
         AND l.ae_line_num = d.ae_line_num
         AND l.accounting_class_code = 'PURCHASE_ORDER'
         AND l.ledger_id = gl.ledger_id
         AND gl.ledger_category_code = 'PRIMARY'
         AND ph.po_header_id = pda.po_header_id
         AND parent_accounts.child_value = gcc.segment3
         AND NOT EXISTS (SELECT 1
                FROM xxap_wrong_po_enc_revresal xxl
               WHERE xxl.invoice_distribution_id =
                     aid.invoice_distribution_id)
            --CHG0034754
            -- CHG0045333 remocve deferrwed restriction
            /*AND NOT EXISTS (SELECT 1
             FROM ap_invoice_lines ail
            WHERE ail.invoice_id=aia.invoice_id
              AND ail.deferred_acctg_flag='Y')*/
            --CHG0034754 Po carry fwd for remaining qty after invoice was created
         and not exists
       (select 1
                from apps.xx_change_gl_po_lines xcg
               where xcg.po_num = ph.segment1)

         and ail.invoice_id = aid.invoice_id
         and ail.line_number = aid.invoice_line_number
      --CHG0034754
       GROUP BY aia.invoice_num,
                aid.invoice_line_number,
                aid.invoice_distribution_id,
                gl.name,
                gp_inv.period_name,
                gp_po.period_name,
                gcc.concatenated_segments,
                l.description,
                gl.currency_code,
                nvl(l.currency_conversion_rate, 1),
                ph.segment1,
                parent_accounts.parent_value,
                gcc.chart_of_accounts_id,
                gcc.segment1,
                gcc.segment2,
                gcc.segment3,
                gcc.segment4,
                gcc.segment5,
                gcc.segment6,
                gcc.segment7,
                gcc.segment8,
                gcc.segment9,
                gcc.segment10,
                gl.ledger_id,
                aid.accounting_date,
                gp_inv.end_date,
                gp_po.end_date,
                ail.deferred_acctg_flag
      HAVING abs(SUM(nvl(l.entered_dr, 0)) - SUM(nvl(l.entered_cr, 0))) >
      --  ofer suad 04/12/2011  change min amount to 500 USD -- profile XXAP_MIN_DIST_MAIL_AMOUNT
      fnd_profile.value('XXAP_MIN_DIST_MAIL_AMOUNT') * gl_currency_api.get_closest_rate('USD', gl.currency_code, SYSDATE, 'Corporate', 10);

    cursor c_defrred_lines is

      select xaw.entered_dr,
             xaw.entered_cr,
             gll.ledger_id,
             xaw.po_period,
             gp.end_date po_period_last_day,
             xaw.currency_code,
             xaw.invoice_num,
             xaw.invoice_line_number,
             xaw.accounted_cr,
             xaw.accounted_dr,
             gcc.segment1,
             gcc.segment2,
             gcc.segment3,
             gcc.segment4,
             gcc.segment5,
             gcc.segment6,
             gcc.segment7,
             gcc.segment8,
             gcc.segment9,
             gcc.segment10,
             gcc.chart_of_accounts_id,
             xaw.po_number,
             xaw.invoice_distribution_id,
             gcc.code_combination_id,
             xaw.rowid
        from XXAP_WRONG_PO_ENC_REVRESAL xaw,
             gl_code_combinations_kfv   gcc,
             gl_ledgers                 gll,
             gl_periods                 gp

       where xaw.deferred_acctg_flag = 'P'
         and ltrim(gcc.concatenated_segments) = xaw.concatenated_segments
         and gll.name = xaw.name
         and gp.period_name = xaw.po_period
         AND gp.period_set_name = 'OBJET_CALENDAR'
         AND gp.adjustment_period_flag = 'N'
         and trunc(sysdate) between gp.start_date and gp.end_date;

    /*   select  xl.entered_dr,xl.entered_cr,xl.ae_header_id,xl.ae_line_num,
       gll.ledger_id,
          xaw.po_period,
          gp.end_date po_period_last_day,
          xaw.currency_code,
          xaw.invoice_num,
          xaw.invoice_line_number,
          xaw.accounted_cr,
          xaw.accounted_dr,
          gcc.segment1,
          gcc.segment2,
          gcc.segment3,
          gcc.segment4,
          gcc.segment5,
          gcc.segment6,
          gcc.segment7,
          gcc.segment8,
          gcc.segment9,
          gcc.segment10,
          gcc.chart_of_accounts_id,
          xaw.po_number,
          xaw.invoice_distribution_id,
          gcc.code_combination_id,
          xaw.rowid
         from XXAP_WRONG_PO_ENC_REVRESAL xaw,
          gl_code_combinations_kfv   gcc,
          gl_ledgers                 gll,
          gl_periods                 gp,
          xla_distribution_links xdl,
            xla_ae_lines           xl,
            xla_ae_headers         xh
    where xaw.deferred_acctg_flag = 'Y'
       and ltrim(gcc.concatenated_segments) = xaw.concatenated_segments
      and gll.name = xaw.name
      and gp.period_name = xaw.po_period
      AND gp.period_set_name = 'OBJET_CALENDAR'
      AND gp.adjustment_period_flag = 'N'
     and  xdl.application_id = 200
        and xdl.source_distribution_id_num_1 = xaw.invoice_distribution_id
        and xdl.source_distribution_type = 'AP_INV_DIST'
        and xl.ae_header_id = xdl.ae_header_id
        and xl.ae_line_num = xdl.ae_line_num
        and xl.ae_header_id = xh.ae_header_id
        and xh.application_id = 200
        and xh.balance_type_code = 'A'
        and xl.code_combination_id = gcc.code_combination_id
        and xl.ledger_id = 2021
        and xh.gl_transfer_status_code='Y'
        and xl.attribute1 is null
        and p_date between gp.start_date and gp.end_date
        and 1=2;*/

  BEGIN
    SELECT l.name
      INTO l_ledger_name
      FROM hr_operating_units h, gl_ledgers l
     WHERE h.set_of_books_id = l.ledger_id
       AND h.organization_id = fnd_global.org_id;

    UPDATE xxap_wrong_po_enc_revresal xxl
       SET xxl.mail_status = 'SENT'
     WHERE xxl.mail_status = 'NEW'
       AND xxl.name = l_ledger_name;
    COMMIT;

    SELECT gp.end_date, gp.period_year, gp.period_num
      INTO l_to_date, l_period_year, l_period_num
      FROM gl_periods gp
     WHERE fnd_date.canonical_to_date(p_date) BETWEEN gp.start_date AND
           gp.end_date
       AND gp.period_set_name = 'OBJET_CALENDAR'
       AND gp.adjustment_period_flag = 'N';

    IF l_period_num = 1 THEN
      l_period_num  := 12;
      l_period_year := l_period_year - 1;
    ELSE
      l_period_num := l_period_num - 1;
    END IF;

    SELECT gp.start_date
      INTO l_from_date
      FROM gl_periods gp
     WHERE gp.period_year = l_period_year
       AND gp.period_set_name = 'OBJET_CALENDAR'
       AND gp.adjustment_period_flag = 'N'
       AND gp.period_num = l_period_num;

    --CHG0034754
    SELECT gl_interface_control_s.NEXTVAL, gl_journal_import_s.NEXTVAL
      INTO l_group_id, l_interface_run_id
      FROM dual;
    --CHG0034754
    l_gl_exists := 0;
    FOR i IN c_enc_lines LOOP
      INSERT INTO xxap_wrong_po_enc_revresal
        (NAME,
         invoice_num,
         invoice_line_number,
         invoice_distribution_id,
         inv_period,
         po_period,
         concatenated_segments,
         entered_dr,
         entered_cr,
         accounted_dr,
         accounted_cr,
         description,
         currency_code,
         rate,
         mail_status,
         --   25/03/2012  Ofer Suad         Add parent accoun and PO number to mail ssent
         po_number,
         parent_account,
         deferred_acctg_flag --CHG0045333 remocve deferrwed restriction
         )
      VALUES
        (i.name,
         i.invoice_num,
         i.invoice_line_number,
         i.invoice_distribution_id,
         i.inv_period,
         i.po_period,
         i.concatenated_segments,
         i.entered_dr,
         i.entered_cr,
         i.accounted_dr,
         i.accounted_cr,
         i.description,
         i.currency_code,
         i.rate,
         i.mail_status,
         --   25/03/2012  Ofer Suad         Add parent accoun and PO number to mail ssent
         i.po_number,
         i.parent_value,
         i.deferred_acctg_flag --CHG0045333 remocve deferrwed restriction
         );
      l_send_mail   := 1;
      l_ledger_name := i.name;
      COMMIT;
      --CHG0034754
      /*  IF l_send_mail != 0 THEN
        xxobjt_wf_mail.send_mail_body_proc(p_to_role     => fnd_profile.value('XXAP_PO_WRONG_ENC_MAIL_GENERAL_REEC'), -- i v
                                           p_cc_mail     => fnd_profile.value('XXAP_PO_WRONG_ENC_MAIL_REGION_REEC'), -- i v
                                           p_bcc_mail    => NULL, -- i v
                                           p_subject     => 'Invoices matched to PO with future GL Date', -- i v
                                           p_body_proc   => 'XXAP_UTILS.prepare_wrong_po_ecnu_body/' ||
                                                            l_ledger_name, -- i v
                                           p_att1_proc   => NULL, -- i v
                                           p_att2_proc   => NULL, -- i v
                                           p_att3_proc   => NULL, -- i v
                                           p_err_code    => retcode, -- o n
                                           p_err_message => errbuf); -- o v

        COMMIT;

      END IF; */
      --CHG0034754

      --CHG0034754
      IF l_rev_account_id IS NULL THEN
        SELECT l.res_encumb_code_combination_id
          INTO l_rev_account_id
          FROM gl_ledgers l
         WHERE l.ledger_id = i.ledger_id;
      END IF;
      ------------------------------------------------------------------------------
      --‘Move From’ Journal Entry
      ------------------------------------------------------------------------------
      if nvl(i.deferred_acctg_flag, 'N') <> 'P' then
        -- CHG0045333 remocve deferrwed restriction
        INSERT INTO gl_interface
          (status,
           actual_flag,
           encumbrance_type_id,
           date_created,
           created_by,
           set_of_books_id,
           ledger_id,
           period_name,
           accounting_date,
           currency_code,
           user_je_source_name,
           user_je_category_name,
           je_line_num,
           reference10,
           entered_dr,
           entered_cr,
           segment1,
           segment2,
           segment3,
           segment4,
           segment5,
           segment6,
           segment7,
           segment8,
           segment9,
           segment10,
           reference21,
           reference22,
           reference23,
           reference24,
           reference4,
           group_id)
        VALUES
          ('NEW',
           'E',
           1001,
           SYSDATE,
           -1,
           i.ledger_id,
           i.ledger_id,
           i.po_period,
           i.po_period_last_day,
           i.currency_code,
           'Encumbrance',
           'Other',
           1,
           i.invoice_num || ' Line ' || i.invoice_line_number ||
           ' Encumbrance Period Correction',
           i.accounted_cr,
           i.accounted_dr,
           i.segment1,
           '000',
           '999999',
           DECODE(i.chart_of_accounts_id, 50308, '0000000', NULL),
           '000',
           '000',
           '00',
           DECODE(i.chart_of_accounts_id, 50308, '0000', NULL),
           DECODE(i.chart_of_accounts_id, 50308, '000000', '0000'),
           DECODE(i.chart_of_accounts_id, 50308, NULL, '000'),
           i.invoice_num,
           i.invoice_line_number,
           i.po_number,
           i.invoice_distribution_id,
           'Move Encumbrance Period',
           l_group_id);
        -------------------------------------------------------------------------------
        ----‘Move From’ Journal Entry Reverse
        -------------------------------------------------------------------------------
        INSERT INTO gl_interface
          (status,
           actual_flag,
           encumbrance_type_id,
           date_created,
           created_by,
           set_of_books_id,
           ledger_id,
           period_name,
           accounting_date,
           currency_code,
           user_je_source_name,
           user_je_category_name,
           je_line_num,
           reference10,
           entered_dr,
           entered_cr,
           segment1,
           segment2,
           segment3,
           segment4,
           segment5,
           segment6,
           segment7,
           segment8,
           segment9,
           segment10,
           reference21,
           reference22,
           reference23,
           reference24,
           reference4,
           group_id)
        VALUES
          ('NEW',
           'E',
           1001,
           SYSDATE,
           -1,
           i.ledger_id,
           i.ledger_id,
           i.po_period,
           i.po_period_last_day,
           i.currency_code,
           'Encumbrance',
           'Other',
           2,
           i.invoice_num || ' Line ' || i.invoice_line_number ||
           ' Encumbrance Period Correction',
           i.accounted_dr,
           i.accounted_cr,
           i.segment1,
           i.segment2,
           i.segment3,
           i.segment4,
           i.segment5,
           i.segment6,
           i.segment7,
           i.segment8,
           i.segment9,
           i.segment10,
           i.invoice_num,
           i.invoice_line_number,
           i.po_number,
           i.invoice_distribution_id,
           'Move Encumbrance Period',
           l_group_id);
      else
        ---
        null;
      end if; -- CHG0045333 remocve deferrwed restriction
      -------------------------------------------------------------------------------
      --‘Move To’ Journal Entry
      -------------------------------------------------------------------------------
      INSERT INTO gl_interface
        (status,
         actual_flag,
         encumbrance_type_id,
         date_created,
         created_by,
         set_of_books_id,
         ledger_id,
         period_name,
         accounting_date,
         currency_code,
         user_je_source_name,
         user_je_category_name,
         je_line_num,
         reference10,
         entered_dr,
         entered_cr,
         segment1,
         segment2,
         segment3,
         segment4,
         segment5,
         segment6,
         segment7,
         segment8,
         segment9,
         segment10,
         reference21,
         reference22,
         reference23,
         reference24,
         reference4,
         group_id)
      VALUES
        ('NEW',
         'E',
         1001,
         SYSDATE,
         -1,
         i.ledger_id,
         i.ledger_id,
         i.inv_period,
         i.inv_period_last_day,
         i.currency_code,
         'Encumbrance',
         'Other',
         1,
         i.invoice_num || ' Line ' || i.invoice_line_number ||
         ' Encumbrance Period Correction',
         i.accounted_cr,
         i.accounted_dr,
         i.segment1,
         i.segment2,
         i.segment3,
         i.segment4,
         i.segment5,
         i.segment6,
         i.segment7,
         i.segment8,
         i.segment9,
         i.segment10,
         i.invoice_num,
         i.invoice_line_number,
         i.po_number,
         i.invoice_distribution_id,
         'Move Encumbrance Period',
         l_group_id);
      -------------------------------------------------------------------------------
      --‘Move To’ Journal Entry reverse
      -------------------------------------------------------------------------------
      INSERT INTO gl_interface
        (status,
         actual_flag,
         encumbrance_type_id,
         date_created,
         created_by,
         set_of_books_id,
         ledger_id,
         period_name,
         accounting_date,
         currency_code,
         user_je_source_name,
         user_je_category_name,
         je_line_num,
         reference10,
         entered_dr,
         entered_cr,
         segment1,
         segment2,
         segment3,
         segment4,
         segment5,
         segment6,
         segment7,
         segment8,
         segment9,
         segment10,
         reference21,
         reference22,
         reference23,
         reference24,
         reference4,
         group_id)
      VALUES
        ('NEW',
         'E',
         1001,
         SYSDATE,
         -1,
         i.ledger_id,
         i.ledger_id,
         i.inv_period,
         i.inv_period_last_day,
         i.currency_code,
         'Encumbrance',
         'Other',
         2,
         i.invoice_num || ' Line ' || i.invoice_line_number ||
         ' Encumbrance Period Correction',
         i.accounted_dr,
         i.accounted_cr,
         i.segment1,
         '000',
         '999999',
         DECODE(i.chart_of_accounts_id, 50308, '0000000', NULL),
         '000',
         '000',
         '00',
         DECODE(i.chart_of_accounts_id, 50308, '0000', NULL),
         DECODE(i.chart_of_accounts_id, 50308, '000000', '0000'),
         DECODE(i.chart_of_accounts_id, 50308, NULL, '000'),
         i.invoice_num,
         i.invoice_line_number,
         i.po_number,
         i.invoice_distribution_id,
         'Move Encumbrance Period',
         l_group_id);
      l_ledger_id := i.ledger_id;
      l_gl_exists := 1;
    END LOOP;
    COMMIT;

    IF l_gl_exists = 1 THEN
      INSERT INTO gl_interface_control
        (status,
         je_source_name,
         group_id,
         set_of_books_id,
         interface_run_id)
      VALUES
        ('S', 'Encumbrance', l_group_id, l_ledger_id, l_interface_run_id);
      l_conc_id := fnd_request.submit_request(application => 'SQLGL',
                                              program     => 'GLLEZL',
                                              description => NULL,
                                              start_time  => SYSDATE,
                                              sub_request => FALSE,
                                              argument1   => l_interface_run_id,
                                              argument2   => l_ledger_id,
                                              argument3   => 'N',
                                              argument4   => NULL,
                                              argument5   => NULL,
                                              argument6   => 'N',
                                              argument7   => 'W');
      COMMIT;

      l_bool := fnd_concurrent.wait_for_request(l_conc_id,
                                                5,
                                                1000,
                                                l_phase,
                                                l_status,
                                                l_dev_phase,
                                                l_dev_status,
                                                l_message);
      COMMIT;
    ELSE
      l_error_message := 'No Data Found for Journal Import Process';
      fnd_file.put_line(fnd_file.log, l_error_message);
    END IF;
    -- CHG0045333 remocve deferrwed restriction
    SELECT gl_interface_control_s.NEXTVAL, gl_journal_import_s.NEXTVAL
      INTO l_group_id, l_interface_run_id
      FROM dual;

    l_gl_exists := 0;
    for j in c_defrred_lines loop
      /*l_transfer_status_code := 'N';
      begin
        select xh.gl_transfer_status_code
          into l_transfer_status_code
          from xla_distribution_links xdl,
               xla_ae_lines           xl,
               xla_ae_headers         xh
         where xdl.application_id = 200
           and xdl.source_distribution_id_num_1 = j.invoice_distribution_id
           and xdl.source_distribution_type = 'AP_INV_DIST'
           and xl.ae_header_id = xdl.ae_header_id
           and xl.ae_line_num = xdl.ae_line_num
           and xl.ae_header_id = xh.ae_header_id
           and xh.application_id = 200
           and xh.balance_type_code = 'A'
           and xl.code_combination_id = j.code_combination_id
           and xl.ledger_id = j.ledger_id
           and rownum = 1;
      exception
        when others then
          l_transfer_status_code := 'N';
      end;*/
      --  if l_transfer_status_code = 'Y' then
      l_gl_exists := 1;
      INSERT INTO gl_interface
        (status,
         actual_flag,
         encumbrance_type_id,
         date_created,
         created_by,
         set_of_books_id,
         ledger_id,
         period_name,
         accounting_date,
         currency_code,
         user_je_source_name,
         user_je_category_name,
         je_line_num,
         reference10,
         entered_dr,
         entered_cr,
         segment1,
         segment2,
         segment3,
         segment4,
         segment5,
         segment6,
         segment7,
         segment8,
         segment9,
         segment10,
         reference21,
         reference22,
         reference23,
         reference24,
         reference4,
         group_id)
      VALUES
        ('NEW',
         'E',
         1001,
         SYSDATE,
         -1,
         j.ledger_id,
         j.ledger_id,
         j.po_period,
         j.po_period_last_day,
         j.currency_code,
         'Encumbrance',
         'Other',
         1,
         j.invoice_num || ' Line ' || j.invoice_line_number ||
         ' Encumbrance Period Correction',
         j.accounted_cr,--CHG0045608
         j.accounted_dr,--CHG0045608
         j.segment1,
         '000',
         '999999',
         DECODE(j.chart_of_accounts_id, 50308, '0000000', NULL),
         '000',
         '000',
         '00',
         DECODE(j.chart_of_accounts_id, 50308, '0000', NULL),
         DECODE(j.chart_of_accounts_id, 50308, '000000', '0000'),
         DECODE(j.chart_of_accounts_id, 50308, NULL, '000'),
         j.invoice_num,
         j.invoice_line_number,
         j.po_number,
         j.invoice_distribution_id,
         'Move Encumbrance Period',
         l_group_id);
      -------------------------------------------------------------------------------
      ----‘Move From’ Journal Entry Reverse
      -------------------------------------------------------------------------------
      INSERT INTO gl_interface
        (status,
         actual_flag,
         encumbrance_type_id,
         date_created,
         created_by,
         set_of_books_id,
         ledger_id,
         period_name,
         accounting_date,
         currency_code,
         user_je_source_name,
         user_je_category_name,
         je_line_num,
         reference10,
         entered_dr,
         entered_cr,
         segment1,
         segment2,
         segment3,
         segment4,
         segment5,
         segment6,
         segment7,
         segment8,
         segment9,
         segment10,
         reference21,
         reference22,
         reference23,
         reference24,
         reference4,
         group_id)
      VALUES
        ('NEW',
         'E',
         1001,
         SYSDATE,
         -1,
         j.ledger_id,
         j.ledger_id,
         j.po_period,
         j.po_period_last_day,
         j.currency_code,
         'Encumbrance',
         'Other',
         2,
         j.invoice_num || ' Line ' || j.invoice_line_number ||
         ' Encumbrance Period Correction',
          j.accounted_dr,--CHG0045608
         j.accounted_cr,--CHG0045608
         j.segment1,
         j.segment2,
         j.segment3,
         j.segment4,
         j.segment5,
         j.segment6,
         j.segment7,
         j.segment8,
         j.segment9,
         j.segment10,
         j.invoice_num,
         j.invoice_line_number,
         j.po_number,
         j.invoice_distribution_id,
         'Move Encumbrance Period',
         l_group_id);

      update XXAP_WRONG_PO_ENC_REVRESAL xwp
         set xwp.deferred_acctg_flag = 'Y'
       where xwp.rowid = j.rowid;
      l_ledger_id := j.ledger_id;

    -- end if;
    end loop;

    COMMIT;

    IF l_gl_exists = 1 THEN
      INSERT INTO gl_interface_control
        (status,
         je_source_name,
         group_id,
         set_of_books_id,
         interface_run_id)
      VALUES
        ('S', 'Encumbrance', l_group_id, l_ledger_id, l_interface_run_id);
      l_conc_id := fnd_request.submit_request(application => 'SQLGL',
                                              program     => 'GLLEZL',
                                              description => NULL,
                                              start_time  => SYSDATE,
                                              sub_request => FALSE,
                                              argument1   => l_interface_run_id,
                                              argument2   => l_ledger_id,
                                              argument3   => 'N',
                                              argument4   => NULL,
                                              argument5   => NULL,
                                              argument6   => 'N',
                                              argument7   => 'W');
      COMMIT;

      l_bool := fnd_concurrent.wait_for_request(l_conc_id,
                                                5,
                                                1000,
                                                l_phase,
                                                l_status,
                                                l_dev_phase,
                                                l_dev_status,
                                                l_message);
      COMMIT;
    end if;
  EXCEPTION
    WHEN OTHERS THEN
      l_error_message := substr('Unexpected Error in gl_interface insert or journal import: ' ||
                                SQLERRM,
                                1,
                                200);
      fnd_file.put_line(fnd_file.log, l_error_message);
      errbuf  := l_error_message;
      retcode := '2';
      --CHG0034754
  END wrong_po_encum_reversal_lines;

  --------------------------------------------------------------------
  --  name:            prepare_wrong_po_ecnu_body
  --  create by:       Ofer Suad
  --  Revision:        1.0
  --  creation date:   13/11/2011  10:30:11 PM
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  13/11/2011  Ofer Suad         initial build
  --------------------------------------------------------------------
  PROCEDURE prepare_wrong_po_ecnu_body(p_document_id   IN VARCHAR2,
                                       p_display_type  IN VARCHAR2,
                                       p_document      IN OUT CLOB,
                                       p_document_type IN OUT VARCHAR2) IS

    CURSOR c_mail_lines IS
      SELECT xxl.name,
             xxl.invoice_num,
             xxl.invoice_line_number,
             xxl.inv_period,
             xxl.po_period,
             xxl.concatenated_segments,
             xxl.description,
             xxl.entered_dr,
             xxl.entered_cr,
             xxl.accounted_dr,
             xxl.accounted_cr,
             xxl.currency_code,
             xxl.po_number,
             xxl.parent_account
        FROM xxap_wrong_po_enc_revresal xxl
       WHERE xxl.mail_status = 'NEW'
         AND xxl.name = p_document_id;
  BEGIN

    dbms_lob.append(p_document,
                    xxobjt_wf_mail.get_header_html ||
                    '<p style="color:darkblue">Hello,</p><p style="color:darkblue">The following Invoices were matched to PO with future GL Date </p>');

    dbms_lob.append(p_document,
                    '<table border="1" cellpadding="2" cellspacing="2" width="100%" style="color:darkblue">');
    dbms_lob.append(p_document,
                    '<tr><th>Ledger</th><th>Invoice Number</th><th>Line Number</th><th>Description</th><th>Invoice Period</th><th>PO Period</th>');
    dbms_lob.append(p_document,
                    '<th>Account</th><th>Entered DR</th><th>Entered CR</th><th>Accounted DR</th><th>Accounted CR</th><th>Currency</th>
                    <th>PO Number</th><th>Parent Account</th></tr>');

    FOR j IN c_mail_lines LOOP

      dbms_lob.append(p_document, '<tr><td>' || j.name || '</td>');
      dbms_lob.append(p_document, '<td>' || j.invoice_num || '</td>');
      dbms_lob.append(p_document,
                      '<td>' || j.invoice_line_number || '</td>');
      dbms_lob.append(p_document, '<td>' || j.description || '</td>');
      dbms_lob.append(p_document, '<td>' || j.inv_period || '</td>');
      dbms_lob.append(p_document, '<td>' || j.po_period || '</td>');
      dbms_lob.append(p_document,
                      '<td>' || j.concatenated_segments || '</td>');
      dbms_lob.append(p_document, '<td>' || j.entered_dr || '</td>');
      dbms_lob.append(p_document, '<td>' || j.entered_cr || '</td>');
      dbms_lob.append(p_document, '<td>' || j.accounted_dr || '</td>');
      dbms_lob.append(p_document, '<td>' || j.accounted_cr || '</td>');
      dbms_lob.append(p_document, '<td>' || j.currency_code || '</td>');
      --   25/03/2012  Ofer Suad         Add parent accoun and PO number to mail ssent
      dbms_lob.append(p_document, '<td>' || j.po_number || '</td>');
      dbms_lob.append(p_document,
                      '<td>' || j.parent_account || '</td></tr>');

    END LOOP;
    dbms_lob.append(p_document,
                    '</tr></table>' || xxobjt_wf_mail.get_footer_html);
    p_document_type := 'TEXT/HTML' || ';name=' || 'INVPOENC.HTML';

  EXCEPTION
    WHEN OTHERS THEN
      wf_core.context('XXAP_UTILS',
                      'XXAP_UTILS.prepare_wrong_po_ecnu_body',
                      p_document_id,
                      p_display_type);
      RAISE;

  END;

  --------------------------------------------------------------------
  --  name:            undo_accounting
  --  create by:       Ofer Suad
  --  Revision:        1.0
  --  creation date:   13/11/2011  10:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Create Wrper to oracle undo accounting
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  13/11/2011  Ofer Suad         initial build
  --------------------------------------------------------------------
  PROCEDURE undo_accounting(errbuf         OUT NOCOPY VARCHAR2,
                            retcode        OUT NOCOPY NUMBER,
                            p_source_table VARCHAR2,
                            p_source_id    NUMBER,
                            p_gl_date      VARCHAR2) IS
    p_calling_sequence VARCHAR2(50) := 'ap_undo_acctg.sql';
    l_event_id         VARCHAR2(50);
    p_bug_id           NUMBER;
    l_gl_date          DATE := fnd_date.canonical_to_date(p_gl_date);
  BEGIN
    errbuf  := NULL;
    retcode := 0;
    fnd_file.put_line(fnd_file.log, 'Running script ap_undo_acctg');
    p_bug_id := 200;
    IF fnd_profile.value('XXAP_UNDO_ACCOUTING_PPREMITED') = 'Y' THEN

      BEGIN

        ap_acctg_data_fix_pkg.undo_accounting(p_source_table,
                                              p_source_id,
                                              l_event_id,
                                              p_calling_sequence,
                                              p_bug_id,
                                              l_gl_date);

        IF NOT
            (ap_acctg_data_fix_pkg.delete_cascade_adjustments(p_source_type => p_source_table,
                                                              p_source_id   => p_source_id)) THEN
          fnd_file.put_line(fnd_file.log,
                            'Problem in delete_cascade_adjustments');
        END IF;
        COMMIT;
      EXCEPTION
        WHEN OTHERS THEN
          errbuf  := 'XXAP_UTILS.undo_accounting ERROR';
          retcode := 1;
          fnd_file.put_line(fnd_file.log,
                            'Error: p_source_id: ' || p_source_id);
          ROLLBACK;
      END;

      fnd_file.put_line(fnd_file.log,
                        'Back from AP_ACCTG_DATA_FIX_PKG.Undo_Accounting');

    END IF;
  END;
END xxap_utils;
/
