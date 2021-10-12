CREATE OR REPLACE PACKAGE BODY XXHR_PAY_ELEMENTS_PKG IS

  --------------------------------------------------------------------
  --  name:            XXHR_PERSON_PKG
  --  create by:       Dalit A. Raviv
  --  Revision:        1.1 
  --  creation date:   13/12/2010  10:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        HR project - Handle upload of elements from Har-Gal to oracle
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  13/12/2010  Dalit A. Raviv    initial build
  --  1.1  18/08/2013  Dalit A. Raviv    get_ele_upd_mode -> enlarge l_exist var 
  --------------------------------------------------------------------  
  g_business_group_id  CONSTANT NUMBER := xxhr_pay_elements_pkg.get_business_group_id; -- hr_security.get_sec_profile_bg_id; --
  g_login_id           number          := null;
  g_user_id            number          := null;
  g_user_name          varchar2(100)   := null;
  g_batch_id           number          := null;
  g_assignment_id      number          := null;
  g_person_id          number          := null;
  g_salary_basis       varchar2(30)    := null;         
  g_pay_basis_id       number          := null;
  g_batch_date         date            := null;
  g_element_start_date date            := null;
  g_second_run         varchar2(5)     := null;
  
  invalid_element     exception;

  -- HR_7155_OBJECT_INVALID  invalid object_version_number
  
  --------------------------------------------------------------------
  --  name:            delete_element_test
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   03/01/2011 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        
  --  in params:       
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  03/01/2011  Dalit A. Raviv    initial build
  -------------------------------------------------------------------- 
  PROCEDURE delete_element_test IS
  
    l_effective_start_date  DATE;
    l_effective_end_date    DATE;
    l_delete_warning        BOOLEAN;
    l_object_version_number NUMBER;
  
  BEGIN
    -- @param p_datetrack_delete_mode Indicates which DateTrack mode to use when
    -- deleting the record. You must set to either ZAP, DELETE, FUTURE_CHANGE or
    -- DELETE_NEXT_CHANGE. Modes available for use with a particular record depend
    -- on the dates of previous record changes and the effective date of this change.
    
    --fnd_global.APPS_INITIALIZE(user_id => 2470,resp_id => 50817,resp_appl_id => 800);
    l_object_version_number := 1;
    pay_element_entry_api.delete_element_entry(p_datetrack_delete_mode => 'DELETE',
                                               p_effective_date => trunc(SYSDATE),
                                               p_element_entry_id => 201, -- Test1
                                               p_object_version_number =>  l_object_version_number,
                                               p_effective_start_date => l_effective_start_date, -- o
                                               p_effective_end_date => l_effective_end_date,-- o
                                               p_delete_warning => l_delete_warning);-- o
    
    IF l_delete_warning THEN
      dbms_output.put_line('Api finished with warning - ' ||
                           substr(SQLERRM, 1, 200));
    ELSE
      dbms_output.put_line('Api finished with success ');
    END IF;
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      dbms_output.put_line('EXCEPTION - ' || substr(SQLERRM, 1, 200));
      dbms_output.put_line('EXCEPTION - ' || substr(SQLERRM, 201, 400));
  END delete_element_test;

  --------------------------------------------------------------------
  --  name:            update_element_test
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   13/12/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        
  --  in params:       
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  13/12/2010  Dalit A. Raviv    initial build
  -------------------------------------------------------------------- 
  PROCEDURE update_element_test IS
  
    l_effective_start_date  DATE;
    l_effective_end_date    DATE;
    l_update_warning        BOOLEAN;
    l_object_version_number NUMBER;
  
  BEGIN
  
    fnd_global.APPS_INITIALIZE(user_id => 2470,resp_id => 50817,resp_appl_id => 800);
    l_object_version_number := 2;
    pay_element_entry_api.update_element_entry(p_datetrack_update_mode => 'UPDATE',--'CORRECTION',
                                               p_effective_date        => trunc(SYSDATE - 60) ,
                                               p_business_group_id     => g_business_group_id, -- 0
                                               p_element_entry_id      => 1123,--182, --g_element_entry_id -- Basic Salary
                                               p_object_version_number => l_object_version_number, --g_object_version_number
                                               p_input_value_id1       => 149058,--148692, --g_input_value_id_tab(1),
                                               p_entry_value1          => 10,--6167, --6000, --lv_input_value_code_1,
                                               /*p_input_value_id2            => g_input_value_id_tab(2),
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             p_entry_value2               => lv_input_value_code_2,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             p_input_value_id3            => g_input_value_id_tab(3),
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             p_entry_value3               => lv_input_value_code_3,*/
                                               p_effective_start_date => l_effective_start_date,
                                               p_effective_end_date   => l_effective_end_date,
                                               p_update_warning       => l_update_warning);
    IF l_update_warning THEN
      dbms_output.put_line('Api finished with warning - ' ||
                           substr(SQLERRM, 1, 200));
    ELSE
      dbms_output.put_line('Api finished with success ');
    END IF;
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      dbms_output.put_line('EXCEPTION - ' || substr(SQLERRM, 1, 200));
      dbms_output.put_line('EXCEPTION - ' || substr(SQLERRM, 201, 400));
  END update_element_test;

  --------------------------------------------------------------------
  --  name:            create_element_test
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   14/12/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        
  --  in params:       
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  14/12/2010  Dalit A. Raviv    initial build
  -------------------------------------------------------------------- 
  PROCEDURE create_element_test IS
  
    l_effective_start_date  DATE;
    l_effective_end_date    DATE;
    l_object_version_number NUMBER;
    l_element_entry_id      NUMBER;
    l_create_warning        BOOLEAN;
  
  BEGIN
  
    --fnd_global.APPS_INITIALIZE(user_id => 2470,resp_id => 50817,resp_appl_id => 800);
    pay_element_entry_api.create_element_entry(p_effective_date    => SYSDATE,
                                               p_business_group_id => g_business_group_id, --0
                                               p_assignment_id     => 881,
                                               p_element_link_id   => 83, --Travel Expense 84, -- Car Maintenance
                                               p_entry_type        => 'E',
                                               p_input_value_id1   => 148715, --148716,
                                               p_entry_value1      => 5000,
                                               --p_input_value_id2            => g_input_value_id_tab(2),
                                               --p_entry_value2               => lv_input_value_code_2,
                                               p_effective_start_date  => l_effective_start_date,
                                               p_effective_end_date    => l_effective_end_date,
                                               p_element_entry_id      => l_element_entry_id,
                                               p_object_version_number => l_object_version_number,
                                               p_create_warning        => l_create_warning);
  
    IF NOT l_create_warning THEN
      dbms_output.put_line('Api finished with warning - ' ||
                           substr(SQLERRM, 1, 200));
    ELSE
      dbms_output.put_line('Api finished with success ');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      dbms_output.put_line('EXCEPTION - ' || substr(SQLERRM, 1, 200));
      dbms_output.put_line('EXCEPTION - ' || substr(SQLERRM, 201, 400));
  END create_element_test;

  --------------------------------------------------------------------
  --  name:            get_element_type_id
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   13/12/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        
  --  in params:       
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  13/12/2010  Dalit A. Raviv    initial build
  -------------------------------------------------------------------- 
  FUNCTION get_element_type_id(p_element_name         IN VARCHAR2,
                               p_effective_start_date IN DATE) RETURN NUMBER IS
  
    l_element_type_id NUMBER;
  
  BEGIN
    -- check if element name exists in element type table
    SELECT pet.element_type_id
      INTO l_element_type_id
      FROM pay_element_types_f pet
     WHERE upper(pet.element_name) = upper(p_element_name)
       AND p_effective_start_date BETWEEN pet.effective_start_date AND
           pet.effective_end_date
       AND pet.business_group_id = g_business_group_id; -- 0
  
    RETURN l_element_type_id;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 0;
  END get_element_type_id;

  --------------------------------------------------------------------
  --  name:            get_element_link_id
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   13/12/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        
  --  in params:       
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  13/12/2010  Dalit A. Raviv    initial build
  -------------------------------------------------------------------- 
  FUNCTION get_element_link_id(p_assignment_id        IN NUMBER,
                               p_element_type_id      IN NUMBER,
                               p_effective_start_date IN DATE) RETURN NUMBER IS
  
    l_element_link_id NUMBER := NULL;
  BEGIN
    -- check if element link exists
    l_element_link_id := hr_entry_api.get_link(p_assignment_id,
                                               p_element_type_id,
                                               p_effective_start_date);
    RETURN l_element_link_id;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN - 1;
  END get_element_link_id;

  --------------------------------------------------------------------
  --  name:            get_business_group_id
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   14/12/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Get bussiness group id      
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  14/12/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_business_group_id RETURN NUMBER IS
  
  BEGIN
    RETURN (fnd_profile.VALUE('PER_BUSINESS_GROUP_ID'));
  END get_business_group_id;

  --------------------------------------------------------------------
  --  name:            get_element_entry_id
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   15/12/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose:         get element entry id   by element name assignment id
  --                   and effective date.
  --  return:             
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  15/12/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE get_element_entry_id(p_element_name     pay_element_types_f.element_name%TYPE,
                                 p_assignment_id    per_all_assignments_f.assignment_id%TYPE,
                                 p_effective_date   DATE,
                                 p_obj_ver_no       OUT pay_element_entries_f.object_version_number%TYPE,
                                 p_start_date       OUT DATE,
                                 p_element_entry_id OUT pay_element_entries.element_entry_id%TYPE) IS
  
    --l_element_entry_id pay_element_entries.element_entry_id%type;
  
  BEGIN
  
    -- Get element entry id
    SELECT peef.element_entry_id,
           peef.object_version_number,
           peef.effective_start_date
      INTO p_element_entry_id, p_obj_ver_no, p_start_date
      FROM pay_element_entries_f peef, pay_element_types_f petf
     WHERE peef.assignment_id = p_assignment_id
       AND peef.element_type_id = petf.element_type_id
       AND petf.element_name = p_element_name
       AND p_effective_date BETWEEN peef.effective_start_date AND
           peef.effective_end_date
       AND p_effective_date BETWEEN petf.effective_start_date AND
           petf.effective_end_date;
  
  EXCEPTION
    WHEN no_data_found THEN
      p_element_entry_id := 0;
      p_obj_ver_no       := NULL;
      p_start_date       := NULL;
  END get_element_entry_id;

  --------------------------------------------------------------------
  --  name:            get_element_name_by_code
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   04/02/2011 
  --------------------------------------------------------------------
  --  purpose:         get element entry name by the hargal code.
  --                   we keep at attribute 2 of element type table 
  --                   the hargal code
  --  return:          element name   
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  04/02/2011  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  function get_element_name_by_code (p_hargal_code in varchar2) return varchar2 is
  
    l_element_name varchar2(80) := null;
  
  begin
    select type.element_name--, attribute2
    into   l_element_name
    from   pay_element_types_f  type
    where  attribute2           = p_hargal_code;
    
    return l_element_name;
  exception
    when others then
      return null;  
  end get_element_name_by_code;

  --------------------------------------------------------------------
  --  name:            get_element_name_is_valid
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   04/02/2011 
  --------------------------------------------------------------------
  --  purpose:         get_element_name_is_valid 
  --                   check the element name is valid at oracle
  --                   
  --  return:          Y -> valid 
  --                   N -> not valid  
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  04/02/2011  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  function get_element_name_is_valid (p_element_name in varchar2) return varchar2 is
  
    l_count number := null;
    
  begin
    select count(1) 
    into   l_count
    from   pay_element_types_f  type
    where  type.element_name    = p_element_name;
    
    if l_count = 0 then
      return 'N';
    else
       return 'Y';
    end if;
  end get_element_name_is_valid;

  --------------------------------------------------------------------
  --  name:            get_emp_ele_exist_for_period
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   04/02/2011 
  --------------------------------------------------------------------
  --  purpose:         get_emp_ele_exist_for_period - check that this elemnet
  --                   at this date exist(UPDATE) or not exist (CREATE) record
  --                   this function come to check duplication of upload elements
  --                   in the same specific date
  --                   
  --  return:          Y - element exist - need to update element for the person
  --                   N - element do not exist - need to create element for the person 
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  04/02/2011  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  function get_emp_ele_exist_for_period (p_element_name   in varchar2,
                                         p_effective_date in date) return varchar2 is
  
    l_exist varchar2(5) :=  null;
   
  begin
    select 'Y'
    into   l_exist
    from   pay_input_values_f          inpval,
           pay_element_types_f         type,
           pay_element_links_f         link,
           pay_element_entry_values_f  value,
           pay_element_entries_f       entry
    where  type.element_type_id        = link.element_type_id
    and    entry.element_link_id       = link.element_link_id
    and    entry.entry_type            in ('A', 'R', 'E')
    and    value.element_entry_id      = entry.element_entry_id
    and    value.effective_start_date  = entry.effective_start_date
    and    value.effective_end_date    = entry.effective_end_date
    and    inpval.input_value_id       = value.input_value_id
    and    entry.assignment_id         = g_assignment_id   -- 881
    and    type.element_name           = p_element_name    -- 'Basic Salary'
    and    entry.effective_start_date  = p_effective_date; -- to_date('14/12/2010', 'dd/mm/yyyy')
    
    return l_exist;
    
  exception
    when no_data_found then
      return 'N';
    when too_many_rows then
      return 'Y';
    when others then
      return 'N';
  end get_emp_ele_exist_for_period;

  --------------------------------------------------------------------
  --  name:            get_ele_upd_mode
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   09/02/2011 
  --------------------------------------------------------------------
  --  purpose:         get_emp_ele_exist_for_period - check that this elemnet
  --                   at this date exist(UPDATE) or not exist (CREATE) record
  --                   this function check if employee have the element if yes we will
  --                   do update to the element.
  --                   
  --  return:          UPDATE - element exist - need to update element for the person
  --                   CREATE - element do not exist - need to create element for the person 
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  09/02/2011  Dalit A. Raviv    initial build
  --  1.1  18/08/2013  Dalit A. Raviv    enlarge l_exist var 
  --------------------------------------------------------------------
  function get_ele_upd_mode (p_element_name   in varchar2,
                             p_effective_date in date) return varchar2 is
  
    l_exist varchar2(10) :=  null;
   
  begin
    select 'UPDATE'
    into   l_exist
    from   pay_input_values_f          inpval,
           pay_element_types_f         type,
           pay_element_links_f         link,
           pay_element_entry_values_f  value,
           pay_element_entries_f       entry
    where  type.element_type_id        = link.element_type_id
    and    entry.element_link_id       = link.element_link_id
    and    entry.entry_type            in ('A', 'R', 'E')
    and    value.element_entry_id      = entry.element_entry_id
    and    value.effective_start_date  = entry.effective_start_date
    and    value.effective_end_date    = entry.effective_end_date
    and    inpval.input_value_id       = value.input_value_id
    and    entry.assignment_id         = g_assignment_id   -- 881
    and    type.element_name           = p_element_name    -- 'Basic Salary'
    and    p_effective_date            between entry.effective_start_date and entry.effective_end_date; 
    
    return l_exist;
    
  exception
    when no_data_found then
      return 'CREATE';
    when too_many_rows then
      return 'UPDATE';
    when others then
      return 'CREATE';
  end get_ele_upd_mode;
  
  --------------------------------------------------------------------
  --  name:            check_temp_table
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   28/12/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose:         Program that will check xxhr_element_det_interface table
  --                   if there are rows exists, program can not run again
  --  return:          Y there are rows exist, N if empty  
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  28/12/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------   
  function check_temp_table return varchar2 is
    l_count number := 0;
  begin
    select count(1)
    into   l_count
    from   xxhr_element_det_interface xei;
    
    if l_count > 0 then
      return 'Y';
    else
      return 'N';
    end if;
  exception
    when others then 
      return 'N'; 
  end check_temp_table;
  
  --------------------------------------------------------------------
  --  name:            get_termination_exist
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   04/01/2011 
  --------------------------------------------------------------------
  --  purpose:         function that will return if person have termianation date
  --                   
  --  Return:          NONE   if no termination
  --                   FUTURE if the terminate date is in the future
  --                   PAST   if the terminate date allready pass
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  04/01/2011  Dalit A. Raviv    initial build
  -------------------------------------------------------------------- 
  function get_termination_exist (p_effective_date in date) return varchar2 is
  
    l_termiante_date date := null;
    
  begin
    select nvl(pps.final_process_date,pps.actual_termination_date)
    into   l_termiante_date
    from   per_periods_of_service pps
    where  pps.person_id          = g_person_id
    and    pps.date_start         = (select max(pps1.date_start)
                                     from   per_periods_of_service pps1
                                     where  pps1.person_id         = g_person_id --258
                                    );
                                    
    if (l_termiante_date is null) or (trunc(l_termiante_date) = p_effective_date) then
      return 'NONE';
    elsif trunc(l_termiante_date) > p_effective_date then
      return 'FUTURE';
    elsif trunc(l_termiante_date) < p_effective_date then
      return 'PAST';
    end if; 
  exception
    when others then
      return 'NONE';  -- this case the API will catch the error if there will be                                
  end;
  
  --------------------------------------------------------------------
  --  name:            ins_into_det_interface
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   29/12/2010 
  --------------------------------------------------------------------
  --  purpose:         insert rows to xxhr_element_det_interface table
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  29/12/2010  Dalit A. Raviv    initial build
  -------------------------------------------------------------------- 
  procedure ins_into_det_interface (p_elements_rec IN  t_elements_rec,
                                    p_err_code     out varchar2,
                                    p_err_desc     out varchar2) is 
                                    
    PRAGMA AUTONOMOUS_TRANSACTION;                                
    l_entity_id number := null;
  
  begin
    -- get entity id
    select xxhr_element_det_inter_entity.nextval
    into   l_entity_id
    from   dual;
    -- insert row 
    insert into xxhr_element_det_interface( batch_id,
                                            entity_id,
                                            employee_number,
                                            effective_start_date,
                                            effective_end_date,
                                            element_code,
                                            element_name,
                                            entry_value1,
                                            entry_value2,
                                            entry_value3,
                                            entry_value4,
                                            entry_value5,
                                            entry_value6,
                                            status,
                                            last_update_date,
                                            last_updated_by,
                                            creation_date,
                                            created_by
                                          )
    values                                ( g_batch_id,
                                            l_entity_id,
                                            p_elements_rec.employee_number,
                                            p_elements_rec.effective_start_date,
                                            p_elements_rec.effective_end_date,
                                            p_elements_rec.element_code,
                                            p_elements_rec.element_name,
                                            p_elements_rec.entry_value1,
                                            p_elements_rec.entry_value2,
                                            p_elements_rec.entry_value3,
                                            p_elements_rec.entry_value4,
                                            p_elements_rec.entry_value5,
                                            p_elements_rec.entry_value6,
                                            'NEW',
                                            sysdate,
                                            g_user_id,
                                            sysdate,
                                            g_user_id
                                          );
    p_err_code := 0;
    p_err_desc := null;
    commit;
  exception
    when others then
      rollback;
      p_err_code := 1;
      p_err_desc := 'GEN EXC - ins_into_det_interface - '||substr(sqlerrm,1,240);
  end ins_into_det_interface;
   
  --------------------------------------------------------------------
  --  name:            ins_into_log_interface
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   29/12/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose:         insert rows to xxhr_element_log_interface table
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  29/12/2010  Dalit A. Raviv    initial build
  -------------------------------------------------------------------- 
  procedure ins_into_log_interface (p_elements_log_rec IN  t_elements_log_rec,
                                    p_err_code         out varchar2,
                                    p_err_desc         out varchar2)  is
  
    PRAGMA AUTONOMOUS_TRANSACTION;
  
  begin
    -- insert row 
    insert into XXHR_ELEMENT_LOG_INTERFACE( batch_id,             -- number      
                                            entity_id,            -- number 
                                            employee_number,      -- varchar2(30)
                                            effective_start_date, -- date
                                            effective_end_date,   -- date
                                            element_code,         -- varchar2(10)
                                            element_name,         -- varchar2(30)
                                            status,               -- varchar2(30)
                                            log_code,             -- varchar2 (5)
                                            log_message,          -- varchar2 (2500)
                                            last_update_date,     -- date
                                            last_updated_by,      -- number
                                            creation_date,        -- date
                                            created_by            -- number
                                          )
    values                                ( p_elements_log_rec.batch_id,
                                            p_elements_log_rec.entity_id,
                                            p_elements_log_rec.employee_number,
                                            p_elements_log_rec.effective_start_date,
                                            p_elements_log_rec.effective_end_date,
                                            p_elements_log_rec.element_code,
                                            p_elements_log_rec.element_name,
                                            p_elements_log_rec.status,
                                            p_elements_log_rec.log_code,
                                            p_elements_log_rec.log_message,
                                            sysdate,
                                            g_user_id,
                                            sysdate,
                                            g_user_id
                                          );
    p_err_code := 0;
    p_err_desc := null;
    commit;
  exception
    when others then
      rollback;
      p_err_code := 1;
      p_err_desc := 'GEN EXC - ins_into_log_interface - '||substr(sqlerrm,1,240);
  end;
  
  --------------------------------------------------------------------
  --  name:            upd_det_interface
  --  create by:       Dalit A. Raviv 
  --  Revision:        1.0 
  --  creation date:   04/01/2011 6:43:07 PM
  --------------------------------------------------------------------
  --  purpose :        update status at xxhr_element_det_interface tbl
  --------------------------------------------------------------------
  --  ver  date        name             desc
  --  1.0  04/01/2011  Dalit A. Raviv   initial build
  --------------------------------------------------------------------
  procedure upd_det_interface (p_employee_number in  number,
                               p_entity_id       in  number,
                               p_status          in  varchar2,
                               p_err_code        out varchar2,
                               p_err_desc        out varchar2) is
                               
    PRAGMA AUTONOMOUS_TRANSACTION;
    
  begin 
   if p_employee_number is null and p_entity_id is null then
     update xxhr_element_det_interface xei
     set    xei.status                 = p_status;
   elsif p_employee_number is not null and p_entity_id is null then
     update xxhr_element_det_interface xei
     set    xei.status                 = p_status
     where  xei.employee_number        = p_employee_number;
   elsif p_entity_id is not null then
     update xxhr_element_det_interface xei
     set    xei.status                 = p_status
     where  xei.entity_id              = p_entity_id;
   end if;
   commit;
   
  exception
    when others then
      rollback;
      p_err_code := 1;
      p_err_desc := 'GEN EXC - upd_det_interface - '||substr(sqlerrm,1,240);
  end upd_det_interface;
  
  --------------------------------------------------------------------
  --  name:            delete_det_interface
  --  create by:       Dalit A. Raviv 
  --  Revision:        1.0 
  --  creation date:   04/01/2011 6:43:07 PM
  --------------------------------------------------------------------
  --  purpose :        delete rows from xxhr_element_det_interface tbl
  --------------------------------------------------------------------
  --  ver  date        name             desc
  --  1.0  04/01/2011  Dalit A. Raviv   initial build
  --------------------------------------------------------------------
  procedure delete_det_interface (errbuf   out varchar2,
                                  retcode  out varchar2/*,
                                  p_status in  varchar2*/) is
                            
    PRAGMA AUTONOMOUS_TRANSACTION;   
                         
  begin
    errbuf  := null;
    retcode := 0;
    
    delete xxhr_element_det_interface xei;
    --where  xei.status                 = nvl(p_status,xei.status); -- ERROR / SUCCESS
    commit;
  exception  
    when others then
      errbuf  := 'GEN EXC - delete_det_interface - '||substr(sqlerrm,1,240);
      retcode := 1;
  end delete_det_interface;
  
  --------------------------------------------------------------------
  --  name:            delete_log_interface
  --  create by:       Dalit A. Raviv 
  --  Revision:        1.0 
  --  creation date:   10/02/2011 6:43:07 PM
  --------------------------------------------------------------------
  --  purpose :        delete rows from xxhr_element_log_interface tbl
  --------------------------------------------------------------------
  --  ver  date        name             desc
  --  1.0  10/02/2011  Dalit A. Raviv   initial build
  --------------------------------------------------------------------
  procedure delete_log_interface (errbuf   out varchar2,
                                  retcode  out varchar2/*,
                                  p_status in  varchar2*/) is
                            
    PRAGMA AUTONOMOUS_TRANSACTION;   
                         
  begin
    errbuf  := null;
    retcode := 0;
    
    delete xxhr_element_log_interface xei;
    --where  xei.status                 = nvl(p_status,xei.status); -- ERROR / SUCCESS
    commit;
  exception  
    when others then
      errbuf  := 'GEN EXC - delete_det_interface - '||substr(sqlerrm,1,240);
      retcode := 1;
  end delete_log_interface;
  
  --------------------------------------------------------------------
  --  name:            get_value_from_line
  --  create by:       Dalit A. Raviv 
  --  Revision:        1.0 
  --  creation date:   29/12/2010 6:43:07 PM
  --------------------------------------------------------------------
  --  purpose :        get value from excel line 
  --                   return short string each time by the deliminar 
  --------------------------------------------------------------------
  --  ver  date        name             desc
  --  1.0  29/12/2009  Dalit A. Raviv   initial build
  --------------------------------------------------------------------
  function get_value_from_line( p_line_string in out varchar2,
                                p_err_msg     in out varchar2,
                                c_delimiter   in varchar2) return varchar2 is
   
    l_pos        number;
    l_char_value varchar2(20);
     
  begin
     
    l_pos := instr(p_line_string, c_delimiter);
     
    if nvl(l_pos, 0) < 1 then
       l_pos := length(p_line_string);
    end if;
     
    l_char_value := ltrim(rtrim(substr(p_line_string, 1, l_pos - 1)));
     
    p_line_string := substr(p_line_string, l_pos + 1);
     
    return l_char_value;
  exception
   when others then
     p_err_msg := 'get_value_from_line - '||substr(sqlerrm,1,250);
  end get_value_from_line;
  
  --------------------------------------------------------------------
  --  name:            handle_salary_basis
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   10/01/2011 
  --------------------------------------------------------------------
  --  purpose:         procedure that handle the salary basis validation
  --                   1) check if ass has salary basis
  --                   2) if not by the elements find the salary basis
  --                   3) upd ass with salary basis + payroll (by API)
  --                   
  --  In  Params:      p_effective_date
  --                   p_employee_number
  --  Out Params:      p_err_code 0    if success , 1 if err. 
  --                   p_err_msg  null if success , 1 if err. 
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  10/01/2011  Dalit A. Raviv    initial build
  --------------------------------------------------------------------  
  procedure handle_salary_basis (p_effective_date  in  date,    -- get_emp_pop_r.effective_start_date
                                 p_employee_number in  varchar2,-- get_emp_pop_r.employee_number
                                 p_err_code        out varchar2,
                                 p_err_msg         out varchar2) is
    
    -- get all elements of person as group  
    cursor get_emp_details_c (p_employee_number in varchar2) is
      select *
      from   xxhr_element_det_interface xei
      where  employee_number            = p_employee_number;
      --and    batch_id                   = g_batch_id;
     
    l_elements_log_rec  XXHR_PAY_ELEMENTS_PKG.t_elements_log_rec;
    l_salary_basis      varchar2(10)   := null; -- Y/N
    l_salary_basis_name varchar2(30)   := null;
    l_pay_basis_id      number         := null;
    l_err_code          varchar2(10)   := null;
    l_err_msg           varchar2(2500) := null;  
    l_database          varchar2(150)  := null;
    
  begin
    p_err_code := 0;
    p_err_msg  := null;
    
    SELECT name 
    INTO   l_database
    FROM   v$database;
    
    l_salary_basis := XXHR_PERSON_ASSIGNMENT_PKG.get_salary_basis_by_ass 
                                 (g_assignment_id,
                                  p_effective_date,
                                  g_business_group_id);
     
    if l_database = 'PROD' then
      if  l_salary_basis = 'N' then
        p_err_code := 1;
        p_err_msg  := 'Employee ' || p_employee_number||' Assignment: Salary Basic is missing';    
        l_elements_log_rec := null;
        fnd_file.put_line(fnd_file.log,'Employee ' || p_employee_number ||' Assignment: Salary Basic is missing');
        l_elements_log_rec.batch_id              := g_batch_id;
        l_elements_log_rec.employee_number       := p_employee_number;
        l_elements_log_rec.effective_start_date  := p_effective_date;
        l_elements_log_rec.status                := 'ERROR';
        l_elements_log_rec.log_code              := 8;
        l_elements_log_rec.log_message           := 'Assignment: Salary Basic is missing';
        l_err_code := 0;
        l_err_msg  := null;
        ins_into_log_interface (p_elements_log_rec => l_elements_log_rec, -- i t_elements_log_rec,
                                p_err_code         => l_err_code,         -- o v
                                p_err_desc         => l_err_msg);         -- o v      
          
        upd_det_interface (p_employee_number,
                           null,
                           'ERROR', -- p_status 
                           l_err_code,
                           l_err_msg); 
      else
        p_err_code := 0;
        p_err_msg  := null;
      end if;
    else
      if  l_salary_basis = 'N' then
        for get_emp_details_r in get_emp_details_c (p_employee_number)   loop
          begin
            select pb.name                  salary_basis, 
                   pb.pay_basis_id
            into   l_salary_basis_name,           
                   l_pay_basis_id       
            from   per_pay_bases            pb, 
                   pay_input_values_f       iv,
                   pay_element_types_f      type
            where  pb.business_group_id + 0 = g_business_group_id
            and    pb.input_value_id        = iv.input_value_id
            and    p_effective_date         between iv.effective_start_date and iv.effective_end_date
            and    type.element_name        = get_emp_details_r.element_name
            and    type.element_type_id     = iv.element_type_id
            and    p_effective_date         between type.effective_start_date and type.effective_end_date;
            
            --find value exit inner loop 
            exit;
          exception
            when others then 
              null;
          end;
        end loop;
        if l_pay_basis_id is not null then
          XXHR_PERSON_ASSIGNMENT_PKG.update_emp_asg_criteria(p_effective_date,     -- i d p_start_date 
                                                             g_assignment_id,      -- i n p_assg_id   
                                                             g_business_group_id,  -- i n p_bg_id
                                                             l_pay_basis_id,       -- i v p_pay_basis
                                                             l_err_code,           -- o v p_err_code
                                                             l_err_msg);           -- o v p_err_desc
                                                       
          if l_err_code <> 0 then
            l_elements_log_rec := null;
            fnd_file.put_line(fnd_file.log,'Employee ' || p_employee_number ||
                              ' Assignment: Salary Basic is missing API Failed ');
            l_elements_log_rec.batch_id              := g_batch_id;
            l_elements_log_rec.employee_number       := p_employee_number;
            l_elements_log_rec.effective_start_date  := p_effective_date;
            l_elements_log_rec.status                := 'ERROR';
            l_elements_log_rec.log_code              := 8;
            l_elements_log_rec.log_message           := 'Assignment: Salary Basic is missing API Failed '||l_err_msg;
            l_err_code := 0;
            l_err_msg  := null;
            ins_into_log_interface (p_elements_log_rec => l_elements_log_rec, -- i t_elements_log_rec,
                                    p_err_code         => l_err_code,         -- o v
                                    p_err_desc         => l_err_msg);         -- o v      
            
            upd_det_interface (p_employee_number,
                               null,
                               'ERROR', -- p_status 
                               l_err_code,
                               l_err_msg);
            p_err_code := 1;
            p_err_msg  := 'Employee '||p_employee_number||' Assignment: Salary Basic is missing - API Failed ' ; 
          end if;
        else
          l_elements_log_rec := null;
          fnd_file.put_line(fnd_file.log,'Employee ' || p_employee_number ||
                            ' Assignment: Salary Basic is missing');
          l_elements_log_rec.batch_id              := g_batch_id;
          l_elements_log_rec.employee_number       := p_employee_number;
          l_elements_log_rec.effective_start_date  := p_effective_date;
          l_elements_log_rec.status                := 'ERROR';
          l_elements_log_rec.log_code              := 8;
          l_elements_log_rec.log_message           := 'Assignment: Salary Basic is missing';
          l_err_code := 0;
          l_err_msg  := null;
          ins_into_log_interface (p_elements_log_rec => l_elements_log_rec, -- i t_elements_log_rec,
                                  p_err_code         => l_err_code,         -- o v
                                  p_err_desc         => l_err_msg);         -- o v      
          
          upd_det_interface (p_employee_number,
                             null,
                             'ERROR', -- p_status 
                             l_err_code,
                             l_err_msg); 
          p_err_code := 1;
          p_err_msg  := 'Employee ' || p_employee_number||' Assignment: Salary Basic is missing';                           
        end if;-- l_pay_basis_id is null
      else
        p_err_code := 0;
        p_err_msg  := null;
      end if;-- l_salary_base = N 
    end if; -- database
  exception
    when others then
      p_err_code := 1;
      p_err_msg  := 'GEN EXC handle_salary_basis - '||substr(sqlerrm,1,240);
  end handle_salary_basis;

  --------------------------------------------------------------------
  --  name:            upload_data
  --  create by:       Dalit A. Raviv 
  --  Revision:        1.0 
  --  creation date:   29/12/2010 6:43:07 PM
  --------------------------------------------------------------------
  --  purpose :        upload data to xxhr_element_det_interface table
  --------------------------------------------------------------------
  --  ver  date        name             desc
  --  1.0  29/12/2009  Dalit A. Raviv   initial build
  --  1.1  03/02/2011  Dalit A. Raviv   1) add new elements to handle
  --                                    2) elemnet travel expence will load only for employees
  --                                       that have pay value.
  --                                    3) Vacation and sickness change the pay value place.
  --------------------------------------------------------------------
  procedure upload_data (p_location in  varchar2, --/UtlFiles/HR/BENEFITS
                         p_filename in  varchar2,
                         p_err_code out varchar2,
                         p_err_msg  out varchar2) is
  
    l_file_hundler       utl_file.file_type;
    l_line_buffer        varchar2(2000);
    l_counter            number               := 0;
    l_pos                number;
    c_delimiter          constant varchar2(1) := ',';
    
    l_emp_number         per_all_people_f.employee_number%TYPE := NULL;
    l_element_code       varchar2(10) := NULL;
    l_pay_value          number       := NULL;
    l_pay_qty            number       := NULL;
    l_element_end_date   varchar2(50) := NULL;
    l_element_start_date varchar2(50) := NULL;
    l_holiday_tot        number       := NULL;
    l_holiday_balance    number       := NULL;
    l_sickness_use       number       := NULL;
    l_sickness_balance   number       := NULL;
    l_contract_type      varchar2(50) := null;
    l_Hr_rate            number       := null;
    l_num_payments       number       := null;
    l_flag               varchar2(5)  := 'Y';
    l_pay_basis_id       number       := null;
    l_pay_basis_name     varchar2(150):= null;
    
    l_err_code           varchar2(10) := 0;
    l_err_msg            varchar2(500):= null;
    l_error_row          varchar2(10) := 'N';
    
    l_elements_rec       XXHR_PAY_ELEMENTS_PKG.t_elements_rec;
    l_elements_log_rec   XXHR_PAY_ELEMENTS_PKG.t_elements_log_rec;
  
  begin
    p_err_code := 0;
    p_err_msg  := null;
    -- handle open file to read and handle file exceptions
    begin
      l_file_hundler := utl_file.fopen( location     => p_location,
                                        filename     => p_filename,
                                        open_mode    => 'r',
                                        max_linesize => 32000);
    exception
      when utl_file.invalid_path then
        p_err_code := 1;
        p_err_msg  := 'Import file was failes. 1 Invalid Path for ' || ltrim(p_filename);
        fnd_file.put_line(fnd_file.log,'Invalid Path for ' || ltrim(p_filename));
        l_err_code                     := 0;
        l_err_msg                      := null;
        l_elements_log_rec             := null;
        l_elements_log_rec.batch_id    := g_batch_id;
        l_elements_log_rec.status      := 'ERROR';
        l_elements_log_rec.log_code    := 1;
        l_elements_log_rec.log_message := 'Import file was failes. 1 Invalid Path for ' || ltrim(p_filename);
        ins_into_log_interface (p_elements_log_rec => l_elements_log_rec, -- i t_elements_log_rec,
                                p_err_code         => l_err_code,         -- o v
                                p_err_desc         => l_err_msg);         -- o v    
        upd_det_interface (null,
                           null,
                           'ERROR', -- p_status 
                           l_err_code,
                           l_err_msg); 
        raise;
      when utl_file.invalid_mode then
        p_err_code := 1;
        p_err_msg  := 'Import file was failes. 2 Invalid Mode for ' || ltrim(p_filename);
        fnd_file.put_line(fnd_file.log,'Invalid Mode for ' || ltrim(p_filename));
        l_err_code                     := 0;
        l_err_msg                      := null;
        l_elements_log_rec             := null;
        l_elements_log_rec.batch_id    := g_batch_id;
        l_elements_log_rec.status      := 'ERROR';
        l_elements_log_rec.log_code    := 1;
        l_elements_log_rec.log_message := 'Import file was failes. 2 Invalid Mode for ' || ltrim(p_filename);
        ins_into_log_interface (p_elements_log_rec => l_elements_log_rec, -- i t_elements_log_rec,
                                p_err_code         => l_err_code,         -- o v
                                p_err_desc         => l_err_msg);         -- o v    
        upd_det_interface (null,
                           null,
                           'ERROR', -- p_status 
                           l_err_code,
                           l_err_msg); 
        raise;
      when utl_file.invalid_operation then
        p_err_code := 1;
        p_err_msg  := 'Invalid operation for ' || ltrim(p_filename) ||substr(SQLERRM,1,500);
        fnd_file.put_line(fnd_file.log,'Invalid operation for ' || ltrim(p_filename) ||SQLERRM);
        l_err_code                     := 0;
        l_err_msg                      := null;
        l_elements_log_rec             := null;
        l_elements_log_rec.batch_id    := g_batch_id;
        l_elements_log_rec.status      := 'ERROR';
        l_elements_log_rec.log_code    := 1;
        l_elements_log_rec.log_message := 'Import file was failes. 3 Invalid operation for ' || ltrim(p_filename)||substr(SQLERRM,1,500);
        ins_into_log_interface (p_elements_log_rec => l_elements_log_rec, -- i t_elements_log_rec,
                                p_err_code         => l_err_code,         -- o v
                                p_err_desc         => l_err_msg);         -- o v  
        upd_det_interface (null,
                           null,
                           'ERROR', -- p_status 
                           l_err_code,
                           l_err_msg); 
        raise;
      when others then
        p_err_code := 1;
        p_err_msg  := 'Other for ' || ltrim(p_filename)||substr(SQLERRM,1,500);
        fnd_file.put_line(fnd_file.log,'Other for ' || ltrim(p_filename));
        l_err_code                     := 0;
        l_err_msg                      := null;
        l_elements_log_rec             := null;
        l_elements_log_rec.batch_id    := g_batch_id;
        l_elements_log_rec.status      := 'ERROR';
        l_elements_log_rec.log_code    := 1;
        l_elements_log_rec.log_message := 'Import file was failes. 4 Other for ' || ltrim(p_filename);
        ins_into_log_interface (p_elements_log_rec => l_elements_log_rec, -- i t_elements_log_rec,
                                p_err_code         => l_err_code,         -- o v
                                p_err_desc         => l_err_msg);         -- o v   
        upd_det_interface (null,
                           null,
                           'ERROR', -- p_status 
                           l_err_code,
                           l_err_msg); 
        raise;
    end;
    
    -- start read from file, do needed validation, and upload data to table
    -- Loop For All File's Lines
    loop
      begin
        -- goto next line
        l_counter           := l_counter + 1;
        l_err_msg           := NULL;
        l_emp_number        := NULL;
        l_element_code      := NULL;
        --l_element_desc      := NULL;
        l_pay_value         := NULL;
        l_pay_qty           := NULL;
        l_element_end_date  := NULL;
        l_holiday_tot       := NULL;
        l_holiday_balance   := NULL;
        l_sickness_use      := NULL;
        l_sickness_balance  := NULL;
        l_contract_type     := null;
        l_Hr_rate           := null;
        l_num_payments      := null;
        l_flag              := 'Y';
        l_pay_basis_id      := null;
        l_pay_basis_name    := null;
        
        -- Get Line and handle exceptions
        begin
          utl_file.get_line(file   => l_file_hundler,
                            buffer => l_line_buffer);
        exception
          when utl_file.read_error then
            l_err_msg := 'Read Error for line: ' || l_counter;
            raise invalid_element;
          when no_data_found then
            exit;
          when others then
            l_err_msg := 'Read Error for line: ' || l_counter ||', Error: ' || substr(SQLERRM,1,500);
            raise invalid_element;
        end; 
        -- Get data from line separate by deliminar
        if l_counter > 1 then
          l_pos := 0;
          
          -- Employee number                                        
          l_emp_number    := get_value_from_line(l_line_buffer,
                                                 l_err_msg,
                                                 c_delimiter);
          -- Vontract Type 03/02/2011                                     
          l_contract_type := get_value_from_line(l_line_buffer,
                                                 l_err_msg,
                                                 c_delimiter);                                                 
          -- Har-Gal code 
          l_element_code  := get_value_from_line(l_line_buffer,
                                                 l_err_msg,
                                                 c_delimiter);                                  
          -- Pay value
          l_pay_value     := get_value_from_line(l_line_buffer,
                                                 l_err_msg,
                                                 c_delimiter);
          -- Pay qty                                   
          l_pay_qty       := get_value_from_line(l_line_buffer,
                                                 l_err_msg,
                                                 c_delimiter);
          -- Hour Rate 03/02/2011                                       
          l_Hr_rate       := get_value_from_line(l_line_buffer,
                                                 l_err_msg,
                                                 c_delimiter); 
          -- number of Payments 03/02/2011                                         
          l_num_payments  := get_value_from_line(l_line_buffer,
                                                 l_err_msg,
                                                 c_delimiter); 
          -- Holiday total (annual quota)
          l_holiday_tot  := get_value_from_line(l_line_buffer,
                                                l_err_msg,
                                                c_delimiter);
          -- Holiday Balance 
          l_holiday_balance := get_value_from_line(l_line_buffer,
                                                   l_err_msg,
                                                   c_delimiter);
          -- Sickness use 
          l_sickness_use  := get_value_from_line(l_line_buffer,
                                                 l_err_msg,
                                                 c_delimiter);
          -- Sickness balance                                  
          l_sickness_balance  := get_value_from_line(l_line_buffer,
                                                     l_err_msg,
                                                     c_delimiter);
          -- elements period date                                           
          l_element_start_date := get_value_from_line(l_line_buffer,
                                                      l_err_msg,
                                                      c_delimiter);
          -- get element period first date 03/02/2011                                                                                    
          g_element_start_date := to_date(l_element_start_date,'DD/MM/RRRR HH24:MI:SS');
          -- to_date(l_element_start_date,'DD/MM/RRRR HH24:MI:SS');
          -- add_months(last_day(to_date(l_element_start_date,'DD/MM/YYYY')) + 1 ,-1);                                   
          -- general for all elements
          --fnd_date.canonical_to_date return date at this format 'YYYY/MM/DD HH24:MI:SS'
          --l_element_desc                      := get_element_name_by_code (l_element_code);
          l_elements_rec                      := null;
          l_elements_rec.employee_number      := l_emp_number;
          l_elements_rec.effective_start_date := g_element_start_date; -- to_date(l_element_start_date,'DD/MM/RRRR HH24:MI:SS');
          l_elements_rec.element_code         := l_element_code;
          l_elements_rec.element_name         := get_element_name_by_code (l_element_code);
          -- each element the value at the excel is in different place
          if l_element_code = '19' then      -- 19 Travel Expence
            l_elements_rec.entry_value1       := l_pay_value;
            l_elements_rec.entry_value2       := null;
            l_elements_rec.entry_value3       := null;
            l_elements_rec.entry_value4       := null;
          -- 1.1 03/02/2011 Dalit A. Raviv
          elsif l_element_code = '22' then   -- 22 Hourly Travel Expence 
            -- Har-Gal file bring element "Hourly Travel Expence" for all employees
            -- I will create this element only if there is a pay value.
            -- person who get "Travel Expence" can not get "Hourly Travel Expence"
            if trim(l_pay_value) is not null then     
              l_elements_rec.entry_value1       := trim(l_pay_value);
              l_elements_rec.entry_value2       := l_pay_qty;
              l_elements_rec.entry_value3       := null;-- l_Hr_rate
              l_elements_rec.entry_value4       := null;  
            else
              l_flag := 'N';
            end if;
          elsif l_element_code = '2' then       -- loan
            l_elements_rec.entry_value1       := l_pay_value;
            l_elements_rec.entry_value2       := l_num_payments;
            l_elements_rec.entry_value3       := null;
            l_elements_rec.entry_value4       := null;
          elsif l_element_code = 'AA' then    -- vacation
            l_elements_rec.entry_value1       := l_holiday_tot; -- Annual quota
            l_elements_rec.entry_value2       := l_holiday_balance; 
            l_elements_rec.entry_value3       := null;
            l_elements_rec.entry_value4       := null;
          elsif l_element_code = 'BB' then    -- sickness
            l_elements_rec.entry_value1       := l_sickness_use;
            l_elements_rec.entry_value2       := l_sickness_balance;
            l_elements_rec.entry_value3       := null;
            l_elements_rec.entry_value4       := null;
          elsif l_element_code in ('15','12','1200') then -- 1200 Hourly Salary, 12 Global Salary, 15 Salary Basis
            -- Check if employee has salary basis = Hourly,
            -- if Yes then the pay_values are different.
            l_pay_basis_id   := XXHR_PERSON_ASSIGNMENT_PKG.get_salary_basis_by_emp_num
                                              (l_emp_number,g_element_start_date,0);
            l_pay_basis_name := HR_GENERAL.decode_pay_basis(l_pay_basis_id);
            if l_pay_basis_name = 'Hourly' then 
              l_elements_rec.element_code       := 1200;
              l_elements_rec.element_name       := get_element_name_by_code (1200);
              l_elements_rec.entry_value1       := l_pay_value;
              l_elements_rec.entry_value2       := l_pay_qty;
              l_elements_rec.entry_value3       := l_Hr_rate;
              l_elements_rec.entry_value4       := null; 
            else
              l_elements_rec.entry_value1       := l_pay_value;
              l_elements_rec.entry_value2       := null;
              l_elements_rec.entry_value3       := null;
              l_elements_rec.entry_value4       := null;  
            end if;
          elsif l_element_code in ('16','17') then -- 16 Overtime 125, 17 Overtime 150
            l_elements_rec.entry_value1       := l_pay_value;
            l_elements_rec.entry_value2       := l_pay_qty;
            l_elements_rec.entry_value3       := null;
            l_elements_rec.entry_value4       := null;  
          else
            l_elements_rec.entry_value1       := l_pay_value;
            l_elements_rec.entry_value2       := null;
            l_elements_rec.entry_value3       := null;
            l_elements_rec.entry_value4       := null;           
          end if;
          -- 1.1 03/02/2011 Dalit A. Raviv insert row to temp table only if have pay value for travel expence
          if l_flag = 'Y' then  
            l_err_code := 0;
            l_err_msg  := null;
            ins_into_det_interface (p_elements_rec => l_elements_rec, -- i t_elements_rec,
                                    p_err_code     => l_err_code,     -- o v
                                    p_err_desc     => l_err_msg);     -- o v 
            if l_err_code = 1 then
              fnd_file.put_line(fnd_file.log, l_err_msg);
              l_elements_log_rec             := null;
              l_elements_log_rec.batch_id    := g_batch_id;
              l_elements_log_rec.status      := 'ERROR';
              l_elements_log_rec.log_code    := 1;
              l_elements_log_rec.log_message := 'Import file was failed. 5 '||l_err_msg;
              l_err_code := 0;
              l_err_msg  := null;
              ins_into_log_interface (p_elements_log_rec => l_elements_log_rec, -- i t_elements_log_rec,
                                      p_err_code         => l_err_code,         -- o v
                                      p_err_desc         => l_err_msg);         -- o v   
            end if; -- err_code
          end if; -- l_flag
        end if;-- l_counter
      exception
        when invalid_element then
          p_err_code                     := 1;
          p_err_msg                      := l_err_msg;
          l_elements_log_rec             := null;
          l_elements_log_rec.batch_id    := g_batch_id;
          l_elements_log_rec.status      := 'ERROR';
          l_elements_log_rec.log_code    := 1;
          l_elements_log_rec.log_message := 'Import file was failed. 6 '||l_err_msg;
          l_err_code := 0;
          l_err_msg  := null;
          ins_into_log_interface (p_elements_log_rec => l_elements_log_rec, -- i t_elements_log_rec,
                                  p_err_code         => l_err_code,         -- o v
                                  p_err_desc         => l_err_msg);         -- o v   
          rollback;
          l_error_row := 'Y';
          exit;
        when others then
          p_err_code := 1;
          p_err_msg  := substr(SQLERRM,1,500);
          l_err_msg  := substr(SQLERRM,1,500);
          fnd_file.put_line(fnd_file.log, l_err_msg);
          l_elements_log_rec             := null;
          l_elements_log_rec.batch_id    := g_batch_id;
          l_elements_log_rec.status      := 'ERROR';
          l_elements_log_rec.log_code    := 1;
          l_elements_log_rec.log_message := 'Import file was failed. 7 '||l_err_msg;
          l_err_code := 0;
          l_err_msg  := null;
          ins_into_log_interface (p_elements_log_rec => l_elements_log_rec, -- i t_elements_log_rec,
                                  p_err_code         => l_err_code,         -- o v
                                  p_err_desc         => l_err_msg);         -- o v   
          rollback;
          l_error_row := 'Y';
          exit;
      end;              
    end loop;
    
    utl_file.fclose(l_file_hundler);
    commit;
    -- did not success to upload all rows
    if l_error_row = 'Y' then
      delete_det_interface (l_err_msg, l_err_code);
    end if;
    
  exception
    when others then
      p_err_code := 1;
      p_err_msg  := 'GEN EXC - upload_data - '||substr(sqlerrm,1,1000);
      fnd_file.put_line(fnd_file.log, 'GEN EXC - upload_data - '||substr(sqlerrm,1,1000));
  end upload_data;
  
  --------------------------------------------------------------------
  --  name:            process_data
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   02/01/2011 
  --------------------------------------------------------------------
  --  purpose:         Program that will process the data that just upload
  --                   to temp table
  --  In  Params:      
  --  Out Params:      errbuf     null if success , WARNING if only 15 err rows
  --                              and ERROR if more then 15 rows are in err. 
  --                   retcode    null if success , 1 if only 15 err rows
  --                              and 2 if more then 15 rows are in err.   
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  02/01/2011  Dalit A. Raviv    initial build
  --------------------------------------------------------------------  
  procedure process_data (p_emp_num  in  varchar2,
                          p_err_code out varchar2,
                          p_err_msg  out varchar2) is
  
    -- get all employees to process
    cursor get_emp_pop is
      select distinct xei.employee_number, papf.full_name, 
             hr_person_type_usage_info.get_user_person_type(trunc(sysdate), papf.person_id) person_type,
             hr_person_type_usage_info.GetSystemPersonType(papf.person_type_id) system_person_type,
             xei.effective_start_date
      from   xxhr_element_det_interface_v xei,
             per_all_people_f             papf
      where  xei.status                   <> 'SUCCESS' -- 'NEW'
      and    papf.employee_number  (+)    = xei.employee_number
      and    trunc(sysdate)               between papf.effective_start_date (+) and papf.effective_end_date (+)
      and    xei.employee_number          = nvl(p_emp_num,xei.employee_number) 
      order by to_number(employee_number);
       
    -- get all elements of person as group  
    -- i use the view to decript the data - the API need to work
    -- on decript date
    cursor get_emp_details_c (p_employee_number in varchar2) is
      select *
      from   xxhr_element_det_interface_v xei
      where  employee_number            = p_employee_number
      and    xei.status                 <> 'SUCCESS';-- 'NEW'
      --and    batch_id                   = g_batch_id;
    
    l_elements_log_rec XXHR_PAY_ELEMENTS_PKG.t_elements_log_rec;
    l_err_code          varchar2(10);  
    l_err_msg           varchar2(2500);
    l_salary_base       varchar2(5)  := 'N';
    l_termination_exist varchar2(50) := null;
    l_error_flag        varchar2(10) := 'N';
    l_exist             varchar2(10) := null;
    l_is_vp_and_up      varchar2(5)  := null;

  begin
