CREATE OR REPLACE PACKAGE BODY iby_fd_extract_ext_pub AS
  /* $Header: ibyfdxeb.pls 120.2 2006/09/20 18:52:12 frzhang noship $ */

  --
  -- This API is called once only for the payment instruction.
  -- Implementor should construct the extract extension elements
  -- at the payment instruction level as a SQLX XML Aggregate
  -- and return the aggregate.
  --
  -- Below is an example implementation:
  /*
    FUNCTION Get_Ins_Ext_Agg(p_payment_instruction_id IN NUMBER)
    RETURN XMLTYPE
    IS
      l_ins_ext_agg XMLTYPE;
  
      CURSOR l_ins_ext_csr (p_payment_instruction_id IN NUMBER) IS
      SELECT XMLConcat(
               XMLElement("Extend",
                 XMLElement("Name", ext_table.attr_name1),
                 XMLElement("Value", ext_table.attr_value1)),
               XMLElement("Extend",
                 XMLElement("Name", ext_table.attr_name2),
                 XMLElement("Value", ext_table.attr_value2))
             )
        FROM your_pay_instruction_lvl_table ext_table
       WHERE ext_table.payment_instruction_id = p_payment_instruction_id;
  
    BEGIN
  
      OPEN l_ins_ext_csr (p_payment_instruction_id);
      FETCH l_ins_ext_csr INTO l_ins_ext_agg;
      CLOSE l_ins_ext_csr;
  
      RETURN l_ins_ext_agg;
  
    END Get_Ins_Ext_Agg;
  */

  -- --------------------------------------------------------------------------------------------
  -- get_pmt_ext_agg
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                            Description
  -----------------------------------------------------------------------------------------------
  -- 1.1  15.02.17    yuval tal                      CHG0039822  get_pmt_ext_agg : Add poalim extra tag , disable wellsfargo code 

  FUNCTION get_ins_ext_agg(p_payment_instruction_id IN NUMBER) RETURN xmltype IS
  BEGIN
    RETURN NULL;
  END get_ins_ext_agg;

  --
  -- This API is called once per payment.
  -- Implementor should construct the extract extension elements
  -- at the payment level as a SQLX XML Aggregate
  -- and return the aggregate.
  --
  FUNCTION get_pmt_ext_agg(p_payment_id IN NUMBER) RETURN xmltype IS
    -- --------------------------------------------------------------------------------------------
    -- get_pmt_ext_agg
    -- --------------------------------------------------------------------------------------------
    -- Ver  Date        Name                            Description
    -----------------------------------------------------------------------------------------------
    -- 1.1  15.02.17    yuval tal                      CHG0039822  Add poalim extra tag , disable wellsfargo code 
  
    l_pmt_ext_agg xmltype;
    -- CHG0039822 wellsfargo
    --  lc_pymnt_flag           VARCHAR(2) := 'N'; -- Added Variable 01/02/2015  SAKULA  (CHG0032794)
    -- lc_flag                 VARCHAR2(1) := 'N'; -- Added Variable 01/02/2015  SAKULA  (CHG0032794)
    l_hapoalim_code         VARCHAR2(150); ---- Added Variable 11/12/2016  MS HAPOALIM EFT--------------
    l_payment_method_code   iby_payments_all.payment_method_code%TYPE;
    l_is_poalim_bank        ce_bank_accounts.attribute1%TYPE;
    v_outboundpaymentextend xmltype;
  BEGIN
  
    --------------------------
  
    -- CHG0039822 wellsfargo is not active 
  
    -- lc_flag       := xxiby_pay_extract_util.is_wellsfargo_bank_account(p_payment_id); -- Added call to the Function 01/02/2015  SAKULA  (CHG0032794)
    -- lc_pymnt_flag := xxiby_pay_extract_util.is_wellsfargo_payment_type(p_payment_id); -- Added call to the Function 01/02/2015  SAKULA  (CHG0032794)
  
    -- Added 01/02/2015  SAKULA  (CHG0032794)
    -- Added Conditional Logic to check if the Bank Account and Payment Method Associated with the Payment are for Wells Fargo Bank. If the Bank Account is from other Bank then a different XML Structure is generated
    -- IF lc_flag = 'Y' AND lc_pymnt_flag = 'Y' THEN
    --  l_pmt_ext_agg := xxwap_get_pmt_ext_agg.get_pmt_ext_agg(p_payment_id);
    --  RETURN l_pmt_ext_agg;
    -- ELSE
  
    -- CHG0039822
    SELECT upper(ipa.payment_method_code),
           nvl(cba.attribute1, 'N')
    INTO   l_payment_method_code,
           l_is_poalim_bank
    FROM   iby_payments_all ipa,
           ce_bank_accounts cba
    WHERE  ipa.payment_id = p_payment_id
    AND    cba.bank_account_id = ipa.internal_bank_account_id;
  
    IF l_payment_method_code = 'EFT' AND l_is_poalim_bank = 'Y' THEN
    
      BEGIN
      
        SELECT vsdf.hapoalim_code
        INTO   l_hapoalim_code
        FROM   iby.iby_payments_all    d,
	   po_vendors              pv,
	   po_vendor_sites_all     vs,
	   po_vendor_sites_all_dfv vsdf
        WHERE  d.payment_id = p_payment_id
        AND    d.inv_payee_supplier_id = pv.vendor_id
        AND    vs.vendor_id = pv.vendor_id
        AND    vs.vendor_site_id(+) = d.supplier_site_id
        AND    vsdf.row_id(+) = vs.rowid;
        SELECT xmlconcat(xmlelement("OutboundPaymentExtend"
			--  ,XMLElement("Printed_Payment_Date", v_Printed_Payment_Date)
			,
			xmlelement("Hapoalim_Code",
			           l_hapoalim_code)))
        
        INTO   v_outboundpaymentextend
        FROM   dual;
        RETURN v_outboundpaymentextend;
      EXCEPTION
      
        WHEN OTHERS THEN
          fnd_file.put_line(fnd_file.log,
		    'Following error accured during the calling procedure of get_pmt_ext_agg: ' ||
		    SQLERRM);
          RETURN NULL;
        
      END;
    
    ELSE
      l_pmt_ext_agg := xxiby_pay_extract_util.get_pmt_ext_agg(p_payment_id);
      RETURN l_pmt_ext_agg;
    END IF;
  
    -- END IF;
  
    ------------------------------
  
  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log,
		'Following error accured during the calling procedure of get_pmt_ext_agg: ' ||
		SQLERRM);
      RETURN NULL;
    
  END get_pmt_ext_agg;

  --
  -- This API is called once per document payable.
  -- Implementor should construct the extract extension elements
  -- at the document level as a SQLX XML Aggregate
  -- and return the aggregate.
  --
  FUNCTION get_doc_ext_agg(p_document_payable_id IN NUMBER) RETURN xmltype IS
  BEGIN
    RETURN NULL;
  END get_doc_ext_agg;

  --
  -- This API is called once per document payable line.
  -- Implementor should construct the extract extension elements
  -- at the doc line level as a SQLX XML Aggregate
  -- and return the aggregate.
  --
  -- Parameters:
  --   p_document_payable_id: primary key of IBY iby_docs_payable_all table
  --   p_line_number: calling app doc line number. For AP this is
  --   ap_invoice_lines_all.line_number.
  --
  -- The combination of p_document_payable_id and p_line_number
  -- can uniquely locate a document line.
  -- For example if the calling product of a doc is AP
  -- p_document_payable_id can locate
  -- iby_docs_payable_all/ap_documents_payable.calling_app_doc_unique_ref2,
  -- which is ap_invoice_all.invoice_id. The combination of invoice_id and
  -- p_line_number will uniquely identify the doc line.
  --
  FUNCTION get_docline_ext_agg(p_document_payable_id IN NUMBER,
		       p_line_number         IN NUMBER)
    RETURN xmltype IS
  BEGIN
    RETURN NULL;
  END get_docline_ext_agg;

  --
  -- This API is called once only for the payment process request.
  -- Implementor should construct the extract extension elements
  -- at the payment request level as a SQLX XML Aggregate
  -- and return the aggregate.
  --
  FUNCTION get_ppr_ext_agg(p_payment_service_request_id IN NUMBER)
    RETURN xmltype IS
  BEGIN
    RETURN NULL;
  END get_ppr_ext_agg;

END iby_fd_extract_ext_pub;
/
