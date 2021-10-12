create or replace PACKAGE      XXINV_K2_ITEM_OUTBOUND_PKG IS
--------------------------------------------------------------------------------------------------
/*
$Revision:   1.0  $
Package Name:    XXINV_K2_ITEM_OUTBOUND_PKG.spc
Author's Name:   Sandeep Akula
Date Written:    8-JULY-2014
Purpose:         Used in K2 Item Outbound Program
Program Style:   Stored Package SPECIFICATION
Called From:
Calls To:
Maintenance History:
Date:          Version                   Name            Remarks
-----------    ----------------         -------------   ------------------
8-JULY-2014        1.0                  Sandeep Akula    Initial Version
---------------------------------------------------------------------------------------------------*/
PROCEDURE MAIN(errbuf OUT VARCHAR2,
               retcode OUT NUMBER,
               p_data_dir IN VARCHAR2,
               p_inv_org IN NUMBER,
               p_override_last_run_date IN VARCHAR2);

END XXINV_K2_ITEM_OUTBOUND_PKG;