-- what happend if last run i enter employee that this run is not exists?????

    p_err_code := 0;
    p_err_msg  := null;
    
    -- start
    for get_emp_pop_r in get_emp_pop loop
      g_assignment_id     := null;
      g_person_id         := null;
      g_salary_basis      := null;         
      g_pay_basis_id      := null;
      l_err_code          := 0;
      l_err_msg           := null;
      l_elements_log_rec  := null;
      l_error_flag        := 'N';
      l_exist             := null;
      --l_is_vp_and_up      := 'N';
      --l_termination_exist := null;
      
      -----------------------------------------------
      -- Validation Start                          --
      -----------------------------------------------
      -- populate global variables
      -----------------------------------------------
      g_person_id := XXHR_PERSON_PKG.get_person_id 
                              (get_emp_pop_r.employee_number, 
                               get_emp_pop_r.effective_start_date, 
                               g_business_group_id,
                               'EMP_NUM');
                                 
      g_assignment_id := XXHR_PERSON_ASSIGNMENT_PKG.get_primary_assignment_id
                              (g_person_id,
                               get_emp_pop_r.effective_start_date, 
                               g_business_group_id);
                               
      -----------------------------------------------
      -- Validation                                --                   
      -- check person exist in Oracle              --
      -----------------------------------------------
      if g_person_id is null then
        l_err_code := 0;
        l_err_msg  := null;
        l_elements_log_rec := null;
        fnd_file.put_line(fnd_file.log,'Employee:' || get_emp_pop_r.employee_number ||
                          ' Employee does not exist in this period.');
        l_elements_log_rec.batch_id              := g_batch_id;
        l_elements_log_rec.employee_number       := get_emp_pop_r.employee_number;
        l_elements_log_rec.effective_start_date  := get_emp_pop_r.effective_start_date;
        l_elements_log_rec.status                := 'ERROR';
        l_elements_log_rec.log_code              := 2;
        l_elements_log_rec.log_message           := 'Employee does not exist in this period.';
        ins_into_log_interface (p_elements_log_rec => l_elements_log_rec, -- i t_elements_log_rec,
                                p_err_code         => l_err_code,         -- o v
                                p_err_desc         => l_err_msg);         -- o v                         
                            
        l_error_flag := 'Y';
        upd_det_interface (get_emp_pop_r.employee_number,
                           null,
                           'ERROR', -- p_status 
                           l_err_code,
                           l_err_msg); 
        
      end if;-- person exists                         
      
      -----------------------------------------------
      -- Validation                                --
      -- Check employee Is VP and UP               --
      -----------------------------------------------
      l_is_vp_and_up := XXHR_PERSON_ASSIGNMENT_PKG.get_is_vp_and_up 
                              (p_person_id => g_person_id, -- i n
                               p_date      => get_emp_pop_r.effective_start_date ); -- i d
      
      if l_is_vp_and_up = 'Y' then
        l_err_code := 0;
        l_err_msg  := null;
        l_elements_log_rec := null;
        fnd_file.put_line(fnd_file.log,'Employee:' || get_emp_pop_r.employee_number ||
                          ' Employee grade is VP, EVP, CTO, CEO.');
        
        l_elements_log_rec.batch_id              := g_batch_id;
        l_elements_log_rec.employee_number       := get_emp_pop_r.employee_number;
        l_elements_log_rec.effective_start_date  := get_emp_pop_r.effective_start_date;
        l_elements_log_rec.status                := 'SUCCESS';
        l_elements_log_rec.log_code              := 2;
        l_elements_log_rec.log_message           := 'Employee grade is VP, EVP, CTO, CEO.';
        ins_into_log_interface (p_elements_log_rec => l_elements_log_rec, -- i t_elements_log_rec,
                                p_err_code         => l_err_code,         -- o v
                                p_err_desc         => l_err_msg);         -- o v                         
                            
        l_error_flag   := 'Y';
        l_is_vp_and_up := 'N'; 
        upd_det_interface (get_emp_pop_r.employee_number,
                           null,
                           'SUCCESS', -- p_status 
                           l_err_code,
                           l_err_msg);
                           
      end if;
      
      -----------------------------------------------
      -- Validation                                --
      -- Check employee termination                --
      -----------------------------------------------
      -- The function will check if employee is active in the 
      -- salary period, and don’t have future termination date. 
      -- In case there is future termination date the process 
      -- raises a warning message and continue the process. 
      -- In case the employee is not active -> termination date 
      -- was in the past the process will raise an error message.
      -- NONE   if no termination
      -- FUTURE if the terminate date is in the future
      -- PAST   if the terminate date allready pass
      -----------------------------------------------
      l_termination_exist := get_termination_exist(trunc(get_emp_pop_r.effective_start_date));
      if l_termination_exist = 'FUTURE' then
        l_err_code := 0;
        l_err_msg  := null;
        l_elements_log_rec := null;
        fnd_file.put_line(fnd_file.log,'Employee: ' || get_emp_pop_r.employee_number ||
                          ' Have Future Termination');
        l_elements_log_rec.batch_id              := g_batch_id;
        l_elements_log_rec.employee_number       := get_emp_pop_r.employee_number;
        l_elements_log_rec.effective_start_date  := get_emp_pop_r.effective_start_date;
        l_elements_log_rec.status                := 'WARNING';
        l_elements_log_rec.log_code              := 13;
        l_elements_log_rec.log_message           := 'Employee: ' || get_emp_pop_r.employee_number ||
                                                    ' Have Future Termination';
        ins_into_log_interface (p_elements_log_rec => l_elements_log_rec, -- i t_elements_log_rec,
                                p_err_code         => l_err_code,         -- o v
                                p_err_desc         => l_err_msg);         -- o v 
        l_termination_exist := null;                                 
      elsif l_termination_exist = 'PAST' then
        l_err_code := 0;
        l_err_msg  := null;
        l_elements_log_rec := null;
        fnd_file.put_line(fnd_file.log,'Employee: '||get_emp_pop_r.employee_number||' was terminated');
        l_elements_log_rec.batch_id              := g_batch_id;
        l_elements_log_rec.employee_number       := get_emp_pop_r.employee_number;
        l_elements_log_rec.effective_start_date  := get_emp_pop_r.effective_start_date;
        l_elements_log_rec.status                := 'ERROR';
        l_elements_log_rec.log_code              := 3;
        l_elements_log_rec.log_message           := 'Employee: '||get_emp_pop_r.employee_number||' was terminated';
        ins_into_log_interface (p_elements_log_rec => l_elements_log_rec, -- i t_elements_log_rec,
                                p_err_code         => l_err_code,         -- o v
                                p_err_desc         => l_err_msg);         -- o v  
        l_error_flag        := 'Y';
        upd_det_interface (get_emp_pop_r.employee_number,
                           null,
                           'ERROR', -- p_status 
                           l_err_code,
                           l_err_msg); 
      end if;
      
      -----------------------------------------------
      -- Validation                                --
      -- Check Salary Basic exists                 --
      -----------------------------------------------
      handle_salary_basis (p_effective_date  => get_emp_pop_r.effective_start_date, -- i d
                           p_employee_number => get_emp_pop_r.employee_number,      -- i v
                           p_err_code        => l_err_code,                         -- o v
                           p_err_msg         => l_err_msg);                         -- o v
      if l_err_code <> 0 then
        l_error_flag := 'Y';
      end if;
      -----------------------------------------------
      -- Start Upload                              --
      -- Identify emp elements that should closed  --
      -----------------------------------------------
      -- procedure delete_element will identify the needed closing elements.
      -- will compare employee last elements that are open to the elements 
      -- that are at the interface -> old minus new  will give the elements we need to close.
      -----------------------------------------------
      -- call delete elements
      --if g_second_run = 'N' then
        l_err_code := 0;
        l_err_msg  := null;
        delete_element (get_emp_pop_r.employee_number,      -- i v p_employee_number
                        get_emp_pop_r.effective_start_date, -- i d p_effective_start_date
                        --get_emp_details_r.entity_id,        -- i n p_entity_id
                        g_batch_id,                         -- i n p_batch_id
                        l_err_code,                         -- o v l_err_code
                        l_err_msg);                         -- o v l_err_msg
      --end if;
      
      if l_error_flag = 'N' then                
        for get_emp_details_r in get_emp_details_c (get_emp_pop_r.employee_number) loop
          -----------------------------------------------
          -- Upload                                    --
          -- Identify Update Create mode
          -----------------------------------------------
          -- For every element the process check if it is exist  
          -- in the effective date for the current employee, 
          -- In case the element exist the process use update 
          -- mode API otherwise it will use Insert mode.
          -----------------------------------------------
          l_exist := get_emp_ele_exist_for_period (get_emp_details_r.element_name,         -- i v p_element_name 
                                                   get_emp_details_r.effective_start_date); -- i d p_effective_date 
        
          if l_exist = 'Y' then  
          
            l_err_code := 0;
            l_err_msg  := null;
            l_elements_log_rec := null;
            fnd_file.put_line(fnd_file.log,'Employee ' || get_emp_pop_r.employee_number ||
                              ' Element '||get_emp_details_r.element_name||
                              ' Exist in this date '||to_char(get_emp_details_r.effective_start_date));
            l_elements_log_rec.batch_id              := get_emp_details_r.batch_id;
            l_elements_log_rec.entity_id             := get_emp_details_r.entity_id;
            l_elements_log_rec.employee_number       := get_emp_details_r.employee_number;
            l_elements_log_rec.effective_start_date  := get_emp_details_r.effective_start_date;
            l_elements_log_rec.effective_end_date    := get_emp_details_r.effective_end_date;
            l_elements_log_rec.element_code          := get_emp_details_r.element_code;
            l_elements_log_rec.status                := 'ERROR';
            l_elements_log_rec.log_code              := 6;
            l_elements_log_rec.log_message           := 'Employee '||get_emp_pop_r.employee_number ||
                                                        ' Element '||get_emp_details_r.element_name||
                                                        ' Exist in this date '||to_char(get_emp_details_r.effective_start_date);
            ins_into_log_interface (p_elements_log_rec => l_elements_log_rec, -- i t_elements_log_rec,
                                    p_err_code         => l_err_code,         -- o v
                                    p_err_desc         => l_err_msg);         -- o v      
            l_error_flag := 'Y';
            upd_det_interface (null,
                               get_emp_details_r.entity_id,
                               'ERROR', -- p_status 
                               l_err_code,
                               l_err_msg); 
          else
            
            l_exist := get_element_name_is_valid (get_emp_details_r.element_name);
            if l_exist = 'N' then
              l_err_code := 0;
              l_err_msg  := null;
              l_elements_log_rec := null;
              fnd_file.put_line(fnd_file.log,'Employee ' || get_emp_pop_r.employee_number ||
                                ' Element Name '||nvl(get_emp_details_r.element_name,'NULL')||
                                ' Not Valid ');
              l_elements_log_rec.batch_id              := get_emp_details_r.batch_id;
              l_elements_log_rec.entity_id             := get_emp_details_r.entity_id;
              l_elements_log_rec.employee_number       := get_emp_details_r.employee_number;
              l_elements_log_rec.effective_start_date  := get_emp_details_r.effective_start_date;
              l_elements_log_rec.effective_end_date    := get_emp_details_r.effective_end_date;
              l_elements_log_rec.element_code          := get_emp_details_r.element_code;
              l_elements_log_rec.status                := 'ERROR';
              l_elements_log_rec.log_code              := 6;
              l_elements_log_rec.log_message           := 'Employee '||get_emp_pop_r.employee_number ||
                                                          ' Element Name '||nvl(get_emp_details_r.element_name,'NULL')||
                                                          ' Not Valid ';
              ins_into_log_interface (p_elements_log_rec => l_elements_log_rec, -- i t_elements_log_rec,
                                      p_err_code         => l_err_code,         -- o v
                                      p_err_desc         => l_err_msg);         -- o v      
              l_error_flag := 'Y';
              upd_det_interface (null,
                                 get_emp_details_r.entity_id,
                                 'ERROR', -- p_status 
                                 l_err_code,
                                 l_err_msg); 
            else
              if get_emp_details_r.entry_value1 is not null or 
                 get_emp_details_r.entry_value2 is not null or 
                 get_emp_details_r.entry_value3 is not null or 
                 get_emp_details_r.entry_value4 is not null or 
                 get_emp_details_r.entry_value5 is not null or 
                 get_emp_details_r.entry_value6 is not null  then
                -------------------TO ENTER IF DECRYPT VALUE<> ENCRYPT VALUE
                ------------------- IF YES ACTIVATE API IF NO ENTER MESSAGE.
                -- check if the Encript/Decrypt works if the value are the same it did not open
                -- the Decrypt values, else Decrypt worked good
                if get_emp_details_r.entry_value1 <> get_emp_details_r.encrypt_entry_value1 or
                   get_emp_details_r.entry_value2 <> get_emp_details_r.encrypt_entry_value2  then
                  if get_ele_upd_mode (get_emp_details_r.element_name,
                                       get_emp_details_r.effective_start_date) = 'UPDATE' then
                    update_element (p_employee_number => get_emp_pop_r.employee_number,  -- i v
                                    p_element_name    => get_emp_details_r.element_name, -- i v
                                    p_effective_date  => get_emp_details_r.effective_start_date, -- i d
                                    p_entity_id       => get_emp_details_r.entity_id,            -- i n
                                    p_batch_id        => get_emp_details_r.batch_id,             -- i n
                                    p_value1          => get_emp_details_r.entry_value1,         -- i n
                                    p_value2          => get_emp_details_r.entry_value2,         -- i n default null,
                                    p_value3          => get_emp_details_r.entry_value3,         -- i n default null,
                                    p_value4          => get_emp_details_r.entry_value4,         -- i v default null,
                                    p_value5          => get_emp_details_r.entry_value5,         -- i v default null,
                                    p_value6          => get_emp_details_r.entry_value6,         -- i d default null,
                                    p_err_code        => l_err_code, -- o v
                                    p_err_msg         => l_err_msg); -- o v  
                  else 
                    -- call create element  procedure
                    create_element (p_employee_number => get_emp_pop_r.employee_number,  -- i v
                                    p_element_name    => get_emp_details_r.element_name, -- i v
                                    p_effective_date  => get_emp_details_r.effective_start_date, -- i d
                                    p_entity_id       => get_emp_details_r.entity_id,            -- i n
                                    p_batch_id        => get_emp_details_r.batch_id,             -- i n
                                    p_value1          => get_emp_details_r.entry_value1,         -- i n
                                    p_value2          => get_emp_details_r.entry_value2,         -- i n default null,
                                    p_value3          => get_emp_details_r.entry_value3,         -- i n default null,
                                    p_value4          => get_emp_details_r.entry_value4,         -- i v default null,
                                    p_value5          => get_emp_details_r.entry_value5,         -- i v default null,
                                    p_value6          => get_emp_details_r.entry_value6,         -- i d default null,
                                    p_err_code        => l_err_code, -- o v
                                    p_err_msg         => l_err_msg); -- o v
                  end if;-- upd or ins
                else
                  -- Handle Encrypt/Decrypt error
                  l_err_code := 0;
                  l_err_msg  := null;
                  l_elements_log_rec := null;
                  fnd_file.put_line(fnd_file.log,'Employee ' || get_emp_pop_r.employee_number ||
                                    ' Element Name '||nvl(get_emp_details_r.element_name,'NULL')||
                                    ' Could not decrypt values ');
                  l_elements_log_rec.batch_id              := get_emp_details_r.batch_id;
                  l_elements_log_rec.entity_id             := get_emp_details_r.entity_id;
                  l_elements_log_rec.employee_number       := get_emp_details_r.employee_number;
                  l_elements_log_rec.effective_start_date  := get_emp_details_r.effective_start_date;
                  l_elements_log_rec.effective_end_date    := get_emp_details_r.effective_end_date;
                  l_elements_log_rec.element_code          := get_emp_details_r.element_code;
                  l_elements_log_rec.status                := 'ERROR';
                  l_elements_log_rec.log_code              := 17;
                  l_elements_log_rec.log_message           := 'Employee '||get_emp_pop_r.employee_number ||
                                                              ' Element Name '||nvl(get_emp_details_r.element_name,'NULL')||
                                                              ' Could not decrypt values ';
                  ins_into_log_interface (p_elements_log_rec => l_elements_log_rec, -- i t_elements_log_rec,
                                          p_err_code         => l_err_code,         -- o v
                                          p_err_desc         => l_err_msg);         -- o v      
                  l_error_flag := 'Y';
                  upd_det_interface (null,
                                     get_emp_details_r.entity_id,
                                     'ERROR', -- p_status 
                                     l_err_code,
                                     l_err_msg); 
                end if; -- encript
              else
              
                l_elements_log_rec.batch_id              := get_emp_details_r.batch_id;
                l_elements_log_rec.entity_id             := get_emp_details_r.entity_id;
                l_elements_log_rec.employee_number       := get_emp_details_r.employee_number;
                l_elements_log_rec.effective_start_date  := get_emp_details_r.effective_start_date;
                l_elements_log_rec.effective_end_date    := get_emp_details_r.effective_end_date;
                l_elements_log_rec.element_code          := get_emp_details_r.element_code;
                l_elements_log_rec.status                := 'WARNING';
                l_elements_log_rec.log_code              := 15;
                l_elements_log_rec.log_message           := 'All Values for the Element are null';
                ins_into_log_interface (p_elements_log_rec => l_elements_log_rec, -- i t_elements_log_rec,
                                        p_err_code         => l_err_code,         -- o v
                                        p_err_desc         => l_err_msg);         -- o v  
              
                upd_det_interface (null,
                                   get_emp_details_r.entity_id,
                                   'WARNING', -- p_status 
                                   l_err_code,
                                   l_err_msg);
              end if;-- all values are null
            end if;-- ele is valid
          end if; -- ele_exist_for_period
        end loop;-- all ele fro emp
      end if; -- l_error_flag
      
      l_salary_base       := null;
      l_termination_exist := null;
    end loop;-- employee number
    
  exception
    when others then
      rollback;
      p_err_code := 1;
      p_err_msg  := 'GEN EXC - process_data - '||substr(sqlerrm,1,500);
      l_err_code := 0;
      l_err_msg  := null;
      l_elements_log_rec := null;
      fnd_file.put_line(fnd_file.log,'GEN EXC - process_data - '||substr(sqlerrm,1,500));
      l_elements_log_rec.batch_id              := g_batch_id;
      l_elements_log_rec.status                := 'ERROR';
      l_elements_log_rec.log_code              := 14;
      l_elements_log_rec.log_message           := 'GEN EXC - process_data - '||substr(sqlerrm,1,500);
      ins_into_log_interface (p_elements_log_rec => l_elements_log_rec, -- i t_elements_log_rec,
                              p_err_code         => l_err_code,         -- o v
                              p_err_desc         => l_err_msg);         -- o v  
      upd_det_interface (null,
                         null,
                         'ERROR', -- p_status 
                         l_err_code,
                         l_err_msg); 
  end process_data;                          
  
  --------------------------------------------------------------------
  --  name:            delete_element
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   03/01/2011 
  --------------------------------------------------------------------
  --  purpose:         this procedure look for the elements that need to be closed.
  --                   person had 2 elements XX, YY and this upload only one need to 
  --                   be upload, for example XX. the procedure will expose the element 
  --                   YY and close it. old population minus new population will give 
  --                   the elements pop that need to be close.
  --                   closing element use delete element API.
  --  In  Params:      p_employee_number
  --                   p_emp_assignment_id
  --  Out Params:      errbuf     null if success , error string if error
  --                   retcode    null if success , 1 error.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  03/01/2011  Dalit A. Raviv    initial build
  -------------------------------------------------------------------- 
  procedure delete_element (p_employee_number      in  varchar2,
                            p_effective_start_date in  date,
                            --p_entity_id            in  number,
                            p_batch_id             in  number,
                            p_err_code             out varchar2,
                            p_err_msg              out varchar2) is
  
    cursor get_delete_ele_pop_c is
      
      -- get person today elements at oracle - OLD
      select distinct
             type.element_name
      from   pay_element_types_f        type,
             pay_element_links_f        link,
             pay_element_entry_values_f value,
             pay_element_entries_f      entry,
             per_all_assignments_f      paaf
      where  type.element_type_id       = link.element_type_id
      and    entry.element_link_id      = link.element_link_id
      and    entry.entry_type           in ('A', 'R', 'E')
      and    value.element_entry_id     = entry.element_entry_id
      and    value.effective_start_date = entry.effective_start_date
      and    value.effective_end_date   = entry.effective_end_date
      and    entry.assignment_id        = paaf.assignment_id --p_emp_assignment_id --881
      and    p_effective_start_date -1  between entry.effective_start_date and entry.effective_end_date
      -- this condition is wrong because there is a vlaue of 31/12/4712 at the field
      -- and    entry.effective_end_date   is null
      -- and    entry.effective_end_date  > p_effective_start_date -1
      --
      and    paaf.assignment_id         = g_assignment_id
      and    p_effective_start_date -1  between paaf.effective_start_date and paaf.effective_end_date
      and    nvl(type.attribute1,'N')   = 'N'
      and    type.attribute2            is not null
      -- elements that in att1 (open indication) have Y we do not close .
      -- the reson is this element is a recuring element like bonus and it come only once in a year
      -- but we steel what that when users look at the screen they will be able to see the element value
      -- if we close it they will not see the element value for this period - only at element history screen
      minus
      -- get person new elements to upload to oracle - NEW
      select type.element_name
      from   xxhr_element_det_interface xei,
             pay_element_types_f        type
      where  xei.employee_number        = p_employee_number -- 258 -- 
      --and    xei.status                 <> 'SUCCESS'        -- 'NEW' 
      and    type.attribute2            = xei.element_code
      and    nvl(type.attribute1,'N')   = 'N';
  
    l_element_entry_id number;
    l_ovn              number;
    l_elements_log_rec XXHR_PAY_ELEMENTS_PKG.t_elements_log_rec;
    l_err_code         varchar2(10);  
    l_err_msg          varchar2(2500);
    l_e_start_date     date;
    l_e_end_date       date;
    l_delete_warning   boolean;
  
  begin
    p_err_code := 0;
    p_err_msg  := null;
    -- for each element found need to close the element
    for get_delete_ele_pop_r in get_delete_ele_pop_c loop
      -- Get old element details
      begin
        l_element_entry_id := null;
        l_ovn              := null;
        -- get element details
        select entry.element_entry_id,
               entry.object_version_number
        into   l_element_entry_id,
               l_ovn
        from   pay_element_types_f        type,
               pay_element_links_f        link,
               pay_element_entries_f      entry
        where  type.element_type_id       = link.element_type_id
        and    entry.element_link_id      = link.element_link_id
        and    entry.entry_type           in ('A', 'R', 'E')
        and    entry.assignment_id        = g_assignment_id --  881
        and    type.element_name          = get_delete_ele_pop_r.element_name --p_element_name --'Basic Salary'
        and    p_effective_start_date     between entry.effective_start_date and entry.effective_end_date; -- ?????????????????
      exception
        when others then
          l_err_code := 0;
          l_err_msg  := null;
          l_elements_log_rec := null;
          fnd_file.put_line(fnd_file.log,'Employee: ' || p_employee_number ||
                            ' Element name: '||get_delete_ele_pop_r.element_name||
                            ' Date: '||to_char(p_effective_start_date -1,'DD/MM/YYYY')||' Can not find details');
          l_elements_log_rec.batch_id              := p_batch_id;
          --l_elements_log_rec.entity_id             := p_entity_id;
          l_elements_log_rec.employee_number       := p_employee_number;
          l_elements_log_rec.effective_start_date  := p_effective_start_date;
          l_elements_log_rec.status                := 'ERROR';
          l_elements_log_rec.log_code              := 12;
          l_elements_log_rec.log_message           := 'Employee: ' || p_employee_number ||
                                                      ' Element: '||get_delete_ele_pop_r.element_name||
                                                      ' Date: '||to_char(p_effective_start_date -1,'DD/MM/YYYY')||
                                                      ' Can not find details';
          ins_into_log_interface (p_elements_log_rec => l_elements_log_rec, -- i t_elements_log_rec,
                                  p_err_code         => l_err_code,         -- o v
                                  p_err_desc         => l_err_msg);         -- o v      
      end; -- Get old element details
      -- API Start
      begin  
        if l_element_entry_id is not null then        
          pay_element_entry_api.delete_element_entry(p_datetrack_delete_mode => 'DELETE',
                                                     p_effective_date        => p_effective_start_date - 1,
                                                     p_element_entry_id      => l_element_entry_id,
                                                     p_object_version_number => l_ovn,
                                                     p_effective_start_date  => l_e_start_date, -- o
                                                     p_effective_end_date    => l_e_end_date,-- o
                                                     p_delete_warning        => l_delete_warning);-- o
        
        
          commit;
        end if;
      -- handle Api return with error
      exception
        when others then
          rollback;
          l_err_code := 0;
          l_err_msg  := null;
          l_elements_log_rec := null;
          fnd_file.put_line(fnd_file.log,'Employee: ' || p_employee_number ||
                            ' Element name: '||get_delete_ele_pop_r.element_name||
                            ' Date: '||to_char(p_effective_start_date,'DD/MM/YYYY')||
                            ' Delete Element Api finished with error'||
                            ' ERR - '||sqlerrm);
          l_elements_log_rec.batch_id              := p_batch_id;
          --l_elements_log_rec.entity_id             := p_entity_id;
          l_elements_log_rec.employee_number       := p_employee_number;
          l_elements_log_rec.effective_start_date  := p_effective_start_date;
          l_elements_log_rec.status                := 'ERROR';
          l_elements_log_rec.log_code              := 11;
          l_elements_log_rec.log_message           := 'Employee: ' || p_employee_number ||
                                                      ' Element: '||get_delete_ele_pop_r.element_name||
                                                      ' Date: '||to_char(p_effective_start_date,'DD/MM/YYYY')||
                                                      ' Delete Element Api finished with error'||
                                                      ' API Err '||substr(sqlerrm,1,500);
          ins_into_log_interface (p_elements_log_rec => l_elements_log_rec, -- i t_elements_log_rec,
                                  p_err_code         => l_err_code,         -- o v
                                  p_err_desc         => l_err_msg);         -- o v     
          
        
      end;
    end loop;
  exception
    when others then
      p_err_code := 1;
      p_err_msg  := 'GEN EXC - delete_element - '||substr(sqlerrm,1,1000);
      l_err_code := 0;
      l_err_msg  := null;
      l_elements_log_rec := null;
      fnd_file.put_line(fnd_file.log,'GEN EXC - delete_element - '||substr(sqlerrm,1,500));
      l_elements_log_rec.batch_id              := p_batch_id;
      --l_elements_log_rec.entity_id             := p_entity_id;
      l_elements_log_rec.employee_number       := p_employee_number;
      l_elements_log_rec.effective_start_date  := p_effective_start_date;
      l_elements_log_rec.status                := 'ERROR';
      l_elements_log_rec.log_code              := 12;
      l_elements_log_rec.log_message           := 'GEN EXC - delete_element - '||substr(sqlerrm,1,500);
      ins_into_log_interface (p_elements_log_rec => l_elements_log_rec, -- i t_elements_log_rec,
                              p_err_code         => l_err_code,         -- o v
                              p_err_desc         => l_err_msg);         -- o v   
  end delete_element;                            
  
  --------------------------------------------------------------------
  --  name:            create_element
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   03/01/2011 
  --------------------------------------------------------------------
  --  purpose:         this procedure create_element .
  --                   
  --  In  Params:      p_employee_number
  --                   p_element_name
  --                   p_effective_date
  --                   p_entity_id
  --                   p_batch_id
  --                   p_value1, p_value2, p_value3, _value4, p_value5, p_value6
  --  Out Params:      errbuf     null if success , error string if error
  --                   retcode    null if success , 1 error.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  03/01/2011  Dalit A. Raviv    initial build
  -------------------------------------------------------------------- 
  procedure create_element (p_employee_number  in  varchar2,
                            p_element_name     in  varchar2,
                            p_effective_date   in  date,
                            p_entity_id        in  number,
                            p_batch_id         in  number,
                            p_value1           in  number,
                            p_value2           in  number   default null,
                            p_value3           in  number   default null,
                            p_value4           in  varchar2 default null,
                            p_value5           in  varchar2 default null,
                            p_value6           in  varchar2 default null,
                            p_err_code         out varchar2,
                            p_err_msg          out varchar2) IS
                           
    cursor element_values_c(p_element_type_id  pay_element_types.element_type_id%type) is
      select input.display_sequence, input.input_value_id
      from   pay_input_values_f     input
      where  input.element_type_id  = p_element_type_id
      and    p_effective_date       between input.effective_start_date 
                                    and     input.effective_end_date
      order by input.display_sequence;
    
    l_effective_start_date  date;
    l_effective_end_date    date;
    l_object_version_number number;
    l_element_entry_id      number;
    l_create_warning        boolean;
    l_elements_log_rec      XXHR_PAY_ELEMENTS_PKG.t_elements_log_rec;
    l_err_code              varchar2(10);  
    l_err_msg               varchar2(2500);
    l_element_type_id       number := null;
    l_element_link_id       number := null;
    type input_val_id_t     is table of number index by binary_integer;
    l_input_vid_t           input_val_id_t;
  
  begin
  
    p_err_code := 0;
    p_err_msg  := null;
    -- Get element type id 
    l_element_type_id := get_element_type_id(p_element_name, p_effective_date); 
    -- Get element link id
    l_element_link_id := get_element_link_id(g_assignment_id,
                                             l_element_type_id,
                                             p_effective_date);
    -- Get input_value_id
    l_input_vid_t(1):='';
    l_input_vid_t(2):='';
    l_input_vid_t(3):='';
    l_input_vid_t(4):='';
    l_input_vid_t(5):='';
    l_input_vid_t(6):='';
    for element_values_r in element_values_c(l_element_type_id) loop
      l_input_vid_t(element_values_c%rowcount):= element_values_r.input_value_id;
    end loop;
    
  -- p_value1
    -- Insert new element
    l_effective_start_date := p_effective_date;
    l_effective_end_date   := null;
    
    --fnd_global.APPS_INITIALIZE(user_id => 2470,resp_id => 21538,resp_appl_id => 800);
    pay_element_entry_api.create_element_entry(p_effective_date        => p_effective_date,
                                               p_business_group_id     => g_business_group_id, --0
                                               p_assignment_id         => g_assignment_id,     -- 881,
                                               p_element_link_id       => l_element_link_id,   -- Travel Expense 84, -- Car Maintenance 83
                                               p_entry_type            => 'E',
                                               p_input_value_id1       => l_input_vid_t(1),    -- 148715, --148716,
                                               p_entry_value1          => p_value1,
                                               p_input_value_id2       => l_input_vid_t(2),    
                                               p_entry_value2          => p_value2,
                                               p_input_value_id3       => l_input_vid_t(3),    
                                               p_entry_value3          => p_value3,
                                               p_input_value_id4       => l_input_vid_t(4),    
                                               p_entry_value4          => p_value4,
                                               p_input_value_id5       => l_input_vid_t(5),    
                                               p_entry_value5          => p_value5,
                                               p_input_value_id6       => l_input_vid_t(6),    
                                               p_entry_value6          => p_value6,
                                               p_effective_start_date  => l_effective_start_date,
                                               p_effective_end_date    => l_effective_end_date,
                                               p_element_entry_id      => l_element_entry_id,
                                               p_object_version_number => l_object_version_number,
                                               p_create_warning        => l_create_warning);
    commit;
    
    upd_det_interface (null,
                       p_entity_id,
                       'SUCCESS', -- p_status 
                       l_err_code,
                       l_err_msg);
  exception
    when others then
      rollback;
      p_err_code := 1;
      p_err_msg  := 'GEN EXC - create_element - '||substr(sqlerrm,1,500);
      l_err_code := 0;
      l_err_msg  := null;
      l_elements_log_rec := null;
      fnd_file.put_line(fnd_file.log,'API - create_element failed. Emp - '||p_employee_number||
                                     'Element - '||p_element_name||' ERR - '||substr(sqlerrm,1,500));
      l_elements_log_rec.batch_id              := p_batch_id;
      l_elements_log_rec.entity_id             := p_entity_id;
      l_elements_log_rec.employee_number       := p_employee_number;
      l_elements_log_rec.effective_start_date  := p_effective_date;
      l_elements_log_rec.status                := 'ERROR';
      l_elements_log_rec.log_code              := 14;
      l_elements_log_rec.log_message           := 'API - create_element failed - '||
                                                  p_element_name||' ERR - '||substr(sqlerrm,1,500);
      ins_into_log_interface (p_elements_log_rec => l_elements_log_rec, -- i t_elements_log_rec,
                              p_err_code         => l_err_code,         -- o v
                              p_err_desc         => l_err_msg);         -- o v  
      upd_det_interface (null,
                         p_entity_id,
                         'ERROR', -- p_status 
                         l_err_code,
                         l_err_msg); 
  end create_element;
  
  --------------------------------------------------------------------
  --  name:            update_element
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   03/01/2011 
  --------------------------------------------------------------------
  --  purpose:         this procedure update_element .
  --                   
  --  In  Params:      p_employee_number
  --                   p_element_name
  --                   p_effective_date
  --                   p_entity_id
  --                   p_batch_id
  --                   p_value1, p_value2, p_value3, _value4, p_value5, p_value6
  --  Out Params:      errbuf     null if success , error string if error
  --                   retcode    null if success , 1 error.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  03/01/2011  Dalit A. Raviv    initial build
  -------------------------------------------------------------------- 
  procedure update_element (p_employee_number  in  varchar2,
                            p_element_name     in  varchar2,
                            p_effective_date   in  date,
                            p_entity_id        in  number,
                            p_batch_id         in  number,
                            p_value1           in  number,
                            p_value2           in  number   default null,
                            p_value3           in  number   default null,
                            p_value4           in  varchar2 default null,
                            p_value5           in  varchar2 default null,
                            p_value6           in  varchar2 default null,
                            p_err_code         out varchar2,
                            p_err_msg          out varchar2) IS
                           
    cursor element_values_c(p_element_type_id  pay_element_types.element_type_id%type) is
      select input.display_sequence, input.input_value_id
      from   pay_input_values_f     input
      where  input.element_type_id  = p_element_type_id
      and    p_effective_date       between input.effective_start_date 
                                    and     input.effective_end_date
      order by input.display_sequence;
    
    l_effective_start_date  date;
    l_effective_end_date    date;
    l_element_entry_id      number;
    l_elements_log_rec      XXHR_PAY_ELEMENTS_PKG.t_elements_log_rec;
    l_err_code              varchar2(10);  
    l_err_msg               varchar2(2500);
    l_element_type_id       number := null;
    --l_element_link_id       number := null;
    type input_val_id_t     is table of number index by binary_integer;
    l_input_vid_t           input_val_id_t;
    l_start_date            date;
    l_obj                   number := 0;
    l_update_warning        BOOLEAN;                 
  begin
  
    p_err_code := 0;
    p_err_msg  := null;
    -- Get element entry id and object version number
    get_element_entry_id(p_element_name,     -- p_element_name     
                         g_assignment_id,    -- p_assignment_id    
                         p_effective_date,   -- p_effective_date  
                         l_obj,              -- p_obj_ver_no       OUT 
                         l_start_date,       -- p_start_date       OUT
                         l_element_entry_id);-- p_element_entry_id OUT 
    -- Get element type id 
    l_element_type_id := get_element_type_id(p_element_name, p_effective_date); 
    -- Get element link id
    --l_element_link_id := get_element_link_id(g_assignment_id,
    --                                         l_element_type_id,
    --                                         p_effective_date);
    -- Get input_value_id
    l_input_vid_t(1):='';
    l_input_vid_t(2):='';
    l_input_vid_t(3):='';
    l_input_vid_t(4):='';
    l_input_vid_t(5):='';
    l_input_vid_t(6):='';
    for element_values_r in element_values_c(l_element_type_id) loop
      l_input_vid_t(element_values_c%rowcount):= element_values_r.input_value_id;
    end loop;
    
  -- p_value1
    -- Insert new element
    l_effective_start_date := p_effective_date;
    l_effective_end_date   := null;
    
    -- param p_datetrack_update_mode Indicates which DateTrack mode to use when
    -- updating the record. You must set to either UPDATE, CORRECTION,
    -- UPDATE_OVERRIDE or UPDATE_CHANGE_INSERT. Modes available for use with a
    -- particular record depend on the dates of previous record changes and the
    -- effective date of this change.
    
    --fnd_global.APPS_INITIALIZE(user_id => 2470,resp_id => 50817,resp_appl_id => 800);
    pay_element_entry_api.update_element_entry(p_datetrack_update_mode => 'UPDATE',            
                                               p_effective_date        => p_effective_date,
                                               p_business_group_id     => g_business_group_id, -- 0
                                               p_element_entry_id      => l_element_entry_id,
                                               p_object_version_number => l_obj, 
                                               p_input_value_id1       => l_input_vid_t(1),    
                                               p_entry_value1          => p_value1,
                                               p_input_value_id2       => l_input_vid_t(2),    
                                               p_entry_value2          => p_value2,
                                               p_input_value_id3       => l_input_vid_t(3),    
                                               p_entry_value3          => p_value3,
                                               p_input_value_id4       => l_input_vid_t(4),    
                                               p_entry_value4          => p_value4,
                                               p_input_value_id5       => l_input_vid_t(5),    
                                               p_entry_value5          => p_value5,
                                               p_input_value_id6       => l_input_vid_t(6),    
                                               p_entry_value6          => p_value6,
                                               p_effective_start_date => l_effective_start_date,
                                               p_effective_end_date   => l_effective_end_date,
                                               p_update_warning       => l_update_warning);
    commit;
    
    upd_det_interface (null,
                       p_entity_id,
                       'SUCCESS', -- p_status 
                       l_err_code,
                       l_err_msg);
  exception
    when others then
      rollback;
      -- !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!     IMPORTANT     !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
      -- there is a case that the api will FAIL because there is a future date for the element 
      -- and i try to update instaed of UPDATE_CHANGE_INSERT.
      -- in this case we decided to handle it manual at the Oracle
      -- 
      -- this is the API error i will enter shorter message to the log table.
      -- API - update_element failed - Global Salary ERR - ORA-20001: You cannot perform a DateTrack update where rows exist in the future
      -- Cause:  The DateTrack update operation cannot be performed where rows exist in the future.  
      -- Action: Consider performing a Datetrack Change Insert or Override operation.
      p_err_code := 1;
      p_err_msg  := 'GEN EXC - update_element - '||substr(sqlerrm,1,500);
      l_err_code := 0;
      l_err_msg  := substr(sqlerrm,1,500);
      l_err_msg  := substr(l_err_msg,1,instr(chr(10),l_err_msg));
      l_elements_log_rec := null;
      fnd_file.put_line(fnd_file.log,'API - update_element failed. Emp -'||p_employee_number||
                                     ' Element - '||p_element_name||' ERR - '||substr(sqlerrm,1,500));
      l_elements_log_rec.batch_id              := p_batch_id;
      l_elements_log_rec.entity_id             := p_entity_id;
      l_elements_log_rec.employee_number       := p_employee_number;
      l_elements_log_rec.effective_start_date  := p_effective_date;
      l_elements_log_rec.status                := 'ERROR';
      l_elements_log_rec.log_code              := 14;
      l_elements_log_rec.log_message           := 'API - update_element failed - '||
                                                  p_element_name||' ERR - '||l_err_msg/*substr(sqlerrm,1,500)*/;
      ins_into_log_interface (p_elements_log_rec => l_elements_log_rec, -- i t_elements_log_rec,
                              p_err_code         => l_err_code,         -- o v
                              p_err_desc         => l_err_msg);         -- o v  
      upd_det_interface (null,
                         p_entity_id,
                         'ERROR', -- p_status 
                         l_err_code,
                         l_err_msg); 
  end update_element;

  --------------------------------------------------------------------
  --  name:            load_elements_data
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   27/12/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose:         Program that will read CSV file and load the data 
  --                   From Har-Gal to Oracle.
  --  In  Params:      p_location - the location where to get the file to load from
  --                   p_filename - filename
  --                   p_token    - for the security 
  --                   p_token2   - for the security
  --                   p_debug    - Y / N 
  --  Out Params:      errbuf     null if success , WARNING if only 15 err rows
  --                              and ERROR if more then 15 rows are in err. 
  --                   retcode    null if success , 1 if only 15 err rows
  --                              and 2 if more then 15 rows are in err.   
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  27/12/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------                              
  PROCEDURE load_elements_data (errbuf             out varchar2,
                                retcode            out varchar2,
                                p_location         in  varchar2, --/UtlFiles/HR/BENEFITS
                                p_filename         in  varchar2,
                                p_token1           in  varchar2,
                                --p_token2           in  varchar2,
                                p_debug            in  varchar2 default 'N',
                                p_employee_number  in  varchar2) is 
                                
    l_security         varchar2(10)   := null;
    l_exist            varchar2(10)   := 'N';
    l_err_code         varchar2(10)   := null;
    l_err_msg          varchar2(1500) := null;
    l_elements_log_rec XXHR_PAY_ELEMENTS_PKG.t_elements_log_rec;
    l_num_err_rows     number         := null;
    l_count            number         := null;
    l_to_user_name     varchar2(150)  := null;
    l_cc               varchar2(150)  := null;
    l_bcc              varchar2(150)  := null;
    l_subject          varchar2(360)  := null;
    l_att1_proc        varchar2(150)  := null;
    l_att2_proc        varchar2(150)  := null;
    l_att3_proc        varchar2(150)  := null;
    l_error_code       number         := 0;
    l_err_message      varchar2(500)  := null;
    
    general_exception exception;
                                
  begin
    -- init globals
    --fnd_global.APPS_INITIALIZE(user_id => 2470,resp_id => 21538 ,resp_appl_id => 800);

    g_login_id   := fnd_profile.VALUE('LOGIN_ID');
    g_user_id    := fnd_profile.VALUE('USER_ID');
    g_user_name  := fnd_profile.VALUE('USER_NAME');
    g_batch_date := sysdate;
    g_second_run := 'N';
    
    -- Set batch id --
    -- if first time run - debug = N then get the id from seq
    -- else it is second time - debug = Y then get the max id from the det interface table.
    /*
    if p_debug = 'Y' then
      select max(batch_id)
      into   g_batch_id  
      from   xxhr_element_det_interface;
    else
      select XXHR_ELEMENT_DET_INTER_BATCH.Nextval
      into   g_batch_id 
      from   dual;
    end if;
    */
    select nvl(max(batch_id),0)
    into   g_batch_id  
    from   xxhr_element_det_interface;
    
    if g_batch_id = 0 then 
      select XXHR_ELEMENT_DET_INTER_BATCH.Nextval
      into   g_batch_id 
      from   dual;
    else
      g_second_run := 'Y';
    end if;
      
    xxobjt_sec.upload_user_session_key(p_pass        => p_token1, --'D1234567',
                                       p_err_code    => l_err_code ,
                                       p_err_message => l_err_message);
      
    if l_err_code = 1 then
      l_security := 'N';
    else
      l_security := 'Y';
    end if;
       
    if l_security = 'N' then
      fnd_file.put_line(fnd_file.log, 'You are not permitted to run this program');
      l_err_code                     := 0;
      l_err_msg                      := null;
      l_elements_log_rec             := null;
      l_elements_log_rec.batch_id    := g_batch_id;
      l_elements_log_rec.status      := 'ERROR';
      l_elements_log_rec.log_code    := 9;
      l_elements_log_rec.log_message := 'You are not permitted to run this program ' || ltrim(p_filename)||
                                        ' User - '||g_user_name;
      ins_into_log_interface (p_elements_log_rec => l_elements_log_rec, -- i t_elements_log_rec,
                              p_err_code         => l_err_code,         -- o v
                              p_err_desc         => l_err_msg);         -- o v 
      
      fnd_file.put_line(fnd_file.log,'You are not permitted to run this program');
      errbuf  := 'You are not permitted to run this program';
      retcode := 2;
      raise general_exception;
    end if;
  
    -- 2) check table is empty
    l_exist := check_temp_table;
    
    if nvl(p_debug,'N') = 'Y' then
      l_exist := 'Y';
    end if;
    
    if l_exist = 'Y' then
      fnd_file.put_line(fnd_file.log, 'There are rows at xxhr_element_det_interface Table');
      l_err_code                     := 0;
      l_err_msg                      := null;
      l_elements_log_rec             := null;
      l_elements_log_rec.batch_id    := g_batch_id;
      l_elements_log_rec.status      := 'ERROR';
      l_elements_log_rec.log_code    := 10;
      l_elements_log_rec.log_message := 'There are rows at xxhr_element_det_interface Table';
      ins_into_log_interface (p_elements_log_rec => l_elements_log_rec, -- i t_elements_log_rec,
                              p_err_code         => l_err_code,         -- o v
                              p_err_desc         => l_err_msg);         -- o v 
      
      fnd_file.put_line(fnd_file.log,'There are rows at xxhr_element_det_interface Table');
      errbuf  := 'There are rows at xxhr_element_det_interface Table';
      retcode := 2;
      
    else
      -- 3) load excel file
      fnd_file.put_line(fnd_file.log,'g_batch_id - '||g_batch_id);
        
      l_err_code := 0;
      l_err_msg  := null;
      upload_data (p_location => p_location, -- i v
                   p_filename => p_filename, -- i v 
                   p_err_code => l_err_code, -- o v
                   p_err_msg  => l_err_msg); -- o v
                     
      if l_err_code <> 0 then
        fnd_file.put_line(fnd_file.log,'Upload_data Failed - '||substr(l_err_msg,1,500));
        errbuf  := 'Upload_data Failed - '||substr(l_err_msg,1,500);
        retcode := 2;
        raise general_exception;
      else
        fnd_file.put_line(fnd_file.log,'Upload_data Success ');
        errbuf  := 'Upload_data Success ';
        retcode := 0;
      end if;
      
    end if; -- l_exists row
  
    -- 4) process data 
    l_err_code := 0;
    l_err_msg  := null;
    process_data (p_emp_num  => p_employee_number,
                  p_err_code => l_err_code, -- o v
                  p_err_msg  => l_err_msg); -- o v
                          
    if l_err_code <> 0 then
      fnd_file.put_line(fnd_file.log,'Process_data Failed - '||substr(l_err_msg,1,500));
      errbuf  := 'Process_data Failed - '||substr(l_err_msg,1,500);
      retcode := 2;
      update fnd_concurrent_requests t
      set    t.argument_text = null,
             t.argument3     = null--,
             --t.argument4     = null
      where  t.request_id    = fnd_global.CONC_REQUEST_ID;

      commit;
    else
      fnd_file.put_line(fnd_file.log,'Process_data Success ');
      errbuf  := 'Process_data Success ';
      retcode := 0;
    end if;
           
    -- 5) delete temp table
    l_num_err_rows := fnd_profile.value('XXHR_ELEMENT_ERROR_ROWS'); --15
  
    select count(1)
    into   l_count
    from   xxhr_element_det_interface xei
    where  xei.status                 <> 'SUCCESS';
    
    if nvl(l_count,0) = 0 then
      delete_det_interface (l_err_msg, l_err_code);
      fnd_file.put_line(fnd_file.log,'Success upload elements ');
      errbuf  := 'Success upload elements ';
      retcode := 0;
    /*elsif l_count > 0 and l_count < l_num_err_rows then
      delete_det_interface (l_err_msg, l_err_code);
      fnd_file.put_line(fnd_file.log,'Warrning upload elements - there are about '||
                                     l_num_err_rows||' rows in ERROR');     
      errbuf  := 'Warrning upload elements - there are about '||l_num_err_rows||
                 ' rows in ERROR';
      retcode := 1;*/
    else
      fnd_file.put_line(fnd_file.log,'Warrning upload elements - there are more then '||
                                     l_num_err_rows||' rows in ERROR');       
      errbuf  := 'ERORR upload elements - there are more then '||l_num_err_rows||
                 ' rows in ERROR';
      retcode := 1;
    end if;

    -- 6) update concurrent parameters
    update fnd_concurrent_requests t
    set    t.argument_text = null,
           t.argument3     = null,
           t.argument4     = null
    where  t.request_id    = fnd_global.CONC_REQUEST_ID;

    commit;
    
    dbms_output.put_line('fnd_global.CONC_REQUEST_ID '||fnd_global.CONC_REQUEST_ID); 
    fnd_file.put_line(fnd_file.log, 'fnd_global.CONC_REQUEST_ID '||fnd_global.CONC_REQUEST_ID); 
    
    -- 7) send log mail to Carmit  
    if l_count > 0 then
      --l_cc := 'Dalit.raviv@objet.com'; -- to hold in profile
      
      l_to_user_name := fnd_profile.value('XXHR_ELEMENT_SEND_MAIL_TO');
      l_cc           := fnd_profile.value('XXHR_ELEMENT_SEND_MAIL_CC');
      l_bcc          := fnd_profile.value('XXHR_ELEMENT_SEND_MAIL_BCC');
      fnd_message.SET_NAME('XXOBJT','XXHR_ELEMENT_SEND_MAIL_SUBJECT');
      l_subject      := fnd_message.get; -- 'Send Elements interface Log File '
      
      xxobjt_wf_mail.send_mail_body_proc
                    (p_to_role     => l_to_user_name,     -- i v
                     p_cc_mail     => l_cc,               -- i v
                     p_bcc_mail    => l_bcc,              -- i v
                     p_subject     => l_subject,          -- i v
                     p_body_proc   => 'XXHR_WF_SEND_MAIL_PKG.prepare_salary_clob_body/'||g_batch_id, -- i v
                     p_att1_proc   => l_att1_proc,        -- i v
                     p_att2_proc   => l_att2_proc,        -- i v
                     p_att3_proc   => l_att3_proc,        -- i v
                     p_err_code    => l_error_code,       -- o n
                     p_err_message => l_err_message);     -- o v
      
      /*update xxhr_element_log_interface log_int
      set    log_int.status   = 'SEND_MAIL'
      where  log_int.batch_id = g_batch_id;
      commit;*/
    
    end if;                  
  exception
    when general_exception then
      -- update concurrent parameters
      update fnd_concurrent_requests t
      set    t.argument_text = null,
             t.argument3     = null,
             t.argument4     = null
      where  t.request_id    = fnd_global.CONC_REQUEST_ID;

      commit;
    when others then
      fnd_file.put_line(fnd_file.log,'GEN EXC load_elements_data '||substr(sqlerrm,1,500));
      errbuf  := 'GEN EXC load_elements_data '||substr(sqlerrm,1,500);
      retcode := 2;
      -- update concurrent parameters
      update fnd_concurrent_requests t
      set    t.argument_text = null,
             t.argument3     = null,
             t.argument4     = null
      where  t.request_id    = fnd_global.CONC_REQUEST_ID;

      commit;
  end load_elements_data;  
 
  -------------------------------------------
  procedure test_clob (p_clob out clob) is
    l_clob clob ;--:= empty_clob;
  begin
  
    --l_clob := 'Dalit test';
    --dbms_lob.append(p_clob,l_clob);
    dbms_lob.append(l_clob,'Dalit test');
    --dbms_lob.writeappend(lob_loc => ,amount => ,buffer => ) --(l_clob,'Dalit test');
    p_clob := l_clob;
  end;                   

