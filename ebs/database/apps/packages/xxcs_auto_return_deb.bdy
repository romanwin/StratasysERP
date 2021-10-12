CREATE OR REPLACE PACKAGE BODY xxcs_auto_return_deb IS
--------------------------------------------------------------------
--  customization code: CUST017 - XXCS_AUTO_RETURN_DEB 
--  name:               XXCS_AUTO_RETURN_DEB
--                            
--  create by:          XXX
--  $Revision:          1.0 
--  creation date:      31/08/2009 1:32:25 PM
--  Purpose:            CLose debrief lines and create move orders for service tasks
--------------------------------------------------------------------
--  ver   date          name            desc
--  1.0   31/08/2009    XXX             initial build  
--  1.1   08/04/2010    Vitaly          add logic changes
--  1.2   16/05/2010    Vitaly          add condition to CURSOR cr_deb_header at create_move_order procedure  
--  1.3   28/10/2010    Dalit A. Raviv  procedure create_move_order :
--                                      change population of cursor cr_deb_lines add 
--                                      lines of return that do not have part requirement.
--  1.4   02/01/2011    Roman V.        add validation of subinv. to part
--                                      Get MO lines for PR that were not assign to deb
--  1.5   22/05/2012    Dalit A. Raviv  1) Support multiple sub-inventories to one engineer. Create return  
--                                      line according to debrief line and not from his default sub-inventory.
--                                      2) Support creating move order of not used parts according to PR and 
--                                      not according to his default sub-inventory.
--                                      3) Fix errors when resubmit xx:auto debrief ? Error when reopen the task and add new line. 
--                                      We got an error ?Error When Trying to Close Debrief for SR 50878: CSF_DEBRIEF_CHARGE_UPLOADED?. 
--                                      4) Remark all commit syntax and api?s commit parameter in order to run all process together. 
--                                      This will prevent from creation return lines or move order without completion the all process.
-------------------------------------------------------------------- 

   g_task_status_id NUMBER;
   g_eng_id         NUMBER;
   g_commit_profile varchar2(50); -- 23/05/2012 1.2 Dalit A. Raviv
  
  --------------------------------------------------------------------
  --  customization code: CUST017 - Debrief Closure / CUST281 - XXCS_AUTO_RETURN_DEB 
  --  name:               create_move_order
  --                            
  --  create by:          XXX
  --  $Revision:          1.0 
  --  creation date:      31/08/2009 1:32:25 PM
  --  Purpose:            create move orders for service tasks
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   31/08/2009    XXX             initial build  
  --  1.1   22/03/2010    Vitaly K.       change logic of program
  --  1.2   28/10/2010    Dalit A. Raviv  1) change population of cursor cr_deb_lines
  --                                         add lines of return that do not have part requirement.
  --                                      2) Handle CAR Sub inventory
  --                                      3) Sum line qty by  inventory item is and issuing_sub_inventory_code
  --  1.3   02/01/2011    Roman V.        add validation of subinv. to part
  --                                      Get MO lines for PR that were not assign to deb
  -------------------------------------------------------------------- 
  PROCEDURE create_move_order( p_task_assignment_id IN NUMBER,
                               p_return_status      OUT VARCHAR2,
                               p_return_message     OUT VARCHAR2) IS
   
    cursor cr_deb_header is
      select jtb.task_id, cd.*
      from   csf_debrief_headers      cd,
             jtf_task_all_assignments jta,
             jtf_tasks_b              jtb
      where  cd.attribute1            = 'YES'  -- 1.2 16/05/2010 Vitaly - Return Part debreif lines were created/updated for this debreif header
      and    cd.task_assignment_id    = jta.task_assignment_id 
      and    jtb.task_id              = jta.task_id 
      and    jta.task_assignment_id   = p_task_assignment_id 
      and    jta.assignee_role        = 'ASSIGNEE' 
      -- Check that there is at least 1 line in the debrief that need to be Moved
      and (exists
           -- Case of material line
           (select 1
            from   csf_debrief_lines       cdl, 
                   cs_transaction_types_b  ct
            where  cdl.debrief_header_id   = cd.debrief_header_id 
            and    cdl.transaction_type_id = ct.transaction_type_id 
            and    cd.debrief_header_id    = cdl.debrief_header_id 
            and    ct.attribute3           = 'YES')
           -- Case of PR
           or exists((select 1
                      from   csp_requirement_headers_v crh,
                             csp_req_line_details_v    crl
                      where  crh.task_id               = jtb.task_id 
                      and    crh.requirement_header_id = crl.requirement_header_id 
                      and    nvl(crl.status_code, 'ENTERED') != 'CANCELLED')));
     
    cursor cr_deb_lines(cp_header_id in number) is
      select 'PART_REQUIREMENT',
             -- a.quantity, Dalit A. Raviv 07/11/2010
             sum(a.quantity) quantity,
             a.issuing_inventory_org_id,
             a.issuing_sub_inventory_code,
             a.issuing_locator_id,
             a.receiving_inventory_org_id,
             a.receiving_sub_inventory_code,
             a.inventory_item_id,
             a.receiving_locator_id,
             a.uom_code,
             -- a.debrief_line_id Dalit A. Raviv 07/11/2010
             count(a.debrief_line_id) debrief_line_id
      from   csf_debrief_lines         a, 
             cs_transaction_types_b    ct,
             mtl_secondary_inventories ms
      where  debrief_header_id         = cp_header_id 
      and    a.transaction_type_id     = ct.transaction_type_id 
      -- and a.item_serial_number IS NULL -- Do Not Create MO Lines When Serial Exist -- closed by Vitaly 22-Mar-2010
      -- and ct.attribute3 = 'YES' --Must Be a Material Line                          -- closed by Vitaly 22-Mar-2010
      -- added by Vitaly 22-Mar-2010
      -- Do Not Create MO Lines When Serial Exist 
      and ((a.item_serial_number is null and ct.attribute3 = 'YES')  --Must Be a Material Line 
            or  a.item_serial_number is not null 
          )
      -- check that the pr lines are connected to the order
      and   a.debrief_header_id in ( select cdh.debrief_header_id
                                     from   csp_requirement_headers_v crh,
                                            csp_req_line_details_v    crl,
                                            csf_debrief_headers       cdh
                                     where  crh.task_assignment_id    = cdh.task_assignment_id 
                                     and    cdh.debrief_header_id     = a.debrief_header_id 
                                     and    crh.requirement_header_id = crl.requirement_header_id 
                                     and    crl.inventory_item_id     = a.inventory_item_id 
                                     and    crl.source_number         is not null 
                                     and    nvl(crl.status_code, 'ENTERED') != 'CANCELLED' 
                                     and    crl.sourced_from_disp           = 'Internal Order')
      -- Dalit A. Raviv 07/11/2010
      -- Handle Car subinventory population. Do Not include in process
      and   ((ms.secondary_inventory_name = a.issuing_sub_inventory_code
             and   ms.attribute2               is not null)
             or
             (ms.secondary_inventory_name = a.receiving_sub_inventory_code
             and   ms.attribute2               is not null)
             )
      group by a.inventory_item_id,
               a.issuing_sub_inventory_code,
               a.issuing_inventory_org_id,
               a.issuing_locator_id,
               a.receiving_inventory_org_id,
               a.receiving_sub_inventory_code,
               a.receiving_locator_id,
               a.uom_code
      union
      select 'RETURN_NO_PART_REQUIREMENT', 
             a.quantity,
             a.issuing_inventory_org_id,
             a.issuing_sub_inventory_code,
             a.issuing_locator_id,
             a.receiving_inventory_org_id,
             a.receiving_sub_inventory_code,
             a.inventory_item_id,
             a.receiving_locator_id,
             a.uom_code,
             a.debrief_line_id
      from   csf_debrief_lines         a, 
             cs_transaction_types_b    ct,
             mtl_secondary_inventories ms
      where  debrief_header_id         = cp_header_id
      and    a.transaction_type_id     = ct.transaction_type_id 
      and ((a.item_serial_number       is null and ct.attribute3 = 'YES') -- Must Be a Material Line 
            or  a.item_serial_number   is not null 
          )
      -- Dalit A. Raviv 28/10/2010
      -- line that are return and not exists in part requirement.
      and   a.receiving_sub_inventory_code is not null
      and   a.debrief_header_id not in ( select cdh.debrief_header_id
                                         from   csp_requirement_headers_v crh,
                                                csp_req_line_details_v    crl,
                                                csf_debrief_headers       cdh
                                         where  crh.task_assignment_id    = cdh.task_assignment_id 
                                         and    cdh.debrief_header_id     = a.debrief_header_id 
                                         and    crh.requirement_header_id = crl.requirement_header_id 
                                         and    crl.inventory_item_id     = a.inventory_item_id 
                                         and    crl.source_number         is not null 
                                         and    nvl(crl.status_code, 'ENTERED') != 'CANCELLED' 
                                         and    crl.sourced_from_disp           = 'Internal Order'
                                         )
      -- Dalit A. Raviv 07/11/2010
      -- Handle Car subinventory population. Do Not include in process
      and   ms.secondary_inventory_name = a.receiving_sub_inventory_code
      and   ms.attribute2               is not null
      ;
   
    -- Get MO lines for PR that were not assign to deb
    cursor cr_part_req(cp_task_assignment_id in number, cp_header_id in number) is
      select crh.destination_organization_id, crh.destination_subinventory, crl.*
      from   csp_requirement_headers_v crh, 
             csp_req_line_details_v    crl
      where  crh.task_assignment_id    = cp_task_assignment_id 
      and    crh.requirement_header_id = crl.requirement_header_id 
      and    crl.source_number         is not null 
      and    crl.sourced_from_disp     = 'Internal Order' 
      and    nvl(crl.status_code, 'ENTERED') != 'CANCELLED' 
      and not exists  (select 1 
                       from   csf_debrief_lines cl,
                              mtl_secondary_inventories ms
                       where  cl.debrief_header_id = cp_header_id
                       and    cl.inventory_item_id = crl.inventory_item_id
                       -- Roman V. 02/01/2011 validation of subinv.
                       and    (ms.secondary_inventory_name = cl.issuing_sub_inventory_code
                               and   ms.attribute2         is not null) );
   
    cursor cr_txn(cp_req_number varchar2, cp_organization_id in number) is
      select l.line_id
      from   mtl_txn_request_headers h, 
             mtl_txn_request_lines   l
      where  h.request_number        = cp_req_number 
      and    h.organization_id       = cp_organization_id 
      and    h.header_id             = l.header_id;
    
    l_hdr_rec             inv_move_order_pub.trohdr_rec_type := inv_move_order_pub.g_miss_trohdr_rec;
    l_line_tbl            inv_move_order_pub.trolin_tbl_type := inv_move_order_pub.g_miss_trolin_tbl;
    x_hdr_rec             inv_move_order_pub.trohdr_rec_type := inv_move_order_pub.g_miss_trohdr_rec;
    x_hdr_val_rec         inv_move_order_pub.trohdr_val_rec_type;
    x_line_tbl            inv_move_order_pub.trolin_tbl_type;
    x_line_val_tbl        inv_move_order_pub.trolin_val_tbl_type;
   
    x_return_status       VARCHAR2(1);
    x_msg_count           NUMBER;
    x_msg_data            VARCHAR2(4000);
    v_msg_index_out       NUMBER;
    v_sr_number           VARCHAR2(64);
    v_counter             NUMBER;
    v_organization_id     NUMBER;
    v_user_id             NUMBER;
    v_usa_subinv_def      VARCHAR2(30);
    v_usa_organization_id NUMBER;
    v_usa_locator_id      NUMBER;
    v_create_mo           BOOLEAN;
    v_reg_subinv          VARCHAR2(30);
    v_quantity_to_move    NUMBER;
    v_incident_id         NUMBER;
         
  begin
    for i in cr_deb_header loop
      -- Indicates if the MO will create or not (only if there are MO lines)
      v_create_mo := FALSE;
      --
      v_counter       := 0;
      p_return_status := '0';
      x_msg_data      := NULL;
      
      begin
        select jtb.source_object_name,
               jr.user_id,
               ci.incident_id,
               jt.resource_id
        into   v_sr_number, v_user_id, v_incident_id, g_eng_id
        from   jtf_task_assignments    jt,
               jtf_tasks_b             jtb,
               jtf_rs_resource_dtls_vl jr,
               cs_incidents_all_b      ci
        where  jtb.source_object_type_code = 'SR' 
        and    jtb.task_id                 = jt.task_id 
        and    jt.task_assignment_id       = i.task_assignment_id 
        and    ci.incident_id              = jtb.source_object_id 
        and    ci.incident_owner_id        = jr.resource_id;
      exception
        when others then
          v_sr_number := null;
      end;
      
      -- mo_global.set_policy_context('S', 81);
      -- inv_globals.set_org_id(81);
      -- fnd_global.apps_initialize(v_user_id, 50612, 401);
            
      l_hdr_rec.status_date         := SYSDATE;
      l_hdr_rec.transaction_type_id := inv_globals.g_type_transfer_order_subxfr;
      l_hdr_rec.move_order_type     := inv_globals.g_move_order_requisition;
      l_hdr_rec.db_flag             := fnd_api.g_true;
      l_hdr_rec.date_required       := SYSDATE;
      l_hdr_rec.header_status       := inv_globals.g_to_status_incomplete;
      -- l_hdr_rec.organization_id := 141;
      l_hdr_rec.status_date         := SYSDATE;
      l_hdr_rec.transaction_type_id := inv_globals.g_type_transfer_order_subxfr;
      l_hdr_rec.move_order_type     := inv_globals.g_move_order_requisition;
      l_hdr_rec.db_flag             := fnd_api.g_true;
      l_hdr_rec.operation           := inv_globals.g_opr_create;
      l_hdr_rec.description         := v_sr_number;
      l_hdr_rec.attribute1          := i.debrief_header_id;
      l_hdr_rec.attribute2          := v_incident_id;
      
      for t in cr_deb_lines(i.debrief_header_id) loop
         
        v_organization_id := nvl(t.issuing_inventory_org_id, t.receiving_inventory_org_id);
         
        if t.issuing_sub_inventory_code is not null then
          --qty for use in case req > use
          begin
            select crl.required_quantity - t.quantity
            into   v_quantity_to_move
            from   csp_requirement_headers_v crh,
                   csp_req_line_details_v    crl
            where  crh.task_assignment_id    = i.task_assignment_id 
            and    crh.requirement_header_id = crl.requirement_header_id 
            and    crl.inventory_item_id     = t.inventory_item_id;
          exception
            when others then
               v_quantity_to_move := null;
          end;
        else
          --qty for def
          v_quantity_to_move := t.quantity;
        end if;
         
        IF nvl(v_quantity_to_move, 0) > 0 THEN
            
          v_create_mo := TRUE;
                      
          begin
            select ms.attribute2
            into   v_reg_subinv
            from   mtl_secondary_inventories   ms
            where  ms.secondary_inventory_name = nvl(t.issuing_sub_inventory_code,t.receiving_sub_inventory_code) 
            and    ms.organization_id          = nvl(t.issuing_inventory_org_id, t.receiving_inventory_org_id);
          exception
            when others then
               v_reg_subinv := null;
          end;
            
          
          if  v_reg_subinv is not null then 
            v_counter      := v_counter + 1;
            l_line_tbl(v_counter).header_id              := l_hdr_rec.header_id;
            l_line_tbl(v_counter).date_required          := SYSDATE;
            l_line_tbl(v_counter).inventory_item_id      := t.inventory_item_id;
            l_line_tbl(v_counter).line_id                := fnd_api.g_miss_num;
            l_line_tbl(v_counter).line_number            := v_counter;
            l_line_tbl(v_counter).line_status            := inv_globals.g_to_status_incomplete;
            l_line_tbl(v_counter).transaction_type_id    := inv_globals.g_type_transfer_order_subxfr;
            l_line_tbl(v_counter).organization_id        := nvl(t.issuing_inventory_org_id, t.receiving_inventory_org_id);
            l_line_tbl(v_counter).quantity               := v_quantity_to_move;
            l_line_tbl(v_counter).status_date            := SYSDATE;
            l_line_tbl(v_counter).uom_code               := t.uom_code;
            l_line_tbl(v_counter).db_flag                := fnd_api.g_true;
            l_line_tbl(v_counter).operation              := inv_globals.g_opr_create;
            l_line_tbl(v_counter).from_subinventory_code := nvl(t.issuing_sub_inventory_code, t.receiving_sub_inventory_code);
            l_line_tbl(v_counter).from_locator_id        := NULL;
            l_line_tbl(v_counter).to_subinventory_code   := v_reg_subinv;
            l_line_tbl(v_counter).to_locator_id          := nvl(t.issuing_locator_id, t.receiving_locator_id);
            --l_line_tbl(v_counter).attribute2             := t.debrief_line_id; -- Dalit 07/11/2010
                           
            fnd_file.put_line(fnd_file.log,'* Debref minus requirement - MO LINE# - '|| v_counter ||
                                           ', inv_item_id = '|| t.inventory_item_id||', qty = '|| v_quantity_to_move||
                                           ', uom = '''||t.uom_code|| ''', from_subinv = '''|| nvl(t.issuing_sub_inventory_code,t.receiving_sub_inventory_code)||
                                           ''', to_subinv   = '''|| v_reg_subinv||
                                           ''', to_locator  = '|| nvl(t.issuing_locator_id,t.receiving_locator_id)||
                                           ', attr2 (debr_line_id) = '||t.debrief_line_id );
                 
          end if;
        end if;
      end loop;
      
      -- This party requirements are not in use in debref lines..
      for t in cr_part_req(i.task_assignment_id, i.debrief_header_id) loop
         
        v_create_mo := TRUE;
         
        -- Get Usable subinv (according to task owner) 
        begin
          select cr.subinventory_code,
                 cr.organization_id,
                 cr.locator_id,
                 ms.attribute2
          into   v_usa_subinv_def,
                 v_usa_organization_id,
                 v_usa_locator_id,
                 v_reg_subinv
          from   csp_rs_subinventories_v   cr,
                 mtl_secondary_inventories ms
          where  cr.resource_id            = g_eng_id 
          and    cr.condition_type_meaning = 'Usable' 
          AND    NVL(CR.effective_date_end,SYSDATE + 1) > SYSDATE
          AND    cr.organization_id        = t.destination_organization_id --
          AND    cr.subinventory_code      = t.destination_subinventory
          and    cr.subinventory_code      = ms.secondary_inventory_name 
          and    cr.organization_id        = cr.organization_id;

          /*
          select cr.subinventory_code,
                 cr.organization_id,
                 cr.locator_id,
                 ms.attribute2
          into   v_usa_subinv_def,
                 v_usa_organization_id,
                 v_usa_locator_id,
                 v_reg_subinv
          from   csp_rs_subinventories_v   cr,
                 mtl_secondary_inventories ms
          where  cr.resource_id            = g_eng_id 
          and    cr.default_flag           = 'Y' 
          and    cr.condition_type_meaning = 'Usable' 
          and    cr.subinventory_code      = ms.secondary_inventory_name 
          and    cr.organization_id        = cr.organization_id;*/
        exception
          when others then
            v_reg_subinv := null;
        end;
         
        v_counter := v_counter + 1;
        l_line_tbl(v_counter).header_id              := l_hdr_rec.header_id;
        l_line_tbl(v_counter).date_required          := SYSDATE;
        l_line_tbl(v_counter).inventory_item_id      := t.inventory_item_id;
        l_line_tbl(v_counter).line_id                := fnd_api.g_miss_num;
        l_line_tbl(v_counter).line_number            := v_counter;
        l_line_tbl(v_counter).line_status            := inv_globals.g_to_status_incomplete;
        l_line_tbl(v_counter).transaction_type_id    := inv_globals.g_type_transfer_order_subxfr;
        l_line_tbl(v_counter).organization_id        := v_usa_organization_id;
        l_line_tbl(v_counter).quantity               := t.required_quantity;
        l_line_tbl(v_counter).status_date            := SYSDATE;
        l_line_tbl(v_counter).uom_code               := t.uom_code;
        l_line_tbl(v_counter).db_flag                := fnd_api.g_true;
        l_line_tbl(v_counter).operation              := inv_globals.g_opr_create;
        l_line_tbl(v_counter).from_subinventory_code := v_usa_subinv_def;
        l_line_tbl(v_counter).from_locator_id        := NULL;
        l_line_tbl(v_counter).to_subinventory_code   := v_reg_subinv;
        l_line_tbl(v_counter).to_locator_id          := v_usa_locator_id;
        fnd_file.put_line(fnd_file.log,'* This part requirement item is not in use - MO LINE# - '|| v_counter ||
                                       ', qty = '|| t.required_quantity|| ', uom = '''||t.uom_code||
                                       ', from_subinv  = '''|| v_usa_subinv_def||''', to_subinv = '''|| v_reg_subinv||
                                       ''', to_locator = '|| v_usa_locator_id );         
      end loop;
      
      l_hdr_rec.organization_id := nvl(v_organization_id,v_usa_organization_id);
      
      if v_create_mo then
         
        fnd_msg_pub.initialize;
         
        inv_move_order_pub.process_move_order(p_api_version_number => 1.0,
                                              p_init_msg_list      => fnd_api.g_false,
                                              p_return_values      => fnd_api.g_false,
                                              p_commit             => fnd_api.g_false,
                                              x_return_status      => x_return_status,
                                              x_msg_count          => x_msg_count,
                                              x_msg_data           => x_msg_data,
                                              p_trohdr_rec         => l_hdr_rec,
                                              p_trolin_tbl         => l_line_tbl,
                                              x_trohdr_rec         => x_hdr_rec,
                                              x_trohdr_val_rec     => x_hdr_val_rec,
                                              x_trolin_tbl         => x_line_tbl,
                                              x_trolin_val_tbl     => x_line_val_tbl);
         
        fnd_file.put_line(fnd_file.log,'Return Status is :' || x_return_status);
         
        if x_return_status = 'S' then
            
          -- COMMIT;
          fnd_file.put_line(fnd_file.log, '* MOVE ORDER# : '||x_hdr_rec.request_number);
          fnd_file.put_line(fnd_file.log, '* Number of Lines Created: '|| x_line_tbl.COUNT);
          dbms_output.put_line('* MOVE ORDER# '|| x_hdr_rec.request_number||' was created SUCCESSFULY , Num of Lines Created: ' ||x_line_tbl.COUNT); 
          v_counter := 0;
            
          -- Update TXN To Approve
          for t in cr_txn(x_hdr_rec.request_number, nvl(v_organization_id, v_usa_organization_id)) loop   
            update mtl_txn_request_lines l
            set    l.line_status         = 3
            where  l.line_id             = t.line_id;  
          end loop;
            
          update mtl_txn_request_headers h
          set    h.header_status         = 3
          where  h.request_number        = x_hdr_rec.request_number 
          and    h.organization_id       = v_organization_id;
          
          commit;
            
        else
          dbms_output.put_line('* Move Order creation FAILURE');
          p_return_status := '2'; 
          if x_msg_count > 0 then
            for v_index in 1 .. x_msg_count loop
              fnd_msg_pub.get(p_msg_index     => v_index,
                              p_encoded       => 'F',
                              p_data          => x_msg_data,
                              p_msg_index_out => v_msg_index_out);
              x_msg_data := substr(x_msg_data, 1, 200) || chr(10);
              fnd_file.put_line(fnd_file.log, x_msg_data);
              fnd_file.put_line(fnd_file.log,'============================================================');
            end loop;
          end if;
          ROLLBACK;
        end if; -- If v_create_mo is True
      end if; -- v_create_mo
      
      p_return_message := x_msg_data;
    end loop; -- debrief header
  end create_move_order;

  --------------------------------------------------------------------
  --  customization code: CUST017 - Debrief Closure / CUST281 - XXCS_AUTO_RETURN_DEB 
  --  name:               create_return_deb
  --                            
  --  create by:          XXX
  --  $Revision:          1.0 
  --  creation date:      31/08/2009 1:32:25 PM
  --  Purpose:            CLose debrief lines for service tasks
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   31/08/2009    XXX             initial build 
  --  1.1   28/06/2010    Dalit A. Raviv  add handle of mark line that we worked on allready.
  --  1.2   22/05/2012    Dalit A. Raviv  1) Support multiple sub-inventories to one engineer. Create return  
  --                                      line according to debrief line and not from his default sub-inventory.
  --                                      2) Support creating move order of not used parts according to PR and 
  --                                      not according to his default sub-inventory.
  --                                      3) Fix errors when resubmit xx:auto debrief ? Error when reopen the task and add new line. 
  --                                      We got an error ?Error When Trying to Close Debrief for SR 50878: CSF_DEBRIEF_CHARGE_UPLOADED?. 
  --                                      4) Remark all commit syntax and api?s commit parameter in order to run all process together. 
  --                                      This will prevent from creation return lines or move order without completion the all process.
  -------------------------------------------------------------------- 
  PROCEDURE create_return_deb( errbuf            OUT VARCHAR2,
                               retcode           OUT VARCHAR2,
                               p_instance_number IN NUMBER) IS
   
    cursor cr_deb_header is
      select jtb.task_id, jtb.source_object_id, sr.incident_number, cd.*
      from   csf_debrief_headers        cd,
             jtf_task_all_assignments   jta,
             jtf_tasks_b                jtb,
             cs_incidents_all_b         sr
      where  cd.task_assignment_id      = jta.task_assignment_id 
      and    jtb.task_id                = jta.task_id 
      and    jtb.source_object_id       = nvl(p_instance_number, jtb.source_object_id) 
      and    jtb.task_status_id         = g_task_status_id  -- Close ENG               
      and    cd.attribute1              is null                 
      and    nvl(jtb.source_object_id,-777) = sr.incident_id(+)
      order by jtb.source_object_id;
   
    cursor cr_deb_lines(cp_header_id in number) is
      select a.*
      from   csf_debrief_lines          a, 
             cs_transaction_types_b     ct
      where  debrief_header_id          = cp_header_id 
      and    a.issuing_inventory_org_id is not null -- Go over only + lines               
      and    a.item_serial_number       IS NULL  -- Must Be a Material Line                
      and    a.transaction_type_id      = ct.transaction_type_id 
      and    ct.attribute3              = 'YES'  -- Indicates the Debrief Line service activity code
      and    a.attribute4               is null  -- 28/06/2010 Dalit A. Raviv 
      -- 1.2 22/05/2012 Dalit A. Raviv Fix errors when resubmit
      AND    nvl(a.charge_upload_status,'xx') != 'SUCCEEDED';
      -- 
   
    cursor cr_deb_lines_to_close(cp_header_id in number) is
      select a.*
      from   csf_debrief_lines a
      where  debrief_header_id = cp_header_id 
      -- 1.2 22/05/2012 Dalit A. Raviv Fix errors when resubmit
      AND    nvl(a.charge_upload_status,'xx') != 'SUCCEEDED' 
      --
      and    rownum            = 1;
   
    l_return_status      varchar2(2000) := null;
    l_msg_count          number         := null;
    l_msg_data           varchar2(2000) := null;
    l_msg_index_out      number         := null;
    l_init_msg_lst       varchar2(500)  := null;
    l_commit             varchar2(5)    := FND_API.G_FALSE; -- 23/05/2012 1.2 Dalit A. Raviv
    v_debrief_line_id    number;
    v_count              number;
    g_eng_id             number;
    v_reg_subinv_def     varchar2(30);
    v_required_quantity  number;
    v_eng_name           varchar2(50);
    v_instance_id        number;
    v_rem_prod_id        number;
    v_user_id            number;
    v_disp_item          varchar2(240);
    v_lookup_code        varchar2(30);
    v_org_master_id      number;
    l_debrief_line_tbl   csf_debrief_pub.debrief_line_tbl_type;
    l_debrief_line_rec   csf_debrief_pub.debrief_line_rec_type;
    v_sr_number          varchar2(30);
    l_sr_start_time      date;
    l_org_id             number;
    stop_process_this_deb_header exception;
    v_error_message      varchar2(3000);
    v_step               varchar2(100);
       
  begin
       
    v_step := 'Step 0';   
    -- Apps Initialize ... CRM Service Super User Objet
    v_step := 'Step 1';
    fnd_global.apps_initialize(1111,   -- user: SCHEDULER
                               51137,  -- CRM Service Super User Objet
                               514);     
  
    l_return_status  := NULL;
    l_msg_count      := NULL;
    l_msg_data       := NULL;
    l_msg_index_out  := NULL;
    errbuf           := NULL;
    retcode          := '0';
   
    g_task_status_id := fnd_profile.VALUE('XXCS_CUST017_DEBRIEF_CLOSURE_STATUS');
    -- 23/05/2012 1.2 Dalit A. Raviv  handle commit control
    g_commit_profile := nvl(fnd_profile.value('XXCS_COMMIT_IN_STEPS'),'N'); 
    -- 
   
    v_step := 'Step 5';
    -- get master organization
    begin
      select distinct mp.master_organization_id
      into   v_org_master_id
      from   mtl_parameters mp;
    exception
      when others then
        errbuf  := 'No Master Organization Found';
        retcode := '2';
        return;
    end;
   
    for i in cr_deb_header loop
      -- DEBREF HEADERS LOOP --
      begin
        v_step := 'Step 10';
        v_count             := 0;
        v_required_quantity := 0;
                 
        fnd_file.put_line(fnd_file.log,'- WE ARE STARTING WITH SR# = '||i.incident_number||
                                       ' , source_object_id = '||i.source_object_id||' (incident_id) '||
                                       ' , task_assignment_id = '||i.task_assignment_id||' , debrief_header_id='||i.debrief_header_id );
                                                                            
        -- Apps Initialize ... CRM Service Super User Objet
        v_step := 'Step 11';
        fnd_global.apps_initialize(1111,  -- user: SCHEDULER
                                   51137, -- CRM Service Super User Objet
                                   514);                                            
              
        v_step := 'Step 15';
        -- get resource details
        begin
          select jr.resource_id,
                 jr.resource_name,
                 ci.customer_product_id,
                 jr1.user_id
          into   g_eng_id, v_eng_name, v_instance_id, v_user_id
          from   jtf_task_assignments    jt,
                 jtf_rs_resource_dtls_vl jr,
                 jtf_rs_resource_dtls_vl jr1,
                 jtf_tasks_b             jtb,
                 cs_incidents_all_b      ci
          where  jt.resource_id          = jr.resource_id 
          and    jt.task_assignment_id   = i.task_assignment_id 
          and    jtb.task_id             = jt.task_id 
          and    jtb.source_object_id    = ci.incident_id 
          and    ci.incident_owner_id    = jr1.resource_id;
        exception
          when no_data_found then
             v_error_message:= '- No Owner To SR '|| i.incident_number||
                               ' , source_object_id = '||i.source_object_id||' (incident_id) '||
                               ' (task_assignment_id = '||i.task_assignment_id||')';
             fnd_file.put_line(fnd_file.log,v_error_message);
             retcode := '2';
             raise stop_process_this_deb_header;
          when others then
             v_error_message:= '- Unexpected error (step = '||v_step||') : '||sqlerrm;
             fnd_file.put_line(fnd_file.log,v_error_message);
             retcode := '2';
             raise stop_process_this_deb_header;
        end;
        -- Get SR operating unit
        v_step := 'Step 20';
        begin
          select cs.incident_number,
                 nvl(incident_occurred_date, incident_date),
                 org_id
          into   v_sr_number, l_sr_start_time, l_org_id
          from   cs_incidents_all_b cs
          where  cs.incident_id     = i.source_object_id;
         
          inv_globals.set_org_id(l_org_id);
          fnd_global.apps_initialize(v_user_id,
                                     fnd_profile.value_specific('XXCS_AUTO_DEBRIEF_RESPONSIBILITY',
                                                                NULL,
                                                                NULL,
                                                                NULL,
                                                                l_org_id),
                                     514);
          mo_global.init('QP');
          fnd_file.put_line(fnd_file.log,'Initialize: User - ' || v_user_id ||
                            ', Responsibility - ' ||
                            fnd_profile.value_specific('XXCS_AUTO_DEBRIEF_RESPONSIBILITY',
                                                       NULL,NULL,NULL, l_org_id) ||
                            ', Application - ' || fnd_global.resp_appl_id);
         
        exception
          when no_data_found then
            v_error_message:= '- SR# ' || i.incident_number || ' Does Not Exist';
            fnd_file.put_line(fnd_file.log,v_error_message);
            retcode := '2';
            raise stop_process_this_deb_header;
          when others then
            v_error_message := '- Unexpected error (step = '||v_step||') : '||SQLERRM;
            fnd_file.put_line(fnd_file.log,v_error_message);
            retcode := '2';
            raise stop_process_this_deb_header;
        end;
        
        -- 23/05/2012 1.2 Dalit A. Raviv remark this part
        -- v_step := 'Step 25';
        -- Get Def subinv (according to task owner)
        -- all this step need to go into the line level 
        /*
        begin
          select cr.subinventory_code
          into   v_reg_subinv_def
          from   csp_rs_subinventories_v   cr
          where  cr.resource_id            = g_eng_id 
          and    cr.default_flag           = 'Y' 
          and    cr.condition_type_meaning = 'Defective';
        exception
          when no_data_found then
            v_error_message:='No Defective Subinventory For The Owner Of The Task. SR# ' ||v_sr_number;
            fnd_file.put_line(fnd_file.log,v_error_message);
            raise stop_process_this_deb_header;
          when others then
            v_error_message:='- Unexpected error (step = '||v_step||') : '||SQLERRM;
            fnd_file.put_line(fnd_file.log,v_error_message);
            raise stop_process_this_deb_header;
        end;
        */
      
        v_step := 'Step 30';
        fnd_file.put_line(fnd_file.log,'- Start processing  ' || v_sr_number);
        if i.task_assignment_id is null then
          v_error_message:= '- Task ID ' || i.task_id || ', Debrief: ' || i.debrief_number ||
                            ' does not have an assignment, line would be ignored';
          fnd_file.put_line(fnd_file.log,v_error_message);
          retcode := '2';
          raise stop_process_this_deb_header;
        else
          for t in cr_deb_lines(i.debrief_header_id) loop
            -- DEBREF LINES LOOP --
            v_step := 'Step 25';
            -- 23/05/2012 1.2 Dalit A. Raviv  handle subinv issue
            -- Get subinv (according to task owner) from debrief line
            begin
              select cr.subinventory_code
              into   v_reg_subinv_def
              from   csp_rs_subinventories_v   cr
              where  cr.resource_id            = g_eng_id -- reasource id
              AND    cr.organization_id        = t.issuing_inventory_org_id 
              AND    NVL(CR.effective_date_end,SYSDATE+1) > SYSDATE
              and    cr.condition_type_meaning = 'Defective';
            exception
              when no_data_found then
                v_error_message:='No Defective Subinventory For The Owner Of The Task. SR# ' ||v_sr_number;
                fnd_file.put_line(fnd_file.log,v_error_message);
                retcode := '2';
                raise stop_process_this_deb_header;
              when others then
                v_error_message:='- Unexpected error (step = '||v_step||') : '||SQLERRM;
                fnd_file.put_line(fnd_file.log,v_error_message);
                retcode := '2';
                raise stop_process_this_deb_header;   
            end;
            -- 1.2
            v_step := 'Step 35';
            begin
              -- find item 
              begin
                v_disp_item := null;               
                select nvl(msi.attribute12, 'N')
                into   v_disp_item
                from   mtl_system_items_b    msi
                where  msi.inventory_item_id = t.inventory_item_id 
                and    msi.organization_id   = v_org_master_id;
              exception
                when others then
                  v_disp_item := null;
                  fnd_file.put_line(fnd_file.log,'- Validation Error - Inventory_Item_Id = '||t.inventory_item_id||
                                                 ' is invalid for debrief_line_id = '||t.debrief_line_id);
                  retcode := '2';
                  raise stop_process_this_deb_header;
              end;
                
              fnd_file.put_line(fnd_file.log,'- Inventory item id '|| v_disp_item ||' - returnable = '||v_disp_item ||
                                             ', Defected Qty = '|| nvl(t.attribute1, 0));
                
              if v_disp_item = 'Y' then
                -- this is returnable item  (do not create line for dispo item)
                if nvl(t.attribute1, 0) > 0 then
                  v_count := v_count + 1;
                  v_step  := 'Step 40';
                  begin
                    select csi.instance_id
                    into   v_rem_prod_id
                    from   csi_ii_relationships  cir,
                           csi_item_instances    csi
                    where  csi.inventory_item_id  = t.inventory_item_id 
                    and    csi.instance_id        = cir.subject_id 
                    and    cir.object_id          = v_instance_id 
                    and    csi.instance_status_id <> 1 
                    and    csi.creation_date      = (select min(csi2.creation_date)
                                                     from   csi_item_instances     csi2,
                                                            csi_ii_relationships   cir2
                                                     where  csi2.instance_id       = cir2.subject_id 
                                                     and    cir2.object_id         = v_instance_id 
                                                     and    csi2.inventory_item_id = t.inventory_item_id);
                  exception
                    when no_data_found then
                      v_rem_prod_id := null;
                      fnd_file.put_line(fnd_file.log,'- Instance Id is not found '||'for debrief_line_id = '||t.debrief_line_id);
                  end;
                  --  Credit Memo Reason -- 
                  v_step := 'Step 45';
                  begin
                    select f.lookup_code
                    into   v_lookup_code
                    from   fnd_lookup_values f
                    where  f.meaning         = t.attribute2 
                    and    f.lookup_type     = 'CREDIT_MEMO_REASON' 
                    and    f.language        = 'US';
                  exception
                    when no_data_found then
                      v_lookup_code := null;
                      fnd_file.put_line(fnd_file.log,'- Credit Memo Reason (csf_debrief_lines.attribute2) is invalid '||
                                                     'for debrief_line_id='||t.debrief_line_id);
                      retcode := '2';
                      raise stop_process_this_deb_header;
                  end;
                      
                  v_step := 'Step 50';
                  select csf_debrief_lines_s.nextval
                  into   v_debrief_line_id
                  from   dual;
                      
                  v_step := 'Step 55';
                  l_debrief_line_tbl(v_count).debrief_line_id             := v_debrief_line_id;
                  l_debrief_line_tbl(v_count).debrief_header_id           := t.debrief_header_id;
                  l_debrief_line_tbl(v_count).service_date                := SYSDATE;
                  l_debrief_line_tbl(v_count).business_process_id         := t.business_process_id;
                  l_debrief_line_tbl(v_count).inventory_item_id           := t.inventory_item_id;
                  l_debrief_line_tbl(v_count).item_revision               := t.item_revision;
                  l_debrief_line_tbl(v_count).instance_id                 := v_rem_prod_id;                      
                  l_debrief_line_tbl(v_count).issuing_inventory_org_id    := NULL;
                  l_debrief_line_tbl(v_count).issuing_sub_inventory_code  := NULL;
                  l_debrief_line_tbl(v_count).issuing_locator_id          := NULL;                      
                  l_debrief_line_tbl(v_count).receiving_inventory_org_id  := t.issuing_inventory_org_id;
                  l_debrief_line_tbl(v_count).receiving_sub_inventory_code:= v_reg_subinv_def; 
                  l_debrief_line_tbl(v_count).receiving_locator_id        := t.issuing_locator_id;
                  l_debrief_line_tbl(v_count).status_of_received_part     := 'Returned to Objet';
                  l_debrief_line_tbl(v_count).uom_code                    := t.uom_code;
                  l_debrief_line_tbl(v_count).quantity                    := t.attribute1;
                  l_debrief_line_tbl(v_count).channel_code                := 'CONNECTED'; -- t.channel_code;
                  l_debrief_line_tbl(v_count).last_update_date            := t.last_update_date;
                  l_debrief_line_tbl(v_count).last_updated_by             := v_user_id;
                  l_debrief_line_tbl(v_count).creation_date               := t.creation_date;
                  l_debrief_line_tbl(v_count).created_by                  := v_user_id;
                  l_debrief_line_tbl(v_count).last_update_login           := t.last_update_login;
                  l_debrief_line_tbl(v_count).transaction_type_id         := 12;          -- Return Part
                  l_debrief_line_tbl(v_count).return_reason_code          := v_lookup_code;
                                        
                  fnd_file.put_line(fnd_file.log, '- Return Part line was created for item ' || t.inventory_item_id);
                end if; -- t.attribute1
                   
                v_step := 'Step 60';
                update csf_debrief_lines cs
                set    cs.parent_product_id  = v_instance_id,
                       cs.removed_product_id = v_rem_prod_id
                where  cs.debrief_line_id    = t.debrief_line_id;
              else
             
                v_step := 'Step 65';
                update csf_debrief_lines    cs
                set    cs.parent_product_id = v_instance_id
                where  cs.debrief_line_id   = t.debrief_line_id;
              end if; -- v_disp_item
            exception
              when others then
                v_error_message:='- Unexpected Error : '||sqlerrm;
                retcode := '2';
                raise stop_process_this_deb_header;
            end;
               -- the end of DEBREF LINES LOOP --
          end loop;
         
          l_msg_data     := NULL;
          l_init_msg_lst := NULL;
          fnd_msg_pub.initialize;
                   
          if v_count = 0 /*And v_fully_received = 'Y'*/ then
            for t in cr_deb_lines_to_close(i.debrief_header_id) loop
              v_step  := 'Step 70';
              v_count := v_count + 1;
                           
              l_debrief_line_rec.debrief_header_id := t.debrief_header_id;
              l_debrief_line_rec.debrief_line_id   := t.debrief_line_id;
              if l_sr_start_time = t.labor_start_date then
                 l_debrief_line_rec.labor_start_date := t.labor_start_date + 10 / 86400;
              else
                 l_debrief_line_rec.labor_start_date := t.labor_start_date;
              end if;
              l_debrief_line_rec.labor_end_date    := t.labor_end_date;
              l_debrief_line_rec.inventory_item_id := t.inventory_item_id;
                           
              fnd_file.put_line(fnd_file.log,'Close debrief  for item ' || t.inventory_item_id);
            end loop;
               
            v_step := 'Step 75';
            
            IF v_count > 0 THEN -- Adi S. 30-05-2012
                csf_debrief_pub.update_debrief_line(1,
                                                   l_init_msg_lst,
                                                   l_commit,
                                                   'Y',
                                                   'Closed',
                                                   l_debrief_line_rec,
                                                   l_return_status,
                                                   l_msg_count,
                                                   l_msg_data);
            ELSE
               l_return_status := 'S';  -- Adi S. 30-05-2012
            END IF;
            if l_return_status != apps.fnd_api.g_ret_sts_success then
              fnd_msg_pub.get(p_msg_index     => -1,
                              p_encoded       => 'F',
                              p_data          => l_msg_data,
                              p_msg_index_out => l_msg_index_out);
              retcode := '2';
              fnd_file.put_line(fnd_file.log,
                                '- Error When Trying To Close Debrief For SR ' ||
                                v_sr_number || ': ' ||
                                substr(l_msg_data, 1, 240) || chr(10));
            else
              v_step := 'Step 80';
              if v_count > 0 then
                update csf_debrief_headers  cd
                set    cd.attribute1        = 'YES'  -- Return Part debrief lines were created for this debrief header
                where  cd.debrief_header_id = i.debrief_header_id;
              else
                -- call new peocedure
                -- if procedure return with error raise
                -- Dalit A. Raviv 31/05/2012 
                l_return_status := null;
                l_msg_data      := null;
                update_status_to_closed (p_debrief_header_id => i.debrief_header_id, -- i n
                                         p_return_status     => l_return_status,     -- o v
                                         p_err_msg           => l_msg_data);         -- o v
                if l_return_status <> 'S' then
                  fnd_file.put_line(fnd_file.log,' Error Update Status to Closed ' || substr(l_msg_data,1,240));
                  v_error_message := l_msg_data;
                  rollback;
                  retcode         := '2';
                  raise           stop_process_this_deb_header;
                end if;
                
              end if;
              
              -- 28/06/2010 Dalit A. Raviv - add update of debrief lines 
              -- each debrief that where created we want to mark it at att4.
              -- next time user will work on this debrief this line will not create. 
              update csf_debrief_lines    dl
              set    dl.attribute4        = 'YES',
                     dl.last_update_date  = sysdate,
                     dl.last_updated_by   = v_user_id
              where  /*dl.debrief_line_id   = v_debrief_line_id
              and    */dl.debrief_header_id = i.debrief_header_id;
              
              -- 23/05/2012 1.2 Dalit A. Raviv  handle commit control
              if g_commit_profile = 'Y' then
                commit; 
              end if;  
              --               
            end if;
               --Close when there are lines + all PR lines are FILLY RECEIVED
          else
            --Create Return Part debrief lines
            v_step := 'Step 85';
            csf_debrief_pub.create_debrief_lines(1,
                                                l_init_msg_lst,
                                                l_commit,
                                                'Y',
                                                'Closed',
                                                l_debrief_line_tbl,
                                                i.debrief_header_id,
                                                'SR',
                                                l_return_status,
                                                l_msg_count,
                                                l_msg_data);
                        
            if l_return_status != apps.fnd_api.g_ret_sts_success then
              fnd_msg_pub.get(p_msg_index     => -1,
                              p_encoded       => 'F',
                              p_data          => l_msg_data,
                              p_msg_index_out => l_msg_index_out);
              fnd_file.put_line(fnd_file.log, '1: ' || l_return_status || ' ' ||l_msg_data);
            else
              v_step := 'Step 90';
              update csf_debrief_headers  cd
              set    cd.attribute1        = 'YES'  -- Return Part debrief lines were created for this debrief header
              where  cd.debrief_header_id = i.debrief_header_id;
               
              -- 28/06/2010 Dalit A. Raviv - add update of debrief lines 
              -- each debrief that where created we want to mark it at att4.
              -- next time user will work on this debrief this line will not create. 
              update csf_debrief_lines    dl
              set    dl.attribute4        = 'YES',
                     dl.last_update_date  = sysdate,
                     dl.last_updated_by   = v_user_id
              where  /*dl.debrief_line_id   = v_debrief_line_id
              and    */dl.debrief_header_id = i.debrief_header_id;
                          
              -- 23/05/2012 1.2 Dalit A. Raviv  handle commit control
              if g_commit_profile = 'Y' then
                commit; 
              end if;  
              --    
            end if;-- return status
          end if;-- v_count
        end if;-- i.task_assignment_id
        
        -- Create Move Order --
        l_return_status := NULL;
        l_msg_data      := NULL;
        if v_count > 0  then
            create_move_order(i.task_assignment_id,
                              l_return_status,
                              l_msg_data);
                                    
            dbms_lock.sleep(5);  
        else 
           commit; -- adi s. 30-05-2012
        end if;  
        if nvl(l_return_status,'0') = '0' THEN -- Adi S. 30-05-2012
          -- success -- commit has been done at create_move_order procedure
          null;
        else
          -- failure -- rollback has been done at create_move_order procedure
          v_error_message := l_msg_data;
          retcode         := '2';
          raise           stop_process_this_deb_header;
        end if;                  
                 
      exception
        when stop_process_this_deb_header then
          -- errbuf  := v_error_message;
          -- retcode := '2';
          -- return;
          null;
        when others then
          errbuf  := 'Unexpected Error (step = '||v_step||') : '||sqlerrm;
          retcode := '2';
          return;
      end;
      -- the end of DEBREF HEADERS LOOP --
    end loop;
  end create_return_deb;
  
  --------------------------------------------------------------------
  --  customization code: CUST017 - Debrief Closure / CUST281 - XXCS_AUTO_RETURN_DEB 
  --  name:               update_status_to_closed
  --                            
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0 
  --  creation date:      31/05/2012 
  --  Purpose:            update status to Closed at debrief, task assignment and task. 
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   31/05/2012    Dalit A. Raviv  initial build  
  -------------------------------------------------------------------- 
  procedure update_status_to_closed (p_debrief_header_id in  number,
                                     p_return_status     out varchar2,
                                     p_err_msg           out varchar2) is
   
    l_return_status      varchar2(100)  := null;
    l_msg_count          number         := null;
    l_msg_data           varchar2(2500) := null;
    x_err_msg            varchar2(2500) := null;
    l_task_id            number         := null;
    l_task_assignment_id number         := null;
    --l_interaction_id     number         := null;
    l_msg_index_out      number         := null;
    l_ovn                number         := null;
    l_ovn_ass            number         := null;
    l_ovn_db             number         := null;
    l_ovn_out            number         := null;
    l_task_status_id     number         := null;
    l_debrief_rec_type   CSF_DEBRIEF_PUB.DEBRIEF_Rec_Type; 
    
    status_exception     exception; 
  begin
    -- get task_id
    begin
      select jta.task_id
      into   l_task_id
      from   jtf_task_all_assignments jta,
             csf_debrief_headers      cdh
      where  jta.task_assignment_id   = cdh.task_assignment_id
      and    cdh.debrief_header_id    =  p_debrief_header_id;
    exception
      when others then
        p_return_status := 'E';
        p_err_msg       := 'Can Not find task_id';
        raise           status_exception;
    end;
    -- Get task assignment_id
    begin  
      select cdh.task_assignment_id,  cdh.object_version_number
      into   l_task_assignment_id,    l_ovn_db
      from   csf_debrief_headers      cdh
      where  cdh.debrief_header_id    =  p_debrief_header_id;  
    exception
      when others then
        p_return_status := 'E';
        p_err_msg       := 'Can Not find task_assignment_id';
        raise           status_exception;
    end;
  
    /*begin
      select cdh.object_version_number
      into   l_ovn_db
      from   csf_debrief_headers   cdh
      where  cdh.debrief_header_id = 175848;
    end;*/
    -- Get assignment object_version_number
    begin
      select jtaa.object_version_number 
      into   l_ovn_ass
      from   jtf_task_all_assignments jtaa
      where  jtaa.task_assignment_id  = l_task_assignment_id; 
    end;   
    ----------------------------------------
    --          Start close Debrief       --
    ----------------------------------------
    l_debrief_rec_type.debrief_header_id  := p_debrief_header_id;
    l_debrief_rec_type.debrief_status_id  := 9;
    l_debrief_rec_type.task_assignment_id := l_task_assignment_id;
    l_debrief_rec_type.attribute1         := 'YES';
    l_debrief_rec_type.object_version_number := l_ovn_db;
  
    CSF_DEBRIEF_PUB.Update_debrief(p_api_version_number => 1.0,
                                   p_init_msg_list      => FND_API.G_TRUE, 
                                   p_commit             => FND_API.G_FALSE,
                                   p_debrief_rec        => l_debrief_rec_type,
                                   x_return_status      => l_return_status,
                                   x_msg_count          => l_msg_count,
                                   x_msg_data           => l_msg_data); 
    -- Handle API Success 
    if l_return_status != fnd_api.g_ret_sts_success then
      if (fnd_msg_pub.count_msg > 0) then
        for i in 1 .. fnd_msg_pub.count_msg loop
          fnd_msg_pub.get(p_msg_index     => i,
                          p_encoded       => 'F',
                          p_data          => l_msg_data,
                          p_msg_index_out => l_msg_index_out);
          x_err_msg := x_err_msg || l_msg_data || chr(10);
        end loop;
      else
        x_err_msg := l_msg_data;
      end if;
      p_err_msg       := x_err_msg;
      p_return_status := l_return_status;
      raise           status_exception;
    else
      p_err_msg       := null;
      p_return_status := l_return_status;
    end if; 
    
    ----------------------------------------
    --    Start close Assignment Status   --
    ----------------------------------------
    l_return_status := null;
    l_msg_count     := null;
    l_msg_data      := null;
    x_err_msg       := null;                              
    csf_task_assignments_pub.update_assignment_status( p_api_version                 => 1.0,
                                                       p_init_msg_list               => FND_API.G_TRUE,
                                                       p_commit                      => FND_API.G_FALSE,
                                                       p_validation_level            => 1,
                                                       x_return_status               => l_return_status,
                                                       x_msg_count                   => l_msg_count,
                                                       x_msg_data                    => l_msg_data,
                                                       p_task_assignment_id          => l_task_assignment_id,
                                                       p_object_version_number       => l_ovn_ass,
                                                       p_assignment_status_id        => 9,
                                                       p_update_task                 => fnd_api.g_false,
                                                       x_task_object_version_number  => l_ovn_out,        -- o
                                                       x_task_status_id              => l_task_status_id  -- o
                                                     );

    if l_return_status != fnd_api.g_ret_sts_success then
      if (fnd_msg_pub.count_msg > 0) then
        for i in 1 .. fnd_msg_pub.count_msg loop
          fnd_msg_pub.get(p_msg_index     => i,
                          p_encoded       => 'F',
                          p_data          => l_msg_data,
                          p_msg_index_out => l_msg_index_out);
          x_err_msg := x_err_msg || l_msg_data || chr(10);
        end loop;
      else
        x_err_msg := l_msg_data;
      end if;
      p_err_msg       := x_err_msg;
      p_return_status := l_return_status;
      raise           status_exception;   
    else
      p_err_msg       := null;
      p_return_status := l_return_status;
    end if; 
      
    ----------------------------------------
    --       Start close Task Status      --
    ----------------------------------------
    l_return_status := null;
    l_msg_count     := null;
    l_msg_data      := null;
    x_err_msg       := null;   
     
    begin  
      select jtb.object_version_number
      into   l_ovn
      from   jtf_tasks_b jtb
      where  jtb.task_id = l_task_id;   
    end;
                              
    csf_tasks_pub.update_task_status (p_api_version            => 1.0,             -- i n
                                      p_init_msg_list          => FND_API.G_TRUE,  -- i v
                                      p_commit                 => FND_API.G_FALSE, -- i v
                                      p_validation_level       => 1,               -- i n
                                      x_return_status          => l_return_status, -- o v
                                      x_msg_count              => l_msg_count,     -- o n
                                      x_msg_data               => l_msg_data,      -- o v
                                      p_task_id                => l_task_id,       -- i n
                                      p_task_status_id         => 9,               -- i n
                                      p_object_version_number  => l_ovn            -- i/o n
                                     );                               
    
    if l_return_status != fnd_api.g_ret_sts_success then
      if (fnd_msg_pub.count_msg > 0) then
        for i in 1 .. fnd_msg_pub.count_msg loop
          fnd_msg_pub.get(p_msg_index     => i,
                          p_encoded       => 'F',
                          p_data          => l_msg_data,
                          p_msg_index_out => l_msg_index_out);
          x_err_msg := x_err_msg || l_msg_data || chr(10);
        end loop;
      else
        x_err_msg := l_msg_data;
      end if;
      p_err_msg       := x_err_msg;
      p_return_status := l_return_status;
      raise           status_exception;        
    else
      p_err_msg       := null;
      p_return_status := l_return_status;
    end if; 
                                      
  -- l_task_id                                 
  exception
    when status_exception then
      null;
    when others then
      p_return_status := 'E';
      p_err_msg       := 'General exception update_status_to_closed - '||substr(sqlerrm,1,240);
  end update_status_to_closed;

/*Procedure Approve_MO(P_Header_Id In Number,P_Line_Id In Number) Is

Begin

 Inv_trolin_Util.Update_Row_Status(P_Line_Id ,
                                    INV_Globals.G_TO_STATUS_APPROVED);

 Inv_trohdr_Util.Update_Row_Status(P_Header_Id,
                                   inv_Globals.G_TO_STATUS_APPROVED);

End Approve_MO;*/

END xxcs_auto_return_deb;
/
