CREATE OR REPLACE PACKAGE BODY xxhr_util_pkg IS
  --XXHR_PERSON_PKG, XXHR_UTIL_PKG
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
  --  1.4  30/12/2012  Dalit A. Raviv    function get_business_group_id
  --                                              change Objet Main Business Group to Stratasys Main Business Group
  --  1.5  21/01/2013  Dalit A. Raviv    add function get_person_mng_by_level
  --  1.6  30/01/2013  Dalit A. Raviv    add function get_person_assignment_id
  --                                                  get_assignment_account_seg
  --                                                  get_assignment_department_seg
  --                                                  get_assignment_company_seg
  --  1.7  06/03/2013  Dalit A. Raviv    add function get_tas_mng_by_level, get_tas_person_by_grade
  --  1.8  24/06/2013  Dalit A. Raviv    add function get_personal_email_address
  --                                     correct logic of get_company_name
  --  1.9  06/08/2014  Michal Tzvik      CHG0032506: add function get_person_top_vp
  --  2.0  26/01/2016  Adi Safin         CHG0037574: add function get_tas_third_approval_mng
  --  2.1  20-APR-2016 LSARANGI          CHG0038225 : Adjust 3rd approver in combtas
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
  --  1.1  30/12/2012  Dalit A. Raviv    change Objet Main Business Group to Stratasys Main Business Group
  --------------------------------------------------------------------
  FUNCTION get_business_group_id RETURN NUMBER IS

    --l_bg_id number(15) := null;

  BEGIN

    /*select     business_group_id
    into       l_bg_id
    from       hr_all_organization_units
    where name = 'Stratasys Main Business Group';

    return l_bg_id;*/
    --return HR_GENERAL.get_business_group_id;
    RETURN(fnd_profile.value('PER_BUSINESS_GROUP_ID'));

  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_business_group_id;

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
    RETURN NUMBER IS

    l_person_id NUMBER(10) := NULL;

  BEGIN
    SELECT person_id
    INTO   l_person_id
    FROM   per_all_people_f papf
    WHERE  papf.national_identifier = p_national_identifier
    AND    business_group_id + 0 = p_bg_id
    AND    p_effective_date BETWEEN effective_start_date AND
           effective_end_date;

    RETURN l_person_id;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_person_id_by_ni;

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
    RETURN NUMBER IS

    l_person_id NUMBER(10) := NULL;

  BEGIN
    SELECT person_id
    INTO   l_person_id
    FROM   per_all_people_f
    WHERE  employee_number = p_emp_number
    AND    business_group_id + 0 = p_bg_id
    AND    p_effective_date BETWEEN effective_start_date AND
           effective_end_date;

    RETURN l_person_id;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_person_id_by_en;

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
    RETURN NUMBER IS

    l_person_id NUMBER(10) := NULL;

  BEGIN
    SELECT person_id
    INTO   l_person_id
    FROM   per_all_people_f papf
    WHERE  papf.full_name = p_full_name
    AND    business_group_id + 0 = p_bg_id
    AND    p_effective_date BETWEEN effective_start_date AND
           effective_end_date;

    RETURN l_person_id;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_person_id_by_fn;

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
    RETURN VARCHAR2 IS

    l_full_name VARCHAR2(360) := NULL;

  BEGIN
    SELECT papf.full_name
    INTO   l_full_name
    FROM   per_all_people_f papf
    WHERE  papf.person_id = p_person_id
    AND    business_group_id + 0 = p_bg_id
    AND    p_effective_date BETWEEN effective_start_date AND
           effective_end_date;

    RETURN l_full_name;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_person_full_name;

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
            p_bg_id    NUMBER DEFAULT 0) RETURN NUMBER IS

    l_job_id NUMBER(15) := NULL;

  BEGIN
    SELECT pj.job_id
    INTO   l_job_id
    FROM   per_jobs pj
    WHERE  pj.name = p_job_name
    AND    pj.business_group_id + 0 = p_bg_id;

    RETURN l_job_id;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_job_id;

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
    p_bg_id  NUMBER DEFAULT 0) RETURN VARCHAR2 IS

    l_job_name VARCHAR2(700) := NULL;

  BEGIN
    SELECT pj.name
    INTO   l_job_name
    FROM   per_jobs pj
    WHERE  pj.job_id = p_job_id
    AND    pj.business_group_id + 0 = p_bg_id;

    RETURN l_job_name;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_job_name;

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
    RETURN VARCHAR2 IS

    l_job_name VARCHAR2(700) := NULL;
  BEGIN
    SELECT pj.name
    INTO   l_job_name
    FROM   per_all_people_f      pap,
           per_all_assignments_f papf,
           per_jobs              pj
    WHERE  pap.person_id = papf.person_id
    AND    p_effective_date BETWEEN pap.effective_start_date AND
           pap.effective_end_date
    AND    p_effective_date BETWEEN papf.effective_start_date AND
           papf.effective_end_date
    AND    pj.job_id = papf.job_id
    AND    papf.person_id = p_person_id
    AND    pap.business_group_id + 0 = p_bg_id
    AND    papf.assignment_type IN ('E', 'C')
    AND    papf.primary_flag = 'Y';

    RETURN l_job_name;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_person_job_name;

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
            p_bg_id    NUMBER DEFAULT 0) RETURN NUMBER IS

    l_org_id NUMBER(10) := NULL;

  BEGIN

    SELECT o.organization_id
    INTO   l_org_id
    FROM   hr_all_organization_units o
    WHERE  o.name = p_org_name
    AND    o.business_group_id = p_bg_id;

    RETURN l_org_id;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_org_id;

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
    p_bg_id  NUMBER DEFAULT 0) RETURN VARCHAR2 IS

    l_org_name VARCHAR2(240) := NULL;

  BEGIN

    SELECT o.name
    INTO   l_org_name
    FROM   hr_all_organization_units o
    WHERE  o.organization_id = p_org_id
    AND    o.business_group_id = p_bg_id;

    RETURN l_org_name;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_org_name;

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
       p_lookup_meaning VARCHAR2) RETURN VARCHAR2 IS

    l_code VARCHAR2(100) := NULL;

  BEGIN

    SELECT lookup_code
    INTO   l_code
    FROM   fnd_lookup_values
    WHERE  lookup_type = p_lookup_type
    AND    meaning = p_lookup_meaning
    AND    LANGUAGE = 'US';

    RETURN l_code;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_lookup_code;

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
    RETURN VARCHAR2 IS

    l_location_code VARCHAR2(60) := NULL;

  BEGIN
    SELECT hrloc.location_code --, pap.full_name
    INTO   l_location_code
    FROM   per_all_people_f      pap,
           per_all_assignments_f papf,
           hr_locations          hrloc
    WHERE  pap.person_id = papf.person_id
    AND    p_effective_date BETWEEN pap.effective_start_date AND
           pap.effective_end_date
    AND    p_effective_date BETWEEN papf.effective_start_date AND
           papf.effective_end_date
    AND    hrloc.location_id = papf.location_id
    AND    papf.person_id = p_person_id
    AND    pap.business_group_id + 0 = p_bg_id
    AND    papf.primary_flag = 'Y'
    AND    papf.assignment_type IN ('E', 'C');

    RETURN l_location_code;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_location_code;

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
    RETURN VARCHAR2 IS

    l_position_name VARCHAR2(240) := NULL;

  BEGIN
    SELECT pp.name position -- pap.full_name,
    INTO   l_position_name
    FROM   per_all_people_f      pap,
           per_all_assignments_f papf,
           per_all_positions     pp
    WHERE  pap.person_id = papf.person_id
    AND    p_effective_date BETWEEN pap.effective_start_date AND
           pap.effective_end_date
    AND    p_effective_date BETWEEN papf.effective_start_date AND
           papf.effective_end_date
    AND    pp.position_id = papf.position_id
    AND    pap.business_group_id = p_bg_id
    AND    pap.person_id = p_person_id
    AND    papf.primary_flag = 'Y'
    AND    papf.assignment_type IN ('E', 'C');

    RETURN l_position_name;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_position_name;

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
    RETURN NUMBER IS

    l_position_id NUMBER := NULL;

  BEGIN
    SELECT asg.position_id
    INTO   l_position_id
    FROM   per_all_assignments_f asg
    WHERE  asg.person_id = p_person_id
    AND    p_effective_date BETWEEN asg.effective_start_date AND
           asg.effective_end_date
    AND    asg.primary_flag = 'Y'
    AND    asg.assignment_type IN ('E', 'C');

    RETURN l_position_id;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_position_id;

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
  --------------------------------------------------------------------
  FUNCTION get_person_email(p_person_id NUMBER) RETURN VARCHAR2 IS

    l_mail VARCHAR2(200);

  BEGIN
    SELECT papf.email_address
    INTO   l_mail
    FROM   per_all_people_f papf
    WHERE  papf.person_id = p_person_id
    AND    trunc(SYSDATE) BETWEEN papf.effective_start_date AND
           papf.effective_end_date;

    RETURN l_mail;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;

  END get_person_email;

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
  FUNCTION get_person_org_name(p_person_id IN NUMBER) RETURN VARCHAR2 IS

    l_name hr_all_organization_units.name%TYPE; -- organization name

  BEGIN
    SELECT NAME
    INTO   l_name
    FROM   per_all_people_f          papf,
           per_all_assignments_f     paaf,
           hr_all_organization_units hao
    WHERE  papf.person_id = p_person_id
    AND    trunc(SYSDATE) BETWEEN papf.effective_start_date AND
           papf.effective_end_date
    AND    papf.person_id = paaf.person_id
    AND    trunc(SYSDATE) BETWEEN paaf.effective_start_date AND
           paaf.effective_end_date
    AND    paaf.organization_id = hao.organization_id
    AND    paaf.assignment_type IN ('E', 'C')
    AND    paaf.primary_flag = 'Y';

    RETURN(l_name);

  EXCEPTION
    WHEN no_data_found THEN
      RETURN(1);
    WHEN OTHERS THEN
      RETURN(2);

  END get_person_org_name;

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
           p_bg_id          IN NUMBER) RETURN VARCHAR2 IS

    l_name hr_all_organization_units.name%TYPE; -- organization name

  BEGIN

    SELECT NAME
    INTO   l_name
    FROM   per_all_people_f          papf,
           per_all_assignments_f     paaf,
           hr_all_organization_units hao
    WHERE  papf.person_id = p_person_id
    AND    p_effective_date BETWEEN papf.effective_start_date AND
           papf.effective_end_date
    AND    papf.person_id = paaf.person_id
    AND    p_effective_date BETWEEN paaf.effective_start_date AND
           paaf.effective_end_date
    AND    paaf.organization_id = hao.organization_id
    AND    paaf.business_group_id = nvl(p_bg_id, 0)
    AND    paaf.primary_flag = 'Y'
    AND    paaf.assignment_type IN ('E', 'C');

    RETURN(l_name);

  EXCEPTION
    WHEN no_data_found THEN
      RETURN(1);
    WHEN OTHERS THEN
      RETURN(2);

  END get_person_org_name;

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
  FUNCTION get_parent_org_id(p_child_org_id IN NUMBER) RETURN NUMBER IS

    l_org_id NUMBER;

  BEGIN

    SELECT organization_id_parent
    INTO   l_org_id
    FROM   per_org_structure_elements
    WHERE  organization_id_child = p_child_org_id;

    RETURN(l_org_id);

  EXCEPTION
    WHEN no_data_found THEN
      RETURN(-1);
    WHEN OTHERS THEN
      RETURN(-2);

  END get_parent_org_id;

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
    RETURN VARCHAR2 IS

    CURSOR get_org_c(p_organization_id IN NUMBER,
           p_org_struc_id    IN NUMBER) IS
    -- select that for specific organization bring all its up organizations
      SELECT --distinct
       el.organization_id_child organization_id,
       ou.name                  organization_name,
       ou.type                  organization_type
      FROM   per_org_structure_elements el,
   hr_all_organization_units  ou
      WHERE  el.org_structure_version_id = p_org_struc_id
      AND    nvl(el.business_group_id, 0) = 0
      AND    el.organization_id_child = ou.organization_id
      AND    trunc(SYSDATE) BETWEEN nvl(ou.date_from, SYSDATE - 1) AND
   nvl(ou.date_to, SYSDATE + 1)
      START  WITH el.organization_id_child = p_organization_id
           AND    el.org_structure_version_id = p_org_struc_id
      CONNECT BY PRIOR el.organization_id_parent = el.organization_id_child
          AND    el.org_structure_version_id = p_org_struc_id
      ORDER  BY LEVEL;

    l_flag              VARCHAR2(5) := 'N';
    l_organization_name VARCHAR2(240) := NULL;
    l_organization_type VARCHAR2(30) := NULL;
    l_organization_id   NUMBER := NULL;
    l_org_struc_id      NUMBER := NULL;

  BEGIN
    l_org_struc_id := fnd_profile.value('XXHR_ORG_STRUCTURE_VERSION_ID');
    FOR get_org_r IN get_org_c(p_organization_id, l_org_struc_id) LOOP
      l_organization_id   := get_org_r.organization_id;
      l_organization_name := get_org_r.organization_name;
      l_organization_type := get_org_r.organization_type;
      IF l_organization_type = p_type THEN
        l_flag := 'Y';
        EXIT;
      END IF;
    END LOOP;

    IF l_flag = 'Y' THEN
      IF p_entity = 'NAME' THEN
        RETURN l_organization_name;
      ELSIF p_entity = 'ID' THEN
        RETURN l_organization_id;
      END IF;
    ELSE
      IF p_entity = 'NAME' THEN
        RETURN 'Lower type';
      ELSIF p_entity = 'ID' THEN
        RETURN - 1;
      END IF;
    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      IF p_entity = 'NAME' THEN
        RETURN 'Lower type';
      ELSIF p_entity = 'ID' THEN
        RETURN - 1;
      END IF;
  END get_organization_by_hierarchy;
  --------------------------------------------------------------------
  --  name:            get_parent_org_by_entity
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   27/12/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        get_parent_org_by_entity by organization id
  --  in params:       p_organization_id - p_organization id
  --                   p_entity          - NAME return organization name
  --                                       ID   return organization id
  --                   p_type            - DIV      -> Division
  --                                       HRDEP    -> Department
  --                                       TER      -> Territory
  --                                       TOP_ORG  -> Top Organization
  --  return:          top organization id by p_entity
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  27/12/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  /*  function get_parent_org_by_entity (p_organization_id in number,
                                       p_type            in varchar2,
                                       p_entity          in varchar2) return varchar2 is

      l_mark               boolean       := true;
      l_organization_name  varchar2(240) := null;
      l_organization_type  varchar2(30)  := null;
      l_parent_org_id      number        := null;
      l_organization_id    number        := null;

      cursor get_pop_c (p_organization_id in number) is
        select u.organization_id          oragnization_id,
               u.name                     organization_name,
               u.type                     organization_type,
               el.organization_id_parent  parent_organization
        from   hr_all_organization_units  u,
               per_org_structure_elements el
        where  u.organization_id          = p_organization_id --214
        and    u.organization_id          = el.organization_id_child;

    begin
      -- if user want to know details of the TOP_ORG -> organization_id = 0
      if p_type = 'TOP_ORG' then
        select u.organization_id          oragnization_id,
               u.name                     organization_name,
               u.type                     organization_type
        into   l_organization_id,
               l_organization_name,
               l_organization_type
        from   hr_all_organization_units  u
        where  u.organization_id          = 0;
      else
        -- Check if p_type lower then the organization_type return Lower type
        l_organization_type := get_organization_type( p_organization_id);
        if (l_organization_type in ( 'DIV', 'TER', 'TOP_ORG') and p_type = 'HRDEP') or
           (l_organization_type in ( 'TER', 'TOP_ORG') and p_type = 'DIV') then
          if p_entity = 'NAME' then
            return 'Lower type';
          elsif p_entity = 'ID' then
            return -1;
          end if;
        end if;
        -- start to go by hierarchy and find the upper wanted organization by type
        while l_mark = TRUE loop
          -- get organization details
          for get_pop_r in get_pop_c (nvl(l_parent_org_id,p_organization_id)) loop
            l_organization_id   := get_pop_r.oragnization_id;
            l_organization_name := get_pop_r.organization_name;
            l_organization_type := get_pop_r.organization_type;
            l_parent_org_id     := get_pop_r.parent_organization;
          end loop;
          -- check exit loop
          if l_organization_type = p_type or l_organization_type = 'TER' then
            l_mark := FALSE;
          end if;
        end loop;
      end if;
      -- define return by entity
      if p_entity = 'NAME' then
        return l_organization_name||' - '||l_organization_id;
      elsif p_entity = 'ID' then
        return l_organization_id;
      end if;
    exception
      when others then
        return null;
    end get_parent_org_by_entity;
  */
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
  FUNCTION get_organization_type(p_organization_id IN NUMBER) RETURN VARCHAR2 IS

    l_type VARCHAR2(30) := NULL;
  BEGIN
    SELECT u.type organization_type
    INTO   l_type
    FROM   hr_all_organization_units u
    WHERE  u.organization_id = p_organization_id; --214

    RETURN l_type;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_organization_type;

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
    RETURN NUMBER IS

    l_hr_divisional_person NUMBER := NULL;

  BEGIN
    SELECT attribute2
    INTO   l_hr_divisional_person
    FROM   hr_all_organization_units ou
    WHERE  ou.organization_id = p_organization_id;

    RETURN l_hr_divisional_person;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_org_hr_divisional_person;

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
    RETURN VARCHAR2 IS

    l_hr_div_person  NUMBER := NULL;
    l_user_person_id NUMBER := NULL;

  BEGIN

    l_hr_div_person  := get_org_hr_divisional_person(p_organization_id);
    l_user_person_id := nvl(p_user_id,
        get_user_person_id(fnd_profile.value('USER_ID')));

    IF l_hr_div_person = l_user_person_id THEN
      RETURN 'Y';
    ELSE
      RETURN 'N';
    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN 'N';
  END get_hr_divisional_permit;

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
  FUNCTION get_user_person_id(p_user_id IN NUMBER) RETURN NUMBER IS

    l_person_id NUMBER := NULL;
  BEGIN
    SELECT fu.employee_id
    INTO   l_person_id
    FROM   fnd_user fu
    WHERE  user_id = p_user_id;

    RETURN l_person_id;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_user_person_id;

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
  FUNCTION get_payroll_name(p_payroll_id IN NUMBER) RETURN VARCHAR2 IS

    l_payroll_name VARCHAR2(80) := NULL;

  BEGIN

    SELECT payroll_name
    INTO   l_payroll_name
    FROM   pay_all_payrolls_f pay
    WHERE  pay.payroll_id = p_payroll_id;

    RETURN l_payroll_name;
  EXCEPTION
    WHEN OTHERS THEN
      NULL;
  END get_payroll_name;

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
  --                   i did not want to write the logic of location id
  --                   relate to entity name as hardcopy.
  --                   the select give me the ability that each change at the legal entity name
  --                   i will get it without open the code.
  --                   the solution was to add attribute1 at legaal entity level
  --                   and there to keep the location id that is relate to the legal entity.
  --                   steel i have the problem withh all IL locations,
  --                   this condition i do here.
  --                   Objet - mexico / Brazil belong to EM and EM sit at IL so they get
  --                   legal entity name as IL locations.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  10/10/2011  Dalit A. Raviv    initial build
  --  1.1  24/06/2013  Dalit A. Raviv    create value set XXOBJT_LEGAL_ENTITY_LOCATION
  --                                     that will hold each location the agregate location that is relate to.
  --                                     istead of changing the code it will handle at VS.
  --------------------------------------------------------------------
  FUNCTION get_company_name(p_location_id IN NUMBER) RETURN VARCHAR2 IS

    l_legal_entity_name VARCHAR2(240);
    l_location_id       NUMBER;
  BEGIN
    -- according to Objet website i got these
    -- Headquarters  Objet Ltd.              (Israel)
    -- North America Objet Inc.              (US)
    -- Europe        Objet GmbH              (EU)
    -- Asia Pacific  Objet Asia Pacific Ltd. (Hong Kong)
    --               Objet Shanghai Ltd.     (China)
    --               Objet in Japan          (Japan - not handling at HR)
    --               Objet in India          (India - not handling at HR)
    /*
    Objet Ltd.                    144 Objet Israel - Rehovot      144
    Objet Geometries Inc.         147 Objet US - Boston           147
    Objet AP Limited.             183 Objet Asia Pacific - HK     183
    Objet Geometries GmbH         185 Objet Europe - Germany      185
    Objet Geometries Shanghai Ltd 182 Objet Asia Pacific - China  182
                                  183123 (Prod) 143983(Patch) -- Objet - Brazil
                                  183122 (prod) 143982(Patch) -- Objet - mexico
    */
    --  1.1 24/06/2013 Dalit A. Raviv
    /*if p_location_id in (145, 144, 146, 262, 183123, 183122) then
      -- 'Objet Israel%', Objet - Brazil, Objet - mexico
      l_location_id := 144;
    else
      l_location_id := p_location_id;
    end if;*/
    BEGIN
      SELECT fv.attribute3
      INTO   l_location_id -- agregate_location_id
      FROM   fnd_flex_values_vl  fv,
   fnd_flex_value_sets fvs
      WHERE  fv.flex_value_set_id = fvs.flex_value_set_id
      AND    fvs.flex_value_set_name LIKE 'XXOBJT_LEGAL_ENTITY_LOCATION'
      AND    fv.enabled_flag = 'Y'
      AND    fv.flex_value = p_location_id;
    EXCEPTION
      WHEN OTHERS THEN
        l_location_id := NULL;
    END;
    -- end 1.1  24/06/2013

    SELECT lep.name
    INTO   l_legal_entity_name
    FROM   xle_entity_profiles lep,
           hr_operating_units  opu
    WHERE  lep.legal_entity_id = opu.default_legal_context_id
    AND    lep.attribute1 = l_location_id;

    RETURN l_legal_entity_name;
    /*
    -- get company
    if p_location_id = 182 then                      -- 'Objet Asia Pacific - China'
      return 'Objet Shanghai Ltd.';
    elsif p_location_id = 183 then                   -- 'Objet Asia Pacific - HK'
      return 'Objet Asia Pacific Ltd.';
    elsif p_location_id = 185 then                   -- 'Objet Europe - Germany'
      return 'Objet GmbH';
    elsif p_location_id = 147 then                   -- 'Objet US - Boston'
      return 'Objet Inc.';
    elsif p_location_id in (145, 144, 146, 262) then -- 'Objet Israel%'
      return 'Objet Ltd.';
    else
      return p_location_id;
    end if;
    */
  EXCEPTION
    WHEN no_data_found THEN
      RETURN 'Location is not connect to entity';
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log,
    'Procedure get_company_name - did not found company name - location id - ' ||
    p_location_id);
      RETURN NULL;
  END get_company_name;

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
    RETURN VARCHAR2 IS

    l_is_top_approver VARCHAR2(10) := NULL;

  BEGIN
    SELECT attribute1 is_top_approver
    INTO   l_is_top_approver
    FROM   per_all_positions pp
    WHERE  pp.position_id = p_position_id
    AND    pp.date_effective =
           (SELECT MAX(pp1.date_effective)
   FROM   per_all_positions pp1
   WHERE  pp1.position_id = pp.position_id);

    RETURN l_is_top_approver;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_position_is_top_approver;

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
  FUNCTION get_person_organization_id(p_person_id IN NUMBER) RETURN NUMBER IS

    l_organization_id NUMBER := NULL;
  BEGIN

    SELECT paaf.organization_id
    INTO   l_organization_id
    FROM   per_all_people_f      papf,
           per_all_assignments_f paaf
    WHERE  papf.person_id = p_person_id
    AND    trunc(SYSDATE) BETWEEN papf.effective_start_date AND
           papf.effective_end_date
    AND    papf.person_id = paaf.person_id
    AND    trunc(SYSDATE) BETWEEN paaf.effective_start_date AND
           paaf.effective_end_date
    AND    paaf.assignment_type IN ('E', 'C')
    AND    paaf.primary_flag = 'Y';

    RETURN(l_organization_id);

  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_person_organization_id;

  --------------------------------------------------------------------
  --  name:            get_person_mng_by_level
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   21/01/21013
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
               p_entity    IN VARCHAR2) RETURN VARCHAR2 IS

    l_person_id     NUMBER := NULL;
    l_person_name   VARCHAR2(360) := NULL;
    l_person_number VARCHAR2(30) := NULL;
    l_mng_id        NUMBER := NULL;
    l_mng_name      VARCHAR2(360) := NULL;
    l_mng_number    VARCHAR2(30) := NULL;
  BEGIN
    SELECT papf.person_id,
           papf.full_name,
           nvl(papf.employee_number, papf.npw_number) emp_number,
           paa.supervisor_id,
           papf1.full_name supervisor_name,
           nvl(papf1.employee_number, papf1.npw_number) supervisor_number --, level
    INTO   l_person_id,
           l_person_name,
           l_person_number,
           l_mng_id,
           l_mng_name,
           l_mng_number
    FROM   (SELECT *
  FROM   per_all_people_f papf
  WHERE  trunc(SYSDATE) BETWEEN papf.effective_start_date AND
         papf.effective_end_date
  AND    papf.business_group_id = 0) papf,
           (SELECT *
  FROM   per_all_assignments_f paa
  WHERE  trunc(SYSDATE) BETWEEN paa.effective_start_date AND
         paa.effective_end_date
  AND    paa.primary_flag = 'Y'
  AND    paa.assignment_type IN ('E', 'C')
  AND    paa.business_group_id = 0) paa,
           (SELECT *
  FROM   per_all_people_f papf1
  WHERE  trunc(SYSDATE) BETWEEN papf1.effective_start_date AND
         papf1.effective_end_date
  AND    papf1.business_group_id = 0) papf1
    WHERE  papf.person_id = paa.person_id
    AND    paa.supervisor_id = papf1.person_id
    AND    LEVEL = p_level
    START  WITH papf.person_id = p_person_id --861
    CONNECT BY PRIOR paa.supervisor_id = papf.person_id
    ORDER  BY LEVEL;

    IF p_entity = 'ID' THEN
      RETURN l_mng_id;
    ELSIF p_entity = 'NAME' THEN
      RETURN l_mng_name;
    ELSIF p_entity = 'NUM' THEN
      RETURN l_mng_number;
    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_person_mng_by_level;

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
      p_effective_date IN DATE) RETURN NUMBER IS
    l_assignment_id NUMBER;

  BEGIN
    SELECT assignment_id
    INTO   l_assignment_id
    FROM   per_all_assignments_f paa
    WHERE  paa.person_id = p_person_id
    AND    trunc(p_effective_date) BETWEEN paa.effective_start_date AND
           paa.effective_end_date;

    RETURN l_assignment_id;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_person_assignment_id;

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
    RETURN VARCHAR2 IS

    l_account_code VARCHAR2(25);
    l_account_desc VARCHAR2(240);

  BEGIN
    SELECT gl.segment3            ea_account, -- Expence account
           gl_account.description account_desc
    INTO   l_account_code,
           l_account_desc
    FROM   per_all_assignments_f pa,
           gl_code_combinations gl,
           (SELECT fv.flex_value,
         fv.flex_value_meaning,
         fv.description
  FROM   fnd_flex_values_vl  fv,
         fnd_flex_value_sets fvs
  WHERE  fv.flex_value_set_id = fvs.flex_value_set_id
  AND    fvs.flex_value_set_name LIKE 'XXGL_ACCOUNT_SEG') gl_account
    WHERE  trunc(SYSDATE) BETWEEN pa.effective_start_date AND
           pa.effective_end_date
    AND    gl.code_combination_id(+) = pa.default_code_comb_id
    AND    gl.segment3 = gl_account.flex_value(+)
    AND    pa.assignment_id = p_assignment_id;

    IF p_entity = 'CODE' THEN
      RETURN l_account_code;
    ELSE
      RETURN l_account_desc;
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_assignment_account_seg;

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
    RETURN VARCHAR2 IS

    l_dept_code VARCHAR2(25);
    l_dept_desc VARCHAR2(240);

  BEGIN
    SELECT gl.segment2               ea_department, -- Expence department
           gl_department.description dept_desc
    INTO   l_dept_code,
           l_dept_desc
    FROM   per_all_assignments_f pa,
           gl_code_combinations gl,
           (SELECT fv.flex_value,
         fv.flex_value_meaning,
         fv.description
  FROM   fnd_flex_values_vl  fv,
         fnd_flex_value_sets fvs
  WHERE  fv.flex_value_set_id = fvs.flex_value_set_id
  AND    fvs.flex_value_set_name LIKE 'XXGL_DEPARTMENT_SEG') gl_department
    WHERE  trunc(SYSDATE) BETWEEN pa.effective_start_date AND
           pa.effective_end_date
    AND    gl.code_combination_id(+) = pa.default_code_comb_id
    AND    gl.segment2 = gl_department.flex_value(+)
    AND    pa.assignment_id = p_assignment_id;

    IF p_entity = 'CODE' THEN
      RETURN l_dept_code;
    ELSE
      RETURN l_dept_desc;
    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_assignment_department_seg;

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
    RETURN VARCHAR2 IS

    l_comp_code VARCHAR2(25);
    l_comp_desc VARCHAR2(240);

  BEGIN
    SELECT gl.segment1            ea_company, -- Expence company
           gl_company.description comp_desc
    INTO   l_comp_code,
           l_comp_desc
    FROM   per_all_assignments_f pa,
           gl_code_combinations gl,
           (SELECT fv.flex_value,
         fv.flex_value_meaning,
         fv.description
  FROM   fnd_flex_values_vl  fv,
         fnd_flex_value_sets fvs
  WHERE  fv.flex_value_set_id = fvs.flex_value_set_id
  AND    fvs.flex_value_set_name LIKE 'XXGL_COMPANY_SEG') gl_company
    WHERE  trunc(SYSDATE) BETWEEN pa.effective_start_date AND
           pa.effective_end_date
    AND    gl.code_combination_id(+) = pa.default_code_comb_id
    AND    gl.segment1 = gl_company.flex_value(+)
    AND    pa.assignment_id = p_assignment_id;

    IF p_entity = 'CODE' THEN
      RETURN l_comp_code;
    ELSE
      RETURN l_comp_desc;
    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_assignment_company_seg;

  --------------------------------------------------------------------
  --  name:            get_tas_mng_by_level
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   06/03/2013
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
  --  1.0  06/03/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_tas_mng_by_level(p_person_id IN NUMBER,
            p_level     IN NUMBER,
            p_entity    IN VARCHAR2) RETURN VARCHAR2 IS

    CURSOR get_pop_c IS
      SELECT papf.person_id,
   papf.full_name,
   nvl(papf.employee_number, papf.npw_number) emp_number,
   paa.supervisor_id,
   papf1.full_name supervisor_name,
   nvl(papf1.employee_number, papf1.npw_number) supervisor_number,
   LEVEL,
   grade.name
      FROM   (SELECT *
    FROM   per_all_people_f papf
    WHERE  trunc(SYSDATE) BETWEEN papf.effective_start_date AND
           papf.effective_end_date
    AND    papf.business_group_id = 0) papf,
   (SELECT *
    FROM   per_all_assignments_f paa
    WHERE  trunc(SYSDATE) BETWEEN paa.effective_start_date AND
           paa.effective_end_date
    AND    paa.primary_flag = 'Y'
    AND    paa.assignment_type IN ('E', 'C')
    AND    paa.business_group_id = 0) paa,
   (SELECT *
    FROM   per_all_people_f papf1
    WHERE  trunc(SYSDATE) BETWEEN papf1.effective_start_date AND
           papf1.effective_end_date
    AND    papf1.business_group_id = 0) papf1,
   (SELECT g.name,
           p.person_id
    FROM   per_all_assignments_f p,
           per_grades_vl         g
    WHERE  trunc(SYSDATE) BETWEEN p.effective_start_date AND
           p.effective_end_date
    AND    p.primary_flag = 'Y'
    AND    p.assignment_type IN ('E', 'C')
    AND    p.business_group_id = 0
    AND    g.grade_id = p.grade_id) grade
      WHERE  papf.person_id = paa.person_id
      AND    paa.supervisor_id = papf1.person_id
      AND    grade.person_id = paa.supervisor_id
      --and    grade.name              <> 'TL'
      START  WITH papf.person_id = p_person_id
      CONNECT BY PRIOR paa.supervisor_id = papf.person_id
      ORDER  BY LEVEL;

    CURSOR get_pop1_c(p_level IN NUMBER) IS
      SELECT papf.person_id,
   papf.full_name,
   nvl(papf.employee_number, papf.npw_number) emp_number,
   paa.supervisor_id,
   papf1.full_name supervisor_name,
   nvl(papf1.employee_number, papf1.npw_number) supervisor_number,
   LEVEL,
   grade.name
      FROM   (SELECT *
    FROM   per_all_people_f papf
    WHERE  trunc(SYSDATE) BETWEEN papf.effective_start_date AND
           papf.effective_end_date
    AND    papf.business_group_id = 0) papf,
   (SELECT *
    FROM   per_all_assignments_f paa
    WHERE  trunc(SYSDATE) BETWEEN paa.effective_start_date AND
           paa.effective_end_date
    AND    paa.primary_flag = 'Y'
    AND    paa.assignment_type IN ('E', 'C')
    AND    paa.business_group_id = 0) paa,
   (SELECT *
    FROM   per_all_people_f papf1
    WHERE  trunc(SYSDATE) BETWEEN papf1.effective_start_date AND
           papf1.effective_end_date
    AND    papf1.business_group_id = 0) papf1,
   (SELECT g.name,
           p.person_id
    FROM   per_all_assignments_f p,
           per_grades_vl         g
    WHERE  trunc(SYSDATE) BETWEEN p.effective_start_date AND
           p.effective_end_date
    AND    p.primary_flag = 'Y'
    AND    p.assignment_type IN ('E', 'C')
    AND    p.business_group_id = 0
    AND    g.grade_id = p.grade_id) grade
      WHERE  papf.person_id = paa.person_id
      AND    paa.supervisor_id = papf1.person_id
      AND    grade.person_id = paa.supervisor_id
  --and    grade.name              <> 'TL'
      AND    LEVEL = p_level
      START  WITH papf.person_id = p_person_id
      CONNECT BY PRIOR paa.supervisor_id = papf.person_id
      ORDER  BY LEVEL;

    l_mng_id         NUMBER := NULL;
    l_mng_name       VARCHAR2(360) := NULL;
    l_mng_number     VARCHAR2(30) := NULL;
    l_check_director VARCHAR2(1) := NULL;
    --l_check_tl       varchar2(1)   := null;
    l_level NUMBER := 0;

    l_first_grade  VARCHAR2(50) := NULL;
    l_second_grade VARCHAR2(50) := NULL;
    l_count        NUMBER := 0;
  BEGIN

    l_check_director := 'N';
    FOR get_pop_r IN get_pop_c LOOP
      l_count := l_count + 1;

      IF l_count = 1 THEN
        l_first_grade := get_pop_r.name;
      ELSIF l_count = 2 THEN
        l_second_grade := get_pop_r.name;
      END IF;

      IF get_pop_r.name = 'Director' THEN
        l_check_director := 'Y';
      END IF;
    END LOOP;
    -- do not show TL and if employee has director go direct to director
    -- TL do not approve
    -- manager will aprove if there in no director else director is the approver.
    IF l_first_grade = 'TL' THEN
      IF l_second_grade = 'Manager' AND l_check_director = 'N' THEN
        l_level := p_level + 1;
      ELSIF l_second_grade = 'Manager' AND l_check_director = 'Y' THEN
        l_level := p_level + 2;
      ELSIF l_second_grade = 'Director' THEN
        l_level := p_level + 1;
      END IF;
    ELSIF l_first_grade = 'Manager' THEN
      IF l_second_grade = 'Director' THEN
        l_level := p_level + 1;
      ELSE
        l_level := p_level;
      END IF;
    ELSIF l_first_grade = 'Director' THEN
      l_level := p_level;
    ELSE
      l_level := p_level;
    END IF;

    FOR get_pop_r IN get_pop1_c(l_level) LOOP
      l_mng_id     := get_pop_r.supervisor_id;
      l_mng_name   := get_pop_r.supervisor_name;
      l_mng_number := get_pop_r.supervisor_number;
    END LOOP;

    --if l_mng_id is null

    IF p_entity = 'ID' THEN
      RETURN l_mng_id;
    ELSIF p_entity = 'NAME' THEN
      RETURN l_mng_name;
    ELSIF p_entity = 'NUM' THEN
      RETURN l_mng_number;
    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_tas_mng_by_level;

  --------------------------------------------------------------------
  --  name:            get_tas_person_by_grade
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   06/03/2013
  --------------------------------------------------------------------
  --  purpose :        i have grade, and i want to know who is the person relate to it.
  --
  --                   p_entity = ID   will return person id
  --                            = NUM  will return employee number.
  --                            = NAME will return full name
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  06/03/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_tas_person_by_grade(p_grade  IN VARCHAR2,
               p_date   IN DATE,
               p_entity IN VARCHAR2) RETURN VARCHAR2 IS

    l_full_name VARCHAR2(360) := NULL;
    l_emp_num   VARCHAR2(20) := NULL;
    l_person_id NUMBER := NULL;

  BEGIN
    SELECT p.full_name,
           nvl(p.employee_number, p.npw_number) emp_num,
           p.person_id
    INTO   l_full_name,
           l_emp_num,
           l_person_id
    FROM   per_grades_vl         g,
           per_all_assignments_f a,
           per_all_people_f      p
    WHERE  g.name = p_grade
    AND    g.grade_id = a.grade_id
    AND    a.person_id = p.person_id
    AND    p_date BETWEEN p.effective_start_date AND p.effective_end_date
    AND    p_date BETWEEN a.effective_start_date AND a.effective_end_date;

    IF p_entity = 'ID' THEN
      RETURN l_person_id;
    ELSIF p_entity = 'NAME' THEN
      RETURN l_full_name;
    ELSIF p_entity = 'NUM' THEN
      RETURN l_emp_num;
    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_tas_person_by_grade;

  --------------------------------------------------------------------
  --  name:            get_tas_first_approval_mng
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   08/04/2013
  --------------------------------------------------------------------
  --  purpose :        The logic of the approval for TAS is:
  --                   a. The first approver will be the highest hierarchy person that under VP.
  --                      (VP will define in profile).
  --                      if there is no VP grade the manager will be the direct manager (manage at the view xxhr_tas_employee_details_v)
  --                   b. The second approver will be the VP of the employee.
  --
  --  return           suppervisor_id, consider with the logic of the approval.
  --
  --                   p_entity = ID   will return suppervisor id
  --                            = NUM  will return suppervisor employee number.
  --                            = NAME will return suppervisor full name
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  08/04/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_tas_first_approval_mng(p_person_id IN NUMBER,
        p_entity    IN VARCHAR2)
    RETURN VARCHAR2 IS

    CURSOR pop_c(p_person_id IN NUMBER,
       p_sequence  IN NUMBER) IS
      SELECT papf.person_id,
   papf.full_name,
   nvl(papf.employee_number, papf.npw_number) emp_number,
   paa.supervisor_id,
   papf1.full_name supervisor_name,
   nvl(papf1.employee_number, papf1.npw_number) supervisor_number,
   LEVEL,
   grade.name,
   grade.sequence
      FROM   (SELECT *
    FROM   per_all_people_f papf
    WHERE  trunc(SYSDATE) BETWEEN papf.effective_start_date AND
           papf.effective_end_date
    AND    papf.business_group_id = 0) papf,
   (SELECT *
    FROM   per_all_assignments_f paa
    WHERE  trunc(SYSDATE) BETWEEN paa.effective_start_date AND
           paa.effective_end_date
    AND    paa.primary_flag = 'Y'
    AND    paa.assignment_type IN ('E', 'C')
    AND    paa.business_group_id = 0) paa,
   (SELECT *
    FROM   per_all_people_f papf1
    WHERE  trunc(SYSDATE) BETWEEN papf1.effective_start_date AND
           papf1.effective_end_date
    AND    papf1.business_group_id = 0) papf1,
   (SELECT g.name,
           p.person_id,
           g.sequence
    FROM   per_all_assignments_f p,
           per_grades_vl         g
    WHERE  trunc(SYSDATE) BETWEEN p.effective_start_date AND
           p.effective_end_date
    AND    p.primary_flag = 'Y'
    AND    p.assignment_type IN ('E', 'C')
    AND    p.business_group_id = 0
    AND    g.grade_id = p.grade_id) grade
      WHERE  papf.person_id = paa.person_id
      AND    paa.supervisor_id = papf1.person_id
      AND    grade.person_id = paa.supervisor_id
      AND    grade.sequence < p_sequence -- 50
      START  WITH papf.person_id = p_person_id
      CONNECT BY PRIOR paa.supervisor_id = papf.person_id
      ORDER  BY LEVEL;

    l_sequence   NUMBER;
    l_mng_id     NUMBER := NULL;
    l_mng_name   VARCHAR2(360) := NULL;
    l_mng_number VARCHAR2(30) := NULL;
  BEGIN
    l_sequence := fnd_profile.value('XXTAS_HR_TOP_GRADE_APPROVAL_SEQ');
    FOR pop_r IN pop_c(p_person_id, l_sequence) LOOP
      l_mng_id     := pop_r.supervisor_id;
      l_mng_name   := pop_r.supervisor_name;
      l_mng_number := pop_r.supervisor_number;
    END LOOP;

    IF p_entity = 'ID' THEN
      RETURN l_mng_id;
    ELSIF p_entity = 'NAME' THEN
      RETURN l_mng_name;
    ELSIF p_entity = 'NUM' THEN
      RETURN l_mng_number;
    END IF;
  END get_tas_first_approval_mng;

  --------------------------------------------------------------------
  --  name:            get_tas_second_approval_mng
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   08/04/2013
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
  --  1.0  08/04/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_tas_second_approval_mng(p_person_id IN NUMBER,
         p_entity    IN VARCHAR2)
    RETURN VARCHAR2 IS

    CURSOR pop_c(p_person_id IN NUMBER,
       p_sequence  IN NUMBER) IS
      SELECT papf.person_id,
   papf.full_name,
   nvl(papf.employee_number, papf.npw_number) emp_number,
   paa.supervisor_id,
   papf1.full_name supervisor_name,
   nvl(papf1.employee_number, papf1.npw_number) supervisor_number,
   LEVEL,
   grade.name,
   grade.sequence
      FROM   (SELECT *
    FROM   per_all_people_f papf
    WHERE  trunc(SYSDATE) BETWEEN papf.effective_start_date AND
           papf.effective_end_date
    AND    papf.business_group_id = 0) papf,
   (SELECT *
    FROM   per_all_assignments_f paa
    WHERE  trunc(SYSDATE) BETWEEN paa.effective_start_date AND
           paa.effective_end_date
    AND    paa.primary_flag = 'Y'
    AND    paa.assignment_type IN ('E', 'C')
    AND    paa.business_group_id = 0) paa,
   (SELECT *
    FROM   per_all_people_f papf1
    WHERE  trunc(SYSDATE) BETWEEN papf1.effective_start_date AND
           papf1.effective_end_date
    AND    papf1.business_group_id = 0) papf1,
   (SELECT g.name,
           p.person_id,
           g.sequence
    FROM   per_all_assignments_f p,
           per_grades_vl         g
    WHERE  trunc(SYSDATE) BETWEEN p.effective_start_date AND
           p.effective_end_date
    AND    p.primary_flag = 'Y'
    AND    p.assignment_type IN ('E', 'C')
    AND    p.business_group_id = 0
    AND    g.grade_id = p.grade_id) grade
      WHERE  papf.person_id = paa.person_id
      AND    paa.supervisor_id = papf1.person_id
      AND    grade.person_id = paa.supervisor_id
      AND    grade.sequence >= p_sequence -- 50
      START  WITH papf.person_id = p_person_id
      CONNECT BY PRIOR paa.supervisor_id = papf.person_id
      ORDER  BY LEVEL;

    l_sequence   NUMBER;
    l_mng_id     NUMBER := NULL;
    l_mng_name   VARCHAR2(360) := NULL;
    l_mng_number VARCHAR2(30) := NULL;
  BEGIN
    l_sequence := fnd_profile.value('XXTAS_HR_TOP_GRADE_APPROVAL_SEQ');
    FOR pop_r IN pop_c(p_person_id, l_sequence) LOOP
      l_mng_id     := pop_r.supervisor_id;
      l_mng_name   := pop_r.supervisor_name;
      l_mng_number := pop_r.supervisor_number;
      EXIT;
    END LOOP;

    IF p_entity = 'ID' THEN
      RETURN l_mng_id;
    ELSIF p_entity = 'NAME' THEN
      RETURN l_mng_name;
    ELSIF p_entity = 'NUM' THEN
      RETURN l_mng_number;
    END IF;
  END get_tas_second_approval_mng;

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
  --  1.1  20-APR-2016 LSARANGI          CHG0038225 : Adjust 3rd approver in combtas
  --------------------------------------------------------------------
  FUNCTION get_tas_third_approval_mng(p_person_id IN NUMBER,
        p_entity    IN VARCHAR2)
    RETURN VARCHAR2 IS

    CURSOR pop_c(p_person_id IN NUMBER,
       p_sequence  IN NUMBER) IS
      SELECT-- papf.person_id,
  -- papf.full_name,
   nvl(papf.employee_number, papf.npw_number) emp_number,
   paa.supervisor_id,
   papf1.full_name supervisor_name,
   nvl(papf1.employee_number, papf1.npw_number) supervisor_number,
   LEVEL,
   grade.name,
   grade.sequence
      FROM   (SELECT person_id,
           full_name,
           npw_number,
           employee_number
    FROM   per_all_people_f papf
    WHERE  trunc(SYSDATE) BETWEEN papf.effective_start_date AND
           papf.effective_end_date
    AND    papf.business_group_id = 0) papf,
   (SELECT person_id,
           supervisor_id
    FROM   per_all_assignments_f paa
    WHERE  trunc(SYSDATE) BETWEEN paa.effective_start_date AND
           paa.effective_end_date
    AND    paa.primary_flag = 'Y'
    AND    paa.assignment_type IN ('E', 'C')
    AND    paa.business_group_id = 0) paa,
   (SELECT person_id,
           npw_number,
           employee_number,
           full_name
    FROM   per_all_people_f papf1
    WHERE  trunc(SYSDATE) BETWEEN papf1.effective_start_date AND
           papf1.effective_end_date
    AND    papf1.business_group_id = 0) papf1,
   (SELECT g.name,
           p.person_id,
           g.sequence
    FROM   per_all_assignments_f p,
           per_grades_vl         g
    WHERE  trunc(SYSDATE) BETWEEN p.effective_start_date AND
           p.effective_end_date
    AND    p.primary_flag = 'Y'
    AND    p.assignment_type IN ('E', 'C')
    AND    p.business_group_id = 0
    AND    g.grade_id = p.grade_id) grade
      WHERE  papf.person_id = paa.person_id
      AND    paa.supervisor_id = papf1.person_id
      AND    grade.person_id = paa.supervisor_id
      AND    grade.sequence >= p_sequence -- 50
      START  WITH papf.person_id = p_person_id
      CONNECT BY PRIOR paa.supervisor_id = papf.person_id
      ORDER  BY LEVEL;

    l_sequence         NUMBER;
    l_mng_id           NUMBER := NULL;
    l_mng_name         VARCHAR2(360) := NULL;
    l_mng_number       VARCHAR2(30) := NULL;
   /* CHG0038225 : Commented as Not going Use
    l_exclude_managers VARCHAR2(360) := NULL;
    l_allowed_managers VARCHAR2(360) := NULL;
    i                  NUMBER;
   */
  BEGIN
    /* CHG0038225 : New Profile Created to hold the NO3 Grade Sequence  */
    l_sequence := fnd_profile.value('XXTAS_HR_TOP_GRADE_NO3_APPROVAL_SEQ');
   /* CHG0038225 : Commented as Not going Use
    l_sequence         := fnd_profile.value('XXTAS_HR_TOP_GRADE_APPROVAL_SEQ');
    l_exclude_managers := fnd_profile.value('XXTAS_HR_EXCLUDE_MANAGER_APPROVAL_NO3');
    l_allowed_managers := fnd_profile.value('XXTAS_HR_ALLOWED_MANAGER_APPROVAL_NO3');
    i                  := 1;
   */
    FOR pop_r IN pop_c(p_person_id, l_sequence) LOOP
      /* CHG0038225 : When Sequence Will be equal to the NO3 Grade Sequence 
         ,The Persons value will be returned as 3rd Manager
      */
      IF pop_r.sequence = l_sequence THEN
          l_mng_id     := pop_r.supervisor_id;
          l_mng_name   := pop_r.supervisor_name;
          l_mng_number := pop_r.supervisor_number;
      END IF;
    END LOOP; 
    /* CHG0038225 : Commented as Not going Use
      IF instr(l_exclude_managers, pop_r.supervisor_name) != 0 THEN
          l_mng_id     := NULL;
          l_mng_name   := NULL;
          l_mng_number := NULL;
      ELSE
        IF l_allowed_managers IS NOT NULL THEN
          IF instr(l_allowed_managers, pop_r.supervisor_name) != 0 THEN
                l_mng_id     := pop_r.supervisor_id;
                l_mng_name   := pop_r.supervisor_name;
                l_mng_number := pop_r.supervisor_number;
          ELSE
                l_mng_id     := NULL;
                l_mng_name   := NULL;
                l_mng_number := NULL;
          END IF;
        ELSE
          l_mng_id     := pop_r.supervisor_id;
          l_mng_name   := pop_r.supervisor_name;
          l_mng_number := pop_r.supervisor_number;
        END IF;
      END IF;

      IF i = 2 THEN
        EXIT;
      ELSE
        i := i + 1;
      END IF;
      */
   

    IF p_entity = 'ID' THEN
      RETURN l_mng_id;
    ELSIF p_entity = 'NAME' THEN
      RETURN l_mng_name;
    ELSIF p_entity = 'NUM' THEN
      RETURN l_mng_number;
    END IF;
  END get_tas_third_approval_mng;
  --------------------------------------------------------------------
  --  name:            get_personal_email_address
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   24/06/2013
  --------------------------------------------------------------------
  --  purpose :        get person private email address -
  --                   this information is important for the stock options
  --                   when employee end employment.
  --
  --  return           private email address
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  24/06/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_personal_email_address(p_person_id IN NUMBER) RETURN VARCHAR2 IS

    l_private_email VARCHAR2(150) := NULL;

  BEGIN
    SELECT attribute3
    INTO   l_private_email
    FROM   per_all_people_f p
    WHERE  p.person_id = p_person_id
    AND    trunc(SYSDATE) BETWEEN p.effective_start_date AND
           p.effective_end_date;

    RETURN l_private_email;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_personal_email_address;

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
          p_bg_id          IN NUMBER) RETURN NUMBER IS

    l_suppervisor_id NUMBER;
  BEGIN

    SELECT a.supervisor_id
    INTO   l_suppervisor_id
    FROM   per_all_people_f      p,
           per_all_assignments_f a
    WHERE  p.person_id = a.person_id
    AND    p_effective_date BETWEEN p.effective_start_date AND
           p.effective_end_date
    AND    p_effective_date BETWEEN a.effective_start_date AND
           a.effective_end_date
    AND    p.business_group_id = p_bg_id
    AND    a.business_group_id = p_bg_id
    AND    p.person_id = p_person_id;

    RETURN l_suppervisor_id;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_suppervisor_id;

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
            p_entity    IN VARCHAR2) RETURN VARCHAR2 IS

    l_territory VARCHAR2(150) := NULL;
  BEGIN

    SELECT --XXHR_UTIL_PKG.get_person_organization_id(p_person_id) person_organization_id, -- get person oragnization id
     xxhr_util_pkg.get_organization_by_hierarchy(xxhr_util_pkg.get_person_organization_id(p_person_id),
         'TER',
         p_entity) person_territory -- get person territory
    INTO   l_territory
    FROM   dual;

    RETURN l_territory;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_person_territory;

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
          p_entity    IN VARCHAR2) RETURN VARCHAR2 IS

    CURSOR pop_c(p_person_id IN NUMBER,
       p_sequence  IN NUMBER) IS
      SELECT papf.person_id,
   papf.full_name,
   nvl(papf.employee_number, papf.npw_number) emp_number,
   paa.supervisor_id,
   papf1.full_name supervisor_name,
   nvl(papf1.employee_number, papf1.npw_number) supervisor_number,
   LEVEL,
   grade.name,
   grade.sequence
      FROM   (SELECT *
    FROM   per_all_people_f papf
    WHERE  trunc(SYSDATE) BETWEEN papf.effective_start_date AND
           papf.effective_end_date
    AND    papf.business_group_id = 0) papf,
   (SELECT *
    FROM   per_all_assignments_f paa
    WHERE  trunc(SYSDATE) BETWEEN paa.effective_start_date AND
           paa.effective_end_date
    AND    paa.primary_flag = 'Y'
    AND    paa.assignment_type IN ('E', 'C')
    AND    paa.business_group_id = 0) paa,
   (SELECT *
    FROM   per_all_people_f papf1
    WHERE  trunc(SYSDATE) BETWEEN papf1.effective_start_date AND
           papf1.effective_end_date
    AND    papf1.business_group_id = 0) papf1,
   (SELECT g.name,
           p.person_id,
           g.sequence
    FROM   per_all_assignments_f p,
           per_grades_vl         g
    WHERE  trunc(SYSDATE) BETWEEN p.effective_start_date AND
           p.effective_end_date
    AND    p.primary_flag = 'Y'
    AND    p.assignment_type IN ('E', 'C')
    AND    p.business_group_id = 0
    AND    g.grade_id = p.grade_id) grade
      WHERE  papf.person_id = paa.person_id
      AND    paa.supervisor_id = papf1.person_id
      AND    grade.person_id = paa.supervisor_id
      AND    grade.sequence < p_sequence -- 80
      START  WITH papf.person_id = p_person_id
      CONNECT BY PRIOR paa.supervisor_id = papf.person_id
      ORDER  BY LEVEL;

    l_sequence   NUMBER;
    l_mng_id     NUMBER := NULL;
    l_mng_name   VARCHAR2(360) := NULL;
    l_mng_number VARCHAR2(30) := NULL;
  BEGIN
    l_sequence := fnd_profile.value('XXHR_VAC_TOP_MNG_GRADE_LEVEL'); -- this is the level of the CEO
    FOR pop_r IN pop_c(p_person_id, l_sequence) LOOP
      l_mng_id     := pop_r.supervisor_id;
      l_mng_name   := pop_r.supervisor_name;
      l_mng_number := pop_r.supervisor_number;
    END LOOP;

    IF p_entity = 'ID' THEN
      RETURN l_mng_id;
    ELSIF p_entity = 'NAME' THEN
      RETURN l_mng_name;
    ELSIF p_entity = 'NUM' THEN
      RETURN l_mng_number;
    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;

  END get_person_top_mng;

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
       p_grade_lvl IN VARCHAR2) RETURN VARCHAR2 IS

    CURSOR pop_c(p_person_id IN NUMBER,
       p_sequence  IN NUMBER) IS
      SELECT papf.person_id,
   papf.full_name,
   nvl(papf.employee_number, papf.npw_number) emp_number,
   paa.supervisor_id,
   papf1.full_name supervisor_name,
   nvl(papf1.employee_number, papf1.npw_number) supervisor_number,
   LEVEL,
   grade.name,
   grade.sequence
      FROM   (SELECT *
    FROM   per_all_people_f papf
    WHERE  trunc(SYSDATE) BETWEEN papf.effective_start_date AND
           papf.effective_end_date
    AND    papf.business_group_id = 0) papf,
   (SELECT *
    FROM   per_all_assignments_f paa
    WHERE  trunc(SYSDATE) BETWEEN paa.effective_start_date AND
           paa.effective_end_date
    AND    paa.primary_flag = 'Y'
    AND    paa.assignment_type IN ('E', 'C')
    AND    paa.business_group_id = 0) paa,
   (SELECT *
    FROM   per_all_people_f papf1
    WHERE  trunc(SYSDATE) BETWEEN papf1.effective_start_date AND
           papf1.effective_end_date
    AND    papf1.business_group_id = 0) papf1,
   (SELECT g.name,
           p.person_id,
           g.sequence
    FROM   per_all_assignments_f p,
           per_grades_vl         g
    WHERE  trunc(SYSDATE) BETWEEN p.effective_start_date AND
           p.effective_end_date
    AND    p.primary_flag = 'Y'
    AND    p.assignment_type IN ('E', 'C')
    AND    p.business_group_id = 0
    AND    g.grade_id = p.grade_id) grade
      WHERE  papf.person_id = paa.person_id
      AND    paa.supervisor_id = papf1.person_id
      AND    grade.person_id = paa.supervisor_id
      AND    grade.sequence < p_sequence -- 60
      START  WITH papf.person_id = p_person_id
      CONNECT BY PRIOR paa.supervisor_id = papf.person_id
      ORDER  BY LEVEL;

    l_mng_id     NUMBER := NULL;
    l_mng_name   VARCHAR2(360) := NULL;
    l_mng_number VARCHAR2(30) := NULL;

    l_mng_grade_name per_grades_vl.name%TYPE;
    l_top_grade_seq  NUMBER;
  BEGIN

    SELECT pg.sequence
    INTO   l_top_grade_seq
    FROM   per_grades pg
    WHERE  pg.name = p_grade_lvl;

    FOR pop_r IN pop_c(p_person_id, l_top_grade_seq) LOOP
      l_mng_id         := pop_r.supervisor_id;
      l_mng_name       := pop_r.supervisor_name;
      l_mng_number     := pop_r.supervisor_number;
      l_mng_grade_name := pop_r.name;
    END LOOP;

    IF p_grade_lvl = 'EVP' AND l_mng_grade_name NOT IN ('VP', 'Sr VP') THEN
      RETURN NULL;
    END IF;

    IF p_entity = 'ID' THEN
      RETURN l_mng_id;
    ELSIF p_entity = 'NAME' THEN
      RETURN l_mng_name;
    ELSIF p_entity = 'NUM' THEN
      RETURN l_mng_number;
    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;

  END get_person_top_mng_by_lvl;
END xxhr_util_pkg;
/
