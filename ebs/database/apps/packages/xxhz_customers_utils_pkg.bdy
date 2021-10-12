CREATE OR REPLACE PACKAGE BODY xxhz_customers_utils_pkg IS

  -----------------------------------------------------------------------
  --  customization code: GENERAL
  --  name:               XXHZ_CUSTOMERS_UTILS_PKG
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0 
  --  creation date:      12/10/2010 
  --  Purpose :           Customers generic package
  -----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   12/10/2010    Dalit A. Raviv  Initial version
  --  1.2   16/04/2012    Dalit A. Raviv  add procedure close person + relationship
  --                                      inactive_contact_person, inactive_person_relationship
  --  1.3   09/08/2012   Ofer Suad        change update sales person by cuntry state postal code etc. 
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
  PROCEDURE create_cust_account_role(errbuf  OUT VARCHAR2,
                                     retcode OUT VARCHAR2) IS
  
    l_success              VARCHAR2(1) := 'T';
    x_cust_account_role_id NUMBER(10);
    l_return_status        VARCHAR2(2000);
    l_msg_count            NUMBER;
    l_msg_data             VARCHAR2(2000);
    l_msg_index_out        NUMBER;
    l_data                 VARCHAR2(2000);
    l_cr_cust_acc_role_rec hz_cust_account_role_v2pub.cust_account_role_rec_type;
  
    CURSOR get_population_c IS
      SELECT hr.party_id contact_party_id, --contact_party_id
             hca.cust_account_id
        FROM ar.hz_relationships hr, hz_cust_accounts hca
       WHERE hr.object_type = 'PERSON'
         AND hca.party_id = hr.subject_id
         AND hr.created_by_module IN ('CSCCCCRC', 'SR')
         AND hr.status = 'A'
         AND hca.status = 'A'
         AND nvl(hr.end_date, SYSDATE + 1) > SYSDATE
         AND NOT EXISTS (SELECT 1
                FROM hz_cust_account_roles hcar
               WHERE hcar.party_id = hr.party_id);
    --and hr.party_id = 1512042;
  
  BEGIN
    -- to check if i need to add apps_initialize??????????????????  
    errbuf  := 0;
    retcode := NULL;
  
    FOR get_population_r IN get_population_c LOOP
      fnd_file.put_line(fnd_file.log, '----------');
      fnd_file.put_line(fnd_file.log,
                        'contact party id - ' ||
                        get_population_r.contact_party_id);
      fnd_file.put_line(fnd_file.log,
                        'Cust account  id - ' ||
                        get_population_r.cust_account_id);
      l_cr_cust_acc_role_rec.party_id          := get_population_r.contact_party_id; --p_contact_party;
      l_cr_cust_acc_role_rec.cust_account_id   := get_population_r.cust_account_id; --p_cust_account_id;
      l_cr_cust_acc_role_rec.primary_flag      := 'N';
      l_cr_cust_acc_role_rec.role_type         := 'CONTACT';
      l_cr_cust_acc_role_rec.created_by_module := 'TCA_V1_API';
    
      fnd_msg_pub.initialize;
      hz_cust_account_role_v2pub.create_cust_account_role(l_success,
                                                          l_cr_cust_acc_role_rec,
                                                          x_cust_account_role_id,
                                                          l_return_status,
                                                          l_msg_count,
                                                          l_msg_data);
    
      IF l_return_status <> fnd_api.g_ret_sts_success THEN
        errbuf := 'Error create cust account role: ';
      
        fnd_file.put_line(fnd_file.log,
                          'Creation cust account role Failed -');
        fnd_file.put_line(fnd_file.log,
                          'l_msg_data = ' || substr(l_msg_data, 1, 2000));
        FOR i IN 1 .. l_msg_count LOOP
          fnd_msg_pub.get(p_msg_index     => i,
                          p_data          => l_data,
                          p_encoded       => fnd_api.g_false,
                          p_msg_index_out => l_msg_index_out);
          fnd_file.put_line(fnd_file.log, 'l_Data - ' || l_data);
          errbuf := substr(errbuf || l_data || chr(10), 1, 500);
        END LOOP;
        retcode := 1;
        ROLLBACK;
      
      ELSE
        COMMIT;
        --p_cust_account_role_id := x_cust_account_role_id;
        fnd_file.put_line(fnd_file.log,
                          'Cust account role id - ' ||
                          x_cust_account_role_id);
      END IF; -- Status if     
    END LOOP;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      retcode := 1;
      errbuf  := 'Gen EXC - create_cust_account_role_api - ' ||
                 substr(SQLERRM, 1, 240);
      fnd_file.put_line(fnd_file.log,
                        'Gen EXC - create_cust_account_role_api - ' ||
                        substr(SQLERRM, 1, 240));
    
  END create_cust_account_role;

  --------------------------------------------------------------------
  --  name:            create_cust_account
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   13/10/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Procedure that create cust account for partyies with no account           
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  13/10/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE create_cust_account(errbuf OUT VARCHAR2, retcode OUT VARCHAR2) IS
  
    CURSOR get_population_c IS
      SELECT hp.party_id, hp.party_name
        FROM hz_parties hp, fnd_lookup_values fl
       WHERE hp.status = 'A'
         AND hp.party_id <> 10041
         AND hp.party_type = 'ORGANIZATION'
         AND hp.created_by_module = fl.lookup_code
         AND fl.lookup_type = 'HZ_CREATED_BY_MODULES'
         AND fl.meaning = 'Customer Care Contact Center'
         AND fl.LANGUAGE = 'US'
            --and      hp.party_id = 299041 
         AND NOT EXISTS (SELECT 1
                FROM hz_cust_accounts hca
               WHERE hp.party_id = hca.party_id);
  
    l_party_number    VARCHAR2(30);
    l_account_number  NUMBER;
    l_cust_account_id NUMBER;
    l_party_id        NUMBER;
    l_profile_id      NUMBER;
    l_return_status   VARCHAR2(1);
    l_msg_count       NUMBER;
    l_msg_data        VARCHAR2(2000);
    l_data            VARCHAR2(2000);
    l_msg_index_out   NUMBER;
  
    t_cust_account_rec     hz_cust_account_v2pub.cust_account_rec_type;
    t_organization_rec     hz_party_v2pub.organization_rec_type;
    t_customer_profile_rec hz_customer_profile_v2pub.customer_profile_rec_type;
  
    invalid_customer EXCEPTION;
  
  BEGIN
    errbuf  := 'Create cust account Success';
    retcode := 0;
    FOR get_population_r IN get_population_c LOOP
      fnd_msg_pub.initialize;
      l_party_id        := NULL;
      l_cust_account_id := NULL;
    
      -- get account Syquence
      SELECT hz_cust_accounts_s.NEXTVAL INTO l_account_number FROM dual;
    
      t_cust_account_rec.account_name         := get_population_r.party_name /*p_account_name*/
       ;
      t_cust_account_rec.date_type_preference := 'ARRIVAL';
      t_cust_account_rec.account_number       := l_account_number;
      t_cust_account_rec.created_by_module    := 'TCA_V1_API';
    
      t_organization_rec.organization_name          := get_population_r.party_name;
      t_organization_rec.created_by_module          := 'TCA_V1_API';
      t_organization_rec.organization_name_phonetic := get_population_r.party_name;
      t_organization_rec.organization_type          := 'ORGANIZATION';
      t_organization_rec.party_rec.party_id         := get_population_r.party_id;
    
      hz_cust_account_v2pub.create_cust_account(p_init_msg_list        => 'T',
                                                p_cust_account_rec     => t_cust_account_rec,
                                                p_organization_rec     => t_organization_rec,
                                                p_customer_profile_rec => t_customer_profile_rec,
                                                p_create_profile_amt   => 'F',
                                                x_cust_account_id      => l_cust_account_id, -- o nocopy n
                                                x_account_number       => l_account_number, -- o nocopy v
                                                x_party_id             => l_party_id, -- o nocopy n
                                                x_party_number         => l_party_number, -- o nocopy v
                                                x_profile_id           => l_profile_id, -- o nocopy n
                                                x_return_status        => l_return_status, -- o nocopy v
                                                x_msg_count            => l_msg_count, -- o nocopy n
                                                x_msg_data             => l_msg_data); -- o nocopy v
      -- if api failed - 1) write to log errors
      --                 2) update interface line table with errors.
      --                 3) rollback
      IF l_return_status <> fnd_api.g_ret_sts_success THEN
        dbms_output.put_line('Failed Creat Customer' ||
                             get_population_r.party_name);
        dbms_output.put_line('x_msg_data = ' || l_msg_data);
        FOR i IN 1 .. l_msg_count LOOP
          fnd_msg_pub.get(p_msg_index     => i,
                          p_data          => l_data,
                          p_encoded       => fnd_api.g_false,
                          p_msg_index_out => l_msg_index_out);
        
          dbms_output.put_line(substr(l_data || chr(10), 1, 240));
        END LOOP;
      
        ROLLBACK;
        retcode := 1;
        errbuf  := substr(l_data, 1, 500);
      ELSE
        COMMIT;
        dbms_output.put_line('Success Create Customer ' ||
                             get_population_r.party_name || ' Party id - ' ||
                             l_party_id || ' Cust account id - ' ||
                             l_cust_account_id);
      
      END IF; -- return status
    END LOOP;
    errbuf  := 'Gen EXC - create_cust_account - ' ||
               substr(SQLERRM, 1, 240);
    retcode := 0;
  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'Gen EXC - create_cust_account - ' ||
                 substr(SQLERRM, 1, 240);
      retcode := 1;
  END create_cust_account;

  --------------------------------------------------------------------
  --  name:            update_job_title_code
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   13/10/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Procedure that update job title and job title_code   
  --                   at update_org_contact     
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  13/10/2010  Dalit A. Raviv    initial build
  -------------------------------------------------------------------- 
  PROCEDURE upd_org_contact_job_title(errbuf   OUT VARCHAR2,
                                      retcode  OUT VARCHAR2,
                                      p_entity IN VARCHAR2) IS
  
    CURSOR get_population_c IS
    -- second run select for correct the job title field
      SELECT p_entity entity,
             hr.subject_id person_party_id, -- person party id
             hr.object_id hz_party_id, -- party_id (cust account)
             hp.object_version_number hp_ovn, -- hp_ovn
             'OPERATOR' job_title_code, -- l_sf_title
             'Operator' job_title,
             hoc.org_contact_id org_contact_id, -- org_contact_id
             hoc.object_version_number hoc_ovn, -- hoc_ovn
             hr.object_version_number rel_ovn -- rel_ovn
        FROM hz_party_sites   hps,
             hz_locations     hl,
             hz_relationships hr,
             hz_parties       hp,
             hz_org_contacts  hoc
       WHERE p_entity = 'DATAFIX'
            
         AND hps.party_id(+) = hp.party_id
         AND hps.location_id = hl.location_id(+)
         AND hr.subject_type = 'PERSON'
         AND hp.party_id = hr.party_id
         AND hoc.party_relationship_id = hr.relationship_id
         AND hoc.job_title_code = 'OPERATOR'
         AND hoc.job_title IS NULL
      UNION
      --first run select
      SELECT p_entity entity,
             hr.subject_id person_party_id, -- person party id
             hr.object_id hz_party_id, -- party_id (cust account)
             hp.object_version_number hp_ovn, -- hp_ovn
             'OPERATOR' job_title_code, -- l_sf_title
             'Operator' job_title,
             hoc.org_contact_id org_contact_id, -- org_contact_id
             hoc.object_version_number hoc_ovn, -- hoc_ovn
             hr.object_version_number rel_ovn -- rel_ovn
        FROM hz_party_sites   hps,
             hz_locations     hl,
             hz_relationships hr,
             hz_parties       hp,
             hz_org_contacts  hoc
       WHERE p_entity = 'DAILY'
         AND hps.party_id(+) = hp.party_id
         AND hps.location_id = hl.location_id(+)
         AND hr.subject_type = 'PERSON'
         AND hp.party_id = hr.party_id
         AND hoc.party_relationship_id = hr.relationship_id
         AND hoc.job_title_code IS NULL
            --and hp.party_id = 344050
         AND hp.party_id IN
             (SELECT DISTINCT rel.party_id
                FROM cs_sr_incidents_v_sec c,
                     hz_parties            cust,
                     hz_parties            cont,
                     hz_parties            rel,
                     hz_relationships      hr
               WHERE c.customer_id = cust.party_id
                 AND c.contact_party_id = hr.party_id
                 AND hr.object_type = 'ORGANIZATION'
                 AND hr.subject_id = cont.party_id
                 AND rel.party_id = c.contact_party_id
                 AND upper(cust.party_name) NOT LIKE upper('%Objet%'));
  
    l_success         VARCHAR2(1) := 'T';
    l_org_contact_rec hz_party_contact_v2pub.org_contact_rec_type;
    l_return_status   VARCHAR2(2000);
    l_msg_count       NUMBER;
    l_msg_data        VARCHAR2(2000);
    l_msg_index_out   NUMBER;
    l_data            VARCHAR2(2000);
    l_cont_ovn        NUMBER := NULL;
    l_rel_ovn         NUMBER := NULL;
    l_party_ovn       NUMBER := NULL;
  BEGIN
    errbuf  := 'SUCCESS - upd_org_contact_job_title - ';
    retcode := 0;
    fnd_file.put_line(fnd_file.log, 'p_entity = ' || p_entity);
    FOR get_population_r IN get_population_c LOOP
    
      l_return_status := NULL;
      l_msg_count     := NULL;
      l_msg_data      := NULL;
    
      fnd_msg_pub.initialize;
      --l_org_contact_rec.created_by_module := 'TCA_V1_API';
      IF p_entity = 'DAILY' THEN
        l_org_contact_rec.job_title_code := get_population_r.job_title_code; --  p_title;
      END IF;
      l_org_contact_rec.job_title      := get_population_r.job_title;
      l_org_contact_rec.org_contact_id := get_population_r.org_contact_id; --p_org_contact_id;
    
      l_cont_ovn  := get_population_r.hoc_ovn; --p_cont_ovn;
      l_rel_ovn   := get_population_r.rel_ovn; --p_rel_ovn;
      l_party_ovn := get_population_r.hp_ovn; --p_party_ovn;
      hz_party_contact_v2pub.update_org_contact(p_init_msg_list               => l_success, -- i v
                                                p_org_contact_rec             => l_org_contact_rec, -- i   ORG_CONTACT_REC_TYPE
                                                p_cont_object_version_number  => l_cont_ovn, -- i/o nocopy n
                                                p_rel_object_version_number   => l_rel_ovn, -- i/o nocopy n
                                                p_party_object_version_number => l_party_ovn, -- i/o nocopy n
                                                x_return_status               => l_return_status, -- o   nocopy v
                                                x_msg_count                   => l_msg_count, -- o   nocopy n
                                                x_msg_data                    => l_msg_data); -- o   nocopy v
    
      IF l_return_status <> fnd_api.g_ret_sts_success THEN
        dbms_output.put_line('Failed Update org contact: p_org_contact_id - ' ||
                             get_population_r.org_contact_id);
        dbms_output.put_line('l_msg_data = ' ||
                             substr(l_msg_data, 1, 2000));
        fnd_file.put_line(fnd_file.log,
                          'Failed Update org contact: p_org_contact_id - ' ||
                          get_population_r.org_contact_id);
        fnd_file.put_line(fnd_file.log,
                          'l_msg_data = ' || substr(l_msg_data, 1, 2000));
        FOR i IN 1 .. l_msg_count LOOP
          fnd_msg_pub.get(p_msg_index     => i,
                          p_data          => l_data,
                          p_encoded       => fnd_api.g_false,
                          p_msg_index_out => l_msg_index_out);
          dbms_output.put_line('l_data = ' || substr(l_data, 1, 2000));
          fnd_file.put_line(fnd_file.log,
                            'l_data = ' || substr(l_data, 1, 2000));
        END LOOP;
        ROLLBACK;
        errbuf  := 'failed - upd_org_contact_job_title ';
        retcode := 1;
      ELSE
        COMMIT;
        dbms_output.put_line('Success Update org contact:- p_org_contact_id - ' ||
                             get_population_r.org_contact_id);
        fnd_file.put_line(fnd_file.log,
                          'Success Update org contact:- p_org_contact_id - ' ||
                          get_population_r.org_contact_id);
      END IF; -- Status if  
    END LOOP;
  EXCEPTION
    WHEN OTHERS THEN
      dbms_output.put_line('Gen EXC - update_org_contact_api - ' ||
                           substr(SQLERRM, 1, 240));
      fnd_file.put_line(fnd_file.log,
                        'Gen EXC - update_org_contact_api - ' ||
                        substr(SQLERRM, 1, 240));
      errbuf  := 'Gen EXC - upd_org_contact_job_title - ' ||
                 substr(SQLERRM, 1, 240);
      retcode := 1;
  END upd_org_contact_job_title;

  ----------------------------------------------
  -- upd_site_salesrep
  -- Update sales person rep acording to agent/party
  ----------------------------------------------
  PROCEDURE upd_site_salesrep(errbuf         OUT VARCHAR2,
                              retcode        OUT VARCHAR2,
                              p_agent_id     NUMBER,
                              p_sales_person NUMBER,
                              p_party_id     NUMBER,
                              p_postal_code  VARCHAR2,
                              p_Country      VARCHAR2,
                              p_state        VARCHAR2,
                              
                              p_new_salesrep_id NUMBER) IS
  
    t_cust_site_use_rec     hz_cust_account_site_v2pub.cust_site_use_rec_type;
    l_return_status         VARCHAR2(2000);
    l_msg_count             NUMBER;
    l_msg_data              VARCHAR2(2000);
    l_data                  VARCHAR2(2000);
    l_msg_index_out         NUMBER;
    l_object_version_number NUMBER;
    l_count                 NUMBER := 0;
  
    CURSOR c IS
      SELECT hcsu.site_use_id,
             hps_dfv.dealer,
             hcsu.cust_acct_site_id,
             hcsu.object_version_number,
             hp.party_name,
             hps.party_site_name site_name
        FROM hz_parties             hp,
             hz_party_sites         hps,
             hz_party_sites_dfv     hps_dfv,
             hz_cust_accounts       hca,
             hz_cust_acct_sites_all hcas,
             hz_cust_site_uses_all  hcsu,
             hz_locations           hl
       WHERE hps_dfv.row_id(+) = hps.ROWID
         AND hps_dfv.context_value(+) = hps.attribute_category
         AND hp.party_id = hps.party_id
         AND hp.party_id = hca.party_id
         AND hca.cust_account_id = hcas.cust_account_id
         AND hcas.party_site_id = hps.party_site_id
         AND hcas.cust_acct_site_id = hcsu.cust_acct_site_id
         AND nvl(hps_dfv.dealer, '-1') =
             nvl(to_char(p_agent_id), nvl(hps_dfv.dealer, '-1'))
         AND hp.party_type = 'ORGANIZATION'
         AND hp.party_id = nvl(p_party_id, hp.party_id)
         and hl.location_id = hps.location_id
         and hl.postal_code = nvl(p_postal_code, hl.postal_code)
         and hl.Country = nvl(p_Country, hl.Country)
         and nvl(hl.state,'NULL') = nvl(p_state,nvl(hl.state,'NULL'))
         and hcsu.org_id=fnd_global.ORG_ID
         and hps.status='A'
         and hcas.status='A'
         and hcsu.status='A'
         and nvl(hcsu.primary_salesrep_id,'-1') =
             nvl(p_sales_person, nvl(hcsu.primary_salesrep_id,'-1'));
    /* SELECT hcsu.site_use_id,
          hcsu.cust_acct_site_id,
          hcsu.object_version_number,
          hp.party_name,
          hps.party_site_name site_name
     FROM hz_parties             hp,
          hz_party_sites         hps,
          hz_party_sites_dfv     hps_dfv,
          hz_cust_accounts       hca,
          hz_cust_acct_sites_all hcas,
          hz_cust_site_uses_all  hcsu
    
    WHERE hps_dfv.row_id = hps.ROWID
      AND hps_dfv.context_value = hps.attribute_category
      AND hp.party_id = hps.party_id
      AND hp.party_id = hca.party_id
      AND hca.cust_account_id = hcas.cust_account_id
      AND hcas.party_site_id = hps.party_site_id
      AND hcas.cust_acct_site_id = hcsu.cust_acct_site_id
      AND hps_dfv.dealer = to_char(p_agent_id)
      AND hp.party_type = 'ORGANIZATION'
      AND hp.party_id = nvl(p_party_id, hp.party_id);*/
  
  BEGIN
    if p_agent_id is null and p_sales_person is null and p_party_id is null and
       p_state is null and p_postal_code is null then
    
      retcode := 1;
      fnd_file.put_line(fnd_file.log,
                        'Please provide at least one of the following :Agent Name,From Sales Person,Party Name,State,Postal Code.');
    else
      -- BEGIN
      -- fnd_global.APPS_INITIALIZE(1308,50580,222);
      /* fnd_global.apps_initialize(3850, 50580, 222);
      mo_global.set_org_context(p_org_id_char     => 89,
                                p_sp_id_char      => NULL,
                                p_appl_short_name => 'AR');*/
    
      --END;
      retcode := 0;
    
      FOR i IN c LOOP
      
        l_object_version_number := i.object_version_number;
      
        ---------------------------------
        -- Update an account site use  --
        ---------------------------------
        t_cust_site_use_rec := NULL;
      
        t_cust_site_use_rec.site_use_id := i.site_use_id; --39940;
      
        t_cust_site_use_rec.primary_salesrep_id := p_new_salesrep_id; -- SUSAN ;
      
        l_return_status := NULL;
        l_msg_count     := NULL;
        l_msg_data      := NULL;
      
        hz_cust_account_site_v2pub.update_cust_site_use(p_init_msg_list         => 'T',
                                                        p_cust_site_use_rec     => t_cust_site_use_rec,
                                                        p_object_version_number => l_object_version_number,
                                                        x_return_status         => l_return_status,
                                                        x_msg_count             => l_msg_count,
                                                        x_msg_data              => l_msg_data);
      
        --ERROR HANDLING 
        IF l_return_status <> fnd_api.g_ret_sts_success THEN
          ROLLBACK;
          errbuf  := 'Error ,See log';
          retcode := 1;
          fnd_file.put_line(fnd_file.log,
                            'Error updating Party= ' || i.party_name ||
                            ' Site = ' || i.site_name);
        
          FOR j IN 1 .. l_msg_count LOOP
            fnd_msg_pub.get(p_msg_index     => j,
                            p_data          => l_data,
                            p_encoded       => fnd_api.g_false,
                            p_msg_index_out => l_msg_index_out);
            dbms_output.put_line(' l_msg_count = ' || to_char(l_msg_count) ||
                                 ' l_msg_data = ' || l_msg_data);
          
            fnd_file.put_line(fnd_file.log,
                              ' l_msg_count = ' || to_char(l_msg_count) ||
                              ' l_msg_data = ' || l_msg_data);
          END LOOP;
        ELSE
          l_count := l_count + 1;
        END IF;
        COMMIT;
      END LOOP;
    
      fnd_file.put_line(fnd_file.log, l_count || ' Records were updated');
      errbuf := l_count || ' Records were updated';
    end if;
  EXCEPTION
    WHEN OTHERS THEN
      retcode := 1;
      fnd_file.put_line(fnd_file.log,
                        'Error in xxhz_customers_utils_pkg.upd_site_salesrep: ' ||
                        SQLERRM);
  END;

  --------------------------------------------------------------------
  --  name:            inactive_contact_person
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   16/04/2012 
  --------------------------------------------------------------------
  --  purpose :        Procedure that close prty from type person (Inactive) 
  --                   at hz_party               
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  16/04/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE inactive_contact_person(errbuf       out varchar2,
                                    retcode      out varchar2,
                                    p_party_name in  varchar2,
                                    p_status     in  varchar2) is
    -- 'Hans Schwerdt', 'Sean Kim', 'Matt Clevenger'
  
    l_upd_person    hz_party_v2pub.person_rec_type;
    l_success       VARCHAR2(1) := 'T';
    l_return_status VARCHAR2(2000);
    l_msg_count     NUMBER;
    l_msg_data      VARCHAR2(2000);
    l_data          VARCHAR2(2000);
    l_msg_index_out NUMBER;
    x_profile_id    NUMBER;
    l_ovn           NUMBER := NULL;
    l_user_id       number := null;
    l_count_s       number := 0;
    l_count_e       number := 0;
    -- population of the persons we want to inactive
    cursor get_pop_c is
      select * from hz_parties hp where hp.party_name = p_party_name; --in ('Hans Schwerdt', 'Sean Kim', 'Matt Clevenger');
    --and    party_id      = 6959049;
  begin
    select user_id
      into l_user_id
      from fnd_user
     where user_name = 'CONVERSION';
  
    fnd_global.apps_initialize(user_id      => l_user_id, -- SALESFORCE
                               resp_id      => 51137, -- CRM Service Super User Objet
                               resp_appl_id => 514); -- Support (obsolete)
    retcode := 0;
    errbuf  := NULL;
  
    fnd_msg_pub.initialize;
    for get_pop_r in get_pop_c loop
      --dbms_output.put_line('----------- ' || get_pop_r.party_id);
      -- Create contact as person. If OK Continue to RelationShip
      l_upd_person.person_first_name  := get_pop_r.person_first_name;
      l_upd_person.person_last_name   := get_pop_r.person_last_name;
      l_upd_person.party_rec.status   := p_status; -- 'I' / 'A'
      l_upd_person.party_rec.party_id := get_pop_r.party_id;
      l_ovn                           := get_pop_r.object_version_number;
    
      hz_party_v2pub.update_person(p_init_msg_list               => l_success, -- i v 'T'
                                   p_person_rec                  => l_upd_person, -- i PERSON_REC_TYPE
                                   p_party_object_version_number => l_ovn, -- i / o nocopy n
                                   x_profile_id                  => x_profile_id, -- o nocopy n
                                   x_return_status               => l_return_status, -- o nocopy v
                                   x_msg_count                   => l_msg_count, -- o nocopy n
                                   x_msg_data                    => l_msg_data -- o nocopy v
                                   );
    
      if l_return_status <> fnd_api.g_ret_sts_success then
      
        dbms_output.put_line('Failed Update Contact');
        dbms_output.put_line('l_msg_data = ' ||
                             substr(l_msg_data, 1, 2000));
        for i in 1 .. l_msg_count loop
          fnd_msg_pub.get(p_msg_index     => i,
                          p_data          => l_data,
                          p_encoded       => fnd_api.g_false,
                          p_msg_index_out => l_msg_index_out);
          dbms_output.put_line('l_Data - ' || l_data);
        end loop;
        l_count_e := l_count_e + 1;
        retcode   := 1;
        errbuf    := 'Failed Update at least ont Contact';
        rollback;
      
      else
        commit;
        --dbms_output.put_line('Success update Contact');
        l_count_s := l_count_s + 1;
      end if; -- Status if
    end loop;
    dbms_output.put_line('Party - '||p_party_name||' Sucess rows ' || l_count_s || ' Failed rows ' ||l_count_e);
  exception
    when others then
      rollback;
      dbms_output.put_line('Gen EXC - update_person_api - ' ||
                           substr(SQLERRM, 1, 240));
  end inactive_contact_person;

  --------------------------------------------------------------------
  --  name:            inactive_person_relationship
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   16/04/2012 
  --------------------------------------------------------------------
  --  purpose :        Procedure that close person relationships (Inactive) 
  --                   'Hans Schwerdt', 'Sean Kim', 'Matt Clevenger'            
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  16/04/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE inactive_person_relationship(errbuf       out varchar2,
                                         retcode      out varchar2,
                                         p_party_name in varchar2,
                                         p_status     in varchar2) is
  
    -- population of all the relationship we want to inactive.
    cursor get_pop_c is
      select p_rel.status rel_status,
             org_cont.status cont_status,
             org_cont.org_contact_id,
             org_cont.object_version_number cont_ovn,
             p_rel.object_version_number rel_ovn,
             p_rel.relationship_id,
             p_rel.party_id               rel_party_id,
             hp_rel.party_id,
             hp_rel.party_name,
             hp_rel.party_type,
             hp_rel.object_version_number party_ovn,
             hp_rel.party_number
        from ar.hz_relationships p_rel,
             ar.hz_org_contacts  org_cont,
             hz_parties          hp,
             hz_parties          hp_rel -- party of relationship
       where p_rel.subject_type = 'PERSON'
         and p_rel.relationship_id = org_cont.party_relationship_id
         and p_rel.subject_id = hp.party_id
            --and   p_rel.subject_id               = 6976045 --get_pop_r.party_id-- 6975045
         and hp.party_name like p_party_name || '%' --'Matt Clevenger%'
            --and     hp_rel.party_number            = '160685'
         and p_rel.party_id = hp_rel.party_id;
  
    l_org_contact_rec hz_party_contact_v2pub.org_contact_rec_type;
    l_user_id         number := null;
    l_cont_ovn        number := null;
    l_rel_ovn         number := null;
    l_party_ovn       number := null;
    l_party_id        number := null;
    l_success         varchar2(1) := 'T';
    l_return_status   varchar2(2000);
    l_msg_count       number;
    l_msg_data        varchar2(2000);
    l_data            varchar2(2000);
    l_msg_index_out   number;
  
    l_count_s number := 0;
    l_count_e number := 0;
  
  begin
    select user_id
      into l_user_id
      from fnd_user
     where user_name = 'CONVERSION';
  
    fnd_global.apps_initialize(user_id      => l_user_id, -- SALESFORCE
                               resp_id      => 51137, -- CRM Service Super User Objet
                               resp_appl_id => 514); -- Support (obsolete)
    retcode := 0;
    errbuf  := NULL;
  
    fnd_msg_pub.initialize;
    for get_pop_r in get_pop_c loop
      --dbms_output.put_line('--------- ' || get_pop_r.party_id ||
      --                     ' Party Num ' || get_pop_r.party_number);
    
      --l_org_contact_id := get_pop_r.org_contact_id;
      --l_rel_id         := get_pop_r.relationship_id; 
      l_cont_ovn                                      := get_pop_r.cont_ovn;
      l_rel_ovn                                       := get_pop_r.rel_ovn;
      l_party_id                                      := get_pop_r.party_id;
      l_party_ovn                                     := get_pop_r.party_ovn;
      l_org_contact_rec.org_contact_id                := get_pop_r.org_contact_id;
      l_org_contact_rec.party_rel_rec.status          := p_status; -- 'I' / 'A'
      l_org_contact_rec.party_rel_rec.relationship_id := get_pop_r.relationship_id;
      l_org_contact_rec.party_rel_rec.end_date        := sysdate;
      -- i think it will inactive the person party as well
      -- party
      l_org_contact_rec.party_rel_rec.party_rec.party_id := get_pop_r.rel_party_id;
      l_org_contact_rec.party_rel_rec.party_rec.status   := 'I';
    
      hz_party_contact_v2pub.update_org_contact(p_init_msg_list               => l_success, -- i v
                                                p_org_contact_rec             => l_org_contact_rec, -- i   ORG_CONTACT_REC_TYPE
                                                p_cont_object_version_number  => l_cont_ovn, -- i/o nocopy n
                                                p_rel_object_version_number   => l_rel_ovn, -- i/o nocopy n
                                                p_party_object_version_number => l_party_ovn, -- i/o nocopy n
                                                x_return_status               => l_return_status, -- o   nocopy v
                                                x_msg_count                   => l_msg_count, -- o   nocopy n
                                                x_msg_data                    => l_msg_data); -- o   nocopy v
    
      if l_return_status <> fnd_api.g_ret_sts_success then
        dbms_output.put_line('Failed Update org contact: l_org_contact_id - ' ||
                             get_pop_r.org_contact_id || ' msg_data = ' ||
                             substr(l_msg_data, 1, 2000));
        for i in 1 .. l_msg_count loop
          fnd_msg_pub.get(p_msg_index     => i,
                          p_data          => l_data,
                          p_encoded       => fnd_api.g_false,
                          p_msg_index_out => l_msg_index_out);
        
          dbms_output.put_line('l_Data - ' || l_data);
        end loop;
        rollback;
        l_count_e := l_count_e + 1;
      else
        l_count_s := l_count_s + 1;
        commit;
        --dbms_output.put_line('Success Update org contact: org_contact_id: ' ||
        --                     get_pop_r.org_contact_id);
      end if; -- Status if
    
    end loop;
  
    dbms_output.put_line('Party - '||p_party_name||' Sucess rows ' || l_count_s || ' Failed rows ' || l_count_e);
  
  end inactive_person_relationship;
  
  --------------------------------------------------------------------
  --  name:            inactive_cust_acc_role
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   27/09/2012 
  --------------------------------------------------------------------
  --  purpose :        Procedure that close person cust account role (Inactive) 
  --                   this proceduer run first then close relationship and then 
  --                   close perosn           
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  27/09/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure inactive_cust_acc_role (errbuf       out varchar2,
                                    retcode      out varchar2,
                                    p_party_name in  varchar2,
                                    p_status     in  varchar2 ) is 
    
    cursor c is
      select p_rel.status rel_status,
             org_cont.status cont_status,
             org_cont.org_contact_id,
             org_cont.object_version_number cont_ovn,
             p_rel.object_version_number rel_ovn,
             p_rel.relationship_id,
             hp_rel.party_id,
             hp_rel.party_name,
             hp_rel.party_type,
             hp_rel.object_version_number party_ovn,
             hp_rel.party_number,
             rol.party_id        role_party_id,
             rol.object_version_number rol_ovn,
             rol.cust_account_role_id 
        from ar.hz_relationships p_rel,
             ar.hz_org_contacts  org_cont,
             hz_parties          hp,
             hz_parties          hp_rel, -- party of relationship
             hz_cust_account_roles rol
       where p_rel.subject_type = 'PERSON'
         and p_rel.relationship_id = org_cont.party_relationship_id
         and p_rel.subject_id = hp.party_id
            --and   p_rel.subject_id               = 6976045 --get_pop_r.party_id-- 6975045
         and hp.party_name like p_party_name || '%' --'Matt Clevenger%'
            --and     hp_rel.party_number            = '160685'
         and p_rel.party_id = hp_rel.party_id
         and  hp_rel.party_id = rol.party_id
         and rol.cust_account_role_id not in (select distinct d.ship_to_contact_id/*, d.order_number, d.creation_date , d.org_id*/
                                              from   oe_order_headers_all  d
                                              where  d.ship_to_contact_id in (select /*name, num, p.party_id, rel.party_id, */role.cust_account_role_id
                                                                              from (SELECT hp.party_name name, count(hp.party_name) num
                                                                                      FROM hz_parties hp
                                                                                     where hp.created_by = 4290
                                                                                       and hp.party_type = 'PERSON'
                                                                                       and hp.creation_date > sysdate - 100
                                                                                     group by hp.party_name) temp,
                                                                                     hz_parties p,
                                                                                     hz_relationships rel,
                                                                                     hz_cust_account_roles role
                                                                              where num > 10 
                                                                              and   p.party_name = temp.name 
                                                                              --and   p.party_name = 'Judit Falk' 
                                                                              and   rel.subject_id = p.party_id
                                                                              and   rel.subject_type = 'PERSON'
                                                                              and   role.party_id = rel.party_id   
                                                                             ));

    l_cust_account_role_rec_type hz_cust_account_role_v2pub.cust_account_role_rec_type;
     
    l_return_status varchar2(2000);
    l_msg_count     number;
    l_msg_data      varchar2(2000);
    l_data          varchar2(2000); 
    l_msg_index_out number;
    l_count_s       number := 0;
    l_count_e       number := 0;
       
  begin
    errbuf  := null;
    retcode := 0;
    for r in c loop
      l_cust_account_role_rec_type.cust_account_role_id := r.cust_account_role_id;
      l_cust_account_role_rec_type.status := p_status; --'A'/'I';
      HZ_CUST_ACCOUNT_ROLE_V2PUB.update_cust_account_role (
        p_init_msg_list                         => 'T',
        p_cust_account_role_rec                 => l_cust_account_role_rec_type, -- i rec
        p_object_version_number                 => r.rol_ovn,                    -- i n
        x_return_status                         => l_return_status,              -- o v
        x_msg_count                             => l_msg_count,                  -- o n
        x_msg_data                              => l_msg_data                    -- o v
                                                );
      if l_return_status <> 'S' then
        
        if l_msg_count > 1 then
          for i in 1..l_msg_count loop 
            --dbms_output.put_line(i||'.'||substr(fnd_msg_pub.get(p_encoded=>fnd_api.g_false ), 1, 255));
            fnd_msg_pub.get(p_msg_index     => i,
                            p_data          => l_data,
                            p_encoded       => fnd_api.g_false,
                            p_msg_index_out => l_msg_index_out);
        
            dbms_output.put_line('l_Data - ' || l_data);
          end loop;
        end if; -- msg_count
        rollback;
        l_count_e := l_count_e + 1;
      else
        commit;
        l_count_s := l_count_s + 1;
      end if; -- retun status
    end loop;
    dbms_output.put_line('Party - '||p_party_name||' Sucess rows ' || l_count_s || ' Failed rows ' || l_count_e);                                                         
  exception
    when others then
      dbms_output.put_line('exc - '||substr(sqlerrm,1,240)); 
  end inactive_cust_acc_role;
  
  --------------------------------------------------------------------
  --  name:            upd_site_agente
  --  create by:       Ofer Suad
  --  Revision:        1.0 
  --  creation date:   09/08/2012 
  --------------------------------------------------------------------
  --  purpose :        chage parties agent        
  --------------------------------------------------------------------
  PROCEDURE upd_site_agent(errbuf          OUT VARCHAR2,
                           retcode         OUT VARCHAR2,
                           p_from_agent_id NUMBER,
                           p_party_id      NUMBER,
                           p_postal_code   VARCHAR2,
                           p_Country       VARCHAR2,
                           p_state         VARCHAR2,
                           p_to_agent_id   NUMBER) is
    CURSOR c IS
      SELECT hps.ROWID
        FROM hz_parties             hp,
             hz_party_sites         hps,
             hz_party_sites_dfv     hps_dfv,
             hz_cust_accounts       hca,
             hz_cust_acct_sites_all hcas,
             hz_cust_site_uses_all  hcsu,
             hz_locations           hl
       WHERE hps_dfv.row_id(+) = hps.ROWID
         AND hps_dfv.context_value(+) = hps.attribute_category
         AND hp.party_id = hps.party_id
         AND hp.party_id = hca.party_id
         AND hca.cust_account_id = hcas.cust_account_id
         AND hcas.party_site_id = hps.party_site_id
         AND hcas.cust_acct_site_id = hcsu.cust_acct_site_id
         AND nvl(hps_dfv.dealer, '-1') =
             nvl(to_char(p_from_agent_id), nvl(hps_dfv.dealer, '-1'))
         AND hp.party_type = 'ORGANIZATION'
         AND hp.party_id = nvl(p_party_id, hp.party_id)
         and hl.location_id = hps.location_id
         and hl.postal_code = nvl(p_postal_code, hl.postal_code)
         and hl.Country = nvl(p_Country, hl.Country)
         and hl.state = nvl(p_state, hl.state);
  begin
    if p_from_agent_id is null and p_party_id is null and p_state is null and
       p_postal_code is null then
    
      retcode := 1;
      fnd_file.put_line(fnd_file.log,
                        'Please provide at least one of the following :From Agent Name,Party Name,State,Postal Code.');
    else
      FOR i IN c LOOP
      
        update hz_party_sites hps
           set hps.Attribute11 = p_to_agent_id,
               hps.attribute_category='SHIP_TO' 
         where hps.rowid = i.rowid;
      end loop;
    end if;
    commit;
    EXCEPTION
    WHEN OTHERS THEN
      retcode := 1;
      fnd_file.put_line(fnd_file.log,
                        'Error in xxhz_customers_utils_pkg.upd_site_salesrep: ' ||
                        SQLERRM);
     errbuf:=     'Error in xxhz_customers_utils_pkg.upd_site_salesrep: ' ||
                        SQLERRM;              
  end upd_site_agent;
  --------------------------------------------------------
END xxhz_customers_utils_pkg;
/
