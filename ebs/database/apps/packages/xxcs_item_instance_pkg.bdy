CREATE OR REPLACE PACKAGE BODY xxcs_item_instance_pkg IS

--------------------------------------------------------------------
--  name:            XXCS_ITEM_INSTANCE_PKG
--  create by:       Vitaly K.
--  Revision:        1.4
--  creation date:   10/01/2010
--------------------------------------------------------------------
--  purpose :        For concurrent XX: Set Item Instance  (short name: XXCS_SET_ITEM_INSTANCE)
--                   program that clean IB for instances that return back to inventory
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  10/01/2010  Vitaly K.         initial build
--  1.1  06/11/2011  Roman V.          set_item_instance /update_child_instance_systems 
--                                     rull out instances that returned from shows/T&B and sold to same customer
--  1.2  22/01/2012  Dalit A. Raviv    set_item_instance - add condition to population
--  1.3  24/04/2012  Dalit A. Raviv    set_item_instance - add or condition on attribute8 
--                                     We now add the region as part from the condition to 
--                                     delete the data when a printer is returning to Objet. 
--  1.4  29/04/2013  Dalit A. Raviv    new program to update US CS region 
--  1.5  12/03/2015  Dalit A. Raviv    CHG0034735 - procedure set_item_instance - Machine return to warehouse                                    
--------------------------------------------------------------------

  --------------------------------------------------------------------
  --  name:            set_item_instance
  --  create by:       XXX
  --  Revision:        1.0
  --  creation date:   XX/XX/2010
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  10/01/2010  Vitaly K.         initial build
  --  1.1  06/11/2011  Roman V.          rull out instances that returned from
  --                                     shows/T&B and sold to same customer
  --  1.2  22/01/2012  Dalit A. Raviv    add condition to population
  --  1.3  24/04/2012  Dalit A. Raviv    add or condition on attribute8 
  --                                     We now add the region as part from the condition to 
  --                                     delete the data when a printer is returning to Objet.
  --  1.4  12/03/2015  Dalit A. Raviv    CHG0034735 - Machine return to warehouse  , update only IB instance that already in SFDC.
  --------------------------------------------------------------------
  procedure set_item_instance(errbuf   out varchar2,
                              errcode  out varchar2) IS

    l_step                     varchar2(100);
    l_error_message            varchar2(3000);

    l_instance_rec             csi_datastructures_pub.instance_rec;
    l_ext_attrib_values_tbl    csi_datastructures_pub.extend_attrib_values_tbl;
    l_party_tbl                csi_datastructures_pub.party_tbl;
    l_account_tbl              csi_datastructures_pub.party_account_tbl;
    l_pricing_attrib_tbl       csi_datastructures_pub.pricing_attribs_tbl;
    l_org_assignments_tbl      csi_datastructures_pub.organization_units_tbl;
    l_asset_assignment_tbl     csi_datastructures_pub.instance_asset_tbl;
    l_txn_rec                  csi_datastructures_pub.transaction_rec;

    -- OUT variables 
    x_instance_id_lst          csi_datastructures_pub.id_tbl;
    x_return_status            varchar2(2000);
    x_msg_count                number;
    x_msg_data                 varchar2(2000);
    t_output                   varchar2(2000);
    t_msg_dummy                number;

    -- total information 
    v_counter                  number:=0;
    v_success_cntr             number:=0;
    v_failure_cntr             number:=0;

    -- 1.4 12/03/2015 Dalit A. Raviv CHG0034735 change population
    cursor get_instances_for_update is
      select cii.instance_id ,cii.ATTRIBUTE12
      from   xxsf_csi_item_instances cii,
             xxcs_items_printers_v pr
      where  pr.inventory_item_id = cii.Inventory_item_id
      AND (cii.account_end_customer_id is not null or cii.install_date is not null or
          cii.attribute3         is not null or cii.attribute7 is not null OR  --- COI flag or COI date
          cii.attribute8         = 'Internal') -- Cs region
      AND    EXISTS (SELECT 1 
                     FROM   csi_item_instances cii_oa 
                     WHERE  cii_oa.location_type_code  = 'INVENTORY'
                     AND    cii_oa.INSTANCE_NUMBER = cii.INSTANCE_ID) -- return to warehouse
      and    cii.Status_description  not in ('Returned for Repair', 'Terminated', 'CREATED', 'EXPIRED')
      -- rull out instances that returned from shows/T&B and sold to same customer
      and    not exists ( select 1
                        from   oe_order_lines_all oola
                        where  oola.attribute1 = cii.instance_id
                        and    oola.line_id = (SELECT cii_oa1.last_oe_rma_line_id 
                                               FROM   csi_item_instances cii_oa1 
                                               WHERE  cii_oa1.INSTANCE_ID = cii.INSTANCE_ID))
      and    cii.last_update_date  < trunc(sysdate) - 1;

      /*select cii.instance_id,  cii.object_version_number
      from   csi_item_instances      cii,
             csi_instance_statuses   cis
      where  cii.instance_status_id  = cis.instance_status_id
      --  1.3  24/04/2012  Dalit A. Raviv
      -- add or condition on attribute8
      -- We now add the region as part from the condition 
      -- to delete the data when a printer is returning to Objet.
      and    (cii.system_id          is not null or cii.install_date is not null or
              cii.attribute3         is not null or cii.attribute7 is not null or
              cii.attribute8         = 'Internal')
      and    cii.location_type_code  = 'INVENTORY'
      and    cis.name                not in ('Returned for Repair', 'Terminated', 'CREATED', 'EXPIRED')
      -- Roman 06-Nov-11 rull out instances that returned from shows/T&B and sold to same customer
      and    not exists ( select 1
                          from   oe_order_lines_all oola
                          where  oola.attribute1 = cii.instance_id
                          and    oola.line_id = cii.last_oe_rma_line_id)
      and    cii.last_update_date  < trunc(sysdate) - 1; -- 1.2  22/01/2012  Dalit A. Raviv
      */
    -- 12/03/2015 Dalit A. Raviv CHG0034735 
    l_rec xxobjt_custom_events%ROWTYPE;
    l_ovn csi_item_instances.object_version_number%type;
  BEGIN

    l_step :='Step 1';
    FOR instance_row IN get_instances_for_update LOOP
      l_step :='Step 5';

      IF l_party_tbl.EXISTS(1) IS NOT NULL THEN
        l_party_tbl.DELETE;
      END IF;

      IF l_account_tbl.EXISTS(1) IS NOT NULL THEN
        l_account_tbl.DELETE;
      END IF;

      IF l_ext_attrib_values_tbl.EXISTS(1) IS NOT NULL THEN
        l_ext_attrib_values_tbl.DELETE;
      END IF;
      -- 1.4 12/03/2015 Dalit A. Raviv CHG0034735 
      -- Get Object version number
      begin
        l_ovn := null;
        select cii.object_version_number
        into   l_ovn
        from   csi_item_instances cii
        where  cii.instance_id    = instance_row.instance_id;
      exception
        when others then
          null;
      end;
      -- 

      v_counter:=v_counter+1;
      l_instance_rec.instance_id          := instance_row.instance_id;
      l_instance_rec.SYSTEM_ID            := NULL;  
      l_instance_rec.INSTALL_DATE         := NULL;  
      l_instance_rec.ATTRIBUTE3           := NULL;  
      l_instance_rec.ATTRIBUTE7           := NULL;  
      l_instance_rec.ATTRIBUTE8           := NULL;  --Cs Region
      l_instance_rec.object_version_number:= l_ovn; -- 1.4 12/03/2015 Dalit A. Raviv CHG0034735 

      l_txn_rec.transaction_id         := FND_API.G_MISS_NUM;
      l_txn_rec.transaction_date       := SYSDATE;
      l_txn_rec.source_transaction_date:= SYSDATE;
      l_txn_rec.transaction_type_id    := 1;

      csi_item_instance_pub.update_item_instance(
             p_api_version           => 1.0,                     -- IN     NUMBER
             p_commit                => 'F',
             p_init_msg_list         => 'F',
             p_instance_rec          => l_instance_rec,
             p_ext_attrib_values_tbl => l_ext_attrib_values_tbl, -- IN OUT NOCOPY csi_datastructures_pub.extend_attrib_values_tbl
             p_party_tbl             => l_party_tbl,             -- IN OUT NOCOPY csi_datastructures_pub.party_tbl
             p_account_tbl           => l_account_tbl,           -- IN OUT NOCOPY csi_datastructures_pub.party_account_tbl
             p_pricing_attrib_tbl    => l_pricing_attrib_tbl,    -- IN OUT NOCOPY csi_datastructures_pub.pricing_attribs_tbl
             p_org_assignments_tbl   => l_org_assignments_tbl,   -- IN OUT NOCOPY csi_datastructures_pub.organization_units_tbl
             p_asset_assignment_tbl  => l_asset_assignment_tbl,  -- IN OUT NOCOPY csi_datastructures_pub.instance_asset_tbl
             p_txn_rec               => l_txn_rec,               -- IN OUT NOCOPY csi_datastructures_pub.transaction_rec
             x_instance_id_lst       => x_instance_id_lst,
             x_return_status         => x_return_status,         -- OUT    NOCOPY VARCHAR2
             x_msg_count             => x_msg_count,             -- OUT    NOCOPY NUMBER
             x_msg_data              => x_msg_data);             -- OUT    NOCOPY VARCH

      l_step :='Step 10';
      -- Output the results
      if x_msg_count > 0 then
        for j in 1 .. x_msg_count loop
            fnd_msg_pub.get ( j,
                              FND_API.G_FALSE,
                              x_msg_data,
                              t_msg_dummy );
            t_output := ( 'Msg'|| To_Char( j) || ': ' || x_msg_data );
            fnd_file.put_line (fnd_file.log,'=== ERROR (Instance_id = '||instance_row.instance_id||'): '|| SubStr (t_output, 1, 255));
        end loop;
        v_failure_cntr:=v_failure_cntr+1;
        rollback;
      else
          fnd_file.put_line (fnd_file.log,'=== SUCCESS: Instance_id = '||instance_row.instance_id||' was updated  successfuly');
          v_success_cntr := v_success_cntr + 1;
          commit;
          -- 1.4 12/03/2015 Dalit A. Raviv CHG0034735
          --l_rec.source_name := 'XXCSI_I_PARTIES_H_BIR_TRG';
          --l_rec.event_table := 'CSI_I_PARTIES_H';
          IF instance_row.attribute12 IS NOT NULL THEN
              l_rec.event_key   := instance_row.instance_id;
              l_rec.event_name  := 'MACHINE_RETURN';
              xxobjt_custom_events_pkg.insert_event(l_rec);
          END IF;
          -- end;
      end if;
    
    end loop;
    commit;

    -- Display total information ...
    fnd_file.put_line (fnd_file.log,''); --empty line
    fnd_file.put_line (fnd_file.log,'***************************************************************************');
    fnd_file.put_line (fnd_file.log,'********************TOTAL INFORMATION******************************');
    fnd_file.put_line (fnd_file.log,'***************************************************************************');
    fnd_file.put_line (fnd_file.log,'=========There are '||v_counter||' instances for updating');
    fnd_file.put_line (fnd_file.log,'============='||v_success_cntr ||' instances were updated SUCCESSFULY ');
    fnd_file.put_line (fnd_file.log,'============='||v_failure_cntr ||' updates  FAILURED');

  exception
    when others then
      l_error_message:=' Unexpected ERROR in XXCS_ITEM_INSTANCE_PKG.set_item_instance (step = '||l_step || ') : ' || SQLERRM;
      errcode:= '2';
      errbuf :=l_error_message;
      fnd_file.put_line(fnd_file.log,'========'||l_error_message);
  end set_item_instance;
  
  --------------------------------------------------------------------
  --  name:            update_us_cs_region
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   29/04/2013
  --------------------------------------------------------------------
  --  purpose :        Concurrent - XX: Update US IB according to states
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  29/04/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure update_us_cs_region (errbuf   out varchar2,
                                 errcode  out varchar2) is
                                 
    l_error_message            varchar2(3000);

    l_instance_rec             csi_datastructures_pub.instance_rec;
    l_ext_attrib_values_tbl    csi_datastructures_pub.extend_attrib_values_tbl;
    l_party_tbl                csi_datastructures_pub.party_tbl;
    l_account_tbl              csi_datastructures_pub.party_account_tbl;
    l_pricing_attrib_tbl       csi_datastructures_pub.pricing_attribs_tbl;
    l_org_assignments_tbl      csi_datastructures_pub.organization_units_tbl;
    l_asset_assignment_tbl     csi_datastructures_pub.instance_asset_tbl;
    l_txn_rec                  csi_datastructures_pub.transaction_rec;

    -- OUT variables 
    x_instance_id_lst          csi_datastructures_pub.id_tbl;
    x_return_status            varchar2(2000);
    x_msg_count                number;
    x_msg_data                 varchar2(2000);
    l_output                   varchar2(2000);
    l_msg_dummy                number;

    -- total information 
    l_counter                  number := 0;
    l_success_cntr             number := 0;
    l_failure_cntr             number := 0;

    cursor get_instances_for_update is
      select distinct -- ib return printers with warrent and contract this dupplicate the record
             ib.instance_id,
             ib.object_version_number,
             ib.serial_number,
             ip.item_type,
             ib.state,
             stt.meaning,
             ib.owner_cs_region      Current_cs_region,
             SUBSTR(ib.owner_cs_region,1,instr(ib.owner_cs_region,' '))||stt.ATTRIBUTE1||SUBSTR(ib.owner_cs_region,instr(ib.owner_cs_region,' ',-1)) new_cs_region
      from   xxcs_install_base_bi_v   ib,
             xxcs_items_printers_v    ip,
             fnd_common_lookups       stt
      where  ib.inventory_item_id     = ip.inventory_item_id
      and    ib.country               = 'United States'
      and    stt.lookup_type          = 'US_STATE'
      and    stt.lookup_code          = ib.state
      and    ip.item_type             in ('PRINTER','WATER-JET')
      and    nvl(ib.active_end_date,  sysdate + 1) > sysdate
      and    instr(ib.owner_cs_region, stt.attribute1) = 0 ;-- this condition give only IB that the subregion is diffrent from the subregion(att1) at the lookup.
      --and    rownum < 3;

      -- to update att8 in csi_item_instances cii table.
  begin
    errbuf  := null;
    errcode := 0;
    -- user SCHEDULER
    -- resp CRM Service Super User Objet
    -- fnd_global.APPS_INITIALIZE(user_id => 1111, resp_id => 51137, resp_appl_id => 514);
    
    for instance_row in get_instances_for_update loop
      
      if l_party_tbl.exists(1) is not null then
        l_party_tbl.delete;
      end if;

      if l_account_tbl.exists(1) is not null then
        l_account_tbl.delete;
      end if;

      if l_ext_attrib_values_tbl.exists(1) is not null then
        l_ext_attrib_values_tbl.delete;
      end if;

      l_counter := l_counter + 1;
      l_instance_rec.instance_id          := instance_row.instance_id;
      --l_instance_rec.SYSTEM_ID            := NULL;  
      --l_instance_rec.install_date         := NULL;  
      l_instance_rec.attribute8           := instance_row.new_cs_region;
      l_instance_rec.object_version_number:= instance_row.object_version_number;

      l_txn_rec.transaction_id         := FND_API.G_MISS_NUM;
      l_txn_rec.transaction_date       := SYSDATE;
      l_txn_rec.source_transaction_date:= SYSDATE;
      l_txn_rec.transaction_type_id    := 1;

      csi_item_instance_pub.update_item_instance(
             p_api_version           => 1.0,                     -- IN     NUMBER
             p_commit                => 'F',
             p_init_msg_list         => 'F',
             p_instance_rec          => l_instance_rec,
             p_ext_attrib_values_tbl => l_ext_attrib_values_tbl, -- IN OUT NOCOPY csi_datastructures_pub.extend_attrib_values_tbl
             p_party_tbl             => l_party_tbl,             -- IN OUT NOCOPY csi_datastructures_pub.party_tbl
             p_account_tbl           => l_account_tbl,           -- IN OUT NOCOPY csi_datastructures_pub.party_account_tbl
             p_pricing_attrib_tbl    => l_pricing_attrib_tbl,    -- IN OUT NOCOPY csi_datastructures_pub.pricing_attribs_tbl
             p_org_assignments_tbl   => l_org_assignments_tbl,   -- IN OUT NOCOPY csi_datastructures_pub.organization_units_tbl
             p_asset_assignment_tbl  => l_asset_assignment_tbl,  -- IN OUT NOCOPY csi_datastructures_pub.instance_asset_tbl
             p_txn_rec               => l_txn_rec,               -- IN OUT NOCOPY csi_datastructures_pub.transaction_rec
             x_instance_id_lst       => x_instance_id_lst,
             x_return_status         => x_return_status,         -- OUT    NOCOPY VARCHAR2
             x_msg_count             => x_msg_count,             -- OUT    NOCOPY NUMBER
             x_msg_data              => x_msg_data);             -- OUT    NOCOPY VARCH

      if x_return_status <> 'S' then
        -- Output the results
        if x_msg_count > 0 then
          for j in 1 .. x_msg_count loop
            fnd_msg_pub.get ( j,
                              FND_API.G_FALSE,
                              x_msg_data,
                              l_msg_dummy );
            l_output := ( 'Msg'|| To_Char( j) || ': ' || x_msg_data );
            fnd_file.put_line (fnd_file.log,'E: Instance_id = '||instance_row.instance_id||' Serial '|| instance_row.serial_number ||' - '|| SubStr (l_output, 1, 255));
            dbms_output.put_line('E: Instance_id = '||instance_row.instance_id||' Serial '|| instance_row.serial_number ||' - '|| SubStr (l_output, 1, 255)); 
          end loop;
          l_failure_cntr := l_failure_cntr + 1;
        end if;
      else
        fnd_file.put_line (fnd_file.log,'S: Instance_id = '||instance_row.instance_id||' Serial '|| instance_row.serial_number );
        fnd_file.put_line (fnd_file.log,'Current cs region '|| instance_row.current_cs_region||' New cs region '|| instance_row.new_cs_region);
        dbms_output.put_line('S: Instance_id = '||instance_row.instance_id||' Serial '|| instance_row.serial_number); 
        dbms_output.put_line('Current cs region '|| instance_row.current_cs_region||' New cs region '|| instance_row.new_cs_region);
        l_success_cntr := l_success_cntr + 1;
      end if;
    end loop;
    commit;

    -- Display total information ...
    fnd_file.put_line (fnd_file.log,'---------------------------');
    fnd_file.put_line (fnd_file.log,'Instances Total '||l_counter);
    fnd_file.put_line (fnd_file.log,'Instances success '||l_success_cntr );
    fnd_file.put_line (fnd_file.log,'Instances failured '||l_failure_cntr);
    fnd_file.put_line (fnd_file.log,'---------------------------');
    dbms_output.put_line('---------------------------'); 
    dbms_output.put_line('Instances Total '||l_counter); 
    dbms_output.put_line('Instances successfuly '||l_success_cntr); 
    dbms_output.put_line('Instances failured '||l_failure_cntr); 
    dbms_output.put_line('---------------------------');

  exception
    when others then
      l_error_message := 'General Err in XXCS_ITEM_INSTANCE_PKG.update_us_cs_region: ' || substr(sqlerrm,1,240);
      errcode := '2';
      errbuf  := l_error_message;
      fnd_file.put_line(fnd_file.log,l_error_message);
      dbms_output.put_line(l_error_message); 
  end update_us_cs_region;

  --------------------------------------------------------------------
  --  name:            set_item_instance
  --  create by:       Vitaly K.
  --  Revision:        1.0
  --  creation date:   10/01/2010
  --------------------------------------------------------------------
  --  purpose :        For concurrent XX: Update Child Instance Systems  (short name: XXCS_UPD_CHILD_INSTANCE_SYS)
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  10/01/2010  Vitaly K.         initial build
  --  1.1  06/11/2011  Roman V.          rull out instances that returned from
  --                                     shows/T&B and sold to same customer
  --------------------------------------------------------------------
  PROCEDURE update_child_instance_systems(errbuf   out varchar2,
                                          errcode  out varchar2) IS

    l_step                     varchar2(100);
    l_error_message            varchar2(3000);

    l_instance_rec             csi_datastructures_pub.instance_rec;
    l_ext_attrib_values_tbl    csi_datastructures_pub.extend_attrib_values_tbl;
    l_party_tbl                csi_datastructures_pub.party_tbl;
    l_account_tbl              csi_datastructures_pub.party_account_tbl;
    l_pricing_attrib_tbl       csi_datastructures_pub.pricing_attribs_tbl;
    l_org_assignments_tbl      csi_datastructures_pub.organization_units_tbl;
    l_asset_assignment_tbl     csi_datastructures_pub.instance_asset_tbl;
    l_txn_rec                  csi_datastructures_pub.transaction_rec;

    -- OUT variables 
    x_instance_id_lst          csi_datastructures_pub.id_tbl;
    x_return_status            varchar2(2000);
    x_msg_count                number;
    x_msg_data                 varchar2(2000);
    t_output                   varchar2(2000);
    t_msg_dummy                number;

    -- total information 
    v_counter                  number:=0;
    v_success_cntr             number:=0;
    v_failure_cntr             number:=0;

    cursor get_child_instances_for_update is
      select cii_child.instance_id              child_instance_id,
             cii_child.object_version_number    child_object_version_number,
             cii_parent.system_id               parent_system_id
      from   csi_item_instances      cii_child,
             mtl_system_items_b      msi,
             csi_ii_relationships    cir,
             csi_item_instances      cii_parent
      where  cii_child.inventory_item_id = msi.inventory_item_id
      and    msi.organization_id         = 91
      and    msi.attribute22             = 'Y'
      and    cii_child.system_id         is null -- child instance without system_id
      and    cii_child.instance_id       = cir.subject_id
      and    cii_parent.instance_id      = cir.object_id
      and    cii_parent.system_id        is not null
      and    nvl(cir.active_end_date,sysdate) >= sysdate;

  begin
    l_step :='Step 1';
    for child_instance_row in get_child_instances_for_update loop
      
      l_step :='Step 5';

      if l_party_tbl.exists(1) is not null then
        l_party_tbl.delete;
      end if;

      if l_account_tbl.exists(1) is not null then
        l_account_tbl.delete;
      end if;

      if l_ext_attrib_values_tbl.exists(1) is not null then
        l_ext_attrib_values_tbl.delete;
      end if;

      v_counter:=v_counter+1;
      l_instance_rec.instance_id          := child_instance_row.child_instance_id;
      l_instance_rec.SYSTEM_ID            := CHILD_INSTANCE_ROW.PARENT_SYSTEM_ID;
      l_instance_rec.object_version_number:= child_instance_row.child_object_version_number;


      l_txn_rec.transaction_id         := FND_API.G_MISS_NUM;
      l_txn_rec.transaction_date       := SYSDATE;
      l_txn_rec.source_transaction_date:= SYSDATE;
      l_txn_rec.transaction_type_id    := 1;

      csi_item_instance_pub.update_item_instance(
               p_api_version           => 1.0,                     -- IN     NUMBER
               p_commit                => 'F',
               p_init_msg_list         => 'F',
               p_instance_rec          => l_instance_rec,
               p_ext_attrib_values_tbl => l_ext_attrib_values_tbl, -- IN OUT NOCOPY csi_datastructures_pub.extend_attrib_values_tbl
               p_party_tbl             => l_party_tbl,             -- IN OUT NOCOPY csi_datastructures_pub.party_tbl
               p_account_tbl           => l_account_tbl,           -- IN OUT NOCOPY csi_datastructures_pub.party_account_tbl
               p_pricing_attrib_tbl    => l_pricing_attrib_tbl,    -- IN OUT NOCOPY csi_datastructures_pub.pricing_attribs_tbl
               p_org_assignments_tbl   => l_org_assignments_tbl,   -- IN OUT NOCOPY csi_datastructures_pub.organization_units_tbl
               p_asset_assignment_tbl  => l_asset_assignment_tbl,  -- IN OUT NOCOPY csi_datastructures_pub.instance_asset_tbl
               p_txn_rec               => l_txn_rec,               -- IN OUT NOCOPY csi_datastructures_pub.transaction_rec
               x_instance_id_lst       => x_instance_id_lst,
               x_return_status         => x_return_status,         -- OUT    NOCOPY VARCHAR2
               x_msg_count             => x_msg_count,             -- OUT    NOCOPY NUMBER
               x_msg_data              => x_msg_data);             -- OUT    NOCOPY VARCH

      l_step :='Step 10';
      -- Output the results
      if x_msg_count > 0 then
        FOR j in 1 .. x_msg_count LOOP
            fnd_msg_pub.get ( j
                            , FND_API.G_FALSE
                            , x_msg_data
                            , t_msg_dummy );
            t_output := ( 'Msg'|| To_Char( j) || ': ' || x_msg_data );
            fnd_file.put_line (fnd_file.log,'=========ERROR (Child_Instance_id='||child_instance_row.child_instance_id||
                                                               '): '|| SubStr ( t_output , 1 , 255 ) );
        END LOOP;
        v_failure_cntr:=v_failure_cntr+1;
      ELSE
        fnd_file.put_line (fnd_file.log,'========SUCCESS: Child_Instance_id='||child_instance_row.child_instance_id||' was updated  successfuly');
        v_success_cntr:=v_success_cntr+1;
      end if;
    end loop;
    commit;

    -- Display total information ...
    fnd_file.put_line (fnd_file.log,''); 
    fnd_file.put_line (fnd_file.log,'***************************************************************************');
    fnd_file.put_line (fnd_file.log,'********************TOTAL INFORMATION******************************');
    fnd_file.put_line (fnd_file.log,'***************************************************************************');
    fnd_file.put_line (fnd_file.log,'=========There are '||v_counter||' instances for updating');
    fnd_file.put_line (fnd_file.log,'============='||v_success_cntr ||' instances were updated SUCCESSFULY ');
    fnd_file.put_line (fnd_file.log,'============='||v_failure_cntr ||' updates  FAILURED');

  exception
    when others then
       l_error_message:=' Unexpected ERROR in XXCS_ITEM_INSTANCE_PKG.update_child_instance_systems (step='||l_step || ') : ' || SQLERRM;
       errcode:= '2';
       errbuf :=l_error_message;
       fnd_file.put_line(fnd_file.log,'========'||l_error_message);
  end update_child_instance_systems;

