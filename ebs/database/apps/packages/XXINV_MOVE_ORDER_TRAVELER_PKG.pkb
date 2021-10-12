CREATE OR REPLACE PACKAGE BODY APPS.XXINV_MOVE_ORDER_TRAVELER_PKG AS
---------------------------------------------------------------------------------------
--  name:            XXINV_MOVE_ORDER_TRAVELER_PKG
--  create by:       S3 Project
--  Revision:        1.0
--  creation date:   05-APR-2017
--  Object Type :    Package Body      
---------------------------------------------------------------------------------------
--  purpose :        
---------------------------------------------------------------------------------------
--  ver  date          name                 desc
--  1.0                S3 Project           initial build - Created During S3 Project
--  1.1  05-APR-2017   Lingaraj Sarangi     Deployment on 12.1.3
---------------------------------------------------------------------------------------  
g_pkg_name CONSTANT VARCHAR2(30) := 'XXINV_MOVE_ORDER_TRAVELER_PKG';
  C_LOG_PRINT_EVENTS CONSTANT BOOLEAN := TRUE;  --Controls if "Print Events" will be logged within a designated DFF on the Move Order Line record.
  l_printer_name VARCHAR2(150); 

  FUNCTION BEFOREREPORT RETURN BOOLEAN IS
    C_DATE_FORMAT varchar2(20);
  BEGIN
    BEGIN
      P_CONC_REQUEST_ID := FND_GLOBAL.CONC_REQUEST_ID;
      C_DATE_FORMAT     := 'DD-MON-YYYY';
      CP_DATE_REQD_LO   := to_char(P_DATE_REQD_LO, C_DATE_FORMAT);
      CP_DATE_REQD_HI   := to_char(P_DATE_REQD_HI, C_DATE_FORMAT);
      /*SRW.USER_EXIT('FND SRWINIT')*/
      NULL;
    EXCEPTION
      WHEN /*SRW.USER_EXIT_FAILURE*/
       OTHERS THEN
        /*SRW.MESSAGE(1
        ,'Before Report: Init')*/
        NULL;
    END;
    DECLARE
      L_RETURN_STATUS VARCHAR2(1);
      L_MSG_COUNT     NUMBER;
      L_MSG_DATA      VARCHAR2(240);
    BEGIN
      IF WMS_INSTALL.CHECK_INSTALL(X_RETURN_STATUS   => L_RETURN_STATUS,
                                   X_MSG_COUNT       => L_MSG_COUNT,
                                   X_MSG_DATA        => L_MSG_DATA,
                                   P_ORGANIZATION_ID => P_ORG_ID) THEN
        P_WMS_INSTALL := 'Y';
      ELSE
        P_WMS_INSTALL := 'N';
      END IF;
    END;
    GET_CHART_OF_ACCOUNTS_ID;
    BEGIN
      /*SRW.USER_EXIT('FND PUTPROFILE NAME="' || 'MFG_ORGANIZATION_ID' || '" FIELD="' || TO_CHAR(P_ORG_ID) || '"')*/
      NULL;
      /*SRW.USER_EXIT('FND PUTPROFILE NAME="' || 'MFG_SET_OF_BOOKS_ID' || '" FIELD="' || TO_CHAR(P_SET_OF_BOOKS_ID) || '"')*/
      NULL;
      FND_PROFILE.PUT('MFG_ORGANIZATION_ID', TO_CHAR(P_ORG_ID));
    EXCEPTION
      WHEN /*SRW.USER_EXIT_FAILURE*/
       OTHERS THEN
        /*SRW.MESSAGE(1
        ,'Before Report: Failed in setting org/ledger id profiles ')*/
        NULL;
        RAISE;
    END;
    BEGIN
      NULL;
    EXCEPTION
      WHEN /*SRW.USER_EXIT_FAILURE*/
       OTHERS THEN
        /*SRW.MESSAGE(1
        ,'Before Report: ItemFlex')*/
        NULL;
    END;
    BEGIN
      /*SRW.REFERENCE(CP_CHART_OF_ACCOUNTS_NUM)*/
      NULL;
    EXCEPTION
      WHEN /*SRW.USER_EXIT_FAILURE*/
       OTHERS THEN
        /*SRW.MESSAGE(1
        ,'Before Report: AccountFlex')*/
        NULL;
    END;
    IF P_ALLOCATE_MOVE_ORDER = 'Y' THEN
      INV_CALL_ALLOCATIONS_ENGINE;
    END IF;

    P_SOURCE_LOCATOR := INV_PROJECT.GET_LOCATOR(P_SOURCE_LOCATOR_ID,
                                                P_ORG_ID);
    P_DEST_LOCATOR   := INV_PROJECT.GET_LOCATOR(P_DEST_LOCATOR_ID, P_ORG_ID);
    DECLARE
      l_return boolean;
    BEGIN
      l_return := P_ORG_IDVALIDTRIGGER();
      l_return := P_REQUESTED_BYVALIDTRIGGER();
      l_return := P_MOVE_ORDER_TYPEVALIDTRIGGER();
      l_return := P_PICK_SLIP_GROUP_RULE_IDVALID();
      l_return := P_PRINT_OPTIONVALIDTRIGGER();
      l_return := P_ALLOCATE_MOVE_ORDERVALIDTRIG();
      l_return := P_PLAN_TASKSVALIDTRIGGER();
      l_return := P_FREIGHT_CODEVALIDTRIGGER();
    END;
    BEGIN      
      /* Call custom function to specify the sorting for the data template's main query.*/
      P_LEXICAL_ORDER_BY_CLAUSE_MAIN := f_order_by_clause;
    END;
    
    BEGIN
        /* Get the printer name for the Concurrent Request*/
        SELECT printer INTO l_printer_name
        FROM fnd_conc_req_summary_v
        WHERE request_id = P_CONC_REQUEST_ID;
    END;
    RETURN(TRUE);
  END BEFOREREPORT;
  FUNCTION AFTERREPORT RETURN BOOLEAN IS
  BEGIN
    /*SRW.USER_EXIT('FND SRWEXIT')*/
    NULL;
    RETURN(TRUE);
  END AFTERREPORT;
  FUNCTION AFTERPFORM RETURN BOOLEAN IS
    L_TEMP_WHERE VARCHAR2(200);
  BEGIN
    IF P_MOVE_ORDER_LOW IS NOT NULL THEN
      L_TEMP_WHERE := ' AND MTRH.REQUEST_NUMBER >= :P_MOVE_ORDER_LOW';
      P_WHERE_MMT  := P_WHERE_MMT || L_TEMP_WHERE;
      P_WHERE_MMTT := P_WHERE_MMTT || L_TEMP_WHERE;
      P_WHERE_MTRL := P_WHERE_MTRL || L_TEMP_WHERE;
    END IF;
    IF P_MOVE_ORDER_HIGH IS NOT NULL THEN
      L_TEMP_WHERE := ' AND MTRH.REQUEST_NUMBER <= :P_MOVE_ORDER_HIGH';
      P_WHERE_MMT  := P_WHERE_MMT || L_TEMP_WHERE;
      P_WHERE_MMTT := P_WHERE_MMTT || L_TEMP_WHERE;
      P_WHERE_MTRL := P_WHERE_MTRL || L_TEMP_WHERE;
    END IF;
    IF P_DATE_REQD_LO IS NOT NULL THEN
      L_TEMP_WHERE := ' AND TO_CHAR(MTRL.Date_required,''YYYY-MM-DD'') >= TO_CHAR(:P_DATE_REQD_LO,''YYYY-MM-DD'')';
      P_WHERE_MMT  := P_WHERE_MMT || L_TEMP_WHERE;
      P_WHERE_MMTT := P_WHERE_MMTT || L_TEMP_WHERE;
      P_WHERE_MTRL := P_WHERE_MTRL || L_TEMP_WHERE;
    END IF;
    IF P_DATE_REQD_HI IS NOT NULL THEN
      L_TEMP_WHERE := ' AND TO_CHAR(MTRL.Date_required,''YYYY-MM-DD'') <= TO_CHAR(:P_DATE_REQD_HI,''YYYY-MM-DD'')';
      P_WHERE_MMT  := P_WHERE_MMT || L_TEMP_WHERE;
      P_WHERE_MMTT := P_WHERE_MMTT || L_TEMP_WHERE;
      P_WHERE_MTRL := P_WHERE_MTRL || L_TEMP_WHERE;
    END IF;
    IF (P_SOURCE_SUBINV IS NOT NULL) THEN
      P_WHERE_MMT  := P_WHERE_MMT ||
                      ' AND MMT.SUBINVENTORY_CODE       = :P_SOURCE_SUBINV';
      P_WHERE_MMTT := P_WHERE_MMTT ||
                      ' AND MMTT.SUBINVENTORY_CODE      = :P_SOURCE_SUBINV';
      P_WHERE_MTRL := P_WHERE_MTRL ||
                      ' AND MTRL.FROM_SUBINVENTORY_CODE = :P_SOURCE_SUBINV';
    END IF;
    IF (P_SOURCE_LOCATOR_ID IS NOT NULL) THEN
      P_WHERE_MMT  := P_WHERE_MMT ||
                      ' AND MMT.LOCATOR_ID       = :P_SOURCE_LOCATOR_ID';
      P_WHERE_MMTT := P_WHERE_MMTT ||
                      ' AND MMTT.LOCATOR_ID      = :P_SOURCE_LOCATOR_ID';
      P_WHERE_MTRL := P_WHERE_MTRL ||
                      ' AND MTRL.FROM_LOCATOR_ID = :P_SOURCE_LOCATOR_ID';
    END IF;
    IF (P_DEST_SUBINV IS NOT NULL) THEN
      P_WHERE_MMT  := P_WHERE_MMT ||
                      ' AND MMT.TRANSFER_SUBINVENTORY  = :P_DEST_SUBINV';
      P_WHERE_MMTT := P_WHERE_MMTT ||
                      ' AND MMTT.TRANSFER_SUBINVENTORY = :P_DEST_SUBINV';
      P_WHERE_MTRL := P_WHERE_MTRL ||
                      ' AND MTRL.TO_SUBINVENTORY_CODE  = :P_DEST_SUBINV';
    END IF;
    IF (P_DEST_LOCATOR_ID IS NOT NULL) THEN
      P_WHERE_MMT  := P_WHERE_MMT ||
                      ' AND MMT.TRANSFER_LOCATOR_ID   = :P_DEST_LOCATOR_ID';
      P_WHERE_MMTT := P_WHERE_MMTT ||
                      ' AND MMTT.TRANSFER_TO_LOCATION = :P_DEST_LOCATOR_ID';
      P_WHERE_MTRL := P_WHERE_MTRL ||
                      ' AND MTRL.TO_LOCATOR_ID        = :P_DEST_LOCATOR_ID';
    END IF;
    IF P_REQUESTED_BY IS NOT NULL THEN
      L_TEMP_WHERE := ' AND MTRL.CREATED_BY = :P_REQUESTED_BY';
      P_WHERE_MMT  := P_WHERE_MMT || L_TEMP_WHERE;
      P_WHERE_MMTT := P_WHERE_MMTT || L_TEMP_WHERE;
      P_WHERE_MTRL := P_WHERE_MTRL || L_TEMP_WHERE;
    END IF;
    IF P_MOVE_ORDER_TYPE = 1 THEN
      L_TEMP_WHERE := ' AND MTRH.MOVE_ORDER_TYPE = 3';
    ELSIF P_MOVE_ORDER_TYPE = 2 THEN
      L_TEMP_WHERE := ' AND MTRH.MOVE_ORDER_TYPE = 6';
    ELSIF P_MOVE_ORDER_TYPE = 3 THEN
      L_TEMP_WHERE := ' AND MTRH.MOVE_ORDER_TYPE = 5';
    ELSIF P_MOVE_ORDER_TYPE = 4 THEN
      L_TEMP_WHERE := ' AND MTRH.MOVE_ORDER_TYPE IN (1,2)';
    ELSE
      L_TEMP_WHERE := ' AND MTRH.MOVE_ORDER_TYPE IN (1,2,3,5,6)';
    END IF;
    P_WHERE_MMT  := P_WHERE_MMT || L_TEMP_WHERE;
    P_WHERE_MMTT := P_WHERE_MMTT || L_TEMP_WHERE;
    P_WHERE_MTRL := P_WHERE_MTRL || L_TEMP_WHERE;
    IF P_PRINT_OPTION = '1' THEN
      P_WHERE_MMT  := P_WHERE_MMT || ' AND 1 = 2 ';
      P_WHERE_MMTT := P_WHERE_MMTT || ' AND 1 = 2 ';
    ELSIF P_PRINT_OPTION = '2' THEN
      P_WHERE_MMT  := P_WHERE_MMT || ' AND 1 = 2 ';
      P_WHERE_MTRL := P_WHERE_MTRL || ' AND 1 = 2 ';
    ELSIF P_PRINT_OPTION = '3' THEN
      P_WHERE_MMT  := P_WHERE_MMT || ' AND 1 = 2 ';
      P_WHERE_MMTT := P_WHERE_MMTT || ' AND MMTT.WMS_TASK_STATUS = 8 ';
      P_WHERE_MTRL := P_WHERE_MTRL || ' AND 1 = 2 ';
    ELSIF P_PRINT_OPTION = '4' THEN
      P_WHERE_MMT  := P_WHERE_MMT || ' AND 1 = 2 ';
      P_WHERE_MMTT := P_WHERE_MMTT || ' AND MMTT.WMS_TASK_STATUS <> 8 ';
      P_WHERE_MTRL := P_WHERE_MTRL || ' AND 1 = 2 ';
    ELSIF P_PRINT_OPTION = '5' THEN
      P_WHERE_MMTT := P_WHERE_MMTT || ' AND 1 = 2 ';
      P_WHERE_MTRL := P_WHERE_MTRL || ' AND 1 = 2 ';
    ELSE
      NULL;
    END IF;
    IF P_PICK_SLIP_NUMBER_LOW IS NOT NULL THEN
      P_WHERE_MMT  := P_WHERE_MMT ||
                      ' AND MMT.PICK_SLIP_NUMBER  >= :P_PICK_SLIP_NUMBER_LOW';
      P_WHERE_MMTT := P_WHERE_MMTT ||
                      ' AND MMTT.PICK_SLIP_NUMBER >= :P_PICK_SLIP_NUMBER_LOW';
    END IF;
    IF P_PICK_SLIP_NUMBER_HIGH IS NOT NULL THEN
      P_WHERE_MMT  := P_WHERE_MMT ||
                      ' AND MMT.PICK_SLIP_NUMBER  <= :P_PICK_SLIP_NUMBER_HIGH';
      P_WHERE_MMTT := P_WHERE_MMTT ||
                      ' AND MMTT.PICK_SLIP_NUMBER <= :P_PICK_SLIP_NUMBER_HIGH';
    END IF;
    IF P_SALES_ORDER_LOW IS NOT NULL OR P_SALES_ORDER_HIGH IS NOT NULL OR
       P_CUSTOMER_ID IS NOT NULL OR P_FREIGHT_CODE IS NOT NULL THEN
      P_FROM_MMT   := P_FROM_MMT || ', WSH_DELIVERY_DETAILS WDD';
      P_FROM_MMTT  := P_FROM_MMTT || ', WSH_DELIVERY_DETAILS WDD';
      P_FROM_MTRL  := P_FROM_MTRL || ', WSH_DELIVERY_DETAILS WDD';
      L_TEMP_WHERE := '';
      IF P_SALES_ORDER_LOW IS NOT NULL THEN
        L_TEMP_WHERE := L_TEMP_WHERE ||
                        ' AND WDD.SOURCE_HEADER_NUMBER >= :P_SALES_ORDER_LOW ';
      END IF;
      IF P_SALES_ORDER_HIGH IS NOT NULL THEN
        L_TEMP_WHERE := L_TEMP_WHERE ||
                        ' AND WDD.SOURCE_HEADER_NUMBER <= :P_SALES_ORDER_HIGH ';
      END IF;
      IF P_CUSTOMER_ID IS NOT NULL THEN
        L_TEMP_WHERE := L_TEMP_WHERE ||
                        ' AND WDD.CUSTOMER_ID = :P_CUSTOMER_ID ';
      END IF;
      IF P_FREIGHT_CODE IS NOT NULL THEN
        L_TEMP_WHERE := L_TEMP_WHERE ||
                        ' WDD.SHIP_METHOD_CODE = :P_FREIGHT_CODE';
      END IF;
      L_TEMP_WHERE := L_TEMP_WHERE ||
                      ' AND MTRL.LINE_ID = WDD.MOVE_ORDER_LINE_ID';
      P_WHERE_MMT  := P_WHERE_MMT || L_TEMP_WHERE;
      P_WHERE_MMTT := P_WHERE_MMTT || L_TEMP_WHERE;
      P_WHERE_MTRL := P_WHERE_MTRL || L_TEMP_WHERE;
    else
      P_FROM_MMT  := ' ';
      P_FROM_MTRL := ' ';
      P_FROM_MMTT := ' ';
    END IF;
    
    /* Log the lexical values returned to the data template.*/
    fnd_file.put_line( fnd_file.log, 'DEBUG: Lexical values from AFTERPFORM below:' );
    fnd_file.put_line( fnd_file.log, 'DEBUG: P_FROM_MMT: "' || P_FROM_MMT || '"' );
    fnd_file.put_line( fnd_file.log, 'DEBUG: P_FROM_MMTT: "' || P_FROM_MTRL || '"');
    fnd_file.put_line( fnd_file.log, 'DEBUG: P_FROM_MTRL: "' || P_FROM_MMTT || '"' );
    fnd_file.put_line( fnd_file.log, 'DEBUG: P_WHERE_MMT: "' || P_WHERE_MMT || '"' );
    fnd_file.put_line( fnd_file.log, 'DEBUG: P_WHERE_MMTT: "' || P_WHERE_MMTT || '"');
    fnd_file.put_line( fnd_file.log, 'DEBUG: P_WHERE_MTRL: "' || P_WHERE_MTRL || '"' );

    
    /* NEED TO INSERT CODE HERE TO APPEND APPROPRIATE WHERE CLAUSES WITH LOCATOR SEGMENT FILTERS AND INCLUDE REPRINTS FILTERS*/
    COMMIT;
    RETURN(TRUE);
  END AFTERPFORM;
  PROCEDURE GET_CHART_OF_ACCOUNTS_ID IS
    L_ERRBUF VARCHAR2(132);
    L_COAID  NUMBER;
  BEGIN
    BEGIN
      SELECT SET_OF_BOOKS_ID
        INTO P_SET_OF_BOOKS_ID
        FROM ORG_ORGANIZATION_DEFINITIONS
       WHERE ORGANIZATION_ID = P_ORG_ID;
    EXCEPTION
      WHEN OTHERS THEN
        /*SRW.MESSAGE(1
        ,'Could not find the ledger id')*/
        NULL;
        /*RAISE SRW.PROGRAM_ABORT*/
        RAISE_APPLICATION_ERROR(-20101, null);
    END;
    BEGIN
      SELECT CHART_OF_ACCOUNTS_ID
        INTO L_COAID
        FROM GL_SETS_OF_BOOKS
       WHERE SET_OF_BOOKS_ID = P_SET_OF_BOOKS_ID;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        /*SRW.MESSAGE(1
        ,'No Data Found in Get COAI')*/
        NULL;
        L_ERRBUF := GL_MESSAGE.GET_MESSAGE('GL_PLL_INVALID_SOB',
                                           'Y',
                                           'SOBID',
                                           TO_CHAR(P_SET_OF_BOOKS_ID));
        /*SRW.MESSAGE(1
        ,L_ERRBUF)*/
        NULL;
        /*RAISE SRW.PROGRAM_ABORT*/
        RAISE_APPLICATION_ERROR(-20101, null);
      WHEN OTHERS THEN
        /*SRW.MESSAGE(1
        ,'Others Exception in Get COAI')*/
        NULL;
        L_ERRBUF := SQLERRM;
        /*SRW.MESSAGE(1
        ,L_ERRBUF)*/
        NULL;
        /*RAISE SRW.PROGRAM_ABORT*/
        RAISE_APPLICATION_ERROR(-20101, null);
    END;
    CP_CHART_OF_ACCOUNTS_NUM := L_COAID;
  END GET_CHART_OF_ACCOUNTS_ID;
  FUNCTION P_REQUESTED_BYVALIDTRIGGER RETURN BOOLEAN IS
  BEGIN
    IF P_REQUESTED_BY IS NOT NULL THEN
      SELECT USER_NAME
        INTO P_REQUESTED_BY_NAME
        FROM FND_USER
       WHERE USER_ID = P_REQUESTED_BY;
    END IF;
    RETURN(TRUE);
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END P_REQUESTED_BYVALIDTRIGGER;
  FUNCTION P_ORG_IDVALIDTRIGGER RETURN BOOLEAN IS
  BEGIN
    SELECT ORG.ORGANIZATION_NAME
      INTO P_ORG_NAME
      FROM ORG_ORGANIZATION_DEFINITIONS ORG
     WHERE ORG.ORGANIZATION_ID = P_ORG_ID;
    RETURN(TRUE);
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END P_ORG_IDVALIDTRIGGER;
  FUNCTION CF_PROJECT_NUMBERFORMULA(PROJECT_ID IN NUMBER) RETURN CHAR IS
    L_PROJECT_NUMBER VARCHAR2(100);
    L_PROJECT_ID     NUMBER; -- Bug 13791981 added
  BEGIN
    L_PROJECT_ID := PROJECT_ID; -- Bug 13791981 added

    IF L_PROJECT_ID IS NOT NULL THEN
      -- Bug 13791981 changed
      BEGIN
        SELECT PROJECT_NUMBER
          INTO L_PROJECT_NUMBER
          FROM PJM_PROJECTS_V PJMP
         WHERE L_PROJECT_ID = PJMP.PROJECT_ID; -- Bug 13791981 changed
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          BEGIN
            SELECT PROJECT_NUMBER
              INTO L_PROJECT_NUMBER
              FROM PA_PROJECTS_EXPEND_V PPEV
             WHERE L_PROJECT_ID = PPEV.PROJECT_ID -- Bug 13791981 changed
               AND ROWNUM = 1;
          EXCEPTION
            WHEN OTHERS THEN
              L_PROJECT_NUMBER := NULL;
          END;
        WHEN OTHERS THEN
          L_PROJECT_NUMBER := NULL;
      END;
    END IF;
    RETURN(L_PROJECT_NUMBER);
  EXCEPTION
    WHEN OTHERS THEN
      RETURN(NULL);
  END CF_PROJECT_NUMBERFORMULA;
  FUNCTION CF_TASK_NUMBERFORMULA(TASK_ID IN NUMBER, PROJECT_ID IN NUMBER)
    RETURN CHAR IS
    L_TASK_NUMBER VARCHAR2(100);
    L_TASK_ID     NUMBER; -- Bug 13791981 added
    L_PROJECT_ID  NUMBER; -- Bug 13791981 added
  BEGIN
    -- Bug 13791981 added
    L_TASK_ID    := TASK_ID;
    L_PROJECT_ID := PROJECT_ID;

    IF L_TASK_ID IS NOT NULL THEN
      -- Bug 13791981 changed
      BEGIN
        SELECT TASK_NUMBER
          INTO L_TASK_NUMBER
          FROM PJM_TASKS_V PJMT
         WHERE L_PROJECT_ID = PJMT.PROJECT_ID -- Bug 13791981 changed
           AND L_TASK_ID = PJMT.TASK_ID; -- Bug 13791981 changed
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          BEGIN
            SELECT TASK_NUMBER
              INTO L_TASK_NUMBER
              FROM PA_TASKS_EXPEND_V PTEV
             WHERE L_PROJECT_ID = PTEV.PROJECT_ID -- Bug 13791981 changed
               AND L_TASK_ID = PTEV.TASK_ID -- Bug 13791981 changed
               AND ROWNUM = 1;
          EXCEPTION
            WHEN OTHERS THEN
              L_TASK_NUMBER := NULL;
          END;
        WHEN OTHERS THEN
          L_TASK_NUMBER := NULL;
      END;
    END IF;
    RETURN(L_TASK_NUMBER);
  EXCEPTION
    WHEN OTHERS THEN
      RETURN(NULL);
  END CF_TASK_NUMBERFORMULA;
  FUNCTION P_MOVE_ORDER_TYPEVALIDTRIGGER RETURN BOOLEAN IS
  BEGIN
    SELECT MEANING
      INTO P_MOVE_ORDER_TYPE_MEANING
      FROM MFG_LOOKUPS
     WHERE LOOKUP_TYPE = 'INV_PICK_SLIP_MO_TYPES'
       AND LOOKUP_CODE = P_MOVE_ORDER_TYPE;
    RETURN(TRUE);
  EXCEPTION
    WHEN OTHERS THEN
      RETURN TRUE;
  END P_MOVE_ORDER_TYPEVALIDTRIGGER;
  FUNCTION P_PICK_SLIP_GROUP_RULE_IDVALID RETURN BOOLEAN IS
  BEGIN
    IF P_PICK_SLIP_GROUP_RULE_ID IS NOT NULL THEN
      SELECT NAME
        INTO P_PICK_SLIP_GROUP_RULE_NAME
        FROM WSH_PICK_GROUPING_RULES
       WHERE PICK_GROUPING_RULE_ID = P_PICK_SLIP_GROUP_RULE_ID;
    END IF;
    RETURN(TRUE);
  EXCEPTION
    WHEN OTHERS THEN
      RETURN TRUE;
  END P_PICK_SLIP_GROUP_RULE_IDVALID;
  FUNCTION P_PRINT_OPTIONVALIDTRIGGER RETURN BOOLEAN IS
    L_PRINT_OPTION NUMBER;
  BEGIN
    IF P_PRINT_OPTION = '1' THEN
      L_PRINT_OPTION := 1;
    ELSIF P_PRINT_OPTION = '2' THEN
      L_PRINT_OPTION := 2;
    ELSIF P_PRINT_OPTION = '3' THEN
      L_PRINT_OPTION := 3;
    ELSIF P_PRINT_OPTION = '4' THEN
      L_PRINT_OPTION := 4;
    ELSIF P_PRINT_OPTION = '5' THEN
      L_PRINT_OPTION := 5;
    ELSE
      L_PRINT_OPTION := 99;
    END IF;
    SELECT MEANING
      INTO P_PRINT_OPTION_MEANING
      FROM MFG_LOOKUPS
     WHERE LOOKUP_TYPE = 'INV_PICK_SLIP_PRINT_OPTIONS'
       AND LOOKUP_CODE = L_PRINT_OPTION;
    RETURN(TRUE);
  EXCEPTION
    WHEN OTHERS THEN
      RETURN TRUE;
  END P_PRINT_OPTIONVALIDTRIGGER;
  FUNCTION CF_WIP_INFOFORMULA(LINE_ID_P                  IN NUMBER,
                              MOVE_ORDER_TYPE            IN NUMBER,
                              TRANSACTION_SOURCE_TYPE_ID IN NUMBER)
    RETURN NUMBER IS
    CURSOR C_WIP_ENTITY_TYPE IS
      SELECT WE.ENTITY_TYPE
        FROM WIP_ENTITIES WE, MTL_TXN_REQUEST_LINES MTRL
       WHERE MTRL.LINE_ID = LINE_ID_P --bug12674388
         AND WE.WIP_ENTITY_ID = MTRL.TXN_SOURCE_ID;
    CURSOR C_DISCRETE_INFO IS
      SELECT WE.WIP_ENTITY_NAME JOB,
             WL.LINE_CODE LINE,
             WO.OPERATION_SEQ_NUM OPERATION,
             BD.DEPARTMENT_CODE DEPARTMENT,
             TO_CHAR(NULL) START_DATE
        FROM WIP_ENTITIES          WE,
             WIP_LINES             WL,
             BOM_DEPARTMENTS       BD,
             WIP_OPERATIONS        WO,
             WIP_DISCRETE_JOBS     WDJ,
             MTL_TXN_REQUEST_LINES MTRL
       WHERE WE.WIP_ENTITY_ID = WDJ.WIP_ENTITY_ID
         AND WE.ORGANIZATION_ID = WDJ.ORGANIZATION_ID
         AND WDJ.LINE_ID = wl.line_id(+)
         AND WDJ.ORGANIZATION_ID = wl.organization_id(+)
         AND WO.DEPARTMENT_ID = bd.department_id(+)
         AND MTRL.TXN_SOURCE_ID = wo.wip_entity_id(+)
         AND MTRL.ORGANIZATION_ID = wo.organization_id(+)
         AND MTRL.TXN_SOURCE_LINE_ID = wo.operation_seq_num(+)
         AND WDJ.WIP_ENTITY_ID = MTRL.TXN_SOURCE_ID
         AND WDJ.ORGANIZATION_ID = MTRL.ORGANIZATION_ID
         AND MTRL.LINE_ID = LINE_ID_P;
    CURSOR C_REPETITIVE_INFO IS
      SELECT MSIK.CONCATENATED_SEGMENTS JOB,
             WL.LINE_CODE LINE,
             WO.OPERATION_SEQ_NUM OPERATION,
             BD.DEPARTMENT_CODE DEPARTMENT,
             TO_CHAR(WRS.FIRST_UNIT_START_DATE) START_DATE
        FROM MTL_SYSTEM_ITEMS_KFV     MSIK,
             WIP_ENTITIES             WE,
             WIP_LINES                WL,
             BOM_DEPARTMENTS          BD,
             WIP_OPERATIONS           WO,
             WIP_REPETITIVE_SCHEDULES WRS,
             MTL_TXN_REQUEST_LINES    MTRL
       WHERE MSIK.INVENTORY_ITEM_ID = WE.PRIMARY_ITEM_ID
         AND MSIK.ORGANIZATION_ID = WE.ORGANIZATION_ID
         AND WE.WIP_ENTITY_ID = WRS.WIP_ENTITY_ID
         AND WE.ORGANIZATION_ID = WRS.ORGANIZATION_ID
         AND WL.LINE_ID = WRS.LINE_ID
         AND WL.ORGANIZATION_ID = WRS.ORGANIZATION_ID
         AND bd.department_id(+) = WO.DEPARTMENT_ID
         AND wo.wip_entity_id(+) = MTRL.TXN_SOURCE_ID
         AND wo.operation_seq_num(+) = MTRL.TXN_SOURCE_LINE_ID
         AND wo.organization_id(+) = MTRL.ORGANIZATION_ID
         AND wo.repetitive_schedule_id(+) = MTRL.REFERENCE_ID
         AND WRS.WIP_ENTITY_ID = MTRL.TXN_SOURCE_ID
         AND WRS.REPETITIVE_SCHEDULE_ID = MTRL.REFERENCE_ID
         AND WRS.ORGANIZATION_ID = MTRL.ORGANIZATION_ID
         AND MTRL.LINE_ID = LINE_ID_P;
    CURSOR C_FLOW_INFO IS
      SELECT WE.WIP_ENTITY_NAME JOB,
             WL.LINE_CODE LINE,
             BOS2.OPERATION_SEQ_NUM OPERATION,
             BD.DEPARTMENT_CODE DEPARTMENT,
             TO_CHAR(NULL) START_DATE
        FROM WIP_ENTITIES             WE,
             WIP_LINES                WL,
             BOM_DEPARTMENTS          BD,
             BOM_OPERATION_SEQUENCES  BOS2,
             BOM_OPERATION_SEQUENCES  BOS,
             BOM_OPERATIONAL_ROUTINGS BOR,
             WIP_FLOW_SCHEDULES       WFS,
             MTL_TXN_REQUEST_LINES    MTRL
       WHERE WE.WIP_ENTITY_ID = WFS.WIP_ENTITY_ID
         AND WE.ORGANIZATION_ID = WFS.ORGANIZATION_ID
         AND WL.LINE_ID = WFS.LINE_ID
         AND WL.ORGANIZATION_ID = WFS.ORGANIZATION_ID
         AND BD.DEPARTMENT_ID = BOS2.DEPARTMENT_ID
         AND BOS2.OPERATION_SEQUENCE_ID = BOS.LINE_OP_SEQ_ID
         AND BOS2.ROUTING_SEQUENCE_ID = BOS.ROUTING_SEQUENCE_ID
         AND BOS.ROUTING_SEQUENCE_ID = BOR.ROUTING_SEQUENCE_ID
         AND BOS.OPERATION_TYPE = 1
         AND (BOR.ALTERNATE_ROUTING_DESIGNATOR =
             WFS.ALTERNATE_ROUTING_DESIGNATOR OR
             (WFS.ALTERNATE_ROUTING_DESIGNATOR IS NULL AND
             BOR.ALTERNATE_ROUTING_DESIGNATOR IS NULL))
         AND BOR.ASSEMBLY_ITEM_ID = WFS.PRIMARY_ITEM_ID
         AND BOR.ORGANIZATION_ID = WFS.ORGANIZATION_ID
         AND WFS.WIP_ENTITY_ID = MTRL.TXN_SOURCE_ID
         AND WFS.ORGANIZATION_ID = MTRL.ORGANIZATION_ID
         AND MTRL.LINE_ID = LINE_ID_P;
    L_WIP_INFO C_DISCRETE_INFO%ROWTYPE;
  BEGIN
    CP_WIP_ENTITY_TYPE := NULL;
    IF (MOVE_ORDER_TYPE = 5 AND TRANSACTION_SOURCE_TYPE_ID in (5, 13)) THEN
      OPEN C_WIP_ENTITY_TYPE;
      FETCH C_WIP_ENTITY_TYPE
        INTO CP_WIP_ENTITY_TYPE;
      CLOSE C_WIP_ENTITY_TYPE;
      IF CP_WIP_ENTITY_TYPE in (1, 5) THEN
        OPEN C_DISCRETE_INFO;
        FETCH C_DISCRETE_INFO
          INTO L_WIP_INFO;
        CLOSE C_DISCRETE_INFO;
      ELSIF CP_WIP_ENTITY_TYPE = 2 THEN
        OPEN C_REPETITIVE_INFO;
        FETCH C_REPETITIVE_INFO
          INTO L_WIP_INFO;
        CLOSE C_REPETITIVE_INFO;
      ELSIF CP_WIP_ENTITY_TYPE = 4 THEN
        OPEN C_FLOW_INFO;
        FETCH C_FLOW_INFO
          INTO L_WIP_INFO;
        CLOSE C_FLOW_INFO;
      END IF;
    END IF;
    CP_WIP_JOB        := L_WIP_INFO.JOB;
    CP_WIP_LINE       := L_WIP_INFO.LINE;
    CP_WIP_OPERATION  := L_WIP_INFO.OPERATION;
    CP_WIP_DEPARTMENT := L_WIP_INFO.DEPARTMENT;
    CP_WIP_START_DATE := L_WIP_INFO.START_DATE;
    RETURN 1;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN - 1;
  END CF_WIP_INFOFORMULA;
  FUNCTION CF_SO_INFOFORMULA(LINE_ID IN NUMBER, MOVE_ORDER_TYPE IN NUMBER)
    RETURN NUMBER IS
    CURSOR C_SO_INFO IS
      SELECT WDD.SOURCE_HEADER_NUMBER SO_NUMBER,
             OEL.LINE_NUMBER          SO_LINE_NUMBER,
             WND.NAME                 DELIVERY_NAME
        FROM OE_ORDER_LINES_ALL       OEL,
             WSH_DELIVERY_DETAILS     WDD,
             WSH_DELIVERY_ASSIGNMENTS WDA,
             WSH_NEW_DELIVERIES       WND
       WHERE WDD.MOVE_ORDER_LINE_ID = CF_SO_INFOFORMULA.LINE_ID
         AND WDD.SOURCE_LINE_ID = OEL.LINE_ID
         AND WDD.DELIVERY_DETAIL_ID = WDA.DELIVERY_DETAIL_ID
         AND WND.DELIVERY_ID(+) = WDA.DELIVERY_ID;
  BEGIN
    IF MOVE_ORDER_TYPE = 3 THEN
      OPEN C_SO_INFO;
      FETCH C_SO_INFO
        INTO CP_SO_ORDER_NUMBER, CP_SO_LINE_NUMBER, CP_SO_DELIVERY_NAME;
      CLOSE C_SO_INFO;
    END IF;
    RETURN 1;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN - 1;
  END CF_SO_INFOFORMULA;
  PROCEDURE INV_CALL_ALLOCATIONS_ENGINE IS
    L_DETAIL_STATUS VARCHAR2(10);
  BEGIN
    IF (P_MOVE_ORDER_TYPE IS NOT NULL AND P_ORG_ID IS NOT NULL) THEN
      RUN_DETAIL_ENGINE(L_DETAIL_STATUS,
                                             P_ORG_ID,
                                             P_MOVE_ORDER_TYPE,
                                             P_MOVE_ORDER_LOW,
                                             P_MOVE_ORDER_HIGH,
                                             P_SOURCE_SUBINV,
                                             P_SOURCE_LOCATOR_ID,
                                             P_DEST_SUBINV,
                                             P_DEST_LOCATOR_ID,
                                             P_SALES_ORDER_LOW,
                                             P_SALES_ORDER_HIGH,
                                             P_FREIGHT_CODE,
                                             P_CUSTOMER_ID,
                                             P_REQUESTED_BY,
                                             P_DATE_REQD_LO,
                                             P_DATE_REQD_HI,
                                             (P_PLAN_TASKS = 'Y'),
                                             P_PICK_SLIP_GROUP_RULE_ID,
                                             P_CONC_REQUEST_ID);
      IF L_DETAIL_STATUS in ('E', 'U') THEN
        /*SRW.MESSAGE(1
        ,'Detail Engine Failed to release some/all lines')*/
        NULL;
      END IF;
    END IF;
  END INV_CALL_ALLOCATIONS_ENGINE;
  FUNCTION P_CUSTOMER_IDVALIDTRIGGER RETURN BOOLEAN IS
  BEGIN
    IF P_CUSTOMER_ID IS NOT NULL THEN
      BEGIN
        SELECT PARTY.PARTY_NAME
          INTO P_CUSTOMER_NAME
          FROM HZ_PARTIES PARTY, HZ_CUST_ACCOUNTS CUST_ACCT
         WHERE CUST_ACCT.CUST_ACCOUNT_ID = P_CUSTOMER_ID
           AND PARTY.PARTY_ID = CUST_ACCT.PARTY_ID;
      EXCEPTION
        WHEN OTHERS THEN
          NULL;
      END;
    END IF;
    RETURN TRUE;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN TRUE;
  END P_CUSTOMER_IDVALIDTRIGGER;
  FUNCTION CF_TASK_STATUSFORMULA(TASK_STATUS IN NUMBER) RETURN CHAR IS
    L_MEANING VARCHAR2(20);
  BEGIN
    IF TASK_STATUS IS NOT NULL AND TASK_STATUS <> 0 THEN
      SELECT MEANING
        INTO L_MEANING
        FROM MFG_LOOKUPS
       WHERE LOOKUP_TYPE = 'WMS_TASK_STATUS'
         AND LOOKUP_CODE = TASK_STATUS;
    ELSIF TASK_STATUS = 0 THEN
      L_MEANING := P_CONST_UNALLOCATED;
    END IF;
    RETURN L_MEANING;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END CF_TASK_STATUSFORMULA;
  FUNCTION CF_TASK_IDFORMULA(TASK_STATUS    IN NUMBER,
                             PARENT_LINE_ID IN NUMBER,
                             TRANSACTION_ID IN NUMBER) RETURN NUMBER IS
  BEGIN
    IF TASK_STATUS not in (0, 6) AND P_WMS_INSTALL = 'Y' THEN
      RETURN NVL(PARENT_LINE_ID, TRANSACTION_ID);
    ELSE
      RETURN NULL;
    END IF;
  END CF_TASK_IDFORMULA;
  FUNCTION P_ALLOCATE_MOVE_ORDERVALIDTRIG RETURN BOOLEAN IS
  BEGIN
    IF P_ALLOCATE_MOVE_ORDER IS NOT NULL THEN
      SELECT MEANING
        INTO P_ALLOCATE_MOVE_ORDER_MEANING
        FROM FND_LOOKUPS
       WHERE LOOKUP_TYPE = 'YES_NO'
         AND LOOKUP_CODE = P_ALLOCATE_MOVE_ORDER;
    END IF;
    RETURN TRUE;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN TRUE;
  END P_ALLOCATE_MOVE_ORDERVALIDTRIG;
  FUNCTION P_PLAN_TASKSVALIDTRIGGER RETURN BOOLEAN IS
  BEGIN
    IF P_PLAN_TASKS IS NOT NULL THEN
      SELECT MEANING
        INTO P_PLAN_TASKS_MEANING
        FROM FND_LOOKUPS
       WHERE LOOKUP_TYPE = 'YES_NO'
         AND LOOKUP_CODE = P_PLAN_TASKS;
    END IF;
    RETURN TRUE;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN TRUE;
  END P_PLAN_TASKSVALIDTRIGGER;
  FUNCTION P_FREIGHT_CODEVALIDTRIGGER RETURN BOOLEAN IS
  BEGIN
    RETURN(TRUE);
  END P_FREIGHT_CODEVALIDTRIGGER;
  FUNCTION CF_SEC_QTYFORMULA(INVENTORY_ITEM_ID_1 IN NUMBER,
                             SEC_TRANSACTION_QTY IN NUMBER) RETURN NUMBER IS
    L_TRACK_IND VARCHAR2(20);
    L_SEC_QTY   NUMBER;
  BEGIN
    IF INVENTORY_ITEM_ID_1 IS NOT NULL THEN
      SELECT TRACKING_QUANTITY_IND
        INTO L_TRACK_IND
        FROM MTL_SYSTEM_ITEMS_B
       WHERE INVENTORY_ITEM_ID = INVENTORY_ITEM_ID_1
         AND ORGANIZATION_ID = P_ORG_ID;
      IF (L_TRACK_IND = 'PS') THEN
        L_SEC_QTY := SEC_TRANSACTION_QTY;
      ELSE
        L_SEC_QTY := NULL;
      END IF;
    END IF;
    RETURN(L_SEC_QTY);
  END CF_SEC_QTYFORMULA;
  FUNCTION CF_SEC_UOMFORMULA(INVENTORY_ITEM_ID_1 IN NUMBER,
                             SEC_UOM             IN VARCHAR2) RETURN CHAR IS
    L_TRACK_IND VARCHAR2(20);
    L_SEC_UOM   VARCHAR2(10);
  BEGIN
    IF INVENTORY_ITEM_ID_1 IS NOT NULL THEN
      SELECT TRACKING_QUANTITY_IND
        INTO L_TRACK_IND
        FROM MTL_SYSTEM_ITEMS_B
       WHERE INVENTORY_ITEM_ID = INVENTORY_ITEM_ID_1
         AND ORGANIZATION_ID = P_ORG_ID;
      IF (L_TRACK_IND = 'PS') THEN
        L_SEC_UOM := SEC_UOM;
      ELSE
        L_SEC_UOM := NULL;
      END IF;
    END IF;
    RETURN(L_SEC_UOM);
  END CF_SEC_UOMFORMULA;
  FUNCTION CF_PARENT_SEC_UOMFORMULA(PARENT_ITEM_ID     IN NUMBER,
                                    PARENT_SEC_TXN_UOM IN VARCHAR2)
    RETURN CHAR IS
    L_TRACK_IND      VARCHAR2(20);
    L_PARENT_SEC_UOM NUMBER;
  BEGIN
    IF PARENT_ITEM_ID IS NULL THEN
      RETURN('');
    ELSE
      SELECT TRACKING_QUANTITY_IND
        INTO L_TRACK_IND
        FROM MTL_SYSTEM_ITEMS_B
       WHERE INVENTORY_ITEM_ID = PARENT_ITEM_ID
         AND ORGANIZATION_ID = P_ORG_ID;
      IF (L_TRACK_IND = 'PS') THEN
        L_PARENT_SEC_UOM := PARENT_SEC_TXN_UOM;
      ELSE
        L_PARENT_SEC_UOM := NULL;
      END IF;
    END IF;
    RETURN(L_PARENT_SEC_UOM);
  END CF_PARENT_SEC_UOMFORMULA;
  FUNCTION CF_PARENT_SEC_QTYFORMULA(PARENT_ITEM_ID     IN NUMBER,
                                    PARENT_SEC_TXN_QTY IN NUMBER)
    RETURN NUMBER IS
    L_TRACK_IND      VARCHAR2(20);
    L_PARENT_SEC_QTY NUMBER;
  BEGIN
    IF PARENT_ITEM_ID IS NULL THEN
      RETURN('');
    ELSE
      SELECT TRACKING_QUANTITY_IND
        INTO L_TRACK_IND
        FROM MTL_SYSTEM_ITEMS_B
       WHERE INVENTORY_ITEM_ID = PARENT_ITEM_ID
         AND ORGANIZATION_ID = P_ORG_ID;
      IF (L_TRACK_IND = 'PS') THEN
        L_PARENT_SEC_QTY := PARENT_SEC_TXN_QTY;
      ELSE
        L_PARENT_SEC_QTY := NULL;
      END IF;
    END IF;
    RETURN(L_PARENT_SEC_QTY);
  END CF_PARENT_SEC_QTYFORMULA;
  FUNCTION CP_SO_ORDER_NUMBER_P RETURN NUMBER IS
  BEGIN
    RETURN CP_SO_ORDER_NUMBER;
  END CP_SO_ORDER_NUMBER_P;
  FUNCTION CP_SO_LINE_NUMBER_P RETURN NUMBER IS
  BEGIN
    RETURN CP_SO_LINE_NUMBER;
  END CP_SO_LINE_NUMBER_P;
  FUNCTION CP_SO_DELIVERY_NAME_P RETURN NUMBER IS
  BEGIN
    RETURN CP_SO_DELIVERY_NAME;
  END CP_SO_DELIVERY_NAME_P;
  FUNCTION CP_WIP_JOB_P RETURN VARCHAR2 IS
  BEGIN
    RETURN CP_WIP_JOB;
  END CP_WIP_JOB_P;
  FUNCTION CP_WIP_DEPARTMENT_P RETURN VARCHAR2 IS
  BEGIN
    RETURN CP_WIP_DEPARTMENT;
  END CP_WIP_DEPARTMENT_P;
  FUNCTION CP_WIP_LINE_P RETURN VARCHAR2 IS
  BEGIN
    RETURN CP_WIP_LINE;
  END CP_WIP_LINE_P;
  FUNCTION CP_WIP_ENTITY_TYPE_P RETURN NUMBER IS
  BEGIN
    RETURN CP_WIP_ENTITY_TYPE;
  END CP_WIP_ENTITY_TYPE_P;
  FUNCTION CP_WIP_START_DATE_P RETURN VARCHAR2 IS
  BEGIN
    RETURN CP_WIP_START_DATE;
  END CP_WIP_START_DATE_P;
  FUNCTION CP_WIP_OPERATION_P RETURN VARCHAR2 IS
  BEGIN
    RETURN CP_WIP_OPERATION;
  END CP_WIP_OPERATION_P;
  FUNCTION CP_CHART_OF_ACCOUNTS_NUM_P RETURN NUMBER IS
  BEGIN
    RETURN CP_CHART_OF_ACCOUNTS_NUM;
  END CP_CHART_OF_ACCOUNTS_NUM_P;

  FUNCTION f_order_by_clause RETURN VARCHAR2 IS
  --  Name:              update_print_events_dff
  --  Created by:        Hubert, Eric
  --  Revision:          1.0
  --  creation date:     07-APR-2017
  --  Description:
  --  1) This function will dynamically build the ORDER BY clause for the report.
  --  2) It uses the sort field parameter values provided by the user.
  --  3) The validation of the field names is not part of this function and is
  --     instead handled by a value set.

    c_sort_field_count CONSTANT NUMBER := 3;  --Number of sorting parameters supported (we can go up to six with minimal effort as the concurrent program is ready for six).
    c_clause_prefix CONSTANT VARCHAR2(10) := 'ORDER BY';  --Order By keyword
    c_delimiter CONSTANT VARCHAR2(1) := ',';  --Character that delimits fields in order by clause
    c_separator CONSTANT VARCHAR2(1) := ' ';  --Character that separates such t field name from the sort direction
    c_default_return_value CONSTANT VARCHAR2(1) := ' '; --Value to return if no sort is specified (a zero-length string return an error so at least use a space character).
    c_sort_ascending CONSTANT VARCHAR2(4) := 'ASC'; --Value to return if no sort is specified
    c_sort_descending CONSTANT VARCHAR2(4) := 'DESC'; --Value to return if no sort is specified
    c_default_sort_direction CONSTANT VARCHAR2(4) := c_sort_ascending;  --Sort direction if not explicitly specified
    
    i NUMBER; --Looping variable
    l_sort_direction VARCHAR2(4);  --Contains explicti or inferred sort direction
    l_temp VARCHAR2(1000) := c_clause_prefix;  --Used to build the order by clause
    l_result VARCHAR2(1000) := NULL;  --Returned value from function
    
    /* Array to hold sort parameter values*/
    TYPE t_string_array IS VARRAY(3) OF VARCHAR2(30);  --Array of strings.  Size needs to match c_sort_field_count. (We can quickly go up to six sort fields)
    l_field_name_array t_string_array;
    l_sort_direction_array t_string_array;

  BEGIN
    /* debug statments for log file*/
    fnd_file.put_line( fnd_file.log, '*** Begin Sorting Function, f_order_by_clause***'); 

    /* Build arrays from sort parameter values (We can un-comment out sort fields 4-6, if/when requierd by the business.)*/
    l_field_name_array := t_string_array(P_SORT_FIELD_01, P_SORT_FIELD_02, P_SORT_FIELD_03); --, P_SORT_FIELD_04, P_SORT_FIELD_05, P_SORT_FIELD_06);
    l_sort_direction_array := t_string_array(P_SORT_FIELD_01_DIRECTION, P_SORT_FIELD_02_DIRECTION, P_SORT_FIELD_03_DIRECTION); -- ,P_SORT_FIELD_04_DIRECTION, P_SORT_FIELD_05_DIRECTION, P_SORT_FIELD_06_DIRECTION);

    fnd_file.put_line( fnd_file.log, 'P_SORT_FIELD_01: ' || P_SORT_FIELD_01); 
    fnd_file.put_line( fnd_file.log, 'P_SORT_FIELD_01_DIRECTION: ' || P_SORT_FIELD_01_DIRECTION);
    fnd_file.put_line( fnd_file.log, 'P_SORT_FIELD_02: ' || P_SORT_FIELD_02); 
    fnd_file.put_line( fnd_file.log, 'P_SORT_FIELD_02_DIRECTION: ' || P_SORT_FIELD_02_DIRECTION);
    fnd_file.put_line( fnd_file.log, 'P_SORT_FIELD_03: ' || P_SORT_FIELD_03); 
    fnd_file.put_line( fnd_file.log, 'P_SORT_FIELD_03_DIRECTION: ' || P_SORT_FIELD_03_DIRECTION);
    fnd_file.put_line( fnd_file.log, 'P_SORT_FIELD_04: ' || P_SORT_FIELD_04); 
    fnd_file.put_line( fnd_file.log, 'P_SORT_FIELD_04_DIRECTION: ' || P_SORT_FIELD_04_DIRECTION);
    fnd_file.put_line( fnd_file.log, 'P_SORT_FIELD_05: ' || P_SORT_FIELD_05); 
    fnd_file.put_line( fnd_file.log, 'P_SORT_FIELD_05_DIRECTION: ' || P_SORT_FIELD_05_DIRECTION);
    fnd_file.put_line( fnd_file.log, 'P_SORT_FIELD_06: ' || P_SORT_FIELD_06); 
    fnd_file.put_line( fnd_file.log, 'P_SORT_FIELD_06_DIRECTION: ' || P_SORT_FIELD_06_DIRECTION);
    
   /* Check that the associateive arrays are of the correct size. */
    CASE WHEN (l_field_name_array.count <> c_sort_field_count) OR (l_sort_direction_array.count <> c_sort_field_count) THEN
        --dbms_output.put_line('Error: invalid array length.');
        fnd_file.put_line( fnd_file.log, 'Error: invalid array length.'); 
    ELSE
        --dbms_output.put_line('Array length is correct');
        fnd_file.put_line( fnd_file.log, 'Array length is correct'); 
    END CASE;   

    /* Build dynamic order by clause. */
    FOR i IN 1..c_sort_field_count LOOP
        fnd_file.put_line( fnd_file.log, 'Loop iteration #: ' || i); 
        dbms_output.put_line(l_field_name_array(i) || ',' || l_sort_direction_array(i));
        IF l_field_name_array(i) IS NOT NULL THEN
            
            /* Prefix with a comma if not first field */
            IF (l_temp <> c_clause_prefix) AND (i <> 1) THEN
                l_temp := l_temp || c_delimiter || c_separator;
            /* Put space between order by clause and first field name. */    
            ELSIF (l_temp = c_clause_prefix) THEN
                 l_temp := l_temp || c_separator;           
            END IF;
            
            /* Determine the sort order with some validation*/
            l_sort_direction := l_sort_direction_array(i);
            
            IF l_sort_direction NOT IN (c_sort_ascending, c_sort_descending) THEN
                l_sort_direction := c_default_sort_direction;
            END IF;
           
            /* Rebuild Order By clause to reflect current sort field and direction*/
            l_temp := l_temp || l_field_name_array(i) || c_separator || l_sort_direction;
             
        END IF;
        fnd_file.put_line( fnd_file.log, 'New l_temp value at end of iteration: ' || l_temp);

    END LOOP;
    
    /* If no fields were specified for the sort then return an empty string. */
    IF l_temp = c_clause_prefix THEN
        fnd_file.put_line( fnd_file.log, 'No sort parameters specified, using default sort: ' || c_default_return_value);
        l_temp := c_default_return_value;
    END IF;
    
    l_result := l_temp;
