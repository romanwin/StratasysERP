create or replace package body XXCS_SR_LINK_PKG is

--------------------------------------------------------------------
--	customization code: CUST310 - Activate Create Link and update SR
--	name:               XXCS_SR_LINK_PKG
--                            
--	create by:          Dalit A. Raviv
--	$Revision:          1.0 
--	creation date:	    03/05/2010 2:10:59 PM
--  Purpose:            Activate Create Link and update SR
--------------------------------------------------------------------
--  ver   date          name            desc
--   1.0    03/05/2010    Dalit A. Raviv  initial build     
-------------------------------------------------------------------- 
  
  --------------------------------------------------------------------
  --  customization code: CUST310
  --  name:               get_link_exists
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0 
  --  creation date:      03/05/2010 
  --  Description:        Function that check id link exist between 
  --                      2 specific SR's.  
  -------------------------------------------------------------------- 
  --  ver   date          name            desc
  --  1.0   02/05/2010    Dalit A. Raviv  initial build
  --------------------------------------------------------------------                                 
  function get_link_exists  (p_o_incident_id in number,
                             p_s_incident_id in number) return varchar2 is
   
    l_count_links number := 0;                     
  begin
        
    select  count(1)
    into    l_count_links
    from    cs_incident_links    lnk
    where   lnk.object_id        = p_o_incident_id -- 18980 -- p_sr_object_id
    and     lnk.subject_id       = p_s_incident_id -- 19336 -- p_sr_subject_id
    and     lnk.object_type      = 'SR'
    and     lnk.subject_type     = 'SR';
  
    -- if there are one or more links exists -> return YES
    -- else return NO (no link exist -> customer can create new link)
    if l_count_links > 0 then
      return 'YES';
    else
      return 'NO';
    end if;
  exception
    when others then
      return 'NO'; 
    
  end get_link_exists;
  
  --------------------------------------------------------------------
  --  customization code: CUST310
  --  name:               get_incident_number
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0 
  --  creation date:      04/05/2010 
  --  Description:        Function that get incident id and return the number
  --                      use for the messages in the program           
  -------------------------------------------------------------------- 
  --  ver   date          name            desc
  --  1.0   04/05/2010    Dalit A. Raviv  initial build
  --------------------------------------------------------------------   
  function get_incident_number (p_incident_id in number) return varchar2 is
  
    l_inc_number varchar2(70);
  
  begin
    select cii.incident_number
    into   l_inc_number
    from   cs_incidents_all_b cii
    where  cii.incident_id    = p_incident_id;
    
    return l_inc_number;
    
  exception
    when others then
      return null;
  end get_incident_number;
  
  --------------------------------------------------------------------
  --  customization code: CUST310
  --  name:               get_link_type_name
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0 
  --  creation date:      04/05/2010 
  --  Description:        Function return the link type name for the API           
  -------------------------------------------------------------------- 
  --  ver   date          name            desc
  --  1.0   04/05/2010    Dalit A. Raviv  initial build
  --------------------------------------------------------------------     
  function get_link_type_name  (p_link_type_id in number) return varchar2 is
    
    l_link_type_name varchar2(240) := null;
  
  begin
    select l_type.name
    into   l_link_type_name
    from   cs_sr_link_types_tl l_type
    where  l_type.language     = 'US'
    and    l_type.link_type_id = p_link_type_id; -- 5
    
    return l_link_type_name;
    
  exception
    when others then
      return null;
  end get_link_type_name;
  
  --------------------------------------------------------------------
  --  customization code: CUST310
  --  name:               upd_profile
  --                      
  --  create by:          Dalit A. Raviv
  --  Revision:           1.0 
  --  creation date:      04/05/2010 9:07:38 AM
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   04/05/2010    Dalit A. Raviv  initial build
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
                                   where  po.profile_option_name = 'XXCS_SR_CREATE_LINK');
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
  --  customization code: CUST310
  --  name:               create_incident_link
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0 
  --  creation date:      03/05/2010
  --  Description:        procedure that go throught SR population and
  --                      create SR link's. 
  -------------------------------------------------------------------- 
  --  ver   date          name            desc
  --  1.0   03/05/2010    Dalit A. Raviv  initial build
  -------------------------------------------------------------------- 
  procedure create_incident_link(errbuf   out varchar2,
                                 retcode  out varchar2) is
    -- get SR population to create link                             
    cursor get_Sr_pop_c (p_time_stamp in date) is
      select cii.*
      from   cs_incidents_all_b        cii
      where  cii.external_attribute_11 is not null
      and    cii.creation_date         between to_date(fnd_profile.value('XXCS_SR_CREATE_LINK') , 'dd/mm/yyyy hh24:mi:ss')
                                       and     p_time_stamp
      and    exists (select to_char(cii1.incident_id)
                     from   cs_incidents_all_b cii1
                     where  to_char(cii1.incident_id)   = cii.external_attribute_11);
      --and    cii.external_attribute_11 in ('19311', '18773');
      -- ('18773','19311','18937','18937','19103','19800')                        
  
    l_time_stamp         date;
    l_link_exists        varchar2(5)    := 'N';
    l_sr_subject_number  varchar2(70)   := null;
    l_msg_count          number         := 0;
    l_msg_data           varchar2(4000) := null;
    --l_msg_data           varchar2(4000) := null;
    l_return_status      varchar2(1)    := FND_API.G_RET_STS_SUCCESS;
    l_msg_index_OUT      number;
    l_link_id            number         := null;
    l_reciprocal_link_id number         := null;
    l_ovn                number         := null;
    l_link_type_name     varchar2(240)  := null;
    l_link_rec           CS_INCIDENTLINKS_PUB.cs_incident_link_rec_type;
    
    l_user_id            number         := FND_PROFILE.VALUE('USER_ID');
    l_login_id           number         := FND_PROFILE.VALUE('LOGIN_ID'); -- fnd_global.LOGIN_ID;--
    
    l_errbuf             varchar2(150)  := 'Success';
    l_retcode            varchar2(150)  := 0;
    l_error_code         number         := 0;
    l_error_desc         varchar2(1500) := null;
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
    l_time_stamp     := sysdate;
    l_link_type_name := get_link_type_name  (5);
    for get_Sr_pop_r in get_Sr_pop_c (l_time_stamp) loop
      l_sr_subject_number := get_incident_number (to_number(get_Sr_pop_r.External_Attribute_11));
      dbms_output.put_line('--------------------'); 
      dbms_output.put_line('Service request o - '||get_Sr_pop_r.incident_number); 
      dbms_output.put_line('Service request s - '||l_sr_subject_number); 
      fnd_file.put_line(fnd_file.log, '--------------------');
      fnd_file.put_line(fnd_file.log, 'Service request o - '||get_Sr_pop_r.incident_number);
      fnd_file.put_line(fnd_file.log, 'Service request s - '||l_sr_subject_number);
      
      l_link_exists := get_link_exists  (get_Sr_pop_r.Incident_Id,                       -- in n p_o_incident_id
                                         to_number(get_Sr_pop_r.External_Attribute_11)); -- in n p_s_incident_id
      if l_link_exists = 'YES' then
        --get_incident_number (p_incident_id in number)
        dbms_output.put_line('Exist link between  - '||get_Sr_pop_r.incident_number||
                             ' And - '||l_sr_subject_number ); 
        fnd_file.put_line(fnd_file.log, 'Exist link between  - '||get_Sr_pop_r.incident_number||
                             ' And - '||l_sr_subject_number );
      else
        -------------------------------------------
        --    call API create incidentlink       --
        -------------------------------------------
        l_link_rec.SUBJECT_ID     := get_Sr_pop_r.incident_id;     -- i n NEW ESR that just created 
        l_link_rec.SUBJECT_TYPE   := 'SR';                         -- i v
        l_link_rec.OBJECT_ID      := to_number(get_Sr_pop_r.External_Attribute_11); -- i n OLD ESR that i created the new ESR from.
        l_link_rec.OBJECT_NUMBER  := l_sr_subject_number;          -- i v
        l_link_rec.OBJECT_TYPE    := 'SR';                         -- i v
        l_link_rec.LINK_TYPE_ID   := 5;                            -- i n   5
        l_link_rec.LINK_TYPE      := l_link_type_name;             -- i v   REF (Reference for)
        l_link_rec.PROGRAM_UPDATE_DATE := sysdate;
        
        l_return_status := null;
        l_msg_count     := null;
        l_msg_data      := null;
        l_msg_index_OUT := null;
        l_link_id            := null;
        l_reciprocal_link_id := null;
        l_ovn                := null;
        -- init API messages
        fnd_msg_pub.initialize; 
        
        CS_INCIDENTLINKS_PUB.CREATE_INCIDENTLINK (
                          P_API_VERSION            => 2.0,                          -- i n
                          P_INIT_MSG_LIST          => FND_API.G_TRUE,               -- i v
                          P_COMMIT                 => FND_API.G_FALSE,              -- i v
                          P_USER_ID                => l_user_id,                    -- i n
                          P_LOGIN_ID               => l_login_id,                   -- i n
                          P_ORG_ID                 => get_Sr_pop_r.Org_Id,          -- i n
                          P_LINK_REC               => l_link_rec,                   -- i rec        
                          -- out
                          X_RETURN_STATUS	         => l_return_status,              -- o v
                          X_MSG_COUNT		           => l_msg_count,                  -- o n
                          X_MSG_DATA		           => l_msg_data,                   -- o v
                          X_OBJECT_VERSION_NUMBER  => l_ovn,                        -- o n
                          X_RECIPROCAL_LINK_ID     => l_reciprocal_link_id,         -- o n
                          X_LINK_ID			           => l_link_id);                   -- o n   
        -- Handle Api errors
        if ( l_return_status ) <> 'S' then
          if ( FND_MSG_PUB.Count_Msg > 0 ) then
            for i in 1..FND_MSG_PUB.Count_Msg loop
              FND_MSG_PUB.Get(p_msg_index     => i,
                              p_encoded       => 'F',
                              p_data          => l_msg_data,
                              p_msg_index_OUT => l_msg_index_OUT );
              dbms_output.put_line('Error : ' || substr(l_msg_data,1,240));  
              fnd_file.put_line(fnd_file.log, 'Erorr - '||substr(l_msg_data,1,240));    
            end loop;
            rollback;
            l_errbuf  := 'Error';
            l_retcode := 1;
          end if; -- message count
        else
          commit;
          --get_incident_number (p_incident_id in number)
          dbms_output.put_line('Success create link between - '||get_Sr_pop_r.incident_number||
                               ' And - '||l_sr_subject_number ); 
          fnd_file.put_line(fnd_file.log, 'Success create link between  - '||get_Sr_pop_r.incident_number||
                               ' And - '||l_sr_subject_number );
          if l_retcode <> 0 then
            null;
          else
            l_errbuf  := 'Success';
            l_retcode := 0;
          end if; -- l_retcode
        end if; -- return status
      end if; -- l_link_exists
    end loop; 
    
    dbms_output.put_line('--------------------'); 
    
    -- after all SR where updated the program update the profile with the time stamp 
    l_error_code := 0;
    l_error_desc := null;
    upd_profile (p_timestamp  => l_time_stamp, -- i d
                 p_error_code => l_error_code, -- o n
                 p_error_desc => l_error_desc);-- o v 
                 
    -- Handle return values             
    if l_retcode <> 0 then
      errbuf  := 'API Error';
      retcode := 2;
    elsif l_retcode = 0 and l_error_code <> 0 then 
      errbuf   := 'Failed to Update Profile';
      retcode  := 2;
    else
      errbuf  := 'Success';
      retcode := 0;
    end if;

  exception
    when others then
      errbuf  := 'XXCS_SR_LINK_PKG.create_incident_link general exception';
      retcode := 1;
      dbms_output.put_line('General exception - '||substr(sqlerrm,1,240)); 
      fnd_file.put_line(fnd_file.log, 'General exception - '||substr(sqlerrm,1,240));
  end create_incident_link;                                 
                                
end XXCS_SR_LINK_PKG;
/

