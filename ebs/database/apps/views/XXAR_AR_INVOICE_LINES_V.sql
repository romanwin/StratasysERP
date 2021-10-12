/*
  Filename         :  XXAR_AR_INVOICE_LINES_V.SQL

  Purpose          :  Display information about AR Invoice Lines to be use for 
                   :  OBIEE reporting. 
                   :  CHG0034077
 
  Change History   :
  ............................................................
 --  ver  date               name                             desc
 --  1.0  15/02/2015    John Hendrickson           CHG0034077 initial build
  ............................................................
*/
  Create Or Replace View "XXBI"."XXAR_AR_INVOICE_LINES_V" ("TRANSACTION_LINE_ID", "TRANSACTION_LINE_NUMBER", "AMOUNT", "LINE_REVENUE_AMOUNT", "REASON", "FUNCTIONAL_CURRENCY_CODE"
  , "INVOICE_CURRENCY_CODE", "EXCHANGE_RATE_DATE", "ITEM_DESCRIPTION", "QUANTITY_ORDERED", "QUANTITY_CREDITED", "QUANTITY_INVOICED", "UNIT_PRICE", "SALES_ORDER_NUMBER", "SALES_ORDER_LINE", "SALES_ORDER_LINE_ID"
  , "SALES_ORDER_DATE", "ACCOUNTING_RULE_DURATION", "RULE_START_DATE", "TRANSACTION_NUMBER", "TRANSACTION_DATE", "TRANSACTION_COMPLETE"
  , "UNIT_OF_MEASURE", "ACCOUNTING_RULE", "INTERFACE_LINE_CONTEXT", "INTERFACE_LINE_ATTRIBUTE1", "INTERFACE_LINE_ATTRIBUTE2"
  , "INTERFACE_LINE_ATTRIBUTE3", "INTERFACE_LINE_ATTRIBUTE4", "INTERFACE_LINE_ATTRIBUTE5", "INTERFACE_LINE_ATTRIBUTE6", "INTERFACE_LINE_ATTRIBUTE7", "INTERFACE_LINE_ATTRIBUTE8"
  , "INTERFACE_LINE_ATTRIBUTE9", "INTERFACE_LINE_ATTRIBUTE10", "INTERFACE_LINE_ATTRIBUTE11", "INTERFACE_LINE_ATTRIBUTE12", "INTERFACE_LINE_ATTRIBUTE13", "INTERFACE_LINE_ATTRIBUTE14"
  , "INTERFACE_LINE_ATTRIBUTE15", "GLOBAL_ATTRIBUTE_CATEGORY", "GLOBAL_ATTRIBUTE1", "GLOBAL_ATTRIBUTE2", "GLOBAL_ATTRIBUTE3", "GLOBAL_ATTRIBUTE4", "GLOBAL_ATTRIBUTE5", "GLOBAL_ATTRIBUTE6"
  , "GLOBAL_ATTRIBUTE7", "GLOBAL_ATTRIBUTE8", "GLOBAL_ATTRIBUTE9", "GLOBAL_ATTRIBUTE10", "GLOBAL_ATTRIBUTE11", "GLOBAL_ATTRIBUTE12", "GLOBAL_ATTRIBUTE13", "GLOBAL_ATTRIBUTE14"
  , "GLOBAL_ATTRIBUTE15", "CUSTOMER_TRX_ID", "PREVIOUS_CUSTOMER_TRX_ID", "PREVIOUS_CUSTOMER_TRX_LINE_ID", "INITIAL_CUSTOMER_TRX_LINE_ID", "INVENTORY_ITEM_ID", "MEMO_LINE_ID"
  , "UOM_CODE", "ACCOUNTING_RULE_ID", "ORG_ID", "LEDGER_ID", "CHART_OF_ACCOUNTS_ID", "BILL_TO_SITE_USE_ID", "SHIP_TO_SITE_USE_ID", "LAST_UPDATE_DATE", "LAST_UPDATED_BY", "CREATION_DATE", "CREATED_BY") AS 
  SELECT Ctl.Customer_Trx_Line_Id ,
    Ctl.Line_Number ,
    Ctl.Extended_Amount ,
    Ctl.revenue_amount ,
    Ctl.Reason_Code ,
    Gll.Currency_Code as functional_currency_code,
    Ct.Invoice_Currency_Code ,
    Ct.Exchange_Date as exchange_rate_date,
    Ctl.Description ,
    Ctl.Quantity_Ordered ,
    Ctl.Quantity_Credited ,
    Ctl.Quantity_Invoiced ,
    Ctl.Unit_Selling_Price ,
    Ctl.Sales_Order ,
    Ctl.Sales_Order_Line ,
    (case when ctl.interface_line_context = 'ORDER ENTRY' then ( (nvl(to_number(DECODE(LENGTH(TRIM(TRANSLATE(ctl.interface_line_attribute6, '0123456789',' ')))
            ,  Null, Ctl.Interface_Line_Attribute6
            ,  0)),0) )) else 0 end)        Sales_Order_line_id,
    trunc(Ctl.Sales_Order_Date) ,
    Ctl.Accounting_Rule_Duration ,
    trunc(Ctl.Rule_Start_Date) ,
    Ct.Trx_Number ,
    trunc(Ct.Trx_Date) ,
    Ct.Complete_Flag ,
    Uom.Unit_Of_Measure ,
    Rul.Name ,
    Ctl.Interface_Line_Context,
    Ctl.Interface_Line_Attribute1,
    Ctl.Interface_Line_Attribute2,
    Ctl.Interface_Line_Attribute3,
    Ctl.Interface_Line_Attribute4,
    Ctl.Interface_Line_Attribute5,
    Ctl.Interface_Line_Attribute6,
    Ctl.Interface_Line_Attribute7,
    Ctl.Interface_Line_Attribute8,
    Ctl.Interface_Line_Attribute9,
    Ctl.Interface_Line_Attribute10,
    Ctl.Interface_Line_Attribute11,
    Ctl.Interface_Line_Attribute12,
    Ctl.Interface_Line_Attribute13,
    Ctl.Interface_Line_Attribute14,
    Ctl.Interface_Line_Attribute15,
    Ctl.Global_Attribute_Category,
    Ctl.Global_Attribute1,
    Ctl.Global_Attribute2,
    Ctl.Global_Attribute3,
    Ctl.Global_Attribute4,
    Ctl.Global_Attribute5,
    Ctl.Global_Attribute6,
    Ctl.Global_Attribute7,
    Ctl.Global_Attribute8,
    Ctl.Global_Attribute9,
    Ctl.Global_Attribute10,
    Ctl.Global_Attribute11,
    Ctl.Global_Attribute12,
    Ctl.Global_Attribute13,
    Ctl.Global_Attribute14,
    Ctl.Global_Attribute15,
    Ctl.Customer_Trx_Id ,
    Ctl.Previous_Customer_Trx_Id ,
    Ctl.Previous_Customer_Trx_Line_Id ,
    Ctl.Initial_Customer_Trx_Line_Id ,
    nvl(Ctl.Inventory_Item_Id,0) ,
    Ctl.Memo_Line_Id ,
    Ctl.Uom_Code ,
    Ctl.Accounting_Rule_Id ,
    Ctl.Org_Id ,
    Gll.Ledger_Id ,
    Gll.Chart_Of_Accounts_Id ,
    Nvl(Ct.Bill_To_Site_Use_Id,0) ,      
    Nvl(ct.ship_to_site_use_id,0) ,
    Ctl.Last_Update_Date ,
    Ctl.Last_Updated_By ,
    Ctl.Creation_Date ,
    Ctl.Created_By
  From apps.Ra_Customer_Trx_Lines_all Ctl ,
       apps.Ra_Customer_Trx_all Ct ,
       apps.Mtl_Units_Of_Measure Uom ,
       apps.Ra_Rules Rul ,
       apps.Gl_Ledgers gll
  WHERE Ctl.Customer_Trx_Id             = Ct.Customer_Trx_Id
  AND Ctl.Uom_Code                      = Uom.Uom_Code (+)
  And Ctl.Accounting_Rule_Id            = Rul.Rule_Id (+)
  And Ct.Set_Of_Books_Id                = Gll.Ledger_Id(+);