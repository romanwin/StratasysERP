/*
  Filename         :  XXAP_CHECKS_V.SQL

  Purpose          :  Display information about AP Checks to be use for 
                   :  OBIEE reporting. 
                   :  CHG0034322
 
  Change History   :
  ............................................................
 --  ver  date               name                             desc
 --  1.0  15/02/2015    John Hendrickson           CHG0034322 initial build
  ............................................................
*/
Create Or Replace View "XXBI"."XXAP_CHECKS_V" ("CHECK_ID", "BANK_ACCOUNT_NAME", "AMOUNT", "CURRENCY_CODE", "CHECK_DATE", "CHECK_NUMBER", "CHECK_VOUCHER_NUMBER", "CHECKRUN_NAME"
, "PAYMENT_TYPE", "PAYMENT_STATUS", "PAYMENT_METHOD", "CHECK_SEQUENCE_NUMBER", "CLEARED_AMOUNT", "CLEARED_DATE", "VENDOR_ID", "VENDOR_SITE_ID", "VENDOR_NAME", "ADDRESS_LINE_1"
, "ADDRESS_LINE_2", "ADDRESS_LINE_3", "VENDOR_CITY", "VENDOR_STATE", "VENDOR_POSTAL_CODE", "VENDOR_COUNTRY", "VENDOR_SITE_CODE", "VENDOR_BANK_ACCOUNT_NUMBER", "VENDOR_BANK_ACCOUNT_TYPE"
, "TREASURY_PAYMENT_DATE", "TREASURY_PAYMENT_NUMBER", "STOP_PAYMENT_RELEASED_DATE", "STOP_PAYMENT_RELEASED_USER_ID", "STOP_PAYMENT_RECORDED_DATE", "STOP_PAYMENT_RECORDED_USER_ID", "VOID_DATE"
, "FUTURE_PAY_DUE_DATE", "CLEARED_FUNCTIONAL_AMOUNT", "CLEARED_CURRENCY_EXCH_RATE", "CLEARED_CURRENCY_EXCH_DATE", "CLEARED_CRNCY_EXCH_RATE_TYPE", "CURRENCY_EXCHANGE_RATE", "CURRENCY_EXCHANGE_DATE"
, "CURRENCY_EXCHANGE_RATE_TYPE", "FUNCTIONAL_AMOUNT", "CLEARED_ERROR_AMOUNT", "CLEARED_CHARGES_AMOUNT", "CLEARED_ERROR_FUNCTIONAL_AMT", "CLEARED_CHARGES_FUNCTIONAL_AMT", "TRANSFER_PRIORITY"
, "STAMP_DUTY_AMOUNT", "STAMP_DUTY_FUNCTIONAL_AMOUNT", "BANK_ACCOUNT_ID", "EXTERNAL_BANK_ACCOUNT_ID", "CREATION_DATE", "CREATED_BY", "LAST_UPDATE_DATE", "LAST_UPDATED_BY")
AS
  SELECT Ch.Check_Id ,
    Ch.Bank_Account_Name ,
    Ch.Amount ,
    Ch.Currency_Code ,
    TRUNC(Ch.Check_Date) ,
    Ch.Check_Number ,
    Ch.Check_Voucher_Num ,
    Ch.Checkrun_Name ,
    Ch.Payment_Type_Flag ,
    Ch.Status_Lookup_Code ,
    Ch.Payment_Method_Lookup_Code ,
    Ch.Doc_Sequence_Id ,
    Ch.Cleared_Amount ,
    TRUNC(Ch.Cleared_Date) ,
    NVL(Ch.Vendor_Id,0) ,
    NVL(Ch.Vendor_Site_Id,0) ,
    Ch.Vendor_Name ,
    Ch.Address_Line1 ,
    Ch.Address_Line2 ,
    Ch.Address_Line3 ,
    Ch.City ,
    Ch.State ,
    Ch.Zip ,
    Ch.Country ,
    Ch.Vendor_Site_Code ,
    Ch.Bank_Account_Num ,
    Ch.Bank_Account_Type ,
    Ch.Treasury_Pay_Date ,
    Ch.Treasury_Pay_Number ,
    Ch.Released_At ,
    Ch.Released_By ,
    Ch.Stopped_At ,
    Ch.Stopped_By ,
    TRUNC(Ch.Void_Date) ,
    TRUNC(Ch.Future_Pay_Due_Date) ,
    Ch.Cleared_Base_Amount ,
    Ch.Cleared_Exchange_Rate ,
    Ch.Cleared_Exchange_Date ,
    Ch.Cleared_Exchange_Rate_Type ,
    Ch.Exchange_Rate ,
    TRUNC(Ch.Exchange_Date) ,
    Ch.Exchange_Rate_Type ,
    Ch.Base_Amount ,
    Ch.Cleared_Error_Amount ,
    Ch.Cleared_Charges_Amount ,
    Ch.Cleared_Error_Base_Amount ,
    Ch.Cleared_Charges_Base_Amount ,
    Ch.Transfer_Priority ,
    Ch.Stamp_Duty_Amt ,
    Ch.Stamp_Duty_Base_Amt ,
    Ch.Ce_Bank_Acct_Use_Id ,
    Ch.External_Bank_Account_Id ,
    TRUNC(Ch.Creation_Date) ,
    Ch.Created_By ,
    TRUNC(Ch.Last_Update_Date) ,
    Ch.Last_Updated_By
  From Apps.Ap_Checks_All Ch;