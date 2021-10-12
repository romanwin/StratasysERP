CREATE OR REPLACE PACKAGE xxhr_util_pkg AUTHID CURRENT_USER IS

  --------------------------------------------------------------------
  --  name:            XXHR_UTIL_PKG
  --  create by:       Dalit A. Raviv
  --  Revision:        1.8
  --  creation date:   29/11/2010 10:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        HR project - Handle Person details
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  29/11/2010  Dalit A. Raviv    initial build
  --  1.1  10/10/2011  Dalit A. Raviv    add function get_company_name
  --  1.2  19/11/2012  yuval tal         Add get_position_id
  --  1.3  21/11/2012  Dalit A. Raviv    add function get_position_is_top_approver
  --                                         function get_person_organization_id
  --  1.4  21/01/2013  Dalit A. Raviv    add function get_person_mng_by_level
  --  1.5  30/01/2013  Dalit A. Raviv    add function get_person_assignment_id
  --                                                  get_assignment_account_seg
  --                                                  get_assignment_department_seg
  --                                                  get_assignment_company_seg
  --  1.6  06/03/2013  Dalit A. Raviv    add function get_tas_mng_by_level, get_tas_person_by_grade
  --  1.7  24/06/2013  Dalit A. Raviv    add function get_personal_email_address
  --  1.8  27/06/2013  Dalit A. Raviv    add AUTHID CURRENT_USER to the package name (at spec level)
  --  1.9  17/07/2013  Dalit A. Raviv    add function get_suppervisor
  --  1.9  06/08/2014  Michal Tzvik      CHG0032506: add function get_person_top_vp
  --  2.0  26/01/2016  Adi Safin         CHG0037574: add function get_tas_third_approval_mng
  --------------------------------------------------------------------

  --------------------------------------------------------------------
  --  name:            get_business_group_id
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   28/11/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        get business_group_id
  --                   by ass_id and date
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  28/11/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_business_group_id RETURN NUMBER;

  --------------------------------------------------------------------
  --  name:            get_person_id_by_ni
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   29/11/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        get person id by national_identifier
  --  in params:       p_national_identifier - will hold national_identifier
  --                   p_effective_date      - the effective date we want to get the data from
  --                   p_bg_id               - business_group_id
  --  Return:          Person_id
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  29/11/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_person_id_by_ni(p_national_identifier VARCHAR2,
		       p_effective_date      DATE DEFAULT trunc(SYSDATE),
		       p_bg_id               NUMBER DEFAULT 0)
    RETURN NUMBER;

  --------------------------------------------------------------------
  --  name:            get_person_id_by_en
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   29/11/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        get person id by employee number
  --  in params:       p_emp_number      - will hold employee number
  --                   p_effective_date  - the effective date we want to get the data from
  --                   p_bg_id           - business_group_id
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  29/11/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_person_id_by_en(p_emp_number     VARCHAR2,
		       p_effective_date DATE DEFAULT trunc(SYSDATE),
		       p_bg_id          NUMBER DEFAULT 0)
    RETURN NUMBER;

  --------------------------------------------------------------------
  --  name:            get_person_id_by_fn
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   29/11/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        get person id by employee number
  --  in params:       p_full_name       - will hold employee full name
  --                   p_effective_date  - the effective date we want to get the data from
  --                   p_bg_id           - business_group_id
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  29/11/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_person_id_by_fn(p_full_name      VARCHAR2,
		       p_effective_date DATE DEFAULT trunc(SYSDATE),
		       p_bg_id          NUMBER DEFAULT 0)
    RETURN NUMBER;

  --------------------------------------------------------------------
  --  name:            get_person_full_name
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   29/11/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        get persion full name by person id
  --  in params:       p_person_id
  --                   p_bg_id          - business_group_id
  --                   p_effective_date
  --  Return:          full_name
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  29/11/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_person_full_name(p_person_id      NUMBER,
		        p_effective_date DATE DEFAULT trunc(SYSDATE),
		        p_bg_id          NUMBER DEFAULT 0)
    RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:            get_job_id
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   29/11/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        get job id by job name
  --  in params:       p_job_name  - job name
  --                   p_bg_id     - business_group_id
  --  Return:          job_id
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  29/11/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_job_id(p_job_name VARCHAR2,
	          p_bg_id    NUMBER DEFAULT 0) RETURN NUMBER;

  --------------------------------------------------------------------
  --  name:            get_job_name
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   29/11/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        get job name by job id
  --  in params:       p_job_id  - job id
  --                   p_bg_id   - business_group_id
  --  return:          job name
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  29/11/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_job_name(p_job_id NUMBER,
		p_bg_id  NUMBER DEFAULT 0) RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:            get_person_job_name
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   09/11/2011
  --------------------------------------------------------------------
  --  purpose :        get job name by person id
  --  in params:       p_person_id  - job id
  --                   p_bg_id      - business_group_id
  --                   p_eff_date   -
  --  return:          job name
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  09/11/2011  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_person_job_name(p_person_id      IN NUMBER,
		       p_effective_date IN DATE DEFAULT trunc(SYSDATE),
		       p_bg_id          IN NUMBER DEFAULT 0)
    RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:            get_org_id
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   29/11/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        get org id org name
  --  in params:       p_org_name - org name
  --                   p_bg_id    - business_group_id
  --  return:          organization id
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  29/11/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_org_id(p_org_name VARCHAR2,
	          p_bg_id    NUMBER DEFAULT 0) RETURN NUMBER;

  --------------------------------------------------------------------
  --  name:            get_org_id
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   29/11/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        get org name by org id
  --  in params:       p_org_id - org id
  --                   p_bg_id  - business_group_id
  --  return:          organization name
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  29/11/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_org_name(p_org_id NUMBER,
		p_bg_id  NUMBER DEFAULT 0) RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:            get_lookup_code
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   29/11/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        get lookup code by type and meanung
  --  in params:       p_org_id - org id
  --                   p_bg_id  - business_group_id
  --  return:          organization name
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  29/11/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_lookup_code(p_lookup_type    VARCHAR2,
		   p_lookup_meaning VARCHAR2) RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:            get_location_code
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   23/12/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        get get_location_code by person id
  --  in params:       p_person_id - person id
  --                   p_org_id    - org id
  --                   p_bg_id     - business_group_id
  --  return:          location code
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  23/12/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_location_code(p_person_id      IN NUMBER,
		     p_effective_date IN DATE DEFAULT trunc(SYSDATE),
		     p_bg_id          IN NUMBER DEFAULT 0)
    RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:            get_position_name
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   23/12/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        get get_position_name by person id
  --  in params:       p_person_id - person id
  --                   p_org_id    - org id
  --                   p_bg_id     - business_group_id
  --  return:          location code
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  23/12/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_position_name(p_person_id      IN NUMBER,
		     p_effective_date IN DATE DEFAULT trunc(SYSDATE),
		     p_bg_id          IN NUMBER DEFAULT 0)
    RETURN VARCHAR2;
  --------------------------------------------------------------------
  --  name:            get_position_id
  --  create by:       yuval tal
  --  Revision:        1.0
  --  creation date:   19.11.2012
  --------------------------------------------------------------------
  --  purpose :        get get_position_id by person id
  --  in params:       p_person_id - person id
  --                   p_org_id    - org id
  --                   p_bg_id     - business_group_id
  --  return:          location code
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  19.11.2012  yuval tal    initial build
  --------------------------------------------------------------------
  FUNCTION get_position_id(p_person_id      IN NUMBER,
		   p_effective_date IN DATE DEFAULT trunc(SYSDATE))
    RETURN NUMBER;

  --------------------------------------------------------------------
  --  name:            get_person_email
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   27/12/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        get_person_email by person id
  --  in params:       p_person_id
  --  return:          person person email address
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  27/12/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------
  FUNCTION get_person_email(p_person_id NUMBER) RETURN VARCHAR2;
  --------------------------------------------------------------------
  --  name:            get_person_org_name
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   27/12/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        get_person_org_name by person id
  --  in params:       p_person_id
  --  return:          person assignment organization name
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  27/12/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_person_org_name(p_person_id IN NUMBER) RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:            get_person_org_name
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   31/03/2011 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        get_person_org_name by person id date and business_group_id
  --  in params:       p_person_id, p_effective_date, p_bg_id
  --  return:          person assignment organization name per date
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  31/03/2011  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_person_org_name(p_person_id      IN NUMBER,
		       p_effective_date IN DATE DEFAULT trunc(SYSDATE),
		       p_bg_id          IN NUMBER) RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:            get_parent_org_id
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   27/12/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        get_parent_org_id by child organization id
  --  in params:       p_child_org_id
  --  return:          parent organization id
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  27/12/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_parent_org_id(p_child_org_id IN NUMBER) RETURN NUMBER;

  --------------------------------------------------------------------
  --  name:            get_organization_by_hierarchy
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   29/12/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        get_organization_by_hierarchy by organization id
  --  in params:       p_organization id
  --                   p_entity    - NAME return organization name
  --                                 ID   return organization id
  --                   p_type      - DIV      -> Division
  --                                 HRDEP    -> Department
  --                                 TER      -> Territory
  --                                 TOP_ORG  -> Top Organization
  --  return:          the up organization by the type send to function
  --                   sample organization 214 is a department of 208 (DIV)
  --                   and i ask to see the TER i will get 81 (IL)
  --                   if i send 208 and ask for HRDEP - 208 is a DIV higer level then ask
  --                   in this case the retun is Lower Level or -1
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  29/12/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_organization_by_hierarchy(p_organization_id IN NUMBER,
			     p_type            IN VARCHAR2,
			     p_entity          IN VARCHAR2)
    RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:            get_organization_type
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   28/12/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        get_organization_type by organization id
  --  in params:       p_organization id
  --  return:          organization type
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  28/12/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_organization_type(p_organization_id IN NUMBER) RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:            get_org_hr_divisional_person
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   30/12/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        get_org_hr_divisional_person by organization id,
  --                   each organization will hold at the DFF attribute2
  --                   the name of the HR manager that responsibile for
  --                   this organization.
  --  in params:       p_organization id
  --  return:          Attribute2 - HR divisional person id
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  30/12/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_org_hr_divisional_person(p_organization_id IN NUMBER)
    RETURN NUMBER;

  --------------------------------------------------------------------
  --  name:            get_hr_divisional_permit
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   30/12/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        get_hr_divisional_permit by organization id,
  --                   This function check the HR divisional person and
  --                   will compare to the user - person id.
  --                   this will give the ability to distingvish between
  --                   Sagit Population to Michal Population.
  --  in params:       p_organization id
  --  return:          Y have permission to see this person
  --                   N dont have permission to see this person
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  30/12/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_hr_divisional_permit(p_organization_id IN NUMBER,
			p_user_id         IN NUMBER DEFAULT NULL)
    RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:            get_user_person_id
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   30/12/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        get_user_person_id by user id,
  --                   each user have employee that attch to the user.
  --                   this function return the employee (person) of the user
  --  in params:       p_user_id
  --  return:          employee id (person id)
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  30/12/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_user_person_id(p_user_id IN NUMBER) RETURN NUMBER;

  --------------------------------------------------------------------
  --  name:            get_payroll_name
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   18/05/2011
  --------------------------------------------------------------------
  --  purpose :        get payroll name by id
  --  in params:       p_payroll_id
  --  return:          payroll name
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  18/05/2011  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_payroll_name(p_payroll_id IN NUMBER) RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:            get_company_name
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   10/10/2011 1:45:30 PM
  --------------------------------------------------------------------
  --  purpose :        CUST460 - Active directory interface
  --
  --                   Get company name by location of the person (from assignment)
  --                   determin the company name she/he belong too.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  10/10/2011  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_company_name(p_location_id IN NUMBER) RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:            get_position_is_top_approver
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   21/11/2012 1:45:30 PM
  --------------------------------------------------------------------
  --  purpose :        use for Head count report
  --
  --                   Get  position id and return if this position
  --                   is a top approver position.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  21/11/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_position_is_top_approver(p_position_id IN NUMBER)
    RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:            get_person_organization_id
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   21/11/2012 1:45:30 PM
  --------------------------------------------------------------------
  --  purpose :        By person organization i can know who is the
  --                   HR divisional focal point person
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  21/11/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_person_organization_id(p_person_id IN NUMBER) RETURN NUMBER;

  --------------------------------------------------------------------
  --  name:            get_person_mng_by_level
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   21/01/2013
  --------------------------------------------------------------------
  --  purpose :        get person suppervisor information by level
  --                   if level = 1 the suppervisor will be the direct one
  --                   if level = 2 the suppervisor will be the second suppervisor for the person etc'
  --                   p_entity = ID   will return suppervisor id
  --                            = NUM  will return suppervisor employee number.
  --                            = NAME will return suppervisor full name
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  21/01/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_person_mng_by_level(p_person_id IN NUMBER,
		           p_level     IN NUMBER,
		           p_entity    IN VARCHAR2) RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:            get_person_assignment_id
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   30/01/2013
  --------------------------------------------------------------------
  --  purpose :        by person id and date get the assignemnt connect to.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  30/01/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_person_assignment_id(p_person_id      IN NUMBER,
			p_effective_date IN DATE) RETURN NUMBER;

  --------------------------------------------------------------------
  --  name:            get_assignment_account_seg
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   30/01/2013
  --------------------------------------------------------------------
  --  purpose :        by assignmant id get the account segment
  --                   p_entity = CODE  will return account code
  --                            = DESC  will return account code description
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  30/01/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_assignment_account_seg(p_assignment_id IN NUMBER,
			  p_entity        IN VARCHAR2)
    RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:            get_assignment_department_seg
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   30/01/2013
  --------------------------------------------------------------------
  --  purpose :        by assignmant id get the department segment
  --                   p_entity = CODE  will return department code
  --                            = DESC  will return department code description
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  30/01/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_assignment_department_seg(p_assignment_id IN NUMBER,
			     p_entity        IN VARCHAR2)
    RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:            get_assignment_company_seg
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   30/01/2013
  --------------------------------------------------------------------
  --  purpose :        by assignmant id get the company segment
  --                   p_entity = CODE  will return company code
  --                            = DESC  will return company code description
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  30/01/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_assignment_company_seg(p_assignment_id IN NUMBER,
			  p_entity        IN VARCHAR2)
    RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:            get_tas_mng_by_level
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   06/03/21013
  --------------------------------------------------------------------
  --  purpose :        the approval for Tas system is that TL do not approve,
  --                   and manager if she/he have director abouve do not approve either.
  --
  --  return           suppervisor_id by the level ask, consider with the logic of the approval.
  --
  --                   p_entity = ID   will return suppervisor id
  --                            = NUM  will return suppervisor employee number.
  --                            = NAME will return suppervisor full name
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  06/03/21013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_tas_mng_by_level(p_person_id IN NUMBER,
		        p_level     IN NUMBER,
		        p_entity    IN VARCHAR2) RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:            get_tas_person_by_grade
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   06/03/21013
  --------------------------------------------------------------------
  --  purpose :        i have grade, and i want to know who is the person relate to it.
  --
  --                   p_entity = ID   will return person id
  --                            = NUM  will return employee number.
  --                            = NAME will return full name
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  06/03/21013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_tas_person_by_grade(p_grade  IN VARCHAR2,
		           p_date   IN DATE,
		           p_entity IN VARCHAR2) RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:            get_tas_first_approval_mng
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   08/04/21013
  --------------------------------------------------------------------
  --  purpose :        The logic of the approval for TAS is:
  --                   the first manager that approve the TAS will be the
  --                   we decided the grade that the first person that hold grade unser the
  --                   grade decided is the first approval person.
  --
  --  return           suppervisor_id, consider with the logic of the approval.
  --
  --                   p_entity = ID   will return suppervisor id
  --                            = NUM  will return suppervisor employee number.
  --                            = NAME will return suppervisor full name
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  08/04/21013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_tas_first_approval_mng(p_person_id IN NUMBER,
			  p_entity    IN VARCHAR2)
    RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:            get_tas_second_approval_mng
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   08/04/21013
  --------------------------------------------------------------------
  --  purpose :        The logic of the approval for TAS is:
  --                   a. The first approver will be the highest hierarchy person that under VP.
  --                      (VP will define in profile)
  --                   b. The second approver will be the VP of the employee.
  --
  --  return           suppervisor_id, consider with the logic of the approval.
  --
  --                   p_entity = ID   will return suppervisor id
  --                            = NUM  will return suppervisor employee number.
  --                            = NAME will return suppervisor full name
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  08/04/21013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_tas_second_approval_mng(p_person_id IN NUMBER,
			   p_entity    IN VARCHAR2)
    RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:            get_tas_third_approval_mng
  --  create by:       Adi Safin
  --  Revision:        1.0
  --  creation date:   25/01/2016
  --------------------------------------------------------------------
  --  purpose :        CHG0037574 - The logic of the approval for TAS is:
  --                   a. The first approver will be the highest hierarchy person that under VP.
  --                      (VP will define in profile)
  --                   b. The second approver will be the VP of the employee.
  --                   c. The third approver will be the one above VP expept those that are mandatory approver for each flight
  --                   
  --  return           suppervisor_id, consider with the logic of the approval.
  --
  --                   p_entity = ID   will return suppervisor id
  --                            = NUM  will return suppervisor employee number.
  --                            = NAME will return suppervisor full name
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  25/01/2016  Adi Safin         initial build
  --------------------------------------------------------------------
  FUNCTION get_tas_third_approval_mng(p_person_id IN NUMBER,
			  p_entity    IN VARCHAR2)
    RETURN VARCHAR2;
  --------------------------------------------------------------------
  --  name:            get_personal_email_address
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   24/06/21013
  --------------------------------------------------------------------
  --  purpose :        get person private email address -
  --                   this information is important for the stock options
  --                   when employee end employment.
  --
  --  return           private email address
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  24/06/21013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_personal_email_address(p_person_id IN NUMBER) RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:            get_suppervisor_id
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   17/07/2013
  --------------------------------------------------------------------
  --  purpose :
  --
  --  return           suppervisor_id
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  17/07/2013  Dalit A. Raviv   initial build
  --------------------------------------------------------------------
  FUNCTION get_suppervisor_id(p_person_id      IN NUMBER,
		      p_effective_date IN DATE,
		      p_bg_id          IN NUMBER) RETURN NUMBER;

  --------------------------------------------------------------------
  --  name:            get_person_territory
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   17/07/2013
  --------------------------------------------------------------------
  --  purpose :
  --
  --  return           suppervisor_id
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  17/07/2013  Dalit A. Raviv   initial build
  --------------------------------------------------------------------
  FUNCTION get_person_territory(p_person_id IN NUMBER,
		        p_entity    IN VARCHAR2) RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:            get_person_top_mng
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   21/07/2013
  --------------------------------------------------------------------
  --  purpose :        The logic of the approval for Vacancy is:
  --                   a. The first approver will be the direct manager.
  --                   b. The second approver will be the TopManager the top manager under CEO.
  --
  --  return           suppervisor_id, consider with the logic of the approval.
  --
  --                   p_entity = ID   will return suppervisor id
  --                            = NUM  will return suppervisor employee number.
  --                            = NAME will return suppervisor full name
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  21/07/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_person_top_mng(p_person_id IN NUMBER,
		      p_entity    IN VARCHAR2) RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:            get_person_top_mng_by_lvl
  --  create by:       Michal Tzvik
  --  Revision:        1.0
  --  creation date:   06.08.2014
  --------------------------------------------------------------------
  --  purpose :        In case when 'VP' or 'Sr VP' level exists under p_grade_lvl (= EVP),
  --                   then they should also be part of approval hierarchy.
  --
  --  return           suppervisor_id, consider with the logic of the approval.
  --
  --                   p_entity = ID   will return suppervisor id
  --                            = NUM  will return suppervisor employee number.
  --                            = NAME will return suppervisor full name
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  06.08.2014  Michal Tzvik      initial build - CHG0032506
  --------------------------------------------------------------------
  FUNCTION get_person_top_mng_by_lvl(p_person_id IN NUMBER,
			 p_entity    IN VARCHAR2,
			 p_grade_lvl IN VARCHAR2) RETURN VARCHAR2;
END xxhr_util_pkg;
/
