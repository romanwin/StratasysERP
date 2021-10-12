create or replace package body XXHR_INTERFACES_PKG is
--------------------------------------------------------------------
--  name:            XXHR_INTERFACES_PKG
--  create by:       Dalit A. Raviv
--  Revision:        1.0
--  creation date:   26/06/2014 12:27:14
--------------------------------------------------------------------
--  purpose :        CHG0032233 - Upload HR data into Oracle
--                   Handle all HR interfaces programs
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  26/06/2014  Dalit A. Raviv    initial build
--------------------------------------------------------------------

  g_user_id              number := nvl(fnd_profile.value('USER_ID'), 2470);
  g_business_group_id    number := fnd_profile.value_specific('PER_BUSINESS_GROUP_ID');

  --------------------------------------------------------------------
  --  name:            get_message
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   27/07/2014
  --------------------------------------------------------------------
  --  purpose :        Handle messages
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  27/07/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  function get_message(p_name  in varchar2,
                       p_field in varchar2) return varchar2 is

  begin
    if p_name in ( 'XXHR_VALIDATION_NULL','XXHR_VALIDATION_VALID')  then
      fnd_message.SET_NAME('XXOBJT', p_name);
      fnd_message.SET_TOKEN('FIELD' ,p_field);
    end if;

    return fnd_message.get;
  end get_message;

  --------------------------------------------------------------------
  --  name:            ins_interface
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   26/06/2014
  --------------------------------------------------------------------
  --  purpose :        Handle - insert record to interface table
  --  in params:       p_file_name  -
  --                   p_location   -
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  26/06/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure ins_interface(errbuf          out  varchar2,
                          retcode         out  varchar2,
                          p_interface_rec in   t_interface_rec) is
  begin
    errbuf  := null;
    retcode := 0;

    insert into XXHR_INTERFACES
             (interface_id,
              batch_id,
              status,
              action,
              person_id,
              first_name,
              last_name,
              person_type,
              person_type_id,
              employee_number,
              national_identifier,
              hire_date,
              gender,
              birthdate,
              email,
              internal_location,
              local_last_name,     -- (attribute1)
              local_first_name,    -- (attribute2)
              home_email_address,  -- (attribute3)
              reference_number,    -- (attribute4)
              sf_title,            -- (attribute5)
              sf_job,              -- (attribute6)
              diploma,             -- (attribute7)
              attribute8,
              attribute9,
              attribute10,
              attribute11,
              attribute12,
              attribute13,
              attribute14,
              attribute15,
              attribute16,
              attribute17,
              attribute18,
              attribute19,
              attribute20,
              assignment_id,
              organization,
              job,
              position_name,       -- (most of US does not use positions)
              grade,
              location_code,
              supervisor,          -- (need to be a valid emp number)
              date_probation_end,
              probation_period,
              probation_unit,
              ass_attribute1,
              ass_attribute2,
              ass_attribute3,
              ass_attribute4,
              ass_attribute5,
              ass_attribute6,
              ass_attribute7,
              ass_attribute8,
              ass_attribute9,
              ass_attribute10,
              ass_attribute11,
              ass_attribute12,
              ass_attribute13,
              ass_attribute14,
              ass_attribute15,
              matrix_supervisor,   -- (attribute16) - (need to be a valid emp number )
              matrix_supervisor_id,
              ass_attribute17,
              ass_attribute18,
              ass_attribute19,
              ass_attribute20,
              ledger,              --(objet israel (usd))
              set_of_books_id,
              company,             -- 10
              department,          -- 630
              account,             -- 699999 - (if it is null to put 69999)
              code_combination_id,
              FTE_value,           -- (0-1) will handle in the program - only if different from 1 and 1 it will contain value.
              HC_value,            -- (0-1) will handle in the program - only if different from 1 and 1 it will contain value.
              reference_int_id,
              site_name,           -- (Territory) - will hold US, IL, APJ, EMEA etc
              change_date,         -- the date of the change if it is null for update: use sysdate, for creation: use start date else if there is value at change date use it.
              log_code,
              log_message,
              validation_msg,
              file_name,
              last_update_date,
              last_updated_by,
              last_update_login,
              creation_date,
              created_by)
    values (  xxhr_interfaces_s.nextval, /*p_interface_rec.interface_id*/
              p_interface_rec.batch_id,
              nvl(p_interface_rec.status,'NEW'),
              p_interface_rec.action,
              p_interface_rec.person_id,
              p_interface_rec.first_name,
              p_interface_rec.last_name,
              p_interface_rec.person_type,
              p_interface_rec.person_type_id,
              p_interface_rec.employee_number,
              p_interface_rec.national_identifier,
              p_interface_rec.hire_date,
              p_interface_rec.gender,
              p_interface_rec.birthdate,
              p_interface_rec.email,
              p_interface_rec.internal_location,
              p_interface_rec.local_last_name,     -- (attribute1)
              p_interface_rec.local_first_name,    -- (attribute2)
              p_interface_rec.home_email_address,  -- (attribute3)
              p_interface_rec.reference_number,    -- (attribute4)
              p_interface_rec.sf_title,            -- (attribute5)
              p_interface_rec.sf_job,              -- (attribute6)
              p_interface_rec.diploma,             -- (attribute7)
              p_interface_rec.attribute8,
              p_interface_rec.attribute9,
              p_interface_rec.attribute10,
              p_interface_rec.attribute11,
              p_interface_rec.attribute12,
              p_interface_rec.attribute13,
              p_interface_rec.attribute14,
              p_interface_rec.attribute15,
              p_interface_rec.attribute16,
              p_interface_rec.attribute17,
              p_interface_rec.attribute18,
              p_interface_rec.attribute19,
              p_interface_rec.attribute20,
              p_interface_rec.assignment_id,
              p_interface_rec.organization,
              p_interface_rec.job,
              p_interface_rec.position_name,       -- (most of US does not use positions)
              p_interface_rec.grade,
              p_interface_rec.location_code,
              p_interface_rec.supervisor,          -- (need to be a valid emp number)
              p_interface_rec.date_probation_end,
              p_interface_rec.probation_period,
              p_interface_rec.probation_unit,
              p_interface_rec.ass_attribute1,
              p_interface_rec.ass_attribute2,
              p_interface_rec.ass_attribute3,
              p_interface_rec.ass_attribute4,
              p_interface_rec.ass_attribute5,
              p_interface_rec.ass_attribute6,
              p_interface_rec.ass_attribute7,
              p_interface_rec.ass_attribute8,
              p_interface_rec.ass_attribute9,
              p_interface_rec.ass_attribute10,
              p_interface_rec.ass_attribute11,
              p_interface_rec.ass_attribute12,
              p_interface_rec.ass_attribute13,
              p_interface_rec.ass_attribute14,
              p_interface_rec.ass_attribute15,
              p_interface_rec.matrix_supervisor,   -- (attribute16) - (need to be a valid emp number )
              p_interface_rec.matrix_supervisor_id,
              p_interface_rec.ass_attribute17,
              p_interface_rec.ass_attribute18,
              p_interface_rec.ass_attribute19,
              p_interface_rec.ass_attribute20,
              p_interface_rec.ledger,              --(objet israel (usd))
              p_interface_rec.set_of_books_id,
              p_interface_rec.company,             -- 10
              p_interface_rec.department,          -- 630
              nvl(p_interface_rec.account,699999), -- 699999 - (if it is null to put 69999)
              p_interface_rec.code_combination_id,
              nvl(p_interface_rec.FTE_value,1),    -- (0-1) will handle in the program - only if different from 1 and 1 it will contain value.
              nvl(p_interface_rec.HC_value,1),     -- (0-1) will handle in the program - only if different from 1 and 1 it will contain value.
              p_interface_rec.reference_int_id,
              p_interface_rec.site_name,           -- (Territory) - will hold US, IL, APJ, EMEA etc
              p_interface_rec.change_date,         -- the date of the change if it is null for update: use sysdate, for creation: use start date else if there is value at change date use it.
              p_interface_rec.log_code,
              p_interface_rec.log_message,
              null, null,sysdate, g_user_id, -1, sysdate, g_user_id);

  exception
    when others then
      errbuf   := 'GEN EXC - ins_interface - '||substr(sqlerrm,1,240);
      retcode  := 1;
  end ins_interface;

  --------------------------------------------------------------------
  --  name:            delete_interface
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   18/08/2014
  --------------------------------------------------------------------
  --  purpose :        Handle - delete interface table. keep only 1 year information.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  18/08/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure delete_interface (errbuf   out  varchar2,
                              retcode  out  varchar2) is

  begin
    delete XXHR_INTERFACES i
    where  i.creation_date < sysdate - 365;

    commit;
  exception
    when others then
      errbuf   := 'GEN EXC - delete_interface - '||substr(sqlerrm,1,240);
      retcode  := 1;
  end delete_interface;

  --------------------------------------------------------------------
  --  name:            upd_interface
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   26/06/2014
  --------------------------------------------------------------------
  --  purpose :        Handle - update all id's per record at interface table
  --  in params:
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  26/06/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure upd_interface (errbuf          out  varchar2,
                           retcode         out  varchar2,
                           p_interface_rec in   t_interface_rec,
                           p_log_code      in   varchar2,
                           p_log_message   in   varchar2,
                           p_entity        in   varchar2) is

    PRAGMA AUTONOMOUS_TRANSACTION;
  begin
    errbuf  := null;
    retcode := 0;
    if p_entity = 'VALIDATION' then
      update XXHR_INTERFACES i
      set    i.person_type_id       = p_interface_rec.person_type_id,
             i.organization_id      = p_interface_rec.organization_id,      --   l_organization_id,
             i.grade_id             = p_interface_rec.grade_id,             --   l_grade_id,
             i.location_id          = p_interface_rec.location_id,          --   l_location_id,
             i.job_id               = p_interface_rec.job_id,               --   l_job_id,
             i.position_id          = p_interface_rec.position_id,          --   l_position_id,
             i.supervisor_id        = p_interface_rec.supervisor_id,        --   l_supervisor_id,
             i.set_of_books_id      = p_interface_rec.set_of_books_id,      --   l_set_of_books_id,
             i.code_combination_id  = p_interface_rec.code_combination_id,  --   l_code_comb_id,
             -- Dalit A. Raviv 24/12/2014.
             i.hire_date            = p_interface_rec.hire_date,
             i.birthdate            = p_interface_rec.birthdate,
             i.date_probation_end   = p_interface_rec.date_probation_end,
             i.change_date          = sysdate,
             --
             i.log_code             = p_log_code,
             i.validation_msg       = p_log_message,
             i.status               = case when p_log_code = 'E' then
                                             'E'
                                           else
                                             'S'
                                      end,
             i.action               = 'VALIDATION',
             i.last_update_date     = sysdate
      where  i.interface_id         = p_interface_rec.interface_id;
    elsif p_entity = 'INSERT' then
      update XXHR_INTERFACES i
      set    i.person_id            = p_interface_rec.person_id,
             i.assignment_id        = p_interface_rec.assignment_id,
             i.employee_number      = p_interface_rec.employee_number,
             i.action               = p_interface_rec.action,
             i.last_update_date     = sysdate
      where  i.interface_id         = p_interface_rec.interface_id;
    elsif p_entity = 'UPDATE' then
      update XXHR_INTERFACES i
      set    i.person_id            = p_interface_rec.person_id,
             i.assignment_id        = p_interface_rec.assignment_id,
             i.action               = p_interface_rec.action,
             i.last_update_date     = sysdate
      where  i.interface_id         = p_interface_rec.interface_id;
    else
      update XXHR_INTERFACES i
      set    i.log_code             = p_log_code,
             i.log_message          = case when i.log_message is not null then
                                              i.log_message||', '||p_log_message
                                           else
                                              p_log_message
                                      end ,

             i.status               = case when p_log_code = 'E' then
                                             'E'
                                           else
                                             'S'
                                      end,
             i.action               = p_interface_rec.action,
             i.last_update_date     = sysdate
      where  i.interface_id         = p_interface_rec.interface_id;
    end if;

    commit;
  exception
    when others then
      errbuf   := 'GEN EXC - upd_interface - '||substr(sqlerrm,1,240);
      retcode  := 1;
  end upd_interface;

  --------------------------------------------------------------------
  --  name:            gen_validation
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   26/06/2014
  --------------------------------------------------------------------
  --  purpose :        Handle - all general validations that need to do
  --  in params:
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  26/06/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure gen_validation (errbuf          out    varchar2,
                            retcode         out    varchar2,
                            p_interface_rec in out t_interface_rec)  is

    l_message         varchar(2000)  := null;
    l_code            varchar2(10)   := null;
    l_code_s          varchar2(10)   := null;
    l_person_type_id  number         := null;
    l_organization_id number         := null;
    l_grade_id        number         := null;
    l_location_id     number         := null;
    l_job_id          number         := null;
    l_position_id     number         := null;
    l_supervisor_id   number         := null;
    l_set_of_books_id number         := null;
    l_company         varchar2(150)  := null;
    l_dept            varchar2(150)  := null;
    l_account         varchar2(150)  := null;
    l_code_comb_id    number         := null;
    l_chart_of_accounts_id  number         := null;
    l_return                varchar2(240)  := null;
    l_concatenated_segments varchar2(240)  := null;
    l_return_code           varchar2(100)  := null;
    l_err_msg               varchar2(2500) := null;

    l_errbuf                varchar2(2000) := null;
    l_retcode               varchar2(100)  := null;
  begin

    errbuf   := null;
    retcode  := 0;

    -------------------------------
    -- Check Person Type
    -- 1) not null
    if p_interface_rec.person_type is null then
      if l_message is null then
        l_message := get_message('XXHR_VALIDATION_NULL','Person type');--'Person type is null';
      else
        l_message := l_message||', '||get_message('XXHR_VALIDATION_NULL','Person type');
      end if;
      l_code      := 'E';
    else
      -- 2) value is a valid value
      begin
        select typ.person_type_id
        into   l_person_type_id
        from   per_person_types     typ
        where  typ.user_person_type = p_interface_rec.person_type;
      exception
        when others then
          if l_message is null then
            l_message := get_message('XXHR_VALIDATION_VALID','Person type'); --'Person type value is invalid';
          else
            l_message := l_message||', '||get_message('XXHR_VALIDATION_VALID','Person type');
          end if;
          l_code      := 'E';
      end;
    end if;  
    -------------------------------
    -- Check employee number
    -- not null
    -- Dalit A. Raviv 23/12/2014 add validation if emp number is null we can not know who is this employee.
    if p_interface_rec.employee_number is null then
      if l_message is null then
        l_message := get_message('XXHR_VALIDATION_NULL','Employee Number'); --'Employee Number is null';
      else
        l_message := l_message||', '||get_message('XXHR_VALIDATION_NULL','Employee Number');
      end if;
      l_code      := 'E';
    end if;  
    -------------------------------
    -- Check Gender
    -- Dalit A. Raviv 23/12/2014 add new validations for gender, last name, and first name.
    -- Add validation to gender field 
    if p_interface_rec.gender is not null then
      if upper(p_interface_rec.gender) not in ('F','M') then
        if l_message is null then
          l_message := get_message('XXHR_VALIDATION_VALID','Gender'); --'Gender value is invalid';
        else
          l_message := l_message||', '||get_message('XXHR_VALIDATION_VALID','Gender');
        end if;
        l_code      := 'E';
      end if;
    elsif p_interface_rec.gender is null then
      -- can not create person without gender (null)
      if l_message is null then
        l_message := get_message('XXHR_VALIDATION_NULL','Gender'); --'Gender value is invalid';
      else
        l_message := l_message||', '||get_message('XXHR_VALIDATION_NULL','Gender');
      end if;
      l_code      := 'E';
    end if;
    -------------------------------
    -- Check Last Name
    -- API finished with error if no last name provide.
    if p_interface_rec.last_name is null then
      if l_message is null then
        l_message := get_message('XXHR_VALIDATION_NULL','Last Name'); --'Last Name value is null';
      else
        l_message := l_message||', '||get_message('XXHR_VALIDATION_NULL','Last Name');
      end if;
      l_code      := 'E';
    end if;
    -------------------------------
    -- Check First Name
    if p_interface_rec.first_name is null then
      if l_message is null then
        l_message := get_message('XXHR_VALIDATION_NULL','First Name'); --'First Name value is null';
      else
        l_message := l_message||', '||get_message('XXHR_VALIDATION_NULL','Fisrt Name');
      end if;
      l_code      := 'E';
    end if;
    -------------------------------
    -- Handle dates and date formates
    -------------------------------
    -- Check Hire Date
    -- Hire date is a required date, we can not create a person without this date
    begin
      if p_interface_rec.hire_date_var is not null then
        p_interface_rec.hire_date := to_date(p_interface_rec.hire_date_var, 'MM/DD/YYYY');
      end if;
    exception
      when others then
        if l_message is null then
          l_message := get_message('XXHR_VALIDATION_VALID','Hire Date')||' date format should be MM/DD/YYYY'; --'Hire Date value is invalid';
        else
          l_message := l_message||', '||get_message('XXHR_VALIDATION_VALID','Hire Date')||' date format should be MM/DD/YYYY';
        end if;
        l_code      := 'E';
    end;
    -------------------------------
    -- Check Birthdate
    -- Birthdate is not a must date, and as oracle is not the major system and we do not handle payroll 
    -- at oracle - this field is not influence other process.
    begin  
      if p_interface_rec.birthdate_var is not null then
        p_interface_rec.birthdate := to_date(p_interface_rec.birthdate_var, 'MM/DD/YYYY');
      end if;
    exception
      when others then
        if l_message is null then
          l_message := get_message('XXHR_VALIDATION_VALID','Birthdate')||' date format should be MM/DD/YYYY'; --'Birthdate value is invalid';
        else
          l_message := l_message||', '||get_message('XXHR_VALIDATION_VALID','Birthdate')||' date format should be MM/DD/YYYY';
        end if;
        l_code_s      := 'S';
    end;
    -------------------------------
    -- Check Probaltion date
    -- Probation is not a must date and not influence other process therfor we can create the person
    begin 
      if p_interface_rec.date_probation_end_var is not null then
        p_interface_rec.date_probation_end := to_date(p_interface_rec.date_probation_end_var, 'MM/DD/YYYY'); 
      end if;
    exception
      when others then
        if l_message is null then
          l_message := get_message('XXHR_VALIDATION_VALID','Probation Date')||' date format should be MM/DD/YYYY'; --'Probation Date value is invalid';
        else
          l_message := l_message||', '||get_message('XXHR_VALIDATION_VALID','Probation Date')||' date format should be MM/DD/YYYY';
        end if;
        l_code_s      := 'S';  
    end;
    -- end 23/12/2014

    -- Dalit A. Raviv 23/12/2014 no need to upload SF_JOB and Diploma
    -- code took out
    
    -------------------------------
    -- Check Organization
    -- Dalit A. Raviv 23/12/2014 no need to check if null
    -- If the excel will provide organization null - the API will create the assignment with 
    -- the default organization - "Setup Business Group" 
    -- There is an alert that go and look for all people that relate to organization - "Setup Business Group" 
    -- and notify on it.
    if p_interface_rec.organization is not null then
      -- value is a valid value
      begin
        select o.funitid
        into   l_organization_id
        from   xxhr_organization_chart_v  o
        where  o.fUnit_Name = p_interface_rec.organization;

      exception
        when others then
          if l_message is null then
            l_message := get_message('XXHR_VALIDATION_VALID','Organization'); --'Organization value is invalid';
          else
            l_message := l_message||', '||get_message('XXHR_VALIDATION_VALID','Organization');
          end if;
          l_code      := 'E';
      end;
    end if;
    -------------------------------
    -- Check Grade (The grade sequence is very important in several processes.)
    -- Dalit A. Raviv 23/12/2014 no need to check if null
    -- !!!!! Grade influnce several approval process, 
    -- !!!!! HR decidedd that this field will not be handle anymore in oracle.
    if p_interface_rec.grade is not null then
      -- value is a valid value
      begin
        select pg.grade_id
        into   l_grade_id
        from   per_grades pg
        where  name       = p_interface_rec.grade
        and    ((date_to is null) or (date_to > trunc(sysdate)));

      exception
        when others then
          if l_message is null then
            l_message := get_message('XXHR_VALIDATION_VALID','Grade');--'Grade value is invalid';
          else
            l_message := l_message||', '||get_message('XXHR_VALIDATION_VALID','Grade');
          end if;
          l_code      := 'E';
      end;
    end if;
    -------------------------------
    -- Check Location
    -- 1) null value
    if p_interface_rec.location_code is null then
      if l_message is null then
        l_message := get_message('XXHR_VALIDATION_NULL','Location');--'Location is null';
      else
        l_message := l_message||', '||get_message('XXHR_VALIDATION_NULL','Location');
      end if;
      l_code      := 'E';
    else
      -- 2) value is a valid value
      begin
        select hrloc.location_id
        into   l_location_id
        from   hr_locations   hrloc
        where  hrloc.location_code  = p_interface_rec.location_code;

      exception
        when others then
          if l_message is null then
            l_message := get_message('XXHR_VALIDATION_VALID','Location');--'Location value is invalid';
          else
            l_message := l_message||', '||get_message('XXHR_VALIDATION_VALID','Location');
          end if;
          l_code      := 'E';
      end;
    end if;
    -------------------------------
    -- Check Job
    -- Dalit A. Raviv 23/12/2014 no need to check if null
    -- If there is a position and no job the API will finish with error
    if p_interface_rec.job is not null then 
      -- value is a valid value
      begin
        select pj.job_id
        into   l_job_id
        from   per_jobs pj
        where  name     = p_interface_rec.job
        and    ((date_to is null) or (date_to > trunc(sysdate)));

      exception
        when others then
          if l_message is null then
            l_message := get_message('XXHR_VALIDATION_VALID','Job');
          else
            l_message := l_message||', '||get_message('XXHR_VALIDATION_VALID','Job');
          end if;
          l_code      := 'E';
      end;
    end if;
    -------------------------------
    -- Check Position - US do not use position
    -- Dalit A. Raviv 23/12/2014 no need to check if null
    if p_interface_rec.position_name is not null then
      -- value is a valid value
      begin
        select pp.position_id
        into   l_position_id
        from   per_all_positions   pp
        where  pp.name             = p_interface_rec.position_name
        and    ((date_end is null) or (date_end > trunc(sysdate))) and nvl(status,'VALID') = 'VALID';

      exception
        when others then
          if l_message is null then
            l_message := get_message('XXHR_VALIDATION_VALID','Position');
          else
            l_message := l_message||', '||get_message('XXHR_VALIDATION_VALID','Position');
          end if;
          l_code      := 'E';
      end;
    end if;
    -------------------------------
    -- Check Supervisor
    -- 1) null value
    if p_interface_rec.supervisor is null then
      if l_message is null then
        l_message := get_message('XXHR_VALIDATION_NULL','Supervisor');--'SUPERVISOR is null';
      else
        l_message := l_message||', '||get_message('XXHR_VALIDATION_NULL','Supervisor');
      end if;
      l_code    := 'E';
    else
      -- 2) value is a valid value
      begin
        select p.person_id
        into   l_supervisor_id
        from   per_all_people_f p
        where  nvl(p.employee_number,p.npw_number) = p_interface_rec.supervisor -- it is the supervisor number
        and    trunc(sysdate) between p.effective_start_date and p.effective_end_date;

      exception
        when others then
          if l_message is null then
            l_message := get_message('XXHR_VALIDATION_VALID','Supervisor');
          else
            l_message := l_message||', '||get_message('XXHR_VALIDATION_VALID','Supervisor');
          end if;
          l_code      := 'E';
      end;
    end if;

    -------------------------------
    -- Check Purchase order information - Ledger (set of book)
    if p_interface_rec.ledger is not null then
    -- Dalit A. Raviv 24/12/2014 no need to check if null
    -- value is a valid value
      begin
        select g.set_of_books_id, g.chart_of_accounts_id
        into   l_set_of_books_id, l_chart_of_accounts_id
        from   gl_sets_of_books g
        where  g.mrc_sob_type_code <> 'R'
        and    g.name           = p_interface_rec.ledger;

      exception
        when others then
          if l_message is null then
            l_message := get_message('XXHR_VALIDATION_VALID','POI Ledger');
          else
            l_message := l_message||', '||get_message('XXHR_VALIDATION_VALID','POI Ledger');
          end if;
          l_code      := 'E';
      end;
    end if; -- ledger is not null
    -------------------------------
    -- Check Purchase order information - Company
    -- Dalit A. Raviv 24/12/2014 no need to check if null
    if p_interface_rec.company is not null then
      -- value is a valid value
      l_return := null;
      if p_interface_rec.ledger = 'Stratasys US' then
        l_return := xxobjt_general_utils_pkg.get_valueset_desc('XXGL_COMPANY_SS', p_interface_rec.company,'ACTIVE'); 
      else
        l_return := xxobjt_general_utils_pkg.get_valueset_desc('XXGL_COMPANY_SEG', p_interface_rec.company,'ACTIVE'); 
      end if;
      if l_return is not null then
          l_company := p_interface_rec.company;
      else
        if l_message is null then
          l_message := get_message('XXHR_VALIDATION_VALID','POI Company');
        else
          l_message := l_message||', '||get_message('XXHR_VALIDATION_VALID','POI Company');
        end if;
        l_code      := 'E';
      end if;-- return is not null 
    end if;-- Company is not null
    -------------------------------
    -- Check Purchase order information - Department
    -- Dalit A. Raviv 24/12/2014 no need to check if null
    if p_interface_rec.department is not null then
      -- value is a valid value
      l_return := null;
      if p_interface_rec.ledger = 'Stratasys US' then
        l_return := xxobjt_general_utils_pkg.get_valueset_desc('XXGL_DEPARTMENT_SS', p_interface_rec.department,'ACTIVE'); 
      else
        l_return := xxobjt_general_utils_pkg.get_valueset_desc('XXGL_DEPARTMENT_SEG', p_interface_rec.department,'ACTIVE'); 
      end if;
      if l_return is not null then
          l_dept := p_interface_rec.department;
      else
        if l_message is null then
          l_message := get_message('XXHR_VALIDATION_VALID','POI Department');--'POI DEPARTMENT';
        else
          l_message := l_message||', '||get_message('XXHR_VALIDATION_VALID','POI Department');
        end if;
        l_code      := 'E';
      end if;-- return is not null 
    end if;-- dept is not null
    -------------------------------
    -- Check Purchase order information - Account
    -- 1) null value
    if p_interface_rec.account is not null then
      -- Dalit A. Raviv 24/12/2014 no need to check if null
      -- value is a valid value
      l_return := null;
      if p_interface_rec.ledger = 'Stratasys US' then
        l_return := xxobjt_general_utils_pkg.get_valueset_desc('XXGL_ACCOUNT_SS', p_interface_rec.account,'ACTIVE'); 
      else
        l_return := xxobjt_general_utils_pkg.get_valueset_desc('XXGL_ACCOUNT_SEG', p_interface_rec.account,'ACTIVE'); 
      end if;
      if l_return is not null then
          l_account := p_interface_rec.account;
      else
        if l_message is null then
          l_message := get_message('XXHR_VALIDATION_VALID','POI Account');
        else
          l_message := l_message||', '||get_message('XXHR_VALIDATION_VALID','POI Account');
        end if;
        l_code      := 'E';
      end if; -- return is not null
    end if; -- account is not null
    
    -- Dalit A. Raviv 23/12/2014
    if (p_interface_rec.ledger is null and p_interface_rec.company is null and 
        p_interface_rec.department is null and p_interface_rec.account is null) then
      null; -- do create the person
    -- one of the fields is null create the person but give message
    elsif l_company is null or l_dept is null or l_set_of_books_id is null/*or l_account is null*/ then
      if l_message is null then
        l_message := get_message('XXHR_VALIDATION_VALID','POI Code Combination');--'POI CC';
      else
        l_message := l_message||', '||get_message('XXHR_VALIDATION_VALID','POI Code Combination');
      end if;
      --l_code      := 'E';
      l_code_comb_id := null;
      l_code_s    := 'S';
    else
      -------------------------------
      -- get the code combination id (all fields contain data)
      begin
        if p_interface_rec.ledger = 'Stratasys US' then
          select code_combination_id
          into   l_code_comb_id
          from   gl_code_combinations_kfv k
          where  k.concatenated_segments = l_company||'.'||l_dept||'.'||nvl(l_account,'699999')||'.000.000.00.000.0000'
          and    k.chart_of_accounts_id  = l_chart_of_accounts_id;
          -- Dalit A. Raviv 24/12/2014
          l_concatenated_segments := l_company||'.'||l_dept||'.'||nvl(l_account,'699999')||'.000.000.00.000.0000'; 
        elsif p_interface_rec.ledger <> 'Stratasys US' and p_interface_rec.ledger is not null then
          select code_combination_id
          into   l_code_comb_id
          from   gl_code_combinations_kfv k
          where  k.concatenated_segments = l_company||'.'||l_dept||'.'||nvl(l_account,'699999')||'.0000000.000.000.00.0000.000000'
          and    k.chart_of_accounts_id  = l_chart_of_accounts_id;
          -- Dalit A. Raviv 24/12/2014
          l_concatenated_segments := l_company||'.'||l_dept||'.'||nvl(l_account,'699999')||'.0000000.000.000.00.0000.000000';
        end if;
      exception
        when others then
          -- Dalit A. Raviv 24/12/2014 if did not found code combination this function will create new CCI 
          xxgl_utils_pkg.get_and_create_account(p_concat_segment      => l_concatenated_segments,
                                                p_coa_id              => l_chart_of_accounts_id,
                                                p_app_short_name      => null,
                                                x_code_combination_id => l_code_comb_id,
                                                x_return_code         => l_return_code, -- if return <> 'S' error messge
                                                x_err_msg             => l_err_msg); 
                                                
          if l_return_code <> 'S' then
            l_message := get_message('XXHR_VALIDATION_VALID','POI Code Combination')|| ' , API ERR - '||l_err_msg;--'POI CC';
          else
            l_message := l_message||', '||get_message('XXHR_VALIDATION_VALID','POI Code Combination')|| ' , API ERR - '||l_err_msg;
          end if;
          --l_code      := 'E';
          l_code_comb_id := null;
          l_code_s    := 'S';
      end;
    end if;-- 23/12/2014
    p_interface_rec.person_type_id       := l_person_type_id;
    if l_organization_id is not null then
      p_interface_rec.organization_id      := l_organization_id;
    end if;
    if l_grade_id is not null then
      p_interface_rec.grade_id             := l_grade_id;
    end if;
    p_interface_rec.location_id          := l_location_id;
    if l_job_id is not null then
      p_interface_rec.job_id               := l_job_id;
    end if;
    if l_position_id is not null then
      p_interface_rec.position_id          := l_position_id;
    end if;
    p_interface_rec.supervisor_id        := l_supervisor_id;
    if l_set_of_books_id is not null then
      p_interface_rec.set_of_books_id      := l_set_of_books_id;
    end if;
    if l_code_comb_id is not null then
      p_interface_rec.code_combination_id  := l_code_comb_id;
    end if;
    p_interface_rec.validation_msg       := l_message;
    p_interface_rec.log_code             := case when l_code_s is not null and l_code is not null then
                                                   l_code
                                                 when l_code_s is null and l_code is not null then
                                                   l_code
                                                 else
                                                   'S' -- l_code_s
                                            end;
    
    p_interface_rec.action := 'VALIDATION';
    --------------------------------------------------------------
    l_errbuf   := null;
    l_retcode  := 0;
    upd_interface (errbuf          => l_errbuf,  -- o v
                   retcode         => l_retcode, -- o v
                   p_interface_rec => p_interface_rec, -- i t_interface_rec,
                   p_log_code      => case when l_code_s is not null and l_code is not null then
                                             l_code
                                           when l_code_s is null and l_code is not null then
                                             l_code
                                           else
                                             'S'       -- l_code_s
                                       end,            -- i v
                   p_log_message   => l_message,       -- i v
                   p_entity        => 'VALIDATION');

    if (l_message is not null and l_code is not null ) then
      retcode  := 1;
    elsif (l_message is not null and l_code is null ) then
      retcode  := 0;
    end if;
    errbuf   := l_message;

  exception
    when others then
      errbuf   := 'GEN EXC - gen_validation - '||substr(sqlerrm,1,240);
      retcode  := 1;
  end gen_validation;

  --------------------------------------------------------------------
  --  name:            upload_file
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   30/06/2014
  --------------------------------------------------------------------
  --  purpose :        Handle - upload of the excel file
  --  in params:       p_file_name  -
  --                   p_location   -
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  30/06/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure upload_file(errbuf                         out varchar2,
                        retcode                        out varchar2,
                        p_table_name                   in varchar2, -- XXHR_INTERFACES
                        p_template_name                in varchar2, -- GEN
                        p_file_name                    in varchar2,
                        p_directory                    in varchar2) is

    l_errbuf        VARCHAR2(3000);
    l_retcode       VARCHAR2(3000);
    l_request_id    NUMBER := fnd_global.conc_request_id;

    stop_processing EXCEPTION;
  begin
    errbuf  := 'Success';
    retcode := '0';

    -- Load data from CSV-table into XXHR_INTERFACES table
    xxobjt_table_loader_util_pkg.load_file(errbuf                 => l_errbuf,
                                           retcode                => l_retcode,
                                           p_table_name           => p_table_name, -- 'XXHR_INTERFACES',
                                           p_template_name        => p_template_name,
                                           p_file_name            => p_file_name,
                                           p_directory            => p_directory,  -- /UtlFiles/shared/DEV
                                           p_expected_num_of_rows => NULL);

    if l_retcode <> '0' then
      fnd_file.put_line(fnd_file.log, l_errbuf);
      retcode := '2';
      errbuf  := l_errbuf;
      raise stop_processing;
    end if;

    fnd_file.put_line(fnd_file.log,'All records from file ' || p_file_name ||' were successfully loaded into table XXHR_INTERFACES');

    update XXHR_INTERFACES i
    set    i.file_name  = p_file_name
    where  i.batch_id   = l_request_id;
    commit;
  exception
    when stop_processing then
      null;
    when others then
      errbuf   := 'GEN EXC - upload_file - '||substr(sqlerrm,1,240);
      retcode  := 1;
  end upload_file;

  --------------------------------------------------------------------
  --  name:            check_emp_number
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   02/07/2014
  --------------------------------------------------------------------
  --  purpose :        check employee number from excel file exists in oracle
  --                   this will determin if the program will go to create or update person.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  02/07/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  function check_emp_number (p_emp_number in number) return varchar2 is
    l_exists varchar2(10) := null;
  begin
    if p_emp_number is null then
      return 'N';
    else
      select 'Y'
      into   l_exists
      from   per_all_people_f p
      where  nvl(p.employee_number, p.npw_number) = p_emp_number
      and    trunc(sysdate) between p.effective_start_date and p.effective_end_date;

      return l_exists;
    end if;
  exception
    when no_data_found  then
      return 'N';
    when TOO_MANY_ROWS then
      return 'Y';
    when others then
      return 'N';

  end check_emp_number;

  --------------------------------------------------------------------
  --  name:            check_NID
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   02/07/2014
  --------------------------------------------------------------------
  --  purpose :        check national identifier from excel file exists in oracle
  --                   this will determin if nid exists in oracle it means that the person exists in oracle
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  02/07/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  function check_NID (p_nid        in varchar2) return varchar2 is
    l_exists varchar2(10) := null;
  begin
    if p_nid is null then
      return 'N';
    else
      select 'Y'
      into   l_exists
      from   per_all_people_f p
      where  p.national_identifier = p_nid;

      return l_exists;
    end if;
  exception
    when no_data_found  then
      begin
        select 'Y'
        into   l_exists
        from   per_all_people_f p
        where  p.national_identifier = '0'||p_nid;

        return l_exists;
      exception
        when TOO_MANY_ROWS then
          return 'Y';
        when others then
          return 'N';
      end;
      --return 'N';
    when too_many_rows then
      return 'Y';
    when others then
      --dbms_output.put_line(substr(sqlerrm,1,240));
      return 'N';

  end check_NID;

  --------------------------------------------------------------------
  --  name:            check_NID_rel
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   30/12/2014
  --------------------------------------------------------------------
  --  purpose :        In Case of UPDATE the validation need to be a bit different
  --                   check if NID exists at the person tbl, if YES do it exists for this employee_number?
  --                   if yes -> UPDATE if exists for another employee_number -> ERR
  --                   There is a case that employee do not have NID and now we want to UPDATE this data.
  --                   in this case i will check that this employee_number have no NID - yes -> UPDATE - No -> ERR
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  30/12/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  function check_NID_rel (p_nid        in varchar2,
                          p_emp_num    in varchar2) return varchar2 is
                      
    l_emp_num varchar2(100) := null;
    l_nid     varchar2(150) := null;
    
  begin
    -- check NID exists at person tbl   
    select nvl(p.employee_number, p.npw_number)
    into   l_emp_num
    from   per_all_people_f p
    where  p.national_identifier = p_nid
    and    trunc(sysdate)        between p.effective_start_date and p.effective_end_date;
    -- if exists check that the emp number found is relate to this enmployee number
    if l_emp_num <> p_emp_num then
      return 'N';
    else
      return 'Y';
    end if;
  exception
    when NO_DATA_FOUND then
      begin
        -- sometime the excel eliminate ziro from the string
        -- there for i need to check concatenated string too
        select nvl(p.employee_number, p.npw_number)
        into   l_emp_num
        from   per_all_people_f p
        where  p.national_identifier = '0'||p_nid
        and    trunc(sysdate)        between p.effective_start_date and p.effective_end_date;
        -- if exists check that the emp number found is relate to this enmployee number
        if l_emp_num <> p_emp_num then
          return 'N';
        else
          return 'Y';
        end if;
      exception
        when NO_DATA_FOUND then
          -- the NID did not found at any row maybee because the person need to update from NULL 
          -- to NID value that come with the excel upload file.
          -- therefor i added this check 
          -- check that this employee do not have NID
          select p.national_identifier
          into   l_nid
          from   per_all_people_f p
          where  nvl(p.employee_number, p.npw_number) = p_emp_num;
          
          if l_nid is null then
            return 'Y';
          else
            return 'N'; 
          end if;
        when others then
          return 'N';
      end; 
    when others then
      return 'N';
  end check_NID_rel;

  --------------------------------------------------------------------
  --  name:            update_person
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   06/07/2014
  --------------------------------------------------------------------
  --  purpose :        update person details by using oracle API
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  06/07/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure update_person (errbuf          out    varchar2,
                           retcode         out    varchar2,
                           p_interface_rec in out t_interface_rec) is

    l_person_id              number;
    l_ovn                    number;
    l_log_code               varchar2(100);
    l_log_message            varchar2(500);
    l_errbuf                 varchar2(2000);
    l_retcode                varchar2(100);
    l_interface_rec          t_interface_rec;
    l_effective_start_date   date;           -- api out param
    l_effective_end_date     date;           -- api out param
    l_full_name              varchar2(100);  -- api out param
    l_comment_id             number(15);     -- api out param
    l_orig_hire_warning      boolean;        -- api out param
    l_assign_payroll_warning boolean;        -- api out param
    l_name_combination_warning boolean;      -- api out param

    l_first_name             varchar2(150);
    l_last_name              varchar2(150);
    l_date_of_birth          date;
    l_email_address          varchar2(150);
    l_person_type_id         number;
    l_attribute3             varchar2(150);
    lc_dt_ud_mode            varchar2(100);
    l_orig_date              date;

    my_exception             exception;

  begin
    errbuf   := null;
    retcode  := 0;

    begin
      select person_id, first_name, last_name, date_of_birth, email_address, 
             person_type_id, attribute3, original_date_of_hire 
      into   l_person_id, l_first_name, l_last_name, l_date_of_birth, l_email_address, 
             l_person_type_id, l_attribute3, l_orig_date
      from   per_all_people_f papf
      where  nvl(papf.employee_number,papf.npw_number) = p_interface_rec.employee_number
      and    trunc(sysdate)                            between papf.effective_start_date and papf.effective_end_date;
    exception
      when others then
        l_log_code := 'E';
        l_log_message := 'No Person found for emp_number '||p_interface_rec.employee_number;
        -- add update of ERROR
        l_interface_rec.interface_id := p_interface_rec.interface_id;
        upd_interface (errbuf          => l_errbuf,        -- o v
                       retcode         => l_retcode,       -- o v
                       p_interface_rec => l_interface_rec, -- i t_interface_rec,
                       p_log_code      => l_log_code,      -- i v
                       p_log_message   => l_log_message,   -- i v
                       p_entity        => 'UPD_PERSON');   -- i v

        errbuf   := 'No Person found for emp_number '||p_interface_rec.employee_number;
        retcode  := 1;
        raise my_exception;
    end;

    -- Set DateTrack Mode (Oracle code)
    -- Change date is allways sysdate
    lc_dt_ud_mode := get_datetrack_mode(p_table_name => 'PER_ALL_PEOPLE_F', -- i v
                                        p_key_column => 'PERSON_ID',        -- i v
                                        p_key_value  => l_person_id,        -- i n
                                        p_date       => trunc(sysdate) );   -- i d

    select max(object_version_number)
    into   l_ovn
    from   per_all_people_f
    where  person_id = l_person_id;
    -- check if any of the field need to update
    if ((l_first_name                        <> p_interface_rec.first_name) or
        (l_last_name                         <> p_interface_rec.last_name) or
        (l_person_type_id                    <> p_interface_rec.person_type_id) or
        (nvl(l_date_of_birth,trunc(sysdate)) <> nvl(p_interface_rec.birthdate,trunc(sysdate))) or
        (nvl(l_email_address,'XXX')          <> nvl(p_interface_rec.email,'XXX')) or
        (nvl(l_attribute3,'XXX')             <> nvl(p_interface_rec.home_email_address,'XXX')) 
        ) then

      hr_person_api.update_person
              ( p_effective_date           => trunc(sysdate),
                p_datetrack_update_mode    => lc_dt_ud_mode,-- 'CORRECTION'
                p_person_id                => l_person_id,
                p_object_version_number    => l_ovn,        -- in out
                p_original_date_of_hire    => l_orig_date,  -- p_interface_rec.hire_date,
                p_first_name               => p_interface_rec.first_name,
                p_last_name                => p_interface_rec.last_name,
                p_sex                      => p_interface_rec.gender,
                p_date_of_birth            => nvl(p_interface_rec.birthdate,l_date_of_birth),
                p_email_address            => nvl(p_interface_rec.email,l_email_address),
                p_person_type_id           => p_interface_rec.person_type_id,
                p_employee_number          => p_interface_rec.employee_number,
                p_national_identifier      => p_interface_rec.national_identifier,
                p_attribute3               => nvl(p_interface_rec.home_email_address,l_attribute3),
                -- out
                p_effective_start_date     => l_effective_start_date,             -- out param
                p_effective_end_date       => l_effective_end_date,               -- out param
                p_full_name                => l_full_name,                        -- out param
                p_comment_id               => l_comment_id,                       -- out param
                p_name_combination_warning => l_name_combination_warning,         -- out param
                p_assign_payroll_warning   => l_assign_payroll_warning,           -- out param
                p_orig_hire_warning        => l_orig_hire_warning                 -- out param
              );
    end if;

    p_interface_rec.person_id := l_person_id;
    p_interface_rec.action    := 'UPDATE';

    errbuf   := 'Success Update person';
    retcode  := 0;
  exception
    when my_exception then
      null;
    when others then
      errbuf   := 'Error Update Person - '||substr(sqlerrm,1,240);
      retcode  := 1;
  end update_person;

  --------------------------------------------------------------------
  --  name:            create_person
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   07/07/2014
  --------------------------------------------------------------------
  --  purpose :        Create new person by using oracle API
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  07/07/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure create_person (errbuf          out    varchar2,
                           retcode         out    varchar2,
                           p_interface_rec in out t_interface_rec/*,
                           p_first_upload  in varchar2*/) is



    lc_employee_number           per_all_people_f.employee_number%type;
    ln_person_id                 per_all_people_f.person_id%type;
    ln_assignment_id             per_all_assignments_f.assignment_id%type;
    ln_object_ver_number         per_all_assignments_f.object_version_number%type;
    ln_asg_ovn                   number;

    ld_per_effective_start_date  per_all_people_f.effective_start_date%type;
    ld_per_effective_end_date    per_all_people_f.effective_end_date%type;
    lc_full_name                 per_all_people_f.full_name%type;
    ln_per_comment_id            per_all_people_f.comment_id%type;
    ln_assignment_sequence       per_all_assignments_f.assignment_sequence%type;
    lc_assignment_number         per_all_assignments_f.assignment_number%type;

    lb_name_combination_warning  boolean;
    lb_assign_payroll_warning    boolean;
    lb_orig_hire_warning         boolean;

  begin
    errbuf   := null;
    retcode  := 0;

    lc_employee_number  := nvl(p_interface_rec.employee_number,xxhr_person_pkg.get_next_employee_number (null));
 
    hr_employee_api.create_employee
       ( -- Input data elements
         p_hire_date                      => nvl(p_interface_rec.hire_date, sysdate),
         p_original_date_of_hire          => nvl(p_interface_rec.hire_date, sysdate),
         p_business_group_id              => 0, 
         p_last_name                      => p_interface_rec.last_name,
         p_first_name                     => p_interface_rec.first_name,
         p_sex                            => upper(p_interface_rec.gender),      -- Dalit A. Raviv 23/12/2014
         p_national_identifier            => p_interface_rec.national_identifier,
         p_date_of_birth                  => p_interface_rec.birthdate, 
         p_email_address                  => p_interface_rec.email,
         p_person_type_id                 => p_interface_rec.person_type_id,
         p_attribute3                     => p_interface_rec.home_email_address, -- (attribute3)
         -- Output data elements
         p_employee_number                => lc_employee_number,                 -- i/o
         p_person_id                      => ln_person_id,
         p_assignment_id                  => ln_assignment_id,
         p_per_object_version_number      => ln_object_ver_number,
         p_asg_object_version_number      => ln_asg_ovn,
         p_per_effective_start_date       => ld_per_effective_start_date,
         p_per_effective_end_date         => ld_per_effective_end_date,
         p_full_name                      => lc_full_name,
         p_per_comment_id                 => ln_per_comment_id,
         p_assignment_sequence            => ln_assignment_sequence,
         p_assignment_number              => lc_assignment_number,
         p_name_combination_warning       => lb_name_combination_warning,
         p_assign_payroll_warning         => lb_assign_payroll_warning,
         p_orig_hire_warning              => lb_orig_hire_warning
       );

    p_interface_rec.employee_number := lc_employee_number;
    p_interface_rec.assignment_id   := ln_assignment_id;
    p_interface_rec.person_id       := ln_person_id;
    p_interface_rec.action          := 'INSERT'; 

    errbuf   := 'Success create person';
    retcode  := 0;

  exception
    when others then
      errbuf   := 'Error create person - '||substr(sqlerrm,1,240);
      retcode  := 1;
  end create_person;

  --------------------------------------------------------------------
  --  name:            get_primary_assignment_id
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   14/07/2014
  --------------------------------------------------------------------
  --  purpose :        find primary assignment id by emp number
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  14/07/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  function get_primary_assignment_id (p_emp_num         varchar2,
                                      p_effective_date  date,
                                      p_bg_id           number) return number is

    l_assignment_id  number(10):= null;

  begin
    select a.assignment_id
    into  l_assignment_id
    from  per_all_people_f        p,
          per_all_assignments_f   a
    where p.employee_number       = p_emp_num
    and   p.business_group_id + 0 = p_bg_id
    and   p_effective_date        between p.effective_start_date and p.effective_end_date
    and   a.person_id             = p.person_id
    and   a.primary_flag          = 'Y'
    and   p_effective_date        between a.effective_start_date and a.effective_end_date;

    return l_assignment_id;
  exception
    when others then
       return null;
  end get_primary_assignment_id;

  --------------------------------------------------------------------
  --  name:            update_assignment_budget
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   14/07/2014
  --------------------------------------------------------------------
  --  purpose :        Update assignment budget info using API
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  14/07/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure update_assignment_budget (errbuf          out    varchar2,
                                      retcode         out    varchar2,
                                      p_interface_rec in out t_interface_rec,
                                      p_assignment_id in     number,
                                      p_unit          in     varchar2,
                                      p_bg_id         in     number) is -- business_group_id
    l_action              varchar2(20);
    l_value               number;
    l_budget_ovn          number;
    l_ass_budget_value_id number;
    l_new_value           number;
    lc_dt_ud_mode         varchar2(100);

    my_exception          exception;
  begin
    begin
      select b.value, b.assignment_budget_value_id, b.object_version_number
      into   l_value, l_ass_budget_value_id,        l_budget_ovn
      from   per_assignment_budget_values_f b
      where  b.assignment_id = p_assignment_id
      and    b.unit          = p_unit
      AND    nvl(p_interface_rec.change_date,trunc(sysdate)) between b.effective_start_date and b.effective_end_date;

      -- Set DateTrack Mode (Oracle code)
      lc_dt_ud_mode := get_datetrack_mode(p_table_name => 'PER_ASSIGNMENT_BUDGET_VALUES_F', -- i v
                                          p_key_column => 'ASSIGNMENT_BUDGET_VALUE_ID',     -- i v
                                          p_key_value  => l_ass_budget_value_id,            -- i n
                                          p_date       => trunc(sysdate));                  -- i d

      if p_unit = 'FTE' then
        if   nvl(l_value,-99) <> nvl(p_interface_rec.fte_value,-99)then
          l_action :='UPDATE';
        end if;
        l_new_value := p_interface_rec.fte_value;
      else
        if   nvl(l_value,-99) <> nvl(p_interface_rec.HC_value,-99)then
          l_action :='UPDATE';
        end if;
        l_new_value := p_interface_rec.HC_value;
      end if;
    exception
      when no_data_found then
        l_action :='INSERT';
        if p_unit = 'FTE' then
          l_new_value := p_interface_rec.fte_value;
        else
          l_new_value := p_interface_rec.HC_value;
        end if;
      when others then
        errbuf  := 'Problem with assignment budget - '||substr(sqlerrm,1,240);
        retcode := 1;
        raise my_exception;
    end;

    if l_action ='INSERT' then
      hr_asg_budget_value_api.create_asg_budget_value
                            ( p_effective_date             => nvl(p_interface_rec.change_date,trunc(sysdate)),
                              p_business_group_id          => p_bg_id,
                              p_assignment_id              => p_assignment_id,
                              p_unit                       => p_unit,
                              p_value                      => l_new_value,
                              p_object_version_number      => l_budget_ovn,         -- out param
                              p_assignment_budget_value_id => l_ass_budget_value_id -- out param
                              );
   elsif   l_action ='UPDATE' then
     hr_asg_budget_value_api.update_asg_budget_value
                            ( p_assignment_budget_value_id => l_ass_budget_value_id,
                              p_effective_date             => nvl(p_interface_rec.change_date,trunc(sysdate)),
                              p_datetrack_mode             => lc_dt_ud_mode,
                              p_value                      => l_new_value,
                              p_object_version_number      => l_budget_ovn);
   end if;

  exception
    when my_exception then
      null;
    when others then
      --dbms_output.put_line('Gen Problem with assignment budget - '||substr(sqlerrm,1,240)); 
      errbuf  := 'Gen Problem with assignment budget - '||substr(sqlerrm,1,240);
      retcode := 1;
  end update_assignment_budget;

  --------------------------------------------------------------------
  --  name:            update_assignment
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   14/07/2014
  --------------------------------------------------------------------
  --  purpose :        update person assignment details by using oracle API
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  14/07/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure update_assignment(errbuf          out    varchar2,
                              retcode         out    varchar2,
                              p_interface_rec in out t_interface_rec,
                              p_mode          in     varchar2,
                              p_assignment_id out    number) is

    ln_assignment_id                number       := null;
    ln_assg_ovn                     number       := null;
    lc_datetrack_mode               varchar2(20) := null;
    ld_assg_effective_start_date    date;
    ld_assg_effective_end_date      date;
    ln_special_ceiling_step_id      number(15)   := null;
    ln_people_group_id              number(15)   := null;
    lc_group_name                   varchar2(100):= null;
    lb_org_now_no_manager_warning   boolean;
    lb_other_manager_warning        boolean;
    lb_spp_delete_warning           boolean;
    lc_entries_changed_warning      varchar2(30);
    lb_tax_district_changed_warn    boolean;
    lc_concatenated_segments        varchar2(240);
    ln_soft_coding_key              number;

    ln_comment_id                   number;
    ld_effective_start_date         date;
    ld_effective_end_date           date;
    lb_no_managers_warning          boolean;
    l_assignment_rec                per_all_assignments_f%rowtype;
    l_date                          date;
    l_supervisor_exists             varchar2(10);
    --l_return_message                varchar2(32000);
    --l_msg_data                      varchar2(2500);
    --l_msg_index                     number;               

    my_exception     exception;
  begin
    errbuf  := null;
    retcode := 0;
    if p_mode = 'UPD' then
      l_date := trunc(sysdate);
      ln_assignment_id := get_primary_assignment_id(p_emp_num         => p_interface_rec.employee_number, -- i v
                                                    p_effective_date  => l_date,                          -- i d
                                                    p_bg_id           => g_business_group_id);            -- i n
    else
      l_date := nvl(p_interface_rec.hire_date, trunc(sysdate));
      ln_assignment_id := p_interface_rec.assignment_id;
    end if;

    p_assignment_id := ln_assignment_id;

    if ln_assignment_id is null then
      errbuf  := 'No primary assignment found for effective date';
      retcode := 1;
      --dbms_output.put_line('Emp Num '||p_interface_rec.employee_number||' '||errbuf);
      raise my_exception;
    end if;
    -- Get object_version_number
    select max(object_version_number) -- max
    into   ln_assg_ovn
    from   per_all_assignments_f
    where  assignment_id = ln_assignment_id
    and    l_date between effective_start_date and effective_end_date;

    -- Set DateTrack Mode (Oracle code)
    lc_datetrack_mode := get_datetrack_mode(p_table_name => 'PER_ALL_ASSIGNMENTS_F', -- i v
                                            p_key_column => 'ASSIGNMENT_ID',         -- i v
                                            p_key_value  => ln_assignment_id,        -- i n
                                            p_date       => l_date );                -- i d
    
    select *
    into   l_assignment_rec
    from   per_all_assignments_f a
    where  a.assignment_id = ln_assignment_id
    and    l_date between effective_start_date and effective_end_date;

    if l_assignment_rec.people_group_id is null then
      if p_interface_rec.person_type in('Employee', 'Pupil','Temporary Employee') then
        ln_people_group_id := 81;
      else
        ln_people_group_id := 141;
      end if;
    else
      ln_people_group_id := l_assignment_rec.people_group_id;
    end if;

    if p_interface_rec.supervisor_id is not null then
      begin
        select 'Y'
        into   l_supervisor_exists
        from   per_all_people_f p
        where  p.person_id      = p_interface_rec.supervisor_id
        and    l_date           between p.effective_start_date and p.effective_end_date;
      
      exception
        when others then
          errbuf  := 'Failed update_emp_asg - Supervisor number '|| p_interface_rec.supervisor||' do not exists at date '||to_char(l_date,'DD-MON-YYYY');
          retcode := 1;
          raise my_exception;
      end;
    end if;

    if ((nvl(l_assignment_rec.set_of_books_id,-1)      <> nvl(p_interface_rec.set_of_books_id,nvl(l_assignment_rec.set_of_books_id,-1)))    or
        (nvl(l_assignment_rec.supervisor_id,-1)        <> nvl(p_interface_rec.supervisor_id, nvl(l_assignment_rec.supervisor_id,-1))) or
        (nvl(l_assignment_rec.default_code_comb_id,-1) <> nvl(p_interface_rec.code_combination_id,nvl(l_assignment_rec.default_code_comb_id,-1))) 
       ) then
      
      begin

        hr_assignment_api.update_emp_asg(p_effective_date         => l_date/*nvl(p_interface_rec.change_date,sysdate)*/,
                                         p_datetrack_update_mode  => lc_datetrack_mode, -- 'CORRECTION',
                                         p_assignment_id          => ln_assignment_id,
                                         p_object_version_number  => ln_assg_ovn,
                                         p_supervisor_id          => p_interface_rec.supervisor_id,
                                         p_change_reason          => null,
                                         p_set_of_books_id        => nvl(p_interface_rec.set_of_books_id,l_assignment_rec.set_of_books_id/*fnd_api.G_MISS_NUM*/),
                                         p_default_code_comb_id   => nvl(p_interface_rec.code_combination_id,l_assignment_rec.default_code_comb_id/*fnd_api.G_MISS_NUM*/),
                                         -- out
                                         p_concatenated_segments  => lc_concatenated_segments,  -- o v
                                         p_soft_coding_keyflex_id => ln_soft_coding_key,        -- o n
                                         p_comment_id             => ln_comment_id,             -- o n
                                         p_effective_start_date   => ld_effective_start_date,   -- o d
                                         p_effective_end_date     => ld_effective_end_date,     -- o d
                                         p_no_managers_warning    => lb_no_managers_warning,    -- o boolean
                                         p_other_manager_warning  => lb_other_manager_warning); -- o boolean

      exception
        when others then  
          errbuf  := 'Failed update_emp_asg - '||substr(sqlerrm,1,240);
          retcode := 1;
          raise my_exception;
      end;
    end if; -- check if need to update

    -- Set DateTrack Mode (Oracle code)
    lc_datetrack_mode := get_datetrack_mode(p_table_name => 'PER_ALL_ASSIGNMENTS_F', -- i v
                                            p_key_column => 'ASSIGNMENT_ID',         -- i v
                                            p_key_value  => ln_assignment_id,        -- i n
                                            p_date       => l_date );                -- i d

    if (((l_assignment_rec.job_id <> p_interface_rec.job_id ) and p_interface_rec.job_id is not null ) or
        ((l_assignment_rec.organization_id <> p_interface_rec.organization_id) and p_interface_rec.organization_id is not null) or
        ((l_assignment_rec.location_id <> p_interface_rec.location_id) and p_interface_rec.location_id is not null) or
        ((l_assignment_rec.grade_id    <> p_interface_rec.grade_id) and p_interface_rec.grade_id is not null ) or
        ((l_assignment_rec.position_id <> p_interface_rec.position_id) and p_interface_rec.position_id is not null)
       ) then

      begin
        hr_assignment_api.update_emp_asg_criteria(
                            p_effective_date               => l_date/*nvl(p_interface_rec.change_date,sysdate)*/,
                            p_datetrack_update_mode        => lc_datetrack_mode,
                            p_assignment_id                => ln_assignment_id,
                            p_object_version_number        => ln_assg_ovn,
                            p_job_id                       => nvl(p_interface_rec.job_id,l_assignment_rec.job_id),--fnd_api.G_MISS_NUM
                            p_organization_id              => nvl(p_interface_rec.organization_id,l_assignment_rec.organization_id),
                            p_location_id                  => nvl(p_interface_rec.location_id,l_assignment_rec.location_id),
                            p_grade_id                     => nvl(p_interface_rec.grade_id,l_assignment_rec.grade_id),
                            p_position_id                  => nvl(p_interface_rec.position_id,l_assignment_rec.position_id),
                            -- Out Params
                            p_people_group_id              => ln_people_group_id,             -- i/o
                            p_special_ceiling_step_id      => ln_special_ceiling_step_id,     -- i/o
                            p_group_name                   => lc_group_name,                  -- o v
                            p_effective_start_date         => ld_assg_effective_start_date,   -- o d
                            p_effective_end_date           => ld_assg_effective_end_date,     -- o d
                            p_org_now_no_manager_warning   => lb_org_now_no_manager_warning ,
                            p_other_manager_warning        => lb_other_manager_warning,
                            p_spp_delete_warning           => lb_spp_delete_warning,
                            p_entries_changed_warning      => lc_entries_changed_warning,
                            p_tax_district_changed_warning => lb_tax_district_changed_warn );
      exception
        when others then
          errbuf  := 'Failed update_emp_asg_criteria - '||substr(sqlerrm,1,240);
          retcode := 1;
          raise my_exception;
      end;
      commit;
    end if;
    
  exception
    when my_exception then
      null;
    when others then
      errbuf   := 'Error update_assignment '||p_mode||', '||substr(sqlerrm,1,240);
      retcode  := 1;
  end update_assignment;
  
  --------------------------------------------------------------------
  --  name:            get_datetrack_mode
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   14/07/2014
  --------------------------------------------------------------------
  --  purpose :        call oracle API that calculate the datetrake mode
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  14/07/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  function get_datetrack_mode (p_table_name in varchar2,
                               p_key_column in varchar2,
                               p_key_value  in number,
                               p_date       in date) return varchar2 is
    
    -- Out Variables for Find Date Track Mode API  
    -- ----------------------------------------------------------------  
    lb_correction              boolean;  
    lb_update                  boolean;  
    lb_update_override         boolean;   
    lb_update_change_insert    boolean;
    lc_dt_ud_mode              varchar2(100) := null;
  begin
    -- Find Date Track Mode 
    -- --------------------------------  
    dt_api.find_dt_upd_modes 
     (    -- Input Data Elements 
          p_effective_date         => p_date, 
          p_base_table_name        => p_table_name, -- 'PER_ALL_ASSIGNMENTS_F','PER_ALL_ASSIGNMENTS_F', 
          p_base_key_column        => p_key_column, -- 'PERSON_ID','ASSIGNMENT_ID', 
          p_base_key_value         => p_key_value,  -- ln_assignment_id , ln_person_id
          -- Output data elements 
          p_correction             => lb_correction, 
          p_update                 => lb_update, 
          p_update_override        => lb_update_override, 
          p_update_change_insert   => lb_update_change_insert 
     ); 
  
    if ( lb_update_override = true or lb_update_change_insert = true ) then 
      lc_dt_ud_mode := 'UPDATE_OVERRIDE'; 
    end if;

    if ( lb_correction = true ) then 
     lc_dt_ud_mode := 'CORRECTION'; 
    end if;

    if ( lb_update = true ) then 
      lc_dt_ud_mode := 'UPDATE'; 
    end if;
     
    return lc_dt_ud_mode;
  
  end get_datetrack_mode;
  
  --------------------------------------------------------------------
  --  name:            main
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   26/06/2014
  --------------------------------------------------------------------
  --  purpose :        --  purpose :        Process the data from excel file
  --                   this procedure will call from retry too
  --  in params:
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  26/06/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure process_data ( errbuf          out varchar2,
                           retcode         out varchar2,
                           p_interface_rec in  out t_interface_rec) is

    l_errbuf         varchar2(1000);
    l_retcode        varchar2(100);
    l_log_code       varchar2(100);
    l_log_message    varchar2(500);
    l_assignment_id  number;
    l_exist_emp_num  varchar2(10);
    
    my_exc    exception;
  begin
    errbuf        := null;
    retcode       := 0;
    l_log_message := null;
    l_log_code    := 'S';

    begin
      update XXHR_INTERFACES   i
      set    i.status          = 'IN_PROCESS'
      where  /*i.status          = 'NEW'     
      and    */i.interface_id    = p_interface_rec.interface_id;
      commit;
    exception
      when others then
        errbuf   := 'Can not update status NEW to IN_PROCESS';
        retcode  := 1;
        raise my_exc;
    end;

    l_errbuf  := null;
    l_retcode := null;
    gen_validation (errbuf          => l_errbuf,  -- out  varchar2,
                    retcode         => l_retcode, -- out  varchar2,
                    p_interface_rec => p_interface_rec);

    if nvl(l_retcode,0) <> 0 then
      errbuf   := 'gen_validation - '||l_errbuf;
      retcode  := 1;
      raise my_exc;
    else
      -- procedd to update/create person
      l_log_code      := null;
      l_log_message   := null;

      l_exist_emp_num := check_emp_number (p_interface_rec.employee_number);
      if l_exist_emp_num = 'Y' then
        -------------------------------------------------------
        -- UPDATE PERSON --------------------------------------
        update_person (errbuf          => l_errbuf,         -- o v
                       retcode         => l_retcode,        -- o v
                       p_interface_rec => p_interface_rec); -- i t_interface_rec

        if nvl(l_retcode,0) <> 0 then
          l_log_code    := 'E';
          p_interface_rec.action := 'UPD_PERSON';
          if l_log_message is not null then
            l_log_message := l_log_message||', '||l_errbuf;
          else
            l_log_message := l_errbuf;
          end if;
          upd_interface (errbuf          => l_errbuf,          -- o v
                         retcode         => l_retcode,         -- o v
                         p_interface_rec => p_interface_rec,
                         p_log_code      => null,
                         p_log_message   => null,
                         p_entity        => 'UPD_PERSON');
          rollback;
        else
          commit;
          -- the system automaticly create assignment for the person with default organization - Setup Business Group
          -- therefor when i call assignment api it will be in correction mode
          update_assignment(errbuf          => l_errbuf,        -- o v
                            retcode         => l_retcode,       -- o v
                            p_interface_rec => p_interface_rec,
                            p_mode          => 'UPD',           -- i v
                            p_assignment_id => l_assignment_id);-- o n
          if nvl(l_retcode,0) = 0 then
            l_log_code    := 'S';
            l_log_message := null;
            commit; -- only if success at the end commit;
            upd_interface (errbuf          => l_errbuf,          -- o v
                           retcode         => l_retcode,         -- o v
                           p_interface_rec => p_interface_rec,
                           p_log_code      => null,
                           p_log_message   => null,
                           p_entity        => 'UPDATE');
          else
            -- problem
            l_log_code := 'E';
            p_interface_rec.action := 'UPD_ASS';
            if l_log_message is not null then
              l_log_message := l_log_message||', '||l_errbuf;
            else
              l_log_message := l_errbuf;
            end if;
            upd_interface (errbuf          => l_errbuf,          -- o v
                           retcode         => l_retcode,         -- o v
                           p_interface_rec => p_interface_rec,
                           p_log_code      => null,
                           p_log_message   => null,
                           p_entity        => 'UPD_ASS');
            rollback;
          end if;-- update assignment
        end if; -- update person

        -- handle return error logs
        if l_log_code = 'E' then
          retcode  := 1;
          errbuf   := l_log_message;
        end if;
      -------------------------------------------------------
      -- CREATE PERSON --------------------------------------
      elsif l_exist_emp_num = 'N' then
        create_person (errbuf          => l_errbuf,          -- o v
                       retcode         => l_retcode,         -- o v
                       p_interface_rec => p_interface_rec    -- i/o t_interface_rec
                       /*p_first_upload  => p_first_upload*/
                      );   -- i v

        if nvl(l_retcode,0) <> 0 then
          if l_log_message is not null then
             l_log_message := l_log_message||', '||l_errbuf;
          else
             l_log_message := l_errbuf;
          end if;
          l_log_code := 'E';
          p_interface_rec.action := 'INS_PERSON';
        else
          -- update assignment if success 
          -- the system automaticly create assignment for the person with default organization - Setup Business Group
          -- therefor when i call assignment api it will be update assignment API
          update_assignment(errbuf          => l_errbuf,        -- o v
                            retcode         => l_retcode,       -- o v
                            p_interface_rec => p_interface_rec,
                            p_mode          => 'INS',           -- i v
                            p_assignment_id => l_assignment_id);

          if nvl(l_retcode,0) = 0 then
            l_log_code    := 'S';
            l_log_message := null;
            commit; -- only if success at the end commit;

            upd_interface (errbuf          => l_errbuf,          -- o v
                           retcode         => l_retcode,         -- o v
                           p_interface_rec => p_interface_rec,
                           p_log_code      => null,
                           p_log_message   => null,
                           p_entity        => 'INSERT');

          else
            -- problem
            l_log_code := 'E';
            p_interface_rec.action := 'UPD_ASS';
            if l_log_message is not null then
              l_log_message := l_log_message||', '||l_errbuf;
            else
              l_log_message := l_errbuf;
            end if;
            
            upd_interface (errbuf          => l_errbuf,          -- o v
                           retcode         => l_retcode,         -- o v
                           p_interface_rec => p_interface_rec,
                           p_log_code      => null,
                           p_log_message   => null,
                           p_entity        => 'UPD_ASS');
            rollback;
          end if;-- upd ass       
        end if;-- create person
        -- handle return error logs
        if l_log_code = 'E' then
          retcode  := 1;
          errbuf   := l_log_message;
        end if;
      end if;-- create / update person
    end if; -- Gen Validation

  exception
    when my_exc then
      null;
    when others then
      errbuf   := 'Procedure process_data err - '||substr(sqlerrm,1,240);
      retcode  := 1;
  end process_data;

  --------------------------------------------------------------------
  --  name:            main_retry
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   30/07/2014
  --------------------------------------------------------------------
  --  purpose :        Handle - main retry program to create/update person in oracle
  --  in params:       p_table_name    - the table to refer the upload to - XXHR_INTERFACES
  --                   p_template_name - the same table can have several templates - GEN
  --                   p_file_name     - the file name to upload
  --                   p_directory     - the path where customer put the file - /UtlFiles/shared/DEV
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  30/07//2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure main_retry ( errbuf     out varchar2,
                         retcode    out varchar2
                       ) is
    cursor pop_c is
      select * from XXHR_INTERFACES i
      where  i.status = 'NEW'
      and    i.last_updated_by = fnd_global.USER_ID;

    l_errbuf         varchar2(2000);
    l_retcode        varchar2(100);
    l_interface_rec  t_interface_rec;
    l_log_code       varchar2(100);
    l_log_message    varchar2(500);

    my_exception exception;
  begin
    errbuf   := null;
    retcode  := 0;

    -- by loop process each person record
    for pop_r in pop_c loop
      l_interface_rec := pop_r;
      process_data ( errbuf          => l_errbuf,        -- o v
                     retcode         => l_retcode,       -- o v
                     p_interface_rec => l_interface_rec  -- i/o t_interface_rec
                    );

      l_log_code    := case when l_retcode = 0 then
                              'S'
                            else
                              'E'
                       end;
      l_log_message := l_errbuf;
      if l_retcode <> 0 then
        errbuf   := l_log_message;
        retcode  := 1;
      end if;

      l_errbuf      := null;
      l_retcode     := 0;
      -- handle process logs (error/success)
      -- add update of ERROR
      upd_interface (errbuf          => l_errbuf,        -- o v
                     retcode         => l_retcode,       -- o v
                     p_interface_rec => l_interface_rec, -- i t_interface_rec,
                     p_log_code      => l_log_code,      -- i v
                     p_log_message   => l_log_message,   -- i v
                     p_entity        => 'MAIN');         -- i v
    end loop;

  exception
    when my_exception then
      null;
    when others then
      errbuf   := 'GEN EXC - main retry - '||substr(sqlerrm,1,240);
      retcode  := 1;
  end main_retry;

  --------------------------------------------------------------------
  --  name:            handle_second_upload
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   30/07/2014
  --------------------------------------------------------------------
  --  purpose :        Handle - handle_second_upload
  --                   if customer export the data from the form to excel
  --                   change the excel data and upload again. the error records in the DB
  --                   need to be closed, because the program will enter new records.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  30/07/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure handle_second_upload(errbuf          out varchar2,           -- o v
                                 retcode         out varchar2,           -- o v
                                 p_interface_rec in  t_interface_rec) is -- i/o t_interface_rec

  begin
    errbuf  := null;
    retcode := 0;

    update XXHR_INTERFACES i
    set    i.status             = 'CLOSED',
           i.last_update_date   = sysdate
    where  i.interface_id       = p_interface_rec.reference_int_id;

    --commit;
  exception
    when others then
      errbuf   := 'GEN EXC - handle_second_upload - '||substr(sqlerrm,1,240);
      retcode  := 1;
  end handle_second_upload;

  --------------------------------------------------------------------
  --  name:            main
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   26/06/2014
  --------------------------------------------------------------------
  --  purpose :        Handle - main program to create/update person in oracle
  --  in params:       p_table_name    - the table to refer the upload to - XXHR_INTERFACES
  --                   p_template_name - the same table can have several templates - GEN
  --                   p_file_name     - the file name to upload
  --                   p_directory     - the path where customer put the file - /UtlFiles/shared/DEV
  --                   p_retry         - if the program do retry no need toupload the eacel again
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  26/06/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure main ( errbuf           out varchar2,
                   retcode          out varchar2,
                   p_table_name     in  varchar2, -- XXHR_INTERFACES
                   p_template_name  in  varchar2, -- GEN
                   p_file_name      in  varchar2, -- test_hr_interface.csv  test_hr_interface.csv
                   p_directory      in  varchar2, -- will hold the path to the file as /UtlFiles/shared/DEV
                   p_retry          in  varchar2
                  ) is

    cursor pop_c is
      select * from XXHR_INTERFACES i
      where  i.status = 'NEW';

    l_errbuf         varchar2(2000);
    l_retcode        varchar2(100);
    l_interface_rec  t_interface_rec;
    l_log_code       varchar2(100);
    l_log_message    varchar2(500);
    l_count_e        number;
    l_count_s        number;
    l_total          number;

    l_to_user_name   varchar2(240);
    l_cc             varchar2(150);
    l_bcc            varchar2(150);
    l_subject        varchar2(500);
    l_att1_proc      varchar2(150)  := null;
    l_att2_proc      varchar2(150)  := null;
    l_att3_proc      varchar2(150)  := null;
    l_error_code     number         := 0;
    l_err_message    varchar2(500)  := null;

    my_exception exception;

  begin
    errbuf   := null;
    retcode  := 0;

    delete_interface(errbuf        => l_errbuf,        -- o v
                     retcode       => l_retcode);      -- o v

    if p_retry = 'N' then
      upload_file(errbuf           => l_errbuf,        -- o v
                  retcode          => l_retcode,       -- o v
                  p_table_name     => p_table_name,    -- i v
                  p_template_name  => p_template_name, -- i v (DEFAULT, GEN etc)
                  p_file_name      => p_file_name,     -- i v
                  p_directory      => p_directory);    -- i v

      if l_retcode <> 0 then
        errbuf   := 'Main problem upload file - '||l_errbuf;
        retcode  := 2;
        -- problem
        l_log_code := 'E';
        l_log_message := l_errbuf;
        raise my_exception;
      end if;

    end if;
    -- by loop process each person record
    l_count_e  := 0;
    l_count_s  := 0;
    l_total    := 0;
    for pop_r in pop_c loop
      l_interface_rec := pop_r;
      l_total         := l_total + 1;
      
      process_data ( errbuf          => l_errbuf,        -- o v
                     retcode         => l_retcode,       -- o v
                     p_interface_rec => l_interface_rec  -- i/o t_interface_rec
                   ); -- i v
      l_log_code    := case when l_retcode = 0 then
                              'S'
                            else
                              'E'
                       end;
      l_log_message := l_errbuf;
      if l_retcode <> 0 then
        errbuf     := 'Please look at the interface form for error messages';
        retcode    := 1;
        l_count_e  := l_count_e + 1;
      else

        l_count_s  := l_count_s + 1;
      end if;

      l_errbuf      := null;
      l_retcode     := 0;
      -- handle process logs (error/success)
      -- add update of ERROR
      upd_interface (errbuf          => l_errbuf,        -- o v
                     retcode         => l_retcode,       -- o v
                     p_interface_rec => l_interface_rec, -- i t_interface_rec,
                     p_log_code      => l_log_code,      -- i v
                     p_log_message   => l_log_message,   -- i v
                     p_entity        => 'MAIN');         -- i v

      if p_retry = 'N' then
        if l_interface_rec.reference_int_id is not null then
          handle_second_upload(errbuf          => l_errbuf,         -- o v
                               retcode         => l_retcode,        -- o v
                               p_interface_rec => l_interface_rec); -- i/o t_interface_rec
          if l_retcode = 0 then
            commit;
          end if;
        end if;
      end if;
    end loop;

    -- send mail by using XXMAIL WF
    if l_total > 0 then

      l_to_user_name := fnd_global.USER_NAME;--fnd_profile.value('XXHR_INTERFACE_SEND_MAIL_TO');
      l_cc           := fnd_profile.value('XXHR_INTERFACE_SEND_MAIL_CC');
      l_bcc          := fnd_profile.value('XXHR_INTERFACE_SEND_MAIL_BCC');
      fnd_message.SET_NAME('XXOBJT','XXHR_INTERFACES_SEND_MAIL_SUBJ');
      l_subject      := fnd_message.get; -- 'HR interface Upload Log File'

      xxobjt_wf_mail.send_mail_body_proc
                    (p_to_role     => l_to_user_name,     -- i v
                     p_cc_mail     => l_cc,               -- i v
                     p_bcc_mail    => l_bcc,              -- i v
                     p_subject     => l_subject,          -- i v
                     p_body_proc   => 'XXHR_WF_SEND_MAIL_PKG.prepare_Interface_body/'||l_count_e||'|'||l_count_s||'|'||l_total, -- i v
                     p_att1_proc   => l_att1_proc,        -- i v
                     p_att2_proc   => l_att2_proc,        -- i v
                     p_att3_proc   => l_att3_proc,        -- i v
                     p_err_code    => l_error_code,       -- o n
                     p_err_message => l_err_message);     -- o v

    end if;
       
  exception
    when my_exception then
      null;
    when others then
      errbuf   := 'GEN EXC - main - '||substr(sqlerrm,1,240);
      retcode  := 1;
  end main;


end XXHR_INTERFACES_PKG;
/
