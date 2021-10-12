create or replace package body XXCSI_UTILS_PKG is
-----------------------------------------------------------------------
--  customization code: GENERAL
--  name:               XXCSI_UTILS_PKG
--  create by:          Dalit A. Raviv
--  $Revision:          1.0 
--  creation date:      14/10/2010 
--  Purpose :           Install Base generic package
-----------------------------------------------------------------------
--  ver   date          name            desc
--  1.0   14/10/2010    Dalit A. Raviv  Initial version
--  1.1   29/03/2012    Dalit A. Raviv  add function get_Attached_file_to_printer
--  1.2   13/05/2015    Dalit A. Raviv  CHG0034234 - Update PTO Validation Setup
--                                      add procedure get_printer_and_contract_info
-----------------------------------------------------------------------
                                     
  --------------------------------------------------------------------
  --  name:            create_cust_account_role
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   12/10/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Procedure that create cust account role                
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  12/10/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure update_system (errbuf  out varchar2,
                           retcode out varchar2) is
                           
    cursor get_system_pop_c is
      select csb.system_id, 
             substr(csb.attribute1,1,50) system_name,
             csb.object_version_number ovn
      from   csi_systems_b  csb, 
             csi_systems_tl cst, 
             hz_parties     hp
      where  cst.system_id  = csb.system_id
      and    cst.language   = 'US'
      and    cst.name       <> csb.attribute1
      and    csb.attribute1 = hp.party_name
      and    csb.attribute2 = hp.party_id;
      --and    csb.system_id  in (19405) ; --(20281);-- (19405,19404,19403,20281,19940,19920,20540,21060);
      --(12899,19405,19404,19403,18960,19201,19220,20281,
      --                          11751,11739,19940,19920,12041,20540,21060);
      --and    csb.system_id not in (12463,12609,10783, 10785);
      --and    rownum < 3;
    
    --l_success        varchar2(1) := 'T';
    l_return_status  varchar2(2500);
    l_msg_count      number;
    l_msg_data       varchar2(2500);
    l_msg_index_out  number;
    l_data           varchar2(2500);
    
    l_system_rec     csi_datastructures_pub.system_rec;
    x_txn_rec        csi_datastructures_pub.transaction_rec;
  begin
    errbuf  := 0;
    retcode := NULL;
    for get_system_pop_r in get_system_pop_c loop
   
      fnd_msg_pub.initialize;
      l_return_status := null;
      l_msg_count     := null;
      l_msg_data      := null;
      l_data          := null;
      begin
        l_system_rec.SYSTEM_ID             := get_system_pop_r.system_id;
        l_system_rec.NAME                  := get_system_pop_r.system_name;
        l_system_rec.OBJECT_VERSION_NUMBER := get_system_pop_r.ovn;
        
        x_txn_rec.transaction_id           := NULL;
        x_txn_rec.transaction_date         := sysdate;
        x_txn_rec.source_transaction_date  := sysdate;
        x_txn_rec.transaction_type_id      := 1;
        x_txn_rec.object_version_number    := NULL;
      
       
       
        CSI_SYSTEMS_PUB.update_system(p_api_version      => 1, -- i n
                                      p_commit           => FND_API.G_FALSE,-- i v 'F'
                                      p_init_msg_list    => FND_API.G_TRUE, -- i v 'T'
                                      --p_validation_level => FND_API.G_VALID_LEVEL_FULL, -- i n 100
                                      p_system_rec       => l_system_rec,   -- i csi_datastructures_pub.system_rec
                                      p_txn_rec          => x_txn_rec,      -- i/o nocopy csi_datastructures_pub.transaction_rec
                                      x_return_status    => l_return_status,-- i/o nocopy v
                                      x_msg_count        => l_msg_count,    -- i/o nocopy n
                                      x_msg_data         => l_msg_data      -- i/o nocopy n
                                      );
       
        if l_return_status <> fnd_api.g_ret_sts_success then
          errbuf := 'Failed Update IB System';
        
          fnd_file.put_line(fnd_file.log,'Failed to Update Install base System name'||get_system_pop_r.system_id||
                            ' Name - '||get_system_pop_r.system_name);
          fnd_file.put_line(fnd_file.log,'l_msg_data = ' || substr(l_msg_data, 1, 2000));
          dbms_output.put_line(get_system_pop_r.system_id ||' - Failed Update IB System 1 - '||
                               get_system_pop_r.system_name);
          begin
          for i in 1 .. l_msg_count loop
            l_data := null;
            fnd_msg_pub.get(p_msg_index     => i,
                            p_data          => l_data,
                            p_encoded       => fnd_api.g_false,
                            p_msg_index_out => l_msg_index_out);
            fnd_file.put_line(fnd_file.log, 'l_Data - ' || l_data);
            dbms_output.put_line('l_data - '||substr(l_data,1,200));         
            --errbuf := substr(errbuf || l_data || chr(10), 1, 2000);
          end loop;
          retcode := 1;
          rollback;
          exception
            when others then
              null;
          end;
        else
          commit;
          --p_cust_account_role_id := x_cust_account_role_id;
          fnd_file.put_line(fnd_file.log,'Success Update Install base System name - '||get_system_pop_r.system_id||
                                         ' Name - '||get_system_pop_r.system_name);
          dbms_output.put_line(get_system_pop_r.system_id||' - Success Update Install base System name - '||
                               get_system_pop_r.system_name);
        end if; -- Status if  
      exception
        when others then
          dbms_output.put_line(get_system_pop_r.system_id ||' - Failed Update IB System 2 - '||
                               get_system_pop_r.system_name);
      end;   
    end loop;

  exception
    when others then
      errbuf  := 1;
      retcode := 'Gen EXC - update_system - '||substr(sqlerrm,1,200);
  end update_system; 
  
  --------------------------------------------------------------------
  --  name:            get_Attached_file_to_printer
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   29/03/2012
  --------------------------------------------------------------------
  --  purpose :        function that find if instance have attachment              
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  29/03/2012  Dalit A. Raviv    initial build
  -------------------------------------------------------------------- 
  function get_Attached_file_to_printer(p_instance_id in number) return varchar2 is
    
    l_return varchar2(5) := 'N';
  begin
    select 'Y'
    into   l_return
    from   fnd_attached_documents t,
           fnd_documents  fo
    where  fo.document_id = t.document_id
    and    t.pk1_value    = p_instance_id
    and    t.entity_name  = 'XX_ITEM_INSTANCE';
    
    return l_return;
  exception
    when too_many_rows then
      return 'Y';
    when others then
      return 'N';
  
  end get_Attached_file_to_printer;  
  
  --------------------------------------------------------------------
  --  name:            get_printer_and_contract_info
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   13/05/2015
  --------------------------------------------------------------------
  --  purpose :        function that get serial number and contract SO line id
  --                   and retun IB info  
  --                   CHG0034234 - Update PTO Validation Setup  
  --
  --                   NOTE!!! - this procedure will use from several places.
  --                   if it will call from trigger XXOE_ORDER_LINES_ALL_BUR_TRG2
  --                   the select can not use the table oe_order_lines_all - the trigger
  --                   entered into mutate stage and ignore the data.
  --                   when i used PRAGMA AUTONOMOUS_TRANSACTION - the
  --                   trigger show error of ORA-06519: active autonomous transaction detected and rolled back 
  --                   therefor the solution was to have 2 separete selects.   
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  13/05/2015  Dalit A. Raviv    initial build
  -------------------------------------------------------------------- 
  procedure get_printer_and_contract_info (p_serial_number     in  varchar2,
                                           p_so_line_id        in  number,
                                           p_entity            in  varchar2,
                                           p_instance_id       out varchar2,
                                           p_contract_end_date out date,
                                           p_sf_id             out varchar2,
                                           p_inventory_item_id in out number ) is
    
    --PRAGMA AUTONOMOUS_TRANSACTION; -- do not take off - this is must for the trigger to be able to work
  begin
    if p_entity <> 'TRIGGER' then
      select cii.instance_id, cii.contract_end_date, cii.attribute12 sf_id, cii.inventory_item_id 
      into   p_instance_id, p_contract_end_date,p_sf_id, p_inventory_item_id
      from   oe_order_lines_all       oola,
             xxcs_items_printers_v    pr,
             mtl_item_categories_v    mic_pr,
             mtl_item_categories_v    mic_sc,
             xxsf_csi_item_instances  cii
      where  pr.inventory_item_id     = mic_pr.inventory_item_id
      and    oola.cancelled_quantity  = 0 
      and    mic_sc.inventory_item_id = oola.inventory_item_id
      and    mic_pr.organization_id   = 91
      and    mic_pr.category_set_name = 'Product Hierarchy'
      and    mic_sc.organization_id   = 91
      and    mic_sc.category_set_name = 'Product Hierarchy'
      and    mic_sc.segment2          = mic_pr.segment2
      and    mic_sc.segment3          in(mic_pr.segment3,mic_pr.segment2)
      and    mic_sc.segment4          = mic_pr.segment4
      and    mic_pr.inventory_item_id = cii.inventory_item_id
      and    cii.serial_number        = p_serial_number
      and    oola.line_id             = p_so_line_id;
    else
      -- this is called from trigger XXOE_ORDER_LINES_ALL_BUR_TRG2
      -- if i use oola table at the select the trigger enter into mutate stage and ignor data.
      select cii.instance_id, cii.contract_end_date, cii.attribute12 sf_id, cii.inventory_item_id 
      into   p_instance_id, p_contract_end_date,p_sf_id, p_inventory_item_id
      from   xxcs_items_printers_v    pr,
             mtl_item_categories_v    mic_pr,
             mtl_item_categories_v    mic_sc,
             xxsf_csi_item_instances  cii
      where  pr.inventory_item_id     = mic_pr.inventory_item_id
      and    mic_pr.organization_id   = 91
      and    mic_pr.category_set_name = 'Product Hierarchy'
      and    mic_sc.organization_id   = 91
      and    mic_sc.category_set_name = 'Product Hierarchy'
      and    mic_sc.segment2          = mic_pr.segment2
      and    mic_sc.segment3          in(mic_pr.segment3,mic_pr.segment2)
      and    mic_sc.segment4          = mic_pr.segment4
      and    mic_pr.inventory_item_id = cii.inventory_item_id
      and    cii.serial_number        = p_serial_number
      and    mic_sc.INVENTORY_ITEM_Id = p_inventory_item_id;
    end if;
  exception
    when others then   
      p_instance_id       := null;
      p_contract_end_date := null;
      p_sf_id             := null; 
      p_inventory_item_id := null; 
  end get_printer_and_contract_info; 
                           
end XXCSI_UTILS_PKG;
/
