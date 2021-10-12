CREATE OR REPLACE VIEW XXCS_INSTANCE_CONTRACT_ALL AS
SELECT
--------------------------------------------------------------------
--  name:            XXCS_INSTANCE_CONTRACT_ALL
--  create by:       Yoram Zamir
--  Revision:        2.0
--  creation date:   03/09/2009
--------------------------------------------------------------------
--  purpose :       Discoverer Reports
--------------------------------------------------------------------
--  ver  date        name             desc
--  1.0  03/09/2009  Yoram Zamir      initial build
--  2.0  23/03/2010  Yoram Zamir      Revised version after data fix
--------------------------------------------------------------------
                c.LINE_ID                       CONTRACT_LINE_ID,
                c.SERVICE                       CONTRACT_SERVICE,
                c.TYPE                          CONTRACT_TYPE,
                c.COVERAGE                      CONTRACT_COVERAGE,
                c.INSTANCE_ID                   CONTRACT_INSTANCE_ID,
                c.INSTANCE_SERIAL_NUMBER        SERIAL_NUMBER,
                c.INSTANCE_ITEM_ID              CONTRACT_INSTANCE_ITEM_ID,
                c.INSTANCE_ITEM                 CONTRACT_INSTANCE_ITEM,
                c.INSTANCE_ITEM_DESC            CONTRACT_INSTANCE_ITEM_DESC,
                c.ITEM_TYPE                     CONTRACT_INSTANCE_ITEM_TYPE,
                c.INSTALL_DATE                  INSTALL_DATE,
                c.COI_DATE                      COI_DATE,
                c.ITEM_REVISION                 CONTRACT_ITEM_REVISION,
                c.CONTRACT_ID                   CONTRACT_ID,
                c.CONTRACT_NUMBER               CONTRACT_NUMBER,
                c.VERSION_NUMBER                CONTRACT_VERSION_NUMBER,
                c.VERSION_NUMBER_SCREEN         CONTRACT_VERSION_NUMBER_SCREEN,
                c.STATUS                        CONTRACT_STATUS,
                c.STATUS_CATEGORY               STATUS_CATEGORY,
                c.STATUS_CATEGORY_GROUP         STATUS_CATEGORY_GROUP,
                c.START_DATE                    CONTRACT_START_DATE,
                c.END_DATE                      CONTRACT_END_DATE,
                c.LINE_STATUS                   CONTRACT_LINE_STATUS,
                c.LINE_START_DATE               CONTRACT_LINE_START_DATE,
                c.LINE_END_DATE                 CONTRACT_LINE_END_DATE,
                c.LINE_DATE_TERMINATED          CONTRACT_LINE_DATE_TERMINATED,
                c.LINE_ID                       LINE_ID,
                c.SUB_LINE_ID                   SUB_LINE_ID,
                c.LINE_PRICE_NEGOTIATED         LINE_PRICE_NEGOTIATED,
                c.LINE_CONVERSION_RATE_TO_USD   LINE_CONVERSION_RATE_TO_USD,
                c.LINE_SUBTOTAL_CONVERTED_USD   LINE_SUBTOTAL_CONVERTED_USD,
                c.LINE_CONVERTED_CURRENCY_CODE  LINE_CONVERTED_CURRENCY_CODE,
                c.LINE_PRICE_UNIT               LINE_PRICE_UNIT,
                c.LINE_UNIT_LIST_PRICE          LINE_UNIT_LIST_PRICE,
                c.LINE_DISCOUNT_CALC            LINE_DISCOUNT_CALC,
                c.LINE_PRICE_UOM                LINE_PRICE_UOM,
                c.LINE_QUANTITY                 LINE_QUANTITY,
                c.LINE_CURRENCY_CODE            LINE_CURRENCY_CODE,
                c.LINE_PRODUCT_QUANTITY         LINE_PRODUCT_QUANTITY,
                c.LINE_PRODUCT_UOM              LINE_PRODUCT_UOM,
                c.LINE_PRODUCT_LIST_PRICE       LINE_PRODUCT_LIST_PRICE,
                c.LINE_PRODUCT_EXTENDED_AMT     LINE_PRODUCT_EXTENDED_AMT,

                c.MODIFIER                      CONTRACT_NUMBER_MODIFIER,
                c.ORG_ID                        ORG_ID,
                c.OPERATING_UNIT                OPERATING_UNIT,
                c.CS_REGION                     CS_REGION,
                c.CURRENCY                      CURRENCY,
                c.CONVERSION_RATE               CONVERSION_RATE,
                c.CONVERSION_RATE_DATE          CONVERSION_RATE_DATE,
                c.price_list_id                 PRICE_LIST_ID,
                c.po_number                     PO_NUMBER,
                c.DOLLAR_VALUE                  DOLLAR_VALUE,
                c.date_approved                 DATE_APPROVED,
                c.date_issued                   DATE_ISSUED,
                c.date_signed                   DATE_SIGNED,
                c.date_terminated               DATE_TERMINATED,
                c.date_renewed                  DATE_RENEWED,
                c.estimated_amount              ESTIMATED_AMOUNT,
                c.estimated_amount_renewed      ESTIMATED_AMOUNT_RENEWED,
                c.UPG_ORIG_SYSTEM_REF           UPG_ORIG_SYSTEM_REF,
                c.UPG_ORIG_SYSTEM_REF_ID        UPG_ORIG_SYSTEM_REF_ID,
                c.NUMBER_OF_ITEMS               NUMBER_OF_ITEMS,
                c.account_name                  ACCOUNT_NAME,
                c.account_number                ACCOUNT_NUMBER,
                c.END_CUSTOMER                  END_CUSTOMER,
                c.party_id                      PARTY_ID,
                c.party_name                    PARTY_NAME,
                c."ID",c."LANGUAGE",c."SOURCE_LANG",c."SFWT_FLAG",c."NAME",c."COMMENTS",c."ITEM_DESCRIPTION",c."BLOCK23TEXT",c."CREATED_BY",c."CREATION_DATE",c."LAST_UPDATED_BY",c."LAST_UPDATE_DATE",c."LAST_UPDATE_LOGIN",c."SECURITY_GROUP_ID",c."OKE_BOE_DESCRIPTION",c."COGNOMEN"
           FROM XXCS_INST_CONTR_AND_WARR_ALL_V   c
          WHERE c.CONTRACT_OR_WARRANTY='CONTRACT'
          AND   upper(c.STATUS)     IN ('ACTIVE','ENTERED','HOLD','QA_HOLD','SIGNED','EXPIRED','TERMINATED')
          AND   upper(c.LINE_STATUS)IN ('ACTIVE','ENTERED','HOLD','QA_HOLD','SIGNED','EXPIRED','TERMINATED');

