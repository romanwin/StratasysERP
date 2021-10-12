CREATE OR REPLACE PACKAGE BODY APPS.XXPO_QUOTE_ANALYSIS_PKG IS 
--------------------------------------------------------------------------------------------------
/*
$Revision:   1.0  $
Package Name:    XXPO_QUOTE_ANALYSIS_PKG.pkb    
Author's Name:   Sandeep Akula   
Date Written:    27-FEB-2014
Purpose:         Find Various Column Values for XX: PO Quote Analysis Report
Program Style:   Stored Package Body
Called From:
Calls To:
Maintenance History:
Date:          Version                   Name            Remarks
-----------    ----------------         -------------   ------------------
27-FEB-2014        1.0                  Sandeep Akula    Initial Version
---------------------------------------------------------------------------------------------------*/
FUNCTION AFTERPFORM RETURN BOOLEAN IS
begin

 IF P_ITEM_ID IS NULL THEN
      C_WHERE_ITEM := 'AND 4 = 4';
  ELSE
      C_WHERE_ITEM := 'AND LINE.ITEM_ID = :P_ITEM_ID';
  END IF;

  IF P_VENDOR_ID IS NULL THEN
      C_WHERE_VENDOR := 'AND 1 = 1';
  ELSE
      C_WHERE_VENDOR := 'AND HEADER.VENDOR_ID = :P_VENDOR_ID';
  END IF;
  
  IF P_AGENT_ID IS NULL THEN
      C_WHERE_BUYER := 'AND 2 = 2';
  ELSE
      C_WHERE_BUYER := 'AND HEADER.AGENT_ID = :P_AGENT_ID';
  END IF;
   
  IF P_HEADER_ID IS NULL THEN 
      C_WHERE_QUOTATION := 'AND 3 = 3';
  ELSE
      C_WHERE_QUOTATION := 'AND HEADER.MAIN_HEADER_ID = :P_HEADER_ID';
  END IF; 
  
  IF P_PROJECT_ID IS NULL THEN
      C_WHERE_PROJECT := 'AND 5 = 5';
  ELSE
      C_WHERE_PROJECT := 'AND LINE.PROJECT_ID = :P_PROJECT_ID';
  END IF;
  
  IF P_SHIP_TO_LOCATION_ID IS NULL THEN
      C_WHERE_SHIP_TO_LOCATION_CODE := 'AND 6 = 6';
  ELSE
      C_WHERE_SHIP_TO_LOCATION_CODE := 'AND HEADER.SHIP_TO_LOCATION_ID = :P_SHIP_TO_LOCATION_ID';
  END IF; 
  
return (TRUE);
END AFTERPFORM; 

FUNCTION BEFOREREPORT RETURN BOOLEAN  IS
begin
null;
return (TRUE);
END BEFOREREPORT;

FUNCTION AFTERREPORT RETURN BOOLEAN IS
BEGIN
null;
return (TRUE);
END AFTERREPORT;                             
END XXPO_QUOTE_ANALYSIS_PKG;
/