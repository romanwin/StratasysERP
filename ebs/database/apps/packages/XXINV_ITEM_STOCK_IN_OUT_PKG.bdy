create or replace package body XXINV_ITEM_STOCK_IN_OUT_PKG is

--------------------------------------------------------------------
--  name:             XXINV_ITEM_STOCK_IN_OUT_PKG
--  create by:        Dalit A. Raviv
--  Revision:         1.0
--  creation date:    24/AUG/2015 15:29:18
--------------------------------------------------------------------
--  purpose :         CHG0036084 - Filament Stock in Stock out
--------------------------------------------------------------------
--  ver  date         name              desc
--  1.0  24/AUG/2015  Dalit A. Raviv    initial build
--------------------------------------------------------------------
  
  g_batch_id    number;
  g_source_code varchar2(50) := 'CONVERT';
  
  --------------------------------------------------------------------
  --  name:             print_log
  --  create by:        Dalit A. RAviv
  --  Revision:         1.0
  --  creation date:    24/AUG/2015
  --------------------------------------------------------------------
  --  purpose :         Print message to log
  --------------------------------------------------------------------
  --  ver  date         name            desc
  --  1.0  24/AUG/2015  Dalit A. RAviv  initial build
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
  --  name:             print_out
  --  create by:        Dalit A. RAviv
  --  Revision:         1.0
  --  creation date:    24/AUG/2015
  --------------------------------------------------------------------
  --  purpose :         Print message to output
  --------------------------------------------------------------------
  --  ver  date         name            desc
  --  1.0  24/AUG/2015  Dalit A. RAviv  initial build
  --------------------------------------------------------------------
  procedure print_out(p_print_msg varchar2) is
  begin
    if fnd_global.conc_request_id = -1 then
      dbms_output.put_line(p_print_msg);
    else
      fnd_file.put_line(FND_FILE.OUTPUT,p_print_msg);
    end if;
  end print_out;
  
  --------------------------------------------------------------------
  --  name:             upd_log_messages
  --  create by:        Dalit A. Raviv
  --  Revision:         1.0
  --  creation date:    25/AUG/2014
  --------------------------------------------------------------------
  --  purpose :         Handle - upload of the excel file
  --  in params:        p_log_code - log code
  --                    p_log_msg  - log message
  --                    p_item_stock_id - unique identifier
  --------------------------------------------------------------------
  --  ver  date         name              desc
  --  1.0  24/AUG/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure upd_log_messages (errbuf          out varchar2,
                              retcode         out number,
                              p_log_code      in  varchar2,
                              p_log_msg       in  varchar2,
                              p_item_stock_id in  number) is
    
  begin
    retcode := 0;
    errbuf  := null;
    
    update XXINV_ITEM_STOCK_IN_OUT isiu
    set    isiu.log_code           = p_log_code,
           isiu.log_msg            = p_log_msg
    where  isiu.item_stock_id      = p_item_stock_id;
    
    commit;
  exception
    when others then 
      rollback;
      retcode := 1;
      errbuf  := 'GEN ERR - upd_log_messages - '||substr(sqlerrm,1,200);
  end upd_log_messages; 

  --------------------------------------------------------------------
  --  name:             upload_file
  --  create by:        Dalit A. Raviv
  --  Revision:         1.0
  --  creation date:    24/AUG/2014
  --------------------------------------------------------------------
  --  purpose :         Handle - upload of the excel file
  --  in params:        p_table_name    - XXINV_ITEM_STOCK_IN_OUT
  --                    p_template_name - OUT_IN
  --                    p_file_name     -
  --                    p_location      - /UtlFiles/shared/DEV (PROD)
  --------------------------------------------------------------------
  --  ver  date         name              desc
  --  1.0  24/AUG/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure upload_file(errbuf                         out varchar2,
                        retcode                        out varchar2,
                        p_table_name                   in varchar2, -- XXINV_ITEM_STOCK_IN_OUT
                        p_template_name                in varchar2, -- OUT_IN
                        p_file_name                    in varchar2,
                        p_directory                    in varchar2) is -- /UtlFiles/shared/DEV (PROD)

    l_errbuf        VARCHAR2(3000);
    l_retcode       VARCHAR2(3000);

    stop_processing EXCEPTION;
  begin
    errbuf  := 'Success';
    retcode := 0;

    -- Load data from CSV-table into XXHR_INTERFACES table
    xxobjt_table_loader_util_pkg.load_file(errbuf                 => l_errbuf,
                                           retcode                => l_retcode,
                                           p_table_name           => p_table_name,   -- 'XXINV_ITEM_STOCK_IN_OUT',
                                           p_template_name        => p_template_name,-- OUT_IN
                                           p_file_name            => p_file_name,
                                           p_directory            => p_directory,    -- /UtlFiles/shared/DEV
                                           p_expected_num_of_rows => NULL);

    if l_retcode <> '0' then
      fnd_file.put_line(fnd_file.log, l_errbuf);
      retcode := 2;
      errbuf  := l_errbuf;
      raise stop_processing;
    end if;

  exception
    when stop_processing then
      null;
    when others then
      errbuf   := 'GEN EXC - upload_file - '||substr(sqlerrm,1,200);
      retcode  := 1;
  end upload_file;

  --------------------------------------------------------------------
  --  name:             check_intransit
  --  create by:        Dalit A. Raviv
  --  Revision:         1.0
  --  creation date:    01/SEP/2015 15:29:18
  --------------------------------------------------------------------
  --  purpose :         CHG0036084 - Filament Stock in Stock out
  --                    This procedure check if item have reservation
  --                    if yes we can not proced the program for this item
  --------------------------------------------------------------------
  --  ver  date         name              desc
  --  1.0  01/SEP/2015  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure check_intransit (errbuf           out varchar2,
                             retcode          out number,
                             p_item_number    in  varchar2,
                             p_item_stock_id  in  number) is
                               
     l_errbuf  varchar2(2000) := null;
     l_retcode varchar2(100)  := 0;
     l_count   number         := 0;
     l_log_msg varchar2(2000) := null;
  begin
    errbuf  := null;
    retcode := 0;
    select count(1)
    into   l_count
    from   po.rcv_shipment_lines t
    where  t.shipment_line_status_code = 'EXPECTED'
    and    t.destination_type_code     = 'INVENTORY'
    and    t.item_id = apps.xxinv_utils_pkg.get_item_id (p_item_number);

    if l_count > 0 then
      -- update
      -- Error: Item has open In Transit shipments
      fnd_message.SET_NAME('XXOBJT', 'XXINV_STOCK_INOUT_EXIST_INTRAN');
      fnd_message.SET_TOKEN('ITEM', p_item_number);
      l_log_msg := fnd_message.get;
      upd_log_messages (errbuf          => l_errbuf,          -- o v
                        retcode         => l_retcode,         -- o v
                        p_log_code      => 'E',               -- i v
                        p_log_msg       => l_log_msg,         -- i v
                        p_item_stock_id => p_item_stock_id);  -- i n
    end if;

  end check_intransit;

  --------------------------------------------------------------------
  --  name:             check_reservation
  --  create by:        Dalit A. Raviv
  --  Revision:         1.0
  --  creation date:    25/AUG/2015 15:29:18
  --------------------------------------------------------------------
  --  purpose :         CHG0036084 - Filament Stock in Stock out
  --                    This procedure check if item have reservation
  --                    if yes we can not proced the program for this item
  --------------------------------------------------------------------
  --  ver  date         name              desc
  --  1.0  25/AUG/2015  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure check_reservation (errbuf           out varchar2,
                               retcode          out number,
                               p_item_number    in  varchar2,
                               p_item_stock_id  in  number) is

     l_errbuf  varchar2(2000) := null;
     l_retcode varchar2(100)  := 0;
     l_count   number         := 0;
     l_log_msg varchar2(2000) := null;
  begin
    errbuf  := null;
    retcode := 0;
    select count(1)
    into   l_count 
    from   mtl_reservations          rsv,
           mtl_system_items_b        msi
    where  rsv.supply_source_type_id = 13
    and    rsv.inventory_item_id     = msi.inventory_item_id
    and    msi.organization_id       = xxinv_utils_pkg.get_master_organization_id
    and    msi.segment1              = p_item_number;
      
    if l_count > 0 then
      -- update
      -- Reservations exists for item &ITEM, transactions cannot be performed
      fnd_message.SET_NAME('XXOBJT', 'XXINV_STOCK_INOUT_EXIST');
      fnd_message.SET_TOKEN('ITEM', p_item_number);
      l_log_msg := fnd_message.get;
      upd_log_messages (errbuf          => l_errbuf,          -- o v
                        retcode         => l_retcode,         -- o v
                        p_log_code      => 'E',               -- i v
                        p_log_msg       => l_log_msg,         -- i v
                        p_item_stock_id => p_item_stock_id);  -- i n
    else
      -- no reservation found
      -- change record status to P -> in-process
      upd_log_messages (errbuf          => l_errbuf,         -- o v
                        retcode         => l_retcode,        -- o v
                        p_log_code      => 'P',              -- i v
                        p_log_msg       => null,             -- i v
                        p_item_stock_id => p_item_stock_id); -- i n
    end if;
  
  end check_reservation;
  
  --------------------------------------------------------------------
  --  name:             complete_item_info
  --  create by:        Dalit A. Raviv
  --  Revision:         1.0
  --  creation date:    25/AUG/2015 15:29:18
  --------------------------------------------------------------------
  --  purpose :         CHG0036084 - Filament Stock in Stock out
  --                    This procedure complete item info and insert records
  --                    per each item per all suninventories.
  --                    each item can have several records, because it can exists at several subinv
  --------------------------------------------------------------------
  --  ver  date         name              desc
  --  1.0  25/AUG/2015  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure complete_item_info (errbuf           out varchar2,
                                retcode          out number,
                                p_item_number    in  varchar2,
                                p_new_lot_number in  varchar2,
                                p_batch_id       in  number) is  
  
    cursor c_items (p_item_number in varchar2) is
      -- items that are not serial control
      select moqd.organization_id,
             o.organization_code,
             moqd.inventory_item_id,
             moqd.subinventory_code,
             moqd.locator_id,
             moqd.revision,
             moqd.lot_number              lot_number, -- this is the original lot number
             null                         serial_number,
             sum(moqd.transaction_quantity)  qty,
             moqd.transaction_uom_code    uom
      from   mtl_onhand_quantities_detail moqd,
             inv.mtl_system_items_b       msib,
             mtl_parameters               o
      where  msib.segment1                = p_item_number   
      and    moqd.inventory_item_id       = msib.inventory_item_id
      and    moqd.organization_id         = msib.organization_id
      and    moqd.organization_id         = o.organization_id
      and    msib.serial_number_control_code not in (2, 5, 6)
      group by moqd.organization_id,
               o.organization_code,
               moqd.inventory_item_id,
               moqd.subinventory_code,
               moqd.locator_id,
               moqd.revision,
               moqd.lot_number,moqd.transaction_uom_code
      union all
      -- Item That are serial
      select msn.current_organization_id,
             o.organization_code,
             msn.inventory_item_id,
             msn.current_subinventory_code,
             msn.current_locator_id,
             msn.revision, 
             null                         lot_number, -- original lot number
             msn.serial_number            serial_number,
             1                            qty,
             msi.primary_uom_code         uom
      from   mtl_serial_numbers           msn,
             mtl_parameters               o,
             mtl_system_items_b           msi
      where  msn.current_organization_id  = o.organization_id
      and    msn.current_status           = 3
      and    msn.inventory_item_id        = msi.inventory_item_id
      and    msi.organization_id          = o.master_organization_id
      and    msi.segment1                 = p_item_number;
   
  begin
    errbuf  := null;
    retcode := 0;
    for r_items in c_items (p_item_number) loop
      begin
        insert into XXINV_ITEM_STOCK_IN_OUT
               (item_stock_id,
                organization_id,
                organization_code,
                inventory_item_id,
                item_number,
                account_id,
                subinventory_code,
                locator_id,
                item_revision,
                original_lot_number,
                new_lot_number, 
                serial_number,
                qty,
                uom,
                trx_type_id, 
                trx_action_id, 
                trx_source_type_id,
                stage,
                batch_id,
                log_code,
                log_msg,
                trx_to_intf_flag,
                trx_to_intf_date,
                trx_interface_id, 
                last_update_date,
                last_updated_by,
                last_update_login,
                creation_date,
                created_by 
               )
        values (XXINV_ITEM_STOCK_IN_OUT_S.Nextval,
                r_items.organization_id,
                r_items.organization_code,
                r_items.inventory_item_id,
                p_item_number,
                null,
                r_items.subinventory_code,
                r_items.locator_id,
                r_items.revision,
                r_items.lot_number,
                p_new_lot_number,     -- from the excel
                r_items.serial_number,
                r_items.qty,
                r_items.uom,
                null,null,null,
                'OUT',
                p_batch_id,
                'N',
                null,null,null,null,
                sysdate,
                fnd_global.USER_ID,
                fnd_global.LOGIN_ID,
                sysdate,
                fnd_global.USER_ID
               );
         commit;
       exception
         when others then
           rollback;
           errbuf  := 'Err insert record complete_item_info. Org '||r_items.organization_code
                      ||', Item '||p_item_number||', Subinv '||r_items.subinventory_code
                      ||', Locator '||r_items.locator_id
                      ||substr(sqlerrm,1,200);
           retcode := 1;
           print_out('Err insert record complete_item_info. Org '||r_items.organization_code
                      ||', Item '||p_item_number||', Subinv '||r_items.subinventory_code
                      ||', Locator '||r_items.locator_id
                      ||substr(sqlerrm,1,200));
       end;
    end loop;
    
  exception
    when others then
      errbuf  := 'GEN EXC - complete_item_info - '||substr(sqlerrm,1,200);
      retcode := 1;
  end complete_item_info;
  
  --------------------------------------------------------------------
  --  name:             upd_account_id
  --  create by:        Dalit A. Raviv
  --  Revision:         1.0
  --  creation date:    26/AUG/2015 15:29:18
  --------------------------------------------------------------------
  --  purpose :         CHG0036084 - Filament Stock in Stock out
  --                    update account id for all items from the same organization
  --------------------------------------------------------------------
  --  ver  date         name              desc
  --  1.0  26/AUG/2015  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure upd_account_id (errbuf              out varchar2,
                            retcode             out varchar2,
                            p_organization_id   in  number,
                            p_organization_code in varchar2,
                            p_batch_id          in  number,
                            p_log_code          in  varchar2) is
    
    cursor c_err_pop is
      select isiu.item_stock_id
      from   XXINV_ITEM_STOCK_IN_OUT isiu
      where  isiu.batch_id           = p_batch_id
      and    isiu.log_code           = p_log_code
      and    isiu.organization_id    = p_organization_id;
  
    l_account_id number := null;
    l_log_msg    varchar2(2000) := null;
    l_retcode    varchar2(100);        
    l_errbuf     varchar2(2000);
  
  begin
    errbuf   := null;
    retcode  := 0;    
    -- Get account id
    select --t.distribution_account   account_id 
           t.disposition_id         account_id
    into   l_account_id               
    from   mtl_generic_dispositions t                             
    where  upper(t.segment1)        = 'CONVERT' 
    and    nvl(t.disable_date,(sysdate + 1)) >= sysdate
    and    t.organization_id        = p_organization_id
    and    rownum                   = 1; 
       
    -- update account
    update XXINV_ITEM_STOCK_IN_OUT isiu
    set    isiu.account_id         = l_account_id
    where  isiu.batch_id           = p_batch_id
    and    isiu.organization_id    = p_organization_id
    and    isiu.log_code           = p_log_code;
    --isiu.item_stock_id      = p_item_stock_id;
    commit;
  exception
    when others then
      rollback;
      -- Account Alias not created for Org: &ORG
      fnd_message.SET_NAME('XXOBJT', 'XXINV_STOCK_INOUT_ACCOUNT');
      fnd_message.SET_TOKEN('ORG', p_organization_code);
      l_log_msg := fnd_message.get;
      errbuf   := 'ERR - upd_account_id - '||l_log_msg;
      retcode  := 1; 
      for r_err_pop in c_err_pop loop
        upd_log_messages (errbuf          => l_errbuf,         -- o v
                          retcode         => l_retcode,        -- o v  
                          p_log_code      => 'E',              -- i v
                          p_log_msg       => l_log_msg,        -- i v
                          p_item_stock_id => r_err_pop.item_stock_id ); -- i n
      end loop;
  end upd_account_id;
  
  --------------------------------------------------------------------
  --  name:             check_combination_exists
  --  create by:        Dalit A. Raviv
  --  Revision:         1.0
  --  creation date:    25/AUG/2015 15:29:18
  --------------------------------------------------------------------
  --  purpose :         CHG0036084 - Filament Stock in Stock out
  --                    This procedure check if combination of: item,org,subinv,loc
  --                    exists at interface table
  --------------------------------------------------------------------
  --  ver  date         name              desc
  --  1.0  25/AUG/2015  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure check_combination_exists(errbuf              out varchar2,
                                     retcode             out number,
                                     p_organization_id   in  number,
                                     p_item_stock_id     in  number,
                                     p_inventory_item_id in  number,
                                     p_subinventory_code in  varchar2,
                                     p_locator_id        in  number
                                     ) is  
                             
    l_log_msg     varchar2(2000);
    l_errbuf      varchar2(2000);
    l_retcode     varchar2(100);
    l_exsists_cnt number;
    
  begin
    errbuf   := null;
    retcode  := 0;           
    -- Check if item combination exist at interface tbl
    select count(1)
    into   l_exsists_cnt
    from   mtl_transactions_interface
    where  inventory_item_id    = p_inventory_item_id
    and    organization_id      = p_organization_id 
    and    subinventory_code    = p_subinventory_code
    and    nvl(locator_id,'-1') = nvl(p_locator_id,'-1') 
    --and    transaction_uom      = p_uom
    and    process_flag         <> 3
    and    source_code          = g_source_code; --'CONVERT';
    ---------------------------------------- add condition to inclide only records that are waiting to be process
 
    if l_exsists_cnt > 0 then
      -- update
      -- Similar lines exists in mtl_transactions_interface table, for source code CONVERT.
      -- Item ITEM, Organization ORG, Subinv SUBINV, Locator LOC.
      fnd_message.SET_NAME('XXOBJT', 'XXINV_STOCK_INOUT_TRX_INT');
      fnd_message.SET_TOKEN('ITEM', p_inventory_item_id);
      fnd_message.SET_TOKEN('ORG', p_organization_id );
      fnd_message.SET_TOKEN('SUBINV', p_subinventory_code);
      fnd_message.SET_TOKEN('LOC', p_locator_id);
      l_log_msg := fnd_message.get;
            
      upd_log_messages (errbuf          => l_errbuf,         -- o v
                        retcode         => l_retcode,        -- o v
                        p_log_code      => 'E',              -- i v
                        p_log_msg       => l_log_msg,        -- i v
                        p_item_stock_id => p_item_stock_id); -- i n        
    end if;       
  end check_combination_exists;                             

  --------------------------------------------------------------------
  --  name:             upd_out_trx_ids
  --  create by:        Dalit A. Raviv
  --  Revision:         1.0
  --  creation date:    25/AUG/2015 15:29:18
  --------------------------------------------------------------------
  --  purpose :         CHG0036084 - Filament Stock in Stock out
  --                    update transaction id's for the interface use
  --                    according to the qty if it is negative or positive.
  --------------------------------------------------------------------
  --  ver  date         name              desc
  --  1.0  25/AUG/2015  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure upd_out_trx_ids (errbuf  out varchar2,
                             retcode out varchar2) is
        
   l_trx_type_id        number;
   l_trx_action_id      number;
   l_trx_source_type_id number;     
  begin
    -- update id's for negative qty
    select transaction_type_id, transaction_action_id, transaction_source_type_id
    into   l_trx_type_id, l_trx_action_id, l_trx_source_type_id
    from   mtl_transaction_types
    where  upper(transaction_type_name) = 'ACCOUNT ALIAS RECEIPT';   
  
    update XXINV_ITEM_STOCK_IN_OUT isio
    set    isio.trx_type_id        = l_trx_type_id,
           isio.trx_action_id      = l_trx_action_id,
           isio.trx_source_type_id = l_trx_source_type_id
    where  isio.batch_id           = g_batch_id
    and    isio.log_code           = 'N'
    and    isio.qty                < 0;
    
    -- Update id's for positive qty
    select transaction_type_id, transaction_action_id, transaction_source_type_id
    into   l_trx_type_id, l_trx_action_id, l_trx_source_type_id
    from   mtl_transaction_types
    where  upper(transaction_type_name) = 'ACCOUNT ALIAS ISSUE'; 
    
    update XXINV_ITEM_STOCK_IN_OUT isio
    set    isio.trx_type_id        = l_trx_type_id,
           isio.trx_action_id      = l_trx_action_id,
           isio.trx_source_type_id = l_trx_source_type_id
    where  isio.batch_id           = g_batch_id
    and    isio.log_code           = 'N'
    and    isio.qty                >= 0;   
 
    commit;
  exception
    when others then
      rollback;
      errbuf  := 'GEN EXC - upd_out_trx_ids - '||substr(sqlerrm,1,200);
      retcode := 1;
      print_log('GEN EXC - upd_out_trx_ids - '||substr(sqlerrm,1,200));
  end upd_out_trx_ids;  
  
  --------------------------------------------------------------------
  --  name:             check_item_has_errors
  --  create by:        Dalit A. Raviv
  --  Revision:         1.0
  --  creation date:    26/AUG/2015 15:29:18
  --------------------------------------------------------------------
  --  purpose :         CHG0036084 - Filament Stock in Stock out
  --                    If item have several records and one of them is Error
  --                    i can not proceed at all with this item.
  --                    i will remark all records as Error
  --------------------------------------------------------------------
  --  ver  date         name              desc
  --  1.0  26/AUG/2015  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure check_item_has_errors (p_item_id       in number,
                                    p_batch_id      in number) is
    
  
     Cursor c_new_pop is
      select *
      from   XXINV_ITEM_STOCK_IN_OUT isio
      where  isio.log_code           = 'N'          
      and    isio.batch_id           = p_batch_id
      and    isio.inventory_item_id  = p_item_id;
    
    l_count   number         := 0;
    l_log_msg varchar2(2000) := null;
    l_errbuf  varchar2(2000) := null;
    l_retcode varchar2(100)  := null;
  begin
    select count(1)
    into   l_count
    from   XXINV_ITEM_STOCK_IN_OUT isio
    where  isio.log_code           = 'E'         
    and    isio.batch_id           = p_batch_id
    and    isio.inventory_item_id  = p_item_id;
    
    if l_count > 0 then
      -- Can not handle this Item, becuase it has at least one record of Error.
      fnd_message.SET_NAME('XXOBJT', 'XXINV_STOCK_INOUT_ITEM_ERR');
      l_log_msg := fnd_message.get;
      for r_new_pop in c_new_pop loop
        upd_log_messages (errbuf          => l_errbuf,         -- o v
                          retcode         => l_retcode,        -- o v  
                          p_log_code      => 'E',              -- i v
                          p_log_msg       => l_log_msg,        -- i v
                          p_item_stock_id => r_new_pop.item_stock_id); -- i n
      end loop;
    end if;
    
  end check_item_has_errors;
  
  --------------------------------------------------------------------
  --  name:             get_item_lot_serial_control
  --  create by:        Dalit A. Raviv
  --  Revision:         1.0
  --  creation date:    24/AUG/2015 15:29:18
  --------------------------------------------------------------------
  --  purpose :         CHG0036084 - Filament Stock in Stock out
  --                    check if item is lot control or serial control
  --------------------------------------------------------------------
  --  ver  date         name              desc
  --  1.0  24/AUG/2015  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure get_item_lot_serial_control(p_organization_id   in number, 
                                        p_inventory_item_id in number,
                                        p_lot_controlled    out varchar2,
                                        p_serial_controlled out varchar2) is
    l_is_lot_controlled    varchar2(10) := null;             
    l_is_serial_controlled varchar2(10) := null;
  begin
    select decode(nvl(sib.lot_control_code, 1), 2, 'Y', 'N'), 
           decode(nvl(sib.serial_number_control_code, 1), 1, 'N', 'Y')
    into   l_is_lot_controlled,
           l_is_serial_controlled
    from   mtl_system_items_b    sib
    where  sib.organization_id   = p_organization_id
    and    sib.inventory_item_id = p_inventory_item_id;

    p_serial_controlled := l_is_serial_controlled;
    p_lot_controlled    :=  l_is_lot_controlled;

  exception
    when others then
      p_serial_controlled := 'N';
      p_lot_controlled    := 'N';
  end get_item_lot_serial_control;
  
  --------------------------------------------------------------------
  --  name:             item_stock_issue
  --  create by:        Dalit A. Raviv
  --  Revision:         1.0
  --  creation date:    24/AUG/2015 15:29:18
  --------------------------------------------------------------------
  --  purpose :         CHG0036084 - Filament Stock in Stock out
  --                    This procedure handle taking out items from subinventory.
  --------------------------------------------------------------------
  --  ver  date         name              desc
  --  1.0  24/AUG/2015  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure Handle_trx_intrface (errbuf             OUT VARCHAR2, -- /*item_stock_issue*/
                                 retcode            OUT NUMBER,
                                 p_stock_in_out_rec in  t_item_stock_in_out_rec,
                                 p_entity           in  varchar2 ) is
                              
    l_transaction_interface_id number;
    l_lot_controlled           varchar2(10)   := null;
    l_serial_controlled        varchar2(10)   := null;
    l_mark                     number         := 0;
    l_log_msg                  varchar2(2000) := null;
    l_lot_number               varchar2(300)  := null;
    l_qty                      number         := null;
  begin
    -- mtl_transactions_interface
    select mtl_material_transactions_s.nextval
    into   l_transaction_interface_id
    from   dual;
    
    l_mark := 1;
    if p_entity = 'OUT' then
      l_qty := ((p_stock_in_out_rec.qty) * (-1));
    else
      l_qty := p_stock_in_out_rec.qty;
    end if;
    INSERT INTO mtl_transactions_interface
                (transaction_interface_id,
                 creation_date,
                 created_by,
                 last_update_date,
                 last_updated_by,
                 source_code,
                 source_line_id,
                 source_header_id,
                 process_flag,
                 inventory_item_id,
                 organization_id,
                 subinventory_code,
                 locator_id,
                 transaction_type_id,
                 transaction_action_id,
                 transaction_source_id,
                 transaction_source_type_id,
                 transaction_quantity,
                 transaction_uom,
                 transaction_date,
                 transaction_mode,
                 transaction_batch_id
                )
          VALUES
                (l_transaction_interface_id,            -- TRANSACTION_INTERFACE_ID
                 SYSDATE,                               -- CREATION_DATE,
                 fnd_global.user_id,                    -- CREATED_BY,
                 SYSDATE,                               -- LAST_UPDATE_DATE, 
                 fnd_global.user_id,                    -- LAST_UPDATE_BY,
                 g_source_code,              	          -- SOURCE_CODE            
                 '99',                                  -- SOURCE_LINE_ID,
                 '99',                                  -- SOURCE_HEADER_ID
                 1,                                     -- PROCESS_FLAG, 1-ready 7-succeeded 3 error 
                 p_stock_in_out_rec.inventory_item_id,  -- INVENTORY_ITEM_ID,          
                 p_stock_in_out_rec.organization_id,    -- ORGANIZATION_ID, 
                 p_stock_in_out_rec.subinventory_code,  -- SUBINVENTORY_CODE,
                 p_stock_in_out_rec.locator_id,         -- LOCATOR_ID
                 p_stock_in_out_rec.trx_type_id,        -- TRANSACTION_TYPE_ID,
                 p_stock_in_out_rec.trx_action_id,      -- TRANSACTION_ACTION_ID, 
                 p_stock_in_out_rec.account_id,         -- transaction_source_id  
                 p_stock_in_out_rec.trx_source_type_id, -- TRANSACTION_SOURCE_TYPE_ID 
                 l_qty,                                 -- TRANSACTION_QUANTITY
                 p_stock_in_out_rec.uom,                -- TRANSACTION_UOM,
                 SYSDATE,                               -- TRANSACTION_DATE
                 3,                                     -- TRANSACTION_MODE, NULL or 1 Online Processing - 2 Concurrent Processing 3 Background Processing
                 g_batch_id
                );
    
      -- check if serial or lot
      get_item_lot_serial_control(p_organization_id   => p_stock_in_out_rec.organization_id,   -- i n
                                  p_inventory_item_id => p_stock_in_out_rec.inventory_item_id, -- i n
                                  p_lot_controlled    => l_lot_controlled,                     -- o v
                                  p_serial_controlled => l_serial_controlled);                 -- o v
      
      if l_serial_controlled = 'Y' then
        -- handle serial
        l_mark := 2;
        INSERT INTO mtl_serial_numbers_interface
              (transaction_interface_id,
               last_update_date,
               last_updated_by,
               created_by,
               creation_date,
               fm_serial_number,
               to_serial_number,
               parent_item_id
               )
        VALUES
              (l_transaction_interface_id,            -- TRANSACTION_INTERFACE_ID
               SYSDATE,                               -- LAST_UPDATE_DATE
               fnd_global.user_id,                    -- LAST_UPDATED_BY
               fnd_global.user_id,                    -- CREATED_BY
               SYSDATE,                               -- CREATION_DATE
               p_stock_in_out_rec.serial_number,      -- FM_SERIAL_NUMBER
               p_stock_in_out_rec.serial_number,      -- TO_SERIAL_NUMBER
               p_stock_in_out_rec.inventory_item_id); -- PARENT_ITEM_ID  
      end if; -- serial control 
      if l_lot_controlled = 'Y' then
        l_mark := 3;
        -- handle lot
        if p_entity = 'OUT' then
          l_lot_number := p_stock_in_out_rec.original_lot_number;
        else
          l_lot_number := nvl(p_stock_in_out_rec.new_lot_number,p_stock_in_out_rec.original_lot_number); 
        end if;
        INSERT INTO mtl_transaction_lots_interface
              (transaction_interface_id,
               lot_number,
               transaction_quantity,
               last_update_date,
               last_updated_by,
               creation_date,
               created_by,
               --product_code,
               --product_transaction_id,
               primary_quantity)
       values (l_transaction_interface_id,            -- TRANSACTION_INTERFACE_ID
               l_lot_number,                          -- LOT_NUMBER
               --p_stock_in_out_rec.original_lot_number,-- LOT_NUMBER
               p_stock_in_out_rec.qty,                -- TRANSACTION_QUANTITY
               SYSDATE,                               -- LAST_UPDATE_DATE
               fnd_global.user_id,                    -- LAST_UPDATED_BY
               SYSDATE,                               -- CREATION_DATE
               fnd_global.user_id,                    -- CREATED_BY
               --'INV',                                 -- PRODUCT_CODE
               --l_transaction_interface_id,            -- PRODUCT_TRANSACTION_ID
               p_stock_in_out_rec.qty                 -- PRIMARY_QUANTITY
              );
      end if; -- lot control  
      
      update XXINV_ITEM_STOCK_IN_OUT isiu
      set    isiu.log_code           = 'T',
             isiu.trx_to_intf_flag   = 'Y',
             isiu.trx_to_intf_date   = sysdate,
             isiu.trx_interface_id   = l_transaction_interface_id
      where  isiu.item_stock_id      = p_stock_in_out_rec.item_stock_id;
      commit;
  exception
    when others then
      rollback;
      -- Problem, insert record to interface
      fnd_message.SET_NAME('XXOBJT', 'XXINV_STOCK_INOUT_TRX_INS_ERR'); 
      l_log_msg := fnd_message.get;
      l_log_msg := l_log_msg||' Insert place '||l_mark||', '||substr(sqlerrm,1,200);
      update XXINV_ITEM_STOCK_IN_OUT isiu
      set    isiu.log_code           = 'E',
             isiu.log_msg            = l_log_msg,
             isiu.trx_to_intf_flag   = 'N',
             isiu.trx_to_intf_date   = sysdate,
             isiu.trx_interface_id   = l_transaction_interface_id
      where  isiu.item_stock_id      = p_stock_in_out_rec.item_stock_id;
      errbuf  := 'GEN EXE - Handle_trx_intrface - '||substr(sqlerrm,1,200);
      retcode := 1;      
      
  end Handle_trx_intrface;                              
  
  --------------------------------------------------------------------
  --  name:             process_trx_interface
  --  create by:        Dalit A. Raviv
  --  Revision:         1.0
  --  creation date:    26/AUG/2015 15:29:18
  --------------------------------------------------------------------
  --  purpose :         CHG0036084 - Filament Stock in Stock out
  --                    handle run "Process transaction interface"
  --                    wait to complete and handle errors from interface
  --------------------------------------------------------------------
  --  ver  date         name              desc
  --  1.0  26/AUG/2015  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure process_trx_interface (p_batch_id   in  number) is

    x_phase       varchar2(100);
    x_status      varchar2(100);
    x_dev_phase   varchar2(100);
    x_dev_status  varchar2(100);
    l_bool        boolean;
    l_request_id  number;
    l_count       number := 0;
    x_message     varchar2(500);
    l_errbuf      varchar2(500);
  begin
    select count(1)
    into   l_count
    from   XXINV_ITEM_STOCK_IN_OUT isiu
    where  isiu.batch_id           = p_batch_id
    and    isiu.log_code           = 'T';
    
    if l_count > 0 then  
 
      l_request_id := fnd_request.submit_request(application => 'INV',
                                                 program     => 'INCTCM');-- Process transaction interface
      commit;
      if l_request_id > 0 then
        --print_out('Concurrent - Process transaction interface, was submitted successfully'
        --          ||' (request_id = ' ||l_request_id || ')');
        
        l_bool := fnd_concurrent.wait_for_request(l_request_id,
                                                  10,  -- interval 5  seconds
                                                  600, -- max wait 120 seconds
                                                  x_phase,
                                                  x_status,
                                                  x_dev_phase,
                                                  x_dev_status,
                                                  x_message);
    
        l_errbuf := null;
        if upper(x_dev_phase) = 'COMPLETE' and upper(x_dev_status) in ('ERROR', 'WARNING') then
          l_errbuf := ('Process transaction interface, program completed in '
                      ||upper(x_dev_status)||'. See log/out for request_id = '||l_request_id);
        
        elsif upper(x_dev_phase) = 'COMPLETE' and upper(x_dev_status) = 'NORMAL' then
          print_log('Process transaction interface, program SUCCESSFULLY COMPLETED'
                    ||' for request_id = ' ||l_request_id);
        else
          l_errbuf := ('Process transaction interface, request failed review log/out for '
                       ||' request_id = '||l_request_id);
        end if;
      else
        l_errbuf  := 'Process transaction interface, submitting PROBLEM';
      end if;
      
      if l_errbuf is not null then
        update XXINV_ITEM_STOCK_IN_OUT isiu
        set    isiu.log_code           = 'E',
               isiu.log_msg            = l_errbuf,
               isiu.trx_to_intf_flag   = 'N',
               isiu.trx_to_intf_date   = sysdate
        where  isiu.batch_id           = p_batch_id
        and    isiu.log_code           = 'T';
        commit;
      end if;
    else
      print_log('No Record to proccess at interface');
    end if;-- l_count
  end process_trx_interface;
  
  --------------------------------------------------------------------
  --  name:             handle_trx_interface_errors
  --  create by:        Dalit A. Raviv
  --  Revision:         1.0
  --  creation date:    26/AUG/2015 15:29:18
  --------------------------------------------------------------------
  --  purpose :         CHG0036084 - Filament Stock in Stock out
  --                    This procedure handle interface errors
  --------------------------------------------------------------------
  --  ver  date         name              desc
  --  1.0  26/AUG/2015  Dalit A. Raviv    initial build
  -------------------------------------------------------------------- 
  procedure handle_trx_interface_errors (p_stock_in_out_rec t_item_stock_in_out_rec) is
    l_error_explanation varchar2(240);
  begin
    select nvl(t.error_explanation,t.error_code)
    into   l_error_explanation
    from   mtl_transactions_interface t
    where  t.transaction_interface_id = p_stock_in_out_rec.trx_interface_id;
    
    if l_error_explanation is not null then
      update XXINV_ITEM_STOCK_IN_OUT isiu
      set    isiu.log_code           = 'E',
             isiu.log_msg            = l_error_explanation
      where  isiu.item_stock_id      = p_stock_in_out_rec.item_stock_id;
    else
      update XXINV_ITEM_STOCK_IN_OUT isiu
      set    isiu.log_code           = 'S'
      where  isiu.item_stock_id      = p_stock_in_out_rec.item_stock_id;
    end if;
    commit;
  exception
    when no_data_found then
      update XXINV_ITEM_STOCK_IN_OUT isiu
      set    isiu.log_code           = 'S'
      where  isiu.item_stock_id      = p_stock_in_out_rec.item_stock_id;
      commit;
    when others then
      null;
  end handle_trx_interface_errors;
                            
