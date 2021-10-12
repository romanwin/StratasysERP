create or replace PACKAGE XXINV_LOT_UPDATE_PKG IS
  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Package Name:    XXINV_LOT_UPDATE_PKG.spc
  Author's Name:   Sandeep Akula
  Date Written:    16-SEP-2015
  Purpose:         Update Lot DFF (Country of Origin - Attribute1)
  Program Style:   Stored Package SPECIFICATION
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  16-SEP-2015        1.0                  Sandeep Akula    Initial Version (CHG0036196)
  ---------------------------------------------------------------------------------------------------*/
  g_curr_request_id NUMBER := fnd_global.conc_request_id;
 
PROCEDURE update_lot_dff(errbuf OUT VARCHAR2,
                         retcode OUT NUMBER,
                         p_backward_days IN NUMBER); 
 
END XXINV_LOT_UPDATE_PKG;
/
