CREATE OR REPLACE PACKAGE XXCS_PNL_REPORT_PKG IS

   -- Author  : Vitaly K.
   -- Created : 23/05/2010
   -- Purpose : For Discoverer report  XX: Profit and Loss report

   TYPE XXCS_PNL_REPORT_REC is RECORD( ORG_ID                        NUMBER,
                                       OPERATING_UNIT                VARCHAR2(300),
                                       CURRENT_OWNER_CS_REGION       VARCHAR2(300),
                                       CUSTOMER_ID                   NUMBER,
                                       CUSTOMER_NAME                 VARCHAR2(300),
                                       INSTANCE_ID                   NUMBER,
                                       SERIAL_NUMBER                 VARCHAR2(300),
                                       PRINTER_INV_ITEM_ID           NUMBER,
                                       PRINTER                       VARCHAR2(300),
                                       PRINTER_DESCRIPTION           VARCHAR2(300),
                                       SOURCE_ID                     NUMBER, ---For "Order By"
                                       SOURCE_NAME                   VARCHAR2(300),
                                       EXPENSE_USD                   NUMBER,
                                       REVENUE_USD                   NUMBER,
                                       PROFIT_USD                    NUMBER,
                                       EXPENSE_USD_STR               VARCHAR2(100),
                                       REVENUE_USD_STR               VARCHAR2(100),
                                       CONTRACT_NUMBER               VARCHAR2(300),
                                       CONTRACT_TYPE                 VARCHAR2(300),
                                       CONTRACT_COVERAGE             VARCHAR2(300),
                                       CONTRACT_FULL_PERIOD_FACTOR   NUMBER
                                       );

   TYPE XXCS_PNL_REPORT_TBL is TABLE of XXCS_PNL_REPORT_REC;



   FUNCTION get_pnl_report RETURN XXCS_PNL_REPORT_TBL PIPELINED;

END XXCS_PNL_REPORT_PKG;
/

