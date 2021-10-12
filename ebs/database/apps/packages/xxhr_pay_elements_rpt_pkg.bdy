create or replace package body xxhr_pay_elements_rpt_pkg is

--------------------------------------------------------------------
--  name:            XXHR_PAY_ELEMENTS_RPT_PKG
--  create by:       Dalit A. Raviv
--  Revision:        1.1
--  creation date:   06/06/2012 15:34:52
--------------------------------------------------------------------
--  purpose :        REP499 - Elements Reports
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  06/06/2012  Dalit A. Raviv    initial build
--  1.1  30/12/2012  Dalit A. Raviv    procedure afterreport, Run_element_rpt
--                                     Organization heirarchy changes - changes in names -> Objet to Stratasys
--------------------------------------------------------------------

  --------------------------------------------------------------------
  --  name:            beforereport
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   06/06/2012 15:34:52
  --------------------------------------------------------------------
  --  purpose :        REP499 - Elements Reports
  --                   1) set security token - open encrypt data
  --                   2) set session param - period date
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  06/06/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  function beforereport (--p_period_date    in varchar2,
                         p_token in varchar2) return boolean is

    l_err_code     varchar2(20)   := null;
    l_err_message  varchar2(2500) := null;
    l_request_id   number         := fnd_global.conc_request_id;
  begin

    -- Handle security Token
    xxobjt_sec.upload_user_session_key(p_pass        => p_token, --'D1234567',
                                       p_err_code    => l_err_code,
                                       p_err_message => l_err_message);

    if l_err_code = 1 then
      fnd_file.put_line(fnd_file.log, '----------------------------------------');
      fnd_file.put_line(fnd_file.log, 'You are not allowed to run this program');
      fnd_file.put_line(fnd_file.log, 'or security token is invalid');
      fnd_file.put_line(fnd_file.log, 'Please contact your sysadmin');
      fnd_file.put_line(fnd_file.log, '----------------------------------------');

      update fnd_concurrent_requests t
      set    t.argument_text = null,
             t.argument1     = null
      where  t.request_id    = l_request_id;

      commit;
      return false;
    end if;

    return true;
  exception
    when others then
      return false;

  end beforereport;

  --------------------------------------------------------------------
  --  name:            afterreport
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   06/06/2012 15:34:52
  --------------------------------------------------------------------
  --  purpose :        REP499 - Elements Reports
  --                   send report output as mail to user that run the report.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  06/06/2012  Dalit A. Raviv    initial build
  --  1.1  30/12/2012  Dalit A. Raviv    Organization heirarchy changes - changes in names -> Objet to Stratasys
  --------------------------------------------------------------------
  function afterreport return boolean is

    --l_email_subject varchar2(200)  := 'All Employees Elements Report';
    l_Request_id    number         := fnd_global.conc_request_id;
    l_Request_id1   number         := null;
    l_email_body    varchar2(1500) := 'Attached file contain summary of Stratasys Employees Elements. '||chr(13);
    l_email_body1    varchar2(1500) := 'Please do not reply to this email. '||chr(13);
    l_email_body2    varchar2(1500) := 'This mailbox does not allow incoming messages. ';
    l_mail_to        varchar2(150);
  begin
    l_email_body  := replace(l_email_body, ' ', '_');
    l_email_body1 := replace(l_email_body1, ' ', '_');
    l_email_body2 := replace(l_email_body2, ' ', '_');

    begin
      select paf.email_address
      into   l_mail_to
      from   per_all_people_f paf,
             fnd_user         fu
      where  paf.person_id    = fu.employee_id
      and    fu.user_id       = fnd_profile.VALUE('USER_ID')
      and    trunc(sysdate)    between paf.effective_start_date and paf.effective_end_date;

    exception
      when others then
      l_mail_to := null;
    end;

    if l_mail_to is null then
      l_mail_to := fnd_profile.value('XXHR_ELEMENT_SEND_MAIL_CC');--'Michal.Yaoz@Objet.com'
    end if;

    l_Request_id1 := fnd_request.Submit_Request( application => 'XXOBJT',
                                                 program     => 'XXSENDREQTOMAIL',
                                                 argument1   => 'Stratasys_Employees_Elements',  -- Mail Subject -- 30/12/2012
                                                 argument2   => l_email_body,
                                                 argument3   => l_email_body1,
                                                 argument4   => l_email_body2,
                                                 argument5   => 'XXHR_SAL_BEN',  -- Concurrent Short Name
                                                 argument6   => l_Request_id,    -- Request id
                                                 argument7   => l_mail_to,       -- Mail Recipient
                                                 argument8   => 'Elements',      -- Report Name (each run can get different name)
                                                 argument9   => 1,               -- Report Subject Number (Sr Number, SO Number...)
                                                 argument10  => 'EXCEL',         -- Concurrent Output Extention - PDF, EXCEL ...
                                                 argument11  => 'xls',           -- File Extention to Send - pdf, exl
                                                 argument12  => 'Y'              -- Delete Concurrent Output - Y/N
                                                 );


    commit;

    if l_Request_id1 = 0 then
      fnd_file.put_line(fnd_file.log, 'Problem to send mail');
    end if;

    update fnd_concurrent_requests t
    set    t.argument_text = null,
           t.argument1     = null
    where  t.request_id    = l_Request_id;
    commit;

    return true;
  exception
    when others then
      return false;

  end afterreport;

  --------------------------------------------------------------------
  --  name:            get_is_last_element_date
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   12/07/2012
  --------------------------------------------------------------------
  --  purpose :        Procedure that handel Run element report and send output
  --                   to user who run the mail
  --  in params:
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  12/07/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  function get_is_last_element_date (p_assignment_id   in number,
                                     p_element_type_id in number,
                                     p_start_date      in date) return number is

    l_count number := 0;
  begin

    select count(1)
    into   l_count
    from   xxhr_element_fwk_v
    where  assignment_id        = p_assignment_id
    and    element_type_id      = p_element_type_id
    and    effective_start_date > p_start_date;

    return l_count;

  end get_is_last_element_date;

  --------------------------------------------------------------------
  --  name:            Run_element_rpt
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   06/06/2012
  --------------------------------------------------------------------
  --  purpose :        Procedure that handel Run element report and send output
  --                   to user who run the mail
  --  in params:       p_assignment_id
  --                   p_element_type_id
  --                   p_Input_Name
  --                   p_input_value
  --  Return:          max_effective_end_date by ass_id, element_type_id,
  --                   input_name and input val
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  06/06/2012  Dalit A. Raviv    initial build
  -------------------------------------------------------------------
  function get_max_end_date (p_assignment_id   in number,
                             p_element_type_id in number,
                             p_Input_Name      in varchar2,
                             p_input_value     in varchar2 ) return date is

    l_max_date date := null;
  begin
    select max(nvl(tt1.effective_end_date,to_date('31/12/4712', 'dd/mm/yyyy')))
    into   l_max_date
    from   xxhr_element_fwk_v tt1
    where  show_all_history   = 'N'
    and    tt1.element_name not in ('Vacation IL','Sickness IL')
    and    tt1.assignment_id    = p_assignment_id
    and    tt1.element_type_id  = p_element_type_id
    and    tt1.Input_Name       = p_Input_Name
    and    tt1.Input_Value      = p_input_value
    group by assignment_id , element_name, input_value, input_name;

    if l_max_date = to_date('31/12/4712', 'dd/mm/yyyy')then
      return null;
    else
      return l_max_date;
    end if;

  end get_max_end_date;

  --------------------------------------------------------------------
  --  name:            Run_element_rpt
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   06/06/2012
  --------------------------------------------------------------------
  --  purpose :        Procedure that handel Run element report and send output
  --                   to user who run the mail
  --  in params:       p_security_token
  --                   p_period_date
  --                   p_department
  --                   p_division
  --                   p_job_id
  --                   p_position_id
  --                   retcode      - 0    success other fialed
  --                   errbuf       - null success other fialed
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  06/06/2012  Dalit A. Raviv    initial build
  --  1.1  30/12/2012  Dalit A. Raviv    Organization heirarchy changes - changes in names -> Objet to Stratasys
  --------------------------------------------------------------------
  procedure Run_element_rpt (errbuf          out varchar2,
                             retcode         out varchar2,
                             p_token         in  varchar2,
                             p_period_date   in  varchar2,
                             p_department    in  varchar2,
                             p_division      in  varchar2,
                             p_job_id        in  number,
                             p_position_id   in  number
                            ) is

    l_to_mail      varchar(100)  := null;
    l_template     boolean;
    l_request_id   number        := null;
    l_error_flag   boolean       := FALSE;
    l_phase        varchar2(100);
    l_status       varchar2(100);
    l_dev_phase    varchar2(100);
    l_dev_status   varchar2(100);
    l_message      varchar2(100);
    l_return_bool  boolean;
    l_req_id       number;
    l_err_code     varchar2(20)   := null;
    l_err_msg      varchar2(2500) := null;
    l_email_body   varchar2(1500) := 'Attached file contain summary of Stratasys Employees Elements.'||chr(13);  -- 1.1 30/12/2012 Dalit A. Raviv
    l_email_body1  varchar2(1500):= 'Please do not reply to this email.'||chr(13);
    l_email_body2  varchar2(1500):= 'This mailbox does not allow incoming messages.';

    general_exception exception;
  begin
    errbuf  := null;
    retcode := 0;

    fnd_file.put_line(fnd_file.log,'-----------------------------------');
    l_request_id   := fnd_global.conc_request_id;
    l_error_flag   := FALSE;
    l_phase        := null;
    l_status       := null;
    l_dev_phase    := null;
    l_dev_status   := null;
    l_message      := null;
    l_req_id       := null;
    --l_full_name    := null;
    --l_emp_num      := null;

    -- Handle security Token
    xxobjt_sec.upload_user_session_key(p_pass        => p_token, --'D1234567',
                                       p_err_code    => l_err_code,
                                       p_err_message => l_err_msg);

    if l_err_code = 1 then
      fnd_file.put_line(fnd_file.log, '----------------------------------------');
      fnd_file.put_line(fnd_file.log, 'You are not allowed to run this program');
      fnd_file.put_line(fnd_file.log, 'or security token is invalid');
      fnd_file.put_line(fnd_file.log, 'Please contact your sysadmin');
      fnd_file.put_line(fnd_file.log, '----------------------------------------');

      update fnd_concurrent_requests t
      set    t.argument_text = null,
             t.argument1     = null
      where  t.request_id    = l_request_id;

      commit;
      errbuf  := 'Security Token is Invalid';
      retcode := 1;
      return;
    end if;

    -- get to mail address
     begin
      select paf.email_address
      into   l_to_mail
      from   per_all_people_f paf,
             fnd_user         fu
      where  paf.person_id    = fu.employee_id
      and    fu.user_id       = fnd_profile.VALUE('USER_ID')
      and    trunc(sysdate)    between paf.effective_start_date and paf.effective_end_date;

    exception
      when others then
      l_to_mail := null;
    end;

    if l_to_mail is null then
      l_to_mail := fnd_profile.value('XXHR_ELEMENT_SEND_MAIL_CC');--'Michal.Yaoz@Objet.com'
    end if;

    -- Set Xml Publisher report template
    l_template := fnd_request.add_layout(template_appl_name => 'XXOBJT',
                                         template_code      => 'XXHR_EMP_ELE',
                                         template_language  => 'en',
                                         output_format      => 'PDF',
                                         template_territory => null);
    if l_template = TRUE then
      -- Run element report
      l_request_id := fnd_request.submit_request(application => 'XXOBJT',
                                                 program     => 'XXHR_EMP_ELE',
                                                 description => null,
                                                 start_time  => null,
                                                 sub_request => FALSE,
                                                 argument1   => p_period_date,
                                                 argument2   => p_department,
                                                 argument3   => p_division,
                                                 argument4   => p_job_id,
                                                 argument5   => p_position_id
                                                );
      -- check concurrent success
      if l_request_id = 0 then

        fnd_file.put_line(fnd_file.log,'Failed to print report -----');
        fnd_file.put_line(fnd_file.log,'Err - '||sqlerrm);
        errbuf  := 'Failed to print salary and benefits report';
        retcode := 2;
      else
        fnd_file.put_line(fnd_file.log,'Success to print salary and benefits report -----');
        -- must commit the request
        commit;

        -- loop to wait until the request finished
        while l_error_flag = FALSE loop
          l_return_bool := fnd_concurrent.wait_for_request( l_request_id , 5, 86400,
                                                            l_phase,
                                                            l_status,
                                                            l_dev_phase,
                                                            l_dev_status,
                                                            l_message);

          if (l_dev_phase = 'COMPLETE' and l_dev_status = 'NORMAL') then
            l_error_flag := TRUE;
          elsif (l_dev_phase = 'COMPLETE' and l_dev_status <> 'NORMAL') then
            l_error_flag := TRUE;
            errbuf  := 'Request finished in error/warrning, no email send';
            retcode := 1;
            fnd_file.put_line(fnd_file.log,'Request finished in error/warrning, no email send. try again later. - '||l_message);
          end if; -- dev_phase
        end loop; -- l_error_flag

        if l_error_flag = TRUE and l_dev_status = 'NORMAL' then
          if l_to_mail is not null then
            l_email_body  := replace(l_email_body, ' ', '_');
            l_email_body1 := replace(l_email_body1, ' ', '_');
            l_email_body2 := replace(l_email_body2, ' ', '_');
            l_req_id := fnd_request.Submit_Request
                                   ( application => 'XXOBJT',
                                     program     => 'XXSENDREQTOMAIL',
                                     argument1   => 'Stratasys_Employees_Elements',  -- Mail Subject -- 1.1 30/12/2012 Dalit A. Raviv
                                     argument2   => l_email_body,
                                     argument3   => l_email_body1,
                                     argument4   => l_email_body2,
                                     argument5   => 'XXHR_EMP_ELE',  -- Concurrent Short Name
                                     argument6   => l_Request_id,    -- Request id
                                     argument7   => l_to_mail,       -- Mail Recipient
                                     argument8   => 'Elements',      -- Report Name (each run can get different name)
                                     argument9   => 1,               -- Report Subject Number (Sr Number, SO Number...)
                                     argument10  => 'EXCEL',         -- Concurrent Output Extention - PDF, EXCEL ...
                                     argument11  => 'xls',           -- File Extention to Send - pdf, exl
                                     argument12  => 'Y'              -- Delete Concurrent Output - Y/N
                                     );

            commit;
            dbms_lock.sleep(seconds => 40);
            --dbms_lock.?sleepý(30)ý;
            if l_req_id = 0 then

              fnd_file.put_line(fnd_file.log,'Failed to Send Mail -----');
              fnd_file.put_line(fnd_file.log,'Err - '||sqlerrm);
              errbuf  := 'Failed to Send Mail';
              retcode := 2;
            else
              fnd_file.put_line(fnd_file.log,'Success to Send Mail -----');
              update fnd_concurrent_requests t
              set    t.argument_text = null,
                     t.argument1     = null
              where  t.request_id    = l_Request_id;
              commit;
            end if;  -- l_req_id -- send mail

          end if; -- l_to_mail
        end if; -- l_error_flag
      end if; -- l_request_id concurrent run
    else
      --
      -- Didn't find Template
      --
      fnd_file.put_line(fnd_file.log,'-----------------------------------');
      fnd_file.put_line(fnd_file.log,'------ Can not Find Template ------');
      fnd_file.put_line(fnd_file.log,'-----------------------------------');
      errbuf  := 'Can not Find Template';
      retcode := 2;
    end if; -- l_template

      -- send mail to the bookkeeper (Carmit)

  exception
    when general_exception then
      null;
    when others then
      errbuf  := 'GEN EXC - send_outgoing_form - Failed - '||substr(sqlerrm,1,240);
      retcode := 2;
  end Run_element_rpt;


end XXHR_PAY_ELEMENTS_RPT_PKG;
/
