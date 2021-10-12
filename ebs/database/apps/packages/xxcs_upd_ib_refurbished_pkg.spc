create or replace package XXCS_UPD_IB_REFURBISHED_PKG is

--------------------------------------------------------------------
--  name:            XXCS_UPD_IB_REFURBUSHED_PKG 
--  create by:       Dalit A. Raviv
--  Revision:        1.0
--  creation date:   28/02/2010
--------------------------------------------------------------------
--  purpose :        Set Refurbished flag to YES in case of Refurbish SR existance
--                   benefit - Identify refurbish printers in IB
--                   Create program that based on reate_extended_attrib_values API
--                   to update IB in case of existing SR
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  28/02/2010  Dalit A. Raviv    initial build
--------------------------------------------------------------------  
  
  
  --------------------------------------------------------------------
  --  name:            upd_ib_refurbished_flag 
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   28/02/2010
  --------------------------------------------------------------------
  --  purpose :        Procedure that will be called from concurrent
  --                   will run each day periodic (one time each day).
  --                   Program will locate population to update, call 
  --                   API to update refurbished flag at IB.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  28/02/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------  
  procedure upd_ib_refurbished_flag (errbuf  OUT VARCHAR2,
                                     retcode OUT VARCHAR2);

  procedure internet_sample (errbuf  OUT VARCHAR2,
                             retcode OUT VARCHAR2);
                             
end XXCS_UPD_IB_REFURBISHED_PKG;
/

