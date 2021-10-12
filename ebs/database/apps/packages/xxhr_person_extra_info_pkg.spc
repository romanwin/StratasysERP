create or replace package xxhr_person_extra_info_pkg AUTHID CURRENT_USER is

--------------------------------------------------------------------
--  name:              XXHR_PERSON_EXTRA_INFO_PKG
--  create by:         Dalit A. Raviv
--  Revision:          1.1
--  creation date:     08/05/2011 10:30:11 PM
--------------------------------------------------------------------
--  purpose :          HR project - Handle Person Extra Information details
--------------------------------------------------------------------
--  ver  date          name              desc
--  1.0  08/05/2011    Dalit A. Raviv    initial build
--  1.1  27/06/2013    Dalit A. Raviv    Handle HR packages and apps_view
--                                       add AUTHID CURRENT_USER to spec
--------------------------------------------------------------------  
  
  --------------------------------------------------------------------
  --  name:            get_lookup_code_meaning
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   08/05/2011 
  --------------------------------------------------------------------
  --  purpose :        translate lookup code to meaning
  --  in params:       lookup type (name)
  --                   lookup code
  --  return:          lookup code meaning     
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  08/05/2011   Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  function get_lookup_code_meaning (p_lookup_type in varchar2,
                                    p_lookup_code in varchar2) return varchar2;
  
  --------------------------------------------------------------------
  --  name:            check_fin_mail
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   11/05/2011  Happy Birthday my Li-Or (19)
  --------------------------------------------------------------------
  --  purpose :        check if there are elements of 'Loan IL','Signing Bonus IL'
  --                   for this employee/contractor
  --  in params:       p_person_id
  --  return:          Y/N -> Y - need to send mail to Carmit, No - no need    
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  11/05/2011   Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  function check_fin_mail (p_person_id in number) return varchar2;
  
  --------------------------------------------------------------------
  --  name:            get_send_mail_to
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   08/05/2011 
  --------------------------------------------------------------------
  --  purpose :        get the list of people to send the mail to.
  --  in params:       p_organization_id - to know to which HR manager 
  --                                       the person relate to.
  --                   p_teritory        - HR sysadmin is different between teritories
  --  return:          strinfg with all email address to send to
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  08/05/2011   Dalit A. Raviv    initial build
  -------------------------------------------------------------------- 
  function get_send_mail_to (p_organization_id in number,
                             p_teritory        in varchar2) return varchar2 ;
                             
  --------------------------------------------------------------------
  --  name:            send_outgoing_form
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   08/05/2011 
  --------------------------------------------------------------------
  --  purpose :        Procedure that handel sending outgoing form to
  --                   HR maintenance person.
  --  in params:       p_person_id  - Unique id
  --                   retcode      - 0    success other fialed
  --                   errbuf       - null success other fialed
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  08/05/2011   Dalit A. Raviv    initial build
  --------------------------------------------------------------------                                 
  procedure send_outgoing_form (errbuf             out varchar2,
                                retcode            out varchar2,
                                p_person_id        in  number
                               );                                    

end XXHR_PERSON_EXTRA_INFO_PKG;

 
/
