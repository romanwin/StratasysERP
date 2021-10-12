CREATE OR REPLACE PACKAGE BODY xxconv_ap_upload_invoice_pkg IS
   /*
      TYPE tbl_of_str IS TABLE OF VARCHAR2(2000) INDEX BY BINARY_INTEGER;
   
      PROCEDURE load_file(p_file_name     IN VARCHAR2,
                          x_error_message OUT VARCHAR2) IS
         l_file      utl_file.file_type;
         l_line      VARCHAR2(32000);
         l_line_data tbl_of_str;
      
         l_pos1 NUMBER;
         l_pos2 NUMBER;
      BEGIN
         -- Open file
         BEGIN
            l_file := utl_file.fopen(fnd_profile.VALUE('XXRTX_LOAD_PATH'),
                                     p_file_name,
                                     'r');
         EXCEPTION
            WHEN OTHERS THEN
               x_error_message := 'Error openning file: ' || SQLERRM;
               RETURN;
         END;
         -- Ignore first 8 rows of file
         FOR i IN 1 .. 8 LOOP
            utl_file.get_line(l_file, l_line);
         END LOOP;
      
         -- Load file to temp table
         BEGIN
            LOOP
               l_pos1 := 0;
               l_pos2 := 1;
               FOR i IN 1 .. 13 LOOP
                  l_line_data(i) := NULL;
               END LOOP;
               utl_file.get_line(l_file, l_line);
            
               -- Parse line data
               FOR i IN 1 .. 13 LOOP
                  l_pos1 := instr(l_line, ',', l_pos2);
                  l_pos2 := instr(l_line, ',', l_pos1 + 1);
                  IF i = 1 THEN
                     l_pos2 := l_pos1;
                     l_line_data(i) := substr(l_line, 1, l_pos1 - 1);
                  ELSIF i < 13 THEN
                     l_line_data(i) := substr(l_line,
                                              l_pos1 + 1,
                                              l_pos2 - l_pos1 - 1);
                  ELSE
                     l_line_data(i) := substr(l_line, l_pos1 + 1);
                  END IF;
               END LOOP;
               -- Insert to temp table
               INSERT INTO xxobjt_conv_ap_invoices
                  (conc_request_id,
                   invoice_num,
                   invoice_date,
                   vendor_num,
                   vendor_name,
                   vendor_site_code,
                   invoice_amount,
                   invoice_currency_code,
                   gl_date,
                   line_number,
                   amount,
                   description,
                   tax_code,
                   dist_code_concatenated,
                   int_status)
               VALUES
                  (fnd_global.conc_request_id,
                   l_line_data(4),
                   l_line_data(5),
                   l_line_data(1),
                   l_line_data(2),
                   l_line_data(3),
                   to_number(l_line_data(7)),
                   l_line_data(6),
                   l_line_data(8),
                   to_number(l_line_data(9)),
                   to_number(l_line_data(10)),
                   l_line_data(13),
                   l_line_data(11),
                   l_line_data(12),
                   'N');
            
            END LOOP;
         EXCEPTION
            WHEN no_data_found THEN
               -- End of file
               IF utl_file.is_open(l_file) THEN
                  utl_file.fclose(l_file);
               END IF;
            WHEN OTHERS THEN
               x_error_message := 'Error reading file: ' || SQLERRM;
               ROLLBACK;
               IF utl_file.is_open(l_file) THEN
                  utl_file.fclose(l_file);
               END IF;
         END;
         COMMIT;
      EXCEPTION
         WHEN OTHERS THEN
            x_error_message := 'Unexpected error: ' || SQLERRM;
            ROLLBACK;
            IF utl_file.is_open(l_file) THEN
               utl_file.fclose(l_file);
            END IF;
      END load_file;
   
      \*
        procedure validate_header(p_user_name    in varchar2,
                                  p_resp_name    in varchar2,
                                  p_file_name    in varchar2,
                                  p_email        in varchar2,
                                  x_user_id      out number,
                                  x_resp_id      out number,
                                  x_resp_appl_id out number,
                                  x_status       out number) is
          l_count number;
        begin
          x_status := 0;
          select user_id
            into x_user_id
            from fnd_user
           where user_name = p_user_name;
      
          select responsibility_id, application_id
            into x_resp_id, x_resp_appl_id
            from fnd_responsibility_tl
           where responsibility_name = p_resp_name
             and language = 'US';
      
          select count(*)
            into l_count
            from fnd_user_resp_groups_direct
           where user_id = x_user_id
             and responsibility_id = x_resp_id
             and responsibility_application_id = x_resp_appl_id
             and sysdate between start_date and nvl(end_date, sysdate + 1);
      
          if l_count = 0 then
            raise no_data_found;
          end if;
        exception
          when others then
            x_status := -1;
            xx_smtp_utilities.send_mail(null,
                                          p_email,
                                          'File was not processed',
                                          'File ' || p_file_name ||
                                          ' was not processed, due to header validation failure. ' ||
                                          'Please check your user name and responsibility.',
                                          'Retalix AP Invoice Interface');
      
        end validate_header;
      *\
   
      PROCEDURE validate(p_user_id      IN NUMBER,
                         p_resp_id      IN NUMBER,
                         p_resp_appl_id IN NUMBER) IS
         CURSOR c_vendor IS
            SELECT DISTINCT vendor_num
              FROM xxap_upload_invoices_tmp inv
             WHERE inv.status = 0 AND
                   inv.conc_request_id = fnd_global.conc_request_id;
      
         CURSOR c_vendor_site IS
            SELECT DISTINCT vendor_id, vendor_site_code
              FROM xxap_upload_invoices_tmp inv
             WHERE inv.status = 10 AND
                   inv.conc_request_id = fnd_global.conc_request_id;
      
         CURSOR c_tax_code IS
            SELECT DISTINCT org_id, tax_code
              FROM xxap_upload_invoices_tmp inv
             WHERE inv.status = 20 AND
                   inv.conc_request_id = fnd_global.conc_request_id;
      
         CURSOR c_code_combination IS
            SELECT DISTINCT org_id, dist_code_concatenated
              FROM xxap_upload_invoices_tmp inv
             WHERE inv.status = 30 AND
                   inv.conc_request_id = fnd_global.conc_request_id;
      
         CURSOR c_invoice IS
            SELECT DISTINCT vendor_id,
                            vendor_site_id,
                            invoice_num,
                            invoice_date,
                            gl_date
              FROM xxap_upload_invoices_tmp inv
             WHERE inv.status = 40 AND
                   inv.conc_request_id = fnd_global.conc_request_id;
      
         CURSOR c_invoice_line IS
            SELECT *
              FROM xxap_upload_invoices_tmp inv
             WHERE inv.status = 50 AND
                   inv.conc_request_id = fnd_global.conc_request_id
               FOR UPDATE;
      
         l_org_id                NUMBER;
         l_legal_entity_id       NUMBER;
         l_chart_of_accounts_id  NUMBER;
         l_dist_segments         VARCHAR2(250);
         l_seg_cogs              fnd_flex_ext.segmentarray;
         l_dot_pos               NUMBER;
         l_segment_counter       NUMBER;
         l_cc_id                 NUMBER;
         l_ok                    BOOLEAN;
         l_vendor_id             NUMBER;
         l_vendor_site_id        NUMBER;
         l_payment_currency_code VARCHAR2(20);
         l_payment_method_code   VARCHAR2(20) := 'CHECK';
         l_payment_terms_id      NUMBER;
         l_count                 NUMBER;
         l_invoice_id            NUMBER;
         l_invoice_line_id       NUMBER;
         l_dummy_date            DATE;
      BEGIN
         -- Delete old records
         DELETE FROM xxap_upload_invoices_tmp
          WHERE status IN (99, -99) AND
                creation_date < SYSDATE - 14;
         COMMIT;
      
         --    fnd_global.apps_initialize(p_user_id, p_resp_id, p_resp_appl_id);
         -- Validate Invoice Headers
         FOR i IN c_vendor LOOP
            -- Step 1: Calculate vendor_id
            BEGIN
               SELECT vendor_id
                 INTO l_vendor_id
                 FROM ap_suppliers
                WHERE segment1 = i.vendor_num;
            
               UPDATE xxap_upload_invoices_tmp inv
                  SET inv.vendor_id = l_vendor_id, status = 10
                WHERE inv.vendor_num = i.vendor_num AND
                      status = 0 AND
                      inv.conc_request_id = fnd_global.conc_request_id;
            EXCEPTION
               WHEN OTHERS THEN
                  UPDATE xxap_upload_invoices_tmp inv
                     SET inv.status             = -1,
                         inv.status_description = 'Validation failed: No supplier found with this number.'
                   WHERE inv.vendor_num = i.vendor_num AND
                         status = 0 AND
                         inv.conc_request_id = fnd_global.conc_request_id;
            END;
         END LOOP;
         COMMIT;
         FOR i IN c_vendor_site LOOP
            -- Step 2: Calculate vendor_site + defaults
            BEGIN
               SELECT vs.vendor_site_id,
                      vs.org_id,
                      vs.payment_currency_code,
                      vs.terms_id
                 INTO l_vendor_site_id,
                      l_org_id,
                      l_payment_currency_code,
                      l_payment_terms_id
                 FROM ap_supplier_sites_all vs
                WHERE vendor_id = i.vendor_id AND
                      vendor_site_code = i.vendor_site_code AND
                      vs.org_id = fnd_global.org_id;
            
               -- Step 3 - Calculate legal entity for operating unit
               BEGIN
                  SELECT DISTINCT org.legal_entity
                    INTO l_legal_entity_id
                    FROM org_organization_definitions org
                   WHERE org.operating_unit = l_org_id;
               EXCEPTION
                  WHEN OTHERS THEN
                     UPDATE xxap_upload_invoices_tmp inv
                        SET inv.status             = -1,
                            inv.status_description = 'Validation failed: Error culculating legal entity for operating unit.'
                      WHERE inv.vendor_id = i.vendor_id AND
                            inv.vendor_site_code = i.vendor_site_code AND
                            status = 10 AND
                            inv.conc_request_id = fnd_global.conc_request_id;
               END;
            
               UPDATE xxap_upload_invoices_tmp inv
                  SET inv.vendor_site_id        = l_vendor_site_id,
                      inv.org_id                = l_org_id,
                      inv.legal_entity_id       = l_legal_entity_id,
                      inv.payment_currency_code = l_payment_currency_code,
                      inv.payment_method_code   = l_payment_method_code,
                      inv.payment_terms_id      = l_payment_terms_id,
                      status                    = 20
                WHERE inv.vendor_id = i.vendor_id AND
                      inv.vendor_site_code = i.vendor_site_code AND
                      status = 10 AND
                      inv.conc_request_id = fnd_global.conc_request_id;
            EXCEPTION
               WHEN OTHERS THEN
                  UPDATE xxap_upload_invoices_tmp inv
                     SET inv.status             = -1,
                         inv.status_description = 'Validation failed: No supplier Site found with this code.'
                   WHERE inv.vendor_id = i.vendor_id AND
                         inv.vendor_site_code = i.vendor_site_code AND
                         status = 10 AND
                         inv.conc_request_id = fnd_global.conc_request_id;
            END;
         END LOOP;
         COMMIT;
         -- Mark lines with no tax code as, tax code validated.
         UPDATE xxap_upload_invoices_tmp inv
            SET inv.status = 30
          WHERE inv.tax_code IS NULL AND
                status = 20 AND
                inv.conc_request_id = fnd_global.conc_request_id;
         COMMIT;
      
         FOR i IN c_tax_code LOOP
            -- Step 4: Validete that tax code exists
            SELECT COUNT(*)
              INTO l_count
              FROM ap_tax_codes_all
             WHERE NAME = i.tax_code AND
                   org_id = i.org_id AND
                   enabled_flag = 'Y' AND
                   trunc(SYSDATE) BETWEEN nvl(start_date, SYSDATE - 1) AND
                   nvl(inactive_date, SYSDATE + 1);
            IF l_count = 0 THEN
               -- Tax code not found
               UPDATE xxap_upload_invoices_tmp inv
                  SET inv.status             = -1,
                      inv.status_description = 'Validation failed: Tax code was not found.'
                WHERE inv.org_id = i.org_id AND
                      inv.tax_code = i.tax_code AND
                      status = 20 AND
                      inv.conc_request_id = fnd_global.conc_request_id;
            ELSE
               -- Validated
               UPDATE xxap_upload_invoices_tmp inv
                  SET inv.status = 30
                WHERE inv.org_id = i.org_id AND
                      inv.tax_code = i.tax_code AND
                      status = 20 AND
                      inv.conc_request_id = fnd_global.conc_request_id;
            END IF;
         END LOOP;
         COMMIT;
      
         -- Calculate GL code combination id
         FOR i IN c_code_combination LOOP
            BEGIN
               -- Calculate chart of accounts
               SELECT DISTINCT org.chart_of_accounts_id
                 INTO l_chart_of_accounts_id
                 FROM org_organization_definitions org
                WHERE org.operating_unit = i.org_id;
            
               -- Brake down dist segments
               l_ok              := NULL;
               l_cc_id           := NULL;
               l_dot_pos         := -1;
               l_segment_counter := 0;
               l_dist_segments   := i.dist_code_concatenated;
               WHILE l_dot_pos <> 0 LOOP
                  l_dot_pos         := instr(l_dist_segments, '.');
                  l_segment_counter := l_segment_counter + 1;
                  IF l_dot_pos <> 0 THEN
                     l_seg_cogs(l_segment_counter) := substr(l_dist_segments,
                                                             1,
                                                             l_dot_pos - 1);
                     l_dist_segments := substr(l_dist_segments, l_dot_pos + 1);
                  ELSE
                     l_seg_cogs(l_segment_counter) := substr(l_dist_segments,
                                                             1,
                                                             length(l_dist_segments));
                  END IF;
               END LOOP;
               FOR j IN 1 .. l_segment_counter LOOP
                  dbms_output.put_line('Segment ' || j || ' - ' ||
                                       l_seg_cogs(j));
               END LOOP;
               -- Calculate code_combination_id
               l_ok := fnd_flex_ext.get_combination_id('SQLGL',
                                                       'GL#',
                                                       l_chart_of_accounts_id,
                                                       SYSDATE,
                                                       l_segment_counter, --num_segments
                                                       l_seg_cogs,
                                                       l_cc_id);
               IF l_ok THEN
                  UPDATE xxap_upload_invoices_tmp inv
                     SET inv.status                   = 40,
                         inv.dist_code_combination_id = l_cc_id
                   WHERE inv.dist_code_concatenated = i.dist_code_concatenated AND
                         status = 30 AND
                         inv.conc_request_id = fnd_global.conc_request_id;
               ELSE
                  UPDATE xxap_upload_invoices_tmp inv
                     SET inv.status             = -1,
                         inv.status_description = 'Validation failed: Error calculating GL code combination'
                   WHERE inv.dist_code_concatenated = i.dist_code_concatenated AND
                         status = 30 AND
                         inv.conc_request_id = fnd_global.conc_request_id;
               END IF;
            EXCEPTION
               WHEN OTHERS THEN
                  UPDATE xxap_upload_invoices_tmp inv
                     SET inv.status             = -1,
                         inv.status_description = 'Validation failed: Error calculating GL code combination'
                   WHERE inv.dist_code_concatenated = i.dist_code_concatenated AND
                         status = 30 AND
                         inv.conc_request_id = fnd_global.conc_request_id;
            END;
         END LOOP;
         COMMIT;
      
         FOR i IN c_invoice LOOP
            -- Step 6: Check if invoice exits
            BEGIN
               l_dummy_date := to_date(i.invoice_date, 'DD-MON-YY');
               l_dummy_date := to_date(i.gl_date, 'DD-MON-YY');
            
               SELECT COUNT(*)
                 INTO l_count
                 FROM ap_invoices_all a
                WHERE vendor_id = i.vendor_id AND
                      a.vendor_site_id = i.vendor_site_id AND
                      invoice_num = i.invoice_num;
            
               IF l_count = 0 THEN
                  -- Make sure that all lines where validated
                  SELECT COUNT(*)
                    INTO l_count
                    FROM xxap_upload_invoices_tmp inv
                   WHERE inv.vendor_id = i.vendor_id AND
                         inv.vendor_site_id = i.vendor_site_id AND
                         inv.invoice_num = i.invoice_num AND
                         inv.status NOT IN (40, 99, -99) AND
                         inv.conc_request_id = fnd_global.conc_request_id;
                  IF l_count > 0 THEN
                     -- Some of the lines failed. Do not process invoice
                     NULL;
                  ELSE
                     -- Validated
                     SELECT ap_invoices_interface_s.NEXTVAL
                       INTO l_invoice_id
                       FROM dual;
                  
                     UPDATE xxap_upload_invoices_tmp inv
                        SET inv.status = 50, invoice_id = l_invoice_id
                      WHERE inv.vendor_id = i.vendor_id AND
                            inv.vendor_site_id = i.vendor_site_id AND
                            inv.invoice_num = i.invoice_num AND
                            status = 40 AND
                            inv.conc_request_id = fnd_global.conc_request_id;
                  END IF;
               ELSE
                  -- Invoice already exists
                  UPDATE xxap_upload_invoices_tmp inv
                     SET inv.status             = -1,
                         inv.status_description = 'Validation failed: Invoice already exists.'
                   WHERE inv.vendor_id = i.vendor_id AND
                         inv.invoice_num = i.invoice_num AND
                         status = 40 AND
                         inv.conc_request_id = fnd_global.conc_request_id;
               END IF;
            EXCEPTION
               WHEN OTHERS THEN
                  UPDATE xxap_upload_invoices_tmp inv
                     SET inv.status             = -1,
                         inv.status_description = 'Validation failed: Error parsing  one of the date fields. Date field must be in DD-MON-YY format.'
                   WHERE inv.vendor_id = i.vendor_id AND
                         inv.invoice_num = i.invoice_num AND
                         status = 40 AND
                         inv.conc_request_id = fnd_global.conc_request_id;
            END;
         END LOOP;
         COMMIT;
         FOR i IN c_invoice_line LOOP
            SELECT ap_invoice_lines_interface_s.NEXTVAL
              INTO l_invoice_line_id
              FROM dual;
            UPDATE xxap_upload_invoices_tmp inv
               SET inv.status = 60, invoice_line_id = l_invoice_line_id
             WHERE CURRENT OF c_invoice_line;
         END LOOP;
         COMMIT;
      END validate;
   
      PROCEDURE move_to_interface(p_null IN VARCHAR2) IS
         CURSOR c_invoice IS
            SELECT *
              FROM xxap_upload_invoices_tmp inv
             WHERE inv.status = 60 AND
                   inv.conc_request_id = fnd_global.conc_request_id
               FOR UPDATE
             ORDER BY inv.invoice_id, inv.invoice_line_id;
      
         l_current_invoice_id NUMBER := 0;
      BEGIN
         FOR i IN c_invoice LOOP
            IF l_current_invoice_id <> i.invoice_id THEN
               -- invoice was chaned. Need to insert header record;
               l_current_invoice_id := i.invoice_id;
               INSERT INTO ap_invoices_interface
                  (invoice_id,
                   invoice_num,
                   vendor_id,
                   vendor_site_id,
                   invoice_amount,
                   invoice_currency_code,
                   payment_currency_code,
                   payment_method_code,
                   org_id,
                   SOURCE,
                   invoice_date,
                   gl_date,
                   terms_id,
                   legal_entity_id,
                   group_id)
               VALUES
                  (i.invoice_id,
                   i.invoice_num,
                   i.vendor_id,
                   i.vendor_site_id,
                   i.invoice_amount,
                   i.invoice_currency_code,
                   i.payment_currency_code,
                   i.payment_method_code,
                   i.org_id,
                   'MANUAL INVOICE ENTRY', --Source
                   i.invoice_date,
                   i.gl_date,
                   i.payment_terms_id,
                   i.legal_entity_id,
                   'retalix_' || fnd_global.conc_request_id);
            END IF;
            -- Insert line record
            INSERT INTO ap_invoice_lines_interface
               (invoice_id,
                invoice_line_id,
                line_number,
                line_type_lookup_code,
                amount,
                dist_code_combination_id,
                description,
                tax_code)
            VALUES
               (i.invoice_id,
                i.invoice_line_id,
                i.line_number,
                'ITEM', -- line_type_lookup_code
                i.amount,
                i.dist_code_combination_id,
                i.description,
                i.tax_code);
            UPDATE xxap_upload_invoices_tmp
               SET status = 99
             WHERE CURRENT OF c_invoice;
         END LOOP;
         COMMIT;
      END move_to_interface;
   
      FUNCTION send_error_report RETURN BOOLEAN IS
         CURSOR c_errors IS
            SELECT inv.vendor_num,
                   inv.vendor_name,
                   inv.vendor_site_code,
                   inv.invoice_num,
                   inv.line_number,
                   inv.status_description
              FROM xxap_upload_invoices_tmp inv
             WHERE inv.status = -1 AND
                   inv.conc_request_id = fnd_global.conc_request_id;
      
         l_msg_body    VARCHAR2(32000);
         l_error_found BOOLEAN := FALSE;
      BEGIN
         l_msg_body := 'The following validation errors were found:<br><br>';
         l_msg_body := l_msg_body ||
                       '<table border="1"><tr><td>Vendor Number</td><td>Vendor Name</td><td>Vendor Site Code</td>' ||
                       '<td>Invoice Number</td><td>Line Number</td><td>Error description</td></tr>';
         FOR i IN c_errors LOOP
            l_error_found := TRUE;
            l_msg_body    := l_msg_body || '<tr><td>' || i.vendor_num ||
                             '</td><td>' || i.vendor_name || '</td><td>' ||
                             i.vendor_site_code || '</td><td>' ||
                             i.invoice_num || '</td><td>' || i.line_number ||
                             '</td><td>' || i.status_description ||
                             '</td></tr>';
            UPDATE xxap_upload_invoices_tmp inv
               SET status = -99
             WHERE inv.vendor_num = i.vendor_num AND
                   inv.vendor_site_code = i.vendor_site_code AND
                   inv.invoice_num = i.invoice_num AND
                   status NOT IN (99, -99) AND
                   inv.conc_request_id = fnd_global.conc_request_id;
         END LOOP;
         COMMIT;
         l_msg_body := l_msg_body || '</table>';
         IF l_error_found THEN
            IF fnd_profile.VALUE('XXAP_IMPORT_PARTIAL_INVOICE_FILE') = 'N' THEN
               UPDATE xxap_upload_invoices_tmp inv
                  SET status = -99
                WHERE inv.conc_request_id = fnd_global.conc_request_id;
               COMMIT;
            END IF;
            fnd_file.put_line(fnd_file.output, l_msg_body);
            RETURN TRUE;
         END IF;
         RETURN FALSE;
      END send_error_report;
   
      PROCEDURE call_import_program(p_user_id      IN NUMBER,
                                    p_resp_id      IN NUMBER,
                                    p_resp_appl_id IN NUMBER) IS
         l_request_id NUMBER;
      BEGIN
         --fnd_global.apps_initialize(p_user_id, p_resp_id, p_resp_appl_id);
         l_request_id := fnd_request.submit_request(application => 'SQLAP',
                                                    program     => 'APXIIMPT',
                                                    description => NULL,
                                                    start_time  => NULL,
                                                    sub_request => FALSE,
                                                    argument1   => '', -- Operating Unit
                                                    argument2   => 'MANUAL INVOICE ENTRY', --Source
                                                    argument3   => 'retalix' ||
                                                                   fnd_global.conc_request_id, --Group ID
                                                    argument4   => 'N/A', -- Batch Name
                                                    argument5   => '', -- Hold Name
                                                    argument6   => '', -- Hold Reason
                                                    argument7   => '', -- GL Date
                                                    argument8   => 'Y', -- Purge
                                                    argument9   => 'N', -- Trace Switch
                                                    argument10  => 'N', -- Debug Switch
                                                    argument11  => 'Y', -- Summarize Report
                                                    argument12  => '1000', -- Commit Batch Size
                                                    argument13  => '0', -- User ID
                                                    argument14  => '0' -- Login ID
                                                    );
         COMMIT;
      END call_import_program;
   
      PROCEDURE main(errbuf      OUT VARCHAR2,
                     retcode     OUT VARCHAR2,
                     p_file_name IN VARCHAR2) IS
         l_error_message VARCHAR2(2000);
      BEGIN
         retcode := 0;
         errbuf  := '';
         load_file(p_file_name, l_error_message);
         IF l_error_message IS NOT NULL THEN
            retcode := 2;
            fnd_file.put_line(fnd_file.log, l_error_message);
            RETURN;
         END IF;
         validate(fnd_global.user_id,
                  fnd_global.resp_id,
                  fnd_global.resp_appl_id);
         IF send_error_report THEN
            retcode := 1;
            fnd_file.put_line(fnd_file.log,
                              'Some validation errors found, see output for details');
         END IF;
         move_to_interface(NULL);
         call_import_program(fnd_global.user_id,
                             fnd_global.resp_id,
                             fnd_global.resp_appl_id);
      END;
   */
   PROCEDURE ascii_apinvoiceint(errbuf         OUT VARCHAR2,
                                retcode        OUT VARCHAR2,
                                p_processlines IN CHAR) IS
   
      CURSOR cr_duplicateinvoices IS
         SELECT a.operatingunit, a.invoice_num, a.line_number, a.supplier_name, COUNT(*)
           FROM xxobjt.xxobjt_conv_ap_invoices a
          WHERE nvl(a.int_status, '0') != '9'
          GROUP BY a.operatingunit, a.invoice_num, a.line_number, a.supplier_name
         HAVING COUNT(*) > 1;
   
      CURSOR cr_loadedinvoices IS
         SELECT *
           FROM xxobjt.xxobjt_conv_ap_invoices a
          WHERE nvl(a.int_status, '0') != '9'
          ORDER BY a.operatingunit, a.invoice_num, a.line_number
            FOR UPDATE OF a.int_status, a.int_message;
   
      CURSOR cr_insertinvoices IS
         SELECT *
           FROM xxobjt.xxobjt_conv_ap_invoices a
          WHERE nvl(a.int_status, '0') = '0'
          ORDER BY a.operatingunit, a.invoice_num, a.line_number
            FOR UPDATE OF a.int_status, a.int_message;
   
      v_user_id         fnd_user.user_id%TYPE;
      v_lineintstatus   xxobjt.xxobjt_conv_ap_invoices.int_status%TYPE;
      v_lineintmsg      xxobjt.xxobjt_conv_ap_invoices.int_message%TYPE;
      v_counter         NUMBER(8) := 0;
      v_currinvoice     ap_invoices_interface.invoice_num%TYPE;
      v_supplerid       ap_invoices_interface.vendor_id%TYPE;
      v_suppliersiteid  ap_invoices_interface.vendor_site_id%TYPE;
      v_orgid           ap_invoices_interface.org_id%TYPE;
      v_legalentid      ap_invoices_interface.legal_entity_id%TYPE;
      v_glaccid         ap_invoice_lines_interface.dist_code_combination_id%TYPE;
      v_invoicetype     ap_invoices_interface.invoice_type_lookup_code%TYPE;
      l_invoice_id      ap_invoices_interface.invoice_id%TYPE;
      l_invoice_line_id ap_invoice_lines_interface.invoice_line_id%TYPE;
      v_dummyDate       Date;
   
      FUNCTION getorgid(pf_opunit IN VARCHAR2) RETURN NUMBER IS
         v_retid NUMBER;
      BEGIN
         SELECT hp.organization_id
           INTO v_retid
           FROM hr_operating_units hp
          WHERE hp.NAME = pf_opunit;
         RETURN(v_retid);
      EXCEPTION
         WHEN no_data_found THEN
            RETURN(NULL);
      END getorgid;
   
      FUNCTION getsupplerid(pf_suppliername IN VARCHAR2) RETURN NUMBER IS
         v_retid NUMBER;
      BEGIN
         SELECT s.vendor_id
           INTO v_retid
           FROM ap_suppliers s
          WHERE s.vendor_name_alt = pf_suppliername OR
                s.vendor_name = pf_suppliername;
         RETURN(v_retid);
      EXCEPTION
         WHEN no_data_found THEN
            RETURN(NULL);
      END getsupplerid;
   
      FUNCTION getsuppliersiteid(pf_supplierid   IN NUMBER,
                                 pf_OrgId        IN NUMBER,
                                 pf_suppliersite IN VARCHAR2) RETURN NUMBER IS
         v_retid NUMBER;
      BEGIN
         SELECT ass.vendor_site_id
           INTO v_retid
           FROM ap_supplier_sites_all ass
          WHERE ass.vendor_id = pf_supplierid AND
                ass.org_id = pf_OrgId AND
                (ass.vendor_site_code = pf_suppliersite OR
                ass.vendor_site_code_alt = pf_suppliersite);
         RETURN(v_retid);
      EXCEPTION
         WHEN no_data_found THEN
            RETURN(NULL);
      END getsuppliersiteid;
   
      FUNCTION isinvoiceexists(pf_orgid      IN NUMBER,
                               pf_invoicenum IN VARCHAR2,
                               pf_vendorID   IN NUMBER) RETURN BOOLEAN IS
         v_dummy CHAR(1);
      BEGIN
         SELECT 'Y'
           INTO v_dummy
           FROM ap_invoices_all ai
          WHERE ai.org_id = pf_orgid AND
                ai.vendor_id = pf_vendorID AND
                ai.invoice_num = pf_invoicenum;
         RETURN(TRUE);
      EXCEPTION
         WHEN no_data_found THEN
            RETURN(FALSE);
      END isinvoiceexists;
   
      FUNCTION ischeckdateok(pf_indate IN VARCHAR2) RETURN BOOLEAN IS
         v_dummy DATE;
      BEGIN
         SELECT to_date(pf_indate, 'YYYY-MM-DD') INTO v_dummy FROM dual;
         RETURN(TRUE);
      EXCEPTION
         WHEN OTHERS THEN
            RETURN(FALSE);
      END ischeckdateok;
   
      FUNCTION iscurrencyok(pf_currcode IN VARCHAR2) RETURN BOOLEAN IS
         v_dummy CHAR(1);
      BEGIN
         SELECT 'Y'
           INTO v_dummy
           FROM gl_currencies gc
          WHERE gc.currency_code = pf_currcode;
         RETURN(TRUE);
      EXCEPTION
         WHEN no_data_found THEN
            RETURN(FALSE);
      END iscurrencyok;
   
      FUNCTION getlegalentityid(pf_orgid IN NUMBER) RETURN NUMBER IS
         v_retid NUMBER;
      BEGIN
         SELECT DISTINCT org.legal_entity
           INTO v_retid
           FROM org_organization_definitions org
          WHERE org.operating_unit = pf_orgid;
         RETURN(v_retid);
      EXCEPTION
         WHEN no_data_found THEN
            RETURN(NULL);
      END getlegalentityid;
   
      FUNCTION getcodecombinationid(pf_accountconc IN VARCHAR2) RETURN NUMBER IS
         v_retid NUMBER;
      BEGIN
         SELECT code_combination_id
           INTO v_retid
           FROM gl_code_combinations_kfv gcc
          WHERE gcc.concatenated_segments = pf_accountconc;
         RETURN(v_retid);
      EXCEPTION
         WHEN no_data_found THEN
            RETURN(NULL);
      END getcodecombinationid;
   
      -- Main Program
   BEGIN
      v_user_id := fnd_profile.VALUE('USER_ID');
      -- Start Validating The DC Input
      FOR apinv IN cr_loadedinvoices LOOP
          --fnd_file.put_line(fnd_file.log, 'In Invoice '||apinv.invoice_num);
         v_counter       := v_counter + 1;
         v_lineintstatus := '0';
         v_lineintmsg    := NULL;
         IF getorgid(apinv.operatingunit) IS NULL THEN
            v_lineintstatus := '2';
            v_lineintmsg    := ltrim(rtrim(v_lineintmsg)) ||
                               'No Operating Unit,';
         END IF;
         IF isinvoiceexists(getorgid(apinv.operatingunit),
                            apinv.invoice_num,
                            getsupplerid(apinv.supplier_name)) THEN
            v_lineintstatus := '2';
            v_lineintmsg    := ltrim(rtrim(v_lineintmsg)) ||
                               'Invoice Exists,';
         END IF;
         IF getsupplerid(apinv.supplier_name) IS NULL THEN
            v_lineintstatus := '2';
            v_lineintmsg    := ltrim(rtrim(v_lineintmsg)) || 'No Supplier,';
         END IF;
         IF getsuppliersiteid(getsupplerid(apinv.supplier_name),
                              getorgid(apinv.operatingunit),
                              apinv.supplier_site_code) IS NULL THEN
            v_lineintstatus := '2';
            v_lineintmsg    := ltrim(rtrim(v_lineintmsg)) ||
                               'No Supplier Site,';
         END IF;
         IF NOT (iscurrencyok(apinv.invoice_currency)) THEN
            v_lineintstatus := '2';
            v_lineintmsg    := ltrim(rtrim(v_lineintmsg)) || 'No Currency,';
         END IF;
         IF getcodecombinationid(apinv.dist_account) IS NULL THEN
            v_lineintstatus := '2';
            v_lineintmsg    := ltrim(rtrim(v_lineintmsg)) ||
                               'No Dist Account,';
         END IF;
         -- Check The Dates
            Begin
              Select to_date(apinv.invoice_date, 'YYYY-MM-DD') Into v_dummyDate
                From dual;
            Exception
              When Others then
                   v_lineintstatus := '2';
                   v_lineintmsg  := ltrim(rtrim(v_lineintmsg))||'No Invoice Date,';
            End;
            Begin
              Select to_date(apinv.gl_date, 'YYYY-MM-DD') Into v_dummyDate
                From dual;
            Exception
              When Others then
                   v_lineintstatus := '2';
                   v_lineintmsg  := ltrim(rtrim(v_lineintmsg))||'No GL Date,';
            End;
            Begin
              Select to_date(apinv.conversion_date, 'YYYY-MM-DD') Into v_dummyDate
                From dual;
            Exception
              When Others then
                   v_lineintstatus := '2';
                   v_lineintmsg  := ltrim(rtrim(v_lineintmsg))||'No Conversion Date,';
            End;
      
         UPDATE xxobjt.xxobjt_conv_ap_invoices
            SET int_status = v_lineintstatus, int_message = v_lineintmsg
          WHERE CURRENT OF cr_loadedinvoices;
      
         IF v_lineintstatus = '2' THEN
            fnd_file.put_line(fnd_file.log,
                              'Line ' || v_counter || ' : ' || v_lineintmsg);
         END IF;
      END LOOP;
      -- Update Duplicate Invoices' Names With Error
      fnd_file.put_line(fnd_file.log,
                        'The Following Invoice Numbers Are Duplicate:');
      FOR apdup IN cr_duplicateinvoices LOOP
         UPDATE xxobjt.xxobjt_conv_ap_invoices
            SET int_status = '2', int_message = 'Duplicate Invoice Number,'
          WHERE operatingunit = apdup.operatingunit AND
                invoice_num = apdup.invoice_num AND
                line_number = apdup.line_number;
         fnd_file.put_line(fnd_file.log,
                           apdup.operatingunit || '  ' || apdup.invoice_num);
      END LOOP;
   
      -- Start Inserting Values To Interface Tables  
      IF p_processlines = 'Y' THEN
         v_currinvoice := '@@@';
         FOR apinv IN cr_insertinvoices LOOP
            IF apinv.invoice_num != v_currinvoice THEN
               v_currinvoice := apinv.invoice_num;
               SELECT ap_invoices_interface_s.NEXTVAL
                 INTO l_invoice_id
                 FROM dual;
               v_supplerid      := getsupplerid(apinv.supplier_name);
               v_suppliersiteid := getsuppliersiteid(v_supplerid,
                                                     getorgid(apinv.operatingunit),
                                                     apinv.supplier_site_code);
               v_orgid          := getorgid(apinv.operatingunit);
               v_legalentid     := getlegalentityid(v_orgid);
               v_glaccid        := getcodecombinationid(apinv.dist_account);
               IF apinv.invoice_amount < 0 THEN
                  v_invoicetype := 'CREDIT';
               ELSE
                  v_invoicetype := 'STANDARD';
               END IF;
               INSERT INTO ap_invoices_interface
                  (invoice_id,
                   invoice_num,
                   vendor_id,
                   vendor_site_id,
                   invoice_amount,
                   invoice_currency_code,
                   payment_currency_code,
                   payment_method_code,
                   org_id,
                   SOURCE,
                   invoice_date,
                   gl_date,
                   terms_name,
                   legal_entity_id,
                   creation_date,
                   created_by,
                   last_update_date,
                   last_updated_by,
                   status,
                   invoice_type_lookup_code,
                   description,
                   exchange_rate_type,
                   exchange_date,
                   group_id)
               VALUES
                  (l_invoice_id,
                   apinv.invoice_num,
                   v_supplerid,
                   v_suppliersiteid,
                   apinv.invoice_amount,
                   apinv.invoice_currency,
                   apinv.invoice_currency,
                   'EFT',
                   v_orgid,
                   'MANUAL INVOICE ENTRY', --Source
                   to_date(apinv.invoice_date, 'YYYY-MM-DD'),
                   to_date(apinv.gl_date, 'YYYY-MM-DD'),
                   'Immediate',
                   v_legalentid,
                   SYSDATE,
                   v_user_id,
                   SYSDATE,
                   v_user_id,
                   NULL, -- Was 'PENDING', Changed To Null According To Note 252224.1
                   v_invoicetype,
                   apinv.description,
                   apinv.conversion_type,
                   to_date(apinv.conversion_date, 'YYYY-MM-DD'),
                   111);
            END IF;
            SELECT ap_invoice_lines_interface_s.NEXTVAL
              INTO l_invoice_line_id
              FROM dual;
            INSERT INTO ap_invoice_lines_interface
               (invoice_id,
                invoice_line_id,
                line_number,
                line_type_lookup_code,
                amount,
                dist_code_combination_id,
                description,
                creation_date,
                created_by,
                last_update_date,
                last_updated_by,
                tax_code)
            VALUES
               (l_invoice_id,
                l_invoice_line_id,
                apinv.line_number,
                'ITEM', -- line_type_lookup_code
                apinv.amount,
                v_glaccid,
                apinv.description,
                SYSDATE,
                v_user_id,
                SYSDATE,
                v_user_id,
                NULL);
         END LOOP;
      END IF;
   END ascii_apinvoiceint;

END xxconv_ap_upload_invoice_pkg;
/

