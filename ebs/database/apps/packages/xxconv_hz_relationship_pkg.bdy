CREATE OR REPLACE PACKAGE BODY xxconv_hz_relationship_pkg IS

   PROCEDURE create_cust_acct_rel(errbuf  out varchar2,
                               retcode out varchar2) IS
/*      l_return_status VARCHAR2(2000);
      l_msg_count     NUMBER;
      l_msg_data      VARCHAR2(2000);
      l_data          VARCHAR2(1000);
      l_msg_index_out NUMBER;
   
      l_relation_type        ar_lookups.lookup_code%TYPE;
      l_rel_cust_acct_id     hz_cust_accounts.cust_account_id%TYPE;
 */
      l_user_id            NUMBER;
      l_org_id             NUMBER;
      l_objet_account_id   NUMBER;
      l_subjet_account_id  NUMBER;
      invalid_relationship EXCEPTION;

      l_return_status  VARCHAR2(2000);
      l_msg_count      NUMBER;
      l_msg_data       VARCHAR2(2000);
      l_data           VARCHAR2(1000);
      l_msg_index_out  NUMBER;
 
      l_cust_acct_relate_rec hz_cust_account_v2pub.cust_acct_relate_rec_type;
   
      CURSOR cr_Account_Relationships IS
         SELECT *
           FROM xxobjt.xxobjt_conv_hz_relations
          WHERE relation_type = 'ACCOUNT' AND
                return_status = 'N';

   BEGIN
     errbuf  := null;
     retcode := 0;
      -- Initialization Fields
      SELECT user_id
        INTO l_user_id
        FROM fnd_user
       WHERE user_name = 'CONVERSION';
      fnd_global.apps_initialize(user_id      => l_user_id,
                                 resp_id      => 50623,
                                 resp_appl_id => 660);

      For crAcct in cr_Account_Relationships Loop
          Begin -- Of The Loop
            BEGIN
               SELECT organization_id
                 INTO l_org_id
                 FROM hr_operating_units
                WHERE NAME = crAcct.operating_unit;
            
               mo_global.set_org_access(p_org_id_char     => l_org_id,
                                        p_sp_id_char      => NULL,
                                        p_appl_short_name => 'AR');
            
            EXCEPTION
               WHEN OTHERS THEN
                  l_msg_data := 'Invalid operating unit';
                  RAISE invalid_relationship;
            END;
         
            BEGIN
              SELECT min(hca.cust_account_id)
                INTO l_objet_account_id
                FROM hz_cust_accounts hca, hz_parties hp
               WHERE hca.party_id = hp.party_id AND
                     hp.party_name = crAcct.party_object_name;
              If l_objet_account_id is null then
                  l_msg_data := 'Invalid object party Account';
                  RAISE invalid_relationship;
              End if;                 
            EXCEPTION
               WHEN OTHERS THEN
                  l_msg_data := 'Invalid object party Account';
                  RAISE invalid_relationship;
            END;
         
            BEGIN
              SELECT min(hca.cust_account_id)
                INTO l_subjet_account_id
                FROM hz_cust_accounts hca, hz_parties hp
               WHERE hca.party_id = hp.party_id AND
                     hp.party_name = crAcct.party_subject_name;
              If l_subjet_account_id is null then
                  l_msg_data := 'Invalid Subjet party Account';
                  RAISE invalid_relationship;
              End if;                 
            EXCEPTION
               WHEN OTHERS THEN
                  l_msg_data := 'Invalid subject Party Account';
                  RAISE invalid_relationship;
            END;
            l_cust_acct_relate_rec.cust_account_id          := l_subjet_account_id;-- Was Changed On 23-Aug-09 By AviH. Was: l_objet_account_id;
            l_cust_acct_relate_rec.related_cust_account_id  := l_objet_account_id; -- Was Changed On 23-Aug-09 By AviH. Was: l_subjet_account_id;
            l_cust_acct_relate_rec.relationship_type        := 'ALL';
            l_cust_acct_relate_rec.created_by_module        := 'ONT_UI_ADD_CUSTOMER';
            l_cust_acct_relate_rec.comments                 := NULL;
            l_cust_acct_relate_rec.bill_to_flag             := crAcct.Bill_To;
            l_cust_acct_relate_rec.ship_to_flag             := crAcct.Ship_To;
            l_cust_acct_relate_rec.customer_reciprocal_flag := crAcct.Reciprocal;
         
            hz_cust_account_v2pub.create_cust_acct_relate(p_init_msg_list        => 'T',
                                                          p_cust_acct_relate_rec => l_cust_acct_relate_rec,
                                                          x_return_status        => l_return_status,
                                                          x_msg_count            => l_msg_count,
                                                          x_msg_data             => l_msg_data);
                                                          
            IF l_return_status <> fnd_api.g_ret_sts_success THEN
            
               FOR i IN 1 .. l_msg_count LOOP
                  fnd_msg_pub.get(p_msg_index     => i,
                                  p_data          => l_data,
                                  p_encoded       => fnd_api.g_false,
                                  p_msg_index_out => l_msg_index_out);
               
                  fnd_file.put_line(fnd_file.log, 'l_Data - ' || l_data);
                  l_msg_data := l_msg_data || l_data;
               END LOOP;
               RAISE invalid_relationship;
            END IF;
            -- Succedeed API
            UPDATE xxobjt.xxobjt_conv_hz_relations t
               SET t.return_status = 'S', t.error_message = NULL
             WHERE t.relation_type = crAcct.relation_type AND
                   t.party_subject_name = crAcct.party_subject_name AND
                   t.party_object_name = crAcct.party_object_name AND
                   t.return_status = 'N';
         
         EXCEPTION -- Of The Loop
            WHEN invalid_relationship THEN
               UPDATE xxobjt.xxobjt_conv_hz_relations t
                  SET t.return_status = 'E', t.error_message = l_msg_data
                WHERE t.relation_type = crAcct.relation_type AND
                      t.party_subject_name = crAcct.party_subject_name AND
                      t.party_object_name = crAcct.party_object_name AND
                      t.return_status = 'N';
            
            WHEN OTHERS THEN
               l_msg_data := SQLERRM;
               UPDATE xxobjt.xxobjt_conv_hz_relations t
                  SET t.return_status = 'E', t.error_message = l_msg_data
                WHERE t.relation_type = crAcct.relation_type AND
                      t.party_subject_name = crAcct.party_subject_name AND
                      t.party_object_name = crAcct.party_object_name AND
                      t.return_status = 'N';
         END;
      End loop;

      /*         IF p_rel_customer IS NOT NULL THEN
         BEGIN
            SELECT hca.cust_account_id
              INTO l_rel_cust_acct_id
              FROM hz_cust_accounts hca, hz_parties hp
             WHERE hca.party_id = hp.party_id AND
                   hp.party_name = p_rel_customer;
         
            SELECT lookup_code
              INTO l_relation_type
              FROM ar_lookups
             WHERE lookup_type = 'RELATIONSHIP_TYPE' AND
                   enabled_flag = 'Y';
         
            l_cust_acct_relate_rec.cust_account_id          := p_cust_account_id;
            l_cust_acct_relate_rec.related_cust_account_id  := l_rel_cust_acct_id;
            l_cust_acct_relate_rec.relationship_type        := l_relation_type;
            l_cust_acct_relate_rec.created_by_module        := 'ONT_UI_ADD_CUSTOMER';
            l_cust_acct_relate_rec.comments                 := NULL;
            l_cust_acct_relate_rec.bill_to_flag             := 'Y';
            l_cust_acct_relate_rec.ship_to_flag             := 'Y';
            l_cust_acct_relate_rec.customer_reciprocal_flag := 'Y';
         
            hz_cust_account_v2pub.create_cust_acct_relate(p_init_msg_list        => 'T',
                                                          p_cust_acct_relate_rec => l_cust_acct_relate_rec,
                                                          x_return_status        => l_return_status,
                                                          x_msg_count            => l_msg_count,
                                                          x_msg_data             => l_msg_data);
            IF l_return_status <> fnd_api.g_ret_sts_success THEN
               ROLLBACK;
               fnd_file.put_line(fnd_file.log,
                                 'Creation of Relationship' ||
                                 p_rel_customer || ' is failed.');
               fnd_file.put_line(fnd_file.log,
                                 'x_msg_count = ' || to_char(l_msg_count));
               fnd_file.put_line(fnd_file.log,
                                 'x_msg_data = ' || l_msg_data);
               FOR i IN 1 .. l_msg_count LOOP
                  fnd_msg_pub.get(p_msg_index     => i,
                                  p_data          => l_data,
                                  p_encoded       => fnd_api.g_false,
                                  p_msg_index_out => l_msg_index_out);
                  fnd_file.put_line(fnd_file.log, 'l_Data - ' || l_data);
               END LOOP;
            ELSE
               rec_success(p_run_number  => p_run_id,
                           p_line_number => p_line_number,
                           p_message     => 'Created relation for customer ' ||
                                            p_rel_customer);
               COMMIT;
            END IF;
         EXCEPTION
            WHEN OTHERS THEN
               rec_error(p_run_number        => p_run_id,
                         p_line_number       => p_line_number,
                         p_error_explanation => 'Invalid relationship - ' ||
                                                p_rel_customer,
                         p_error_value       => p_field_name,
                         p_error_code        => 'E');
         END;
      END IF;*/
   
      NULL;
   END create_cust_acct_rel;

   PROCEDURE create_end_customer_rel(errbuf  out varchar2,
                                  retcode out varchar2) IS
   
      CURSOR csr_end_cust_relationships IS
         SELECT *
           FROM xxobjt.xxobjt_conv_hz_relations
          WHERE relation_type = 'END CUSTOMER' AND
                return_status = 'N';
   
      cur_relationship csr_end_cust_relationships%ROWTYPE;
      l_return_status  VARCHAR2(2000);
      l_msg_count      NUMBER;
      l_msg_data       VARCHAR2(2000);
      l_data           VARCHAR2(1000);
      l_msg_index_out  NUMBER;
   
      --l_relation_type ar_lookups.lookup_code%TYPE;
      t_rel_rec       hz_relationship_v2pub.relationship_rec_type;
   
      l_relationship_id NUMBER;
      l_party_id        NUMBER;
      l_party_number    VARCHAR2(80);
   
      l_user_id         NUMBER;
      l_org_id          NUMBER;
      l_objet_party_id  NUMBER;
      l_subjet_party_id NUMBER;
      invalid_relationship EXCEPTION;
   
   BEGIN
     errbuf  := null;
     retcode := 0;
     
      SELECT user_id
        INTO l_user_id
        FROM fnd_user
       WHERE user_name = 'CONVERSION';
   
      fnd_global.apps_initialize(user_id      => l_user_id,
                                 resp_id      => 50623,
                                 resp_appl_id => 660);
   
      FOR cur_relationship IN csr_end_cust_relationships LOOP
      
         BEGIN
         
            BEGIN
               SELECT organization_id
                 INTO l_org_id
                 FROM hr_operating_units
                WHERE NAME = cur_relationship.operating_unit;
            
               mo_global.set_org_access(p_org_id_char     => l_org_id,
                                        p_sp_id_char      => NULL,
                                        p_appl_short_name => 'AR');
            
            EXCEPTION
               WHEN OTHERS THEN
                  l_msg_data := 'Invalid operating unit';
                  RAISE invalid_relationship;
            END;
         
            BEGIN
               SELECT party_id
                 INTO l_objet_party_id
                 FROM hz_parties
                WHERE party_name = cur_relationship.party_object_name
                  AND party_type = 'ORGANIZATION' -- AviH Addition On 18-Aug-09
                  and created_by_module = 'TCA_V1_API'
                ;
            EXCEPTION
               WHEN OTHERS THEN
                  l_msg_data := 'Invalid object party';
                  RAISE invalid_relationship;
            END;
         
            BEGIN
               SELECT party_id
                 INTO l_subjet_party_id
                 FROM hz_parties
                WHERE party_name = cur_relationship.party_subject_name
                  AND party_type = 'ORGANIZATION' -- AviH Addition On 18-Aug-09
                  and created_by_module = 'TCA_V1_API'
                ;
            EXCEPTION
               WHEN OTHERS THEN
                  l_msg_data := 'Invalid subject party';
                  RAISE invalid_relationship;
            END;
         
            t_rel_rec.subject_id          := l_subjet_party_id; 
            t_rel_rec.subject_type        := 'ORGANIZATION';
            t_rel_rec.subject_table_name  := 'HZ_PARTIES';
            t_rel_rec.object_id           := l_objet_party_id; -- Was Changed On 23-Aug-09 By AviH. Was: l_objet_party_id;
            t_rel_rec.object_type         := 'ORGANIZATION';
            t_rel_rec.object_table_name   := 'HZ_PARTIES';
            t_rel_rec.relationship_code   := 'CUSTOMER_INDIRECTLY_MANAGED_BY';
            t_rel_rec.relationship_type   := 'PARTNER_MANAGED_CUSTOMER';
            t_rel_rec.content_source_type := 'USER_ENTERED';
            t_rel_rec.created_by_module   := 'HZ_CPUI';
            t_rel_rec.start_date          := SYSDATE;
            t_rel_rec.status              := 'A';
         
            -- here's the delegated call to the old PL/SQL routine
            hz_relationship_v2pub.create_relationship(p_init_msg_list    => fnd_api.g_true,
                                                      p_relationship_rec => t_rel_rec,
                                                      x_relationship_id  => l_relationship_id,
                                                      x_party_id         => l_party_id,
                                                      x_party_number     => l_party_number,
                                                      x_return_status    => l_return_status,
                                                      x_msg_count        => l_msg_count,
                                                      x_msg_data         => l_msg_data);
         
            IF l_return_status <> fnd_api.g_ret_sts_success THEN
            
               FOR i IN 1 .. l_msg_count LOOP
                  fnd_msg_pub.get(p_msg_index     => i,
                                  p_data          => l_data,
                                  p_encoded       => fnd_api.g_false,
                                  p_msg_index_out => l_msg_index_out);
               
                  fnd_file.put_line(fnd_file.log, 'l_Data - ' || l_data);
                  l_msg_data := l_msg_data || l_data;
               END LOOP;
            
               RAISE invalid_relationship;
            
            END IF;
         
            UPDATE xxobjt.xxobjt_conv_hz_relations t
               SET t.return_status = 'S', t.error_message = NULL
             WHERE t.relation_type = cur_relationship.relation_type AND
                   t.party_subject_name = cur_relationship.party_subject_name AND
                   t.party_object_name = cur_relationship.party_object_name AND
                   t.return_status = 'N';
         
         EXCEPTION
            WHEN invalid_relationship THEN
               UPDATE xxobjt.xxobjt_conv_hz_relations t
                  SET t.return_status = 'E', t.error_message = l_msg_data
                WHERE t.relation_type = cur_relationship.relation_type AND
                      t.party_subject_name = cur_relationship.party_subject_name AND
                      t.party_object_name = cur_relationship.party_object_name AND
                      t.return_status = 'N';
            
            WHEN OTHERS THEN
               l_msg_data := SQLERRM;
               UPDATE xxobjt.xxobjt_conv_hz_relations t
                  SET t.return_status = 'E', t.error_message = l_msg_data
                WHERE t.relation_type = cur_relationship.relation_type AND
                      t.party_subject_name = cur_relationship.party_subject_name AND
                      t.party_object_name = cur_relationship.party_object_name AND
                      t.return_status = 'N';
         END;
      END LOOP;
   
   END create_end_customer_rel;

