CREATE OR REPLACE PACKAGE iby_fd_extract_ext_pub AUTHID CURRENT_USER AS
  /* $Header: ibyfdxes.pls 120.2 2006/09/20 18:52:23 frzhang noship $ */

  g_debug_module CONSTANT VARCHAR2(100) := 'iby.plsql.IBY_FD_EXTRACT_EXT_PUB';

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
  FUNCTION get_ins_ext_agg(p_payment_instruction_id IN NUMBER) RETURN xmltype;

  --
  -- This API is called once per payment.
  -- Implementor should construct the extract extension elements
  -- at the payment level as a SQLX XML Aggregate
  -- and return the aggregate.
  --
  FUNCTION get_pmt_ext_agg(p_payment_id IN NUMBER) RETURN xmltype;

  --
  -- This API is called once per document payable.
  -- Implementor should construct the extract extension elements
  -- at the document level as a SQLX XML Aggregate
  -- and return the aggregate.
  --
  FUNCTION get_doc_ext_agg(p_document_payable_id IN NUMBER) RETURN xmltype;

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
    RETURN xmltype;

  --
  -- This API is called once only for the payment process request.
  -- Implementor should construct the extract extension elements
  -- at the payment request level as a SQLX XML Aggregate
  -- and return the aggregate.
  --
  FUNCTION get_ppr_ext_agg(p_payment_service_request_id IN NUMBER)
    RETURN xmltype;

END iby_fd_extract_ext_pub;
/
