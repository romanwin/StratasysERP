create or replace package body xxfnd_resp_api_pkg is

  -------------------------------------------------------------------------------------------------------
  --  name:               xxfnd_resp_api_pkg
  --  create by:          dan melamed
  --  revision:           1.0
  --  creation date:      10-jul-2018
  --  purpose :           package used to copy responsibilities from user a to user b
  -------------------------------------------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   10-jul-2018   dan melamed     initial build - chg0043086 - create user ebs  responsibilities
  --  1.1   04/12/2018    Roman W.        CHG0044523 - Copy from program
  --  1.3   09/12/2018    Roman W.        CHG0043902-CTASK0039588 except users with user_id <=1111
  --  1.4   23/12/2018    Roman W.        CHG0043902-CTASK0039841 exclude user AME_USER
  --  1.5   25/12/2018    Roman W.        CHG0043902-CTASK0039472 : fr.application_id = fa.application_id
  --  1.6   13/02/2019    Roman W         CHG0044882 - Bug Fix Related to Copy From Program (CHG0043086)
  --  1.7   23/12/2019    Roman W.        INC0176753 - buffer to small exception 
  --------------------------------------------------------------------------------------------------------

  --------------------------------------------------------------------
  --  name:               log_error_copy_responsibility
  --  create by:          dan melamed
  --  revision:           1.0
  --  creation date:      10-jul-2018
  --  purpose :           log each responsibility that could not be copied (for later email)
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   10-jul-2018   dan melamed     initial build - chg0043086 - create user ebs  responsibilities
  -----------------------------------------------------------------------
  procedure log_error_copy_responsibility(p_from           varchar2,
                                          p_to             varchar2,
                                          p_ticket         varchar2,
                                          p_responsibility varchar2,
                                          p_app            varchar2,
                                          p_status         varchar2,
                                          p_comment        varchar2) is
  
    pragma autonomous_transaction;
  begin
  
    insert into xxobjt.xxfnd_user_resp_error_t
      (copy_from,
       copy_to,
       snow_ticket,
       responsibility,
       responsibiity_app,
       status,
       comments,
       last_update_on,
       last_update_by)
    values
      (p_from,
       p_to,
       p_ticket,
       p_responsibility,
       p_app,
       p_status,
       substr(p_comment, 1, 200),
       sysdate,
       fnd_global.user_id);
  
    commit;
  
    -- main exception handles this exception
  end log_error_copy_responsibility;
  ----------------------------------------------------------------------------------------------------
  -- Ver       When        Who              Description
  -- --------  ----------  ---------------  ----------------------------------------------------------
  -- 1.0       03/11/2018  Roman W.         CHG0044523 - Copy from program malfunction - (CHG0043086)
  -- 1.1       13/02/2019  Roman W          CHG0044882 - Bug Fix Related to Copy From Program (CHG0043086)
  ----------------------------------------------------------------------------------------------------
  PROCEDURE addresp(p_from_user              in varchar2,
                    p_to_user                in varchar2,
                    p_responsibility_name    in varchar2,
                    p_application_short_name in varchar2,
                    p_responsibility_key     in varchar2,
                    p_security_group_key     in varchar2,
                    p_start_date             in date,
                    p_end_date               in date,
                    p_ticket                 in varchar2,
                    p_status_code            out varchar2,
                    p_error_code             out varchar2,
                    p_error_desc             out varchar2) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
    l_full_error   varchar2(32676);
    l_granting_err varchar2(255);
    -- email parameters
    l_subject     varchar2(2000);
    l_body        varchar2(32676);
    l_err_code    number;
    l_err_message varchar2(2000);
  BEGIN
  
    xxaccntx.set_cse(true);
    xxaccntx.set_context('FNDSCAUS');
  
    fnd_user_pkg.addresp(username       => p_to_user,
                         resp_app       => p_application_short_name,
                         resp_key       => p_responsibility_key,
                         security_group => p_security_group_key,
                         start_date     => p_start_date,
                         end_date       => p_end_date,
                         description    => p_ticket); -- take original end date from the 'from' user
  
    commit;
    p_status_code := 'S';
  
  exception
    when others then
    
      p_status_code := 'E';
      l_full_error  := substr(sqlerrm, 1, 32000);
      if abs(sqlcode) > 20000 then
        -- custom error
      
        begin
        
          select flv.description
            into l_granting_err
            from fnd_lookup_values flv
           where flv.lookup_type = 'XXFND_TRANSLATE_SOD_ERRORS'
             and flv.language = nvl(userenv('LANG'), 'US')
             and l_full_error like '%' || flv.meaning || '%';
        
          begin
            l_subject := substr('SOD Conflicts Error Notification (' ||
                                p_ticket || ')',
                                1,
                                2000);
            fnd_message.SET_NAME(APPLICATION => 'XXOBJT',
                                 NAME        => 'XXFND_COPY_FROM_SOD_EMAIL_BODY');
            fnd_message.SET_TOKEN(TOKEN => 'USER_NAME', VALUE => p_to_user);
            fnd_message.SET_TOKEN(TOKEN => 'RESP_NAME',
                                  VALUE => p_responsibility_name);
            fnd_message.SET_TOKEN(TOKEN => 'ERROR',
                                  VALUE => l_granting_err);
          
            l_body := fnd_message.get;
            xxiby_process_cust_paymt_pkg.send_smtp_mail(p_msg_to        => 'S_Now-Apps_SysAdmin@stratasys.com',
                                                        p_msg_from      => fnd_profile.VALUE('XXAC_SOD_NOTIFY_FROM_EMAIL'),
                                                        p_msg_subject   => l_subject,
                                                        p_msg_text_html => l_body,
                                                        p_err_code      => l_err_code,
                                                        p_err_message   => l_err_message);
          
            p_error_desc := substr(l_granting_err, 1, 2000); -- CHG0044882
          
          exception
            when others then
              -- no error handling , aproved by Sagi Sofer --
              null;
          end;
        exception
          when others then
            l_granting_err := 'Error - could not be translated - ' ||
                              substr(l_full_error, 1, 180);
        end;
      else
        l_granting_err := 'Responsibility grant error : ' ||
                          substr(sqlerrm, 1, 180);
      end if;
      rollback;
      p_status_code := 'E';
      p_error_desc  := substr(l_granting_err, 1, 2000); -- CHG0044882
      log_error_copy_responsibility(p_from           => p_from_user,
                                    p_to             => p_to_user,
                                    p_ticket         => p_ticket,
                                    p_responsibility => p_responsibility_name,
                                    p_app            => p_application_short_name,
                                    p_status         => 'E',
                                    p_comment        => l_granting_err);
      commit;
    
  END addresp;

  --------------------------------------------------------------------
  --  name:               copy_responsibilities
  --  create by:          dan melamed
  --  revision:           1.0
  --  creation date:      10-jul-2018
  --  purpose :           copy all responsibilities from user a to user b
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   10-jul-2018   dan melamed     initial build - chg0043086 - create user ebs  responsibilities
  --  1.1   23/12/2019    Roman W.        INC0176753 - buffer to small exception 
  -----------------------------------------------------------------------
  procedure copy_responsibilities(p_from_user   varchar2,
                                  p_to_user     varchar2,
                                  p_start_date  date,
                                  p_ticket      varchar2,
                                  p_status_code out varchar2,
                                  p_status_text out varchar2) is
  
    -- cursor holding current employee (from) responsibilities (non closed ones)
    cursor c_copy_from_resps(c_from_user varchar2, c_start_date date) is
      select resp.responsibility_key,
             resptl.responsibility_name,
             furgd.start_date,
             furgd.end_date,
             furgd.responsibility_application_id,
             app.application_short_name,
             furgd.responsibility_id,
             furgd.security_group_id,
             secg.security_group_key,
             us.start_date user_start_date
        from fnd_user_resp_groups_direct furgd,
             fnd_responsibility          resp,
             fnd_responsibility_tl       resptl,
             fnd_user                    us,
             fnd_application             app,
             fnd_security_groups         secg
       where (furgd.responsibility_id, furgd.responsibility_application_id) in
             (select responsibility_id, application_id
                from fnd_responsibility
               where (version = '4' or version = 'W' or version = 'M' or
                     version = 'H'))
         and (us.user_id = furgd.user_id)
         and resp.responsibility_id = furgd.responsibility_id
         and resp.application_id = furgd.responsibility_application_id
         and resptl.application_id = furgd.responsibility_application_id
         and resptl.responsibility_id = furgd.responsibility_id
         and resptl.application_id = app.application_id
         and nvl(userenv('LANG'), 'US') = resptl.language
         and resptl.responsibility_name not like 'Internet Expenses%'
         and us.user_name = c_from_user
         and secg.security_group_id = furgd.security_group_id
         and c_start_date between trunc(furgd.start_date) and
             trunc(nvl(furgd.end_date, hr_general.end_of_time)); -- only responsibilities active on copy date
  
    -- cursor holding current employee (to) responsibilities, excluding the ones 'FROM' has  (non closed ones)
    cursor c_to_user_resps(c_from_user  varchar2,
                           c_to_user    varchar2,
                           c_start_date date) is
      select resp.responsibility_key,
             resptl.responsibility_name,
             furgd.start_date,
             furgd.end_date,
             furgd.responsibility_application_id,
             app.application_short_name,
             furgd.responsibility_id,
             furgd.security_group_id,
             secg.security_group_key,
             us.start_date user_start_date
        from fnd_user_resp_groups_direct furgd,
             fnd_responsibility          resp,
             fnd_responsibility_tl       resptl,
             fnd_user                    us,
             fnd_application             app,
             fnd_security_groups         secg
       where (furgd.responsibility_id, furgd.responsibility_application_id) in
             (select responsibility_id, application_id
                from fnd_responsibility
               where (version = '4' or version = 'W' or version = 'M' or
                     version = 'H'))
         and (us.user_id = furgd.user_id)
         and resp.responsibility_id = furgd.responsibility_id
         and resp.application_id = furgd.responsibility_application_id
         and resptl.application_id = furgd.responsibility_application_id
         and resptl.responsibility_id = furgd.responsibility_id
         and resptl.application_id = app.application_id
         and nvl(userenv('LANG'), 'US') = resptl.language
         and resptl.responsibility_name not like 'Internet Expenses%'
         and us.user_name = c_to_user
         and secg.security_group_id = furgd.security_group_id
         and c_start_date between trunc(furgd.start_date) and
             trunc(nvl(furgd.end_date, hr_general.end_of_time)) -- responsibilities active on copy date
         and not exists -- responsibility is not current in the original (from) user open in copy date
       (select 1
                from fnd_user_resp_groups_direct f_furgd, fnd_user f_us
               where f_us.user_id = f_furgd.user_id
                 and f_furgd.responsibility_id = furgd.responsibility_id
                 and f_furgd.responsibility_application_id =
                     furgd.responsibility_application_id
                 and f_furgd.security_group_id = furgd.security_group_id
                 and c_start_date between trunc(f_furgd.start_date) and
                     trunc(nvl(f_furgd.end_date, hr_general.end_of_time))
                 and f_us.user_name = c_from_user);
  
    l_responsibility_exists number;
    l_orig_to_date          date;
    l_to_userid             number;
    l_orig_start_date       date;
    l_orig_desc             varchar2(500);
    l_close_date            date;
    l_future_removed        boolean;
    l_full_error            varchar2(32000);
    l_granting_err          varchar2(255);
    l_error_code            varchar2(255);
    l_error_desc            varchar2(4000);
  
  begin
    p_status_code := 'S';
    p_status_text := null;
  
    -- copy new responsibilities
    for rec in c_copy_from_resps(p_from_user, p_start_date) loop
    
      begin
      
        l_granting_err   := null;
        l_future_removed := false;
      
        begin
        
          -- check if responsibility exists for local (to) user
          select '1',
                 trunc(furgd_to.end_date),
                 us_to.user_id,
                 trunc(furgd_to.start_date),
                 furgd_to.description
            into l_responsibility_exists,
                 l_orig_to_date,
                 l_to_userid,
                 l_orig_start_date,
                 l_orig_desc
            from fnd_user_resp_groups_direct furgd_to, fnd_user us_to
           where us_to.user_id = furgd_to.user_id
             and us_to.user_name = p_to_user
             and furgd_to.responsibility_id = rec.responsibility_id
             and furgd_to.responsibility_application_id =
                 rec.responsibility_application_id
             and furgd_to.security_group_id = rec.security_group_id;
        
        exception
          when no_data_found then
            l_responsibility_exists := 0;
        end;
      
        if l_responsibility_exists = 0 then
        
          l_error_desc := null;
        
          addresp(p_from_user              => p_from_user,
                  p_to_user                => p_to_user,
                  p_responsibility_name    => rec.responsibility_name,
                  p_application_short_name => rec.application_short_name,
                  p_responsibility_key     => rec.responsibility_key,
                  p_security_group_key     => rec.security_group_key,
                  p_start_date             => p_start_date,
                  p_end_date               => rec.end_date,
                  p_ticket                 => p_ticket,
                  p_status_code            => p_status_code,
                  p_error_code             => l_error_code,
                  p_error_desc             => l_error_desc);
        
          if p_status_code = 'E' then
            p_status_text := substr(p_status_text || ' ,' || l_error_desc,
                                    1,
                                    1000); -- INC0176753 changed from 2000 -> 1000
          
            continue;
          end if;
        
        else
          -- responsibility *does* exist for user 'TO', check if need to update.
        
          if l_orig_desc is null then
            l_orig_desc := p_ticket;
          else
            l_orig_desc := l_orig_desc || ', ' || p_ticket;
          end if;
        
          -- Take only last 200 characters of the comment, if already more than 200.
          if length(l_orig_desc) > 200 then
            l_orig_desc := substr(l_orig_desc, -200);
          end if;
        
          if l_orig_start_date > p_start_date then
            -- responsibility exists in future for employee --> error out.
            p_status_code := 'E';
            log_error_copy_responsibility(p_from           => p_from_user,
                                          p_to             => p_to_user,
                                          p_ticket         => p_ticket,
                                          p_responsibility => rec.responsibility_name,
                                          p_app            => rec.application_short_name,
                                          p_status         => 'E',
                                          p_comment        => 'Responsibility already exists in the future for user');
            continue; -- continue to next responsibility
          
          end if;
        
          if rec.end_date is null then
            -- in the 'from' , the responsibility is open
          
            if l_orig_to_date is not null then
              -- in the 'To', the responsibility is  closed. need to re-open it.
              -- if both null, no need to do anything. (this is why no else for this if)
            
              addresp(p_from_user              => p_from_user,
                      p_to_user                => p_to_user,
                      p_responsibility_name    => rec.responsibility_name,
                      p_application_short_name => rec.application_short_name,
                      p_responsibility_key     => rec.responsibility_key,
                      p_security_group_key     => rec.security_group_key,
                      p_start_date             => l_orig_start_date,
                      p_end_date               => null,
                      p_ticket                 => l_orig_desc,
                      p_status_code            => p_status_code,
                      p_error_code             => l_error_code,
                      p_error_desc             => l_error_desc);
            
              if p_status_code = 'E' then
                p_status_text := substr(p_status_text || ' ,' ||
                                        l_error_desc,
                                        1,
                                        1000); -- INC0176753 changed from 2000 -> 1000
                continue;
              end if;
            end if;
          
          else
            -- 'From' responsibility is *closed* (it will be after 'copy' date, otherwise would not be in cursor)
          
            if trunc(nvl(rec.end_date, hr_general.end_of_time)) <
               l_orig_start_date then
              -- nvl here just for the < sake. end of time is always larger than any date.
              -- can not set end date to be before already existing start date -- raise error.
              -- neither can be null : 'from' has end date, and the employee has the responsibility so there is a start date.
              p_status_code := 'E';
              log_error_copy_responsibility(p_from           => p_from_user,
                                            p_to             => p_to_user,
                                            p_ticket         => p_ticket,
                                            p_responsibility => rec.responsibility_name,
                                            p_app            => rec.application_short_name,
                                            p_status         => 'E',
                                            p_comment        => 'Could not set end date prior to start date');
              continue; -- to next responsibility.
            else
            
              addresp(p_from_user              => p_from_user,
                      p_to_user                => p_to_user,
                      p_responsibility_name    => rec.responsibility_name,
                      p_application_short_name => rec.application_short_name,
                      p_responsibility_key     => rec.responsibility_key,
                      p_security_group_key     => rec.security_group_key,
                      p_start_date             => l_orig_start_date,
                      p_end_date               => rec.end_date,
                      p_ticket                 => l_orig_desc,
                      p_status_code            => p_status_code,
                      p_error_code             => l_error_code,
                      p_error_desc             => l_error_desc);
            
              if p_status_code = 'E' then
                p_status_text := substr(p_status_text || ' ,' ||
                                        l_error_desc,
                                        1,
                                        1000); -- INC0176753 changed from 2000 -> 1000
                continue;
              end if;
            
            end if;
          end if;
        
        end if;
      
      exception
        when others then
          p_status_code := 'E';
          p_status_text := 'Unexpected Error  ' || sqlerrm;
        
          return; -- unexpected error - break with error.
      end;
    end loop;
  
    -- close old responsibilities ?
    for rec in c_to_user_resps(p_from_user, p_to_user, p_start_date) loop
      begin
      
        -- get current description to concatanate ticket number to.
        select furgd_to.description
          into l_orig_desc
          from fnd_user_resp_groups_direct furgd_to, fnd_user us_to
         where us_to.user_id = furgd_to.user_id
           and us_to.user_name = p_to_user
           and furgd_to.responsibility_id = rec.responsibility_id
           and furgd_to.responsibility_application_id =
               rec.responsibility_application_id
           and furgd_to.security_group_id = rec.security_group_id;
      
        -- At this point I KNOW that the responsibility needs to be closed, as it does not exist on the 'from'.
        -- and is not an 'Internet expense'.
      
        -- get which date i should close the current (not exist in 'from') responsibilities
        l_close_date := greatest(rec.start_date, p_start_date); -- if current responsibility start date is larger than copy start date,
        -- end the responsibility on the same day (as resp start date)
        -- Responsibility granted can not be deleted, at most it can be ended on same date.
      
        if l_orig_desc is null then
          l_orig_desc := p_ticket;
        else
          l_orig_desc := l_orig_desc || ', ' || p_ticket;
        end if;
      
        if length(l_orig_desc) > 200 then
          l_orig_desc := substr(l_orig_desc, -200);
        end if;
      
        addresp(p_from_user              => p_from_user,
                p_to_user                => p_to_user,
                p_responsibility_name    => rec.responsibility_name,
                p_application_short_name => rec.application_short_name,
                p_responsibility_key     => rec.responsibility_key,
                p_security_group_key     => rec.security_group_key,
                p_start_date             => rec.start_date,
                p_end_date               => l_close_date,
                p_ticket                 => l_orig_desc,
                p_status_code            => p_status_code,
                p_error_code             => l_error_code,
                p_error_desc             => l_error_desc);
      
        if p_status_code = 'E' then
          p_status_text := substr(p_status_text || ' ,' || l_error_desc,
                                  1,
                                  1000); -- INC0176753 changed from 2000 -> 1000
          continue;
        end if;
      
      exception
        when others then
          p_status_code := 'E';
        
          log_error_copy_responsibility(p_from           => p_from_user,
                                        p_to             => p_to_user,
                                        p_ticket         => p_ticket,
                                        p_responsibility => rec.responsibility_name,
                                        p_app            => rec.application_short_name,
                                        p_status         => 'E',
                                        p_comment        => 'Close responsibility Unexpected Error  ' ||
                                                            sqlerrm);
        
          return; -- unexpected error - break out.
      end;
    end loop;
  
  exception
    when others then
      p_status_code := 'E';
      p_status_text := 'Unexpected Error  ' || sqlerrm;
  end copy_responsibilities;

  --------------------------------------------------------------------
  --  name:               collect_errors
  --  create by:          dan melamed
  --  revision:           1.0
  --  creation date:      10-jul-2018
  --  purpose :           collect all logged errors for 'copy to' user
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   10-jul-2018   dan melamed     initial build - chg0043086
  ----------------------------------------------------------------------

  function collect_errors(p_copy_to varchar2) return varchar2 is
    l_return_note varchar2(1000);
    cursor c_log is
      select *
        from xxobjt.xxfnd_user_resp_error_t log
       where log.copy_to = p_copy_to;
  begin
  
    for rec in c_log loop
      if l_return_note is null or
         length(l_return_note) <= 800 and rec.responsibility is not null then
      
        if l_return_note is null then
          l_return_note := substr(rec.responsibility || ' (' ||
                                  rec.responsibiity_app || ') : ' ||
                                  rec.comments,
                                  1,
                                  199);
        else
          l_return_note := l_return_note || chr(13) ||
                           substr(rec.responsibility || ' (' ||
                                  rec.responsibiity_app || ') : ' ||
                                  rec.comments,
                                  1,
                                  199);
        end if;
      
      end if;
    end loop;
  
    return l_return_note;
  exception
    when others then
      l_return_note := substr(l_return_note ||
                              'Error while collecting errors',
                              1,
                              1000);
  end collect_errors;

  --------------------------------------------------------------------------------------------
  -- purpose: initialize applicative user
  -- --------------------------------------------------------------------------------------------
  -- ver  date        name                    description
  -- 1.0  23-jul-2018  dan m.                  initial build
  -- --------------------------------------------------------------------------------------------

  function app_initialize(p_user_name      varchar2,
                          p_responsibility varchar2,
                          p_appication     varchar2) return varchar2 is
    l_user_id number;
    l_resp_id number;
    l_app_id  number;
  begin
    begin
    
      select fndappl.application_id
        into l_app_id
        from fnd_application fndappl
       where fndappl.application_short_name = p_appication;
    
      select fndresp.responsibility_id
        into l_resp_id
        from fnd_responsibility_tl fndresp
       where fndresp.responsibility_name = p_responsibility
         and fndresp.language = 'US'
         and fndresp.application_id = l_app_id;
    
      select fnd.user_id
        into l_user_id
        from fnd_user fnd
       where fnd.user_name = p_user_name;
    
      fnd_global.apps_initialize(user_id      => l_user_id,
                                 resp_id      => l_resp_id,
                                 resp_appl_id => l_app_id);
    
      mo_global.init(p_appication);
    
      return 'Y';
    exception
      when others then
        return 'X';
    end;
  
  end app_initialize;

  --------------------------------------------------------------------
  --  name:               main
  --  create by:          dan melamed
  --  revision:           1.0
  --  creation date:      10-jul-2018
  --  purpose :           main procedure called to copy bulk table of users responsibility a to b
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   10-jul-2018   dan melamed     initial build - chg0043086 - create user ebs  responsibilities
  -----------------------------------------------------------------------

  procedure main(p_processing_bulk in out xxobjt.xxfnd_user_resp_tab,
                 p_error_code      out number,
                 p_error_desc      out varchar2) is
  
    l_record            xxobjt.xxfnd_user_resp_rec;
    l_username_from     varchar2(255);
    l_username_to       varchar2(255);
    l_employee_err_code varchar2(5);
    l_employee_err_note varchar2(1000);
    l_app_init          varchar2(1);
    l_request_id        number;
    l_complete          boolean;
    l_status_text       varchar2(1000);
  
    l_conc_phase  varchar2(255);
    l_conc_status varchar2(255);
    l_dev_phase   varchar2(255);
    l_dev_status  varchar2(255);
    l_message     varchar2(4000);
  
  begin
    p_error_code                       := 0;
    xxfnd_resp_api_pkg.g_called_by_api := true;
  
    l_app_init := app_initialize('BPEL_INTF',
                                 'System Administrator',
                                 'SYSADMIN');
    if l_app_init = 'N' then
      p_error_code := 1;
      p_error_desc := 'Unable to initialize to sysadmin';
      return;
    end if;
  
    -- run th concurrent to fix dangling role assignments
  
    for i in p_processing_bulk.first .. p_processing_bulk.last loop
    
      l_record := p_processing_bulk(i);
    
      begin
      
        -- employee 'From'
        select us.user_name
          into l_username_from
          from fnd_user us
         where us.employee_id in
               (select distinct ppf.person_id
                  from per_all_people_f ppf
                 where nvl(ppf.employee_number, ppf.npw_number) =
                       regexp_substr(l_record.employee_number_from,
                                     '[[:digit:]]+'));
      
      exception
        when too_many_rows then
        
          select us.user_name
            into l_username_from
            from fnd_user us
           where us.employee_id in
                 (select distinct ppf.person_id
                    from per_all_people_f ppf
                   where nvl(ppf.employee_number, ppf.npw_number) =
                         regexp_substr(l_record.employee_number_from,
                                       '[[:digit:]]+'))
             and ((trunc(us.start_date) >= trunc(l_record.start_date) and
                 us.end_date is null) -- future user
                 or (trunc(l_record.start_date) between us.start_date and
                 trunc(nvl(us.end_date, hr_general.end_of_time)))); -- get only the active user
      
      end;
    
      --employee 'To'
      begin
      
        select us.user_name
          into l_username_to
          from fnd_user us
         where us.employee_id in
               (select distinct ppf.person_id
                  from per_all_people_f ppf
                 where nvl(ppf.employee_number, ppf.npw_number) =
                       regexp_substr(l_record.employee_number_to,
                                     '[[:digit:]]+'));
      
      exception
        when too_many_rows then
        
          select us.user_name
            into l_username_to
            from fnd_user us
           where us.employee_id in
                 (select distinct ppf.person_id
                    from per_all_people_f ppf
                   where nvl(ppf.employee_number, ppf.npw_number) =
                         regexp_substr(l_record.employee_number_to,
                                       '[[:digit:]]+'))
             and ((trunc(us.start_date) >= trunc(l_record.start_date) and
                 us.end_date is null) -- future user
                 or (trunc(l_record.start_date) between us.start_date and
                 trunc(nvl(us.end_date, hr_general.end_of_time)))); -- get only the active user
      end;
    
      -- delete lines from log table for copy to.
      delete from xxobjt.xxfnd_user_resp_error_t t1
       where t1.copy_to = l_username_to;
    
      copy_responsibilities(p_from_user   => l_username_from,
                            p_to_user     => l_username_to,
                            p_start_date  => trunc(l_record.start_date),
                            p_ticket      => l_record.refference_number,
                            p_status_code => l_employee_err_code,
                            p_status_text => l_status_text);
    
      if l_status_text is not null then
        -- critical error
        p_error_code := 1;
        p_error_desc := l_status_text;
        return;
      end if;
    
      l_employee_err_note := collect_errors(l_username_to);
      p_processing_bulk(i).status := nvl(l_employee_err_code, 'E');
    
      if p_processing_bulk(i).status = 'E' then
        p_processing_bulk(i).status_note := nvl(l_employee_err_note,
                                                'Error processing copy responsibility');
      end if;
    
    end loop;
  
    -- resubmit responsebility validation request for all users.
    l_request_id := fnd_request.submit_request(application => 'FND',
                                               program     => 'FNDWFDSURV',
                                               description => 'Validates the user/role information in Workflow Directory Services',
                                               start_time  => sysdate,
                                               sub_request => false,
                                               argument1   => '10000',
                                               argument2   => null,
                                               argument3   => null,
                                               argument4   => 'N',
                                               argument5   => 'Y',
                                               argument6   => 'N');
  
    if l_request_id < 1 then
      p_error_code := 1;
      p_error_desc := 'Unable to submit concurrent fixing role assignments';
      return;
      -- takes a couple of minutes (2). no need to wait for completion.
      -- l_complete  := fnd_concurrent.wait_for_request (request_id => l_request_id, interval => 1, max_wait => 150, phase => l_conc_phase, status => l_conc_status, dev_phase => l_dev_phase, dev_status => l_dev_status, message => l_message );
    end if;
  
  exception
    when others then
      p_error_code := 1;
      p_error_desc := 'Error during process : ' || substr(sqlerrm, 1, 250);
      if l_record.employee_number_to is not null then
        p_error_desc := p_error_desc || '  ' || l_record.employee_number_to || '(' ||
                        regexp_substr(l_record.employee_number_to,
                                      '[[:digit:]]+') || ') on ' ||
                        to_char(l_record.start_date, 'DD-MON-YYYY');
      end if;
  end main;

  ------------------------------------------------------------------------------------
  ------------------------------------------------------------------------------------
  --------------------------------------------------------------------
  --  name:            message
  --  create by:       Bellona(TCS)
  --  Revision:        1.0
  --  creation date:   19-SEP-2018
  ---------------------------------------------------------------------------------
  --  purpose :        printing log message
  --
  ----------------------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  06/09/2012  Bellona(TCS)    initial build
  --  1.1  12/11/2018  Roman W.        CHG0043902 - modefication in "main" cursors
  ----------------------------------------------------------------------------------
  procedure message(p_msg in varchar2) IS
  begin
  
    if fnd_global.CONC_REQUEST_ID != -1 then
      fnd_file.put_line(fnd_file.log, p_msg);
    else
      dbms_output.put_line(p_msg);
    end if;
  
  end message;

  --------------------------------------------------------------------
  --  name:            close_resp
  --  create by:       Bellona(TCS)
  --  Revision:        1.0
  --  creation date:   19-SEP-2018
  --------------------------------------------------------------------
  --  purpose :        close active responsibility of user
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  06/09/2012  Bellona(TCS)      CHG0043902-initial build
  --  1.1  29/11/2018  Roman W.          CHG0043902-CTASK0039472 added prameter IN
  --                                        p_resp_start_date
  --                                        p_resp_end_date
  --  1.2  25/12/2018  Roman W.          CHG0043902-CTASK0039472 : fr.application_id = fa.application_id
  --------------------------------------------------------------------
  procedure close_resp(errbuf            out varchar2,
                       retcode           out varchar2,
                       p_user_name       in varchar2,
                       p_resp_key        in varchar2,
                       p_appl_short_name in varchar2,
                       p_resp_start_date in date default null,
                       p_resp_end_date   in date default null,
                       p_application_id  in number) is
    --declare variables
    v_responsibility_name varchar2(100) := null;
    v_security_group      varchar2(100) := null;
  
  begin
    errbuf  := null;
    retcode := '0';
  
    select frt.responsibility_name, nvl(frg.security_group_key, 'STANDARD')
      into v_responsibility_name, v_security_group
      from fnd_responsibility    fr,
           fnd_application       fa,
           fnd_security_groups   frg,
           fnd_responsibility_tl frt
     where fr.application_id = fa.application_id
       and fr.data_group_id = frg.security_group_id(+)
       and fr.responsibility_id = frt.responsibility_id
       and fa.application_short_name = p_appl_short_name
       and frt.language = userenv('LANG')
       and fr.responsibility_key = p_resp_key
       and fr.application_id = p_application_id;
  
    if p_resp_start_date is not null and p_resp_end_date is not null and
       p_resp_start_date > p_resp_end_date then
    
      fnd_user_pkg.addresp(username       => p_user_name,
                           resp_app       => p_appl_short_name,
                           resp_key       => p_resp_key,
                           security_group => v_security_group,
                           description    => 'Closed by: "XXFND : Automatic User Termination - Prog"',
                           start_date     => p_resp_start_date,
                           end_date       => p_resp_end_date);
    
    else
      --calling api to end date responsibility 'p_resp_name' for the user 'p_user_name'
      fnd_user_pkg.delresp(username       => p_user_name,
                           resp_app       => p_appl_short_name,
                           resp_key       => p_resp_key,
                           security_group => v_security_group);
    end if;
  
    commit;
  
    message('Responsiblity ' || v_responsibility_name ||
            ' is removed from the user ' || p_user_name || ' Successfully');
  exception
    when others then
      errbuf  := 'Error encountered while deleting responsibilty ' ||
                 v_responsibility_name || ' from the user ' || p_user_name ||
                 ' and the error is ' || substr(sqlerrm, 1, 240);
      retcode := 1;
      message('Error encountered while deleting responsibilty ' ||
              v_responsibility_name || ' from the user ' || p_user_name ||
              ' and the error is ' || sqlerrm);
  end;

  --------------------------------------------------------------------
  --  name:            end_date_user
  --  create by:       Bellona(TCS)
  --  Revision:        1.0
  --  creation date:   19-SEP-2018
  --------------------------------------------------------------------
  --  purpose :        End date user
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  06/09/2012  Bellona(TCS)    initial build
  --------------------------------------------------------------------
  procedure end_date_user(errbuf      out varchar2,
                          retcode     out varchar2,
                          p_user_name in varchar2) is
    -------------------------
    --   Local Definitions
    -------------------------
    ld_user_end_date date := sysdate;
    -------------------------
    --   Code Section
    -------------------------
  begin
    errbuf  := null;
    retcode := '0';
  
    fnd_user_pkg.updateuser(x_user_name   => p_user_name,
                            x_owner       => null,
                            x_description => 'Closed by: "XXFND : Automatic User Termination - Prog"', -- added by R.W 27/11/2018
                            x_end_date    => ld_user_end_date);
  
    commit;
  
    message('User ' || p_user_name || ' is end-dated successfully');
  
  exception
    when others then
      errbuf  := 'Error encountered while end dating user ' || p_user_name ||
                 ' and the error is ' || substr(sqlerrm, 1, 240);
      retcode := '1';
      message('Error encountered while end dating user ' || p_user_name ||
              ' and the error is ' || sqlerrm);
    
  end;

  ----------------------------------------------------------------------------------
  --  name:            main
  --  create by:       Bellona(TCS)
  --  Revision:        1.0
  --  creation date:   19-SEP-2018
  ----------------------------------------------------------------------------------
  --  purpose :        CHG0043902 - Automatic termination of user
  --
  ----------------------------------------------------------------------------------
  --  ver  date        name            desc
  --  ---  ----------  --------------  ---------------------------------------------
  --  1.0  06/09/2012  Bellona(TCS)    initial build
  --  1.1  25/11/2018  Roman W.        cursor c_term_user modefications
  --  1.2  29/11/2018  Roman W.        CHG0043902-CTASK0039472 Close Ex-Emp user resp with user end-date
  --  1.3  09/12/2018  Roman W.        CHG0043902-CTASK0039588 except users with user_id <=1111
  --  1.4  09/12/2018  Roman W.        CHG0043902-CTASK0039841 exclude user AME_USER
  ----------------------------------------------------------------------------------
  procedure close_ex_employee_user(errbuf  out varchar2,
                                   retcode out varchar2) is
  
    ------------------------------
    --      Local Definition
    ------------------------------
  
    cursor c_term_user is
      select fu.user_name
        from fnd_user fu
       where nvl(fu.end_date, trunc(sysdate)) >= trunc(sysdate)
         and hr_person_type_usage_info.get_user_person_type(trunc(sysdate),
                                                            fu.employee_id) like
             ('Ex%')
         and fu.user_name not in ('SYSADMIN', 'SCHEDULER');
  
    --find list of all open responsibilities to close users
    cursor c_open_resp is
      select fu.user_name,
             fur.responsibility_id,
             r.responsibility_name,
             r.responsibility_key,
             a.application_short_name,
             r.START_DATE             resp_start_date, -- CHG0043902-CTASK0039472
             fur.start_date           user_start_date, -- CHG0043902-CTASK0039472
             fur.end_date             user_end_date, -- CHG0043902-CTASK0039472
             r.application_id
        from fnd_user                    fu,
             fnd_user_resp_groups_direct fur,
             fnd_responsibility_vl       r,
             fnd_application_vl          a
       where fur.user_id = fu.user_id
         and r.responsibility_id = fur.responsibility_id
         and r.application_id = fur.responsibility_application_id
         and fur.end_date is null
         and r.application_id = a.application_id
         and nvl(fu.end_date, trunc(sysdate + 1)) <= trunc(sysdate) -- CHG0043902-CTASK0039841 added "="
         and fu.user_name not in ('SYSADMIN', 'SCHEDULER')
         and fu.user_id > 1111 -- CHG0043902-CTASK0039588
         and fu.user_id != 1152; -- AME_USER  CHG0043902-CTASK0039841
  
    ------------------------------
    --      Code Section
    ------------------------------
  begin
  
    errbuf  := null;
    retcode := '0';
  
    for i in c_term_user loop
    
      message('USER - ' || i.user_name);
    
      -- call procedure for end date active users and update description
      end_date_user(errbuf, retcode, i.user_name);
    
    end loop; --<ending c_term_user>
  
    -- Close open responcibility to close users
    for j in c_open_resp loop
      message('Close responsibility - ' || j.responsibility_name);
    
      --call procedure for closing responsibility
      close_resp(errbuf,
                 retcode,
                 j.user_name,
                 j.responsibility_key,
                 j.application_short_name,
                 j.resp_start_date,
                 j.user_end_date,
                 j.application_id);
    end loop; --<ending c_open_resp>
  
  end close_ex_employee_user;

end xxfnd_resp_api_pkg;
/
