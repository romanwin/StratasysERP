create or replace package body XXHR_API_PKG is

  /* Package : XXHR_API_PKG
   By : Dan Melamed
   ERRORS in p_out_Err and p_err_text
   Procedure Purpose :
      Support interface from SF to Oracle HR, create employment periods (CWK and EMP), update employee information and create/update fnd users.

   Version Control :
      1.0    CR 40116   Dan Melamed       22/Jan/2018  Initial version
      1.1    CHG0042593   Dan Melamed       08-Apr-2018  CHG0042593 : Logic Corrections in SF2ORA Interface :
                                                       Changes in procedures : get_code_comb_id, call_data_update, call_rehire, call_termination, process_employees
      1.2    CHG0043076   Dan Melamed       21-May-2018  Correct select to fetch person record for future re-hire
                                                         if hire date change error, discard the error and continue
                                                         if Termination date changed, exit and do nothing else.
                                                         If rehired already , skip the rehire and process as data change only.

  */



  g_current_emp_no varchar2(255);
  g_cutoff_date date := to_date('01-JAN-1920', 'DD-MON-YYYY');
  g_align_date date := to_date('01-JAN-1900', 'DD-MON-YYYY');

   -- Debug procedure - inner code to be enabled only in test environments.
/*  procedure xx_debug(p_line varchar2, p_Date date default sysdate) is
    pragma autonomous_transaction;
    seq number;
  begin

  null;

    select xx_debug_seq.nextval into seq from dual;

    insert into xx_debug_t
      (textline, ontime, seq)
    values
      (g_current_emp_no || '  ' || p_line, p_date, seq);
    commit;

  end xx_debug;*/

  /* Function/Procedure Stubs - Actual Definition below this point.  */

  function get_most_Recent_ppf_Date(p_emp_num varchar2) return date; -- stub for get_most_Recent_ppf_Date
  procedure get_code_comb_id(p_finance_company varchar2,
                             p_company         varchar2,
                             p_finance_dept    varchar2,
                             p_finance_account varchar2,
                             p_out_ccid        out number,
                             p_out_ledger_id   out number,
                             P_OUT_ccid_vc     out varchar2,
                             p_out_ledger      OUT Varchar2); -- stub for get_code_comb_id
  procedure call_termination_cng(p_employee_rec xxhr_emp_rec,
                                 p_err_code     out number,
                                 p_err_text     out varchar2); -- stub for call_Termination_chg



  /* Function : align_date
   By : Dan Melamed

   Procedure Purpose :
      Align date to be not lower than cutoff date set (01-jan-1920, hard coded)

   Version Control :
      1.0    CHG0043076   Dan Melamed       05-Jun-2018
  */



  procedure align_date(p_date in out date)
    is

    begin

      if p_date is not null then
        if p_date < g_cutoff_date then
          p_date := g_align_date;
        end if;
      end if;

    exception
       when others then
         return;
    end align_date;



      /* Function : init_user
   By : Dan Melamed

   Procedure Purpose :
      apps.initialize to BPEL_INTF user

   Version Control :
      1.0    CR 40116   Dan Melamed       22/Jan/2018
  */


  function init_user return number is

    l_user_id      number;

  begin

    select fnd.user_id
      into l_user_id
      from fnd_user fnd
     where fnd.user_name = 'BPEL_INTF';

    fnd_global.APPS_INITIALIZE(user_id      => l_user_id,
                               resp_id      =>  0,
                               resp_appl_id =>  0);

    return 0; -- success;
  exception
    when others then
      return - 1; -- error
  end init_user;

  /* Function : get_most_Recent_ppf_Date
   By : Dan Melamed

   Procedure Purpose :
      Get most recent per_all_people_f entry (where multiple can occur, one per every hire period or if changes manually in Oracle for any reason)

   Version Control :
      1.0    CR 40116   Dan Melamed       22/Jan/2018
  */

  function get_most_Recent_ppf_Date(p_emp_num varchar2) return date is
    -- as we get seperate records, the event date may be out of the hire date
    --   (and beore the employee actually hired)

    l_date date;
  begin

    begin
      select max(ppf.effective_start_date)
        into l_date
        from per_all_people_f ppf
       where 1 = 1
         and nvl(ppf.employee_number, ppf.npw_number) = p_emp_num;

      return l_date;

    exception
      when others then
        return sysdate;
    end;

  end get_most_Recent_ppf_Date;

  /* Function : map_sf_to_HR_person_Type
   By : Dan Melamed

   Function Purpose :
      map SF Person type to Oracle HR Person type (hard coded logic by Rachel Aviad)

   Version Control :
      1.0    CR 40116   Dan Melamed       22/Jan/2018
  */

  function map_sf_to_HR_person_Type(p_sf_personclass varchar2)
    return varchar2 is
    l_hr_person_type varchar2(255);
  begin

    select (case p_sf_personclass
             when 'F' then
              'Temp Replacement'
             when 'H' then
              'Temporary Employee'
             when 'J' then
              'Managed Services'
             when 'C' then
              'Consultant'
             when 'I' then
              'Intern/Student'
             when 'R' then
              'Contractor'
             when 'M' then
              'Employee'
             when 'L' then
              'IL Pupil'
             when 'D' then
              'Managed Services'
             else
              'Unknown/Error'
           END)
      into l_hr_person_type
      FROM DUAL;

    return l_hr_person_type;
  exception
    when others then
      return 'Unknown/Error';
      return l_hr_person_type;

  end map_sf_to_HR_person_Type;

  /* Function : truncated_compass_id
   By : Dan Melamed

   Function Purpose :
      Get truncated employee number (digits only)
      in employee_number/npw_number the truncated value is to be populated/compared with, and in the DFF (compas ID, attribute 10) the full value.

      if first character is numeric, return as is. if not numeric, truncat first character and return string without it.

   Version Control :
      1.0    CR 40116   Dan Melamed       22/Jan/2018
  */

  function truncated_compass_id(p_in_compass_id varchar2) return varchar is
    l_digit number;
  begin

    begin
      l_digit := substr(p_in_compass_id, 1, 1);
      return p_in_compass_id; -- first digit is numeric
    exception
      when others then
        return substr(p_in_compass_id, 2, length(p_in_compass_id) - 1); -- first digit is non numeric - I fell one exception
    end;
  exception
    when others then
      return p_in_compass_id;
  end truncated_compass_id;

  /* procedure : call_update_person_type
   By : Dan Melamed

   procedure Purpose :
      Update person type of employee (not employment type, just person type)
      Procedure only taking into account active employment periods (CWK/EMP) and not EX. EX are being handled by the termination / reverse terminatino directly.

   procedure variables :
       p_person_id - person ID to change
       p_effective_date - Change effective as of date
       p_new_person_type_id - new person type ID
       p_err_future - out error in case of future person type
   Version Control :
      1.0    CR 40116   Dan Melamed       22/Jan/2018
  */

  procedure call_update_person_type(p_person_id          number,
                                    p_effective_date     date,
                                    p_new_person_type_id number,
                                    p_err_future         out number) is
    Cursor curr_per_types is
      select pft.person_type_usage_id,
             pft.person_id,
             pft.object_version_number,
             pft.effective_start_date
        from per_person_Type_usages_f pft, per_person_types pert
       where pft.person_id = p_person_id
         and p_effective_date between pft.effective_start_date and
             pft.effective_end_date
         and pert.person_type_id = pft.person_type_id
         and pert.system_person_type in ('EMP', 'CWK') -- do not change Exs (Ex-employee, Ex Contractor)
            -- only change active employees person types. Hire and Terminate (and cancel hire) take care of the Ex types (set and remove)
         and rownum = 1; -- only one type active per period.

    l_ovn           number;
    l_update_mode   varchar2(255);
    l_new_date_from date;
    l_new_date_to   date;

    l_exist_future_pt number;
  begin
    -- XX_DEBUG(' PERSON type eff date for change is : ' ||
    --         to_char(p_effective_date, 'DD-MON-YYYY'));
    p_err_future := 0;

    for rec in curr_per_types loop

      -- check for future person type changes existance after requested change date.
      select count(1)
        into l_exist_future_pt
        from per_person_Type_usages_f pft
       where pft.person_id = p_person_id
         and pft.effective_start_date > p_effective_date;

      -- if any future person type changes, exit with error
      if l_exist_future_pt > 0 then
        p_err_future := 1;
        return;
      else
        if trunc(p_effective_date) = trunc(rec.effective_start_date) then

          l_update_mode := 'CORRECTION';
        else
          l_update_mode := 'UPDATE';
        end if;
      end if;
      l_ovn := rec.object_version_number;

      hr_person_type_usage_api.update_person_type_usage(p_validate              => false,
                                                        p_person_type_usage_id  => rec.person_type_usage_id,
                                                        p_effective_date        => p_effective_date,
                                                        p_datetrack_mode        => l_update_mode,
                                                        p_object_version_number => l_ovn,
                                                        p_person_type_id        => p_new_person_type_id,
                                                        p_effective_start_date  => l_new_date_from,
                                                        p_effective_end_date    => l_new_date_to);

    end loop;
  end call_update_person_type;

  /* procedure : get_code_comb_id
   By : Dan Melamed 22/Jan/2018

   Procedure Purpose :
      get CCID from GL gl_code_combinations table. do not create a new one if does not exist, error out.

    In Variables :
       p_which_codecomb indication of SOB Name (and which KFF structure to use, number of segments)
       p_finance_company :  ID as received from SOA/SF
       p_finance_dept : ID as received from SOA/SF
       p_finance_account : ID as received from SOA/SF

   returns
       CCID
         or if error, -1

   Version Control :
      1.0    CR 40116   Dan Melamed       22/Jan/2018
      1.1    CHG0042593   Dan Melamed       08-Apr-2018  Logic Corrections in SF2ORA Interface : Multiple SF Companies per ledger

  */

  procedure get_code_comb_id(p_finance_company varchar2,
                             p_company         varchar2,
                             p_finance_dept    varchar2,
                             p_finance_account varchar2,
                             p_out_ccid        out number,
                             p_out_ledger_id   out number,
                             P_OUT_ccid_vc     out varchar2,
                             p_out_ledger      OUT Varchar2) -- stub for get_code_comb_id
                             is


    l_concat_cc   varchar2(255);

    l_ccid        number;
    l_coa_id      number;
    l_return_code number;
    l_err_msg     varchar2(4000);

    l_finance_company varchar2(255);
    l_company         varchar2(255);
  begin

    if p_finance_company is null then
      p_out_ledger_id := null;
    else

      l_company         := p_company;
      l_finance_company := p_finance_company;

      begin

/*        xx_debug('P_COMPANY  ' || '*' || P_COMPANY || '*');
        xx_debug('P_finance_company  ' || '*' || P_finance_company || '*');
        xx_debug('p_finance_dept  ' || '*' || p_finance_dept || '*');
        xx_debug('p_finance_account  ' || '*' || p_finance_account || '*');*/

       /* select t.ledger_id, t.name
          into p_out_ledger_id, p_out_ledger
          from gl.gl_ledgers t, fnd_user us
         where 1 = 1
           and t.ledger_category_Code = 'PRIMARY'
           and t.attribute1 = l_company -- DFF For Company.
           and t.last_updated_by = us.user_id;*/

		-- CHG0042593 - Allow for multltiple companies take on same ledger.
       select gll.ledger_id, gll.name
          into p_out_ledger_id, p_out_ledger
          from gl.gl_ledgers gll, fnd_user us
         where 1 = 1
           and gll.ledger_category_Code = 'PRIMARY'
           and l_company in (
               select regexp_substr(gll.attribute1,'[^;]+', 1, level) from dual
                connect by regexp_substr(gll.attribute1, '[^;]+', 1, level) is not null
           )
           and gll.last_updated_by = us.user_id;


      exception
        when others then
          -- could not find ledger ID, exit as error.
          p_out_ledger_id := null;
          p_out_ccid      := -1;
          null;
      end;

    end if;

    if p_finance_company is null and p_finance_dept is null and
       p_finance_account is null then
      p_out_ccid := null;
      return;
    end if;

    if l_company = 'SSYSUS' then
      -- SSYSUS segments, otherwise, ROW segments.
      l_concat_cc := l_finance_company || '.' || p_finance_dept || '.' ||
                     p_finance_account || '.' || '000' || '.' || '000' || '.' || '00' || '.' ||
                     '000' || '.' || '0000';

    else
      -- otherwise, ROW segments.
      l_concat_cc := l_finance_company || '.' || p_finance_dept || '.' ||
                     p_finance_account || '.' || '0000000' || '.' || '000' || '.' ||
                     '000' || '.' || '00' || '.' || '0000' || '.' ||
                     '000000';
    end if;

      BEGIN

      SELECT gll.chart_of_accounts_id
        into l_coa_id
        FROM GL_LEDGER_NORM_SEG_VALS gln, gl_ledgers gll
       where gln.ledger_id = gll.ledger_id
         and gll.ledger_id = p_out_ledger_id
         and gln.segment_value = l_finance_company;

      exception
        when no_Data_found then
           p_out_ccid := -2;
           return;
      end;

     BEGIN

      -- xx_debug('l_coa_id : ' || l_coa_id);
      P_OUT_ccid_vc  := l_concat_cc;
      XXGL_UTILS_PKG.GET_AND_CREATE_ACCOUNT(p_concat_segment      => l_concat_cc,
                                            p_coa_id              => l_coa_id,
                                            x_code_combination_id => l_ccid,
                                            x_return_code         => l_return_code,
                                            x_err_msg             => l_err_msg);

    exception
      when others then
        if l_ccid > 0 then
          p_out_ccid := l_ccid;
        else
          p_out_ccid := -1;
        end if;
        return;
    end;

  exception
    when others then
      p_out_ccid := -1;
  end get_code_comb_id;


    /* procedure : call_re_hire_employee
   By : Dan Melamed 22/Jan/2018

   Procedure Purpose :
      call Seeded API to rehire an employee (EMP)

    In Variables :
       p_person_id : person ID to be re-hired
       p_hire_date : Rehire date
       p_object_version_number : period of service object version ID
    Out Variables :
       p_out_err : Out Error if any.
       p_object_version_number : period of service object version ID

   returns
       CCID
         or if error, -1

   Version Control :
      1.0    CR 40116   Dan Melamed       22/Jan/2018
  */


  procedure call_re_hire_employee(p_person_id             number,
                                  p_hire_date             date,
                                  p_object_version_number in out number,
                                  p_out_err               out varchar2) is

    ln_per_object_version_number  PER_ALL_PEOPLE_F.OBJECT_VERSION_NUMBER%TYPE := p_object_version_number;
    ln_assg_object_version_number PER_ALL_ASSIGNMENTS_F.OBJECT_VERSION_NUMBER%TYPE;
    ln_assignment_id              PER_ALL_ASSIGNMENTS_F.ASSIGNMENT_ID%TYPE;
    ld_per_effective_start_date   PER_ALL_PEOPLE_F.EFFECTIVE_START_DATE%TYPE;
    ld_per_effective_end_date     PER_ALL_PEOPLE_F.EFFECTIVE_END_DATE%TYPE;
    ln_assignment_sequence        PER_ALL_ASSIGNMENTS_F.ASSIGNMENT_SEQUENCE%TYPE;
    lb_assign_payroll_warning     BOOLEAN;
    lc_assignment_number          PER_ALL_ASSIGNMENTS_F.ASSIGNMENT_NUMBER%TYPE;

  BEGIN

    -- Rehire Employee API
    -- --------------------------------
    hr_employee_api.re_hire_ex_employee( -- Input data elements
                                        -- -----------------------------
                                        p_hire_date     => p_hire_date,
                                        p_person_id     => p_person_id,
                                        p_rehire_reason => NULL,
                                        -- Output data elements
                                        -- --------------------------------
                                        p_assignment_id             => ln_assignment_id,
                                        p_per_object_version_number => ln_per_object_version_number,
                                        p_asg_object_version_number => ln_assg_object_version_number,
                                        p_per_effective_start_date  => ld_per_effective_start_date,
                                        p_per_effective_end_date    => ld_per_effective_end_date,
                                        p_assignment_sequence       => ln_assignment_sequence,
                                        p_assignment_number         => lc_assignment_number,
                                        p_assign_payroll_warning    => lb_assign_payroll_warning);

  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      p_out_err := SUBSTR(SQLERRM, 1, 255);
  END call_re_hire_employee;

  /* procedure : update_assignment_cwk
   By : Dan Melamed 22/Jan/2018

   Procedure Purpose :
      Call oracle seeded API to update cwk assignment

    In Variables :
       p_employee_rec : original values from processing bulk
       p_person_id : person_ID to be updated
       p_assignment_id : assignment_ID to be updated
       p_people_group_id : not used at this point
       p_supervisor_id : supervisor person ID
       p_location_id : location ID (translated from SF value in 'call data update')
       p_code_comb_id : code combination ID (got from get_code_comb_id)
       p_ledger_id : set of books ID (by logic, in 'call data update'
       p_object_version_number : assignment object version number.
       p_effective_date : effective date of the change

    Out :
       p_out_err : errors from oracle seeded API if any

   Version Control :
      1.0    CR 40116   Dan Melamed       22/Jan/2018
  */

  procedure update_assignment_emp(p_employee_rec          xxhr_emp_rec,  -- bring the record for any future changes as they may be required. not used now.
                                  p_assignment_id         number,
                                  p_grade_id              number,
                                  p_people_group_id       varchar2,
                                  p_supervisor_id         number,
                                  p_location_id           number,
                                  p_code_comb_id          number,
                                  p_ledger_id             number,
                                  p_object_version_number in out number,
                                  p_effective_date        date,
                                  p_out_err               out varchar2) is
    -- Local Variables
    -- -----------------------
    lc_dt_ud_mode VARCHAR2(100) := NULL;

    ln_assignment_id   NUMBER := p_assignment_id;
    ln_supervisor_id   NUMBER := p_supervisor_id;
    ln_object_number   NUMBER := p_object_version_number;
    ln_people_group_id NUMBER := p_people_group_id;

    -- Out Variables for Find Date Track Mode API
    -- -----------------------------------------------------------------
    lb_correction           BOOLEAN;
    lb_update               BOOLEAN;
    lb_update_override      BOOLEAN;
    lb_update_change_insert BOOLEAN;

    -- Out Variables for Update Employee Assignment API
    -- ----------------------------------------------------------------------------
    ln_soft_coding_keyflex_id HR_SOFT_CODING_KEYFLEX.SOFT_CODING_KEYFLEX_ID%TYPE;
    lc_concatenated_segments  VARCHAR2(2000);
    ln_comment_id             PER_ALL_ASSIGNMENTS_F.COMMENT_ID%TYPE;
    lb_no_managers_warning    BOOLEAN;

    -- Out Variables for Update Employee Assgment Criteria
    -- -------------------------------------------------------------------------------
    ln_special_ceiling_step_id    PER_ALL_ASSIGNMENTS_F.SPECIAL_CEILING_STEP_ID%TYPE;
    lc_group_name                 VARCHAR2(30);
    ld_effective_start_date       PER_ALL_ASSIGNMENTS_F.EFFECTIVE_START_DATE%TYPE;
    ld_effective_end_date         PER_ALL_ASSIGNMENTS_F.EFFECTIVE_END_DATE%TYPE;
    lb_org_now_no_manager_warning BOOLEAN;
    lb_other_manager_warning      BOOLEAN;
    lb_spp_delete_warning         BOOLEAN;
    lc_entries_changed_warning    VARCHAR2(30);
    lb_tax_district_changed_warn  BOOLEAN;
    l_temp_grade                  number;
  begin

    -- update asg and criteria
    -- calculate update mode directly as this changes / may change between first API and latter.

    -- if received grade is 0 or null, keep current value. otherwise try to pass on received value.

    select decode(p_grade_id,
                  0,
                  hr_api.g_number,
                  null,
                  hr_api.g_number,
                  p_grade_id)
      into l_temp_grade
      from dual;

    dt_api.find_dt_upd_modes(p_effective_date  => p_effective_date,
                             p_base_table_name => 'PER_ALL_ASSIGNMENTS_F',
                             p_base_key_column => 'ASSIGNMENT_ID',
                             p_base_key_value  => ln_assignment_id,
                             -- Output data elements
                             -- --------------------------------
                             p_correction           => lb_correction,
                             p_update               => lb_update,
                             p_update_override      => lb_update_override,
                             p_update_change_insert => lb_update_change_insert);

    IF (lb_update_override = TRUE OR lb_update_change_insert = TRUE) THEN
      -- UPDATE_OVERRIDE
      -- ---------------------------------
      lc_dt_ud_mode := 'UPDATE_OVERRIDE';
    END IF;

    IF (lb_correction = TRUE) THEN
      -- CORRECTION
      -- ----------------------
      lc_dt_ud_mode := 'CORRECTION';
    END IF;

    IF (lb_update = TRUE) THEN
      -- UPDATE
      -- --------------
      lc_dt_ud_mode := 'UPDATE';
    END IF;

    -- Update Employee Assignment
    -- ---------------------------------------------
    hr_assignment_api.update_emp_asg( -- Input data elements
                                     -- ------------------------------
                                     p_effective_date        => p_effective_date,
                                     p_datetrack_update_mode => lc_dt_ud_mode,
                                     p_assignment_id         => ln_assignment_id,
                                     p_supervisor_id         => ln_supervisor_id,
                                     p_change_reason         => hr_api.g_varchar2,
                                     p_manager_flag          => hr_api.g_varchar2, -- keep whats in
                                     p_default_code_comb_id  => p_code_comb_id,
                                     p_set_of_books_id       => p_ledger_id,
                                     -- Output data elements
                                     -- -------------------------------
                                     p_object_version_number  => ln_object_number,
                                     p_soft_coding_keyflex_id => ln_soft_coding_keyflex_id,
                                     p_concatenated_segments  => lc_concatenated_segments,
                                     p_comment_id             => ln_comment_id,
                                     p_effective_start_date   => ld_effective_start_date,
                                     p_effective_end_date     => ld_effective_end_date,
                                     p_no_managers_warning    => lb_no_managers_warning,
                                     p_other_manager_warning  => lb_other_manager_warning);

    -- Find Date Track Mode for Second API
    -- ------------------------------------------------------
    dt_api.find_dt_upd_modes(p_effective_date  => p_effective_date,
                             p_base_table_name => 'PER_ALL_ASSIGNMENTS_F',
                             p_base_key_column => 'ASSIGNMENT_ID',
                             p_base_key_value  => ln_assignment_id,
                             -- Output data elements
                             -- -------------------------------
                             p_correction           => lb_correction,
                             p_update               => lb_update,
                             p_update_override      => lb_update_override,
                             p_update_change_insert => lb_update_change_insert);

    IF (lb_update_override = TRUE OR lb_update_change_insert = TRUE) THEN
      -- UPDATE_OVERRIDE
      -- --------------------------------
      lc_dt_ud_mode := 'UPDATE_OVERRIDE';
    END IF;

    IF (lb_correction = TRUE) THEN
      -- CORRECTION
      -- ----------------------
      lc_dt_ud_mode := 'CORRECTION';
    END IF;

    IF (lb_update = TRUE) THEN
      -- UPDATE
      -- --------------
      lc_dt_ud_mode := 'UPDATE';
    END IF;

    -- Update Employee Assgment Criteria
    -- -----------------------------------------------------
    hr_assignment_api.update_emp_asg_criteria( -- Input data elements
                                              -- ------------------------------
                                              p_effective_date        => p_effective_date,
                                              p_datetrack_update_mode => lc_dt_ud_mode,
                                              p_assignment_id         => ln_assignment_id,
                                              p_location_id           => p_location_id,
                                              p_grade_id              => l_temp_grade,
                                              p_job_id                => hr_api.g_number,
                                              p_payroll_id            => hr_api.g_number,
                                              p_organization_id       => hr_api.g_number,
                                              p_employment_category   => hr_api.g_varchar2,
                                              -- Output data elements
                                              -- -------------------------------
                                              p_people_group_id              => ln_people_group_id,
                                              p_object_version_number        => ln_object_number,
                                              p_special_ceiling_step_id      => ln_special_ceiling_step_id,
                                              p_group_name                   => lc_group_name,
                                              p_effective_start_date         => ld_effective_start_date,
                                              p_effective_end_date           => ld_effective_end_date,
                                              p_org_now_no_manager_warning   => lb_org_now_no_manager_warning,
                                              p_other_manager_warning        => lb_other_manager_warning,
                                              p_spp_delete_warning           => lb_spp_delete_warning,
                                              p_entries_changed_warning      => lc_entries_changed_warning,
                                              p_tax_district_changed_warning => lb_tax_district_changed_warn);

    -- COMMIT;

  exception
    when others then
      rollback;
      p_out_err := SUBSTR(sqlerrm, 1, 255);
  end update_assignment_emp;

  /* procedure : update_assignment_cwk
   By : Dan Melamed 22/Jan/2018

   Procedure Purpose :
      Call oracle seeded API to update cwk assignment

    In Variables :
       p_employee_rec : original values from processing bulk
       p_person_id : person_ID to be updated
       p_assignment_id : assignment_ID to be updated
       p_people_group_id : not used at this point
       p_supervisor_id : supervisor person ID
       p_location_id : location ID (translated from SF value in 'call data update')
       p_code_comb_id : code combination ID (got from get_code_comb_id)
       p_ledger_id : set of books ID (by logic, in 'call data update'
       p_object_version_number : assignment object version number.
       p_effective_date : effective date of the change

    Out :
       p_out_err : errors from oracle seeded API if any

   Version Control :
      1.0    CR 40116   Dan Melamed       22/Jan/2018
  */

  procedure update_assignment_cwk(p_employee_rec          xxhr_emp_rec, -- bring the record for any future changes as they may be required. not used now.
                                  p_assignment_id         number,
                                  p_grade_id              number,
                                  p_people_group_id       varchar2,
                                  p_supervisor_id         number,
                                  p_location_id           number,
                                  p_code_comb_id          number,
                                  p_ledger_id             number,
                                  p_object_version_number in out number,
                                  p_effective_date        date,
                                  p_out_err               out varchar2) is
    -- Local Variables
    -- -----------------------
    lc_dt_ud_mode VARCHAR2(100) := NULL;

    ln_assignment_id   NUMBER := p_assignment_id;
    ln_supervisor_id   NUMBER := p_supervisor_id;
    ln_object_number   NUMBER := p_object_version_number;
    ln_people_group_id NUMBER := p_people_group_id;

    -- Out Variables for Find Date Track Mode API
    -- -----------------------------------------------------------------
    lb_correction           BOOLEAN;
    lb_update               BOOLEAN;
    lb_update_override      BOOLEAN;
    lb_update_change_insert BOOLEAN;

    -- Out Variables for Update Employee Assignment API
    -- ----------------------------------------------------------------------------
    ln_soft_coding_keyflex_id HR_SOFT_CODING_KEYFLEX.SOFT_CODING_KEYFLEX_ID%TYPE;
    lc_concatenated_segments  VARCHAR2(2000);
    ln_comment_id             PER_ALL_ASSIGNMENTS_F.COMMENT_ID%TYPE;
    lb_no_managers_warning    BOOLEAN;
    lb_hourly_sala_warn       boolean;
    -- Out Variables for Update Employee Assgment Criteria
    -- -------------------------------------------------------------------------------
