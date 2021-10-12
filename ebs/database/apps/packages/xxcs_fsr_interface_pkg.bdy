CREATE OR REPLACE PACKAGE BODY xxcs_fsr_interface_pkg IS

  --------------------------------------------------------------------
  -- name:            XXCS_FSR_INTERFACE_PKG
  -- create by:       Ella malchi
  -- Revision:        1.13
  -- creation date:   xx/xx/2010
  --------------------------------------------------------------------
  -- purpose :        process_fsr_request
  --------------------------------------------------------------------
  -- ver  date        name             desc
  -- 1.0  xx/xx/2010  Ella malchi      initial build
  -- 1.1  09/01/2011  Dalit A. Raviv   procedure process_fsr_request
  --                                   change logic of select at  line 1343
  --                                   serial number use to be uniqe number
  --                                   now serial number can be none uniqe number
  --                                   but just one will be active.
  -- 1.2  10.01.2011  yuval tal        add process_attachments +
  --                                   change process_fsr_request (call process_attachments)
  -- 1.3  30/01/2011  Dalit A. Raviv   add validation on procedure:
  --                                   add incident date validation - can not be grather then current date
  -- 1.4  15/05/2011  Dalit A. Raviv   Procedure get_price_list_header_id add  logic
  -- 1.5  22/05/2011  Dalit A. Raviv   Procedure create_fsr_request:
  --                                   add Project_Number in SR creation API
  -- 1.6  29/05/2011  Dalit A. Raviv   change message in procedure process_fsr_request
  --                                   change logic of BILL_TO/SHIP_TO at procedure create_fsr_request
  --                                   create_fsr_note x_err_msg - return null and not note count
  -- 1.7  27/11/2011  Dalit A. raviv   update_addnl_params_conc change logic
  -- 1.8  10/01/2012  Dalit A. RAviv   procedure update_addnl_params_conc
  --                                   add field to update (error_message = null)
  -- 1.9  22/01/2012  Dalit A. Raviv   procedure process_fsr_request call fnd message for error messages
  -- 1.10 29/01/2012  Dalit A. Raviv   procedure process_fsr_request
  --                                   1) app_initialize modifications: a)change place at prog,
  --                                      b) take org_id from header tbl, c)do app_initialize only when org_id is changed.
  --                                   procedure create_fsr_request
  --                                   Change logic of finding contract - first bring contract from type
  --                                   Warrenty if not fount bring what you did find
  -- 1.11 28/05/2012  Dalit A. Raviv   1) Some SR that created have closed date of year 01/01/4712
  --                                      This is oncorrect. The solution is to add procedure (that will 
  --                                      call immidiate after SR creation) that will update SR status
  --                                     to closed and set closed_date to sysdate. 
  --                                   2) Enable change of the SR status in case SR was updated by eFSR.
  --                                   3) Enable distributors that are not the OWNER of the eFSR to create eFSR.
  --                                   4) Customize the eFSR to recognize also GA customers.
  -- 1.12 10/03/2013  Dalit A. Raviv   procedure create_fsr_charges, create_fsr_request - new field need to be send to API (12.1.3)  
  -- 1.13 02/05/2013  Dalit A. Raviv   procedure create_fsr_request add validation for WATER-JET
  -- 1.14 1.12.13     Yuval Tal        modify create_fsr_request: CR1163-Service - Customization support new operating unit 737
  --------------------------------------------------------------------

  invalid_request EXCEPTION;
  g_user_id fnd_user.user_id%TYPE;

  SUBTYPE r_service_request_rec_type IS cs_servicerequest_pvt.service_request_rec_type;
  SUBTYPE t_notes_table_type IS cs_servicerequest_pvt.notes_table;
  SUBTYPE t_contacts_table_type IS cs_servicerequest_pvt.contacts_table;
  SUBTYPE o_sr_update_out_rec_type IS cs_servicerequest_pvt.sr_update_out_rec_type;
  SUBTYPE o_sr_create_out_rec_type IS cs_servicerequest_pvt.sr_create_out_rec_type;

  /*  SUBTYPE r_service_request_rec_type IS cs_servicerequest_pub.service_request_rec_type;
  
  SUBTYPE t_notes_table_type IS cs_servicerequest_pub.notes_table;
  SUBTYPE t_contacts_table_type IS cs_servicerequest_pub.contacts_table;
  SUBTYPE o_sr_update_out_rec_type IS cs_servicerequest_pub.sr_update_out_rec_type;
  SUBTYPE o_sr_create_out_rec_type IS cs_servicerequest_pub.sr_create_out_rec_type;*/

  --------------------------------------------------------------------
  --  name:            capture_counter_reading
  --  create by:       Ella Malchi
  --  Revision:        1.0
  --  creation date:   xx/xx/2010
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  xx/xx/2010  Ella Malchi     initial build
  --------------------------------------------------------------------
  PROCEDURE capture_counter_reading(p_instance_id   IN NUMBER,
                                    p_reading_value IN NUMBER,
                                    x_return_status IN OUT VARCHAR2,
                                    x_err_msg       IN OUT VARCHAR2) IS
  
    l_counter_id            NUMBER;
    l_counter_reading_id    NUMBER;
    l_max_reading           NUMBER;
    t_txn_tbl               csi_datastructures_pub.transaction_tbl;
    t_counter_reading_tbl   csi_ctr_datastructures_pub.counter_readings_tbl;
    t_counter_prop_read_tbl csi_ctr_datastructures_pub.ctr_property_readings_tbl;
  
    l_msg_count     NUMBER;
    l_msg_data      VARCHAR2(500);
    l_msg_index_out NUMBER;
  
  BEGIN
  
    x_return_status := fnd_api.g_ret_sts_success;
  
    BEGIN
    
      SELECT ca.counter_id
        INTO l_counter_id
        FROM csi_counter_associations_v ca
       WHERE ca.source_object_id = p_instance_id
         AND ca.source_object_code = 'CP';
    
    EXCEPTION
      WHEN OTHERS THEN
        x_err_msg := x_err_msg || 'Counter not defined,';
        RETURN;
      
    END;
  
    SELECT nvl(MAX(counter_reading), 0)
      INTO l_max_reading
      FROM csi_counter_readings
     WHERE counter_id = l_counter_id;
  
    IF l_max_reading >= p_reading_value THEN
      x_err_msg := x_err_msg ||
                   'Counter value is smaller or equal to existing value,';
      RETURN;
    END IF;
  
    SELECT csi_counter_readings_s.nextval
      INTO l_counter_reading_id
      FROM dual;
  
    t_counter_reading_tbl(1).counter_value_id := l_counter_reading_id;
    t_counter_reading_tbl(1).counter_id := l_counter_id;
    t_counter_reading_tbl(1).value_timestamp := SYSDATE;
    t_counter_reading_tbl(1).counter_reading := nvl(p_reading_value, 0);
    t_counter_reading_tbl(1).migrated_flag := 'N';
    t_counter_reading_tbl(1).life_to_date_reading := nvl(p_reading_value, 0);
    t_counter_reading_tbl(1).net_reading := nvl(p_reading_value, 0);
    t_counter_reading_tbl(1).disabled_flag := 'N';
    t_counter_reading_tbl(1).parent_tbl_index := 1;
    -----
    t_txn_tbl(1).source_transaction_date := trunc(SYSDATE);
    t_txn_tbl(1).transaction_type_id := 80;
    t_txn_tbl(1).object_version_number := 1;
    t_txn_tbl(1).source_header_ref_id := p_instance_id;
  
    csi_counter_readings_pub.capture_counter_reading(p_api_version      => 1.0,
                                                     p_commit           => 'F',
                                                     p_init_msg_list    => 'T',
                                                     p_validation_level => fnd_api.g_valid_level_none,
                                                     p_txn_tbl          => t_txn_tbl,
                                                     p_ctr_rdg_tbl      => t_counter_reading_tbl,
                                                     p_ctr_prop_rdg_tbl => t_counter_prop_read_tbl,
                                                     x_return_status    => x_return_status,
                                                     x_msg_count        => l_msg_count,
                                                     x_msg_data         => l_msg_data);
  
    IF x_return_status != fnd_api.g_ret_sts_success THEN
      fnd_msg_pub.get(p_msg_index     => -1,
                      p_encoded       => 'F',
                      p_data          => l_msg_data,
                      p_msg_index_out => l_msg_index_out);
    
      x_err_msg := l_msg_data;
    
    END IF;
  
  END capture_counter_reading;

  --------------------------------------------------------------------
  --  name:            get_price_list_header_id
  --  create by:       Ella Malchi
  --  Revision:        1.0
  --  creation date:   xx/xx/2010
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  xx/xx/2010  Ella Malchi     initial build
  --  1.1  15/05/2011  Dalit A. Raviv  if there is no price list bring
  --                                   the price list from profile CS_CHARGE_DEFAULT_PRICE_LIST
  --------------------------------------------------------------------
  FUNCTION get_price_list_header_id(p_service_line_id     NUMBER,
                                    p_business_process_id NUMBER,
                                    p_instance_id         NUMBER)
    RETURN NUMBER IS
  
    l_pricing_tbl   oks_con_coverage_pub.pricing_tbl_type; -- Fix bug 3546811
    l_price_list_id NUMBER := NULL;
    l_return_status VARCHAR2(30); -- Fix bug 3546811
    l_msg_count     NUMBER; -- Fix bug 3546811
    l_msg_data      VARCHAR2(30); -- Fix bug 3546811
    l_record_count  NUMBER; -- Fix bug 3546811
    --l_mesg_index_out   NUMBER; -- Fix bug 3546811
    --l_business_process VARCHAR2(50);
  
  BEGIN
  
    -- l_profile_price_list_id := to_number(fnd_profile.value('CS_CHARGE_DEFAULT_PRICE_LIST'));
  
    IF p_service_line_id IS NOT NULL THEN
      /***  No Contract ***/
    
      oks_con_coverage_pub.get_bp_pricelist(p_api_version         => 1.0,
                                            p_init_msg_list       => 'T',
                                            p_contract_line_id    => p_service_line_id,
                                            p_business_process_id => p_business_process_id,
                                            p_request_date        => SYSDATE,
                                            x_return_status       => l_return_status,
                                            x_msg_count           => l_msg_count,
                                            x_msg_data            => l_msg_data,
                                            x_pricing_tbl         => l_pricing_tbl);
    
    END IF;
  
    IF (l_return_status = 'S') AND (l_pricing_tbl.count > 0) THEN
      l_record_count  := l_pricing_tbl.first;
      l_price_list_id := to_number(l_pricing_tbl(l_record_count)
                                   .bp_price_list_id);
    ELSE
    
      l_price_list_id := xxcs_price_list_chg_pkg.get_price_list_id(p_business_process_id,
                                                                   p_instance_id);
      IF l_price_list_id IS NULL THEN
        -- to get the responsibility
        -- 1.1 15/05/2011 Dalit A. Raviv
        l_price_list_id := fnd_profile.value('CS_CHARGE_DEFAULT_PRICE_LIST');
        /*l_price_list_id := fnd_profile.VALUE_SPECIFIC(NAME => ,
                                      null ,-- user
                                      RESPONSIBILITY_ID => ,
                                      null, -- appl
                                      null, -- appl
                                      null );-- appl
        
        ('CS_CHARGE_DEFAULT_PRICE_LIST');*/
      END IF;
    
    END IF;
  
    RETURN l_price_list_id;
  
  END get_price_list_header_id;

  --------------------------------------------------------------------
  --  name:            create_fsr_note
  --  create by:       Ella Malchi
  --  Revision:        1.0
  --  creation date:   xx/xx/2010
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  xx/xx/2010  Ella Malchi     initial build
  --  1.1  29/05/2011  Dalit A. raviv  x_err_msg return null
  --------------------------------------------------------------------
  PROCEDURE create_fsr_note(p_fsr_id            IN NUMBER,
                            p_registration_code IN NUMBER,
                            --p_incident_id       IN NUMBER,
                            --p_entered_date      IN DATE,
                            --p_org_id            IN NUMBER,
                            t_notes_tbl     IN OUT t_notes_table_type,
                            x_return_status IN OUT VARCHAR2,
                            x_err_msg       IN OUT VARCHAR2) IS
  
    CURSOR csr_fsr_notes IS
      SELECT *
        FROM xxobjt_fsr_note
       WHERE fsr_id = p_fsr_id
         AND registration_code = p_registration_code;
  
    cur_note csr_fsr_notes%ROWTYPE;
    --l_msg_count      NUMBER;
    --l_note_id        NUMBER;
    l_note_counter   NUMBER;
    t_notes_tbl_miss t_notes_table_type;
  
  BEGIN
  
    x_return_status := fnd_api.g_ret_sts_success;
    x_err_msg       := NULL;
  
    l_note_counter := 1;
    t_notes_tbl    := t_notes_tbl_miss;
  
    FOR cur_note IN csr_fsr_notes LOOP
    
      t_notes_tbl(l_note_counter).note := substr(cur_note.note, 1, 2000);
      t_notes_tbl(l_note_counter).note_detail := substr(cur_note.note,
                                                        2000,
                                                        2000);
      t_notes_tbl(l_note_counter).note_type := 'KB_ACTION';
      t_notes_tbl(l_note_counter).note_context_type_01 := NULL;
      t_notes_tbl(l_note_counter).note_context_type_id_01 := NULL;
      t_notes_tbl(l_note_counter).note_context_type_02 := NULL;
      t_notes_tbl(l_note_counter).note_context_type_id_02 := NULL;
      t_notes_tbl(l_note_counter).note_context_type_03 := NULL;
      t_notes_tbl(l_note_counter).note_context_type_id_03 := NULL;
      l_note_counter := l_note_counter + 1;
    
    --jtf_notes_pub.create_note(p_api_version        => 1.0,
    --                          p_init_msg_list      => fnd_api.g_true,
    --                          p_commit             => fnd_api.g_false,
    --                          p_validation_level   => fnd_api.g_valid_level_full,
    --                          x_return_status      => x_return_status,
    --                          x_msg_count          => l_msg_count,
    --                          x_msg_data           => x_err_msg,
    --                          p_org_id             => p_org_id,
    --                          p_source_object_id   => l_msg_count, ---- New created SR
    --                          p_source_object_code => 'SR',
    --                          p_note_type          => 'KB_ACTION',
    --                          p_notes              => cur_note.note,
    --                          p_note_status        => 'I',
    --                          p_entered_date       => p_entered_date,
    --                          p_creation_date      => SYSDATE,
    --                          x_jtf_note_id        => l_note_id);
    
    --/*** If error, exit and rollback fsr  ***/
    
    END LOOP;
    x_err_msg := NULL; --l_note_counter;
  
  END create_fsr_note;

  --------------------------------------------------------------------
  --  name:            create_fsr_charges
  --  create by:       Ella Malchi
  --  Revision:        1.0
  --  creation date:   xx/xx/2010
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  xx/xx/2010  Ella Malchi     initial build
  --  1.1  10/03/2013  Dalit A. Raviv  new field need to be send to API (12.1.3)
  --------------------------------------------------------------------
  PROCEDURE create_fsr_charges(p_fsr_id              IN NUMBER,
                               p_registration_code   IN NUMBER,
                               p_incident_rec        IN cs_incidents_all_b%ROWTYPE,
                               p_business_process_id IN NUMBER,
                               p_org_id              NUMBER,
                               x_return_status       IN OUT VARCHAR2,
                               x_err_msg             IN OUT VARCHAR2) IS
  
    CURSOR csr_fsr_charges IS
      SELECT *
        FROM xxobjt_fsr_charges
       WHERE fsr_id = p_fsr_id
         AND registration_code = p_registration_code
         FOR UPDATE OF estimate_detail_id;
  
    cur_fsr_charges          csr_fsr_charges%ROWTYPE;
    t_charges_rec            cs_charge_details_pub.charges_rec_type;
    l_charge_item_id         NUMBER;
    l_charge_revision        VARCHAR2(3);
    l_material_billable_flag VARCHAR2(30);
    l_transaction_type_id    NUMBER;
    l_txn_billing_type_id    NUMBER;
    l_order_category_code    VARCHAR2(10);
    l_price_list_id          NUMBER;
    l_currency_code          VARCHAR2(3);
    l_msg_count              NUMBER;
    l_object_version_number  NUMBER;
    l_msg_data               VARCHAR2(500);
    l_estimate_detail_id     NUMBER;
    l_line_number            NUMBER;
    l_uom_code               VARCHAR2(3);
    l_msg_index_out          NUMBER;
    l_list_price             NUMBER;
  
  BEGIN
  
    x_return_status := fnd_api.g_ret_sts_success;
  
    FOR cur_fsr_charges IN csr_fsr_charges LOOP
    
      l_charge_item_id         := NULL;
      l_charge_revision        := NULL;
      l_material_billable_flag := NULL;
      l_transaction_type_id    := NULL;
      l_txn_billing_type_id    := NULL;
      l_order_category_code    := NULL;
      l_price_list_id          := NULL;
      l_currency_code          := NULL;
      l_list_price             := NULL;
      l_msg_count              := NULL;
      l_object_version_number  := NULL;
      l_msg_data               := NULL;
      l_estimate_detail_id     := NULL;
      l_line_number            := NULL;
      l_uom_code               := NULL;
      l_msg_index_out          := NULL;
    
      BEGIN
        SELECT inventory_item_id,
               xxinv_utils_pkg.get_current_revision(inventory_item_id,
                                                    organization_id),
               material_billable_flag,
               primary_uom_code
          INTO l_charge_item_id,
               l_charge_revision,
               l_material_billable_flag,
               l_uom_code
          FROM mtl_system_items_b msi
         WHERE msi.segment1 = cur_fsr_charges.item
           AND organization_id = xxinv_utils_pkg.get_master_organization_id;
      EXCEPTION
        WHEN OTHERS THEN
          x_err_msg       := 'Charge query(Item: ' || cur_fsr_charges.item ||
                             ', Qty: ' || cur_fsr_charges.quantity || '): ' ||
                             SQLERRM;
          x_return_status := fnd_api.g_ret_sts_error;
          RETURN;
      END;
    
      BEGIN
        SELECT ctt.transaction_type_id,
               ctb.txn_billing_type_id,
               ctt.line_order_category_code
          INTO l_transaction_type_id,
               l_txn_billing_type_id,
               l_order_category_code
          FROM cs_transaction_types_b ctt, cs_txn_billing_types ctb
         WHERE ctt.transaction_type_id = ctb.transaction_type_id
           AND nvl(ctt.attribute4, 'N') = 'Y'
           AND ctb.billing_type = l_material_billable_flag
           AND ctt.line_order_category_code =
               decode(abs(cur_fsr_charges.quantity),
                      cur_fsr_charges.quantity,
                      'ORDER',
                      'RETURN');
      
      EXCEPTION
        WHEN OTHERS THEN
          x_err_msg       := 'Charges transaction query: ' || SQLERRM;
          x_return_status := fnd_api.g_ret_sts_error;
          RETURN;
      END;
    
      l_price_list_id := get_price_list_header_id(p_service_line_id     => p_incident_rec.contract_service_id,
                                                  p_business_process_id => p_business_process_id,
                                                  p_instance_id         => p_incident_rec.customer_product_id);
    
      BEGIN
        SELECT currency_code
          INTO l_currency_code
          FROM qp_list_headers_all_b
         WHERE list_header_id = l_price_list_id;
      
      EXCEPTION
        WHEN OTHERS THEN
          x_err_msg       := 'Price List Query: ' || SQLERRM;
          x_return_status := fnd_api.g_ret_sts_error;
          RETURN;
      END;
    
      t_charges_rec.org_id               := p_org_id;
      t_charges_rec.incident_id          := p_incident_rec.incident_id;
      t_charges_rec.original_source_id   := p_incident_rec.incident_id;
      t_charges_rec.original_source_code := 'SR';
      t_charges_rec.charge_line_type     := 'ACTUAL';
      -- t_charges_rec.line_number          := cur_charge.line_number;
      t_charges_rec.inventory_item_id_in := l_charge_item_id;
      t_charges_rec.item_revision        := l_charge_revision;
      t_charges_rec.txn_billing_type_id  := l_txn_billing_type_id;
      t_charges_rec.transaction_type_id  := l_transaction_type_id;
      t_charges_rec.unit_of_measure_code := l_uom_code;
      t_charges_rec.quantity_required    := cur_fsr_charges.quantity;
      t_charges_rec.currency_code        := l_currency_code;
    
      cs_pricing_item_pkg.call_pricing_item(p_api_version       => 1.0,
                                            p_init_msg_list     => 'F',
                                            p_commit            => 'F',
                                            p_validation_level  => NULL,
                                            p_inventory_item_id => l_charge_item_id,
                                            p_price_list_id     => l_price_list_id,
                                            p_uom_code          => l_uom_code,
                                            p_currency_code     => l_currency_code,
                                            p_quantity          => cur_fsr_charges.quantity,
                                            p_org_id            => p_org_id,
                                            x_list_price        => l_list_price,
                                            x_return_status     => x_return_status,
                                            x_msg_count         => l_msg_count,
                                            x_msg_data          => l_msg_data);
    
      IF x_return_status = 'S' THEN
      
        t_charges_rec.list_price    := l_list_price;
        t_charges_rec.selling_price := l_list_price;
      
      END IF;
    
      t_charges_rec.bill_to_party_id    := p_incident_rec.bill_to_party_id;
      t_charges_rec.bill_to_account_id  := p_incident_rec.bill_to_account_id;
      t_charges_rec.ship_to_party_id    := p_incident_rec.ship_to_party_id;
      t_charges_rec.ship_to_account_id  := p_incident_rec.ship_to_account_id;
      t_charges_rec.ship_to_org_id      := p_incident_rec.ship_to_site_use_id;
      t_charges_rec.invoice_to_org_id   := p_incident_rec.bill_to_site_use_id;
      t_charges_rec.after_warranty_cost := 0;
      t_charges_rec.no_charge_flag      := 'Y';
      t_charges_rec.line_category_code  := l_order_category_code;
      t_charges_rec.price_list_id       := l_price_list_id;
      t_charges_rec.source_code         := 'SR';
      t_charges_rec.source_id           := p_incident_rec.incident_id;
      t_charges_rec.business_process_id := p_business_process_id;
      t_charges_rec.contract_id         := p_incident_rec.contract_id;
      t_charges_rec.contract_line_id    := p_incident_rec.contract_service_id;
      -- 10/03/2013 Dalit A. Raviv - new field need to be send to API
      t_charges_rec.instrument_payment_use_id := NULL;
      cs_charge_details_pub.create_charge_details(p_api_version           => 1.0,
                                                  p_init_msg_list         => 'T',
                                                  p_commit                => 'F',
                                                  p_validation_level      => fnd_api.g_valid_level_none,
                                                  x_return_status         => x_return_status,
                                                  x_msg_count             => l_msg_count,
                                                  x_object_version_number => l_object_version_number,
                                                  x_msg_data              => l_msg_data,
                                                  x_estimate_detail_id    => l_estimate_detail_id,
                                                  x_line_number           => l_line_number,
                                                  p_resp_appl_id          => fnd_global.resp_appl_id,
                                                  p_resp_id               => fnd_global.resp_id,
                                                  p_user_id               => g_user_id,
                                                  p_login_id              => NULL,
                                                  p_transaction_control   => fnd_api.g_true,
                                                  p_charges_rec           => t_charges_rec);
    
      IF x_return_status != fnd_api.g_ret_sts_success THEN
        IF (fnd_msg_pub.count_msg > 0) THEN
          FOR i IN 1 .. fnd_msg_pub.count_msg LOOP
            fnd_msg_pub.get(p_msg_index     => i,
                            p_encoded       => 'F',
                            p_data          => l_msg_data,
                            p_msg_index_out => l_msg_index_out);
            x_err_msg := x_err_msg || l_msg_data || chr(10);
          END LOOP;
        ELSE
          x_err_msg := l_msg_data;
        END IF;
        RETURN;
      END IF;
    
      UPDATE xxobjt_fsr_charges
         SET estimate_detail_id = l_estimate_detail_id
       WHERE CURRENT OF csr_fsr_charges;
    
    END LOOP;
  
    /***
             For each material line we need to check that the item is install base trackable.
             We need to check if this item exist under the dealer, and not under the serial number
            (there are no parent / child relationship):
            If exist ' update the parent according to the service request serial number
            If doesn't exist ' create the item under the serial number
    
         csf_debrief_update_pkg - line 785
         -----------------------------------------------
            l_instance_status_id :=to_number(l_instance_status); --added  for bug 3192060
       csf_ib.update_install_base(
       p_api_version            => 1.0,
       p_init_msg_list          => null,
       p_commit                 => null,
       p_validation_level       => null,
       x_return_status          => l_return_status,
       x_msg_count              => l_msg_count,
       x_msg_data               => l_msg_data,
       x_new_instance_id        => l_new_instance_id, --
       p_in_out_flag            => l_in_out_flag,  --
       p_transaction_type_id    => l_transaction_type_id_csi,
       p_txn_sub_type_id        => l_txn_sub_type_id,
       p_instance_id            => l_instance_id,
       p_inventory_item_id      => l_inventory_item_id,
       p_inv_organization_id    => l_organization_id,
       p_inv_subinventory_name  => l_subinventory_code,
       p_inv_locator_id         => l_locator_id,
       p_quantity               => l_quantity,
       p_inv_master_organization_id => l_inv_master_organization_id,
       p_mfg_serial_number_flag => 'N',
       p_serial_number          => l_item_serial_number,
       p_lot_number             => l_item_lotnumber,
       p_revision               => l_revision,
       p_unit_of_measure        => l_uom_code,
       p_party_id               => l_party_id,
       p_party_account_id       => l_customer_account_id,
       p_party_site_id          => l_party_site_id,
       p_parent_instance_id     => l_parent_product_id,
    p_instance_status_id     => l_instance_status_id,  --added for bug 3192060
    p_item_operational_status_code => l_item_operational_status_code);
    
    
    
         ***/
  
  END create_fsr_charges;

  --------------------------------------------------------------------
  --  name:            create_fsr_request
  --  create by:       Ella Malchi
  --  Revision:        1.5
  --  creation date:   07/12/2009
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  07/12/2009  Ella Malchi     initial build
  --  1.1  22/05/2011  Dalit A. Raviv  add project number at SR create
  --  1.2  29/01/2012  Dalit A. Raviv  change logic of finding contract create_fsr_request
  --                                   today the first contract retrieve is the contract
  --                                   that connect to SR this is not good.
  --                                   If there is contract from type WR (Warrenty) this
  --                                   contract should add to the SR.
  --  1.3  28/05/2012  Dalit A. Raviv  Fix bug on close date field, it enters wrong date
  --  1.4  10/03/2013  Dalit A. Raviv  new field need to be send to API (12.1.3) 
  --  1.5  02/05/2013  Dalit A. Raviv  In FSR the fields of Studio version and printer version as required
  --                                   but in the case of WATER JET these fields need to be null in oracle.
  --  
  --------------------------------------------------------------------
  PROCEDURE create_fsr_request(p_fsr_id            IN NUMBER,
                               p_registration_code IN NUMBER,
                               p_incident_date     IN DATE,
                               p_incident_type     IN VARCHAR2,
                               p_problem_meaning   IN VARCHAR2,
                               p_serial_number     IN VARCHAR2,
                               --p_machine_run_time      IN VARCHAR2,
                               --p_machine_part          IN VARCHAR2,
                               p_studio_version        IN VARCHAR2,
                               p_printer_version       IN VARCHAR2,
                               p_resolution_meaning    IN VARCHAR2,
                               p_sub_resolution_1      IN VARCHAR2,
                               p_sub_resolution_2      IN VARCHAR2,
                               p_sub_resolution_3      IN VARCHAR2,
                               p_party_id              IN NUMBER,
                               p_relationship_party_id IN NUMBER,
                               p_group_id              IN NUMBER,
                               p_owner_resource_id     IN NUMBER,
                               p_inventory_item_id     IN NUMBER,
                               p_item_rev              IN VARCHAR2,
                               p_organization_id       IN NUMBER,
                               p_location_type_code    IN VARCHAR2,
                               p_location_id           IN NUMBER,
                               p_customer_id           IN NUMBER,
                               p_instance_id           IN NUMBER,
                               --p_instance_number       IN NUMBER,
                               p_system_id           IN NUMBER,
                               p_category_id         IN NUMBER,
                               p_install_location_id IN NUMBER,
                               p_org_id              IN NUMBER,
                               p_cs_region           IN VARCHAR2,
                               x_incident_rec        IN OUT cs_incidents_all_b%ROWTYPE,
                               x_business_process_id IN OUT NUMBER,
                               x_return_status       IN OUT VARCHAR2,
                               x_err_msg             IN OUT VARCHAR2) IS
  
    CURSOR csr_request_contacts(p_relationship_contact_id NUMBER) IS
      SELECT c_tab.party_id,
             c_tab.contact_point_id,
             c_tab.contact_point_type,
             CASE
               WHEN c_tab.ord_field = c_tab.min_ord_field THEN
                'Y'
               ELSE
                'N'
             END primary_flag,
             c_tab.contact_type,
             c_tab.party_role_code
        FROM (SELECT contact_tab.party_id,
                     contact_tab.contact_point_id,
                     contact_tab.contact_point_type,
                     contact_tab.primary_flag,
                     contact_tab.contact_type,
                     contact_tab.party_role_code,
                     contact_tab.ord_field,
                     MIN(contact_tab.ord_field) over(PARTITION BY contact_tab.contact_type) min_ord_field
                FROM (SELECT cont_tab.party_id,
                             cont_tab.contact_point_id,
                             cont_tab.contact_point_type,
                             cont_tab.primary_flag,
                             cont_tab.contact_type,
                             cont_tab.party_role_code,
                             row_number() over(ORDER BY cont_tab.contact_point_type_ord_field, cont_tab.primary_flag_ord_field) ord_field
                        FROM (SELECT hr.party_id,
                                     hcp.contact_point_id,
                                     hcp.contact_point_type,
                                     hcp.primary_flag,
                                     'PARTY_RELATIONSHIP' contact_type,
                                     'CONTACT' party_role_code,
                                     decode(hcp.contact_point_type,
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
                                     decode(hcp.primary_flag, 'Y', 1, 2) primary_flag_ord_field
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
                                 AND hr.party_id = p_relationship_contact_id ---parameter
                              ) cont_tab) contact_tab) c_tab;
  
    r_service_request_rec r_service_request_rec_type;
    t_notes_table         t_notes_table_type;
    t_contacts_table      t_contacts_table_type;
    o_sr_create_out_rec   o_sr_create_out_rec_type;
    t_ent_contracts       cs_cont_get_details_pvt.ent_contract_tab;
  
    cur_contact           csr_request_contacts%ROWTYPE;
    l_msg_count           NUMBER;
    l_msg_data            VARCHAR2(500);
    l_msg_index_out       NUMBER;
    l_contact_point_index NUMBER;
  
    l_incident_type_id     NUMBER;
    l_incident_status_id   NUMBER;
    l_incident_severity_id NUMBER;
    l_incident_urgency_id  NUMBER;
    l_problem_code         fnd_lookup_values.lookup_code%TYPE;
    l_ship_to_site_use_id  NUMBER;
    l_ship_to_site_id      NUMBER;
    l_ship_account_id      NUMBER;
    l_ship_to_party_id     NUMBER;
    l_bill_to_site_use_id  NUMBER;
    l_bill_to_site_id      NUMBER;
    l_bill_account_id      NUMBER;
    l_bill_to_party_id     NUMBER;
    l_resolution_code      VARCHAR2(50);
    l_sub_resolution_code1 VARCHAR2(50);
    l_sub_resolution_code2 VARCHAR2(50);
    l_sub_resolution_code3 VARCHAR2(50);
    l_timezone_id          NUMBER;
    l_timezone_name        VARCHAR2(80);
    l_studio_version       fnd_flex_values.flex_value%TYPE;
    l_printer_version      fnd_flex_values.flex_value%TYPE;
    l_projet_name          VARCHAR2(360) := NULL;
  
    -- Dalit A. Raviv 28/05/2012
    l_return_status VARCHAR2(50) := NULL;
    l_err_msg       VARCHAR2(2500) := NULL;
    -- Dalit A. Raviv 02/05/2013  
    l_count NUMBER;
  
  BEGIN
    --cs_servicerequest_pub.initialize_rec(r_service_request_rec);
    cs_servicerequest_pvt.initialize_rec(r_service_request_rec);
    x_return_status := fnd_api.g_ret_sts_success;
  
    -- Incident Type and Business Process
    BEGIN
    
      SELECT cit.incident_type_id, cit.business_process_id
        INTO l_incident_type_id, x_business_process_id
        FROM cs_incident_types_vl cit
       WHERE upper(cit.name) = upper(p_incident_type);
    
    EXCEPTION
      WHEN OTHERS THEN
        x_return_status := fnd_api.g_ret_sts_error;
        x_err_msg       := 'Type Query: ' || SQLERRM;
        RETURN;
    END;
  
    -- Incident Status
    BEGIN
      SELECT cis.incident_status_id
        INTO l_incident_status_id
        FROM cs_incident_statuses_vl cis
       WHERE cis.name = 'FSR Closed';
    EXCEPTION
      WHEN no_data_found THEN
        x_return_status := fnd_api.g_ret_sts_error;
        x_err_msg       := 'Status Query: ' || SQLERRM;
        RETURN;
    END;
  
    -- Incident Severity
    BEGIN
      SELECT cie.incident_severity_id
        INTO l_incident_severity_id
        FROM cs_incident_severities_vl cie
       WHERE cie.name = 'Medium';
    EXCEPTION
      WHEN no_data_found THEN
        x_return_status := fnd_api.g_ret_sts_error;
        x_err_msg       := 'Severity Query: ' || SQLERRM;
        RETURN;
    END;
  
    -- incident Urgency
    BEGIN
      SELECT ciu.incident_urgency_id
        INTO l_incident_urgency_id
        FROM cs_incident_urgencies_vl ciu
       WHERE ciu.name = 'Medium';
    EXCEPTION
      WHEN no_data_found THEN
        x_return_status := fnd_api.g_ret_sts_error;
        x_err_msg       := 'Priority Query: ' || SQLERRM;
        RETURN;
    END;
  
    -- Incident Problem Code
    BEGIN
      SELECT lookup_code
        INTO l_problem_code
        FROM fnd_lookup_values_vl
       WHERE lookup_type = 'REQUEST_PROBLEM_CODE'
         AND upper(meaning) = upper(p_problem_meaning);
    
    EXCEPTION
      WHEN no_data_found THEN
        x_err_msg      := x_err_msg || 'invalid problem code, ';
        l_problem_code := NULL;
    END;
  
    -- Get customer data
    BEGIN
    
      SELECT hzsius1.party_site_use_id   ship_to_site_use_id,
             hzsite1.party_site_id       ship_to_site_id,
             hzacctsite1.cust_account_id ship_to_account_id,
             hzpty1.party_id             ship_to_party_id,
             hzsius3.party_site_use_id   bill_to_site_use_id,
             hzsite3.party_site_id       bill_to_site_id,
             hzacctsite3.cust_account_id bill_to_account_id,
             hzpty3.party_id             bill_to_party_id
        INTO l_ship_to_site_use_id,
             l_ship_to_site_id,
             l_ship_account_id,
             l_ship_to_party_id,
             l_bill_to_site_use_id,
             l_bill_to_site_id,
             l_bill_account_id,
             l_bill_to_party_id
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
         AND cip.relationship_type_code = cirt.ipa_relation_type_code(+)
         AND cip.party_source_table = 'HZ_PARTIES'
         AND cip.instance_party_id = cia.instance_party_id(+)
         AND (hzsius1.end_date IS NULL OR hzsius1.end_date > SYSDATE)
         AND hzsius1.status(+) = 'A'
         AND (hzsite1.end_date_active IS NULL OR
             hzsite1.end_date_active > SYSDATE)
         AND hzsite1.status = 'A'
         AND (hzsite2.end_date_active IS NULL OR
             hzsite2.end_date_active > SYSDATE)
         AND hzsite2.status = 'A'
         AND (hzsius3.end_date IS NULL OR hzsius3.end_date > SYSDATE)
         AND hzsius3.status(+) = 'A'
         AND (hzsite3.end_date_active IS NULL OR
             hzsite3.end_date_active > SYSDATE)
         AND hzsite3.status = 'A'
         AND (hcsu1.status = 'A' OR hcsu1.status IS NULL)
         AND (hcsu3.status = 'A' OR hcsu3.status IS NULL)
         AND (hzacctsite1.status = 'A' OR hzacctsite1.status IS NULL)
         AND (hzacctsite3.status = 'A' OR hzacctsite3.status IS NULL)
         AND cii.instance_id = p_instance_id;
    EXCEPTION
      WHEN no_data_found THEN
        l_bill_to_site_id     := NULL;
        l_bill_to_site_use_id := NULL;
        l_bill_account_id     := NULL;
        l_bill_to_party_id    := NULL;
        l_ship_to_site_id     := NULL;
        l_ship_to_site_use_id := NULL;
        l_ship_account_id     := NULL;
        l_ship_to_party_id    := NULL;
      
    END;
  
    -- Resolution Code (Incident_attribute_2)
    IF p_resolution_meaning IS NOT NULL THEN
      BEGIN
        SELECT flv.meaning
          INTO l_resolution_code
          FROM cs_sr_res_code_mapping_detail csc, fnd_lookup_values flv
         WHERE csc.category_id = p_category_id
           AND flv.language = 'US'
           AND flv.lookup_code = csc.resolution_code
           AND flv.lookup_type = 'REQUEST_RESOLUTION_CODE'
           AND nvl(csc.map_end_date_active, SYSDATE + 1) > SYSDATE
           AND nvl(csc.end_date_active, SYSDATE + 1) > SYSDATE
           AND upper(flv.description) = upper(p_resolution_meaning);
      
      EXCEPTION
        WHEN no_data_found THEN
          x_err_msg         := x_err_msg || 'invalid resolution code, ';
          l_resolution_code := NULL;
      END;
    ELSE
      l_resolution_code := NULL;
    END IF;
  
    -- Resolution Sub Code 1 (Incident_attribute_3)
    IF p_sub_resolution_1 IS NOT NULL THEN
      BEGIN
        SELECT flv2.meaning
          INTO l_sub_resolution_code1
          FROM fnd_lookup_values flv2
         WHERE flv2.lookup_type = 'XXCS_FULL_SUBRESOLUTION1_NLU'
           AND flv2.attribute_category = 'XXCS_FULL_SUBRESOLUTION1_NLU'
           AND upper(flv2.attribute1) = upper(l_resolution_code)
           AND flv2.language = 'US'
           AND upper(flv2.description) = upper(p_sub_resolution_1);
      EXCEPTION
        WHEN no_data_found THEN
          x_err_msg              := x_err_msg ||
                                    'invalid sub resolution code, ';
          l_sub_resolution_code1 := NULL;
      END;
    ELSE
      l_sub_resolution_code1 := NULL;
    END IF;
  
    -- Resolution Sub Code 1 (Incident_attribute_3)
    IF p_sub_resolution_2 IS NOT NULL THEN
      BEGIN
        SELECT flv2.meaning
          INTO l_sub_resolution_code2
          FROM fnd_lookup_values flv2
         WHERE flv2.lookup_type = 'XXCS_FULL_SUBRESOLUTION2_NLU'
           AND flv2.attribute_category = 'XXCS_FULL_SUBRESOLUTION2_NLU'
           AND upper(flv2.attribute1) = upper(l_sub_resolution_code1)
           AND flv2.language = 'US'
           AND upper(flv2.description) = upper(p_sub_resolution_2);
      EXCEPTION
        WHEN no_data_found THEN
          x_err_msg              := x_err_msg ||
                                    'invalid sub resolution2 code, ';
          l_sub_resolution_code2 := NULL;
      END;
    ELSE
      l_sub_resolution_code2 := NULL;
    END IF;
  
    -- Resolution Sub Code 1 (Incident_attribute_3)
    IF p_sub_resolution_3 IS NOT NULL THEN
      BEGIN
        SELECT flv2.meaning
          INTO l_sub_resolution_code3
          FROM fnd_lookup_values flv2
         WHERE flv2.lookup_type = 'XXCS_FULL_SUBRESOLUTION3_NLU'
           AND flv2.attribute_category = 'XXCS_FULL_SUBRESOLUTION3_NLU'
           AND upper(flv2.attribute1) = upper(l_sub_resolution_code2)
           AND flv2.language = 'US'
           AND upper(flv2.description) = upper(p_sub_resolution_3);
      EXCEPTION
        WHEN no_data_found THEN
          x_err_msg              := x_err_msg ||
                                    'invalid sub resolution3 code, ';
          l_sub_resolution_code3 := NULL;
      END;
    ELSE
      l_sub_resolution_code3 := NULL;
    END IF;
  
    IF p_printer_version IS NOT NULL THEN
      BEGIN
      
        SELECT flex_value
          INTO l_printer_version
          FROM fnd_flex_value_sets fvs, fnd_flex_values ffv
         WHERE fvs.flex_value_set_id = ffv.flex_value_set_id
           AND fvs.flex_value_set_name = 'XXCSI_EMBEEDED_SW_VERSION'
           AND flex_value = p_printer_version;
      
      EXCEPTION
        WHEN no_data_found THEN
          x_err_msg         := x_err_msg || 'invalid printer version, ';
          l_printer_version := NULL;
      END;
    ELSE
      l_printer_version := NULL;
    END IF;
  
    IF p_studio_version IS NOT NULL THEN
      BEGIN
      
        SELECT flex_value
          INTO l_studio_version
          FROM fnd_flex_value_sets fvs, fnd_flex_values ffv
         WHERE fvs.flex_value_set_id = ffv.flex_value_set_id
           AND fvs.flex_value_set_name = 'XXCSI_STUDIO_SW_VERSION'
           AND flex_value = p_studio_version;
      
      EXCEPTION
        WHEN no_data_found THEN
          x_err_msg        := x_err_msg || 'invalid studio version, ';
          l_studio_version := NULL;
      END;
    ELSE
      l_studio_version := NULL;
    END IF;
  
    -------------------------------------------
    -- 1.4 02/05/2013 Dalit A. Raviv 
    -- add validation for WATER-JET
    -- In FSR the fields of Studio version and printer version as required
    -- but in the case of WATER JET these fields need to be null.
    --  
    IF p_serial_number IS NOT NULL THEN
      l_count := 0;
    
      SELECT COUNT(1)
        INTO l_count
        FROM xxcs_items_printers_v pr, csi_item_instances cii
       WHERE cii.inventory_item_id = pr.inventory_item_id
         AND pr.item_type = 'WATER-JET'
         AND cii.serial_number = p_serial_number;
    
      IF l_count > 0 THEN
        l_studio_version  := NULL;
        l_printer_version := NULL;
      END IF;
    END IF;
  
    -- Time Zone
    BEGIN
      cs_tz_get_details_pvt.customer_preferred_time_zone(p_incident_id            => NULL,
                                                         p_task_id                => NULL,
                                                         p_resource_id            => NULL,
                                                         p_cont_pref_time_zone_id => NULL,
                                                         p_incident_location_id   => p_location_id,
                                                         p_incident_location_type => p_location_type_code,
                                                         p_contact_party_id       => p_relationship_party_id,
                                                         p_customer_id            => p_customer_id,
                                                         x_timezone_id            => l_timezone_id,
                                                         x_timezone_name          => l_timezone_name);
    
    END;
  
    -- Contract
    BEGIN
      cs_cont_get_details_pvt.get_contract_lines(p_api_version         => 1.0,
                                                 p_init_msg_list       => 'T',
                                                 p_contract_number     => NULL, --_contract_number,
                                                 p_service_line_id     => NULL, --l_service_line_id,
                                                 p_customer_id         => p_party_id,
                                                 p_site_id             => NULL, --l_site_id,
                                                 p_customer_account_id => p_customer_id, --l_account_id,
                                                 p_system_id           => p_system_id,
                                                 p_inventory_item_id   => p_inventory_item_id, --l_inventory_item_id,
                                                 p_customer_product_id => p_instance_id,
                                                 p_request_date        => p_incident_date, --sysdate,--nvl(i.incident_date, sysdate),
                                                 p_business_process_id => x_business_process_id, --v_business_process_id,
                                                 p_severity_id         => l_incident_severity_id, --v_severity_id,
                                                 p_time_zone_id        => l_timezone_id,
                                                 p_calc_resptime_flag  => 'Y', --l_calc_resptime_flag,
                                                 p_validate_flag       => 'Y', --l_validate_flag,
                                                 p_dates_in_input_tz   => 'N',
                                                 p_incident_date       => SYSDATE, --nvl(i.incident_date, sysdate),
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
            x_err_msg := x_err_msg || l_msg_data || chr(10);
          END LOOP;
        ELSE
          x_err_msg := l_msg_data;
        END IF;
        RETURN;
      END IF;
    
    END;
  
    -- 1.1 22/05/2011 Dalit A. Raviv
    -- Project Number project_number
    BEGIN
      IF p_system_id IS NOT NULL THEN
        SELECT hp.party_name
          INTO l_projet_name
          FROM csi_systems_b cs, hz_parties hp
         WHERE hp.party_id = cs.attribute2
           AND cs.system_id = p_system_id;
      END IF;
    
      r_service_request_rec.project_number := l_projet_name;
    EXCEPTION
      WHEN OTHERS THEN
        NULL;
    END;
  
    -- Assign Record
    r_service_request_rec.inventory_org_id := p_organization_id;
    IF p_org_id IN (737, 89) THEN
      --- OBJET US (OU)
      r_service_request_rec.request_date           := nvl(p_incident_date +
                                                          10 / 24,
                                                          SYSDATE);
      r_service_request_rec.incident_occurred_date := nvl(p_incident_date +
                                                          10 / 24,
                                                          SYSDATE);
    ELSE
      r_service_request_rec.request_date           := nvl(p_incident_date +
                                                          1 / 24,
                                                          SYSDATE);
      r_service_request_rec.incident_occurred_date := nvl(p_incident_date +
                                                          1 / 24,
                                                          SYSDATE);
    END IF;
    r_service_request_rec.type_id               := l_incident_type_id;
    r_service_request_rec.status_id             := l_incident_status_id;
    r_service_request_rec.severity_id           := l_incident_severity_id;
    r_service_request_rec.urgency_id            := l_incident_urgency_id;
    r_service_request_rec.owner_group_id        := p_group_id;
    r_service_request_rec.group_type            := 'RS_GROUP';
    r_service_request_rec.owner_id              := p_owner_resource_id;
    r_service_request_rec.resource_type         := 'RS_EMPLOYEE';
    r_service_request_rec.summary               := p_problem_meaning;
    r_service_request_rec.resolution_summary    := l_resolution_code;
    r_service_request_rec.caller_type           := 'ORGANIZATION';
    r_service_request_rec.customer_id           := p_party_id;
    r_service_request_rec.account_id            := p_customer_id;
    r_service_request_rec.bill_to_account_id    := l_bill_account_id;
    r_service_request_rec.bill_to_party_id      := l_bill_to_party_id;
    r_service_request_rec.bill_to_site_id       := l_bill_to_site_id;
    r_service_request_rec.bill_to_site_use_id   := l_bill_to_site_use_id;
    r_service_request_rec.ship_to_account_id    := l_ship_account_id;
    r_service_request_rec.ship_to_party_id      := l_ship_to_party_id;
    r_service_request_rec.ship_to_site_id       := l_ship_to_site_id;
    r_service_request_rec.ship_to_site_use_id   := l_ship_to_site_use_id;
    r_service_request_rec.install_site_id       := p_install_location_id;
    r_service_request_rec.publish_flag          := 'T';
    r_service_request_rec.verify_cp_flag        := 'N';
    r_service_request_rec.customer_product_id   := p_instance_id;
    r_service_request_rec.category_set_id       := xxinv_utils_pkg.get_default_category_set_id;
    r_service_request_rec.category_id           := p_category_id;
    r_service_request_rec.language              := 'US';
    r_service_request_rec.inventory_item_id     := p_inventory_item_id;
    r_service_request_rec.current_serial_number := p_serial_number;
    r_service_request_rec.inv_item_revision     := p_item_rev;
    r_service_request_rec.product_revision      := p_item_rev;
    r_service_request_rec.system_id             := p_system_id;
    r_service_request_rec.problem_code          := l_problem_code;
  
    r_service_request_rec.request_attribute_1 := p_category_id;
    r_service_request_rec.request_attribute_2 := l_resolution_code;
    r_service_request_rec.request_attribute_3 := l_sub_resolution_code1;
    r_service_request_rec.request_attribute_4 := l_sub_resolution_code2;
    r_service_request_rec.request_attribute_5 := l_sub_resolution_code3;
    -- r_service_request_rec.territory_id          := l_territory_id;
  
    r_service_request_rec.external_attribute_1 := p_cs_region;
    r_service_request_rec.external_attribute_2 := NULL;
    r_service_request_rec.external_attribute_3 := l_printer_version;
    r_service_request_rec.external_attribute_4 := l_studio_version; --- STUDIO version
  
    r_service_request_rec.sr_creation_channel      := 'PHONE';
    r_service_request_rec.last_update_channel      := 'PHONE';
    r_service_request_rec.creation_program_code    := 'CSXSRISR';
    r_service_request_rec.last_update_program_code := 'CSXSRISR';
    r_service_request_rec.last_update_date         := SYSDATE;
    r_service_request_rec.last_updated_by          := g_user_id;
    r_service_request_rec.incident_location_type   := 'HZ_PARTY_SITE'; --v_loc_type_code;
    r_service_request_rec.incident_location_id     := p_location_id;
  
    --  1.4  10/03/2013  Dalit A. Raviv  new field need to be send to API (12.1.3)
    r_service_request_rec.instrument_payment_use_id := NULL;
    --
  
    BEGIN
    
      -- 1.2  29/01/2012  Dalit A. Raviv  change logic of finding contract
      -- by loop on contract variable (table) if found type = WR exit
      -- else continue till the end, and bring when ever you have.
      FOR i IN 1 .. t_ent_contracts.count LOOP
        r_service_request_rec.contract_service_id := t_ent_contracts(i)
                                                     .service_line_id;
        r_service_request_rec.contract_id         := t_ent_contracts(i)
                                                     .contract_id;
        r_service_request_rec.coverage_type       := t_ent_contracts(i)
                                                     .coverage_type_code;
        r_service_request_rec.cust_po_number      := t_ent_contracts(i)
                                                     .service_po_number;
        r_service_request_rec.obligation_date     := t_ent_contracts(i)
                                                     .exp_reaction_time; --Open Date  ;
        IF t_ent_contracts(i).coverage_type_code = 'WR' THEN
          EXIT;
        END IF;
      END LOOP;
      /*r_service_request_rec.contract_service_id := t_ent_contracts(1).service_line_id;
        r_service_request_rec.contract_id         := t_ent_contracts(1).contract_id;
        r_service_request_rec.coverage_type       := t_ent_contracts(1).coverage_type_code;
        r_service_request_rec.cust_po_number      := t_ent_contracts(1).service_po_number;
        r_service_request_rec.obligation_date     := t_ent_contracts(1).exp_reaction_time; --Open Date  ;
      */
    EXCEPTION
      WHEN OTHERS THEN
        NULL;
    END;
  
    /***  Fill contact table ***/
    l_contact_point_index := 0;
    FOR cur_contact IN csr_request_contacts(p_relationship_party_id) LOOP
    
      l_contact_point_index := l_contact_point_index + 1;
      SELECT cs_hz_sr_contact_points_s.nextval
        INTO t_contacts_table(l_contact_point_index).sr_contact_point_id
        FROM dual;
    
      t_contacts_table(l_contact_point_index).party_id := cur_contact.party_id;
      t_contacts_table(l_contact_point_index).contact_point_id := cur_contact.contact_point_id;
      t_contacts_table(l_contact_point_index).contact_point_type := cur_contact.contact_point_type;
      t_contacts_table(l_contact_point_index).primary_flag := cur_contact.primary_flag;
      t_contacts_table(l_contact_point_index).contact_type := cur_contact.contact_type;
      t_contacts_table(l_contact_point_index).party_role_code := cur_contact.party_role_code;
      t_contacts_table(l_contact_point_index).start_date_active := SYSDATE;
    
    END LOOP;
  
    /***  Fill notes table ***/
    create_fsr_note(p_fsr_id            => p_fsr_id,
                    p_registration_code => p_registration_code,
                    --p_incident_id       => x_incident_rec.incident_id,
                    --p_entered_date      => SYSDATE,
                    --p_org_id            => p_org_id,
                    t_notes_tbl     => t_notes_table,
                    x_return_status => x_return_status,
                    x_err_msg       => x_err_msg);
  
    fnd_msg_pub.initialize;
    /*cs_servicerequest_pub.Create_ServiceRequest(p_api_version => ,
    p_init_msg_list => ,
    p_commit => ,
    x_return_status =>,
    x_msg_count => , 
    x_msg_data => ,
    p_resp_appl_id => ,
    p_resp_id => ,
    p_user_id => ,
    p_login_id => ,
    p_org_id => ,
    p_request_id => ,
    p_request_number => ,
    p_service_request_rec => ,
    p_notes => ,
    p_contacts => ,
    p_auto_assign => ,
    p_auto_generate_tasks => ,
    x_sr_create_out_rec =>  )*/
    cs_servicerequest_pvt.create_servicerequest(p_api_version         => 4.0,
                                                p_init_msg_list       => 'T',
                                                p_commit              => 'T',
                                                p_validation_level    => 0,
                                                x_return_status       => x_return_status,
                                                x_msg_count           => l_msg_count,
                                                x_msg_data            => l_msg_data,
                                                p_resp_appl_id        => fnd_profile.value('RESP_APPL_ID'),
                                                p_resp_id             => fnd_profile.value('RESP_ID'),
                                                p_user_id             => g_user_id,
                                                p_login_id            => NULL,
                                                p_org_id              => p_org_id,
                                                p_request_id          => x_incident_rec.incident_id,
                                                p_request_number      => NULL,
                                                p_service_request_rec => r_service_request_rec,
                                                p_notes               => t_notes_table,
                                                p_contacts            => t_contacts_table,
                                                p_auto_assign         => 'N',
                                                p_auto_generate_tasks => 'N',
                                                x_sr_create_out_rec   => o_sr_create_out_rec);
  
    IF x_return_status != fnd_api.g_ret_sts_success THEN
      IF (fnd_msg_pub.count_msg > 0) THEN
        FOR i IN 1 .. fnd_msg_pub.count_msg LOOP
          fnd_msg_pub.get(p_msg_index     => i,
                          p_encoded       => 'F',
                          p_data          => l_msg_data,
                          p_msg_index_out => l_msg_index_out);
          x_err_msg := x_err_msg || l_msg_data || chr(10);
        END LOOP;
      ELSE
        x_err_msg := l_msg_data;
      END IF;
      RETURN;
    END IF;
    --  1.3  28/05/2012  Dalit A. Raviv 
    IF x_return_status = 'S' THEN
      update_incident_status(p_incident_id        => o_sr_create_out_rec.request_id, -- i n
                             p_incident_status_id => l_incident_status_id, -- i n
                             x_return_status      => l_return_status, -- o v
                             x_err_msg            => l_err_msg); -- o v
      x_err_msg       := l_err_msg;
      x_return_status := l_return_status;
    
    END IF;
    --
    x_incident_rec.incident_id := o_sr_create_out_rec.request_id;
    BEGIN
      x_incident_rec.contract_id := t_ent_contracts(1).contract_id;
    EXCEPTION
      WHEN OTHERS THEN
        x_incident_rec.contract_id := NULL;
    END;
    x_incident_rec.contract_service_id   := o_sr_create_out_rec.contract_service_id;
    x_incident_rec.current_serial_number := p_serial_number;
    x_incident_rec.customer_product_id   := p_instance_id;
    x_incident_rec.customer_id           := p_party_id;
    x_incident_rec.bill_to_party_id      := l_bill_to_party_id;
    x_incident_rec.bill_to_customer      := l_bill_account_id;
    x_incident_rec.bill_to_site_id       := l_bill_to_site_id;
    x_incident_rec.bill_to_site_use_id   := l_bill_to_site_use_id;
    x_incident_rec.ship_to_party_id      := l_ship_to_party_id;
    x_incident_rec.ship_to_customer      := l_ship_account_id;
    x_incident_rec.ship_to_site_id       := l_ship_to_site_id;
    x_incident_rec.ship_to_site_use_id   := l_ship_to_site_use_id;
  
  END create_fsr_request;

  --------------------------------------------------------------------
  --  name:            update_fsr_request
  --  create by:       Ella Malchi
  --  Revision:        1.0
  --  creation date:   xx/xx/2010
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  xx/xx/2010  Ella Malchi     initial build
  --------------------------------------------------------------------
  PROCEDURE update_fsr_request(p_fsr_id                IN NUMBER,
                               p_registration_code     IN NUMBER,
                               p_incident_id           IN NUMBER,
                               p_object_version_number IN NUMBER,
                               --p_org_id                IN NUMBER,
                               x_return_status IN OUT VARCHAR2,
                               x_err_msg       IN OUT VARCHAR2) IS
  
    r_service_request_rec r_service_request_rec_type;
    t_notes_table         t_notes_table_type;
    t_contacts_table      t_contacts_table_type;
    o_sr_update_out_rec   o_sr_update_out_rec_type;
  
    l_msg_count     NUMBER;
    l_msg_data      VARCHAR2(500);
    l_msg_index_out NUMBER;
  
  BEGIN
  
    cs_servicerequest_pvt.initialize_rec(r_service_request_rec);
    x_return_status := fnd_api.g_ret_sts_success;
  
    r_service_request_rec.last_update_channel      := 'PHONE';
    r_service_request_rec.creation_program_code    := 'CSXSRISR';
    r_service_request_rec.last_update_program_code := 'CSXSRISR';
    r_service_request_rec.last_update_date         := SYSDATE;
    r_service_request_rec.last_updated_by          := g_user_id;
    r_service_request_rec.external_attribute_2     := 'Y';
  
    create_fsr_note(p_fsr_id            => p_fsr_id,
                    p_registration_code => p_registration_code,
                    --p_incident_id       => p_incident_id,
                    --p_entered_date      => SYSDATE,
                    --p_org_id            => p_org_id,
                    t_notes_tbl     => t_notes_table,
                    x_return_status => x_return_status,
                    x_err_msg       => x_err_msg);
  
    fnd_msg_pub.initialize;
    cs_servicerequest_pvt.update_servicerequest(p_api_version           => 4.0,
                                                p_init_msg_list         => 'T',
                                                p_commit                => 'T',
                                                p_validation_level      => 0,
                                                x_return_status         => x_return_status,
                                                x_msg_count             => l_msg_count,
                                                x_msg_data              => l_msg_data,
                                                p_request_id            => p_incident_id,
                                                p_object_version_number => p_object_version_number,
                                                p_resp_appl_id          => fnd_profile.value('RESP_APPL_ID'),
                                                p_resp_id               => fnd_profile.value('RESP_ID'),
                                                p_last_updated_by       => g_user_id,
                                                p_last_update_login     => NULL,
                                                p_last_update_date      => SYSDATE,
                                                p_service_request_rec   => r_service_request_rec,
                                                p_update_desc_flex      => 'T',
                                                p_notes                 => t_notes_table,
                                                p_contacts              => t_contacts_table,
                                                p_audit_comments        => NULL,
                                                p_called_by_workflow    => 'F',
                                                p_workflow_process_id   => NULL,
                                                p_auto_assign           => 'N',
                                                x_sr_update_out_rec     => o_sr_update_out_rec);
  
    IF x_return_status != fnd_api.g_ret_sts_success THEN
      IF (fnd_msg_pub.count_msg > 0) THEN
        FOR i IN 1 .. fnd_msg_pub.count_msg LOOP
          fnd_msg_pub.get(p_msg_index     => i,
                          p_encoded       => 'F',
                          p_data          => l_msg_data,
                          p_msg_index_out => l_msg_index_out);
          x_err_msg := x_err_msg || l_msg_data || chr(10);
        END LOOP;
      ELSE
        x_err_msg := l_msg_data;
      END IF;
      RETURN;
    END IF;
  
  END update_fsr_request;

  --------------------------------------------------------------------
  --  name:            process_fsr_request
  --  create by:       Ella malchi
  --  Revision:        1.0
  --  creation date:   xx/xx/2010
  --------------------------------------------------------------------
  --  purpose :        process_fsr_request
  --------------------------------------------------------------------
  --  ver  date        name             desc
  --  1.0  xx/xx/2010  Ella malchi      initial build
  --  1.1  09/01/2011  Dalit A. Raviv   change logic of select at  line 1343
  --                                    serial number use to be uniqe number
  --                                    now serial number can be none uniqe number
  --                                    but just one will be active.
  --  1.2  10/01/2011  yuval tal        add process_attachments +
  --                                    change process_fsr_request (call process_attachments)
  --  1.3  30/01/2011  Dalit A. Raviv   add incident date validation - can not be grather then current date - process_fsr_request
  --  1.4  29/05/2011  Dalit A. Raviv   change out message - Incorrect SR Number Provided
  --  1.5  22/01/2012  Dalit A. Raviv   call fnd message for error messages.
  --  1.6  29/01/2012  Dalit A. Raviv   1) app_initialize modifications:
  --                                       change place at prog,
  --                                       take org_id from header tbl,
  --                                       do app_initialize only when org_id is changed.
  --                                    2) Handle contract
  --  1.7  28/05/2012  Dalit A. Raviv   1) call update_incident_status after create SR
  --                                       to update status to Closed.
  --                                    2) add validation after Update_fsr_request
  --                                       if SR (FSR) is "Wait FSR" then call to 
  --                                       new procedure update_incident_status that will 
  --                                       change status to Closed FSR. 
  --  1.8  17/06/2012  Dalit A. Raviv   1) Enable distributors that are not the OWNER of the eFSR to create eFSR.
  --                                    2) Customize the eFSR to recognize also GA customers.
  --------------------------------------------------------------------
  PROCEDURE process_fsr_request(p_fsr_id            IN NUMBER,
                                p_registration_code IN NUMBER,
                                x_return_status     IN OUT VARCHAR2,
                                x_err_msg           IN OUT VARCHAR2) IS
  
    CURSOR csr_fsr_request IS
      SELECT *
        FROM xxobjt_fsr_header xfh
       WHERE xfh.fsr_id = p_fsr_id
         AND xfh.registration_code = p_registration_code -- New, Updated
       ORDER BY xfh.org_id; -- 1.6 29/01/2012  Dalit A. Raviv for apps_initialize
  
    cur_fsr_request     csr_fsr_request%ROWTYPE;
    t_incident_rec      cs_incidents_all_b%ROWTYPE;
    l_org_id            NUMBER := NULL; -------------------------
    l_group_id          NUMBER;
    l_cs_region         VARCHAR2(30);
    l_owner_resource_id NUMBER;
    l_party_id          NUMBER;
    --l_party_name              hz_parties.party_name%TYPE;
    l_contact_relationship_id NUMBER;
    l_inventory_item_id       NUMBER;
    l_item_rev                VARCHAR2(3);
    l_organization_id         NUMBER;
    l_location_type_code      VARCHAR2(20);
    l_location_id             NUMBER;
    l_owner_party_id          NUMBER;
    l_customer_id             NUMBER;
    l_instance_id             NUMBER;
    l_instance_number         NUMBER;
    l_system_id               NUMBER;
    l_category_id             NUMBER;
    l_install_location_id     NUMBER;
    l_business_process_id     NUMBER;
    l_incident_status_flag    VARCHAR2(1);
    l_err_msg                 VARCHAR2(500);
  
    l_flag    VARCHAR2(1) := 'N';
    l_errbuf  VARCHAR2(500);
    l_retcode NUMBER;
    -- 28/05/2012 Dalit A. Raviv
    l_incident_status_id NUMBER;
    -- 17/06/2012 Dalit A. Raviv
    l_party_dist_id NUMBER;
    l_party_id_temp NUMBER;
  
  BEGIN
  
    BEGIN
      x_err_msg := NULL;
    
      -- Fetch FSR
      OPEN csr_fsr_request;
      FETCH csr_fsr_request
        INTO cur_fsr_request;
      IF csr_fsr_request%NOTFOUND THEN
        RAISE no_data_found;
      END IF;
      CLOSE csr_fsr_request;
    
      --  1.6 29/01/2012  Dalit A. Raviv
      --  1) app_initialize modifications:
      --     change place at prog,
      --     take org_id from header tbl,
      --     do app_initialize only when org_id is changed.
      --
      -- check org_id changed
      IF nvl(l_org_id, 1) <> cur_fsr_request.org_id THEN
        l_flag := 'Y';
      ELSE
        l_flag := 'N';
      END IF;
      -- if org_id changed (or first time) do app_initialize
      IF l_flag = 'Y' THEN
        inv_globals.set_org_id(cur_fsr_request.org_id /*l_org_id*/);
        fnd_global.apps_initialize(g_user_id,
                                   fnd_profile.value_specific('XXCS_AUTO_DEBRIEF_RESPONSIBILITY',
                                                              NULL,
                                                              NULL,
                                                              NULL,
                                                              cur_fsr_request.org_id /*l_org_id*/),
                                   514);
        mo_global.init('QP');
      END IF;
      -- end 1.6 29/01/2012  Dalit A. Raviv
      x_return_status := fnd_api.g_ret_sts_success;
      l_err_msg       := NULL;
      l_org_id        := NULL;
      l_party_id      := NULL;
      --l_party_name              := NULL;
      l_contact_relationship_id := NULL;
      l_cs_region               := NULL;
      l_group_id                := NULL;
      l_owner_resource_id       := NULL;
      l_inventory_item_id       := NULL;
      l_item_rev                := NULL;
      l_organization_id         := NULL;
      l_location_type_code      := NULL;
      l_location_id             := NULL;
      l_owner_party_id          := NULL;
      l_customer_id             := NULL;
      l_instance_number         := NULL;
      l_system_id               := NULL;
      l_category_id             := NULL;
      l_install_location_id     := NULL;
      l_business_process_id     := NULL;
      l_incident_status_flag    := NULL;
      -- 28/05/2012 Dalit A. Raviv
      l_incident_status_id := NULL;
      -- 17/06/2012 Dalit A. Raviv
      l_party_dist_id := NULL;
      l_party_id_temp := NULL;
      --
    
      -- Check sr vs.contact vs.customer validity and get operating unit
    
      -- Check if customer from contact relationship match file customer
      l_party_id                := cur_fsr_request.customer_party_id;
      l_contact_relationship_id := cur_fsr_request.owner_party_id;
      l_cs_region               := cur_fsr_request.cs_region;
    
      IF l_party_id IS NULL OR l_contact_relationship_id IS NULL THEN
        -- l_err_msg := 'Party details are missing.';
        -- 1.5  22/01/2012  Dalit A. Raviv
        -- Party details are missing.
        fnd_message.set_name('XXOBJT', 'XXCS_FSR_PROCESS_MSG1');
        l_err_msg := fnd_message.get;
        RAISE invalid_request;
      END IF;
    
      -- Check if serial exists
      IF cur_fsr_request.serial_number IS NULL THEN
        -- l_err_msg := 'Serial number is missing';
        -- 1.5  22/01/2012  Dalit A. Raviv
        -- Serial number is missing
        fnd_message.set_name('XXOBJT', 'XXCS_FSR_PROCESS_MSG2');
        l_err_msg := fnd_message.get;
        RAISE invalid_request;
      END IF;
    
      -- 30/01/2011 Dalit A. Raviv validation FRS date
      IF trunc(cur_fsr_request.incident_date) > trunc(SYSDATE) THEN
        -- l_err_msg := 'Incident date can not be grater then current date';
        -- 1.5  22/01/2012  Dalit A. Raviv
        -- Incident Date provided in eFSR is incorrect. Please verify the correct incident date
        fnd_message.set_name('XXOBJT', 'XXCS_FSR_PROCESS_MSG3');
        l_err_msg := fnd_message.get;
        RAISE invalid_request;
      END IF;
    
      BEGIN
        -- 1.1  09/01/2011  Dalit A. Raviv
        -- change logic of serial number. it use to be uniqe number
        -- now serial number can be none uniqe number but just one will be active.
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
           AND cii.inv_master_organization_id = mic.organization_id
           AND mic.category_set_id =
               xxinv_utils_pkg.get_default_category_set_id
           AND cii.serial_number = cur_fsr_request.serial_number
           AND cii.instance_status_id = cis.instance_status_id
           AND cis.terminated_flag = 'N';
      
        l_party_id_temp := NULL;
        -- Check if customer from serial match file customer
        IF l_party_id != l_owner_party_id THEN
          -- l_party_id come from the FSR
          -- l_owner_party_id come from IB
          -- 17/06/2012 Dalit A. Raviv
          -- Check Global account
          BEGIN
            -- check if the printer have secondary distributor for service
            SELECT tt.object_id party_id_distributer
              INTO l_party_dist_id
              FROM hz_relationships tt, hz_parties hp_son
             WHERE tt.object_table_name = 'HZ_PARTIES'
               AND tt.subject_id = l_owner_party_id -- 25441
               AND tt.object_id = hp_son.party_id
               AND tt.status = 'A'
               AND SYSDATE BETWEEN tt.start_date AND
                   nvl(tt.end_date, SYSDATE + 1)
               AND tt.relationship_code = 'MANAGED_BY_SEC_DISTRIBUTOR'
               AND tt.relationship_type = 'XX_DISTRIBUTOR_SEC';
          
            l_party_id_temp := l_owner_party_id;
          
          EXCEPTION
            WHEN OTHERS THEN
              l_party_dist_id := -999;
          END;
        
          IF l_party_id <> l_party_dist_id THEN
            BEGIN
              -- when did not found check if distributer is affilate(relate to)
              -- to other distributer  
              l_party_dist_id := NULL;
            
              SELECT tt.object_id party_id_distributer
                INTO l_party_dist_id
                FROM hz_relationships tt, hz_parties hp_son
               WHERE tt.object_table_name = 'HZ_PARTIES'
                 AND tt.subject_id = l_owner_party_id -- 4557041
                 AND tt.object_id = hp_son.party_id
                 AND tt.status = 'A'
                 AND SYSDATE BETWEEN tt.start_date AND
                     nvl(tt.end_date, SYSDATE + 1)
                 AND tt.relationship_code = 'AFFILIATE_TO'
                 AND tt.relationship_type = 'AFFILIATE';
            
              l_party_id_temp := l_owner_party_id;
            
            EXCEPTION
              WHEN OTHERS THEN
                l_party_dist_id := -999;
            END;
          
            IF l_party_id <> l_party_dist_id THEN
              -- Serial Number that provided in eFSR is not owned by the partner that submitted this eFSR.
              -- Please verify the owner of the IB
              fnd_message.set_name('XXOBJT', 'XXCS_FSR_PROCESS_MSG4');
              l_err_msg := fnd_message.get;
              RAISE invalid_request;
            END IF;
          END IF; -- l_party_id <>  l_party_dist_id (GA)         
        END IF; --l_party <> owner party
        -- end 17/06/2012
      EXCEPTION
        WHEN no_data_found THEN
          -- l_err_msg := 'validation failed for Customer/Serial';
          -- 1.5  22/01/2012  Dalit A. Raviv
          -- Serial Number that provided in eFSR is not owned by the partner that submitted this eFSR.
          -- Please verify the owner of the IB
          fnd_message.set_name('XXOBJT', 'XXCS_FSR_PROCESS_MSG5');
          l_err_msg := fnd_message.get;
          RAISE invalid_request;
      END;
    
      IF l_party_id_temp IS NOT NULL THEN
        l_party_id                := l_party_id_temp;
        l_contact_relationship_id := NULL;
      END IF;
    
      -- Get region data
      -- Updated the XXCS_CS_REGIONS value set, added there 2 DFFs in order to determine the Group_id and owner Resource_id for SR creation:
      BEGIN
        -- Dalit A. Raviv 21/07/2011
        SELECT ffv.attribute1 org_id,
               ffv.attribute2 group_id,
               ffv.attribute3 owner_resource_id
          INTO l_org_id, l_group_id, l_owner_resource_id
          FROM hz_parties hp, fnd_flex_values ffv, fnd_flex_value_sets ffvs
         WHERE ffvs.flex_value_set_name = 'XXCS_CS_REGIONS'
           AND ffv.flex_value_set_id = ffvs.flex_value_set_id
           AND hp.attribute3 = ffv.attribute1
           AND ffv.enabled_flag = 'Y'
           AND hp.party_id = l_party_id
           AND rownum = 1;
      
        -- Initialize record parameters
        -- 1.6 29/01/2012  Dalit A. Raviv  change place to the begining of the program
        --inv_globals.set_org_id(cur_fsr_request.org_id/*l_org_id*/);
        --fnd_global.apps_initialize(g_user_id,
        --                           fnd_profile.value_specific('XXCS_AUTO_DEBRIEF_RESPONSIBILITY',
        --                                                      NULL,
        --                                                      NULL,
        --                                                      NULL,
        --                                                      cur_fsr_request.org_id/*l_org_id*/),
        --                           514);
        --mo_global.init('QP');
      
      EXCEPTION
        WHEN OTHERS THEN
          -- l_err_msg := 'Region Query: ' || SQLERRM;
          -- 1.5  22/01/2012  Dalit A. Raviv
          -- System Error Region Query: ORA-01403: no data found. Please contact system administrator
          fnd_message.set_name('XXOBJT', 'XXCS_FSR_PROCESS_MSG6');
          l_err_msg := fnd_message.get;
          RAISE invalid_request;
      END;
      -- check if SR exists - if not and defined raise error or create?????
      IF cur_fsr_request.sr_number IS NOT NULL THEN
      
        BEGIN
        
          SELECT ci.incident_id,
                 ci.object_version_number,
                 ci.contract_id,
                 ci.contract_service_id,
                 ci.current_serial_number,
                 ci.customer_id,
                 ci.bill_to_party_id,
                 ci.bill_to_customer,
                 ci.bill_to_site_id,
                 ci.bill_to_site_use_id,
                 ci.ship_to_party_id,
                 ci.ship_to_customer,
                 ci.ship_to_site_id,
                 ci.ship_to_site_use_id,
                 ci.customer_product_id,
                 nvl(cis.close_flag, 'N'),
                 cit.business_process_id,
                 ci.incident_status_id -- 28/05/2012 Dalit A. Raviv
            INTO t_incident_rec.incident_id,
                 t_incident_rec.object_version_number,
                 t_incident_rec.contract_id,
                 t_incident_rec.contract_service_id,
                 t_incident_rec.current_serial_number,
                 t_incident_rec.customer_id,
                 t_incident_rec.bill_to_party_id,
                 t_incident_rec.bill_to_customer,
                 t_incident_rec.bill_to_site_id,
                 t_incident_rec.bill_to_site_use_id,
                 t_incident_rec.ship_to_party_id,
                 t_incident_rec.ship_to_customer,
                 t_incident_rec.ship_to_site_id,
                 t_incident_rec.ship_to_site_use_id,
                 t_incident_rec.customer_product_id,
                 l_incident_status_flag,
                 l_business_process_id,
                 l_incident_status_id -- 28/05/2012 Dalit A. Raviv
            FROM cs_incidents_all_b     ci,
                 cs_incident_statuses_b cis,
                 cs_incident_types_b    cit
           WHERE ci.incident_status_id = cis.incident_status_id
             AND ci.incident_type_id = cit.incident_type_id
             AND ci.incident_number = TRIM(cur_fsr_request.sr_number);
        
        EXCEPTION
          WHEN OTHERS THEN
            -- 1.4  29/05/2011  Dalit A. raviv   change out message - Incorrect SR Number Provided
            -- l_err_msg := 'Service Request Query: ' || SQLERRM;
            -- 1.5  22/01/2012  Dalit A. Raviv
            -- l_err_msg := 'Incorrect SR Number Provided: '|| SQLERRM;--
            -- Objet’s SR Number that provided in eFSR is invalid. Please verify the correct SR number
            fnd_message.set_name('XXOBJT', 'XXCS_FSR_PROCESS_MSG7');
            l_err_msg := fnd_message.get;
            RAISE invalid_request;
        END;
      
        IF l_incident_status_flag = 'Y' THEN
          -- l_err_msg := 'Service Request already closed';
          -- 1.5  22/01/2012  Dalit A. Raviv
          -- Objet’s SR number that provided in eFSR is closed. Please reopen this SR for update by eFSR
          fnd_message.set_name('XXOBJT', 'XXCS_FSR_PROCESS_MSG8');
          l_err_msg := fnd_message.get;
          RAISE invalid_request;
        ELSIF t_incident_rec.current_serial_number !=
              cur_fsr_request.serial_number THEN
          -- l_err_msg := 'Validation failed for Request/Serial';
          -- 1.5  22/01/2012  Dalit A. Raviv
          -- Validation failed for Request/Serial
          fnd_message.set_name('XXOBJT', 'XXCS_FSR_PROCESS_MSG9');
          l_err_msg := fnd_message.get;
          RAISE invalid_request;
        END IF;
      
        -- if sr exists update sr and create notes
        update_fsr_request(p_fsr_id                => p_fsr_id,
                           p_registration_code     => p_registration_code,
                           p_incident_id           => t_incident_rec.incident_id,
                           p_object_version_number => t_incident_rec.object_version_number,
                           --p_org_id                => l_org_id,
                           x_return_status => x_return_status,
                           x_err_msg       => l_err_msg);
      
        IF x_return_status != fnd_api.g_ret_sts_success THEN
          RAISE invalid_request;
        END IF;
      
        -- 1.7  28/05/2012  Dalit A. Raviv
        -- if it is Wait FSR we need to change it to Fsr Closed
        IF l_incident_status_id =
           fnd_profile.value('XXCS_SR_STATUS_WAIT_FSR') THEN
          l_err_msg := NULL;
          update_incident_status(p_incident_id        => t_incident_rec.incident_id,
                                 p_incident_status_id => fnd_profile.value('XXCS_SR_STATUS_FSR_CLOSED'),
                                 x_return_status      => x_return_status,
                                 x_err_msg            => l_err_msg);
        END IF;
      
      ELSE
      
        -- if not create sr and notes
        create_fsr_request(p_fsr_id            => p_fsr_id,
                           p_registration_code => p_registration_code,
                           p_incident_date     => cur_fsr_request.incident_date,
                           p_incident_type     => cur_fsr_request.sr_type,
                           p_problem_meaning   => cur_fsr_request.problem_code,
                           p_serial_number     => cur_fsr_request.serial_number,
                           --p_machine_run_time      => cur_fsr_request.machine_run_time,
                           --p_machine_part          => cur_fsr_request.machine_part,
                           p_studio_version        => cur_fsr_request.studio_version,
                           p_printer_version       => cur_fsr_request.printer_version,
                           p_resolution_meaning    => cur_fsr_request.resolution_code,
                           p_sub_resolution_1      => cur_fsr_request.sub_resolution_1,
                           p_sub_resolution_2      => cur_fsr_request.sub_resolution_2,
                           p_sub_resolution_3      => cur_fsr_request.sub_resolution_3,
                           p_party_id              => l_party_id,
                           p_relationship_party_id => l_contact_relationship_id,
                           p_group_id              => l_group_id,
                           p_owner_resource_id     => l_owner_resource_id,
                           p_inventory_item_id     => l_inventory_item_id,
                           p_item_rev              => l_item_rev,
                           p_organization_id       => l_organization_id,
                           p_location_type_code    => l_location_type_code,
                           p_location_id           => l_location_id,
                           p_customer_id           => l_customer_id,
                           p_instance_id           => l_instance_id,
                           --p_instance_number       => l_instance_number,
                           p_system_id           => l_system_id,
                           p_category_id         => l_category_id,
                           p_install_location_id => l_install_location_id,
                           p_org_id              => l_org_id,
                           p_cs_region           => l_cs_region,
                           x_incident_rec        => t_incident_rec,
                           x_business_process_id => l_business_process_id,
                           x_return_status       => x_return_status,
                           x_err_msg             => l_err_msg);
      
        IF x_return_status != fnd_api.g_ret_sts_success THEN
          RAISE invalid_request;
        END IF;
      
      END IF;
    
      -- create counter reading
      IF nvl(cur_fsr_request.machine_run_time, 0) > 0 THEN
      
        capture_counter_reading(p_instance_id   => l_instance_id,
                                p_reading_value => cur_fsr_request.machine_run_time,
                                x_return_status => x_return_status,
                                x_err_msg       => l_err_msg);
      
      END IF;
    
      -- create charges
      create_fsr_charges(p_fsr_id              => p_fsr_id,
                         p_registration_code   => p_registration_code,
                         p_incident_rec        => t_incident_rec,
                         p_business_process_id => l_business_process_id,
                         p_org_id              => l_org_id,
                         x_return_status       => x_return_status,
                         x_err_msg             => l_err_msg);
    
      IF x_return_status != fnd_api.g_ret_sts_success THEN
        RAISE invalid_request;
      END IF;
      --  error Handling
    EXCEPTION
      WHEN invalid_request THEN
      
        x_return_status := fnd_api.g_ret_sts_error;
        ROLLBACK;
      
      WHEN OTHERS THEN
      
        x_return_status := fnd_api.g_ret_sts_unexp_error;
        -- l_err_msg       := 'General error: ' || SQLERRM;
        -- 1.5  22/01/2012  Dalit A. Raviv
        -- General error: &SQLERRM
        fnd_message.set_name('XXOBJT', 'XXCS_FSR_PROCESS_MSG10');
        fnd_message.set_token('SQLERRM', substr(SQLERRM, 1, 200));
        l_err_msg := fnd_message.get;
        x_err_msg := l_err_msg;
        ROLLBACK;
      
    END;
  
    --
    UPDATE xxobjt_fsr_header t
       SET t.record_status    = x_return_status,
           t.error_message    = t.error_message || ' ' || l_err_msg,
           t.incident_id      = t_incident_rec.incident_id,
           t.last_update_date = SYSDATE -- 1.6 29/01/2012  Dalit A. Raviv
     WHERE t.fsr_id = cur_fsr_request.fsr_id
       AND t.registration_code = cur_fsr_request.registration_code;
  
    COMMIT;
    -- load attachments
    xxcs_fsr_interface_pkg.process_attachments(errbuf    => l_errbuf,
                                               retcode   => l_retcode,
                                               p_bpel_id => cur_fsr_request.bpel_instance_id);
  
    -- update fsr tables
    IF l_retcode = 2 THEN
      UPDATE xxobjt_fsr_header t
         SET t.error_message    = t.error_message || ' ' || l_errbuf,
             t.last_update_date = SYSDATE -- 1.6 29/01/2012  Dalit A. Raviv
       WHERE t.fsr_id = cur_fsr_request.fsr_id
         AND t.registration_code = cur_fsr_request.registration_code;
    END IF;
  
  END process_fsr_request;

  --------------------------------------------------------------------
  --  name:            process_fsr_interface
  --  create by:       Ella Malchi
  --  Revision:        1.0
  --  creation date:   xx/xx/2010
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  xx/xx/2010  Ella Malchi     initial build
  --  1.1  15/05/2011  Dalit A. Raviv  add condition to upd population
  --------------------------------------------------------------------
  PROCEDURE process_fsr_interface(p_request_status IN VARCHAR2,
                                  p_fsr_file_name  IN VARCHAR2 DEFAULT NULL,
                                  x_return_status  IN OUT VARCHAR2,
                                  x_err_msg        IN OUT VARCHAR2) IS
  
    t_fsr_id_tbl            t_number_type;
    t_registration_code_tbl t_number_type;
  
  BEGIN
    /*** Change FSR status to In Process ***/
    UPDATE xxobjt_fsr_header
       SET record_status = 'P'
     WHERE record_status = p_request_status
       AND nvl(fsr_file_name, 'file') =
           nvl(p_fsr_file_name, nvl(fsr_file_name, 'file'))
       AND incident_id IS NULL -- 1.1  15/05/2011  Dalit A. Raviv
    RETURNING fsr_id, registration_code BULK COLLECT INTO t_fsr_id_tbl, t_registration_code_tbl;
  
    COMMIT;
  
    FOR i IN 1 .. t_fsr_id_tbl.count LOOP
    
      process_fsr_request(t_fsr_id_tbl(i),
                          t_registration_code_tbl(i),
                          x_return_status,
                          x_err_msg);
    END LOOP;
  
  END process_fsr_interface;

  --------------------------------------------------------------------
  --  name:            process_fsr_interface_conc
  --  create by:       Ella Malchi
  --  Revision:        1.0
  --  creation date:   xx/xx/2010
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  xx/xx/2010  Ella Malchi     initial build
  --------------------------------------------------------------------
  PROCEDURE process_fsr_interface_conc(errbuf           OUT VARCHAR2,
                                       retcode          OUT VARCHAR2,
                                       p_request_status IN VARCHAR2) IS
  
    l_return_status VARCHAR2(1);
  
  BEGIN
  
    process_fsr_interface(p_request_status => p_request_status,
                          p_fsr_file_name  => NULL,
                          x_return_status  => l_return_status,
                          x_err_msg        => errbuf);
  
    IF l_return_status != fnd_api.g_ret_sts_success THEN
      retcode := 1;
    END IF;
  
  END process_fsr_interface_conc;

  --------------------------------------------------------------------
  --  name:            update_addnl_params
  --  create by:       Ella Malchi
  --  Revision:        1.0
  --  creation date:   xx/xx/2010
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  xx/xx/2010  Ella Malchi     initial build
  --  1.1  15/05/2011  Dalit A. Raviv  change source of select for update
  --  1.2  21/07/2011  Dalit A. Raviv  Change select
  --  1.3  04/09/2011  Dalit A. Raviv  create trigger XXOBJT_FSR_HEADER_BIR_TRG1
  --                                   no need for this procedure any more
  --------------------------------------------------------------------
  PROCEDURE update_addnl_params(p_bpel_instance_id IN NUMBER) IS
  
  BEGIN
    NULL;
    /*
    UPDATE xxobjt_fsr_header t
       SET (org_id, customer_party_id, owner_party_id, cs_region) = (select hps.attribute3, -- org id
                                                                            hps.party_id, -- customer party id
                                                                            r.party_id, -- contact relationship party id
                                                                            cii.attribute8 -- cs_region
                                                                     from   hz_parties            hp,
                                                                            hz_relationships      r,
                                                                            hz_parties            hpo,
                                                                            hz_parties            hps,
                                                                            csi_item_instances    cii
                                                                     where  hp.party_number       = t.registration_code
                                                                     and    hp.party_id           = r.party_id
                                                                     and    r.object_type         = 'PERSON'
                                                                     and    r.object_table_name   = 'HZ_PARTIES'
                                                                     and    r.object_id           = hpo.party_id
                                                                     and    r.subject_id          = hps.party_id
                                                                     and    cii.owner_party_id(+) = hps.party_id
                                                                     and    cii.serial_number(+) = t.serial_number
                                                                     AND    rownum = 1
                                                                    )
    
    WHERE  t.bpel_instance_id = p_bpel_instance_id;
    
    COMMIT;
    */
  END update_addnl_params;

  --------------------------------------------------------------------
  --  name:            update_addnl_params_conc
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   15/05/2011
  --------------------------------------------------------------------
  --  purpose :        Concurrent that will give the ability to
  --                   update additional params at table
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  15/05/2011  Dalit A. Raviv  initial build
  --  1.1  27/11/2011  Dalit A. raviv  change all logic
  --  1.2  28/11/2011  Dalit A. Raviv  add parameter org id
  --  1.3  10/01/2012  Dalit A. RAviv  add field to update (error_message = null) update_addnl_params_conc
  --------------------------------------------------------------------
  PROCEDURE update_addnl_params_conc(errbuf             OUT VARCHAR2,
                                     retcode            OUT NUMBER,
                                     p_bpel_instance_id IN NUMBER,
                                     p_org_id           IN NUMBER) IS
  
    CURSOR get_pop_c IS
      SELECT *
        FROM xxobjt_fsr_header h
       WHERE h.record_status = 'E'
         AND h.creation_date > SYSDATE - 90
         AND h.incident_id IS NULL
         AND h.org_id IS NULL
            --and    h.error_message   like 'Trigger - Could not find additional data - ORA-01403: no data found Party details are missing%'
         AND (h.bpel_instance_id = p_bpel_instance_id OR
             p_bpel_instance_id IS NULL)
      --and    rownum            < 11
       ORDER BY h.error_message;
  
    l_org_id            NUMBER;
    l_customer_party_id NUMBER;
    l_cont_rel_party_id NUMBER;
    l_cs_region         VARCHAR2(150);
  BEGIN
    errbuf  := NULL;
    retcode := 0;
    --xxcs_fsr_interface_pkg.update_addnl_params(p_bpel_instance_id);
    FOR get_pop_r IN get_pop_c LOOP
      l_org_id            := NULL;
      l_customer_party_id := NULL;
      l_cont_rel_party_id := NULL;
      l_cs_region         := NULL;
      BEGIN
        SELECT hps.attribute3, -- org id
               hps.party_id, -- customer party id
               r.party_id, -- contact relationship party id
               cii.attribute8 -- cs_region
          INTO l_org_id,
               l_customer_party_id,
               l_cont_rel_party_id,
               l_cs_region
          FROM hz_parties         hp,
               hz_relationships   r,
               hz_parties         hpo,
               hz_parties         hps,
               csi_item_instances cii
         WHERE hp.party_number = get_pop_r.registration_code /*:NEW.registration_code*/ --t.registration_code
           AND hp.party_id = r.party_id
           AND r.object_type = 'PERSON'
           AND r.object_table_name = 'HZ_PARTIES'
           AND r.object_id = hpo.party_id
           AND r.subject_id = hps.party_id
           AND cii.owner_party_id(+) = hps.party_id
           AND cii.serial_number(+) = get_pop_r.serial_number /*:NEW.serial_number*/ --t.serial_number
           AND rownum = 1;
      
        IF p_org_id = l_org_id THEN
          UPDATE xxobjt_fsr_header t
             SET org_id            = l_org_id,
                 customer_party_id = l_customer_party_id,
                 owner_party_id    = l_cont_rel_party_id,
                 cs_region         = l_cs_region,
                 record_status     = 'N',
                 error_message     = NULL,
                 last_update_date  = SYSDATE
           WHERE t.fsr_id = get_pop_r.fsr_id
             AND t.registration_code = get_pop_r.registration_code
             AND t.serial_number = get_pop_r.serial_number;
        
          COMMIT;
          dbms_output.put_line('---');
          dbms_output.put_line('S - fsr id   - ' || get_pop_r.fsr_id || '|');
          dbms_output.put_line('S - reg code - ' ||
                               get_pop_r.registration_code || '|');
          dbms_output.put_line('S - ser num  - ' ||
                               get_pop_r.serial_number || '|');
          fnd_file.put_line(fnd_file.log, '---');
          fnd_file.put_line(fnd_file.log,
                            'S - fsr id   - ' || get_pop_r.fsr_id || '|');
          fnd_file.put_line(fnd_file.log,
                            'S - reg code - ' ||
                            get_pop_r.registration_code || '|');
          fnd_file.put_line(fnd_file.log,
                            'S - ser num  - ' || get_pop_r.serial_number || '|');
        END IF;
      EXCEPTION
        WHEN OTHERS THEN
          ROLLBACK;
          dbms_output.put_line('---');
          dbms_output.put_line('E - fsr id   - ' || get_pop_r.fsr_id || '|');
          dbms_output.put_line('E - reg code - ' ||
                               get_pop_r.registration_code || '|');
          dbms_output.put_line('E - ser num  - ' ||
                               get_pop_r.serial_number || '|');
          fnd_file.put_line(fnd_file.log, '---');
          fnd_file.put_line(fnd_file.log,
                            'E - fsr id   - ' || get_pop_r.fsr_id || '|');
          fnd_file.put_line(fnd_file.log,
                            'E - reg code - ' ||
                            get_pop_r.registration_code || '|');
          fnd_file.put_line(fnd_file.log,
                            'E - ser num  - ' || get_pop_r.serial_number || '|');
      END;
    END LOOP;
  
  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'GEN EXC - update_addnl_params_conc ' ||
                 substr(SQLERRM, 1, 240);
      retcode := 1;
  END update_addnl_params_conc;

  --------------------------------------------------------------------
  --  name:            initiate_process
  --  create by:       Ella Malchi
  --  Revision:        1.0
  --  creation date:   xx/xx/2010
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  xx/xx/2010  Ella Malchi     initial build
  --------------------------------------------------------------------
  PROCEDURE initiate_process(errbuf OUT VARCHAR2, retcode OUT NUMBER) IS
  
    v_in_process        VARCHAR2(1) := 'N';
    service_            sys.utl_dbws.service;
    call_               sys.utl_dbws.call;
    service_qname       sys.utl_dbws.qname;
    response            sys.xmltype;
    request             sys.xmltype;
    v_string_type_qname sys.utl_dbws.qname;
    v_error             VARCHAR2(1000);
  
  BEGIN
  
    -- check for running or stack processes
    BEGIN
    
      SELECT DISTINCT 'Y'
        INTO v_in_process
        FROM xxobjt_fsr_header
       WHERE record_status = 'P'
         AND rownum < 2;
    
      retcode := 1;
      errbuf  := 'There are transactions in process, terminating program';
      RETURN;
    
    EXCEPTION
      WHEN no_data_found THEN
        NULL;
        --v_in_process := 'N';
      WHEN too_many_rows THEN
        retcode := 1;
        errbuf  := 'There are transactions in process, terminating program';
        RETURN;
    END;
  
    --call bpel process xxfsrCallScript
    BEGIN
      service_qname := sys.utl_dbws.to_qname('http://xmlns.oracle.com/xxfsrCallScript',
                                             'xxfsrCallScript');
    
      v_string_type_qname := sys.utl_dbws.to_qname('http://www.w3.org/2001/XMLSchema',
                                                   'string');
      service_            := sys.utl_dbws.create_service(service_qname);
      call_               := sys.utl_dbws.create_call(service_);
      sys.utl_dbws.set_target_endpoint_address(call_,
                                               'http://soaprodapps.2objet.com:7777/orabpel/' ||
                                               xxagile_util_pkg.get_bpel_domain ||
                                               '/xxfsrCallScript/1.0');
    
      sys.utl_dbws.set_property(call_, 'SOAPACTION_USE', 'TRUE');
      sys.utl_dbws.set_property(call_, 'SOAPACTION_URI', 'process');
      sys.utl_dbws.set_property(call_, 'OPERATION_STYLE', 'document');
      sys.utl_dbws.set_property(call_,
                                'ENCODINGSTYLE_URI',
                                'http://schemas.xmlsoap.org/soap/encoding/');
    
      sys.utl_dbws.set_return_type(call_, v_string_type_qname);
    
      -- Set the input
    
      request := sys.xmltype('<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' ||
                             '    <soap:Body xmlns:ns1="http://xmlns.oracle.com/xxfsrCallScript">' ||
                             '        <ns1:xxfsrCallScriptProcessRequest>' ||
                             '            <ns1:input></ns1:input>' ||
                             '        </ns1:xxfsrCallScriptProcessRequest>' ||
                             '    </soap:Body>' || '</soap:Envelope>');
    
      response := sys.utl_dbws.invoke(call_, request);
      sys.utl_dbws.release_call(call_);
      sys.utl_dbws.release_service(service_);
      v_error := response.getstringval();
      IF response.getstringval() LIKE '%Error%' THEN
        retcode := 2;
        errbuf  := REPLACE(REPLACE(substr(v_error,
                                          instr(v_error, 'instance') + 10,
                                          length(v_error)),
                                   '</OutPut>',
                                   NULL),
                           '</processResponse>',
                           NULL);
      END IF;
      --dbms_output.put_line(response.getstringval());
    EXCEPTION
      WHEN OTHERS THEN
        v_error := substr(SQLERRM, 1, 250);
        retcode := '2';
        errbuf  := 'Error Run Bpel Process - xxfsrCallScript: ' || v_error;
        sys.utl_dbws.release_call(call_);
        sys.utl_dbws.release_service(service_);
    END;
  
  END initiate_process;

  --------------------------------------------------------------------
  --  name:            process_attachments
  --  create by:       Yuval Tal
  --  Revision:        1.0
  --  creation date:   10/01/2011
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name          desc
  --  1.0  10/01/2011  Yuval Tal     initial build
  --------------------------------------------------------------------
  PROCEDURE process_attachments(errbuf    OUT VARCHAR2,
                                retcode   OUT NUMBER,
                                p_bpel_id NUMBER DEFAULT NULL) IS
    l_resultout VARCHAR2(100);
    l_file_dir  VARCHAR2(180);
    l_domain    VARCHAR2(100);
    CURSOR c IS
      SELECT t.fsr_id, t.registration_code, t.file_name, h.incident_id
        FROM xxobjt_fsr_attachments t, xxobjt_fsr_header h
       WHERE h.fsr_id = t.fsr_id
         AND h.registration_code = t.registration_code
         AND t.status IN ('E', 'N')
         AND h.bpel_instance_id = nvl(p_bpel_id, h.bpel_instance_id);
    l_ora_dir VARCHAR2(50);
  BEGIN
  
    l_domain := xxagile_util_pkg.get_bpel_domain;
  
    -- get atta dir
    IF l_domain = 'production' THEN
      l_file_dir := fnd_profile.value('XXCS_FSR_ATTACHMENT_DIR');
    ELSE
      l_file_dir := fnd_profile.value('XXCS_FSR_ATTACHMENT_DIR_TEST');
    
    END IF;
  
    BEGIN
    
      SELECT directory_name
        INTO l_ora_dir
        FROM all_directories
       WHERE directory_path = l_file_dir;
    
    EXCEPTION
      WHEN no_data_found THEN
      
        EXECUTE IMMEDIATE 'CREATE OR REPLACE DIRECTORY XXCS_FSR_ATTACHMENT_DIR AS ''' ||
                          l_file_dir || '''';
    END;
  
    retcode := 0;
    -- errbuf  := 'Success uploaded';
    FOR i IN c LOOP
      BEGIN
      
        IF i.incident_id IS NULL THEN
        
          UPDATE xxobjt_fsr_attachments t
             SET t.status           = 'E',
                 t.note             = 'incident_id is null',
                 t.last_updated_by  = fnd_global.user_id,
                 t.last_update_date = SYSDATE
           WHERE t.fsr_id = i.fsr_id
             AND t.registration_code = i.registration_code;
        
          COMMIT;
          retcode := '2';
          errbuf  := 'fsr_id=' || i.fsr_id || ' ' || 'registration_code=' ||
                     i.registration_code || ' ' || 'incident_id is null';
        ELSE
          -- dbms_output.put_line('FILE=' || l_file_dir || '/' || i.file_name);
        
          xxcs_attach_doc_pkg.objet_store_pdf(p_entity_name       => 'CS_INCIDENTS',
                                              p_pk1               => i.incident_id,
                                              p_pk2               => NULL,
                                              p_pk3               => NULL,
                                              p_pk4               => NULL,
                                              p_pk5               => NULL,
                                              p_conc_req_id       => NULL,
                                              p_doc_categ         => 1000625,
                                              p_file_name         => l_file_dir || '/' ||
                                                                     i.file_name,
                                              resultout           => l_resultout,
                                              p_file_content_type => 'application/x-zip-compressed');
        
          IF l_resultout = 'COMPLETE:Y' THEN
            UPDATE xxobjt_fsr_attachments t
               SET t.status           = 'S',
                   t.note             = NULL,
                   t.last_updated_by  = fnd_global.user_id,
                   t.last_update_date = SYSDATE
             WHERE t.fsr_id = i.fsr_id
               AND t.registration_code = i.registration_code;
            COMMIT;
          
            -- delete file
          
            utl_file.fremove(location => 'XXCS_FSR_ATTACHMENT_DIR',
                             filename => i.file_name);
          ELSE
          
            errbuf := 'fsr_id=' || i.fsr_id || ' ' || 'registration_code=' ||
                      i.registration_code || ' ' || l_resultout;
          
            UPDATE xxobjt_fsr_attachments t
               SET t.status           = 'E',
                   t.note             = errbuf,
                   t.last_updated_by  = fnd_global.user_id,
                   t.last_update_date = SYSDATE
             WHERE t.fsr_id = i.fsr_id
               AND t.registration_code = i.registration_code;
            retcode := '2';
          END IF;
        END IF;
      
      EXCEPTION
        WHEN OTHERS THEN
          ROLLBACK;
      END;
      COMMIT;
    END LOOP;
  
  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := substr(SQLERRM, 1, 250);
      retcode := '2';
    
  END process_attachments;

  --------------------------------------------------------------------
  --  name:            update_incident_status
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   28/05/2012
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  28/05/2012  Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  PROCEDURE update_incident_status(p_incident_id        IN NUMBER,
                                   p_incident_status_id IN NUMBER,
                                   x_return_status      OUT VARCHAR2,
                                   x_err_msg            OUT VARCHAR2) IS
  
    l_return_status VARCHAR2(100) := NULL;
    l_msg_count     NUMBER := NULL;
    l_msg_data      VARCHAR2(2500) := NULL;
    --x_err_msg            varchar2(2500) := null;
    l_ovn            NUMBER := NULL;
    l_interaction_id NUMBER := NULL;
    l_msg_index_out  NUMBER := NULL;
  BEGIN
    x_return_status := 'S';
    x_err_msg       := NULL;
  
    SELECT cii.object_version_number
      INTO l_ovn
      FROM cs_incidents_all_b cii
     WHERE cii.incident_id = p_incident_id;
  
    cs_servicerequest_pub.update_status(p_api_version           => 2.0,
                                        p_init_msg_list         => fnd_api.g_true,
                                        p_commit                => fnd_api.g_false,
                                        x_return_status         => l_return_status,
                                        x_msg_count             => l_msg_count,
                                        x_msg_data              => l_msg_data,
                                        p_request_id            => p_incident_id, --54432,
                                        p_object_version_number => l_ovn,
                                        p_status_id             => p_incident_status_id,
                                        p_closed_date           => SYSDATE,
                                        --p_validate_sr_closure => 'N',
                                        --p_resp_appl_id   => 514,
                                        --p_resp_id        => 51137,
                                        --p_user_id        => g_user_id,
                                        x_interaction_id => l_interaction_id);
  
    x_return_status := 'S';
    IF l_return_status != fnd_api.g_ret_sts_success THEN
      IF (fnd_msg_pub.count_msg > 0) THEN
        FOR i IN 1 .. fnd_msg_pub.count_msg LOOP
          fnd_msg_pub.get(p_msg_index     => i,
                          p_encoded       => 'F',
                          p_data          => l_msg_data,
                          p_msg_index_out => l_msg_index_out);
          x_err_msg := x_err_msg || l_msg_data || chr(10);
        END LOOP;
      ELSE
        x_err_msg := l_msg_data;
      END IF;
      --dbms_output.put_line('x_err_msg - '||x_err_msg);     
    END IF;
  
  END update_incident_status;

BEGIN

  /*** Initialize parameters  ***/
  g_user_id := fnd_profile.value('XXCS_FSR_USER');

END xxcs_fsr_interface_pkg;
/