Procedure Mark_Duplicates (P_relation_type in Varchar2)
Is
  Cursor cr_dup is
    Select a.relation_type, a.party_subject_name, a.party_object_name, a.operating_unit, a.relation_name,
           a.reciprocal, a.bill_to, a.ship_to, count(*)
      From xxobjt.xxobjt_conv_hz_relations a
     Where relation_type = P_relation_type
     Group by a.relation_type, a.party_subject_name, a.party_object_name, a.operating_unit, a.relation_name,
           a.reciprocal, a.bill_to, a.ship_to
     Having count(*) > 1;
     
  Cursor cr_SiteIdent (PC_relation_type in varchar2, 
                       PC_party_subject_name in varchar2, 
                       PC_party_object_name in varchar2, 
                       PC_operating_unit in varchar2, 
                       PC_relation_name in varchar2,
                       PC_reciprocal in varchar2, 
                       PC_bill_to in varchar2, 
                       PC_ship_to in varchar2) is
    Select a.site
      From xxobjt.xxobjt_conv_hz_relations a
     Where relation_type = PC_relation_type
       and party_subject_name = PC_party_subject_name
       and party_object_name = PC_party_object_name
       and operating_unit = PC_operating_unit
       and nvl(relation_name, '@@') = nvl(PC_relation_name, '@@')
       and nvl(reciprocal, '@') = nvl(PC_reciprocal, '@')
       and nvl(bill_to, '@') = nvl(PC_bill_to, '@')
       and nvl(ship_to, '@') = nvl(PC_ship_to, '@')
      For update of return_status, error_message;
      
    v_counter number := 0;
Begin
    For Dup in cr_dup loop
        v_counter := 0;
        For Sites in cr_SiteIdent(dup.relation_type, dup.party_subject_name, dup.party_object_name, dup.operating_unit,
                     dup.relation_name, dup.reciprocal, dup.bill_to, dup.ship_to) loop
            v_counter := v_counter + 1;
            If v_counter > 1 then
               Update xxobjt.xxobjt_conv_hz_relations
                  Set return_status = 'D', error_message = 'Duplicate Party Record'
                Where current of cr_SiteIdent;
            End if;
        End loop;
    End loop;
End Mark_Duplicates;

END xxconv_hz_relationship_pkg;
/
