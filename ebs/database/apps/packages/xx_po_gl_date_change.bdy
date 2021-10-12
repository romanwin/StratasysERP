create or replace package body xx_po_gl_date_change IS

  --------------------------------------------------------------------
  --  name:            xx_po_gl_date_change
  --  create by:       OFER.SUAD
  --  Revision:        1.11
  --  creation date:   15/08/2011
  --------------------------------------------------------------------
  --  purpose :        PP's GL date carry forward
  --------------------------------------------------------------------
  --  ver  date        name           desc
  --  1.0    15/08/2011  Ofer Suad      initial build
  --  1.1    15/01/2017  Ofer Suad   CHG0041827 bug fix changes
  --  1.2    11/06/2019  Bellona.B   CHG0046530 create new procedure to 
  --                                 process all the PO’s that were received but not invoiced     
  --------------------------------------------------------------------

  /*************************************************************************
  this is the main procedure called from concurent to call all sub
  procdure that do the unresreve /changing gl date ,reresreve and reapprove
  **************************************************************************/
  ---------------------------------------------------------------------
  -- 18-dec-2011 Ofer Suad  p_use_gl_date      => PO_DOCUMENT_FUNDS_PVT.g_parameter_YES
  -- in do the unreseve
  --  ver     date        name           desc
  -- 1.1    15/01/2017    Ofer Suad      CHG0041827 bug fix changes
  ---------------------------------------------------------------------
  PROCEDURE main(errbuf OUT VARCHAR2, retcode OUT NUMBER) IS
    p_doc_level_id_tbl po_tbl_number := po_tbl_number(1);
    p_detailed_results po_fcout_type;
    p_status           VARCHAR2(20);
    p_error_msg        VARCHAR2(200); --v1.1 CHG0041827 - Length Changed from 40 to 200
    p_bool             BOOLEAN;

    l_err_exists       Number := 0; --v1.1 CHG0041827 Added
    l_valid_emp        number;      --v1.1 CHG0041827 Added
    l_full_name        per_all_people_f.full_name%TYPE; --v1.1 CHG0041827 Added
    l_person_id         number;                         --v1.1 CHG0041827 Added

    CURSOR c_po_to_modify IS
      SELECT DISTINCT xcg.po_num, xcg.po_line_num, xcg.new_gl_date
        FROM xx_change_gl_po_lines xcg
       WHERE xcg.org_id = fnd_global.org_id
         AND xcg.status IS NULL
         AND xcg.po_num IS NOT NULL;
    CURSOR c_dist(po_num VARCHAR2, po_line_num NUMBER, p_new_gl_date date) IS --v1.1 CHG0041827 - p_new_gl_date added
      SELECT pda.po_distribution_id,
             pda.gl_encumbered_date,
             pda.req_distribution_id,
             pda.encumbered_flag
        FROM po_headers_all ph, po_lines_all pl, po_distributions_all pda
       WHERE ph.segment1 = po_num
         AND pl.po_header_id = ph.po_header_id
         AND pl.line_num = po_line_num
         AND pda.po_line_id = pl.po_line_id
         and pda.gl_encumbered_date < p_new_gl_date -- CHG0041827 no update for future GL Date
         AND pda.quantity_ordered >
             pda.quantity_billed + pda.quantity_cancelled
         AND ph.org_id = fnd_global.org_id;
  BEGIN
    errbuf       := null;
    retcode      := 0;
    l_err_exists := 0;

    /* clean previous data */
    DELETE FROM xx_po_change_encumbrance
     WHERE org_id = fnd_global.org_id
       AND group_id IS NULL;

    COMMIT;
    -- CHG0041827 -error handling - create output header
     fnd_file.put_line(fnd_file.OUTPUT,xxobjt_wf_mail.get_header_html ||
	      '<p style="color:darkblue">Hello,</p><p style="color:darkblue">POs that failed validation </p>');
        fnd_file.put_line(fnd_file.OUTPUT,'<table border="1" cellpadding="2" cellspacing="2" width="100%" style="color:darkblue">');
    FOR i IN c_po_to_modify LOOP
      l_valid_emp := 0;
    -- CHG0041827 -check if buyer is active
    l_person_id:=-99;
    l_full_name :=null;
    begin
    select pf.full_name,pf.person_id
    into l_full_name,l_person_id
    from po_headers_all          ph,
             per_all_people_f        pf
    where ph.segment1 = i.po_num
         and ph.org_id = fnd_global.org_id
         and ph.agent_id = pf.person_id
         and sysdate between pf.effective_start_date and
             nvl(pf.effective_end_date, sysdate + 1) ;
     exception
     when others then
       null;
     end;

      select count(1)
        into l_valid_emp
        from PER_WORKFORCE_CURRENT_X pwc
       where pwc.person_id = l_person_id;

      if l_valid_emp = 0 then

        write_log_message(i.po_num, i.po_line_num, 'Buyer '||l_full_name||' is not valid');
        p_error_msg  := 'Buyer '||l_full_name||' is not valid';
        p_status     := 'FAILURE';
        l_err_exists := 1;
      else

        -- CHG0041827 - validate new GL Date is no more than 3 years ago
        if i.new_gl_date < add_months(sysdate, -36) then
          write_log_message(i.po_num,
                            i.po_line_num,
                            'New GL date ' || i.new_gl_date ||
                            ' is more than 3 yeares ago');
          p_error_msg  := 'New GL date ' || i.new_gl_date ||
                          ' is more than 3 yeares ago';
          p_status     := 'FAILURE';
          l_err_exists := 1;
        else
          FOR j IN c_dist(i.po_num, i.po_line_num, i.new_gl_date) LOOP
            -- CHG0041827 send new GL to cursor  to check future dates

            p_doc_level_id_tbl(1) := j.po_distribution_id;
            p_error_msg := NULL;
            -- 14-10-2012 add check if not encumbered only change gl date
            if nvl(j.encumbered_flag, 'N') = 'N' then
              chage_dist_gl_date(p_doc_level_id_tbl, i.new_gl_date);
              p_status := 'DONE';
            else

              do_unresrve(p_doc_level_id_tbl, p_status);
              IF p_status NOT IN ('SUCCESS', 'WARNING') THEN
                p_error_msg := 'Eror while do_unresrve';
                 write_log_message(i.po_num, i.po_line_num, 'Eror while do_unresrve');
               -- fnd_file.put_line(fnd_file.log,
               --                   'Eror while do_unresrve for PO ' ||
               --                   i.po_num || ' Line ' || i.po_line_num);
                l_err_exists := 1;

              ELSE
                chage_dist_gl_date(p_doc_level_id_tbl, i.new_gl_date);
                do_reserve(p_doc_level_id_tbl,
                           p_detailed_results,
                           p_status);
                IF p_status NOT IN ('SUCCESS', 'WARNING') THEN
                  p_error_msg := 'Eror while do_resrve';
                  write_log_message(i.po_num, i.po_line_num, 'Eror while do_resrve');

                ELSE
                  p_status := 'DONE';
                  IF j.req_distribution_id IS NOT NULL THEN
                    populate_encum_table(p_detailed_results.row_index(1),
                                         p_doc_level_id_tbl(1),
                                         i.po_num,
                                         i.po_line_num,
                                         j.gl_encumbered_date,
                                         j.req_distribution_id);
                  END IF;
                  fnd_file.put_line(fnd_file.log,
                                    'Changing ' || i.po_num || ' Line ' ||
                                    i.po_line_num || ' end successfully.');

                END IF;

              END IF;
            end if;

          END LOOP;
        end if;
      end if;
      UPDATE xx_change_gl_po_lines xg
         SET xg.status = p_status, xg.error_desc = p_error_msg
       WHERE xg.po_num = i.po_num
         AND xg.po_line_num = i.po_line_num
         AND xg.org_id = fnd_global.org_id
         AND xg.status IS NULL;

    END LOOP;
    -- CHG0041827 in case all dist are with future gl date
    delete from xx_change_gl_po_lines xg
    where  xg.org_id = fnd_global.org_id
         AND xg.status IS NULL;

    pupulate_gl_interface;
    approve_docs;
    fnd_file.put_line(fnd_file.OUTPUT,'</table></html>');
    -- CHG0041827 update concurrent status only when procees ends
    if l_err_exists = 1 then
      p_bool := fnd_concurrent.set_completion_status('WARNING',
                                                     'See error log for failing document list ');
    end if;
    COMMIT;
  END;

  /*************************************************************************
   do the unreseve before changing the gl date
   -- -- Ofer S. 18/12/2011 add parameter
   --  ver     date        name           desc
   -- 1.1    15/01/2017   Ofer Suad       CHG0041827 bug fix changes
  **************************************************************************/
  PROCEDURE do_unresrve(p_doc_level_id_tbl IN po_tbl_number,
                        p_status           OUT VARCHAR2) IS
    p_return_status    VARCHAR2(50);
    p_po_return_code   VARCHAR2(50);
    p_detailed_results po_fcout_type;
  BEGIN

    po_document_funds_grp.do_unreserve(p_api_version      => '1',
                                       p_commit           => 'T',
                                       p_init_msg_list    => 'T',
                                       p_validation_level => NULL,
                                       x_return_status    => p_return_status,
                                       p_doc_type         => 'PO',
                                       p_doc_subtype      => 'STANDARD',
                                       p_doc_level        => 'DISTRIBUTION',
                                       p_doc_level_id_tbl => p_doc_level_id_tbl,
                                       p_employee_id      => NULL,
                                       p_override_funds   => PO_DOCUMENT_FUNDS_GRP.g_parameter_YES, --v1.1 CHG0041827 Ofer S.
                                       p_use_gl_date      => PO_DOCUMENT_FUNDS_PVT.g_parameter_YES, -- Ofer S. 18/12/2011 add parameter
                                       p_override_date    => SYSDATE,
                                       p_report_successes => NULL,
                                       x_po_return_code   => p_po_return_code,
                                       x_detailed_results => p_detailed_results);
    p_status := p_po_return_code;
  END;
  /*************************************************************************
   do the reseve after changing the gl date
   --  ver     date        name           desc
   -- 1.1     15/01/2017  Ofer Suad       CHG0041827 bug fix changes
  **************************************************************************/
  PROCEDURE do_reserve(p_doc_level_id_tbl IN po_tbl_number,
                       p_detailed_results OUT po_fcout_type,
                       p_status           OUT VARCHAR2) IS
    p_return_status  VARCHAR2(50);
    p_po_return_code VARCHAR2(50);

  BEGIN
    po_document_funds_grp.do_reserve(p_api_version          => '1',
                                     p_commit               => 'T',
                                     p_init_msg_list        => 'T',
                                     p_validation_level     => NULL,
                                     x_return_status        => p_return_status,
                                     p_doc_type             => 'PO',
                                     p_doc_subtype          => 'STANDARD',
                                     p_doc_level            => 'DISTRIBUTION',
                                     p_doc_level_id_tbl     => p_doc_level_id_tbl,
                                     p_prevent_partial_flag => NULL,
                                     p_employee_id          => NULL,
                                     p_override_funds       => PO_DOCUMENT_FUNDS_GRP.g_parameter_YES, --v1.1 CHG0041827 Ofer S.
                                     p_report_successes     => NULL,
                                     x_po_return_code       => p_po_return_code,
                                     x_detailed_results     => p_detailed_results);
    p_status := p_po_return_code;
  END;
  /*************************************************************************
   change gl date of the po distibution
  **************************************************************************/
  PROCEDURE chage_dist_gl_date(p_doc_level_id_tbl IN po_tbl_number,
                               p_new_gl_date      IN DATE) IS
  BEGIN
    UPDATE po_distributions_all pda
       SET pda.gl_encumbered_date = p_new_gl_date
     WHERE pda.po_distribution_id = p_doc_level_id_tbl(1);
  END;

  /*************************************************************************
   populate the date that will be the base of Encumbrance JE
  **************************************************************************/
  PROCEDURE populate_encum_table(doc_seq_num    NUMBER,
                                 p_po_dist_id   NUMBER,
                                 p_po_num       VARCHAR2,
                                 p_po_line_num  NUMBER,
                                 p_orig_gl_date DATE,
                                 p_req_dist_id  NUMBER) IS
    p_currency_code            VARCHAR2(15);
    p_ledger_id                NUMBER;
    p_ccid                     VARCHAR2(15);
    p_accounting_date          DATE;
    p_cr_amt                   NUMBER;
    p_dr_amt                   NUMBER;
    p_acctd_cr_amt             NUMBER;
    p_acctd_dr_amt             NUMBER;
    p_currency_conversion_date DATE;
    p_currency_conversion_rate NUMBER;
    p_currency_conversion_type VARCHAR2(15);
  BEGIN

    SELECT prl.rate_date, prl.rate, prl.rate_type
      INTO p_currency_conversion_date,
           p_currency_conversion_rate,
           p_currency_conversion_type
      FROM po_requisition_lines_all prl, po_req_distributions_all prd
     WHERE prd.requisition_line_id = prl.requisition_line_id
       AND prd.distribution_id = p_req_dist_id;

    SELECT xl.ledger_id,
           xl.code_combination_id,
           xl.currency_code,
           -- xl.currency_conversion_date,
           -- xl.currency_conversion_rate,
           --   xl.currency_conversion_type,
           xl.entered_dr,
           xl.entered_cr,
           xl.accounted_dr,
           xl.accounted_cr,
           xl.accounting_date
      INTO p_ledger_id,
           p_ccid,
           p_currency_code,
           --  p_currency_conversion_date,
           --  p_currency_conversion_rate,
           --  p_currency_conversion_type,
           p_cr_amt, -- Shoud reverse the lines so dr in xla_lines is cr heare
           p_dr_amt, -- Shoud reverse the lines so cr in xla_lines is dr heare
           p_acctd_cr_amt,
           p_acctd_dr_amt,
           p_accounting_date
      FROM po_bc_distributions pbd, xla_ae_headers xh, xla_ae_lines xl
     WHERE pbd.distribution_id = p_req_dist_id
       AND pbd.origin_sequence_num = doc_seq_num
       AND pbd.ae_event_id = xh.event_id
       AND pbd.ledger_id = xh.ledger_id
       AND xl.ae_header_id = xh.ae_header_id
       AND xl.accounting_class_code = 'REQUISITION'
       AND pbd.event_type_code = 'PO_PA_RESERVED';

    INSERT INTO xx_po_change_encumbrance
      (ledger_id, --
       org_id,
       currency_code, --
       curr_coversion_type, --
       curr_coversion_date, --
       curr_coversion_rate, --
       accounting_date, --
       orig_accounting_date,
       code_combination_id, --
       debit_ent_amt, --
       credit_ent_amt, --
       debit_acctd_amt,
       credit_acctd_amt,
       line_desciption, --
       req_dist_id,
       po_dist_id,
       doc_seq_num,
       creation_date)
    VALUES
      (p_ledger_id,
       fnd_global.org_id,
       p_currency_code,
       p_currency_conversion_type,
       p_currency_conversion_date,
       p_currency_conversion_rate,
       p_accounting_date,
       p_orig_gl_date,
       p_ccid,
       p_dr_amt,
       p_cr_amt,
       p_acctd_dr_amt,
       p_acctd_cr_amt,
       'JE cahge gl date of PO ' || p_po_num || ' Line Number ' ||
       p_po_line_num,
       p_req_dist_id,
       p_po_dist_id,
       doc_seq_num,
       SYSDATE);
  exception
    when others then
      null;

  END;
  /*************************************************************************
   populate gl intraface with  Encumbrance JE lines
   actualy there will be 2 JE - one in the new period to reduce funds
   and one in the original date to add funds thate where taken from budget
   where po was approved

   Then run import program
  **************************************************************************/
  PROCEDURE pupulate_gl_interface IS
    CURSOR c_je_lines IS
      SELECT ledger_id,
             accounting_date,
             orig_accounting_date,
             currency_code,
             curr_coversion_date,
             curr_coversion_type,
             curr_coversion_rate,
             code_combination_id,
             line_desciption,
             SUM(debit_ent_amt) debit_ent_amt,
             SUM(credit_ent_amt) credit_ent_amt,
             SUM(debit_acctd_amt) debit_acctd_amt,
             SUM(credit_acctd_amt) credit_acctd_amt
        FROM xx_po_change_encumbrance t
       WHERE t.group_id IS NULL
       GROUP BY ledger_id,
                accounting_date,
                orig_accounting_date,
                currency_code,
                curr_coversion_date,
                curr_coversion_type,
                curr_coversion_rate,
                code_combination_id,
                line_desciption
      HAVING SUM(debit_ent_amt) != 0 OR SUM(credit_ent_amt) != 0;

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
  BEGIN
    SELECT gl_interface_control_s.NEXTVAL, gl_journal_import_s.NEXTVAL
      INTO l_group_id, l_interface_run_id
      FROM dual;

    l_gl_exists := 0;

    FOR i IN c_je_lines LOOP
      IF l_rev_account_id IS NULL THEN
        SELECT res_encumb_code_combination_id
          INTO l_rev_account_id
          FROM gl_ledgers l
         WHERE l.ledger_id = i.ledger_id;

      END IF;
      /* insert into interface */
      INSERT INTO gl_interface
        (status,
         ledger_id,
         accounting_date,
         currency_code,
         date_created,
         created_by,
         actual_flag,
         user_je_category_name,
         user_je_source_name,
         currency_conversion_date,
         encumbrance_type_id, --
         user_currency_conversion_type,
         currency_conversion_rate,
         entered_dr,
         entered_cr,
         accounted_dr,
         accounted_cr,
         code_combination_id,
         group_id,
         reference10)
      VALUES
        ('NEW',
         i.ledger_id,
         i.accounting_date,
         i.currency_code,
         SYSDATE,
         fnd_global.user_id,
         'E',
         'Other', --'Requisitions',
         'Encumbrance', --'Purchasing',
         i.curr_coversion_date,
         1000,
         i.curr_coversion_type,
         i.curr_coversion_rate,
         i.debit_ent_amt,
         i.credit_ent_amt,
         i.debit_acctd_amt,
         i.credit_acctd_amt,
         i.code_combination_id,
         l_group_id,
         i.line_desciption);
      -------------------------------------------------
      --reerve account
      -------------------------------------------------
      INSERT INTO gl_interface
        (status,
         ledger_id,
         accounting_date,
         currency_code,
         date_created,
         created_by,
         actual_flag,
         user_je_category_name,
         user_je_source_name,
         currency_conversion_date,
         encumbrance_type_id, --
         user_currency_conversion_type,
         currency_conversion_rate,
         entered_dr,
         entered_cr,
         accounted_dr,
         accounted_cr,
         code_combination_id,
         group_id,
         reference10)
      VALUES
        ('NEW',
         i.ledger_id,
         i.accounting_date,
         i.currency_code,
         SYSDATE,
         fnd_global.user_id,
         'E',
         'Other', --'Requisitions',
         'Encumbrance', --'Purchasing',
         i.curr_coversion_date,
         1000,
         i.curr_coversion_type,
         i.curr_coversion_rate,
         i.credit_ent_amt,
         i.debit_ent_amt,
         i.credit_acctd_amt,
         i.debit_acctd_amt,
         l_rev_account_id,
         l_group_id,
         i.line_desciption);
      --------------------------------------
      /* Original date of po*/
      --------------------------------------
      INSERT INTO gl_interface
        (status,
         ledger_id,
         accounting_date,
         currency_code,
         date_created,
         created_by,
         actual_flag,
         user_je_category_name,
         user_je_source_name,
         currency_conversion_date,
         encumbrance_type_id, --
         user_currency_conversion_type,
         currency_conversion_rate,
         entered_dr,
         entered_cr,
         accounted_dr,
         accounted_cr,
         code_combination_id,
         reference10,
         group_id)
      VALUES
        ('NEW',
         i.ledger_id,
         i.orig_accounting_date,
         i.currency_code,
         SYSDATE,
         fnd_global.user_id,
         'E',
         'Other', --'Requisitions',
         'Encumbrance', --'Purchasing',
         i.curr_coversion_date,
         1000,
         i.curr_coversion_type,
         i.curr_coversion_rate,
         i.credit_ent_amt,
         i.debit_ent_amt,
         i.credit_acctd_amt,
         i.debit_acctd_amt,
         i.code_combination_id,
         i.line_desciption,
         l_group_id);
      -------------------------------------------------
      --reerve account
      -------------------------------------------------

      INSERT INTO gl_interface
        (status,
         ledger_id,
         accounting_date,
         currency_code,
         date_created,
         created_by,
         actual_flag,
         user_je_category_name,
         user_je_source_name,
         currency_conversion_date,
         encumbrance_type_id, --
         user_currency_conversion_type,
         currency_conversion_rate,
         entered_dr,
         entered_cr,
         accounted_dr,
         accounted_cr,
         code_combination_id,
         reference10,
         group_id)
      VALUES
        ('NEW',
         i.ledger_id,
         i.orig_accounting_date,
         i.currency_code,
         SYSDATE,
         fnd_global.user_id,
         'E',
         'Other', --'Requisitions',
         'Encumbrance', --'Purchasing',
         i.curr_coversion_date,
         1000,
         i.curr_coversion_type,
         i.curr_coversion_rate,
         i.debit_ent_amt,
         i.credit_ent_amt,
         i.debit_acctd_amt,
         i.credit_acctd_amt,
         l_rev_account_id,
         i.line_desciption,
         l_group_id);
      -----------------------------------------------------
      l_ledger_id := i.ledger_id;
      l_gl_exists := 1;
    END LOOP;
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
      IF (l_conc_id = 0) THEN
        fnd_file.put_line(fnd_file.log,
                          'Eror while running import program');
        l_bool := fnd_concurrent.set_completion_status('WARNING',
                                                       'Eror while running import program');
      END IF;
    END IF;
    UPDATE xx_po_change_encumbrance xpc
       SET xpc.group_id = l_group_id
     WHERE xpc.group_id IS NULL;
    COMMIT;
  END;

  ------------------------
  FUNCTION get_value_from_line(p_line_string IN OUT VARCHAR2,
                               p_err_msg     IN OUT VARCHAR2,
                               p_counter     IN NUMBER,
                               c_delimiter   IN VARCHAR2) RETURN VARCHAR2 IS

    l_pos        NUMBER;
    l_char_value VARCHAR2(20);

  BEGIN
    p_err_msg := null;
    l_pos     := instr(p_line_string, c_delimiter);

    IF nvl(l_pos, 0) < 1 THEN
      l_pos := length(p_line_string);
    END IF;

    l_char_value := ltrim(rtrim(substr(p_line_string, 1, l_pos - 1)));

    p_line_string := substr(p_line_string, l_pos + 1);

    RETURN l_char_value;

  END get_value_from_line;
  /*************************************************************************
   Load the file of po nums and line nums
  **************************************************************************/
  PROCEDURE load_file(errbuf     OUT VARCHAR2,
                      retcode    OUT VARCHAR2,
                      p_location IN VARCHAR2,
                      p_filename IN VARCHAR2) IS
    l_file_hundler utl_file.file_type;

    l_line_buffer VARCHAR2(2000);
    l_counter     NUMBER := 0;
    l_err_msg     VARCHAR2(500);
    c_delimiter CONSTANT VARCHAR2(1) := ',';
    l_return_status VARCHAR2(1);
    l_po_num        VARCHAR2(20);
    l_po_line_num   NUMBER;
    l_new_gl_date   DATE;
    l_pos           NUMBER;
  BEGIN
    errbuf  := null;
    retcode := 0;
    /* clean previous data */
    DELETE FROM xx_change_gl_po_lines
     WHERE org_id = fnd_global.org_id
       AND status IS NULL;

    BEGIN
      l_file_hundler := utl_file.fopen(location     => p_location,
                                       filename     => p_filename,
                                       open_mode    => 'r',
                                       max_linesize => 32000);

    EXCEPTION
      WHEN utl_file.invalid_path THEN
        fnd_file.put_line(fnd_file.log,
                          'Invalid Path for ' || ltrim(p_filename));
        RAISE;
      WHEN utl_file.invalid_mode THEN
        fnd_file.put_line(fnd_file.log,
                          'Invalid Mode for ' || ltrim(p_filename));
        RAISE;
      WHEN utl_file.invalid_operation THEN
        fnd_file.put_line(fnd_file.log,
                          'Invalid operation for ' || ltrim(p_filename) ||
                          SQLERRM);
        RAISE;
      WHEN OTHERS THEN
        fnd_file.put_line(fnd_file.log, 'Other for ' || ltrim(p_filename));
        RAISE;
    END;
    ------------------------------------------------------
    LOOP

      BEGIN
        -- goto next line

        l_counter       := l_counter + 1;
        l_err_msg       := NULL;
        l_return_status := NULL;

        BEGIN
          utl_file.get_line(file   => l_file_hundler,
                            buffer => l_line_buffer);
        EXCEPTION
          WHEN utl_file.read_error THEN
            l_err_msg := 'Read Error for line: ' || l_counter;
            RAISE;
          WHEN no_data_found THEN
            EXIT;
          WHEN OTHERS THEN
            l_err_msg := 'Read Error for line: ' || l_counter ||
                         ', Error: ' || SQLERRM;
            RAISE;
        END;

        l_pos := 0;

        l_po_num := get_value_from_line(l_line_buffer,
                                        l_err_msg,
                                        l_counter,
                                        c_delimiter);

        l_po_line_num := get_value_from_line(l_line_buffer,
                                             l_err_msg,
                                             l_counter,
                                             c_delimiter);
        l_new_gl_date := to_date(get_value_from_line(l_line_buffer,
                                                     l_err_msg,
                                                     l_counter,
                                                     c_delimiter),
                                 'dd/mm/yyyy');
        IF l_po_num IS NOT NULL THEN
          INSERT INTO xx_change_gl_po_lines
            (po_num, po_line_num, new_gl_date, org_id)
          VALUES
            (l_po_num, l_po_line_num, l_new_gl_date, fnd_global.org_id);
        END IF;
      EXCEPTION
        WHEN OTHERS THEN
          l_err_msg := SQLERRM;
          fnd_file.put_line(fnd_file.log, l_err_msg);
          ROLLBACK;
      END;

    END LOOP;
    utl_file.fclose(l_file_hundler);
    COMMIT;
  END;
  /*************************************************************************
   Reapprove all the documents
  **************************************************************************/
  PROCEDURE approve_docs IS
    p_return_status VARCHAR2(50);
    p_exception_msg VARCHAR2(200);

    CURSOR c_lines IS
      SELECT h.po_header_id, xcg.po_num, xcg.po_line_num
        FROM po_headers_all h, xx_change_gl_po_lines xcg
       WHERE h.segment1 = xcg.po_num
         AND h.org_id = xcg.org_id
         AND h.org_id = fnd_global.org_id
         AND xcg.status = 'DONE';

  BEGIN

    FOR i IN c_lines LOOP

      po_document_action_pvt.do_approve(p_document_id => i.po_header_id,

                                        p_document_type => 'PO',

                                        p_document_subtype => 'STANDARD',

                                        p_note => 'Reapprove after GL Date change',

                                        p_approval_path_id => NULL,

                                        x_return_status => p_return_status,

                                        x_exception_msg => p_exception_msg);
      UPDATE xx_change_gl_po_lines xcg
         SET xcg.status = 'SUCCESS'
       WHERE xcg.po_num = i.po_num
         AND xcg.po_line_num = i.po_line_num;

    END LOOP;

    COMMIT;
  END;
  -----------------------------------------------------
  --  ver   date        name           desc
  --  1.0   15/08/2011  Bellona.B      CHG0046530 - initial build
  -----------------------------------------------------
  PROCEDURE po_received_not_invoice_je(errbuf     OUT VARCHAR2,
                                       retcode    OUT VARCHAR2,
                                       p_period   IN VARCHAR2)
  IS
  l_rev_account_id   NUMBER;
  l_group_id         NUMBER;
  l_ledger_id        NUMBER;
  l_interface_run_id NUMBER;
  l_conc_id          NUMBER;
  l_bool             BOOLEAN;
  l_message          VARCHAR2(100);
  l_gl_exists        NUMBER; --
  l_phase            VARCHAR2(100);
  l_status           VARCHAR2(100);
  l_dev_phase        VARCHAR2(100);
  l_dev_status       VARCHAR2(100);

  cursor c_lines is
    select 'Other' Ctegory,
     'USD' currency_code,
     gp.end_date + 1 Accounting_date,
     'Obligation' Encumbrance_Type,
     gcc.code_combination_id,
     sum(round((pda.quantity_ordered -
               (pda.quantity_billed + pda.quantity_cancelled)) *
               plla.price_override * nvl(ph.rate, 1))) debit_acctd_amt,
     null credit_acctd_amt,
     'JE cahge gl date of PO ' || ph.segment1 || ' Line Number ' ||
     pll.line_num line_desciption,
     gll.ledger_id
    
      from apps.po_line_locations_all plla,
           po_lines_all               pll,
           apps.po_headers            ph,
           apps.po_distributions_all  pda,
           apps.gl_code_combinations  gcc,
           gl_periods                 gp,
           gl_ledgers                 gll
     where plla.quantity_received > plla.quantity_billed
       and ph.po_header_id = plla.po_header_id
       and pda.line_location_id = plla.line_location_id
       and gcc.code_combination_id = pda.code_combination_id
       and (gcc.account_type = 'E' or exists
            (select 1
               from fa_category_books fcb
              where (fcb.asset_clearing_acct = gcc.segment3 or
                    fcb.asset_cost_acct = gcc.segment3)))
       and plla.closed_code <> 'FINALLY CLOSED'
       and pda.gl_encumbered_date between gp.quarter_start_date and
           add_months(gp.quarter_start_date, 3) - 1
       and gp.period_name = p_period--"&concurrent parameter"
          -- and ph.org_id = 81 --in (81, 737)
       and pll.po_line_id = plla.po_line_id
       and gll.ledger_id = pda.set_of_books_id
    
     group by ph.segment1,
              gll.ledger_id,
              gp.end_date,
              pll.line_num,
              gcc.code_combination_id
    
    having sum((pda.quantity_ordered - (pda.quantity_billed + pda.quantity_cancelled)) * plla.price_override * nvl(ph.rate, 1)) > fnd_profile.VALUE('XXGL_MIN_ENC_FWD_AMT'); --profile_value;
    
  BEGIN
    errbuf  := null;
    retcode := 0;
    /*fnd_global.apps_initialize(user_id      => 3930,
                               resp_id      => 50575,
                               resp_appl_id => 101);

    mo_global.set_policy_context('S', 81);*/

    SELECT gl_interface_control_s.NEXTVAL, gl_journal_import_s.NEXTVAL
      INTO l_group_id, l_interface_run_id
      FROM dual;
    l_gl_exists := 0;
    for i in c_lines loop
       
      IF l_rev_account_id IS NULL THEN
        SELECT res_encumb_code_combination_id
          INTO l_rev_account_id
          FROM gl_ledgers l
         WHERE l.ledger_id = i.ledger_id;
      END IF;
      ------------------------
      INSERT INTO gl_interface
        (status,
         ledger_id,
         accounting_date,
         currency_code,
         date_created,
         created_by,
         actual_flag,
         user_je_category_name,
         user_je_source_name,
         encumbrance_type_id, --
         entered_dr,
         entered_cr,
         accounted_dr,
         accounted_cr,
         code_combination_id,
         group_id,
         reference10)
      VALUES
        ('NEW',
         i.ledger_id,
         i.accounting_date,
         i.currency_code,
         SYSDATE,
         fnd_global.user_id,
         'E',
         'Other', --'Requisitions',
         'Encumbrance', --'Purchasing',
         -- i.curr_coversion_date,
         1000,
         --  i.accounting_date,
         --   i.curr_coversion_rate,
         -- i.debit_ent_amt,
         --  i.credit_ent_amt,
         i.debit_acctd_amt,
         i.credit_acctd_amt,
         i.debit_acctd_amt,
         i.credit_acctd_amt,
         i.code_combination_id,
         l_group_id,
         i.line_desciption);
      -------------------------------------------------
      --reerve account
      -------------------------------------------------
      INSERT INTO gl_interface
        (status,
         ledger_id,
         accounting_date,
         currency_code,
         date_created,
         created_by,
         actual_flag,
         user_je_category_name,
         user_je_source_name,
         encumbrance_type_id, --
         entered_dr,
         entered_cr,
         accounted_dr,
         accounted_cr,
         code_combination_id,
         group_id,
         reference10)
      VALUES
        ('NEW',
         i.ledger_id,
         i.accounting_date,
         i.currency_code,
         SYSDATE,
         fnd_global.user_id,
         'E',
         'Other', --'Requisitions',
         'Encumbrance', --'Purchasing',
         -- i.curr_coversion_date,
         1000,
         i.credit_acctd_amt,
         i.debit_acctd_amt,
         i.credit_acctd_amt,
         i.debit_acctd_amt,
         l_rev_account_id,
         l_group_id,
         i.line_desciption);
      
      ------------------------
      
      l_ledger_id := i.ledger_id;
      l_gl_exists := 1;
    end loop;

    IF l_gl_exists = 1 THEN
      INSERT INTO gl_interface_control
        (status, je_source_name, group_id, set_of_books_id, interface_run_id)
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
      IF (l_conc_id = 0) THEN
        fnd_file.put_line(fnd_file.log, 'Eror while running import program');
        l_bool := fnd_concurrent.set_completion_status('WARNING',
                                                       'Eror while running import program');
      END IF;
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      errbuf := SQLERRM;
      retcode := 2;
      fnd_file.put_line(fnd_file.log, errbuf);
      ROLLBACK;                                           
  END; 
  -----------------------------
  --------------------------------------
  --1.1  15/01/2018  Ofer Suad CHG0041827  error log
  -------------------------------
  PROCEDURE write_log_message(p_po_number VARCHAR2,
                              p_po_line   Number,
                              Po_msg      VARCHAR2) is
  begin
    fnd_file.put_line(fnd_file.OUTPUT,'<tr><td>'||p_po_number||'</td><td>'||p_po_line||'</td><td>'||Po_msg||'</td></tr>');
  end write_log_message;

END xx_po_gl_date_change;
/