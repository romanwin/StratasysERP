create or replace package body xxcsi_ib_relationships_pkg is

--------------------------------------------------------------------
--	customization code: CUST280 - IB - Upgrade IB Serial
--	name:               XXCS_SR_LINK_PKG
--                            
--	create by:          Dalit A. Raviv
--	$Revision:          1.0 
--	creation date:	    10/05/2010 1:32:25 PM
--  Purpose:            Activate Create Link and update SR
--------------------------------------------------------------------
--  ver   date          name            desc
--   1.0    10/05/2010    Dalit A. Raviv  initial build     
-------------------------------------------------------------------- 

  --------------------------------------------------------------------
  --  customization code: CUST280
  --  name:               upd_profile
  --                      
  --  create by:          Dalit A. Raviv
  --  Revision:           1.0 
  --  creation date:      10/05/2010 9:07:38 AM
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   01/05/2010    Dalit A. Raviv  initial build
  --------------------------------------------------------------------  
  Procedure upd_profile (p_timestamp    in  date,
                         p_error_code   out number,
                         p_error_desc   out varchar2) is 
                         
  begin
    -- update profile XXCS_IB_CREATE_REL wwith the last start run time.
    -- each run the program will take all SR that have no Contract and created
    -- between profile value and sysdate (p_timestamp) the time the program start to run.
    update Fnd_Profile_Option_values
    set    profile_option_value = to_char(p_timestamp,'dd/mm/yyyy hh24:mi:ss')
    where  profile_option_id    = (select po.profile_option_id
                                   from   fnd_profile_options    po
                                   where  po.profile_option_name = 'XXCS_IB_CREATE_REL');
    commit;
    p_error_code := 0;
    p_error_desc := null;
  exception
    when others then
      rollback;
      dbms_output.put_line('upd_profile Failed - '||substr(sqlerrm,1,200)); 
      p_error_code := 1;
      p_error_desc := 'upd_profile Failed - '||substr(sqlerrm,1,200);
  end upd_profile;  

  --------------------------------------------------------------------
  --  customization code: CUST280
  --  name:               create_ib_relationship
  --                      
  --  create by:          Dalit A. Raviv
  --  Revision:           1.0 
  --  creation date:      10/05/2010 9:07:38 AM
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   10/05/2010    Dalit A. Raviv  initial build
  --  1.1   31/08/2011    Dalit A. Raviv  change population of program
  --                                      when printer come back from customers
  --                                      it return to objet subinv and the relationship with the
  --                                      customer end. this program run each night and create
  --                                      this relationship again - this is wrong.
  --                                      program population will be more specific. 
  --------------------------------------------------------------------  
  Procedure create_ib_relationship (errbuf   out varchar2,
                                    retcode  out varchar2) is
                                    
    cursor get_pop_c is 
      select cii.instance_id child_instance_id, oola.attribute1 parent_instance_id
      from   csi_item_instances    cii,
             oe_order_lines_all    oola,
             mtl_system_items_b    msib,
             csi_instance_statuses cis
      where  oola.line_id          = cii.last_oe_order_line_id 
      --and    oola.attribute1       is not null 
      and    oola.creation_date    between sysdate - 360 and SYSDATE
      AND    cii.owner_party_id    <> 10041 --Objet Internal Install Base
      AND    cii.inventory_item_id = msib.inventory_item_id
      AND    msib.organization_id  = 91
      AND    msib.comms_nl_trackable_flag = 'Y'
      AND    cii.instance_status_id       = cis.instance_status_id
      AND    cis.terminated_flag          = 'N'
      AND    EXISTS                       (SELECT 1 
                                           FROM   csi_item_instances i
                                           WHERE  i.instance_id      = oola.attribute1);

      /*select cii.instance_id child_instance_id, oola.attribute1 parent_instance_id
      from   csi_item_instances cii,
             oe_order_lines_all oola
      where  oola.line_id       = cii.last_oe_order_line_id 
      and    oola.attribute1    is not null 
      and    oola.creation_date between sysdate - 360 and sysdate; */
      /*
      and    not exists         (select relationship_id
                                 from   csi_ii_relationships cir
                                 where  object_id            = oola.attribute1
                                 and    subject_id           = cii.instance_id
                                 --and    active_end_date      IS NOT NULL
                                 and    (active_end_date is null or active_end_date > sysdate)
                                );
                                */
    l_txn_rec_chi          csi_datastructures_pub.transaction_rec;
    l_relationship_tbl     csi_datastructures_pub.ii_relationship_tbl; 
    l_relationship_tbl1    csi_datastructures_pub.ii_relationship_tbl;   
    l_return_status        varchar2(2500) := null;
    l_msg_count            number := null;
    l_msg_data             varchar2(2500) := null;
    l_msg_index_out        number := null;
    l_relationship_id      number;
    l_validation_level     number := null;   
    l_relation_exist       varchar2(10) := null;                    
  begin
  
    errbuf   := 'Success';
    retcode  := 0;
    
    for get_pop_r in get_pop_c loop
      l_relation_exist := null;
      -- check relationship exists
      begin
        select 'EXISTS'
        into   l_relation_exist
        from   csi_ii_relationships cir
        where  /*object_id            = get_pop_r.parent_instance_id --oola.attribute1
        and*/    subject_id           = get_pop_r.child_instance_id  --cii.instance_id
        AND    cir.relationship_type_code = 'COMPONENT-OF'
        and    (active_end_date is null or active_end_date > sysdate);
        /* keep for debug
        fnd_file.put_line(fnd_file.log,
                          'Exist Relation Between Parent Instance ' || get_pop_r.parent_instance_id ||
                          ' And Child Instance '||get_pop_r.child_instance_id
                          );*/
      exception
        -- relationship do not exists
        when others then
          -- Create the relationship between Parent Instance and Child
          l_return_status    := NULL;
          l_msg_count        := NULL;
          l_msg_index_out    := NULL;
          l_validation_level := NULL;
          l_msg_data         := null;
          l_relationship_tbl := l_relationship_tbl1 ;

          select csi_ii_relationships_s.nextval
          into   l_relationship_id
          from   dual;

          l_relationship_tbl(1).relationship_id        := l_relationship_id;
          l_relationship_tbl(1).relationship_type_code := 'COMPONENT-OF';
          l_relationship_tbl(1).object_id              := get_pop_r.parent_instance_id; --l_parent_instance_id;
          l_relationship_tbl(1).subject_id             := get_pop_r.child_instance_id;  --l_instance_id;
          l_relationship_tbl(1).subject_has_child      := 'N';
          l_relationship_tbl(1).position_reference     := NULL;
          l_relationship_tbl(1).active_start_date      := SYSDATE;
          l_relationship_tbl(1).active_end_date        := NULL;
          l_relationship_tbl(1).display_order          := NULL;
          l_relationship_tbl(1).mandatory_flag         := 'N';
          l_relationship_tbl(1).object_version_number  := 1;

          l_txn_rec_chi.transaction_date        := trunc(SYSDATE);
          l_txn_rec_chi.source_transaction_date := trunc(SYSDATE);
          l_txn_rec_chi.transaction_type_id     := 1;
          l_txn_rec_chi.object_version_number   := 1;

          csi_ii_relationships_pub.create_relationship(p_api_version      => 1,
                                                       p_commit           => FND_API.G_FALSE,     -- i v
                                                       p_init_msg_list    => FND_API.G_TRUE,      -- i v
                                                       p_validation_level => l_validation_level,
                                                       p_relationship_tbl => l_relationship_tbl,
                                                       p_txn_rec          => l_txn_rec_chi,
                                                       x_return_status    => l_return_status,
                                                       x_msg_count        => l_msg_count,
                                                       x_msg_data         => l_msg_data);

          if l_return_status != FND_API.G_RET_STS_SUCCESS then -- 'S'
            fnd_file.put_line(fnd_file.log,'l_return_status - '||l_return_status);
            fnd_msg_pub.get(p_msg_index     => -1,
                            p_encoded       => 'F',
                            p_data          => l_msg_data,
                            p_msg_index_out => l_msg_index_out);
            fnd_file.put_line(fnd_file.log,
                              'Error Create Relation Between Parent Instance ' || get_pop_r.parent_instance_id ||
                              ' And Child Instance '||get_pop_r.child_instance_id ||
                              '. Error: ' || l_msg_data);
            dbms_output.put_line('Relation ' || l_return_status ||
                                 l_msg_data);
            retcode := 1;
          else
             fnd_file.put_line(fnd_file.log,
                          'Success Relation Between Parent Instance ' || get_pop_r.parent_instance_id ||
                          ' And Child Instance '||get_pop_r.child_instance_id
                          );
          end if;
      end;
    end loop;
    if retcode = 0 then
      errbuf   := 'Success';
      retcode  := 0;
    else
      errbuf   := 'Error';
      retcode  := 1;
    end if;
  exception
    when others then
      errbuf   := 'XXCSI_IB_RELATIONSHIPS_PKG.create_ib_relationship general exception'||substr(sqlerrm,1,200);
      retcode  := 2;
  end create_ib_relationship;                                    

end XXCSI_IB_RELATIONSHIPS_PKG;
/
