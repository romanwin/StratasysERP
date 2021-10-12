create or replace package body xxhr_vacancy_pkg is

--------------------------------------------------------------------
--  name:            XXHR_VACANCY_PKG
--  create by:       Dalit A. Raviv
--  Revision:        1.1
--  creation date:   17/07/2013 10:44:43
--------------------------------------------------------------------
--  purpose :        
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  17/07/2013  Dalit A. Raviv    initial build
--  1.1  04/02/2014  Dalit A. Raviv    Happy Birthday My Yuval (19)
--                                     add procedure: get_can_see_salary_info
--                                     add caal to new proceduer from get_request_message_clob
--------------------------------------------------------------------
  
  --------------------------------------------------------------------
  --  name:            get_can_see_salary_info
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   04/02/2014 
  --------------------------------------------------------------------
  --  purpose :        
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  03/12/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  function get_can_see_salary_info (p_doc_instance_id in number) return varchar2 is
    l_dynamic_role varchar2(150);
    l_exists       varchar2(2);
  begin
    -- get dynamic role that the doc approval is now in list
    begin
      select ht.dynamic_role 
      into   l_dynamic_role
      from   xxobjt.xxobjt_wf_doc_history_tmp  ht
      where  ht.doc_instance_id = p_doc_instance_id
      and    ht.seq_no = (select di.current_seq_appr 
                          from   xxobjt.xxobjt_wf_doc_instance di
                          where  di.doc_instance_id = p_doc_instance_id);
    exception
      when others then 
        return 'N';
    end;
    -- check this role exists in the approve list to see salary info.
    select 'Y'
    into   l_exists
    from   fnd_flex_values_vl       fv,
           fnd_flex_value_sets      fvs
    where  fv.flex_value_set_id     = fvs.flex_value_set_id
    and    fvs.flex_value_set_name  like 'XXHR_VACANCY_DOC_APP'
    and    nvl(fv.ENABLED_FLAG,'Y') = 'Y'
    and    fv.description           = l_dynamic_role;
    
    return l_exists;
  exception
    when others then 
      return 'N';
  end get_can_see_salary_info; 

  --------------------------------------------------------------------
  --  name:            get_request_message_clob
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   03/12/2012
  --------------------------------------------------------------------
  --  purpose :        
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  03/12/2012  Dalit A. Raviv    initial build
  --  1.1  10/10/2013  Dalit A. Raviv    add vacancy type, vacancy status and comments to the mail notification.
  --------------------------------------------------------------------
  procedure get_request_message_clob(document_id   in           varchar2,
                                     display_type  in           varchar2,
                                     document      in out nocopy clob,
                                     document_type in out nocopy varchar2) is
  
    cursor get_pop_c(p_doc_instance_id in number) is
      select v.vacancy_name,
             v.vacancy_create_by,
             xxhr_util_pkg.get_person_full_name(v.vacancy_create_by,trunc(sysdate),0) vacancy_create_by_name,
             v.department_id,
             hr_general.decode_organization (v.department_id)                         department_name,
             to_char(v.vacancy_start_date,'DD-MON-YYYY')                              Planning_employment_date,
             v.grade_id,
             hr_general.decode_grade (v.grade_id)                                     grade_name,
             v.hr_recruiter_id,
             xxhr_util_pkg.get_person_full_name(v.hr_recruiter_id,trunc(sysdate),0)   hr_manager,
             v.budget,
             -- 1.1 10/10/2013 Dalit A. Raviv
             v.vacancy_type,
             v.vacancy_status,
             v.comments,
             -- 1.2 04/02/2014 Dalit A. Raviv
             --v.salary_range_f,
             --v.salary_range_t,
             v.vacancy_id
      from   xxhr_vacancies     v
      where  v.doc_instance_id  = p_doc_instance_id;

    l_history_clob CLOB;
  BEGIN
    document_type := 'text/html';
    -- Vacancy Details
    document := ' ';
    dbms_lob.append(document,
                    '<p> <font face="Verdana" style="color:darkblue" size="3"> <strong>Request for New Vacancy Details</strong> </font> </p>');
    dbms_lob.append(document,
                    '<div align="left"><TABLE BORDER=1 cellPadding=2>');
  
    FOR get_pop_r IN get_pop_c(document_id) LOOP
      
      dbms_lob.append(document,
                      '<tr> <td><b> Vacancy Name: </b></td> <td>' ||get_pop_r.vacancy_name ||'</td> </tr>');
      -- 1.2 04/02/2014 Dalit A. Raviv 
      dbms_lob.append(document,
                      '<tr> <td><b> Vacancy Number: </b></td> <td>' ||get_pop_r.vacancy_id ||'</td> </tr>');
      --
      dbms_lob.append(document,
                      '<tr> <td><b> Requested by: </b></td> <td>' ||get_pop_r.vacancy_create_by_name ||'</td> </tr>');
        
      dbms_lob.append(document,
                      '<tr> <td><b> Department: </b></td> <td>' ||get_pop_r.department_name || '</td> </tr>');
    
      dbms_lob.append(document,
                      '<tr> <td><b> Planning Start Empoyment: </b></td> <td>' ||get_pop_r.Planning_employment_date || '</td> </tr>');
    
      dbms_lob.append(document,
                      '<tr> <td><b> HR Manager: </b></td> <td>' || get_pop_r.hr_manager ||'</td> </tr>');
    
      dbms_lob.append(document,
                      '<tr> <td><b> Budget: </b></td> <td>' ||nvl(get_pop_r.budget, '&nbsp') ||'</td> </tr>');
                      
      -- 1.1 10/10/2013 Dalit A. Raviv
      dbms_lob.append(document,
                      '<tr> <td><b> Type: </b></td> <td>' ||nvl(get_pop_r.vacancy_type, '&nbsp') ||'</td> </tr>');
                      
      dbms_lob.append(document,
                      '<tr> <td><b> Comments: </b></td> <td>' ||nvl(get_pop_r.comments, '&nbsp') ||'</td> </tr>');                    
    
      -- 1.2 04/02/2014 Dalit A. Raviv
      --if get_can_see_salary_info (document_id) = 'Y' then
      --  dbms_lob.append(document,
      --                '<tr> <td><b> Salary: </b></td> <td>' ||nvl(get_pop_r.salary_range_f, '&nbsp') ||' - '||nvl(get_pop_r.salary_range_t, '&nbsp')||'</td> </tr>');   
      --end if;
      
      dbms_lob.append(document, '</table> </div>');
      
    END LOOP;
    
    -- add history
    l_history_clob := NULL;
    dbms_lob.append(document, '</br> </br><p> <font face="Verdana" style="color:darkblue" size="3"> <strong>Action History</strong> </font> </p>');
    xxobjt_wf_doc_rg.get_history_wf(document_id   => document_id,
                                    display_type  => '',
                                    document      => l_history_clob,
                                    document_type => document_type);
    
    dbms_lob.append(document, l_history_clob);
  
  END get_request_message_clob;

end xxhr_vacancy_pkg;
/