--    fnd_file.put_line( fnd_file.log, 'Result: ' || f_order_by_clause);  --***This line is causing the program to run indefinitely
    fnd_file.put_line( fnd_file.log, '*** End Sorting Function, f_order_by_clause***'); 
    RETURN l_result;
  END f_order_by_clause;

  --------------------------------------------------------------------
  --  name:              mydebug
  --  create by:         XXX
  --  Revision:          1.0
  --  creation date:     XX/XXX/XXXX
  --------------------------------------------------------------------
  --  purpose :          Oracle Hook package that we can change the code here.
  --------------------------------------------------------------------
  --  ver  date          name              desc
  --  1.0  XX/XXX/XXXX   XXX               initial build
  --------------------------------------------------------------------
  PROCEDURE mydebug(p_message VARCHAR2, p_api_name VARCHAR2) IS
  BEGIN
    inv_log_util.trace(p_message, g_pkg_name || '.' || p_api_name, 9);
  END;

  --------------------------------------------------------------------
  --  name:              chk_wms_install
  --  create by:         XXX
  --  Revision:          1.0
  --  creation date:     XX/XXX/XXXX
  --------------------------------------------------------------------
  --  purpose :          Oracle Hook package that we can change the code here.
  --------------------------------------------------------------------
  --  ver  date          name              desc
  --  1.0  XX/XXX/XXXX   XXX               initial build
  --------------------------------------------------------------------
  FUNCTION chk_wms_install(p_organization_id IN NUMBER) RETURN VARCHAR2 IS
    l_msg_count         NUMBER;
    l_msg_data          VARCHAR2(2000);
    l_api_name CONSTANT VARCHAR(30)    := 'CHK_WMS_INSTALL';
    l_return_status     VARCHAR2(1);
  BEGIN
    IF wms_install.check_install(x_return_status   => l_return_status,
                                 x_msg_count       => l_msg_count,
                                 x_msg_data        => l_msg_data,
                                 p_organization_id => p_organization_id) THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      IF (fnd_msg_pub.check_msg_level(fnd_msg_pub.g_msg_lvl_unexp_error)) THEN
        fnd_msg_pub.add_exc_msg(g_pkg_name, l_api_name);
      END IF;

      RETURN 'FALSE';
  END chk_wms_install;

  --------------------------------------------------------------------
  --  name:              chk_wms_install
  --  create by:         XXX
  --  Revision:          1.0
  --  creation date:     XX/XXX/XXXX
  --------------------------------------------------------------------
  --  purpose :          Oracle Hook package that we can change the code here.
  --------------------------------------------------------------------
  --  ver  date          name              desc
  --  1.0  XX/XXX/XXXX   XXX               initial build
  --------------------------------------------------------------------
  
  PROCEDURE update_print_events_dff (
    /* This custom private procedure is forward-declared here since it needs to be 
    called from run_detail_engine, yet we want to keep it's code near the
    "bottom" of the package body for overall readability. */
        p_move_order_line_id_in IN NUMBER
        , p_return_status_out OUT VARCHAR2
  ); 
  
  
  PROCEDURE run_detail_engine(x_return_status           OUT NOCOPY    VARCHAR2,
                              p_org_id                                NUMBER,
                              p_move_order_type                       NUMBER,
                              p_move_order_from                       VARCHAR2,
                              p_move_order_to                         VARCHAR2,
                              p_source_subinv                         VARCHAR2,
                              p_source_locator_id                     NUMBER,
                              p_dest_subinv                           VARCHAR2,
                              p_dest_locator_id                       NUMBER,
                              p_sales_order_from                      VARCHAR2,
                              p_sales_order_to                        VARCHAR2,
                              p_freight_code                          VARCHAR2,
                              p_customer_id                           NUMBER,
                              p_requested_by                          NUMBER,
                              p_date_reqd_from                        DATE,
                              p_date_reqd_to                          DATE,
                              p_plan_tasks                            BOOLEAN,
                              p_pick_slip_group_rule_id               NUMBER,
                              p_request_id                            NUMBER
                             ) IS

  --------------------------------------------------------------------
  --  name:              run_detail_engine
  --  create by:         XXX
  --  Revision:          1.0
  --  creation date:     XX/XXX/XXXX
  --------------------------------------------------------------------
  --  purpose :          Oracle Hook package that we can change the code here.
  --                     This procedure will be called from Move Order Pick Slip Report.
  --                     Change History
  --------------------------------------------------------------------
  --  ver  date          name              desc
  --  1.0  22-Nov-2004   Nalin Kumar       Modified the Procedure and added parameter
  --                                       p_request_id to fix Bug# 4003379.
  --------------------------------------------------------------------

  /***************************************************************************
    Reason why the p_request_id parameter has been introduced into this procedure:
      Assume that
       o CURSOR c_move_order_lines has 97 records
       o 'INV: Pick Slip Batch Size' profile value is set to 10
    - Basically to eliminate already processed records from getting selected again and again into
      c_move_order_lines CURSOR the request_id has be introduced in this procedure.
    - Once the number of records processed becomes equal to the value specified in 'INV: Pick Slip Batch Size'
      profile (10) then a COMMIT is issued and the c_move_order_lines is CLOSED and OPENED once again
      (to eliminate the 'ORA-01002: fetch out of sequence' Error). When the c_move_order_lines CURSOR
      is OPENED for the second time then the CURSOR MAY fetch the already processed records. But the
      idea is to process only unprocessed records and after CLOSING the CURSOR there was no pointer to
      find out that which all records have been already processed. So to identify the processed records
      we are updating the request_id column in mtl_txn_request_lines along with quantity_detailed. And
      the same (request_id) column is now being used to identify unprocessed records.
  *****************************************************************************/
    l_api_name               VARCHAR2(30);
    l_msg_data               VARCHAR2(2000);
    l_msg_count              NUMBER;
    l_max_batch              NUMBER;
    l_batch_size             NUMBER;
    l_num_of_rows            NUMBER         := 0;
    l_detailed_qty           NUMBER         := 0;
    l_secondary_detailed_qty NUMBER         := NULL; -- INVCONV
    l_revision               VARCHAR2(3)  := NULL;
    l_from_loc_id            NUMBER         := 0;
    l_to_loc_id              NUMBER         := 0;
    -- Increased lot size to 80 Char - Mercy Thomas - B4625329
    l_lot_number             VARCHAR2(80);
    l_expiration_date        DATE;
    l_transaction_temp_id    NUMBER;
    l_txn_header_id          NUMBER;
    l_serial_flag            VARCHAR2(1);

    l_pick_slip_no           NUMBER;
    l_prev_header_id         NUMBER         := 0;
    l_req_msg                VARCHAR2(30)   := NULL;
    l_tracking_quantity_ind  VARCHAR2(30)   := NULL;
    
    l_print_event_update_result VARCHAR2(10) := NULL; --Contains status of call to update_print_events_dff

    CURSOR c_move_order_lines (l_header_id NUMBER, l_move_order_type NUMBER,
                               l_profile_value NUMBER /* Added to fix Bug# 4003379 */) IS
      SELECT l_header_id header_id,
             l_move_order_type move_order_type,
             mtrl.line_id,
             mtrl.inventory_item_id,
             mtrl.to_account_id,
             mtrl.project_id,
             mtrl.task_id,
             mtrl.quantity_detailed
        FROM mtl_txn_request_lines mtrl
       WHERE mtrl.line_status IN (3, 7)
         AND mtrl.organization_id = p_org_id
         AND mtrl.header_id =  l_header_id
         AND mtrl.quantity > NVL(mtrl.quantity_detailed, 0)
         AND (p_requested_by IS NULL OR mtrl.created_by = p_requested_by)
         AND (p_source_subinv IS NULL OR mtrl.from_subinventory_code = p_source_subinv)
         AND (p_source_locator_id IS NULL OR mtrl.from_locator_id = p_source_locator_id)
         AND (p_dest_subinv IS NULL OR mtrl.to_subinventory_code = p_dest_subinv)
         AND (p_dest_locator_id IS NULL OR mtrl.to_locator_id = p_dest_locator_id)
         AND (p_date_reqd_from IS NULL OR mtrl.date_required >= p_date_reqd_from) /* Added to fix Bug# 4078103 */
         --bug 6850379
         AND (p_date_reqd_to IS NULL OR (mtrl.date_required <= trunc(p_date_reqd_to+1)-0.00001))    /* Added to fix Bug# 4078103 */
         --bug 6850379
         AND ((p_sales_order_from IS NULL AND p_sales_order_to IS NULL AND p_customer_id IS NULL AND p_freight_code IS NULL)
               OR EXISTS (SELECT 1
                            FROM wsh_delivery_details wdd
                           WHERE wdd.organization_id = p_org_id
                             AND wdd.move_order_line_id = mtrl.line_id
                             AND (p_sales_order_from IS NULL OR wdd.source_header_number >= p_sales_order_from)
                             AND (p_sales_order_to IS NULL OR wdd.source_header_number <= p_sales_order_to)
                             AND (p_customer_id IS NULL OR wdd.customer_id = p_customer_id)
                             AND (p_freight_code IS NULL OR wdd.ship_method_code = p_freight_code))
              )
         AND NVL(mtrl.request_id, 0) < p_request_id
             /* Added to fix Bug# 4003379; If the record does not have any request_id or
                it is less than current request_id that means- that record has not been
                processed by this request so select that record for processing. */
         AND rownum < l_profile_value +1
             /* Added to fix Bug# 4003379; ROWNUM is introduced to fetch and lock only
                that many records which has to be processed in a single go based on the
                value of the 'INV: Pick Slip Batch Size' profile. */
       FOR UPDATE OF mtrl.quantity_detailed NOWAIT; -- Added 3772012

    CURSOR c_move_order_header IS
      SELECT mtrh.header_id,
             mtrh.move_order_type
        FROM mtl_txn_request_headers mtrh
       WHERE mtrh.organization_id = p_org_id
         AND (p_move_order_from IS NULL OR mtrh.request_number >= p_move_order_from)
         AND (p_move_order_to IS NULL OR mtrh.request_number <= p_move_order_to)
         AND (    (p_move_order_type = 99 AND mtrh.move_order_type IN (1,2,3,5))
               OR (p_move_order_type = 1  AND mtrh.move_order_type = 3)
               OR (p_move_order_type = 2  AND mtrh.move_order_type = 5)
	       OR (p_move_order_type = 3  AND mtrh.move_order_type = 5) --Bug #4700988 MFG Pick
               OR (p_move_order_type = 4  AND mtrh.move_order_type IN (1,2))
             );

    CURSOR c_mmtt(p_mo_line_id NUMBER) IS
      SELECT transaction_temp_id,
             subinventory_code,
             locator_id,
             transfer_subinventory,
             transfer_to_location,
             revision
        FROM mtl_material_transactions_temp
       WHERE move_order_line_id = p_mo_line_id
         AND pick_slip_number IS NULL;

    l_debug NUMBER;
    record_locked EXCEPTION; -- bug 3772012
    PRAGMA EXCEPTION_INIT(record_locked, -54); -- bug 3772012
    v_mo_line_rec c_move_order_lines%ROWTYPE;
  BEGIN
    /* Initializing the default values */
    l_api_name := 'RUN_DETAIL_ENGINE';
    l_serial_flag := 'F';
    l_debug := NVL(fnd_profile.VALUE('INV_DEBUG_TRACE'), 0);
    
    fnd_file.put_line(which => fnd_file.log, buff => 'DEBUG: run_detail_engine' );
    
    IF l_debug = 1 THEN
      mydebug('Running Detail Engine with Parameters...', l_api_name);
      mydebug('  Organization ID     = ' || p_org_id, l_api_name);
      mydebug('  Move Order Type     = ' || p_move_order_type, l_api_name);
      mydebug('  Move Order From     = ' || p_move_order_from, l_api_name);
      mydebug('  Move Order To       = ' || p_move_order_to, l_api_name);
      mydebug('  Source Subinventory = ' || p_source_subinv, l_api_name);
      mydebug('  Source Locator      = ' || p_source_locator_id, l_api_name);
      mydebug('  Dest Subinventory   = ' || p_dest_subinv, l_api_name);
      mydebug('  Dest Locator        = ' || p_dest_locator_id, l_api_name);
      mydebug('  Sales Order From    = ' || p_sales_order_from, l_api_name);
      mydebug('  Sales Order To      = ' || p_sales_order_to, l_api_name);
      mydebug('  Freight Code        = ' || p_freight_code, l_api_name);
      mydebug('  Customer ID         = ' || p_customer_id, l_api_name);
      mydebug('  Requested By        = ' || p_requested_by, l_api_name);
      mydebug('  Date Required From  = ' || p_date_reqd_from, l_api_name);
      mydebug('  Date Required To    = ' || p_date_reqd_to, l_api_name);
      mydebug('  PickSlip Group Rule = ' || p_pick_slip_group_rule_id, l_api_name);
      mydebug('  Request ID          = ' || p_request_id, l_api_name);
    END IF;

    l_max_batch   := TO_NUMBER(fnd_profile.VALUE('INV_PICK_SLIP_BATCH_SIZE'));

    IF (l_debug = 1) THEN
      mydebug('Maximum Batch Size = ' || l_max_batch, l_api_name);
    END IF;

    IF l_max_batch IS NULL OR l_max_batch <= 0 THEN
      l_max_batch  := 20;

      IF (l_debug = 1) THEN
        mydebug('Using Default Batch Size 20', l_api_name);
      END IF;
    END IF;

    l_batch_size  := 0;

    --device integration starts
    IF (inv_install.adv_inv_installed(p_org_id) = TRUE) THEN --for WMS org
       IF wms_device_integration_pvt.wms_call_device_request IS NULL THEN

    IF (l_debug = 1) THEN
       mydebug('Setting global variable for device integration call', l_api_name);
    END IF;
    wms_device_integration_pvt.is_device_set_up(p_org_id,wms_device_integration_pvt.WMS_BE_MO_TASK_ALLOC,x_return_status);
       END IF;
    END IF;
    --device integration end

    FOR v_mo_header_rec IN c_move_order_header LOOP  -- Added 3772012
    BEGIN
     /*    FOR v_mo_line_rec IN c_move_order_lines(v_mo_header_rec.header_id, v_mo_header_rec.move_order_type) LOOP */
     --Start of new code to fix Bug# 4003379
     OPEN c_move_order_lines(v_mo_header_rec.header_id,
                             v_mo_header_rec.move_order_type,
                             l_max_batch); /* Changed from FOR loop Bug# 4003379 */
       LOOP
         FETCH c_move_order_lines INTO v_mo_line_rec;
         IF c_move_order_lines%NOTFOUND THEN
           CLOSE c_move_order_lines;
           COMMIT;
           l_batch_size := 0;
           EXIT;
         END IF;
     --END of new code added to fix Bug# 4003379
         l_batch_size       := l_batch_size + 1;
         IF v_mo_line_rec.header_id <> l_prev_header_id THEN
           l_prev_header_id := v_mo_line_rec.header_id;
           IF p_pick_slip_group_rule_id IS NOT NULL AND v_mo_line_rec.move_order_type IN (1,2) THEN
             IF l_debug = 1 THEN
               mydebug('New Header ID... So updating Pick Slip Grouping Rule', l_api_name);
             END IF;
             UPDATE mtl_txn_request_headers
             SET grouping_rule_id = p_pick_slip_group_rule_id
             WHERE header_id = v_mo_line_rec.header_id;
           END IF;
         END IF;

         SELECT decode(serial_number_control_code, 1, 'F', 'T'), tracking_quantity_ind
          INTO l_serial_flag, l_tracking_quantity_ind -- Bug 8985168
         FROM mtl_system_items
         WHERE inventory_item_id = v_mo_line_rec.inventory_item_id
         AND organization_id = p_org_id;

         SELECT mtl_material_transactions_s.NEXTVAL INTO l_txn_header_id FROM DUAL;

         inv_replenish_detail_pub.line_details_pub(
             x_return_status              => x_return_status,
             x_msg_count                  => l_msg_count,
             x_msg_data                   => l_msg_data,
             x_number_of_rows             => l_num_of_rows,
             x_detailed_qty               => l_detailed_qty,
             x_detailed_qty2              => l_secondary_detailed_qty, --INVCONV
             x_revision                   => l_revision,
             x_locator_id                 => l_from_loc_id,
             x_transfer_to_location       => l_to_loc_id,
             x_lot_number                 => l_lot_number,
             x_expiration_date            => l_expiration_date,
             x_transaction_temp_id        => l_transaction_temp_id,
             p_line_id                    => v_mo_line_rec.line_id,
             p_transaction_header_id      => l_txn_header_id,
             p_transaction_mode           => NULL,
             p_move_order_type            => v_mo_line_rec.move_order_type,
             p_serial_flag                => l_serial_flag,
             p_plan_tasks                 => p_plan_tasks,
             p_auto_pick_confirm          => FALSE
           );


         --
         -- Bug 8985168
         -- Handling the situation where the primary detailed quantity has become 0.
         IF l_debug = 1 THEN
           mydebug('l_tracking_quantity_ind     : ' || l_tracking_quantity_ind,l_api_name);
           mydebug('(1)l_detailed_qty           : ' || l_detailed_qty, l_api_name);
           mydebug('(1)l_secondary_detailed_qty : ' || l_secondary_detailed_qty, l_api_name);
         END IF;
         IF (l_tracking_quantity_ind = 'PS') THEN
            IF (l_detailed_qty = 0) THEN
               l_secondary_detailed_qty := 0;
            END IF;
            -- here theoretically we an raise an error if primary is NON zero while secondary is NULL or 0.
            -- but we will not raise this error at this time!
         ELSE
            l_secondary_detailed_qty := NULL;
         END IF;

         IF l_debug = 1 THEN
           mydebug('(2)l_detailed_qty           : ' || l_detailed_qty, l_api_name);
           mydebug('(2)l_secondary_detailed_qty : ' || l_secondary_detailed_qty, l_api_name);
         END IF;
         -- End Bug 8985168

         --Bug #4155230
         UPDATE mtl_txn_request_lines
         SET quantity_detailed = (NVL(quantity_delivered, 0) + l_detailed_qty),
             --secondary_quantity_detailed = decode(l_secondary_detailed_qty, 0, NULL, l_secondary_detailed_qty), --INVCONV
             secondary_quantity_detailed = NVL(secondary_quantity_delivered,0) + l_secondary_detailed_qty, -- Bug 8985168
             request_id = p_request_id /* Added the updation of request_id to fix Bug# 4003379 */
         WHERE line_id = v_mo_line_rec.line_id
         AND organization_id = p_org_id;

         IF l_debug = 1 THEN
           mydebug('Allocated MO Line = ' || v_mo_line_rec.line_id || ' : Qty Detailed = ' || l_detailed_qty, l_api_name);
         END IF;

         IF p_pick_slip_group_rule_id IS NOT NULL AND v_mo_line_rec.move_order_type IN (1,2) THEN
           -- Looping for each allocation of the MO Line for which Pick Slip Number is not stamped.
           FOR v_mmtt IN c_mmtt(v_mo_line_rec.line_id) LOOP
             inv_pr_pick_slip_number.get_pick_slip_number(
               x_api_status                 => x_return_status,
               x_error_message              => l_msg_data,
               x_pick_slip_number           => l_pick_slip_no,
               p_pick_grouping_rule_id      => p_pick_slip_group_rule_id,
               p_org_id                     => p_org_id,
               p_inventory_item_id          => v_mo_line_rec.inventory_item_id,
               p_revision                   => v_mmtt.revision,
               p_lot_number                 => NULL,
               p_src_subinventory           => v_mmtt.subinventory_code,
               p_src_locator_id             => v_mmtt.locator_id,
               p_supply_subinventory        => v_mmtt.transfer_subinventory,
               p_supply_locator_id          => v_mmtt.transfer_to_location,
               p_project_id                 => v_mo_line_rec.project_id,
               p_task_id                    => v_mo_line_rec.task_id,
               p_wip_entity_id              => NULL,
               p_rep_schedule_id            => NULL,
               p_operation_seq_num          => NULL,
               p_dept_id                    => NULL,
               p_push_or_pull               => NULL
             );

             UPDATE mtl_material_transactions_temp
             SET    pick_slip_number = l_pick_slip_no
             WHERE  transaction_temp_id = v_mmtt.transaction_temp_id;
           END LOOP;
         END IF;

      /*Bug#5140639. Commented the updation of 'distribution_account_id' in MMTT as
         it is already done in 'INV_Replenish_Detail_PUB.Line_Details_PUB' */

	    /* IF v_mo_line_rec.to_account_id IS NOT NULL THEN
           UPDATE mtl_material_transactions_temp
           SET distribution_account_id = v_mo_line_rec.to_account_id
           WHERE move_order_line_id = v_mo_line_rec.line_id;
         END IF;*/

         IF l_batch_size >= l_max_batch THEN
           IF (l_debug = 1) THEN
             mydebug('Current Batch Completed... Committing.',l_api_name);
           END IF;
           IF c_move_order_lines%ISOPEN THEN  --Added to fix Bug# 4003379
             CLOSE c_move_order_lines;
           END IF;
           COMMIT;
           OPEN c_move_order_lines(v_mo_header_rec.header_id,
                                   v_mo_header_rec.move_order_type,
                                   l_max_batch); --Changed from FOR loop bug 4003379

           l_batch_size  := 0;
         END IF;

       END LOOP;
     EXCEPTION -- Added 3772012
       WHEN record_locked THEN
         fnd_message.set_name('INV', 'INV_MO_LOCKED_SO');
         IF (l_debug = 1 ) THEN
           inv_log_util.TRACE('Lines for header '||v_mo_header_rec.header_id||' are locked', 'INV_UTILITIES', 9);
         END IF;
         fnd_msg_pub.ADD;
       END;
    END LOOP;

    IF (l_debug = 1) THEN
      inv_log_util.TRACE('calling Device Integration',l_api_name);
    END IF;
    -- Call Device Integration API to send the details of this
    -- PickRelease Wave for Move Order Allocation to devices, if it is a WMS organization.
    -- Note: We don't check for the return condition of this API as
    -- we let the Move Order Allocation  process succeed
    -- irrespective of DeviceIntegration succeed or fail.
    IF (wms_install.check_install(
      x_return_status   => x_return_status,
      x_msg_count       => l_msg_count,
      x_msg_data        => l_msg_data,
      p_organization_id => p_org_id
      ) = TRUE  ) THEN
       wms_device_integration_pvt.device_request(
         p_bus_event      => WMS_DEVICE_INTEGRATION_PVT.WMS_BE_MO_TASK_ALLOC,
         p_call_ctx       => WMS_Device_integration_pvt.DEV_REQ_AUTO,
         p_task_trx_id    => NULL,
         x_request_msg    => l_req_msg,
         x_return_status  => x_return_status,
         x_msg_count      => l_msg_count,
         x_msg_data       => l_msg_data);

       IF (l_debug = 1) THEN
         inv_log_util.TRACE('Device_API: returned status:'||x_return_status, l_api_name);
       END IF;
    END IF;

    IF c_move_order_lines%ISOPEN THEN  --Added to fix Bug# 4003379
      CLOSE c_move_order_lines;
    END IF;

    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      x_return_status := fnd_api.g_ret_sts_unexp_error;
      IF c_move_order_lines%ISOPEN THEN  --Added to fix Bug# 4003379
        CLOSE c_move_order_lines;
      END IF;
  END run_detail_engine;

  --------------------------------------------------------------------
  --  name:              print_move_order_traveler (copied from  INV_PICK_SLIP_REPORT.print_pick_slip)
  --  create by:         XXX
  --  Revision:          1.0
  --  creation date:     XX/XXX/XXXX
  --------------------------------------------------------------------
  --  purpose :          Oracle Hook package that we can change the code here.
  --------------------------------------------------------------------
  --  ver  date          name              desc
  --  1.0  XX/XXX/XXXX   XXX               initial build
  --------------------------------------------------------------------
  FUNCTION print_move_order_traveler( p_organization_id         VARCHAR2,
                            p_move_order_from         VARCHAR2,
                            p_move_order_to           VARCHAR2,
                            p_pick_slip_number_from   VARCHAR2,
                            p_pick_slip_number_to     VARCHAR2,
                            p_source_subinv           VARCHAR2,
                            p_source_locator          VARCHAR2,
                            p_dest_subinv             VARCHAR2,
                            p_dest_locator            VARCHAR2,
                            p_requested_by            VARCHAR2,
                            p_date_reqd_from          VARCHAR2,
                            p_date_reqd_to            VARCHAR2,
                            p_print_option            VARCHAR2,
                            p_print_mo_type           VARCHAR2,
                            p_sales_order_from        VARCHAR2,
                            p_sales_order_to          VARCHAR2,
                            p_ship_method_code        VARCHAR2,
                            p_customer_id             VARCHAR2,
                            p_auto_allocate           VARCHAR2,
                            p_plan_tasks              VARCHAR2,
                            p_pick_slip_group_rule_id VARCHAR2 ) RETURN NUMBER IS
    l_msg_data     varchar2(1000);
    l_msg_count    number;
    l_api_name     varchar2(30);
    l_debug        number;
    l_request_id   number;
    ------ Gary
    l_add_layout   boolean;
    ------ Dalit
    l_print_option boolean;
    l_printer_name varchar2(150);
    l_conc_prog_id number;
  BEGIN
    /* Initializing the default values */
    l_api_name := 'PRINT_MOVE_ORDER_TRAVELER';
    l_debug := NVL(fnd_profile.VALUE('INV_DEBUG_TRACE'), 0);



    -- Gary 18-JUN-2014  CHG0031940
    l_add_layout := fnd_request.add_layout(template_appl_name => 'INV',--'INV',
                                           template_code      => 'XXINV_MOVE_ORDER_TRAVELER',
                                           template_language  => 'en',
                                           template_territory => 'US',
                                           output_format      => 'PDF'
                                           );

    if not l_add_layout then
      l_debug := 1 ;
      l_api_name := l_api_name ||': '||' Can not add layout for XXWIPTOPKL';
    end if;
    -- end CHG0031940

    -- CHG0033284 Dalit A. Raviv 28/09/2014
    -- Get program id (program id can be different between environments on dev stage)
    begin
      select v.concurrent_program_id --, user_concurrent_program_name, v.concurrent_program_name
      into   l_conc_prog_id
      from   fnd_concurrent_programs_vl v
      where  v.concurrent_program_name  = 'XXWIPTOPKL';--'XX: Job Move Order Pick Slip'
    exception
      when others then
        l_conc_prog_id := null;
        l_printer_name := null;
    end;
    -- get printer name from set up - by organization
    -- the document set is set at "Implemetation" -> Order entry -> Shipping -> setup -> Documents -> Choose Printers
    -- Print the report only if the program for the organization is set here and it is default printer or is enable Y
    if l_conc_prog_id is not null then
      begin
        select wrp.printer_name
        into   l_printer_name
        from   wsh_report_printers       wrp
        where  wrp.level_value_id        = p_organization_id
        and    wrp.concurrent_program_id = l_conc_prog_id
        and    wrp.enabled_flag          = 'Y'
        and    wrp.default_printer_flag  = 'Y'
        and    wrp.level_type_id         = 10008;
      exception
        when others then
          l_printer_name := null;
      end;
    end if;
    -- Only if found printer then set print option to print 1 copy
    if l_printer_name is not null then
      l_print_option := fnd_request.set_print_options(printer     => l_printer_name,
                                                      copies      => 1,
                                                      save_output => TRUE);
      if not l_print_option then
        l_debug := 1;
        l_api_name := l_api_name ||': '||' Can not set print option, for printer: '||l_printer_name;
      end if;
    end if;
    l_request_id  := fnd_request.submit_request(
                       application => 'XXOBJT',    -- 'INV'          -- Gary 18-JUN-2014  CHG0031940
                       program     => 'XXWIPTOPKL',-- 'INVTOPKL_XML' -- Gary 18-JUN-2014  CHG0031940
                       description => NULL,
                       start_time  => NULL,
                       sub_request => FALSE,
                       argument1   => p_organization_id,
                       argument2   => p_move_order_from,
                       argument3   => p_move_order_to,
                       argument4   => p_pick_slip_number_from,
                       argument5   => p_pick_slip_number_to,
                       argument6   => p_source_subinv,
                       argument7   => p_source_locator,
                       argument8   => p_dest_subinv,
                       argument9   => p_dest_locator,
                       argument10  => p_requested_by,
                       argument11  => p_date_reqd_from,
                       argument12  => p_date_reqd_to,
                       argument13  => p_print_option,
                       argument14  => p_print_mo_type,
                       argument15  => p_sales_order_from,
                       argument16  => p_sales_order_to,
                       argument17  => p_ship_method_code,
                       argument18  => p_customer_id,
                       argument19  => p_auto_allocate,
                       argument20  => p_plan_tasks,
                       argument21  => p_pick_slip_group_rule_id );

    IF l_debug = 1 THEN
      mydebug('Request ID = ' || l_request_id, l_api_name);
    END IF;

    IF l_request_id = 0 THEN
       fnd_msg_pub.count_and_get(p_encoded=>fnd_api.g_false,p_data=>l_msg_data, p_count=>l_msg_count);
       IF l_debug = 1 THEN
         mydebug('Unable to submit the MO Pick Slip Request - ' || l_msg_data, l_api_name);
       END IF;
    END IF;

    RETURN l_request_id;
  END print_move_order_traveler;

  --------------------------------------------------------------------
  --  name:              update_print_events_dff
  --  created by:        Hubert, Eric
  --  Revision:          1.0
  --  creation date:     07-APR-2017
  --------------------------------------------------------------------
