CREATE OR REPLACE PACKAGE BODY xxconv_il_purchasing_pkg IS

  g_user_id fnd_user.user_id%TYPE;
  -------------------------------------------------------------------
  PROCEDURE message(p_message VARCHAR2) IS
  
  BEGIN
    -----dbms_output.put_line(p_message);
    fnd_file.put_line(fnd_file.log, '========= ' || p_message);
  EXCEPTION
    WHEN OTHERS THEN
      NULL;
  END message;
  -------------------------------------------------------------------

  PROCEDURE load_quotations(errbuf OUT VARCHAR2, retcode OUT VARCHAR2) IS
  
    CURSOR csr_quotation_headers IS
      SELECT DISTINCT cpq.quotation_num,
                      cpq.supplier_name,
                      cpq.supplier_site,
                      cpq.status,
                      cpq.buyer,
                      cpq.rfq,
                      cpq.currency,
                      cpq.operating_unit
        FROM xxobjt_conv_po_quotations cpq
       WHERE cpq.int_status = 'N'
       ORDER BY quotation_num;
  
    CURSOR csr_quotation_lines(p_quotation_header VARCHAR2) IS
      SELECT DISTINCT cpq.quotation_num, cpq.operating_unit, cpq.item
        FROM xxobjt_conv_po_quotations cpq
       WHERE cpq.int_status = 'N'
         AND quotation_num = p_quotation_header
       ORDER BY quotation_num, item;
  
    CURSOR csr_quot_price_breaks(p_quotation_header VARCHAR2,
                                 p_item             VARCHAR2) IS
      SELECT *
        FROM xxobjt_conv_po_quotations cpq
       WHERE cpq.int_status = 'N'
         AND quotation_num = p_quotation_header
         AND cpq.item = p_item
       ORDER BY quotation_num, item, price_break_quantity, price DESC;
  
    cur_quotation_header csr_quotation_headers%ROWTYPE;
    cur_quotation_line   csr_quotation_lines%ROWTYPE;
    cur_quot_price_break csr_quot_price_breaks%ROWTYPE;
    l_rate               NUMBER;
  
    invalid_quotation EXCEPTION;
    l_error_msg VARCHAR2(250);
  
    l_org_id                  NUMBER;
    l_supplier_id             NUMBER;
    l_supplier_site_id        NUMBER;
    l_status                  VARCHAR2(5);
    l_buyer_id                NUMBER;
    l_rfq_id                  NUMBER;
    l_quotation_id            NUMBER;
    l_inventory_item_id       NUMBER;
    l_line_num                NUMBER;
    l_line_id                 NUMBER;
    l_uom_code                VARCHAR2(3);
    l_unit_of_measure         mtl_system_items_b.primary_unit_of_measure%TYPE;
    l_price_break_num         NUMBER;
    l_bill_to_location_id     NUMBER;
    l_ship_to_location_id     NUMBER;
    l_ship_to_organization_id NUMBER;
    l_supplier_item           VARCHAR2(50);
    l_quantity                NUMBER;
    l_price                   NUMBER;
    l_mfg_part_number         VARCHAR2(50);
    l_effective_date          DATE;
    l_header_counter          NUMBER := 0;
  
  BEGIN
    errbuf  := NULL;
    retcode := 0;
    FOR cur_quotation_header IN csr_quotation_headers LOOP
    
      BEGIN
      
        l_header_counter := l_header_counter + 1;
        l_error_msg      := NULL;
        BEGIN
        
          SELECT organization_id
            INTO l_org_id
            FROM hr_operating_units ou
           WHERE ou.name = cur_quotation_header.operating_unit;
        
          mo_global.set_org_access(p_org_id_char     => l_org_id,
                                   p_sp_id_char      => NULL,
                                   p_appl_short_name => 'PO');
        
        EXCEPTION
          WHEN OTHERS THEN
            l_error_msg := 'Invalid Operating Unit, ' || SQLERRM;
            RAISE invalid_quotation;
          
        END;
      
        BEGIN
        
          SELECT s.vendor_id,
                 ss.vendor_site_id,
                 ss.bill_to_location_id,
                 ss.ship_to_location_id
            INTO l_supplier_id,
                 l_supplier_site_id,
                 l_bill_to_location_id,
                 l_ship_to_location_id
            FROM ap_suppliers s, ap_supplier_sites_all ss
           WHERE s.vendor_id = ss.vendor_id
             AND s.vendor_name = cur_quotation_header.supplier_name
             AND rownum < 2;
        
        EXCEPTION
          WHEN OTHERS THEN
            l_error_msg := 'Invalid Supplier, ' || SQLERRM;
            RAISE invalid_quotation;
          
        END;
      
        l_status := 'A';
      
        BEGIN
        
          SELECT p.person_id
            INTO l_buyer_id
            FROM per_all_people_f p
           WHERE full_name = cur_quotation_header.buyer
             AND p.current_employee_flag = 'Y'
             AND SYSDATE BETWEEN p.effective_start_date AND
                 p.effective_end_date;
        
        EXCEPTION
          WHEN OTHERS THEN
            l_error_msg := 'Invalid Buyer, ' || SQLERRM;
            RAISE invalid_quotation;
        END;
      
        BEGIN
        
          IF cur_quotation_header.rfq IS NOT NULL THEN
          
            SELECT po_header_id
              INTO l_rfq_id
              FROM po_headers_all h
             WHERE h.type_lookup_code = 'RFQ'
               AND segment1 = cur_quotation_header.rfq;
          
          ELSE
            l_rfq_id := NULL;
          END IF;
        
        EXCEPTION
          WHEN OTHERS THEN
            l_error_msg := 'Invalid RFQ, ' || SQLERRM;
            RAISE invalid_quotation;
          
        END;
      
        SELECT po_headers_interface_s.nextval
          INTO l_quotation_id
          FROM dual;
      
        INSERT INTO po_headers_interface
          (interface_header_id,
           action,
           batch_id,
           process_code,
           org_id,
           document_type_code,
           document_subtype,
           document_num,
           currency_code,
           rate,
           rate_date,
           rate_type,
           agent_id,
           vendor_id,
           vendor_site_id,
           from_header_id,
           from_type_lookup_code,
           from_rfq_num,
           quote_warning_delay,
           ship_to_location_id,
           bill_to_location_id,
           creation_date,
           created_by,
           last_update_date,
           last_updated_by,
           created_language,
           approval_required_flag)
        VALUES
          (l_quotation_id,
           'ORIGINAL',
           1,
           'PENDING',
           l_org_id,
           'QUOTATION', --'PO',
           'CATALOG', --'QUOTATION',
           cur_quotation_header.quotation_num,
           cur_quotation_header.currency,
           l_rate,
           decode(cur_quotation_header.currency, 'USD', NULL, SYSDATE - 1),
           decode(cur_quotation_header.currency, 'USD', NULL, 'Corporate'),
           l_buyer_id,
           l_supplier_id,
           l_supplier_site_id,
           l_rfq_id,
           decode(l_rfq_id, NULL, NULL, 'RFQ'),
           cur_quotation_header.rfq,
           0,
           l_ship_to_location_id,
           l_bill_to_location_id,
           SYSDATE - 1,
           g_user_id,
           SYSDATE - 1,
           g_user_id,
           'US',
           'N');
      
        l_line_num := 0;
      
        FOR cur_quotation_line IN csr_quotation_lines(cur_quotation_header.quotation_num) LOOP
        
          SELECT supplier_item,
                 mfg_part_number,
                 quantity,
                 price,
                 effective_date
            INTO l_supplier_item,
                 l_mfg_part_number,
                 l_quantity,
                 l_price,
                 l_effective_date
            FROM (SELECT t.supplier_item,
                         t.mfg_part_number,
                         t.price_break_quantity quantity,
                         t.price,
                         MIN(t.effective_date) effective_date
                    FROM xxobjt_conv_po_quotations t
                   WHERE t.quotation_num = cur_quotation_line.quotation_num
                     AND t.item = cur_quotation_line.item
                     AND t.price_break_quantity =
                         (SELECT MIN(price_break_quantity)
                            FROM xxobjt_conv_po_quotations t1
                           WHERE t1.quotation_num = t.quotation_num
                             AND t1.item = t.item)
                   GROUP BY t.supplier_item,
                            t.mfg_part_number,
                            t.price_break_quantity,
                            t.price)
           WHERE rownum < 2;
        
          BEGIN
            SELECT inventory_item_id,
                   primary_uom_code,
                   primary_unit_of_measure
              INTO l_inventory_item_id, l_uom_code, l_unit_of_measure
              FROM mtl_system_items_b
             WHERE segment1 = cur_quotation_line.item
               AND organization_id =
                   xxinv_utils_pkg.get_master_organization_id
               AND nvl(purchasing_enabled_flag, 'N') = 'Y';
          EXCEPTION
            WHEN OTHERS THEN
              l_error_msg := 'Invalid or non purchable Item, ' || SQLERRM;
              RAISE invalid_quotation;
            
          END;
        
          SELECT organization_id,
                 ---decode(organization_id, 90, 144, 92, 145, NULL)
                 decode(organization_id, 735, 144, 734, 145, NULL)
            INTO l_ship_to_organization_id, l_ship_to_location_id
            FROM (SELECT mp.organization_id
                    FROM mtl_system_items_b msi, mtl_parameters mp
                   WHERE msi.inventory_item_id = l_inventory_item_id
                     AND msi.organization_id = mp.organization_id
                     AND mp.organization_code IN ('IPK', 'IRK') ---('WRI', 'WPI')
                   ORDER BY organization_code DESC)
           WHERE rownum < 2;
        
          SELECT po_lines_interface_s.nextval INTO l_line_id FROM dual;
        
          l_line_num := l_line_num + 1;
        
          INSERT INTO po_lines_interface
            (interface_line_id,
             interface_header_id,
             action,
             process_code,
             line_num,
             shipment_num,
             line_type_id,
             item_id,
             uom_code,
             unit_of_measure,
             closed_code,
             price_break_flag,
             vendor_product_num,
             quantity,
             unit_price,
             ship_to_location_id,
             ship_to_organization_id,
             line_attribute1,
             creation_date,
             created_by,
             last_update_date,
             last_updated_by,
             effective_date)
          VALUES
            (l_line_id,
             l_quotation_id,
             'ADD',
             'PENDING',
             l_line_num,
             1,
             1,
             l_inventory_item_id,
             l_uom_code,
             l_unit_of_measure,
             'OPEN',
             'N',
             substr(l_supplier_item, 1, 25),
             l_quantity,
             l_price,
             l_ship_to_location_id,
             l_ship_to_organization_id,
             l_mfg_part_number,
             SYSDATE - 1,
             g_user_id,
             SYSDATE - 1,
             g_user_id,
             l_effective_date);
        
          l_price_break_num := 1;
        
          FOR cur_quot_price_break IN csr_quot_price_breaks(cur_quotation_header.quotation_num,
                                                            cur_quotation_line.item) LOOP
          
            IF cur_quot_price_break.price != l_price OR
               cur_quot_price_break.price_break_quantity != l_quantity OR
               cur_quot_price_break.effective_date != l_effective_date THEN
            
              SELECT po_lines_interface_s.nextval INTO l_line_id FROM dual;
            
              l_price_break_num := l_price_break_num + 1;
            
              INSERT INTO po_lines_interface
                (interface_line_id,
                 interface_header_id,
                 --action,
                 -- process_code,
                 line_num,
                 shipment_num,
                 price_break_lookup_code,
                 uom_code,
                 unit_of_measure,
                 quantity,
                 unit_price,
                 price_discount,
                 price_break_flag,
                 ship_to_location_id,
                 ship_to_organization_id,
                 closed_code,
                 creation_date,
                 created_by,
                 last_update_date,
                 last_updated_by,
                 effective_date)
              VALUES
                (l_line_id,
                 l_quotation_id,
                 --'ADD',
                 --'PENDING',
                 l_line_num,
                 l_price_break_num,
                 'QUOTATION',
                 l_uom_code,
                 l_unit_of_measure,
                 cur_quot_price_break.price_break_quantity,
                 cur_quot_price_break.price,
                 (1 - (cur_quot_price_break.price /
                 decode(l_price, NULL, 1, 0, 1, l_price))) * 100,
                 'Y',
                 l_ship_to_location_id,
                 l_ship_to_organization_id,
                 'OPEN',
                 SYSDATE - 1,
                 g_user_id,
                 SYSDATE - 1,
                 g_user_id,
                 cur_quot_price_break.effective_date);
            END IF;
          
          END LOOP;
        
        END LOOP;
      
        UPDATE xxobjt_conv_po_quotations
           SET int_status = 'S', int_message = NULL
         WHERE quotation_num = cur_quotation_header.quotation_num;
      
      EXCEPTION
        WHEN invalid_quotation THEN
          ROLLBACK;
          UPDATE xxobjt_conv_po_quotations
             SET int_status = 'E', int_message = l_error_msg
           WHERE quotation_num = cur_quotation_header.quotation_num;
        
        WHEN OTHERS THEN
          ROLLBACK;
          l_error_msg := SQLERRM;
          UPDATE xxobjt_conv_po_quotations
             SET int_status = 'E', int_message = l_error_msg
           WHERE quotation_num = cur_quotation_header.quotation_num;
      END;
      COMMIT;
    
      IF l_header_counter > 200 THEN
        EXIT;
      END IF;
    
    END LOOP;
  
  END load_quotations;
  --------------------------------------------------------------------
  --  customization code: CUST695
  --  name:               load_asl
  --  create by:          Vitaly K.
  --  $Revision:          1.0 $
  --  creation date:      30/10/2013
  --  Purpose :
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   30/10/2013    Vitaly K.       initial build CR921
  ----------------------------------------------------------------------
  PROCEDURE load_asl(errbuf OUT VARCHAR2, retcode OUT VARCHAR2) IS
  
    CURSOR csr_asl_records IS
      SELECT * FROM xxobjt_conv_asl t WHERE t.int_status = 'N';
  
    cur_asl csr_asl_records%ROWTYPE;
  
    l_asl_id                 NUMBER;
    l_using_organization_id  NUMBER;
    l_owning_organization_id NUMBER;
    l_inventory_item_id      NUMBER;
    l_unit_of_measure        VARCHAR2(50);
    l_purchasing_flag        VARCHAR2(1);
    l_osp_flag               VARCHAR2(1);
    l_record_unique          BOOLEAN;
    l_return_status          VARCHAR2(1);
    l_msg_count              NUMBER;
    l_msg_data               VARCHAR2(500);
    l_asl_status_id          NUMBER;
    l_vendor_id              NUMBER;
    l_vendor_site_id         NUMBER;
    l_error_msg              VARCHAR2(500);
    l_ship_to_location_id    NUMBER;
    invalid_asl EXCEPTION;
  
  BEGIN
    errbuf  := 'Success';
    retcode := '0';
  
    FOR cur_asl IN csr_asl_records LOOP
    
      BEGIN
      
        BEGIN
          SELECT inventory_item_id,
                 primary_unit_of_measure,
                 purchasing_enabled_flag,
                 outside_operation_flag
            INTO l_inventory_item_id,
                 l_unit_of_measure,
                 l_purchasing_flag,
                 l_osp_flag
            FROM mtl_system_items_b
           WHERE segment1 = cur_asl.item
             AND organization_id =
                 xxinv_utils_pkg.get_master_organization_id;
        
          IF cur_asl.to_organization_id IS NULL THEN
            l_error_msg := 'Missing To_Organization_Id';
            RAISE invalid_asl;
          ELSE
            -------
            BEGIN
              SELECT mp.organization_id, mp.organization_id
                INTO l_using_organization_id, l_owning_organization_id
                FROM mtl_parameters mp
               WHERE mp.organization_id = cur_asl.to_organization_id;
            EXCEPTION
              WHEN no_data_found THEN
                l_error_msg := 'Invalid To_Organization_Id=' ||
                               cur_asl.to_organization_id;
                RAISE invalid_asl;
            END;
            -------
          END IF;
        
          IF fnd_profile.save(x_name       => 'MGF_ORGANIZATION_ID',
                              x_value      => l_owning_organization_id,
                              x_level_name => 'SITE') THEN
            COMMIT;
          END IF;
        
        EXCEPTION
          WHEN no_data_found THEN
            l_error_msg := 'Invalid Item/Organization, ' || SQLERRM;
            RAISE invalid_asl;
          
        END;
      
        BEGIN
        
          SELECT s.vendor_id, ss.vendor_site_id, ss.ship_to_location_id
            INTO l_vendor_id, l_vendor_site_id, l_ship_to_location_id
            FROM ap_suppliers s, ap_supplier_sites_all ss
           WHERE s.vendor_id = ss.vendor_id
             AND s.vendor_name = cur_asl.supplier
             AND ss.vendor_site_code = cur_asl.supplier_site
             AND ss.org_id = cur_asl.org_id;
        
        EXCEPTION
          WHEN no_data_found THEN
            l_error_msg := 'Invalid Supplier/Supplier Site';
            RAISE invalid_asl;
          
        END;
      
        l_record_unique := po_asl_sv.check_record_unique(NULL,
                                                         l_vendor_id,
                                                         l_vendor_site_id,
                                                         l_inventory_item_id,
                                                         NULL,
                                                         l_owning_organization_id);
      
        --<LOCAL SR/ASL PROJECT 11i11 END>
        --
        IF NOT l_record_unique THEN
          l_error_msg := 'ASL Exists';
          RAISE invalid_asl;
        
        ELSIF l_purchasing_flag = 'N' THEN
          l_error_msg := 'Item NOT purchable';
          RAISE invalid_asl;
        END IF;
      
        l_asl_status_id := 2;
      
        SELECT po_approved_supplier_list_s.nextval INTO l_asl_id FROM dual;
      
        --
        INSERT INTO po_approved_supplier_list
          (asl_id,
           using_organization_id,
           owning_organization_id,
           vendor_business_type,
           asl_status_id,
           last_update_date,
           last_updated_by,
           creation_date,
           created_by,
           vendor_id,
           vendor_site_id,
           item_id,
           primary_vendor_item,
           last_update_login,
           request_id)
        VALUES
          (l_asl_id,
           l_using_organization_id, --<LOCAL SR/ASL PROJECT 11i11>
           l_owning_organization_id,
           'DIRECT',
           cur_asl.asl_status_id,
           SYSDATE - 1,
           g_user_id,
           SYSDATE - 1,
           g_user_id,
           l_vendor_id,
           l_vendor_site_id,
           l_inventory_item_id,
           cur_asl.primary_vendor_item,
           -1,
           NULL);
      
        -- <INBOUND LOGISTICS FPJ START>
        po_businessevent_pvt.raise_event(p_api_version   => 1.0,
                                         x_return_status => l_return_status,
                                         x_msg_count     => l_msg_count,
                                         x_msg_data      => l_msg_data,
                                         p_event_name    => 'oracle.apps.po.event.create_asl',
                                         p_entity_name   => 'ASL',
                                         p_entity_id     => l_asl_id);
      
        INSERT INTO po_asl_attributes
          (asl_id,
           using_organization_id,
           last_update_date,
           last_updated_by,
           creation_date,
           created_by,
           last_update_login,
           document_sourcing_method,
           release_generation_method,
           enable_plan_schedule_flag,
           enable_ship_schedule_flag,
           enable_autoschedule_flag,
           enable_authorizations_flag,
           vendor_id,
           vendor_site_id,
           purchasing_unit_of_measure,
           item_id)
        VALUES
          (l_asl_id,
           l_using_organization_id, --<LOCAL SR/ASL PROJECT 11i11>
           SYSDATE - 1,
           g_user_id,
           SYSDATE - 1,
           g_user_id,
           -1,
           'ASL',
           NULL,
           'N',
           'N',
           'N',
           'N',
           l_vendor_id,
           l_vendor_site_id,
           l_unit_of_measure,
           l_inventory_item_id);
        --
      
        -- <ASL ERECORD FPJ START>
        -- bug3236816: Move the code that raises eres event after
        --             PO ASL Attribute is created
      
        po_asl_sv.raise_asl_eres_event(x_return_status     => l_return_status,
                                       p_asl_id            => l_asl_id,
                                       p_action            => po_asl_sv.g_event_insert,
                                       p_calling_from      => 'PO_APPROVED_SUPPLIER_LIST_SV.create_po_asl_entries',
                                       p_ackn_note         => NULL,
                                       p_autonomous_commit => fnd_api.g_false);
      
        UPDATE xxobjt_conv_asl t
           SET int_status = 'S', err_message = NULL
         WHERE t.using_organization = cur_asl.using_organization
           AND t.supplier = cur_asl.supplier
           AND t.supplier_site = cur_asl.supplier_site
           AND t.from_organization_id = cur_asl.from_organization_id
           AND t.item = cur_asl.item;
      
      EXCEPTION
        WHEN invalid_asl THEN
          ROLLBACK;
          UPDATE xxobjt_conv_asl t
             SET int_status = 'E', err_message = l_error_msg
           WHERE t.using_organization = cur_asl.using_organization
             AND t.supplier = cur_asl.supplier
             AND t.supplier_site = cur_asl.supplier_site
             AND t.from_organization_id = cur_asl.from_organization_id
             AND t.item = cur_asl.item;
        
        WHEN OTHERS THEN
          ROLLBACK;
          l_error_msg := SQLERRM;
          UPDATE xxobjt_conv_asl t
             SET int_status = 'E', err_message = l_error_msg
           WHERE t.using_organization = cur_asl.using_organization
             AND t.supplier = cur_asl.supplier
             AND t.supplier_site = cur_asl.supplier_site
             AND t.from_organization_id = cur_asl.from_organization_id
             AND t.item = cur_asl.item;
      END;
      COMMIT;
    
    END LOOP;
  
  END load_asl;

  PROCEDURE load_sourcing_rule(errbuf OUT VARCHAR2, retcode OUT VARCHAR2) IS
  
    CURSOR csr_sourcing_rules IS
      SELECT DISTINCT rule_name,
                      organization,
                      vendor,
                      vendor_site,
                      start_date,
                      end_date
        FROM xxobjt_conv_sourcing_rule
       WHERE int_status = 'N';
  
    CURSOR csr_rule_lines(p_rule_name VARCHAR2) IS
      SELECT DISTINCT *
        FROM xxobjt_conv_sourcing_rule
       WHERE int_status = 'N'
         AND rule_name = p_rule_name;
  
    cur_rule csr_sourcing_rules%ROWTYPE;
    cur_line csr_rule_lines%ROWTYPE;
    invalid_rule EXCEPTION;
    invalid_item EXCEPTION;
  
    l_rule_name VARCHAR(80);
    ---l_create_update_flag     VARCHAR2(10);
    l_sourcing_rule_type     NUMBER;
    l_organization_id        NUMBER;
    l_org_id                 NUMBER;
    l_inventory_item_id      NUMBER;
    l_vendor_id              NUMBER;
    l_vendor_site_id         NUMBER;
    l_error_msg              VARCHAR2(500);
    x_progress               VARCHAR2(5);
    l_temp_sourcing_rule_id  NUMBER;
    l_sourcing_rule_id       NUMBER;
    l_sr_receipt_id          NUMBER;
    l_sr_source_id           NUMBER;
    l_assignment_id          NUMBER;
    l_assignment_set_id      NUMBER;
    l_assign_organization_id NUMBER;
  
  BEGIN
    errbuf  := NULL;
    retcode := 0;
    ----l_create_update_flag := 'CREATE';
    l_organization_id := xxinv_utils_pkg.get_master_organization_id;
  
    SELECT assignment_set_id
      INTO l_assignment_set_id
      FROM mrp_assignment_sets;
  
    FOR cur_rule IN csr_sourcing_rules LOOP
    
      BEGIN
      
        BEGIN
        
          SELECT organization_id
            INTO l_org_id
            FROM hr_operating_units ou
           WHERE ou.name = cur_rule.organization;
          mo_global.set_org_access(p_org_id_char     => l_org_id,
                                   p_sp_id_char      => NULL,
                                   p_appl_short_name => 'PO');
        
        EXCEPTION
          WHEN OTHERS THEN
            l_error_msg := 'Invalid Operating Unit, ' || SQLERRM;
            RAISE invalid_rule;
          
        END;
      
        l_rule_name := cur_rule.rule_name;
      
        BEGIN
        
          SELECT s.vendor_id, vendor_site_id
            INTO l_vendor_id, l_vendor_site_id
            FROM ap_suppliers s, ap_supplier_sites_all ss
           WHERE s.vendor_id = ss.vendor_id
             AND s.vendor_name = cur_rule.vendor
             AND ss.vendor_site_code = ss.vendor_site_code
             AND rownum < 2;
        
        EXCEPTION
          WHEN no_data_found THEN
            l_error_msg := 'Invalid Supplier/Supplier Site';
            RAISE invalid_rule;
          
        END;
      
        l_sourcing_rule_type := 1;
      
        x_progress := '020';
        BEGIN
        
          ----<LOCAL SR/ASL PROJECT 11i11 START>
          SELECT sourcing_rule_id
            INTO l_temp_sourcing_rule_id
            FROM mrp_sourcing_rules
           WHERE sourcing_rule_name = l_rule_name
             AND sourcing_rule_type = l_sourcing_rule_type
             AND ----<LOCAL SR/ASL PROJECT 11i11>
                 nvl(organization_id, -999) = nvl(l_organization_id, -999); ----<LOCAL SR/ASL PROJECT 11i11>
          ----<LOCAL SR/ASL PROJECT 11i11 END>
          -- Bug#3184990
          l_error_msg := 'Rule already exists';
          RAISE invalid_rule;
        
        EXCEPTION
          WHEN no_data_found THEN
            l_temp_sourcing_rule_id := NULL;
        END;
      
        --x_progress := '030';
      
        SELECT mrp_sourcing_rules_s.nextval
          INTO l_sourcing_rule_id
          FROM sys.dual;
      
        INSERT INTO mrp_sourcing_rules
          (sourcing_rule_id,
           sourcing_rule_name,
           status,
           sourcing_rule_type,
           organization_id,
           last_update_date,
           last_updated_by,
           creation_date,
           created_by,
           last_update_login,
           planning_active)
        VALUES
          (l_sourcing_rule_id,
           l_rule_name,
           1, -- status
           l_sourcing_rule_type, --<LOCAL SR/ASL PROJECT 11i11>
           NULL, --<LOCAL SR/ASL PROJECT 11i11>
           SYSDATE - 1,
           g_user_id,
           SYSDATE - 1,
           g_user_id,
           -1,
           1 -- planning_active (1=ACTIVE)
           );
      
        SELECT mrp_sr_receipt_org_s.nextval INTO l_sr_receipt_id FROM dual;
      
        --x_progress := '040';
        INSERT INTO mrp_sr_receipt_org
          (sr_receipt_id,
           sourcing_rule_id,
           effective_date,
           disable_date,
           last_update_date,
           last_updated_by,
           creation_date,
           created_by,
           last_update_login,
           receipt_organization_id ----<LOCAL SR/ASL PROJECT 11i11>
           )
        VALUES
          (l_sr_receipt_id,
           l_sourcing_rule_id,
           nvl(cur_rule.start_date, SYSDATE - 1),
           cur_rule.end_date,
           SYSDATE - 1,
           g_user_id,
           SYSDATE - 1,
           g_user_id,
           -1,
           NULL ----<LOCAL SR/ASL PROJECT 11i11>
           );
      
        --x_progress := '050';
        SELECT mrp_sr_source_org_s.nextval
          INTO l_sr_source_id
          FROM sys.dual;
      
        INSERT INTO mrp_sr_source_org
          (sr_source_id,
           sr_receipt_id,
           vendor_id,
           vendor_site_id,
           source_type,
           allocation_percent,
           rank,
           last_update_date,
           last_updated_by,
           creation_date,
           created_by,
           last_update_login)
        VALUES
          (l_sr_source_id,
           l_sr_receipt_id,
           l_vendor_id,
           l_vendor_site_id,
           3, -- source_type
           100, -- bug 605898, allocation_percent should be 100 instead of 0
           1, -- rank should be 1
           SYSDATE - 1,
           g_user_id,
           SYSDATE - 1,
           g_user_id,
           -1);
      
        x_progress := '060';
        -- Assign at Item level
        ----<LOCAL SR/ASL PROJECT 11i11 START>
        --Validate and ensure that the item is enabled for the given inventory
        --org. This is to ensure that the correct assignment goes in the
        --MRP_SR_ASSIGNMENTS
      
        FOR cur_line IN csr_rule_lines(cur_rule.rule_name) LOOP
        
          BEGIN
            BEGIN
            
              SELECT inventory_item_id
                INTO l_inventory_item_id
                FROM mtl_system_items_b
               WHERE segment1 = cur_line.item
                 AND organization_id = l_organization_id;
            
              SELECT organization_id
                INTO l_assign_organization_id
                FROM (SELECT mp.organization_id
                        FROM mtl_system_items_b msi, mtl_parameters mp
                       WHERE msi.inventory_item_id = l_inventory_item_id
                         AND msi.organization_id = mp.organization_id
                         AND mp.organization_code IN ('IPK', 'IRK') ---('WRI', 'WPI')
                       ORDER BY organization_code DESC)
               WHERE rownum < 2;
            
            EXCEPTION
              WHEN no_data_found THEN
              
                l_error_msg := 'Invalid item';
                RAISE invalid_item;
              
            END;
            ----<LOCAL SR/ASL PROJECT 11i11 END>
          
            SELECT mrp_sr_assignments_s.nextval
              INTO l_assignment_id
              FROM sys.dual;
          
            BEGIN
            
              INSERT INTO mrp_sr_assignments
                (assignment_id,
                 assignment_type,
                 sourcing_rule_id,
                 sourcing_rule_type,
                 assignment_set_id,
                 last_update_date,
                 last_updated_by,
                 creation_date,
                 created_by,
                 last_update_login,
                 organization_id,
                 inventory_item_id)
              VALUES
                (l_assignment_id,
                 6, ----<LOCAL SR/ASL PROJECT 11i11>
                 l_sourcing_rule_id,
                 l_sourcing_rule_type, -- sourcing_rule_type (1=SOURCING RULE)
                 l_assignment_set_id,
                 SYSDATE - 1,
                 g_user_id,
                 SYSDATE - 1,
                 g_user_id,
                 -1,
                 -- Bug 3692799: organization_id should be null
                 -- when assignment_type is 3 (item assignment)
                 l_assign_organization_id,
                 l_inventory_item_id);
              ----<LOCAL SR/ASL PROJECT 11i11 END>
            EXCEPTION
              WHEN OTHERS THEN
                NULL;
            END;
          EXCEPTION
            WHEN invalid_item THEN
            
              UPDATE xxobjt_conv_sourcing_rule t
                 SET int_status = 'E',
                     err_messge = l_error_msg,
                     rule_name  = rule_name || '_I'
               WHERE t.rule_name = cur_rule.rule_name
                 AND t.vendor = cur_rule.vendor
                 AND t.organization = cur_rule.organization
                 AND t.item = cur_line.item;
            
          END;
        
        --    COMMIT;
        
        END LOOP;
      
        UPDATE xxobjt_conv_sourcing_rule t
           SET int_status = 'S', err_messge = NULL
         WHERE t.rule_name = cur_rule.rule_name
           AND t.vendor = cur_rule.vendor;
      
      EXCEPTION
        WHEN invalid_rule THEN
          ROLLBACK;
          UPDATE xxobjt_conv_sourcing_rule t
             SET int_status = 'E', err_messge = l_error_msg
           WHERE t.rule_name = cur_rule.rule_name
             AND t.vendor = cur_rule.vendor
             AND t.organization = cur_rule.organization;
        
        WHEN OTHERS THEN
          ROLLBACK;
          l_error_msg := SQLERRM;
          UPDATE xxobjt_conv_sourcing_rule t
             SET int_status = 'E', err_messge = l_error_msg
           WHERE t.rule_name = cur_rule.rule_name
             AND t.vendor = cur_rule.vendor
             AND t.organization = cur_rule.organization;
      END;
      COMMIT;
      l_error_msg := NULL;
    END LOOP;
  
  END load_sourcing_rule;

  ----------------------------------------------------------------
  PROCEDURE load_po_blanket_lines(errbuf        OUT VARCHAR2,
                                  retcode       OUT VARCHAR2,
                                  p_po_segment1 IN VARCHAR2) IS
  
    CURSOR get_po_blanket_header IS
      SELECT poh.po_header_id,
             poh.segment1,
             poh.type_lookup_code,
             poh.vendor_id,
             v.vendor_name,
             poh.vendor_site_id,
             vs.vendor_site_code,
             poh.agent_id,
             initcap(a.agent_name) agent_name,
             poh.org_id,
             ou.name operating_unit
        FROM po_headers_all        poh,
             po_vendor_sites_all   vs,
             po_agents_v           a,
             po_vendors            v,
             hr_operating_units    ou,
             po_ga_org_assignments ga
       WHERE poh.segment1 = p_po_segment1 --proc. parameter
         AND poh.global_agreement_flag = 'Y'
         AND poh.type_lookup_code = 'BLANKET'
         AND poh.vendor_id = 4472 ---  Stratasys, Inc.
         AND ou.name IN ('OBJET DE (OU)', 'OBJET HK (OU)') --- org_id in (96, 103)
         AND ga.po_header_id = poh.po_header_id
         AND nvl(ga.enabled_flag, 'N') = 'Y'
         AND ga.organization_id = poh.org_id
         AND nvl(poh.vendor_site_id, -777) = vs.vendor_site_id(+)
         AND poh.org_id = ou.organization_id
         AND nvl(poh.agent_id, -777) = a.agent_id(+)
         AND nvl(poh.vendor_id, -777) = v.vendor_id(+);
  
    CURSOR get_po_blanket_lines IS
      SELECT upper(pol.item_code) item_code, pol.price
        FROM xxobjt_conv_po_blanket_lines pol
       WHERE pol.trans_to_int_code = 'N';
  
    missing_parameter_po_seg1 EXCEPTION;
    invalid_record            EXCEPTION;
    --l_req_id                  NUMBER;
    l_step              VARCHAR2(100);
    l_error_msg         VARCHAR2(250);
    l_inventory_item_id NUMBER;
    l_line_num          NUMBER;
    ----l_line_id                 NUMBER;
    l_uom_code               VARCHAR2(3);
    l_unit_of_measure        mtl_system_items_b.primary_unit_of_measure%TYPE;
    l_header_counter         NUMBER := 0;
    l_inserted_lines_counter NUMBER := 0;
  
  BEGIN
  
    errbuf  := '';
    retcode := '0';
  
    l_step := 'Step 0';
    IF p_po_segment1 IS NULL THEN
      RAISE missing_parameter_po_seg1;
    END IF;
  
    l_step := 'Step 5';
    UPDATE xxobjt_conv_po_blanket_lines pol
       SET pol.trans_to_int_code  = 'E',
           pol.trans_to_int_error = 'More than 1 record for the same Item Code'
     WHERE nvl(pol.trans_to_int_code, 'N') = 'N'
       AND EXISTS
     (SELECT COUNT(1)
              FROM xxobjt_conv_po_blanket_lines pol2
             WHERE pol2.item_code = pol.item_code HAVING COUNT(1) > 1);
  
    COMMIT;
  
    l_step := 'Step 10';
    UPDATE xxobjt_conv_po_blanket_lines pol
       SET pol.trans_to_int_code  = 'E',
           pol.trans_to_int_error = 'Missing Item Code'
     WHERE nvl(pol.trans_to_int_code, 'N') = 'N'
       AND pol.item_code IS NULL;
  
    COMMIT;
  
    l_step := 'Step 15';
    UPDATE xxobjt_conv_po_blanket_lines pol
       SET pol.trans_to_int_code  = 'E',
           pol.trans_to_int_error = 'Missing Price'
     WHERE nvl(pol.trans_to_int_code, 'N') = 'N'
       AND pol.price IS NULL;
  
    COMMIT;
  
    l_step := 'Step 20';
    UPDATE xxobjt_conv_po_blanket_lines pol
       SET pol.trans_to_int_code  = 'E',
           pol.trans_to_int_error = 'Price should be positive value'
     WHERE nvl(pol.trans_to_int_code, 'N') = 'N'
       AND pol.price < 0;
  
    COMMIT;
  
    l_step := 'Step 25';
    UPDATE xxobjt_conv_po_blanket_lines pol
       SET pol.trans_to_int_code  = 'E',
           pol.trans_to_int_error = 'There is forbidden character in item_code '
     WHERE nvl(pol.trans_to_int_code, 'N') = 'N'
       AND (instr(pol.item_code, '.', 1) > 0 OR
            instr(pol.item_code, ',', 1) > 0 OR
            instr(pol.item_code, '<', 1) > 0 OR
            instr(pol.item_code, '>', 1) > 0 OR
            instr(pol.item_code, '=', 1) > 0 OR
            instr(pol.item_code, '_', 1) > 0 OR
            instr(pol.item_code, ';', 1) > 0 OR
            instr(pol.item_code, ':', 1) > 0 OR
            instr(pol.item_code, '+', 1) > 0 OR
            instr(pol.item_code, ')', 1) > 0 OR
            instr(pol.item_code, '(', 1) > 0 OR
            instr(pol.item_code, '*', 1) > 0 OR
            instr(pol.item_code, '&', 1) > 0 OR
            instr(pol.item_code, '^', 1) > 0 OR
            instr(pol.item_code, '%', 1) > 0 OR
            instr(pol.item_code, '$', 1) > 0 OR
            instr(pol.item_code, '#', 1) > 0 OR
            instr(pol.item_code, '@', 1) > 0 OR
            instr(pol.item_code, '!', 1) > 0 OR
            instr(pol.item_code, '?', 1) > 0 OR
            instr(pol.item_code, '/', 1) > 0 OR
            instr(pol.item_code, '\', 1) > 0 OR
            instr(pol.item_code, '''', 1) > 0 OR
            instr(pol.item_code, '"', 1) > 0 OR
            instr(pol.item_code, '|', 1) > 0 OR
            instr(pol.item_code, '{', 1) > 0 OR
            instr(pol.item_code, '}', 1) > 0 OR
            instr(pol.item_code, '[', 1) > 0 OR
            instr(pol.item_code, ']', 1) > 0);
  
    COMMIT;
  
    l_step := 'Step 30';
    UPDATE xxobjt_conv_po_blanket_lines pbl
       SET pbl.trans_to_int_code  = 'E',
           pbl.trans_to_int_error = 'Item already exists in po_lines_all for Blanket PO segment1=' ||
                                    p_po_segment1
     WHERE nvl(pbl.trans_to_int_code, 'N') = 'N'
       AND EXISTS (SELECT 1
              FROM po_headers_all     poh,
                   po_lines_all       pol,
                   mtl_system_items_b msi
             WHERE msi.segment1 = upper(pbl.item_code)
               AND poh.segment1 = p_po_segment1 --parameter
               AND msi.organization_id = 91 ---Master
               AND msi.inventory_item_id = pol.item_id
               AND poh.po_header_id = pol.po_header_id);
  
    COMMIT;
  
    FOR blanket_header_rec IN get_po_blanket_header LOOP
      ------- PO Blanket Header loop ----- 1 record only -------------------------
      l_step           := 'Step 32';
      l_header_counter := l_header_counter + 1;
      l_error_msg      := NULL;
      dbms_output.put_line('==== Blanket PO segment1=' || p_po_segment1 ||
                           ' =======');
      dbms_output.put_line('po_header_id    =' ||
                           blanket_header_rec.po_header_id);
      dbms_output.put_line('operating unit  =' ||
                           blanket_header_rec.operating_unit);
      dbms_output.put_line('type_lookup_code=' ||
                           blanket_header_rec.type_lookup_code);
      dbms_output.put_line('vendor name     =' ||
                           blanket_header_rec.vendor_name);
      dbms_output.put_line('vendor site code=' ||
                           blanket_header_rec.vendor_site_code);
      dbms_output.put_line('agent name      =' ||
                           blanket_header_rec.agent_name);
    
      fnd_file.put_line(fnd_file.log,
                        '==== Blanket PO segment1=' || p_po_segment1 ||
                        ' =======');
      fnd_file.put_line(fnd_file.log,
                        'po_header_id    =' ||
                        blanket_header_rec.po_header_id);
      fnd_file.put_line(fnd_file.log,
                        'operating unit  =' ||
                        blanket_header_rec.operating_unit);
      fnd_file.put_line(fnd_file.log,
                        'type_lookup_code=' ||
                        blanket_header_rec.type_lookup_code);
      fnd_file.put_line(fnd_file.log,
                        'vendor name     =' ||
                        blanket_header_rec.vendor_name);
      fnd_file.put_line(fnd_file.log,
                        'vendor site code=' ||
                        blanket_header_rec.vendor_site_code);
      fnd_file.put_line(fnd_file.log,
                        'agent name      =' ||
                        blanket_header_rec.agent_name);
    
      l_step := 'Step 33';
      IF blanket_header_rec.org_id = 96 THEN
        --- operating unit 'OBJET DE (OU)'
        UPDATE xxobjt_conv_po_blanket_lines pbl
           SET pbl.trans_to_int_code  = 'E',
               pbl.trans_to_int_error = 'Item ' || upper(pbl.item_code) ||
                                        ' should be assigned to ''ESB'' organization_id=728'
         WHERE nvl(pbl.trans_to_int_code, 'N') = 'N'
           AND NOT EXISTS
         (SELECT 1
                  FROM mtl_system_items_b msi
                 WHERE organization_id = 728 --- ESB
                   AND msi.segment1 = upper(pbl.item_code));
        COMMIT;
        UPDATE xxobjt_conv_po_blanket_lines pbl
           SET pbl.trans_to_int_code  = 'E',
               pbl.trans_to_int_error = 'Item ' || upper(pbl.item_code) ||
                                        ' should be assigned to ''ETF'' organization_id=729'
         WHERE nvl(pbl.trans_to_int_code, 'N') = 'N'
           AND NOT EXISTS
         (SELECT 1
                  FROM mtl_system_items_b msi
                 WHERE organization_id = 729 --- ETF
                   AND msi.segment1 = upper(pbl.item_code));
        COMMIT;
        UPDATE xxobjt_conv_po_blanket_lines pbl
           SET pbl.trans_to_int_code  = 'E',
               pbl.trans_to_int_error = 'Item ' || upper(pbl.item_code) ||
                                        ' in ''ESB'' organization_id=728 -- flags...purchasing_enabled,purchasing_item,inventory_item,stock_enabled,mtl_transactions_enabled,costing_enabled,inventory_asset should be Y'
         WHERE nvl(pbl.trans_to_int_code, 'N') = 'N'
           AND NOT EXISTS
         (SELECT 1
                  FROM mtl_system_items_b msi
                 WHERE organization_id = 728 --- ESB
                   AND msi.segment1 = upper(pbl.item_code)
                   AND nvl(msi.purchasing_enabled_flag, 'N') = 'Y'
                   AND nvl(msi.purchasing_item_flag, 'N') = 'Y'
                   AND nvl(msi.inventory_item_flag, 'N') = 'Y'
                   AND nvl(msi.stock_enabled_flag, 'N') = 'Y'
                   AND nvl(msi.mtl_transactions_enabled_flag, 'N') = 'Y'
                   AND nvl(msi.costing_enabled_flag, 'N') = 'Y'
                   AND nvl(msi.inventory_asset_flag, 'N') = 'Y');
        COMMIT;
        UPDATE xxobjt_conv_po_blanket_lines pbl
           SET pbl.trans_to_int_code  = 'E',
               pbl.trans_to_int_error = 'Item ' || upper(pbl.item_code) ||
                                        ' in ''ETF'' organization_id=729 -- flags...purchasing_enabled,purchasing_item,inventory_item,stock_enabled,mtl_transactions_enabled,costing_enabled,inventory_asset should be Y'
         WHERE nvl(pbl.trans_to_int_code, 'N') = 'N'
           AND NOT EXISTS
         (SELECT 1
                  FROM mtl_system_items_b msi
                 WHERE organization_id = 729 --- ETF
                   AND msi.segment1 = upper(pbl.item_code)
                   AND nvl(msi.purchasing_enabled_flag, 'N') = 'Y'
                   AND nvl(msi.purchasing_item_flag, 'N') = 'Y'
                   AND nvl(msi.inventory_item_flag, 'N') = 'Y'
                   AND nvl(msi.stock_enabled_flag, 'N') = 'Y'
                   AND nvl(msi.mtl_transactions_enabled_flag, 'N') = 'Y'
                   AND nvl(msi.costing_enabled_flag, 'N') = 'Y'
                   AND nvl(msi.inventory_asset_flag, 'N') = 'Y');
        COMMIT;
      
      ELSIF blanket_header_rec.org_id = 103 THEN
        --- operating unit 'OBJET HK (OU)'
        UPDATE xxobjt_conv_po_blanket_lines pbl
           SET pbl.trans_to_int_code  = 'E',
               pbl.trans_to_int_error = 'Item ' || upper(pbl.item_code) ||
                                        ' should be assigned to ''ASH'' organization_id=726'
         WHERE nvl(pbl.trans_to_int_code, 'N') = 'N'
           AND NOT EXISTS
         (SELECT 1
                  FROM mtl_system_items_b msi
                 WHERE organization_id = 726 --- ASH
                   AND msi.segment1 = upper(pbl.item_code));
        COMMIT;
        UPDATE xxobjt_conv_po_blanket_lines pbl
           SET pbl.trans_to_int_code  = 'E',
               pbl.trans_to_int_error = 'Item ' || upper(pbl.item_code) ||
                                        ' should be assigned to ''ATH'' organization_id=725'
         WHERE nvl(pbl.trans_to_int_code, 'N') = 'N'
           AND NOT EXISTS
         (SELECT 1
                  FROM mtl_system_items_b msi
                 WHERE organization_id = 725 --- ATH
                   AND msi.segment1 = upper(pbl.item_code));
        COMMIT;
        UPDATE xxobjt_conv_po_blanket_lines pbl
           SET pbl.trans_to_int_code  = 'E',
               pbl.trans_to_int_error = 'Item ' || upper(pbl.item_code) ||
                                        ' in ''ASH'' organization_id=726 -- flags...purchasing_enabled,purchasing_item,inventory_item,stock_enabled,mtl_transactions_enabled,costing_enabled,inventory_asset should be Y'
         WHERE nvl(pbl.trans_to_int_code, 'N') = 'N'
           AND NOT EXISTS
         (SELECT 1
                  FROM mtl_system_items_b msi
                 WHERE organization_id = 726 --- ASH
                   AND msi.segment1 = upper(pbl.item_code)
                   AND nvl(msi.purchasing_enabled_flag, 'N') = 'Y'
                   AND nvl(msi.purchasing_item_flag, 'N') = 'Y'
                   AND nvl(msi.inventory_item_flag, 'N') = 'Y'
                   AND nvl(msi.stock_enabled_flag, 'N') = 'Y'
                   AND nvl(msi.mtl_transactions_enabled_flag, 'N') = 'Y'
                   AND nvl(msi.costing_enabled_flag, 'N') = 'Y'
                   AND nvl(msi.inventory_asset_flag, 'N') = 'Y');
        COMMIT;
        UPDATE xxobjt_conv_po_blanket_lines pbl
           SET pbl.trans_to_int_code  = 'E',
               pbl.trans_to_int_error = 'Item ' || upper(pbl.item_code) ||
                                        ' in ''ATH'' organization_id=725'
         WHERE nvl(pbl.trans_to_int_code, 'N') = 'N'
           AND NOT EXISTS
         (SELECT 1
                  FROM mtl_system_items_b msi
                 WHERE organization_id = 725 --- ATH
                   AND msi.segment1 = upper(pbl.item_code)
                   AND nvl(msi.purchasing_enabled_flag, 'N') = 'Y'
                   AND nvl(msi.purchasing_item_flag, 'N') = 'Y'
                   AND nvl(msi.inventory_item_flag, 'N') = 'Y'
                   AND nvl(msi.stock_enabled_flag, 'N') = 'Y'
                   AND nvl(msi.mtl_transactions_enabled_flag, 'N') = 'Y'
                   AND nvl(msi.costing_enabled_flag, 'N') = 'Y'
                   AND nvl(msi.inventory_asset_flag, 'N') = 'Y');
        COMMIT;
      END IF;
    
      BEGIN
      
        mo_global.set_org_access(p_org_id_char     => blanket_header_rec.org_id,
                                 p_sp_id_char      => NULL,
                                 p_appl_short_name => 'PO');
      EXCEPTION
        WHEN OTHERS THEN
          l_error_msg := 'Invalid Operating Unit, ' || SQLERRM;
          RAISE invalid_record;
      END;
    
      l_step := 'Step 40';
      ---Get max. existing line_num for this PO
      SELECT nvl(MAX(pol.line_num), 0)
        INTO l_line_num
        FROM po_lines_all pol
       WHERE pol.po_header_id = blanket_header_rec.po_header_id;
    
      l_step := 'Step 45';
      INSERT INTO po_headers_interface
        (interface_header_id,
         po_header_id, --this blanket po will be updated (new line/lines will be added)
         batch_id,
         action,
         process_code,
         document_type_code,
         approval_status,
         org_id,
         vendor_id,
         vendor_site_code,
         vendor_site_id,
         agent_id, --optional as you can enter buyer duringimport run
         -----VENDOR_DOC_NUM, --Unique Identifier used to update Blanket
         creation_date,
         created_by,
         last_update_date,
         last_updated_by)
      VALUES
        (apps.po_headers_interface_s.nextval,
         blanket_header_rec.po_header_id,
         1,
         'UPDATE',
         'PENDING',
         'BLANKET',
         'APPROVED',
         blanket_header_rec.org_id,
         blanket_header_rec.vendor_id,
         blanket_header_rec.vendor_site_code,
         blanket_header_rec.vendor_site_id,
         blanket_header_rec.agent_id,
         ----blanket_header_rec.segment1,
         SYSDATE,
         g_user_id,
         SYSDATE,
         g_user_id);
    
      l_error_msg := NULL;
      FOR blanket_lines_rec IN get_po_blanket_lines LOOP
        --------- Lines loop -----------------------
        l_step := 'Step 50';
        BEGIN
          ----Check Item -----
          BEGIN
            SELECT inventory_item_id,
                   primary_uom_code,
                   primary_unit_of_measure
              INTO l_inventory_item_id, l_uom_code, l_unit_of_measure
              FROM mtl_system_items_b
             WHERE segment1 = blanket_lines_rec.item_code
               AND organization_id =
                   xxinv_utils_pkg.get_master_organization_id;
          EXCEPTION
            WHEN no_data_found THEN
              l_error_msg := 'This item does not exist in mtl_system_items_b';
              RAISE invalid_record;
          END;
          --------------------
          l_line_num := l_line_num + 1;
          --------------------
          INSERT INTO po_lines_interface
            (interface_line_id,
             interface_header_id,
             line_num,
             item_id,
             action,
             process_code,
             unit_price,
             quantity,
             expiration_date,
             creation_date,
             created_by,
             last_update_date,
             last_updated_by)
          VALUES
            (po_lines_interface_s.nextval,
             po_headers_interface_s.currval,
             l_line_num,
             l_inventory_item_id,
             'ADD',
             'PENDING',
             blanket_lines_rec.price,
             999999,
             to_date('31-DEC-2013', 'DD-MON-YYYY'),
             SYSDATE,
             g_user_id,
             SYSDATE,
             g_user_id);
        
          UPDATE xxobjt_conv_po_blanket_lines pol
             SET pol.trans_to_int_code = 'S', pol.trans_to_int_error = NULL
           WHERE upper(pol.item_code) = blanket_lines_rec.item_code;
        
          IF MOD(l_inserted_lines_counter, 1000) = 0 THEN
            COMMIT;
          END IF;
          l_inserted_lines_counter := l_inserted_lines_counter + 1;
        
        EXCEPTION
          WHEN invalid_record THEN
            ROLLBACK;
            UPDATE xxobjt_conv_po_blanket_lines pol
               SET pol.trans_to_int_code  = 'E',
                   pol.trans_to_int_error = l_error_msg
             WHERE upper(pol.item_code) = blanket_lines_rec.item_code;
          
          WHEN OTHERS THEN
            ROLLBACK;
            l_error_msg := SQLERRM;
            UPDATE xxobjt_conv_po_blanket_lines pol
               SET pol.trans_to_int_code  = 'E',
                   pol.trans_to_int_error = l_error_msg
             WHERE upper(pol.item_code) = blanket_lines_rec.item_code;
        END;
        --------- the end of Lines loop -----------------------
      END LOOP;
      ------- the end of PO Blanket Header loop ----------------------
    END LOOP;
  
    IF l_header_counter = 0 THEN
      fnd_file.put_line(fnd_file.log,
                        '==== Blanket PO segment1=' || p_po_segment1 ||
                        ' is invalid or not exists');
      dbms_output.put_line('==== Blanket PO segment1=' || p_po_segment1 ||
                           ' is invalid or not exists');
    ELSIF l_inserted_lines_counter = 0 THEN
      fnd_file.put_line(fnd_file.log,
                        '==== No new lines in table XXOBJT_CONV_PO_BLANKET_LINES.   0 record inserted into interface tables...');
      dbms_output.put_line('==== No new lines in table XXOBJT_CONV_PO_BLANKET_LINES.   0 record inserted into interface tables...');
      ROLLBACK; -- dont commit PO_HEADERS_INTERFACE record without PO_LINES_INTERFACE records
    ELSIF l_inserted_lines_counter > 0 THEN
      COMMIT;
      fnd_file.put_line(fnd_file.log,
                        '==== 1 record inserted into PO_HEADERS_INTERFACE table (action=UPDATE)');
      dbms_output.put_line('====    1 record inserted into PO_HEADERS_INTERFACE table (action=UPDATE)');
    
      fnd_file.put_line(fnd_file.log,
                        '==== ' || l_inserted_lines_counter ||
                        ' records inserted into PO_LINES_INTERFACE table (action=ADD)');
      dbms_output.put_line('==== ' || l_inserted_lines_counter ||
                           ' records inserted into PO_LINES_INTERFACE table (action=ADD)');
    END IF;
  
    -----------------------------------------------------------------------------------------------------------------------------------
    ---Concurrent program 'Import Price Catalogs' should be submitted from responsibility 'Implementation Manufacturing, OBJET'
    -----------------------------------------------------------------------------------------------------------------------------------
    /*l_req_id:=fnd_request.submit_request(
              'PO',
              'POXPDOI',   ---Import Price Catalogs
               NULL,
               NULL,
               FALSE,
               NULL,       ---Default Buyer
               'Blanket',  ---Document Type
               NULL,       ---ocument Sub Type
               'N',        ---Create or Update Items
               'N',        ---Create Sourcing Rules
               'APPROVED', ---Approval Status
               NULL,       ---Release Generetion Method
               1,          ---Batch Id
               NULL,       ---Operating Unit
               'Y',        ---Global Agreement
               'Y',        ---Enable Sourcing Level
               NULL,       ---Sourcing Level
               NULL,       ---Inv Org Enable
               NULL);      ---Inventory Organization
    COMMIT;*/
  
    --see errors  select * from PO_INTERFACE_ERRORS
  
    /*if l_req_id>0 then
        null;
        ---Concurrent ''Import Price Catalogs'' was submitted successfully
    else
        null;
        ---Concurrent ''Import Price Catalogs'' submitting PROBLEM
    end if;*/
  
  EXCEPTION
    WHEN missing_parameter_po_seg1 THEN
      fnd_file.put_line(fnd_file.log,
                        '=========Missing parameter p_po_segment1=========');
      dbms_output.put_line('=========Missing parameter p_po_segment1=========');
      errbuf  := 'Missing parameter p_po_segment1';
      retcode := '2';
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log,
                        '==== Unexpected Error in procedure xxconv_il_purchasing_pkg.load_po_blanket_lines ' ||
                        l_step || ': ' || SQLERRM);
      dbms_output.put_line('==== Unexpected Error in procedure xxconv_il_purchasing_pkg.load_po_blanket_lines ' ||
                           l_step || ': ' || SQLERRM);
      errbuf  := 'Unexpected Error in procedure xxconv_il_purchasing_pkg.load_po_blanket_lines ' ||
                 l_step || ': ' || SQLERRM;
      retcode := '2';
  END load_po_blanket_lines;
  ----------------------------------------------------------------
  PROCEDURE load_fdm_category_assignments(errbuf  OUT VARCHAR2,
                                          retcode OUT VARCHAR2) IS
  
    CURSOR get_operating_units IS
      SELECT ou.organization_id org_id, ou.name operating_unit
        FROM hr_operating_units ou
       WHERE ou.name IN ('OBJET DE (OU)', 'OBJET HK (OU)');
  
    CURSOR get_organiz_and_sourcing_rule(p_org_id NUMBER) IS
      SELECT DISTINCT s.sourcing_rule_id,
                      s.sourcing_rule_type,
                      s.sourcing_rule_name,
                      mp.organization_id,
                      mp.organization_code
        FROM mrp_sourcing_rules s,
             mrp_sr_receipt_org sr,
             mrp_sr_source_org so,
             (SELECT a.organization_id, a.organization_code
                FROM mtl_parameters a
               WHERE a.organization_id IN
                     (728 /*ESB*/ /*101 EOG*/,
                      729 /*ETF */ /*102 EOT*/,
                      726 /*ASH*/ /*121 POH*/,
                      725 /*ATH*/ /*461 POT*/)
                    ------old (101, 102, 121, 461)
                 AND ((p_org_id = 96 AND
                     a.organization_id IN
                     (728 /*ESB*/ /*101 EOG*/, 729 /*ETF */ /*102 EOT*/)) OR
                     (p_org_id = 103 AND
                     a.organization_id IN
                     (726 /*ASH*/ /*121 POH*/, 725 /*ATH*/ /*461 POT*/)))) mp
       WHERE sr.sourcing_rule_id = s.sourcing_rule_id
         AND so.sr_receipt_id = sr.sr_receipt_id
         AND s.sourcing_rule_name IN ('SSYS DE', 'SSYS HK')
         AND ((p_org_id = 96 AND s.sourcing_rule_name = 'SSYS DE') OR
             (p_org_id = 103 AND s.sourcing_rule_name = 'SSYS HK'));
  
    CURSOR get_fdm_categories IS
      SELECT c.category_id, c.description
        FROM mtl_categories c
       WHERE c.attribute8 = 'FDM';
    ----and    c.CATEGORY_ID=70123;
  
    invalid_operating_unit EXCEPTION;
  
    ----l_org_id                 NUMBER;
    l_error_msg     VARCHAR2(500);
    l_assignment_id NUMBER;
  
    l_success_inserted_assignments NUMBER := 0;
    l_inserting_assignment_failure NUMBER := 0;
    l_step                         VARCHAR2(100);
  BEGIN
  
    l_step  := 'Step 0';
    errbuf  := NULL;
    retcode := '0';
  
    FOR operating_unit_rec IN get_operating_units LOOP
      ---=============  OPERATING UNITS LOOP ======================
      BEGIN
        mo_global.set_org_access(p_org_id_char     => operating_unit_rec.org_id,
                                 p_sp_id_char      => NULL,
                                 p_appl_short_name => 'PO');
      EXCEPTION
        WHEN OTHERS THEN
          l_error_msg := 'Invalid Operating Unit ''' ||
                         operating_unit_rec.operating_unit || '''';
          RAISE invalid_operating_unit;
      END;
      -------
      l_step := 'Step 5';
      FOR organiz_and_sourcing_rule_rec IN get_organiz_and_sourcing_rule(operating_unit_rec.org_id) LOOP
        ---=============  ORGANIZATIONS AND SOURCING RULES LOOP ======================
        l_step                         := 'Step 10';
        l_success_inserted_assignments := 0;
        l_inserting_assignment_failure := 0;
        FOR fdm_category_rec IN get_fdm_categories LOOP
          ---=============  FDM CATEGORIES LOOP ======================
          l_step := 'Step 15';
          SELECT mrp_sr_assignments_s.nextval
            INTO l_assignment_id
            FROM sys.dual;
          l_step := 'Step 20';
          BEGIN
            INSERT INTO mrp_sr_assignments
              (assignment_id,
               assignment_type,
               sourcing_rule_id,
               sourcing_rule_type,
               assignment_set_id,
               last_update_date,
               last_updated_by,
               creation_date,
               created_by,
               last_update_login,
               organization_id,
               category_id,
               category_set_id)
            VALUES
              (l_assignment_id,
               5, --- category-organization
               organiz_and_sourcing_rule_rec.sourcing_rule_id,
               1, ---  1=SOURCING RULE
               1, --- 'Global Assigment' set
               SYSDATE - 1,
               g_user_id,
               SYSDATE - 1,
               g_user_id,
               -1,
               organiz_and_sourcing_rule_rec.organization_id,
               fdm_category_rec.category_id,
               1100000041); ---  Main Category Set
            l_success_inserted_assignments := l_success_inserted_assignments + 1;
          EXCEPTION
            WHEN OTHERS THEN
              l_inserting_assignment_failure := l_inserting_assignment_failure + 1;
          END;
          ---=============  the end of FDM CATEGORIES LOOP ======================
        END LOOP;
        COMMIT;
        fnd_file.put_line(fnd_file.log,
                          '======== ' || l_success_inserted_assignments ||
                          ' category-organization assignments SUCCESSFULLY LOADED in organization ''' ||
                          organiz_and_sourcing_rule_rec.organization_code || '''');
        dbms_output.put_line('======== ' || l_success_inserted_assignments ||
                             ' category-organization assignments SUCCESSFULLY LOADED in organization ''' ||
                             organiz_and_sourcing_rule_rec.organization_code || '''');
        IF l_inserting_assignment_failure > 0 THEN
          fnd_file.put_line(fnd_file.log,
                            '======== ' || l_inserting_assignment_failure ||
                            ' category-organization assignments loading FAILURED in organization ''' ||
                            organiz_and_sourcing_rule_rec.organization_code || '''');
          dbms_output.put_line('======== ' ||
                               l_inserting_assignment_failure ||
                               ' category-organization assignments loading FAILURED in organization ''' ||
                               organiz_and_sourcing_rule_rec.organization_code || '''');
        END IF;
        ---=============  the end of ORGANIZATIONS AND SOURCING RULES LOOP ======================
      END LOOP;
      ---=============  the end of OPERATING UNITS LOOP ======================
    END LOOP;
  
  EXCEPTION
    WHEN invalid_operating_unit THEN
      fnd_file.put_line(fnd_file.log, l_error_msg);
      dbms_output.put_line(l_error_msg);
      errbuf  := l_error_msg;
      retcode := '2';
    
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log,
                        '==== Unexpected Error in procedure xxconv_il_purchasing_pkg.load_fdm_category_assignments ' ||
                        l_step || ': ' || SQLERRM);
      dbms_output.put_line('==== Unexpected Error in procedure xxconv_il_purchasing_pkg.load_fdm_category_assignments ' ||
                           l_step || ': ' || SQLERRM);
      errbuf  := 'Unexpected Error in procedure xxconv_il_purchasing_pkg.load_fdm_category_assignments ' ||
                 l_step || ': ' || SQLERRM;
      retcode := '2';
  END load_fdm_category_assignments;
  --------------------------------------------------------------------
  --  customization code: CUST695
  --  name:               fill_log_table
  --  create by:          Vitaly K.
  --  $Revision:          1.0 $
  --  creation date:      30/10/2013
  --  Purpose :
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   30/10/2013    Vitaly K.       initial build CR932
  ----------------------------------------------------------------------
  PROCEDURE fill_log_table(p_batch_id      IN NUMBER,
                           p_org_id        IN NUMBER,
                           p_po_number     IN VARCHAR2,
                           x_error_code    OUT NUMBER, ---0-success
                           x_error_message OUT VARCHAR2) IS
    stop_processing EXCEPTION;
    v_num_of_deleted_records  NUMBER;
    v_num_of_inserted_records NUMBER;
  BEGIN
    x_error_code    := 0; ---success
    x_error_message := NULL;
  
    IF p_batch_id IS NULL THEN
      x_error_code    := 2; ---error
      x_error_message := 'ERROR in Fill_Log_Table procedure: Missing p_batch_id parameter';
      RAISE stop_processing;
    END IF;
  
    IF p_org_id IS NULL THEN
      x_error_code    := 2; ---error
      x_error_message := 'ERROR in Fill_Log_Table procedure: Missing p_org_id parameter';
      RAISE stop_processing;
    END IF;
  
    DELETE FROM xxconv_po_log polog WHERE polog.batch_id = p_batch_id;
    v_num_of_deleted_records := SQL%ROWCOUNT;
    COMMIT;
    message(v_num_of_deleted_records ||
            ' records (garbage) were DELETED from XXCONV_PO_LOG for batch_id=' ||
            p_batch_id);
  
    DELETE FROM xxconv_po_log_distributions d
     WHERE d.batch_id = p_batch_id;
    v_num_of_deleted_records := SQL%ROWCOUNT;
    COMMIT;
    message(v_num_of_deleted_records ||
            ' records (garbage) were DELETED from XXCONV_PO_LOG_DISTRIBUTIONS for batch_id=' ||
            p_batch_id);
  
    INSERT INTO xxconv_po_log
      (batch_id,
       vendor_id,
       vendor_name,
       org_id,
       po_header_id,
       po_number,
       po_type_lookup_code,
       revision_num,
       currency_code,
       po_line_id,
       old_line_num,
       line_num,
       po_line_location_id,
       old_shipment_num,
       shipment_num,
       ship_to_organization_id,
       new_ship_to_organization_id,
       ship_to_location_id,
       shipment_need_by_date,
       shipment_promised_date,
       do_reserve_flag,
       interface_header_id,
       interface_line_id,
       status,
       error_message,
       creation_date,
       last_update_date)
      SELECT p_batch_id,
             a.vendor_id,
             a.vendor_name,
             a.org_id,
             a.po_header_id,
             a.po_number,
             a.type_lookup_code,
             a.revision_num,
             a.currency_code,
             a.po_line_id,
             a.old_line_num,
             a.line_num,
             a.line_location_id,
             a.old_shipment_num,
             a.shipment_num,
             a.ship_to_organization_id,
             a.new_ship_to_organization_id,
             a.ship_to_location_id,
             a.shipment_need_by_date,
             shipment_promised_date,
             a.do_reserve_flag, --- 1 ---this PO should be RESEVED at the end of conversion
             NULL                          interface_header_id,
             NULL                          interface_line_id,
             'N', ---status,
             NULL, ---error_message,
             SYSDATE                       creation_date,
             SYSDATE                       last_update_date
        FROM xxconv_po_std_cost_v a
       WHERE a.po_number = nvl(p_po_number, a.po_number)
         AND a.authorization_status = 'APPROVED'
         AND a.org_id = p_org_id ---parameter
       ORDER BY a.po_header_id, a.line_num, a.shipment_num;
  
    v_num_of_inserted_records := SQL%ROWCOUNT;
    COMMIT;
    message(v_num_of_inserted_records ||
            ' were successfully INSERTED into table XXCONV_PO_LOG for org_id=' ||
            p_org_id);
  
  EXCEPTION
    WHEN stop_processing THEN
      NULL;
    WHEN OTHERS THEN
      x_error_code    := 2;
      x_error_message := substr('Unexpected Error in  Fill_Log_Table: ' ||
                                SQLERRM,
                                1,
                                200);
  END fill_log_table;
  --------------------------------------------------------------------
  --  customization code: CUST695
  --  name:               po_data_validations
  --  create by:          Vitaly K.
  --  $Revision:          1.0 $
  --  creation date:      30/10/2013
  --  Purpose :
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   30/10/2013    Vitaly K.       initial build CR932
  ----------------------------------------------------------------------
  PROCEDURE po_data_validations(p_batch_id      NUMBER,
                                x_error_code    OUT NUMBER, ---0-success
                                x_error_message OUT VARCHAR2) IS
    CURSOR c_get_po_headers IS
      SELECT DISTINCT polog.po_header_id, poh.agent_id
        FROM xxconv_po_log  polog, --- po shipments level rows inside
             po_headers_all poh
       WHERE polog.batch_id = p_batch_id --parameter
         AND polog.status = 'N'
         AND polog.po_header_id = poh.po_header_id;
  
    CURSOR c_get_po_lines(p_po_header_id NUMBER) IS
      SELECT DISTINCT polog.po_header_id,
                      polog.po_line_id,
                      polog.line_num,
                      pl.item_id
        FROM xxconv_po_log polog, --- po shipments level rows inside
             po_lines_all  pl
       WHERE polog.batch_id = p_batch_id --parameter
         AND polog.po_header_id = p_po_header_id ---cursor parameter
         AND polog.status = 'N'
         AND polog.po_line_id = pl.po_line_id;
  
    CURSOR c_get_po_shipments(p_po_line_id NUMBER) IS
      SELECT polog.po_line_id,
             polog.shipment_num,
             polog.po_line_location_id,
             polog.ship_to_location_id,
             polog.new_ship_to_organization_id,
             mp.organization_code              new_ship_to_organization_code,
             hrl.inventory_organization_id     ship_to_loc_inv_organiz_id,
             mp_loc.organization_code          ship_to_loc_inv_organiz_code
        FROM xxconv_po_log    polog, --- po shipments level rows inside
             mtl_parameters   mp,
             hr_locations_all hrl,
             mtl_parameters   mp_loc
       WHERE polog.batch_id = p_batch_id --parameter
         AND polog.po_line_id = p_po_line_id ---cursor parameter
         AND polog.status = 'N'
         AND polog.new_ship_to_organization_id = mp.organization_id
         AND polog.ship_to_location_id = hrl.location_id
         AND nvl(hrl.inventory_organization_id, -777) =
             mp_loc.organization_id(+)
       ORDER BY polog.shipment_num;
  
    CURSOR c_get_po_distributions(p_po_line_location_id NUMBER) IS
      SELECT polog.po_header_id,
             polog.po_line_id,
             polog.po_line_location_id,
             polog.old_shipment_num,
             pod.po_distribution_id,
             pod.deliver_to_person_id,
             pod.destination_type_code
        FROM xxconv_po_log polog, po_distributions_all pod
       WHERE polog.batch_id = p_batch_id --parameter
         AND polog.po_line_location_id = p_po_line_location_id ---cursor parameter
         AND polog.status = 'N'
         AND polog.po_line_location_id = pod.line_location_id
         AND pod.quantity_ordered - nvl(pod.quantity_delivered, 0) -
             nvl(pod.quantity_cancelled, 0) > 0;
  
    v_step                     VARCHAR2(100);
    v_error_message            VARCHAR2(3000);
    v_num_of_validation_errors NUMBER := 0;
    invalid_buyer           EXCEPTION;
    stop_this_po_validation EXCEPTION;
  BEGIN
    v_step          := 'Step 0';
    x_error_code    := 0; ---0--success
    x_error_message := NULL;
  
    FOR header_rec IN c_get_po_headers LOOP
      ---==================== HEADERS LOOP =============================
      BEGIN
        /*v_step := 'Step 10';
        -----Check Buyer ACTIVE USER (PO_HEADERS_ALL.agent_id)
        BEGIN
          SELECT 'Invalid PO Buyer (inactive person) (agent_id=' ||
                 header_rec.agent_id || ', name=' ||
                 hr_general.decode_person_name(header_rec.agent_id) || ')'
            INTO v_error_message
            FROM dual
           WHERE instr(xxhr_person_pkg.get_system_person_type(SYSDATE,
                                                              header_rec.agent_id),
                       'EX') > 0;
          --all invalid Buyers will be replaced with Aviram, Yacov (agent_id=8681)
          RAISE invalid_buyer;
        EXCEPTION
          WHEN no_data_found THEN
            NULL;
        END;
        v_step := 'Step 20';
        -----Check Buyer ACTIVE BUYER (PO_HEADERS_ALL.agent_id)
        BEGIN
          SELECT 'Invalid PO Buyer (inactive buyer) (agent_id=' ||
                 header_rec.agent_id || ', name=' ||
                 hr_general.decode_person_name(header_rec.agent_id) || ')'
            INTO v_error_message
            FROM po_agents poa
           WHERE poa.agent_id = header_rec.agent_id
             AND nvl(poa.end_date_active, SYSDATE + 1) < SYSDATE;
          --all invalid Buyers will be replaced with Aviram, Yacov (agent_id=8681)
          RAISE invalid_buyer;
        EXCEPTION
          WHEN no_data_found THEN
            NULL;
        END;*/
        ----Check Lines data
        FOR line_rec IN c_get_po_lines(header_rec.po_header_id) LOOP
          ---==================== LINES LOOP =============================
          v_step := 'Step 30';
          -----Check Discontinued Item (PO_LINES_ALL.item_id)
          BEGIN
            SELECT 'Line#=' || line_rec.line_num || ', Item ' ||
                   msi.segment1 || ' (inv_item_id=' || line_rec.item_id ||
                   ') is Discontinued'
              INTO v_error_message
              FROM mtl_system_items_b msi
             WHERE msi.organization_id = 91 ---Master
               AND msi.inventory_item_id = line_rec.item_id
               AND nvl(msi.inventory_item_status_code, 'XYZ') =
                   'XX_DISCONT'; ---Discontinued
            v_step := 'Step 30.2';
            ---this PO LINE is invalid and will not be converted
            ----------but other valid lines will be converted...
            UPDATE xxconv_po_log a
               SET a.status           = 'E',
                   a.error_message    = v_error_message,
                   a.last_update_date = SYSDATE
             WHERE a.po_header_id = header_rec.po_header_id ---header
               AND a.po_line_id = line_rec.po_line_id --line
               AND a.batch_id = p_batch_id; ---parameter
          
            v_num_of_validation_errors := v_num_of_validation_errors +
                                          SQL%ROWCOUNT;
            ------RAISE stop_this_po_validation;
          EXCEPTION
            WHEN no_data_found THEN
              NULL;
          END;
        
          v_step := 'Step 40';
          ----Check NON Purchaseable Item (PO_LINES_ALL.item_id)
          BEGIN
            SELECT 'Item ' || msi.segment1 || ' (inv_item_id=' ||
                   line_rec.item_id || ') is NON Purchaseable'
              INTO v_error_message
              FROM mtl_system_items_b msi
             WHERE msi.organization_id = 91 ---Master
               AND msi.inventory_item_id = line_rec.item_id
               AND msi.purchasing_enabled_flag = 'N'; ---NON Purchaseable item
            v_step := 'Step 40.2';
            ---this PO LINE is invalid and will not be converted
            ----------but other valid lines will be converted...
            UPDATE xxconv_po_log a
               SET a.status           = 'E',
                   a.error_message    = v_error_message,
                   a.last_update_date = SYSDATE
             WHERE a.po_header_id = header_rec.po_header_id ---header
               AND a.po_line_id = line_rec.po_line_id --line
               AND a.batch_id = p_batch_id; ---parameter
          
          EXCEPTION
            WHEN no_data_found THEN
              NULL;
          END;
          ----Check Shipments----
          FOR shipment_rec IN c_get_po_shipments(line_rec.po_line_id) LOOP
            ---================== SHIPPINGS (LINE_LOC) LOOP =======================
            v_step := 'Step 50';
            -----Check Location (PO_LINE_LOCATIONS_ALL.Ship_To_Location_Id)
            IF shipment_rec.ship_to_loc_inv_organiz_id IS NOT NULL AND
               shipment_rec.ship_to_loc_inv_organiz_id <>
               shipment_rec.new_ship_to_organization_id THEN
              v_error_message := 'The ship_to_location_id =' ||
                                 shipment_rec.ship_to_location_id ||
                                 ' is currently defined to ' ||
                                 shipment_rec.ship_to_loc_inv_organiz_code || '(' ||
                                 shipment_rec.ship_to_loc_inv_organiz_id ||
                                 '), and is not defined to ' ||
                                 shipment_rec.new_ship_to_organization_code || '(' ||
                                 shipment_rec.new_ship_to_organization_id || ')';
              ---Invalid PO Shipment --> this PO Line is invalid and will not be converted
              --------but other valid PO Lines will be converted...
              UPDATE xxconv_po_log a
                 SET a.status           = 'E',
                     a.error_message    = v_error_message,
                     a.last_update_date = SYSDATE
               WHERE a.po_header_id = header_rec.po_header_id ---header
                 AND a.po_line_id = line_rec.po_line_id ---line
                    ----AND a.po_line_location_id = shipment_rec.po_line_location_id ---shipment
                 AND a.batch_id = p_batch_id; --parameter
              v_num_of_validation_errors := v_num_of_validation_errors + 1;
              ----RAISE stop_this_po_validation;
            END IF;
          
            v_step := 'Step 60';
            -- check item assignment to new org
            DECLARE
              l_tmp NUMBER;
            BEGIN
            
              SELECT 1
                INTO l_tmp
                FROM mtl_system_items_b t
               WHERE t.inventory_item_id = line_rec.item_id
                 AND t.organization_id =
                     shipment_rec.new_ship_to_organization_id;
            
            EXCEPTION
              WHEN no_data_found THEN
                ---Invalid PO Shipment --> this PO Line is invalid and will not be converted
                --------but other valid PO Lines will be converted...
                UPDATE xxconv_po_log a
                   SET a.status           = 'E',
                       a.error_message    = 'Item id=' || line_rec.item_id ||
                                            '  not assign to organization_id= ' ||
                                            shipment_rec.new_ship_to_organization_id,
                       a.last_update_date = SYSDATE
                 WHERE a.po_header_id = header_rec.po_header_id ---header
                   AND a.po_line_id = line_rec.po_line_id ---line
                      ----AND a.po_line_location_id = shipment_rec.po_line_location_id ---shipment
                   AND a.batch_id = p_batch_id; --parameter
                v_num_of_validation_errors := v_num_of_validation_errors + 1;
                ----RAISE stop_this_po_validation;
            END;
          
            --
          
            FOR distrib_rec IN c_get_po_distributions(shipment_rec.po_line_location_id) LOOP
              ---==================== DISTRIBUTIONS LOOP =============================
              v_step := 'Step 70';
              -----Check PO Distribution Requestor (PO_DISTRIBUTIONS_ALL.deliver_to_person_id)
              BEGIN
                SELECT 'Invalid PO Distribution Requestor (deliver_to_person_id=' ||
                       distrib_rec.deliver_to_person_id || ' ' ||
                       hr_general.decode_person_name(distrib_rec.deliver_to_person_id) || ')'
                  INTO v_error_message
                  FROM dual
                 WHERE instr(xxhr_person_pkg.get_system_person_type(SYSDATE,
                                                                    distrib_rec.deliver_to_person_id),
                             'EX') > 0;
                ---invalid Distribution --> this PO Line is invalid and will not be converted
                --------but other valid PO Lines will be converted...
                UPDATE xxconv_po_log a
                   SET a.status           = 'E',
                       a.error_message    = v_error_message,
                       a.last_update_date = SYSDATE
                 WHERE a.po_header_id = header_rec.po_header_id ---header
                   AND a.po_line_id = line_rec.po_line_id ---line
                      -----AND a.po_line_location_id = shipment_rec.po_line_location_id ---shipment
                   AND a.batch_id = p_batch_id; --parameter
                v_num_of_validation_errors := v_num_of_validation_errors + 1;
              
              EXCEPTION
                WHEN no_data_found THEN
                  NULL;
              END;
              ------
              v_step := 'Step 80';
              -----Check PO Distribution Destination Type (PO_DISTRIBUTIONS_ALL.destination_type_code)
              IF distrib_rec.destination_type_code = 'EXPENSE' THEN
                ---invalid Distribution --> this PO Line is invalid and will not be converted
                --------but other valid PO Lines will be converted...
                UPDATE xxconv_po_log a
                   SET a.status           = 'E',
                       a.error_message    = 'Distribution destination_type_code=''EXPENSE'' (shipment_num=' ||
                                            distrib_rec.old_shipment_num ||
                                            ', po_distribution_id=' ||
                                            distrib_rec.po_distribution_id || ')',
                       a.last_update_date = SYSDATE
                 WHERE a.po_header_id = header_rec.po_header_id ---header
                   AND a.po_line_id = line_rec.po_line_id ---line
                      -----AND a.po_line_location_id = shipment_rec.po_line_location_id ---shipment
                   AND a.batch_id = p_batch_id; --parameter
                v_num_of_validation_errors := v_num_of_validation_errors + 1;
              END IF;
              ---===============the end of DISTRIBUTIONS LOOP =============================
            END LOOP;
            ---================== the end of SHIPPINGS (LINE_LOC) LOOP =======================
          END LOOP;
          ---===============the end of LINES LOOP =============================
        END LOOP;
        ------
      EXCEPTION
        WHEN stop_this_po_validation THEN
          ---this PO Quotation is invalid and will not be converted
          UPDATE xxconv_po_log a
             SET a.status           = 'E',
                 a.error_message    = v_error_message,
                 a.last_update_date = SYSDATE
           WHERE a.po_header_id = header_rec.po_header_id
             AND a.batch_id = p_batch_id; ---parameter
          v_num_of_validation_errors := v_num_of_validation_errors +
                                        SQL%ROWCOUNT;
          /*WHEN invalid_buyer THEN
          -----all invalid Buyers will be replaced with Aviram, Yacov (agent_id=8681)
          UPDATE xxconv_po_log a
             SET a.agent_id         = 8681, --- Aviram, Yacov
                 a.error_message    = 'Invalid Buyer was replaced with Aviram, Yacov (agent_id=8681)',
                 a.last_update_date = SYSDATE
           WHERE a.po_header_id = header_rec.po_header_id
             AND a.batch_id = p_batch_id; ---parameter*/
      END;
      COMMIT; ---------------COMMIT-------------
    ---===============the end of HEADERS LOOP =============================
    END LOOP;
    COMMIT; ---------COMMIT-----------
  
  EXCEPTION
    WHEN OTHERS THEN
      x_error_code    := 2;
      x_error_message := substr('Unexpected Error in  po_data_validations(' ||
                                v_step || '): ' || SQLERRM,
                                1,
                                200);
  END po_data_validations;
  --------------------------------------------------------------------
  --  customization code: CUST695
  --  name:               handle_po_distribution
  --  create by:          Vitaly K.
  --  $Revision:          1.0 $
  --  creation date:      30/10/2013
  --  Purpose :
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   30/10/2013    Vitaly K.       initial build CR932
  ----------------------------------------------------------------------
  PROCEDURE handle_po_distribution(p_batch_id                    NUMBER,
                                   p_new_ship_to_organization_id NUMBER,
                                   p_po_line_location_id         NUMBER,
                                   p_interface_header_id         NUMBER,
                                   p_interface_line_id           NUMBER,
                                   x_error_code                  OUT NUMBER, ---0-success
                                   x_error_message               OUT VARCHAR2) IS
    CURSOR c_get_po_distributions IS
      SELECT pl.line_num, pol.shipment_num, d.*
        FROM po_distributions_all  d,
             po_lines_all          pl,
             po_line_locations_all pol --shipments
       WHERE d.line_location_id = p_po_line_location_id --parameter
         AND d.quantity_ordered - nvl(d.quantity_delivered, 0) -
             nvl(d.quantity_cancelled, 0) > 0
         AND pol.po_line_id = pl.po_line_id
         AND d.line_location_id = pol.line_location_id
       ORDER BY d.distribution_num;
  
    l_inface_distribution_rec po.po_distributions_interface%ROWTYPE;
    stop_processing EXCEPTION;
  BEGIN
    x_error_code    := 0; ---success
    x_error_message := NULL;
  
    IF p_new_ship_to_organization_id IS NULL THEN
      x_error_code    := 2;
      x_error_message := 'Error in Handle_Po_Distribution: Missing parameter p_new_ship_to_organization_id';
      RAISE stop_processing;
    END IF;
    IF p_po_line_location_id IS NULL THEN
      x_error_code    := 2;
      x_error_message := 'Error in Handle_Po_Distribution: Missing parameter p_po_line_location_id';
      RAISE stop_processing;
    END IF;
    IF p_interface_header_id IS NULL THEN
      x_error_code    := 2;
      x_error_message := 'Error in Handle_Po_Distribution: Missing parameter p_interface_header_id';
      RAISE stop_processing;
    END IF;
    IF p_interface_line_id IS NULL THEN
      x_error_code    := 2;
      x_error_message := 'Error in Handle_Po_Distribution: Missing parameter p_interface_line_id';
      RAISE stop_processing;
    END IF;
  
    l_inface_distribution_rec.interface_header_id := p_interface_header_id;
    l_inface_distribution_rec.interface_line_id   := p_interface_line_id;
    FOR distribution_rec IN c_get_po_distributions LOOP
      ----================ DISTRIBUTIONS LOOP =======================
      SELECT po_distributions_interface_s.nextval
        INTO l_inface_distribution_rec.interface_distribution_id
        FROM dual;
    
      l_inface_distribution_rec.distribution_num := distribution_rec.distribution_num;
      l_inface_distribution_rec.set_of_books_id  := distribution_rec.set_of_books_id;
      ----l_inface_distribution_rec.code_combination_id         := distribution_rec.code_combination_id;
      l_inface_distribution_rec.quantity_ordered   := distribution_rec.quantity_ordered -
                                                      nvl(distribution_rec.quantity_delivered,
                                                          0) -
                                                      nvl(distribution_rec.quantity_cancelled,
                                                          0);
      l_inface_distribution_rec.po_release_id      := distribution_rec.po_release_id;
      l_inface_distribution_rec.quantity_delivered := 0; ---distribution_rec.quantity_delivered;
      l_inface_distribution_rec.quantity_billed    := distribution_rec.quantity_billed;
      l_inface_distribution_rec.quantity_cancelled := 0; ---distribution_rec.quantity_cancelled;
      ---l_inface_distribution_rec.req_header_reference_num := distribution_rec.req_header_reference_num;
      ---l_inface_distribution_rec.req_line_reference_num   := distribution_rec.req_line_reference_num;
      l_inface_distribution_rec.req_distribution_id         := distribution_rec.req_distribution_id;
      l_inface_distribution_rec.deliver_to_location_id      := distribution_rec.deliver_to_location_id;
      l_inface_distribution_rec.deliver_to_person_id        := distribution_rec.deliver_to_person_id;
      l_inface_distribution_rec.rate_date                   := distribution_rec.rate_date;
      l_inface_distribution_rec.rate                        := distribution_rec.rate;
      l_inface_distribution_rec.amount_billed               := distribution_rec.amount_billed;
      l_inface_distribution_rec.accrued_flag                := distribution_rec.accrued_flag;
      l_inface_distribution_rec.encumbered_flag             := distribution_rec.encumbered_flag;
      l_inface_distribution_rec.encumbered_amount           := distribution_rec.encumbered_amount;
      l_inface_distribution_rec.unencumbered_amount         := distribution_rec.unencumbered_amount;
      l_inface_distribution_rec.unencumbered_quantity       := distribution_rec.unencumbered_quantity;
      l_inface_distribution_rec.gl_encumbered_date          := trunc(SYSDATE);
      l_inface_distribution_rec.gl_cancelled_date           := distribution_rec.gl_cancelled_date;
      l_inface_distribution_rec.destination_type_code       := distribution_rec.destination_type_code;
      l_inface_distribution_rec.destination_organization_id := p_new_ship_to_organization_id;
      l_inface_distribution_rec.destination_subinventory    := distribution_rec.destination_subinventory;
      l_inface_distribution_rec.budget_account_id           := distribution_rec.budget_account_id;
      l_inface_distribution_rec.accrual_account_id          := distribution_rec.accrual_account_id;
      l_inface_distribution_rec.variance_account_id         := distribution_rec.variance_account_id;
      l_inface_distribution_rec.prevent_encumbrance_flag    := distribution_rec.prevent_encumbrance_flag;
      l_inface_distribution_rec.destination_context         := distribution_rec.destination_context;
      l_inface_distribution_rec.project_accounting_context  := distribution_rec.project_accounting_context;
      l_inface_distribution_rec.org_id                      := distribution_rec.org_id;
      l_inface_distribution_rec.recoverable_tax             := distribution_rec.recoverable_tax;
      l_inface_distribution_rec.nonrecoverable_tax          := distribution_rec.nonrecoverable_tax;
    
      l_inface_distribution_rec.bom_resource_id := distribution_rec.bom_resource_id;
    
      ---l_inface_distribution_rec.wip_entity 
      l_inface_distribution_rec.wip_entity_id         := distribution_rec.wip_entity_id;
      l_inface_distribution_rec.wip_operation_seq_num := distribution_rec.wip_operation_seq_num;
      l_inface_distribution_rec.wip_resource_seq_num  := distribution_rec.wip_resource_seq_num;
      -- l_inface_distribution_rec.wip_repetitive_schedule:= distribution_rec.wip_repetitive_schedule_id
      l_inface_distribution_rec.wip_repetitive_schedule_id := distribution_rec.wip_repetitive_schedule_id;
      ---l_inface_distribution_rec.wip_line_code
      l_inface_distribution_rec.wip_line_id := distribution_rec.wip_line_id;
      -----l_inface_distribution_rec.amount_delivered  := distribution_rec.amount_delivered;
      -----l_inface_distribution_rec.amount_cancelled  := distribution_rec.amount_cancelled;
      l_inface_distribution_rec.creation_date     := SYSDATE;
      l_inface_distribution_rec.created_by        := fnd_global.user_id;
      l_inface_distribution_rec.last_update_date  := SYSDATE;
      l_inface_distribution_rec.last_updated_by   := fnd_global.user_id;
      l_inface_distribution_rec.last_update_login := fnd_global.conc_login_id;
    
      INSERT INTO po_distributions_interface
      VALUES l_inface_distribution_rec;
      message('1 record was inserted into PO_DISTRIBUTIONS_INTERFACE ==== inter_distr_id=' ||
              l_inface_distribution_rec.interface_distribution_id ||
              ', Old Line#=' || distribution_rec.line_num ||
              ', Old Shipment#=' || distribution_rec.shipment_num ||
              ', Distribution#=' || distribution_rec.distribution_num);
    
      INSERT INTO xxconv_po_log_distributions
        (batch_id,
         old_po_line_location_id,
         distribution_num,
         req_distribution_id,
         creation_date,
         last_update_date)
      VALUES
        (p_batch_id,
         p_po_line_location_id,
         distribution_rec.distribution_num,
         distribution_rec.req_distribution_id,
         SYSDATE,
         SYSDATE);
      ----=========the end of PO DISTRIBUTIONS LOOP ==============================
    END LOOP;
  EXCEPTION
    WHEN stop_processing THEN
      NULL;
    WHEN OTHERS THEN
      x_error_code    := 2;
      x_error_message := substr('Unexpected Error in  Handle_Po_Distribution: ' ||
                                SQLERRM,
                                1,
                                200);
  END handle_po_distribution;
  --------------------------------------------------------------------
  --  customization code: CUST695
  --  name:               handle_po_lines_shipments
  --  create by:          Vitaly K.
  --  $Revision:          1.0 $
  --  creation date:      30/10/2013
  --  Purpose :
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   30/10/2013    Vitaly K.       initial build CR932
  ----------------------------------------------------------------------
  PROCEDURE handle_po_lines_shipments(p_batch_id            NUMBER,
                                      p_po_line_id          NUMBER,
                                      p_po_line_location_id NUMBER,
                                      p_interface_header_id NUMBER,
                                      x_error_code          OUT NUMBER, ---0-success
                                      x_error_message       OUT VARCHAR2) IS
    CURSOR c_get_po_lines_shipments IS
      SELECT po.*
        FROM xxconv_po_std_cost_v po --- po shipping level rows inside
       WHERE po.po_line_id = p_po_line_id ---parameter
         AND po.line_location_id = p_po_line_location_id --parameter
       ORDER BY po.shipment_num;
  
    l_iface_lines_rec       po.po_lines_interface%ROWTYPE;
    v_step                  VARCHAR2(100);
    v_curr_user_employee_id NUMBER;
    stop_processing EXCEPTION;
    v_error_code    NUMBER; ---0-success, 2-error
    v_error_message VARCHAR2(3000);
  
    l_return_status    VARCHAR2(1) := NULL;
    l_po_tbl_number    po_tbl_number := po_tbl_number();
    l_detailed_results po_fcout_type;
    l_po_return_code   VARCHAR2(2000);
  
  BEGIN
    v_step          := 'Step 0';
    x_error_code    := 0; ---success
    x_error_message := NULL;
  
    v_step := 'Step 10';
    ----Get Current user employee_id----
    SELECT fu.employee_id
      INTO v_curr_user_employee_id
      FROM fnd_user fu
     WHERE fu.user_id = fnd_global.user_id;
  
    v_step := 'Step 20';
    IF p_po_line_id IS NULL THEN
      x_error_code    := 2;
      x_error_message := 'Error in Handle_Po_Lines_Shipments: Missing parameter p_po_line_id';
      RAISE stop_processing;
    END IF;
    IF p_interface_header_id IS NULL THEN
      x_error_code    := 2;
      x_error_message := 'Error in Handle_Po_Lines_Shipments: Missing parameter p_interface_header_id';
      RAISE stop_processing;
    END IF;
  
    l_po_tbl_number.extend; ---*******EXTEND********
  
    FOR line_shipment_rec IN c_get_po_lines_shipments LOOP
      ----=============== PO LINES SHIPMENTS LOOP ==================================
      IF line_shipment_rec.encumbered_flag = 'Y' THEN
        ---This Shipment is Reserved----
        v_step := 'Step 50';
        ---=============== UNRESERVE ====================================
        ----message('Before Api DO_UNRESERVE');
        l_po_tbl_number(1) := line_shipment_rec.line_location_id;
        ---==== API ======
        v_step := 'Step 52';
        po_document_funds_grp.do_unreserve(p_api_version      => 1.0,
                                           p_init_msg_list    => fnd_api.g_true,
                                           p_commit           => fnd_api.g_true,
                                           x_return_status    => l_return_status, ----OUT
                                           p_doc_type         => 'PO',
                                           p_doc_subtype      => 'STANDARD',
                                           p_doc_level        => po_document_funds_pvt.g_doc_level_shipment, ---g_doc_level_header, ---var
                                           p_doc_level_id_tbl => l_po_tbl_number,
                                           p_employee_id      => fnd_global.employee_id, --1961, ---v_curr_user_employee_id,
                                           p_override_funds   => NULL, --var
                                           p_use_gl_date      => 'Y', ---var
                                           p_override_date    => SYSDATE, --date
                                           p_report_successes => NULL, --var
                                           x_po_return_code   => l_po_return_code, --varchar ---- OUT
                                           x_detailed_results => l_detailed_results); --out --po_fcout_type
      
        v_step := 'Step 55';
        IF l_return_status = 'S' THEN
          NULL;
        ELSE
          --capture the fact that Doc Mgr could not un-reserve the PO
          message('PO Shipment UNRESERVE ERROR  (PO#=' ||
                  line_shipment_rec.po_number || ', Old Line#=' ||
                  line_shipment_rec.old_line_num || ', Old Shipment#=' ||
                  line_shipment_rec.old_shipment_num || ')' ||
                  fnd_message.get);
          /* FOR i IN 1 .. l_detailed_results.error_msg.count LOOP
            message('****** UnReserve Error Msg line ' || i || ': ' ||
                    l_detailed_results.error_msg(i));
          END LOOP;*/
          x_error_code    := 2;
          x_error_message := 'PO Shipment UNRESERVE ERROR'; ---v_error_message;
          RAISE stop_processing;
        
        END IF;
      
      END IF; ---IF line_shipment_rec.encumbered_flag='Y' THEN
    
      v_step := 'Step 70';
      -------FILL NEW SHIPMENTS DEAILS (new po line details will be calculated by API)----------
      l_iface_lines_rec.interface_header_id := p_interface_header_id; --p-arameter
      SELECT po_lines_interface_s.nextval
        INTO l_iface_lines_rec.interface_line_id
        FROM dual;
      l_iface_lines_rec.line_num                      := line_shipment_rec.line_num; ---new-----
      l_iface_lines_rec.shipment_num                  := line_shipment_rec.shipment_num; ---new ----
      l_iface_lines_rec.line_type                     := line_shipment_rec.line_type; ---'Goods' for example
      l_iface_lines_rec.item                          := line_shipment_rec.item; ---- segment1
      l_iface_lines_rec.item_revision                 := line_shipment_rec.item_revision;
      l_iface_lines_rec.unit_of_measure               := line_shipment_rec.uom;
      l_iface_lines_rec.quantity                      := line_shipment_rec.new_shipment_qty; --new shipment qty
      l_iface_lines_rec.unit_price                    := line_shipment_rec.unit_price;
      l_iface_lines_rec.ship_to_organization_id       := line_shipment_rec.new_ship_to_organization_id; ---NEW-------------------
      l_iface_lines_rec.ship_to_location_id           := line_shipment_rec.ship_to_location_id; ---check in hz_locations.organi
      l_iface_lines_rec.promised_date                 := line_shipment_rec.shipment_promised_date;
      l_iface_lines_rec.need_by_date                  := line_shipment_rec.shipment_need_by_date;
      l_iface_lines_rec.line_attribute_category_lines := line_shipment_rec.attribute_category;
      l_iface_lines_rec.line_attribute1               := line_shipment_rec.attribute1;
      l_iface_lines_rec.line_attribute2               := line_shipment_rec.attribute2;
      l_iface_lines_rec.line_attribute3               := line_shipment_rec.attribute3;
      l_iface_lines_rec.line_attribute4               := line_shipment_rec.attribute4;
      l_iface_lines_rec.line_attribute5               := line_shipment_rec.attribute5;
      l_iface_lines_rec.line_attribute6               := line_shipment_rec.attribute6;
      l_iface_lines_rec.line_attribute7               := line_shipment_rec.attribute7;
      l_iface_lines_rec.line_attribute8               := line_shipment_rec.attribute8;
      l_iface_lines_rec.line_attribute9               := line_shipment_rec.attribute9;
      l_iface_lines_rec.line_attribute10              := line_shipment_rec.attribute10;
      l_iface_lines_rec.line_attribute11              := line_shipment_rec.attribute11;
      l_iface_lines_rec.line_attribute12              := line_shipment_rec.attribute12;
      l_iface_lines_rec.line_attribute13              := line_shipment_rec.attribute13;
      l_iface_lines_rec.line_attribute14              := line_shipment_rec.attribute14;
      l_iface_lines_rec.line_attribute15              := line_shipment_rec.attribute15;
    
      l_iface_lines_rec.shipment_attribute3 := line_shipment_rec.shipment_attribute3;
      l_iface_lines_rec.shipment_attribute4 := line_shipment_rec.shipment_attribute4;
    
      v_step := 'Step 75';
      INSERT INTO po_lines_interface VALUES l_iface_lines_rec;
      message('1 record was inserted into PO_LINES_INTERFACE ==== interface_line_id=' ||
              l_iface_lines_rec.interface_line_id || ', Line#=' ||
              line_shipment_rec.line_num || ', (Old Line#=' ||
              line_shipment_rec.old_line_num || '), Shipment#=' ||
              line_shipment_rec.shipment_num || ', (Old Shipment#=' ||
              line_shipment_rec.old_shipment_num || ', line_loc_id=' ||
              line_shipment_rec.line_location_id || ')');
      v_step := 'Step 80';
      UPDATE xxconv_po_log a
         SET a.interface_header_id = p_interface_header_id, ---parameter
             a.interface_line_id   = l_iface_lines_rec.interface_line_id
       WHERE a.po_line_id = p_po_line_id ---parameter
         AND a.po_line_location_id = p_po_line_location_id;
      message('UPDATE xxconv_po_log set interface_header_id=' ||
              p_interface_header_id || ', interface_line_id=' ||
              l_iface_lines_rec.interface_line_id);
    
      v_step := 'Step 100';
      handle_po_distribution(p_batch_id                    => p_batch_id,
                             p_new_ship_to_organization_id => line_shipment_rec.new_ship_to_organization_id,
                             p_po_line_location_id         => line_shipment_rec.line_location_id,
                             p_interface_header_id         => p_interface_header_id,
                             p_interface_line_id           => l_iface_lines_rec.interface_line_id,
                             x_error_code                  => v_error_code, ---0-success, 2-error
                             x_error_message               => v_error_message);
    
      IF v_error_code <> 0 THEN
        ---PO Distributions Processing ERROR-----
        x_error_code    := 2;
        x_error_message := v_error_message;
        RAISE stop_processing;
      END IF;
    
    ----=========the end of PO LINES SHIPMENTS LOOP ==============================
    END LOOP;
  EXCEPTION
    WHEN stop_processing THEN
      NULL;
    WHEN OTHERS THEN
      x_error_code    := 2;
      x_error_message := substr('Unexpected Error in  Handle_Po_Lines_Shipments (' ||
                                v_step || ') : ' || SQLERRM,
                                1,
                                200);
  END handle_po_lines_shipments;
  --------------------------------------------------------------------
  --  customization code: CUST695
  --  name:               handle_po_header
  --  create by:          Vitaly K.
  --  $Revision:          1.0 $
  --  creation date:      30/10/2013
  --  Purpose :
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   30/10/2013    Vitaly K.       initial build CR932
  ----------------------------------------------------------------------
  PROCEDURE handle_po_header(p_batch_id NUMBER,
                             p_org_id   NUMBER,
                             ----p_new_ship_to_organization_id NUMBER,
                             p_po_header_id        NUMBER,
                             p_po_number           NUMBER,
                             x_interface_header_id OUT NUMBER,
                             x_error_code          OUT NUMBER, ---0-success
                             x_error_message       OUT VARCHAR2) IS
    CURSOR c_get_po_lines IS
      SELECT po.po_line_id,
             po.old_line_num,
             ---po.line_num                    new_line_num,
             po.po_line_location_id,
             po.old_shipment_num,
             po.shipment_num new_shipment_num,
             po.new_ship_to_organization_id
        FROM xxconv_po_log po
       WHERE po.po_header_id = p_po_header_id ---parameter
         AND po.batch_id = p_batch_id ---parameter
         AND po.status = 'N'
       ORDER BY po.line_num, po.shipment_num;
  
    v_error_code    NUMBER; ---0-success, 2-error
    v_error_message VARCHAR2(3000);
    l_iface_rec     po.po_headers_interface%ROWTYPE;
    stop_processing EXCEPTION;
  BEGIN
    x_error_code    := 0; ---success
    x_error_message := NULL;
  
    IF p_batch_id IS NULL THEN
      x_error_code    := 2;
      x_error_message := 'Error in  Handle_Po_Header: Missing parameter p_batch_id';
      RAISE stop_processing;
    END IF;
    IF p_org_id IS NULL THEN
      x_error_code    := 2;
      x_error_message := 'Error in  Handle_Po_Header: Missing parameter p_org_id';
      RAISE stop_processing;
    END IF;
  
    l_iface_rec.org_id := p_org_id;
    SELECT po_headers_interface_s.nextval
      INTO l_iface_rec.interface_header_id
      FROM dual;
    l_iface_rec.process_code := 'PENDING';
    l_iface_rec.action       := 'UPDATE';
    -- l_iface_rec.document_type_code := i.type_lookup_code; ----'STANDARD' or 'BLANKET';
    l_iface_rec.document_num := p_po_number;
    l_iface_rec.po_header_id := p_po_header_id;
    --  l_iface_rec.revision_num          := i.revision_num;
    l_iface_rec.approval_status       := 'APPROVED';
    l_iface_rec.interface_source_code := 'Std_Cost_Conversion';
    l_iface_rec.batch_id              := p_batch_id;
    INSERT INTO po.po_headers_interface VALUES l_iface_rec;
    message('1 record was inserted into PO_HEADERS_INTERFACE ==== interface_header_id=' ||
            l_iface_rec.interface_header_id || ', po_header_id=' ||
            p_po_header_id || ', PO#=' || p_po_number);
  
    FOR line_rec IN c_get_po_lines LOOP
      ---=================== PO LINES LOOP ===============================
      handle_po_lines_shipments(p_batch_id            => p_batch_id,
                                p_po_line_id          => line_rec.po_line_id,
                                p_po_line_location_id => line_rec.po_line_location_id,
                                p_interface_header_id => l_iface_rec.interface_header_id,
                                x_error_code          => v_error_code, ---0-success, 2-error
                                x_error_message       => v_error_message);
    
      IF v_error_code <> 0 THEN
        ---PO Lines Shipments Processing ERROR-----
        x_error_code    := 2;
        x_error_message := v_error_message;
        RAISE stop_processing;
      END IF;
      ---===============the end of PO LINES LOOP ========================
    END LOOP;
  
    x_interface_header_id := l_iface_rec.interface_header_id;
  
  EXCEPTION
    WHEN stop_processing THEN
      x_interface_header_id := l_iface_rec.interface_header_id;
    WHEN OTHERS THEN
      x_interface_header_id := l_iface_rec.interface_header_id;
      x_error_code          := 2;
      x_error_message       := substr('Unexpected Error in  handle_po_header: ' ||
                                      SQLERRM,
                                      1,
                                      200);
  END handle_po_header;
  --------------------------------------------------------------------
  --  customization code: CUST695
  --  name:               check_import_errors
  --  create by:          Vitaly K.
  --  $Revision:          1.0 $
  --  creation date:      30/10/2013
  --  Purpose :
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   30/10/2013    Vitaly K.       initial build CR932
  ----------------------------------------------------------------------
  PROCEDURE check_import_errors(p_batch_id      NUMBER,
                                x_error_code    OUT NUMBER, ---0-success
                                x_error_message OUT VARCHAR2) IS
    CURSOR c_get_log_data IS
      SELECT DISTINCT polog.interface_header_id,
                      polog.interface_line_id,
                      polog.po_number,
                      polog.line_num
        FROM xxconv_po_log polog
       WHERE polog.batch_id = p_batch_id ---parameter
         AND polog.status <> 'E' --previous error
         AND polog.interface_header_id IS NOT NULL
         AND polog.interface_line_id IS NOT NULL;
  
    CURSOR c_get_import_errors(p_interface_header_id NUMBER,
                               p_interface_line_id   NUMBER) IS
      SELECT e.table_name || ' ' || e.error_message error_message
        FROM po_interface_errors e
       WHERE e.table_name = 'PO_HEADERS_INTERFACE'
         AND e.interface_header_id = p_interface_header_id --cursor parameter
         AND e.error_message IS NOT NULL
      UNION ALL
      SELECT e.table_name || ' ' || e.error_message
        FROM po_interface_errors e
       WHERE e.table_name = 'PO_LINES_INTERFACE'
         AND e.interface_header_id = p_interface_header_id --cursor parameter
         AND e.interface_line_id = p_interface_line_id --cursor parameter
         AND e.error_message IS NOT NULL
      UNION ALL
      SELECT error_tab.error_message
        FROM (SELECT listagg(err_tab.table_name || ' ' ||
                             err_tab.error_message,
                             ',') within GROUP(ORDER BY err_tab.table_name) error_message
                FROM (SELECT DISTINCT e.table_name, e.error_message
                        FROM po_interface_errors e
                       WHERE e.table_name IN
                             ('PO_LINE_LOCATIONS_INTERFACE',
                              'PO_DISTRIBUTIONS_INTERFACE')
                         AND e.interface_header_id = p_interface_header_id --cursor parameter
                         AND e.interface_line_id = p_interface_line_id --cursor parameter
                         AND e.error_message IS NOT NULL) err_tab) error_tab
       WHERE error_tab.error_message IS NOT NULL;
  
    stop_processing EXCEPTION;
    v_count_errors NUMBER := 0;
  
  BEGIN
    x_error_code    := 0; ---success
    x_error_message := NULL;
  
    IF p_batch_id IS NULL THEN
      x_error_code    := 2;
      x_error_message := 'Error in  Check_Import_Errors: Missing parameter p_batch_id';
      RAISE stop_processing;
    END IF;
  
    FOR log_data_rec IN c_get_log_data LOOP
      ---============== LOG LOOP ==========================
      FOR error_rec IN c_get_import_errors(p_interface_header_id => log_data_rec.interface_header_id,
                                           p_interface_line_id   => log_data_rec.interface_line_id) LOOP
        ---=============== IMPORT ERRORS LOOP ========================
        v_count_errors := v_count_errors + 1;
        IF v_count_errors = 1 THEN
          message('****************** SEE PO IMPORT ERRORS below **************************************************');
        END IF;
        UPDATE xxconv_po_log a
           SET a.status = 'E', a.error_message = error_rec.error_message
         WHERE a.batch_id = p_batch_id ---parameter
           AND a.interface_header_id = log_data_rec.interface_header_id
           AND a.interface_line_id =
               nvl(log_data_rec.interface_line_id, a.interface_line_id);
        message('****** PO#' || log_data_rec.po_number || ', new line#=' ||
                log_data_rec.line_num || ' Import Error: ' ||
                error_rec.error_message);
        ---==========the end of IMPORT ERRORS LOOP ===================
      END LOOP;
      ---===========the end of LOG LOOP =======================
    END LOOP;
  
    UPDATE xxconv_po_log a
       SET a.status = 'E'
     WHERE a.batch_id = p_batch_id ---parameter
       AND a.status = 'S'
       AND EXISTS
     (SELECT 1
              FROM xxconv_po_log a2
             WHERE a2.batch_id = a.batch_id
               AND a2.interface_header_id = a.interface_header_id
               AND a2.status = 'E');
  
    COMMIT; ---COMMIT---COMMIT---COMMIT----
  
    IF v_count_errors = 0 THEN
      message('************** NO PO IMPORT ERRORS ******************');
    END IF;
  
  EXCEPTION
    WHEN stop_processing THEN
      NULL;
    WHEN OTHERS THEN
      x_error_code    := 2;
      x_error_message := substr('Unexpected Error in  Check_Import_Errors: ' ||
                                SQLERRM,
                                1,
                                200);
  END check_import_errors;
  --------------------------------------------------------------------
  --  customization code: CUST695
  --  name:               update_req_distribution_id
  --  create by:          Vitaly K.
  --  $Revision:          1.0 $
  --  creation date:      30/10/2013
  --  Purpose :
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   30/10/2013    Vitaly K.       initial build CR932
  ----------------------------------------------------------------------
  PROCEDURE update_req_distribution_id(p_batch_id      NUMBER,
                                       x_error_code    OUT NUMBER, ---0-success
                                       x_error_message OUT VARCHAR2) IS
  
    CURSOR c_get_success_conv_po_headers IS
      SELECT DISTINCT polog.po_number, polog.po_header_id
        FROM xxconv_po_log polog
       WHERE polog.batch_id = p_batch_id ---parameter
         AND polog.status = 'S';
  
    CURSOR c_get_distribution_data(p_po_header_id NUMBER) IS
      SELECT old_dist_tab.new_line_num,
             old_dist_tab.new_shipment_num,
             old_dist_tab.distribution_num,
             ----new_dist_tab.rowid,
             old_dist_tab.req_distribution_id,
             new_dist_tab.new_po_distribution_id
        FROM (SELECT polog.line_num            new_line_num,
                     polog.shipment_num        new_shipment_num,
                     polog.po_line_location_id old_po_line_location_id,
                     d.distribution_num,
                     d.req_distribution_id
                FROM xxconv_po_log polog, xxconv_po_log_distributions d
               WHERE polog.batch_id = p_batch_id --parameter
                 AND polog.po_header_id = p_po_header_id --cursor parameter
                 AND polog.po_line_location_id = d.old_po_line_location_id
                 AND d.req_distribution_id IS NOT NULL
                 AND polog.batch_id = d.batch_id) old_dist_tab,
             (SELECT pl2.line_num          new_line_num,
                     pll2.shipment_num     new_shipment_num,
                     d2.distribution_num,
                     d2.line_location_id   new_line_location_id,
                     d2.po_distribution_id new_po_distribution_id ----,d2.rowid
                FROM fnd_lookup_values_vl  a,
                     po_distributions_all  d2,
                     po_line_locations_all pll2,
                     po_lines_all          pl2
               WHERE d2.po_header_id = p_po_header_id --cursor parameter
                 AND pll2.ship_to_organization_id = a.attribute1 -- new cost organization_id
                    ---p_new_ship_to_organization_id ---parameter
                 AND d2.line_location_id = pll2.line_location_id
                 AND pll2.po_line_id = pl2.po_line_id
                 AND a.lookup_type = 'XXCST_INV_ORG_REPLACE') new_dist_tab
       WHERE old_dist_tab.new_line_num = new_dist_tab.new_line_num
         AND old_dist_tab.new_shipment_num = new_dist_tab.new_shipment_num
         AND old_dist_tab.distribution_num = new_dist_tab.distribution_num
       ORDER BY old_dist_tab.new_line_num,
                old_dist_tab.new_shipment_num,
                old_dist_tab.distribution_num;
  
    stop_processing EXCEPTION;
  
  BEGIN
    x_error_code    := 0; ---success
    x_error_message := NULL;
  
    IF p_batch_id IS NULL THEN
      x_error_code    := 2;
      x_error_message := 'Error in  Update_Req_Distribution_Id: Missing parameter p_batch_id';
      RAISE stop_processing;
    END IF;
  
    FOR po_header_rec IN c_get_success_conv_po_headers LOOP
      ---============== HEADERS LOOP ==========================
      --- message('Update req_distribution_id for po_header_id=' ||
      ---        po_header_rec.po_header_id);
      FOR distribution_rec IN c_get_distribution_data(po_header_rec.po_header_id) LOOP
        ---============== DISTRIBUTIONS LOOP ==========================
        UPDATE po_distributions_all pod
           SET pod.req_distribution_id = distribution_rec.req_distribution_id ---from old po_distribution_id
         WHERE pod.po_distribution_id =
               distribution_rec.new_po_distribution_id; --NEW distribution      
      ---===========the end of HEADERS LOOP ===================
      END LOOP;
      ---===========the end of DISTRIBUTIONS LOOP ===================
    END LOOP;
  
    COMMIT; ---COMMIT---COMMIT---COMMIT----
  
  EXCEPTION
    WHEN stop_processing THEN
      NULL;
    WHEN OTHERS THEN
      x_error_code    := 2;
      x_error_message := substr('Unexpected Error in  Update_Req_Distribution_Id: ' ||
                                SQLERRM,
                                1,
                                200);
  END update_req_distribution_id;
  --------------------------------------------------------------------
  --  customization code: CUST695
  --  name:               cancel_requisition_line
  --  create by:          Vitaly K.
  --  $Revision:          1.0 $
  --  creation date:      18/12/2013
  --  Purpose :
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   18/12/2013    Vitaly K.       initial build CR932
  ----------------------------------------------------------------------
  FUNCTION cancel_requisition_line(p_batch_id          NUMBER,
                                   po_line_location_id NUMBER)
    RETURN VARCHAR2 IS
    ----RETURN 'S' --- Success
    ----RETURN error message ---Error
    CURSOR c_get_requisition_lines IS
      SELECT ---pord.requisition_line_id,
      ---porl.line_num,
       porl.requisition_header_id,
       porh.segment1,
       porh.preparer_id,
       podt.document_type_code,
       porh.type_lookup_code,
       ---MAX(porl_new.requisition_line_id) new_requisition_line_id, -- new requisition line will be created after Cancel Shipment
       ---MAX(porl_new.line_num) new_requisition_line_num
       porl_new.requisition_line_id new_requisition_line_id, -- new requisition line will be created after Cancel Shipment
       porl_new.line_num            new_requisition_line_num
        FROM xxobjt.xxconv_po_log_distributions d,
             po_req_distributions_all           pord,
             po_requisition_lines_all           porl,
             po_requisition_lines_all           porl_new, -- new requisition line will be created after Cancel Shipment
             po_requisition_headers_all         porh,
             po_document_types_all              podt
       WHERE d.batch_id = p_batch_id ---parameter
         AND d.old_po_line_location_id = po_line_location_id ---parameter
         AND d.req_distribution_id = pord.distribution_id
         AND pord.requisition_line_id = porl.requisition_line_id
         AND porh.requisition_header_id = porl.requisition_header_id
         AND porl.requisition_header_id = porl_new.requisition_header_id
         AND porl_new.line_location_id IS NULL -- new requisition line will be created after Cancel Shipment
         AND porl_new.last_update_date > SYSDATE - 1 / (24 * 12) --- 5 minutes
         AND porh.type_lookup_code = podt.document_subtype
         AND porh.org_id = podt.org_id;
    /*GROUP BY pord.requisition_line_id,
              porl.line_num,
              porl.requisition_header_id,
              porh.segment1,
              porh.preparer_id,
              podt.document_type_code,
              porh.type_lookup_code
    HAVING MAX(porl_new.requisition_line_id) IS NOT NULL;*/
  
    x_req_control_error_rc  VARCHAR2(500);
    v_error_msg             VARCHAR2(500);
    v_new_req_lines_counter NUMBER := 0;
  BEGIN
  
    FOR requisition_line_rec IN c_get_requisition_lines LOOP
      ---=============== requisition_lines LOOP ============================
      v_new_req_lines_counter := v_new_req_lines_counter + 1;
      po_reqs_control_sv.update_reqs_status(x_req_header_id      => requisition_line_rec.requisition_header_id, ---- 176505
                                            x_req_line_id        => requisition_line_rec.new_requisition_line_id, ---227973
                                            x_agent_id           => requisition_line_rec.preparer_id, ---941
                                            x_req_doc_type       => requisition_line_rec.document_type_code, --'REQUISITION',
                                            x_req_doc_subtype    => requisition_line_rec.type_lookup_code, ---'PURCHASE',
                                            x_req_control_action => 'CANCEL',
                                            x_req_control_reason => 'Std Cost',
                                            x_req_action_date    => SYSDATE,
                                            x_encumbrance_flag   => 'N',
                                            x_oe_installed_flag  => 'N', ---'Y', 
                                            
                                            x_req_control_error_rc => x_req_control_error_rc);
      COMMIT;
      IF x_req_control_error_rc IS NOT NULL THEN
        ---Cancellation ERROR---
        v_error_msg := 'ERROR when Cancel New Requisition line_num= ' ||
                       requisition_line_rec.new_requisition_line_num ||
                       ', requisition#=' || requisition_line_rec.segment1 ||
                       ' : ' || x_req_control_error_rc;
        -----message(v_error_msg);
        RETURN v_error_msg;
      ELSE
        ---Cancelled Successfully----
        NULL;
      END IF;
      ---==============the end of requisition_lines LOOP ===================
    END LOOP;
    IF v_new_req_lines_counter = 0 THEN
      RETURN 'No Cancelled Requisition Line';
    END IF;
    RETURN 'S';
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 'Unexpected Error when cancelling requisition line';
  END cancel_requisition_line;
  --------------------------------------------------------------------
  --  customization code: CUST695
  --  name:               convert_po
  --  create by:          Vitaly K.
  --  $Revision:          1.0 $
  --  creation date:      30/10/2013
  --  Purpose :
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   30/10/2013    Vitaly K.       initial build CR932
  ----------------------------------------------------------------------
  PROCEDURE convert_po(errbuf         OUT VARCHAR2,
                       retcode        OUT VARCHAR2,
                       p_org_id       IN NUMBER,
                       p_user_id      IN NUMBER,
                       p_resp_id      IN NUMBER,
                       p_resp_appl_id IN NUMBER,
                       p_po_number    IN VARCHAR2) IS
  
    CURSOR c_get_po_headers(p_batch_id NUMBER) IS
      SELECT DISTINCT po.org_id, po.po_number, po.po_header_id
        FROM xxconv_po_log po
       WHERE po.status = 'N'
         AND po.batch_id = p_batch_id --- cursor parameter
         AND po.org_id = p_org_id --- parameter
         AND po.po_number = nvl(p_po_number, po.po_number); --- parameter
  
    v_step                         VARCHAR2(100);
    v_error_code                   NUMBER; ---0-success, 2-error
    v_error_message                VARCHAR2(3000);
    v_return_status                VARCHAR2(100);
    v_interface_header_id          NUMBER;
    num_of_headers_in_open_interf  NUMBER;
    num_of_lines_in_open_interface NUMBER;
    num_of_distr_in_open_interface NUMBER;
    stop_processing           EXCEPTION;
    stop_and_exit             EXCEPTION;
    no_data_in_open_interface EXCEPTION;
  
    v_batch_id NUMBER := xxconv_po_log_seq.nextval;
  
    ------
    v_concurrent_request_id NUMBER;
    ---- out variables for fnd_concurrent.wait_for_request-----
    x_phase       VARCHAR2(100);
    x_status      VARCHAR2(100);
    x_dev_phase   VARCHAR2(100);
    x_dev_status  VARCHAR2(100);
    x_return_bool BOOLEAN;
    x_message     VARCHAR2(100);
  
    l_po_tbl_number    po_tbl_number := po_tbl_number();
    l_detailed_results po_fcout_type;
    l_po_return_code   VARCHAR2(2000);
  
    ---variables for po_change_api1_s.update_po API (for RE-APPROVAL)
    v_previous_po_header_id NUMBER;
    ---v_need_re_approval_flag VARCHAR2(100);
    v_result     NUMBER;
    v_api_errors po_api_errors_rec_type;
  
  BEGIN
    v_step  := 'Step 0';
    errbuf  := 'Success';
    retcode := '0';
  
    IF nvl(fnd_profile.value('XXPO_CONV_AUTO_APPROVAL'), 'N') = 'N' THEN
      RAISE stop_and_exit;
    END IF;
  
    IF p_org_id IS NULL THEN
      ---error
      v_error_message := 'ERROR in Convert_Po procedure: Missing p_org_id parameter';
      RAISE stop_processing;
    END IF;
  
    v_step := 'Step 30';
  
    v_step := 'Step 40';
    -- intiialize applications information
    fnd_global.apps_initialize(p_user_id, p_resp_id, p_resp_appl_id);
    /*fnd_global.apps_initialize(5490, ---TAMAR.FRIEDMAN   3850, --Yuval----V_USER_ID,
    50877, ----V_RESPONSIBILITY_ID,
    201 ---V_RESPONSIBILITY_APPL_ID
    );*/
  
    mo_global.init('PO');
  
    message('batch_id=' || v_batch_id || '===========================');
    message('p_org_id=' || p_org_id || '===========================');
    message('p_user_id=' || p_user_id ||
            '=========== fnd_global.employee_id=' ||
            fnd_global.employee_id);
    message('p_resp_id=' || p_resp_id || '===========================');
    message('p_resp_appl_id=' || p_resp_appl_id ||
            '===========================');
    message('p_po_number=' || p_po_number || '===========================');
    ---Insert po data (for a given p_org_id) into log table-------------
    v_step := 'Step 70';
    fill_log_table(p_batch_id      => v_batch_id,
                   p_org_id        => p_org_id,
                   p_po_number     => p_po_number,
                   x_error_code    => v_error_code, ---0-success, 2-error
                   x_error_message => v_error_message);
    IF v_error_code <> 0 THEN
      --- Unexpected error in Fill_Log_Table-----
      RAISE stop_processing;
    END IF;
  
    ---Validate all PO inserted into log table for this batch_id-------------
    v_step := 'Step 80';
    po_data_validations(p_batch_id      => v_batch_id,
                        x_error_code    => v_error_code, ---0-success, 2-error
                        x_error_message => v_error_message);
    IF v_error_code <> 0 THEN
      --- Unexpected error in check_all_po-----
      RAISE stop_processing;
    END IF;
  
    v_step := 'Step 300';
    FOR po_header_rec IN c_get_po_headers(v_batch_id) LOOP
      ---====================== PO HEADERS LOOP =================================
      -- Insert Date into PO Open Interface Tables------
      handle_po_header(p_batch_id            => v_batch_id,
                       p_org_id              => po_header_rec.org_id,
                       p_po_header_id        => po_header_rec.po_header_id,
                       p_po_number           => po_header_rec.po_number,
                       x_interface_header_id => v_interface_header_id, --out
                       x_error_code          => v_error_code, ---0-success, 2-error
                       x_error_message       => v_error_message);
      IF v_error_code = 0 THEN
        ----Success----------------
        UPDATE xxconv_po_log a
           SET a.status = 'S', a.last_update_date = SYSDATE
         WHERE a.po_header_id = po_header_rec.po_header_id
           AND a.batch_id = v_batch_id
           AND a.status = 'N'; ---no validation error
        COMMIT;
      ELSE
        ----Unexpected Error in Handle_Po_Header----
        ROLLBACK;
        message('Unexpected ERROR in Handle_Po_Header: ' ||
                v_error_message);
        UPDATE xxconv_po_log a
           SET a.status           = 'E',
               a.error_message    = v_error_message,
               a.last_update_date = SYSDATE
         WHERE a.po_header_id = po_header_rec.po_header_id
           AND a.batch_id = v_batch_id;
        COMMIT;
      END IF;
      ---============== the end of PO HEADERS LOOP ==============================
    END LOOP;
  
    COMMIT; ---- COMMIT ---- COMMIT ---- COMMIT ----
  
    ---Does data in Open Interface Tables exist for this batch------
    SELECT COUNT(1)
      INTO num_of_headers_in_open_interf
      FROM po_headers_interface pohi
     WHERE pohi.batch_id = v_batch_id
       AND nvl(pohi.document_type_code, 'ZZZZZZZ') <> 'QUOTATION'
       AND pohi.interface_source_code = 'Std_Cost_Conversion';
    SELECT COUNT(1)
      INTO num_of_lines_in_open_interface
      FROM po_lines_interface poli
     WHERE poli.interface_header_id IN
           (SELECT pohi.interface_header_id
              FROM po_headers_interface pohi
             WHERE pohi.batch_id = v_batch_id
               AND nvl(pohi.document_type_code, 'ZZZZZZZ') <> 'QUOTATION'
               AND pohi.interface_source_code = 'Std_Cost_Conversion');
    SELECT COUNT(1)
      INTO num_of_distr_in_open_interface
      FROM po_distributions_interface podi
     WHERE podi.interface_header_id IN
           (SELECT pohi.interface_header_id
              FROM po_headers_interface pohi
             WHERE pohi.batch_id = v_batch_id
               AND nvl(pohi.document_type_code, 'ZZZZZZZ') <> 'QUOTATION'
               AND pohi.interface_source_code = 'Std_Cost_Conversion');
  
    IF num_of_headers_in_open_interf = 0 THEN
      v_error_message := 'No Data Inserted Into Open Interface Tables';
      message(v_error_message);
      RAISE no_data_in_open_interface;
    ELSE
      message(num_of_headers_in_open_interf || ' PO Headers, ' ||
              num_of_lines_in_open_interface || ' PO Lines, ' ||
              num_of_distr_in_open_interface ||
              ' PO Distributions--- are Successfully INSERTED into PO Open Interface');
    END IF;
  
    --===================== SUBMIT RERQUEST ===================================
    v_step := 'Step 400';
    ---Submit concurrent program 'Import Standard Purchase Orders' / POXPOPDOI-------------------
    x_return_bool := fnd_request.set_print_options(NULL, NULL, 0, TRUE, 'N');
  
    v_concurrent_request_id := fnd_request.submit_request(application => 'PO',
                                                          program     => 'POXPOPDOI', ---Import Standard Purchase Orders
                                                          argument1   => NULL, ---Default Buyer
                                                          argument2   => 'STANDARD', ----Document Type
                                                          argument3   => NULL, ---Document SubType
                                                          argument4   => 'N', -----Create or Update Items
                                                          argument5   => NULL, -----Create Sourcing Rules
                                                          argument6   => 'APPROVED', -----Approval Status
                                                          argument7   => NULL, ---Release Generation Method
                                                          argument8   => v_batch_id, ---Batch Id
                                                          argument9   => NULL, ---Operating Unit
                                                          argument10  => NULL, ---Global Agreement
                                                          argument11  => NULL, ---Enable Sourcing Level
                                                          argument12  => NULL, ---Sourcing Level
                                                          argument13  => NULL, ---Inv Org Enable
                                                          argument14  => NULL ---, ---Inventory Organization
                                                          ---argument15  => NULL, ---Batch Size  --in PATCH only
                                                          ---argument16  => 'N' ---Gather Stats --in PATCH only
                                                          );
  
    COMMIT;
  
    v_step := 'Step 410';
    IF v_concurrent_request_id > 0 THEN
      message('Concurrent ''Import Standard Purchase Orders'' was SUBMITTED successfully (request_id=' ||
              v_concurrent_request_id || ')');
      ---------
      LOOP
        x_return_bool := fnd_concurrent.wait_for_request(v_concurrent_request_id,
                                                         5, --- interval 5  seconds
                                                         3600, ---- max wait 1 hour
                                                         x_phase,
                                                         x_status,
                                                         x_dev_phase,
                                                         x_dev_status,
                                                         x_message);
        EXIT WHEN x_return_bool AND upper(x_dev_phase) = 'COMPLETE';
      
      END LOOP;
      IF upper(x_dev_phase) = 'COMPLETE' AND
         upper(x_dev_status) IN ('ERROR', 'WARNING') THEN
        v_error_message := 'Concurrent ''Import Standard Purchase Orders'' concurrent program completed in ' ||
                           upper(x_dev_status) ||
                           '. See log for request_id=' ||
                           v_concurrent_request_id;
        message(v_error_message);
        message('==========================================================================================');
        message('=====================Error log for cst import ============================================');
        message('=item=======organization====error code=========== explanation=============================');
        retcode := '2';
        RAISE stop_processing;
      ELSIF upper(x_dev_phase) = 'COMPLETE' AND
            upper(x_dev_status) = 'NORMAL' THEN
        message('Concurrent ''Import Standard Purchase Orders'' was SUCCESSFULLY COMPLETED (request_id=' ||
                v_concurrent_request_id || ')');
      ELSE
        v_error_message := 'Concurrent ''Import Standard Purchase Orders'' failed , review log (request_id=' ||
                           v_concurrent_request_id || ')';
        message(v_error_message);
        retcode := '2';
        RAISE stop_processing;
      END IF;
    ELSE
      message('Concurrent ''Import Standard Purchase Orders'' submitting PROBLEM');
      errbuf  := 'Concurrent ''Import Standard Purchase Orders'' submitting PROBLEM';
      retcode := '2';
    END IF;
  
    v_step := 'Step 500';
    ----Check 'Import Standard Purchase Orders' Results and update XXCONV_PO_LOG.status-------
    check_import_errors(p_batch_id      => v_batch_id,
                        x_error_code    => v_error_code, ---0-success, 2-error
                        x_error_message => v_error_message);
    IF v_error_code <> 0 THEN
      ----Unexpected Error in check_import_errors----
      RAISE stop_processing;
    END IF;
  
    ----------------------------
    ---- Cancel shipment level---(cancel old shipments after successfully import)
    ---------------------------
    v_step := 'Step 600';
    FOR po_shipments_rec IN (SELECT polog.org_id,
                                    polog.po_header_id,
                                    polog.po_line_id,
                                    polog.po_line_location_id,
                                    polog.po_number,
                                    polog.old_line_num,
                                    polog.old_shipment_num
                               FROM xxconv_po_log polog
                              WHERE polog.batch_id = v_batch_id
                                AND polog.status = 'S'
                                AND polog.interface_header_id IS NOT NULL
                              ORDER BY polog.po_line_location_id) LOOP
      ---======================= CANCEL old PO_LINE_LOCATIONS LOOP ======================
      fnd_msg_pub.initialize;
      v_error_message := NULL;
      po_document_control_pub.control_document(p_api_version      => 1.0, -- p_api_version
                                               p_init_msg_list    => fnd_api.g_true, -- p_init_msg_list
                                               p_commit           => fnd_api.g_true, -- p_commit
                                               x_return_status    => v_return_status, -- x_return_status
                                               p_doc_type         => 'PO', -- p_doc_type
                                               p_doc_subtype      => 'STANDARD', -- p_doc_subtype
                                               p_doc_id           => po_shipments_rec.po_header_id,
                                               p_doc_num          => NULL,
                                               p_release_id       => NULL,
                                               p_release_num      => NULL,
                                               p_doc_line_id      => po_shipments_rec.po_line_id,
                                               p_doc_line_num     => NULL,
                                               p_doc_line_loc_id  => po_shipments_rec.po_line_location_id,
                                               p_doc_shipment_num => NULL,
                                               p_action           => 'CANCEL',
                                               p_action_date      => SYSDATE,
                                               p_cancel_reason    => 'Std_Cost Conversion ',
                                               p_cancel_reqs_flag => 'N',
                                               p_print_flag       => NULL,
                                               p_note_to_vendor   => NULL,
                                               p_use_gldate       => NULL,
                                               
                                               p_org_id => po_shipments_rec.org_id);
      COMMIT;
      dbms_lock.sleep(2);
      ---message('Cancel po API RETURN STATUS IS-' || l_return_status);
      IF v_return_status = 'S' THEN
        ------Old PO Shipment was SUCCESSFULLY CANCELLED
        NULL;
        ---Cancel Requisition Lines----
        v_error_message := cancel_requisition_line(p_batch_id          => v_batch_id,
                                                   po_line_location_id => po_shipments_rec.po_line_location_id);
        IF v_error_message = 'S' THEN
          ---Cancelled Successfully---
          NULL;
        ELSE
          ---Error when Cancell..
          message('ERROR when CANCELLING Requisition Line---- PO#=' ||
                  po_shipments_rec.po_number || ', Old Line#=' ||
                  po_shipments_rec.old_line_num || ', Old Shipment#=' ||
                  po_shipments_rec.old_shipment_num || '----' ||
                  v_error_message);
          UPDATE xxconv_po_log a
             SET a.error_message = 'ERROR when CANCELLING Requisition Line----' ||
                                   v_error_message
           WHERE a.batch_id = v_batch_id -----
             AND a.po_line_location_id =
                 po_shipments_rec.po_line_location_id; ------
          COMMIT;
        END IF;
      ELSE
        FOR j IN 1 .. fnd_msg_pub.count_msg LOOP
          v_error_message := v_error_message ||
                             fnd_msg_pub.get(p_msg_index => j,
                                             p_encoded   => 'F');
        END LOOP;
        v_error_message := 'The PO Shipment (PO#=' ||
                           po_shipments_rec.po_number || ', Old Line#=' ||
                           po_shipments_rec.old_line_num ||
                           ', Old Shipment#=' ||
                           po_shipments_rec.old_shipment_num ||
                           ') Failed to Cancel: ' || v_error_message;
        message(v_error_message);
        UPDATE xxconv_po_log a
           SET a.status           = 'E',
               a.error_message    = v_error_message,
               a.last_update_date = SYSDATE
         WHERE a.po_header_id = po_shipments_rec.po_header_id
              ---AND a.po_line_id = po_shipments_rec.po_line_id  ---ASK YAIR
              ---AND a.po_line_location_id = po_shipments_rec.po_line_location_id ---ASK YAIR
           AND a.batch_id = v_batch_id;
        COMMIT;
        ----RAISE stop_processing;
      END IF;
      ---==============the end of CANCEL old PO_LINE_LOCATIONS ======================
    END LOOP;
  
    ----Update new distributions (created in this conversion) ..Set PO_DISTRIBUTIONS_ALL.req_distribution_id = old distribution req_distribution_id
    v_step := 'Step 650';
    update_req_distribution_id(p_batch_id      => v_batch_id,
                               x_error_code    => v_error_code, ---0-success, 2-error
                               x_error_message => v_error_message);
    IF v_error_code <> 0 THEN
      ----Unexpected Error in update_req_distribution_id----
      RAISE stop_processing;
    END IF;
  
    ------------------------------------
    ----- RESERVE HEADER -- all
    ------------------------------------
    v_step          := 'Step 700';
    v_error_message := NULL;
    l_po_tbl_number.extend;
    FOR po_rec IN (SELECT DISTINCT polog.po_header_id, polog.po_number
                     FROM xxconv_po_log polog
                    WHERE polog.batch_id = v_batch_id
                      AND polog.status = 'S'
                      AND polog.do_reserve_flag = 1) LOOP
      ---======================= RESERVE PO LOOP ======================
      v_step := 'Step 710';
      l_po_tbl_number(1) := po_rec.po_header_id; ----i.line_location_id;
    
      ---======== API ==============================================
      po_document_funds_grp.do_reserve(p_api_version          => 1.0,
                                       p_init_msg_list        => fnd_api.g_true,
                                       p_commit               => fnd_api.g_true,
                                       x_return_status        => v_return_status, ----OUT
                                       p_doc_type             => 'PO',
                                       p_doc_subtype          => 'STANDARD',
                                       p_doc_level            => po_document_funds_pvt.g_doc_level_header, ---var
                                       p_doc_level_id_tbl     => l_po_tbl_number,
                                       p_prevent_partial_flag => NULL, ---ASK
                                       p_employee_id          => fnd_global.employee_id, --number --- YUVAL
                                       p_override_funds       => NULL, --var
                                       p_report_successes     => NULL, --var
                                       x_po_return_code       => l_po_return_code, --varchar ---- OUT
                                       x_detailed_results     => l_detailed_results); --out --po_fcout_type
    
      v_step := 'Step 705';
    
      IF v_return_status = 'S' THEN
        ---message('PO#=' || po_rec.po_number || ' was SUCCESSFULLY RESERVED');
        NULL;
      ELSE
        v_error_message := 'PO#=' || po_rec.po_number ||
                           ' ---- try RESERVE ---ERROR';
        message(v_error_message);
        --capture the fact that Doc Mgr could not reserve the PO
        /*  ---ASK YUVAL ABOUT ERROR ---- ORA-06531: Reference to uninitialized collection
        FOR i IN 1 .. l_detailed_results.error_msg.count LOOP
          v_error_message := v_error_message || 'Reserve PO Error- Line ' || i || ': ' ||
                             l_detailed_results.error_msg(i);
          message('****** Reserve PO Error- Line ' || i || ': ' ||
                  l_detailed_results.error_msg(i));
        END LOOP;*/
        ----RAISE stop_processing;
        UPDATE xxconv_po_log a
           SET a.status           = 'E',
               a.error_message    = v_error_message,
               a.last_update_date = SYSDATE
         WHERE a.po_header_id = po_rec.po_header_id
           AND a.batch_id = v_batch_id;
        COMMIT;
      
      END IF;
    END LOOP;
    ----------------------------
    --- Send to approve
    ----------------------------
    ---v_need_re_approval_flag := 'Y';
    v_previous_po_header_id := -1;
    v_error_message         := NULL;
    FOR po_rec IN (SELECT polog.org_id,
                          polog.po_number,
                          polog.po_header_id,
                          polog.revision_num + 1 new_revision_num,
                          polog.line_num new_line_num,
                          polog.shipment_num new_shipment_num,
                          polog.shipment_need_by_date,
                          polog.shipment_promised_date
                     FROM xxconv_po_log polog
                    WHERE polog.batch_id = v_batch_id
                      AND polog.status = 'S') LOOP
      ---======================= RE-APPROVE PO LOOP ======================
      IF v_previous_po_header_id <> po_rec.po_header_id THEN
        ----Firs shipping for this PO -------------
        v_step   := 'Step 800';
        v_result := po_change_api1_s.update_po(x_po_number           => po_rec.po_number, --Enter the PO Number
                                               x_release_number      => to_number(NULL),
                                               x_revision_number     => po_rec.new_revision_num,
                                               x_line_number         => po_rec.new_line_num,
                                               x_shipment_number     => po_rec.new_shipment_num,
                                               new_quantity          => NULL, ---l_quantity,
                                               new_price             => NULL, ---l_price,
                                               new_promised_date     => CASE
                                                                         po_rec.shipment_need_by_date
                                                                          WHEN NULL THEN
                                                                           trunc(po_rec.shipment_promised_date) +
                                                                           1 / 24
                                                                          ELSE
                                                                           NULL
                                                                        END, ---l_promised_date,
                                               new_need_by_date      => trunc(po_rec.shipment_need_by_date) +
                                                                        1 / 24,
                                               launch_approvals_flag => 'Y', --- RE_APPROVAL request here?!
                                               update_source         => NULL,
                                               version               => '1.0',
                                               x_override_date       => NULL,
                                               x_api_errors          => v_api_errors,
                                               --  p_buyer_name          => NULL,
                                               p_secondary_quantity => NULL,
                                               p_preferred_grade    => NULL,
                                               p_org_id             => po_rec.org_id);
        IF (v_result = 1) THEN
          -----PO# was SUCCESSFULLY Updated (RE_APPROVAL request success)
          COMMIT;
        ELSE
          v_error_message := 'PO#=' || po_rec.po_number ||
                             ' Update ERROR (RE_APPROVAL request failed)';
          /*-- Display the errors
          FOR j IN 1 .. v_api_errors.message_text.count LOOP
            v_error_message := v_error_message || ' ' ||
                               v_api_errors.message_text(j);
          END LOOP;*/
          UPDATE xxconv_po_log a
             SET a.status           = 'E',
                 a.error_message    = v_error_message,
                 a.last_update_date = SYSDATE
           WHERE a.po_number = po_rec.po_number
             AND a.batch_id = v_batch_id;
          COMMIT;
          message(v_error_message);
        
        END IF;
        v_previous_po_header_id := po_rec.po_header_id;
      END IF;
    END LOOP;
  
    message('************** PROGRAM WAS COMPLETED *************************');
  
  EXCEPTION
    WHEN stop_and_exit THEN
      errbuf  := 'Profile XXPO_CONV_AUTO_APPROVAL != Y , program aborted';
      retcode := '1';
    WHEN no_data_in_open_interface THEN
      errbuf  := v_error_message;
      retcode := '1';
    WHEN stop_processing THEN
      message(v_error_message);
      errbuf  := v_error_message;
      retcode := '2';
      ROLLBACK;
    WHEN OTHERS THEN
      message('Unexpected Error in procedure xxconv_il_purchasing_pkg.convert_po ' ||
              v_step || ': ' || SQLERRM);
      errbuf  := 'Unexpected Error in procedure xxconv_il_purchasing_pkg.convert_po ' ||
                 v_step || ': ' || SQLERRM;
      retcode := '2';
      ROLLBACK;
  END convert_po;
  --------------------------------------------------------------------
  --  customization code: CUST695
  --  name:               cancel_so_lines_internal
  --  create by:          Vitaly K.
  --  $Revision:          1.0 $
  --  creation date:      30/10/2013
  --  Purpose :
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   30/10/2013    Vitaly K.       initial build CR998
  ----------------------------------------------------------------------
  PROCEDURE cancel_so_lines_internal(p_so_header_id  IN NUMBER,
                                     p_user_id       IN NUMBER,
                                     p_so_org_id     IN NUMBER,
                                     p_return_status OUT VARCHAR2,
                                     p_error_message OUT VARCHAR2) IS
  
    CURSOR a1 IS
      SELECT ola.line_id, ola.header_id, ola.ordered_quantity
        FROM oe_order_lines_all ola
       WHERE ola.open_flag = 'Y'
         AND nvl(ola.cancelled_flag, 'N') = 'N'
         AND ola.header_id = p_so_header_id;
  
    v_api_version_number NUMBER := 1.0;
    v_return_status      VARCHAR2(2000);
    v_msg_count          NUMBER;
    v_msg_data           VARCHAR2(2000);
    l_sequnce            NUMBER;
    v_error_message      VARCHAR2(3000);
    v_step               VARCHAR2(100);
    v_resp_id            NUMBER;
    -- IN Variables --
    v_header_rec         oe_order_pub.header_rec_type;
    v_line_tbl           oe_order_pub.line_tbl_type;
    v_action_request_tbl oe_order_pub.request_tbl_type;
    v_line_adj_tbl       oe_order_pub.line_adj_tbl_type;
  
    -- OUT Variables --
    v_header_rec_out             oe_order_pub.header_rec_type;
    v_header_val_rec_out         oe_order_pub.header_val_rec_type;
    v_header_adj_tbl_out         oe_order_pub.header_adj_tbl_type;
    v_header_adj_val_tbl_out     oe_order_pub.header_adj_val_tbl_type;
    v_header_price_att_tbl_out   oe_order_pub.header_price_att_tbl_type;
    v_header_adj_att_tbl_out     oe_order_pub.header_adj_att_tbl_type;
    v_header_adj_assoc_tbl_out   oe_order_pub.header_adj_assoc_tbl_type;
    v_header_scredit_tbl_out     oe_order_pub.header_scredit_tbl_type;
    v_header_scredit_val_tbl_out oe_order_pub.header_scredit_val_tbl_type;
    v_line_tbl_out               oe_order_pub.line_tbl_type;
    v_line_val_tbl_out           oe_order_pub.line_val_tbl_type;
    v_line_adj_tbl_out           oe_order_pub.line_adj_tbl_type;
    v_line_adj_val_tbl_out       oe_order_pub.line_adj_val_tbl_type;
    v_line_price_att_tbl_out     oe_order_pub.line_price_att_tbl_type;
    v_line_adj_att_tbl_out       oe_order_pub.line_adj_att_tbl_type;
    v_line_adj_assoc_tbl_out     oe_order_pub.line_adj_assoc_tbl_type;
    v_line_scredit_tbl_out       oe_order_pub.line_scredit_tbl_type;
    v_line_scredit_val_tbl_out   oe_order_pub.line_scredit_val_tbl_type;
    v_lot_serial_tbl_out         oe_order_pub.lot_serial_tbl_type;
    v_lot_serial_val_tbl_out     oe_order_pub.lot_serial_val_tbl_type;
    v_action_request_tbl_out     oe_order_pub.request_tbl_type;
  
  BEGIN
    v_step := 'Step 0';
  
    SELECT r.level_id
      INTO v_resp_id
      FROM xxobjt_profiles_v r
     WHERE r.profile_name LIKE 'MO: Operating Unit'
       AND r.level_id IN
           (SELECT u.responsibility_id
              FROM fnd_responsibility_tl u
             WHERE u.language = 'US'
               AND u.responsibility_name LIKE 'OM%SuperUser%')
       AND r.profile_value = p_so_org_id; ---parameter
  
    v_step := 'Step 5';
    fnd_global.apps_initialize(user_id      => p_user_id,
                               resp_id      => v_resp_id, ---'OM%SuperUser%'
                               resp_appl_id => 660); --- Order Management
    mo_global.init(p_appl_short_name => 'ONT');
    mo_global.set_policy_context('S', p_so_org_id); ---parameter
  
    l_sequnce := 0;
  
    v_header_rec_out := oe_order_pub.g_miss_header_rec;
    v_line_tbl.delete;
    -- v_line_tbl := oe_order_pub.G_MISS_LINE_TBL;
  
    FOR l1 IN a1 LOOP
      v_step    := 'Step 10';
      l_sequnce := l_sequnce + 1;
      -- Line Record --
      v_line_tbl(l_sequnce) := oe_order_pub.g_miss_line_rec;
      v_line_tbl(l_sequnce).operation := oe_globals.g_opr_update;
      v_line_tbl(l_sequnce).line_id := l1.line_id;
      v_line_tbl(l_sequnce).change_reason := 'Not provided'; --Administrative Reason
      v_line_tbl(l_sequnce).cancelled_flag := 'Y';
      v_line_tbl(l_sequnce).cancelled_quantity := l1.ordered_quantity;
      v_line_tbl(l_sequnce).open_flag := 'N';
      v_line_tbl(l_sequnce).ordered_quantity := 0;
      oe_msg_pub.delete_msg;
      -- COMMIT;
    END LOOP;
  
    v_step := 'Step 20';
    oe_order_pub.process_order(p_init_msg_list      => fnd_api.g_true,
                               p_api_version_number => v_api_version_number,
                               p_header_rec         => v_header_rec,
                               p_line_tbl           => v_line_tbl,
                               p_action_request_tbl => v_action_request_tbl,
                               p_line_adj_tbl       => v_line_adj_tbl,
                               -- OUT variables
                               x_header_rec             => v_header_rec_out,
                               x_header_val_rec         => v_header_val_rec_out,
                               x_header_adj_tbl         => v_header_adj_tbl_out,
                               x_header_adj_val_tbl     => v_header_adj_val_tbl_out,
                               x_header_price_att_tbl   => v_header_price_att_tbl_out,
                               x_header_adj_att_tbl     => v_header_adj_att_tbl_out,
                               x_header_adj_assoc_tbl   => v_header_adj_assoc_tbl_out,
                               x_header_scredit_tbl     => v_header_scredit_tbl_out,
                               x_header_scredit_val_tbl => v_header_scredit_val_tbl_out,
                               x_line_tbl               => v_line_tbl_out,
                               x_line_val_tbl           => v_line_val_tbl_out,
                               x_line_adj_tbl           => v_line_adj_tbl_out,
                               x_line_adj_val_tbl       => v_line_adj_val_tbl_out,
                               x_line_price_att_tbl     => v_line_price_att_tbl_out,
                               x_line_adj_att_tbl       => v_line_adj_att_tbl_out,
                               x_line_adj_assoc_tbl     => v_line_adj_assoc_tbl_out,
                               x_line_scredit_tbl       => v_line_scredit_tbl_out,
                               x_line_scredit_val_tbl   => v_line_scredit_val_tbl_out,
                               x_lot_serial_tbl         => v_lot_serial_tbl_out,
                               x_lot_serial_val_tbl     => v_lot_serial_val_tbl_out,
                               x_action_request_tbl     => v_action_request_tbl_out,
                               x_return_status          => v_return_status,
                               x_msg_count              => v_msg_count,
                               x_msg_data               => v_msg_data);
  
    v_step := 'Step 30';
    IF v_return_status = fnd_api.g_ret_sts_success THEN
      COMMIT;
      p_return_status := 'S';
    ELSE
      ----dbms_output.put_line('Update Line failed:' || v_msg_data);
      ROLLBACK;
      v_error_message := NULL;
      FOR i IN 1 .. v_msg_count LOOP
        v_msg_data := oe_msg_pub.get(p_msg_index => i, p_encoded => 'F');
        ---dbms_output.put_line(i || ') ' || v_msg_data);
        IF v_error_message IS NULL THEN
          v_error_message := v_msg_data;
        ELSE
          v_error_message := v_error_message || ' ' || v_msg_data;
        END IF;
      END LOOP;
      message('Error when Cancel SO lines for header_id=' ||
              p_so_header_id || ' ' || v_error_message);
      p_return_status := 'E';
      p_error_message := 'Error when Cancel SO lines for header_id=' ||
                         p_so_header_id || ' ' || v_error_message;
    END IF;
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      p_return_status := 'E';
      p_error_message := 'Unexpected Error in CANCEL_SO_LINES_INTERNAL (' ||
                         v_step || ') : ' || SQLERRM;
  END cancel_so_lines_internal;
  --------------------------------------------------------------------
  --  customization code: CUST695
  --  name:               cancel_requisition_std_cost
  --  create by:          Vitaly K.
  --  $Revision:          1.0 $
  --  creation date:      30/10/2013
  --  Purpose :
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   30/10/2013    Vitaly K.       initial build CR998
  ----------------------------------------------------------------------
  PROCEDURE cancel_requisition_std_cost(errbuf               OUT VARCHAR2,
                                        retcode              OUT VARCHAR2,
                                        p_org_id             IN NUMBER,
                                        p_user_id            IN NUMBER,
                                        p_resp_id            IN NUMBER,
                                        p_resp_appl_id       IN NUMBER,
                                        p_requisition_number IN VARCHAR2) IS
  
    CURSOR c_req_cancel IS
      SELECT prh.segment1              requisition_num,
             prh.requisition_header_id,
             oha.org_id                so_org_id,
             prl.requisition_line_id,
             prh.preparer_id,
             prh.type_lookup_code,
             ola.header_id,
             ola.line_id,
             pdt.document_type_code,
             prh.authorization_status,
             prl.line_location_id
        FROM po_requisition_headers_all prh,
             po_requisition_lines_all   prl,
             po_document_types_all      pdt,
             oe_order_headers_all       oha,
             oe_order_lines_all         ola,
             fnd_lookup_values          t
       WHERE 1 = 1
         AND ola.header_id = oha.header_id
         AND nvl(ola.open_flag, 'Y') = 'Y'
         AND nvl(ola.cancelled_flag, 'N') = 'N'
         AND ola.source_document_type_id = 10
         AND ola.source_document_id = prl.requisition_header_id
         AND prl.requisition_line_id = ola.source_document_line_id
         AND prh.org_id = p_org_id ---parameter
         AND prh.segment1 = nvl(p_requisition_number, prh.segment1) ---parameter
         AND pdt.document_type_code = 'REQUISITION'
         AND prh.authorization_status = 'APPROVED'
         AND prh.type_lookup_code = 'INTERNAL'
         AND prl.line_location_id IS NULL
         AND nvl(prl.cancel_flag, 'N') = 'N'
         AND t.language = 'US'
         AND t.lookup_type = 'XXCST_INV_ORG_REPLACE'
         AND t.lookup_code = prl.destination_organization_id
         AND prh.requisition_header_id = prl.requisition_header_id
         AND prh.type_lookup_code = pdt.document_subtype
         AND prh.org_id = pdt.org_id
         AND trunc(prh.creation_date) >= '01-JAN-2012';
  
    v_step          VARCHAR2(100);
    v_error_message VARCHAR2(3000);
    v_return_status VARCHAR2(100);
  
    ----v_org_id               NUMBER;
    x_req_control_error_rc VARCHAR2(500);
  
    v_num_of_cancell_req_errors NUMBER := 0;
    v_num_of_cancelled_requisit NUMBER := 0;
    v_num_of_cancell_so_errors  NUMBER := 0;
    stop_processing         EXCEPTION;
    stop_cancel_requisition EXCEPTION;
  
  BEGIN
    v_step  := 'Step 0';
    errbuf  := 'Success';
    retcode := '0';
  
    message('*************** PARAMETERS ********************************');
    message('p_org_id=' || p_org_id || '===========================');
    message('p_user_id=' || p_user_id || '===========================');
    message('p_resp_id=' || p_resp_id || '===========================');
    message('p_resp_appl_id=' || p_resp_appl_id ||
            '===========================');
    IF p_requisition_number IS NOT NULL THEN
      message('p_requisition_number=' || p_requisition_number ||
              '===========================');
    END IF;
  
    v_step := 'Step 20';
    FOR i IN c_req_cancel LOOP
      ----------------- RERQUISITIONS LOOP ----------------------
      BEGIN
        v_step := 'Step 10';
        fnd_global.apps_initialize(user_id      => p_user_id, ---5490, --Tamar F
                                   resp_id      => p_resp_id, --- 50877,
                                   resp_appl_id => p_resp_appl_id); ---  201);
        mo_global.init('PO');
        mo_global.set_policy_context('S', p_org_id);
      
        po_reqs_control_sv.update_reqs_status(x_req_header_id        => i.requisition_header_id,
                                              x_req_line_id          => i.requisition_line_id,
                                              x_agent_id             => i.preparer_id,
                                              x_req_doc_type         => i.document_type_code,
                                              x_req_doc_subtype      => i.type_lookup_code,
                                              x_req_control_action   => 'CANCEL',
                                              x_req_control_reason   => 'CANCELLED BY API',
                                              x_req_action_date      => SYSDATE,
                                              x_encumbrance_flag     => 'N',
                                              x_oe_installed_flag    => 'Y',
                                              x_req_control_error_rc => x_req_control_error_rc);
        COMMIT;
        v_step := 'Step 30';
        IF x_req_control_error_rc IS NOT NULL THEN
          ---Cancellation ERROR---
          message('ERROR when Cancel Requisition ' || i.requisition_num ||
                  ' : ' || x_req_control_error_rc);
          v_num_of_cancell_req_errors := v_num_of_cancell_req_errors + 1;
          RAISE stop_cancel_requisition;
        ELSE
          ---Cancelled Successfully----
          v_num_of_cancelled_requisit := v_num_of_cancelled_requisit + 1;
        END IF;
      
        v_step := 'Step 40';
        cancel_so_lines_internal(p_so_header_id  => i.header_id,
                                 p_user_id       => p_user_id,
                                 p_so_org_id     => i.so_org_id,
                                 p_return_status => v_return_status,
                                 p_error_message => v_error_message);
        IF v_return_status <> 'S' THEN
          ----Error when Cancel lines in Sales Order-----
          v_num_of_cancell_so_errors := v_num_of_cancell_so_errors + 1;
        END IF;
      
      EXCEPTION
        WHEN stop_cancel_requisition THEN
          NULL; --continue to the next requisition
      END;
      --------------the end of RERQUISITIONS LOOP -------------------
    END LOOP;
    message(v_num_of_cancelled_requisit ||
            ' Requisitions were SUCCESSFULLY Cancelled');
    IF v_num_of_cancell_req_errors > 0 THEN
      message(v_num_of_cancell_req_errors ||
              ' Requisitions Cancellation ERRORS');
    END IF;
    IF v_num_of_cancell_so_errors > 0 THEN
      message(v_num_of_cancell_so_errors ||
              ' Sales Orders (lines) Cancellation ERRORS');
    END IF;
    message('************** PROGRAM WAS COMPLETED *************************');
  
  EXCEPTION
    WHEN stop_processing THEN
      message(v_error_message);
      errbuf  := v_error_message;
      retcode := '2';
      ROLLBACK;
    WHEN OTHERS THEN
      v_error_message := 'Unexpected Error in procedure xxconv_il_purchasing_pkg.cancel_requisition_std_cost  ' ||
                         v_step || ': ' || SQLERRM;
      message(v_error_message);
      errbuf  := v_error_message;
      retcode := '2';
      ROLLBACK;
  END cancel_requisition_std_cost;
  --------------------------------------------------------------------
  --  customization code: CUST695
  --  name:               create_requisition_std_cost
  --  create by:          Vitaly K.
  --  $Revision:          1.0 $
  --  creation date:      30/10/2013
  --  Purpose :
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   30/10/2013    Vitaly K.       initial build CR998
  ----------------------------------------------------------------------
  PROCEDURE create_requisition_std_cost(errbuf         OUT VARCHAR2,
                                        retcode        OUT VARCHAR2,
                                        p_org_id       IN NUMBER,
                                        p_user_id      IN NUMBER,
                                        p_resp_id      IN NUMBER,
                                        p_resp_appl_id IN NUMBER) IS
  
    v_step          VARCHAR2(100);
    v_error_message VARCHAR2(3000);
  
    v_org_id NUMBER;
  
    v_rows_inserted_into_req_int NUMBER := 0;
    v_num_of_req_import_errors   NUMBER := 0;
    stop_processing EXCEPTION;
  
    ------
    v_concurrent_request_id NUMBER;
    ---- out variables for fnd_concurrent.wait_for_request-----
    x_phase       VARCHAR2(100);
    x_status      VARCHAR2(100);
    x_dev_phase   VARCHAR2(100);
    x_dev_status  VARCHAR2(100);
    x_return_bool BOOLEAN;
    x_message     VARCHAR2(100);
  
  BEGIN
    v_step  := 'Step 0';
    errbuf  := 'Success';
    retcode := '0';
  
    ---v_org_id := nvl(p_org_id, fnd_global.org_id);
    v_org_id := nvl(p_org_id, fnd_profile.value('ORG_ID'));
    message('*************** ORG_ID=' || v_org_id ||
            ' *************************************');
  
    fnd_global.apps_initialize(user_id      => p_user_id, ---5490, --Tamar F
                               resp_id      => p_resp_id, --- 50877,
                               resp_appl_id => p_resp_appl_id); ---  201);
    mo_global.init('PO');
    mo_global.set_policy_context('S', p_org_id);
  
    v_step := 'Step 30';
    INSERT INTO po_requisitions_interface_all
      (batch_id,
       group_code,
       header_description,
       item_id,
       item_revision,
       need_by_date,
       quantity,
       org_id,
       created_by,
       creation_date,
       last_updated_by,
       last_update_date,
       last_update_login,
       destination_organization_id,
       destination_subinventory,
       deliver_to_location_id,
       preparer_id,
       charge_account_id,
       source_organization_id,
       uom_code,
       deliver_to_requestor_id,
       authorization_status,
       source_type_code, -- INVENTORY
       destination_type_code, --  INVENTORY
       interface_source_code, --'FORM'
       project_accounting_context, -- N
       vmi_flag, --  N
       autosource_flag)
      (SELECT fnd_global.conc_request_id,
              oha.order_number,
              oha.order_number,
              ola.inventory_item_id,
              prl.item_revision,
              prl.need_by_date,
              --prl.quantity,
              ola.ordered_quantity,
              prl.org_id,
              fnd_global.user_id,
              SYSDATE,
              fnd_global.user_id,
              SYSDATE,
              fnd_global.conc_login_id,
              flv.attribute1 destination_organization_id,
              prl.destination_subinventory,
              prl.deliver_to_location_id,
              prh.preparer_id,
              mp.material_account,
              CASE
                WHEN prl.source_organization_id = 90 AND
                     prl.deliver_to_location_id IN
                     (SELECT xx.lookup_code --282,184962
                        FROM fnd_lookup_values xx
                       WHERE xx.lookup_type = 'XXCST_WH_INT_LOCATION_ORG'
                         AND xx.language = 'US') THEN
                 (SELECT xx.description
                    FROM fnd_lookup_values xx
                   WHERE xx.lookup_type = 'XXCST_WH_INT_LOCATION_ORG'
                     AND xx.language = 'US'
                     AND xx.lookup_code = prl.deliver_to_location_id)
                ELSE
                 flb.attribute1
              END source_org_id,
              -- flb.attribute1               source_org_id,
              ola.order_quantity_uom,
              prl.to_person_id,
              'APPROVED',
              'INVENTORY',
              prl.destination_type_code,
              'STDCST',
              'N',
              'N',
              'P'
         FROM oe_order_headers_all       oha,
              oe_order_lines_all         ola,
              po_requisition_lines_all   prl,
              po_requisition_headers_all prh,
              mtl_parameters             mp,
              fnd_lookup_values          flv,
              fnd_lookup_values          flb
        WHERE 1 = 1
          AND ola.header_id = oha.header_id
          AND nvl(ola.open_flag, 'Y') = 'Y'
          AND nvl(ola.cancelled_flag, 'N') = 'N'
          AND ola.source_document_type_id = 10
          AND (ola.source_document_id = prl.requisition_header_id AND
              prl.requisition_line_id = ola.source_document_line_id)
          AND flv.lookup_code = prl.destination_organization_id
          AND flb.lookup_code = ola.ship_from_org_id
          AND mp.organization_id = ola.ship_from_org_id
          AND flb.lookup_type = 'XXCST_INV_ORG_REPLACE'
          AND flb.language = 'US'
          AND flv.lookup_type = 'XXCST_INV_ORG_REPLACE'
          AND flv.language = 'US'
          AND trunc(prh.creation_date) >= '01-JAN-2012'
          AND prh.org_id = v_org_id ---variable
          AND prh.requisition_header_id = prl.requisition_header_id
          AND NOT EXISTS (SELECT 1
                 FROM csp_req_line_details x
                WHERE x.source_id = ola.line_id));
  
    v_rows_inserted_into_req_int := SQL%ROWCOUNT;
    message(v_rows_inserted_into_req_int ||
            ' Records were inserted into table PO_REQUISITIONS_INTERFACE_ALL');
    COMMIT;
  
    --===================== SUBMIT RERQUEST for Requisition Import ===================================
    v_step := 'Step 400';
    ---Submit concurrent program 'Requisition Import' / REQIMPORT-----------( 6 parameters for example: NJRC,333333 , ITEM, , N, Y )
    x_return_bool := fnd_request.set_print_options(NULL, NULL, 0, TRUE, 'N');
  
    v_concurrent_request_id := fnd_request.submit_request(application => 'PO',
                                                          program     => 'REQIMPORT', ---Requisition Import
                                                          argument1   => 'NJRC', ---INTERFACE_SOURCE_CODE
                                                          argument2   => fnd_global.conc_request_id, ----BATCH_ID
                                                          argument3   => 'ITEM', ---GROUP_BY
                                                          argument4   => NULL, -----LAST_REQUISITION_NUMBER
                                                          argument5   => 'N', -----MULTI_DISTRIBUTIONS
                                                          argument6   => 'Y' -----INITIATE_REQAPPR_AFTER_REQIMP
                                                          );
  
    COMMIT;
  
    v_step := 'Step 410';
    IF v_concurrent_request_id > 0 THEN
      message('Concurrent ''Requisition Import'' was SUBMITTED successfully (request_id=' ||
              v_concurrent_request_id || ')');
      ---------
      LOOP
        x_return_bool := fnd_concurrent.wait_for_request(v_concurrent_request_id,
                                                         5, --- interval 10  seconds
                                                         3600, ---- max wait 1 hour
                                                         x_phase,
                                                         x_status,
                                                         x_dev_phase,
                                                         x_dev_status,
                                                         x_message);
        EXIT WHEN x_return_bool AND upper(x_dev_phase) = 'COMPLETE';
      
      END LOOP;
      IF upper(x_dev_phase) = 'COMPLETE' AND
         upper(x_dev_status) IN ('ERROR', 'WARNING') THEN
        v_error_message := 'Concurrent ''Requisition Import'' concurrent program completed in ' ||
                           upper(x_dev_status) ||
                           '. See log for request_id=' ||
                           v_concurrent_request_id;
        RAISE stop_processing;
      ELSIF upper(x_dev_phase) = 'COMPLETE' AND
            upper(x_dev_status) = 'NORMAL' THEN
        message('Concurrent ''Requisition Import'' was SUCCESSFULLY COMPLETED (request_id=' ||
                v_concurrent_request_id || ')');
      ELSE
        v_error_message := 'Concurrent ''Requisition Import'' failed , review log (request_id=' ||
                           v_concurrent_request_id || ')';
        RAISE stop_processing;
      END IF;
    ELSE
      v_error_message := 'Concurrent ''Requisition Import'' submitting PROBLEM';
      RAISE stop_processing;
    END IF;
  
    ----Check Requisition Import Errors------
    v_step := 'Step 420';
    FOR error_rec IN (SELECT poie.column_name,
                             REPLACE(poie.error_message, chr(10), ' ') error_message
                        FROM po_interface_errors poie
                       WHERE poie.interface_type = 'REQIMPORT'
                         AND poie.batch_id = fnd_global.conc_request_id) LOOP
      message('Requisition Import ERROR: column_name=''' ||
              error_rec.column_name || ', ' || error_rec.error_message);
      v_num_of_req_import_errors := v_num_of_req_import_errors + 1;
    END LOOP;
  
    IF v_num_of_req_import_errors > 0 THEN
      errbuf  := '************** Requisition Import was completed with ' ||
                 v_num_of_req_import_errors ||
                 ' ERRORS *************************';
      retcode := '1';
    END IF;
  
    message('************** PROGRAM WAS COMPLETED *************************');
  
  EXCEPTION
    WHEN stop_processing THEN
      message(v_error_message);
      errbuf  := v_error_message;
      retcode := '2';
      ROLLBACK;
    WHEN OTHERS THEN
      v_error_message := 'Unexpected Error in procedure xxconv_il_purchasing_pkg.create_requisition_std_cost   ' ||
                         v_step || ': ' || SQLERRM;
      message(v_error_message);
      errbuf  := v_error_message;
      retcode := '2';
      ROLLBACK;
  END create_requisition_std_cost;
  --------------------------------------------------------------------
  --  customization code: CUST695
  --  name:               handle_po_quota_price_break
  --  create by:          Vitaly K.
  --  $Revision:          1.0 $
  --  creation date:      30/10/2013
  --  Purpose :
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   30/10/2013    Vitaly K.       initial build CR932
  ----------------------------------------------------------------------
  PROCEDURE handle_po_quota_price_break(p_batch_id            NUMBER,
                                        p_po_line_location_id NUMBER,
                                        p_interface_header_id NUMBER,
                                        p_interface_line_id   NUMBER,
                                        x_error_code          OUT NUMBER, ---0-success
                                        x_error_message       OUT VARCHAR2) IS
    CURSOR c_get_po_quota_price_break_d IS
      SELECT po.*
        FROM xxconv_po_quotation_log po --- po quotation price breaks level rows inside
       WHERE po.batch_id = p_batch_id ---parameter
         AND po.line_location_id = p_po_line_location_id; ---parameter
  
    l_po_quota_price_break_d_rec c_get_po_quota_price_break_d%ROWTYPE;
    l_iface_line_locations_rec   po.po_line_locations_interface%ROWTYPE;
    v_step                       VARCHAR2(100);
    v_curr_user_employee_id      NUMBER;
    stop_processing EXCEPTION;
  
  BEGIN
    v_step          := 'Step 0';
    x_error_code    := 0; ---success
    x_error_message := NULL;
  
    v_step := 'Step 10';
    ----Get Current user employee_id----
    SELECT fu.employee_id
      INTO v_curr_user_employee_id
      FROM fnd_user fu
     WHERE fu.user_id = fnd_global.user_id;
  
    v_step := 'Step 20';
    IF p_po_line_location_id IS NULL THEN
      x_error_code    := 2;
      x_error_message := 'Error in handle_po_quota_price_break: Missing parameter p_po_line_location_id';
      RAISE stop_processing;
    END IF;
    IF p_interface_header_id IS NULL THEN
      x_error_code    := 2;
      x_error_message := 'Error in handle_po_quota_price_break: Missing parameter p_interface_header_id';
      RAISE stop_processing;
    END IF;
    IF p_interface_line_id IS NULL THEN
      x_error_code    := 2;
      x_error_message := 'Error in handle_po_quota_price_break: Missing parameter p_interface_line_id';
      RAISE stop_processing;
    END IF;
  
    v_step := 'Step 70';
    OPEN c_get_po_quota_price_break_d;
    FETCH c_get_po_quota_price_break_d
      INTO l_po_quota_price_break_d_rec;
    CLOSE c_get_po_quota_price_break_d;
  
    v_step                                         := 'Step 70.2';
    l_iface_line_locations_rec.interface_header_id := p_interface_header_id; --parameter
    l_iface_line_locations_rec.interface_line_id   := p_interface_line_id; --parameter
    SELECT po_line_locations_interface_s.nextval
      INTO l_iface_line_locations_rec.interface_line_location_id
      FROM dual;
  
    l_iface_line_locations_rec.shipment_type           := 'QUOTATION';
    l_iface_line_locations_rec.shipment_num            := l_po_quota_price_break_d_rec.price_breake_num;
    l_iface_line_locations_rec.ship_to_organization_id := l_po_quota_price_break_d_rec.new_ship_to_organization_id;
    l_iface_line_locations_rec.ship_to_location_id     := l_po_quota_price_break_d_rec.price_brea_ship_to_location_id;
    l_iface_line_locations_rec.quantity                := l_po_quota_price_break_d_rec.quantity;
    l_iface_line_locations_rec.unit_of_measure         := l_po_quota_price_break_d_rec.unit_meas_lookup_code;
    l_iface_line_locations_rec.price_override          := l_po_quota_price_break_d_rec.price_override;
    l_iface_line_locations_rec.price_discount          := l_po_quota_price_break_d_rec.price_discount;
    l_iface_line_locations_rec.start_date              := l_po_quota_price_break_d_rec.price_breake_start_date;
    l_iface_line_locations_rec.end_date                := l_po_quota_price_break_d_rec.price_breake_end_date;
    l_iface_line_locations_rec.qty_rcv_exception_code  := l_po_quota_price_break_d_rec.qty_rcv_exception_code;
    l_iface_line_locations_rec.creation_date           := l_po_quota_price_break_d_rec.creation_date;
  
    v_step := 'Step 75';
    INSERT INTO po_line_locations_interface
    VALUES l_iface_line_locations_rec;
  
    v_step := 'Step 80';
    UPDATE xxconv_po_quotation_log a
       SET a.interface_header_id        = p_interface_header_id, ---parameter
           a.interface_line_id          = p_interface_line_id, ---parameter
           a.interface_line_location_id = l_iface_line_locations_rec.interface_line_location_id
     WHERE a.batch_id = p_batch_id ---parameter
       AND a.line_location_id = p_po_line_location_id; ---parameter
  
  EXCEPTION
    WHEN stop_processing THEN
      NULL;
    WHEN OTHERS THEN
      x_error_code    := 2;
      x_error_message := substr('Unexpected Error in  handle_po_quota_price_break (' ||
                                v_step || ') : ' || SQLERRM,
                                1,
                                200);
  END handle_po_quota_price_break;
  --------------------------------------------------------------------
  --  customization code: CUST695
  --  name:               handle_po_quotation_lines
  --  create by:          Vitaly K.
  --  $Revision:          1.0 $
  --  creation date:      30/10/2013
  --  Purpose :
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   30/10/2013    Vitaly K.       initial build CR932
  ----------------------------------------------------------------------
  PROCEDURE handle_po_quotation_lines(p_batch_id            NUMBER,
                                      p_po_line_id          NUMBER,
                                      p_interface_header_id NUMBER,
                                      x_error_code          OUT NUMBER, ---0-success
                                      x_error_message       OUT VARCHAR2) IS
    CURSOR c_get_po_quota_line_det IS
      SELECT DISTINCT po.po_line_id,
                      po.line_num,
                      po.line_type,
                      po.item,
                      po.vendor_product_num,
                      po.uom_code,
                      po.unit_price,
                      po.new_ship_to_organization_id,
                      po.ship_to_location_id,
                      po.line_creation_date
        FROM xxconv_po_quotation_log po --- po quotation price breaks level rows inside
       WHERE po.batch_id = p_batch_id ---parameter
         AND po.po_line_id = p_po_line_id; ---parameter
  
    CURSOR c_get_po_quota_price_breaks IS
      SELECT po.line_location_id
        FROM xxconv_po_quotation_log po --- po quotation price breaks level rows inside
       WHERE po.batch_id = p_batch_id ---parameter
         AND po.po_line_id = p_po_line_id ---parameter
         AND po.line_location_id IS NOT NULL
         AND po.status = 'N'
       ORDER BY po.price_breake_num;
  
    l_po_quotation_line_det_rec c_get_po_quota_line_det%ROWTYPE;
    l_iface_lines_rec           po.po_lines_interface%ROWTYPE;
    v_step                      VARCHAR2(100);
    v_curr_user_employee_id     NUMBER;
    stop_processing EXCEPTION;
    v_error_code    VARCHAR2(100);
    v_error_message VARCHAR2(3000);
  
  BEGIN
    v_step          := 'Step 0';
    x_error_code    := 0; ---success
    x_error_message := NULL;
  
    v_step := 'Step 10';
    ----Get Current user employee_id----
    SELECT fu.employee_id
      INTO v_curr_user_employee_id
      FROM fnd_user fu
     WHERE fu.user_id = fnd_global.user_id;
  
    v_step := 'Step 20';
    IF p_po_line_id IS NULL THEN
      x_error_code    := 2;
      x_error_message := 'Error in handle_po_quotation_lines: Missing parameter p_po_line_id';
      RAISE stop_processing;
    END IF;
    IF p_interface_header_id IS NULL THEN
      x_error_code    := 2;
      x_error_message := 'Error in handle_po_quotation_lines: Missing parameter p_interface_header_id';
      RAISE stop_processing;
    END IF;
  
    v_step := 'Step 70';
    OPEN c_get_po_quota_line_det;
    FETCH c_get_po_quota_line_det
      INTO l_po_quotation_line_det_rec;
    CLOSE c_get_po_quota_line_det;
  
    v_step                                := 'Step 70.2';
    l_iface_lines_rec.interface_header_id := p_interface_header_id; --parameter
    SELECT po_lines_interface_s.nextval
      INTO l_iface_lines_rec.interface_line_id
      FROM dual;
  
    l_iface_lines_rec.action                  := 'ADD';
    l_iface_lines_rec.line_num                := l_po_quotation_line_det_rec.line_num;
    l_iface_lines_rec.line_type               := l_po_quotation_line_det_rec.line_type;
    l_iface_lines_rec.item                    := l_po_quotation_line_det_rec.item;
    l_iface_lines_rec.vendor_product_num      := l_po_quotation_line_det_rec.vendor_product_num;
    l_iface_lines_rec.uom_code                := l_po_quotation_line_det_rec.uom_code;
    l_iface_lines_rec.unit_price              := l_po_quotation_line_det_rec.unit_price;
    l_iface_lines_rec.ship_to_organization_id := l_po_quotation_line_det_rec.new_ship_to_organization_id;
    l_iface_lines_rec.ship_to_location_id     := l_po_quotation_line_det_rec.ship_to_location_id;
    l_iface_lines_rec.need_by_date            := SYSDATE;
    l_iface_lines_rec.promised_date           := SYSDATE;
    l_iface_lines_rec.creation_date           := l_po_quotation_line_det_rec.line_creation_date;
    l_iface_lines_rec.line_loc_populated_flag := 'Y';
  
    v_step := 'Step 75';
    INSERT INTO po_lines_interface VALUES l_iface_lines_rec;
  
    FOR price_break_rec IN c_get_po_quota_price_breaks LOOP
      ---==================== PRICE_BREAKS LOOP=======================
      v_step := 'Step 100';
      handle_po_quota_price_break(p_batch_id            => p_batch_id,
                                  p_po_line_location_id => price_break_rec.line_location_id,
                                  p_interface_header_id => p_interface_header_id,
                                  p_interface_line_id   => l_iface_lines_rec.interface_line_id,
                                  x_error_code          => v_error_code, ---0-success, 2-error
                                  x_error_message       => v_error_message);
    
      IF v_error_code <> 0 THEN
        ---PO quota_price_break Processing ERROR-----
        x_error_code    := 2;
        x_error_message := v_error_message;
        RAISE stop_processing;
      END IF;
      ---============== the end of PRICE_BREAKS LOOP================
    END LOOP;
  
  EXCEPTION
    WHEN stop_processing THEN
      NULL;
    WHEN OTHERS THEN
      x_error_code    := 2;
      x_error_message := substr('Unexpected Error in  handle_po_quotation_lines (' ||
                                v_step || ') : ' || SQLERRM,
                                1,
                                200);
  END handle_po_quotation_lines;
  --------------------------------------------------------------------
  --  customization code: CUST695
  --  name:               handle_po_quotation_header
  --  create by:          Vitaly K.
  --  $Revision:          1.0 $
  --  creation date:      30/10/2013
  --  Purpose :
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   30/10/2013    Vitaly K.       initial build CR932
  ----------------------------------------------------------------------
  PROCEDURE handle_po_quotation_header(p_batch_id            NUMBER,
                                       p_org_id              NUMBER,
                                       p_po_header_id        NUMBER,
                                       x_interface_header_id OUT NUMBER,
                                       x_error_code          OUT NUMBER, ---0-success
                                       x_error_message       OUT VARCHAR2) IS
    CURSOR c_get_po_quota_head_details IS
      SELECT DISTINCT po.quote_subtype,
                      po.currency_code,
                      po.agent_id,
                      po.vendor_id,
                      po.vendor_site_id,
                      po.ship_to_location_id,
                      po.bill_to_location_id,
                      po.po_header_attribute1,
                      po.po_header_attribute2,
                      po.new_quotation_number,
                      po.quote_warning_delay,
                      po.reply_date,
                      po.rate_date
        FROM xxconv_po_quotation_log po --- po quotation price breaks level rows inside
       WHERE po.po_header_id = p_po_header_id ---parameter
         AND po.batch_id = p_batch_id; ---parameter
  
    CURSOR c_get_po_quotation_lines IS
      SELECT tab.po_line_id, tab.line_num
        FROM (SELECT DISTINCT po.po_line_id, po.line_num
                FROM xxconv_po_quotation_log po
               WHERE po.po_header_id = p_po_header_id ---parameter
                 AND po.batch_id = p_batch_id ---parameter
                 AND po.status = 'N') tab
       ORDER BY tab.line_num;
  
    v_step                        VARCHAR2(100);
    v_error_code                  NUMBER; ---0-success, 2-error
    v_error_message               VARCHAR2(3000);
    l_po_quotation_header_det_rec c_get_po_quota_head_details%ROWTYPE;
    l_iface_rec                   po.po_headers_interface%ROWTYPE;
    stop_processing EXCEPTION;
  BEGIN
    v_step          := 'Step 0';
    x_error_code    := 0; ---success
    x_error_message := NULL;
  
    IF p_batch_id IS NULL THEN
      x_error_code    := 2;
      x_error_message := 'Error in  handle_po_quotation_header: Missing parameter p_batch_id';
      RAISE stop_processing;
    END IF;
    IF p_org_id IS NULL THEN
      x_error_code    := 2;
      x_error_message := 'Error in  handle_po_quotation_header: Missing parameter p_org_id';
      RAISE stop_processing;
    END IF;
  
    v_step := 'Step 10';
    OPEN c_get_po_quota_head_details;
    FETCH c_get_po_quota_head_details
      INTO l_po_quotation_header_det_rec;
    CLOSE c_get_po_quota_head_details;
  
    v_step := 'Step 20';
    SELECT po_headers_interface_s.nextval
      INTO l_iface_rec.interface_header_id
      FROM dual;
  
    v_step                          := 'Step 30';
    l_iface_rec.process_code        := 'PENDING';
    l_iface_rec.action              := 'ORIGINAL';
    l_iface_rec.document_type_code  := 'QUOTATION';
    v_step                          := 'Step 30.2';
    l_iface_rec.document_num        := l_po_quotation_header_det_rec.new_quotation_number;
    l_iface_rec.document_subtype    := l_po_quotation_header_det_rec.quote_subtype;
    l_iface_rec.currency_code       := l_po_quotation_header_det_rec.currency_code;
    l_iface_rec.agent_id            := l_po_quotation_header_det_rec.agent_id;
    l_iface_rec.vendor_id           := l_po_quotation_header_det_rec.vendor_id;
    l_iface_rec.vendor_site_id      := l_po_quotation_header_det_rec.vendor_site_id;
    v_step                          := 'Step 30.3';
    l_iface_rec.ship_to_location_id := l_po_quotation_header_det_rec.ship_to_location_id;
    l_iface_rec.bill_to_location_id := l_po_quotation_header_det_rec.bill_to_location_id;
    l_iface_rec.attribute1          := l_po_quotation_header_det_rec.po_header_attribute1;
    l_iface_rec.attribute2          := l_po_quotation_header_det_rec.po_header_attribute2;
    v_step                          := 'Step 30.4';
    l_iface_rec.quote_warning_delay := l_po_quotation_header_det_rec.quote_warning_delay;
    l_iface_rec.reply_date          := l_po_quotation_header_det_rec.reply_date;
    l_iface_rec.rate_date           := l_po_quotation_header_det_rec.rate_date;
  
    v_step                            := 'Step 30.5';
    l_iface_rec.interface_source_code := 'Std_Cost_Conversion';
    l_iface_rec.org_id                := p_org_id;
    l_iface_rec.batch_id              := p_batch_id;
    l_iface_rec.creation_date         := SYSDATE;
  
    v_step := 'Step 40';
    INSERT INTO po.po_headers_interface VALUES l_iface_rec;
  
    v_step := 'Step 50';
    FOR line_rec IN c_get_po_quotation_lines LOOP
      ---=================== PO QUOTATION LINES LOOP ===============================
      handle_po_quotation_lines(p_batch_id            => p_batch_id,
                                p_po_line_id          => line_rec.po_line_id,
                                p_interface_header_id => po_headers_interface_s.currval, --l_iface_rec.interface_header_id,
                                x_error_code          => v_error_code, ---0-success, 2-error
                                x_error_message       => v_error_message);
    
      IF v_error_code <> 0 THEN
        ---PO Quotation Lines  Processing ERROR-----
        x_error_code    := 2;
        x_error_message := v_error_message;
        RAISE stop_processing;
      END IF;
      ---===============the end of PO QUOTATION LINES LOOP ========================
    END LOOP;
  
    v_step                := 'Step 60';
    x_interface_header_id := l_iface_rec.interface_header_id;
  
  EXCEPTION
    WHEN stop_processing THEN
      x_interface_header_id := l_iface_rec.interface_header_id;
    WHEN OTHERS THEN
      x_interface_header_id := l_iface_rec.interface_header_id;
      x_error_code          := 2;
      x_error_message       := substr('Unexpected Error in  handle_po_quotation_header (' ||
                                      v_step || ');' || SQLERRM,
                                      1,
                                      200);
  END handle_po_quotation_header;
  --------------------------------------------------------------------
  --  customization code: CUST695
  --  name:               fill_quotation_log_table
  --  create by:          Vitaly K.
  --  $Revision:          1.0 $
  --  creation date:      30/10/2013
  --  Purpose :
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   30/10/2013    Vitaly K.       initial build CR932
  ----------------------------------------------------------------------
  PROCEDURE fill_quotation_log_table(p_batch_id            IN NUMBER,
                                     p_org_id              IN NUMBER,
                                     p_po_quotation_number IN VARCHAR2,
                                     x_error_code          OUT NUMBER, ---0-success
                                     x_error_message       OUT VARCHAR2) IS
    stop_processing EXCEPTION;
    v_num_of_deleted_records  NUMBER;
    v_num_of_inserted_records NUMBER;
  BEGIN
    x_error_code    := 0; ---success
    x_error_message := NULL;
  
    IF p_batch_id IS NULL THEN
      x_error_code    := 2; ---error
      x_error_message := 'ERROR in fill_quotation_log_table procedure: Missing p_batch_id parameter';
      RAISE stop_processing;
    END IF;
  
    IF p_org_id IS NULL THEN
      x_error_code    := 2; ---error
      x_error_message := 'ERROR in fill_quotation_log_table procedure: Missing p_org_id parameter';
      RAISE stop_processing;
    END IF;
  
    DELETE FROM xxconv_po_quotation_log WHERE batch_id = p_batch_id;
    v_num_of_deleted_records := SQL%ROWCOUNT;
    COMMIT;
    IF v_num_of_deleted_records <> 0 THEN
      message(v_num_of_deleted_records ||
              ' records (garbage) were DELETED from XXCONV_PO_QUOTATION_LOG for batch_id=' ||
              p_batch_id);
    END IF;
  
    INSERT INTO xxconv_po_quotation_log
      (batch_id,
       po_header_id,
       quotation_number,
       new_quotation_number,
       quote_subtype,
       attachment_flag,
       currency_code,
       quote_warning_delay,
       org_id,
       agent_id,
       vendor_id,
       vendor_site_id,
       ship_to_location_id,
       bill_to_location_id,
       po_header_attribute1,
       po_header_attribute2,
       reply_date,
       rate_date,
       comments,
       ----Line Level
       po_line_id,
       line_num,
       line_type,
       item,
       vendor_product_num,
       uom_code,
       unit_price,
       line_creation_date,
       ----Price break Level
       line_location_id,
       price_breake_num,
       price_breake_start_date,
       price_breake_end_date,
       qty_rcv_exception_code,
       price_override,
       price_discount,
       quantity,
       unit_meas_lookup_code,
       price_brea_ship_to_location_id,
       new_ship_to_organization_id,
       interface_header_id,
       interface_line_id,
       interface_line_location_id,
       status,
       error_message,
       creation_date,
       last_update_date)
      SELECT p_batch_id,
             po_header_id,
             a.quotation_number,
             a.new_quotation_number,
             a.quote_subtype,
             a.attachment_flag,
             a.currency_code,
             a.quote_warning_delay,
             a.org_id,
             a.agent_id,
             a.vendor_id,
             a.vendor_site_id,
             a.ship_to_location_id,
             a.bill_to_location_id,
             a.po_header_attribute1,
             a.po_header_attribute2,
             a.reply_date,
             a.rate_date,
             a.comments,
             ----Line Level
             a.po_line_id,
             a.line_num,
             a.line_type,
             a.item,
             a.vendor_product_num,
             a.uom_code,
             a.unit_price,
             a.line_creation_date,
             ----Price break Level
             a.line_location_id,
             a.shipment_num                   price_break_num,
             a.price_breake_start_date,
             a.price_breake_end_date,
             a.qty_rcv_exception_code,
             a.price_override,
             a.price_discount,
             a.quantity,
             a.unit_meas_lookup_code,
             a.price_brea_ship_to_location_id,
             a.new_ship_to_organization_id,
             NULL                             interface_header_id,
             NULL                             interface_line_id,
             NULL                             interface_line_location_id,
             'N', ---status,
             NULL, ---error_message,
             SYSDATE                          creation_date,
             SYSDATE                          last_update_date
        FROM xxconv_po_quota_std_cost_v a
       WHERE ----a.quotation_number IN ('28072013_NJRC', '07171098-1')
       a.quotation_number = nvl(p_po_quotation_number, a.quotation_number)
       AND a.org_id = p_org_id ---parameter
       ORDER BY a.po_header_id, a.line_num, a.shipment_num;
  
    v_num_of_inserted_records := SQL%ROWCOUNT;
    COMMIT;
    message(v_num_of_inserted_records ||
            ' records successfully INSERTED into table XXCONV_PO_QUOTATION_LOG for batch_id=' ||
            p_batch_id || ' and org_id=' || p_org_id);
  
  EXCEPTION
    WHEN stop_processing THEN
      NULL;
    WHEN OTHERS THEN
      x_error_code    := 2;
      x_error_message := substr('Unexpected Error in  fill_quotation_log_table: ' ||
                                SQLERRM,
                                1,
                                200);
  END fill_quotation_log_table;
  --------------------------------------------------------------------
  --  customization code: CUST695
  --  name:               check_po_quotations_import_err
  --  create by:          Vitaly K.
  --  $Revision:          1.0 $
  --  creation date:      30/10/2013
  --  Purpose :
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   30/10/2013    Vitaly K.       initial build CR932
  -----------------------------------------------------------------------
  PROCEDURE check_po_quotations_import_err(p_batch_id      NUMBER,
                                           x_error_code    OUT NUMBER, ---0-success
                                           x_error_message OUT VARCHAR2) IS
    CURSOR c_get_log_data IS
      SELECT DISTINCT polog.interface_header_id,
                      polog.interface_line_id,
                      polog.interface_line_location_id,
                      polog.quotation_number,
                      polog.new_quotation_number,
                      polog.line_num,
                      polog.price_breake_num
        FROM xxconv_po_quotation_log polog
       WHERE polog.batch_id = p_batch_id ---parameter
         AND polog.status <> 'E' --previous error
         AND polog.interface_header_id IS NOT NULL
         AND polog.interface_line_id IS NOT NULL;
  
    CURSOR c_get_quotation_import_errors(p_interface_header_id        NUMBER,
                                         p_interface_line_id          NUMBER,
                                         p_interface_line_location_id NUMBER) IS
      SELECT e.table_name || ' ' || e.error_message error_message
        FROM po_interface_errors e
       WHERE e.table_name = 'PO_HEADERS_INTERFACE'
         AND e.interface_header_id = p_interface_header_id --cursor parameter
         AND e.error_message IS NOT NULL
      UNION ALL
      SELECT e.table_name || ' ' || e.error_message
        FROM po_interface_errors e
       WHERE e.table_name = 'PO_LINES_INTERFACE'
         AND e.interface_header_id = p_interface_header_id --cursor parameter
         AND e.interface_line_id = p_interface_line_id --cursor parameter
         AND e.error_message IS NOT NULL
      UNION ALL
      SELECT e.table_name || ' ' || e.error_message
        FROM po_interface_errors e
       WHERE e.table_name = 'PO_LINE_LOCATIONS_INTERFACE'
         AND e.interface_header_id = p_interface_header_id --cursor parameter
         AND e.interface_line_id = p_interface_line_id --cursor parameter
         AND e.interface_line_location_id = p_interface_line_location_id --cursor parameter
         AND e.error_message IS NOT NULL;
  
    stop_processing EXCEPTION;
    v_count_errors NUMBER := 0;
  
  BEGIN
    x_error_code    := 0; ---success
    x_error_message := NULL;
  
    IF p_batch_id IS NULL THEN
      x_error_code    := 2;
      x_error_message := 'Error in  check_po_quotations_import_err: Missing parameter p_batch_id';
      RAISE stop_processing;
    END IF;
  
    FOR log_data_rec IN c_get_log_data LOOP
      ---============== LOG LOOP ==========================
      FOR error_rec IN c_get_quotation_import_errors(p_interface_header_id        => log_data_rec.interface_header_id,
                                                     p_interface_line_id          => log_data_rec.interface_line_id,
                                                     p_interface_line_location_id => log_data_rec.interface_line_location_id) LOOP
        ---=============== IMPORT ERRORS LOOP ========================
        v_count_errors := v_count_errors + 1;
        IF v_count_errors = 1 THEN
          message('****************** SEE IMPORT PRICE CATALOGS ERRORS below **************************************************');
        END IF;
        UPDATE xxconv_po_quotation_log a
           SET a.status = 'E', a.error_message = error_rec.error_message
         WHERE a.batch_id = p_batch_id ---parameter
           AND a.interface_header_id = log_data_rec.interface_header_id
           AND a.interface_line_id =
               nvl(log_data_rec.interface_line_id, a.interface_line_id);
        message('****** New Quotation#' ||
                log_data_rec.new_quotation_number || ', line#=' ||
                log_data_rec.line_num || ' Import Error: ' ||
                error_rec.error_message);
        ---==========the end of IMPORT ERRORS LOOP ===================
      END LOOP;
      ---===========the end of LOG LOOP =======================
    END LOOP;
  
    UPDATE xxconv_po_quotation_log a
       SET a.status = 'E'
     WHERE a.batch_id = p_batch_id ---parameter
       AND a.status = 'S'
       AND EXISTS
     (SELECT 1
              FROM xxconv_po_quotation_log a2
             WHERE a2.batch_id = a.batch_id
               AND a2.interface_header_id = a.interface_header_id
               AND a2.status = 'E');
  
    COMMIT; ---COMMIT---COMMIT---COMMIT----
  
    IF v_count_errors = 0 THEN
      message('************** NO IMPORT PRICE CATALOGS ERRORS ******************');
    END IF;
  
  EXCEPTION
    WHEN stop_processing THEN
      NULL;
    WHEN OTHERS THEN
      x_error_code    := 2;
      x_error_message := substr('Unexpected Error in  check_po_quotations_import_err: ' ||
                                SQLERRM,
                                1,
                                200);
  END check_po_quotations_import_err;
  --------------------------------------------------------------------
  --  customization code: CUST695
  --  name:               validate_quotations
  --  create by:          Vitaly K.
  --  $Revision:          1.0 $
  --  creation date:      30/10/2013
  --  Purpose :
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   30/10/2013    Vitaly K.       initial build CR932
  -----------------------------------------------------------------------
  PROCEDURE validate_quotations(p_batch_id      NUMBER,
                                x_error_code    OUT NUMBER, ---0-success
                                x_error_message OUT VARCHAR2) IS
    CURSOR c_get_po_headers IS
      SELECT DISTINCT polog.new_quotation_number,
                      polog.po_header_id,
                      poh.agent_id,
                      poh.vendor_id
        FROM xxconv_po_quotation_log polog, --- po quotation price breaks level rows inside
             po_headers_all          poh
       WHERE polog.batch_id = p_batch_id --parameter
         AND polog.status = 'N'
         AND polog.po_header_id = poh.po_header_id;
  
    CURSOR c_get_po_lines(p_po_header_id NUMBER) IS
      SELECT DISTINCT polog.po_header_id,
                      polog.po_line_id,
                      polog.line_num,
                      pl.item_id
        FROM xxconv_po_quotation_log polog, --- po quotation price breaks level rows inside
             po_lines_all            pl
       WHERE polog.batch_id = p_batch_id --parameter
         AND polog.po_header_id = p_po_header_id ---cursor parameter
         AND polog.status = 'N'
         AND polog.po_line_id = pl.po_line_id;
  
    CURSOR c_get_po_quota_price_breaks(p_po_line_id NUMBER) IS
      SELECT polog.po_line_id,
             polog.price_breake_num,
             polog.line_location_id,
             polog.price_brea_ship_to_location_id,
             polog.new_ship_to_organization_id,
             mp.organization_code                 new_ship_to_organization_code,
             hrl.inventory_organization_id        ship_to_loc_inv_organiz_id,
             mp_loc.organization_code             ship_to_loc_inv_organiz_code
        FROM xxconv_po_quotation_log polog, --- po quotation price breaks level rows inside
             mtl_parameters          mp,
             hr_locations_all        hrl,
             mtl_parameters          mp_loc
       WHERE polog.batch_id = p_batch_id --parameter
         AND polog.po_line_id = p_po_line_id ---cursor parameter
         AND polog.status = 'N'
         AND polog.new_ship_to_organization_id = mp.organization_id
         AND polog.price_brea_ship_to_location_id = hrl.location_id
         AND nvl(hrl.inventory_organization_id, -777) =
             mp_loc.organization_id(+)
       ORDER BY polog.price_breake_num;
  
    v_step          VARCHAR2(100);
    v_error_message VARCHAR2(3000);
    stop_this_po_validation EXCEPTION;
    ---invalid_buyer           EXCEPTION;
    v_num_of_validation_errors NUMBER := 0;
  BEGIN
    v_step          := 'Step 0';
    x_error_code    := 0; ---0--success
    x_error_message := NULL;
  
    FOR header_rec IN c_get_po_headers LOOP
      ---==================== HEADERS LOOP =============================
      BEGIN
        v_step := 'Step 10';
        -----Check Buyer ACTIVE USER (PO_HEADERS_ALL.agent_id)
        BEGIN
          SELECT 'Invalid PO Buyer (inactive person) (agent_id=' ||
                 header_rec.agent_id || ', name=' ||
                 hr_general.decode_person_name(header_rec.agent_id) || ')'
            INTO v_error_message
            FROM dual
           WHERE instr(xxhr_person_pkg.get_system_person_type(SYSDATE,
                                                              header_rec.agent_id),
                       'EX') > 0;
        
          -----all invalid Buyers will be replaced with Aviram, Yacov (agent_id=8681)
          UPDATE xxconv_po_quotation_log a
             SET a.agent_id         = 8681, --- Aviram, Yacov
                 a.error_message    = 'Invalid Buyer was replaced with Aviram, Yacov (agent_id=8681)',
                 a.last_update_date = SYSDATE
           WHERE a.po_header_id = header_rec.po_header_id
             AND a.batch_id = p_batch_id; ---parameter
          COMMIT;
        EXCEPTION
          WHEN no_data_found THEN
            NULL;
        END;
        v_step := 'Step 15';
        -----Check Buyer ACTIVE BUYER (PO_HEADERS_ALL.agent_id)
        BEGIN
          SELECT 'Invalid PO Buyer (inactive buyer) (agent_id=' ||
                 header_rec.agent_id || ', name=' ||
                 hr_general.decode_person_name(header_rec.agent_id) ||
                 ', end_active_date=' ||
                 to_char(poa.end_date_active, 'DD-MON-YYYY') || ')'
            INTO v_error_message
            FROM po_agents poa
           WHERE poa.agent_id = header_rec.agent_id
             AND nvl(poa.end_date_active, SYSDATE + 1) < SYSDATE;
        
          -----all invalid Buyers will be replaced with Aviram, Yacov (agent_id=8681)
          UPDATE xxconv_po_quotation_log a
             SET a.agent_id         = 8681, --- Aviram, Yacov
                 a.error_message    = 'Invalid Buyer was replaced with Aviram, Yacov (agent_id=8681)',
                 a.last_update_date = SYSDATE
           WHERE a.po_header_id = header_rec.po_header_id
             AND a.batch_id = p_batch_id; ---parameter
          COMMIT;
        EXCEPTION
          WHEN no_data_found THEN
            NULL;
        END;
      
        v_step := 'Step 20';
        -----Check Supplier (PO_HEADERS_ALL.vendor_id)
        BEGIN
          SELECT 'Invalid PO Supplier (vendor_id=' || header_rec.vendor_id ||
                 ', name=' || pv.vendor_name || ', end_active_date=' ||
                 to_char(pv.end_date_active, 'DD-MON-YYYY') || ')'
            INTO v_error_message
            FROM ap_suppliers pv ---po_vendors pv
           WHERE pv.vendor_id = header_rec.vendor_id
             AND nvl(pv.end_date_active, SYSDATE + 1) < SYSDATE
             AND rownum = 1;
          ---this PO Quotation is invalid and will not be converted
          RAISE stop_this_po_validation;
        EXCEPTION
          WHEN no_data_found THEN
            NULL;
        END;
      
        v_step := 'Step 25';
        -----Check Supplier vendor_site FREIGHT_CODE
        BEGIN
          SELECT 'Inactive FREIGHT_CODE ''' || fc.freight_code ||
                 ''' in PO Supplier vendor_site ''' || pvs.vendor_site_code ||
                 ' (vendor_id=' || header_rec.vendor_id || ', name=' ||
                 pv.vendor_name || ')'
            INTO v_error_message
            FROM ap_suppliers        pv,
                 wsh_carriers_v      fc,
                 po_vendor_sites_all pvs
           WHERE pv.vendor_id = header_rec.vendor_id
             AND pvs.vendor_id = pv.vendor_id
             AND pvs.ship_via_lookup_code = fc.freight_code
             AND fc.active = 'I' ---- Inactive freight_code
             AND rownum = 1;
          ---this PO Quotation is invalid and will not be converted
          RAISE stop_this_po_validation;
        EXCEPTION
          WHEN no_data_found THEN
            NULL;
        END;
      
        v_step := 'Step 30';
        -----Check NEW Quotation number (SEGMENT1) value lenght
        IF length(header_rec.new_quotation_number) > 20 THEN
          v_error_message := 'New Quotation number ' ||
                             header_rec.new_quotation_number ||
                             ' is too long for field PO_HEADERS_ALL.SEGMENT1 varchar2(20)';
          ---this PO Quotation is invalid and will not be converted
          RAISE stop_this_po_validation;
        END IF;
        ----------
      
        v_step := 'Step 30';
        ----Check Lines data
        FOR line_rec IN c_get_po_lines(header_rec.po_header_id) LOOP
          ---==================== LINES LOOP =============================
          ----Check NON Purchaseable Item (PO_LINES_ALL.item_id)
          BEGIN
            SELECT 'Item ' || msi.segment1 || ' (inv_item_id=' ||
                   line_rec.item_id || ') is NON Purchaseable'
              INTO v_error_message
              FROM mtl_system_items_b msi
             WHERE msi.organization_id = 91 ---Master
               AND msi.inventory_item_id = line_rec.item_id
               AND msi.purchasing_enabled_flag = 'N'; ---NON Purchaseable item
            v_step := 'Step 30.2';
            ---this PO Quotation LINE is invalid and will not be converted
            ----------but other valid lines will be converted...
            UPDATE xxconv_po_quotation_log a
               SET a.status           = 'E',
                   a.error_message    = v_error_message,
                   a.last_update_date = SYSDATE
             WHERE a.po_header_id = header_rec.po_header_id ---header
               AND a.po_line_id = line_rec.po_line_id
               AND a.batch_id = p_batch_id; ---parameter
          
            v_num_of_validation_errors := v_num_of_validation_errors +
                                          SQL%ROWCOUNT;
            ----RAISE stop_this_po_validation;
            ---=============================================
            ---CONTINUE THIS PO Quotation VALIDATION !
            ---=============================================
          EXCEPTION
            WHEN no_data_found THEN
              NULL;
          END;
        
          v_step := 'Step 40';
          ----Check Price Breaks----
          FOR price_break_rec IN c_get_po_quota_price_breaks(line_rec.po_line_id) LOOP
            ---================== PRICE BREAKS (LINE_LOC) LOOP =======================
            -----Check Location (PO_LINE_LOCATIONS_ALL.Ship_To_Location_Id)
            IF price_break_rec.ship_to_loc_inv_organiz_id IS NOT NULL AND
               price_break_rec.ship_to_loc_inv_organiz_id <>
               price_break_rec.new_ship_to_organization_id THEN
              v_error_message := 'The ship_to_location_id =' ||
                                 price_break_rec.price_brea_ship_to_location_id ||
                                 ' is currently defined to ' ||
                                 price_break_rec.ship_to_loc_inv_organiz_code || '(' ||
                                 price_break_rec.ship_to_loc_inv_organiz_id ||
                                 '), and is not defined to ' ||
                                 price_break_rec.new_ship_to_organization_code || '(' ||
                                 price_break_rec.new_ship_to_organization_id || ')';
            
              v_step := 'Step 40.2';
              ---this PO Quotation LINE PRICE BREAK is invalid and will not be converted
              ----------but other valid lines price breaks will be converted...
              UPDATE xxconv_po_quotation_log a
                 SET a.status           = 'E',
                     a.error_message    = v_error_message,
                     a.last_update_date = SYSDATE
               WHERE a.po_header_id = header_rec.po_header_id ---header
                 AND a.po_line_id = line_rec.po_line_id ---line
                 AND a.line_location_id = price_break_rec.line_location_id ---price break
                 AND a.batch_id = p_batch_id; --parameter
              v_num_of_validation_errors := v_num_of_validation_errors + 1;
              -----RAISE stop_this_po_validation;
              ---=============================================
              ---CONTINUE THIS PO Quotation VALIDATION !
              ---=============================================
            END IF;
          
          ---================== the end of PRICE BREAKS (LINE_LOC) LOOP =======================
          END LOOP;
          ---===============the end of LINES LOOP =============================
        END LOOP;
        ------
      EXCEPTION
        WHEN stop_this_po_validation THEN
          ---this PO Quotation is invalid and will not be converted
          UPDATE xxconv_po_quotation_log a
             SET a.status           = 'E',
                 a.error_message    = v_error_message,
                 a.last_update_date = SYSDATE
           WHERE a.po_header_id = header_rec.po_header_id
             AND a.batch_id = p_batch_id; ---parameter
          v_num_of_validation_errors := v_num_of_validation_errors +
                                        SQL%ROWCOUNT;
          /*WHEN invalid_buyer THEN
          -----all invalid Buyers will be replaced with Aviram, Yacov (agent_id=8681)
          UPDATE xxconv_po_quotation_log a
             SET a.agent_id         = 8681, --- Aviram, Yacov
                 a.error_message    = 'Invalid Buyer was replaced with Aviram, Yacov (agent_id=8681)',
                 a.last_update_date = SYSDATE
           WHERE a.po_header_id = header_rec.po_header_id
             AND a.batch_id = p_batch_id; ---parameter*/
      END;
      COMMIT; ---------------COMMIT-------------
    ---===============the end of HEADERS LOOP =============================
    END LOOP;
    COMMIT; ---------COMMIT-----------
  
    v_step := 'Step 100';
    IF v_num_of_validation_errors > 0 THEN
      message('========== ' || v_num_of_validation_errors ||
              ' records are INVALID in table XXCONV_PO_QUOTATION_LOG for batch_id=' ||
              p_batch_id || ' =================');
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      x_error_code    := 2;
      x_error_message := substr('Unexpected Error in  validate_quotations (' ||
                                v_step || '): ' || SQLERRM,
                                1,
                                200);
  END validate_quotations;
  --------------------------------------------------------------------
  --  customization code: CUST695
  --  name:               convert_po_quotations
  --  create by:          Vitaly K.
  --  $Revision:          1.0 $
  --  creation date:      30/10/2013
  --  Purpose :
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   30/10/2013    Vitaly K.       initial build CR932
  -----------------------------------------------------------------------
  PROCEDURE convert_po_quotations(errbuf                OUT VARCHAR2,
                                  retcode               OUT VARCHAR2,
                                  p_org_id              IN NUMBER,
                                  p_user_id             IN NUMBER,
                                  p_resp_id             IN NUMBER,
                                  p_resp_appl_id        IN NUMBER,
                                  p_po_quotation_number IN VARCHAR2) IS
  
    CURSOR c_get_po_quotations(p_batch_id NUMBER) IS
    
      SELECT tab.org_id,
             tab.po_header_id,
             tab.quotation_number,
             tab.new_quotation_number
        FROM (SELECT DISTINCT po.org_id,
                              po.po_header_id,
                              po.quotation_number,
                              po.new_quotation_number
                FROM xxconv_po_quotation_log po
               WHERE po.status = 'N'
                 AND po.batch_id = p_batch_id --- cursor parameter
                 AND po.org_id = p_org_id --- parameter
                 AND po.quotation_number =
                     nvl(p_po_quotation_number, po.quotation_number) --- parameter
              ) tab;
  
    v_step          VARCHAR2(100);
    v_error_code    NUMBER; ---0-success, 2-error
    v_error_message VARCHAR2(3000);
  
    v_interface_header_id          NUMBER;
    num_of_headers_in_open_interf  NUMBER := 0;
    num_of_lines_in_open_interface NUMBER := 0;
    num_of_line_loc_in_o_interface NUMBER := 0;
    num_of_inserted_doc_attach     NUMBER := 0;
    num_of_updated_old_quotations  NUMBER := 0;
    stop_processing           EXCEPTION;
    stop_and_exit             EXCEPTION;
    no_data_in_open_interface EXCEPTION;
  
    v_batch_id NUMBER := xxconv_po_quotation_log_seq.nextval;
  
    ------
    v_concurrent_request_id NUMBER;
    ---- out variables for fnd_concurrent.wait_for_request-----
    x_phase       VARCHAR2(100);
    x_status      VARCHAR2(100);
    x_dev_phase   VARCHAR2(100);
    x_dev_status  VARCHAR2(100);
    x_return_bool BOOLEAN;
    x_message     VARCHAR2(100);
  
  BEGIN
    v_step  := 'Step 0';
    errbuf  := 'Success';
    retcode := '0';
  
    IF p_org_id IS NULL THEN
      ---error
      v_error_message := 'ERROR in convert_po_quotations procedure: Missing p_org_id parameter';
      RAISE stop_processing;
    END IF;
  
    v_step := 'Step 30';
  
    v_step := 'Step 40';
    -- intiialize applications information
    fnd_global.apps_initialize(p_user_id, --Tamar.F ---3850 Yuval
                               p_resp_id,
                               p_resp_appl_id);
  
    mo_global.init('PO');
  
    message('batch_id=' || v_batch_id || '===========================');
    message('p_org_id=' || p_org_id || '===========================');
    message('p_user_id=' || p_user_id ||
            '=========== fnd_global.employee_id=' ||
            fnd_global.employee_id);
    message('p_resp_id=' || p_resp_id || '===========================');
    message('p_resp_appl_id=' || p_resp_appl_id ||
            '===========================');
    message('p_po_quotation_number=' || p_po_quotation_number ||
            '===========================');
    ---Insert po data (for a given p_org_id) into log table-------------
    v_step := 'Step 70';
    fill_quotation_log_table(p_batch_id            => v_batch_id,
                             p_org_id              => p_org_id,
                             p_po_quotation_number => p_po_quotation_number,
                             x_error_code          => v_error_code, ---0-success, 2-error
                             x_error_message       => v_error_message);
    IF v_error_code <> 0 THEN
      --- Unexpected error in Fill_Quotation_Log_Table-----
      RAISE stop_processing;
    END IF;
  
    ---Validate all PO Quotations inserted into table XXOBJT.XXCONV_PO_QUOTATION_LOG for this batch_id-------------
    v_step := 'Step 80';
    validate_quotations(p_batch_id      => v_batch_id,
                        x_error_code    => v_error_code, ---0-success, 2-error
                        x_error_message => v_error_message);
    IF v_error_code <> 0 THEN
      --- Unexpected error in check_all_po-----
      RAISE stop_processing;
    END IF;
  
    v_step := 'Step 300';
    FOR po_header_rec IN c_get_po_quotations(v_batch_id) LOOP
      ---====================== PO HEADERS LOOP =================================
      -- Insert Date into PO Open Interface Tables------
      handle_po_quotation_header(p_batch_id            => v_batch_id,
                                 p_org_id              => po_header_rec.org_id,
                                 p_po_header_id        => po_header_rec.po_header_id,
                                 x_interface_header_id => v_interface_header_id, --out
                                 x_error_code          => v_error_code, ---0-success, 2-error
                                 x_error_message       => v_error_message);
      IF v_error_code = 0 THEN
        ----Success----------------
        UPDATE xxconv_po_quotation_log a
           SET a.status = 'S', a.last_update_date = SYSDATE
         WHERE a.po_header_id = po_header_rec.po_header_id
           AND a.batch_id = v_batch_id
           AND a.status = 'N';
        COMMIT;
      ELSE
        ----Unexpected Error in handle_po_quotation_header----
        ROLLBACK;
        message('Unexpected ERROR in handle_po_quotation_header: ' ||
                v_error_message);
        UPDATE xxconv_po_quotation_log a
           SET a.status           = 'E',
               a.error_message    = v_error_message,
               a.last_update_date = SYSDATE
         WHERE a.po_header_id = po_header_rec.po_header_id
           AND a.batch_id = v_batch_id;
        COMMIT;
      END IF;
      ---============== the end of PO HEADERS LOOP ==============================
    END LOOP;
  
    COMMIT; ---- COMMIT ---- COMMIT ---- COMMIT ----
  
    ---Does data in Open Interface Tables exist for this batch------
    SELECT COUNT(1)
      INTO num_of_headers_in_open_interf
      FROM po_headers_interface pohi
     WHERE pohi.batch_id = v_batch_id
       AND pohi.document_type_code = 'QUOTATION'
       AND pohi.interface_source_code = 'Std_Cost_Conversion';
    SELECT COUNT(1)
      INTO num_of_lines_in_open_interface
      FROM po_lines_interface poli
     WHERE poli.interface_header_id IN
           (SELECT pohi.interface_header_id
              FROM po_headers_interface pohi
             WHERE pohi.batch_id = v_batch_id
               AND pohi.document_type_code = 'QUOTATION'
               AND pohi.interface_source_code = 'Std_Cost_Conversion');
    SELECT COUNT(1)
      INTO num_of_line_loc_in_o_interface
      FROM po_line_locations_interface polli
     WHERE polli.interface_header_id IN
           (SELECT pohi.interface_header_id
              FROM po_headers_interface pohi
             WHERE pohi.batch_id = v_batch_id
               AND pohi.document_type_code = 'QUOTATION'
               AND pohi.interface_source_code = 'Std_Cost_Conversion');
  
    IF num_of_headers_in_open_interf = 0 THEN
      v_error_message := 'WARNING ++++++  No Data Inserted Into Open Interface Tables +++++++++';
      message(v_error_message);
      RAISE no_data_in_open_interface;
    ELSE
      message(num_of_headers_in_open_interf || ' PO Headers, ' ||
              num_of_lines_in_open_interface || ' PO Lines, ' ||
              num_of_line_loc_in_o_interface ||
              ' PO Line Locations--- are Successfully INSERTED into PO Open Interface Tables');
    END IF;
  
    --===================== SUBMIT RERQUEST ===================================
    v_step := 'Step 400';
    ---Submit concurrent program 'Import Price Catalogs' / POXPDOI-------------------
  
    -----x_return_bool := fnd_request.set_print_options(NULL, NULL, 0, TRUE, 'N');
  
    v_concurrent_request_id := fnd_request.submit_request(application => 'PO',
                                                          program     => 'POXPDOI', ---Import Price Catalogs
                                                          argument1   => NULL, ----Default Buyer
                                                          argument2   => 'Quotation', ----Document Type
                                                          argument3   => 'Catalog', ----Document SubType
                                                          argument4   => 'N', ----Create or Update Items
                                                          argument5   => 'N', ----Create Sourcing Rules
                                                          argument6   => 'APPROVED', ----Approval Status
                                                          argument7   => NULL, ----Release Generation Method
                                                          argument8   => v_batch_id, ----Batch Id
                                                          argument9   => NULL, ---Operating Unit
                                                          argument10  => 'N', ---Global Agreement
                                                          argument11  => NULL, ---Enable Sourcing Level
                                                          argument12  => NULL, ---Sourcing Level
                                                          argument13  => NULL, ---Inv Org Enable
                                                          argument14  => NULL --, ---Inventory Organization
                                                          ---argument15  => NULL, ---Batch Size  --in PATCH only
                                                          ---argument16  => 'N' ---Gather Stats --in PATCH only
                                                          );
  
    COMMIT;
  
    v_step := 'Step 410';
    IF v_concurrent_request_id > 0 THEN
      message('Concurrent ''Import Price Catalogs'' was SUBMITTED successfully (request_id=' ||
              v_concurrent_request_id || ')');
      ---------
      LOOP
        x_return_bool := fnd_concurrent.wait_for_request(v_concurrent_request_id,
                                                         5, --- interval 10  seconds
                                                         3600, ---- max wait 1 hour
                                                         x_phase,
                                                         x_status,
                                                         x_dev_phase,
                                                         x_dev_status,
                                                         x_message);
        EXIT WHEN x_return_bool AND upper(x_dev_phase) = 'COMPLETE';
      
      END LOOP;
      IF upper(x_dev_phase) = 'COMPLETE' AND
         upper(x_dev_status) IN ('ERROR', 'WARNING') THEN
        v_error_message := 'Concurrent ''Import Price Catalogs'' concurrent program completed in ' ||
                           upper(x_dev_status) ||
                           '. See log for request_id=' ||
                           v_concurrent_request_id;
        message(v_error_message);
        message('==========================================================================================');
        message('=====================Error log for quotation import ======================================');
        retcode := '2';
        RAISE stop_processing;
      ELSIF upper(x_dev_phase) = 'COMPLETE' AND
            upper(x_dev_status) = 'NORMAL' THEN
        message('Concurrent ''Import Price Catalogs'' was SUCCESSFULLY COMPLETED (request_id=' ||
                v_concurrent_request_id || ')');
      ELSE
        v_error_message := 'Concurrent ''Import Price Catalogs'' failed , review log (request_id=' ||
                           v_concurrent_request_id || ')';
        message(v_error_message);
        retcode := '2';
        RAISE stop_processing;
      END IF;
    ELSE
      message('Concurrent ''Import Price Catalogs'' submitting PROBLEM');
      errbuf  := 'Concurrent ''Import Price Catalogs'' submitting PROBLEM';
      retcode := '2';
    END IF;
  
    v_step := 'Step 500';
    ----Check 'Import Price Catalogs' Results and update xxconv_po_quotation_log.status-------
    check_po_quotations_import_err(p_batch_id      => v_batch_id,
                                   x_error_code    => v_error_code, ---0-success, 2-error
                                   x_error_message => v_error_message);
    IF v_error_code <> 0 THEN
      ----Unexpected Error in check_po_quotations_import_err----
      RAISE stop_processing;
    END IF;
  
    v_step := 'Step 600';
    -----Document Attachments (New Quotation refers to Document Attachment of the Old Quotation)------
    FOR doc_attach_rec IN (SELECT ad.document_id,
                                  ad.seq_num,
                                  ad.entity_name,
                                  poq.new_po_header_id,
                                  ad.automatically_added_flag,
                                  ad.category_id
                             FROM fnd_attached_docs_form_vl ad,
                                  (SELECT DISTINCT a.po_header_id         old_po_header_id,
                                                   a.new_quotation_number,
                                                   poh.po_header_id       new_po_header_id
                                     FROM xxconv_po_quotation_log a,
                                          po_headers_all          poh
                                    WHERE a.batch_id = v_batch_id -----batch_id
                                      AND a.status = 'S' --- new quotation was successfully created
                                      AND a.new_quotation_number =
                                          poh.segment1 --- new quotation segment1
                                   ) poq
                            WHERE ad.function_name = 'PO_POXSCERQ_Q'
                              AND ad.entity_name = 'PO_HEADERS'
                              AND ad.pk1_value = poq.old_po_header_id
                              AND NOT EXISTS
                            (SELECT 1
                                     FROM fnd_attached_docs_form_vl ad2
                                    WHERE ad2.function_name = 'PO_POXSCERQ_Q'
                                      AND ad2.entity_name = 'PO_HEADERS'
                                      AND ad2.pk1_value =
                                          poq.new_po_header_id ---new quotation
                                      AND ad2.seq_num = ad.seq_num)
                            ORDER BY ad.pk1_value, ad.seq_num) LOOP
      ----------------LOOP----------------------
      BEGIN
        INSERT INTO fnd_attached_documents
          (attached_document_id,
           document_id,
           creation_date,
           created_by,
           last_update_date,
           last_updated_by,
           last_update_login,
           seq_num,
           entity_name,
           pk1_value,
           automatically_added_flag,
           program_update_date,
           category_id)
        VALUES
          (fnd_attached_documents_s.nextval,
           doc_attach_rec.document_id,
           SYSDATE, ----creation_date,
           fnd_global.user_id, ---- created_by,
           SYSDATE, ----- last_update_date,
           fnd_global.user_id, ---- last_updated_by,
           fnd_global.login_id,
           doc_attach_rec.seq_num,
           doc_attach_rec.entity_name,
           doc_attach_rec.new_po_header_id, ---- pk1_value,
           doc_attach_rec.automatically_added_flag,
           SYSDATE, ---- program_update_date,
           doc_attach_rec.category_id);
      
        num_of_inserted_doc_attach := num_of_inserted_doc_attach + 1;
      
      EXCEPTION
        WHEN OTHERS THEN
          v_error_message := v_step ||
                             ' Error when inserting into table fnd_attached_documents ' ||
                             SQLERRM;
          RAISE stop_processing;
      END;
      -----------------the end of LOOP-------------------------------
    END LOOP;
    COMMIT;
    IF num_of_inserted_doc_attach <> 0 THEN
      message('++++++++++++ ' || num_of_inserted_doc_attach ||
              ' records inserted into table FND_ATTACHED_DOCUMENTS +++++++++++++++++++');
    END IF;
  
    v_step := 'Step 700';
    ----- Update PO_HEADERS_ALL.END_DATE=trunc(sysdate) in all Old Quotation..if New Quotation was successfully created------
    BEGIN
      UPDATE po_headers_all poh
         SET poh.comments          = 'This Quotation was converted to Quotation ' ||
                                     (SELECT a.new_quotation_number
                                        FROM xxconv_po_quotation_log a
                                       WHERE a.batch_id = v_batch_id -----batch_id
                                         AND a.status = 'S' --- new quotation was successfully created
                                         AND a.quotation_number =
                                             poh.segment1 --- old quotation segment1
                                         AND rownum = 1) ||
                                     decode(poh.comments,
                                            NULL,
                                            NULL,
                                            '; ' || poh.comments),
             poh.end_date          = trunc(SYSDATE),
             poh.last_update_date  = SYSDATE,
             poh.last_updated_by   = fnd_global.user_id,
             poh.last_update_login = fnd_global.login_id
       WHERE poh.type_lookup_code = 'QUOTATION'
         AND EXISTS (SELECT 1
                FROM xxconv_po_quotation_log a
               WHERE a.batch_id = v_batch_id -----batch_id
                 AND a.status = 'S' --- new quotation was successfully created
                 AND a.quotation_number = poh.segment1); --- old quotation segment1
    
      num_of_updated_old_quotations := SQL%ROWCOUNT;
      message('++++++++++++ ' || num_of_updated_old_quotations ||
              ' Old Quotations are updated (PO_HEADERS_ALL.END_DATE) +++++++++++++++++++');
      COMMIT;
    EXCEPTION
      WHEN OTHERS THEN
        v_error_message := v_step ||
                           ' Error when updating PO_HEADERS_ALL.END_DATE ' ||
                           SQLERRM;
        RAISE stop_processing;
    END;
    ------------------------------------------------
  
    message('************** PROGRAM WAS COMPLETED *************************');
  
  EXCEPTION
    WHEN stop_and_exit THEN
      errbuf  := 'XXXXXXX';
      retcode := '1';
    WHEN no_data_in_open_interface THEN
      errbuf  := v_error_message;
      retcode := '1';
    WHEN stop_processing THEN
      message(v_error_message);
      errbuf  := v_error_message;
      retcode := '2';
      ROLLBACK;
    WHEN OTHERS THEN
      message('Unexpected Error in procedure xxconv_il_purchasing_pkg.convert_po_quotations ' ||
              v_step || ': ' || SQLERRM);
      errbuf  := 'Unexpected Error in procedure xxconv_il_purchasing_pkg.convert_po_quotations ' ||
                 v_step || ': ' || SQLERRM;
      retcode := '2';
      ROLLBACK;
  END convert_po_quotations;
  ----------------------------------------------------------------

BEGIN

  SELECT user_id
    INTO g_user_id
    FROM fnd_user
   WHERE user_name = 'CONVERSION';

  fnd_global.apps_initialize(user_id      => g_user_id,
                             resp_id      => 50623,
                             resp_appl_id => 660);

END xxconv_il_purchasing_pkg;
/
