create or replace package body xxobjt_sysadmin_pkg is
--------------------------------------------------------------------
--  name:            XXOBJT_SYSADMIN_PKG
--  create by:       Dalit A. Raviv
--  Revision:        1.3
--  creation date:   04/03/2013 10:07:00
--------------------------------------------------------------------
--  purpose :        REP629 SOD - Responsibility Menu and functions
--
-- Apps_View create or replace synonym apps_view.XXOBJT_SYSADMIN_PKG for apps.XXOBJT_SYSADMIN_PKG
-- for packages need to give grant execute as well
-- Grant execute on XXOBJT_SYSADMIN_PKG to apps_view;
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  04/03/2013  Dalit A. Raviv    initial build
--  1.1  14/04/2013  Dalit A. Raviv    add approach to Exclusion menues and function from responsibility level
--  1.2  26/05/2013  Dalit A. Raviv    add procedure upd_sso_profile - handle change value to profile
--                                     APPS_SSO_LOCAL_LOGIN that control the SSO user can update password
--                                     add procedure change_user_password
--  1.3  29/07/2013  Dalit A. Raviv    add log messages and finish in red when error
--------------------------------------------------------------------
  g_count              number := 0;
  g_responsibility_id  number;
  g_responsibility_key varchar2(30);
  g_resp_menu_id       number;
  g_sequence_id        pls_integer := 0;
  
  --------------------------------------------------------------------
  --  name:            insert_row
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   04/03/2013
  --------------------------------------------------------------------
  --  purpose :        REP629 SOD - Responsibility Menu and functions
  --                   insert row to XXOBJT_RESP_MENU_FUNC table
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  04/03/2013  Dalit A. Raviv    initial build
  --  1.1  14/03/2013  Saar Nagar        removed PRAGMA AUTONOMOUS_TRANSACTION and commit. + Removed sequance from code, used simple counter.
  --------------------------------------------------------------------
  procedure insert_row (p_menu_rec in  t_menu_rec,
                        retcode    out varchar2,
                        errbuf     out varchar2) is

  begin
    --select XXOBJT_RESP_MENU_FUNC_S.Nextval
    --into   l_entity
    --from dual; 
    g_sequence_id := g_sequence_id +1;
    insert /*+ append */ into XXOBJT_RESP_MENU_FUNC NOLOGGING ( entity_id,
                                        responsibility_id,
                                        responsibility_key,
                                        resp_menu_id,
                                        menu_id,
                                        entry_sequence,
                                        prompt,
                                        grant_flag,
                                        entry_level,
                                        sub_menu_id,
                                        function_id,
                                        last_update_date,
                                        last_updated_by,
                                        last_update_login,
                                        creation_date,
                                        created_by)
    values                             (g_sequence_id,
                                        p_menu_rec.responsibility_id,
                                        p_menu_rec.responsibility_key,
                                        p_menu_rec.resp_menu_id,
                                        p_menu_rec.menu_id,
                                        p_menu_rec.entry_sequence,
                                        p_menu_rec.prompt,
                                        p_menu_rec.grant_flag,
                                        p_menu_rec.entry_level,
                                        p_menu_rec.sub_menu_id,
                                        p_menu_rec.function_id,
                                        sysdate,
                                        g_user_id,
                                        -1,
                                        sysdate,
                                        g_user_id);
    retcode := 0;
    errbuf  := null;
    -- commit;
  exception
    when others then
      rollback;
      retcode := 1;
      errbuf  := 'GEN EXC - insert_row - '||substr(sqlerrm,1,240);
  end insert_row;
  --------------------------------------------------------------------
  --  name:            delete_tbl
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   04/03/2013
  --------------------------------------------------------------------
  --  purpose :        REP629 SOD - Responsibility Menu and functions
  --                   the program run once a day and populate XXOBJT_RESP_MENU_FUNC table.
  --                   the program will delete all rows before start new population.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  04/03/2013  Dalit A. Raviv    initial build
  --  1.1  14/08/2014  Saar Nagar        change from delete to truncate for performance use. removed PRAGMA AUTONOMOUS_TRANSACTION and commit. Drop XXOBJT_RESP_MENU_FUNC indexes prior to truncate.
  --------------------------------------------------------------------
  procedure delete_tbl (retcode    out varchar2,
                        errbuf     out varchar2) is
  begin
    retcode := 0;
    errbuf  := null;
    execute immediate ('drop index XXOBJT.XXOBJT_RESP_MENU_FUNC_N1');
    execute immediate ('drop index XXOBJT.XXOBJT_RESP_MENU_FUNC_N2');
    execute immediate ('drop index XXOBJT.XXOBJT_RESP_MENU_FUNC_N3');
    execute immediate ('drop index XXOBJT.XXOBJT_RESP_MENU_FUNC_U1');
    execute immediate ('truncate table XXOBJT.XXOBJT_RESP_MENU_FUNC');

    --commit;
  exception
    when others then
      retcode := 1;
      errbuf  := 'Procedure delete_tbl failed - '||substr(sqlerrm,1,240);
  end delete_tbl;

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
                             p_err_desc  out varchar2) is

    cursor pop_c (p_menu_id in number,
                  p_resp_id   in number) is
      select entry_sequence,
             prompt,
             description,
             grant_flag,
             menu_id,
             sub_menu_id,
             function_id
      from   fnd_menu_entries_vl menus
      where  menu_id  = p_menu_id
      and    p_entity = 'FULL'
      --  1.1  14/04/2013  Dalit A. Raviv
      and    not exists (select 1
                         from   fnd_resp_functions   rf
                         where  rf.action_id         = menus.function_id
                         and    rf.responsibility_id = p_resp_id   -- <Resp Param>
                         and    rf.rule_type         = 'F')
      and    not exists (select 1
                         from   fnd_resp_functions   rf
                         where  rf.action_id         = menus.menu_id
                         and    rf.responsibility_id = p_resp_id   -- <Resp Param>
                         and    rf.rule_type         ='M')
      --
      union all
      select entry_sequence,
             prompt,
             description,
             grant_flag,
             menu_id,
             sub_menu_id,
             function_id
      from   fnd_menu_entries_vl  menus
      where  menu_id    = p_menu_id
      and    p_entity   = 'ACTIVE'
      and    prompt     is not null
      and    grant_flag = 'Y'
      --  1.1  14/04/2013  Dalit A. Raviv
      and    not exists (select 1
                         from   fnd_resp_functions   rf
                         where  rf.action_id         = menus.function_id
                         and    rf.responsibility_id = p_resp_id   -- <Resp Param>
                         and    rf.rule_type         = 'F')
      and    not exists (select 1
                         from   fnd_resp_functions   rf
                         where  rf.action_id         = menus.menu_id
                         and    rf.responsibility_id = p_resp_id   -- <Resp Param>
                         and    rf.rule_type         ='M')
      --
      order by entry_sequence;

    l_menu_rec  XXOBJT_SYSADMIN_PKG.t_menu_rec;
    l_err_code  varchar2(10);
    l_err_buf   varchar2(500);
    gen_exc     exception;

    v_counter PLS_INTEGER := 0;
  begin
    g_count := g_count +1;

    for pop_r in pop_c (p_menu_id, g_responsibility_id) loop
      -- if function is exists this is the lowest level
      if pop_r.function_id is not null then

        l_menu_rec := null;
        l_menu_rec.responsibility_id  := g_responsibility_id;
        l_menu_rec.responsibility_key := g_responsibility_key;
        l_menu_rec.resp_menu_id       := g_resp_menu_id;
        l_menu_rec.menu_id            := p_menu_id;
        l_menu_rec.entry_sequence     := pop_r.entry_sequence;
        l_menu_rec.prompt             := pop_r.prompt;
        l_menu_rec.grant_flag         := pop_r.grant_flag;
        l_menu_rec.entry_level        := g_count;
        l_menu_rec.sub_menu_id        := null;
        l_menu_rec.function_id        := pop_r.function_id;

        insert_row (l_menu_rec, -- i t_menu_rec,
                    l_err_code, -- o v
                    l_err_buf); -- o v
      -- if sub_menu_id is exists this is the a level that need to continue with the explode.
      -- first i enter row and then call to the recursive procedure again
      -- no need for exist condition because the lowest level is function and
      -- the loop will finish by itself.
      elsif pop_r.sub_menu_id is not null then

        l_menu_rec := null;
        l_menu_rec.responsibility_id  := g_responsibility_id;
        l_menu_rec.responsibility_key := g_responsibility_key;
        l_menu_rec.resp_menu_id       := g_resp_menu_id;
        l_menu_rec.menu_id            := p_menu_id;
        l_menu_rec.entry_sequence     := pop_r.entry_sequence;
        l_menu_rec.prompt             := pop_r.prompt;
        l_menu_rec.grant_flag         := pop_r.grant_flag;
        l_menu_rec.entry_level        := g_count;
        l_menu_rec.sub_menu_id        := pop_r.sub_menu_id;
        l_menu_rec.function_id        := null;

        insert_row (l_menu_rec, -- i t_menu_rec,
                    l_err_code, -- o v
                    l_err_buf); -- o v

        recursive_menus (p_entity     => p_entity,          -- i n
                         p_menu_id    => pop_r.sub_menu_id, -- i n
                         p_err_code   => l_err_code,        -- o v
                         p_err_desc   => l_err_buf);        -- o v
      end if;

      v_counter := v_counter +1;
      if ( v_counter >= 10000 ) then
        v_counter := 0;
        commit;
      end if;

    end loop;

    commit; -- commit
    -- control not to enter to endless loop
    if g_count = 200 then
      raise gen_exc;
    end if;

  exception
    when gen_exc then
      p_err_code := 1;
      p_err_desc := 'Recursive loop to long recursive_menus';
    when others then
      p_err_code := 1;
      p_err_desc := 'Gen Exception recursive_menus - '||substr(sqlerrm,1,220);
  end recursive_menus;

  --------------------------------------------------------------------
  --  name:            main
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   11/03/2013
  --------------------------------------------------------------------
  --  purpose :        REP629 SOD - Responsibility Menu and functions
  --                   1) delete from temp table.
  --                   2) populate temp table.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  11/03/2013  Dalit A. Raviv    initial build
  --  1.1  14/08/2014  Saar Nagar        Add index creation after DML work was finished.
  --------------------------------------------------------------------
  procedure main(errbuf              out varchar2,
                 retcode             out varchar2,
                 p_responsibility_id in  number,  -- 51137
                 p_entity            in  varchar2) is

    -- get all responsibilities taht are active and connect to users.
    cursor resp_c is
      select t.responsibility_key,  t.responsibility_name, t.menu_id , t.responsibility_id, m.menu_name
      from   fnd_responsibility_vl  t,
             fnd_menus_vl           m
      where  trunc(sysdate)         between nvl(t.start_date, trunc(sysdate)) and nvl(t.end_date, trunc(sysdate) )
      and    m.menu_id              = t.menu_id
      and    t.responsibility_id    = nvl(p_responsibility_id,t.responsibility_id)
      and    exists                 ( select 1
                                      from   fnd_user_resp_groups g,
                                             fnd_user             u
                                      where  t.responsibility_id  = g.responsibility_id
                                      and    g.user_id            = u.user_id
                                      and    sysdate              <= nvl(u.end_date, sysdate));

    l_err_code  varchar2(10);
    l_err_buf   varchar2(500);
    l_count     number := 0;
  begin

    fnd_file.put_line(fnd_file.log,'Start - '||to_char(sysdate,'DD-MON-YYYY HH24:MI:SS'));
    dbms_output.put_line('Start - '||to_char(sysdate,'DD-MON-YYYY HH24:MI:SS'));
    -- set g_user_id
    begin
      select fu.user_id
      into   g_user_id
      from   fnd_user fu
      where  fu.user_name = 'SCHEDULER';
    end;

    g_sequence_id := 0;

    -- Set init var
    errbuf  := null;
    retcode := 0;
    -- before start to run delete data fronm table XXOBJT_RESP_MENU_FUNC.(start from clean)
    delete_tbl (retcode  => l_err_code, -- o v
                errbuf   => l_err_buf); -- o v
    if l_err_code <> 0 then
      errbuf  := 'Can not delete table';
      retcode := 1;
    else

     -- start populate table XXOBJT_RESP_MENU_FUNC
     for resp_r in  resp_c loop
        l_err_code := 0;
        l_err_buf  := null;
        l_count    := l_count + 1;
        g_count    := 0;

        fnd_file.put_line(fnd_file.log,l_count||'  Resp - '||resp_r.responsibility_key||' '||resp_r.responsibility_id);
        dbms_output.put_line(l_count||'  Resp - '||resp_r.responsibility_key||' '||resp_r.responsibility_id);
        g_responsibility_id  := resp_r.responsibility_id;
        g_responsibility_key := resp_r.responsibility_key;
        g_resp_menu_id       := resp_r.menu_id;
        -- This function by recursive use enter for each menu the sub_menu and functions.
        recursive_menus (p_entity     => p_entity,       -- i n
                         p_menu_id    => resp_r.menu_id, -- i n
                         p_err_code   => l_err_code,     -- o v
                         p_err_desc   => l_err_buf);     -- o v
        if l_err_code = 1 then
          fnd_file.put_line(fnd_file.log,l_err_buf);
          dbms_output.put_line(l_err_buf);
        end if;
      end loop; -- resp_r

    execute immediate ('create index XXOBJT.XXOBJT_RESP_MENU_FUNC_N1 on XXOBJT.XXOBJT_RESP_MENU_FUNC (FUNCTION_ID) NOLOGGING tablespace APPS_TS_TX_IDX');
    execute immediate ('create index  XXOBJT.XXOBJT_RESP_MENU_FUNC_N2 on XXOBJT.XXOBJT_RESP_MENU_FUNC (RESPONSIBILITY_ID) NOLOGGING tablespace APPS_TS_TX_IDX');
    execute immediate ('create index XXOBJT.XXOBJT_RESP_MENU_FUNC_N3 on XXOBJT.XXOBJT_RESP_MENU_FUNC (MENU_ID) NOLOGGING tablespace APPS_TS_TX_IDX');
    execute immediate ('create unique index XXOBJT.XXOBJT_RESP_MENU_FUNC_U1 on XXOBJT.XXOBJT_RESP_MENU_FUNC (ENTITY_ID) NOLOGGING tablespace APPS_TS_TX_IDX');

    end if; -- l_err_code delete
    fnd_file.put_line(fnd_file.log,'End - '||to_char(sysdate,'DD-MON-YYYY HH24:MI:SS'));
    dbms_output.put_line('End - '||to_char(sysdate,'DD-MON-YYYY HH24:MI:SS'));
  exception
    when others then
      errbuf  := 'Procedure Main failed: '||substr(sqlerrm,1,240);
      retcode := 1;
  end main;

  --------------------------------------------------------------------
  --  name:            upd_sso_local_login_profile
  --  create by:       dalit a. raviv
  --  Revision:        1.0
  --  creation date:   26/05/2013
  --------------------------------------------------------------------
  --  purpose :        CR791 User Password - SSO
  --                   program that will run once a week
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  26/05/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure upd_SSO_LOCAL_LOGIN_profile( errbuf              out varchar2,
                                         retcode             out varchar2) is

    cursor pop_c is
      select *
      from   fnd_user     fu
      where  fu.user_guid is not null;
      --and    rownum       < 20;

    l_status        boolean := false;
    l_profile       fnd_profile_options_vl.profile_option_name%type;
    l_profile_value xxobjt_profiles_v.profile_value%type;
    l_count_s       number := 0;
    l_count_e       number := 0;

  begin
    errbuf  := null;
    retcode := 0;

    l_profile := 'APPS_SSO_LOCAL_LOGIN';
    for pop_r in pop_c loop
      -- check the value user have
      l_profile_value := fnd_profile.VALUE_SPECIFIC('APPS_SSO_LOCAL_LOGIN',pop_r.user_id );
      dbms_output.put_line(' l_profile_value - '||l_profile_value);

      -- if the value is different from LOCAL then change it.
      if nvl(l_profile_value,'DR') <> 'LOCAL' then
        l_status := fnd_profile.save ( x_name => l_profile ,x_value => 'LOCAL', x_level_name => 'USER', x_level_value => pop_r.user_id );
        if ( l_status ) then
          l_count_s := l_count_s + 1;
          fnd_file.put_line(fnd_file.log,'S - '||pop_r.user_name);
          dbms_output.put_line('S - '||pop_r.user_name);
        else
          l_count_e := l_count_e + 1;
          fnd_file.put_line(fnd_file.log,'E - '||pop_r.user_name);
          dbms_output.put_line('E - '||pop_r.user_name);
        end if;
      end if;
    end loop;
    commit;

    fnd_file.put_line(fnd_file.log,'Change value to profile APPS_SSO_LOCAL_LOGIN - Success '||l_count_s);
    fnd_file.put_line(fnd_file.log,'Change value to profile APPS_SSO_LOCAL_LOGIN - Errors  '||l_count_e);
    dbms_output.put_line('Change value to profile APPS_SSO_LOCAL_LOGIN - Success '||l_count_s);
    dbms_output.put_line('Change value to profile APPS_SSO_LOCAL_LOGIN - Errors  '||l_count_e);
  exception
    when others then
      errbuf  := 'Procedure upd_sso_profile failed - '||substr(sqlerrm,1,240);
      retcode := 2;
  end upd_SSO_LOCAL_LOGIN_profile;

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
                                 p_password    in varchar2) is

    l_status        boolean := false;
    l_profile       fnd_profile_options_vl.profile_option_name%type;
    l_user_name     fnd_user.user_name%type;
    l_result        boolean := false;

  begin
    errbuf  := null;
    retcode := 0;

    -- The following anonymous block will update all profiles
    -- and will replace the explicit updates
    select t1.user_name
    into   l_user_name
    from   fnd_user     t1
    where  t1.user_id   = p_user_id;
    fnd_file.put_line(fnd_file.log,'--- User --- ' || upper(l_user_name));
    l_profile := 'APPS_SSO_LOCAL_LOGIN';

    l_status := fnd_profile.save ( x_name => l_profile ,x_value => 'LOCAL', x_level_name => 'USER', x_level_value => p_user_id );
    commit;

    -- Change Password for User
    if ( l_status ) then
      dbms_output.put_line ('Profile was succefully alter to LOCAL');
      fnd_file.put_line(fnd_file.log,'Profile was succefully alter to LOCAL');
      l_result := fnd_user_pkg.changepassword(username    => upper(l_user_name),
                                              newpassword => p_password);
      if ( l_result ) then
        commit;
        dbms_output.put_line ('Password was changed.');
        fnd_file.put_line(fnd_file.log,'Password was changed.');
      else
        errbuf  := 'Failed to change password.';
        retcode := 2;
        rollback;
        dbms_output.put_line ('Failed to change password. '||substr(sqlerrm,1,240));
        fnd_file.put_line(fnd_file.log,'Failed to change password.'||substr(sqlerrm,1,240));
      end if;
    else
      dbms_output.put_line ('Profile FAILED to be alter to LOCAL, Skipping Password Change.' );
      fnd_file.put_line(fnd_file.log,'Profile FAILED to be alter to LOCAL, Skipping Password Change.');
    end if;

    -- Remove profile value
    l_status := fnd_profile.save ( x_name => l_profile ,x_value => '', x_level_name => 'USER', x_level_value => p_user_id );
    commit;
    if ( l_status ) then
      null;
    end if;
  exception
    when others then
      errbuf  := 'change_user_password - '||substr(sqlerrm,1,240);
      retcode := 2;
  end change_user_password;


end XXOBJT_SYSADMIN_PKG;
/
