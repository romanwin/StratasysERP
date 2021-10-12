CREATE OR REPLACE VIEW XXCS_CONTRACT_ALL_V AS
SELECT
--------------------------------------------------------------------
--  name:            XXCS_CONTRACT_ALL_V
--  create by:       Vitaly.K
--  Revision:        2.2
--  creation date:   01/09/2009
--------------------------------------------------------------------
--  purpose :        For Disco Reports
--------------------------------------------------------------------
--  ver  date        name           desc
--  1.0  01/09/2009  Vitaly         initial build
--  1.1  14/12/2009  Vitaly         okc_k_headers_all_b.attribute13  "DOLLAR_VALUE"  was added
--  1.2  27/01/2010  Yoram Zamir    add LINE_DATE_TERMINATED
--  1.3  28/01/2010  Yoram Zamir    New table OKC_K_LINES_B was added
--                                  UPG_ORIG_SYSTEM_REF, KL.UPG_ORIG_SYSTEM_REF_ID, CONVERSION_RATE_TO_USD, CONVERTED_LINE_SUBTOTAL_USD, CONVERTED_CURRENCY_CODE_USD, NUMBER_OF_ITEMS  were added
--                                  ITEM_TYPE logic was changed
--  1.4  28/01/2010  Yoram Zamir    OPERATING_UNIT was added
--  2.0  24/03/2010  Yoram Zamir    new revision
--  2.1  14/04/2010  Yoram Zamir    NVL on cs_region; org_id was added
--  2.2  06/09/2010  Roman          add INSTANCE_ORDER_LINE_ID
--------------------------------------------------------------------
       c.ORG_ID                            ORG_ID,
       c.OPERATING_UNIT                    OPERATING_UNIT,
       c.CONTRACT_ID                       CONTRACT_ID,
       c.CONTRACT_SERVICE_ID               CONTRACT_SERVICE_ID,
       nvl(c.CS_REGION, 'No Region')       CS_REGION,
       c.SERVICE                           SERVICE_TYPE,
       c.SERVICE_ITEM                      SERVICE,
       c.COVERAGE                          COVERAGE,
       c.party_id                          PARTY_ID,
       c.party_name                        CUSTOMER_NAME,
       c.END_CUSTOMER                      END_CUSTOMER,
       c.account_name                      ACCOUNT_NAME,
       c.INSTANCE_ID                       INSTANCE_ID,
       c.Instance_Serial_Number            SERIAL_NUMBER,
       c.NUMBER_OF_ITEMS                   NUMBER_OF_ITEMS,
       c.INSTANCE_ITEM||' - ' ||
             c.INSTANCE_ITEM_DESC          ITEM,
       c.INSTANCE_ITEM_ID                  INVENTORY_ITEM_ID,
       c.INSTANCE_ITEM                     INSTANCE_ITEM,
       c.INSTANCE_ITEM_DESC                INSTANCE_ITEM_DESC,
       c.inSTANCE_ORDER_LINE_ID            INSTANCE_ORDER_LINE_ID,
       c.ITEM_TYPE                         ITEM_TYPE,
       c.ITEM_REVISION                     ITEM_REVISION,
       c.INSTALL_DATE                      INSTALL_DATE,
       c.COI_DATE                          COI_DATE,
       c.CONTRACT_NUMBER                   CONTRACT_NUMBER,
       c.VERSION_NUMBER_SCREEN             VERSION_NUMBER,
       c.VERSION_NUMBER_SCREEN             CONTRACT_VERSION_NUMBER_SCREEN,
       c.STATUS                            STATUS,
       c.STATUS_CATEGORY_GROUP             STATUS_CATEGORY,
       c.START_DATE                        START_DATE,
       c.END_DATE                          END_DATE,
       c.LINE_STATUS                       LINE_STATUS,
       c.LINE_START_DATE                   LINE_START_DATE,
       c.LINE_END_DATE                     LINE_END_DATE,
       c.LINE_DATE_TERMINATED              LINE_DATE_TERMINATED,
       c.MODIFIER                          MODIFIER,
       C.CURRENCY                          CURRENCY,
       C.CONVERSION_RATE                   CONVERSION_RATE,
       C.CONVERSION_RATE_DATE              CONVERSION_RATE_DATE,
       C.PRICE_LIST_ID                     PRICE_LIST_ID,
       C.PO_NUMBER                         PO_NUMBER,
       C.DOLLAR_VALUE                      DOLLAR_VALUE,
       C.DATE_APPROVED                     DATE_APPROVED,
       C.DATE_ISSUED                       DATE_ISSUED,
       C.DATE_SIGNED                       DATE_SIGNED,
       C.DATE_TERMINATED                   DATE_TERMINATED,
       C.DATE_RENEWED                      DATE_RENEWED,
       C.ESTIMATED_AMOUNT                  ESTIMATED_AMOUNT,
       C.ESTIMATED_AMOUNT                  CONTRACT_TOTAL_AMOUNT,
       C.ESTIMATED_AMOUNT_RENEWED          ESTIMATED_AMOUNT_RENEWED,
       C.ESTIMATED_AMOUNT_RENEWED          CONTRACT_AMOUNT_RENEWED,
       --Service line
       C.LINE_PRICE_NEGOTIATED,
       C.LINE_PRICE_NEGOTIATED             LINE_SUBTOTAL,
       C.LINE_conversion_rate_to_usd       conversion_rate_to_usd,
       C.LINE_SUBTOTAL_CONVERTED_USD       converted_line_subtotal_usd,
       C.LINE_CONVERTED_CURRENCY_CODE      converted_currency_code_usd,
       C.LINE_PRICE_UNIT                   LINE_PRICE_UNIT,
       C.LINE_UNIT_LIST_PRICE              LINE_UNIT_LIST_PRICE,
       C.LINE_DISCOUNT_CALC                LINE_DISCOUNT_CALC,
       c.LINE_PRICE_UOM                    LINE_PRICE_UOM,
       c.LINE_QUANTITY                     LINE_QUANTITY,
       c.LINE_CURRENCY_CODE                LINE_CURRENCY_CODE,
       -- product line
       c.LINE_PRODUCT_QUANTITY             PRODUCT_QUANTITY,
       c.line_PRODUCT_UOM                  PRODUCT_UOM,
       c.line_PRODUCT_LIST_PRICE           PRODUCT_LIST_PRICE,
       c.LINE_PRODUCT_EXTENDED_AMT         PRODUCT_EXTENDED_AMT,
       c.LINE_ID                           CONTRACT_CLE_ID,
       c.SUB_LINE_ID                       CONTRACT_LINE_ID,
       c.upg_orig_system_ref               UPG_ORIG_SYSTEM_REF,
       c.upg_orig_system_ref_id            UPG_ORIG_SYSTEM_REF_ID,
       c.PRICE_LIST_NAME                   PRICE_LIST_NAME,
       c.UNIT_PRICE_ORG_CURRENCY           UNIT_PRICE_ORG_CURRENCY,
       c.PRICE_LIST_CURRENCY               PRICE_LIST_CURRENCY,
       c.INVOICED                          INVOICED
FROM   XXCS_INST_CONTR_AND_WARR_ALL_V   c;

