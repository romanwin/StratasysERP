create or replace package xxobjt_sysadmin_pkg is
--------------------------------------------------------------------
--  name:            XXOBJT_SYSADMIN_PKG
--  create by:       Dalit A. Raviv
--  Revision:        1.1
--  creation date:   04/03/2013 10:07:00
--------------------------------------------------------------------
--  purpose :        REP629 SOD - Responsibility Menu and functions
--
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  04/03/2013  Dalit A. Raviv    initial build
--  1.1  26/05/2013  Dalit A. Raviv    add procedure upd_sso_profile - handle change value to profile
--                                     APPS_SSO_LOCAL_LOGIN that control the SSO user can update password
--                                     add procedure change_user_password
--------------------------------------------------------------------

 TYPE t_menu_rec IS RECORD
      ( responsibility_id     number,
        responsibility_key    varchar2(30),
        resp_menu_id          number,
        menu_id               number,
        entry_sequence        number,
        prompt                varchar2(60),
        grant_flag            varchar2(5),
        entry_level           number,
        sub_menu_id           number,
        function_id           number);

  g_user_id                   number; 

  --------------------------------------------------------------------
  --  name:            Main
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   04/03/2013 10:07:00
  --------------------------------------------------------------------
  --  purpose :        REP629 SOD - Responsibility Menu and functions
  --                   1) delete from temp table.
  --                   2) populate temp table.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  04/03/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure main(errbuf              out varchar2,
                 retcode             out varchar2,
                 p_responsibility_id in  number,
                 p_entity            in  varchar2);
                 
  --------------------------------------------------------------------
  --  name:            recursive_menus
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   11/03/2013
  --------------------------------------------------------------------
  --  purpose :        REP629 SOD - Responsibility Menu and functions
  --                   call from main with the main menu id from the responsibility
  --                   and bring alll sub_menus and functions for this main menu.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  11/03/2013  Dalit A. Raviv    initial build
  --  1.1  14/04/2013  Dalit A. Raviv    add approach to exclusion from responsibility.
  --  1.2  14/08/2014  Saar Nagar        Added commit every 10000 rows.
  --------------------------------------------------------------------
  procedure recursive_menus (p_entity    in  varchar2,
                             p_menu_id   in  number,
                             p_err_code  out varchar2,
                             p_err_desc  out varchar2);

  --------------------------------------------------------------------
  --  name:            upd_SSO_LOCAL_LOGIN_profile
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   26/05/2013
  --------------------------------------------------------------------
  --  purpose :        CR791 User Password - SSO
  --                   program that will run once a week
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  26/05/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure upd_SSO_LOCAL_LOGIN_profile( errbuf   out varchar2,
                                         retcode  out varchar2);

  --------------------------------------------------------------------
  --  name:            change_user_password
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   26/05/2013
  --------------------------------------------------------------------
  --  purpose :        CR791 User Password - SSO
  --                   manualy program that will use by Helpdesk
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  26/05/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure change_user_password(errbuf        out varchar2,
                                 retcode       out varchar2,
                                 p_user_id     in number,
                                 p_password    in varchar2);

  --procedure test (p_responsibility_id in number) ;
end XXOBJT_SYSADMIN_PKG;
/
