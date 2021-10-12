CREATE OR REPLACE PACKAGE BODY xxgl_ledger_report_pkg IS

   PROCEDURE calc_openning_balances(in_gl_comb_id          IN NUMBER,
                                    in_period_name         IN VARCHAR2,
                                    p_ledger_id            IN NUMBER,
                                    out_functional_balance OUT NUMBER) IS
      v_functional_currency VARCHAR2(3);
   BEGIN
      BEGIN
      
         SELECT gle.currency_code
           INTO v_functional_currency
           FROM gl_ledgers gle
          WHERE gle.ledger_id = p_ledger_id;
      
         -- Get Balance for period
         SELECT nvl(begin_balance_dr, 0) - nvl(begin_balance_cr, 0)
           INTO out_functional_balance
           FROM gl_balances
          WHERE code_combination_id = in_gl_comb_id AND
                period_name = in_period_name AND
                actual_flag = 'A' AND
                ledger_id = p_ledger_id --2021 -- Accouting book
                AND
                currency_code = v_functional_currency; --'USD';
      EXCEPTION
         WHEN OTHERS THEN
            out_functional_balance := 0;
      END;
      /*begin
        select nvl(begin_balance_dr, 0) - nvl(begin_balance_cr, 0)
          into out_reporting_balance
          from gl_balances
         where code_combination_id = in_gl_comb_id
           and period_name = in_period_name
           and actual_flag = 'A'
           and ledger_id = 2024 -- Reporting book
           and currency_code = 'ILS';
      exception
        when others then
          out_reporting_balance := 0;
      end;*/ -- Excluding MRC
   END calc_openning_balances;

   PROCEDURE gather_information(errbuf        OUT VARCHAR2,
                                retcode       OUT VARCHAR2,
                                p_from_period IN VARCHAR2,
                                p_to_period   IN VARCHAR2,
                                p_ledger_id   IN NUMBER) IS
      CURSOR c_transactions(p_from_date IN DATE, p_to_date IN DATE) IS
         SELECT l.je_header_id,
                l.je_line_num,
                h.NAME je_name,
                h.je_source,
                l.code_combination_id,
                fnd_flex_ext.get_segs('SQLGL',
                                      'GL#',
                                      gcc.chart_of_accounts_id,
                                      l.code_combination_id) account,
                gcc.segment2 account_segment_2,
                gcc.segment3 account_segment_3,
                l.effective_date gl_date,
                l.accounted_dr,
                l.accounted_cr,
                h.je_category,
                h.currency_code
           FROM gl_je_headers h, gl_je_lines l, gl_code_combinations gcc
          WHERE l.je_header_id = h.je_header_id AND
                l.code_combination_id = gcc.code_combination_id AND
                h.ledger_id = p_ledger_id --2021
                AND
                h.actual_flag = 'A' AND
                l.effective_date BETWEEN p_from_date AND p_to_date
               --and l.code_combination_id = 4028 --nitai
                --AND
                --gcc.segment3 BETWEEN '000000' AND '129000' --daniel !!! to delete
          ORDER BY code_combination_id;
   
      CURSOR c_xla_distributions(p_gl_sl_link_id NUMBER, p_gl_sl_link_table VARCHAR2) IS
         SELECT xd.unrounded_accounted_dr,
                xd.unrounded_accounted_cr,
                l.gl_sl_link_id,
                xd.source_distribution_id_num_1
           FROM xla_ae_lines l, xla_ae_headers h, xla_distribution_links xd --, xla_ae_headers h1, xla_ae_lines l1
          WHERE /*h.event_id = h1.event_id
                                                          and */
          h.ledger_id = p_ledger_id --2024
          AND
          h.ae_header_id = xd.ae_header_id AND
          l.ae_line_num = xd.ae_line_num AND
          h.balance_type_code = 'A' AND
          h.gl_transfer_status_code = 'Y'
         --and xd.application_id <> 707 --nitai
         --and l1.ae_header_id = h1.ae_header_id
         --and l1.ae_line_num = l.ae_line_num
          AND
          h.ae_header_id = l.ae_header_id AND
          h.application_id = l.application_id AND
          l.gl_sl_link_id = p_gl_sl_link_id AND
          l.gl_sl_link_table = p_gl_sl_link_table
         UNION ALL
         SELECT l.accounted_dr, l.accounted_cr, NULL, NULL
           FROM gl_je_headers h, gl_je_lines l
          WHERE h.je_header_id = l.je_header_id AND
                l.je_line_num = l.je_line_num AND
                h.parent_je_header_id = l.je_header_id AND
                h.ledger_id = p_ledger_id --2024;
                AND
                p_gl_sl_link_id IS NULL;
   
      cur_xla_distribution c_xla_distributions%ROWTYPE;
      /*
        cursor c_reporting_transaction(p_code_comb_id number, p_from_date date, p_to_date date) is
          select l.accounted_dr, l.accounted_cr, l.effective_date gl_date
            from gl_je_lines l, gl_je_headers h, gl_je_batches b
           where h.je_header_id = l.je_header_id
             and h.je_batch_id = b.je_batch_id
             and h.ledger_id = p_ledger_id --2024
             and h.actual_flag = 'A'
             and l.gl_sl_link_id is null
             and h.parent_je_header_id is null
             and b.parent_je_batch_id is null
             and l.code_combination_id = p_code_comb_id
             and l.effective_date between p_from_date and p_to_date;
      */ -- Excluding MRC
      l_from_date             DATE;
      l_to_date               DATE;
      l_request_id            NUMBER := fnd_global.conc_request_id;
      l_prevoius_gl_comb      NUMBER := 0;
      l_prevoius_account      VARCHAR2(100);
      l_prev_segment_2        VARCHAR2(20);
      l_prev_segment_3        VARCHAR2(20);
      l_line_number           NUMBER;
      l_functional_balance    NUMBER;
      l_reporting_balance     NUMBER;
      l_reporting_dr          NUMBER;
      l_reporting_cr          NUMBER;
      l_je_name               VARCHAR2(50);
      l_gl_sl_link_id         NUMBER;
      l_gl_sl_link_table      VARCHAR2(50);
      l_transaction_number    VARCHAR2(50);
      l_instance_number       VARCHAR2(50);
      l_trx_type              VARCHAR2(50);
      l_reference_1           VARCHAR2(50);
      l_reference_2           VARCHAR2(50);
      l_party_id              NUMBER;
      l_party_type            VARCHAR2(10);
      l_party_name            VARCHAR2(100);
      l_ref1_meaning          VARCHAR2(100);
      l_ref2_meaning          VARCHAR2(100);
      l_accounting_class_code VARCHAR2(100);
   
   BEGIN
      retcode := '0';
      errbuf  := '';
   
      -- Delete old temporary records
      DELETE FROM xxobjt_ledger_report_tmp
       WHERE creation_date < SYSDATE - 7 OR
             request_id = l_request_id;
      COMMIT;
   
      SELECT start_date
        INTO l_from_date
        FROM gl_periods
       WHERE period_name = p_from_period AND
             period_set_name = 'OBJET_CALENDAR';
   
      SELECT end_date
        INTO l_to_date
        FROM gl_periods
       WHERE period_name = p_to_period AND
             period_set_name = 'OBJET_CALENDAR';
   
      FOR i IN c_transactions(l_from_date, l_to_date) LOOP
         IF i.code_combination_id <> l_prevoius_gl_comb THEN
            IF l_prevoius_gl_comb > 0 THEN
               -- insert reporting GL Lines
               /*for j in c_reporting_transaction(l_prevoius_gl_comb, l_from_date, l_to_date) loop
                   l_line_number := l_line_number + 1;
                   l_reporting_balance := l_reporting_balance +
                                (nvl(j.accounted_dr, 0) - nvl(j.accounted_cr, 0));
                   insert into XXOBJT_LEDGER_REPORT_TMP
                     (creation_date,
                      request_id,
                      code_combination_id,
                      account,
                      account_segment_2,
                      account_segment_4,
                      line_number,
                      reporting_debit,
                      reporting_credit,
                      reporting_balance,
                      gl_date)
                   values
                     (sysdate,
                      l_request_id,
                      l_prevoius_gl_comb,
                      l_prevoius_account,
                      l_prev_segment_2,
                      l_prev_segment_4,
                      l_line_number,
                      j.accounted_dr,
                      j.accounted_cr,
                      l_reporting_balance,
                      j.gl_date);
                 end loop;
               */ -- Excluding MRC
               -- insert closing record for old account
               INSERT INTO xxobjt_ledger_report_tmp
                  (creation_date,
                   request_id,
                   code_combination_id,
                   account,
                   account_segment_2,
                   account_segment_3,
                   line_number,
                   cumulative_functional_balance,
                   reporting_balance,
                   gl_date,
                   je_source,
                   je_category,
                   entered_currency,
                   report_line_number)
               VALUES
                  (SYSDATE,
                   l_request_id,
                   l_prevoius_gl_comb,
                   l_prevoius_account,
                   l_prev_segment_2,
                   l_prev_segment_3,
                   9999999999,
                   l_functional_balance,
                   l_reporting_balance,
                   l_to_date,
                   i.je_source,
                   i.je_category,
                   i.currency_code,
                   9999999999);
            END IF;
            -- Calculate openning baget for new account
            calc_openning_balances(i.code_combination_id,
                                   p_from_period,
                                   p_ledger_id,
                                   l_functional_balance /*,
                                                                                                                                                                                                                                                  l_reporting_balance*/);
            l_prevoius_gl_comb := i.code_combination_id;
            l_prevoius_account := i.account;
            l_prev_segment_2   := i.account_segment_2;
            l_prev_segment_3   := i.account_segment_3;
            l_line_number      := 0;
            --insert openning record for new account
            INSERT INTO xxobjt_ledger_report_tmp
               (creation_date,
                request_id,
                code_combination_id,
                account,
                account_segment_2,
                account_segment_3,
                line_number,
                cumulative_functional_balance,
                reporting_balance,
                gl_date,
                je_source,
                je_category,
                entered_currency,
                report_line_number)
            VALUES
               (SYSDATE,
                l_request_id,
                i.code_combination_id,
                l_prevoius_account,
                l_prev_segment_2,
                l_prev_segment_3,
                0,
                l_functional_balance,
                NULL, --l_reporting_balance,
                l_from_date,
                i.je_source,
                i.je_category,
                i.currency_code,
                0);
         END IF;
      
         -- Calculate reporing transaction and balance
         BEGIN
            SELECT /*+ leading(ir) */
             ir.gl_sl_link_id, ir.gl_sl_link_table
              INTO l_gl_sl_link_id, l_gl_sl_link_table
              FROM gl_import_references ir
             WHERE ir.je_header_id = i.je_header_id AND
                   ir.je_line_num = i.je_line_num;
         EXCEPTION
            WHEN OTHERS THEN
               l_gl_sl_link_id    := NULL;
               l_gl_sl_link_table := NULL;
         END;
         -- begin
         /*if l_gl_sl_link_id is null then
           select l.accounted_dr, l.accounted_cr
             into l_reporting_dr, l_reporting_cr
             from gl_je_headers h, gl_je_lines l
            where h.je_header_id = l.je_header_id
              and l.je_line_num = i.je_line_num
              and h.parent_je_header_id = i.je_header_id
              and h.ledger_id = p_ledger_id; --2024;
         else
         8888888888888888888888888888888888
           select xd.unrounded_accounted_dr, xd.unrounded_accounted_cr
             into l_reporting_dr, l_reporting_cr,l.gl_sl_link_id,xd.source_distribution_id_num_1
             from xla_ae_lines l, xla_ae_headers h ,xla_distribution_links xd     --, xla_ae_headers h1, xla_ae_lines l1
            where \*h.event_id = h1.event_id
              and *\h.ledger_id = p_ledger_id --2024
              and h.ae_header_id=xd.ae_header_id
              and l.ae_line_num=xd.ae_line_num
              and h.balance_type_code = 'A'
              and h.gl_transfer_status_code='Y'
              --and l1.ae_header_id = h1.ae_header_id
              --and l1.ae_line_num = l.ae_line_num
              and h.ae_header_id = l.ae_header_id
              and h.application_id = l.application_id
              and l.gl_sl_link_id = l_gl_sl_link_id
              and l.gl_sl_link_table = l_gl_sl_link_table;
         end if;*/
         FOR cur_xla_distribution IN c_xla_distributions(l_gl_sl_link_id,
                                                         l_gl_sl_link_table) LOOP
         
            l_line_number        := l_line_number + 1;
            l_functional_balance := l_functional_balance +
                                    (nvl(cur_xla_distribution.unrounded_accounted_dr,
                                         0) - nvl(cur_xla_distribution.unrounded_accounted_cr,
                                                   0));
         
            l_reporting_dr := cur_xla_distribution.unrounded_accounted_dr;
            l_reporting_cr := cur_xla_distribution.unrounded_accounted_cr;
         
            l_reporting_balance := l_reporting_balance +
                                   (nvl(l_reporting_dr, 0) -
                                   nvl(l_reporting_cr, 0));
            /*  exception
              when others then
                l_reporting_dr := null;
                l_reporting_cr := null;
            end;*/
            -- Calculate XLA record and matching transaction
            BEGIN
               SELECT l.instance_number,
                      l.source_inst_number,
                      l.party_name,
                      l.accounting_class_code,
                      l.ref1_meaning,
                      l.reference1,
                      l.ref2_meaning,
                      l.reference2 --,nitai
               --l.party_name nitai
               --te.transaction_number, l.party_id, l.party_type_code
                 INTO l_transaction_number,
                      l_instance_number,
                      l_party_name,
                      l_accounting_class_code,
                      l_ref1_meaning,
                      l_reference_1,
                      l_ref2_meaning,
                      l_reference_2 --, nitai
               --l_party_name nitai
                 FROM xxgl_sl_reference_v l --xla.xla_transaction_entities te, xla_ae_lines l, xla_ae_headers h
                WHERE /*te.entity_id = h.entity_id
                                                                                    and te.application_id = h.application_id
                                                                                    and h.ae_header_id = l.ae_header_id
                                                                                    and h.application_id = l.application_id
                                                                                    and */
                l.gl_sl_link_id = l_gl_sl_link_id AND
                l.source_distribution_id_num_1 =
                cur_xla_distribution.source_distribution_id_num_1 --nitai
               /* and
                                                                  l. */
               ;
               --and l.gl_sl_link_table = l_gl_sl_link_table;
            
               /*if l_party_type = 'S' then
                 select vendor_name
                   into l_party_name
                   from ap_suppliers
                  where vendor_id = l_party_id;
               elsif l_party_type = 'C' then
                 select customer_name
                   into l_party_name
                   from ar_customers_all_v
                  where customer_id = l_party_id;
               else
                 l_party_name := null;
               end if;*/
            EXCEPTION
               WHEN OTHERS THEN
                  l_ref2_meaning := SQLERRM;
               
                  l_transaction_number := NULL;
                  l_instance_number    := NULL;
                  l_trx_type           := NULL;
                  l_reference_1        := NULL;
                  l_reference_2        := NULL;
            END;
         
            -- insert record for current transaction
            INSERT INTO xxobjt_ledger_report_tmp
               (creation_date,
                request_id,
                code_combination_id,
                account,
                account_segment_2,
                account_segment_3,
                line_number,
                transaction_number,
                gl_date,
                functional_debit,
                functional_credit,
                cumulative_functional_balance,
                reporting_debit,
                reporting_credit,
                reporting_balance,
                party_name, --contra_account,
                instance_number,
                trx_type,
                ref1_meaning,
                reference_1,
                ref2_meaning,
                reference_2,
                je_source,
                je_category,
                entered_currency,
                gl_sl_link_id,
                source_distribution_id_num_1,
                je_name,
                report_line_number)
            VALUES
               (SYSDATE,
                l_request_id,
                i.code_combination_id,
                i.account,
                i.account_segment_2,
                i.account_segment_3,
                i.je_line_num,
                l_transaction_number,
                i.gl_date,
                i.accounted_dr,
                i.accounted_cr,
                l_functional_balance,
                l_reporting_dr,
                l_reporting_cr,
                l_reporting_balance,
                l_party_name,
                l_instance_number,
                l_trx_type,
                l_ref1_meaning,
                l_reference_1,
                l_ref2_meaning,
                l_reference_2,
                i.je_source,
                i.je_category,
                i.currency_code,
                cur_xla_distribution.gl_sl_link_id,
                cur_xla_distribution.source_distribution_id_num_1,
                i.je_name,
                l_line_number);
         END LOOP; --distribution
      END LOOP;
      IF l_prevoius_gl_comb > 0 THEN
         -- insert reporting GL Lines
         /*for j in c_reporting_transaction(l_prevoius_gl_comb, l_from_date, l_to_date) loop
           l_line_number := l_line_number + 1;
           l_reporting_balance := l_reporting_balance +
                        (nvl(j.accounted_dr, 0) - nvl(j.accounted_cr, 0));
           insert into XXOBJT_LEDGER_REPORT_TMP
             (creation_date,
              request_id,
              code_combination_id,
              account,
              account_segment_2,
              account_segment_4,
              line_number,
              reporting_debit,
              reporting_credit,
              reporting_balance,
              gl_date)
           values
             (sysdate,
              l_request_id,
              l_prevoius_gl_comb,
              l_prevoius_account,
              l_prev_segment_2,
              l_prev_segment_4,
              l_line_number,
              j.accounted_dr,
              j.accounted_cr,
              l_reporting_balance,
              j.gl_date);
         end loop;*/ -- Excluding MRC
         -- insert closing record for last account
         INSERT INTO xxobjt_ledger_report_tmp
            (creation_date,
             request_id,
             code_combination_id,
             account,
             account_segment_2,
             account_segment_3,
             line_number,
             cumulative_functional_balance,
             reporting_balance,
             gl_date)
         VALUES
            (SYSDATE,
             l_request_id,
             l_prevoius_gl_comb,
             l_prevoius_account,
             l_prev_segment_2,
             l_prev_segment_3,
             9999999999,
             l_functional_balance,
             l_reporting_balance,
             l_to_date);
      END IF;
      COMMIT;
   EXCEPTION
      WHEN OTHERS THEN
         retcode := '2';
         errbuf  := 'Error gathering information for ledger report: ' ||
                    SQLERRM;
   END gather_information;

END xxgl_ledger_report_pkg;
/

