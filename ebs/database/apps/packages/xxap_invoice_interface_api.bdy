CREATE OR REPLACE PACKAGE BODY xxap_invoice_interface_api AS
  ---------------------------------------------------------------------------
  -- $Header: xxap_invoice_interface_api   $
  ---------------------------------------------------------------------------
  -- Package: xxap_invoice_interface_api
  -- Created:
  -- Author  :
  --------------------------------------------------------------------------
  -- Perpose: CUST 641 CombTas Interfaces
  --          CR681: generic procerdures for invoice interface data check and import
  --------------------------------------------------------------------------
  -- Version  Date        Performer       Comments
  ----------  --------    --------------  -------------------------------------
  --     1.0  11.2.13     yuval tal       initial Build
  --     1.1  05/31/2016  diptasurjya     CHG0038550 - Add procedure process_oic_invoices
  --                      chatterjee      to process AP invoices which are being imported from
  --                                      Oracle Incentive Compensation
  --     1.2  03/06/2018  Diptasurjya     CHG0042331 - Change OIC invoice import logic to
  --                      Chatterjee      prevent non income tax reportable vendors invoice from being marked with income tax oode
  -----------------------------------------------------------------------------
  g_group_id          NUMBER;
  g_header_table_name VARCHAR2(50) := 'XX_AP_INVOICES_INTERFACE';
  g_line_table_name   VARCHAR2(50) := 'XX_AP_INVOICE_LINES_INTERFACE';
  ----------------------------------------------------
  -- submit_import
  -- submit Payables Open Interface Import for group id
  ----------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ---------------
  --     1.0  11.2.2013  yuval tal      Initial Build
  ----------------------------------------------------

  -------------------------------------------------------
  -- check_inv_exists
  --
  -- check existance of invoice in ap
  -- return invoice_id if exists
  -------------------------------------------------------
  FUNCTION check_inv_exists(p_org_id       NUMBER,
                            p_vendor_id    NUMBER,
                            p_invoice_num  VARCHAR2,
                            p_invoice_date DATE) RETURN NUMBER IS
    l_tmp NUMBER;
    CURSOR c_inv IS
      SELECT t.invoice_id
        FROM ap_invoices_all t
       WHERE t.org_id = p_org_id
         AND t.vendor_id = p_vendor_id
         AND t.invoice_num = p_invoice_num
         AND t.invoice_date = trunc(p_invoice_date);

  BEGIN

    OPEN c_inv;
    FETCH c_inv
      INTO l_tmp;
    CLOSE c_inv;
    RETURN nvl(l_tmp, 0);

  END;
  ----------------------------------------------------
  -- get_line_source
  --
  -----------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ---------------
  --     1.0  11.2.2013  yuval tal      Initial Build

  FUNCTION get_line_source(p_line_id NUMBER) RETURN VARCHAR2 IS
    l_source VARCHAR2(100);
  BEGIN
    SELECT l.source
      INTO l_source
      FROM xx_ap_invoice_lines_interface l, xx_ap_invoices_interface h
     WHERE l.invoice_id = h.invoice_id
       AND l.invoice_line_id = p_line_id;

    RETURN l_source;

  END;

  ----------------------------------------------------
  -- handle_line
  -----------------------------------------------------
  -- in : p_invoice_line_id

  ----------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ---------------
  --     1.0  11.2.2013  yuval tal      Initial Build
  PROCEDURE handle_line(p_invoice_line_id NUMBER,
                        p_err_code        OUT NUMBER,
                        p_err_message     OUT VARCHAR2) IS

    l_err_rec      xxobjt_interface_errors%ROWTYPE;
    l_table_source VARCHAR2(50);

  BEGIN
    p_err_code    := 0;
    p_err_message := NULL;

    l_table_source := get_line_source(p_invoice_line_id);

    xxobjt_interface_check.handle_check(p_group_id     => g_group_id,
                                        p_table_source => l_table_source,
                                        p_table_name   => g_line_table_name,
                                        p_id           => p_invoice_line_id,
                                        p_err_code     => p_err_code,
                                        p_err_message  => p_err_message);

    fnd_file.put_line(fnd_file.log,
                      'p_invoice_line_id=' || p_invoice_line_id ||
                      '  err_code=' || p_err_code || ' ' || p_err_message);

  EXCEPTION

    WHEN OTHERS THEN
      p_err_code            := 1;
      p_err_message         := SQLERRM;
      l_err_rec.table_name  := g_line_table_name;
      l_err_rec.obj_id      := p_invoice_line_id;
      l_err_rec.description := SQLERRM;
      l_err_rec.group_id    := g_group_id;
      l_err_rec.check_id    := -1;
      xxobjt_interface_check.insert_error(l_err_rec);
  END;

  ----------------------------------------------------
  -- handle_header
  ---------------------------------------------------
  -- process invoice checks header and lines

  ----------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ---------------
  --     1.0  11.2.2013  yuval tal      Initial Build
  PROCEDURE handle_header(p_invoice_id  NUMBER,
                          p_err_code    OUT NUMBER,
                          p_err_message OUT VARCHAR2) IS

    CURSOR c_invoices IS
      SELECT *
        FROM xx_ap_invoices_interface t
       WHERE t.invoice_id = p_invoice_id;

    CURSOR c_invoices_lines(c_invoice_id NUMBER) IS
      SELECT t.*
        FROM xx_ap_invoice_lines_interface t
       WHERE t.invoice_id = c_invoice_id;

    my_exception EXCEPTION;
    l_err_rec     xxobjt_interface_errors%ROWTYPE;
    l_err_code    NUMBER;
    l_err_message VARCHAR2(2000);

    l_source   VARCHAR2(50);
    l_err_flag NUMBER := 0;
  BEGIN
    p_err_code    := 0;
    p_err_message := NULL;
    FOR i IN c_invoices LOOP
      l_source := i.source;
      -- execure check for header

      xxobjt_interface_check.handle_check(p_group_id     => g_group_id,
                                          p_table_source => i.source,
                                          p_table_name   => g_header_table_name,
                                          p_id           => p_invoice_id,
                                          p_err_code     => p_err_code,
                                          p_err_message  => p_err_message);

      fnd_file.put_line(fnd_file.log,
                        'p_invoice_id=' || p_invoice_id || ' ' ||
                        substr(p_err_message, 1, 180));

      COMMIT;

      -- execute  check for lines
      l_err_flag := p_err_code;
      FOR j IN c_invoices_lines(p_invoice_id) LOOP

        handle_line(p_invoice_line_id => j.invoice_line_id,
                    p_err_code        => l_err_code,
                    p_err_message     => l_err_message);
        l_err_flag := greatest(l_err_flag, l_err_code);

      END LOOP;

      p_err_code := l_err_flag;

    END LOOP;

  EXCEPTION
    WHEN my_exception THEN
      NULL;
    WHEN OTHERS THEN
      p_err_code            := 1;
      p_err_message         := SQLERRM;
      l_err_rec.table_name  := g_header_table_name;
      l_err_rec.obj_id      := p_invoice_id;
      l_err_rec.description := SQLERRM;
      -- dbms_output.put_line('x=' || l_err_rec.description);
      l_err_rec.group_id := g_group_id;
      l_err_rec.check_id := -1;
      xxobjt_interface_check.insert_error(l_err_rec);

  END;

  -------------------------------------------------------
  -- get_import_status
  --------------------------------------------------------
  -- p_compeleted_code  Y import completed  / N import in process
  -- p_success          Y no erros  : N no  error exists
  --------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------
  --     1.0  11.2.2013  yuval tal      Initial Build
  ---------------------------------------------------------

  PROCEDURE get_import_status(p_request_id      NUMBER,
                              p_success         OUT VARCHAR2,
                              p_compeleted_code OUT VARCHAR2,
                              p_err_message     OUT VARCHAR2)

   IS

    --call_status
    l_success    BOOLEAN;
    l_phase      VARCHAR2(30);
    l_status     VARCHAR2(30);
    l_dev_phase  VARCHAR2(30);
    l_dev_status VARCHAR2(30);
    l_message    VARCHAR2(240);
    l_request_id NUMBER := p_request_id;

    CURSOR c_interface_err IS
      SELECT 'N'
        FROM ap_invoices_interface aii
       WHERE aii.status = 'REJECTED'
            -- AND aii.source = p_source
         AND aii.request_id = p_request_id;

  BEGIN
    l_success := fnd_concurrent.get_request_status(request_id => l_request_id,
                                                   --   appl_shortname => :appl_shortname,
                                                   --    program        => :program,
                                                   phase      => l_phase,
                                                   status     => l_status,
                                                   dev_phase  => l_dev_phase,
                                                   dev_status => l_dev_status,
                                                   message    => l_message);

    IF l_success THEN

      p_err_message := l_dev_phase;
      IF nvl(l_dev_phase, 'A') = 'COMPLETE' THEN

        p_compeleted_code := 'Y';

        OPEN c_interface_err;
        FETCH c_interface_err
          INTO p_success;
        CLOSE c_interface_err;
        p_success := nvl(p_success, 'Y');
      ELSE
        p_compeleted_code := 'N';

      END IF;

    ELSE

      p_compeleted_code := 'N';
      p_success         := 'N';
      p_err_message     := 'Unable to get request ' || l_request_id ||
                           ' status';

    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      p_compeleted_code := 'N';
      p_success         := 'N';
      p_err_message     := 'Failed get_import_status:' || SQLERRM;
  END;
  ----------------------------------------------------
  -- submit_ap_import
  --
  -- 1. submit ap invoice creation
  -- 2. update invoice status (ERROR/SUCCESS)+ new invoiceid in field invoice_id_ap in ap_invoices_all in table xx_ap_invoices_interface

  ----------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ---------------
  --     1.0  11.2.2013  yuval tal      Initial Build
  -----------------------------------------------------
  PROCEDURE submit_ap_import(p_group_id     NUMBER,
                             p_table_source VARCHAR2,
                             p_request_id   OUT NUMBER,
                             p_err_code     OUT NUMBER,
                             p_err_message  OUT VARCHAR2) IS
    --
    -- l_org_id NUMBER;
    --call_status

    v_phase         VARCHAR2(30);
    v_status        VARCHAR2(30);
    v_dev_phase     VARCHAR2(30);
    v_dev_status    VARCHAR2(30);
    v_message       VARCHAR2(240);
    l_success       BOOLEAN;
    l_invoice_id_ap NUMBER;
    --
    l_user_id     NUMBER;
    l_resp_id     NUMBER;
    l_resp_app_id NUMBER;
    l_err_rec     xxobjt_interface_errors%ROWTYPE;

    CURSOR c_check_invoices IS
      SELECT *
        FROM xx_ap_invoices_interface t
       WHERE group_id = p_group_id
         AND t.source = p_table_source;

    CURSOR c_imp_err(c_invoice_id NUMBER) IS
      SELECT *
        FROM (SELECT g_header_table_name table_name,
                     aii.group_id,
                     aii.invoice_id      obj_id,
                     aii.invoice_id,
                     aii.invoice_num,
                     0                   line_number,
                     flv.description
                FROM ap_invoices_interface aii,

                     ap_interface_rejections apr,
                     fnd_lookup_values       flv
               WHERE apr.parent_table = 'AP_INVOICES_INTERFACE'
                 AND aii.status = 'REJECTED'
                 AND aii.source = p_table_source
                 AND apr.parent_id = aii.invoice_id
                 AND flv.lookup_type = 'REJECT CODE'
                 AND flv.lookup_code = apr.reject_lookup_code
                 AND flv.language = 'US'
              UNION ALL
              SELECT g_line_table_name   table_name,
                     aii.group_id,
                     ail.invoice_line_id obj_id,
                     ail.invoice_id,
                     aii.invoice_num,
                     ail.line_number,
                     flv.description
                FROM ap_invoices_interface      aii,
                     ap_invoice_lines_interface ail,
                     ap_interface_rejections    apr,
                     fnd_lookup_values          flv
               WHERE apr.parent_table = 'AP_INVOICE_LINES_INTERFACE'
                 AND aii.status = 'REJECTED'
                 AND aii.source = p_table_source
                 AND aii.invoice_id = ail.invoice_id
                 AND apr.parent_id = ail.invoice_line_id
                 AND flv.lookup_type = 'REJECT CODE'
                 AND flv.lookup_code = apr.reject_lookup_code
                 AND flv.language = 'US')
       WHERE invoice_id = c_invoice_id;
  BEGIN

    fnd_file.put_line(fnd_file.log, 'Start submit_ap_import');
    p_err_code := 0;

    --

    --
    /*  l_user_id     := fnd_profile.value_specific(NAME   => 'XXAP_INVOICE_IMP_USER_ID',
                                                org_id => l_org_id);
    l_resp_id     := fnd_profile.value_specific(NAME   => 'XXAP_INVOICE_IMP_RESP_ID',
                                                org_id => l_org_id);
    l_resp_app_id := fnd_profile.value_specific(NAME   => 'XXAP_INVOICE_IMP_RESP_APP_ID',
                                                org_id => l_org_id);
    fnd_global.apps_initialize(l_user_id, l_resp_id, l_resp_app_id);*/
    --
    fnd_file.put_line(fnd_file.log, 'Begin APXIIMPT Submission');
    dbms_output.put_line('Begin APXIIMPT Submission');
    --
    p_request_id := fnd_request.submit_request(application => 'SQLAP',
                                               program     => 'APXIIMPT',
                                               description => 'Payables Open Interface Import',
                                               sub_request => FALSE,
                                               argument1   => NULL, -- l_org_id,
                                               argument2   => p_table_source,
                                               argument3   => p_group_id,
                                               argument4   => NULL, -- Batch Name
                                               argument5   => NULL, --Hold Name
                                               argument6   => NULL, --Hold Reason
                                               argument7   => NULL, --GL Date
                                               argument8   => 'N', --Purge
                                               argument9   => 'N', --Trace Switch
                                               argument10  => 'N', -- Debug Switch
                                               argument11  => 'N', --Summarize Report
                                               argument12  => 1000, --Commit Batch Size
                                               argument13  => l_user_id, --User ID,
                                               argument14  => fnd_global.login_id --LOGIN_ID,

                                               );

    COMMIT;
    IF p_request_id = 0 THEN

      p_err_code    := 1;
      p_err_message := 'Standard Program is Not Submitted';
      dbms_output.put_line(p_err_message);

      fnd_file.put_line(fnd_file.log,
                        p_err_message || ' ' || fnd_message.get);

    ELSE
      WHILE nvl(v_dev_phase, 'A') != 'COMPLETE' LOOP
        l_success := fnd_concurrent.wait_for_request(p_request_id,
                                                     5,
                                                     30,
                                                     v_phase,
                                                     v_status,
                                                     v_dev_phase,
                                                     v_dev_status,
                                                     v_message);
      END LOOP;
      IF l_success THEN
        dbms_output.put_line('Printing on True');
        dbms_output.put_line('Message is :' || v_message);
        dbms_output.put_line('Status is :' || v_status);
        dbms_output.put_line('phase is :' || v_phase);
      ELSE
        dbms_output.put_line('Printing On Flase');
        dbms_output.put_line('Message is :' || v_message);
        dbms_output.put_line('Status is :' || v_status);
        dbms_output.put_line('phase is :' || v_phase);
      END IF;
      -- dbms_output.put_line('Return Status :' || l_success);
    END IF;

    --
    -- check interface error
    --
    FOR i IN c_check_invoices LOOP

      IF i.status != 'ERROR' THEN
        -- check ap_invoices existance
        l_invoice_id_ap := check_inv_exists(i.org_id,
                                            i.vendor_id,
                                            i.invoice_num,
                                            i.invoice_date);
        IF l_invoice_id_ap != 0 THEN
          UPDATE xx_ap_invoices_interface t
             SET t.invoice_id_ap = l_invoice_id_ap, t.status = 'SUCCESS'
           WHERE t.invoice_id = i.invoice_id;
          fnd_file.put_line(fnd_file.log,
                            'Invoice num ' || i.invoice_num ||
                            ' Vendor Id ' || i.vendor_id || ' Created');
        ELSE
          UPDATE xx_ap_invoices_interface t
             SET t.status = 'ERROR'
           WHERE t.invoice_id = i.invoice_id;

          fnd_file.put_line(fnd_file.log,
                            'Error : Invoice num ' || i.invoice_num ||
                            'Vendor Id ' || i.vendor_id || ' Not Created');
          -- search errors in interface tables

          FOR j IN c_imp_err(i.invoice_id) LOOP
            l_err_rec.table_name  := j.table_name;
            l_err_rec.obj_id      := j.obj_id;
            l_err_rec.description := j.description;
            l_err_rec.group_id    := p_group_id;
            l_err_rec.check_id    := 0;
            xxobjt_interface_check.insert_error(l_err_rec);

          END LOOP;

        END IF;

      END IF;

    END LOOP;

    ----

    p_err_code    := 0;
    p_err_message := NULL;

  EXCEPTION
    WHEN OTHERS THEN
      p_err_code    := 1;
      p_err_message := 'Failed Submit Payables Open Interface Import:' ||
                       SQLERRM;
      fnd_file.put_line(fnd_file.log, p_err_message);

  END;

  ----------------------------------------------------
  -- copy_to_interface
  -- copy xx intreface record to ap interface records
  ----------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ---------------
  --     1.0  11.2.2013  yuval tal      Initial Build
  ----------------------------------------------------

  PROCEDURE copy_to_interface(p_group_id    NUMBER,
                              p_source      VARCHAR2,
                              p_err_code    OUT NUMBER,
                              p_err_message OUT VARCHAR2) IS

    CURSOR c_header IS
      SELECT t.*
        FROM xx_ap_invoices_interface t
       WHERE t.group_id = p_group_id
         AND t.source = p_source
         AND t.status = 'CHECKED';

    CURSOR c_lines(c_invoice_id NUMBER) IS
      SELECT t.*
        FROM xx_ap_invoice_lines_interface t
       WHERE t.invoice_id = c_invoice_id;

  BEGIN
    p_err_code    := 0;
    p_err_message := NULL;
    -- delete previous records
    DELETE FROM ap_invoice_lines_interface t
     WHERE t.invoice_id IN (SELECT invoice_id
                              FROM ap_invoices_interface t
                             WHERE t.group_id = p_group_id
                               AND t.source = p_source);

    DELETE FROM ap_invoices_interface t
     WHERE t.group_id = p_group_id
       AND t.source = p_source;

    COMMIT;
    FOR i IN c_header LOOP

      -- insert header
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
         awt_group_id,
         awt_group_name,
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
         /*  global_attribute_category,
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
         global_attribute20,*/
         status,
         SOURCE,
         group_id,
         request_id,
         payment_cross_rate_type,
         payment_cross_rate_date,
         payment_cross_rate,
         payment_currency_code,
         workflow_flag,
         doc_category_code,
         voucher_num,
         payment_method_lookup_code,
         pay_group_lookup_code,
         goods_received_date,
         invoice_received_date,
         gl_date,
         accts_pay_code_combination_id,
         ussgl_transaction_code,
         exclusive_payment_flag,
         org_id,
         amount_applicable_to_discount,
         prepay_num,
         prepay_dist_num,
         prepay_apply_amount,
         prepay_gl_date,
         invoice_includes_prepay_flag,
         no_xrate_base_amount,
         vendor_email_address,
         terms_date,
         requester_id,
         ship_to_location,
         external_doc_ref,
         prepay_line_num,
         requester_first_name,
         requester_last_name,
         application_id,
         product_table,
         reference_key1,
         reference_key2,
         reference_key3,
         reference_key4,
         reference_key5,
         apply_advances_flag,
         calc_tax_during_import_flag,
         control_amount,
         add_tax_to_inv_amt_flag,
         tax_related_invoice_id,
         taxation_country,
         document_sub_type,
         supplier_tax_invoice_number,
         supplier_tax_invoice_date,
         supplier_tax_exchange_rate,
         tax_invoice_recording_date,
         tax_invoice_internal_seq,
         legal_entity_id,
         legal_entity_name,
         reference_1,
         reference_2,
         operating_unit,
         bank_charge_bearer,
         remittance_message1,
         remittance_message2,
         remittance_message3,
         unique_remittance_identifier,
         uri_check_digit,
         settlement_priority,
         payment_reason_code,
         payment_reason_comments,
         payment_method_code,
         delivery_channel_code,
         paid_on_behalf_employee_id,
         net_of_retainage_flag,
         requester_employee_num,
         cust_registration_code,
         cust_registration_number,
         party_id,
         party_site_id,
         pay_proc_trxn_type_code,
         payment_function,
         payment_priority,
         port_of_entry_code,
         external_bank_account_id,
         accts_pay_code_concatenated,
         pay_awt_group_id,
         pay_awt_group_name,
         remit_to_supplier_name,
         remit_to_supplier_id,
         remit_to_supplier_site,
         remit_to_supplier_site_id,
         relationship_id,
         remit_to_supplier_num

         )
      VALUES
        (i.invoice_id,
         i.invoice_num,
         i.invoice_type_lookup_code,
         i.invoice_date,
         i.po_number,
         i. vendor_id,
         i. vendor_num,
         i. vendor_name,
         i. vendor_site_id,
         i. vendor_site_code,
         i. invoice_amount,
         i. invoice_currency_code,
         i. exchange_rate,
         i. exchange_rate_type,
         i. exchange_date,
         i. terms_id,
         i. terms_name,
         substr(i. description, 1, 239),
         i. awt_group_id,
         i. awt_group_name,
         i. last_update_date,
         i. last_updated_by,
         i. last_update_login,
         i. creation_date,
         i. created_by,
         i. attribute_category,
         i. attribute1,
         i. attribute2,
         i. attribute3,
         i. attribute4,
         i. attribute5,
         i. attribute6,
         i. attribute7,
         i. attribute8,
         i. attribute9,
         i. attribute10,
         i. attribute11,
         i. attribute12,
         i. attribute13,
         i. attribute14,
         i. attribute15,
         /* i. global_attribute_category,
         i. global_attribute1,
         i. global_attribute2,
         i. global_attribute3,
         i. global_attribute4,
         i. global_attribute5,
         i. global_attribute6,
         i. global_attribute7,
         i. global_attribute8,
         i. global_attribute9,
         i. global_attribute10,
         i. global_attribute11,
         i. global_attribute12,
         i.global_attribute13,
         i. global_attribute14,
         i. global_attribute15,
         i. global_attribute16,
         i. global_attribute17,
         i. global_attribute18,
         i. global_attribute19,
         i. global_attribute20,*/
         NULL, -- i. status,
         i. SOURCE,
         i. group_id,
         i. request_id,
         i. payment_cross_rate_type,
         i. payment_cross_rate_date,
         i. payment_cross_rate,
         i. payment_currency_code,
         i. workflow_flag,
         i. doc_category_code,
         i. voucher_num,
         i. payment_method_lookup_code,
         i. pay_group_lookup_code,
         i. goods_received_date,
         i. invoice_received_date,
         i. gl_date,
         i. accts_pay_code_combination_id,
         i. ussgl_transaction_code,
         i. exclusive_payment_flag,
         i. org_id,
         i. amount_applicable_to_discount,
         i. prepay_num,
         i. prepay_dist_num,
         i. prepay_apply_amount,
         i. prepay_gl_date,
         i. invoice_includes_prepay_flag,
         i. no_xrate_base_amount,
         i. vendor_email_address,
         i. terms_date,
         i. requester_id,
         i. ship_to_location,
         i. external_doc_ref,
         i. prepay_line_num,
         i. requester_first_name,
         i. requester_last_name,
         i. application_id,
         i. product_table,
         i. reference_key1,
         i. reference_key2,
         i. reference_key3,
         i. reference_key4,
         i. reference_key5,
         i. apply_advances_flag,
         i. calc_tax_during_import_flag,
         i. control_amount,
         i.add_tax_to_inv_amt_flag,
         i. tax_related_invoice_id,
         i. taxation_country,
         i. document_sub_type,
         i. supplier_tax_invoice_number,
         i. supplier_tax_invoice_date,
         i. supplier_tax_exchange_rate,
         i. tax_invoice_recording_date,
         i. tax_invoice_internal_seq,
         i. legal_entity_id,
         i. legal_entity_name,
         i. reference_1,
         i. reference_2,
         i. operating_unit,
         i. bank_charge_bearer,
         i. remittance_message1,
         i. remittance_message2,
         i. remittance_message3,
         i. unique_remittance_identifier,
         i. uri_check_digit,
         i. settlement_priority,
         i. payment_reason_code,
         i. payment_reason_comments,
         i. payment_method_code,
         i. delivery_channel_code,
         i. paid_on_behalf_employee_id,
         i. net_of_retainage_flag,
         i. requester_employee_num,
         i. cust_registration_code,
         i. cust_registration_number,
         i. party_id,
         i. party_site_id,
         i. pay_proc_trxn_type_code,
         i. payment_function,
         i. payment_priority,
         i. port_of_entry_code,
         i. external_bank_account_id,
         i. accts_pay_code_concatenated,
         i. pay_awt_group_id,
         i. pay_awt_group_name,
         i. remit_to_supplier_name,
         i. remit_to_supplier_id,
         i. remit_to_supplier_site,
         i. remit_to_supplier_site_id,
         i. relationship_id,
         i. remit_to_supplier_num);

      FOR j IN c_lines(i.invoice_id) LOOP

        INSERT INTO ap_invoice_lines_interface
          (invoice_id,
           invoice_line_id,
           line_number,
           line_type_lookup_code,
           line_group_number,
           amount,
           accounting_date,
           description,
           amount_includes_tax_flag,
           prorate_across_flag,
           tax_code,
           final_match_flag,
           po_header_id,
           po_number,
           po_line_id,
           po_line_number,
           po_line_location_id,
           po_shipment_num,
           po_distribution_id,
           po_distribution_num,
           po_unit_of_measure,
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
           /* global_attribute_category,
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
           global_attribute20,*/
           po_release_id,
           release_num,
           account_segment,
           balancing_segment,
           cost_center_segment,
           project_id,
           task_id,
           expenditure_type,
           expenditure_item_date,
           expenditure_organization_id,
           project_accounting_context,
           pa_addition_flag,
           pa_quantity,
           ussgl_transaction_code,
           stat_amount,
           type_1099,
           income_tax_region,
           assets_tracking_flag,
           price_correction_flag,
           org_id,
           receipt_number,
           receipt_line_number,
           match_option,
           packing_slip,
           rcv_transaction_id,
           pa_cc_ar_invoice_id,
           pa_cc_ar_invoice_line_num,
           reference_1,
           reference_2,
           pa_cc_processed_code,
           tax_recovery_rate,
           tax_recovery_override_flag,
           tax_recoverable_flag,
           tax_code_override_flag,
           tax_code_id,
           credit_card_trx_id,
           award_id,
           vendor_item_num,
           taxable_flag,
           price_correct_inv_num,
           external_doc_line_ref,
           serial_number,
           manufacturer,
           model_number,
           warranty_number,
           deferred_acctg_flag,
           def_acctg_start_date,
           def_acctg_end_date,
           def_acctg_number_of_periods,
           def_acctg_period_type,
           unit_of_meas_lookup_code,
           price_correct_inv_line_num,
           asset_book_type_code,
           asset_category_id,
           requester_id,
           requester_first_name,
           requester_last_name,
           requester_employee_num,
           application_id,
           product_table,
           reference_key1,
           reference_key2,
           reference_key3,
           reference_key4,
           reference_key5,
           purchasing_category,
           purchasing_category_id,
           cost_factor_id,
           cost_factor_name,
           control_amount,
           assessable_value,
           default_dist_ccid,
           primary_intended_use,
           ship_to_location_id,
           product_type,
           product_category,
           product_fisc_classification,
           user_defined_fisc_class,
           trx_business_category,
           tax_regime_code,
           tax,
           tax_jurisdiction_code,
           tax_status_code,
           tax_rate_id,
           tax_rate_code,
           tax_rate,
           incl_in_taxable_line_flag,
           source_application_id,
           source_entity_code,
           source_event_class_code,
           source_trx_id,
           source_line_id,
           source_trx_level_type,
           tax_classification_code,
           cc_reversal_flag,
           company_prepaid_invoice_id,
           expense_group,
           justification,
           merchant_document_number,
           merchant_name,
           merchant_reference,
           merchant_tax_reg_number,
           merchant_taxpayer_id,
           receipt_currency_code,
           receipt_conversion_rate,
           receipt_currency_amount,
           country_of_supply,
           pay_awt_group_id,
           pay_awt_group_name,
           expense_start_date,
           expense_end_date

           )

        VALUES
          (i.invoice_id,
           j.invoice_line_id,
           j.line_number,
           j.line_type_lookup_code,
           j.line_group_number,
           j.amount,
           j. accounting_date,
           substr(replace (replace (j.description,chr(13)||chr(10),chr(10)),'"'), 1, 200),
           j. amount_includes_tax_flag,
           j. prorate_across_flag,
           j. tax_code,
           j. final_match_flag,
           j. po_header_id,
           j. po_number,
           j. po_line_id,
           j. po_line_number,
           j. po_line_location_id,
           j. po_shipment_num,
           j. po_distribution_id,
           j. po_distribution_num,
           j. po_unit_of_measure,
           j. inventory_item_id,
           j. item_description,
           j. quantity_invoiced,
           j. ship_to_location_code,
           j. unit_price,
           j. distribution_set_id,
           j. distribution_set_name,
           j. dist_code_concatenated,
           j. dist_code_combination_id,
           j. awt_group_id,
           j. awt_group_name,
           j. last_updated_by,
           j. last_update_date,
           j. last_update_login,
           j. created_by,
           j. creation_date,
           j. attribute_category,
           j. attribute1,
           j. attribute2,
           j. attribute3,
           j. attribute4,
           j. attribute5,
           j. attribute6,
           j. attribute7,
           j. attribute8,
           j. attribute9,
           j. attribute10,
           j. attribute11,
           j. attribute12,
           j. attribute13,
           j. attribute14,
           j. attribute15,
           /* j. global_attribute_category,
           j. global_attribute1,
           j. global_attribute2,
           j. global_attribute3,
           j. global_attribute4,
           j. global_attribute5,
           j. global_attribute6,
           j. global_attribute7,
           j. global_attribute8,
           j. global_attribute9,
           j. global_attribute10,
           j. global_attribute11,
           j. global_attribute12,
           j. global_attribute13,
           j. global_attribute14,
           j. global_attribute15,
           j. global_attribute16,
           j. global_attribute17,
           j. global_attribute18,
           j. global_attribute19,
           j. global_attribute20,*/
           j. po_release_id,
           j. release_num,
           j. account_segment,
           j. balancing_segment,
           j. cost_center_segment,
           j. project_id,
           j. task_id,
           j. expenditure_type,
           j. expenditure_item_date,
           j. expenditure_organization_id,
           j. project_accounting_context,
           j. pa_addition_flag,
           j. pa_quantity,
           j. ussgl_transaction_code,
           j. stat_amount,
           j. type_1099,
           j. income_tax_region,
           j. assets_tracking_flag,
           j. price_correction_flag,
           j. org_id,
           j. receipt_number,
           j. receipt_line_number,
           j. match_option,
           j. packing_slip,
           j. rcv_transaction_id,
           j. pa_cc_ar_invoice_id,
           j. pa_cc_ar_invoice_line_num,
           j. reference_1,
           j.reference_2,
           j. pa_cc_processed_code,
           j. tax_recovery_rate,
           j. tax_recovery_override_flag,
           j. tax_recoverable_flag,
           j.tax_code_override_flag,
           j. tax_code_id,
           j. credit_card_trx_id,
           j. award_id,
           j. vendor_item_num,
           j. taxable_flag,
           j. price_correct_inv_num,
           j. external_doc_line_ref,
           j. serial_number,
           j. manufacturer,
           j. model_number,
           j. warranty_number,
           j. deferred_acctg_flag,
           j. def_acctg_start_date,
           j. def_acctg_end_date,
           j.def_acctg_number_of_periods,
           j. def_acctg_period_type,
           j. unit_of_meas_lookup_code,
           j. price_correct_inv_line_num,
           j. asset_book_type_code,
           j.asset_category_id,
           j. requester_id,
           j. requester_first_name,
           j. requester_last_name,
           j. requester_employee_num,
           j. application_id,
           j. product_table,
           j. reference_key1,
           j. reference_key2,
           j. reference_key3,
           j. reference_key4,
           j. reference_key5,
           j. purchasing_category,
           j. purchasing_category_id,
           j.cost_factor_id,
           j. cost_factor_name,
           j. control_amount,
           j. assessable_value,
           j. default_dist_ccid,
           j. primary_intended_use,
           j.ship_to_location_id,
           j.product_type,
           j. product_category,
           j. product_fisc_classification,
           j. user_defined_fisc_class,
           j. trx_business_category,
           j. tax_regime_code,
           j.tax,
           j. tax_jurisdiction_code,
           j. tax_status_code,
           j. tax_rate_id,
           j. tax_rate_code,
           j. tax_rate,
           j. incl_in_taxable_line_flag,
           j. source_application_id,
           j. source_entity_code,
           j. source_event_class_code,
           j. source_trx_id,
           j. source_line_id,
           j. source_trx_level_type,
           j. tax_classification_code,
           j. cc_reversal_flag,
           j. company_prepaid_invoice_id,
           j. expense_group,
           j. justification,
           j. merchant_document_number,
           j. merchant_name,
           j. merchant_reference,
           j. merchant_tax_reg_number,
           j. merchant_taxpayer_id,
           j. receipt_currency_code,
           j. receipt_conversion_rate,
           j. receipt_currency_amount,
           j. country_of_supply,
           j. pay_awt_group_id,
           j. pay_awt_group_name,
           j. expense_start_date,
           j. expense_end_date);

      END LOOP;

    END LOOP;

    COMMIT;

  EXCEPTION
    WHEN OTHERS THEN
      p_err_code    := 1;
      p_err_message := 'Failed copy records to Oracle AP interface:' ||
                       SQLERRM;

  END;
  -----------------------------------------------------
  -- get_err_xml
  --
  ----------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ---------------
  --     1.0  11.2.2013  yuval tal      Initial Build
  PROCEDURE get_err_xml(p_group_id    NUMBER,
                        p_err_code    OUT NUMBER,
                        p_err_message OUT VARCHAR2,
                        p_err_xml     OUT xmltype) IS
  BEGIN
    NULL;

  EXCEPTION
    WHEN OTHERS THEN
      p_err_code    := 1;
      p_err_message := SQLERRM;
  END;

  --------------------------------------------------
  -- check_invoices
  --------------------------------------------------
  -- steps :
  -- 1. execute header/lines check for all invoices in status 'NEW' after check status is changing to CHECKED/ERROR
  -- 2. if invoice in status checked exists  continue to ap import
  -- 3. check ap import errors
  --
  -- in :
  --     p_group_id : unique id for invoices in batch ( received in insert process)
  --     p_ap_import_flag : Y/N if no errors found continue to invoice creation
  -- out :
  --     p_err_code 1 error 0 success
  --     p_err_message : error message
  --     p_import_request_id : request id for seeded import inv prog  in case of p_ap_import_flag=Y
  --------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ---------------
  --     1.0  11.2.2013  yuval tal      Initial Build

  PROCEDURE process_invoices(p_err_code          OUT NUMBER,
                             p_err_message       OUT VARCHAR2,
                             p_import_request_id OUT NUMBER,
                             p_group_id          NUMBER,
                             p_ap_import_flag    VARCHAR2) IS

    CURSOR c_invoices IS
      SELECT *
        FROM xx_ap_invoices_interface t
       WHERE t.group_id = p_group_id;
    --   AND t.status = 'NEW';

    CURSOR c_checked_exists IS
      SELECT 0
        FROM xx_ap_invoices_interface t
       WHERE t.status = 'CHECKED'
         AND t.group_id = p_group_id;

    l_err_code    NUMBER;
    l_err_message VARCHAR2(3000);
    l_source      VARCHAR2(50);
    l_count       NUMBER := 0;
  BEGIN

    p_err_code := 0;

    g_group_id := p_group_id;
    --

    -- check every invoice for group
    FOR i IN c_invoices LOOP
      l_count := l_count + 1;

      l_source := i.source;
      handle_header(p_invoice_id  => i.invoice_id,
                    p_err_code    => l_err_code,
                    p_err_message => l_err_message);

      -- set status
      --
      fnd_file.put_line(fnd_file.log,
                        'handle header err_code=' || l_err_code);
      UPDATE xx_ap_invoices_interface t
         SET t.status =
             (CASE l_err_code
               WHEN 0 THEN
                'CHECKED'
               ELSE
                'ERROR'
             END)
       WHERE t.invoice_id = i.invoice_id;

      -- fnd_file.put_line(fnd_file.log, 'sql count=' || SQL%ROWCOUNT);
      COMMIT;

    END LOOP; -- invoice header
    fnd_file.put_line(fnd_file.log, 'Invoices found =' || l_count);
    ---- check invoice exists with status checked
    -- 0 exists
    OPEN c_checked_exists;
    FETCH c_checked_exists
      INTO p_err_code;
    CLOSE c_checked_exists;

    p_err_code := nvl(p_err_code, 1);

    IF p_err_code = 1 THEN
      p_err_message := 'Please Check Error Log';

      -- copy records to ap interface
    ELSIF p_err_code = 0 AND p_ap_import_flag = 'Y' THEN

      copy_to_interface(p_group_id, l_source, l_err_code, l_err_message);

      fnd_file.put_line(fnd_file.log,
                        'copy_to_interface l_err_code=' || l_err_code ||
                        ' l_err_message=' || l_err_message);

      IF l_err_code = 1 THEN
        p_err_message := l_err_message;
      ELSE
        --submit_import
        submit_ap_import(p_group_id,
                         l_source,
                         p_import_request_id,
                         l_err_code,
                         l_err_message);

        IF l_err_code = 1 THEN
          p_err_code    := l_err_code;
          p_err_message := l_err_message;
        END IF;

      END IF;
    END IF;

    ---

  EXCEPTION
    WHEN OTHERS THEN
      p_err_code    := 1;
      p_err_message := SQLERRM;
  END;
  --------------------------------------------------------------
  -- process_invoices_conc
  --
  ----------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ---------------
  --     1.0  11.2.2013  yuval tal      Initial Build
  -- submit ap import process from concurrent program
  --
  -- in :
  --                p_table_source   : invoice source from table xx_ap_invoices_interface . source
  --                p_group_id       : invoice group_id from table xx_ap_invoices_interface . group id
  --                p_ap_import_flag : execute import to ap process
  -- out :
  --                p_err_code    : 1 error 0 success
  --                p_err_message : error message

  --------------------------------------------------------------
  PROCEDURE process_invoices_conc(p_err_message    OUT VARCHAR2,
                                  p_err_code       OUT NUMBER,
                                  p_table_source   VARCHAR2,
                                  p_group_id       NUMBER,
                                  p_ap_import_flag VARCHAR2) IS

    CURSOR c_invoices IS
      SELECT DISTINCT t.source, t.group_id
        FROM xx_ap_invoices_interface t
       WHERE t.group_id = nvl(p_group_id, t.group_id)
         AND t.source = p_table_source;
    --  AND t.status = 'NEW';
    l_import_request_id NUMBER;
    l_err_code          NUMBER;
    l_err_message       VARCHAR2(2000);
    l_count             NUMBER := 0;
  BEGIN
    p_err_code := 0;
    fnd_file.put_line(fnd_file.log,
                      '----------- Start looking for invoices ----------');
    FOR i IN c_invoices LOOP

      fnd_file.put_line(fnd_file.log, 'Source=' || i.source);
      fnd_file.put_line(fnd_file.log, 'Group_id=' || i.group_id);

      process_invoices(l_err_code,
                       l_err_message,
                       l_import_request_id,
                       i.group_id,
                       p_ap_import_flag);

      fnd_file.put_line(fnd_file.log,
                        'import_request_id=' || l_import_request_id);
      fnd_file.put_line(fnd_file.log, 'err_code=' || l_err_code);
      fnd_file.put_line(fnd_file.log,
                        'err_message=' || substr(l_err_message, 1, 250));

      p_err_code := greatest(p_err_code, l_err_code);

    END LOOP;

  EXCEPTION
    WHEN OTHERS THEN
      p_err_code    := 2;
      p_err_message := SQLERRM;
  END;
  --------------------------------------------------------------
  -- get_invoice_err_string
  ----------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ---------------
  --     1.0  11.2.2013  yuval tal      Initial Build
  --
  -- submit ap import process from concurrent program
  --
  -- in :
  --                p_invoice_id   :

  -- out :  concate errors from header and lines for invoice  id

  FUNCTION get_invoice_err_string(p_invoice_id NUMBER, p_group_id NUMBER)
    RETURN VARCHAR2 IS
    CURSOR c IS
      SELECT DISTINCT t.description
        FROM xxap_invoices_int_err_v t
       WHERE t.invoice_id = p_invoice_id
         AND t.group_id = p_group_id;
    l_str VARCHAR2(32000);
  BEGIN

    FOR i IN c LOOP
      l_str := l_str || i.description || ', ';

    END LOOP;
    RETURN rtrim(l_str);
  END;

  --------------------------------------------------------------
  -- create_account
  --
  -- return code combination_id from cocate segment
  ----------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ---------------
  --     1.0  29.4.2013  yuval tal      Initial Build
  PROCEDURE create_account(p_concat_segment      VARCHAR2,
                           p_coa_id              NUMBER,
                           p_org_id              NUMBER DEFAULT NULL,
                           x_code_combination_id OUT NUMBER,
                           x_return_code         OUT VARCHAR2,
                           x_err_msg             OUT VARCHAR2) IS
    l_coa_id NUMBER;
  BEGIN

    l_coa_id := nvl(p_coa_id, xxgl_utils_pkg.get_coa_id_from_ou(p_org_id));

    SELECT fnd_api.g_ret_sts_success, code_combination_id
      INTO x_return_code, x_code_combination_id
      FROM gl_code_combinations_kfv x
     WHERE concatenated_segments = p_concat_segment
       AND x.chart_of_accounts_id = l_coa_id;

  EXCEPTION
    WHEN no_data_found THEN
      xxgl_utils_pkg.get_and_create_account(p_concat_segment      => p_concat_segment,
                                            p_coa_id              => l_coa_id,
                                            x_code_combination_id => x_code_combination_id,
                                            x_return_code         => x_return_code,
                                            x_err_msg             => x_err_msg);

  END;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0038550
  --          This is a wrapper procedure to process OIC invoices only.
  --          Input Parameter:
  --           a. p_process_rejected - Y/N. Y will re process all previously rejected invoices from OIC
  --           b. p_mail_import_summary - WIll mail the Standard AP import program output to mailing lists. Can be Y/N
  --
  --          The primary function of this procedure will be:
  --           1. Update income tax type in invoice lines interface for OIC invoices for tax reportable commission plan elements
  --              The update will also be applicable for US resellers only.
  --           2. Call standard Payables Open Interface import concurrent program after setting group ID and batch names
  --           3. In case of AP interface rejections, send notification email regarding rejected invoices
  --
  --          This procedure will be called from the concurrent program XXCN_OIC_INVOICE_IMPORT
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                                Description
  -- 1.0  05/20/2016  Diptasurjya Chatterjee              Initial Build
  -- 1.1  03/06/2018  Diptasurjya Chatterjee              CHG0042331 - Invoices for non 1099 reportable
  --                                                      vendors should not have income tax code added
  -- 1.2  08/30/2019  Diptasurjya Chatterjee              CHG0046413 - Populate expense account from custom expense DFF at 
  --                                                      plan element level in OIC
  -- --------------------------------------------------------------------------------------------
  PROCEDURE process_oic_invoices(ERRBUFF OUT VARCHAR2,
                                 RETCODE OUT VARCHAR2,
                                 --p_org_id            IN number,
                                 p_process_rejected  IN varchar2,
                                 p_mail_import_summary IN varchar2) IS

    l_source        varchar2(200) := 'ORACLE_SALES_COMPENSATION';
    l_program_name  varchar2(200) := 'XXCN_OIC_INVOICE_IMPORT';
    l_request_id    number := 0;
    l_group_id      number;
    v_phase         VARCHAR2(30);
    v_status        VARCHAR2(30);
    v_dev_phase     VARCHAR2(30);
    v_dev_status    VARCHAR2(30);
    v_message       VARCHAR2(240);
    l_success       BOOLEAN;

    p_org_id        number;

    l_record_count  number;
    l_intf_reject_cnt number;
    l_body          varchar2(4000);
    l_mail_to_list  varchar2(1000);
    l_mail_cc_list  varchar2(1000);
    l_mail_err_code number;
    l_mail_err_msg  varchar2(4000);

    l_dist_list     boolean;
    l_dist_mail_sub varchar2(200) := '';
    l_dist_mail_to  varchar2(2000) := '';
    l_dist_mail_cc  varchar2(2000) := '';

    cursor cur_oic_invoices is
           select *
             from ap_invoices_interface aii
            where aii.source = l_source
              and aii.org_id = p_org_id
              and nvl(aii.status,'NEW') in ('NEW','REJECT');

  BEGIN
    -- Section 1
    fnd_file.put_line(fnd_file.log, 'Start process_oic_invoices');
    retcode := 0;
    errbuff := 'Success';

    --mo_global.set_policy_context('S',p_org_id);
    p_org_id := mo_global.get_current_org_id;

    fnd_file.put_line(fnd_file.log, 'Updating invoice number to add Stratasys specific prefix XX: OIC AP Invoice Number Prefix');
    -- Section 2
    update ap_invoices_interface aii
       set aii.attribute7 = aii.invoice_num,
           aii.invoice_num = fnd_profile.VALUE('XXCN_OIC_INVOICE_PREFIX')||aii.invoice_num
     where aii.source = l_source
       and aii.org_id = p_org_id
       and aii.status is null
       and length(aii.invoice_num) = length(replace(aii.invoice_num,fnd_profile.VALUE('XXCN_OIC_INVOICE_PREFIX'),''));
    fnd_file.put_line(fnd_file.log, 'Invoice number updated with prefix specified in profile XX: OIC AP Invoice Number Prefix : '||SQL%ROWCOUNT);
    --commit;

    fnd_file.put_line(fnd_file.log, 'Updating income tax type of invoice lines interface for tax reportable OIC products');
    -- Section 3
    update ap_invoice_lines_interface aili
       set aili.type_1099 = fnd_profile.VALUE('XXCN_INCOME_TAX_TYPE'),
           aili.last_update_date = sysdate
     where exists (select 1
                     from ap_invoices_interface aii1,
                          ap_supplier_sites_all assa,
                          ap_suppliers asp   -- CHG0042331
                    where aii1.invoice_id = aili.invoice_id
                      and (aii1.status is null or (aii1.status = 'REJECTED' and p_process_rejected = 'Y'))
                      and aii1.source = l_source
                      and aii1.org_id = p_org_id
                      and assa.vendor_site_id = aii1.vendor_site_id
                      and assa.vendor_id = asp.vendor_id     -- CHG0042331
                      and asp.federal_reportable_flag = 'Y'  -- CHG0042331
                      and assa.country = 'US')
       and exists (select 1
                     from ap_invoices_interface aii,
                          cn_payment_transactions_all cpta,
                          cn_quotas_all cq
                    where aii.source = l_source
                      and aii.org_id = p_org_id
                      and (aii.status is null or aii.status = 'REJECTED')
                      and aii.invoice_id = aili.invoice_id
                      and to_number(aii.attribute7) = cpta.payment_transaction_id
                      and aii.org_id = cpta.org_id
                      and cpta.quota_id = cq.quota_id
                      and nvl(cq.attribute1,'Y') = 'Y');
    fnd_file.put_line(fnd_file.log, 'Invoice lines updated with income tax type: '||SQL%ROWCOUNT);
    --commit;

    -- CHG0046413 - populate expense account from custom DFF at plan element level
    -- Section 4
    update ap_invoice_lines_interface aili
       set aili.dist_code_combination_id = (select cq1.attribute2
                     from ap_invoices_interface aii1,
                          cn_payment_transactions_all cpta1,
                          cn_quotas_all cq1
                    where aii1.source = l_source
                      and aii1.org_id = p_org_id
                      and (aii1.status is null or aii1.status = 'REJECTED')
                      and aii1.invoice_id = aili.invoice_id
                      and to_number(aii1.attribute7) = cpta1.payment_transaction_id
                      and aii1.org_id = cpta1.org_id
                      and cpta1.quota_id = cq1.quota_id)
     where (select cq.attribute2
              from ap_invoices_interface aii,
                   cn_payment_transactions_all cpta,
                   cn_quotas_all cq
             where aii.source = l_source
               and aii.org_id = p_org_id
               and (aii.status is null or aii.status = 'REJECTED')
               and aii.invoice_id = aili.invoice_id
               and to_number(aii.attribute7) = cpta.payment_transaction_id
               and aii.org_id = cpta.org_id
               and cpta.quota_id = cq.quota_id) is not null;

    l_dist_mail_to := xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit => p_org_id, p_program_short_name => l_program_name||'_AP_TO');
    l_dist_mail_cc := xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit => p_org_id, p_program_short_name => l_program_name||'_AP_CC');
    l_mail_to_list := xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit => p_org_id, p_program_short_name => l_program_name||'_REJ_AP_TO');


    select decode(xxobjt_general_utils_pkg.am_i_in_production,'N',sys_context('userenv', 'db_name')||':','')||'Incentive Compensation payable invoice import summary'
      into l_dist_mail_sub
      from dual;

    -- Section 5
    for rec_payruns in (select distinct cpa.name
                          from ap_invoices_interface aii2,
                               CN_PAYRUNS_ALL cpa,
                               cn_payment_transactions_all cpta
                         where aii2.source = l_source
                           and aii2.org_id = p_org_id
                           and (aii2.status is null or (aii2.status = 'REJECTED' and p_process_rejected = 'Y'))
                           and cpta.payment_transaction_id = aii2.attribute7
                           and cpta.payrun_id = cpa.payrun_id)
    loop
      -- Section 6
      fnd_file.put_line(fnd_file.log, 'Begin APXIIMPT Submission for OIC payment batch: '||rec_payruns.name);

      l_group_id := XX_AP_INV_OIC_GROUP_S.Nextval;
      l_request_id := 0;
      v_dev_phase := null;
      l_success := null;
      v_phase := null;
      v_status := null;
      v_dev_status := null;
      v_message := null;

      -- Section 7
      fnd_file.put_line(fnd_file.log, 'Updating group ID of invoice interface to: '||l_group_id);

      update ap_invoices_interface aii
         set aii.group_id = l_group_id
       where exists (select 1
                       from cn_payruns_all cpa,
                            cn_payment_transactions_all cpta
                      where cpta.payrun_id = cpa.payrun_id
                        and cpa.name = rec_payruns.name
                        and cpta.payment_transaction_id = aii.attribute7)
        and aii.source = l_source
        and aii.org_id = p_org_id
        and (aii.status is null or (aii.status = 'REJECTED' and p_process_rejected = 'Y'));
      fnd_file.put_line(fnd_file.log, 'Group ID: '||l_group_id||' updated for '||SQL%ROWCOUNT||' invoice records');
      fnd_file.put_line(fnd_file.log, 'Start processing for OIC batch name: '||rec_payruns.name);
      commit;

      if p_mail_import_summary = 'Y' then -- Import program output needs to be mailed
        fnd_file.put_line(fnd_file.log, 'Start set program delivery options to send output as email');
        -- Section 8
        --
        l_dist_list :=
          fnd_request.add_delivery_option (TYPE         => 'E', -- this one to speciy the delivery option as Email
                                           p_argument1  => l_dist_mail_sub, -- subject for the mail
                                           p_argument2  => xxobjt_general_utils_pkg.get_from_mail, -- from address
                                           p_argument3  => l_dist_mail_to, -- to address
                                           p_argument4  => l_dist_mail_cc, -- cc address to be specified here.
                                           nls_language => '');
        fnd_file.put_line(fnd_file.log, 'End set program delivery options to send output as email');
      end if;
      -- Section 9
      --
      l_request_id := fnd_request.submit_request(application => 'SQLAP',
                                                 program     => 'APXIIMPT',
                                                 description => 'Payables Open Interface Import',
                                                 sub_request => FALSE,
                                                 argument1   => p_org_id, -- l_org_id,
                                                 argument2   => l_source,
                                                 argument3   => l_group_id,
                                                 argument4   => NULL, -- Batch Name
                                                 argument5   => NULL, --Hold Name
                                                 argument6   => NULL, --Hold Reason
                                                 argument7   => NULL, --GL Date
                                                 argument8   => 'N', --Purge
                                                 argument9   => 'N', --Trace Switch
                                                 argument10  => 'N', -- Debug Switch
                                                 argument11  => 'N', --Summarize Report
                                                 argument12  => 1000, --Commit Batch Size
                                                 argument13  => fnd_global.USER_ID, --User ID,
                                                 argument14  => fnd_global.login_id --LOGIN_ID,

                                                 );

      COMMIT;
      IF l_request_id = 0 THEN

        retcode    := 2;
        errbuff := 'Payables Open Interface Import could not be submitted';

        fnd_file.put_line(fnd_file.log,
                          errbuff || ' ' || fnd_message.get);

      ELSE
        WHILE nvl(v_dev_phase, 'A') != 'COMPLETE' LOOP
          l_success := fnd_concurrent.wait_for_request(l_request_id,
                                                       5,
                                                       30,
                                                       v_phase,
                                                       v_status,
                                                       v_dev_phase,
                                                       v_dev_status,
                                                       v_message);
        END LOOP;
        IF l_success THEN
          fnd_file.put_line(fnd_file.log, 'Program Complete: '||v_status);
        ELSE
          fnd_file.put_line(fnd_file.log, 'Program Complete: '||v_status);

          retcode    := 1;
          errbuff := 'Warning';
        END IF;

        select count(1)
          into l_intf_reject_cnt
          from ap_invoices_interface
         where source = l_source
           and status = 'REJECTED'
           and group_id = l_group_id
           and org_id = p_org_id;

        IF l_intf_reject_cnt > 0 then
          IF p_mail_import_summary = 'Y' then
            begin
              fnd_file.put_line(fnd_file.log,'Start sending mail for AP Invoice import rejections');
              l_body := xxobjt_wf_mail_support.get_header_html('INTERNAL')||'<p>
    Hi
    <br><br>
    Please note that '||l_intf_reject_cnt||' reseller commissions payment invoices were rejected during import.
    <br><br>
    Check the invoice import summary that has been emailed to you, for details about the rejected invoices.
    <BR>
    Please correct the invoice information in AP interface, before submitting this program once again to process the rejected invoices.
    <BR><BR>
    Request ID with rejections: '||l_request_id||'<br>
    OIC Payment Batch: '||rec_payruns.name||'
    </p>
    <br><br>'||
    xxobjt_wf_mail_support.get_footer_html;

                  /*for rec1 in (select '<tr><td>'||aii1.invoice_num||'</td><td>'||aii1.attribute7||'</td><td>'|| (select listagg(air.reject_lookup_code, 'chr(10)') within group(order by air.parent_table, air.reject_lookup_code)
                                from ap_interface_rejections air
                               where air.parent_id in
                                     (aii1.invoice_id,
                                      (select aili.invoice_line_id
                                         from ap_invoice_lines_interface aili
                                        where aili.invoice_id = aii1.invoice_id)))||'</td></tr>' rowrec
                              from ap_invoices_interface aii1--, po_vendors pv
                              where aii1.source = l_source
                                and aii1.status = 'REJECTED'
                                --and aii1.vendor_id = pv.VENDOR_ID
                                and aii1.group_id = l_group_id
                                and aii1.org_id = p_org_id)
                  loop
                    l_body := l_body||rec1.rowrec;
                  end loop;*/

                  fnd_file.put_line(fnd_file.log,'Body: '||l_body);
                  xxobjt_wf_mail.send_mail_html(p_to_role => l_mail_to_list,
                                                p_cc_mail => l_dist_mail_cc,
                                                p_subject => 'ERROR: Reseller Commissions invoice import failure',
                                                p_body_html => l_body,
                                                p_err_code => l_mail_err_code,
                                                p_err_message => l_mail_err_msg);
                    fnd_file.put_line(fnd_file.log,'Mail Error'||l_mail_err_msg);
                    fnd_file.put_line(fnd_file.log,'Mail Error Code'||l_mail_err_code);

                  fnd_file.put_line(fnd_file.log,'End sending mail for AP Invoice import rejections');

                  if l_mail_err_code <> 0 then
                    fnd_file.put_line(fnd_file.log,'ERROR sending mail for AP Invoice import rejections'||SQLERRM);
                    retcode    := 2;
                    errbuff := 'Error';
                  end if;
            exception when others then
              fnd_file.put_line(fnd_file.log,'ERROR sending mail for AP Invoice import rejections'||SQLERRM);
              retcode    := 2;
              errbuff := 'Error';
            end;
          END IF;
        END IF;
      END IF;
    end loop;
fnd_file.put_line(fnd_file.log,'p_err_code: '||retcode);
  EXCEPTION WHEN OTHERS THEN
    rollback;
    fnd_file.put_line(fnd_file.log, 'ERROR: In process_oic_invoices: '||SQLERRM);
    retcode    := 2;
    errbuff := 'Error';
  END process_oic_invoices;
END;
/
