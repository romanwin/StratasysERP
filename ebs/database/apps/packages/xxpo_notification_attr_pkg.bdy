CREATE OR REPLACE PACKAGE BODY xxpo_notification_attr_pkg IS

   FUNCTION get_requisition_justifications(p_po_line_id NUMBER)
      RETURN VARCHAR2 IS
   
      CURSOR csr_justifications IS
         SELECT DISTINCT rl.justification
           FROM po_requisition_lines_all rl,
                po_req_distributions_all rd,
                po_distributions_all     pd
          WHERE rd.distribution_id = pd.req_distribution_id AND
                rl.requisition_line_id = rd.requisition_line_id AND
                nvl(rl.cancel_flag, 'N') = 'N' AND
                rl.justification IS NOT NULL AND
                pd.po_line_id = p_po_line_id;
   
      cur_justification      csr_justifications%ROWTYPE;
      l_concat_justification VARCHAR2(500) := NULL;
   
   BEGIN
   
      FOR cur_justification IN csr_justifications LOOP
         l_concat_justification := l_concat_justification ||
                                   cur_justification.justification || '; ';
      
         IF length(l_concat_justification) > 450 THEN
            EXIT;
         END IF;
      END LOOP;
   
      l_concat_justification := substr(l_concat_justification,
                                       1,
                                       length(l_concat_justification) - 2);
   
      RETURN l_concat_justification;
   
   EXCEPTION
      WHEN OTHERS THEN
         RETURN NULL;
   END get_requisition_justifications;

   FUNCTION get_requisition_requestors(p_po_line_id NUMBER) RETURN VARCHAR2 IS
   
      CURSOR csr_requestors IS
         SELECT DISTINCT p.full_name
           FROM po_requisition_lines_all rl,
                per_all_people_f         p,
                po_req_distributions_all rd,
                po_distributions_all     pd
          WHERE rd.distribution_id = pd.req_distribution_id AND
                rl.requisition_line_id = rd.requisition_line_id AND
                p.person_id = rl.to_person_id AND
                p.current_employee_flag = 'Y' AND
                SYSDATE BETWEEN p.effective_start_date AND
                p.effective_end_date AND
                nvl(rl.cancel_flag, 'N') = 'N' AND
                pd.po_line_id = p_po_line_id;
   
      cur_requestor       csr_requestors%ROWTYPE;
      l_concat_requestors VARCHAR2(250) := NULL;
   
   BEGIN
   
      FOR cur_requestor IN csr_requestors LOOP
         l_concat_requestors := l_concat_requestors ||
                                cur_requestor.full_name || '; ';
      
         IF length(l_concat_requestors) > 200 THEN
            EXIT;
         END IF;
      END LOOP;
   
      l_concat_requestors := substr(l_concat_requestors,
                                    1,
                                    length(l_concat_requestors) - 2);
   
      RETURN l_concat_requestors;
   
   EXCEPTION
      WHEN OTHERS THEN
         RETURN NULL;
   END get_requisition_requestors;

   FUNCTION get_requisition_justifications(p_req_line_id   NUMBER,
                                           p_currency_code VARCHAR2)
      RETURN VARCHAR2 IS
   
      CURSOR csr_justifications IS
         SELECT DISTINCT rl.justification
           FROM po_requisition_lines_all     rl,
                gl_sets_of_books             sob,
                financials_system_params_all fsp
          WHERE rl.requisition_line_id = p_req_line_id AND
                nvl(rl.cancel_flag, 'N') = 'N' AND
                fsp.org_id = rl.org_id AND
                sob.set_of_books_id = fsp.set_of_books_id AND
                nvl(rl.currency_code, sob.currency_code) = p_currency_code;
   
      cur_justification      csr_justifications%ROWTYPE;
      l_concat_justification VARCHAR2(500) := NULL;
   
   BEGIN
   
      FOR cur_justification IN csr_justifications LOOP
         l_concat_justification := l_concat_justification ||
                                   cur_justification.justification || '; ';
      
         IF length(l_concat_justification) > 450 THEN
            EXIT;
         END IF;
      END LOOP;
   
      l_concat_justification := substr(l_concat_justification,
                                       1,
                                       length(l_concat_justification) - 2);
   
      RETURN l_concat_justification;
   
   EXCEPTION
      WHEN OTHERS THEN
         RETURN NULL;
   END get_requisition_justifications;

   FUNCTION get_requisition_requestors(p_req_line_id   NUMBER,
                                       p_currency_code VARCHAR2)
      RETURN VARCHAR2 IS
   
      CURSOR csr_requestors IS
         SELECT DISTINCT p.full_name
           FROM po_requisition_lines_all     rl,
                per_all_people_f             p,
                gl_sets_of_books             sob,
                financials_system_params_all fsp
          WHERE rl.requisition_line_id = p_req_line_id AND
                p.person_id = rl.to_person_id AND
                p.current_employee_flag = 'Y' AND
                SYSDATE BETWEEN p.effective_start_date AND
                p.effective_end_date AND
                nvl(rl.cancel_flag, 'N') = 'N' AND
                fsp.org_id = rl.org_id AND
                sob.set_of_books_id = fsp.set_of_books_id AND
                nvl(rl.currency_code, sob.currency_code) = p_currency_code;
   
      cur_requestor       csr_requestors%ROWTYPE;
      l_concat_requestors VARCHAR2(250) := NULL;
   
   BEGIN
   
      FOR cur_requestor IN csr_requestors LOOP
         l_concat_requestors := l_concat_requestors ||
                                cur_requestor.full_name || '; ';
      
         IF length(l_concat_requestors) > 200 THEN
            EXIT;
         END IF;
      END LOOP;
   
      l_concat_requestors := substr(l_concat_requestors,
                                    1,
                                    length(l_concat_requestors) - 2);
   
      RETURN l_concat_requestors;
   
   EXCEPTION
      WHEN OTHERS THEN
         RETURN NULL;
   END get_requisition_requestors;

   PROCEDURE get_po_distributions_details(document_id   IN VARCHAR2,
                                          display_type  IN VARCHAR2,
                                          document      IN OUT NOCOPY CLOB, -- <BUG 7006113>
                                          document_type IN OUT NOCOPY VARCHAR2) IS
   
      CURSOR csr_po_accounts(p_header_id NUMBER, p_func_currency VARCHAR2) IS
         SELECT concatenated_segments,
                account_description,
                currency_code,
                gl_encumbered_period_name,
                amount,
                functional_amount,
                (xxpo_wf_notification_pkg.get_req_distributions(set_of_books_id,
                                                                budget_account_id,
                                                                gl_encumbered_period_name)) get_details,
                xxpo_wf_notification_pkg.get_budget_amount budget_amount,
                xxpo_wf_notification_pkg.get_actual_amount actual_amount,
                xxpo_wf_notification_pkg.get_encumbrance_amount encumbrance_amount,
                xxpo_wf_notification_pkg.get_funds_avail_amount funds_avail_amount,
                xxpo_wf_notification_pkg.get_obligation_amount obligation_amount,
                xxpo_wf_notification_pkg.get_commitment_amount commitment_amount,
                xxpo_wf_notification_pkg.get_other_amount other_enc_amount
           FROM (SELECT pd.set_of_books_id,
                        pd.budget_account_id,
                        gcc.concatenated_segments,
                        MAX(xla_oa_functions_pkg.get_ccid_description(gcc.chart_of_accounts_id,
                                                                      gcc.code_combination_id)) account_description,
                        nvl(ph.currency_code, p_func_currency) currency_code,
                        pd.gl_encumbered_period_name,
                        SUM(pd.quantity_ordered * pll.price_override) amount,
                        SUM(pd.quantity_ordered * pll.price_override *
                            nvl(pd.rate, ph.rate)) functional_amount
                   FROM po_headers_all           ph,
                        po_lines_all             pl,
                        po_line_locations_all    pll,
                        po_distributions_all     pd,
                        gl_code_combinations_kfv gcc
                  WHERE ph.po_header_id = pl.po_header_id AND
                        pl.po_line_id = pll.po_line_id AND
                        pll.line_location_id = pd.line_location_id AND
                        pd.budget_account_id = gcc.code_combination_id AND
                        nvl(pll.cancel_flag, 'N') != 'Y' AND
                        ph.po_header_id = p_header_id
                  GROUP BY pd.set_of_books_id,
                           pd.budget_account_id,
                           gcc.concatenated_segments,
                           nvl(ph.currency_code, p_func_currency),
                           pd.gl_encumbered_period_name);
   
      nl          VARCHAR2(1) := fnd_global.newline;
      l_document  VARCHAR2(32000) := '';
      l_item_type wf_items.item_type%TYPE;
      l_item_key  wf_items.item_key%TYPE;
   
      l_document_id   po_lines.po_header_id%TYPE;
      l_org_id        po_lines.org_id%TYPE;
      l_document_type VARCHAR2(25);
      l_currency_code fnd_currencies.currency_code%TYPE;
   
      i                        NUMBER := 0;
      max_lines_dsp            NUMBER; -- <BUG 7006113>
      l_line_count             NUMBER := 0; -- <BUG 3616816> # lines/shipments on document
      l_num_records_to_display NUMBER; -- <BUG 3616816> actual # of records to be displayed in table
      l_display_func_amount    NUMBER;
      l_func_currency          VARCHAR2(3);
      --
      TYPE account_tbl_type IS TABLE OF gl_code_combinations_kfv.concatenated_segments%TYPE;
      TYPE account_desc_tbl_type IS TABLE OF VARCHAR2(500);
      TYPE currency_tbl_type IS TABLE OF gl_currencies.currency_code%TYPE;
      TYPE period_tbl_type IS TABLE OF gl_periods.period_name%TYPE;
      TYPE amount_tbl_type IS TABLE OF po_lines_all.amount%TYPE;
      TYPE func_amount_tbl_type IS TABLE OF po_lines_all.amount%TYPE;
      TYPE details_tbl_type IS TABLE OF NUMBER;
      TYPE budget_tbl_type IS TABLE OF po_lines_all.amount%TYPE;
      TYPE encumbrance_tbl_type IS TABLE OF po_lines_all.amount%TYPE;
      TYPE actual_tbl_type IS TABLE OF po_lines_all.amount%TYPE;
      TYPE funds_tbl_type IS TABLE OF po_lines_all.amount%TYPE;
      TYPE obligation_tbl_type IS TABLE OF po_lines_all.amount%TYPE;
      TYPE commitment_tbl_type IS TABLE OF po_lines_all.amount%TYPE;
      TYPE other_tbl_type IS TABLE OF po_lines_all.amount%TYPE;
   
      l_account_tbl      account_tbl_type;
      l_account_desc_tbl account_desc_tbl_type;
      l_currency_tbl     currency_tbl_type;
      l_period_tbl       period_tbl_type;
      l_amount_tbl       amount_tbl_type;
      l_func_amount_tbl  func_amount_tbl_type;
      l_details_tbl      details_tbl_type;
      l_budget_tbl       budget_tbl_type;
      l_encumbrance_tbl  encumbrance_tbl_type;
      l_actual_tbl       actual_tbl_type;
      l_funds_tbl        funds_tbl_type;
      l_obligation_tbl   obligation_tbl_type;
      l_commitment_tbl   commitment_tbl_type;
      l_other_tbl        other_tbl_type;
   
   BEGIN
   
      l_item_type := substr(document_id, 1, instr(document_id, ':') - 1);
      l_item_key  := substr(document_id, instr(document_id, ':') + 1);
   
      po_reqapproval_init1.set_doc_mgr_context(l_item_type, l_item_key);
      l_document_id := wf_engine.getitemattrnumber(itemtype => l_item_type,
                                                   itemkey  => l_item_key,
                                                   aname    => 'DOCUMENT_ID');
   
      l_org_id := wf_engine.getitemattrnumber(itemtype => l_item_type,
                                              itemkey  => l_item_key,
                                              aname    => 'ORG_ID');
   
      l_document_type := wf_engine.getitemattrtext(itemtype => l_item_type,
                                                   itemkey  => l_item_key,
                                                   aname    => 'DOCUMENT_TYPE');
   
      po_moac_utils_pvt.set_org_context(l_org_id); -- <R12 MOAC>
   
      l_currency_code := wf_engine.getitemattrtext(itemtype => l_item_type,
                                                   itemkey  => l_item_key,
                                                   aname    => 'FUNCTIONAL_CURRENCY');
   
      SELECT led.currency_code,
             decode(led.currency_code, l_currency_code, 0, 1)
        INTO l_func_currency, l_display_func_amount
        FROM hr_operating_units hou, gl_ledgers led
       WHERE hou.set_of_books_id = led.ledger_id AND
             hou.organization_id = l_org_id;
   
      OPEN csr_po_accounts(l_document_id, l_currency_code);
   
      FETCH csr_po_accounts BULK COLLECT
         INTO l_account_tbl, l_account_desc_tbl, l_currency_tbl, l_period_tbl, l_amount_tbl, l_func_amount_tbl, l_details_tbl, l_budget_tbl, l_actual_tbl, l_encumbrance_tbl, l_funds_tbl, l_obligation_tbl, l_commitment_tbl, l_other_tbl;
   
      l_line_count := csr_po_accounts%ROWCOUNT; -- Get # of records fetched.
   
      CLOSE csr_po_accounts;
   
      max_lines_dsp := to_number(fnd_profile.VALUE('PO_NOTIF_LINES_LIMIT'));
   
      IF max_lines_dsp IS NULL THEN
      
         max_lines_dsp := l_line_count;
      
      END IF;
   
      IF (l_line_count >= max_lines_dsp) THEN
         l_num_records_to_display := max_lines_dsp;
      ELSE
         l_num_records_to_display := l_line_count;
      END IF;
   
      IF (display_type = 'text/html') THEN
      
         l_document := nl || nl || '<!-- PO_DISTRIBUTIONS_DETAILS -->' || nl || nl ||
                       '<P><B><FONT FACE= "Arial", "Helvetica" SIZE="2">';
         l_document := l_document ||
                       fnd_message.get_string('XXOBJT',
                                              'XXPO_WF_NOTIF_PO_DIST_DETAILS');
         l_document := l_document || '</font></B>' || nl || '<P>'; -- <BUG 3616816>
      
         l_document := l_document || nl ||
                       '<TABLE border=1 cellpadding=2 cellspacing=1 summary="' ||
                       fnd_message.get_string('ICX',
                                              'ICX_POR_TBL_PO_TO_APPROVE_SUM') ||
                       '"> ' || nl;
      
         l_document := l_document || '<TR>' || nl;
      
         l_document := l_document ||
                       '<TH  id="account_1"><FONT FACE= "Arial", "Helvetica" SIZE="2">' ||
                       fnd_message.get_string('XXOBJT',
                                              'XXPO_WF_NOTIF_ACCOUNT') ||
                       '</font></TH>' || nl;
      
         l_document := l_document ||
                       '<TH  id="period_1"><FONT FACE= "Arial", "Helvetica" SIZE="2">' ||
                       fnd_message.get_string('XXOBJT',
                                              'XXPO_WF_NOTIF_PERIOD') ||
                       '</font></TH>' || nl;
      
         fnd_message.set_name('XXOBJT', 'XXPO_WF_NOTIF_AMOUNT');
         fnd_message.set_token('CURR', l_currency_code);
         l_document := l_document ||
                       '<TH  id="amount_1"><FONT FACE= "Arial", "Helvetica" SIZE="2">' ||
                       fnd_message.get || '</font></TH>' || nl;
      
         IF l_display_func_amount = 1 THEN
         
            fnd_message.set_name('XXOBJT', 'XXPO_WF_NOTIF_FUNC_AMOUNT');
            fnd_message.set_token('CURR', l_func_currency);
            l_document := l_document ||
                          '<TH  id="funcAmount_1"><FONT FACE= "Arial", "Helvetica" SIZE="2">' ||
                          fnd_message.get || '</font></TH>' || nl;
         
         END IF;
      
         l_document := l_document ||
                       '<TH  id="budget_1"><FONT FACE= "Arial", "Helvetica" SIZE="2">' ||
                       fnd_message.get_string('XXOBJT',
                                              'XXPO_WF_NOTIF_BUDGET') ||
                       '</font></TH>' || nl;
      
         l_document := l_document ||
                       '<TH  id="encumbrance_1"><FONT FACE= "Arial", "Helvetica" SIZE="2">' ||
                       fnd_message.get_string('XXOBJT',
                                              'XXPO_WF_NOTIF_ENCUMBRANCE') ||
                       '</font></TH>' || nl;
      
         l_document := l_document ||
                       '<TH  id="actual_1"><FONT FACE= "Arial", "Helvetica" SIZE="2">' ||
                       fnd_message.get_string('XXOBJT',
                                              'XXPO_WF_NOTIF_ACTUAL') ||
                       '</font></TH>' || nl;
      
         l_document := l_document ||
                       '<TH  id="funds_1"><FONT FACE= "Arial", "Helvetica" SIZE="2">' ||
                       fnd_message.get_string('XXOBJT',
                                              'XXPO_WF_NOTIF_FUNDS') ||
                       '</font></TH>' || nl;
      
         l_document := l_document || '</TR>' || nl;
      
         -- curr_len  := lengthb(l_document);
         -- prior_len := curr_len;
      
         FOR i IN 1 .. l_num_records_to_display LOOP
            -- <BUG 3616816>
         
            /* Exit the cursor if the current document length and 2 times the
            ** length added in prior line exceeds 32000 char */
            -- < BUG 7006113 START Commented the loop to avoid the check so that maximum
            --  lines can be displayed >
            -- if (curr_len + (2 * (curr_len - prior_len))) >= 32000 then
            --  exit;
            --  end if;
            --  prior_len := curr_len;
            -- < BUG 7006113 END >
         
            l_document := l_document || '<TR>' || nl;
         
            l_document := l_document ||
                          '<TD nowrap align=left headers="account_1"><FONT FACE= "Arial", "Helvetica" SIZE="2">' ||
                          nvl(to_char(l_account_tbl(i)), '&nbsp') || '<br>' ||
                          nvl(to_char(l_account_desc_tbl(i)), '&nbsp') ||
                          '</font></TD>' || nl;
            l_document := l_document ||
                          '<TD nowrap headers="period_1"><FONT FACE= "Arial", "Helvetica" SIZE="2">' ||
                          nvl(l_period_tbl(i), '&nbsp') || '</font></TD>' || nl;
            l_document := l_document ||
                          '<TD nowrap align=right headers="amount_1"><FONT FACE= "Arial", "Helvetica" SIZE="2">' ||
                          nvl(to_char(l_amount_tbl(i),
                                      xxgl_utils_pkg.safe_get_format_mask(l_currency_code,
                                                                          30,
                                                                          'Y',
                                                                          4)),
                              '&nbsp') || '</font></TD>' || nl;
         
            IF l_display_func_amount = 1 THEN
               l_document := l_document ||
                             '<TD nowrap align=right headers="funcAmount_1"><FONT FACE= "Arial", "Helvetica" SIZE="2">' ||
                             nvl(to_char(l_func_amount_tbl(i),
                                         xxgl_utils_pkg.safe_get_format_mask(l_currency_code,
                                                                             30,
                                                                             'Y',
                                                                             4)),
                                 '&nbsp') || '</font></TD>' || nl;
            END IF;
         
            l_document := l_document ||
                          '<TD nowrap align=right headers="budget"><FONT FACE= "Arial", "Helvetica" SIZE="2">' ||
                          nvl(to_char(l_budget_tbl(i),
                                      xxgl_utils_pkg.safe_get_format_mask(l_currency_code,
                                                                          30,
                                                                          'Y',
                                                                          4)),
                              '&nbsp') || '</font></TD>' || nl;
         
            l_document := l_document ||
                          '<TD nowrap align=right headers="encumbrance_1"><FONT FACE= "Arial", "Helvetica" SIZE="2">' ||
                          nvl(to_char(l_encumbrance_tbl(i),
                                      xxgl_utils_pkg.safe_get_format_mask(l_currency_code,
                                                                          30,
                                                                          'Y',
                                                                          4)),
                              '&nbsp') || '</font></TD>' || nl;
         
            l_document := l_document ||
                          '<TD nowrap align=right headers="actual_1"><FONT FACE= "Arial", "Helvetica" SIZE="2">' ||
                          nvl(to_char(l_actual_tbl(i),
                                      xxgl_utils_pkg.safe_get_format_mask(l_currency_code,
                                                                          30,
                                                                          'Y',
                                                                          4)),
                              '&nbsp') || '</font></TD>' || nl;
         
            l_document := l_document ||
                          '<TD nowrap align=right headers="funds_1"><FONT FACE= "Arial", "Helvetica" SIZE="2">' ||
                          nvl(to_char(l_funds_tbl(i),
                                      xxgl_utils_pkg.safe_get_format_mask(l_currency_code,
                                                                          30,
                                                                          'Y',
                                                                          4)),
                              '&nbsp') || '</font></TD>' || nl;
         
            l_document := l_document || '</TR>' || nl;
         
            -- <BUG 7006113 START>
            --curr_len  := lengthb(l_document);
            wf_notification.writetoclob(document, l_document);
         
            l_document := NULL;
         
            EXIT WHEN i = l_num_records_to_display;
            -- <BUG 7006113 END>
         END LOOP;
      
         l_document := l_document || '</TABLE></P>' || nl;
      
         wf_notification.writetoclob(document, l_document); -- <BUG 7006113>
      
      ELSIF (display_type = 'text/plain') THEN
      
         l_document := l_document ||
                       fnd_message.get_string('PO',
                                              'PO_WF_NOTIF_PO_LINE_DETAILS') || nl || nl;
      
         FOR i IN 1 .. l_num_records_to_display LOOP
            -- <BUG 3616816>
         
            /* Exit the cursor if the current document length and 2 times the
            ** length added in prior line exceeds 32000 char */
            -- < BUG 7006113 START Commented the loop to avoid the check so
            --   that maximum lines can be displayed >
            --   if (curr_len + (2 * (curr_len - prior_len))) >= 32000 then
            --     exit;
            --   end if;
            --   prior_len := curr_len;
            -- < BUG 7006113 END >
         
            l_document := l_document ||
                          fnd_message.get_string('XXOBJT',
                                                 'XXPO_WF_NOTIF_ACCOUNT') || ':' ||
                          l_account_tbl(i) || ', ' || l_account_desc_tbl(i) || nl;
            l_document := l_document ||
                          fnd_message.get_string('XXOBJT',
                                                 'XXPO_WF_NOTIF_PERIOD') || ': ' ||
                          l_period_tbl(i) || nl;
            fnd_message.set_name('XXOBJT', 'XXPO_WF_NOTIF_AMOUNT');
            fnd_message.set_token('CURR', l_currency_code);
            l_document := l_document || fnd_message.get || ': ' ||
                          to_char(l_amount_tbl(i),
                                  xxgl_utils_pkg.safe_get_format_mask(l_currency_code,
                                                                      30,
                                                                      'Y')) || nl;
            IF l_display_func_amount = 1 THEN
               fnd_message.set_name('XXOBJT',
                                    'PO_WF_XXPO_WF_NOTIF_FUNC_AMOUNT');
               fnd_message.set_token('CURR', l_func_currency);
               l_document := l_document || fnd_message.get || ': ' ||
                             to_char(l_func_amount_tbl(i),
                                     xxgl_utils_pkg.safe_get_format_mask(l_currency_code,
                                                                         30,
                                                                         'Y')) || nl;
            END IF;
            l_document := l_document ||
                          fnd_message.get_string('XXOBJT',
                                                 'XXPO_WF_NOTIF_BUDGET') || ': ' ||
                          to_char(l_budget_tbl(i),
                                  xxgl_utils_pkg.safe_get_format_mask(l_currency_code,
                                                                      30,
                                                                      'Y')) || nl;
            l_document := l_document ||
                          fnd_message.get_string('XXOBJT',
                                                 'XXPO_WF_NOTIF_ENCUMBRANCE') || ': ' ||
                          to_char(l_encumbrance_tbl(i),
                                  xxgl_utils_pkg.safe_get_format_mask(l_currency_code,
                                                                      30,
                                                                      'Y')) || nl;
            l_document := l_document ||
                          fnd_message.get_string('XXOBJT',
                                                 'XXPO_WF_NOTIF_ACTUAL') || ': ' ||
                          to_char(l_actual_tbl(i),
                                  xxgl_utils_pkg.safe_get_format_mask(l_currency_code,
                                                                      30,
                                                                      'Y')) || nl;
            l_document := l_document ||
                          fnd_message.get_string('XXOBJT',
                                                 'XXPO_WF_NOTIF_FUNDS') || ': ' ||
                          to_char(l_funds_tbl(i),
                                  fnd_currency.get_format_mask(l_currency_code,
                                                               30)) || nl;
         
            wf_notification.writetoclob(document, l_document); -- <BUG 7006113>
            l_document := NULL;
         
            EXIT WHEN i = l_num_records_to_display;
            -- <BUG 7006113 END>
         END LOOP;
      
         l_document := l_document || '</TABLE></P>' || nl;
      
         wf_notification.writetoclob(document, l_document); -- <BUG 7006113>
      
      END IF;
   
      wf_notification.writetoclob(document, l_document); -- <BUG 7006113>
   
   END get_po_distributions_details;

   PROCEDURE get_po_lines_details(document_id   IN VARCHAR2,
                                  display_type  IN VARCHAR2,
                                  document      IN OUT NOCOPY CLOB, -- <BUG 7006113>
                                  document_type IN OUT NOCOPY VARCHAR2) IS
   
      l_item_type wf_items.item_type%TYPE;
      l_item_key  wf_items.item_key%TYPE;
   
      l_document_id   po_lines.po_header_id%TYPE;
      l_org_id        po_lines.org_id%TYPE;
      l_document_type VARCHAR2(25);
   
      l_document VARCHAR2(32000) := '';
   
      l_currency_code fnd_currencies.currency_code%TYPE;
   
      -- Bug 3668188: added new local var. note: the length of this
      -- varchar was determined based on the length in POXWPA1B.pls,
      -- which is the other place 'OPEN_FORM_COMMAND' attribute is used
   
      l_open_form_command VARCHAR2(200);
      l_view_po_url       VARCHAR2(1000); -- HTML Orders R12
      l_edit_po_url       VARCHAR2(1000); -- HTML Orders R12
   
      nl VARCHAR2(1) := fnd_global.newline;
   
      i                        NUMBER := 0;
      max_lines_dsp            NUMBER; -- <BUG 7006113>
      l_line_count             NUMBER := 0; -- <BUG 3616816> # lines/shipments on document
      line_mesg                fnd_new_messages.message_text%TYPE; --Bug 4695601
      l_num_records_to_display NUMBER; -- <BUG 3616816> actual # of records to be displayed in table
      l_row_span               VARCHAR2(30);
      -- <BUG 7006113 START>
      -- curr_len           NUMBER := 0;
      -- prior_len          NUMBER := 0;
      -- <BUG 7006113 END>
   
      -- po lines cursor
   
      -- <BUG 3616816 START> Declare TABLEs for each column that is selected
      -- from po_line_csr and po_line_loc_csr.
      --
      TYPE line_num_tbl_type IS TABLE OF po_lines.line_num%TYPE;
      TYPE shipment_num_tbl_type IS TABLE OF po_line_locations.shipment_num%TYPE;
      TYPE item_num_tbl_type IS TABLE OF mtl_system_items_kfv.concatenated_segments%TYPE;
      TYPE item_revision_tbl_type IS TABLE OF po_lines.item_revision%TYPE;
      TYPE item_desc_tbl_type IS TABLE OF po_lines.item_description%TYPE;
      TYPE uom_tbl_type IS TABLE OF mtl_units_of_measure.unit_of_measure_tl%TYPE;
      TYPE quantity_tbl_type IS TABLE OF po_lines.quantity%TYPE;
      TYPE unit_price_tbl_type IS TABLE OF po_lines.unit_price%TYPE;
      TYPE amount_tbl_type IS TABLE OF po_lines.amount%TYPE;
      TYPE location_tbl_type IS TABLE OF hr_locations.location_code%TYPE;
      TYPE organization_name_tbl_type IS TABLE OF org_organization_definitions.organization_name%TYPE;
      TYPE need_by_date_tbl_type IS TABLE OF po_line_locations.need_by_date%TYPE;
      TYPE promised_date_tbl_type IS TABLE OF po_line_locations.promised_date%TYPE;
      TYPE shipment_type_tbl_type IS TABLE OF po_line_locations.shipment_type%TYPE;
   
      TYPE po_line_id_type IS TABLE OF po_lines.po_line_id%TYPE;
      TYPE req_line_quantity_type IS TABLE OF po_requisition_lines_all.quantity%TYPE;
      TYPE req_requestor_name_type IS TABLE OF per_all_people_f.full_name%TYPE;
      TYPE req_justification_type IS TABLE OF po_requisition_lines_all.justification%TYPE;
      TYPE req_line_amount_type IS TABLE OF po_lines.attribute3%TYPE;
      TYPE req_quote_amount_type IS TABLE OF po_lines.attribute3%TYPE;
      TYPE linkage_price_type IS TABLE OF po_lines.attribute3%TYPE;
      TYPE last_po_amount_type IS TABLE OF po_lines.attribute3%TYPE;
      TYPE req_curr_count_type IS TABLE OF NUMBER;
   
      l_po_line_id_tbl    po_line_id_type;
      l_line_num_tbl      line_num_tbl_type;
      l_shipment_num_tbl  shipment_num_tbl_type;
      l_item_num_tbl      item_num_tbl_type;
      l_item_revision_tbl item_revision_tbl_type;
      l_item_desc_tbl     item_desc_tbl_type;
      l_uom_tbl           uom_tbl_type;
      l_quantity_tbl      quantity_tbl_type;
      l_unit_price_tbl    unit_price_tbl_type;
      l_amount_tbl        amount_tbl_type;
      l_location_tbl      location_tbl_type;
      l_org_name_tbl      organization_name_tbl_type;
      l_need_by_date_tbl  need_by_date_tbl_type;
      l_promised_date_tbl promised_date_tbl_type;
      l_shipment_type_tbl shipment_type_tbl_type;
   
      l_req_line_quantity_tbl  req_line_quantity_type;
      l_req_requestor_name_tbl req_requestor_name_type;
      l_req_justification_tbl  req_justification_type;
      l_req_line_amount_tbl    req_line_amount_type;
      l_req_quote_amount_tbl   req_quote_amount_type;
      l_linkage_price_tbl      linkage_price_type;
      l_last_po_amount_tbl     last_po_amount_type;
      l_req_curr_count_tbl     req_curr_count_type;
   
      --
      -- <BUG 3616816 END>
   
      /* Bug# 1419139: kagarwal
      ** Desc: The where clause pol.org_id = msi.organization_id(+) in the
      ** PO lines cursor, po_line_csr, is not correct as the pol.org_id
      ** is the operating unit which is not the same as the inventory
      ** organization_id.
      **
      ** We need to use the financials_system_parameter table for the
      ** inventory organization_id.
      **
      ** Also did the similar changes for the Release cursor,po_line_loc_csr.
      */
   
      /* Bug 2401933: sktiwari
         Modifying cursor po_line_csr to return the translated UOM value
         instead of unit_meas_lookup_code.
      */
   
      CURSOR po_line_csr(v_document_id NUMBER) IS
         SELECT pol.po_line_id,
                pol.line_num,
                msi.concatenated_segments,
                pol.item_revision,
                pol.item_description,
                --     pol.unit_meas_lookup_code, -- bug 2401933.remove
                nvl(muom.unit_of_measure_tl, pol.unit_meas_lookup_code), -- bug 2401933.add
                pol.quantity,
                pol.unit_price,
                nvl(pol.amount, pol.quantity * pol.unit_price),
                (SELECT SUM(rd.req_line_quantity)
                   FROM po_req_distributions_all rd, po_distributions_all pd
                  WHERE rd.distribution_id = pd.req_distribution_id AND
                        pd.po_line_id = pol.po_line_id),
                get_requisition_requestors(pol.po_line_id),
                get_requisition_justifications(pol.po_line_id),
                pol.attribute3,
                (SELECT nvl(l.attribute3,
                            round(l.unit_price, 4) || ' ' || h.currency_code)
                   FROM po_headers_all h, po_lines_all l
                  WHERE h.po_header_id = l.po_header_id AND
                        l.item_id = pol.item_id AND
                        l.po_line_id =
                        (SELECT MAX(po_line_id)
                           FROM po_lines_all l1
                          WHERE l1.item_id = pol.item_id AND
                                l1.po_line_id != pol.po_line_id AND
                                l.unit_price > 0)),
                (SELECT COUNT(DISTINCT
                              nvl(porl.currency_code, sob.currency_code))
                   FROM po_distributions_all         pd,
                        po_req_distributions_all     pord,
                        po_requisition_lines_all     porl,
                        gl_sets_of_books             sob,
                        financials_system_params_all fsp
                  WHERE pd.po_line_id = pol.po_line_id AND
                        pd.req_distribution_id = pord.distribution_id AND
                        pord.requisition_line_id = porl.requisition_line_id AND
                        fsp.org_id = porl.org_id AND
                        sob.set_of_books_id = fsp.set_of_books_id)
           FROM po_lines                     pol,
                mtl_system_items_kfv         msi,
                mtl_units_of_measure         muom, -- bug 2401933.add
                financials_system_parameters fsp
          WHERE pol.po_header_id = v_document_id AND
                pol.item_id = msi.inventory_item_id(+) AND
                nvl(msi.organization_id, fsp.inventory_organization_id) =
                fsp.inventory_organization_id AND
                nvl(pol.cancel_flag, 'N') = 'N' AND
                muom.unit_of_measure(+) = pol.unit_meas_lookup_code -- bug 2401933.add
          ORDER BY pol.line_num;
   
      CURSOR csr_req_amounts(p_po_line_id NUMBER) IS
         SELECT round(porl.unit_price, 4) || ' ' || sob.currency_code,
                round(porl.currency_unit_price, 4) || ' ' ||
                porl.currency_code
           FROM po_distributions_all         pd,
                po_req_distributions_all     pord,
                po_requisition_lines_all     porl,
                gl_sets_of_books             sob,
                financials_system_params_all fsp
          WHERE pd.po_line_id = p_po_line_id AND
                pd.req_distribution_id = pord.distribution_id AND
                pord.requisition_line_id = porl.requisition_line_id AND
                nvl(porl.cancel_flag, 'N') = 'N' AND
                fsp.org_id = porl.org_id AND
                sob.set_of_books_id = fsp.set_of_books_id;
   
      -- release shipments cursor
   
      /* Bug# 1530303: kagarwal
      ** Desc: We need to change the where clause as the item
      ** may not be an inventory item. For this case we should
      ** have an outer join with the mtl_system_items_kfv.
      **
      ** Changed the condition:
      ** pol.item_id = msi.inventory_item_id
      ** to pol.item_id = msi.inventory_item_id(+)
      **
      */
   
      /* Bug# 1718725: kagarwal
      ** Desc: The unit of measure may be null at the shipment level
      ** hence in this case we need to get the uom from line level.
      **
      ** Changed nvl(pll.unit_meas_lookup_code, pol.unit_meas_lookup_code)
      */
      /* Bug# 1770951: kagarwal
      ** Desc: For Releases we should consider the price_override on the shipments
      ** and not the price on the Blanket PO line as the shipment price could be
      ** different if the price override is enabled on the Blanket.
      */
   
      /* Bug 2401933: sktiwari
         Modifying cursor po_line_loc_csr to return the translated UOM value
         instead of unit_meas_lookup_code.
      */
   
      CURSOR po_line_loc_csr(v_document_id NUMBER) IS
         SELECT pll.shipment_num,
                msi.concatenated_segments,
                pol.item_revision,
                pol.item_description,
                -- Bug 2401933.start
                --     nvl(pll.unit_meas_lookup_code, pol.unit_meas_lookup_code)
                --         unit_meas_lookup_code,
                nvl(muom.unit_of_measure_tl, pol.unit_meas_lookup_code),
                -- Bug 2401933.end
                pll.quantity,
                nvl(pll.price_override, pol.unit_price) unit_price,
                hrl.location_code,
                ood.organization_name,
                pll.need_by_date,
                pll.promised_date,
                pll.shipment_type,
                --Bug 4950850 Added pll.amount
                --Bug 5563024 AMOUNT NOT SHOWN FOR A RELEASE SHIPMENT IN APPROVAL NOTIFICATION.
                nvl(pll.amount,
                    nvl(pll.price_override, pol.unit_price) * pll.quantity)
           FROM po_lines                     pol,
                po_line_locations            pll,
                mtl_system_items_kfv         msi,
                hr_locations_all             hrl,
                hz_locations                 hz,
                org_organization_definitions ood,
                mtl_units_of_measure         muom, -- Bug 2401933.add
                financials_system_parameters fsp
          WHERE pll.po_release_id = v_document_id AND
                pll.po_line_id = pol.po_line_id AND
                pll.ship_to_location_id = hrl.location_id(+) AND
                pll.ship_to_location_id = hz.location_id(+) AND
                pll.ship_to_organization_id = ood.organization_id AND
                pol.item_id = msi.inventory_item_id(+) AND
                nvl(msi.organization_id, fsp.inventory_organization_id) =
                fsp.inventory_organization_id
               /* Bug 2299484 fixed. prevented the canceled shipments to be displayed
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               in notifications.
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            */
                AND
                nvl(pll.cancel_flag, 'N') = 'N' AND
                muom.unit_of_measure(+) = pol.unit_meas_lookup_code -- Bug 2401933.add
          ORDER BY shipment_num ASC;
   
   BEGIN
   
      l_item_type := substr(document_id, 1, instr(document_id, ':') - 1);
      l_item_key  := substr(document_id,
                            instr(document_id, ':') + 1,
                            length(document_id) - 2);
   
      /* Bug# 2353153
      ** Setting application context
      */
   
      po_reqapproval_init1.set_doc_mgr_context(l_item_type, l_item_key);
   
      l_document_id := wf_engine.getitemattrnumber(itemtype => l_item_type,
                                                   itemkey  => l_item_key,
                                                   aname    => 'DOCUMENT_ID');
   
      l_org_id := wf_engine.getitemattrnumber(itemtype => l_item_type,
                                              itemkey  => l_item_key,
                                              aname    => 'ORG_ID');
   
      l_document_type := wf_engine.getitemattrtext(itemtype => l_item_type,
                                                   itemkey  => l_item_key,
                                                   aname    => 'DOCUMENT_TYPE');
   
      po_moac_utils_pvt.set_org_context(l_org_id); -- <R12 MOAC>
   
      /* Bug# 1686066: kagarwal
      ** Desc: Use the functional currency of the PO for the precision of
      ** line amounts.
      */
   
      l_currency_code := wf_engine.getitemattrtext(itemtype => l_item_type,
                                                   itemkey  => l_item_key,
                                                   aname    => 'FUNCTIONAL_CURRENCY');
   
      -- Bug 3668188
      l_open_form_command := po_wf_util_pkg.getitemattrtext(itemtype => l_item_type,
                                                            itemkey  => l_item_key,
                                                            aname    => 'OPEN_FORM_COMMAND');
   
      -- HTML Orders R12
      -- Get the PO HTML Page URL's
      l_view_po_url := po_wf_util_pkg.getitemattrtext(itemtype => l_item_type,
                                                      itemkey  => l_item_key,
                                                      aname    => 'VIEW_DOC_URL');
   
      l_edit_po_url := po_wf_util_pkg.getitemattrtext(itemtype => l_item_type,
                                                      itemkey  => l_item_key,
                                                      aname    => 'EDIT_DOC_URL');
   
      /* Bug# 2668222: kagarwal
      ** Desc: Using profile PO_NOTIF_LINES_LIMIT to get the maximum
      ** number of PO lines to be displayed in Approval notification.
      ** The same profile is also used for Requisitions.
      */
      -- <BUG 7006113  START Moved this code to the later section of the procedure >
      --  max_lines_dsp:= to_number(fnd_profile.value('PO_NOTIF_LINES_LIMIT'));
   
      -- if max_lines_dsp is NULL then
      --   max_lines_dsp := 20;
      -- end if;
      -- <BUG 7006113 END>
   
      -- <BUG 3616816 START> Fetch Release Shipments/PO Lines data into Tables.
      --
      IF (l_document_type = 'RELEASE') THEN
      
         OPEN po_line_loc_csr(l_document_id);
      
         FETCH po_line_loc_csr BULK COLLECT
            INTO l_shipment_num_tbl, l_item_num_tbl, l_item_revision_tbl, l_item_desc_tbl, l_uom_tbl, l_quantity_tbl, l_unit_price_tbl, l_location_tbl, l_org_name_tbl, l_need_by_date_tbl, l_promised_date_tbl, l_shipment_type_tbl, l_amount_tbl; --bug 4950850
      
         l_line_count := po_line_loc_csr%ROWCOUNT; -- Get # of records fetched.
      
         CLOSE po_line_loc_csr;
      
      ELSE
      
         OPEN po_line_csr(l_document_id);
      
         FETCH po_line_csr BULK COLLECT
            INTO l_po_line_id_tbl, l_line_num_tbl, l_item_num_tbl, l_item_revision_tbl, l_item_desc_tbl, l_uom_tbl, l_quantity_tbl, l_unit_price_tbl, l_amount_tbl, l_req_line_quantity_tbl, l_req_requestor_name_tbl, l_req_justification_tbl, l_linkage_price_tbl, l_last_po_amount_tbl, l_req_curr_count_tbl;
      
         l_line_count := po_line_csr%ROWCOUNT; -- Get # of records fetched.
      
         CLOSE po_line_csr;
      
      END IF;
      --
      -- <BUG 3616816 END>
   
      max_lines_dsp := to_number(fnd_profile.VALUE('PO_NOTIF_LINES_LIMIT'));
   
      IF max_lines_dsp IS NULL THEN
      
         max_lines_dsp := l_line_count;
      
      END IF;
   
      -- <BUG 3616816 START> Determine the actual number of records to display
      -- in the table.
      --
      IF (l_line_count >= max_lines_dsp) THEN
         l_num_records_to_display := max_lines_dsp;
      ELSE
         l_num_records_to_display := l_line_count;
      END IF;
      --
      -- <BUG 3616816 END>
   
      IF (display_type = 'text/html') THEN
      
         IF (nvl(l_document_type, 'PO') <> 'RELEASE') THEN
         
            l_document := nl || nl || '<!-- PO_LINE_DETAILS -->' || nl || nl ||
                          '<P><B>';
            l_document := l_document ||
                          fnd_message.get_string('PO',
                                                 'PO_WF_NOTIF_PO_LINE_DETAILS');
            l_document := l_document || '</B>' || nl || '<P>'; -- <BUG 3616816>
         
            -- <BUG 3616816 START> Only display message if # of actual lines is
            -- greater than maximum limit.
            --
            IF (l_line_count > max_lines_dsp) THEN
            
               -- Bug 3668188: changed the code check (originally created
               -- in bug 3607009) that determines which message to show
               -- based on whether Open Document icon is shown in the notif.
               -- The value of WF attribute 'OPEN_FORM_COMMAND' is set in a
               -- previous node, using the get_po_user_msg_attribute procedure.
               --
               -- HTML Orders R12
               -- Check for the URL parameters as well
               IF (l_open_form_command IS NULL) AND (l_view_po_url IS NULL) AND
                  (l_edit_po_url IS NULL) THEN
                  -- "The first [COUNT] Purchase Order lines are summarized below."
                  fnd_message.set_name('PO',
                                       'PO_WF_NOTIF_PO_LINE_MESG_TRUNC');
               ELSE
                  -- "The first [COUNT] Purchase Order lines are summarized
                  -- below. For information on additional lines, please click
                  -- the Open Document icon."
                  fnd_message.set_name('PO', 'PO_WF_NOTIF_PO_LINE_MESG');
               END IF;
            
               fnd_message.set_token('COUNT', to_char(max_lines_dsp));
               line_mesg  := fnd_message.get;
               l_document := l_document || line_mesg || '<P>';
            
            END IF;
            --
            -- <BUG 3616816 END>
         
            l_document := l_document || nl ||
                          '<TABLE border=1 cellpadding=2 cellspacing=1 summary="' ||
                          fnd_message.get_string('ICX',
                                                 'ICX_POR_TBL_PO_TO_APPROVE_SUM') ||
                          '"> ' || nl;
         
            l_document := l_document || '<TR>' || nl;
         
            l_document := l_document ||
                          '<TH  id="lineNum_1"><FONT FACE= "Arial", "Helvetica" SIZE="2">' ||
                          fnd_message.get_string('PO',
                                                 'PO_WF_NOTIF_LINE_NUMBER') ||
                          '</font></TH>' || nl;
         
            l_document := l_document ||
                          '<TH  id="itemNum_1"><FONT FACE= "Arial", "Helvetica" SIZE="2">' ||
                          fnd_message.get_string('PO',
                                                 'PO_WF_NOTIF_ITEM_NUMBER') ||
                          '</font></TH>' || nl;
         
            l_document := l_document ||
                          '<TH  id="itemRev_1"><FONT FACE= "Arial", "Helvetica" SIZE="2">' ||
                          fnd_message.get_string('PO',
                                                 'PO_WF_NOTIF_ITEM_REVISION') ||
                          '</font></TH>' || nl;
         
            l_document := l_document ||
                          '<TH  id="itemDesc_1"><FONT FACE= "Arial", "Helvetica" SIZE="2">' ||
                          fnd_message.get_string('PO',
                                                 'PO_WF_NOTIF_ITEM_DESC') ||
                          '</font></TH>' || nl;
         
            l_document := l_document ||
                          '<TH  id="uom_1"><FONT FACE= "Arial", "Helvetica" SIZE="2">' ||
                          fnd_message.get_string('PO', 'PO_WF_NOTIF_UOM') ||
                          '</font></TH>' || nl;
         
            l_document := l_document ||
                          '<TH  id="quant_1"><FONT FACE= "Arial", "Helvetica" SIZE="2">' ||
                          fnd_message.get_string('PO',
                                                 'PO_WF_NOTIF_QUANTITY') ||
                          '</font></TH>' || nl;
         
            fnd_message.set_name('XXOBJT', 'XXPO_WF_NOTIF_UNIT_PRICE');
            fnd_message.set_token('CURR', l_currency_code);
            l_document := l_document ||
                          '<TH  id="unitPrice_1"><FONT FACE= "Arial", "Helvetica" SIZE="2">' ||
                          fnd_message.get || '</font></TH>' || nl;
         
            fnd_message.set_name('XXOBJT', 'XXPO_WF_NOTIF_LINE_AMOUNT');
            fnd_message.set_token('CURR', l_currency_code);
            l_document := l_document ||
                          '<TH  id="lineAmt_1"><FONT FACE= "Arial", "Helvetica" SIZE="2">' ||
                          fnd_message.get || '</font></TH>' || nl;
         
            l_document := l_document ||
                          '<TH  id="reqQty_1"><FONT FACE= "Arial", "Helvetica" SIZE="2">' ||
                          fnd_message.get_string('XXOBJT',
                                                 'XXPO_WF_NOTIF_REQ_QTY') ||
                          '</font></TH>' || nl;
         
            l_document := l_document ||
                          '<TH  id="reqRequestor_1"><FONT FACE= "Arial", "Helvetica" SIZE="2">' ||
                          fnd_message.get_string('XXOBJT',
                                                 'XXPO_WF_NOTIF_REQUESTOR') ||
                          '</font></TH>' || nl;
         
            l_document := l_document ||
                          '<TH  id="reqJustification_1"><FONT FACE= "Arial", "Helvetica" SIZE="2">' ||
                          fnd_message.get_string('XXOBJT',
                                                 'XXPO_WF_NOTIF_JUSTIFICATION') ||
                          '</font></TH>' || nl;
         
            /*           l_document := l_document ||
                                      '<TH  id="reqJustification_1"><FONT FACE= "Arial", "Helvetica" SIZE="2">' ||
                                      fnd_message.get_string('XXOBJT',
                                                             'XXPO_WF_NOTIF_LINKAGE_PRICE') ||
                                      '</font></TH>' || nl;
            
                        l_document := l_document ||
                                      '<TH  id="reqJustification_1"><FONT FACE= "Arial", "Helvetica" SIZE="2">' ||
                                      fnd_message.get_string('XXOBJT',
                                                             'XXPO_WF_NOTIF_LAST_PO_PRICE') ||
                                      '</font></TH>' || nl;
            
                        l_document := l_document ||
                                      '<TH  id="reqJustification_1"><FONT FACE= "Arial", "Helvetica" SIZE="2">' ||
                                      fnd_message.get_string('XXOBJT',
                                                             'XXPO_WF_NOTIF_REQ_PRICE') ||
                                      '</font></TH>' || nl;
            
                        l_document := l_document ||
                                      '<TH  id="reqJustification_1"><FONT FACE= "Arial", "Helvetica" SIZE="2">' ||
                                      fnd_message.get_string('XXOBJT',
                                                             'XXPO_WF_NOTIF_QUOTE_PRICE') ||
                                      '</font></TH>' || nl;
            */
            l_document := l_document || '</TR>' || nl;
         
            -- curr_len  := lengthb(l_document);
            -- prior_len := curr_len;
         
            FOR i IN 1 .. l_num_records_to_display LOOP
               -- <BUG 3616816>
            
               /* Exit the cursor if the current document length and 2 times the
               ** length added in prior line exceeds 32000 char */
               -- < BUG 7006113 START Commented the loop to avoid the check so that maximum
               --  lines can be displayed >
               -- if (curr_len + (2 * (curr_len - prior_len))) >= 32000 then
               --  exit;
               --  end if;
               --  prior_len := curr_len;
               -- < BUG 7006113 END >
            
               l_document := l_document || '<TR>' || nl;
            
               l_document := l_document ||
                             '<TD nowrap align=center headers="lineNum_1"><FONT FACE= "Arial", "Helvetica" SIZE="2">' ||
                             nvl(to_char(l_line_num_tbl(i)), '&nbsp') ||
                             '</font></TD>' || nl;
               l_document := l_document ||
                             '<TD nowrap headers="itemNum_1"><FONT FACE= "Arial", "Helvetica" SIZE="2">' ||
                             nvl(l_item_num_tbl(i), '&nbsp') ||
                             '</font></TD>' || nl;
               l_document := l_document ||
                             '<TD nowrap headers="itemRev_1"><FONT FACE= "Arial", "Helvetica" SIZE="2">' ||
                             nvl(l_item_revision_tbl(i), '&nbsp') ||
                             '</font></TD>' || nl;
               l_document := l_document ||
                             '<TD nowrap headers="itemDesc_1"><FONT FACE= "Arial", "Helvetica" SIZE="2">' ||
                             nvl(l_item_desc_tbl(i), '&nbsp') ||
                             '</font></TD>' || nl;
               l_document := l_document ||
                             '<TD nowrap headers="uom_1"><FONT FACE= "Arial", "Helvetica" SIZE="2">' ||
                             nvl(l_uom_tbl(i), '&nbsp') || '</font></TD>' || nl;
               l_document := l_document ||
                             '<TD nowrap align=right headers="quant_1"><FONT FACE= "Arial", "Helvetica" SIZE="2">' ||
                             nvl(to_char(l_quantity_tbl(i)), '&nbsp') ||
                             '</font></TD>' || nl;
            
               /* Bug 2868931: kagarwal
               ** We will not format the unit price on the lines in notifications
               */
               -- Bug 3547777. Added the nvl clauses to unit_price and line_
               -- amount so that box is still displayed even if value is null.
               l_document := l_document ||
                             '<TD nowrap align=right headers="unitPrice_1"><FONT FACE= "Arial", "Helvetica" SIZE="2">' ||
                             nvl(to_char(l_unit_price_tbl(i),
                                         xxgl_utils_pkg.safe_get_format_mask(l_currency_code,
                                                                             30,
                                                                             'Y',
                                                                             4)),
                                 '&nbsp') || '</TD></font>' || nl; -- <BUG 7006113>
            
               l_document := l_document ||
                             '<TD nowrap align=right headers="lineAmt_1"><FONT FACE= "Arial", "Helvetica" SIZE="2">' ||
                             nvl(to_char(l_amount_tbl(i),
                                         xxgl_utils_pkg.safe_get_format_mask(l_currency_code,
                                                                             30,
                                                                             'Y',
                                                                             4)),
                                 '&nbsp') || '</font></TD>' || nl;
            
               l_document := l_document ||
                             '<TD nowrap align=right headers="reqQty_1"><FONT FACE= "Arial", "Helvetica" SIZE="2">' ||
                             nvl(to_char(l_req_line_quantity_tbl(i)),
                                 '&nbsp') || '</font></TD>' || nl;
            
               l_document := l_document ||
                             '<TD  align=right headers="reqRequestor_1"><FONT FACE= "Arial", "Helvetica" SIZE="2">' ||
                             nvl(l_req_requestor_name_tbl(i), '&nbsp') ||
                             '</font></TD>' || nl;
            
               l_document := l_document ||
                             '<TD  align=right headers="reqJustification_1"><FONT FACE= "Arial", "Helvetica" SIZE="2">' ||
                             nvl(l_req_justification_tbl(i), '&nbsp') ||
                             '</font></TD>' || nl;
            
               l_document := l_document || '</TR>' || nl;
            
               -- <BUG 7006113 START>
               --curr_len  := lengthb(l_document);
            
               wf_notification.writetoclob(document, l_document);
            
               l_document := NULL;
            
               EXIT WHEN i = l_num_records_to_display;
               -- <BUG 7006113 END>
            END LOOP;
         
         ELSE
            -- release
         
            l_document := nl || nl || '<!-- RELEASE_SHIPMENT_DETAILS -->' || nl || nl ||
                          '<P><B>';
            l_document := l_document ||
                          fnd_message.get_string('PO',
                                                 'PO_WF_NOTIF_SHIP_DETAILS');
            l_document := l_document || '</B>' || nl || '<P>';
         
            -- <BUG 3616816 START> Only display message if # of actual lines is
            -- greater than maximum limit.
            --
            IF (l_line_count > max_lines_dsp) THEN
               fnd_message.set_name('PO', 'PO_WF_NOTIF_PO_REL_SHIP_MESG');
               fnd_message.set_token('COUNT', to_char(max_lines_dsp));
               line_mesg  := fnd_message.get;
               l_document := l_document || line_mesg || '<P>';
            END IF;
            --
            -- <BUG 3616816 END>
         
            l_document := l_document ||
                          '<TABLE border=1 cellpadding=2 cellspacing=1 summary="' ||
                          fnd_message.get_string('ICX',
                                                 'ICX_POR_TBL_BL_TO_APPROVE_SUM') ||
                          '"> ' || nl;
         
            l_document := l_document || '<TR>' || nl;
         
            l_document := l_document || '<TH  id="shipNum_2">' ||
                          fnd_message.get_string('PO',
                                                 'PO_WF_NOTIF_SHIP_NUMBER') ||
                          '</TH>' || nl;
         
            l_document := l_document || '<TH  id="itemNum_2">' ||
                          fnd_message.get_string('PO',
                                                 'PO_WF_NOTIF_ITEM_NUMBER') ||
                          '</TH>' || nl;
         
            l_document := l_document || '<TH  id="itemRev_2">' ||
                          fnd_message.get_string('PO',
                                                 'PO_WF_NOTIF_ITEM_REVISION') ||
                          '</TH>' || nl;
         
            l_document := l_document || '<TH  id="itemDesc_2">' ||
                          fnd_message.get_string('PO',
                                                 'PO_WF_NOTIF_ITEM_DESC') ||
                          '</TH>' || nl;
         
            l_document := l_document || '<TH  id="uom_2">' ||
                          fnd_message.get_string('PO', 'PO_WF_NOTIF_UOM') ||
                          '</TH>' || nl;
         
            l_document := l_document || '<TH  id="quant_2">' ||
                          fnd_message.get_string('PO',
                                                 'PO_WF_NOTIF_QUANTITY') ||
                          '</TH>' || nl;
         
            l_document := l_document || '<TH  id="unitPrice_2">' ||
                          fnd_message.get_string('PO',
                                                 'PO_WF_NOTIF_UNIT_PRICE') ||
                          '</TH>' || nl;
         
            l_document := l_document || '<TH  id="location_2">' ||
                          fnd_message.get_string('PO',
                                                 'PO_WF_NOTIF_LOCATION') ||
                          '</TH>' || nl;
         
            l_document := l_document || '<TH  id="shipToOrg_2">' ||
                          fnd_message.get_string('PO', 'POA_SHIP_TO_ORG') ||
                          '</TH>' || nl;
         
            l_document := l_document || '<TH  id="needByDate_2">' ||
                          fnd_message.get_string('PO',
                                                 'PO_WF_NOTIF_NEED_BY_DATE') ||
                          '</TH>' || nl;
            /* bug 4950850 */
            l_document := l_document || '<TH  id="lineAmt_2">' ||
                          fnd_message.get_string('PO', 'PO_WF_NOTIF_AMOUNT') ||
                          '</TH>' || nl;
         
            l_document := l_document || '</TR>' || nl;
         
            -- curr_len  := lengthb(l_document);
            -- prior_len := curr_len;
         
            FOR i IN 1 .. l_num_records_to_display LOOP
               -- <BUG 3616816>
            
               /* Exit the cursor if the current document length and 2 times the
               ** length added in prior line exceeds 32000 char */
               -- < BUG 7006113 START Commented the loop to avoid the check so that
               --   maximum lines can be displayed >
               -- if (curr_len + (2 * (curr_len - prior_len))) >= 32000 then
               --   exit;
               -- end if;
               -- prior_len := curr_len;
               -- < BUG 7006113 END >
            
               l_document := l_document || '<TR>' || nl;
            
               l_document := l_document ||
                             '<TD nowrap align=center headers="shipNum_2">' ||
                             nvl(to_char(l_shipment_num_tbl(i)), '&nbsp') ||
                             '</TD>' || nl;
               l_document := l_document ||
                             '<TD nowrap  headers="itemNum_2">' ||
                             nvl(l_item_num_tbl(i), '&nbsp') || '</TD>' || nl;
               l_document := l_document ||
                             '<TD nowrap  headers="itemRev_2">' ||
                             nvl(l_item_revision_tbl(i), '&nbsp') ||
                             '</TD>' || nl;
               l_document := l_document ||
                             '<TD nowrap  headers="itemDesc_2">' ||
                             nvl(l_item_desc_tbl(i), '&nbsp') || '</TD>' || nl;
               l_document := l_document || '<TD nowrap  headers="uom_2">' ||
                             nvl(l_uom_tbl(i), '&nbsp') || '</TD>' || nl;
               l_document := l_document ||
                             '<TD nowrap align=right  headers="quant_2">' ||
                             nvl(to_char(l_quantity_tbl(i)), '&nbsp') ||
                             '</TD>' || nl;
            
               /* Bug 2868931: kagarwal
               ** We will not format the unit price on the lines in notifications
               */
            
               l_document := l_document ||
                             '<TD nowrap align=right  headers="unitPrice_2">' ||
                             nvl(po_wf_req_notification.format_currency_no_precesion(l_currency_code,
                                                                                     l_unit_price_tbl(i)),
                                 '&nbsp') || '</TD>' || nl; -- <BUG 7006113>
            
               l_document := l_document ||
                             '<TD nowrap  headers="location_2">' ||
                             nvl(l_location_tbl(i), '&nbsp') || '</TD>' || nl;
               l_document := l_document ||
                             '<TD nowrap  headers="shipToOrg_2">' ||
                             nvl(l_org_name_tbl(i), '&nbsp') || '</TD>' || nl;
               l_document := l_document ||
                             '<TD nowrap  headers="needByDate_2">' ||
                             to_char(l_need_by_date_tbl(i)) || '</TD>' || nl;
               /* bug 4950850 */
               l_document := l_document ||
                             '<TD nowrap align=right headers="lineAmt_2">' ||
                             nvl(to_char(l_amount_tbl(i),
                                         fnd_currency.get_format_mask(l_currency_code,
                                                                      30)),
                                 '&nbsp') || '</TD>' || nl;
               l_document := l_document || '</TR>' || nl;
            
               -- <BUG 7006113 START>
               -- curr_len  := lengthb(l_document);
            
               wf_notification.writetoclob(document, l_document);
            
               l_document := NULL;
            
               EXIT WHEN i = l_num_records_to_display;
               -- <BUG 7006113 END>
            
            END LOOP;
         
         END IF;
         l_document := l_document || '</TABLE></P>' || nl;
      
         wf_notification.writetoclob(document, l_document); -- <BUG 7006113>
      
         -- document := l_document; -- <BUG 7006113>
      
      ELSIF (display_type = 'text/plain') THEN
      
         IF (nvl(l_document_type, 'PO') <> 'RELEASE') THEN
         
            l_document := l_document ||
                          fnd_message.get_string('PO',
                                                 'PO_WF_NOTIF_PO_LINE_DETAILS') || nl || nl;
         
            -- <BUG 3616816 START> Only display message if # of actual lines is
            -- greater than maximum limit.
            --
            IF (l_line_count > max_lines_dsp) THEN
            
               -- Bug 3668188: changed the code check (originally created
               -- in bug 3607009) that determines which message to show
               -- based on whether Open Document icon is shown in then notif.
               -- The value of WF attribute 'OPEN_FORM_COMMAND' is set in a
               -- previous node, using the get_po_user_msg_attribute procedure.
               -- HTML Orders R12
               -- Check for the URL parameters as well
               IF (l_open_form_command IS NULL) AND (l_view_po_url IS NULL) AND
                  (l_edit_po_url IS NULL) THEN
                  -- "The first [COUNT] Purchase Order lines are summarized below."
                  fnd_message.set_name('PO',
                                       'PO_WF_NOTIF_PO_LINE_MESG_TRUNC');
               ELSE
                  -- "The first [COUNT] Purchase Order lines are summarized
                  -- below. For information on additional lines, please click
                  -- the Open Document icon."
                  fnd_message.set_name('PO', 'PO_WF_NOTIF_PO_LINE_MESG');
               END IF;
            
               fnd_message.set_token('COUNT', to_char(max_lines_dsp));
               line_mesg  := fnd_message.get;
               l_document := l_document || line_mesg || nl || nl;
            
            END IF;
            --
            -- <BUG 3616816 END>
         
            -- curr_len  := lengthb(l_document);
            -- prior_len := curr_len;
         
            FOR i IN 1 .. l_num_records_to_display LOOP
               -- <BUG 3616816>
            
               /* Exit the cursor if the current document length and 2 times the
               ** length added in prior line exceeds 32000 char */
               -- < BUG 7006113 START Commented the loop to avoid the check so
               --   that maximum lines can be displayed >
               --   if (curr_len + (2 * (curr_len - prior_len))) >= 32000 then
               --     exit;
               --   end if;
               --   prior_len := curr_len;
               -- < BUG 7006113 END >
            
               l_document := l_document ||
                             fnd_message.get_string('PO',
                                                    'PO_WF_NOTIF_LINE_NUMBER') || ':' ||
                             to_char(l_line_num_tbl(i)) || nl;
               l_document := l_document ||
                             fnd_message.get_string('PO',
                                                    'PO_WF_NOTIF_ITEM_NUMBER') || ': ' ||
                             l_item_num_tbl(i) || nl;
               l_document := l_document ||
                             fnd_message.get_string('PO',
                                                    'PO_WF_NOTIF_ITEM_REVISION') || ': ' ||
                             l_item_revision_tbl(i) || nl;
               l_document := l_document ||
                             fnd_message.get_string('PO',
                                                    'PO_WF_NOTIF_ITEM_DESC') || ': ' ||
                             l_item_desc_tbl(i) || nl;
               l_document := l_document ||
                             fnd_message.get_string('PO', 'PO_WF_NOTIF_UOM') || ': ' ||
                             l_uom_tbl(i) || nl;
               l_document := l_document ||
                             fnd_message.get_string('PO',
                                                    'PO_WF_NOTIF_QUANTITY') || ': ' ||
                             to_char(l_quantity_tbl(i)) || nl;
            
               /* Bug 2868931: kagarwal
               ** We will not format the unit price on the lines in notifications
               */
            
               l_document := l_document ||
                             fnd_message.get_string('PO',
                                                    'PO_WF_NOTIF_UNIT_PRICE') || ': ' ||
                             po_wf_req_notification.format_currency_no_precesion(l_currency_code,
                                                                                 l_unit_price_tbl(i)) || nl;
               l_document := l_document ||
                             fnd_message.get_string('PO',
                                                    'PO_WF_NOTIF_LINE_AMOUNT') || ': ' ||
                             to_char(l_amount_tbl(i),
                                     fnd_currency.get_format_mask(l_currency_code,
                                                                  30)) || nl || nl;
            
               -- < BUG 7006113 START >
               -- curr_len  := lengthb(l_document);
            
               wf_notification.writetoclob(document, l_document);
            
               l_document := NULL;
            
               EXIT WHEN i = l_num_records_to_display;
               -- < BUG 7006113 END >
            
            END LOOP;
         
         ELSE
            -- release
         
            l_document := l_document ||
                          fnd_message.get_string('PO',
                                                 'PO_WF_NOTIF_SHIP_DETAILS') || nl || nl || nl;
         
            -- <BUG 3616816 START> Only display message if # of actual lines is
            -- greater than maximum limit.
            --
            IF (l_line_count > max_lines_dsp) THEN
               fnd_message.set_name('PO', 'PO_WF_NOTIF_PO_REL_SHIP_MESG');
               fnd_message.set_token('COUNT', to_char(max_lines_dsp));
               line_mesg  := fnd_message.get;
               l_document := l_document || line_mesg || nl || nl;
            END IF;
            --
            -- <BUG 3616816 END>
         
            -- curr_len  := lengthb(l_document);
            -- prior_len := curr_len;
         
            FOR i IN 1 .. l_num_records_to_display LOOP
               -- <BUG 3616816>
            
               /* Exit the cursor if the current document length and 2 times the
               ** length added in prior line exceeds 32000 char */
               -- <BUG 7006113 START Commented the loop to avoid the check so that
               --  maximum lines can be displayed
               --  if (curr_len + (2 * (curr_len - prior_len))) >= 32000 then
               --  exit;
               --  end if;
               --  prior_len := curr_len;
               -- <BUG 7006113 END>
            
               l_document := l_document ||
                             fnd_message.get_string('PO',
                                                    'PO_WF_NOTIF_SHIP_NUMBER') || ': ' ||
                             to_char(l_shipment_num_tbl(i)) || nl;
               l_document := l_document ||
                             fnd_message.get_string('PO',
                                                    'PO_WF_NOTIF_ITEM_NUMBER') || ': ' ||
                             l_item_num_tbl(i) || nl;
               l_document := l_document ||
                             fnd_message.get_string('PO',
                                                    'PO_WF_NOTIF_ITEM_REVISION') || ': ' ||
                             l_item_revision_tbl(i) || nl;
               l_document := l_document ||
                             fnd_message.get_string('PO',
                                                    'PO_WF_NOTIF_ITEM_DESC') || ': ' ||
                             l_item_desc_tbl(i) || nl;
               l_document := l_document ||
                             fnd_message.get_string('PO', 'PO_WF_NOTIF_UOM') || ': ' ||
                             l_uom_tbl(i) || nl;
               l_document := l_document ||
                             fnd_message.get_string('PO',
                                                    'PO_WF_NOTIF_QUANTITY') || ': ' ||
                             to_char(l_quantity_tbl(i)) || nl;
            
               /* Bug 2868931: kagarwal
               ** We will not format the unit price on the lines in notifications
               */
            
               l_document := l_document ||
                             fnd_message.get_string('PO',
                                                    'PO_WF_NOTIF_UNIT_PRICE') || ': ' ||
                             po_wf_req_notification.format_currency_no_precesion(l_currency_code,
                                                                                 l_unit_price_tbl(i)) || nl;
               -- bug 4950850
               l_document := l_document ||
                             fnd_message.get_string('PO',
                                                    'PO_WF_NOTIF_AMOUNT') || ': ' ||
                             to_char(l_amount_tbl(i),
                                     fnd_currency.get_format_mask(l_currency_code,
                                                                  30)) || nl;
               l_document := l_document ||
                             fnd_message.get_string('PO',
                                                    'PO_WF_NOTIF_LOCATION') || ': ' ||
                             l_location_tbl(i) || nl;
               l_document := l_document ||
                             fnd_message.get_string('PO', 'POA_SHIP_TO_ORG') || ': ' ||
                             l_org_name_tbl(i) || nl;
               l_document := l_document ||
                             fnd_message.get_string('PO',
                                                    'PO_WF_NOTIF_NEED_BY_DATE') || ': ' ||
                             to_char(l_need_by_date_tbl(i)) || nl || nl;
            
               -- <BUG 7006113 START>
               -- curr_len  := lengthb(l_document);
            
               wf_notification.writetoclob(document, l_document);
            
               l_document := NULL;
            
               EXIT WHEN i = l_num_records_to_display;
               -- <BUG 7006113 END>
            
            END LOOP;
         
         END IF;
      
         wf_notification.writetoclob(document, l_document); -- <BUG 7006113>
         -- document := l_document; -- <Bug 7006113>
      END IF;
   
   END get_po_lines_details;

END xxpo_notification_attr_pkg;
/

