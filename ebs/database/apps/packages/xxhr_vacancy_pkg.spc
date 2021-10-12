create or replace package xxhr_vacancy_pkg is

--------------------------------------------------------------------
--  name:            XXHR_VACANCY_PKG
--  create by:       Dalit A. Raviv
--  Revision:        1.0
--  creation date:   17/07/2013 10:44:43
--------------------------------------------------------------------
--  purpose :        
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  17/07/2013  Dalit A. Raviv    initial build
--------------------------------------------------------------------

  --------------------------------------------------------------------
  --  name:            get_request_message_clob
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   03/12/2012
  --------------------------------------------------------------------
  --  purpose :        
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  03/12/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure get_request_message_clob(document_id   in            varchar2,
                                     display_type  in            varchar2,
                                     document      in out nocopy clob,
                                     document_type in out nocopy varchar2);

end XXHR_VACANCY_PKG;
/
