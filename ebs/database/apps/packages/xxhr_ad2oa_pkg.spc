create or replace package xxhr_ad2oa_pkg is
  
--------------------------------------------------------------------
--  name:            XXHR_AD2OA_PKG
--  create by:       Dalit A. Raviv
--  Revision:        1.0
--  creation date:   09/07/2013 13:48:31
--------------------------------------------------------------------
--  purpose :        CUST677 - AD email address to oracle - prog
--
--                   This Package handle Active directory interface to Oracle
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  09/07/2013  Dalit A. Raviv    initial build
--------------------------------------------------------------------
  
  --------------------------------------------------------------------
  --  name:            get_details_from_ad
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   09/07/2013 
  --------------------------------------------------------------------
  --  purpose :        open session to AD, ask AD for specific attributes 
  --                   per person.                  
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  09/07/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure get_details_from_ad(errbuf        out    varchar2, 
                                retcode       out    varchar2,
                                p_last_name   out    varchar2,
                                p_first_name  out    varchar2,
                                p_emp_num     in out varchar2,  
                                p_mail        out    varchar2
                                );

  procedure main (errbuf        out varchar2, 
                  retcode       out varchar2) ;

end xxhr_ad2oa_pkg;
/
