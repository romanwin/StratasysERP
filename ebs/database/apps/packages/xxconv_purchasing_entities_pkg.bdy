CREATE OR REPLACE PACKAGE BODY xxconv_purchasing_entities_pkg IS

   g_user_id fnd_user.user_id%TYPE;

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
          WHERE cpq.int_status = 'N' AND
                quotation_num = p_quotation_header
          ORDER BY quotation_num, item;
   
      CURSOR csr_quot_price_breaks(p_quotation_header VARCHAR2, p_item VARCHAR2) IS
         SELECT *
           FROM xxobjt_conv_po_quotations cpq
          WHERE cpq.int_status = 'N' AND
                quotation_num = p_quotation_header AND
                cpq.item = p_item
          ORDER BY quotation_num, item, price_break_quantity, price DESC;
   
      /*      CURSOR csr_all_purch_orgs(p_org_id NUMBER, p_item_code VARCHAR2) IS
      SELECT ood.organization_id
        FROM mtl_system_items_b msi, org_organization_definitions ood
       WHERE ood.organization_id = msi.organization_id AND
             msi.segment1 = p_item_code AND
             ood.operating_unit = p_org_id;*/
   
      cur_quotation_header csr_quotation_headers%ROWTYPE;
      cur_quotation_line   csr_quotation_lines%ROWTYPE;
      cur_quot_price_break csr_quot_price_breaks%ROWTYPE;
      --  csr_purch_org        csr_all_purch_orgs%ROWTYPE;
      l_rate NUMBER;
   
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
   
      FOR cur_quotation_header IN csr_quotation_headers LOOP
      
         BEGIN
         
            l_header_counter := l_header_counter + 1;
            l_error_msg      := NULL;
            BEGIN
            
               SELECT organization_id
                 INTO l_org_id
                 FROM hr_operating_units ou
                WHERE ou.NAME = cur_quotation_header.operating_unit;
            
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
                WHERE s.vendor_id = ss.vendor_id AND
                      s.vendor_name = cur_quotation_header.supplier_name AND
                      rownum < 2;
               --(s.vendor_name_alt =
               --cur_quotation_header.supplier_name OR
               --s.vendor_name = cur_quotation_header.supplier_name) AND
               --ss.vendor_site_code(+) =
               --nvl(cur_quotation_header.supplier_site, 'NO SITE');
            
            EXCEPTION
               WHEN OTHERS THEN
                  l_error_msg := 'Invalid Supplier, ' || SQLERRM;
                  RAISE invalid_quotation;
               
            END;
         
            BEGIN
            
               --SELECT lookup_code
               --  INTO l_status
               --  FROM fnd_lookup_values
               -- WHERE lookup_type = 'RFQ/QUOTE STATUS' AND
               --       meaning = cur_quotation_header.status AND
               --       LANGUAGE = userenv('LANG');
            
               l_status := 'A';
            
            EXCEPTION
               WHEN OTHERS THEN
                  l_error_msg := 'Invalid Status, ' || SQLERRM;
                  RAISE invalid_quotation;
               
            END;
         
            BEGIN
            
               SELECT p.person_id
                 INTO l_buyer_id
                 FROM per_all_people_f p
                WHERE full_name = cur_quotation_header.buyer AND
                      p.current_employee_flag = 'Y' AND
                      SYSDATE BETWEEN p.effective_start_date AND
                      p.effective_end_date;
            
            EXCEPTION
               WHEN OTHERS THEN
                  l_error_msg := 'Invalid Buyer, ' || SQLERRM;
                  RAISE invalid_quotation;
                  -- l_buyer_id := 121;
            
            END;
         
            BEGIN
            
               IF cur_quotation_header.rfq IS NOT NULL THEN
               
                  SELECT po_header_id
                    INTO l_rfq_id
                    FROM po_headers_all h
                   WHERE h.type_lookup_code = 'RFQ' AND
                         segment1 = cur_quotation_header.rfq;
               
               ELSE
                  l_rfq_id := NULL;
               END IF;
            
            EXCEPTION
               WHEN OTHERS THEN
                  l_error_msg := 'Invalid RFQ, ' || SQLERRM;
                  RAISE invalid_quotation;
               
            END;
         
            /*            IF cur_quotation_header.currency != 'USD' THEN
                        
                           BEGIN
                           
                              l_rate := gl_currency_api.get_rate(x_from_currency   => cur_quotation_header.currency,
                                                                 x_to_currency     => 'USD',
                                                                 x_conversion_date => SYSDATE,
                                                                 x_conversion_type => 'Corporate');
                           
                           EXCEPTION
                              WHEN OTHERS THEN
                                 l_error_msg := 'Missing rate';
                                 RAISE invalid_quotation;
                              
                           END;
                        
                        ELSE
                           l_rate := NULL;
                        END IF;
            */
            SELECT po_headers_interface_s.NEXTVAL
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
                decode(cur_quotation_header.currency,
                       'USD',
                       NULL,
                       SYSDATE - 1),
                decode(cur_quotation_header.currency,
                       'USD',
                       NULL,
                       'Corporate'),
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
                        WHERE t.quotation_num =
                              cur_quotation_line.quotation_num AND
                              t.item = cur_quotation_line.item AND
                              t.price_break_quantity =
                              (SELECT MIN(price_break_quantity)
                                 FROM xxobjt_conv_po_quotations t1
                                WHERE t1.quotation_num = t.quotation_num AND
                                      t1.item = t.item)
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
                   WHERE segment1 = cur_quotation_line.item AND
                         organization_id =
                         xxinv_utils_pkg.get_master_organization_id AND
                         nvl(purchasing_enabled_flag, 'N') = 'Y';
               EXCEPTION
                  WHEN OTHERS THEN
                     l_error_msg := 'Invalid or non purchable Item, ' ||
                                    SQLERRM;
                     RAISE invalid_quotation;
                  
               END;
            
               SELECT organization_id,
                      decode(organization_id, 90, 144, 92, 145, NULL)
                 INTO l_ship_to_organization_id, l_ship_to_location_id
                 FROM (SELECT mp.organization_id
                         FROM mtl_system_items_b msi, mtl_parameters mp
                        WHERE msi.inventory_item_id = l_inventory_item_id AND
                              msi.organization_id = mp.organization_id AND
                              mp.organization_code IN ('WRI', 'WPI')
                        ORDER BY organization_code DESC)
                WHERE rownum < 2;
            
               /*BEGIN
               
                  SELECT location_id, inventory_organization_id
                    INTO l_ship_to_location_id, l_ship_to_organization_id
                    FROM hr_locations_all
                   WHERE location_code =
                         cur_quotation_header.ship_to_location;
               EXCEPTION
                  WHEN OTHERS THEN
                     l_error_msg := 'Invalid Location, ' || SQLERRM;
                     RAISE invalid_quotation;
                  
               END;*/
            
               SELECT po_lines_interface_s.NEXTVAL
                 INTO l_line_id
                 FROM dual;
            
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
               
                  IF cur_quot_price_break.price != l_price OR cur_quot_price_break.price_break_quantity !=
                     l_quantity OR cur_quot_price_break.effective_date !=
                     l_effective_date THEN
                  
                     --   FOR csr_purch_org IN csr_all_purch_orgs(l_org_id,
                     --                                           cur_quotation_line.item) LOOP
                  
                     SELECT po_lines_interface_s.NEXTVAL
                       INTO l_line_id
                       FROM dual;
                  
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
                     --  END LOOP;
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
   
      FOR cur_asl IN csr_asl_records LOOP
      
         BEGIN
         
            /* BEGIN
                  SELECT organization_id
                    INTO l_owning_organization_id
                    FROM mtl_parameters mp
                   WHERE organization_code = cur_asl.using_organization;
                  l_using_organization_id := l_owning_organization_id;
               
                  IF fnd_profile.SAVE(x_name       => 'MGF_ORGANIZATION_ID',
                                      x_value      => l_owning_organization_id,
                                      x_level_name => 'SITE') THEN
                     COMMIT;
                  END IF;
               
               EXCEPTION
                  WHEN OTHERS THEN
                     l_error_msg := 'Invalid Organization';
                     RAISE invalid_asl;
                  
               END;
            */
            /*
               The value of using organization id for Global ASL's is -1. Set the value of
               l_using_organization_id to -1 if the sourcing level is 'ITEM'. Else if the
               Sourcing level is 'ITEM-ORGANIZATION'we need to set the value to x_asl_org_id
            
               We need to select the value of inventory organization id only if the value
               of sourcing_level is  is 'ITEM'. This would happen if the calling program is Approval
               Workflow or if POASLGEN AND PDOI call the program with Sourcing Level set to Item
            */
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
                WHERE segment1 = cur_asl.item AND
                      organization_id =
                      xxinv_utils_pkg.get_master_organization_id;
            
               SELECT organization_id, organization_id
                 INTO l_using_organization_id, l_owning_organization_id
                 FROM (SELECT mp.organization_id
                         FROM mtl_system_items_b msi, mtl_parameters mp
                        WHERE msi.inventory_item_id = l_inventory_item_id AND
                              msi.organization_id = mp.organization_id AND
                              mp.organization_code IN ('WRI', 'WPI')
                        ORDER BY organization_code DESC)
                WHERE rownum < 2;
            
               IF fnd_profile.SAVE(x_name       => 'MGF_ORGANIZATION_ID',
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
            
               SELECT s.vendor_id,
                      ss.vendor_site_id,
                      ss.ship_to_location_id
                 INTO l_vendor_id, l_vendor_site_id, l_ship_to_location_id
                 FROM ap_suppliers s, ap_supplier_sites_all ss
                WHERE s.vendor_id = ss.vendor_id AND
                      s.vendor_name = cur_asl.supplier AND
                      rownum < 2;
            
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
         
            SELECT po_approved_supplier_list_s.NEXTVAL
              INTO l_asl_id
              FROM dual;
         
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
                l_asl_status_id,
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
             WHERE t.using_organization = cur_asl.using_organization AND
                   t.supplier = cur_asl.supplier AND
                   t.item = cur_asl.item;
         
         EXCEPTION
            WHEN invalid_asl THEN
               ROLLBACK;
               UPDATE xxobjt_conv_asl t
                  SET int_status = 'E', err_message = l_error_msg
                WHERE t.using_organization = cur_asl.using_organization AND
                      t.supplier = cur_asl.supplier AND
                      t.item = cur_asl.item;
            
            WHEN OTHERS THEN
               ROLLBACK;
               l_error_msg := SQLERRM;
               UPDATE xxobjt_conv_asl t
                  SET int_status = 'E', err_message = l_error_msg
                WHERE t.using_organization = cur_asl.using_organization AND
                      t.supplier = cur_asl.supplier AND
                      t.item = cur_asl.item;
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
          WHERE int_status = 'N' AND
                rule_name = p_rule_name;
   
      cur_rule csr_sourcing_rules%ROWTYPE;
      cur_line csr_rule_lines%ROWTYPE;
      invalid_rule EXCEPTION;
      invalid_item EXCEPTION;
   
      l_rule_name              VARCHAR(80);
      l_create_update_flag     VARCHAR2(10);
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
   
      l_create_update_flag := 'CREATE';
      l_organization_id    := xxinv_utils_pkg.get_master_organization_id;
   
      SELECT assignment_set_id
        INTO l_assignment_set_id
        FROM mrp_assignment_sets;
   
      FOR cur_rule IN csr_sourcing_rules LOOP
      
         BEGIN
         
            BEGIN
            
               SELECT organization_id
                 INTO l_org_id
                 FROM hr_operating_units ou
                WHERE ou.NAME = cur_rule.organization;
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
                WHERE s.vendor_id = ss.vendor_id AND
                      s.vendor_name = cur_rule.vendor AND
                      ss.vendor_site_code = ss.vendor_site_code AND
                      rownum < 2;
            
            EXCEPTION
               WHEN no_data_found THEN
                  l_error_msg := 'Invalid Supplier/Supplier Site';
                  RAISE invalid_rule;
               
            END;
         
            /*
                The possible values for sourcing_rule_type are :
                  Sourcing Rule           =>  1
                  Bill Of Distributions   =>  2
            
                By Default we create only sourcing rules and hence the value of l_sourcing_rule_type
                would have to be 1.
            
                If the value of x_assignment_type_id is null (x_assignment_type_id is null
                when called from PDOI/WORKFLOW)  we would default the x_assignment_type_id to
                3(This implies sourcing level 'ITEM').
            
                If the value of x_assignment_type_id is 3 it implies 'ITEM' assignment. In this
                case the organization_id would be null.
            
                If the value of x_assignment_type_id is 6 it implies 'ITEM-ORGANIZATION' assignment. In this
                case the organization_id/receipt_organization_id would be x_organization_id.
            */
            l_sourcing_rule_type := 1;
         
            /* Bug 1969613: Before this fix, an incoming line carrying a sourcing rule name
            which was already existing but a new item used to error out.
                           This happened since for a new item the code always fetched a
                           new sourcing rule id and tried to attach the new rule but with
                           the existing sourcing rule name.The following piece of code now
                           brings up the sourcing rule id for a new item also and in the
                           end the item will be assigned to the assignment set for this
                           sourcing rule id.Also no new sourcing rule will be created
                           in such a case. */
            /* Bug#3184990 Added the condition 'organization_id is null' to the below
            ** sql to avoid the ORA-1422 error as PDOI should always consider the
            ** Global Sourcing Rules only and not the local Sourcing Rules which are
            ** defined specific to the organization. */
         
            x_progress := '020';
            BEGIN
            
               ----<LOCAL SR/ASL PROJECT 11i11 START>
               SELECT sourcing_rule_id
                 INTO l_temp_sourcing_rule_id
                 FROM mrp_sourcing_rules
                WHERE sourcing_rule_name = l_rule_name AND
                      sourcing_rule_type = l_sourcing_rule_type AND ----<LOCAL SR/ASL PROJECT 11i11>
                      nvl(organization_id, -999) =
                      nvl(l_organization_id, -999); ----<LOCAL SR/ASL PROJECT 11i11>
               ----<LOCAL SR/ASL PROJECT 11i11 END>
               -- Bug#3184990
               l_error_msg := 'Rule already exists';
               RAISE invalid_rule;
            
            EXCEPTION
               WHEN no_data_found THEN
                  l_temp_sourcing_rule_id := NULL;
            END;
         
            x_progress := '030';
         
            SELECT mrp_sourcing_rules_s.NEXTVAL
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
         
            SELECT mrp_sr_receipt_org_s.NEXTVAL
              INTO l_sr_receipt_id
              FROM dual;
         
            x_progress := '040';
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
         
            x_progress := '050';
            SELECT mrp_sr_source_org_s.NEXTVAL
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
                      WHERE segment1 = cur_line.item AND
                            organization_id = l_organization_id;
                  
                     SELECT organization_id
                       INTO l_assign_organization_id
                       FROM (SELECT mp.organization_id
                               FROM mtl_system_items_b msi,
                                    mtl_parameters     mp
                              WHERE msi.inventory_item_id =
                                    l_inventory_item_id AND
                                    msi.organization_id = mp.organization_id AND
                                    mp.organization_code IN ('WRI', 'WPI')
                              ORDER BY organization_code DESC)
                      WHERE rownum < 2;
                  
                  EXCEPTION
                     WHEN no_data_found THEN
                     
                        l_error_msg := 'Invalid item';
                        RAISE invalid_item;
                     
                  END;
                  ----<LOCAL SR/ASL PROJECT 11i11 END>
               
                  SELECT mrp_sr_assignments_s.NEXTVAL
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
                  /* FPH We have created the sourcing rule. So set the flag to N.
                   * This will prevent us to call the update_sourcing_rule
                   * procedure.
                  */
               
                  /*
                  Assignment Type => Assignment Type ID Mapping
                  
                  Assignment Type         Assignment Type Id
                  --------------------------------------------
                  --------------------------------------------
                  Global              =>         1
                  Item              =>         3
                  Organization      =>         4
                  Category-Org      =>         5
                  Item-Organization =>         6
                  
                  */
               EXCEPTION
                  WHEN invalid_item THEN
                  
                     UPDATE xxobjt_conv_sourcing_rule t
                        SET int_status = 'E',
                            err_messge = l_error_msg,
                            rule_name  = rule_name || '_I'
                      WHERE t.rule_name = cur_rule.rule_name AND
                            t.vendor = cur_rule.vendor AND
                            t.organization = cur_rule.organization AND
                            t.item = cur_line.item;
                  
               END;
            
            --    COMMIT;
            
            END LOOP;
         
            UPDATE xxobjt_conv_sourcing_rule t
               SET int_status = 'S', err_messge = NULL
             WHERE t.rule_name = cur_rule.rule_name AND
                   t.vendor = cur_rule.vendor; /* AND
                                                                                     t.organization = cur_rule.organization AND
                                                                                     t.item = cur_line.ite*/
         
         EXCEPTION
            WHEN invalid_rule THEN
               ROLLBACK;
               UPDATE xxobjt_conv_sourcing_rule t
                  SET int_status = 'E', err_messge = l_error_msg
                WHERE t.rule_name = cur_rule.rule_name AND
                      t.vendor = cur_rule.vendor AND
                      t.organization = cur_rule.organization;
            
            WHEN OTHERS THEN
               ROLLBACK;
               l_error_msg := SQLERRM;
               UPDATE xxobjt_conv_sourcing_rule t
                  SET int_status = 'E', err_messge = l_error_msg
                WHERE t.rule_name = cur_rule.rule_name AND
                      t.vendor = cur_rule.vendor AND
                      t.organization = cur_rule.organization;
         END;
         COMMIT;
         l_error_msg := NULL;
      END LOOP;
   
   END load_sourcing_rule;
   
----------------------------------------------------------------
PROCEDURE load_po_blanket_lines(errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_po_segment1 IN VARCHAR2) IS
 
       CURSOR get_po_blanket_header IS
         SELECT  poh.po_header_id,
                 poh.segment1,
                 poh.type_lookup_code,
                 poh.vendor_id,
                 v.vendor_name,
                 poh.vendor_site_id,
                 vs.vendor_site_code,
                 poh.agent_id,
                 initcap(a.agent_name)    agent_name,
                 poh.org_id,
                 ou.name  operating_unit
          FROM  po_headers_all        poh,
                po_vendor_sites_all   vs,
                po_agents_v           a,
                po_vendors            v,
                hr_operating_units    ou,
                po_ga_org_assignments ga
          WHERE poh.segment1= p_po_segment1 --proc. parameter
          and   poh.global_agreement_flag='Y'
          and   poh.type_lookup_code='BLANKET'
          and   poh.vendor_id=4472 ---  Stratasys, Inc.
          and   ou.name in ('OBJET DE (OU)','OBJET HK (OU)')   --- org_id in (96, 103)
          and   ga.po_header_id=poh.po_header_id
          and   nvl(ga.enabled_flag, 'N') = 'Y'
          and   ga.organization_id=poh.org_id
          and   nvl(poh.vendor_site_id,-777)=vs.vendor_site_id(+)
          and   poh.org_id=ou.organization_id
          and   nvl(poh.agent_id,-777)=a.agent_id(+)
          and   nvl(poh.vendor_id,-777)=v.vendor_id(+);
   
      CURSOR get_po_blanket_lines IS
         SELECT upper(pol.item_code)  item_code,
                pol.price
           FROM xxobjt_conv_po_blanket_lines  pol
          WHERE pol.trans_to_int_code = 'N';
 
     
      missing_parameter_po_seg1 EXCEPTION;
      invalid_record            EXCEPTION;
      l_req_id                  NUMBER;
      l_step                    VARCHAR2(100);
      l_error_msg               VARCHAR2(250);
      l_inventory_item_id       NUMBER;
      l_line_num                NUMBER;
      ----l_line_id                 NUMBER;
      l_uom_code                VARCHAR2(3);
      l_unit_of_measure         mtl_system_items_b.primary_unit_of_measure%TYPE;
      l_header_counter          NUMBER :=0;
      l_inserted_lines_counter     NUMBER :=0;
   
BEGIN
  
errbuf  := '';
retcode := '0';

l_step:='Step 0'; 
if p_po_segment1 is null then
    raise missing_parameter_po_seg1;
end if;


l_step:='Step 5';    
update xxobjt_conv_po_blanket_lines  pol
set    pol.trans_to_int_code = 'E',
    pol.trans_to_int_error='More than 1 record for the same Item Code'
where nvl(pol.trans_to_int_code,'N') = 'N'
and   exists (select count(1) 
           from xxobjt_conv_po_blanket_lines  pol2
           where pol2.item_code=pol.item_code
           having count(1)>1);
   
commit; 

l_step:='Step 10';   
update xxobjt_conv_po_blanket_lines  pol
set    pol.trans_to_int_code = 'E',
    pol.trans_to_int_error='Missing Item Code'
where nvl(pol.trans_to_int_code,'N') = 'N'
and   pol.item_code is null;
   
commit;
   
l_step:='Step 15';
update xxobjt_conv_po_blanket_lines  pol
set    pol.trans_to_int_code = 'E',
    pol.trans_to_int_error='Missing Price'
where nvl(pol.trans_to_int_code,'N') = 'N'
and   pol.price is null;
   
commit;
   
l_step:='Step 20';
update xxobjt_conv_po_blanket_lines  pol
set    pol.trans_to_int_code = 'E',
    pol.trans_to_int_error='Price should be positive value'
where nvl(pol.trans_to_int_code,'N') = 'N'
and   pol.price <0;
   
commit;

l_step:='Step 25';
UPDATE xxobjt_conv_po_blanket_lines  pol
SET    pol.trans_to_int_code = 'E',
       pol.trans_to_int_error= 'There is forbidden character in item_code '
WHERE nvl(pol.trans_to_int_code,'N') = 'N'
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
     
commit;

l_step:='Step 30'; 
update xxobjt_conv_po_blanket_lines  pbl
set    pbl.trans_to_int_code = 'E',
       pbl.trans_to_int_error= 'Item already exists in po_lines_all for Blanket PO segment1='||p_po_segment1
where nvl(pbl.trans_to_int_code,'N') = 'N'
and   exists (select 1 
              from  po_headers_all      poh,
                    po_lines_all        pol,
                    mtl_system_items_b  msi
              where msi.segment1=upper(pbl.item_code)
              and   poh.segment1=p_po_segment1 --parameter
              and   msi.organization_id=91
              and   msi.inventory_item_id=pol.item_id
              and   poh.po_header_id=pol.po_header_id);    

commit;  

   
FOR blanket_header_rec IN get_po_blanket_header LOOP
        ------- PO Blanket Header loop ----- 1 record only -------------------------
        l_step:='Step 32';
        l_header_counter := l_header_counter + 1;
        l_error_msg      := NULL;
        dbms_output.put_line('==== Blanket PO segment1='||p_po_segment1||' =======');
        dbms_output.put_line('po_header_id    ='||blanket_header_rec.po_header_id);
        dbms_output.put_line('operating unit  ='||blanket_header_rec.operating_unit);
        dbms_output.put_line('type_lookup_code='||blanket_header_rec.type_lookup_code);
        dbms_output.put_line('vendor name     ='||blanket_header_rec.vendor_name);
        dbms_output.put_line('vendor site code='||blanket_header_rec.vendor_site_code);
        dbms_output.put_line('agent name      ='||blanket_header_rec.agent_name);
        
        fnd_file.put_line(fnd_file.log,'==== Blanket PO segment1='||p_po_segment1||' =======');
        fnd_file.put_line(fnd_file.log,'po_header_id    ='||blanket_header_rec.po_header_id);
        fnd_file.put_line(fnd_file.log,'operating unit  ='||blanket_header_rec.operating_unit);
        fnd_file.put_line(fnd_file.log,'type_lookup_code='||blanket_header_rec.type_lookup_code);
        fnd_file.put_line(fnd_file.log,'vendor name     ='||blanket_header_rec.vendor_name);
        fnd_file.put_line(fnd_file.log,'vendor site code='||blanket_header_rec.vendor_site_code);
        fnd_file.put_line(fnd_file.log,'agent name      ='||blanket_header_rec.agent_name);
        
        
        l_step:='Step 33';
        if blanket_header_rec.org_id=96 then  --- operating unit 'OBJET DE (OU)'            
            update xxobjt_conv_po_blanket_lines  pbl
            set    pbl.trans_to_int_code = 'E',
                   pbl.trans_to_int_error= 'Item '||upper(pbl.item_code)||' should be assigned to ''EOG'' organization_id=101'
            where nvl(pbl.trans_to_int_code,'N') = 'N'
            and NOT exists (SELECT 1 
                            FROM mtl_system_items_b msi
                            WHERE organization_id=101 --- EOG
                            AND msi.segment1=upper(pbl.item_code));                     
            commit;
            update xxobjt_conv_po_blanket_lines  pbl
            set    pbl.trans_to_int_code = 'E',
                   pbl.trans_to_int_error= 'Item '||upper(pbl.item_code)||' should be assigned to ''EOT'' organization_id=102'
            where nvl(pbl.trans_to_int_code,'N') = 'N'
            and NOT exists (SELECT 1 
                            FROM mtl_system_items_b msi
                            WHERE organization_id=102 --- EOT
                            AND msi.segment1=upper(pbl.item_code));                     
            commit;
            update xxobjt_conv_po_blanket_lines  pbl
            set    pbl.trans_to_int_code = 'E',
                   pbl.trans_to_int_error= 'Item '||upper(pbl.item_code)||' in ''EOG'' organization_id=101 -- flags...purchasing_enabled,purchasing_item,inventory_item,stock_enabled,mtl_transactions_enabled,costing_enabled,inventory_asset should be Y'
            where nvl(pbl.trans_to_int_code,'N') = 'N'
            and NOT exists (SELECT 1 
                            FROM mtl_system_items_b msi
                            WHERE organization_id=101 --- EOG
                            AND msi.segment1=upper(pbl.item_code)
                            AND nvl( msi.purchasing_enabled_flag, 'N') = 'Y'
                            AND nvl( msi.purchasing_item_flag, 'N')    = 'Y'
                            AND nvl( msi.inventory_item_flag, 'N')     = 'Y'
                            AND nvl( msi.stock_enabled_flag, 'N')      = 'Y'
                            AND nvl( msi.mtl_transactions_enabled_flag, 'N') = 'Y'
                            AND nvl( msi.costing_enabled_flag, 'N') = 'Y'
                            AND nvl( msi.inventory_asset_flag, 'N') = 'Y'
                            );                     
            commit;
            update xxobjt_conv_po_blanket_lines  pbl
            set    pbl.trans_to_int_code = 'E',
                   pbl.trans_to_int_error= 'Item '||upper(pbl.item_code)||' in ''EOT'' organization_id=102 -- flags...purchasing_enabled,purchasing_item,inventory_item,stock_enabled,mtl_transactions_enabled,costing_enabled,inventory_asset should be Y'
            where nvl(pbl.trans_to_int_code,'N') = 'N'
            and NOT exists (SELECT 1 
                            FROM mtl_system_items_b msi
                            WHERE organization_id=102 --- EOT
                            AND msi.segment1=upper(pbl.item_code)
                            AND nvl( msi.purchasing_enabled_flag, 'N') = 'Y'
                            AND nvl( msi.purchasing_item_flag, 'N')    = 'Y'
                            AND nvl( msi.inventory_item_flag, 'N')     = 'Y'
                            AND nvl( msi.stock_enabled_flag, 'N')      = 'Y'
                            AND nvl( msi.mtl_transactions_enabled_flag, 'N') = 'Y'
                            AND nvl( msi.costing_enabled_flag, 'N') = 'Y'
                            AND nvl( msi.inventory_asset_flag, 'N') = 'Y'
                            );                     
            commit;
            
        elsif blanket_header_rec.org_id=103 then  --- operating unit 'OBJET HK (OU)'               
            update xxobjt_conv_po_blanket_lines  pbl
            set    pbl.trans_to_int_code = 'E',
                   pbl.trans_to_int_error= 'Item '||upper(pbl.item_code)||' should be assigned to ''POH'' organization_id=121'
            where nvl(pbl.trans_to_int_code,'N') = 'N'
            and NOT exists (SELECT 1 
                            FROM mtl_system_items_b msi
                            WHERE organization_id=121 --- POH
                            AND msi.segment1=upper(pbl.item_code));                     
            commit;
            update xxobjt_conv_po_blanket_lines  pbl
            set    pbl.trans_to_int_code = 'E',
                   pbl.trans_to_int_error= 'Item '||upper(pbl.item_code)||' should be assigned to ''POT'' organization_id=461'
            where nvl(pbl.trans_to_int_code,'N') = 'N'
            and NOT exists (SELECT 1 
                            FROM mtl_system_items_b msi
                            WHERE organization_id=461 --- POT
                            AND msi.segment1=upper(pbl.item_code));                     
            commit;
            update xxobjt_conv_po_blanket_lines  pbl
            set    pbl.trans_to_int_code = 'E',
                   pbl.trans_to_int_error= 'Item '||upper(pbl.item_code)||' in ''POH'' organization_id=121 -- flags...purchasing_enabled,purchasing_item,inventory_item,stock_enabled,mtl_transactions_enabled,costing_enabled,inventory_asset should be Y'
            where nvl(pbl.trans_to_int_code,'N') = 'N'
            and NOT exists (SELECT 1 
                            FROM mtl_system_items_b msi
                            WHERE organization_id=121 --- POH
                            AND msi.segment1=upper(pbl.item_code)
                            AND nvl( msi.purchasing_enabled_flag, 'N') = 'Y'
                            AND nvl( msi.purchasing_item_flag, 'N')    = 'Y'
                            AND nvl( msi.inventory_item_flag, 'N')     = 'Y'
                            AND nvl( msi.stock_enabled_flag, 'N')      = 'Y'
                            AND nvl( msi.mtl_transactions_enabled_flag, 'N') = 'Y'
                            AND nvl( msi.costing_enabled_flag, 'N') = 'Y'
                            AND nvl( msi.inventory_asset_flag, 'N') = 'Y'
                            );                     
            commit;
            update xxobjt_conv_po_blanket_lines  pbl
            set    pbl.trans_to_int_code = 'E',
                   pbl.trans_to_int_error= 'Item '||upper(pbl.item_code)||' in ''POT'' organization_id=461'
            where nvl(pbl.trans_to_int_code,'N') = 'N'
            and NOT exists (SELECT 1 
                            FROM mtl_system_items_b msi
                            WHERE organization_id=461 --- POT
                            AND msi.segment1=upper(pbl.item_code)
                            AND nvl( msi.purchasing_enabled_flag, 'N') = 'Y'
                            AND nvl( msi.purchasing_item_flag, 'N')    = 'Y'
                            AND nvl( msi.inventory_item_flag, 'N')     = 'Y'
                            AND nvl( msi.stock_enabled_flag, 'N')      = 'Y'
                            AND nvl( msi.mtl_transactions_enabled_flag, 'N') = 'Y'
                            AND nvl( msi.costing_enabled_flag, 'N') = 'Y'
                            AND nvl( msi.inventory_asset_flag, 'N') = 'Y'
                            );                     
            commit;
        end if;
        
        BEGIN            
             --SELECT organization_id
             --  INTO l_org_id
             --  FROM hr_operating_units ou
             -- WHERE ou.NAME = blanket_header_rec.operating_unit;            
             mo_global.set_org_access(p_org_id_char     => blanket_header_rec.org_id,
                                      p_sp_id_char      => NULL,
                                      p_appl_short_name => 'PO');                    
        EXCEPTION
         WHEN OTHERS THEN
            l_error_msg := 'Invalid Operating Unit, ' || SQLERRM;
            RAISE invalid_record;               
        END;                       
         
        l_step:='Step 40';        
        ---Get max. existing line_num for this PO
        SELECT nvl(max(pol.line_num) ,0)
        INTO  l_line_num
        FROM  po_lines_all  pol
        WHERE pol.po_header_id = blanket_header_rec.po_header_id;
                 
                                  
        l_step:='Step 45';                
        INSERT INTO PO_HEADERS_INTERFACE (INTERFACE_HEADER_ID,
                                          PO_HEADER_ID, --this blanket po will be updated (new line/lines will be added)
                                          BATCH_ID,
                                          ACTION,
                                          PROCESS_CODE,
                                          DOCUMENT_TYPE_CODE,
                                          APPROVAL_STATUS,
                                          ORG_ID,
                                          VENDOR_ID,
                                          VENDOR_SITE_CODE,
                                          VENDOR_SITE_ID,
                                          AGENT_ID, --optional as you can enter buyer duringimport run
                                          -----VENDOR_DOC_NUM, --Unique Identifier used to update Blanket
                                          CREATION_DATE,
                                          CREATED_BY,
                                          LAST_UPDATE_DATE,
                                          LAST_UPDATED_BY )
              VALUES (apps.po_headers_interface_s.NEXTVAL,
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
                      sysdate,
                      g_user_id,
                      sysdate,
                      g_user_id );
                      
        l_error_msg      := NULL;
        FOR blanket_lines_rec IN get_po_blanket_lines LOOP
             --------- Lines loop -----------------------
             l_step:='Step 50';
             BEGIN              
               ----Check Item -----              
               BEGIN
                  SELECT inventory_item_id,
                         primary_uom_code,
                         primary_unit_of_measure
                    INTO l_inventory_item_id, l_uom_code, l_unit_of_measure
                    FROM mtl_system_items_b
                   WHERE segment1 = blanket_lines_rec.item_code
                   AND   organization_id = xxinv_utils_pkg.get_master_organization_id; 
               EXCEPTION
                  WHEN NO_DATA_FOUND THEN
                     l_error_msg := 'This item does not exist in mtl_system_items_b';
                     RAISE invalid_record;
               END;
               --------------------                                                      
               ---SELECT po_lines_interface_s.NEXTVAL
               ---  INTO l_line_id
               ---  FROM dual;
               --------------------
               l_line_num := l_line_num + 1;
               --------------------               
               INSERT INTO PO_LINES_INTERFACE ( INTERFACE_LINE_ID,
                                                INTERFACE_HEADER_ID,
                                                LINE_NUM,
                                                ITEM_ID,
                                                ACTION,
                                                PROCESS_CODE,
                                                UNIT_PRICE,
                                                QUANTITY,
                                                EXPIRATION_DATE,
                                                CREATION_DATE,
                                                CREATED_BY,
                                                LAST_UPDATE_DATE,
                                                LAST_UPDATED_BY)
                  VALUES (po_lines_interface_s.nextval,
                          po_headers_interface_s.currval,
                          l_line_num,
                          l_inventory_item_id,
                          'ADD',
                          'PENDING',
                          blanket_lines_rec.price,
                          999999,
                          to_date('31-DEC-2013','DD-MON-YYYY'),
                          sysdate,
                          g_user_id,
                          sysdate,
                          g_user_id); 
                            
               UPDATE xxobjt_conv_po_blanket_lines pol
               SET   pol.trans_to_int_code = 'S', 
                     pol.trans_to_int_error = NULL
               WHERE upper(pol.item_code) = blanket_lines_rec.item_code;   
               
               IF MOD(l_inserted_lines_counter, 1000) = 0 THEN
                  COMMIT;
               END IF;
               l_inserted_lines_counter:=l_inserted_lines_counter+1;
                
             EXCEPTION
              WHEN invalid_record THEN
                   ROLLBACK;
                   UPDATE xxobjt_conv_po_blanket_lines pol
                      SET pol.trans_to_int_code = 'E', 
                          pol.trans_to_int_error = l_error_msg
                    WHERE upper(pol.item_code) = blanket_lines_rec.item_code;
              
              WHEN OTHERS THEN
                   ROLLBACK;
                   l_error_msg := SQLERRM;
                   UPDATE xxobjt_conv_po_blanket_lines pol
                      SET pol.trans_to_int_code = 'E', 
                          pol.trans_to_int_error = l_error_msg
                    WHERE upper(pol.item_code) = blanket_lines_rec.item_code;
             END;  
             --------- the end of Lines loop -----------------------                         
        END LOOP; 
        ------- the end of PO Blanket Header loop ----------------------
END LOOP; 



if l_header_counter=0 then
   fnd_file.put_line(fnd_file.log,'==== Blanket PO segment1='||p_po_segment1||' is invalid or not exists');
   dbms_output.put_line('==== Blanket PO segment1='||p_po_segment1||' is invalid or not exists');
elsif l_inserted_lines_counter=0 then
   fnd_file.put_line(fnd_file.log,'==== No new lines in table XXOBJT_CONV_PO_BLANKET_LINES.   0 record inserted into interface tables...');
   dbms_output.put_line('==== No new lines in table XXOBJT_CONV_PO_BLANKET_LINES.   0 record inserted into interface tables...');
   ROLLBACK; -- dont commit PO_HEADERS_INTERFACE record without PO_LINES_INTERFACE records
elsif l_inserted_lines_counter>0 then
   COMMIT;
   fnd_file.put_line(fnd_file.log,'==== 1 record inserted into PO_HEADERS_INTERFACE table (action=UPDATE)');
   dbms_output.put_line('====    1 record inserted into PO_HEADERS_INTERFACE table (action=UPDATE)');
   
   fnd_file.put_line(fnd_file.log,'==== '||l_inserted_lines_counter||' records inserted into PO_LINES_INTERFACE table (action=ADD)');
   dbms_output.put_line('==== '||l_inserted_lines_counter||' records inserted into PO_LINES_INTERFACE table (action=ADD)');
end if;



-----------------------------------------------------------------------------------------------------------------------------------
---Concurrent program 'Import Price Catalogs' should be submitted from responsibility 'Implementation Manufacturing, OBJET'
-----------------------------------------------------------------------------------------------------------------------------------
/*l_req_id:=fnd_request.submit_request(
          'PO', 
          'POXPDOI',   ---Import Price Catalogs 
           NULL, 
           NULL, 
           FALSE,
           NULL,       ---parameter  1 Default Buyer
           'Blanket',  ---parameter  2 Document Type
           NULL,       ---parameter  3 Document Sub Type
           'N',        ---parameter  4 Create or Update Items
           'N',        ---parameter  5 Create Sourcing Rules
           'APPROVED', ---parameter  6 Approval Status
           NULL,       ---parameter  7 Release Generetion Method
           1,          ---parameter  8 Batch Id
           NULL,       ---parameter  9 Operating Unit
           'Y',        ---parameter 10 Global Agreement
           'Y',        ---parameter 11 Enable Sourcing Level
           NULL,       ---parameter 12 Sourcing Level
           NULL,       ---parameter 13 Inv Org Enable
           NULL);      ---parameter 14 Inventory Organization
COMMIT;*/

--see errors  select * from PO_INTERFACE_ERRORS

/*if l_req_id>0 then
    fnd_file.put_line(fnd_file.log,'Concurrent ''Import Price Catalogs'' was submitted successfully (request_id='||l_req_id);
    dbms_output.put_line('Concurrent ''Import Price Catalogs'' was submitted successfully (request_id='||l_req_id);
else
    fnd_file.put_line(fnd_file.log,'Concurrent ''Import Price Catalogs'' submitting PROBLEM');
    dbms_output.put_line('Concurrent ''Import Price Catalogs'' submitting PROBLEM');
end if;*/



EXCEPTION
  WHEN missing_parameter_po_seg1 THEN
     fnd_file.put_line(fnd_file.log,'=========Missing parameter p_po_segment1=========');
     dbms_output.put_line('=========Missing parameter p_po_segment1=========');
     errbuf  := 'Missing parameter p_po_segment1';
     retcode := '2';
  WHEN OTHERS THEN
     fnd_file.put_line(fnd_file.log,'==== Unexpected Error in procedure xxconv_purchasing_entities_pkg.load_po_blanket_lines '||l_step||': '||sqlerrm);
     dbms_output.put_line('==== Unexpected Error in procedure xxconv_purchasing_entities_pkg.load_po_blanket_lines '||l_step||': '||sqlerrm);
     errbuf  := 'Unexpected Error in procedure xxconv_purchasing_entities_pkg.load_po_blanket_lines '||l_step||': '||sqlerrm;
     retcode := '2';  
END load_po_blanket_lines;
----------------------------------------------------------------
PROCEDURE load_fdm_category_assignments(errbuf OUT VARCHAR2, retcode OUT VARCHAR2) IS
  
      CURSOR get_operating_units IS
      select ou.organization_id  org_id,
             ou.name             operating_unit
      from hr_operating_units  ou
      where ou.name in ('OBJET DE (OU)','OBJET HK (OU)');


      CURSOR get_organiz_and_sourcing_rule(p_org_id number) IS
      select distinct s.sourcing_rule_id, s.sourcing_rule_type, s.sourcing_rule_name,
                mp.organization_id , mp.organization_code
      from MRP_SOURCING_RULES  s,
           MRP_SR_RECEIPT_ORG  sr,
           mrp_sr_source_org   so, 
          (select a.organization_id, 
                  a.organization_code  
           from  mtl_parameters a
           where a.organization_id in (101,102,121,461)  
           and ((p_org_id=96  and a.organization_id in (101,102))
                  OR
                (p_org_id=103 and a.organization_id in (121,461)) 
                      ))  mp
      where sr.sourcing_rule_id=s.sourcing_rule_id
      and   so.sr_receipt_id=sr.sr_receipt_id
      and  s.sourcing_rule_name in ('SSYS DE','SSYS HK')
      and ( (p_org_id=96  and s.sourcing_rule_name='SSYS DE')
             OR
            (p_org_id=103 and s.sourcing_rule_name='SSYS HK') );
      /*select distinct s.sourcing_rule_id, s.sourcing_rule_type, s.sourcing_rule_name,
                      s.organization_id,mp.organization_code
      from MRP_SOURCING_RULES  s,
           MRP_SR_RECEIPT_ORG  sr,
           mrp_sr_source_org   so,
           mtl_parameters      mp
      where sr.sourcing_rule_id=s.sourcing_rule_id
      and   so.sr_receipt_id=sr.sr_receipt_id
      and   s.organization_id=mp.organization_id
      and ( (p_org_id=96  and s.organization_id in (101,102) and s.sourcing_rule_name='SSYS DE')
             OR
            (p_org_id=103 and s.organization_id in (121,461) and s.sourcing_rule_name='SSYS HK') );*/
      
   
      CURSOR get_fdm_categories IS
      select c.category_id, c.description      
      from   mtl_categories c
      where  c.attribute8='FDM';
      ----and    c.CATEGORY_ID=70123;
   
      invalid_operating_unit   EXCEPTION;
         
      ----l_org_id                 NUMBER;
      l_error_msg              VARCHAR2(500);
      l_assignment_id          NUMBER;
           
      l_success_inserted_assignments  NUMBER :=0;
      l_inserting_assignment_failure  NUMBER :=0;
      l_step                   VARCHAR2(100);
BEGIN
   
l_step:='Step 0';
errbuf  := null;
retcode := '0'; 
     
FOR operating_unit_rec IN get_operating_units LOOP
  ---=============  OPERATING UNITS LOOP ======================
  BEGIN            
     mo_global.set_org_access(p_org_id_char     => operating_unit_rec.org_id,
                              p_sp_id_char      => NULL,
                              p_appl_short_name => 'PO');            
  EXCEPTION
     WHEN OTHERS THEN
        l_error_msg := 'Invalid Operating Unit ''' || operating_unit_rec.operating_unit ||'''';
        RAISE invalid_operating_unit;               
  END;
  -------
  l_step:='Step 5';
  FOR organiz_and_sourcing_rule_rec IN get_organiz_and_sourcing_rule(operating_unit_rec.org_id) LOOP
  ---=============  ORGANIZATIONS AND SOURCING RULES LOOP ====================== 
        l_step:='Step 10';
        l_success_inserted_assignments:=0;
        l_inserting_assignment_failure:=0;
        FOR fdm_category_rec IN get_fdm_categories LOOP
          ---=============  FDM CATEGORIES LOOP ======================
                 l_step:='Step 15';     
                 SELECT mrp_sr_assignments_s.NEXTVAL
                    INTO l_assignment_id
                    FROM sys.dual;
                 l_step:='Step 20';
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
                         5,                    --- category-organization
                         organiz_and_sourcing_rule_rec.sourcing_rule_id,
                         1,                    ---  1=SOURCING RULE
                         1,                    --- 'Global Assigment' set
                         SYSDATE - 1,
                         g_user_id,
                         SYSDATE - 1,
                         g_user_id,
                         -1,
                         organiz_and_sourcing_rule_rec.organization_id,
                         fdm_category_rec.category_id,      
                         1100000041);          ---  Main Category Set
                     l_success_inserted_assignments:=l_success_inserted_assignments+1;
                  EXCEPTION
                     WHEN OTHERS THEN
                        l_inserting_assignment_failure:=l_inserting_assignment_failure+1;
                  END;
                                
                  /*
                  Assignment Type => Assignment Type ID Mapping
                  
                  Assignment Type         Assignment Type Id
                  --------------------------------------------
                  --------------------------------------------
                  Global            =>         1
                  Item              =>         3
                  Organization      =>         4
                  Category-Org      =>         5
                  Item-Organization =>         6                  
                  */
               
         ---=============  the end of FDM CATEGORIES LOOP ======================
        END LOOP;        
        COMMIT;
        fnd_file.put_line(fnd_file.log,'======== '||l_success_inserted_assignments||' category-organization assignments SUCCESSFULLY LOADED in organization '''||organiz_and_sourcing_rule_rec.organization_code||'''');
        dbms_output.put_line('======== '||l_success_inserted_assignments||' category-organization assignments SUCCESSFULLY LOADED in organization '''||organiz_and_sourcing_rule_rec.organization_code||'''');
        if l_inserting_assignment_failure>0 then
           fnd_file.put_line(fnd_file.log,'======== '||l_inserting_assignment_failure||' category-organization assignments loading FAILURED in organization '''||organiz_and_sourcing_rule_rec.organization_code||'''');
           dbms_output.put_line('======== '||l_inserting_assignment_failure||' category-organization assignments loading FAILURED in organization '''||organiz_and_sourcing_rule_rec.organization_code||'''');
        end if;
     ---=============  the end of ORGANIZATIONS AND SOURCING RULES LOOP ====================== 
  END LOOP;
  ---=============  the end of OPERATING UNITS LOOP ======================
END LOOP;


EXCEPTION
  WHEN invalid_operating_unit THEN
     fnd_file.put_line(fnd_file.log,l_error_msg);
     dbms_output.put_line(l_error_msg);
     errbuf  := l_error_msg;
     retcode := '2';   

  WHEN OTHERS THEN
     fnd_file.put_line(fnd_file.log,'==== Unexpected Error in procedure xxconv_purchasing_entities_pkg.load_fdm_category_assignments '||l_step||': '||sqlerrm);
     dbms_output.put_line('==== Unexpected Error in procedure xxconv_purchasing_entities_pkg.load_fdm_category_assignments '||l_step||': '||sqlerrm);
     errbuf  := 'Unexpected Error in procedure xxconv_purchasing_entities_pkg.load_fdm_category_assignments '||l_step||': '||sqlerrm;
     retcode := '2';  
END load_fdm_category_assignments;
----------------------------------------------------------------
BEGIN

   SELECT user_id
     INTO g_user_id
     FROM fnd_user
    WHERE user_name = 'CONVERSION';

   fnd_global.apps_initialize(user_id      => g_user_id,
                              resp_id      => 50623,
                              resp_appl_id => 660);

END xxconv_purchasing_entities_pkg;
/