--    PRINT EVENT LOGGING
--    Business Requirement: update Move Order Line record to indicate that a Move
--    Order Traveler was physically printed for the move order line.  The definition
--    of "physcially printed" may need a more precise definition but in a crude 
--    sense, it means that the Printer <> "noprint" and Copies > 0.
--    
--    Business Reason:
--    This parameter controls whether previously-printed Move Order Travelers s
--    hould be printed.  The business needs to be able to know at a Move Order 
--    Line level if a Move Order Traveler has been printed for that line.  It is 
--    critical that the business not have two physical copies of this report on 
--    the ahop floor/warehouse at one time as this can lead to picking the same 
--    material twice and then getting system errors when the second document is 
--    attempted to be transacted.
--    
--    Technical Design:
--    DFF update: can INV_MOVE_ORDER_PUB be used for this?  It doesn't look like it.  Will need to update table directly.
--    
--    Technical Reference:
--        http://www.adivaconsulting.com/adiva-blog/item/6-datatemplate-part2
  --------------------------------------------------------------------
  --  ver  date          name              desc
  --  1.0  XX/XXX/XXXX   XXX               initial build
  --------------------------------------------------------------------
    PROCEDURE update_print_events_dff (
        p_move_order_line_id_in IN NUMBER
        , p_return_status_out OUT VARCHAR2
        ) 
    IS
        C_PRINT_EVENT_DELIMITER CONSTANT VARCHAR2(1) := ';'; --Separates individual print events in the DFF
        C_FIELD_DELIMITER CONSTANT VARCHAR2(1) := '/'; --Separates fields within a print event (Printed Date and Concurrent Request ID)
        C_DATETIME_FORMAT CONSTANT VARCHAR2(100) := 'DD-MON-YYYY HH24:MI:SS'; --Format of the Date/Time that is wriiten to the DFF
        C_PRINT_EVENT_DFF_COLUMN CONSTANT VARCHAR2(30) := 'ATTRIBUTE3';  --Descriptive Flex Field column in MTL_TXN_REQUEST_LINES
    
        l_old_dff_value VARCHAR2(150);
        l_new_dff_value VARCHAR2(150);
        l_temp VARCHAR2(150);
        move_order_line_record mtl_txn_request_lines%ROWTYPE;
        
        BEGIN
        /* Get the Move Order Line record. */
        SELECT * INTO move_order_line_record 
        FROM mtl_txn_request_lines
        WHERE line_id = p_move_order_line_id_in;
        
        /* Build new Print Event string. */
        l_temp := TO_CHAR(SYSDATE, C_DATETIME_FORMAT); 
        l_temp := l_temp || C_FIELD_DELIMITER;
        l_temp := l_temp || fnd_global.conc_request_id;
        l_temp := l_temp || C_PRINT_EVENT_DELIMITER;
        
        /* Manipulate the Print Events DFF value. */
        l_old_dff_value := move_order_line_record.attribute3;
        l_new_dff_value := l_temp;

        /* Assign new values. */
        move_order_line_record.attribute3 := l_temp;
        move_order_line_record.last_updated_by := fnd_profile.VALUE ('USER_ID');
        move_order_line_record.last_update_date := SYSDATE;
        move_order_line_record.last_update_login := USERENV ('SESSIONID');

        /* Update the Move Order Line. */
        UPDATE mtl_txn_request_lines 
        SET ROW = move_order_line_record 
        WHERE line_id = p_move_order_line_id_in; 
        
        p_return_status_out := 'SUCCESS';
        
    EXCEPTION
        WHEN
            OTHERS THEN
            NULL;
            p_return_status_out := 'FAILED';
    END;
END XXINV_MOVE_ORDER_TRAVELER_PKG;
/