/*
  Filename         :  XXAP_HOLDS_V.SQL

  Purpose          :  Display information about AP Invoice Holds to be use for 
                   :  OBIEE reporting. 
                   :  CHG0034322
 
  Change History   :
  ............................................................
 --  ver  date               name                             desc
 --  1.0  15/02/2015    John Hendrickson           CHG0034322 initial build
  ............................................................
*/
Create Or Replace View "XXBI"."XXAP_HOLDS_V" ("HOLD_ID", "HELD_BY_USER_ID", "HOLD_DATE", "HOLD_REASON", "HOLD_DESCRIPTION", "HOLD_RELEASE_REASON", "RELEASE_DESCRIPTION"
, "INSUFFICIENT_FUNDS_OWNER_ID", "INVOICE_ID", "LINE_LOCATION_ID", "ORG_ID", "HOLD_CODE", "STATUS_FLAG", "CREATION_DATE", "CREATED_BY", "LAST_UPDATE_DATE", "LAST_UPDATED_BY"
, "VENDOR_ID", "VENDOR_SITE_ID", "LEDGER_ID", "PERIOD_SET_NAME")
AS
  SELECT Ho.Hold_id ,
    Ho.Held_By ,
    TRUNC(Ho.Hold_Date) ,
    Ho.Hold_Reason ,
    Ho.Hold_Lookup_Code ,
    Ho.Release_Reason ,
    Ho.Release_Lookup_Code ,
    Ho.Responsibility_Id ,
    NVL(Ho.Invoice_Id,0) ,
    NVL(Ho.Line_Location_Id,0) ,
    Ho.Org_Id ,
    Ho.Hold_Lookup_Code ,
    Ho.Status_Flag ,
    TRUNC(Ho.Creation_Date) ,
    Ho.Created_By ,
    TRUNC(Ho.Last_Update_Date) ,
    Ho.Last_Updated_By,
    NVL(aia.vendor_id,0),
    NVL(aia.vendor_site_id,0),
    NVL(aia.set_of_books_id,0),
    Gl.Period_Set_Name
  FROM Apps.Ap_Holds_All Ho,
    Apps.Ap_Invoices_All Aia,
    apps.gl_ledgers gl
  WHERE ho.invoice_id     = aia.invoice_id
  AND aia.set_of_books_id = gl.ledger_id;