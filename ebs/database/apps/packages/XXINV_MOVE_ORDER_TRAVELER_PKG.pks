CREATE OR REPLACE PACKAGE APPS.XXINV_MOVE_ORDER_TRAVELER_PKG AUTHID CURRENT_USER AS
---------------------------------------------------------------------------------------
--  name:            XXINV_MOVE_ORDER_TRAVELER_PKG
--  create by:       S3 Project
--  Revision:        1.0
--  creation date:   05-APR-2017
--  Object Type :    Package Specification      
---------------------------------------------------------------------------------------
--  purpose :        
---------------------------------------------------------------------------------------
--  ver  date          name                 desc
--  1.0                S3 Project           initial build - Created During S3 Project
--  1.1  05-APR-2017   Lingaraj Sarangi     Finilizing Deployment on 12.1.3
---------------------------------------------------------------------------------------
 /* $Header: INVTOPKLS.pls 120.2 2008/01/08 06:27:05 dwkrishn noship $ */
  P_REPT_TYPE_PARAM             VARCHAR2(10); --Added by TCS on 24/05/2016
  P_PRINT_REPORT_HEADER_FOOTER  VARCHAR2(10); --Added by TCS on 24/05/2016
  P_ORG_ID                      NUMBER;
  P_DATE_REQD_HI                DATE;
  P_DATE_REQD_LO                DATE;
  CP_DATE_REQD_LO               varchar2(20);
  CP_DATE_REQD_HI               varchar2(20);
  P_ITEM_FLEXSQL                VARCHAR2(1000) := '(msi.segment1  || ''\n'' || msi.segment2  || ''\n'' || msi.segment3  || ''\n'' ||
  msi.segment4  || ''\n'' || msi.segment5  || ''\n'' || msi.segment6  || ''\n'' || msi.segment7  || ''\n'' ||
  msi.segment8  || ''\n'' || msi.segment9  || ''\n'' || msi.segment10 || ''\n'' || msi.segment11 || ''\n'' ||
  msi.segment12 || ''\n'' || msi.segment13 || ''\n'' )';
  P_ITEM_FLEXNUM                NUMBER;
  P_DEST_SUBINV                 VARCHAR2(10);
  P_TRACE_FLAG                  NUMBER;
  P_CBO_FLAG                    NUMBER;
  P_TO_ACCOUNT_FLEXSQL          VARCHAR2(1000) := 'gcc.segment1|| ''\n'' || gcc.segment2|| ''\n'' || gcc.segment3|| ''\n'' ||
  gcc.segment4|| ''\n'' || gcc.segment5|| ''\n'' || gcc.segment6|| ''\n'' || gcc.segment7|| ''\n'' || gcc.segment8|| ''\n'' ||
  gcc.segment9|| ''\n'' || gcc.segment10|| ''\n'' || gcc.segment11|| ''\n'' || gcc.segment12|| ''\n'' ||
  gcc.segment13|| ''\n'' || gcc.segment14|| ''\n'' || gcc.segment15|| ''\n'' || gcc.segment16|| ''\n'' ||
  gcc.segment17|| ''\n'' || gcc.segment18|| ''\n'' || gcc.segment19|| ''\n'' || gcc.segment20|| ''\n'' ||
  gcc.segment21|| ''\n'' || gcc.segment22|| ''\n'' || gcc.segment23|| ''\n'' || gcc.segment24|| ''\n'' ||
  gcc.segment25|| ''\n'' || gcc.segment26|| ''\n'' || gcc.segment27|| ''\n'' || gcc.segment28|| ''\n'' ||
  gcc.segment29|| ''\n'' || gcc.segment30';
  P_SOURCE_SUBINV               VARCHAR2(10);
  P_DEST_LOCATOR_ID             NUMBER;
  P_DELIVER_TO_LOCATOR_SEG_01     VARCHAR2(20); -- Deliver To Stock Locator Segment 1 (Subinventory - XXINV_SUBINVENTORY_TABLE_VS)
  P_DELIVER_TO_LOCATOR_SEG_02     VARCHAR2(20); -- Deliver To Stock Locator Segment 2 (Row - XXINV_STOCK_LOCATOR_ROW_VS)
  P_DELIVER_TO_LOCATOR_SEG_03     VARCHAR2(20); -- Deliver To Stock Locator Segment 3 (Rack - XXINV_STOCK_LOCATOR_RACK_VS)
  P_DELIVER_TO_LOCATOR_SEG_04     VARCHAR2(20); -- Deliver To Stock Locator Segment 4 (Bin - XXINV_STOCK_LOCATOR_BIN_VS)
  P_SOURCE_LOCATOR_ID           NUMBER;
  P_REQUESTED_BY                NUMBER;
  P_SET_OF_BOOKS_ID             NUMBER;
  P_WHERE_MMT                   VARCHAR2(2000) := '1=1';
  P_REQUESTED_BY_NAME           VARCHAR2(50);
  P_PRINT_OPTION                VARCHAR2(32767);
  P_WHERE_MMTT                  VARCHAR2(2000) := '1=1';
  P_WHERE_MTRL                  VARCHAR2(2000) := '1=1';
  P_MOVE_ORDER_TYPE             NUMBER;
  P_ALLOCATE_MOVE_ORDER         VARCHAR2(32767);
  P_WMS_INSTALL                 VARCHAR2(1) := 'N';
  P_PLAN_TASKS                  VARCHAR2(22);
  P_PICK_SLIP_GROUP_RULE_ID     NUMBER;
  P_PICK_SLIP_GROUP_RULE_NAME   VARCHAR2(30);
  P_ORG_NAME                    VARCHAR2(240);
  P_SOURCE_LOCATOR              VARCHAR2(2000);
  P_DEST_LOCATOR                VARCHAR2(2000);
  P_MOVE_ORDER_TYPE_MEANING     VARCHAR2(80);
  P_PRINT_OPTION_MEANING        VARCHAR2(80);
  P_CONST_UNALLOCATED           VARCHAR2(30);
  P_MOVE_ORDER_LOW              VARCHAR2(30);
  P_MOVE_ORDER_HIGH             VARCHAR2(30);
  P_CONC_REQUEST_ID             NUMBER;
  P_SORT_BY                     NUMBER;
  P_FROM_MMT                    VARCHAR2(1000);
  P_FROM_MMTT                   VARCHAR2(1000);
  P_FROM_MTRL                   VARCHAR2(1000);
  P_SALES_ORDER_LOW             VARCHAR2(22);
  P_SALES_ORDER_HIGH            VARCHAR2(22);
  P_CUSTOMER_ID                 NUMBER;
  P_FREIGHT_CODE                VARCHAR2(30);
  P_PICK_SLIP_NUMBER_LOW        NUMBER;
  P_PICK_SLIP_NUMBER_HIGH       NUMBER;
  P_CUSTOMER_NAME               VARCHAR2(50);
  P_ALLOCATE_MOVE_ORDER_MEANING VARCHAR2(32767);
  P_PLAN_TASKS_MEANING          VARCHAR2(32767);
  P_SER_PARENT_S_FROM           VARCHAR2(600) := 'SELECT LAG(MSN.SERIAL_NUMBER, 1) OVER(ORDER BY LENGTH(MSN.SERIAL_NUMBER), MSN.SERIAL_NUMBER) PREV_SERIAL, MSN.SERIAL_NUMBER SERIAL_NUMBER,
  LEAD(MSN.SERIAL_NUMBER, 1) OVER(ORDER BY LENGTH(MSN.SERIAL_NUMBER), MSN.SERIAL_NUMBER) NEXT_SERIAL
  FROM MTL_SERIAL_NUMBERS_TEMP MSNT, MTL_SERIAL_NUMBERS MSN
  WHERE MSNT.TRANSACTION_TEMP_ID = :PARENT_TXN_TEMP_ID AND MSN.SERIAL_NUMBER BETWEEN MSNT.FM_SERIAL_NUMBER
  AND MSNT.TO_SERIAL_NUMBER AND MSN.INVENTORY_ITEM_ID = :PARENT_ITEM_ID AND LENGTH(MSN.SERIAL_NUMBER) = LENGTH(MSNT.FM_SERIAL_NUMBER)';
  P_SER_CHILD_S_FROM            VARCHAR2(1000) := 'SELECT LAG(SERIAL_NUMBER, 1) OVER(ORDER BY LENGTH(SERIAL_NUMBER), SERIAL_NUMBER) PREV_SERIAL, SERIAL_NUMBER, LEAD(SERIAL_NUMBER, 1) OVER(ORDER BY LENGTH(SERIAL_NUMBER), SERIAL_NUMBER) NEXT_SERIAL
  FROM MTL_UNIT_TRANSACTIONS WHERE TRANSACTION_ID = :TRANSACTION_ID
  UNION ALL SELECT LAG(MSN.SERIAL_NUMBER, 1) OVER(ORDER BY LENGTH(MSN.SERIAL_NUMBER), MSN.SERIAL_NUMBER)
  PREV_SERIAL, MSN.SERIAL_NUMBER SERIAL_NUMBER, LEAD(SERIAL_NUMBER, 1) OVER(ORDER BY LENGTH(SERIAL_NUMBER), SERIAL_NUMBER) NEXT_SERIAL FROM MTL_SERIAL_NUMBERS_TEMP MSNT, MTL_SERIAL_NUMBERS MSN
  WHERE MSNT.TRANSACTION_TEMP_ID = :TRANSACTION_ID AND MSN.SERIAL_NUMBER BETWEEN MSNT.FM_SERIAL_NUMBER
  AND MSNT.TO_SERIAL_NUMBER AND MSN.INVENTORY_ITEM_ID = :INVENTORY_ITEM_ID AND LENGTH(MSN.SERIAL_NUMBER) = LENGTH(MSNT.FM_SERIAL_NUMBER)';
  P_SER_PARENT_LS_FROM          VARCHAR2(600) := 'SELECT LAG(MSN.SERIAL_NUMBER, 1) OVER(ORDER BY LENGTH(MSN.SERIAL_NUMBER), MSN.SERIAL_NUMBER) PREV_SERIAL, MSN.SERIAL_NUMBER SERIAL_NUMBER,
  LEAD(MSN.SERIAL_NUMBER, 1) OVER(ORDER BY LENGTH(MSN.SERIAL_NUMBER), MSN.SERIAL_NUMBER) NEXT_SERIAL FROM MTL_SERIAL_NUMBERS_TEMP MSNT, MTL_SERIAL_NUMBERS MSN WHERE MSNT.TRANSACTION_TEMP_ID = :L_PARENT_SER_TXN_TEMP_ID
  AND MSN.SERIAL_NUMBER BETWEEN MSNT.FM_SERIAL_NUMBER AND MSNT.TO_SERIAL_NUMBER
  AND MSN.INVENTORY_ITEM_ID = :PARENT_ITEM_ID AND LENGTH(MSN.SERIAL_NUMBER) = LENGTH(MSNT.FM_SERIAL_NUMBER)';
  P_SER_CHILD_LS_FROM           VARCHAR2(1000) := 'SELECT LAG(SERIAL_NUMBER, 1) OVER(ORDER BY LENGTH(SERIAL_NUMBER), SERIAL_NUMBER) PREV_SERIAL, SERIAL_NUMBER, LEAD(SERIAL_NUMBER, 1) OVER(ORDER BY LENGTH(SERIAL_NUMBER), SERIAL_NUMBER) NEXT_SERIAL
  FROM MTL_UNIT_TRANSACTIONS WHERE TRANSACTION_ID = :LS_SER_TXN_ID UNION ALL SELECT LAG(MSN.SERIAL_NUMBER, 1) OVER(ORDER BY LENGTH(MSN.SERIAL_NUMBER), MSN.SERIAL_NUMBER) PREV_SERIAL,
  MSN.SERIAL_NUMBER SERIAL_NUMBER, LEAD(SERIAL_NUMBER, 1) OVER(ORDER BY LENGTH(SERIAL_NUMBER), SERIAL_NUMBER) NEXT_SERIAL FROM MTL_SERIAL_NUMBERS_TEMP MSNT, MTL_SERIAL_NUMBERS MSN
  WHERE MSNT.TRANSACTION_TEMP_ID = :LS_SER_TXN_ID AND MSN.SERIAL_NUMBER BETWEEN MSNT.FM_SERIAL_NUMBER AND MSNT.TO_SERIAL_NUMBER AND MSN.INVENTORY_ITEM_ID = :INVENTORY_ITEM_ID AND LENGTH(MSN.SERIAL_NUMBER) = LENGTH(MSNT.FM_SERIAL_NUMBER)';
  CP_SO_ORDER_NUMBER            NUMBER;
  CP_SO_LINE_NUMBER             NUMBER;
  CP_SO_DELIVERY_NAME           NUMBER;
  CP_WIP_JOB                    VARCHAR2(500);
  CP_WIP_DEPARTMENT             VARCHAR2(20);
  CP_WIP_LINE                   VARCHAR2(20);
  CP_WIP_ENTITY_TYPE            NUMBER;
  CP_WIP_START_DATE             VARCHAR2(20);
  CP_WIP_OPERATION              VARCHAR2(20);
  CP_CHART_OF_ACCOUNTS_NUM      NUMBER;
  P_INCLUDE_REPRINTS           VARCHAR2(3);-- Indicates if Move Orders Travelers that have already been printed should be printed again.
  P_SORT_FIELD_01              VARCHAR2(30);--supports dynamic sorting
  P_SORT_FIELD_01_DIRECTION    VARCHAR2(4);--supports dynamic sorting
  P_SORT_FIELD_02              VARCHAR2(30);--supports dynamic sorting
  P_SORT_FIELD_02_DIRECTION    VARCHAR2(4);--supports dynamic sorting
  P_SORT_FIELD_03              VARCHAR2(30);--supports dynamic sorting
  P_SORT_FIELD_03_DIRECTION    VARCHAR2(4);--supports dynamic sorting
  P_SORT_FIELD_04              VARCHAR2(30);--supports dynamic sorting
  P_SORT_FIELD_04_DIRECTION    VARCHAR2(4);--supports dynamic sorting
  P_SORT_FIELD_05              VARCHAR2(30);--supports dynamic sorting
  P_SORT_FIELD_05_DIRECTION    VARCHAR2(4);--supports dynamic sorting
  P_SORT_FIELD_06              VARCHAR2(30);--supports dynamic sorting
  P_SORT_FIELD_06_DIRECTION    VARCHAR2(4);--supports dynamic sorting
  CF_TO_ACCOUNT VARCHAR2(1000);  --Added this because we were getting this in the log file: "[033117_085628849][][ERROR] Variable ' cf_to_account' is missing...." and "PLS-00302: component 'CF_TO_ACCOUNT' must be declared"
  CF_PARENT_ITEM VARCHAR2(1000);  --Added this because we were getting this in the log file: "[033117_085628849][][ERROR] Variable ' cf_to_account' is missing...." and "PLS-00302: component 'CF_TO_ACCOUNT' must be declared"
  P_LEXICAL_ORDER_BY_CLAUSE_MAIN VARCHAR2(1000);--lexical that supports dynamic sorting
  FUNCTION BEFOREREPORT RETURN BOOLEAN;
  FUNCTION AFTERREPORT RETURN BOOLEAN;
  FUNCTION AFTERPFORM RETURN BOOLEAN;
  PROCEDURE GET_CHART_OF_ACCOUNTS_ID;
  FUNCTION P_REQUESTED_BYVALIDTRIGGER RETURN BOOLEAN;
  FUNCTION P_ORG_IDVALIDTRIGGER RETURN BOOLEAN;
  FUNCTION CF_PROJECT_NUMBERFORMULA(PROJECT_ID IN NUMBER) RETURN CHAR;
  FUNCTION CF_TASK_NUMBERFORMULA(TASK_ID IN NUMBER, PROJECT_ID IN NUMBER)
    RETURN CHAR;
  FUNCTION P_MOVE_ORDER_TYPEVALIDTRIGGER RETURN BOOLEAN;
  FUNCTION P_PICK_SLIP_GROUP_RULE_IDVALID RETURN BOOLEAN;
  FUNCTION P_PRINT_OPTIONVALIDTRIGGER RETURN BOOLEAN;
  FUNCTION CF_WIP_INFOFORMULA(LINE_ID_P                  IN NUMBER,
                              MOVE_ORDER_TYPE            IN NUMBER,
                              TRANSACTION_SOURCE_TYPE_ID IN NUMBER)
    RETURN NUMBER;
  FUNCTION CF_SO_INFOFORMULA(LINE_ID IN NUMBER, MOVE_ORDER_TYPE IN NUMBER)
    RETURN NUMBER;
  PROCEDURE INV_CALL_ALLOCATIONS_ENGINE;
  FUNCTION P_CUSTOMER_IDVALIDTRIGGER RETURN BOOLEAN;
  FUNCTION CF_TASK_STATUSFORMULA(TASK_STATUS IN NUMBER) RETURN CHAR;
  FUNCTION CF_TASK_IDFORMULA(TASK_STATUS    IN NUMBER,
                             PARENT_LINE_ID IN NUMBER,
                             TRANSACTION_ID IN NUMBER) RETURN NUMBER;
  FUNCTION P_ALLOCATE_MOVE_ORDERVALIDTRIG RETURN BOOLEAN;
  FUNCTION P_PLAN_TASKSVALIDTRIGGER RETURN BOOLEAN;
  FUNCTION P_FREIGHT_CODEVALIDTRIGGER RETURN BOOLEAN;
  FUNCTION CF_SEC_QTYFORMULA(INVENTORY_ITEM_ID_1 IN NUMBER,
                             SEC_TRANSACTION_QTY IN NUMBER) RETURN NUMBER;
  FUNCTION CF_SEC_UOMFORMULA(INVENTORY_ITEM_ID_1 IN NUMBER,
                             SEC_UOM             IN VARCHAR2) RETURN CHAR;
  FUNCTION CF_PARENT_SEC_UOMFORMULA(PARENT_ITEM_ID     IN NUMBER,
                                    PARENT_SEC_TXN_UOM IN VARCHAR2)
    RETURN CHAR;
  FUNCTION CF_PARENT_SEC_QTYFORMULA(PARENT_ITEM_ID     IN NUMBER,
                                    PARENT_SEC_TXN_QTY IN NUMBER)
    RETURN NUMBER;
  FUNCTION CP_SO_ORDER_NUMBER_P RETURN NUMBER;
  FUNCTION CP_SO_LINE_NUMBER_P RETURN NUMBER;
  FUNCTION CP_SO_DELIVERY_NAME_P RETURN NUMBER;
  FUNCTION CP_WIP_JOB_P RETURN VARCHAR2;
  FUNCTION CP_WIP_DEPARTMENT_P RETURN VARCHAR2;
  FUNCTION CP_WIP_LINE_P RETURN VARCHAR2;
  FUNCTION CP_WIP_ENTITY_TYPE_P RETURN NUMBER;
  FUNCTION CP_WIP_START_DATE_P RETURN VARCHAR2;
  FUNCTION CP_WIP_OPERATION_P RETURN VARCHAR2;
  FUNCTION CP_CHART_OF_ACCOUNTS_NUM_P RETURN NUMBER;
  FUNCTION f_order_by_clause RETURN VARCHAR2;
  
  /* $Header: INVPKSLS.pls 120.0 2005/05/25 04:37:51 appldev noship $ */

  /*
  ** -------------------------------------------------------------------------
  ** Function:    chk_wms_install
  ** Description: Checks to see if WMS is installed
  **               This API should be used only for Move Order Pick Slip Report's
  **               Move order type value set.
  ** Input:       None
  ** Output:      none
  ** Returns:
  **      'TRUE' if WMS installed, else 'FALSE'
  **
  ** --------------------------------------------------------------------------
  */
  FUNCTION chk_wms_install(p_organization_id NUMBER)
    RETURN VARCHAR2;

  PROCEDURE run_detail_engine(
    x_return_status           OUT NOCOPY    VARCHAR2
  , p_org_id                                NUMBER
  , p_move_order_type                       NUMBER
  , p_move_order_from                       VARCHAR2
  , p_move_order_to                         VARCHAR2
  , p_source_subinv                         VARCHAR2
  , p_source_locator_id                     NUMBER
  , p_dest_subinv                           VARCHAR2
  , p_dest_locator_id                       NUMBER
  , p_sales_order_from                      VARCHAR2
  , p_sales_order_to                        VARCHAR2
  , p_freight_code                          VARCHAR2
  , p_customer_id                           NUMBER
  , p_requested_by                          NUMBER
  , p_date_reqd_from                        DATE
  , p_date_reqd_to                          DATE
  , p_plan_tasks                            BOOLEAN
  , p_pick_slip_group_rule_id               NUMBER
  , p_request_id                            NUMBER DEFAULT 1); /* Added p_request_id to fix Bug# 3869858 */

  FUNCTION print_move_order_traveler(
    p_organization_id         VARCHAR2
  , p_move_order_from         VARCHAR2 DEFAULT ''
  , p_move_order_to           VARCHAR2 DEFAULT ''
  , p_pick_slip_number_from   VARCHAR2 DEFAULT ''
  , p_pick_slip_number_to     VARCHAR2 DEFAULT ''
  , p_source_subinv           VARCHAR2 DEFAULT ''
  , p_source_locator          VARCHAR2 DEFAULT ''
  , p_dest_subinv             VARCHAR2 DEFAULT ''
  , p_dest_locator            VARCHAR2 DEFAULT ''
  , p_requested_by            VARCHAR2 DEFAULT ''
  , p_date_reqd_from          VARCHAR2 DEFAULT ''
  , p_date_reqd_to            VARCHAR2 DEFAULT ''
  , p_print_option            VARCHAR2 DEFAULT '99'
  , p_print_mo_type           VARCHAR2 DEFAULT '99'
  , p_sales_order_from        VARCHAR2 DEFAULT ''
  , p_sales_order_to          VARCHAR2 DEFAULT ''
  , p_ship_method_code        VARCHAR2 DEFAULT ''
  , p_customer_id             VARCHAR2 DEFAULT ''
  , p_auto_allocate           VARCHAR2 DEFAULT 'N'
  , p_plan_tasks              VARCHAR2 DEFAULT 'N'
  , p_pick_slip_group_rule_id VARCHAR2 DEFAULT ''
  ) RETURN NUMBER;
  
END XXINV_MOVE_ORDER_TRAVELER_PKG;
/