create or replace package body xxhr_send_mail_pkg is
--------------------------------------------------------------------
--  name:            XXHR_SEND_MAIL_PKG
--  create by:       Dalit A. Raviv
--  Revision:        1.3
--  creation date:   27/10/2011
--------------------------------------------------------------------
--  purpose :        HR project - Handle send mail cases
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  27/01/2011  Dalit A. Raviv    initial build
--  1.1  05/03/2012  Dalit A. Raviv    mng_note_on_empl_birthday -> add log of the manager id
--  1.2  30/12/2012  Dalit A. Raviv    mng_note_on_empl_birthday -> send mail to direct manager only
--  1.3  20/02/2013  Dalit A. Raviv    send manager person id and today date to procedure
--                                     XXHR_WF_SEND_MAIL_PKG.prepare_mng_emps_birthday_body
--------------------------------------------------------------------

  --------------------------------------------------------------------
  --  name:            mng_note_on_empl_birthday
  --  create by:       Dalit A. Raviv
  --  Revision:        1.3
  --  creation date:   27/10/2011
  --------------------------------------------------------------------
  --  purpose:         This procedure handle note to manager on her/his
  --                   employees that will have tomorrow birthday.
  --                   1) get level
  --                   2) check count if to send mail (if there are employees to notify on)
  --                   3) if count > 0 then send mail
  --                      the mail will send to the manager, cc to michal
  --  In  Params:
  --  Out Params:
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  27/01/2011  Dalit A. Raviv    initial build
  --  1.1  05/03/2012  Dalit A. Raviv    add log of the manager id
  --  1.2  30/12/2012  Dalit A. Raviv    send mail to direct manager only mng_note_on_empl_birthday
  --  1.3  20/02/2013  Dalit A. Raviv    send manager person id and today date to procedure
  --                                     XXHR_WF_SEND_MAIL_PKG.prepare_mng_emps_birthday_body
  --------------------------------------------------------------------
  procedure mng_note_on_empl_birthday (errbuf   out varchar2,
                                       retcode  out varchar2) is


    -- Get all suppervisors
    cursor get_mng_c is
      select distinct
             papf.full_name, papf.email_address, papf.person_type_id,
             hr_person_type_usage_info.get_user_person_type(trunc(sysdate),paa.supervisor_id) person_type,
             papf.person_id
      from   per_all_people_f      papf,
             per_all_assignments_f paa
      where  1 = 1
      and    trunc(sysdate)        between paa.effective_start_date  and paa.effective_end_date
      and    trunc(sysdate)        between papf.effective_start_date and papf.effective_end_date
      and    paa.supervisor_id     = papf.person_id
      and    hr_person_type_usage_info.get_user_person_type(trunc(sysdate),paa.supervisor_id) not like 'Ex%';

     l_level        number        := 999;
     l_count        number        := 0;
     l_to_user_name varchar2(150) := null;
     l_profile      varchar2(150) := fnd_profile.value('XXHR_ENABLE_BCC_MAIL');
     l_bcc          varchar2(150) := null;
     l_subject      varchar2(360) := null;
     l_att1_proc    varchar2(150) := null;
     l_att2_proc    varchar2(150) := null;
     l_att3_proc    varchar2(150) := null;
     l_err_code     number        := 0;
     l_err_desc     varchar2(1000):= null;

  begin

    errbuf  := null;
    retcode := 0;

    for get_mng_r in get_mng_c loop

      -- 1) check count if to send mail - only if manager have at least one employee
      --    today birthday the program will send mail notification.
      --    the mail will contain all employess that today have birthday.
      select  count(paa1.person_id)
      into    l_count
      from    (select *
               from   per_all_people_f     papf2
               where  trunc(sysdate)       between papf2.effective_start_date
                                           and papf2.effective_end_date) papf,
              (select *
               from   per_all_assignments_f paa2
               where  trunc(sysdate)        between paa2.effective_start_date
                                            and paa2.effective_end_date) paa1,
              (select *
               from   per_all_people_f      papf3
               where  trunc(sysdate)        between papf3.effective_start_date
                                            and papf3.effective_end_date )  papf1
      where   paa1.supervisor_id      = papf.person_id  -- manager
      and     paa1.person_id          = papf1.person_id -- employee
      and     paa1.primary_flag       = 'Y'
      and     paa1.assignment_type    in ('E','C')
      and     level                   = 1            ----
      and     to_char(papf1.date_of_birth,'MM-DD') = to_char(trunc(sysdate +1 ),'MM-DD')
      and     hr_person_type_usage_info.get_user_person_type(trunc(sysdate),paa1.person_id) not like 'Ex%'
      start   with paa1.supervisor_id = GET_MNG_R.PERSON_ID ----
      connect by prior paa1.person_id = paa1.supervisor_id
      and     paa1.primary_flag       = 'Y'
      and     paa1.assignment_type    in ('E','C')
      and     papf.business_group_id  = 0
      and     paa1.business_group_id  = 0
      and     papf1.business_group_id = 0
      and     hr_person_type_usage_info.get_user_person_type(trunc(sysdate),paa1.person_id) not like 'Ex%';

      -- 2) if count > 0 then send mail
      if l_count > 0 then
        -- send mail
        --
        -- get user to send the mail too
        begin
          select user_name
          into   l_to_user_name
          from   fnd_user       fu
          where  fu.employee_id = GET_MNG_R.PERSON_ID;
        exception
          when others then
            l_to_user_name := 'ORACLE_HR';
            -- 1.1  05/03/2012  Dalit A. Raviv
            fnd_file.put_line(fnd_file.log,'Manager have no Oracle user - '||get_mng_r.person_id);
        end;

        if nvl(l_profile,'N') = 'Y' then
          l_bcc        := fnd_profile.value('XXHR_ELEMENT_SEND_MAIL_BCC');-- Dalit.raviv@objet.com
        else
          l_bcc        := null;
        end if;
        fnd_message.SET_NAME('XXOBJT','XXHR_MNG_SEND_MAIL_SUBJECT');
        l_subject      := fnd_message.get;
        l_err_code     := 0;
        l_err_desc     := null;

        fnd_file.put_line(fnd_file.log, 'Manger - '||GET_MNG_R.PERSON_ID||' Level '||l_level||' Send Mail ');
        dbms_output.put_line('Manger - '||GET_MNG_R.PERSON_ID||' Level '||l_level||' Send Mail ');
        --  1.3  20/02/2013  Dalit A. Raviv
        xxobjt_wf_mail.send_mail_body_proc
                      (p_to_role     => l_to_user_name,     -- i v
                       p_cc_mail     => null,               -- i v
                       p_bcc_mail    => l_bcc,              -- i v
                       p_subject     => l_subject,          -- i v
                       p_body_proc   => 'XXHR_WF_SEND_MAIL_PKG.prepare_mng_emps_birthday_body/'||GET_MNG_R.PERSON_ID||'|'||to_char(trunc(SYSDATE + 1), 'MM-DD'), -- i v
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
        end if;
      end if;
    end loop;

  exception
    when others then
      errbuf  := 'Gen Exc - mng_note_on_empl_birthday - '||substr(sqlerrm,1,240);
      retcode := 1;
  end mng_note_on_empl_birthday;

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
  --  1.0  30/01/2011  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  function get_footer_html return varchar2 is
  begin
    fnd_message.set_name('XXOBJT', 'XXHR_MAIL_FOOTER');
    return fnd_message.get;

  end get_footer_html;

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
  function get_footer_html_birthday return varchar2 is
  begin
    fnd_message.set_name('XXOBJT', 'XXHR_MAIL_FOOTER_BIRTHDAY');
    return fnd_message.get;

  end get_footer_html_birthday;

end XXHR_SEND_MAIL_PKG;
/
