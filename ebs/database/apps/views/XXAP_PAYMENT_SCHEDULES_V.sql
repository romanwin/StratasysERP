/*
  Filename         :  XXAP_PAYMENT_SCHEDULES_V.SQL

  Purpose          :  Display information about AP Open Invoices to be use for 
                   :  OBIEE reporting. 
                   :  CHG0034322
 
  Change History   :
  ............................................................
 --  ver  date               name                             desc
 --  1.0  15/02/2015    John Hendrickson           CHG0034322 initial build
  ............................................................
*/
Create Or Replace View "XXBI"."XXAP_PAYMENT_SCHEDULES_V" ("INVOICE_NUMBER", "INVOICE_DATE", "INVOICE_TYPE", "PAYMENT_NUMBER", "PAYMENT_STATUS"
, "VENDOR_ID", "VENDOR_SITE_ID", "INVOICE_CURRENCY", "PAYMENT_CURRENCY", "PAYMENT_GROUP", "AMOUNT_REMAINING", "CREATED_BY", "CREATION_DATE"
, "DISCOUNT_AMOUNT_AVAILABLE", "DISCOUNT_AMOUNT_REMAINING", "DISCOUNT_DATE", "DUE_DATE", "FUTURE_PAY_DUE_DATE", "GROSS_AMOUNT", "HOLD_FLAG"
, "LAST_UPDATED_BY", "LAST_UPDATE_DATE", "LAST_UPDATE_LOGIN", "PMT_METHOD_LOOKUP_CODE", "PAYMENT_PRIORITY", "SECOND_DISCOUNT_DATE", "SECOND_DISC_AMT_AVAILABLE"
, "THIRD_DISCOUNT_DATE", "THIRD_DISC_AMT_AVAILABLE", "ATTRIBUTE_CATEGORY", "ATTRIBUTE1", "ATTRIBUTE2", "ATTRIBUTE3", "ATTRIBUTE4", "ATTRIBUTE5", "ATTRIBUTE6"
, "ATTRIBUTE7", "ATTRIBUTE8", "ATTRIBUTE9", "ATTRIBUTE10", "GLOBAL_ATTRIBUTE_CATEGORY", "GLOBAL_ATTRIBUTE1", "GLOBAL_ATTRIBUTE2", "GLOBAL_ATTRIBUTE3"
, "GLOBAL_ATTRIBUTE4", "GLOBAL_ATTRIBUTE5", "GLOBAL_ATTRIBUTE6", "GLOBAL_ATTRIBUTE7", "GLOBAL_ATTRIBUTE8", "GLOBAL_ATTRIBUTE9", "GLOBAL_ATTRIBUTE10", "ORG_ID"
, "LEDGER_ID", "CHART_OF_ACCOUNTS_ID", "FUNC_CURRENCY_CODE", "PERIOD_SET_NAME", "INVOICE_ID", "EXTERNAL_BANK_ACCOUNT_ID")
AS
  SELECT Ai.Invoice_Num Invoice_Number ,
    Ai.Invoice_Date ,
    Ai.Invoice_Type_Lookup_Code ,
    Aps.Payment_Num Payment_Number ,
    Aps.Payment_Status_Flag ,
    NVL(Ai.Vendor_Id,0) ,
    NVL(Ai.Vendor_Site_Id,0) ,
    Ai.Invoice_Currency_Code ,
    Ai.Payment_Currency_Code ,
    Ai.Pay_Group_Lookup_Code ,
    Aps.Amount_Remaining Amount_Remaining ,
    Aps.Created_By Created_By ,
    TRUNC(Aps.Creation_Date) Creation_Date ,
    Aps.Discount_Amount_Available Discount_Amount_Available ,
    Aps.Discount_Amount_Remaining Discount_Amount_Remaining ,
    TRUNC(Aps.Discount_Date) Discount_Date ,
    TRUNC(Aps.Due_Date) Due_Date ,
    TRUNC(Aps.Future_Pay_Due_Date) Future_Pay_Due_Date ,
    Aps.Gross_Amount Gross_Amount ,
    Aps.Hold_Flag Hold_Flag ,
    Aps.Last_Updated_By Last_Updated_By ,
    TRUNC(Aps.Last_Update_Date) Last_Update_Date ,
    Aps.Last_Update_Login Last_Update_Login ,
    Aps.Payment_Method_Lookup_Code ,
    Aps.Payment_Priority Payment_Priority ,
    Aps.Second_Discount_Date Second_Discount_Date ,
    Aps.Second_Disc_Amt_Available Second_Disc_Amt_Available ,
    Aps.Third_Discount_Date Third_Discount_Date ,
    Aps.Third_Disc_Amt_Available Third_Disc_Amt_Available ,
    Aps.Attribute_Category,
    Aps.Attribute1 ,
    Aps.Attribute2 ,
    Aps.Attribute3 ,
    Aps.Attribute4 ,
    Aps.Attribute5 ,
    Aps.Attribute6 ,
    Aps.Attribute7 ,
    Aps.Attribute8 ,
    Aps.Attribute9 ,
    Aps.Attribute10 ,
    Aps.Global_Attribute_Category,
    Aps.Global_Attribute1,
    Aps.Global_Attribute2,
    Aps.Global_Attribute3,
    Aps.Global_Attribute4,
    Aps.Global_Attribute5,
    Aps.Global_Attribute6,
    Aps.Global_Attribute7,
    Aps.Global_Attribute8,
    Aps.Global_Attribute9,
    Aps.Global_Attribute10,
    NVL(Aps.Org_Id,0),
    NVL(Gll.Ledger_Id,0),
    NVL(Gll.Chart_Of_Accounts_Id,0),
    Gll.Currency_Code,
    Gll.period_set_name,
    NVL(Aps.Invoice_Id,0) Invoice_Id ,
    NVL(Aps.External_Bank_Account_Id,0)
  FROM Apps.Ap_Payment_Schedules_All Aps ,
    Apps.Ap_Invoices_All Ai ,
    apps.GL_Ledgers Gll
  WHERE Aps.Invoice_Id   = Ai.Invoice_Id
  AND Ai.Set_Of_Books_Id = Gll.Ledger_Id;