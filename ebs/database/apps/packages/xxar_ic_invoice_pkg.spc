create or replace package xxar_ic_invoice_pkg AUTHID CURRENT_USER is
  ----------  --------    --------------  -------------------------------------
  -- $Header: xxar_ic_invoices 120.0.0  4JUL2017  $
  ----------  --------    --------------  -------------------------------------
  -- Package: xxar_ic_invoices 
  -- Created: Ofer Suad <Ofer.Suad@stratasys.com>
  -- Author : Ofer Suad <Ofer.Suad@stratasys.com>
  ----------  --------    --------------  -------------------------------------
  -- Perpose: 
  ----------  --------    --------------  -------------------------------------
  -- Version  Date        Performer       Comments
  --------------------------------------------------------------------
  --     1.0  04/07/2017  Ofer Suad       CHG0040750  - Initial Build  
  --------------------------------------------------------------------

  --------------------------------------
  -- declaration of record type
  --------------------------------------
  TYPE IC_INV_ERR_DTL_REC IS RECORD(
    INVOICE_ROWID             VARCHAR2(1000),
    ITEM_CODE                 VARCHAR2(240),
    ITEM_DESC                 VARCHAR2(240),
    INTERFACE_LINE_CONTEXT    VARCHAR2(240),
    INTERFACE_LINE_ID         VARCHAR2(240),
    INTERFACE_LINE_ATTRIBUTE1 VARCHAR2(240),
    INTERFACE_LINE_ATTRIBUTE4 VARCHAR2(240),
    customer_trx_id           VARCHAR2(240),
    trx_number                VARCHAR2(240),
    BATCH_SOURCE_NAME         VARCHAR2(240),
    LINE_TYPE                 VARCHAR2(20),
    CURRENCY_CODE             VARCHAR2(5),
    CONVERSION_TYPE           VARCHAR2(20),
    AMOUNT                    VARCHAR2(240),
    SELL_ORGANIZATION_ID      VARCHAR2(240),
    WAREHOUSE_ID              VARCHAR2(240),
    ORG_ID                    VARCHAR2(240),
    --CREATION_DATE             DATE,        
    PAYING_CUSTOMER_ID VARCHAR2(240),
    PAYING_SITE_USE_ID VARCHAR2(240),
    SALES_ORDER        VARCHAR2(240),
    SALES_ORDER_SOURCE VARCHAR2(240),
    -- SALES_ORDER_DATE          DATE,
    SALES_ORDER_LINE      VARCHAR2(240),
    ERROR_MSG             VARCHAR2(4000),
    RECORD_STATUS         VARCHAR2(10),
    FIRST_AR_INV_CREATED  VARCHAR2(3),
    SECOND_AR_INV_CREATED VARCHAR2(3),
    AP_INV_CREATED        VARCHAR2(3)
    
    );

  TYPE IC_INV_ERR_DTL_TBL IS TABLE OF IC_INV_ERR_DTL_REC INDEX BY BINARY_INTEGER;

  -- *************************************************************************************
  -- PROCEDURE : repalce_ar_invoice
  --
  -- Purpose: 
  --
  -- Revision History
  -- Version   Date            Performer          Comments
  --************************************************************************************** 
  --   1.0     04/07/2017      Ofer Suad          CHG0040750  - Initial Build
  --  
  -- *************************************************************************************
  Procedure repalce_ar_invoice(errbuf OUT VARCHAR2, retcode OUT VARCHAR2);

  -- *************************************************************************************
  -- PROCEDURE : repalce_ap_inv
  --
  -- Purpose: 
  --
  -- Revision History
  -- Version   Date            Performer          Comments
  --************************************************************************************** 
  --   1.0     04/07/2017      Ofer Suad          CHG0040750  - Initial Build
  --  
  -- *************************************************************************************                                  
  Procedure repalce_ap_invoice(errbuf OUT VARCHAR2, retcode OUT VARCHAR2);

end xxar_ic_invoice_pkg;
/
