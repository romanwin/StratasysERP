create or replace package body XXBOM_GENERAL_PKG is
----------------------------------------------------------------------------------------
--      customization code: CHG0034558 
--      name:               XXBOM_GENERAL_PKG
--      create by:          Dalit A. Raviv
--      $Revision:          1.0 $
--      creation date:      07/05/2015 12:17:47
--      Purpose :           General package for BOM uses
----------------------------------------------------------------------------------------
--  ver   date         name             desc
--  1.0   07/05/2015   Dalit A. Raviv   initial build
----------------------------------------------------------------------------------------
 
  --------------------------------------------------------------------
  --  name:            print_log
  --  create by:       Dalit A. RAviv 
  --  Revision:        1.0
  --  creation date:   10/05/2015
  --------------------------------------------------------------------
  --  purpose :        CHG0034558
  --                   Print message to log
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  10/05/2015  Dalit A. RAviv  CHG0034558  
  --------------------------------------------------------------------
  procedure print_log(p_print_msg varchar2) is
  begin
    if fnd_global.conc_request_id = -1 then  
      dbms_output.put_line(p_print_msg);
    else
      fnd_file.put_line(FND_FILE.LOG,p_print_msg);
    end if;
  end print_log; 
 
  --------------------------------------------------------------------
  --  name:            print_log
  --  create by:       Dalit A. RAviv 
  --  Revision:        1.0
  --  creation date:   10/05/2015
  --------------------------------------------------------------------
  --  purpose :        CHG0034558
  --                   Print message to output
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  10/05/2015  Dalit A. RAviv  CHG0034558
  --------------------------------------------------------------------
  procedure print_out(p_print_msg varchar2) is
  begin
    if fnd_global.conc_request_id = -1 then  
      dbms_output.put_line(p_print_msg);
    else
      fnd_file.put_line(FND_FILE.OUTPUT,p_print_msg);
    end if;
  end print_out;  
  
  ----------------------------------------------------------------------------------------
  --      customization code: CHG0034558 - Restore capability lost due to implementation of Agile
  --      name:               XXBOM_GENERAL_PKG
  --      create by:          Dalit A. Raviv
  --      $Revision:          1.0 $
  --      creation date:      10/05/2015 
  --      Purpose :           copy subinventory and locatior from source assembly to new assembly.
  --                          NOTE - 1) this program work on the first level.
  --                                 2) the main assumption is that the new assembly BOM have no Subinv and Locator info.
  ----------------------------------------------------------------------------------------
  --  ver   date         name             desc
  --  1.0   10/05/2015   Dalit A. Raviv   initial build
  ----------------------------------------------------------------------------------------
  procedure bom_upd_backflush_info(errbuf            out varchar2,
                                   retcode           out varchar2,
                                   p_organization_id in  number,
                                   p_source_assembly in  number,
                                   p_new_assembly    in  number) is
  
    cursor c_source_ass (p_comp_item_id in number) is
      select assembly.assembly_item_id         assembly_item_id,
             msi_ass.segment1                  assembly_item,
             msi_ass.description               assembly_desc,
             assembly.wip_supply_type          ass_wip_supply_type,
             xxobjt_general_utils_pkg.get_lookup_meaning(p_lookup_type      => 'WIP_SUPPLY',
                                                         p_lookup_code      => assembly.wip_supply_type,
                                                         p_description_flag => 'N') ass_supply_type,
             assembly.organization_id          organization_id,
             assembly.bill_sequence_id         bill_sequence_id,
             assembly.implementation_date      implementation_date,
             comp.component_item_id            comp_item_id,
             msi_comp.segment1                 comp_item,
             substr(msi_comp.description,1,40) comp_desc,
             comp.item_num                     item_sequence_number, 
             comp.operation_seq_num            operation_seq_num,
             comp.component_quantity           comp_quantity,
             comp.effectivity_date             effectivity_date,
             comp.implementation_date          comp_implementation_date,
             comp.disable_date                 disable_date,           
             comp.supply_subinventory          supply_subinventory,
             comp.supply_locator_id            supply_locator_id,
             (select concatenated_segments
              from   mtl_item_locations_kfv    loc
              where  organization_id           = assembly.organization_id
              and    inventory_location_id     = comp.supply_locator_id
              and    rownum                    = 1) locator_name,
             comp.supply_type                  comp_wip_supply_type 
      from   bom_inventory_components_v        comp,
             mtl_system_items_b                msi_comp,
             bom_bill_of_materials_v           assembly,
             mtl_system_items_b                msi_ass
      where  assembly_item_id                  = p_source_assembly --in ( 1214729,762441)
      and    assembly.organization_id          = p_organization_id
      and    comp.component_item_id            = p_comp_item_id
      and    msi_comp.inventory_item_id        = comp.component_item_id
      and    msi_comp.organization_id          = xxinv_utils_pkg.get_master_organization_id
      and    assembly.bill_sequence_id         = comp.bill_sequence_id
      and    msi_ass.inventory_item_id         = assembly.assembly_item_id
      and    msi_ass.organization_id           = xxinv_utils_pkg.get_master_organization_id
      and    sysdate                           between comp.effectivity_date and nvl(comp.disable_date, trunc(sysdate +1))
      order by assembly_item_id, item_num;

    cursor c_new_ass is
      select assembly.assembly_item_id         assembly_item_id,
             msi_ass.segment1                  assembly_item,
             msi_ass.description               assembly_decription,
             assembly.wip_supply_type          ass_wip_supply_type,
             xxobjt_general_utils_pkg.get_lookup_meaning(p_lookup_type      => 'WIP_SUPPLY',
                                                         p_lookup_code      => assembly.wip_supply_type,
                                                         p_description_flag => 'N') ass_supply_type,
             assembly.organization_id          organization_id,
             assembly.bill_sequence_id         bill_sequence_id,
             assembly.implementation_date      implementation_date,
             comp.component_item_id            comp_item_id,
             msi_comp.segment1                 comp_item,
             substr(msi_comp.description,1,40) comp_desc,
             comp.item_num                     item_sequence_number, 
             comp.operation_seq_num            operation_seq_num,
             comp.component_quantity           comp_quantity,
             comp.effectivity_date             effectivity_date,
             comp.implementation_date          comp_implementation_date,
             comp.disable_date                 disable_date,           
             comp.supply_subinventory          supply_subinventory,
             comp.supply_locator_id            supply_locator_id,
             (select concatenated_segments
              from   mtl_item_locations_kfv    loc
              where  organization_id           = assembly.organization_id
              and    inventory_location_id     = comp.supply_locator_id
              and    rownum                    = 1) locator_name,
             comp.supply_type                  comp_wip_supply_type 
      from   bom_inventory_components_v        comp,
             mtl_system_items_b                msi_comp,
             bom_bill_of_materials_v           assembly,
             mtl_system_items_b                msi_ass
      where  assembly_item_id                  = p_new_assembly --in ( 1214729,762441)
      and    assembly.organization_id          = p_organization_id
      and    msi_comp.inventory_item_id        = comp.component_item_id
      and    msi_comp.organization_id          = xxinv_utils_pkg.get_master_organization_id
      and    assembly.bill_sequence_id         = comp.bill_sequence_id
      and    msi_ass.inventory_item_id         = assembly.assembly_item_id
      and    msi_ass.organization_id           = xxinv_utils_pkg.get_master_organization_id
      and    sysdate                           between comp.effectivity_date and nvl(comp.disable_date, trunc(sysdate +1))
      order by assembly_item_id, item_num;
    
    -- API input variables
    l_bom_header_rec         Bom_Bo_Pub.bom_head_rec_type           := Bom_Bo_Pub.g_miss_bom_header_rec;
    l_bom_revision_tbl       Bom_Bo_Pub.bom_revision_tbl_type       := Bom_Bo_Pub.g_miss_bom_revision_tbl;
    l_bom_component_tbl      Bom_Bo_Pub.bom_comps_tbl_type          := Bom_Bo_Pub.g_miss_bom_component_tbl;
    l_bom_ref_designator_tbl Bom_Bo_Pub.bom_ref_designator_tbl_type := Bom_Bo_Pub.g_miss_bom_ref_designator_tbl;
    l_bom_sub_component_tbl  Bom_Bo_Pub.bom_sub_component_tbl_type  := Bom_Bo_Pub.g_miss_bom_sub_component_tbl;

    -- API output variables
    x_bom_header_rec         Bom_Bo_Pub.bom_head_rec_type           := Bom_Bo_Pub.g_miss_bom_header_rec;
    x_bom_revision_tbl       Bom_Bo_Pub.bom_revision_tbl_type       := Bom_Bo_Pub.g_miss_bom_revision_tbl;
    x_bom_component_tbl      Bom_Bo_Pub.bom_comps_tbl_type          := Bom_Bo_Pub.g_miss_bom_component_tbl;
    x_bom_ref_designator_tbl Bom_Bo_Pub.bom_ref_designator_tbl_type := Bom_Bo_Pub.g_miss_bom_ref_designator_tbl;
    x_bom_sub_component_tbl  Bom_Bo_Pub.bom_sub_component_tbl_type  := Bom_Bo_Pub.g_miss_bom_sub_component_tbl;
    l_error_table            Error_Handler.Error_Tbl_Type;
    l_output_dir             VARCHAR2(500) :=  null;
    l_debug_filename         VARCHAR2(60)  :=  'bom_upd_Backflush_info.dbg';

    l_return_status          VARCHAR2(1)   := NULL;
    l_msg_count              NUMBER        := 0;
    l_org_code               varchar2(10);
    l_continue               number        := 0;
    l_err_msg                varchar2(2500);
    l_count_all              number        := 0;
    l_count_nulls            number        := 0;
    l_comment                varchar2(1000);  

  begin
    errbuf  := null;
    retcode := 0;
    print_out('------------  '||'|'||RPAD('------------  ',14)||'|'||RPAD('--------  ',10)||'|'
              ||RPAD('------------  ',14)||'|'||RPAD('------------  ',14)||'|'
              ||RPAD('----------------------------  ',30)||'|'||RPAD('--------------------------------------  ',40)||'|'
              ||'--------------------------------------  ');
    print_out(RPAD('Op. Seq. Num  ',14)||'|'||RPAD('Comp Item Num',14)||'|'||RPAD('Comp Qty',10)||'|'
              ||RPAD('Supply Type',14)||'|'||RPAD('Subinventory',14)||'|'
              ||RPAD('Locator',30)||'|'||RPAD('Item Description',40)||'|'
              ||'Message');
    print_out('------------  '||'|'||RPAD('------------  ',14)||'|'||RPAD('--------  ',10)||'|'
              ||RPAD('------------  ',14)||'|'||RPAD('------------  ',14)||'|'
              ||RPAD('----------------------------  ',30)||'|'||RPAD('--------------------------------------  ',40)||'|'
              ||'--------------------------------------  ');
   
    /* for debug */
    -- intiialize applications information
    -- FND_GLOBAL.APPS_INITIALIZE(user_id =>2470 ,resp_id => ,resp_appl_id => );
     
    l_org_code := xxinv_utils_pkg.get_org_code (p_organization_id);
    -- 'Auto Update using BOM API'
    fnd_message.SET_NAME('XXOBJT','XXBOM_BACKFLUSH_INFO_COMMENT');
    l_comment  := fnd_message.get;
    
    for r_new_ass in c_new_ass loop  
      l_count_all := l_count_all + 1;    
      for r_source_ass in c_source_ass (r_new_ass.comp_item_id) loop            
        if r_source_ass.supply_subinventory is null and r_source_ass.supply_locator_id is null then
          l_count_nulls := l_count_nulls + 1; 
          exit;
        end if;
        -- initialize BOM header
        l_bom_header_rec.assembly_item_name := r_new_ass.assembly_item;         
        l_bom_header_rec.organization_code  := l_org_code; 
        l_bom_header_rec.transaction_type   := 'UPDATE';
        l_bom_header_rec.return_status      := NULL; 
      
        -- initialize BOM components
        l_bom_component_tbl (1).organization_code   := l_org_code;                           -- NEED
        l_bom_component_tbl (1).assembly_item_name  := r_new_ass.assembly_item;              -- NEED
        l_bom_component_tbl (1).component_item_name := r_new_ass.comp_item;                  -- NEED
        l_bom_component_tbl (1).start_effective_date:= r_new_ass.effectivity_date;   
        l_bom_component_tbl (1).comments            := l_comment;                            -- 'Auto Update using BOM API';                     
        l_bom_component_tbl (1).item_sequence_number      := r_new_ass.item_sequence_number;
        l_bom_component_tbl (1).operation_sequence_number := r_new_ass.operation_seq_num;    -- NEED
        l_bom_component_tbl (1).transaction_type    := 'UPDATE';                             -- can get CREATE/UPDATE
        l_bom_component_tbl (1).return_status       := NULL;         
        l_bom_component_tbl (1).supply_subinventory := r_source_ass.supply_subinventory;     -- NEED
        l_bom_component_tbl (1).Location_Name       := r_source_ass.locator_name;            -- NEED provide concat segments for locator              
          
        -- initialize error stack for logging errors
        Error_Handler.initialize; 
        bom_bo_pub.process_bom (p_bo_identifier               => 'BOM',
                                p_api_version_number          => 1.0,
                                p_init_msg_list               => TRUE,
                                p_bom_header_rec              => l_bom_header_rec,
                                p_bom_revision_tbl            => l_bom_revision_tbl,
                                p_bom_component_tbl           => l_bom_component_tbl,
                                p_bom_ref_designator_tbl      => l_bom_ref_designator_tbl,
                                p_bom_sub_component_tbl       => l_bom_sub_component_tbl,
                                x_bom_header_rec              => x_bom_header_rec,
                                x_bom_revision_tbl            => x_bom_revision_tbl,
                                x_bom_component_tbl           => x_bom_component_tbl,
                                x_bom_ref_designator_tbl      => x_bom_ref_designator_tbl,
                                x_bom_sub_component_tbl       => x_bom_sub_component_tbl,
                                x_return_status               => l_return_status,
                                x_msg_count                   => l_msg_count,
                                p_debug                       => 'N',
                                p_output_dir                  => l_output_dir,
                                p_debug_filename              => l_debug_filename
                               );
        --fnd_file.put_line(FND_FILE.LOG,'API - component '||r_new_ass.comp_item||' l_return_status '||l_return_status);  
                               
        if (l_return_status <> fnd_api.g_ret_sts_success) then
          error_handler.get_message_list(x_message_list => l_error_table);            
          for i in 1..l_error_table.count loop
            if l_err_msg is null then
              l_err_msg := to_char(i)||':'||l_error_table(i).entity_index||':'||l_error_table(i).table_name||' - '||l_error_table(i).message_text;
            else
              l_err_msg := substr(l_err_msg||', '||to_char(i)||':'||l_error_table(i).entity_index||':'||l_error_table(i).table_name||' - '||l_error_table(i).message_text,1,2000);
            end if;
          end loop;

          print_out(RPAD(r_new_ass.operation_seq_num ,14)||'|'||RPAD(r_new_ass.comp_item,14)||'|'||RPAD(r_new_ass.comp_quantity,10)||'|'
                    ||RPAD(r_new_ass.comp_wip_supply_type,14)||'|'||RPAD(nvl(r_source_ass.supply_subinventory,'.') ,14)||'|'
                    ||RPAD(nvl(r_source_ass.locator_name,'.') ,30)||'|'||RPAD(nvl(r_new_ass.comp_desc,'.'),40)||'|'
                    ||'API ERR - '||l_err_msg);
          rollback;
        else
          print_out(RPAD(r_new_ass.operation_seq_num ,14)||'|'||RPAD(r_new_ass.comp_item,14)||'|'||RPAD(r_new_ass.comp_quantity,10)||'|'
                    ||RPAD(r_new_ass.comp_wip_supply_type,14)||'|'||RPAD(nvl(r_source_ass.supply_subinventory,'.') ,14)||'|'
                    ||RPAD(nvl(r_source_ass.locator_name,'.') ,30)||'|'||RPAD(nvl(r_new_ass.comp_desc,'.'),40)||'|'
                    ||'API Successs'); 
          commit;
        end if;
          
        -- reset variables
        l_err_msg           := null;
        l_msg_count         := null;
        l_return_status     := null;
        l_bom_header_rec    := Bom_Bo_Pub.g_miss_bom_header_rec;
        l_bom_component_tbl := Bom_Bo_Pub.g_miss_bom_component_tbl; 
        l_continue          := 0;     
        exit;
      end loop;-- source 
    end loop;-- component
              
    if l_count_all = 0 then
      print_out('                                  ');
      print_out('                                  ');
      fnd_message.SET_NAME('XXOBJT','XXBOM_BACKFLUSH_INFO_NODATA'); --um
      print_out(fnd_message.get);
    elsif  l_count_nulls =  l_count_all then
      print_out('                                  ');
      print_out('                                  ');
      fnd_message.SET_NAME('XXOBJT','XXBOM_BACKFLUSH_INFO_UPD');
      print_out(fnd_message.get);
    else
      print_out('------------  '||'|'||RPAD('------------  ',14)||'|'||RPAD('--------  ',10)||'|'
              ||RPAD('------------  ',14)||'|'||RPAD('------------  ',14)||'|'
              ||RPAD('----------------------------  ',30)||'|'||RPAD('--------------------------------------  ',40)||'|'
              ||'--------------------------------------  ');
    end if;             
  end bom_upd_Backflush_info;                             
end XXBOM_GENERAL_PKG;
/
