create or replace package body xxobjt_auto_create_user_pkg is

--------------------------------------------------------------------
--  name:            XXOBJT_AUTO_CREATE_USER_PKG
--  create by:       Dalit A. Raviv
--  Revision:        1.5
--  creation date:   06/09/2012 09:30:07
--------------------------------------------------------------------
--  purpose :        CUST530 - Automatic creation of oracle user
--
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  06/09/2012  Dalit A. Raviv    initial build
--  1.1  27/11/2012  Dalit A. Raviv    Add full_name at user description fields
--                                     add email address to user fields
--                                     change password number of days from 90 to 180
--                                     Add procedure main_update
--  1.2  10/01/2013  Dalit A. Raviv    change logic at get_person_short_territory and get_resp_name
--  1.3  30/01/2012  Dalit A. Raviv    Add_responsibility enlarge local var
--  1.4  11/08/2013  Dalit A. Raviv    proceduer Main - enlarge the population of the program to look at persons 3 days before start to work.
--                                     main trunc(greatest(period.date_start,period.creation_date)) between trunc(sysdate) - 1 and trunc(sysdate)
--  1.5  30/09/2013  Dalit A. Raviv    BUGFIX1036 - handle of user creation 3 days befor start working.
--  1.6  26/06/2014  Dalit A. Raviv    CHG0032452 Responsibilities for new users
--                                     Us employees do not use responsibility - internet expense US , consult with Laura,
--                                     we decided that we will not create the users for employees from NA or Corp US territories.
--  1.7  05/07/2018  Roman W           CHG0043270: Modified logic to derive 
--                                     default responsibility name from location.
--------------------------------------------------------------------

  g_user_id   number := fnd_global.USER_ID;
  g_batch_id  number := null;
  g_days      number := fnd_profile.value('XXOBJET_AUTOCREATE_USER_DAYS');

  --------------------------------------------------------------------
  --  name:            insert_log
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
  procedure insert_log(p_person_id  in  number,
                       p_full_name  in  varchar2,
                       p_log_msg    in  varchar2,
                       p_log_code   in  varchar2,
                       p_user_name  in  varchar2,
                       p_resp       in  varchar2,
                       p_err_code   out number,
                       p_err_desc   out varchar2) is
    PRAGMA AUTONOMOUS_TRANSACTION;
    l_log_id number := null;
  begin
    p_err_code := 0;
    p_err_desc := null;
    -- get entity id
    select xxobjt_autocreate_user_log_s.Nextval
    into   l_log_id
    from   dual;

    insert into xxobjt_autocreate_user_log( BATCH_ID,
                                            LOG_ID,
                                            PERSON_ID,
                                            PERSON_FULL_NAME,
                                            LOG_CODE,
                                            LOG_MESSAGE,
                                            SEND_MAIL,
                                            USER_NAME,
                                            RESPONSIBILITY,
                                            LAST_UPDATE_DATE,
                                            LAST_UPDATED_BY,
                                            LAST_UPDATE_LOGIN,
                                            CREATION_DATE,
                                            CREATED_BY)
    values                                ( g_batch_id,
                                            l_log_id,
                                            p_person_id,
                                            p_full_name,
                                            p_log_code,
                                            p_log_msg,
                                            'N',
                                            p_user_name,
                                            p_resp,
                                            sysdate,
                                            g_user_id,
                                            -1,
                                            sysdate,
                                            g_user_id);

    commit;
  exception
    when others then
      fnd_file.put_line(fnd_file.log,'Procedure insert_log - Failed - '||substr(sqlerrm,1,240));
      rollback;
      p_err_code := 1;
      p_err_desc := 'Procedure insert_log - Failed - '||substr(sqlerrm,1,240);
  end insert_log;

  --------------------------------------------------------------------
  --  name:            handle_messages
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   09/09/2012
  --------------------------------------------------------------------
  --  purpose :        CUST530 - Automatic creation of oracle user
  --                   Handle all message at program
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  09/09/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  function handle_messages  (p_message_name in  varchar2,
                             p_token1       in  varchar2,
                             p_token2       in  varchar2--,
                             )  return varchar2 is
    l_message     varchar2(500) := null;
  begin
    if p_message_name = 'XXOBJET_AUTOCREATE_USER_ERR' then
      fnd_message.SET_NAME('XXOBJT','XXOBJET_AUTOCREATE_USER_ERR');    -- Unable to create User due to &SQLCODE  -  &SQLERRM.
      fnd_message.SET_TOKEN('SQLCODE' ,p_token1); -- sqlcode
      fnd_message.SET_TOKEN('SQLERRM' ,p_token2); -- SUBSTR(SQLERRM, 1, 240)
    end if;

    if p_message_name = 'XXOBJET_AUTOCREATE_USER_SUCCES' then
      fnd_message.SET_NAME('XXOBJT','XXOBJET_AUTOCREATE_USER_SUCCES'); -- User &USERNAME Created Successfully
      fnd_message.SET_TOKEN('USERNAME' ,p_token1); -- l_user_name
    end if;

    if p_message_name = 'XXOBJET_AUTOCREATE_USER_PERSON' then
      fnd_message.SET_NAME('XXOBJT','XXOBJET_AUTOCREATE_USER_PERSON'); -- Person exists in User table - user -  &USERNAME Person id - &PERSON
      fnd_message.SET_TOKEN('USERNAME' ,p_token1); -- l_user_name
      fnd_message.SET_TOKEN('PERSON'   ,p_token2); -- pop_r.full_name
    end if;

    if p_message_name = 'XXOBJET_AUTOCREATE_USER_EXIST' then
      fnd_message.SET_NAME('XXOBJT','XXOBJET_AUTOCREATE_USER_EXIST');  -- Same User Name exists in User table - &USERNAME
      fnd_message.SET_TOKEN('USERNAME' ,p_token1); -- pop_r.user_name
    end if;

    if p_message_name = 'XXOBJET_AUTOCREATE_USER_CLOSE' then
      fnd_message.SET_NAME('XXOBJT','XXOBJET_AUTOCREATE_USER_CLOSE');  -- Exist closed Oracle User &USERNAME for person &PERSON
      fnd_message.SET_TOKEN('USERNAME' ,p_token1); -- l_user_name
      fnd_message.SET_TOKEN('PERSON'   ,p_token2); -- pop_r.full_name
    end if;

    if p_message_name = 'XXOBJET_AUTOCREATE_USER_RESP' then
      fnd_message.SET_NAME('XXOBJT','XXOBJET_AUTOCREATE_USER_RESP');   -- Created User &USERNAME without any responsibilities.
      fnd_message.SET_TOKEN('USERNAME' ,p_token1); -- pop_r.user_name
    end if;

    if p_message_name = 'XXOBJET_AUTOCREATE_USER_ADD_EX' then
      fnd_message.SET_NAME('XXOBJT','XXOBJET_AUTOCREATE_USER_ADD_EX'); -- Responsibility: &RESP is added to the User &USERNAME
      fnd_message.SET_TOKEN('RESP' ,p_token1); -- pop_r.user_name
      fnd_message.SET_TOKEN('USERNAME' ,p_token2); -- pop_r.user_name
    end if;

    if p_message_name = 'XXOBJET_AUTOCREATE_USER_UNABLE' then
      fnd_message.SET_NAME('XXOBJT','XXOBJET_AUTOCREATE_USER_UNABLE'); -- Unable to add the responsibility due to &SQLCODE - &SQLERRM
      fnd_message.SET_TOKEN('SQLCODE' ,p_token1); -- sqlcode
      fnd_message.SET_TOKEN('SQLERRM' ,p_token2); -- SUBSTR(SQLERRM, 1, 240)
    end if;
    -- Did not created User &USERNAME because did not found any Responsibility to add.
    if p_message_name = 'XXOBJET_AUTOCREATE_USER_NO_RES' then
      fnd_message.SET_NAME('XXOBJT','XXOBJET_AUTOCREATE_USER_NO_RES'); -- Created User &USERNAME without any Responsibility
      fnd_message.SET_TOKEN('USERNAME' ,p_token1); -- pop_r.user_name
    end if;

    if p_message_name = 'XXOBJET_AUTOCREATE_PERSON_TYPE' then
      fnd_message.SET_NAME('XXOBJT','XXOBJET_AUTOCREATE_PERSON_TYPE'); -- Person &NAME, created with Person Type - &PERSONTYPE. Need Manager approval for user creation.
      fnd_message.SET_TOKEN('NAME' ,p_token1);       -- Person full name
      fnd_message.SET_TOKEN('PERSONTYPE' ,p_token2); -- Person user type
    end if;

    if p_message_name = 'XXOBJET_AUTOCREATE_USERPER_ERR' then
      fnd_message.SET_NAME('XXOBJT','XXOBJET_AUTOCREATE_USERPER_ERR'); -- Did not success to add person to user - &USER
      fnd_message.SET_TOKEN('USERNAME' ,p_token1); -- pop_r.user_name
    end if;

    /*if p_message_name = 'XXOBJET_AUTOCREATE_USER_NO_RES' then
      fnd_message.SET_NAME('XXOBJT','XXOBJET_AUTOCREATE_USER_NO_RES');  -- Responsibility: &RESP is added to the User &USERNAME
      fnd_message.SET_TOKEN('USERNAME' ,p_token2); -- pop_r.user_name
    end if;*/


    l_message := fnd_message.GET;
    return l_message;
  exception
    when others then
      return null;
  end handle_messages;

  --------------------------------------------------------------------
  --  name:            get_person_short_territory
  --  create by:       Dalit A. Raviv
  --  Revision:        1.1
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
  --  1.1  30/09/2013  Dalit A. Raviv    BUGFIX1036 - handle of user creation 3 days befor start working.
  --------------------------------------------------------------------
  function get_person_short_territory(p_person_id in number) return varchar2 is

    l_org_name  varchar2(360) := null;
    l_org_id    number        := null;
    l_territory varchar2(360) := null;

  begin
    -- Get person Organization name from assignment
    l_org_name  := XXHR_UTIL_PKG.get_person_org_name(p_person_id, trunc(sysdate) + g_days,0);
    -- check case HR create person but did not changed the assignment details from the default.
    if l_org_name <> 'Objet Main Business Group' then
      -- Get organization id
      l_org_id    := XXHR_UTIL_PKG.get_org_id (l_org_name, 0);
      -- get Territory person realte to.
      l_territory := XXHR_UTIL_PKG.get_organization_by_hierarchy (l_org_id,'TER','NAME');

      -- Set return Territory suffix - IL, AP, EU, US etc'
      if l_territory = 'Lower type' then
        return 'Corp IL';
      else
        return l_territory;
      end if;
    else
      return 'Objet Main Business Group';
    end if;
  end get_person_short_territory;

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
  --  1.1  10/01/2013  Dalit A. Raviv    change logic doe to the organization chart changes.
  --                                     value set will hold by territory and location the
  --                                     responsibility that need to add to new user.  get_resp_name
  --------------------------------------------------------------------
  function get_resp_name(p_territory in varchar2,
                         p_person_id in number) return varchar2 is
    l_location_code  varchar2(150) := null;
    l_responsibility varchar2(150) := null;
  begin
    /*-- Corp IL and LATAM will handle as IL
    if p_territory in ( 'IL','AM') then  -- AM = LATAM
      return 'Internet Expenses, OBJET IL';
    -- Corp US and NA will handle as US
    elsif p_territory in ( 'US', 'NA') then
      return 'Internet Expenses, OBJET US';
    -- Stratasys EU changed name to EMEA
    elsif p_territory = 'EA'\*'EU'*\ then
      return 'Internet Expenses, OBJET DE';
    -- Stratasys AP changed name to APJ
    elsif p_territory = 'PJ'\*'AP' *\then
      l_location_code := apps.xxhr_util_pkg.get_location_code(p_person_id, trunc(sysdate),0);
      if substr(l_location_code,-2) = 'HK' then
        -- Objet Asia Pacific - JP
        return 'Internet Expenses, OBJET HK';
      elsif substr(l_location_code,-2) = 'na' then
        return 'Internet Expenses, OBJET CN';
      else
        return null;  -- Objet Asia Pacific - JP
      end if;
   else
     return null;
   end if;*/
    if p_territory = 'Setup Business Group'/*'Objet Main Business Group'*/ then
      return null;
    else
      l_location_code := apps.xxhr_util_pkg.get_location_code(p_person_id, trunc(sysdate) + g_days,0);

      select fv.attribute3
      into   l_responsibility
      from   fnd_flex_values_vl      fv,
             fnd_flex_value_sets     fvs
      where  fv.flex_value_set_id    = fvs.flex_value_set_id
      and    fvs.flex_value_set_name like 'XXOBJT_AUTOCREATE_RESP'
      and    fv.enabled_flag         = 'Y'
      and    fv.attribute1           = p_territory
      and    (fv.attribute2          is null or fv.attribute2 = l_location_code);

      return l_responsibility;
    end if;
  exception
    when others then
      return null;
  end get_resp_name;

  --------------------------------------------------------------------
  --  name:            close_responsibility
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   09/09/2012
  --------------------------------------------------------------------
  --  purpose :        CUST530 - Automatic creation of oracle user
  --                   Closed exist responsibilities.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  09/09/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure close_responsibility ( p_user_name     in  varchar2,  -- MICHAELS
                                   errbuf          out varchar2,
                                   retcode         out varchar2)  is

    -- get all open responsibilities for the user
    cursor pop_c is
      select fu.user_name,
             fur.responsibility_id,
             r.responsibility_name,
             r.responsibility_key,
             a.application_short_name,
             fur.start_date
      from   fnd_user                    fu,
             fnd_user_resp_groups_direct fur,
             fnd_responsibility_vl       r,
             fnd_application_vl          a
      where  fur.user_id                 = fu.user_id
      and    r.responsibility_id         = fur.responsibility_id
      and    fur.end_date                is  null
      and    r.application_id            = a.application_id
      and    fu.user_name                = p_user_name;

  begin
    errbuf  := null;
    retcode := 0;
    -- if exists closed user -first closed all responsibilities
    -- then open/create only the internet expense responsibility according to territory.
    for pop_r in pop_c loop
      begin
        fnd_user_pkg.AddResp (username       => pop_r.user_name,
                              resp_app       => pop_r.application_short_name,
                              resp_key       => pop_r.responsibility_key,
                              security_group => 'STANDARD',
                              description    => null,
                              start_date     => pop_r.start_date,
                              end_date       => sysdate
                              );

        commit;
        --dbms_output.put_line ('Responsibility:'||pop_r.responsibility_key||' '||'is Closed to User:'||p_user_name);
      exception
        when others then
          null;
          rollback;
      end;
    end loop;

  exception
    when others then
      null;
      rollback;
  end close_responsibility;

  --------------------------------------------------------------------
  --  name:            Add_responsibility
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   09/09/2012
  --------------------------------------------------------------------
  --  purpose :        CUST530 - Automatic creation of oracle user
  --                   Add new responsibilities if exist open it.   
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  09/09/2012  Dalit A. Raviv    initial build
  --  1.1  30/01/2012  Dalit A. Raviv    enlarge local var l_territory   
  --  1.2  05-AUG-18   Roman W           CHG0043270: Modified logic to derive 
  --                                     default responsibility name from location.
  --------------------------------------------------------------------
  procedure Add_responsibility(p_user_name     in  varchar2,  -- MICHAELS
                               p_person_id     in  number,
                               p_resp_name     out varchar2,
                               errbuf          out varchar2,
                               retcode         out varchar2)  is

    l_territory      varchar2(100)  := null;
    l_resp           varchar2(150);
    l_resp_key       varchar2(30);
    l_app_short_name varchar2(50);
    l_add_resp       varchar2(5);
    l_message        varchar2(500) := null;
  begin
    errbuf  := null;
    retcode := 0;
    begin
    --  Addition as part of CHG0043270 start
      l_add_resp := 'Y';
    
      select frv.responsibility_key, fav.application_short_name
        into l_resp_key, l_app_short_name
        from per_all_assignments_f paaf,
             hr_locations          hl,
             fnd_responsibility_vl frv,
             fnd_application_vl    fav
       where 1 = 1
         and paaf.person_id = p_person_id
         and trunc(sysdate) between paaf.effective_start_date and
             paaf.effective_end_date
         and hl.location_id = paaf.location_id
         and hl.attribute4 = to_char(frv.responsibility_id)
         and fav.application_id = frv.application_id;
    
    exception
      when no_data_found then
        l_resp_key       := null;
        l_app_short_name := null;

        fnd_file.put_line(fnd_file.log,'Unable to derive default Responsibility');
        l_add_resp := 'N';
      when others then
        -- Created User &USERNAME without any Responsibility
        l_message  := handle_messages('XXOBJET_AUTOCREATE_USER_NO_RES',
                                      p_user_name,
                                      null);
        errbuf     := l_message;
        retcode    := 1;
        l_add_resp := 'N';
    end; 
    --  Addition as part of CHG0043270 end.
    
    -- Commented as part of CHG0043270 start. 
