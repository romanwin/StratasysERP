create or replace package xxhr_person_assignment_pkg AUTHID CURRENT_USER is

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
--  1.2  27/06/2013  Dalit A. Raviv    Handle HR packages and apps_view
--                                     add AUTHID CURRENT_USER to spec
--------------------------------------------------------------------  

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
                                           p_effective_date date)  return number ;
   
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
  function get_assg_status_type_id (p_assg_user_status  varchar2) return number;

  --------------------------------------------------------------------
  --  name:            get_primary_assignment_id
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   28/11/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        get assignment_id by employee number and effective date
  --                   return primary assignment_id
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  28/11/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  function get_primary_assignment_id (p_person_id      in number,
                                      p_effective_date in date,
                                      p_bg_id          in number) return number;
   
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
  function get_grade_by_job (p_job_id in number) return number;
    
  -------------------------------------------------------------------
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
                                     p_err_desc      out varchar2);
                                                                       
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
                                   p_bg_id           number default 0) return varchar2;
                                   
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
                                    p_bg_id           number default 0) return varchar2;                                                                       
                                    
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
                                        p_bg_id           in number   default 0) return number ;

    
  --------------------------------------------------------------------
  --  name:            get_is_vp_and_up
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   06/01/2011 
  --------------------------------------------------------------------
  --  purpose :        get_is_vp_and_up by person_id and effective date
  --                   return Y/N
  --                   if VP , EVP, CTO, CEO all these we do not want
  --                   the salary information will be at oracle.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  06/01/2011  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  function get_is_vp_and_up (p_person_id in number,
                             p_date      in date ) return varchar2;
                             
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
                                p_date        in date) return varchar2; 
                                
  procedure upload_performance (errbuf             out varchar2,
                                retcode            out varchar2,
                                --p_location         in  varchar2, --/UtlFiles/HR/PERFORMANCE
                                --p_filename         in  varchar2,
                                p_token1           in  varchar2); 
                                
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
  function get_person_name_by_ass_id (p_assignment_id in varchar2) return varchar2;                                                                                               

end XXHR_PERSON_ASSIGNMENT_PKG;

 
/