--    ln_special_ceiling_step_id    PER_ALL_ASSIGNMENTS_F.SPECIAL_CEILING_STEP_ID%TYPE;
    lc_group_name                 VARCHAR2(30);
    ld_effective_start_date       PER_ALL_ASSIGNMENTS_F.EFFECTIVE_START_DATE%TYPE;
    ld_effective_end_date         PER_ALL_ASSIGNMENTS_F.EFFECTIVE_END_DATE%TYPE;
    lb_org_now_no_manager_warning BOOLEAN;
    lb_other_manager_warning      BOOLEAN;
    lb_spp_delete_warning         BOOLEAN;
    lc_entries_changed_warning    VARCHAR2(30);
    lb_tax_district_changed_warn  BOOLEAN;
    l_temp_grade                  number;
  begin

    -- update asg and criteria
    -- calculate update mode directly as this changes / may change between first API and latter.

   -- if grade is 0 or null, pass current value. otherwise attempt to pass received value.

    select decode(p_grade_id,
                  0,
                  hr_api.g_number,
                  null,
                  hr_api.g_number,
                  p_grade_id)
      into l_temp_grade
      from dual;

    dt_api.find_dt_upd_modes(p_effective_date  => p_effective_date,
                             p_base_table_name => 'PER_ALL_ASSIGNMENTS_F',
                             p_base_key_column => 'ASSIGNMENT_ID',
                             p_base_key_value  => ln_assignment_id,
                             -- Output data elements
                             -- --------------------------------
                             p_correction           => lb_correction,
                             p_update               => lb_update,
                             p_update_override      => lb_update_override,
                             p_update_change_insert => lb_update_change_insert);

    IF (lb_update_override = TRUE OR lb_update_change_insert = TRUE) THEN
      -- UPDATE_OVERRIDE
      -- ---------------------------------
      lc_dt_ud_mode := 'UPDATE_OVERRIDE';
    END IF;

    IF (lb_correction = TRUE) THEN
      -- CORRECTION
      -- ----------------------
      lc_dt_ud_mode := 'CORRECTION';
    END IF;

    IF (lb_update = TRUE) THEN
      -- UPDATE
      -- --------------
      lc_dt_ud_mode := 'UPDATE';
    END IF;

    -- Update Employee Assignment
    -- ---------------------------------------------
    hr_assignment_api.update_cwk_asg( -- Input data elements
                                     -- ------------------------------
                                     p_effective_date        => p_effective_date,
                                     p_datetrack_update_mode => lc_dt_ud_mode,
                                     p_assignment_id         => ln_assignment_id,
                                     p_supervisor_id         => ln_supervisor_id,
                                     p_change_reason         => hr_api.g_varchar2,
                                     p_set_of_books_id       => p_ledger_id,
                                     p_default_code_comb_id  => p_code_comb_id,
                                     -- Output data elements
                                     -- -------------------------------
                                     p_object_version_number      => ln_object_number,
                                     p_soft_coding_keyflex_id     => ln_soft_coding_keyflex_id,
                                     p_concatenated_segments      => lc_concatenated_segments,
                                     p_comment_id                 => ln_comment_id,
                                     p_effective_start_date       => ld_effective_start_date,
                                     p_effective_end_date         => ld_effective_end_date,
                                     p_no_managers_warning        => lb_no_managers_warning,
                                     p_other_manager_warning      => lb_other_manager_warning,
                                     p_org_now_no_manager_warning => lb_org_now_no_manager_warning,
                                     p_hourly_salaried_warning    => lb_hourly_sala_warn);

    -- Find Date Track Mode for Second API
    -- ------------------------------------------------------
    dt_api.find_dt_upd_modes(p_effective_date  => p_effective_date,
                             p_base_table_name => 'PER_ALL_ASSIGNMENTS_F',
                             p_base_key_column => 'ASSIGNMENT_ID',
                             p_base_key_value  => ln_assignment_id,
                             -- Output data elements
                             -- -------------------------------
                             p_correction           => lb_correction,
                             p_update               => lb_update,
                             p_update_override      => lb_update_override,
                             p_update_change_insert => lb_update_change_insert);

    IF (lb_update_override = TRUE OR lb_update_change_insert = TRUE) THEN
      -- UPDATE_OVERRIDE
      -- --------------------------------
      lc_dt_ud_mode := 'UPDATE_OVERRIDE';
    END IF;

    IF (lb_correction = TRUE) THEN
      -- CORRECTION
      -- ----------------------
      lc_dt_ud_mode := 'CORRECTION';
    END IF;

    IF (lb_update = TRUE) THEN
      -- UPDATE
      -- --------------
      lc_dt_ud_mode := 'UPDATE';
    END IF;

    -- Update Employee Assgment Criteria
    -- -----------------------------------------------------
    hr_assignment_api.update_cwk_asg_criteria( -- Input data elements
                                              -- ------------------------------
                                              p_effective_date        => p_effective_date,
                                              p_datetrack_update_mode => lc_dt_ud_mode,
                                              p_assignment_id         => ln_assignment_id,
                                              p_location_id           => p_location_id,
                                              p_grade_id              => l_temp_grade,
                                              p_job_id                => hr_api.g_number,
                                              p_organization_id       => hr_api.g_number,
                                              -- Output data elements
                                              -- -------------------------------
                                              p_people_group_id       => ln_people_group_id,
                                              p_object_version_number => ln_object_number,
                                              --  p_special_ceiling_step_id                  => ln_special_ceiling_step_id,
                                              p_people_group_name            => lc_group_name,
                                              p_effective_start_date         => ld_effective_start_date,
                                              p_effective_end_date           => ld_effective_end_date,
                                              p_org_now_no_manager_warning   => lb_org_now_no_manager_warning,
                                              p_other_manager_warning        => lb_other_manager_warning,
                                              p_spp_delete_warning           => lb_spp_delete_warning,
                                              p_entries_changed_warning      => lc_entries_changed_warning,
                                              p_tax_district_changed_warning => lb_tax_district_changed_warn);

    --COMMIT;

  exception
    when others then
      rollback;
      p_out_err := SUBSTR(sqlerrm, 1, 255);
  end update_assignment_cwk;

  /* procedure : update_person
   By : Dan Melamed 22/Jan/2018

   Procedure Purpose :
      Call oracle seeded API to update person

    In Variables :
       p_update_mode : Update API Method type (to allow update in case of re-hire, and correction on other cases)
       p_employee_rec : Employee information holding all information for employee to be updated.
       p_person_id : Person ID to be updated.
       sf_person_type_id : SF received person type (Employee/Pupil, etc..)
       p_ovn : Object Verison Number of PPF Record.
       p_update_date : Update Cutoff date.

    Out :
       p_out_err : errors from oracle seeded API if any

   Version Control :
      1.0    CR 40116   Dan Melamed       22/Jan/2018
  */

  procedure update_person(p_update_mode     varchar2,
                          p_employee_rec    xxhr_emp_rec,
                          p_person_id       number,
                          sf_person_type_id number,
                          p_ovn             in out number,
                          p_update_date     date,
                          p_out_err         out varchar2) is

    -- Local Variables
    -- -----------------------
  --  ln_object_version_number PER_ALL_PEOPLE_F.OBJECT_VERSION_NUMBER%TYPE := p_ovn;
--    lc_dt_ud_mode            VARCHAR2(100) := NULL;

    -- Out Variables for Update Employee API
    -- -----------------------------------------------------------
    ld_effective_start_date     DATE;
    ld_effective_end_date       DATE;
    lc_full_name                PER_ALL_PEOPLE_F.FULL_NAME%TYPE;
    ln_comment_id               PER_ALL_PEOPLE_F.COMMENT_ID%TYPE;
    lb_name_combination_warning BOOLEAN;
    lb_assign_payroll_warning   BOOLEAN;
    lb_orig_hire_warning        BOOLEAN;
    lc_employee_number          varchar2(255);

  BEGIN

    -- Find Date Track Mode
    -- --------------------------------


    --xx_debug(' in update person');
    lc_employee_number := hr_api.g_varchar2;
    --xx_debug(p_employee_rec.Per_gender || ' gen');
/*    xx_debug(p_employee_rec.Per_first_name || ' fn');
    xx_debug(p_employee_rec.Per_last_name || ' ln');
    xx_debug(p_employee_rec.Per_middle_name || ' mn');
    xx_debug(to_char(p_employee_rec.Per_date_of_birth, 'DD-MON-YYYY') || ' date of birth');
    xx_debug(p_employee_rec.Per_email || 'eml');*/

    -- Update Employee API
    -- ---------------------------------
    hr_person_api.update_person( -- Input Data Elements
                                -- ------------------------------
                                p_effective_date        => p_update_date,
                                p_datetrack_update_mode => p_update_mode,
                                p_person_id             => p_person_id,
                                p_person_type_id        => sf_person_type_id,
                                p_first_name            => p_employee_rec.Per_first_name,
                                p_last_name             => p_employee_rec.Per_last_name,
                                p_middle_names          => p_employee_rec.Per_middle_name,
                                p_sex                   => p_employee_rec.Per_gender,
                                p_date_of_birth         => p_employee_rec.Per_date_of_birth,
                                P_EMAIL_ADDRESS         => p_employee_rec.Per_email,

                                -- Output Data Elements
                                -- ----------------------------------
                                p_employee_number          => lc_employee_number,
                                p_object_version_number    => p_ovn,
                                p_effective_start_date     => ld_effective_start_date,
                                p_effective_end_date       => ld_effective_end_date,
                                p_full_name                => lc_full_name,
                                p_comment_id               => ln_comment_id,
                                p_name_combination_warning => lb_name_combination_warning,
                                p_assign_payroll_warning   => lb_assign_payroll_warning,
                                p_orig_hire_warning        => lb_orig_hire_warning);

    -- COMMIT;

  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
         p_out_err := SUBSTR(sqlerrm, 1, 255);
  END update_person;

  /* procedure : create_employee
   By : Dan Melamed 22/Jan/2018

   Procedure Purpose :
      Call oracle seeded API to create employee.

    In Variables :
       p_hire_date Hire date
       p_first_name first name
       p_last_name last_name
       p_middle_name middle_name
       p_gender : M/F Gender
       p_date_of_birth birthdate of employee
       p_compass_id : full compass ID (including initial character if any)

       ...
    Out :
        p_person_id : person_id of new created emp
        p_assignment_id : p_assignment_id of new created employment
       p_out_err : errors from oracle seeded API if any

   Version Control :
      1.0    CR 40116   Dan Melamed       22/Jan/2018
  */

  procedure create_employee(p_hire_date     date,
                            p_first_name    varchar2,
                            p_last_name     varchar2,
                            p_middle_name   varchar2,
                            p_gender        varchar2,
                            p_date_of_birth date,
                            p_compass_id    varchar2,
                            p_person_id     out number,
                            p_assignment_id out number,
                            p_out_err       out varchar2) is

    lc_employee_number   PER_ALL_PEOPLE_F.EMPLOYEE_NUMBER%TYPE := p_compass_id;
    ln_person_id         PER_ALL_PEOPLE_F.PERSON_ID%TYPE;
    ln_assignment_id     PER_ALL_ASSIGNMENTS_F.ASSIGNMENT_ID%TYPE;
    ln_object_ver_number PER_ALL_ASSIGNMENTS_F.OBJECT_VERSION_NUMBER%TYPE;
    ln_asg_ovn           NUMBER;

    ld_per_effective_start_date PER_ALL_PEOPLE_F.EFFECTIVE_START_DATE%TYPE;
    ld_per_effective_end_date   PER_ALL_PEOPLE_F.EFFECTIVE_END_DATE%TYPE;
    lc_full_name                PER_ALL_PEOPLE_F.FULL_NAME%TYPE;
    ln_per_comment_id           PER_ALL_PEOPLE_F.COMMENT_ID%TYPE;
    ln_assignment_sequence      PER_ALL_ASSIGNMENTS_F.ASSIGNMENT_SEQUENCE%TYPE;
    lc_assignment_number        PER_ALL_ASSIGNMENTS_F.ASSIGNMENT_NUMBER%TYPE;

    lb_name_combination_warning BOOLEAN;
    lb_assign_payroll_warning   BOOLEAN;
    lb_orig_hire_warning        BOOLEAN;

    l_employee_id varchar2(255) := truncated_compass_id(p_compass_id);

  BEGIN
    hr_employee_api.create_employee( -- Input data elements
                                    -- ------------------------------
                                    p_hire_date         => p_hire_date,
                                    p_business_group_id => 0,
                                    p_last_name         => p_last_name,
                                    p_first_name        => p_first_name,
                                    p_middle_names      => p_middle_name,
                                    p_sex               => p_gender,
                                    p_date_of_birth     => p_date_of_birth,
                                    P_ATTRIBUTE10       => lc_employee_number,

                                    -- Output data elements
                                    -- --------------------------------
                                    p_employee_number           => l_employee_id,
                                    p_person_id                 => ln_person_id,
                                    p_assignment_id             => ln_assignment_id,
                                    p_per_object_version_number => ln_object_ver_number,
                                    p_asg_object_version_number => ln_asg_ovn,
                                    p_per_effective_start_date  => ld_per_effective_start_date,
                                    p_per_effective_end_date    => ld_per_effective_end_date,
                                    p_full_name                 => lc_full_name,
                                    p_per_comment_id            => ln_per_comment_id,
                                    p_assignment_sequence       => ln_assignment_sequence,
                                    p_assignment_number         => lc_assignment_number,
                                    p_name_combination_warning  => lb_name_combination_warning,
                                    p_assign_payroll_warning    => lb_assign_payroll_warning,
                                    p_orig_hire_warning         => lb_orig_hire_warning);

    p_assignment_id := ln_assignment_id;
    p_person_id     := ln_person_id;

  EXCEPTION
    WHEN OTHERS THEN
      p_out_err := SUBSTR(sqlerrm, 1, 255);
      ROLLBACK;
  END create_employee;

 /* procedure : create_contingent
   By : Dan Melamed 22/Jan/2018

   Procedure Purpose :
      Call oracle seeded API to create CWK (Contingent worker).

    In Variables :
       p_hire_date Hire date
       p_first_name first name
       p_last_name last_name
       p_middle_name middle_name
       p_gender : M/F Gender
       p_date_of_birth birthdate of employee
       p_compass_id : full compass ID (including initial character if any)

       ...
    Out :
        p_person_id : person_id of new created emp
        p_assignment_id : p_assignment_id of new created employment
       p_out_err : errors from oracle seeded API if any

   Version Control :
      1.0    CR 40116   Dan Melamed       22/Jan/2018
  */

  procedure create_contingent(p_hire_date     date,
                              p_first_name    varchar2,
                              p_last_name     varchar2,
                              p_middle_name   varchar2,
                              p_gender        varchar2,
                              p_date_of_birth date,
                              p_compass_id    varchar2,
                              p_person_id     out number,
                              p_assignment_id out number,
                              p_out_err       out varchar2) is

    lc_npw_number        PER_ALL_PEOPLE_F.npw_number%TYPE := p_compass_id;
    ln_person_id         PER_ALL_PEOPLE_F.PERSON_ID%TYPE;
    ln_assignment_id     PER_ALL_ASSIGNMENTS_F.ASSIGNMENT_ID%TYPE;
    ln_object_ver_number PER_ALL_ASSIGNMENTS_F.OBJECT_VERSION_NUMBER%TYPE;
    ln_asg_ovn           NUMBER;

    ld_per_effective_start_date PER_ALL_PEOPLE_F.EFFECTIVE_START_DATE%TYPE;
    ld_per_effective_end_date   PER_ALL_PEOPLE_F.EFFECTIVE_END_DATE%TYPE;
    lc_full_name                PER_ALL_PEOPLE_F.FULL_NAME%TYPE;
    ln_per_comment_id           PER_ALL_PEOPLE_F.COMMENT_ID%TYPE;
    ln_assignment_sequence      PER_ALL_ASSIGNMENTS_F.ASSIGNMENT_SEQUENCE%TYPE;
    lc_assignment_number        PER_ALL_ASSIGNMENTS_F.ASSIGNMENT_NUMBER%TYPE;

    lb_name_combination_warning  BOOLEAN;
