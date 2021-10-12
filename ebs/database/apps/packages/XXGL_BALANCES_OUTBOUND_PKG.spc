create or replace PACKAGE XXGL_BALANCES_OUTBOUND_PKG IS
--------------------------------------------------------------------------------------------------
/*
$Revision:   1.0  $
Package Name:    XXGL_BALANCES_OUTBOUND_PKG.spc
Author's Name:   Sandeep Akula
Date Written:    28-JULY-2014
Purpose:         Send GL Balances to Blackline for Account Reconciliation
Program Style:   Stored Package SPECIFICATION
Called From:
Calls To:
Maintenance History:
Date:          Version                   Name            Remarks
-----------    ----------------         -------------   ------------------
28-JULY-2014        1.0                  Sandeep Akula    Initial Version (CHG0032798)
17-NOV-2014         1.1                  Sandeep Akula    Added Procedure SUBLEDGER_MAIN (CHG0033074)
---------------------------------------------------------------------------------------------------*/
P_CURR_REQUEST_ID       NUMBER := FND_GLOBAL.CONC_REQUEST_ID;

PROCEDURE INSERT_GL_BAL_RUNTIME_DATA(P_SOURCE IN VARCHAR2,
P_REQUEST_ID IN NUMBER,
P_PROGRAM_SHORT_NAME IN VARCHAR2,
P_REQUESTER IN VARCHAR2 DEFAULT NULL,
P_FILE_NAME IN VARCHAR2 DEFAULT NULL,
P_EXTRACT_DATE IN VARCHAR2 DEFAULT NULL,
P_LINES_EXTRACTED IN NUMBER DEFAULT NULL,
P_FILE_DIRECTORY IN VARCHAR2 DEFAULT NULL,
P_ATTRIBUTE1 IN VARCHAR2 DEFAULT NULL,
P_ATTRIBUTE2 IN VARCHAR2 DEFAULT NULL,
P_ATTRIBUTE3 IN VARCHAR2 DEFAULT NULL,
P_ATTRIBUTE4 IN VARCHAR2 DEFAULT NULL,
P_OUT_MSG OUT VARCHAR2);

PROCEDURE MAIN(errbuf OUT VARCHAR2,
               retcode OUT NUMBER,
               p_data_dir IN VARCHAR2,
               p_period_name IN VARCHAR2);
               
PROCEDURE SUBLEDGER_MAIN(errbuf OUT VARCHAR2,
                         retcode OUT NUMBER,
                         p_data_dir IN VARCHAR2,
                         p_period_name IN VARCHAR2);               

END XXGL_BALANCES_OUTBOUND_PKG;
/


