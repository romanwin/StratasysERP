create or replace PACKAGE  APPS.XXPA_CIP_BAL_PKG IS
--------------------------------------------------------------------------------------------------
/*
$Revision:   1.0  $
Package Name:    XXPA_CIP_BAL_PKG.spc
Author's Name:   Sandeep Akula
Date Written:    19-MAY-2014
Purpose:         Find Various Column Values for XX: PA CIP Balances (EXCEL)
Program Style:   Stored Package SPECIFICATION
Called From:
Calls To:
Maintenance History:
Date:          Version                   Name            Remarks
-----------    ----------------         -------------   ------------------
19-MAY-2014        1.0                  Sandeep Akula    Initial Version
26-JUN-2014        1.1                  Sandeep Akula    Added Functions GET_CIP_ADDITIONS and GET_TRANSFER_TO_FA (CHG0032482) 
---------------------------------------------------------------------------------------------------*/
P_REQUEST_ID       NUMBER := FND_GLOBAL.CONC_REQUEST_ID;
P_PERIOD VARCHAR2(100);
P_PROJECT_ID NUMBER;
P_PROJECT_TYPE VARCHAR2(200);
P_ACCOUNT VARCHAR2(100);
P_COMPANY VARCHAR2(100);
P_ORGANIZATION NUMBER;
P_PROJECT_STATUS VARCHAR2(30);

FUNCTION GET_BEGINNING_BALANCE(P_PROJECT_ID IN NUMBER,
                               P_CCID IN NUMBER,
                               P_GL_PERIOD IN VARCHAR2)
RETURN NUMBER;

FUNCTION GET_CIP_ADDITIONS(P_PROJECT_ID IN NUMBER,
                           P_CCID IN NUMBER,
                           P_GL_PERIOD IN VARCHAR2)
RETURN NUMBER;

FUNCTION GET_TRANSFER_TO_FA(P_PROJECT_ID IN NUMBER,
                            P_CCID IN NUMBER,
                            P_GL_PERIOD IN VARCHAR2)
RETURN NUMBER;

FUNCTION AFTERPFORM RETURN BOOLEAN;

FUNCTION BEFOREREPORT RETURN BOOLEAN ;

FUNCTION AFTERREPORT RETURN BOOLEAN;

END XXPA_CIP_BAL_PKG;
/
