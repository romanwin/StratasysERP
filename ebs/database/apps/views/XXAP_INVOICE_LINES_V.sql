/*
  Filename         :  XXAP_INVOICE_LINES_V.SQL

  Purpose          :  Display information about AP Invoice Lines to be use for 
                   :  OBIEE reporting. 
                   :  CHG0034322
 
  Change History   :
  ............................................................
 --  ver  date               name                             desc
 --  1.0  15/02/2015    John Hendrickson           CHG0034322 initial build
  ............................................................
*/
  Create Or Replace View "XXBI"."XXAP_INVOICE_LINES_V"(INVOICE_ID
  ,LINE_NUMBER
  ,LINE_TYPE_LOOKUP_CODE
  ,LINE_TYPE
  ,Requester_Id
  ,LINE_DESCRIPTION
  ,LINE_SOURCE
  ,ORG_ID
  ,LINE_GROUP_NUMBER
  ,INVENTORY_ITEM_ID
  ,ITEM_DESCRIPTION
  ,SERIAL_NUMBER
  ,MANUFACTURER
  ,MODEL_NUMBER
  ,WARRANTY_NUMBER
  ,GENERATE_DISTRIBUTIONS
  ,MATCH_TYPE
  ,Distribution_Set_Id
  ,PRORATE_ACROSS_ALL_ITEMS
  ,GL_DATE
  ,PERIOD_NAME
  ,DEFERRED_ACCTG_FLAG
  ,DEFERRED_START_DATE
  ,DEFERRED_END_DATE
  ,DEFERRED_NUMBER_OF_PERIODS
  ,DEFERRED_PERIOD_TYPE
  ,Ledger_Id
  ,LINE_AMOUNT
  ,LINE_BASE_AMOUNT
  ,LINE_ROUNDING_AMOUNT
  ,LINE_QUANTITY_INVOICED
  ,Line_Unit_Meas_Lookup_Code
  ,LINE_UNIT_PRICE
  ,WFAPPROVAL_STATUS_LOOKUP_CODE
  ,WFAPPROVAL_STATUS_DISP
  ,DISCARDED_FLAG
  ,LINE_ORIGINAL_AMOUNT
  ,LINE_ORIGINAL_BASE_AMOUNT
  ,LINE_ORIGINAL_ROUNDING_AMOUNT
  ,CANCELLED_FLAG
  ,INCOME_TAX_REGION
  ,INCOME_TAX_TYPE
  ,LINE_STAT_AMOUNT
  ,Prepay_Invoice_Id
  ,PREPAY_LINE_NUMBER
  ,INVOICE_INCLUDES_PREPAY_FLAG
  ,Corrected_Inv_Id
  ,CORRECTED_LINE_NUMBER
  ,Po_Header_Id
  ,Po_Line_Id
  ,Po_Release_Id
  ,Po_Line_Location_Id
  ,Po_Distribution_Id
  ,Rcv_Transaction_Id
  ,FINAL_MATCH_FLAG
  ,ASSETS_TRACKING_FLAG
  ,Asset_Book_Type_Code
  ,ASSET_CATEGORY_ID
  ,Project_Id
  ,Task_Id
  ,EXPENDITURE_TYPE
  ,EXPENDITURE_ITEM_DATE
  ,Expenditure_Organization_Id
  ,LINE_PA_QUANTITY
  ,Pa_Cc_Ar_Invoice_Id
  ,Intercompany_Invoice_Line_Num
  ,PA_CC_PROCESSED_CODE
  ,AWARD_ID
  ,Awt_Group_Id
  ,REFERENCE_1
  ,REFERENCE_2
  ,RECEIPT_VERIFIED_FLAG
  ,RECEIPT_REQUIRED_FLAG
  ,RECEIPT_MISSING_FLAG
  ,JUSTIFICATION
  ,EXPENSE_GROUP
  ,START_EXPENSE_DATE
  ,END_EXPENSE_DATE
  ,RECEIPT_CURRENCY_CODE
  ,RECEIPT_CONVERSION_RATE
  ,RECEIPT_CURRENCY_AMOUNT
  ,DAILY_AMOUNT
  ,WEB_PARAMETER_ID
  ,ADJUSTMENT_REASON
  ,MERCHANT_DOCUMENT_NUMBER
  ,MERCHANT_NAME
  ,MERCHANT_REFERENCE
  ,MERCHANT_TAX_REG_NUMBER
  ,MERCHANT_TAXPAYER_ID
  ,COUNTRY_OF_SUPPLY
  ,CREDIT_CARD_TRX_ID
  ,COMPANY_PREPAID_INVOICE_ID
  ,CC_REVERSAL_FLAG
  ,CREATION_DATE
  ,CREATED_BY
  ,LAST_UPDATED_BY
  ,LAST_UPDATE_DATE
  ,LAST_UPDATE_LOGIN
  ,PROGRAM_APPLICATION_ID
  ,PROGRAM_ID
  ,PROGRAM_UPDATE_DATE
  ,Request_Id
  ,ATTRIBUTE_CATEGORY
  ,ATTRIBUTE1
  ,ATTRIBUTE2
  ,ATTRIBUTE3
  ,ATTRIBUTE4
  ,ATTRIBUTE5
  ,ATTRIBUTE6
  ,ATTRIBUTE7
  ,ATTRIBUTE8
  ,ATTRIBUTE9
  ,ATTRIBUTE10
  ,GLOBAL_ATTRIBUTE_CATEGORY
  ,GLOBAL_ATTRIBUTE1
  ,GLOBAL_ATTRIBUTE2
  ,GLOBAL_ATTRIBUTE3
  ,GLOBAL_ATTRIBUTE4
  ,GLOBAL_ATTRIBUTE5
  ,GLOBAL_ATTRIBUTE6
  ,GLOBAL_ATTRIBUTE7
  ,GLOBAL_ATTRIBUTE8
  ,GLOBAL_ATTRIBUTE9
  ,Global_Attribute10
  ,PRIMARY_INTENDED_USE
  ,Ship_To_Location_Id
  ,PRODUCT_FISC_CLASSIFICATION
  ,USER_DEFINED_FISC_CLASS
  ,TRX_BUSINESS_CATEGORY
  ,PRODUCT_TYPE
  ,PRODUCT_CATEGORY
  ,ASSESSABLE_VALUE
  ,CONTROL_AMOUNT
  ,INCLUDED_TAX_AMOUNT
  ,TOTAL_REC_TAX_AMOUNT
  ,TOTAL_NREC_TAX_AMOUNT
  ,TAX_REGIME_CODE
  ,TAX
  ,TAX_STATUS_CODE
  ,TAX_RATE_CODE
  ,TAX_RATE_ID
  ,TAX_RATE
  ,TAX_JURISDICTION_CODE
  ,SUMMARY_TAX_LINE_ID
  ,TAX_ALREADY_CALCULATED_FLAG
  ,TAX_CLASSIFICATION_CODE
  ,APPLICATION_ID
  ,PRODUCT_TABLE
  ,Cost_Factor_Id
  ,RETAINED_AMOUNT
  ,RETAINED_AMOUNT_REMAINING
  ,Retained_Invoice_Id
  ,RETAINED_LINE_NUMBER
  ,LINE_SELECTED_FOR_RELEASE_FLAG
  ,Rcv_Shipment_Line_Id
  ,Pay_Awt_Group_Id
  )
    AS 
  Select
   AIL.INVOICE_ID          INVOICE_ID
  ,AIL.LINE_NUMBER         LINE_NUMBER
  ,AIL.LINE_TYPE_LOOKUP_CODE LINE_TYPE_LOOKUP_CODE
  ,ALC1.DISPLAYED_FIELD    LINE_TYPE
  ,AIL.REQUESTER_ID        REQUESTER_ID
  ,AIL.DESCRIPTION         DESCRIPTION
  ,AIL.LINE_SOURCE         LINE_SOURCE
  ,AIL.ORG_ID              ORG_ID
  ,AIL.LINE_GROUP_NUMBER   LINE_GROUP_NUMBER
  ,AIL.INVENTORY_ITEM_ID   INVENTORY_ITEM_ID
  ,AIL.ITEM_DESCRIPTION    ITEM_DESCRIPTION
  ,AIL.SERIAL_NUMBER       SERIAL_NUMBER
  ,AIL.MANUFACTURER        MANUFACTURER
  ,AIL.MODEL_NUMBER        MODEL_NUMBER
  ,AIL.WARRANTY_NUMBER     WARRANTY_NUMBER
  ,AIL.GENERATE_DISTS      GENERATE_DISTRIBUTIONS
  ,AIL.MATCH_TYPE          MATCH_TYPE
  ,Ail.Distribution_Set_Id Distribution_Set_Id
  ,AIL.PRORATE_ACROSS_ALL_ITEMS PRORATE_ACROSS_ALL_ITEMS
  ,AIL.ACCOUNTING_DATE     GL_DATE
  ,AIL.PERIOD_NAME         PERIOD_NAME
  ,AIL.DEFERRED_ACCTG_FLAG DEFERRED_ACCTG_FLAG
  ,AIL.DEF_ACCTG_START_DATE DEFERRED_START_DATE
  ,AIL.DEF_ACCTG_END_DATE   DEFERRED_END_DATE
  ,AIL.DEF_ACCTG_NUMBER_OF_PERIODS DEFERRED_NUMBER_OF_PERIODS
  ,AIL.DEF_ACCTG_PERIOD_TYPE DEFERRED_PERIOD_TYPE
  ,AIL.SET_OF_BOOKS_ID     SET_OF_BOOKS_ID
  ,AIL.AMOUNT              AMOUNT
  ,AIL.BASE_AMOUNT         BASE_AMOUNT
  ,AIL.ROUNDING_AMT        ROUNDING_AMOUNT
  ,AIL.QUANTITY_INVOICED   QUANTITY_INVOICED
  ,AIL.UNIT_MEAS_LOOKUP_CODE UNIT_MEAS_LOOKUP_CODE
  ,AIL.UNIT_PRICE          UNIT_PRICE
  ,AIL.WFAPPROVAL_STATUS   WFAPPROVAL_STATUS_LOOKUP_CODE
  ,ALC2.DISPLAYED_FIELD    WFAPPROVAL_STATUS_DISP
  ,AIL.DISCARDED_FLAG      DISCARDED_FLAG
  ,AIL.ORIGINAL_AMOUNT     ORIGINAL_AMOUNT
  ,AIL.ORIGINAL_BASE_AMOUNT ORIGINAL_BASE_AMOUNT
  ,AIL.ORIGINAL_ROUNDING_AMT ORIGINAL_ROUNDING_AMOUNT
  ,AIL.CANCELLED_FLAG      CANCELLED_FLAG
  ,AIL.INCOME_TAX_REGION   INCOME_TAX_REGION
  ,AIL.TYPE_1099           INCOME_TAX_TYPE
  ,AIL.STAT_AMOUNT         STAT_AMOUNT
  ,Ail.Prepay_Invoice_Id   Prepay_Invoice_Id
  ,AIL.PREPAY_LINE_NUMBER  PREPAY_LINE_NUMBER
  ,AIL.INVOICE_INCLUDES_PREPAY_FLAG INVOICE_INCLUDES_PREPAY_FLAG
  ,Ail.Corrected_Inv_Id    Corrected_Inv_Id
  ,AIL.CORRECTED_LINE_NUMBER CORRECTED_LINE_NUMBER
  ,Ail.Po_Header_Id        Po_Header_Id
  ,Ail.Po_Line_Id          Po_Line_Id
  ,Ail.Po_Release_Id       Po_Release_Id
  ,Ail.Po_Line_Location_Id Po_Line_Location_Id
  ,Ail.Po_Distribution_Id  Po_Distribution_Id
  ,Ail.Rcv_Transaction_Id  Rcv_Transaction_Id
  ,AIL.FINAL_MATCH_FLAG    FINAL_MATCH_FLAG
  ,AIL.ASSETS_TRACKING_FLAG ASSETS_TRACKING_FLAG
  ,Ail.Asset_Book_Type_Code Asset_Book_Type_Code
  ,AIL.ASSET_CATEGORY_ID   ASSET_CATEGORY_ID
  ,Ail.Project_Id          Project_Id
  ,Ail.Task_Id             Task_Id
  ,AIL.EXPENDITURE_TYPE    EXPENDITURE_TYPE
  ,AIL.EXPENDITURE_ITEM_DATE EXPENDITURE_ITEM_DATE
  ,Ail.Expenditure_Organization_Id Expenditure_Organization_Id
  ,AIL.PA_QUANTITY         PA_QUANTITY
  ,Ail.Pa_Cc_Ar_Invoice_Id Pa_Cc_Ar_Invoice_Id
  ,AIL.PA_CC_AR_INVOICE_LINE_NUM INTERCOMPANY_INVOICE_LINE_NUM
  ,AIL.PA_CC_PROCESSED_CODE PROCESSED_CODE
  ,AIL.AWARD_ID            AWARD_ID
  ,Ail.Awt_Group_Id        Awt_Group_Id
  ,AIL.REFERENCE_1         REFERENCE_1
  ,AIL.REFERENCE_2         REFERENCE_2
  ,AIL.RECEIPT_VERIFIED_FLAG RECEIPT_VERIFIED_FLAG
  ,AIL.RECEIPT_REQUIRED_FLAG RECEIPT_REQUIRED_FLAG
  ,AIL.RECEIPT_MISSING_FLAG  RECEIPT_MISSING_FLAG
  ,AIL.JUSTIFICATION       JUSTIFICATION
  ,AIL.EXPENSE_GROUP       EXPENSE_GROUP
  ,AIL.START_EXPENSE_DATE  START_EXPENSE_DATE
  ,AIL.END_EXPENSE_DATE    END_EXPENSE_DATE
  ,AIL.RECEIPT_CURRENCY_CODE RECEIPT_CURRENCY_CODE
  ,AIL.RECEIPT_CONVERSION_RATE RECEIPT_CONVERSION_RATE
  ,AIL.RECEIPT_CURRENCY_AMOUNT RECEIPT_CURRENCY_AMOUNT
  ,AIL.DAILY_AMOUNT        DAILY_AMOUNT
  ,AIL.WEB_PARAMETER_ID    WEB_PARAMETER_ID
  ,AIL.ADJUSTMENT_REASON   ADJUSTMENT_REASON
  ,AIL.MERCHANT_DOCUMENT_NUMBER MERCHANT_DOCUMENT_NUMBER
  ,AIL.MERCHANT_NAME       MERCHANT_NAME
  ,AIL.MERCHANT_REFERENCE  MERCHANT_REFERENCE
  ,AIL.MERCHANT_TAX_REG_NUMBER MERCHANT_TAX_REG_NUMBER
  ,AIL.MERCHANT_TAXPAYER_ID MERCHANT_TAXPAYER_ID
  ,AIL.COUNTRY_OF_SUPPLY   COUNTRY_OF_SUPPLY
  ,AIL.CREDIT_CARD_TRX_ID  CREDIT_CARD_TRX_ID
  ,AIL.COMPANY_PREPAID_INVOICE_ID COMPANY_PREPAID_INVOICE_ID
  ,AIL.CC_REVERSAL_FLAG    CC_REVERSAL_FLAG
  ,AIL.CREATION_DATE       CREATION_DATE
  ,AIL.CREATED_BY          CREATED_BY
  ,AIL.LAST_UPDATED_BY     LAST_UPDATED_BY
  ,AIL.LAST_UPDATE_DATE    LAST_UPDATE_DATE
  ,AIL.LAST_UPDATE_LOGIN   LAST_UPDATE_LOGIN
  ,AIL.PROGRAM_APPLICATION_ID PROGRAM_APPLICATION_ID
  ,AIL.PROGRAM_ID          PROGRAM_ID
  ,AIL.PROGRAM_UPDATE_DATE PROGRAM_UPDATE_DATE
  ,Ail.Request_Id          Request_Id
  ,AIL.ATTRIBUTE_CATEGORY  ATTRIBUTE_CATEGORY
  ,AIL.ATTRIBUTE1          ATTRIBUTE1
  ,AIL.ATTRIBUTE2          ATTRIBUTE2
  ,AIL.ATTRIBUTE3          ATTRIBUTE3
  ,AIL.ATTRIBUTE4          ATTRIBUTE4
  ,AIL.ATTRIBUTE5          ATTRIBUTE5
  ,AIL.ATTRIBUTE6          ATTRIBUTE6
  ,AIL.ATTRIBUTE7          ATTRIBUTE7
  ,AIL.ATTRIBUTE8          ATTRIBUTE8
  ,AIL.ATTRIBUTE9          ATTRIBUTE9
  ,AIL.ATTRIBUTE10         ATTRIBUTE10
  ,AIL.GLOBAL_ATTRIBUTE_CATEGORY GLOBAL_ATTRIBUTE_CATEGORY
  ,AIL.GLOBAL_ATTRIBUTE1   GLOBAL_ATTRIBUTE1
  ,AIL.GLOBAL_ATTRIBUTE2   GLOBAL_ATTRIBUTE2
  ,AIL.GLOBAL_ATTRIBUTE3   GLOBAL_ATTRIBUTE3
  ,AIL.GLOBAL_ATTRIBUTE4   GLOBAL_ATTRIBUTE4
  ,AIL.GLOBAL_ATTRIBUTE5   GLOBAL_ATTRIBUTE5
  ,AIL.GLOBAL_ATTRIBUTE6   GLOBAL_ATTRIBUTE6
  ,AIL.GLOBAL_ATTRIBUTE7   GLOBAL_ATTRIBUTE7
  ,AIL.GLOBAL_ATTRIBUTE8   GLOBAL_ATTRIBUTE8
  ,AIL.GLOBAL_ATTRIBUTE9   GLOBAL_ATTRIBUTE9
  ,Ail.Global_Attribute10  Global_Attribute10
  ,AIL.PRIMARY_INTENDED_USE
  ,Ail.Ship_To_Location_Id
  ,AIL.PRODUCT_FISC_CLASSIFICATION
  ,AIL.USER_DEFINED_FISC_CLASS
  ,AIL.TRX_BUSINESS_CATEGORY
  ,AIL.PRODUCT_TYPE
  ,AIL.PRODUCT_CATEGORY
  ,AIL.ASSESSABLE_VALUE
  ,AIL.CONTROL_AMOUNT
  ,AIL.INCLUDED_TAX_AMOUNT
  ,AIL.TOTAL_REC_TAX_AMOUNT
  ,AIL.TOTAL_NREC_TAX_AMOUNT
  ,AIL.TAX_REGIME_CODE
  ,AIL.TAX
  ,AIL.TAX_STATUS_CODE
  ,AIL.TAX_RATE_CODE
  ,AIL.TAX_RATE_ID
  ,AIL.TAX_RATE
  ,AIL.TAX_JURISDICTION_CODE
  ,AIL.SUMMARY_TAX_LINE_ID
  ,AIL.TAX_ALREADY_CALCULATED_FLAG
  ,AIL.TAX_CLASSIFICATION_CODE
  ,AIL.APPLICATION_ID
  ,AIL.PRODUCT_TABLE
  ,Ail.Cost_Factor_Id
  ,AIL.RETAINED_AMOUNT			RETAINED_AMOUNT
  ,AIL.RETAINED_AMOUNT_REMAINING	RETAINED_AMOUNT_REMAINING
  ,Ail.Retained_Invoice_Id		Retained_Invoice_Id
  ,AIL.RETAINED_LINE_NUMBER		RETAINED_LINE_NUMBER
  ,AIL.LINE_SELECTED_FOR_RELEASE_FLAG	LINE_SELECTED_FOR_RELEASE_FLAG
  ,AIL.RCV_SHIPMENT_LINE_ID		RCV_SHIPMENT_LINE_ID
  ,Ail.Pay_Awt_Group_Id Pay_Awt_Group_Id    
From Apps.Ap_Invoice_Lines_All         Ail
  , Apps.Ap_Lookup_Codes                Alc1
  , apps.Ap_Lookup_Codes                Alc2
Where  ALC1.lookup_type (+)   = 'INVOICE LINE TYPE'
AND    ALC1.lookup_code (+)   = AIL.line_type_lookup_code
AND    ALC2.lookup_type (+)   = 'AP_WFAPPROVAL_STATUS'
And    Alc2.Lookup_Code (+)   = Ail.Wfapproval_Status;