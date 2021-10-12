create or replace package XXFA_UTILS_PKG is
  --------------------------------------------------------------------
  --  name:            XXFA_UTILS_PKG
  --  create by:       Suad Ofer
  --  Revision:        1.1
  --  creation date:   25/05/2020 11:26:48
  --------------------------------------------------------------------
  --  purpose :        Fix asset module utils 

  -------------------------------------------------------------------------------
  -- Ver   When         Who          Descr 
  -- ----  -----------  -----------  --------------------------------------------
  -- 1.0   25/05/2020   Ofer Suad    CHG0047953  - Create set to run whatif 
  --                                      program for all ledgers in one program
  -------------------------------------------------------------------------------
  Procedure submit_whatif_set(errbuf  IN OUT VARCHAR2,
                              retcode IN OUT VARCHAR2,
                              p_year  number);

end XXFA_UTILS_PKG;
/