------------------------------------------------------------------
/*FUNCTION get_instance_top_level_parent(p_child_instance_id IN NUMBER) RETURN NUMBER IS
       ---from bottom to top
CURSOR get_top_level_parent_instance IS
SELECT PARENT_CHILD_HIERARCHY_TAB.parent_instance_id
       ---PARENT_CHILD_HIERARCHY_TAB.parent_instance_number,
       ---PARENT_CHILD_HIERARCHY_TAB.parent_part_number,
       ---PARENT_CHILD_HIERARCHY_TAB.child_instance_id,
       ---PARENT_CHILD_HIERARCHY_TAB.child_instance_number,
       ---PARENT_CHILD_HIERARCHY_TAB.child_part_number,
       ---PARENT_CHILD_HIERARCHY_TAB.parent_level
FROM
(SELECT PARENT_CHILD_TAB.parent_instance_id,
       PARENT_CHILD_TAB.parent_instance_number,
       PARENT_CHILD_TAB.parent_part_number,
       PARENT_CHILD_TAB.child_instance_id,
       PARENT_CHILD_TAB.child_instance_number,
       PARENT_CHILD_TAB.child_part_number,
       LEVEL  parent_level,
       MAX(LEVEL) OVER (PARTITION BY trunc(SYSDATE))   max_parent_level

FROM
(-------------PARENT-CHILD---------------
select  ciip.instance_id     parent_instance_id,
        ciip.instance_number parent_instance_number,
        msip.segment1        parent_part_number,
        msip.description     parent_part_description,
        ciip.serial_number parent_serial_number,
        ciip.active_start_date,
        ciip.active_end_date,
        ciip.location_id,
        ciip.install_date,
        ciip.install_location_id,
        ciic.instance_id     child_instance_id,
        ciic.instance_number child_instance_number,
        msic.segment1        child_part_number,
        msic.description child_part_description,
        ciic.serial_number child_serial_number
FROM    CSI_ITEM_INSTANCES      ciip,
        CSI_II_RELATIONSHIPS    cir,
        CSI_ITEM_INSTANCES      ciic,
        MTL_SYSTEM_ITEMS        msip,
        MTL_SYSTEM_ITEMS        msic
where   ciip.instance_id = cir.object_id
and     ciic.instance_id = cir.subject_id
and     ciip.inventory_item_id = msip.inventory_item_id
and     ciic.inventory_item_id = msic.inventory_item_id
and     msip.organization_id = 91
and     msic.organization_id = 91
AND     SYSDATE BETWEEN  cir.active_start_date AND nvl(cir.active_end_date,SYSDATE)
                     )   PARENT_CHILD_TAB
CONNECT BY PRIOR PARENT_CHILD_TAB.parent_instance_id=PARENT_CHILD_TAB.child_instance_id
START WITH PARENT_CHILD_TAB.child_instance_id=p_child_instance_id --parameter
                                )   PARENT_CHILD_HIERARCHY_TAB
WHERE PARENT_CHILD_HIERARCHY_TAB.parent_level=PARENT_CHILD_HIERARCHY_TAB.max_parent_level;

v_top_level_parent_instance_id  NUMBER;



BEGIN

IF p_child_instance_id IS NULL THEN
   RETURN NULL;
END IF;

IF get_top_level_parent_instance%ISOPEN THEN
   CLOSE get_top_level_parent_instance;
END IF;
OPEN get_top_level_parent_instance;
FETCH get_top_level_parent_instance INTO v_top_level_parent_instance_id;
CLOSE get_top_level_parent_instance;

RETURN v_top_level_parent_instance_id;


EXCEPTION
  WHEN OTHERS THEN
    RETURN NULL;
END get_instance_top_level_parent;*/

  ------------------------------------------------------------------
  FUNCTION get_child_inst_from_hierarchy(p_parent_instance_id           IN NUMBER,
                                         p_child_inst_inventory_item_id IN NUMBER,
                                         p_error_interface_header_id    IN NUMBER
                                         --add 2 OUT NOCOPY parameters
                                         ) RETURN XXCS_INSTANCE_TBL
    PIPELINED IS
    --Take the instance (Printer) from the SR and see if we have an item (returen item from SR) under the configuration of the printer

    CURSOR get_child_inst_from_hierarchy IS
      SELECT ---HIERARCHY_TAB.parent_instance_id,
      ---HIERARCHY_TAB.parent_instance_number,
      ---HIERARCHY_TAB.parent_part_number,
       HIERARCHY_TAB.child_instance_id,
       HIERARCHY_TAB.child_inst_creation_date_rank,
       HIERARCHY_TAB.child_inst_inventory_item_id,
       HIERARCHY_TAB.child_part_number, --segment1
       NULL organization_id,
       HIERARCHY_TAB.child_instance_quantity,
       HIERARCHY_TAB.child_part_primary_uom
      ---HIERARCHY_TAB.child_instance_number,
      ---HIERARCHY_TAB.child_instance_creation_date,
      ---HIERARCHY_TAB.child_inst_creation_date_rank
      ---HIERARCHY_TAB.parent_level,

        FROM (SELECT HIER_TAB.parent_instance_id,
                     HIER_TAB.parent_instance_number,
                     HIER_TAB.parent_part_number,
                     HIER_TAB.child_instance_id,
                     HIER_TAB.child_instance_terminated_flag,
                     HIER_TAB.child_instance_number,
                     HIER_TAB.child_part_number,
                     HIER_TAB.child_inst_inventory_item_id,
                     HIER_TAB.child_part_primary_uom,
                     HIER_TAB.child_instance_quantity,
                     HIER_TAB.child_instance_creation_date,
                     DENSE_RANK() OVER(PARTITION BY HIER_TAB.child_inst_inventory_item_id ORDER BY HIER_TAB.child_instance_creation_date, HIER_TAB.child_instance_id) child_inst_creation_date_rank
                FROM (SELECT PARENT_CHILD_TAB.parent_instance_id,
                             PARENT_CHILD_TAB.parent_instance_number,
                             PARENT_CHILD_TAB.parent_part_number,
                             PARENT_CHILD_TAB.child_instance_id,
                             PARENT_CHILD_TAB.child_instance_terminated_flag,
                             PARENT_CHILD_TAB.child_instance_number,
                             PARENT_CHILD_TAB.child_part_number,
                             PARENT_CHILD_TAB.child_part_primary_uom,
                             PARENT_CHILD_TAB.child_inst_inventory_item_id,
                             PARENT_CHILD_TAB.child_instance_quantity,
                             PARENT_CHILD_TAB.child_instance_creation_date
                        FROM ( -------------PARENT-CHILD---------------
                              select ciip.instance_id parent_instance_id,
                                      ciip.instance_number parent_instance_number,
                                      msip.segment1 parent_part_number,
                                      msip.description parent_part_description,
                                      ciip.serial_number parent_serial_number,
                                      ciip.active_start_date,
                                      ciip.active_end_date,
                                      ciip.location_id,
                                      ciip.install_date,
                                      ciip.install_location_id,
                                      ciic.instance_id child_instance_id,
                                      nvl(cisc.terminated_flag, 'N') child_instance_terminated_flag,
                                      ciic.creation_date child_instance_creation_date,
                                      ciic.instance_number child_instance_number,
                                      ciic.quantity child_instance_quantity,
                                      msic.inventory_item_id child_inst_inventory_item_id,
                                      msic.segment1 child_part_number,
                                      msic.description child_part_description,
                                      msic.primary_uom_code child_part_primary_uom,
                                      ciic.serial_number child_serial_number
                                FROM CSI_ITEM_INSTANCES    ciip, ---parent
                                      CSI_II_RELATIONSHIPS  cir,
                                      CSI_ITEM_INSTANCES    ciic, ---child
                                      CSI_INSTANCE_STATUSES cisc, ---child instance status
                                      MTL_SYSTEM_ITEMS      msip,
                                      MTL_SYSTEM_ITEMS      msic
                               where ciip.instance_id = cir.object_id
                                 and ciic.instance_id = cir.subject_id
                                 AND ciic.instance_status_id =
                                     cisc.instance_status_id
                                 and ciip.inventory_item_id =
                                     msip.inventory_item_id
                                 and ciic.inventory_item_id =
                                     msic.inventory_item_id
                                 and msip.organization_id = 91
                                 and msic.organization_id = 91
                                 AND SYSDATE BETWEEN cir.active_start_date AND
                                     nvl(cir.active_end_date, SYSDATE)) PARENT_CHILD_TAB
                      CONNECT BY PRIOR PARENT_CHILD_TAB.child_instance_id =
                                  PARENT_CHILD_TAB.parent_instance_id
                       START WITH PARENT_CHILD_TAB.parent_instance_id =
                                  p_parent_instance_id --PARAMETER
                      ) HIER_TAB
               WHERE HIER_TAB.child_inst_inventory_item_id =
                     p_child_inst_inventory_item_id ---PARAMETER
                 AND HIER_TAB.child_instance_terminated_flag <> 'Y' ---Not Terminated Child Item Instance
                 AND NOT EXISTS
               (SELECT t.instance_id ---oha.header_id, t.last_oe_order_line_id, oha.order_number, ou.name          operating_unit
                        FROM csi_item_instances   t,
                             oe_order_lines_all   ola,
                             oe_order_headers_all oha,
                             hr_operating_units   ou
                       WHERE t.last_oe_order_line_id IS NOT NULL
                         AND t.last_oe_order_line_id = ola.line_id
                         AND ola.header_id = oha.header_id
                         AND oha.org_id = ou.organization_id
                         AND ola.line_category_code = 'ORDER'
                         AND oha.header_id = p_error_interface_header_id
                         AND ---PARAMETER
                             t.instance_id = HIER_TAB.child_instance_id)) HIERARCHY_TAB;
    ----WHERE HIERARCHY_TAB.child_inst_creation_date_rank=1; ---will be closed

    v_child_instance_rec XXCS_INSTANCE_REC;

  BEGIN

    IF get_child_inst_from_hierarchy%ISOPEN THEN
      CLOSE get_child_inst_from_hierarchy;
    END IF;
    OPEN get_child_inst_from_hierarchy;
    LOOP
      FETCH get_child_inst_from_hierarchy
        INTO v_child_instance_rec.INSTANCE_ID, v_child_instance_rec.INSTANCE_RANK, v_child_instance_rec.INVENTORY_ITEM_ID, v_child_instance_rec.ITEM, v_child_instance_rec.ORGANIZATION_ID, v_child_instance_rec.QUANTITY, v_child_instance_rec.UOM;
      EXIT WHEN get_child_inst_from_hierarchy%NOTFOUND;
      PIPE ROW(v_child_instance_rec);
    END LOOP;
    CLOSE get_child_inst_from_hierarchy;

    RETURN;

  EXCEPTION
    WHEN OTHERS THEN
      NULL;
  END get_child_inst_from_hierarchy;

  ------------------------------------------------------------------
  FUNCTION get_unassigned_instance(p_owner_party_id            IN NUMBER,
                                   p_owner_party_acct_id       IN NUMBER,
                                   p_inventory_item_id         IN NUMBER,
                                   p_error_interface_header_id IN NUMBER) RETURN XXCS_INSTANCE_TBL PIPELINED IS

  --- See if we have an item (returened item from SO) under the customer that is not in any configuration

  /*  --TYPE XXCS_INSTANCE_REC
  INSTANCE_ID,
  INSTANCE_RANK,
  INVENTORY_ITEM_ID,
  ITEM,
  ORGANIZATION_ID,
  QUANTITY,
  UOM*/

  CURSOR get_unassigned_instance IS
  SELECT INSTANCE_TAB.instance_id,
         INSTANCE_TAB.child_inst_creation_date_rank,
         INSTANCE_TAB.inventory_item_id,
         INSTANCE_TAB.item,
         NULL    organization,
         INSTANCE_TAB.quantity,
         INSTANCE_TAB.primary_uom_code
  FROM (
  SELECT INST_TAB.instance_id,
         INST_TAB.inventory_item_id,
         INST_TAB.item,
         INST_TAB.quantity,
         INST_TAB.primary_uom_code,
         INST_TAB.creation_date,
         DENSE_RANK() OVER (PARTITION BY INST_TAB.inventory_item_id
                     ORDER BY INST_TAB.creation_date,INST_TAB.instance_id) child_inst_creation_date_rank
  FROM (
  SELECT cii.instance_id,
         cii.inventory_item_id,
         msi.segment1    item,
         cii.quantity,
         msi.primary_uom_code,
         cii.creation_date
  FROM   CSI_ITEM_INSTANCES     cii,
         CSI_INSTANCE_STATUSES  cis,
         MTL_SYSTEM_ITEMS_B     msi
  WHERE  cii.owner_party_id        = p_owner_party_id      ---PARAMETER
  AND    cii.owner_party_account_id= p_owner_party_acct_id ---PARAMETER
  AND    cii.inventory_item_id     = p_inventory_item_id   ---PARAMETER
  AND    cii.instance_status_id=cis.instance_status_id
  AND    nvl(cis.terminated_flag,'N')<>'Y'  ---Not Terminated instance
  AND    msi.inventory_item_id=cii.inventory_item_id
  AND    msi.organization_id=91 --Master
  AND NOT EXISTS ---Not Exists in Hierarchies
  (select  ciip.instance_id     parent_instance_id,
          ciip.instance_number parent_instance_number,
          msip.segment1        parent_part_number,
          msip.description     parent_part_description,
          ciip.serial_number parent_serial_number,
          ciip.active_start_date,
          ciip.active_end_date,
          ciip.location_id,
          ciip.install_date,
          ciip.install_location_id,
          ciic.instance_id           child_instance_id,
          ciic.creation_date         child_instance_creation_date,
          ciic.instance_number       child_instance_number,
          msic.inventory_item_id     child_inst_inventory_item_id,
          msic.segment1              child_part_number,
          msic.description           child_part_description,
          ciic.serial_number         child_serial_number
  FROM    CSI_ITEM_INSTANCES      ciip,
          CSI_II_RELATIONSHIPS    cir,
          CSI_ITEM_INSTANCES      ciic,
          MTL_SYSTEM_ITEMS        msip,
          MTL_SYSTEM_ITEMS        msic
  where   ciip.instance_id = cir.object_id
  and     ciic.instance_id = cir.subject_id
  and     ciip.inventory_item_id = msip.inventory_item_id
  and     ciic.inventory_item_id = msic.inventory_item_id
  and     msip.organization_id = 91
  and     msic.organization_id = 91
  AND     SYSDATE BETWEEN  cir.active_start_date AND nvl(cir.active_end_date,SYSDATE)
  AND     cii.instance_id= ciic.instance_id)  ---child_instance_id
  AND  NOT EXISTS (SELECT t.instance_id  ---oha.header_id, t.last_oe_order_line_id, oha.order_number, ou.name          operating_unit
                    FROM csi_item_instances   t,
                         oe_order_lines_all   ola,
                         oe_order_headers_all oha,
                         hr_operating_units   ou
                    WHERE t.last_oe_order_line_id IS NOT NULL        AND
                          t.last_oe_order_line_id = ola.line_id      AND
                          ola.header_id = oha.header_id              AND
                          oha.org_id=ou.organization_id              AND
                          ola.line_category_code = 'ORDER'           AND
                          oha.header_id= p_error_interface_header_id AND  ---PARAMETER
                          t.instance_id= cii.instance_id )
                                   )  INST_TAB
                              )   INSTANCE_TAB;
  ----WHERE  INSTANCE_TAB.child_inst_creation_date_rank=1;  --will be closed for Pipe-line function


  v_unassigned_instance_rec    XXCS_INSTANCE_REC;



  BEGIN



  IF get_unassigned_instance%ISOPEN THEN
     CLOSE get_unassigned_instance;
  END IF;
  OPEN  get_unassigned_instance;
  LOOP
     FETCH get_unassigned_instance INTO v_unassigned_instance_rec.INSTANCE_ID,
                                        v_unassigned_instance_rec.INSTANCE_RANK,
                                        v_unassigned_instance_rec.INVENTORY_ITEM_ID,
                                        v_unassigned_instance_rec.ITEM,
                                        v_unassigned_instance_rec.ORGANIZATION_ID,
                                        v_unassigned_instance_rec.QUANTITY,
                                        v_unassigned_instance_rec.UOM;
     EXIT WHEN get_unassigned_instance%NOTFOUND;
     PIPE ROW (v_unassigned_instance_rec);
  END LOOP;
  CLOSE get_unassigned_instance;

  RETURN;


  EXCEPTION
    WHEN OTHERS THEN
      NULL;
  END get_unassigned_instance;

  ------------------------------------------------------------------
  FUNCTION get_instance_ownership_history(p_instance_id  IN NUMBER) RETURN XXCS_INSTANCE_HISTORY_TBL PIPELINED IS


  /*  ---XXCS_INSTANCE_HISTORY_REC
  INSTANCE_ID,
  HISTORY_RANK,
  PARTY_ID,
  PARTY_NUMBER,
  PARTY_NAME,
  OWNERSHIP_DATE,    ---start
  END_DATE,    ---stop
  INSTANCE_ACTIVE_END_DATE,
  ITEM,
  ITEM_DESC,
  ITEM_TYPE,
  PARTY_HIST_TRANSACTION_ID,
  PARTY_HIST_CREATION_DATE*/

  CURSOR get_inst_ownership_hist IS
  SELECT INST_HISTORY_TAB.instance_id,
         INST_HISTORY_TAB.party_id,
         INST_HISTORY_TAB.party_number,
         INST_HISTORY_TAB.party_name,
         INST_HISTORY_TAB.ownership_date,
         INST_HISTORY_TAB.next_record_instance_id,
         INST_HISTORY_TAB.next_record_party_id,
         INST_HISTORY_TAB.next_record_creation_date,---  end_date,
         INST_HISTORY_TAB.instance_active_end_date,
         INST_HISTORY_TAB.item,
         INST_HISTORY_TAB.item_description,
         INST_HISTORY_TAB.item_type,
         INST_HISTORY_TAB.creation_date,
         INST_HISTORY_TAB.transaction_id
  FROM (
  SELECT cip.instance_id,
         ciph.new_party_id       party_id,
         hp_new.party_number,
         hp_new.party_name,
         decode(trunc(ciph.creation_date),to_date ('27-AUG-2009','DD-MON-YYYY'),cii.active_start_date, ---27-Aug-2009 --data coversion from old system to Oracle Appl
                                          ciph.creation_date)      ownership_date,
         LEAD(cip.instance_id)    OVER (ORDER BY cii.instance_id,ciph.creation_date,ciph.transaction_id)     next_record_instance_id,
         LEAD(ciph.new_party_id)  OVER (ORDER BY cii.instance_id,ciph.creation_date,ciph.transaction_id)     next_record_party_id,
         LEAD(ciph.creation_date) OVER (ORDER BY cii.instance_id,ciph.creation_date,ciph.transaction_id)     next_record_creation_date,---  end_date,
         cii.active_end_date   instance_active_end_date,
         printers.item,
         printers.item_description,
         printers.item_type,
         ciph.creation_date,
         ciph.transaction_id
  FROM   CSI_I_PARTIES_H          ciph,
         CSI_I_PARTIES            cip,
         CSI_ITEM_INSTANCES       cii,
         XXCS_ITEMS_PRINTERS_V    printers,
         HZ_PARTIES               hp_new
  WHERE  ciph.instance_party_id = cip.instance_party_id
  AND    ciph.new_party_id=hp_new.party_id
  AND    cip.relationship_type_code = 'OWNER'
  AND    cip.instance_id=cii.instance_id
  AND    cii.inventory_item_id=printers.inventory_item_id
  AND    cii.instance_id  =nvl(p_instance_id,cii.instance_id)
                           ) INST_HISTORY_TAB
  WHERE NOT (INST_HISTORY_TAB.party_name='Objet Internal Install Base'
                 AND INST_HISTORY_TAB.ownership_date=INST_HISTORY_TAB.next_record_creation_date
                     AND INST_HISTORY_TAB.instance_id=INST_HISTORY_TAB.next_record_instance_id)
  ORDER BY INST_HISTORY_TAB.instance_id,INST_HISTORY_TAB.creation_date,INST_HISTORY_TAB.transaction_id;

  ---Objet Internal Install Base

  v_instance_history_rec        XXCS_INSTANCE_HISTORY_REC;
  v_next_record_instance_id     NUMBER;
  v_next_record_party_id        NUMBER;
  v_next_record_creation_date   DATE;
  v_previous_ownership_date     DATE;
  v_prev_record_was_hidden_flag VARCHAR2(1):='N';
  v_inst_history_rank           NUMBER:=1; ---from oldest ownership record...

  BEGIN


  IF get_inst_ownership_hist%ISOPEN THEN
     CLOSE get_inst_ownership_hist;
  END IF;
  OPEN  get_inst_ownership_hist;
  LOOP
     FETCH get_inst_ownership_hist INTO v_instance_history_rec.INSTANCE_ID,
                                        v_instance_history_rec.PARTY_ID,
                                        v_instance_history_rec.PARTY_NUMBER,
                                        v_instance_history_rec.PARTY_NAME,
                                        v_instance_history_rec.OWNERSHIP_DATE,
                                        v_next_record_instance_id,
                                        v_next_record_party_id,
                                        v_next_record_creation_date,---  end_date,
                                        v_instance_history_rec.INSTANCE_ACTIVE_END_DATE,
                                        v_instance_history_rec.ITEM,
                                        v_instance_history_rec.ITEM_DESC,
                                        v_instance_history_rec.ITEM_TYPE,
                                        v_instance_history_rec.PARTY_HIST_CREATION_DATE,
                                        v_instance_history_rec.PARTY_HIST_TRANSACTION_ID;


     EXIT WHEN get_inst_ownership_hist%NOTFOUND;
     IF v_instance_history_rec.INSTANCE_ID!= v_next_record_instance_id OR
        v_instance_history_rec.PARTY_ID   != v_next_record_party_id    OR
        v_next_record_instance_id IS NULL OR    --last record
        v_next_record_party_id    IS NULL THEN  --last record
        IF v_prev_record_was_hidden_flag='Y' THEN
            v_instance_history_rec.OWNERSHIP_DATE:=v_previous_ownership_date;
            v_prev_record_was_hidden_flag:='N';
        END IF;
        v_instance_history_rec.HISTORY_RANK:=v_inst_history_rank;
        v_inst_history_rank:=v_inst_history_rank+1;
        IF v_instance_history_rec.INSTANCE_ID= v_next_record_instance_id AND v_next_record_instance_id IS NOT NULL THEN
              v_instance_history_rec.end_date:=v_next_record_creation_date-1/(24*60*60);
        ELSE
              v_instance_history_rec.end_date:=v_instance_history_rec.INSTANCE_ACTIVE_END_DATE; --last history record for this instance
        END IF;
        ------------------------------------
        PIPE ROW (v_instance_history_rec);
        ------------------------------------
     ELSE
        IF v_prev_record_was_hidden_flag='N' THEN
            v_previous_ownership_date:=v_instance_history_rec.OWNERSHIP_DATE; ---issue
        END IF;
        v_prev_record_was_hidden_flag:='Y';
     END IF;
     IF v_instance_history_rec.INSTANCE_ID!= v_next_record_instance_id OR
        v_next_record_instance_id IS NULL THEN
         v_inst_history_rank:=1;
     END IF;
  END LOOP;
  CLOSE get_inst_ownership_hist;

  RETURN;


  EXCEPTION
    WHEN OTHERS THEN
      NULL;
  END get_instance_ownership_history;
  ------------------------------------------------------------------
END XXCS_ITEM_INSTANCE_PKG;
/
