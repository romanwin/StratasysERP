create or replace package body xxinv_prod_hierarchy_pkg is
--------------------------------------------------------------------
--  name:            XXINV_PROD_HIERARCHY_PKG
--  create by:       Dalit A. Raviv
--  Revision:        1.0
--  creation date:   12/06/2014 13:05:45
--------------------------------------------------------------------
--  purpose :        CHG0032236 - Item Category Auto assign - Product Hierarchy
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  12/06/2014  Dalit A. Raviv    initial build
--------------------------------------------------------------------
  
  g_user_id              number := nvl(fnd_profile.value('USER_ID'), 2470);

  g_organization_id     number;
  g_forecast_name       varchar2(20);
  /*TYPE t_ph_details_rec IS RECORD(
         entity_id               number,
         batch_id                number,
         program_date            date,
         bom_expl_run_date       date,
         -- parameters
         simulation_mode         varchar2(10),  -- param1 Y/N  
         Constrain_lob           varchar2(150), -- param2
         Constrain_lob_threshold number,        -- param3
         Common_threshold        number,        -- param4
         --        
         comp_item_id            number,
         comp_quantity_extended  number,
         fcst_qty                number,
         qty_for_calculation     number,
         fg_line_of_business     varchar2(150), -- seg1
         fg_product_line         varchar2(150), -- seg2
         fg_product_family       varchar2(150), -- seg3
         fg_sub_family           varchar2(150), -- seg4
         fg_specialty_flavor     varchar2(150), -- seg5
         sum_qty_per_comp        number,
         sum_per_seg1            number,
         sp_seg2                 number,
         sp_seg3                 number,
         sp_seg4                 number,
         sp_seg5                 number);*/

  type t_ph_assign_rec IS RECORD(
         entity_id                 number,
         batch_id                  number,
         program_date              date,
         bom_expl_run_date         date,
         -- parameters
         simulation_mode           varchar2(10),  -- param1 Y/N if to run program in simulation mode or to update. 
         Constrain_lob             varchar2(150), -- param2
         Constrain_lob_threshold   number,        -- param3
         Common_threshold          number,        -- param4        
         --
         inv_org_id                number,        -- 
         component_id              number,        -- inventory_item_id
         fg_top_assembly_id        number,        -- top_assembly_id
         fcst_qty                  number,
         -- FG info (top_assembly)
         fg_line_of_busines_old    varchar2(150), -- fg_segment1
         fg_product_line_old       varchar2(150), -- fg_segment2 
         fg_product_family_old     varchar2(150), -- fg_segment3 
         fg_sub_family_old         varchar2(150), -- fg_segemnt4 
         fg_specialty_flavor_old   varchar2(150), -- fg_segment5 
         fg_technology_old         varchar2(150), -- fg_segment6
         fg_item_type_old          varchar2(150), -- fg_segment7 
         -- component
         comp_quantity_extended    number,
         comp_required_qty         number,
         comp_line_of_business_old varchar2(150), -- comp_segmemt1
         comp_product_line_old     varchar2(150), -- comp_segmnet2
         comp_product_family_old   varchar2(150), -- comp_segment3
         comp_sub_family_old       varchar2(150), -- comp_segment4
         comp_specialty_flavor_old varchar2(150), -- comp_segment5
         comp_technology_old       varchar2(150), -- comp_segment6
         comp_item_type_old        varchar2(150), -- comp_segment7
         comp_line_of_business_new varchar2(150), -- comp_segment1 
         comp_product_line_new     varchar2(150), -- comp_segment2 
         comp_product_family_new   varchar2(150), -- comp_segment3 
         comp_sub_family_new       varchar2(150), -- comp_segment4 
         comp_specialty_flavor_new varchar2(150), -- comp_segment5 
         comp_total_required_qty   number,
         sum_per_line_of_business  number,
         sum_per_product_line      number,
         sum_per_product_family    number,
         sum_per_sub_family        number,
         sum_per_specialty_flavor  number,
         log_code                  varchar2(100),
         log_message               varchar2(1000),
         trx_id                    number,
         last_update_date  	       date,
         last_updated_by    	     number,
         last_update_login  	     number,
         creation_date      	     date,
         created_by         	     number
         ); 
         
  type t_conv_cat_rec IS RECORD(         
         trans_to_int_code   varchar2(3),
         trans_to_int_error  varchar2(250),
         structure_code      varchar2(240), 
         segment1            varchar2(150),  
         description1        varchar2(240), 
         segment2            varchar2(150), 
         description2        varchar2(240),
         segment3            varchar2(150), 
         description3        varchar2(240), 
         segment4            varchar2(150), 
         description4        varchar2(240),
         segment5            varchar2(150), 
         description5        varchar2(240),
         segment6            varchar2(150), 
         description6        varchar2(240),
         segment7            varchar2(150), 
         description7        varchar2(240), 
         segment8            varchar2(150), 
         description8        varchar2(240),
         finish_good_flag    varchar2(1),
         trx_id              number,
         request_id          number,
         item_code           varchar2(30),
         organization_code   varchar2(3),
         category_set_name   varchar2(150), 
         segment9            varchar2(150), 
         segment10           varchar2(150), 
         segment11           varchar2(150), 
         segment12           varchar2(150), 
         segment13           varchar2(150),
         segment14           varchar2(150), 
         segment15           varchar2(150), 
         segment16           varchar2(150), 
         segment17           varchar2(150), 
         segment18           varchar2(150), 
         segment19           varchar2(150), 
         segment20           varchar2(150),  
         category_id         number, 
         source_code         varchar2(150), 
         last_update_date    date,      
         last_updated_by     number,
         last_update_login   number,
         creation_date       date,
         created_by          number); 
  
  --------------------------------------------------------------------
  --  name:            insert_assign
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   12/06/2014 
  --------------------------------------------------------------------
  --  purpose :        Handle insert records into XXINV_PROD_HEIRARCHY_ASSIGN table
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  12/06/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure insert_assign(errbuf          out varchar2,
                          retcode         out varchar2,
                          p_ph_assign_rec in  t_ph_assign_rec ) is
                          
    PRAGMA AUTONOMOUS_TRANSACTION;
  begin
    errbuf   := null;
    retcode  := 0;
    
    -- when call to the procedure retrive sequence nextval
    insert into XXINV_PROD_HIERARCHY_ASSIGN (          
                entity_id,
                batch_id,
                program_date,                -- d
                bom_expl_run_date,           -- d
                -- parameters
                simulation_mode,             -- v(10) 
                Constrain_lob,               -- v(150)
                Constrain_lob_threshold,  
                Common_threshold,         
                --
                inv_org_id,              
                component_id, 
                fg_top_assembly_id,
                fcst_qty,
                -- FG info (top_assembly)
                fg_line_of_busines_old,      -- fg_segment1 v(150)
                fg_product_line_old,         -- fg_segment2 
                fg_product_family_old,       -- fg_segment3 
                fg_sub_family_old ,          -- fg_segemnt4 
                fg_specialty_flavor_old,     -- fg_segment5 
                fg_technology_old,           -- fg_segment6
                fg_item_type_old,            -- fg_segment7 
                -- component
                comp_quantity_extended,
                comp_required_qty,
                comp_line_of_business_old,   -- v(150) Segment1
                comp_product_line_old,       -- v(150) Segment2
                comp_product_family_old,     -- v(150) Segment3
                comp_sub_family_old,         -- v(150) Segment4
                comp_specialty_flavor_old,   -- v(150) Segment5
                comp_technology_old,         -- v(150) Segment6 
                comp_item_type_old,          -- v(150) Segment7
                comp_line_of_business_new,   -- v(150) Segment1
                comp_product_line_new,       -- v(150) Segment2 
                comp_product_family_new,     -- v(150) Segment3 
                comp_sub_family_new,         -- v(150) Segment4 
                comp_specialty_flavor_new,   -- v(150) Segment5 
                comp_total_required_qty,
                sum_per_line_of_business,
                sum_per_product_line,
                sum_per_product_family,
                sum_per_sub_family,
                sum_per_specialty_flavor, 
                log_code,
                log_message,
                trx_id, 
                last_update_date,      
                last_updated_by,
                last_update_login,
                creation_date,
                created_by            
                )
       values  (p_ph_assign_rec.entity_id,
                p_ph_assign_rec.batch_id,
                p_ph_assign_rec.program_date,            -- d
                p_ph_assign_rec.bom_expl_run_date,       -- d
                -- parameters
                p_ph_assign_rec.simulation_mode,         -- v(10) 
                p_ph_assign_rec.Constrain_lob,           -- v(150)
                p_ph_assign_rec.Constrain_lob_threshold,  
                p_ph_assign_rec.Common_threshold,         
                -- FG info (top_assembly)
                p_ph_assign_rec.inv_org_id, 
                p_ph_assign_rec.component_id, 
                p_ph_assign_rec.fg_top_assembly_id,
                p_ph_assign_rec.fcst_qty,
                -- FG info (top_assembly)
                p_ph_assign_rec.fg_line_of_busines_old,   -- v(150) segemnt1 
                p_ph_assign_rec.fg_product_line_old,      -- v(150) segment2 
                p_ph_assign_rec.fg_product_family_old,    -- v(150) segment3 
                p_ph_assign_rec.fg_sub_family_old,        -- v(150) segment4 
                p_ph_assign_rec.fg_specialty_flavor_old,  -- v(150) segment5 
                p_ph_assign_rec.fg_technology_old,        -- v(150) segment6 
                p_ph_assign_rec.fg_item_type_old,         -- v(150) segment7 
                -- component
                p_ph_assign_rec.comp_quantity_extended,
                p_ph_assign_rec.comp_required_qty,
                p_ph_assign_rec.comp_line_of_business_old,-- v(150) segemnt1 
                p_ph_assign_rec.comp_product_line_old,    -- v(150) segemnt2 
                p_ph_assign_rec.comp_product_family_old,  -- v(150) segemnt3 
                p_ph_assign_rec.comp_sub_family_old,      -- v(150) segemnt4
                p_ph_assign_rec.comp_specialty_flavor_old,-- v(150) segemnt5
                p_ph_assign_rec.comp_technology_old,      -- v(150) segemnt6 
                p_ph_assign_rec.comp_item_type_old,       -- v(150) segemnt7 
                p_ph_assign_rec.comp_line_of_business_new,-- v(150) segemnt1 
                p_ph_assign_rec.comp_product_line_new,    -- v(150) segemnt2 
                p_ph_assign_rec.comp_product_family_new,  -- v(150) segemnt3 
                p_ph_assign_rec.comp_sub_family_new,      -- v(150) segemnt4 
                p_ph_assign_rec.comp_specialty_flavor_new,-- v(150) segemnt5 
                p_ph_assign_rec.comp_total_required_qty,
                p_ph_assign_rec.sum_per_line_of_business,
                p_ph_assign_rec.sum_per_product_line,
                p_ph_assign_rec.sum_per_product_family,
                p_ph_assign_rec.sum_per_sub_family,
                p_ph_assign_rec.sum_per_specialty_flavor,  
                p_ph_assign_rec.log_code,
                p_ph_assign_rec.log_message,
                p_ph_assign_rec.trx_id,
                sysdate, g_user_id, -1, sysdate, g_user_id);              
  
    commit;

  exception
    when others then
      errbuf   := 'Gen Exc - insert_assign '||substr(sqlerrm,1,240);
      retcode  := 1; 
  end insert_assign;
        
  --------------------------------------------------------------------
  --  name:            update_assign
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   12/06/2014 
  --------------------------------------------------------------------
  --  purpose :        Handle update records at XXINV_PROD_HEIRARCHY_ASSIGN table
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  12/06/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure update_assign(errbuf          out varchar2,
                          retcode         out varchar2,
                          p_ph_assign_rec in  t_ph_assign_rec ) is
                          
    PRAGMA AUTONOMOUS_TRANSACTION;
  begin
    errbuf   := null;
    retcode  := 0;
    
    update XXINV_PROD_HIERARCHY_ASSIGN
    set    comp_line_of_business_new    = p_ph_assign_rec.comp_line_of_business_new,
           comp_product_line_new        = p_ph_assign_rec.comp_product_line_new,
           comp_product_family_new      = p_ph_assign_rec.comp_product_family_new,
           comp_sub_family_new          = p_ph_assign_rec.comp_sub_family_new,
           comp_specialty_flavor_new    = p_ph_assign_rec.comp_specialty_flavor_new,
           last_update_date             = sysdate,    
           last_updated_by              = g_user_id         
    where  batch_id                     = p_ph_assign_rec.batch_id              
    --and    program_date                 = p_ph_assign_rec.program_date
    and    component_id                 = p_ph_assign_rec.component_id;

    commit;

  exception
    when others then
      errbuf   := 'Gen Exc - update_assign '||substr(sqlerrm,1,240);
      retcode  := 1; 
  end update_assign;
  
  --------------------------------------------------------------------
  --  name:            update_assign_logs
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   22/06/2014 
  --------------------------------------------------------------------
  --  purpose :        Handle update logs at XXINV_PROD_HEIRARCHY_ASSIGN table
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  22/06/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure update_assign_logs(errbuf          out varchar2,
                               retcode         out varchar2,
                               p_ph_assign_rec in  t_ph_assign_rec ) is
                          
    PRAGMA AUTONOMOUS_TRANSACTION;
  begin
    errbuf   := null;
    retcode  := 0;
    
    update XXINV_PROD_HIERARCHY_ASSIGN  v
    set    v.trx_id                     = p_ph_assign_rec.trx_id,
           v.log_code                   = p_ph_assign_rec.log_code,
           v.log_message                = p_ph_assign_rec.log_message,
           last_update_date             = sysdate,    
           last_updated_by              = g_user_id         
    where  batch_id                     = p_ph_assign_rec.batch_id              
    and    component_id                 = p_ph_assign_rec.component_id;

    commit;

  exception
    when others then
      errbuf   := 'Gen Exc - update_assign_logs '||substr(sqlerrm,1,240);
      retcode  := 1; 
  end update_assign_logs;
  
  --------------------------------------------------------------------
  --  name:            delete_history_assign
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   22/06/2014 
  --------------------------------------------------------------------
  --  purpose :        Handle delete XXINV_PROD_HEIRARCHY_ASSIGN table
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  22/06/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure delete_history_assign(errbuf                out varchar2,
                                  retcode               out varchar2,
                                  p_days_to_keep_assign in number) is
                            
    PRAGMA AUTONOMOUS_TRANSACTION;                        
  begin
    errbuf   := null;
    retcode  := 0;
    delete XXINV_PROD_HIERARCHY_ASSIGN v
    where  v.creation_date < sysdate - p_days_to_keep_assign;
        
    commit;
  exception
    when others then
      errbuf   := 'Gen Exc - delete_history_assign '||substr(sqlerrm,1,240);
      retcode  := 1;
      fnd_file.put_line(fnd_file.log,'Err - delete_history_assign '||substr(sqlerrm,1,240));
      dbms_output.put_line('Err - delete_history_assign '||substr(sqlerrm,1,240));   
  end delete_history_assign; 
  
  --------------------------------------------------------------------
  --  name:            delete_history_import
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   22/06/2014 
  --------------------------------------------------------------------
  --  purpose :        Handle delete xxobjt_conv_category table.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  22/06/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure delete_history_import(errbuf                out varchar2,
                                  retcode               out varchar2,
                                  p_day_to_keep_import  in number) is
                            
    PRAGMA AUTONOMOUS_TRANSACTION;                        
  begin
    errbuf   := null;
    retcode  := 0;
    delete xxobjt_conv_category v
    where  v.creation_date < sysdate - p_day_to_keep_import;
    
    commit;
  exception
    when others then
      errbuf   := 'Gen Exc - delete_history_import '||substr(sqlerrm,1,240);
      retcode  := 1; 
      fnd_file.put_line(fnd_file.log,'Err - delete_history_import '||substr(sqlerrm,1,240));
      dbms_output.put_line('Err - delete_history_import '||substr(sqlerrm,1,240));  
  end delete_history_import;                             
  
  /*--------------------------------------------------------------------
  --  name:            insert_details
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   12/06/2014 
  --------------------------------------------------------------------
  --  purpose :        Handle insert records into XXINV_PROD_HEIRARCHY_DETAILS table
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  12/06/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure insert_details (errbuf            out varchar2,
                            retcode           out varchar2,
                            p_ph_details_rec  in  t_ph_details_rec) is
   
  PRAGMA AUTONOMOUS_TRANSACTION;
  
  begin
    errbuf   := null;
    retcode  := 0;
    
    insert into XXINV_PROD_HEIRARCHY_DETAILS
                (entity_id,
                 batch_id,
                 program_date,           -- d
                 bom_expl_run_date,      -- d
                 -- parameters
                 simulation_mode,        -- v(10)
                 Constrain_lob,          -- v(150)
                 Constrain_lob_threshold,   
                 Common_threshold,  
                 --        
                 comp_item_id,
                 comp_quantity_extended,
                 fcst_qty,
                 qty_for_calculation,
                 fg_line_of_business,    -- v(150) seg1
                 fg_product_line,        -- v(150) seg2
                 fg_product_family,      -- v(150) seg3
                 fg_sub_family,          -- v(150) seg4
                 fg_specialty_flavor,    -- v(150) seg5
                 sum_qty_per_comp,
                 sum_per_seg1,
                 sp_seg2,
                 sp_seg3,
                 sp_seg4,
                 sp_seg5,
                 last_update_date,
                 last_updated_by,
                 last_update_login,
                 creation_date,
                 created_by)
    values      (p_ph_details_rec.entity_id,
                 p_ph_details_rec.batch_id,
                 p_ph_details_rec.program_date,           -- d
                 p_ph_details_rec.bom_expl_run_date,      -- d
                 -- parameters
                 p_ph_details_rec.simulation_mode,        -- v(10)
                 p_ph_details_rec.Constrain_lob,          -- v(150)
                 p_ph_details_rec.Constrain_lob_threshold,   
                 p_ph_details_rec.Common_threshold,  
                 --        
                 p_ph_details_rec.comp_item_id,
                 p_ph_details_rec.comp_quantity_extended,
                 p_ph_details_rec.fcst_qty,
                 p_ph_details_rec.qty_for_calculation,
                 p_ph_details_rec.fg_line_of_business,    -- v(150) seg1
                 p_ph_details_rec.fg_product_line,        -- v(150) seg2
                 p_ph_details_rec.fg_product_family,      -- v(150) seg3
                 p_ph_details_rec.fg_sub_family,          -- v(150) seg4
                 p_ph_details_rec.fg_specialty_flavor,    -- v(150) seg5
                 p_ph_details_rec.sum_qty_per_comp,
                 p_ph_details_rec.sum_per_seg1,
                 p_ph_details_rec.sp_seg2,
                 p_ph_details_rec.sp_seg3,
                 p_ph_details_rec.sp_seg4,
                 p_ph_details_rec.sp_seg5,
                 sysdate, g_user_id, -1, sysdate, g_user_id);         
    commit;

  exception
    when others then
      errbuf   := 'Gen Exc - insert_details '||substr(sqlerrm,1,240);
      retcode  := 1; 
  end insert_details;
   */
  --------------------------------------------------------------------
  --  name:            calc_line_of_business
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   15/06/2014 13:05:45
  --------------------------------------------------------------------
  --  purpose :        Handle segment1 calculation logic  
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  15/06/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure calc_line_of_business(errbuf                    out varchar2,
                                  retcode                   out varchar2,
                                  p_new_lob                 out varchar2, -- segment1
                                  p_component_id            in  number,
                                  p_constrain_lob           in  varchar2, 
                                  p_constrain_lob_threshold in  number
                                  )is
    cursor details_c (p_component_id in number) is
      select a_view.comp_item_id,
             sum(a_view.comp_required_qty) sum_qty,
             a_view.segment1,
             a_view.total_per_comp,
             trunc((sum(a_view.comp_required_qty) / a_view.total_per_comp) * 100 ,2) percentage
      from   (select v.comp_item_id, 
                     v.comp_required_qty,                              -- comp_quantity_extended * fcst_qty
                     v.fg_line_of_business                             segment1,
                     sum (v.comp_required_qty) over (PARTITION BY v.comp_item_id) total_per_comp
              from   xxinv_prod_hierarchy_data_v v
              where  v.comp_item_id    = p_component_id --19232
              and    v.organization_id = g_organization_id
              and    v.Fcst_Name       = g_forecast_name 
             ) a_view
      group by a_view.comp_item_id, a_view.segment1, a_view.total_per_comp
      order by sum(a_view.comp_required_qty) desc;   

    l_count   number := 0;
    l_new_lob varchar2(150) := null;

  begin
    errbuf  := null;
    retcode := 0;
    for details_r in details_c (p_component_id ) loop
      -- check if the highest qty relate to a line_of_business is not equal to the value in p_constrain_lob parameter
      -- Then return the line_of_business  found with the highest qty
      -- Else chack highest line_of_business found equal to p_constrain_lob check the percentarge in p_constrain_lob_threshold parameter.
      -- if it is highest then the percentage found -> return the next highest line_of_business qty found
      -- else return line_of_business found
      l_count := l_count +1;
      if l_count = 1 then  
        if details_r.segment1 <> p_constrain_lob then
          l_new_lob := details_r.segment1;
          exit;
        else
          if details_r.percentage >= p_constrain_lob_threshold then
            l_new_lob := details_r.segment1;
            exit;
          end if;-- check param threshold
        end if;-- check param constrain
      end if;-- count
      if l_count = 2 then   
        l_new_lob := details_r.segment1;
        exit;
      end if;
      --l_count := l_count +1;
    end loop;
  
    p_new_lob := l_new_lob;
  
  exception
    when others then
      errbuf   := 'Gen Exc - calc_line_of_business '||substr(sqlerrm,1,240);
      retcode  := 1; 
  end calc_line_of_business;
  
  --------------------------------------------------------------------
  --  name:            calc_product_line
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   15/06/2014 13:05:45
  --------------------------------------------------------------------
  --  purpose :        Handle segment2 calculation logic  
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  15/06/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure calc_product_line(errbuf               out varchar2,
                              retcode              out varchar2,
                              p_new_product_line   out varchar2, -- segment2
                              p_component_id       in  number,
                              p_Common_threshold   in  number
                              ) is
    cursor details_c (p_component_id in number) is
      select a_view.comp_item_id,
             sum(a_view.comp_required_qty) sum_qty,
             a_view.segment2,
             a_view.total_per_comp,
             trunc((sum(a_view.comp_required_qty) / a_view.total_per_comp) * 100 ,2)   percentage
      from   (select v.comp_item_id, 
                     v.comp_required_qty,                                -- comp_quantity_extended * fcst_qty
                     v.fg_product_line                                   segment2,
                     sum (v.comp_required_qty) over (PARTITION BY v.comp_item_id) total_per_comp
              from   xxinv_prod_hierarchy_data_v v
              where  v.comp_item_id    = p_component_id --19232
              and    v.organization_id = g_organization_id
              and    v.Fcst_Name       = g_forecast_name 
             ) a_view
      group by a_view.comp_item_id, a_view.segment2, a_view.total_per_comp
      order by sum(a_view.comp_required_qty) desc;   

    l_new_product_line varchar2(150) := null;

  begin
    errbuf  := null;
    retcode := 0;
    for details_r in details_c (p_component_id ) loop
      -- Check if the highest qty (percentage) relate to product_line is greater or equal to p_Common_threshold parameter  
      -- the value of product_line will return
      -- else return "Common"
      
      if details_r.percentage >= p_Common_threshold then
        l_new_product_line := details_r.segment2;
      else
        l_new_product_line := 'Common';
      end if;
      exit;
    end loop;
  
    p_new_product_line := l_new_product_line;
  
  exception
    when others then
      errbuf   := 'Gen Exc - calc_product_line'||substr(sqlerrm,1,240);
      retcode  := 1; 
  end calc_product_line;
  
  --------------------------------------------------------------------
  --  name:            calc_product_family
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   15/06/2014 13:05:45
  --------------------------------------------------------------------
  --  purpose :        Handle segment3 calculation logic  
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  15/06/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure calc_product_family(errbuf               out varchar2,
                                retcode              out varchar2,
                                p_new_product_family out varchar2, -- segment3
                                p_component_id       in  number,
                                p_Common_threshold   in  number
                                ) is
    cursor details_c (p_component_id in number) is
      select a_view.comp_item_id,
             sum(a_view.comp_required_qty) sum_qty,
             a_view.segment3,
             a_view.total_per_comp,
             trunc((sum(a_view.comp_required_qty) / a_view.total_per_comp) * 100 ,2)   percentage
      from   (select v.comp_item_id, 
                     v.comp_required_qty,                                -- comp_quantity_extended * fcst_qty
                     v.fg_product_family                                 segment3,
                     sum (v.comp_required_qty) over (PARTITION BY v.comp_item_id) total_per_comp
              from   xxinv_prod_hierarchy_data_v v
              where  v.comp_item_id    = p_component_id --19232
              and    v.organization_id = g_organization_id
              and    v.Fcst_Name       = g_forecast_name 
             ) a_view
      group by a_view.comp_item_id, a_view.segment3, a_view.total_per_comp
      order by sum(a_view.comp_required_qty) desc;   

    l_new_product_family varchar2(150) := null;

  begin
    errbuf  := null;
    retcode := 0;
    for details_r in details_c (p_component_id ) loop
      -- Check if the highest qty (percentage) relate to product_family is greater or equal to p_Common_threshold parameter  
      -- the value of product_family will return
      -- else return "Common"
      
      if details_r.percentage >= p_Common_threshold then
        l_new_product_family := details_r.segment3;
      else
        l_new_product_family := 'Common';
      end if;
      exit;
    end loop;
  
    p_new_product_family := l_new_product_family;
  
  exception
    when others then
      errbuf   := 'Gen Exc - calc_product_family'||substr(sqlerrm,1,240);
      retcode  := 1; 
  end calc_product_family;
  
  --------------------------------------------------------------------
  --  name:            calc_sub_family
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   15/06/2014 13:05:45
  --------------------------------------------------------------------
  --  purpose :        Handle segment3 calculation logic  
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  15/06/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure calc_sub_family    (errbuf              out varchar2,
                                retcode             out varchar2,
                                p_new_sub_family    out varchar2, -- segment4
                                p_component_id      in  number,
                                p_Common_threshold  in  number
                                ) is
    cursor details_c (p_component_id in number) is
      select a_view.comp_item_id,
             sum(a_view.comp_required_qty) sum_qty,
             a_view.segment4,
             a_view.total_per_comp,
             trunc((sum(a_view.comp_required_qty) / a_view.total_per_comp) * 100 ,2)   percentage
      from   (select v.comp_item_id, 
                     v.comp_required_qty,                                -- comp_quantity_extended * fcst_qty
                     v.fg_sub_family                                     segment4,
                     sum (v.comp_required_qty) over (PARTITION BY v.comp_item_id) total_per_comp
              from   xxinv_prod_hierarchy_data_v v
              where  v.comp_item_id    = p_component_id --19232
              and    v.organization_id = g_organization_id
              and    v.Fcst_Name       = g_forecast_name 
             ) a_view
      group by a_view.comp_item_id, a_view.segment4, a_view.total_per_comp
      order by sum(a_view.comp_required_qty) desc;   

    l_new_sub_family varchar2(150) := null;

  begin
    errbuf  := null;
    retcode := 0;
    for details_r in details_c (p_component_id ) loop
      -- Check if the highest qty (percentage) relate to sub_family is greater or equal to p_Common_threshold parameter  
      -- the value of sub_family will return
      -- else return "Common"
      
      if details_r.percentage >= p_Common_threshold then
        l_new_sub_family := details_r.segment4;
      else
        l_new_sub_family := 'Common';
      end if;
      exit;
    end loop;
  
    p_new_sub_family := l_new_sub_family;
  
  exception
    when others then
      errbuf   := 'Gen Exc - calc_sub_family'||substr(sqlerrm,1,240);
      retcode  := 1; 
  end calc_sub_family;
  
  --------------------------------------------------------------------
  --  name:            specialty_flavor
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   15/06/2014 13:05:45
  --------------------------------------------------------------------
  --  purpose :        Handle segment3 calculation logic  
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  15/06/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure calc_specialty_flavor(errbuf                 out varchar2,
                                  retcode                out varchar2,
                                  p_new_specialty_flavor out varchar2, -- segment5
                                  p_component_id         in  number,
                                  p_Common_threshold     in  number
                                  ) is
    cursor details_c (p_component_id in number) is
      select a_view.comp_item_id,
             sum(a_view.comp_required_qty) sum_qty,
             a_view.segment5,
             a_view.total_per_comp,
             trunc((sum(a_view.comp_required_qty) / a_view.total_per_comp) * 100 ,2)   percentage
      from   (select v.comp_item_id, 
                     v.comp_required_qty,                                -- comp_quantity_extended * fcst_qty
                     v.fg_specialty_flavor                               segment5,
                     sum (v.comp_required_qty) over (PARTITION BY v.comp_item_id) total_per_comp
              from   xxinv_prod_hierarchy_data_v v
              where  v.comp_item_id    = p_component_id --19232
              and    v.organization_id = g_organization_id
              and    v.Fcst_Name       = g_forecast_name 
             ) a_view
      group by a_view.comp_item_id, a_view.segment5, a_view.total_per_comp
      order by sum(a_view.comp_required_qty) desc;   

    l_new_specialty_flavor varchar2(150) := null;

  begin
    errbuf  := null;
    retcode := 0;
    for details_r in details_c (p_component_id ) loop
      -- Check if the highest qty (percentage) relate to specialty_flavor is greater or equal to p_Common_threshold parameter  
      -- the value of specialty_flavor will return
      -- else return "Common"
      
      if details_r.percentage >= p_Common_threshold then
        l_new_specialty_flavor := details_r.segment5;
      else
        l_new_specialty_flavor := 'Common';
      end if;
      exit;
    end loop;
  
    p_new_specialty_flavor := l_new_specialty_flavor;
  
  exception
    when others then
      errbuf   := 'Gen Exc - calc_specialty_flavor'||substr(sqlerrm,1,240);
      retcode  := 1; 
  end  calc_specialty_flavor;
  
 /* XXOBJT_CONV_CATEGORY
TRX_ID = XXOBJT_CONV_CATEGORY_TRXID_SEQ.nextval
TRANS_TO_INT_CODE = 'N'
REQUEST_ID = fnd_global.conc_request_id

ITEM_CODE
ORGANIZATION_CODE  = OMA
CATEGORY_SET_NAME  = Product Hierarchy
SEGMENT1           = Materials        
SEGMENT2           = Resin
SEGMENT3           = Model
SEGMENT4           = Rigid Opack
SEGMENT5           = VeroBlue
SEGMENT6           = Polyjet
SEGMENT7           = FG
SEGMENT8           to SEGMENT20 null
source_code        = CHG0032236 - Item Category Auto assign - Product Hierarchy
who colomns
  */
  
  --------------------------------------------------------------------
  --  name:            insert_item_category
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   12/06/2014 
  --------------------------------------------------------------------
  --  purpose :        Handle insert records into XXOBJT_CONV_CATEGORY table
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  12/06/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure insert_item_category(errbuf          out varchar2,
                                 retcode         out varchar2,
                                 p_conv_cat_rec  in  t_conv_cat_rec ) is
                          
    PRAGMA AUTONOMOUS_TRANSACTION;
  begin
    errbuf   := null;
    retcode  := 0;
    
    -- when call to the procedure retrive sequence nextval
    insert into XXOBJT_CONV_CATEGORY(          
                trans_to_int_code,
                trans_to_int_error,
                structure_code, 
                segment1, description1, 
                segment2, description2, 
                segment3, description3, 
                segment4, description4, 
                segment5, description5, 
                segment6, description6, 
                segment7, description7, 
                segment8, description8,
                finish_good_flag,
                trx_id,
                request_id,
                item_code,
                organization_code,
                category_set_name, 
                segment9,  segment10, segment11, segment12, segment13, segment14, 
                segment15, segment16, segment17, segment18, segment19, segment20,  
                category_id,
                source_code, 
                last_update_date,      
                last_updated_by,
                last_update_login,
                creation_date,
                created_by            
                )
       values  (p_conv_cat_rec.trans_to_int_code,
                p_conv_cat_rec.trans_to_int_error,
                p_conv_cat_rec.structure_code,
                p_conv_cat_rec.segment1,
                p_conv_cat_rec.description1,
                p_conv_cat_rec.segment2,
                p_conv_cat_rec.description2,
                p_conv_cat_rec.segment3,
                p_conv_cat_rec.description3,
                p_conv_cat_rec.segment4,
                p_conv_cat_rec.description4,
                p_conv_cat_rec.segment5,
                p_conv_cat_rec.description5,
                p_conv_cat_rec.segment6,
                p_conv_cat_rec.description6,
                p_conv_cat_rec.segment7,
                p_conv_cat_rec.description7,
                p_conv_cat_rec.segment8,
                p_conv_cat_rec.description8,
                p_conv_cat_rec.finish_good_flag,
                p_conv_cat_rec.trx_id,
                p_conv_cat_rec.request_id,
                p_conv_cat_rec.item_code,
                p_conv_cat_rec.organization_code,
                p_conv_cat_rec.category_set_name,
                p_conv_cat_rec.segment9,
                p_conv_cat_rec.segment10,
                p_conv_cat_rec.segment11,
                p_conv_cat_rec.segment12,
                p_conv_cat_rec.segment13,
                p_conv_cat_rec.segment14,
                p_conv_cat_rec.segment15,
                p_conv_cat_rec.segment16,
                p_conv_cat_rec.segment17,
                p_conv_cat_rec.segment18,
                p_conv_cat_rec.segment19,
                p_conv_cat_rec.segment20,
                p_conv_cat_rec.category_id, 
                p_conv_cat_rec.source_code, 
                sysdate, g_user_id, -1, sysdate, g_user_id);              
  
    commit;

  exception
    when others then
      errbuf   := 'Gen Exc - insert_item_category '||substr(sqlerrm,1,240);
      retcode  := 1; 
  end insert_item_category;    
  
  --------------------------------------------------------------------
  --  name:            main
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   12/06/2014 13:05:45
  --------------------------------------------------------------------
  --  purpose :        Handle main program
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  12/06/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure  main (errbuf                    out varchar2,
                   retcode                   out varchar2,
                   p_organization_id         in  number,
                   p_forecast_name           in  varchar2,
                   p_simulation_mode         in  varchar2,
                   p_Constrain_lob           in  varchar2, 
                   p_Constrain_lob_threshold in  number,       
                   p_Common_threshold        in  number,
                   p_days_to_keep_assign     in  number,
                   p_day_to_keep_import      in  number ) is
                   
    cursor get_pop_c is
      select distinct v.comp_item_id 
      from   xxinv_prod_hierarchy_data_v v
      where  v.organization_id = p_organization_id
      and    v.Fcst_Name       = p_forecast_name;
      --where  v.comp_item_id in (859003);  -- for debug
  
    cursor details_c (p_component_id in number) is
      select v.bom_expl_run_date,
             v.organization_id,
             v.top_assembly_item_id,
             v.fcst_qty,
             v.fg_line_of_business,
             v.fg_product_line,
             v.fg_product_family,
             v.fg_sub_family, 
             v.fg_specialty_flavor,
             v.fg_technology, 
             v.fg_item_type,
             v.comp_item_id,
             v.comp_quantity_extended,
             v.comp_required_qty,
             v.comp_line_of_business,
             v.comp_product_line,
             v.comp_product_family,
             v.comp_sub_family,
             v.comp_specialty_flavor,
             v.comp_technology,
             v.comp_item_type,  
             sum (nvl(v.comp_quantity_extended,0) * nvl(v.fcst_qty,0)) over (PARTITION BY v.comp_item_id) total_per_comp,
             sum (nvl(v.comp_quantity_extended,0) * nvl(v.fcst_qty,0)) over (PARTITION BY v.comp_item_id, v.fg_line_of_business) sp_seg1,
             sum (nvl(v.comp_quantity_extended,0) * nvl(v.fcst_qty,0)) over (PARTITION BY v.comp_item_id, v.fg_product_line)     sp_seg2,
             sum (nvl(v.comp_quantity_extended,0) * nvl(v.fcst_qty,0)) over (PARTITION BY v.comp_item_id, v.fg_product_family)   sp_seg3,
             sum (nvl(v.comp_quantity_extended,0) * nvl(v.fcst_qty,0)) over (PARTITION BY v.comp_item_id, v.fg_sub_family)       sp_seg4,
             sum (nvl(v.comp_quantity_extended,0) * nvl(v.fcst_qty,0)) over (PARTITION BY v.comp_item_id, v.fg_specialty_flavor) sp_seg5  -- sp = sum_per
      from   xxinv_prod_hierarchy_data_v v
      where  v.comp_item_id    = p_component_id --19232
      and    v.organization_id = p_organization_id
      and    v.Fcst_Name       = p_forecast_name; 
    
    cursor compare_c (p_component_id in number,
                      p_batch_id     in number) is
    select * 
    from   XXINV_PROD_HIERARCHY_ASSIGN p
    where  p.component_id = p_component_id 
    and    p.batch_id     = p_batch_id;
    --and    p.program_date = p_program_date; --19232
         
    l_err_desc             varchar2(500);
    l_err_code             varchar2(100);
    l_new_lob              varchar2(150); -- seg1
    l_new_product_line     varchar2(150); -- seg2
    l_new_product_family   varchar2(150); -- seg3
    l_new_sub_family       varchar2(150); -- seg4
    l_new_specialty_flavor varchar2(150); -- seg5
    l_ph_assign_rec        t_ph_assign_rec;
    l_program_date         date;
    l_batch_id             number;
    l_upd                  varchar2(10);
    l_conv_cat_rec         t_conv_cat_rec;
    l_request_id           number;
    l_trx_id               number;
    l_technology_old       varchar2(150);
    l_item_type_old        varchar2(150);
    --
    l_to_user_name     varchar2(150)  := null;
    l_cc               varchar2(150)  := null;
    l_bcc              varchar2(150)  := null;
    l_subject          varchar2(360)  := null;
    l_att1_proc        varchar2(150)  := null;
    l_att2_proc        varchar2(150)  := null;
    l_att3_proc        varchar2(150)  := null;
    
  begin
    errbuf   := null;
    retcode  := 0;
    
    delete_history_assign(errbuf                => l_err_desc,            -- o v
                          retcode               => l_err_code,            -- o v
                          p_days_to_keep_assign => p_days_to_keep_assign); -- i n
    
    delete_history_import(errbuf                => l_err_desc,         -- o v
                          retcode               => l_err_code,         -- o v
                          p_day_to_keep_import  => p_day_to_keep_import); -- i n
    -- 1) get general info
    -- Get program date
    l_program_date := sysdate;
    -- get Batch id (unique id for the batch)
    begin
      select XXINV_PROD_HIERARCHY_B_S.Nextval
      into   l_batch_id     
      from dual;
    exception
      when others then
        null;
    end;
    
    g_organization_id  := p_organization_id;
    g_forecast_name    := p_forecast_name;
    
    l_request_id := fnd_global.conc_request_id;
    -- 2) by loop for each component id
    for get_pop_r in get_pop_c loop
      -- 3) enter to table XXINV_PROD_HEIRARCHY_ASSIGN all info by loop
      for details_r in details_c (get_pop_r.comp_item_id) loop
        l_ph_assign_rec := null;
        -- Get entity id (unique id for the record)
        begin
          select XXINV_PROD_HIERARCHY_S.Nextval
          into   l_ph_assign_rec.entity_id     
          from dual;
        exception
          when others then
            null;
        end;
       
        l_ph_assign_rec.batch_id                  := l_batch_id;
        l_ph_assign_rec.program_date              := l_program_date;
        l_ph_assign_rec.bom_expl_run_date         := details_r.bom_expl_run_date;
        l_ph_assign_rec.simulation_mode           := p_simulation_mode;
        l_ph_assign_rec.Constrain_lob             := p_Constrain_lob;
        l_ph_assign_rec.Constrain_lob_threshold   := p_Constrain_lob_threshold;
        l_ph_assign_rec.Common_threshold          := p_Common_threshold;
        l_ph_assign_rec.inv_org_id                := details_r.organization_id;
        l_ph_assign_rec.component_id              := details_r.comp_item_id;
        l_ph_assign_rec.fg_top_assembly_id        := details_r.top_assembly_item_id;
        l_ph_assign_rec.fcst_qty                  := details_r.fcst_qty;
        l_ph_assign_rec.fg_line_of_busines_old    := details_r.fg_line_of_business;
        l_ph_assign_rec.fg_product_line_old       := details_r.fg_product_line;
        l_ph_assign_rec.fg_product_family_old     := details_r.fg_product_family;
        l_ph_assign_rec.fg_sub_family_old         := details_r.fg_sub_family;
        l_ph_assign_rec.fg_specialty_flavor_old   := details_r.fg_specialty_flavor;
        l_ph_assign_rec.fg_technology_old         := details_r.fg_technology;
        l_ph_assign_rec.fg_item_type_old          := details_r.fg_item_type;
        l_ph_assign_rec.comp_quantity_extended    := details_r.comp_quantity_extended;
        l_ph_assign_rec.comp_required_qty         := details_r.comp_required_qty;
        l_ph_assign_rec.comp_line_of_business_old := details_r.comp_line_of_business;
        l_ph_assign_rec.comp_product_line_old     := details_r.comp_product_line;
        l_ph_assign_rec.comp_product_family_old   := details_r.comp_product_family;
        l_ph_assign_rec.comp_sub_family_old       := details_r.comp_sub_family; 
        l_ph_assign_rec.comp_specialty_flavor_old := details_r.comp_specialty_flavor; 
        l_ph_assign_rec.comp_technology_old       := details_r.comp_technology;
        l_ph_assign_rec.comp_item_type_old        := details_r.comp_item_type;
        l_ph_assign_rec.sum_per_line_of_business  := details_r.sp_seg1;
        l_ph_assign_rec.sum_per_product_line      := details_r.sp_seg2;                                     
        l_ph_assign_rec.sum_per_product_family    := details_r.sp_seg3;
        l_ph_assign_rec.sum_per_sub_family        := details_r.sp_seg4;
        l_ph_assign_rec.sum_per_specialty_flavor  := details_r.sp_seg5;
        l_ph_assign_rec.comp_total_required_qty   := details_r.total_per_comp; --total_per_comp;
        
        
        
        l_err_desc                    := null;
        l_err_code                    := 0;
        insert_assign(errbuf          => l_err_desc,        -- o v
                      retcode         => l_err_code,        -- o v
                      p_ph_assign_rec => l_ph_assign_rec ); -- i rec
        
      end loop;
      -- 4) calc new line_of_business - segment1
      l_new_lob            := null;
      l_err_desc           := null;
      l_err_code           := 0;
      calc_line_of_business(errbuf                    => l_err_desc,               -- o v
                            retcode                   => l_err_code,               -- o v
                            p_new_lob                 => l_new_lob,                -- o v segment1
                            p_component_id            => get_pop_r.comp_item_id,   -- i n
                            p_constrain_lob           => p_Constrain_lob,          -- i v 
                            p_constrain_lob_threshold => p_constrain_lob_threshold -- i n
                            );
                            
      -- 5) calc new product_line - segment2
      l_new_product_line   := null;
      l_err_desc           := null;
      l_err_code           := 0;
      calc_product_line    (errbuf                    => l_err_desc,               -- o v
                            retcode                   => l_err_code,               -- o v
                            p_new_product_line        => l_new_product_line,       -- o v segment2
                            p_component_id            => get_pop_r.comp_item_id,   -- i n
                            p_common_threshold        => p_common_threshold        -- i n
                            );
      
      -- 6) calc new product_family - segment3
      l_new_product_family := null;
      l_err_desc           := null;
      l_err_code           := 0;
      calc_product_family  (errbuf                    => l_err_desc,               -- o v
                            retcode                   => l_err_code,               -- o v
                            p_new_product_family      => l_new_product_family,     -- o v segment3
                            p_component_id            => get_pop_r.comp_item_id,   -- i n
                            p_common_threshold        => p_common_threshold        -- i n
                            ); 
      -- 7) calc new sub_family - segment4
      l_new_sub_family     := null;
      l_err_desc           := null;
      l_err_code           := 0;
      calc_sub_family      (errbuf                    => l_err_desc,               -- o v
                            retcode                   => l_err_code,               -- o v
                            p_new_sub_family          => l_new_sub_family,         -- o v
                            p_component_id            => get_pop_r.comp_item_id,   -- i n
                            p_common_threshold        => p_common_threshold        -- i n
                            );
      -- 8) calc new specialty_flavor - segment5
      l_new_specialty_flavor := null;
      l_err_desc           := null;
      l_err_code           := 0;
      calc_specialty_flavor(errbuf                    => l_err_desc,               -- o v
                            retcode                   => l_err_code,               -- o v
                            p_new_specialty_flavor    => l_new_specialty_flavor,   -- o v
                            p_component_id            => get_pop_r.comp_item_id,   -- i n
                            p_common_threshold        => p_common_threshold        -- i n
                            );
                            
      -- 9) Update table XXINV_PROD_HEIRARCHY_ASSIGN with new segemnts values
      l_ph_assign_rec := null;
      l_ph_assign_rec.batch_id                  := l_batch_id;
      l_ph_assign_rec.component_id              := get_pop_r.comp_item_id;
      l_ph_assign_rec.comp_line_of_business_new := l_new_lob;
      l_ph_assign_rec.comp_product_line_new     := l_new_product_line; 
      l_ph_assign_rec.comp_product_family_new   := l_new_product_family;
      l_ph_assign_rec.comp_sub_family_new       := l_new_sub_family;
      l_ph_assign_rec.comp_specialty_flavor_new := l_new_specialty_flavor;      
      
      update_assign(errbuf          => l_err_desc,        -- o v
                    retcode         => l_err_code,        -- o v
                    p_ph_assign_rec => l_ph_assign_rec ); -- i rec                       
          
      -- 10) update item category using oracle API
      if p_simulation_mode = 'N' then
        l_upd := 'N';
        for compare_r in compare_c (get_pop_r.comp_item_id, l_batch_id) loop
          -- chack if category segments old with new need to change
          if ((compare_r.comp_line_of_business_old <> compare_r.comp_line_of_business_new) and compare_r.comp_line_of_business_new is not null) or
             ((compare_r.comp_product_line_old     <> compare_r.comp_product_line_new) and compare_r.comp_product_line_new is not null) or
             ((compare_r.comp_product_family_old   <> compare_r.comp_product_family_new) and compare_r.comp_product_family_new is not null) or
             ((compare_r.comp_sub_family_old       <> compare_r.comp_sub_family_new) and compare_r.comp_sub_family_new is not null) or
             ((compare_r.comp_specialty_flavor_old <> compare_r.comp_specialty_flavor_new) and compare_r.comp_specialty_flavor_new is not null) then
            
            l_upd := 'Y';
            exit;
          end if;
        end loop; 
        -- call the api to update item category
        if l_upd = 'Y' then
          -- 11) insert record to xxobjt_conv_category table
          l_conv_cat_rec := null;
          
          begin
            select XXOBJT_CONV_CATEGORY_TRXID_SEQ.nextval
            into   l_trx_id
            from   dual;
          end;
          begin
            select p.comp_technology_old, p.comp_item_type_old
            into   l_technology_old, l_item_type_old
            from   XXINV_PROD_HIERARCHY_ASSIGN p
            where  p.component_id = get_pop_r.comp_item_id
            and    p.batch_id     = l_batch_id
            and    rownum         = 1;
          exception
            when others then
              l_technology_old := null;
              l_item_type_old  := null;
          end;
          
          l_conv_cat_rec.trx_id            := l_trx_id;
          l_conv_cat_rec.trans_to_int_code := 'N';
          l_conv_cat_rec.request_id        := l_request_id;
          l_conv_cat_rec.item_code         := xxinv_utils_pkg.get_item_segment(get_pop_r.comp_item_id, 91);
          l_conv_cat_rec.organization_code := 'OMA';
          l_conv_cat_rec.category_set_name := 'Product Hierarchy';
          l_conv_cat_rec.segment1          := l_new_lob;
          l_conv_cat_rec.segment2          := l_new_product_line;
          l_conv_cat_rec.segment3          := l_new_product_family;
          l_conv_cat_rec.segment4          := l_new_sub_family;
          l_conv_cat_rec.segment5          := l_new_specialty_flavor;
          l_conv_cat_rec.segment6          := l_technology_old; --details_r.comp_technology;
          l_conv_cat_rec.segment7          := l_item_type_old;  --details_r.comp_item_type;
          l_conv_cat_rec.source_code       := 'CHG0032236 - Item Category Auto assign - Product Hierarchy';
          l_conv_cat_rec.last_update_date  := sysdate;
          l_conv_cat_rec.last_updated_by   := g_user_id;
          l_conv_cat_rec.last_update_login := -1;
          l_conv_cat_rec.creation_date     := sysdate;
          l_conv_cat_rec.created_by        := g_user_id;
          l_err_desc                       := null;
          l_err_code                       := 0; 
          insert_item_category(errbuf          => l_err_desc,       -- o v
                               retcode         => l_err_code,       -- o v
                               p_conv_cat_rec  => l_conv_cat_rec); 
                               
          if l_err_code <> 0 then
            fnd_file.put_line(fnd_file.log,'Failed to update_assign_logs, batch id - '||l_batch_id||' component id - '||get_pop_r.comp_item_id||' - '||substr(l_err_desc,1,500));
            dbms_output.put_line('Failed to update_assign_logs, batch id - '||l_batch_id||' component id - '||get_pop_r.comp_item_id||' - '||substr(l_err_desc,1,240)); 
            l_ph_assign_rec := null;
            l_ph_assign_rec.trx_id       := l_trx_id;
            l_ph_assign_rec.log_code     := l_err_code;
            l_ph_assign_rec.log_message  := substr(l_err_desc,1,500);
            l_ph_assign_rec.component_id := get_pop_r.comp_item_id;
            l_ph_assign_rec.batch_id     := l_batch_id;
            update_assign_logs(errbuf          => l_err_desc,        -- o v
                               retcode         => l_err_code,        -- o v
                               p_ph_assign_rec => l_ph_assign_rec ); -- i rec
          else                     
            -- 12) process the category 
            l_err_desc           := null;
            l_err_code           := 0;
            xxinv_item_classification.import_categories(errbuf         => l_err_desc,       -- o v
                                                        retcode        => l_err_code,       -- o v
                                                        p_request_id   => l_request_id,     -- i n               
                                                        p_create_new_combinations_flag => 'N'); -- i v
            if l_err_code <> '0' then
              fnd_file.put_line(fnd_file.log,'Failed to import_categories, batch id - '||l_batch_id||' component id - '||get_pop_r.comp_item_id||' - '||substr(l_err_desc,1,500));
              dbms_output.put_line('Failed to import_categories, batch id - '||l_batch_id||' component id - '||get_pop_r.comp_item_id||' - '||substr(l_err_desc,1,240)); 
            end if;
            
            -- 13) update XXINV_PROD_HEIRARCHY_ASSIGN table                                           
            l_ph_assign_rec := null;
            l_ph_assign_rec.trx_id       := l_trx_id;
            l_ph_assign_rec.log_code     := l_err_code;
            l_ph_assign_rec.log_message  := substr(l_err_desc,1,500);
            l_ph_assign_rec.component_id := get_pop_r.comp_item_id;
            l_ph_assign_rec.batch_id     := l_batch_id;
            update_assign_logs(errbuf          => l_err_desc,        -- o v
                               retcode         => l_err_code,        -- o v
                               p_ph_assign_rec => l_ph_assign_rec ); -- i rec
                                                        
            if l_err_code <> 0 then
              fnd_file.put_line(fnd_file.log,'Failed to update_assign_logs, batch id - '||l_batch_id||' component id - '||get_pop_r.comp_item_id||' - '||substr(l_err_desc,1,500));
              dbms_output.put_line('Failed to update_assign_logs, batch id - '||l_batch_id||' component id - '||get_pop_r.comp_item_id||' - '||substr(l_err_desc,1,240)); 
            end if; -- update assign log
          end if; -- ins item category
        end if; -- l_upd
      end if; -- p_simulation_mode
    end loop; -- components
    
    ------------------------
    -- 7) send log mail to Carmit  
    if p_simulation_mode = 'N' then
      
      l_to_user_name := nvl(fnd_global.USER_NAME,fnd_profile.value('USER_NAME')); --fnd_profile.value('XXINV_PROD_HIERAR_SEND_MAIL_TO'); -- need to be USERNAME DALIT.RAVIV
      l_cc           := null;--fnd_profile.value('XXINV_PROD_HIERAR_SEND_MAIL_CC'); -- can be several emails devided by - Moni.Canjalli@stratasys.com
      l_bcc          := null; 
      fnd_message.SET_NAME('XXOBJT','XXINV_PROD_HIERAR_SEND_MAIL_SU'); -- Automatic Category Assignment - Program
      l_subject      := fnd_message.get; 
      
      xxobjt_wf_mail.send_mail_body_proc
                    (p_to_role     => l_to_user_name,     -- i v
                     p_cc_mail     => l_cc,               -- i v
                     p_bcc_mail    => l_bcc,              -- i v
                     p_subject     => l_subject,          -- i v
                     p_body_proc   => 'XXINV_PROD_HIERARCHY_PKG.prepare_mail_body/'||l_request_id, -- i v
                     p_att1_proc   => l_att1_proc,        -- i v
                     p_att2_proc   => l_att2_proc,        -- i v
                     p_att3_proc   => l_att3_proc,        -- i v
                     p_err_code    => l_err_code,         -- o n
                     p_err_message => l_err_desc);        -- o v
    end if;     
    
  exception
    when others then
      errbuf   := null;
      retcode  := 0;  
  end main;  
  
  --------------------------------------------------------------------
  --  name:            prepare_mail_body
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   24/06/2014
  --------------------------------------------------------------------
  --  purpose:         procedure taht prepare the CLOB string to attach to
  --                   the mail body that send
  --  In  Params:      p_document_id   - request_id of XXOBJT_CONV_CATEGORY table
  --                   p_display_type  - HTML
  --  Out Params:      p_document      - clob of all data to show
  --                   p_document_type - TEXT/HTML - LOG.HTML
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  24/06/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure prepare_mail_body(p_document_id   in varchar2,
                              p_display_type  in varchar2,
                              p_document      in out clob,
                              p_document_type in out varchar2) is

    cursor pop_c is
      select *
      from   XXOBJT_CONV_CATEGORY x
      where  x.request_id = p_document_id;

    l_tot_items number := 0;
    l_tot_s     number := 0;
    l_tot_e     number := 0;
    l_title     varchar2(150) := null;
  begin
    for pop_r in pop_c loop
      l_tot_items := l_tot_items +1;
      if pop_r.trans_to_int_code = 'S' and pop_r.trans_to_int_error is null then
        l_tot_s := l_tot_s + 1;
      else
        l_tot_e := l_tot_e +1;
      end if;
    end loop;  
    -- Summary Results of, Automatic Category Assignment program
    fnd_message.SET_NAME('XXOBJT','XXINV_PROD_HIERAR_SEND_MAIL_BO'); 
    l_title    := fnd_message.get; 
  
    dbms_lob.createtemporary(p_document,true);

    -- concatenate start message
    dbms_lob.append(p_document,
                    '<HTML>' || '<BODY><FONT color=blue face="Verdana">' ||
                    '<P>Hello,</P>' || '<P> </P>' ||
                    '<P>'||l_title||'</P>');
    -- concatenate table prompts
    dbms_lob.append(p_document,
                    '<div align="left"><TABLE style="COLOR: blue" border=1 cellpadding=8>');
    dbms_lob.append(p_document,
                    '<TR align="left">' ||
                    '<TH> Total Uploaded  </TH>' ||
                    '<TH> Total Success   </TH>' || 
                    '<TH> Total Failed    </TH>' ||
                    '</TR>');
    -- concatenate table values by loop
    -- Put value to HTML table
    dbms_lob.append(p_document,
                    '<TR>' ||
                      '<TD>' || l_tot_items ||'</TD>' ||
                      '<TD>' || l_tot_s ||'</TD>' ||
                      '<TD>' || l_tot_e || '</TD>' ||
                    '</TD>' || '</TR>');

    -- concatenate close table
    dbms_lob.append(p_document, '</TABLE> </div>');
    -- concatenate close tags
    dbms_lob.append(p_document, '<P>Regards,</P>' || '<P>Planning Sysadmin</P></FONT>' || '</BODY></HTML>');

    --set_debug_context('xx_notif_attach_procedure');
    p_document_type := 'TEXT/HTML' || ';name=' || 'LOG.HTML';
    -- dbms_lob.copy(document, bdoc, dbms_lob.getlength(bdoc));
  exception
    when others then
      wf_core.context('XXINV_PROD_HIERARCHY_PKG',
                      'XXINV_PROD_HIERARCHY_PKG.prepare_mail_body',
                      p_document_id,
                      p_display_type);
      raise;
  end prepare_mail_body;                                    
                  
end XXINV_PROD_HIERARCHY_PKG;
/