/*CURSOR elements_pop_c (p_assignment_id in number,
                           p_element_name  in varchar2) is
      select entry.element_entry_id,
             type.element_name,
             entry.object_version_number,
             type.element_type_id,
             link.element_link_id,
             entry.effective_start_date element_start,
             entry.effective_end_date   element_end,
             inpval.input_value_id,
             inpval.name,
             decode(entry.entry_type,  'R',
                    hr_chkfmt.changeformat(value.screen_entry_value,inpval.uom, type.input_currency_code),
                    hr_chkfmt.changeformat(translate(value.screen_entry_value,'x-','x'),inpval.uom,type.input_currency_code)) entry_value ,            
             inpval.effective_start_date input_start,
             inpval.effective_end_date   input_end
      from   pay_input_values_f         inpval,
             pay_element_types_f        type,
             pay_element_links_f        link,
             pay_element_entry_values_f value,
             pay_element_entries_f      entry
      where  type.element_type_id       = link.element_type_id
      and    entry.element_link_id      = link.element_link_id
      and    entry.entry_type           in ('A', 'R', 'E')
      and    value.element_entry_id     = entry.element_entry_id
      and    value.effective_start_date = entry.effective_start_date
      and    value.effective_end_date   = entry.effective_end_date
      and    inpval.input_value_id      = value.input_value_id
      and    entry.assignment_id        = p_assignment_id
      and    type.element_name          = p_element_name --'Basic Salary'
      and    trunc(sysdate)             between entry.effective_start_date and entry.effective_end_date;*/

-- XXHR_PAY_ELEMENTS_PKG.load_elements_data

END XXHR_PAY_ELEMENTS_PKG;
/
