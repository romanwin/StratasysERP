------------------------------------------------------------------------------
--  Program             :  AP Distributions View
--  Filename            :  xxapdistributionsv.sql
--
--  Description         :  Corresponding information on the form can be found
--                      :  under the AP Transactions menu selection.
--
--  Created By          :  John Hendrickson
--  Creation Date       :  July 7, 2014
--
--  Change History      : V1.0
--  .......................................................................
--   ver  date               name                             desc
--   1.0  7/07/2014    John Hendrickson           CHG0032283 initial build 
------------------------------------------------------------------------------
create or replace view xxbi.xxap_distributions_v
  (  invoice_id
    ,Invoice_Num
    ,doc_sequence_value
    ,invoice_currency_code
    ,invoice_amount
    ,base_amount
    ,amount_paid
    ,invoice_date
    ,source
    ,invoice_type_lookup_code
    ,header_description
    ,terms_date
    ,pay_group_lookup_code
    ,payment_status_flag
    ,Creation_Date
    ,Requester_Id
    ,Cancelled_Date
    ,Po_Header_Id
    ,Quick_Po_Header_Id
    ,Posting_Status
    ,Reference_1
    ,approved_amount
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
    ,wfapproval_status
 --Invoice Distribution Attributes 
    ,invoice_distribution_id
    ,line_type_lookup_code
    ,line_description
    ,invoice_line_number
    ,distribution_line_number
    ,posted_flag
    ,amount_encumbered
    ,base_amount_encumbered
    ,Encumbered_Flag
    ,Po_Distribution_Id
    ,Match_Status_Flag
    ,Reversal_Flag
    ,Dist_Match_Type
    ,Inventory_Transfer_Status
    ,Cancellation_Flag
    ,asset_book_type_code
--Dimension Join Columns    
    ,vendor_id
    ,vendor_site_id --optional
    ,party_id
    ,party_site_id
    ,set_of_books_id
    ,terms_id
    ,org_id
    ,project_id
    ,task_id
    ,expenditure_type
    ,expenditure_organization_id
    ,period_name 
    ,accounting_date
    ,dist_code_combination_id
    ,dist_base_amount
  )
as
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
    ,nvl(aia.set_of_books_id, 0) set_of_books_id
    ,nvl(aia.terms_id, 0) terms_id
    ,nvl(aida.org_id, 0) org_id
    ,nvl(aida.project_id, 0) project_id
    ,nvl(aida.task_id, 0) task_id
    ,nvl(aida.expenditure_type, '0') expenditure_type
    ,nvl(aida.expenditure_organization_id, 0) expenditure_organization_id
    ,aida.period_name 
    ,aida.accounting_date
    ,nvl(aida.dist_code_combination_id, 0) dist_code_combination_id
    ,NVL(AIDA.BASE_AMOUNT,AIDA.AMOUNT) AS dist_base_amount
	From 
     Apps.Ap_Invoice_Distributions_All Aida
		,APPS.AP_INVOICES_ALL AIA
	WHERE AIDA.INVOICE_ID = AIA.INVOICE_ID;