/*
  Filename         :  XXAP_INVOICES_V.SQL

  Purpose          :  Display information about AP Invoice Headers to be use for 
                   :  OBIEE reporting. 
                   :  CHG0034322
 
  Change History   :
  ............................................................
 --  ver  date               name                             desc
 --  1.0  15/02/2015    John Hendrickson           CHG0034322 initial build
  ............................................................
*/
Create Or Replace View "XXBI"."XXAP_INVOICES_V" ("INVOICE_NUMBER", "INVOICE_DATE", "INVOICE_DESCRIPTION", "INVOICE_DISCOUNTABLE_AMOUNT", "INVOICE_ENTERED_AMOUNT"
, "INVOICE_FREIGHT_AMOUNT", "INVOICE_FUNCTIONAL_AMOUNT", "INVOICE_RECEIVED_DATE", "INVOICE_POSTING_STATUS", "AWT_FLAG", "INVOICE_SEQUENCE_NUMBER", "INVOICE_SOURCE"
, "INVOICE_TYPE_CODE", "PAY_ALONE_FLAG", "PAY_GROUP", "PAYMENT_CURRENCY_INVOICE_AMT", "INV_TO_PMT_RATE", "INV_TO_PMT_RATE_TYPE", "INV_TO_PMT_RATE_DATE", "PAYMENT_METHOD"
, "PAYMENT_STATUS", "PMT_STATUS_DESCRIPTION", "MANUALLY_APPROVED_DESCRIPTION", "PAYMENT_TERMS_DATE", "TAX_AMOUNT", "TAX_CALCULATION_LEVEL", "USSGL_TRANSACTION_CODE"
, "MANUALLY_APPROVED_STATUS", "INVOICE_APPROVED_AMOUNT", "INVOICE_CANCELED_AMOUNT", "INVOICE_CANCELED_DATE", "INV_TO_FUNCTIONAL_EXCH_RATE", "INV_TO_FUNCTIONAL_EXCH_TYPE"
, "INV_TO_FUNCTIONAL_EXCH_DATE", "BATCH_ID", "VENDOR_ID", "VENDOR_SITE_ID", "INVOICE_CURRENCY_CODE", "PAYMENT_CURRENCY_CODE", "TERMS_ID", "INVOICE_ID", "PO_HEADER_ID"
, "PROJECT_ID", "PROJECT_TASK_ID", "PA_EXPENDITURE_TYPE", "PA_EXPENDITURE_ITEM_DATE", "PA_QUANTITY", "PA_REFERENCE_1", "PA_REFERENCE_2", "ATTRIBUTE_CATEGORY", "ATTRIBUTE1"
, "ATTRIBUTE2", "ATTRIBUTE3", "ATTRIBUTE4", "ATTRIBUTE5", "ATTRIBUTE6", "ATTRIBUTE7", "ATTRIBUTE8", "ATTRIBUTE9", "ATTRIBUTE10", "ATTRIBUTE11", "ATTRIBUTE12", "ATTRIBUTE13"
, "ATTRIBUTE14", "ATTRIBUTE15", "GLOBAL_ATTRIBUTE_CATEGORY", "GLOBAL_ATTRIBUTE1", "GLOBAL_ATTRIBUTE2", "GLOBAL_ATTRIBUTE3", "GLOBAL_ATTRIBUTE4", "GLOBAL_ATTRIBUTE5", "GLOBAL_ATTRIBUTE6"
, "GLOBAL_ATTRIBUTE7", "GLOBAL_ATTRIBUTE8", "GLOBAL_ATTRIBUTE9", "GLOBAL_ATTRIBUTE10", "GLOBAL_ATTRIBUTE11", "GLOBAL_ATTRIBUTE12", "GLOBAL_ATTRIBUTE13", "GLOBAL_ATTRIBUTE14"
, "GLOBAL_ATTRIBUTE15", "CREATION_DATE", "CREATED_BY", "LAST_UPDATE_DATE", "LAST_UPDATED_BY", "CREATED_BY_NAME") 
AS 
  SELECT Inv.Invoice_Num ,
    Inv.Invoice_Date ,
    Inv.Description ,
    Inv.Amount_Applicable_To_Discount ,
    Inv.Invoice_Amount ,
    Inv.Freight_Amount ,
    Inv.Base_Amount ,
    Inv.Invoice_Received_Date ,
    Inv.Posting_Status ,
    Inv.Awt_Flag ,
    Inv.Doc_Sequence_Value ,
    Inv.Source ,
    Inv.Invoice_Type_Lookup_Code ,
    Inv.Exclusive_Payment_Flag ,
    Inv.Pay_Group_Lookup_Code ,
    Inv.Pay_Curr_Invoice_Amount ,
    Inv.Payment_Cross_Rate ,
    Inv.Payment_Cross_Rate_Type ,
    Inv.Payment_Cross_Rate_Date ,
    Inv.Payment_Method_Code    ,
    Inv.Payment_Status_Flag ,
    Inv.Payment_Status_Flag ,
    Inv.Approval_Description ,
    trunc(Inv.Terms_Date) ,
    Inv.Tax_Amount ,
    Inv.Auto_Tax_Calc_Flag ,
    Inv.Ussgl_Transaction_Code ,
    Inv.Approval_Status ,
    Inv.Approved_Amount ,
    Inv.Cancelled_Amount ,
    trunc(Inv.Cancelled_Date) ,
    Inv.Exchange_Rate ,
    Inv.Exchange_Rate_Type ,
    trunc(Inv.Exchange_Date) ,
    Inv.Batch_Id ,
    Inv.Vendor_Id ,
    Inv.Vendor_Site_Id ,
    Inv.Invoice_Currency_Code ,
    Inv.Payment_Currency_Code ,
    Inv.Terms_Id ,
    Inv.Invoice_Id ,
    Inv.Po_Header_Id ,
    Inv.Project_Id ,
    Inv.Task_Id ,
    Inv.Expenditure_Type ,
    trunc(Inv.Expenditure_Item_Date),
    Inv.Pa_Quantity ,
    Inv.Reference_1 ,
    Inv.Reference_2 ,
    Inv.Attribute_Category,
    Inv.Attribute1 ,
    Inv.Attribute2 ,
    Inv.Attribute3 ,
    Inv.Attribute4 ,
    Inv.Attribute5 ,
    Inv.Attribute6 ,
    Inv.Attribute7 ,
    Inv.Attribute8 ,
    Inv.Attribute9 ,
    Inv.Attribute10 ,
    Inv.Attribute11 ,
    Inv.Attribute12 ,
    Inv.Attribute13 ,
    Inv.Attribute14 ,
    Inv.Attribute15 ,
    Inv.Global_Attribute_Category,
    Inv.Global_Attribute1,
    Inv.Global_Attribute2,
    Inv.Global_Attribute3,
    Inv.Global_Attribute4,
    Inv.Global_Attribute5,
    Inv.Global_Attribute6,
    Inv.Global_Attribute7,
    Inv.Global_Attribute8,
    Inv.Global_Attribute9,
    Inv.Global_Attribute10,
    Inv.Global_Attribute11,
    Inv.Global_Attribute12,
    Inv.Global_Attribute13,
    Inv.Global_Attribute14,
    Inv.Global_Attribute15,
    trunc(Inv.Creation_Date) ,
    Inv.Created_By ,
    Trunc(Inv.Last_Update_Date) ,
    Inv.Last_Updated_By,
    Fu.User_Name
  From Apps.Ap_Invoices_All Inv ,
       Apps.Fnd_User Fu
  where inv.created_by = fu.user_id;