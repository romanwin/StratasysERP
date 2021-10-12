CREATE OR REPLACE PACKAGE APPS.XXPO_QUOTE_ANALYSIS_PKG IS
--------------------------------------------------------------------------------------------------
/*
$Revision:   1.0  $
Package Name:    XXPO_QUOTE_ANALYSIS_PKG.pks
Author's Name:   Sandeep Akula
Date Written:    27-FEB-2014
Purpose:         Find Various Column Values for XX: PO Quote Analysis Report
Program Style:   Stored Package SPECIFICATION
Called From:
Calls To:
Maintenance History:
Date:          Version                   Name            Remarks
-----------    ----------------         -------------   ------------------
27-FEB-2014        1.0                  Sandeep Akula    Initial Version
---------------------------------------------------------------------------------------------------*/
P_REQUEST_ID       NUMBER := FND_GLOBAL.CONC_REQUEST_ID;
P_ITEM_ID       NUMBER;
P_VENDOR_ID  NUMBER;
P_AGENT_ID         NUMBER;
P_PROJECT_ID       NUMBER;
P_HEADER_ID       NUMBER;
P_SHIP_TO_LOCATION_ID NUMBER;
P_ORG_ID       NUMBER;
C_WHERE_VENDOR   VARCHAR2(500);
C_WHERE_BUYER   VARCHAR2(500);
C_WHERE_QUOTATION   VARCHAR2(500);
C_WHERE_ITEM   VARCHAR2(500);
C_WHERE_PROJECT   VARCHAR2(500);
C_WHERE_SHIP_TO_LOCATION_CODE   VARCHAR2(500);

FUNCTION AFTERPFORM RETURN BOOLEAN;

FUNCTION BEFOREREPORT RETURN BOOLEAN ;

FUNCTION AFTERREPORT RETURN BOOLEAN;

END XXPO_QUOTE_ANALYSIS_PKG;
/
