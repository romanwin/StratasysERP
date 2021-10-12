create or replace package body XXCS_PZ2OA_INTF_PKG is

--------------------------------------------------------------------
-- name:            XXCS_PZ2OA_INTF_PKG
-- create by:       Dalit A. Raviv
-- Revision:        1.0 
-- creation date:   22/05/2011 2:57:40 PM
--------------------------------------------------------------------
-- purpose :        CUST419 - PZ2Oracle interface for UG upgrade in IB
--------------------------------------------------------------------
-- ver  date        name             desc
-- 1.0  22/05/2011  Dalit A. Raviv   initial build
-- 1.1  12/06/2011  Dalit A. Raviv   Check Close SR only for HW.
-- 1.2  16/06/2011  Dalit A. Raviv   Add condition to procedure initiate_ib_update
--------------------------------------------------------------------
  
  --------------------------------------------------------------------
  -- name:            upd_interface_errors
  -- create by:       Dalit A. Raviv
  -- Revision:        1.0 
  -- creation date:   22/05/2011 2:57:40 PM
  --------------------------------------------------------------------
  -- purpose :        update interface table with errors (xxcs_pz2oa_intf)
  --------------------------------------------------------------------
  -- ver  date        name             desc
  -- 1.0  22/05/2011  Dalit A. Raviv   initial build
  --------------------------------------------------------------------
  procedure upd_interface_errors (p_record_status  in  varchar2,
                                  p_error_message  in  varchar2,
                                  p_transaction_id in  number,
                                  p_err_code       out varchar2,
                                  p_err_desc       out varchar2) is
                                  
    PRAGMA AUTONOMOUS_TRANSACTION;
    
  begin
    p_err_code := 0;
    p_err_desc := null;
    update xxcs_pz2oa_intf      xpi
    set    xpi.record_status    = p_record_status, --'E',
           xpi.error_message    = case when xpi.error_message is null then
                                    p_error_message
                                  else
                                    xpi.error_message||chr(10)||p_error_message
                                  end,
           xpi.last_update_date = sysdate
    where  xpi.transaction_id   = p_transaction_id;
      
    commit; 
  exception
    when others then
      p_err_code := 1;
      p_err_desc := 'Gen Exc - upd_interface_errors - '||substr(sqlerrm,1,240);   
  end upd_interface_errors;
  
  --------------------------------------------------------------------
  -- name:            ins_interface_row
  -- create by:       Dalit A. Raviv
  -- Revision:        1.0 
  -- creation date:   30/05/2011 2:57:40 PM
  --------------------------------------------------------------------
  -- purpose :        insert row to interface table(xxcs_pz2oa_intf)
  --------------------------------------------------------------------
  -- ver  date        name             desc
  -- 1.0  30/05/2011  Dalit A. Raviv   initial build
  --------------------------------------------------------------------
  procedure ins_interface_row (p_system_sn         in  varchar2,
                               p_hasp_sn           in  varchar2,
                               p_transaction_date  in  date,
                               p_transaction_type  in  varchar2,
                               p_file_name         in  varchar2,
                               p_bpel_instance_id  in  number,
                               p_err_code          out varchar2,
                               p_err_msg           out varchar2) is
    
    PRAGMA AUTONOMOUS_TRANSACTION;
    
    l_transaction_id number := null;
    l_user_id        number := null;
  begin
    p_err_code := 0;
    p_err_msg  := null;
    -- get transaction_id
    select xxcs_pz2oa_intf_s.nextval
    into   l_transaction_id
    from   dual;
    -- get user id
    select user_id
    into   l_user_id
    from   fnd_user
    where  user_name = 'PZ_INTF';
    -- insert row
    insert into xxcs_pz2oa_intf (transaction_id,
                                 system_sn,
                                 hasp_sn,
                                 transaction_date,
                                 transaction_type,
                                 file_name,
                                 bpel_instance_id,
                                 record_status,
                                 error_message,
                                 last_update_date,
                                 last_updated_by,
                                 last_update_login,
                                 creation_date,created_by)
    values                      (l_transaction_id,
                                 trim(p_system_sn),
                                 trim(p_hasp_sn),
                                 p_transaction_date,
                                 p_transaction_type,
                                 p_file_name,
                                 p_bpel_instance_id,
                                 'N',
                                 null,
                                 sysdate,
                                 l_user_id,
                                 -1,
                                 sysdate,
                                 l_user_id
                                );
    commit;
  exception
    when others then 
      p_err_code := 1;
      p_err_msg  := 'ERR GEN - ins_interface_row - '||substr(sqlerrm,1,240);  
  end ins_interface_row;
  
  --------------------------------------------------------------------
  --  name:            handle_duplicate_rows
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   05/06/2011
  --------------------------------------------------------------------
  --  purpose :        This procedure check if this transaction allready 
  --                   done. If Yes update interface table.
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  05/06/2011  Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  procedure handle_duplicate_rows ( p_transaction_id  in  number,
                                    x_return_status   in  out varchar2,
                                    x_err_msg         in  out varchar2) is
    
    cursor get_pop_c is
      select * 
      from   xxcs_pz2oa_intf   xpi
      where  xpi.transaction_id = p_transaction_id;
  
    l_count number := 0;
  
  begin
    x_return_status := 'S';
     x_err_msg      := null;
    for get_pop_r in get_pop_c loop
      select count(1)
      into   l_count
      from   xxcs_pz2oa_intf      xpi
      where  xpi.record_status    = 'S'
      and    xpi.old_instance_id  = get_pop_r.old_instance_id
      and    xpi.upgrade_kit      = get_pop_r.upgrade_kit;
      
      if l_count <> 0 then
        update xxcs_pz2oa_intf      xpi
        set    xpi.record_status    = 'S',
               xpi.error_message    = 'Duplicate Transaction',
               xpi.last_update_date = sysdate
        where  xpi.transaction_id   = get_pop_r.transaction_id;
        
        commit;
        x_return_status := 'E';
      end if;
    end loop;
  exception
    when others then 
      x_return_status := 'E';
      x_err_msg       := 'GEN EXC - handle_duplicate_rows - '||substr(sqlerrm,1,240);
  end handle_duplicate_rows;
  
  --------------------------------------------------------------------
  --  name:            update_item_instance
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   27/03/2011 10:42:40 AM
  --------------------------------------------------------------------
  --  purpose :        Procedure update item instance
  --                   For association of the instance we need to do it by update.
  --                   
  --  In param:        p_old_instance_id
  --                   p_new_instance_id
  --  Out Param:       p_err_code
  --                   p_err_msg
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  27/03/2011  Dalit A. Raviv    initial build
  -------------------------------------------------------------------- 
  procedure update_item_instance (p_HASP_instance_id in  number,
                                  p_new_HASP_item_id in  number,
                                  p_upgrade_kit      in  number,
                                  p_err_code         out varchar2,
                                  p_err_msg          out varchar2) is
       
    l_instance_rec           CSI_DATASTRUCTURES_PUB.INSTANCE_REC;
    l_ext_attrib_values      CSI_DATASTRUCTURES_PUB.EXTEND_ATTRIB_VALUES_TBL;
    l_party_tbl              CSI_DATASTRUCTURES_PUB.PARTY_TBL;
    l_account_tbl            CSI_DATASTRUCTURES_PUB.PARTY_ACCOUNT_TBL;
    l_pricing_attrib_tbl     CSI_DATASTRUCTURES_PUB.PRICING_ATTRIBS_TBL;
    l_org_assignments_tbl    CSI_DATASTRUCTURES_PUB.ORGANIZATION_UNITS_TBL;
    l_asset_assignment_tbl   CSI_DATASTRUCTURES_PUB.INSTANCE_ASSET_TBL;
    l_txn_rec                CSI_DATASTRUCTURES_PUB.TRANSACTION_REC;
    l_instance_id_lst        CSI_DATASTRUCTURES_PUB.ID_TBL;
    l_return_status          VARCHAR2(2000);
    l_msg_count              NUMBER;
    l_msg_data               VARCHAR2(2000);
    l_msg_index_out          NUMBER;
    
    l_attribute_id           number;
    l_attribute_value        varchar2(240) := null;
    l_ext_attribute_value_id number        := null;
    
    --l_instance_party_id number;
    --l_party_ind         number;
  begin
    
    --Ext attribute2:
    l_attribute_id := null;
    begin
      select cie.attribute_id
      into   l_attribute_id
      from   csi_i_extended_attribs cie
      where  cie.attribute_code = 'OBJ_HASP_SV'
      and    cie.inventory_item_id = p_new_HASP_item_id; -- &inv_item_id of the new hasp
    exception
      when others then
        l_attribute_id := null;
        fnd_file.put_line(fnd_file.log,'ERR5 - create NEW HASP ext attributes - failed find attribute id2');
    end;
        
    l_attribute_value := null;
        
    if l_attribute_id is not null then
      begin
        --attribute_value:
        select v.sw_version 
        into   l_attribute_value
        from   xxcs_sales_ug_items_v v
        where  v.upgrade_item_id = p_upgrade_kit; --&Upgrade inv_item_id
      exception
        when others then
          l_attribute_value := null;
          fnd_file.put_line(fnd_file.log,'ERR6 - create NEW HASP ext attributes - failed find attribute value');
      end;
       
      select csi_iea_values_s.NEXTVAL
          into   l_ext_attribute_value_id
          from   dual;
          
      l_ext_attrib_values(2).attribute_value_id := l_ext_attribute_value_id;
      l_ext_attrib_values(2).instance_id        := p_HASP_instance_id;
      l_ext_attrib_values(2).attribute_id       := l_attribute_id;
      l_ext_attrib_values(2).attribute_code     := 'OBJ_HASP_SV';
      l_ext_attrib_values(2).attribute_value    := l_attribute_value;
      l_ext_attrib_values(2).active_start_date  := SYSDATE;
    end if;    

    l_txn_rec.transaction_id          := NULL;
    l_txn_rec.transaction_date        := SYSDATE;
    l_txn_rec.source_transaction_date := SYSDATE;
    l_txn_rec.transaction_type_id     := 1; 

    -- Now call the stored program
    csi_item_instance_pub.update_item_instance( 1.0,
                                                'F',
                                                'F',
                                                1,
                                                l_instance_rec,
                                                l_ext_attrib_values,
                                                l_party_tbl,
                                                l_account_tbl,
                                                l_pricing_attrib_tbl,
                                                l_org_assignments_tbl,
                                                l_asset_assignment_tbl,
                                                l_txn_rec,
                                                l_instance_id_lst,
                                                l_return_status,
                                                l_msg_count,
                                                l_msg_data);


    if l_return_status != apps.fnd_api.g_ret_sts_success then        
      fnd_msg_pub.get(p_msg_index     => -1,
                      p_encoded       => 'F',
                      p_data          => l_msg_data,
                      p_msg_index_out => l_msg_index_out);
         
      dbms_output.put_line('ERR7 - update_HASP_item_instance - : '||substr(l_msg_data,1,240)); 
      fnd_file.put_line(fnd_file.log,
                        'ERR7 - update_HASP_item_instance - : '||l_msg_data);

      p_err_code := 1;
      p_err_msg  := 'ERR7 - update_HASP_item_instance - : '||substr(l_msg_data,1,240);                         
        
    else
      p_err_code := 0;
      p_err_msg  := null;
    end if;
  
  exception
    when others then
      p_err_code := 1;
      p_err_msg  := 'GEN EXC - update_item_instance - '||substr(sqlerrm,1, 240);
      
  end update_item_instance;
