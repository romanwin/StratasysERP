create or replace PACKAGE XXGL_ESSBASE_OUTBOUND_PKG IS
--------------------------------------------------------------------------------------------------
/*
$Revision:   1.0  $
Package Name:    XXGL_ESSBASE_OUTBOUND_PKG.spc
Author's Name:   Sandeep Akula
Date Written:    28-MAY-2015
Purpose:         Send GL Balances to Essbase
Program Style:   Stored Package SPECIFICATION
Called From:
Calls To:
Maintenance History:
Date:          Version                   Name            Remarks
-----------    ----------------         -------------   ------------------
28-MAY-2015        1.0                  Sandeep Akula    Initial Version (CHG0034720)
---------------------------------------------------------------------------------------------------*/
P_CURR_REQUEST_ID       NUMBER := FND_GLOBAL.CONC_REQUEST_ID;

FUNCTION CHECK_ACCOUNT_IN_VALUESET(p_account IN VARCHAR2)
RETURN VARCHAR2;

PROCEDURE MAIN(errbuf OUT VARCHAR2,
               retcode OUT NUMBER,
               p_dir IN VARCHAR2,
               p_balance_type IN VARCHAR2,
               p_period_from IN VARCHAR2,
               p_period_to IN VARCHAR2,
               p_spool_output IN VARCHAR2);

END XXGL_ESSBASE_OUTBOUND_PKG;
/


