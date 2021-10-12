create or replace package XXCS_EXT_ATT_VALUE_IN_BI_PKG is

--------------------------------------------------------------------
--  name:            XXCS_UPD_IB_REFURBUSHED_PKG 
--  create by:       Dalit A. Raviv
--  Revision:        1.0
--  creation date:   28/02/2010
--------------------------------------------------------------------
--  purpose :        Set Extra attributes value In BI 
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  28/02/2010  Dalit A. Raviv    initial build
--  1.1  08/03/2010  Dalit A. Raviv    add 2 procedures - main , create_FCO_Date
--------------------------------------------------------------------  
  
  
  --------------------------------------------------------------------
  --  name:            upd_ib_refurbished_flag 
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   28/02/2010
  --------------------------------------------------------------------
  --  purpose :        Program will locate population to update, call 
  --                   API to update refurbished flag at IB.
  --                   Set Refurbished flag to YES in case of Refurbish SR existance
  --                   benefit - Identify refurbish printers in IB
  --                   Create program that based on reate_extended_attrib_values API
  --                   to update IB in case of existing SR
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  28/02/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------  
  procedure upd_ib_refurbished_flag (p_error_desc OUT VARCHAR2,
                                     p_error_code OUT VARCHAR2);

  --------------------------------------------------------------------
  --  name:            create_FCO_Date
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   08/03/2010
  --------------------------------------------------------------------
  --  purpose :        Call API to update refurbished flag at IB.
  --                   Set FCO date according to closure date of SR.
  --                   Create program that based on create_extended_attrib_values API
  --                   to update IB in case of existing SR
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  08/03/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------  
  procedure create_FCO_Date         (p_error_desc OUT VARCHAR2,
                                     p_error_code OUT VARCHAR2);
                             
  --------------------------------------------------------------------
  --  name:            main
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   08/03/2010
  --------------------------------------------------------------------
  --  purpose :        Procedure that will be called from concurrent
  --                   will run each day periodic (one time each day).
  --                   will call to refurbish procedure and FCO Date procedure
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  08/03/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------  
  Procedure main                    (errbuf       OUT VARCHAR2,
                                     retcode      OUT VARCHAR2);                            
  
  procedure internet_sample (errbuf  OUT VARCHAR2,
                             retcode OUT VARCHAR2);
                             
end XXCS_EXT_ATT_VALUE_IN_BI_PKG;
/

