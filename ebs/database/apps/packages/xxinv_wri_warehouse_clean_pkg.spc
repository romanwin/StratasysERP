create or replace package XXINV_WRI_WAREHOUSE_CLEAN_PKG is

-----------------------------------------------------------------------
--  customization code: CUST331 - WRI Warehouse clean up
--  name:               XXINV_WRI_WAREHOUSE_CLEAN_PKG
--  create by:          Dalit A. Raviv
--  $Revision:          1.0 $
--  creation date:      13/06/2010 1:44:58 PM
--  Purpose :           Package that handle - wri warehouse clean up
--                      
-----------------------------------------------------------------------
--  ver   date          name            desc
--  1.0   13/06/2010    Dalit A. Raviv  initial build
----------------------------------------------------------------------- 

  -----------------------------------------------------------------------
  --  customization code: CUST331 - WRI Warehouse clean up
  --  name:               WRI_warehouse_clean_up
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0 $
  --  creation date:      13/06/2010
  --  Purpose :           Procedure that handle - wri warehouse clean up
  --                      
  -----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   13/06/2010    Dalit A. Raviv  initial build
  ----------------------------------------------------------------------- 
  procedure WRI_warehouse_clean_up (errbuf  out varchar2, 
                                    retcode out varchar2);

end XXINV_WRI_WAREHOUSE_CLEAN_PKG;
/

