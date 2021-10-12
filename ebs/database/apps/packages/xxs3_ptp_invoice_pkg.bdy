CREATE OR REPLACE PACKAGE xxs3_ptp_invoice_pkg AUTHID CURRENT_USER AS
  ----------------------------------------------------------------------------
  --  name:            xxs3_ptp_invoice_pkg
  --  create by:       Debarati Banerjee
  --  Revision:        1.0
  --  creation date:   12/08/2016
  ----------------------------------------------------------------------------
  --  purpose :        Package to extract the Open Invoice template fields
  --                   from Legacy system

  ----------------------------------------------------------------------------
  --  ver  date        name                         desc
  --  1.0  12/08/2016  Debarati Banerjee            Initial build
  ----------------------------------------------------------------------------

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will extract all required Open Invoice fields and insert into
  --           staging table XXS3_PTP_INVOICE
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0  12/08/2016  Debarati Banerjee            Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE open_invoice_extract_data(x_errbuf  OUT VARCHAR2
                                     ,x_retcode OUT NUMBER);
  PROCEDURE open_invoice_extract_line_data(x_errbuf  OUT VARCHAR2
                                          ,x_retcode OUT NUMBER);
  PROCEDURE open_invoice_transform_report(p_entity VARCHAR2);

END xxs3_ptp_invoice_pkg;
/
CREATE OR REPLACE PACKAGE BODY xxs3_ptp_invoice_pkg AS
  ----------------------------------------------------------------------------
  --  name:            xxs3_ptp_invoice_pkg
  --  create by:       Debarati Banerjee
  --  Revision:        1.0
  --  creation date:   12/08/2016
  ----------------------------------------------------------------------------
  --  purpose :        Package to extract the Open Invoice template fields
  --                   from Legacy system

  ----------------------------------------------------------------------------
  --  ver  date        name                         desc
  --  1.0  12/08/2016  Debarati Banerjee            Initial build
  ----------------------------------------------------------------------------



  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will extract all required Open Invoice fields and insert into
  --           staging table XXS3_PTP_INVOICE
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  12/08/2016  Debarati Banerjee            Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE open_invoice_extract_data(x_errbuf  OUT VARCHAR2
                                     ,x_retcode OUT NUMBER) IS
  
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
    l_step                   VARCHAR2(1000);
    l_count                  NUMBER;
  
    CURSOR c_invoice_extract IS
    -- Query to pick up unpaid standard invoices 
      SELECT invoice_id
            ,accts_pay_code_concatenated
            ,accts_pay_code_segment1
            ,accts_pay_code_segment2
            ,accts_pay_code_segment3
            ,accts_pay_code_segment5
            ,accts_pay_code_segment6
            ,accts_pay_code_segment7
            ,accts_pay_code_segment10
            ,amount_applicable_to_discount
            ,attribute1
            ,attribute2
            ,attribute3
            ,attribute4
            ,attribute5
            ,attribute6
            ,attribute7
            ,attribute8
            ,attribute9
            ,attribute10
            ,attribute11
            ,attribute12
            ,attribute13
            ,attribute14
            ,attribute15
            ,attribute_category
            ,bank_charge_bearer
            ,control_amount
            ,cust_registration_code
            ,cust_registration_number
            ,delivery_channel_code
            ,description
            ,dispute_reason
            ,doc_category_code
            ,exchange_date
            ,exchange_rate
            ,exchange_rate_type
            ,global_attribute1
            ,global_attribute2
            ,global_attribute3
            ,global_attribute4
            ,global_attribute5
            ,global_attribute6
            ,global_attribute7
            ,global_attribute8
            ,global_attribute9
            ,global_attribute10
            ,global_attribute11
            ,global_attribute12
            ,global_attribute13
            ,global_attribute14
            ,global_attribute15
            ,global_attribute16
            ,global_attribute17
            ,global_attribute18
            ,global_attribute19
            ,global_attribute20
            ,global_attribute_category
            ,gl_date
            ,goods_received_date
            ,invoice_amount
            ,invoice_currency_code
            ,invoice_date
            ,invoice_num
            ,invoice_received_date
            ,invoice_type_lookup_code
            ,legal_entity_name
            ,set_of_books_name
            ,net_of_retainage_flag
            ,operating_unit
            ,original_invoice_amount
            ,payment_currency_code
            ,payment_method_code
            ,
             --PAYMENT_METHOD_LOOKUP_CODE  ,  
             payment_reason_code
            ,payment_reason_comments
            ,pay_group_lookup_code
            ,port_of_entry_code
            ,po_number
            ,product_table
            ,requester_employee_num
            ,SOURCE
            ,terms_date
            ,terms_name
            ,vendor_email_address
            ,vendor_name
            ,vendor_number
            ,vendor_site_code
            ,voucher_num
      FROM (SELECT (SELECT concatenated_segments
                    FROM gl_code_combinations_kfv gcck
                    WHERE gcck.code_combination_id =
                          aia.accts_pay_code_combination_id) accts_pay_code_concatenated
                  ,(SELECT segment1
                    FROM gl_code_combinations_kfv gcck
                    WHERE gcck.code_combination_id =
                          aia.accts_pay_code_combination_id) accts_pay_code_segment1
                  ,(SELECT segment2
                    FROM gl_code_combinations_kfv gcck
                    WHERE gcck.code_combination_id =
                          aia.accts_pay_code_combination_id) accts_pay_code_segment2
                  ,(SELECT segment3
                    FROM gl_code_combinations_kfv gcck
                    WHERE gcck.code_combination_id =
                          aia.accts_pay_code_combination_id) accts_pay_code_segment3
                  ,(SELECT segment5
                    FROM gl_code_combinations_kfv gcck
                    WHERE gcck.code_combination_id =
                          aia.accts_pay_code_combination_id) accts_pay_code_segment5
                  ,(SELECT segment6
                    FROM gl_code_combinations_kfv gcck
                    WHERE gcck.code_combination_id =
                          aia.accts_pay_code_combination_id) accts_pay_code_segment6
                  ,(SELECT segment7
                    FROM gl_code_combinations_kfv gcck
                    WHERE gcck.code_combination_id =
                          aia.accts_pay_code_combination_id) accts_pay_code_segment7
                  ,(SELECT segment10
                    FROM gl_code_combinations_kfv gcck
                    WHERE gcck.code_combination_id =
                          aia.accts_pay_code_combination_id) accts_pay_code_segment10
                  ,amount_applicable_to_discount
                  ,attribute1
                  ,attribute2
                  ,attribute3
                  ,attribute4
                  ,attribute5
                  ,attribute6
                  ,attribute7
                  ,attribute8
                  ,attribute9
                  ,attribute10
                  ,attribute11
                  ,attribute12
                  ,attribute13
                  ,attribute14
                  ,attribute15
                  ,attribute_category
                  ,bank_charge_bearer
                  ,control_amount
                  ,cust_registration_code
                  ,cust_registration_number
                  ,delivery_channel_code
                  ,description
                  ,dispute_reason
                  ,doc_category_code
                  ,exchange_date
                  ,exchange_rate
                  ,exchange_rate_type
                  ,global_attribute1
                  ,global_attribute2
                  ,global_attribute3
                  ,global_attribute4
                  ,global_attribute5
                  ,global_attribute6
                  ,global_attribute7
                  ,global_attribute8
                  ,global_attribute9
                  ,global_attribute10
                  ,global_attribute11
                  ,global_attribute12
                  ,global_attribute13
                  ,global_attribute14
                  ,global_attribute15
                  ,global_attribute16
                  ,global_attribute17
                  ,global_attribute18
                  ,global_attribute19
                  ,global_attribute20
                  ,global_attribute_category
                  ,gl_date
                  ,goods_received_date
                   --,(invoice_amount - nvl(amount_paid
                   --                       ,0)) invoice_amount
                  ,invoice_amount
                  ,invoice_currency_code
                  ,invoice_date
                  ,invoice_id
                  ,invoice_num
                  ,invoice_received_date
                  ,invoice_type_lookup_code
                  ,(SELECT legal_entity_name
                    FROM xle_le_ou_ledger_v
                    WHERE legal_entity_id = aia.legal_entity_id) legal_entity_name
                  ,set_of_books_name
                  ,
                   /*(SELECT NAME FROM GL_LEDGERS
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                WHERE LEDGER_ID=AIA.SET_OF_BOOKS_ID) SET_OF_BOOKS_NAME,*/net_of_retainage_flag
                  ,(SELECT NAME
                    FROM hr_operating_units hou
                    WHERE hou.organization_id = aia.org_id) operating_unit
                  ,original_invoice_amount
                  ,payment_currency_code
                  ,payment_method_code
                  ,
                   --PAYMENT_METHOD_LOOKUP_CODE  ,
                   payment_reason_code
                  ,payment_reason_comments
                  ,pay_group_lookup_code
                  ,port_of_entry_code
                  ,po_number
                  ,
                   /*(SELECT SEGMENT1 FROM PO_HEADERS_ALL PHA
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                WHERE PHA.PO_HEADER_ID=AIA.QUICK_PO_HEADER_ID)PO_NUMBER  ,*/product_table
                  ,(SELECT employee_number
                    FROM per_all_people_f papf
                    WHERE papf.person_id = aia.requester_id
                    AND trunc(SYSDATE) BETWEEN
                          trunc(nvl(papf.effective_start_date
                                ,SYSDATE)) AND
                          trunc(nvl(papf.effective_end_date
                                   ,SYSDATE + 1))) requester_employee_num
                  ,SOURCE
                  ,terms_date
                  ,terms_name
                  ,(SELECT email_address
                    FROM ap_supplier_sites_all assa
                    WHERE assa.vendor_site_id = aia.vendor_site_id
                    AND assa.inactive_date IS NULL) vendor_email_address
                  ,vendor_name
                  ,vendor_number
                  ,vendor_site_code
                  ,voucher_num
            FROM ap_invoices_v aia
            WHERE aia.org_id = l_org_id
            AND aia.invoice_type_lookup_code = 'STANDARD'
            AND aia.cancelled_date IS NULL
                 --  AND aia.invoice_id = 988922
            AND nvl(aia.invoice_amount
                  ,0) > 0
            AND nvl(aia.amount_paid
                  ,0) = 0
            AND ap_invoices_pkg.get_approval_status(aia.invoice_id
                                                  ,aia.invoice_amount
                                                  ,aia.payment_status_flag
                                                  ,aia.invoice_type_lookup_code) =
                  'APPROVED'
            
            /* UNION
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        --QUERY FOR STANDARD PARTIALLY PAID INVOICE HEADER
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        SELECT (SELECT concatenated_segments
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                FROM gl_code_combinations_kfv gcck
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                WHERE gcck.code_combination_id =
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      aia.accts_pay_code_combination_id) accts_pay_code_concatenated
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,(SELECT segment1
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                FROM gl_code_combinations_kfv gcck
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                WHERE gcck.code_combination_id =
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      aia.accts_pay_code_combination_id) accts_pay_code_segment1
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,(SELECT segment2
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                FROM gl_code_combinations_kfv gcck
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                WHERE gcck.code_combination_id =
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      aia.accts_pay_code_combination_id) accts_pay_code_segment2
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,(SELECT segment3
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                FROM gl_code_combinations_kfv gcck
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                WHERE gcck.code_combination_id =
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      aia.accts_pay_code_combination_id) accts_pay_code_segment3
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,(SELECT segment5
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                FROM gl_code_combinations_kfv gcck
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                WHERE gcck.code_combination_id =
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      aia.accts_pay_code_combination_id) accts_pay_code_segment5
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,(SELECT segment6
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                FROM gl_code_combinations_kfv gcck
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                WHERE gcck.code_combination_id =
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      aia.accts_pay_code_combination_id) accts_pay_code_segment6
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,(SELECT segment7
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                FROM gl_code_combinations_kfv gcck
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                WHERE gcck.code_combination_id =
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      aia.accts_pay_code_combination_id) accts_pay_code_segment7
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,(SELECT segment10
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                FROM gl_code_combinations_kfv gcck
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                WHERE gcck.code_combination_id =
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      aia.accts_pay_code_combination_id) accts_pay_code_segment10
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,amount_applicable_to_discount
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,attribute1
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,attribute2
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,attribute3
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,attribute4
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,attribute5
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,attribute6
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,attribute7
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,attribute8
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,attribute9
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,attribute10
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,attribute11
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,attribute12
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,attribute13
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,attribute14
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,attribute15
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,attribute_category
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,bank_charge_bearer
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,control_amount
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,cust_registration_code
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,cust_registration_number
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,delivery_channel_code
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,description
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,dispute_reason
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,doc_category_code
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,exchange_date
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,exchange_rate
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,exchange_rate_type
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,global_attribute1
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,global_attribute2
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,global_attribute3
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,global_attribute4
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,global_attribute5
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,global_attribute6
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,global_attribute7
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,global_attribute8
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,global_attribute9
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,global_attribute10
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,global_attribute11
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,global_attribute12
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,global_attribute13
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,global_attribute14
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,global_attribute15
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,global_attribute16
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,global_attribute17
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,global_attribute18
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,global_attribute19
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,global_attribute20
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,global_attribute_category
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,gl_date
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,goods_received_date
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,(invoice_amount - nvl(amount_paid
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    ,0)) invoice_amount
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,invoice_currency_code
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,invoice_date
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,invoice_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,invoice_num
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,invoice_received_date
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,invoice_type_lookup_code
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,(SELECT legal_entity_name
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                FROM xle_le_ou_ledger_v
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                WHERE legal_entity_id = aia.legal_entity_id) legal_entity_name
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,set_of_books_name
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              --(SELECT NAME FROM GL_LEDGERS
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         --                                                                                                                                                                                                                                        WHERE LEDGER_ID=AIA.SET_OF_BOOKS_ID) SET_OF_BOOKS_NAME, 
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               */
            /*net_of_retainage_flag
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,(SELECT NAME
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                FROM hr_operating_units hou
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                WHERE hou.organization_id = aia.org_id) operating_unit
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,original_invoice_amount
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,payment_currency_code
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,payment_method_code
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               --PAYMENT_METHOD_LOOKUP_CODE  ,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               payment_reason_code
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,payment_reason_comments
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,pay_group_lookup_code
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,port_of_entry_code
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,po_number
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              -- (SELECT SEGMENT1 FROM PO_HEADERS_ALL PHA
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             --                                                                                                                                                                                                                                    WHERE PHA.PO_HEADER_ID=AIA.QUICK_PO_HEADER_ID)PO_NUMBER  ,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             product_table
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,(SELECT employee_number
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                FROM per_all_people_f papf
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                WHERE papf.person_id = aia.requester_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                AND trunc(SYSDATE) BETWEEN
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      trunc(nvl(papf.effective_start_date
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            ,SYSDATE)) AND
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      trunc(nvl(papf.effective_end_date
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               ,SYSDATE + 1))) requester_employee_num
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,SOURCE
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,terms_date
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,terms_name
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               --(SELECT AT1.NAME
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 --                                                                                                                                                                                                                                 FROM AP_TERMS AT1
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     WHERE AT1.TERM_ID = AIA.TERMS_ID)TERMS_NAME  ,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         (SELECT email_address
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                FROM ap_supplier_sites_all assa
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                WHERE assa.vendor_site_id =
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      aia.vendor_site_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                AND assa.inactive_date IS NULL) vendor_email_address
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,vendor_name
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,vendor_number
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,vendor_site_code
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,voucher_num
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        FROM ap_invoices_v aia
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        WHERE aia.org_id = l_org_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        AND aia.invoice_type_lookup_code = 'STANDARD'
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        AND aia.cancelled_date IS NULL
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        AND nvl(aia.invoice_amount
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,0) > 0
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        AND (nvl(aia.amount_paid
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               ,0) + nvl(aia.discount_amount_taken
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      ,0)) <> aia.invoice_amount
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        AND (nvl(aia.amount_paid
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               ,0) + nvl(aia.discount_amount_taken
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      ,0)) > 0
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        AND ap_invoices_pkg.get_approval_status(aia.invoice_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,aia.invoice_amount
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,aia.payment_status_flag
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,aia.invoice_type_lookup_code) =
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              'APPROVED'*/
            
            -- UNION
            
            --QUERY FOR  Paid/Partiall Paid PREPAY INVOICE HEADER
            /*  SELECT (SELECT concatenated_segments
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                FROM gl_code_combinations_kfv gcck
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                WHERE gcck.code_combination_id =
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      aia.accts_pay_code_combination_id) accts_pay_code_concatenated
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,(SELECT segment1
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                FROM gl_code_combinations_kfv gcck
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                WHERE gcck.code_combination_id =
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      aia.accts_pay_code_combination_id) accts_pay_code_segment1
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,(SELECT segment2
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                FROM gl_code_combinations_kfv gcck
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                WHERE gcck.code_combination_id =
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      aia.accts_pay_code_combination_id) accts_pay_code_segment2
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,(SELECT segment3
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                FROM gl_code_combinations_kfv gcck
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                WHERE gcck.code_combination_id =
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      aia.accts_pay_code_combination_id) accts_pay_code_segment3
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,(SELECT segment5
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                FROM gl_code_combinations_kfv gcck
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                WHERE gcck.code_combination_id =
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      aia.accts_pay_code_combination_id) accts_pay_code_segment5
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,(SELECT segment6
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                FROM gl_code_combinations_kfv gcck
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                WHERE gcck.code_combination_id =
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      aia.accts_pay_code_combination_id) accts_pay_code_segment6
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,(SELECT segment7
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                FROM gl_code_combinations_kfv gcck
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                WHERE gcck.code_combination_id =
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      aia.accts_pay_code_combination_id) accts_pay_code_segment7
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,(SELECT segment10
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                FROM gl_code_combinations_kfv gcck
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                WHERE gcck.code_combination_id =
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      aia.accts_pay_code_combination_id) accts_pay_code_segment10
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,amount_applicable_to_discount
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,attribute1
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,attribute2
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,attribute3
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,attribute4
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,attribute5
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,attribute6
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,attribute7
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,attribute8
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,attribute9
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,attribute10
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,attribute11
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,attribute12
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,attribute13
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,attribute14
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,attribute15
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,attribute_category
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,bank_charge_bearer
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,control_amount
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,cust_registration_code
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,cust_registration_number
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,delivery_channel_code
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,description
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,dispute_reason
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,doc_category_code
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,exchange_date
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,exchange_rate
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,exchange_rate_type
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,global_attribute1
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,global_attribute2
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,global_attribute3
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,global_attribute4
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,global_attribute5
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,global_attribute6
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,global_attribute7
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,global_attribute8
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,global_attribute9
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,global_attribute10
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,global_attribute11
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,global_attribute12
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,global_attribute13
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,global_attribute14
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,global_attribute15
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,global_attribute16
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,global_attribute17
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,global_attribute18
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,global_attribute19
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,global_attribute20
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,global_attribute_category
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,gl_date
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,goods_received_date
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         --       (INVOICE_AMOUNT - NVL(AMOUNT_PAID, 0))
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               nvl((SELECT SUM(aida.prepay_amount_remaining)
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   FROM ap_invoice_lines_all         aila
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       ,ap_invoice_distributions_all aida
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   WHERE aia.invoice_id =
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         aila.invoice_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   AND aila.invoice_id =
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         aida.invoice_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   AND aila.line_number =
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         aida.invoice_line_number)
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  ,aia.amount_paid) invoice_amount
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,invoice_currency_code
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,invoice_date
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,invoice_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,invoice_num
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,invoice_received_date
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,invoice_type_lookup_code
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,(SELECT legal_entity_name
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                FROM xle_le_ou_ledger_v
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                WHERE legal_entity_id = aia.legal_entity_id) legal_entity_name
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,set_of_books_name
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           --  (SELECT NAME FROM GL_LEDGERS
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             --                                                                                                                                                                                                                                    WHERE LEDGER_ID=AIA.SET_OF_BOOKS_ID) SET_OF_BOOKS_NAME, 
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             net_of_retainage_flag
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,(SELECT NAME
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                FROM hr_operating_units hou
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                WHERE hou.organization_id = aia.org_id) operating_unit
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,original_invoice_amount
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,payment_currency_code
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,payment_method_code
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               --PAYMENT_METHOD_LOOKUP_CODE  ,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               payment_reason_code
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,payment_reason_comments
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,pay_group_lookup_code
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,port_of_entry_code
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,po_number
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              --(SELECT SEGMENT1 FROM PO_HEADERS_ALL PHA
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          --                                                                                                                                                                                                                                       WHERE PHA.PO_HEADER_ID=AIA.QUICK_PO_HEADER_ID)PO_NUMBER  ,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            product_table
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,(SELECT employee_number
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                FROM per_all_people_f papf
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                WHERE papf.person_id = aia.requester_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                AND trunc(SYSDATE) BETWEEN
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      trunc(nvl(papf.effective_start_date
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            ,SYSDATE)) AND
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      trunc(nvl(papf.effective_end_date
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               ,SYSDATE + 1))) requester_employee_num
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,SOURCE
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,terms_date
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,terms_name
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               --(SELECT AT1.NAME
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             --                                                                                                                                                                                                                                     FROM AP_TERMS AT1
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     WHERE AT1.TERM_ID = AIA.TERMS_ID)TERMS_NAME  ,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             (SELECT email_address
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                FROM ap_supplier_sites_all assa
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                WHERE assa.vendor_site_id =
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      aia.vendor_site_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                AND assa.inactive_date IS NULL) vendor_email_address
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,vendor_name
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,vendor_number
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,vendor_site_code
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,voucher_num
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        FROM ap_invoices_v aia
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        WHERE aia.org_id = l_org_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        AND aia.invoice_type_lookup_code = 'PREPAYMENT'
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        AND aia.cancelled_date IS NULL
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        AND nvl(aia.invoice_amount
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,0) > 0
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        AND nvl(aia.amount_paid
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,0) > 0
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        AND nvl((SELECT SUM(aida.prepay_amount_remaining)
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               FROM ap_invoice_lines_all         aila
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   ,ap_invoice_distributions_all aida
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               WHERE aia.invoice_id = aila.invoice_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               AND aila.invoice_id = aida.invoice_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               AND aila.line_number = aida.invoice_line_number)
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,aia.amount_paid) > 0
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        AND ap_invoices_pkg.get_approval_status(aia.invoice_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,aia.invoice_amount
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,aia.payment_status_flag
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,aia.invoice_type_lookup_code) =
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              'AVAILABLE')*/
            
            
            UNION
            -- Query to pick up unpaid/ partially Paid Prepayments 
            SELECT (SELECT concatenated_segments
                    FROM gl_code_combinations_kfv gcck
                    WHERE gcck.code_combination_id =
                          aia.accts_pay_code_combination_id) accts_pay_code_concatenated
                  ,(SELECT segment1
                    FROM gl_code_combinations_kfv gcck
                    WHERE gcck.code_combination_id =
                          aia.accts_pay_code_combination_id) accts_pay_code_segment1
                  ,(SELECT segment2
                    FROM gl_code_combinations_kfv gcck
                    WHERE gcck.code_combination_id =
                          aia.accts_pay_code_combination_id) accts_pay_code_segment2
                  ,(SELECT segment3
                    FROM gl_code_combinations_kfv gcck
                    WHERE gcck.code_combination_id =
                          aia.accts_pay_code_combination_id) accts_pay_code_segment3
                  ,(SELECT segment5
                    FROM gl_code_combinations_kfv gcck
                    WHERE gcck.code_combination_id =
                          aia.accts_pay_code_combination_id) accts_pay_code_segment5
                  ,(SELECT segment6
                    FROM gl_code_combinations_kfv gcck
                    WHERE gcck.code_combination_id =
                          aia.accts_pay_code_combination_id) accts_pay_code_segment6
                  ,(SELECT segment7
                    FROM gl_code_combinations_kfv gcck
                    WHERE gcck.code_combination_id =
                          aia.accts_pay_code_combination_id) accts_pay_code_segment7
                  ,(SELECT segment10
                    FROM gl_code_combinations_kfv gcck
                    WHERE gcck.code_combination_id =
                          aia.accts_pay_code_combination_id) accts_pay_code_segment10
                  ,amount_applicable_to_discount
                  ,attribute1
                  ,attribute2
                  ,attribute3
                  ,attribute4
                  ,attribute5
                  ,attribute6
                  ,attribute7
                  ,attribute8
                  ,attribute9
                  ,attribute10
                  ,attribute11
                  ,attribute12
                  ,attribute13
                  ,attribute14
                  ,attribute15
                  ,attribute_category
                  ,bank_charge_bearer
                  ,control_amount
                  ,cust_registration_code
                  ,cust_registration_number
                  ,delivery_channel_code
                  ,description
                  ,dispute_reason
                  ,doc_category_code
                  ,exchange_date
                  ,exchange_rate
                  ,exchange_rate_type
                  ,global_attribute1
                  ,global_attribute2
                  ,global_attribute3
                  ,global_attribute4
                  ,global_attribute5
                  ,global_attribute6
                  ,global_attribute7
                  ,global_attribute8
                  ,global_attribute9
                  ,global_attribute10
                  ,global_attribute11
                  ,global_attribute12
                  ,global_attribute13
                  ,global_attribute14
                  ,global_attribute15
                  ,global_attribute16
                  ,global_attribute17
                  ,global_attribute18
                  ,global_attribute19
                  ,global_attribute20
                  ,global_attribute_category
                  ,gl_date
                  ,goods_received_date
                  ,
                   /* (INVOICE_AMOUNT - NVL(AMOUNT_PAID, 0))*/nvl((SELECT SUM(aida.prepay_amount_remaining)
                       FROM ap_invoice_lines_all         aila
                           ,ap_invoice_distributions_all aida
                       WHERE aia.invoice_id =
                             aila.invoice_id
                       AND aila.invoice_id =
                             aida.invoice_id
                       AND aila.line_number =
                             aida.invoice_line_number)
                      ,aia.amount_paid) invoice_amount
                  ,invoice_currency_code
                  ,invoice_date
                  ,invoice_id
                  ,invoice_num
                  ,invoice_received_date
                  ,invoice_type_lookup_code
                  ,(SELECT legal_entity_name
                    FROM xle_le_ou_ledger_v
                    WHERE legal_entity_id = aia.legal_entity_id) legal_entity_name
                  ,set_of_books_name
                  ,
                   /*(SELECT NAME FROM GL_LEDGERS
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                WHERE LEDGER_ID=AIA.SET_OF_BOOKS_ID) SET_OF_BOOKS_NAME, */net_of_retainage_flag
                  ,(SELECT NAME
                    FROM hr_operating_units hou
                    WHERE hou.organization_id = aia.org_id) operating_unit
                  ,original_invoice_amount
                  ,payment_currency_code
                  ,payment_method_code
                  ,
                   --PAYMENT_METHOD_LOOKUP_CODE  ,
                   payment_reason_code
                  ,payment_reason_comments
                  ,pay_group_lookup_code
                  ,port_of_entry_code
                  ,po_number
                  ,
                   /* (SELECT SEGMENT1 FROM PO_HEADERS_ALL PHA
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                WHERE PHA.PO_HEADER_ID=AIA.QUICK_PO_HEADER_ID)PO_NUMBER  ,*/product_table
                  ,(SELECT employee_number
                    FROM per_all_people_f papf
                    WHERE papf.person_id = aia.requester_id
                    AND trunc(SYSDATE) BETWEEN
                          trunc(nvl(papf.effective_start_date
                                ,SYSDATE)) AND
                          trunc(nvl(papf.effective_end_date
                                   ,SYSDATE + 1))) requester_employee_num
                  ,SOURCE
                  ,terms_date
                  ,terms_name
                  ,
                   /*(SELECT AT1.NAME
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 FROM AP_TERMS AT1
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    WHERE AT1.TERM_ID = AIA.TERMS_ID)TERMS_NAME  ,*/(SELECT email_address
                    FROM ap_supplier_sites_all assa
                    WHERE assa.vendor_site_id =
                          aia.vendor_site_id
                    AND assa.inactive_date IS NULL) vendor_email_address
                  ,vendor_name
                  ,vendor_number
                  ,vendor_site_code
                  ,voucher_num
            FROM ap_invoices_v aia
            WHERE aia.org_id = 737
            AND aia.invoice_type_lookup_code = 'PREPAYMENT'
            AND aia.cancelled_date IS NULL
            AND nvl(aia.invoice_amount
                  ,0) > 0
            AND nvl(aia.amount_paid
                  ,0) > 0
            AND nvl((SELECT SUM(aida.prepay_amount_remaining)
                   FROM ap_invoice_lines_all         aila
                       ,ap_invoice_distributions_all aida
                   WHERE aia.invoice_id = aila.invoice_id
                   AND aila.invoice_id = aida.invoice_id
                   AND aila.line_number = aida.invoice_line_number)
                  ,0) > 0
            AND ap_invoices_pkg.get_approval_status(aia.invoice_id
                                                  ,aia.invoice_amount
                                                  ,aia.payment_status_flag
                                                  ,aia.invoice_type_lookup_code) =
                  'AVAILABLE')
      ORDER BY invoice_num;
  
    CURSOR c_data IS
      SELECT * --MATCH_OPTION,RECEIPT_REQUIRED_FLAG_SHIP
      FROM xxobjt.xxs3_ptp_invoice;
    /* CURSOR c_transform IS
    SELECT *
    FROM   xxobjt.xxs3_ptp_invoice; \*
            WHERE process_flag IN ('Q','Y');*\*/
  
    /* CURSOR c_header_utl_upload IS
    SELECT *
    FROM   xxobjt.xxs3_ptp_invoice;*/
  
    l_err_code     VARCHAR2(4000);
    l_err_msg      VARCHAR2(4000);
    l_s3_gl_string VARCHAR2(2000);
  
  BEGIN
  
    x_retcode := 0;
    x_errbuf  := 'COMPLETE';
    l_file    := utl_file.fopen('/UtlFiles/shared/DEV'
                               ,'INV_HEADER_DATA' || '_' || SYSDATE ||
                                '.xls'
                               ,'w'
                               ,32767);
    --mo_global.init('PO');
    mo_global.set_policy_context('S'
                                ,l_org_id);
  
    EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.xxs3_ptp_invoice';
  
    FOR i IN c_invoice_extract
    LOOP
    
      --fnd_file.put_line(fnd_file.log, 'Segment1 :'||i.segment1);
    
      INSERT INTO xxobjt.xxs3_ptp_invoice
      VALUES
        (xxs3_ptp_invoice_seq.NEXTVAL
        ,SYSDATE
        ,'N'
        ,NULL
        ,NULL
        ,i.invoice_id
        ,i.accts_pay_code_concatenated
        ,i.accts_pay_code_segment1
        ,i.accts_pay_code_segment2
        ,i.accts_pay_code_segment3
        ,i.accts_pay_code_segment5
        ,i.accts_pay_code_segment6
        ,i.accts_pay_code_segment7
        ,i.accts_pay_code_segment10
        ,NULL
        ,NULL
        ,NULL
        ,NULL
        ,NULL
        ,NULL
        ,NULL
        ,NULL
        ,i.amount_applicable_to_discount
        ,i.attribute1
        ,i.attribute2
        ,i.attribute3
        ,i.attribute4
        ,i.attribute5
        ,i.attribute6
        ,i.attribute7
        ,i.attribute8
        ,i.attribute9
        ,i.attribute10
        ,i.attribute11
        ,i.attribute12
        ,i.attribute13
        ,i.attribute14
        ,i.attribute15
        ,i.attribute_category
        ,i.bank_charge_bearer
        ,i.control_amount
        ,i.cust_registration_code
        ,i.cust_registration_number
        ,i.delivery_channel_code
        ,i.description
        ,i.dispute_reason
        ,i.doc_category_code
        ,i.exchange_date
        ,i.exchange_rate
        ,i.exchange_rate_type
        ,i.global_attribute1
        ,i.global_attribute2
        ,i.global_attribute3
        ,i.global_attribute4
        ,i.global_attribute5
        ,i.global_attribute6
        ,i.global_attribute7
        ,i.global_attribute8
        ,i.global_attribute9
        ,i.global_attribute10
        ,i.global_attribute11
        ,i.global_attribute12
        ,i.global_attribute13
        ,i.global_attribute14
        ,i.global_attribute15
        ,i.global_attribute16
        ,i.global_attribute17
        ,i.global_attribute18
        ,i.global_attribute19
        ,i.global_attribute20
        ,i.global_attribute_category
        ,i.gl_date
        ,i.goods_received_date
        ,i.invoice_amount
        ,i.invoice_currency_code
        ,i.invoice_date
        ,i.invoice_num
        ,i.invoice_received_date
        ,i.invoice_type_lookup_code
        ,i.legal_entity_name
        ,NULL
        ,i.set_of_books_name
        ,NULL
        ,i.net_of_retainage_flag
        ,i.operating_unit
        ,NULL
        ,i.original_invoice_amount
        ,i.payment_currency_code
        ,i.payment_method_code
        ,NULL
        ,NULL
        ,
         --i.PAYMENT_METHOD_LOOKUP_CODE  ,  
         i.payment_reason_code
        ,i.payment_reason_comments
        ,i.pay_group_lookup_code
        ,i.port_of_entry_code
        ,i.po_number
        ,i.product_table
        ,i.requester_employee_num
        ,i.SOURCE
        ,i.terms_date
        ,i.terms_name
        ,NULL
        ,i.vendor_email_address
        ,i.vendor_name
        ,i.vendor_number
        ,i.vendor_site_code
        ,i.voucher_num
        ,NULL
        ,NULL
        ,NULL
        ,NULL);
    
    END LOOP;
    COMMIT;
  
    fnd_file.put_line(fnd_file.log
                     ,'Loading complete');
  
    --Transformation
    FOR m IN c_data
    LOOP
      --set of books transformation
      IF m.set_of_books_name IS NOT NULL
      THEN
        l_step := 'Transform set_of_books_name';
        xxs3_data_transform_util_pkg.transform(p_mapping_type => 'SET_OF_BOOKS'
                                              ,p_stage_tab => 'XXS3_PTP_INVOICE'
                                              , --Staging Table Name
                                               p_stage_primary_col => 'XX_INVOICE_ID'
                                              , --Staging Table Primary Column Name
                                               p_stage_primary_col_val => m.xx_invoice_id
                                              , --Staging Table Primary Column Value
                                               p_legacy_val => m.set_of_books_name
                                              , --Legacy Value
                                               p_stage_col => 'S3_SET_OF_BOOKS_NAME'
                                              , --Staging Table Name
                                               p_err_code => l_err_code
                                              , -- Output error code
                                               p_err_msg => l_err_msg);
      END IF;
      --terms transformation
      --IF m.terms_name IS NOT NULL THEN    
      l_step := 'Transform terms_name';
      xxs3_data_transform_util_pkg.transform(p_mapping_type => 'payment_terms_ptp'
                                            ,p_stage_tab => 'XXS3_PTP_INVOICE'
                                            , --Staging Table Name
                                             p_stage_primary_col => 'XX_INVOICE_ID'
                                            , --Staging Table Primary Column Name
                                             p_stage_primary_col_val => m.xx_invoice_id
                                            , --Staging Table Primary Column Value
                                             p_legacy_val => m.terms_name
                                            , --Legacy Value
                                             p_stage_col => 'S3_TERMS_NAME'
                                            , --Staging Table Name
                                             p_err_code => l_err_code
                                            , -- Output error code
                                             p_err_msg => l_err_msg);
      --END IF;   
      --ou transformation                                       
      IF m.operating_unit IS NOT NULL
      THEN
        l_step := 'Transform operating_unit';
        xxs3_data_transform_util_pkg.transform(p_mapping_type => 'organization_name'
                                              ,p_stage_tab => 'XXS3_PTP_INVOICE'
                                              , --Staging Table Name
                                               p_stage_primary_col => 'XX_INVOICE_ID'
                                              , --Staging Table Primary Column Name
                                               p_stage_primary_col_val => m.xx_invoice_id
                                              , --Staging Table Primary Column Value
                                               p_legacy_val => m.operating_unit
                                              , --Legacy Value
                                               p_stage_col => 'S3_OPERATING_UNIT'
                                              , --Staging Table Name
                                               p_err_code => l_err_code
                                              , -- Output error code
                                               p_err_msg => l_err_msg);
      END IF;
      --legal_entity transformation                                               
      IF m.legal_entity_name IS NOT NULL
      THEN
        l_step := 'Transform legal_entity_name';
        xxs3_data_transform_util_pkg.transform(p_mapping_type => 'LEGAL_ENTITY_NAME'
                                              ,p_stage_tab => 'XXS3_PTP_INVOICE'
                                              , --Staging Table Name
                                               p_stage_primary_col => 'XX_INVOICE_ID'
                                              , --Staging Table Primary Column Name
                                               p_stage_primary_col_val => m.xx_invoice_id
                                              , --Staging Table Primary Column Value
                                               p_legacy_val => m.legal_entity_name
                                              , --Legacy Value
                                               p_stage_col => 'S3_LEGAL_ENTITY_NAME'
                                              , --Staging Table Name
                                               p_err_code => l_err_code
                                              , -- Output error code
                                               p_err_msg => l_err_msg);
      END IF;
    
      IF m.payment_method_code IS NOT NULL
      THEN
        l_step := 'Transform payment_method_code';
        xxs3_data_transform_util_pkg.transform(p_mapping_type => 'payment_method_code'
                                              ,p_stage_tab => 'XXS3_PTP_INVOICE'
                                              , --Staging Table Name
                                               p_stage_primary_col => 'XX_INVOICE_ID'
                                              , --Staging Table Primary Column Name
                                               p_stage_primary_col_val => m.xx_invoice_id
                                              , --Staging Table Primary Column Value
                                               p_legacy_val => m.payment_method_code
                                              , --Legacy Value
                                               p_stage_col => 'S3_PAYMENT_METHOD_CODE'
                                              , --Staging Table Name
                                               p_err_code => l_err_code
                                              , -- Output error code
                                               p_err_msg => l_err_msg);
      END IF;
      --CoA transformation     
    
      IF m.accts_pay_code_concatenated IS NOT NULL
      THEN
        /*   xxs3_data_transform_util_pkg.coa_transform(p_field_name => 'ACCTS_PAY_CODE_CONCATENATED'
                                                  ,p_legacy_company_val => m.accts_pay_code_segment1
                                                  , --legacy company value
                                                   p_legacy_department_val => m.accts_pay_code_segment2
                                                  , --legacy department value
                                                   p_legacy_account_val => m.accts_pay_code_segment3
                                                  , --legacy account value
                                                   p_legacy_product_val => m.accts_pay_code_segment5
                                                  , --legacy product value
                                                   p_legacy_location_val => m.accts_pay_code_segment6
                                                  , --legacy location value
                                                   p_legacy_intercompany_val => m.accts_pay_code_segment7
                                                  , --legacy intercompany value
                                                   p_legacy_division_val => m.accts_pay_code_segment10
                                                  , --Legacy Division Value
                                                   p_item_number => NULL
                                                  ,p_s3_gl_string => l_s3_gl_string
                                                  ,p_err_code => l_output_code
                                                  ,p_err_msg => l_output); --Output Message   
        
        xxs3_data_transform_util_pkg.coa_update(p_gl_string => l_s3_gl_string
                                               ,p_stage_tab => 'XXS3_PTP_INVOICE'
                                               ,p_stage_primary_col => 'XX_INVOICE_ID'
                                               ,p_stage_primary_col_val => m.xx_invoice_id
                                               ,p_stage_company_col => 'S3_ACCTS_PAY_CODE_SEGMENT1'
                                               ,p_stage_business_unit_col => 'S3_ACCTS_PAY_CODE_SEGMENT2'
                                               ,p_stage_department_col => 'S3_ACCTS_PAY_CODE_SEGMENT3'
                                               ,p_stage_account_col => 'S3_ACCTS_PAY_CODE_SEGMENT4'
                                               ,p_stage_product_line_col => 'S3_ACCTS_PAY_CODE_SEGMENT5'
                                               ,p_stage_location_col => 'S3_ACCTS_PAY_CODE_SEGMENT6'
                                               ,p_stage_intercompany_col => 'S3_ACCTS_PAY_CODE_SEGMENT7'
                                               ,p_stage_future_col => 'S3_ACCTS_PAY_CODE_SEGMENT8'
                                               ,p_coa_err_msg => l_output
                                               ,p_err_code => l_output_code_coa_update
                                               ,p_err_msg => l_output_coa_update);*/
      
      
        xxs3_coa_transform_pkg.coa_transform(p_field_name => 'ACCTS_PAY_CODE_CONCATENATED'
                                            ,p_legacy_company_val => m.accts_pay_code_segment1 --Legacy Company Value
                                            ,p_legacy_department_val => m.accts_pay_code_segment2 --Legacy Department Value
                                            ,p_legacy_account_val => m.accts_pay_code_segment3 --Legacy Account Value
                                            ,p_legacy_product_val => m.accts_pay_code_segment5 --Legacy Product Value
                                            ,p_legacy_location_val => m.accts_pay_code_segment6 --Legacy Location Value
                                            ,p_legacy_intercompany_val => m.accts_pay_code_segment7 --Legacy Intercompany Value
                                            ,p_legacy_division_val => m.accts_pay_code_segment10 --Legacy Division Value
                                            ,p_item_number => NULL
                                            ,p_s3_org => NULL
                                            ,p_trx_type => 'ALL'
                                            ,p_set_of_books_id => NULL
                                            ,p_debug_flag => 'N'
                                            ,p_s3_gl_string => l_s3_gl_string
                                            ,p_err_code => l_output_code
                                            ,p_err_msg => l_output);
      
      
      
        xxs3_coa_transform_pkg.coa_update(p_gl_string => l_s3_gl_string
                                         ,p_stage_tab => 'XXS3_PTP_INVOICE'
                                         ,p_stage_primary_col => 'XX_INVOICE_ID'
                                         ,p_stage_primary_col_val => m.xx_invoice_id
                                         ,p_stage_company_col => 'S3_ACCTS_PAY_CODE_SEGMENT1'
                                         ,p_stage_business_unit_col => 'S3_ACCTS_PAY_CODE_SEGMENT2'
                                         ,p_stage_department_col => 'S3_ACCTS_PAY_CODE_SEGMENT3'
                                         ,p_stage_account_col => 'S3_ACCTS_PAY_CODE_SEGMENT4'
                                         ,p_stage_product_line_col => 'S3_ACCTS_PAY_CODE_SEGMENT5'
                                         ,p_stage_location_col => 'S3_ACCTS_PAY_CODE_SEGMENT6'
                                         ,p_stage_intercompany_col => 'S3_ACCTS_PAY_CODE_SEGMENT7'
                                         ,p_stage_future_col => 'S3_ACCTS_PAY_CODE_SEGMENT8'
                                         ,p_coa_err_msg => l_output
                                         ,p_err_code => l_output_code_coa_update
                                         ,p_err_msg => l_output_coa_update);
      
      
      END IF;
    
    END LOOP;
  
  
    -- Writing in UTL File
    utl_file.put(l_file
                ,'~' || 'XX_INVOICE_ID');
    utl_file.put(l_file
                ,'~' || 'DATE_EXTRACTED_ON');
    utl_file.put(l_file
                ,'~' || 'PROCESS_FLAG');
    utl_file.put(l_file
                ,'~' || 'OPERATING_UNIT');
    utl_file.put(l_file
                ,'~' || 'S3_OPERATING_UNIT');
    utl_file.put(l_file
                ,'~' || 'INVOICE_TYPE_LOOKUP_CODE');
    utl_file.put(l_file
                ,'~' || 'INVOICE_NUM');
    utl_file.put(l_file
                ,'~' || 'INVOICE_ID');
    utl_file.put(l_file
                ,'~' || 'S3_INVOICE_ID');
    utl_file.put(l_file
                ,'~' || 'INVOICE_DATE');
    utl_file.put(l_file
                ,'~' || 'GL_DATE');
    utl_file.put(l_file
                ,'~' || 'SOURCE');
    utl_file.put(l_file
                ,'~' || 'ORIGINAL_INVOICE_AMOUNT');
    utl_file.put(l_file
                ,'~' || 'INVOICE_AMOUNT');
    utl_file.put(l_file
                ,'~' || 'AMOUNT_APPLICABLE_TO_DISCOUNT');
    utl_file.put(l_file
                ,'~' || 'INVOICE_CURRENCY_CODE');
    utl_file.put(l_file
                ,'~' || 'VENDOR_NAME');
    utl_file.put(l_file
                ,'~' || 'VENDOR_NUM');
    utl_file.put(l_file
                ,'~' || 'VENDOR_SITE_CODE');
    utl_file.put(l_file
                ,'~' || 'VENDOR_EMAIL_ADDRESS');
    utl_file.put(l_file
                ,'~' || 'PAYMENT_CURRENCY_CODE');
    utl_file.put(l_file
                ,'~' || 'PAYMENT_METHOD_CODE');
    utl_file.put(l_file
                ,'~' || 'PAYMENT_METHOD_LOOKUP_CODE');
    utl_file.put(l_file
                ,'~' || 'PAYMENT_REASON_CODE');
    utl_file.put(l_file
                ,'~' || 'PAYMENT_REASON_COMMENTS');
    utl_file.put(l_file
                ,'~' || 'PAY_GROUP_LOOKUP_CODE');
    utl_file.put(l_file
                ,'~' || 'VOUCHER_NUM');
    utl_file.put(l_file
                ,'~' || 'PO_NUMBER');
    utl_file.put(l_file
                ,'~' || 'PRODUCT_TABLE');
    utl_file.put(l_file
                ,'~' || 'REQUESTER_EMPLOYEE_NUM');
    utl_file.put(l_file
                ,'~' || 'TERMS_DATE');
    utl_file.put(l_file
                ,'~' || 'TERMS_NAME');
    utl_file.put(l_file
                ,'~' || 'S3_TERMS_NAME');
    utl_file.put(l_file
                ,'~' || 'LEGAL_ENTITY_NAME');
    utl_file.put(l_file
                ,'~' || 'S3_LEGAL_ENTITY_NAME');
    utl_file.put(l_file
                ,'~' || 'SET_OF_BOOKS_NAME');
    utl_file.put(l_file
                ,'~' || 'S3_SET_OF_BOOKS_NAME');
    utl_file.put(l_file
                ,'~' || 'GOODS_RECEIVED_DATE');
    utl_file.put(l_file
                ,'~' || 'INVOICE_RECEIVED_DATE');
    utl_file.put(l_file
                ,'~' || 'NET_OF_RETAINAGE_FLAG');
    utl_file.put(l_file
                ,'~' || 'NOTES');
    utl_file.put(l_file
                ,'~' || 'ACCTS_PAY_CODE_CONCATENATED');
    utl_file.put(l_file
                ,'~' || 'ACCTS_PAY_CODE_SEGMENT1');
    utl_file.put(l_file
                ,'~' || 'ACCTS_PAY_CODE_SEGMENT2');
    utl_file.put(l_file
                ,'~' || 'ACCTS_PAY_CODE_SEGMENT3');
    utl_file.put(l_file
                ,'~' || 'ACCTS_PAY_CODE_SEGMENT5');
    utl_file.put(l_file
                ,'~' || 'ACCTS_PAY_CODE_SEGMENT6');
    utl_file.put(l_file
                ,'~' || 'ACCTS_PAY_CODE_SEGMENT7');
    utl_file.put(l_file
                ,'~' || 'ACCTS_PAY_CODE_SEGMENT10');
    utl_file.put(l_file
                ,'~' || 'S3_ACCTS_PAY_CODE_SEGMENT1');
    utl_file.put(l_file
                ,'~' || 'S3_ACCTS_PAY_CODE_SEGMENT2');
    utl_file.put(l_file
                ,'~' || 'S3_ACCTS_PAY_CODE_SEGMENT3');
    utl_file.put(l_file
                ,'~' || 'S3_ACCTS_PAY_CODE_SEGMENT4');
    utl_file.put(l_file
                ,'~' || 'S3_ACCTS_PAY_CODE_SEGMENT5');
    utl_file.put(l_file
                ,'~' || 'S3_ACCTS_PAY_CODE_SEGMENT6');
    utl_file.put(l_file
                ,'~' || 'S3_ACCTS_PAY_CODE_SEGMENT7');
    utl_file.put(l_file
                ,'~' || 'S3_ACCTS_PAY_CODE_SEGMENT8');
    utl_file.put(l_file
                ,'~' || 'ATTRIBUTE1_HDR');
    utl_file.put(l_file
                ,'~' || 'ATTRIBUTE2_HDR');
    utl_file.put(l_file
                ,'~' || 'ATTRIBUTE3_HDR');
    utl_file.put(l_file
                ,'~' || 'ATTRIBUTE4_HDR');
    utl_file.put(l_file
                ,'~' || 'ATTRIBUTE5_HDR');
    utl_file.put(l_file
                ,'~' || 'ATTRIBUTE6_HDR');
    utl_file.put(l_file
                ,'~' || 'ATTRIBUTE7_HDR');
    utl_file.put(l_file
                ,'~' || 'ATTRIBUTE8_HDR');
    utl_file.put(l_file
                ,'~' || 'ATTRIBUTE9_HDR');
    utl_file.put(l_file
                ,'~' || 'ATTRIBUTE10_HDR');
    utl_file.put(l_file
                ,'~' || 'ATTRIBUTE11_HDR');
    utl_file.put(l_file
                ,'~' || 'ATTRIBUTE12_HDR');
    utl_file.put(l_file
                ,'~' || 'ATTRIBUTE13_HDR');
    utl_file.put(l_file
                ,'~' || 'ATTRIBUTE14_HDR');
    utl_file.put(l_file
                ,'~' || 'ATTRIBUTE15_HDR');
    utl_file.put(l_file
                ,'~' || 'ATTRIBUTE_CATEGORY_HDR');
    utl_file.put(l_file
                ,'~' || 'BANK_CHARGE_BEARER');
    utl_file.put(l_file
                ,'~' || 'CONTROL_AMOUNT');
    utl_file.put(l_file
                ,'~' || 'CUST_REGISTRATION_CODE');
    utl_file.put(l_file
                ,'~' || 'CUST_REGISTRATION_NUMBER');
    utl_file.put(l_file
                ,'~' || 'DELIVERY_CHANNEL_CODE');
    utl_file.put(l_file
                ,'~' || 'DESCRIPTION');
    utl_file.put(l_file
                ,'~' || 'DISPUTE_REASON');
    utl_file.put(l_file
                ,'~' || 'DOC_CATEGORY_CODE');
    utl_file.put(l_file
                ,'~' || 'EXCHANGE_DATE');
    utl_file.put(l_file
                ,'~' || 'EXCHANGE_RATE');
    utl_file.put(l_file
                ,'~' || 'EXCHANGE_RATE_TYPE');
    utl_file.put(l_file
                ,'~' || 'GLOBAL_ATTRIBUTE1');
    utl_file.put(l_file
                ,'~' || 'GLOBAL_ATTRIBUTE2');
    utl_file.put(l_file
                ,'~' || 'GLOBAL_ATTRIBUTE3');
    utl_file.put(l_file
                ,'~' || 'GLOBAL_ATTRIBUTE4');
    utl_file.put(l_file
                ,'~' || 'GLOBAL_ATTRIBUTE5');
    utl_file.put(l_file
                ,'~' || 'GLOBAL_ATTRIBUTE6');
    utl_file.put(l_file
                ,'~' || 'GLOBAL_ATTRIBUTE7');
    utl_file.put(l_file
                ,'~' || 'GLOBAL_ATTRIBUTE8');
    utl_file.put(l_file
                ,'~' || 'GLOBAL_ATTRIBUTE9');
    utl_file.put(l_file
                ,'~' || 'GLOBAL_ATTRIBUTE10');
    utl_file.put(l_file
                ,'~' || 'GLOBAL_ATTRIBUTE11');
    utl_file.put(l_file
                ,'~' || 'GLOBAL_ATTRIBUTE12');
    utl_file.put(l_file
                ,'~' || 'GLOBAL_ATTRIBUTE13');
    utl_file.put(l_file
                ,'~' || 'GLOBAL_ATTRIBUTE14');
    utl_file.put(l_file
                ,'~' || 'GLOBAL_ATTRIBUTE15');
    utl_file.put(l_file
                ,'~' || 'GLOBAL_ATTRIBUTE16');
    utl_file.put(l_file
                ,'~' || 'GLOBAL_ATTRIBUTE17');
    utl_file.put(l_file
                ,'~' || 'GLOBAL_ATTRIBUTE18');
    utl_file.put(l_file
                ,'~' || 'GLOBAL_ATTRIBUTE19');
    utl_file.put(l_file
                ,'~' || 'GLOBAL_ATTRIBUTE20');
    utl_file.put(l_file
                ,'~' || 'GLOBAL_ATTRIBUTE_CATEGORY');
    utl_file.put(l_file
                ,'~' || 'PORT_OF_ENTRY_CODE');
    utl_file.put(l_file
                ,'~' || 'TRANSFORM_STATUS');
    utl_file.put(l_file
                ,'~' || 'TRANSFORM_ERROR');
    utl_file.new_line(l_file);
  
  
    FOR c1 IN c_data
    LOOP
      utl_file.put(l_file
                  ,'~' || c1.xx_invoice_id);
      utl_file.put(l_file
                  ,'~' || c1.date_extracted_on);
      utl_file.put(l_file
                  ,'~' || c1.process_flag);
      utl_file.put(l_file
                  ,'~' || c1.operating_unit);
      utl_file.put(l_file
                  ,'~' || c1.s3_operating_unit);
      utl_file.put(l_file
                  ,'~' || c1.invoice_type_lookup_code);
      utl_file.put(l_file
                  ,'~' || c1.invoice_num);
      utl_file.put(l_file
                  ,'~' || c1.invoice_id);
      utl_file.put(l_file
                  ,'~' || c1.s3_invoice_id);
      utl_file.put(l_file
                  ,'~' || c1.invoice_date);
      utl_file.put(l_file
                  ,'~' || c1.gl_date);
      utl_file.put(l_file
                  ,'~' || c1.SOURCE);
      utl_file.put(l_file
                  ,'~' || c1.original_invoice_amount);
      utl_file.put(l_file
                  ,'~' || c1.invoice_amount);
      utl_file.put(l_file
                  ,'~' || c1.amount_applicable_to_discount);
      utl_file.put(l_file
                  ,'~' || c1.invoice_currency_code);
      utl_file.put(l_file
                  ,'~' || c1.vendor_name);
      utl_file.put(l_file
                  ,'~' || c1.vendor_num);
      utl_file.put(l_file
                  ,'~' || c1.vendor_site_code);
      utl_file.put(l_file
                  ,'~' || c1.vendor_email_address);
      utl_file.put(l_file
                  ,'~' || c1.payment_currency_code);
      utl_file.put(l_file
                  ,'~' || c1.payment_method_code);
      utl_file.put(l_file
                  ,'~' || c1.payment_method_lookup_code);
      utl_file.put(l_file
                  ,'~' || c1.payment_reason_code);
      utl_file.put(l_file
                  ,'~' || c1.payment_reason_comments);
      utl_file.put(l_file
                  ,'~' || c1.pay_group_lookup_code);
      utl_file.put(l_file
                  ,'~' || c1.voucher_num);
      utl_file.put(l_file
                  ,'~' || c1.po_number);
      utl_file.put(l_file
                  ,'~' || c1.product_table);
      utl_file.put(l_file
                  ,'~' || c1.requester_employee_num);
      utl_file.put(l_file
                  ,'~' || c1.terms_date);
      utl_file.put(l_file
                  ,'~' || c1.terms_name);
      utl_file.put(l_file
                  ,'~' || c1.s3_terms_name);
      utl_file.put(l_file
                  ,'~' || c1.legal_entity_name);
      utl_file.put(l_file
                  ,'~' || c1.s3_legal_entity_name);
      utl_file.put(l_file
                  ,'~' || c1.set_of_books_name);
      utl_file.put(l_file
                  ,'~' || c1.s3_set_of_books_name);
      utl_file.put(l_file
                  ,'~' || c1.goods_received_date);
      utl_file.put(l_file
                  ,'~' || c1.invoice_received_date);
      utl_file.put(l_file
                  ,'~' || c1.net_of_retainage_flag);
      utl_file.put(l_file
                  ,'~' || c1.notes);
      utl_file.put(l_file
                  ,'~' || c1.accts_pay_code_concatenated);
      utl_file.put(l_file
                  ,'~' || c1.accts_pay_code_segment1);
      utl_file.put(l_file
                  ,'~' || c1.accts_pay_code_segment2);
      utl_file.put(l_file
                  ,'~' || c1.accts_pay_code_segment3);
      utl_file.put(l_file
                  ,'~' || c1.accts_pay_code_segment5);
      utl_file.put(l_file
                  ,'~' || c1.accts_pay_code_segment6);
      utl_file.put(l_file
                  ,'~' || c1.accts_pay_code_segment7);
      utl_file.put(l_file
                  ,'~' || c1.accts_pay_code_segment10);
      utl_file.put(l_file
                  ,'~' || c1.s3_accts_pay_code_segment1);
      utl_file.put(l_file
                  ,'~' || c1.s3_accts_pay_code_segment2);
      utl_file.put(l_file
                  ,'~' || c1.s3_accts_pay_code_segment3);
      utl_file.put(l_file
                  ,'~' || c1.s3_accts_pay_code_segment4);
      utl_file.put(l_file
                  ,'~' || c1.s3_accts_pay_code_segment5);
      utl_file.put(l_file
                  ,'~' || c1.s3_accts_pay_code_segment6);
      utl_file.put(l_file
                  ,'~' || c1.s3_accts_pay_code_segment7);
      utl_file.put(l_file
                  ,'~' || c1.s3_accts_pay_code_segment8);
      utl_file.put(l_file
                  ,'~' || c1.attribute1_hdr);
      utl_file.put(l_file
                  ,'~' || c1.attribute2_hdr);
      utl_file.put(l_file
                  ,'~' || c1.attribute3_hdr);
      utl_file.put(l_file
                  ,'~' || c1.attribute4_hdr);
      utl_file.put(l_file
                  ,'~' || c1.attribute5_hdr);
      utl_file.put(l_file
                  ,'~' || c1.attribute6_hdr);
      utl_file.put(l_file
                  ,'~' || c1.attribute7_hdr);
      utl_file.put(l_file
                  ,'~' || c1.attribute8_hdr);
      utl_file.put(l_file
                  ,'~' || c1.attribute9_hdr);
      utl_file.put(l_file
                  ,'~' || c1.attribute10_hdr);
      utl_file.put(l_file
                  ,'~' || c1.attribute11_hdr);
      utl_file.put(l_file
                  ,'~' || c1.attribute12_hdr);
      utl_file.put(l_file
                  ,'~' || c1.attribute13_hdr);
      utl_file.put(l_file
                  ,'~' || c1.attribute14_hdr);
      utl_file.put(l_file
                  ,'~' || c1.attribute15_hdr);
      utl_file.put(l_file
                  ,'~' || c1.attribute_category_hdr);
      utl_file.put(l_file
                  ,'~' || c1.bank_charge_bearer);
      utl_file.put(l_file
                  ,'~' || c1.control_amount);
      utl_file.put(l_file
                  ,'~' || c1.cust_registration_code);
      utl_file.put(l_file
                  ,'~' || c1.cust_registration_number);
      utl_file.put(l_file
                  ,'~' || c1.delivery_channel_code);
      utl_file.put(l_file
                  ,'~' || (REPLACE(REPLACE(REPLACE(REPLACE(c1.description
                                                          ,','
                                                          ,' ')
                                                  ,'"'
                                                  ,' ')
                                          ,chr(10)
                                          ,' ')
                                  ,chr(13)
                                  ,' ')));
      utl_file.put(l_file
                  ,'~' || c1.dispute_reason);
      utl_file.put(l_file
                  ,'~' || c1.doc_category_code);
      utl_file.put(l_file
                  ,'~' || c1.exchange_date);
      utl_file.put(l_file
                  ,'~' || c1.exchange_rate);
      utl_file.put(l_file
                  ,'~' || c1.exchange_rate_type);
      utl_file.put(l_file
                  ,'~' || c1.global_attribute1);
      utl_file.put(l_file
                  ,'~' || c1.global_attribute2);
      utl_file.put(l_file
                  ,'~' || c1.global_attribute3);
      utl_file.put(l_file
                  ,'~' || c1.global_attribute4);
      utl_file.put(l_file
                  ,'~' || c1.global_attribute5);
      utl_file.put(l_file
                  ,'~' || c1.global_attribute6);
      utl_file.put(l_file
                  ,'~' || c1.global_attribute7);
      utl_file.put(l_file
                  ,'~' || c1.global_attribute8);
      utl_file.put(l_file
                  ,'~' || c1.global_attribute9);
      utl_file.put(l_file
                  ,'~' || c1.global_attribute10);
      utl_file.put(l_file
                  ,'~' || c1.global_attribute11);
      utl_file.put(l_file
                  ,'~' || c1.global_attribute12);
      utl_file.put(l_file
                  ,'~' || c1.global_attribute13);
      utl_file.put(l_file
                  ,'~' || c1.global_attribute14);
      utl_file.put(l_file
                  ,'~' || c1.global_attribute15);
      utl_file.put(l_file
                  ,'~' || c1.global_attribute16);
      utl_file.put(l_file
                  ,'~' || c1.global_attribute17);
      utl_file.put(l_file
                  ,'~' || c1.global_attribute18);
      utl_file.put(l_file
                  ,'~' || c1.global_attribute19);
      utl_file.put(l_file
                  ,'~' || c1.global_attribute20);
      utl_file.put(l_file
                  ,'~' || c1.global_attribute_category);
      utl_file.put(l_file
                  ,'~' || c1.port_of_entry_code);
      utl_file.put(l_file
                  ,'~' || c1.transform_status);
      utl_file.put(l_file
                  ,'~' || c1.transform_error);
      utl_file.new_line(l_file);
    END LOOP;
    utl_file.fclose(l_file);
  
    SELECT COUNT(1) INTO l_count FROM xxobjt.xxs3_ptp_invoice;
  
    fnd_file.put_line(fnd_file.output
                     ,rpad('Invoice Header Extract'
                          ,100
                          ,' '));
    fnd_file.put_line(fnd_file.output
                     ,rpad('============================================================'
                          ,200
                          ,' '));
    fnd_file.put_line(fnd_file.output
                     ,rpad('Run date and time:    ' ||
                           to_char(SYSDATE
                                  ,'dd-Mon-YYYY HH24:MI')
                          ,100
                          ,' '));
    fnd_file.put_line(fnd_file.output
                     ,rpad('============================================================'
                          ,200
                          ,' '));
    fnd_file.put_line(fnd_file.output
                     ,'');
    fnd_file.put_line(fnd_file.output
                     ,rpad('Track Name'
                          ,10
                          ,' ') || chr(32) ||
                      rpad('Entity Name'
                          ,30
                          ,' ') || chr(32) ||
                      rpad('Total Count'
                          ,15
                          ,' '));
    fnd_file.put_line(fnd_file.output
                     ,rpad('==========================================================='
                          ,200
                          ,' '));
    fnd_file.put_line(fnd_file.output
                     ,'');
    fnd_file.put_line(fnd_file.output
                     ,rpad('PTP'
                          ,10
                          ,' ') || ' ' || rpad('Invoice_hdr'
                                              ,30
                                              ,' ') || ' ' ||
                      rpad(l_count
                          ,15
                          ,' '));
    fnd_file.put_line(fnd_file.output
                     ,rpad('=========END OF REPORT==============='
                          ,200
                          ,' '));
    fnd_file.put_line(fnd_file.output
                     ,'');
  
  EXCEPTION
  
    WHEN OTHERS THEN
      x_retcode        := 2;
      x_errbuf         := 'Unexpected error: ' || SQLERRM;
      l_status_message := SQLCODE || chr(10) || SQLERRM;
      fnd_file.put_line(fnd_file.log
                       ,'Unexpected error during data extraction at step: ' ||
                        l_step || chr(10) || l_status_message);
      fnd_file.put_line(fnd_file.log
                       ,'--------------------------------------');
    
  END open_invoice_extract_data;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will extract all required Open Invoice fields at line level and insert into
  --           staging table XXS3_PTP_INVOICE_LINE
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  12/08/2016  Debarati Banerjee            Initial build
  -- -------------------------------------------------------------------------------------------- 

  PROCEDURE open_invoice_extract_line_data(x_errbuf  OUT VARCHAR2
                                          ,x_retcode OUT NUMBER) IS
  
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
    l_err_code               VARCHAR2(4000);
    l_err_msg                VARCHAR2(4000);
    l_flag                   VARCHAR2(1);
    l_s3_gl_string           VARCHAR2(2000);
    l_step                   VARCHAR2(1000);
    l_file                   utl_file.file_type;
    l_count                  NUMBER;
    l_count_line             NUMBER;
    l_line_number            NUMBER;
    l_non_po_matched         VARCHAR2(1);
  
    CURSOR c_valid_invoice IS
      SELECT invoice_id FROM xxs3_ptp_invoice WHERE process_flag <> 'R';
  
    CURSOR c_invoice_line_extract(p_invoice_id IN NUMBER) IS
      SELECT invoice_num
            ,invoice_id
            ,po_line_location_id
            ,account_segment
            ,dist_amount
            ,line_amount
            ,assets_tracking_flag
            ,asset_book_type_code
            ,asset_category_id
            ,attribute1
            ,attribute2
            ,attribute3
            ,attribute4
            ,attribute5
            ,attribute6
            ,attribute7
            ,attribute8
            ,attribute9
            ,attribute10
            ,attribute11
            ,attribute12
            ,attribute13
            ,attribute14
            ,attribute15
            ,attribute_category
            ,balancing_segment
            ,control_amount
            ,cost_center_segment
            ,
             --COST_FACTOR_NAME  ,
             country_of_supply
            ,default_distribution_account
            ,default_distribution_segment1
            ,default_distribution_segment2
            ,default_distribution_segment3
            ,default_distribution_segment5
            ,default_distribution_segment6
            ,default_distribution_segment7
            ,default_distribution_segment10
            ,deferred_acctg_flag
            ,def_acctg_end_date
            ,def_acctg_number_of_periods
            ,def_acctg_period_type
            ,def_acctg_start_date
            ,description
            ,distribution_set_name
            ,dist_code_concatenated
            ,dist_code_segment1
            ,dist_code_segment2
            ,dist_code_segment3
            ,dist_code_segment5
            ,dist_code_segment6
            ,dist_code_segment7
            ,dist_code_segment10
            ,expenditure_item_date
            ,expenditure_org_line
            ,expenditure_operating_unit
            ,expenditure_type_line
            ,expenditure_type
            ,final_match_flag
            ,global_attribute1
            ,global_attribute2
            ,global_attribute3
            ,global_attribute4
            ,global_attribute5
            ,global_attribute6
            ,global_attribute7
            ,global_attribute8
            ,global_attribute9
            ,global_attribute10
            ,global_attribute11
            ,global_attribute12
            ,global_attribute13
            ,global_attribute14
            ,global_attribute15
            ,global_attribute16
            ,global_attribute17
            ,global_attribute18
            ,global_attribute19
            ,global_attribute20
            ,global_attribute_category
            ,incl_in_taxable_line_flag
            ,income_tax_region
            ,item
            ,invoice_line_num
            ,item_description
            ,justification
            ,line_group_number
            ,line_number
            ,line_type_lookup_code
            ,manufacturer
            ,match_option
            ,model_number
            ,operating_unit
            ,pa_addition_flag
            ,pa_quantity
            ,po_distribution_num
            ,po_line_number
            ,po_number
            ,po_shipment_num
            ,primary_intended_use
            ,product_category
            ,product_fisc_classification
            ,product_table
            ,product_type
            ,project_accounting_context
            ,project_line
            ,project
            ,prorate_across_flag
            ,
             --PURCHASING_CATEGORY ,
             quantity_invoiced
            ,receipt_conversion_rate
            ,receipt_currency_amount
            ,receipt_currency_code
            ,receipt_line_number
            ,receipt_number
            ,release_num
            ,requester_employee_num
            ,serial_number
            ,ship_to_location_code
            ,task_id_line
            ,task_line
            ,task_id
            ,task
            ,type_1099
            ,unit_meas_lookup_code
            ,unit_price
            ,warranty_number
      FROM (SELECT aia.invoice_num
                  ,aia.invoice_id
                  ,aila.po_line_location_id
                  ,account_segment
                  ,aida.amount dist_amount
                  ,aila.amount line_amount
                  ,aida.assets_tracking_flag
                  ,aida.asset_book_type_code
                  ,aida.asset_category_id
                  ,aida.attribute1
                  ,aida.attribute2
                  ,aida.attribute3
                  ,aida.attribute4
                  ,aida.attribute5
                  ,aida.attribute6
                  ,aida.attribute7
                  ,aida.attribute8
                  ,aida.attribute9
                  ,aida.attribute10
                  ,aida.attribute11
                  ,aida.attribute12
                  ,aida.attribute13
                  ,aida.attribute14
                  ,aida.attribute15
                  ,aida.attribute_category
                  ,aila.balancing_segment
                  ,aila.control_amount
                  ,cost_center_segment
                  ,
                   --COST_FACTOR_NAME  ,
                   aida.country_of_supply
                  ,(SELECT concatenated_segments
                    FROM gl_code_combinations_kfv gcck
                    WHERE gcck.code_combination_id = aila.default_dist_ccid) default_distribution_account
                  ,(SELECT segment1
                    FROM gl_code_combinations_kfv gcck
                    WHERE gcck.code_combination_id = aila.default_dist_ccid) default_distribution_segment1
                  ,(SELECT segment2
                    FROM gl_code_combinations_kfv gcck
                    WHERE gcck.code_combination_id = aila.default_dist_ccid) default_distribution_segment2
                  ,(SELECT segment3
                    FROM gl_code_combinations_kfv gcck
                    WHERE gcck.code_combination_id = aila.default_dist_ccid) default_distribution_segment3
                  ,(SELECT segment5
                    FROM gl_code_combinations_kfv gcck
                    WHERE gcck.code_combination_id = aila.default_dist_ccid) default_distribution_segment5
                  ,(SELECT segment6
                    FROM gl_code_combinations_kfv gcck
                    WHERE gcck.code_combination_id = aila.default_dist_ccid) default_distribution_segment6
                  ,(SELECT segment7
                    FROM gl_code_combinations_kfv gcck
                    WHERE gcck.code_combination_id = aila.default_dist_ccid) default_distribution_segment7
                  ,(SELECT segment10
                    FROM gl_code_combinations_kfv gcck
                    WHERE gcck.code_combination_id = aila.default_dist_ccid) default_distribution_segment10
                  ,deferred_acctg_flag
                  ,def_acctg_end_date
                  ,def_acctg_number_of_periods
                  ,def_acctg_period_type
                  ,def_acctg_start_date
                  ,aida.description
                  ,(SELECT distribution_set_name
                    FROM ap_distribution_sets_all adsa
                    WHERE adsa.distribution_set_id =
                          aila.distribution_set_id) distribution_set_name
                  ,(SELECT concatenated_segments
                    FROM gl_code_combinations_kfv gcck
                    WHERE gcck.code_combination_id =
                          aida.dist_code_combination_id) dist_code_concatenated
                  ,(SELECT segment1
                    FROM gl_code_combinations_kfv gcck
                    WHERE gcck.code_combination_id =
                          aida.dist_code_combination_id) dist_code_segment1
                  ,(SELECT segment2
                    FROM gl_code_combinations_kfv gcck
                    WHERE gcck.code_combination_id =
                          aida.dist_code_combination_id) dist_code_segment2
                  ,(SELECT segment3
                    FROM gl_code_combinations_kfv gcck
                    WHERE gcck.code_combination_id =
                          aida.dist_code_combination_id) dist_code_segment3
                  ,(SELECT segment5
                    FROM gl_code_combinations_kfv gcck
                    WHERE gcck.code_combination_id =
                          aida.dist_code_combination_id) dist_code_segment5
                  ,(SELECT segment6
                    FROM gl_code_combinations_kfv gcck
                    WHERE gcck.code_combination_id =
                          aida.dist_code_combination_id) dist_code_segment6
                  ,(SELECT segment7
                    FROM gl_code_combinations_kfv gcck
                    WHERE gcck.code_combination_id =
                          aida.dist_code_combination_id) dist_code_segment7
                  ,(SELECT segment10
                    FROM gl_code_combinations_kfv gcck
                    WHERE gcck.code_combination_id =
                          aida.dist_code_combination_id) dist_code_segment10
                  ,aida.expenditure_item_date
                  ,(SELECT NAME
                    FROM hr_operating_units hou
                    WHERE hou.organization_id =
                          aila.expenditure_organization_id) expenditure_org_line
                  ,(SELECT NAME
                    FROM hr_operating_units hou
                    WHERE hou.organization_id =
                          aida.expenditure_organization_id) expenditure_operating_unit
                  ,aila.expenditure_type expenditure_type_line
                  ,aida.expenditure_type
                  ,aida.final_match_flag
                  ,aida.global_attribute1
                  ,aida.global_attribute2
                  ,aida.global_attribute3
                  ,aida.global_attribute4
                  ,aida.global_attribute5
                  ,aida.global_attribute6
                  ,aida.global_attribute7
                  ,aida.global_attribute8
                  ,aida.global_attribute9
                  ,aida.global_attribute10
                  ,aida.global_attribute11
                  ,aida.global_attribute12
                  ,aida.global_attribute13
                  ,aida.global_attribute14
                  ,aida.global_attribute15
                  ,aida.global_attribute16
                  ,aida.global_attribute17
                  ,aida.global_attribute18
                  ,aida.global_attribute19
                  ,aida.global_attribute20
                  ,aida.global_attribute_category
                  ,amount_includes_tax_flag incl_in_taxable_line_flag
                  ,aida.income_tax_region
                  ,(SELECT segment1
                    FROM mtl_system_items_b msib
                    WHERE msib.inventory_item_id = aila.inventory_item_id
                    AND upper(msib.enabled_flag) = 'Y'
                    AND trunc(SYSDATE) BETWEEN
                          trunc(nvl(msib.start_date_active
                                ,SYSDATE)) AND
                          trunc(nvl(msib.end_date_active
                                   ,SYSDATE + 1))
                    AND rownum = 1) item
                  ,aida.invoice_line_number invoice_line_num
                  ,item_description
                  ,aida.justification
                  ,aida.line_group_number
                  ,line_number
                  ,aida.line_type_lookup_code
                  ,manufacturer
                  ,aida.dist_match_type match_option
                  ,model_number
                  ,(SELECT NAME
                    FROM hr_operating_units hou
                    WHERE hou.organization_id = aila.org_id) operating_unit
                  ,pa_addition_flag
                  ,aida.pa_quantity
                  ,(SELECT distribution_num
                    FROM po_lines_all         pla
                        ,po_distributions_all pda
                    WHERE pla.po_header_id = pda.po_header_id
                    AND pla.po_line_id = pda.po_line_id
                    AND pda.po_distribution_id = aila.po_distribution_id) po_distribution_num
                  ,(SELECT line_num
                    FROM po_headers_all pha
                        ,po_lines_all   pla
                    WHERE pha.po_header_id = pla.po_header_id
                    AND pla.po_line_id = aila.po_line_id) po_line_number
                  ,(SELECT segment1
                    FROM po_headers_all pha
                    WHERE pha.po_header_id = aila.po_header_id) po_number
                  ,(SELECT shipment_num
                    FROM po_lines_all          pla
                        ,po_line_locations_all plla
                    WHERE pla.po_header_id = plla.po_header_id
                    AND pla.po_line_id = plla.po_line_id
                    AND plla.line_location_id = aila.po_line_location_id) po_shipment_num
                  ,primary_intended_use
                  ,product_category
                  ,product_fisc_classification
                  ,aila.product_table
                  ,product_type
                  ,aida.project_accounting_context
                  ,(SELECT NAME
                    FROM pa_projects_all ppa
                    WHERE ppa.project_id = aila.project_id) project_line
                  ,(SELECT NAME
                    FROM pa_projects_all ppa
                    WHERE ppa.project_id = aida.project_id) project
                  ,prorate_across_all_items prorate_across_flag
                  ,aida.quantity_invoiced
                  ,aida.receipt_conversion_rate
                  ,aida.receipt_currency_amount
                  ,aida.receipt_currency_code
                  ,(SELECT line_num
                    FROM rcv_shipment_lines   rsl
                        ,rcv_shipment_headers rsh
                    WHERE rsh.shipment_header_id = rsl.shipment_header_id
                    AND rsl.po_header_id = aila.po_header_id
                    AND rsl.po_line_id = aila.po_line_id
                    AND rsh.invoice_num = aia.invoice_num) receipt_line_number
                  ,(SELECT receipt_num
                    FROM rcv_shipment_headers rsh
                    WHERE rsh.invoice_num = aia.invoice_num) receipt_number
                  ,(SELECT release_num
                    FROM po_headers_all  pha
                        ,po_releases_all pra
                    WHERE pha.po_header_id = pra.po_header_id
                    AND pra.po_release_id = aila.po_release_id) release_num
                  ,(SELECT employee_number
                    FROM per_all_people_f papf
                    WHERE papf.person_id = aila.requester_id
                    AND trunc(SYSDATE) BETWEEN
                          trunc(nvl(papf.effective_start_date
                                ,SYSDATE)) AND
                          trunc(nvl(papf.effective_end_date
                                   ,SYSDATE + 1))) requester_employee_num
                  ,serial_number
                  ,(SELECT location_code
                    FROM hr_locations_all hl
                    WHERE hl.location_id = aila.ship_to_location_id) ship_to_location_code
                  ,aila.task_id task_id_line
                  ,(SELECT pt.task_name
                    FROM pa_tasks pt
                    WHERE pt.task_id = aila.task_id
                    AND pt.project_id = aila.project_id) task_line
                  ,aida.task_id task_id
                  ,(SELECT pt.task_name
                    FROM pa_tasks pt
                    WHERE pt.task_id = aida.task_id
                    AND pt.project_id = aida.project_id) task
                  ,aida.type_1099
                  ,unit_meas_lookup_code
                  ,aila.unit_price
                  ,warranty_number
            FROM ap_invoices_all              aia
                ,ap_invoice_lines_all         aila
                ,ap_invoice_distributions_all aida
            WHERE aia.invoice_id = aila.invoice_id
            AND aila.invoice_id = aida.invoice_id
            AND aila.line_number = aida.invoice_line_number
            AND aia.org_id = l_org_id
            AND aia.invoice_type_lookup_code = 'STANDARD'
                 --  AND aila.line_type_lookup_code <> 'PREPAYMENT'
            AND aia.cancelled_date IS NULL
                 -- AND nvl(aia.invoice_amount
                 -- ,0) > 0
                 --  AND nvl(aia.amount_paid
                 --  ,0) = 0
            AND nvl(aila.amount
                  ,0) > 0
            AND aia.invoice_id = p_invoice_id
            AND ap_invoices_pkg.get_approval_status(aia.invoice_id
                                                  ,aia.invoice_amount
                                                  ,aia.payment_status_flag
                                                  ,aia.invoice_type_lookup_code) =
                  'APPROVED'
            
            UNION
            
            ----Query for standard partially paid invoice line
            /* SELECT aia.invoice_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,account_segment
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,aida.amount
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,aida.assets_tracking_flag
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,aida.asset_book_type_code
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,aida.asset_category_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,aida.attribute1
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,aida.attribute2
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,aida.attribute3
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,aida.attribute4
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,aida.attribute5
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,aida.attribute6
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,aida.attribute7
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,aida.attribute8
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,aida.attribute9
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,aida.attribute10
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,aida.attribute11
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,aida.attribute12
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,aida.attribute13
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,aida.attribute14
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,aida.attribute15
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,aida.attribute_category
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,aila.balancing_segment
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,aila.control_amount
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,cost_center_segment
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               --COST_FACTOR_NAME  ,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               aida.country_of_supply
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,(SELECT concatenated_segments
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                FROM gl_code_combinations_kfv gcck
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                WHERE gcck.code_combination_id = aila.default_dist_ccid) default_distribution_account
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,(SELECT segment1
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                FROM gl_code_combinations_kfv gcck
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                WHERE gcck.code_combination_id = aila.default_dist_ccid) default_distribution_segment1
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,(SELECT segment2
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                FROM gl_code_combinations_kfv gcck
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                WHERE gcck.code_combination_id = aila.default_dist_ccid) default_distribution_segment2
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,(SELECT segment3
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                FROM gl_code_combinations_kfv gcck
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                WHERE gcck.code_combination_id = aila.default_dist_ccid) default_distribution_segment3
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,(SELECT segment5
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                FROM gl_code_combinations_kfv gcck
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                WHERE gcck.code_combination_id = aila.default_dist_ccid) default_distribution_segment5
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,(SELECT segment6
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                FROM gl_code_combinations_kfv gcck
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                WHERE gcck.code_combination_id = aila.default_dist_ccid) default_distribution_segment6
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,(SELECT segment7
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                FROM gl_code_combinations_kfv gcck
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                WHERE gcck.code_combination_id = aila.default_dist_ccid) default_distribution_segment7
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,(SELECT segment10
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                FROM gl_code_combinations_kfv gcck
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                WHERE gcck.code_combination_id = aila.default_dist_ccid) default_distribution_segment10
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,deferred_acctg_flag
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,def_acctg_end_date
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,def_acctg_number_of_periods
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,def_acctg_period_type
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,def_acctg_start_date
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,aida.description
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,(SELECT distribution_set_name
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                FROM ap_distribution_sets_all adsa
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                WHERE adsa.distribution_set_id =
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      aila.distribution_set_id) distribution_set_name
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,(SELECT concatenated_segments
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                FROM gl_code_combinations_kfv gcck
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                WHERE gcck.code_combination_id =
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      aida.dist_code_combination_id) dist_code_concatenated
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,(SELECT segment1
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                FROM gl_code_combinations_kfv gcck
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                WHERE gcck.code_combination_id =
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      aida.dist_code_combination_id) dist_code_segment1
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,(SELECT segment2
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                FROM gl_code_combinations_kfv gcck
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                WHERE gcck.code_combination_id =
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      aida.dist_code_combination_id) dist_code_segment2
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,(SELECT segment3
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                FROM gl_code_combinations_kfv gcck
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                WHERE gcck.code_combination_id =
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      aida.dist_code_combination_id) dist_code_segment3
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,(SELECT segment5
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                FROM gl_code_combinations_kfv gcck
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                WHERE gcck.code_combination_id =
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      aida.dist_code_combination_id) dist_code_segment5
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,(SELECT segment6
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                FROM gl_code_combinations_kfv gcck
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                WHERE gcck.code_combination_id =
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      aida.dist_code_combination_id) dist_code_segment6
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,(SELECT segment7
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                FROM gl_code_combinations_kfv gcck
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                WHERE gcck.code_combination_id =
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      aida.dist_code_combination_id) dist_code_segment7
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,(SELECT segment10
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                FROM gl_code_combinations_kfv gcck
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                WHERE gcck.code_combination_id =
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      aida.dist_code_combination_id) dist_code_segment10
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,aida.expenditure_item_date
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,(SELECT NAME
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                FROM hr_operating_units hou
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                WHERE hou.organization_id =
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      aila.expenditure_organization_id) expenditure_org_line
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,(SELECT NAME
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                FROM hr_operating_units hou
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                WHERE hou.organization_id =
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      aida.expenditure_organization_id) expenditure_operating_unit
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,aila.expenditure_type expenditure_type_line
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,aida.expenditure_type
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,aida.final_match_flag
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,aida.global_attribute1
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,aida.global_attribute2
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,aida.global_attribute3
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,aida.global_attribute4
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,aida.global_attribute5
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,aida.global_attribute6
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,aida.global_attribute7
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,aida.global_attribute8
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,aida.global_attribute9
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,aida.global_attribute10
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,aida.global_attribute11
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,aida.global_attribute12
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,aida.global_attribute13
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,aida.global_attribute14
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,aida.global_attribute15
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,aida.global_attribute16
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,aida.global_attribute17
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,aida.global_attribute18
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,aida.global_attribute19
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,aida.global_attribute20
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,aida.global_attribute_category
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,amount_includes_tax_flag incl_in_taxable_line_flag
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,aida.income_tax_region
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,(SELECT segment1
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                FROM mtl_system_items_b msib
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                WHERE msib.inventory_item_id = aila.inventory_item_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                AND upper(msib.enabled_flag) = 'Y'
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                AND trunc(SYSDATE) BETWEEN
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      trunc(nvl(msib.start_date_active
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            ,SYSDATE)) AND
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      trunc(nvl(msib.end_date_active
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               ,SYSDATE + 1))
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                AND rownum = 1) item
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,aida.invoice_line_number invoice_line_num
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,item_description
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,aida.justification
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,aida.line_group_number
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,line_number
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,aida.line_type_lookup_code
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,manufacturer
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,aida.dist_match_type match_option
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,model_number
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,(SELECT NAME
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                FROM hr_operating_units hou
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                WHERE hou.organization_id = aila.org_id) operating_unit
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,pa_addition_flag
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,aida.pa_quantity
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,(SELECT distribution_num
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                FROM po_lines_all         pla
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    ,po_distributions_all pda
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                WHERE pla.po_header_id = pda.po_header_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                AND pla.po_line_id = pda.po_line_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                AND pda.po_distribution_id = aila.po_distribution_id) po_distribution_num
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,(SELECT line_num
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                FROM po_headers_all pha
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    ,po_lines_all   pla
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                WHERE pha.po_header_id = pla.po_header_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                AND pla.po_line_id = aila.po_line_id) po_line_number
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,(SELECT segment1
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                FROM po_headers_all pha
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                WHERE pha.po_header_id = aila.po_header_id) po_number
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,(SELECT shipment_num
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                FROM po_lines_all          pla
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    ,po_line_locations_all plla
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                WHERE pla.po_header_id = plla.po_header_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                AND pla.po_line_id = plla.po_line_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                AND plla.line_location_id = aila.po_line_location_id) po_shipment_num
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,primary_intended_use
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,product_category
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,product_fisc_classification
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,aila.product_table
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,product_type
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,aida.project_accounting_context
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,(SELECT NAME
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                FROM pa_projects_all ppa
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                WHERE ppa.project_id = aila.project_id) project_line
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,(SELECT NAME
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                FROM pa_projects_all ppa
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                WHERE ppa.project_id = aida.project_id) project
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,prorate_across_all_items prorate_across_flag
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,aida.quantity_invoiced
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,aida.receipt_conversion_rate
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,aida.receipt_currency_amount
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,aida.receipt_currency_code
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,(SELECT line_num
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                FROM rcv_shipment_lines   rsl
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    ,rcv_shipment_headers rsh
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                WHERE rsh.shipment_header_id = rsl.shipment_header_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                AND rsl.po_header_id = aila.po_header_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                AND rsl.po_line_id = aila.po_line_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                AND rsh.invoice_num = aia.invoice_num) receipt_line_number
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,(SELECT receipt_num
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                FROM rcv_shipment_headers rsh
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                WHERE rsh.invoice_num = aia.invoice_num) receipt_number
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,(SELECT release_num
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                FROM po_headers_all  pha
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    ,po_releases_all pra
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                WHERE pha.po_header_id = pra.po_header_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                AND pra.po_release_id = aila.po_release_id) release_num
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,(SELECT employee_number
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                FROM per_all_people_f papf
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                WHERE papf.person_id = aila.requester_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                AND trunc(SYSDATE) BETWEEN
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      trunc(nvl(papf.effective_start_date
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            ,SYSDATE)) AND
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      trunc(nvl(papf.effective_end_date
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               ,SYSDATE + 1))) requester_employee_num
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,serial_number
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,(SELECT location_code
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                FROM hr_locations_all hl
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                WHERE hl.location_id = aila.ship_to_location_id) ship_to_location_code
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,aila.task_id task_id_line
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,(SELECT pt.task_name
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                FROM pa_tasks pt
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                WHERE pt.task_id = aila.task_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                AND pt.project_id = aila.project_id) task_line
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,aida.task_id task_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,(SELECT pt.task_name
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                FROM pa_tasks pt
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                WHERE pt.task_id = aida.task_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                AND pt.project_id = aida.project_id) task
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,aida.type_1099
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,unit_meas_lookup_code
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,aila.unit_price
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,warranty_number
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        FROM ap_invoices_all              aia
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            ,ap_invoice_lines_all         aila
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            ,ap_invoice_distributions_all aida
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        WHERE aia.invoice_id = aila.invoice_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        AND aila.invoice_id = aida.invoice_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        AND aila.line_number = aida.invoice_line_number
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        AND aia.org_id = l_org_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        AND aia.invoice_type_lookup_code = 'STANDARD'
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        AND aila.line_type_lookup_code <> 'PREPAY'
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        AND aia.cancelled_date IS NULL
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        AND nvl(aia.invoice_amount
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,0) > 0
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        AND (nvl(aia.amount_paid
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               ,0) + nvl(aia.discount_amount_taken
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      ,0)) <> aia.invoice_amount
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        AND (nvl(aia.amount_paid
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               ,0) + nvl(aia.discount_amount_taken
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      ,0)) > 0
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        AND aia.invoice_id = p_invoice_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        AND ap_invoices_pkg.get_approval_status(aia.invoice_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,aia.invoice_amount
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,aia.payment_status_flag
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ,aia.invoice_type_lookup_code) =
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              'APPROVED'
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        UNION*/
            
            ----Query for  Prepay unpaid invoice line
            SELECT aia.invoice_num
                  ,aia.invoice_id
                  ,po_line_location_id
                  ,account_segment
                  ,aida.amount dist_amount
                  ,aila.amount line_amount
                  ,aida.assets_tracking_flag
                  ,aida.asset_book_type_code
                  ,aida.asset_category_id
                  ,aida.attribute1
                  ,aida.attribute2
                  ,aida.attribute3
                  ,aida.attribute4
                  ,aida.attribute5
                  ,aida.attribute6
                  ,aida.attribute7
                  ,aida.attribute8
                  ,aida.attribute9
                  ,aida.attribute10
                  ,aida.attribute11
                  ,aida.attribute12
                  ,aida.attribute13
                  ,aida.attribute14
                  ,aida.attribute15
                  ,aida.attribute_category
                  ,aila.balancing_segment
                  ,aila.control_amount
                  ,cost_center_segment
                  ,
                   --COST_FACTOR_NAME  ,
                   aida.country_of_supply
                  ,(SELECT concatenated_segments
                    FROM gl_code_combinations_kfv gcck
                    WHERE gcck.code_combination_id = aila.default_dist_ccid) default_distribution_account
                  ,(SELECT segment1
                    FROM gl_code_combinations_kfv gcck
                    WHERE gcck.code_combination_id = aila.default_dist_ccid) default_distribution_segment1
                  ,(SELECT segment2
                    FROM gl_code_combinations_kfv gcck
                    WHERE gcck.code_combination_id = aila.default_dist_ccid) default_distribution_segment2
                  ,(SELECT segment3
                    FROM gl_code_combinations_kfv gcck
                    WHERE gcck.code_combination_id = aila.default_dist_ccid) default_distribution_segment3
                  ,(SELECT segment5
                    FROM gl_code_combinations_kfv gcck
                    WHERE gcck.code_combination_id = aila.default_dist_ccid) default_distribution_segment5
                  ,(SELECT segment6
                    FROM gl_code_combinations_kfv gcck
                    WHERE gcck.code_combination_id = aila.default_dist_ccid) default_distribution_segment6
                  ,(SELECT segment7
                    FROM gl_code_combinations_kfv gcck
                    WHERE gcck.code_combination_id = aila.default_dist_ccid) default_distribution_segment7
                  ,(SELECT segment10
                    FROM gl_code_combinations_kfv gcck
                    WHERE gcck.code_combination_id = aila.default_dist_ccid) default_distribution_segment10
                  ,deferred_acctg_flag
                  ,def_acctg_end_date
                  ,def_acctg_number_of_periods
                  ,def_acctg_period_type
                  ,def_acctg_start_date
                  ,aida.description
                  ,(SELECT distribution_set_name
                    FROM ap_distribution_sets_all adsa
                    WHERE adsa.distribution_set_id =
                          aila.distribution_set_id) distribution_set_name
                  ,(SELECT concatenated_segments
                    FROM gl_code_combinations_kfv gcck
                    WHERE gcck.code_combination_id =
                          aida.dist_code_combination_id) dist_code_concatenated
                  ,(SELECT segment1
                    FROM gl_code_combinations_kfv gcck
                    WHERE gcck.code_combination_id =
                          aida.dist_code_combination_id) dist_code_segment1
                  ,(SELECT segment2
                    FROM gl_code_combinations_kfv gcck
                    WHERE gcck.code_combination_id =
                          aida.dist_code_combination_id) dist_code_segment2
                  ,(SELECT segment3
                    FROM gl_code_combinations_kfv gcck
                    WHERE gcck.code_combination_id =
                          aida.dist_code_combination_id) dist_code_segment3
                  ,(SELECT segment5
                    FROM gl_code_combinations_kfv gcck
                    WHERE gcck.code_combination_id =
                          aida.dist_code_combination_id) dist_code_segment5
                  ,(SELECT segment6
                    FROM gl_code_combinations_kfv gcck
                    WHERE gcck.code_combination_id =
                          aida.dist_code_combination_id) dist_code_segment6
                  ,(SELECT segment7
                    FROM gl_code_combinations_kfv gcck
                    WHERE gcck.code_combination_id =
                          aida.dist_code_combination_id) dist_code_segment7
                  ,(SELECT segment10
                    FROM gl_code_combinations_kfv gcck
                    WHERE gcck.code_combination_id =
                          aida.dist_code_combination_id) dist_code_segment10
                  ,aida.expenditure_item_date
                  ,(SELECT NAME
                    FROM hr_operating_units hou
                    WHERE hou.organization_id =
                          aila.expenditure_organization_id) expenditure_org_line
                  ,(SELECT NAME
                    FROM hr_operating_units hou
                    WHERE hou.organization_id =
                          aida.expenditure_organization_id) expenditure_operating_unit
                  ,aila.expenditure_type expenditure_type_line
                  ,aida.expenditure_type
                  ,aida.final_match_flag
                  ,aida.global_attribute1
                  ,aida.global_attribute2
                  ,aida.global_attribute3
                  ,aida.global_attribute4
                  ,aida.global_attribute5
                  ,aida.global_attribute6
                  ,aida.global_attribute7
                  ,aida.global_attribute8
                  ,aida.global_attribute9
                  ,aida.global_attribute10
                  ,aida.global_attribute11
                  ,aida.global_attribute12
                  ,aida.global_attribute13
                  ,aida.global_attribute14
                  ,aida.global_attribute15
                  ,aida.global_attribute16
                  ,aida.global_attribute17
                  ,aida.global_attribute18
                  ,aida.global_attribute19
                  ,aida.global_attribute20
                  ,aida.global_attribute_category
                  ,amount_includes_tax_flag incl_in_taxable_line_flag
                  ,aida.income_tax_region
                  ,(SELECT segment1
                    FROM mtl_system_items_b msib
                    WHERE msib.inventory_item_id = aila.inventory_item_id
                    AND upper(msib.enabled_flag) = 'Y'
                    AND trunc(SYSDATE) BETWEEN
                          trunc(nvl(msib.start_date_active
                                ,SYSDATE)) AND
                          trunc(nvl(msib.end_date_active
                                   ,SYSDATE + 1))
                    AND rownum = 1) item
                  ,aida.invoice_line_number invoice_line_num
                  ,item_description
                  ,aida.justification
                  ,aida.line_group_number
                  ,line_number
                  ,aida.line_type_lookup_code
                  ,manufacturer
                  ,aida.dist_match_type match_option
                  ,model_number
                  ,(SELECT NAME
                    FROM hr_operating_units hou
                    WHERE hou.organization_id = aila.org_id) operating_unit
                  ,pa_addition_flag
                  ,aida.pa_quantity
                  ,(SELECT distribution_num
                    FROM po_lines_all         pla
                        ,po_distributions_all pda
                    WHERE pla.po_header_id = pda.po_header_id
                    AND pla.po_line_id = pda.po_line_id
                    AND pda.po_distribution_id = aila.po_distribution_id) po_distribution_num
                  ,(SELECT line_num
                    FROM po_headers_all pha
                        ,po_lines_all   pla
                    WHERE pha.po_header_id = pla.po_header_id
                    AND pla.po_line_id = aila.po_line_id) po_line_number
                  ,(SELECT segment1
                    FROM po_headers_all pha
                    WHERE pha.po_header_id = aila.po_header_id) po_number
                  ,(SELECT shipment_num
                    FROM po_lines_all          pla
                        ,po_line_locations_all plla
                    WHERE pla.po_header_id = plla.po_header_id
                    AND pla.po_line_id = plla.po_line_id
                    AND plla.line_location_id = aila.po_line_location_id) po_shipment_num
                  ,primary_intended_use
                  ,product_category
                  ,product_fisc_classification
                  ,aila.product_table
                  ,product_type
                  ,aida.project_accounting_context
                  ,(SELECT NAME
                    FROM pa_projects_all ppa
                    WHERE ppa.project_id = aila.project_id) project_line
                  ,(SELECT NAME
                    FROM pa_projects_all ppa
                    WHERE ppa.project_id = aida.project_id) project
                  ,prorate_across_all_items prorate_across_flag
                  ,aida.quantity_invoiced
                  ,aida.receipt_conversion_rate
                  ,aida.receipt_currency_amount
                  ,aida.receipt_currency_code
                  ,(SELECT line_num
                    FROM rcv_shipment_lines   rsl
                        ,rcv_shipment_headers rsh
                    WHERE rsh.shipment_header_id = rsl.shipment_header_id
                    AND rsl.po_header_id = aila.po_header_id
                    AND rsl.po_line_id = aila.po_line_id
                    AND rsh.invoice_num = aia.invoice_num) receipt_line_number
                  ,(SELECT receipt_num
                    FROM rcv_shipment_headers rsh
                    WHERE rsh.invoice_num = aia.invoice_num) receipt_number
                  ,(SELECT release_num
                    FROM po_headers_all  pha
                        ,po_releases_all pra
                    WHERE pha.po_header_id = pra.po_header_id
                    AND pra.po_release_id = aila.po_release_id) release_num
                  ,(SELECT employee_number
                    FROM per_all_people_f papf
                    WHERE papf.person_id = aila.requester_id
                    AND trunc(SYSDATE) BETWEEN
                          trunc(nvl(papf.effective_start_date
                                ,SYSDATE)) AND
                          trunc(nvl(papf.effective_end_date
                                   ,SYSDATE + 1))) requester_employee_num
                  ,serial_number
                  ,(SELECT location_code
                    FROM hr_locations_all hl
                    WHERE hl.location_id = aila.ship_to_location_id) ship_to_location_code
                  ,aila.task_id task_id_line
                  ,(SELECT pt.task_name
                    FROM pa_tasks pt
                    WHERE pt.task_id = aila.task_id
                    AND pt.project_id = aila.project_id) task_line
                  ,aida.task_id task_id
                  ,(SELECT pt.task_name
                    FROM pa_tasks pt
                    WHERE pt.task_id = aida.task_id
                    AND pt.project_id = aida.project_id) task
                  ,aida.type_1099
                  ,unit_meas_lookup_code
                  ,aila.unit_price
                  ,warranty_number
            FROM ap_invoices_all              aia
                ,ap_invoice_lines_all         aila
                ,ap_invoice_distributions_all aida
            WHERE aia.invoice_id = aila.invoice_id
            AND aila.invoice_id = aida.invoice_id
            AND aila.line_number = aida.invoice_line_number
            AND aia.org_id = l_org_id
            AND aia.invoice_type_lookup_code = 'PREPAYMENT'
                 --AND     AILA.LINE_TYPE_LOOKUP_CODE <>'PREPAY'
                 -- AND aia.cancelled_date IS NULL
                 --  --AND nvl(aia.invoice_amount
                 --    ,0) > 0
                 -- AND nvl(aia.amount_paid
                 --     ,0) > 0
            AND nvl(aila.amount
                  ,0) > 0
            AND aia.invoice_id = p_invoice_id
            AND ap_invoices_pkg.get_approval_status(aia.invoice_id
                                                  ,aia.invoice_amount
                                                  ,aia.payment_status_flag
                                                  ,aia.invoice_type_lookup_code) =
                  'AVAILABLE')
      ORDER BY invoice_id;
  
    CURSOR c_line_data IS
      SELECT * --MATCH_OPTION,RECEIPT_REQUIRED_FLAG_SHIP
      FROM xxobjt.xxs3_ptp_invoice_line
      WHERE process_flag != 'R';
  
  
    CURSOR c_update_inv_line IS
      SELECT DISTINCT invoice_id --MATCH_OPTION,RECEIPT_REQUIRED_FLAG_SHIP
      FROM xxobjt.xxs3_ptp_invoice_line
      WHERE process_flag != 'R';
    /* CURSOR c_line_transform IS
      SELECT *
      FROM   xxobjt.xxs3_ptp_invoice_line;
    
    CURSOR c_line_utl_upload IS
      SELECT *
      FROM   xxobjt.xxs3_ptp_invoice_line;*/
  
  
  BEGIN
  
    x_retcode := 0;
    x_errbuf  := 'COMPLETE';
    l_file    := utl_file.fopen('/UtlFiles/shared/DEV'
                               ,'INV_LINE_DATA' || '_' || SYSDATE || '.xls'
                               ,'w'
                               ,32767);
  
    --mo_global.init('PO');
    mo_global.set_policy_context('S'
                                ,l_org_id);
  
    EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.xxs3_ptp_invoice_line';
  
    EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.xxs3_ptp_invoice_line_temp';
  
    FOR j IN c_valid_invoice
    LOOP
      FOR i IN c_invoice_line_extract(j.invoice_id)
      LOOP
      
        INSERT INTO xxobjt.xxs3_ptp_invoice_line_temp
        VALUES
          (xxs3_ptp_invoice_line_seq.NEXTVAL
          ,SYSDATE
          ,'N'
          ,NULL
          ,NULL
          ,i.invoice_id
          ,
           -- i.LINE_NUMBER,
           i.account_segment
          ,i.dist_amount
          ,i.assets_tracking_flag
          ,i.asset_book_type_code
          ,NULL
          ,i.asset_category_id
          ,i.attribute1
          ,i.attribute2
          ,i.attribute3
          ,i.attribute4
          ,i.attribute5
          ,i.attribute6
          ,i.attribute7
          ,i.attribute8
          ,i.attribute9
          ,i.attribute10
          ,i.attribute11
          ,i.attribute12
          ,i.attribute13
          ,i.attribute14
          ,i.attribute15
          ,i.attribute_category
          ,i.balancing_segment
          ,i.control_amount
          ,i.cost_center_segment
          ,
           -- NULL , --COST_FACTOR_NAME  ,
           i.country_of_supply
          ,i.default_distribution_account
          ,i.default_distribution_segment1
          ,i.default_distribution_segment2
          ,i.default_distribution_segment3
          ,i.default_distribution_segment5
          ,i.default_distribution_segment6
          ,i.default_distribution_segment7
          ,i.default_distribution_segment10
          ,NULL
          ,NULL
          ,NULL
          ,NULL
          ,NULL
          ,NULL
          ,NULL
          ,NULL
          ,i.deferred_acctg_flag
          ,i.def_acctg_end_date
          ,i.def_acctg_number_of_periods
          ,i.def_acctg_period_type
          ,i.def_acctg_start_date
          ,i.description
          ,i.distribution_set_name
          ,i.dist_code_concatenated
          ,i.dist_code_segment1
          ,i.dist_code_segment2
          ,i.dist_code_segment3
          ,i.dist_code_segment5
          ,i.dist_code_segment6
          ,i.dist_code_segment7
          ,i.dist_code_segment10
          ,NULL
          ,NULL
          ,NULL
          ,NULL
          ,NULL
          ,NULL
          ,NULL
          ,NULL
          ,i.expenditure_item_date
          ,i.expenditure_org_line
          ,NULL
          ,i.expenditure_operating_unit
          ,NULL
          ,i.expenditure_type_line
          ,NULL
          ,i.expenditure_type
          ,NULL
          ,i.final_match_flag
          ,i.global_attribute1
          ,i.global_attribute2
          ,i.global_attribute3
          ,i.global_attribute4
          ,i.global_attribute5
          ,i.global_attribute6
          ,i.global_attribute7
          ,i.global_attribute8
          ,i.global_attribute9
          ,i.global_attribute10
          ,i.global_attribute11
          ,i.global_attribute12
          ,i.global_attribute13
          ,i.global_attribute14
          ,i.global_attribute15
          ,i.global_attribute16
          ,i.global_attribute17
          ,i.global_attribute18
          ,i.global_attribute19
          ,i.global_attribute20
          ,i.global_attribute_category
          ,i.incl_in_taxable_line_flag
          ,i.income_tax_region
          ,i.item
          ,i.invoice_line_num
          ,i.item_description
          ,i.justification
          ,i.line_group_number
          ,i.line_number
          ,i.line_type_lookup_code
          ,i.manufacturer
          ,i.match_option
          ,i.model_number
          ,i.operating_unit
          ,NULL
          ,i.pa_addition_flag
          ,i.pa_quantity
          ,i.po_distribution_num
          ,i.po_line_number
          ,i.po_number
          ,i.po_shipment_num
          ,i.primary_intended_use
          ,i.product_category
          ,i.product_fisc_classification
          ,i.product_table
          ,i.product_type
          ,i.project_accounting_context
          ,i.project_line
          ,NULL
          ,i.project
          ,NULL
          ,i.prorate_across_flag
          ,i.quantity_invoiced
          ,i.receipt_conversion_rate
          ,i.receipt_currency_amount
          ,i.receipt_currency_code
          ,i.receipt_line_number
          ,i.receipt_number
          ,i.release_num
          ,i.requester_employee_num
          ,i.serial_number
          ,i.ship_to_location_code
          ,NULL
          ,i.task_line
          ,NULL
          ,i.task
          ,NULL
          ,i.type_1099
          ,i.unit_meas_lookup_code
          ,i.unit_price
          ,i.warranty_number
          ,NULL
          ,NULL
          ,i.task_id
          ,i.task_id_line
          ,NULL
          ,NULL
          ,i.invoice_num
          ,NULL
          ,i.po_line_location_id
          ,NULL
          ,NULL
          ,i.line_amount);
      
      END LOOP;
    END LOOP;
    COMMIT;
  
  
    FOR j IN c_valid_invoice
    LOOP
      FOR i IN c_invoice_line_extract(j.invoice_id)
      LOOP
      
        INSERT INTO xxobjt.xxs3_ptp_invoice_line
        VALUES
          (xxs3_ptp_invoice_line_seq.NEXTVAL
          ,SYSDATE
          ,'N'
          ,NULL
          ,NULL
          ,i.invoice_id
          ,
           -- i.LINE_NUMBER,
           i.account_segment
          ,i.dist_amount
          ,i.assets_tracking_flag
          ,i.asset_book_type_code
          ,NULL
          ,i.asset_category_id
          ,i.attribute1
          ,i.attribute2
          ,i.attribute3
          ,i.attribute4
          ,i.attribute5
          ,i.attribute6
          ,i.attribute7
          ,i.attribute8
          ,i.attribute9
          ,i.attribute10
          ,i.attribute11
          ,i.attribute12
          ,i.attribute13
          ,i.attribute14
          ,i.attribute15
          ,i.attribute_category
          ,i.balancing_segment
          ,i.control_amount
          ,i.cost_center_segment
          ,
           -- NULL , --COST_FACTOR_NAME  ,
           i.country_of_supply
          ,i.default_distribution_account
          ,i.default_distribution_segment1
          ,i.default_distribution_segment2
          ,i.default_distribution_segment3
          ,i.default_distribution_segment5
          ,i.default_distribution_segment6
          ,i.default_distribution_segment7
          ,i.default_distribution_segment10
          ,NULL
          ,NULL
          ,NULL
          ,NULL
          ,NULL
          ,NULL
          ,NULL
          ,NULL
          ,i.deferred_acctg_flag
          ,i.def_acctg_end_date
          ,i.def_acctg_number_of_periods
          ,i.def_acctg_period_type
          ,i.def_acctg_start_date
          ,i.description
          ,i.distribution_set_name
          ,i.dist_code_concatenated
          ,i.dist_code_segment1
          ,i.dist_code_segment2
          ,i.dist_code_segment3
          ,i.dist_code_segment5
          ,i.dist_code_segment6
          ,i.dist_code_segment7
          ,i.dist_code_segment10
          ,NULL
          ,NULL
          ,NULL
          ,NULL
          ,NULL
          ,NULL
          ,NULL
          ,NULL
          ,i.expenditure_item_date
          ,i.expenditure_org_line
          ,NULL
          ,i.expenditure_operating_unit
          ,NULL
          ,i.expenditure_type_line
          ,NULL
          ,i.expenditure_type
          ,NULL
          ,i.final_match_flag
          ,i.global_attribute1
          ,i.global_attribute2
          ,i.global_attribute3
          ,i.global_attribute4
          ,i.global_attribute5
          ,i.global_attribute6
          ,i.global_attribute7
          ,i.global_attribute8
          ,i.global_attribute9
          ,i.global_attribute10
          ,i.global_attribute11
          ,i.global_attribute12
          ,i.global_attribute13
          ,i.global_attribute14
          ,i.global_attribute15
          ,i.global_attribute16
          ,i.global_attribute17
          ,i.global_attribute18
          ,i.global_attribute19
          ,i.global_attribute20
          ,i.global_attribute_category
          ,i.incl_in_taxable_line_flag
          ,i.income_tax_region
          ,i.item
          ,i.invoice_line_num
          ,i.item_description
          ,i.justification
          ,i.line_group_number
          ,i.line_number
          ,i.line_type_lookup_code
          ,i.manufacturer
          ,i.match_option
          ,i.model_number
          ,i.operating_unit
          ,NULL
          ,i.pa_addition_flag
          ,i.pa_quantity
          ,i.po_distribution_num
          ,i.po_line_number
          ,i.po_number
          ,i.po_shipment_num
          ,i.primary_intended_use
          ,i.product_category
          ,i.product_fisc_classification
          ,i.product_table
          ,i.product_type
          ,i.project_accounting_context
          ,i.project_line
          ,NULL
          ,i.project
          ,NULL
          ,i.prorate_across_flag
          ,i.quantity_invoiced
          ,i.receipt_conversion_rate
          ,i.receipt_currency_amount
          ,i.receipt_currency_code
          ,i.receipt_line_number
          ,i.receipt_number
          ,i.release_num
          ,i.requester_employee_num
          ,i.serial_number
          ,i.ship_to_location_code
          ,NULL
          ,i.task_line
          ,NULL
          ,i.task
          ,NULL
          ,i.type_1099
          ,i.unit_meas_lookup_code
          ,i.unit_price
          ,i.warranty_number
          ,NULL
          ,NULL
          ,i.task_id
          ,i.task_id_line
          ,NULL
          ,NULL
          ,i.invoice_num
          ,NULL
          ,i.po_line_location_id
          ,NULL
          ,NULL
          ,i.line_amount);
      
      END LOOP;
    END LOOP;
    COMMIT;
  
    fnd_file.put_line(fnd_file.log
                     ,'Loading complete');
  
  
  
  
    FOR i IN c_update_inv_line
    LOOP
      -- Update s3 invoice line number for non po matched invoices
      l_step := 'Update s3 invoice line number';
    
      FOR j IN (SELECT invoice_id
                      ,invoice_line_num
                      ,po_number
                      ,po_line_location_id
                FROM xxs3_ptp_invoice_line
                WHERE invoice_id = i.invoice_id)
      
      LOOP
        IF j.po_number IS NOT NULL
        THEN
          BEGIN
          
            fnd_file.put_line(fnd_file.log
                             ,'Po Matched for invoice_id : ' ||
                              j.invoice_id);
          
            l_non_po_matched := 'N';
          
            l_step := 'Update distribution and project details for po matched invoices';
            UPDATE xxs3_ptp_invoice_line
            SET po_distribution_num           = NULL
               ,s3_expenditure_type           = NULL
               ,expenditure_item_date         = NULL
               ,pa_addition_flag              = NULL
               ,s3_expenditure_operating_unit = NULL
            WHERE invoice_id = j.invoice_id;
          
            l_step := 'Fetching count of line number for po matched invoices';
            SELECT COUNT(ROWID)
            INTO l_count_line
            FROM xxs3_ptp_invoice_line
            WHERE invoice_line_num = j.invoice_line_num
            AND invoice_id = j.invoice_id;
          
            fnd_file.put_line(fnd_file.log
                             ,'invoice_line_num : ' || j.invoice_line_num ||
                              ' : ' || l_count_line);
          
          EXCEPTION
            WHEN OTHERS THEN
              fnd_file.put_line(fnd_file.log
                               ,'Exception while exceuting : ' || l_step ||
                                ' : ' || SQLERRM);
            
          END;
        
          IF l_count_line > 1
          THEN
          
            fnd_file.put_line(fnd_file.log
                             ,'Count > 1');
          
            BEGIN
            
              l_step := 'Updating  s3_line_amount for po matched invoices';
              UPDATE xxs3_ptp_invoice_line
              SET s3_line_amount = (SELECT SUM(legacy_dist_amount)
                                    FROM xxs3_ptp_invoice_line
                                    WHERE invoice_id = j.invoice_id
                                    AND invoice_line_num = j.invoice_line_num)
              WHERE invoice_id = j.invoice_id
              AND invoice_line_num = j.invoice_line_num;
            
              fnd_file.put_line(fnd_file.log
                               ,'Deleted : ' || j.invoice_line_num ||
                                ' : ' || j.invoice_line_num);
            
            
              l_step := 'Deleting multiple distrivutions for po matched invoices';
              DELETE FROM xxs3_ptp_invoice_line
              WHERE invoice_id = j.invoice_id
              AND invoice_line_num = j.invoice_line_num
              AND rownum > 1;
            
            
            
            EXCEPTION
              WHEN OTHERS THEN
                fnd_file.put_line(fnd_file.log
                                 ,'Exception while exceuting : ' || l_step ||
                                  ' : ' || SQLERRM);
              
            END;
          
          ELSE
          
            UPDATE xxs3_ptp_invoice_line
            SET s3_line_amount = legacy_line_amount
            WHERE invoice_id = j.invoice_id
            AND invoice_line_num = j.invoice_line_num;
          
          END IF;
        ELSE
        
          l_non_po_matched := 'Y';
        
          UPDATE xxs3_ptp_invoice_line
          SET s3_line_amount = legacy_dist_amount
          WHERE invoice_id = j.invoice_id
          AND invoice_line_num = j.invoice_line_num;
        
        END IF;
      END LOOP;
    
      COMMIT;
    
      IF l_non_po_matched = 'Y'
      THEN
        fnd_file.put_line(fnd_file.log
                         ,'Updating Line numbers');
      
        l_step        := 'Updating Line numbers';
        l_line_number := 0;
      
        FOR k IN (SELECT invoice_id
                        ,invoice_line_num
                  FROM xxs3_ptp_invoice_line
                  WHERE invoice_id = i.invoice_id
                  ORDER BY invoice_line_num)
        LOOP
        
          fnd_file.put_line(fnd_file.log
                           ,'l_line_number' || l_line_number);
          BEGIN
            UPDATE xxs3_ptp_invoice_line
            SET s3_invoice_line_number = l_line_number + 1
            WHERE invoice_id = k.invoice_id;
          
          EXCEPTION
            WHEN OTHERS THEN
              fnd_file.put_line(fnd_file.log
                               ,'Exception while exceuting : ' || l_step ||
                                ' : ' || SQLERRM);
            
          
          END;
        END LOOP;
      
      ELSE
        IF l_non_po_matched = 'N'
        THEN
        
          UPDATE xxs3_ptp_invoice_line
          SET s3_invoice_line_number = invoice_line_num
          WHERE invoice_id = i.invoice_id;
        
        END IF;
      
      END IF;
    
    END LOOP;
  
    -- Update s3 invoice line number for non po matched invoices
  
    COMMIT;
  
    --Transformation
    FOR m IN c_line_data
    LOOP
    
      l_step := 'Transform ship_to_location_code';
      --ship_to_location
      IF m.ship_to_location_code IS NOT NULL
      THEN
        xxs3_data_transform_util_pkg.transform(p_mapping_type => 'location_code_ship'
                                              ,p_stage_tab => 'XXS3_PTP_INVOICE_LINE'
                                              , --Staging Table Name
                                               p_stage_primary_col => 'XX_INVOICE_ID'
                                              , --Staging Table Primary Column Name
                                               p_stage_primary_col_val => m.xx_invoice_id
                                              , --Staging Table Primary Column Value
                                               p_legacy_val => m.ship_to_location_code
                                              , --Legacy Value
                                               p_stage_col => 'S3_SHIP_TO_LOCATION_CODE'
                                              , --Staging Table Name
                                               p_err_code => l_err_code
                                              , -- Output error code
                                               p_err_msg => l_err_msg);
      END IF;
    
      --asset book type code transformation
      IF m.asset_book_type_code IS NOT NULL
      THEN
        l_step := 'Transform asset_book_type_code';
        xxs3_data_transform_util_pkg.transform(p_mapping_type => 'asset_book_type_code'
                                              ,p_stage_tab => 'XXS3_PTP_INVOICE_LINE'
                                              , --Staging Table Name
                                               p_stage_primary_col => 'XX_INVOICE_ID'
                                              , --Staging Table Primary Column Name
                                               p_stage_primary_col_val => m.xx_invoice_id
                                              , --Staging Table Primary Column Value
                                               p_legacy_val => m.asset_book_type_code
                                              , --Legacy Value
                                               p_stage_col => 'S3_ASSET_BOOK_TYPE_CODE'
                                              , --Staging Table Name
                                               p_err_code => l_err_code
                                              , -- Output error code
                                               p_err_msg => l_err_msg);
      END IF;
      --ou transformation
      IF m.operating_unit IS NOT NULL
      THEN
        l_step := 'Transform operating_unit';
        xxs3_data_transform_util_pkg.transform(p_mapping_type => 'organization_name'
                                              ,p_stage_tab => 'XXS3_PTP_INVOICE_LINE'
                                              , --Staging Table Name
                                               p_stage_primary_col => 'XX_INVOICE_ID'
                                              , --Staging Table Primary Column Name
                                               p_stage_primary_col_val => m.xx_invoice_id
                                              , --Staging Table Primary Column Value
                                               p_legacy_val => m.operating_unit
                                              , --Legacy Value
                                               p_stage_col => 'S3_OPERATING_UNIT'
                                              , --Staging Table Name
                                               p_err_code => l_err_code
                                              , -- Output error code
                                               p_err_msg => l_err_msg);
      END IF;
      --expenditure ou transformation                                       
      IF m.expenditure_operating_unit IS NOT NULL
      THEN
        l_step := 'Transform expenditure_operating_unit';
        xxs3_data_transform_util_pkg.transform(p_mapping_type => 'expenditure_orgs_ptp'
                                              ,p_stage_tab => 'XXS3_PTP_INVOICE_LINE'
                                              , --Staging Table Name
                                               p_stage_primary_col => 'XX_INVOICE_ID'
                                              , --Staging Table Primary Column Name
                                               p_stage_primary_col_val => m.xx_invoice_id
                                              , --Staging Table Primary Column Value
                                               p_legacy_val => m.expenditure_operating_unit
                                              , --Legacy Value
                                               p_stage_col => 'S3_EXPENDITURE_OPERATING_UNIT'
                                              , --Staging Table Name
                                               p_err_code => l_err_code
                                              , -- Output error code
                                               p_err_msg => l_err_msg);
      
      END IF;
      ----expenditure ou transformation at line level
      IF m.expenditure_org_line IS NOT NULL
      THEN
        l_step := 'Transform expenditure_org_line';
        xxs3_data_transform_util_pkg.transform(p_mapping_type => 'expenditure_orgs_ptp'
                                              ,p_stage_tab => 'XXS3_PTP_INVOICE_LINE'
                                              , --Staging Table Name
                                               p_stage_primary_col => 'XX_INVOICE_ID'
                                              , --Staging Table Primary Column Name
                                               p_stage_primary_col_val => m.xx_invoice_id
                                              , --Staging Table Primary Column Value
                                               p_legacy_val => m.expenditure_org_line
                                              , --Legacy Value
                                               p_stage_col => 'S3_EXPENDITURE_ORG_LINE'
                                              , --Staging Table Name
                                               p_err_code => l_err_code
                                              , -- Output error code
                                               p_err_msg => l_err_msg);
      
      END IF;
      --expenditure type transformation
    
      IF m.expenditure_type IS NOT NULL
      THEN
        l_step := 'Transform expenditure_type';
        xxs3_data_transform_util_pkg.transform(p_mapping_type => 'expenditure_type_ptp'
                                              ,p_stage_tab => 'XXS3_PTP_INVOICE_LINE'
                                              , --Staging Table Name
                                               p_stage_primary_col => 'XX_INVOICE_ID'
                                              , --Staging Table Primary Column Name
                                               p_stage_primary_col_val => m.xx_invoice_id
                                              , --Staging Table Primary Column Value
                                               p_legacy_val => m.expenditure_type
                                              , --Legacy Value
                                               p_stage_col => 'S3_EXPENDITURE_TYPE'
                                              , --Staging Table Name
                                               p_err_code => l_err_code
                                              , -- Output error code
                                               p_err_msg => l_err_msg);
      
      END IF;
    
      IF m.expenditure_type_line IS NOT NULL
      THEN
        l_step := 'Transform expenditure_type_line';
        xxs3_data_transform_util_pkg.transform(p_mapping_type => 'expenditure_type_ptp'
                                              ,p_stage_tab => 'XXS3_PTP_INVOICE_LINE'
                                              , --Staging Table Name
                                               p_stage_primary_col => 'XX_INVOICE_ID'
                                              , --Staging Table Primary Column Name
                                               p_stage_primary_col_val => m.xx_invoice_id
                                              , --Staging Table Primary Column Value
                                               p_legacy_val => m.expenditure_type_line
                                              , --Legacy Value
                                               p_stage_col => 'S3_EXPENDITURE_TYPE_LINE'
                                              , --Staging Table Name
                                               p_err_code => l_err_code
                                              , -- Output error code
                                               p_err_msg => l_err_msg);
      
      END IF;
      --project transformation
    
      IF m.project IS NOT NULL
      THEN
        l_step := 'Transform project';
        xxs3_data_transform_util_pkg.transform(p_mapping_type => 'projects_ptp'
                                              ,p_stage_tab => 'XXS3_PTP_INVOICE_LINE'
                                              , --Staging Table Name
                                               p_stage_primary_col => 'XX_INVOICE_ID'
                                              , --Staging Table Primary Column Name
                                               p_stage_primary_col_val => m.xx_invoice_id
                                              , --Staging Table Primary Column Value
                                               p_legacy_val => m.project
                                              , --Legacy Value
                                               p_stage_col => 'S3_PROJECT'
                                              , --Staging Table Name
                                               p_err_code => l_err_code
                                              , -- Output error code
                                               p_err_msg => l_err_msg);
      END IF;
    
      IF m.project_line IS NOT NULL
      THEN
        l_step := 'Transform project_line';
        xxs3_data_transform_util_pkg.transform(p_mapping_type => 'projects_ptp'
                                              ,p_stage_tab => 'XXS3_PTP_INVOICE_LINE'
                                              , --Staging Table Name
                                               p_stage_primary_col => 'XX_INVOICE_ID'
                                              , --Staging Table Primary Column Name
                                               p_stage_primary_col_val => m.xx_invoice_id
                                              , --Staging Table Primary Column Value
                                               p_legacy_val => m.project_line
                                              , --Legacy Value
                                               p_stage_col => 'S3_PROJECT_LINE'
                                              , --Staging Table Name
                                               p_err_code => l_err_code
                                              , -- Output error code
                                               p_err_msg => l_err_msg);
      END IF;
      --task transformation
      IF m.task IS NOT NULL
      THEN
        l_step := 'Transform task';
        xxs3_data_transform_util_pkg.transform(p_mapping_type => 'task_ptp'
                                              ,p_stage_tab => 'XXS3_PTP_INVOICE_LINE'
                                              , --Staging Table Name
                                               p_stage_primary_col => 'XX_INVOICE_ID'
                                              , --Staging Table Primary Column Name
                                               p_stage_primary_col_val => m.xx_invoice_id
                                              , --Staging Table Primary Column Value
                                               p_legacy_val => m.task
                                              , --Legacy Value
                                               p_stage_col => 'S3_TASK'
                                              , --Staging Table Name
                                               p_other_col => m.task_id
                                              ,p_err_code => l_err_code
                                              , -- Output error code
                                               p_err_msg => l_err_msg);
      END IF;
    
      IF m.task_line IS NOT NULL
      THEN
        l_step := 'Transform task_line';
        xxs3_data_transform_util_pkg.transform(p_mapping_type => 'task_ptp'
                                              ,p_stage_tab => 'XXS3_PTP_INVOICE_LINE'
                                              , --Staging Table Name
                                               p_stage_primary_col => 'XX_INVOICE_ID'
                                              , --Staging Table Primary Column Name
                                               p_stage_primary_col_val => m.xx_invoice_id
                                              , --Staging Table Primary Column Value
                                               p_legacy_val => m.task_line
                                              , --Legacy Value
                                               p_stage_col => 'S3_TASK_LINE'
                                              , --Staging Table Name
                                               p_other_col => m.task_id_line
                                              ,p_err_code => l_err_code
                                              , -- Output error code
                                               p_err_msg => l_err_msg);
      END IF;
      --CoA transformation     
    
      IF m.default_distribution_account IS NOT NULL
      THEN
        /*  xxs3_data_transform_util_pkg.coa_transform(p_field_name => 'DEFAULT_DISTRIBUTION_ACCOUNT'
                                                  ,p_legacy_company_val => m.default_distribution_segment1
                                                  , --Legacy Company Value
                                                   p_legacy_department_val => m.default_distribution_segment2
                                                  , --Legacy Department Value
                                                   p_legacy_account_val => m.default_distribution_segment3
                                                  , --Legacy Account Value
                                                   p_legacy_product_val => m.default_distribution_segment5
                                                  , --Legacy Product Value
                                                   p_legacy_location_val => m.default_distribution_segment6
                                                  , --Legacy Location Value
                                                   p_legacy_intercompany_val => m.default_distribution_segment7
                                                  , --Legacy Intercompany Value
                                                   p_legacy_division_val => m.default_distribution_segment10
                                                  , --Legacy Division Value
                                                   p_item_number => m.item
                                                  ,p_s3_gl_string => l_s3_gl_string
                                                  ,p_err_code => l_output_code
                                                  ,p_err_msg => l_output); --Output Message   
        
        xxs3_data_transform_util_pkg.coa_update(p_gl_string => l_s3_gl_string
                                               ,p_stage_tab => 'XXS3_PTP_INVOICE_LINE'
                                               ,p_stage_primary_col => 'XX_INVOICE_ID'
                                               ,p_stage_primary_col_val => m.xx_invoice_id
                                               ,p_stage_company_col => 'S3_DEFAULT_DIST_SEGMENT1'
                                               ,p_stage_business_unit_col => 'S3_DEFAULT_DIST_SEGMENT2'
                                               ,p_stage_department_col => 'S3_DEFAULT_DIST_SEGMENT3'
                                               ,p_stage_account_col => 'S3_DEFAULT_DIST_SEGMENT4'
                                               ,p_stage_product_line_col => 'S3_DEFAULT_DIST_SEGMENT5'
                                               ,p_stage_location_col => 'S3_DEFAULT_DIST_SEGMENT6'
                                               ,p_stage_intercompany_col => 'S3_DEFAULT_DIST_SEGMENT7'
                                               ,p_stage_future_col => 'S3_DEFAULT_DIST_SEGMENT8'
                                               ,p_coa_err_msg => l_output
                                               ,p_err_code => l_output_code_coa_update
                                               ,p_err_msg => l_output_coa_update);*/
      
      
      
        xxs3_coa_transform_pkg.coa_transform(p_field_name => 'DEFAULT_DISTRIBUTION_ACCOUNT'
                                            ,p_legacy_company_val => m.default_distribution_segment1 --Legacy Company Value
                                            ,p_legacy_department_val => m.default_distribution_segment2 --Legacy Department Value
                                            ,p_legacy_account_val => m.default_distribution_segment3 --Legacy Account Value
                                            ,p_legacy_product_val => m.default_distribution_segment5 --Legacy Product Value
                                            ,p_legacy_location_val => m.default_distribution_segment6 --Legacy Location Value
                                            ,p_legacy_intercompany_val => m.default_distribution_segment7 --Legacy Intercompany Value
                                            ,p_legacy_division_val => m.default_distribution_segment10 --Legacy Division Value
                                            ,p_item_number => NULL
                                            ,p_s3_org => NULL
                                            ,p_trx_type => 'ALL'
                                            ,p_set_of_books_id => NULL
                                            ,p_debug_flag => 'N'
                                            ,p_s3_gl_string => l_s3_gl_string
                                            ,p_err_code => l_output_code
                                            ,p_err_msg => l_output);
      
      
      
        xxs3_coa_transform_pkg.coa_update(p_gl_string => l_s3_gl_string
                                         ,p_stage_tab => 'XXS3_PTP_INVOICE_LINE'
                                         ,p_stage_primary_col => 'XX_INVOICE_ID'
                                         ,p_stage_primary_col_val => m.xx_invoice_id
                                         ,p_stage_company_col => 'S3_DEFAULT_DIST_SEGMENT1'
                                         ,p_stage_business_unit_col => 'S3_DEFAULT_DIST_SEGMENT2'
                                         ,p_stage_department_col => 'S3_DEFAULT_DIST_SEGMENT3'
                                         ,p_stage_account_col => 'S3_DEFAULT_DIST_SEGMENT4'
                                         ,p_stage_product_line_col => 'S3_DEFAULT_DIST_SEGMENT5'
                                         ,p_stage_location_col => 'S3_DEFAULT_DIST_SEGMENT6'
                                         ,p_stage_intercompany_col => 'S3_DEFAULT_DIST_SEGMENT7'
                                         ,p_stage_future_col => 'S3_DEFAULT_DIST_SEGMENT8'
                                         ,p_coa_err_msg => l_output
                                         ,p_err_code => l_output_code_coa_update
                                         ,p_err_msg => l_output_coa_update);
      
      
      
      END IF;
    
      IF m.dist_code_concatenated IS NOT NULL
      THEN
        /* xxs3_data_transform_util_pkg.coa_transform(p_field_name => 'DIST_CODE_CONCATENATED'
                                                  ,p_legacy_company_val => m.dist_code_segment1
                                                  , --Legacy Company Value
                                                   p_legacy_department_val => m.dist_code_segment2
                                                  , --Legacy Department Value
                                                   p_legacy_account_val => m.dist_code_segment3
                                                  , --Legacy Account Value
                                                   p_legacy_product_val => m.dist_code_segment5
                                                  , --Legacy Product Value
                                                   p_legacy_location_val => m.dist_code_segment6
                                                  , --Legacy Location Value
                                                   p_legacy_intercompany_val => m.dist_code_segment7
                                                  , --Legacy Intercompany Value
                                                   p_legacy_division_val => m.dist_code_segment10
                                                  , --Legacy Division Value
                                                   p_item_number => m.item
                                                  ,p_s3_gl_string => l_s3_gl_string
                                                  ,p_err_code => l_output_code
                                                  ,p_err_msg => l_output); --Output Message   
        
        xxs3_data_transform_util_pkg.coa_update(p_gl_string => l_s3_gl_string
                                               ,p_stage_tab => 'XXS3_PTP_INVOICE_LINE'
                                               ,p_stage_primary_col => 'XX_INVOICE_ID'
                                               ,p_stage_primary_col_val => m.xx_invoice_id
                                               ,p_stage_company_col => 'S3_DIST_CODE_SEGMENT1'
                                               ,p_stage_business_unit_col => 'S3_DIST_CODE_SEGMENT2'
                                               ,p_stage_department_col => 'S3_DIST_CODE_SEGMENT3'
                                               ,p_stage_account_col => 'S3_DIST_CODE_SEGMENT4'
                                               ,p_stage_product_line_col => 'S3_DIST_CODE_SEGMENT5'
                                               ,p_stage_location_col => 'S3_DIST_CODE_SEGMENT6'
                                               ,p_stage_intercompany_col => 'S3_DIST_CODE_SEGMENT7'
                                               ,p_stage_future_col => 'S3_DIST_CODE_SEGMENT8'
                                               ,p_coa_err_msg => l_output
                                               ,p_err_code => l_output_code_coa_update
                                               ,p_err_msg => l_output_coa_update);*/
      
        xxs3_coa_transform_pkg.coa_transform(p_field_name => 'DIST_CODE_CONCATENATED'
                                            ,p_legacy_company_val => m.dist_code_segment1 --Legacy Company Value
                                            ,p_legacy_department_val => m.dist_code_segment2 --Legacy Department Value
                                            ,p_legacy_account_val => m.dist_code_segment3 --Legacy Account Value
                                            ,p_legacy_product_val => m.dist_code_segment5 --Legacy Product Value
                                            ,p_legacy_location_val => m.dist_code_segment6 --Legacy Location Value
                                            ,p_legacy_intercompany_val => m.dist_code_segment7 --Legacy Intercompany Value
                                            ,p_legacy_division_val => m.dist_code_segment10 --Legacy Division Value
                                            ,p_item_number => NULL
                                            ,p_s3_org => NULL
                                            ,p_trx_type => 'ALL'
                                            ,p_set_of_books_id => NULL
                                            ,p_debug_flag => 'N'
                                            ,p_s3_gl_string => l_s3_gl_string
                                            ,p_err_code => l_output_code
                                            ,p_err_msg => l_output);
      
      
      
        xxs3_coa_transform_pkg.coa_update(p_gl_string => l_s3_gl_string
                                         ,p_stage_tab => 'XXS3_PTP_INVOICE_LINE'
                                         ,p_stage_primary_col => 'XX_INVOICE_ID'
                                         ,p_stage_primary_col_val => m.xx_invoice_id
                                         ,p_stage_company_col => 'S3_DIST_CODE_SEGMENT1'
                                         ,p_stage_business_unit_col => 'S3_DIST_CODE_SEGMENT2'
                                         ,p_stage_department_col => 'S3_DIST_CODE_SEGMENT3'
                                         ,p_stage_account_col => 'S3_DIST_CODE_SEGMENT4'
                                         ,p_stage_product_line_col => 'S3_DIST_CODE_SEGMENT5'
                                         ,p_stage_location_col => 'S3_DIST_CODE_SEGMENT6'
                                         ,p_stage_intercompany_col => 'S3_DIST_CODE_SEGMENT7'
                                         ,p_stage_future_col => 'S3_DIST_CODE_SEGMENT8'
                                         ,p_coa_err_msg => l_output
                                         ,p_err_code => l_output_code_coa_update
                                         ,p_err_msg => l_output_coa_update);
      
      
      END IF;
    END LOOP;
  
    --generate csv
    utl_file.put(l_file
                ,'~' || 'XX_INVOICE_ID');
    utl_file.put(l_file
                ,'~' || 'DATE_EXTRACTED_ON');
    utl_file.put(l_file
                ,'~' || 'PROCESS_FLAG');
    utl_file.put(l_file
                ,'~' || 'INVOICE_NUM');
    utl_file.put(l_file
                ,'~' || 'INVOICE_ID');
    utl_file.put(l_file
                ,'~' || 'S3_INVOICE_ID');
    utl_file.put(l_file
                ,'~' || 'AMOUNT');
    utl_file.put(l_file
                ,'~' || 'INVOICE_LINE_NUM');
    utl_file.put(l_file
                ,'~' || 'LINE_GROUP_NUMBER');
    utl_file.put(l_file
                ,'~' || 'LINE_TYPE_LOOKUP_CODE');
    utl_file.put(l_file
                ,'~' || 'NOTES');
    utl_file.put(l_file
                ,'~' || 'ACCOUNT_SEGMENT');
    utl_file.put(l_file
                ,'~' || 'ASSETS_TRACKING_FLAG');
    utl_file.put(l_file
                ,'~' || 'ASSET_BOOK_TYPE_CODE');
    utl_file.put(l_file
                ,'~' || 'S3_ASSET_BOOK_TYPE_CODE');
    utl_file.put(l_file
                ,'~' || 'ASSET_CATEGORY_ID');
    utl_file.put(l_file
                ,'~' || 'ATTRIBUTE1');
    utl_file.put(l_file
                ,'~' || 'ATTRIBUTE2');
    utl_file.put(l_file
                ,'~' || 'ATTRIBUTE3');
    utl_file.put(l_file
                ,'~' || 'ATTRIBUTE4');
    utl_file.put(l_file
                ,'~' || 'ATTRIBUTE5');
    utl_file.put(l_file
                ,'~' || 'ATTRIBUTE6');
    utl_file.put(l_file
                ,'~' || 'ATTRIBUTE7');
    utl_file.put(l_file
                ,'~' || 'ATTRIBUTE8');
    utl_file.put(l_file
                ,'~' || 'ATTRIBUTE9');
    utl_file.put(l_file
                ,'~' || 'ATTRIBUTE10');
    utl_file.put(l_file
                ,'~' || 'ATTRIBUTE11');
    utl_file.put(l_file
                ,'~' || 'ATTRIBUTE12');
    utl_file.put(l_file
                ,'~' || 'ATTRIBUTE13');
    utl_file.put(l_file
                ,'~' || 'ATTRIBUTE14');
    utl_file.put(l_file
                ,'~' || 'ATTRIBUTE15');
    utl_file.put(l_file
                ,'~' || 'ATTRIBUTE_CATEGORY');
    utl_file.put(l_file
                ,'~' || 'BALANCING_SEGMENT');
    utl_file.put(l_file
                ,'~' || 'CONTROL_AMOUNT');
    utl_file.put(l_file
                ,'~' || 'COST_CENTER_SEGMENT');
    utl_file.put(l_file
                ,'~' || 'COUNTRY_OF_SUPPLY');
    utl_file.put(l_file
                ,'~' || 'DEFAULT_DISTRIBUTION_ACCOUNT');
    utl_file.put(l_file
                ,'~' || 'DEFAULT_DISTRIBUTION_SEGMENT1');
    utl_file.put(l_file
                ,'~' || 'DEFAULT_DISTRIBUTION_SEGMENT2');
    utl_file.put(l_file
                ,'~' || 'DEFAULT_DISTRIBUTION_SEGMENT3');
    utl_file.put(l_file
                ,'~' || 'DEFAULT_DISTRIBUTION_SEGMENT5');
    utl_file.put(l_file
                ,'~' || 'DEFAULT_DISTRIBUTION_SEGMENT6');
    utl_file.put(l_file
                ,'~' || 'DEFAULT_DISTRIBUTION_SEGMENT7');
    utl_file.put(l_file
                ,'~' || 'DEFAULT_DISTRIBUTION_SEGMENT10');
    utl_file.put(l_file
                ,'~' || 'S3_DEFAULT_DIST_SEGMENT1');
    utl_file.put(l_file
                ,'~' || 'S3_DEFAULT_DIST_SEGMENT2');
    utl_file.put(l_file
                ,'~' || 'S3_DEFAULT_DIST_SEGMENT3');
    utl_file.put(l_file
                ,'~' || 'S3_DEFAULT_DIST_SEGMENT4');
    utl_file.put(l_file
                ,'~' || 'S3_DEFAULT_DIST_SEGMENT5');
    utl_file.put(l_file
                ,'~' || 'S3_DEFAULT_DIST_SEGMENT6');
    utl_file.put(l_file
                ,'~' || 'S3_DEFAULT_DIST_SEGMENT7');
    utl_file.put(l_file
                ,'~' || 'S3_DEFAULT_DIST_SEGMENT8');
    utl_file.put(l_file
                ,'~' || 'DEFERRED_ACCTG_FLAG');
    utl_file.put(l_file
                ,'~' || 'DEF_ACCTG_END_DATE');
    utl_file.put(l_file
                ,'~' || 'DEF_ACCTG_NUMBER_OF_PERIODS');
    utl_file.put(l_file
                ,'~' || 'DEF_ACCTG_PERIOD_TYPE');
    utl_file.put(l_file
                ,'~' || 'DEF_ACCTG_START_DATE');
    utl_file.put(l_file
                ,'~' || 'DESCRIPTION');
    utl_file.put(l_file
                ,'~' || 'DISTRIBUTION_SET_NAME');
    utl_file.put(l_file
                ,'~' || 'DIST_CODE_CONCATENATED');
    utl_file.put(l_file
                ,'~' || 'DIST_CODE_SEGMENT1');
    utl_file.put(l_file
                ,'~' || 'DIST_CODE_SEGMENT2');
    utl_file.put(l_file
                ,'~' || 'DIST_CODE_SEGMENT3');
    utl_file.put(l_file
                ,'~' || 'DIST_CODE_SEGMENT5');
    utl_file.put(l_file
                ,'~' || 'DIST_CODE_SEGMENT6');
    utl_file.put(l_file
                ,'~' || 'DIST_CODE_SEGMENT7');
    utl_file.put(l_file
                ,'~' || 'DIST_CODE_SEGMENT10');
    utl_file.put(l_file
                ,'~' || 'S3_DIST_CODE_SEGMENT1');
    utl_file.put(l_file
                ,'~' || 'S3_DIST_CODE_SEGMENT2');
    utl_file.put(l_file
                ,'~' || 'S3_DIST_CODE_SEGMENT3');
    utl_file.put(l_file
                ,'~' || 'S3_DIST_CODE_SEGMENT4');
    utl_file.put(l_file
                ,'~' || 'S3_DIST_CODE_SEGMENT5');
    utl_file.put(l_file
                ,'~' || 'S3_DIST_CODE_SEGMENT6');
    utl_file.put(l_file
                ,'~' || 'S3_DIST_CODE_SEGMENT7');
    utl_file.put(l_file
                ,'~' || 'S3_DIST_CODE_SEGMENT8');
    utl_file.put(l_file
                ,'~' || 'EXPENDITURE_ITEM_DATE');
    utl_file.put(l_file
                ,'~' || 'EXPENDITURE_ORG_LINE');
    utl_file.put(l_file
                ,'~' || 'S3_EXPENDITURE_ORG_LINE');
    utl_file.put(l_file
                ,'~' || 'EXPENDITURE_OPERATING_UNIT');
    utl_file.put(l_file
                ,'~' || 'S3_EXPENDITURE_OPERATING_UNIT');
    utl_file.put(l_file
                ,'~' || 'EXPENDITURE_TYPE_LINE');
    utl_file.put(l_file
                ,'~' || 'S3_EXPENDITURE_TYPE_LINE');
    utl_file.put(l_file
                ,'~' || 'EXPENDITURE_TYPE');
    utl_file.put(l_file
                ,'~' || 'S3_EXPENDITURE_TYPE');
    utl_file.put(l_file
                ,'~' || 'FINAL_MATCH_FLAG');
    utl_file.put(l_file
                ,'~' || 'GLOBAL_ATTRIBUTE1');
    utl_file.put(l_file
                ,'~' || 'GLOBAL_ATTRIBUTE2');
    utl_file.put(l_file
                ,'~' || 'GLOBAL_ATTRIBUTE3');
    utl_file.put(l_file
                ,'~' || 'GLOBAL_ATTRIBUTE4');
    utl_file.put(l_file
                ,'~' || 'GLOBAL_ATTRIBUTE5');
    utl_file.put(l_file
                ,'~' || 'GLOBAL_ATTRIBUTE6');
    utl_file.put(l_file
                ,'~' || 'GLOBAL_ATTRIBUTE7');
    utl_file.put(l_file
                ,'~' || 'GLOBAL_ATTRIBUTE8');
    utl_file.put(l_file
                ,'~' || 'GLOBAL_ATTRIBUTE9');
    utl_file.put(l_file
                ,'~' || 'GLOBAL_ATTRIBUTE10');
    utl_file.put(l_file
                ,'~' || 'GLOBAL_ATTRIBUTE11');
    utl_file.put(l_file
                ,'~' || 'GLOBAL_ATTRIBUTE12');
    utl_file.put(l_file
                ,'~' || 'GLOBAL_ATTRIBUTE13');
    utl_file.put(l_file
                ,'~' || 'GLOBAL_ATTRIBUTE14');
    utl_file.put(l_file
                ,'~' || 'GLOBAL_ATTRIBUTE15');
    utl_file.put(l_file
                ,'~' || 'GLOBAL_ATTRIBUTE16');
    utl_file.put(l_file
                ,'~' || 'GLOBAL_ATTRIBUTE17');
    utl_file.put(l_file
                ,'~' || 'GLOBAL_ATTRIBUTE18');
    utl_file.put(l_file
                ,'~' || 'GLOBAL_ATTRIBUTE19');
    utl_file.put(l_file
                ,'~' || 'GLOBAL_ATTRIBUTE20');
    utl_file.put(l_file
                ,'~' || 'GLOBAL_ATTRIBUTE_CATEGORY');
    utl_file.put(l_file
                ,'~' || 'AMOUNT_INCLUDES_TAX_FLAG');
    utl_file.put(l_file
                ,'~' || 'INCOME_TAX_REGION');
    utl_file.put(l_file
                ,'~' || 'ITEM');
    utl_file.put(l_file
                ,'~' || 'ITEM_DESCRIPTION');
    utl_file.put(l_file
                ,'~' || 'JUSTIFICATION');
    utl_file.put(l_file
                ,'~' || 'MANUFACTURER');
    utl_file.put(l_file
                ,'~' || 'DIST_MATCH_TYPE');
    utl_file.put(l_file
                ,'~' || 'MODEL_NUMBER');
    utl_file.put(l_file
                ,'~' || 'OPERATING_UNIT');
    utl_file.put(l_file
                ,'~' || 'S3_OPERATING_UNIT');
    utl_file.put(l_file
                ,'~' || 'PA_ADDITION_FLAG');
    utl_file.put(l_file
                ,'~' || 'PA_QUANTITY');
    utl_file.put(l_file
                ,'~' || 'PO_DISTRIBUTION_NUM');
    utl_file.put(l_file
                ,'~' || 'PO_LINE_NUMBER');
    utl_file.put(l_file
                ,'~' || 'PO_NUMBER');
    utl_file.put(l_file
                ,'~' || 'PO_SHIPMENT_NUM');
    utl_file.put(l_file
                ,'~' || 'PRIMARY_INTENDED_USE');
    utl_file.put(l_file
                ,'~' || 'PRODUCT_CATEGORY');
    utl_file.put(l_file
                ,'~' || 'PRODUCT_FISC_CLASSIFICATION');
    utl_file.put(l_file
                ,'~' || 'PRODUCT_TABLE');
    utl_file.put(l_file
                ,'~' || 'PRODUCT_TYPE');
    utl_file.put(l_file
                ,'~' || 'PROJECT_ACCOUNTING_CONTEXT');
    utl_file.put(l_file
                ,'~' || 'PROJECT_LINE');
    utl_file.put(l_file
                ,'~' || 'S3_PROJECT_LINE');
    utl_file.put(l_file
                ,'~' || 'PROJECT');
    utl_file.put(l_file
                ,'~' || 'S3_PROJECT');
    utl_file.put(l_file
                ,'~' || 'PRORATE_ACROSS_ALL_ITEMS');
    utl_file.put(l_file
                ,'~' || 'QUANTITY_INVOICED');
    utl_file.put(l_file
                ,'~' || 'RECEIPT_CONVERSION_RATE');
    utl_file.put(l_file
                ,'~' || 'RECEIPT_CURRENCY_AMOUNT');
    utl_file.put(l_file
                ,'~' || 'RECEIPT_CURRENCY_CODE');
    utl_file.put(l_file
                ,'~' || 'RECEIPT_LINE_NUMBER');
    utl_file.put(l_file
                ,'~' || 'RECEIPT_NUMBER');
    utl_file.put(l_file
                ,'~' || 'RELEASE_NUM');
    utl_file.put(l_file
                ,'~' || 'REQUESTER_EMPLOYEE_NUM');
    utl_file.put(l_file
                ,'~' || 'SERIAL_NUMBER');
    utl_file.put(l_file
                ,'~' || 'SHIP_TO_LOCATION_CODE');
    utl_file.put(l_file
                ,'~' || 'S3_SHIP_TO_LOCATION_CODE');
    utl_file.put(l_file
                ,'~' || 'TASK_LINE');
    utl_file.put(l_file
                ,'~' || 'S3_TASK_LINE');
    utl_file.put(l_file
                ,'~' || 'TASK');
    utl_file.put(l_file
                ,'~' || 'S3_TASK');
    utl_file.put(l_file
                ,'~' || 'TYPE_1099');
    utl_file.put(l_file
                ,'~' || 'UNIT_MEAS_LOOKUP_CODE');
    utl_file.put(l_file
                ,'~' || 'UNIT_PRICE');
    utl_file.put(l_file
                ,'~' || 'WARRANTY_NUMBER');
    utl_file.put(l_file
                ,'~' || 'TRANSFORM_STATUS');
    utl_file.put(l_file
                ,'~' || 'TRANSFORM_ERROR');
    utl_file.new_line(l_file);
  
  
    FOR c1 IN c_line_data
    LOOP
      utl_file.put(l_file
                  ,'~' || c1.xx_invoice_id);
      utl_file.put(l_file
                  ,'~' || c1.date_extracted_on);
      utl_file.put(l_file
                  ,'~' || c1.process_flag);
      utl_file.put(l_file
                  ,'~' || c1.invoice_num);
      utl_file.put(l_file
                  ,'~' || c1.invoice_id);
      utl_file.put(l_file
                  ,'~' || c1.s3_invoice_id);
      utl_file.put(l_file
                  ,'~' || c1.legacy_dist_amount);
      utl_file.put(l_file
                  ,'~' || c1.invoice_line_num);
      utl_file.put(l_file
                  ,'~' || c1.line_group_number);
      utl_file.put(l_file
                  ,'~' || c1.line_type_lookup_code);
      utl_file.put(l_file
                  ,'~' || c1.notes);
      utl_file.put(l_file
                  ,'~' || c1.account_segment);
      utl_file.put(l_file
                  ,'~' || c1.assets_tracking_flag);
      utl_file.put(l_file
                  ,'~' || c1.asset_book_type_code);
      utl_file.put(l_file
                  ,'~' || c1.s3_asset_book_type_code);
      utl_file.put(l_file
                  ,'~' || c1.asset_category_id);
      utl_file.put(l_file
                  ,'~' || c1.attribute1);
      utl_file.put(l_file
                  ,'~' || c1.attribute2);
      utl_file.put(l_file
                  ,'~' || c1.attribute3);
      utl_file.put(l_file
                  ,'~' || c1.attribute4);
      utl_file.put(l_file
                  ,'~' || c1.attribute5);
      utl_file.put(l_file
                  ,'~' || c1.attribute6);
      utl_file.put(l_file
                  ,'~' || c1.attribute7);
      utl_file.put(l_file
                  ,'~' || c1.attribute8);
      utl_file.put(l_file
                  ,'~' || c1.attribute9);
      utl_file.put(l_file
                  ,'~' || c1.attribute10);
      utl_file.put(l_file
                  ,'~' || c1.attribute11);
      utl_file.put(l_file
                  ,'~' || c1.attribute12);
      utl_file.put(l_file
                  ,'~' || c1.attribute13);
      utl_file.put(l_file
                  ,'~' || c1.attribute14);
      utl_file.put(l_file
                  ,'~' || c1.attribute15);
      utl_file.put(l_file
                  ,'~' || c1.attribute_category);
      utl_file.put(l_file
                  ,'~' || c1.balancing_segment);
      utl_file.put(l_file
                  ,'~' || c1.control_amount);
      utl_file.put(l_file
                  ,'~' || c1.cost_center_segment);
      utl_file.put(l_file
                  ,'~' || c1.country_of_supply);
      utl_file.put(l_file
                  ,'~' || c1.default_distribution_account);
      utl_file.put(l_file
                  ,'~' || c1.default_distribution_segment1);
      utl_file.put(l_file
                  ,'~' || c1.default_distribution_segment2);
      utl_file.put(l_file
                  ,'~' || c1.default_distribution_segment3);
      utl_file.put(l_file
                  ,'~' || c1.default_distribution_segment5);
      utl_file.put(l_file
                  ,'~' || c1.default_distribution_segment6);
      utl_file.put(l_file
                  ,'~' || c1.default_distribution_segment7);
      utl_file.put(l_file
                  ,'~' || c1.default_distribution_segment10);
      utl_file.put(l_file
                  ,'~' || c1.s3_default_dist_segment1);
      utl_file.put(l_file
                  ,'~' || c1.s3_default_dist_segment2);
      utl_file.put(l_file
                  ,'~' || c1.s3_default_dist_segment3);
      utl_file.put(l_file
                  ,'~' || c1.s3_default_dist_segment4);
      utl_file.put(l_file
                  ,'~' || c1.s3_default_dist_segment5);
      utl_file.put(l_file
                  ,'~' || c1.s3_default_dist_segment6);
      utl_file.put(l_file
                  ,'~' || c1.s3_default_dist_segment7);
      utl_file.put(l_file
                  ,'~' || c1.s3_default_dist_segment8);
      utl_file.put(l_file
                  ,'~' || c1.deferred_acctg_flag);
      utl_file.put(l_file
                  ,'~' || c1.def_acctg_end_date);
      utl_file.put(l_file
                  ,'~' || c1.def_acctg_number_of_periods);
      utl_file.put(l_file
                  ,'~' || c1.def_acctg_period_type);
      utl_file.put(l_file
                  ,'~' || c1.def_acctg_start_date);
      utl_file.put(l_file
                  ,'~' || (REPLACE(REPLACE(REPLACE(REPLACE(c1.description
                                                          ,','
                                                          ,' ')
                                                  ,'"'
                                                  ,' ')
                                          ,chr(10)
                                          ,' ')
                                  ,chr(13)
                                  ,' ')));
      utl_file.put(l_file
                  ,'~' || c1.distribution_set_name);
      utl_file.put(l_file
                  ,'~' || c1.dist_code_concatenated);
      utl_file.put(l_file
                  ,'~' || c1.dist_code_segment1);
      utl_file.put(l_file
                  ,'~' || c1.dist_code_segment2);
      utl_file.put(l_file
                  ,'~' || c1.dist_code_segment3);
      utl_file.put(l_file
                  ,'~' || c1.dist_code_segment5);
      utl_file.put(l_file
                  ,'~' || c1.dist_code_segment6);
      utl_file.put(l_file
                  ,'~' || c1.dist_code_segment7);
      utl_file.put(l_file
                  ,'~' || c1.dist_code_segment10);
      utl_file.put(l_file
                  ,'~' || c1.s3_dist_code_segment1);
      utl_file.put(l_file
                  ,'~' || c1.s3_dist_code_segment2);
      utl_file.put(l_file
                  ,'~' || c1.s3_dist_code_segment3);
      utl_file.put(l_file
                  ,'~' || c1.s3_dist_code_segment4);
      utl_file.put(l_file
                  ,'~' || c1.s3_dist_code_segment5);
      utl_file.put(l_file
                  ,'~' || c1.s3_dist_code_segment6);
      utl_file.put(l_file
                  ,'~' || c1.s3_dist_code_segment7);
      utl_file.put(l_file
                  ,'~' || c1.s3_dist_code_segment8);
      utl_file.put(l_file
                  ,'~' || c1.expenditure_item_date);
      utl_file.put(l_file
                  ,'~' || c1.expenditure_org_line);
      utl_file.put(l_file
                  ,'~' || c1.s3_expenditure_org_line);
      utl_file.put(l_file
                  ,'~' || c1.expenditure_operating_unit);
      utl_file.put(l_file
                  ,'~' || c1.s3_expenditure_operating_unit);
      utl_file.put(l_file
                  ,'~' || c1.expenditure_type_line);
      utl_file.put(l_file
                  ,'~' || c1.s3_expenditure_type_line);
      utl_file.put(l_file
                  ,'~' || c1.expenditure_type);
      utl_file.put(l_file
                  ,'~' || c1.s3_expenditure_type);
      utl_file.put(l_file
                  ,'~' || c1.final_match_flag);
      utl_file.put(l_file
                  ,'~' || c1.global_attribute1);
      utl_file.put(l_file
                  ,'~' || c1.global_attribute2);
      utl_file.put(l_file
                  ,'~' || c1.global_attribute3);
      utl_file.put(l_file
                  ,'~' || c1.global_attribute4);
      utl_file.put(l_file
                  ,'~' || c1.global_attribute5);
      utl_file.put(l_file
                  ,'~' || c1.global_attribute6);
      utl_file.put(l_file
                  ,'~' || c1.global_attribute7);
      utl_file.put(l_file
                  ,'~' || c1.global_attribute8);
      utl_file.put(l_file
                  ,'~' || c1.global_attribute9);
      utl_file.put(l_file
                  ,'~' || c1.global_attribute10);
      utl_file.put(l_file
                  ,'~' || c1.global_attribute11);
      utl_file.put(l_file
                  ,'~' || c1.global_attribute12);
      utl_file.put(l_file
                  ,'~' || c1.global_attribute13);
      utl_file.put(l_file
                  ,'~' || c1.global_attribute14);
      utl_file.put(l_file
                  ,'~' || c1.global_attribute15);
      utl_file.put(l_file
                  ,'~' || c1.global_attribute16);
      utl_file.put(l_file
                  ,'~' || c1.global_attribute17);
      utl_file.put(l_file
                  ,'~' || c1.global_attribute18);
      utl_file.put(l_file
                  ,'~' || c1.global_attribute19);
      utl_file.put(l_file
                  ,'~' || c1.global_attribute20);
      utl_file.put(l_file
                  ,'~' || c1.global_attribute_category);
      utl_file.put(l_file
                  ,'~' || c1.amount_includes_tax_flag);
      utl_file.put(l_file
                  ,'~' || c1.income_tax_region);
      utl_file.put(l_file
                  ,'~' || c1.item);
      utl_file.put(l_file
                  ,'~' || (REPLACE(REPLACE(REPLACE(REPLACE(c1.item_description
                                                          ,','
                                                          ,' ')
                                                  ,'"'
                                                  ,' ')
                                          ,chr(10)
                                          ,' ')
                                  ,chr(13)
                                  ,' ')));
      utl_file.put(l_file
                  ,'~' || c1.justification);
      utl_file.put(l_file
                  ,'~' || c1.manufacturer);
      utl_file.put(l_file
                  ,'~' || c1.dist_match_type);
      utl_file.put(l_file
                  ,'~' || c1.model_number);
      utl_file.put(l_file
                  ,'~' || c1.operating_unit);
      utl_file.put(l_file
                  ,'~' || c1.s3_operating_unit);
      utl_file.put(l_file
                  ,'~' || c1.pa_addition_flag);
      utl_file.put(l_file
                  ,'~' || c1.pa_quantity);
      utl_file.put(l_file
                  ,'~' || c1.po_distribution_num);
      utl_file.put(l_file
                  ,'~' || c1.po_line_number);
      utl_file.put(l_file
                  ,'~' || c1.po_number);
      utl_file.put(l_file
                  ,'~' || c1.po_shipment_num);
      utl_file.put(l_file
                  ,'~' || c1.primary_intended_use);
      utl_file.put(l_file
                  ,'~' || c1.product_category);
      utl_file.put(l_file
                  ,'~' || c1.product_fisc_classification);
      utl_file.put(l_file
                  ,'~' || c1.product_table);
      utl_file.put(l_file
                  ,'~' || c1.product_type);
      utl_file.put(l_file
                  ,'~' || c1.project_accounting_context);
      utl_file.put(l_file
                  ,'~' || c1.project_line);
      utl_file.put(l_file
                  ,'~' || c1.s3_project_line);
      utl_file.put(l_file
                  ,'~' || c1.project);
      utl_file.put(l_file
                  ,'~' || c1.s3_project);
      utl_file.put(l_file
                  ,'~' || c1.prorate_across_all_items);
      utl_file.put(l_file
                  ,'~' || c1.quantity_invoiced);
      utl_file.put(l_file
                  ,'~' || c1.receipt_conversion_rate);
      utl_file.put(l_file
                  ,'~' || c1.receipt_currency_amount);
      utl_file.put(l_file
                  ,'~' || c1.receipt_currency_code);
      utl_file.put(l_file
                  ,'~' || c1.receipt_line_number);
      utl_file.put(l_file
                  ,'~' || c1.receipt_number);
      utl_file.put(l_file
                  ,'~' || c1.release_num);
      utl_file.put(l_file
                  ,'~' || c1.requester_employee_num);
      utl_file.put(l_file
                  ,'~' || c1.serial_number);
      utl_file.put(l_file
                  ,'~' || c1.ship_to_location_code);
      utl_file.put(l_file
                  ,'~' || c1.s3_ship_to_location_code);
      utl_file.put(l_file
                  ,'~' || c1.task_line);
      utl_file.put(l_file
                  ,'~' || c1.s3_task_line);
      utl_file.put(l_file
                  ,'~' || c1.task);
      utl_file.put(l_file
                  ,'~' || c1.s3_task);
      utl_file.put(l_file
                  ,'~' || c1.type_1099);
      utl_file.put(l_file
                  ,'~' || c1.unit_meas_lookup_code);
      utl_file.put(l_file
                  ,'~' || c1.unit_price);
      utl_file.put(l_file
                  ,'~' || c1.warranty_number);
      utl_file.put(l_file
                  ,'~' || c1.transform_status);
      utl_file.put(l_file
                  ,'~' || (REPLACE(REPLACE(REPLACE(REPLACE(c1.transform_error
                                                          ,','
                                                          ,' ')
                                                  ,'"'
                                                  ,' ')
                                          ,chr(10)
                                          ,' ')
                                  ,chr(13)
                                  ,' ')));
      utl_file.new_line(l_file);
    END LOOP;
    utl_file.fclose(l_file);
  
    SELECT COUNT(1) INTO l_count FROM xxobjt.xxs3_ptp_invoice_line;
  
    fnd_file.put_line(fnd_file.output
                     ,rpad('Invoice Line Extract'
                          ,100
                          ,' '));
    fnd_file.put_line(fnd_file.output
                     ,rpad('============================================================'
                          ,200
                          ,' '));
    fnd_file.put_line(fnd_file.output
                     ,rpad('Run date and time:    ' ||
                           to_char(SYSDATE
                                  ,'dd-Mon-YYYY HH24:MI')
                          ,100
                          ,' '));
    fnd_file.put_line(fnd_file.output
                     ,rpad('============================================================'
                          ,200
                          ,' '));
    fnd_file.put_line(fnd_file.output
                     ,'');
    fnd_file.put_line(fnd_file.output
                     ,rpad('Track Name'
                          ,10
                          ,' ') || chr(32) ||
                      rpad('Entity Name'
                          ,30
                          ,' ') || chr(32) ||
                      rpad('Total Count'
                          ,15
                          ,' '));
    fnd_file.put_line(fnd_file.output
                     ,rpad('==========================================================='
                          ,200
                          ,' '));
    fnd_file.put_line(fnd_file.output
                     ,'');
    fnd_file.put_line(fnd_file.output
                     ,rpad('PTP'
                          ,10
                          ,' ') || ' ' || rpad('Invoice_line'
                                              ,30
                                              ,' ') || ' ' ||
                      rpad(l_count
                          ,15
                          ,' '));
    fnd_file.put_line(fnd_file.output
                     ,rpad('=========END OF REPORT==============='
                          ,200
                          ,' '));
    fnd_file.put_line(fnd_file.output
                     ,'');
  
  EXCEPTION
  
    WHEN OTHERS THEN
      x_retcode        := 2;
      x_errbuf         := 'Unexpected error: ' || SQLERRM;
      l_status_message := SQLCODE || chr(10) || SQLERRM;
      fnd_file.put_line(fnd_file.log
                       ,'Unexpected error during data extraction at step: ' ||
                        l_step || chr(10) || l_status_message);
      fnd_file.put_line(fnd_file.log
                       ,'--------------------------------------');
    
  END open_invoice_extract_line_data;

  --------------------------------------------------------------------
  --  name:              data_transform_report
  --  create by:         Debarati banerjee
  --  Revision:          1.0
  --  creation date:     18/10/2016
  --------------------------------------------------------------------
  --  purpose :          write data transform report to output
  --
  --------------------------------------------------------------------
  --  ver  date          name                   desc
  --  1.0  13/05/2016    Debarati banerjee     report data transform
  --------------------------------------------------------------------

  PROCEDURE open_invoice_transform_report(p_entity VARCHAR2) IS
  
    l_delimiter     VARCHAR2(5) := '~';
    l_err_msg       VARCHAR2(2000);
    l_count_success NUMBER;
    l_count_fail    NUMBER;
    l_file          utl_file.file_type;
    l_file_path     VARCHAR2(100);
    l_file_name     VARCHAR2(100);
  
    CURSOR c_open_invoice_report IS
      SELECT xpp.invoice_id
            ,xpp.invoice_num
            ,xpp.xx_invoice_id
            ,xpp.set_of_books_name
            ,xpp.s3_set_of_books_name
            ,xpp.terms_name
            ,xpp.s3_terms_name
            ,xpp.operating_unit
            ,xpp.s3_operating_unit
            ,xpp.legal_entity_name
            ,xpp.s3_legal_entity_name
            ,xpp.payment_method_code
            ,xpp.s3_payment_method_code
            ,xpp.accts_pay_code_concatenated
            ,xpp.accts_pay_code_segment1
            ,xpp.accts_pay_code_segment2
            ,xpp.accts_pay_code_segment3
            ,xpp.accts_pay_code_segment5
            ,xpp.accts_pay_code_segment6
            ,xpp.accts_pay_code_segment7
            ,xpp.accts_pay_code_segment10
            ,xpp.s3_accts_pay_code_segment1
            ,xpp.s3_accts_pay_code_segment2
            ,xpp.s3_accts_pay_code_segment3
            ,xpp.s3_accts_pay_code_segment4
            ,xpp.s3_accts_pay_code_segment5
            ,xpp.s3_accts_pay_code_segment6
            ,xpp.s3_accts_pay_code_segment7
            ,xpp.s3_accts_pay_code_segment8
            ,xpp.transform_status
            ,xpp.transform_error
      FROM xxobjt.xxs3_ptp_invoice xpp
      WHERE xpp.transform_status IN ('PASS', 'FAIL');
  
    CURSOR c_open_invoice_line_report IS
      SELECT xcc.xx_invoice_id
            ,xcc.invoice_id
            ,xcc.invoice_num
            ,xcc.invoice_line_num
            ,xcc.ship_to_location_code
            ,xcc.s3_ship_to_location_code
            ,xcc.asset_book_type_code
            ,xcc.s3_asset_book_type_code
            ,xcc.operating_unit
            ,xcc.s3_operating_unit
            ,xcc.expenditure_operating_unit
            ,xcc.s3_expenditure_operating_unit
            ,xcc.expenditure_org_line
            ,xcc.s3_expenditure_org_line
            ,xcc.expenditure_type
            ,xcc.s3_expenditure_type
            ,xcc.expenditure_type_line
            ,xcc.s3_expenditure_type_line
            ,xcc.project
            ,xcc.s3_project
            ,xcc.project_line
            ,xcc.s3_project_line
            ,xcc.task
            ,xcc.s3_task
            ,xcc.task_line
            ,xcc.s3_task_line
            ,xcc.default_distribution_segment1
            ,xcc.default_distribution_segment2
            ,xcc.default_distribution_segment3
            ,xcc.default_distribution_segment5
            ,xcc.default_distribution_segment6
            ,xcc.default_distribution_segment7
            ,xcc.default_distribution_segment10
            ,xcc.s3_default_dist_segment1
            ,xcc.s3_default_dist_segment2
            ,xcc.s3_default_dist_segment3
            ,xcc.s3_default_dist_segment4
            ,xcc.s3_default_dist_segment5
            ,xcc.s3_default_dist_segment6
            ,xcc.s3_default_dist_segment7
            ,xcc.s3_default_dist_segment8
            ,xcc.dist_code_segment1
            ,xcc.dist_code_segment2
            ,xcc.dist_code_segment3
            ,xcc.dist_code_segment5
            ,xcc.dist_code_segment6
            ,xcc.dist_code_segment7
            ,xcc.dist_code_segment10
            ,xcc.s3_dist_code_segment1
            ,xcc.s3_dist_code_segment2
            ,xcc.s3_dist_code_segment3
            ,xcc.s3_dist_code_segment4
            ,xcc.s3_dist_code_segment5
            ,xcc.s3_dist_code_segment6
            ,xcc.s3_dist_code_segment7
            ,xcc.s3_dist_code_segment8
            ,xcc.transform_status
            ,xcc.transform_error
      FROM xxobjt.xxs3_ptp_invoice_line xcc
      WHERE xcc.transform_status IN ('PASS', 'FAIL');
  
  BEGIN
  
  
    IF p_entity = 'INVOICE_HDR'
    THEN
    
      BEGIN
      
        /* Get the file name  */
        l_file_name := 'AP_Invoice_Header_Transformation_Report' || '_' ||
                       SYSDATE || '.xls';
      
        /* Get the utl file open*/
        l_file := utl_file.fopen('/UtlFiles/shared/DEV'
                                ,l_file_name
                                ,'W'
                                ,32767); /* Utl file open */
      EXCEPTION
        WHEN OTHERS THEN
          fnd_file.put_line(fnd_file.log
                           ,'Invalid File Path' || SQLERRM);
          NULL;
      END;
    
      SELECT COUNT(1)
      INTO l_count_success
      FROM xxobjt.xxs3_ptp_invoice xpp
      WHERE xpp.transform_status = 'PASS';
    
      SELECT COUNT(1)
      INTO l_count_fail
      FROM xxobjt.xxs3_ptp_invoice xpp
      WHERE xpp.transform_status = 'FAIL';
    
      utl_file.put(l_file
                  ,rpad('Report name = Open Invoice Data Transformation Report' ||
                        l_delimiter
                       ,100
                       ,' '));
      utl_file.new_line(l_file);
      utl_file.put(l_file
                  ,rpad('========================================' ||
                        l_delimiter
                       ,100
                       ,' '));
      utl_file.new_line(l_file);
      utl_file.put(l_file
                  ,rpad('Data Migration Object Name = ' || p_entity ||
                        l_delimiter
                       ,100
                       ,' '));
      utl_file.new_line(l_file);
      utl_file.put(l_file
                  ,'');
      utl_file.new_line(l_file);
      utl_file.put(l_file
                  ,rpad('Run date and time:    ' ||
                        to_char(SYSDATE
                               ,'dd-Mon-YYYY HH24:MI') || l_delimiter
                       ,100
                       ,' '));
      utl_file.new_line(l_file);
      utl_file.put(l_file
                  ,rpad('Total Record Count Success = ' || l_count_success ||
                        l_delimiter
                       ,100
                       ,' '));
      utl_file.new_line(l_file);
      utl_file.put(l_file
                  ,rpad('Total Record Count Failure = ' || l_count_fail ||
                        l_delimiter
                       ,100
                       ,' '));
      utl_file.new_line(l_file);
    
      utl_file.put(l_file
                  ,'');
      utl_file.new_line(l_file);
    
      utl_file.put(l_file
                  ,rpad('Track Name'
                       ,10
                       ,' ') || l_delimiter ||
                   rpad('Entity Name'
                       ,15
                       ,' ') || l_delimiter ||
                   rpad('INVOICE ID'
                       ,20
                       ,' ') || l_delimiter ||
                   rpad('INVOICE NUMBER'
                       ,50
                       ,' ') || l_delimiter ||
                   rpad('XX_INVOICE_ID'
                       ,20
                       ,' ') || l_delimiter ||
                   rpad('SET_OF_BOOKS_NAME'
                       ,50
                       ,' ') || l_delimiter ||
                   rpad('S3_SET_OF_BOOKS_NAME'
                       ,50
                       ,' ') || l_delimiter ||
                   rpad('TERMS_NAME'
                       ,20
                       ,' ') || l_delimiter ||
                   rpad('S3_TERMS_NAME'
                       ,20
                       ,' ') || l_delimiter ||
                   rpad('OPERATING_UNIT'
                       ,50
                       ,' ') || l_delimiter ||
                   rpad('S3_OPERATING_UNIT'
                       ,50
                       ,' ') || l_delimiter ||
                   rpad('LEGAL_ENTITY_NAME'
                       ,50
                       ,' ') || l_delimiter ||
                   rpad('S3_LEGAL_ENTITY_NAME'
                       ,50
                       ,' ') || l_delimiter ||
                   rpad('PAYMENT_METHOD_CODE'
                       ,30
                       ,' ') || l_delimiter ||
                   rpad('S3_PAYMENT_METHOD_CODE'
                       ,50
                       ,' ') || l_delimiter ||
                   rpad('ACCTS_PAY_CODE_CONCATENATED'
                       ,50
                       ,' ') || l_delimiter ||
                   rpad('ACCTS_PAY_CODE_SEGMENT1'
                       ,50
                       ,' ') || l_delimiter ||
                   rpad('ACCTS_PAY_CODE_SEGMENT2'
                       ,50
                       ,' ') || l_delimiter ||
                   rpad('ACCTS_PAY_CODE_SEGMENT3'
                       ,50
                       ,' ') || l_delimiter ||
                   rpad('ACCTS_PAY_CODE_SEGMENT5'
                       ,50
                       ,' ') || l_delimiter ||
                   rpad('ACCTS_PAY_CODE_SEGMENT6'
                       ,50
                       ,' ') || l_delimiter ||
                   rpad('ACCTS_PAY_CODE_SEGMENT7'
                       ,50
                       ,' ') || l_delimiter ||
                   rpad('ACCTS_PAY_CODE_SEGMENT10'
                       ,50
                       ,' ') || l_delimiter ||
                   rpad('S3_ACCTS_PAY_CODE_SEGMENT1'
                       ,50
                       ,' ') || l_delimiter ||
                   rpad('S3_ACCTS_PAY_CODE_SEGMENT2'
                       ,50
                       ,' ') || l_delimiter ||
                   rpad('S3_ACCTS_PAY_CODE_SEGMENT3'
                       ,50
                       ,' ') || l_delimiter ||
                   rpad('S3_ACCTS_PAY_CODE_SEGMENT4'
                       ,50
                       ,' ') || l_delimiter ||
                   rpad('S3_ACCTS_PAY_CODE_SEGMENT5'
                       ,50
                       ,' ') || l_delimiter ||
                   rpad('S3_ACCTS_PAY_CODE_SEGMENT6'
                       ,50
                       ,' ') || l_delimiter ||
                   rpad('S3_ACCTS_PAY_CODE_SEGMENT7'
                       ,50
                       ,' ') || l_delimiter ||
                   rpad('S3_ACCTS_PAY_CODE_SEGMENT8'
                       ,50
                       ,' ') || l_delimiter ||
                   rpad('TRANSFORM_STATUS'
                       ,20
                       ,' ') || l_delimiter ||
                   rpad('TRANSFORM_ERROR'
                       ,2000
                       ,' '));
      utl_file.new_line(l_file);
    
      FOR r_data IN c_open_invoice_report
      LOOP
        utl_file.put(l_file
                    ,rpad('PTP'
                         ,10
                         ,' ') || l_delimiter ||
                     rpad('OPEN INVOICE'
                         ,15
                         ,' ') || l_delimiter ||
                     rpad(r_data.invoice_id
                         ,20
                         ,' ') || l_delimiter ||
                     rpad(r_data.invoice_num
                         ,50
                         ,' ') || l_delimiter ||
                     rpad(r_data.xx_invoice_id
                         ,20
                         ,' ') || l_delimiter ||
                     rpad(r_data.set_of_books_name
                         ,50
                         ,' ') || l_delimiter ||
                     rpad(r_data.s3_set_of_books_name
                         ,50
                         ,' ') || l_delimiter ||
                     rpad(r_data.terms_name
                         ,20
                         ,' ') || l_delimiter ||
                     rpad(r_data.s3_terms_name
                         ,20
                         ,' ') || l_delimiter ||
                     rpad(r_data.operating_unit
                         ,50
                         ,' ') || l_delimiter ||
                     rpad(r_data.s3_operating_unit
                         ,50
                         ,' ') || l_delimiter ||
                     rpad(r_data.legal_entity_name
                         ,50
                         ,' ') || l_delimiter ||
                     rpad(r_data.s3_legal_entity_name
                         ,50
                         ,' ') || l_delimiter ||
                     rpad(r_data.payment_method_code
                         ,30
                         ,' ') || l_delimiter ||
                     rpad(r_data.s3_payment_method_code
                         ,30
                         ,' ') || l_delimiter ||
                     rpad(r_data.accts_pay_code_concatenated
                         ,50
                         ,' ') || l_delimiter ||
                     rpad(r_data.accts_pay_code_segment1
                         ,50
                         ,' ') || l_delimiter ||
                     rpad(r_data.accts_pay_code_segment2
                         ,50
                         ,' ') || l_delimiter ||
                     rpad(r_data.accts_pay_code_segment3
                         ,50
                         ,' ') || l_delimiter ||
                     rpad(r_data.accts_pay_code_segment5
                         ,50
                         ,' ') || l_delimiter ||
                     rpad(r_data.accts_pay_code_segment6
                         ,50
                         ,' ') || l_delimiter ||
                     rpad(r_data.accts_pay_code_segment7
                         ,50
                         ,' ') || l_delimiter ||
                     rpad(r_data.accts_pay_code_segment10
                         ,50
                         ,' ') || l_delimiter ||
                     rpad(r_data.s3_accts_pay_code_segment1
                         ,50
                         ,' ') || l_delimiter ||
                     rpad(r_data.s3_accts_pay_code_segment2
                         ,50
                         ,' ') || l_delimiter ||
                     rpad(r_data.s3_accts_pay_code_segment3
                         ,50
                         ,' ') || l_delimiter ||
                     rpad(r_data.s3_accts_pay_code_segment4
                         ,50
                         ,' ') || l_delimiter ||
                     rpad(r_data.s3_accts_pay_code_segment5
                         ,50
                         ,' ') || l_delimiter ||
                     rpad(r_data.s3_accts_pay_code_segment6
                         ,50
                         ,' ') || l_delimiter ||
                     rpad(r_data.s3_accts_pay_code_segment7
                         ,50
                         ,' ') || l_delimiter ||
                     rpad(r_data.s3_accts_pay_code_segment8
                         ,50
                         ,' ') || l_delimiter ||
                     rpad(r_data.transform_status
                         ,20
                         ,' ') || l_delimiter ||
                     rpad(r_data.transform_error
                         ,2000
                         ,' '));
        utl_file.new_line(l_file);
      
      END LOOP;
    
      utl_file.put(l_file
                  ,'');
      utl_file.new_line(l_file);
      utl_file.new_line(l_file);
      utl_file.new_line(l_file);
      utl_file.put(l_file
                  ,'Stratasys Confidential' || l_delimiter);
    
      utl_file.fclose(l_file);
    
    ELSE
      IF
      
       p_entity = 'INVOICE_LINE'
      THEN
      
      
        BEGIN
        
          /* Get the file name  */
          l_file_name := 'AP_Invoice_Line_Transformation_Report' || '_' ||
                         SYSDATE || '.xls';
        
          /* Get the utl file open*/
          l_file := utl_file.fopen('/UtlFiles/shared/DEV'
                                  ,l_file_name
                                  ,'W'
                                  ,32767); /* Utl file open */
        EXCEPTION
          WHEN OTHERS THEN
            fnd_file.put_line(fnd_file.log
                             ,'Invalid File Path' || SQLERRM);
            NULL;
        END;
      
      
        SELECT COUNT(1)
        INTO l_count_success
        FROM xxobjt.xxs3_ptp_invoice_line xcc
        WHERE xcc.transform_status = 'PASS';
      
        SELECT COUNT(1)
        INTO l_count_fail
        FROM xxobjt.xxs3_ptp_invoice_line xcc
        WHERE xcc.transform_status = 'FAIL';
      
        utl_file.put(l_file
                    ,rpad('Report name = Invoice Line Data Transformation Report' ||
                          l_delimiter
                         ,100
                         ,' '));
        utl_file.new_line(l_file);
        utl_file.put(l_file
                    ,rpad('========================================' ||
                          l_delimiter
                         ,100
                         ,' '));
        utl_file.new_line(l_file);
        utl_file.put(l_file
                    ,rpad('Data Migration Object Name = ' || p_entity ||
                          l_delimiter
                         ,100
                         ,' '));
        utl_file.new_line(l_file);
        utl_file.put(l_file
                    ,'');
        utl_file.put(l_file
                    ,rpad('Run date and time:    ' ||
                          to_char(SYSDATE
                                 ,'dd-Mon-YYYY HH24:MI') || l_delimiter
                         ,100
                         ,' '));
        utl_file.new_line(l_file);
        utl_file.put(l_file
                    ,rpad('Total Record Count Success = ' ||
                          l_count_success || l_delimiter
                         ,100
                         ,' '));
        utl_file.new_line(l_file);
        utl_file.put(l_file
                    ,rpad('Total Record Count Failure = ' || l_count_fail ||
                          l_delimiter
                         ,100
                         ,' '));
        utl_file.new_line(l_file);
      
        utl_file.put(l_file
                    ,'');
        utl_file.new_line(l_file);
      
        utl_file.put(l_file
                    ,rpad('Track Name'
                         ,10
                         ,' ') || l_delimiter ||
                     rpad('Entity Name'
                         ,15
                         ,' ') || l_delimiter ||
                     rpad('XX_INVOICE_ID'
                         ,20
                         ,' ') || l_delimiter ||
                     rpad('INVOICE_ID'
                         ,20
                         ,' ') || l_delimiter ||
                     rpad('INVOICE NUMBER'
                         ,30
                         ,' ') || l_delimiter ||
                     rpad('INVOICE_LINE_NUM'
                         ,20
                         ,' ') || l_delimiter ||
                     rpad('SHIP_TO_LOCATION_CODE'
                         ,30
                         ,' ') || l_delimiter ||
                     rpad('S3_SHIP_TO_LOCATION_CODE'
                         ,30
                         ,' ') || l_delimiter ||
                     rpad('ASSET_BOOK_TYPE_CODE'
                         ,30
                         ,' ') || l_delimiter ||
                     rpad('S3_ASSET_BOOK_TYPE_CODE'
                         ,30
                         ,' ') || l_delimiter ||
                     rpad('OPERATING_UNIT'
                         ,30
                         ,' ') || l_delimiter ||
                     rpad('S3_OPERATING_UNIT'
                         ,30
                         ,' ') || l_delimiter ||
                     rpad('EXPENDITURE_OPERATING_UNIT'
                         ,30
                         ,' ') || l_delimiter ||
                     rpad('S3_EXPENDITURE_OPERATING_UNIT'
                         ,30
                         ,' ') || l_delimiter ||
                     rpad('EXPENDITURE_ORG_LINE'
                         ,30
                         ,' ') || l_delimiter ||
                     rpad('S3_EXPENDITURE_ORG_LINE'
                         ,30
                         ,' ') || l_delimiter ||
                     rpad('EXPENDITURE_TYPE'
                         ,30
                         ,' ') || l_delimiter ||
                     rpad('S3_EXPENDITURE_TYPE'
                         ,30
                         ,' ') || l_delimiter ||
                     rpad('EXPENDITURE_TYPE_LINE'
                         ,30
                         ,' ') || l_delimiter ||
                     rpad('S3_EXPENDITURE_TYPE_LINE'
                         ,30
                         ,' ') || l_delimiter ||
                     rpad('PROJECT'
                         ,100
                         ,' ') || l_delimiter ||
                     rpad('S3_PROJECT'
                         ,30
                         ,' ') || l_delimiter ||
                     rpad('PROJECT_LINE'
                         ,30
                         ,' ') || l_delimiter ||
                     rpad('S3_PROJECT_LINE'
                         ,30
                         ,' ') || l_delimiter ||
                     rpad('TASK'
                         ,30
                         ,' ') || l_delimiter ||
                     rpad('S3_TASK'
                         ,30
                         ,' ') || l_delimiter ||
                     rpad('TASK_LINE'
                         ,30
                         ,' ') || l_delimiter ||
                     rpad('S3_TASK_LINE'
                         ,30
                         ,' ') || l_delimiter ||
                     rpad('default_distribution_segment1'
                         ,50
                         ,' ') || l_delimiter ||
                     rpad('default_distribution_segment2'
                         ,50
                         ,' ') || l_delimiter ||
                     rpad('default_distribution_segment3'
                         ,50
                         ,' ') || l_delimiter ||
                     rpad('default_distribution_segment5'
                         ,50
                         ,' ') || l_delimiter ||
                     rpad('default_distribution_segment6'
                         ,50
                         ,' ') || l_delimiter ||
                     rpad('default_distribution_segment7'
                         ,50
                         ,' ') || l_delimiter ||
                     rpad('default_distribution_segment10'
                         ,50
                         ,' ') || l_delimiter ||
                     rpad('S3_DEFAULT_DIST_SEGMENT1'
                         ,50
                         ,' ') || l_delimiter ||
                     rpad('S3_DEFAULT_DIST_SEGMENT2'
                         ,50
                         ,' ') || l_delimiter ||
                     rpad('S3_DEFAULT_DIST_SEGMENT3'
                         ,50
                         ,' ') || l_delimiter ||
                     rpad('S3_DEFAULT_DIST_SEGMENT4'
                         ,50
                         ,' ') || l_delimiter ||
                     rpad('S3_DEFAULT_DIST_SEGMENT5'
                         ,50
                         ,' ') || l_delimiter ||
                     rpad('S3_DEFAULT_DIST_SEGMENT6'
                         ,50
                         ,' ') || l_delimiter ||
                     rpad('S3_DEFAULT_DIST_SEGMENT7'
                         ,50
                         ,' ') || l_delimiter ||
                     rpad('S3_DEFAULT_DIST_SEGMENT8'
                         ,50
                         ,' ') || l_delimiter ||
                     rpad('DIST_CODE_SEGMENT1'
                         ,50
                         ,' ') || l_delimiter ||
                     rpad('DIST_CODE_SEGMENT2'
                         ,50
                         ,' ') || l_delimiter ||
                     rpad('DIST_CODE_SEGMENT3'
                         ,50
                         ,' ') || l_delimiter ||
                     rpad('DIST_CODE_SEGMENT5'
                         ,50
                         ,' ') || l_delimiter ||
                     rpad('DIST_CODE_SEGMENT6'
                         ,50
                         ,' ') || l_delimiter ||
                     rpad('DIST_CODE_SEGMENT7'
                         ,50
                         ,' ') || l_delimiter ||
                     rpad('DIST_CODE_SEGMENT10'
                         ,50
                         ,' ') || l_delimiter ||
                     rpad('S3_DIST_CODE_SEGMENT1'
                         ,50
                         ,' ') || l_delimiter ||
                     rpad('S3_DIST_CODE_SEGMENT2'
                         ,50
                         ,' ') || l_delimiter ||
                     rpad('S3_DIST_CODE_SEGMENT3'
                         ,50
                         ,' ') || l_delimiter ||
                     rpad('S3_DIST_CODE_SEGMENT4'
                         ,50
                         ,' ') || l_delimiter ||
                     rpad('S3_DIST_CODE_SEGMENT5'
                         ,50
                         ,' ') || l_delimiter ||
                     rpad('S3_DIST_CODE_SEGMENT6'
                         ,50
                         ,' ') || l_delimiter ||
                     rpad('S3_DIST_CODE_SEGMENT7'
                         ,50
                         ,' ') || l_delimiter ||
                     rpad('S3_DIST_CODE_SEGMENT8'
                         ,50
                         ,' ') || l_delimiter ||
                     rpad('TRANSFORM_STATUS'
                         ,20
                         ,' ') || l_delimiter ||
                     rpad('TRANSFORM_ERROR'
                         ,2000
                         ,' '));
        utl_file.new_line(l_file);
      
        FOR r_data IN c_open_invoice_line_report
        LOOP
          utl_file.put(l_file
                      ,rpad('PTP'
                           ,10
                           ,' ') || l_delimiter ||
                       rpad('OPEN INVOICE'
                           ,15
                           ,' ') || l_delimiter ||
                       rpad(r_data.xx_invoice_id
                           ,20
                           ,' ') || l_delimiter ||
                       rpad(r_data.invoice_id
                           ,20
                           ,' ') || l_delimiter ||
                       rpad(r_data.invoice_num
                           ,30
                           ,' ') || l_delimiter ||
                       rpad(r_data.invoice_line_num
                           ,20
                           ,' ') || l_delimiter ||
                       rpad(r_data.ship_to_location_code
                           ,30
                           ,' ') || l_delimiter ||
                       rpad(r_data.s3_ship_to_location_code
                           ,30
                           ,' ') || l_delimiter ||
                       rpad(r_data.asset_book_type_code
                           ,30
                           ,' ') || l_delimiter ||
                       rpad(r_data.s3_asset_book_type_code
                           ,30
                           ,' ') || l_delimiter ||
                       rpad(r_data.operating_unit
                           ,30
                           ,' ') || l_delimiter ||
                       rpad(r_data.s3_operating_unit
                           ,30
                           ,' ') || l_delimiter ||
                       rpad(r_data.expenditure_operating_unit
                           ,30
                           ,' ') || l_delimiter ||
                       rpad(r_data.s3_expenditure_operating_unit
                           ,30
                           ,' ') || l_delimiter ||
                       rpad(r_data.expenditure_org_line
                           ,30
                           ,' ') || l_delimiter ||
                       rpad(r_data.s3_expenditure_org_line
                           ,200
                           ,' ') || l_delimiter ||
                       rpad(r_data.expenditure_type
                           ,30
                           ,' ') || l_delimiter ||
                       rpad(r_data.s3_expenditure_type
                           ,30
                           ,' ') || l_delimiter ||
                       rpad(r_data.expenditure_type_line
                           ,30
                           ,' ') || l_delimiter ||
                       rpad(r_data.s3_expenditure_type_line
                           ,30
                           ,' ') || l_delimiter ||
                       rpad(r_data.project
                           ,30
                           ,' ') || l_delimiter ||
                       rpad(r_data.s3_project
                           ,30
                           ,' ') || l_delimiter ||
                       rpad(r_data.project_line
                           ,30
                           ,' ') || l_delimiter ||
                       rpad(r_data.s3_project_line
                           ,30
                           ,' ') || l_delimiter ||
                       rpad(r_data.task
                           ,30
                           ,' ') || l_delimiter ||
                       rpad(r_data.s3_task
                           ,30
                           ,' ') || l_delimiter ||
                       rpad(r_data.task_line
                           ,30
                           ,' ') || l_delimiter ||
                       rpad(r_data.s3_task_line
                           ,30
                           ,' ') || l_delimiter ||
                       rpad(r_data.default_distribution_segment1
                           ,50
                           ,' ') || l_delimiter ||
                       rpad(r_data.default_distribution_segment2
                           ,50
                           ,' ') || l_delimiter ||
                       rpad(r_data.default_distribution_segment3
                           ,50
                           ,' ') || l_delimiter ||
                       rpad(r_data.default_distribution_segment5
                           ,50
                           ,' ') || l_delimiter ||
                       rpad(r_data.default_distribution_segment6
                           ,50
                           ,' ') || l_delimiter ||
                       rpad(r_data.default_distribution_segment7
                           ,50
                           ,' ') || l_delimiter ||
                       rpad(r_data.default_distribution_segment10
                           ,50
                           ,' ') || l_delimiter ||
                       rpad(r_data.s3_default_dist_segment1
                           ,50
                           ,' ') || l_delimiter ||
                       rpad(r_data.s3_default_dist_segment2
                           ,50
                           ,' ') || l_delimiter ||
                       rpad(r_data.s3_default_dist_segment3
                           ,50
                           ,' ') || l_delimiter ||
                       rpad(r_data.s3_default_dist_segment4
                           ,50
                           ,' ') || l_delimiter ||
                       rpad(r_data.s3_default_dist_segment5
                           ,50
                           ,' ') || l_delimiter ||
                       rpad(r_data.s3_default_dist_segment6
                           ,50
                           ,' ') || l_delimiter ||
                       rpad(r_data.s3_default_dist_segment7
                           ,50
                           ,' ') || l_delimiter ||
                       rpad(r_data.s3_default_dist_segment8
                           ,50
                           ,' ') || l_delimiter ||
                       rpad(r_data.dist_code_segment1
                           ,50
                           ,' ') || l_delimiter ||
                       rpad(r_data.dist_code_segment2
                           ,50
                           ,' ') || l_delimiter ||
                       rpad(r_data.dist_code_segment3
                           ,50
                           ,' ') || l_delimiter ||
                       rpad(r_data.dist_code_segment5
                           ,50
                           ,' ') || l_delimiter ||
                       rpad(r_data.dist_code_segment6
                           ,50
                           ,' ') || l_delimiter ||
                       rpad(r_data.dist_code_segment7
                           ,50
                           ,' ') || l_delimiter ||
                       rpad(r_data.dist_code_segment10
                           ,50
                           ,' ') || l_delimiter ||
                       rpad(r_data.s3_dist_code_segment1
                           ,50
                           ,' ') || l_delimiter ||
                       rpad(r_data.s3_dist_code_segment2
                           ,50
                           ,' ') || l_delimiter ||
                       rpad(r_data.s3_dist_code_segment3
                           ,50
                           ,' ') || l_delimiter ||
                       rpad(r_data.s3_dist_code_segment4
                           ,50
                           ,' ') || l_delimiter ||
                       rpad(r_data.s3_dist_code_segment5
                           ,50
                           ,' ') || l_delimiter ||
                       rpad(r_data.s3_dist_code_segment6
                           ,50
                           ,' ') || l_delimiter ||
                       rpad(r_data.s3_dist_code_segment7
                           ,50
                           ,' ') || l_delimiter ||
                       rpad(r_data.s3_dist_code_segment8
                           ,50
                           ,' ') || l_delimiter ||
                       rpad(r_data.transform_status
                           ,20
                           ,' ') || l_delimiter ||
                       rpad(r_data.transform_error
                           ,2000
                           ,' '));
          utl_file.new_line(l_file);
        
        END LOOP;
      
        utl_file.put(l_file
                    ,'');
        utl_file.new_line(l_file);
        utl_file.new_line(l_file);
        utl_file.new_line(l_file);
        utl_file.put(l_file
                    ,'Stratasys Confidential' || l_delimiter);
      
        utl_file.fclose(l_file);
      END IF;
    END IF;
  END open_invoice_transform_report;
END xxs3_ptp_invoice_pkg;
/
