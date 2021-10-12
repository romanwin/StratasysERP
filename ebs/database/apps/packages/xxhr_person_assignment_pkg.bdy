create or replace package body xxhr_person_assignment_pkg is
--------------------------------------------------------------------
--  name:            XXHR_PERSON_ASSIGNMENT_PKG
--  create by:       Dalit A. Raviv
--  Revision:        1.2
--  creation date:   28/11/2010 1:30:11 PM
--------------------------------------------------------------------
--  purpose :        HR project - Handle Person assignment details
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  28/11/2010  Dalit A. Raviv    initial build
--  1.1  12/06/2011  Dalit A. Raviv    New function get_person_name_by_ass_id
--                                     By assignment id return person full name
--  1.2  06/02/2014  Dalit A. Raviv    function get_is_vp_and_up - add 'Sr VP', 'CFO' grades 
--------------------------------------------------------------------

  --g_go_live_date  date := sysdate;
  --------------------------------------------------------------------
  --  name:            get_assg_object_version_number
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   28/11/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        get assignment object version number
  --                   by ass_id and date
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  28/11/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  function get_assg_object_version_number (p_assg_id        number,
                                           p_effective_date date)  return number is

    l_assg_ovn                   number(15):= null;

  begin
    select object_version_number
    into   l_assg_ovn
    from   per_all_assignments_f
    where  assignment_id    = p_assg_id
    and    p_effective_date between effective_start_date and effective_end_date;

    return(l_assg_ovn);

  exception
    when OTHERS then
      return null;
  end get_assg_object_version_number;

  --------------------------------------------------------------------
  --  name:            get_assg_status_type_id
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   28/11/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        get assignment_status_type_id for US
  --                   get user status name return status id
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  28/11/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  function get_assg_status_type_id (p_assg_user_status  varchar2) return number is

    l_assignment_status_type_id number(15);

  begin
    select t.assignment_status_type_id
    into   l_assignment_status_type_id
    from   per_assignment_status_types_tl t
    where  t.user_status                  = p_assg_user_status
    and    t.language                     = 'US';

    return l_assignment_status_type_id;

  exception
    when others then
      return null;
  end get_assg_status_type_id;

  --------------------------------------------------------------------
  --  name:            get_primary_assignment_id
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   28/11/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        get assignment_id by person_id and effective date
  --                   return primary assignment_id
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  28/11/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  function get_primary_assignment_id (p_person_id      in number,
                                      p_effective_date in date,
                                      p_bg_id          in number) return number is

  l_assignment_id number(10):= null;

  begin
    select paaf.assignment_id
    into   l_assignment_id
    from   per_all_assignments_f     paaf
    where  paaf.business_group_id +0 = p_bg_id
    and    paaf.person_id            = p_person_id
    and    paaf.primary_flag         = 'Y'
    and    paaf.assignment_type      in ('E','C')
    and    p_effective_date          between paaf.effective_start_date
                                     and     paaf.effective_end_date;

    return l_assignment_id;

  exception
    when others then
      return null;
  end get_primary_assignment_id;

  --------------------------------------------------------------------
  --  name:            get_grade_by_job
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   28/11/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        get grade id by job id
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  28/11/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  function get_grade_by_job (p_job_id in number) return number is

    l_grade_id number := null;

  begin
    select grade_id --, pg.name , pj.name
    into   l_grade_id
    from   per_grades pg,
           per_jobs   pj
    where  pg.name    = pj.name
    and    pj.job_id  = p_job_id;

    return l_grade_id;

  exception
    when others then
      return null;
  end get_grade_by_job;

  --------------------------------------------------------------------
  --  name:            Update_Ass_Job_Position
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   28/11/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Update_Ass_Job_Position -- for reference
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  28/11/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure update_ass_job_position is

    l_jobid                         number;
    l_positionid                    number;
    l_assg_effective_start_date     date;
    l_assg_effective_end_date       date;
    l_special_ceiling_step_id       number(15)   := null;
    l_people_group_id               number(15)   := null;
    l_group_name                    varchar2(100):= null;
    l_org_now_no_manager_warning    boolean;
    l_other_manager_warning         boolean;
    l_spp_delete_warning            boolean;
    l_entries_changed_warning       varchar2(30);
    l_tax_district_changed_warning  boolean;
    l_error                         varchar2(1000);

    cursor getass is
      -- to add hassava table to this select
      select a.assignment_id,
             a.effective_start_date,
             a.object_version_number ,
             a.people_group_id,
             a.person_id,
             b.employee_number,
             b.attribute11,
             b.attribute12
      from   per_all_assignments_f a,
             per_all_people_f      b
      where  (a.job_id             is not null or a.position_id is not null)
      and    a.person_id           = b.person_id;

  begin
    dbms_output.put_line('begin update_job_ass at: '||to_char(SYSDATE,'dd/mm/yyyy hh24:mi:ss'));
    for cuurentrec in getass loop

       l_jobid      := null; --- to get this value from the excel we get
       l_positionid := null; --- to get this value from the excel we get

       hr_assignment_api.update_emp_asg_criteria(
                          p_effective_date               => CuurentRec.effective_start_date,
                          p_datetrack_update_mode        => 'CORRECTION',
                          p_assignment_id                => CuurentRec.assignment_id,
                          p_object_version_number        => CuurentRec.object_version_number,
                          p_job_id                       => l_jobid,
                          p_position_id                  => l_positionid,
                          p_effective_start_date         => l_assg_effective_start_date, -- out date
                          p_effective_end_date           => l_assg_effective_end_date,   -- out date
                          p_special_ceiling_step_id      => l_special_ceiling_step_id,   -- in out
                          p_people_group_id              => l_people_group_id,           -- out
                          p_group_name                   => l_group_name,                -- out
                          p_org_now_no_manager_warning   => l_org_now_no_manager_warning,
                          p_other_manager_warning        => l_other_manager_warning,
                          p_spp_delete_warning           => l_spp_delete_warning,
                          p_entries_changed_warning      => l_entries_changed_warning,
                          p_tax_district_changed_warning => l_tax_district_changed_warning);


    end loop;
    dbms_output.put_line('end update_job_ass at: '||to_char(SYSDATE,'dd/mm/yyyy hh24:mi:ss'));

  exception
    when others then
      l_error := sqlerrm;
      dbms_output.put_line('error ' ||substr(l_error,1,100));

  end update_ass_job_position;

  --------------------------------------------------------------------
  --  name:            update_emp_asg_criteria
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   10/01/2011
  --------------------------------------------------------------------
  --  purpose :        procedure that use API to update person assignment
  --                   with payroll data and pay basis data
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  10/01/2011  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure update_emp_asg_criteria (p_start_date    in  date,
                                     p_assg_id       in  number,
                                     p_bg_id         in  number,
                                     p_pay_basis_id  in  number,
                                     p_err_code      out varchar,
                                     p_err_desc      out varchar2) is

    l_assg_ovn                      number       := null;
    l_payroll_id                    number       := null;
    --l_pay_basis_id                  number       := null;
    l_assg_effective_start_date     date;
    l_assg_effective_end_date       date;
    l_special_ceiling_step_id       number(15)   := null;
    l_people_group_id               number(15)   := null;
    l_group_name                    varchar2(100):= null;
    l_org_now_no_manager_warning    boolean;
    l_other_manager_warning         boolean;
    l_spp_delete_warning            boolean;
    l_entries_changed_warning       varchar2(30);
    l_tax_district_changed_warning  boolean;
  begin
    -- Get object version number
    select max(paaf.object_version_number)
    into   l_assg_ovn
    from   per_all_assignments_f paaf
    where  paaf.assignment_id    = p_assg_id
    and    p_start_date          between paaf.effective_start_date and paaf.effective_end_date;

    -- Get payroll id of Hargal
    select --p.payroll_name payroll,
           p.payroll_id
    into   l_payroll_id
    from   pay_payrolls_f          p
    where  p.business_group_id + 0 = p_bg_id
    and    p_start_date            between p.effective_start_date and  p.effective_end_date
    and    p.payroll_name          = 'Hargal';
    --order by p.payroll_name
    /*
    -- Get Pay_basis_id (Salary Basis)
    -- Basis Plus Over Time, Global, Hourly
    select --pb.name                  salary_basis,
           --pb.pay_basis,            pay_basis     -- MONTHLY / HOURLY
           pb.pay_basis_id
    into   l_pay_basis_id
    from   per_pay_bases            pb,
           pay_input_values_f       iv
    where  pb.business_group_id + 0 = p_bg_id
    and    pb.input_value_id        = iv.input_value_id
    and    p_start_date             between iv.effective_start_date and iv.effective_end_date
    and    pb.name                  = p_pay_basis
    order by pb.name;*/

    hr_assignment_api.update_emp_asg_criteria(
                p_effective_date               => p_start_date,                   -- i   d
                p_datetrack_update_mode        => 'CORRECTION',                   -- i   v
                p_assignment_id                => p_assg_id,                      -- i   n
                p_object_version_number        => l_assg_ovn,                     -- i/o n
                --p_payroll_id                   => l_payroll_id,                   -- i   n
                p_pay_basis_id                 => p_pay_basis_id,                 -- i   n
                p_effective_start_date         => l_assg_effective_start_date,    -- o   d
                p_effective_end_date           => l_assg_effective_end_date,      -- o   d
                p_special_ceiling_step_id      => l_special_ceiling_step_id,      -- i/o n
                p_people_group_id              => l_people_group_id,              -- o   n
                p_group_name                   => l_group_name,                   -- o   v
                p_org_now_no_manager_warning   => l_org_now_no_manager_warning,   -- o   b
                p_other_manager_warning        => l_other_manager_warning,        -- o   b
                p_spp_delete_warning           => l_spp_delete_warning,           -- o   b
                p_entries_changed_warning      => l_entries_changed_warning,      -- o   v
                p_tax_district_changed_warning => l_tax_district_changed_warning);-- o   b

    commit;
    p_err_code := 0;
    p_err_desc := null;
  exception
    when others then
      rollback;
      p_err_code := 1;
      p_err_desc := 'update_emp_asg_criteria - API Failed - '||substr(sqlerrm,1,950);
  end update_emp_asg_criteria;

  --------------------------------------------------------------------
  --  name:            get_salary_basis_exist
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   03/01/2011
  --------------------------------------------------------------------
  --  purpose :        get_salary_basis_exist by employee number and effective date
  --                   return Y/N
  --                   get salary basis from person assignment.
  --                   if no salary basis connect to this person return N
  --                   else return Y
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  03/01/2011  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  function get_salary_basis_exist (p_emp_num         varchar2,
                                   p_effective_date  date   default trunc(sysdate),
                                   p_bg_id           number default 0) return varchar2 is

  l_pay_basis_id number(10):= null;

  begin
    select paaf.pay_basis_id
    into   l_pay_basis_id
    from   per_all_people_f          papf,
           per_all_assignments_f     paaf
    where  papf.employee_number      = p_emp_num
    and    papf.business_group_id +0 = p_bg_id
    and    p_effective_date          between papf.effective_start_date
                                     and     papf.effective_end_date
    and    paaf.person_id            = papf.person_id
    and    paaf.primary_flag         = 'Y'
    and    p_effective_date          between paaf.effective_start_date
                                     and     paaf.effective_end_date;

    if l_pay_basis_id is null then
      return 'N';
    else
      return 'Y';
    end if;

  exception
    when others then
      return sqlerrm;
  end get_salary_basis_exist;

  --------------------------------------------------------------------
  --  name:            get_salary_basis_by_ass
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   06/01/2011
  --------------------------------------------------------------------
  --  purpose :        get_salary_basis_by_ass by assignment_id and effective date
  --                   return Y/N
  --                   get salary basis from person assignment.
  --                   if no salary basis connect to this person return N
  --                   else return Y
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  06/01/2011  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  function get_salary_basis_by_ass (p_assignment_id   in number,
                                    p_effective_date  date   default trunc(sysdate),
                                    p_bg_id           number default 0) return varchar2 is

  l_pay_basis_id number(10):= null;

  begin
    select paaf.pay_basis_id
    into   l_pay_basis_id
    from   per_all_assignments_f     paaf
    where  paaf.business_group_id +0 = nvl(p_bg_id, 0)
    and    paaf.primary_flag         = 'Y'
    and    paaf.assignment_id        = p_assignment_id
    and    p_effective_date          between paaf.effective_start_date
                                     and     paaf.effective_end_date;

    if l_pay_basis_id is null then
      return 'N';
    else
      return 'Y';
    end if;

  exception
    when others then
      return sqlerrm;
  end get_salary_basis_by_ass;

  --------------------------------------------------------------------
  --  name:            get_salary_basis_by_emp_num
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   03/02/2011
  --------------------------------------------------------------------
  --  purpose :        get_salary_basis_by_emp_num by employee_number and effective date
  --                   return employee pay basis (pay_basis_id)
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  03/02/2011  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  function get_salary_basis_by_emp_num (p_employee_number in varchar2,
                                        p_effective_date  in date     default trunc(sysdate),
                                        p_bg_id           in number   default 0) return number is

  l_pay_basis_id number(10):= null;

  begin
    select paaf.pay_basis_id
    into   l_pay_basis_id
    from   per_all_assignments_f     paaf,
           per_all_people_f          papf
    where  paaf.business_group_id +0 = nvl(p_bg_id, 0)
    and    papf.business_group_id +0 = nvl(p_bg_id, 0)
    and    papf.person_id            = paaf.person_id
    and    p_effective_date          between paaf.effective_start_date
                                     and     paaf.effective_end_date
    and    p_effective_date          between papf.effective_start_date
                                     and     papf.effective_end_date
    and    papf.employee_number      = p_employee_number
    and    paaf.primary_flag         = 'Y';

    return l_pay_basis_id;
