create or replace package XXHR_PERSON_PERFORMANCE_PKG is

--------------------------------------------------------------------
--  name:            XXHR_PERSON_PERFORMANCE_PKG
--  create by:       Dalit A. Raviv
--  Revision:        1.0 
--  creation date:   29/12/2010 
--------------------------------------------------------------------
--  purpose :        HR project - Handle upload of employee performance
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  29/12/2010   Dalit A. Raviv    initial build
--------------------------------------------------------------------     
  
  --------------------------------------------------------------------
  --  name:            main
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   29/12/2010 
  --------------------------------------------------------------------
  --  purpose :        Main procedure that run the program
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  29/12/2010   Dalit A. Raviv    initial build
  --------------------------------------------------------------------   
  procedure main (errbuf      out varchar2,
                  retcode     out varchar2,
                  p_location  in  varchar2,
                  p_filename  in  varchar2,
                  p_token     in  varchar2);
                  
end XXHR_PERSON_PERFORMANCE_PKG;
/

