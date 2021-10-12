CREATE OR REPLACE PACKAGE BODY xxconv_create_contacts_pkg IS
   g_user_id fnd_user.user_id%TYPE := 1318;
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
      l_session_id       NUMBER;
      v_lang_id          NUMBER;
      l_msg_index_out    NUMBER;
   
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
   
      SELECT hz_person_language_s.NEXTVAL INTO v_lang_id FROM dual;
   
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
            dbms_output.put_line('Phone' || substr(l_msg_data, 240));
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
      v_title           VARCHAR2(20);
   
   BEGIN
   
      fnd_global.apps_initialize(g_user_id, 50582, 222);
      fnd_client_info.set_org_context(p_org);
      l_return_status  := NULL;
      l_msg_count      := NULL;
      l_msg_data       := NULL;
      x_org_contact_id := NULL;
      x_party_id       := NULL;
      x_party_number   := NULL;
   
      /* If P_Title is not null Then
       v_title :=upper(P_Title)||'.';
      Else     
       v_title := null;
      End If; */
   
      p_org_contact_rec.created_by_module                := 'HR API';
      p_org_contact_rec.party_rel_rec.subject_id         := p_subject_id; --i.relation_to;--208571; 
      p_org_contact_rec.party_rel_rec.subject_type       := p_subject_type; --'PERSON';
      p_org_contact_rec.party_rel_rec.subject_table_name := 'HZ_PARTIES';
      p_org_contact_rec.party_rel_rec.object_id          := p_object_id; --i.party_id; 
      p_org_contact_rec.party_rel_rec.object_type        := p_object_type; --'ORGANIZATION';
      p_org_contact_rec.party_rel_rec.object_table_name  := p_object_tble_name; --*/'HZ_PARTIES';
      p_org_contact_rec.party_rel_rec.relationship_code  := p_relation_code; --i.relationship_type;
      p_org_contact_rec.party_rel_rec.relationship_type  := p_relation_type; --'CONTACT';
      -- p_org_contact_rec.decision_maker_flag := 'Y';--nvl(P_Decision_Maker,'Y');
      --p_org_contact_rec.job_title := P_Job_Title;
      p_org_contact_rec.title                    := upper(p_title);
      p_org_contact_rec.party_rel_rec.start_date := SYSDATE;
      p_org_contact_rec.party_rel_rec.status     := 'A';
   
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
         dbms_output.put_line('Details: ' || p_object_id || ' ' ||
                              substr(l_msg_data, 1, 210));
      ELSE
         p_status        := 'S';
         p_error         := NULL;
         p_contact_party := x_party_id;
         p_party_number  := x_party_number;
      END IF;
   
   END create_person;

   PROCEDURE create_party_person(errbuf OUT VARCHAR2, retcode OUT VARCHAR2) IS
   
      l_success              VARCHAR2(1) := 'T';
      p_upd_person           hz_party_v2pub.person_rec_type;
      p_cr_cust_acc_role_rec hz_cust_account_role_v2pub.cust_account_role_rec_type;
      l_init_msg_list        NUMBER;
      l_return_status        VARCHAR2(2000);
      l_msg_count            NUMBER;
      l_msg_data             VARCHAR2(2000);
      x_party_id             NUMBER;
      x_party_number         VARCHAR2(2000);
      x_profile_id           NUMBER;
      v_contact_status       VARCHAR2(1);
      v_contact_error        VARCHAR2(1000);
      l_msg_index_out        NUMBER;
      v_multi_contact        VARCHAR2(100) := '@@aa&&';
      v_contact_party        NUMBER(10);
      x_cust_account_role_id NUMBER(10);
      v_party_number         NUMBER(10);
      v_language             VARCHAR2(10);
      v_cust_acct_site_id    NUMBER(10);
      v_customer_cyborg      NUMBER(10) := 2;
      v_customer_cyborg1     NUMBER(10) := 2;
      v_resp_id              NUMBER(10);
      v_org_id               VARCHAR2(10);
      v_resp_apl_id          NUMBER(10);
      v_party_id             NUMBER;
      v_cust_account_id      NUMBER;
   
      CURSOR cr_contacts IS
         SELECT *
           FROM xxobjt_conv_contacts a
          WHERE a.ERROR_CODE IS NULL
          ORDER BY a.contact_first_name,
                   a.operating_unit_name,
                   a.organization_name;
   
   BEGIN
   
      SELECT user_id
        INTO g_user_id
        FROM fnd_user
       WHERE user_name = 'CONVERSION';
   
      FOR i IN cr_contacts LOOP
      
         BEGIN
            SELECT organization_id
              INTO v_org_id
              FROM hr_all_organization_units
             WHERE NAME = i.operating_unit_name;
         EXCEPTION
            WHEN OTHERS THEN
               v_org_id := NULL;
         END;
      
         fnd_global.apps_initialize(g_user_id, 50582, 222);
         fnd_client_info.set_org_context(v_org_id);
         fnd_msg_pub.initialize;
         l_init_msg_list  := NULL;
         l_return_status  := NULL;
         l_msg_count      := NULL;
         l_msg_data       := NULL;
         x_party_number   := NULL;
         l_return_status  := NULL;
         v_contact_status := NULL;
         v_contact_error  := NULL;
         v_party_id       := NULL;
         --dbms_output.put_line(v_multi_contact|| ' '||i.contact_cyborg_id);
         IF v_multi_contact <> i.contact_first_name THEN
            --commit;
         
            x_party_id := NULL;
         
            BEGIN
               SELECT hp.party_id, hc.cust_account_id
                 INTO v_party_id, v_cust_account_id
                 FROM hz_parties hp, hz_cust_accounts hc
                WHERE hp.party_name = i.organization_name AND
                      hp.party_id = hc.party_id;
            EXCEPTION
               WHEN no_data_found THEN
                  v_party_id := NULL;
            END;
         
            IF v_party_id IS NULL THEN
               UPDATE xxobjt_conv_contacts a
                  SET a.ERROR_CODE    = 'E',
                      a.error_message = 'Customer Does Not Exist'
                WHERE a.organization_name = i.organization_name;
               COMMIT;
            ELSE
               BEGIN
                  SELECT hpl.language_name
                    INTO v_language
                    FROM hz_person_language hpl
                   WHERE hpl.party_id = v_party_id AND
                         rownum = 1;
               EXCEPTION
                  WHEN no_data_found THEN
                     v_language := 'US';
               END;
            
               -- Person Handle
               p_upd_person.person_first_name := i.contact_first_name;
               --p_upd_person.person_last_name   := 'aa';--i.contact_last_name;
               p_upd_person.person_title := i.prefix;
               -- p_upd_person.person_middle_name := 'cc';--i.contact_middle_name ; 
               p_upd_person.created_by_module := 'HR API';
               p_upd_person.party_rec.status  := 'A';
            
               hz_party_v2pub.create_person(l_success,
                                            p_upd_person,
                                            x_party_id,
                                            x_party_number,
                                            x_profile_id,
                                            l_return_status,
                                            l_msg_count,
                                            l_msg_data);
               IF l_return_status != apps.fnd_api.g_ret_sts_success THEN
                  dbms_output.put_line('Create ' ||
                                       substr(l_msg_data, 240));
                  dbms_output.put_line('l_msg_count ' || l_msg_count);
                  fnd_msg_pub.get(p_msg_index     => -1,
                                  p_encoded       => 'F',
                                  p_data          => l_msg_data,
                                  p_msg_index_out => l_msg_index_out);
                  dbms_output.put_line(l_return_status);
                  dbms_output.put_line('Create ' ||
                                       substr(l_msg_data, 240));
               ELSE
                  --Create RelationShip Between Contact And Organization   
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
               
                  IF v_contact_status <> 'S' THEN
                     ROLLBACK;
                     dbms_output.put_line(v_contact_status);
                     dbms_output.put_line('Create_Person ' ||
                                          substr(v_contact_error, 240));
                  ELSE
                     fnd_msg_pub.initialize;
                     -- Create Role
                     l_init_msg_list := NULL;
                     l_msg_count     := NULL;
                     l_msg_data      := NULL;
                     x_party_number  := NULL;
                     l_return_status := NULL;
                     -- If i.contact_site_id = -1 Then 
                     v_cust_acct_site_id := NULL;
                     /*Else
                      v_cust_acct_site_id := i.account_site_id;
                     End If; */
                     --Create Role - It will Create The Contact Details( For Site Put cust_acct_site_id. For Account Don't Put cust_acct_site_id) 
                     p_cr_cust_acc_role_rec.party_id        := v_contact_party;
                     p_cr_cust_acc_role_rec.cust_account_id := v_cust_account_id;
                     --    p_cr_cust_acc_role_rec.primary_flag := 'N'; 
                     p_cr_cust_acc_role_rec.role_type := 'CONTACT';
                     --   p_cr_cust_acc_role_rec.cust_acct_site_id  := v_cust_acct_site_id;
                     p_cr_cust_acc_role_rec.created_by_module := 'HR API';
                  
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
                        dbms_output.put_line('Create Role :' ||
                                             l_return_status || ' Error: ' ||
                                             substr(l_msg_data, 1, 240));
                        ROLLBACK;
                     ELSE
                        IF i.phone IS NOT NULL AND v_contact_status = 'S' THEN
                           --  dbms_output.put_line(i.customer_cyborg_id||' '||i.Phone_Number);
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
                              dbms_output.put_line(v_contact_status);
                              dbms_output.put_line('Update_Contact_Details Phone' ||
                                                   substr(v_contact_error,
                                                          240));
                           END IF;
                        END IF; --Phone Exist  
                     
                        IF i.email IS NOT NULL AND v_contact_status = 'S' THEN
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
                              dbms_output.put_line(v_contact_status);
                              dbms_output.put_line('Update_Contact_Details Mail' ||
                                                   substr(v_contact_error,
                                                          240));
                           END IF; --Update Mail      
                        END IF; -- Mail Exist 
                     END IF;
                  END IF;
               END IF;
               UPDATE xxobjt_conv_contacts a
                  SET a.ERROR_CODE    = nvl(l_return_status,
                                            v_contact_status),
                      a.error_message = nvl(l_msg_data, v_contact_error)
                WHERE a.organization_name = i.organization_name;
               COMMIT;
               --  commit;   
               v_customer_cyborg := v_cust_account_id;
               v_multi_contact   := i.contact_first_name;
               --End If;
            END IF; --Customer Not Exist
         ELSE
            -- No Need To Create Again The Contact Only Connect It To The Organization/Site
            --If i.cust_account_id <> v_customer_cyborg Then
            v_contact_party := NULL;
         
            x_party_id := NULL;
         
            BEGIN
               SELECT hp.party_id, hc.cust_account_id
                 INTO v_party_id, v_cust_account_id
                 FROM hz_parties hp, hz_cust_accounts hc
                WHERE hp.party_name = i.organization_name AND
                      hp.party_id = hc.party_id;
            EXCEPTION
               WHEN no_data_found THEN
                  v_party_id := NULL;
            END;
         
            IF v_party_id IS NULL THEN
               UPDATE xxobjt_conv_contacts a
                  SET a.ERROR_CODE    = 'E',
                      a.error_message = 'Customer Does Not Exist'
                WHERE a.organization_name = i.organization_name;
               COMMIT;
            ELSE
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
            
               IF v_contact_status <> 'S' THEN
                  ROLLBACK;
               ELSE
                  fnd_msg_pub.initialize;
                  -- Create Role
                  l_init_msg_list := NULL;
                  --l_return_status  := null;
                  l_msg_count     := NULL;
                  l_msg_data      := NULL;
                  x_party_number  := NULL;
                  l_return_status := NULL;
                  --If i.contact_site_id = -1 Then 
                  v_cust_acct_site_id := NULL;
                  /* Else
                   v_cust_acct_site_id := i.account_site_id;
                  End If; */
                  --          dbms_output.put_line('Site '||v_cust_acct_site_id); 
                  --Create Role - It will Create The Contact Details( For Site Put cust_acct_site_id. For Account Don't Put cust_acct_site_id) 
                  p_cr_cust_acc_role_rec.party_id        := v_contact_party;
                  p_cr_cust_acc_role_rec.cust_account_id := v_cust_account_id;
                  --p_cr_cust_acc_role_rec.primary_flag := 'N'; 
                  p_cr_cust_acc_role_rec.role_type := 'CONTACT';
                  --   p_cr_cust_acc_role_rec.cust_acct_site_id  := v_cust_acct_site_id;
                  p_cr_cust_acc_role_rec.created_by_module := 'HR API';
               
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
                     dbms_output.put_line('Create Role2 :' || l_msg_data);
                     ROLLBACK;
                  ELSE
                     IF i.phone IS NOT NULL AND v_contact_status = 'S' THEN
                        --  dbms_output.put_line(i.customer_cyborg_id||' '||i.Phone_Number);
                        update_contact_details(i.area_code,
                                               i.country_code,
                                               i.phone,
                                               i.extention,
                                               'TEL',
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
                     END IF; --Phone Exist  
                  
                     IF i.email IS NOT NULL AND v_contact_status = 'S' THEN
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
                     END IF; -- Mail Exist 
                  END IF;
               END IF;
               UPDATE xxobjt_conv_contacts a
                  SET a.ERROR_CODE    = nvl(l_return_status,
                                            v_contact_status),
                      a.error_message = nvl(l_msg_data, v_contact_error)
                WHERE a.organization_name = i.organization_name;
               COMMIT;
               --    v_customer_cyborg := i.cust_account_id; 
               v_multi_contact := i.contact_first_name;
            END IF;
         END IF;
         --Commit;                              
      END LOOP;
   END create_party_person;
   
Procedure Split_First_Last_Name 
Is
  Cursor cr_Persons Is
    Select *
      From hz_parties hp
     Where hp.party_type = 'PERSON'
       and hp.person_last_name is null
       --and hp.person_first_name like 'F.%'
     ;
  p_upd_person           hz_party_v2pub.person_rec_type;
  l_init_msg_list        NUMBER;
  l_return_status        VARCHAR2(2000);
  l_msg_count            NUMBER;
  l_msg_data             VARCHAR2(2000);
  l_msg_index_out        NUMBER;
  l_profile_id           NUMBER ;
  l_objectVersion        NUMBER := 1;
  
  Procedure cut_First_Last_Names (P_Contact_Name in varchar2, P_Contact_FirstName out varchar2, P_Contact_LastName out varchar2) 
  Is
    v_lastSpace                  number(5);
    v_nameLen                    number(5) := length(P_Contact_Name);
  Begin
    For i in 1..v_nameLen loop
        If substr(P_Contact_Name, i, 1) = ' ' then
           v_lastSpace := i;
        End if;
    End loop;
    P_Contact_FirstName := substr(P_Contact_Name, 1, v_lastSpace - 1);
    P_Contact_LastName  := substr(P_Contact_Name, v_lastSpace + 1, v_nameLen);
  End cut_First_Last_Names;
Begin
  fnd_global.APPS_INITIALIZE(user_id => 1151, resp_id => 50623, resp_appl_id => 660);
  For i in cr_Persons loop
      l_init_msg_list  := null;
      l_return_status  := null;
      l_msg_count      := null;
      l_msg_data       := null;
      l_msg_index_out  := null;
      HZ_PARTY_V2PUB.get_person_rec(p_party_id => i.party_id,
                                    x_person_rec => p_upd_person,
                                    x_return_status => l_return_status,
                                    x_msg_count => l_msg_count,
                                    x_msg_data => l_msg_data
                                   );
      IF l_return_status != apps.fnd_api.g_ret_sts_success THEN
         dbms_output.put_line('Get ' ||substr(l_msg_data, 240));
         dbms_output.put_line('l_msg_count ' || l_msg_count);
         fnd_msg_pub.get(p_msg_index     => -1,
                         p_encoded       => 'F',
                         p_data          => l_msg_data,
                         p_msg_index_out => l_msg_index_out);
         dbms_output.put_line(l_return_status);
      ELSE
         --p_upd_person.party_rec.status := 'A';
         cut_First_Last_Names(p_upd_person.person_first_name, p_upd_person.person_first_name, p_upd_person.person_last_name);
         l_objectVersion := i.object_version_number;
         HZ_PARTY_V2PUB.update_person(p_person_rec => p_upd_person,
                                      p_party_object_version_number => l_objectVersion,
                                      x_profile_id => l_profile_id,
                                      x_return_status => l_return_status,
                                      x_msg_count => l_msg_count,
                                      x_msg_data => l_msg_data
                                     );
         IF l_return_status != apps.fnd_api.g_ret_sts_success THEN
            dbms_output.put_line('Set ' ||substr(l_msg_data, 240));
            dbms_output.put_line('l_msg_count ' || l_msg_count);
            fnd_msg_pub.get(p_msg_index     => -1,
                            p_encoded       => 'F',
                            p_data          => l_msg_data,
                            p_msg_index_out => l_msg_index_out);
            dbms_output.put_line(l_return_status);
         END IF;                             
      END IF;                             
  End loop;
End Split_First_Last_Name;

END xxconv_create_contacts_pkg;
/

