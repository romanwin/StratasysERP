/*
  Filename         :  XXAR_AR_INVOICE_DIST_XLA_V.SQL

  Purpose          :  Display information about AR Invoice Distributions(XLA) to be use for 
                   :  OBIEE reporting. 
                   :  CHG0034077
 
  Change History   :
  ............................................................
 --  ver  date               name                             desc
 --  1.0  15/02/2015    John Hendrickson           CHG0034077 initial build
  ............................................................
*/
  Create Or Replace View "XXBI"."XXAR_AR_INVOICE_DIST_XLA_V" ("TRANSACTION_DISTRIBUTION_ID", "ACCOUNT_TYPE", "AMOUNT", "FUNCTIONAL_AMOUNT", "DEBIT_AMOUNT"
  , "CREDIT_AMOUNT", "FUNCTIONAL_DEBIT_AMOUNT", "FUNCTIONAL_CREDIT_AMOUNT", "GL_DATE", "FUNCTIONAL_CURRENCY_CODE", "INVOICE_CURRENCY_CODE"
  , "EXCHANGE_RATE_DATE", "TRANSACTION_DATE", "CUSTOMER_TRX_ID", "CUSTOMER_TRX_LINE_ID", "SALES_ORDER_LINE_ID", "CODE_COMBINATION_ID", "ORG_ID", "INVENTORY_ITEM_ID", "LEDGER_ID"
  , "CHART_OF_ACCOUNTS_ID", "BILL_TO_SITE_USE_ID", "SHIP_TO_SITE_USE_ID", "REVENUE_ADJUSTMENT_ID", "LAST_UPDATE_DATE", "LAST_UPDATED_BY", "CREATION_DATE"
  , "CREATED_BY", "ATTRIBUTE1", "ATTRIBUTE2", "ATTRIBUTE3", "ATTRIBUTE4", "ATTRIBUTE5", "ATTRIBUTE6", "ATTRIBUTE7", "ATTRIBUTE8", "ATTRIBUTE9", "ATTRIBUTE10", "SOURCE_DISTRIBUTION_TYPE" ) AS 
  SELECT
    Tlgd.Cust_Trx_Line_Gl_Dist_Id ,
    Tlgd.Account_Class ,
    nvl(Tlgd.Amount,0),
    nvl(Tlgd.Acctd_Amount,0) Funcational_Amount ,
    DECODE(SIGN(Tlgd.Amount), -1, ABS(Tlgd.Amount), NULL) ,
    DECODE(SIGN(Tlgd.Amount), 1, Tlgd.Amount, NULL) ,
    DECODE(SIGN(Tlgd.Acctd_Amount), -1, ABS(Tlgd.Acctd_Amount), NULL) ,
    Decode(Sign(Tlgd.Acctd_Amount), 1, Tlgd.Acctd_Amount, Null) ,
    trunc(Tlgd.Gl_Date) ,
    Gll.Currency_Code as functional_currency_code,
    Ct.Invoice_Currency_Code ,
    trunc(Ct.Exchange_Date) ,
    trunc(ct.trx_date) ,
    Nvl(Tlgd.Customer_Trx_Id,0) ,
    Nvl(Tlgd.Customer_Trx_Line_Id,0) ,
    (case when ctl.interface_line_context = 'ORDER ENTRY' then ( (nvl(to_number(DECODE(LENGTH(TRIM(TRANSLATE(ctl.interface_line_attribute6, '0123456789',' ')))
            ,  Null, Ctl.Interface_Line_Attribute6
            ,  0)),0) )) Else 0 End)        Sales_Order_Line_Id,
    Nvl(Tlgd.Code_Combination_Id,0) ,
    Tlgd.Org_Id ,
    Nvl(Ctl.Inventory_Item_Id,0) ,
    Gll.Ledger_Id ,
    nvl(Gll.Chart_Of_Accounts_Id,0) ,
    Nvl(Ct.Bill_To_Site_Use_Id,0) ,      
    Nvl(ct.ship_to_site_use_id,0) ,
    NVL(tlgd.revenue_adjustment_id,0) ,
    trunc(Tlgd.Last_Update_Date) ,
    Tlgd.Last_Updated_By ,
    Trunc(Tlgd.Creation_Date) ,
    Tlgd.Created_By ,
    tlgd.Attribute1 ,
    tlgd.Attribute2 ,
    tlgd.Attribute3 ,
    tlgd.Attribute4 ,
    tlgd.Attribute5 ,
    tlgd.Attribute6 ,
    tlgd.Attribute7 ,
    tlgd.Attribute8 ,
    tlgd.Attribute9 ,
    Tlgd.Attribute10 ,
    'RA_CUST_TRX_LINE_GL_DIST_ALL' as source_distribution_type
  From  Apps.Ra_Customer_Trx_All Ct,
    Apps.Ra_Customer_Trx_Lines_All Ctl,
    Apps.Ra_Cust_Trx_Line_Gl_Dist_All Tlgd,
    Apps.Gl_Ledgers Gll
  Where  tlgd.Customer_Trx_Id          = Ct.Customer_Trx_Id(+)
  And    Tlgd.Customer_Trx_Line_Id     = Ctl.Customer_Trx_Line_Id(+)
  And    Tlgd.Account_Set_Flag         = 'N'   
  And    tlgd.Set_Of_Books_Id          = Gll.Ledger_Id(+);