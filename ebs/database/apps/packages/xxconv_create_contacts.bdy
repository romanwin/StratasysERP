CREATE OR REPLACE PACKAGE BODY apps.xxconv_create_contacts IS
  ---------------------------------------------------------------------------------
  -- Entity Name: xxconv_hz_customers_pkg
  -- Purpose    : CREATING CUSTOMERS
  -- Author     : Evgeniy Braiman
  -- Version    : 1.0
  ---------------------------------------------------------------------------------
  -- Version    Date       Author         Description
  ---------------------------------------------------------------------------------
  -- 1.X       02/05/2013  yuval tal     create_party_person : remove " from phone   
  --                                     catch exception for multi party name                               
  ---------------------------------------------------------------------------------

  g_user_id fnd_user.user_id%TYPE := 1318;
  g_sysdate DATE;
  PROCEDURE update_contact_details(p_area_code    IN VARCHAR2,
                                   p_country_code IN VARCHAR2,
                                   p_number       IN VARCHAR2,
                                   p_ext          IN VARCHAR2,
                                   p_line_type    IN VARCHAR2,
                                   p_owner_table  IN VARCHAR2,
                                   p_owner_id     IN NUMBER,
                                   p_point_type   IN VARCHAR2,
                                   p_orig_sys     IN VARCHAR2,
                                   p_mail         IN VARCHAR2,
                                   p_status       OUT VARCHAR2,
                                   p_error        OUT VARCHAR2) IS
  
    l_success          VARCHAR2(1) := 'T';
    p_cretae_phone     hz_contact_point_v2pub.phone_rec_type;
    p_cretae_mail      hz_contact_point_v2pub.email_rec_type;
    p_contact_point    hz_contact_point_v2pub.contact_point_rec_type;
    x_contact_point_id NUMBER;
    l_return_status    VARCHAR2(2000);
    l_msg_count        NUMBER;
    l_msg_data         VARCHAR2(2000);
    --l_session_id       number;
    v_lang_id       NUMBER;
    l_msg_index_out NUMBER;
  
  BEGIN
    --fnd_global.apps_initialize(g_user_id,50582,222);
    /*fnd_global.INITIALIZE(l_session_id,g_user_id,50582,222,0,-1,144627,-1,-1,-1,-1,
    null,null,null,null,null,null,-1);   */
  
    fnd_global.apps_initialize(user_id      => g_user_id,
                               resp_id      => 50582,
                               resp_appl_id => 222);
    mo_global.set_org_access(p_org_id_char     => 81,
                             p_sp_id_char      => NULL,
                             p_appl_short_name => 'AR');
  
    SELECT hz_person_language_s.nextval INTO v_lang_id FROM dual;
  
    IF p_point_type = 'PHONE' THEN
      p_cretae_phone.phone_area_code     := p_area_code;
      p_cretae_phone.phone_country_code  := p_country_code;
      p_cretae_phone.phone_number        := p_number;
      p_cretae_phone.phone_line_type     := p_line_type; --'MOBILE';--TEL
      p_cretae_phone.phone_extension     := p_ext;
      p_contact_point.owner_table_name   := p_owner_table; --'HZ_PARTIES';--HZ_PARTY_SITES + party_site_id
      p_contact_point.owner_table_id     := p_owner_id; --46821;--For contact need rel_prty_id . For communication party_id:208567;
      p_contact_point.contact_point_type := p_point_type; --'PHONE';
      p_contact_point.created_by_module  := 'HR API';
      --p_contact_point.primary_flag := 'N';
      --p_contact_point.orig_system_reference := P_Orig_Sys;--'208567';
    
      hz_contact_point_v2pub.create_phone_contact_point(l_success,
                                                        p_contact_point,
                                                        p_cretae_phone,
                                                        x_contact_point_id,
                                                        l_return_status,
                                                        l_msg_count,
                                                        l_msg_data);
      IF l_return_status != apps.fnd_api.g_ret_sts_success THEN
        fnd_msg_pub.get(p_msg_index     => -1,
                        p_encoded       => 'F',
                        p_data          => l_msg_data,
                        p_msg_index_out => l_msg_index_out);
        p_status := l_return_status;
        p_error  := l_msg_data;
      ELSE
        p_status := l_return_status;
        p_error  := l_msg_data;
      END IF;
    ELSIF p_point_type = 'EMAIL' THEN
      p_cretae_mail.email_address           := p_mail;
      p_contact_point.owner_table_name      := p_owner_table; --HZ_PARTY_SITES + party_site_id
      p_contact_point.owner_table_id        := p_owner_id; --For contact need rel_prty_id . For communication party_id:208567;
      p_contact_point.contact_point_type    := p_point_type;
      p_contact_point.created_by_module     := 'HR API';
      p_contact_point.primary_flag          := 'N';
      p_contact_point.orig_system_reference := p_orig_sys;
    
      hz_contact_point_v2pub.create_email_contact_point(l_success,
                                                        p_contact_point,
                                                        p_cretae_mail, --p_cretae_phone,
                                                        x_contact_point_id,
                                                        l_return_status,
                                                        l_msg_count,
                                                        l_msg_data);
    
      IF l_return_status != apps.fnd_api.g_ret_sts_success THEN
        fnd_msg_pub.get(p_msg_index     => -1,
                        p_encoded       => 'F',
                        p_data          => l_msg_data,
                        p_msg_index_out => l_msg_index_out);
        p_status := l_return_status;
        p_error  := l_msg_data;
      ELSE
        p_status := l_return_status;
        p_error  := l_msg_data;
      END IF;
    ELSE
      p_status := 'E';
      p_error  := 'Wrong Type Of Point Type Entered';
    END IF;
  
  END update_contact_details;

  PROCEDURE create_person(p_subject_id       IN NUMBER,
                          p_object_id        IN NUMBER,
                          p_relation_code    IN VARCHAR2,
                          p_object_type      IN VARCHAR2,
                          p_subject_type     IN VARCHAR2,
                          p_contact_party    OUT NUMBER,
                          p_party_number     OUT NUMBER,
                          p_object_tble_name IN VARCHAR2,
                          p_relation_type    IN VARCHAR2,
                          p_title            IN VARCHAR2,
                          p_status           OUT VARCHAR2,
                          p_error            OUT VARCHAR2,
                          p_resp_id          IN NUMBER,
                          p_org              IN VARCHAR2,
                          p_resp_apl_id      IN NUMBER) IS
  
    l_success         VARCHAR2(1) := 'T';
    p_org_contact_rec hz_party_contact_v2pub.org_contact_rec_type;
    l_return_status   VARCHAR2(2000);
    l_msg_count       NUMBER;
    l_msg_data        VARCHAR2(2000);
    x_party_rel_id    NUMBER;
    x_party_id        NUMBER;
    x_party_number    VARCHAR2(2000);
    x_org_contact_id  NUMBER;
    l_msg_index_out   NUMBER;
    --v_title           varchar2(20);
  
  BEGIN
  
    l_return_status  := NULL;
    l_msg_count      := NULL;
    l_msg_data       := NULL;
    x_org_contact_id := NULL;
    x_party_id       := NULL;
    x_party_number   := NULL;
  
    p_org_contact_rec.created_by_module := 'TCA_V1_API';
    --p_org_contact_rec.job_title                        := 'AAA';
    p_org_contact_rec.party_rel_rec.subject_id         := p_subject_id;
    p_org_contact_rec.party_rel_rec.subject_type       := p_subject_type;
    p_org_contact_rec.party_rel_rec.subject_table_name := 'HZ_PARTIES';
    p_org_contact_rec.party_rel_rec.object_id          := p_object_id;
    p_org_contact_rec.party_rel_rec.object_type        := p_object_type;
    p_org_contact_rec.party_rel_rec.object_table_name  := p_object_tble_name;
    p_org_contact_rec.party_rel_rec.relationship_code  := p_relation_code;
    p_org_contact_rec.party_rel_rec.relationship_type  := p_relation_type;
    p_org_contact_rec.party_rel_rec.start_date         := g_sysdate;
    p_org_contact_rec.party_rel_rec.status             := 'A';
  
    hz_party_contact_v2pub.create_org_contact(l_success,
                                              p_org_contact_rec,
                                              x_org_contact_id,
                                              x_party_rel_id,
                                              x_party_id,
                                              x_party_number,
                                              l_return_status,
                                              l_msg_count,
                                              l_msg_data);
  
    IF l_return_status != apps.fnd_api.g_ret_sts_success THEN
      fnd_msg_pub.get(p_msg_index     => -1,
                      p_encoded       => 'F',
                      p_data          => l_msg_data,
                      p_msg_index_out => l_msg_index_out);
      p_status := l_return_status;
      p_error  := 'Rel: ' || upper(p_title) || ' ' || l_msg_data;
    ELSE
      p_status        := 'S';
      p_error         := NULL;
      p_contact_party := x_party_id;
      p_party_number  := x_party_number;
    END IF;
  
  END create_person;
  ------------------------------------------
  -- create_party_person

  ---------------------------------------------------------------------------------
  -- Version    Date       Author         Description
  ---------------------------------------------------------------------------------
  -- 1.X       02/05/2013  yuval tal     create_party_person : remove " from phone
  --                                     catch exception for multi party name                                 
  ---------------------------------------------------------------------------------

  PROCEDURE create_party_person(errbuf OUT VARCHAR2, retcode OUT VARCHAR2) IS
  
    l_success              VARCHAR2(1) := 'T';
    p_upd_person           hz_party_v2pub.person_rec_type;
    p_cr_cust_acc_role_rec hz_cust_account_role_v2pub.cust_account_role_rec_type;
    l_init_msg_list        NUMBER;
    l_return_status        VARCHAR2(2000);
    l_msg_count            NUMBER;
    l_msg_data             VARCHAR2(2000);
    x_party_id             NUMBER;
    v_x_party_id           NUMBER;
    x_party_number         VARCHAR2(2000);
    x_profile_id           NUMBER;
    v_contact_status       VARCHAR2(1);
    v_contact_error        VARCHAR2(1000);
    l_msg_index_out        NUMBER;
    v_multi_contact        VARCHAR2(100) := '@@aa&&';
    v_multi_org            VARCHAR2(100) := '@@aa&&';
    v_multi_site           VARCHAR2(100) := '@@aa&&';
    v_contact_party        NUMBER(10);
    x_cust_account_role_id NUMBER(10);
    v_party_number         NUMBER(10);
    v_language             VARCHAR2(10);
    v_cust_acct_site_id    NUMBER(10);
    --v_customer_cyborg      number(10) := 2;
    --v_customer_cyborg1     number(10) := 2;
    v_resp_id         NUMBER(10);
    v_org_id          VARCHAR2(10);
    v_resp_apl_id     NUMBER(10);
    v_party_id        NUMBER;
    v_cust_account_id NUMBER;
    v_exists          CHAR(1);
  
    CURSOR cr_contacts IS
      SELECT DISTINCT a.operating_unit_name,
                      a.organization_name,
                      a.contact_first_name,
                      a.contact_middle_name,
                      a.contact_last_name,
                      upper(a.prefix) prefix,
                      a.type,
                      REPLACE(a.phone, '"') phone,
                      a.email,
                      a.area_code,
                      a.country_code,
                      a.extention,
                      a.site_identifier,
                      NULL AS job_title
      --a.address_line1 as job_title
        FROM xxobjt_conv_contacts a
       WHERE /*a.site_identifier is not null
                                                                                                               and a.error_message is not null*/
       a.error_code = 'N'
      --a.contact_first_name in ('Daniela Conceicao Pereir', 'Sergiy Dudzyanyy')
       ORDER BY a.contact_first_name,
                a.operating_unit_name,
                a.organization_name,
                nvl(a.site_identifier, 'a');
  
  BEGIN
    errbuf  := NULL;
    retcode := 0;
    --Get User
    SELECT user_id
      INTO g_user_id
      FROM fnd_user
     WHERE user_name = 'CONVERSION';
    g_sysdate := SYSDATE;
  
    --Get All Contacts details  
    FOR i IN cr_contacts LOOP
    
      --Get OU
      BEGIN
        SELECT organization_id
          INTO v_org_id
          FROM hr_all_organization_units
         WHERE NAME = i.operating_unit_name;
      EXCEPTION
        WHEN OTHERS THEN
          v_org_id := NULL;
      END;
    
      fnd_global.apps_initialize(g_user_id, 50617, 222);
      mo_global.set_org_access(v_org_id, NULL, 'AR');
    
      fnd_msg_pub.initialize;
      l_init_msg_list  := NULL;
      l_return_status  := 'S';
      l_msg_count      := NULL;
      l_msg_data       := NULL;
      x_party_number   := NULL;
      v_contact_status := 'S';
      v_contact_error  := NULL;
      v_party_id       := NULL;
    
      --Get Customer Details
      BEGIN
      
        SELECT hp.party_id, hc.cust_account_id
          INTO v_party_id, v_cust_account_id
          FROM hz_parties hp, hz_cust_accounts hc
         WHERE hp.party_name = i.organization_name
           AND hp.party_id = hc.party_id;
      EXCEPTION
        WHEN too_many_rows THEN
        
          v_contact_error := 'More than one party with name= ' ||
                             i.organization_name;
          v_party_id      := NULL;
        WHEN no_data_found THEN
          v_contact_error := 'No party name found for organization= ' ||
                             i.organization_name;
          v_party_id      := NULL;
      END;
    
      --If customer not exist -> error.
      IF v_party_id IS NULL THEN
        UPDATE xxobjt_conv_contacts a
           SET a.error_code = 'E', a.error_message = v_contact_error
         WHERE a.organization_name = i.organization_name
           AND nvl(a.contact_first_name, '@@') =
               nvl(i.contact_first_name, '@@')
           AND nvl(a.contact_last_name, '@@') =
               nvl(i.contact_last_name, '@@')
           AND a.type = i.type;
        COMMIT;
      ELSE
        --Check if contact created already  (v_multi_contact hold the previos record contact)
        IF v_multi_contact <> i.contact_first_name||i.contact_last_name THEN
        
          x_party_id      := NULL;
          v_contact_party := NULL;
        
          --Get language
          BEGIN
            SELECT hpl.language_name
              INTO v_language
              FROM hz_person_language hpl
             WHERE hpl.party_id = v_party_id
               AND rownum = 1;
          EXCEPTION
            WHEN no_data_found THEN
              v_language := 'US';
          END;
        
          --Get site details by site identifier.
          BEGIN
            SELECT DISTINCT hc.cust_acct_site_id
              INTO v_cust_acct_site_id
              FROM hz_cust_acct_sites_all hc
             WHERE hc.orig_system_reference = i.site_identifier;
          EXCEPTION
            WHEN no_data_found THEN
              v_cust_acct_site_id := NULL;
          END;
        
          -- Create contact as person. If OK Continue to RelationShip
          p_upd_person.person_first_name       := i.contact_first_name;
          p_upd_person.person_last_name        := i.contact_last_name;
          p_upd_person.person_pre_name_adjunct := i.prefix;
          p_upd_person.person_title            := i.job_title;
          p_upd_person.created_by_module       := 'TCA_V1_API';
          p_upd_person.party_rec.status        := 'A';
        
          hz_party_v2pub.create_person(l_success,
                                       p_upd_person,
                                       x_party_id,
                                       x_party_number,
                                       x_profile_id,
                                       l_return_status,
                                       l_msg_count,
                                       l_msg_data);
        
          IF l_return_status != apps.fnd_api.g_ret_sts_success THEN
            fnd_msg_pub.get(p_msg_index     => -1,
                            p_encoded       => 'F',
                            p_data          => l_msg_data,
                            p_msg_index_out => l_msg_index_out);
          ELSE
            --Create RelationShip Between Contact And Organization. If OK continue to Role 
            create_person(x_party_id,
                          v_party_id,
                          'CONTACT_OF',
                          'ORGANIZATION',
                          'PERSON',
                          v_contact_party,
                          v_party_number,
                          'HZ_PARTIES',
                          'CONTACT',
                          i.prefix,
                          v_contact_status,
                          l_msg_data,
                          v_resp_id,
                          v_org_id,
                          v_resp_apl_id);
          
            IF v_contact_status <> 'S' THEN
              ROLLBACK;
            ELSE
              -- Create Role. If OK continue to contact details (Phone/Fax/Mail)
              -- It will Create The Contact Details( For Site Put cust_acct_site_id. For Account Don't Put cust_acct_site_id) 
              l_init_msg_list := NULL;
              l_msg_count     := NULL;
              l_msg_data      := NULL;
              x_party_number  := NULL;
              l_return_status := 'S';
            
              IF v_cust_acct_site_id IS NOT NULL THEN
                p_cr_cust_acc_role_rec.cust_acct_site_id := v_cust_acct_site_id;
              END IF;
              --dbms_output.put_line(a => 'Debug v_cust_acct_site_id:'||v_cust_acct_site_id);
              p_cr_cust_acc_role_rec.party_id          := v_contact_party;
              p_cr_cust_acc_role_rec.cust_account_id   := v_cust_account_id;
              p_cr_cust_acc_role_rec.primary_flag      := 'N';
              p_cr_cust_acc_role_rec.role_type         := 'CONTACT';
              p_cr_cust_acc_role_rec.created_by_module := 'TCA_V1_API';
            
              fnd_msg_pub.initialize;
              hz_cust_account_role_v2pub.create_cust_account_role(l_success,
                                                                  p_cr_cust_acc_role_rec,
                                                                  x_cust_account_role_id,
                                                                  l_return_status,
                                                                  l_msg_count,
                                                                  l_msg_data);
              IF l_return_status != apps.fnd_api.g_ret_sts_success THEN
                fnd_msg_pub.get(p_msg_index     => -1,
                                p_encoded       => 'F',
                                p_data          => l_msg_data,
                                p_msg_index_out => l_msg_index_out);
                ROLLBACK;
              ELSE
                --Insert Phone
                --dbms_output.put_line(a => 'Debug v_contact_party:'||v_contact_party);
                IF i.phone IS NOT NULL AND i.type = 'Telephone' THEN
                  -- AviH Change For Not Duplicating Phones
                  BEGIN
                    SELECT 'Y'
                      INTO v_exists
                      FROM hz_contact_points aa
                     WHERE aa.contact_point_type = 'PHONE'
                       AND aa.phone_line_type = 'GEN'
                       AND aa.owner_table_name = 'HZ_PARTIES'
                       AND aa.owner_table_id = v_contact_party
                       AND REPLACE(aa.phone_number, '.', NULL) = i.phone;
                  EXCEPTION
                    WHEN no_data_found THEN
                      v_exists := 'N';
                  END;
                  IF v_exists = 'N' THEN
                    update_contact_details(i.area_code,
                                           i.country_code,
                                           i.phone,
                                           i.extention,
                                           'GEN',
                                           'HZ_PARTIES',
                                           v_contact_party, --*/x_party_id,
                                           'PHONE',
                                           v_party_number, --x_party_number,
                                           NULL,
                                           l_return_status,
                                           l_msg_data);
                    IF l_return_status <> 'S' THEN
                      ROLLBACK;
                    END IF;
                  END IF;
                END IF;
              
                --Insert Fax
                IF i.phone IS NOT NULL AND i.type = 'Fax' AND
                   l_return_status = 'S' THEN
                  BEGIN
                    SELECT 'Y'
                      INTO v_exists
                      FROM hz_contact_points aa
                     WHERE aa.contact_point_type = 'PHONE'
                       AND aa.phone_line_type = 'FAX'
                       AND aa.owner_table_name = 'HZ_PARTIES'
                       AND aa.owner_table_id = v_contact_party
                       AND REPLACE(aa.phone_number, '.', NULL) = i.phone;
                  EXCEPTION
                    WHEN no_data_found THEN
                      v_exists := 'N';
                  END;
                  IF v_exists = 'N' THEN
                    update_contact_details(i.area_code,
                                           i.country_code,
                                           i.phone,
                                           i.extention,
                                           'FAX',
                                           'HZ_PARTIES',
                                           v_contact_party, --*/x_party_id,
                                           'PHONE',
                                           v_party_number, --x_party_number,
                                           NULL,
                                           l_return_status,
                                           l_msg_data);
                    IF l_return_status <> 'S' THEN
                      ROLLBACK;
                    END IF;
                  END IF;
                END IF;
              
                --Insert Mobile
                IF i.phone IS NOT NULL AND i.type = 'Mobile' AND
                   l_return_status = 'S' THEN
                  BEGIN
                    SELECT 'Y'
                      INTO v_exists
                      FROM hz_contact_points aa
                     WHERE aa.contact_point_type = 'PHONE'
                       AND aa.phone_line_type = 'MOBILE'
                       AND aa.owner_table_name = 'HZ_PARTIES'
                       AND aa.owner_table_id = v_contact_party
                       AND REPLACE(aa.phone_number, '.', NULL) = i.phone;
                  EXCEPTION
                    WHEN no_data_found THEN
                      v_exists := 'N';
                  END;
                  IF v_exists = 'N' THEN
                    update_contact_details(i.area_code,
                                           i.country_code,
                                           i.phone,
                                           i.extention,
                                           'MOBILE',
                                           'HZ_PARTIES',
                                           v_contact_party, --*/x_party_id,
                                           'PHONE',
                                           v_party_number, --x_party_number,
                                           NULL,
                                           l_return_status,
                                           l_msg_data);
                    IF l_return_status <> 'S' THEN
                      ROLLBACK;
                    END IF;
                  END IF;
                END IF;
              
                --Insert Mail
                IF i.email IS NOT NULL AND l_return_status = 'S' THEN
                  BEGIN
                    SELECT 'Y'
                      INTO v_exists
                      FROM hz_contact_points aa
                     WHERE aa.contact_point_type = 'EMAIL'
                       AND aa.owner_table_name = 'HZ_PARTIES'
                       AND aa.owner_table_id = v_contact_party
                       AND aa.email_address = i.email;
                  EXCEPTION
                    WHEN no_data_found THEN
                      v_exists := 'N';
                  END;
                  IF v_exists = 'N' THEN
                    update_contact_details(NULL,
                                           NULL,
                                           NULL,
                                           NULL,
                                           NULL,
                                           'HZ_PARTIES',
                                           v_contact_party, --x_party_id,
                                           'EMAIL',
                                           v_party_number, --x_party_number,
                                           i.email,
                                           l_return_status,
                                           l_msg_data);
                    IF l_return_status <> 'S' THEN
                      ROLLBACK;
                    END IF; --Update Mail  
                  END IF;
                END IF; -- Mail Exist 
              
              END IF; --Role
            
            END IF; --Relationship
          
          END IF; --Person
        
          --Update status & Message
          UPDATE xxobjt_conv_contacts a
             SET a.error_code    = l_return_status,
                 a.error_message = nvl(l_msg_data, v_contact_error)
           WHERE a.organization_name = i.organization_name
             AND nvl(a.contact_first_name, '@@') =
                 nvl(i.contact_first_name, '@@')
             AND nvl(a.contact_last_name, '@@') =
                 nvl(i.contact_last_name, '@@')
             AND a.type = i.type
             AND nvl(a.site_identifier, ' @@@') =
                 nvl(i.site_identifier, ' @@@');
        
          --Commit only in the end   
          COMMIT;
        
          --Initialize values of customer/contact/site
          v_multi_org     := i.organization_name;
          v_multi_contact := i.contact_first_name||i.contact_last_name;
          v_multi_site    := i.site_identifier;
        
          -- If a new contact record -> it it's the same contact -> check if the previos record created the contact
          -- x_party_id will have a value if the contact was created.
          -- No Need To Create Again The Contact Only Connect It To The Organization/Site(if not connected by now)
        ELSIF x_party_id IS NOT NULL THEN
        
          --Get language
          BEGIN
            SELECT hpl.language_name
              INTO v_language
              FROM hz_person_language hpl
             WHERE hpl.party_id = v_party_id
               AND rownum = 1;
          EXCEPTION
            WHEN no_data_found THEN
              v_language := 'US';
          END;
        
          --Get site details
          BEGIN
            SELECT DISTINCT hc.cust_acct_site_id
              INTO v_cust_acct_site_id
              FROM hz_cust_acct_sites_all hc
             WHERE hc.orig_system_reference = i.site_identifier;
          EXCEPTION
            WHEN no_data_found THEN
              v_cust_acct_site_id := NULL;
          END;
        
          --In case it's the same Customer don't create a Relationship again. 
          IF v_multi_org <> i.organization_name THEN
          
            v_x_party_id := x_party_id;
            create_person(x_party_id,
                          v_party_id,
                          'CONTACT_OF',
                          'ORGANIZATION',
                          'PERSON',
                          v_contact_party,
                          v_party_number,
                          'HZ_PARTIES',
                          'CONTACT',
                          i.prefix,
                          v_contact_status,
                          v_contact_error,
                          v_resp_id,
                          v_org_id,
                          v_resp_apl_id);
          
            v_multi_org := i.organization_name;
          ELSE
            v_contact_status := 'S';
          END IF;
        
          IF v_contact_status <> 'S' THEN
            x_party_id := v_x_party_id;
            ROLLBACK;
          ELSE
            -- If no error
            --If There is a multiple record of sites for the same customer create the role.
            --dbms_output.put_line(a => 'v_multi_site:'||v_multi_site||', i.site_identifier:'||i.site_identifier);
            IF ((nvl(v_multi_site, '@@@#') <> i.site_identifier) AND
               (i.site_identifier IS NOT NULL)) THEN
              -- Create Role
              l_init_msg_list := NULL;
              x_party_number  := NULL;
            
              IF v_cust_acct_site_id IS NOT NULL THEN
                p_cr_cust_acc_role_rec.cust_acct_site_id := v_cust_acct_site_id;
                p_cr_cust_acc_role_rec.primary_flag      := 'N';
              END IF;
              --dbms_output.put_line(a => 'Debug2 v_cust_acct_site_id:'||v_cust_acct_site_id);
              --Create Role
              p_cr_cust_acc_role_rec.party_id        := v_contact_party;
              p_cr_cust_acc_role_rec.cust_account_id := v_cust_account_id;
              --p_cr_cust_acc_role_rec.primary_flag := 'N'; 
              p_cr_cust_acc_role_rec.role_type         := 'CONTACT';
              p_cr_cust_acc_role_rec.created_by_module := 'TCA_V1_API';
            
              hz_cust_account_role_v2pub.create_cust_account_role(l_success,
                                                                  p_cr_cust_acc_role_rec,
                                                                  x_cust_account_role_id,
                                                                  v_contact_status,
                                                                  l_msg_count,
                                                                  v_contact_error);
              IF v_contact_status != apps.fnd_api.g_ret_sts_success THEN
                fnd_msg_pub.get(p_msg_index     => -1,
                                p_encoded       => 'F',
                                p_data          => v_contact_error,
                                p_msg_index_out => l_msg_index_out);
                ROLLBACK;
              END IF;
            
            ELSE
              v_contact_status := 'S';
            END IF;
          
            v_multi_site := i.site_identifier;
          
          END IF;
          --dbms_output.put_line(a => 'Debug2 v_contact_party:'||v_contact_party);
          IF i.phone IS NOT NULL AND i.type = 'Telephone' AND
             v_contact_status = 'S' THEN
            --  dbms_output.put_line(i.customer_cyborg_id||' '||i.Phone_Number);
            BEGIN
              SELECT 'Y'
                INTO v_exists
                FROM hz_contact_points aa
               WHERE aa.contact_point_type = 'PHONE'
                 AND aa.phone_line_type = 'GEN'
                 AND aa.owner_table_name = 'HZ_PARTIES'
                 AND aa.owner_table_id = v_contact_party
                 AND REPLACE(aa.phone_number, '.', NULL) = i.phone;
            EXCEPTION
              WHEN no_data_found THEN
                v_exists := 'N';
            END;
            IF v_exists = 'N' THEN
              update_contact_details(i.area_code,
                                     i.country_code,
                                     i.phone,
                                     i.extention,
                                     'GEN',
                                     'HZ_PARTIES',
                                     v_contact_party, --*/x_party_id,
                                     'PHONE',
                                     v_party_number, --x_party_number,
                                     NULL,
                                     v_contact_status,
                                     v_contact_error);
              IF v_contact_status <> 'S' THEN
                ROLLBACK;
              END IF;
            END IF;
          END IF; --Phone Exist  
        
          IF i.phone IS NOT NULL AND i.type = 'Fax' AND
             l_return_status = 'S' THEN
            BEGIN
              SELECT 'Y'
                INTO v_exists
                FROM hz_contact_points aa
               WHERE aa.contact_point_type = 'PHONE'
                 AND aa.phone_line_type = 'FAX'
                 AND aa.owner_table_name = 'HZ_PARTIES'
                 AND aa.owner_table_id = v_contact_party
                 AND REPLACE(aa.phone_number, '.', NULL) = i.phone;
            EXCEPTION
              WHEN no_data_found THEN
                v_exists := 'N';
            END;
            IF v_exists = 'N' THEN
              update_contact_details(i.area_code,
                                     i.country_code,
                                     i.phone,
                                     i.extention,
                                     'FAX',
                                     'HZ_PARTIES',
                                     v_contact_party, --*/x_party_id,
                                     'PHONE',
                                     v_party_number, --x_party_number,
                                     NULL,
                                     l_return_status,
                                     l_msg_data);
              IF l_return_status <> 'S' THEN
                ROLLBACK;
              END IF;
            END IF;
          END IF;
        
          IF i.phone IS NOT NULL AND i.type = 'Mobile' AND
             l_return_status = 'S' THEN
            BEGIN
              SELECT 'Y'
                INTO v_exists
                FROM hz_contact_points aa
               WHERE aa.contact_point_type = 'PHONE'
                 AND aa.phone_line_type = 'MOBILE'
                 AND aa.owner_table_name = 'HZ_PARTIES'
                 AND aa.owner_table_id = v_contact_party
                 AND REPLACE(aa.phone_number, '.', NULL) = i.phone;
            EXCEPTION
              WHEN no_data_found THEN
                v_exists := 'N';
            END;
            IF v_exists = 'N' THEN
              update_contact_details(i.area_code,
                                     i.country_code,
                                     i.phone,
                                     i.extention,
                                     'MOBILE',
                                     'HZ_PARTIES',
                                     v_contact_party, --*/x_party_id,
                                     'PHONE',
                                     v_party_number, --x_party_number,
                                     NULL,
                                     l_return_status,
                                     l_msg_data);
              IF l_return_status <> 'S' THEN
                ROLLBACK;
              END IF;
            END IF;
          END IF;
        
          IF i.email IS NOT NULL AND v_contact_status = 'S' THEN
            BEGIN
              SELECT 'Y'
                INTO v_exists
                FROM hz_contact_points aa
               WHERE aa.contact_point_type = 'EMAIL'
                 AND aa.owner_table_name = 'HZ_PARTIES'
                 AND aa.owner_table_id = v_contact_party
                 AND aa.email_address = i.email;
            EXCEPTION
              WHEN no_data_found THEN
                v_exists := 'N';
            END;
            IF v_exists = 'N' THEN
              update_contact_details(NULL,
                                     NULL,
                                     NULL,
                                     NULL,
                                     NULL,
                                     'HZ_PARTIES',
                                     v_contact_party, --x_party_id,
                                     'EMAIL',
                                     v_party_number, --x_party_number,
                                     i.email,
                                     v_contact_status,
                                     v_contact_error);
              IF v_contact_status <> 'S' THEN
                ROLLBACK;
              END IF; --Update Mail      
            END IF;
          END IF; -- Mail Exist 
        
          UPDATE xxobjt_conv_contacts a
             SET a.error_code    = v_contact_status,
                 a.error_message = v_contact_error
           WHERE a.organization_name = i.organization_name
             AND nvl(a.contact_first_name, '@@') =
                 nvl(i.contact_first_name, '@@')
             AND nvl(a.contact_last_name, '@@') =
                 nvl(i.contact_last_name, '@@')
             AND a.type = i.type
             AND nvl(a.site_identifier, ' @@@') =
                 nvl(i.site_identifier, ' @@@');
          COMMIT;
          v_multi_contact := i.contact_first_name;
        
        ELSE
        
          UPDATE xxobjt_conv_contacts a
             SET a.error_code    = v_contact_status,
                 a.error_message = v_contact_error
           WHERE a.organization_name = i.organization_name
             AND nvl(a.contact_first_name, '@@') =
                 nvl(i.contact_first_name, '@@')
             AND nvl(a.contact_last_name, '@@') =
                 nvl(i.contact_last_name, '@@')
             AND a.type = i.type
             AND nvl(a.site_identifier, ' @@@') =
                 nvl(i.site_identifier, ' @@@');
          COMMIT;
        
        END IF;
        /*  Else
        dbms_output.put_line('S  END');      
          End If;*/
      END IF;
      --Commit;                              
    END LOOP;
  END create_party_person;
END xxconv_create_contacts;
/
