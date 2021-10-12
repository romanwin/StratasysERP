create or replace package xxhr_send_mail_pkg AUTHID CURRENT_USER is
  
--------------------------------------------------------------------
--  name:            XXHR_SEND_MAIL_PKG
--  create by:       Dalit A. Raviv
--  Revision:        1.1 
--  creation date:   27/10/2011 
--------------------------------------------------------------------
--  purpose :        HR project - Handle send mail cases
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  27/01/2011  Dalit A. Raviv    initial build
--  1.1  27/06/2013  Dalit A. Raviv    Handle HR packages and apps_view
--                                     add AUTHID CURRENT_USER to spec
--------------------------------------------------------------------  

  --------------------------------------------------------------------
  --  name:            mng_note_on_empl_birthday
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   27/10/2011
  --------------------------------------------------------------------
  --  purpose:         
  --  In  Params:      
  --  Out Params:      
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  27/01/2011  Dalit A. Raviv    initial build
  --------------------------------------------------------------------  
  procedure mng_note_on_empl_birthday (errbuf   out varchar2,  
                                       retcode  out varchar2);
                                       
  --------------------------------------------------------------------
  --  name:            get_footer_html
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   30/10/2011
  --------------------------------------------------------------------
  --  purpose:         
  --  In  Params:      
  --  Out Params:      
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  30/10/2011  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  function get_footer_html return varchar2;   
  
  --------------------------------------------------------------------
  --  name:            get_footer_html_birthday
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   06/11/2011
  --------------------------------------------------------------------
  --  purpose:         
  --  In  Params:      
  --  Out Params:      
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  06/11/2011  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  function get_footer_html_birthday return varchar2;                                    

end XXHR_SEND_MAIL_PKG;

 
/