/*
  --------------------------------------------------------------------
  -- name:            handle_SW_upgrade
  -- create by:       Dalit A. Raviv
  -- Revision:        1.0 
  -- creation date:   25/05/2011 2:57:40 PM
  --------------------------------------------------------------------
  -- purpose :        Handle SW upgrade
  --------------------------------------------------------------------
  -- ver  date        name             desc
  -- 1.0  25/05/2011  Dalit A. Raviv   initial build
  --------------------------------------------------------------------
  procedure handle_SW_upgrade (p_system_sn      in  varchar2,-- old parent instance SN
                               p_transaction_id in  number,
                               p_instance_id    in  number, -- old parent instance id
                               p_upgrade_kit    in  number, -- new item id 
                               p_err_code       out varchar2,
                               p_err_desc       out varchar2) is
    l_err_code                 number           := 0;
    l_err_desc                 varchar2(2000)   := null;
    l_HASP_inventory_item_id   number           := null;
    l_Hasp_instance_id         number           := null;
    l_NEW_HASP_item_id         number           := null;
    l_hasp_sn                  varchar2(30)     := null;
    general_exception          exception;
  begin
    p_err_code := 0;
    p_err_desc := null;
    -- Get Hasp_sn
    select xpi.hasp_sn
    into   l_hasp_sn
    from   xxcs_pz2oa_intf    xpi
    where  xpi.transaction_id = p_transaction_id;   
    
    -- By the parent serial number look if there is an HASP item.
    -- Return the HASP instance id and Item Id if exists 
    XXCSI_IB_AUTO_UPGRADE_PKG.get_SW_HASP_exist (p_old_instance_id        => p_instance_id,            -- i n
                                                 p_Hasp_instance_id       => l_Hasp_instance_id,       -- o n 
                                                 p_HASP_inventory_item_id => l_HASP_inventory_item_id, -- o n 
                                                 p_error_code             => l_err_code,               -- o v
                                                 p_error_desc             => l_err_desc);              -- o v
    
    if l_err_code <> 0 then
      upd_interface_errors (p_record_status  => 'E',              -- i v
                            p_error_message  => l_err_desc,       -- i v
                            p_transaction_id => p_transaction_id, -- i n
                            p_err_code       => l_err_code,       -- o v
                            p_err_desc       => l_err_desc);      -- o v 
                              
      p_err_code := 1;
      p_err_desc := l_err_desc;
      raise      general_exception;
    end if;  
     
    l_err_code := 0;
    l_err_desc := null; 
    -- By the parent serial number get the upgrade kit(item id) that can change.
    -- Return the HASP Item Id if exists    
    XXCSI_IB_AUTO_UPGRADE_PKG.get_HASP_after_upgrade (p_upgrade_kit      => p_upgrade_kit,      --i n  
                                                      p_NEW_HASP_item_id => l_NEW_HASP_item_id, --o n 
                                                      p_errr_code        => l_err_code,         --o v 
                                                      p_errr_desc        => l_err_desc);        --o v  
                                                           
    if l_err_code <> 0 then
      upd_interface_errors (p_record_status  => 'E',              -- i v
                            p_error_message  => l_err_desc,       -- i v
                            p_transaction_id => p_transaction_id, -- i n
                            p_err_code       => l_err_code,       -- o v
                            p_err_desc       => l_err_desc);      -- o v 
                              
      p_err_code := 1;
      p_err_desc := l_err_desc;
      raise      general_exception;
    end if; 
    -- If Hasp item id that found attach to the old printer
    -- equal to the hasp item id from the upgrade kit
    -- only need to update the external attributes
    -- if not equal need to create new hasp to the upgrade printer.
    if l_HASP_inventory_item_id = l_NEW_HASP_item_id then
      l_err_code := 0;
      l_err_desc := null; 
      -- procedure that only update item instance and update the extnded attributes.
      -- !!!!!!!!!!!!!! to compare hasp_sn from interface to serial number of l_Hasp_instance_id
      -- if not compare failure .   
      XXCSI_IB_AUTO_UPGRADE_PKG.main(errbuf              => l_err_desc,
                                     retcode             => l_err_code,
                                     p_entity            => 'MANUAL',
                                     p_instance_id       => l_Hasp_instance_id,
                                     p_inventory_item_id => l_NEW_HASP_item_id,
                                     p_hasp_sn           => l_hasp_sn,  ---!!!!!!!!!!!!!!!!!!!!!
                                     --p_System_sn         => p_system_sn, -- to take off
                                     p_user_name         => 'PZ_INTF',
                                     p_SW_HW             => 'SW_UPG');                                 
      
      if l_err_code <> 0 then
                                
        p_err_code := 1;
        p_err_desc := l_err_desc;
        raise      general_exception;
      end if; 
    else
      -- create new HASP + new Relationship
      XXCSI_IB_AUTO_UPGRADE_PKG.main(errbuf              => l_err_desc,
                                     retcode             => l_err_code,
                                     p_entity            => 'MANUAL',
                                     p_instance_id       => p_instance_id,
                                     p_inventory_item_id => p_upgrade_kit,
                                     p_hasp_sn           => l_hasp_sn,
                                     --p_System_sn         => l_pz2oa_rec.system_sn, -- to take off
                                     p_user_name         => 'PZ_INTF',
                                     p_SW_HW             => 'SW_NEW');
      if l_err_code <> 0 then
                                
        p_err_code := 1;
        p_err_desc := l_err_desc;
        raise      general_exception;
      end if;
    end if; -- hasp_item_id before and after upgrade                             
    
  exception
    when general_exception then
      null;
    when others then
      p_err_code := 1;
      p_err_desc := 'Gen Exc - handle_SW_upgrade - '||substr(sqlerrm,1,240);
  end handle_SW_upgrade;
*/                                
                                    
  --------------------------------------------------------------------
  --  name:            process_pz2oa_request
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   22/05/2011
  --------------------------------------------------------------------
  --  purpose :        Call Bpell Process to start process    
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  22/05/2011  Dalit A. Raviv  initial build
  --  1.1  12/06/2011  Dalit A. Raviv  Check Close SR only for HW.
  --  1.2  14/07/2011  Dalit A. Raviv  no need to check SR exist any more
  --                                   since we will use csi_item_instance_pub.update_item_instance
  --                                   to change inventory_item id
  --------------------------------------------------------------------
  procedure process_pz2oa_request(p_transaction_id in number,
                                  x_return_status  in out varchar2,
                                  x_err_msg        in out varchar2) is
    
    l_pz2oa_rec              xxcs_pz2oa_intf%rowtype; 
    l_upgrade_type           varchar2(100) := null;
    l_upgrade_kit            number        := null;
    l_old_instance_id        number        := null;
    l_err_code               number        := 0;
    l_err_desc               varchar2(2000):= null;
    l_return_status          varchar2(5)   := null;
        
    general_exception exception;                              
  begin
    x_return_status := 'S';
    x_err_msg       := null;
    
    -- get record information
    select *
    into   l_pz2oa_rec
    from   xxcs_pz2oa_intf    xpi
    where  xpi.transaction_id = p_transaction_id; 
        
    -- determin upgrade type according to SYSTEM_SN of the printer from interface table.
    XXCSI_IB_AUTO_UPGRADE_PKG.get_upgrade_type (p_serial_number   => l_pz2oa_rec.system_sn, -- i v
                                                p_upgrade_type    => l_upgrade_type,        -- o v
                                                p_upgrade_kit     => l_upgrade_kit,         -- o n
                                                p_old_instance_id => l_old_instance_id);    -- o n 
    begin
      update xxcs_pz2oa_intf      xpi
      set    xpi.old_instance_id  = l_old_instance_id,
             xpi.upgrade_kit      = l_upgrade_kit,
             xpi.last_update_date = sysdate
      where  xpi.transaction_id   = p_transaction_id;
          
      commit;
    exception
      when others then 
        null;
    end;
    
    handle_duplicate_rows ( p_transaction_id  => p_transaction_id, -- i   v
                            x_return_status   => l_return_status,  -- i/o v
                            x_err_msg         => l_err_desc);      -- i/o v
    
    if l_return_status = 'E' then
      raise general_exception;
    end if;
    
    -- Handle error if there are
    if l_upgrade_type not in ('HW', 'SW') then
      upd_interface_errors (p_record_status  => 'E',              -- i v
                            p_error_message  => l_upgrade_type,   -- i v
                            p_transaction_id => p_transaction_id, -- i n
                            p_err_code       => l_err_code,       -- o v
                            p_err_desc       => l_err_desc);      -- o v 
      -- update interface
      x_return_status  := 'E';
      x_err_msg        := l_upgrade_type;
      raise general_exception;
    elsif l_upgrade_type = 'HW'then
      l_err_desc := null;
      l_err_code := 0;
      XXCSI_IB_AUTO_UPGRADE_PKG.main(errbuf              => l_err_desc,
                                     retcode             => l_err_code,
                                     p_entity            => 'MANUAL',
                                     p_instance_id       => l_old_instance_id,
                                     p_inventory_item_id => l_upgrade_kit,
                                     p_hasp_sn           => l_pz2oa_rec.hasp_sn,
                                     p_user_name         => 'PZ_INTF',
                                     p_SW_HW             => 'HW');
      if l_err_code = 1 then
        ROLLBACK;
        x_return_status := 'E';
        x_err_msg       := l_err_desc;
        upd_interface_errors (p_record_status  => 'E',              -- i v
                              p_error_message  => l_err_desc,       -- i v
                              p_transaction_id => p_transaction_id, -- i n
                              p_err_code       => l_err_code,       -- o v
                              p_err_desc       => l_err_desc);      -- o v 
        
      else
        COMMIT;
        x_return_status := 'S';
        x_err_msg       := NULL;
        upd_interface_errors (p_record_status  => 'S',              -- i v
                              p_error_message  => l_err_desc,       -- i v
                              p_transaction_id => p_transaction_id, -- i n
                              p_err_code       => l_err_code,       -- o v
                              p_err_desc       => l_err_desc);      -- o v 
        
      end if;
    elsif l_upgrade_type = 'SW'then
      
      l_err_desc := null;
      l_err_code := 0;
        
      XXCSI_IB_AUTO_UPGRADE_PKG.main(errbuf              => l_err_desc,
                                     retcode             => l_err_code,
                                     p_entity            => 'MANUAL',
                                     p_instance_id       => l_old_instance_id,
                                     p_inventory_item_id => l_upgrade_kit,
                                     p_hasp_sn           => l_pz2oa_rec.hasp_sn,
                                     p_user_name         => 'PZ_INTF',
                                     p_SW_HW             => 'SW');
              
      if l_err_code = 1 then
        ROLLBACK;
        x_return_status := 'E';
        x_err_msg       := l_err_desc;
        upd_interface_errors (p_record_status  => 'E',              -- i v
                                p_error_message  => l_err_desc,       -- i v
                                p_transaction_id => p_transaction_id, -- i n
                                p_err_code       => l_err_code,       -- o v
                                p_err_desc       => l_err_desc);      -- o v 
      ELSE
        COMMIT;
        x_return_status := 'S';
        x_err_msg       := NULL;
        upd_interface_errors (p_record_status  => 'S',              -- i v
                              p_error_message  => l_err_desc,       -- i v
                              p_transaction_id => p_transaction_id, -- i n
                              p_err_code       => l_err_code,       -- o v
                              p_err_desc       => l_err_desc);      -- o v 
      end if;                       
    end if;

  exception
    when general_exception then
      null;
    when others then  
      x_return_status := 'E';
      x_err_msg       := 'GEN EXC - process_pz2oa_request '||substr(sqlerrm,1,240);
  end process_pz2oa_request;                                  

  --------------------------------------------------------------------
  --  name:            process_pz2oa_request
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   29/05/2011
  --------------------------------------------------------------------
  --  purpose :        To be able to re run and correct data   
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  29/05/2011  Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  procedure process_pz2oa_request_conc(errbuf           out varchar2, 
                                       retcode          out number,
                                       p_transaction_id in  number) is
                                  
    l_return_status VARCHAR2(1);
  begin
    errbuf  := null;
    retcode := 0;
    process_pz2oa_request(p_transaction_id => p_transaction_id, -- i   n
                          x_return_status  => l_return_status,  -- i/o v
                          x_err_msg        => errbuf);          -- i/o v                            
                           
    if l_return_status != fnd_api.g_ret_sts_success then
      retcode := 1;
    end if;
  end process_pz2oa_request_conc;

  --------------------------------------------------------------------
  --  name:            call_bpel_process
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   22/05/2011
  --------------------------------------------------------------------
  --  purpose :        Call Bpell Process to start process    
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  22/05/2011  Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  PROCEDURE call_bpel_process (errbuf OUT VARCHAR2, retcode OUT NUMBER) is
  
    l_in_process        varchar2(1) := 'N';
    service_            sys.utl_dbws.service;
    call_               sys.utl_dbws.CALL;
    service_qname       sys.utl_dbws.qname;
    response            sys.xmltype;
    request             sys.xmltype;
    l_string_type_qname sys.utl_dbws.qname;
    l_error             varchar2(1000);
    l_jndi_name         varchar2(50);
    
  begin
    retcode := 0;
    errbuf  := null;
    
    l_jndi_name := xxobjt_bpel_utils_pkg.get_jndi_name(NULL);
    
    -- check for running or stack processes
    begin
    
      select distinct 'Y'
      into   l_in_process
      from   xxcs_pz2oa_intf
      where  record_status = 'P'
      and    rownum < 2;
    
      retcode := 1;
      errbuf  := 'There are transactions in process, terminating program';
      return;
    
    exception
      when no_data_found then
        null;
        --v_in_process := 'n';
      when too_many_rows then
        retcode := 1;
        errbuf  := 'There are transactions in process, terminating program';
        return;
    end;
    
    --call bpel process xxPZ2OACallScript
    begin
      service_qname := sys.utl_dbws.to_qname('http://xmlns.oracle.com/xxPZ2OACallScript','xxPZ2OACallScript');
    
      l_string_type_qname := sys.utl_dbws.to_qname('http://www.w3.org/2001/XMLSchema','string');
      service_            := sys.utl_dbws.create_service(service_qname);
      call_               := sys.utl_dbws.create_call(service_);
      sys.utl_dbws.set_target_endpoint_address(call_,
                                               'http://soaprodapps.2objet.com:7777/orabpel/' ||
                                               xxagile_util_pkg.get_bpel_domain ||'/xxPZ2OACallScript/1.0');
    
      sys.utl_dbws.set_property(call_, 'SOAPACTION_USE', 'TRUE');
      sys.utl_dbws.set_property(call_, 'SOAPACTION_URI', 'process');
      sys.utl_dbws.set_property(call_, 'OPERATION_STYLE', 'document');
      sys.utl_dbws.set_property(call_, 'ENCODINGSTYLE_URI', 'http://schemas.xmlsoap.org/soap/encoding/');
      sys.utl_dbws.add_parameter(call_,
                                 'JndiName',
                                 l_string_type_qname,
                                 'ParameterMode.IN');
    
      sys.utl_dbws.set_return_type(call_, l_string_type_qname);
    /*
      -- Set the input
      request := sys.xmltype('<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' ||
                             '    <soap:Body xmlns:ns1="http://xmlns.oracle.com/xxPZ2OACallScript">' ||
                             '        <ns1:xxPZ2OACallScriptProcessRequest>' ||
                             '            <ns1:jndi_name>' || l_jndi_name || '</ns1:jndi_name>' ||
                             '        </ns1:xxPZ2OACallScriptProcessRequest>' ||
                             '    </soap:Body>' || '</soap:Envelope>');*/

      request := sys.xmltype('<ns1:xxPZ2OACallScriptProcessRequest xmlns:ns1="http://xmlns.oracle.com/xxPZ2OACallScript">
                               <ns1:jndi_name>' || l_jndi_name || '</ns1:jndi_name>' ||
                             '</ns1:xxSF2OA_interfacesProcessRequest>');                            
    
      response := sys.utl_dbws.invoke(call_, request);
      sys.utl_dbws.release_call(call_);
      sys.utl_dbws.release_service(service_);
      l_error := response.getstringval();
      if response.getstringval() like '%Error%' then
        retcode := 2;
        errbuf  := Replace(replace(substr(l_error,
                                          instr(l_error, 'instance') + 10,
                                          length(l_error)),
                                   '</OutPut>',
                                   null),
                           '</processResponse>',
                           null);
      end if;
      --dbms_output.put_line(response.getstringval()); 
    exception
      when others then
        l_error := substr(SQLERRM, 1, 250);
        retcode := '2';
        errbuf  := 'Error Run Bpel Process - xxPZ2OACallScript: ' || l_error;
        sys.utl_dbws.release_call(call_);
        sys.utl_dbws.release_service(service_);
    end;
  
  end call_bpel_process;
  
  --------------------------------------------------------------------
  --  name:            initiate_IB_update_conc
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   29/05/2011
  --------------------------------------------------------------------
  --  purpose :        To be able to re run and correct data
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  29/05/2011  Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  procedure initiate_ib_update_conc (errbuf            out varchar2, 
                                     retcode           out number,
                                     p_request_status  in  varchar2 default null,
                                     p_serial_number   in  varchar2 default null) is
    l_return_status VARCHAR2(1);
  begin
    errbuf  := null;
    retcode := 0;
    initiate_ib_update(p_request_status  => p_request_status, -- i   v
                       p_serial_number   => p_serial_number,  -- i   v
                       x_return_status   => l_return_status,  -- i/o v
                       x_err_msg         => errbuf);          -- i/o v
      
    if l_return_status != fnd_api.g_ret_sts_success then
      retcode := 1;
    end if;
  end initiate_ib_update_conc;   
  
  --------------------------------------------------------------------
  --  name:            initiate_IB_update
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   23/05/2011
  --------------------------------------------------------------------
  --  purpose :        Start process data  
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  23/05/2011  Dalit A. Raviv  initial build
  --  1.1  16/05/2011  Dalit A. Raviv  add condition - to take only rows that are
  --                                   created a week ago
  --------------------------------------------------------------------
  procedure initiate_ib_update (p_request_status  in  varchar2 default null,
                                p_serial_number   in  varchar2 default null,
                                x_return_status   in  out varchar2,
                                x_err_msg         in  out varchar2) is 
  
    t_transaction_id_tbl t_number_type;
    l_exists             number;
    l_count              number;
    
  begin
    --errbuf  := null;
    --retcode := 0;  
    
    update xxcs_pz2oa_intf   xpi
    set    xpi.record_status = 'P'
    where  record_status     = nvl(p_request_status,'N')
    and    xpi.system_sn     = nvl(p_serial_number,xpi.system_sn)
    and    xpi.creation_date < sysdate -7
    returning xpi.transaction_id bulk collect into t_transaction_id_tbl;
  
    COMMIT;
  
    for i in 1 .. t_transaction_id_tbl.count loop
      l_exists := 0;
      l_count  := 0;
      
      -- determin upgrade type according to SYSTEM_SN of the printer from interface table.
      process_pz2oa_request(t_transaction_id_tbl(i),    -- p_transaction_id i n
                            x_return_status,            -- i/o v
                            x_err_msg);                 -- i/o v
 
    end loop; 
    
  end initiate_ib_update;
  
end XXCS_PZ2OA_INTF_PKG;
/
