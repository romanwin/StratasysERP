create or replace package body XXCS_SR_UPD_CONTRACTS is

--------------------------------------------------------------------
--  customization code: CUST311 - Activate Get Contract and update SR
--  name:               XXCS_SR_UPD_CONTRACTS
--                      
--  create by:          Dalit A. Raviv
--  Revision:           1.0 
--  creation date:      28/04/2010 9:07:38 AM
--------------------------------------------------------------------
--  ver   date          name            desc
--  1.0   28/04/2010    Dalit A. Raviv  initial build
--  1.1   10/06/2010    Dalit A. Raviv  Fix error at Upd_sr_with_contract
--------------------------------------------------------------------
  
  --------------------------------------------------------------------
  --  customization code: CUST311 - Activate Get Contract and update SR
  --  name:               Upd_sr_with_contract
  --                      
  --  create by:          Dalit A. Raviv
  --  Revision:           1.0 
  --  creation date:      28/04/2010 9:07:38 AM
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   28/04/2010    Dalit A. Raviv  initial build
  --  1.1   10/06/2010    Dalit A. Raviv  The program do not update the profile because the message
  --                                      from Update_ServiceRequest is too long and then 
  --                                      the program jump to general exception.
  --                                      * add handle of the error message come from API
  --------------------------------------------------------------------
  Procedure Upd_sr_with_contract (errbuf   out varchar2,
                                  retcode  out varchar2) is
                                                                   
    -- Get service request population to update Contracts
    cursor get_sr_pop_c (p_time_stamp in date) is
      select -- for the contract api
             cia.incident_id            incident_id, 
             cia.incident_number        incident_number, 
             cia.customer_id            customer_id, 
             cia.install_site_id        install_site_id,
             cia.account_id             account_id, 
             cia.system_id              system_id, 
             cia.inventory_item_id      inventory_item_id,
             cia.customer_product_id    customer_product_id, 
             cia.incident_date          incident_date, 
             cia.incident_type_id       incident_type_id,
             cia.incident_severity_id   incident_severity_id, 
             cia.org_id                 org_id, 
             cia.object_version_number  object_version_number, 
             cia.incident_occurred_date incident_occurred_date,
             -- for the time zone api
             cia.time_zone_id           time_zone_id, 
             cia.incident_location_id   incident_location_id,
             cia.incident_location_type incident_location_type, 
             sr_cont.party_id           contact_party_id
      from   cs_incidents_all_b       cia,
             cs_hz_sr_contact_points  sr_cont
      where  sr_cont.incident_id(+)   = cia.incident_id
      and    sr_cont.primary_flag     = 'Y' 
      and    cia.contract_id          is null
      and    cia.creation_date        between to_date(fnd_profile.value('XXCS_SR_UPD_CONTRACT') , 'dd/mm/yyyy hh24:mi:ss')
                                      and     p_time_stamp;
      --and    cia.incident_id          in ( 19564,19291);
      
    -- Get business_process_id
    cursor bus_proc_id_c (p_inc_type_id number) is
      select business_process_id 
      from   cs_incident_types
      where  incident_type_id = p_inc_type_id;

    x_timezone_id         number;
    x_timezone_name       varchar2(250) ;
    l_ent_contracts       CS_CONT_GET_DETAILS_PVT.ent_contract_tab;
    l_return_status       VARCHAR2(1);
    l_msg_count           NUMBER;
    l_msg_data            VARCHAR2(2500);
    l_msg_index_OUT       NUMBER;
    l_rec_count           BINARY_INTEGER;
    l_user_id             number;
    l_business_process_id number;
    l_err_msg             varchar2(2500);
    l_error_code          number;
    l_error_desc          varchar2(500);
    l_time_stamp          date;
    l_error_flag          varchar2(1) := 'N';
    
    l_service_request_rec CS_ServiceRequest_PUB.service_request_rec_type;
    t_notes_table         CS_ServiceRequest_PUB.notes_table;            
    t_contacts_table      CS_ServiceRequest_PUB.contacts_table;         
    o_sr_update_out_rec   CS_ServiceRequest_PUB.sr_update_out_rec_type;   
                             
  begin 
    