/*    l_territory := get_person_short_territory(p_person_id);
    l_resp      := get_resp_name(l_territory,p_person_id) ;
    l_add_resp  := 'Y';
    p_resp_name := l_resp;
    begin
      select r.responsibility_key,
             a.application_short_name
      into   l_resp_key,
             l_app_short_name
      from   fnd_responsibility_vl        r,
             fnd_application_vl           a
      where  r.application_id             = a.application_id
      and    upper(r.responsibility_name) = upper(l_resp);
    exception
      when others then
        -- Created User &USERNAME without any Responsibility
        l_message := handle_messages  ('XXOBJET_AUTOCREATE_USER_NO_RES',p_user_name,null);
        errbuf     := l_message;
        retcode    := 1;
        l_add_resp := 'N';
    end;*/  
    -- Commented as part of CHG0043270 end.
    
    
    -- Add Internet Expense responsibility according to Hr Territory
    if l_add_resp = 'Y' then
      fnd_user_pkg.AddResp (username       => p_user_name,
                            resp_app       => l_app_short_name,
                            resp_key       => l_resp_key,
                            security_group => 'STANDARD',
                            description    => null, -- description => ¿Auto Assignment¿
                            start_date     => sysdate,
                            end_date       => null
                            );
      --commit;
      --p_resp_name := l_resp;
      -- Responsibility: &RESP is added to the User &USERNAME
      l_message := handle_messages  ('XXOBJET_AUTOCREATE_USER_ADD_EX',l_resp,p_user_name);
      errbuf      := l_message;
      retcode     := 0;

      --dbms_output.put_line (l_message);
      --fnd_file.put_line(fnd_file.log,l_message);
    end if;
  exception
    when others then
      -- Unable to add the responsibility due to &SQLCODE - &SQLERRM
      l_message := handle_messages  ('XXOBJET_AUTOCREATE_USER_UNABLE',SQLCODE,SUBSTR(SQLERRM, 1, 240));
      dbms_output.put_line (l_message);
      fnd_file.put_line(fnd_file.log,l_message);
      p_resp_name := null;
      errbuf      := l_message;
      retcode     := 2;
      --rollback;
  end Add_responsibility;
  --------------------------------------------------------------------
  --  name:            Handle_responsibility
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   09/09/2012
  --------------------------------------------------------------------
  --  purpose :        CUST530 - Automatic creation of oracle user
  --                   Open Closed responsibilities.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  09/09/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
 /* procedure handle_responsibility (p_user_name     in  varchar2,  -- MICHAELS
                                   p_person_id     in  number,
                                   p_entity        in  varchar2,  -- p_entity = 'CLOSE'
                                   errbuf          out varchar2,
                                   retcode         out varchar2)  is

    -- get all open responsibilities for the user
    cursor pop_c is
      select fu.user_name,
             fur.responsibility_id,
             r.responsibility_name,
             r.responsibility_key,
             a.application_short_name,
             fur.start_date
      from   fnd_user                    fu,
             fnd_user_resp_groups_direct fur,
             fnd_responsibility_vl       r,
             fnd_application_vl          a
      where  fur.user_id                 = fu.user_id
      and    r.responsibility_id         = fur.responsibility_id
      and    fur.end_date                is  null
      and    r.application_id            = a.application_id
      and    fu.user_name                = p_user_name;

    l_territory      varchar2(10)  := null;
    l_resp           varchar2(150);
    l_resp_key       varchar2(30);
    l_app_short_name varchar2(50);
    l_add_resp       varchar2(5);
    l_message        varchar2(500) := null;
  begin
    errbuf  := null;
    retcode := 0;
    -- if exists closed user -first closed all responsibilities
    -- then open/create only the internet expense responsibility according to territory.
    if p_entity = 'CLOSE' then
      for pop_r in pop_c loop
        begin
          fnd_user_pkg.AddResp (username       => pop_r.user_name,
                                resp_app       => pop_r.application_short_name,
                                resp_key       => pop_r.responsibility_key,
                                security_group => 'STANDARD',
                                description    => null,
                                start_date     => pop_r.start_date,
                                end_date       => sysdate
                                );

          commit;
          --dbms_output.put_line ('Responsibility:'||pop_r.responsibility_key||' '||'is Closed to User:'||p_user_name);
        exception
          when others then
            null;
        end;
      end loop;
    end if;
    dbms_output.put_line ('Clesed Responsibilities to User:'||p_user_name||' Success');
    fnd_file.put_line(fnd_file.log,'Clesed Responsibilities to User:'||p_user_name||' Success');

    l_territory := get_person_short_territory(p_person_id);
    l_resp      := get_resp_name(l_territory,p_person_id) ;
    l_add_resp  := 'Y';
    begin
      select r.responsibility_key,
             a.application_short_name
      into   l_resp_key,
             l_app_short_name
      from   fnd_responsibility_vl        r,
             fnd_application_vl           a
      where  r.application_id             = a.application_id
      and    upper(r.responsibility_name) = upper(l_resp);
    exception
      when others then
        -- Created User &USERNAME without any Responsibility
        if p_entity <> 'CLOSE' then
          l_message := handle_messages  ('XXOBJET_AUTOCREATE_USER_NO_RES',p_user_name,null);
          errbuf     := l_message;
          retcode    := 1;
        end if;
        l_add_resp := 'N';
    end;
    -- Add Internet Expense responsibility according to Hr Territory
    if l_add_resp = 'Y' then
      fnd_user_pkg.AddResp (username       => p_user_name,
                            resp_app       => l_app_short_name,
                            resp_key       => l_resp_key,
                            security_group => 'STANDARD',
                            description    => null, -- description => ¿Auto Assignment¿
                            start_date     => sysdate,
                            end_date       => null
                            );
      commit;

      -- Responsibility: &RESP is added to the User &USERNAME
      l_message := handle_messages  ('XXOBJET_AUTOCREATE_USER_ADD_EX',l_resp,p_user_name);
      dbms_output.put_line (l_message);
      fnd_file.put_line(fnd_file.log,l_message);
    end if;
  exception
    when others then
      -- Unable to add the responsibility due to &SQLCODE - &SQLERRM
      l_message := handle_messages  ('XXOBJET_AUTOCREATE_USER_UNABLE',SQLCODE,SUBSTR(SQLERRM, 1, 240));
      dbms_output.put_line (l_message);
      fnd_file.put_line(fnd_file.log,l_message);
      errbuf     := l_message;
      retcode    := 2;
      rollback;
  end handle_responsibility;
*/
  --------------------------------------------------------------------
  --  name:            Create user
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   09/09/2012
  --------------------------------------------------------------------
  --  purpose :        CUST530 - Automatic creation of oracle user
  --                   Use API to create new Oracle USER
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  09/09/2012  Dalit A. Raviv    initial build
  --  1.1  27/11/2012  Dalit A. Raviv    add profile to handle password lifespan days
  --                                     add full_name to description
  --  1.2  30/09/2013  Dalit A. Raviv    BUGFIX1036 - handle of user creation 3 days befor start working.
  --                                     create the user without person.
  --------------------------------------------------------------------
  procedure Create_new_user (p_user_name     in  varchar2,
                             p_email_address in  varchar2,
                             --p_person_id   in  number,   -- 1.2 30/09/2013 Dalit A. Raviv
                             p_full_name     in  varchar2,
                             errbuf          out varchar2,
                             retcode         out varchar2) is

    l_session_id  integer        := userenv('sessionid');
    l_password    varchar2(150)  := fnd_profile.value('XXOBJET_AUTOCREATE_USER_PASS'); --'Objet123'
    l_message     varchar2(1000) := null;
    -- 1.1 27/11/2012 Dalit A. Raviv
    l_password_lifespan_days varchar2(20) := fnd_profile.value('XXOBJT_PASSWORD_LIFESPAN_DAYS');
  begin
    errbuf  := null;
    retcode := 0;

    fnd_user_pkg.createuser ( x_user_name              => p_user_name,
                              x_owner                  => null,
                              x_unencrypted_password   => l_password,
                              x_session_number         => l_session_id,
                              --x_employee_id            => p_person_id, -- 1.2 30/09/2013
                              x_password_lifespan_days => l_password_lifespan_days, --90,
                              x_start_date             => sysdate,
                              x_end_date               => null,
                              x_email_address          => p_email_address,
                              x_description            => p_full_name
                              );

    l_message := handle_messages  ('XXOBJET_AUTOCREATE_USER_SUCCES',p_user_name,null);

    errbuf  := l_message;
    retcode := 0;


    --dbms_output.put_line (l_message);
    --fnd_file.put_line(fnd_file.log,l_message);

  exception
    when others then
      -- did not create user set log message to enter to log table
      l_message := handle_messages  ('XXOBJET_AUTOCREATE_USER_ERR',sqlcode,SUBSTR(SQLERRM, 1, 240));
      errbuf  := l_message; --'Unable to create User due to'||SQLCODE||' '||SUBSTR(SQLERRM, 1, 240);
      retcode := 1;

      dbms_output.put_line(l_message);
      fnd_file.put_line(fnd_file.log,l_message);

  end Create_new_user;

  --------------------------------------------------------------------
  --  name:            Update_user_person
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   30/09/2013
  --------------------------------------------------------------------
  --  purpose :        CUST530 - Automatic creation of oracle user
  --                   Use API to create new Oracle USER
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  30/09/2013  Dalit A. Raviv    BUGFIX1036 - handle of user creation 3 days befor start working.
  --                                     create the user without person, add respo and then update the person to the user
  --------------------------------------------------------------------
  procedure Update_user_person (p_user_name in  varchar2,
                                p_person_id in  number,
                                errbuf      out varchar2,
                                retcode     out varchar2) is

    l_message     varchar2(1000) := null;

  begin
    errbuf    := null;
    retcode   := 0;

    FND_USER_PKG.UpdateUser(x_user_name    => p_user_name,  -- i v
                            x_owner        => null,
                            x_employee_id  => p_person_id); -- i n

    l_message := handle_messages  ('XXOBJET_AUTOCREATE_USER_SUCCES',p_user_name,null);

    errbuf  := l_message;
    retcode := 0;

  exception
    when others then
      -- did not update user with person set log message to enter to log table
      l_message := handle_messages  ('XXOBJET_AUTOCREATE_USERPER_ERR',p_user_name, null);
      errbuf    := l_message; -- Did not success to add person to user - &USERNAME
      retcode   := 1;

      dbms_output.put_line(l_message);
      fnd_file.put_line(fnd_file.log,l_message);

  end Update_user_person;

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
                              p_document_type in out varchar2) is

    cursor pop_c is
      select log.log_message, papf.full_name, nvl(papf.employee_number, papf.npw_number) emp_num
      from   xxobjt_autocreate_user_log log,
             per_all_people_f           papf
      where  batch_id                   = p_document_id
      and    log.send_mail              = 'N'
      and    log.log_code               = 'E'
      and    papf.person_id             = log.person_id
      and    trunc(sysdate)             between papf.effective_start_date - g_days and papf.effective_end_date;

    l_msg1 varchar2(1500) := null;
    l_msg2 varchar2(1500) := null;
  begin
    -- Following is a list of employees that had problem to create automatic oracle User:
    fnd_message.SET_NAME('XXOBJT','XXOBJET_AUTOCREATE_USER_LOG');
    l_msg1 := fnd_message.GET;
    -- concatenate start message
    dbms_lob.append(p_document,'<HTML>'||
                               '<BODY><FONT color=blue face="Verdana">'||
                               '<P> </P>'||
                               '<P> '||l_msg1 ||'</P>'||
                               '<P> </P>'
                               );

    -- concatenate table prompts
    dbms_lob.append(p_document,
                    '<div align="left"><TABLE style="COLOR: blue; font size=14" border=1 cellpadding=8>');

    --style="color:blue;text-align:center;font size=20"
    dbms_lob.append(p_document, '<TR align="left">'||
                                   '<TH>Full Name        </TH>'||
                                   '<TH>Employee number  </TH>'||
                                   '<TH>Log Message      </TH>'||
                                '</TR>');

    -- concatenate table values by loop
    FOR pop_r IN pop_c LOOP

      -- Put value to HTML table
      dbms_lob.append(p_document,
                      '<TR>'||
                         '<TD>'||pop_r.full_name   ||'</TD>'||
                         '<TD>'||pop_r.emp_num     ||'</TD>'||
                         '<TD>'||pop_r.log_message ||'</TD>'||
                      '</TR>');
    END LOOP;
    -- concatenate close table
    dbms_lob.append(p_document,'</TABLE> </div>');
    dbms_lob.append(p_document,'<P> </P>'||
                               '&nbsp'||
                               '<P> </P>');
    -- add fotter meaasge
    fnd_message.SET_NAME('XXOBJT','XXOBJT_MAIL_FOOTER');
    l_msg2 := fnd_message.GET;
    dbms_lob.append(p_document,l_msg2);

    p_document_type := 'TEXT/HTML' || ';name=' || 'LOG.HTML';
  exception
    when others then
      wf_core.CONTEXT('XXOBJT_AUTO_CREATE_USER_PKG',
                      'XXOBJT_AUTO_CREATE_USER_PKG.prepare_log_body',
                      p_document_id,
                      p_display_type);
      raise;
  end prepare_log_body;

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
                           retcode    out varchar2) is

    cursor pop_c is
      select log.log_code, log.log_id, log.log_message, papf.full_name, nvl(papf.employee_number, papf.npw_number) emp_num
      from   xxobjt_autocreate_user_log log,
             per_all_people_f           papf
      where  batch_id                   = p_batch_id
      and    log.send_mail              = 'N'
      and    log.log_code               = 'E'
      and    papf.person_id             = log.person_id
      and    trunc(sysdate)             between papf.effective_start_date - g_days and papf.effective_end_date;

    l_to_user_name varchar2(150) := null;
    l_bcc          varchar2(150) := null;
    l_subject      varchar2(360) := null;
    l_att1_proc    varchar2(150) := null;
    l_att2_proc    varchar2(150) := null;
    l_att3_proc    varchar2(150) := null;
    l_err_code     number        := 0;
    l_err_desc     varchar2(1000):= null;
    l_profile      varchar2(150) := fnd_profile.value('XXOBJT_ENABLE_USER_BCC_MAIL');  -- Y/N
    l_env          varchar2(50)  := null;
    l_count        number;
  begin
    errbuf  := null;
    retcode := 0;

    begin
      select count(1)
      into   l_count
      from   xxobjt_autocreate_user_log log
      where  batch_id                   = 0
      and    log.send_mail              = 'N'
      and    log.log_code               = 'E';
    end;

    if l_count > 0 then
      l_env :=  xxobjt_fnd_attachments.get_environment_name;
      --Auto Create Oracle User
      fnd_message.SET_NAME('XXOBJT','XXOBJET_AUTOCREATE_USER_SUBJ');
      l_subject      := fnd_message.get;
      l_err_code     := 0;
      l_err_desc     := null;

      if l_env = 'PROD' then
        l_to_user_name := 'ORACLE.HELPDESK';
      else
        l_to_user_name := 'DALIT.RAVIV';
      end if;

      if nvl(l_profile,'N') = 'Y' then
        l_bcc        := fnd_profile.value('XXHR_ELEMENT_SEND_MAIL_BCC');-- Dalit.raviv@objet.com
      else
        l_bcc        := null;
      end if;

      xxobjt_wf_mail.send_mail_body_proc
                    (p_to_role     => l_to_user_name,     -- i v
                     p_cc_mail     => null,               -- i v
                     p_bcc_mail    => l_bcc,              -- i v
                     p_subject     => l_subject,          -- i v
                     p_body_proc   => 'XXOBJT_AUTO_CREATE_USER_PKG.prepare_log_body/'||p_batch_id, -- i v
                     p_att1_proc   => l_att1_proc,        -- i v
                     p_att2_proc   => l_att2_proc,        -- i v
                     p_att3_proc   => l_att3_proc,        -- i v
                     p_err_code    => l_err_code,         -- o n
                     p_err_message => l_err_desc);        -- o v

      if nvl(l_err_code,0) > 0 then
        errbuf  := l_err_desc;
        retcode := l_err_code;
        dbms_output.put_line('Error Send Mail - '||l_err_desc);
        fnd_file.put_line(fnd_file.log,'Error Send Mail - '||l_err_desc);
      else
        for pop_r in pop_c loop
          update xxobjt_autocreate_user_log
          set    send_mail = 'Y'
          where  log_id    = pop_r.log_id;
          commit;
        end loop;
      end if; -- l_err_code
    end if; -- l_count
  exception
    when others then
      dbms_output.put_line('GEN EXE Error Send Mail - '||l_err_desc);
      fnd_file.put_line(fnd_file.log,'GEN EXE Error Send Mail - '||l_err_desc);
  end send_log_mail;

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
                         retcode   out varchar2) is
    cursor pop_c is
      select fu.user_name
      from   fnd_user       fu
      where  1              = 1
      --and    fu.employee_id is not null
      and    fu.end_date    is null
      and    fu.user_name   not in ('SCHEDULER','SYSADMIN','AGILE','ORACLE.HELPDESK','ORACLE_CS','ORACLE_FIN','ORACLE_HR',
                                    'ORACLE_OPERATION','CONVERSION','ISUPPORT', 'IBE_GUEST','PILOT_TEST1','PILOT_TEST',
                                    'YUVAL.TAL','ROMAN.VAINTRAUB','ORIT.DEKEL','EITAN.AFIK','DROR.PANHI','DOVIK.POLLAK',
                                    'DALIT.RAVIV','ALON.SHALOM','ADI.SAFIN','AMIR.DEI', 'SALESFORCE','FSR','IBE_ADMIN')
      order by 1, fu.user_name;

    --l_session_id             integer      := userenv('sessionid');
    l_password_lifespan_days varchar2(20) := fnd_profile.value('XXOBJT_PASSWORD_LIFESPAN_DAYS');
  begin
    errbuf  := null;
    retcode := 0;
    for pop_r in pop_c loop
      begin
      fnd_user_pkg.UpdateUser(x_user_name => pop_r.user_name,
                              x_owner => null ,
                              x_password_lifespan_days => l_password_lifespan_days);
      exception
        when others then
          dbms_output.put_line('ERR - '|| substr(sqlerrm,1,240));
      end;
    end loop;

    commit;
  exception
    when others then
      dbms_output.put_line('GEN ERR - '|| substr(sqlerrm,1,240));
      errbuf  := 'GEN ERR - '|| substr(sqlerrm,1,240);
      retcode := 1;
  end main_update;

  --------------------------------------------------------------------
  --  name:            main
  --  create by:       Dalit A. Raviv
  --  Revision:        1.3
  --  creation date:   06/09/2012
  --------------------------------------------------------------------
  --  purpose :        CUST530 - Automatic creation of oracle user
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  06/09/2012  Dalit A. Raviv    initial build
  --  1.1  27/11/2012  Dalit A. Raviv    Add full_name at user description fields
  --                                     add email address to user fields
  --                                     change password number of days from 90 to 180
  --  1.2  24/06/2013  Dalit A. Raviv    correct user name, APJ use () at first name ,
  --                                     this cause the api to finish with error.
  --  1.3  01/09/2013  Dalit A. Raviv    correct code to create the user 3 days before
  --
  --------------------------------------------------------------------
  procedure main (errbuf    out varchar2,
                  retcode   out varchar2) is

    -- get all persons that start to work today and do not have oracle user
    cursor pop_c (p_days in number) is
      select period.entity,
             period.person_id,
             papf.full_name,
             papf.first_name,
             papf.last_name,
             -- 1.1 27/11/2012 Dalit A. Raviv
             papf.email_address,
             case when instr(papf.first_name,'(') > 0 then
                    replace(replace(upper((substr(papf.first_name,1,instr(papf.first_name,'(') -1))||'.'||papf.last_name),' ',''),'''','')
                  else
                    replace(replace(upper(papf.first_name||'.'||papf.last_name),' ',''),'''','')
             end user_name,
             nvl(papf.employee_number,papf.npw_number) emp_number,
             period.date_start,
             period.creation_date,
             trunc(greatest(period.date_start,period.creation_date)) greatest,
             period.actual_termination_date
      from   xxhr_per_periods_of_work_v period,
             per_all_people_f           papf
      where  trunc(greatest(period.date_start,period.creation_date)) between trunc(sysdate) - /*1*/p_days and trunc(sysdate) + p_days
        and    period.person_id           = papf.person_id
      -- 1.3 01/09/2013 Dalit A. Raviv
      and    trunc(sysdate)   + p_days    between papf.effective_start_date - p_days and papf.effective_end_date
      -- this is chacking that this person did not created allready manualy.
      and    not exists                 (select employee_id
                                         from   fnd_user    fu
                                         where  employee_id = papf.person_id
                                         and    (fu.end_date is null or fu.end_date > trunc(sysdate)))
      --and period.person_id = 11022  -- !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
      -- 24/06/2014 Dalit A. Raviv
      -- CHG0032452 Responsibilities for new users
      -- Us employees do not use responsibility - internet expense US , consult with Laura, we decided that we will not create the
      -- users for employees from NA or Corp US territories.
      and    xxobjt_auto_create_user_pkg.get_person_short_territory(papf.person_id) not in ( 'NA' ,'Corp US')
      order by 7;

    l_person_id   number;
    l_end_date    date;
    l_user_name   varchar2(150);
    l_check_user  varchar2(5)    := 'N';
    l_user_exist  varchar2(5)    := 'N';
    l_message     varchar2(1000) := null;
    l_err_code    number ;
    l_err_desc    varchar2(1000);
    l_err_desc1   varchar2(1000);
    l_resp_name   varchar2(240);
    l_count       number         := 0;
    l_person_type varchar2(500)  := null;
    --l_days        number         := fnd_profile.value('XXOBJET_AUTOCREATE_USER_DAYS');

    gen_exception exception;
  begin
    errbuf  := null;
    retcode := 0;

    --fnd_global.APPS_INITIALIZE(user_id => 2470,resp_id => 20420,resp_appl_id => 1);  -- !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

    for pop_r in pop_c(g_days) loop
      l_count := l_count +1;
      exit;
    end loop;
    if l_count > 0 then
      select xxobjt_autouser_batch_log_s.nextval
      into   g_batch_id
      from   dual;
    end if;
    for pop_r in pop_c (g_days) loop

      dbms_output.put_line('---');
      dbms_output.put_line('User name - '||pop_r.user_name);
      fnd_file.put_line(fnd_file.log,'---');
      fnd_file.put_line(fnd_file.log,'User name - '||pop_r.user_name);

      l_check_user  := 'N';
      l_user_exist  := 'N';
      l_err_code    := 0;
      l_err_desc    := null;
      l_person_id   := null;
      l_end_date    := null;
      l_user_name   := null;
      l_message     := null;
      l_resp_name   := null;
      l_person_type := null;
      -- check if person allready exists in user table as open user
      begin
        select employee_id, fu.end_date, fu.user_name
        into   l_person_id, l_end_date,  l_user_name
        from   fnd_user     fu
        where  employee_id  = pop_r.person_id;

        if l_end_date is null then
          -- Person exists in User table - user -  &USERNAME Person id - &PERSON
          l_message := handle_messages  ('XXOBJET_AUTOCREATE_USER_PERSON',l_user_name,pop_r.full_name);
          dbms_output.put_line(l_message);
          fnd_file.put_line(fnd_file.log,l_message);
          -- enter to log table
          insert_log(p_person_id  => pop_r.person_id ,   -- i n
                     p_full_name  => pop_r.full_name,    -- i v
                     p_log_code   => 'E',                -- i v
                     p_log_msg    => l_message,          -- i v
                     p_user_name  => pop_r.user_name,    -- i v
                     p_resp       => null,               -- i v
                     p_err_code   => l_err_code,         -- o n
                     p_err_desc   => l_err_desc);        -- o v
        else
          -- close all responsibilities
          -- Exist closed Oracle User &USERNAME for person &PERSON
          l_message := handle_messages  ('XXOBJET_AUTOCREATE_USER_CLOSE',l_user_name,pop_r.full_name);
          dbms_output.put_line(l_message);
          fnd_file.put_line(fnd_file.log,l_message);
          -- enter to log table
          insert_log(p_person_id  => pop_r.person_id ,   -- i n
                     p_full_name  => pop_r.full_name,    -- i v
                     p_log_code   => 'E',                -- i v
                     p_log_msg    => l_message,          -- i v
                     p_user_name  => pop_r.user_name,    -- i v
                     p_resp       => null,               -- i v
                     p_err_code   => l_err_code,         -- o n
                     p_err_desc   => l_err_desc);        -- o v
          l_err_code   := 0;
          l_err_desc   := null;
          --  Closed responsibilities and give new correct one
          close_responsibility ( p_user_name     => pop_r.user_name, -- i v
                                 errbuf          => l_err_desc,      -- o v
                                 retcode         => l_err_code);     -- o v
        end if;

      exception
        when NO_DATA_FOUND then
          l_check_user := 'Y';
        when others then
          l_check_user := 'Y';
      end;
      -- Person do not exist but the same user name exist.
      if l_check_user = 'Y' then
        l_message := null;
        begin
          select 'Y'
          into   l_user_exist
          from   fnd_user     fu
          where  fu.user_name = pop_r.user_name;
          -- Same User Name exists in User table - &USERNAME
          l_message := handle_messages  ('XXOBJET_AUTOCREATE_USER_EXIST',pop_r.user_name,null);
          dbms_output.put_line(l_message);
          fnd_file.put_line(fnd_file.log,l_message);

          -- enter person to log table
          insert_log(p_person_id  => pop_r.person_id ,   -- i n
                     p_full_name  => pop_r.full_name,    -- i v
                     p_log_code   => 'E',                -- i v
                     p_log_msg    => l_message,          -- i v
                     p_user_name  => pop_r.user_name,    -- i v
                     p_resp       => null,               -- i v
                     p_err_code   => l_err_code,         -- o n
                     p_err_desc   => l_err_desc);        -- o v

        exception
          when NO_DATA_FOUND then
            -- create user
            l_err_code   := 0;
            l_err_desc   := null;
            l_err_desc1  := null;
            -- check person is employee -
            -- get user_person_type
            l_person_type := HR_PERSON_TYPE_USAGE_INFO.GET_USER_PERSON_TYPE(trunc(pop_r.greatest),
                                                                            pop_r.person_id);
            if instr(l_person_type,'.')  > 0 then
              l_person_type := substr(l_person_type,1,instr(l_person_type,'.') -1);
            end if;

            If l_person_type <> 'Employee' then
              -- Person &NAME, created with Person Type - &PERSONTYPE. Need Manager approval for user creation.
              l_message := handle_messages  ('XXOBJET_AUTOCREATE_PERSON_TYPE',pop_r.full_name,l_person_type);
              dbms_output.put_line(l_message);
              fnd_file.put_line(fnd_file.log,l_message);

              -- enter person to log table
              insert_log(p_person_id  => pop_r.person_id ,   -- i n
                         p_full_name  => pop_r.full_name,    -- i v
                         p_log_code   => 'E',                -- i v
                         p_log_msg    => l_message,          -- i v
                         p_user_name  => pop_r.user_name,    -- i v
                         p_resp       => null,               -- i v
                         p_err_code   => l_err_code,         -- o n
                         p_err_desc   => l_err_desc);        -- o v
            else
              l_err_desc := null;
              l_err_code := 0;
              -- 1.1 27/11/2012 Dalit A. Raviv
              Create_new_user (p_user_name     => pop_r.user_name, -- i v
                               p_email_address => pop_r.email_address, -- i v -- xxhr_util_pkg.get_person_email (pop_r.person_id),
                               --p_person_id     => pop_r.person_id,   -- i n -- 30/09/2013 Dalit A. Raviv
                               p_full_name     => pop_r.full_name, -- i v
                               errbuf          => l_err_desc,      -- o v
                               retcode         => l_err_code);     -- o v
              -- end 1.1 27/11/2012

              if l_err_code <> 0 then
                -- enter to log table
                insert_log(p_person_id  => pop_r.person_id,      -- i n
                           p_full_name  => pop_r.full_name,      -- i v
                           p_log_code   => 'E',                  -- i v
                           p_log_msg    => l_err_desc,           -- i v
                           p_user_name  => pop_r.user_name,      -- i v
                           p_resp       => null,                 -- i v
                           p_err_code   => l_err_code,           -- o n
                           p_err_desc   => l_err_desc1);         -- o v

                 dbms_output.put_line (l_err_desc);
                 fnd_file.put_line(fnd_file.log,'User - '||l_err_desc);
              else
                l_err_code   := 0;
                l_err_desc   := null;
                Add_responsibility(p_user_name     => pop_r.user_name, -- i v
                                   p_person_id     => pop_r.person_id, -- i n
                                   p_resp_name     => l_resp_name,     -- o v
                                   errbuf          => l_err_desc,      -- o v
                                   retcode         => l_err_code);     -- o v

                if  l_err_code <> 0 then
                  insert_log(p_person_id  => pop_r.person_id ,   -- i n
                             p_full_name  => pop_r.full_name,    -- i v
                             p_log_code   => 'E',                -- i v
                             p_log_msg    => l_err_desc,         -- i v
                             p_user_name  => pop_r.user_name,    -- i v
                             p_resp       => l_resp_name,        -- i v
                             p_err_code   => l_err_code,         -- o n
                             p_err_desc   => l_err_desc1);       -- o v
                  dbms_output.put_line (l_err_desc);
                  fnd_file.put_line(fnd_file.log,'Resp - '||l_err_desc);
                  rollback;
                else

                  -- update user
                  l_err_code   := 0;
                  l_err_desc   := null;
                  Update_user_person (p_user_name => pop_r.user_name, -- i v
                                      p_person_id => pop_r.person_id, -- i n
                                      errbuf      => l_err_desc,      -- o v
                                      retcode     => l_err_code );    -- o v
                  if l_err_code <> 0 then
                    insert_log(p_person_id  => pop_r.person_id ,   -- i n
                               p_full_name  => pop_r.full_name,    -- i v
                               p_log_code   => 'E',                -- i v
                               p_log_msg    => l_err_desc,         -- i v
                               p_user_name  => pop_r.user_name,    -- i v
                               p_resp       => l_resp_name,        -- i v
                               p_err_code   => l_err_code,         -- o n
                               p_err_desc   => l_err_desc1);       -- o v

                    dbms_output.put_line (l_err_desc);
                    fnd_file.put_line(fnd_file.log,l_err_desc);
                    rollback;
                  else
                    insert_log(p_person_id  => pop_r.person_id ,   -- i n
                             p_full_name  => pop_r.full_name,    -- i v
                             p_log_code   => 'S',                -- i v
                             p_log_msg    => 'Success Create User', -- i v
                             p_user_name  => pop_r.user_name,    -- i v
                             p_resp       => l_resp_name,        -- i v
                             p_err_code   => l_err_code,         -- o n
                             p_err_desc   => l_err_desc1);       -- o v

                     dbms_output.put_line (l_err_desc);
                     fnd_file.put_line(fnd_file.log,l_err_desc);
                    commit;
                  end if;

                  -- send mail to person, manager and helpdesk will be done by alert ---!!!
                end if; -- handle_responsibility
              end if; -- Create_new_user
            end if; -- check person type
        end;
      end if;-- l_check_user
    end loop;
    -- send mail to helpdesk on error users
    -- Alert will send the success user creation, to person and it manager.
    if nvl(fnd_profile.value('XXOBJET_AUTOCREATE_USER_HD'),'N') = 'Y' then
      l_err_code := 0;
      l_err_desc := null;

      send_log_mail (p_batch_id => g_batch_id,  -- i n
                     errbuf     => l_err_desc,  -- o v
                     retcode    => l_err_code); -- o v
    end if;
  end main;


end XXOBJT_AUTO_CREATE_USER_PKG;
/