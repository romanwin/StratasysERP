------------------------------------------------------------------------------
--  Program             :  AP Subledger Distributions View
--  Filename            :  XXAP_XLA_DISTRIBUTIONS_V.sql
--
--  Description         :  
--                      :  
--                      :  
--
--  Created By          :  John Hendrickson
--  Creation Date       :  September 15, 2014
--
--  Change History      : V1.0
--  .......................................................................
--   ver      date               name                             desc
--   1.0    15/09/2014    John Hendrickson           CHG0033238 initial build
------------------------------------------------------------------------------


CREATE OR REPLACE VIEW "XXBI"."XXAP_XLA_DISTRIBUTIONS_V"  ("INVOICE_ID", "INVOICE_NUM", "DOC_SEQUENCE_VALUE", "INVOICE_CURRENCY_CODE", "INVOICE_AMOUNT", "BASE_AMOUNT",
                                                           "AMOUNT_PAID", "INVOICE_DATE", "SOURCE", "INVOICE_TYPE_LOOKUP_CODE", "HEADER_DESCRIPTION","TERMS_DATE",
                                                           "PAY_GROUP_LOOKUP_CODE", "PAYMENT_STATUS_FLAG", "CREATION_DATE", "REQUESTER_ID", "CANCELLED_DATE", "PO_HEADER_ID",
                                                           "QUICK_PO_HEADER_ID", "POSTING_STATUS", "REFERENCE_1", "APPROVED_AMOUNT", "ATTRIBUTE1", "ATTRIBUTE2", "ATTRIBUTE3",
                                                           "ATTRIBUTE4", "ATTRIBUTE5",  "ATTRIBUTE6", "ATTRIBUTE7", "ATTRIBUTE8", "ATTRIBUTE9", "ATTRIBUTE10",  "ATTRIBUTE11",
                                                           "ATTRIBUTE12", "ATTRIBUTE13", "ATTRIBUTE14", "ATTRIBUTE15", "WFAPPROVAL_STATUS", "INVOICE_DISTRIBUTION_ID", "LINE_TYPE_LOOKUP_CODE",
                                                           "LINE_DESCRIPTION", "INVOICE_LINE_NUMBER", "DISTRIBUTION_LINE_NUMBER", "POSTED_FLAG", "AMOUNT_ENCUMBERED",
                                                           "BASE_AMOUNT_ENCUMBERED", "ENCUMBERED_FLAG", "PO_DISTRIBUTION_ID", "MATCH_STATUS_FLAG", "REVERSAL_FLAG", "DIST_MATCH_TYPE",
                                                           "INVENTORY_TRANSFER_STATUS", "CANCELLATION_FLAG", "ASSET_BOOK_TYPE_CODE", "VENDOR_ID", "VENDOR_SITE_ID",
                                                           "PARTY_ID", "PARTY_SITE_ID", "SET_OF_BOOKS_ID", "TERMS_ID", "ORG_ID", "PROJECT_ID", "TASK_ID", "EXPENDITURE_TYPE",
                                                           "EXPENDITURE_ORGANIZATION_ID", "PERIOD_NAME", "ACCOUNTING_DATE", "DIST_CODE_COMBINATION_ID", "DIST_BASE_AMOUNT", 
                                                           "DIST_AMOUNT", "GL_CCID", "GL_AMOUNT", "AE_HEADER_ID", "CURRENCY_CODE", "USD_AMOUNT")
AS
SELECT
--Invoice Header Attributes
    aia.invoice_id
    ,Aia.Invoice_Num
    ,aia.doc_sequence_value
    ,aia.invoice_currency_code
    ,aia.invoice_amount
    ,aia.base_amount
    ,aia.amount_paid
    ,aia.invoice_date
    ,aia.source
    ,aia.invoice_type_lookup_code
    ,aia.description header_description
    ,aia.terms_date
    ,aia.pay_group_lookup_code
    ,aia.payment_status_flag
    ,Aia.Creation_Date
    ,nvl(Aia.Requester_Id,0)
    ,Aia.Cancelled_Date
    ,Aia.Po_Header_Id
    ,Aia.Quick_Po_Header_Id
    ,Aia.Posting_Status
    ,Aia.Reference_1
    ,aia.approved_amount
    ,aia.attribute1
    ,aia.attribute2
    ,aia.attribute3
    ,aia.attribute4
    ,aia.attribute5
    ,aia.attribute6
    ,aia.attribute7
    ,aia.attribute8
    ,aia.attribute9
    ,aia.attribute10
    ,aia.attribute11
    ,aia.attribute12
    ,aia.attribute13
    ,aia.attribute14
    ,aia.attribute15
