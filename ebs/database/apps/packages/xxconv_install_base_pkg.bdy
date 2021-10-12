CREATE OR REPLACE PACKAGE BODY xxconv_install_base_pkg IS
  
  g_user_id NUMBER;

  --------------------------------------------------------------------
  --  name:            create_system
  --  create by:       XXX
  --  Revision:        1.0
  --  creation date:   XX.XX.XXXX
  --------------------------------------------------------------------
  --  purpose :        Handle write to log tbl
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  XX.XX.XXXX  XXX               initial build
  --------------------------------------------------------------------
  PROCEDURE create_system(p_org_id          IN NUMBER,
                          p_system_name     IN VARCHAR2,
                          p_cust_account_id IN NUMBER,
                          p_type_flag       IN VARCHAR2,
                          p_system_id       IN OUT NUMBER,
                          p_err_code        OUT VARCHAR2,
                          p_err_msg         OUT VARCHAR2) IS
   
    l_system_rec    csi_datastructures_pub.system_rec := csi_generic_grp.ui_system_rec;
    l_txn_rec       csi_datastructures_pub.transaction_rec := csi_generic_grp.ui_transaction_rec;
    --l_system_id     NUMBER;
    l_system_type   VARCHAR2(50);
    l_return_status VARCHAR2(1);
    l_msg_count     NUMBER;
    l_msg_data      VARCHAR2(2000);
    l_msg_index_out NUMBER;
   
  BEGIN
   
    --fnd_global.apps_initialize(18598,5303,514); -- pass in user_id, responsibility_id, and application_id
    fnd_global.apps_initialize(g_user_id /*26585*/, 22971, 542);
       
    p_err_code := fnd_api.g_ret_sts_success;
       
    SELECT lookup_code
    INTO   l_system_type
    FROM   csi_lookups
    WHERE  lookup_type = 'CSI_SYSTEM_TYPE' 
    and    tag = p_type_flag; -- D - Direct, EC - End Customer
       
    SELECT csi_systems_s.NEXTVAL INTO p_system_id FROM dual;
       
    --   
    l_system_rec.system_id        := p_system_id;
    l_system_rec.customer_id      := p_cust_account_id;
    l_system_rec.system_type_code := l_system_type;
    l_system_rec.system_number    := p_system_id;
    l_system_rec.parent_system_id := NULL;
    /*l_system_rec.ship_to_contact_id   := :cs_system.ship_to_contact_id;
      l_system_rec.bill_to_contact_id   := :cs_system.bill_to_contact_id;
      l_system_rec.technical_contact_id := :cs_system.technical_contact_id;
      l_system_rec.service_admin_contact_id := :cs_system.service_admin_contact_id;
      l_system_rec.ship_to_site_use_id  := :cs_system.ship_to_site_use_id;
      l_system_rec.bill_to_site_use_id  := :cs_system.bill_to_site_use_id;
      l_system_rec.install_site_use_id  := :cs_system.install_site_use_id;
      l_system_rec.coterminate_day_month  := :cs_system.coterminate_day_month;
      l_system_rec.autocreated_from_system_id := :cs_system.autocreated_from_system_id;
      l_system_rec.config_system_type   := :cs_system.config_system_type_code;
      l_system_rec.start_date_active    := :cs_system.start_date_active;
      l_system_rec.end_date_active    := :cs_system.end_date_active;
      l_system_rec.context      := :cs_system.context;
      l_system_rec.attribute1     := :cs_system.attribute1;
      l_system_rec.attribute2     := :cs_system.attribute2;
      l_system_rec.attribute3     := :cs_system.attribute3;
      l_system_rec.attribute4     := :cs_system.attribute4;
      l_system_rec.attribute5     := :cs_system.attribute5;
      l_system_rec.attribute6     := :cs_system.attribute6;
      l_system_rec.attribute7     := :cs_system.attribute7;
      l_system_rec.attribute8     := :cs_system.attribute8;
      l_system_rec.attribute9     := :cs_system.attribute9;
      l_system_rec.attribute10    := :cs_system.attribute10;
      l_system_rec.attribute11    := :cs_system.attribute11;
      l_system_rec.attribute12    := :cs_system.attribute12;
      l_system_rec.attribute13    := :cs_system.attribute13;
      l_system_rec.attribute14    := :cs_system.attribute14;
      l_system_rec.attribute15    := :cs_system.attribute15;
    */
    l_system_rec.object_version_number := 1;
    l_system_rec.NAME                  := p_system_name;
    --l_system_rec.description    := :cs_system.description;
    l_system_rec.operating_unit_id := p_org_id;
       
    l_txn_rec.transaction_type_id     := 1;
    l_txn_rec.source_transaction_date := SYSDATE;
       
    csi_systems_pub.create_system(p_api_version      => 1.0,
                                  p_commit           => 'T',
                                  p_init_msg_list    => 'T',
                                  p_validation_level => 100,
                                  p_system_rec       => l_system_rec,
                                  p_txn_rec          => l_txn_rec,
                                  x_system_id        => p_system_id,
                                  x_return_status    => l_return_status,
                                  x_msg_count        => l_msg_count,
                                  x_msg_data         => l_msg_data);
       
    IF l_return_status != 'S' THEN
      p_err_code := l_return_status;
      IF (fnd_msg_pub.count_msg > 0) THEN
        FOR i IN 1 .. fnd_msg_pub.count_msg LOOP
          fnd_msg_pub.get(p_msg_index     => i,
                         p_encoded       => 'F',
                         p_data          => l_msg_data,
                         p_msg_index_out => l_msg_index_out);
          p_err_msg := p_err_msg || l_msg_data;       
        END LOOP;
      END IF;
    ELSE
      COMMIT;
    END IF;
  END create_system;

  --------------------------------------------------------------------
  --  name:            create_instance
  --  create by:       XXX
  --  Revision:        1.0
  --  creation date:   XX.XX.XXXX
  --------------------------------------------------------------------
  --  purpose :        Handle write to log tbl
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  XX.XX.XXXX  XXX               initial build
  --------------------------------------------------------------------
  PROCEDURE create_instance(errbuf OUT VARCHAR2, retcode OUT VARCHAR2) IS
   
    CURSOR cr_ib_details IS
       SELECT *
       FROM   xxobjt_conv_ib_instance s
       WHERE  s.error_code_flag = 'N'
       ORDER BY instance_name;
   
    v_instance_id              NUMBER;
    --v_instance_party_id        NUMBER;
    --v_ip_account_id            NUMBER;
    --l_commit                   VARCHAR2(5);
    l_init_msg_lst             VARCHAR2(500) := NULL;
    l_validation_level         NUMBER := NULL;
    l_ext_attrib_values        csi_datastructures_pub.extend_attrib_values_tbl;
    --l_success                  VARCHAR2(1) := 'T';
    l_instance_rec             csi_datastructures_pub.instance_rec;
    l_party_tbl                csi_datastructures_pub.party_tbl;
    l_account_tbl              csi_datastructures_pub.party_account_tbl;
    --l_ext_attrib_values_tbl    csi_datastructures_pub.extend_attrib_values_tbl;
    l_pricing_attrib_tbl       csi_datastructures_pub.pricing_attribs_tbl;
    l_org_assignments_tbl      csi_datastructures_pub.organization_units_tbl;
    l_asset_assignment_tbl     csi_datastructures_pub.instance_asset_tbl;
    l_txn_rec                  csi_datastructures_pub.transaction_rec;
    --l_txn_rec_chi              csi_datastructures_pub.transaction_rec;
    --l_relationship_tbl         csi_datastructures_pub.ii_relationship_tbl;
    l_ext_attrib_values_miss   csi_datastructures_pub.extend_attrib_values_tbl;
    l_txn_tbl                  csi_datastructures_pub.transaction_tbl;
    l_txn_tbl_miss             csi_datastructures_pub.transaction_tbl;
    l_counter_reading_tbl      csi_ctr_datastructures_pub.counter_readings_tbl;
    --l_counter_reading_tbl_miss csi_ctr_datastructures_pub.counter_readings_tbl;
    l_counter_prop_read_tbl    csi_ctr_datastructures_pub.ctr_property_readings_tbl;
    l_return_status            VARCHAR2(2000) := NULL;
    l_msg_count                NUMBER := NULL;
    l_msg_data                 VARCHAR2(2000) := NULL;
    v_system_id                NUMBER(10) := NULL;
    --v_subject_id               NUMBER(10);
    l_msg_index_out            NUMBER := NULL;
    --v_relationship_id          NUMBER;
    v_counter                  NUMBER(10) := 0;
    v_act_start_date           DATE;
    v_party_id                 NUMBER;
    --v_object_qty               NUMBER(10);
    --v_att_value_id             NUMBER(10);
    --v_inst_loc_type            VARCHAR2(50);
    v_inst_loc_id              NUMBER(10);
    v_organization_id          NUMBER;
    v_item_id                  NUMBER;
    v_instance_status_id       NUMBER;
    v_party_site_id            NUMBER;
    v_owner_party_id           NUMBER;
    --v_install_party_site_id    NUMBER;
    v_owner_account_id         NUMBER;
    v_account_id               NUMBER;
    v_mfg_serial_number_flag   VARCHAR2(1);
    l_revision                 VARCHAR2(5);
    l_acct_class_code          VARCHAR2(30);
    l_instance_type_code       VARCHAR2(20);
    invalid_instance           EXCEPTION;
    l_error_msg                VARCHAR2(500);
    l_uom_code                 VARCHAR2(3);
    l_org_id                   NUMBER;
    v_party_seq_id             NUMBER;
    v_account_seq_id           NUMBER;
    l_warning_msg              VARCHAR2(500);
    l_type_flag                VARCHAR2(2);
    l_instance_ou_id           NUMBER;
    l_attribute_value_id       NUMBER;
    l_counter_reading_id       NUMBER;
    l_counter_id               NUMBER;
    l_ship_to                  NUMBER;
    l_bill_to                  NUMBER;
    l_ext_attr_ind             NUMBER;
   
  BEGIN
    errbuf  := null;
    retcode := 0;
    
    SELECT user_id
    INTO   g_user_id
    FROM   fnd_user
    WHERE  user_name = 'CONVERSION';
   
    fnd_global.apps_initialize(g_user_id, 22971, 542);
   
    FOR i IN cr_ib_details LOOP
      
    BEGIN
      v_counter            := v_counter + 1;
      l_return_status      := fnd_api.g_ret_sts_success;
      l_msg_count          := NULL;
      l_msg_data           := NULL;
      l_msg_index_out      := NULL;
      l_warning_msg        := NULL;
      l_type_flag          := NULL;
      l_error_msg          := NULL;
      v_organization_id    := NULL;
      l_org_id             := NULL;
      v_act_start_date     := NULL;
      v_owner_party_id     := NULL;
      v_owner_account_id   := NULL;
      l_bill_to            := NULL;
      l_ship_to            := NULL;
      v_party_site_id      := NULL;
      v_inst_loc_id        := NULL;
      v_party_id           := NULL;
      v_account_id         := NULL;
      v_system_id          := NULL;
      v_item_id            := NULL;
      l_uom_code           := NULL;
      v_instance_status_id := NULL;
      l_instance_type_code := NULL;
      l_acct_class_code    := NULL;
      l_counter_id         := NULL;
             
      BEGIN
         SELECT organization_id, operating_unit
           INTO v_organization_id, l_org_id
           FROM org_organization_definitions
          WHERE organization_name = i.organization;
      EXCEPTION
         WHEN OTHERS THEN
            l_error_msg := 'invalid organization';
            RAISE invalid_instance;
      END;
             
      IF nvl(i.active_start_date, SYSDATE + 1) > SYSDATE THEN
         v_act_start_date := least(SYSDATE,
                                   nvl(i.install_date, SYSDATE));
      ELSE
         v_act_start_date := i.active_start_date;
      END IF;
             
      BEGIN
         SELECT hca.party_id,
                hca.cust_account_id,
                (SELECT bill_to.site_use_id
                   FROM hz_cust_site_uses_all  bill_to,
                        hz_cust_acct_sites_all b
                  WHERE bill_to.cust_acct_site_id =
                        b.cust_acct_site_id AND
                        b.cust_account_id = hca.cust_account_id AND
                        bill_to.site_use_code = 'BILL_TO' AND
                        primary_flag = 'Y' and rownum < 2) bill_to_id,
                (SELECT ship_to.site_use_id
                   FROM hz_cust_site_uses_all  ship_to,
                        hz_cust_acct_sites_all b
                  WHERE ship_to.cust_acct_site_id =
                        b.cust_acct_site_id AND
                        b.cust_account_id = hca.cust_account_id AND
                        ship_to.site_use_code = 'SHIP_TO' AND
                        rownum < 2) ship_to_id
           INTO v_owner_party_id,
                v_owner_account_id,
                l_bill_to,
                l_ship_to
           FROM hz_cust_accounts hca, hz_parties hp /*,
                                                                                                                                                                                                                                                                                                                                                                                        hz_organization_profiles hop*/
          WHERE /*(hp.party_name = i.party_name OR
                                                                                                                                                                                                                                                                                                                                                                                        hop.organization_name_phonetic = i.party_name) AND*/
          hp.party_name = i.party_name AND
         -- hp.party_id = hop.party_id AND
          hp.party_id = hca.party_id AND
          hca.status = 'A';
                
         IF l_bill_to IS NULL OR l_ship_to IS NULL THEN
            l_error_msg := 'missing ship to/bill to';
            -- RAISE invalid_instance;
         END IF;
                
      EXCEPTION
         WHEN no_data_found THEN
            l_error_msg        := 'Invalid party ';
            v_owner_party_id   := NULL;
            v_owner_account_id := NULL;
            RAISE invalid_instance;
         WHEN too_many_rows THEN
            l_error_msg        := 'Party has more than one bill to';
            v_owner_party_id   := NULL;
            v_owner_account_id := NULL;
            RAISE invalid_instance;
      END;
             
      BEGIN
         SELECT hcas.party_site_id,
                hcas.party_site_id,
                hca.party_id,
                hca.cust_account_id
           INTO v_party_site_id,
                v_inst_loc_id,
                v_party_id,
                v_account_id
           FROM hz_cust_accounts hca, hz_cust_acct_sites_all hcas
          WHERE upper(hcas.orig_system_reference) =
                upper(i.party_site_number) AND
                hca.cust_account_id = v_owner_account_id AND
                hca.cust_account_id = hcas.cust_account_id;
                
         l_type_flag := 'D';
                
      EXCEPTION
         WHEN no_data_found THEN
                   
            l_type_flag := 'EC';
                   
            BEGIN
               SELECT hcas.party_site_id,
                      hcas.party_site_id,
                      hca.party_id,
                      hca.cust_account_id
                 INTO v_party_site_id,
                      v_inst_loc_id,
                      v_party_id,
                      v_account_id
                 FROM hz_cust_accounts       hca,
                      hz_cust_acct_sites_all hcas
                WHERE upper(hcas.orig_system_reference) =
                      upper(i.party_site_number) AND
                      hca.cust_account_id = hcas.cust_account_id;
                      
               BEGIN
                  SELECT 'Relation: ' || r.relationship_code
                    INTO l_warning_msg
                    FROM hz_relationships r
                   WHERE object_id = v_owner_party_id AND
                         r.object_type = 'ORGANIZATION' AND
                         r.object_table_name = 'HZ_PARTIES' AND
                         r.subject_id = v_party_id AND
                         r.subject_type = 'ORGANIZATION' AND
                         r.subject_table_name = 'HZ_PARTIES' AND
                         rownum < 2;
               EXCEPTION
                  WHEN no_data_found THEN
                     l_warning_msg := NULL;
               END;
            EXCEPTION
               WHEN OTHERS THEN
                  l_error_msg := 'invalid location';
                  --  RAISE invalid_instance;
            END;
         WHEN OTHERS THEN
            l_error_msg := 'invalid location';
            RAISE invalid_instance;
      END;
             
      IF i.system IS NULL THEN
         v_system_id := NULL;
                
      ELSE
         BEGIN
            SELECT system_id
              INTO v_system_id
              FROM csi_systems_vl s
             WHERE s.NAME = i.system;
         EXCEPTION
            WHEN no_data_found THEN
               create_system(p_org_id          => l_org_id,
                             p_system_name     => i.system,
                             p_cust_account_id => nvl(v_account_id,
                                                      v_owner_account_id),
                             p_type_flag       => l_type_flag,
                             p_system_id       => v_system_id,
                             p_err_code        => l_return_status,
                             p_err_msg         => l_error_msg);
               IF l_return_status != 'S' THEN
                  RAISE invalid_instance;
               END IF;
                      
         END;
      END IF;
             
      BEGIN
         SELECT inventory_item_id, primary_uom_code
           INTO v_item_id, l_uom_code
           FROM mtl_system_items_b
          WHERE segment1 = i.item AND
                organization_id = v_organization_id;
                
         SELECT MAX(revision)
           INTO l_revision
           FROM mtl_item_revisions_b
          WHERE inventory_item_id = v_item_id AND
                organization_id = v_organization_id;
      EXCEPTION
         WHEN OTHERS THEN
            l_error_msg := 'invalid item';
            RAISE invalid_instance;
                   
      END;
             
      BEGIN
         SELECT cis.instance_status_id
           INTO v_instance_status_id
           FROM csi_instance_statuses cis
          WHERE cis.NAME = i.instance_status;
      EXCEPTION
         WHEN OTHERS THEN
            l_error_msg := 'invalid status';
            RAISE invalid_instance;
      END;
             
      BEGIN
         SELECT lookup_code
           INTO l_instance_type_code
           FROM fnd_lookup_values_vl
          WHERE lookup_type = 'CSI_INST_TYPE_CODE' AND
                meaning = i.instance_type_code;
      EXCEPTION
         WHEN OTHERS THEN
            l_error_msg := 'invalid type';
            RAISE invalid_instance;
      END;
             
      BEGIN
         SELECT lookup_code
           INTO l_acct_class_code
           FROM fnd_lookup_values
          WHERE lookup_type = 'CSI_ACCOUNTING_CLASS_CODE' AND
                meaning = i.accounting_classification;
      EXCEPTION
         WHEN OTHERS THEN
            l_error_msg := 'invalid account class';
            RAISE invalid_instance;
      END;
             
      SELECT csi_item_instances_s.NEXTVAL
        INTO v_instance_id
        FROM dual;
      IF i.serial_number is null /*= NULL*/ THEN
         v_mfg_serial_number_flag := 'N';
      ELSE
         v_mfg_serial_number_flag := 'Y';
      END IF;
             
      --agreement_name,  
      --l_instance_rec.creation_complete_flag     := 'N';
      --l_instance_rec.completeness_flag          := 'N';
      l_instance_rec.instance_id                := v_instance_id;
      l_instance_rec.instance_number            := nvl(i.instance_number,
                                                       v_instance_id);
      l_instance_rec.instance_description       := i.instance_name;
      l_instance_rec.inventory_item_id          := v_item_id; --( <= with serial)--40508;
      l_instance_rec.vld_organization_id        := v_organization_id;
      l_instance_rec.inventory_revision         := l_revision;
      l_instance_rec.inv_master_organization_id := xxinv_utils_pkg.get_master_organization_id;
      l_instance_rec.serial_number              := i.serial_number;
      l_instance_rec.mfg_serial_number_flag     := v_mfg_serial_number_flag;
      l_instance_rec.quantity                   := i.quantity; --I.QTY;
      l_instance_rec.unit_of_measure            := l_uom_code; --I.UOM;
      l_instance_rec.accounting_class_code      := l_acct_class_code; --I.ACC_CLASS_CODE;
      l_instance_rec.owner_party_id             := v_owner_party_id;
      --l_instance_rec.INSTANCE_CONDITION_ID           := l_Condition_Id; --i.INSTANCE_COND_ID;         
      l_instance_rec.instance_status_id    := v_instance_status_id; --i.INSTANCE_STAT_ID;
      l_instance_rec.customer_view_flag    := i.flag_customer; --I.CUSTOMER_VIEW_FLAG;DBMS_OUTPUT.PUT_LINE('CUSTOMER_VIEW_FLAG '||I.CUSTOMER_VIEW_FLAG);
      l_instance_rec.merchant_view_flag    := i.merchant_flag; --I.MERCHANT_VIEW_FLAG;DBMS_OUTPUT.PUT_LINE('MERCHANT_VIEW_FLAG '||I.MERCHANT_VIEW_FLAG);
      l_instance_rec.sellable_flag         := 'Y'; --I.SELL_FLAG;DBMS_OUTPUT.PUT_LINE('SELL_FLAG '||I.SELL_FLAG);
      l_instance_rec.system_id             := v_system_id;
      l_instance_rec.instance_type_code    := l_instance_type_code; --I.INST_TYPE_CODE;
      l_instance_rec.active_start_date     := trunc(v_act_start_date) +
                                              1 / 2; --TO_DATE(I.ACT_END_DATE,'RRRR/MM/DD HH24:MI:SS');-- NULL;
      l_instance_rec.location_type_code    := (CASE WHEN v_party_site_id IS NULL THEN NULL ELSE 'HZ_PARTY_SITES' END); --I.LOC_TYPE_CODE;
      l_instance_rec.location_id           := v_party_site_id; --I.INV_LOCATION_ID;
      l_instance_rec.install_date          := trunc(i.install_date) +
                                              1 / 2;
      l_instance_rec.manually_created_flag := 'Y'; --I.MANUALLY_CREATED_FLAG;--'Y';
      -- l_instance_rec.return_by_date             := i.return_by_date;
      -- l_instance_rec.actual_return_date         := i.actual_return_date; --I.ACT_RETURN_DATE;
      l_instance_rec.creation_complete_flag     := 'Y'; --I.CREATION_COMP_FLAG;--'Y';
      l_instance_rec.completeness_flag          := 'Y'; --I.COMPL_FLAG;--'Y';
      l_instance_rec.object_version_number      := 1; --I.OBJECT_VER_NUMBER;--1;
      l_instance_rec.install_location_type_code := (CASE WHEN v_party_site_id IS NULL THEN NULL ELSE 'HZ_PARTY_SITES' END); --'HZ_LOCATIONS';
      l_instance_rec.install_location_id        := v_inst_loc_id;
      -- l_instance_rec.CONTEXT                    := 'APPS'; --I.CONTEXT;--'APPS';
      l_instance_rec.call_contracts     := fnd_api.g_false;
      l_instance_rec.grp_call_contracts := fnd_api.g_false;
      l_instance_rec.attribute1         := 'No Job Found';
      l_instance_rec.attribute2         := i.attribute2; --I.NEW_ATT2;
      l_instance_rec.attribute3         := i.attribute3; --I.NEW_ATT3;
      l_instance_rec.attribute4         := i.attribute4; --I.NEW_ATT4;
      l_instance_rec.attribute5         := i.attribute5; --I.NEW_ATT5;
      l_instance_rec.attribute6         := to_char(to_date(i.attribute1,
                                                           'YYYY-MM-DD'),
                                                   'dd/MM/YYYY'); --I.NEW_ATT1;
      /*l_instance_rec.ATTRIBUTE6                      := I.ATTRIBUTE6; --I.NEW_ATT6;
      l_instance_rec.ATTRIBUTE7                      := I.ATTRIBUTE7; --I.NEW_ATT7;
      l_instance_rec.ATTRIBUTE8                      := I.ATTRIBUTE8; --I.NEW_ATT8;
      l_instance_rec.ATTRIBUTE9                      := I.ATTRIBUTE9; --I.NEW_ATT9;
      l_instance_rec.ATTRIBUTE10                     := I.ATTRIBUTE10; --I.NEW_ATT10;
      l_instance_rec.ATTRIBUTE11                     := I.ATTRIBUTE11; --I.NEW_ATT11;
      l_instance_rec.ATTRIBUTE12                     := I.ATTRIBUTE12; --I.NEW_ATT12;
      l_instance_rec.ATTRIBUTE13                     := I.ATTRIBUTE13; --I.NEW_ATT13;
      l_instance_rec.ATTRIBUTE14                     := I.ATTRIBUTE14; --I.NEW_ATT14;
      l_instance_rec.ATTRIBUTE15                     := I.ATTRIBUTE15;*/ --I.NEW_ATT15;
             
      -- l_instance_rec.network_asset_flag := 'Y';
             
      --PARTY
             
      SELECT csi_i_parties_s.NEXTVAL INTO v_party_seq_id FROM dual;
             
      l_party_tbl(1).instance_party_id := v_party_seq_id; --V_INSTANCE_PARTY_ID;
      l_party_tbl(1).instance_id := v_instance_id; --V_INSTANCE_ID;
      l_party_tbl(1).party_source_table := 'HZ_PARTIES';
      l_party_tbl(1).party_id := v_owner_party_id;
      l_party_tbl(1).relationship_type_code := 'OWNER'; --i.relation_type_code;--'OWNER';
      l_party_tbl(1).contact_flag := 'N';
      l_party_tbl(1).contact_ip_id := NULL;
      l_party_tbl(1).active_start_date := trunc(v_act_start_date) +
                                          1 / 2; --TO_DATE(I.ACT_START_DATE,'RR/MM/DD HH24:MI:SS');
      l_party_tbl(1).active_end_date := NULL; --TRUNC(TO_DATE(i.act_end_date1,'RRRR/MM/DD HH24:MI:SS'));
      l_party_tbl(1).object_version_number := 1; --i.object_ver_number1;
      l_party_tbl(1).primary_flag := 'N';
      --l_party_tbl(1).preferred_flag := i.preferred_flag;
      l_party_tbl(1).call_contracts := fnd_api.g_false;
             
      --ACCOUNTS
             
      SELECT csi_ip_accounts_s.NEXTVAL
        INTO v_account_seq_id
        FROM dual;
             
      l_account_tbl(1).ip_account_id := v_account_seq_id; --V_IP_ACCOUNT_ID;
      l_account_tbl(1).parent_tbl_index := 1; --i.parent_tbl_index;--1;
      l_account_tbl(1).instance_party_id := v_party_seq_id; --i.instance_party_id;--V_INSTANCE_PARTY_ID;
      l_account_tbl(1).party_account_id := v_owner_account_id;
      l_account_tbl(1).relationship_type_code := 'OWNER';
      l_account_tbl(1).bill_to_address := l_bill_to;
      l_account_tbl(1).ship_to_address := l_ship_to;
      l_account_tbl(1).active_start_date := trunc(v_act_start_date) +
                                            1 / 2; --TO_DATE(i.act_start_date,'RRRR/MM/DD HH24:MI:SS');
      l_account_tbl(1).active_end_date := NULL; --TO_DATE(i.act_end_date,'RRRR/MM/DD HH24:MI:SS');
      l_account_tbl(1).object_version_number := 1; --i.object_ver_number1;
      l_account_tbl(1).call_contracts := fnd_api.g_false; --i.call_contracts;
      l_account_tbl(1).grp_call_contracts := fnd_api.g_false; --i.call_contracts;
      l_account_tbl(1).vld_organization_id := v_organization_id;
             
      --TXN
             
      l_txn_rec.transaction_id              := NULL;
      l_txn_rec.transaction_date            := trunc(SYSDATE);
      l_txn_rec.source_transaction_date     := trunc(SYSDATE);
      l_txn_rec.transaction_type_id         := 1;
      l_txn_rec.txn_sub_type_id             := NULL;
      l_txn_rec.source_group_ref_id         := NULL;
      l_txn_rec.source_group_ref            := '';
      l_txn_rec.source_header_ref_id        := NULL;
      l_txn_rec.source_header_ref           := '';
      l_txn_rec.source_line_ref_id          := NULL;
      l_txn_rec.source_line_ref             := '';
      l_txn_rec.source_dist_ref_id1         := NULL;
      l_txn_rec.source_dist_ref_id2         := NULL;
      l_txn_rec.inv_material_transaction_id := NULL;
      l_txn_rec.transaction_quantity        := NULL;
      l_txn_rec.transaction_uom_code        := '';
      l_txn_rec.transacted_by               := NULL;
      l_txn_rec.transaction_status_code     := '';
      l_txn_rec.transaction_action_code     := '';
      l_txn_rec.message_id                  := NULL;
      l_txn_rec.object_version_number       := '';
      l_txn_rec.split_reason_code           := '';
      --CALL API
             
      SELECT csi_i_org_assignments_s.NEXTVAL
        INTO l_instance_ou_id
        FROM dual;
      l_org_assignments_tbl(1).instance_ou_id := l_instance_ou_id;
      l_org_assignments_tbl(1).instance_id := v_instance_id;
      l_org_assignments_tbl(1).operating_unit_id := l_org_id;
      l_org_assignments_tbl(1).relationship_type_code := 'SOLD_FROM';
      l_org_assignments_tbl(1).active_start_date := trunc(v_act_start_date) +
                                                    1 / 2;
             
      l_ext_attrib_values := l_ext_attrib_values_miss;
      l_ext_attr_ind      := 1;
             
      IF i.optimax_upgrade_date IS NOT NULL THEN
                
         SELECT csi_iea_values_s.NEXTVAL
           INTO l_attribute_value_id
           FROM dual;
                
         l_ext_attrib_values(l_ext_attr_ind).attribute_value_id := l_attribute_value_id;
         l_ext_attrib_values(l_ext_attr_ind).instance_id := v_instance_id;
         l_ext_attrib_values(l_ext_attr_ind).attribute_id := 10000;
         l_ext_attrib_values(l_ext_attr_ind).attribute_code := 'OBJ_OPTUG';
         l_ext_attrib_values(l_ext_attr_ind).attribute_value := i.optimax_upgrade_date;
         l_ext_attrib_values(l_ext_attr_ind).active_start_date := trunc(v_act_start_date) +
                                                                  1 / 2;
                
         l_ext_attr_ind := l_ext_attr_ind + 1;
                
      END IF;
             
      IF i.upgrade_date IS NOT NULL THEN
                
         SELECT csi_iea_values_s.NEXTVAL
           INTO l_attribute_value_id
           FROM dual;
                
         l_ext_attrib_values(l_ext_attr_ind).attribute_value_id := l_attribute_value_id;
         l_ext_attrib_values(l_ext_attr_ind).instance_id := v_instance_id;
         l_ext_attrib_values(l_ext_attr_ind).attribute_id := 11000;
         l_ext_attrib_values(l_ext_attr_ind).attribute_code := 'OBJ_TEMPO_DATE';
         l_ext_attrib_values(l_ext_attr_ind).attribute_value := i.upgrade_date;
         l_ext_attrib_values(l_ext_attr_ind).active_start_date := trunc(v_act_start_date) +
                                                                  1 / 2;
                
      END IF;
             
      l_msg_data     := NULL;
      l_init_msg_lst := NULL;
      fnd_msg_pub.initialize;
      --dbms_output.put_line('1: '||l_RETURN_STATUS||' '||l_msg_data);
      csi_item_instance_pub.create_item_instance(p_api_version           => 1,
                                                 p_commit                => 'F',
                                                 p_init_msg_list         => 'T',
                                                 p_validation_level      => l_validation_level,
                                                 p_instance_rec          => l_instance_rec,
                                                 p_ext_attrib_values_tbl => l_ext_attrib_values,
                                                 p_party_tbl             => l_party_tbl,
                                                 p_account_tbl           => l_account_tbl,
                                                 p_pricing_attrib_tbl    => l_pricing_attrib_tbl,
                                                 p_org_assignments_tbl   => l_org_assignments_tbl,
                                                 p_asset_assignment_tbl  => l_asset_assignment_tbl,
                                                 p_txn_rec               => l_txn_rec,
                                                 x_return_status         => l_return_status,
                                                 x_msg_count             => l_msg_count,
                                                 x_msg_data              => l_msg_data);
             
      IF l_return_status != apps.fnd_api.g_ret_sts_success THEN
         fnd_msg_pub.get(p_msg_index     => -1,
                         p_encoded       => 'F',
                         p_data          => l_msg_data,
                         p_msg_index_out => l_msg_index_out);
                
         UPDATE xxobjt_conv_ib_instance
            SET error_message   = l_msg_data,
                error_code_flag = l_return_status
          WHERE serial_number = i.serial_number;
      ELSE
                
         IF i.counter IS NOT NULL THEN
                   
            BEGIN
                      
               SELECT ca.counter_id
                 INTO l_counter_id
                 FROM csi_counter_associations_v ca
                WHERE ca.source_object_id = v_instance_id AND
                      ca.source_object_code = 'CP';
                      
            EXCEPTION
               WHEN OTHERS THEN
                  l_error_msg := 'Counter not defined for ' || i.item;
                  RAISE invalid_instance;
                         
            END;
            SELECT csi_counter_readings_s.NEXTVAL
              INTO l_counter_reading_id
              FROM dual;
                   
            l_txn_tbl := l_txn_tbl_miss;
                   
            l_counter_reading_tbl(1).counter_value_id := l_counter_reading_id;
            l_counter_reading_tbl(1).counter_id := l_counter_id;
            l_counter_reading_tbl(1).value_timestamp := SYSDATE;
            l_counter_reading_tbl(1).counter_reading := nvl(i.counter,
                                                            0);
            l_counter_reading_tbl(1).migrated_flag := 'N';
            l_counter_reading_tbl(1).life_to_date_reading := nvl(i.counter,
                                                                 0);
            l_counter_reading_tbl(1).net_reading := nvl(i.counter, 0);
            l_counter_reading_tbl(1).disabled_flag := 'N';
            l_counter_reading_tbl(1).parent_tbl_index := 1;
            -----
            l_txn_tbl(1).source_transaction_date := trunc(SYSDATE);
            l_txn_tbl(1).transaction_type_id := 80;
            l_txn_tbl(1).object_version_number := 1;
            l_txn_tbl(1).source_header_ref_id := v_instance_id;
                   
            csi_counter_readings_pub.capture_counter_reading(p_api_version      => 1.0,
                                                             p_commit           => 'F',
                                                             p_init_msg_list    => 'T',
                                                             p_validation_level => l_validation_level,
                                                             p_txn_tbl          => l_txn_tbl,
                                                             p_ctr_rdg_tbl      => l_counter_reading_tbl,
                                                             p_ctr_prop_rdg_tbl => l_counter_prop_read_tbl,
                                                             x_return_status    => l_return_status,
                                                             x_msg_count        => l_msg_count,
                                                             x_msg_data         => l_msg_data);
                   
            IF l_return_status != apps.fnd_api.g_ret_sts_success THEN
               fnd_msg_pub.get(p_msg_index     => -1,
                               p_encoded       => 'F',
                               p_data          => l_msg_data,
                               p_msg_index_out => l_msg_index_out);
                      
               l_error_msg := l_msg_data;
               RAISE invalid_instance;
                      
            END IF;
                   
         END IF;
                
         UPDATE xxobjt_conv_ib_instance
            SET error_message = NULL, error_code_flag = 'S'
          WHERE serial_number = i.serial_number AND
                item = i.item AND
                party_name = i.party_name;
                
         /*               dbms_output.put_line('S');,
         IF ' ' \*????i.object_id?????*\
            <> i.instance_number THEN
                   
            BEGIN
               SELECT a.quantity
                 INTO v_object_qty
                 FROM csi_instance_details_v a
                WHERE a.instance_number = '' \*????i.object_id?????*\
               ;
            EXCEPTION
               WHEN no_data_found THEN
                  v_object_qty := NULL;
            END;
            IF v_object_qty = 1 THEN
                      
               l_return_status    := NULL;
               l_msg_count        := NULL;
               l_init_msg_lst     := NULL;
               l_msg_index_out    := NULL;
               l_validation_level := NULL;
                      
               SELECT csi_ii_relationships_s.NEXTVAL
                 INTO v_relationship_id
                 FROM sys.dual;
                      
               l_relationship_tbl(1).relationship_id := v_relationship_id; --14369;--l_instance_rec.INSTANCE_ID;
               l_relationship_tbl(1).relationship_type_code := 'COMPONENT-OF'; --i.rel_ship_type_code;--'COMPONENT-OF';
               l_relationship_tbl(1).object_id := '' \*????i.object_id?????*\
                ;
               l_relationship_tbl(1).subject_id := l_instance_rec.instance_id; --10001;
               l_relationship_tbl(1).subject_has_child := 'N';
               l_relationship_tbl(1).position_reference := NULL;
               l_relationship_tbl(1).active_start_date := v_act_start_date;
               l_relationship_tbl(1).active_end_date := NULL; --fnd_api.G_MISS_DATE;
               l_relationship_tbl(1).display_order := NULL;
               l_relationship_tbl(1).mandatory_flag := 'N';
               l_relationship_tbl(1).object_version_number := 1;
                      
               l_txn_rec_chi.transaction_date        := trunc(SYSDATE);
               l_txn_rec_chi.source_transaction_date := trunc(SYSDATE);
               l_txn_rec_chi.transaction_type_id     := 1;
               l_txn_rec_chi.object_version_number   := 1;
                      
               csi_ii_relationships_pub.create_relationship(p_api_version      => 1,
                                                            p_commit           => l_commit,
                                                            p_init_msg_list    => l_init_msg_lst,
                                                            p_validation_level => l_validation_level,
                                                            p_relationship_tbl => l_relationship_tbl,
                                                            p_txn_rec          => l_txn_rec_chi,
                                                            x_return_status    => l_return_status,
                                                            x_msg_count        => l_msg_count,
                                                            x_msg_data         => l_msg_data);
                      
               IF l_return_status != apps.fnd_api.g_ret_sts_success THEN
                  ROLLBACK;
                  fnd_msg_pub.get(p_msg_index     => -1,
                                  p_encoded       => 'F',
                                  p_data          => l_msg_data,
                                  p_msg_index_out => l_msg_index_out);
                  -- dbms_output.put_line('Relation '||l_RETURN_STATUS||l_msg_data);
                  UPDATE xxobjt_conv_ib_instance
                     SET error_message   = 'Relation Ship: ' ||
                                           l_msg_data,
                         error_code_flag = l_return_status
                   WHERE instance_number = i.instance_number;
                  COMMIT;
               ELSE
                  -- dbms_output.put_line('Relation S ');
                  UPDATE xxobjt_conv_ib_instance
                     SET error_message    = NULL,
                         error_code_flag  = 'S',
                         instance_id      = l_instance_rec.instance_id,
                         relation_ship_id = v_relationship_id
                   WHERE instance_number = i.instance_number;
                  COMMIT;
               END IF;
            ELSE
               UPDATE xxobjt_conv_ib_instance
                  SET error_message   = NULL,
                      error_code_flag = 'S',
                      instance_id     = l_instance_rec.instance_id
                WHERE instance_number = i.instance_number;
               COMMIT;
            END IF;
         ELSE
            UPDATE xxobjt_conv_ib_instance
               SET error_message   = NULL,
                   error_code_flag = 'S',
                   instance_id     = l_instance_rec.instance_id
             WHERE instance_number = i.instance_number;
         END IF;
         IF i.machine_name IS NOT NULL THEN
            SELECT csi_iea_value_interface_s.NEXTVAL
              INTO v_att_value_id
              FROM dual;
            BEGIN
               INSERT INTO csi_iea_values
                  (attribute_value,
                   attribute_value_id,
                   attribute_id,
                   instance_id,
                   created_by,
                   creation_date,
                   last_updated_by,
                   last_update_date,
                   object_version_number)
               VALUES
                  (i.machine_name,
                   v_att_value_id,
                   10065,
                   l_instance_rec.instance_id,
                   23982,
                   SYSDATE,
                   23982,
                   SYSDATE,
                   1);
            EXCEPTION
               WHEN OTHERS THEN
                  dbms_output.put_line('Error Inserting Value Table. Instance: ' ||
                                       i.instance_number);
            END;
         END IF;*/
      END IF;
             
    EXCEPTION
      WHEN invalid_instance THEN
         UPDATE xxobjt_conv_ib_instance
            SET error_message = l_error_msg, error_code_flag = 'E'
          WHERE serial_number = i.serial_number AND
                item = i.item AND
                party_name = i.party_name;
                
      WHEN OTHERS THEN
         l_error_msg := SQLERRM;
         UPDATE xxobjt_conv_ib_instance
            SET error_message = l_error_msg, error_code_flag = 'E'
          WHERE serial_number = i.serial_number AND
                item = i.item AND
                party_name = i.party_name;
    END;
      
    END LOOP;
    COMMIT;
  END create_instance;
   
  --------------------------------------------------------------------
  --  name:            create_instance
  --  create by:       XXX
  --  Revision:        1.0
  --  creation date:   XX.XX.XXXX
  --------------------------------------------------------------------
  --  purpose :        Handle write to log tbl
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  XX.XX.XXXX  XXX               initial build
  --------------------------------------------------------------------
  Procedure upload_associations_employees(errbuf         Out Varchar2,
                                          errcode        Out Varchar2,
                                          p_location     In Varchar2,  ----'/UtlFiles/Forecast'
                                          p_filename     In Varchar2,  ----'csi_employees.csv'
                                          p_ignore_first_headers_line  In Varchar2 DEFAULT 'N',
                                          p_validate_only_flag         In Varchar2) IS
                                        
    ---For each Item Instance ("mehonat kafe im serial number...")
    ------------- You can define OWNER (ORGANIZATION-PARTY)-Association ("hevra she soheret mehonat kafe")
    -----------------------              and TECHNICAL -Association  ("technai" she magia letaken mehonat kafe)                                       
                                        
    CURSOR get_data_from_file(p_conc_request_id NUMBER)  IS
    SELECT instance_id,
           person_id,
           party_source_table,
           relationship_type_code,
           preferred_flag,
           primary_flag,
           contact_flag
    FROM   XXCSI_UPLOAD_ASSOCIATIONS_TMP  ua
    WHERE  ua.conc_request_id=p_conc_request_id ---param                                                                                         
    AND    ua.status='SUCCESS';  ---validation success
    -----AND    ROWNUM=1;  ---FOR DEBUGGING ONLY
                                       
      
    v_conc_request_id                   number;                                 
    v_step                         varchar2(1000);                                 
    v_error_message                varchar2(1000);
    --v_operating_unit_name          varchar2(100);
    v_numeric_dummy                number;
    stop_processing                exception;  --- missing parameter...or invalid parameter. stop (exit) procedure..
    validation_error               exception;  ---the one of fields is invalid. stop processing for this line
    v_file                         utl_file.file_type;
    v_line                         VARCHAR2(7000);
    v_line_number                  NUMBER:=0;
    v_line_is_valid_flag           VARCHAR2(1);
    v_valid_error_message          VARCHAR2(1000);
    v_status                       VARCHAR2(100);
    v_num_of_non_valid_lines       NUMBER:=0;
    v_num_of_valid_lines           NUMBER:=0;
    v_num_of_success_ins_lines     NUMBER:=0;
    v_num_of_failured_ins_lines    NUMBER:=0;
    v_Read_Code                    NUMBER;
    v_there_are_non_valid_rows     VARCHAR2(100):='N';
    v_num_of_update_success        NUMBER:=0;
    v_num_of_update_failured       NUMBER:=0;
    
    --l_app_short_name               VARCHAR2(100);
    
    ---UTL file fields-----
    v_instance_id_str              VARCHAR2(100); -----1---------
    v_person_id_str                VARCHAR2(100); -----2---------
    v_party_source_table           VARCHAR2(100); -----3---------
    v_relationship_type_code       VARCHAR2(100); -----4---------
    v_preferred_flag               VARCHAR2(100); -----5---------
    v_primary_flag                 VARCHAR2(100); -----6---------
    v_contact_flag                 VARCHAR2(100); -----7---------
    
    
    -----Selected values-----------------
    v_instance_id                  NUMBER;
    v_person_id                    NUMBER;
    --v_party_seq_id                 NUMBER;
    v_contact_ip_id                NUMBER;
    -----API variables-------------------
    l_instance_rec             csi_datastructures_pub.instance_rec;
    l_party_tbl                csi_datastructures_pub.party_tbl;
    l_account_tbl              csi_datastructures_pub.party_account_tbl;
    --l_ext_attrib_values_tbl    csi_datastructures_pub.extend_attrib_values_tbl;
    l_pricing_attrib_tbl       csi_datastructures_pub.pricing_attribs_tbl;
    l_org_assignments_tbl      csi_datastructures_pub.organization_units_tbl;
    l_asset_assignment_tbl     csi_datastructures_pub.instance_asset_tbl;
    l_txn_rec                  csi_datastructures_pub.transaction_rec;
    --l_txn_rec_chi              csi_datastructures_pub.transaction_rec;
    --l_relationship_tbl         csi_datastructures_pub.ii_relationship_tbl;
    l_ext_attrib_values        csi_datastructures_pub.extend_attrib_values_tbl;
    --l_txn_tbl                  csi_datastructures_pub.transaction_tbl;
    --l_txn_tbl_miss             csi_datastructures_pub.transaction_tbl;
    --l_counter_reading_tbl      csi_ctr_datastructures_pub.counter_readings_tbl;
    --l_counter_reading_tbl_miss csi_ctr_datastructures_pub.counter_readings_tbl;
    --l_counter_prop_read_tbl    csi_ctr_datastructures_pub.ctr_property_readings_tbl;
    l_return_status            VARCHAR2(2000) := NULL;
    l_msg_count                NUMBER := NULL;
    l_msg_data                 VARCHAR2(2000) := NULL;
    l_init_msg_lst             VARCHAR2(1000) := NULL;
    l_msg_index_out            NUMBER;
    l_instance_id_lst          csi_datastructures_pub.id_tbl;
    l_validation_level         NUMBER := NULL;
    
   
  BEGIN


    v_step:='Step 1';

    v_conc_request_id:=fnd_global.CONC_REQUEST_ID;

    /*---------------INTIALIZATION--------------------------------------
    fnd_global.apps_initialize(user_id      => fnd_global.USER_ID,
                               resp_id      => fnd_global.resp_id,
                               resp_appl_id => fnd_global.resp_appl_id);
                               
      */                         
             
    IF p_location IS NULL THEN
       fnd_file.put_line (fnd_file.log,'***************** MISSING PARAMETER p_location ****************'); 
       RAISE stop_processing; 
    END IF;

    IF p_filename IS NULL THEN
       fnd_file.put_line (fnd_file.log,'***************** MISSING PARAMETER p_filename ****************'); 
       RAISE stop_processing; 
    END IF;

    IF p_validate_only_flag IS NULL THEN
       fnd_file.put_line (fnd_file.log,'***************** MISSING PARAMETER p_validate_only_flag ****************'); 
       RAISE stop_processing; 
    END IF;

    IF p_ignore_first_headers_line IS NULL THEN
       fnd_file.put_line (fnd_file.log,'***************** MISSING PARAMETER p_ignore_first_headers_line ****************'); 
       RAISE stop_processing; 
    END IF;

    IF p_ignore_first_headers_line NOT IN ('Y','N') THEN
       fnd_file.put_line (fnd_file.log,'***************** PARAMETER p_ignore_first_headers_line SHOULD BE ''Y'' or ''N'' ****************'); 
       RAISE stop_processing; 
    END IF;

                                           
      
    fnd_file.put_line (fnd_file.log,'***************************************************************************'); 
    fnd_file.put_line (fnd_file.log,'***************************PARAMETERS*****************************');
    fnd_file.put_line (fnd_file.log,'***************************************************************************');  
    fnd_file.put_line (fnd_file.log,'---------p_location='||p_location );
    fnd_file.put_line (fnd_file.log,'---------p_filename='||p_filename );
    fnd_file.put_line (fnd_file.log,'---------p_ignore_first_headers_line='||p_ignore_first_headers_line);      
    fnd_file.put_line (fnd_file.log,'---------p_validate_only_flag='||p_validate_only_flag );                                                              
    fnd_file.put_line (fnd_file.log,''); --empty line
    fnd_file.put_line (fnd_file.log,''); --empty line
    fnd_file.put_line (fnd_file.log,''); --empty line

    ------------------Open flat file----------------------------
    v_step:='Step 10';
    begin 
      v_file := utl_file.fopen(  ---v_dir,v_file_name,'r');
                                p_location,p_filename,'R');
                              -- p_location,p_filename,'r',32767);
                            
    exception 
         when utl_file.invalid_path then
         errcode := '2';
         errbuf   := errbuf || 'Invalid Path for '||ltrim(p_location||'/'||p_filename) || chr(0);
         RAISE stop_processing;
        when utl_file.invalid_mode then
         errcode := '2';
         errbuf   := errbuf || 'Invalid Mode for '||ltrim(p_location||'/'||p_filename) || chr(0);
         RAISE stop_processing;
        when utl_file.invalid_operation then
         errcode := '2';
         errbuf   := errbuf || 'Invalid operation for '||ltrim(p_location||'/'||p_filename)||' '||sqlerrm|| chr(0);
        RAISE stop_processing;
        when others then 
          errcode :='2' ;
          errbuf  :='==============Cannot open '||p_location||'/'||p_filename||' file';
          RAISE stop_processing; 
    end;  

    ------------------Get lines---------------------------------
    v_step:='Step 20';
    begin
        v_Read_Code:=1;
        WHILE v_Read_Code <> 0  --End Of File
                                    LOOP
          ----
          begin
              UTL_FILE.GET_LINE(v_file, v_line);
          Exception
            When Utl_File.Read_Error Then
              Errbuf  := 'Read Error' || Chr(0);
              errcode := '2';
              EXIT;
            When No_Data_Found Then
              fnd_file.put_line (fnd_file.log,' ');  ---empty row
              fnd_file.put_line (fnd_file.log,' ');  ---empty row
              fnd_file.put_line (fnd_file.log,'***********************READ COMPLETE******************************');
              Errbuf      := 'Read Complete' || Chr(0);
              v_Read_Code := 0;
              EXIT;
            When Others Then
              Errbuf  := 'Other for Line Read' || Chr(0);
              errcode := '2';
              EXIT;
          end;  

        
        IF v_line IS NULL THEN
           ----dbms_output.put_line('Got empty line');
           NULL;
        ELSE
           v_step:='Step 30';
           --------New line was received from file-----------
           v_line_number:=v_line_number+1;
           v_line_is_valid_flag:='Y';
           v_valid_error_message:=NULL;
           v_status:='SUCCESS'; 
                               
           v_instance_id_str          :=xxconv_install_base_pkg.get_field_from_utl_file_line(v_line, 1);
           v_person_id_str            :=xxconv_install_base_pkg.get_field_from_utl_file_line(v_line, 2);
           v_party_source_table       :=xxconv_install_base_pkg.get_field_from_utl_file_line(v_line, 3);
           v_relationship_type_code   :=xxconv_install_base_pkg.get_field_from_utl_file_line(v_line, 4);
           v_preferred_flag           :=xxconv_install_base_pkg.get_field_from_utl_file_line(v_line, 5);
           v_primary_flag             :=xxconv_install_base_pkg.get_field_from_utl_file_line(v_line, 6);
           v_contact_flag             :=xxconv_install_base_pkg.get_field_from_utl_file_line(v_line, 7);
           v_contact_flag:=rtrim(v_contact_flag,chr(13)); 
            
           /*IF NOT(v_line_number=1 AND p_ignore_first_headers_line='Y') THEN      
           ------------------- FOR DEBUGGING ONLY ------------------------------
               fnd_file.put_line (fnd_file.log,'');   ---empty line    
               fnd_file.put_line (fnd_file.log,'++++++++++++ Line '||v_line_number||' +++++++++++++++');
               fnd_file.put_line (fnd_file.log,'Instance Id           : '||v_instance_id_str       ||'---('||length(v_instance_id_str)||')');
               fnd_file.put_line (fnd_file.log,'Person Id             : '||v_person_id_str         ||'---('||length(v_person_id_str)  ||')');
               fnd_file.put_line (fnd_file.log,'Party Source Table    : '||v_party_source_table    ||'---('||length(v_party_source_table)  ||')');
               fnd_file.put_line (fnd_file.log,'Relationship Type Code: '||v_relationship_type_code||'---('||length(v_relationship_type_code)  ||')');
               fnd_file.put_line (fnd_file.log,'Prefered Flag         : '||v_preferred_flag        ||'---('||length(v_preferred_flag)  ||')');
               fnd_file.put_line (fnd_file.log,'Primary Flag          : '||v_primary_flag          ||'---('||length(v_primary_flag)  ||')');
               fnd_file.put_line (fnd_file.log,'Contact Flag          : '||v_contact_flag          ||'---('||length(v_contact_flag)  ||')');
                          
           END IF; */
                        
           ---=================Validations========================
           BEGIN
                 IF v_line_number=1 AND p_ignore_first_headers_line='Y' THEN
                     RAISE validation_error; ---no validations for this headres line
                 END IF;
                 ----------Check Instance Id------------REQUIRED----------------
                 v_step:='Step 40';
                 if v_instance_id_str is null then
                     v_line_is_valid_flag:='N';
                     v_status:='ERROR';
                     v_valid_error_message:='======Line '||v_line_number||' Validation Error:   INSTANCE_ID is MISSING=========';
                     fnd_file.put_line (fnd_file.log, v_valid_error_message);
                     RAISE validation_error;
                 end if;
                 --------
                 begin
                       v_instance_id:=to_number(v_instance_id_str); 
                 exception
                     when others then
                       v_line_is_valid_flag:='N';
                       v_status:='ERROR';
                       v_valid_error_message:='======Line '||v_line_number||
                                              ' Validation Error:   INSTANCE_ID SHOULD BE NUMERIC VALUE';
                       fnd_file.put_line (fnd_file.log, v_valid_error_message);
                       RAISE validation_error; 
                 end;
                 --------
                 IF  v_instance_id <=0 THEN
                       v_line_is_valid_flag:='N';
                       v_status:='ERROR';
                       v_valid_error_message:='======Line '||v_line_number||
                                              ' Validation Error:   INSTANCE_ID SHOULD BE POSITIVE NUMERIC VALUE > 0';
                       fnd_file.put_line (fnd_file.log, v_valid_error_message);
                       RAISE validation_error;
                 END IF;
                 --------
                 begin
                       select 1
                       into   v_numeric_dummy
                       from   csi_item_instances  cii
                       where  cii.instance_id=v_instance_id
                       and    sysdate between cii.active_start_date and nvl(cii.active_end_date,sysdate+1); 
                 exception
                     when others then
                       v_line_is_valid_flag:='N';
                       v_status:='ERROR';
                       v_valid_error_message:='======Line '||v_line_number||
                                              ' Validation Error:   INSTANCE_ID='||v_instance_id||' DOES NOT EXIST in CSI_ITEM_INSTANCES table';
                       fnd_file.put_line (fnd_file.log, v_valid_error_message);
                       RAISE validation_error; 
                 end;
                 ----------Check Person Id------------REQUIRED----------------
                 v_step:='Step 40.2';
                 if v_person_id_str is null then
                     v_line_is_valid_flag:='N';
                     v_status:='ERROR';
                     v_valid_error_message:='======Line '||v_line_number||' Validation Error:   PERSON_ID is MISSING=========';
                     fnd_file.put_line (fnd_file.log, v_valid_error_message);
                     RAISE validation_error;
                 end if;
                 --------
                 begin
                       v_person_id:=to_number(v_person_id_str); 
                 exception
                     when others then
                       v_line_is_valid_flag:='N';
                       v_status:='ERROR';
                       v_valid_error_message:='======Line '||v_line_number||
                                              ' Validation Error:   PERSON_ID SHOULD BE NUMERIC VALUE';
                       fnd_file.put_line (fnd_file.log, v_valid_error_message);
                       RAISE validation_error; 
                 end;
                 --------
                 IF  v_person_id <=0 THEN
                       v_line_is_valid_flag:='N';
                       v_status:='ERROR';
                       v_valid_error_message:='======Line '||v_line_number||
                                              ' Validation Error:   PERSON_ID SHOULD BE POSITIVE NUMERIC VALUE > 0';
                       fnd_file.put_line (fnd_file.log, v_valid_error_message);
                       RAISE validation_error;
                 END IF;
                 --------
                 begin
                       select 1
                       into   v_numeric_dummy
                       from   per_all_people_f   ppf
                       where  ppf.person_id=v_person_id
                       and    sysdate between ppf.effective_start_date and nvl(ppf.effective_end_date,sysdate+1)
                       and    ppf.current_employee_flag='Y'; 
                 exception
                     when others then
                       v_line_is_valid_flag:='N';
                       v_status:='ERROR';
                       v_valid_error_message:='======Line '||v_line_number||
                                              ' Validation Error:   PERSON_ID='||v_person_id||' DOES NOT EXIST in PER_ALL_PEOPLE_F table';
                       fnd_file.put_line (fnd_file.log, v_valid_error_message);
                       RAISE validation_error; 
                 end;
                 ----Check Party Source Table------
                 v_step:='Step 40.3';
                 if v_party_source_table is null then
                     v_line_is_valid_flag:='N';
                     v_status:='ERROR';
                     v_valid_error_message:='======Line '||v_line_number||' Validation Error:   PARTY_SOURCE_TABLE is MISSING=========';
                     fnd_file.put_line (fnd_file.log, v_valid_error_message);
                     RAISE validation_error;
                 end if;
                 if v_party_source_table NOT IN ('EMPLOYEE','HZ_PARTIES') THEN
                     v_line_is_valid_flag:='N';
                     v_status:='ERROR';
                     v_valid_error_message:='======Line '||v_line_number||' Validation Error:   PARTY_SOURCE_TABLE value is wrong (it shoud be ''EMPLOYEE'' or ''HZ_PARTIES'')';
                     fnd_file.put_line (fnd_file.log, v_valid_error_message);
                     RAISE validation_error;
                 end if;
                 ----Check Party Source Table------
                 v_step:='Step 40.4';
                 if v_relationship_type_code is null then
                     v_line_is_valid_flag:='N';
                     v_status:='ERROR';
                     v_valid_error_message:='======Line '||v_line_number||' Validation Error:   RELATIONSHIP_TYPE_CODE is MISSING=========';
                     fnd_file.put_line (fnd_file.log, v_valid_error_message);
                     RAISE validation_error;
                 end if;
                 if v_relationship_type_code NOT IN ('TECHNICAL','OWNER') THEN
                     v_line_is_valid_flag:='N';
                     v_status:='ERROR';
                     v_valid_error_message:='======Line '||v_line_number||' Validation Error:   RELATIONSHIP_TYPE_CODE value is wrong (it shoud be ''TECHNICAL'',''OWNER'')';
                     fnd_file.put_line (fnd_file.log, v_valid_error_message);
                     RAISE validation_error;
                 end if;
                 ----Check Preferred Flag------
                 v_step:='Step 40.5';
                 if v_preferred_flag is null then
                     v_line_is_valid_flag:='N';
                     v_status:='ERROR';
                     v_valid_error_message:='======Line '||v_line_number||' Validation Error:   PREFERRED_FLAG is MISSING=========';
                     fnd_file.put_line (fnd_file.log, v_valid_error_message);
                     RAISE validation_error;
                 end if;
                 if v_preferred_flag NOT IN ('Y','N') THEN
                     v_line_is_valid_flag:='N';
                     v_status:='ERROR';
                     v_valid_error_message:='======Line '||v_line_number||' Validation Error:   PREFERRED_FLAG value is wrong (it shoud be ''Y'' or ''N'')';
                     fnd_file.put_line (fnd_file.log, v_valid_error_message);
                     RAISE validation_error;
                 end if;
                 ----Check Primary Flag------
                 v_step:='Step 40.6';
                 if v_primary_flag is null then
                     v_line_is_valid_flag:='N';
                     v_status:='ERROR';
                     v_valid_error_message:='======Line '||v_line_number||' Validation Error:   PRIMARY_FLAG is MISSING=========';
                     fnd_file.put_line (fnd_file.log, v_valid_error_message);
                     RAISE validation_error;
                 end if;
                 if v_primary_flag NOT IN ('Y','N') THEN
                     v_line_is_valid_flag:='N';
                     v_status:='ERROR';
                     v_valid_error_message:='======Line '||v_line_number||' Validation Error:   PRIMARY_FLAG value is wrong (it shoud be ''Y'' or ''N'')';
                     fnd_file.put_line (fnd_file.log, v_valid_error_message);
                     RAISE validation_error;
                 end if;
                 ----Check Contact Flag------
                 v_step:='Step 40.7';
                 if v_contact_flag is null then
                     v_line_is_valid_flag:='N';
                     v_status:='ERROR';
                     v_valid_error_message:='======Line '||v_line_number||' Validation Error:   CONTACT_FLAG is MISSING=========';
                     fnd_file.put_line (fnd_file.log, v_valid_error_message);
                     RAISE validation_error;
                 end if;
                 if v_contact_flag NOT IN ('Y','N') THEN
                     v_line_is_valid_flag:='N';
                     v_status:='ERROR';
                     v_valid_error_message:='======Line '||v_line_number||' Validation Error:   CONTACT_FLAG value is wrong (it shoud be ''Y'' or ''N'')';
                     fnd_file.put_line (fnd_file.log, v_valid_error_message);
                     RAISE validation_error;
                 end if;      
           EXCEPTION
              when validation_error then
                  IF NOT(v_line_number=1 AND p_ignore_first_headers_line='Y') THEN
                     v_there_are_non_valid_rows:='Y';
                  END IF;
                  fnd_file.put_line (fnd_file.log,'');   ---empty line 
           END;            
           ---=============the end of validations=================  
           if v_line_is_valid_flag='N' then
                v_num_of_non_valid_lines:=v_num_of_non_valid_lines +1;
           else
                v_num_of_valid_lines:=v_num_of_valid_lines +1;
           end if; 
           
              
           
               
           
           IF  -------v_line_is_valid_flag='Y' AND p_validate_only_flag<>'Y' AND
              NOT(v_line_number=1 AND p_ignore_first_headers_line='Y') THEN
              ---********* Insert this valid record(line) into XXCSI_UPLOAD_ASSOCIATIONS_TMP table *****************      
              v_step:='Step 40';
              --------
              BEGIN
                INSERT INTO XXCSI_UPLOAD_ASSOCIATIONS_TMP(conc_request_id,
                                                          instance_id,
                                                          person_id,
                                                          party_source_table,
                                                          relationship_type_code,
                                                          preferred_flag,
                                                          primary_flag,
                                                          contact_flag,
                                                          status,
                                                          error_message)
                   VALUES(v_conc_request_id,
                          v_instance_id,
                          v_person_id,
                          v_party_source_table,
                          v_relationship_type_code,
                          v_preferred_flag,
                          v_primary_flag,
                          v_contact_flag,
                          v_status,
                          v_valid_error_message);
                          v_num_of_success_ins_lines:=v_num_of_success_ins_lines+1;
            EXCEPTION
              WHEN OTHERS THEN
                 v_num_of_failured_ins_lines:=v_num_of_failured_ins_lines+1;
                 fnd_file.put_line (fnd_file.log, '**************Line '||v_line_number||' INSERT into XXCSI_UPLOAD_ASSOCIATIONS_TMP ERROR : '||
                                                            SQLERRM);
            END;
            ------------
           end if;
           ---***********the end of Insert into XXCSI_UPLOAD_ASSOCIATIONS_TMP table ***********             
        END IF;
      END LOOP;
      
     
    exception
      WHEN no_data_found THEN
         fnd_file.put_line (fnd_file.log, '##############  No more data to read  #################');
    end;

    -------------COMMIT-------------------
    IF v_num_of_success_ins_lines>0 THEN
        COMMIT;
    END IF;    

    ------------------Close flat file----------------------------
    utl_file.fclose(v_file);

    IF p_validate_only_flag<>'Y'  THEN
        --------------
        FOR party_rec IN get_data_from_file(v_conc_request_id) LOOP
            ------
            begin 
                -----===============UPDATE INSTANCE==========================
                l_instance_rec.instance_id := party_rec.instance_id;
                            
                ----Get contact istance party id--------
                v_contact_ip_id:=null;
                begin
                      select CIP.Instance_Party_Id
                      into   v_contact_ip_id
                      from   csi_i_parties cip
                      where  cip.instance_id = party_rec.instance_id  ---param
                      and    cip.party_source_table    ='HZ_PARTIES'
                      and    cip.relationship_type_code='OWNER';          
                exception
                  when NO_DATA_FOUND then
                      v_contact_ip_id:=null;
                      fnd_file.put_line (fnd_file.log,'--------Contact Istance Party Id NOT FOUND for instance_id='||party_rec.instance_id);
                      RAISE stop_processing;
                end;
                ------------------
                        
                /*SELECT csi_i_parties_s.NEXTVAL 
                INTO   v_party_seq_id 
                FROM dual;*/
             
                l_party_tbl(1).instance_party_id     := null;  ----v_party_seq_id; 
                l_party_tbl(1).instance_id           := party_rec.instance_id;
                l_party_tbl(1).party_id              := party_rec.person_id;
                l_party_tbl(1).party_source_table    := party_rec.party_source_table;       ----'EMPLOYEE';
                l_party_tbl(1).relationship_type_code:= party_rec.relationship_type_code;   ----'TECHNICAL';           
                l_party_tbl(1).preferred_flag        := party_rec.preferred_flag;
                l_party_tbl(1).primary_flag          := party_rec.primary_flag;
                l_party_tbl(1).contact_flag          := party_rec.contact_flag;
                l_party_tbl(1).active_start_date     := SYSDATE;
                l_party_tbl(1).active_end_date       := NULL;
                l_party_tbl(1).object_version_number := 1;
                l_party_tbl(1).contact_ip_id         := v_contact_ip_id;
                
                
                
                l_txn_rec.transaction_id              := NULL;
                l_txn_rec.transaction_date            := trunc(SYSDATE);
                l_txn_rec.source_transaction_date     := trunc(SYSDATE);
                l_txn_rec.transaction_type_id         := 1;
                l_txn_rec.txn_sub_type_id             := NULL;
                l_txn_rec.source_group_ref_id         := NULL;
                l_txn_rec.source_group_ref            := '';
                l_txn_rec.source_header_ref_id        := NULL;
                l_txn_rec.source_header_ref           := '';
                l_txn_rec.source_line_ref_id          := NULL;
                l_txn_rec.source_line_ref             := '';
                l_txn_rec.source_dist_ref_id1         := NULL;
                l_txn_rec.source_dist_ref_id2         := NULL;
                l_txn_rec.inv_material_transaction_id := NULL;
                l_txn_rec.transaction_quantity        := NULL;
                l_txn_rec.transaction_uom_code        := '';
                l_txn_rec.transacted_by               := NULL;
                l_txn_rec.transaction_status_code     := '';
                l_txn_rec.transaction_action_code     := '';
                l_txn_rec.message_id                  := NULL;
                l_txn_rec.object_version_number       := '';
                l_txn_rec.split_reason_code           := '';
                  
                               
                l_msg_data     := NULL;
                l_init_msg_lst := NULL;
                fnd_msg_pub.initialize;
                CSI_ITEM_INSTANCE_PUB.UPDATE_ITEM_INSTANCE(p_api_version           => 1,
                                                           p_commit                => 'F',
                                                           p_init_msg_list         => 'T',
                                                           p_validation_level      => l_validation_level,
                                                           p_instance_rec          => l_instance_rec,
                                                           p_ext_attrib_values_tbl => l_ext_attrib_values,
                                                           p_party_tbl             => l_party_tbl,
                                                           p_account_tbl           => l_account_tbl,
                                                           p_pricing_attrib_tbl    => l_pricing_attrib_tbl,
                                                           p_org_assignments_tbl   => l_org_assignments_tbl,
                                                           p_asset_assignment_tbl  => l_asset_assignment_tbl,
                                                           p_txn_rec               => l_txn_rec,
                                                           x_instance_id_lst       => l_instance_id_lst,
                                                           x_return_status         => l_return_status,
                                                           x_msg_count             => l_msg_count,
                                                           x_msg_data              => l_msg_data);
                v_error_message:=null;
                IF l_return_status != 'S' THEN
                   --------API ERROR--------------
                   IF (fnd_msg_pub.count_msg > 0) THEN
                      FOR i IN 1 .. fnd_msg_pub.count_msg LOOP
                         fnd_msg_pub.get(p_msg_index     => i,
                                         p_encoded       => 'F',
                                         p_data          => l_msg_data,
                                         p_msg_index_out => l_msg_index_out);
                         v_error_message := v_error_message || l_msg_data;                     
                      END LOOP;
                   END IF;               
                   UPDATE XXOBJT.XXCSI_UPLOAD_ASSOCIATIONS_TMP
                   SET    status='ERROR',
                          error_message=v_error_message
                   WHERE  conc_request_id=v_conc_request_id
                   AND    instance_id    =party_rec.instance_id
                   AND    person_id      =party_rec.person_id;
                   fnd_file.put_line (fnd_file.log,'***********API ERROR (instance_id='||party_rec.instance_id||
                                                                                ',person_id='||party_rec.person_id||
                                                                           ') : '||v_error_message);
                   v_num_of_update_failured:=v_num_of_update_failured+1;                                                                      
                ELSE
                   --------API SUCCESS--------------
                   UPDATE XXOBJT.XXCSI_UPLOAD_ASSOCIATIONS_TMP
                   SET    status='SUCCESS',
                          error_message=''
                   WHERE  conc_request_id=v_conc_request_id
                   AND    instance_id    =party_rec.instance_id
                   AND    person_id      =party_rec.person_id;
                   -----fnd_file.put_line (fnd_file.log,'***********API SUCCESS');
                   v_num_of_update_success:=v_num_of_update_success+1;
                   COMMIT;
                END IF;  
                
                -----============the end of UPDATE INSTANCE==================
              exception
          when others then
             null;
        end;
        --------------   
        END LOOP;
    END IF;

    ------------------Display total information about this updload...----------------------------
    fnd_file.put_line (fnd_file.log,''); --empty line
    fnd_file.put_line (fnd_file.log,''); --empty line
    fnd_file.put_line (fnd_file.log,''); --empty line
    fnd_file.put_line (fnd_file.log,'***************************************************************************'); 
    fnd_file.put_line (fnd_file.log,'********************TOTAL INFORMATION******************************');
    fnd_file.put_line (fnd_file.log,'***************************************************************************');  
    fnd_file.put_line (fnd_file.log,'=========There are '||v_line_number||' lines in our file '||p_location||'/'||p_filename);
    fnd_file.put_line (fnd_file.log,'============='||v_num_of_non_valid_lines    ||' LINES ARE NON-VALID');
    fnd_file.put_line (fnd_file.log,'============='||v_num_of_success_ins_lines  ||' rows were SUCCESSFULY INSERTED into XXCSI_UPLOAD_ASSOCIATIONS_TMP table');
    fnd_file.put_line (fnd_file.log,'============='||v_num_of_failured_ins_lines ||' for these lines INSERT was FAILURED');
    fnd_file.put_line (fnd_file.log,'============='||v_num_of_update_success     ||' Accessories were SUCCESSFULY UPLOADED');
    fnd_file.put_line (fnd_file.log,'============='||v_num_of_update_failured    ||' api updates FAILURED');

    fnd_file.put_line (fnd_file.log,''); --empty line

    IF v_there_are_non_valid_rows='Y' THEN
         errcode :='1';  ---Warning
    ELSE
         errcode :='0';  ---Success
    END IF;
    
                                         
  EXCEPTION
    when stop_processing then
      NULL;
    when others then
      v_error_message:=' =============XXCONV_INSTALL_BASE_PKG.UPLOAD_ASSOCIATIONS_EMPLOYEES unexpected ERROR ('||v_step||' (utl-file line='||v_line_number||') : '||SQLERRM;
      errcode :='2' ;
      errbuf  := v_error_message;
      fnd_file.put_line (fnd_file.log, v_error_message );                                     
  end upload_associations_employees;  

  --------------------------------------------------------------------
  --  name:            create_instance
  --  create by:       XXX
  --  Revision:        1.0
  --  creation date:   XX.XX.XXXX
  --------------------------------------------------------------------
  --  purpose :        Handle write to log tbl
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  XX.XX.XXXX  XXX               initial build
  --------------------------------------------------------------------
  FUNCTION get_field_from_utl_file_line(p_line_str      IN VARCHAR2,
                                        p_field_number  IN NUMBER) RETURN VARCHAR2 IS
      v_last_comma_pos               NUMBER;
      v_pos                          NUMBER;
      v_num_of_columns_in_this_line  NUMBER;
      v_start_pos                    NUMBER;
      v_next_comma_pos               NUMBER;
      v_length                       NUMBER;                                 
                                     
  BEGIN

    if p_line_str is null      or
       p_field_number is null  or
       p_field_number <=0       then
         RETURN '';
    end if;

    select instr(p_line_str,',',-1)
    into   v_last_comma_pos
    from   dual;


    IF v_last_comma_pos >=1 THEN
       v_num_of_columns_in_this_line:=1;
       LOOP
          v_pos:=instr(p_line_str,',',1,v_num_of_columns_in_this_line);
          v_num_of_columns_in_this_line:=v_num_of_columns_in_this_line+1;
          IF v_pos>=v_last_comma_pos OR v_pos=0 THEN
              EXIT;
          END IF;
       END LOOP;
    END IF;

    -----return to_char(v_num_of_columns_in_this_line);

    IF p_field_number=v_num_of_columns_in_this_line THEN
        ----this is last column in this line
        return rtrim(substr(p_line_str,v_last_comma_pos+1),' ');
    ELSE
        IF p_field_number=1 THEN
           v_start_pos:=1;            
        ELSE
           v_start_pos:=instr(p_line_str,',',1,p_field_number-1)+1;
        END IF;
        v_next_comma_pos:=instr(p_line_str,',',1,p_field_number);  
        v_length:=v_next_comma_pos-v_start_pos;
        return ltrim(rtrim(substr(p_line_str,v_start_pos,v_length),' '),' ');
    END IF;
  EXCEPTION
    when others then
      return '';
  END get_field_from_utl_file_line;                                              

  --------------------------------------------------------------------
  --  name:            get_value_from_line
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   22/08/2012
  --------------------------------------------------------------------
  --  purpose :        get value from excel line
  --                   return short string each time by the deliminar
  --------------------------------------------------------------------
  --  ver  date        name             desc
  --  1.0  22/08/2012  Dalit A. Raviv   initial build
  --------------------------------------------------------------------
  function get_value_from_line( p_line_string in out varchar2,
                                p_err_msg     in out varchar2,
                                c_delimiter   in varchar2) return varchar2 is

    l_pos        number;
    l_char_value varchar2(50);

  begin

    l_pos := instr(p_line_string, c_delimiter);

    if nvl(l_pos, 0) < 1 then
       l_pos := length(p_line_string);
    end if;

    l_char_value := ltrim(rtrim(substr(p_line_string, 1, l_pos - 1)));

    p_line_string := substr(p_line_string, l_pos + 1);

    return l_char_value;
  exception
   when others then
     p_err_msg := 'get_value_from_line - '||substr(sqlerrm,1,250);
  end get_value_from_line;

  --------------------------------------------------------------------
  --  name:            Update_SW_version
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   22/08/2012
  --------------------------------------------------------------------
  --  purpose :        Handle conversions of SW_versions values at Install Base
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  22/08/2012  Dalit A. raviv    initial build
  --------------------------------------------------------------------
  procedure Update_SW_version  (errbuf         out varchar2,
                                retcode        out varchar2,
                                p_location     in  varchar2,  -- /UtlFiles/Forwarder
                                p_filename     in  varchar2) is
                                     
    l_file_hundler              utl_file.file_type;
    l_line_buffer               varchar2(2000);
    l_counter                   number               := 0;
    l_pos                       number;
    c_delimiter                 constant varchar2(1) := ',';
    
    l_new_att_4                 varchar2(150);
    l_new_att_5                 varchar2(150);
    l_instance_id               number;
    l_ovn                       number;
    
    l_instance_rec              csi_datastructures_pub.instance_rec;
    l_ext_attrib_values_tbl     csi_datastructures_pub.extend_attrib_values_tbl;
    l_party_tbl                 csi_datastructures_pub.party_tbl;
    l_account_tbl               csi_datastructures_pub.party_account_tbl;
    l_pricing_attrib_tbl        csi_datastructures_pub.pricing_attribs_tbl;
    l_org_assignments_tbl       csi_datastructures_pub.organization_units_tbl;
    l_asset_assignment_tbl      csi_datastructures_pub.instance_asset_tbl;
    l_txn_rec                   csi_datastructures_pub.transaction_rec;
    l_instance_id_lst           csi_datastructures_pub.id_tbl;
    l_return_status             varchar2(2000);
    l_msg_count                 number;
    l_msg_data                  varchar2(2000);
    l_msg_index_out             number;
    l_err_msg                   varchar2(1000):= null;
    l_count                     number        := 0;
    
    general_exception           exception;
  begin

   errbuf  := null;
   retcode := 0;
   
   -- CONVERSION = 1171
   fnd_global.APPS_INITIALIZE(user_id => 1171,resp_id =>51137/*IL*//*51621 US*/ ,resp_appl_id => 514); 
   
   begin
      l_file_hundler := utl_file.fopen( location     => p_location,
                                        filename     => p_filename,
                                        open_mode    => 'r',
                                        max_linesize => 32000);
    exception
      when utl_file.invalid_path then
        retcode := 1;
        errbuf  := 'Import file was failes. 1 Invalid Path for ' || ltrim(p_filename);
        fnd_file.put_line(fnd_file.log,'Invalid Path for ' || ltrim(p_filename));
        dbms_output.put_line('Invalid Path for ' || ltrim(p_filename));
        raise;
      when utl_file.invalid_mode then
        retcode := 1;
        errbuf  := 'Import file was failes. 2 Invalid Mode for ' || ltrim(p_filename);
        fnd_file.put_line(fnd_file.log,'Invalid Mode for ' || ltrim(p_filename));
        dbms_output.put_line('Invalid Mode for ' || ltrim(p_filename));
        raise;
      when utl_file.invalid_operation then
        retcode := 1;
        errbuf  := 'Invalid operation for ' || ltrim(p_filename) ||substr(SQLERRM,1,500);
        fnd_file.put_line(fnd_file.log,'Invalid operation for ' || ltrim(p_filename) ||SQLERRM);
        dbms_output.put_line('Invalid operation for ' || ltrim(p_filename) ||SQLERRM);
        raise;
      when others then
        retcode := 1;
        errbuf  := 'Other for ' || ltrim(p_filename)||substr(SQLERRM,1,500);
        fnd_file.put_line(fnd_file.log,'Other for ' || ltrim(p_filename));
        dbms_output.put_line('Other for ' || ltrim(p_filename));
        raise;
    end;
   
    -- start read from file, do needed validation, and upload data to table
    -- Loop For All File's Lines
    loop
      begin
        -- goto next line
        l_counter      := l_counter + 1;
        l_new_att_4    := null;
        l_new_att_5    := null;
        l_instance_id  := null;
        l_ovn          := null;

        -- Get Line and handle exceptions
        begin
          utl_file.get_line(file   => l_file_hundler,
                            buffer => l_line_buffer);
        exception
          when utl_file.read_error then
            errbuf := 'Read Error for line: ' || l_counter;
            fnd_file.put_line(fnd_file.log,'Read Error for line: ' || l_counter);
            dbms_output.put_line('Read Error for line: ' || l_counter);
            raise general_exception;
          when no_data_found then
            exit;
          when others then
            errbuf := 'Read Error for line: ' || l_counter ||', Error: ' || substr(SQLERRM,1,200);
            fnd_file.put_line(fnd_file.log,'Read Error for line: ' || l_counter ||', Error: ' || substr(SQLERRM,1,200));
            dbms_output.put_line('Read Error for line: ' || l_counter ||', Error: ' || substr(SQLERRM,1,200));
            raise general_exception;
        end;

        -- Get data from line separate by deliminar
        if l_counter > 1 then
          l_count := l_count + 1;
          l_pos := 0;

          -- Employee number    Performance_2009.csv
          l_new_att_4   := get_value_from_line(l_line_buffer,
                                               l_err_msg,
                                               c_delimiter);

          l_new_att_5   := get_value_from_line(l_line_buffer,
                                               l_err_msg,
                                               c_delimiter);

          l_instance_id := get_value_from_line(l_line_buffer,
                                               l_err_msg,
                                               c_delimiter);

          fnd_file.put_line(fnd_file.log,l_count||' -- '||l_instance_id);
          dbms_output.put_line(l_count||' -- '||l_instance_id);

          -- call api
          Begin
            
            select cii.object_version_number
            into   l_ovn
            from   csi_item_instances cii
            where  cii.instance_id    = l_instance_id;
          exception
            when others then
              fnd_file.put_line(fnd_file.log,'Instance do not exists '||l_instance_id);
              dbms_output.put_line('Instance do not exists '||l_instance_id);
              errbuf  := 'wrong instance id';
              retcode := 1;
              raise general_exception;
          end;
          
          l_instance_rec.instance_id           := l_instance_id;
          l_instance_rec.object_version_number := l_ovn;
          l_instance_rec.attribute4            := l_new_att_4;
          l_instance_rec.attribute5            := l_new_att_5;
          l_txn_rec.transaction_id             := NULL;
          l_txn_rec.transaction_date           := SYSDATE;
          l_txn_rec.source_transaction_date    := SYSDATE;
          l_txn_rec.transaction_type_id        := 1;

          -- Now call the stored program
          csi_item_instance_pub.update_item_instance( 1.0,
                                                      'F',
                                                      'F',
                                                      1,
                                                      l_instance_rec,
                                                      l_ext_attrib_values_tbl,
                                                      l_party_tbl,
                                                      l_account_tbl,
                                                      l_pricing_attrib_tbl,
                                                      l_org_assignments_tbl,
                                                      l_asset_assignment_tbl,
                                                      l_txn_rec,
                                                      l_instance_id_lst,
                                                      l_return_status,
                                                      l_msg_count,
                                                      l_msg_data);

          if l_return_status != apps.fnd_api.g_ret_sts_success then
            fnd_msg_pub.get(p_msg_index     => -1,
                            p_encoded       => 'F',
                            p_data          => l_msg_data,
                            p_msg_index_out => l_msg_index_out);

            dbms_output.put_line('Err - update_item_instance - : '||substr(l_msg_data,1,240));
            fnd_file.put_line(fnd_file.log,'Err - update_item_instance - : '||l_msg_data);

            retcode := 1;
            errbuf  := 'Err - update_item_instance - : '||substr(l_msg_data,1,240);

          else
            retcode := 0;
            errbuf  := null;
          end if;    
        end if; -- l_counter

      exception
        when general_exception then
          null;
        when others then
          retcode := 1;
          errbuf  := 'Gen EXC loop - '||substr(SQLERRM,1,240);
          fnd_file.put_line(fnd_file.log,'Gen EXC loop - '||substr(SQLERRM,1,240));
          dbms_output.put_line('Gen EXC loop - '||substr(SQLERRM,1,240));
      end;
    end loop;
    utl_file.fclose(l_file_hundler);
    commit;
   
  end Update_SW_version; 

END xxconv_install_base_pkg;
/
