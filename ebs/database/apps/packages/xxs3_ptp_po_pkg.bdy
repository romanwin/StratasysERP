CREATE OR REPLACE PACKAGE BODY xxs3_ptp_po_pkg AS
  ----------------------------------------------------------------------------
  --  name:            xxs3_ptp_po_pkg
  --  create by:       Debarati Banerjee
  --  Revision:        1.0
  --  creation date:   28/07/2016
  ----------------------------------------------------------------------------
  --  purpose :        Package to extract the Open PO template fields
  --                   from Legacy system

  ----------------------------------------------------------------------------
  --  ver  date        name                         desc
  --  1.0  28/07/2016  Debarati Banerjee            Initial build
  ----------------------------------------------------------------------------

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Update agent_name
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  19/04/2016  Debarati Banerjee            Initial build
  -----------------------------------------------------------------------------------------------

  PROCEDURE update_agent_name(p_id         IN NUMBER,
                              p_agent_id   IN NUMBER,
                              p_agent_name IN VARCHAR2) IS

    l_buyer     NUMBER := 0;
    l_emp       NUMBER := 0;
    l_error_msg VARCHAR2(4000);
    l_step      VARCHAR2(50);

  BEGIN
    SELECT COUNT(1)
    INTO   l_emp
    FROM   per_all_people_f papf
    WHERE  papf.person_id = p_agent_id
    AND    SYSDATE BETWEEN nvl(papf.effective_start_date, SYSDATE) AND
           nvl(papf.effective_end_date, SYSDATE);

    SELECT COUNT(1)
    INTO   l_buyer
    FROM   po_agents pa
    WHERE  pa.agent_id = p_agent_id
    AND    SYSDATE BETWEEN nvl(pa.start_date_active, SYSDATE) AND
           nvl(pa.end_date_active, SYSDATE);

    IF l_buyer > 0 AND l_emp > 0 THEN
      UPDATE xxs3_ptp_po
      SET    s3_agent_name = p_agent_name
      WHERE  xx_po_header_id = p_id;
    ELSE
      UPDATE xxs3_ptp_po
      SET    s3_agent_name = 'Buyer, Stratasys'
      WHERE  xx_po_header_id = p_id;
    END IF;

    COMMIT;

  EXCEPTION
    WHEN OTHERS THEN
      l_error_msg := 'UNEXPECTED ERROR on s3_agent_name update at step : '||l_step||':' ||SQLCODE||'-' ||SQLERRM;
      BEGIN
        UPDATE xxs3_ptp_po
        SET    cleanse_status = 'FAIL',
               cleanse_error  = cleanse_error || ':' || '' || l_error_msg
        WHERE  xx_po_header_id = p_id;
      EXCEPTION
         WHEN OTHERS THEN
            fnd_file.put_line(fnd_file.log, 'Unexpected error during cleansing of agent name for xx_po_header_id = '
                          ||p_id||chr(10) || SQLCODE || chr(10) || SQLERRM);
      END;

      COMMIT;

  END update_agent_name;

  --- --------------------------------------------------------------------------------------------
  -- Purpose: Update legacy values Amount Agreed value
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  05/10/2016  Sateesh            Initial build
  -----------------------------------------------------------------------------------------------
   PROCEDURE update_amount_agreed(p_po_header_id         IN NUMBER,
                                  p_id IN NUMBER
                              ) IS


    l_error_msg VARCHAR2(4000);
	  l_amount_agreed NUMBER;

  BEGIN
    BEGIN
      SELECT SUM(quantity_line * unit_price)
        INTO l_amount_agreed
        FROM xxs3_ptp_po pllv
       WHERE po_header_id = p_po_header_id
         AND process_flag <> 'R';
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
       fnd_file.put_line(fnd_file.log, 'Amount agreed field cannot be calculated due to no data found for xx_po_header_id = '
                          ||p_id||chr(10) || SQLCODE || chr(10) || SQLERRM);
    END;

      UPDATE xxs3_ptp_po
      SET    amount_agreed = l_amount_agreed
      WHERE  xx_po_header_id = p_id;

    COMMIT;

  EXCEPTION
    WHEN OTHERS THEN
        l_error_msg := 'Unexpected error during update of amount_agreed field for xx_po_header_id = '
                          ||p_id||chr(10) || SQLCODE || chr(10) || SQLERRM;
        fnd_file.put_line(fnd_file.log, l_error_msg);
       BEGIN
        UPDATE xxs3_ptp_po
        SET    transform_status = 'FAIL',
               transform_error  = transform_error || ':' || '' || l_error_msg
        WHERE  xx_po_header_id = p_id;

       EXCEPTION
        WHEN OTHERS THEN
            fnd_file.put_line(fnd_file.log, 'Unexpected error during update of transformation status for xx_po_header_id = '
                            ||p_id||chr(10) || SQLCODE || chr(10) || SQLERRM);
       END;

      COMMIT;

  END update_amount_agreed;

   -- --------------------------------------------------------------------------------------------
  -- Purpose: Update vendor contact
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  05/10/2016  Debarati Banerjee            Initial build
  -----------------------------------------------------------------------------------------------

  PROCEDURE update_vendor_contact(p_id         IN NUMBER,
                              p_vendor_contact_id   IN NUMBER) IS

    l_count     NUMBER := 0;
    l_error_msg VARCHAR2(4000);

  BEGIN
    SELECT COUNT(1)
      INTO l_count
      FROM xxs3_ptp_suppliers_cont
     WHERE vendor_contact_id = p_vendor_contact_id;

    IF l_count = 0 THEN
      UPDATE xxs3_ptp_po
      SET    vendor_contact = NULL
      WHERE  xx_po_header_id = p_id;
    END IF;

    COMMIT;

  EXCEPTION
    WHEN OTHERS THEN
       l_error_msg := 'Unexpected error during update of vendor_contact field for xx_po_header_id = '
                          ||p_id||chr(10) || SQLCODE || chr(10) || SQLERRM;
        fnd_file.put_line(fnd_file.log, l_error_msg);
       BEGIN
          UPDATE xxs3_ptp_po
          SET    transform_status = 'FAIL',
                 transform_error  = transform_error || ':' || '' || l_error_msg
          WHERE  xx_po_header_id = p_id;
       EXCEPTION
        WHEN OTHERS THEN
            fnd_file.put_line(fnd_file.log, 'Unexpected error during update of transformation status for xx_po_header_id = '
                            ||p_id||chr(10) || SQLCODE || chr(10) || SQLERRM);
       END;

      COMMIT;

  END update_vendor_contact;


  --- --------------------------------------------------------------------------------------------
  -- Purpose: Update legacy values match_option and receipt_required_flag_ship value
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  01/08/2016  Debarati Banerjee            Initial build
  -----------------------------------------------------------------------------------------------

  PROCEDURE update_legacy_values(p_id                IN NUMBER,
                                 /*p_flag              IN VARCHAR2,
                                 p_receipt_reqd_flag IN VARCHAR2,*/
                                 p_po_header_id      IN NUMBER,
                                 p_currency          IN VARCHAR2) IS

    l_error_msg VARCHAR2(4000);
    l_currency VARCHAR2(50);
    l_step VARCHAR2(50);

  BEGIN
    --IF p_flag = 'Y' THEN
      UPDATE xxs3_ptp_po
      SET    s3_match_option               = 'P',
             s3_bill_to_location           = 'Stratasys US - EP - Edenvale',
             --s3_receipt_required_flag_ship = 'Y',
             cleanse_status                = 'PASS'
      WHERE  xx_po_header_id = p_id;
    /*ELSE
      UPDATE xxs3_ptp_po
      SET    s3_match_option               = 'P',
             s3_bill_to_location           = 'Stratasys US - EP - Edenvale',
             s3_receipt_required_flag_ship = p_receipt_reqd_flag,
             cleanse_status                = 'PASS'
      WHERE  xx_po_header_id = p_id;
    END IF;*/

     BEGIN
      --check functional currency
      l_step := 'Check functional currency';
       SELECT gll.currency_code
         INTO l_currency
         FROM po_headers_all pha, hr_operating_units hou, gl_ledgers gll
        WHERE pha.org_id = hou.organization_id
          AND hou.set_of_books_id = gll.ledger_id
          AND pha.po_header_id = p_po_header_id;

        IF l_currency = p_currency THEN
         l_step := 'Update Rate Details';
          UPDATE xxs3_ptp_po
             SET rate_hdr       = NULL,
                 rate_date_hdr  = NULL,
                 rate_type      = NULL,
                 rate_dist      = NULL,
                 rate_date_dist = NULL
           WHERE xx_po_header_id = p_id;
        END IF;
     EXCEPTION
       WHEN NO_DATA_FOUND THEN
        fnd_file.put_line(fnd_file.log, 'No data found for functional currency of po_header_id  : ' ||p_po_header_id);
       WHEN OTHERS THEN
        l_error_msg := 'Unexpected error during : ' ||l_step ||chr(10) || SQLCODE || chr(10) || SQLERRM;
        fnd_file.put_line(fnd_file.log, l_error_msg);
     END;

 EXCEPTION
    WHEN OTHERS THEN
       l_error_msg := 'Unexpected error during update of legacy fields for xx_po_header_id = '
                          ||p_id||chr(10) || SQLCODE || chr(10) || SQLERRM;
        fnd_file.put_line(fnd_file.log, l_error_msg);
    BEGIN
      UPDATE xxs3_ptp_po
      SET    cleanse_status = 'FAIL',
             cleanse_error  = cleanse_error || ':' || '' || l_error_msg
      WHERE  xx_po_header_id = p_id;

    EXCEPTION
        WHEN OTHERS THEN
            fnd_file.put_line(fnd_file.log, 'Unexpected error during update of cleanse status for xx_po_header_id = '
                            ||p_id||chr(10) || SQLCODE || chr(10) || SQLERRM);
    END;

 END update_legacy_values;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Insert in to DQ table for validation errors and update master table
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  13/07/2016   Debarati Banerjee            Initial build
  -----------------------------------------------------------------------------------------------

  PROCEDURE insert_update_po_dq(p_xx_po_header_id NUMBER,
                                p_rule_name       IN VARCHAR2,
                                p_reject_code     IN VARCHAR2) IS
   l_step VARCHAR2(50);
  BEGIN
  /* Update Process flag for DQ records with 'Q' */
     l_step := 'Set Process_Flag =Q';
    UPDATE xxs3_ptp_po
       SET process_flag = 'Q'
     WHERE xx_po_header_id = p_xx_po_header_id;


	 /* Insert records in the DQ table with DQ details */
	   l_step := 'Insert into DQ table';

    INSERT INTO xxs3_ptp_po_dq
      (xx_dq_po_header_id, xx_po_header_id, rule_name, notes)
    VALUES
      (xxs3_ptp_po_dq_seq.NEXTVAL,
       p_xx_po_header_id,
       p_rule_name,
       p_reject_code);
 EXCEPTION
      WHEN OTHERS THEN
        fnd_file.put_line(fnd_file.log, 'Unexpected error during DQ table DML for xx_po_header_id = '
                          ||p_xx_po_header_id|| 'at step: '||l_step||chr(10) || SQLCODE || chr(10) || SQLERRM);

  END insert_update_po_dq;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Extract data from staging tables for quality check
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0  01/08/2016  Debarati Banerjee            Initial build
  -----------------------------------------------------------------------------------------------

  PROCEDURE quality_check_po IS

    l_status     VARCHAR2(10) := 'SUCCESS';
    l_check_rule VARCHAR2(10) := 'TRUE';

    CURSOR c_quality IS
      SELECT xx_po_header_id,
             agent_name,
             agent_id,
             destination_organization,
             ship_to_org_code_ship,
             ship_to_location_ship
      FROM   xxs3_ptp_po
      WHERE  process_flag = 'N'
      AND    nvl(cleanse_status, 'PASS') <> 'FAIL';

  BEGIN
    FOR i IN c_quality LOOP
      l_status := 'SUCCESS';

      IF i.agent_name IS NOT NULL THEN
        l_check_rule := xxs3_dq_util_pkg.eqt_175(i.agent_id);

        IF l_check_rule = 'FALSE' THEN
          insert_update_po_dq(i.xx_po_header_id, 'EQT_175:Agent is valid Employee', 'Agent is not valid employee');
          l_status := 'ERR';
        END IF;
      END IF;

	  IF i.destination_organization IS NOT NULL THEN
        l_check_rule := xxs3_dq_util_pkg.eqt_176_1(i.destination_organization,i.ship_to_org_code_ship,i.ship_to_location_ship);
         IF l_check_rule = 'FALSE' THEN
          insert_update_po_dq(i.xx_po_header_id, 'EQT_176_1:Destination Organization should tag with  Ship To Location', 'Destination Organization not tag with  Ship To Location');

		    UPDATE xxs3_ptp_po
         SET    process_flag = 'R'
        WHERE  xx_po_header_id = i.xx_po_header_id;

          l_status := 'ERR';
        END IF;
      END IF;

      IF l_status <> 'ERR' THEN
        UPDATE xxs3_ptp_po
        SET    process_flag = 'Y'
        WHERE  xx_po_header_id = i.xx_po_header_id;
      END IF;
    END LOOP;

    --COMMIT;
  END quality_check_po;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will extract all required Open PO fields and insert into
  --           staging table XXS3_PTP_PO
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0  28/07/2016  Debarati Banerjee            Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE open_po_extract_data(x_errbuf  OUT VARCHAR2,
                                 x_retcode OUT NUMBER) IS

    l_org_id                 NUMBER := fnd_global.org_id;
    l_errbuf                 VARCHAR2(2000);
    l_retcode                VARCHAR2(1);
    l_requestor              NUMBER;
    l_program_short_name     VARCHAR2(100);
    l_status_message         VARCHAR2(4000);
    l_output                 VARCHAR2(4000);
    l_output_code            VARCHAR2(100);
    l_output_coa_update      VARCHAR2(4000);
    l_output_code_coa_update VARCHAR2(100);
    l_file                   utl_file.file_type;
    l_file_path              VARCHAR2(100);
    l_file_name              VARCHAR2(100);
    l_step                   VARCHAR2(50);
    l_count                  NUMBER;

    CURSOR c_po_extract IS
      SELECT po_header_id,
             acceptance_due_date,
             agent_name,
             agent_id,
             amount_limit,
             approved_date,
             attribute1_hdr,
             attribute2_hdr,
             attribute3_hdr,
             attribute4_hdr,
             attribute5_hdr,
             attribute6_hdr,
             attribute7_hdr,
             attribute8_hdr,
             attribute9_hdr,
             attribute10_hdr,
             attribute11_hdr,
             attribute12_hdr,
             attribute13_hdr,
             attribute14_hdr,
             attribute15_hdr,
             attribute_category_hdr,
             bill_to_location,
             change_summary,
             currency_code,
             segment1,
             --DOCUMENT_TYPE_CODE,
             doc_type_name,
             --DOCUMENT_SUBTYPE,
             --EFFECTIVE_DATE,
             creation_date_disp,
             freight_carrier_hdr,
             fob_hdr,
             freight_terms_hdr,
             global_agreement_flag,
             min_release_amount_hdr,
             note_to_receiver_hdr,
             note_to_vendor_hdr,
             operating_unit_name,
             payment_terms_hdr,
             printed_date,
             print_count,
             rate_hdr,
             rate_date_hdr,
             rate_type,
             revised_date,
             revision_num,
             shipping_control,
             ship_to_location_hdr,
             vendor_contact,
             vendor_contact_id,
             vendor_name,
             vendor_num,
             vendor_site_code,
             acceptance_required_flag,
             confirming_order_flag,
             --line and line locations
             accrue_on_receipt_flag_ship,
             allow_sub_receipts_flag_ship,
             amount_line,
             amount_ship,
             base_unit_price,
             category,
             committed_amount,
             days_early_rec_allowed_ship,
             days_late_receipt_allowed_ship,
             drop_ship_flag,
             enforce_ship_to_loc_code_ship,
             expiration_date,
             fob_ship,
             freight_carrier_ship,
             freight_terms_ship,
             hazard_class,
             inspection_required_flag_ship,
             invoice_close_tolerance_ship,
             item_number,
             item_description,
             item_revision,
             job_name,
             line_attribute1,
             line_attribute2,
             line_attribute3,
             line_attribute4,
             line_attribute5,
             line_attribute6,
             line_attribute7,
             line_attribute8,
             line_attribute9,
             line_attribute10,
             line_attribute11,
             line_attribute12,
             line_attribute13,
             line_attribute14,
             line_attribute15,
             line_attribute_category_lines,
             price_type,
             allow_price_override_flag,
             un_number,
             capital_expense_flag,
             transaction_reason_code,
             quantity_committed,
             not_to_exceed_price,
             line_num,
             line_type,
             list_price_per_unit,
             market_price,
             min_release_amount_line,
             need_by_date_ship,
             negotiated_by_preparer_flag,
             note_to_receiver_ship,
             note_to_vendor_line,
             over_tolerance_error_flag,
             payment_terms_ship,
             preferred_grade_line,
             preferred_grade_ship,
             price_break_lookup_code,
             promised_date_ship,
             --QTY_RCV_EXCEPTION_CODE_LINE ,
             qty_rcv_exception_code_ship,
             qty_rcv_tolerance_line,
             qty_rcv_tolerance_ship,
             quantity_line,
             quantity_ship,
             quantity_billed_ship,
             quantity_cancelled_ship,
             quantity_received_ship,
             receipt_days_exc_code_ship,
             receipt_required_flag_ship,
             receive_close_tolerance_ship,
             receiving_routing_ship,
             shipment_attribute1,
             shipment_attribute2,
             shipment_attribute3,
             shipment_attribute4,
             shipment_attribute5,
             shipment_attribute6,
             shipment_attribute7,
             shipment_attribute8,
             shipment_attribute9,
             shipment_attribute10,
             shipment_attribute11,
             shipment_attribute12,
             shipment_attribute13,
             shipment_attribute14,
             shipment_attribute15,
             shipment_attribute_category,
             shipment_num_ship,
             shipment_type_ship,
             ship_to_location_ship,
             ship_to_org_code_ship,
             type_1099,
             unit_of_measure_line,
             unit_of_measure_ship,
             unit_price,
             vendor_product_num,
             price_discount_ship,
             start_date,
             end_date,
             price_override,
             lead_time_ship,
             lead_time_unit_ship,
             matching_basis,
             accrue_on_receipt_flag_dist,
             accrual_account,
             accrual_acct_segment1,
             accrual_acct_segment2,
             accrual_acct_segment3,
             --ACCRUAL_ACCT_SEGMENT4       ,
             accrual_acct_segment5,
             accrual_acct_segment6,
             accrual_acct_segment7,
             accrual_acct_segment10,
             amount_billed,
             amount_ordered,
             attribute1_dist,
             attribute2_dist,
             attribute3_dist,
             attribute4_dist,
             attribute5_dist,
             attribute6_dist,
             attribute7_dist,
             attribute8_dist,
             attribute9_dist,
             attribute10_dist,
             attribute11_dist,
             attribute12_dist,
             attribute13_dist,
             attribute14_dist,
             attribute15_dist,
             attribute_category_dist,
             budget_account,
             budget_acct_segment1,
             budget_acct_segment2,
             budget_acct_segment3,
             --BUDGET_ACCT_SEGMENT4      ,
             budget_acct_segment5,
             budget_acct_segment6,
             budget_acct_segment7,
             budget_acct_segment10,
             charge_account,
             charge_acct_segment1,
             charge_acct_segment2,
             charge_acct_segment3,
             --BUDGET_ACCT_SEGMENT4      ,
             charge_acct_segment5,
             charge_acct_segment6,
             charge_acct_segment7,
             charge_acct_segment10,
             deliver_to_location,
             deliver_to_person,
             destination_context,
             destination_organization,
             destination_subinventory,
             destination_type_code,
             distribution_num,
             encumbered_amount,
             encumbered_flag,
             expenditure_item_date,
             expenditure_organization,
             expenditure_type,
             failed_funds_lookup_code,
             gl_cancelled_date,
             gl_encumbered_date,
             gl_encumbered_period_name,
             nonrecoverable_tax,
             prevent_encumbrance_flag,
             project,
             project_accounting_context,
             quantity_billed_dist,
             quantity_cancelled_dist,
             --QUANTITY_DELIVERED,
             quantity_ordered_dist,
             rate_dist,
             rate_date_dist,
             recoverable_tax,
             recovery_rate,
             set_of_books,
             task_id,
             task,
             tax_recovery_override_flag,
             variance_account,
             variance_acct_segment1,
             variance_acct_segment2,
             variance_acct_segment3,
             --VARIANCE_ACCT_SEGMENT4      ,
             variance_acct_segment5,
             variance_acct_segment6,
             variance_acct_segment7,
             variance_acct_segment10,
             match_option
        FROM (SELECT phv.po_header_id po_header_id, --scenario 1 (PO is not received or invoiced)
                     phv.acceptance_due_date,
                     phv.agent_name,
                     phv.agent_id,
                     phv.amount_limit,
                     phv.approved_date,
                     phv.attribute1 attribute1_hdr,
                     phv.attribute2 attribute2_hdr,
                     phv.attribute3 attribute3_hdr,
                     phv.attribute4 attribute4_hdr,
                     phv.attribute5 attribute5_hdr,
                     phv.attribute6 attribute6_hdr,
                     phv.attribute7 attribute7_hdr,
                     phv.attribute8 attribute8_hdr,
                     phv.attribute9 attribute9_hdr,
                     phv.attribute10 attribute10_hdr,
                     phv.attribute11 attribute11_hdr,
                     phv.attribute12 attribute12_hdr,
                     phv.attribute13 attribute13_hdr,
                     phv.attribute14 attribute14_hdr,
                     phv.attribute15 attribute15_hdr,
                     phv.attribute_category attribute_category_hdr,
                     phv.bill_to_location,
                     phv.change_summary,
                     phv.currency_code,
                     phv.segment1,
                     --phv.DOCUMENT_TYPE_CODE,
                     --phv.doc_type_name,--change
                     phv.type_lookup_code doc_type_name,
                     --phv.DOCUMENT_SUBTYPE,
                     --phv.EFFECTIVE_DATE,
                     phv.creation_date_disp, --need to verify
                     phv.ship_via_lookup_code freight_carrier_hdr,
                     --PHV.FOB_LOOKUP_CODE FOB_HDR, --new field
                     phv.fob_lookup_code fob_hdr,
                     phv.freight_terms_dsp freight_terms_hdr,
                     phv.global_agreement_flag,
                     phv.min_release_amount min_release_amount_hdr,
                     phv.note_to_receiver note_to_receiver_hdr,
                     phv.note_to_vendor note_to_vendor_hdr,
                     (SELECT hou .NAME
                        FROM hr_operating_units hou
                       WHERE hou.organization_id = phv.org_id) operating_unit_name,
                     payment_terms payment_terms_hdr,
                     phv.printed_date,
                     phv.print_count,
                     phv.rate rate_hdr,
                     phv.rate_date rate_date_hdr,
                     phv.rate_type,
                     phv.revised_date,
                     phv.revision_num,
                     phv.shipping_control,
                     phv.ship_to_location ship_to_location_hdr,
                     phv.vendor_contact,
                     phv.vendor_contact_id,
                     phv.vendor_name,
                     (SELECT segment1
                        FROM ap_suppliers
                       WHERE vendor_id = phv.vendor_id) vendor_num,
                     phv.vendor_site_code,
                     phv.acceptance_required_flag,
                     phv.confirming_order_flag,
                     --line and line locations
                     pllv.accrue_on_receipt_flag accrue_on_receipt_flag_ship,
                     pllv.allow_substitute_receipts_flag allow_sub_receipts_flag_ship,
                     plv.amount amount_line,
                     pllv.amount amount_ship,
                     plv.base_unit_price,
                     (SELECT concatenated_segments
                        FROM mtl_categories_b_kfv mcbk
                       WHERE mcbk.category_id = plv.category_id) category,
                     plv.committed_amount,
                     pllv.days_early_receipt_allowed days_early_rec_allowed_ship,
                     pllv.days_late_receipt_allowed days_late_receipt_allowed_ship,
                     pllv.drop_ship_flag,
                     pllv.enforce_ship_to_location_code enforce_ship_to_loc_code_ship,
                     plv.expiration_date,
                     pllv.fob_lookup_code fob_ship,
                     pllv.ship_via_lookup_code freight_carrier_ship,
                     pllv.freight_terms_lookup_code freight_terms_ship,
                     plv.hazard_class,
                     pllv.inspection_required_flag inspection_required_flag_ship,
                     pllv.invoice_close_tolerance invoice_close_tolerance_ship,
                     plv.item_number,
                     plv.item_description,
                     plv.item_revision,
                     (SELECT NAME
                        FROM per_jobs pj
                       WHERE pj.job_id = plv.job_id) job_name, --need to fetch job_name
                     plv.attribute1 line_attribute1,
                     plv.attribute2 line_attribute2,
                     plv.attribute3 line_attribute3,
                     plv.attribute4 line_attribute4,
                     plv.attribute5 line_attribute5,
                     plv.attribute6 line_attribute6,
                     plv.attribute7 line_attribute7,
                     plv.attribute8 line_attribute8,
                     plv.attribute9 line_attribute9,
                     plv.attribute10 line_attribute10,
                     plv.attribute11 line_attribute11,
                     plv.attribute12 line_attribute12,
                     plv.attribute13 line_attribute13,
                     plv.attribute14 line_attribute14,
                     plv.attribute15 line_attribute15,
                     plv.attribute_category line_attribute_category_lines,
                     plv.price_type,
                     plv.allow_price_override_flag,
                     plv.un_number,
                     plv.capital_expense_flag,
                     plv.transaction_reason_code,
                     plv.quantity_committed,
                     plv.not_to_exceed_price,
                     plv.line_num,
                     plv.line_type,
                     plv.list_price_per_unit,
                     plv.market_price,
                     plv.min_release_amount min_release_amount_line,
                     pllv.need_by_date need_by_date_ship,
                     plv.negotiated_by_preparer_flag,
                     pllv.note_to_receiver note_to_receiver_ship,
                     plv.note_to_vendor note_to_vendor_line,
                     plv.over_tolerance_error_flag,
                     pllv.payment_terms_name payment_terms_ship,
                     plv.preferred_grade preferred_grade_line,
                     plv.preferred_grade preferred_grade_ship,
                     plv.price_break_lookup_code,
                     pllv.promised_date promised_date_ship,
                     --QTY_RCV_EXCEPTION_CODE_LINE ,
                     pllv.qty_rcv_exception_code qty_rcv_exception_code_ship,
                     plv.qty_rcv_tolerance qty_rcv_tolerance_line,
                     pllv.qty_rcv_tolerance qty_rcv_tolerance_ship,
                     (SELECT SUM(quantity_left)
                        FROM (SELECT (pll.quantity - pll.quantity_billed -
                                     pll.quantity_cancelled) quantity_left,
                                     pl.po_line_id
                                FROM po_lines_v pl, po_line_locations_v pll
                               WHERE pl.po_line_id = pll.po_line_id) calc_quantity
                       WHERE calc_quantity.po_line_id = plv.po_line_id
                      /*AND quantity_left > 0*/
                      ) quantity_line,
                     (pllv.quantity - pllv.quantity_billed -
                     pllv.quantity_cancelled) quantity_ship,
                     --PLLV.QUANTITY QUANTITY_SHIP,
                     0 quantity_billed_ship,
                     0 quantity_cancelled_ship,
                     (pllv.quantity_received - pllv.quantity_billed) quantity_received_ship,
                     pllv.receipt_days_exception_code receipt_days_exc_code_ship,
                     pllv.receipt_required_flag receipt_required_flag_ship,
                     pllv.receive_close_tolerance receive_close_tolerance_ship,
                     (SELECT meaning
                        FROM fnd_lookup_values_vl flvv
                       WHERE lookup_type = 'RCV_ROUTING_HEADERS'
                         AND flvv.lookup_code = pllv.receiving_routing_id) receiving_routing_ship,
                     pllv.attribute1 shipment_attribute1,
                     pllv.attribute2 shipment_attribute2,
                     pllv.attribute3 shipment_attribute3,
                     pllv.attribute4 shipment_attribute4,
                     pllv.attribute5 shipment_attribute5,
                     pllv.attribute6 shipment_attribute6,
                     pllv.attribute7 shipment_attribute7,
                     pllv.attribute8 shipment_attribute8,
                     pllv.attribute9 shipment_attribute9,
                     pllv.attribute10 shipment_attribute10,
                     pllv.attribute11 shipment_attribute11,
                     pllv.attribute12 shipment_attribute12,
                     pllv.attribute13 shipment_attribute13,
                     pllv.attribute14 shipment_attribute14,
                     pllv.attribute15 shipment_attribute15,
                     pllv.attribute_category shipment_attribute_category,
                     pllv.shipment_num shipment_num_ship,
                     pllv.shipment_type shipment_type_ship,
                     pllv.ship_to_location_code ship_to_location_ship,
                     pllv.ship_to_organization_code ship_to_org_code_ship,
                     plv.type_1099,
                     (SELECT muom.uom_code
                        FROM mtl_units_of_measure    muom,
                             mtl_units_of_measure_tl muomt
                       WHERE muom.uom_code = muomt.uom_code
                         AND muomt.LANGUAGE = userenv('LANG')
                         AND muom.unit_of_measure(+) =
                             plv.unit_meas_lookup_code
                         AND nvl(muom.disable_date, SYSDATE + 1) >= SYSDATE) unit_of_measure_line,
                     (SELECT muom.uom_code
                        FROM mtl_units_of_measure    muom,
                             mtl_units_of_measure_tl muomt
                       WHERE muom.uom_code = muomt.uom_code
                         AND muomt.LANGUAGE = userenv('LANG')
                         AND muom.unit_of_measure(+) =
                             pllv.unit_meas_lookup_code
                         AND nvl(muom.disable_date, SYSDATE + 1) >= SYSDATE) unit_of_measure_ship,
                     plv.unit_price,
                     pllv.vendor_product_num,
                     pllv.price_discount price_discount_ship,
                     --pllv.start_date,
                     phv.start_date,
                     --  pllv.end_date,
                     phv.end_date,
                     pllv.price_override,
                     pllv.lead_time lead_time_ship,
                     pllv.lead_time_unit lead_time_unit_ship,
                     plv.matching_basis,
                     pdv.accrue_on_receipt_flag accrue_on_receipt_flag_dist,
                     (SELECT gcck.concatenated_segments
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.accrual_account_id) accrual_account,
                     (SELECT segment1
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.accrual_account_id) accrual_acct_segment1,
                     (SELECT segment2
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.accrual_account_id) accrual_acct_segment2,
                     (SELECT segment3
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.accrual_account_id) accrual_acct_segment3,
                     (SELECT segment5
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.accrual_account_id) accrual_acct_segment5,
                     (SELECT segment6
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.accrual_account_id) accrual_acct_segment6,
                     (SELECT segment7
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.accrual_account_id) accrual_acct_segment7,
                     (SELECT segment10
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.accrual_account_id) accrual_acct_segment10,
                     pdv.amount_billed,
                     pdv.amount_ordered,
                     pdv.attribute1 attribute1_dist,
                     pdv.attribute2 attribute2_dist,
                     pdv.attribute3 attribute3_dist,
                     pdv.attribute4 attribute4_dist,
                     pdv.attribute5 attribute5_dist,
                     pdv.attribute6 attribute6_dist,
                     pdv.attribute7 attribute7_dist,
                     pdv.attribute8 attribute8_dist,
                     pdv.attribute9 attribute9_dist,
                     pdv.attribute10 attribute10_dist,
                     pdv.attribute11 attribute11_dist,
                     pdv.attribute12 attribute12_dist,
                     pdv.attribute13 attribute13_dist,
                     pdv.attribute14 attribute14_dist,
                     pdv.attribute15 attribute15_dist,
                     pdv.attribute_category attribute_category_dist,
                     (SELECT gcck.concatenated_segments
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id = pdv.budget_account_id) budget_account,
                     (SELECT segment1
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id = pdv.budget_account_id) budget_acct_segment1,
                     (SELECT segment2
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id = pdv.budget_account_id) budget_acct_segment2,
                     (SELECT segment3
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id = pdv.budget_account_id) budget_acct_segment3,
                     (SELECT segment5
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id = pdv.budget_account_id) budget_acct_segment5,
                     (SELECT segment6
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id = pdv.budget_account_id) budget_acct_segment6,
                     (SELECT segment7
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id = pdv.budget_account_id) budget_acct_segment7,
                     (SELECT segment10
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id = pdv.budget_account_id) budget_acct_segment10,
                     (SELECT gcck.concatenated_segments
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.code_combination_id) charge_account,
                     (SELECT segment1
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.code_combination_id) charge_acct_segment1,
                     (SELECT segment2
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.code_combination_id) charge_acct_segment2,
                     (SELECT segment3
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.code_combination_id) charge_acct_segment3,
                     (SELECT segment5
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.code_combination_id) charge_acct_segment5,
                     (SELECT segment6
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.code_combination_id) charge_acct_segment6,
                     (SELECT segment7
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.code_combination_id) charge_acct_segment7,
                     (SELECT segment10
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.code_combination_id) charge_acct_segment10,
                     (SELECT hla.location_code
                        FROM hr_locations_all hla
                       WHERE hla.bill_to_site_flag = 'Y'
                         AND hla.location_id = pdv.deliver_to_location_id) deliver_to_location,
                     (SELECT papf.full_name
                        FROM per_all_people_f papf
                       WHERE papf.person_id = pdv.deliver_to_person_id
                         AND SYSDATE BETWEEN
                             nvl(papf.effective_start_date, SYSDATE) AND
                             nvl(papf.effective_end_date, SYSDATE + 1)) deliver_to_person,
                     pdv.destination_context,
                     (SELECT organization_code
                        FROM org_organization_definitions
                       WHERE organization_id =
                             pdv.destination_organization_id) destination_organization,
                     pdv.destination_subinventory,
                     pdv.destination_type_code,
                     pdv.distribution_num,
                     pdv.encumbered_amount,
                     pdv.encumbered_flag,
                     pdv.expenditure_item_date,
                     (SELECT hou.NAME
                        FROM hr_organization_units       hou,
                             hr_organization_information hoi
                       WHERE hou.organization_id = hoi.organization_id
                         AND hou.organization_id =
                             pdv.expenditure_organization_id
                         AND trunc(SYSDATE) BETWEEN
                             nvl(trunc(hou.date_from), trunc(SYSDATE) - 1) AND
                             nvl(trunc(hou.date_to), trunc(SYSDATE) + 1)
                         AND hoi.org_information1 = 'PA_EXPENDITURE_ORG'
                         AND nvl(hoi.org_information2, 'N') = 'Y') expenditure_organization,
                     pdv.expenditure_type,
                     pdv.failed_funds_lookup_code,
                     pdv.gl_cancelled_date,
                     pdv.gl_encumbered_date,
                     pdv.gl_encumbered_period_name,
                     pdv.nonrecoverable_tax,
                     pdv.prevent_encumbrance_flag,
                     (SELECT ppa.NAME
                        FROM pa_projects_all ppa
                       WHERE ppa.project_id = pdv.project_id) project,
                     pdv.project_accounting_context, /*
                                                                                                                                                                                                                                                                                                                                                                              PDV.QUANTITY_BILLED,
                                                                                                                                                                                                                                                                                                                                                                              PDV.QUANTITY_CANCELLED,*/
                     --PDV.QUANTITY_DELIVERED
                     0 quantity_billed_dist,
                     0 quantity_cancelled_dist,
                     (pdv.quantity_ordered - pdv.quantity_billed -
                     pdv.quantity_cancelled) quantity_ordered_dist,
                     pdv.rate rate_dist,
                     pdv.rate_date rate_date_dist,
                     pdv.recoverable_tax,
                     pdv.recovery_rate,
                     pdv.task_id,
                     (SELECT gl.NAME
                        FROM gl_ledgers gl
                       WHERE gl.ledger_id = pdv.set_of_books_id) set_of_books,
                     (SELECT pt.task_name
                        FROM pa_tasks pt
                       WHERE pt.project_id = pdv.project_id
                         AND pt.task_id = pdv.task_id) task,
                     pdv.tax_recovery_override_flag,
                     (SELECT gcck.concatenated_segments
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.variance_account_id) variance_account,
                     (SELECT segment1
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.variance_account_id) variance_acct_segment1,
                     (SELECT segment2
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.variance_account_id) variance_acct_segment2,
                     (SELECT segment3
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.variance_account_id) variance_acct_segment3,
                     (SELECT segment5
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.variance_account_id) variance_acct_segment5,
                     (SELECT segment6
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.variance_account_id) variance_acct_segment6,
                     (SELECT segment7
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.variance_account_id) variance_acct_segment7,
                     (SELECT segment10
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.variance_account_id) variance_acct_segment10,
                     pllv.match_option
                FROM po_headers_v        phv,
                     po_lines_v          plv,
                     po_line_locations_v pllv,
                     po_distributions_v  pdv,
                     ap_suppliers        asp,
                     ap_supplier_sites   ass
               WHERE phv.po_header_id = plv.po_header_id
                 AND plv.po_line_id = pllv.po_line_id
                 AND pdv.line_location_id = pllv.line_location_id
                 AND nvl(phv.cancel_flag, 'N') <> 'Y'
                 AND nvl(plv.closed_date,
                         to_date('01-APR-2016', 'DD-MON-YYYY')) >=
                     to_date('01-APR-2016', 'DD-MON-YYYY')
                 AND nvl(plv.expiration_date,
                         to_date('01-APR-2016', 'DD-MON-YYYY')) >=
                     to_date('01-APR-2016', 'DD-MON-YY')
                 AND phv.vendor_id = asp.vendor_id
                 AND asp.vendor_id = ass.vendor_id
                 AND phv.vendor_site_id = ass.vendor_site_id
                 AND asp.enabled_flag = 'Y'
                 AND trunc(SYSDATE) BETWEEN trunc(asp.start_date_active) AND
                     trunc(nvl(asp.end_date_active, SYSDATE))
                 AND ass.inactive_date IS NULL
                 AND phv.org_id = l_org_id
                 AND phv.authorization_status = 'APPROVED'
                 AND nvl(plv.cancel_flag, 'N') = 'N'
                 AND nvl(upper(phv.closed_code), 'OPEN') IN
                     ('OPEN', 'CLOSED FOR INVOICE', 'CLOSED FOR RECEIVING')
                 AND upper(pllv.closed_code) NOT IN
                     ('CLOSED', 'FINALLY CLOSED')
                 AND pllv.quantity_received = 0
                 AND pllv.quantity_billed = 0
                 AND (pllv.quantity - pllv.quantity_cancelled) > 0
                 AND phv.doc_type_name IN ('Standard Purchase Order')
              --ORDER BY phv.segment1

              UNION
              --Query Scenario 2 (PO is fully received but not invoiced )

              SELECT phv.po_header_id po_header_id,
                     phv.acceptance_due_date,
                     phv.agent_name,
                     phv.agent_id,
                     phv.amount_limit,
                     phv.approved_date,
                     phv.attribute1 attribute1_hdr,
                     phv.attribute2 attribute2_hdr,
                     phv.attribute3 attribute3_hdr,
                     phv.attribute4 attribute4_hdr,
                     phv.attribute5 attribute5_hdr,
                     phv.attribute6 attribute6_hdr,
                     phv.attribute7 attribute7_hdr,
                     phv.attribute8 attribute8_hdr,
                     phv.attribute9 attribute9_hdr,
                     phv.attribute10 attribute10_hdr,
                     phv.attribute11 attribute11_hdr,
                     phv.attribute12 attribute12_hdr,
                     phv.attribute13 attribute13_hdr,
                     phv.attribute14 attribute14_hdr,
                     phv.attribute15 attribute15_hdr,
                     phv.attribute_category attribute_category_hdr,
                     phv.bill_to_location,
                     phv.change_summary,
                     phv.currency_code,
                     phv.segment1,
                     --phv.DOCUMENT_TYPE_CODE,
                     --phv.doc_type_name,
                     phv.type_lookup_code doc_type_name,
                     --phv.DOCUMENT_SUBTYPE,
                     --phv.EFFECTIVE_DATE,
                     phv.creation_date_disp, --need to verify
                     phv.ship_via_lookup_code freight_carrier_hdr,
                     phv.fob_lookup_code fob_hdr, --new field
                     phv.freight_terms_dsp freight_terms_hdr,
                     phv.global_agreement_flag,
                     phv.min_release_amount min_release_amount_hdr,
                     phv.note_to_receiver note_to_receiver_hdr,
                     phv.note_to_vendor note_to_vendor_hdr,
                     (SELECT hou .NAME
                        FROM hr_operating_units hou
                       WHERE hou.organization_id = phv.org_id) operating_unit_name,
                     payment_terms payment_terms_hdr,
                     phv.printed_date,
                     phv.print_count,
                     /*decode((SELECT currency_code FROM gl_ledgers WHERE ledger_id = pdv.set_of_books_id),phv.currency_code,NULL,phv.rate) rate_hdr,
                                                                                                                                                                                                                                       decode((SELECT currency_code FROM gl_ledgers WHERE ledger_id = pdv.set_of_books_id),phv.currency_code,NULL,phv.rate_date) rate_date_hdr,
                                                                                                                                                                                                                                       decode((SELECT currency_code FROM gl_ledgers WHERE ledger_id = pdv.set_of_books_id),phv.currency_code,NULL,phv.rate_type) rate_type,*/
                     phv.rate rate_hdr,
                     phv.rate_date rate_date_hdr,
                     phv.rate_type,
                     phv.revised_date,
                     phv.revision_num,
                     phv.shipping_control,
                     phv.ship_to_location ship_to_location_hdr,
                     phv.vendor_contact,
                     phv.vendor_contact_id,
                     phv.vendor_name,
                     (SELECT segment1
                        FROM ap_suppliers
                       WHERE vendor_id = phv.vendor_id) vendor_num,
                     phv.vendor_site_code,
                     phv.acceptance_required_flag,
                     phv.confirming_order_flag,
                     --line and line locations
                     pllv.accrue_on_receipt_flag accrue_on_receipt_flag_ship,
                     pllv.allow_substitute_receipts_flag allow_sub_receipts_flag_ship,
                     plv.amount amount_line,
                     pllv.amount amount_ship,
                     plv.base_unit_price,
                     (SELECT concatenated_segments
                        FROM mtl_categories_b_kfv mcbk
                       WHERE mcbk.category_id = plv.category_id) category,
                     plv.committed_amount,
                     pllv.days_early_receipt_allowed days_early_rec_allowed_ship,
                     pllv.days_late_receipt_allowed days_late_receipt_allowed_ship,
                     pllv.drop_ship_flag,
                     pllv.enforce_ship_to_location_code enforce_ship_to_loc_code_ship,
                     plv.expiration_date,
                     pllv.fob_lookup_code fob_ship,
                     pllv.ship_via_lookup_code freight_carrier_ship,
                     pllv.freight_terms_lookup_code freight_terms_ship,
                     plv.hazard_class,
                     pllv.inspection_required_flag inspection_required_flag_ship,
                     pllv.invoice_close_tolerance invoice_close_tolerance_ship,
                     plv.item_number,
                     plv.item_description,
                     plv.item_revision,
                     (SELECT NAME
                        FROM per_jobs pj
                       WHERE pj.job_id = plv.job_id) job_name, --need to fetch job_name
                     plv.attribute1 line_attribute1,
                     plv.attribute2 line_attribute2,
                     plv.attribute3 line_attribute3,
                     plv.attribute4 line_attribute4,
                     plv.attribute5 line_attribute5,
                     plv.attribute6 line_attribute6,
                     plv.attribute7 line_attribute7,
                     plv.attribute8 line_attribute8,
                     plv.attribute9 line_attribute9,
                     plv.attribute10 line_attribute10,
                     plv.attribute11 line_attribute11,
                     plv.attribute12 line_attribute12,
                     plv.attribute13 line_attribute13,
                     plv.attribute14 line_attribute14,
                     plv.attribute15 line_attribute15,
                     plv.attribute_category line_attribute_category_lines,
                     plv.price_type,
                     plv.allow_price_override_flag,
                     plv.un_number,
                     plv.capital_expense_flag,
                     plv.transaction_reason_code,
                     plv.quantity_committed,
                     plv.not_to_exceed_price,
                     plv.line_num,
                     plv.line_type,
                     plv.list_price_per_unit,
                     plv.market_price,
                     plv.min_release_amount min_release_amount_line,
                     pllv.need_by_date need_by_date_ship,
                     plv.negotiated_by_preparer_flag,
                     pllv.note_to_receiver note_to_receiver_ship,
                     plv.note_to_vendor note_to_vendor_line,
                     plv.over_tolerance_error_flag,
                     pllv.payment_terms_name payment_terms_ship,
                     plv.preferred_grade preferred_grade_line,
                     plv.preferred_grade preferred_grade_ship,
                     plv.price_break_lookup_code,
                     pllv.promised_date promised_date_ship,
                     --QTY_RCV_EXCEPTION_CODE_LINE ,
                     pllv.qty_rcv_exception_code qty_rcv_exception_code_ship,
                     plv.qty_rcv_tolerance       qty_rcv_tolerance_line,
                     pllv.qty_rcv_tolerance      qty_rcv_tolerance_ship,
                     /*(PLV.QUANTITY - PLLV.QUANTITY_CANCELLED) QUANTITY_LINE,
                                                                                                                                                                                                                                                                                                                                                                              PLLV.QUANTITY QUANTITY_SHIP,*/
                     (SELECT SUM(quantity_left)
                        FROM (SELECT (pll.quantity - pll.quantity_billed -
                                     pll.quantity_cancelled) quantity_left,
                                     pl.po_line_id
                                FROM po_lines_v pl, po_line_locations_v pll
                               WHERE pl.po_line_id = pll.po_line_id) calc_quantity
                       WHERE calc_quantity.po_line_id = plv.po_line_id
                         AND quantity_left > 0) quantity_line,
                     (pllv.quantity - pllv.quantity_billed -
                     pllv.quantity_cancelled) quantity_ship,
                     0 quantity_billed_ship,
                     0 quantity_cancelled_ship,
                     (pllv.quantity_received - pllv.quantity_billed) quantity_received_ship,
                     pllv.receipt_days_exception_code receipt_days_exc_code_ship,
                     pllv.receipt_required_flag receipt_required_flag_ship,
                     pllv.receive_close_tolerance receive_close_tolerance_ship,
                     (SELECT meaning
                        FROM fnd_lookup_values_vl flvv
                       WHERE lookup_type = 'RCV_ROUTING_HEADERS'
                         AND flvv.lookup_code = pllv.receiving_routing_id) receiving_routing_ship,
                     pllv.attribute1 shipment_attribute1,
                     pllv.attribute2 shipment_attribute2,
                     pllv.attribute3 shipment_attribute3,
                     pllv.attribute4 shipment_attribute4,
                     pllv.attribute5 shipment_attribute5,
                     pllv.attribute6 shipment_attribute6,
                     pllv.attribute7 shipment_attribute7,
                     pllv.attribute8 shipment_attribute8,
                     pllv.attribute9 shipment_attribute9,
                     pllv.attribute10 shipment_attribute10,
                     pllv.attribute11 shipment_attribute11,
                     pllv.attribute12 shipment_attribute12,
                     pllv.attribute13 shipment_attribute13,
                     pllv.attribute14 shipment_attribute14,
                     pllv.attribute15 shipment_attribute15,
                     pllv.attribute_category shipment_attribute_category,
                     pllv.shipment_num shipment_num_ship,
                     pllv.shipment_type shipment_type_ship,
                     pllv.ship_to_location_code ship_to_location_ship,
                     pllv.ship_to_organization_code ship_to_org_code_ship,
                     plv.type_1099,
                     (SELECT muom.uom_code
                        FROM mtl_units_of_measure    muom,
                             mtl_units_of_measure_tl muomt
                       WHERE muom.uom_code = muomt.uom_code
                         AND muomt.LANGUAGE = userenv('LANG')
                         AND muom.unit_of_measure(+) =
                             plv.unit_meas_lookup_code
                         AND nvl(muom.disable_date, SYSDATE + 1) >= SYSDATE) unit_of_measure_line,
                     (SELECT muom.uom_code
                        FROM mtl_units_of_measure    muom,
                             mtl_units_of_measure_tl muomt
                       WHERE muom.uom_code = muomt.uom_code
                         AND muomt.LANGUAGE = userenv('LANG')
                         AND muom.unit_of_measure(+) =
                             pllv.unit_meas_lookup_code
                         AND nvl(muom.disable_date, SYSDATE + 1) >= SYSDATE) unit_of_measure_ship,
                     plv.unit_price,
                     pllv.vendor_product_num,
                     pllv.price_discount price_discount_ship,
                     --pllv.start_date,
                     phv.start_date,
                     --pllv.end_date,
                     phv.end_date,
                     pllv.price_override,
                     pllv.lead_time lead_time_ship,
                     pllv.lead_time_unit lead_time_unit_ship,
                     plv.matching_basis,
                     pdv.accrue_on_receipt_flag accrue_on_receipt_flag_dist,
                     (SELECT gcck.concatenated_segments
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.accrual_account_id) accrual_account,
                     (SELECT segment1
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.accrual_account_id) accrual_acct_segment1,
                     (SELECT segment2
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.accrual_account_id) accrual_acct_segment2,
                     (SELECT segment3
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.accrual_account_id) accrual_acct_segment3,
                     (SELECT segment5
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.accrual_account_id) accrual_acct_segment5,
                     (SELECT segment6
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.accrual_account_id) accrual_acct_segment6,
                     (SELECT segment7
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.accrual_account_id) accrual_acct_segment7,
                     (SELECT segment10
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.accrual_account_id) accrual_acct_segment10,
                     pdv.amount_billed,
                     pdv.amount_ordered,
                     pdv.attribute1 attribute1_dist,
                     pdv.attribute2 attribute2_dist,
                     pdv.attribute3 attribute3_dist,
                     pdv.attribute4 attribute4_dist,
                     pdv.attribute5 attribute5_dist,
                     pdv.attribute6 attribute6_dist,
                     pdv.attribute7 attribute7_dist,
                     pdv.attribute8 attribute8_dist,
                     pdv.attribute9 attribute9_dist,
                     pdv.attribute10 attribute10_dist,
                     pdv.attribute11 attribute11_dist,
                     pdv.attribute12 attribute12_dist,
                     pdv.attribute13 attribute13_dist,
                     pdv.attribute14 attribute14_dist,
                     pdv.attribute15 attribute15_dist,
                     pdv.attribute_category attribute_category_dist,
                     (SELECT gcck.concatenated_segments
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id = pdv.budget_account_id) budget_account,
                     (SELECT segment1
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id = pdv.budget_account_id) budget_acct_segment1,
                     (SELECT segment2
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id = pdv.budget_account_id) budget_acct_segment2,
                     (SELECT segment3
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id = pdv.budget_account_id) budget_acct_segment3,
                     (SELECT segment5
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id = pdv.budget_account_id) budget_acct_segment5,
                     (SELECT segment6
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id = pdv.budget_account_id) budget_acct_segment6,
                     (SELECT segment7
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id = pdv.budget_account_id) budget_acct_segment7,
                     (SELECT segment10
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id = pdv.budget_account_id) budget_acct_segment10,
                     (SELECT gcck.concatenated_segments
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.code_combination_id) charge_account,
                     (SELECT segment1
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.code_combination_id) charge_acct_segment1,
                     (SELECT segment2
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.code_combination_id) charge_acct_segment2,
                     (SELECT segment3
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.code_combination_id) charge_acct_segment3,
                     (SELECT segment5
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.code_combination_id) charge_acct_segment5,
                     (SELECT segment6
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.code_combination_id) charge_acct_segment6,
                     (SELECT segment7
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.code_combination_id) charge_acct_segment7,
                     (SELECT segment10
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.code_combination_id) charge_acct_segment10,
                     (SELECT hla.location_code
                        FROM hr_locations_all hla
                       WHERE hla.bill_to_site_flag = 'Y'
                         AND hla.location_id = pdv.deliver_to_location_id) deliver_to_location,
                     (SELECT papf.full_name
                        FROM per_all_people_f papf
                       WHERE papf.person_id = pdv.deliver_to_person_id
                         AND SYSDATE BETWEEN
                             nvl(papf.effective_start_date, SYSDATE) AND
                             nvl(papf.effective_end_date, SYSDATE + 1)) deliver_to_person,
                     pdv.destination_context,
                     (SELECT organization_code
                        FROM org_organization_definitions
                       WHERE organization_id =
                             pdv.destination_organization_id) destination_organization,
                     pdv.destination_subinventory,
                     pdv.destination_type_code,
                     pdv.distribution_num,
                     pdv.encumbered_amount,
                     pdv.encumbered_flag,
                     pdv.expenditure_item_date,
                     (SELECT hou.NAME
                        FROM hr_organization_units       hou,
                             hr_organization_information hoi
                       WHERE hou.organization_id = hoi.organization_id
                         AND hou.organization_id =
                             pdv.expenditure_organization_id
                         AND trunc(SYSDATE) BETWEEN
                             nvl(trunc(hou.date_from), trunc(SYSDATE) - 1) AND
                             nvl(trunc(hou.date_to), trunc(SYSDATE) + 1)
                         AND hoi.org_information1 = 'PA_EXPENDITURE_ORG'
                         AND nvl(hoi.org_information2, 'N') = 'Y') expenditure_organization,
                     pdv.expenditure_type,
                     pdv.failed_funds_lookup_code,
                     pdv.gl_cancelled_date,
                     pdv.gl_encumbered_date,
                     pdv.gl_encumbered_period_name,
                     pdv.nonrecoverable_tax,
                     pdv.prevent_encumbrance_flag,
                     (SELECT ppa.NAME
                        FROM pa_projects_all ppa
                       WHERE ppa.project_id = pdv.project_id) project,
                     pdv.project_accounting_context,
                     /*PDV.QUANTITY_BILLED,
                                                                                                                                                                                                                                                                                                                                                                              PDV.QUANTITY_CANCELLED,
                                                                                                                                                                                                                                                                                                                                                                              --PDV.QUANTITY_DELIVERED
                                                                                                                                                                                                                                                                                                                                                                              PDV.QUANTITY_ORDERED_DIST,*/
                     0 quantity_billed_dist,
                     0 quantity_cancelled_dist,
                     (pdv.quantity_ordered - pdv.quantity_billed -
                     pdv.quantity_cancelled) quantity_ordered_dist,
                     /*decode((SELECT currency_code FROM gl_ledgers WHERE ledger_id = pdv.set_of_books_id),phv.currency_code,NULL,pdv.rate) rate_dist,
                                                                                                                                                                                                                                       decode((SELECT currency_code FROM gl_ledgers WHERE ledger_id = pdv.set_of_books_id),phv.currency_code,NULL,pdv.rate_date) rate_date_dist,*/
                     pdv.rate rate_dist,
                     pdv.rate_date rate_date_dist,
                     pdv.recoverable_tax,
                     pdv.recovery_rate,
                     pdv.task_id,
                     (SELECT gl.NAME
                        FROM gl_ledgers gl
                       WHERE gl.ledger_id = pdv.set_of_books_id) set_of_books,
                     (SELECT pt.task_name
                        FROM pa_tasks pt
                       WHERE pt.project_id = pdv.project_id
                         AND pt.task_id = pdv.task_id) task,
                     pdv.tax_recovery_override_flag,
                     (SELECT gcck.concatenated_segments
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.variance_account_id) variance_account,
                     (SELECT segment1
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.variance_account_id) variance_acct_segment1,
                     (SELECT segment2
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.variance_account_id) variance_acct_segment2,
                     (SELECT segment3
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.variance_account_id) variance_acct_segment3,
                     (SELECT segment5
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.variance_account_id) variance_acct_segment5,
                     (SELECT segment6
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.variance_account_id) variance_acct_segment6,
                     (SELECT segment7
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.variance_account_id) variance_acct_segment7,
                     (SELECT segment10
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.variance_account_id) variance_acct_segment10,
                     pllv.match_option
                FROM po_headers_v        phv,
                     po_lines_v          plv,
                     po_line_locations_v pllv,
                     po_distributions_v  pdv,
                     ap_suppliers        asp,
                     ap_supplier_sites   ass
               WHERE phv.po_header_id = plv.po_header_id
                 AND plv.po_line_id = pllv.po_line_id
                 AND pdv.line_location_id = pllv.line_location_id
                 AND nvl(phv.cancel_flag, 'N') <> 'Y'
                 AND nvl(plv.closed_date,
                         to_date('01-APR-2016', 'DD-MON-YYYY')) >=
                     to_date('01-APR-2016', 'DD-MON-YYYY')
                 AND nvl(plv.expiration_date,
                         to_date('01-APR-2016', 'DD-MON-YYYY')) >=
                     to_date('01-APR-2016', 'DD-MON-YY')
                 AND phv.vendor_id = asp.vendor_id
                 AND asp.vendor_id = ass.vendor_id
                 AND phv.vendor_site_id = ass.vendor_site_id
                 AND asp.enabled_flag = 'Y'
                 AND trunc(SYSDATE) BETWEEN trunc(asp.start_date_active) AND
                     trunc(nvl(asp.end_date_active, SYSDATE))
                 AND ass.inactive_date IS NULL
                 AND phv.org_id = l_org_id
                 AND phv.authorization_status = 'APPROVED'
                 AND nvl(plv.cancel_flag, 'N') = 'N'
                 AND nvl(upper(phv.closed_code), 'OPEN') IN
                     ('OPEN', 'CLOSED FOR INVOICE', 'CLOSED FOR RECEIVING')
                 AND upper(pllv.closed_code) NOT IN
                     ('CLOSED', 'FINALLY CLOSED')
                 AND pllv.quantity_received = pllv.quantity
                 AND pllv.quantity_billed = 0
                 AND (pllv.quantity - pllv.quantity_cancelled) > 0
                 AND phv.doc_type_name IN ('Standard Purchase Order')
              --ORDER BY phv.segment1

              --UNION

              --Query Scenario 4

              /*SELECT PHV.PO_HEADER_ID PO_HEADER_ID,
                                                                                                                                                                                                                                               PHV.ACCEPTANCE_DUE_DATE,
                                                                                                                                                                                                                                               PHV.AGENT_NAME,
                                                                                                                                                                                                                                               PHV.AGENT_ID,
                                                                                                                                                                                                                                               PHV.AMOUNT_LIMIT,
                                                                                                                                                                                                                                               PHV.APPROVED_DATE,
                                                                                                                                                                                                                                               PHV.ATTRIBUTE1 ATTRIBUTE1_HDR,
                                                                                                                                                                                                                                               PHV.ATTRIBUTE2 ATTRIBUTE2_HDR,
                                                                                                                                                                                                                                               PHV.ATTRIBUTE3 ATTRIBUTE3_HDR,
                                                                                                                                                                                                                                               PHV.ATTRIBUTE4 ATTRIBUTE4_HDR,
                                                                                                                                                                                                                                               PHV.ATTRIBUTE5 ATTRIBUTE5_HDR,
                                                                                                                                                                                                                                               PHV.ATTRIBUTE6 ATTRIBUTE6_HDR,
                                                                                                                                                                                                                                               PHV.ATTRIBUTE7 ATTRIBUTE7_HDR,
                                                                                                                                                                                                                                               PHV.ATTRIBUTE8 ATTRIBUTE8_HDR,
                                                                                                                                                                                                                                               PHV.ATTRIBUTE9 ATTRIBUTE9_HDR,
                                                                                                                                                                                                                                               PHV.ATTRIBUTE10 ATTRIBUTE10_HDR,
                                                                                                                                                                                                                                               PHV.ATTRIBUTE11 ATTRIBUTE11_HDR,
                                                                                                                                                                                                                                               PHV.ATTRIBUTE12 ATTRIBUTE12_HDR,
                                                                                                                                                                                                                                               PHV.ATTRIBUTE13 ATTRIBUTE13_HDR,
                                                                                                                                                                                                                                               PHV.ATTRIBUTE14 ATTRIBUTE14_HDR,
                                                                                                                                                                                                                                               PHV.ATTRIBUTE15 ATTRIBUTE15_HDR,
                                                                                                                                                                                                                                               PHV.ATTRIBUTE_CATEGORY ATTRIBUTE_CATEGORY_HDR,
                                                                                                                                                                                                                                               PHV.BILL_TO_LOCATION,
                                                                                                                                                                                                                                               PHV.CHANGE_SUMMARY,
                                                                                                                                                                                                                                               PHV.CURRENCY_CODE,
                                                                                                                                                                                                                                               PHV.SEGMENT1,
                                                                                                                                                                                                                                               --phv.DOCUMENT_TYPE_CODE,
                                                                                                                                                                                                                                               PHV.DOC_TYPE_NAME,
                                                                                                                                                                                                                                               --phv.DOCUMENT_SUBTYPE,
                                                                                                                                                                                                                                               --phv.EFFECTIVE_DATE,
                                                                                                                                                                                                                                               PHV.CREATION_DATE_DISP, --need to verify
                                                                                                                                                                                                                                               PHV.SHIP_VIA_LOOKUP_CODE FREIGHT_CARRIER_HDR,
                                                                                                                                                                                                                                               PHV.FOB_LOOKUP_CODE FOB_HDR, --new field
                                                                                                                                                                                                                                               PHV.FREIGHT_TERMS_DSP FREIGHT_TERMS_HDR,
                                                                                                                                                                                                                                               PHV.GLOBAL_AGREEMENT_FLAG,
                                                                                                                                                                                                                                               PHV.MIN_RELEASE_AMOUNT MIN_RELEASE_AMOUNT_HDR,
                                                                                                                                                                                                                                               PHV.NOTE_TO_RECEIVER NOTE_TO_RECEIVER_HDR,
                                                                                                                                                                                                                                               PHV.NOTE_TO_VENDOR NOTE_TO_VENDOR_HDR,
                                                                                                                                                                                                                                               (SELECT HOU .NAME
                                                                                                                                                                                                                                                  FROM HR_OPERATING_UNITS HOU
                                                                                                                                                                                                                                                 WHERE HOU.ORGANIZATION_ID = PHV.ORG_ID) OPERATING_UNIT_NAME,
                                                                                                                                                                                                                                               PAYMENT_TERMS PAYMENT_TERMS_HDR,
                                                                                                                                                                                                                                               PHV.PRINTED_DATE,
                                                                                                                                                                                                                                               PHV.PRINT_COUNT,
                                                                                                                                                                                                                                               PHV.RATE RATE_HDR,
                                                                                                                                                                                                                                               PHV.RATE_DATE RATE_DATE_HDR,
                                                                                                                                                                                                                                               PHV.RATE_TYPE,
                                                                                                                                                                                                                                               PHV.REVISED_DATE,
                                                                                                                                                                                                                                               PHV.REVISION_NUM,
                                                                                                                                                                                                                                               PHV.SHIPPING_CONTROL,
                                                                                                                                                                                                                                               PHV.SHIP_TO_LOCATION SHIP_TO_LOCATION_HDR,
                                                                                                                                                                                                                                               PHV.VENDOR_CONTACT,
                                                                                                                                                                                                                                               PHV.VENDOR_NAME,
                                                                                                                                                                                                                                               (SELECT SEGMENT1
                                                                                                                                                                                                                                                  FROM AP_SUPPLIERS
                                                                                                                                                                                                                                                 WHERE VENDOR_ID = PHV.VENDOR_ID) VENDOR_NUM,
                                                                                                                                                                                                                                               PHV.VENDOR_SITE_CODE,
                                                                                                                                                                                                                                               PHV.ACCEPTANCE_REQUIRED_FLAG,
                                                                                                                                                                                                                                               PHV.CONFIRMING_ORDER_FLAG,
                                                                                                                                                                                                                                               --line and line locations
                                                                                                                                                                                                                                               PLLV.ACCRUE_ON_RECEIPT_FLAG ACCRUE_ON_RECEIPT_FLAG_SHIP,
                                                                                                                                                                                                                                               PLLV.ALLOW_SUBSTITUTE_RECEIPTS_FLAG ALLOW_SUB_RECEIPTS_FLAG_SHIP,
                                                                                                                                                                                                                                               PLV.AMOUNT AMOUNT_LINE,
                                                                                                                                                                                                                                               PLLV.AMOUNT AMOUNT_SHIP,
                                                                                                                                                                                                                                               PLV.BASE_UNIT_PRICE,
                                                                                                                                                                                                                                               (SELECT CONCATENATED_SEGMENTS
                                                                                                                                                                                                                                                  FROM MTL_CATEGORIES_B_KFV MCBK
                                                                                                                                                                                                                                                 WHERE MCBK.CATEGORY_ID = PLV.CATEGORY_ID) CATEGORY,
                                                                                                                                                                                                                                               PLV.COMMITTED_AMOUNT,
                                                                                                                                                                                                                                               PLLV.DAYS_EARLY_RECEIPT_ALLOWED DAYS_EARLY_REC_ALLOWED_SHIP,
                                                                                                                                                                                                                                               PLLV.DAYS_LATE_RECEIPT_ALLOWED DAYS_LATE_RECEIPT_ALLOWED_SHIP,
                                                                                                                                                                                                                                               PLLV.DROP_SHIP_FLAG,
                                                                                                                                                                                                                                               PLLV.ENFORCE_SHIP_TO_LOCATION_CODE ENFORCE_SHIP_TO_LOC_CODE_SHIP,
                                                                                                                                                                                                                                               PLV.EXPIRATION_DATE,
                                                                                                                                                                                                                                               PLLV.FOB_LOOKUP_CODE FOB_SHIP,
                                                                                                                                                                                                                                               PLLV.SHIP_VIA_LOOKUP_CODE FREIGHT_CARRIER_SHIP,
                                                                                                                                                                                                                                               PLLV.FREIGHT_TERMS_LOOKUP_CODE FREIGHT_TERMS_SHIP,
                                                                                                                                                                                                                                               PLV.HAZARD_CLASS,
                                                                                                                                                                                                                                               PLLV.INSPECTION_REQUIRED_FLAG INSPECTION_REQUIRED_FLAG_SHIP,
                                                                                                                                                                                                                                               PLLV.INVOICE_CLOSE_TOLERANCE INVOICE_CLOSE_TOLERANCE_SHIP,
                                                                                                                                                                                                                                               PLV.ITEM_NUMBER,
                                                                                                                                                                                                                                               PLV.ITEM_DESCRIPTION,
                                                                                                                                                                                                                                               PLV.ITEM_REVISION,
                                                                                                                                                                                                                                               (SELECT NAME FROM PER_JOBS PJ WHERE PJ.JOB_ID = PLV.JOB_ID) JOB_NAME,
                                                                                                                                                                                                                                               PLV.ATTRIBUTE1 LINE_ATTRIBUTE1,
                                                                                                                                                                                                                                               PLV.ATTRIBUTE2 LINE_ATTRIBUTE2,
                                                                                                                                                                                                                                               PLV.ATTRIBUTE3 LINE_ATTRIBUTE3,
                                                                                                                                                                                                                                               PLV.ATTRIBUTE4 LINE_ATTRIBUTE4,
                                                                                                                                                                                                                                               PLV.ATTRIBUTE5 LINE_ATTRIBUTE5,
                                                                                                                                                                                                                                               PLV.ATTRIBUTE6 LINE_ATTRIBUTE6,
                                                                                                                                                                                                                                               PLV.ATTRIBUTE7 LINE_ATTRIBUTE7,
                                                                                                                                                                                                                                               PLV.ATTRIBUTE8 LINE_ATTRIBUTE8,
                                                                                                                                                                                                                                               PLV.ATTRIBUTE9 LINE_ATTRIBUTE9,
                                                                                                                                                                                                                                               PLV.ATTRIBUTE10 LINE_ATTRIBUTE10,
                                                                                                                                                                                                                                               PLV.ATTRIBUTE11 LINE_ATTRIBUTE11,
                                                                                                                                                                                                                                               PLV.ATTRIBUTE12 LINE_ATTRIBUTE12,
                                                                                                                                                                                                                                               PLV.ATTRIBUTE13 LINE_ATTRIBUTE13,
                                                                                                                                                                                                                                               PLV.ATTRIBUTE14 LINE_ATTRIBUTE14,
                                                                                                                                                                                                                                               PLV.ATTRIBUTE15 LINE_ATTRIBUTE15,
                                                                                                                                                                                                                                               PLV.ATTRIBUTE_CATEGORY LINE_ATTRIBUTE_CATEGORY_LINES,
                                                                                                                                                                                                                                               PLV.PRICE_TYPE,
                                                                                                                                                                                                                                               PLV.ALLOW_PRICE_OVERRIDE_FLAG,
                                                                                                                                                                                                                                               PLV.UN_NUMBER,
                                                                                                                                                                                                                                               PLV.CAPITAL_EXPENSE_FLAG,
                                                                                                                                                                                                                                               PLV.TRANSACTION_REASON_CODE,
                                                                                                                                                                                                                                               ----PLV.QUANTITY_COMMITTED,
                                                                                                                                                                                                                                               PLV.NOT_TO_EXCEED_PRICE,
                                                                                                                                                                                                                                               PLV.LINE_NUM,
                                                                                                                                                                                                                                               PLV.LINE_TYPE,
                                                                                                                                                                                                                                               PLV.LIST_PRICE_PER_UNIT,
                                                                                                                                                                                                                                               PLV.MARKET_PRICE,
                                                                                                                                                                                                                                               PLV.MIN_RELEASE_AMOUNT MIN_RELEASE_AMOUNT_LINE,
                                                                                                                                                                                                                                               PLLV.NEED_BY_DATE NEED_BY_DATE_SHIP,
                                                                                                                                                                                                                                               PLV.NEGOTIATED_BY_PREPARER_FLAG,
                                                                                                                                                                                                                                               PLLV.NOTE_TO_RECEIVER NOTE_TO_RECEIVER_SHIP,
                                                                                                                                                                                                                                               PLV.NOTE_TO_VENDOR NOTE_TO_VENDOR_LINE,
                                                                                                                                                                                                                                               PLV.OVER_TOLERANCE_ERROR_FLAG,
                                                                                                                                                                                                                                               PLLV.PAYMENT_TERMS_NAME PAYMENT_TERMS_SHIP,
                                                                                                                                                                                                                                               PLV.PREFERRED_GRADE PREFERRED_GRADE_LINE,
                                                                                                                                                                                                                                               PLV.PREFERRED_GRADE PREFERRED_GRADE_SHIP,
                                                                                                                                                                                                                                               PLV.PRICE_BREAK_LOOKUP_CODE,
                                                                                                                                                                                                                                               PLLV.PROMISED_DATE PROMISED_DATE_SHIP,
                                                                                                                                                                                                                                               --QTY_RCV_EXCEPTION_CODE_LINE ,
                                                                                                                                                                                                                                               PLLV.QTY_RCV_EXCEPTION_CODE QTY_RCV_EXCEPTION_CODE_SHIP,
                                                                                                                                                                                                                                               PLV.QTY_RCV_TOLERANCE       QTY_RCV_TOLERANCE_LINE,
                                                                                                                                                                                                                                               PLLV.QTY_RCV_TOLERANCE      QTY_RCV_TOLERANCE_SHIP,
                                                                                                                                                                                                                                               \*(PLV.QUANTITY - PLLV.QUANTITY_CANCELLED) QUANTITY_LINE,
                                                                                                                                                                                                                                                              PLLV.QUANTITY QUANTITY_SHIP,*\
                                                                                                                                                                                                                                               (SELECT SUM(QUANTITY_LEFT)
                                                                                                                                                                                                                                                  FROM (SELECT (PL.QUANTITY - PLL.QUANTITY_BILLED -
                                                                                                                                                                                                                                                               PLL.QUANTITY_CANCELLED) QUANTITY_LEFT,
                                                                                                                                                                                                                                                               PL.PO_LINE_ID
                                                                                                                                                                                                                                                          FROM PO_LINES_V PL, PO_LINE_LOCATIONS_V PLL
                                                                                                                                                                                                                                                         WHERE PL.PO_LINE_ID = PLL.PO_LINE_ID) CALC_QUANTITY
                                                                                                                                                                                                                                                 WHERE CALC_QUANTITY.PO_LINE_ID = PLV.PO_LINE_ID
                                                                                                                                                                                                                                                   AND QUANTITY_LEFT > 0) QUANTITY_LINE,
                                                                                                                                                                                                                                               (PLV.QUANTITY - PLLV.QUANTITY_BILLED -
                                                                                                                                                                                                                                               PLLV.QUANTITY_CANCELLED) QUANTITY_SHIP,
                                                                                                                                                                                                                                               0 QUANTITY_BILLED_SHIP,
                                                                                                                                                                                                                                               0 QUANTITY_CANCELLED_SHIP,
                                                                                                                                                                                                                                               (PLLV.QUANTITY_RECEIVED - PLLV.QUANTITY_BILLED) QUANTITY_RECEIVED_SHIP,
                                                                                                                                                                                                                                               PLLV.RECEIPT_DAYS_EXCEPTION_CODE RECEIPT_DAYS_EXC_CODE_SHIP,
                                                                                                                                                                                                                                               PLLV.RECEIPT_REQUIRED_FLAG RECEIPT_REQUIRED_FLAG_SHIP,
                                                                                                                                                                                                                                               PLLV.RECEIVE_CLOSE_TOLERANCE RECEIVE_CLOSE_TOLERANCE_SHIP,
                                                                                                                                                                                                                                               (SELECT MEANING
                                                                                                                                                                                                                                                  FROM FND_LOOKUP_VALUES_VL FLVV
                                                                                                                                                                                                                                                 WHERE LOOKUP_TYPE = 'RCV_ROUTING_HEADERS'
                                                                                                                                                                                                                                                   AND FLVV.LOOKUP_CODE = PLLV.RECEIVING_ROUTING_ID) RECEIVING_ROUTING_SHIP,
                                                                                                                                                                                                                                               PLLV.ATTRIBUTE1 SHIPMENT_ATTRIBUTE1,
                                                                                                                                                                                                                                               PLLV.ATTRIBUTE2 SHIPMENT_ATTRIBUTE2,
                                                                                                                                                                                                                                               PLLV.ATTRIBUTE3 SHIPMENT_ATTRIBUTE3,
                                                                                                                                                                                                                                               PLLV.ATTRIBUTE4 SHIPMENT_ATTRIBUTE4,
                                                                                                                                                                                                                                               PLLV.ATTRIBUTE5 SHIPMENT_ATTRIBUTE5,
                                                                                                                                                                                                                                               PLLV.ATTRIBUTE6 SHIPMENT_ATTRIBUTE6,
                                                                                                                                                                                                                                               PLLV.ATTRIBUTE7 SHIPMENT_ATTRIBUTE7,
                                                                                                                                                                                                                                               PLLV.ATTRIBUTE8 SHIPMENT_ATTRIBUTE8,
                                                                                                                                                                                                                                               PLLV.ATTRIBUTE9 SHIPMENT_ATTRIBUTE9,
                                                                                                                                                                                                                                               PLLV.ATTRIBUTE10 SHIPMENT_ATTRIBUTE10,
                                                                                                                                                                                                                                               PLLV.ATTRIBUTE11 SHIPMENT_ATTRIBUTE11,
                                                                                                                                                                                                                                               PLLV.ATTRIBUTE12 SHIPMENT_ATTRIBUTE12,
                                                                                                                                                                                                                                               PLLV.ATTRIBUTE13 SHIPMENT_ATTRIBUTE13,
                                                                                                                                                                                                                                               PLLV.ATTRIBUTE14 SHIPMENT_ATTRIBUTE14,
                                                                                                                                                                                                                                               PLLV.ATTRIBUTE15 SHIPMENT_ATTRIBUTE15,
                                                                                                                                                                                                                                               PLLV.ATTRIBUTE_CATEGORY SHIPMENT_ATTRIBUTE_CATEGORY,
                                                                                                                                                                                                                                               PLLV.SHIPMENT_NUM SHIPMENT_NUM_SHIP,
                                                                                                                                                                                                                                               PLLV.SHIPMENT_TYPE SHIPMENT_TYPE_SHIP,
                                                                                                                                                                                                                                               PLLV.SHIP_TO_LOCATION_CODE SHIP_TO_LOCATION_SHIP,
                                                                                                                                                                                                                                               PLLV.SHIP_TO_ORGANIZATION_CODE SHIP_TO_ORG_CODE_SHIP,
                                                                                                                                                                                                                                               PLV.TYPE_1099,
                                                                                                                                                                                                                                               --UNIT_OF_MEASURE_LINE  ,
                                                                                                                                                                                                                                               --UNIT_OF_MEASURE_SHIP  ,
                                                                                                                                                                                                                                               PLLV.UNIT_PRICE,
                                                                                                                                                                                                                                               PLLV.VENDOR_PRODUCT_NUM,
                                                                                                                                                                                                                                               PLLV.PRICE_DISCOUNT PRICE_DISCOUNT_SHIP,
                                                                                                                                                                                                                                               PLLV.START_DATE,
                                                                                                                                                                                                                                               PLLV.END_DATE,
                                                                                                                                                                                                                                               PLLV.PRICE_OVERRIDE,
                                                                                                                                                                                                                                               PLLV.LEAD_TIME LEAD_TIME_SHIP,
                                                                                                                                                                                                                                               PLLV.LEAD_TIME_UNIT LEAD_TIME_UNIT_SHIP,
                                                                                                                                                                                                                                               PLV.MATCHING_BASIS,
                                                                                                                                                                                                                                               PDV.ACCRUE_ON_RECEIPT_FLAG ACCRUE_ON_RECEIPT_FLAG_DIST,
                                                                                                                                                                                                                                               (SELECT GCCK.CONCATENATED_SEGMENTS
                                                                                                                                                                                                                                                  FROM GL_CODE_COMBINATIONS_KFV GCCK
                                                                                                                                                                                                                                                 WHERE GCCK.CODE_COMBINATION_ID = PDV.ACCRUAL_ACCOUNT_ID) ACCRUAL_ACCOUNT,
                                                                                                                                                                                                                                               (SELECT SEGMENT1
                                                                                                                                                                                                                                                  FROM GL_CODE_COMBINATIONS_KFV GCCK
                                                                                                                                                                                                                                                 WHERE GCCK.CODE_COMBINATION_ID = PDV.ACCRUAL_ACCOUNT_ID) ACCRUAL_ACCT_SEGMENT1,
                                                                                                                                                                                                                                               (SELECT SEGMENT2
                                                                                                                                                                                                                                                  FROM GL_CODE_COMBINATIONS_KFV GCCK
                                                                                                                                                                                                                                                 WHERE GCCK.CODE_COMBINATION_ID = PDV.ACCRUAL_ACCOUNT_ID) ACCRUAL_ACCT_SEGMENT2,
                                                                                                                                                                                                                                               (SELECT SEGMENT3
                                                                                                                                                                                                                                                  FROM GL_CODE_COMBINATIONS_KFV GCCK
                                                                                                                                                                                                                                                 WHERE GCCK.CODE_COMBINATION_ID = PDV.ACCRUAL_ACCOUNT_ID) ACCRUAL_ACCT_SEGMENT3,
                                                                                                                                                                                                                                               (SELECT SEGMENT5
                                                                                                                                                                                                                                                  FROM GL_CODE_COMBINATIONS_KFV GCCK
                                                                                                                                                                                                                                                 WHERE GCCK.CODE_COMBINATION_ID = PDV.ACCRUAL_ACCOUNT_ID) ACCRUAL_ACCT_SEGMENT5,
                                                                                                                                                                                                                                               (SELECT SEGMENT6
                                                                                                                                                                                                                                                  FROM GL_CODE_COMBINATIONS_KFV GCCK
                                                                                                                                                                                                                                                 WHERE GCCK.CODE_COMBINATION_ID = PDV.ACCRUAL_ACCOUNT_ID) ACCRUAL_ACCT_SEGMENT6,
                                                                                                                                                                                                                                               (SELECT SEGMENT7
                                                                                                                                                                                                                                                  FROM GL_CODE_COMBINATIONS_KFV GCCK
                                                                                                                                                                                                                                                 WHERE GCCK.CODE_COMBINATION_ID = PDV.ACCRUAL_ACCOUNT_ID) ACCRUAL_ACCT_SEGMENT7,
                                                                                                                                                                                                                                               (SELECT SEGMENT10
                                                                                                                                                                                                                                                  FROM GL_CODE_COMBINATIONS_KFV GCCK
                                                                                                                                                                                                                                                 WHERE GCCK.CODE_COMBINATION_ID = PDV.ACCRUAL_ACCOUNT_ID) ACCRUAL_ACCT_SEGMENT10,
                                                                                                                                                                                                                                               PDV.AMOUNT_BILLED,
                                                                                                                                                                                                                                               PDV.AMOUNT_ORDERED,
                                                                                                                                                                                                                                               PDV.ATTRIBUTE1 ATTRIBUTE1_DIST,
                                                                                                                                                                                                                                               PDV.ATTRIBUTE2 ATTRIBUTE2_DIST,
                                                                                                                                                                                                                                               PDV.ATTRIBUTE3 ATTRIBUTE3_DIST,
                                                                                                                                                                                                                                               PDV.ATTRIBUTE4 ATTRIBUTE4_DIST,
                                                                                                                                                                                                                                               PDV.ATTRIBUTE5 ATTRIBUTE5_DIST,
                                                                                                                                                                                                                                               PDV.ATTRIBUTE6 ATTRIBUTE6_DIST,
                                                                                                                                                                                                                                               PDV.ATTRIBUTE7 ATTRIBUTE7_DIST,
                                                                                                                                                                                                                                               PDV.ATTRIBUTE8 ATTRIBUTE8_DIST,
                                                                                                                                                                                                                                               PDV.ATTRIBUTE9 ATTRIBUTE9_DIST,
                                                                                                                                                                                                                                               PDV.ATTRIBUTE10 ATTRIBUTE10_DIST,
                                                                                                                                                                                                                                               PDV.ATTRIBUTE11 ATTRIBUTE11_DIST,
                                                                                                                                                                                                                                               PDV.ATTRIBUTE12 ATTRIBUTE12_DIST,
                                                                                                                                                                                                                                               PDV.ATTRIBUTE13 ATTRIBUTE13_DIST,
                                                                                                                                                                                                                                               PDV.ATTRIBUTE14 ATTRIBUTE14_DIST,
                                                                                                                                                                                                                                               PDV.ATTRIBUTE15 ATTRIBUTE15_DIST,
                                                                                                                                                                                                                                               PDV.ATTRIBUTE_CATEGORY ATTRIBUTE_CATEGORY_DIST,
                                                                                                                                                                                                                                               (SELECT GCCK.CONCATENATED_SEGMENTS
                                                                                                                                                                                                                                                  FROM GL_CODE_COMBINATIONS_KFV GCCK
                                                                                                                                                                                                                                                 WHERE GCCK.CODE_COMBINATION_ID = PDV.BUDGET_ACCOUNT_ID) BUDGET_ACCOUNT,
                                                                                                                                                                                                                                               (SELECT SEGMENT1
                                                                                                                                                                                                                                                  FROM GL_CODE_COMBINATIONS_KFV GCCK
                                                                                                                                                                                                                                                 WHERE GCCK.CODE_COMBINATION_ID = PDV.BUDGET_ACCOUNT_ID) BUDGET_ACCT_SEGMENT1,
                                                                                                                                                                                                                                               (SELECT SEGMENT2
                                                                                                                                                                                                                                                  FROM GL_CODE_COMBINATIONS_KFV GCCK
                                                                                                                                                                                                                                                 WHERE GCCK.CODE_COMBINATION_ID = PDV.BUDGET_ACCOUNT_ID) BUDGET_ACCT_SEGMENT2,
                                                                                                                                                                                                                                               (SELECT SEGMENT3
                                                                                                                                                                                                                                                  FROM GL_CODE_COMBINATIONS_KFV GCCK
                                                                                                                                                                                                                                                 WHERE GCCK.CODE_COMBINATION_ID = PDV.BUDGET_ACCOUNT_ID) BUDGET_ACCT_SEGMENT3,
                                                                                                                                                                                                                                               (SELECT SEGMENT5
                                                                                                                                                                                                                                                  FROM GL_CODE_COMBINATIONS_KFV GCCK
                                                                                                                                                                                                                                                 WHERE GCCK.CODE_COMBINATION_ID = PDV.BUDGET_ACCOUNT_ID) BUDGET_ACCT_SEGMENT5,
                                                                                                                                                                                                                                               (SELECT SEGMENT6
                                                                                                                                                                                                                                                  FROM GL_CODE_COMBINATIONS_KFV GCCK
                                                                                                                                                                                                                                                 WHERE GCCK.CODE_COMBINATION_ID = PDV.BUDGET_ACCOUNT_ID) BUDGET_ACCT_SEGMENT6,
                                                                                                                                                                                                                                               (SELECT SEGMENT7
                                                                                                                                                                                                                                                  FROM GL_CODE_COMBINATIONS_KFV GCCK
                                                                                                                                                                                                                                                 WHERE GCCK.CODE_COMBINATION_ID = PDV.BUDGET_ACCOUNT_ID) BUDGET_ACCT_SEGMENT7,
                                                                                                                                                                                                                                               (SELECT SEGMENT10
                                                                                                                                                                                                                                                  FROM GL_CODE_COMBINATIONS_KFV GCCK
                                                                                                                                                                                                                                                 WHERE GCCK.CODE_COMBINATION_ID = PDV.BUDGET_ACCOUNT_ID) BUDGET_ACCT_SEGMENT10,
                                                                                                                                                                                                                                               (SELECT GCCK.CONCATENATED_SEGMENTS
                                                                                                                                                                                                                                                  FROM GL_CODE_COMBINATIONS_KFV GCCK
                                                                                                                                                                                                                                                 WHERE GCCK.CODE_COMBINATION_ID = PDV.CODE_COMBINATION_ID) CHARGE_ACCOUNT,
                                                                                                                                                                                                                                               (SELECT SEGMENT1
                                                                                                                                                                                                                                                  FROM GL_CODE_COMBINATIONS_KFV GCCK
                                                                                                                                                                                                                                                 WHERE GCCK.CODE_COMBINATION_ID = PDV.CODE_COMBINATION_ID) CHARGE_ACCT_SEGMENT1,
                                                                                                                                                                                                                                               (SELECT SEGMENT2
                                                                                                                                                                                                                                                  FROM GL_CODE_COMBINATIONS_KFV GCCK
                                                                                                                                                                                                                                                 WHERE GCCK.CODE_COMBINATION_ID = PDV.CODE_COMBINATION_ID) CHARGE_ACCT_SEGMENT2,
                                                                                                                                                                                                                                               (SELECT SEGMENT3
                                                                                                                                                                                                                                                  FROM GL_CODE_COMBINATIONS_KFV GCCK
                                                                                                                                                                                                                                                 WHERE GCCK.CODE_COMBINATION_ID = PDV.CODE_COMBINATION_ID) CHARGE_ACCT_SEGMENT3,
                                                                                                                                                                                                                                               (SELECT SEGMENT5
                                                                                                                                                                                                                                                  FROM GL_CODE_COMBINATIONS_KFV GCCK
                                                                                                                                                                                                                                                 WHERE GCCK.CODE_COMBINATION_ID = PDV.CODE_COMBINATION_ID) CHARGE_ACCT_SEGMENT5,
                                                                                                                                                                                                                                               (SELECT SEGMENT6
                                                                                                                                                                                                                                                  FROM GL_CODE_COMBINATIONS_KFV GCCK
                                                                                                                                                                                                                                                 WHERE GCCK.CODE_COMBINATION_ID = PDV.CODE_COMBINATION_ID) CHARGE_ACCT_SEGMENT6,
                                                                                                                                                                                                                                               (SELECT SEGMENT7
                                                                                                                                                                                                                                                  FROM GL_CODE_COMBINATIONS_KFV GCCK
                                                                                                                                                                                                                                                 WHERE GCCK.CODE_COMBINATION_ID = PDV.CODE_COMBINATION_ID) CHARGE_ACCT_SEGMENT7,
                                                                                                                                                                                                                                               (SELECT SEGMENT10
                                                                                                                                                                                                                                                  FROM GL_CODE_COMBINATIONS_KFV GCCK
                                                                                                                                                                                                                                                 WHERE GCCK.CODE_COMBINATION_ID = PDV.CODE_COMBINATION_ID) CHARGE_ACCT_SEGMENT10,
                                                                                                                                                                                                                                               (SELECT HLA.LOCATION_CODE
                                                                                                                                                                                                                                                  FROM HR_LOCATIONS_ALL HLA
                                                                                                                                                                                                                                                 WHERE HLA.BILL_TO_SITE_FLAG = 'Y'
                                                                                                                                                                                                                                                   AND HLA.LOCATION_ID = PDV.DELIVER_TO_LOCATION_ID) DELIVER_TO_LOCATION,
                                                                                                                                                                                                                                               (SELECT PAPF.FULL_NAME
                                                                                                                                                                                                                                                  FROM PER_ALL_PEOPLE_F PAPF
                                                                                                                                                                                                                                                 WHERE PAPF.PERSON_ID = PDV.DELIVER_TO_PERSON_ID
                                                                                                                                                                                                                                                   AND SYSDATE BETWEEN
                                                                                                                                                                                                                                                       NVL(PAPF.EFFECTIVE_START_DATE, SYSDATE) AND
                                                                                                                                                                                                                                                       NVL(PAPF.EFFECTIVE_END_DATE, SYSDATE + 1)) DELIVER_TO_PERSON,
                                                                                                                                                                                                                                               PDV.DESTINATION_CONTEXT,
                                                                                                                                                                                                                                               (SELECT ORGANIZATION_NAME
                                                                                                                                                                                                                                                  FROM ORG_ORGANIZATION_DEFINITIONS
                                                                                                                                                                                                                                                 WHERE ORGANIZATION_ID = PDV.DESTINATION_ORGANIZATION_ID) DESTINATION_ORGANIZATION,
                                                                                                                                                                                                                                               PDV.DESTINATION_SUBINVENTORY,
                                                                                                                                                                                                                                               PDV.DESTINATION_TYPE_CODE,
                                                                                                                                                                                                                                               PDV.DISTRIBUTION_NUM,
                                                                                                                                                                                                                                               PDV.ENCUMBERED_AMOUNT,
                                                                                                                                                                                                                                               PDV.ENCUMBERED_FLAG,
                                                                                                                                                                                                                                               PDV.EXPENDITURE_ITEM_DATE,
                                                                                                                                                                                                                                               (SELECT HOU.NAME
                                                                                                                                                                                                                                                  FROM HR_ORGANIZATION_UNITS       HOU,
                                                                                                                                                                                                                                                       HR_ORGANIZATION_INFORMATION HOI
                                                                                                                                                                                                                                                 WHERE HOU.ORGANIZATION_ID = HOI.ORGANIZATION_ID
                                                                                                                                                                                                                                                   AND HOU.ORGANIZATION_ID = PDV.EXPENDITURE_ORGANIZATION_ID
                                                                                                                                                                                                                                                   AND TRUNC(SYSDATE) BETWEEN
                                                                                                                                                                                                                                                       NVL(TRUNC(HOU.DATE_FROM), TRUNC(SYSDATE) - 1) AND
                                                                                                                                                                                                                                                       NVL(TRUNC(HOU.DATE_TO), TRUNC(SYSDATE) + 1)
                                                                                                                                                                                                                                                   AND HOI.ORG_INFORMATION1 = 'PA_EXPENDITURE_ORG'
                                                                                                                                                                                                                                                   AND NVL(HOI.ORG_INFORMATION2, 'N') = 'Y') EXPENDITURE_ORGANIZATION,
                                                                                                                                                                                                                                               PDV.EXPENDITURE_TYPE,
                                                                                                                                                                                                                                               PDV.FAILED_FUNDS_LOOKUP_CODE,
                                                                                                                                                                                                                                               PDV.GL_CANCELLED_DATE,
                                                                                                                                                                                                                                               PDV.GL_ENCUMBERED_DATE,
                                                                                                                                                                                                                                               PDV.GL_ENCUMBERED_PERIOD_NAME,
                                                                                                                                                                                                                                               PDV.NONRECOVERABLE_TAX,
                                                                                                                                                                                                                                               PDV.PREVENT_ENCUMBRANCE_FLAG,
                                                                                                                                                                                                                                               (SELECT PPA.NAME
                                                                                                                                                                                                                                                  FROM PA_PROJECTS_ALL PPA
                                                                                                                                                                                                                                                 WHERE PPA.PROJECT_ID = PDV.PROJECT_ID) PROJECT,
                                                                                                                                                                                                                                               PDV.PROJECT_ACCOUNTING_CONTEXT,
                                                                                                                                                                                                                                               \*PDV.QUANTITY_BILLED,
                                                                                                                                                                                                                                                              PDV.QUANTITY_CANCELLED,
                                                                                                                                                                                                                                                              --PDV.QUANTITY_DELIVERED
                                                                                                                                                                                                                                                              PDV.QUANTITY_ORDERED_DIST,*\
                                                                                                                                                                                                                                               0 QUANTITY_BILLED_DIST,
                                                                                                                                                                                                                                               0 QUANTITY_CANCELLED_DIST,
                                                                                                                                                                                                                                               (PDV.QUANTITY_ORDERED - PDV.QUANTITY_BILLED -
                                                                                                                                                                                                                                               PDV.QUANTITY_CANCELLED) QUANTITY_ORDERED_DIST,
                                                                                                                                                                                                                                               PDV.RATE RATE_DIST,
                                                                                                                                                                                                                                               PDV.RATE_DATE RATE_DATE_DIST,
                                                                                                                                                                                                                                               PDV.RECOVERABLE_TAX,
                                                                                                                                                                                                                                               PDV.RECOVERY_RATE,
                                                                                                                                                                                                                                               (SELECT GL.NAME
                                                                                                                                                                                                                                                  FROM GL_LEDGERS GL
                                                                                                                                                                                                                                                 WHERE GL.LEDGER_ID = PDV.SET_OF_BOOKS_ID) SET_OF_BOOKS,
                                                                                                                                                                                                                                               (SELECT PT.TASK_NAME
                                                                                                                                                                                                                                                  FROM PA_TASKS PT
                                                                                                                                                                                                                                                 WHERE PT.PROJECT_ID = PDV.PROJECT_ID
                                                                                                                                                                                                                                                   AND PT.TASK_ID = PDV.TASK_ID) TASK,
                                                                                                                                                                                                                                               PDV.TAX_RECOVERY_OVERRIDE_FLAG,
                                                                                                                                                                                                                                               (SELECT GCCK.CONCATENATED_SEGMENTS
                                                                                                                                                                                                                                                  FROM GL_CODE_COMBINATIONS_KFV GCCK
                                                                                                                                                                                                                                                 WHERE GCCK.CODE_COMBINATION_ID = PDV.VARIANCE_ACCOUNT_ID) VARIANCE_ACCOUNT,
                                                                                                                                                                                                                                               (SELECT SEGMENT1
                                                                                                                                                                                                                                                  FROM GL_CODE_COMBINATIONS_KFV GCCK
                                                                                                                                                                                                                                                 WHERE GCCK.CODE_COMBINATION_ID = PDV.VARIANCE_ACCOUNT_ID) VARIANCE_ACCT_SEGMENT1,
                                                                                                                                                                                                                                               (SELECT SEGMENT2
                                                                                                                                                                                                                                                  FROM GL_CODE_COMBINATIONS_KFV GCCK
                                                                                                                                                                                                                                                 WHERE GCCK.CODE_COMBINATION_ID = PDV.VARIANCE_ACCOUNT_ID) VARIANCE_ACCT_SEGMENT2,
                                                                                                                                                                                                                                               (SELECT SEGMENT3
                                                                                                                                                                                                                                                  FROM GL_CODE_COMBINATIONS_KFV GCCK
                                                                                                                                                                                                                                                 WHERE GCCK.CODE_COMBINATION_ID = PDV.VARIANCE_ACCOUNT_ID) VARIANCE_ACCT_SEGMENT3,
                                                                                                                                                                                                                                               (SELECT SEGMENT5
                                                                                                                                                                                                                                                  FROM GL_CODE_COMBINATIONS_KFV GCCK
                                                                                                                                                                                                                                                 WHERE GCCK.CODE_COMBINATION_ID = PDV.VARIANCE_ACCOUNT_ID) VARIANCE_ACCT_SEGMENT5,
                                                                                                                                                                                                                                               (SELECT SEGMENT6
                                                                                                                                                                                                                                                  FROM GL_CODE_COMBINATIONS_KFV GCCK
                                                                                                                                                                                                                                                 WHERE GCCK.CODE_COMBINATION_ID = PDV.VARIANCE_ACCOUNT_ID) VARIANCE_ACCT_SEGMENT6,
                                                                                                                                                                                                                                               (SELECT SEGMENT7
                                                                                                                                                                                                                                                  FROM GL_CODE_COMBINATIONS_KFV GCCK
                                                                                                                                                                                                                                                 WHERE GCCK.CODE_COMBINATION_ID = PDV.VARIANCE_ACCOUNT_ID) VARIANCE_ACCT_SEGMENT7,
                                                                                                                                                                                                                                               (SELECT SEGMENT10
                                                                                                                                                                                                                                                  FROM GL_CODE_COMBINATIONS_KFV GCCK
                                                                                                                                                                                                                                                 WHERE GCCK.CODE_COMBINATION_ID = PDV.VARIANCE_ACCOUNT_ID) VARIANCE_ACCT_SEGMENT10,
                                                                                                                                                                                                                                               PLLV.MATCH_OPTION
                                                                                                                                                                                                                                          FROM PO_HEADERS_V        PHV,
                                                                                                                                                                                                                                               PO_LINES_V          PLV,
                                                                                                                                                                                                                                               PO_LINE_LOCATIONS_V PLLV,
                                                                                                                                                                                                                                               PO_DISTRIBUTIONS_V  PDV,
                                                                                                                                                                                                                                               AP_SUPPLIERS        ASP,
                                                                                                                                                                                                                                               AP_SUPPLIER_SITES   ASS
                                                                                                                                                                                                                                         WHERE PHV.PO_HEADER_ID = PLV.PO_HEADER_ID
                                                                                                                                                                                                                                           AND PLV.PO_LINE_ID = PLLV.PO_LINE_ID
                                                                                                                                                                                                                                           AND PDV.LINE_LOCATION_ID = PLLV.LINE_LOCATION_ID
                                                                                                                                                                                                                                           AND NVL(PHV.CANCEL_FLAG, 'N') <> 'Y'
                                                                                                                                                                                                                                           AND NVL(PLV.CLOSED_DATE, TO_DATE('01-APR-2016', 'DD-MON-YYYY')) >=
                                                                                                                                                                                                                                               TO_DATE('01-APR-2016', 'DD-MON-YYYY')
                                                                                                                                                                                                                                           AND NVL(PLV.EXPIRATION_DATE,
                                                                                                                                                                                                                                                   TO_DATE('01-APR-2016', 'DD-MON-YYYY')) >=
                                                                                                                                                                                                                                               TO_DATE('01-APR-2016', 'DD-MON-YY')
                                                                                                                                                                                                                                           AND PHV.VENDOR_ID = ASP.VENDOR_ID
                                                                                                                                                                                                                                           AND ASP.VENDOR_ID = ASS.VENDOR_ID
                                                                                                                                                                                                                                           AND PHV.VENDOR_SITE_ID = ASS.VENDOR_SITE_ID
                                                                                                                                                                                                                                           AND ASP.ENABLED_FLAG = 'Y'
                                                                                                                                                                                                                                           AND TRUNC(SYSDATE) BETWEEN TRUNC(ASP.START_DATE_ACTIVE) AND
                                                                                                                                                                                                                                               TRUNC(NVL(ASP.END_DATE_ACTIVE, SYSDATE))
                                                                                                                                                                                                                                           AND ASS.INACTIVE_DATE IS NULL
                                                                                                                                                                                                                                           AND PHV.ORG_ID = l_org_id
                                                                                                                                                                                                                                           AND PHV.AUTHORIZATION_STATUS = 'APPROVED'
                                                                                                                                                                                                                                           AND NVL(PLV.CANCEL_FLAG, 'N') = 'N'
                                                                                                                                                                                                                                           AND NVL(UPPER(PHV.CLOSED_CODE), 'OPEN') IN
                                                                                                                                                                                                                                               ('OPEN', 'CLOSED FOR INVOICE', 'CLOSED FOR RECEIVING')
                                                                                                                                                                                                                                           AND UPPER(PLLV.CLOSED_CODE) NOT IN ('CLOSED', 'FINALLY CLOSED')
                                                                                                                                                                                                                                           AND PLLV.QUANTITY_RECEIVED = 0
                                                                                                                                                                                                                                           AND PLLV.QUANTITY_BILLED = 0
                                                                                                                                                                                                                                           AND PLLV.QUANTITY_CANCELLED > 0
                                                                                                                                                                                                                                           AND (PLV.QUANTITY - PLLV.QUANTITY_CANCELLED) > 0
                                                                                                                                                                                                                                           AND PHV.DOC_TYPE_NAME IN ('Standard Purchase Order')*/
              -- ORDER BY phv.segment1

              UNION

              --Query Scenario5 (PO is partially received irrespective of how much is invoiced)

              SELECT phv.po_header_id po_header_id,
                     phv.acceptance_due_date,
                     phv.agent_name,
                     phv.agent_id,
                     phv.amount_limit,
                     phv.approved_date,
                     phv.attribute1 attribute1_hdr,
                     phv.attribute2 attribute2_hdr,
                     phv.attribute3 attribute3_hdr,
                     phv.attribute4 attribute4_hdr,
                     phv.attribute5 attribute5_hdr,
                     phv.attribute6 attribute6_hdr,
                     phv.attribute7 attribute7_hdr,
                     phv.attribute8 attribute8_hdr,
                     phv.attribute9 attribute9_hdr,
                     phv.attribute10 attribute10_hdr,
                     phv.attribute11 attribute11_hdr,
                     phv.attribute12 attribute12_hdr,
                     phv.attribute13 attribute13_hdr,
                     phv.attribute14 attribute14_hdr,
                     phv.attribute15 attribute15_hdr,
                     phv.attribute_category attribute_category_hdr,
                     phv.bill_to_location,
                     phv.change_summary,
                     phv.currency_code,
                     phv.segment1,
                     --phv.DOCUMENT_TYPE_CODE,
                     --phv.doc_type_name,
                     phv.type_lookup_code doc_type_name,
                     --phv.DOCUMENT_SUBTYPE,
                     --phv.EFFECTIVE_DATE,
                     phv.creation_date_disp, --need to verify
                     phv.ship_via_lookup_code freight_carrier_hdr,
                     phv.fob_lookup_code fob_hdr, --new field
                     phv.freight_terms_dsp freight_terms_hdr,
                     phv.global_agreement_flag,
                     phv.min_release_amount min_release_amount_hdr,
                     phv.note_to_receiver note_to_receiver_hdr,
                     phv.note_to_vendor note_to_vendor_hdr,
                     (SELECT hou .NAME
                        FROM hr_operating_units hou
                       WHERE hou.organization_id = phv.org_id) operating_unit_name,
                     payment_terms payment_terms_hdr,
                     phv.printed_date,
                     phv.print_count,
                     /*decode((SELECT currency_code FROM gl_ledgers WHERE ledger_id = pdv.set_of_books_id),phv.currency_code,NULL,phv.rate) rate_hdr,
                                                                                                                                                                                                                                       decode((SELECT currency_code FROM gl_ledgers WHERE ledger_id = pdv.set_of_books_id),phv.currency_code,NULL,phv.rate_date) rate_date_hdr,
                                                                                                                                                                                                                                       decode((SELECT currency_code FROM gl_ledgers WHERE ledger_id = pdv.set_of_books_id),phv.currency_code,NULL,phv.rate_type) rate_type,_type,*/
                     phv.rate rate_hdr,
                     phv.rate_date rate_date_hdr,
                     phv.rate_type,
                     phv.revised_date,
                     phv.revision_num,
                     phv.shipping_control,
                     phv.ship_to_location ship_to_location_hdr,
                     phv.vendor_contact,
                     phv.vendor_contact_id,
                     phv.vendor_name,
                     (SELECT segment1
                        FROM ap_suppliers
                       WHERE vendor_id = phv.vendor_id) vendor_num,
                     phv.vendor_site_code,
                     phv.acceptance_required_flag,
                     phv.confirming_order_flag,
                     --line and line locations
                     pllv.accrue_on_receipt_flag accrue_on_receipt_flag_ship,
                     pllv.allow_substitute_receipts_flag allow_sub_receipts_flag_ship,
                     plv.amount amount_line,
                     pllv.amount amount_ship,
                     plv.base_unit_price,
                     (SELECT concatenated_segments
                        FROM mtl_categories_b_kfv mcbk
                       WHERE mcbk.category_id = plv.category_id) category,
                     plv.committed_amount,
                     pllv.days_early_receipt_allowed days_early_rec_allowed_ship,
                     pllv.days_late_receipt_allowed days_late_receipt_allowed_ship,
                     pllv.drop_ship_flag,
                     pllv.enforce_ship_to_location_code enforce_ship_to_loc_code_ship,
                     plv.expiration_date,
                     pllv.fob_lookup_code fob_ship,
                     pllv.ship_via_lookup_code freight_carrier_ship,
                     pllv.freight_terms_lookup_code freight_terms_ship,
                     plv.hazard_class,
                     pllv.inspection_required_flag inspection_required_flag_ship,
                     pllv.invoice_close_tolerance invoice_close_tolerance_ship,
                     plv.item_number,
                     plv.item_description,
                     plv.item_revision,
                     (SELECT NAME
                        FROM per_jobs pj
                       WHERE pj.job_id = plv.job_id) job_name, --need to fetch job_name
                     plv.attribute1 line_attribute1,
                     plv.attribute2 line_attribute2,
                     plv.attribute3 line_attribute3,
                     plv.attribute4 line_attribute4,
                     plv.attribute5 line_attribute5,
                     plv.attribute6 line_attribute6,
                     plv.attribute7 line_attribute7,
                     plv.attribute8 line_attribute8,
                     plv.attribute9 line_attribute9,
                     plv.attribute10 line_attribute10,
                     plv.attribute11 line_attribute11,
                     plv.attribute12 line_attribute12,
                     plv.attribute13 line_attribute13,
                     plv.attribute14 line_attribute14,
                     plv.attribute15 line_attribute15,
                     plv.attribute_category line_attribute_category_lines,
                     plv.price_type,
                     plv.allow_price_override_flag,
                     plv.un_number,
                     plv.capital_expense_flag,
                     plv.transaction_reason_code,
                     plv.quantity_committed,
                     plv.not_to_exceed_price,
                     plv.line_num,
                     plv.line_type,
                     plv.list_price_per_unit,
                     plv.market_price,
                     plv.min_release_amount min_release_amount_line,
                     pllv.need_by_date need_by_date_ship,
                     plv.negotiated_by_preparer_flag,
                     pllv.note_to_receiver note_to_receiver_ship,
                     plv.note_to_vendor note_to_vendor_line,
                     plv.over_tolerance_error_flag,
                     pllv.payment_terms_name payment_terms_ship,
                     plv.preferred_grade preferred_grade_line,
                     plv.preferred_grade preferred_grade_ship,
                     plv.price_break_lookup_code,
                     pllv.promised_date promised_date_ship,
                     --QTY_RCV_EXCEPTION_CODE_LINE ,
                     pllv.qty_rcv_exception_code qty_rcv_exception_code_ship,
                     plv.qty_rcv_tolerance       qty_rcv_tolerance_line,
                     pllv.qty_rcv_tolerance      qty_rcv_tolerance_ship,
                     /*((PLV.QUANTITY - PLLV.QUANTITY_RECEIVED) +
                                                                                                                                                                                                                                                                                                                                                                              (PLLV.QUANTITY_RECEIVED - PLLV.QUANTITY_BILLED) -
                                                                                                                                                                                                                                                                                                                                                                              PLLV.QUANTITY_CANCELLED) QUANTITY_LINE,
                                                                                                                                                                                                                                                                                                                                                                              PLLV.QUANTITY QUANTITY_SHIP,*/
                     (SELECT SUM(quantity_left)
                        FROM (SELECT (pll.quantity - pll.quantity_billed -
                                     pll.quantity_cancelled) quantity_left,
                                     pl.po_line_id
                                FROM po_lines_v pl, po_line_locations_v pll
                               WHERE pl.po_line_id = pll.po_line_id) calc_quantity
                       WHERE calc_quantity.po_line_id = plv.po_line_id
                         AND quantity_left > 0) quantity_line,
                     (pllv.quantity - pllv.quantity_billed -
                     pllv.quantity_cancelled) quantity_ship,
                     0 quantity_billed_ship,
                     0 quantity_cancelled_ship,
                     (pllv.quantity_received - pllv.quantity_billed) quantity_received_ship,
                     pllv.receipt_days_exception_code receipt_days_exc_code_ship,
                     pllv.receipt_required_flag receipt_required_flag_ship,
                     pllv.receive_close_tolerance receive_close_tolerance_ship,
                     (SELECT meaning
                        FROM fnd_lookup_values_vl flvv
                       WHERE lookup_type = 'RCV_ROUTING_HEADERS'
                         AND flvv.lookup_code = pllv.receiving_routing_id) receiving_routing_ship,
                     pllv.attribute1 shipment_attribute1,
                     pllv.attribute2 shipment_attribute2,
                     pllv.attribute3 shipment_attribute3,
                     pllv.attribute4 shipment_attribute4,
                     pllv.attribute5 shipment_attribute5,
                     pllv.attribute6 shipment_attribute6,
                     pllv.attribute7 shipment_attribute7,
                     pllv.attribute8 shipment_attribute8,
                     pllv.attribute9 shipment_attribute9,
                     pllv.attribute10 shipment_attribute10,
                     pllv.attribute11 shipment_attribute11,
                     pllv.attribute12 shipment_attribute12,
                     pllv.attribute13 shipment_attribute13,
                     pllv.attribute14 shipment_attribute14,
                     pllv.attribute15 shipment_attribute15,
                     pllv.attribute_category shipment_attribute_category,
                     pllv.shipment_num shipment_num_ship,
                     pllv.shipment_type shipment_type_ship,
                     pllv.ship_to_location_code ship_to_location_ship,
                     pllv.ship_to_organization_code ship_to_org_code_ship,
                     plv.type_1099,
                     (SELECT muom.uom_code
                        FROM mtl_units_of_measure    muom,
                             mtl_units_of_measure_tl muomt
                       WHERE muom.uom_code = muomt.uom_code
                         AND muomt.LANGUAGE = userenv('LANG')
                         AND muom.unit_of_measure(+) =
                             plv.unit_meas_lookup_code
                         AND nvl(muom.disable_date, SYSDATE + 1) >= SYSDATE) unit_of_measure_line,
                     (SELECT muom.uom_code
                        FROM mtl_units_of_measure    muom,
                             mtl_units_of_measure_tl muomt
                       WHERE muom.uom_code = muomt.uom_code
                         AND muomt.LANGUAGE = userenv('LANG')
                         AND muom.unit_of_measure(+) =
                             pllv.unit_meas_lookup_code
                         AND nvl(muom.disable_date, SYSDATE + 1) >= SYSDATE) unit_of_measure_ship,
                     plv.unit_price,
                     pllv.vendor_product_num,
                     pllv.price_discount price_discount_ship,
                     --pllv.start_date,
                     phv.start_date,
                     -- pllv.end_date,
                     phv.end_date,
                     pllv.price_override,
                     pllv.lead_time lead_time_ship,
                     pllv.lead_time_unit lead_time_unit_ship,
                     plv.matching_basis,
                     pdv.accrue_on_receipt_flag accrue_on_receipt_flag_dist,
                     (SELECT gcck.concatenated_segments
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.accrual_account_id) accrual_account,
                     (SELECT segment1
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.accrual_account_id) accrual_acct_segment1,
                     (SELECT segment2
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.accrual_account_id) accrual_acct_segment2,
                     (SELECT segment3
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.accrual_account_id) accrual_acct_segment3,
                     (SELECT segment5
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.accrual_account_id) accrual_acct_segment5,
                     (SELECT segment6
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.accrual_account_id) accrual_acct_segment6,
                     (SELECT segment7
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.accrual_account_id) accrual_acct_segment7,
                     (SELECT segment10
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.accrual_account_id) accrual_acct_segment10,
                     pdv.amount_billed,
                     pdv.amount_ordered,
                     pdv.attribute1 attribute1_dist,
                     pdv.attribute2 attribute2_dist,
                     pdv.attribute3 attribute3_dist,
                     pdv.attribute4 attribute4_dist,
                     pdv.attribute5 attribute5_dist,
                     pdv.attribute6 attribute6_dist,
                     pdv.attribute7 attribute7_dist,
                     pdv.attribute8 attribute8_dist,
                     pdv.attribute9 attribute9_dist,
                     pdv.attribute10 attribute10_dist,
                     pdv.attribute11 attribute11_dist,
                     pdv.attribute12 attribute12_dist,
                     pdv.attribute13 attribute13_dist,
                     pdv.attribute14 attribute14_dist,
                     pdv.attribute15 attribute15_dist,
                     pdv.attribute_category attribute_category_dist,
                     (SELECT gcck.concatenated_segments
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id = pdv.budget_account_id) budget_account,
                     (SELECT segment1
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id = pdv.budget_account_id) budget_acct_segment1,
                     (SELECT segment2
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id = pdv.budget_account_id) budget_acct_segment2,
                     (SELECT segment3
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id = pdv.budget_account_id) budget_acct_segment3,
                     (SELECT segment5
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id = pdv.budget_account_id) budget_acct_segment5,
                     (SELECT segment6
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id = pdv.budget_account_id) budget_acct_segment6,
                     (SELECT segment7
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id = pdv.budget_account_id) budget_acct_segment7,
                     (SELECT segment10
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id = pdv.budget_account_id) budget_acct_segment10,
                     (SELECT gcck.concatenated_segments
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.code_combination_id) charge_account,
                     (SELECT segment1
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.code_combination_id) charge_acct_segment1,
                     (SELECT segment2
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.code_combination_id) charge_acct_segment2,
                     (SELECT segment3
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.code_combination_id) charge_acct_segment3,
                     (SELECT segment5
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.code_combination_id) charge_acct_segment5,
                     (SELECT segment6
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.code_combination_id) charge_acct_segment6,
                     (SELECT segment7
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.code_combination_id) charge_acct_segment7,
                     (SELECT segment10
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.code_combination_id) charge_acct_segment10,
                     (SELECT hla.location_code
                        FROM hr_locations_all hla
                       WHERE hla.bill_to_site_flag = 'Y'
                         AND hla.location_id = pdv.deliver_to_location_id) deliver_to_location,
                     (SELECT papf.full_name
                        FROM per_all_people_f papf
                       WHERE papf.person_id = pdv.deliver_to_person_id
                         AND SYSDATE BETWEEN
                             nvl(papf.effective_start_date, SYSDATE) AND
                             nvl(papf.effective_end_date, SYSDATE + 1)) deliver_to_person,
                     pdv.destination_context,
                     (SELECT organization_code
                        FROM org_organization_definitions
                       WHERE organization_id =
                             pdv.destination_organization_id) destination_organization,
                     pdv.destination_subinventory,
                     pdv.destination_type_code,
                     pdv.distribution_num,
                     pdv.encumbered_amount,
                     pdv.encumbered_flag,
                     pdv.expenditure_item_date,
                     (SELECT hou.NAME
                        FROM hr_organization_units       hou,
                             hr_organization_information hoi
                       WHERE hou.organization_id = hoi.organization_id
                         AND hou.organization_id =
                             pdv.expenditure_organization_id
                         AND trunc(SYSDATE) BETWEEN
                             nvl(trunc(hou.date_from), trunc(SYSDATE) - 1) AND
                             nvl(trunc(hou.date_to), trunc(SYSDATE) + 1)
                         AND hoi.org_information1 = 'PA_EXPENDITURE_ORG'
                         AND nvl(hoi.org_information2, 'N') = 'Y') expenditure_organization,
                     pdv.expenditure_type,
                     pdv.failed_funds_lookup_code,
                     pdv.gl_cancelled_date,
                     pdv.gl_encumbered_date,
                     pdv.gl_encumbered_period_name,
                     pdv.nonrecoverable_tax,
                     pdv.prevent_encumbrance_flag,
                     (SELECT ppa.NAME
                        FROM pa_projects_all ppa
                       WHERE ppa.project_id = pdv.project_id) project,
                     pdv.project_accounting_context,
                     /*PDV.QUANTITY_BILLED,
                                                                                                                                                                                                                                                                                                                                                                              PDV.QUANTITY_CANCELLED,
                                                                                                                                                                                                                                                                                                                                                                              --PDV.QUANTITY_DELIVERED
                                                                                                                                                                                                                                                                                                                                                                              PDV.QUANTITY_ORDERED_DIST,*/
                     0 quantity_billed_dist,
                     0 quantity_cancelled_dist,
                     (pdv.quantity_ordered - pdv.quantity_billed -
                     pdv.quantity_cancelled) quantity_ordered_dist,
                     /*decode((SELECT currency_code FROM gl_ledgers WHERE ledger_id = pdv.set_of_books_id),phv.currency_code,NULL,pdv.rate) rate_dist,
                                                                                                                                                                                                                                       decode((SELECT currency_code FROM gl_ledgers WHERE ledger_id = pdv.set_of_books_id),phv.currency_code,NULL,pdv.rate_date) rate_date_dist,*/
                     pdv.rate rate_dist,
                     pdv.rate_date rate_date_dist,
                     pdv.recoverable_tax,
                     pdv.recovery_rate,
                     pdv.task_id,
                     (SELECT gl.NAME
                        FROM gl_ledgers gl
                       WHERE gl.ledger_id = pdv.set_of_books_id) set_of_books,
                     (SELECT pt.task_name
                        FROM pa_tasks pt
                       WHERE pt.project_id = pdv.project_id
                         AND pt.task_id = pdv.task_id) task,
                     pdv.tax_recovery_override_flag,
                     (SELECT gcck.concatenated_segments
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.variance_account_id) variance_account,
                     (SELECT segment1
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.variance_account_id) variance_acct_segment1,
                     (SELECT segment2
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.variance_account_id) variance_acct_segment2,
                     (SELECT segment3
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.variance_account_id) variance_acct_segment3,
                     (SELECT segment5
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.variance_account_id) variance_acct_segment5,
                     (SELECT segment6
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.variance_account_id) variance_acct_segment6,
                     (SELECT segment7
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.variance_account_id) variance_acct_segment7,
                     (SELECT segment10
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.variance_account_id) variance_acct_segment10,
                     pllv.match_option
                FROM po_headers_v        phv,
                     po_lines_v          plv,
                     po_line_locations_v pllv,
                     po_distributions_v  pdv,
                     ap_suppliers        asp,
                     ap_supplier_sites   ass
               WHERE phv.po_header_id = plv.po_header_id
                 AND plv.po_line_id = pllv.po_line_id
                 AND pdv.line_location_id = pllv.line_location_id
                 AND nvl(phv.cancel_flag, 'N') <> 'Y'
                 AND nvl(plv.closed_date,
                         to_date('01-APR-2016', 'DD-MON-YYYY')) >=
                     to_date('01-APR-2016', 'DD-MON-YYYY')
                 AND nvl(plv.expiration_date,
                         to_date('01-APR-2016', 'DD-MON-YYYY')) >=
                     to_date('01-APR-2016', 'DD-MON-YYYY')
                 AND phv.vendor_id = asp.vendor_id
                 AND asp.vendor_id = ass.vendor_id
                 AND phv.vendor_site_id = ass.vendor_site_id
                 AND asp.enabled_flag = 'Y'
                 AND trunc(SYSDATE) BETWEEN trunc(asp.start_date_active) AND
                     trunc(nvl(asp.end_date_active, SYSDATE))
                 AND ass.inactive_date IS NULL
                 AND phv.org_id = l_org_id
                 AND phv.authorization_status = 'APPROVED'
                 AND nvl(plv.cancel_flag, 'N') = 'N'
                 AND nvl(upper(phv.closed_code), 'OPEN') IN
                     ('OPEN', 'CLOSED FOR INVOICE', 'CLOSED FOR RECEIVING')
                 AND upper(pllv.closed_code) NOT IN
                     ('CLOSED', 'FINALLY CLOSED')
                 AND pllv.quantity_received > 0
                 AND pllv.quantity_received < pllv.quantity
                    /*AND pllv.quantity_billed > 0  --commented out for POs that are partially received and all received are billed
                                                         AND pllv.quantity_billed < pllv.quantity_received*/
                 AND ((pllv.quantity - pllv.quantity_received) +
                     (pllv.quantity_received - pllv.quantity_billed) -
                     pllv.quantity_cancelled) > 0
                 AND phv.doc_type_name IN ('Standard Purchase Order')
              --ORDER BY phv.segment1

              UNION

              --Query Scenario6 (PO is fully received, partially invoiced)

              SELECT phv.po_header_id po_header_id,
                     phv.acceptance_due_date,
                     phv.agent_name,
                     phv.agent_id,
                     phv.amount_limit,
                     phv.approved_date,
                     phv.attribute1 attribute1_hdr,
                     phv.attribute2 attribute2_hdr,
                     phv.attribute3 attribute3_hdr,
                     phv.attribute4 attribute4_hdr,
                     phv.attribute5 attribute5_hdr,
                     phv.attribute6 attribute6_hdr,
                     phv.attribute7 attribute7_hdr,
                     phv.attribute8 attribute8_hdr,
                     phv.attribute9 attribute9_hdr,
                     phv.attribute10 attribute10_hdr,
                     phv.attribute11 attribute11_hdr,
                     phv.attribute12 attribute12_hdr,
                     phv.attribute13 attribute13_hdr,
                     phv.attribute14 attribute14_hdr,
                     phv.attribute15 attribute15_hdr,
                     phv.attribute_category attribute_category_hdr,
                     phv.bill_to_location,
                     phv.change_summary,
                     phv.currency_code,
                     phv.segment1,
                     --phv.DOCUMENT_TYPE_CODE,
                     --phv.doc_type_name,
                     phv.type_lookup_code doc_type_name,
                     --phv.DOCUMENT_SUBTYPE,
                     --phv.EFFECTIVE_DATE,
                     phv.creation_date_disp, --need to verify
                     phv.ship_via_lookup_code freight_carrier_hdr,
                     phv.fob_lookup_code fob_hdr, --new field
                     phv.freight_terms_dsp freight_terms_hdr,
                     phv.global_agreement_flag,
                     phv.min_release_amount min_release_amount_hdr,
                     phv.note_to_receiver note_to_receiver_hdr,
                     phv.note_to_vendor note_to_vendor_hdr,
                     (SELECT hou .NAME
                        FROM hr_operating_units hou
                       WHERE hou.organization_id = phv.org_id) operating_unit_name,
                     payment_terms payment_terms_hdr,
                     phv.printed_date,
                     phv.print_count,
                     /*decode((SELECT currency_code FROM gl_ledgers WHERE ledger_id = pdv.set_of_books_id),phv.currency_code,NULL,phv.rate) rate_hdr,
                                                                                                                                                                                                                                       decode((SELECT currency_code FROM gl_ledgers WHERE ledger_id = pdv.set_of_books_id),phv.currency_code,NULL,phv.rate_date) rate_date_hdr,
                                                                                                                                                                                                                                       decode((SELECT currency_code FROM gl_ledgers WHERE ledger_id = pdv.set_of_books_id),phv.currency_code,NULL,phv.rate_type) rate_type,*/
                     phv.rate rate_hdr,
                     phv.rate_date rate_date_hdr,
                     phv.rate_type,
                     phv.revised_date,
                     phv.revision_num,
                     phv.shipping_control,
                     phv.ship_to_location ship_to_location_hdr,
                     phv.vendor_contact,
                     phv.vendor_contact_id,
                     phv.vendor_name,
                     (SELECT segment1
                        FROM ap_suppliers
                       WHERE vendor_id = phv.vendor_id) vendor_num,
                     phv.vendor_site_code,
                     phv.acceptance_required_flag,
                     phv.confirming_order_flag,
                     --line and line locations
                     pllv.accrue_on_receipt_flag accrue_on_receipt_flag_ship,
                     pllv.allow_substitute_receipts_flag allow_sub_receipts_flag_ship,
                     plv.amount amount_line,
                     pllv.amount amount_ship,
                     plv.base_unit_price,
                     (SELECT concatenated_segments
                        FROM mtl_categories_b_kfv mcbk
                       WHERE mcbk.category_id = plv.category_id) category,
                     plv.committed_amount,
                     pllv.days_early_receipt_allowed days_early_rec_allowed_ship,
                     pllv.days_late_receipt_allowed days_late_receipt_allowed_ship,
                     pllv.drop_ship_flag,
                     pllv.enforce_ship_to_location_code enforce_ship_to_loc_code_ship,
                     plv.expiration_date,
                     pllv.fob_lookup_code fob_ship,
                     pllv.ship_via_lookup_code freight_carrier_ship,
                     pllv.freight_terms_lookup_code freight_terms_ship,
                     plv.hazard_class,
                     pllv.inspection_required_flag inspection_required_flag_ship,
                     pllv.invoice_close_tolerance invoice_close_tolerance_ship,
                     plv.item_number,
                     plv.item_description,
                     plv.item_revision,
                     (SELECT NAME
                        FROM per_jobs pj
                       WHERE pj.job_id = plv.job_id) job_name, --need to fetch job_name
                     plv.attribute1 line_attribute1,
                     plv.attribute2 line_attribute2,
                     plv.attribute3 line_attribute3,
                     plv.attribute4 line_attribute4,
                     plv.attribute5 line_attribute5,
                     plv.attribute6 line_attribute6,
                     plv.attribute7 line_attribute7,
                     plv.attribute8 line_attribute8,
                     plv.attribute9 line_attribute9,
                     plv.attribute10 line_attribute10,
                     plv.attribute11 line_attribute11,
                     plv.attribute12 line_attribute12,
                     plv.attribute13 line_attribute13,
                     plv.attribute14 line_attribute14,
                     plv.attribute15 line_attribute15,
                     plv.attribute_category line_attribute_category_lines,
                     plv.price_type,
                     plv.allow_price_override_flag,
                     plv.un_number,
                     plv.capital_expense_flag,
                     plv.transaction_reason_code,
                     plv.quantity_committed,
                     plv.not_to_exceed_price,
                     plv.line_num,
                     plv.line_type,
                     plv.list_price_per_unit,
                     plv.market_price,
                     plv.min_release_amount min_release_amount_line,
                     pllv.need_by_date need_by_date_ship,
                     plv.negotiated_by_preparer_flag,
                     pllv.note_to_receiver note_to_receiver_ship,
                     plv.note_to_vendor note_to_vendor_line,
                     plv.over_tolerance_error_flag,
                     pllv.payment_terms_name payment_terms_ship,
                     plv.preferred_grade preferred_grade_line,
                     plv.preferred_grade preferred_grade_ship,
                     plv.price_break_lookup_code,
                     pllv.promised_date promised_date_ship,
                     --QTY_RCV_EXCEPTION_CODE_LINE ,
                     pllv.qty_rcv_exception_code qty_rcv_exception_code_ship,
                     plv.qty_rcv_tolerance       qty_rcv_tolerance_line,
                     pllv.qty_rcv_tolerance      qty_rcv_tolerance_ship,
                     /*(PLV.QUANTITY - PLLV.QUANTITY_CANCELLED -
                                                                                                                                                                                                                                                                                                                                                                              PLLV.QUANTITY_BILLED) QUANTITY_LINE,
                                                                                                                                                                                                                                                                                                                                                                              PLLV.QUANTITY QUANTITY_SHIP,*/
                     (SELECT SUM(quantity_left)
                        FROM (SELECT (pll.quantity - pll.quantity_billed -
                                     pll.quantity_cancelled) quantity_left,
                                     pl.po_line_id
                                FROM po_lines_v pl, po_line_locations_v pll
                               WHERE pl.po_line_id = pll.po_line_id) calc_quantity
                       WHERE calc_quantity.po_line_id = plv.po_line_id
                         AND quantity_left > 0) quantity_line,
                     (pllv.quantity - pllv.quantity_billed -
                     pllv.quantity_cancelled) quantity_ship,
                     0 quantity_billed_ship,
                     0 quantity_cancelled_ship,
                     (pllv.quantity_received - pllv.quantity_billed) quantity_received_ship,
                     pllv.receipt_days_exception_code receipt_days_exc_code_ship,
                     pllv.receipt_required_flag receipt_required_flag_ship,
                     pllv.receive_close_tolerance receive_close_tolerance_ship,
                     (SELECT meaning
                        FROM fnd_lookup_values_vl flvv
                       WHERE lookup_type = 'RCV_ROUTING_HEADERS'
                         AND flvv.lookup_code = pllv.receiving_routing_id) receiving_routing_ship,
                     pllv.attribute1 shipment_attribute1,
                     pllv.attribute2 shipment_attribute2,
                     pllv.attribute3 shipment_attribute3,
                     pllv.attribute4 shipment_attribute4,
                     pllv.attribute5 shipment_attribute5,
                     pllv.attribute6 shipment_attribute6,
                     pllv.attribute7 shipment_attribute7,
                     pllv.attribute8 shipment_attribute8,
                     pllv.attribute9 shipment_attribute9,
                     pllv.attribute10 shipment_attribute10,
                     pllv.attribute11 shipment_attribute11,
                     pllv.attribute12 shipment_attribute12,
                     pllv.attribute13 shipment_attribute13,
                     pllv.attribute14 shipment_attribute14,
                     pllv.attribute15 shipment_attribute15,
                     pllv.attribute_category shipment_attribute_category,
                     pllv.shipment_num shipment_num_ship,
                     pllv.shipment_type shipment_type_ship,
                     pllv.ship_to_location_code ship_to_location_ship,
                     pllv.ship_to_organization_code ship_to_org_code_ship,
                     plv.type_1099,
                     (SELECT muom.uom_code
                        FROM mtl_units_of_measure    muom,
                             mtl_units_of_measure_tl muomt
                       WHERE muom.uom_code = muomt.uom_code
                         AND muomt.LANGUAGE = userenv('LANG')
                         AND muom.unit_of_measure(+) =
                             plv.unit_meas_lookup_code
                         AND nvl(muom.disable_date, SYSDATE + 1) >= SYSDATE) unit_of_measure_line,
                     (SELECT muom.uom_code
                        FROM mtl_units_of_measure    muom,
                             mtl_units_of_measure_tl muomt
                       WHERE muom.uom_code = muomt.uom_code
                         AND muomt.LANGUAGE = userenv('LANG')
                         AND muom.unit_of_measure(+) =
                             pllv.unit_meas_lookup_code
                         AND nvl(muom.disable_date, SYSDATE + 1) >= SYSDATE) unit_of_measure_ship,
                     plv.unit_price,
                     pllv.vendor_product_num,
                     pllv.price_discount price_discount_ship,
                     --pllv.start_date,
                     phv.start_date,
                     --pllv.end_date,
                     phv.end_date,
                     pllv.price_override,
                     pllv.lead_time lead_time_ship,
                     pllv.lead_time_unit lead_time_unit_ship,
                     plv.matching_basis,
                     pdv.accrue_on_receipt_flag accrue_on_receipt_flag_dist,
                     (SELECT gcck.concatenated_segments
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.accrual_account_id) accrual_account,
                     (SELECT segment1
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.accrual_account_id) accrual_acct_segment1,
                     (SELECT segment2
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.accrual_account_id) accrual_acct_segment2,
                     (SELECT segment3
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.accrual_account_id) accrual_acct_segment3,
                     (SELECT segment5
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.accrual_account_id) accrual_acct_segment5,
                     (SELECT segment6
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.accrual_account_id) accrual_acct_segment6,
                     (SELECT segment7
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.accrual_account_id) accrual_acct_segment7,
                     (SELECT segment10
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.accrual_account_id) accrual_acct_segment10,
                     pdv.amount_billed,
                     pdv.amount_ordered,
                     pdv.attribute1 attribute1_dist,
                     pdv.attribute2 attribute2_dist,
                     pdv.attribute3 attribute3_dist,
                     pdv.attribute4 attribute4_dist,
                     pdv.attribute5 attribute5_dist,
                     pdv.attribute6 attribute6_dist,
                     pdv.attribute7 attribute7_dist,
                     pdv.attribute8 attribute8_dist,
                     pdv.attribute9 attribute9_dist,
                     pdv.attribute10 attribute10_dist,
                     pdv.attribute11 attribute11_dist,
                     pdv.attribute12 attribute12_dist,
                     pdv.attribute13 attribute13_dist,
                     pdv.attribute14 attribute14_dist,
                     pdv.attribute15 attribute15_dist,
                     pdv.attribute_category attribute_category_dist,
                     (SELECT gcck.concatenated_segments
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id = pdv.budget_account_id) budget_account,
                     (SELECT segment1
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id = pdv.budget_account_id) budget_acct_segment1,
                     (SELECT segment2
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id = pdv.budget_account_id) budget_acct_segment2,
                     (SELECT segment3
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id = pdv.budget_account_id) budget_acct_segment3,
                     (SELECT segment5
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id = pdv.budget_account_id) budget_acct_segment5,
                     (SELECT segment6
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id = pdv.budget_account_id) budget_acct_segment6,
                     (SELECT segment7
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id = pdv.budget_account_id) budget_acct_segment7,
                     (SELECT segment10
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id = pdv.budget_account_id) budget_acct_segment10,
                     (SELECT gcck.concatenated_segments
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.code_combination_id) charge_account,
                     (SELECT segment1
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.code_combination_id) charge_acct_segment1,
                     (SELECT segment2
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.code_combination_id) charge_acct_segment2,
                     (SELECT segment3
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.code_combination_id) charge_acct_segment3,
                     (SELECT segment5
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.code_combination_id) charge_acct_segment5,
                     (SELECT segment6
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.code_combination_id) charge_acct_segment6,
                     (SELECT segment7
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.code_combination_id) charge_acct_segment7,
                     (SELECT segment10
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.code_combination_id) charge_acct_segment10,
                     (SELECT hla.location_code
                        FROM hr_locations_all hla
                       WHERE hla.bill_to_site_flag = 'Y'
                         AND hla.location_id = pdv.deliver_to_location_id) deliver_to_location,
                     (SELECT papf.full_name
                        FROM per_all_people_f papf
                       WHERE papf.person_id = pdv.deliver_to_person_id
                         AND SYSDATE BETWEEN
                             nvl(papf.effective_start_date, SYSDATE) AND
                             nvl(papf.effective_end_date, SYSDATE + 1)) deliver_to_person,
                     pdv.destination_context,
                     (SELECT organization_code
                        FROM org_organization_definitions
                       WHERE organization_id =
                             pdv.destination_organization_id) destination_organization,
                     pdv.destination_subinventory,
                     pdv.destination_type_code,
                     pdv.distribution_num,
                     pdv.encumbered_amount,
                     pdv.encumbered_flag,
                     pdv.expenditure_item_date,
                     (SELECT hou.NAME
                        FROM hr_organization_units       hou,
                             hr_organization_information hoi
                       WHERE hou.organization_id = hoi.organization_id
                         AND hou.organization_id =
                             pdv.expenditure_organization_id
                         AND trunc(SYSDATE) BETWEEN
                             nvl(trunc(hou.date_from), trunc(SYSDATE) - 1) AND
                             nvl(trunc(hou.date_to), trunc(SYSDATE) + 1)
                         AND hoi.org_information1 = 'PA_EXPENDITURE_ORG'
                         AND nvl(hoi.org_information2, 'N') = 'Y') expenditure_organization,
                     pdv.expenditure_type,
                     pdv.failed_funds_lookup_code,
                     pdv.gl_cancelled_date,
                     pdv.gl_encumbered_date,
                     pdv.gl_encumbered_period_name,
                     pdv.nonrecoverable_tax,
                     pdv.prevent_encumbrance_flag,
                     (SELECT ppa.NAME
                        FROM pa_projects_all ppa
                       WHERE ppa.project_id = pdv.project_id) project,
                     pdv.project_accounting_context,
                     /*PDV.QUANTITY_BILLED,
                                                                                                                                                                                                                                                                                                                                                                              PDV.QUANTITY_CANCELLED,
                                                                                                                                                                                                                                                                                                                                                                              --PDV.QUANTITY_DELIVERED
                                                                                                                                                                                                                                                                                                                                                                              PDV.QUANTITY_ORDERED_DIST,*/
                     0 quantity_billed_dist,
                     0 quantity_cancelled_dist,
                     (pdv.quantity_ordered - pdv.quantity_billed -
                     pdv.quantity_cancelled) quantity_ordered_dist,
                     /*decode((SELECT currency_code FROM gl_ledgers WHERE ledger_id = pdv.set_of_books_id),phv.currency_code,NULL,pdv.rate) rate_dist,
                                                                                                                                                                                                                                       decode((SELECT currency_code FROM gl_ledgers WHERE ledger_id = pdv.set_of_books_id),phv.currency_code,NULL,pdv.rate_date) rate_date_dist,*/
                     pdv.rate rate_dist,
                     pdv.rate_date rate_date_dist,
                     pdv.recoverable_tax,
                     pdv.recovery_rate,
                     pdv.task_id,
                     (SELECT gl.NAME
                        FROM gl_ledgers gl
                       WHERE gl.ledger_id = pdv.set_of_books_id) set_of_books,
                     (SELECT pt.task_name
                        FROM pa_tasks pt
                       WHERE pt.project_id = pdv.project_id
                         AND pt.task_id = pdv.task_id) task,
                     pdv.tax_recovery_override_flag,
                     (SELECT gcck.concatenated_segments
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.variance_account_id) variance_account,
                     (SELECT segment1
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.variance_account_id) variance_acct_segment1,
                     (SELECT segment2
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.variance_account_id) variance_acct_segment2,
                     (SELECT segment3
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.variance_account_id) variance_acct_segment3,
                     (SELECT segment5
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.variance_account_id) variance_acct_segment5,
                     (SELECT segment6
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.variance_account_id) variance_acct_segment6,
                     (SELECT segment7
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.variance_account_id) variance_acct_segment7,
                     (SELECT segment10
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.variance_account_id) variance_acct_segment10,
                     pllv.match_option
                FROM po_headers_v        phv,
                     po_lines_v          plv,
                     po_line_locations_v pllv,
                     po_distributions_v  pdv,
                     ap_suppliers        asp,
                     ap_supplier_sites   ass
               WHERE phv.po_header_id = plv.po_header_id
                 AND plv.po_line_id = pllv.po_line_id
                 AND pdv.line_location_id = pllv.line_location_id
                 AND nvl(phv.cancel_flag, 'N') <> 'Y'
                 AND nvl(plv.closed_date,
                         to_date('01-APR-2016', 'DD-MON-YYYY')) >=
                     to_date('01-APR-2016', 'DD-MON-YYYY')
                 AND nvl(plv.expiration_date,
                         to_date('01-APR-2016', 'DD-MON-YYYY')) >=
                     to_date('01-APR-2016', 'DD-MON-YY')
                 AND phv.vendor_id = asp.vendor_id
                 AND asp.vendor_id = ass.vendor_id
                 AND phv.vendor_site_id = ass.vendor_site_id
                 AND asp.enabled_flag = 'Y'
                 AND trunc(SYSDATE) BETWEEN trunc(asp.start_date_active) AND
                     trunc(nvl(asp.end_date_active, SYSDATE))
                 AND ass.inactive_date IS NULL
                 AND phv.org_id = l_org_id
                 AND phv.authorization_status = 'APPROVED'
                 AND nvl(plv.cancel_flag, 'N') = 'N'
                 AND nvl(upper(phv.closed_code), 'OPEN') IN
                     ('OPEN', 'CLOSED FOR INVOICE', 'CLOSED FOR RECEIVING')
                 AND upper(pllv.closed_code) NOT IN
                     ('CLOSED', 'FINALLY CLOSED')
                 AND pllv.quantity_received = pllv.quantity
                 AND pllv.quantity_billed > 0
                 AND pllv.quantity_billed < pllv.quantity
                 AND (pllv.quantity - pllv.quantity_cancelled -
                     pllv.quantity_billed) > 0
                 AND phv.doc_type_name IN ('Standard Purchase Order')

              --Scenario 7 (the PO Qty has NOT been received BUT Yet it has been invoiced and it is not 2 way match)
              UNION

              SELECT phv.po_header_id po_header_id,
                     phv.acceptance_due_date,
                     phv.agent_name,
                     phv.agent_id,
                     phv.amount_limit,
                     phv.approved_date,
                     phv.attribute1 attribute1_hdr,
                     phv.attribute2 attribute2_hdr,
                     phv.attribute3 attribute3_hdr,
                     phv.attribute4 attribute4_hdr,
                     phv.attribute5 attribute5_hdr,
                     phv.attribute6 attribute6_hdr,
                     phv.attribute7 attribute7_hdr,
                     phv.attribute8 attribute8_hdr,
                     phv.attribute9 attribute9_hdr,
                     phv.attribute10 attribute10_hdr,
                     phv.attribute11 attribute11_hdr,
                     phv.attribute12 attribute12_hdr,
                     phv.attribute13 attribute13_hdr,
                     phv.attribute14 attribute14_hdr,
                     phv.attribute15 attribute15_hdr,
                     phv.attribute_category attribute_category_hdr,
                     phv.bill_to_location,
                     phv.change_summary,
                     phv.currency_code,
                     phv.segment1,
                     --phv.DOCUMENT_TYPE_CODE,
                     --phv.doc_type_name,
                     phv.type_lookup_code doc_type_name,
                     --phv.DOCUMENT_SUBTYPE,
                     --phv.EFFECTIVE_DATE,
                     phv.creation_date_disp, --need to verify
                     phv.ship_via_lookup_code freight_carrier_hdr,
                     phv.fob_lookup_code fob_hdr, --new field
                     phv.freight_terms_dsp freight_terms_hdr,
                     phv.global_agreement_flag,
                     phv.min_release_amount min_release_amount_hdr,
                     phv.note_to_receiver note_to_receiver_hdr,
                     phv.note_to_vendor note_to_vendor_hdr,
                     (SELECT hou .NAME
                        FROM hr_operating_units hou
                       WHERE hou.organization_id = phv.org_id) operating_unit_name,
                     payment_terms payment_terms_hdr,
                     phv.printed_date,
                     phv.print_count,
                     /*decode((SELECT currency_code FROM gl_ledgers WHERE ledger_id = pdv.set_of_books_id),phv.currency_code,NULL,phv.rate) rate_hdr,
                                                                                                                                                                                                                                       decode((SELECT currency_code FROM gl_ledgers WHERE ledger_id = pdv.set_of_books_id),phv.currency_code,NULL,phv.rate_date) rate_date_hdr,
                                                                                                                                                                                                                                       decode((SELECT currency_code FROM gl_ledgers WHERE ledger_id = pdv.set_of_books_id),phv.currency_code,NULL,phv.rate_type) rate_type,*/
                     phv.rate rate_hdr,
                     phv.rate_date rate_date_hdr,
                     phv.rate_type,
                     phv.revised_date,
                     phv.revision_num,
                     phv.shipping_control,
                     phv.ship_to_location ship_to_location_hdr,
                     phv.vendor_contact,
                     phv.vendor_contact_id,
                     phv.vendor_name,
                     (SELECT segment1
                        FROM ap_suppliers
                       WHERE vendor_id = phv.vendor_id) vendor_num,
                     phv.vendor_site_code,
                     phv.acceptance_required_flag,
                     phv.confirming_order_flag,
                     --line and line locations
                     pllv.accrue_on_receipt_flag accrue_on_receipt_flag_ship,
                     pllv.allow_substitute_receipts_flag allow_sub_receipts_flag_ship,
                     plv.amount amount_line,
                     pllv.amount amount_ship,
                     plv.base_unit_price,
                     (SELECT concatenated_segments
                        FROM mtl_categories_b_kfv mcbk
                       WHERE mcbk.category_id = plv.category_id) category,
                     plv.committed_amount,
                     pllv.days_early_receipt_allowed days_early_rec_allowed_ship,
                     pllv.days_late_receipt_allowed days_late_receipt_allowed_ship,
                     pllv.drop_ship_flag,
                     pllv.enforce_ship_to_location_code enforce_ship_to_loc_code_ship,
                     plv.expiration_date,
                     pllv.fob_lookup_code fob_ship,
                     pllv.ship_via_lookup_code freight_carrier_ship,
                     pllv.freight_terms_lookup_code freight_terms_ship,
                     plv.hazard_class,
                     pllv.inspection_required_flag inspection_required_flag_ship,
                     pllv.invoice_close_tolerance invoice_close_tolerance_ship,
                     plv.item_number,
                     plv.item_description,
                     plv.item_revision,
                     (SELECT NAME
                        FROM per_jobs pj
                       WHERE pj.job_id = plv.job_id) job_name, --need to fetch job_name
                     plv.attribute1 line_attribute1,
                     plv.attribute2 line_attribute2,
                     plv.attribute3 line_attribute3,
                     plv.attribute4 line_attribute4,
                     plv.attribute5 line_attribute5,
                     plv.attribute6 line_attribute6,
                     plv.attribute7 line_attribute7,
                     plv.attribute8 line_attribute8,
                     plv.attribute9 line_attribute9,
                     plv.attribute10 line_attribute10,
                     plv.attribute11 line_attribute11,
                     plv.attribute12 line_attribute12,
                     plv.attribute13 line_attribute13,
                     plv.attribute14 line_attribute14,
                     plv.attribute15 line_attribute15,
                     plv.attribute_category line_attribute_category_lines,
                     plv.price_type,
                     plv.allow_price_override_flag,
                     plv.un_number,
                     plv.capital_expense_flag,
                     plv.transaction_reason_code,
                     plv.quantity_committed,
                     plv.not_to_exceed_price,
                     plv.line_num,
                     plv.line_type,
                     plv.list_price_per_unit,
                     plv.market_price,
                     plv.min_release_amount min_release_amount_line,
                     pllv.need_by_date need_by_date_ship,
                     plv.negotiated_by_preparer_flag,
                     pllv.note_to_receiver note_to_receiver_ship,
                     plv.note_to_vendor note_to_vendor_line,
                     plv.over_tolerance_error_flag,
                     pllv.payment_terms_name payment_terms_ship,
                     plv.preferred_grade preferred_grade_line,
                     plv.preferred_grade preferred_grade_ship,
                     plv.price_break_lookup_code,
                     pllv.promised_date promised_date_ship,
                     --QTY_RCV_EXCEPTION_CODE_LINE ,
                     pllv.qty_rcv_exception_code qty_rcv_exception_code_ship,
                     plv.qty_rcv_tolerance       qty_rcv_tolerance_line,
                     pllv.qty_rcv_tolerance      qty_rcv_tolerance_ship,
                     /* (PLV.QUANTITY - PLLV.QUANTITY_BILLED -
                                                                                                                                                                                                                                                                                                                                                                              PLLV.QUANTITY_CANCELLED) QUANTITY_LINE,
                                                                                                                                                                                                                                                                                                                                                                              (PLLV.QUANTITY - PLLV.QUANTITY_BILLED -
                                                                                                                                                                                                                                                                                                                                                                              PLLV.QUANTITY_CANCELLED) QUANTITY_SHIP,*/
                     (SELECT SUM(quantity_left)
                        FROM (SELECT (pll.quantity - pll.quantity_billed -
                                     pll.quantity_cancelled) quantity_left,
                                     pl.po_line_id
                                FROM po_lines_v pl, po_line_locations_v pll
                               WHERE pl.po_line_id = pll.po_line_id) calc_quantity
                       WHERE calc_quantity.po_line_id = plv.po_line_id
                         AND quantity_left > 0) quantity_line,
                     (pllv.quantity - pllv.quantity_billed -
                     pllv.quantity_cancelled) quantity_ship,
                     0 quantity_billed_ship,
                     0 quantity_cancelled_ship,
                     pllv.quantity /*(pllv.quantity_received - pllv.quantity_billed)*/ quantity_received_ship, --new change as nothing has been received.
                     pllv.receipt_days_exception_code receipt_days_exc_code_ship,
                     pllv.receipt_required_flag receipt_required_flag_ship,
                     pllv.receive_close_tolerance receive_close_tolerance_ship,
                     (SELECT meaning
                        FROM fnd_lookup_values_vl flvv
                       WHERE lookup_type = 'RCV_ROUTING_HEADERS'
                         AND flvv.lookup_code = pllv.receiving_routing_id) receiving_routing_ship,
                     pllv.attribute1 shipment_attribute1,
                     pllv.attribute2 shipment_attribute2,
                     pllv.attribute3 shipment_attribute3,
                     pllv.attribute4 shipment_attribute4,
                     pllv.attribute5 shipment_attribute5,
                     pllv.attribute6 shipment_attribute6,
                     pllv.attribute7 shipment_attribute7,
                     pllv.attribute8 shipment_attribute8,
                     pllv.attribute9 shipment_attribute9,
                     pllv.attribute10 shipment_attribute10,
                     pllv.attribute11 shipment_attribute11,
                     pllv.attribute12 shipment_attribute12,
                     pllv.attribute13 shipment_attribute13,
                     pllv.attribute14 shipment_attribute14,
                     pllv.attribute15 shipment_attribute15,
                     pllv.attribute_category shipment_attribute_category,
                     pllv.shipment_num shipment_num_ship,
                     pllv.shipment_type shipment_type_ship,
                     pllv.ship_to_location_code ship_to_location_ship,
                     pllv.ship_to_organization_code ship_to_org_code_ship,
                     plv.type_1099,
                     (SELECT muom.uom_code
                        FROM mtl_units_of_measure    muom,
                             mtl_units_of_measure_tl muomt
                       WHERE muom.uom_code = muomt.uom_code
                         AND muomt.LANGUAGE = userenv('LANG')
                         AND muom.unit_of_measure(+) =
                             plv.unit_meas_lookup_code
                         AND nvl(muom.disable_date, SYSDATE + 1) >= SYSDATE) unit_of_measure_line,
                     (SELECT muom.uom_code
                        FROM mtl_units_of_measure    muom,
                             mtl_units_of_measure_tl muomt
                       WHERE muom.uom_code = muomt.uom_code
                         AND muomt.LANGUAGE = userenv('LANG')
                         AND muom.unit_of_measure(+) =
                             pllv.unit_meas_lookup_code
                         AND nvl(muom.disable_date, SYSDATE + 1) >= SYSDATE) unit_of_measure_ship,
                     plv.unit_price,
                     pllv.vendor_product_num,
                     pllv.price_discount price_discount_ship,
                     --pllv.start_date,
                     phv.start_date,
                     -- pllv.end_date,
                     phv.end_date,
                     pllv.price_override,
                     pllv.lead_time lead_time_ship,
                     pllv.lead_time_unit lead_time_unit_ship,
                     plv.matching_basis,
                     pdv.accrue_on_receipt_flag accrue_on_receipt_flag_dist,
                     (SELECT gcck.concatenated_segments
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.accrual_account_id) accrual_account,
                     (SELECT segment1
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.accrual_account_id) accrual_acct_segment1,
                     (SELECT segment2
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.accrual_account_id) accrual_acct_segment2,
                     (SELECT segment3
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.accrual_account_id) accrual_acct_segment3,
                     (SELECT segment5
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.accrual_account_id) accrual_acct_segment5,
                     (SELECT segment6
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.accrual_account_id) accrual_acct_segment6,
                     (SELECT segment7
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.accrual_account_id) accrual_acct_segment7,
                     (SELECT segment10
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.accrual_account_id) accrual_acct_segment10,
                     pdv.amount_billed,
                     pdv.amount_ordered,
                     pdv.attribute1 attribute1_dist,
                     pdv.attribute2 attribute2_dist,
                     pdv.attribute3 attribute3_dist,
                     pdv.attribute4 attribute4_dist,
                     pdv.attribute5 attribute5_dist,
                     pdv.attribute6 attribute6_dist,
                     pdv.attribute7 attribute7_dist,
                     pdv.attribute8 attribute8_dist,
                     pdv.attribute9 attribute9_dist,
                     pdv.attribute10 attribute10_dist,
                     pdv.attribute11 attribute11_dist,
                     pdv.attribute12 attribute12_dist,
                     pdv.attribute13 attribute13_dist,
                     pdv.attribute14 attribute14_dist,
                     pdv.attribute15 attribute15_dist,
                     pdv.attribute_category attribute_category_dist,
                     (SELECT gcck.concatenated_segments
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id = pdv.budget_account_id) budget_account,
                     (SELECT segment1
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id = pdv.budget_account_id) budget_acct_segment1,
                     (SELECT segment2
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id = pdv.budget_account_id) budget_acct_segment2,
                     (SELECT segment3
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id = pdv.budget_account_id) budget_acct_segment3,
                     (SELECT segment5
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id = pdv.budget_account_id) budget_acct_segment5,
                     (SELECT segment6
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id = pdv.budget_account_id) budget_acct_segment6,
                     (SELECT segment7
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id = pdv.budget_account_id) budget_acct_segment7,
                     (SELECT segment10
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id = pdv.budget_account_id) budget_acct_segment10,
                     (SELECT gcck.concatenated_segments
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.code_combination_id) charge_account,
                     (SELECT segment1
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.code_combination_id) charge_acct_segment1,
                     (SELECT segment2
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.code_combination_id) charge_acct_segment2,
                     (SELECT segment3
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.code_combination_id) charge_acct_segment3,
                     (SELECT segment5
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.code_combination_id) charge_acct_segment5,
                     (SELECT segment6
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.code_combination_id) charge_acct_segment6,
                     (SELECT segment7
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.code_combination_id) charge_acct_segment7,
                     (SELECT segment10
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.code_combination_id) charge_acct_segment10,
                     (SELECT hla.location_code
                        FROM hr_locations_all hla
                       WHERE hla.bill_to_site_flag = 'Y'
                         AND hla.location_id = pdv.deliver_to_location_id) deliver_to_location,
                     (SELECT papf.full_name
                        FROM per_all_people_f papf
                       WHERE papf.person_id = pdv.deliver_to_person_id
                         AND SYSDATE BETWEEN
                             nvl(papf.effective_start_date, SYSDATE) AND
                             nvl(papf.effective_end_date, SYSDATE + 1)) deliver_to_person,
                     pdv.destination_context,
                     (SELECT organization_code
                        FROM org_organization_definitions
                       WHERE organization_id =
                             pdv.destination_organization_id) destination_organization,
                     pdv.destination_subinventory,
                     pdv.destination_type_code,
                     pdv.distribution_num,
                     pdv.encumbered_amount,
                     pdv.encumbered_flag,
                     pdv.expenditure_item_date,
                     (SELECT hou.NAME
                        FROM hr_organization_units       hou,
                             hr_organization_information hoi
                       WHERE hou.organization_id = hoi.organization_id
                         AND hou.organization_id =
                             pdv.expenditure_organization_id
                         AND trunc(SYSDATE) BETWEEN
                             nvl(trunc(hou.date_from), trunc(SYSDATE) - 1) AND
                             nvl(trunc(hou.date_to), trunc(SYSDATE) + 1)
                         AND hoi.org_information1 = 'PA_EXPENDITURE_ORG'
                         AND nvl(hoi.org_information2, 'N') = 'Y') expenditure_organization,
                     pdv.expenditure_type,
                     pdv.failed_funds_lookup_code,
                     pdv.gl_cancelled_date,
                     pdv.gl_encumbered_date,
                     pdv.gl_encumbered_period_name,
                     pdv.nonrecoverable_tax,
                     pdv.prevent_encumbrance_flag,
                     (SELECT ppa.NAME
                        FROM pa_projects_all ppa
                       WHERE ppa.project_id = pdv.project_id) project,
                     pdv.project_accounting_context,
                     /*PDV.QUANTITY_BILLED,
                                                                                                                                                                                                                                                                                                                                                                              PDV.QUANTITY_CANCELLED,
                                                                                                                                                                                                                                                                                                                                                                              --PDV.QUANTITY_DELIVERED
                                                                                                                                                                                                                                                                                                                                                                              PDV.QUANTITY_ORDERED_DIST,*/
                     0 quantity_billed_dist,
                     0 quantity_cancelled_dist,
                     (pdv.quantity_ordered - pdv.quantity_billed -
                     pdv.quantity_cancelled) quantity_ordered_dist,
                     /*decode((SELECT currency_code FROM gl_ledgers WHERE ledger_id = pdv.set_of_books_id),phv.currency_code,NULL,pdv.rate) rate_dist,
                                                                                                                                                                                                                                       decode((SELECT currency_code FROM gl_ledgers WHERE ledger_id = pdv.set_of_books_id),phv.currency_code,NULL,pdv.rate_date) rate_date_dist,*/
                     pdv.rate rate_dist,
                     pdv.rate_date rate_date_dist,
                     pdv.recoverable_tax,
                     pdv.recovery_rate,
                     pdv.task_id,
                     (SELECT gl.NAME
                        FROM gl_ledgers gl
                       WHERE gl.ledger_id = pdv.set_of_books_id) set_of_books,
                     (SELECT pt.task_name
                        FROM pa_tasks pt
                       WHERE pt.project_id = pdv.project_id
                         AND pt.task_id = pdv.task_id) task,
                     pdv.tax_recovery_override_flag,
                     (SELECT gcck.concatenated_segments
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.variance_account_id) variance_account,
                     (SELECT segment1
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.variance_account_id) variance_acct_segment1,
                     (SELECT segment2
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.variance_account_id) variance_acct_segment2,
                     (SELECT segment3
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.variance_account_id) variance_acct_segment3,
                     (SELECT segment5
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.variance_account_id) variance_acct_segment5,
                     (SELECT segment6
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.variance_account_id) variance_acct_segment6,
                     (SELECT segment7
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.variance_account_id) variance_acct_segment7,
                     (SELECT segment10
                        FROM gl_code_combinations_kfv gcck
                       WHERE gcck.code_combination_id =
                             pdv.variance_account_id) variance_acct_segment10,
                     pllv.match_option
                FROM po_headers_v        phv,
                     po_lines_v          plv,
                     po_line_locations_v pllv,
                     po_distributions_v  pdv,
                     ap_suppliers        asp,
                     ap_supplier_sites   ass
               WHERE phv.po_header_id = plv.po_header_id
                 AND plv.po_line_id = pllv.po_line_id
                 AND pdv.line_location_id = pllv.line_location_id
                 AND nvl(phv.cancel_flag, 'N') <> 'Y'
                 AND nvl(plv.closed_date,
                         to_date('01-APR-2016', 'DD-MON-YYYY')) >=
                     to_date('01-APR-2016', 'DD-MON-YYYY')
                 AND nvl(plv.expiration_date,
                         to_date('01-APR-2016', 'DD-MON-YYYY')) >=
                     to_date('01-APR-2016', 'DD-MON-YY')
                 AND phv.vendor_id = asp.vendor_id
                 AND asp.vendor_id = ass.vendor_id
                 AND phv.vendor_site_id = ass.vendor_site_id
                 AND asp.enabled_flag = 'Y'
                 AND trunc(SYSDATE) BETWEEN trunc(asp.start_date_active) AND
                     trunc(nvl(asp.end_date_active, SYSDATE))
                 AND ass.inactive_date IS NULL
                 AND phv.org_id = l_org_id
                 AND phv.authorization_status = 'APPROVED'
                 AND nvl(plv.cancel_flag, 'N') = 'N'
                 AND nvl(upper(phv.closed_code), 'OPEN') IN
                     ('OPEN', 'CLOSED FOR INVOICE', 'CLOSED FOR RECEIVING')
                 AND upper(pllv.closed_code) NOT IN
                     ('CLOSED', 'FINALLY CLOSED')
                 AND pllv.quantity_received = 0
                 AND pllv.quantity_billed = pllv.quantity --Fully invoiced
                 AND pllv.inspection_required_flag <> 'N' --new change
                 AND pllv.receipt_required_flag <> 'N'
                    /*AND pllv.inspection_required_flag = 'N'
                                                         AND pllv.receipt_required_flag = 'N'*/
                    /*AND (pllv.quantity - pllv.quantity_billed -
                                                             pllv.quantity_cancelled) > 0*/
                 AND phv.doc_type_name IN ('Standard Purchase Order')

              UNION

              --(Scenario 8 : PO is not received but it is fully invoiced and it is 2 way match.Extract if unpaid)
              SELECT DISTINCT phv.po_header_id po_header_id,
                              phv.acceptance_due_date,
                              phv.agent_name,
                              phv.agent_id,
                              phv.amount_limit,
                              phv.approved_date,
                              phv.attribute1 attribute1_hdr,
                              phv.attribute2 attribute2_hdr,
                              phv.attribute3 attribute3_hdr,
                              phv.attribute4 attribute4_hdr,
                              phv.attribute5 attribute5_hdr,
                              phv.attribute6 attribute6_hdr,
                              phv.attribute7 attribute7_hdr,
                              phv.attribute8 attribute8_hdr,
                              phv.attribute9 attribute9_hdr,
                              phv.attribute10 attribute10_hdr,
                              phv.attribute11 attribute11_hdr,
                              phv.attribute12 attribute12_hdr,
                              phv.attribute13 attribute13_hdr,
                              phv.attribute14 attribute14_hdr,
                              phv.attribute15 attribute15_hdr,
                              phv.attribute_category attribute_category_hdr,
                              phv.bill_to_location,
                              phv.change_summary,
                              phv.currency_code,
                              phv.segment1,
                              --phv.DOCUMENT_TYPE_CODE,
                              --phv.doc_type_name,
                              phv.type_lookup_code doc_type_name,
                              --phv.DOCUMENT_SUBTYPE,
                              --phv.EFFECTIVE_DATE,
                              phv.creation_date_disp, --need to verify
                              phv.ship_via_lookup_code freight_carrier_hdr,
                              phv.fob_lookup_code fob_hdr, --new field
                              phv.freight_terms_dsp freight_terms_hdr,
                              phv.global_agreement_flag,
                              phv.min_release_amount min_release_amount_hdr,
                              phv.note_to_receiver note_to_receiver_hdr,
                              phv.note_to_vendor note_to_vendor_hdr,
                              (SELECT hou .NAME
                                 FROM hr_operating_units hou
                                WHERE hou.organization_id = phv.org_id) operating_unit_name,
                              payment_terms payment_terms_hdr,
                              phv.printed_date,
                              phv.print_count,
                              /*decode((SELECT currency_code FROM gl_ledgers WHERE ledger_id = pdv.set_of_books_id),phv.currency_code,NULL,phv.rate) rate_hdr,
                                                                                                                                                                                                                                                                decode((SELECT currency_code FROM gl_ledgers WHERE ledger_id = pdv.set_of_books_id),phv.currency_code,NULL,phv.rate_date) rate_date_hdr,
                                                                                                                                                                                                                                                                decode((SELECT currency_code FROM gl_ledgers WHERE ledger_id = pdv.set_of_books_id),phv.currency_code,NULL,phv.rate_type) rate_type,*/
                              phv.rate rate_hdr,
                              phv.rate_date rate_date_hdr,
                              phv.rate_type,
                              phv.revised_date,
                              phv.revision_num,
                              phv.shipping_control,
                              phv.ship_to_location ship_to_location_hdr,
                              phv.vendor_contact,
                              phv.vendor_contact_id,
                              phv.vendor_name,
                              (SELECT segment1
                                 FROM ap_suppliers
                                WHERE vendor_id = phv.vendor_id) vendor_num,
                              phv.vendor_site_code,
                              phv.acceptance_required_flag,
                              phv.confirming_order_flag,
                              --line and line locations
                              pllv.accrue_on_receipt_flag accrue_on_receipt_flag_ship,
                              pllv.allow_substitute_receipts_flag allow_sub_receipts_flag_ship,
                              plv.amount amount_line,
                              pllv.amount amount_ship,
                              plv.base_unit_price,
                              (SELECT concatenated_segments
                                 FROM mtl_categories_b_kfv mcbk
                                WHERE mcbk.category_id = plv.category_id) category,
                              plv.committed_amount,
                              pllv.days_early_receipt_allowed days_early_rec_allowed_ship,
                              pllv.days_late_receipt_allowed days_late_receipt_allowed_ship,
                              pllv.drop_ship_flag,
                              pllv.enforce_ship_to_location_code enforce_ship_to_loc_code_ship,
                              plv.expiration_date,
                              pllv.fob_lookup_code fob_ship,
                              pllv.ship_via_lookup_code freight_carrier_ship,
                              pllv.freight_terms_lookup_code freight_terms_ship,
                              plv.hazard_class,
                              pllv.inspection_required_flag inspection_required_flag_ship,
                              pllv.invoice_close_tolerance invoice_close_tolerance_ship,
                              plv.item_number,
                              plv.item_description,
                              plv.item_revision,
                              (SELECT NAME
                                 FROM per_jobs pj
                                WHERE pj.job_id = plv.job_id) job_name, --need to fetch job_name
                              plv.attribute1 line_attribute1,
                              plv.attribute2 line_attribute2,
                              plv.attribute3 line_attribute3,
                              plv.attribute4 line_attribute4,
                              plv.attribute5 line_attribute5,
                              plv.attribute6 line_attribute6,
                              plv.attribute7 line_attribute7,
                              plv.attribute8 line_attribute8,
                              plv.attribute9 line_attribute9,
                              plv.attribute10 line_attribute10,
                              plv.attribute11 line_attribute11,
                              plv.attribute12 line_attribute12,
                              plv.attribute13 line_attribute13,
                              plv.attribute14 line_attribute14,
                              plv.attribute15 line_attribute15,
                              plv.attribute_category line_attribute_category_lines,
                              plv.price_type,
                              plv.allow_price_override_flag,
                              plv.un_number,
                              plv.capital_expense_flag,
                              plv.transaction_reason_code,
                              plv.quantity_committed,
                              plv.not_to_exceed_price,
                              plv.line_num,
                              plv.line_type,
                              plv.list_price_per_unit,
                              plv.market_price,
                              plv.min_release_amount min_release_amount_line,
                              pllv.need_by_date need_by_date_ship,
                              plv.negotiated_by_preparer_flag,
                              pllv.note_to_receiver note_to_receiver_ship,
                              plv.note_to_vendor note_to_vendor_line,
                              plv.over_tolerance_error_flag,
                              pllv.payment_terms_name payment_terms_ship,
                              plv.preferred_grade preferred_grade_line,
                              plv.preferred_grade preferred_grade_ship,
                              plv.price_break_lookup_code,
                              pllv.promised_date promised_date_ship,
                              --QTY_RCV_EXCEPTION_CODE_LINE ,
                              pllv.qty_rcv_exception_code qty_rcv_exception_code_ship,
                              plv.qty_rcv_tolerance qty_rcv_tolerance_line,
                              pllv.qty_rcv_tolerance qty_rcv_tolerance_ship,
                              (SELECT SUM(quantity_left)
                                 FROM (SELECT (pll.quantity -
                                              pll.quantity_cancelled) quantity_left,
                                              pl.po_line_id
                                         FROM po_lines_v          pl,
                                              po_line_locations_v pll
                                        WHERE pl.po_line_id = pll.po_line_id) calc_quantity
                                WHERE calc_quantity.po_line_id =
                                      plv.po_line_id
                                  AND quantity_left > 0) quantity_line,
                              (pllv.quantity - pllv.quantity_cancelled) quantity_ship,
                              (pllv.quantity_billed -
                              pllv.quantity_cancelled) quantity_billed_ship,
                              0 quantity_cancelled_ship,
                              (pllv.quantity_received -
                              pllv.quantity_cancelled) quantity_received_ship,
                              pllv.receipt_days_exception_code receipt_days_exc_code_ship,
                              pllv.receipt_required_flag receipt_required_flag_ship,
                              pllv.receive_close_tolerance receive_close_tolerance_ship,
                              (SELECT meaning
                                 FROM fnd_lookup_values_vl flvv
                                WHERE lookup_type = 'RCV_ROUTING_HEADERS'
                                  AND flvv.lookup_code =
                                      pllv.receiving_routing_id) receiving_routing_ship,
                              pllv.attribute1 shipment_attribute1,
                              pllv.attribute2 shipment_attribute2,
                              pllv.attribute3 shipment_attribute3,
                              pllv.attribute4 shipment_attribute4,
                              pllv.attribute5 shipment_attribute5,
                              pllv.attribute6 shipment_attribute6,
                              pllv.attribute7 shipment_attribute7,
                              pllv.attribute8 shipment_attribute8,
                              pllv.attribute9 shipment_attribute9,
                              pllv.attribute10 shipment_attribute10,
                              pllv.attribute11 shipment_attribute11,
                              pllv.attribute12 shipment_attribute12,
                              pllv.attribute13 shipment_attribute13,
                              pllv.attribute14 shipment_attribute14,
                              pllv.attribute15 shipment_attribute15,
                              pllv.attribute_category shipment_attribute_category,
                              pllv.shipment_num shipment_num_ship,
                              pllv.shipment_type shipment_type_ship,
                              pllv.ship_to_location_code ship_to_location_ship,
                              pllv.ship_to_organization_code ship_to_org_code_ship,
                              plv.type_1099,
                              (SELECT muom.uom_code
                                 FROM mtl_units_of_measure    muom,
                                      mtl_units_of_measure_tl muomt
                                WHERE muom.uom_code = muomt.uom_code
                                  AND muomt.LANGUAGE = userenv('LANG')
                                  AND muom.unit_of_measure(+) =
                                      plv.unit_meas_lookup_code
                                  AND nvl(muom.disable_date, SYSDATE + 1) >=
                                      SYSDATE) unit_of_measure_line,
                              (SELECT muom.uom_code
                                 FROM mtl_units_of_measure    muom,
                                      mtl_units_of_measure_tl muomt
                                WHERE muom.uom_code = muomt.uom_code
                                  AND muomt.LANGUAGE = userenv('LANG')
                                  AND muom.unit_of_measure(+) =
                                      pllv.unit_meas_lookup_code
                                  AND nvl(muom.disable_date, SYSDATE + 1) >=
                                      SYSDATE) unit_of_measure_ship,
                              plv.unit_price,
                              pllv.vendor_product_num,
                              pllv.price_discount price_discount_ship,
                              --pllv.start_date,
                              phv.start_date,
                              -- pllv.end_date,
                              phv.end_date,
                              pllv.price_override,
                              pllv.lead_time lead_time_ship,
                              pllv.lead_time_unit lead_time_unit_ship,
                              plv.matching_basis,
                              pdv.accrue_on_receipt_flag accrue_on_receipt_flag_dist,
                              (SELECT gcck.concatenated_segments
                                 FROM gl_code_combinations_kfv gcck
                                WHERE gcck.code_combination_id =
                                      pdv.accrual_account_id) accrual_account,
                              (SELECT segment1
                                 FROM gl_code_combinations_kfv gcck
                                WHERE gcck.code_combination_id =
                                      pdv.accrual_account_id) accrual_acct_segment1,
                              (SELECT segment2
                                 FROM gl_code_combinations_kfv gcck
                                WHERE gcck.code_combination_id =
                                      pdv.accrual_account_id) accrual_acct_segment2,
                              (SELECT segment3
                                 FROM gl_code_combinations_kfv gcck
                                WHERE gcck.code_combination_id =
                                      pdv.accrual_account_id) accrual_acct_segment3,
                              (SELECT segment5
                                 FROM gl_code_combinations_kfv gcck
                                WHERE gcck.code_combination_id =
                                      pdv.accrual_account_id) accrual_acct_segment5,
                              (SELECT segment6
                                 FROM gl_code_combinations_kfv gcck
                                WHERE gcck.code_combination_id =
                                      pdv.accrual_account_id) accrual_acct_segment6,
                              (SELECT segment7
                                 FROM gl_code_combinations_kfv gcck
                                WHERE gcck.code_combination_id =
                                      pdv.accrual_account_id) accrual_acct_segment7,
                              (SELECT segment10
                                 FROM gl_code_combinations_kfv gcck
                                WHERE gcck.code_combination_id =
                                      pdv.accrual_account_id) accrual_acct_segment10,
                              pdv.amount_billed,
                              pdv.amount_ordered,
                              pdv.attribute1 attribute1_dist,
                              pdv.attribute2 attribute2_dist,
                              pdv.attribute3 attribute3_dist,
                              pdv.attribute4 attribute4_dist,
                              pdv.attribute5 attribute5_dist,
                              pdv.attribute6 attribute6_dist,
                              pdv.attribute7 attribute7_dist,
                              pdv.attribute8 attribute8_dist,
                              pdv.attribute9 attribute9_dist,
                              pdv.attribute10 attribute10_dist,
                              pdv.attribute11 attribute11_dist,
                              pdv.attribute12 attribute12_dist,
                              pdv.attribute13 attribute13_dist,
                              pdv.attribute14 attribute14_dist,
                              pdv.attribute15 attribute15_dist,
                              pdv.attribute_category attribute_category_dist,
                              (SELECT gcck.concatenated_segments
                                 FROM gl_code_combinations_kfv gcck
                                WHERE gcck.code_combination_id =
                                      pdv.budget_account_id) budget_account,
                              (SELECT segment1
                                 FROM gl_code_combinations_kfv gcck
                                WHERE gcck.code_combination_id =
                                      pdv.budget_account_id) budget_acct_segment1,
                              (SELECT segment2
                                 FROM gl_code_combinations_kfv gcck
                                WHERE gcck.code_combination_id =
                                      pdv.budget_account_id) budget_acct_segment2,
                              (SELECT segment3
                                 FROM gl_code_combinations_kfv gcck
                                WHERE gcck.code_combination_id =
                                      pdv.budget_account_id) budget_acct_segment3,
                              (SELECT segment5
                                 FROM gl_code_combinations_kfv gcck
                                WHERE gcck.code_combination_id =
                                      pdv.budget_account_id) budget_acct_segment5,
                              (SELECT segment6
                                 FROM gl_code_combinations_kfv gcck
                                WHERE gcck.code_combination_id =
                                      pdv.budget_account_id) budget_acct_segment6,
                              (SELECT segment7
                                 FROM gl_code_combinations_kfv gcck
                                WHERE gcck.code_combination_id =
                                      pdv.budget_account_id) budget_acct_segment7,
                              (SELECT segment10
                                 FROM gl_code_combinations_kfv gcck
                                WHERE gcck.code_combination_id =
                                      pdv.budget_account_id) budget_acct_segment10,
                              (SELECT gcck.concatenated_segments
                                 FROM gl_code_combinations_kfv gcck
                                WHERE gcck.code_combination_id =
                                      pdv.code_combination_id) charge_account,
                              (SELECT segment1
                                 FROM gl_code_combinations_kfv gcck
                                WHERE gcck.code_combination_id =
                                      pdv.code_combination_id) charge_acct_segment1,
                              (SELECT segment2
                                 FROM gl_code_combinations_kfv gcck
                                WHERE gcck.code_combination_id =
                                      pdv.code_combination_id) charge_acct_segment2,
                              (SELECT segment3
                                 FROM gl_code_combinations_kfv gcck
                                WHERE gcck.code_combination_id =
                                      pdv.code_combination_id) charge_acct_segment3,
                              (SELECT segment5
                                 FROM gl_code_combinations_kfv gcck
                                WHERE gcck.code_combination_id =
                                      pdv.code_combination_id) charge_acct_segment5,
                              (SELECT segment6
                                 FROM gl_code_combinations_kfv gcck
                                WHERE gcck.code_combination_id =
                                      pdv.code_combination_id) charge_acct_segment6,
                              (SELECT segment7
                                 FROM gl_code_combinations_kfv gcck
                                WHERE gcck.code_combination_id =
                                      pdv.code_combination_id) charge_acct_segment7,
                              (SELECT segment10
                                 FROM gl_code_combinations_kfv gcck
                                WHERE gcck.code_combination_id =
                                      pdv.code_combination_id) charge_acct_segment10,
                              (SELECT hla.location_code
                                 FROM hr_locations_all hla
                                WHERE hla.bill_to_site_flag = 'Y'
                                  AND hla.location_id =
                                      pdv.deliver_to_location_id) deliver_to_location,
                              (SELECT papf.full_name
                                 FROM per_all_people_f papf
                                WHERE papf.person_id =
                                      pdv.deliver_to_person_id
                                  AND SYSDATE BETWEEN
                                      nvl(papf.effective_start_date, SYSDATE) AND
                                      nvl(papf.effective_end_date,
                                          SYSDATE + 1)) deliver_to_person,
                              pdv.destination_context,
                              (SELECT organization_code
                                 FROM org_organization_definitions
                                WHERE organization_id =
                                      pdv.destination_organization_id) destination_organization,
                              pdv.destination_subinventory,
                              pdv.destination_type_code,
                              pdv.distribution_num,
                              pdv.encumbered_amount,
                              pdv.encumbered_flag,
                              pdv.expenditure_item_date,
                              (SELECT hou.NAME
                                 FROM hr_organization_units       hou,
                                      hr_organization_information hoi
                                WHERE hou.organization_id =
                                      hoi.organization_id
                                  AND hou.organization_id =
                                      pdv.expenditure_organization_id
                                  AND trunc(SYSDATE) BETWEEN
                                      nvl(trunc(hou.date_from),
                                          trunc(SYSDATE) - 1) AND
                                      nvl(trunc(hou.date_to),
                                          trunc(SYSDATE) + 1)
                                  AND hoi.org_information1 =
                                      'PA_EXPENDITURE_ORG'
                                  AND nvl(hoi.org_information2, 'N') = 'Y') expenditure_organization,
                              pdv.expenditure_type,
                              pdv.failed_funds_lookup_code,
                              pdv.gl_cancelled_date,
                              pdv.gl_encumbered_date,
                              pdv.gl_encumbered_period_name,
                              pdv.nonrecoverable_tax,
                              pdv.prevent_encumbrance_flag,
                              (SELECT ppa.NAME
                                 FROM pa_projects_all ppa
                                WHERE ppa.project_id = pdv.project_id) project,
                              pdv.project_accounting_context,
                              /*PDV.QUANTITY_BILLED,
                                                                                                                                                                                                                                                                                                                                                                                                       PDV.QUANTITY_CANCELLED,
                                                                                                                                                                                                                                                                                                                                                                                                       --PDV.QUANTITY_DELIVERED
                                                                                                                                                                                                                                                                                                                                                                                                       PDV.QUANTITY_ORDERED_DIST,*/
                              0 quantity_billed_dist,
                              0 quantity_cancelled_dist,
                              (pdv.quantity_ordered - pdv.quantity_cancelled) quantity_ordered_dist,
                              /*decode((SELECT currency_code FROM gl_ledgers WHERE ledger_id = pdv.set_of_books_id),phv.currency_code,NULL,pdv.rate) rate_dist,
                                                                                                                                                                                                                                                                decode((SELECT currency_code FROM gl_ledgers WHERE ledger_id = pdv.set_of_books_id),phv.currency_code,NULL,pdv.rate_date) rate_date_dist,*/
                              pdv.rate rate_dist,
                              pdv.rate_date rate_date_dist,
                              pdv.recoverable_tax,
                              pdv.recovery_rate,
                              pdv.task_id,
                              (SELECT gl.NAME
                                 FROM gl_ledgers gl
                                WHERE gl.ledger_id = pdv.set_of_books_id) set_of_books,
                              (SELECT pt.task_name
                                 FROM pa_tasks pt
                                WHERE pt.project_id = pdv.project_id
                                  AND pt.task_id = pdv.task_id) task,
                              pdv.tax_recovery_override_flag,
                              (SELECT gcck.concatenated_segments
                                 FROM gl_code_combinations_kfv gcck
                                WHERE gcck.code_combination_id =
                                      pdv.variance_account_id) variance_account,
                              (SELECT segment1
                                 FROM gl_code_combinations_kfv gcck
                                WHERE gcck.code_combination_id =
                                      pdv.variance_account_id) variance_acct_segment1,
                              (SELECT segment2
                                 FROM gl_code_combinations_kfv gcck
                                WHERE gcck.code_combination_id =
                                      pdv.variance_account_id) variance_acct_segment2,
                              (SELECT segment3
                                 FROM gl_code_combinations_kfv gcck
                                WHERE gcck.code_combination_id =
                                      pdv.variance_account_id) variance_acct_segment3,
                              (SELECT segment5
                                 FROM gl_code_combinations_kfv gcck
                                WHERE gcck.code_combination_id =
                                      pdv.variance_account_id) variance_acct_segment5,
                              (SELECT segment6
                                 FROM gl_code_combinations_kfv gcck
                                WHERE gcck.code_combination_id =
                                      pdv.variance_account_id) variance_acct_segment6,
                              (SELECT segment7
                                 FROM gl_code_combinations_kfv gcck
                                WHERE gcck.code_combination_id =
                                      pdv.variance_account_id) variance_acct_segment7,
                              (SELECT segment10
                                 FROM gl_code_combinations_kfv gcck
                                WHERE gcck.code_combination_id =
                                      pdv.variance_account_id) variance_acct_segment10,
                              pllv.match_option
                FROM po_headers_v        phv,
                     po_lines_v          plv,
                     po_line_locations_v pllv,
                     po_distributions_v  pdv,
                     ap_suppliers        asp,
                     ap_supplier_sites   ass,
                     ap_invoice_lines_v  ail,
                     ap_invoices_v       ai
               WHERE phv.po_header_id = plv.po_header_id
                 AND plv.po_line_id = pllv.po_line_id
                 AND pdv.line_location_id = pllv.line_location_id
                 AND nvl(phv.cancel_flag, 'N') <> 'Y'
                 AND nvl(plv.closed_date,
                         to_date('01-APR-2016', 'DD-MON-YYYY')) >=
                     to_date('01-APR-2016', 'DD-MON-YYYY')
                 AND nvl(plv.expiration_date,
                         to_date('01-APR-2016', 'DD-MON-YYYY')) >=
                     to_date('01-APR-2016', 'DD-MON-YY')
                 AND phv.vendor_id = asp.vendor_id
                 AND asp.vendor_id = ass.vendor_id
                 AND phv.vendor_site_id = ass.vendor_site_id
                 AND asp.enabled_flag = 'Y'
                 AND trunc(SYSDATE) BETWEEN trunc(asp.start_date_active) AND
                     trunc(nvl(asp.end_date_active, SYSDATE))
                 AND ass.inactive_date IS NULL
                 AND phv.org_id = l_org_id
                 AND phv.authorization_status = 'APPROVED'
                 AND nvl(plv.cancel_flag, 'N') = 'N'
                 AND pllv.quantity_received = 0 -- Not Received
                 AND pllv.quantity_billed = pllv.quantity -- Fully Invoiced
                 AND pllv.inspection_required_flag = 'N' --2 way matched but unpaid
                 AND pllv.receipt_required_flag = 'N'
                 AND pllv.po_line_id = ail.po_line_id
                 AND pllv.po_header_id = ail.po_header_id
                 AND ail.invoice_id = ai.invoice_id
                 AND (ai.payment_status_flag = 'N' OR
                     ai.payment_status_flag = 'P')
                    --AND ai.invoice_type NOT IN ('Credit Memo', 'Debit Memo')
                 AND ai.invoice_type_lookup_code IN
                     ('STANDARD', 'PREPAYMENT')
                 AND phv.doc_type_name IN ('Standard Purchase Order')
                 AND ai.cancelled_date IS NULL

              --(Scenario 9 : PO is fully received and fully invoiced but not paid in full)

              UNION

              SELECT DISTINCT phv.po_header_id po_header_id,
                              phv.acceptance_due_date,
                              phv.agent_name,
                              phv.agent_id,
                              phv.amount_limit,
                              phv.approved_date,
                              phv.attribute1 attribute1_hdr,
                              phv.attribute2 attribute2_hdr,
                              phv.attribute3 attribute3_hdr,
                              phv.attribute4 attribute4_hdr,
                              phv.attribute5 attribute5_hdr,
                              phv.attribute6 attribute6_hdr,
                              phv.attribute7 attribute7_hdr,
                              phv.attribute8 attribute8_hdr,
                              phv.attribute9 attribute9_hdr,
                              phv.attribute10 attribute10_hdr,
                              phv.attribute11 attribute11_hdr,
                              phv.attribute12 attribute12_hdr,
                              phv.attribute13 attribute13_hdr,
                              phv.attribute14 attribute14_hdr,
                              phv.attribute15 attribute15_hdr,
                              phv.attribute_category attribute_category_hdr,
                              phv.bill_to_location,
                              phv.change_summary,
                              phv.currency_code,
                              phv.segment1,
                              --phv.DOCUMENT_TYPE_CODE,
                              --phv.doc_type_name,
                              phv.type_lookup_code doc_type_name,
                              --phv.DOCUMENT_SUBTYPE,
                              --phv.EFFECTIVE_DATE,
                              phv.creation_date_disp, --need to verify
                              phv.ship_via_lookup_code freight_carrier_hdr,
                              phv.fob_lookup_code fob_hdr, --new field
                              phv.freight_terms_dsp freight_terms_hdr,
                              phv.global_agreement_flag,
                              phv.min_release_amount min_release_amount_hdr,
                              phv.note_to_receiver note_to_receiver_hdr,
                              phv.note_to_vendor note_to_vendor_hdr,
                              (SELECT hou .NAME
                                 FROM hr_operating_units hou
                                WHERE hou.organization_id = phv.org_id) operating_unit_name,
                              payment_terms payment_terms_hdr,
                              phv.printed_date,
                              phv.print_count,
                              /*decode((SELECT currency_code FROM gl_ledgers WHERE ledger_id = pdv.set_of_books_id),phv.currency_code,NULL,phv.rate) rate_hdr,
                                                                                                                                                                                                                                                                decode((SELECT currency_code FROM gl_ledgers WHERE ledger_id = pdv.set_of_books_id),phv.currency_code,NULL,phv.rate_date) rate_date_hdr,
                                                                                                                                                                                                                                                                decode((SELECT currency_code FROM gl_ledgers WHERE ledger_id = pdv.set_of_books_id),phv.currency_code,NULL,phv.rate_type) rate_type,*/
                              phv.rate rate_hdr,
                              phv.rate_date rate_date_hdr,
                              phv.rate_type,
                              phv.revised_date,
                              phv.revision_num,
                              phv.shipping_control,
                              phv.ship_to_location ship_to_location_hdr,
                              phv.vendor_contact,
                              phv.vendor_contact_id,
                              phv.vendor_name,
                              (SELECT segment1
                                 FROM ap_suppliers
                                WHERE vendor_id = phv.vendor_id) vendor_num,
                              phv.vendor_site_code,
                              phv.acceptance_required_flag,
                              phv.confirming_order_flag,
                              --line and line locations
                              pllv.accrue_on_receipt_flag accrue_on_receipt_flag_ship,
                              pllv.allow_substitute_receipts_flag allow_sub_receipts_flag_ship,
                              plv.amount amount_line,
                              pllv.amount amount_ship,
                              plv.base_unit_price,
                              (SELECT concatenated_segments
                                 FROM mtl_categories_b_kfv mcbk
                                WHERE mcbk.category_id = plv.category_id) category,
                              plv.committed_amount,
                              pllv.days_early_receipt_allowed days_early_rec_allowed_ship,
                              pllv.days_late_receipt_allowed days_late_receipt_allowed_ship,
                              pllv.drop_ship_flag,
                              pllv.enforce_ship_to_location_code enforce_ship_to_loc_code_ship,
                              plv.expiration_date,
                              pllv.fob_lookup_code fob_ship,
                              pllv.ship_via_lookup_code freight_carrier_ship,
                              pllv.freight_terms_lookup_code freight_terms_ship,
                              plv.hazard_class,
                              pllv.inspection_required_flag inspection_required_flag_ship,
                              pllv.invoice_close_tolerance invoice_close_tolerance_ship,
                              plv.item_number,
                              plv.item_description,
                              plv.item_revision,
                              (SELECT NAME
                                 FROM per_jobs pj
                                WHERE pj.job_id = plv.job_id) job_name, --need to fetch job_name
                              plv.attribute1 line_attribute1,
                              plv.attribute2 line_attribute2,
                              plv.attribute3 line_attribute3,
                              plv.attribute4 line_attribute4,
                              plv.attribute5 line_attribute5,
                              plv.attribute6 line_attribute6,
                              plv.attribute7 line_attribute7,
                              plv.attribute8 line_attribute8,
                              plv.attribute9 line_attribute9,
                              plv.attribute10 line_attribute10,
                              plv.attribute11 line_attribute11,
                              plv.attribute12 line_attribute12,
                              plv.attribute13 line_attribute13,
                              plv.attribute14 line_attribute14,
                              plv.attribute15 line_attribute15,
                              plv.attribute_category line_attribute_category_lines,
                              plv.price_type,
                              plv.allow_price_override_flag,
                              plv.un_number,
                              plv.capital_expense_flag,
                              plv.transaction_reason_code,
                              plv.quantity_committed,
                              plv.not_to_exceed_price,
                              plv.line_num,
                              plv.line_type,
                              plv.list_price_per_unit,
                              plv.market_price,
                              plv.min_release_amount min_release_amount_line,
                              pllv.need_by_date need_by_date_ship,
                              plv.negotiated_by_preparer_flag,
                              pllv.note_to_receiver note_to_receiver_ship,
                              plv.note_to_vendor note_to_vendor_line,
                              plv.over_tolerance_error_flag,
                              pllv.payment_terms_name payment_terms_ship,
                              plv.preferred_grade preferred_grade_line,
                              plv.preferred_grade preferred_grade_ship,
                              plv.price_break_lookup_code,
                              pllv.promised_date promised_date_ship,
                              --QTY_RCV_EXCEPTION_CODE_LINE ,
                              pllv.qty_rcv_exception_code qty_rcv_exception_code_ship,
                              plv.qty_rcv_tolerance qty_rcv_tolerance_line,
                              pllv.qty_rcv_tolerance qty_rcv_tolerance_ship,
                              (SELECT SUM(quantity_left)
                                 FROM (SELECT (pll.quantity -
                                              pll.quantity_cancelled) quantity_left,
                                              pl.po_line_id
                                         FROM po_lines_v          pl,
                                              po_line_locations_v pll
                                        WHERE pl.po_line_id = pll.po_line_id) calc_quantity
                                WHERE calc_quantity.po_line_id =
                                      plv.po_line_id
                                  AND quantity_left > 0) quantity_line,
                              (pllv.quantity - pllv.quantity_cancelled) quantity_ship,
                              (pllv.quantity_billed -
                              pllv.quantity_cancelled) quantity_billed_ship,
                              0 quantity_cancelled_ship,
                              (pllv.quantity_received -
                              pllv.quantity_cancelled) quantity_received_ship,
                              pllv.receipt_days_exception_code receipt_days_exc_code_ship,
                              pllv.receipt_required_flag receipt_required_flag_ship,
                              pllv.receive_close_tolerance receive_close_tolerance_ship,
                              (SELECT meaning
                                 FROM fnd_lookup_values_vl flvv
                                WHERE lookup_type = 'RCV_ROUTING_HEADERS'
                                  AND flvv.lookup_code =
                                      pllv.receiving_routing_id) receiving_routing_ship,
                              pllv.attribute1 shipment_attribute1,
                              pllv.attribute2 shipment_attribute2,
                              pllv.attribute3 shipment_attribute3,
                              pllv.attribute4 shipment_attribute4,
                              pllv.attribute5 shipment_attribute5,
                              pllv.attribute6 shipment_attribute6,
                              pllv.attribute7 shipment_attribute7,
                              pllv.attribute8 shipment_attribute8,
                              pllv.attribute9 shipment_attribute9,
                              pllv.attribute10 shipment_attribute10,
                              pllv.attribute11 shipment_attribute11,
                              pllv.attribute12 shipment_attribute12,
                              pllv.attribute13 shipment_attribute13,
                              pllv.attribute14 shipment_attribute14,
                              pllv.attribute15 shipment_attribute15,
                              pllv.attribute_category shipment_attribute_category,
                              pllv.shipment_num shipment_num_ship,
                              pllv.shipment_type shipment_type_ship,
                              pllv.ship_to_location_code ship_to_location_ship,
                              pllv.ship_to_organization_code ship_to_org_code_ship,
                              plv.type_1099,
                              (SELECT muom.uom_code
                                 FROM mtl_units_of_measure    muom,
                                      mtl_units_of_measure_tl muomt
                                WHERE muom.uom_code = muomt.uom_code
                                  AND muomt.LANGUAGE = userenv('LANG')
                                  AND muom.unit_of_measure(+) =
                                      plv.unit_meas_lookup_code
                                  AND nvl(muom.disable_date, SYSDATE + 1) >=
                                      SYSDATE) unit_of_measure_line,
                              (SELECT muom.uom_code
                                 FROM mtl_units_of_measure    muom,
                                      mtl_units_of_measure_tl muomt
                                WHERE muom.uom_code = muomt.uom_code
                                  AND muomt.LANGUAGE = userenv('LANG')
                                  AND muom.unit_of_measure(+) =
                                      pllv.unit_meas_lookup_code
                                  AND nvl(muom.disable_date, SYSDATE + 1) >=
                                      SYSDATE) unit_of_measure_ship,
                              plv.unit_price,
                              pllv.vendor_product_num,
                              pllv.price_discount price_discount_ship,
                              --pllv.start_date,
                              phv.start_date,
                              -- pllv.end_date,
                              phv.end_date,
                              pllv.price_override,
                              pllv.lead_time lead_time_ship,
                              pllv.lead_time_unit lead_time_unit_ship,
                              plv.matching_basis,
                              pdv.accrue_on_receipt_flag accrue_on_receipt_flag_dist,
                              (SELECT gcck.concatenated_segments
                                 FROM gl_code_combinations_kfv gcck
                                WHERE gcck.code_combination_id =
                                      pdv.accrual_account_id) accrual_account,
                              (SELECT segment1
                                 FROM gl_code_combinations_kfv gcck
                                WHERE gcck.code_combination_id =
                                      pdv.accrual_account_id) accrual_acct_segment1,
                              (SELECT segment2
                                 FROM gl_code_combinations_kfv gcck
                                WHERE gcck.code_combination_id =
                                      pdv.accrual_account_id) accrual_acct_segment2,
                              (SELECT segment3
                                 FROM gl_code_combinations_kfv gcck
                                WHERE gcck.code_combination_id =
                                      pdv.accrual_account_id) accrual_acct_segment3,
                              (SELECT segment5
                                 FROM gl_code_combinations_kfv gcck
                                WHERE gcck.code_combination_id =
                                      pdv.accrual_account_id) accrual_acct_segment5,
                              (SELECT segment6
                                 FROM gl_code_combinations_kfv gcck
                                WHERE gcck.code_combination_id =
                                      pdv.accrual_account_id) accrual_acct_segment6,
                              (SELECT segment7
                                 FROM gl_code_combinations_kfv gcck
                                WHERE gcck.code_combination_id =
                                      pdv.accrual_account_id) accrual_acct_segment7,
                              (SELECT segment10
                                 FROM gl_code_combinations_kfv gcck
                                WHERE gcck.code_combination_id =
                                      pdv.accrual_account_id) accrual_acct_segment10,
                              pdv.amount_billed,
                              pdv.amount_ordered,
                              pdv.attribute1 attribute1_dist,
                              pdv.attribute2 attribute2_dist,
                              pdv.attribute3 attribute3_dist,
                              pdv.attribute4 attribute4_dist,
                              pdv.attribute5 attribute5_dist,
                              pdv.attribute6 attribute6_dist,
                              pdv.attribute7 attribute7_dist,
                              pdv.attribute8 attribute8_dist,
                              pdv.attribute9 attribute9_dist,
                              pdv.attribute10 attribute10_dist,
                              pdv.attribute11 attribute11_dist,
                              pdv.attribute12 attribute12_dist,
                              pdv.attribute13 attribute13_dist,
                              pdv.attribute14 attribute14_dist,
                              pdv.attribute15 attribute15_dist,
                              pdv.attribute_category attribute_category_dist,
                              (SELECT gcck.concatenated_segments
                                 FROM gl_code_combinations_kfv gcck
                                WHERE gcck.code_combination_id =
                                      pdv.budget_account_id) budget_account,
                              (SELECT segment1
                                 FROM gl_code_combinations_kfv gcck
                                WHERE gcck.code_combination_id =
                                      pdv.budget_account_id) budget_acct_segment1,
                              (SELECT segment2
                                 FROM gl_code_combinations_kfv gcck
                                WHERE gcck.code_combination_id =
                                      pdv.budget_account_id) budget_acct_segment2,
                              (SELECT segment3
                                 FROM gl_code_combinations_kfv gcck
                                WHERE gcck.code_combination_id =
                                      pdv.budget_account_id) budget_acct_segment3,
                              (SELECT segment5
                                 FROM gl_code_combinations_kfv gcck
                                WHERE gcck.code_combination_id =
                                      pdv.budget_account_id) budget_acct_segment5,
                              (SELECT segment6
                                 FROM gl_code_combinations_kfv gcck
                                WHERE gcck.code_combination_id =
                                      pdv.budget_account_id) budget_acct_segment6,
                              (SELECT segment7
                                 FROM gl_code_combinations_kfv gcck
                                WHERE gcck.code_combination_id =
                                      pdv.budget_account_id) budget_acct_segment7,
                              (SELECT segment10
                                 FROM gl_code_combinations_kfv gcck
                                WHERE gcck.code_combination_id =
                                      pdv.budget_account_id) budget_acct_segment10,
                              (SELECT gcck.concatenated_segments
                                 FROM gl_code_combinations_kfv gcck
                                WHERE gcck.code_combination_id =
                                      pdv.code_combination_id) charge_account,
                              (SELECT segment1
                                 FROM gl_code_combinations_kfv gcck
                                WHERE gcck.code_combination_id =
                                      pdv.code_combination_id) charge_acct_segment1,
                              (SELECT segment2
                                 FROM gl_code_combinations_kfv gcck
                                WHERE gcck.code_combination_id =
                                      pdv.code_combination_id) charge_acct_segment2,
                              (SELECT segment3
                                 FROM gl_code_combinations_kfv gcck
                                WHERE gcck.code_combination_id =
                                      pdv.code_combination_id) charge_acct_segment3,
                              (SELECT segment5
                                 FROM gl_code_combinations_kfv gcck
                                WHERE gcck.code_combination_id =
                                      pdv.code_combination_id) charge_acct_segment5,
                              (SELECT segment6
                                 FROM gl_code_combinations_kfv gcck
                                WHERE gcck.code_combination_id =
                                      pdv.code_combination_id) charge_acct_segment6,
                              (SELECT segment7
                                 FROM gl_code_combinations_kfv gcck
                                WHERE gcck.code_combination_id =
                                      pdv.code_combination_id) charge_acct_segment7,
                              (SELECT segment10
                                 FROM gl_code_combinations_kfv gcck
                                WHERE gcck.code_combination_id =
                                      pdv.code_combination_id) charge_acct_segment10,
                              (SELECT hla.location_code
                                 FROM hr_locations_all hla
                                WHERE hla.bill_to_site_flag = 'Y'
                                  AND hla.location_id =
                                      pdv.deliver_to_location_id) deliver_to_location,
                              (SELECT papf.full_name
                                 FROM per_all_people_f papf
                                WHERE papf.person_id =
                                      pdv.deliver_to_person_id
                                  AND SYSDATE BETWEEN
                                      nvl(papf.effective_start_date, SYSDATE) AND
                                      nvl(papf.effective_end_date,
                                          SYSDATE + 1)) deliver_to_person,
                              pdv.destination_context,
                              (SELECT organization_code
                                 FROM org_organization_definitions
                                WHERE organization_id =
                                      pdv.destination_organization_id) destination_organization,
                              pdv.destination_subinventory,
                              pdv.destination_type_code,
                              pdv.distribution_num,
                              pdv.encumbered_amount,
                              pdv.encumbered_flag,
                              pdv.expenditure_item_date,
                              (SELECT hou.NAME
                                 FROM hr_organization_units       hou,
                                      hr_organization_information hoi
                                WHERE hou.organization_id =
                                      hoi.organization_id
                                  AND hou.organization_id =
                                      pdv.expenditure_organization_id
                                  AND trunc(SYSDATE) BETWEEN
                                      nvl(trunc(hou.date_from),
                                          trunc(SYSDATE) - 1) AND
                                      nvl(trunc(hou.date_to),
                                          trunc(SYSDATE) + 1)
                                  AND hoi.org_information1 =
                                      'PA_EXPENDITURE_ORG'
                                  AND nvl(hoi.org_information2, 'N') = 'Y') expenditure_organization,
                              pdv.expenditure_type,
                              pdv.failed_funds_lookup_code,
                              pdv.gl_cancelled_date,
                              pdv.gl_encumbered_date,
                              pdv.gl_encumbered_period_name,
                              pdv.nonrecoverable_tax,
                              pdv.prevent_encumbrance_flag,
                              (SELECT ppa.NAME
                                 FROM pa_projects_all ppa
                                WHERE ppa.project_id = pdv.project_id) project,
                              pdv.project_accounting_context,
                              /*PDV.QUANTITY_BILLED,
                                                                                                                                                                                                                                                                                                                                                                                                       PDV.QUANTITY_CANCELLED,
                                                                                                                                                                                                                                                                                                                                                                                                       --PDV.QUANTITY_DELIVERED
                                                                                                                                                                                                                                                                                                                                                                                                       PDV.QUANTITY_ORDERED_DIST,*/
                              0 quantity_billed_dist,
                              0 quantity_cancelled_dist,
                              (pdv.quantity_ordered - pdv.quantity_cancelled) quantity_ordered_dist,
                              /*decode((SELECT currency_code FROM gl_ledgers WHERE ledger_id = pdv.set_of_books_id),phv.currency_code,NULL,pdv.rate) rate_dist,
                                                                                                                                                                                                                                                                decode((SELECT currency_code FROM gl_ledgers WHERE ledger_id = pdv.set_of_books_id),phv.currency_code,NULL,pdv.rate_date) rate_date_dist,*/
                              pdv.rate rate_dist,
                              pdv.rate_date rate_date_dist,
                              pdv.recoverable_tax,
                              pdv.recovery_rate,
                              pdv.task_id,
                              (SELECT gl.NAME
                                 FROM gl_ledgers gl
                                WHERE gl.ledger_id = pdv.set_of_books_id) set_of_books,
                              (SELECT pt.task_name
                                 FROM pa_tasks pt
                                WHERE pt.project_id = pdv.project_id
                                  AND pt.task_id = pdv.task_id) task,
                              pdv.tax_recovery_override_flag,
                              (SELECT gcck.concatenated_segments
                                 FROM gl_code_combinations_kfv gcck
                                WHERE gcck.code_combination_id =
                                      pdv.variance_account_id) variance_account,
                              (SELECT segment1
                                 FROM gl_code_combinations_kfv gcck
                                WHERE gcck.code_combination_id =
                                      pdv.variance_account_id) variance_acct_segment1,
                              (SELECT segment2
                                 FROM gl_code_combinations_kfv gcck
                                WHERE gcck.code_combination_id =
                                      pdv.variance_account_id) variance_acct_segment2,
                              (SELECT segment3
                                 FROM gl_code_combinations_kfv gcck
                                WHERE gcck.code_combination_id =
                                      pdv.variance_account_id) variance_acct_segment3,
                              (SELECT segment5
                                 FROM gl_code_combinations_kfv gcck
                                WHERE gcck.code_combination_id =
                                      pdv.variance_account_id) variance_acct_segment5,
                              (SELECT segment6
                                 FROM gl_code_combinations_kfv gcck
                                WHERE gcck.code_combination_id =
                                      pdv.variance_account_id) variance_acct_segment6,
                              (SELECT segment7
                                 FROM gl_code_combinations_kfv gcck
                                WHERE gcck.code_combination_id =
                                      pdv.variance_account_id) variance_acct_segment7,
                              (SELECT segment10
                                 FROM gl_code_combinations_kfv gcck
                                WHERE gcck.code_combination_id =
                                      pdv.variance_account_id) variance_acct_segment10,
                              pllv.match_option
                FROM po_headers_v        phv,
                     po_lines_v          plv,
                     po_line_locations_v pllv,
                     po_distributions_v  pdv,
                     ap_suppliers        asp,
                     ap_supplier_sites   ass,
                     ap_invoice_lines_v  ail,
                     ap_invoices_v       ai
               WHERE phv.po_header_id = plv.po_header_id
                 AND plv.po_line_id = pllv.po_line_id
                 AND pdv.line_location_id = pllv.line_location_id
                 AND nvl(phv.cancel_flag, 'N') <> 'Y'
                 AND nvl(plv.closed_date,
                         to_date('01-APR-2016', 'DD-MON-YYYY')) >=
                     to_date('01-APR-2016', 'DD-MON-YYYY')
                 AND nvl(plv.expiration_date,
                         to_date('01-APR-2016', 'DD-MON-YYYY')) >=
                     to_date('01-APR-2016', 'DD-MON-YY')
                 AND phv.vendor_id = asp.vendor_id
                 AND asp.vendor_id = ass.vendor_id
                 AND phv.vendor_site_id = ass.vendor_site_id
                 AND asp.enabled_flag = 'Y'
                 AND trunc(SYSDATE) BETWEEN trunc(asp.start_date_active) AND
                     trunc(nvl(asp.end_date_active, SYSDATE))
                 AND ass.inactive_date IS NULL
                 AND phv.org_id = l_org_id
                 AND phv.authorization_status = 'APPROVED'
                 AND nvl(plv.cancel_flag, 'N') = 'N'
                 AND pllv.quantity = pllv.quantity_received -- Fully Received
                 AND pllv.quantity = pllv.quantity_billed -- Fully Invoiced
                 AND pllv.po_line_id = ail.po_line_id
                 AND pllv.po_header_id = ail.po_header_id
                 AND ail.invoice_id = ai.invoice_id
                 AND (ai.payment_status_flag = 'N' OR
                     ai.payment_status_flag = 'P')
                    --AND ai.invoice_type NOT IN ('Credit Memo', 'Debit Memo')
                 AND ai.invoice_type_lookup_code IN
                     ('STANDARD', 'PREPAYMENT')
                 AND phv.doc_type_name IN ('Standard Purchase Order')
                 AND ai.cancelled_date IS NULL)
       ORDER BY segment1;

    --cursor for blanket Purchase agreements

    CURSOR c_bpa IS
      SELECT phv.po_header_id po_header_id,
             phv.acceptance_due_date,
             phv.agent_name,
             phv.agent_id,
             phv.amount_limit,
             phv.approved_date,
             phv.attribute1 attribute1_hdr,
             phv.attribute2 attribute2_hdr,
             phv.attribute3 attribute3_hdr,
             phv.attribute4 attribute4_hdr,
             phv.attribute5 attribute5_hdr,
             phv.attribute6 attribute6_hdr,
             phv.attribute7 attribute7_hdr,
             phv.attribute8 attribute8_hdr,
             phv.attribute9 attribute9_hdr,
             phv.attribute10 attribute10_hdr,
             phv.attribute11 attribute11_hdr,
             phv.attribute12 attribute12_hdr,
             phv.attribute13 attribute13_hdr,
             phv.attribute14 attribute14_hdr,
             phv.attribute15 attribute15_hdr,
             phv.attribute_category attribute_category_hdr,
             phv.bill_to_location,
             phv.change_summary,
             phv.currency_code,
             phv.segment1,
             --phv.DOCUMENT_TYPE_CODE,
             --phv.doc_type_name,
             phv.type_lookup_code doc_type_name,
             --phv.DOCUMENT_SUBTYPE,
             --phv.EFFECTIVE_DATE,
             phv.creation_date_disp, --need to verify
             phv.ship_via_lookup_code freight_carrier_hdr,
             phv.fob_lookup_code fob_hdr, --new field
             phv.freight_terms_dsp freight_terms_hdr,
             phv.global_agreement_flag,
             phv.min_release_amount min_release_amount_hdr,
             phv.note_to_receiver note_to_receiver_hdr,
             phv.note_to_vendor note_to_vendor_hdr,
             (SELECT hou .NAME
                FROM hr_operating_units hou
               WHERE hou.organization_id = phv.org_id) operating_unit_name,
             payment_terms payment_terms_hdr,
             phv.printed_date,
             phv.print_count,
             phv.rate rate_hdr,
             phv.rate_date rate_date_hdr,
             phv.rate_type,
             phv.revised_date,
             phv.revision_num,
             phv.shipping_control,
             phv.ship_to_location ship_to_location_hdr,
             phv.vendor_contact,
             phv.vendor_contact_id,
             phv.vendor_name,
             (SELECT segment1
                FROM ap_suppliers asp
               WHERE asp.vendor_id = phv.vendor_id
                 AND asp.enabled_flag = 'Y'
                 AND trunc(SYSDATE) BETWEEN trunc(asp.start_date_active) AND
                     trunc(nvl(asp.end_date_active, SYSDATE))) vendor_num,
             phv.vendor_site_code,
             phv.acceptance_required_flag,
             phv.confirming_order_flag,
             --line and line locations
             pllv.accrue_on_receipt_flag accrue_on_receipt_flag_ship,
             pllv.allow_substitute_receipts_flag allow_sub_receipts_flag_ship,
             plv.amount amount_line,
             pllv.amount amount_ship,
             plv.base_unit_price,
             (SELECT concatenated_segments
                FROM mtl_categories_b_kfv mcbk
               WHERE mcbk.category_id = plv.category_id) category,
             plv.committed_amount,
             pllv.days_early_receipt_allowed days_early_rec_allowed_ship,
             pllv.days_late_receipt_allowed days_late_receipt_allowed_ship,
             pllv.drop_ship_flag,
             pllv.enforce_ship_to_location_code enforce_ship_to_loc_code_ship,
             plv.expiration_date,
             pllv.fob_lookup_code fob_ship,
             pllv.ship_via_lookup_code freight_carrier_ship,
             pllv.freight_terms_lookup_code freight_terms_ship,
             plv.hazard_class,
             pllv.inspection_required_flag inspection_required_flag_ship,
             pllv.invoice_close_tolerance invoice_close_tolerance_ship,
             plv.item_number,
             plv.item_description,
             plv.item_revision,
             (SELECT NAME FROM per_jobs pj WHERE pj.job_id = plv.job_id) job_name, --need to fetch job_name
             plv.attribute1 line_attribute1,
             plv.attribute2 line_attribute2,
             plv.attribute3 line_attribute3,
             plv.attribute4 line_attribute4,
             plv.attribute5 line_attribute5,
             plv.attribute6 line_attribute6,
             plv.attribute7 line_attribute7,
             plv.attribute8 line_attribute8,
             plv.attribute9 line_attribute9,
             plv.attribute10 line_attribute10,
             plv.attribute11 line_attribute11,
             plv.attribute12 line_attribute12,
             plv.attribute13 line_attribute13,
             plv.attribute14 line_attribute14,
             plv.attribute15 line_attribute15,
             plv.attribute_category line_attribute_category_lines,
             plv.price_type,
             plv.allow_price_override_flag,
             plv.un_number,
             plv.capital_expense_flag,
             plv.transaction_reason_code,
             plv.quantity_committed,
             plv.not_to_exceed_price,
             plv.line_num,
             plv.line_type,
             plv.list_price_per_unit,
             plv.market_price,
             plv.min_release_amount min_release_amount_line,
             pllv.need_by_date need_by_date_ship,
             plv.negotiated_by_preparer_flag,
             pllv.note_to_receiver note_to_receiver_ship,
             plv.note_to_vendor note_to_vendor_line,
             plv.over_tolerance_error_flag,
             pllv.payment_terms_name payment_terms_ship,
             plv.preferred_grade preferred_grade_line,
             plv.preferred_grade preferred_grade_ship,
             plv.price_break_lookup_code,
             pllv.promised_date promised_date_ship,
             --QTY_RCV_EXCEPTION_CODE_LINE ,
             pllv.qty_rcv_exception_code qty_rcv_exception_code_ship,
             plv.qty_rcv_tolerance qty_rcv_tolerance_line,
             pllv.qty_rcv_tolerance qty_rcv_tolerance_ship,
             (plv.quantity_committed -
             (SELECT SUM(pllv1. quantity_received)
                 FROM po_line_locations_all pllv1, po_releases_v prv
                WHERE phv.po_header_id = prv.po_header_id
                  AND pllv1.po_release_id IS NOT NULL
                  AND prv.po_release_id = pllv1.po_release_id
                  AND pllv1.po_line_id = plv.po_line_id
                  AND nvl(prv.cancel_flag, 'N') != 'Y'
                  AND nvl(pllv1.cancel_flag, 'N') != 'Y')) quantity_line,
             (plv.quantity - pllv.quantity_billed - pllv.quantity_cancelled) quantity_ship,
             --PLLV.QUANTITY QUANTITY_SHIP,
             0 quantity_billed_ship,
             0 quantity_cancelled_ship,
             (pllv.quantity_received - pllv.quantity_billed) quantity_received_ship,
             pllv.receipt_days_exception_code receipt_days_exc_code_ship,
             pllv.receipt_required_flag receipt_required_flag_ship,
             pllv.receive_close_tolerance receive_close_tolerance_ship,
             (SELECT meaning
                FROM fnd_lookup_values_vl flvv
               WHERE lookup_type = 'RCV_ROUTING_HEADERS'
                 AND flvv.lookup_code = pllv.receiving_routing_id) receiving_routing_ship,
             pllv.attribute1 shipment_attribute1,
             pllv.attribute2 shipment_attribute2,
             pllv.attribute3 shipment_attribute3,
             pllv.attribute4 shipment_attribute4,
             pllv.attribute5 shipment_attribute5,
             pllv.attribute6 shipment_attribute6,
             pllv.attribute7 shipment_attribute7,
             pllv.attribute8 shipment_attribute8,
             pllv.attribute9 shipment_attribute9,
             pllv.attribute10 shipment_attribute10,
             pllv.attribute11 shipment_attribute11,
             pllv.attribute12 shipment_attribute12,
             pllv.attribute13 shipment_attribute13,
             pllv.attribute14 shipment_attribute14,
             pllv.attribute15 shipment_attribute15,
             pllv.attribute_category shipment_attribute_category,
             pllv.shipment_num shipment_num_ship,
             pllv.shipment_type shipment_type_ship,
             pllv.ship_to_location_code ship_to_location_ship,
             pllv.ship_to_organization_code ship_to_org_code_ship,
             plv.type_1099,
             (SELECT muom.uom_code
                FROM mtl_units_of_measure    muom,
                     mtl_units_of_measure_tl muomt
               WHERE muom.uom_code = muomt.uom_code
                 AND muomt.LANGUAGE = userenv('LANG')
                 AND muom.unit_of_measure(+) = plv.unit_meas_lookup_code
                 AND nvl(muom.disable_date, SYSDATE + 1) >= SYSDATE) unit_of_measure_line,
             (SELECT muom.uom_code
                FROM mtl_units_of_measure    muom,
                     mtl_units_of_measure_tl muomt
               WHERE muom.uom_code = muomt.uom_code
                 AND muomt.LANGUAGE = userenv('LANG')
                 AND muom.unit_of_measure(+) = pllv.unit_meas_lookup_code
                 AND nvl(muom.disable_date, SYSDATE + 1) >= SYSDATE) unit_of_measure_ship,
             plv.unit_price,
             pllv.vendor_product_num,
             pllv.price_discount price_discount_ship,
             -- pllv.start_date,
             phv.start_date,
             --  pllv.end_date,
             phv.end_date,
             pllv.price_override,
             pllv.lead_time lead_time_ship,
             pllv.lead_time_unit lead_time_unit_ship,
             plv.matching_basis,
             -- PDV.ACCRUE_ON_RECEIPT_FLAG ACCRUE_ON_RECEIPT_FLAG_DIST,
             /*(SELECT GCCK.CONCATENATED_SEGMENTS
                                                                                                                                                                                                                            FROM GL_CODE_COMBINATIONS_KFV GCCK
                                                                                                                                                                                                                           WHERE GCCK.CODE_COMBINATION_ID = PDV.ACCRUAL_ACCOUNT_ID) ACCRUAL_ACCOUNT,
                                                                                                                                                                                                                         (SELECT SEGMENT1
                                                                                                                                                                                                                            FROM GL_CODE_COMBINATIONS_KFV GCCK
                                                                                                                                                                                                                           WHERE GCCK.CODE_COMBINATION_ID = PDV.ACCRUAL_ACCOUNT_ID) ACCRUAL_ACCT_SEGMENT1,
                                                                                                                                                                                                                         (SELECT SEGMENT2
                                                                                                                                                                                                                            FROM GL_CODE_COMBINATIONS_KFV GCCK
                                                                                                                                                                                                                           WHERE GCCK.CODE_COMBINATION_ID = PDV.ACCRUAL_ACCOUNT_ID) ACCRUAL_ACCT_SEGMENT2,
                                                                                                                                                                                                                         (SELECT SEGMENT3
                                                                                                                                                                                                                            FROM GL_CODE_COMBINATIONS_KFV GCCK
                                                                                                                                                                                                                           WHERE GCCK.CODE_COMBINATION_ID = PDV.ACCRUAL_ACCOUNT_ID) ACCRUAL_ACCT_SEGMENT3,
                                                                                                                                                                                                                         (SELECT SEGMENT5
                                                                                                                                                                                                                            FROM GL_CODE_COMBINATIONS_KFV GCCK
                                                                                                                                                                                                                           WHERE GCCK.CODE_COMBINATION_ID = PDV.ACCRUAL_ACCOUNT_ID) ACCRUAL_ACCT_SEGMENT5,
                                                                                                                                                                                                                         (SELECT SEGMENT6
                                                                                                                                                                                                                            FROM GL_CODE_COMBINATIONS_KFV GCCK
                                                                                                                                                                                                                           WHERE GCCK.CODE_COMBINATION_ID = PDV.ACCRUAL_ACCOUNT_ID) ACCRUAL_ACCT_SEGMENT6,
                                                                                                                                                                                                                         (SELECT SEGMENT7
                                                                                                                                                                                                                            FROM GL_CODE_COMBINATIONS_KFV GCCK
                                                                                                                                                                                                                           WHERE GCCK.CODE_COMBINATION_ID = PDV.ACCRUAL_ACCOUNT_ID) ACCRUAL_ACCT_SEGMENT7,
                                                                                                                                                                                                                         (SELECT SEGMENT10
                                                                                                                                                                                                                            FROM GL_CODE_COMBINATIONS_KFV GCCK
                                                                                                                                                                                                                           WHERE GCCK.CODE_COMBINATION_ID = PDV.ACCRUAL_ACCOUNT_ID) ACCRUAL_ACCT_SEGMENT10,
                                                                                                                                                                                                                         PDV.AMOUNT_BILLED,
                                                                                                                                                                                                                         PDV.AMOUNT_ORDERED,
                                                                                                                                                                                                                         PDV.ATTRIBUTE1 ATTRIBUTE1_DIST,
                                                                                                                                                                                                                         PDV.ATTRIBUTE2 ATTRIBUTE2_DIST,
                                                                                                                                                                                                                         PDV.ATTRIBUTE3 ATTRIBUTE3_DIST,
                                                                                                                                                                                                                         PDV.ATTRIBUTE4 ATTRIBUTE4_DIST,
                                                                                                                                                                                                                         PDV.ATTRIBUTE5 ATTRIBUTE5_DIST,
                                                                                                                                                                                                                         PDV.ATTRIBUTE6 ATTRIBUTE6_DIST,
                                                                                                                                                                                                                         PDV.ATTRIBUTE7 ATTRIBUTE7_DIST,
                                                                                                                                                                                                                         PDV.ATTRIBUTE8 ATTRIBUTE8_DIST,
                                                                                                                                                                                                                         PDV.ATTRIBUTE9 ATTRIBUTE9_DIST,
                                                                                                                                                                                                                         PDV.ATTRIBUTE10 ATTRIBUTE10_DIST,
                                                                                                                                                                                                                         PDV.ATTRIBUTE11 ATTRIBUTE11_DIST,
                                                                                                                                                                                                                         PDV.ATTRIBUTE12 ATTRIBUTE12_DIST,
                                                                                                                                                                                                                         PDV.ATTRIBUTE13 ATTRIBUTE13_DIST,
                                                                                                                                                                                                                         PDV.ATTRIBUTE14 ATTRIBUTE14_DIST,
                                                                                                                                                                                                                         PDV.ATTRIBUTE15 ATTRIBUTE15_DIST,
                                                                                                                                                                                                                         PDV.ATTRIBUTE_CATEGORY ATTRIBUTE_CATEGORY_DIST,
                                                                                                                                                                                                                         (SELECT GCCK.CONCATENATED_SEGMENTS
                                                                                                                                                                                                                            FROM GL_CODE_COMBINATIONS_KFV GCCK
                                                                                                                                                                                                                           WHERE GCCK.CODE_COMBINATION_ID = PDV.BUDGET_ACCOUNT_ID) BUDGET_ACCOUNT,
                                                                                                                                                                                                                         (SELECT SEGMENT1
                                                                                                                                                                                                                            FROM GL_CODE_COMBINATIONS_KFV GCCK
                                                                                                                                                                                                                           WHERE GCCK.CODE_COMBINATION_ID = PDV.BUDGET_ACCOUNT_ID) BUDGET_ACCT_SEGMENT1,
                                                                                                                                                                                                                         (SELECT SEGMENT2
                                                                                                                                                                                                                            FROM GL_CODE_COMBINATIONS_KFV GCCK
                                                                                                                                                                                                                           WHERE GCCK.CODE_COMBINATION_ID = PDV.BUDGET_ACCOUNT_ID) BUDGET_ACCT_SEGMENT2,
                                                                                                                                                                                                                         (SELECT SEGMENT3
                                                                                                                                                                                                                            FROM GL_CODE_COMBINATIONS_KFV GCCK
                                                                                                                                                                                                                           WHERE GCCK.CODE_COMBINATION_ID = PDV.BUDGET_ACCOUNT_ID) BUDGET_ACCT_SEGMENT3,
                                                                                                                                                                                                                         (SELECT SEGMENT5
                                                                                                                                                                                                                            FROM GL_CODE_COMBINATIONS_KFV GCCK
                                                                                                                                                                                                                           WHERE GCCK.CODE_COMBINATION_ID = PDV.BUDGET_ACCOUNT_ID) BUDGET_ACCT_SEGMENT5,
                                                                                                                                                                                                                         (SELECT SEGMENT6
                                                                                                                                                                                                                            FROM GL_CODE_COMBINATIONS_KFV GCCK
                                                                                                                                                                                                                           WHERE GCCK.CODE_COMBINATION_ID = PDV.BUDGET_ACCOUNT_ID) BUDGET_ACCT_SEGMENT6,
                                                                                                                                                                                                                         (SELECT SEGMENT7
                                                                                                                                                                                                                            FROM GL_CODE_COMBINATIONS_KFV GCCK
                                                                                                                                                                                                                           WHERE GCCK.CODE_COMBINATION_ID = PDV.BUDGET_ACCOUNT_ID) BUDGET_ACCT_SEGMENT7,
                                                                                                                                                                                                                         (SELECT SEGMENT10
                                                                                                                                                                                                                            FROM GL_CODE_COMBINATIONS_KFV GCCK
                                                                                                                                                                                                                           WHERE GCCK.CODE_COMBINATION_ID = PDV.BUDGET_ACCOUNT_ID) BUDGET_ACCT_SEGMENT10,
                                                                                                                                                                                                                         (SELECT GCCK.CONCATENATED_SEGMENTS
                                                                                                                                                                                                                            FROM GL_CODE_COMBINATIONS_KFV GCCK
                                                                                                                                                                                                                           WHERE GCCK.CODE_COMBINATION_ID = PDV.CODE_COMBINATION_ID) CHARGE_ACCOUNT,
                                                                                                                                                                                                                         (SELECT SEGMENT1
                                                                                                                                                                                                                            FROM GL_CODE_COMBINATIONS_KFV GCCK
                                                                                                                                                                                                                           WHERE GCCK.CODE_COMBINATION_ID = PDV.CODE_COMBINATION_ID) CHARGE_ACCT_SEGMENT1,
                                                                                                                                                                                                                         (SELECT SEGMENT2
                                                                                                                                                                                                                            FROM GL_CODE_COMBINATIONS_KFV GCCK
                                                                                                                                                                                                                           WHERE GCCK.CODE_COMBINATION_ID = PDV.CODE_COMBINATION_ID) CHARGE_ACCT_SEGMENT2,
                                                                                                                                                                                                                         (SELECT SEGMENT3
                                                                                                                                                                                                                            FROM GL_CODE_COMBINATIONS_KFV GCCK
                                                                                                                                                                                                                           WHERE GCCK.CODE_COMBINATION_ID = PDV.CODE_COMBINATION_ID) CHARGE_ACCT_SEGMENT3,
                                                                                                                                                                                                                         (SELECT SEGMENT5
                                                                                                                                                                                                                            FROM GL_CODE_COMBINATIONS_KFV GCCK
                                                                                                                                                                                                                           WHERE GCCK.CODE_COMBINATION_ID = PDV.CODE_COMBINATION_ID) CHARGE_ACCT_SEGMENT5,
                                                                                                                                                                                                                         (SELECT SEGMENT6
                                                                                                                                                                                                                            FROM GL_CODE_COMBINATIONS_KFV GCCK
                                                                                                                                                                                                                           WHERE GCCK.CODE_COMBINATION_ID = PDV.CODE_COMBINATION_ID) CHARGE_ACCT_SEGMENT6,
                                                                                                                                                                                                                         (SELECT SEGMENT7
                                                                                                                                                                                                                            FROM GL_CODE_COMBINATIONS_KFV GCCK
                                                                                                                                                                                                                           WHERE GCCK.CODE_COMBINATION_ID = PDV.CODE_COMBINATION_ID) CHARGE_ACCT_SEGMENT7,
                                                                                                                                                                                                                         (SELECT SEGMENT10
                                                                                                                                                                                                                            FROM GL_CODE_COMBINATIONS_KFV GCCK
                                                                                                                                                                                                                           WHERE GCCK.CODE_COMBINATION_ID = PDV.CODE_COMBINATION_ID) CHARGE_ACCT_SEGMENT10,
                                                                                                                                                                                                                         (SELECT HLA.LOCATION_CODE
                                                                                                                                                                                                                            FROM HR_LOCATIONS_ALL HLA
                                                                                                                                                                                                                           WHERE HLA.BILL_TO_SITE_FLAG = 'Y'
                                                                                                                                                                                                                             AND HLA.LOCATION_ID = PDV.DELIVER_TO_LOCATION_ID) DELIVER_TO_LOCATION,
                                                                                                                                                                                                                         (SELECT PAPF.FULL_NAME
                                                                                                                                                                                                                            FROM PER_ALL_PEOPLE_F PAPF
                                                                                                                                                                                                                           WHERE PAPF.PERSON_ID = PDV.DELIVER_TO_PERSON_ID
                                                                                                                                                                                                                             AND SYSDATE BETWEEN
                                                                                                                                                                                                                                 NVL(PAPF.EFFECTIVE_START_DATE, SYSDATE) AND
                                                                                                                                                                                                                                 NVL(PAPF.EFFECTIVE_END_DATE, SYSDATE + 1)) DELIVER_TO_PERSON,
                                                                                                                                                                                                                         PDV.DESTINATION_CONTEXT,
                                                                                                                                                                                                                         (SELECT ORGANIZATION_NAME
                                                                                                                                                                                                                            FROM ORG_ORGANIZATION_DEFINITIONS
                                                                                                                                                                                                                           WHERE ORGANIZATION_ID = PDV.DESTINATION_ORGANIZATION_ID) DESTINATION_ORGANIZATION,
                                                                                                                                                                                                                         PDV.DESTINATION_SUBINVENTORY,
                                                                                                                                                                                                                         PDV.DESTINATION_TYPE_CODE,
                                                                                                                                                                                                                         PDV.DISTRIBUTION_NUM,
                                                                                                                                                                                                                         PDV.ENCUMBERED_AMOUNT,
                                                                                                                                                                                                                         PDV.ENCUMBERED_FLAG,
                                                                                                                                                                                                                         PDV.EXPENDITURE_ITEM_DATE,
                                                                                                                                                                                                                         (SELECT HOU.NAME
                                                                                                                                                                                                                            FROM HR_ORGANIZATION_UNITS       HOU,
                                                                                                                                                                                                                                 HR_ORGANIZATION_INFORMATION HOI
                                                                                                                                                                                                                           WHERE HOU.ORGANIZATION_ID = HOI.ORGANIZATION_ID
                                                                                                                                                                                                                             AND HOU.ORGANIZATION_ID = PDV.EXPENDITURE_ORGANIZATION_ID
                                                                                                                                                                                                                             AND TRUNC(SYSDATE) BETWEEN
                                                                                                                                                                                                                                 NVL(TRUNC(HOU.DATE_FROM), TRUNC(SYSDATE) - 1) AND
                                                                                                                                                                                                                                 NVL(TRUNC(HOU.DATE_TO), TRUNC(SYSDATE) + 1)
                                                                                                                                                                                                                             AND HOI.ORG_INFORMATION1 = 'PA_EXPENDITURE_ORG'
                                                                                                                                                                                                                             AND NVL(HOI.ORG_INFORMATION2, 'N') = 'Y') EXPENDITURE_ORGANIZATION,
                                                                                                                                                                                                                         PDV.EXPENDITURE_TYPE,
                                                                                                                                                                                                                         PDV.FAILED_FUNDS_LOOKUP_CODE,
                                                                                                                                                                                                                         PDV.GL_CANCELLED_DATE,
                                                                                                                                                                                                                         PDV.GL_ENCUMBERED_DATE,
                                                                                                                                                                                                                         PDV.GL_ENCUMBERED_PERIOD_NAME,
                                                                                                                                                                                                                         PDV.NONRECOVERABLE_TAX,
                                                                                                                                                                                                                         PDV.PREVENT_ENCUMBRANCE_FLAG,
                                                                                                                                                                                                                         (SELECT PPA.NAME
                                                                                                                                                                                                                            FROM PA_PROJECTS_ALL PPA
                                                                                                                                                                                                                           WHERE PPA.PROJECT_ID = PDV.PROJECT_ID) PROJECT,
                                                                                                                                                                                                                         PDV.PROJECT_ACCOUNTING_CONTEXT, /*
                                                                                                                                                                                                                                        PDV.QUANTITY_BILLED,
                                                                                                                                                                                                                                        PDV.QUANTITY_CANCELLED,*/
             --PDV.QUANTITY_DELIVERED*/
             /* 0 QUANTITY_BILLED_DIST,
                                                                                                                                                                                                                         0 QUANTITY_CANCELLED_DIST,*/
             /*(PDV.QUANTITY_ORDERED - PDV.QUANTITY_BILLED -
                                                                                                                                                                                                                         PDV.QUANTITY_CANCELLED) QUANTITY_ORDERED_DIST,
                                                                                                                                                                                                                         PDV.RATE RATE_DIST,
                                                                                                                                                                                                                         PDV.RATE_DATE RATE_DATE_DIST,
                                                                                                                                                                                                                         PDV.RECOVERABLE_TAX,
                                                                                                                                                                                                                         PDV.RECOVERY_RATE,
                                                                                                                                                                                                                         (SELECT GL.NAME
                                                                                                                                                                                                                            FROM GL_LEDGERS GL
                                                                                                                                                                                                                           WHERE GL.LEDGER_ID = PDV.SET_OF_BOOKS_ID) SET_OF_BOOKS,
                                                                                                                                                                                                                         (SELECT PT.TASK_NAME
                                                                                                                                                                                                                            FROM PA_TASKS PT
                                                                                                                                                                                                                           WHERE PT.PROJECT_ID = PDV.PROJECT_ID
                                                                                                                                                                                                                             AND PT.TASK_ID = PDV.TASK_ID) TASK,
                                                                                                                                                                                                                         PDV.TAX_RECOVERY_OVERRIDE_FLAG,
                                                                                                                                                                                                                         (SELECT GCCK.CONCATENATED_SEGMENTS
                                                                                                                                                                                                                            FROM GL_CODE_COMBINATIONS_KFV GCCK
                                                                                                                                                                                                                           WHERE GCCK.CODE_COMBINATION_ID = PDV.VARIANCE_ACCOUNT_ID) VARIANCE_ACCOUNT,
                                                                                                                                                                                                                         (SELECT SEGMENT1
                                                                                                                                                                                                                            FROM GL_CODE_COMBINATIONS_KFV GCCK
                                                                                                                                                                                                                           WHERE GCCK.CODE_COMBINATION_ID = PDV.VARIANCE_ACCOUNT_ID) VARIANCE_ACCT_SEGMENT1,
                                                                                                                                                                                                                         (SELECT SEGMENT2
                                                                                                                                                                                                                            FROM GL_CODE_COMBINATIONS_KFV GCCK
                                                                                                                                                                                                                           WHERE GCCK.CODE_COMBINATION_ID = PDV.VARIANCE_ACCOUNT_ID) VARIANCE_ACCT_SEGMENT2,
                                                                                                                                                                                                                         (SELECT SEGMENT3
                                                                                                                                                                                                                            FROM GL_CODE_COMBINATIONS_KFV GCCK
                                                                                                                                                                                                                           WHERE GCCK.CODE_COMBINATION_ID = PDV.VARIANCE_ACCOUNT_ID) VARIANCE_ACCT_SEGMENT3,
                                                                                                                                                                                                                         (SELECT SEGMENT5
                                                                                                                                                                                                                            FROM GL_CODE_COMBINATIONS_KFV GCCK
                                                                                                                                                                                                                           WHERE GCCK.CODE_COMBINATION_ID = PDV.VARIANCE_ACCOUNT_ID) VARIANCE_ACCT_SEGMENT5,
                                                                                                                                                                                                                         (SELECT SEGMENT6
                                                                                                                                                                                                                            FROM GL_CODE_COMBINATIONS_KFV GCCK
                                                                                                                                                                                                                           WHERE GCCK.CODE_COMBINATION_ID = PDV.VARIANCE_ACCOUNT_ID) VARIANCE_ACCT_SEGMENT6,
                                                                                                                                                                                                                         (SELECT SEGMENT7
                                                                                                                                                                                                                            FROM GL_CODE_COMBINATIONS_KFV GCCK
                                                                                                                                                                                                                           WHERE GCCK.CODE_COMBINATION_ID = PDV.VARIANCE_ACCOUNT_ID) VARIANCE_ACCT_SEGMENT7,
                                                                                                                                                                                                                         (SELECT SEGMENT10
                                                                                                                                                                                                                            FROM GL_CODE_COMBINATIONS_KFV GCCK
                                                                                                                                                                                                                           WHERE GCCK.CODE_COMBINATION_ID = PDV.VARIANCE_ACCOUNT_ID) VARIANCE_ACCT_SEGMENT10,*/
             pllv.match_option
        FROM po_headers_v phv, po_lines_v plv, po_line_locations_v pllv
       WHERE phv.po_header_id = plv.po_header_id
            --AND plv.po_line_id = pllv.po_line_id(+)
         AND pllv.po_header_id(+) = phv.po_header_id --new change
         AND nvl(phv.cancel_flag, 'N') <> 'Y'
         AND nvl(plv.closed_date, to_date('01-APR-2016', 'DD-MON-YYYY')) >=
             to_date('01-APR-2016', 'DD-MON-YYYY')
         AND nvl(plv.expiration_date, to_date('01-APR-2016', 'DD-MON-YYYY')) >=
             to_date('01-APR-2016', 'DD-MON-YY')
         AND phv.org_id = l_org_id
         AND phv.authorization_status = 'APPROVED'
         AND nvl(plv.cancel_flag, 'N') = 'N'
         AND nvl(upper(phv.closed_code), 'OPEN') IN
             ('OPEN', 'CLOSED FOR INVOICE', 'CLOSED FOR RECEIVING')
         AND nvl(upper(pllv.closed_code), 'XXX') NOT IN
             ('CLOSED', 'FINALLY CLOSED')
         AND (plv.quantity_committed -
             (SELECT SUM(pllv1. quantity_received)
                 FROM po_line_locations_all pllv1, po_releases_v prv
                WHERE phv.po_header_id = prv.po_header_id
                  AND pllv1.po_release_id IS NOT NULL
                  AND prv.po_release_id = pllv1.po_release_id
                  AND pllv1.po_line_id = plv.po_line_id
                  AND nvl(prv.cancel_flag, 'N') != 'Y'
                  AND nvl(pllv1.cancel_flag, 'N') != 'Y')) > 0
         AND phv.doc_type_name = 'Blanket Purchase Agreement'
       ORDER BY 1, 2, 3;

    CURSOR c_data IS
      SELECT * --MATCH_OPTION,RECEIPT_REQUIRED_FLAG_SHIP
      FROM   xxs3_ptp_po;

    CURSOR c_transform IS
      SELECT *
      FROM   xxs3_ptp_po
      WHERE  process_flag IN ('Q', 'Y','N');

    l_make_buy        VARCHAR2(10);
    l_bom             VARCHAR2(10);
    l_err_code        VARCHAR2(4000);
    l_err_msg         VARCHAR2(4000);
    l_flag            VARCHAR2(1);
    l_s3_gl_string    VARCHAR2(2000);
    p_acc_first_digit NUMBER;

  BEGIN

    x_retcode := 0;
    x_errbuf  := 'COMPLETE';
    --l_file    := utl_file.fopen('/UtlFiles/shared/DEV', 'XXS3_PTP_PO_EXTRACT_DATA.CSV', 'w', 32767);
    BEGIN
      /* Get the file path from the lookup */
      SELECT TRIM(' ' FROM meaning)
      INTO   l_file_path
      FROM   fnd_lookup_values_vl
      WHERE  lookup_type = 'XXS3_ITEM_OUT_FILE_PATH';

      /* Get the file name  */
      l_file_name := 'Open_PO_Extract' || '_' || SYSDATE || '.xls';

      /* Get the utl file open*/
      l_file := utl_file.fopen(l_file_path, l_file_name, 'W', 32767); /* Utl file open */
    EXCEPTION
      WHEN OTHERS THEN
        fnd_file.put_line(fnd_file.log, 'Invalid File Path' || SQLERRM);
        NULL;
    END;

    mo_global.init('PO');
    mo_global.set_policy_context('S', l_org_id);

    EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.xxs3_ptp_po';

    FOR i IN c_po_extract LOOP

      INSERT INTO xxs3_ptp_po
      VALUES
        (xxs3_ptp_po_seq.NEXTVAL,
         SYSDATE,
         'N',
         NULL,
         NULL,
         i.po_header_id,
         i.acceptance_due_date,
         i.agent_name,
         NULL,
         i.agent_id,
         i.amount_limit,
         i.approved_date,
         i.attribute1_hdr,
         i.attribute2_hdr,
         i.attribute3_hdr,
         i.attribute4_hdr,
         i.attribute5_hdr,
         i.attribute6_hdr,
         i.attribute7_hdr,
         i.attribute8_hdr,
         i.attribute9_hdr,
         i.attribute10_hdr,
         i.attribute11_hdr,
         i.attribute12_hdr,
         i.attribute13_hdr,
         i.attribute14_hdr,
         i.attribute15_hdr,
         i.attribute_category_hdr,
         i.bill_to_location,
         NULL,
         i.change_summary,
         i.currency_code,
         i.segment1,
         --phv.DOCUMENT_TYPE_CODE,
         i.doc_type_name,
         --phv.DOCUMENT_SUBTYPE,
         --phv.EFFECTIVE_DATE,
         i.creation_date_disp, --need to verify
         i.freight_carrier_hdr,
         NULL,
         i.fob_hdr, --new field
         NULL,
         --i.freight_terms_hdr,
         NULL,
         NULL,
         i.global_agreement_flag,
         i.min_release_amount_hdr,
         i.note_to_receiver_hdr,
         i.note_to_vendor_hdr,
         i.operating_unit_name,
         NULL,
         i.payment_terms_hdr,
         NULL,
         NULL, --i.printed_date,
         NULL, --i.print_count,
         i.rate_hdr,
         i.rate_date_hdr,
         i.rate_type,
         NULL, --i.revised_date,
         NULL, -- i.revision_num,
         i.shipping_control,
         i.ship_to_location_hdr,
         NULL,
         i.vendor_contact,
         i.vendor_name,
         i.vendor_num,
         i.vendor_site_code,
         i.acceptance_required_flag,
         i.confirming_order_flag,
         --line and line locations
         i.accrue_on_receipt_flag_ship,
         i.allow_sub_receipts_flag_ship,
         i.amount_line,
         i.amount_ship,
         NULL, --i.base_unit_price,
         i.category,
         NULL,
         i.committed_amount,
         i.days_early_rec_allowed_ship,
         i.days_late_receipt_allowed_ship,
         i.drop_ship_flag,
         i.enforce_ship_to_loc_code_ship,
         i.expiration_date,
         i.fob_ship,
         i.freight_carrier_ship,
         i.freight_terms_ship,
         i.hazard_class,
         i.inspection_required_flag_ship,
         i.invoice_close_tolerance_ship,
         i.item_number,
         i.item_description,
         i.item_revision,
         i.job_name, --need to fetch job_name
         i.line_attribute1,
         i.line_attribute2,
         i.line_attribute3,
         i.line_attribute4,
         i.line_attribute5,
         i.line_attribute6,
         i.line_attribute7,
         i.line_attribute8,
         i.line_attribute9,
         i.line_attribute10,
         i.line_attribute11,
         i.line_attribute12,
         i.line_attribute13,
         i.line_attribute14,
         i.line_attribute15,
         i.line_attribute_category_lines,
         i.price_type,
         i.allow_price_override_flag,
         i.un_number,
         i.capital_expense_flag,
         i.transaction_reason_code,
         --I.QUANTITY_COMMITTED,
         i.not_to_exceed_price,
         i.line_num,
         i.line_type,
         i.list_price_per_unit,
         i.market_price,
         i.min_release_amount_line,
         i.need_by_date_ship,
         i.negotiated_by_preparer_flag,
         i.note_to_receiver_ship,
         i.note_to_vendor_line,
         i.over_tolerance_error_flag,
         i.payment_terms_ship,
         NULL,
         i.preferred_grade_line,
         i.preferred_grade_ship,
         i.price_break_lookup_code,
         i.promised_date_ship,
         --QTY_RCV_EXCEPTION_CODE_LINE ,
         i.qty_rcv_exception_code_ship,
         i.qty_rcv_tolerance_line,
         i.qty_rcv_tolerance_ship,
         i.quantity_line,
         i.quantity_ship,
         i.quantity_billed_ship,
         i.quantity_cancelled_ship,
         i.quantity_received_ship,
         i.receipt_days_exc_code_ship,
         i.receipt_required_flag_ship,
         --NULL,
         i.receive_close_tolerance_ship,
         i.receiving_routing_ship, --need to fetch value
         i.shipment_attribute1,
         i.shipment_attribute2,
         i.shipment_attribute3,
         i.shipment_attribute4,
         i.shipment_attribute5,
         i.shipment_attribute6,
         i.shipment_attribute7,
         i.shipment_attribute8,
         i.shipment_attribute9,
         i.shipment_attribute10,
         i.shipment_attribute11,
         i.shipment_attribute12,
         i.shipment_attribute13,
         i.shipment_attribute14,
         i.shipment_attribute15,
         i.shipment_attribute_category,
         i.shipment_num_ship,
         i.shipment_type_ship,
         i.ship_to_location_ship,
         NULL,
         i.ship_to_org_code_ship,
         NULL,
         i.type_1099,
         i.unit_of_measure_line,
         i.unit_of_measure_ship,
         i.unit_price,
         i.vendor_product_num,
         i.price_discount_ship,
         i.start_date,
         i.end_date,
         i.price_override,
         i.lead_time_ship,
         i.lead_time_unit_ship,
         i.matching_basis,
         i.accrue_on_receipt_flag_dist,
         i.accrual_account,
         NULL,
         i.accrual_acct_segment1,
         i.accrual_acct_segment2,
         i.accrual_acct_segment3,
         i.accrual_acct_segment5,
         i.accrual_acct_segment6,
         i.accrual_acct_segment7,
         i.accrual_acct_segment10,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         i.amount_billed,
         i.amount_ordered,
         i.attribute1_dist,
         i.attribute2_dist,
         i.attribute3_dist,
         i.attribute4_dist,
         i.attribute5_dist,
         i.attribute6_dist,
         i.attribute7_dist,
         i.attribute8_dist,
         i.attribute9_dist,
         i.attribute10_dist,
         i.attribute11_dist,
         i.attribute12_dist,
         i.attribute13_dist,
         i.attribute14_dist,
         i.attribute15_dist,
         i.attribute_category_dist,
         --I.BUDGET_ACCOUNT,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         /*I.BUDGET_ACCT_SEGMENT1,
                                                                                                                                       I.BUDGET_ACCT_SEGMENT2,
                                                                                                                                       I.BUDGET_ACCT_SEGMENT3,
                                                                                                                                       I.BUDGET_ACCT_SEGMENT5,
                                                                                                                                       I.BUDGET_ACCT_SEGMENT6,
                                                                                                                                       I.BUDGET_ACCT_SEGMENT7,
                                                                                                                                       I.BUDGET_ACCT_SEGMENT10,*/
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         i.charge_account,
         NULL,
         i.charge_acct_segment1,
         i.charge_acct_segment2,
         i.charge_acct_segment3,
         i.charge_acct_segment5,
         i.charge_acct_segment6,
         i.charge_acct_segment7,
         i.charge_acct_segment10,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         i.deliver_to_location,
         NULL,
         i.deliver_to_person,
         i.destination_context,
         i.destination_organization,
         NULL,
         i.destination_subinventory,
         i.destination_type_code,
         i.distribution_num,
         --i.encumbered_amount,
         NULL,
         --i.encumbered_flag,
         NULL,
         i.expenditure_item_date,
         i.expenditure_organization,
         NULL,
         i.expenditure_type,
         NULL,
         --i.failed_funds_lookup_code,
         NULL,
         i.gl_cancelled_date,
         --i.gl_encumbered_date,
         NULL,
         --i.gl_encumbered_period_name,
         NULL,
         i.nonrecoverable_tax,
         i.prevent_encumbrance_flag,
         i.project,
         NULL,
         i.project_accounting_context,
         /*I.QUANTITY_BILLED,
                                                                                                                                       I.QUANTITY_CANCELLED,
                                                                                                                                       I.QUANTITY_DELIVERED,
                                                                                                                                       I.QUANTITY_ORDERED,*/
         i.quantity_billed_dist,
         i.quantity_cancelled_dist,
         i.quantity_ordered_dist,
         i.rate_dist,
         i.rate_date_dist,
         i.recoverable_tax,
         i.recovery_rate,
         i.set_of_books,
         NULL,
         i.task,
         NULL,
         i.tax_recovery_override_flag,
         i.variance_account,
         NULL,
         i.variance_acct_segment1,
         i.variance_acct_segment2,
         i.variance_acct_segment3,
         i.variance_acct_segment5,
         i.variance_acct_segment6,
         i.variance_acct_segment7,
         i.variance_acct_segment10,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         i.match_option,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         i.vendor_contact_id,
         i.task_id,
         NULL);
    END LOOP;

    --BPA insert
    FOR i IN c_bpa LOOP
      INSERT INTO xxs3_ptp_po
      VALUES
        (xxs3_ptp_po_seq.NEXTVAL,
         SYSDATE,
         'N',
         NULL,
         NULL,
         i.po_header_id,
         i.acceptance_due_date,
         i.agent_name,
         NULL,
         i.agent_id,
         i.amount_limit,
         i.approved_date,
         i.attribute1_hdr,
         i.attribute2_hdr,
         i.attribute3_hdr,
         i.attribute4_hdr,
         i.attribute5_hdr,
         i.attribute6_hdr,
         i.attribute7_hdr,
         i.attribute8_hdr,
         i.attribute9_hdr,
         i.attribute10_hdr,
         i.attribute11_hdr,
         i.attribute12_hdr,
         i.attribute13_hdr,
         i.attribute14_hdr,
         i.attribute15_hdr,
         i.attribute_category_hdr,
         i.bill_to_location,
         NULL,
         i.change_summary,
         i.currency_code,
         i.segment1,
         --phv.DOCUMENT_TYPE_CODE,
         i.doc_type_name,
         --phv.DOCUMENT_SUBTYPE,
         --phv.EFFECTIVE_DATE,
         i.creation_date_disp, --need to verify
         i.freight_carrier_hdr,
         NULL,
         i.fob_hdr, --new field
         NULL,
         --i.freight_terms_hdr,
         NULL,
         NULL,
         i.global_agreement_flag,
         i.min_release_amount_hdr,
         i.note_to_receiver_hdr,
         i.note_to_vendor_hdr,
         i.operating_unit_name,
         NULL,
         i.payment_terms_hdr,
         NULL,
         NULL, --i.printed_date,
         NULL, --i.print_count,
         i.rate_hdr,
         i.rate_date_hdr,
         i.rate_type,
         NULL, --i.revised_date,
         NULL, --i.revision_num,
         i.shipping_control,
         i.ship_to_location_hdr,
         NULL,
         i.vendor_contact,
         i.vendor_name,
         i.vendor_num,
         i.vendor_site_code,
         i.acceptance_required_flag,
         i.confirming_order_flag,
         --line and line locations
         i.accrue_on_receipt_flag_ship,
         i.allow_sub_receipts_flag_ship,
         i.amount_line,
         i.amount_ship,
         NULL,--i.base_unit_price,
         i.category,
         NULL,
         i.committed_amount,
         i.days_early_rec_allowed_ship,
         i.days_late_receipt_allowed_ship,
         i.drop_ship_flag,
         i.enforce_ship_to_loc_code_ship,
         i.expiration_date,
         i.fob_ship,
         i.freight_carrier_ship,
         i.freight_terms_ship,
         i.hazard_class,
         i.inspection_required_flag_ship,
         i.invoice_close_tolerance_ship,
         i.item_number,
         i.item_description,
         i.item_revision,
         i.job_name, --need to fetch job_name
         i.line_attribute1,
         i.line_attribute2,
         i.line_attribute3,
         i.line_attribute4,
         i.line_attribute5,
         i.line_attribute6,
         i.line_attribute7,
         i.line_attribute8,
         i.line_attribute9,
         i.line_attribute10,
         i.line_attribute11,
         i.line_attribute12,
         i.line_attribute13,
         i.line_attribute14,
         i.line_attribute15,
         i.line_attribute_category_lines,
         i.price_type,
         i.allow_price_override_flag,
         i.un_number,
         i.capital_expense_flag,
         i.transaction_reason_code,
         --I.QUANTITY_COMMITTED,
         i.not_to_exceed_price,
         i.line_num,
         i.line_type,
         i.list_price_per_unit,
         i.market_price,
         i.min_release_amount_line,
         i.need_by_date_ship,
         i.negotiated_by_preparer_flag,
         i.note_to_receiver_ship,
         i.note_to_vendor_line,
         i.over_tolerance_error_flag,
         i.payment_terms_ship,
         NULL,
         i.preferred_grade_line,
         i.preferred_grade_ship,
         i.price_break_lookup_code,
         i.promised_date_ship,
         --QTY_RCV_EXCEPTION_CODE_LINE ,
         i.qty_rcv_exception_code_ship,
         i.qty_rcv_tolerance_line,
         i.qty_rcv_tolerance_ship,
         i.quantity_line,
         i.quantity_ship,
         i.quantity_billed_ship,
         i.quantity_cancelled_ship,
         i.quantity_received_ship,
         i.receipt_days_exc_code_ship,
         i.receipt_required_flag_ship,
         --NULL,
         i.receive_close_tolerance_ship,
         i.receiving_routing_ship, --need to fetch value
         i.shipment_attribute1,
         i.shipment_attribute2,
         i.shipment_attribute3,
         i.shipment_attribute4,
         i.shipment_attribute5,
         i.shipment_attribute6,
         i.shipment_attribute7,
         i.shipment_attribute8,
         i.shipment_attribute9,
         i.shipment_attribute10,
         i.shipment_attribute11,
         i.shipment_attribute12,
         i.shipment_attribute13,
         i.shipment_attribute14,
         i.shipment_attribute15,
         i.shipment_attribute_category,
         i.shipment_num_ship,
         i.shipment_type_ship,
         i.ship_to_location_ship,
         NULL,
         i.ship_to_org_code_ship,
         NULL,
         i.type_1099,
         i.unit_of_measure_line  ,
         i.unit_of_measure_ship  ,
         i.unit_price,
         i.vendor_product_num,
         i.price_discount_ship,
         i.start_date,
         i.end_date,
         i.price_override,
         i.lead_time_ship,
         i.lead_time_unit_ship,
         i.matching_basis,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         /*I.QUANTITY_BILLED,
                                                                                                                                I.QUANTITY_CANCELLED,
                                                                                                                                I.QUANTITY_DELIVERED,
                                                                                                                                I.QUANTITY_ORDERED,*/
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         i.match_option,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         i.vendor_contact_id,
         NULL,
         i.quantity_committed);

    END LOOP;
    COMMIT;
    fnd_file.put_line(fnd_file.log, 'Loading complete');

    --Autocleanse

    FOR j IN c_data LOOP
      /*IF j.inspection_required_flag_ship = 'N' AND
         j.receipt_required_flag_ship = 'N' THEN
        l_flag := 'Y';
      ELSE
        l_flag := 'N';
      END IF;
      update_legacy_values(j.xx_po_header_id, l_flag, j.receipt_required_flag_ship,j.po_header_id,j.currency_code);*/
      update_legacy_values(j.xx_po_header_id, /*l_flag, j.receipt_required_flag_ship,*/j.po_header_id,j.currency_code);
    END LOOP;

    COMMIT;

    --DQ check
    BEGIN
      quality_check_po;
    EXCEPTION
         WHEN OTHERS THEN
          fnd_file.put_line(fnd_file.log, 'Unexpected error during DQ validation : ' ||
                       chr(10) || SQLCODE || chr(10) || SQLERRM);
    END;

    --Transformation
    FOR m IN c_transform LOOP

      --update agent_name
       l_step := 'Transform agent name';
      update_agent_name(m.xx_po_header_id, m.agent_id, m.agent_name);

       l_step := 'Transform vendor contact';
      update_vendor_contact(m.xx_po_header_id, m.vendor_contact_id);

      l_step := 'Transform amount agreed';
      IF m.doc_type_name='BLANKET' THEN
      update_amount_agreed(m.po_header_id,m.xx_po_header_id);
      END IF;

    BEGIN
      --Bill to location transformation
     /*IF m.bill_to_location IS NOT NULL THEN
      l_step := 'Transform Bill to location';
      xxs3_data_transform_util_pkg.transform(p_mapping_type => 'location_code', p_stage_tab => 'XXS3_PTP_PO', --Staging Table Name
                                             p_stage_primary_col => 'XX_PO_HEADER_ID', --Staging Table Primary Column Name
                                             p_stage_primary_col_val => m.xx_po_header_id, --Staging Table Primary Column Value
                                             p_legacy_val => m.bill_to_location, --Legacy Value
                                             p_stage_col => 'S3_BILL_TO_LOCATION', --Staging Table Name
                                             p_err_code => l_err_code, -- Output error code
                                             p_err_msg => l_err_msg);
      END IF;*/
      IF m.fob_hdr IS NOT NULL THEN
        -- fob transformation
        l_step := 'Transform fob_lookup_code';
        xxs3_data_transform_util_pkg.transform(p_mapping_type => 'fob_lookup_code', p_stage_tab => 'XXS3_PTP_PO', --Staging Table Name
                                               p_stage_primary_col => 'XX_PO_HEADER_ID', --Staging Table Primary Column Name
                                               p_stage_primary_col_val => m.xx_po_header_id, --Staging Table Primary Column Value
                                               p_legacy_val => m.fob_hdr, --Legacy Value
                                               p_stage_col => 'S3_FOB_HDR', --Staging Table Name
                                               p_err_code => l_err_code, -- Output error code
                                               p_err_msg => l_err_msg);
      END IF;
      IF m.freight_carrier_hdr IS NOT NULL THEN
      --Ship_via_lookup_code transformation
        l_step := 'Transform ship_via_lookup_code';
        xxs3_data_transform_util_pkg.transform(p_mapping_type => 'ship_via_lookup_code', p_stage_tab => 'XXS3_PTP_PO', --Staging Table Name
                                               p_stage_primary_col => 'XX_PO_HEADER_ID', --Staging Table Primary Column Name
                                               p_stage_primary_col_val => m.xx_po_header_id, --Staging Table Primary Column Value
                                               p_legacy_val => m.freight_carrier_hdr, --Legacy Value
                                               p_stage_col => 'S3_FREIGHT_CARRIER_HDR', --Staging Table Name
                                               p_err_code => l_err_code, -- Output error code
                                               p_err_msg => l_err_msg);
      END IF;
      --freight_terms_lookup_code transformation
      /*l_step := 'Transform freight_terms_lookup_code';
      xxs3_data_transform_util_pkg.transform(p_mapping_type => 'freight_terms_lookup_code', p_stage_tab => 'XXS3_PTP_PO', --Staging Table Name
                                             p_stage_primary_col => 'XX_PO_HEADER_ID', --Staging Table Primary Column Name
                                             p_stage_primary_col_val => m.xx_po_header_id, --Staging Table Primary Column Value
                                             p_legacy_val => m.freight_terms_hdr, --Legacy Value
                                             p_stage_col => 'S3_FREIGHT_TERMS_HDR', --Staging Table Name
                                             p_err_code => l_err_code, -- Output error code
                                             p_err_msg => l_err_msg);*/
      --organization_name transformation
     IF m.operating_unit_name IS NOT NULL THEN
        l_step := 'Transform organization_name';
        xxs3_data_transform_util_pkg.transform(p_mapping_type => 'organization_name', p_stage_tab => 'XXS3_PTP_PO', --Staging Table Name
                                               p_stage_primary_col => 'XX_PO_HEADER_ID', --Staging Table Primary Column Name
                                               p_stage_primary_col_val => m.xx_po_header_id, --Staging Table Primary Column Value
                                               p_legacy_val => m.operating_unit_name, --Legacy Value
                                               p_stage_col => 'S3_OPERATING_UNIT_NAME', --Staging Table Name
                                               p_err_code => l_err_code, -- Output error code
                                               p_err_msg => l_err_msg);
     END IF;

     IF m.ship_to_location_hdr IS NOT NULL THEN
        --ship_to_location_hdr transformation
        l_step := 'Transform ship_to_location_hdr';
        xxs3_data_transform_util_pkg.transform(p_mapping_type => 'location_code', p_stage_tab => 'XXS3_PTP_PO', --Staging Table Name
                                               p_stage_primary_col => 'XX_PO_HEADER_ID', --Staging Table Primary Column Name
                                               p_stage_primary_col_val => m.xx_po_header_id, --Staging Table Primary Column Value
                                               p_legacy_val => m.ship_to_location_hdr, --Legacy Value
                                               p_stage_col => 'S3_SHIP_TO_LOCATION_HDR', --Staging Table Name
                                               --p_other_col => m.ship_to_org_code_ship,
                                               p_err_code => l_err_code, -- Output error code
                                               p_err_msg => l_err_msg);
      END IF;
      IF m.category IS NOT NULL THEN
      --Category transformation
        l_step := 'Transform category';
        xxs3_data_transform_util_pkg.transform(p_mapping_type => 'category', p_stage_tab => 'XXS3_PTP_PO', --Staging Table Name
                                               p_stage_primary_col => 'XX_PO_HEADER_ID', --Staging Table Primary Column Name
                                               p_stage_primary_col_val => m.xx_po_header_id, --Staging Table Primary Column Value
                                               p_legacy_val => m.category, --Legacy Value
                                               p_stage_col => 'S3_CATEGORY', --Staging Table Name
                                               p_err_code => l_err_code, -- Output error code
                                               p_err_msg => l_err_msg);
      END IF;
      IF m.ship_to_location_ship IS NOT NULL THEN
      --ship_to_location_ship transformation
        l_step := 'Transform ship_to_location_ship';
        xxs3_data_transform_util_pkg.transform(p_mapping_type => 'location_code_ship'/*'location_code'*/, p_stage_tab => 'XXS3_PTP_PO', --Staging Table Name
                                               p_stage_primary_col => 'XX_PO_HEADER_ID', --Staging Table Primary Column Name
                                               p_stage_primary_col_val => m.xx_po_header_id, --Staging Table Primary Column Value
                                               p_legacy_val => m.ship_to_location_ship, --Legacy Value
                                               p_stage_col => 'S3_SHIP_TO_LOCATION_SHIP', --Staging Table Name
                                               p_other_col => m.ship_to_org_code_ship,
                                               p_err_code => l_err_code, -- Output error code
                                               p_err_msg => l_err_msg);
      END IF;
      --ship_to_org_code_ship transformation
      IF m.ship_to_org_code_ship IS NOT NULL THEN
        l_step := 'Transform ship_to_org_code_ship';
        xxs3_data_transform_util_pkg.transform(p_mapping_type => 'inventory_org_ptp', p_stage_tab => 'XXS3_PTP_PO', --Staging Table Name
                                               p_stage_primary_col => 'XX_PO_HEADER_ID', --Staging Table Primary Column Name
                                               p_stage_primary_col_val => m.xx_po_header_id, --Staging Table Primary Column Value
                                               p_legacy_val => m.ship_to_org_code_ship, --Legacy Value
                                               p_stage_col => 'S3_SHIP_TO_ORG_CODE_SHIP', --Staging Table Name
                                               p_other_col => m.ship_to_location_ship,
                                               p_err_code => l_err_code, -- Output error code
                                               p_err_msg => l_err_msg);
      END IF;

       IF m.destination_organization IS NOT NULL THEN
      --destination_organization transformation
        l_step := 'Transform destination_organization';
        xxs3_data_transform_util_pkg.transform(p_mapping_type => 'inventory_org_ptp', p_stage_tab => 'XXS3_PTP_PO', --Staging Table Name
                                               p_stage_primary_col => 'XX_PO_HEADER_ID', --Staging Table Primary Column Name
                                               p_stage_primary_col_val => m.xx_po_header_id, --Staging Table Primary Column Value
                                               p_legacy_val => m.destination_organization, --Legacy Value
                                               p_stage_col => 'S3_DESTINATION_ORGANIZATION', --Staging Table Name
                                               p_other_col => m.ship_to_location_ship,
                                               p_err_code => l_err_code, -- Output error code
                                               p_err_msg => l_err_msg);
      END IF;

      IF m.expenditure_organization IS NOT NULL THEN
      --expenditure_organization transformation
        l_step := 'Transform expenditure_organization';
        xxs3_data_transform_util_pkg.transform(p_mapping_type => 'expenditure_orgs_ptp', p_stage_tab => 'XXS3_PTP_PO', --Staging Table Name
                                               p_stage_primary_col => 'XX_PO_HEADER_ID', --Staging Table Primary Column Name
                                               p_stage_primary_col_val => m.xx_po_header_id, --Staging Table Primary Column Value
                                               p_legacy_val => m.expenditure_organization, --Legacy Value
                                               p_stage_col => 'S3_EXPENDITURE_ORGANIZATION', --Staging Table Name
                                               p_err_code => l_err_code, -- Output error code
                                               p_err_msg => l_err_msg);
      END IF;

      IF m.expenditure_type IS NOT NULL THEN
      --expenditure_type transformation
        l_step := 'Transform expenditure_type';
        xxs3_data_transform_util_pkg.transform(p_mapping_type => 'expenditure_type_ptp', p_stage_tab => 'XXS3_PTP_PO', --Staging Table Name
                                               p_stage_primary_col => 'XX_PO_HEADER_ID', --Staging Table Primary Column Name
                                               p_stage_primary_col_val => m.xx_po_header_id, --Staging Table Primary Column Value
                                               p_legacy_val => m.expenditure_type, --Legacy Value
                                               p_stage_col => 'S3_EXPENDITURE_TYPE', --Staging Table Name
                                               p_err_code => l_err_code, -- Output error code
                                               p_err_msg => l_err_msg);
      END IF;
      IF m.project IS NOT NULL THEN
      --Project transformation
        l_step := 'Transform project';
        xxs3_data_transform_util_pkg.transform(p_mapping_type => 'projects_ptp', p_stage_tab => 'XXS3_PTP_PO', --Staging Table Name
                                               p_stage_primary_col => 'XX_PO_HEADER_ID', --Staging Table Primary Column Name
                                               p_stage_primary_col_val => m.xx_po_header_id, --Staging Table Primary Column Value
                                               p_legacy_val => m.project, --Legacy Value
                                               p_stage_col => 'S3_PROJECT', --Staging Table Name
                                               p_err_code => l_err_code, -- Output error code
                                               p_err_msg => l_err_msg);
      END IF;
      IF m.task IS NOT NULL THEN
      --Task transformation
        l_step := 'Transform task';
        xxs3_data_transform_util_pkg.transform(p_mapping_type => 'task_ptp', p_stage_tab => 'XXS3_PTP_PO', --Staging Table Name
                                               p_stage_primary_col => 'XX_PO_HEADER_ID', --Staging Table Primary Column Name
                                               p_stage_primary_col_val => m.xx_po_header_id, --Staging Table Primary Column Value
                                               p_legacy_val => m.task, --Legacy Value
                                               p_stage_col => 'S3_TASK', --Staging Table Name
                                               p_other_col => m.task_id,
                                               p_err_code => l_err_code, -- Output error code
                                               p_err_msg => l_err_msg);
      END IF;
      IF m.payment_terms_hdr IS NOT NULL THEN
      --payment_terms_hdr transformation
        l_step := 'Transform payment_terms_hdr';
        xxs3_data_transform_util_pkg.transform(p_mapping_type => 'payment_terms_ptp', p_stage_tab => 'XXS3_PTP_PO', --Staging Table Name
                                               p_stage_primary_col => 'XX_PO_HEADER_ID', --Staging Table Primary Column Name
                                               p_stage_primary_col_val => m.xx_po_header_id, --Staging Table Primary Column Value
                                               p_legacy_val => m.payment_terms_hdr, --Legacy Value
                                               p_stage_col => 'S3_PAYMENT_TERMS_HDR', --Staging Table Name
                                               p_err_code => l_err_code, -- Output error code
                                               p_err_msg => l_err_msg);
      END IF;
      IF m.payment_terms_ship IS NOT NULL THEN
      --payment_terms_ship transformation
        l_step := 'Transform payment_terms_ship';
        xxs3_data_transform_util_pkg.transform(p_mapping_type => 'payment_terms_ptp', p_stage_tab => 'XXS3_PTP_PO', --Staging Table Name
                                               p_stage_primary_col => 'XX_PO_HEADER_ID', --Staging Table Primary Column Name
                                               p_stage_primary_col_val => m.xx_po_header_id, --Staging Table Primary Column Value
                                               p_legacy_val => m.payment_terms_ship, --Legacy Value
                                               p_stage_col => 'S3_PAYMENT_TERMS_SHIP', --Staging Table Name
                                               p_err_code => l_err_code, -- Output error code
                                               p_err_msg => l_err_msg);
      END IF;
      IF m.set_of_books IS NOT NULL THEN
      --set_of_books transformation
        l_step := 'Transform set_of_books';
        xxs3_data_transform_util_pkg.transform(p_mapping_type => 'SET_OF_BOOKS', p_stage_tab => 'XXS3_PTP_PO', --Staging Table Name
                                               p_stage_primary_col => 'XX_PO_HEADER_ID', --Staging Table Primary Column Name
                                               p_stage_primary_col_val => m.xx_po_header_id, --Staging Table Primary Column Value
                                               p_legacy_val => m.set_of_books, --Legacy Value
                                               p_stage_col => 'S3_SET_OF_BOOKS', --Staging Table Name
                                               p_err_code => l_err_code, -- Output error code
                                               p_err_msg => l_err_msg);
       END IF;
      IF m.deliver_to_location IS NOT NULL THEN
      --deliver_to_location transformation
        l_step := 'Transform deliver_to_location';
        xxs3_data_transform_util_pkg.transform(p_mapping_type => 'location_code_ship', p_stage_tab => 'XXS3_PTP_PO', --Staging Table Name
                                               p_stage_primary_col => 'XX_PO_HEADER_ID', --Staging Table Primary Column Name
                                               p_stage_primary_col_val => m.xx_po_header_id, --Staging Table Primary Column Value
                                               p_legacy_val => m.deliver_to_location, --Legacy Value
                                               p_stage_col => 'S3_DELIVER_TO_LOCATION', --Staging Table Name
                                               p_other_col => m.destination_organization,
                                               p_err_code => l_err_code, -- Output error code
                                               p_err_msg => l_err_msg);
      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        fnd_file.put_line(fnd_file.log, 'Unexpected error during transformation at step : ' ||
                     l_step ||chr(10) || SQLCODE || chr(10) || SQLERRM);
    END;
      --CoA transformation

      IF m.accrual_account IS NOT NULL THEN
        xxs3_data_transform_util_pkg.coa_open_po_transform(p_field_name => 'ACCRUAL_ACCOUNT', p_legacy_company_val => m.accrual_acct_segment1, --Legacy Company Value
                                                   p_legacy_department_val => m.accrual_acct_segment2, --Legacy Department Value
                                                   p_legacy_account_val => m.accrual_acct_segment3, --Legacy Account Value
                                                   p_legacy_product_val => m.accrual_acct_segment5, --Legacy Product Value
                                                   p_legacy_location_val => m.accrual_acct_segment6, --Legacy Location Value
                                                   p_legacy_intercompany_val => m.accrual_acct_segment7, --Legacy Intercompany Value
                                                   p_legacy_division_val => m.accrual_acct_segment10, --Legacy Division Value
                                                   p_item_number => m.item_number, p_s3_gl_string => l_s3_gl_string, p_err_code => l_output_code, p_err_msg => l_output); --Output Message

        xxs3_data_transform_util_pkg.coa_update(p_gl_string => l_s3_gl_string, p_stage_tab => 'xxs3_ptp_po', p_stage_primary_col => 'xx_po_header_id', p_stage_primary_col_val => m.xx_po_header_id, p_stage_company_col => 's3_accrual_acct_segment1', p_stage_business_unit_col => 's3_accrual_acct_segment2', p_stage_department_col => 's3_accrual_acct_segment3', p_stage_account_col => 's3_accrual_acct_segment4', p_stage_product_line_col => 's3_accrual_acct_segment5', p_stage_location_col => 's3_accrual_acct_segment6', p_stage_intercompany_col => 's3_accrual_acct_segment7', p_stage_future_col => 's3_accrual_acct_segment8', p_coa_err_msg => l_output, p_err_code => l_output_code_coa_update, p_err_msg => l_output_coa_update);
      END IF;

      IF m.charge_account IS NOT NULL THEN
        xxs3_data_transform_util_pkg.coa_open_po_transform(p_field_name => 'CHARGE_ACCOUNT', p_legacy_company_val => m.charge_acct_segment1, --Legacy Company Value
                                                   p_legacy_department_val => m.charge_acct_segment2, --Legacy Department Value
                                                   p_legacy_account_val => m.charge_acct_segment3, --Legacy Account Value
                                                   p_legacy_product_val => m.charge_acct_segment5, --Legacy Product Value
                                                   p_legacy_location_val => m.charge_acct_segment6, --Legacy Location Value
                                                   p_legacy_intercompany_val => m.charge_acct_segment7, --Legacy Intercompany Value
                                                   p_legacy_division_val => m.charge_acct_segment10, --Legacy Division Value
                                                   p_item_number => m.item_number, p_s3_gl_string => l_s3_gl_string, p_err_code => l_output_code, p_err_msg => l_output); --Output Message

        xxs3_data_transform_util_pkg.coa_update(p_gl_string => l_s3_gl_string, p_stage_tab => 'xxs3_ptp_po', p_stage_primary_col => 'xx_po_header_id', p_stage_primary_col_val => m.xx_po_header_id, p_stage_company_col => 's3_charge_acct_segment1', p_stage_business_unit_col => 's3_charge_acct_segment2', p_stage_department_col => 's3_charge_acct_segment3', p_stage_account_col => 's3_charge_acct_segment4', p_stage_product_line_col => 's3_charge_acct_segment5', p_stage_location_col => 's3_charge_acct_segment6', p_stage_intercompany_col => 's3_charge_acct_segment7', p_stage_future_col => 's3_charge_acct_segment8', p_coa_err_msg => l_output, p_err_code => l_output_code_coa_update, p_err_msg => l_output_coa_update);
      END IF;

      /*IF m.BUDGET_ACCOUNT IS NOT NULL THEN
       xxs3_data_transform_util_pkg.coa_open_po_transform(p_field_name => 'BUDGET_ACCOUNT',
                                   P_LEGACY_COMPANY_VAL      =>m.budget_acct_segment1, --Legacy Company Value
                                   P_LEGACY_DEPARTMENT_VAL   =>m.budget_acct_segment2, --Legacy Department Value
                                   P_LEGACY_ACCOUNT_VAL      =>m.budget_acct_segment3, --Legacy Account Value
                                   P_LEGACY_PRODUCT_VAL      =>m.budget_acct_segment5, --Legacy Product Value
                                   P_LEGACY_LOCATION_VAL     =>m.budget_acct_segment6, --Legacy Location Value
                                   P_LEGACY_INTERCOMPANY_VAL =>m.budget_acct_segment7, --Legacy Intercompany Value
                                   P_LEGACY_DIVISION_VAL     =>m.budget_acct_segment10,--Legacy Division Value
                                   P_ITEM_NUMBER             =>m.item_number,
                                   P_S3_GL_STRING            =>l_s3_gl_string,
                                   p_err_code                =>l_output_code,
                                   p_err_msg                 => l_output); --Output Message

       xxs3_data_transform_util_pkg.coa_update(p_gl_string               =>l_s3_gl_string
                                                 ,p_stage_tab               =>'xxs3_ptp_po'
                                                 ,p_stage_primary_col       =>'xx_po_header_id'
                                                 ,p_stage_primary_col_val   => m.xx_po_header_id
                                                 ,p_stage_company_col       => 's3_budget_acct_segment1'
                                                 ,p_stage_business_unit_col => 's3_budget_acct_segment2'
                                                 ,p_stage_department_col    => 's3_budget_acct_segment3'
                                                 ,p_stage_account_col       => 's3_budget_acct_segment4'
                                                 ,p_stage_product_line_col  => 's3_budget_acct_segment5'
                                                 ,p_stage_location_col      => 's3_budget_acct_segment6'
                                                 ,p_stage_intercompany_col  => 's3_budget_acct_segment7'
                                                 ,p_stage_future_col        => 's3_budget_acct_segment8'
                                                 ,p_coa_err_msg             => l_output
                                                 ,p_err_code                =>l_output_code_coa_update
                                                 ,p_err_msg                 =>l_output_coa_update);

      END IF;   */

      IF m.variance_account IS NOT NULL THEN
        xxs3_data_transform_util_pkg.coa_open_po_transform(p_field_name => 'VARIANCE_ACCOUNT', p_legacy_company_val => m.variance_acct_segment1, --Legacy Company Value
                                                   p_legacy_department_val => m.variance_acct_segment2, --Legacy Department Value
                                                   p_legacy_account_val => m.variance_acct_segment3, --Legacy Account Value
                                                   p_legacy_product_val => m.variance_acct_segment5, --Legacy Product Value
                                                   p_legacy_location_val => m.variance_acct_segment6, --Legacy Location Value
                                                   p_legacy_intercompany_val => m.variance_acct_segment7, --Legacy Intercompany Value
                                                   p_legacy_division_val => m.variance_acct_segment10, --Legacy Division Value
                                                   p_item_number => m.item_number, p_s3_gl_string => l_s3_gl_string, p_err_code => l_output_code, p_err_msg => l_output); --Output Message

        xxs3_data_transform_util_pkg.coa_update(p_gl_string => l_s3_gl_string, p_stage_tab => 'xxs3_ptp_po', p_stage_primary_col => 'xx_po_header_id', p_stage_primary_col_val => m.xx_po_header_id, p_stage_company_col => 's3_variance_acct_segment1', p_stage_business_unit_col => 's3_variance_acct_segment2', p_stage_department_col => 's3_variance_acct_segment3', p_stage_account_col => 's3_variance_acct_segment4', p_stage_product_line_col => 's3_variance_acct_segment5', p_stage_location_col => 's3_variance_acct_segment6', p_stage_intercompany_col => 's3_variance_acct_segment7', p_stage_future_col => 's3_variance_acct_segment8', p_coa_err_msg => l_output, p_err_code => l_output_code_coa_update, p_err_msg => l_output_coa_update);
      END IF;
    END LOOP;

    SELECT COUNT(1) INTO l_count FROM xxobjt.xxs3_ptp_po;

    fnd_file.put_line(fnd_file.output, RPAD('PO Extract', 100, ' '));
    fnd_file.put_line(fnd_file.output, RPAD('============================================================', 200, ' '));
    fnd_file.put_line(fnd_file.output, RPAD('Run date and time:    ' ||
                       to_char(SYSDATE, 'dd-Mon-YYYY HH24:MI'), 100, ' '));
	  fnd_file.put_line(fnd_file.output, RPAD('============================================================', 200, ' '));
	  fnd_file.put_line(fnd_file.output, '');
    fnd_file.put_line(fnd_file.output,RPAD('Track Name', 10, ' ')||chr(32)||RPAD('Entity Name', 30, ' ') || chr(32) || RPAD('Total Count', 15, ' ') );
    fnd_file.put_line(fnd_file.output, RPAD('===========================================================', 200, ' '));
    fnd_file.put_line(fnd_file.output, '');
    fnd_file.put_line(fnd_file.output,RPAD('PTP', 10, ' ')||' '||RPAD('PO', 30, ' ') ||' ' ||  RPAD(l_count, 15, ' ') );
    fnd_file.put_line(fnd_file.output, RPAD('=========END OF REPORT===============', 200, ' '));
    fnd_file.put_line(fnd_file.output, '');

    --extra CoA logic

    /*FOR m IN (SELECT *
              FROM   xxs3_ptp_po) LOOP
      IF m.variance_account IS NOT NULL THEN
        SELECT substr(m.variance_acct_segment3, 1, 1)
        INTO   p_acc_first_digit
        FROM   dual;
        IF p_acc_first_digit = '5' AND m.s3_variance_acct_segment2 = '501' THEN
          UPDATE xxs3_ptp_po
          SET    s3_variance_acct_segment5 = '0000'
          WHERE  xx_po_header_id = m.xx_po_header_id;

          COMMIT;
        END IF;
      END IF;
    END LOOP;*/
    --extra CoA logic

    --generate csv file

    utl_file.put(l_file, '~' || 'XX_PO_HEADER_ID');
    utl_file.put(l_file, '~' || 'DATE_EXTRACTED_ON');
    utl_file.put(l_file, '~' || 'PROCESS_FLAG');
    utl_file.put(l_file, '~' || 'S3_PO_HEADER_ID');
    utl_file.put(l_file, '~' || 'NOTES');
    utl_file.put(l_file, '~' || 'PO_HEADER_ID');
    utl_file.put(l_file, '~' || 'ACCEPTANCE_DUE_DATE');
    utl_file.put(l_file, '~' || 'AGENT_NAME');
    utl_file.put(l_file, '~' || 'S3_AGENT_NAME');
    utl_file.put(l_file, '~' || 'AGENT_ID');
    utl_file.put(l_file, '~' || 'AMOUNT_LIMIT');
    utl_file.put(l_file, '~' || 'APPROVED_DATE');
    utl_file.put(l_file, '~' || 'ATTRIBUTE1_HDR');
    utl_file.put(l_file, '~' || 'ATTRIBUTE2_HDR');
    utl_file.put(l_file, '~' || 'ATTRIBUTE3_HDR');
    utl_file.put(l_file, '~' || 'ATTRIBUTE4_HDR');
    utl_file.put(l_file, '~' || 'ATTRIBUTE5_HDR');
    utl_file.put(l_file, '~' || 'ATTRIBUTE6_HDR');
    utl_file.put(l_file, '~' || 'ATTRIBUTE7_HDR');
    utl_file.put(l_file, '~' || 'ATTRIBUTE8_HDR');
    utl_file.put(l_file, '~' || 'ATTRIBUTE9_HDR');
    utl_file.put(l_file, '~' || 'ATTRIBUTE10_HDR');
    utl_file.put(l_file, '~' || 'ATTRIBUTE11_HDR');
    utl_file.put(l_file, '~' || 'ATTRIBUTE12_HDR');
    utl_file.put(l_file, '~' || 'ATTRIBUTE13_HDR');
    utl_file.put(l_file, '~' || 'ATTRIBUTE14_HDR');
    utl_file.put(l_file, '~' || 'ATTRIBUTE15_HDR');
    utl_file.put(l_file, '~' || 'ATTRIBUTE_CATEGORY_HDR');
    utl_file.put(l_file, '~' || 'BILL_TO_LOCATION');
    utl_file.put(l_file, '~' || 'S3_BILL_TO_LOCATION');
    utl_file.put(l_file, '~' || 'CHANGE_SUMMARY');
    utl_file.put(l_file, '~' || 'CURRENCY_CODE');
    utl_file.put(l_file, '~' || 'SEGMENT1');
    utl_file.put(l_file, '~' || 'DOC_TYPE_NAME');
    utl_file.put(l_file, '~' || 'CREATION_DATE_DISP');
    utl_file.put(l_file, '~' || 'FREIGHT_CARRIER_HDR');
    utl_file.put(l_file, '~' || 'S3_FREIGHT_CARRIER_HDR');
    utl_file.put(l_file, '~' || 'FOB_HDR');
    utl_file.put(l_file, '~' || 'S3_FOB_HDR');
    utl_file.put(l_file, '~' || 'FREIGHT_TERMS_HDR');
    utl_file.put(l_file, '~' || 'S3_FREIGHT_TERMS_HDR');
    utl_file.put(l_file, '~' || 'GLOBAL_AGREEMENT_FLAG');
    utl_file.put(l_file, '~' || 'MIN_RELEASE_AMOUNT_HDR');
    utl_file.put(l_file, '~' || 'NOTE_TO_RECEIVER_HDR');
    utl_file.put(l_file, '~' || 'NOTE_TO_VENDOR_HDR');
    utl_file.put(l_file, '~' || 'OPERATING_UNIT_NAME');
    utl_file.put(l_file, '~' || 'S3_OPERATING_UNIT_NAME');
    utl_file.put(l_file, '~' || 'PAYMENT_TERMS_HDR');
    utl_file.put(l_file, '~' || 'S3_PAYMENT_TERMS_HDR');
    utl_file.put(l_file, '~' || 'PRINTED_DATE');
    utl_file.put(l_file, '~' || 'PRINT_COUNT');
    utl_file.put(l_file, '~' || 'RATE_HDR');
    utl_file.put(l_file, '~' || 'RATE_DATE_HDR');
    utl_file.put(l_file, '~' || 'RATE_TYPE');
    utl_file.put(l_file, '~' || 'REVISED_DATE');
    utl_file.put(l_file, '~' || 'REVISION_NUM');
    utl_file.put(l_file, '~' || 'SHIPPING_CONTROL');
    utl_file.put(l_file, '~' || 'SHIP_TO_LOCATION_HDR');
    utl_file.put(l_file, '~' || 'S3_SHIP_TO_LOCATION_HDR');
    utl_file.put(l_file, '~' || 'VENDOR_CONTACT');
    utl_file.put(l_file, '~' || 'VENDOR_NAME');
    utl_file.put(l_file, '~' || 'VENDOR_NUM');
    utl_file.put(l_file, '~' || 'VENDOR_SITE_CODE');
    utl_file.put(l_file, '~' || 'ACCEPTANCE_REQUIRED_FLAG');
    utl_file.put(l_file, '~' || 'CONFIRMING_ORDER_FLAG');
    utl_file.put(l_file, '~' || 'ACCRUE_ON_RECEIPT_FLAG_SHIP');
    utl_file.put(l_file, '~' || 'ALLOW_SUB_RECEIPTS_FLAG_SHIP');
    utl_file.put(l_file, '~' || 'AMOUNT_LINE');
    utl_file.put(l_file, '~' || 'AMOUNT_SHIP');
    utl_file.put(l_file, '~' || 'BASE_UNIT_PRICE');
    utl_file.put(l_file, '~' || 'CATEGORY');
    utl_file.put(l_file, '~' || 'S3_CATEGORY');
    utl_file.put(l_file, '~' || 'COMMITTED_AMOUNT');
    utl_file.put(l_file, '~' || 'DAYS_EARLY_REC_ALLOWED_SHIP');
    utl_file.put(l_file, '~' || 'DAYS_LATE_RECEIPT_ALLOWED_SHIP');
    utl_file.put(l_file, '~' || 'DROP_SHIP_FLAG');
    utl_file.put(l_file, '~' || 'ENFORCE_SHIP_TO_LOC_CODE_SHIP');
    utl_file.put(l_file, '~' || 'EXPIRATION_DATE');
    utl_file.put(l_file, '~' || 'FOB_SHIP');
    utl_file.put(l_file, '~' || 'FREIGHT_CARRIER_SHIP');
    utl_file.put(l_file, '~' || 'FREIGHT_TERMS_SHIP');
    utl_file.put(l_file, '~' || 'HAZARD_CLASS');
    utl_file.put(l_file, '~' || 'INSPECTION_REQUIRED_FLAG_SHIP');
    utl_file.put(l_file, '~' || 'INVOICE_CLOSE_TOLERANCE_SHIP');
    utl_file.put(l_file, '~' || 'ITEM_NUMBER');
    utl_file.put(l_file, '~' || 'ITEM_DESCRIPTION');
    utl_file.put(l_file, '~' || 'ITEM_REVISION');
    utl_file.put(l_file, '~' || 'JOB_NAME');
    utl_file.put(l_file, '~' || 'LINE_ATTRIBUTE1');
    utl_file.put(l_file, '~' || 'LINE_ATTRIBUTE2');
    utl_file.put(l_file, '~' || 'LINE_ATTRIBUTE3');
    utl_file.put(l_file, '~' || 'LINE_ATTRIBUTE4');
    utl_file.put(l_file, '~' || 'LINE_ATTRIBUTE5');
    utl_file.put(l_file, '~' || 'LINE_ATTRIBUTE6');
    utl_file.put(l_file, '~' || 'LINE_ATTRIBUTE7');
    utl_file.put(l_file, '~' || 'LINE_ATTRIBUTE8');
    utl_file.put(l_file, '~' || 'LINE_ATTRIBUTE9');
    utl_file.put(l_file, '~' || 'LINE_ATTRIBUTE10');
    utl_file.put(l_file, '~' || 'LINE_ATTRIBUTE11');
    utl_file.put(l_file, '~' || 'LINE_ATTRIBUTE12');
    utl_file.put(l_file, '~' || 'LINE_ATTRIBUTE13');
    utl_file.put(l_file, '~' || 'LINE_ATTRIBUTE14');
    utl_file.put(l_file, '~' || 'LINE_ATTRIBUTE15');
    utl_file.put(l_file, '~' || 'LINE_ATTRIBUTE_CATEGORY_LINES');
    utl_file.put(l_file, '~' || 'PRICE_TYPE');
    utl_file.put(l_file, '~' || 'ALLOW_PRICE_OVERRIDE_FLAG');
    utl_file.put(l_file, '~' || 'UN_NUMBER');
    utl_file.put(l_file, '~' || 'CAPITAL_EXPENSE_FLAG');
    utl_file.put(l_file, '~' || 'TRANSACTION_REASON_CODE');
    utl_file.put(l_file, '~' || 'NOT_TO_EXCEED_PRICE');
    utl_file.put(l_file, '~' || 'LINE_NUM');
    utl_file.put(l_file, '~' || 'LINE_TYPE');
    utl_file.put(l_file, '~' || 'LIST_PRICE_PER_UNIT');
    utl_file.put(l_file, '~' || 'MARKET_PRICE');
    utl_file.put(l_file, '~' || 'MIN_RELEASE_AMOUNT_LINE');
    utl_file.put(l_file, '~' || 'NEED_BY_DATE_SHIP');
    utl_file.put(l_file, '~' || 'NEGOTIATED_BY_PREPARER_FLAG');
    utl_file.put(l_file, '~' || 'NOTE_TO_RECEIVER_SHIP');
    utl_file.put(l_file, '~' || 'NOTE_TO_VENDOR_LINE');
    utl_file.put(l_file, '~' || 'OVER_TOLERANCE_ERROR_FLAG');
    utl_file.put(l_file, '~' || 'PAYMENT_TERMS_SHIP');
    utl_file.put(l_file, '~' || 'S3_PAYMENT_TERMS_SHIP');
    utl_file.put(l_file, '~' || 'PREFERRED_GRADE_LINE');
    utl_file.put(l_file, '~' || 'PREFERRED_GRADE_SHIP');
    utl_file.put(l_file, '~' || 'PRICE_BREAK_LOOKUP_CODE');
    utl_file.put(l_file, '~' || 'PROMISED_DATE_SHIP');
    utl_file.put(l_file, '~' || 'QTY_RCV_EXCEPTION_CODE_SHIP');
    utl_file.put(l_file, '~' || 'QTY_RCV_TOLERANCE_LINE');
    utl_file.put(l_file, '~' || 'QTY_RCV_TOLERANCE_SHIP');
    utl_file.put(l_file, '~' || 'QUANTITY_LINE');
    utl_file.put(l_file, '~' || 'QUANTITY_SHIP');
    utl_file.put(l_file, '~' || 'QUANTITY_BILLED_SHIP');
    utl_file.put(l_file, '~' || 'QUANTITY_CANCELLED_SHIP');
    utl_file.put(l_file, '~' || 'QUANTITY_RECEIVED_SHIP');
    utl_file.put(l_file, '~' || 'RECEIPT_DAYS_EXC_CODE_SHIP');
    utl_file.put(l_file, '~' || 'RECEIPT_REQUIRED_FLAG_SHIP');
    --utl_file.put(l_file, '~' || 'S3_RECEIPT_REQUIRED_FLAG_SHIP');
    utl_file.put(l_file, '~' || 'RECEIVE_CLOSE_TOLERANCE_SHIP');
    utl_file.put(l_file, '~' || 'RECEIVING_ROUTING_SHIP');
    utl_file.put(l_file, '~' || 'SHIPMENT_ATTRIBUTE1');
    utl_file.put(l_file, '~' || 'SHIPMENT_ATTRIBUTE2');
    utl_file.put(l_file, '~' || 'SHIPMENT_ATTRIBUTE3');
    utl_file.put(l_file, '~' || 'SHIPMENT_ATTRIBUTE4');
    utl_file.put(l_file, '~' || 'SHIPMENT_ATTRIBUTE5');
    utl_file.put(l_file, '~' || 'SHIPMENT_ATTRIBUTE6');
    utl_file.put(l_file, '~' || 'SHIPMENT_ATTRIBUTE7');
    utl_file.put(l_file, '~' || 'SHIPMENT_ATTRIBUTE8');
    utl_file.put(l_file, '~' || 'SHIPMENT_ATTRIBUTE9');
    utl_file.put(l_file, '~' || 'SHIPMENT_ATTRIBUTE10');
    utl_file.put(l_file, '~' || 'SHIPMENT_ATTRIBUTE11');
    utl_file.put(l_file, '~' || 'SHIPMENT_ATTRIBUTE12');
    utl_file.put(l_file, '~' || 'SHIPMENT_ATTRIBUTE13');
    utl_file.put(l_file, '~' || 'SHIPMENT_ATTRIBUTE14');
    utl_file.put(l_file, '~' || 'SHIPMENT_ATTRIBUTE15');
    utl_file.put(l_file, '~' || 'SHIPMENT_ATTRIBUTE_CATEGORY');
    utl_file.put(l_file, '~' || 'SHIPMENT_NUM_SHIP');
    utl_file.put(l_file, '~' || 'SHIPMENT_TYPE_SHIP');
    utl_file.put(l_file, '~' || 'SHIP_TO_LOCATION_SHIP');
    utl_file.put(l_file, '~' || 'S3_SHIP_TO_LOCATION_SHIP');
    utl_file.put(l_file, '~' || 'SHIP_TO_ORG_CODE_SHIP');
    utl_file.put(l_file, '~' || 'S3_SHIP_TO_ORG_CODE_SHIP');
    utl_file.put(l_file, '~' || 'TYPE_1099');
    utl_file.put(l_file, '~' || 'UNIT_OF_MEASURE_LINE');
    utl_file.put(l_file, '~' || 'UNIT_OF_MEASURE_SHIP');
    utl_file.put(l_file, '~' || 'UNIT_PRICE');
    utl_file.put(l_file, '~' || 'VENDOR_PRODUCT_NUM');
    utl_file.put(l_file, '~' || 'PRICE_DISCOUNT_SHIP');
    utl_file.put(l_file, '~' || 'START_DATE');
    utl_file.put(l_file, '~' || 'END_DATE');
    utl_file.put(l_file, '~' || 'PRICE_OVERRIDE');
    utl_file.put(l_file, '~' || 'LEAD_TIME_SHIP');
    utl_file.put(l_file, '~' || 'LEAD_TIME_UNIT_SHIP');
    utl_file.put(l_file, '~' || 'MATCHING_BASIS');
    utl_file.put(l_file, '~' || 'ACCRUE_ON_RECEIPT_FLAG_DIST');
    utl_file.put(l_file, '~' || 'ACCRUAL_ACCOUNT');
    utl_file.put(l_file, '~' || 'S3_ACCRUAL_ACCOUNT');
    utl_file.put(l_file, '~' || 'ACCRUAL_ACCT_SEGMENT1');
    utl_file.put(l_file, '~' || 'ACCRUAL_ACCT_SEGMENT2');
    utl_file.put(l_file, '~' || 'ACCRUAL_ACCT_SEGMENT3');
    utl_file.put(l_file, '~' || 'ACCRUAL_ACCT_SEGMENT5');
    utl_file.put(l_file, '~' || 'ACCRUAL_ACCT_SEGMENT6');
    utl_file.put(l_file, '~' || 'ACCRUAL_ACCT_SEGMENT7');
    utl_file.put(l_file, '~' || 'ACCRUAL_ACCT_SEGMENT10');
    utl_file.put(l_file, '~' || 'S3_ACCRUAL_ACCT_SEGMENT1');
    utl_file.put(l_file, '~' || 'S3_ACCRUAL_ACCT_SEGMENT2');
    utl_file.put(l_file, '~' || 'S3_ACCRUAL_ACCT_SEGMENT3');
    utl_file.put(l_file, '~' || 'S3_ACCRUAL_ACCT_SEGMENT4');
    utl_file.put(l_file, '~' || 'S3_ACCRUAL_ACCT_SEGMENT5');
    utl_file.put(l_file, '~' || 'S3_ACCRUAL_ACCT_SEGMENT6');
    utl_file.put(l_file, '~' || 'S3_ACCRUAL_ACCT_SEGMENT7');
    utl_file.put(l_file, '~' || 'S3_ACCRUAL_ACCT_SEGMENT8');
    utl_file.put(l_file, '~' || 'AMOUNT_BILLED');
    utl_file.put(l_file, '~' || 'AMOUNT_ORDERED');
    utl_file.put(l_file, '~' || 'ATTRIBUTE1_DIST');
    utl_file.put(l_file, '~' || 'ATTRIBUTE2_DIST');
    utl_file.put(l_file, '~' || 'ATTRIBUTE3_DIST');
    utl_file.put(l_file, '~' || 'ATTRIBUTE4_DIST');
    utl_file.put(l_file, '~' || 'ATTRIBUTE5_DIST');
    utl_file.put(l_file, '~' || 'ATTRIBUTE6_DIST');
    utl_file.put(l_file, '~' || 'ATTRIBUTE7_DIST');
    utl_file.put(l_file, '~' || 'ATTRIBUTE8_DIST');
    utl_file.put(l_file, '~' || 'ATTRIBUTE9_DIST');
    utl_file.put(l_file, '~' || 'ATTRIBUTE10_DIST');
    utl_file.put(l_file, '~' || 'ATTRIBUTE11_DIST');
    utl_file.put(l_file, '~' || 'ATTRIBUTE12_DIST');
    utl_file.put(l_file, '~' || 'ATTRIBUTE13_DIST');
    utl_file.put(l_file, '~' || 'ATTRIBUTE14_DIST');
    utl_file.put(l_file, '~' || 'ATTRIBUTE15_DIST');
    utl_file.put(l_file, '~' || 'ATTRIBUTE_CATEGORY_DIST');
    utl_file.put(l_file, '~' || 'BUDGET_ACCOUNT');
    utl_file.put(l_file, '~' || 'S3_BUDGET_ACCOUNT');
    utl_file.put(l_file, '~' || 'BUDGET_ACCT_SEGMENT1');
    utl_file.put(l_file, '~' || 'BUDGET_ACCT_SEGMENT2');
    utl_file.put(l_file, '~' || 'BUDGET_ACCT_SEGMENT3');
    utl_file.put(l_file, '~' || 'BUDGET_ACCT_SEGMENT5');
    utl_file.put(l_file, '~' || 'BUDGET_ACCT_SEGMENT6');
    utl_file.put(l_file, '~' || 'BUDGET_ACCT_SEGMENT7');
    utl_file.put(l_file, '~' || 'BUDGET_ACCT_SEGMENT10');
    utl_file.put(l_file, '~' || 'S3_BUDGET_ACCT_SEGMENT1');
    utl_file.put(l_file, '~' || 'S3_BUDGET_ACCT_SEGMENT2');
    utl_file.put(l_file, '~' || 'S3_BUDGET_ACCT_SEGMENT3');
    utl_file.put(l_file, '~' || 'S3_BUDGET_ACCT_SEGMENT4');
    utl_file.put(l_file, '~' || 'S3_BUDGET_ACCT_SEGMENT5');
    utl_file.put(l_file, '~' || 'S3_BUDGET_ACCT_SEGMENT6');
    utl_file.put(l_file, '~' || 'S3_BUDGET_ACCT_SEGMENT7');
    utl_file.put(l_file, '~' || 'S3_BUDGET_ACCT_SEGMENT8');
    utl_file.put(l_file, '~' || 'CHARGE_ACCOUNT');
    utl_file.put(l_file, '~' || 'S3_CHARGE_ACCOUNT');
    utl_file.put(l_file, '~' || 'CHARGE_ACCT_SEGMENT1');
    utl_file.put(l_file, '~' || 'CHARGE_ACCT_SEGMENT2');
    utl_file.put(l_file, '~' || 'CHARGE_ACCT_SEGMENT3');
    utl_file.put(l_file, '~' || 'CHARGE_ACCT_SEGMENT5');
    utl_file.put(l_file, '~' || 'CHARGE_ACCT_SEGMENT6');
    utl_file.put(l_file, '~' || 'CHARGE_ACCT_SEGMENT7');
    utl_file.put(l_file, '~' || 'CHARGE_ACCT_SEGMENT10');
    utl_file.put(l_file, '~' || 'S3_CHARGE_ACCT_SEGMENT1');
    utl_file.put(l_file, '~' || 'S3_CHARGE_ACCT_SEGMENT2');
    utl_file.put(l_file, '~' || 'S3_CHARGE_ACCT_SEGMENT3');
    utl_file.put(l_file, '~' || 'S3_CHARGE_ACCT_SEGMENT4');
    utl_file.put(l_file, '~' || 'S3_CHARGE_ACCT_SEGMENT5');
    utl_file.put(l_file, '~' || 'S3_CHARGE_ACCT_SEGMENT6');
    utl_file.put(l_file, '~' || 'S3_CHARGE_ACCT_SEGMENT7');
    utl_file.put(l_file, '~' || 'S3_CHARGE_ACCT_SEGMENT8');
    utl_file.put(l_file, '~' || 'DELIVER_TO_LOCATION');
    utl_file.put(l_file, '~' || 'S3_DELIVER_TO_LOCATION');
    utl_file.put(l_file, '~' || 'DELIVER_TO_PERSON');
    utl_file.put(l_file, '~' || 'DESTINATION_CONTEXT');
    utl_file.put(l_file, '~' || 'DESTINATION_ORGANIZATION');
    utl_file.put(l_file, '~' || 'S3_DESTINATION_ORGANIZATION');
    utl_file.put(l_file, '~' || 'DESTINATION_SUBINVENTORY');
    utl_file.put(l_file, '~' || 'DESTINATION_TYPE_CODE');
    utl_file.put(l_file, '~' || 'DISTRIBUTION_NUM');
    utl_file.put(l_file, '~' || 'ENCUMBERED_AMOUNT');
    utl_file.put(l_file, '~' || 'ENCUMBERED_FLAG');
    utl_file.put(l_file, '~' || 'EXPENDITURE_ITEM_DATE');
    utl_file.put(l_file, '~' || 'EXPENDITURE_ORGANIZATION');
    utl_file.put(l_file, '~' || 'S3_EXPENDITURE_ORGANIZATION');
    utl_file.put(l_file, '~' || 'EXPENDITURE_TYPE');
    utl_file.put(l_file, '~' || 'S3_EXPENDITURE_TYPE');
    utl_file.put(l_file, '~' || 'FAILED_FUNDS_LOOKUP_CODE');
    utl_file.put(l_file, '~' || 'GL_CANCELLED_DATE');
    utl_file.put(l_file, '~' || 'GL_ENCUMBERED_DATE');
    utl_file.put(l_file, '~' || 'GL_ENCUMBERED_PERIOD_NAME');
    utl_file.put(l_file, '~' || 'NONRECOVERABLE_TAX');
    utl_file.put(l_file, '~' || 'PREVENT_ENCUMBRANCE_FLAG');
    utl_file.put(l_file, '~' || 'PROJECT');
    utl_file.put(l_file, '~' || 'S3_PROJECT');
    utl_file.put(l_file, '~' || 'PROJECT_ACCOUNTING_CONTEXT');
    utl_file.put(l_file, '~' || 'QUANTITY_BILLED_DIST');
    utl_file.put(l_file, '~' || 'QUANTITY_CANCELLED_DIST');
    utl_file.put(l_file, '~' || 'QUANTITY_ORDERED_DIST');
    utl_file.put(l_file, '~' || 'RATE_DIST');
    utl_file.put(l_file, '~' || 'RATE_DATE_DIST');
    utl_file.put(l_file, '~' || 'RECOVERABLE_TAX');
    utl_file.put(l_file, '~' || 'RECOVERY_RATE');
    utl_file.put(l_file, '~' || 'SET_OF_BOOKS');
    utl_file.put(l_file, '~' || 'S3_SET_OF_BOOKS');
    utl_file.put(l_file, '~' || 'TASK');
    utl_file.put(l_file, '~' || 'S3_TASK');
    utl_file.put(l_file, '~' || 'TAX_RECOVERY_OVERRIDE_FLAG');
    utl_file.put(l_file, '~' || 'VARIANCE_ACCOUNT');
    utl_file.put(l_file, '~' || 'S3_VARIANCE_ACCOUNT');
    utl_file.put(l_file, '~' || 'VARIANCE_ACCT_SEGMENT1');
    utl_file.put(l_file, '~' || 'VARIANCE_ACCT_SEGMENT2');
    utl_file.put(l_file, '~' || 'VARIANCE_ACCT_SEGMENT3');
    utl_file.put(l_file, '~' || 'VARIANCE_ACCT_SEGMENT5');
    utl_file.put(l_file, '~' || 'VARIANCE_ACCT_SEGMENT6');
    utl_file.put(l_file, '~' || 'VARIANCE_ACCT_SEGMENT7');
    utl_file.put(l_file, '~' || 'VARIANCE_ACCT_SEGMENT10');
    utl_file.put(l_file, '~' || 'S3_VARIANCE_ACCT_SEGMENT1');
    utl_file.put(l_file, '~' || 'S3_VARIANCE_ACCT_SEGMENT2');
    utl_file.put(l_file, '~' || 'S3_VARIANCE_ACCT_SEGMENT3');
    utl_file.put(l_file, '~' || 'S3_VARIANCE_ACCT_SEGMENT4');
    utl_file.put(l_file, '~' || 'S3_VARIANCE_ACCT_SEGMENT5');
    utl_file.put(l_file, '~' || 'S3_VARIANCE_ACCT_SEGMENT6');
    utl_file.put(l_file, '~' || 'S3_VARIANCE_ACCT_SEGMENT7');
    utl_file.put(l_file, '~' || 'S3_VARIANCE_ACCT_SEGMENT8');
    utl_file.put(l_file, '~' || 'MATCH_OPTION');
    utl_file.put(l_file, '~' || 'S3_MATCH_OPTION');
    utl_file.put(l_file, '~' || 'AMOUNT_AGREED');
    utl_file.put(l_file, '~' || 'CLEANSE_STATUS');
    utl_file.put(l_file, '~' || 'CLEANSE_ERROR');
    utl_file.put(l_file, '~' || 'TRANSFORM_STATUS');
    utl_file.put(l_file, '~' || 'TRANSFORM_ERROR');
    utl_file.new_line(l_file);

    FOR c1 IN c_data LOOP
      utl_file.put(l_file, '~' || c1.xx_po_header_id);
      utl_file.put(l_file, '~' || c1.date_extracted_on);
      utl_file.put(l_file, '~' || c1.process_flag);
      utl_file.put(l_file, '~' || c1.s3_po_header_id);
      utl_file.put(l_file, '~' || c1.notes);
      utl_file.put(l_file, '~' || c1.po_header_id);
      utl_file.put(l_file, '~' || c1.acceptance_due_date);
      utl_file.put(l_file, '~' || c1.agent_name);
      utl_file.put(l_file, '~' || c1.s3_agent_name);
      utl_file.put(l_file, '~' || c1.agent_id);
      utl_file.put(l_file, '~' || c1.amount_limit);
      utl_file.put(l_file, '~' || c1.approved_date);
      utl_file.put(l_file, '~' || c1.attribute1_hdr);
      utl_file.put(l_file, '~' || c1.attribute2_hdr);
      utl_file.put(l_file, '~' || c1.attribute3_hdr);
      utl_file.put(l_file, '~' || c1.attribute4_hdr);
      utl_file.put(l_file, '~' || c1.attribute5_hdr);
      utl_file.put(l_file, '~' || c1.attribute6_hdr);
      utl_file.put(l_file, '~' || c1.attribute7_hdr);
      utl_file.put(l_file, '~' || c1.attribute8_hdr);
      utl_file.put(l_file, '~' || c1.attribute9_hdr);
      utl_file.put(l_file, '~' || c1.attribute10_hdr);
      utl_file.put(l_file, '~' || c1.attribute11_hdr);
      utl_file.put(l_file, '~' || c1.attribute12_hdr);
      utl_file.put(l_file, '~' || c1.attribute13_hdr);
      utl_file.put(l_file, '~' || c1.attribute14_hdr);
      utl_file.put(l_file, '~' || c1.attribute15_hdr);
      utl_file.put(l_file, '~' || c1.attribute_category_hdr);
      utl_file.put(l_file, '~' || c1.bill_to_location);
      utl_file.put(l_file, '~' || c1.s3_bill_to_location);
      utl_file.put(l_file, '~' || c1.change_summary);
      utl_file.put(l_file, '~' || c1.currency_code);
      utl_file.put(l_file, '~' || c1.segment1);
      utl_file.put(l_file, '~' || c1.doc_type_name);
      utl_file.put(l_file, '~' || c1.creation_date_disp);
      utl_file.put(l_file, '~' || c1.freight_carrier_hdr);
      utl_file.put(l_file, '~' || c1.s3_freight_carrier_hdr);
      utl_file.put(l_file, '~' || c1.fob_hdr);
      utl_file.put(l_file, '~' || c1.s3_fob_hdr);
      utl_file.put(l_file, '~' || c1.freight_terms_hdr);
      utl_file.put(l_file, '~' || c1.s3_freight_terms_hdr);
      utl_file.put(l_file, '~' || c1.global_agreement_flag);
      utl_file.put(l_file, '~' || c1.min_release_amount_hdr);
      utl_file.put(l_file, '~' || c1.note_to_receiver_hdr);
      utl_file.put(l_file, '~' || c1.note_to_vendor_hdr);
      utl_file.put(l_file, '~' || c1.operating_unit_name);
      utl_file.put(l_file, '~' || c1.s3_operating_unit_name);
      utl_file.put(l_file, '~' || c1.payment_terms_hdr);
      utl_file.put(l_file, '~' || c1.s3_payment_terms_hdr);
      utl_file.put(l_file, '~' || c1.printed_date);
      utl_file.put(l_file, '~' || c1.print_count);
      utl_file.put(l_file, '~' || c1.rate_hdr);
      utl_file.put(l_file, '~' || c1.rate_date_hdr);
      utl_file.put(l_file, '~' || c1.rate_type);
      utl_file.put(l_file, '~' || c1.revised_date);
      utl_file.put(l_file, '~' || c1.revision_num);
      utl_file.put(l_file, '~' || c1.shipping_control);
      utl_file.put(l_file, '~' || c1.ship_to_location_hdr);
      utl_file.put(l_file, '~' || c1.s3_ship_to_location_hdr);
      utl_file.put(l_file, '~' || c1.vendor_contact);
      utl_file.put(l_file, '~' || c1.vendor_name);
      utl_file.put(l_file, '~' || c1.vendor_num);
      utl_file.put(l_file, '~' || c1.vendor_site_code);
      utl_file.put(l_file, '~' || c1.acceptance_required_flag);
      utl_file.put(l_file, '~' || c1.confirming_order_flag);
      utl_file.put(l_file, '~' || c1.accrue_on_receipt_flag_ship);
      utl_file.put(l_file, '~' || c1.allow_sub_receipts_flag_ship);
      utl_file.put(l_file, '~' || c1.amount_line);
      utl_file.put(l_file, '~' || c1.amount_ship);
      utl_file.put(l_file, '~' || c1.base_unit_price);
      utl_file.put(l_file, '~' || c1.category);
      utl_file.put(l_file, '~' || c1.s3_category);
      utl_file.put(l_file, '~' || c1.committed_amount);
      utl_file.put(l_file, '~' || c1.days_early_rec_allowed_ship);
      utl_file.put(l_file, '~' || c1.days_late_receipt_allowed_ship);
      utl_file.put(l_file, '~' || c1.drop_ship_flag);
      utl_file.put(l_file, '~' || c1.enforce_ship_to_loc_code_ship);
      utl_file.put(l_file, '~' || c1.expiration_date);
      utl_file.put(l_file, '~' || c1.fob_ship);
      utl_file.put(l_file, '~' || c1.freight_carrier_ship);
      utl_file.put(l_file, '~' || c1.freight_terms_ship);
      utl_file.put(l_file, '~' || c1.hazard_class);
      utl_file.put(l_file, '~' || c1.inspection_required_flag_ship);
      utl_file.put(l_file, '~' || c1.invoice_close_tolerance_ship);
      utl_file.put(l_file, '~' || c1.item_number);
      utl_file.put(l_file, '~' || c1.item_description);
      utl_file.put(l_file, '~' || c1.item_revision);
      utl_file.put(l_file, '~' || c1.job_name);
      utl_file.put(l_file, '~' || c1.line_attribute1);
      utl_file.put(l_file, '~' || c1.line_attribute2);
      utl_file.put(l_file, '~' || c1.line_attribute3);
      utl_file.put(l_file, '~' || c1.line_attribute4);
      utl_file.put(l_file, '~' || c1.line_attribute5);
      utl_file.put(l_file, '~' || c1.line_attribute6);
      utl_file.put(l_file, '~' || c1.line_attribute7);
      utl_file.put(l_file, '~' || c1.line_attribute8);
      utl_file.put(l_file, '~' || c1.line_attribute9);
      utl_file.put(l_file, '~' || c1.line_attribute10);
      utl_file.put(l_file, '~' || c1.line_attribute11);
      utl_file.put(l_file, '~' || c1.line_attribute12);
      utl_file.put(l_file, '~' || c1.line_attribute13);
      utl_file.put(l_file, '~' || c1.line_attribute14);
      utl_file.put(l_file, '~' || c1.line_attribute15);
      utl_file.put(l_file, '~' || c1.line_attribute_category_lines);
      utl_file.put(l_file, '~' || c1.price_type);
      utl_file.put(l_file, '~' || c1.allow_price_override_flag);
      utl_file.put(l_file, '~' || c1.un_number);
      utl_file.put(l_file, '~' || c1.capital_expense_flag);
      utl_file.put(l_file, '~' || c1.transaction_reason_code);
      utl_file.put(l_file, '~' || c1.not_to_exceed_price);
      utl_file.put(l_file, '~' || c1.line_num);
      utl_file.put(l_file, '~' || c1.line_type);
      utl_file.put(l_file, '~' || c1.list_price_per_unit);
      utl_file.put(l_file, '~' || c1.market_price);
      utl_file.put(l_file, '~' || c1.min_release_amount_line);
      utl_file.put(l_file, '~' || c1.need_by_date_ship);
      utl_file.put(l_file, '~' || c1.negotiated_by_preparer_flag);
      utl_file.put(l_file, '~' || c1.note_to_receiver_ship);
      utl_file.put(l_file, '~' || c1.note_to_vendor_line);
      utl_file.put(l_file, '~' || c1.over_tolerance_error_flag);
      utl_file.put(l_file, '~' || c1.payment_terms_ship);
      utl_file.put(l_file, '~' || c1.s3_payment_terms_ship);
      utl_file.put(l_file, '~' || c1.preferred_grade_line);
      utl_file.put(l_file, '~' || c1.preferred_grade_ship);
      utl_file.put(l_file, '~' || c1.price_break_lookup_code);
      utl_file.put(l_file, '~' || c1.promised_date_ship);
      utl_file.put(l_file, '~' || c1.qty_rcv_exception_code_ship);
      utl_file.put(l_file, '~' || c1.qty_rcv_tolerance_line);
      utl_file.put(l_file, '~' || c1.qty_rcv_tolerance_ship);
      utl_file.put(l_file, '~' || c1.quantity_line);
      utl_file.put(l_file, '~' || c1.quantity_ship);
      utl_file.put(l_file, '~' || c1.quantity_billed_ship);
      utl_file.put(l_file, '~' || c1.quantity_cancelled_ship);
      utl_file.put(l_file, '~' || c1.quantity_received_ship);
      utl_file.put(l_file, '~' || c1.receipt_days_exc_code_ship);
      utl_file.put(l_file, '~' || c1.receipt_required_flag_ship);
      --utl_file.put(l_file, '~' || c1.s3_receipt_required_flag_ship);
      utl_file.put(l_file, '~' || c1.receive_close_tolerance_ship);
      utl_file.put(l_file, '~' || c1.receiving_routing_ship);
      utl_file.put(l_file, '~' || c1.shipment_attribute1);
      utl_file.put(l_file, '~' || c1.shipment_attribute2);
      utl_file.put(l_file, '~' || c1.shipment_attribute3);
      utl_file.put(l_file, '~' || c1.shipment_attribute4);
      utl_file.put(l_file, '~' || c1.shipment_attribute5);
      utl_file.put(l_file, '~' || c1.shipment_attribute6);
      utl_file.put(l_file, '~' || c1.shipment_attribute7);
      utl_file.put(l_file, '~' || c1.shipment_attribute8);
      utl_file.put(l_file, '~' || c1.shipment_attribute9);
      utl_file.put(l_file, '~' || c1.shipment_attribute10);
      utl_file.put(l_file, '~' || c1.shipment_attribute11);
      utl_file.put(l_file, '~' || c1.shipment_attribute12);
      utl_file.put(l_file, '~' || c1.shipment_attribute13);
      utl_file.put(l_file, '~' || c1.shipment_attribute14);
      utl_file.put(l_file, '~' || c1.shipment_attribute15);
      utl_file.put(l_file, '~' || c1.shipment_attribute_category);
      utl_file.put(l_file, '~' || c1.shipment_num_ship);
      utl_file.put(l_file, '~' || c1.shipment_type_ship);
      utl_file.put(l_file, '~' || c1.ship_to_location_ship);
      utl_file.put(l_file, '~' || c1.s3_ship_to_location_ship);
      utl_file.put(l_file, '~' || c1.ship_to_org_code_ship);
      utl_file.put(l_file, '~' || c1.s3_ship_to_org_code_ship);
      utl_file.put(l_file, '~' || c1.type_1099);
      utl_file.put(l_file, '~' || c1.unit_of_measure_line);
      utl_file.put(l_file, '~' || c1.unit_of_measure_ship);
      utl_file.put(l_file, '~' || c1.unit_price);
      utl_file.put(l_file, '~' || c1.vendor_product_num);
      utl_file.put(l_file, '~' || c1.price_discount_ship);
      utl_file.put(l_file, '~' || c1.start_date);
      utl_file.put(l_file, '~' || c1.end_date);
      utl_file.put(l_file, '~' || c1.price_override);
      utl_file.put(l_file, '~' || c1.lead_time_ship);
      utl_file.put(l_file, '~' || c1.lead_time_unit_ship);
      utl_file.put(l_file, '~' || c1.matching_basis);
      utl_file.put(l_file, '~' || c1.accrue_on_receipt_flag_dist);
      utl_file.put(l_file, '~' || c1.accrual_account);
      utl_file.put(l_file, '~' || c1.s3_accrual_account);
      utl_file.put(l_file, '~' || c1.accrual_acct_segment1);
      utl_file.put(l_file, '~' || c1.accrual_acct_segment2);
      utl_file.put(l_file, '~' || c1.accrual_acct_segment3);
      utl_file.put(l_file, '~' || c1.accrual_acct_segment5);
      utl_file.put(l_file, '~' || c1.accrual_acct_segment6);
      utl_file.put(l_file, '~' || c1.accrual_acct_segment7);
      utl_file.put(l_file, '~' || c1.accrual_acct_segment10);
      utl_file.put(l_file, '~' || c1.s3_accrual_acct_segment1);
      utl_file.put(l_file, '~' || c1.s3_accrual_acct_segment2);
      utl_file.put(l_file, '~' || c1.s3_accrual_acct_segment3);
      utl_file.put(l_file, '~' || c1.s3_accrual_acct_segment4);
      utl_file.put(l_file, '~' || c1.s3_accrual_acct_segment5);
      utl_file.put(l_file, '~' || c1.s3_accrual_acct_segment6);
      utl_file.put(l_file, '~' || c1.s3_accrual_acct_segment7);
      utl_file.put(l_file, '~' || c1.s3_accrual_acct_segment8);
      utl_file.put(l_file, '~' || c1.amount_billed);
      utl_file.put(l_file, '~' || c1.amount_ordered);
      utl_file.put(l_file, '~' || c1.attribute1_dist);
      utl_file.put(l_file, '~' || c1.attribute2_dist);
      utl_file.put(l_file, '~' || c1.attribute3_dist);
      utl_file.put(l_file, '~' || c1.attribute4_dist);
      utl_file.put(l_file, '~' || c1.attribute5_dist);
      utl_file.put(l_file, '~' || c1.attribute6_dist);
      utl_file.put(l_file, '~' || c1.attribute7_dist);
      utl_file.put(l_file, '~' || c1.attribute8_dist);
      utl_file.put(l_file, '~' || c1.attribute9_dist);
      utl_file.put(l_file, '~' || c1.attribute10_dist);
      utl_file.put(l_file, '~' || c1.attribute11_dist);
      utl_file.put(l_file, '~' || c1.attribute12_dist);
      utl_file.put(l_file, '~' || c1.attribute13_dist);
      utl_file.put(l_file, '~' || c1.attribute14_dist);
      utl_file.put(l_file, '~' || c1.attribute15_dist);
      utl_file.put(l_file, '~' || c1.attribute_category_dist);
      utl_file.put(l_file, '~' || c1.budget_account);
      utl_file.put(l_file, '~' || c1.s3_budget_account);
      utl_file.put(l_file, '~' || c1.budget_acct_segment1);
      utl_file.put(l_file, '~' || c1.budget_acct_segment2);
      utl_file.put(l_file, '~' || c1.budget_acct_segment3);
      utl_file.put(l_file, '~' || c1.budget_acct_segment5);
      utl_file.put(l_file, '~' || c1.budget_acct_segment6);
      utl_file.put(l_file, '~' || c1.budget_acct_segment7);
      utl_file.put(l_file, '~' || c1.budget_acct_segment10);
      utl_file.put(l_file, '~' || c1.s3_budget_acct_segment1);
      utl_file.put(l_file, '~' || c1.s3_budget_acct_segment2);
      utl_file.put(l_file, '~' || c1.s3_budget_acct_segment3);
      utl_file.put(l_file, '~' || c1.s3_budget_acct_segment4);
      utl_file.put(l_file, '~' || c1.s3_budget_acct_segment5);
      utl_file.put(l_file, '~' || c1.s3_budget_acct_segment6);
      utl_file.put(l_file, '~' || c1.s3_budget_acct_segment7);
      utl_file.put(l_file, '~' || c1.s3_budget_acct_segment8);
      utl_file.put(l_file, '~' || c1.charge_account);
      utl_file.put(l_file, '~' || c1.s3_charge_account);
      utl_file.put(l_file, '~' || c1.charge_acct_segment1);
      utl_file.put(l_file, '~' || c1.charge_acct_segment2);
      utl_file.put(l_file, '~' || c1.charge_acct_segment3);
      utl_file.put(l_file, '~' || c1.charge_acct_segment5);
      utl_file.put(l_file, '~' || c1.charge_acct_segment6);
      utl_file.put(l_file, '~' || c1.charge_acct_segment7);
      utl_file.put(l_file, '~' || c1.charge_acct_segment10);
      utl_file.put(l_file, '~' || c1.s3_charge_acct_segment1);
      utl_file.put(l_file, '~' || c1.s3_charge_acct_segment2);
      utl_file.put(l_file, '~' || c1.s3_charge_acct_segment3);
      utl_file.put(l_file, '~' || c1.s3_charge_acct_segment4);
      utl_file.put(l_file, '~' || c1.s3_charge_acct_segment5);
      utl_file.put(l_file, '~' || c1.s3_charge_acct_segment6);
      utl_file.put(l_file, '~' || c1.s3_charge_acct_segment7);
      utl_file.put(l_file, '~' || c1.s3_charge_acct_segment8);
      utl_file.put(l_file, '~' || c1.deliver_to_location);
      utl_file.put(l_file, '~' || c1.s3_deliver_to_location);
      utl_file.put(l_file, '~' || c1.deliver_to_person);
      utl_file.put(l_file, '~' || c1.destination_context);
      utl_file.put(l_file, '~' || c1.destination_organization);
      utl_file.put(l_file, '~' || c1.s3_destination_organization);
      utl_file.put(l_file, '~' || c1.destination_subinventory);
      utl_file.put(l_file, '~' || c1.destination_type_code);
      utl_file.put(l_file, '~' || c1.distribution_num);
      utl_file.put(l_file, '~' || c1.encumbered_amount);
      utl_file.put(l_file, '~' || c1.encumbered_flag);
      utl_file.put(l_file, '~' || c1.expenditure_item_date);
      utl_file.put(l_file, '~' || c1.expenditure_organization);
      utl_file.put(l_file, '~' || c1.s3_expenditure_organization);
      utl_file.put(l_file, '~' || c1.expenditure_type);
      utl_file.put(l_file, '~' || c1.s3_expenditure_type);
      utl_file.put(l_file, '~' || c1.failed_funds_lookup_code);
      utl_file.put(l_file, '~' || c1.gl_cancelled_date);
      utl_file.put(l_file, '~' || c1.gl_encumbered_date);
      utl_file.put(l_file, '~' || c1.gl_encumbered_period_name);
      utl_file.put(l_file, '~' || c1.nonrecoverable_tax);
      utl_file.put(l_file, '~' || c1.prevent_encumbrance_flag);
      utl_file.put(l_file, '~' || c1.project);
      utl_file.put(l_file, '~' || c1.s3_project);
      utl_file.put(l_file, '~' || c1.project_accounting_context);
      utl_file.put(l_file, '~' || c1.quantity_billed_dist);
      utl_file.put(l_file, '~' || c1.quantity_cancelled_dist);
      utl_file.put(l_file, '~' || c1.quantity_ordered_dist);
      utl_file.put(l_file, '~' || c1.rate_dist);
      utl_file.put(l_file, '~' || c1.rate_date_dist);
      utl_file.put(l_file, '~' || c1.recoverable_tax);
      utl_file.put(l_file, '~' || c1.recovery_rate);
      utl_file.put(l_file, '~' || c1.set_of_books);
      utl_file.put(l_file, '~' || c1.s3_set_of_books);
      utl_file.put(l_file, '~' || c1.task);
      utl_file.put(l_file, '~' || c1.s3_task);
      utl_file.put(l_file, '~' || c1.tax_recovery_override_flag);
      utl_file.put(l_file, '~' || c1.variance_account);
      utl_file.put(l_file, '~' || c1.s3_variance_account);
      utl_file.put(l_file, '~' || c1.variance_acct_segment1);
      utl_file.put(l_file, '~' || c1.variance_acct_segment2);
      utl_file.put(l_file, '~' || c1.variance_acct_segment3);
      utl_file.put(l_file, '~' || c1.variance_acct_segment5);
      utl_file.put(l_file, '~' || c1.variance_acct_segment6);
      utl_file.put(l_file, '~' || c1.variance_acct_segment7);
      utl_file.put(l_file, '~' || c1.variance_acct_segment10);
      utl_file.put(l_file, '~' || c1.s3_variance_acct_segment1);
      utl_file.put(l_file, '~' || c1.s3_variance_acct_segment2);
      utl_file.put(l_file, '~' || c1.s3_variance_acct_segment3);
      utl_file.put(l_file, '~' || c1.s3_variance_acct_segment4);
      utl_file.put(l_file, '~' || c1.s3_variance_acct_segment5);
      utl_file.put(l_file, '~' || c1.s3_variance_acct_segment6);
      utl_file.put(l_file, '~' || c1.s3_variance_acct_segment7);
      utl_file.put(l_file, '~' || c1.s3_variance_acct_segment8);
      utl_file.put(l_file, '~' || c1.match_option);
      utl_file.put(l_file, '~' || c1.s3_match_option);
      utl_file.put(l_file, '~' || c1.amount_agreed);
      utl_file.put(l_file, '~' || c1.cleanse_status);
      utl_file.put(l_file, '~' || c1.cleanse_error);
      utl_file.put(l_file, '~' || c1.transform_status);
      utl_file.put(l_file, '~' || c1.transform_error);
      utl_file.new_line(l_file);

    END LOOP;
    utl_file.fclose(l_file);

  EXCEPTION

    WHEN OTHERS THEN
      x_retcode        := 2;
      x_errbuf         := 'Unexpected error: ' || SQLERRM;
      l_status_message := SQLCODE || chr(10) || SQLERRM;
      fnd_file.put_line(fnd_file.log, 'Unexpected error during data extraction : ' ||
                         chr(10) || l_status_message);
      fnd_file.put_line(fnd_file.log, '--------------------------------------');

  END open_po_extract_data;

  --------------------------------------------------------------------
  --  name:              data_transform_report
  --  create by:         Debarati banerjee
  --  Revision:          1.0
  --  creation date:     11/07/2016
  --------------------------------------------------------------------
  --  purpose :          write data transform report to output
  --
  --------------------------------------------------------------------
  --  ver  date          name                   desc
  --  1.0  13/05/2016    Debarati banerjee     report data transform
  --------------------------------------------------------------------

  PROCEDURE data_transform_report(p_entity VARCHAR2) IS

    l_delimiter     VARCHAR2(5) := '~';
    l_err_msg       VARCHAR2(2000);
    l_count_success NUMBER;
    l_count_fail    NUMBER;

    CURSOR c_report_po IS
      SELECT xpp.xx_po_header_id,
             xpp.po_header_id,
             xpp.s3_po_header_id,
             xpp.segment1,
             xpp.agent_name,
             xpp.s3_agent_name,
             xpp.bill_to_location,
             xpp.s3_bill_to_location,
             xpp.freight_carrier_hdr,
             xpp.s3_freight_carrier_hdr,
             xpp.fob_hdr,
             xpp.s3_fob_hdr,
             xpp.freight_terms_hdr,
             xpp.s3_freight_terms_hdr,
             xpp.operating_unit_name,
             xpp.s3_operating_unit_name,
             xpp.payment_terms_hdr,
             xpp.s3_payment_terms_hdr,
             xpp.ship_to_location_hdr,
             xpp.s3_ship_to_location_hdr,
             xpp.category,
             xpp.s3_category,
             xpp.payment_terms_ship,
             xpp.s3_payment_terms_ship, /*
                          xpp.receipt_required_flag_ship,
                          xpp.s3_receipt_required_flag_ship,*/
             xpp.ship_to_location_ship,
             xpp.s3_ship_to_location_ship,
             xpp.ship_to_org_code_ship,
             xpp.s3_ship_to_org_code_ship,
             xpp.deliver_to_location,
             xpp.s3_deliver_to_location,
             xpp.accrual_account,
             xpp.s3_accrual_account,
             xpp.accrual_acct_segment1,
             xpp.s3_accrual_acct_segment1,
             xpp.accrual_acct_segment2,
             xpp.s3_accrual_acct_segment2,
             xpp.accrual_acct_segment3,
             xpp.s3_accrual_acct_segment3,
             xpp.accrual_acct_segment5,
             xpp.s3_accrual_acct_segment5,
             xpp.accrual_acct_segment6,
             xpp.s3_accrual_acct_segment6,
             xpp.accrual_acct_segment7,
             xpp.s3_accrual_acct_segment7,
             xpp.accrual_acct_segment10,
             xpp.s3_accrual_acct_segment4,
             xpp.s3_accrual_acct_segment8,
             xpp.budget_account,
             xpp.s3_budget_account,
             xpp.budget_acct_segment1,
             xpp.s3_budget_acct_segment1,
             xpp.budget_acct_segment2,
             xpp.s3_budget_acct_segment2,
             xpp.budget_acct_segment3,
             xpp.s3_budget_acct_segment3,
             xpp.budget_acct_segment5,
             xpp.s3_budget_acct_segment5,
             xpp.budget_acct_segment6,
             xpp.s3_budget_acct_segment6,
             xpp.budget_acct_segment7,
             xpp.s3_budget_acct_segment7,
             xpp.budget_acct_segment10,
             xpp.s3_budget_acct_segment4,
             xpp.s3_budget_acct_segment8,
             xpp.charge_account,
             xpp.s3_charge_account,
             xpp.charge_acct_segment1,
             xpp.s3_charge_acct_segment1,
             xpp.charge_acct_segment2,
             xpp.s3_charge_acct_segment2,
             xpp.charge_acct_segment3,
             xpp.s3_charge_acct_segment3,
             xpp.charge_acct_segment5,
             xpp.s3_charge_acct_segment5,
             xpp.charge_acct_segment6,
             xpp.s3_charge_acct_segment6,
             xpp.charge_acct_segment7,
             xpp.s3_charge_acct_segment7,
             xpp.charge_acct_segment10,
             xpp.s3_charge_acct_segment4,
             xpp.s3_charge_acct_segment8,
             xpp.destination_organization,
             xpp.s3_destination_organization,
             xpp.expenditure_organization,
             xpp.s3_expenditure_organization,
             xpp.expenditure_type,
             xpp.s3_expenditure_type,
             xpp.set_of_books,
             xpp.s3_set_of_books,
             xpp.task,
             xpp.s3_task,
             xpp.variance_account,
             xpp.s3_variance_account,
             xpp.variance_acct_segment1,
             xpp.s3_variance_acct_segment1,
             xpp.variance_acct_segment2,
             xpp.s3_variance_acct_segment2,
             xpp.variance_acct_segment3,
             xpp.s3_variance_acct_segment3,
             xpp.variance_acct_segment5,
             xpp.s3_variance_acct_segment5,
             xpp.variance_acct_segment6,
             xpp.s3_variance_acct_segment6,
             xpp.variance_acct_segment7,
             xpp.s3_variance_acct_segment7,
             xpp.variance_acct_segment10,
             xpp.s3_variance_acct_segment4,
             xpp.s3_variance_acct_segment8,
             xpp.match_option,
             xpp.s3_match_option,
             xpp.transform_status,
             xpp.transform_error
        FROM xxs3_ptp_po xpp
       WHERE xpp.transform_status IN ('PASS', 'FAIL');

  BEGIN
    IF p_entity = 'PO' THEN

      SELECT COUNT(1)
        INTO l_count_success
        FROM xxs3_ptp_po xpp
       WHERE xpp.transform_status = 'PASS';

      SELECT COUNT(1)
        INTO l_count_fail
        FROM xxs3_ptp_po xpp
       WHERE xpp.transform_status = 'FAIL';

      fnd_file.put_line(fnd_file.output, rpad('Report name = Data Transformation Report' ||
                              l_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('========================================' ||
                              l_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('Data Migration Object Name = ' ||
                              p_entity || l_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, '');
      fnd_file.put_line(fnd_file.output, rpad('Run date and time:    ' ||
                              to_char(SYSDATE, 'dd-Mon-YYYY HH24:MI') ||
                              l_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('Total Record Count Success = ' ||
                              l_count_success ||
                              l_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('Total Record Count Failure = ' ||
                              l_count_fail || l_delimiter, 100, ' '));

      fnd_file.put_line(fnd_file.output, '');

      fnd_file.put_line(fnd_file.output, rpad('Track Name', 10, ' ') ||
                         l_delimiter ||
                         rpad('Entity Name', 15, ' ') ||
                         l_delimiter ||
                         rpad('XX_PO_HEADER_ID', 20, ' ') ||
                         l_delimiter ||
                         rpad('PO_HEADER_ID', 15, ' ') ||
                         l_delimiter ||
                         rpad('SEGMENT1', 20, ' ') ||
                         l_delimiter ||
                         rpad('AGENT_NAME', 240, ' ') ||
                         l_delimiter ||
                         rpad('S3_AGENT_NAME', 240, ' ') ||
                         l_delimiter ||
                         rpad('BILL_TO_LOCATION', 60, ' ') ||
                         l_delimiter ||
                         rpad('S3_BILL_TO_LOCATION', 60, ' ') ||
                         l_delimiter ||
                         rpad('FREIGHT_CARRIER_HDR', 25, ' ') ||
                         l_delimiter ||
                         rpad('S3_FREIGHT_CARRIER_HDR', 25, ' ') ||
                         l_delimiter ||
                         rpad('FOB_HDR', 80, ' ') ||
                         l_delimiter ||
                         rpad('S3_FOB_HDR', 80, ' ') ||
                         l_delimiter ||
                         rpad('FREIGHT_TERMS_HDR', 80, ' ') ||
                         l_delimiter ||
                         rpad('S3_FREIGHT_TERMS_HDR', 80, ' ') ||
                         l_delimiter ||
                         rpad('OPERATING_UNIT_NAME', 240, ' ') ||
                         l_delimiter ||
                         rpad('S3_OPERATING_UNIT_NAME', 240, ' ') ||
                         l_delimiter ||
                         rpad('PAYMENT_TERMS_HDR', 50, ' ') ||
                         l_delimiter ||
                         rpad('S3_PAYMENT_TERMS_HDR', 50, ' ') ||
                         l_delimiter ||
                         rpad('SHIP_TO_LOCATION_HDR', 60, ' ') ||
                         l_delimiter ||
                         rpad('S3_SHIP_TO_LOCATION_HDR', 60, ' ') ||
                         l_delimiter ||
                         rpad('CATEGORY', 286, ' ') ||
                         l_delimiter ||
                         rpad('S3_CATEGORY', 286, ' ') ||
                         l_delimiter ||
                         rpad('PAYMENT_TERMS_SHIP', 50, ' ') ||
                         l_delimiter ||
                         rpad('S3_PAYMENT_TERMS_SHIP', 50, ' ') ||
                         l_delimiter ||
                        /* rpad('RECEIPT_REQUIRED_FLAG_SHIP', 30, ' ') ||
                         l_delimiter ||
                         rpad('S3_RECEIPT_REQUIRED_FLAG_SHIP', 30, ' ') ||
                         l_delimiter ||*/
                         rpad('SHIP_TO_LOCATION_SHIP', 60, ' ') ||
                         l_delimiter ||
                         rpad('S3_SHIP_TO_LOCATION_SHIP', 60, ' ') ||
                         l_delimiter ||
                         rpad('SHIP_TO_ORG_CODE_SHIP', 30, ' ') ||
                         l_delimiter ||
                         rpad('S3_SHIP_TO_ORG_CODE_SHIP', 30, ' ') ||
                         l_delimiter ||
                         rpad('DELIVER_TO_LOCATION', 60, ' ') ||
                         l_delimiter ||
                         rpad('S3_DELIVER_TO_LOCATION', 60, ' ') ||
                         l_delimiter ||
                         rpad('ACCRUAL_ACCOUNT', 233, ' ') ||
                         l_delimiter ||
                         rpad('S3_ACCRUAL_ACCOUNT', 233, ' ') ||
                         l_delimiter ||
                         rpad('ACCRUAL_ACCT_SEGMENT1', 25, ' ') ||
                         l_delimiter ||
                         rpad('ACCRUAL_ACCT_SEGMENT2', 25, ' ') ||
                         l_delimiter ||
                         rpad('ACCRUAL_ACCT_SEGMENT3', 25, ' ') ||
                         l_delimiter ||
                         rpad('ACCRUAL_ACCT_SEGMENT5', 25, ' ') ||
                         l_delimiter ||
                         rpad('ACCRUAL_ACCT_SEGMENT6', 25, ' ') ||
                         l_delimiter ||
                         rpad('ACCRUAL_ACCT_SEGMENT7', 25, ' ') ||
                         l_delimiter ||
                         rpad('ACCRUAL_ACCT_SEGMENT10', 25, ' ') ||
                         l_delimiter ||
                         rpad('S3_ACCRUAL_ACCT_SEGMENT1', 25, ' ') ||
                         l_delimiter ||
                         rpad('S3_ACCRUAL_ACCT_SEGMENT2', 25, ' ') ||
                         l_delimiter ||
                         rpad('S3_ACCRUAL_ACCT_SEGMENT3', 25, ' ') ||
                         l_delimiter ||
                         rpad('S3_ACCRUAL_ACCT_SEGMENT4', 25, ' ') ||
                         l_delimiter ||
                         rpad('S3_ACCRUAL_ACCT_SEGMENT5', 25, ' ') ||
                         l_delimiter ||
                         rpad('S3_ACCRUAL_ACCT_SEGMENT6', 25, ' ') ||
                         l_delimiter ||
                         rpad('S3_ACCRUAL_ACCT_SEGMENT7', 25, ' ') ||
                         l_delimiter ||
                         rpad('S3_ACCRUAL_ACCT_SEGMENT8', 25, ' ') ||
                         l_delimiter ||
                         rpad('BUDGET_ACCOUNT', 233, ' ') ||
                         l_delimiter ||
                         rpad('S3_BUDGET_ACCOUNT', 233, ' ') ||
                         l_delimiter ||
                         rpad('BUDGET_ACCT_SEGMENT1', 25, ' ') ||
                         l_delimiter ||
                         rpad('BUDGET_ACCT_SEGMENT2', 25, ' ') ||
                         l_delimiter ||
                         rpad('BUDGET_ACCT_SEGMENT3', 25, ' ') ||
                         l_delimiter ||
                         rpad('BUDGET_ACCT_SEGMENT5', 25, ' ') ||
                         l_delimiter ||
                         rpad('BUDGET_ACCT_SEGMENT6', 25, ' ') ||
                         l_delimiter ||
                         rpad('BUDGET_ACCT_SEGMENT7', 25, ' ') ||
                         l_delimiter ||
                         rpad('BUDGET_ACCT_SEGMENT10', 25, ' ') ||
                         l_delimiter ||
                         rpad('S3_BUDGET_ACCT_SEGMENT1', 25, ' ') ||
                         l_delimiter ||
                         rpad('S3_BUDGET_ACCT_SEGMENT2', 25, ' ') ||
                         l_delimiter ||
                         rpad('S3_BUDGET_ACCT_SEGMENT3', 25, ' ') ||
                         l_delimiter ||
                         rpad('S3_BUDGET_ACCT_SEGMENT4', 25, ' ') ||
                         l_delimiter ||
                         rpad('S3_BUDGET_ACCT_SEGMENT5', 25, ' ') ||
                         l_delimiter ||
                         rpad('S3_BUDGET_ACCT_SEGMENT6', 25, ' ') ||
                         l_delimiter ||
                         rpad('S3_BUDGET_ACCT_SEGMENT7', 25, ' ') ||
                         l_delimiter ||
                         rpad('S3_BUDGET_ACCT_SEGMENT8', 25, ' ') ||
                         l_delimiter ||
                         rpad('CHARGE_ACCOUNT', 233, ' ') ||
                         l_delimiter ||
                         rpad('S3_CHARGE_ACCOUNT', 233, ' ') ||
                         l_delimiter ||
                         rpad('CHARGE_ACCT_SEGMENT1', 25, ' ') ||
                         l_delimiter ||
                         rpad('CHARGE_ACCT_SEGMENT2', 25, ' ') ||
                         l_delimiter ||
                         rpad('CHARGE_ACCT_SEGMENT3', 25, ' ') ||
                         l_delimiter ||
                         rpad('CHARGE_ACCT_SEGMENT5', 25, ' ') ||
                         l_delimiter ||
                         rpad('CHARGE_ACCT_SEGMENT6', 25, ' ') ||
                         l_delimiter ||
                         rpad('CHARGE_ACCT_SEGMENT7', 25, ' ') ||
                         l_delimiter ||
                         rpad('CHARGE_ACCT_SEGMENT10', 25, ' ') ||
                         l_delimiter ||
                         rpad('S3_CHARGE_ACCT_SEGMENT1', 25, ' ') ||
                         l_delimiter ||
                         rpad('S3_CHARGE_ACCT_SEGMENT2', 25, ' ') ||
                         l_delimiter ||
                         rpad('S3_CHARGE_ACCT_SEGMENT3', 25, ' ') ||
                         l_delimiter ||
                         rpad('S3_CHARGE_ACCT_SEGMENT4', 25, ' ') ||
                         l_delimiter ||
                         rpad('S3_CHARGE_ACCT_SEGMENT5', 25, ' ') ||
                         l_delimiter ||
                         rpad('S3_CHARGE_ACCT_SEGMENT6', 25, ' ') ||
                         l_delimiter ||
                         rpad('S3_CHARGE_ACCT_SEGMENT7', 25, ' ') ||
                         l_delimiter ||
                         rpad('S3_CHARGE_ACCT_SEGMENT8', 25, ' ') ||
                         l_delimiter ||
                         rpad('DESTINATION_ORGANIZATION', 240, ' ') ||
                         l_delimiter ||
                         rpad('S3_DESTINATION_ORGANIZATION', 240, ' ') ||
                         l_delimiter ||
                         rpad('EXPENDITURE_ORGANIZATION', 240, ' ') ||
                         l_delimiter ||
                         rpad('S3_EXPENDITURE_ORGANIZATION', 240, ' ') ||
                         l_delimiter ||
                         rpad('EXPENDITURE_TYPE', 30, ' ') ||
                         l_delimiter ||
                         rpad('S3_EXPENDITURE_TYPE', 30, ' ') ||
                         l_delimiter ||
                         rpad('SET_OF_BOOKS', 30, ' ') ||
                         l_delimiter ||
                         rpad('S3_SET_OF_BOOKS', 30, ' ') ||
                         l_delimiter ||
                         rpad('TASK', 20, ' ') ||
                         l_delimiter ||
                         rpad('S3_TASK', 20, ' ') ||
                         l_delimiter ||
                         rpad('VARIANCE_ACCOUNT', 233, ' ') ||
                         l_delimiter ||
                         rpad('S3_VARIANCE_ACCOUNT', 233, ' ') ||
                         l_delimiter ||
                         rpad('VARIANCE_ACCT_SEGMENT1', 25, ' ') ||
                         l_delimiter ||
                         rpad('VARIANCE_ACCT_SEGMENT2', 25, ' ') ||
                         l_delimiter ||
                         rpad('VARIANCE_ACCT_SEGMENT3', 25, ' ') ||
                         l_delimiter ||
                         rpad('VARIANCE_ACCT_SEGMENT5', 25, ' ') ||
                         l_delimiter ||
                         rpad('VARIANCE_ACCT_SEGMENT6', 25, ' ') ||
                         l_delimiter ||
                         rpad('VARIANCE_ACCT_SEGMENT7', 25, ' ') ||
                         l_delimiter ||
                         rpad('VARIANCE_ACCT_SEGMENT10', 25, ' ') ||
                         l_delimiter ||
                         rpad('S3_VARIANCE_ACCT_SEGMENT1', 25, ' ') ||
                         l_delimiter ||
                         rpad('S3_VARIANCE_ACCT_SEGMENT2', 25, ' ') ||
                         l_delimiter ||
                         rpad('S3_VARIANCE_ACCT_SEGMENT3', 25, ' ') ||
                         l_delimiter ||
                         rpad('S3_VARIANCE_ACCT_SEGMENT4', 25, ' ') ||
                         l_delimiter ||
                         rpad('S3_VARIANCE_ACCT_SEGMENT5', 25, ' ') ||
                         l_delimiter ||
                         rpad('S3_VARIANCE_ACCT_SEGMENT6', 25, ' ') ||
                         l_delimiter ||
                         rpad('S3_VARIANCE_ACCT_SEGMENT7', 25, ' ') ||
                         l_delimiter ||
                         rpad('S3_VARIANCE_ACCT_SEGMENT8', 25, ' ') ||
                         l_delimiter ||
                         rpad('MATCH_OPTION', 25, ' ') ||
                         l_delimiter ||
                         rpad('S3_MATCH_OPTION', 25, ' ') ||
                         l_delimiter ||
                         rpad('Status', 10, ' ') ||
                         l_delimiter ||
                         rpad('Error Message', 2000, ' '));

      FOR r_data IN c_report_po LOOP
        fnd_file.put_line(fnd_file.output, rpad('PTP', 10, ' ') ||
                           l_delimiter ||
                           rpad('PO', 15, ' ') ||
                           l_delimiter ||
                           rpad(r_data.xx_po_header_id, 20, ' ') ||
                           l_delimiter ||
                           rpad(r_data.po_header_id, 15, ' ') ||
                           l_delimiter ||
                           rpad(r_data.segment1, 20, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.agent_name, 'NULL'), 240, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_agent_name, 'NULL'), 240, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.bill_to_location, 'NULL'), 60, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_bill_to_location, 'NULL'), 60, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.freight_carrier_hdr, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_freight_carrier_hdr, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.fob_hdr, 'NULL'), 80, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_fob_hdr, 'NULL'), 80, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.freight_terms_hdr, 'NULL'), 80, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_freight_terms_hdr, 'NULL'), 80, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.operating_unit_name, 'NULL'), 240, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_operating_unit_name, 'NULL'), 240, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.payment_terms_hdr, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_payment_terms_hdr, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.ship_to_location_hdr, 'NULL'), 60, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_ship_to_location_hdr, 'NULL'), 60, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.category, 'NULL'), 286, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_category, 'NULL'), 286, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.payment_terms_ship, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_payment_terms_ship, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                          /* rpad(nvl(r_data.receipt_required_flag_ship, 'NULL'), 1, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_receipt_required_flag_ship, 'NULL'), 1, ' ') ||
                           l_delimiter ||*/
                           rpad(nvl(r_data.ship_to_location_ship, 'NULL'), 60, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_ship_to_location_ship, 'NULL'), 60, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.ship_to_org_code_ship, 'NULL'), 60, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_ship_to_org_code_ship, 'NULL'), 60, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.deliver_to_location, 'NULL'), 60, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_deliver_to_location, 'NULL'), 60, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.accrual_account, 'NULL'), 233, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_accrual_account, 'NULL'), 233, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.accrual_acct_segment1, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.accrual_acct_segment2, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.accrual_acct_segment3, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.accrual_acct_segment5, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.accrual_acct_segment6, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.accrual_acct_segment7, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.accrual_acct_segment10, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_accrual_acct_segment1, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_accrual_acct_segment2, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_accrual_acct_segment3, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_accrual_acct_segment4, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_accrual_acct_segment5, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_accrual_acct_segment6, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_accrual_acct_segment7, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_accrual_acct_segment8, 'NULL'), 25, ' ') ||
                           l_delimiter ||

                           rpad(nvl(r_data.budget_account, 'NULL'), 233, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_budget_account, 'NULL'), 233, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.budget_acct_segment1, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.budget_acct_segment2, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.budget_acct_segment3, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.budget_acct_segment5, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.budget_acct_segment6, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.budget_acct_segment7, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.budget_acct_segment10, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_budget_acct_segment1, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_budget_acct_segment2, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_budget_acct_segment3, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_budget_acct_segment4, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_budget_acct_segment5, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_budget_acct_segment6, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_budget_acct_segment7, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_budget_acct_segment8, 'NULL'), 25, ' ') ||
                           l_delimiter ||

                           rpad(nvl(r_data.charge_account, 'NULL'), 233, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_charge_account, 'NULL'), 233, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.charge_acct_segment1, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.charge_acct_segment2, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.charge_acct_segment3, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.charge_acct_segment5, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.charge_acct_segment6, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.charge_acct_segment7, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.charge_acct_segment10, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_charge_acct_segment1, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_charge_acct_segment2, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_charge_acct_segment3, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_charge_acct_segment4, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_charge_acct_segment5, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_charge_acct_segment6, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_charge_acct_segment7, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_charge_acct_segment8, 'NULL'), 25, ' ') ||
                           l_delimiter ||

                           rpad(nvl(r_data.destination_organization, 'NULL'), 240, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_destination_organization, 'NULL'), 240, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.expenditure_organization, 'NULL'), 240, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_expenditure_organization, 'NULL'), 240, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.expenditure_type, 'NULL'), 30, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_expenditure_type, 'NULL'), 30, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.set_of_books, 'NULL'), 30, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_set_of_books, 'NULL'), 30, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.task, 'NULL'), 20, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_task, 'NULL'), 20, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.variance_account, 'NULL'), 233, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_variance_account, 'NULL'), 233, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.variance_acct_segment1, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.variance_acct_segment2, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.variance_acct_segment3, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.variance_acct_segment5, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.variance_acct_segment6, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.variance_acct_segment7, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.variance_acct_segment10, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_variance_acct_segment1, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_variance_acct_segment2, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_variance_acct_segment3, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_variance_acct_segment4, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_variance_acct_segment5, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_variance_acct_segment6, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_variance_acct_segment7, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_variance_acct_segment8, 'NULL'), 25, ' ') ||
                           l_delimiter ||

                           rpad(nvl(r_data.match_option, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_match_option, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(r_data.transform_status, 10, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.transform_error, 'NULL'), 2000, ' '));
      END LOOP;

      fnd_file.put_line(fnd_file.output, '');
      fnd_file.put_line(fnd_file.output, 'Stratasys Confidential' ||
                         l_delimiter);

    END IF;

  END data_transform_report;

  --------------------------------------------------------------------
  --  name:              dq_report
  --  create by:         Debarati banerjee
  --  Revision:          1.0
  --  creation date:     01/08/2016
  --------------------------------------------------------------------
  --  purpose :          write dq report to output
  --
  --------------------------------------------------------------------
  --  ver  date          name                   desc
  --  1.0  01/08/2016    Debarati banerjee     report DQ errors
  --------------------------------------------------------------------

  PROCEDURE dq_report(p_entity VARCHAR2) IS

    l_delimiter    VARCHAR2(5) := '~';
    l_err_msg      VARCHAR2(2000);
    l_count_dq     NUMBER;
    l_count_reject NUMBER;

    CURSOR c_report_po IS
      SELECT nvl(xppd.rule_name, ' ') rule_name,
             nvl(xppd.notes, ' ') notes,
             xpp.po_header_id,
             xpp.segment1,
             xppd.xx_po_header_id,
             decode(xpp.process_flag, 'R', 'Y', 'Q', 'N') reject_record
        FROM xxs3_ptp_po xpp, xxs3_ptp_po_dq xppd
       WHERE xpp.xx_po_header_id = xppd.xx_po_header_id
         AND xpp.process_flag IN ('Q', 'R')
       ORDER BY po_header_id DESC;

  BEGIN
    /*
    x_err_code := 0;
    x_err_msg  := '';*/
    IF p_entity = 'PO' THEN

      SELECT COUNT(1)
        INTO l_count_dq
        FROM xxs3_ptp_po xpp
       WHERE xpp.process_flag IN ('Q', 'R');

      SELECT COUNT(1)
        INTO l_count_reject
        FROM xxs3_ptp_po xpp
       WHERE xpp.process_flag = 'R';

      fnd_file.put_line(fnd_file.output, rpad('Report name = Data Quality Error Report' ||
                              l_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('========================================' ||
                              l_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('Data Migration Object Name = ' ||
                              p_entity || l_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, '');
      fnd_file.put_line(fnd_file.output, rpad('Run date and time:    ' ||
                              to_char(SYSDATE, 'dd-Mon-YYYY HH24:MI') ||
                              l_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('Total Record Count Having DQ Issues = ' ||
                              l_count_dq || l_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('Total Record Count Rejected =  ' ||
                              l_count_reject || l_delimiter, 100, ' '));

      fnd_file.put_line(fnd_file.output, '');

      fnd_file.put_line(fnd_file.output, rpad('Track Name', 10, ' ') ||
                         l_delimiter ||
                         rpad('Entity Name', 11, ' ') ||
                         l_delimiter ||
                         rpad('XX PO Header ID', 30, ' ') ||
                         l_delimiter ||
                         rpad('PO Header ID', 10, ' ') ||
                         l_delimiter ||
                         rpad('Segment1', 20, ' ') ||
                         l_delimiter ||
                         rpad('Reject Record Flag(Y/N)', 22, ' ') ||
                         l_delimiter ||
                         rpad('Rule Name', 45, ' ') ||
                         l_delimiter ||
                         rpad('Reason Code', 50, ' '));

      FOR r_data IN c_report_po LOOP
        fnd_file.put_line(fnd_file.output, rpad('PTP', 10, ' ') ||
                           l_delimiter ||
                           rpad('PO', 11, ' ') ||
                           l_delimiter ||
                           rpad(r_data.xx_po_header_id, 30, ' ') ||
                           l_delimiter ||
                           rpad(r_data.po_header_id, 10, ' ') ||
                           l_delimiter ||
                           rpad(r_data.segment1, 20, ' ') ||
                           l_delimiter ||
                           rpad(r_data.reject_record, 22, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.rule_name, 'NULL'), 45, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.notes, 'NULL'), 50, ' '));

      END LOOP;

      fnd_file.put_line(fnd_file.output, '');
      fnd_file.put_line(fnd_file.output, 'Stratasys Confidential' ||
                         l_delimiter);
    END IF;
  END dq_report;

  --------------------------------------------------------------------
  --  name:              data_cleanse_report
  --  create by:         Debarati banerjee
  --  Revision:          1.0
  --  creation date:     01/08/2016
  --------------------------------------------------------------------
  --  purpose :          write data cleanse report to output
  --
  --------------------------------------------------------------------
  --  ver  date          name                   desc
  --  1.0  01/08/2016    Debarati banerjee     report data cleanse
  --------------------------------------------------------------------

  PROCEDURE data_cleanse_report(p_entity VARCHAR2) IS

    l_delimiter     VARCHAR2(5) := '~';
    l_err_msg       VARCHAR2(2000);
    l_count_success NUMBER;
    l_count_fail    NUMBER;

    CURSOR c_report_po IS
      SELECT xpp.po_header_id po_header_id,
             xpp.match_option,
             xpp.s3_match_option,
             /*xpp.receipt_required_flag_ship,
                          xpp.s3_receipt_required_flag_ship,*/
             xpp.xx_po_header_id xx_po_header_id,
             xpp.segment1,
             xpp.cleanse_status,
             xpp.cleanse_error
        FROM xxs3_ptp_po xpp
       WHERE xpp.cleanse_status IN ('PASS', 'FAIL');

  BEGIN
    /*
    x_err_code := 0;
    x_err_msg  := '';*/
    IF p_entity = 'PO' THEN

      SELECT COUNT(1)
        INTO l_count_success
        FROM xxs3_ptp_po xpp
       WHERE xpp.cleanse_status = 'PASS';

      SELECT COUNT(1)
        INTO l_count_fail
        FROM xxs3_ptp_po xpp
       WHERE xpp.cleanse_status = 'FAIL';

      fnd_file.put_line(fnd_file.output, rpad('Report name = Automated Cleanse & Standardize Report' ||
                              l_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('====================================================' ||
                              l_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('Data Migration Object Name = ' ||
                              p_entity || l_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, '');
      fnd_file.put_line(fnd_file.output, rpad('Run date and time:    ' ||
                              to_char(SYSDATE, 'dd-Mon-YYYY HH24:MI') ||
                              l_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('Total Record Count Success = ' ||
                              l_count_success ||
                              l_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('Total Record Count Failure = ' ||
                              l_count_fail || l_delimiter, 100, ' '));

      fnd_file.put_line(fnd_file.output, '');

      fnd_file.put_line(fnd_file.output, rpad('Track Name', 10, ' ') ||
                         l_delimiter ||
                         rpad('Entity Name', 11, ' ') ||
                         l_delimiter ||
                         rpad('XX PO Header ID', 30, ' ') ||
                         l_delimiter ||
                         rpad('PO Header ID', 30, ' ') ||
                         l_delimiter ||
                         rpad('Segment1', 30, ' ') ||
                         l_delimiter ||
                         rpad('Match Option', 40, ' ') ||
                         l_delimiter ||
                         rpad('S3 Match Option', 40, ' ') ||
                         l_delimiter ||
                         rpad('Receipt Reqd flag', 30, ' ') ||
                         l_delimiter ||
                         rpad('S3 Receipt Reqd flag', 30, ' ') ||
                         l_delimiter ||
                         rpad('Status', 10, ' ') ||
                         l_delimiter ||
                         rpad('Error Message', 200, ' '));

      FOR r_data IN c_report_po LOOP
        fnd_file.put_line(fnd_file.output, rpad('PTP', 10, ' ') ||
                           l_delimiter ||
                           rpad('PO', 11, ' ') ||
                           l_delimiter ||
                           rpad(r_data.xx_po_header_id, 30, ' ') ||
                           l_delimiter ||
                           rpad(r_data.po_header_id, 30, ' ') ||
                           l_delimiter ||
                           rpad(r_data.segment1, 30, ' ') ||
                           l_delimiter ||
                           rpad(r_data.match_option, 40, ' ') ||
                           l_delimiter ||
                           rpad(r_data.s3_match_option, 40, ' ') ||
                           l_delimiter ||
                           /*rpad(r_data.receipt_required_flag_ship, 30, ' ') ||
                           l_delimiter ||
                           rpad(r_data.s3_receipt_required_flag_ship, 30, ' ') ||
                           l_delimiter ||*/
                           rpad(r_data.cleanse_status, 10, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.cleanse_error, 'NULL'), 200, ' '));

      END LOOP;

      fnd_file.put_line(fnd_file.output, '');
      fnd_file.put_line(fnd_file.output, 'Stratasys Confidential' ||
                         l_delimiter);

    END IF;
  END data_cleanse_report;
END xxs3_ptp_po_pkg;
/
