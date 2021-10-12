/*
  Filename         :  XXAR_CASH_RECEIPTS_V.SQL

  Purpose          :  Display information about AR Cash Receipts to be use for 
                   :  OBIEE reporting. 
                   :  CHG0034077
 
  Change History   :
  ............................................................
 --  ver  date               name                             desc
 --  1.0  15/02/2015    John Hendrickson           CHG0034077 initial build
  ............................................................
*/
  Create Or Replace View "XXBI"."XXAR_AR_CASH_RECEIPTS_V" ("CASH_RECEIPT_ID", "RECEIPT_NUMBER", "RECEIPT_AMOUNT", "RECEIPT_DATE", "DOCUMENT_SEQUENCE_NUMBER"
  , "CURRENCY_EXCHANGE_RATE", "CURRENCY_EXCHANGE_RATE_TYPE", "CURRENCY_EXCHANGE_RATE_DATE", "DEPOSIT_DATE", "RECEIPT_STATUS", "REVERSAL_REASON", "REVERSAL_DATE"
  , "REVERSAL_COMMENTS", "REVERSAL_CATEGORY", "CUSTOMER_RECEIPT_REFERENCE", "FACTORING_FLAG", "FACTOR_DISCOUNT_AMOUNT", "OVERRIDE_REMIT_ACCOUNT", "ANTICIPATED_CLEARING_DATE"
  , "NOTE_RECEIVABLE_ISSUER_NAME", "NOTE_RECEIVABLE_ISSUE_DATE", "COMMENTS", "USSGL_TRANSACTION_CODE", "ATTRIBUTE_CATEGORY", "ATTRIBUTE1", "ATTRIBUTE2", "ATTRIBUTE3"
  , "ATTRIBUTE4", "ATTRIBUTE5", "ATTRIBUTE6", "ATTRIBUTE7", "ATTRIBUTE8", "ATTRIBUTE9", "ATTRIBUTE10", "GLOBAL_ATTRIBUTE_CATEGORY", "GLOBAL_ATTRIBUTE1", "GLOBAL_ATTRIBUTE2"
  , "GLOBAL_ATTRIBUTE3", "GLOBAL_ATTRIBUTE4", "GLOBAL_ATTRIBUTE5", "GLOBAL_ATTRIBUTE6", "GLOBAL_ATTRIBUTE7", "GLOBAL_ATTRIBUTE8", "GLOBAL_ATTRIBUTE9", "GLOBAL_ATTRIBUTE10"
  , "PAYMENT_METHOD_NAME", "ORG_ID", "CURRENCY_CODE", "RECEIPT_METHOD_ID", "PAY_FROM_CUSTOMER", "CUSTOMER_SITE_USE_ID", "REMITTANCE_BANK_ACCOUNT_ID", "CUSTOMER_BANK_ACCOUNT_ID"
  , "ISSUER_BANK_BRANCH_ID", "LEDGER_ID", "CHART_OF_ACCOUNTS_ID", "FUNC_CURRENCY_CODE", "LAST_UPDATE_DATE", "LAST_UPDATED_BY", "CREATION_DATE", "CREATED_BY") 
  AS 
  SELECT
    Cr.Cash_Receipt_Id ,
    Cr.Receipt_Number ,
    Cr.Amount ,
    trunc(Cr.Receipt_Date) ,
    Cr.Doc_Sequence_Value ,
    Cr.Exchange_Rate ,
    Cr.Exchange_Rate_Type ,
    trunc(Cr.Exchange_Date) ,
    Cr.Deposit_Date ,
    Cr.Status ,
    Cr.Reversal_Reason_Code ,
    Cr.Reversal_Date ,
    Cr.Reversal_Comments ,
    Cr.Reversal_Category ,
    Cr.Customer_Receipt_Reference ,
    Cr.Selected_For_Factoring_Flag ,
    Cr.Factor_Discount_Amount ,
    Cr.Override_Remit_Account_Flag ,
    trunc(Cr.Anticipated_Clearing_Date) ,
    Cr.Issuer_Name ,
    trunc(Cr.Issue_Date) ,
    Cr.Comments ,
    Cr.Ussgl_Transaction_Code ,
    Rm.Name ,
    Cr.Attribute_Category,
    Cr.Attribute1,
    Cr.Attribute2,
    Cr.Attribute3,
    Cr.Attribute4,
    Cr.Attribute5,
    Cr.Attribute6,
    Cr.Attribute7,
    Cr.Attribute8,
    Cr.Attribute9,
    Cr.Attribute10,
    Cr.Global_Attribute_Category,
    Cr.Global_Attribute1,
    Cr.Global_Attribute2,
    Cr.Global_Attribute3,
    Cr.Global_Attribute4,
    Cr.Global_Attribute5,
    Cr.Global_Attribute6,
    Cr.Global_Attribute7,
    Cr.Global_Attribute8,
    Cr.Global_Attribute9,
    Cr.Global_Attribute10,
    /* IDS */
    Cr.Org_Id ,
    Cr.Currency_Code ,
    Cr.Receipt_Method_Id ,
    Cr.Pay_From_Customer ,
    nvl(Cr.Customer_Site_Use_Id,0) ,
    Cr.Remit_Bank_Acct_Use_Id ,
    Cr.Payment_Trxn_Extension_Id ,
    Cr.Issuer_Bank_Branch_Id ,
    Cr.set_of_books_Id ,
    Gll.Chart_Of_Accounts_Id ,
    Gll.currency_code ,
    /* WHO COLUMNS */
    trunc(Cr.Last_Update_Date) ,
    Cr.Last_Updated_By ,
    trunc(Cr.Creation_Date) ,
    Cr.Created_By
  From apps.Ar_Cash_Receipts_All Cr,
       apps.Gl_Ledgers Gll,
       apps.Ar_Receipt_Methods Rm
  WHERE Cr.Type                   = 'CASH'
  And Cr.Receipt_Method_Id        = Rm.Receipt_Method_Id
  AND Cr.set_of_books_id          = Gll.ledger_id;