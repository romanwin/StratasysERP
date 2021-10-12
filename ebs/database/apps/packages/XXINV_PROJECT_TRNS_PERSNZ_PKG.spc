create or replace PACKAGE      XXINV_PROJECT_TRNS_PERSNZ_PKG AS
--------------------------------------------------------------------------------------------------
/*
$Revision:   1.0  $
Package Name:    XXINV_PROJECT_TRNS_PERSNZ_PKG.spc
Author's Name:   Sandeep Akula
Date Written:    03-JUN-2014
Purpose:         Used in Inventory Personalizations for Project related Transactions 
Program Style:   Stored Package Spec
Called From:
Calls To:
Maintenance History:
Date:          Version                   Name            Remarks
-----------    ----------------         -------------   ------------------
03-JUN-2014        1.0                  Sandeep Akula    Initial Version 
---------------------------------------------------------------------------------------------------*/

/* Checks if Project Task is Capital */
FUNCTION PROJ_TASK_CAPITALIZABLE_FLAG(P_PROJECT_ID IN NUMBER,
                                      P_TASK_ID IN NUMBER)
RETURN VARCHAR2;

/* Returns Code Combination Id of Account 26.000.181210.000.000.00.000.0000 */
FUNCTION SSUS_GET_ACCOUNT_STRING_ID
RETURN NUMBER;

/* Dervies Individual Segments from the Accounting String and performs custom validations */
FUNCTION SSUS_VALIDATE_DEPT_ACCOUNT(P_ACCT_STRING IN VARCHAR2)
RETURN VARCHAR2;

/* Return text stored in Message XXINV_PA_CAPITAL_PROJECT_MSG */
FUNCTION SSUS_CAPITAL_PROJECT_MSG
RETURN VARCHAR2;

/* Return text stored in Message XXINV_PA_NONCAPITAL_PROJ_MSG */
FUNCTION SSUS_NON_CAPITAL_PROJECT_MSG
RETURN VARCHAR2;

/* Dervies the Accounting Flex Field Structure based on the Inventory Organization Id.
Returns Y if structure name is XX_STRATASYS_USD else return N */
FUNCTION SSUS_VALIDATE_ACCTFLEX_STRUC(p_inventory_org_id IN NUMBER)
RETURN VARCHAR2;

END XXINV_PROJECT_TRNS_PERSNZ_PKG;
/
