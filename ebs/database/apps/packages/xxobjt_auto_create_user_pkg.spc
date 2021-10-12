create or replace package apps.xxobjt_auto_create_user_pkg is

--------------------------------------------------------------------
--  name:            XXOBJT_AUTO_CREATE_USER_PKG
--  create by:       Dalit A. Raviv
--  Revision:        1.0
--  creation date:   06/09/2012 09:30:07
--------------------------------------------------------------------
--  purpose :        CUST530 - Automatic creation of oracle user
--
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  06/09/2012  Dalit A. Raviv    initial build
--  1.1  27/11/2012  Dalit A. Raviv    Add procedure main_update
-------------------------------------------------------------------- 
                       
  --------------------------------------------------------------------
  --  name:            main
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   06/09/2012
  --------------------------------------------------------------------
  --  purpose :        CUST530 - Automatic creation of oracle user
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  06/09/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure main (errbuf    out varchar2,
                  retcode   out varchar2);
  
  --------------------------------------------------------------------
  --  name:            main_update
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   27/11/2012 
  --------------------------------------------------------------------
  --  purpose :        CUST530 - Automatic creation of oracle user
  --                  
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  27/11/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  Procedure main_update (errbuf    out varchar2,
                         retcode   out varchar2);
    
  --------------------------------------------------------------------
  --  name:            prepare_log_body
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   12/09/2012
  --------------------------------------------------------------------
  --  purpose :        CUST530 - Automatic creation of oracle user
  --                   Prepare the body of the mail send to Helpdesk
  --                   with all persons that did not create oracle User.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  06/09/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure prepare_log_body (p_document_id   in varchar2,
                              p_display_type  in varchar2,
                              p_document      in out clob,
                              p_document_type in out varchar2);
                                            
  --------------------------------------------------------------------
  --  name:            send_log_mail
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   06/09/2012
  --------------------------------------------------------------------
  --  purpose :        CUST530 - Automatic creation of oracle user
  --                  
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  06/09/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure send_log_mail (p_batch_id in  number,
                           errbuf     out varchar2,
                           retcode    out varchar2);
  
  --------------------------------------------------------------------
  --  name:            get_resp_name
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   10/09/2012
  --------------------------------------------------------------------
  --  purpose :        CUST530 - Automatic creation of oracle user
  --                   determine the Territory to add to the responsibility
  --                   Internet expense to add
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  10/09/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  function get_resp_name(p_territory in varchar2,
                         p_person_id in number) return varchar2;
                         
  --------------------------------------------------------------------
  --  name:            get_person_short_territory
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   09/09/2012
  --------------------------------------------------------------------
  --  purpose :        CUST530 - Automatic creation of oracle user
  --                   By person id get the organization from assignment 
  --                   and from organization get the territory.
  --
  --  Return:          Territory suffix - IL, AP, EU, US etc'
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  09/09/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  function get_person_short_territory(p_person_id in number) return varchar2 ;
                            
end xxobjt_auto_create_user_pkg;
/
