/*
  Filename         :  XXAP_INVOICE_PAYMENTS_V.SQL

  Purpose          :  Display information about AP Invoice Payments to be use for 
                   :  OBIEE reporting. 
                   :  CHG0034322
 
  Change History   :
  ............................................................
 --  ver  date               name                             desc
 --  1.0  15/02/2015    John Hendrickson           CHG0034322 initial build
  ............................................................
*/
Create Or Replace View "XXBI"."XXAP_INVOICE_PAYMENTS_V" ("INVOICE_PAYMENT_ID", "ACCOUNTING_DATE", "ACCRUAL_POSTED_FLAG", "AMOUNT"
, "ASSETS_ADDITION_FLAG", "BANK_ACCOUNT_NUMBER", "BANK_ACCOUNT_TYPE", "BANK_NUMBER", "CASH_POSTED_FLAG", "DISCOUNT_LOST", "DISCOUNT_TAKEN"
, "EXCHANGE_DATE", "EXCHANGE_RATE", "EXCHANGE_RATE_TYPE", "INVOICE_BASE_AMOUNT", "PAYMENT_BASE_AMOUNT", "PAYMENT_NUMBER", "PERIOD_NAME"
, "POSTED_FLAG", "INVOICE_PAYMENT_TYPE", "CHART_OF_ACCOUNTS_ID", "CURRENCY_CODE", "PERIOD_SET_NAME", "EXTERNAL_BANK_ACCOUNT_ID"
, "ACCTS_PAY_CODE_COMBINATION_ID", "ASSET_CODE_COMBINATION_ID", "CHECK_ID", "GAIN_CODE_COMBINATION_ID", "INVOICE_ID", "LOSS_CODE_COMBINATION_ID"
, "LEDGER_ID", "ORG_ID", "CREATED_BY", "CREATION_DATE", "LAST_UPDATED_BY", "LAST_UPDATE_DATE", "LAST_UPDATE_LOGIN", "VENDOR_ID", "VENDOR_SITE_ID")
AS
  SELECT
    Aip.Invoice_Payment_Id Invoice_Payment_Id ,
    TRUNC(Aip.Accounting_Date) Accounting_Date ,
    Aip.Accrual_Posted_Flag Accrual_Posted_Flag ,
    Aip.Amount Amount ,
    Aip.Assets_Addition_Flag Assets_Addition_Flag ,
    Aip.Bank_Account_Num Bank_Account_Number ,
    Aip.Bank_Account_Type Bank_Account_Type ,
    Aip.Bank_Num Bank_Number ,
    Aip.Cash_Posted_Flag Cash_Posted_Flag ,
    Aip.Discount_Lost Discount_Lost ,
    Aip.Discount_Taken Discount_Taken ,
    Aip.Exchange_Date Exchange_Date ,
    Aip.Exchange_Rate Exchange_Rate ,
    Aip.Exchange_Rate_Type Exchange_Rate_Type ,
    Aip.Invoice_Base_Amount Invoice_Base_Amount ,
    Aip.Payment_Base_Amount Payment_Base_Amount ,
    Aip.Payment_Num Payment_Number ,
    Aip.Period_Name Period_Name ,
    Aip.Posted_Flag Posted_Flag ,
    Aip.Invoice_Payment_Type Invoice_Payment_Type ,
    NVL(Gll.Chart_Of_Accounts_Id,0) ,
    NVL(Gll.Currency_Code,0) ,
    gll.period_set_name ,
    NVL(Aip.External_Bank_Account_Id,0) External_Bank_Account_Id ,
    NVL(Aip.Accts_Pay_Code_Combination_Id,0) Accts_Pay_Code_Combination_Id ,
    NVL(Aip.Asset_Code_Combination_Id,0) Asset_Code_Combination_Id ,
    NVL(Aip.Check_Id,0) Check_Id ,
    NVL(Aip.Gain_Code_Combination_Id,0) Gain_Code_Combination_Id ,
    NVL(Aip.Invoice_Id,0) Invoice_Id ,
    NVL(Aip.Loss_Code_Combination_Id,0) Loss_Code_Combination_Id ,
    NVL(Aip.Set_Of_Books_Id,0) ,
    NVL(Aip.org_id,0) ,
    Aip.Created_By Created_By ,
    TRUNC(Aip.Creation_Date) Creation_Date ,
    Aip.Last_Updated_By Last_Updated_By ,
    TRUNC(Aip.Last_Update_Date) Last_Update_Date ,
    Aip.Last_Update_Login Last_Update_Login,
    aia.vendor_id,
    Aia.Vendor_Site_Id
  FROM Apps.Ap_Invoice_Payments_All Aip ,
    Apps.Ap_Invoices_All Aia,
    apps.Gl_Ledgers Gll
  WHERE Aip.Set_Of_Books_Id = Gll.Ledger_Id
  AND aip.invoice_id        = aia.invoice_id;
