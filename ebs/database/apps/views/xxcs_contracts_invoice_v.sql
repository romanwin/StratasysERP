CREATE OR REPLACE VIEW xxcs_contracts_invoice_v AS
SELECT
--------------------------------------------------------------------
--  name:            XXCS_CONTRACTS_INVOICE_V
--  create by:       Vitaly.K
--  Revision:        1.4
--  creation date:   01/09/2009
--------------------------------------------------------------------
--  purpose :    Disco Report:  XX: Service Contracts Report
--------------------------------------------------------------------
--  ver  date        name        desc
--  1.0  01/09/2009  Vitaly      initial build
--  1.1  13/12/2009  Vitaly      "Order By" was removed, "DOLLAR_VALUE" field was added
--  1.2  07/04/2010  Vitaly      Sub-select was removed,
--  1.3  09/06/2010  Vitaly      Org_id, Operating_unit; Security by OU were added
--  1.4  24/11/2011  Roman       Added partner_program
--------------------------------------------------------------------
              SC.CONTRACT_ID,
              SC.CONTRACT_SERVICE_ID,
              SC.CS_REGION,
              SC.SERVICE_TYPE,
              SC.SERVICE,
              SC.COVERAGE,
              SC.CUSTOMER_NAME,
              SC.END_CUSTOMER,
              SC.ACCOUNT_NAME,
              SC.INSTANCE_ID,
              SC.SERIAL_NUMBER,
              SC.ITEM,
              SC.INVENTORY_ITEM_ID,
              SC.INSTANCE_ITEM,
              SC.INSTANCE_ITEM_DESC,
              SC.ITEM_TYPE,
              SC.ITEM_REVISION,
              SC.INSTALL_DATE,
              SC.COI_DATE,
              SC.CONTRACT_NUMBER,
              SC.VERSION_NUMBER,
              SC.STATUS,
              SC.STATUS_CATEGORY,
              SC.START_DATE,
              SC.END_DATE,
              SC.LINE_STATUS,
              SC.LINE_START_DATE,
              SC.LINE_END_DATE,
              SC.MODIFIER,
              SC.CURRENCY,
              SC.CONVERSION_RATE,
              SC.CONVERSION_RATE_DATE,
              SC.PRICE_LIST_ID,
              SC.PO_NUMBER,
              SC.DOLLAR_VALUE,
              SC.DATE_APPROVED,
              SC.DATE_ISSUED,
              SC.DATE_SIGNED,
              SC.DATE_TERMINATED,
              SC.DATE_RENEWED,
              SC.ESTIMATED_AMOUNT,
              SC.CONTRACT_TOTAL_AMOUNT,
              SC.ESTIMATED_AMOUNT_RENEWED,
              SC.CONTRACT_AMOUNT_RENEWED,
              SC.LINE_PRICE_NEGOTIATED,
              SC.LINE_SUBTOTAL,
              SC.LINE_PRICE_UNIT,
              SC.LINE_UNIT_LIST_PRICE,
              SC.LINE_DISCOUNT_CALC,
              SC.LINE_PRICE_UOM,
              SC.LINE_QUANTITY,
              SC.LINE_CURRENCY_CODE,
              SC.PRODUCT_QUANTITY,
              SC.PRODUCT_UOM,
              SC.PRODUCT_LIST_PRICE,
              SC.PRODUCT_EXTENDED_AMT,
              SC.CONTRACT_CLE_ID,
              SC.CONTRACT_LINE_ID,
              SC.PRICE_LIST_NAME,
              SC.UNIT_PRICE_ORG_CURRENCY,
              SC.PRICE_LIST_CURRENCY,
              SC.INVOICED,
              SC.ORG_ID,
              SC.OPERATING_UNIT,
              partner_program.partner_program
FROM   XXCS_CONTRACT_ALL_V    SC,
 (SELECT GG.PARTY_ID, GG.PARTNER_PROGRAM, GG.RANK
  FROM (SELECT OKPR.OBJECT1_ID1 PARTY_ID,
               MSIB.SEGMENT1 PARTNER_PROGRAM,
               DENSE_RANK() OVER(PARTITION BY OKPR.OBJECT1_ID1 ORDER BY L.END_DATE DESC) RANK
          FROM OKC_K_HEADERS_ALL_B H,
               OKC_K_LINES_B       L,
               OKC_K_ITEMS         OKI2,
               MTL_SYSTEM_ITEMS_B  MSIB,
               OKC_K_PARTY_ROLES_B OKPR
         WHERE OKI2.CLE_ID = L.ID
           AND L.CHR_ID = H.ID
           AND MSIB.INVENTORY_ITEM_ID = OKI2.OBJECT1_ID1
           AND MSIB.ORGANIZATION_ID = 91
           AND MSIB.SEGMENT1 IN ('SERVICE CARE', 'TOTAL CARE')
           AND H.ID = OKPR.CHR_ID
           AND OKPR.JTOT_OBJECT1_CODE = 'OKX_PARTY'
           AND L.STS_CODE = 'ACTIVE'
           AND SYSDATE BETWEEN L.START_DATE AND
               NVL(L.DATE_TERMINATED, L.END_DATE)) GG
 WHERE GG.RANK = 1) partner_program
WHERE  sc.party_id = partner_program.party_id (+)
and XXCS_UTILS_PKG.CHECK_SECURITY_BY_OPER_UNIT(sc.org_id,sc.party_id)='Y';
