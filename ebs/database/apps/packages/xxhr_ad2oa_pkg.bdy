create or replace package body xxhr_ad2oa_pkg is
--------------------------------------------------------------------
--  name:            XXHR_AD2OA_PKG
--  create by:       Dalit A. Raviv
--  Revision:        1.0
--  creation date:   09/07/2013 13:48:31
--------------------------------------------------------------------
--  purpose :        CUST677 - AD email address to oracle - prog
--
--                   This Package handle Active directory interface to Oracle
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  09/07/2013  Dalit A. Raviv    initial build
--------------------------------------------------------------------
  
  g_user_id number;

  --------------------------------------------------------------------
  --  name:            ins_log_msg
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   11/07/2013 
  --------------------------------------------------------------------
  --  purpose :        insert new row to log table                 
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  11/07/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure ins_log_msg(p_oa_emp_number	  in  varchar2,
                        p_oa_first_name	  in  varchar2,
                        p_oa_last_name	  in  varchar2,
                        p_oa_person_id	  in  number,
                        p_ad_first_name	  in  varchar2,
                        p_ad_last_name	  in  varchar2,
                        p_ad_mail	        in  varchar2,
                        p_log_code	      in  varchar2,
                        p_log_message	    in  varchar2,
                        p_err_code        out varchar2,
                        p_err_desc        out varchar2) is

    PRAGMA AUTONOMOUS_TRANSACTION;
    l_log_id number := null;
    
  begin
    
    p_err_code := 0;
    p_err_desc := NULL;
    -- get log id
    SELECT xxhr_ad2oa_log_s.nextval INTO l_log_id FROM dual;
  
    insert into xxobjt.xxhr_ad2oa_log(log_id,
                                      oa_emp_number,
                                      oa_first_name,
                                      oa_last_name,
                                      oa_person_id,
                                      ad_first_name,
                                      ad_last_name,
                                      ad_mail,
                                      log_code,
                                      log_message,
                                      send_mail,
                                      last_update_date,
                                      last_updated_by,
                                      last_update_login,
                                      creation_date,
                                      created_by)
    values                           (l_log_id,
                                      p_oa_emp_number,
                                      p_oa_first_name,
                                      p_oa_last_name,
                                      p_oa_person_id,
                                      p_ad_first_name,
                                      p_ad_last_name,
                                      p_ad_mail,
                                      p_log_code,
                                      p_log_message,
                                      'N',
                                      sysdate,
                                      g_user_id,
                                      -1,
                                      sysdate,
                                      g_user_id);
                                      
    commit;                                      
  exception
    when others then
      p_err_code := 1;
      p_err_desc := 'GEN exc - ins_lod_msg - '||substr(sqlerrm,1,240);
  end ins_log_msg;                        

  --------------------------------------------------------------------
  --  name:            get_details_from_ad
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   09/07/2013 
  --------------------------------------------------------------------
  --  purpose :        open session to AD, ask AD for specific attributes 
  --                   per person.                  
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  09/07/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure get_details_from_ad(errbuf        out    varchar2, 
                                retcode       out    varchar2,
                                p_last_name   out    varchar2,
                                p_first_name  out    varchar2,
                                p_emp_num     in out varchar2,  
                                p_mail        out    varchar2
                                ) is
                                          
    retval       pls_integer := -1;
    my_session   dbms_ldap.session;
    my_attrs     dbms_ldap.string_collection;
    my_message   dbms_ldap.message;
    my_entry     dbms_ldap.message;
    entry_index  pls_integer;
    my_dn        varchar2(256);
    my_attr_name varchar2(256);
    my_ber_elmt  dbms_ldap.ber_element;
    attr_index   pls_integer;
    i            pls_integer;
    my_vals      dbms_ldap.string_collection;
    ldap_host    varchar2(256);
    ldap_port    varchar2(256);
    ldap_user    varchar2(256);
    ldap_passwd  varchar2(256);
    ldap_base    varchar2(256);  
                                       
  begin
    errbuf  := null;
    retcode := 0;
    
    --retval         := -1;   
    -- Please customize the following variables as needed
    ldap_host   := fnd_profile.value('XXHR_AD2OA_LDAP_HOST');  --'srv-ire-dc03';   
    ldap_port   := fnd_profile.value('XXHR_AD2OA_LDAP_PORT');  --'389';             
    ldap_user   := fnd_profile.value('XXHR_AD2OA_LDAP_USER');  --'CN=svc-tasks,OU=Service Accounts,OU=IT Infra,OU=Israel,DC=2objet,DC=com'; 
    ldap_passwd := fnd_profile.value('XXHR_AD2OA_LDAP_PASSWD');--'Q!w2e3';            
    ldap_base   := fnd_profile.value('XXHR_AD2OA_LDAP_BASE');  --'dc=2objet,dc=com'; 
    -- end of customizable settings 

    -- Choosing exceptions to be raised by DBMS_LDAP library.
    dbms_ldap.use_exception := TRUE;
    my_session     := dbms_ldap.init(ldap_host,ldap_port);

    -- bind to the directory
    retval         := DBMS_LDAP.simple_bind_s(my_session, ldap_user, ldap_passwd);
    --dbms_output.put_line('Retval 1 ' || to_char(retval));
      
    -- issue the search these are the names of the attributes at AD
    my_attrs(1)    := 'mail';                 -- email address
    my_attrs(2)    := 'extensionAttribute2';  -- employee number
    my_attrs(3)    := 'givenName';            -- first name
    my_attrs(4)    := 'sn';                   -- last name
    retval := DBMS_LDAP.search_s(my_session, ldap_base, 
                                 DBMS_LDAP.SCOPE_SUBTREE,
                                 'extensionAttribute2='||p_emp_num,--'objectclass=*',
                                 my_attrs,
                                 0,
                                 my_message);
                                   
    --dbms_output.put_line('Retval 2 ' || to_char(retval));
    -- count the number of entries returned
    retval := dbms_ldap.count_entries(my_session, my_message);
    --dbms_output.put_line('Retval 3 ' || to_char(retval));
      
    -- get the first entry
    my_entry       := dbms_ldap.first_entry(my_session, my_message);
    entry_index    := 1;

    -- Loop through each of the entries one by one
    while my_entry IS NOT NULL loop
      -- print the current entry
      my_dn        := dbms_ldap.get_dn(my_session, my_entry);
      my_attr_name := dbms_ldap.first_attribute(my_session,my_entry, my_ber_elmt);
      attr_index   := 1;
      while my_attr_name IS NOT NULL loop
        my_vals    := dbms_ldap.get_values (my_session, my_entry,my_attr_name);
        if my_vals.COUNT > 0 then
          for i in my_vals.first..my_vals.last loop
            dbms_output.put_line(my_attr_name || ' : ' || substr(my_vals(i),1,200));
              
            if my_attr_name = 'sn' then
               p_last_name := substr(my_vals(i),1,200);
            elsif my_attr_name = 'givenName' then
               p_first_name := substr(my_vals(i),1,200);
            elsif my_attr_name = 'extensionAttribute2' then
               p_emp_num := substr(my_vals(i),1,200);
            elsif my_attr_name = 'mail' then
               p_mail := substr(my_vals(i),1,200);
            end if;
            /*
            sn : Raviv
            givenName : Dalit
            extensionAttribute2 : 393
            mail : Dalit.Raviv@stratasys.com
            */
          end loop;
        end if;
        my_attr_name := DBMS_LDAP.next_attribute(my_session,my_entry, my_ber_elmt);
        attr_index := attr_index+1;
      end loop;
      my_entry := dbms_ldap.next_entry(my_session, my_entry);
      --dbms_output.put_line('------------');
      entry_index := entry_index+1;
    end loop;

    -- unbind from the directory  
    retval := DBMS_LDAP.unbind_s(my_session);
    --dbms_output.put_line('Retval 4 ' || to_char(retval));
    --dbms_output.put_line('Directory operation Successful .. exiting');
   
  exception
    when others then
      errbuf  := 'Gen exc - Exception encountered .. exiting - '||substr(sqlerrm,1,240);
      retcode := 2;
      dbms_output.put_line(' Error code    : ' || TO_CHAR(SQLCODE));
      dbms_output.put_line(' Error Message : ' || SQLERRM);
      dbms_output.put_line(' Exception encountered .. exiting');
  end get_details_from_ad;                                          
 
  --------------------------------------------------------------------
  --  name:            main
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   09/07/2013 
  --------------------------------------------------------------------
  --  purpose :        main program, locate the population of all employees without email address
  --                   call AD, check validation, and update oracle with the email address.                 
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  09/07/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure main (errbuf        out varchar2, 
                  retcode       out varchar2) is
                  
    cursor emp_without_mail_c is
      select p.person_id, p.first_name, p.last_name, nvl(p.employee_number,p.npw_number) emp_num, p.email_address,
             hr_person_type_usage_info.get_user_person_type(trunc(p.effective_start_date), p.person_id) person_type,
             p.effective_start_date
      from   per_all_people_f p
      where  p.email_address is null
      and    p.effective_start_date = (select max(effective_start_date)
                                       from   per_all_people_f p1
                                       where  p1.person_id     = p.person_id)
      and    p.person_id            not in (select fv.flex_value
                                            from   fnd_flex_values_vl      fv,
                                                   fnd_flex_value_sets     fvs
                                            where  fv.flex_value_set_id    = fvs.flex_value_set_id
                                            and    fvs.flex_value_set_name like 'XXHR_EXCEPTION_PERSONS'
                                            and    fv.enabled_flag         = 'Y'
                                            and    trunc(sysdate)          between nvl(fv.start_date_active, sysdate-1)
                                                                           and     nvl(fv.end_date_active,sysdate+1)
                                            )
      and    hr_person_type_usage_info.get_user_person_type(trunc(p.effective_start_date), p.person_id) not like 'Ex%'
      and    hr_person_type_usage_info.get_user_person_type(trunc(p.effective_start_date), p.person_id) not like 'Applicant%'
      and    hr_person_type_usage_info.get_user_person_type(trunc(p.effective_start_date), p.person_id) <> 'Pupil';  
    
    l_err_desc     varchar2(1500); 
    l_err_desc1    varchar2(1500); 
    l_err_code     varchar2(100);
    l_last_name    per_all_people_f.last_name%type;
    l_first_name   per_all_people_f.first_name%type;
    l_emp_num      per_all_people_f.employee_number%type;
    l_mail         per_all_people_f.email_address%type;
    
  begin
    
    select fu.user_id
    into   g_user_id
    from   fnd_user fu
    where  fu.user_name = 'SCHEDULER';
    
    errbuf  := null;
    retcode := 0;
    for emp_without_mail_r in emp_without_mail_c loop
      l_err_desc    := null; 
      l_err_code    := 0;
      l_last_name   := null;
      l_first_name  := null;
      l_mail        := null;
      fnd_file.put_line(fnd_file.log,'----');   
      fnd_file.put_line(fnd_file.log,'Employee - '||emp_without_mail_r.last_name||', '||emp_without_mail_r.first_name||' - '||emp_without_mail_r.emp_num); 
      dbms_output.put_line('----');   
      dbms_output.put_line('Employee - '||emp_without_mail_r.last_name||', '||emp_without_mail_r.first_name||' - '||emp_without_mail_r.emp_num);              
      -- 1) call AD and get return detail per employee
      l_emp_num := emp_without_mail_r.emp_num;
      get_details_from_ad(errbuf        => l_err_desc,   -- o   v 
                          retcode       => l_err_code,   -- o   v
                          p_last_name   => l_last_name,  -- o   v
                          p_first_name  => l_first_name, -- o   v
                          p_emp_num     => l_emp_num,    -- i/o v  
                          p_mail        => l_mail        -- o   v
                          );
      if l_err_code = 0 then  
        -- 2) validation for the details returned (AD data is the same as in OA)
        if l_first_name is null and l_last_name is null and l_mail is null then
          fnd_file.put_line(fnd_file.log,'Person do not exists at AD '); 
          dbms_output.put_line('Person do not exists at AD '); 
          ins_log_msg(p_oa_emp_number	  => emp_without_mail_r.emp_num,    -- i v
                      p_oa_first_name	  => emp_without_mail_r.first_name, -- i v
                      p_oa_last_name	  => emp_without_mail_r.last_name,  -- i v
                      p_oa_person_id	  => emp_without_mail_r.person_id,  -- i n
                      p_ad_first_name	  => l_first_name,                  -- i v
                      p_ad_last_name	  => l_last_name,                   -- i v
                      p_ad_mail	        => l_mail,                        -- i v
                      p_log_code	      => 'E',                           -- i v
                      p_log_message	    => 'Person do not exists at AD ', -- i v
                      p_err_code        => l_err_code,
                      p_err_desc        => l_err_desc);      
        else
          -- validation that the person from OA is the person at AD 
          if ((upper(emp_without_mail_r.first_name) = upper(l_first_name)) or (INSTR(upper(emp_without_mail_r.first_name) ,upper(l_first_name))  > 0))and
             ((upper(emp_without_mail_r.last_name)  = upper(l_last_name))  or (INSTR(upper(emp_without_mail_r.last_name) , upper(l_last_name))  > 0))  then
             l_err_desc    := null; 
             l_err_code    := 0; 
             -- 3) update OA with the email address returned from AD
             xxhr_person_pkg.update_employee_email (p_personid     => emp_without_mail_r.person_id,-- i n
                                                    p_emailaddress => l_mail,       -- i v
                                                    p_error_code   => l_err_code,   -- o v
                                                    p_error_desc   => l_err_desc ); -- o v
          
             if l_err_code <> 0 then
               fnd_file.put_line(fnd_file.log,'Problem to update Person - '||l_err_desc); 
               dbms_output.put_line('Problem to update Person - '||l_err_desc); 
               ins_log_msg (p_oa_emp_number	  => emp_without_mail_r.emp_num,    -- i v
                            p_oa_first_name	  => emp_without_mail_r.first_name, -- i v
                            p_oa_last_name	  => emp_without_mail_r.last_name,  -- i v
                            p_oa_person_id	  => emp_without_mail_r.person_id,  -- i n
                            p_ad_first_name	  => l_first_name,                  -- i v
                            p_ad_last_name	  => l_last_name,                   -- i v
                            p_ad_mail	        => l_mail,                        -- i v
                            p_log_code	      => 'E',                           -- i v
                            p_log_message	    => 'Problem to update Person - '||l_err_desc, -- i v
                            p_err_code        => l_err_code,
                            p_err_desc        => l_err_desc);                   
             else
               fnd_file.put_line(fnd_file.log,'Success - '||l_mail);
               dbms_output.put_line('Success - '||l_mail);
               ins_log_msg( p_oa_emp_number	  => emp_without_mail_r.emp_num,    -- i v
                            p_oa_first_name	  => emp_without_mail_r.first_name, -- i v
                            p_oa_last_name	  => emp_without_mail_r.last_name,  -- i v
                            p_oa_person_id	  => emp_without_mail_r.person_id,  -- i n
                            p_ad_first_name	  => l_first_name,                  -- i v
                            p_ad_last_name	  => l_last_name,                   -- i v
                            p_ad_mail	        => l_mail,                        -- i v
                            p_log_code	      => 'S',                           -- i v
                            p_log_message	    => 'Success',                     -- i v
                            p_err_code        => l_err_code,
                            p_err_desc        => l_err_desc);    
             end if; -- l_err_code
          else
            ins_log_msg(p_oa_emp_number	  => emp_without_mail_r.emp_num,    -- i v
                        p_oa_first_name	  => emp_without_mail_r.first_name, -- i v
                        p_oa_last_name	  => emp_without_mail_r.last_name,  -- i v
                        p_oa_person_id	  => emp_without_mail_r.person_id,  -- i n
                        p_ad_first_name	  => l_first_name,                  -- i v
                        p_ad_last_name	  => l_last_name,                   -- i v
                        p_ad_mail	        => l_mail,                        -- i v
                        p_log_code	      => 'E',                           -- i v
                        p_log_message	    => 'Details are incorrect between OA and AD', -- i v
                        p_err_code        => l_err_code,
                        p_err_desc        => l_err_desc);  
          
            fnd_file.put_line(fnd_file.log,'Details are incorrect between OA and AD - ');   
            fnd_file.put_line(fnd_file.log,'First name OA - '||emp_without_mail_r.first_name|| ' AD -'||l_first_name);
            fnd_file.put_line(fnd_file.log,'Last  name OA - '||emp_without_mail_r.last_name|| ' AD -'||l_last_name); 
            fnd_file.put_line(fnd_file.log,'Emp   Num  OA - '||emp_without_mail_r.emp_num|| ' AD -'||l_emp_num);  
            dbms_output.put_line('Details are incorrect between OA and AD - ');   
            dbms_output.put_line('First name OA - '||emp_without_mail_r.first_name|| ' AD -'||l_first_name);
            dbms_output.put_line('Last  name OA - '||emp_without_mail_r.last_name|| ' AD -'||l_last_name);         
            dbms_output.put_line('Emp   Num  OA - '||emp_without_mail_r.emp_num|| ' AD -'||l_emp_num);
          end if; -- check person details
        end if; -- check nulls
      else
        ins_log_msg(p_oa_emp_number	  => emp_without_mail_r.emp_num,    -- i v
                        p_oa_first_name	  => emp_without_mail_r.first_name, -- i v
                        p_oa_last_name	  => emp_without_mail_r.last_name,  -- i v
                        p_oa_person_id	  => emp_without_mail_r.person_id,  -- i n
                        p_ad_first_name	  => l_first_name,                  -- i v
                        p_ad_last_name	  => l_last_name,                   -- i v
                        p_ad_mail	        => l_mail,                        -- i v
                        p_log_code	      => 'E',                           -- i v
                        p_log_message	    => l_err_desc, -- i v
                        p_err_code        => l_err_code,
                        p_err_desc        => l_err_desc1);  
      end if; -- err_code from AD                         
    end loop;
  exception
    when others then
      errbuf  := 'Gen exc - main - '||substr(sqlerrm,1,240);
      retcode := 2;
      dbms_output.put_line('Gen exc - main - '||substr(sqlerrm,1,240));
      fnd_file.put_line(fnd_file.log,'Gen exc - main - '||substr(sqlerrm,1,240));
      ins_log_msg(p_oa_emp_number	  => null, -- i v
                  p_oa_first_name	  => null, -- i v
                  p_oa_last_name	  => null, -- i v
                  p_oa_person_id	  => null, -- i n
                  p_ad_first_name	  => null, -- i v
                  p_ad_last_name	  => null, -- i v
                  p_ad_mail	        => null, -- i v
                  p_log_code	      => 'E',  -- i v
                  p_log_message	    => 'Gen exc - main - '||substr(sqlerrm,1,240), -- i v
                  p_err_code        => l_err_code,
                  p_err_desc        => l_err_desc);   
  end main;

end xxhr_ad2oa_pkg;
/
