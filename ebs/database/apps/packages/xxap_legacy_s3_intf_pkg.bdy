CREATE OR REPLACE PACKAGE BODY xxap_legacy_s3_intf_pkg

-- =============================================================================
-- Copyright(c) :
-- Application  : Custom Application
-- -----------------------------------------------------------------------------
-- Program name                      Creation Date    Original Ver    Created by
-- xxap_legacy_s3_intf_pkg            30-JUL-2016      1.0             TCS
-- -----------------------------------------------------------------------------
-- Usage: This will be used as Auto AP Invoice Creation program based on AR Invoice.
-- This is the Package Specification.
-- -----------------------------------------------------------------------------
-- Description: This program will be used to create
--              AP invoice for AR Invoice in legacy.
-- Parameter    : Written in each procedure section.
-- Return value : Written in each procedure section.
-- -----------------------------------------------------------------------------
-- Modification History:
-- Modified Date     Version      Done by       Change Description
--
-- =============================================================================
 IS
  -- ===========================================================================
  --                     Global Variable Declaration
  -- ===========================================================================
  g_last_updated_by    NUMBER := fnd_global.user_id;
  g_last_update_login  NUMBER := fnd_global.conc_login_id;
  g_sqlerrm            VARCHAR2(2000) := NULL;
  g_error_msg          VARCHAR2(4000) := NULL;
  g_step_id            VARCHAR2(100) := NULL;
  g_request_id         NUMBER := NULL;
  g_last_update_date   DATE := SYSDATE;
  g_created_by         NUMBER := fnd_global.user_id;
  g_creation_date      DATE := SYSDATE;
  g_group_id           NUMBER := NULL;

  -- ===========================================================================
  --                       Global Exception Declaration
  -- ===========================================================================
  e_abort EXCEPTION;

  -- ===========================================================================
  --                     Start of Procedure INVOICE_LN_CREATION
  -- ===========================================================================
  PROCEDURE invoice_ln_creation(p_invoice_num IN VARCHAR2,
                                x_status      OUT VARCHAR2)
  -- ===========================================================================
    --  Program name                 Creation Date               Created by
    --  INVOICE_LN_CREATION           30-JUL-2016                TCS
    -- ---------------------------------------------------------------------------
    -- Description  : This procedure is used to insert the invoice line record.
    --
    -- Return value : None
    --
    -- ===========================================================================
   IS
    -- Cursor decleration - Start.
    CURSOR c_line_invoice(p_inv_num VARCHAR2) IS
      SELECT xails.ROWID, xails.*
        FROM xx_ap_invoices_line_stg xails
       WHERE xails.invoice_num = p_inv_num;
    --  AND  xails.status = 'V';

    -- Cursor decleration - End.

    -- Variable decleration - Start.
    l_line_status VARCHAR2(10) := 'S';
    l_error_msg   VARCHAR2(30000) := NULL;

    -- Variable decleration - End.

  BEGIN

    FND_FILE.PUT_LINE(FND_FILE.LOG,
                      CHR(13) || 'Procedure invoice_ln_creation - Start');

    FOR line_invoice_rec IN c_line_invoice(p_invoice_num) LOOP
      BEGIN
        INSERT INTO ap_invoice_lines_interface
          (invoice_id,
           invoice_line_id,
           line_number,
           line_type_lookup_code,
           amount,
           accounting_date,
           description,
           final_match_flag,
           po_header_id,
           po_number,
           po_line_id,
           po_line_number,
           po_line_location_id,
           po_shipment_num,
           po_distribution_id,
           po_distribution_num,
           inventory_item_id,
           item_description,
           quantity_invoiced,
           ship_to_location_code,
           unit_price,
           distribution_set_id,
           distribution_set_name,
           dist_code_concatenated,
           dist_code_combination_id,
           awt_group_id,
           awt_group_name,
           last_updated_by,
           last_update_date,
           last_update_login,
           created_by,
           creation_date,
           attribute_category,
           attribute1,
           attribute2,
           attribute3,
           attribute4,
           attribute5,
           attribute6,
           attribute7,
           attribute8,
           attribute9,
           attribute10,
           attribute11,
           attribute12,
           attribute13,
           attribute14,
           attribute15,
           global_attribute_category,
           global_attribute1,
           global_attribute2,
           global_attribute3,
           global_attribute4,
           global_attribute5,
           global_attribute6,
           global_attribute7,
           global_attribute8,
           global_attribute9,
           global_attribute10,
           global_attribute11,
           global_attribute12,
           global_attribute13,
           global_attribute14,
           global_attribute15,
           global_attribute16,
           global_attribute17,
           global_attribute18,
           global_attribute19,
           global_attribute20,
           po_release_id,
           release_num,
           project_id,
           task_id,
           expenditure_type,
           expenditure_item_date,
           expenditure_organization_id,
           pa_quantity,
           type_1099,
           income_tax_region,
           assets_tracking_flag,
           org_id,
           receipt_number,
           receipt_line_number,
           match_option,
           trx_business_category,
           tax_regime_code,
           tax,
           tax_jurisdiction_code,
           tax_status_code,
           tax_rate_id,
           tax_rate_code,
           tax_rate,
           requester_first_name,
           requester_last_name,
           requester_employee_num,
           serial_number,
           manufacturer,
           model_number,
           asset_book_type_code,
           assessable_value,
           product_type,
           amount_includes_tax_flag,
           tax_code,
           po_unit_of_measure,
           ussgl_transaction_code,
           tax_recovery_rate,
           tax_recovery_override_flag,
           tax_recoverable_flag,
           tax_code_override_flag,
           tax_code_id,
           taxable_flag,
           deferred_acctg_flag,
           def_acctg_start_date,
           def_acctg_end_date,
           def_acctg_number_of_periods,
           def_acctg_period_type,
           control_amount,
           tax_classification_code,
           expense_group)
        VALUES
          (ap_invoices_interface_s.CURRVAL,
           line_invoice_rec.invoice_line_id,
           line_invoice_rec.line_number,
           line_invoice_rec.line_type_lookup_code,
           line_invoice_rec.amount,
           line_invoice_rec.accounting_date,
           line_invoice_rec.description,
           line_invoice_rec.final_match_flag,
           line_invoice_rec.po_header_id,
           line_invoice_rec.po_number,
           line_invoice_rec.po_line_id,
           line_invoice_rec.po_line_number,
           line_invoice_rec.po_line_location_id,
           line_invoice_rec.po_shipment_num,
           line_invoice_rec.po_distribution_id,
           line_invoice_rec.po_distribution_num,
           line_invoice_rec.inventory_item_id,
           line_invoice_rec.item_description,
           line_invoice_rec.quantity_invoiced,
           line_invoice_rec.ship_to_location_code,
           line_invoice_rec.unit_price,
           line_invoice_rec.distribution_set_id,
           line_invoice_rec.distribution_set_name,
           line_invoice_rec.dist_code_concatenated,
           line_invoice_rec.dist_code_combination_id,
           line_invoice_rec.awt_group_id,
           line_invoice_rec.awt_group_name,
           g_last_updated_by,
           g_last_update_date,
           g_last_update_login,
           g_created_by,
           g_creation_date,
           line_invoice_rec.attribute_category,
           line_invoice_rec.attribute1,
           line_invoice_rec.attribute2,
           line_invoice_rec.attribute3,
           line_invoice_rec.attribute4,
           line_invoice_rec.attribute5,
           line_invoice_rec.attribute6,
           line_invoice_rec.attribute7,
           line_invoice_rec.attribute8,
           line_invoice_rec.attribute9,
           line_invoice_rec.attribute10,
           line_invoice_rec.attribute11,
           line_invoice_rec.attribute12,
           line_invoice_rec.attribute13,
           line_invoice_rec.attribute14,
           line_invoice_rec.attribute15,
           line_invoice_rec.global_attribute_category,
           line_invoice_rec.global_attribute1,
           line_invoice_rec.global_attribute2,
           line_invoice_rec.global_attribute3,
           line_invoice_rec.global_attribute4,
           line_invoice_rec.global_attribute5,
           line_invoice_rec.global_attribute6,
           line_invoice_rec.global_attribute7,
           line_invoice_rec.global_attribute8,
           line_invoice_rec.global_attribute9,
           line_invoice_rec.global_attribute10,
           line_invoice_rec.global_attribute11,
           line_invoice_rec.global_attribute12,
           line_invoice_rec.global_attribute13,
           line_invoice_rec.global_attribute14,
           line_invoice_rec.global_attribute15,
           line_invoice_rec.global_attribute16,
           line_invoice_rec.global_attribute17,
           line_invoice_rec.global_attribute18,
           line_invoice_rec.global_attribute19,
           line_invoice_rec.global_attribute20,
           line_invoice_rec.po_release_id,
           line_invoice_rec.release_num,
           line_invoice_rec.project_id,
           line_invoice_rec.task_id,
           line_invoice_rec.expenditure_type,
           line_invoice_rec.expenditure_item_date,
           line_invoice_rec.expenditure_organization_id,
           line_invoice_rec.pa_quantity,
           line_invoice_rec.type_1099,
           line_invoice_rec.income_tax_region,
           line_invoice_rec.assets_tracking_flag,
           line_invoice_rec.org_id,
           line_invoice_rec.receipt_number,
           line_invoice_rec.receipt_line_number,
           line_invoice_rec.match_option,
           line_invoice_rec.trx_business_category,
           line_invoice_rec.tax_regime_code,
           line_invoice_rec.tax,
           line_invoice_rec.tax_jurisdiction_code,
           line_invoice_rec.tax_status_code,
           line_invoice_rec.tax_rate_id,
           line_invoice_rec.tax_rate_code,
           line_invoice_rec.tax_rate,
           line_invoice_rec.requester_first_name,
           line_invoice_rec.requester_last_name,
           line_invoice_rec.requester_employee_num,
           line_invoice_rec.serial_number,
           line_invoice_rec.manufacturer,
           line_invoice_rec.model_number,
           line_invoice_rec.asset_book_type_code,
           line_invoice_rec.assessable_value,
           line_invoice_rec.product_type,
           line_invoice_rec.amount_includes_tax_flag,
           line_invoice_rec.tax_code,
           line_invoice_rec.po_unit_of_measure,
           line_invoice_rec.ussgl_transaction_code,
           line_invoice_rec.tax_recovery_rate,
           line_invoice_rec.tax_recovery_override_flag,
           line_invoice_rec.tax_recoverable_flag,
           line_invoice_rec.tax_code_override_flag,
           line_invoice_rec.tax_code_id,
           line_invoice_rec.taxable_flag,
           line_invoice_rec.deferred_acctg_flag,
           line_invoice_rec.def_acctg_start_date,
           line_invoice_rec.def_acctg_end_date,
           line_invoice_rec.def_acctg_number_of_periods,
           line_invoice_rec.def_acctg_period_type,
           line_invoice_rec.control_amount,
           line_invoice_rec.tax_classification_code,
           line_invoice_rec.expense_group);
        x_status := 'S';
      EXCEPTION
        WHEN OTHERS THEN
          g_step_id     := 'L01';
          l_line_status := 'I';
          l_error_msg   := 'Failed to insert the record' ||
                           ' in Line interface table for the  ' ||
                           'invoice number "' ||
                           line_invoice_rec.invoice_num || '" and ' ||
                           'Invoice Line Number "' ||
                           line_invoice_rec.line_number || '" Error : ' ||
                           SQLERRM;
          --  l_error_count := l_error_count + 1;
          x_status := 'I';
      END;
      IF l_line_status = 'I' THEN
        x_status := 'I';
        --update error
        BEGIN
          UPDATE xx_ap_invoices_line_stg xails
             SET xails.status        = l_line_status,
                 xails.error_message = 'LINE CREATION ERROR'
           WHERE xails.ROWID = line_invoice_rec.ROWID;
        EXCEPTION
          WHEN OTHERS THEN
            g_step_id   := 'L02';
            g_sqlerrm   := SQLERRM;
            g_error_msg := 'Unexceptional error while updating valid status';
            RAISE e_abort;
        END;
      ELSE
        --update success
        BEGIN
          UPDATE xx_ap_invoices_line_stg xails
             SET xails.status        = l_line_status,
                 xails.error_message = 'LINES CREATED'
           WHERE xails.ROWID = line_invoice_rec.ROWID;
        EXCEPTION
          WHEN OTHERS THEN
            g_step_id   := 'L03';
            g_sqlerrm   := SQLERRM;
            g_error_msg := 'Unexceptional error while updating valid status';
            RAISE e_abort;
        END;
      END IF;
    END LOOP;
  EXCEPTION
    WHEN OTHERS THEN
      g_step_id   := 'L04';
      g_sqlerrm   := SQLERRM;
      g_error_msg := 'Unexceptional Error has occured in invoice Line creation procedure invoice_ln_creation';
      fnd_file.put_line(fnd_file.log, 'Sqlerrm : ' || g_sqlerrm);
      fnd_file.put_line(fnd_file.log, 'Error Message : ' || g_error_msg);
      fnd_file.put_line(fnd_file.log, 'Step Id : ' || g_step_id);
      RAISE e_abort;
  END invoice_ln_creation;
  -- ===========================================================================
  --                     End of Procedure INVOICE_LN_CREATION
  -- ===========================================================================

  -- ===========================================================================
  --                     Start of Procedure INVOICE_HDR_CREATION
  -- ===========================================================================
  PROCEDURE invoice_hdr_creation
  -- ===========================================================================
    --  Program name                 Creation Date               Created by
    --  INVOICE_HDR_CREATION              18-JUN-2016                 TCS
    -- ---------------------------------------------------------------------------
    -- Description  : This procedure is used to insert the invoice header record.
    --
    -- Return value : None
    --
    -- ===========================================================================
   IS
    -- Cursor decleration - Start.
    CURSOR c_hdr_invoice IS
      SELECT distinct xaihs.*, xaihs.ROWID
        FROM xx_ap_invoices_hdr_stg xaihs
       WHERE xaihs.status = 'V';

    -- Cursor decleration - End.

    -- Variable decleration - Start.
    l_error_msg     VARCHAR2(30000);
    l_record_status VARCHAR2(10) := 'S';
    l_out_status    VARCHAR2(10) := 'S';

    -- Variable decleration - End.

  BEGIN

    FND_FILE.PUT_LINE(FND_FILE.LOG,
                      CHR(13) || 'Procedure invoice_hdr_creation - Start');

    FOR hdr_invoice_rec IN c_hdr_invoice LOOP
      BEGIN
        INSERT INTO ap_invoices_interface
          (invoice_id,
           invoice_num,
           invoice_type_lookup_code,
           invoice_date,
           po_number,
           vendor_id,
           vendor_num,
           vendor_name,
           vendor_site_id,
           vendor_site_code,
           invoice_amount,
           invoice_currency_code,
           exchange_rate,
           exchange_rate_type,
           exchange_date,
           terms_id,
           terms_name,
           description,
           last_update_date,
           last_updated_by,
           last_update_login,
           creation_date,
           created_by,
           attribute_category,
           attribute1,
           attribute2,
           attribute3,
           attribute4,
           attribute5,
           attribute6,
           attribute7,
           attribute8,
           attribute9,
           attribute10,
           attribute11,
           attribute12,
           attribute13,
           attribute14,
           attribute15,
           global_attribute_category,
           global_attribute1,
           global_attribute2,
           global_attribute3,
           global_attribute4,
           global_attribute5,
           global_attribute6,
           global_attribute7,
           global_attribute8,
           global_attribute9,
           global_attribute10,
           global_attribute11,
           global_attribute12,
           global_attribute13,
           global_attribute14,
           global_attribute15,
           global_attribute16,
           global_attribute17,
           global_attribute18,
           global_attribute19,
           global_attribute20,
           source,
           group_id,
           payment_method_lookup_code,
           payment_method_code,
           payment_currency_code,
           doc_category_code,
           voucher_num,
           pay_group_lookup_code,
           gl_date,
           accts_pay_code_concatenated,
           accts_pay_code_combination_id,
           operating_unit,
           org_id,
           amount_applicable_to_discount,
           terms_date,
           awt_group_name,
           payment_cross_rate_type,
           payment_cross_rate_date,
           payment_cross_rate,
           workflow_flag,
           goods_received_date,
           invoice_received_date,
           prepay_num,
           prepay_dist_num,
           prepay_apply_amount,
           prepay_gl_date,
           invoice_includes_prepay_flag,
           legal_entity_name,
           payment_reason_code,
           payment_reason_comments)
        VALUES
          (ap_invoices_interface_s.NEXTVAL,
           hdr_invoice_rec.invoice_num,
           hdr_invoice_rec.invoice_type_lookup_code,
           hdr_invoice_rec.invoice_date,
           hdr_invoice_rec.po_number,
           hdr_invoice_rec.vendor_id,
           hdr_invoice_rec.vendor_num,
           hdr_invoice_rec.vendor_name,
           hdr_invoice_rec.vendor_site_id,
           hdr_invoice_rec.vendor_site_code,
           hdr_invoice_rec.invoice_amount,
           hdr_invoice_rec.invoice_currency_code,
           hdr_invoice_rec.exchange_rate,
           hdr_invoice_rec.exchange_rate_type,
           hdr_invoice_rec.exchange_date,
           hdr_invoice_rec.terms_id,
           hdr_invoice_rec.terms,
           hdr_invoice_rec.description,
           g_last_update_date,
           g_last_updated_by,
           g_last_update_login,
           g_creation_date,
           g_created_by,
           hdr_invoice_rec.attribute_category,
           hdr_invoice_rec.attribute1,
           hdr_invoice_rec.attribute2,
           hdr_invoice_rec.attribute3,
           hdr_invoice_rec.attribute4,
           hdr_invoice_rec.attribute5,
           hdr_invoice_rec.attribute6,
           hdr_invoice_rec.attribute7,
           hdr_invoice_rec.attribute8,
           hdr_invoice_rec.attribute9,
           hdr_invoice_rec.attribute10,
           hdr_invoice_rec.attribute11,
           hdr_invoice_rec.attribute12,
           hdr_invoice_rec.attribute13,
           hdr_invoice_rec.attribute14,
           hdr_invoice_rec.attribute15,
           hdr_invoice_rec.global_attribute_category,
           hdr_invoice_rec.global_attribute1,
           hdr_invoice_rec.global_attribute2,
           hdr_invoice_rec.global_attribute3,
           hdr_invoice_rec.global_attribute4,
           hdr_invoice_rec.global_attribute5,
           hdr_invoice_rec.global_attribute6,
           hdr_invoice_rec.global_attribute7,
           hdr_invoice_rec.global_attribute8,
           hdr_invoice_rec.global_attribute9,
           hdr_invoice_rec.global_attribute10,
           hdr_invoice_rec.global_attribute11,
           hdr_invoice_rec.global_attribute12,
           hdr_invoice_rec.global_attribute13,
           hdr_invoice_rec.global_attribute14,
           hdr_invoice_rec.global_attribute15,
           hdr_invoice_rec.global_attribute16,
           hdr_invoice_rec.global_attribute17,
           hdr_invoice_rec.global_attribute18,
           hdr_invoice_rec.global_attribute19,
           hdr_invoice_rec.global_attribute20,
           hdr_invoice_rec.source,
           g_group_id,
           hdr_invoice_rec.payment_method_lookup_code,
           hdr_invoice_rec.payment_method_code,
           hdr_invoice_rec.payment_currency_code,
           hdr_invoice_rec.doc_category_code,
           hdr_invoice_rec.voucher_num,
           hdr_invoice_rec.pay_group_lookup_code,
           hdr_invoice_rec.gl_date,
           hdr_invoice_rec.liability_account,
           hdr_invoice_rec.liability_cc_id,
           hdr_invoice_rec.operating_unit,
           hdr_invoice_rec.org_id,
           hdr_invoice_rec.amount_applicable_to_discount,
           hdr_invoice_rec.terms_date,
           hdr_invoice_rec.awt_group_name,
           hdr_invoice_rec.payment_cross_rate_type,
           hdr_invoice_rec.payment_cross_rate_date,
           hdr_invoice_rec.payment_cross_rate,
           hdr_invoice_rec.workflow_flag,
           hdr_invoice_rec.goods_received_date,
           hdr_invoice_rec.invoice_received_date,
           hdr_invoice_rec.prepay_num,
           hdr_invoice_rec.prepay_dist_num,
           hdr_invoice_rec.prepay_apply_amount,
           hdr_invoice_rec.prepay_gl_date,
           hdr_invoice_rec.invoice_includes_prepay_flag,
           hdr_invoice_rec.legal_entity_name,
           hdr_invoice_rec.payment_reason_code,
           hdr_invoice_rec.payment_reason_comments);

        FND_FILE.PUT_LINE(FND_FILE.LOG,
                          CHR(13) ||
                          'Procedure invoice_ln_creation - calling');

        invoice_ln_creation(p_invoice_num => hdr_invoice_rec.invoice_num,
                            x_status      => l_out_status);
      EXCEPTION
        WHEN OTHERS THEN
          g_step_id       := 'H01';
          l_error_msg     := 'Failed to insert the record' ||
                             ' in interface table for the invoice ' ||
                             'Number "' || hdr_invoice_rec.invoice_num ||
                             '" Error : ' || SQLERRM;
          l_record_status := 'I';
      END;
      --Update the staging table - Start.
      IF /*l_out_status = 'I' OR*/
       l_record_status = 'I' THEN
        BEGIN
          UPDATE xx_ap_invoices_hdr_stg xaihs
             SET xaihs.status        = l_record_status,
                 xaihs.error_message = 'HEADER CREATION ERROR'
           WHERE xaihs.ROWID = hdr_invoice_rec.ROWID;
        EXCEPTION
          WHEN OTHERS THEN
            g_step_id   := 'H02';
            g_sqlerrm   := SQLERRM;
            g_error_msg := 'Unexceptional error while updating the status';
            RAISE e_abort;
        END;
      ELSE
        BEGIN
          UPDATE xx_ap_invoices_hdr_stg xaihs
             SET xaihs.status = l_record_status, xaihs.error_message = NULL
           WHERE xaihs.ROWID = hdr_invoice_rec.ROWID;
        EXCEPTION
          WHEN OTHERS THEN
            g_step_id   := 'H03';
            g_sqlerrm   := SQLERRM;
            g_error_msg := 'Unexceptional error while updating the status';
            RAISE e_abort;
        END;
      END IF;
      --Update the insterface table - End.

    END LOOP;
  EXCEPTION
    WHEN e_abort THEN
      RAISE e_abort;
    WHEN OTHERS THEN
      g_step_id   := 'H04';
      g_sqlerrm   := SQLERRM;
      g_error_msg := 'Unexceptional Error has' ||
                     ' Occurred hence the Program is aborted';
      g_step_id   := 'HI03';
      fnd_file.put_line(fnd_file.log, 'Sqlerrm : ' || g_sqlerrm);
      fnd_file.put_line(fnd_file.log, 'Error Message : ' || g_error_msg);
      fnd_file.put_line(fnd_file.log, 'Step Id : ' || g_step_id);
      RAISE e_abort;

  END invoice_hdr_creation;

  -- ===========================================================================
  --                     Start of Procedure VALIDATE_INVOICE_LN
  -- ===========================================================================
  PROCEDURE invoice_ln_validate(p_invoice_num IN VARCHAR2,
                                p_request_id  IN NUMBER,
                                x_err_message OUT VARCHAR2,
                                x_err_flag    OUT VARCHAR2)
  -- ===========================================================================
    --  Program name                 Creation Date               Created by
    --  invoice_ln_validate            2-AUG-2016                 TCS
    -- ---------------------------------------------------------------------------
    -- Description  : This procedure is used to validate the invoice line record.
    --
    -- Return value : None
    --
    -- ===========================================================================
   IS
    -- Local Variable Declaration - Start.
    l_error_msg              VARCHAR2(4000);
    l_err_flag               VARCHAR2(20);
    l_line_error             VARCHAR2(4000);
    l_line_flag              VARCHAR2(2);
    l_inv_line_type_cnt      NUMBER;
    l_master_org_id_cnt      NUMBER;
    l_dist_code_cnt          NUMBER;
    l_vendor_num_cnt         NUMBER;
    l_po_num_cnt             NUMBER;
    l_invoice_num            ap_invoices_all.invoice_num%TYPE;


    -- Local Variable Declaration - End.

    -- Cursor Declaration - Start
    -- This cursor will fetch all the new records from the Invoice line staging
    -- table
    CURSOR c_inv_ln(p_invoice_num VARCHAR2) IS
      SELECT xails.ROWID, xails.*
        FROM xx_ap_invoices_line_stg xails
       WHERE xails.status = 'NEW'
         AND xails.invoice_num = p_invoice_num
         AND xails.request_id = p_request_id;
    -- Cursor Declaration - End

  BEGIN
    FND_FILE.PUT_LINE(FND_FILE.LOG,
                      CHR(13) || 'Procedure VALIDATE_INVOICE_LN - Start');
    l_invoice_num := p_invoice_num;

    FOR inv_ln_rec IN c_inv_ln(l_invoice_num)

     LOOP

      -- Re-initialization of variables - Start
      l_error_msg              := NULL;
      l_master_org_id_cnt      := NULL;
      l_inv_line_type_cnt      := NULL;
      l_dist_code_cnt          := NULL;
      l_vendor_num_cnt         := NULL;
      l_po_num_cnt             := NULL;
      l_line_error             := NULL;
      l_line_flag              := 'V';
      l_err_flag               := 'V';
      -- Re-initialization of variables - End

      -- Validation Start

      -- 1. Invoice line number validation.
      IF (inv_ln_rec.invoice_num IS NULL) THEN
        l_err_flag  := 'E';
        l_error_msg := 'Invoice Line Number is mandatory.';
      END IF;

      -- 2. Invoice line type validation.
      IF (inv_ln_rec.line_type_lookup_code IS NULL) THEN
        l_err_flag  := 'E';
        l_error_msg := l_error_msg || '/' ||
                       'Invoice Line type is mandatory';
      ELSIF (inv_ln_rec.line_type_lookup_code IS NOT NULL) THEN
        BEGIN
          SELECT COUNT(1)
            INTO l_inv_line_type_cnt
            FROM fnd_lookup_values_vl flvv
           WHERE flvv.lookup_type = 'INVOICE LINE TYPE'
             AND flvv.enabled_flag = 'Y'
             AND SYSDATE BETWEEN NVL(flvv.start_date_active, SYSDATE - 1) AND
                 NVL(flvv.end_date_active, SYSDATE + 1)
             AND flvv.lookup_code = inv_ln_rec.line_type_lookup_code;
        EXCEPTION
          WHEN OTHERS THEN
            g_step_id   := 'V01';
            g_sqlerrm   := SQLERRM;
            g_error_msg := 'Unexpected error has occured while checking the' ||
                           'Invoice line type.';
            RAISE e_abort;
        END;
        IF l_inv_line_type_cnt = 0 THEN
          l_err_flag    := 'E';
          l_error_msg := l_error_msg || '/' || 'Invoice Line Type--' ||
                         inv_ln_rec.line_type_lookup_code ||
                         ' is not defined in the system';
        END IF;
      END IF;

      -- 3. Invoice line amount validation.
      IF (inv_ln_rec.amount IS NULL) THEN
        l_err_flag  := 'E';
        l_error_msg := l_error_msg || '/' ||
                       'Invoice Line amount is mandatory';
      END IF;

      -- 4. Item master organization validation.
      IF (inv_ln_rec.org_id IS NOT NULL) THEN
        BEGIN
          SELECT COUNT(1)
            INTO l_master_org_id_cnt
            FROM mtl_parameters mp, hr_organization_information hoi
           WHERE hoi.organization_id = mp.organization_id
             AND hoi.org_information_context = 'Accounting Information'
             AND hoi.org_information3 = inv_ln_rec.org_id
             AND ROWNUM = 1;
        EXCEPTION
          WHEN OTHERS THEN
            g_step_id   := 'V02';
            g_sqlerrm   := SQLERRM;
            g_error_msg := 'Unexpected error has occured while checking the' ||
                           'master org.';
            RAISE e_abort;
        END;
        IF l_master_org_id_cnt = 0 THEN
          l_err_flag    := 'E';
          l_error_msg := l_error_msg || '/' || 'Master Organization--' ||
                         inv_ln_rec.org_id ||
                         ' is not defined in the system';
        END IF;
      END IF;

      -- 5. Distribution account code validation
      IF (inv_ln_rec.dist_code_concatenated IS NOT NULL) THEN
        BEGIN
          SELECT COUNT(1)
            INTO l_dist_code_cnt
            FROM gl_code_combinations_kfv gcck
           WHERE gcck.concatenated_segments =
                 inv_ln_rec.dist_code_concatenated;
        EXCEPTION
          WHEN OTHERS THEN
            g_step_id   := 'V03';
            g_sqlerrm   := SQLERRM;
            g_error_msg := 'Unexpected error has occured while checking the' ||
                           'distribution account at invoice line.';
            RAISE e_abort;
        END;
        IF l_dist_code_cnt = 0 THEN
          l_err_flag    := 'E';
          l_error_msg := l_error_msg || '/' || 'Distribution Account' ||
                         inv_ln_rec.dist_code_concatenated ||
                         ' is not defined in the system';
        END IF;
      END IF;

      -- 7. Invoice Number validations
      IF (inv_ln_rec.invoice_num IS NULL) THEN
        l_err_flag  := 'E';
        l_error_msg := l_error_msg || '/' || ' Invoice number mandatory.';
      END IF;

      -- 8. Supplier Number validations
      IF (inv_ln_rec.supplier_number IS NOT NULL) THEN
        BEGIN
          SELECT COUNT(1)
            INTO l_vendor_num_cnt
            FROM po_vendors pv
           WHERE pv.segment1 = inv_ln_rec.supplier_number;
        EXCEPTION
          WHEN OTHERS THEN
            g_step_id   := 'V04';
            g_sqlerrm   := SQLERRM;
            g_error_msg := 'Unexpected error has occured while checking the' ||
                           'supplier number.';
            RAISE e_abort;
        END;
        IF l_vendor_num_cnt = 0 THEN
          l_err_flag    := 'E';
          l_error_msg := l_error_msg || '/' || 'Supplier Number' ||
                         inv_ln_rec.supplier_number ||
                         ' is not defined in the system';
        END IF;
      END IF;

      -- 9. PO Number validations
      IF (inv_ln_rec.po_number IS NOT NULL) THEN
        BEGIN
          SELECT COUNT(1)
            INTO l_po_num_cnt
            FROM po_headers_all pha
           WHERE pha.org_id = inv_ln_rec.org_id
             AND pha.approved_flag = 'Y'
             AND pha.segment1 = inv_ln_rec.po_number;
        EXCEPTION
          WHEN OTHERS THEN
            g_step_id   := 'V05';
            g_sqlerrm   := SQLERRM;
            g_error_msg := 'Unexpected error has occured while checking the' ||
                           'PO number.';
            RAISE e_abort;
        END;
         IF l_po_num_cnt = 0 THEN
          l_err_flag    := 'E';
          l_error_msg := l_error_msg || '/' || 'PO Number' ||
                         inv_ln_rec.po_number ||
                         ' is not defined in the system';
        END IF;
      END IF;

      -- 10. GL Date validations
      IF (inv_ln_rec.accounting_date IS NULL) THEN
        l_err_flag  := 'E';
        l_error_msg := l_error_msg || '/' ||
                       ' Accounting date is mandatory.';
      END IF;

      -- Validation - End.

      IF l_err_flag = 'E' THEN
        l_line_flag  := 'E';
        l_line_error := l_line_error || '/' || l_error_msg;
        BEGIN
          UPDATE xx_ap_invoices_line_stg xails
             SET xails.status            = l_err_flag,
                 xails.error_message     = l_error_msg,
                 xails.LAST_UPDATED_BY   = g_last_updated_by,
                 xails.LAST_UPDATE_DATE  = g_last_update_date,
                 xails.LAST_UPDATE_LOGIN = g_last_update_login
           WHERE xails.ROWID = inv_ln_rec.ROWID;
        EXCEPTION
          WHEN OTHERS THEN
            g_sqlerrm   := SQLERRM;
            g_error_msg := 'Unexceptional error while updating line valid status';
            g_step_id   := 'V06';
            RAISE e_abort;
        END;
      ELSIF l_err_flag <> 'E' THEN
        BEGIN
          UPDATE xx_ap_invoices_line_stg xails
             SET xails.status            = l_err_flag,
                 xails.LAST_UPDATED_BY   = g_last_updated_by,
                 xails.LAST_UPDATE_DATE  = g_last_update_date,
                 xails.LAST_UPDATE_LOGIN = g_last_update_login
           WHERE xails.ROWID = inv_ln_rec.ROWID;
        EXCEPTION
          WHEN OTHERS THEN
            g_sqlerrm   := SQLERRM;
            g_error_msg := 'Unexceptional error while line valid status';
            g_step_id   := 'V07';
            RAISE e_abort;
        END;
      END IF;

    END LOOP;
    x_err_message := l_line_error;
    x_err_flag    := l_line_flag;

    FND_FILE.PUT_LINE(FND_FILE.LOG,
                      CHR(13) || 'Procedure VALIDATE_INVOICE_LN - End');

  EXCEPTION
    WHEN e_abort THEN
      RAISE e_abort;
    WHEN OTHERS THEN
      g_step_id   := 'V08';
      g_sqlerrm   := SQLERRM;
      g_error_msg := 'Unexpected error has occured in the procedure ' ||
                     'VALIDATE_INVOICE';
      RAISE e_abort;

  END invoice_ln_validate;
  -- ===========================================================================
  --                     End of Procedure VALIDATE_INVOICE_LN
  -- ===========================================================================

  -- ===========================================================================
  --                     Start of Procedure VALIDATE_INVOICE
  -- ===========================================================================
  PROCEDURE invoice_hdr_validate(p_request_id IN NUMBER)

    -- ===========================================================================
    --  Program name                    Creation Date               Created by
    --  invoice_hdr_validate              02-AUG-2016                 TCS
    -- ---------------------------------------------------------------------------
    -- Description  : This procedure is used to validate the AP Invoice HDR record.
    --
    -- Return value : None
    --
    -- ===========================================================================
   IS
    -- Local Variable Declaration - Start

    l_org_id_cnt             NUMBER;
    l_inv_type_cnt           NUMBER;
    l_vendor_name_cnt        NUMBER;
    l_vendor_site_cnt        NUMBER;
    l_source_cnt             NUMBER;
    l_po_num_cnt             NUMBER;
    l_flag                   VARCHAR2(2);
    l_term_id                NUMBER;
    l_err_msg_line           VARCHAR2(4000);
    l_err_flag_line          VARCHAR2(2);
    l_status                 VARCHAR2(1);
    l_error_msg              VARCHAR2(4000);

    -- Local Variable Declaration - End

    -- Cursor Declaration - Start
    -- This cursor will fetch all the new records from the Invoice HDR staging
    -- table
    CURSOR c_inv_hdr IS
      SELECT xaihs.ROWID, xaihs.*
        FROM xx_ap_invoices_hdr_stg xaihs
       WHERE xaihs.status = 'NEW'
         AND xaihs.request_id = p_request_id;
    -- Cursor Declaration - End

  BEGIN
    FND_FILE.PUT_LINE(FND_FILE.LOG,
                      CHR(13) || 'Procedure invoice_hdr_validate - Start');

    --Opening the cursor
    FOR inv_hdr_rec IN c_inv_hdr LOOP

      -- Re-initialization of variables - Start

      l_org_id_cnt      := NULL;
      l_inv_type_cnt    := NULL;
      l_vendor_name_cnt := NULL;
      l_vendor_site_cnt := NULL;
      l_source_cnt      := NULL;
      l_po_num_cnt      := NULL;
      l_term_id         := NULL;
      l_err_msg_line    := NULL;
      l_err_flag_line   := NULL;
      l_error_msg       := NULL;
      l_status          := 'V';
      l_flag            := 'V';

      -- Re-initialization of variables - End

      -- Validation - Start.

      -- 1. Checking for mandatory fields validations
      -- 1A) Invoice Number.
      IF (inv_hdr_rec.invoice_num IS NULL) THEN
        l_status    := 'E';
        l_error_msg := 'Invoice Number is Mandatory';
      END IF;
      -- 1B) Invoice Amount.
      IF (inv_hdr_rec.invoice_amount IS NULL) THEN
        l_status    := 'E';
        l_error_msg := l_error_msg || '/' || 'Invoice Amount is Mandatory';
      END IF;
      -- 1C) Source.
      IF (inv_hdr_rec.source IS NULL) THEN
        l_status    := 'E';
        l_error_msg := l_error_msg || '/' || 'Source is Mandatory';
      END IF;
      -- 1D) Operating Unit.
      IF (inv_hdr_rec.operating_unit IS NULL) THEN
        l_status    := 'E';
        l_error_msg := l_error_msg || '/' || 'Operating Unit is Mandatory';
      END IF;
      -- 1D) Invoice Date.
      IF (inv_hdr_rec.invoice_date IS NULL) THEN
        l_status    := 'E';
        l_error_msg := l_error_msg || '/' || 'Invoice Date is Mandatory';
      END IF;
      -- 1E) Invoice Type.
      IF (inv_hdr_rec.invoice_type_lookup_code IS NULL) THEN
        l_status    := 'E';
        l_error_msg := l_error_msg || '/' || 'Invoice Type is Mandatory';
      END IF;
      -- 1F) Supplier Number.
      IF (inv_hdr_rec.vendor_num IS NULL) THEN
        l_status    := 'E';
        l_error_msg := l_error_msg || '/' || 'Supplier Number is Mandatory';
      END IF;
      -- 1G) Supplier Name.
      IF (inv_hdr_rec.vendor_name IS NULL) THEN
        l_status    := 'E';
        l_error_msg := l_error_msg || '/' || 'Supplier Name is Mandatory';
      END IF;
      -- 1H) Supplier Site.
      IF (inv_hdr_rec.vendor_site_code IS NULL) THEN
        l_status    := 'E';
        l_error_msg := l_error_msg || '/' || 'Supplier Site is Mandatory';
      END IF;
      -- 1I) Invoice Currency.
      IF (inv_hdr_rec.invoice_currency_code IS NULL) THEN
        l_status    := 'E';
        l_error_msg := l_error_msg || '/' ||
                       'Invoice Currency is Mandatory';
      END IF;
      -- 1J) GL Date.
      IF (inv_hdr_rec.gl_date IS NULL) THEN
        l_status    := 'E';
        l_error_msg := l_error_msg || '/' || 'GL Date is Mandatory';
      END IF;

      -- 2. Operating Unit validation.
      IF (inv_hdr_rec.operating_unit IS NOT NULL) THEN
        BEGIN
          SELECT COUNT(1)
            INTO l_org_id_cnt
            FROM hr_operating_units hou
           WHERE hou.name = inv_hdr_rec.operating_unit;
        EXCEPTION
          WHEN OTHERS THEN
            g_step_id   := 'V09';
            g_sqlerrm   := SQLERRM;
            g_error_msg := 'Unexpected error has occured while checking the' ||
                           'Operating unit';
            RAISE e_abort;
        END;
        IF l_org_id_cnt = 0 THEN
          l_status    := 'E';
          l_error_msg := l_error_msg || '/' || 'Operating Unit-' ||
                         inv_hdr_rec.operating_unit ||
                         ' is not defined in the system';
        END IF;
      END IF;

      -- 3. Invoice Type validation.
      IF (inv_hdr_rec.invoice_type_lookup_code IS NOT NULL) THEN
        BEGIN
          SELECT COUNT(1)
            INTO l_inv_type_cnt
            FROM fnd_lookup_values_vl flvv
           WHERE flvv.lookup_type = 'INVOICE TYPE'
             AND flvv.enabled_flag = 'Y'
             AND SYSDATE BETWEEN NVL(flvv.start_date_active, SYSDATE - 1) AND
                 NVL(flvv.end_date_active, SYSDATE + 1)
             AND flvv.lookup_code = inv_hdr_rec.invoice_type_lookup_code;
        EXCEPTION
          WHEN OTHERS THEN
            g_step_id   := 'V10';
            g_sqlerrm   := SQLERRM;
            g_error_msg := 'Unexpected error has occured while checking the' ||
                           'Invoice Type';
            RAISE e_abort;
        END;
        IF l_inv_type_cnt = 0 THEN
          l_status    := 'E';
          l_error_msg := l_error_msg || '/' || 'Invoice type-' ||
                         inv_hdr_rec.invoice_type_lookup_code ||
                         ' is not defined in the system';
        END IF;
      END IF;

      -- 4. Supplier Name validation.
      IF (inv_hdr_rec.vendor_name IS NOT NULL) THEN
        BEGIN
          SELECT COUNT(1)
            INTO l_vendor_name_cnt
            FROM po_vendors pv
           WHERE pv.vendor_name = inv_hdr_rec.vendor_name;
        EXCEPTION
          WHEN OTHERS THEN
            g_step_id   := 'V11';
            g_sqlerrm   := SQLERRM;
            g_error_msg := 'Unexpected error has occured while checking the' ||
                           'Supplier Name';
            RAISE e_abort;
        END;
        IF l_vendor_name_cnt = 0 THEN
          l_status    := 'E';
          l_error_msg := l_error_msg || '/' || 'Vendor Name-' ||
                         inv_hdr_rec.vendor_name ||
                         ' is not defined in the system';
        END IF;
      END IF;

      -- 5. Supplier Site validation.
      IF (inv_hdr_rec.vendor_site_code IS NOT NULL) THEN
        BEGIN
          SELECT COUNT(1)
            INTO l_vendor_site_cnt
            FROM po_vendor_sites_all pvsa
           WHERE pvsa.org_id = inv_hdr_rec.org_id
             AND pvsa.vendor_id = inv_hdr_rec.vendor_id
             AND pvsa.vendor_site_code = inv_hdr_rec.vendor_site_code;
        EXCEPTION
          WHEN OTHERS THEN
            g_step_id   := 'V12';
            g_sqlerrm   := SQLERRM;
            g_error_msg := 'Unexpected error has occured while checking the' ||
                           'Supplier Site';
            RAISE e_abort;
        END;
        IF l_vendor_site_cnt = 0 THEN
          l_status    := 'E';
          l_error_msg := l_error_msg || '/' || 'Vendor Site Code-' ||
                         inv_hdr_rec.vendor_site_code ||
                         ' is not defined in the system';
        END IF;
      END IF;

      -- 6. Source Validation.
      IF (inv_hdr_rec.source IS NOT NULL) THEN
        BEGIN
          SELECT COUNT(1)
            INTO l_source_cnt
            FROM fnd_lookup_values_vl flvv
           WHERE flvv.lookup_type = 'SOURCE'
             AND flvv.enabled_flag = 'Y'
             AND SYSDATE BETWEEN NVL(flvv.start_date_active, SYSDATE - 1) AND
                 NVL(flvv.end_date_active, SYSDATE + 1)
             AND flvv.lookup_code = inv_hdr_rec.source;
        EXCEPTION
          WHEN OTHERS THEN
            g_step_id   := 'V13';
            g_sqlerrm   := SQLERRM;
            g_error_msg := 'Unexpected error has occured while checking the' ||
                           'Source';
            RAISE e_abort;
        END;
        IF l_source_cnt = 0 THEN
          l_status    := 'E';
          l_error_msg := l_error_msg || '/' || 'Source-' ||
                         inv_hdr_rec.source ||
                         ' is not defined in the system';
        END IF;
      END IF;

      -- 7.PO validation
      IF (inv_hdr_rec.po_number IS NOT NULL) THEN
        BEGIN
          SELECT COUNT(1)
            INTO l_po_num_cnt
            FROM po_headers_all pha
           WHERE pha.org_id = inv_hdr_rec.org_id
             AND pha.approved_flag = 'Y'
             AND pha.segment1 = inv_hdr_rec.po_number;
        EXCEPTION
          WHEN OTHERS THEN
            g_step_id   := 'V14';
            g_sqlerrm   := SQLERRM;
            g_error_msg := 'Unexpected error has occured while checking the' ||
                           'PO Number';
            RAISE e_abort;
        END;
        IF l_po_num_cnt = 0 THEN
          l_status    := 'E';
          l_error_msg := l_error_msg || '/' || 'PO Number-' ||
                         inv_hdr_rec.po_number ||
                         ' is not defined in the system';
        END IF;
      END IF;

      -- Header Validation - End.

      -- Call the Line Validation procedure for the Invoice.
      IF l_status <> 'E' THEN
        invoice_ln_validate(p_invoice_num => inv_hdr_rec.invoice_num,
                            p_request_id  => p_request_id,
                            x_err_message => l_err_msg_line,
                            x_err_flag    => l_err_flag_line);

        IF l_err_flag_line = 'E' THEN
          l_flag      := 'E';
          g_error_msg := g_error_msg ||
                         'Invoice Line has validation errors';
        ELSE
          l_flag := 'V';
        END IF;
        --Line validation update status in header satging table
        IF l_flag = 'E' THEN
          BEGIN
            UPDATE xx_ap_invoices_hdr_stg xaihs
               SET xaihs.status            = l_flag,
                   xaihs.error_message     = g_error_msg,
                   xaihs.LAST_UPDATED_BY   = g_last_updated_by,
                   xaihs.LAST_UPDATE_DATE  = g_last_update_date,
                   xaihs.LAST_UPDATE_LOGIN = g_last_update_login
             WHERE xaihs.ROWID = inv_hdr_rec.ROWID;
          EXCEPTION
            WHEN OTHERS THEN
              g_sqlerrm   := SQLERRM;
              g_error_msg := 'Unexceptional error while updating the status';
              g_step_id   := 'V15';
              RAISE e_abort;
          END;
        ELSE
          BEGIN
            UPDATE xx_ap_invoices_hdr_stg xaihs
               SET xaihs.status            = l_flag,
                   xaihs.LAST_UPDATED_BY   = g_last_updated_by,
                   xaihs.LAST_UPDATE_DATE  = g_last_update_date,
                   xaihs.LAST_UPDATE_LOGIN = g_last_update_login
             WHERE xaihs.ROWID = inv_hdr_rec.ROWID;
          EXCEPTION
            WHEN OTHERS THEN
              g_sqlerrm   := SQLERRM;
              g_error_msg := 'Unexceptional error while updating valid status';
              g_step_id   := 'V16';
              RAISE e_abort;
          END;
        END IF;
      ELSIF l_status = 'E' THEN
        BEGIN
          UPDATE xx_ap_invoices_hdr_stg xaihs
             SET xaihs.status            = l_status,
                 xaihs.error_message     = l_error_msg,
                 xaihs.LAST_UPDATED_BY   = g_last_updated_by,
                 xaihs.LAST_UPDATE_DATE  = g_last_update_date,
                 xaihs.LAST_UPDATE_LOGIN = g_last_update_login
           WHERE xaihs.ROWID = inv_hdr_rec.ROWID;
        EXCEPTION
          WHEN OTHERS THEN
            g_sqlerrm   := SQLERRM;
            g_error_msg := 'Unexceptional error while updating valid status';
            g_step_id   := 'V17';
            RAISE e_abort;
        END;
      END IF;

      --Re-initializing the global variables.
      g_error_msg := NULL;

    END LOOP;
    FND_FILE.PUT_LINE(FND_FILE.LOG,
                      CHR(13) || 'Procedure VALIDATE_INVOICE - End');
  EXCEPTION
    WHEN e_abort THEN
      RAISE e_abort;
    WHEN OTHERS THEN
      g_step_id   := 'V18';
      g_sqlerrm   := SQLERRM;
      g_error_msg := 'Unexpected error has occured in the procedure ' ||
                     'VALIDATE_INVOICE';
      RAISE e_abort;

  END invoice_hdr_validate;

  -- ===========================================================================
  --                      Start Of Procedure update_inv_stg
  -- ===========================================================================
  PROCEDURE update_inv_stg(p_request_id IN NUMBER)
  -- ===========================================================================
    --  Program name                 Creation Date               Created by
    --  update_inv_stg          01-Mar-2016                 TCS
    -- ---------------------------------------------------------------------------
    -- Description  : This procedure is used to update the supplier header
    --                staging table after insertion in the header interface
    --
    -- Return value : None
    --
    -- ===========================================================================
   IS
    -- Cursor to fetch the interface error records - Start
    CURSOR c_inv_hdr_err_det IS
     SELECT xaihs.ROWID row_id,
            REPLACE(air.reject_lookup_code, CHR(10), ' ') error_message
       FROM xx_ap_invoices_hdr_stg  xaihs,
            ap_invoices_interface   aii,
            ap_interface_rejections air
      WHERE xaihs.status = 'S'
        AND aii.invoice_num = xaihs.invoice_num
        AND aii.invoice_id = air.parent_id
        AND air.parent_table = 'AP_INVOICES_INTERFACE'
        AND aii.status <> 'PROCESSED'
        AND xaihs.request_id = p_request_id;
    -- Cursor to fetch the interface error records - End

    -- Cursor to fetch the Line interface error records - Start
    CURSOR c_inv_ln_err_det IS
      SELECT xails.ROWID row_id,
             REPLACE(air.reject_lookup_code, CHR(10), ' ') error_message
        FROM xx_ap_invoices_line_stg    xails,
             ap_invoices_interface      aii,
             ap_invoice_lines_interface aili,
             ap_interface_rejections    air
       WHERE xails.status = 'S'
         AND aii.invoice_num = xails.invoice_num
         AND aili.invoice_id = aii.invoice_id
         AND aili.invoice_line_id = air.parent_id
         AND air.parent_table = 'AP_INVOICE_LINES_INTERFACE'
         AND aii.status <> 'PROCESSED'
         AND xails.request_id = p_request_id;
    -- Cursor to fetch the Line interface error records - End

  BEGIN
    FND_FILE.PUT_LINE(FND_FILE.LOG,
                      CHR(13) || 'Procedure update_inv_stg - Start');

    FOR rec_inv_hdr_err_det IN c_inv_hdr_err_det LOOP
      BEGIN
        UPDATE xx_ap_invoices_hdr_stg xaihs
           SET xaihs.status            = 'I',
               xaihs.error_message     = rec_inv_hdr_err_det.error_message,
               xaihs.last_updated_by   = g_last_updated_by,
               xaihs.last_update_date  = SYSDATE,
               xaihs.last_update_login = g_last_update_login
         WHERE xaihs.ROWID = rec_inv_hdr_err_det.row_id
           AND xaihs.request_id = p_request_id;
      EXCEPTION
        WHEN OTHERS THEN
          g_step_id   := 'USH01';
          g_sqlerrm   := SQLERRM;
          g_error_msg := 'Unexpected error occured while updating the ' ||
                         'Header staging table with the interface error details. ';
          RAISE e_abort;
      END;
    END LOOP;

    ------------updating error in line staging table------------

    FND_FILE.PUT_LINE(FND_FILE.LOG,
                      CHR(13) || 'Line stage error update - Start');

    FOR rec_inv_ln_err_det IN c_inv_ln_err_det LOOP
      BEGIN
        UPDATE xx_ap_invoices_line_stg xails
           SET xails.status            = 'I',
               xails.error_message     = rec_inv_ln_err_det.error_message,
               xails.last_updated_by   = g_last_updated_by,
               xails.last_update_date  = SYSDATE,
               xails.last_update_login = g_last_update_login
         WHERE xails.ROWID = rec_inv_ln_err_det.row_id
           AND xails.request_id = p_request_id;
      EXCEPTION
        WHEN OTHERS THEN
          g_step_id   := 'USH01';
          g_sqlerrm   := SQLERRM;
          g_error_msg := 'Unexpected error occured while updating the ' ||
                         'Line staging table with the interface error details. ';
          RAISE e_abort;
      END;
    END LOOP;

    FND_FILE.PUT_LINE(FND_FILE.LOG,
                      CHR(13) || 'Procedure update_inv_stg - End');

  EXCEPTION
    WHEN e_abort THEN
      RAISE e_abort;
    WHEN OTHERS THEN
      g_step_id   := 'USH80';
      g_sqlerrm   := SQLERRM;
      g_error_msg := 'Unexpected error has occured in the procedure ' ||
                     'update_inv_stg.Please contact SysAdmin';
      RAISE e_abort;
  END update_inv_stg;

  --   ===========================================================================
  --                      End Of Procedure update_inv_stg
  -- ===========================================================================

  -- ===========================================================================
  --                      Start Of Procedure invoice_loading_summary
  -- ===========================================================================
  PROCEDURE invoice_loading_summary(p_request_id IN NUMBER)
  -- ===========================================================================
    --  Program name                 Creation Date               Created by
    --  invoice_loading_summary         23-AUG-2016                 TCS
    -- ---------------------------------------------------------------------------
    -- Description  : This procedure is used for reconciliation
    --
    -- Return value : None
    --
    -- ===========================================================================
   IS

    -- Cursor Declaration - Start
    -- Invoice Header records failed during custom validation and interface execution
    CURSOR c_err_inv_hdr_details IS
      SELECT xaihs.invoice_id,
             xaihs.invoice_num,
             xaihs.status,
             xaihs.error_message,
             xaihs.rowid
        FROM xx_ap_invoices_hdr_stg xaihs
       WHERE xaihs.status IN ('E', 'I')
         AND xaihs.request_id = p_request_id
       ORDER BY xaihs.status;
    -- Cursor Declaration - End

    -- Cursor Declaration - Start
    -- Invoice line records failed during custom validation and interface execution
    CURSOR cur_err_inv_line_details IS
      SELECT xails.invoice_id,
             xails.invoice_line_id,
             xails.invoice_num,
             xails.status,
             xails.error_message,
             xails.rowid
        FROM xx_ap_invoices_line_stg xails
       WHERE xails.status IN ('E', 'I')
         AND xails.request_id = p_request_id
       ORDER BY xails.status;
    -- Cursor Declaration - End

    -- Local Variable Declaration - Start
    l_hdr_total_cnt   NUMBER := NULL;
    l_hdr_success_cnt NUMBER := NULL;
    l_hdr_val_err_cnt NUMBER := NULL;
    l_hdr_int_err_cnt NUMBER := NULL;

    l_line_total_cnt   NUMBER := NULL;
    l_line_success_cnt NUMBER := NULL;
    l_line_val_err_cnt NUMBER := NULL;
    l_line_int_err_cnt NUMBER := NULL;
    -- Local Variable Declaration - End

  BEGIN
    FND_FILE.PUT_LINE(FND_FILE.LOG,
                      CHR(13) ||
                      'Procedure invoice_loading_summary - Start');

    -- Header Total Count - Start
    BEGIN
      SELECT COUNT(1)
        INTO l_hdr_total_cnt
        FROM xx_ap_invoices_hdr_stg xaihs
       WHERE xaihs.request_id = p_request_id;
    EXCEPTION
      WHEN OTHERS THEN
        g_step_id   := 'S01';
        g_sqlerrm   := SQLERRM;
        g_error_msg := 'Unexpected error has occured while taking the total header count';
        RAISE e_abort;
    END;
    -- Header Total Count - End

    -- Header Success Count - Start
    BEGIN
      SELECT COUNT(1)
        INTO l_hdr_success_cnt
        FROM xx_ap_invoices_hdr_stg xaihs
       WHERE xaihs.status = 'S'
         AND xaihs.request_id = p_request_id;
    EXCEPTION
      WHEN OTHERS THEN
        g_step_id   := 'S02';
        g_sqlerrm   := SQLERRM;
        g_error_msg := 'Unexpected error has occured while taking the header success count';
        RAISE e_abort;
    END;
    -- Header Success Count - Start

    -- Header Validation Fail Count - Start
    BEGIN
      SELECT COUNT(1)
        INTO l_hdr_val_err_cnt
        FROM xx_ap_invoices_hdr_stg xaihs
       WHERE xaihs.status = 'E'
         AND xaihs.request_id = p_request_id;
    EXCEPTION
      WHEN OTHERS THEN
        g_step_id   := 'S03';
        g_sqlerrm   := SQLERRM;
        g_error_msg := 'Unexpected error has occured while taking the header' ||
                       'custom validation fail count';
        RAISE e_abort;
    END;
    -- Header Validation Fail Count - Start

    -- Header Interface Fail Count - Start
    BEGIN
      SELECT COUNT(1)
        INTO l_hdr_int_err_cnt
        FROM xx_ap_invoices_hdr_stg xaihs
       WHERE xaihs.status = 'I'
         AND xaihs.request_id = p_request_id;
    EXCEPTION
      WHEN OTHERS THEN
        g_step_id   := 'S04';
        g_sqlerrm   := SQLERRM;
        g_error_msg := 'Unexpected error has occured while taking the ' ||
                       'header interface fail count';
        RAISE e_abort;
    END;
    -- Header Interface Fail Count - End

    ----------------------------------------------------------------------
    -- Line Total Count - Start
    BEGIN
      SELECT COUNT(1)
        INTO l_line_total_cnt
        FROM xx_ap_invoices_line_stg xails
       WHERE xails.request_id = p_request_id;
    EXCEPTION
      WHEN OTHERS THEN
        g_step_id   := 'S01';
        g_sqlerrm   := SQLERRM;
        g_error_msg := 'Unexpected error has occured while taking the total header count';
        RAISE e_abort;
    END;
    -- Line Total Count - End

    -- Line Success Count - Start
    BEGIN
      SELECT COUNT(1)
        INTO l_line_success_cnt
        FROM xx_ap_invoices_line_stg xails
       WHERE xails.status = 'S'
         AND xails.request_id = p_request_id;
    EXCEPTION
      WHEN OTHERS THEN
        g_step_id   := 'S02';
        g_sqlerrm   := SQLERRM;
        g_error_msg := 'Unexpected error has occured while taking the header success count';
        RAISE e_abort;
    END;
    -- Line Success Count - Start

    -- Line Validation Fail Count - Start
    BEGIN
      SELECT COUNT(1)
        INTO l_line_val_err_cnt
        FROM xx_ap_invoices_line_stg xails
       WHERE xails.status = 'E'
         AND xails.request_id = p_request_id;
    EXCEPTION
      WHEN OTHERS THEN
        g_step_id   := 'S03';
        g_sqlerrm   := SQLERRM;
        g_error_msg := 'Unexpected error has occured while taking the header' ||
                       'custom validation fail count';
        RAISE e_abort;
    END;
    -- Line Validation Fail Count - Start

    -- Line Interface Fail Count - Start
    BEGIN
      SELECT COUNT(1)
        INTO l_line_int_err_cnt
        FROM xx_ap_invoices_line_stg xails
       WHERE xails.status = 'I'
         AND xails.request_id = p_request_id;
    EXCEPTION
      WHEN OTHERS THEN
        g_step_id   := 'S04';
        g_sqlerrm   := SQLERRM;
        g_error_msg := 'Unexpected error has occured while taking the ' ||
                       'header interface fail count';
        RAISE e_abort;
    END;
    -- Line Interface Fail Count - End

    -- Status in the Concurrent Log for Invoice Header - Start
    FND_FILE.PUT_LINE(FND_FILE.LOG,
                      '**********Invoice Header Summary**********');
    FND_FILE.PUT_LINE(FND_FILE.LOG,
                      'Total no. of Invoice Header records: ' ||
                      l_hdr_total_cnt);
    FND_FILE.PUT_LINE(FND_FILE.LOG,
                      'Total no. of Invoice Header ' ||
                      'records successfully loaded:' || l_hdr_success_cnt);
    FND_FILE.PUT_LINE(FND_FILE.LOG,
                      'Total no. of Invoice Header records ' ||
                      'failed in custom validation: ' || l_hdr_val_err_cnt);
    FND_FILE.PUT_LINE(FND_FILE.LOG,
                      'Total no. of Invoice Header records ' ||
                      'failed during Interface execution: ' ||
                      l_hdr_int_err_cnt);

    FND_FILE.PUT_LINE(FND_FILE.LOG,
                      '****** Invoice Header Error Records ******');
    FND_FILE.PUT_LINE(FND_FILE.LOG,
                      '------------------------------------' ||
                      '------------------------------------------------' ||
                      '------------------------------------------------' ||
                      '-----------------------------------------------' ||
                      '------------------------------------------------' ||
                      '------------------------------------------------' ||
                      '------------------------------');
    FND_FILE.PUT_LINE(FND_FILE.LOG,
                      RPAD('Invoice Id', 20) || RPAD('Invoice Num', 20) ||
                      RPAD('Error Status', 20) ||
                      RPAD('Error Message', 2000));

    FOR err_inv_hdr_details_rec IN c_err_inv_hdr_details LOOP
      FND_FILE.PUT_LINE(FND_FILE.LOG,
                        RPAD(err_inv_hdr_details_rec.invoice_id, 20) ||
                        RPAD(err_inv_hdr_details_rec.invoice_num, 20) ||
                        RPAD(err_inv_hdr_details_rec.status, 20) ||
                        RPAD(err_inv_hdr_details_rec.error_message, 2000));

    END LOOP;

    FND_FILE.PUT_LINE(FND_FILE.LOG,
                      '------------------------------------' ||
                      '------------------------------------------------' ||
                      '------------------------------------------------' ||
                      '-----------------------------------------------' ||
                      '------------------------------------------------' ||
                      '------------------------------------------------' ||
                      '------------------------------');
    FND_FILE.PUT_LINE(FND_FILE.LOG,
                      '********End of Invoice Header Summary********');
    -- Status in the Concurrent Log for Invoice Header - End

    -- Status in the Concurrent Log for Invoice Line - Start
    FND_FILE.PUT_LINE(FND_FILE.LOG,
                      '**********Invoice Line Summary**********');
    FND_FILE.PUT_LINE(FND_FILE.LOG,
                      'Total no. of Invoice Line records: ' ||
                      l_line_total_cnt);
    FND_FILE.PUT_LINE(FND_FILE.LOG,
                      'Total no. of Invoice Line ' ||
                      'records successfully loaded:' || l_line_success_cnt);
    FND_FILE.PUT_LINE(FND_FILE.LOG,
                      'Total no. of Invoice Line records ' ||
                      'failed in custom validation: ' || l_line_val_err_cnt);
    FND_FILE.PUT_LINE(FND_FILE.LOG,
                      'Total no. of Invoice Line records ' ||
                      'failed during Interface execution: ' ||
                      l_line_int_err_cnt);

    FND_FILE.PUT_LINE(FND_FILE.LOG,
                      '****** Invoice Line Error Records ******');
    FND_FILE.PUT_LINE(FND_FILE.LOG,
                      '------------------------------------' ||
                      '------------------------------------------------' ||
                      '------------------------------------------------' ||
                      '-----------------------------------------------' ||
                      '------------------------------------------------' ||
                      '------------------------------------------------' ||
                      '------------------------------');
    FND_FILE.PUT_LINE(FND_FILE.LOG,
                      RPAD('Invoice Id', 20) || RPAD('Invoice Line Id', 20) ||
                      RPAD('Invoice Num', 20) || RPAD('Error Status', 20) ||
                      RPAD('Error Message', 2000));

    FOR err_inv_line_details_rec IN cur_err_inv_line_details LOOP
      FND_FILE.PUT_LINE(FND_FILE.LOG,
                        RPAD(err_inv_line_details_rec.invoice_id, 20) ||
                        RPAD(err_inv_line_details_rec.invoice_line_id, 20) ||
                        RPAD(err_inv_line_details_rec.invoice_num, 20) ||
                        RPAD(err_inv_line_details_rec.status, 20) ||
                        RPAD(err_inv_line_details_rec.error_message, 2000));

    END LOOP;

    FND_FILE.PUT_LINE(FND_FILE.LOG,
                      '------------------------------------' ||
                      '------------------------------------------------' ||
                      '------------------------------------------------' ||
                      '-----------------------------------------------' ||
                      '------------------------------------------------' ||
                      '------------------------------------------------' ||
                      '------------------------------');
    FND_FILE.PUT_LINE(FND_FILE.LOG,
                      '********End of Invoice Line Summary********');
    -- Status in the Concurrent Log for Invoice Line - End

    FND_FILE.PUT_LINE(FND_FILE.LOG,
                      CHR(13) || 'Procedure invoice_loading_summary - End');
  EXCEPTION
    WHEN e_abort THEN
      RAISE e_abort;
    WHEN OTHERS THEN
      g_step_id   := 'S08';
      g_sqlerrm   := SQLERRM;
      g_error_msg := 'Unexpected error has occured in the procedure ' ||
                     'invoice_loading_summary.Please contact SysAdmin';
      RAISE e_abort;
  END invoice_loading_summary;

  -- ===========================================================================
  --                      End Of Procedure invoice_loading_summary
  -- ===========================================================================

  -- ===========================================================================
  --                     Start of Procedure MAIN
  -- ===========================================================================
  PROCEDURE main(x_errbuf     OUT VARCHAR2,
                 x_retcode    OUT VARCHAR2)
  -- ===========================================================================
    --  Program name                Creation Date                Created by
    --  MAIN                        02-AUG-2016                  TCS
    -- ---------------------------------------------------------------------------
    -- Description  : This is the main procedure
    --
    -- Return value : None
    --
    -- ===========================================================================
   IS

    -- Declaration of Variables - Start
    l_request_id NUMBER;
    l_org_id     NUMBER;
    g_request_id NUMBER := fnd_global.conc_request_id;

    -- Declaration of Variables - End

  BEGIN
    FND_FILE.PUT_LINE(FND_FILE.LOG, CHR(13) || 'Procedure Main - Start');

    -- Initialization of Variables - Start
    x_errbuf     := 'SUCCESS';
    x_retcode    := '0';
    l_org_id     := NULL;
    l_request_id := NULL;

    -- Initialization of Variables - End

    FND_FILE.PUT_LINE(FND_FILE.LOG,
                      CHR(13) ||
                      'Calling Validate Procedure from Main - Start');
    -- Call Validate Procedure - Start
    invoice_hdr_validate(g_request_id);

    -- Call Validate Procedure - End

    FND_FILE.PUT_LINE(FND_FILE.LOG,
                      CHR(13) ||
                      'Calling Validate Procedure from Main - End');

    FND_FILE.PUT_LINE(FND_FILE.LOG,
                      CHR(13) ||
                      'Calling Header Insert Procedure from Main - Start');
    -- Call Header Insert Procedure - Start
    invoice_hdr_creation;

    -- Call Header Insert Procedure - End

    FND_FILE.PUT_LINE(FND_FILE.LOG,
                      CHR(13) ||
                      'Calling Header Insert Procedure from Main - End');

    l_org_id := fnd_profile.value('ORG_ID');
    -- Fetching ORG ID associated with Responsibility - End

    FND_FILE.PUT_LINE(FND_FILE.LOG,
                      CHR(13) || 'Calling Import Program from Main - Start');
    -- Calling Invoice Import Program - Start
    BEGIN
      l_request_id := fnd_request.submit_request(application => 'SQLAP',
                                                 program     => 'APXIIMPT',
                                                 description => 'Payables Open Interface Import',
                                                 argument1   => l_org_id,
                                                 argument2   => 'INTERFACE IMPORT',
                                                 argument4   => 'N/A');

    EXCEPTION
      WHEN OTHERS THEN
        g_step_id := 'M01';
        x_retcode := 2;
        x_errbuf  := 'SQLERRM :' || SQLERRM;
        RAISE e_abort;
    END;

    -- Calling Invoice Import Program - End

    FND_FILE.PUT_LINE(FND_FILE.LOG,
                      CHR(13) || 'Calling Import Program from Main - End');

    FND_FILE.PUT_LINE(FND_FILE.LOG, CHR(13) || 'Procedure Main - End');

    FND_FILE.PUT_LINE(FND_FILE.LOG,
                      CHR(13) ||
                      'Calling Summary Procedure from Main - Start');

    -- Calling Summary Procedure - Start
    invoice_loading_summary(p_request_id => g_request_id);

    -- Calling Summary Procedure - End

    FND_FILE.PUT_LINE(FND_FILE.LOG,
                      CHR(13) ||
                      'Calling Summary Procedure from Main - End');

    FND_FILE.PUT_LINE(FND_FILE.LOG,
                      CHR(13) ||
                      'Calling Update Invoice Staging Procedure from Main - Start');

    -- Calling Update Invoice Staging Procedure - Start
    update_inv_stg(g_request_id);

    COMMIT;
    -- Call Update Invoice Staging Procedure - End

    FND_FILE.PUT_LINE(FND_FILE.LOG,
                      CHR(13) ||
                      'Calling Update Invoice Staging Procedure from Main - End');

  EXCEPTION
    WHEN e_abort THEN
      ROLLBACK;
      g_step_id := 'M80';
      x_errbuf  := 'ERROR';
      x_retcode := '2';
      FND_FILE.PUT_LINE(FND_FILE.LOG,
                        CHR(13) || g_error_msg || '/SQLERRM: ' || g_sqlerrm ||
                        '/Step ID:' || g_step_id);

    WHEN OTHERS THEN
      ROLLBACK;
      g_step_id := 'M90';
      x_errbuf  := 'ERROR';
      x_retcode := '2';
      FND_FILE.PUT_LINE(FND_FILE.LOG,
                        CHR(13) ||
                        'Unexpected error occurred.Please contact SysAdmin.' ||
                        '/SQLERRM: ' || SQLERRM || '/Step ID : M02' ||
                        CHR(13));

  END main;
  -- ===========================================================================
--                     End of Procedure MAIN
-- ===========================================================================

END xxap_legacy_s3_intf_pkg;
/