CREATE OR REPLACE PACKAGE BODY xxinv_bom_util_pkg IS

  --------------------------------------------------------------------
  --      customization code: XXINV_BOM_PKG
  --      name:               XXINV_BOM_PKG
  --      create by:          Ida
  --      Revision:           1.1
  --      creation date:      08/03/2006
  ----------------------------------------------------------------------
  --  ver   date         name            desc
  --  1.0   08/03/2006   Ida             initial build
  --  1.1   04/07/2006   Tamara          added Explode_Bom_With_Phantom
  --  1.2   18/07/2006   Noam            update (added Explode_Bom_With_Phantom)
  --  1.3   02.8.2011    yuval tal       scheduale_bom_explode : change p_explode_option to 1 =all
  --  1.4   19.4.2012    yuval tal       scheduale_bom_explode : remove history
  --  1.5   18.08.2013   Vitaly          CR 870 std cost - change hard-coded organization
  --  1.6   11/06/2014   Dalit A. Raviv  Procedure schedule_bom_explode change population logic
  --                                     add new parameter to run bom explode  per assembly
  --  1.7   08/12/2014   Dalit A. Raviv  CHG0033956 - NPI bom report, Procedure schedule_bom_explode
  --                                     add 2 fields: implementation_date, operation_seq_num
  --  2.0   22-04-2018   Roman.W         CHG0041935 - Common BOM at OMA - XXINV_BOM_EXPLODE_HISTORY
  --  2.1   08/03/2018   Roman.W         CHG0041937 - addede procedure "xxinv_bomcopy_casing" called from 
  --                                     concurrent "XXINV_BOMCOPY_CASING / XX: INV XXBOM Copy Bom Casing"
  --                                     Read items data from file and submit concurrent "XXBOMCOPY"
  --  2.2   11/03/2018   Roman.W         CHG0041951 - added procedure "xxinv_bompcmbm_casing" calling from
  --                                     concurrent "XXINV_BOMPCMBM_CASING / XX: INV Create Common Bills Casing".
  --                                     Procedure read data from file and submit concurrent "BOMPCMBM"
  -----------------------------------------------------------------------

  --------------------------------------------------------------------
  -- customization code:cust44
  -- name: Explode_Bom_Phantom
  -- create by: Ida
  -- creation date:  29/11/2005
  --------------------------------------------------------------------
  -- input :
  --------------------------------------------------------------------
  -- process :
  -- ouput   :
  -- depend on :
  --------------------------------------------------------------------
  PROCEDURE explode_bom_phantom(p_assembly_item_id  IN NUMBER,
                                p_id                IN NUMBER,
                                p_revision_date     IN DATE,
                                p_organization_id   IN NUMBER,
                                p_explode_option    IN NUMBER,
                                p_impl_flag         IN NUMBER,
                                p_levels_to_explode IN NUMBER, -- 1,
                                p_bom_or_eng        IN NUMBER, -- 1, --BOM
                                p_module            IN NUMBER, -- 2, -- BOM
                                p_std_comp_flag     IN NUMBER,
                                p_qty               IN NUMBER) IS
  
    v_error_code NUMBER;
    v_err_msg    VARCHAR2(2000);
    v_group_id   NUMBER;
  
    CURSOR explode_phantoms_cur IS
      SELECT b.*
        FROM bom_explosion_temp b, --bom_explosion_temp b,
             mtl_system_items_b msib
       WHERE SYSDATE BETWEEN nvl(b.effectivity_date, SYSDATE - 1) AND
             nvl(b.disable_date, SYSDATE + 1)
         AND b.component_sequence_id IS NOT NULL
         AND b.component_item_id = msib.inventory_item_id
         AND b.organization_id = msib.organization_id
         AND nvl(b.wip_supply_type, msib.wip_supply_type) = 6
         AND b.group_id = v_group_id;
  
  BEGIN
  
    SELECT bom_explosion_temp_s.nextval INTO v_group_id FROM dual;
  
    bompexpl.exploder_userexit(org_id            => p_organization_id,
                               grp_id            => v_group_id,
                               levels_to_explode => p_levels_to_explode, --1
                               bom_or_eng        => p_bom_or_eng, --BOM
                               impl_flag         => p_impl_flag, --implemented only
                               explode_option    => p_explode_option, --All -  IMPORTANT
                               module            => p_module, --1 BOM
                               std_comp_flag     => p_std_comp_flag, -- (1 = only standard), 2 = All
                               expl_qty          => p_qty,
                               item_id           => p_assembly_item_id,
                               rev_date          => to_char(p_revision_date,
                                                            '',
                                                            'YYYY/MM/DD HH24:MI:SS'),
                               err_msg           => v_err_msg,
                               ERROR_CODE        => v_error_code);
  
    FOR phantom IN explode_phantoms_cur LOOP
      dbms_output.put_line(phantom.component_item_id);
      explode_bom_phantom(phantom.component_item_id,
                          p_id,
                          p_revision_date,
                          phantom.organization_id,
                          p_explode_option,
                          p_impl_flag,
                          p_levels_to_explode,
                          p_bom_or_eng,
                          p_module,
                          p_std_comp_flag,
                          phantom.extended_quantity);
    
    END LOOP;
  
  END explode_bom_phantom;

  --------------------------------------------------------------------
  -- customization code:cust44
  -- name: Explode_Bom
  -- create by: Ida
  -- creation date:  29/11/2005
  --------------------------------------------------------------------
  -- input :
  --------------------------------------------------------------------
  -- process :
  -- ouput   :
  -- depend on :
  --------------------------------------------------------------------
  PROCEDURE explode_bom(p_assembly_item_id  IN NUMBER,
                        p_id                IN NUMBER,
                        p_revision_date     IN DATE,
                        p_organization_id   IN NUMBER,
                        p_explode_option    IN NUMBER, -- 1 - All,  2 - Current, 3 - Current and future
                        p_impl_flag         IN NUMBER, -- 1 - implemented only,  2 - both impl and unimpl
                        p_levels_to_explode IN NUMBER, -- 1,
                        p_bom_or_eng        IN NUMBER, -- 1 - BOM, 2 - ENG
                        p_module            IN NUMBER, -- 1 - Costing, 2 - Bom, 3 - Order entry
                        p_std_comp_flag     IN NUMBER, -- 1 - explode only standard components, 2 - all components
                        p_qty               IN NUMBER) IS
  BEGIN
    xxinv_bom_util_pkg.explode_bom_phantom(p_assembly_item_id  => p_assembly_item_id,
                                           p_id                => p_id,
                                           p_revision_date     => p_revision_date,
                                           p_organization_id   => p_organization_id,
                                           p_explode_option    => p_explode_option,
                                           p_impl_flag         => p_impl_flag,
                                           p_levels_to_explode => p_levels_to_explode,
                                           p_bom_or_eng        => p_bom_or_eng,
                                           p_module            => p_module,
                                           p_std_comp_flag     => p_std_comp_flag,
                                           p_qty               => p_qty);
  
    COMMIT;
  
  END explode_bom;

  --------------------------------------------------------------------
  -- customization code:cust
  -- name: Explode_Bom_With_Phantom
  -- create by:
  -- creation date:
  --------------------------------------------------------------------
  -- input :
  --------------------------------------------------------------------
  -- process :
  -- ouput   :
  -- depend on :
  --------------------------------------------------------------------
  PROCEDURE explode_bom_with_phantom(p_assembly_item_id  IN NUMBER,
                                     p_id                IN NUMBER,
                                     p_revision_date     IN DATE,
                                     p_organization_id   IN NUMBER,
                                     p_explode_option    IN NUMBER, -- 1 - All,  2 - Current, 3 - Current and future
                                     p_impl_flag         IN NUMBER, -- 1 - implemented only,  2 - both impl and unimpl
                                     p_levels_to_explode IN NUMBER, -- 1,
                                     p_bom_or_eng        IN NUMBER, -- 1 - BOM, 2 - ENG
                                     p_module            IN NUMBER, -- 1 - Costing, 2 - Bom, 3 - Order entry
                                     p_std_comp_flag     IN NUMBER, -- 1 - explode only standard components, 2 - all components
                                     p_qty               IN NUMBER) IS
  BEGIN
    xxinv_bom_util_pkg.explode_bom_phantom(p_assembly_item_id  => p_assembly_item_id,
                                           p_id                => p_id,
                                           p_revision_date     => p_revision_date,
                                           p_organization_id   => p_organization_id,
                                           p_explode_option    => p_explode_option,
                                           p_impl_flag         => p_impl_flag,
                                           p_levels_to_explode => p_levels_to_explode,
                                           p_bom_or_eng        => p_bom_or_eng,
                                           p_module            => p_module,
                                           p_std_comp_flag     => p_std_comp_flag,
                                           p_qty               => p_qty);
  
    COMMIT;
  
  END explode_bom_with_phantom;

  --------------------------------------------------------------------
  -- customization code:cust44
  -- name: Explode_Bom_no_Phantom
  -- create by: Ida
  -- creation date:  29/11/2005
  --------------------------------------------------------------------
  -- input :
  --------------------------------------------------------------------
  -- process :
  -- ouput   :
  -- depend on :
  --------------------------------------------------------------------
  PROCEDURE explode_bom_no_phantom(p_assembly_item_id IN NUMBER,
                                   --p_id                IN NUMBER,
                                   p_revision_date     IN DATE,
                                   p_organization_id   IN NUMBER,
                                   p_explode_option    IN NUMBER,
                                   p_impl_flag         IN NUMBER,
                                   p_levels_to_explode IN NUMBER, -- 1,
                                   p_bom_or_eng        IN NUMBER, -- 1, --BOM
                                   p_module            IN NUMBER, -- 2, -- BOM
                                   p_std_comp_flag     IN NUMBER,
                                   p_qty               IN NUMBER) IS
  
    v_error_code NUMBER;
    v_err_msg    VARCHAR2(2000);
    v_group_id   NUMBER;
  
  BEGIN
  
    SELECT bom_explosion_temp_s.nextval INTO v_group_id FROM dual;
  
    bompexpl.exploder_userexit(org_id            => p_organization_id,
                               grp_id            => v_group_id,
                               levels_to_explode => p_levels_to_explode, --1
                               bom_or_eng        => p_bom_or_eng, --BOM
                               impl_flag         => p_impl_flag, --implemented only
                               explode_option    => p_explode_option, --All -  IMPORTANT
                               module            => p_module, --1 BOM
                               std_comp_flag     => p_std_comp_flag, -- (1 = only standard), 2 = All
                               expl_qty          => p_qty,
                               item_id           => p_assembly_item_id,
                               rev_date          => to_char(p_revision_date,
                                                            'YYYY/MM/DD HH24:MI:SS'),
                               err_msg           => v_err_msg,
                               ERROR_CODE        => v_error_code);
  
  END explode_bom_no_phantom;

  --------------------------------------------------------------------
  --  name:            scheduale_bom_explode
  --  create by:       XXX
  --  Revision:        1.0
  --  creation date:   xx/xx/xxxx
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  xx/xx/xxxx  XXX               initial build
  --  1.1  11/06/2014  Dalit A. Raviv    change population logic
  --  1.2  04/11/2014  Dalit A. Raviv    Add 2 feilds to the history table,
  --                                     and moved the place of the commit and delete in code for beter performance
  --                                     add new parameter to run bom explode  per assembly
  --  1.3  08/12/2014  Dalit A. Raviv    CHG0033956 - NPI bom report,
  --                                     add 2 fields: implementation_date, operation_seq_num
  --  2.0   08/03/2018   Roman.W         CHG0041935 - Development - Common BOM at OMA - XXINV_BOM_EXPLODE_HISTORY
  --------------------------------------------------------------------
  PROCEDURE scheduale_bom_explode(errbuf             out varchar2,
                                  retcode            out number,
                                  p_assembly_item_id in number) IS
    -----------------------------------------
    --       Local Definitions
    -----------------------------------------
    cursor c_assembly is
    -- Dalit 11/06/2014
      select b.assembly_item_id inventory_item_id, o.organization_id
        from bom.bom_structures_b b, inv.mtl_parameters o
       where b.organization_id = o.organization_id
         and (o.organization_id = 91 or o.primary_cost_method = 1) -- standard
         and (b.assembly_item_id = p_assembly_item_id or
             p_assembly_item_id is null);
  
    --and o.organization_id = 735;
    /*SELECT msi.inventory_item_id, msi.organization_id
     FROM mtl_system_items_b msi
    WHERE nvl(msi.enabled_flag, 'N') = 'Y'
      AND organization_id IN (735 ); -- 735 IPK, 734 IRK*/
  
    cursor c_explode is
      select * from bom_explosion_temp t order by t.sort_order;
  
    l_batch_id  NUMBER;
    l_recipient VARCHAR2(500);
  
    l_top_level_ass_part_number varchar2(50);
    l_comp_part_number          varchar2(500);
    type xx is table of varchar2(500) index by varchar2(500);
    type number_arr is table of number index by binary_integer;
  
    l_item_arr              xx;
    l_last_po_rcv_price_arr number_arr;
    l_last_po_last_price    number_arr;
    --l_make_buy_arr          number_arr;
    l_make_buy_arr          xx;
    l_get_last_rcv_po_price number;
    l_comp_last_po_price    number;
    l_exlude_flag           varchar2(1);
    l_make_buy              number;
    -----------------------------------------
    --       Code Section
    -----------------------------------------
  begin
    retcode := '0';
    errbuf  := 'Completed successfully';
    -- RAISE no_data_found;
  
    -- rem by R.W. CHG0041935    
    --fnd_global.apps_initialize(user_id      => 3850,
    --                           resp_id      => 50877,
    --                          resp_appl_id => 201);
  
    select xxinv_bom_explode_history_seq.nextval into l_batch_id from dual;
  
    -- Dalit A. Raviv 11/06/2014
    -- to delete this delete and commit. move it into the loop.
    /*DELETE FROM xxinv_bom_explode_history t;
    COMMIT;*/
  
    for j in c_assembly loop
      /*-- Dalit A. Raviv 04/11/2014
      DELETE FROM xxinv_bom_explode_history t
      where  t.top_assembly_item_id = j.inventory_item_id
      and    t.organization_id      = j.organization_id;*/
    
      l_top_level_ass_part_number := xxinv_utils_pkg.get_item_segment(j.inventory_item_id,
                                                                      j.organization_id);
    
      -- Call the procedure
      xxinv_bom_util_pkg.explode_bom_no_phantom(p_assembly_item_id => j.inventory_item_id,
                                                --p_id                => l_batch_id,
                                                p_revision_date     => SYSDATE,
                                                p_organization_id   => j.organization_id,
                                                p_explode_option    => 1, --1 all --3, --2,
                                                p_impl_flag         => 1,
                                                p_levels_to_explode => 50,
                                                p_bom_or_eng        => 1,
                                                p_module            => 1,
                                                p_std_comp_flag     => 0,
                                                p_qty               => 1);
    
      -- Dalit A. Raviv 04/11/2014
      --COMMIT;
      delete from xxinv_bom_explode_history t
       where t.top_assembly_item_id = j.inventory_item_id
         and t.organization_id = j.organization_id;
    
      for t in c_explode loop
        --------------------------------------------------------
        ------------------ cache  -----------------------------
        --------------------------------------------------------
        -- l_comp_part_number
        begin
          l_comp_part_number := l_item_arr(t.component_item_id || '-' ||
                                           t.organization_id);
        exception
          when no_data_found then
            l_comp_part_number := xxinv_utils_pkg.get_item_segment(t.component_item_id,
                                                                   t.organization_id);
            l_item_arr(t.component_item_id || '-' || t.organization_id) := l_comp_part_number;
        end;
      
        -- l_get_last_rcv_po_price
        begin
          l_get_last_rcv_po_price := l_last_po_rcv_price_arr(t.component_item_id);
        exception
          when no_data_found then
            l_get_last_rcv_po_price := round(xxpo_utils_pkg.get_last_rcv_po_price(t.component_item_id,
                                                                                  sysdate),
                                             2);
            l_last_po_rcv_price_arr(t.component_item_id) := l_get_last_rcv_po_price;
        end;
      
        -- l_comp_last_po_price
        begin
          l_comp_last_po_price := l_last_po_last_price(t.component_item_id);
        exception
          when no_data_found then
            l_comp_last_po_price := round(xxpo_utils_pkg.get_last_po_price(t.component_item_id,
                                                                           sysdate),
                                          2);
            l_last_po_last_price(t.component_item_id) := l_comp_last_po_price;
        end;
      
        ----------- MAKE_BUY_CACHE
        -- l_comp_last_po_price
        begin
          l_make_buy := l_make_buy_arr(t.component_item_id || '-' ||
                                       t.organization_id);
        exception
          when no_data_found then
            l_make_buy := xxinv_utils_pkg.get_item_make_buy_code(t.component_item_id,
                                                                 t.organization_id);
            l_make_buy_arr(t.component_item_id || '-' || t.organization_id) := l_make_buy;
        end;
      
        begin
          IF l_make_buy_arr(t.assembly_item_id || '-' || t.organization_id) = 2 THEN
            -- buy=2
            l_exlude_flag := 'Y';
          else
            l_exlude_flag := 'N';
          end if;
        exception
          when others then
            l_exlude_flag := 'N';
        end;
      
        -------------------------------------------
        insert into xxinv_bom_explode_history
          (batch_id,
           creation_date,
           plan_level,
           component_code,
           sort_order,
           top_level_assembly_part_number,
           top_assembly_item_id,
           direct_assembly_part_number,
           direct_assembly_item_id,
           comp_part_number,
           comp_item_id,
           comp_material_cost,
           comp_item_cost,
           comp_last_po_rcv_price,
           comp_last_po_price,
           comp_quantity,
           comp_quantity_extended,
           comp_buy_make,
           organization_id,
           exclude_ind,
           effective_date,
           disable_date,
           --  1.2  04/11/2014  Dalit A. Raviv
           supply_subinventory,
           supply_locator_id,
           wip_supply_type,
           --- CHG0041935
           operation_seq_num,
           item_num,
           component_yield_factor,
           --primary_uom_code,
           --basis_type,
           change_notice,
           --include_in_cost_rollup,
           --last_update_date,
           implementation_date,
           component_sequence_id)
        VALUES
          (l_batch_id,
           trunc(SYSDATE),
           t.plan_level,
           t.component_code,
           t.sort_order,
           l_top_level_ass_part_number, --top_level_assembly_part_number,
           j.inventory_item_id,
           xxinv_utils_pkg.get_item_segment(t.assembly_item_id,
                                            t.organization_id), --direct_assembly_part_number,
           t.assembly_item_id,
           l_comp_part_number, --comp_part_number,
           t.component_item_id,
           round(xxinv_utils_pkg.get_item_material_cost(t.component_item_id,
                                                        t.organization_id),
                 2),
           round(xxinv_utils_pkg.get_item_cost(t.component_item_id,
                                               t.organization_id),
                 2), --COMP_item_COST,
           l_get_last_rcv_po_price, --comp_last_po_rcv_price,
           l_comp_last_po_price,
           t.component_quantity, --comp_quantity,
           t.extended_quantity,
           xxinv_utils_pkg.get_lookup_meaning('MTL_PLANNING_MAKE_BUY',
                                              l_make_buy),
           t.organization_id,
           l_exlude_flag,
           t.effectivity_date,
           t.disable_date,
           -- 1.2 04/11/2014 Dalit A. Raviv
           t.supply_subinventory,
           t.supply_locator_id,
           t.wip_supply_type,
           --- CHG0041935
           t.operation_seq_num,
           t.item_num,
           t.component_yield_factor,
           --t.primary_uom_code,
           --t.basis_type,
           t.change_notice,
           --t.include_in_cost_rollup,
           --t.last_update_date,
           t.implementation_date,
           t.component_sequence_id);
      
      END LOOP;
    
      DELETE FROM bom_explosion_temp;
    
      COMMIT;
    
    END LOOP;
  EXCEPTION
  
    WHEN OTHERS THEN
      ROLLBACK;
      retcode := '2';
      errbuf  := SQLERRM;
    
      l_recipient := xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit     => '',
                                                                 p_program_short_name => 'XXBOMEXPLODE');
    
      xxfnd_smtp_utilities.send_mail2(p_recipient => l_recipient,
                                      p_subject   => 'Error in xxbom_util_pkg.scheduale_bom_explode',
                                      p_body      => SQLERRM);
  END scheduale_bom_explode;

  --------------------------------------------------------------------------------
  -- Ver      When        Who            Description 
  -- -------  ----------  -------------  -------------------------------------------
  --  1.0     08/03/2018  Roman.W        CHG0041937 - addede procedure "xxinv_bomcopy_casing" called from 
  --                                     concurrent "XXINV_BOMCOPY_CASING / XX: INV XXBOM Copy Bom Casing"
  --                                     Read items data from file and submit concurrent "XXBOMCOPY"
  --------------------------------------------------------------------------------                            
  procedure xxinv_bomcopy_casing(errbuf                OUT VARCHAR2,
                                 retcode               OUT VARCHAR2,
                                 p_org_id_from         IN VARCHAR2,
                                 p_org_id_to           IN VARCHAR2,
                                 p_file_name           IN VARCHAR2,
                                 p_directory_from_list IN VARCHAR2,
                                 p_directory_name      IN VARCHAR2,
                                 p_directory_path      IN VARCHAR2,
                                 p_concurent_max_count IN NUMBER) is
    ------------------------------------
    ---      Cursor Definition
    ------------------------------------                         
    cursor my_cur(pc_organization_id NUMBER,
                  pc_file_name       VARCHAR2,
                  pc_directory       VARCHAR2) is
      select tbl.line_number,
             msib.inventory_item_id item_id,
             tbl.c002               with_subinventory
        from (select line_number,
                     c001,
                     c002,
                     c003,
                     c004,
                     c005,
                     c006,
                     c007,
                     c008
                from table(xxssys_csv_util_pkg.utl_file_to_csv(p_file_name => pc_file_name -- 'ifk_ume.csv',
                                                              ,
                                                               p_directory => pc_directory -- 'XXOBJT_TAB_LOADER_DIR'
                                                               ))) tbl,
             MTL_SYSTEM_ITEMS_B msib
       where tbl.line_number != 1
         and trim(tbl.c001) is not null
         and msib.segment1 = trim(tbl.c001)
         and msib.organization_id = pc_organization_id;
  
    ---------------------------
    --    Local Definition
    ---------------------------
    l_resp_appl_id NUMBER;
    l_resp_id      NUMBER;
    l_user_id      NUMBER;
    l_org_id       NUMBER;
    l_error_code   NUMBER := 0;
    l_error_desc   VARCHAR2(300);
    l_request_id   NUMBER;
  
    j NUMBER := 1;
  
    type type_concurent_data_n IS TABLE OF NUMBER INDEX BY BINARY_INTEGER;
    type type_concurent_data_v IS TABLE OF VARCHAR(300) INDEX BY BINARY_INTEGER;
    type type_concurent_data_b IS TABLE OF BOOLEAN INDEX BY BINARY_INTEGER;
  
    l_type_request_id type_concurent_data_n;
    l_type_complete   type_concurent_data_b;
    l_type_phase      type_concurent_data_v;
    l_type_status     type_concurent_data_v;
    l_type_dev_phase  type_concurent_data_v;
    l_type_dev_status type_concurent_data_v;
    l_type_message    type_concurent_data_v;
  
    l_file_type     VARCHAR2(300);
    l_sql_statement VARCHAR2(800);
    l_directory     VARCHAR2(800);
    l_log_flag      boolean;
    ---------------------------
    --    Code Section
    ---------------------------
  begin
  
    fnd_file.put_line(fnd_file.LOG, 'p_org_code_from : ' || p_org_id_from);
    fnd_file.put_line(fnd_file.LOG, 'p_org_code_to   : ' || p_org_id_to);
    fnd_file.put_line(fnd_file.LOG, 'p_file_name     : ' || p_file_name);
    fnd_file.put_line(fnd_file.LOG,
                      'p_directory_from_list : ' || p_directory_from_list);
    fnd_file.put_line(fnd_file.LOG,
                      'p_directory_name : ' || p_directory_name);
    fnd_file.put_line(fnd_file.LOG,
                      'p_directory_path : ' || p_directory_path);
  
    ------------------------------------------------------
    ------------- Create Directory -----------------------
    ------------------------------------------------------    
    if p_directory_path is null then
      l_directory := p_directory_from_list;
    else
      l_sql_statement := 'CREATE OR REPLACE DIRECTORY ' || p_directory_name ||
                         ' AS ''' || p_directory_path || '''';
    
      BEGIN
        EXECUTE IMMEDIATE l_sql_statement;
      
        fnd_file.put_line(fnd_file.LOG,
                          'Directory ' || p_directory_name ||
                          ' was created/replaced successfully');
      EXCEPTION
        WHEN OTHERS THEN
          ---Error----
          errbuf  := substr('Create/Replace Directory Error: ' || SQLERRM,
                            1,
                            200);
          retcode := 2;
          return;
      END;
      l_directory := p_directory_name;
    
    end if;
  
    if p_org_id_from = p_org_id_to then
      errbuf  := 'ERROR : Please choice diferent Organization From & Organization To';
      retcode := 2;
      fnd_file.put_line(fnd_file.LOG, errbuf);
      return;
    end if;
  
    select reverse(REGEXP_SUBSTR(reverse(p_file_name), '[^.]+*'))
      INTO l_file_type
      from dual;
  
    fnd_file.put_line(fnd_file.LOG, 'File Type : ' || l_file_type);
  
    if 'CSV' != UPPER(l_file_type) then
      errbuf  := 'ERROR : File Type must be ".csv"';
      retcode := 2;
      fnd_file.put_line(fnd_file.LOG, errbuf);
      return;
    end if;
  
    for my_ind in my_cur(p_org_id_from, p_file_name, l_directory) loop
      fnd_file.put_line(fnd_file.LOG,
                        my_ind.line_number || ' || ' || my_ind.item_id ||
                        ' || ' || my_ind.with_subinventory);
    
      l_request_id := fnd_request.submit_request(application => 'XXOBJT',
                                                 program     => 'XXBOMCOPY',
                                                 description => '',
                                                 start_time  => NULL,
                                                 sub_request => FALSE,
                                                 argument1   => p_org_id_from,
                                                 argument2   => my_ind.ITEM_ID,
                                                 argument3   => p_org_id_to,
                                                 argument4   => my_ind.with_subinventory);
    
      if l_request_id > 0 then
      
        COMMIT;
      
        fnd_file.put_line(fnd_file.LOG,
                          'REQ_ID : ' || l_request_id || ' , ITEM_ID : ' ||
                          my_ind.ITEM_ID || ' , WITH_SUBINVENTORY : ' ||
                          my_ind.with_subinventory);
      
        if mod(my_ind.line_number, p_concurent_max_count) = 0 then
        
          j := 1;
        
          for k in 1 .. p_concurent_max_count loop
            begin
              fnd_file.put_line(fnd_file.LOG, '----' || k || '----');
              l_type_complete(k) := fnd_concurrent.wait_for_request(request_id => l_type_request_id(k),
                                                                    INTERVAL   => 5,
                                                                    max_wait   => 600,
                                                                    phase      => l_type_phase(k),
                                                                    status     => l_type_status(k),
                                                                    dev_phase  => l_type_dev_phase(k),
                                                                    dev_status => l_type_dev_status(k),
                                                                    message    => l_type_message(k));
            
              fnd_file.put_line(fnd_file.LOG,
                                'l_request_id = ' || l_type_request_id(k) ||
                                ' ,l_phase = ' || l_type_phase(k) ||
                                ' ,l_status = ' || l_type_status(k) ||
                                ' ,l_dev_phase = ' || l_type_dev_phase(k) ||
                                ' ,l_dev_status = ' || l_type_dev_status(k) ||
                                ' ,l_message = ' || l_type_message(k));
            
              l_log_flag := true;
            
              if l_type_dev_phase(k) != 'COMPLETE' or
                 l_type_dev_status(k) != 'NORMAL' then
                retcode := 2;
              end if;
            
              l_type_request_id(k) := null;
              l_type_phase(k) := null;
              l_type_status(k) := null;
              l_type_dev_phase(k) := null;
              l_type_dev_status(k) := null;
              l_type_message(k) := null;
            
            exception
              when others then
                null;
            end;
          end loop;
        else
          l_type_request_id(j) := l_request_id;
          j := j + 1;
          l_log_flag := false;
        end if;
      
      end if;
    
    end loop;
    -- Write to log status of last 15 concurrents --
    if not l_log_flag then
      for k in 1 .. p_concurent_max_count loop
        begin
          fnd_file.put_line(fnd_file.LOG, '----' || k || '----');
          l_type_complete(k) := fnd_concurrent.wait_for_request(request_id => l_type_request_id(k),
                                                                INTERVAL   => 5,
                                                                max_wait   => 600,
                                                                phase      => l_type_phase(k),
                                                                status     => l_type_status(k),
                                                                dev_phase  => l_type_dev_phase(k),
                                                                dev_status => l_type_dev_status(k),
                                                                message    => l_type_message(k));
        
          fnd_file.put_line(fnd_file.LOG,
                            'l_request_id = ' || l_type_request_id(k) ||
                            ' ,l_phase = ' || l_type_phase(k) ||
                            ' ,l_status = ' || l_type_status(k) ||
                            ' ,l_dev_phase = ' || l_type_dev_phase(k) ||
                            ' ,l_dev_status = ' || l_type_dev_status(k) ||
                            ' ,l_message = ' || l_type_message(k));
        
          l_log_flag := true;
        
          if l_type_dev_phase(k) != 'COMPLETE' or
             l_type_dev_status(k) != 'NORMAL' then
            retcode := 2;
          end if;
        
          l_type_request_id(k) := null;
          l_type_phase(k) := null;
          l_type_status(k) := null;
          l_type_dev_phase(k) := null;
          l_type_dev_status(k) := null;
          l_type_message(k) := null;
        
        exception
          when others then
            null;
        end;
      end loop;
    end if;
  
  exception
    when OTHERS then
      fnd_file.put_line(fnd_file.LOG, 'EXCEPTION_OTHERS_1 : ' || sqlerrm);
      retcode := 2;
  end XXINV_BOMCOPY_CASING;

  ---------------------------------------------------------------------------------------------------------------
  -- Ver      When         Who         Description 
  -- -------  -----------   ---------  --------------------------------------------------------------------------
  --  1.0     11/03/2018   Roman.W     CHG0041951 - added procedure "xxinv_bompcmbm_casing" calling from
  --                                   concurrent "XXINV_BOMPCMBM_CASING / XX: INV Create Common Bills Casing".
  --                                   Procedure read data from file and submit concurrent "BOMPCMBM"
  ---------------------------------------------------------------------------------------------------------------
  procedure xxinv_bompcmbm_casing(errbuf                   OUT VARCHAR2,
                                  retcode                  OUT VARCHAR2,
                                  p_file_name              IN VARCHAR2,
                                  p_defauld_directory_name IN VARCHAR2,
                                  p_new_directory_name     IN VARCHAR2,
                                  p_new_directory_path     IN VARCHAR2,
                                  p_concurent_max_count    IN NUMBER) is
    ----------------------------------
    --    Local Definitions
    ----------------------------------
    cursor my_cur(c_file_name VARCHAR2, c_directory VARCHAR2) is
      select tbl.line_number,
             tbl.c001        scope,
             tbl.c002        org_hierarchy,
             tbl.c003        current_org_id,
             tbl.c004        common_item_from,
             tbl.c005        alternate,
             tbl.c006        common_org_to,
             tbl.c007        common_item_to,
             tbl.c008        enable_attrs_update
        from (select line_number,
                     c001,
                     c002,
                     c003,
                     c004,
                     c005,
                     c006,
                     c007,
                     c008
                from table(xxssys_csv_util_pkg.utl_file_to_csv(p_file_name => c_file_name,
                                                               p_directory => c_directory))) tbl
       where tbl.line_number != 1
         and trim(tbl.c001) is not null;
  
    l_resp_id      NUMBER;
    l_resp_appl_id NUMBER;
  
    l_request_id NUMBER;
  
    j NUMBER := 1;
  
    type type_concurent_data_n IS TABLE OF NUMBER INDEX BY BINARY_INTEGER;
    type type_concurent_data_v IS TABLE OF VARCHAR(300) INDEX BY BINARY_INTEGER;
    type type_concurent_data_b IS TABLE OF BOOLEAN INDEX BY BINARY_INTEGER;
  
    l_type_request_id type_concurent_data_n;
    l_type_complete   type_concurent_data_b;
    l_type_phase      type_concurent_data_v;
    l_type_status     type_concurent_data_v;
    l_type_dev_phase  type_concurent_data_v;
    l_type_dev_status type_concurent_data_v;
    l_type_message    type_concurent_data_v;
  
    l_error_desc VARCHAR2(4000);
  
    l_current_org_id NUMBER;
    l_common_org_to  NUMBER;
  
    l_common_item_from NUMBER;
    l_common_item_to   NUMBER;
    l_directory        VARCHAR2(300);
    l_file_type        VARCHAR2(300);
    l_sql_statement    VARCHAR2(300);
    l_log_flag         BOOLEAN;
    l_flag             BOOLEAN;
    ----------------------------------
    --       Code Section
    ----------------------------------
  begin
  
    --- Check File Type ----
    select reverse(REGEXP_SUBSTR(reverse(p_file_name), '[^.]+*'))
      INTO l_file_type
      from dual;
  
    fnd_file.put_line(fnd_file.LOG, 'File Type : ' || l_file_type);
  
    if 'CSV' != UPPER(l_file_type) then
      errbuf  := 'ERROR : File Type must be ".csv"';
      retcode := 2;
      fnd_file.put_line(fnd_file.LOG, errbuf);
      return;
    end if;
  
    ---- Create Directory if required ----
    if p_new_directory_path is null then
      l_directory := p_defauld_directory_name;
    else
      l_sql_statement := 'CREATE OR REPLACE DIRECTORY ' ||
                         p_new_directory_name || ' AS ''' ||
                         p_new_directory_path || '''';
    
      BEGIN
        EXECUTE IMMEDIATE l_sql_statement;
      
        fnd_file.put_line(fnd_file.LOG,
                          'Directory ' || p_new_directory_name ||
                          ' was created/replaced successfully');
      EXCEPTION
        WHEN OTHERS THEN
          ---Error----
          errbuf  := substr('Create/Replace Directory Error: ' || SQLERRM,
                            1,
                            200);
          retcode := 2;
          return;
      END;
      l_directory := p_new_directory_name;
    
    end if;
  
    -------------------------------------------------------
    ------ Get Concurrent Short Name / Application --------
    -------------------------------------------------------
    -- Test statements here
    for my_ind in my_cur(p_file_name, l_directory) loop
    
      l_flag           := true;
      l_error_desc     := null;
      l_current_org_id := null;
      l_common_org_to  := null;
    
      -- Check Required --
      l_error_desc := my_ind.line_number || ') ';
      if trim(my_ind.scope) is null then
        l_flag       := false;
        l_error_desc := l_error_desc || ' SCOPE is EMPTY.' || chr(10);
      
      end if;
    
      if trim(my_ind.common_item_from) is null then
        l_flag       := false;
        l_error_desc := l_error_desc || ' COMMON_ITEM_FROM is EMPTY.' ||
                        chr(10);
      end if;
    
      if trim(my_ind.enable_attrs_update) is null then
        l_flag       := false;
        l_error_desc := l_error_desc || ' ENABLE_ATTRS_UPDATE is EMPTY.' ||
                        chr(10);
      end if;
    
      --- Check Data --
      begin
        if my_ind.current_org_id is not null then
          select ion.ORGANIZATION_ID
            into l_current_org_id
            from INV_ORGANIZATION_NAME_V ion
           where ion.ORGANIZATION_CODE = my_ind.current_org_id;
        end if;
      exception
        when others then
          l_flag       := false;
          l_error_desc := l_error_desc || ' CURRENT_ORG_ID = ' ||
                          my_ind.current_org_id || ' - not valid.' ||
                          chr(10);
      end;
      -- Check ORGANIZATION_ID TO --
      begin
        if my_ind.common_org_to is not null then
          select ion.ORGANIZATION_ID
            into l_common_org_to
            from INV_ORGANIZATION_NAME_V ion
           where ion.ORGANIZATION_CODE = my_ind.common_org_to;
        end if;
      exception
        when others then
          l_flag       := false;
          l_error_desc := l_error_desc || ' COMMON_ORG_TO = ' ||
                          my_ind.common_org_to || ' - not valid.' ||
                          chr(10);
      end;
      -- Check COMMON_ITEM_FROM --
      begin
        if l_current_org_id is not null and
           trim(my_ind.common_item_from) is not null then
          SELECT inventory_item_id
            INTO l_common_item_from
            FROM MTL_SYSTEM_ITEMS_VL
           WHERE concatenated_segments = my_ind.common_item_from --common_item_from
             AND organization_id = l_current_org_id;
        end if;
      exception
        when others then
          l_flag       := false;
          l_error_desc := l_error_desc || ' COMMON_ITEM_FROM = ' ||
                          my_ind.common_item_from || ' - not valid.' ||
                          chr(10);
      end;
    
      -- Check COMMON_ITEM_TO --
      begin
        if l_common_org_to is not null and
           trim(my_ind.common_item_to) is not null then
          SELECT inventory_item_id
            INTO l_common_item_to
            FROM MTL_SYSTEM_ITEMS_VL
           WHERE concatenated_segments = my_ind.common_item_to
             AND organization_id = l_current_org_id;
        end if;
      exception
        when others then
          l_flag       := false;
          l_error_desc := l_error_desc || ' COMMON_ITEM_FROM = ' ||
                          my_ind.common_item_from || ' - not valid.' ||
                          chr(10);
      end;
    
      if l_flag then
      
        l_request_id := fnd_request.submit_request(application => 'BOM',
                                                   program     => 'BOMPCMBM',
                                                   description => '',
                                                   start_time  => NULL,
                                                   sub_request => FALSE,
                                                   argument1   => my_ind.scope,
                                                   argument2   => my_ind.org_hierarchy,
                                                   argument3   => l_current_org_id,
                                                   argument4   => l_common_item_from,
                                                   argument5   => my_ind.alternate,
                                                   argument6   => l_common_org_to,
                                                   argument7   => l_common_item_to,
                                                   argument8   => my_ind.enable_attrs_update);
      
        if l_request_id > 0 then
        
          COMMIT;
        
          dbms_output.put_line('REQ_ID : ' || l_request_id);
        
          if mod(my_ind.line_number, p_concurent_max_count) = 0 then
          
            j := 1;
          
            for k in 1 .. p_concurent_max_count loop
              begin
                fnd_file.put_line(fnd_file.LOG, '----' || k || '----');
                l_type_complete(k) := fnd_concurrent.wait_for_request(request_id => l_type_request_id(k),
                                                                      INTERVAL   => 5,
                                                                      max_wait   => 600,
                                                                      phase      => l_type_phase(k),
                                                                      status     => l_type_status(k),
                                                                      dev_phase  => l_type_dev_phase(k),
                                                                      dev_status => l_type_dev_status(k),
                                                                      message    => l_type_message(k));
              
                fnd_file.put_line(fnd_file.LOG,
                                  'l_request_id = ' || l_type_request_id(k) ||
                                  ' ,l_phase = ' || l_type_phase(k) ||
                                  ' ,l_status = ' || l_type_status(k) ||
                                  ' ,l_dev_phase = ' || l_type_dev_phase(k) ||
                                  ' ,l_dev_status = ' ||
                                  l_type_dev_status(k) || ' ,l_message = ' ||
                                  l_type_message(k));
                l_log_flag := true;
                if l_type_dev_phase(k) != 'COMPLETE' or
                   l_type_dev_status(k) != 'NORMAL' then
                  retcode := 2;
                end if;
              
              exception
                when others then
                  null;
              end;
            end loop;
          
          else
            l_type_request_id(j) := l_request_id;
            j := j + 1;
            l_log_flag := false;
          end if;
        end if;
      else
        dbms_output.put_line(l_error_desc);
        fnd_file.put_line(fnd_file.LOG, l_error_desc);
      
      end if;
      fnd_file.put_line(fnd_file.LOG,
                        '-------------------------------------------------------------');
    end loop;
    -- Write to log status of last 15 concurrents --
    if not l_log_flag then
      for k in 1 .. p_concurent_max_count loop
        begin
          fnd_file.put_line(fnd_file.LOG, '----' || k || '----');
          l_type_complete(k) := fnd_concurrent.wait_for_request(request_id => l_type_request_id(k),
                                                                INTERVAL   => 5,
                                                                max_wait   => 600,
                                                                phase      => l_type_phase(k),
                                                                status     => l_type_status(k),
                                                                dev_phase  => l_type_dev_phase(k),
                                                                dev_status => l_type_dev_status(k),
                                                                message    => l_type_message(k));
        
          fnd_file.put_line(fnd_file.LOG,
                            'l_request_id = ' || l_type_request_id(k) ||
                            ' ,l_phase = ' || l_type_phase(k) ||
                            ' ,l_status = ' || l_type_status(k) ||
                            ' ,l_dev_phase = ' || l_type_dev_phase(k) ||
                            ' ,l_dev_status = ' || l_type_dev_status(k) ||
                            ' ,l_message = ' || l_type_message(k));
        
          l_log_flag := true;
        
          if l_type_dev_phase(k) != 'COMPLETE' or
             l_type_dev_status(k) != 'NORMAL' then
            retcode := 2;
          end if;
        
          l_type_request_id(k) := null;
          l_type_phase(k) := null;
          l_type_status(k) := null;
          l_type_dev_phase(k) := null;
          l_type_dev_status(k) := null;
          l_type_message(k) := null;
        
        exception
          when others then
            null;
        end;
      end loop;
    end if;
    dbms_output.put_line('============= SCRIPT RUN COMPLITED ==============');
  exception
    when OTHERS then
      errbuf := 'EXCEPTION_OTHERS : xxinv_bom_util_pkg.XXBOM_BOMPCMBM_CASING() - ' ||
                sqlerrm;
  end XXINV_BOMPCMBM_CASING;

END XXINV_BOM_UTIL_PKG;
/