--Invoice Distribution Attributes
    ,aia.wfapproval_status
    ,aida.invoice_distribution_id
    ,aida.line_type_lookup_code
    ,aida.description line_description
    ,aida.invoice_line_number
    ,aida.distribution_line_number
    ,aida.posted_flag
    ,aida.amount_encumbered
    ,aida.base_amount_encumbered
    ,Aida.Encumbered_Flag
    ,Aida.Po_Distribution_Id
    ,Aida.Match_Status_Flag
    ,Aida.Reversal_Flag
    ,Aida.Dist_Match_Type
    ,Aida.Inventory_Transfer_Status
    ,Aida.Cancellation_Flag
    ,aida.asset_book_type_code
--Dimension Join Columns
    ,nvl(aia.vendor_id, 0) vendor_id
    ,nvl(aia.vendor_site_id, 0) vendor_site_id --optional
    ,nvl(aia.party_id, 0) party_id
    ,nvl(aia.party_site_id, 0) party_site_id
    ,nvl(xal.ledger_id, 0) set_of_books_id
    ,nvl(aia.terms_id, 0) terms_id
    ,nvl(aida.org_id, 0) org_id
    ,nvl(aida.project_id, 0) project_id
    ,nvl(aida.task_id, 0) task_id
    ,nvl(aida.expenditure_type, '0') expenditure_type
    ,nvl(aida.expenditure_organization_id, 0) expenditure_organization_id
    ,aida.period_name
    --,aida.accounting_date --using subledger date
    ,xal.accounting_date
    ,nvl(aida.dist_code_combination_id, 0) dist_code_combination_id
    ,nvl(Aida.Base_Amount,Aida.Amount) As Dist_Base_Amount
    ,Aida.Amount As Dist_Amount
    ,nvl(xal.code_combination_id,0) gl_ccid
    ,nvl(xal.accounted_dr,0) - nvl(xal.accounted_cr,0) gl_amount
    ,xal.ae_header_id
    ,gll.currency_code
    ,(decode(xal.currency_code,                                                     --look at the currency code
                   'USD',                                                           --if it is USD...
                   (nvl(xal.accounted_dr,0) - nvl(xal.accounted_cr,0)),             --then get this amount
                   decode(gll.currency_code,                                        --if it is not USD, go to the ledger
                          'USD',                                                    --if it is USD in the ledger...
                          (nvl(xal.accounted_dr,0)  - nvl(xal.accounted_cr,0)),     --do this
                          ((nvl(xal.accounted_dr,0) - nvl(xal.accounted_cr,0)) *    --otherwise, convert it to USD with this function
                          gl_currency_api.get_closest_rate( /*from*/gll.currency_code, /*to*/
                                                            'USD', /*date*/
                                                            nvl(xal.currency_conversion_date,
                                                                xal.accounting_date),
                                                            'Corporate',
                                                            10)))) ) USD_amount
      
FROM
      Apps.Ap_Invoice_Distributions_All   Aida
    , Apps.Ap_Invoices_All                Aia
    , Xxbi.Xxgl_Code_Combinations_V       Gl
    , Apps.Gl_Code_Combinations           Xlacc
    , Apps.Xla_Distribution_Links         Xdl
    , Apps.xla_ae_lines                   Xal
    , Apps.Gl_ledgers                     Gll
WHERE     Aida.Invoice_Id                 = Aia.Invoice_Id
   AND    Aida.dist_code_combination_id   = Gl.Code_Combination_Id
   AND    Aida.Invoice_Distribution_Id    = Xdl.Source_Distribution_Id_Num_1 
   AND    Xdl.ae_header_id                = Xal.ae_header_id 
   AND    Xdl.Ae_Line_Num                 = Xal.Ae_Line_Num 
   AND    Xal.code_combination_id         = Xlacc.code_combination_id 
   AND    Xal.Ledger_id                   = Gll.ledger_id
;
