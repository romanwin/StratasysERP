CREATE OR REPLACE PACKAGE BODY xxconv_crm_sr_api_pkg IS
  --v_user_id                fnd_user.user_id%type;
  g_user_id      NUMBER;
  g_resp_id      NUMBER := 50019;
  g_resp_appl_id NUMBER := 512;
  -- Important Remark
  --For SRs with Status = Complete / Cancelled / Closed FSR - Please convert all charge lines with status SUBMITTED
  --And - OM Interface flag as N'

  PROCEDURE insert_api_sr(errbuf            OUT VARCHAR2,
                          retcode           OUT VARCHAR2,
                          p_validation_only IN VARCHAR2) IS
  
    v_unexpected_error_cnt NUMBER := 0;
    v_valid_errors_counter NUMBER := 0;
   ---- v_sr_without_contracts NUMBER := 0;
   ---- v_sr_with_1_contract   NUMBER := 0;
   ---- v_sr_with_2_contract   NUMBER := 0;
    
    v_sr_success_created_cnt     NUMBER:=0;
    v_sr_creation_failured_cnt   NUMBER:=0;
  
    v_created_notes_list       VARCHAR2(3000);
    v_created_charges_list     VARCHAR2(3000);
    v_created_escalations_list VARCHAR2(3000);
  
    v_step      VARCHAR2(100);
    p_sr_record cs_servicerequest_pub.service_request_rec_type;
    x_sr_record cs_servicerequest_pub.sr_create_out_rec_type;
    t_notes     cs_servicerequest_pub.notes_table;
    t_contacts  cs_servicerequest_pub.contacts_table;
    ---l_task_rec_in           jtf_tasks_pub.task_rec;
    l_ent_contracts  cs_cont_get_details_pvt.ent_contract_tab;
    t_charges_rec    cs_charge_details_pub.charges_rec_type;
    p_sr_record_miss cs_servicerequest_pub.service_request_rec_type;
    ---t_notes_miss            cs_servicerequest_pub.notes_table;
    t_contacts_miss cs_servicerequest_pub.contacts_table;
    ---t_charges_rec_miss      cs_charge_details_pub.charges_rec_type;
    l_transaction_type_id NUMBER;
    l_txn_billing_type_id NUMBER;
    return_status         VARCHAR2(200) := NULL;
    msg_count             NUMBER;
    msg_data              VARCHAR2(4000);
    ---x_request_id            NUMBER;
    l_msg_count                NUMBER;
    l_msg_data                 VARCHAR2(4000) := NULL;
    l_contact_index            NUMBER;
    l_msg_index_out            VARCHAR2(2000) := 0;
    v_counter                  NUMBER := 0;
    v_note_counter             NUMBER(10);
    l_init_msg_list            NUMBER;
    l_return_status            VARCHAR2(2000);
    l_commit                   VARCHAR2(5);
    l_validation_level         NUMBER;
    v_estimate_detail_id       NUMBER(10);
    v_line_number              NUMBER(10);
    v_resource_id              NUMBER(10);
    v_resource_type            VARCHAR2(30);
    v_type_id                  NUMBER(10);
    v_group_id                 NUMBER(10);
    v_status_id                NUMBER(10);
    v_severity_id              NUMBER(10);
    v_urgency_id               NUMBER(10);
    v_business_process_id      NUMBER;
    l_business_process_id_file NUMBER;
    l_rec_count                NUMBER;
  
    v_item_id             NUMBER;
    v_item_rev            VARCHAR2(20);
    v_organization_id     NUMBER;
    v_loc_type_code       VARCHAR2(30);
    v_loc_id              NUMBER;
    v_party_id            NUMBER;
    v_customer_id         NUMBER;
    v_problem_code        VARCHAR2(30);
    v_instance_id         NUMBER;
    v_instance_num        VARCHAR2(30);
    v_system_id           NUMBER;
    v_bill_to_site_id     NUMBER;
    v_bill_to_site_use_id NUMBER;
    v_bill_account_id     NUMBER;
    v_bill_to_party_id    NUMBER;
    v_ship_to_site_id     NUMBER;
    v_ship_to_site_use_id NUMBER;
    v_ship_account_id     NUMBER;
    v_ship_to_party_id    NUMBER;
    v_category_id         NUMBER;
    v_install_loc_id      NUMBER;
    v_location_id         NUMBER;
  
    v_external_attribute_1    VARCHAR2(240);
    v_external_attribute_3    VARCHAR2(240);
    v_external_attribute_4    VARCHAR2(240);
    v_external_attribute_11   VARCHAR2(240);
  
    v_jtf_note_id             NUMBER; --api out
    ----v_escalation_id NUMBER; --api out
  
    v_resp_appl_id               NUMBER;
    v_resp_id                    NUMBER;
    -----v_user_id                    NUMBER;
    v_inventory_organization_id  NUMBER;
  
    x_timezone_id   NUMBER;
    x_timezone_name VARCHAR2(50);
    
    
    -------------------------------------------------------------------------
  -- Record and table type descriptions for Escalation API
  -------------------------------------------------------------------------
  l_esc_rec            jtf_ec_pub.esc_rec_type;
  l_esc_ref_docs       jtf_ec_pub.esc_ref_docs_tbl_type;
  l_esc_contacts       jtf_ec_pub.esc_contacts_tbl_type;
  l_esc_cont_phones    jtf_ec_pub.esc_cont_points_tbl_type;
  l_esc_task_id        JTF_TASKS_VL.TASK_ID%TYPE;
  l_esc_task_number    JTF_TASKS_VL.TASK_NUMBER%TYPE;
  l_wf_process_id      NUMBER;
  ---l_msg                FND_NEW_MESSAGES.MESSAGE_TEXT%TYPE;
  ----l_msg_name           FND_NEW_MESSAGES.MESSAGE_NAME%TYPE;
  ---l_short_name         VARCHAR2(80);
  l_user_id            number := to_number(fnd_profile.value('USER_ID'));
  
  
  
    --Call Temp Table For Inserting Date Into API
    CURSOR csr_sr_incidents IS
      SELECT *
        FROM xxobjt_conv_crm_incidents sr
       WHERE sr.status = 'N'
       AND ROWNUM <= 1000; ---FOR DEBUGGING ONLY
  
    CURSOR csr_sr_notes(p_helpdesk_number IN VARCHAR2) IS
      SELECT *
        FROM xxobjt_conv_crm_notes n
       WHERE n.helpdesk_number = p_helpdesk_number ---parameter
         AND note IS NOT NULL
       ORDER BY entered_date;
  
    CURSOR csr_sr_contacts(p_helpdesk_number IN VARCHAR2) IS
      SELECT *
        FROM xxobjt_conv_crm_contacts c
       WHERE c.helpdesk_number = p_helpdesk_number; ---parameter
  
    CURSOR csr_sr_charges(p_helpdesk_number IN VARCHAR2) IS
      SELECT *
        FROM xxobjt_conv_crm_charges c
       WHERE c.helpdesk_number = p_helpdesk_number ---parameter
       ORDER BY c.line_number;
  
    CURSOR get_external_attribute_11(p_helpdesk_number IN VARCHAR2) IS
      SELECT c.external_attribute_11
        FROM xxobjt_conv_crm_contacts c
       WHERE c.helpdesk_number = p_helpdesk_number;
  
    CURSOR csr_contact_roles(p_rel_party_id VARCHAR2) IS
      SELECT C_TAB.party_id,
             C_TAB.contact_point_id,
             C_TAB.contact_point_type,
             CASE
               WHEN C_TAB.ord_field = C_TAB.min_ord_field THEN
                'Y'
               ELSE
                'N'
             END primary_flag,
             C_TAB.contact_type,
             C_TAB.party_role_code
        FROM (SELECT CONTACT_TAB.party_id,
                     CONTACT_TAB.contact_point_id,
                     CONTACT_TAB.contact_point_type,
                     CONTACT_TAB.primary_flag,
                     CONTACT_TAB.contact_type,
                     CONTACT_TAB.party_role_code,
                     CONTACT_TAB.ord_field,
                     MIN(CONTACT_TAB.ord_field) OVER(PARTITION BY CONTACT_TAB.contact_type
                     ----- ORDER BY CONT_TAB.contact_point_type_ord_field, CONT_TAB.primary_flag_ord_field
                      ) min_ord_field
                FROM (SELECT CONT_TAB.party_id,
                             CONT_TAB.contact_point_id,
                             CONT_TAB.contact_point_type,
                             CONT_TAB.primary_flag,
                             CONT_TAB.contact_type,
                             CONT_TAB.party_role_code,
                             ROW_NUMBER() OVER( ----PARTITION BY deptno 
                             ORDER BY CONT_TAB.contact_point_type_ord_field, CONT_TAB.primary_flag_ord_field) ord_field
                        FROM (SELECT hr.party_id,
                                     hcp.contact_point_id,
                                     hcp.contact_point_type,
                                     hcp.primary_flag,
                                     'PARTY_RELATIONSHIP' contact_type,
                                     'CONTACT' party_role_code,
                                     DECODE(hcp.contact_point_type,
                                            'PHONE',
                                            decode(hcp.phone_line_type,
                                                   'GEN',
                                                   1,
                                                   'MOBILE',
                                                   2,
                                                   4),
                                            'EMAIL',
                                            3,
                                            5) contact_point_type_ord_field,
                                     DECODE(hcp.primary_flag, 'Y', 1, 2) primary_flag_ord_field
                                FROM hz_relationships  hr,
                                     hz_parties        hp_obj, -- Customer Party
                                     hz_parties        hp_sub, -- Contact
                                     hz_contact_points hcp
                               WHERE hr.status = 'A'
                                 AND nvl(hr.start_date, SYSDATE - 1) < SYSDATE
                                 AND nvl(hr.end_date, SYSDATE + 1) > SYSDATE
                                 AND hp_sub.party_id = hr.subject_id
                                 AND hp_sub.status = 'A'
                                 AND hp_sub.party_type = 'PERSON'
                                 AND hp_obj.party_id = hr.object_id
                                 AND hp_obj.status = 'A'
                                 AND hp_obj.party_type = 'ORGANIZATION'
                                 AND hcp.owner_table_id(+) = hr.party_id
                                 AND hcp.owner_table_name(+) = 'HZ_PARTIES'
                                 AND hcp.status(+) = 'A'
                                 AND hr.party_id IS NOT NULL
                                 AND hr.party_id = p_rel_party_id ---parameter
                              ) CONT_TAB) CONTACT_TAB) C_TAB;
  
    cur_incident csr_sr_incidents%ROWTYPE;
    cur_note     csr_sr_notes%ROWTYPE;
    cur_contact  csr_sr_contacts%ROWTYPE;
    cur_charge   csr_sr_charges%ROWTYPE;
  
    invalid_incident EXCEPTION;
    v_numeric_dummy NUMBER;
  
    l_org_id                 NUMBER;
    l_err_msg                VARCHAR2(3000);
    l_category_set_id        NUMBER;
    l_price_list_id          NUMBER;
    l_selling_price          NUMBER;
    l_territory_id           NUMBER;
    l_charge_item_id         NUMBER;
    l_charge_revision        VARCHAR2(3);
    l_contract_number        VARCHAR2(30);
    v_project_number         VARCHAR2(100);
    /* 
      UPDATE xxobjt_conv_crm_incidents sr
      SET    sr.INCIDENT_PRIORITY='Medium',
             sr.status='N',
             RESOURCE_TYPE='RS_EMPLOYEE';
             
    ;
    --------Copy Activity_Type and paste as Billing_Type               
         
      */
  
  BEGIN
  
    v_step := 'Step 1';
  
    l_category_set_id := xxinv_utils_pkg.get_default_category_set_id;
  
    FOR cur_incident IN csr_sr_incidents LOOP
    
      BEGIN
        v_step                     := 'Step 10';
        v_counter                  := v_counter + 1;
        l_return_status            := NULL;
        l_msg_count                := NULL;
        l_msg_data                 := NULL;
        l_err_msg                  := NULL;
        l_business_process_id_file := NULL;
        v_business_process_id      := NULL;
        l_contract_number          := NULL;
        v_external_attribute_11    := NULL;
        v_created_notes_list       := NULL;
        v_created_charges_list     := NULL;
        v_created_escalations_list := NULL;
      
        BEGIN
          v_step := 'Step 20';
          SELECT organization_id
            INTO l_org_id
            FROM hr_operating_units
           WHERE NAME = cur_incident.organization;
          IF l_org_id = 81 THEN
              --- OBJET IL (OU)
              v_resp_appl_id := 514;
              v_resp_id      := 50557; ---'Dispatcher..IL'
              ---v_user_id      := 1130; ---ella.malchi
            ELSIF l_org_id = 89 THEN
              --- OBJET US (OU)
              v_resp_appl_id := 514;
              v_resp_id      := 50558; ---'Dispatcher..US'
              ---v_user_id      := 1130; ---ella.malchi
            ELSIF l_org_id = 103 THEN
              --- OBJET HK (OU)
              v_resp_appl_id := 514;
              v_resp_id      := 50560; ---'Dispatcher..HK'
              ---v_user_id      := 1130; ---ella.malchi
            ELSIF l_org_id = 96 THEN
              --- OBJET DE (OU)
              v_resp_appl_id := 514;
              v_resp_id      := 50559; ---'Dispatcher..DE'
              -----v_user_id      := 1130; ---ella.malchi
            END IF;
            ---
            begin
              fnd_global.APPS_INITIALIZE(user_id      => g_user_id,
                                         resp_id      => v_resp_id,
                                         resp_appl_id => v_resp_appl_id);
              mo_global.set_org_context(p_org_id_char     => l_org_id,
                                        p_sp_id_char      => null,
                                        p_appl_short_name => 'QP');
            end;
        EXCEPTION
          WHEN OTHERS THEN
            l_err_msg := 'Invalid operation unit';
            RAISE invalid_incident;
        END;
        
        v_step := 'Step 25';
        BEGIN
            select  fpov.profile_option_value
            into    v_inventory_organization_id
            from fnd_profile_option_values fpov,
                 fnd_profile_options       fpo
            where fpo.profile_option_name = 'CS_INV_VALIDATION_ORG'
            and   fpo.profile_option_id = fpov.profile_option_id
            and   fpov.level_id = 10003
            and   fpov.level_value = v_resp_id; ---param
                        
        EXCEPTION
          WHEN OTHERS THEN
            v_inventory_organization_id:=91;
        END;
        
        v_step := 'Step 27';
        BEGIN
            select S.NAME
            into v_project_number 
            from csi_systems_tl s,
                 csi_item_instances i
            where s.system_id = i.system_id
            and   i.serial_number = cur_incident.serial_numer 
            and   s.language = 'US';
        EXCEPTION
          WHEN OTHERS THEN
            v_project_number:=null;
        END;
        
        v_step := 'Step 30';
        BEGIN
        
          SELECT g.group_id
            INTO v_group_id
            from jtf_rs_groups_tl g
           where upper(g.group_name) = upper(cur_incident.group_name) --param
             and g.language = 'US';
        
        EXCEPTION
          WHEN OTHERS THEN
            v_group_id := NULL;
            l_err_msg  := 'Invalid Group Name';
            RAISE invalid_incident;
        END;
      
        v_step := 'Step 40';
        BEGIN
          SELECT a.resource_id
            INTO v_resource_id
            FROM jtf_rs_resource_extns a
           WHERE upper(a.source_name) = upper(cur_incident.owner);
        EXCEPTION
          WHEN no_data_found THEN
            l_err_msg := 'Invalid Resource';
            RAISE invalid_incident;
        END;
      
        v_resource_type := 'RS_EMPLOYEE';
        v_step          := 'Step 50';
        BEGIN
          SELECT cit.incident_type_id, cit.business_process_id
            INTO v_type_id, v_business_process_id
            FROM CS_INCIDENT_TYPES_VL cit
           WHERE upper(cit.NAME) = upper(cur_incident.incident_type);
        EXCEPTION
          WHEN no_data_found THEN
            l_err_msg := 'Invalid Incident Type';
            RAISE invalid_incident;
          
        END;
        v_step := 'Step 60';
        BEGIN
          SELECT cis.incident_status_id
            INTO v_status_id
            FROM cs_incident_statuses_vl cis
           WHERE upper(cis.NAME) = upper(cur_incident.incident_status);
        EXCEPTION
          WHEN no_data_found THEN
            l_err_msg := 'Invalid status';
            RAISE invalid_incident;
        END;
        v_step := 'Step 70';
        BEGIN
          SELECT cie.incident_severity_id
            INTO v_severity_id
            FROM cs_incident_severities_vl cie
           WHERE upper(cie.NAME) = upper(cur_incident.incident_severity);
        EXCEPTION
          WHEN no_data_found THEN
            l_err_msg := 'Invalid severity';
            RAISE invalid_incident;
        END;
        v_step := 'Step 80';
        BEGIN
          SELECT ciu.incident_urgency_id
            INTO v_urgency_id
            FROM cs_incident_urgencies_vl ciu
           WHERE upper(ciu.NAME) = upper(cur_incident.incident_priority);
        EXCEPTION
          WHEN no_data_found THEN
            l_err_msg := 'Invalid priority';
            RAISE invalid_incident;
        END;
      
        BEGIN
          v_step := 'Step 90';
          SELECT cii.inventory_item_id,
                 cii.inventory_revision,
                 nvl(cii.inv_organization_id,
                     cii.inv_master_organization_id),
                 cii.install_location_type_code,
                 cii.install_location_id,
                 cii.owner_party_id,
                 cii.owner_party_account_id,
                 cii.instance_id,
                 cii.instance_number,
                 cii.system_id,
                 mic.category_id,
                 cii.install_location_id,
                 cii.location_id
            INTO v_item_id,
                 v_item_rev,
                 v_organization_id,
                 v_loc_type_code,
                 v_loc_id,
                 v_party_id,
                 v_customer_id,
                 v_instance_id,
                 v_instance_num,
                 v_system_id,
                 v_category_id,
                 v_install_loc_id,
                 v_location_id
            FROM csi_item_instances cii, mtl_item_categories mic
           WHERE cii.inventory_item_id = mic.inventory_item_id
             AND cii.inv_master_organization_id = mic.organization_id
             AND mic.category_set_id =
                 xxinv_utils_pkg.get_default_category_set_id
             AND cii.serial_number = cur_incident.serial_numer; ------parameter----------------
        
        EXCEPTION
          WHEN no_data_found THEN
            l_err_msg := 'Invalid serial';
            RAISE invalid_incident;
        END;
        
        
        ------------------Valid install_site_id----------------------------------
        --------(see CS_ServiceRequest_UTIL.Validate_Install_Site proc ) --------
        -------------------------------------------------------------------------
        BEGIN
                SELECT 1
                INTO v_numeric_dummy
                FROM   Hz_Party_Sites s
                WHERE s.party_site_id = v_install_loc_id ---SELECTED VALUE FROM PREVIOUS SELECT
                AND   s.status = 'A'
                and   rownum=1 ---added by Vitaly
            -- Belongs to SR Customer
                AND ( s.party_id = v_party_id   ---SELECTED VALUE FROM PREVIOUS SELECT 
            -- or one of its relationships
                      OR s.party_id IN (
                         SELECT r.party_id
                         FROM   Hz_Relationships r
                         WHERE r.object_id     = v_party_id   ---SELECTED VALUE FROM PREVIOUS SELECT 
                         AND   r.status = 'A'
                         -- Added to remove TCA violation -- Relationship should be active -- anmukher -- 08/14/03
                         AND   TRUNC(SYSDATE) BETWEEN TRUNC(NVL(r.START_DATE, SYSDATE)) AND TRUNC(NVL(r.END_DATE, SYSDATE)) )
                          -- or one of its Related parties
                      OR s.party_id IN (
                         SELECT sub.party_id
                         FROM   Hz_Parties  p,
                                Hz_Parties sub,
                                Hz_Parties obj,
                                Hz_Relationships r
                         WHERE obj.party_id  = v_party_id   ---SELECTED VALUE FROM PREVIOUS SELECT 
                         AND   sub.status = 'A'
                         AND   obj.status = 'A'
                         AND   r.status   = 'A'
                         AND   p.status   = 'A'
                         AND   TRUNC(SYSDATE) BETWEEN TRUNC(NVL(r.START_DATE, SYSDATE)) AND TRUNC(NVL(r.END_DATE, SYSDATE))
                         AND   sub.party_type IN ('PERSON','ORGANIZATION')
                         AND   p.party_id = r.party_id
                         AND   r.object_id = obj.party_id
                         AND   r.subject_id = sub.party_id ));
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            ---selected install_site is invalid...
            v_install_loc_id:=NULL;
        END;
        --------------------------------------------
      
        BEGIN
          v_step := 'Step 100';
          SELECT hzsius1.party_site_use_id   ship_to_site_use_id,
                 hzsite1.party_site_id       ship_to_site_id,
                 hzacctsite1.cust_account_id ship_to_account_id,
                 hzpty1.party_id             ship_to_party_id,
                 hzsius3.party_site_use_id   bill_to_site_use_id,
                 hzsite3.party_site_id       bill_to_site_id,
                 hzacctsite3.cust_account_id bill_to_account_id,
                 hzpty3.party_id             bill_to_party_id
            INTO v_ship_to_site_use_id,
                 v_ship_to_site_id,
                 v_ship_account_id,
                 v_ship_to_party_id,
                 v_bill_to_site_use_id,
                 v_bill_to_site_id,
                 v_bill_account_id,
                 v_bill_to_party_id
            FROM csi_item_instances     cii,
                 csi_i_parties          cip,
                 csi_ip_accounts        cia,
                 csi_ipa_relation_types cirt,
                 hz_cust_site_uses_all  hcsu1,
                 hz_cust_acct_sites_all hzacctsite1,
                 hz_party_sites         hzsite1,
                 hz_party_site_uses     hzsius1,
                 hz_locations           hzloc1,
                 hz_parties             hzpty1,
                 hz_party_sites         hzsite2,
                 hz_locations           hzloc2,
                 hz_parties             hzpty2,
                 hz_cust_site_uses_all  hcsu3,
                 hz_cust_acct_sites_all hzacctsite3,
                 hz_party_sites         hzsite3,
                 hz_party_site_uses     hzsius3,
                 hz_locations           hzloc3,
                 hz_parties             hzpty3,
                 hz_cust_accounts       hza,
                 hz_parties             hzp
           WHERE cii.instance_id = cip.instance_id
             AND cip.instance_party_id = cia.instance_party_id
             AND cia.party_account_id = hza.cust_account_id
             AND cia.relationship_type_code = 'OWNER'
             AND cia.active_end_date IS NULL
             AND hza.party_id = hzp.party_id
             AND cia.ship_to_address = hcsu1.site_use_id(+)
             AND hcsu1.cust_acct_site_id = hzacctsite1.cust_acct_site_id(+)
             AND hzacctsite1.party_site_id = hzsite1.party_site_id(+)
             AND hzsite1.location_id = hzloc1.location_id(+)
             AND hzsite1.party_id = hzpty1.party_id(+)
             AND hzsite1.party_site_id = hzsius1.party_site_id(+)
             AND hzsius1.site_use_type(+) = 'SHIP_TO'
             AND cii.install_location_id = hzsite2.party_site_id(+)
             AND hzsite2.location_id = hzloc2.location_id(+)
             AND hzsite2.party_id = hzpty2.party_id(+)
             AND cia.bill_to_address = hcsu3.site_use_id(+)
             AND hcsu3.cust_acct_site_id = hzacctsite3.cust_acct_site_id(+)
             AND hzacctsite3.party_site_id = hzsite3.party_site_id(+)
             AND hzsite3.location_id = hzloc3.location_id(+)
             AND hzsite3.party_id = hzpty3.party_id(+)
             AND hzsite3.party_site_id = hzsius3.party_site_id(+)
             AND hzsius3.site_use_type(+) = 'BILL_TO'
             AND cip.relationship_type_code =
                 cirt.ipa_relation_type_code(+)
             AND cip.party_source_table = 'HZ_PARTIES'
             AND cip.instance_party_id = cia.instance_party_id(+)
             and (hzsius1.end_date is null or hzsius1.end_date > sysdate)
             and  hzsius1.status (+) = 'A'
             and   (hzsite1.end_date_active is null or  hzsite1.end_date_active > sysdate)
             and   hzsite1.status = 'A'
             and   (hzsite2.end_date_active is null or  hzsite2.end_date_active > sysdate)
             and   hzsite2.status = 'A'
             and (hzsius3.end_date is null or hzsius3.end_date > sysdate)
             and  hzsius3.status (+) = 'A'
             AND   (hzsite3.end_date_active is null or  hzsite3.end_date_active > sysdate)
             and    hzsite3.status = 'A'
             AND cii.instance_id = v_instance_id;  ---parameter
        EXCEPTION
          WHEN no_data_found THEN
            v_bill_to_site_id     := NULL;
            v_bill_to_site_use_id := NULL;
            v_bill_account_id     := NULL;
            v_bill_to_party_id    := NULL;
            v_ship_to_site_id     := NULL;
            v_ship_to_site_use_id := NULL;
            v_ship_account_id     := NULL;
            v_ship_to_party_id    := NULL;
          
        END;
      
        v_step := 'Step 110';
        BEGIN
          SELECT lookup_code
            INTO v_problem_code
            FROM fnd_lookup_values_vl
           WHERE lookup_type = 'REQUEST_PROBLEM_CODE'
             AND upper(meaning) = upper(cur_incident.problem_code);
        
        EXCEPTION
          WHEN no_data_found THEN
            l_err_msg := 'Invalid problem code';
            RAISE invalid_incident;
        END;
        IF cur_incident.attribute2 IS NOT NULL THEN
          v_step := 'Step 120';
          BEGIN
            SELECT 1
              INTO v_numeric_dummy
              FROM CS_SR_RES_CODE_MAPPING_DETAIL CSC, FND_LOOKUP_VALUES FLV
             WHERE CSC.CATEGORY_ID =
                   (select mic.category_id
                      from mtl_item_categories mic, csi_item_instances cii
                     where cii.serial_number = cur_incident.serial_numer ------
                       and cii.inventory_item_id = mic.inventory_item_id
                       and mic.organization_id = 91
                       and mic.category_set_id = 1100000041)
               AND FLV.LANGUAGE = 'US'
               AND FLV.LOOKUP_CODE = CSC.RESOLUTION_CODE
               AND FLV.LOOKUP_TYPE = 'REQUEST_RESOLUTION_CODE'
               and (csc.map_end_date_active is null or
                   csc.map_end_date_active > sysdate)
               and (csc.end_date_active is null or
                   csc.end_date_active > sysdate)
               and flv.description = cur_incident.attribute2; ----INCIDENT_ATTRIBUTE_2
          
          EXCEPTION
            WHEN no_data_found THEN
              l_err_msg := 'Invalid INCIDENT_ATTRIBUTE_2 and Serial Number';
              RAISE invalid_incident;
          END;
        END IF;
      
        IF cur_incident.attribute3 IS NOT NULL THEN
          v_step := 'Step 130';
          BEGIN
            SELECT 1
              INTO v_numeric_dummy
              FROM fnd_lookup_values flv2
             WHERE FLV2.lookup_type = 'XXCS_FULL_SUBRESOLUTION1_LU'
               AND flv2.attribute1 = cur_incident.attribute2 ----INCIDENT_ATTRIBUTE_2
               AND flv2.language = 'US'
               AND flv2.description = cur_incident.attribute3; ---INCIDENT_ATTRIBUTE_3
          EXCEPTION
            WHEN no_data_found THEN
              l_err_msg := 'Invalid INCIDENT_ATTRIBUTE_3';
              RAISE invalid_incident;
          END;
        END IF;
      
        v_step := 'Step 140';
        BEGIN
          cs_tz_get_details_pvt.customer_preferred_time_zone(p_incident_id            => NULL,
                                                             p_task_id                => NULL,
                                                             p_resource_id            => NULL,
                                                             p_cont_pref_time_zone_id => NULL,
                                                             p_incident_location_id   => v_loc_id,
                                                             p_incident_location_type => v_loc_type_code,
                                                             p_contact_party_id       => v_party_id,
                                                             p_customer_id            => v_customer_id,
                                                             x_timezone_id            => x_timezone_id,
                                                             x_timezone_name          => x_timezone_name);
        
        END;
      
        v_step := 'Step 143';
        FOR a IN get_external_attribute_11(cur_incident.helpdesk_number) LOOP
          ------1 row only-------
          v_external_attribute_11 := a.external_attribute_11;
        END LOOP;
        
        v_step := 'Step 143.2'; 
        -- SQL For  EXTERNAL_ATTRIBUTE_1 -- CS Region --
        BEGIN
            select p.attribute1
            into   v_external_attribute_1
            from   hz_parties p
            where  p.party_id = v_party_id;  ----customer_id
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            v_external_attribute_1:=null;
          WHEN OTHERS THEN
            v_external_attribute_1:=null;
            fnd_file.put_line(fnd_file.log,'*********Error : ('||v_step||') '||SQLERRM);
        END;
        
        v_step := 'Step 143.3'; 
        -- SQL For EXTERNAL_ATTRIBUTE_3 -- embeeded version
        -- SQL For EXTERNAL_ATTRIBUTE_4 -- STUDIO version
        BEGIN
            select i.ATTRIBUTE4,
                   i.ATTRIBUTE5
            into   v_external_attribute_3,
                   v_external_attribute_4
            from   csi_item_instances i
            where  i.serial_number = cur_incident.serial_numer; 
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            v_external_attribute_3:=null;
            v_external_attribute_4:=null;
          WHEN OTHERS THEN
            v_external_attribute_3:=null;
            v_external_attribute_4:=null;
            fnd_file.put_line(fnd_file.log,'*********Error : ('||v_step||') '||SQLERRM);
        END;
    
        /*v_step := 'Step 150';  --not in use
        ----
        begin
          select h.contract_number
          \*cov.name               COVERAGE,
          msi_service.segment1   SERVICE_LINE_ITEM,
          ld_service.object1_id1 INVENTORY_ID_OF_SERVICE_ITEM,
          oki.object1_id1        INSTANCE_ID_OF_COVERED_PRODUCT*\
            into l_contract_number
            from OKC_K_HEADERS_ALL_B h, --Contract Header
                 okc.okc_k_items     oki, -- Covered Product
                 OKS_AUTH_LINES_V    oal_product, -- Connects between Service Item and Covered Product
                 oks_line_details_v  ld_service, -- Service ITEMS
                 mtl_system_items_b  msi_service, -- Service ITEMS
                 OKS_COVERAGES_V     cov,
                 csi_item_instances  cii
           where h.id = ld_service.contract_id
             and oki.dnz_chr_id = ld_service.contract_id
             and oki.jtot_object1_code = 'OKX_CUSTPROD'
             and oki.cle_id = oal_product.id
             and oal_product.cle_id = ld_service.line_id
             and ld_service.object1_id1 = msi_service.inventory_item_id
             and ld_service.object1_id2 = msi_service.organization_id
             and msi_service.coverage_schedule_id = cov.id(+)
             and oki.object1_id1 = cii.instance_id
             and cii.serial_number = cur_incident.serial_numer --param---
             and h.start_date <= cur_incident.incident_date --param---
             and h.end_date > cur_incident.incident_date; --param--- 
        
        exception
          when OTHERS THEN
            l_contract_number:=null;
        end;*/
        ----------------
         ------
          BEGIN
            v_step := 'Step 160';
            ---fnd_file.put_line(fnd_file.log,''); ---empty row
            ---fnd_file.put_line(fnd_file.log,''); ---empty row
            /*IF l_contract_number IS NOT NULL THEN
                 fnd_file.put_line(fnd_file.log,'*********l_contract_number='||l_contract_number||' for helpdesk_number='||cur_incident.helpdesk_number||'********************');
            ELSE
                 fnd_file.put_line(fnd_file.log,'*********l_contract_number IS NULL for helpdesk_number='||cur_incident.helpdesk_number||'********************');
            END IF;*/
            
            cs_cont_get_details_pvt.get_contract_lines(p_api_version         => 1.0,
                                                       p_init_msg_list       => 'T',
                                                       p_contract_number     => null,  ----l_contract_number,
                                                       p_service_line_id     => NULL,
                                                       p_customer_id         => v_party_id,
                                                       p_site_id             => NULL,
                                                       p_customer_account_id => v_customer_id,
                                                       p_system_id           => v_system_id,
                                                       p_inventory_item_id   => v_item_id,
                                                       p_customer_product_id => v_instance_id,
                                                       p_request_date        => nvl(cur_incident.incident_date,
                                                                                    SYSDATE),
                                                       p_business_process_id => v_business_process_id,
                                                       p_severity_id         => v_severity_id,
                                                       p_time_zone_id        => x_timezone_id,
                                                       p_calc_resptime_flag  => 'Y',
                                                       p_validate_flag       => 'Y',
                                                       p_dates_in_input_tz   => 'N',
                                                       p_incident_date       => nvl(cur_incident.incident_date,
                                                                                    SYSDATE),
                                                       x_ent_contracts       => l_ent_contracts,
                                                       x_return_status       => l_return_status,
                                                       x_msg_count           => l_msg_count,
                                                       x_msg_data            => l_msg_data);
          
            v_step := 'Step 170';
            IF (l_return_status) <> 'S' THEN
              IF (fnd_msg_pub.count_msg > 0) THEN
                FOR c IN 1 .. fnd_msg_pub.count_msg LOOP
                  fnd_msg_pub.get(p_msg_index     => c,
                                  p_encoded       => 'F',
                                  p_data          => l_msg_data,
                                  p_msg_index_out => l_msg_index_out);
                
                  l_err_msg := l_err_msg || l_msg_data || ',';
                END LOOP;
              END IF;
              RAISE invalid_incident;
            END IF;
          
            l_rec_count := l_ent_contracts.FIRST;
          END;
        
        v_step      := 'Step 180';
        p_sr_record := p_sr_record_miss;
        --Start Insert Date From Table
        p_sr_record.cust_ticket_number     := cur_incident.helpdesk_number;
        p_sr_record.project_number         := v_project_number;
        p_sr_record.inventory_org_id       := v_inventory_organization_id;
        IF l_org_id = 89 THEN
              --- OBJET US (OU) 
             p_sr_record.request_date           := nvl(cur_incident.incident_date+10/24,SYSDATE);
             p_sr_record.incident_occurred_date := nvl(cur_incident.incident_occured_date+10/24,SYSDATE);
        ELSE    
             p_sr_record.request_date           := nvl(cur_incident.incident_date+1/24,SYSDATE);                                             
             p_sr_record.incident_occurred_date := nvl(cur_incident.incident_occured_date+1/24,SYSDATE);
        END IF;                                                  
        p_sr_record.type_id                := v_type_id;
        p_sr_record.status_id              := v_status_id;
        p_sr_record.severity_id            := v_severity_id;
        p_sr_record.urgency_id             := v_urgency_id;
        p_sr_record.owner_group_id         := v_group_id;
        p_sr_record.owner_id               := v_resource_id;
        p_sr_record.resource_type          := v_resource_type;
        p_sr_record.group_type             := 'RS_GROUP';
        p_sr_record.owner_group_id         := v_group_id;
        p_sr_record.summary                := cur_incident.problem_summary;
        p_sr_record.resolution_summary     := cur_incident.resolution_summary;
        p_sr_record.caller_type            := 'ORGANIZATION';
        p_sr_record.customer_id            := v_party_id;
        p_sr_record.account_id             := v_customer_id;
        p_sr_record.bill_to_account_id     := v_bill_account_id;
        p_sr_record.bill_to_party_id       := v_bill_to_party_id; 
        p_sr_record.bill_to_site_id        := v_bill_to_site_id;
        p_sr_record.bill_to_site_use_id    := v_bill_to_site_use_id;
        p_sr_record.ship_to_account_id     := v_ship_account_id;
        p_sr_record.ship_to_party_id       := v_ship_to_party_id; 
        p_sr_record.ship_to_site_id        := v_ship_to_site_id;
        p_sr_record.ship_to_site_use_id    := v_ship_to_site_use_id;
        p_sr_record.install_site_id        := v_install_loc_id;
        IF cur_incident.publish_flag='Y' THEN
           p_sr_record.publish_flag := 'T';
        ELSE
           p_sr_record.publish_flag := 'F';
        END IF;
        p_sr_record.verify_cp_flag      := 'N';
        p_sr_record.customer_product_id := v_instance_id;
        p_sr_record.category_set_id     := l_category_set_id;
        p_sr_record.category_id         := v_category_id;
        p_sr_record.LANGUAGE            := 'US';
        --------p_sr_record.cp_ref_number          := v_instance_num; --API Warning (CS_ServiceRequest_PUB.Create_ServiceRequest): The API ignored the p_cp_ref_number parameter.
        p_sr_record.inventory_item_id     := v_item_id;
        p_sr_record.current_serial_number := cur_incident.serial_numer;
        p_sr_record.inv_item_revision     := v_item_rev;
        p_sr_record.product_revision      := v_item_rev;
        p_sr_record.system_id             := v_system_id;
        p_sr_record.problem_code          := v_problem_code;
        p_sr_record.request_attribute_1   := v_category_id;
        p_sr_record.request_attribute_2   := cur_incident.ATTRIBUTE2;
        p_sr_record.request_attribute_3   := cur_incident.ATTRIBUTE3;
        p_sr_record.territory_id          := l_territory_id;
        
        p_sr_record.external_attribute_1  := v_external_attribute_1;  --- CS Region --
        p_sr_record.external_attribute_3  := v_external_attribute_3;  --- embeeded version
        p_sr_record.external_attribute_4  := v_external_attribute_4;  --- STUDIO version
        p_sr_record.external_attribute_11 := v_external_attribute_11; --- from contracts file
      
        p_sr_record.sr_creation_channel    := 'PHONE';
        p_sr_record.last_update_channel    := 'PHONE';
        p_sr_record.incident_location_type := 'HZ_PARTY_SITE'; --v_loc_type_code;
        p_sr_record.incident_location_id   := v_loc_id;
      
        ------Get first contract------
        BEGIN
          v_step                              := 'Step 190';
          -------fnd_file.put_line(fnd_file.log,'*********XXCONV_CRM_SR_API_PKG :  contract_service_id='||l_ent_contracts(1).service_line_id ||' ************');

          p_sr_record.contract_service_id     := l_ent_contracts(1).service_line_id;
          p_sr_record.contract_service_number := NULL;
          p_sr_record.contract_id             := l_ent_contracts(1)
                                                 .contract_id;
          p_sr_record.coverage_type           := l_ent_contracts(1)
                                                 .coverage_type_code;
          p_sr_record.cust_po_number          := l_ent_contracts(1)
                                                 .service_po_number;
          p_sr_record.obligation_date         := l_ent_contracts(1)
                                                 .exp_reaction_time; --Open Date  ;
        EXCEPTION
          WHEN OTHERS THEN
            NULL;
        END;
        ------         
        l_contact_index := 0;
        t_contacts      := t_contacts_miss;
      
        v_step := 'Step 200';
        FOR cur_contact IN csr_sr_contacts(cur_incident.helpdesk_number) LOOP
        
          FOR cur_contact_role IN csr_contact_roles(cur_contact.relationship_party_id) LOOP
            v_step          := 'Step 210';
            l_contact_index := l_contact_index + 1;
            SELECT cs_hz_sr_contact_points_s.NEXTVAL
              INTO t_contacts(l_contact_index).sr_contact_point_id
              FROM dual;
          
            t_contacts(l_contact_index).party_id := cur_contact_role.party_id;
            t_contacts(l_contact_index).contact_point_id := cur_contact_role.contact_point_id;
            t_contacts(l_contact_index).contact_point_type := cur_contact_role.contact_point_type;
            t_contacts(l_contact_index).primary_flag := cur_contact_role.primary_flag;
            t_contacts(l_contact_index).contact_type := cur_contact_role.contact_type;
            t_contacts(l_contact_index).party_role_code := cur_contact_role.party_role_code;
            t_contacts(l_contact_index).start_date_active := SYSDATE;
          END LOOP;
        
        END LOOP;
      
        /*v_step:='Step 220';
        v_note_counter := 0;
        t_notes        := t_notes_miss;
        FOR cur_note IN csr_sr_notes(cur_incident.helpdesk_number) LOOP
           IF cur_note.note IS NOT NULL THEN
              v_note_counter := v_note_counter + 1;
              t_notes(v_note_counter).note := cur_note.note;
              t_notes(v_note_counter).note_type := cur_note.note_type;
              t_notes(v_note_counter).note_context_type_01 := NULL;
              t_notes(v_note_counter).note_context_type_id_01 := NULL;
              t_notes(v_note_counter).note_context_type_02 := NULL;
              t_notes(v_note_counter).note_context_type_id_02 := NULL;
              t_notes(v_note_counter).note_context_type_03 := NULL;
              t_notes(v_note_counter).note_context_type_id_03 := NULL;
           END IF;
        END LOOP;*/
      
        fnd_msg_pub.initialize;
      
        IF p_validation_only <> 'Y' THEN
          v_step := 'Step 250';
          --Send To SR API
          cs_servicerequest_pub.create_servicerequest(p_api_version                  => 4.0,
                                                      p_init_msg_list                => NULL,
                                                      p_commit                       => fnd_api.g_false,
                                                      x_return_status                => return_status,
                                                      x_msg_count                    => msg_count,
                                                      x_msg_data                     => msg_data,
                                                      p_resp_appl_id                 => v_resp_appl_id,
                                                      p_resp_id                      => v_resp_id,
                                                      p_user_id                      => g_user_id, 
                                                      p_login_id                     => v_resource_id,
                                                      p_org_id                       => NULL, 
                                                      p_request_id                   => NULL, 
                                                      p_request_number               => NULL, 
                                                      p_service_request_rec          => p_sr_record,
                                                      p_notes                        => t_notes,
                                                      p_contacts                     => t_contacts,
                                                      p_auto_assign                  => NULL,
                                                      p_auto_generate_tasks          => 'N',
                                                      x_sr_create_out_rec            => x_sr_record,
                                                      p_default_contract_sla_ind     => NULL,
                                                      p_default_coverage_template_id => NULL 
                                                      );
          v_step := 'Step 260';
          IF (return_status <> 'S') THEN
            v_sr_creation_failured_cnt:=v_sr_creation_failured_cnt+1;
            fnd_msg_pub.get(p_msg_index     => -1,
                            p_encoded       => 'F',
                            p_data          => msg_data,
                            p_msg_index_out => l_msg_index_out);
            l_err_msg := msg_data;
            RAISE invalid_incident;
          END IF;
        
          v_sr_success_created_cnt:=v_sr_success_created_cnt+1;
          
          
          ------Create notes for this SR
          v_step          := 'Step 265';
          l_err_msg       := NULL;
          l_msg_count     := NULL;
          l_msg_data      := NULL;
          l_init_msg_list := NULL;
          l_msg_index_out := NULL;
          v_jtf_note_id   := NULL;
          FOR cur_note IN csr_sr_notes(cur_incident.helpdesk_number) LOOP
            IF cur_note.note IS NOT NULL THEN
              v_note_counter := v_note_counter + 1;
              jtf_notes_pub.create_note(p_api_version        => 1.0,
                                        p_init_msg_list      => l_init_msg_list,
                                        p_commit             => l_commit,
                                        p_validation_level   => l_validation_level,
                                        x_return_status      => l_return_status,
                                        x_msg_count          => l_msg_count,
                                        x_msg_data           => l_msg_data,
                                        p_org_id             => l_org_id,
                                        p_source_object_id   => x_sr_record.request_id, ---- New created SR
                                        p_source_object_code => 'SR',
                                        p_note_type          => cur_note.note_type,
                                        p_notes              => cur_note.note,
                                        p_note_status        => cur_note.note_status,
                                        p_entered_date       => cur_note.entered_date,
                                        p_creation_date      => cur_note.entered_date,
                                        x_jtf_note_id        => v_jtf_note_id);
              v_step := 'Step 265.2';
              if (l_return_status = 'S') then
                ---API Success
                v_created_notes_list := v_created_notes_list || 'Note_id=' ||
                                        v_jtf_note_id || ' was created' || ', ';
              else
                ---API Error
                if (fnd_msg_pub.count_msg > 0) then
                  for i in 1 .. fnd_msg_pub.count_msg loop
                    fnd_msg_pub.get(p_msg_index     => i,
                                    p_data          => l_msg_data,
                                    p_encoded       => 'T',
                                    p_msg_index_out => l_msg_index_out);
                  
                    l_err_msg := l_err_msg || l_msg_data || ',';
                  end loop;
                  ---fnd_message.set_encoded(l_err_msg);
                  v_created_notes_list := v_created_notes_list ||
                                          'API Error : ' || l_err_msg || ', ';
                end if;
              end if;
            
            END IF;
          END LOOP;
        END IF; ----IF p_validation_only<>'Y' THEN
      
        v_step        := 'Step 280';
        v_line_number := 0;
        FOR cur_charge IN csr_sr_charges(cur_incident.helpdesk_number) LOOP
          v_step := 'Step 282';
          -----------
          BEGIN
            SELECT inventory_item_id,
                   xxinv_utils_pkg.get_current_revision(inventory_item_id,
                                                        organization_id)
              INTO l_charge_item_id, l_charge_revision
              FROM mtl_system_items_b msi
             WHERE msi.segment1 = cur_charge.item
               AND organization_id =
                   xxinv_utils_pkg.get_master_organization_id;
          EXCEPTION
            WHEN OTHERS THEN
              l_err_msg := 'Charge Item ''' || cur_charge.item ||
                           ''' does not exist ';
              RAISE invalid_incident;
          END;
          ---------
          v_step := 'Step 284';
          BEGIN
            SELECT ctt.transaction_type_id, ctb.txn_billing_type_id
              INTO l_transaction_type_id, l_txn_billing_type_id
              FROM cs_transaction_types_vl ctt, cs_txn_billing_types ctb
             WHERE ctt.transaction_type_id = ctb.transaction_type_id
               AND ( (ctt.name = cur_charge.billing_type  and cur_charge.billing_type NOT IN ('FSR Replace Part','FSR Return Part'))
                     OR
                     (ctt.name = 'FSR Replace Part' and cur_charge.billing_type='FSR Replace Part' and ctb.billing_type='M')
                     OR
                     (ctt.name = 'FSR Return Part' and cur_charge.billing_type='FSR Return Part' and ctb.billing_type='M')
                   );
          
          EXCEPTION
            WHEN OTHERS THEN
              l_err_msg := 'Billing Type ''' || cur_charge.billing_type ||
                           ''' does not exist';
              RAISE invalid_incident;
          END;
          ---------
          v_step := 'Step 290';
          BEGIN
            select plt.list_header_id, round(pll.Operand, 2)
              into l_price_list_id, l_selling_price
              from qp_list_headers_tl    plt,
                   qp_list_lines         pll,
                   qp_pricing_attributes qpa
             where plt.name = cur_charge.price_list --------
               and plt.language = 'US'
               and qpa.list_header_id = plt.list_header_id
               and pll.list_line_id = qpa.list_line_id
               and qpa.product_attr_value =
                   (select msi.INVENTORY_ITEM_ID
                      from mtl_system_items_b msi
                     where msi.organization_id = 91
                       and msi.segment1 = cur_charge.item) ------
               and qpa.product_uom_code = cur_charge.uom; ------
          
          EXCEPTION
            WHEN OTHERS THEN
              l_err_msg := 'Invalid price list,item,uom  (''' ||
                           cur_charge.price_list || ''',''' ||
                           cur_charge.item || ''',''' || cur_charge.uom ||
                           ''') ';
              RAISE invalid_incident;
          END;
          IF cur_charge.business_process IS NOT NULL THEN
            -----------
            v_step := 'Step 293';
            BEGIN
              select bp.business_process_id
                into l_business_process_id_file
                from CS_BUSINESS_PROCESSES bp
               where upper(bp.name) = upper(cur_charge.business_process);
            
            EXCEPTION
              WHEN OTHERS THEN
                l_err_msg := 'Invalid Business Process (''' ||
                             cur_charge.business_process || ''') ';
                RAISE invalid_incident;
            END;
            --------
          END IF;
        
          v_step                             := 'Step 300';
          l_msg_count                        := NULL;
          l_msg_data                         := NULL;
          l_init_msg_list                    := NULL;
          l_msg_index_out                    := NULL;
          t_charges_rec.org_id               := l_org_id;
          t_charges_rec.incident_id          := x_sr_record.request_id; ---New created SR
          t_charges_rec.original_source_id   := x_sr_record.request_id; ---New created SR ------
          t_charges_rec.original_source_code := 'SR';
          t_charges_rec.charge_line_type     := cur_charge.charge_line_type;
          t_charges_rec.line_number          := cur_charge.line_number;
          t_charges_rec.inventory_item_id_in := l_charge_item_id;
          t_charges_rec.item_revision        := l_charge_revision;
          --------t_charges_rec.billing_flag         := cur_charge.billing_flag;  ---closed by Dorit
          t_charges_rec.txn_billing_type_id    := l_txn_billing_type_id;
          t_charges_rec.transaction_type_id    := l_transaction_type_id;
          t_charges_rec.unit_of_measure_code   := cur_charge.uom;
          t_charges_rec.quantity_required      := cur_charge.quantity_required;
          -------t_charges_rec.serial_number        := cur_charge.serial_number;   ---closed by Dorit
          t_charges_rec.currency_code          := cur_charge.currency_code;
          t_charges_rec.list_price             := l_selling_price; ---selected value
          t_charges_rec.selling_price          := cur_charge.selling_price;    ----- value from file
          t_charges_rec.con_pct_over_list_price:= cur_charge.selling_price;    ----- value from file
          t_charges_rec.after_warranty_cost    := cur_charge.selling_price * cur_charge.quantity_required;--override_unit_price * qty
          t_charges_rec.line_category_code     := cur_charge.line_category_code;
          t_charges_rec.price_list_id          := l_price_list_id;
          t_charges_rec.source_code            := 'SR';
          t_charges_rec.source_id              := x_sr_record.request_id; ---New created SR ------
          v_step                               := 'Step 300.5';
          IF l_business_process_id_file IS NOT NULL THEN
            ----from CHARGES...file
            t_charges_rec.business_process_id := l_business_process_id_file;
          ELSE
            ----from SR type
            t_charges_rec.business_process_id := v_business_process_id;
          END IF;
        
          IF p_validation_only <> 'Y' THEN
            v_step := 'Step 310';
            v_note_counter := null;
            cs_charge_details_pub.create_charge_details(
                                                        
                                                        p_api_version           => 1.0,
                                                        p_init_msg_list         => 'T', 
                                                        p_commit                => 'F', 
                                                        p_validation_level      => fnd_api.G_VALID_LEVEL_NONE,
                                                        x_return_status         => l_return_status,
                                                        x_msg_count             => l_msg_count,
                                                        x_object_version_number => v_note_counter,
                                                        x_msg_data              => l_msg_data,
                                                        x_estimate_detail_id    => v_estimate_detail_id,
                                                        x_line_number           => v_line_number,                                                        
                                                        p_resp_appl_id          => v_resp_appl_id,
                                                        p_resp_id               => v_resp_id,
                                                        p_user_id               => g_user_id,
                                                        p_login_id              => NULL,
                                                        p_transaction_control   => fnd_api.g_true,
                                                        p_charges_rec           => t_charges_rec);
            IF l_return_status = apps.fnd_api.g_ret_sts_success THEN
              ---API Success
              v_created_charges_list := v_created_charges_list ||
                                        'Charge line_num=' ||
                                        t_charges_rec.line_number ||
                                        ' was created' || ', ';
            ELSE
              ---API Error
              fnd_msg_pub.get(p_msg_index     => -1,
                              p_encoded       => 'F',
                              p_data          => l_msg_data,
                              p_msg_index_out => l_msg_index_out);
              v_created_charges_list := v_created_charges_list ||
                                        'API Error in line_num=' ||
                                        t_charges_rec.line_number || ': ' ||
                                        substr(l_msg_data, 1, 1000) || ', ';
            END IF;
          END IF; ---- IF p_validation_only<>'Y' THEN   
        END LOOP;
      
        IF p_validation_only <> 'Y' THEN
          ---============================ESCALATION==================================
          IF cur_incident.escalated IS NOT NULL THEN
            --------- profile "Escalation:Default Escalation Level"  (Site)
            --  The following table describes lookup code JTF_TASK_ESC_LEVEL, which describes
            --  escalation levels.
            --  Lookup Code JTF_TASK_ESC_LEVEL
            --  Code Description
            --  DE    De-escalated
            --  L1    Level 1
            --  L2    Level 2
            --  NE    Never escalated
          
            v_step := 'Step 315';
            --------
            l_err_msg := null;
            begin
              
        l_esc_rec.esc_owner_id        := 100002097;              ----l_owner_id;
        l_esc_rec.esc_owner_type_code := 'RS_EMPLOYEE';          ----NVL(l_resource_type,FND_API.G_MISS_CHAR);
        l_esc_rec.esc_name            := 'Escalation Document';  ----g_rule_name;
        -----l_esc_rec.esc_description     := g_rule_desc;
        l_esc_rec.status_id           := 17;                     ----l_esc_status;
        l_esc_rec.escalation_level    := 'L1';                   ----l_esc_level;
        l_esc_rec.customer_id         := v_party_id;             ----g_customer_id ;
        l_esc_rec.cust_account_id     := v_customer_id;          ----g_cust_account_id;
        l_esc_rec.cust_address_id     := v_location_id;          ----g_address_id;
        l_esc_rec.reason_code         := 'AUTOMATED';
        l_esc_rec.esc_open_date       := SYSDATE;
        l_esc_ref_docs(1).action_code := 'I';
        l_esc_ref_docs(1).object_type_code  := 'SR';
        l_esc_ref_docs(1).object_name       := 'Service Request';
        l_esc_ref_docs(1).object_id         := x_sr_record.request_id; ---New created SR  
        l_esc_ref_docs(1).reference_code    := 'ESC';
        l_esc_contacts(1).action_code       := 'I';
        l_esc_contacts(1).contact_id        := 190;    ---v_rule_owner;
                                 /*SELECT B.EMPLOYEE_ID INTO v_rule_owner
                                  FROM JTF_RS_ACTIVE_RESOURCES_VL A,
                                       FND_USER B
                                  WHERE A.RESOURCE_ID=100002097
                                  AND A.USER_NAME=B.USER_NAME*/
        l_esc_contacts(1).contact_type_code := 'EMP';
        l_esc_contacts(1).escalation_requester_flag := 'Y';

        JTF_EC_PUB.Create_Escalation
        ( p_api_version         => 1.0
        , p_init_msg_list       => FND_API.G_True
        , x_return_status       => l_return_status
        , x_msg_count           => l_msg_count
        , x_msg_data            => l_msg_data
        , p_user_id             => l_user_id
        , p_esc_record          => l_esc_rec
        , p_reference_documents => l_esc_ref_docs
        , p_esc_contacts        => l_esc_contacts
        , p_cont_points         => l_esc_cont_phones
        , x_esc_id              => l_esc_task_id
        , x_esc_number          => l_esc_task_number
        , x_workflow_process_id => l_wf_process_id
        );
        IF (l_return_status <> FND_API.G_Ret_Sts_Success) THEN
          -----------------------------------------------------------------
          -- Create_Escalation API failed
          -----------------------------------------------------------------
            fnd_msg_pub.get(p_msg_index     => -1,
                            p_encoded       => 'F',
                            p_data          => msg_data,
                            p_msg_index_out => l_msg_index_out);
            l_err_msg := msg_data;
            v_created_escalations_list := v_created_escalations_list ||
                                                'API Error : ' ||
                                                substr(l_err_msg, 1, 1000) || ', ';
            
       ELSE
            ----API SUCCESS
            COMMIT;
            v_created_escalations_list := v_created_escalations_list ||
                                              'Escalation task_id=' ||
                                              l_esc_task_id ||
                                              ' was created' || ', ';
            ---RAISE FND_API.G_EXC_UNEXPECTED_ERROR;
        END IF;
            end;
            -----=======================the end of ESCALATION==================================
          END IF; ----IF cur_incident.escalated IS NOT NULL THEN
        END IF; ---IF p_validation_only<>'Y' THEN       
      
        IF p_validation_only <> 'Y' THEN
          v_step := 'Step 330';
          UPDATE xxobjt_conv_crm_incidents t
             SET t.status                   = 'S',
                 t.incident_number          = x_sr_record.request_number, ---created SR number
                 t.creation_date            = SYSDATE,
                 t.created_notes_list       = v_created_notes_list,      ---notes created       for this SR
                 t.created_charges_list     = v_created_charges_list,    ---charges created     for this SR
                 t.created_escalations_list = v_created_escalations_list ---escalations created for this SR
           WHERE t.helpdesk_number = cur_incident.helpdesk_number;
        END IF;
      
      EXCEPTION
        WHEN invalid_incident THEN
          v_valid_errors_counter := v_valid_errors_counter + 1;
          ROLLBACK;
          IF p_validation_only = 'Y' THEN
            fnd_file.put_line(fnd_file.log,
                              '-----Helpdesk Number=''' ||
                              cur_incident.helpdesk_number ||
                              ''' VALIDATION ERROR : ' || l_err_msg);
            UPDATE xxobjt_conv_crm_incidents t
               SET t.status        = 'E',
                   t.error_message = l_err_msg,
                   t.creation_date = SYSDATE
             WHERE t.helpdesk_number = cur_incident.helpdesk_number;
          ELSE
            UPDATE xxobjt_conv_crm_incidents t
               SET t.status        = 'E',
                   t.error_message = l_err_msg,
                   t.creation_date = SYSDATE
             WHERE t.helpdesk_number = cur_incident.helpdesk_number;
          END IF;
        WHEN OTHERS THEN
          l_err_msg := SQLERRM;
          ROLLBACK;
          IF p_validation_only = 'Y' THEN
            fnd_file.put_line(fnd_file.log,
                              '-----Helpdesk Number=''' ||
                              cur_incident.helpdesk_number ||
                              ''' Unexpected Error (' || v_step || ') : ' ||
                              l_err_msg);
            v_unexpected_error_cnt := v_unexpected_error_cnt + 1;
          ELSE
            UPDATE xxobjt_conv_crm_incidents t
               SET t.status        = 'E',
                   t.error_message = 'Unexpected Error (' || v_step ||
                                     ') : ' || l_err_msg,
                   t.creation_date = SYSDATE
             WHERE t.helpdesk_number = cur_incident.helpdesk_number;
          END IF;
      END;
      COMMIT;
    END LOOP;
  
    fnd_file.put_line(fnd_file.log, ''); --empty line
    fnd_file.put_line(fnd_file.log, ''); --empty line
    fnd_file.put_line(fnd_file.log,
                      '***********************************************************************');
    fnd_file.put_line(fnd_file.log,
                      '********************TOTAL INFORMATION**********************************');
    fnd_file.put_line(fnd_file.log,
                      '***********************************************************************');
    fnd_file.put_line(fnd_file.log,
                      '====== There are ' || v_counter ||
                      ' Service Requests in our file ');
    fnd_file.put_line(fnd_file.log,
                      '================ ' || v_unexpected_error_cnt ||
                      ' SR with Unexpected Errors');
    fnd_file.put_line(fnd_file.log,
                      '================ ' || v_valid_errors_counter ||
                      ' SR are NON VALID');
    fnd_file.put_line(fnd_file.log,
                      '================ ' || v_sr_success_created_cnt ||
                      ' SR successfuly created');                  
    fnd_file.put_line(fnd_file.log,
                      '================ ' || v_sr_creation_failured_cnt ||
                      ' SR creation api failured');                    
                      
                                            
  
  EXCEPTION
    WHEN OTHERS THEN
      retcode := '2';
      errbuf  := 'Unexpected Error in xxconv_crm_sr_api_pkg.insert_api_sr (' ||
                 v_step || ') : ' || SQLERRM;
  END insert_api_sr;

  /*PROCEDURE create_task_api(errbuf OUT VARCHAR2, retcode OUT VARCHAR2) IS
  
     CURSOR cr_tasks IS
        SELECT * FROM cis_crm_sr_tasks_api a WHERE status = 'I';
  
     p_sr_record   apps.cs_servicerequest_pub.service_request_rec_type;
     l_notes       apps.cs_servicerequest_pub.notes_table;
     l_contacts    apps.cs_servicerequest_pub.contacts_table;
     l_task_rec_in jtf_tasks_pub.task_rec;
     v_resource_id VARCHAR2(30);
  
     p_source_sw_case_id NUMBER;
     return_status       VARCHAR2(200) := NULL;
     msg_count           NUMBER;
     msg_data            VARCHAR2(4000);
     l_msg_count         NUMBER;
     l_msg_data          VARCHAR2(4000) := NULL;
     l_error_data        VARCHAR2(4000) := NULL;
     l_note_index        NUMBER;
     l_contact_index     NUMBER;
     l_msg_index_out     VARCHAR2(2000) := 0;
     v_counter           NUMBER := 0;
     l_task_id           NUMBER;
     v_task_reference_id NUMBER(10);
     v_assig_id          NUMBER(10);
     v_description       VARCHAR2(4000);
     v_resource_type     VARCHAR2(30);
  BEGIN
  
     fnd_client_info.set_org_context('10');
     --Create Task API
     FOR i IN cr_tasks LOOP
        fnd_global.apps_initialize(nvl(i.task_created_by, 23982),
                                   53433,
                                   512);
        return_status := NULL;
        msg_count     := NULL;
        msg_data      := NULL;
        v_description := NULL;
     
        IF i.instruction IS NOT NULL THEN
           v_description := 'Service Direction: ' || i.instruction ||
                            chr(10);
        ELSE
           v_description := v_description;
        END IF;
     
        IF i.rma_id IS NOT NULL THEN
           v_description := v_description || 'Related RMA: ' || i.rma_id ||
                            chr(10);
        ELSE
           v_description := v_description;
        END IF;
     
        IF i.cyborg_open_date IS NOT NULL THEN
           v_description := v_description || 'Open Date: ' ||
                            i.cyborg_open_date || chr(10);
        ELSE
           v_description := v_description;
        END IF;
     
        IF i.resol_desc IS NOT NULL THEN
           v_description := v_description || 'Field Service Outcome: ' ||
                            i.resol_desc || chr(10);
        ELSE
           v_description := v_description;
        END IF;
     
        IF i.task_owner_id = 100009589 THEN
           v_resource_type := 'RS_OTHER';
        ELSE
           v_resource_type := 'RS_EMPLOYEE';
        END IF;
     
        jtf_tasks_pub.create_task(p_api_version        => 1.0,
                                  p_init_msg_list      => fnd_api.g_false, --'T',
                                  p_commit             => fnd_api.g_false, --null,
                                  p_task_name          => nvl(i.subject,
                                                              i.incident_id),
                                  p_task_type_name     => i.task_type,
                                  p_task_type_id       => i.type_id,
                                  p_description        => v_description,
                                  p_task_status_name   => i.task_status,
                                  p_task_status_id     => i.task_status_id,
                                  p_task_priority_name => i.task_priority,
                                  p_task_priority_id   => i.priority_id,
                                  p_planned_start_date => to_date(i.plan_start_date,
                                                                  'MM/DD/YYYY'),
                                  p_planned_end_date   => to_date(i.plan_end_date,
                                                                  'MM/DD/YYYY'),
                                  p_actual_start_date  => to_date(i.act_start_date,
                                                                  'MM/DD/YYYY'),
                                  p_actual_end_date    => to_date(i.act_end_date,
                                                                  'MM/DD/YYYY'),
                                  p_owner_type_code    => v_resource_type,
                                  p_owner_id           => i.task_owner_id,
                                  --   p_assigned_by_id                => i.Task_Owner_Id,
                                  p_source_object_type_code => 'SR',
                                  p_source_object_id        => i.incident_id, --3609,--l_task_rec_in.
                                  p_source_object_name      => i.incident_id,
                                  x_return_status           => return_status,
                                  x_msg_count               => msg_count,
                                  x_msg_data                => msg_data,
                                  x_task_id                 => l_task_id);
        IF (return_status <> 'S') THEN
           fnd_msg_pub.get(p_msg_index     => -1,
                           p_encoded       => 'F',
                           p_data          => msg_data,
                           p_msg_index_out => l_msg_index_out);
           dbms_output.put_line(return_status || ' ' || msg_data);
           UPDATE cis_crm_sr_tasks_api
              SET error = msg_data, status = return_status
            WHERE temp_task_id = i.temp_task_id;
           --   commit;
        ELSE
        
           fnd_msg_pub.initialize;
           IF i.assignee_id IS NOT NULL THEN
              return_status := NULL;
              msg_count     := NULL;
              msg_data      := NULL;
           
              jtf_task_assignments_pub.create_task_assignment(p_api_version          => 1.0,
                                                              p_init_msg_list        => fnd_api.g_false, --'T',
                                                              p_commit               => fnd_api.g_false,
                                                              p_task_id              => l_task_id,
                                                              p_resource_type_code   => 'RS_EMPLOYEE',
                                                              p_resource_id          => i.assignee_id,
                                                              p_task_assignment_id   => NULL,
                                                              p_task_number          => NULL,
                                                              p_task_name            => NULL,
                                                              p_assignment_status_id => i.task_status_id,
                                                              p_shift_construct_id   => NULL,
                                                              x_return_status        => return_status,
                                                              x_msg_count            => msg_count,
                                                              x_msg_data             => msg_data,
                                                              x_task_assignment_id   => v_assig_id);
           
              IF return_status <> 'S' THEN
                 fnd_msg_pub.get(p_msg_index     => -1,
                                 p_encoded       => 'F',
                                 p_data          => msg_data,
                                 p_msg_index_out => l_msg_index_out);
                 dbms_output.put_line(return_status);
                 UPDATE cis_crm_sr_tasks_api
                    SET error = msg_data, status = return_status;
                 --     commit;
              ELSE
                 dbms_output.put_line(return_status || ' ' || msg_data);
                 UPDATE cis_crm_sr_tasks_api
                    SET error = NULL, status = 'S', task_id = l_task_id
                  WHERE temp_task_id = i.temp_task_id;
                 --     Commit;
              END IF;
           ELSE
              UPDATE cis_crm_sr_tasks_api
                 SET error   = 'Need To update Assignee',
                     status  = 'S',
                     task_id = l_task_id
               WHERE temp_task_id = i.temp_task_id;
              -- commit;
           END IF;
        END IF;
     END LOOP;
  END create_task_api;*/

  /*PROCEDURE create_note IS
  
     CURSOR cr_temptbl IS
        SELECT *
          FROM xxobjt_conv_sr_notes xcn \*
                                                                                                                                                                                                                                                                             Where xcn.trans_to_int_code = 'N'*\
        ;
  
     v_user_id        fnd_user.user_id%TYPE;
     v_entered_by_id  fnd_user.user_id%TYPE;
     v_lookup_code    fnd_lookup_values.lookup_code%TYPE;
     v_lookup_meaning fnd_lookup_values.meaning%TYPE;
     l_incident_id    cs_incidents_all_b.incident_id%TYPE;
     l_return_status  xxobjt_conv_sr_notes.trans_to_int_code%TYPE;
     l_msg_count      NUMBER;
     l_msg_data       xxobjt_conv_sr_notes.trans_to_int_error%TYPE;
     l_jtf_note_id    NUMBER;
     v_note_status    VARCHAR2(10);
     ln_count         NUMBER;
     lc_entity_id     VARCHAR2(1000);
     lc_entity_type   VARCHAR2(1000);
     v_msg_index_out  NUMBER;
  
  BEGIN
  
     BEGIN
        SELECT user_id --> 1698
          INTO v_user_id
          FROM fnd_user
         WHERE user_name = 'CONVERSION';
     EXCEPTION
        WHEN no_data_found THEN
           v_user_id := NULL;
     END;
  
     FOR i IN cr_temptbl LOOP
     
        BEGIN
           SELECT user_id --> 1318
             INTO v_entered_by_id
             FROM fnd_user
            WHERE user_name = i.entered_by;
        EXCEPTION
           WHEN no_data_found THEN
              v_entered_by_id := NULL;
        END;
     
        BEGIN
           SELECT fndv.lookup_code
             INTO v_note_status
             FROM fnd_lookup_values fndv
            WHERE fndv.lookup_type = 'JTF_NOTE_STATUS' AND
                  meaning = i.status;
        EXCEPTION
           WHEN no_data_found THEN
              v_note_status := NULL;
        END;
     
        BEGIN
           SELECT cib.incident_id
             INTO l_incident_id
             FROM cs_incidents_all_b cib
            WHERE cib.customer_ticket_number = i.priority_case;
           dbms_output.put_line('Incident ID: ' || l_incident_id);
        EXCEPTION
           WHEN no_data_found THEN
              l_incident_id := NULL;
        END;
     
        BEGIN
           SELECT fndv.lookup_code
             INTO v_lookup_code
             FROM fnd_lookup_values fndv
            WHERE fndv.lookup_type LIKE 'JTF_NOTE_TYPE' AND
                  fndv.LANGUAGE = 'US' AND
                  (fndv.end_date_active IS NULL OR
                  fndv.end_date_active > SYSDATE) AND
                  fndv.meaning = i.note_type;
           dbms_output.put_line('Lookup Meaning: ' || v_lookup_code);
        EXCEPTION
           WHEN no_data_found THEN
              v_lookup_code := NULL;
        END;
     
        \*      Begin        
            select fndv.lookup_code
               into v_lookup_code
                   from fnd_lookup_values fndv
            where fndv.lookup_type like 'JTF_NOTE_TYPE'
            and fndv.language = 'US'
            and (fndv.end_date_active is null or fndv.end_date_active > sysdate) and
             fndv.meaning = i.note_type;
            Dbms_Output.Put_Line('Lookup Code: '||v_lookup_code);           
            exception        
                 when no_data_found then
                     v_lookup_code := null;              
        End;   *\
     
        dbms_output.put_line('l_incident_id:    ' || l_incident_id);
        dbms_output.put_line('i.source_object: ' || i.source_object);
        dbms_output.put_line('i.note:             ' || i.note);
        dbms_output.put_line('v_note_status: ' || v_note_status);
     
        BEGIN
        
           jtf_notes_pub.create_note(p_api_version        => 1.0,
                                     p_init_msg_list      => fnd_api.g_true,
                                     p_commit             => fnd_api.g_false,
                                     x_return_status      => l_return_status,
                                     x_msg_count          => l_msg_count,
                                     x_msg_data           => l_msg_data,
                                     p_source_object_id   => l_incident_id,
                                     p_source_object_code => i.source_object_code,
                                     p_notes              => i.note,
                                     p_notes_detail       => NULL,
                                     p_note_status        => v_note_status,
                                     p_entered_by         => v_entered_by_id,
                                     p_entered_date       => i.entered_date,
                                     p_note_type          => v_lookup_code,
                                     x_jtf_note_id        => l_jtf_note_id,
                                     p_last_update_date   => SYSDATE,
                                     p_last_updated_by    => v_user_id,
                                     p_created_by         => v_user_id);
        
        END;
     
        dbms_output.put_line('API Return Status: ' || l_return_status);
        dbms_output.put_line('API Msg Count:     ' || l_msg_count);
        dbms_output.put_line('API Note ID:         ' || l_jtf_note_id);
     
        IF l_return_status <> 'S' THEN
           v_msg_index_out := NULL;
           fnd_msg_pub.get(-1, 'F', l_msg_data, v_msg_index_out);
           dbms_output.put_line('API Msg Data:       ' || l_msg_data);
           UPDATE xxobjt_conv_sr_notes xcn
              SET xcn.trans_to_int_code  = l_return_status,
                  xcn.trans_to_int_error = l_msg_data
            WHERE xcn.source_object = i.source_object;
        ELSE
           UPDATE xxobjt_conv_sr_notes xcn
              SET xcn.trans_to_int_code = 'S'
            WHERE xcn.source_object = i.source_object;
        END IF;
     
     END LOOP;
  
     COMMIT;
  
  END;*/

  ---------------------------------------------------------------------------------------------------  

  PROCEDURE create_task_assignee IS
  
    CURSOR cr_temptbl_tasks IS
      SELECT * FROM xxobjt_conv_task_assign xct;
  
    v_user_id            fnd_user.user_id%TYPE;
    v_assign_status_id   jtf_task_statuses_vl.task_status_id%TYPE;
    l_return_status      xxobjt_conv_task_assign.trans_to_int_code%TYPE;
    l_msg_count          NUMBER;
    l_msg_data           xxobjt_conv_task_assign.trans_to_int_error%TYPE;
    l_task_assignment_id jtf_task_all_assignments.task_assignment_id%TYPE;
    l_task_number        VARCHAR2(30); -- jtf_tasks_b.task_number%TYPE;
    l_enable_workflow    VARCHAR2(1);
    v_msg_index_out      NUMBER;
    ---l_varchar2           VARCHAR2(500);
    ---l_number             NUMBER;
    v_resource_id jtf_rs_resource_extns_vl.resource_id%TYPE;
  
  BEGIN
  
    BEGIN
      SELECT user_id --> 1698
        INTO v_user_id
        FROM fnd_user
       WHERE user_name = 'CONVERSION';
    EXCEPTION
      WHEN no_data_found THEN
        v_user_id := NULL;
    END;
  
    FOR i IN cr_temptbl_tasks LOOP
    
      BEGIN
        SELECT jts.task_status_id
          INTO v_assign_status_id
          FROM jtf_task_statuses_vl jts
         WHERE assignment_status_flag = 'Y'
           AND jts.NAME = i.assignment_status;
      EXCEPTION
        WHEN no_data_found THEN
          v_assign_status_id := NULL;
      END;
    
      BEGIN
        IF i.resource_type_code = 'Employee Resource' THEN
          --  'RS_EMPLOYEE' then
          BEGIN
            SELECT jte.resource_id
              INTO v_resource_id
              FROM jtf_rs_resource_extns_vl jte
             WHERE category = 'EMPLOYEE'
               AND resource_name = i.resource_id;
          EXCEPTION
            WHEN no_data_found THEN
              v_resource_id := NULL;
          END;
        ELSIF i.resource_type_code = 'RS_GROUP' THEN
          BEGIN
            SELECT jtg.group_id
              INTO v_resource_id
              FROM jtf_rs_groups_vl jtg
             WHERE jtg.group_name = i.resource_id;
          EXCEPTION
            WHEN no_data_found THEN
              v_resource_id := NULL;
          END;
        END IF;
      END;
    
      dbms_output.put_line('User ID:            ' || v_user_id);
      dbms_output.put_line('Task Status ID: ' || v_assign_status_id);
      dbms_output.put_line('Resorce ID:       ' || v_resource_id);
    
      BEGIN
        jtf_task_assignments_pub.create_task_assignment(p_api_version          => 1.0,
                                                        p_init_msg_list        => fnd_api.g_true,
                                                        p_commit               => fnd_api.g_false,
                                                        p_task_number          => l_task_number,
                                                        p_resource_type_code   => i.resource_type_code,
                                                        p_resource_id          => v_resource_id,
                                                        p_actual_effort        => i.actual_effort,
                                                        p_actual_effort_uom    => i.actual_effort_uom,
                                                        p_actual_start_date    => i.actual_start_date,
                                                        p_actual_end_date      => i.actual_end_date,
                                                        p_assignment_status_id => v_assign_status_id,
                                                        x_return_status        => l_return_status,
                                                        x_msg_count            => l_msg_count,
                                                        x_msg_data             => l_msg_data,
                                                        x_task_assignment_id   => l_task_assignment_id,
                                                        p_enable_workflow      => NULL,
                                                        p_abort_workflow       => NULL,
                                                        p_object_capacity_id   => l_enable_workflow,
                                                        p_free_busy_type       => NULL);
      END;
    
      dbms_output.put_line('API Return Status: ' || l_return_status);
      dbms_output.put_line('API Msg Count:     ' || l_msg_count);
      dbms_output.put_line('API Msg Data:       ' || l_msg_data);
      dbms_output.put_line('API Assignment ID: ' || l_task_assignment_id);
    
      IF l_return_status <> 'S' THEN
        v_msg_index_out := NULL;
        fnd_msg_pub.get(-1, 'F', l_msg_data, v_msg_index_out);
        dbms_output.put_line('API Msg Data:     ' || l_msg_data);
        UPDATE xxobjt_conv_task_assign xct
           SET xct.trans_to_int_code  = l_return_status,
               xct.trans_to_int_error = l_msg_data
         WHERE xct.task_number = i.task_number;
      ELSE
        UPDATE xxobjt_conv_task_assign xct
           SET xct.trans_to_int_code = 'S',
               xct.task_number       = l_task_assignment_id
         WHERE xct.task_number = i.task_number;
        dbms_output.put_line('API Task Number: ' || l_task_assignment_id);
      END IF;
    
    END LOOP;
  
    COMMIT;
  
  END create_task_assignee;

---------------------------------------------------------------------------------------------------   
BEGIN
  SELECT user_id
    INTO g_user_id
    FROM fnd_user
   WHERE user_name = 'CONVERSION';

  fnd_global.apps_initialize(g_user_id, g_resp_id, g_resp_appl_id);

END xxconv_crm_sr_api_pkg;
/

