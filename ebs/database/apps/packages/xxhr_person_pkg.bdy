create or replace package body xxhr_person_pkg is

  --------------------------------------------------------------------
  --  name:            XXHR_PERSON_PKG
  --  create by:       Dalit A. Raviv
  --  Revision:        1.6
  --  creation date:   29/11/2010 10:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        HR project - Handle Person details
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  29/11/2010  Dalit A. Raviv    initial build
  --  1.1  23/06/2011  Dalit A. Raviv    add function  get_person_town_or_city
  --  1.2  05/07/2011  Dalit A. Raviv    add function  get_person_phone
  --  1.3  04/09/2011  Dalit A. Raviv    add function  get_person_address
  --  1.4  30/12/2012  Dalit A. Raviv    procedure     update_employee_National_id
  --                                                   change location name Objet Israel% to Stratasys Israel%
  --  1.5  18/07/2013  Dalit A. Raviv    correct update employee email
  --  1.6  06/02/2014  Dalit A. Raviv    add function get_person_personal_email
  --  1.7  07/09/2020  Roman W.          CHG0048543 - R & D Location in purchase requisition - change logic  
  --------------------------------------------------------------------

  --------------------------------------------------------------------
  --  name:            get_person_id
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   29/11/2010
  --------------------------------------------------------------------
  --  purpose :        get person id by employee number
  --  in params:       p_entity_value    - will hold the value to look for - example
  --                                       full_name, emp_number (varchar value)
  --                   p_effective_date  - the effective date we want to get the data from
  --                   p_bg_id           - business_group_id
  --                   p_entity_name     - FULL_NAME / EMP_NUM et'c
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  29/11/2010  Dalit A. Raviv    initial build
  --  1.1  20/11/2011  Dalit A. Raviv    nvl to get npw_number for contractors
  --------------------------------------------------------------------
  function get_person_id(p_entity_value   varchar2,
                         p_effective_date date,
                         p_bg_id          number,
                         p_entity_name    varchar2) return number is
  
    l_person_id number(10) := null;
  
  begin
    if p_entity_name = 'EMP_NUM' then
      select person_id
        into l_person_id
        from per_all_people_f papf
       where (employee_number = p_entity_value or
             papf.npw_number = p_entity_value)
         and business_group_id + 0 = p_bg_id
         and p_effective_date between effective_start_date and
             effective_end_date;
    elsif p_entity_name = 'FULL_NAME' then
      select person_id
        into l_person_id
        from per_all_people_f papf
       where papf.full_name = p_entity_value
         and business_group_id + 0 = p_bg_id
         and p_effective_date between effective_start_date and
             effective_end_date;
    end if;
  
    return l_person_id;
  
  exception
    when OTHERS then
      return null;
  end get_person_id;

  --------------------------------------------------------------------
  --  name:            update_employee_email
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   30/11/2010
  --------------------------------------------------------------------
  --  purpose :        by person is update email address
  --                   this provedure will call from Active Directory after creating User there.
  --  in params:       p_personid
  --                   p_emailaddress - email to update
  --  out params:      p_error_code   - o success 1 failure
  --                   p_error_desc   - null success string failure
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  30/11/2010  Dalit A. Raviv    initial build
  --  1.1  18/07/2013  Dalit A. Raviv    Correct future start date update
  --------------------------------------------------------------------
  procedure update_employee_email(p_personid     in number,
                                  p_emailaddress in varchar2,
                                  p_error_code   out varchar2,
                                  p_error_desc   out varchar2) is
  
    l_ovn                  number(10);
    l_emp_num              varchar2(10);
    l_effective_start_date date;
    l_effective_end_date   date;
    l_full_name            varchar2(90);
    l_comment_id           number(10) := null;
    --l_persontypeid               number;
    --l_dateofbirth                varchar2(20);
  
    l_name_combination_warning boolean;
    l_assign_payroll_warning   boolean;
    l_orig_hire_warning        boolean;
    -- 1.1 Dalit A. Raviv 18/07/2013
    l_effective_start_date1 date;
  
  begin
  
    select max(object_version_number)
      into l_ovn
      from per_all_people_f
     where person_id = p_personid;
  
    begin
      -- 1.1 Dalit A. Raviv 18/07/2013
      select papf.employee_number, papf.effective_start_date
        into l_emp_num, l_effective_start_date1
        from per_all_people_f papf
       where papf.effective_start_date =
             (select Max(papf1.effective_start_date)
                from per_all_people_f papf1
               where papf1.person_id = papf.person_id)
         and papf.person_id = p_personid
         and papf.person_id = p_personid;
    exception
      when others then
        l_emp_num := null;
    end;
  
    hr_person_api.update_person(p_effective_date           => l_effective_start_date1, -- 1.1 Dalit A. Raviv 18/07/2013
                                p_datetrack_update_mode    => 'CORRECTION',
                                p_person_id                => p_personid,
                                p_object_version_number    => l_ovn, -- in/out
                                p_email_address            => p_emailaddress,
                                p_employee_number          => l_emp_num, -- in/out
                                p_effective_start_date     => l_effective_start_date, -- out
                                p_effective_end_date       => l_effective_end_date, -- out
                                p_full_name                => l_full_name, -- out
                                p_comment_id               => l_comment_id, -- out number
                                p_name_combination_warning => l_name_combination_warning, -- out bool
                                p_assign_payroll_warning   => l_assign_payroll_warning, -- out bool
                                p_orig_hire_warning        => l_orig_hire_warning -- out bool
                                );
  
    commit;
  exception
    when others then
      p_error_code := 1;
      p_error_desc := 'Update_employee - ' || substr(SQLERRM, 1, 500);
      --dbms_output.put_line('error is '||SQLERRM);
      dbms_output.put_line('Update_employee - ' || substr(SQLERRM, 1, 240));
      dbms_output.put_line('Update_employee - ' ||
                           substr(SQLERRM, 241, 440));
    
  end update_employee_email;

  --------------------------------------------------------------------
  --  name:            update_employee_National_id
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   08/03/2011
  --------------------------------------------------------------------
  --  purpose :        Go on all employees that the national identifier is wrong
  --                   and add leading ziro - LPAD '0' to 9 digits.
  --  in params:
  --  out params:      p_error_code   - o success 1 failure
  --                   p_error_desc   - null success string failure
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  08/03/2011  Dalit A. Raviv    initial build
  --  1.1  30/12/2012  Dalit A. Raviv    change location name Objet Israel% to Stratasys Israel%
  --------------------------------------------------------------------
  procedure update_employee_National_id(p_error_code out varchar2,
                                        p_error_desc out varchar2) is
  
    cursor get_pop_c is
      select full_name,
             nvl(employee_number, pf.npw_number) emp_num,
             pf.national_identifier,
             XXHR_PERSON_PKG.get_system_person_type(trunc(sysdate),
                                                    pf.person_id) user_type,
             XXHR_UTIL_PKG.get_location_code(pf.person_id,
                                             trunc(sysdate),
                                             0) location,
             pf.object_version_number ovn,
             pf.person_id
        from per_all_people_f pf
       where length(rtrim(ltrim(pf.national_identifier))) < 9
         and XXHR_UTIL_PKG.get_location_code(pf.person_id,
                                             trunc(sysdate),
                                             0) like 'Stratasys Israel%'
         and XXHR_PERSON_PKG.get_system_person_type(trunc(sysdate),
                                                    pf.person_id) <>
             'EX_EMP';
    /*and    pf.effective_start_date                        = (select max(effective_start_date)
     from   per_all_people_f pf1
     where  pf1.person_id    = pf.person_id
    )*/
    --and    rownum < 5;
  
    l_effective_start_date date;
    l_effective_end_date   date;
    l_full_name            varchar2(90);
    l_comment_id           number(10) := null;
  
    l_name_combination_warning boolean;
    l_assign_payroll_warning   boolean;
    l_orig_hire_warning        boolean;
    l_national_id              varchar2(25) := null;
    l_national_id_len          number := null;
  
  begin
    for get_pop_r in get_pop_c loop
      l_national_id          := null;
      l_national_id_len      := null;
      l_full_name            := null;
      l_comment_id           := null;
      l_effective_start_date := null;
      l_effective_end_date   := null;
      begin
        complete_to_nine_digit(p_national_id_number => get_pop_r.national_identifier, -- i v
                               p_national_id_len    => l_national_id_len, -- o n
                               p_new_national_id    => l_national_id); -- o v
      
        hr_person_api.update_person(p_effective_date           => SYSDATE,
                                    p_datetrack_update_mode    => 'CORRECTION',
                                    p_person_id                => get_pop_r.person_id,
                                    p_object_version_number    => get_pop_r.ovn, -- in/out
                                    p_national_identifier      => l_national_id, -- in
                                    p_employee_number          => get_pop_r.emp_num, -- in/out
                                    p_effective_start_date     => l_effective_start_date, -- out
                                    p_effective_end_date       => l_effective_end_date, -- out
                                    p_full_name                => l_full_name, -- out
                                    p_comment_id               => l_comment_id, -- out number
                                    p_name_combination_warning => l_name_combination_warning, -- out bool
                                    p_assign_payroll_warning   => l_assign_payroll_warning, -- out bool
                                    p_orig_hire_warning        => l_orig_hire_warning -- out bool
                                    );
      
        commit;
        dbms_output.put_line('S - ' || get_pop_r.full_name || ' - ' ||
                             get_pop_r.emp_num || ' - ' ||
                             get_pop_r.national_identifier);
      exception
        when others then
          p_error_code := 1;
          p_error_desc := 'ERR Update emp National_id - ' ||
                          get_pop_r.full_name || ' - ' || get_pop_r.emp_num ||
                          ' - ' || get_pop_r.national_identifier || ' - ' ||
                          substr(SQLERRM, 1, 200);
          --dbms_output.put_line('error is '||SQLERRM);
          dbms_output.put_line('ERR Update emp National_id - ' ||
                               get_pop_r.full_name || ' - ' ||
                               get_pop_r.emp_num || ' - ' ||
                               get_pop_r.national_identifier || ' - ' ||
                               substr(SQLERRM, 1, 200));
          rollback;
      end;
    end loop;
  
    if p_error_code = 1 then
      p_error_desc := 'Error Correct National identifier for some employees';
    end if;
  exception
    when others then
      p_error_code := 1;
      p_error_desc := 'ERR Update emp National_id - ' ||
                      substr(SQLERRM, 1, 240);
      --dbms_output.put_line('error is '||SQLERRM);
      dbms_output.put_line('ERR Update emp National_id - ' ||
                           substr(SQLERRM, 1, 240));
      dbms_output.put_line('ERR Update emp National_id - ' ||
                           substr(SQLERRM, 241, 440));
    
  end update_employee_National_id;

  --------------------------------------------------------------------
  --  name:            get_emp_num
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   29/12/2010
  --------------------------------------------------------------------
  --  purpose :        get employee number by person_id
  --  in params:       p_person_id
  --                   p_effective_date  - the effective date we want to get the data from
  --                   p_bg_id           - business_group_id
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  29/12/2010  Dalit A. Raviv    initial build
  --  1.1  20/11/2011  Dalit A. Raviv    nvl to get npw_number for contractors
  --------------------------------------------------------------------
  function get_emp_num(p_person_id      in number,
                       p_effective_date in date default trunc(sysdate),
                       p_bg_id          in number default 0) return varchar2 is
  
    l_emp_number varchar2(30) := null;
  
  begin
    select nvl(papf.employee_number, papf.npw_number) emp_num
      into l_emp_number
      from per_all_people_f papf
     where p_effective_date between papf.effective_start_date and
           papf.effective_end_date
       and papf.person_id = p_person_id
       and papf.business_group_id = p_bg_id;
  
    return l_emp_number;
  exception
    when others then
      return null;
  end;

  --------------------------------------------------------------------
  --  name:            get_next_employee_number
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   11/01/2011
  --------------------------------------------------------------------
  --  purpose :        get next employee number
  --                   in person screen we want to put automaticly
  --                   the employee number.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  11/01/2011  Dalit A. Raviv    initial build
  --  1.1  23/01/2011  Dalit A. Raviv    Handle future dates
  --                                     Handle copy contractor number to employee number
  --------------------------------------------------------------------
  function get_next_employee_number(p_person_id in number) return varchar2 is
  
    l_next_number number;
  begin
    /*select max(to_number(papf.employee_number))
    into   l_next_number
    from   per_all_people_f papf
    where  trunc(sysdate)   between papf.effective_start_date and papf.effective_end_date
    and    papf.current_employee_flag = 'Y'
    and    hr_person_type_usage_info.GetSystemPersonType(papf.person_type_id) in ( 'EMP', 'EMP_APL','CWK','OTHER')--= 'EMP'
    and    papf.employee_number not in ('000001','000002','000003','0000016');*/
    begin
      select nvl(per.npw_number, per.employee_number)
        into l_next_number
        from per_person_types         typ,
             per_person_type_usages_f ptu,
             per_all_people_f         per
       where typ.person_type_id = ptu.person_type_id
         and per.person_id = ptu.person_id
         and per.person_id = p_person_id
         and per.effective_start_date =
             (select max(per1.effective_start_date)
                from per_all_people_f per1
               where per1.person_id = per.person_id)
         and ptu.effective_start_date =
             (select max(ptu1.effective_start_date)
                from per_person_type_usages_f ptu1
               where ptu1.person_id = ptu.person_id)
         and typ.system_person_type in ('EX_EMP', 'EMP', 'EX_CWK', 'CWK');
    exception
      when others then
        select max(nvl(to_number(per.employee_number),
                       to_number(per.npw_number))) + 1 max_all
          into l_next_number
          from per_person_types         typ,
               per_person_type_usages_f ptu,
               per_all_people_f         per
         where typ.person_type_id = ptu.person_type_id
           and per.person_id = ptu.person_id
           and per.effective_start_date =
               (select max(per1.effective_start_date)
                  from per_all_people_f per1
                 where per1.person_id = per.person_id)
           and ptu.effective_start_date =
               (select max(ptu1.effective_start_date)
                  from per_person_type_usages_f ptu1
                 where ptu1.person_id = ptu.person_id)
           and typ.system_person_type in ('EX_EMP', 'EMP', 'EX_CWK', 'CWK');
    end;
    /*select XXHR_EMPLOYEE_NUMBER_S.Nextval
    into   l_next_number
    from   dual;*/
  
    --return l_next_number + 1;
    return l_next_number;
  exception
    when others then
      return null;
  end get_next_employee_number;

  --------------------------------------------------------------------
  --  name:            get_system_person_type
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   18/01/2011
  --------------------------------------------------------------------
  --  purpose :        get system person type like EMP,CWK,APL,EX_EMP,EX_CWK,EX_APL
  --                   by date and person id get the person system type
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  18/01/2011  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  function get_system_person_type(p_effective_date in date,
                                  p_person_id      in number) return varchar2 is
  
    l_system_person_type varchar2(30) := null;
  
  begin
    select typ.system_person_type
      into l_system_person_type
      from per_person_types_tl      ttl,
           per_person_types         typ,
           per_person_type_usages_f ptu
     where ttl.language = userenv('LANG')
       and ttl.person_type_id = typ.person_type_id
       and typ.system_person_type in
           ('APL', 'EMP', 'EX_APL', 'EX_EMP', 'CWK', 'EX_CWK', 'OTHER')
       and typ.person_type_id = ptu.person_type_id
       and p_effective_date between ptu.effective_start_date and
           ptu.effective_end_date
       and ptu.person_id = p_person_id;
    --order by decode(typ.system_person_type,'EMP', 1, 'CWK', 2, 'APL', 3, 'EX_EMP', 4,
    --                                       'EX_CWK', 5, 'EX_APL', 6,7);
  
    return l_system_person_type;
  exception
    when others then
      begin
        -- look only for employees
        select typ.system_person_type
          into l_system_person_type
          from per_person_types_tl      ttl,
               per_person_types         typ,
               per_person_type_usages_f ptu
         where ttl.language = userenv('LANG')
           and ttl.person_type_id = typ.person_type_id
           and typ.system_person_type in ('EMP', 'EX_EMP')
           and typ.person_type_id = ptu.person_type_id
           and p_effective_date between ptu.effective_start_date and
               ptu.effective_end_date
           and ptu.person_id = p_person_id;
      
        return l_system_person_type;
      
      exception
        when others then
          begin
            -- look only for contractors
            select typ.system_person_type
              into l_system_person_type
              from per_person_types_tl      ttl,
                   per_person_types         typ,
                   per_person_type_usages_f ptu
             where ttl.language = userenv('LANG')
               and ttl.person_type_id = typ.person_type_id
               and typ.system_person_type in ('CWK', 'EX_CWK')
               and typ.person_type_id = ptu.person_type_id
               and p_effective_date between ptu.effective_start_date and
                   ptu.effective_end_date
               and ptu.person_id = p_person_id;
          
            return l_system_person_type;
          exception
            -- look only for applicant
            when others then
              begin
                select typ.system_person_type
                  into l_system_person_type
                  from per_person_types_tl      ttl,
                       per_person_types         typ,
                       per_person_type_usages_f ptu
                 where ttl.language = userenv('LANG')
                   and ttl.person_type_id = typ.person_type_id
                   and typ.system_person_type in ('APL', 'EX_APL')
                   and typ.person_type_id = ptu.person_type_id
                   and p_effective_date between ptu.effective_start_date and
                       ptu.effective_end_date
                   and ptu.person_id = p_person_id;
              
                return l_system_person_type;
              exception
                -- look only for others
                when others then
                  begin
                    select typ.system_person_type
                      into l_system_person_type
                      from per_person_types_tl      ttl,
                           per_person_types         typ,
                           per_person_type_usages_f ptu
                     where ttl.language = userenv('LANG')
                       and ttl.person_type_id = typ.person_type_id
                       and typ.system_person_type in ('OTHER')
                       and typ.person_type_id = ptu.person_type_id
                       and p_effective_date between
                           ptu.effective_start_date and
                           ptu.effective_end_date
                       and ptu.person_id = p_person_id;
                  
                    return l_system_person_type;
                  exception
                    when others then
                      return null;
                  end; -- others
              end; -- apl
          end; -- cwk
      end; -- emp
  end get_system_person_type;

  --------------------------------------------------------------------
  --  name:            get_indirect_mgr_detailes
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   06/03/2011
  --------------------------------------------------------------------
  --  purpose :        Procedure that do validation to employee identity number
  --  in  params:      p_id_number
  --  Out Params:      p_ret_str
  --                   p_yes_no    return FALSE / TRUE
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  06/03/2011  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure validate_emp_id_number(p_national_id_number in varchar2,
                                   p_ret_str            out varchar2,
                                   p_yes_no             out varchar2) is
  
    lv_id_number   varchar(40) := p_national_id_number;
    ln_id_len      number := length(rtrim(ltrim(lv_id_number)));
    ln_valid_digit number := 0;
    ln_comb_digit  number := 0;
    ln_tmp_sum     number := 0;
    ln_tmp1        number := 0;
    ln_tmp2        number := 0;
    ln_total       number := 0;
    ln_turn        number := 0;
    ln_i           number := 0;
  
  begin
    p_ret_str := 'ID_OK';
    p_yes_no  := 'TRUE';
  
    -- Check length of ID string
    if ln_id_len > 9 then
      p_ret_str := 'National Identifier is longet then 9 digits';
      p_yes_no  := 'FALSE';
      return;
    end if;
  
    -- Complete ID number to 9 digits with leading zeroes
    if ln_id_len < 9 then
      lv_id_number := lpad(lv_id_number, 9, '0');
      ln_id_len    := length(rtrim(ltrim(lv_id_number)));
    end if;
  
    -- Check if ID contains only digits
    if ln_id_len > 0 then
      for i in 1 .. ln_id_len loop
        if substr(lv_id_number, i, 1) not between '0' and '9' then
          p_ret_str := 'National Identifier contain Leters instead of digits';
          p_yes_no  := 'FALSE';
          return;
        end if;
      end loop;
    end if;
  
    -- Get validation digit
    ln_valid_digit := to_number(substr(lv_id_number, ln_id_len, 1));
  
    -- Check ID number according to the formula
    ln_i       := ln_id_len - 1;
    ln_turn    := 2;
    ln_total   := 0;
    ln_tmp_sum := 0;
  
    while ln_i > 0 loop
      ln_tmp_sum := to_number(substr(lv_id_number, ln_i, 1)) * ln_turn;
      if ln_tmp_sum > 9 then
        ln_tmp1  := to_number(substr(to_char(ln_tmp_sum), 1, 1));
        ln_tmp2  := to_number(substr(to_char(ln_tmp_sum), 2, 1));
        ln_total := ln_total + ln_tmp1 + ln_tmp2;
      else
        ln_total := ln_total + ln_tmp_sum;
      end if;
    
      -- change turn: from 2 to 1, and from 1 to 2
      ln_turn := 3 - ln_turn;
      ln_i    := ln_i - 1;
    
    end loop;
  
    ln_comb_digit := 10 - (ln_total MOD 10);
    if ln_comb_digit = 10 then
      ln_comb_digit := 0;
    end if;
  
    -- compare validation digit to calculated validation digit
    if ln_valid_digit != ln_comb_digit then
      p_ret_str := 'National Identifier is InCorrect';
      p_yes_no  := 'FALSE';
      return;
    end if;
  
  exception
    when others then
      p_ret_str := 'National Identifier is wrong';
      p_yes_no  := 'FALSE';
  end validate_emp_id_number;

  --------------------------------------------------------------------
  --  name:            complete_to_nine_digit
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   06/03/2011
  --------------------------------------------------------------------
  --  purpose :        Procedure that check that the employee identity number
  --                   is 9 digit, if not concatenate ziro infront of the id number
  --  in  params:      p_national_id_number
  --  Out Params:      p_national_id_len
  --                   p_new_national_id
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  06/03/2011  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure complete_to_nine_digit(p_national_id_number in varchar2,
                                   p_national_id_len    out number,
                                   p_new_national_id    out varchar2) is
  
    lv_id_number varchar(40) := p_national_id_number;
    ln_id_len    number := length(rtrim(ltrim(lv_id_number)));
  
  begin
    -- complete id number to 9 digits with leading zeroes
    if ln_id_len < 9 then
      lv_id_number      := lpad(lv_id_number, 9, '0');
      p_national_id_len := ln_id_len;
      p_new_national_id := lv_id_number;
    else
      p_national_id_len := ln_id_len;
      p_new_national_id := lv_id_number;
    end if;
  end complete_to_nine_digit;

  --------------------------------------------------------------------
  --  name:            check_national_id_exists
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   06/03/2011
  --------------------------------------------------------------------
  --  purpose :        Procedure that check if national identifier exists
  --                   allready at person table
  --  in  params:      p_national_identifier
  --  retun:           Yes Exists (Not good) No not exists (Good)
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  06/03/2011  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  function check_national_id_exists(p_national_identifier in varchar2)
    return varchar2 is
  
    l_exists varchar2(5) := null;
  
  begin
    select 'Y'
      into l_exists
      from per_all_people_f
     where national_identifier = p_national_identifier;
  
    return l_exists;
  exception
    when too_many_rows then
      return 'Y';
    when others then
      return 'N';
  end check_national_id_exists;

  --------------------------------------------------------------------
  --  name:            get_person_town_or_city
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   23/06/2011
  --------------------------------------------------------------------
  --  purpose :        Function that get person id and return the town_or_city
  --                   from person address
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  23/06/2011  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  function get_person_town_or_city(p_person_id in number) return varchar2 is
  
    l_town_or_city varchar2(30) := null;
  
  begin
    select pa.town_or_city town_or_city
      into l_town_or_city
      from per_addresses_v pa, per_all_people_f paf
     where paf.person_id = pa.person_id
       and trunc(sysdate) between paf.effective_start_date and
           paf.effective_end_date
       and pa.business_group_id + 0 = 0
       and pa.primary_flag = 'Y'
       and pa.person_id = p_person_id;
  
    return l_town_or_city;
  exception
    when others then
      return null;
  end get_person_town_or_city;

  --------------------------------------------------------------------
  --  name:            get_person_phone
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   05/07/2011
  --------------------------------------------------------------------
  --  purpose :        Function that get person phone number by phone type
  --                   M  = Mobile
  --                   O  = Others will be Person Personal Mobile
  --                   W1 = Work
  --                   H1 = Home
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  05/07/2011  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  function get_person_phone(p_person_id  in number,
                            p_phone_type in varchar2) return varchar2 is
  
    l_phone_number varchar2(60) := null;
  begin
    select pp.phone_number
      into l_phone_number
      from per_phones pp
     where parent_table = 'PER_ALL_PEOPLE_F'
       and parent_id = p_person_id -- '861'
       and sysdate between date_from and nvl(date_to, sysdate + 1)
       and pp.phone_type = p_phone_type; -- 'O'
  
    return l_phone_number;
  exception
    when too_many_rows then
      begin
        select pp.phone_number
          into l_phone_number
          from per_phones pp
         where parent_table = 'PER_ALL_PEOPLE_F'
           and parent_id = p_person_id -- '861'
           and sysdate between date_from and nvl(date_to, sysdate + 1)
           and pp.phone_type = p_phone_type -- 'O'
           and rownum = 1;
      
        return l_phone_number;
      exception
        when others then
          return null;
      end;
    when others then
      return null;
  end get_person_phone;

  --------------------------------------------------------------------
  --  name:            get_person_address
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   04/09/2011
  --------------------------------------------------------------------
  --  purpose :        Function that get person id and return person
  --                   address depand on address style.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  04/09/2011  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  function get_person_address(p_person_id in number) return varchar2 is
    l_person_address varchar2(2500) := null;
  begin
    select --papf.full_name, papf.employee_number,
     pa.address_line1 || ' ' ||
     decode(pa.address_line2, null, null, pa.address_line2 || ', ') || case
       when pa.address_line3 is null then
        null
       when pa.country = 'DE' and pa.d_style = 'Germany' then
        pa.address_line3 || ', '
       else
        pa.address_line3 || ', '
     end || decode(pa.town_or_city, null, null, pa.town_or_city || ', ') || case
       when pa.region_1 is null then
        null
       when pa.country = 'DE' and pa.d_style = 'Germany' then
        XXHR_PERSON_EXTRA_INFO_PKG.get_lookup_code_meaning('DE_FED_STATE',
                                                           pa.region_1) || ', '
       when pa.country = 'DE' and pa.d_style = 'Germany (International)' then
        XXHR_PERSON_EXTRA_INFO_PKG.get_lookup_code_meaning('DE_REGION',
                                                           pa.region_1) || ', '
       else
        pa.region_1 || ', '
     end ||
     
     decode(pa.region_2, null, null, pa.region_2 || ', ') ||
     decode(pa.postal_code, null, null, pa.postal_code || ', ') ||
     decode(pa.d_country, null, null, d_country)
      into l_person_address
      from per_addresses_v pa /*,
                                                                           per_all_people_f         papf*/
     where pa.person_id = p_person_id
       and pa.business_group_id + 0 = 0
       and pa.primary_flag = 'Y';
    /*and    pa.country  = 'US'
    and    pa.person_id = papf.person_id
    and    sysdate between papf.effective_start_date and papf.effective_end_date*/
    return l_person_address;
  exception
    when others then
      return null;
    
  end get_person_address;

  --------------------------------------------------------------------
  --  name:            get_person_personal_email
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   06/02/2014
  --------------------------------------------------------------------
  --  purpose :        Function that get person id and return person
  --                   personal email address.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  06/02/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  function get_person_personal_email(p_person_id in number) return varchar2 is
    l_email varchar2(150);
  begin
  
    select attribute3
      into l_email
      from per_all_people_f
     where person_id = p_person_id;
  
    return l_email;
  exception
    when others then
      return null;
  end get_person_personal_email;

  --------------------------------------------------------------------------
  -- Ver   When         Who          Descr
  -- ----  -----------  -----------  ---------------------------------------
  -- 1.0   07/09/2020   Roman W.     CHG0048543 - R & D Location in purchase requisition - change logic
  --------------------------------------------------------------------------
  function is_employee_il_rd(p_person_id NUMBER) return varchar is
    -------------------------
    --    Local Definition
    -------------------------    
    l_ret_value varchar2(300);
    l_count     number;
    -------------------------
    --    Code Section
    -------------------------
  begin
    select count(*)
      into l_count
      from per_all_people_f      papf,
           per_all_assignments_f paaf,
           gl_code_combinations  gcc
     where 1 = 1
       and papf.person_id = p_person_id
          --       and gcc.segment1 = 10
       and paaf.set_of_books_id = 2021
       and paaf.person_id = papf.person_id
       and trunc(sysdate) between paaf.effective_start_date and
           paaf.effective_end_date
       and trunc(sysdate) between papf.effective_start_date and
           papf.effective_end_date
       and gcc.code_combination_id = paaf.default_code_comb_id
       and gcc.segment2 in
           (select ffvv.FLEX_VALUE
              from FND_FLEX_VALUE_SETS ffvs, FND_FLEX_VALUES_VL ffvv
             where ffvs.flex_value_set_name = 'XXGL_DEPARTMENT_SEG'
               and ffvs.flex_value_set_id = ffvv.FLEX_VALUE_SET_ID
               and ffvv.ATTRIBUTE3 = 'Y'
               and ffvv.ENABLED_FLAG = 'Y'
               and trunc(sysdate) between
                   nvl(ffvv.START_DATE_ACTIVE, trunc(sysdate)) and
                   nvl(ffvv.END_DATE_ACTIVE, trunc(sysdate)));
  
    if 0 = l_count then
      l_ret_value := 'N';
    else
      l_ret_value := 'Y';
    end if;
  
    return l_ret_value;
  exception
    when others then
      return 'N';
  end is_employee_il_rd;

end XXHR_PERSON_PKG;
/
