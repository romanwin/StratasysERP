create or replace package xxhr_person_pkg AUTHID CURRENT_USER is

  --------------------------------------------------------------------
  --  name:            XXHR_PERSON_PKG
  --  create by:       Dalit A. Raviv
  --  Revision:        1.5
  --  creation date:   29/11/2010 10:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        HR project - Handle Person details
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  29/11/2010  Dalit A. Raviv    initial build
  --  1.1  23/06/2011  Dalit A. Raviv    add function  get_person_town_or_city
  --  1.2  05/07/2011  Dalit A. Raviv    add function  get_person_phone
  --  1.3  04/09/2011  Dalit A. Raviv    add function  get_person_address
  --  1.4  27/06/2013  Dalit A. Raviv    Handle HR packages and apps_view
  --                                     add AUTHID CURRENT_USER to spec
  --  1.5  06/02/2014  Dalit A. Raviv    add function get_person_personal_email
  --  1.6  07/09/2020  Roman W.          CHG0048543 - R & D Location in purchase requisition - change logic  
  --------------------------------------------------------------------

  --------------------------------------------------------------------
  --  name:            get_person_id
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   29/11/2010 1:30:11 PM
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
  --------------------------------------------------------------------
  function get_person_id(p_entity_value   varchar2,
                         p_effective_date date,
                         p_bg_id          number,
                         p_entity_name    varchar2) return number;

  --------------------------------------------------------------------
  --  name:            get_emp_num
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   29/12/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        get employee number by person_id
  --  in params:       p_person_id
  --                   p_effective_date  - the effective date we want to get the data from
  --                   p_bg_id           - business_group_id
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  29/12/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  function get_emp_num(p_person_id      in number,
                       p_effective_date in date default trunc(sysdate),
                       p_bg_id          in number default 0) return varchar2;
  --------------------------------------------------------------------
  --  name:            update_employee_email
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   30/11/2010 1:30:11 PM
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
  --------------------------------------------------------------------
  procedure update_employee_email(p_personid     in number,
                                  p_emailaddress in varchar2,
                                  p_error_code   out varchar2,
                                  p_error_desc   out varchar2);

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
  --------------------------------------------------------------------
  procedure update_employee_National_id(p_error_code out varchar2,
                                        p_error_desc out varchar2);

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
  function get_next_employee_number(p_person_id in number) return varchar2;

  --------------------------------------------------------------------
  --  name:            get_system_person_type
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   18/01/2011
  --------------------------------------------------------------------
  --  purpose :        get system person type
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  18/01/2011  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  function get_system_person_type(p_effective_date in date,
                                  p_person_id      in number) return varchar2;

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
                                   p_new_national_id    out varchar2);

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
                                   p_yes_no             out varchar2);

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
    return varchar2;

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
  function get_person_town_or_city(p_person_id in number) return varchar2;

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
                            p_phone_type in varchar2) return varchar2;

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
  function get_person_address(p_person_id in number) return varchar2;

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
  function get_person_personal_email(p_person_id in number) return varchar2;

  --------------------------------------------------------------------------
  -- Ver   When         Who          Descr
  -- ----  -----------  -----------  ---------------------------------------
  -- 1.0   07/09/2020   Roman W.     CHG0048543 - R & D Location in purchase requisition - change logic
  --------------------------------------------------------------------------
  function is_employee_il_rd(p_person_id NUMBER) return varchar;

end XXHR_PERSON_PKG;
/
