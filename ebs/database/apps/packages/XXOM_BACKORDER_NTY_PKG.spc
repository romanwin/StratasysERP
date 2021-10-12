CREATE OR REPLACE PACKAGE XXOM_BACKORDER_NTY_PKG is

----------------------------------------------------------
  -- Author  : PIYALI.BHOWMICK
  -- Created : 09/11/2017 12:45:36
  -- Purpose :To send notification to the order creator in case of 
  --          backorder.   
  -- ---------------------------------------------------------
  --------------------------------------------------------------------------
  -- Version  Date      Performer             Comments
  ----------  --------  --------------       -------------------------------------
  --
  --   1.1    9.11.2017     Piyali Bhowmick     CHG0041696 - Initial Build 
  ------------------------------------------------------------------------------------

  --------------------------------------------------------------------
  --  name:            process_events
  --  create by:       Piyali Bhowmick
  --  Revision:        1.0
  --  creation date:   09/11/2017 12:45:36
  --------------------------------------------------------------------
  --  purpose : To update the staging table xxssys_events and send notification to 
  --            order creator in case of back ordered lines. 
  --------------------------------------------------------------------
  --   1.0    7.8.2017    Piyali Bhowmick      CHG0041696 -To update the staging table xxssys_events and send notification to 
  --                                           order creator in case of back ordered lines.   
  ------------------------------------------------------------------------------------------

   PROCEDURE process_events(l_retcode OUT  VARCHAR2, 
                          l_errbuf OUT  VARCHAR2);
 
    --------------------------------------------------------------------
  --  name:             backorder_details
  --  create by:       Piyali Bhowmick
  --  Revision:        1.0
  --  creation date:   09/11/2017 12:45:36
  --------------------------------------------------------------------
  --  purpose :   To get the order details as well as the line details of 
  --              those lines which are backordered 
  --------------------------------------------------------------------
  --   1.0    7.8.2017    Piyali Bhowmick      CHG0041696 -   To get the order details as well as the line details of 
  --                                                  those lines which are backordered 
  -----------------------------------------------------------------------------------------
    
   PROCEDURE backorder_details(document_id   IN VARCHAR2,
                             display_type  IN VARCHAR2,
                             document      IN OUT CLOB,
                             document_type IN OUT VARCHAR2);

                                                                
end XXOM_BACKORDER_NTY_PKG;