/*    lb_assign_payroll_warning    BOOLEAN;
    lb_orig_hire_warning         BOOLEAN;
*/    lb_pdp_object_version_number number;

    l_employee_id varchar2(255) := truncated_compass_id(p_compass_id);

  BEGIN
    hr_contingent_worker_api.create_cwk( -- Input data elements
                                        -- ------------------------------
                                        p_start_date        => p_hire_date,
                                        p_business_group_id => 0,
                                        p_last_name         => p_last_name,
                                        p_first_name        => p_first_name,
                                        p_middle_names      => p_middle_name,
                                        p_sex               => p_gender,
                                        p_date_of_birth     => p_date_of_birth,
                                        P_ATTRIBUTE10       => lc_npw_number,

                                        -- Output data elements
                                        -- --------------------------------
                                        p_npw_number                => l_employee_id,
                                        p_person_id                 => ln_person_id,
                                        p_assignment_id             => ln_assignment_id,
                                        p_per_object_version_number => ln_object_ver_number,
                                        p_asg_object_version_number => ln_asg_ovn,
                                        p_per_effective_start_date  => ld_per_effective_start_date,
                                        p_per_effective_end_date    => ld_per_effective_end_date,
                                        p_full_name                 => lc_full_name,
                                        p_comment_id                => ln_per_comment_id,
                                        p_assignment_sequence       => ln_assignment_sequence,
                                        p_assignment_number         => lc_assignment_number,
                                        p_name_combination_warning  => lb_name_combination_warning,
                                        p_pdp_object_version_number => lb_pdp_object_version_number);

    p_assignment_id := ln_assignment_id;
    p_person_id     := ln_person_id;

  EXCEPTION
    WHEN OTHERS THEN
      p_out_err := SUBSTR(sqlerrm, 1, 255);
      ROLLBACK;
  END create_contingent;

  /* procedure : call_data_update
   By : Dan Melamed 22/Jan/2018

   Procedure Purpose :
      translate SF Received information into oracle values, compare with oracle current values.
      do reverse termination, change first working date, Assignment changes, person changes.

    In Variables :
       p_employee_rec - row from the updating bulk
    Out :
       p_person_id - not used at this point.
       p_assignment_id - not used at this point
       p_err_code - Error indication for processing
       p_err_text - actual error received if any.

   Version Control :
      1.0    CR 40116   Dan Melamed       22/Jan/2018
      1.1    CHG0042593   Dan Melamed       08-Apr-2018  Logic Corrections in SF2ORA Interface : Person date method, ignore hire date change if hire can not be updated, assignment active by not in 'terminate assignment'
      1.2    CHG0043076   Dan Melamed       21-May-2018  Correct select to fetch person record for future re-hire
                                                         if hire date change error, discard the error and continue
                                                         if Termination date changed, exit and do nothing else.
                                                         If rehired already , skip the rehire and process as data change only.
                                                         Update (if null) the External ID (Attribute10) in person
                                                         If termination date null, reverse terminate only if hire date (SF) > termination date (ORA)

  */

  Procedure call_data_update(p_employee_rec  xxhr_emp_rec,
                             p_err_code      out number,
                             p_err_text      out varchar2
                             ) is

    l_employee_id               varchar2(255) := truncated_compass_id(p_employee_rec.person_id_external);  -- get numeric only employee_number (for emp/cwk#)
    l_manager_id                varchar2(255) := truncated_compass_id(p_employee_rec.ASG_manager); -- get numeric only supervisor # (for emp/cwk#)


    l_ORA_hire_date         date;
    l_ORA_ter_date          date;
    l_ORA_person_id         number;
    l_ora_period_id         number;
    l_ora_type_hr           varchar2(255);

    -- current assignment and upervisor records
    l_assignment_rec        per_all_assignments_f%rowtype;
    p_people_rec            per_all_people_f%rowtype;


   p_people_rec_last            per_all_people_f%rowtype;




    l_update_type           varchar2(255);
    l_ovn                   number;
    l_out_err               varchar2(4000);

    -- sf received person type ID and validation
    l_sf_person_Type_id     number;
    l_validate_emp_type_cng number;
    l_hr_person_type            varchar2(255); -- received from SF, translated to ORA Language by mapping.


    -- used for translating incoming Compass information to oracle language for comparison and parameter passing
    l_location_id              number;
    l_supervisor_id            number;
    l_ledger_id                number;
    l_default_code_combination number;
    l_people_group_id          number;  -- currently not used, to be used in the future.



    l_emp_type_sf               varchar2(255);
    l_update_emptype_future_Err number;
--    l_period_count              number;
    l_proc_name                 varchar2(255) := 'API Procedure : Data_Update - ';
    l_lookfor_ass_type          varchar2(1);
    l_grade_id                  number;
    l_ppf_date                  date;

-- Out perameters required by called oracle seeded APIs
    l_warn_ee               varchar2(255); -- needed by Rehire
    l_changes_in_person     number;
    l_changes_in_pertypes   number;
    l_changes_in_assignment number;
    l_ORA_prev_ter_date date;

    l_code_combination varchar2(255);
    l_ledger varchar2(255);
  begin

    -- get last *employment* record in ORA --> start and end dates, type (C/E) etc, Verify employee exists in Oracle.

    BEGIN

      --xx_debug(' in d');
      l_ppf_date := get_most_recent_ppf_date(l_employee_id);

      --xx_debug(' in d2' || to_char(l_ppf_date, 'DD-MON-YYYY'));

      -- get lastst hire date from Oracle : Person_ID, Hire Date, Termination Date, Employment Type (CWK/EMP), and period (Service/Placement) ID.
      with periods as
       (select 'EMP' EMPTYPE,
               per.period_of_service_id period_id,
               per.person_id,
               per.date_start,
               per.actual_termination_date,
               per.last_standard_process_date,
               per.CREATION_DATE,
               per.object_version_number,
               per.period_of_service_id
          from per_periods_of_service per
        UNION
        select 'CWK' EMPTYPE,
               ser.period_of_placement_id period_id,
               ser.person_id,
               ser.date_start,
               ser.actual_termination_date,
               ser.last_standard_process_date,
               ser.CREATION_DATE,
               ser.object_version_number,
               ser.period_of_placement_id
          from per_periods_of_placement ser

        ),
      orderedByRecent as
       (select PER.EMPTYPE,
               ppf.first_name,
               ppf.last_name,
               per.date_start,
               per.actual_Termination_date,
               per.person_id,
               per.Object_Version_Number,
               per.period_id
          from per_all_people_f ppf, periods per
         where 1 = 1
           and nvl(ppf.employee_number, ppf.npw_number) = l_employee_id
           and per.person_id = ppf.person_id
           AND l_ppf_date between ppf.effective_start_date and
               ppf.effective_end_date
         order by per.date_start desc, ppf.effective_start_date desc)
      select sel.date_start,
             sel.actual_Termination_date,
             sel.person_id,
             sel.emptype,
             sel.period_id
        into l_ORA_hire_date,
             l_ORA_ter_date,
             l_ORA_person_id,
             l_ora_type_hr,
             l_ora_period_id
        from orderedByRecent sel
       where rownum = 1;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
          p_err_code := 1;
         fnd_message.clear;
         fnd_message.set_name ('XXOBJT', 'XXHR_SF2ORA_ERROR_EMPNOTEXIST');
         fnd_message.set_token('ERRPROCEDURE', 'Change Personal data');
         fnd_message.set_token('ERRCODE', '02');
         fnd_message.set_token('ERRADDTXT', null);
         fnd_message.set_token('WORKERNAME', p_employee_rec.PER_first_name || ' ' || p_employee_rec.PER_last_name);
         p_err_text := fnd_message.get;
        RETURN;
      when others then
         p_err_code := 1;
         fnd_message.clear;
         fnd_message.set_name ('XXOBJT', 'XXHR_SF2ORA_ERROR_GENERAL');
         fnd_message.set_token('ERRPROCEDURE', 'Update Data');
         fnd_message.set_token('ORAERR', substr(SQLERRM, 1, 255));
         fnd_message.set_token('ORAERR2', NULL);
         fnd_message.set_token('ERRCODE', 99);
         fnd_message.set_token('WORKERNAME', p_employee_rec.PER_first_name || ' ' || p_employee_rec.PER_last_name);
         p_err_text := fnd_message.get;
        RETURN;
    END;

  -- CHG0042593 - Throw error in case of data change (in j.i.) is earlier to employment information hire date (retroactive change)
    if p_employee_rec.CNG_START_DATE < p_employee_rec.EMP_hire_date then
        fnd_message.CLEAR;
       fnd_message.set_name ('XXOBJT', 'XXHR_SF2ORA_ERROR_GENERAL');
       fnd_message.set_token('ERRPROCEDURE', 'Data_Change');
       fnd_message.set_token('ERRCODE', '99');
       fnd_message.set_token('ORAERR', 'Retroactive change previous to a later hire date');
       fnd_message.set_token('ORAERR2', null);
       fnd_message.set_token('WORKERNAME', p_employee_rec.PER_first_name || ' ' || p_employee_rec.PER_last_name);
        p_err_text := fnd_message.get;
        p_err_code := 1;
        return;

    end if;

    --xx_debug('step 1');
    -- Get and map employment type used by SF/Compass Record ( mapping received from rachel)
    l_hr_person_type := map_sf_to_HR_person_Type(p_employee_rec.ASG_sf_employee_class);
    -- look for the Employment type for the interface.
    --xx_debug('step 2');
    begin

      --xx_debug('step 3');
      -- Map Received Oracle Person type to oracle system person type (and type ID).
      select pert.person_type_id, pert.system_person_type
        into l_sf_person_Type_id, l_emp_type_sf
        from per_person_types pert
       where pert.user_person_type = l_hr_person_type;

      --xx_debug('step 4');
    exception
      when others then

         fnd_message.clear;
         fnd_message.set_name ('XXOBJT', 'XXHR_SF2ORA_ERROR_PERTYPE_UNK');
         fnd_message.set_token('ERRPROCEDURE', 'Update Person');
         fnd_message.set_token('ERRCODE', '0');
         fnd_message.SET_TOKEN('SFPT', l_hr_person_type || ' (' || p_employee_rec.ASG_sf_employee_class || ')');
         fnd_message.SET_TOKEN('ADDTEXT', null);
         fnd_message.set_token('WORKERNAME', p_employee_rec.PER_first_name || ' ' || p_employee_rec.PER_last_name);
         p_err_text := fnd_message.get;

        p_err_code := 1;
        return;
    end;

    --xx_debug('step 5');
    -- Check if employment code/type is known type in the first place
    if l_emp_type_sf not in ('CWK', 'EMP') then
         p_err_code := 1;

         fnd_message.clear;
         fnd_message.set_name ('XXOBJT', 'XXHR_SF2ORA_ERROR_PERTYPE_UNK');
         fnd_message.set_token('ERRPROCEDURE', 'Update Person');
         fnd_message.set_token('ERRCODE', '0');
         fnd_message.SET_TOKEN('SFPT', l_hr_person_type || ' (' || p_employee_rec.ASG_sf_employee_class || ')');
         fnd_message.SET_TOKEN('ADDTEXT', 'Or not a EMP/CWK Employee type');
         fnd_message.set_token('WORKERNAME', p_employee_rec.PER_first_name || ' ' || p_employee_rec.PER_last_name);
         p_err_text := fnd_message.get;

      return;
    end if;

    --xx_debug('step 6');
    -- Check for mismatch between last employment type SF vs HR oracle.
    if l_emp_type_sf <> l_ora_type_hr then
         p_err_code := 1;
          fnd_message.clear;
         fnd_message.set_name ('XXOBJT', 'XXHR_SF2ORA_ERROR_PTYPE_INVCHG'); -- was : general (13-Mar)
         fnd_message.set_token('ERRPROCEDURE', 'Update Person');
         fnd_message.set_token('ERRCODE', '99');
         fnd_message.set_token('WORKERNAME', p_employee_rec.PER_first_name || ' ' || p_employee_rec.PER_last_name);
         p_err_text := fnd_message.get;
      return;
    end if;
    --xx_debug('step 7');
    -- need to cancel hire ? Yuval be able to provide event reason ? -- moved to seperate handling.
    /*IF l_ORA_ter_date is  null -- last period is not terminated in HR
    and p_employee_rec.EMP_termination_date is not null  -- SF/Compass period is closed
    and l_ORA_hire_date > p_employee_rec.EMP_termination_date then -- Ora latest hire date is larger than SF Termination date
         p_err_code := 1;
         p_err_text := l_proc_name || 'Please cancel hire manually in ORA HR';
         return;
    end if;*/


    -- Check if changes in Employment information. if yes, than check employment info periods. if not, cont.
   /* if p_employee_rec.Sub_event = 'XXHR_EMPLOYMENT_INFORMATION' then */

                  --xx_debug('step 8:9 - Check for termination changes ?');
                  -- Check for Termination date change
/*                  xx_debug(l_ORA_ter_date);
                  xx_debug(p_employee_rec.EMP_termination_date);*/

                  IF ((L_ORA_TER_DATE IS NOT NULL -- CLOSED PERIOD
                     AND P_EMPLOYEE_REC.EMP_TERMINATION_DATE IS NOT NULL -- CLOSED PERIOD
                     AND L_ORA_TER_DATE <> P_EMPLOYEE_REC.EMP_TERMINATION_DATE) OR -- Termination date changed

                     (L_ORA_TER_DATE IS NOT NULL -- CLOSED PERIOD
                     AND P_EMPLOYEE_REC.EMP_TERMINATION_DATE IS NULL -- NOT CLOSED PERIOD
                     and P_EMPLOYEE_REC.EMP_hire_date /* SF Hire Date*/ <  L_ORA_TER_DATE -- Actual Reverse Termination
                     -- Reverse Termination
                     )

                     ) THEN

                     /*
                     if TRUNC(P_EMPLOYEE_REC.EMP_hire_date) >= TRUNC( L_ORA_TER_DATE) THEN
                       -- Hire date in SF > Termination in ORA to be reversed
                       -- This means missing rehire event
                       -- Raise Error
                       -- Would result (if not done) in wrongfully done reverse termination !


                        p_err_code := 1;
                        fnd_message.CLEAR;
                        fnd_message.set_name ('XXOBJT', 'XXHR_SF2ORA_ERROR_GENERAL');
                        fnd_message.set_token('ERRPROCEDURE', 'Reverse Termination (Data Change)');
                        fnd_message.set_token('ERRCODE', '99');
                        fnd_message.set_token('ORAERR', 'Unexpected error : Reverse termination canceled - Missing Hire');
                        fnd_message.set_token('ORAERR2', substr(SQLERRM, 1, 255));
                        fnd_message.set_token('WORKERNAME', p_employee_rec.PER_first_name || ' ' || p_employee_rec.PER_last_name);
                         p_err_text := fnd_message.get;
                         return;
                     END IF;
                     */
                    CALL_TERMINATION_CNG(P_EMPLOYEE_REC => P_EMPLOYEE_REC,
                                         P_ERR_CODE     => P_ERR_CODE,
                                         P_ERR_TEXT     => P_ERR_TEXT);
                    IF P_ERR_CODE = 0 THEN
                     return; -- CHG0043076 danm 21-May-2018, if termination date changes, exit and do nothing else.
                    ELSE
                      /* Actual error trying to change termination date */
                      null;
                      P_ERR_CODE := 1;
                     -- P_ERR_TEXT set by the call_Termination_chg
                        RETURN;
                    END IF;
                  END IF;

                  --xx_debug('step 10');
                  -- get again latest ppf date, as it may have changed (above steps)
                  l_ppf_date := get_most_recent_ppf_date(l_employee_id);

                 -- xx_debug('step 11');

                  -- *Change* hire date actions
                  -- check for changes in first working date - currently  as agreed with rachel enabled only for first ever period.
                  --xx_debug(' Hire date in Ora : ' ||  TO_CHAR(l_ORA_hire_date, 'dd-mon-yyyy'));
                  --xx_debug(' Hire date in SF : ' ||   TO_CHAR(p_employee_rec.EMP_hire_date, 'dd-mon-yyyy'));

              -- no point in checking person changes - as a hire / rehire will create a break in person anyway and than its a break that's not really a break ..
              -- Check number of changes in PPF after current oracle Hire Date
                  select count(1)
                    into l_changes_in_person
                    from per_all_people_f ppf
                   where nvl(ppf.employee_number, ppf.npw_number) = l_employee_id
                     and ppf.effective_start_date > l_ORA_hire_date;

              -- Check number of changes in PFA   after current oracle Hire Date
                  select count(1)
                    into l_changes_in_assignment
                    from per_all_assignments_f pfa
                   where pfa.person_id = l_ora_person_id
                     and pfa.effective_start_date > l_ORA_hire_date;

              -- Check number of changes in person_types  after current oracle Hire Date

                  select count(1)
                    into l_changes_in_pertypes
                    from per_person_Type_usages_f pft, per_person_types pert
                   where pft.person_id = l_ora_person_id
                     and pft.effective_start_date > l_ORA_hire_date
                     and pert.person_type_id = pft.person_type_id
                     and pert.system_person_type in ('EMP', 'CWK');

              -- Search for previous (if any) termination date.
                begin
                with periods as
                   (select 'EMP' EMPTYPE,
                           per.period_of_service_id period_id,
                           per.person_id,
                           per.date_start,
                           per.actual_termination_date,
                           per.last_standard_process_date,
                           per.CREATION_DATE,
                           per.object_version_number,
                           per.period_of_service_id
                      from per_periods_of_service per
                    UNION
                    select 'CWK' EMPTYPE,
                           ser.period_of_placement_id period_id,
                           ser.person_id,
                           ser.date_start,
                           ser.actual_termination_date,
                           ser.last_standard_process_date,
                           ser.CREATION_DATE,
                           ser.object_version_number,
                           ser.period_of_placement_id
                      from per_periods_of_placement ser
                    )
                select max(actual_termination_date)
                into l_ORA_prev_ter_date
                from periods per
                where per.date_start < l_ORA_hire_date
                and per.person_id = l_ora_person_id;
                exception
                   when no_data_found then
                      l_ORA_prev_ter_date := null;
                 end;



              -- if change in hire date AND no changes in PPf, pfa, per_types AND previous termination (if any) lower than new hire date, proceed with change hire date.
/*                 xx_debug('p_employee_rec.EMP_hire_date : ' || p_employee_rec.EMP_hire_date);
                 xx_debug('l_ORA_hire_date : ' || l_ORA_hire_date);
                 xx_debug('l_changes_in_person : ' || l_changes_in_person);
                 xx_debug('l_changes_in_assignment : ' || l_changes_in_assignment);
                 xx_debug('l_changes_in_pertypes : ' || l_changes_in_pertypes);
                 xx_debug('l_ORA_prev_ter_date : ' || l_ORA_prev_ter_date);*/

                   if trunc(p_employee_rec.EMP_hire_date) <> trunc(l_ORA_hire_date) then

                         if (l_changes_in_person <= 1 and l_changes_in_assignment <= 1 and
                          l_changes_in_pertypes <= 1 and nvl(l_ORA_prev_ter_date, hr_general.START_OF_TIME) < p_employee_rec.EMP_hire_date ) then

                        -- need to change first working date for that employee
                        if l_ORA_ter_date is not null then
                          -- you can not change first working date of a terminated period !!
                          p_err_code := 1;
                          fnd_message.CLEAR;
                       fnd_message.set_name ('XXOBJT', 'XXHR_SF2ORA_ERROR_CNGHIRE_TER');
                       fnd_message.set_token('ERRPROCEDURE', 'Hire date change');
                       fnd_message.set_token('ERRCODE', '99');
                       fnd_message.set_token('WORKERNAME', p_employee_rec.PER_first_name || ' ' || p_employee_rec.PER_last_name);
                       p_err_text := fnd_message.get;

              --            p_err_text := l_proc_name ||
              --                          'Rehire missing or did not pass due to error - you can not change hire date of a terminated period';
                          return;
                        else

                          if l_ora_type_hr = 'EMP' then
                            -- change first working date for employee
                            begin
                              --xx_debug('change emp hire date');

                              hr_change_start_date_api.update_start_date(p_validate       => false,
                                                                         p_person_id      => l_ORA_person_id,
                                                                         p_old_start_date => l_ORA_hire_date,
                                                                         p_new_start_date => p_employee_rec.EMP_hire_date,
                                                                         p_update_type    => 'E',
                                                                         p_warn_ee        => l_warn_ee);

                              -- commit;
                              p_err_code := 0;
                              return;  -- in case of change in hire date, only do this action.
                            exception
                              when others then
/*                                p_err_code := 1;
                               fnd_message.CLEAR;
                               fnd_message.set_name ('XXOBJT', 'XXHR_SF2ORA_ERROR_GENERAL');
                               fnd_message.set_token('ERRPROCEDURE', 'Hire date change');
                               fnd_message.set_token('ERRCODE', '99');
                               fnd_message.set_token('ORAERR', 'Error changing first working date - ' || sqlerrm);
                               fnd_message.set_token('ORAERR2', null);
                               fnd_message.set_token('WORKERNAME', p_employee_rec.PER_first_name || ' ' || p_employee_rec.PER_last_name);
                                p_err_text := fnd_message.get;
                                return;

*/
                              null;
                              -- CHG0043076 : 21-May-2018 danm : In case of hire date change failure, do nothing and attempt to continue anyway.
                              end;

                          else
                            -- Change first working date for Contingent.
                            begin
                              --xx_debug('change CWK hire date');
                              hr_change_start_date_api.update_start_date(p_validate       => false,
                                                                         p_person_id      => l_ORA_person_id,
                                                                         p_old_start_date => l_ORA_hire_date,
                                                                         p_new_start_date => p_employee_rec.emp_hire_date,
                                                                         p_update_type    => 'C',
                                                                         p_warn_ee        => l_warn_ee);
                             p_err_code := 0;
                             return;             -- in case of change in hire date, only do this action.
                              --commit;
                            exception
                              when others then

                               /* p_err_code := 1;
                                fnd_message.CLEAR;
                               fnd_message.set_name ('XXOBJT', 'XXHR_SF2ORA_ERROR_GENERAL');
                               fnd_message.set_token('ERRPROCEDURE', 'Hire date change');
                               fnd_message.set_token('ERRCODE', '99');
                               fnd_message.set_token('ORAERR', 'Error changing first working date - ' || sqlerrm);
                               fnd_message.set_token('ORAERR2', null);
                               fnd_message.set_token('WORKERNAME', p_employee_rec.PER_first_name || ' ' || p_employee_rec.PER_last_name);
                                  p_err_text := fnd_message.get;
                                return;*/

                              null;
                              -- CHG0043076 : 21-May-2018 danm : In case of hire date change failure, do nothing and attempt to continue anyway.

                            end;

                          end if;
                        end if;
                      elsif (l_changes_in_person > 1 or
                            l_changes_in_assignment > 1 or l_changes_in_pertypes > 1) then
                            null;
                                                     /* -- CHG0042593 -  ignore change in hire date if results in error */

                 --       p_err_code := 1;
              --          p_err_text := l_proc_name || 'Change hire can not be done in Oracle - Future Assignment/Person/Person Type changes';
                     --    fnd_message.CLEAR;
                      --   fnd_message.set_name ('XXOBJT', 'XXHR_SF2ORA_ERROR_CNGHIRE_EVT');
                       --  fnd_message.set_token('ERRPROCEDURE', 'Change Hire Date');
                        -- fnd_message.set_token('ERRCODE', '03');
                         --fnd_message.set_token('WORKERNAME', p_employee_rec.PER_first_name || ' ' || p_employee_rec.PER_last_name);
                        -- p_err_text := fnd_message.get;
                       -- return;
                      elsif (l_ORA_prev_ter_date is not null and l_ORA_prev_ter_date >= p_employee_rec.EMP_hire_date) then
                         --p_err_code := 1;
                         /* ignore change in hire date if results in error */
                         null;

                         --fnd_message.set_name ('XXOBJT', 'XXHR_SF2ORA_ERROR_CNGHIRE_BTER');
                         --fnd_message.set_token('ERRPROCEDURE', 'Hire date change');
                         --fnd_message.set_token('ERRCODE', '99');
              --           fnd_message.set_token('ORAERR', 'Error changing first working date - ' || sqlerrm);
              --            fnd_message.set_token('ORAERR2', null);
                         --fnd_message.set_token('WORKERNAME', p_employee_rec.PER_first_name || ' ' || p_employee_rec.PER_last_name);

                        -- p_err_text := fnd_message.get;
              --          p_err_text := l_proc_name || 'Change hire can not be done in Oracle - You can not move a hire before a previous termination';
                          --              -- CHG0042593 -  Ignore change in Hire Date.
--                        return;
                       end if;
                      end if;

                  --xx_debug('step 13');


   /*  end if;*/

/*    if p_employee_rec.CNG_START_DATE < l_ORA_hire_date then
 -- check if change is for a terminated period (already handled termination/rehire at this stage)
      p_err_code := 0;
      return;
    end if;
*/
    -- bypass for SOA Issue ! at times, null record inserted on hire change date;
    if p_employee_rec.Per_gender is null or
       p_employee_rec.per_last_name is null then
      p_err_code := 0;
      return;
    end if;

    --xx_debug('step 14');

    -- Which assignment type to look for ? (C/E) --> not really needed in SSys setup, as you can not have two at the same time in current setup.
    select decode(l_emp_type_sf, 'EMP', 'E', 'CWK', 'C', 'X')
      into l_lookfor_ass_type
      from dual;

    --xx_debug(' l_emp_type_sf : ' || l_emp_type_sf);
    --xx_debug(' l_lookfor_ass_type : ' || l_lookfor_ass_type);
    --xx_debug(' l_ORA_person_id : ' || l_ORA_person_id);

    -- now after we did a reverse termination (if needed) we can fetch last assignment record for the employee.
    -- otherwise the 'last assignment' would be the incorrect one.

 -- CHG0042593 -  Take non terminate assignment record. (not by active assignment/cwk)
    --xx_debug('step 15');
    select pfa.*
      into l_assignment_rec
      from per_all_assignments_f pfa
         ,per_assignment_status_types pft
     where pfa.person_id = l_ORA_person_id
       and pfa.assignment_type in (l_lookfor_ass_type) -- not taking applicant records, when they exist (they do)
        and pft.assignment_status_type_id = pfa.assignment_status_type_id
        and pft.per_system_status not in ('TERM_ASSIGN')
       and pfa.effective_start_date =
           (select max(pfa1.effective_start_date)
              from per_all_assignments_f pfa1
                 ,per_assignment_status_types pft
             where 1=1
               and pft.assignment_status_type_id = pfa1.assignment_status_type_id
               and pft.per_system_status not in ('TERM_ASSIGN')
               and pfa.person_id = pfa1.person_id
               and pfa1.assignment_type in (l_lookfor_ass_type));

    --xx_debug('step 16');


    -- same for getting last person record. employment periods are already aligned - we have just aligned them.


-- CHG0042593 - Get active/current person record to be updated.
-- Fetch person record to be changed
    begin


-- TRY to get the first if futrure hire / rehire (first person record after today)
       select *
      into p_people_rec
      from per_all_people_f ppf
     where ppf.person_id = l_ORA_person_id
       and ppf.effective_start_date =
           (select MIN(ppf1.effective_start_date)
              from per_all_people_F ppf1
             where ppf1.person_id = ppf.person_id
                   AND PPF1.EFFECTIVE_START_DATE >=  l_ORA_hire_date  -- CHG0043076 : danm, 21-May-2018 Correct logic to getch person record for future re/hire
                  and ppf1.effective_start_date > sysdate );          -- CHG0043076 : danm, 21-May-2018 Correct logic to getch person record for future re/hire

     exception
        when no_Data_found then
         -- if not exist, fetch current record from ppf
          select *
      into p_people_rec
      from per_all_people_f ppf
     where ppf.person_id = l_ORA_person_id
       and sysdate between ppf.effective_start_date and ppf.effective_end_date ;


     end;


     -- get the last (ever) per_all_people record for the employee

        select *
      into p_people_rec_last
      from per_all_people_f ppf
     where ppf.person_id = l_ORA_person_id
       and ppf.effective_start_date =
           (select max(ppf1.effective_start_date)
              from per_all_people_F ppf1
             where ppf1.person_id = ppf.person_id);

    --xx_debug('step 17');

    -- Check if (translated) SF Person type ID is currently active for the person. there is only one 'active'  type every time in SSYS Setup..
    begin
      select '1'
        into l_validate_emp_type_cng
        from dual
       where l_sf_person_Type_id in
             (select pft.person_type_id
                from per_person_Type_usages_f pft, per_person_types pert
               where pft.person_id = l_ORA_person_id
                 and p_employee_rec.CNG_START_DATE between
                     pft.effective_start_date and pft.effective_end_date
                 and pert.person_type_id = pft.person_type_id
                 and pert.system_person_type in ('EMP', 'CWK'));
    exception
      when no_Data_found then
        l_validate_emp_type_cng := 0;
      when others then
        p_err_code := 1;

        fnd_message.CLEAR;
           fnd_message.set_name ('XXOBJT', 'XXHR_SF2ORA_ERROR_GENERAL');
           fnd_message.set_token('ERRPROCEDURE', 'Change person type');
           fnd_message.set_token('ERRCODE', '99');
           fnd_message.set_token('ORAERR', 'Unexpected error : too many person types ?');
            fnd_message.set_token('ORAERR2', substr(SQLERRM, 1, 255));
           fnd_message.set_token('WORKERNAME', p_employee_rec.PER_first_name || ' ' || p_employee_rec.PER_last_name);
              p_err_text := fnd_message.get;

      --  p_err_text := l_proc_name ||
        --              ;  -- XXHR_SF2HR_ERROR_GENERAL
        return;
    end;

    --xx_debug('step 18');
    if l_validate_emp_type_cng = 0 then -- current Person type is not what arrived from SF
      begin
        call_update_person_type(p_person_id          => l_ORA_person_id,
                                p_effective_date     => p_employee_rec.CNG_START_DATE,
                                p_new_person_type_id => l_sf_person_Type_id,
                                p_err_future         => l_update_emptype_future_Err);
        if l_update_emptype_future_Err = 1 then
          p_err_code := 1;
                 fnd_message.CLEAR;
                 fnd_message.set_name ('XXOBJT', 'XXHR_SF2ORA_ERROR_FUT_CNG');
                 fnd_message.set_token('ERRPROCEDURE', 'Personal info change');
                 fnd_message.set_token('ERRCODE', '99');
                 fnd_message.set_token('ADDFTCNGTXT', 'Person type');
                 fnd_message.set_token('WORKERNAME', p_employee_rec.PER_first_name || ' ' || p_employee_rec.PER_last_name);
                 p_err_text := fnd_message.get;
          return;
        end if;
      exception
        when others then
          p_err_code := 1;
                   fnd_message.CLEAR;
                 fnd_message.set_name ('XXOBJT', 'XXHR_SF2ORA_ERROR_GENERAL');
                 fnd_message.set_token('ERRPROCEDURE', 'Person type change');
                 fnd_message.set_token('ERRCODE', '99');
                 fnd_message.set_token('ORAERR', 'Error Updating person type - ' ||    substr(sqlerrm,1, 255));
                 fnd_message.set_token('WORKERNAME', p_employee_rec.PER_first_name || ' ' || p_employee_rec.PER_last_name);
                 p_err_text := fnd_message.get;

          return;
      end;
    end if;
    -- check for person type changes
    --xx_debug('step 19');

    -- Check for changes in per_all_people_f (and only if there are changes to in ..)
    if (p_people_rec.last_name <> p_employee_rec.per_last_name or
       p_people_rec.first_name <> p_employee_rec.per_first_name or
       nvl(p_people_rec.date_of_birth, hr_general.END_OF_TIME) <>
       nvl(p_employee_rec.per_date_of_birth, hr_general.END_OF_TIME) or
       p_people_rec.sex <> p_employee_rec.Per_gender or
       nvl(p_people_rec.email_address, 'noemail') <>
       nvl(p_employee_rec.per_email, 'noemail') or
       p_people_rec.person_type_id <> l_sf_person_Type_id) and
       p_employee_rec.per_last_name is not null and
       p_employee_rec.Per_gender is not null

    --      or l_validate_emp_type_cng = 0
     then
      --xx_debug('step 19.1');
  -- p_people_rec holds in this point the last relevant people rec.

      -- person update is from the most recent (current) or first (if future hire)
      -- Check if there is a change in per_all_people_f (which is current or first in the future in the first place)

      if trunc(p_people_rec.effective_start_Date) < trunc(p_people_rec_last.effective_start_date) then
        p_err_code := 1; -- error out on

        fnd_message.CLEAR;
                 fnd_message.set_name ('XXOBJT', 'XXHR_SF2ORA_ERROR_FUT_CNG');
                 fnd_message.set_token('ERRPROCEDURE', 'Change Personal Data');
                 fnd_message.set_token('ERRCODE', '04');
                 fnd_message.set_token('ADDFTCNGTXT', 'Personal');
                 fnd_message.set_token('WORKERNAME', p_employee_rec.PER_first_name || ' ' || p_employee_rec.PER_last_name);
                 p_err_text := fnd_message.get;

--        p_err_text := l_proc_name || 'Person Future Changes Exist';
        return;
    /*  elsif trunc(p_people_rec.effective_start_date) < trunc(p_employee_rec.CNG_START_DATE) then
        l_update_type := 'UPDATE';*/
      else
        l_update_type := 'CORRECTION';  -- -- CHG0042593 -  Always correction - from the date of the ppf record.
      end if;

      l_ovn     := p_people_rec.object_version_number;
      l_out_err := null;

      -- to be used on re-hire, update using normal update (update/correction if needed)
      update_person(p_update_mode     => l_update_type,
                    p_employee_rec    => p_employee_rec,
                    p_person_id       => l_ORA_person_id,
                    sf_person_type_id => l_sf_person_Type_id,
                    p_ovn             => l_ovn,
                    p_update_date     => trunc(p_people_rec.effective_start_date),  -- CHG0042593 - Always correction
                    p_out_err         => l_out_err);

      if l_out_err is not null then
        ROLLBACK;
        p_err_code := 1; -- error out on

         fnd_message.CLEAR;
                 fnd_message.set_name ('XXOBJT', 'XXHR_SF2ORA_ERROR_GENERAL');
                 fnd_message.set_token('ERRPROCEDURE', 'Person info change');
                 fnd_message.set_token('ERRCODE', '99');
                 fnd_message.set_token('ORAERR', 'Error updating person information');
                 fnd_message.set_token('ORAERR2', l_out_err); -- is sqlerrm (If any)
                 fnd_message.set_token('WORKERNAME', p_employee_rec.PER_first_name || ' ' || p_employee_rec.PER_last_name);
                 p_err_text := fnd_message.get;

        return;
      end if;
    --else
      --xx_debug('step 19.2');
    end if;

    --xx_debug('step 20');
    -- calculate actual HR values for incoming Compass Assignment information

    -- supervisor ID - Check if exists
     -- CHG0042593 - in case 'no manager' received, use 'current' (API Instruction)
    if p_employee_rec.ASG_manager = 'NO_MANAGER' then
     l_supervisor_id := hr_api.g_number;
    else

      select count(1)
        into l_supervisor_id
        from per_all_people_f ppf
       where nvl(ppf.employee_number, ppf.npw_number) = l_manager_id;

   if l_supervisor_id = 0 then
        p_err_code := 1; -- error out on
                 fnd_message.CLEAR;
                 fnd_message.set_name ('XXOBJT', 'XXHR_SF2ORA_SUPER_NOTEXIST');
                 fnd_message.set_token('ERRPROCEDURE', 'Update Assignment');
                 fnd_message.set_token('ERRCODE', '08');
                 fnd_message.set_token('ACTIVE_EXIST', 'does not exist');
                 fnd_message.set_token('SUPERID', l_manager_id);
                 fnd_message.set_token('WORKERNAME', p_employee_rec.PER_first_name || ' ' || p_employee_rec.PER_last_name);
                 p_err_text := fnd_message.get;
        return;
    end if;

    begin  -- CHG0042593 - Take assignment ignoring terminate assignment
      select ppf.person_id
        into l_supervisor_id
        from per_all_people_f ppf, per_all_assignments_f pfa,  per_assignment_status_types pft
       where nvl(ppf.employee_number, ppf.npw_number) = l_manager_id
         and p_employee_rec.CNG_start_date between ppf.effective_start_date and
             ppf.effective_end_date
         and p_employee_rec.CNG_start_date between pfa.effective_start_date and
             pfa.effective_end_date
         and pfa.assignment_type in ('E', 'C')
               and pft.assignment_status_type_id = pfa.assignment_status_type_id
               and pft.per_system_status not in ('TERM_ASSIGN')
         and trunc(p_employee_rec.CNG_START_DATE) >= trunc(ppf.start_date) -- employee change to manager is after manager start date
         and pfa.person_id = ppf.person_id
         and rownum = 1;
    exception
      when no_Data_found then
        p_err_code := 1; -- error out on
                 fnd_message.CLEAR;
                 fnd_message.set_name ('XXOBJT', 'XXHR_SF2ORA_SUPER_NOTEXIST');
                 fnd_message.set_token('ERRPROCEDURE', 'Update Assignment');
                 fnd_message.set_token('ERRCODE', '09');
                 fnd_message.set_token('ACTIVE_EXIST', 'Is not active');
                 fnd_message.set_token('SUPERID', l_manager_id);
                 fnd_message.set_token('WORKERNAME', p_employee_rec.PER_first_name || ' ' || p_employee_rec.PER_last_name);
                 p_err_text := fnd_message.get;
        return;
    end;
    end if;
    --xx_debug('step 21');
    -- Grade translation
    begin
      SELECT grds.grade_id
        into l_grade_id
        FROM FND_FLEX_VALUES_VL    v,
             fnd_flex_value_sets   vsts,
             per_grades            grds,
             per_grade_definitions pgd
       WHERE 1 = 1
         and (v.FLEX_VALUE_SET_ID = vsts.flex_value_set_id)
         and vsts.flex_value_set_name = 'XXHR_COMPAS_GRADE_MAP'
         and nvl(v.ENABLED_FLAG, 'N') = 'Y'
         and p_employee_rec.CNG_START_DATE between
             nvl(v.START_DATE_ACTIVE, p_employee_rec.CNG_START_DATE) and
             nvl(v.END_DATE_ACTIVE, p_employee_rec.CNG_START_DATE)
         and grds.name(+) = v.Description
         and v.FLEX_VALUE = p_employee_rec.ASG_job_level
         and pgd.grade_definition_id = grds.grade_definition_id;
    exception
      when others then
        p_err_code := 1; -- error out on

                 fnd_message.CLEAR;
                 fnd_message.set_name ('XXOBJT', 'XXHR_SF2ORA_GRADE_NOTEXIST');
                 fnd_message.set_token('ERRPROCEDURE', 'Update Assignment');
                 fnd_message.set_token('ERRCODE', '10');
                 fnd_message.set_token('GRADE', p_employee_rec.ASG_job_level);
                 fnd_message.set_token('WORKERNAME', p_employee_rec.PER_first_name || ' ' || p_employee_rec.PER_last_name);
                 p_err_text := fnd_message.get;

        return;
    end;

    --xx_debug('ASG_finance_company  ' || p_employee_rec.ASG_finance_company);
    --xx_debug('ASG_COMPANY  ' || p_employee_rec.ASG_company);




    get_code_comb_id(p_finance_company => p_employee_rec.ASG_finance_company,
                     p_company         => p_employee_rec.ASG_company,
                     p_finance_dept    => p_employee_rec.ASG_finance_dept,
                     p_finance_account => p_employee_rec.ASG_finance_account,
                     p_out_ccid        => l_default_code_combination,
                     p_out_ledger_id   => l_ledger_id,
                     p_out_ledger => l_ledger,
                     P_OUT_ccid_vc => l_code_combination
                     );

 if p_employee_rec.ASG_finance_company is not null and l_ledger_id is null then
                  p_err_code := 1; -- error out on
                 fnd_message.CLEAR;
                 fnd_message.set_name ('XXOBJT', 'XXHR_SF2ORA_COMPANY_NOTEXIST');
                 fnd_message.set_token('ERRPROCEDURE', 'Update Assignment');
                 fnd_message.set_token('ERRCODE', '30');
                 fnd_message.set_token('SFCOMPANY', p_employee_rec.ASG_finance_company);
                 fnd_message.set_token('WORKERNAME', p_employee_rec.PER_first_name || ' ' || p_employee_rec.PER_last_name);
                 p_err_text := fnd_message.get;
                 return;
  end if;
    --xx_debug('l_ledger_id  ' || l_ledger_id);
    --xx_debug('l_default_code_combination  ' || l_default_code_combination);

    /* := null;  -- 2282 for stratasys US. for ObjIL, 2021.
       := null; -- get_code_comb_id('ObjIL', p_employee_rec.ASG_finance_company, p_employee_rec.ASG_finance_dept, p_employee_rec.ASG_finance_account);
    */
    if l_default_code_combination = -1 then
      p_err_code := 1; -- error out on
         fnd_message.CLEAR;
                 fnd_message.set_name ('XXOBJT', 'XXHR_SF2ORA_ERROR_GENERAL');
                 fnd_message.set_token('ERRPROCEDURE', 'Person info change');
                 fnd_message.set_token('ERRCODE', '99');
                 fnd_message.set_token('ORAERR', 'Invalid code combination');
                 fnd_message.set_token('ORAERR2', '(' || l_code_combination || ' is not valid for Ledger '  ||  l_ledger || ')');
                 fnd_message.set_token('WORKERNAME', p_employee_rec.PER_first_name || ' ' || p_employee_rec.PER_last_name);
                 p_err_text := fnd_message.get;
                 return;
    elsif l_default_code_combination = -2 then
      p_err_code := 1; -- error out on
         fnd_message.CLEAR;
                 fnd_message.set_name ('XXOBJT', 'XXHR_SF2ORA_ERROR_GENERAL');
                 fnd_message.set_token('ERRPROCEDURE', 'Person info change');
                 fnd_message.set_token('ERRCODE', '99');
                 fnd_message.set_token('ORAERR', 'Chart of account Could not be identified for Finance Company and Ledger combination');
                 fnd_message.set_token('ORAERR2', null);
                 fnd_message.set_token('WORKERNAME', p_employee_rec.PER_first_name || ' ' || p_employee_rec.PER_last_name);
                 p_err_text := fnd_message.get;
                 return;
    end if;


    -- get location Code
    begin
      SELECT t_loc.location_id
        into l_location_id
        from HR_LOCATIONS_ALL t_loc
       where t_loc.attribute3 = p_employee_rec.ASG_location_SF_CODE;
    exception
      when no_data_found then
        p_err_code := 1; -- error out on
                 fnd_message.CLEAR;
                 fnd_message.set_name ('XXOBJT', 'XXHR_SF2ORA_LOCATION_NOTEXIST');
                 fnd_message.set_token('ERRPROCEDURE', 'Update Assignment');
                 fnd_message.set_token('ERRCODE', '07');
                 fnd_message.set_token('SFLOC', p_employee_rec.ASG_location_SF_CODE);
                 fnd_message.set_token('WORKERNAME', p_employee_rec.PER_first_name || ' ' || p_employee_rec.PER_last_name);
                 p_err_text := fnd_message.get;
        return;
      when others then
        p_err_code := 1; -- error out on

                 fnd_message.CLEAR;
                 fnd_message.set_name ('XXOBJT', 'XXHR_SF2ORA_LOCATION_NOTEXIST');
                 fnd_message.set_token('ERRPROCEDURE', 'Update Assignment');
                 fnd_message.set_token('ERRCODE', '07');
                 fnd_message.set_token('SFLOC', p_employee_rec.ASG_location_SF_CODE);
                 fnd_message.set_token('WORKERNAME', p_employee_rec.PER_first_name || ' ' || p_employee_rec.PER_last_name);
                 p_err_text := fnd_message.get;

        return;
    end;

    -- Check for changes in per_assignment_f

    if nvl(l_assignment_rec.supervisor_id, 0) <> nvl(l_supervisor_id, 0) or
       nvl(l_assignment_rec.set_of_books_id, 0) <> nvl(l_ledger_id, 0) or
       nvl(l_assignment_Rec.Location_Id, 0) <> nvl(l_location_id, 0)
      --      OR NVL(l_assignment_Rec.Set_Of_Books_Id, 0) <> nvl(l_ledger_id, 0)
       or nvl(l_assignment_Rec.Default_Code_Comb_Id, 0) <>
       nvl(l_default_code_combination, 0) or
       nvl(l_assignment_Rec.grade_id, 0) <> nvl(l_grade_id, 0) then

      -- update person info future person cng only if there is actually a change. otherwise, just continue as nothing to change anyway.
      if trunc(l_assignment_rec.effective_start_date) >
         trunc(p_employee_rec.CNG_START_DATE) then
        p_err_code := 1; -- error out on
                 fnd_message.CLEAR;
                 fnd_message.set_name ('XXOBJT', 'XXHR_SF2ORA_ERROR_FUT_CNG');
                 fnd_message.set_token('ERRPROCEDURE', 'Update Assignment');
                 fnd_message.set_token('ERRCODE', '16');
                 fnd_message.set_token('ADDFTCNGTXT', 'Assignment');
                 fnd_message.set_token('WORKERNAME', p_employee_rec.PER_first_name || ' ' || p_employee_rec.PER_last_name);
                 p_err_text := fnd_message.get;
        return;
      end if;

      l_ovn     := l_assignment_rec.object_version_number;
      l_out_err := null;

      if l_ora_type_hr = 'EMP' then
        update_assignment_emp(p_employee_rec          => p_employee_rec,
                              p_assignment_id         => l_assignment_rec.assignment_id,
                              p_people_group_id       => null,
                              p_supervisor_id         => l_supervisor_id,
                              p_location_id           => l_location_id,
                              p_ledger_id             => l_ledger_id,
                              p_grade_id              => l_grade_id,
                              p_code_comb_id          => l_default_code_combination,
                              p_object_version_number => l_ovn,
                              p_effective_date        => trunc(p_employee_rec.CNG_START_DATE),
                              p_out_err               => l_out_err);
      else
        update_assignment_cwk(p_employee_rec          => p_employee_rec,
                              p_assignment_id         => l_assignment_rec.assignment_id,
                              p_people_group_id       => null,
                              p_supervisor_id         => l_supervisor_id,
                              p_location_id           => l_location_id,
                              p_ledger_id             => l_ledger_id,
                              p_grade_id              => l_grade_id,
                              p_code_comb_id          => l_default_code_combination,
                              p_object_version_number => l_ovn,
                              p_effective_date        => trunc(p_employee_rec.CNG_START_DATE),
                              p_out_err               => l_out_err);
      end if;

      if l_out_err is not null then
        ROLLBACK;
        p_err_code := 1; -- error out on
                 fnd_message.CLEAR;
                 fnd_message.set_name ('XXOBJT', 'XXHR_SF2ORA_ERROR_GENERAL');
                 fnd_message.set_token('ERRPROCEDURE', 'Personal info change');
                 fnd_message.set_token('ERRCODE', '99');
                 fnd_message.set_token('ORAERR', 'Error updating Assignment : ' ||  l_out_err);
                          fnd_message.set_token('ORAERR2', NULL);
                 fnd_message.set_token('WORKERNAME', p_employee_rec.PER_first_name || ' ' || p_employee_rec.PER_last_name);
                 p_err_text := fnd_message.get;
        return;
      end if;

    end if;

    p_err_code := 0;
    p_err_text := null;
    --commit;
  exception
    when others then
      p_err_code := 1; -- error out on
                 fnd_message.CLEAR;
                 fnd_message.set_name ('XXOBJT', 'XXHR_SF2ORA_ERROR_GENERAL');
                 fnd_message.set_token('ERRPROCEDURE', 'Personal info change');
                 fnd_message.set_token('ERRCODE', '99');
                 fnd_message.set_token('ORAERR', 'Error updating Assignment : ' ||  SUBSTR(sqlerrm, 1, 255));
         fnd_message.set_token('ORAERR2', NULL);
                 fnd_message.set_token('WORKERNAME', p_employee_rec.PER_first_name || ' ' || p_employee_rec.PER_last_name);
                 p_err_text := fnd_message.get;
      return;

  end call_data_update;

  procedure call_cancel_hire(p_employee_rec  xxhr_emp_rec,
                             p_err_code      out number,
                             p_err_text      out varchar2) is

    l_supervisor_warning         boolean;
    l_recruiter_warning          boolean;
    l_event_warning              boolean;
    l_interview_warning          boolean;
    l_review_warning             boolean;
    l_vacancy_warning            boolean;
    l_requisition_warning        boolean;
    l_budget_warning             boolean;
    l_payment_warning            boolean;
    l_pay_proposal_warning       boolean;
    l_ORA_hire_date              date;
    l_ORA_ter_date               date;
    l_ORA_person_id              number;
    l_ora_type_hr                varchar2(255);
    l_person_org_manager_warning varchar2(255);
    /*  l_ORA_hire_date date;
      l_ORA_ter_date date;
      l_ORA_person_id number;
      l_ora_type_hr varchar2(255);
    */

    l_assignment_rec   per_all_assignments_f%rowtype;
    l_people_rec       per_all_people_f%rowtype;
    l_proc_name        varchar2(255) := 'call_cancel_hire : ';
    l_employee_id      varchar2(255) := truncated_compass_id(p_employee_rec.person_id_external);
    l_lookfor_ass_type VARCHAR2(3);
    l_period_count     number;
    l_ppf_date         date;
  begin

    begin

      l_ppf_date := get_most_recent_ppf_date(l_employee_id);

      with periods as
       (select 'EMP' EMPTYPE,
               per.period_of_service_id period_id,
               per.person_id,
               per.date_start,
               per.actual_termination_date,
               per.last_standard_process_date,
               per.CREATION_DATE,
               per.object_version_number,
               per.period_of_service_id
          from per_periods_of_service per
        UNION
        select 'CWK' EMPTYPE,
               ser.period_of_placement_id period_id,
               ser.person_id,
               ser.date_start,
               ser.actual_termination_date,
               ser.last_standard_process_date,
               ser.CREATION_DATE,
               ser.object_version_number,
               ser.period_of_placement_id
          from per_periods_of_placement ser

        ),
      orderedByRecent as
       (select PER.EMPTYPE,
               ppf.first_name,
               ppf.last_name,
               per.date_start,
               per.actual_Termination_date,
               per.person_id,
               per.Object_Version_Number,
               per.period_id
          from per_all_people_f ppf, periods per
         where 1 = 1
           and nvl(ppf.employee_number, ppf.npw_number) = l_employee_id
           and per.person_id = ppf.person_id
           AND l_ppf_date between ppf.effective_start_date and
               ppf.effective_end_date
         order by per.date_start desc, ppf.effective_start_date desc)
      select sel.date_start,
             sel.actual_Termination_date,
             sel.person_id,
             sel.emptype
        into l_ORA_hire_date,
             l_ORA_ter_date,
             l_ORA_person_id,
             l_ora_type_hr
        from orderedByRecent sel
       where rownum = 1;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        p_err_code := 1;
         fnd_message.clear;
         fnd_message.set_name ('XXOBJT', 'XXHR_SF2ORA_ERROR_EMPNOTEXIST');
         fnd_message.set_token('ERRPROCEDURE', 'Cancel hire');
         fnd_message.set_token('ERRCODE', '13');
         fnd_message.set_token('ERRADDTXT', null);
         fnd_message.set_token('WORKERNAME', p_employee_rec.PER_first_name || ' ' || p_employee_rec.PER_last_name);
         p_err_text := fnd_message.get;
          RETURN;
    END;

    if l_ORA_ter_date is not null then
      p_err_code := 1;
     fnd_message.clear;
         fnd_message.set_name ('XXOBJT', 'XXHR_SF2ORA_ERROR_CANHI_TER');
         fnd_message.set_token('ERRPROCEDURE', 'Cancel hire');
         fnd_message.set_token('ERRCODE', '13');
         fnd_message.set_token('ERRADDTXT', null);
         fnd_message.set_token('WORKERNAME', p_employee_rec.PER_first_name || ' ' || p_employee_rec.PER_last_name);
         p_err_text := fnd_message.get;
      RETURN;
    end if;

    select decode(l_ora_type_hr, 'EMP', 'E', 'CWK', 'C', 'X')
      into l_lookfor_ass_type
      from dual;

   -- CHG0042593 - Take assignment ignoring terminate assignment
    -- Get most recent assignment : Any change in assignment information after hire date will result in failng the cancel hire.
    select pfa.*
      into l_assignment_rec
      from per_all_assignments_f pfa, per_assignment_status_types pft
     where pfa.person_id = l_ORA_person_id
      and pft.assignment_status_type_id = pfa.assignment_status_type_id
--      and pft.per_system_status not in ('TERM_ASSIGN')
       and pfa.assignment_type in (l_lookfor_ass_type) -- not taking applicant records, when they exist (they do)
       and pfa.effective_start_date =
           (select max(pfa1.effective_start_date)
              from per_all_assignments_f pfa1, per_assignment_status_types pft
             where 1=1
            and pft.assignment_status_type_id = pfa1.assignment_status_type_id
               and pfa.person_id = pfa1.person_id
               and pfa1.assignment_type in (l_lookfor_ass_type));

    -- Get most recent person data
    select *
      into l_people_rec
      from per_all_people_f ppf
     where ppf.person_id = l_ORA_person_id
       and ppf.effective_start_date =
           (select max(ppf1.effective_start_date)
              from per_all_people_F ppf1
             where ppf1.person_id = ppf.person_id);




    if trunc(l_people_rec.effective_start_date) >
       trunc(p_employee_rec.CNG_START_DATE) then
      p_err_code := 1; -- error out on
         fnd_message.clear;
         fnd_message.set_name ('XXOBJT', 'XXHR_SF2ORA_ERROR_CANHI_EVT');
         fnd_message.set_token('ERRPROCEDURE', 'Hiring Cancel');
         fnd_message.set_token('ERRCODE', '15');
         fnd_message.set_token('ADDTEXT', '(Person)');
         fnd_message.set_token('WORKERNAME', p_employee_rec.PER_first_name || ' ' || p_employee_rec.PER_last_name);
         p_err_text := fnd_message.get;
--      p_err_text := l_proc_name || 'Person Future Changes Exist';  -- XXHR_SF2HR_ERROR_FUTURE_CHANGE
      return;
    end if;

    if trunc(l_assignment_rec.effective_start_date) >
       trunc(p_employee_rec.CNG_START_DATE) then
      p_err_code := 1; -- error out on
         fnd_message.clear;
         fnd_message.set_name ('XXOBJT', 'XXHR_SF2ORA_ERROR_CANHI_EVT');
         fnd_message.set_token('ERRPROCEDURE', 'Hiring Cancel');
         fnd_message.set_token('ERRCODE', '15');
         fnd_message.set_token('ADDTEXT', '(Assignment)');
         fnd_message.set_token('WORKERNAME', p_employee_rec.PER_first_name || ' ' || p_employee_rec.PER_last_name);
         p_err_text := fnd_message.get;
--      p_err_text := l_proc_name || 'Assignment Future Changes Exist';  -- XXHR_SF2HR_ERROR_FUTURE_CHANGE
      return;
    end if;

    l_ppf_date := get_most_recent_ppf_date(l_employee_id);

    with periods as
     (select 'EMP' EMPTYPE,
             per.period_of_service_id period_id,
             per.person_id,
             per.date_start,
             per.actual_termination_date,
             per.last_standard_process_date,
             per.CREATION_DATE,
             per.object_version_number,
             per.period_of_service_id
        from per_periods_of_service per
      UNION
      select 'CWK' EMPTYPE,
             ser.period_of_placement_id period_id,
             ser.person_id,
             ser.date_start,
             ser.actual_termination_date,
             ser.last_standard_process_date,
             ser.CREATION_DATE,
             ser.object_version_number,
             ser.period_of_placement_id
        from per_periods_of_placement ser

      ),
    orderedByRecent as
     (select PER.EMPTYPE,
             ppf.first_name,
             ppf.last_name,
             per.date_start,
             per.actual_Termination_date,
             per.person_id,
             per.Object_Version_Number,
             per.period_id
        from per_all_people_f ppf, periods per
       where 1 = 1
         and nvl(ppf.employee_number, ppf.npw_number) = l_employee_id
         and per.person_id = ppf.person_id
         AND l_ppf_date between ppf.effective_start_date and
             ppf.effective_end_date
       order by per.date_start desc, ppf.effective_start_date desc)
    select count(1) into l_period_count from orderedByRecent sel;


    if abs(p_employee_rec.CNG_START_DATE - l_ORA_hire_date) > 1 then
      p_err_code := 1;
       fnd_message.clear;
         fnd_message.set_name ('XXOBJT', 'XXHR_SF2ORA_ERROR_MISM_CNGDATE');
         fnd_message.set_token('ERRPROCEDURE', 'Hiring Cancel');
         fnd_message.set_token('ERRCODE', '99');
         fnd_message.set_token('WORKERNAME', p_employee_rec.PER_first_name || ' ' || p_employee_rec.PER_last_name);
         p_err_text := fnd_message.get;
--      p_err_text := 'cancel hire date does not match hire date in Oracle';  -- XXHR_SF2HR_ERROR_CANHIRE_MISMA
      return;
    end if;
    if l_period_count > 1 then

      if l_ora_type_hr = 'EMP' then

        Hr_Cancel_Hire_Api.cancel_hire(p_validate             => false,
                                       p_person_id            => l_ORA_person_id,
                                       p_effective_date       => l_ORA_hire_date,
                                       p_supervisor_warning   => l_supervisor_warning,
                                       p_recruiter_warning    => l_recruiter_warning,
                                       p_event_warning        => l_event_warning,
                                       p_interview_warning    => l_interview_warning,
                                       p_review_warning       => l_review_warning,
                                       p_vacancy_warning      => l_vacancy_warning,
                                       p_requisition_warning  => l_requisition_warning,
                                       p_budget_warning       => l_budget_warning,
                                       p_payment_warning      => l_payment_warning,
                                       p_pay_proposal_warning => l_pay_proposal_warning);
      elsif l_ora_type_hr = 'CWK' then
        Hr_Cancel_Placement_Api.cancel_placement(p_validate            => false,
                                                 p_person_id           => l_ORA_person_id,
                                                 p_effective_date      => l_ORA_hire_date,
                                                 p_supervisor_warning  => l_supervisor_warning,
                                                 p_recruiter_warning   => l_recruiter_warning,
                                                 p_event_warning       => l_event_warning,
                                                 p_interview_warning   => l_interview_warning,
                                                 p_review_warning      => l_review_warning,
                                                 p_vacancy_warning     => l_vacancy_warning,
                                                 p_requisition_warning => l_requisition_warning,
                                                 p_budget_warning      => l_budget_warning,
                                                 p_payment_warning     => l_payment_warning);
      end if;

    else
      -- l_period_count = 0

      hr_person_api.delete_person(p_validate                   => false,
                                  p_effective_date             => l_ORA_hire_date,
                                  p_person_id                  => l_ORA_person_id,
                                  p_perform_predel_validation  => false,
                                  p_person_org_manager_warning => l_person_org_manager_warning);

    end if;
    p_err_code := 0;
  exception
    when others then
      p_err_code := 1;
 fnd_message.clear;
         fnd_message.set_name ('XXOBJT', 'XXHR_SF2ORA_ERROR_GENERAL');
         fnd_message.set_token('ERRPROCEDURE', 'Hiring Cancel');
         fnd_message.set_token('ERRCODE', '99');
         fnd_message.set_token('ORAERR', SUBSTR(sqlerrm, 1, 255));
         fnd_message.set_token('ORAERR2', NULL);
         fnd_message.set_token('WORKERNAME', p_employee_rec.PER_first_name || ' ' || p_employee_rec.PER_last_name);
         p_err_text := fnd_message.get;
  end call_cancel_hire;

  /* procedure : call_Termination
   By : Dan Melamed 22/Jan/2018

   Procedure Purpose :
      Call oracle termination seeded APIs

    In Variables :
       p_employee_rec - row from the updating bulk
       p_source_id  - Sequential ID of update (not used currently)
       p_employee_rec - Bulk of transactions to process into HR
    Out :
       p_person_id - not used at this point.
       p_assignment_id - not used at this point
       p_err_code - Error indication for processing
       p_err_text - actual error received if any.

   Version Control :
      1.0    CR 40116   Dan Melamed       22/Jan/2018
      1.1    CHG0042593   Dan Melamed       08-Apr-2018  Logic Corrections in SF2ORA Interface : Last standatd process date 15 days after termination.
  */

  procedure call_Termination(p_employee_rec  xxhr_emp_rec,
                             p_final_process_flag in boolean default false,
                             p_err_code      out number,
                             p_err_text      out varchar2
                            ) is

    l_ORA_hire_date           date;
    l_ORA_ter_date            date;
    l_ORA_person_id           number;
    l_emp_type                varchar2(3);
    l_ora_period_id           number;

    l_object_version_number   number;

    l_last_std_process_date_out  date;
    l_supervisor_warning         boolean;
    l_event_warning              boolean;
    l_interview_warning          boolean;
    l_review_warning             boolean;
    l_recruiter_warning          boolean;
    l_asg_future_changes_warning boolean;
    l_entries_changed_warning    varchar2(255);
    l_pay_proposal_warning       boolean;
    l_dod_warning                boolean;
    lp_alu_change_warning        varchar2(255);
    l_org_now_no_manager_warning boolean;
    l_finalproc_date             date;
    l_cwk_lsd                    date;
    l_employee_id                varchar2(255) := truncated_compass_id(p_employee_rec.person_id_external);
    l_proc_name                  varchar2(255) := 'API Procedure : Call_Termination - ';
    l_ppf_date                   date;
    l_termination_date           date;

    l_changes_in_person number;
    l_changes_in_assignment number;
    l_changes_in_pertypes number;

  -- CHG0042593 - Termination date (final process) set to termination date + 15 days.
    l_termination_std_ed_Days number := 15;
  begin
    -- termination is on the oracle type, regardless of what I receive from SF.
    begin
    /*
    if p_final_process_flag = true then
           xx_debug(' p_final_process_flag flag is true');

    else
           xx_debug(' p_final_process_flag flag is false');

    end if;
    */
      l_ppf_date := get_most_recent_ppf_date(l_employee_id);

      with periods as
       (select 'EMP' EMPTYPE,
               per.period_of_service_id period_id,
               per.person_id,
               per.date_start,
               per.actual_termination_date,
               per.last_standard_process_date,
               per.CREATION_DATE,
               per.object_version_number,
               per.period_of_service_id
          from per_periods_of_service per
        UNION
        select 'CWK' EMPTYPE,
               ser.period_of_placement_id period_id,
               ser.person_id,
               ser.date_start,
               ser.actual_termination_date,
               ser.last_standard_process_date,
               ser.CREATION_DATE,
               ser.object_version_number,
               ser.period_of_placement_id
          from per_periods_of_placement ser

        ),
      orderedByRecent as
       (select PER.EMPTYPE,
               ppf.first_name,
               ppf.last_name,
               per.date_start,
               per.actual_Termination_date,
               per.person_id,
               per.Object_Version_Number,
               per.period_id
          from per_all_people_f ppf, periods per
         where 1 = 1
           and nvl(ppf.employee_number, ppf.npw_number) = l_employee_id
           and per.person_id = ppf.person_id
           AND l_ppf_date between ppf.effective_start_date and
               ppf.effective_end_date
         order by per.date_start desc, ppf.effective_start_date desc)
      select sel.date_start,
             sel.actual_Termination_date,
             sel.person_id,
             sel.emptype,
             sel.period_id,
             sel.object_version_number
        into l_ORA_hire_date,
             l_ORA_ter_date,
             l_ORA_person_id,
             l_emp_type,
             l_ora_period_id,
             l_object_version_number
        from orderedByRecent sel
       where rownum = 1;
    exception
      when others then
        p_err_code := 1;

         fnd_message.clear;
         fnd_message.set_name ('XXOBJT', 'XXHR_SF2ORA_ERROR_EMPNOTEXIST');
         fnd_message.set_token('ERRPROCEDURE', 'Termination');
         fnd_message.set_token('ERRCODE', '16');
         fnd_message.set_token('ERRADDTXT', null);
         fnd_message.set_token('WORKERNAME', p_employee_rec.PER_first_name || ' ' || p_employee_rec.PER_last_name);
         p_err_text := fnd_message.get;

    end;


  --xx_debug(' Check termination for : ' || to_char(nvl(P_EMPLOYEE_REC.EMP_TERMINATION_DATE, hr_general.END_OF_TIME),'DD-MON-YYYY'));

  -- Check number of changes in PPF after lowest between new hire date and original hire date.
    select count(1)
      into l_changes_in_person
      from per_all_people_f ppf
     where nvl(ppf.employee_number, ppf.npw_number) = l_employee_id
       and ppf.effective_start_date > nvl(P_EMPLOYEE_REC.EMP_TERMINATION_DATE, hr_general.END_OF_TIME);

-- Check number of changes in PFA   after lowest between new hire date and original hire date.
    select count(1)
      into l_changes_in_assignment
      from per_all_assignments_f pfa
         ,per_assignment_status_types pft
     where pfa.person_id = l_ora_person_id
     and pft.assignment_status_type_id = pfa.assignment_status_type_id
     and pft.per_system_status not in ('TERM_ASSIGN')
       and pfa.effective_start_date > nvl(P_EMPLOYEE_REC.EMP_TERMINATION_DATE, hr_general.END_OF_TIME);

-- Check number of changes in person_types  after lowest between new hire date and original hire date.

    select count(1)
      into l_changes_in_pertypes
      from per_person_Type_usages_f pft, per_person_types pert
     where pft.person_id = l_ora_person_id
       and pft.effective_start_date > nvl(P_EMPLOYEE_REC.EMP_TERMINATION_DATE, hr_general.END_OF_TIME)
       and pert.person_type_id = pft.person_type_id
       and pert.system_person_type in ('EMP', 'CWK');

--xx_debug('l_changes_in_person : ' || l_changes_in_person);
--xx_debug('l_changes_in_pertypes : ' || l_changes_in_pertypes);
--xx_debug('l_changes_in_assignment : ' || l_changes_in_assignment);

--xx_debug(' Procceed with P_EMPLOYEE_REC.EMP_TERMINATION_DATE as : ' || to_char(P_EMPLOYEE_REC.EMP_TERMINATION_DATE, 'DD-MON-YYYY'));
--xx_debug(' Procceed with L_ORA_TER_DATE as : ' || to_char(L_ORA_TER_DATE, 'DD-MON-YYYY'));


    if P_EMPLOYEE_REC.EMP_TERMINATION_DATE is not null
      and (l_changes_in_pertypes > 0 or l_changes_in_assignment > 0 or l_changes_in_person > 0) then
            p_err_code := 1;


          fnd_message.clear;
         fnd_message.set_name ('XXOBJT', 'XXHR_SF2ORA_ERROR_FUT_CNG');
         fnd_message.set_token('ERRPROCEDURE', 'Termination');
         fnd_message.set_token('ERRCODE', '99');
         fnd_message.set_token('ADDFTCNGTXT', 'Person/Assignment/Person Type');
         fnd_message.set_token('WORKERNAME', p_employee_rec.PER_first_name || ' ' || p_employee_rec.PER_last_name);
         p_err_text := fnd_message.get;
--            p_err_text := 'Could not terminate in Oracle, Future changes in Person/Assignment/Person types found';  -- XXHR_SF2HR_ERROR_FUTURE_CHANGE
            return;
      end if;

    -- Termination event received : can be different date !
    if l_ORA_ter_date is not null then
      -- employee is already terminated in ORA - Check for termination date change

      IF ((L_ORA_TER_DATE IS NOT NULL -- CLOSED PERIOD in ORA
         AND P_EMPLOYEE_REC.EMP_TERMINATION_DATE IS NOT NULL -- CLOSED PERIOD
         AND L_ORA_TER_DATE <> P_EMPLOYEE_REC.EMP_TERMINATION_DATE) OR

         (L_ORA_TER_DATE IS NOT NULL -- CLOSED PERIOD
         AND P_EMPLOYEE_REC.EMP_TERMINATION_DATE IS NULL -- Open PERIOD in SF
         )

         ) THEN

        CALL_TERMINATION_CNG(P_EMPLOYEE_REC => P_EMPLOYEE_REC,
                             P_ERR_CODE     => P_ERR_CODE,
                             P_ERR_TEXT     => P_ERR_TEXT);
        IF P_ERR_CODE = 0 THEN
          NULL;
        ELSE
          P_ERR_CODE := 1;
          P_ERR_TEXT := L_PROC_NAME || P_ERR_TEXT;
          RETURN;
        END IF;
        return;
      end if;
    end if;

    -- assume if both received in one go, the termination of the previous day happened a day before the re-hire
    l_termination_date := nvl(p_employee_rec.EMP_termination_date,
                              p_employee_rec.EMP_hire_date - 1);

       --xx_debug(' call termination for : ' || l_emp_type);
       --xx_debug(' call termination for  l_ora_period_id : ' || l_ora_period_id);
       --xx_debug(' call termination for l_object_version_number : ' || l_object_version_number);


    if l_emp_type = 'EMP' then

      hr_ex_employee_api.actual_termination_emp(p_validate                   => false,
                                                p_effective_date             => l_termination_date,
                                                p_period_of_service_id       => l_ora_period_id,
                                                p_object_version_number      => l_object_version_number,
                                                p_actual_termination_date    => l_termination_date,
                                                p_last_standard_process_date => l_termination_date,

                                                p_last_std_process_date_out  => l_last_std_process_date_out,
                                                p_supervisor_warning         => l_supervisor_warning,
                                                p_event_warning              => l_event_warning,
                                                p_interview_warning          => l_interview_warning,
                                                p_review_warning             => l_review_warning,
                                                p_recruiter_warning          => l_recruiter_warning,
                                                p_asg_future_changes_warning => l_asg_future_changes_warning,
                                                p_entries_changed_warning    => l_entries_changed_warning,
                                                p_pay_proposal_warning       => l_pay_proposal_warning,
                                                p_dod_warning                => l_dod_warning,
                                                p_alu_change_warning         => lp_alu_change_warning);

      l_ppf_date := get_most_recent_ppf_date(l_employee_id);

      with periods as
       (select 'EMP' EMPTYPE,
               per.period_of_service_id period_id,
               per.person_id,
               per.date_start,
               per.actual_termination_date,
               per.last_standard_process_date,
               per.CREATION_DATE,
               per.object_version_number,
               per.period_of_service_id
          from per_periods_of_service per
        UNION
        select 'CWK' EMPTYPE,
               ser.period_of_placement_id period_id,
               ser.person_id,
               ser.date_start,
               ser.actual_termination_date,
               ser.last_standard_process_date,
               ser.CREATION_DATE,
               ser.object_version_number,
               ser.period_of_placement_id
          from per_periods_of_placement ser

        ),
      orderedByRecent as
       (select PER.EMPTYPE,
               ppf.first_name,
               ppf.last_name,
               per.date_start,
               per.actual_Termination_date,
               per.person_id,
               per.Object_Version_Number,
               per.period_id
          from per_all_people_f ppf, periods per
         where 1 = 1
           and nvl(ppf.employee_number, ppf.npw_number) = l_employee_id
           and per.person_id = ppf.person_id
           AND l_ppf_date between ppf.effective_start_date and
               ppf.effective_end_date
         order by per.date_start desc, ppf.effective_start_date desc)
      select sel.date_start,
             sel.actual_Termination_date,
             sel.person_id,
             sel.emptype,
             sel.period_id,
             sel.object_version_number
        into l_ORA_hire_date,
             l_ORA_ter_date,
             l_ORA_person_id,
             l_emp_type,
             l_ora_period_id,
             l_object_version_number
        from orderedByRecent sel
       where rownum = 1;

      if p_final_process_flag = true then
        l_finalproc_date := trunc(l_termination_date);  -- if rehire back to back of EMP to EMP and temrination was missing set f.p.d same as termination to allow the re-hire.
      else
        l_finalproc_date := trunc(l_termination_date + l_termination_std_ed_Days); -- parameter. set to 31 days (25-Mar-2018)
      end if;

      --xx_debug(' p_final_process_flag is ' || to_char(l_finalproc_date, 'DD-MON-YYYY'));

      hr_ex_employee_api.final_process_emp(p_validate                   => false,
                                           p_period_of_service_id       => l_ora_period_id,
                                           p_object_version_number      => l_object_version_number,
                                           p_final_process_date         => l_finalproc_date,
                                           p_org_now_no_manager_warning => l_org_now_no_manager_warning,
                                           p_asg_future_changes_warning => l_asg_future_changes_warning,
                                           p_entries_changed_warning    => l_entries_changed_warning);

    elsif l_emp_type = 'CWK' then
      l_cwk_lsd := null;

      hr_contingent_worker_api.actual_termination_placement(p_validate                   => false,
                                                            p_effective_date             => l_termination_date,
                                                            p_person_id                  => l_ORA_person_id,
                                                            p_date_start                 => l_ORA_hire_date,
                                                            p_object_version_number      => l_object_version_number,
                                                            p_actual_termination_date    => l_termination_date,
                                                            p_last_standard_process_date => l_cwk_lsd,
                                                            p_supervisor_warning         => l_supervisor_warning,
                                                            p_event_warning              => l_event_warning,
                                                            p_interview_warning          => l_interview_warning,
                                                            p_review_warning             => l_review_warning,
                                                            p_recruiter_warning          => l_recruiter_warning,
                                                            p_asg_future_changes_warning => l_asg_future_changes_warning,
                                                            p_entries_changed_warning    => l_entries_changed_warning,
                                                            p_pay_proposal_warning       => l_pay_proposal_warning,
                                                            p_dod_warning                => l_dod_warning);

      l_cwk_lsd := trunc(l_termination_date);

          l_ppf_date := get_most_recent_ppf_date(l_employee_id);

      with periods as
       (select 'EMP' EMPTYPE,
               per.period_of_service_id period_id,
               per.person_id,
               per.date_start,
               per.actual_termination_date,
               per.last_standard_process_date,
               per.CREATION_DATE,
               per.object_version_number,
               per.period_of_service_id
          from per_periods_of_service per
        UNION
        select 'CWK' EMPTYPE,
               ser.period_of_placement_id period_id,
               ser.person_id,
               ser.date_start,
               ser.actual_termination_date,
               ser.last_standard_process_date,
               ser.CREATION_DATE,
               ser.object_version_number,
               ser.period_of_placement_id
          from per_periods_of_placement ser

        ),
      orderedByRecent as
       (select PER.EMPTYPE,
               ppf.first_name,
               ppf.last_name,
               per.date_start,
               per.actual_Termination_date,
               per.person_id,
               per.Object_Version_Number,
               per.period_id
          from per_all_people_f ppf, periods per
         where 1 = 1
           and nvl(ppf.employee_number, ppf.npw_number) = l_employee_id
           and per.person_id = ppf.person_id
           AND l_ppf_date between ppf.effective_start_date and
               ppf.effective_end_date
         order by per.date_start desc, ppf.effective_start_date desc)
      select sel.date_start,
             sel.actual_Termination_date,
             sel.person_id,
             sel.emptype,
             sel.period_id,
             sel.object_version_number
        into l_ORA_hire_date,
             l_ORA_ter_date,
             l_ORA_person_id,
             l_emp_type,
             l_ora_period_id,
             l_object_version_number
        from orderedByRecent sel
       where rownum = 1;

      hr_contingent_worker_api.final_process_placement(p_validate                   => false,
                                                       p_person_id                  => l_ORA_person_id,
                                                       p_date_start                 => l_ORA_hire_date,
                                                       p_object_version_number      => l_object_version_number,
                                                       p_final_process_date         => l_cwk_lsd,
                                                       p_org_now_no_manager_warning => l_org_now_no_manager_warning,
                                                       p_asg_future_changes_warning => l_asg_future_changes_warning,
                                                       p_entries_changed_warning    => l_entries_changed_warning);

    else
      p_err_code := 1;

       fnd_message.clear;
         fnd_message.set_name ('XXOBJT', 'XXHR_SF2ORA_ERROR_GENERAL');
         fnd_message.set_token('ERRPROCEDURE', 'Termination changes');
         fnd_message.set_token('ERRCODE', '99');
         fnd_message.set_token('ORAERR', 'Employment period not found');
         fnd_message.set_token('WORKERNAME', p_employee_rec.PER_first_name || ' ' || p_employee_rec.PER_last_name);
         p_err_text := fnd_message.get;

    end if;

    p_err_code := 0;
    --  commit;
  exception
    when others then
      rollback;
      p_err_code := 1;

       fnd_message.clear;
         fnd_message.set_name ('XXOBJT', 'XXHR_SF2ORA_ERROR_GENERAL');
         fnd_message.set_token('ERRPROCEDURE', 'Termination changes');
         fnd_message.set_token('ERRCODE', '16');
         fnd_message.set_token('ORAERR', SUBSTR(sqlerrm, 1, 255));
         fnd_message.set_token('WORKERNAME', p_employee_rec.PER_first_name || ' ' || p_employee_rec.PER_last_name);
         p_err_text := fnd_message.get;

  end call_Termination;

  /* procedure : call_new_hire
   By : Dan Melamed 22/Jan/2018

   Procedure Purpose :
      Validate data and call oracle seeded API to create new employee/Contractor (new/first hire)

    In Variables :
       p_employee_rec - row from the updating bulk
    Out :
       p_person_id - person_id of new created employee/CWK
       p_assignment_id - Assignment_ID of new created employee/CWK
       p_err_code - Error indication for processing
       p_err_text - actual error received if any.

   Version Control :
      1.0    CR 40116   Dan Melamed       22/Jan/2018
  */

  Procedure call_new_hire(p_employee_rec  xxhr_emp_rec,
                          p_err_code      out number,
                          p_err_text      out varchar2,
                          p_person_id     out number,
                          p_assignment_id out number) is
--    l_hr_employment_type varchar2(255);
    l_employee_exists    number;
    l_hr_person_type     varchar2(255);
  --  l_hr_person_TYPE_id  number;
    l_sf_person_Type_id  number;
    l_hire_type          varchar2(255);
    l_err_state          number := 0;
    l_err_str            varchar2(255);
    l_proc_name          varchar2(255) := 'API Procedure : New_Hire - ';
    l_employee_id        varchar2(255) := truncated_compass_id(p_employee_rec.person_id_external);
  begin

    -- check employee exists in HR at all.
    select count(1)
      into l_employee_exists
      from per_all_people_f ppf
     where nvl(ppf.employee_number, ppf.npw_number) = l_employee_id;

    -- if employee exists (and Event here is a new hire) - exit with error and do nothing.
    if l_employee_exists > 0 then

         fnd_message.clear;
         fnd_message.set_name ('XXOBJT', 'XXHR_SF2ORA_ERROR_EMP_EXISTS');
         fnd_message.set_token('ERRPROCEDURE', 'New Hire');
         fnd_message.set_token('ERRCODE', '01');
         fnd_message.set_token('WORKERNAME', p_employee_rec.PER_first_name || ' ' || p_employee_rec.PER_last_name);
         p_err_text := fnd_message.get;


--      p_err_text := l_proc_name || 'Employee Already exist in Oracle HR';  -- XXHR_SF2HR_ERROR_ALREADYEXIST
      p_err_code := 1;
      return;
    end if;

    -- Convert from Compass assignment class to person type and employment type.
    l_hr_person_type := map_sf_to_HR_person_Type(p_employee_rec.ASG_sf_employee_class);

    -- after mapping received from rachel, look for the person type for the interface.
    begin

      select pert.person_type_id, pert.system_person_type
        into l_sf_person_Type_id, l_hire_type
        from per_person_types pert
       where pert.user_person_type = l_hr_person_type;

    exception
      when others then
            fnd_message.clear;
         fnd_message.set_name ('XXOBJT', 'XXHR_SF2ORA_ERROR_PERTYPE_UNK');
         fnd_message.set_token('ERRPROCEDURE', 'New Hire');
         fnd_message.set_token('ERRCODE', '0');
         fnd_message.SET_TOKEN('SFPT', l_hr_person_type || ' (' || p_employee_rec.ASG_sf_employee_class || ')');
         fnd_message.SET_TOKEN('ADDTEXT', null);
         fnd_message.set_token('WORKERNAME', p_employee_rec.PER_first_name || ' ' || p_employee_rec.PER_last_name);
         p_err_text := fnd_message.get;
        p_err_code := 1;
        return;
    end;

    if l_hire_type not in ('EMP', 'CWK') then
      p_err_code := 1;

         fnd_message.clear;
         fnd_message.set_name ('XXOBJT', 'XXHR_SF2ORA_ERROR_PERTYPE_UNK');
         fnd_message.set_token('ERRPROCEDURE', 'New Hire');
         fnd_message.set_token('ERRCODE', '0');
         fnd_message.SET_TOKEN('SFPT', l_hr_person_type || ' (' || p_employee_rec.ASG_sf_employee_class || ')');
         fnd_message.SET_TOKEN('ADDTEXT', 'Or not a EMP/CWK Employee type');
         fnd_message.set_token('WORKERNAME', p_employee_rec.PER_first_name || ' ' || p_employee_rec.PER_last_name);
         p_err_text := fnd_message.get;
      p_err_code := 1;
      return;
    end if;

    -- birthdate validation : birthdate must be EARLIER to hire date. this is oracle rule.
    if p_employee_rec.EMP_hire_date <
       nvl(p_employee_rec.Per_date_of_birth, p_employee_rec.EMP_hire_date) then
     -- p_err_text := l_proc_name || '';  -- XXHR_SF2HR_ERROR_GENERAL

               fnd_message.clear;
         fnd_message.set_name ('XXOBJT', 'XXHR_SF2ORA_ERROR_GENERAL');
         fnd_message.set_token('ERRPROCEDURE', 'New Hire');
         fnd_message.set_token('ERRCODE', '99');
         fnd_message.SET_TOKEN('ORAERR', 'Birthdate can not be after Hire date');
         fnd_message.SET_TOKEN('ORAERR2', null);
         fnd_message.set_token('WORKERNAME', p_employee_rec.PER_first_name || ' ' || p_employee_rec.PER_last_name);
         p_err_text := fnd_message.get;

      p_err_code := 1;
      return;
    end if;

    -- validate first/last name exist (note, can be non english !)
    if p_employee_rec.Per_first_name is null or
       p_employee_rec.Per_last_name is null then
               fnd_message.clear;
         fnd_message.set_name ('XXOBJT', 'XXHR_SF2ORA_ERROR_GENERAL');
         fnd_message.set_token('ERRPROCEDURE', 'New Hire');
         fnd_message.set_token('ERRCODE', '99');
         fnd_message.SET_TOKEN('ORAERR', 'First and last names are mandatory');
         fnd_message.SET_TOKEN('ORAERR2', null);
         fnd_message.set_token('WORKERNAME', p_employee_rec.PER_first_name || ' ' || p_employee_rec.PER_last_name);
         p_err_text := fnd_message.get;
      p_err_code := 1;
      return;
    end if;

    if p_employee_rec.PER_gender is null then
                    fnd_message.clear;
         fnd_message.set_name ('XXOBJT', 'XXHR_SF2ORA_ERROR_GENERAL');
         fnd_message.set_token('ERRPROCEDURE', 'New Hire');
         fnd_message.set_token('ERRCODE', '99');
         fnd_message.SET_TOKEN('ORAERR', 'Gender is Mandatory');
         fnd_message.SET_TOKEN('ORAERR2', null);
         fnd_message.set_token('WORKERNAME', p_employee_rec.PER_first_name || ' ' || p_employee_rec.PER_last_name);
         p_err_text := fnd_message.get;
      p_err_code := 1;
      return;
    end if;

    if l_hire_type in ('EMP') then
      -- Employee
      ----xx_debug(' create new emp on ' ||               to_char(p_employee_rec.EMP_HIRE_DATE, 'DD-MON-YYYY'),               sysdate);
      create_employee(p_hire_date     => p_employee_rec.EMP_HIRE_DATE,
                      p_first_name    => p_employee_rec.Per_first_name,
                      p_last_name     => p_employee_rec.Per_last_name,
                      p_middle_name   => p_employee_rec.Per_middle_name,
                      p_gender        => p_employee_rec.per_Gender,
                      p_date_of_birth => p_employee_rec.Per_date_of_birth,
                      p_compass_id    => p_employee_rec.person_id_external,
                      p_person_id     => p_person_id,
                      p_assignment_id => p_assignment_id,
                      p_out_err       => l_err_str);
      --xx_debug(' emp created ', sysdate);
    elsif l_hire_type in ('CWK') then
      -- Contractor
      --xx_debug(' create new CWK on ' || to_char(p_employee_rec.EMP_HIRE_DATE, 'DD-MON-YYYY'), sysdate);

      create_contingent(p_hire_date     => p_employee_rec.EMP_HIRE_DATE,
                        p_first_name    => p_employee_rec.Per_first_name,
                        p_last_name     => p_employee_rec.Per_last_name,
                        p_middle_name   => p_employee_rec.Per_middle_name,
                        p_gender        => p_employee_rec.per_Gender,
                        p_date_of_birth => p_employee_rec.Per_date_of_birth,
                        p_compass_id    => p_employee_rec.person_id_external,
                        p_person_id     => p_person_id,
                        p_assignment_id => p_assignment_id,
                        p_out_err       => l_err_str);
      --xx_debug(' Contractor created ', sysdate);

    end if;

    -- check if create employment passed through (by checking function outputs)
    if p_person_id is not null and p_assignment_id is not null then
      -- and if employment created, run through the call update to update assignment (person / employment periods will not be updated as nothing changed in this stage)
      --xx_debug(' Call Data Update ', sysdate);

      call_data_update(p_employee_rec  => p_employee_rec,
                       p_err_code      => l_err_state,
                       p_err_text      => l_err_str
                      );
      --xx_debug(' Update data called ', sysdate);
      --xx_debug(' update data err : ' || l_err_str, sysdate);
      if l_err_state is null or l_err_state = 0 then

        p_err_code := 0;
        --   commit;
      else
        rollback;
        p_err_code := 1;


         fnd_message.clear;
         fnd_message.set_name ('XXOBJT', 'XXHR_SF2ORA_ERROR_GENERAL');
         fnd_message.set_token('ERRPROCEDURE', 'New Hire');
         fnd_message.set_token('ERRCODE', '99');
         fnd_message.SET_TOKEN('ORAERR', 'Error during hire');
         fnd_message.SET_TOKEN('ORAERR2', l_err_str);
         fnd_message.set_token('WORKERNAME', p_employee_rec.PER_first_name || ' ' || p_employee_rec.PER_last_name);
         p_err_text := fnd_message.get;

      end if;
      null;
    else
      rollback;
      p_err_code := 1;


       fnd_message.clear;
         fnd_message.set_name ('XXOBJT', 'XXHR_SF2ORA_ERROR_GENERAL');
         fnd_message.set_token('ERRPROCEDURE', 'New Hire');
         fnd_message.set_token('ERRCODE', '99');
         fnd_message.SET_TOKEN('ORAERR', 'Error during hire');
         fnd_message.SET_TOKEN('ORAERR2', l_err_str || SUBSTR(sqlerrm, 1, 255));
         fnd_message.set_token('WORKERNAME', p_employee_rec.PER_first_name || ' ' || p_employee_rec.PER_last_name);
         p_err_text := fnd_message.get;

    end if;
    null;
  end call_new_hire;

  /* procedure : call_re_hire
   By : Dan Melamed 22/Jan/2018

   Procedure Purpose :
      Validate data and call oracle seeded API to RE-hire employee

    In Variables :
       p_employee_rec - row from the updating bulk
    Out :
       p_person_id - person_id of new created employee/CWK
       p_assignment_id - Assignment_ID of new created employee/CWK
       p_err_code - Error indication for processing
       p_err_text - actual error received if any.

   Version Control :
      1.0    CR 40116   Dan Melamed       22/Jan/2018
      1.1    CHG0042593 Dan Melamed       25-Mar-2018 : Change behaviour around termination/rehire for special rehire (fix)
      1.2    CHG0043076 Dan MelameD       25-May-2018 : If rehired already , skip the rehire and process as data change only.
  */

  Procedure call_rehire(p_employee_rec  in out xxhr_emp_rec,
                        p_err_code      out number,
                        p_err_text      out varchar2,
                        p_person_id     out number) is
    l_hr_person_type     varchar2(255);
    l_sf_person_Type_id  number;
    l_hire_type          varchar2(255);
    l_HR_TER_hire_type   varchar2(255);
    l_err_state          number := 0;
    l_err_str            varchar2(255);

    l_ORA_ter_date           date;
    l_ORA_person_id          number;
    l_object_version_number  number;
    l_employee_number        varchar2(255);
    l_rehire_sd              date;
    l_rehire_ed              date;
    l_assign_payroll_warning boolean;
    l_orig_hire_warning      boolean;
    l_employee_id            varchar2(255) := truncated_compass_id(p_employee_rec.person_id_external);
    l_proc_name              varchar2(255) := 'API Procedure : Rehire - ';
    l_per_eff_d_s            date;
    l_per_eff_d_e            date;

    l_pdp_object_version_number number;
    l_assignment_id             number;
    l_asg_object_version_number number;
    l_assignment_sequence       number;
    l_ppf_date                  date;
    l_ora_assignment_id         number;
    l_lookfor_ass_type          varchar2(1);
    l_ora_hire_date date;
   l_final_process_rehire_flag boolean := false;



    l_ORA_CWK_hire_date       date;
    l_cwk_fpd                 date;
    l_cwk_ovn                 number;

    l_ter_errcode number;
    l_ter_errtext varchar2(4000);
/*    Cursor fut_ass_not_Active(p_person_id number, p_eff_date date) is
      select *
        from per_all_assignments_f pfa
       where pfa.person_id = p_person_id
         and trunc(pfa.effective_start_date) >= trunc(p_eff_date)
         and pfa.assignment_status_type_id in (1, 76);*/

  begin

    l_employee_number := l_employee_id;
    --xx_debug(' this is for l_employee_number : ' || l_employee_number);
    begin
      l_ppf_date := get_most_recent_ppf_date(l_employee_id);

      with periods as
       (select 'EMP' EMPTYPE,
               per.period_of_service_id period_id,
               per.person_id,
               per.date_start,
               per.actual_termination_date,
               per.last_standard_process_date,
               per.CREATION_DATE,
               per.object_version_number,
               per.period_of_service_id
          from per_periods_of_service per
        UNION
        select 'CWK' EMPTYPE,
               ser.period_of_placement_id period_id,
               ser.person_id,
               ser.date_start,
               ser.actual_termination_date,
               ser.last_standard_process_date,
               ser.CREATION_DATE,
               ser.object_version_number,
               ser.period_of_placement_id
          from per_periods_of_placement ser

        ),
      orderedByRecent as
       (select PER.EMPTYPE,
               ppf.first_name,
               ppf.last_name,
               per.date_start,
               per.actual_Termination_date,
               per.person_id,
               PPF.Object_Version_Number,
               per.period_id
          from per_all_people_f ppf, periods per
         where 1 = 1
           and nvl(ppf.employee_number, ppf.npw_number) = l_employee_id
           and per.person_id = ppf.person_id
           AND l_ppf_date between ppf.effective_start_date and
               ppf.effective_end_date
         order by per.date_start desc, ppf.effective_start_date desc)
      select sel.actual_Termination_date,
             sel.person_id,
             sel.EMPTYPE,
             SEL.OBJECT_VERSION_NUMBER,
             sel.date_start
        into l_ORA_ter_date,
             l_ORA_person_id,
             l_HR_TER_hire_type,
             l_object_version_number,
             l_ora_hire_date
        from orderedByRecent sel
       where rownum = 1;
    exception
      when no_Data_found then
        -- this is actually a first hire - no previous employments found for employee !
         fnd_message.clear;
         fnd_message.set_name ('XXOBJT', 'XXHR_SF2ORA_ERROR_EMPNOTEXIST');
         fnd_message.set_token('ERRPROCEDURE', 'Rehire');
         fnd_message.set_token('ERRCODE', '22');
         fnd_message.set_token('ERRADDTXT', null);
         fnd_message.set_token('WORKERNAME', p_employee_rec.PER_first_name || ' ' || p_employee_rec.PER_last_name);
         p_err_text := fnd_message.get;
         p_err_code := 1;
        return;
    end;

    l_hr_person_type := map_sf_to_HR_person_Type(p_employee_rec.ASG_sf_employee_class);

    -- after mapping received from rachel, look for the person type for the interface.

    begin

      select pert.person_type_id, pert.system_person_type
        into l_sf_person_Type_id, l_hire_type
        from per_person_types pert
       where pert.user_person_type = l_hr_person_type;

    exception
      when others then
       fnd_message.clear;
         fnd_message.set_name ('XXOBJT', 'XXHR_SF2ORA_ERROR_PERTYPE_UNK');
         fnd_message.set_token('ERRPROCEDURE', 'Rehire');
         fnd_message.set_token('ERRCODE', '0');
         fnd_message.SET_TOKEN('SFPT', l_hr_person_type || ' (' || p_employee_rec.ASG_sf_employee_class || ')');
         fnd_message.SET_TOKEN('ADDTEXT', null);
         fnd_message.set_token('WORKERNAME', p_employee_rec.PER_first_name || ' ' || p_employee_rec.PER_last_name);
         p_err_text := fnd_message.get;
        p_err_code := 1;
        return;
    end;

 -- CHG0043076 : If rehired already , skip the rehire and process as data change only.
  if trunc(p_employee_rec.EMP_hire_date) = trunc(l_ora_hire_date) then
    -- Already rehired !
    call_data_update(p_employee_rec  => p_employee_rec,
                     p_err_code      => p_err_code,
                     p_err_text      => p_err_text);
   return;
  end if;

-- CHG0042593 - Take into account possibility of EMPG/ICT Coming as two seperate events.
     if l_ORA_ter_date is null and trunc(p_employee_rec.EMP_hire_date) <> trunc(l_ora_hire_date) then
      -- if re-hire, and specific re-hire types, than terminate a day before the re-hire
        if p_employee_rec.Sub_event in ('EMPG', 'ICT') then
           --xx_debug(' Fake termination event for ' || l_HR_TER_hire_type);
          -- terminate first and than re-hire (fake termination date)

          if l_HR_TER_hire_type = 'EMP' then -- if ORA Type to terminate is EMP(loyee)
                p_employee_rec.EMP_termination_date := p_employee_rec.EMP_hire_date - 1;
                l_final_process_rehire_flag := true; -- set final process date flag to allow emp to emp rehire (final process date)
              else
                p_employee_rec.EMP_termination_date := p_employee_rec.EMP_hire_date - 1;  -- else if CWK termination and re-hire can be same day.

          end if;

            call_termination(p_employee_rec => p_employee_rec, p_err_code => l_ter_errcode, p_err_text => l_ter_errtext, p_final_process_flag=>l_final_process_rehire_flag ); -- call termination
            --xx_debug(' Exit termination with : ' || l_ter_errtext);
            if l_ter_errcode <> 0 then  -- error returned from temrination APIs
                    p_err_text := l_ter_errtext;
                    p_err_code := 1;
                    return;
             else
               -- commit; -- releasing any locks related with termination events.
                p_err_code := 2;  -- re-hire will continue immiedetly.
               return;  -- redo the re-hire in the main to re-hire for real this time.
            end if;
        else
          fnd_message.clear;
         fnd_message.set_name ('XXOBJT', 'XXHR_SF2ORA_ERROR_REHI_NOTTER');
         fnd_message.set_token('ERRPROCEDURE', 'Rehire');
         fnd_message.set_token('ERRCODE', '23');
         fnd_message.set_token('WORKERNAME', p_employee_rec.PER_first_name || ' ' || p_employee_rec.PER_last_name);
         p_err_text := fnd_message.get;
         p_err_code := 1;
      return;

      end if;
    end if;

    if p_employee_rec.EMP_hire_date < l_ORA_ter_date then
      fnd_message.clear;
         fnd_message.set_name ('XXOBJT', 'XXHR_SF2ORA_ERROR_CNGHIRE_BTER');
         fnd_message.set_token('ERRPROCEDURE', 'Rehire');
         fnd_message.set_token('ERRCODE', '0');
         fnd_message.set_token('WORKERNAME', p_employee_rec.PER_first_name || ' ' || p_employee_rec.PER_last_name);
         p_err_text := fnd_message.get;
         p_err_code := 1;
      return;
    end if;

    --xx_debug('l_hire_type : ' || l_hire_type);
    --xx_debug('l_HR_TER_hire_type : ' || l_HR_TER_hire_type);
    --xx_debug('p_employee_rec.EMP_hire_date : ' ||  to_char(p_employee_rec.EMP_hire_date, 'DD-MON-YYYY'));

    IF L_HIRE_TYPE Not in ('EMP', 'CWK') then

          fnd_message.clear;
         fnd_message.set_name ('XXOBJT', 'XXHR_SF2ORA_ERROR_PERTYPE_UNK');
         fnd_message.set_token('ERRPROCEDURE', 'Rehire');
         fnd_message.set_token('ERRCODE', '0');
         fnd_message.SET_TOKEN('SFPT', l_hr_person_type || ' (' || p_employee_rec.ASG_sf_employee_class || ')');
         fnd_message.SET_TOKEN('ADDTEXT', 'Or not a EMP/CWK Employee type');
         fnd_message.set_token('WORKERNAME', p_employee_rec.PER_first_name || ' ' || p_employee_rec.PER_last_name);
         p_err_text := fnd_message.get;
         p_err_code := 1;
      return;
    end if;

    if l_hire_type in ('EMP') and l_HR_TER_hire_type in ('EMP') then
      -- Employee rehired as employee
      --xx_debug(' rehire EMP to EMP');
      call_re_hire_employee(p_person_id             => l_ORA_person_id,
                            p_hire_date             => p_employee_rec.EMP_hire_date,
                            p_object_version_number => l_object_version_number,
                            p_out_err               => p_err_text);
      --xx_debug (' rehire exited with : ' || p_err_text);

      -- do not call data change directly. if needed bounce again from SF with aprpriate event.!

    elsif l_hire_type in ('EMP') and l_HR_TER_hire_type in ('CWK') then
      -- rehire CWK as EMP
      begin
        -- delete the terminate CWK Assignment...

        begin

          select t.date_start,
                 t.object_version_number,
                 t.final_process_date
            into l_ORA_CWK_hire_date, l_cwk_ovn, l_cwk_fpd
            from per_periods_of_placement t
           where t.person_id = l_ORA_person_id
             and p_employee_rec.EMP_hire_date between t.date_start and
                 t.final_process_date;

          if p_employee_rec.EMP_hire_date < l_cwk_fpd then
            p_err_text := 'Change Final process date for the Contractor record, or re-hire after last process date';
            p_err_code := 1;
            return;

          end if;
        exception
          when no_data_found then
            null; -- everything is ok, no Issue with FPD.
        end;

       --xx_debug('got to hire into job');
       --xx_debug(' p_employee_rec.EMP_hire_date : ' || to_char( p_employee_rec.EMP_hire_date));
       --xx_debug('l_ORA_person_id : ' ||  l_ORA_person_id);
       --xx_debug('l_object_version_number : ' ||  l_object_version_number);
        HR_EMPLOYEE_API.HIRE_INTO_JOB(p_validate               => false,
                                      p_effective_date         => p_employee_rec.EMP_hire_date,
                                      p_person_id              => l_ORA_person_id,
                                      p_object_version_number  => l_object_version_number,
                                      p_employee_number        => l_employee_number,
                                      p_effective_start_date   => l_rehire_sd,
                                      p_effective_end_date     => l_rehire_ed,
                                      p_assign_payroll_warning => l_assign_payroll_warning,
                                      p_orig_hire_warning      => l_orig_hire_warning);

      exception
        when others then
          p_err_text := SUBSTR(sqlerrm, 1, 255);
          p_err_code := 1;
          return;

      end;
    elsif l_hire_type in ('CWK') and l_HR_TER_hire_type in ('EMP') then
      -- rehire EMP as CWK

      begin
      --xx_debug(' THIS IS MY Rehire');
      --xx_debug('l_object_version_number : ' || l_object_version_number);
      --xx_debug('l_ORA_person_id : ' || l_ORA_person_id);
        HR_CONTINGENT_WORKER_API.convert_to_cwk(p_validate                  => false,
                                                p_effective_date            => p_employee_rec.EMP_hire_date,
                                                p_person_id                 => l_ORA_person_id,
                                                p_object_version_number     => l_object_version_number,
                                                p_npw_number                => l_employee_number,
                                                p_datetrack_update_mode     => 'UPDATE', -- it will always be update - Rehire !
                                                p_per_effective_start_date  => l_per_eff_d_s,
                                                p_per_effective_end_date    => l_per_eff_d_e,
                                                p_pdp_object_version_number => l_pdp_object_version_number,
                                                p_assignment_id             => l_assignment_id,
                                                p_asg_object_version_number => l_asg_object_version_number,
                                                p_assignment_sequence       => l_assignment_sequence);

      exception
        when others then
          --xx_debug(SUBSTR(sqlerrm, 1, 255));
          p_err_text := SUBSTR(sqlerrm, 1, 255);
          p_err_code := 1;
          return;

      end;
    else
      p_err_text := 'At this stage only EMP to EMP ,CWK to EMP or EMP to CWK rehire supported by the interface. CWK rehire to CWK is not supported.';
      p_err_code := 1;
      return;

    end if;

    -- if I am still here, means no errors till now.


    select decode(l_hire_type, 'EMP', 'E', 'CWK', 'C', 'X')
      into l_lookfor_ass_type
      from dual;

    select pfa.assignment_id
      into l_ora_assignment_id
      from per_all_assignments_f pfa
     where pfa.person_id = l_ORA_person_id
       and pfa.assignment_type in (l_lookfor_ass_type) -- not taking applicant records, when they exist (they do)
       and pfa.assignment_status_type_id in (1, 76) -- active assignment
       and pfa.effective_start_date =
           (select max(pfa1.effective_start_date)
              from per_all_assignments_f pfa1
             where pfa.assignment_status_type_id in (1, 76)
               and pfa.person_id = pfa1.person_id
               and pfa1.assignment_type in (l_lookfor_ass_type));

    --xx_debug(' now calling call_data_update');

    if p_employee_rec.Sub_event in ('EMPG', 'ICT') then
       p_employee_rec.EMP_termination_date := null; -- (to compensate on above changes)
    end if;

    --xx_debug(' hire date for update data : ' ||  to_char( p_employee_rec.EMP_hire_date, 'DD-MON-YYYY'));
    --xx_debug(' ter date for update data : ' ||  to_char( p_employee_rec.EMP_termination_date, 'DD-MON-YYYY'))   ;
    call_data_update(p_employee_rec  => p_employee_rec,
                     p_err_code      => l_err_state,
                     p_err_text      => l_err_str);

    --xx_debug(' Update data called ', sysdate);
    --xx_debug(' update data err : ' || l_err_str, sysdate);
    if l_err_state is null or l_err_state = 0 then

      p_err_code := 0;
      --   commit;
    else
      rollback;
      p_err_code := 1;
      p_err_text := l_proc_name || 'error during updating assigmnet : ' ||
                    l_err_str;
    end if;

    --  p_err_code := 0;
    --  commit;
  end call_rehire;

  /* procedure : call_termination_cng
   By : Dan Melamed 22/Jan/2018

   Procedure Purpose :
      Do all Termination *Changes* - Change termination Date / Reverse Termination.
      this procedure is not to be called for the initial termination

    In Variables :
       p_employee_rec - row from the updating bulk
    Out :
       p_person_id - not used at this point.
       p_assignment_id - not used at this point
       p_err_code - Error indication for processing
       p_err_text - actual error received if any.

   Version Control :
      1.0    CR 40116   Dan Melamed       22/Jan/2018
  */

  procedure call_termination_cng(p_employee_rec xxhr_emp_rec,
                                 p_err_code     out number,
                                 p_err_text     out varchar2) is
    l_ORA_hire_date           date;
    l_ORA_ter_date            date;
    l_ORA_person_id           number;
    l_HR_emp_type             varchar2(3);
    l_ora_period_id           number;

--    L_FUT_ACTNS_EXIST_WARNING BOOLEAN;
    l_object_version_number   number;
    l_warn                    boolean;

--    l_last_std_process_date_out  date;
/*    l_supervisor_warning         boolean;
    l_event_warning              boolean;
    l_interview_warning          boolean;
    l_review_warning             boolean;
    l_recruiter_warning          boolean;
    l_asg_future_changes_warning boolean;
    l_entries_changed_warning    varchar2(255);
    l_pay_proposal_warning       boolean;*/
    l_dod_warning                boolean;
/*    lp_alu_change_warning        varchar2(255);
    l_org_now_no_manager_warning boolean;
    l_finalproc_date             date;
    l_cwk_lsd                    date;
    l_person_id                  number;
    l_assignment_id              number;*/
    l_err_code                   number;
    l_err_msg                    varchar2(255);
    l_proc_name                  varchar2(255) := 'call_termination_chg - ';
    l_employee_id                varchar2(255);
    l_ppf_date                   date;
  begin
    l_employee_id := truncated_compass_id(p_employee_rec.person_id_external);
    begin
      -- get last *employment* record in ORA --> start and end dates, type (C/E) etc, Verify employee exists in Oracle.

      l_ppf_date := get_most_recent_ppf_date(l_employee_id);

      with periods as
       (select 'EMP' EMPTYPE,
               per.period_of_service_id period_id,
               per.person_id,
               per.date_start,
               per.actual_termination_date,
               per.last_standard_process_date,
               per.CREATION_DATE,
               per.object_version_number,
               per.period_of_service_id
          from per_periods_of_service per
        UNION
        select 'CWK' EMPTYPE,
               ser.period_of_placement_id period_id,
               ser.person_id,
               ser.date_start,
               ser.actual_termination_date,
               ser.last_standard_process_date,
               ser.CREATION_DATE,
               ser.object_version_number,
               ser.period_of_placement_id
          from per_periods_of_placement ser

        ),
      orderedByRecent as
       (select PER.EMPTYPE,
               ppf.first_name,
               ppf.last_name,
               per.date_start,
               per.actual_Termination_date,
               per.person_id,
               per.Object_Version_Number,
               per.period_id
          from per_all_people_f ppf, periods per
         where 1 = 1
           and nvl(ppf.employee_number, ppf.npw_number) = l_employee_id
           and per.person_id = ppf.person_id
           AND l_ppf_date between ppf.effective_start_date and
               ppf.effective_end_date
         order by per.date_start desc, ppf.effective_start_date desc)
      select sel.date_start,
             sel.actual_Termination_date,
             sel.person_id,
             sel.emptype,
             sel.period_id,
             sel.object_version_number
        into l_ORA_hire_date,
             l_ORA_ter_date,
             l_ORA_person_id,
             l_HR_emp_type,
             l_ora_period_id,
             l_object_version_number
        from orderedByRecent sel
       where rownum = 1;
    exception
      when others then
        p_err_code := 1;
         fnd_message.clear;
         fnd_message.set_name ('XXOBJT', 'XXHR_SF2ORA_ERROR_EMPNOTEXIST');
         fnd_message.set_token('ERRPROCEDURE', 'Termination changes');
         fnd_message.set_token('ERRCODE', '18');
         fnd_message.set_token('ERRADDTXT', null);
         fnd_message.set_token('WORKERNAME', p_employee_rec.PER_first_name || ' ' || p_employee_rec.PER_last_name);
         p_err_text := fnd_message.get;
         RETURN;
        end;

    --xx_debug(' Check termination dates ');
    -- reverse termination / change termination date ?
    if l_ORA_ter_date is not null -- terminated in ORA
       and p_employee_rec.EMP_termination_date is not null -- terminated in SF/Compass
       and
       trunc(l_ORA_ter_date) <> trunc(p_employee_rec.EMP_termination_date) -- Change in Termination Date
     then

      -- treat as termination date change
      begin
        if l_HR_emp_type = 'EMP' then
          hr_ex_employee_api.reverse_terminate_employee(p_person_id               => l_ORA_person_id,
                                                        p_actual_termination_date => l_ORA_ter_date,
                                                        p_clear_details           => 'Y');
        else
          -- else its CWK. no other option
          hr_contingent_worker_api.reverse_terminate_placement(p_person_id               => l_ORA_person_id,
                                                               p_actual_termination_date => l_ORA_ter_date,
                                                               p_clear_details           => 'Y',
                                                               p_fut_actns_exist_warning => l_warn);
        end if;

      exception
        when others then
          p_err_code := 1;


          fnd_message.clear;
         fnd_message.set_name ('XXOBJT', 'XXHR_SF2ORA_ERROR_GENERAL');
         fnd_message.set_token('ERRPROCEDURE', 'Termination changes');
         fnd_message.set_token('ERRCODE', '16');
          fnd_message.set_token('ORAERR', 'Termination Error : ');
         fnd_message.set_token('ORAERR2', SUBSTR(SQLERRM, 1, 255));         fnd_message.set_token('WORKERNAME', p_employee_rec.PER_first_name || ' ' || p_employee_rec.PER_last_name);
         p_err_text := fnd_message.get;
         return;
      end;

      call_termination(p_employee_rec  => p_employee_rec,
                       p_err_code      => l_err_code,
                       p_err_text      => l_err_msg);
      p_err_code := NVL(l_err_code, 0);
     -- if p_err_text is not null
      p_err_text := l_err_msg;
    elsif l_ORA_ter_date is not null -- terminated in ORA
          and p_employee_rec.EMP_termination_date is null then

      -- NOT terminated in SF/Compass
      -- Reverse Termination
      --xx_debug('reverse ter');
      --xx_debug(' for type : ' || l_HR_emp_type);
      if l_HR_emp_type = 'EMP' then
        hr_ex_employee_api.reverse_terminate_employee(p_person_id               => l_ORA_person_id,
                                                      p_actual_termination_date => l_ORA_ter_date,
                                                      p_clear_details           => 'Y');
      else
        -- else its CWK. no other option
        hr_contingent_worker_api.reverse_terminate_placement(p_person_id               => l_ORA_person_id,
                                                             p_actual_termination_date => l_ORA_ter_date,
                                                             p_clear_details           => 'Y',
                                                             p_fut_actns_exist_warning => l_warn);
      end if;

    else
      null;
    end if;
     p_err_code := 0;
    -- end if;

    -- redo with new termination date


  exception
    when others then
      p_err_code := 1;
      p_err_text := SUBSTR(sqlerrm, 1, 255);
  end call_termination_cng;

  /* procedure : process_employees
   By : Dan Melamed 22/Jan/2018

   Procedure Purpose :
      Entry point for Interface.

    In Variables :
       p_sourcename - Source  for update (not used currently)
       p_source_id  - Sequential ID of update (not used currently)
       p_processing_bulk - Bulk of transactions to process into HR
    Out :
       p_error_code - General fault error code
       p_error_message - General fault error message
       p_processing_bulk - Status and Error messages for each transaction in the bulk

   Version Control :
      1.0    CR 40116   Dan Melamed       22/Jan/2018
      1.1    CHG0042593 Dan Melamed       25-Mar-2018 : Change behaviour around termination/rehire for special rehire (fix)

  */

  Procedure process_employees(p_sourcename      varchar2,  -- not used at this point
                              p_source_id       varchar2,  -- not used at this point
                              p_error_code      out varchar2,
                              p_error_message   out varchar2,
                              p_processing_bulk IN OUT xxhr_emp_tab) is

    l_record        xxhr_emp_rec;
--    l_err           varchar2(255);
--    l_status        number;
    l_person_id     number;
    l_assignment_id number;

--    l_emp_type        varchar2(255);
--    l_per_type        varchar2(255);
    l_employee_id     number;
    l_init_user_state number;
    l_test_employee   varchar2(255);
    TYPE t_ignore_emps_t IS TABLE OF per_all_people_f.employee_number%TYPE INDEX BY BINARY_INTEGER;

    l_ignore_emps_t t_ignore_emps_t;
  begin

    --xx_debug('Pre initialize', sysdate);

    l_init_user_state := init_user;
    if l_init_user_state <> 0 then
      p_error_code    := 1;
      p_error_message := 'Could not apps.initialize to user';
      return;
    end if;

    --xx_debug('User Initizlized', sysdate);

    FOR i IN p_processing_bulk.FIRST .. p_processing_bulk.LAST LOOP
      --xx_debug('==============================================================================');
      l_record      := p_processing_bulk(i);
      l_employee_id := truncated_compass_id(l_record.person_id_external);
      g_current_emp_no := l_employee_id;

      --xx_debug(' Processing employee : ' || l_employee_id, sysdate);

      begin
        l_test_employee := l_ignore_emps_t(l_employee_id);
      exception
        when no_Data_found then
          l_test_employee := null;
      end;

      if l_test_employee is null then
        -- check if error was set for this employee in this bulk
        --xx_debug('Date Informations');
         --xx_debug(to_char(l_record.Per_date_of_birth, 'DD-MON-YYYY') || ' - Birthdate -  before each and any processing');
         --xx_debug(to_char(l_record.CNG_START_DATE, 'DD-MON-YYYY') || ' - Change Date (JI) -  before each and any processing');
         --xx_debug(to_char(l_record.EMP_termination_date, 'DD-MON-YYYY') || ' - Terminarion Date -  before each and any processing');
         --xx_debug(to_char(l_record.EMP_hire_date, 'DD-MON-YYYY') || ' - Hire Date -  before each and any processing');

         align_date(l_record.Per_date_of_birth);
         --xx_debug(to_char(l_record.Per_date_of_birth, 'DD-MON-YYYY') || ' - Birthdate -  after align');
        if l_Record.Event_name = 'HR_NEWHIRE' then
          -- new hire (first ever hire, CWK or EMP first ever occurance of this emp#)
          --xx_debug(' calling new hire ', sysdate);
          call_new_hire(l_record,
                        p_processing_bulk(i).err_code,
                        p_processing_bulk(i).err_message,
                        l_person_id,
                        l_assignment_id);
          --xx_debug(' finished called new hire', sysdate);
        elsif l_Record.Event_name in
              ('HR_TERMINATION_CHANGE', 'HR_REVERSE_TERMINATION') then
          -- Considering we know to capture these events.
          call_termination_cng(p_employee_rec => l_record,
                               p_err_code     => p_processing_bulk(i)
                                                 .err_code,
                               p_err_text     => p_processing_bulk(i)
                                                 .err_message);
          null;
          --elsif  l_Record.Event_name in ('HR_CNG_HIREDATE') then -- (and HR_CHANGE_HIREDATE and HR_TERMINATION_CHG_DATE, hr_reverse_termination)
          --call_update_hiredate(p_employee_rec => l_record, p_event_type => 'HR_DATACHANGE', p_err_code => p_processing_bulk(i).err_code, p_err_text => p_processing_bulk(i).err_message, p_person_id => l_person_id, p_assignment_id => l_assignment_id);
          --  null;
        elsif l_Record.Event_name = 'HR_DATACHANGE' then
          -- (and HR_CHANGE_HIREDATE and HR_TERMINATION_CHG_DATE, hr_reverse_termination)
          call_data_update(p_employee_rec  => l_record,
                           p_err_code      => p_processing_bulk(i).err_code,
                           p_err_text      => p_processing_bulk(i).err_message);
        elsif l_record.Event_name = 'HR_TERMINATION' then
          if l_record.Sub_event = 'THC' then
            -- Cancel hire
            call_cancel_hire(p_employee_rec  => l_record,
                             p_err_code      => p_processing_bulk(i).err_code,
                             p_err_text      => p_processing_bulk(i)
                                                .err_message);
          else
            call_termination(p_employee_rec  => l_record,
                             p_err_code      => p_processing_bulk(i).err_code,
                             p_err_text      => p_processing_bulk(i)
                                                .err_message);
          end if;
        elsif l_record.Event_name = 'HR_REHIRE' then
          call_rehire(p_employee_rec  => l_record,
                      p_err_code      => p_processing_bulk(i).err_code,
                      p_err_text      => p_processing_bulk(i).err_message,
                      p_person_id     => l_person_id);

           -- if EMPG or ICT call a second time after termination done.
          if l_record.Sub_event in ('EMPG', 'ICT') and p_processing_bulk(i).err_code = 2  then  -- CHG0042593 : Special rehire fix (process comes in one or two gos)
               call_rehire(p_employee_rec  => l_record,
               p_err_code      => p_processing_bulk(i).err_code,
               p_err_text      => p_processing_bulk(i).err_message,
               p_person_id     => l_person_id);
          end if;
        elsif l_record.Event_name = 'HR_CANCELHIRE' then
          call_cancel_hire(p_employee_rec  => l_record,
                           p_err_code      => p_processing_bulk(i).err_code,
                           p_err_text      => p_processing_bulk(i)
                                              .err_message);
        else
          p_processing_bulk(I).err_message := 'Invalid event received';
          p_processing_bulk(i).err_code := 1; -- error
        end if;

        if p_processing_bulk(i).err_code = 0 then
          commit;
        else
          rollback;
        end if;

        if p_processing_bulk(i).err_code = 1 then
          -- set error for employee in this bulk
          l_ignore_emps_t(l_employee_id) := 'Error for employee';
        end if;

      else
        -- skip employee if error in this bulk
        p_processing_bulk(I).err_message := 'Ignore - Error on other transaction for same employee in same bulk';
        p_processing_bulk(i).err_code := 1; -- error

      end if;
      -- if error for this employee, ignore all next messages for this employee.

    end loop;
    null;
    p_error_code := 0; -- actual results are in TOR records
  exception
    when others then
      p_error_code    := -1;
      p_error_message := 'Error invoking SF 2 HR Interface - ' || SUBSTR(sqlerrm, 1, 255);
  end process_employees;
end XXHR_API_PKG;
/
