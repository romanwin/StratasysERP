create or replace PACKAGE      XXGL_CONCUR_INBOUND_PKG IS 
--------------------------------------------------------------------------------------------------
/*
$Revision:   1.0  $
Package Name:    XXGL_CONCUR_INBOUND_PKG.spc
Author's Name:   Sandeep Akula
Date Written:    07-OCT-2014
Purpose:         Concur Expenses Validation Package
Program Style:   Stored Package SPECIFICATION
Called From:
Calls To:
Maintenance History:
Date:          Version                   Name            Remarks
-----------    ----------------         -------------   ------------------
07-OCT-2014        1.0                  Sandeep Akula    Initial Version (CHG0033357)
07-JUL-2015        1.1                  Sandeep Akula    Added New Functions COMPANY_EXISTS_CNT, GET_LEDGER_NAME and GET_LIABILITY_ACCOUNT to the Package -- CHG0035548
---------------------------------------------------------------------------------------------------*/
FUNCTION COMPANY_EXISTS_CNT(p_company IN VARCHAR2)
RETURN VARCHAR2;

FUNCTION GET_LEDGER_NAME(p_company IN VARCHAR2)
RETURN VARCHAR2;

FUNCTION GET_LIABILITY_ACCOUNT(p_company IN VARCHAR2)
RETURN VARCHAR2;

PROCEDURE MAIN(errbuf OUT VARCHAR2,
               retcode OUT NUMBER,
               p_file_name IN VARCHAR2,
               p_bpel_instance_id IN NUMBER);

PROCEDURE CONCUR_INTF_DATAPURGE(errbuf OUT VARCHAR2,
                                retcode OUT NUMBER,
                                p_retention_period IN NUMBER);

END XXGL_CONCUR_INBOUND_PKG;
/