-- hr_general.DECODE_PAY_BASIS(61)
  exception
    when others then
      return null;
  end get_salary_basis_by_emp_num;

  --------------------------------------------------------------------
  --  name:            get_is_vp_and_up
  --  create by:       Dalit A. Raviv
  --  Revision:        1.3
  --  creation date:   06/01/2011
  --------------------------------------------------------------------
  --  purpose :        get_is_vp_and_up by person_id and effective date
  --                   return Y/N
  --                   if VP , EVP, CTO, CEO all these we do not want
  --                   the salary information will be at oracle.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  06/01/2011  Dalit A. Raviv    initial build
  --  1.1  05/07/2011  Dalit A. Raviv    add grade President
  --  1.2  04/06/2012  Dalit A. Raviv    add COO grade
  --  1.3  06/02/2014  Dalit A. Raviv    add  'Sr VP', 'CFO' grades 
  --------------------------------------------------------------------
  function get_is_vp_and_up (p_person_id in number,
                             p_date      in date ) return varchar2 is

    l_grad varchar2(240) := null;
  begin
    select pg.name
    into   l_grad
    from   per_all_assignments_f paaf,
           per_grades            pg
    where  paaf.grade_id         = pg.grade_id
    and    trunc(p_date)         between paaf.effective_start_date and paaf.effective_end_date
    and    paaf.person_id        = p_person_id
    and    paaf.primary_flag     = 'Y'
    and    pg.name               in ('VP', 'Sr VP', 'EVP', 'CFO', 'CTO', 'CEO','President','COO');
    --and    pg.name               not in ( 'Employee','TL' ,'Manager', 'Director');

    if l_grad is not null then
      return 'Y';
    else
      return 'N';
    end if;
  exception
    when others then
      return 'N';
  end get_is_vp_and_up;

  --------------------------------------------------------------------
  --  name:            get_position_exists
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   28/02/2011
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  28/02/2011  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  function get_position_exists (p_position_id in number,
                                p_date        in date) return varchar2 is
    l_exists varchar2(1) := null;
  begin
    select 'Y'
    into   l_exists
    from   per_all_assignments_f paa
    where  paa.position_id       = p_position_id
    and    p_date                between paa.effective_start_date and paa.effective_end_date;

    return l_exists;
  exception
    when too_many_rows then
      return 'Y';
    when others then
      return 'N';
  end get_position_exists;

  --------------------------------------------------------------------
  --  name:            upload_performance
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   06/03/2011
  --------------------------------------------------------------------
  --  purpose :        API to Upload Performance review
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  06/03/2011  Dalit A. Raviv    initial build - test
  --------------------------------------------------------------------
  procedure upload_performance (errbuf             out varchar2,
                                retcode            out varchar2,
                                --p_location         in  varchar2, --/UtlFiles/HR/PERFORMANCE
                                --p_filename         in  varchar2,
                                p_token1           in  varchar2) is

    l_p_performance_review_id  number  := null;
    l_ovn                      number  := null;
    l_next_review_date_warning boolean;
    --l_next_review_warning      varchar2(100) := null;
    l_err_code                 varchar2(10)  := null;
    l_err_message              varchar2(200) := null;
  begin
    errbuf  := null;
    retcode := 0;
    -- set apps_initialize
    fnd_global.APPS_INITIALIZE(user_id => 2470,resp_id => 21538 ,resp_appl_id => 800);
    -- set security token
    xxobjt_sec.upload_user_session_key    (p_pass        => p_token1,
                                           p_err_code    => l_err_code ,
                                           p_err_message => l_err_message);
    -- Call performance API
    hr_perf_review_api.create_perf_review (p_validate                       => false,
                                           p_performance_review_id          => l_p_performance_review_id, -- o n
                                           p_person_id                      => 861,                      -- i n
                                           p_review_date                    => sysdate/*to_date ('01-JAN-2011')*/,   -- i d
                                           p_performance_rating             => '40',                      -- i v
                                           p_object_version_number          => l_ovn,                     -- o n
                                           p_next_review_date_warning       => l_next_review_date_warning -- o b
                                          );
    commit;
    dbms_output.put_line('Sucess');

  exception
    when others then
      rollback;
      dbms_output.put_line('Error - '||substr(sqlerrm,1,240));
      errbuf  := 'Error - '||substr(sqlerrm,1,240);
      retcode := 1;
  end;

  --------------------------------------------------------------------
  --  name:            get_person_name_by_ass_id
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   12/06/2011
  --------------------------------------------------------------------
  --  purpose :        Function that by assignment id return person full name
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  12/06/2011  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  function get_person_name_by_ass_id (p_assignment_id in varchar2) return varchar2 is

    l_full_name varchar2(240) := null;

  begin
    /*select pap.full_name
    into   l_full_name
    from   per_all_assignments_f paa,
           per_all_people_f      pap
    where  paa.person_id         = pap.person_id
    and    sysdate               between pap.effective_start_date and pap.effective_end_date
    and    paa.assignment_id     = to_number(p_assignment_id);*/
    select pap.full_name
    into   l_full_name
    from   per_all_assignments_f    paa,
           per_all_people_f         pap
    where  paa.person_id            = pap.person_id
    --and    trunc(sysdate)         between pap.effective_start_date and pap.effective_end_date
    --and    trunc(sysdate)         between paa.effective_start_date and paa.effective_end_date
    and    paa.effective_start_date between pap.effective_start_date and pap.effective_end_date
    and    paa.effective_start_date = (select max(paa1.effective_start_date)
                                       from   per_all_assignments_f paa1
                                       where  paa1.assignment_id     = paa.assignment_id)
    and    paa.assignment_id        = to_number(p_assignment_id);

    return l_full_name;

    return l_full_name;
  exception
    when others then
      return null;
  end get_person_name_by_ass_id;

end XXHR_PERSON_ASSIGNMENT_PKG;
/
