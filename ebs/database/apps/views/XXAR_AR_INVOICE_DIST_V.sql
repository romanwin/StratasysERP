/*
  Filename         :  XXAR_AR_INVOICE_DIST_V.SQL

  Purpose          :  Display information about AR Invoice Distributions to be use for 
                   :  OBIEE reporting. 
                   :  CHG0034077
 
  Change History   :
  ............................................................
 --  ver  date               name                             desc
 --  1.0  15/02/2015    John Hendrickson           CHG0034077 initial build
  ............................................................
*/
  Create Or Replace View "XXBI"."XXAR_AR_INVOICE_DIST_V" ("TRANSACTION_DISTRIBUTION_ID", "ACCOUNT_TYPE", "AMOUNT", "FUNCTIONAL_AMOUNT", "GL_DATE", "GL_POSTED_DATE", "FUNCTIONAL_CURRENCY_CODE", "INVOICE_CURRENCY_CODE"
  , "EXCHANGE_RATE_DATE", "TRANSACTION_DATE", "CUSTOMER_TRX_ID", "CUSTOMER_TRX_LINE_ID", "SALES_ORDER_LINE_ID", "CODE_COMBINATION_ID", "ORG_ID", "INVENTORY_ITEM_ID", "LEDGER_ID"
  , "CHART_OF_ACCOUNTS_ID", "BILL_TO_SITE_USE_ID", "SHIP_TO_SITE_USE_ID", "REVENUE_ADJUSTMENT_ID", "LAST_UPDATE_DATE", "LAST_UPDATED_BY", "CREATION_DATE"
  , "CREATED_BY", "ATTRIBUTE1", "ATTRIBUTE2", "ATTRIBUTE3", "ATTRIBUTE4", "ATTRIBUTE5", "ATTRIBUTE6", "ATTRIBUTE7", "ATTRIBUTE8", "ATTRIBUTE9", "ATTRIBUTE10" ) 
  AS 
  Select
    RcTlgd.Cust_Trx_Line_Gl_Dist_Id ,
    RcTlgd.Account_Class ,
    Nvl(RcTlgd.Amount,0),
    Nvl(Rctlgd.Acctd_Amount,0) Functional_Amount ,
    Trunc(Rctlgd.Gl_Date) ,
    Trunc(Rctlgd.Gl_Posted_Date) ,
    Gll.Currency_Code as functional_currency_code,
    Ct.Invoice_Currency_Code ,
    trunc(Ct.Exchange_Date) ,
    Trunc(Ct.Trx_Date) ,
    Nvl(Rctlgd.Customer_Trx_Id,0) ,
    Nvl(RcTlgd.Customer_Trx_Line_Id,0) ,
    (case when ctl.interface_line_context = 'ORDER ENTRY' then ( (nvl(to_number(DECODE(LENGTH(TRIM(TRANSLATE(ctl.interface_line_attribute6, '0123456789',' ')))
            ,  Null, Ctl.Interface_Line_Attribute6
            ,  0)),0) )) Else 0 End)        Sales_Order_Line_Id,
    Nvl(Rctlgd.Code_Combination_Id,0) ,
    RcTlgd.Org_Id ,
    Nvl(Ctl.Inventory_Item_Id,0) ,
    Gll.Ledger_Id ,
    nvl(Gll.Chart_Of_Accounts_Id,0) ,
    Nvl(Ct.Bill_To_Site_Use_Id,0) ,      
    Nvl(Ct.Ship_To_Site_Use_Id,0) ,
    Nvl(RcTlgd.Revenue_Adjustment_Id,0) ,
    Trunc(RcTlgd.Last_Update_Date) ,
    RcTlgd.Last_Updated_By ,
    Trunc(RcTlgd.Creation_Date) ,
    Rctlgd.Created_By ,
    Rctlgd.Attribute1 ,
    Rctlgd.Attribute2 ,
    Rctlgd.Attribute3 ,
    Rctlgd.Attribute4 ,
    Rctlgd.Attribute5 ,
    Rctlgd.Attribute6 ,
    Rctlgd.Attribute7 ,
    Rctlgd.Attribute8 ,
    Rctlgd.Attribute9 ,
    Rctlgd.Attribute10 
  From  Apps.Ra_Customer_Trx_All Ct,
    Apps.Ra_Customer_Trx_Lines_All Ctl,
    Apps.Ra_Cust_Trx_Line_Gl_Dist_All Rctlgd,
    Apps.Gl_Ledgers Gll
  Where  Rctlgd.Customer_Trx_Line_Id = Ctl.Customer_Trx_Line_Id
  And    Ctl.Customer_Trx_Id         = Ct.Customer_Trx_Id
  And    Ct.set_of_books_id          = gll.ledger_id; 