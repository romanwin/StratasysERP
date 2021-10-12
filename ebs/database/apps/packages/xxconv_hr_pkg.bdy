create or replace package body xxconv_hr_pkg is

--------------------------------------------------------------------
--  name:            XXCONV_HR_PKG
--  create by:       Dalit A. Raviv
--  Revision:        1.0 
--  creation date:   10/01/2011 08:47:46
--------------------------------------------------------------------
--  purpose :        HR project - Handle All conversion programs 
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  10/01/2011  Dalit A. Raviv    initial build
--  1.1  20/11/2011  Dalit A. raviv    add 3 procedures:
--                                     upload_phone_eit, upload_car_eit, get_lookup_code
--  1.2  23/08/2012  Dalit A. Raviv    add procedure upd_IT_phone_numbers
--------------------------------------------------------------------  

  g_debug_num     varchar2(50);

  --------------------------------------------------------------------
  --  name:            update_assignment_grade
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   28/11/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        update_assignment_grade
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  28/11/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------  
  procedure update_assignment_grade is

    l_assg_ovn                      number(15)   := null;
    l_datetrack_mode                varchar2(50) := null;
    l_count_datetrack               number(15)   := null;

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
    --l_org_id                      number(15);
    l_job_id                        number(15);
    l_grade_id                      number;
    --l_g_grade_id                    number;

    -- this cursor show all employees assignments, will update history rows
    CURSOR c_prev_assg is
      select paaf.rowid row_id, 
             paaf.assignment_id, 
             paaf.effective_start_date,
             paaf.effective_end_date,--vac.name
             paaf.job_id, 
             pj.name job_name, 
             pg.name grad_name,
             papf.person_id,
             papf.full_name
      from   per_all_assignments_f paaf,
             per_all_people_f      papf,
             per_jobs              pj,
             per_grades            pg
      where  /*paaf.person_id        in (291)--(861, 137, 257) \*p_person_id*\
      and    */paaf.person_id        = papf.person_id
      --and    trunc(sysdate)        between paaf.effective_start_date and paaf.effective_end_date --
      and    trunc(sysdate)        between papf.effective_start_date and papf.effective_end_date
      and    paaf.assignment_type  = 'E' --
      and    pj.job_id  (+)        = paaf.job_id
      and    pg.grade_id (+)       = paaf.grade_id 
      and    paaf.primary_flag     = 'Y' ;-- 
      --order by effective_start_date desc;
      
  begin
    fnd_global.APPS_INITIALIZE(user_id => 2470,resp_id => 21538 ,resp_appl_id => 800);
    g_debug_num := '20';

    savepoint update_assg;

    l_count_datetrack := '1';
    l_job_id          := null;
    
    for c_prev_ass_r in c_prev_assg loop
      -- Get object_version_number
      select max(object_version_number) 
      INTO   l_assg_ovn
      from   per_all_assignments_f
      where  assignment_id = c_prev_ass_r.assignment_id
      and    c_prev_ass_r.effective_start_date between effective_start_date 
                                               and     effective_end_date;
      -- set datetrack_mode
      /*
      begin
        select 'CORRECTION'
        into   l_datetrack_mode
        from   per_all_assignments_f
        where  assignment_id        = c_prev_ass_r.assignment_id
        and    effective_start_date = c_prev_ass_r.effective_start_date;
      exception
        when others then 
          l_datetrack_mode := 'CORRECTION';
        --when no_data_found then
        --  l_datetrack_mode := 'UPDATE';
        --when too_many_rows then ---- ?????
        --  l_datetrack_mode := 'CORRECTION';
      end;
      */
      l_datetrack_mode := 'CORRECTION';

      g_debug_num := '21';

      l_job_id   := c_prev_ass_r.job_id;
      l_grade_id := XXHR_PERSON_ASSIGNMENT_PKG.get_grade_by_job (c_prev_ass_r.job_id);
      /*if l_grade_id is null then
        l_grade_id := l_g_grade_id; --nvl(l_g_grade_id,63); -- Manager
      else
        l_g_grade_id := l_grade_id;
      end if;*/
      --------------------------------------------
      -- hr_assignment_api.update_emp_asg_criteria
      --------------------------------------------
      g_debug_num := '22';

      if (l_job_id is not null) then     
        begin
            hr_assignment_api.update_emp_asg_criteria(
                          p_effective_date               => c_prev_ass_r.effective_start_date,
                          p_datetrack_update_mode        => l_datetrack_mode,
                          p_assignment_id                => c_prev_ass_r.assignment_id,
                          p_object_version_number        => l_assg_ovn,
                          p_grade_id                     => l_grade_id,
                          p_effective_start_date         => l_assg_effective_start_date,   -- out date
                          p_effective_end_date           => l_assg_effective_end_date,     -- out date
                          p_special_ceiling_step_id      => l_special_ceiling_step_id,     -- in out
                          p_people_group_id              => l_people_group_id,             -- out
                          p_group_name                   => l_group_name,                  -- out
                          p_org_now_no_manager_warning   => l_org_now_no_manager_warning ,
                          p_other_manager_warning        => l_other_manager_warning,
                          p_spp_delete_warning           => l_spp_delete_warning,
                          p_entries_changed_warning      => l_entries_changed_warning,
                          p_tax_district_changed_warning => l_tax_district_changed_warning);

            l_count_datetrack := l_count_datetrack+1;
            commit;
            dbms_output.put_line('Person_id - '||c_prev_ass_r.person_id||' Assignment id - '||c_prev_ass_r.assignment_id); 
          exception
            when others then
              dbms_output.put_line('API Failded - '||substr(sqlerrm,1,200)); 
              dbms_output.put_line('API Failded - '||substr(sqlerrm,200,400));
              rollback;
          end;
      else
        dbms_output.put_line('Person_id - '||c_prev_ass_r.person_id|| ' - have no job value'); 
      end if; -- l_job_id is null
    end loop;

  exception
    when others then
      dbms_output.put_line('GEN EXP - '||substr(sqlerrm,1,150)) ;
      ROLLBACK TO update_assg;   
  end update_assignment_grade;

  --------------------------------------------------------------------
  --  name:            upd_hebrew_names
  --  create by:       Dalit A. Raviv 
  --  Revision:        1.0 
  --  creation date:   09/01/2011 6:43:07 PM
  --------------------------------------------------------------------
  --  purpose :        CUST377 - Conversion - Employee hebrew first and last name to DFF           
  --                   upload hebrew first last name from excel to oracle
  --                   1) select for update of XXHR_CONV_PERSON_DETAILS
  --                   2) load data to table
  --                   3) process this procedure by test
  --------------------------------------------------------------------
  --  ver  date        name             desc
  --  1.0  09/01/2011  Dalit A. Raviv   initial build
  --------------------------------------------------------------------
  procedure upd_hebrew_names (errbuf    out varchar2,
                              retcode   out varchar2) is
  
  
    cursor get_emp_pop_c is
      select * 
      from   XXHR_CONV_PERSON_DETAILS xcp
      where  xcp.log_status           = 'NEW';
      --and    rownum                   < 5; -- for debug
    
    l_ovn                      number        := null;
    l_person_id                number        := null;
    l_effective_start_date     date          := null;
    l_effective_end_date       date          := null;
    l_full_name                varchar2(240) := null;
    l_comment_id               number(10)    := null;
    l_name_combination_warning boolean;
    l_assign_payroll_warning   boolean;
    l_orig_hire_warning        boolean;
    l_err_msg                  varchar2(1000):= null;
  begin
    errbuf  := null;
    retcode := 0;
    
    fnd_global.APPS_INITIALIZE(user_id => 2470,resp_id => 21538 ,resp_appl_id => 800);
    
    for get_emp_pop_r in get_emp_pop_c loop
      l_person_id := XXHR_PERSON_PKG.get_person_id( p_entity_value   => get_emp_pop_r.employee_number, -- i v
                                                    p_effective_date => trunc(sysdate),                -- i d
                                                    p_bg_id          => 0,                             -- i n
                                                    p_entity_name    => 'EMP_NUM');                    -- i v 
      if l_person_id is not null then
        begin
          select max(object_version_number)
          into   l_ovn
          from   per_all_people_f papf
          where  papf.person_id   = l_person_id;
          
          hr_person_api.update_person 
                  (p_effective_date           => SYSDATE,
                   p_datetrack_update_mode    => 'CORRECTION',
                   p_person_id                => l_person_id,
                   p_object_version_number    => l_ovn,                        -- in/out
                   p_employee_number          => get_emp_pop_r.employee_number,-- in/out
                   --p_attribute_category       => 'EMP',
                   p_attribute1               => get_emp_pop_r.last_name,      -- in
                   p_attribute2               => get_emp_pop_r.first_name,     -- in
                   p_effective_start_date     => l_effective_start_date,       -- out
                   p_effective_end_date       => l_effective_end_date,         -- out
                   p_full_name                => l_full_name,                  -- out
                   p_comment_id               => l_comment_id,                 -- out number
                   p_name_combination_warning => l_name_combination_warning,   -- out bool
                   p_assign_payroll_warning   => l_assign_payroll_warning,     -- out bool
                   p_orig_hire_warning        => l_orig_hire_warning           -- out bool
                  );
          commit;
          update XXHR_CONV_PERSON_DETAILS xcpd
          set    xcpd.log_status          = 'SUCCESS',
                 xcpd.log_code            = 0,
                 xcpd.log_msg             = ' Employee - '||get_emp_pop_r.employee_number||
                                            ' Success update Hebrew names',
                 xcpd.last_update_date    = sysdate
          where  xcpd.entity_id           = get_emp_pop_r.entity_id;
          commit;                 
        exception
          when others then
            rollback;
            errbuf  := 'Failed to update all employees';
            retcode := 1;
            l_err_msg := ' Employee - '||get_emp_pop_r.employee_number||
                         ' Failed update Hebrew names'||substr(SQLERRM,1,900);
            update XXHR_CONV_PERSON_DETAILS xcpd
            set    xcpd.log_status          = 'ERROR',
                   xcpd.log_code            = 1,
                   xcpd.log_msg             = l_err_msg,
                   xcpd.last_update_date    = sysdate
            where  xcpd.entity_id           = get_emp_pop_r.entity_id;
            commit; 
        end; -- api
      else
        l_err_msg := ' Employee - '||get_emp_pop_r.employee_number||
                     ' Do not exist in oracle';
        update XXHR_CONV_PERSON_DETAILS xcpd
        set    xcpd.log_status          = 'ERROR',
               xcpd.log_code            = 1,
               xcpd.log_msg             = l_err_msg,
               xcpd.last_update_date    = sysdate
        where  xcpd.entity_id           = get_emp_pop_r.entity_id;
        commit;
      end if; -- l_person_id
    end loop;
  exception
    when others then
      errbuf  := 'GEN EXC - upd_hebrew_names -'||substr(sqlerrm,1,240);
      retcode := 1;

  end upd_hebrew_names; 
  
  --------------------------------------------------------------------
  --  name:            Add_positions_names_to_vs
  --  create by:       Dalit A. Raviv 
  --  Revision:        1.0 
  --  creation date:   10/01/2011 6:43:07 PM
  --------------------------------------------------------------------
  --  purpose :        Add position names to Value Set - XXHR_POSITION_NAME_VS
  --                   all positions will enter to temp table xxhr_conv_jobs_positions
  --                   select with distinct will give me all the new names 
  --                   to add to Value set.
  --------------------------------------------------------------------
  --  ver  date        name             desc
  --  1.0  10/01/2011  Dalit A. Raviv   initial build
  --------------------------------------------------------------------
  procedure Add_positions_names_to_vs (errbuf    out varchar2,
                                       retcode   out varchar2) is
  

    cursor get_pop_c is
      select distinct 
             trim(xcjp.position_name) position_name
      from   xxhr_conversions   xcjp
      where  xcjp.log_status    = 'NEW'
      and    xcjp.position_name is not null;
      --and    rownum < 4;
   
   cursor temp_c is
     select position_name
     from   XXHR_CONVERSIONS_TEMP v
     where  log_status = 'NEW';    
      /*select fv.flex_value --, fvs.flex_value_set_name
      from   fnd_flex_values_vl  fv,
             fnd_flex_value_sets fvs
      where  fv.flex_value_set_id = fvs.flex_value_set_id
      and    fvs.flex_value_set_name like 'XXHR_POSITION_NAME_VS';*/

    l_storage varchar2(32000);
    l_err_msg varchar2(1000) := null;
    l_count1  number         := 0;
  begin
    errbuf  := null;
    retcode := 0;
    -- 21538 global HRMS, 20420 sysadmin
    fnd_global.APPS_INITIALIZE(user_id => 2470,resp_id =>20420,resp_appl_id => 1);
    
    for get_pop_r in get_pop_c loop
      begin
      l_count1 := l_count1 + 1;
      insert into XXHR_CONVERSIONS_TEMP (ENTITY_ID,POSITION_NAME,LOG_STATUS,
                                         LAST_UPDATE_DATE,LAST_UPDATED_BY,CREATION_DATE,CREATED_BY)
      values                            (l_count1,get_pop_r.position_name, 'NEW', 
                                         sysdate, 2470, sysdate,2470);
      commit;
      exception
        when others then 
          dbms_output.put_line('ERR - '||substr(sqlerrm,1,240)); 
      end;                        
    end loop;
    
    for get_pop_r in temp_c/*get_pop_c*/ loop
      begin
        FND_FLEX_VAL_API.CREATE_INDEPENDENT_VSET_VALUE(P_FLEX_VALUE_SET_NAME => 'XXHR_POSITION_NAME_VS',
                                                       P_FLEX_VALUE          => get_pop_r.position_name, -- get_pop_r.flex_value,
                                                       P_DESCRIPTION         => get_pop_r.position_name, -- get_pop_r.flex_value,
                                                       X_STORAGE_VALUE       => l_storage);
      
        update XXHR_CONVERSIONS_TEMP  xcjp
        set    xcjp.log_status        = 'SUCCESS',
               xcjp.log_code          = 0,
               --xcjp.log_msg           = 'Success insert new position - '||get_pop_r.position_name,
               xcjp.last_update_date  = sysdate
        where  xcjp.position_name     = get_pop_r.position_name;
        commit;
        dbms_output.put_line('SUCCESS '||get_pop_r.position_name); 
      exception
        when others then
          errbuf  := 'Add_positions_names_to_vs - at list one row finished with error';
          retcode := 1;
          l_err_msg := 'Failed insert new position - '||get_pop_r.position_name||
                       ' - '||substr(sqlerrm,1,500);
          dbms_output.put_line('ERR '||l_err_msg); 
          rollback;
          update XXHR_CONVERSIONS_TEMP xcjp
          set    xcjp.log_status       = 'ERROR',
                 xcjp.log_code         = 1,
                 xcjp.log_msg          = l_err_msg,
                 xcjp.last_update_date = sysdate
          where  xcjp.position_name    = get_pop_r.position_name;
          commit;
      end;
    end loop;
  exception
    when others then
      errbuf  := 'GEN EXC - Add_positions_names_to_vs -'||substr(sqlerrm,1,240);
      retcode := 2;

  end Add_positions_names_to_vs;
  
  --------------------------------------------------------------------
  --  name:            Add_positions_names_to_vs
  --  create by:       Dalit A. Raviv 
  --  Revision:        1.0 
  --  creation date:   10/01/2011 6:43:07 PM
  --------------------------------------------------------------------
  --  purpose :        Add position names to Value Set - XXHR_POSITION_NAME_VS
  --                   all positions will enter to temp table xxhr_conv_jobs_positions
  --                   select with distinct will give me all the new names 
  --                   to add to Value set.
  --
  --                   select fv.FLEX_VALUE_MEANING,fv.description, fv.flex_value 
  --                   from   fnd_flex_values_vl      fv,
  --                          fnd_flex_value_sets     fvs
  --                   where  fv.flex_value_set_id    = fvs.flex_value_set_id
  --                   and    fvs.flex_value_set_name like 'XXHR_POSITION_NAME_VS'
  --
  --------------------------------------------------------------------
  --  ver  date        name             desc
  --  1.0  10/01/2011  Dalit A. Raviv   initial build
  --------------------------------------------------------------------
  procedure Add_jobs_names_to_vs (errbuf    out varchar2,
                                  retcode   out varchar2) is
  

    cursor get_pop_c is
      select distinct 
             trim(xcjp.job_name)        job_name
      from   xxhr_conversions           xcjp
      where  nvl(xcjp.log_status,'NEW') = 'NEW'
      and    xcjp.job_name              is not null
      and    xcjp.organization_names    is null;

    cursor temp_c is
     select job_name
     from   XXHR_CONVERSIONS_TEMP v
     where  log_status = 'NEW';  
      /*select fv.flex_value --, fvs.flex_value_set_name
      from   fnd_flex_values_vl  fv,
             fnd_flex_value_sets fvs
      where  fv.flex_value_set_id = fvs.flex_value_set_id
      and    fvs.flex_value_set_name like 'XXHR_POSITION_NAME_VS';*/

      
    l_storage varchar2(32000);
    l_err_msg varchar2(1000) := null;
    l_count1  number         := 0;

  begin
    errbuf  := null;
    retcode := 0;
    -- 21538 global HRMS, 20420 sysadmin
    -- 800   human Reasource, 1 System administration
    fnd_global.APPS_INITIALIZE(user_id => 2470,resp_id =>20420,resp_appl_id => 1);
    
    for get_pop_r in get_pop_c loop
      begin
      l_count1 := l_count1 + 1;
      insert into XXHR_CONVERSIONS_TEMP (ENTITY_ID,JOB_NAME,LOG_STATUS,
                                         LAST_UPDATE_DATE,LAST_UPDATED_BY,CREATION_DATE,CREATED_BY)
      values                            (l_count1,get_pop_r.job_name, 'NEW', 
                                         sysdate, 2470, sysdate,2470);
      commit;
      exception
        when others then 
          dbms_output.put_line('ERR - '||substr(sqlerrm,1,240)); 
      end;                        
    end loop;
    
    for get_pop_r in temp_c/*get_pop_c*/ loop
      begin
        FND_FLEX_VAL_API.CREATE_INDEPENDENT_VSET_VALUE(P_FLEX_VALUE_SET_NAME => 'XXHR_JOB_NAME_VS',--'XXHR_JOB_GRADE_VS',
                                                       P_FLEX_VALUE          => get_pop_r.job_name, -- get_pop_r.flex_value,
                                                       P_DESCRIPTION         => get_pop_r.job_name, -- get_pop_r.flex_value,
                                                       X_STORAGE_VALUE       => l_storage);
      
        update XXHR_CONVERSIONS_TEMP xcjp
        set    xcjp.log_status       = 'SUCCESS',
               xcjp.log_code         = 0,
               xcjp.last_update_date = sysdate
        where  xcjp.position_name    = get_pop_r.job_name;

        commit;
        dbms_output.put_line('SUCCESS - '||get_pop_r.job_name); 
      exception
        when others then
          errbuf  := 'Add_jobs_names_to_vss - at list one row finished with error';
          retcode := 1;
          l_err_msg := 'Failed insert new job - '||get_pop_r.job_name||
                       ' - '||substr(sqlerrm,1,240);
          dbms_output.put_line('ERR - '||l_err_msg); 
          rollback;
          update XXHR_CONVERSIONS_TEMP xcjp
          set    xcjp.log_status       = 'ERROR',
                 xcjp.log_code         = 1,
                 xcjp.log_msg          = l_err_msg,
                 xcjp.last_update_date = sysdate
          where  xcjp.position_name    = get_pop_r.job_name;

          commit;
      end;
    end loop;

  exception
    when others then
      errbuf  := 'GEN EXC - Add_jobs_names_to_vs -'||substr(sqlerrm,1,240);
      retcode := 2;

  end Add_jobs_names_to_vs;
 
  --------------------------------------------------------------------
  --  name:            create_new_job
  --  create by:       Dalit A. Raviv 
  --  Revision:        1.0 
  --  creation date:   10/01/2011 6:43:07 PM
  --------------------------------------------------------------------
  --  purpose :        use API to create the new jobs
  --------------------------------------------------------------------
  --  ver  date        name             desc
  --  1.0  10/01/2011  Dalit A. Raviv   initial build
  --------------------------------------------------------------------
  procedure create_new_job (errbuf    out varchar2,
                            retcode   out varchar2)  IS

    l_job_id                 number;
    l_object_version_number  number;
    l_job_definition_id      number;
    l_api_failed             varchar2(100);
    l_name                   varchar2(500);
    l_bg_id                  number;
    l_job_group_id           number;
    l_error                  varchar2(2000);
    l_count                  number(15)   := 0;
    l_date_from              date;

    cursor job_name_c is
      select distinct trim(xcjp.job_name) job_name
      from   xxhr_conversions  xcjp
      where  xcjp.log_status   = 'NEW';
      
   cursor temp_c is
     select job_name 
     from   XXHR_CONVERSIONS_TEMP
     where  log_status = 'NEW';  
     
  l_count1 number := 0;    

  begin
    errbuf  := null;
    retcode := 0;
       
    for job_name_r in job_name_c loop
      l_count1 := l_count1 + 1;
      begin
      insert into XXHR_CONVERSIONS_TEMP (ENTITY_ID,JOB_NAME,LOG_STATUS,
                                         LAST_UPDATE_DATE,LAST_UPDATED_BY,CREATION_DATE,CREATED_BY)
      values                            (l_count1,job_name_r.job_name, 'NEW', 
                                         sysdate, 2470, sysdate,2470); 
      commit;
      exception
        when others then
          dbms_output.put_line('ERR - '||substr(sqlerrm,1,240)); 
      end;                       
    end loop;
    
    fnd_global.APPS_INITIALIZE(user_id => 2470,resp_id => 21538 ,resp_appl_id => 800);
    dbms_output.put_line('Start create_job at: '||to_char(sysdate,'dd/mm/yyyy hh24:mi:ss'));
    for job_name_r/*current_rec*/ in temp_c/*job_name_c*/ loop
      begin
        l_job_definition_id := NULL;
        --
        -- Get business group id
        l_api_failed := 'select business_group_id';
        l_bg_id      := XXHR_UTIL_PKG.get_business_group_id;

        l_api_failed := 'select job_group_id';

        select job_group_id
        into   l_job_group_id
        from   per_job_groups
        where  business_group_id = l_bg_id;

        l_date_from := to_date('01/01/1990','dd/mm/yyyy');

        l_api_failed := 'before create_job ';
        hr_job_api.create_job(p_business_group_id     => l_bg_id,
                              p_date_from             => l_date_from,
                              p_job_group_id          => l_job_group_id,
                              p_segment1              => job_name_r.job_name,
                              p_job_id                => l_job_id,                -- o
                              p_object_version_number => l_object_version_number, -- o
                              p_job_definition_id     => l_job_definition_id,     -- o
                              p_name                  => l_name);                 -- o
        commit;
        update XXHR_CONVERSIONS_TEMP  xcjp
        set    xcjp.log_status        = 'SUCCESS',
               xcjp.log_code          = 0,
               --xcjp.log_msg           = xcjp.log_msg||chr(10)||Null,
               xcjp.last_update_date  = sysdate
        where  xcjp.job_name          = job_name_r.job_name; 
        commit;   
      exception
        when others then
          
          l_error:= l_error||'-'||substr(sqlerrm,1,200)||' API_FAIL: '||l_api_failed;
          dbms_output.put_line('l_err: '||l_error||' Job name '||job_name_r.job_name);
          rollback;
          update XXHR_CONVERSIONS_TEMP  xcjp
          set    xcjp.log_status        = 'ERROR',
                 xcjp.log_code          = 1,
                 xcjp.log_msg           = l_error,
                 xcjp.last_update_date  = sysdate
          where  xcjp.job_name          = job_name_r.job_name; 
          commit;
          errbuf  := l_error;
          retcode := 1;
      END; -- create job block

      -- עדכון סטטוס רשומה בטבלת הסבות
      
      l_error := '0';

	    l_count := l_count+ 1;
    end loop;

    dbms_output.put_line('end create_job at: '||to_char(sysdate,'dd/mm/yyyy hh24:mi:ss'));

  exception
    when others then
      l_error := substr(sqlerrm,1,100)||' create_job';
      dbms_output.put_line('other errors: '||l_error);
      errbuf  := l_error;
      retcode := 1;
  end create_new_job;

  --------------------------------------------------------------------
  --  name:            correct_employee_numbers
  --  create by:       Dalit A. Raviv 
  --  Revision:        1.0 
  --  creation date:   10/01/2011 6:43:07 PM
  --------------------------------------------------------------------
  --  purpose :        use API to correct employee numbers
  --------------------------------------------------------------------
  --  ver  date        name             desc
  --  1.0  10/01/2011  Dalit A. Raviv   initial build
  --------------------------------------------------------------------
  procedure correct_employee_numbers (errbuf    out varchar2,
                                      retcode   out varchar2) is
  
    cursor emp_num_c is
      select papf.employee_number, papf.full_name, xxhr_util_pkg.get_location_code(papf.person_id,trunc(sysdate), 0) location,
             papf.national_identifier NID,
             hr_person_type_usage_info.get_user_person_type(trunc(sysdate), papf.person_id) person_type,
             hr_person_type_usage_info.GetSystemPersonType(papf.person_type_id) system_person_type,
             papf.person_id
      from   per_all_people_f papf
      where  trunc(sysdate)   between papf.effective_start_date and papf.effective_end_date
      and    length(papf.employee_number) > 3 
      and    hr_person_type_usage_info.GetSystemPersonType(papf.person_type_id) = 'EMP'
      and    papf.employee_number not in ('000001','000002','000003','0000016')
      order by /*case when length(papf.employee_number) <= 3  
                    then 1  
                    else 2 
                    end ,  */to_number (papf.employee_number);
                    
    l_number                   number := 600;   
    l_ovn                      number(10);
    l_effective_start_date     date;
    l_effective_end_date       date; 
    l_full_name                varchar2(360);
    l_comment_id               number(10):= null;
    l_name_combination_warning boolean;
    l_assign_payroll_warning   boolean;
    l_orig_hire_warning        boolean;              
  begin 
    errbuf  := null;
    retcode := 0;
    for emp_num_r in emp_num_c loop 
    
      select max(object_version_number)
      into   l_ovn
      from   per_all_people_f
      where  person_id = emp_num_r.person_id;
      begin      
        hr_person_api.update_person( p_effective_date           => SYSDATE,
                                     p_datetrack_update_mode    => 'CORRECTION',
                                     p_person_id                => emp_num_r.person_id,
                                     p_object_version_number    => l_ovn,                      -- in out
                                     p_employee_number          => l_number,
                                     --p_attribute4               => emp_num_r.employee_number,
                                     p_effective_start_date     => l_effective_start_date,
                                     p_effective_end_date       => l_effective_end_date,
                                     p_full_name                => l_full_name,
                                     p_comment_id               => l_comment_id,               -- number
                                     p_name_combination_warning => l_name_combination_warning, -- bool
                                     p_assign_payroll_warning   => l_assign_payroll_warning,   -- bool
                                     p_orig_hire_warning        => l_orig_hire_warning         -- bool
                                    );
        
        dbms_output.put_line('Api Success - Employee number old '||emp_num_r.employee_number||
                             ' Employee number new '||l_number||
                             ' Full name '||emp_num_r.full_name); 
        l_number := l_number +1;
        commit;
      exception
        when others then
          rollback;
          dbms_output.put_line('Api Error - Employee number '||emp_num_r.employee_number|| 
                               ' Full name '||emp_num_r.full_name||' - '||substr(Sqlerrm,1,240)); 
          errbuf  := 'At list One employee finished with error ';
          retcode := 1;
      end;
    end loop;
  exception
    when others then
      errbuf  := 'GEN EXC - correct_employee_numbers - '||substr(sqlerrm,1,240);
      retcode := 2;
  end correct_employee_numbers; 
 
  --------------------------------------------------------------------
  --  name:            create_hr_organization
  --  create by:       Dalit A. Raviv 
  --  Revision:        1.0 
  --  creation date:   12/01/2011 6:43:07 PM
  --------------------------------------------------------------------
  --  purpose :        use API to create new organizations
  --                   !!!!!!!!!!!! NOTE !!!!!!!!!!!!!!!!!
  --                   need to add to Objet Main Business Group TOP_ORG
  --                   need to add to all operating units Hr organization clasification
  --------------------------------------------------------------------
  --  ver  date        name             desc
  --  1.0  12/01/2011  Dalit A. Raviv   initial build
  -------------------------------------------------------------------- 
  procedure create_hr_organization ( errbuf    out varchar2,
                                     retcode   out varchar2 ) is
  
    cursor organizations_pop_c is
      select * 
      from   xxobjt.xxhr_conversions t
      where  organization_names      is not null
      and    log_status              = 'NEW'
      and    t.full_name             is null;
      
      --and    t.entity_id             = 4;
      
    /* this select is from HR env to get the new organization population
    select ou.name, ou.type, ou.location_id loc_id,
           --loc.location_code loc_name,
           --ou.organization_id, 
           --ou.internal_external_flag internal,
           --ou.date_from
    from   hr_all_organization_units ou,
           hr_locations              loc
    where  ou.location_id            = loc.location_id
    and    ou.type is not null
    and    (ou.name                  like ('%US') or 
            ou.name                  like ('%IL') or
            ou.name                  like ('%EU') or
            ou.name                  like ('%DE') or
            ou.name                  like ('%AP') or
            ou.name                  like ('%HK'))
    and    ou.date_to                is null;
    */
    l_api_failed  varchar2(100) := null;  
    l_bg_id       number        := null;
    l_org_id      number(15)    := null;
    l_org_ovn     number(10)    := null;
    l_org_info_id number(15)    := null;
    l_info_ovn    number(10)    := null;
  begin
    errbuf  := null;
    retcode := 0;
    
    -- 21538 global HRMS, 20420 sysadmin
    fnd_global.APPS_INITIALIZE(user_id => 2470,resp_id =>21538,resp_appl_id => 800);
    l_bg_id := XXHR_UTIL_PKG.get_business_group_id;
    for organizations_pop_r in organizations_pop_c loop
      --------------------------------------------
      -- hr_organization_api.create_organization
      --------------------------------------------
      begin
        l_api_failed := 'create_organization';
        hr_organization_api.create_organization
              (p_effective_date         => to_date('01/01/1990','dd/mm/yyyy'),
               p_business_group_id      => l_bg_id,
               p_date_from              => to_date('01/01/1990','dd/mm/yyyy'),
               p_name                   => organizations_pop_r.organization_names,
               p_location_id            => organizations_pop_r.organization_location_id,
               p_internal_external_flag => 'INT',
               p_type                   => organizations_pop_r.organization_type,
               p_attribute1             => organizations_pop_r.org_attribute1,
               p_attribute2             => organizations_pop_r.org_attribute2,
               p_organization_id        => l_org_id,   -- out param
               p_object_version_number  => l_org_ovn); -- out param
      exception
        when others then
          errbuf   := l_api_failed ||' Failed - '||substr(sqlerrm,1,240);
          retcode  := 1;
          dbms_output.put_line(l_api_failed ||' Failed - '||substr(sqlerrm,1,200));
          rollback;
          update xxhr_conversions       xcjp
          set    xcjp.log_status        = 'E',
                 xcjp.log_code          = 1,
                 xcjp.log_msg           = l_api_failed ||' Failed - '||errbuf,
                 xcjp.last_update_date  = sysdate
          where  xcjp.entity_id         = organizations_pop_r.entity_id; 
          commit;   
           
          l_org_id := null;
      end;
      begin
        if l_org_id is not null then
          --------------------------------------------
          -- hr_organization_api.create_org_classification
          --------------------------------------------
          l_api_failed := 'create_org_classification';
          hr_organization_api.create_org_classification(
                 p_effective_date         => to_date('01/01/1990','dd/mm/yyyy'),
                 p_organization_id        => l_org_id,
                 p_org_classif_code       => 'HR_ORG',
                 p_org_information_id     => l_org_info_id, -- out param
                 p_object_version_number  => l_info_ovn); -- out param
        
          update xxhr_conversions       xcjp
          set    xcjp.log_status        = 'S',
                 xcjp.log_code          = 0,
                 xcjp.log_msg           = null,
                 xcjp.last_update_date  = sysdate
          where  xcjp.entity_id         = organizations_pop_r.entity_id; 

          commit;   
        
        end if;
      exception
        when others then
          errbuf   := l_api_failed ||' Failed - '||substr(sqlerrm,1,240);
          retcode  := 1;
          dbms_output.put_line(l_api_failed ||' Failed - '||substr(sqlerrm,1,200)); 
          rollback;
          update xxhr_conversions       xcjp
          set    xcjp.log_status        = 'E',
                 xcjp.log_code          = 1,
                 xcjp.log_msg           = l_api_failed ||' Failed - '||errbuf,
                 xcjp.last_update_date  = sysdate
          where  xcjp.entity_id         = organizations_pop_r.entity_id; 

          commit;             
      end;
    end loop;
    /*
    create hierarchy
    hr_hierarchy_element_api.create_hierarchy_element(
                    p_organization_id_parent   => l_parent_org_id,
                    p_org_structure_version_id => l_org_structure_version_id,
                    p_organization_id_child    => l_org_id,
                    p_business_group_id        => l_bg_id,
                    p_effective_date           => l_go_live_date, --to_date('01/09/2003','dd/mm/yyyy'),
                    p_date_from                => l_go_live_date, --to_date('01/09/2003','dd/mm/yyyy'),
                    p_security_profile_id      => NULL,
                    p_view_all_orgs            => NULL,
                    p_end_of_time              => to_date('31/12/4712','dd/mm/yyyy'),
                    p_hr_installed             => 'I',
                    p_pa_installed             => 'N',
                    p_pos_control_enabled_flag => NULL,--'N' ,
                    p_warning_raised           => l_warning_raised, --out param
                    p_org_structure_element_id => l_org_structure_element_id, --out param
                    p_object_version_number    =>  l_ose_ovn); --out param
    */
  end create_hr_organization;
  
  --------------------------------------------------------------------
  --  name:            correct_start_date
  --  create by:       Dalit A. Raviv 
  --  Revision:        1.0 
  --  creation date:   12/01/2011 6:43:07 PM
  --------------------------------------------------------------------
  --  purpose :        use API to change start date of employee
  --------------------------------------------------------------------
  --  ver  date        name             desc
  --  1.0  12/01/2011  Dalit A. Raviv   initial build
  -------------------------------------------------------------------- 
  procedure correct_start_date (errbuf        out varchar2,
                                retcode       out varchar2,
                                p_person_id   in  number,
                                p_old_date    in  date,
                                p_new_date    in  date,
                                p_update_type in  varchar2) is

    l_qwarn_ee varchar2(100) := null;
  begin
    errbuf  := null;
    retcode := 0;  
     -- need to have loop on the employees with start date. 
     
     -- p_update_type 'E' for employees, 'C' for contingent workers
     -- p_applicant_number Applicant number, if specified will cause appl records to be moved also
     -- p_warn_ee For employees, set to 'Y' if recurring element entries were changed.
     hr_change_start_date_api.update_start_date
      (p_person_id           => p_person_id,                        --861 in number
       p_old_start_date      => p_old_date,                         --to_date('16/11/2009','dd/mm/yyyy'), -- in date
       p_new_start_date      => p_new_date,                         --to_date('01/12/2009','dd/mm/yyyy'), -- in date         
       p_update_type         => p_update_type,                      --'E',                                -- in varchar2
       p_warn_ee             => l_qwarn_ee                          -- out nocopy varchar2
      ); 
    commit;
  exception
    when others then
      dbms_output.put_line('EXCEPTION - '||substr(sqlerrm,1,240)); 
      rollback;
       errbuf   := 'EXCEPTION - '||substr(sqlerrm,1,240);
       retcode  := 1;
  end correct_start_date;
  
  --------------------------------------------------------------------
  --  name:            close_posiotions
  --  create by:       Dalit A. Raviv 
  --  Revision:        1.0 
  --  creation date:   28/02/2011 
  --------------------------------------------------------------------
  --  purpose :        use API to close positions after conversion
  --                   param p_datetrack_mode Indicates which DateTrack mode to use when updating
  --                   the record. You must set to either UPDATE, CORRECTION, UPDATE_OVERRIDE or
  --                   UPDATE_CHANGE_INSERT. Modes available for use with a particular record
  --                   depend on the dates of previous record changes and the effective date of
  --                   this change.
  --------------------------------------------------------------------
  --  ver  date        name             desc
  --  1.0  28/02/2011  Dalit A. Raviv   initial build
  --------------------------------------------------------------------                               
  procedure close_posiotions   (errbuf        out varchar2,
                                retcode       out varchar2) is
                                
    cursor get_pop_c is
      select distinct 
             pos.name          position, 
             pos.position_id, 
             pj.name           job,
             pj.job_id, 
             ou.name           dept, 
             loc.location_code, 
             pos.business_group_id, 
             pos.frequency,
             pos.status, 
             pos.availability_status_id, 
             pos.object_version_number, 
             pos.position_definition_id,
             hr_general.decode_availability_status(pos.availability_status_id) availability_status_desc,
             XXHR_PERSON_ASSIGNMENT_PKG.get_position_exists (pos.position_id,trunc(sysdate)) ass
      from   hr_locations_all                    loc,
             (select * 
              from   per_jobs                    pj
              where  trunc(sysdate)              between nvl(pj.date_from,sysdate -1) and nvl(pj.date_to,sysdate +1)
              and    pj.business_group_id        = 0) pj,
             (select * 
              from   hr_all_positions_f          pos
              where  trunc(sysdate )              between nvl(pos.date_effective,sysdate -1) and nvl (pos.date_end,sysdate +1)
              and    pos.business_group_id       = 0) pos,
             (select * 
              from   per_all_organization_units  ou
              where  trunc(sysdate )              between nvl(ou.date_from,sysdate -1) and nvl(ou.date_to,sysdate +1)
              and    ou.business_group_id        = 0) ou
      where  loc.location_id                     = pos.location_id
      and    pj.job_id                           = pos.job_id
      and    ou.organization_id                  = pos.organization_id
      and    pos.availability_status_id          = 1
      and    pj.job_id                           in (66,68,70,64)
      and    XXHR_PERSON_ASSIGNMENT_PKG.get_position_exists (pos.position_id,trunc(sysdate)) = 'N'
      --and    rownum                              < 10
      order by XXHR_PERSON_ASSIGNMENT_PKG.get_position_exists (pos.position_id,trunc(sysdate)), loc.location_code;
  
    l_ovn                    number        := null;
    l_position_name          varchar2(240) := null;
    l_position_definition_id number        := null;
    l_effective_start_date   date          := null;
    l_effective_end_date     date          := null;
    l_err_msg                varchar2(1000):= null;
    l_valid_grades_changed_warning         boolean;
  
  begin
    errbuf  := 'Success';
    retcode := 0;
    for get_pop_r in get_pop_c loop
      begin
        l_ovn                    := null;
        l_position_name          := null;
        l_position_definition_id := null;
        l_effective_start_date   := null;
        l_effective_end_date     := null;
        l_err_msg                := null;
        dbms_output.put_line('----------------------------'); 
        /*begin
          select nvl(max(pos.object_version_number),0) ovn
          into   l_ovn
          from   per_all_positions pos
          where  pos.position_id   = get_pop_r.position_id;
        exception
          when others then
            l_ovn := 0;
        end;*/
        --dbms_output.put_line('Ovn - '||l_ovn); 
        l_ovn           := get_pop_r.object_version_number;
        l_position_name := get_pop_r.position;
        dbms_output.put_line('Ovn - '||l_ovn); 
        if get_pop_r.ass = 'N' then
          hr_position_api.update_position (--p_validate                       in  boolean   default false,
                                           p_position_id                    => get_pop_r.position_id,    -- i   n
                                           p_effective_start_date           => l_effective_start_date,   -- o   d
                                           p_effective_end_date             => l_effective_end_date,     -- o   d
                                           p_position_definition_id         => l_position_definition_id, -- i/o n
                                           p_avail_status_prop_end_date     => trunc(sysdate) +2,        -- i   d
                                           p_valid_grades_changed_warning   => l_valid_grades_changed_warning, -- o   B
                                           p_name                           => l_position_name,-- i/o v
                                           p_availability_status_id         => 4,              -- i   n 5 = Eliminated , 4 = Frozen
                                           p_object_version_number          => l_ovn,          -- i/o n
                                           p_effective_date                 => trunc(sysdate), -- i   d 
                                           p_datetrack_mode                 => 'UPDATE'    -- i   v
                                          );
          
          commit;                                
          dbms_output.put_line('Success - '||l_position_name); 
        else
          dbms_output.put_line('Exists Ass - '||get_pop_r.position_id||' - '||l_position_name); 
        end if;
        
      exception
        when others then
          rollback;
          errbuf  := 'At least one position Failed';
          retcode := 1;
          dbms_output.put_line('Failed - '||get_pop_r.position_id||' - '||l_position_name ||' Ovn - '||l_ovn);
          l_err_msg := substr(sqlerrm,1,240);    
          l_err_msg := substr(l_err_msg,instr(l_err_msg,'Action:'));
          dbms_output.put_line(l_err_msg);  
      end;
    end loop;                                
  end close_posiotions;   
  
  --------------------------------------------------------------------
  --  name:            get_value_from_line
  --  create by:       Dalit A. Raviv 
  --  Revision:        1.0 
  --  creation date:   28/03/2011
  --------------------------------------------------------------------
  --  purpose :        get value from excel line 
  --                   return short string each time by the deliminar 
  --------------------------------------------------------------------
  --  ver  date        name             desc
  --  1.0  28/03/2011  Dalit A. Raviv   initial build
  --------------------------------------------------------------------
  function get_value_from_line( p_line_string in out varchar2,
                                p_err_msg     in out varchar2,
                                c_delimiter   in varchar2) return varchar2 is
   
    l_pos        number;
    l_char_value varchar2(50);
     
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
  --  name:            Add_Atzmon_codes_to_vs
  --  create by:       Dalit A. Raviv 
  --  Revision:        1.0 
  --  creation date:   28/03/2011 
  --------------------------------------------------------------------
  --  purpose :        Add atsmon codes to Value Set - XXHR_ATSMON_CODES
  --                   
  --------------------------------------------------------------------
  --  ver  date        name             desc
  --  1.0  28/03/2011  Dalit A. Raviv   initial build
  --------------------------------------------------------------------   
  procedure Add_Atzmon_codes_to_vs (errbuf    out varchar2,
                                    retcode   out varchar2) is
                                    
    cursor get_pop_c is
      select distinct 
             conv.atsmon_code           atsmon_code
      from   xxhr_conversions_temp      conv
      where  nvl(conv.log_status,'NEW') = 'NEW'
      and    conv.atsmon_code           is not null;
    
    l_storage varchar2(32000); 
    l_err_msg varchar2(1000) := null;
  begin
    errbuf  := null;
    retcode := 0;
    fnd_global.APPS_INITIALIZE(user_id => 2470,resp_id =>51597,resp_appl_id => 800);
    for get_pop_r in get_pop_c loop
      begin
        FND_FLEX_VAL_API.CREATE_INDEPENDENT_VSET_VALUE(P_FLEX_VALUE_SET_NAME => 'XXHR_ATSMON_CODES',
                                                       P_FLEX_VALUE          => get_pop_r.atsmon_code, 
                                                       P_DESCRIPTION         => get_pop_r.atsmon_code, 
                                                       X_STORAGE_VALUE       => l_storage);

      
        update XXHR_CONVERSIONS_TEMP  xcjp
        set    xcjp.log_status        = 'SUCCESS',
               xcjp.log_code          = 0,
               --xcjp.log_msg           = 'Success insert new position - '||get_pop_r.position_name,
               xcjp.last_update_date  = sysdate
        where  xcjp.atsmon_code       = get_pop_r.atsmon_code;
        commit;
        dbms_output.put_line('SUCCESS '||get_pop_r.atsmon_code); 
      exception
        when others then
          errbuf  := 'upload_atsmon_code - at list one row finished with error';
          retcode := 1;
          l_err_msg := 'Failed insert atsmon_code - '||get_pop_r.atsmon_code||
                       ' - '||substr(sqlerrm,1,500);
          dbms_output.put_line('ERR '||l_err_msg); 
          rollback;
          update XXHR_CONVERSIONS_TEMP xcjp
          set    xcjp.log_status       = 'ERROR',
                 xcjp.log_code         = 1,
                 xcjp.log_msg          = l_err_msg,
                 xcjp.last_update_date = sysdate
          where  xcjp.atsmon_code      = get_pop_r.atsmon_code;
          commit;
      end;
    end loop;
  exception  
    when others then
      errbuf  := 'GEN EXC - Add_Atzmon_codes_to_vs - '||substr(sqlerrm,1,240);
      retcode := 1;
  end Add_Atzmon_codes_to_vs;                                    
  
  --------------------------------------------------------------------
  --  name:            upload_atsmon_code
  --  create by:       Dalit A. Raviv 
  --  Revision:        1.0 
  --  creation date:   28/03/2011 
  --------------------------------------------------------------------
  --  purpose :        use API to add atzmon code to emp assignment
  --------------------------------------------------------------------
  --  ver  date        name             desc
  --  1.0  28/03/2011  Dalit A. Raviv   initial build
  --------------------------------------------------------------------                               
  procedure upload_atsmon_code (errbuf        out varchar2,
                                retcode       out varchar2,
                                p_location    in  varchar2, --/UtlFiles/HR
                                p_filename    in  varchar2) is
                             
    l_file_hundler              utl_file.file_type;
    l_line_buffer               varchar2(2000);
    l_counter                   number               := 0;
    l_pos                       number;
    c_delimiter                 constant varchar2(1) := ',';
    
    l_emp_number                per_all_people_f.employee_number%type;
    l_full_name                 per_all_people_f.full_name%type;
    l_dept                      varchar2(100);
    l_code_atsmon               varchar2(50);
    l_flag                      varchar2(5)  := 'Y';
    
    l_ass_id                    per_all_assignments_f.assignment_id%type;
    l_ass_number                per_all_assignments_f.assignment_number%type;
    l_ovn                       per_all_assignments_f.object_version_number%type;
   
    l_soft_coding_keyflex_id    number(10);
    l_comment_id                number(10);
    l_concatenated_segments     varchar2(100);
    l_no_managers_warning       boolean;
    l_assg_effective_start_date date;
    l_assg_effective_end_date   date;
    l_other_manager_warning     boolean;
    
    l_err_msg                   varchar2(1500);
    
    invalid_element             exception;
  
  begin
    errbuf  := null;
    retcode := 0;
    fnd_global.APPS_INITIALIZE(user_id => 2470,resp_id =>51597,resp_appl_id => 800);
    -- handle open file to read and handle file exceptions
    begin
      l_file_hundler := utl_file.fopen( location     => p_location,
                                        filename     => p_filename,
                                        open_mode    => 'r',
                                        max_linesize => 32000);
    exception
      when utl_file.invalid_path then  
        retcode := 1;
        errbuf  := 'Import file was failes. 1 Invalid Path for ' || ltrim(p_filename);
        --fnd_file.put_line(fnd_file.log,'Invalid Path for ' || ltrim(p_filename));
        dbms_output.put_line('Invalid Path for ' || ltrim(p_filename)); 
        raise;
      when utl_file.invalid_mode then
        retcode := 1;
        errbuf  := 'Import file was failes. 2 Invalid Mode for ' || ltrim(p_filename);
        --fnd_file.put_line(fnd_file.log,'Invalid Mode for ' || ltrim(p_filename));
        dbms_output.put_line('Invalid Mode for ' || ltrim(p_filename)); 
        raise;
      when utl_file.invalid_operation then
        retcode := 1;
        errbuf  := 'Invalid operation for ' || ltrim(p_filename) ||substr(SQLERRM,1,500);
        --fnd_file.put_line(fnd_file.log,'Invalid operation for ' || ltrim(p_filename) ||SQLERRM);
        dbms_output.put_line('Invalid operation for ' || ltrim(p_filename) ||SQLERRM); 
        raise;
      when others then
        retcode := 1;
        errbuf  := 'Other for ' || ltrim(p_filename)||substr(SQLERRM,1,500);
        --fnd_file.put_line(fnd_file.log,'Other for ' || ltrim(p_filename));
        dbms_output.put_line('Other for ' || ltrim(p_filename)); 
        raise;
    end;
    
    -- start read from file, do needed validation, and upload data to table
    -- Loop For All File's Lines
    loop
      begin
        -- goto next line
        l_counter      := l_counter + 1;
        l_err_msg      := null;
        l_emp_number   := null;
        l_flag         := 'Y';
        l_full_name    := null;
        l_dept         := null;
        l_code_atsmon  := null;
        l_ass_id       := null;
        l_ass_number   := null;
        l_ovn          := null;
    
        -- Get Line and handle exceptions
        begin
          utl_file.get_line(file   => l_file_hundler,
                            buffer => l_line_buffer);
        exception
          when utl_file.read_error then
            errbuf := 'Read Error for line: ' || l_counter;
            raise invalid_element;
          when no_data_found then
            exit;
          when others then
            errbuf := 'Read Error for line: ' || l_counter ||', Error: ' || substr(SQLERRM,1,500);
            raise invalid_element;
        end;
        
        -- Get data from line separate by deliminar
        if l_counter > 1 then
          l_pos := 0;
          
          -- Employee number                                        
          l_emp_number    := get_value_from_line(l_line_buffer,
                                                 l_err_msg,
                                                 c_delimiter);
                                                 
          l_full_name     := get_value_from_line(l_line_buffer,
                                                 l_err_msg,
                                                 c_delimiter); 
          
          l_dept          := get_value_from_line(l_line_buffer,
                                                 l_err_msg,
                                                 c_delimiter); 
          
          l_code_atsmon   := get_value_from_line(l_line_buffer,
                                                 l_err_msg,
                                                 c_delimiter);                                 
          -- get assignment details
          -- id + ovn +
          begin
            select paa.assignment_id, paa.assignment_number, paa.object_version_number
            into   l_ass_id, l_ass_number, l_ovn
            from   per_all_people_f      paf,
                   per_all_assignments_f paa
            where  paf.person_id         = paa.person_id
            and    trunc(sysdate)        between paf.effective_start_date and paf.effective_end_date
            and    trunc(sysdate)        between paa.effective_start_date and paa.effective_end_date
            and    paf.employee_number   = l_emp_number;
            
            l_flag := 'Y';
          exception
            when others then
              l_flag := 'N';
          end;
          dbms_output.put_line('----------- ');
          dbms_output.put_line(l_counter||' - ' ||l_flag||' - '||l_emp_number); 
          if l_flag = 'Y' then
            begin
              -- call to api
              hr_assignment_api.update_emp_asg(
                     p_effective_date          => sysdate,
                     p_datetrack_update_mode   => 'CORRECTION',
                     p_assignment_id           => l_ass_id,
                     p_assignment_number       => l_ass_number,
                     p_object_version_number   => l_ovn,                       -- in out
                     p_ass_attribute5          => l_code_atsmon,               -- מנהל עקיף
                     p_soft_coding_keyflex_id  => l_soft_coding_keyflex_id,    -- out number
                     p_comment_id              => l_comment_id,                -- out number
                     p_effective_start_date    => l_assg_effective_start_date, -- out date
                     p_effective_end_date      => l_assg_effective_end_date,   -- out date
                     p_concatenated_segments   => l_concatenated_segments,     -- out varchar2
                     p_no_managers_warning     => l_no_managers_warning,       -- out boolean
                     p_other_manager_warning   => l_other_manager_warning);    -- out boolean
              
              --fnd_file.put_line(fnd_file.log,'SUCCESS');
              dbms_output.put_line('SUCCESS'); 
              commit;
            exception
              when others then
                rollback;
                retcode := 1;
                errbuf  := 'ERROR - ' ||substr(sqlerrm,1,240);
                --fnd_file.put_line(fnd_file.log,'ERROR - ' ||substr(sqlerrm,1,240));
                dbms_output.put_line('ERROR - ' ||substr(sqlerrm,1,240)); 
            end;
          end if; -- l_flag 
        end if; -- l_counter
    
      exception
        when invalid_element then
          null;
        when others then
          retcode := 1;
          errbuf  := 'Gen EXC loop Emp - ' ||l_emp_number||' - '||substr(SQLERRM,1,240);
          --fnd_file.put_line(fnd_file.log,'Gen EXC loop Emp - '||l_emp_number||' - '||substr(SQLERRM,1,240));
          dbms_output.put_line('Gen EXC loop Emp - '||l_emp_number||' - '||substr(SQLERRM,1,240)); 
      end;
    end loop;
    utl_file.fclose(l_file_hundler);
    commit;
  exception  
    when others then
      errbuf  := 'GEN EXC - upload_atsmon_code - '||substr(sqlerrm,1,240);
      retcode := 1;
  end upload_atsmon_code;  
                                
  --------------------------------------------------------------------
  --  name:            upload_zviran_code
  --  create by:       Dalit A. Raviv 
  --  Revision:        1.0 
  --  creation date:   14/03/2012 
  --------------------------------------------------------------------
  --  purpose :        use API to add zviran code to emp assignment
  --------------------------------------------------------------------
  --  ver  date        name             desc
  --  1.0  14/03/2012  Dalit A. Raviv   initial build
  --------------------------------------------------------------------                               
  procedure upload_zviran_code (errbuf        out varchar2,
                                retcode       out varchar2,
                                p_location    in  varchar2, --/UtlFiles/HR
                                p_filename    in  varchar2) is
                             
    l_file_hundler              utl_file.file_type;
    l_line_buffer               varchar2(2000);
    l_counter                   number               := 0;
    l_pos                       number;
    c_delimiter                 constant varchar2(1) := ',';
    
    l_emp_number                per_all_people_f.employee_number%type;
    l_full_name                 per_all_people_f.full_name%type;
    l_dept                      varchar2(100);
    l_code_atsmon               varchar2(50);
    l_flag                      varchar2(5)  := 'Y';
    
    l_ass_id                    per_all_assignments_f.assignment_id%type;
    l_ass_number                per_all_assignments_f.assignment_number%type;
    l_ovn                       per_all_assignments_f.object_version_number%type;  
    l_err_msg                   varchar2(1500);
    
    invalid_element             exception;
  
    l_person_id                 number;  -- DALIT
  begin
    errbuf  := null;
    retcode := 0;
    --fnd_global.APPS_INITIALIZE(user_id => 2470,resp_id =>51597,resp_appl_id => 800);
    -- handle open file to read and handle file exceptions
    begin
      l_file_hundler := utl_file.fopen( location     => p_location,
                                        filename     => p_filename,
                                        open_mode    => 'r',
                                        max_linesize => 32000);
    exception
      when utl_file.invalid_path then  
        retcode := 1;
        errbuf  := 'Import file was failes. 1 Invalid Path for ' || ltrim(p_filename);
        --fnd_file.put_line(fnd_file.log,'Invalid Path for ' || ltrim(p_filename));
        dbms_output.put_line('Invalid Path for ' || ltrim(p_filename)); 
        raise;
      when utl_file.invalid_mode then
        retcode := 1;
        errbuf  := 'Import file was failes. 2 Invalid Mode for ' || ltrim(p_filename);
        --fnd_file.put_line(fnd_file.log,'Invalid Mode for ' || ltrim(p_filename));
        dbms_output.put_line('Invalid Mode for ' || ltrim(p_filename)); 
        raise;
      when utl_file.invalid_operation then
        retcode := 1;
        errbuf  := 'Invalid operation for ' || ltrim(p_filename) ||substr(SQLERRM,1,500);
        --fnd_file.put_line(fnd_file.log,'Invalid operation for ' || ltrim(p_filename) ||SQLERRM);
        dbms_output.put_line('Invalid operation for ' || ltrim(p_filename) ||SQLERRM); 
        raise;
      when others then
        retcode := 1;
        errbuf  := 'Other for ' || ltrim(p_filename)||substr(SQLERRM,1,500);
        --fnd_file.put_line(fnd_file.log,'Other for ' || ltrim(p_filename));
        dbms_output.put_line('Other for ' || ltrim(p_filename)); 
        raise;
    end;
    
    -- start read from file, do needed validation, and upload data to table
    -- Loop For All File's Lines
    loop
      begin
        -- goto next line
        l_counter      := l_counter + 1;
        l_err_msg      := null;
        l_emp_number   := null;
        l_flag         := 'Y';
        l_full_name    := null;
        l_dept         := null;
        l_code_atsmon  := null;
        l_ass_id       := null;
        l_ass_number   := null;
        l_ovn          := null;
        l_person_id    := null;  -- dalit
    
        -- Get Line and handle exceptions
        begin
          utl_file.get_line(file   => l_file_hundler,
                            buffer => l_line_buffer);
        exception
          when utl_file.read_error then
            errbuf := 'Read Error for line: ' || l_counter;
            raise invalid_element;
          when no_data_found then
            exit;
          when others then
            errbuf := 'Read Error for line: ' || l_counter ||', Error: ' || substr(SQLERRM,1,500);
            raise invalid_element;
        end;
        
        -- Get data from line separate by deliminar
        if l_counter > 1 then
          l_pos := 0;
          
          -- Employee number                                        
          l_emp_number    := get_value_from_line(l_line_buffer,
                                                 l_err_msg,
                                                 c_delimiter);
                                                 
          l_full_name     := get_value_from_line(l_line_buffer,
                                                 l_err_msg,
                                                 c_delimiter); 
          
          l_dept          := get_value_from_line(l_line_buffer,
                                                 l_err_msg,
                                                 c_delimiter); 
          
          l_code_atsmon   := get_value_from_line(l_line_buffer,
                                                 l_err_msg,
                                                 c_delimiter);                                 
          -- get assignment details
          -- id + ovn +
          begin
            select paa.assignment_id, paa.assignment_number, paa.object_version_number, paa.person_id
            into   l_ass_id, l_ass_number, l_ovn,l_person_id
            from   per_all_people_f      paf,
                   per_all_assignments_f paa
            where  paf.person_id         = paa.person_id
            and    trunc(sysdate)        between paf.effective_start_date and paf.effective_end_date
            and    trunc(sysdate)        between paa.effective_start_date and paa.effective_end_date
            and    nvl(paf.employee_number,paf.npw_number)   = l_emp_number;
            
            l_flag := 'Y';
          exception
            when others then
              l_flag := 'N';
              dbms_output.put_line(l_counter||' ERROR - ' ||l_flag||' - '||l_emp_number); 
          end;
          dbms_output.put_line('----------- ');
          dbms_output.put_line(l_counter||' - ' ||l_flag||' - '||l_emp_number); 
          if l_flag = 'Y' then
            begin
              -- call to api
              update per_all_assignments_f paa
              set    paa.ass_attribute4    = l_code_atsmon
              where  paa.person_id         = l_person_id
              and    trunc(sysdate)        between paa.effective_start_date and paa.effective_end_date;
             
              --fnd_file.put_line(fnd_file.log,'SUCCESS');
              dbms_output.put_line('SUCCESS'); 
              commit;
            exception
              when others then
                rollback;
                retcode := 1;
                errbuf  := 'ERROR - ' ||substr(sqlerrm,1,240);
                --fnd_file.put_line(fnd_file.log,'ERROR - ' ||substr(sqlerrm,1,240));
                dbms_output.put_line('ERROR - ' ||substr(sqlerrm,1,240)); 
            end;
          end if; -- l_flag 
        end if; -- l_counter
    
      exception
        when invalid_element then
          null;
        when others then
          retcode := 1;
          errbuf  := 'Gen EXC loop Emp - ' ||l_emp_number||' - '||substr(SQLERRM,1,240);
          --fnd_file.put_line(fnd_file.log,'Gen EXC loop Emp - '||l_emp_number||' - '||substr(SQLERRM,1,240));
          dbms_output.put_line('Gen EXC loop Emp - '||l_emp_number||' - '||substr(SQLERRM,1,240)); 
      end;
    end loop;
    utl_file.fclose(l_file_hundler);
    commit;
  exception  
    when others then
      errbuf  := 'GEN EXC - upload_zviran_code - '||substr(sqlerrm,1,240);
      retcode := 1;
  end upload_zviran_code;                                  
  
  --------------------------------------------------------------------
  --  name:            upload_phone_eit
  --  create by:       Dalit A. Raviv 
  --  Revision:        1.0 
  --  creation date:   25/10/2011 
  --------------------------------------------------------------------
  --  purpose :        use API to add Phone EIT to person
  --------------------------------------------------------------------
  --  ver  date        name             desc
  --  1.0  25/10/2011  Dalit A. Raviv   initial build
  -------------------------------------------------------------------- 
  procedure upload_phone_eit(errbuf        out varchar2,
                             retcode       out varchar2,
                             p_location    in  varchar2,     -- /UtlFiles/HR 
                             p_filename    in  varchar2) is  -- US_last2.csv

                            
    l_peii                 number;
    l_person_extra_info_id number;
    l_ovn                  number;
    l_file_hundler         utl_file.file_type;
    l_line_buffer          varchar2(2500);
    l_counter              number               := 0;
    l_pos                  number;
    c_delimiter            constant varchar2(1) := ',';
    
    l_full_name            varchar2(360); -- Full name
    l_emp_number           varchar2(150); -- employee number
    l_cell_phone_num       varchar2(150); -- Cellular Phone Number
    l_cell_model           varchar2(150); -- Cellular Model
    l_cell_limit           varchar2(150); -- Cellular Limit
    l_cell_Family          varchar2(150); -- Cellular Family Pack
    l_cell_ele_charg       varchar2(150); -- Cellular Electric Charger
    l_cell_usb_cable       varchar2(150); -- Cellular USB Cable
    l_car_cell_charge      varchar2(150); -- Car Cellular Charger
    l_car_cell_spiker      varchar2(150); -- Car Cellular Spiker
    l_cell_headphone       varchar2(150); -- Cellular Headphone
    l_cell_others          varchar2(150); -- Others
    l_person_id            number;
    l_flag                 varchar2(2);
    
    l_err_msg              varchar2(1500);
    
    invalid_element        exception;
  begin
  
    errbuf  := 'SUCCESS';
    retcode := 0;
    fnd_global.APPS_INITIALIZE(user_id => 2470,resp_id =>51597,resp_appl_id => 800);
    -- handle open file to read and handle file exceptions
    begin
      l_file_hundler := utl_file.fopen( location     => p_location,
                                        filename     => p_filename,
                                        open_mode    => 'r',
                                        max_linesize => 32000);
    exception
      when utl_file.invalid_path then  
        retcode := 1;
        errbuf  := 'Import file was failes. 1 Invalid Path for ' || ltrim(p_filename);
        --fnd_file.put_line(fnd_file.log,'Invalid Path for ' || ltrim(p_filename));
        dbms_output.put_line('Invalid Path for ' || ltrim(p_filename)); 
        raise;
      when utl_file.invalid_mode then
        retcode := 1;
        errbuf  := 'Import file was failes. 2 Invalid Mode for ' || ltrim(p_filename);
        --fnd_file.put_line(fnd_file.log,'Invalid Mode for ' || ltrim(p_filename));
        dbms_output.put_line('Invalid Mode for ' || ltrim(p_filename)); 
        raise;
      when utl_file.invalid_operation then
        retcode := 1;
        errbuf  := 'Invalid operation for ' || ltrim(p_filename) ||substr(SQLERRM,1,500);
        --fnd_file.put_line(fnd_file.log,'Invalid operation for ' || ltrim(p_filename) ||SQLERRM);
        dbms_output.put_line('Invalid operation for ' || ltrim(p_filename) ||SQLERRM); 
        raise;
      when others then
        retcode := 1;
        errbuf  := 'Other for ' || ltrim(p_filename)||substr(SQLERRM,1,500);
        --fnd_file.put_line(fnd_file.log,'Other for ' || ltrim(p_filename));
        dbms_output.put_line('Other for ' || ltrim(p_filename)); 
        raise;
    end;
    -- start read from file, do needed validation, and upload data to table
    -- Loop For All File's Lines
    loop
      begin
        -- goto next line
        l_counter         := l_counter + 1;
        l_err_msg         := null;
        l_full_name       := null;
        l_emp_number      := null;
        l_cell_phone_num  := null; -- Cellular Phone Number
        l_cell_model      := null; -- Cellular Model
        l_cell_limit      := null; -- Cellular Limit
        l_cell_Family     := null; -- Cellular Family Pack
        l_cell_ele_charg  := null; -- Cellular Electric Charger
        l_cell_usb_cable  := null; -- Cellular USB Cable
        l_car_cell_charge := null; -- Car Cellular Charger
        l_car_cell_spiker := null; -- Car Cellular Spiker
        l_cell_headphone  := null; -- Cellular Headphone
        l_cell_others     := null; -- Others
        l_person_id       := null;
        l_flag            := null;
        
        -- Get Line and handle exceptions
        begin
          utl_file.get_line(file   => l_file_hundler,
                            buffer => l_line_buffer);
        exception
          when utl_file.read_error then
            errbuf := 'Read Error for line: ' || l_counter;
            raise invalid_element;
          when no_data_found then
            exit;
          when others then
            errbuf := 'Read Error for line: ' || l_counter ||', Error: ' || substr(SQLERRM,1,500);
            raise invalid_element;
        end;
        
        -- Get data from line separate by deliminar
        if l_counter > 1 then
          l_pos := 0;

          l_full_name         := get_value_from_line(l_line_buffer,
                                                     l_err_msg,
                                                     c_delimiter);
          -- Employee number                                        
          l_emp_number        := get_value_from_line(l_line_buffer,
                                                     l_err_msg,
                                                     c_delimiter);
                                                 
          l_cell_phone_num    := get_value_from_line(l_line_buffer,
                                                     l_err_msg,
                                                     c_delimiter); 
          
          l_cell_model        := get_value_from_line(l_line_buffer,
                                                     l_err_msg,
                                                     c_delimiter); 
          
          l_cell_limit        := get_value_from_line(l_line_buffer,
                                                     l_err_msg,
                                                     c_delimiter); 
          
          l_cell_Family       := get_value_from_line(l_line_buffer,
                                                     l_err_msg,
                                                     c_delimiter); 
                                                   
          l_cell_ele_charg    := get_value_from_line(l_line_buffer,
                                                     l_err_msg,
                                                     c_delimiter);
                                                     
          l_cell_usb_cable    := get_value_from_line(l_line_buffer,
                                                 l_err_msg,
                                                 c_delimiter);                                                                                                                                     
          
          l_car_cell_charge   := get_value_from_line(l_line_buffer,
                                                     l_err_msg,
                                                     c_delimiter);                                                                                                                                     
          
          l_car_cell_spiker   := get_value_from_line(l_line_buffer,
                                                     l_err_msg,
                                                     c_delimiter);                                                                                                                                     
          
          l_cell_headphone    := get_value_from_line(l_line_buffer,
                                                     l_err_msg,
                                                     c_delimiter);                                                                                                                                     
          
          l_cell_others       := get_value_from_line(l_line_buffer,
                                                     l_err_msg,
                                                     c_delimiter);                                                                                                                                            
          
          dbms_output.put_line('----------- ');
          -- 1) check if this person have PHONE EIT or not
          begin
          
            l_person_id := XXHR_PERSON_PKG.get_person_id (l_emp_number,trunc(sysdate),0,'EMP_NUM');
                                     
            select ph.person_extra_info_id, ph.object_version_number
            into   l_person_extra_info_id, l_ovn
            from   XXHR_CELL_PHONE_EIT_V ph
            where  ph.person_id          = l_person_id; -- p_person_id
          exception
            when others then
            l_person_extra_info_id := null;
          end;
          
          --l_cell_model      := get_lookup_code ('XXHR_CELL_MODEL', l_cell_model);
          --l_car_cell_spiker := get_lookup_code ('XXHR_CELL_CAR_SPIKER', l_car_cell_spiker);
          --l_cell_ele_charg  := XXCONV_HR_PKG.get_lookup_code ('YES_NO', l_cell_ele_charg);
          --l_cell_usb_cable  := XXCONV_HR_PKG.get_lookup_code ('YES_NO', l_cell_usb_cable);
          --l_car_cell_charge := XXCONV_HR_PKG.get_lookup_code ('YES_NO', l_car_cell_charge);
          --l_cell_headphone  := XXCONV_HR_PKG.get_lookup_code ('YES_NO', l_cell_headphone);
          
          if l_cell_phone_num  is null and l_cell_model      is null and nvl(l_cell_limit,0) = 0     and
             l_cell_Family     is null and l_cell_ele_charg  is null and l_cell_usb_cable    is null and
             l_car_cell_charge is null and l_car_cell_spiker is null and l_cell_headphone    is null and
             l_cell_others     is null then
            l_flag := 'N';
          else
            l_flag := 'Y';
          end if;
          
          ----------------------
          -- 2) if exist do update other do create
          begin
            if l_flag = 'Y' then
              
              l_cell_phone_num := '+'||l_cell_phone_num;
              
              if l_person_extra_info_id is null then
                hr_person_extra_info_api.create_person_extra_info
                                          ( p_validate                 => FALSE,
                                            p_person_id                => l_person_id, --1961, --861,
                                            p_information_type         => 'XXHR_CELL_PHONE',
                                            p_pei_information_category => 'XXHR_CELL_PHONE',
                                            p_pei_information1         => l_cell_phone_num,       -- CELLULAR_PHONE
                                            p_pei_information2         => l_cell_model,           -- CELLULAR_MODEL_CODE 
                                            p_pei_information3         => l_cell_limit,           -- CELLULAR_LIMIT
                                            p_pei_information4         => l_cell_Family,          -- CELLULAR_FAMILY_PACK
                                            p_pei_information5         => l_cell_ele_charg,       -- CELLULAR_ELECTRIC_CHARGER
                                            p_pei_information6         => l_cell_usb_cable,       -- CELLULAR_USB_CABLE
                                            p_pei_information7         => l_car_cell_charge,      -- CAR_CELLULAR_CHARGER
                                            p_pei_information8         => l_car_cell_spiker,      -- CAR_CELLULAR_SPIKER_CODE
                                            p_pei_information9         => l_cell_headphone,       -- CELLULAR_HEADPHONE
                                            p_pei_information20        => l_cell_others,          -- OTHERS
                                            p_person_extra_info_id     => l_peii,                 -- o
                                            p_object_version_number    => l_ovn                   -- o 
                                          );
              else
                hr_person_extra_info_api.update_person_extra_info
                                          (p_validate                  => FALSE,-- i b
                                           p_person_extra_info_id      => l_person_extra_info_id, -- i   n
                                           p_object_version_number     => l_ovn,                  -- i/o n
                                           p_pei_information_category  => 'XXHR_CELL_PHONE',      -- i   v 
                                           p_pei_information1          => l_cell_phone_num,       -- i   v
                                           p_pei_information2          => l_cell_model,           -- i   v
                                           p_pei_information3          => l_cell_limit,           -- i   v
                                           p_pei_information4          => l_cell_Family,          -- i   v
                                           p_pei_information5          => l_cell_ele_charg,       -- i   v
                                           p_pei_information6          => l_cell_usb_cable,       -- i   v
                                           p_pei_information7          => l_car_cell_charge,      -- i   v
                                           p_pei_information8          => l_car_cell_spiker,      -- i   v
                                           p_pei_information9          => l_cell_headphone,       -- i   v
                                           p_pei_information20         => l_cell_others           -- i   v
                                          );          
                                   

              end if; -- EIT exists
            end if; -- l_flag
            dbms_output.put_line ('SUCCESS Emp Number - '||l_emp_number);
            commit;
            errbuf  := null;
            retcode := 0;
          exception
            when others then
              rollback;
              retcode := 1;
              errbuf  := 'ERROR - ' ||substr(sqlerrm,1,240);
              dbms_output.put_line ('ERROR Emp Number - '||l_emp_number||' - '||substr(sqlerrm,1,240));
          end;
        end if; -- l_counter
    
      exception
        when invalid_element then
          null;
        when others then
          retcode := 1;
          errbuf  := 'Gen EXC loop Emp EIT- ' ||l_emp_number||' - '||substr(SQLERRM,1,240);
          --fnd_file.put_line(fnd_file.log,'Gen EXC loop Emp - '||l_emp_number||' - '||substr(SQLERRM,1,240));
          dbms_output.put_line('Gen EXC loop Emp EIT- '||l_emp_number||' - '||substr(SQLERRM,1,240)); 
      end;
    end loop;
    utl_file.fclose(l_file_hundler);
    commit;
  exception  
    when others then
      errbuf  := 'GEN EXC - upload_phone_eit - '||substr(sqlerrm,1,240);
      retcode := 1;      
  end upload_phone_eit;
  
  --------------------------------------------------------------------
  --  name:            upload_phone_eit
  --  create by:       Dalit A. Raviv 
  --  Revision:        1.0 
  --  creation date:   25/10/2011 
  --------------------------------------------------------------------
  --  purpose :        use API to add Phone EIT to person
  --------------------------------------------------------------------
  --  ver  date        name             desc
  --  1.0  25/10/2011  Dalit A. Raviv   initial build
  -------------------------------------------------------------------- 
  procedure upload_car_eit(errbuf        out varchar2,
                           retcode       out varchar2,
                           p_location    in  varchar2,    -- /UtlFiles/HR
                           p_filename    in  varchar2) is -- Upload_car_info.csv

                            
    l_peii                 number;
    l_person_extra_info_id number;
    l_ovn                  number;
    l_file_hundler         utl_file.file_type;
    l_line_buffer          varchar2(2000);
    l_counter              number               := 0;
    l_pos                  number;
    c_delimiter            constant varchar2(1) := ',';
    
    l_full_name            varchar2(360); -- Full name
    l_emp_number           varchar2(150); -- employee number
    l_car_number           varchar2(150); -- CAR_NUMBER               1
    l_car_start_date       varchar2(150); -- CAR_START_DATE           2
    l_car_end_date         varchar2(150); -- CAR_END_DATE             14
    l_car_model            varchar2(150); -- CAR_MODEL                3
    l_car_code             varchar2(150); -- CAR_CODE                 4
    l_car_contract         varchar2(150); -- CAR_CONTRACT             5
    l_car_license          varchar2(150); -- CAR_LICENSE              6
    l_car_insurance        varchar2(150); -- CAR_INSURANCE            7
    l_driver_license       varchar2(150); -- DRIVER_LICENSE           8
    l_health_declaration   varchar2(150); -- HEALTH_DECLARATION       9
    l_car_wash             varchar2(150); -- CAR_WASH                 10 
    l_puncture_services    varchar2(150); -- PUNCTURE_SERVICES        11 
    l_passkal              varchar2(150); -- PASSKAL                  12 
    l_parking              varchar2(150); -- PARKING                  13  
    l_car_others           varchar2(150); -- Others                   20
    l_card_num             varchar2(150); -- Card Number              15           
    l_leasing              varchar2(150); -- LEASING_COMPANY          16
    l_old_car              varchar2(150); -- Old Car                  17
    l_flag                 varchar2(2);
    l_person_id            number;
        
    l_err_msg              varchar2(1500);
    
    invalid_element        exception;
  begin
  
    errbuf  := 'SUCCESS';
    retcode := 0;
    fnd_global.APPS_INITIALIZE(user_id => 2470,resp_id =>51597,resp_appl_id => 800);
    -- handle open file to read and handle file exceptions
    begin
      l_file_hundler := utl_file.fopen( location     => p_location,
                                        filename     => p_filename,
                                        open_mode    => 'r',
                                        max_linesize => 32000);
    exception
      when utl_file.invalid_path then  
        retcode := 1;
        errbuf  := 'Import file was failes. 1 Invalid Path for ' || ltrim(p_filename);
        --fnd_file.put_line(fnd_file.log,'Invalid Path for ' || ltrim(p_filename));
        dbms_output.put_line('Invalid Path for ' || ltrim(p_filename)); 
        raise;
      when utl_file.invalid_mode then
        retcode := 1;
        errbuf  := 'Import file was failes. 2 Invalid Mode for ' || ltrim(p_filename);
        --fnd_file.put_line(fnd_file.log,'Invalid Mode for ' || ltrim(p_filename));
        dbms_output.put_line('Invalid Mode for ' || ltrim(p_filename)); 
        raise;
      when utl_file.invalid_operation then
        retcode := 1;
        errbuf  := 'Invalid operation for ' || ltrim(p_filename) ||substr(SQLERRM,1,500);
        --fnd_file.put_line(fnd_file.log,'Invalid operation for ' || ltrim(p_filename) ||SQLERRM);
        dbms_output.put_line('Invalid operation for ' || ltrim(p_filename) ||SQLERRM); 
        raise;
      when others then
        retcode := 1;
        errbuf  := 'Other for ' || ltrim(p_filename)||substr(SQLERRM,1,500);
        --fnd_file.put_line(fnd_file.log,'Other for ' || ltrim(p_filename));
        dbms_output.put_line('Other for ' || ltrim(p_filename)); 
        raise;
    end;
    -- start read from file, do needed validation, and upload data to table
    -- Loop For All File's Lines
    loop
      begin
        -- goto next line
        l_counter             := l_counter + 1;
        l_err_msg             := null;
        l_full_name           := null;
        l_emp_number          := null; -- employee number
        l_car_number          := null; -- CAR_NUMBER               1
        l_car_start_date      := null; -- CAR_START_DATE           2
        l_car_end_date        := null; -- CAR_END_DATE             14
        l_car_model           := null; -- CAR_MODEL                3
        l_car_code            := null; -- CAR_CODE                 4
        l_car_contract        := null; -- CAR_CONTRACT             5
        l_car_license         := null; -- CAR_LICENSE              6
        l_car_insurance       := null; -- CAR_INSURANCE            7
        l_driver_license      := null; -- DRIVER_LICENSE           8
        l_health_declaration  := null; -- HEALTH_DECLARATION       9
        l_car_wash            := null; -- CAR_WASH                 10 
        l_puncture_services   := null; -- PUNCTURE_SERVICES        11 
        l_passkal             := null; -- PASSKAL                  12 
        l_parking             := null; -- PARKING                  13  
        l_car_others          := null; -- Others                   20
        l_card_num            := null; -- Card Number              15           
        l_leasing             := null; -- LEASING_COMPANY          16
        l_old_car             := null; -- Old Car                  17
        l_flag                := 'N';
                
        l_person_id           := null;
        
        -- Get Line and handle exceptions
        begin
          utl_file.get_line(file   => l_file_hundler,
                            buffer => l_line_buffer);
        exception
          when utl_file.read_error then
            errbuf := 'Read Error for line: ' || l_counter;
            raise invalid_element;
          when no_data_found then
            exit;
          when others then
            errbuf := 'Read Error for line: ' || l_counter ||', Error: ' || substr(SQLERRM,1,500);
            raise invalid_element;
        end;
        
        -- Get data from line separate by deliminar
        if l_counter > 1 then
          l_pos := 0;

          -- Employee number  
          l_full_name         := get_value_from_line(l_line_buffer,
                                                     l_err_msg,
                                                     c_delimiter);
                                                                                           
          l_emp_number        := get_value_from_line(l_line_buffer,
                                                     l_err_msg,
                                                     c_delimiter);
                                                 
          l_car_number        := get_value_from_line(l_line_buffer,
                                                     l_err_msg,
                                                     c_delimiter); 
          
          l_car_start_date    := get_value_from_line(l_line_buffer,
                                                     l_err_msg,
                                                     c_delimiter); 
          
          l_car_end_date      := get_value_from_line(l_line_buffer,
                                                     l_err_msg,
                                                     c_delimiter); 
          
          l_car_model         := get_value_from_line(l_line_buffer,
                                                     l_err_msg,
                                                     c_delimiter); 
                                                   
          l_car_code          := get_value_from_line(l_line_buffer,
                                                     l_err_msg,
                                                     c_delimiter);
                                                     
          l_car_contract      := get_value_from_line(l_line_buffer,
                                                 l_err_msg,
                                                 c_delimiter);                                                                                                                                     
          
          l_car_license       := get_value_from_line(l_line_buffer,
                                                     l_err_msg,
                                                     c_delimiter);                                                                                                                                     
          
          l_car_insurance     := get_value_from_line(l_line_buffer,
                                                     l_err_msg,
                                                     c_delimiter);                                                                                                                                     
          
          l_driver_license    := get_value_from_line(l_line_buffer,
                                                     l_err_msg,
                                                     c_delimiter); 
          
          l_health_declaration := get_value_from_line(l_line_buffer,
                                                     l_err_msg,
                                                     c_delimiter); 
          
          l_car_wash          := get_value_from_line(l_line_buffer,
                                                     l_err_msg,
                                                     c_delimiter);                                                                                                                                                                                                                            
          
          l_puncture_services := get_value_from_line(l_line_buffer,
                                                     l_err_msg,
                                                     c_delimiter); 
          
          l_passkal           := get_value_from_line(l_line_buffer,
                                                     l_err_msg,
                                                     c_delimiter); 
          
          l_parking           := get_value_from_line(l_line_buffer,
                                                     l_err_msg,
                                                     c_delimiter); 
                                                     
          l_card_num          := get_value_from_line(l_line_buffer,
                                                     l_err_msg,
                                                     c_delimiter);
                                                     
          l_leasing           := get_value_from_line(l_line_buffer,
                                                     l_err_msg,
                                                     c_delimiter); 
                                                    
          l_old_car           := get_value_from_line(l_line_buffer,
                                                     l_err_msg,
                                                     c_delimiter);                                                                                                             
          
          l_car_others        := get_value_from_line(l_line_buffer,
                                                     l_err_msg,
                                                     c_delimiter);                                                                                                                                            
          
          dbms_output.put_line('----------- ');
          if l_car_number is null and l_car_start_date is null and l_car_end_date is null and
             l_car_model is null and l_car_code is null and l_car_contract is null and
             l_car_license is null and l_car_insurance is null and l_driver_license is null and
             l_health_declaration is null and l_car_wash is null and l_puncture_services is null and 
             l_passkal is null and l_parking is null and l_car_others is null and
             l_card_num is null and l_leasing is null and l_old_car is null then
            l_flag := 'N';
          else
            l_flag := 'Y';
          end if;
          
          if l_flag = 'Y' then
            -- 1) check if this person have PHONE EIT or not
            begin
            
              l_person_id := XXHR_PERSON_PKG.get_person_id (l_emp_number,trunc(sysdate),0,'EMP_NUM');
                                       
              select cp.person_extra_info_id, cp.object_version_number
              into   l_person_extra_info_id, l_ovn
              from   XXHR_CAR_PARKING_EIT_V cp
              where  cp.person_id          = l_person_id; 
            exception
              when others then
              l_person_extra_info_id := null;
            end;
          
            l_car_model := get_lookup_code ('XXHR_CAR_MODEL', l_car_model);
            l_car_start_date := to_char(to_date(l_car_start_date,
                                                'DD/MM/RR HH24:MI:SS'),
                                        'RRRR/MM/DD HH24:MI:SS');
            l_car_end_date   := to_char(to_date(l_car_end_date,
                                                'DD/MM/RR HH24:MI:SS'),
                                        'RRRR/MM/DD HH24:MI:SS');     
            -- 2) if exist do update other do create
            begin
              if l_person_extra_info_id is null then
                hr_person_extra_info_api.create_person_extra_info
                                          ( p_validate                 => FALSE,
                                            p_person_id                => l_person_id, --1961, --861,
                                            p_information_type         => 'XXHR_CAR_PARKING',
                                            p_pei_information_category => 'XXHR_CAR_PARKING',
                                            p_pei_information1         => l_car_number,           -- CAR_NUMBER
                                            p_pei_information2         => l_car_start_date,       -- CAR_START_DATE
                                            p_pei_information14        => l_car_end_date,         -- CAR_END_DATE 
                                            p_pei_information3         => l_car_model,            -- CAR_MODEL
                                            p_pei_information4         => l_car_code,             -- CAR_CODE
                                            p_pei_information5         => l_car_contract,         -- CAR_CONTRACT
                                            p_pei_information6         => l_car_license,          -- CAR_LICENSE
                                            p_pei_information7         => l_car_insurance,        -- CAR_INSURANCE
                                            p_pei_information8         => l_driver_license,       -- DRIVER_LICENSE
                                            p_pei_information9         => l_health_declaration,   -- HEALTH_DECLARATION
                                            p_pei_information10        => l_car_wash,             -- CAR_WASH
                                            p_pei_information11        => l_puncture_services,    -- PUNCTURE_SERVICES
                                            p_pei_information12        => l_passkal,              -- PASSKAL
                                            p_pei_information13        => l_parking,              -- PARKING
                                            p_pei_information15        => l_card_num,             -- Card num
                                            p_pei_information16        => l_leasing,              -- Leasing company
                                            p_pei_information17        => l_old_car,              -- Old Car
                                            p_pei_information20        => l_car_others,           -- OTHERS
                                            p_person_extra_info_id     => l_peii,                 -- o
                                            p_object_version_number    => l_ovn                   -- o 
                                          );
              else
                hr_person_extra_info_api.update_person_extra_info
                                          (p_validate                  => FALSE,-- i b
                                           p_person_extra_info_id      => l_person_extra_info_id, -- i   n
                                           p_object_version_number     => l_ovn,                  -- i/o n
                                           p_pei_information_category  => 'XXHR_CAR_PARKING',     -- i   v 
                                           p_pei_information1          => l_car_number,           -- i   v
                                           p_pei_information2          => l_car_start_date,       -- i   v
                                           p_pei_information14         => l_car_end_date,         -- i   v
                                           p_pei_information3          => l_car_model,            -- i   v
                                           p_pei_information4          => l_car_code,             -- i   v
                                           p_pei_information5          => l_car_contract,         -- i   v
                                           p_pei_information6          => l_car_license,          -- i   v
                                           p_pei_information7          => l_car_insurance,        -- i   v
                                           p_pei_information8          => l_driver_license,       -- i   v
                                           p_pei_information9          => l_health_declaration,   -- i   v
                                           p_pei_information10         => l_car_wash,             -- i   v
                                           p_pei_information11         => l_puncture_services,    -- i   v
                                           p_pei_information12         => l_passkal,              -- i   v
                                           p_pei_information13         => l_parking,              -- i   v
                                           p_pei_information15         => l_card_num,             -- Card num
                                           p_pei_information16         => l_leasing,              -- Leasing company
                                           p_pei_information17         => l_old_car,              -- Old Car
                                           p_pei_information20         => l_car_others            -- i   v
                                          );          
              end if;
              
              dbms_output.put_line ('SUCCESS Emp Number - '||l_emp_number);
              commit;
              errbuf  := null;
              retcode := 0;
            exception
              when others then
                rollback;
                retcode := 1;
                errbuf  := 'ERROR - ' ||substr(sqlerrm,1,240);
                dbms_output.put_line ('ERROR Emp Number - '||l_emp_number||' - '||substr(sqlerrm,1,240));
            end;
            
          else
            dbms_output.put_line('Employee have no car details Emp Number - '||l_emp_number); 
          end if; -- l_flag
        end if; -- l_counter
    
      exception
        when invalid_element then
          null;
        when others then
          retcode := 1;
          errbuf  := 'Gen EXC loop Emp EIT- ' ||l_emp_number||' - '||substr(SQLERRM,1,240);
          --fnd_file.put_line(fnd_file.log,'Gen EXC loop Emp - '||l_emp_number||' - '||substr(SQLERRM,1,240));
          dbms_output.put_line('Gen EXC loop Emp EIT- '||l_emp_number||' - '||substr(SQLERRM,1,240)); 
      end;
    end loop;
    utl_file.fclose(l_file_hundler);
    commit;
  exception  
    when others then
      errbuf  := 'GEN EXC - upload_phone_eit - '||substr(sqlerrm,1,240);
      retcode := 1;      
  end upload_car_eit;
  
  --------------------------------------------------------------------
  --  name:            upload_it_Phones_eit
  --  create by:       Dalit A. Raviv 
  --  Revision:        1.0 
  --  creation date:   28/11/2011 
  --------------------------------------------------------------------
  --  purpose :        use API to add IT Phones EIT to person
  --------------------------------------------------------------------
  --  ver  date        name             desc
  --  1.0  25/10/2011  Dalit A. Raviv   initial build
  -------------------------------------------------------------------- 
  procedure upload_it_Phones_eit(errbuf        out varchar2,
                                 retcode       out varchar2,
                                 p_location    in  varchar2,    -- /UtlFiles/HR
                                 p_filename    in  varchar2) is  -- IT_IL_PHONES.csv    
  l_peii                 number;
    l_person_extra_info_id number;
    l_ovn                  number;
    l_file_hundler         utl_file.file_type;
    l_line_buffer          varchar2(2500);
    l_counter              number               := 0;
    l_pos                  number;
    c_delimiter            constant varchar2(1) := ',';
    
    l_full_name            varchar2(360); -- Full name
    l_emp_number           varchar2(150); -- employee number
    l_office_phone_ext     varchar2(150); -- OFFICE_PHONE_EXTENSION
    l_office_phone_full    varchar2(150); -- OFFICE_PHONE_FULL
    l_office_fax           varchar2(150); -- OFFICE_FAX
    l_person_id            number;
    l_flag                 varchar2(2);
    
    l_err_msg              varchar2(1500);
    
    invalid_element        exception;
  begin
  
    errbuf  := 'SUCCESS';
    retcode := 0;
    fnd_global.APPS_INITIALIZE(user_id => 2470,resp_id =>51597,resp_appl_id => 800);
    -- handle open file to read and handle file exceptions
    begin
      l_file_hundler := utl_file.fopen( location     => p_location,
                                        filename     => p_filename,
                                        open_mode    => 'r',
                                        max_linesize => 32000);
    exception
      when utl_file.invalid_path then  
        retcode := 1;
        errbuf  := 'Import file was failes. 1 Invalid Path for ' || ltrim(p_filename);
        --fnd_file.put_line(fnd_file.log,'Invalid Path for ' || ltrim(p_filename));
        dbms_output.put_line('Invalid Path for ' || ltrim(p_filename)); 
        raise;
      when utl_file.invalid_mode then
        retcode := 1;
        errbuf  := 'Import file was failes. 2 Invalid Mode for ' || ltrim(p_filename);
        --fnd_file.put_line(fnd_file.log,'Invalid Mode for ' || ltrim(p_filename));
        dbms_output.put_line('Invalid Mode for ' || ltrim(p_filename)); 
        raise;
      when utl_file.invalid_operation then
        retcode := 1;
        errbuf  := 'Invalid operation for ' || ltrim(p_filename) ||substr(SQLERRM,1,500);
        --fnd_file.put_line(fnd_file.log,'Invalid operation for ' || ltrim(p_filename) ||SQLERRM);
        dbms_output.put_line('Invalid operation for ' || ltrim(p_filename) ||SQLERRM); 
        raise;
      when others then
        retcode := 1;
        errbuf  := 'Other for ' || ltrim(p_filename)||substr(SQLERRM,1,500);
        --fnd_file.put_line(fnd_file.log,'Other for ' || ltrim(p_filename));
        dbms_output.put_line('Other for ' || ltrim(p_filename)); 
        raise;
    end;
    -- start read from file, do needed validation, and upload data to table
    -- Loop For All File's Lines
    loop
      begin
        -- goto next line
        l_counter           := l_counter + 1;
        l_err_msg           := null;
        l_full_name         := null;
        l_emp_number        := null;
        l_office_phone_ext  := null;
        l_office_phone_full := null;
        l_office_fax        := null;
        l_person_id         := null;
        l_flag              := null;
        
        -- Get Line and handle exceptions
        begin
          utl_file.get_line(file   => l_file_hundler,
                            buffer => l_line_buffer);
        exception
          when utl_file.read_error then
            errbuf := 'Read Error for line: ' || l_counter;
            raise invalid_element;
          when no_data_found then
            exit;
          when others then
            errbuf := 'Read Error for line: ' || l_counter ||', Error: ' || substr(SQLERRM,1,500);
            raise invalid_element;
        end;
        
        -- Get data from line separate by deliminar
        if l_counter > 1 then
          l_pos := 0;

          l_full_name         := get_value_from_line(l_line_buffer,
                                                     l_err_msg,
                                                     c_delimiter);
          -- Employee number                                        
          l_emp_number        := get_value_from_line(l_line_buffer,
                                                     l_err_msg,
                                                     c_delimiter);
          l_office_phone_full := get_value_from_line(l_line_buffer,
                                                     l_err_msg,
                                                     c_delimiter); 
          l_office_phone_ext  := get_value_from_line(l_line_buffer,
                                                     l_err_msg,
                                                     c_delimiter); 
          l_office_fax        := get_value_from_line(l_line_buffer,
                                                     l_err_msg,
                                                     c_delimiter);                                                                                                                                             
          
          dbms_output.put_line('----------- ');
          -- 1) check if this person have IT information EIT or not
          begin
          
            l_person_id := XXHR_PERSON_PKG.get_person_id (l_emp_number,trunc(sysdate),0,'EMP_NUM');
                                     
            select ph.person_extra_info_id, ph.object_version_number
            into   l_person_extra_info_id, l_ovn
            from   xxhr_it_eit_v   ph
            where  ph.person_id    = l_person_id; -- p_person_id
          exception
            when others then
            l_person_extra_info_id := null;
          end;
          
          if (l_office_phone_ext is null and l_office_phone_full is null and l_office_fax is null ) or 
              l_emp_number is null then
            l_flag := 'N';
          else
            l_flag := 'Y';
          end if;
          
          ----------------------
          -- 2) if exist do update other do create
          begin
            if l_flag = 'Y' then
              
              --l_office_phone_ext  := '+'||l_office_phone_ext;
              if l_office_phone_full is not null then
                l_office_phone_full := '+'||l_office_phone_full;
              end if;
              if l_office_fax is not null then
                l_office_fax        := '+'||l_office_fax;
              end if;
              if l_person_extra_info_id is null then
                hr_person_extra_info_api.create_person_extra_info
                                          ( p_validate                 => FALSE,
                                            p_person_id                => l_person_id, --1961, --861,
                                            p_information_type         => 'XXHR_IT',
                                            p_pei_information_category => 'XXHR_IT',
                                            p_pei_information11         => l_office_phone_ext, -- OFFICE_PHONE_EXTENSION
                                            p_pei_information12         => l_office_phone_full,-- OFFICE_PHONE_FULL 
                                            p_pei_information13         => l_office_fax,       -- OFFICE_FAX
                                            p_person_extra_info_id     => l_peii,                 -- o
                                            p_object_version_number    => l_ovn                   -- o 
                                          );
              else
                hr_person_extra_info_api.update_person_extra_info
                                          (p_validate                  => FALSE,-- i b
                                           p_person_extra_info_id      => l_person_extra_info_id, -- i   n
                                           p_object_version_number     => l_ovn,                  -- i/o n
                                           p_pei_information_category  => 'XXHR_IT',              -- i   v 
                                           p_pei_information11         => l_office_phone_ext, -- OFFICE_PHONE_EXTENSION
                                           p_pei_information12         => l_office_phone_full,-- OFFICE_PHONE_FULL 
                                           p_pei_information13         => l_office_fax        -- OFFICE_FAX
                                          );          
                                   

              end if; -- EIT exists
            end if; -- l_flag
            dbms_output.put_line ('SUCCESS Emp Number - '||l_emp_number);
            commit;
            errbuf  := null;
            retcode := 0;
          exception
            when others then
              rollback;
              retcode := 1;
              errbuf  := 'ERROR - ' ||substr(sqlerrm,1,240);
              dbms_output.put_line ('ERROR Emp Number - '||l_emp_number||' - '||substr(sqlerrm,1,240));
          end;
        end if; -- l_counter
    
      exception
        when invalid_element then
          null;
        when others then
          retcode := 1;
          errbuf  := 'Gen EXC loop Emp EIT- ' ||l_emp_number||' - '||substr(SQLERRM,1,240);
          --fnd_file.put_line(fnd_file.log,'Gen EXC loop Emp - '||l_emp_number||' - '||substr(SQLERRM,1,240));
          dbms_output.put_line('Gen EXC loop Emp EIT- '||l_emp_number||' - '||substr(SQLERRM,1,240)); 
      end;
    end loop;
    utl_file.fclose(l_file_hundler);
    commit;
  exception  
    when others then
      errbuf  := 'GEN EXC - upload_it_Phones_eit - '||substr(sqlerrm,1,240);
      retcode := 1;    
  end;
  
  --------------------------------------------------------------------
  --  name:            get_lookup_code
  --  create by:       Dalit A. Raviv 
  --  Revision:        1.0 
  --  creation date:   25/10/2011 
  --------------------------------------------------------------------
  --  purpose :        translate meaning to code
  --------------------------------------------------------------------
  --  ver  date        name             desc
  --  1.0  25/10/2011  Dalit A. Raviv   initial build
  --------------------------------------------------------------------  
  function get_lookup_code (p_lookup_type    in varchar2,
                            p_lookup_meaning in varchar2) return varchar2 is

    l_code varchar2(30) := null;
  begin
    select lookup_code 
    into   l_code
    from   fnd_lookup_values lv
    where  lv.lookup_type    = p_lookup_type
    and    lv.language       = 'US'
    and    meaning           = p_lookup_meaning ;
    
    return l_code;
  exception
    when too_many_rows then
      begin
        select lookup_code 
        into   l_code
        from   fnd_lookup_values lv
        where  lv.lookup_type    = p_lookup_type
        and    lv.language       = 'US'
        and    meaning           = p_lookup_meaning 
        and    rownum            = 1;
      
        return l_code;
      exception
        when others then
          return null;
      end;
    when others then 
      return null;
  end get_lookup_code;
  
  --------------------------------------------------------------------
  --  name:            upd_IT_phone_numbers
  --  create by:       Dalit A. Raviv 
  --  Revision:        1.0 
  --  creation date:   23/08/2012
  --------------------------------------------------------------------
  --  purpose :        update full phone number at person EIT - IT
  --------------------------------------------------------------------
  --  ver  date        name             desc
  --  1.0  23/08/2012  Dalit A. Raviv   initial build
  --------------------------------------------------------------------                            
  procedure upd_IT_phone_numbers (errbuf        out varchar2,
                                  retcode       out varchar2) is
                                 
    cursor pop_c is
      select info.person_extra_info_id      person_extra_info_id,
             info.person_id                 person_id,
             paf.full_name                  full_name,
             nvl(paf.employee_number,paf.npw_number) person_num,
             info.pei_information11         office_phone_extension,
             '+972-74-745'||substr(info.pei_information11,instr(info.pei_information11,'+972-8-931'),length(info.pei_information11)) new_number, 
             info.pei_information12         office_phone_full,
             info.pei_information13         office_fax,
             info.pei_information14,
             info.object_version_number     object_version_number
      from   per_people_extra_info          info,
             per_all_people_f               paf,
             fnd_descr_flex_contexts_vl     dff
      where  info.person_id                 = paf.person_id
      and    trunc(sysdate)                 between paf.effective_start_date and paf.effective_end_date
      and    info.information_type          = 'XXHR_IT'
      and    dff.descriptive_flexfield_name = 'Extra Person Info DDF'
      and    dff.application_id             = 800
      and    info.information_type          = dff.descriptive_flex_context_code
      and    decode(hr_security.view_all,'Y','TRUE',
                    hr_security.show_person(paf.person_id,
                                            paf.current_applicant_flag,
                                            paf.current_employee_flag,
                                            paf.current_npw_flag,
                                            paf.employee_number,
                                            paf.applicant_number,
                                            paf.npw_number)) = 'TRUE'
      AND    decode(hr_general.get_xbg_profile,'Y', paf.business_group_id,
                    hr_general.get_business_group_id) = paf.business_group_id
      and    info.pei_information12 like '+972-8-931%'
      --and    rownum < 2
      order by paf.full_name, info.information_type;
      
     cursor pop_c1 is
      select info.person_extra_info_id      person_extra_info_id,
             info.person_id                 person_id,
             paf.full_name                  full_name,
             nvl(paf.employee_number,paf.npw_number) person_num,
             info.pei_information11         office_phone_extension,
             '+972-74-74541'||substr(info.pei_information11,instr(info.pei_information11,'+972-8-95406'),length(info.pei_information11)) new_number, 
             info.pei_information12         office_phone_full,
             info.pei_information13         office_fax,
             info.pei_information14,
             info.object_version_number     object_version_number
      from   per_people_extra_info          info,
             per_all_people_f               paf,
             fnd_descr_flex_contexts_vl     dff
      where  info.person_id                 = paf.person_id
      and    trunc(sysdate)                 between paf.effective_start_date and paf.effective_end_date
      and    info.information_type          = 'XXHR_IT'
      and    dff.descriptive_flexfield_name = 'Extra Person Info DDF'
      and    dff.application_id             = 800
      and    info.information_type          = dff.descriptive_flex_context_code
      and    decode(hr_security.view_all,'Y','TRUE',
                    hr_security.show_person(paf.person_id,
                                            paf.current_applicant_flag,
                                            paf.current_employee_flag,
                                            paf.current_npw_flag,
                                            paf.employee_number,
                                            paf.applicant_number,
                                            paf.npw_number)) = 'TRUE'
      AND    decode(hr_general.get_xbg_profile,'Y', paf.business_group_id,
                    hr_general.get_business_group_id) = paf.business_group_id
      and    info.pei_information12 like '+972-8-95406%'
      order by paf.full_name, info.information_type;
      
    l_count number := 0;  
  begin
    errbuf  := null;
    retcode := 0;
    -- loop for numbers like '+972-8-931%' 
    dbms_output.put_line('----------------------------- +972-8-931% '); 
    for pop_r in pop_c loop
      begin
        update per_people_extra_info          info
        set    info.pei_information12         = pop_r.new_number
        where  info.person_extra_info_id      = pop_r.person_extra_info_id
        and    info.person_id                 = pop_r.person_id;
        
        commit;
        l_count := l_count +1;
        dbms_output.put_line(l_count||' Emp - '||pop_r.person_num||' - '||pop_r.full_name); 
      exception
        when others then 
          dbms_output.put_line('ERR '||substr(sqlerrm,1,240)); 
      end;
    end loop;
    l_count := 0;
    -- loop fo rnumbers like '+972-8-95406%'
    dbms_output.put_line('----------------------------- +972-8-95406% '); 
    for pop_r in pop_c1 loop
      begin
        update per_people_extra_info          info
        set    info.pei_information12         = pop_r.new_number
        where  info.person_extra_info_id      = pop_r.person_extra_info_id
        and    info.person_id                 = pop_r.person_id;
              
        commit;
        l_count := l_count +1;
        dbms_output.put_line(l_count||' Emp - '||pop_r.person_num||' - '||pop_r.full_name); 
      exception
        when others then 
          dbms_output.put_line('ERR '||substr(sqlerrm,1,240)); 
      end;
    end loop;
  exception
    when others then
      errbuf  := 'ERR - '||substr(sqlerrm,1,240);
      retcode := 1;
  end upd_IT_phone_numbers;
                                                    

end XXCONV_HR_PKG;
/