/*  --------------------------------------------------------------------
  --  name:             item_stock_issue
  --  create by:        Dalit A. Raviv
  --  Revision:         1.0
  --  creation date:    24/AUG/2015 15:29:18
  --------------------------------------------------------------------
  --  purpose :         CHG0036084 - Filament Stock in Stock out
  --                    This procedure handle taking in items to subinventory.
  --------------------------------------------------------------------
  --  ver  date         name              desc
  --  1.0  24/AUG/2015  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure item_stock_receiving (errbuf             OUT VARCHAR2,
                                  retcode            OUT NUMBER,
                                  p_stock_in_out_rec t_item_stock_in_out_rec) is

    l_transaction_interface_id number;
    l_lot_controlled           varchar2(10)   := null;
    l_serial_controlled        varchar2(10)   := null;
    l_mark                     number         := 0;
    l_log_msg                  varchar2(2000) := null;
    
  begin
    errbuf  := null;
    retcode := 0;   
  
    select mtl_material_transactions_s.nextval
    into   l_transaction_interface_id
    from   dual;
    
    INSERT INTO mtl_transactions_interface
            (transaction_interface_id,
             creation_date,
             created_by,
             last_update_date,
             last_updated_by,
             source_code,
             source_line_id,
             source_header_id,
             process_flag,
             inventory_item_id,
             organization_id,
             subinventory_code,
             locator_id,
             transaction_type_id,
             transaction_action_id,
             transaction_source_id,
             transaction_source_type_id,
             transaction_quantity,
             transaction_uom,
             transaction_date,
             transaction_mode
            )
    VALUES  (l_transaction_interface_id, ---transaction_interface_id
             SYSDATE,                    --- CREATION_DATE,
             fnd_global.user_id,         --- CREATED_BY,
             SYSDATE,                    --- LAST_UPDATE_DATE, 
             fnd_global.user_id,         --- LAST_UPDATE_BY,
             l_source_code,              --- SOURCE_CODE  
             99,                         --- SOURCE_LINE_ID,
             99,                         --- SOURCE_HEADER_ID
             1,                          --- PROCESS_FLAG, 1-ready 7-succeeded 3 error 
             c_1.item_id,                --- INVENTORY_ITEM_ID,          
             c_1.organization_id,        --- ORGANIZATION_ID, 
             c_1.subinv,                 --- SUBINVENTORY_CODE,
             c_1.inventory_location_id,  ---locator_id
             l_transaction_type_id,      --- TRANSACTION_TYPE_ID,
             l_transaction_action_id,    --- TRANSACTION_ACTION_ID, 
             l_transaction_source_id,    -- transaction_source_id  
             l_transaction_source_type_id, ---TRANSACTION_SOURCE_TYPE_ID 
             --c_1.qty, --- TRANSACTION_QUANTITY,
            DECODE(sign(c_1.qty),'-1',c_1.qty,c_1.qty), --- TRANSACTION_QUANTITY,
             c_1.uom, --- TRANSACTION_UOM,
             SYSDATE, --- TRANSACTION_DATE
             3  --- TRANSACTION_MODE, NULL or 1 Online Processing - 2 Concurrent Processing 3 Background Processing
             );
     
    
  exception
    when others then
      errbuf  := 'GEN EXE - item_stock_receiving - '||substr(1,200);
      retcode := 1; 
  end item_stock_receiving;
*/  
  --------------------------------------------------------------------
  --  name:             main_out
  --  create by:        Dalit A. Raviv
  --  Revision:         1.0
  --  creation date:    24/AUG/2015 15:29:18
  --------------------------------------------------------------------
  --  purpose :         CHG0036084 - Filament Stock in Stock out
  --                    This procedure is the main prog that 
  --                    handle taking out items from subinventory.
  --                    
  --                    1) Upload excel file with the list of items to work on
  --                    2) Check if there are existing reservations (i.e open Transact Move Orders, open balance in Stage, etc)
  --                    3) Complete item inforamtion
  --                    4) update account id
  --                    5) Check item combination of: org,item,subinv and locator
  --                       do not exists at interface table
  --                    6) update transaction id's for the interface use
  --                    7) if item have one record with E code - all other reacords need to get error
  --                    8) insert record to interface table
  --                    9) Handle run "Process transaction interface" 
  --                    10) handle transaction table errors
  --------------------------------------------------------------------
  --  ver  date         name              desc
  --  1.0  24/AUG/2015  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure main_out (errbuf          out varchar2,
                      retcode         out number,
                      p_table_name    in  varchar2,
                      p_template_name in  varchar2,
                      p_file_name     in  varchar2,
                      p_directory     in  varchar2,
                      p_upload        in  varchar2) is
  
    Cursor c_init_pop is
      select * 
      from   XXINV_ITEM_STOCK_IN_OUT isio
      where  isio.log_code = 'I'          -- All uploaded records will get initial value of I
      and    isio.batch_id = g_batch_id;
    
     Cursor c_process_pop is
      select * 
      from   XXINV_ITEM_STOCK_IN_OUT isio
      where  isio.log_code = 'P'          -- All uploaded records will get initial value of P
      and    isio.batch_id = g_batch_id;
    
    Cursor c_account_pop is
      select distinct isio.organization_id, isio.organization_code
      from   XXINV_ITEM_STOCK_IN_OUT isio
      where  isio.log_code = 'N'          -- All uploaded records will get initial value of N
      and    isio.batch_id = g_batch_id;
    
    Cursor c_new_pop is
      select * 
      from   XXINV_ITEM_STOCK_IN_OUT isio
      where  isio.log_code = 'N'          -- All uploaded records will get initial value of N
      and    isio.batch_id = g_batch_id;
    
    Cursor c_err_pop is
      select distinct isio.inventory_item_id, isio.item_number
      from   XXINV_ITEM_STOCK_IN_OUT isio
      where  isio.log_code = 'N'          -- All uploaded records will get initial value of N
      and    isio.batch_id = g_batch_id;
    
    Cursor c_trx_pop is
      select * 
      from   XXINV_ITEM_STOCK_IN_OUT isio
      where  isio.log_code = 'T'          -- All uploaded records will get initial value of T
      and    isio.batch_id = g_batch_id;
    
    Cursor c_err_pop1 is
      select isio.item_stock_id, isio.organization_code, isio.item_number,
             isio.account_id, isio.subinventory_code, isio.locator_id, 
             isio.item_revision, isio.original_lot_number, isio.new_lot_number, isio.serial_number,
             isio.qty, isio.uom, isio.stage, isio.trx_interface_id, isio.batch_id, 
             isio.log_code, isio.log_msg,
             (select concatenated_segments
              from   mtl_item_locations_kfv    loc
              where  organization_id           = isio.organization_id
              and    inventory_location_id     = isio.locator_id
              and    rownum                    = 1) locator_name 
      from   XXINV_ITEM_STOCK_IN_OUT isio
      where  isio.batch_id = g_batch_id;
      --and    isio.log_code = 'E';
    
    l_errbuf           varchar2(2500) := null;
    l_retcode          varchar2(100)  := 0;
    l_stock_in_out_rec t_item_stock_in_out_rec;
    l_count            number         := 0;
    l_log_msg          varchar2(2000) := null;
    --l_batch_id         number;
    
    stop_processing    exception;
  begin
    g_batch_id := fnd_global.CONC_REQUEST_ID;
    --l_batch_id := fnd_global.CONC_REQUEST_ID;
  
    print_out('------------------------');
    print_out('Batch Id - '||g_batch_id);
    print_out('------------------------');
    
    if fnd_global.conc_request_id = -1 then
      fnd_global.APPS_INITIALIZE(user_id =>2470 ,resp_id => 50623,resp_appl_id => 660);
    end if;
    -- 1) upload excel file into table
    l_errbuf  := null;
    l_retcode := 0;
    if p_upload = 'Y' then
      upload_file(errbuf           => l_errbuf,        -- o v
                  retcode          => l_retcode,       -- o v
                  p_table_name     => p_table_name,    -- i v XXINV_ITEM_STOCK_IN_OUT
                  p_template_name  => p_template_name, -- i v GEN
                  p_file_name      => p_file_name,     -- i v
                  p_directory      => p_directory);    -- i v
                  
      if l_retcode <> '0' then
        print_out('Upload File - '||l_errbuf);
        errbuf   := 'main_out problem upload file - '||l_errbuf;
        retcode  := 2;
        raise stop_processing;
      end if; 
    end if;
    
    -- 2) check if item is not in transit -> if yes error and do not procedd 
    -- i go over all 'I' records (Initial) and if i find exists reservation
    -- i will update the record with error - E
    -- in the continue of the program i will not look at these record any more.
    -- isio.log_code = 'I' 
     
    l_count := 0;
    for r_pop in c_init_pop loop
      check_intransit (errbuf           => l_errbuf,             -- o v
                       retcode          => l_retcode,            -- o v
                       p_item_number    => r_pop.item_number,    -- i v
                       p_item_stock_id  => r_pop.item_stock_id); -- i n
      l_count := l_count +1;                         
    end loop;
    if l_count = 0 then 
      print_out('Check InTransit code = I -> No record to process'); 
    end if; 
    -- 2.1) check if item reserve -> if yes error and do not procedd 
    -- i go over all 'I' records (Initial) and if i find exists reservation
    -- i will update the record with error - E
    -- in the continue of the program i will not look at these record any more.
    -- isio.log_code = 'I' 
    l_count := 0;
    for r_pop in c_init_pop loop
      check_reservation (errbuf           => l_errbuf,             -- o v
                         retcode          => l_retcode,            -- o v
                         p_item_number    => r_pop.item_number,    -- i v
                         p_item_stock_id  => r_pop.item_stock_id); -- i n
      l_count := l_count +1;                         
    end loop;
    if l_count = 0 then 
      print_out('Check Reservation code = I -> No record to process'); 
    end if; 
    
    -- 3) Complete item inforamtion:
    --    each item can have several records, because it can exists at several subinv
    --    isio.log_code = 'P'  
    l_count := 0;
    for r_process_pop in c_process_pop loop
      l_errbuf  := null;
      l_retcode := 0;
      complete_item_info (errbuf           => l_errbuf,                     -- o v
                          retcode          => l_retcode,                    -- o v
                          p_item_number    => r_process_pop.item_number,    -- i v
                          p_new_lot_number => r_process_pop.new_lot_number, -- i v
                          p_batch_id       => g_batch_id);                  -- i n
      l_count := l_count +1;  
    end loop;
    if l_count = 0 then 
      print_out('Complete Item Info code = P -> No record to process'); 
    end if;
    
    -- 4) update account id
    --    isio.log_code = 'N'
    l_count := 0;
    for r_account_pop in c_account_pop loop
      l_errbuf  := null;
      l_retcode := 0;
      upd_account_id (errbuf              => l_errbuf,                        -- o v
                      retcode             => l_retcode,                       -- o v
                      p_organization_id   => r_account_pop.organization_id,   -- i n
                      p_organization_code => r_account_pop.organization_code, -- i v
                      p_batch_id          => g_batch_id,                      -- i n
                      p_log_code          => 'N');                            -- i v
      l_count := l_count +1;  
    end loop;
    if l_count = 0 then 
      print_out('Upd Account Id - code = N -> No record to process'); 
    end if;
    
    -- 5) Check item combination of: org,item,subinv and locator
    --    do not exists at interface table
    --    isio.log_code = 'N'   
    l_count := 0;
    for r_new_pop in c_new_pop loop
      l_errbuf  := null;
      l_retcode := 0; 
      check_combination_exists(errbuf              => l_errbuf,                    -- o v
                               retcode             => l_retcode,                   -- o v
                               p_organization_id   => r_new_pop.organization_id,   -- i n
                               p_item_stock_id     => r_new_pop.item_stock_id,     -- i n
                               p_inventory_item_id => r_new_pop.inventory_item_id, -- i n
                               p_subinventory_code => r_new_pop.subinventory_code, -- i v
                               p_locator_id        => r_new_pop.locator_id         -- i n
                               );
      l_count := l_count +1;  
    end loop;
    if l_count = 0 then 
      print_out('Check Combination Exists - code = N -> No record to process'); 
    end if;
     
    -- 6) update transaction id's for the interface use
    l_errbuf  := null;
    l_retcode := 0; 
    upd_out_trx_ids (errbuf  => l_errbuf,   -- o v
                     retcode => l_retcode); -- o v
    
    -- 7) if item have one record with E code - all other reacords need to get error
    --    isio.log_code = 'N' 
    l_count := 0;
    for r_err_pop in c_err_pop loop
      check_item_has_errors (p_item_id       => r_err_pop.inventory_item_id,      -- i n
                              p_batch_id      => g_batch_id);                      -- i n
      l_count := l_count +1;
    end loop;
    if l_count = 0 then 
      print_out('Check Item have Errors - code = N - No record to process'); 
    end if;
    
    -- 8) insert record to interface table
    --    isio.log_code = 'N' 
    l_count := 0;
    for r_new_pop in c_new_pop loop
      --handle interface
      l_stock_in_out_rec := r_new_pop;
      Handle_trx_intrface (errbuf             => l_errbuf,            -- o v
                           retcode            => l_retcode,           -- o v
                           p_stock_in_out_rec => l_stock_in_out_rec,  -- t_item_stock_in_out_rec
                           p_entity           => 'OUT');              -- i v
      l_count := l_count +1;
    end loop;
    if l_count = 0 then 
      print_out('Handle Trx Intrface - code = N -> No record to process'); 
    end if; 
    
    -- 9) Handle run "Process transaction interface"
    process_trx_interface (p_batch_id   => g_batch_id ); -- i n
    
    -- 10) handle transaction table errors
    l_stock_in_out_rec := null;
    --    isio.log_code = 'T' 
    l_count := 0;
    for r_trx_pop in c_trx_pop loop
      l_stock_in_out_rec := r_trx_pop;
      handle_trx_interface_errors (p_stock_in_out_rec => l_stock_in_out_rec);
      l_count := l_count +1;
    end loop;
    if l_count = 0 then 
      print_out('Handle Trx Intrface Errors - code = T -> No record to process'); 
    end if;
    
    l_count := 0;
    select count(1)
    into   l_count
    from   XXINV_ITEM_STOCK_IN_OUT isio
    where  isio.log_code           = 'E'         
    and    isio.batch_id           = g_batch_id;
    
    if l_count > 0 then
      -- There are several records with Error
      fnd_message.SET_NAME('XXOBJT', 'XXINV_STOCK_INOUT_TOTAL_ERROR');
      l_log_msg := fnd_message.get;
      errbuf  := l_log_msg;
      retcode := 1;
    end if;
     
    -- Write to out
    -- Set prompts
    print_out('                    ');
    print_out(  RPAD('--------  ',10)||'|'||RPAD('---  ',5)||'|'||RPAD('----------  ',12)||'|'
              ||RPAD('----------  ',12)||'|'||RPAD('------------  ',14)||'|'||RPAD('------------------  ',20)||'|'
              ||RPAD('--------  ',10)||'|'||RPAD('------------  ',14)||'|'||RPAD('------------  ',14)||'|'
              ||RPAD('------------  ',14)||'|'||RPAD('----------  ',12)||'|'||RPAD('---  ',5)||'|'
              ||RPAD('------------  ',14)||'|'||RPAD('--------  ',10)||'|'
              ||RPAD('--------  ',10)||'|'||'--------------------------------------  ');
    print_out(  RPAD('Stock Id  ',10)||'|'||RPAD('Org  ',5)||'|'||RPAD('Item Number ',12)||'|'
              ||RPAD('Account Id  ',12)||'|'||RPAD('Subinventory  ',14)||'|'||RPAD('Locator             ',20)||'|'
              ||RPAD('Item Rev  ',10)||'|'||RPAD('Orig Lot      ',14)||'|'||RPAD('New Lot       ',14)||'|'
              ||RPAD('Serial Number ',14)||'|'||RPAD('Qty         ',12)||'|'||RPAD('UOM  ',5)||'|'
              ||RPAD('Inter TRX Id  ',14)||'|'||RPAD('Batch Id  ',10)||'|'
              ||RPAD('Log Code  ',10)||'|'||'Log Message');
    print_out(  RPAD('--------  ',10)||'|'||RPAD('---  ',5)||'|'||RPAD('----------  ',12)||'|'
              ||RPAD('----------  ',12)||'|'||RPAD('------------  ',14)||'|'||RPAD('------------------  ',20)||'|'
              ||RPAD('--------  ',10)||'|'||RPAD('------------  ',14)||'|'||RPAD('------------  ',14)||'|'
              ||RPAD('------------  ',14)||'|'||RPAD('----------  ',12)||'|'||RPAD('---  ',5)||'|'
              ||RPAD('------------  ',14)||'|'||RPAD('--------  ',10)||'|'
              ||RPAD('--------  ',10)||'|'||'--------------------------------------  ');
                               
   for r_err_pop in c_err_pop1 loop
      print_out( RPAD(r_err_pop.item_stock_id ,10)||'|'||RPAD(nvl(r_err_pop.organization_code,'.'),5)||'|'||RPAD(r_err_pop.item_number,12)||'|'
               ||RPAD(nvl(r_err_pop.account_id,-9),12)||'|'||RPAD(nvl(r_err_pop.subinventory_code,'.') ,14)||'|'||RPAD(nvl(r_err_pop.locator_name,'.') ,20)||'|'
               ||RPAD(nvl(r_err_pop.item_revision,'.') ,10)||'|'||RPAD(nvl(r_err_pop.original_lot_number,'.'),14)||'|'||RPAD(nvl(r_err_pop.new_lot_number,'.'),14)||'|'
               ||RPAD(nvl(r_err_pop.serial_number,'.') ,14)||'|'||RPAD(nvl(r_err_pop.qty,-9) ,12)||'|'||RPAD(nvl(r_err_pop.uom,'.') ,5)||'|'
               ||RPAD(nvl(r_err_pop.trx_interface_id,-9) ,14)||'|'||RPAD(nvl(r_err_pop.batch_id,-9) ,10)||'|'
               ||RPAD(nvl(r_err_pop.log_code,'.') ,10)||'|'
               ||nvl(r_err_pop.log_msg,'.'));   
   
   end loop;
   print_out(  RPAD('--------  ',10)||'|'||RPAD('---  ',5)||'|'||RPAD('----------  ',12)||'|'
              ||RPAD('----------  ',12)||'|'||RPAD('------------  ',14)||'|'||RPAD('------------------  ',20)||'|'
              ||RPAD('--------  ',10)||'|'||RPAD('------------  ',14)||'|'||RPAD('------------  ',14)||'|'
              ||RPAD('------------  ',14)||'|'||RPAD('----------  ',12)||'|'||RPAD('---  ',5)||'|'
              ||RPAD('------------  ',14)||'|'||RPAD('--------  ',10)||'|'
              ||RPAD('--------  ',10)||'|'||'--------------------------------------  ');
  exception
    when stop_processing then
      null;
    when others then
      errbuf  := 'GEN EXE - main_out - '||substr(sqlerrm,1,200);
      retcode := 1; 
  end main_out;  
  
  --------------------------------------------------------------------
  --  name:             reset_values
  --  create by:        Dalit A. Raviv
  --  Revision:         1.0
  --  creation date:    27/AUG/2015 15:29:18
  --------------------------------------------------------------------
  --  purpose :         CHG0036084 - Filament Stock in Stock out
  --                    The in process need to determine the population to work on
  --                    All succee
  --                    
  --                    1) 
  --                    2) 
  --------------------------------------------------------------------
  --  ver  date         name              desc
  --  1.0  27/AUG/2015  Dalit A. Raviv    initial build
  --------------------------------------------------------------------      
  procedure reset_values (errbuf     out varchar2,
                          retcode    out number,
                          p_batch_id in  number,
                          p_log_code in  varchar2) is
                          
    
      
  begin
    errbuf  := null;
    retcode := 0;
    -- All records of this batch that finished with Success
    -- need to reset some fields inorder to continue the trx In process.
    update XXINV_ITEM_STOCK_IN_OUT isiu
    set    isiu.log_code           = 'N',
           isiu.stage              = 'IN',
           isiu.log_msg            = null,
           isiu.trx_type_id        = null,
           isiu.trx_action_id      = null,
           isiu.trx_source_type_id = null,
           isiu.trx_to_intf_flag   = null,
           isiu.trx_to_intf_date   = null,
           isiu.trx_interface_id   = null
    where  isiu.log_code           = p_log_code --'S'          
    and    isiu.batch_id           = p_batch_id;
    
    commit;
    
  exception
    when others then
      errbuf  := 'GEN EXE - reset_values - '||substr(sqlerrm,1,200);
      retcode := 1;   
  end reset_values;                          
  
  --------------------------------------------------------------------
  --  name:             upd_in_trx_ids
  --  create by:        Dalit A. Raviv
  --  Revision:         1.0
  --  creation date:    27/AUG/2015 15:29:18
  --------------------------------------------------------------------
  --  purpose :         CHG0036084 - Filament Stock in Stock out
  --                    update transaction id's for the interface use
  --                    according to the qty if it is negative or positive.
  --------------------------------------------------------------------
  --  ver  date         name              desc
  --  1.0  27/AUG/2015  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure upd_in_trx_ids (errbuf  out varchar2,
                             retcode out varchar2) is
        
   l_trx_type_id        number;
   l_trx_action_id      number;
   l_trx_source_type_id number;     
  begin
    -- update id's for negative qty
    select transaction_type_id, transaction_action_id, transaction_source_type_id
    into   l_trx_type_id, l_trx_action_id, l_trx_source_type_id
    from   mtl_transaction_types
    where  upper(transaction_type_name) = 'ACCOUNT ALIAS ISSUE';  
    
    update XXINV_ITEM_STOCK_IN_OUT isio
    set    isio.trx_type_id        = l_trx_type_id,
           isio.trx_action_id      = l_trx_action_id,
           isio.trx_source_type_id = l_trx_source_type_id
    where  isio.batch_id           = g_batch_id
    and    isio.log_code           = 'N'
    and    isio.qty                < 0;
    
    -- Update id's for positive qty
    select transaction_type_id, transaction_action_id, transaction_source_type_id
    into   l_trx_type_id, l_trx_action_id, l_trx_source_type_id
    from   mtl_transaction_types
    where  upper(transaction_type_name) = 'ACCOUNT ALIAS RECEIPT';  
    
    update XXINV_ITEM_STOCK_IN_OUT isio
    set    isio.trx_type_id        = l_trx_type_id,
           isio.trx_action_id      = l_trx_action_id,
           isio.trx_source_type_id = l_trx_source_type_id
    where  isio.batch_id           = g_batch_id
    and    isio.log_code           = 'N'
    and    isio.qty                >= 0;   
 
    commit;
  exception
    when others then
      rollback;
      errbuf  := 'GEN EXC - upd_in_trx_ids - '||substr(sqlerrm,1,200);
      retcode := 1;
      print_log('GEN EXC - upd_in_trx_ids - '||substr(sqlerrm,1,200));
  end upd_in_trx_ids;  
  
  --------------------------------------------------------------------
  --  name:             main_in
  --  create by:        Dalit A. Raviv
  --  Revision:         1.0
  --  creation date:    27/AUG/2015 15:29:18
  --------------------------------------------------------------------
  --  purpose :         CHG0036084 - Filament Stock in Stock out
  --                    This procedure is the main prog that 
  --                    handle return in items to subinventory.
  --                    
  --                    1) reset batch records that where Success to init. values 
  --                    2) update transaction id's for the interface use
  --                    3) insert record back into interface table
  --                    4) Handle run "Process transaction interface"
  --------------------------------------------------------------------
  --  ver  date         name              desc
  --  1.0  27/AUG/2015  Dalit A. Raviv    initial build
  --------------------------------------------------------------------                  
  procedure main_in  (errbuf     OUT VARCHAR2,
                      retcode    OUT NUMBER,
                      P_BATCH_ID in  number) is
                      
    Cursor c_new_pop is
      select * 
      from   XXINV_ITEM_STOCK_IN_OUT isio
      where  isio.log_code = 'N'          
      and    isio.batch_id = p_batch_id
      and    isio.stage    = 'IN';
    
    Cursor c_trx_pop is
      select * 
      from   XXINV_ITEM_STOCK_IN_OUT isio
      where  isio.log_code = 'T'          
      and    isio.batch_id = p_batch_id
      and    isio.stage    = 'IN';
    
    Cursor c_err_pop1 is
      select isio.item_stock_id, isio.organization_code, isio.item_number,
             isio.account_id, isio.subinventory_code, isio.locator_id, 
             isio.item_revision, isio.original_lot_number, isio.new_lot_number, isio.serial_number,
             isio.qty, isio.uom, isio.stage, isio.trx_interface_id, isio.batch_id, 
             isio.log_code, isio.log_msg,
             (select concatenated_segments
              from   mtl_item_locations_kfv    loc
              where  organization_id           = isio.organization_id
              and    inventory_location_id     = isio.locator_id
              and    rownum                    = 1) locator_name
      from   XXINV_ITEM_STOCK_IN_OUT isio
      where  isio.batch_id = p_batch_id;
      --and    isio.log_code = 'E';
    
    l_errbuf           varchar2(2500) := null;
    l_retcode          varchar2(100)  := 0;
    l_stock_in_out_rec t_item_stock_in_out_rec;
    l_count            number         := 0;
    l_log_msg          varchar2(2000) := null;
    
  begin
    errbuf     := null;
    retcode    := 0;
    g_batch_id := p_batch_id;
    
    print_out('------------------------');
    print_out('Batch Id - '||g_batch_id);
    print_out('------------------------');
  
    -- 1) all records that finished with S (Success) - this is our population
    --    of records to work with.
    --    to be able to do it i need to change values to init values
    l_errbuf  := null;
    l_retcode := 0;    
    reset_values (errbuf     => l_errbuf,   -- o v
                  retcode    => l_retcode,  -- o v
                  p_batch_id => p_batch_id, -- i n
                  p_log_code => 'S');       -- i v
  
    -- 2) update transaction id's for the interface use
    l_errbuf  := null;
    l_retcode := 0;   
    upd_in_trx_ids (errbuf  => l_errbuf,   -- o v
                    retcode => l_retcode); -- o v
  
    -- 3) insert record back into interface table
    --    isio.log_code = 'N' 
    for r_new_pop in c_new_pop loop
      --handle interface
      l_stock_in_out_rec := r_new_pop;
      Handle_trx_intrface (errbuf             => l_errbuf,            -- o v
                           retcode            => l_retcode,           -- o v
                           p_stock_in_out_rec => l_stock_in_out_rec,  -- t_item_stock_in_out_rec
                           p_entity           => 'IN');               -- i v
      
    end loop;
     
    -- 4) Handle run "Process transaction interface"
    process_trx_interface (p_batch_id => p_batch_id); -- i n
    
    -- 5) handle transaction table errors
    l_stock_in_out_rec := null;
    --    isio.log_code = 'T' 
    for r_trx_pop in c_trx_pop loop
      l_stock_in_out_rec := r_trx_pop;
      handle_trx_interface_errors (p_stock_in_out_rec => l_stock_in_out_rec);
    end loop;
    
    select count(1)
    into   l_count
    from   XXINV_ITEM_STOCK_IN_OUT isio
    where  isio.log_code           = 'E'         
    and    isio.batch_id           = g_batch_id
    and    isio.stage              = 'IN';
    
    if l_count > 0 then
      -- There are several records with Erro
      fnd_message.SET_NAME('XXOBJT', 'XXINV_STOCK_INOUT_TOTAL_ERROR');
      l_log_msg := fnd_message.get;
      print_out('----------------------------');
      print_out(l_log_msg);
      errbuf  := l_log_msg;
      retcode := 1;
    end if;
  
    -- Write to out
    -- Set prompts
    print_out('                    ');
    print_out(  RPAD('--------  ',10)||'|'||RPAD('---  ',5)||'|'||RPAD('----------  ',12)||'|'
              ||RPAD('----------  ',12)||'|'||RPAD('------------  ',14)||'|'||RPAD('------------------  ',20)||'|'
              ||RPAD('--------  ',10)||'|'||RPAD('------------  ',14)||'|'||RPAD('------------  ',14)||'|'
              ||RPAD('------------  ',14)||'|'||RPAD('----------  ',12)||'|'||RPAD('---  ',5)||'|'
              ||RPAD('------------  ',14)||'|'||RPAD('--------  ',10)||'|'
              ||RPAD('--------  ',10)||'|'||'--------------------------------------  ');
    print_out(  RPAD('Stock Id  ',10)||'|'||RPAD('Org  ',5)||'|'||RPAD('Item Number ',12)||'|'
              ||RPAD('Account Id  ',12)||'|'||RPAD('Subinventory  ',14)||'|'||RPAD('Locator             ',20)||'|'
              ||RPAD('Item Rev  ',10)||'|'||RPAD('Orig Lot      ',14)||'|'||RPAD('New Lot       ',14)||'|'
              ||RPAD('Serial Number ',14)||'|'||RPAD('Qty         ',12)||'|'||RPAD('UOM  ',5)||'|'
              ||RPAD('Inter TRX Id  ',14)||'|'||RPAD('Batch Id  ',10)||'|'
              ||RPAD('Log Code  ',10)||'|'||'Log Message');
    print_out(  RPAD('--------  ',10)||'|'||RPAD('---  ',5)||'|'||RPAD('----------  ',12)||'|'
              ||RPAD('----------  ',12)||'|'||RPAD('------------  ',14)||'|'||RPAD('------------------  ',20)||'|'
              ||RPAD('--------  ',10)||'|'||RPAD('------------  ',14)||'|'||RPAD('------------  ',14)||'|'
              ||RPAD('------------  ',14)||'|'||RPAD('----------  ',12)||'|'||RPAD('---  ',5)||'|'
              ||RPAD('------------  ',14)||'|'||RPAD('--------  ',10)||'|'
              ||RPAD('--------  ',10)||'|'||'--------------------------------------  ');
                               
   for r_err_pop in c_err_pop1 loop
      print_out( RPAD(r_err_pop.item_stock_id ,10)||'|'||RPAD(nvl(r_err_pop.organization_code,'.'),5)||'|'||RPAD(r_err_pop.item_number,12)||'|'
               ||RPAD(nvl(r_err_pop.account_id,-9),12)||'|'||RPAD(nvl(r_err_pop.subinventory_code,'.') ,14)||'|'||RPAD(nvl(r_err_pop.locator_name,'.') ,20)||'|'
               ||RPAD(nvl(r_err_pop.item_revision,'.') ,10)||'|'||RPAD(nvl(r_err_pop.original_lot_number,'.'),14)||'|'||RPAD(nvl(r_err_pop.new_lot_number,'.'),14)||'|'
               ||RPAD(nvl(r_err_pop.serial_number,'.') ,14)||'|'||RPAD(nvl(r_err_pop.qty,-9) ,12)||'|'||RPAD(nvl(r_err_pop.uom,'.') ,5)||'|'
               ||RPAD(nvl(r_err_pop.trx_interface_id,-9) ,14)||'|'||RPAD(nvl(r_err_pop.batch_id,-9) ,10)||'|'
               ||RPAD(nvl(r_err_pop.log_code,'.') ,10)||'|'
               ||nvl(r_err_pop.log_msg,'.'));   
   
   end loop;
   print_out(  RPAD('--------  ',10)||'|'||RPAD('---  ',5)||'|'||RPAD('----------  ',12)||'|'
              ||RPAD('----------  ',12)||'|'||RPAD('------------  ',14)||'|'||RPAD('------------------  ',20)||'|'
              ||RPAD('--------  ',10)||'|'||RPAD('------------  ',14)||'|'||RPAD('------------  ',14)||'|'
              ||RPAD('------------  ',14)||'|'||RPAD('----------  ',12)||'|'||RPAD('---  ',5)||'|'
              ||RPAD('------------  ',14)||'|'||RPAD('--------  ',10)||'|'
              ||RPAD('--------  ',10)||'|'||'--------------------------------------  ');
  
  exception
    when others then
      errbuf  := 'GEN EXE - main_in - '||substr(sqlerrm,1,200);
      retcode := 1; 
  end main_in;                                                                                           

end XXINV_ITEM_STOCK_IN_OUT_PKG;
/
