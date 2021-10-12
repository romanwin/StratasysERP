/*
  Filename         :  XXAR_AR_REVENUE_ADJ_V.SQL

  Purpose          :  Display information about AR Revenue Adjustments to be use for 
                   :  OBIEE reporting. 
                   :  CHG0034077
 
  Change History   :
  ............................................................
 --  ver  date               name                             desc
 --  1.0  15/02/2015    John Hendrickson           CHG0034077 initial build
  ............................................................
*/
  Create Or Replace View "XXBI"."XXAR_AR_REVENUE_ADJ_V" ("REVENUE_ADJUSTMENT_ID", "ORG_ID", "REVENUE_ADJUSTMENT_NUMBER", "CUSTOMER_TRX_ID", "APPLICATION_DATE", "SALES_CREDIT_TYPE"
  , "AMOUNT_MODE", "AMOUNT", "PERCENT", "LINE_SELECTION_MODE", "FROM_CUST_TRX_LINE_ID", "TO_CUST_TRX_LINE_ID", "FROM_INVENTORY_ITEM_ID", "TO_INVENTORY_ITEM_ID", "FROM_SALESGROUP_ID"
  , "TO_SALESGROUP_ID", "GL_DATE", "TYPE", "ADJ_REASON_CODE", "ADJ_REASON", "COMMENTS", "STATUS", "CREATION_DATE", "CREATED_BY", "LAST_UPDATE_DATE", "LAST_UPDATED_BY", "ATTRIBUTE_CATEGORY"
  , "ATTRIBUTE1", "ATTRIBUTE2", "ATTRIBUTE3", "ATTRIBUTE4", "ATTRIBUTE5", "ATTRIBUTE6", "ATTRIBUTE7", "ATTRIBUTE8", "ATTRIBUTE9", "ATTRIBUTE10") 
  AS 
  Select Ara.Revenue_Adjustment_Id
,      nvl(Ara.Org_Id,0)
,      Ara.Revenue_Adjustment_Number
,      Nvl(Ara.Customer_Trx_Id,0)
,      trunc(Ara.Application_Date)
,      Ara.Sales_Credit_Type
,      Ara.Amount_Mode
,      Ara.Amount
,      Ara.Percent
,      Ara.Line_Selection_Mode
,      Nvl(Ara.From_Cust_Trx_Line_Id,0)
,      Nvl(Ara.To_Cust_Trx_Line_Id,0)
,      Nvl(Ara.From_Inventory_Item_Id,0)
,      Nvl(Ara.To_Inventory_Item_Id,0)
,      Nvl(Ara.From_Salesgroup_Id,0)
,      Nvl(Ara.To_Salesgroup_Id,0)
,      trunc(Ara.Gl_Date)
,      Ara.Type
,      Ara.Reason_Code           As Adj_Reason_Code
,      Al.Meaning                As Adj_Reason
,      Ara.Comments
,      Ara.Status
,      trunc(Ara.Creation_Date)
,      Ara.Created_By
,      trunc(Ara.Last_Update_Date)
,      Ara.Last_Updated_By
,      Ara.Attribute_Category
,      Ara.attribute1
,      Ara.Attribute2
,      Ara.attribute3
,      Ara.Attribute4
,      Ara.attribute5
,      Ara.Attribute6
,      Ara.Attribute7
,      Ara.attribute8
,      Ara.Attribute9
,      Ara.attribute10
From  apps.Ar_Revenue_Adjustments_All          Ara
  ,   apps.Ar_Lookups                          Al
Where ara.reason_code      = al.lookup_code (+);