/*   
    -- Set apps initialize
    -- to be able to run from Pl/Sql 
    fnd_global.apps_initialize( 1111,   -- user: SCHEDULER
                                51137,  -- CRM Service Super User Objet
                                514);  
*/                                

    -- this variable determine the population to run on.
    -- if Sr where created after this time -> the program will 
    -- take it next run.
    l_time_stamp := sysdate;
    
    
    for get_sr_pop_r in get_sr_pop_c (l_time_stamp) loop
      dbms_output.put_line('--------------------'); 
      dbms_output.put_line('Service request - '||get_sr_pop_r.incident_number); 
      fnd_file.put_line(fnd_file.log, '--------------------');
      fnd_file.put_line(fnd_file.log, 'Service request - '||get_sr_pop_r.incident_number);
    
      x_timezone_id := null;
      -- Get CS TimeZone 
      CS_TZ_GET_DETAILS_PVT.CUSTOMER_PREFERRED_TIME_ZONE
          ( p_incident_id            => null,
            p_task_id                => null,
            p_resource_id            => null,
            p_cont_pref_time_zone_id => null,                                                 --name_in('incident_tracking.time_zone_id')
            p_incident_location_id   => get_sr_pop_r.incident_location_id,  --17085,          --name_in('incident_tracking.incident_location_id')
            p_incident_location_type => get_sr_pop_r.incident_location_type,--'HZ_PARTY_SITE',--name_in('incident_tracking.incident_location_type')
            p_contact_party_id       => get_sr_pop_r.contact_party_id,      --27712,          --name_in('incident_tracking.contact_party_id')
            p_customer_id            => get_sr_pop_r.customer_id,           --25090,          --name_in('incident_tracking.customer_id')
            x_timezone_id            => x_timezone_id,
            x_timezone_name          => x_timezone_name
          ) ;
      
      dbms_output.put_line('x_timezone_id   - '||x_timezone_id); 
      dbms_output.put_line('x_timezone_name - '||x_timezone_name); 
      fnd_file.put_line(fnd_file.log, 'x_timezone_name - '||x_timezone_name); 
      -- Get business_process_id for API
      open  bus_proc_id_c(get_sr_pop_r.incident_type_id);
      fetch bus_proc_id_c into l_business_process_id;
      close bus_proc_id_c;
       
      l_return_status := null;
      l_msg_count     := null;
      l_msg_data      := null;
      l_msg_index_OUT := null;
      l_rec_count     := 1;
      -- init API message 
      fnd_msg_pub.initialize;
         
      -- get contract Details
      CS_CONT_GET_DETAILS_PVT.GET_CONTRACT_LINES
          ( p_api_version           => 1.0,
            p_init_msg_list         => 'T',
            p_contract_number       => null,                         
            p_service_line_id       => null,                               --
            p_customer_id           => get_sr_pop_r.customer_id,           -- 25090
            p_site_id               => get_sr_pop_r.install_site_id,       -- 17085
            p_customer_account_id   => get_sr_pop_r.account_id,            -- 6105
            p_system_id             => get_sr_pop_r.system_id,             -- 12607
            p_inventory_item_id     => get_sr_pop_r.inventory_item_id,     -- 19045
            p_customer_product_id   => get_sr_pop_r.customer_product_id,   -- 11758
            p_request_date          => get_sr_pop_r.incident_date,         -- to_date('07-APR-2010 10:47:57','DD-MON-YYYY HH24:MI:SS')
            p_business_process_id   => l_business_process_id,              -- 1001
            p_severity_id           => get_sr_pop_r.incident_severity_id,  -- 2
            p_time_zone_id          => x_timezone_id,                      -- 172 
            p_calc_resptime_flag    => 'Y',                              
            p_validate_flag         => 'Y',                              
            p_dates_in_input_tz     => 'N',
            p_incident_date         => get_sr_pop_r.incident_occurred_date,-- to_date('07-APR-2010 10:47:57','DD-MON-YYYY HH24:MI:SS'),
            -- out params
            x_ent_contracts         => l_ent_contracts,
            x_return_status         => l_return_status,
            x_msg_count             => l_msg_count,
            x_msg_data              => l_msg_data
          );
      dbms_output.put_line('l_return_status - ' ||l_return_status); 
      fnd_file.put_line(fnd_file.log, 'l_return_status - '||l_return_status);     
      -- Handle error messages
      if ( l_return_status ) <> 'S' then
        l_error_flag := 'Y';
        if ( FND_MSG_PUB.Count_Msg > 0 ) then
          for i in 1..FND_MSG_PUB.Count_Msg loop
            FND_MSG_PUB.Get(p_msg_index     => i,
                            p_encoded       => 'F',
                            p_data          => l_msg_data,
                            p_msg_index_OUT => l_msg_index_OUT );
            dbms_output.put_line('Error : ' || substr(l_msg_data,1,200));  
            fnd_file.put_line(fnd_file.log, 'Erorr - '||substr(l_msg_data,1,200));    
          end loop;
          rollback;
        end if;
      else -- API finished with success 
        -- check if the API return value find contract then go and update SR
        l_rec_count := l_ent_contracts.FIRST;
        -- case did not find any valid contract
        if l_rec_count is null then
          dbms_output.put_line('l_rec_count - ' ||l_rec_count);
          dbms_output.put_line('No valid contracts found.');   
          fnd_file.put_line(fnd_file.log, 'No valid contracts found.');
        -- find valid contract - upd SR
        else
          dbms_output.put_line('contract_id     - '||l_ent_contracts(l_rec_count).contract_id);
          dbms_output.put_line('contract_number - '||l_ent_contracts(l_rec_count).contract_number);
          dbms_output.put_line('service_name    - '||l_ent_contracts(l_rec_count).service_name); 
          fnd_file.put_line(fnd_file.log, 'contract_id     - '||l_ent_contracts(l_rec_count).contract_id);
          fnd_file.put_line(fnd_file.log, 'contract_number - '||l_ent_contracts(l_rec_count).contract_number);
          fnd_file.put_line(fnd_file.log, 'service_name    - '||l_ent_contracts(l_rec_count).service_name);
          -- Init in record param 
          CS_ServiceRequest_PUB.initialize_rec(l_service_request_rec);
           
          l_service_request_rec.contract_service_id := l_ent_contracts(1).service_line_id;
          l_service_request_rec.contract_id         := l_ent_contracts(1).contract_id;
          l_service_request_rec.coverage_type       := l_ent_contracts(1).coverage_type_code;
          l_service_request_rec.cust_po_number      := l_ent_contracts(1).service_po_number;
          l_service_request_rec.obligation_date     := l_ent_contracts(1).exp_reaction_time; --Open Date;
          
          l_return_status := null;
          l_msg_count     := null;
          l_msg_data      := null;
          l_msg_index_OUT := null;
          -- init API messages
          fnd_msg_pub.initialize; 
          -- call Upd Sr API 
          CS_ServiceRequest_PUB.Update_ServiceRequest
                   (p_api_version            => 4.0,
                    p_init_msg_list          => FND_API.G_TRUE,
                    p_commit                 => FND_API.G_FALSE,
                    x_return_status          => l_return_status, -- out
                    x_msg_count              => l_msg_count,     -- out
                    x_msg_data               => l_msg_data,      -- out
                    p_request_id             => get_sr_pop_r.incident_id,
                    p_object_version_number  => get_sr_pop_r.object_version_number,
                    p_resp_appl_id           => fnd_profile.VALUE('RESP_APPL_ID'),
                    p_resp_id                => fnd_profile.VALUE('RESP_ID'),
                    p_last_updated_by        => l_user_id,
                    p_last_update_date       => sysdate,
                    p_service_request_rec    => l_service_request_rec, -----------
                    p_notes                  => t_notes_table,
                    p_contacts               => t_contacts_table,
                    x_sr_update_out_rec      => o_sr_update_out_rec);
         -- get API error messages
         IF l_return_status != fnd_api.g_ret_sts_success THEN
           l_error_flag := 'Y';
           IF (fnd_msg_pub.count_msg > 0) THEN
              -- 1.1 Dalit A. Raviv 10/06/2010
              -- cut the message to be able to fit l_err_msg
              -- if not the program jump to the exception.
              FOR i IN 1 .. 2/*fnd_msg_pub.count_msg*/ LOOP
                 fnd_msg_pub.get(p_msg_index     => i,
                                 p_encoded       => 'F',
                                 p_data          => l_msg_data,
                                 p_msg_index_out => l_msg_index_out);
                 l_err_msg := substr(l_err_msg,1,500) || l_msg_data || chr(10);
              END LOOP;
              dbms_output.put_line('CS_ServiceRequest_PUB.Update_ServiceRequest error -'||substr(l_err_msg,1,200));
              fnd_file.put_line(fnd_file.log, 'CS_ServiceRequest_PUB.Update_ServiceRequest error - '||substr(l_err_msg,1,200));
           /*ELSE
              l_err_msg := l_msg_data;
              dbms_output.put_line('CS_ServiceRequest_PUB.Update_ServiceRequest error -'||substr(l_err_msg,1,200));
              fnd_file.put_line(fnd_file.log, 'CS_ServiceRequest_PUB.Update_ServiceRequest error - '||substr(l_err_msg,1,200)); 
           */
           END IF;
           rollback;
         -- else API success
         else  
           commit;
           dbms_output.put_line('CS_ServiceRequest_PUB.Update_ServiceRequest success'); 
           fnd_file.put_line(fnd_file.log, 'CS_ServiceRequest_PUB.Update_ServiceRequest success');
         END IF;                                                                                  
          
       end if; -- l_rec_count
      end if;-- l_return_status
    end loop;
    dbms_output.put_line('--------------------'); 
    
    -- after all SR where updated the program update the profile with the time stamp 
    l_error_code := 0;
    l_error_desc := null;
    upd_profile (p_timestamp  => l_time_stamp, -- i d
                 p_error_code => l_error_code, -- o n
                 p_error_desc => l_error_desc);-- o v 
                 
    -- Handle return values             
    if l_error_code = 0 and l_error_flag = 'N' then            
      errbuf   := 'SUCCESS';
      retcode  := 0;
    elsif l_error_code <> 0 and l_error_flag = 'N' then    
      errbuf   := 'Failed to Update Profile';
      retcode  := 2;
    else
      errbuf   := 'API Error';
      retcode  := 2;
    end if;

  exception
    when others then
      errbuf  := 'XXCS_SR_UPD_CONTRACTS.Upd_sr_with_contract GEN ERROR - '||substr(sqlerrm,1,200);
      retcode := 1;
  end Upd_sr_with_contract; 
    
  --------------------------------------------------------------------
  --  customization code: CUST311 - Activate Get Contract and update SR
  --  name:               upd_profile
  --                      
  --  create by:          Dalit A. Raviv
  --  Revision:           1.0 
  --  creation date:      02/05/2010 9:07:38 AM
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   02/05/2010    Dalit A. Raviv  initial build
  --------------------------------------------------------------------  
  Procedure upd_profile (p_timestamp    in  date,
                         p_error_code   out number,
                         p_error_desc   out varchar2) is 
                         
  begin
    -- update profile XXCS_SR_UPD_CONTRACT wwith the last start run time.
    -- each run the program will take all SR that have no Contract and created
    -- between profile value and sysdate (p_timestamp) the time the program start to run.
    update Fnd_Profile_Option_values
    set    profile_option_value = to_char(p_timestamp,'dd/mm/yyyy hh24:mi:ss')
    where  profile_option_id    = (select po.profile_option_id
                                   from   fnd_profile_options    po
                                   where  po.profile_option_name = 'XXCS_SR_UPD_CONTRACT');
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
    
                                   
end XXCS_SR_UPD_CONTRACTS;
/

