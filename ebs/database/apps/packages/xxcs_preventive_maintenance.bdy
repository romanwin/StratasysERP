CREATE OR REPLACE PACKAGE BODY xxcs_preventive_maintenance IS
  --------------------------------------------------------------------
  -- name:            XXCS_PREVENTIVE_MAINTENANCE
  -- create by:       Dalit A. Raviv
  -- Revision:        1.0
  -- creation date:   12/03/2012 11:39:03
  --------------------------------------------------------------------
  -- purpose :        Cust- 484 -> SR Preventive Maintenance Auto Creation
  --                  Customization should support different PM plans per 
  --                  different Printers and different counters readings.
  --                  screen xxce_sr_pm call to this package
  --                  Once the user select the relevant lines at the screen, 
  --                  She/he will press GENERATE button in order for the 
  --                  customization to create SRs of PM Type per each selected line.              
  --------------------------------------------------------------------
  -- ver  date        name             desc
  -- 1.0  12/03/2012  Dalit A. Raviv   initial build
  --------------------------------------------------------------------
  invalid_request EXCEPTION;
  g_user_id fnd_user.user_id%TYPE := fnd_profile.value('USER_ID');

  SUBTYPE r_service_request_rec_type IS cs_servicerequest_pub.service_request_rec_type;
  SUBTYPE t_notes_table_type IS cs_servicerequest_pub.notes_table;
  SUBTYPE t_contacts_table_type IS cs_servicerequest_pub.contacts_table;
  --SUBTYPE o_sr_update_out_rec_type IS cs_servicerequest_pub.sr_update_out_rec_type;
  SUBTYPE o_sr_create_out_rec_type IS cs_servicerequest_pub.sr_create_out_rec_type;

  --------------------------------------------------------------------
  -- name:            handle_log_tbl
  -- create by:       Dalit A. Raviv
  -- Revision:        1.0
  -- creation date:   18/03/2012 
  --------------------------------------------------------------------
  -- purpose :        Cust- 484 -> SR Preventive Maintenance Auto Creation
  --                  procedure that will handle all API messages.
  --                  at the screen i will be able to retriev today messages and
  --                  show all messages to user at the screen.
  --                            
  --------------------------------------------------------------------
  -- ver  date        name             desc
  -- 1.0  18/03/2012  Dalit A. Raviv   initial build
  --------------------------------------------------------------------
  PROCEDURE handle_log_tbl(p_log_rec  IN t_sr_pm_rec,
                           p_batch_id IN NUMBER,
                           p_status   IN VARCHAR2,
                           p_err_code OUT VARCHAR2,
                           p_err_msg  OUT VARCHAR2) IS
  
    PRAGMA AUTONOMOUS_TRANSACTION;
    l_entity_id NUMBER := NULL;
  BEGIN
    p_err_code := 0;
    p_err_msg  := NULL;
  
    -- get entity id
    SELECT xxcs_sr_pm_log_s.nextval INTO l_entity_id FROM dual;
  
    INSERT INTO xxcs_sr_pm_log_tbl
      (batch_id,
       entity_id,
       instance_id,
       serial_number,
       inventory_item_id,
       party_id,
       org_id,
       cs_region,
       active_contract, -- WARRANTY, FULL CARE etc
       counter_change,
       last_counter,
       template_id,
       incident_number,
       incident_id,
       status,
       log_code,
       log_message,
       send_mail,
       last_update_date,
       last_updated_by,
       last_update_login,
       creation_date,
       created_by)
    VALUES
      (p_batch_id,
       l_entity_id,
       p_log_rec.instance_id,
       p_log_rec.serial_number,
       p_log_rec.inventory_item_id,
       p_log_rec.party_id,
       p_log_rec.org_id,
       p_log_rec.cs_region,
       p_log_rec.active_contract,
       p_log_rec.counter_change,
       p_log_rec.last_counter,
       p_log_rec.template_id,
       p_log_rec.incident_number,
       p_log_rec.incident_id,
       p_status,
       p_log_rec.log_code,
       p_log_rec.log_message,
       'N',
       SYSDATE,
       g_user_id,
       -1,
       SYSDATE,
       g_user_id);
  
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      p_err_code := 1;
      p_err_msg  := 'GEN EXC - handle_log - ' || substr(SQLERRM, 1, 240);
  END handle_log_tbl;

  --------------------------------------------------------------------
  -- name:            handle_upd_log_tbl
  -- create by:       Dalit A. Raviv
  -- Revision:        1.0
  -- creation date:   26/03/2012 11:39:03
  --------------------------------------------------------------------
  -- purpose :        Cust- 484 -> SR Preventive Maintenance Auto Creation
  --                  Handle update log table with API success or failure.
  --                            
  --------------------------------------------------------------------
  -- ver  date        name             desc
  -- 1.0  26/03/2012  Dalit A. Raviv   initial build
  --------------------------------------------------------------------    
  PROCEDURE handle_upd_log_tbl(p_batch_id        IN NUMBER,
                               p_entity_id       IN NUMBER,
                               p_status          IN VARCHAR2,
                               p_item_id         IN NUMBER,
                               p_incident_number IN VARCHAR2,
                               p_incident_id     IN NUMBER,
                               p_task_id         IN NUMBER,
                               p_err_code        IN OUT VARCHAR2,
                               p_err_msg         IN OUT VARCHAR2) IS
  
    PRAGMA AUTONOMOUS_TRANSACTION;
  
  BEGIN
  
    UPDATE xxcs_sr_pm_log_tbl log
       SET log.status            = p_status,
           log.inventory_item_id = p_item_id,
           log.incident_number   = p_incident_number,
           log.incident_id       = p_incident_id,
           log.task_id           = p_task_id,
           log.log_code          = p_err_code,
           log.log_message       = p_err_msg
     WHERE log.batch_id = p_batch_id
       AND log.entity_id = p_entity_id;
  
    COMMIT;
    p_err_code := 0;
    p_err_msg  := NULL;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      p_err_code := 1;
      p_err_msg  := 'GEN EXC - handle_upd_log_tbl - ' ||
                    substr(SQLERRM, 1, 240);
  END handle_upd_log_tbl;

  --------------------------------------------------------------------
  -- name:            create_pm_service_request
  -- create by:       Dalit A. Raviv
  -- Revision:        1.0
  -- creation date:   12/03/2012 11:39:03
  --------------------------------------------------------------------
  -- purpose :        Cust- 484 -> SR Preventive Maintenance Auto Creation
  --                  procedure that call from create SR preventive maintenance
  --                  screen. Procedure create SR by the parameters that pass.
  --                            
  --------------------------------------------------------------------
  -- ver  date        name             desc
  -- 1.0  12/03/2012  Dalit A. Raviv   initial build
  --------------------------------------------------------------------       
  PROCEDURE create_pm_service_request(errbuf            OUT VARCHAR2,
                                      retcode           OUT VARCHAR2,
                                      p_instance_id     IN NUMBER,
                                      p_serial_number   IN VARCHAR2,
                                      p_party_id        IN NUMBER,
                                      p_org_id          IN NUMBER,
                                      p_cs_region       IN VARCHAR2,
                                      p_incident_number OUT VARCHAR2,
                                      p_incident_id     OUT NUMBER,
                                      p_item_id         OUT NUMBER,
                                      p_location_id     OUT NUMBER) IS
  
    l_inventory_item_id   NUMBER := NULL;
    l_item_rev            VARCHAR2(3) := NULL;
    l_organization_id     NUMBER := NULL;
    l_location_type_code  VARCHAR2(20) := NULL;
    l_location_id         NUMBER := NULL;
    l_owner_party_id      NUMBER := NULL;
    l_customer_id         NUMBER := NULL;
    l_instance_id         NUMBER := NULL;
    l_instance_number     NUMBER := NULL;
    l_system_id           NUMBER := NULL;
    l_category_id         NUMBER := NULL;
    l_install_location_id NUMBER := NULL;
    l_org_id              NUMBER := NULL;
    l_group_id            NUMBER := NULL;
    l_owner_resource_id   NUMBER := NULL;
    --l_owner_resource_id1      number       := null;  
  
    l_ship_to_site_use_id NUMBER := NULL;
    l_ship_to_site_id     NUMBER := NULL;
    l_ship_account_id     NUMBER := NULL;
    l_ship_to_party_id    NUMBER := NULL;
    l_bill_to_site_use_id NUMBER := NULL;
    l_bill_to_site_id     NUMBER := NULL;
    l_bill_account_id     NUMBER := NULL;
    l_bill_to_party_id    NUMBER := NULL;
  
    l_timezone_id         NUMBER := NULL;
    l_timezone_name       VARCHAR2(80) := NULL;
    r_service_request_rec r_service_request_rec_type;
    t_notes_table         t_notes_table_type;
    t_contacts_table      t_contacts_table_type;
    o_sr_create_out_rec   o_sr_create_out_rec_type;
    t_ent_contracts       cs_cont_get_details_pvt.ent_contract_tab;
    x_business_process_id NUMBER := NULL;
  
    l_msg_count     NUMBER := NULL;
    l_msg_data      VARCHAR2(500) := NULL;
    l_msg_index_out NUMBER := NULL;
    x_msg_data      VARCHAR2(500) := NULL;
    x_return_status VARCHAR2(100) := NULL;
    l_resource_id   NUMBER := NULL;
    l_user_id       NUMBER := NULL;
  
  BEGIN
    -- initial record variable
    cs_servicerequest_pub.initialize_rec(r_service_request_rec);
    x_return_status := fnd_api.g_ret_sts_success;
    errbuf          := 'Success';
    retcode         := 0;
  
    -- get item details from install base
    BEGIN
      SELECT cii.inventory_item_id,
             cii.inventory_revision,
             nvl(cii.inv_organization_id, cii.inv_master_organization_id),
             cii.install_location_type_code,
             cii.location_id,
             cii.owner_party_id,
             cii.owner_party_account_id,
             cii.instance_id,
             cii.instance_number,
             cii.system_id,
             mic.category_id,
             cii.install_location_id
        INTO l_inventory_item_id,
             l_item_rev,
             l_organization_id,
             l_location_type_code,
             l_location_id,
             l_owner_party_id,
             l_customer_id,
             l_instance_id,
             l_instance_number,
             l_system_id,
             l_category_id,
             l_install_location_id
        FROM csi_item_instances    cii,
             mtl_item_categories   mic,
             csi_instance_statuses cis
       WHERE cii.inventory_item_id = mic.inventory_item_id
         AND mic.organization_id = cii.inv_master_organization_id
         AND mic.category_set_id =
             xxinv_utils_pkg.get_default_category_set_id
         AND cii.instance_status_id = cis.instance_status_id
         AND cis.terminated_flag = 'N'
         AND cii.instance_id = p_instance_id;
    
    EXCEPTION
      WHEN OTHERS THEN
        errbuf := 'ERR - Validation failed for Customer/Serial';
        RAISE invalid_request;
    END;
  
    -- get org_id, group id \and owner resource id
    BEGIN
      SELECT ffv.attribute1 org_id,
             ffv.attribute2 group_id,
             ffv.attribute3 owner_resource_id
        INTO l_org_id, l_group_id, l_owner_resource_id
        FROM hz_parties hp, fnd_flex_values ffv, fnd_flex_value_sets ffvs
       WHERE ffvs.flex_value_set_name = 'XXCS_CS_REGIONS'
         AND ffv.flex_value_set_id = ffvs.flex_value_set_id
         AND hp.attribute3 = ffv.attribute1
         AND ffv.enabled_flag = 'Y'
         AND hp.party_id = p_party_id
         AND rownum = 1;
    EXCEPTION
      WHEN OTHERS THEN
        errbuf := 'ERR - Region Query: ' || substr(SQLERRM, 1, 240);
        RAISE invalid_request;
    END;
    -- get resource id by user that run the program
    BEGIN
      l_user_id := fnd_profile.value('USER_ID');
    
      SELECT res.resource_id
        INTO l_resource_id
        FROM jtf_rs_resource_extns res
       WHERE user_id = l_user_id;
    
      l_owner_resource_id := l_resource_id;
    
    EXCEPTION
      WHEN OTHERS THEN
        NULL;
    END;
  
    -- Get customer data
    BEGIN
      SELECT hpsu.party_site_use_id  ship_to_site_use_id,
             hp.party_site_id        ship_to_site_id,
             hc.cust_account_id      ship_to_account_id,
             h.party_id              ship_to_party_id,
             hpsu1.party_site_use_id bill_to_site_use_id,
             hp1.party_site_id       bill_to_site_id,
             hc1.cust_account_id     bill_to_account_id,
             h1.party_id             bill_to_party_id
        INTO l_ship_to_site_use_id,
             l_ship_to_site_id,
             l_ship_account_id,
             l_ship_to_party_id,
             l_bill_to_site_use_id,
             l_bill_to_site_id,
             l_bill_account_id,
             l_bill_to_party_id
        FROM csi_item_instances cii,
             hz_locations       hl,
             hz_party_sites     hp,
             hz_party_site_uses hpsu,
             hz_parties         h,
             hz_cust_accounts   hc,
             hz_locations       hl1,
             hz_party_sites     hp1,
             hz_party_site_uses hpsu1,
             hz_parties         h1,
             hz_cust_accounts   hc1
       WHERE cii.owner_party_id = h.party_id
         AND cii.owner_party_account_id = hc.cust_account_id
         AND hl.location_id = hp.location_id
         AND h.party_id = hp.party_id
         AND hc.party_id = h.party_id
         AND hpsu.party_site_id = hp.party_site_id
         AND hpsu.primary_per_type = 'Y'
         AND hpsu.site_use_type = 'SHIP_TO'
         AND (hpsu.end_date IS NULL OR hpsu.end_date > SYSDATE)
         AND hpsu.status(+) = 'A'
         AND cii.owner_party_id = h1.party_id
         AND cii.owner_party_account_id = hc1.cust_account_id
         AND hl1.location_id = hp1.location_id
         AND h1.party_id = hp1.party_id
         AND hc1.party_id = h1.party_id
         AND hpsu1.party_site_id = hp1.party_site_id
         AND hpsu1.primary_per_type = 'Y'
         AND hpsu1.site_use_type = 'BILL_TO'
         AND (hpsu1.end_date IS NULL OR hpsu1.end_date > SYSDATE)
         AND hpsu1.status(+) = 'A'
         AND cii.instance_id = p_instance_id;
    EXCEPTION
      WHEN OTHERS THEN
        l_bill_to_site_id     := NULL;
        l_bill_to_site_use_id := NULL;
        l_bill_account_id     := NULL;
        l_bill_to_party_id    := NULL;
        l_ship_to_site_id     := NULL;
        l_ship_to_site_use_id := NULL;
        l_ship_account_id     := NULL;
        l_ship_to_party_id    := NULL;
      
        fnd_file.put_line(fnd_file.log,
                          'ERR - Customer data Query: Please check instance SHIP_TO or BILL_TO address validation - Instance_id - ' ||
                          p_instance_id);
        errbuf := 'ERR - Customer data Query: Please check instance SHIP_TO or BILL_TO address validation - ' ||
                  substr(SQLERRM, 1, 240);
        RAISE invalid_request;
    END;
  
    -- Incident Type and Business Process 
    BEGIN
    
      SELECT cit.business_process_id
        INTO x_business_process_id
        FROM cs_incident_types_vl cit
       WHERE cit.incident_type_id = 11007; -- preventive maintenance
    
    EXCEPTION
      WHEN OTHERS THEN
        x_return_status := fnd_api.g_ret_sts_error;
        errbuf          := 'ERR - Type Query: ' || substr(SQLERRM, 1, 240);
        RAISE invalid_request;
    END;
  
    -- Time Zone 
    BEGIN
      cs_tz_get_details_pvt.customer_preferred_time_zone(p_incident_id            => NULL,
                                                         p_task_id                => NULL,
                                                         p_resource_id            => NULL,
                                                         p_cont_pref_time_zone_id => NULL,
                                                         p_incident_location_id   => l_location_id,
                                                         p_incident_location_type => l_location_type_code,
                                                         --p_contact_party_id       => l_relationship_party_id, -- ??
                                                         p_customer_id   => l_customer_id,
                                                         x_timezone_id   => l_timezone_id,
                                                         x_timezone_name => l_timezone_name);
    
    END; -- Time Zone 
  
    -- Contract 
    BEGIN
      x_msg_data := NULL;
      l_msg_data := NULL;
      cs_cont_get_details_pvt.get_contract_lines(p_api_version         => 1.0,
                                                 p_init_msg_list       => 'T',
                                                 p_contract_number     => NULL,
                                                 p_service_line_id     => NULL,
                                                 p_customer_id         => p_party_id,
                                                 p_site_id             => NULL,
                                                 p_customer_account_id => l_customer_id,
                                                 p_system_id           => l_system_id,
                                                 p_inventory_item_id   => l_inventory_item_id,
                                                 p_customer_product_id => p_instance_id,
                                                 p_request_date        => SYSDATE,
                                                 p_business_process_id => x_business_process_id,
                                                 p_severity_id         => 2, -- Medium
                                                 p_time_zone_id        => l_timezone_id,
                                                 p_calc_resptime_flag  => 'Y',
                                                 p_validate_flag       => 'Y',
                                                 p_dates_in_input_tz   => 'N',
                                                 p_incident_date       => SYSDATE,
                                                 x_ent_contracts       => t_ent_contracts,
                                                 x_return_status       => x_return_status,
                                                 x_msg_count           => l_msg_count,
                                                 x_msg_data            => l_msg_data);
    
      IF x_return_status != fnd_api.g_ret_sts_success THEN
        IF (fnd_msg_pub.count_msg > 0) THEN
          FOR c IN 1 .. fnd_msg_pub.count_msg LOOP
            fnd_msg_pub.get(p_msg_index     => c,
                            p_encoded       => 'F',
                            p_data          => l_msg_data,
                            p_msg_index_out => l_msg_index_out);
            x_msg_data := x_msg_data || l_msg_data || chr(10);
          END LOOP;
        ELSE
          x_msg_data := l_msg_data;
          dbms_output.put_line('Error - ' || substr(x_msg_data, 1, 240));
          fnd_file.put_line(fnd_file.log,
                            'Error - cs_cont_get_details_pvt.get_contract_lines - ' ||
                            substr(x_msg_data, 1, 240));
        END IF;
      END IF; -- return get_contract_lines
    END; -- Contract
  
    -- Assign Record 
    r_service_request_rec.inventory_org_id       := l_organization_id; -- 
    r_service_request_rec.request_date           := SYSDATE;
    r_service_request_rec.incident_occurred_date := SYSDATE;
  
    r_service_request_rec.type_id        := 11007; -- Preventive Maintenance
    r_service_request_rec.status_id      := 113; -- New
    r_service_request_rec.severity_id    := 2; -- Medium
    r_service_request_rec.urgency_id     := 2; -- Medium
    r_service_request_rec.owner_group_id := l_group_id; -- 
    r_service_request_rec.group_type     := 'RS_GROUP';
    r_service_request_rec.owner_id       := l_owner_resource_id;
    r_service_request_rec.resource_type  := 'RS_EMPLOYEE';
    r_service_request_rec.summary        := 'Preventive Maintenance Activity';
    --r_service_request_rec.publish_flag           := 'N';
    r_service_request_rec.caller_type         := 'ORGANIZATION';
    r_service_request_rec.customer_id         := p_party_id;
    r_service_request_rec.account_id          := l_customer_id;
    r_service_request_rec.customer_product_id := p_instance_id;
  
    r_service_request_rec.bill_to_account_id  := l_bill_account_id;
    r_service_request_rec.bill_to_party_id    := l_bill_to_party_id;
    r_service_request_rec.bill_to_site_id     := l_bill_to_site_id;
    r_service_request_rec.bill_to_site_use_id := l_bill_to_site_use_id;
    r_service_request_rec.ship_to_account_id  := l_ship_account_id;
    r_service_request_rec.ship_to_party_id    := l_ship_to_party_id;
    r_service_request_rec.ship_to_site_id     := l_ship_to_site_id;
    r_service_request_rec.ship_to_site_use_id := l_ship_to_site_use_id;
    --r_service_request_rec.install_site_id        := l_install_location_id; 
  
    r_service_request_rec.verify_cp_flag := 'N';
  
    r_service_request_rec.category_set_id       := xxinv_utils_pkg.get_default_category_set_id;
    r_service_request_rec.category_id           := l_category_id;
    r_service_request_rec.language              := 'US';
    r_service_request_rec.inventory_item_id     := l_inventory_item_id;
    r_service_request_rec.current_serial_number := p_serial_number;
    r_service_request_rec.inv_item_revision     := l_item_rev;
    r_service_request_rec.product_revision      := l_item_rev;
    r_service_request_rec.system_id             := l_system_id;
    r_service_request_rec.problem_code          := 'XXCS_PM';
  
    r_service_request_rec.request_attribute_1  := l_category_id;
    r_service_request_rec.external_attribute_1 := p_cs_region;
    r_service_request_rec.external_attribute_2 := NULL;
    r_service_request_rec.external_attribute_8 := -999;
    r_service_request_rec.external_attribute_7 := 'N/A';
  
    r_service_request_rec.sr_creation_channel      := 'AUTOMATIC';
    r_service_request_rec.last_update_channel      := 'AUTOMATIC';
    r_service_request_rec.creation_program_code    := 'CSXSRISR';
    r_service_request_rec.last_update_program_code := 'CSXSRISR';
    r_service_request_rec.incident_location_type   := 'HZ_PARTY_SITE';
    r_service_request_rec.incident_location_id     := l_location_id;
  
    BEGIN
      -- api
      r_service_request_rec.contract_service_id := t_ent_contracts(1)
                                                   .service_line_id;
      r_service_request_rec.contract_id         := t_ent_contracts(1)
                                                   .contract_id;
      r_service_request_rec.coverage_type       := t_ent_contracts(1)
                                                   .coverage_type_code;
      r_service_request_rec.cust_po_number      := t_ent_contracts(1)
                                                   .service_po_number;
      r_service_request_rec.obligation_date     := t_ent_contracts(1)
                                                   .exp_reaction_time; -- Open Date
    
    EXCEPTION
      WHEN OTHERS THEN
        NULL;
    END;
  
    fnd_msg_pub.initialize;
    x_return_status := NULL;
    l_msg_count     := NULL;
    l_msg_data      := NULL;
    l_msg_index_out := NULL;
    x_msg_data      := NULL;
  
    cs_servicerequest_pub.create_servicerequest(p_api_version         => 4.0,
                                                p_init_msg_list       => fnd_api.g_true,
                                                p_commit              => fnd_api.g_false,
                                                x_return_status       => x_return_status,
                                                x_msg_count           => l_msg_count,
                                                x_msg_data            => l_msg_data,
                                                p_resp_appl_id        => fnd_profile.value('RESP_APPL_ID'),
                                                p_resp_id             => fnd_profile.value('RESP_ID'),
                                                p_user_id             => fnd_profile.value('USER_ID'),
                                                p_login_id            => NULL,
                                                p_org_id              => p_org_id,
                                                p_service_request_rec => r_service_request_rec,
                                                p_notes               => t_notes_table,
                                                p_contacts            => t_contacts_table,
                                                p_auto_assign         => 'N',
                                                p_auto_generate_tasks => 'N',
                                                x_sr_create_out_rec   => o_sr_create_out_rec);
  
    IF x_return_status != fnd_api.g_ret_sts_success THEN
      FOR i IN 1 .. fnd_msg_pub.count_msg LOOP
        fnd_msg_pub.get(p_msg_index     => i,
                        p_encoded       => 'F',
                        p_data          => l_msg_data,
                        p_msg_index_out => l_msg_index_out);
        x_msg_data := x_msg_data || l_msg_data || chr(10);
      END LOOP;
      fnd_file.put_line(fnd_file.log,
                        'Error - cs_servicerequest_pub.create_servicerequest - ' ||
                        substr(x_msg_data, 1, 240));
      errbuf            := nvl(x_msg_data, 'Error create SR');
      retcode           := 1;
      p_incident_number := NULL;
      p_incident_id     := NULL;
      p_item_id         := l_inventory_item_id;
      ROLLBACK;
    ELSE
      x_msg_data        := nvl(l_msg_data, 'Success create SR');
      p_incident_number := o_sr_create_out_rec.request_number;
      p_incident_id     := o_sr_create_out_rec.request_id;
      p_item_id         := l_inventory_item_id;
      p_location_id     := l_location_id;
      fnd_file.put_line(fnd_file.log,
                        'Success - SR -    ' ||
                        o_sr_create_out_rec.request_number);
      fnd_file.put_line(fnd_file.log,
                        'Success - SR id - ' ||
                        o_sr_create_out_rec.request_id);
      fnd_file.put_line(fnd_file.log,
                        'Serial Number -   ' || p_serial_number);
      errbuf := x_msg_data;
    END IF; -- api success
  
  EXCEPTION
    WHEN invalid_request THEN
      retcode           := 1;
      p_incident_number := NULL;
      p_incident_id     := NULL;
      p_item_id         := l_inventory_item_id;
      p_location_id     := l_location_id;
    WHEN OTHERS THEN
      p_incident_number := NULL;
      p_incident_id     := NULL;
      p_location_id     := l_location_id;
      p_item_id         := l_inventory_item_id;
      retcode           := 1;
      errbuf            := 'GEN EXC - create_pm_service_request - ' ||
                           substr(SQLERRM, 1, 240);
  END create_pm_service_request;

  --------------------------------------------------------------------
  -- name:            create_pm_task
  -- create by:       Dalit A. Raviv
  -- Revision:        1.0
  -- creation date:   26/03/2012 
  --------------------------------------------------------------------
  -- purpose :        Cust- 484 -> SR Preventive Maintenance Auto Creation
  --                  create task according to the template recomended from screen.
  --                          
  --------------------------------------------------------------------
  -- ver  date        name             desc
  -- 1.0  26/03/2012  Dalit A. Raviv   initial build
  --------------------------------------------------------------------
  PROCEDURE create_pm_task(errbuf        OUT VARCHAR2,
                           retcode       OUT VARCHAR2,
                           p_template_id IN NUMBER,
                           p_incident_id IN NUMBER,
                           p_location_id IN NUMBER,
                           p_task_id     OUT NUMBER) IS
    l_return_status         VARCHAR2(1) := NULL;
    l_msg_count             NUMBER := NULL;
    l_msg_data              VARCHAR2(1000) := NULL;
    x_msg_data              VARCHAR2(1000) := NULL;
    l_task_id               NUMBER := NULL;
    l_msg_index_out         NUMBER := NULL;
    l_task_type_id          NUMBER := NULL;
    l_task_status_id        NUMBER := NULL;
    l_task_priority_id      NUMBER := NULL;
    l_private_flag          VARCHAR2(1) := NULL;
    l_publish_flag          VARCHAR2(1) := NULL;
    l_planned_effort        NUMBER := NULL;
    l_planned_effort_uom    VARCHAR2(3) := NULL;
    l_restrict_closure_flag VARCHAR2(1) := NULL;
    l_template_group_name   VARCHAR2(80) := NULL;
    l_owner_group_id        NUMBER := NULL;
    --l_description           varchar2(1000) := null; 
    --l_item_desc             varchar2(240)  := null;
    --l_segment1              varchar2(40)   := null;
  
  BEGIN
    errbuf  := 'SUCCESS';
    retcode := 0;
    -- get from template - task required details
    BEGIN
      SELECT t.task_type_id,
             t.task_status_id,
             t.task_priority_id,
             t.private_flag,
             nvl(t.publish_flag, 'N'),
             t.planned_effort,
             t.planned_effort_uom,
             t.restrict_closure_flag,
             tt.template_group_name
        INTO l_task_type_id,
             l_task_status_id,
             l_task_priority_id,
             l_private_flag,
             l_publish_flag,
             l_planned_effort,
             l_planned_effort_uom,
             l_restrict_closure_flag,
             l_template_group_name
        FROM jtf_task_templates_b t, jtf_task_temp_groups_tl tt
       WHERE t.task_template_id = p_template_id --10140
         AND t.task_template_id = tt.task_template_group_id
         AND tt.language = 'US';
    EXCEPTION
      WHEN OTHERS THEN
        l_task_type_id          := 11003; -- On Site Support
        l_task_status_id        := 11001; -- New
        l_task_priority_id      := 3; -- Medium
        l_private_flag          := 'N';
        l_publish_flag          := 'N';
        l_planned_effort        := 2;
        l_planned_effort_uom    := 'HR'; -- Hour
        l_restrict_closure_flag := 'Y';
        l_template_group_name   := 'On Site Support';
    END;
    -- get from SR - owner group id
    BEGIN
      SELECT cia.owner_group_id
        INTO l_owner_group_id
        FROM cs_incidents_all_b cia
       WHERE cia.incident_id = p_incident_id;
    EXCEPTION
      WHEN OTHERS THEN
        l_owner_group_id := NULL;
    END;
    /*
    begin
      select msi.description, msi.segment1
      into   l_item_desc, l_segment1
      from   mtl_system_items_b msi
      where  msi.inventory_item_id = p_item_id
      and    msi.organization_id   = 91;
    end;*/
  
    --l_description := 'S/N: '||p_serial_number||'; Item: '||l_item_desc|| '; Problem: Preventive Maintenance'; 
  
    csf_tasks_pub.create_task(p_api_version             => 1.0, -- i n
                              p_init_msg_list           => fnd_api.g_false, -- i v
                              p_commit                  => fnd_api.g_false, -- i v
                              x_return_status           => l_return_status, -- o v
                              x_msg_count               => l_msg_count, -- o n
                              x_msg_data                => l_msg_data, -- o v
                              p_task_name               => l_template_group_name, -- i v
                              p_source_object_type_code => 'SR', -- i v
                              p_source_object_id        => p_incident_id, -- i n
                              p_task_type_id            => l_task_type_id, -- i n
                              p_task_status_id          => l_task_status_id, -- i n
                              p_task_priority_id        => l_task_priority_id, -- i n
                              p_private_flag            => l_private_flag, -- i v
                              p_publish_flag            => l_publish_flag, -- i v
                              p_planned_start_date      => SYSDATE, -- i d
                              p_planned_end_date        => SYSDATE + 7, -- i d
                              p_restrict_closure_flag   => l_restrict_closure_flag, -- i v
                              p_planned_effort          => l_planned_effort, -- i n
                              p_planned_effort_uom      => l_planned_effort_uom, -- i v
                              p_owner_type_code         => 'RS_GROUP', -- i v
                              p_owner_id                => l_owner_group_id, -- i n
                              p_address_id              => p_location_id, -- i n
                              --p_description        => l_description,         -- i v
                              --TASK_TIME_ZONE     => 'AGENT',
                              p_template_id       => p_template_id, -- i n
                              p_template_group_id => p_template_id, -- i n
                              x_task_id           => l_task_id -- o n
                              );
  
    IF l_return_status <> fnd_api.g_ret_sts_success THEN
      FOR i IN 1 .. fnd_msg_pub.count_msg LOOP
        fnd_msg_pub.get(p_msg_index     => i,
                        p_encoded       => 'F',
                        p_data          => l_msg_data,
                        p_msg_index_out => l_msg_index_out);
        x_msg_data := x_msg_data || l_msg_data || chr(10);
      END LOOP;
      fnd_file.put_line(fnd_file.log,
                        'Error - csf_tasks_pub.create_task - ' ||
                        substr(x_msg_data, 1, 240));
      errbuf    := nvl(x_msg_data, 'Error create task');
      retcode   := 1;
      p_task_id := NULL;
    ELSE
      --fnd_file.put_line(fnd_file.log,'Success - SR - '||o_sr_create_out_rec.request_number);
      fnd_file.put_line(fnd_file.log, 'Success - Task id - ' || l_task_id);
      errbuf    := nvl(x_msg_data, 'Success create SR and Task');
      retcode   := 0;
      p_task_id := l_task_id;
    END IF; -- api success
  EXCEPTION
    WHEN OTHERS THEN
      p_task_id := NULL;
      retcode   := 1;
      errbuf    := 'GEN EXC - create_pm_task - ' || substr(SQLERRM, 1, 240);
  END create_pm_task;

  --------------------------------------------------------------------
  -- name:            get_task_template_id
  -- create by:       Dalit A. Raviv
  -- Revision:        1.0
  -- creation date:   03/04/2012 
  --------------------------------------------------------------------
  -- purpose :        Cust- 484 -> SR Preventive Maintenance Auto Creation
  --                  function that get inventory item id and counter change
  --                  return the task_template id        
  --------------------------------------------------------------------
  -- ver  date        name             desc
  -- 1.0  03/04/2012  Dalit A. Raviv   initial build
  --------------------------------------------------------------------
  FUNCTION get_task_template_id(p_inventory_item_id IN NUMBER,
                                p_counter_change    IN NUMBER) RETURN NUMBER IS
  
    l_template_id NUMBER := NULL;
  
  BEGIN
    SELECT cpt.task_template_id
      INTO l_template_id
      FROM csp.csp_product_tasks cpt
     WHERE cpt.product_id = p_inventory_item_id
       AND p_counter_change BETWEEN nvl(to_number(cpt.attribute3), 9999999) AND
           nvl(to_number(cpt.attribute4), 9999999);
    --and    cpt.task_template_id     != 10020;
  
    RETURN l_template_id;
  
  EXCEPTION
    WHEN too_many_rows THEN
      RETURN NULL;
    WHEN OTHERS THEN
      RETURN NULL;
  END get_task_template_id;

  --------------------------------------------------------------------
  -- name:            get_sr_number
  -- create by:       Dalit A. Raviv
  -- Revision:        1.0
  -- creation date:   21/03/2012 
  --------------------------------------------------------------------
  -- purpose :        Cust- 484 -> SR Preventive Maintenance Auto Creation
  --                  function that get incident_date, serial number and
  --                  item_id and return SR number.
  --                  use at screen to know the last pm sr number 
  --                          
  --------------------------------------------------------------------
  -- ver  date        name             desc
  -- 1.0  18/03/2012  Dalit A. Raviv   initial build
  --------------------------------------------------------------------
  FUNCTION get_sr_number(p_incident_date     IN DATE,
                         p_instance_id       IN NUMBER,
                         p_inventory_item_id IN NUMBER) RETURN VARCHAR2 IS
  
    l_instance_number VARCHAR2(30);
  BEGIN
    SELECT ciab.incident_number
      INTO l_instance_number
      FROM cs_incidents_all_b ciab
     WHERE ciab.incident_date = p_incident_date -- to_date('04/04/2012 11:46:42','dd/mm/yyyy hh24:mi;ss') 
       AND ciab.inventory_item_id = p_inventory_item_id -- 19062
       AND ciab.incident_type_id = 11007 -- 'preventive maintenance'
       AND ciab.customer_product_id = p_instance_id -- 5293001
       AND ciab.incident_status_id != 104; -- 'cancelled'
  
    RETURN l_instance_number;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END;

  --------------------------------------------------------------------
  -- name:            create_sr_pm_by_batch
  -- create by:       Dalit A. Raviv
  -- Revision:        1.0
  -- creation date:   19/03/2012 
  --------------------------------------------------------------------
  -- purpose :        Cust- 484 -> SR Preventive Maintenance Auto Creation
  --                  procedure that will handle 
  --                  by loop on all rows that arrvied from screen
  --                  (entered to log tbl by batch_id)
  --                  call procedure create_pm_service_request that will create the PM         
  --------------------------------------------------------------------
  -- ver  date        name             desc
  -- 1.0  19/03/2012  Dalit A. Raviv   initial build
  --------------------------------------------------------------------
  PROCEDURE create_sr_pm_by_batch(errbuf     OUT VARCHAR2,
                                  retcode    OUT VARCHAR2,
                                  p_batch_id IN NUMBER) IS
    CURSOR get_pm_pop_c IS
      SELECT * FROM xxcs_sr_pm_log_tbl log WHERE log.batch_id = p_batch_id;
  
    l_err_code        VARCHAR2(10);
    l_err_desc        VARCHAR2(2500);
    l_incident_number VARCHAR2(100);
    l_item_id         NUMBER;
    l_incident_id     NUMBER;
    l_task_id         NUMBER;
    l_location_id     NUMBER;
  BEGIN
    errbuf  := 'SUCCESS';
    retcode := 0;
    --fnd_global.APPS_INITIALIZE(user_id => 1308, resp_id => 50557 ,resp_appl_id => 514);
    -- all rows that where marked at the screen and entered to log table.
  
    FOR get_pm_pop_r IN get_pm_pop_c LOOP
      l_err_code        := 0;
      l_err_desc        := NULL;
      l_incident_number := NULL;
      l_item_id         := NULL;
      l_incident_id     := NULL;
      l_location_id     := NULL;
      fnd_file.put_line(fnd_file.log, '----------------------- ');
      fnd_file.put_line(fnd_file.log,
                        'Serial Number - ' || get_pm_pop_r.serial_number);
      fnd_file.put_line(fnd_file.log,
                        'Instance Id   - ' || get_pm_pop_r.instance_id);
      create_pm_service_request(errbuf            => l_err_desc, -- o v
                                retcode           => l_err_code, -- o v
                                p_instance_id     => get_pm_pop_r.instance_id, -- i n
                                p_serial_number   => get_pm_pop_r.serial_number, -- i v
                                p_party_id        => get_pm_pop_r.party_id, -- i n
                                p_org_id          => get_pm_pop_r.org_id, -- i n
                                p_cs_region       => get_pm_pop_r.cs_region, -- i v
                                p_incident_number => l_incident_number, -- o v
                                p_incident_id     => l_incident_id, -- o n
                                p_item_id         => l_item_id, -- o n
                                p_location_id     => l_location_id -- o n
                                );
      IF l_err_code <> 0 THEN
        errbuf  := 'Error at one row';
        retcode := 1;
        ROLLBACK;
        -- update log table with error and rollback.
        handle_upd_log_tbl(p_batch_id        => p_batch_id, -- i n
                           p_entity_id       => get_pm_pop_r.entity_id, -- i n
                           p_status          => 'ERROR', -- i v
                           p_item_id         => l_item_id, -- i n
                           p_incident_number => l_incident_number, -- i v 
                           p_incident_id     => l_incident_id, -- i n
                           p_task_id         => NULL, -- i n
                           p_err_code        => l_err_code, -- i/o v
                           p_err_msg         => l_err_desc); -- i/o v
      
      ELSE
        -- call to procedure that create task by template.
        l_err_code := 0;
        l_err_desc := NULL;
        l_task_id  := NULL;
        create_pm_task(errbuf        => l_err_desc, -- o v
                       retcode       => l_err_code, -- o v
                       p_template_id => get_pm_pop_r.template_id, -- i n
                       p_incident_id => l_incident_id, -- i n
                       p_location_id => l_location_id, -- i n
                       p_task_id     => l_task_id); -- o n        
        IF l_err_code <> 0 THEN
          errbuf  := 'Error at one row';
          retcode := 1;
          ROLLBACK;
          -- update log table 
          handle_upd_log_tbl(p_batch_id        => p_batch_id, -- i n
                             p_entity_id       => get_pm_pop_r.entity_id, -- i n
                             p_status          => 'ERROR', -- i v
                             p_item_id         => l_item_id, -- i n
                             p_incident_number => NULL, -- i v 
                             p_incident_id     => NULL, -- i n
                             p_task_id         => l_task_id, -- i n
                             p_err_code        => l_err_code, -- i/o v
                             p_err_msg         => l_err_desc); -- i/o v
        
        ELSE
          -- success
          handle_upd_log_tbl(p_batch_id        => p_batch_id, -- i n
                             p_entity_id       => get_pm_pop_r.entity_id, -- i n
                             p_status          => 'SUCCESS', -- i v
                             p_item_id         => l_item_id, -- i n
                             p_incident_number => l_incident_number, -- i v 
                             p_incident_id     => l_incident_id, -- i n
                             p_task_id         => l_task_id, -- i n
                             p_err_code        => l_err_code, -- i/o v
                             p_err_msg         => l_err_desc); -- i/o v
          COMMIT;
        END IF;
      END IF; -- err_code                          
    END LOOP;
  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'GEN EXC - create_sr_pm_by_batch - ' ||
                 substr(SQLERRM, 1, 240);
      retcode := 1;
  END create_sr_pm_by_batch;

  --------------------------------------------------------------------
  --  name:            get_counter_reading
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   04/04/2012
  --------------------------------------------------------------------
  --  purpose:         Bring counter reading from IB by specific date
  --------------------------------------------------------------------
  --  ver  date        name             desc
  --  1.0  04/04/2012  Dalit A. Raviv   initial build
  --------------------------------------------------------------------
  FUNCTION get_counter_reading(p_date                  IN DATE,
                               p_printer_serial_number IN VARCHAR2,
                               p_inventory_item_id     IN NUMBER DEFAULT NULL)
    RETURN NUMBER IS
  
    l_counter_reading NUMBER := NULL;
  
  BEGIN
  
    SELECT nvl(MAX(t.counter_reading),0)
      INTO l_counter_reading
      FROM xxcs_counter_reading_v t
     WHERE t.serial_number        = p_printer_serial_number
       AND t.inventory_item_id    = nvl(p_inventory_item_id, t.inventory_item_id) -- 1.1 15/03/2012
       AND t.value_timestamp      <= p_date; --to_date('04/04/2012 11:46:42','dd/mm/yyyy hh24:mi:ss')
  
    RETURN l_counter_reading;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN null;
  END;

  --------------------------------------------------------------------
  --  name:            get_last_counter_reading
  --  create by:       Yoram Zamir / Vitaly K.
  --  Revision:        1.0
  --  creation date:   xx/xx/20xx
  --------------------------------------------------------------------
  --  purpose :        Disco Report
  --------------------------------------------------------------------
  --  ver  date        name             desc
  --  1.0  xx/xx/20xx  Yoram / Vitaly   initial build
  --  1.1  15/03/2012  Dalit A. Raviv   add parameter inventory_item_id
  --------------------------------------------------------------------
  FUNCTION get_last_counter_reading(p_printer_serial_number IN VARCHAR2,
                                    p_inventory_item_id     IN NUMBER DEFAULT NULL)
    RETURN NUMBER IS
    /*CURSOR get_last_counter_reading IS
      SELECT t.counter_reading, t.value_timestamp
        FROM xxcs_counter_reading_v t
       WHERE t.serial_number        = p_printer_serial_number
         AND t.inventory_item_id    = nvl(p_inventory_item_id, t.inventory_item_id)
       ORDER BY 2 DESC;*/
  
    l_last_counter_reading NUMBER := 0;
    missing_parameter EXCEPTION;
  
  BEGIN
  
    IF p_printer_serial_number IS NULL THEN
      RAISE missing_parameter;
    END IF;
  
    SELECT nvl(MAX(t.counter_reading),0)
      INTO l_last_counter_reading
      FROM xxcs_counter_reading_v t
     WHERE t.serial_number        = p_printer_serial_number
       AND t.inventory_item_id    = nvl(p_inventory_item_id, t.inventory_item_id);
  
    RETURN l_last_counter_reading;
  
  EXCEPTION
    WHEN missing_parameter THEN
      RETURN null;
    WHEN OTHERS THEN
      RETURN null;
  END get_last_counter_reading;

  --------------------------------------------------------------------
  -- name:            refresh_material_view
  -- create by:       Dalit A. Raviv
  -- Revision:        1.0
  -- creation date:   22/04/2012 
  --------------------------------------------------------------------
  -- purpose :        Cust- 484 -> SR Preventive Maintenance Auto Creation
  --                  refresh material view      
  --------------------------------------------------------------------
  -- ver  date        name             desc
  -- 1.0  22/04/2012  Dalit A. Raviv   initial build
  -------------------------------------------------------------------- 
  PROCEDURE refresh_material_view(errbuf  OUT VARCHAR2,
                                  retcode OUT VARCHAR2) IS
  
  BEGIN
    errbuf  := NULL;
    retcode := 0;
    dbms_snapshot.refresh('xxcs_preventive_maintenance_mv', 'C');
  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'GEN EXE - Can not refresh mv - ' ||
                 substr(SQLERRM, 1, 240);
      retcode := 1;
  END refresh_material_view;
  --------------------------------------------------------------------
  -- name:            get_instance_staus_id
  -- create by:       Dalit A. Raviv
  -- Revision:        1.0
  -- creation date:   24/05/2012 
  --------------------------------------------------------------------
  -- purpose :        get instance_id and return its status.                    
  --------------------------------------------------------------------
  -- ver  date        name             desc
  -- 1.0  24/05/2012  Dalit A. Raviv   initial build
  -------------------------------------------------------------------- 
  function get_instance_staus_id (p_instance_id in number) return number is
    
    l_instance_status_id number := null;
    
  begin
    select cis.instance_status_id
    into   l_instance_status_id
    from   csi_item_instances     cii,
           csi_instance_statuses  cis
    where  cii.instance_id        = p_instance_id 
    and    cis.instance_status_id = cii.instance_status_id;
    
    return l_instance_status_id;
  exception
    when others then return 1;
  end get_instance_staus_id;

  --------------------------------------------------------------------
  -- name:            main
  -- create by:       Dalit A. Raviv
  -- Revision:        1.0
  -- creation date:   18/03/2012 
  --------------------------------------------------------------------
  -- purpose :        Cust- 484 -> SR Preventive Maintenance Auto Creation
  --                  procedure that will handle 
  --                  1) by loop from all rows that arrvied from screen
  --                     enter to log table
  --                  2) call procedure (concurrent program) that will create the PM         
  --------------------------------------------------------------------
  -- ver  date        name             desc
  -- 1.0  18/03/2012  Dalit A. Raviv   initial build
  --------------------------------------------------------------------
  PROCEDURE main(errbuf      OUT VARCHAR2,
                 retcode     OUT VARCHAR2,
                 p_sr_pm_tbl t_sr_pm_tbl) IS
  
    l_err_code     VARCHAR2(10);
    l_err_desc     VARCHAR2(2500);
    l_sr_pm_rec    t_sr_pm_rec;
    l_batch_id     NUMBER;
    l_request_id   NUMBER := NULL;
    l_print_option BOOLEAN;
    l_printer_name VARCHAR2(150) := NULL;
  
  BEGIN
    errbuf  := NULL;
    retcode := 0;
    -- get batch_id
    SELECT xxcs_sr_pm_log_batch_s.nextval INTO l_batch_id FROM dual;
    -- 1) enter all marked rows at screen to log table
    FOR i IN p_sr_pm_tbl.first .. p_sr_pm_tbl.last LOOP
      l_err_code := 0;
      l_err_desc := NULL;
    
      l_sr_pm_rec             := p_sr_pm_tbl(i);
      l_sr_pm_rec.log_code    := l_err_code;
      l_sr_pm_rec.log_message := l_err_desc;
      handle_log_tbl(p_log_rec  => l_sr_pm_rec, -- i t_sr_pm_rec,
                     p_batch_id => l_batch_id,
                     p_status   => 'NEW',
                     p_err_code => l_err_code, -- o v
                     p_err_msg  => l_err_desc); -- o v                                  
    END LOOP;
    --
    -- Set printer and print option
    --
    l_printer_name := fnd_profile.value('PRINTER');
    l_print_option := fnd_request.set_print_options(l_printer_name,
                                                    '',
                                                    '0',
                                                    TRUE,
                                                    'N');
    IF l_print_option = TRUE THEN
      -- 2) to free the screen i needed to call concurrent program that will handle
      --    the call to the SR create API by loop on all rows entered to log tbl at tsage 1 
      --    XXCS_SR_PM = xxcs_preventive_maintenance.create_sr_pm_by_batch
      l_request_id := fnd_request.submit_request(application => 'XXOBJT',
                                                 program     => 'XXCS_SR_PM',
                                                 description => NULL,
                                                 start_time  => NULL,
                                                 sub_request => FALSE,
                                                 argument1   => l_batch_id);
    
      IF l_request_id = 0 THEN
      
        fnd_file.put_line(fnd_file.log,
                          '--------------------------------------------------');
        fnd_file.put_line(fnd_file.log,
                          '-- Failed Run proceduere create_sr_pm_by_batch  --');
        errbuf  := SQLCODE;
        retcode := SQLERRM;
      ELSE
        fnd_file.put_line(fnd_file.log,
                          '-------------------- Success ---------------------');
        -- must commit the request
        COMMIT;
      END IF; -- request_id
    ELSE
      --
      -- Didn't find printer
      --
      fnd_file.put_line(fnd_file.log,
                        '--------------------------------------------------');
      fnd_file.put_line(fnd_file.log,
                        '-------------- Can not Find Printer --------------');
      fnd_file.put_line(fnd_file.log,
                        '--------------------------------------------------');
      errbuf  := SQLCODE;
      retcode := SQLERRM;
    END IF; -- l_print_option
  
  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'GEN EXC - Main - ' || substr(SQLERRM, 1, 240);
      retcode := 1;
  END main;

END xxcs_preventive_maintenance;
/
