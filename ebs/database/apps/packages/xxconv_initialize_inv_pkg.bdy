CREATE OR REPLACE PACKAGE BODY xxconv_initialize_inv_pkg IS

   PROCEDURE misc_receive_int(errbuf OUT VARCHAR2, retcode OUT VARCHAR2) IS
   
      CURSOR cr_temp_tbl IS
         SELECT *
           FROM xxobjt_conv_inv_interface
          WHERE trans_to_int_code = 'N'
            FOR UPDATE OF trans_to_int_code, trans_to_int_error, transaction_id;
   
      v_error VARCHAR2(100);
      --v_serial_cont_code       mtl_system_items_b.serial_number_control_code%type;
   
      v_material_account            NUMBER;
      v_material_overhead_account   NUMBER;
      v_resource_account            NUMBER;
      v_outside_processing_account  NUMBER;
      v_overhead_account            NUMBER;
      v_trans_to_int_flag           CHAR(1);
      v_trans_to_int_error          VARCHAR2(240);
      v_dist_account_id             NUMBER;
      v_source_id                   mtl_generic_dispositions.disposition_id%TYPE;
      ln_reason_id                  NUMBER;
      ln_serial_number_control_code NUMBER := NULL;
      l_lot_control_code            NUMBER;
      l_user_id                     NUMBER;
   
      l_transaction_type_id        NUMBER;
      l_transaction_action_id      NUMBER;
      l_transaction_source_type_id NUMBER;
      v_trx_type_name              VARCHAR2(80);
      v_source_name                VARCHAR2(80);
      v_interfaced_txn_id          NUMBER;
      l_organization_id            NUMBER;
      v_uom_code                   VARCHAR2(5);
      l_locator_id                 NUMBER;
      l_revision_qty_control_code  NUMBER;
      l_revision                   VARCHAR2(5);
      l_inventory_item_id          NUMBER;
      l_stage                      VARCHAR2(80);
      l_counter                    NUMBER := 0;
      l_shelf_life_days            NUMBER;
   
   BEGIN
   
      -- LOADING DATE SHOULD BE 31/08/2009
   
      --dbms_output.put_line('STARTS HERE ');
      UPDATE mtl_system_items_b
         SET serial_number_control_code = 5, attribute30 = 'CHANGE'
       WHERE serial_number_control_code = 2;
   
      --backup in table xxobjt_shelf_life      
      UPDATE mtl_system_items_b
         SET attribute28 = shelf_life_code, attribute29 = shelf_life_days
       WHERE shelf_life_days > 0;
      COMMIT;
   
      UPDATE mtl_system_items_b
         SET shelf_life_code = 4, shelf_life_days = 0
       WHERE shelf_life_days > 0;
      COMMIT;
   
      BEGIN
         SELECT user_id
           INTO l_user_id
           FROM fnd_user
          WHERE user_name = 'CONVERSION';
      EXCEPTION
         WHEN no_data_found THEN
            l_user_id := NULL;
      END;
   
      fnd_global.apps_initialize(user_id      => l_user_id,
                                 resp_id      => 50606,
                                 resp_appl_id => 660);
   
      -- Get Transaction Source Code
      SELECT a.transaction_type_id,
             a.transaction_type_name,
             a.transaction_action_id,
             a.transaction_source_type_id,
             b.transaction_source_type_name
        INTO l_transaction_type_id,
             v_trx_type_name,
             l_transaction_action_id,
             l_transaction_source_type_id,
             v_source_name
        FROM mtl_transaction_types a, mtl_txn_source_types b
       WHERE a.transaction_source_type_id = b.transaction_source_type_id AND
             a.transaction_type_name = 'Account alias receipt';
   
      FOR i IN cr_temp_tbl LOOP
      
         BEGIN
         
            l_organization_id             := NULL;
            v_interfaced_txn_id           := NULL;
            v_source_id                   := NULL;
            l_inventory_item_id           := NULL;
            ln_serial_number_control_code := NULL;
            l_lot_control_code            := NULL;
            v_uom_code                    := NULL;
            l_revision_qty_control_code   := NULL;
            l_locator_id                  := NULL;
         
            l_stage := 'Organization';
         
            SELECT organization_id
              INTO l_organization_id
              FROM org_organization_definitions
             WHERE organization_code = TRIM(i.organization);
         
            /* SELECT organization_id
                 INTO l_organization_id
                 FROM mtl_parameters
                WHERE organization_code = TRIM(i.organization);
            */
         
            l_stage := 'Accounts';
         
            BEGIN
               SELECT mtp.material_account,
                      mtp.material_overhead_account,
                      mtp.resource_account,
                      mtp.outside_processing_account,
                      mtp.overhead_account
                 INTO v_material_account,
                      v_material_overhead_account,
                      v_resource_account,
                      v_outside_processing_account,
                      v_overhead_account
                 FROM mtl_parameters mtp
                WHERE organization_id = l_organization_id;
            EXCEPTION
               WHEN no_data_found THEN
                  v_material_account           := NULL;
                  v_material_overhead_account  := NULL;
                  v_resource_account           := NULL;
                  v_outside_processing_account := NULL;
                  v_overhead_account           := NULL;
                  v_trans_to_int_flag          := 'E';
                  v_trans_to_int_error         := 'Problem with account parameters';
            END;
         
            l_stage := 'Source';
         
            SELECT a.disposition_id
              INTO v_source_id
              FROM mtl_generic_dispositions a
             WHERE a.organization_id = l_organization_id AND
                   upper(segment1) = upper('DATA_CONVERSION'); -------*********************-----------
            -------------------------------------------------------------------------------
            l_stage := 'Reson';
         
            BEGIN
               SELECT v.reason_id
                 INTO ln_reason_id
                 FROM mtl_transaction_reasons v
                WHERE v.reason_name = 'Data Conversion';
            
            EXCEPTION
               WHEN no_data_found THEN
                  ln_reason_id := NULL;
            END;
         
            l_stage := 'Item Attributes';
         
            SELECT msi.inventory_item_id,
                   msi.serial_number_control_code,
                   msi.lot_control_code,
                   primary_uom_code,
                   revision_qty_control_code,
                   msi.shelf_life_days
              INTO l_inventory_item_id,
                   ln_serial_number_control_code,
                   l_lot_control_code,
                   v_uom_code,
                   l_revision_qty_control_code,
                   l_shelf_life_days
              FROM mtl_system_items_b msi
             WHERE msi.segment1 = i.item_code AND
                   msi.organization_id = l_organization_id;
         
            IF l_revision_qty_control_code = 2 THEN
            
               l_stage := 'Revision';
            
               SELECT MAX(revision)
                 INTO l_revision
                 FROM mtl_item_revisions_b
                WHERE inventory_item_id = l_inventory_item_id AND
                      organization_id = l_organization_id;
            
            ELSE
            
               l_revision := NULL;
            
            END IF;
         
            l_stage := 'Locator';
         
            BEGIN
            
               SELECT mil.inventory_location_id
                 INTO l_locator_id
                 FROM mtl_item_locations_kfv mil
                WHERE upper(mil.concatenated_segments) =
                      upper(i.locator_code) AND
                      mil.organization_id = l_organization_id;
            EXCEPTION
               WHEN no_data_found THEN
                  l_locator_id := NULL;
            END;
         
            l_stage := 'INSERT mtl_transactions_interface';
            SELECT inv.mtl_material_transactions_s.NEXTVAL
              INTO v_interfaced_txn_id
              FROM dual;
         
            INSERT INTO mtl_transactions_interface
               (inventory_item_id,
                transaction_interface_id,
                source_code,
                transaction_type_id,
                transaction_action_id,
                transaction_source_type_id,
                transaction_source_id,
                transaction_uom,
                transaction_quantity,
                primary_quantity,
                transaction_date,
                transaction_reference,
                organization_id,
                revision,
                reason_id,
                source_header_id,
                flow_schedule,
                process_flag,
                transaction_mode,
                creation_date,
                created_by,
                last_update_date,
                last_updated_by,
                last_update_login,
                subinventory_code,
                scheduled_flag,
                substitution_item_id,
                substitution_type_id,
                locator_id,
                source_line_id)
            VALUES
               (l_inventory_item_id,
                v_interfaced_txn_id,
                v_source_name,
                l_transaction_type_id,
                l_transaction_action_id,
                l_transaction_source_type_id,
                v_source_id,
                v_uom_code,
                i.quantity,
                i.quantity,
                to_date('31/08/2009', 'DD/MM/YYYY'),
                i.subinv_code,
                l_organization_id,
                l_revision,
                ln_reason_id,
                v_interfaced_txn_id,
                'Y',
                '1',
                '3',
                to_date('31/08/2009', 'DD/MM/YYYY'),
                l_user_id,
                to_date('31/08/2009', 'DD/MM/YYYY'),
                l_user_id,
                -1,
                i.subinv_code,
                '2',
                '0',
                '0',
                l_locator_id,
                v_interfaced_txn_id /*,
                                                                                                                                                                                                                                                                                                                                                                                                                                                v_material_account,
                                                                                                                                                                                                                                                                                                                                                                                                                                                v_material_overhead_account,
                                                                                                                                                                                                                                                                                                                                                                                                                                                v_resource_account,
                                                                                                                                                                                                                                                                                                                                                                                                                                                v_outside_processing_account,
                                                                                                                                                                                                                                                                                                                                                                                                                                                v_overhead_account*/);
         
            IF i.serial_number IS NOT NULL THEN
            
               l_stage := 'INSERT INTO mtl_serial_numbers_interface';
            
               INSERT INTO mtl_serial_numbers_interface
                  (transaction_interface_id,
                   source_code,
                   process_flag,
                   source_line_id,
                   fm_serial_number,
                   creation_date,
                   created_by,
                   last_update_date,
                   last_updated_by)
               VALUES
                  (v_interfaced_txn_id,
                   v_source_name,
                   1,
                   v_interfaced_txn_id,
                   i.serial_number,
                   to_date('31/08/2009', 'DD/MM/YYYY'),
                   l_user_id,
                   to_date('31/08/2009', 'DD/MM/YYYY'),
                   l_user_id);
            
            END IF;
         
            IF i.lot_number IS NOT NULL AND l_lot_control_code IS NOT NULL THEN
            
               l_stage := 'INSERT INTO mtl_transaction_lots_interface';
               INSERT INTO mtl_transaction_lots_interface
                  (transaction_interface_id,
                   source_code,
                   source_line_id,
                   last_update_date,
                   last_updated_by,
                   creation_date,
                   created_by,
                   last_update_login,
                   lot_number,
                   lot_expiration_date,
                   transaction_quantity,
                   primary_quantity,
                   process_flag)
               VALUES
                  (v_interfaced_txn_id,
                   v_source_name,
                   NULL,
                   to_date('31/08/2009', 'DD/MM/YYYY'),
                   l_user_id,
                   to_date('31/08/2009', 'DD/MM/YYYY'),
                   l_user_id,
                   -1,
                   i.lot_number,
                   i.expiration_date,
                   i.quantity,
                   i.quantity,
                   1);
            
            END IF;
         
            UPDATE xxobjt_conv_inv_interface
               SET trans_to_int_code  = 'S',
                   trans_to_int_error = NULL,
                   transaction_id     = v_interfaced_txn_id
             WHERE CURRENT OF cr_temp_tbl;
         
         EXCEPTION
            WHEN OTHERS THEN
               v_error := l_stage || ': ' || substr(SQLERRM, 1, 70);
               UPDATE xxobjt_conv_inv_interface
                  SET trans_to_int_code = 'E', trans_to_int_error = v_error
                WHERE CURRENT OF cr_temp_tbl;
         END;
      
      END LOOP;
   
      COMMIT;
   END misc_receive_int;
   -----------------------------------------------------------------------------------------------------

   PROCEDURE upload_locators(errbuf OUT VARCHAR2, retcode OUT NUMBER) IS
   
      CURSOR csr_upload_locators IS
         SELECT * FROM xxobjt_conv_locators WHERE err_code = 'N';
   
      CURSOR cr_vs_segments IS
         SELECT flex_value_set_id
           FROM fnd_id_flex_segments
          WHERE application_id = 401 AND
                id_flex_code = 'MTLL' AND
                id_flex_num = 101 AND
                enabled_flag = 'Y'
          ORDER BY segment_num;
   
      l_index                 NUMBER;
      cur_locator             csr_upload_locators%ROWTYPE;
      cur_vs                  cr_vs_segments%ROWTYPE;
      l_flex_value_set_id     NUMBER;
      l_flex_value_set_name   VARCHAR2(80);
      l_user_id               NUMBER;
      l_return_status         VARCHAR2(1);
      l_msg_count             NUMBER;
      l_msg_data              VARCHAR2(500);
      l_inventory_location_id NUMBER;
      l_locator_exists        VARCHAR2(10);
      l_status_id             NUMBER;
      l_organization_id       NUMBER;
      l_storage_value         VARCHAR2(50);
      l_rec_data              VARCHAR2(500);
      l_msg_index_out         NUMBER;
      segments                fnd_flex_ext.segmentarray;
   
   BEGIN
   
      SELECT user_id
        INTO l_user_id
        FROM fnd_user
       WHERE user_name = 'CONVERSION';
   
      fnd_global.apps_initialize(user_id      => l_user_id,
                                 resp_id      => 50606,
                                 resp_appl_id => 660);
   
      FOR cur_locator IN csr_upload_locators LOOP
      
         l_status_id       := NULL;
         l_organization_id := NULL;
         l_msg_data        := NULL;
      
         BEGIN
         
            SELECT status_id
              INTO l_status_id
              FROM mtl_material_statuses_vl sts
             WHERE locator_control = 1 AND
                   enabled_flag = 1 AND
                   sts.status_code = cur_locator.status;
         
            SELECT organization_id
              INTO l_organization_id
              FROM mtl_parameters
             WHERE organization_code = cur_locator.organization_code;
         
            IF fnd_profile.SAVE('MFG_ORGANIZATION_ID',
                                l_organization_id,
                                'SITE') THEN
               COMMIT;
            END IF;
         
            l_index := fnd_flex_ext.breakup_segments(cur_locator.loc_segments,
                                                     '.',
                                                     segments);
         
            l_index := 0;
         
            FOR cur_vs IN cr_vs_segments LOOP
               l_index := l_index + 1;
            
               IF l_index > 1 THEN
               
                  segments(l_index) := TRIM(upper(segments(l_index)));
               
                  BEGIN
                     l_flex_value_set_name := NULL;
                     SELECT fvs.flex_value_set_name
                       INTO l_flex_value_set_name
                       FROM fnd_flex_value_sets fvs
                      WHERE fvs.flex_value_set_id =
                            cur_vs.flex_value_set_id;
                  
                     SELECT 'Y'
                       INTO l_return_status
                       FROM fnd_flex_values
                      WHERE flex_value_set_id = cur_vs.flex_value_set_id AND
                            flex_value = segments(l_index);
                  
                  EXCEPTION
                     WHEN no_data_found THEN
                     
                        fnd_flex_val_api.create_independent_vset_value(p_flex_value_set_name => l_flex_value_set_name,
                                                                       p_flex_value          => segments(l_index),
                                                                       x_storage_value       => l_storage_value);
                     
                  END;
               
               END IF;
            
            END LOOP;
         
            COMMIT;
         
            l_msg_data      := NULL;
            l_return_status := 'S';
         
            fnd_msg_pub.initialize;
         
            inv_loc_wms_pub.create_locator(x_return_status            => l_return_status,
                                           x_msg_count                => l_msg_count,
                                           x_msg_data                 => l_msg_data,
                                           x_inventory_location_id    => l_inventory_location_id,
                                           x_locator_exists           => l_locator_exists,
                                           p_organization_id          => l_organization_id,
                                           p_organization_code        => cur_locator.organization_code,
                                           p_concatenated_segments    => cur_locator.loc_segments,
                                           p_description              => cur_locator.description,
                                           p_inventory_location_type  => NULL,
                                           p_picking_order            => NULL,
                                           p_location_maximum_units   => NULL,
                                           p_subinventory_code        => cur_locator.subinventory,
                                           p_location_weight_uom_code => NULL,
                                           p_max_weight               => NULL,
                                           p_volume_uom_code          => NULL,
                                           p_max_cubic_area           => NULL,
                                           p_x_coordinate             => NULL,
                                           p_y_coordinate             => NULL,
                                           p_z_coordinate             => NULL,
                                           p_physical_location_id     => NULL,
                                           p_pick_uom_code            => NULL,
                                           p_dimension_uom_code       => NULL,
                                           p_length                   => NULL,
                                           p_width                    => NULL,
                                           p_height                   => NULL,
                                           p_status_id                => l_status_id,
                                           p_dropping_order           => NULL);
         
            IF l_return_status != 'S' THEN
               IF l_msg_count > 1 THEN
                  FOR i IN 1 .. l_msg_count LOOP
                     fnd_msg_pub.get(p_msg_index     => i,
                                     p_encoded       => 'F',
                                     p_data          => l_rec_data,
                                     p_msg_index_out => l_msg_index_out);
                     l_msg_data := l_msg_data || ', ' || l_rec_data;
                  END LOOP;
               END IF;
            END IF;
         
            UPDATE xxobjt_conv_locators
               SET err_code = l_return_status, err_message = l_msg_data
             WHERE organization_code = cur_locator.organization_code AND
                   loc_segments = cur_locator.loc_segments;
         
         EXCEPTION
            WHEN OTHERS THEN
            
               l_msg_data := SQLERRM;
            
               UPDATE xxobjt_conv_locators
                  SET err_code = 'E', err_message = l_msg_data
                WHERE organization_code = cur_locator.organization_code AND
                      loc_segments = cur_locator.loc_segments;
            
         END;
      
      END LOOP;
   
      COMMIT;
   
   END upload_locators;

   PROCEDURE upload_items_cost(errbuf           OUT VARCHAR2,
                               retcode          OUT VARCHAR2,
                               p_operating_unit IN NUMBER) IS
      CURSOR csr_items_cost IS
         SELECT DISTINCT *
           FROM xxobjt_conv_item_cost a
          WHERE a.err_code = 'N'
          ORDER BY organization, item_code;
   
      /*      CURSOR csr_items_params(p_item_number VARCHAR2) IS
               SELECT msi.inventory_item_id,
                      msi.organization_id,
                      primary_uom_code,
                      mp.primary_cost_method,
                      mp.default_cost_group_id,
                      msi.revision_qty_control_code,
                      mp.material_account,
                      mp.material_overhead_account,
                      mp.resource_account,
                      mp.outside_processing_account,
                      mp.overhead_account
                 FROM mtl_system_items_b           msi,
                      mtl_parameters               mp,
                      org_organization_definitions ood
                WHERE msi.organization_id = mp.organization_id AND
                      msi.segment1 = p_item_number AND
                      mp.organization_id = ood.organization_id AND
                      ood.operating_unit = p_operating_unit AND
                      mp.organization_id != mp.master_organization_id;
      */
   
      CURSOR csr_items_params(p_item_number VARCHAR2, p_org_code VARCHAR2) IS
         SELECT msi.inventory_item_id,
                msi.organization_id,
                primary_uom_code,
                mp.primary_cost_method,
                mp.default_cost_group_id,
                msi.revision_qty_control_code,
                mp.material_account,
                mp.material_overhead_account,
                mp.resource_account,
                mp.outside_processing_account,
                mp.overhead_account
           FROM mtl_system_items_b msi, mtl_parameters mp
          WHERE msi.organization_id = mp.organization_id AND
                msi.segment1 = p_item_number AND
                mp.organization_code = p_org_code;
   
      cur_item_cost       csr_items_cost%ROWTYPE;
      cur_inv_item        csr_items_params%ROWTYPE;
      cur_inv_item_mis    csr_items_params%ROWTYPE;
      v_interfaced_txn_id mtl_transactions_interface.transaction_interface_id%TYPE;
      v_cost_group_id     mtl_transactions_interface.transaction_interface_id%TYPE;
      v_cmp_account       mtl_transactions_interface.material_account%TYPE;
      v_org_id            hr_organization_information.organization_id%TYPE;
      v_primary_qty       mtl_transactions_interface.primary_quantity%TYPE;
      v_upd_cost          cst_item_costs.item_cost%TYPE;
      v_avg_prevrun       CHAR(1);
   
      l_cost_type_id               NUMBER;
      l_error_msg                  VARCHAR2(500);
      l_stage                      VARCHAR2(20);
      v_source_id                  NUMBER;
      l_transaction_type_id        NUMBER;
      l_transaction_action_id      NUMBER;
      l_transaction_source_type_id NUMBER;
      l_prim_trx_quantity          NUMBER;
      l_user_id                    NUMBER;
      l_material_element           NUMBER;
      l_material_overhead_element  NUMBER;
      l_resource_element           NUMBER;
      v_dist_account               NUMBER;
      l_revision                   VARCHAR2(3);
   BEGIN
   
      SELECT user_id
        INTO l_user_id
        FROM fnd_user
       WHERE user_name = 'CONVERSION';
   
      fnd_global.apps_initialize(user_id      => l_user_id,
                                 resp_id      => 50606,
                                 resp_appl_id => 660);
   
      /*   -- Get Global Data
            SELECT a.org_information3
              INTO v_org_id
              FROM hr_organization_information a
             WHERE a.org_information_context = 'Accounting Information' AND
                   a.organization_id = p_organization_id;
      */
      -- SELECT FROM cst_cost_groups
   
      SELECT transaction_type_id,
             transaction_action_id,
             transaction_source_type_id
        INTO l_transaction_type_id,
             l_transaction_action_id,
             l_transaction_source_type_id
        FROM mtl_transaction_types mtt
       WHERE mtt.transaction_type_name = 'Average cost update';
   
      SELECT cost_element_id
        INTO l_material_element
        FROM cst_cost_elements
       WHERE cost_element = 'Material';
   
      SELECT cost_element_id
        INTO l_material_overhead_element
        FROM cst_cost_elements
       WHERE cost_element = 'Material Overhead';
   
      SELECT cost_element_id
        INTO l_resource_element
        FROM cst_cost_elements
       WHERE cost_element = 'Resource';
   
      FOR cur_item_cost IN csr_items_cost LOOP
      
         --FOR cur_inv_item IN csr_items_params(cur_item_cost.item_code,
         --                                     cur_item_cost.organization) LOOP
      
         BEGIN
         
            l_stage             := NULL;
            cur_inv_item        := cur_inv_item_mis;
            v_source_id         := NULL;
            l_revision          := NULL;
            l_prim_trx_quantity := NULL;
         
            l_stage := 'Item';
            SELECT msi.inventory_item_id,
                   msi.organization_id,
                   primary_uom_code,
                   mp.primary_cost_method,
                   mp.default_cost_group_id,
                   msi.revision_qty_control_code,
                   mp.material_account,
                   mp.material_overhead_account,
                   mp.resource_account,
                   mp.outside_processing_account,
                   mp.overhead_account
              INTO cur_inv_item
              FROM mtl_system_items_b msi, mtl_parameters mp
             WHERE msi.organization_id = mp.organization_id AND
                   msi.segment1 = cur_item_cost.item_code AND
                   mp.organization_code = cur_item_cost.organization;
         
            l_stage := 'Tansaction Source';
            -- BEGIN
            SELECT a.disposition_id, a.distribution_account
              INTO v_source_id, v_dist_account
              FROM mtl_generic_dispositions a
             WHERE a.organization_id = cur_inv_item.organization_id AND
                   upper(segment1) = upper('DATA_CONVERSION'); -------*********************-----------
            -------------------------------------------------------------------------------
            --EXCEPTION
            --   WHEN no_data_found THEN
            --      v_source_id := NULL;
            --END;
            l_stage := 'Revision';
         
            BEGIN
            
               SELECT MAX(revision)
                 INTO l_revision
                 FROM mtl_item_revisions_b
                WHERE inventory_item_id = cur_inv_item.inventory_item_id AND
                      organization_id = cur_inv_item.organization_id;
            
            EXCEPTION
               WHEN OTHERS THEN
                  l_revision := NULL;
               
            END;
         
            l_stage := 'Check On-Hand';
         
            SELECT nvl(SUM(primary_transaction_quantity), 0)
              INTO l_prim_trx_quantity
              FROM mtl_onhand_quantities_detail
             WHERE inventory_item_id = cur_inv_item.inventory_item_id AND
                   organization_id = cur_inv_item.organization_id;
         
            l_stage := 'Insert';
         
            SELECT inv.mtl_material_transactions_s.NEXTVAL
              INTO v_interfaced_txn_id
              FROM dual;
         
            INSERT INTO mtl_transactions_interface
               (transaction_interface_id,
                inventory_item_id,
                organization_id,
                revision,
                transaction_type_id,
                transaction_action_id,
                transaction_source_type_id,
                transaction_source_id,
                transaction_quantity,
                transaction_uom,
                primary_quantity,
                transaction_date,
                cost_group_id,
                cost_type_id,
                new_average_cost,
                source_line_id,
                source_header_id,
                process_flag,
                transaction_mode,
                creation_date,
                created_by,
                last_update_date,
                last_updated_by,
                last_update_login,
                source_code,
                material_account,
                material_overhead_account,
                resource_account,
                outside_processing_account,
                overhead_account)
            VALUES
               (v_interfaced_txn_id,
                cur_inv_item.inventory_item_id,
                cur_inv_item.organization_id,
                l_revision,
                l_transaction_type_id,
                l_transaction_action_id,
                l_transaction_source_type_id,
                v_source_id,
                0,
                cur_inv_item.primary_uom_code,
                l_prim_trx_quantity,
                to_date('31/08/2009', 'DD/MM/YYYY'),
                cur_inv_item.default_cost_group_id,
                cur_inv_item.primary_cost_method,
                (nvl(cur_item_cost.material_cost, 0) +
                nvl(cur_item_cost.material_overhead_cost, 0) +
                nvl(cur_item_cost.resource_cost, 0)),
                1, --> ?????
                1, --> ?????
                '1', --> ?????
                '3', --> ?????
                to_date('31/08/2009', 'DD/MM/YYYY'),
                l_user_id,
                to_date('31/08/2009', 'DD/MM/YYYY'),
                l_user_id,
                -1,
                'CONVERSION',
                v_dist_account,--cur_inv_item.material_account,
                v_dist_account,--cur_inv_item.material_overhead_account,
                v_dist_account,--cur_inv_item.resource_account,
                v_dist_account,--cur_inv_item.outside_processing_account,
                v_dist_account);--cur_inv_item.overhead_account);
            l_stage := 'Cost';
         
            l_stage := 'Material';
            INSERT INTO mtl_txn_cost_det_interface
               (transaction_interface_id,
                last_update_date,
                last_updated_by,
                creation_date,
                created_by,
                last_update_login,
                organization_id,
                cost_element_id,
                level_type,
                new_average_cost)
            VALUES
               (v_interfaced_txn_id,
                to_date('31/08/2009', 'DD/MM/YYYY'),
                l_user_id,
                to_date('31/08/2009', 'DD/MM/YYYY'),
                l_user_id,
                -1,
                cur_inv_item.organization_id,
                l_material_element, --Element id from file!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
                1,
                nvl(cur_item_cost.material_cost, 0));
         
            l_stage := 'Material Overhead';
            INSERT INTO mtl_txn_cost_det_interface
               (transaction_interface_id,
                last_update_date,
                last_updated_by,
                creation_date,
                created_by,
                last_update_login,
                organization_id,
                cost_element_id,
                level_type,
                new_average_cost)
            VALUES
               (v_interfaced_txn_id,
                to_date('31/08/2009', 'DD/MM/YYYY'),
                l_user_id,
                to_date('31/08/2009', 'DD/MM/YYYY'),
                l_user_id,
                -1,
                cur_inv_item.organization_id,
                l_material_overhead_element, --Element id from file!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
                1,
                nvl(cur_item_cost.material_overhead_cost, 0));
         
            l_stage := 'Resource';
            INSERT INTO mtl_txn_cost_det_interface
               (transaction_interface_id,
                last_update_date,
                last_updated_by,
                creation_date,
                created_by,
                last_update_login,
                organization_id,
                cost_element_id,
                level_type,
                new_average_cost)
            VALUES
               (v_interfaced_txn_id,
                to_date('31/08/2009', 'DD/MM/YYYY'),
                l_user_id,
                to_date('31/08/2009', 'DD/MM/YYYY'),
                l_user_id,
                -1,
                cur_inv_item.organization_id,
                l_resource_element, --Element id from file!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
                1,
                nvl(cur_item_cost.resource_cost, 0));
         
            UPDATE xxobjt_conv_item_cost t
               SET t.err_code = 'S', t.err_message = NULL
             WHERE item_code = cur_item_cost.item_code AND
                   organization = cur_item_cost.organization;
         
         EXCEPTION
            WHEN OTHERS THEN
            
               ROLLBACK;
               l_error_msg := l_stage || ': ' || SQLERRM;
               UPDATE xxobjt_conv_item_cost t
                  SET t.err_code = 'E', t.err_message = l_error_msg
                WHERE item_code = cur_item_cost.item_code AND
                      organization = cur_item_cost.organization;
         END;
         COMMIT;
      END LOOP;
   
   END upload_items_cost;



  PROCEDURE update_items_cost(errbuf           OUT VARCHAR2,
                               retcode          OUT VARCHAR2,
                               trx_date         IN VARCHAR2,
                               account_num      IN VARCHAR2,
                               p_operating_unit IN NUMBER) IS
      CURSOR csr_items_cost IS
         SELECT DISTINCT *
           FROM xxobjt_conv_item_cost a
          WHERE a.err_code = 'N'
          ORDER BY organization, item_code;
   
      /*      CURSOR csr_items_params(p_item_number VARCHAR2) IS
               SELECT msi.inventory_item_id,
                      msi.organization_id,
                      primary_uom_code,
                      mp.primary_cost_method,
                      mp.default_cost_group_id,
                      msi.revision_qty_control_code,
                      mp.material_account,
                      mp.material_overhead_account,
                      mp.resource_account,
                      mp.outside_processing_account,
                      mp.overhead_account
                 FROM mtl_system_items_b           msi,
                      mtl_parameters               mp,
                      org_organization_definitions ood
                WHERE msi.organization_id = mp.organization_id AND
                      msi.segment1 = p_item_number AND
                      mp.organization_id = ood.organization_id AND
                      ood.operating_unit = p_operating_unit AND
                      mp.organization_id != mp.master_organization_id;
      */
   
      CURSOR csr_items_params(p_item_number VARCHAR2, p_org_code VARCHAR2) IS
         SELECT msi.inventory_item_id,
                msi.organization_id,
                primary_uom_code,
                mp.primary_cost_method,
                mp.default_cost_group_id,
                msi.revision_qty_control_code,
                mp.material_account,
                mp.material_overhead_account,
                mp.resource_account,
                mp.outside_processing_account,
                mp.overhead_account
           FROM mtl_system_items_b msi, mtl_parameters mp
          WHERE msi.organization_id = mp.organization_id AND
                msi.segment1 = p_item_number AND
                mp.organization_code = p_org_code;
   
      cur_item_cost       csr_items_cost%ROWTYPE;
      cur_inv_item        csr_items_params%ROWTYPE;
      cur_inv_item_mis    csr_items_params%ROWTYPE;
      v_interfaced_txn_id mtl_transactions_interface.transaction_interface_id%TYPE;
      v_cost_group_id     mtl_transactions_interface.transaction_interface_id%TYPE;
      v_cmp_account       mtl_transactions_interface.material_account%TYPE;
      v_org_id            hr_organization_information.organization_id%TYPE;
      v_primary_qty       mtl_transactions_interface.primary_quantity%TYPE;
      v_upd_cost          cst_item_costs.item_cost%TYPE;
      v_avg_prevrun       CHAR(1);
   
      l_cost_type_id               NUMBER;
      l_error_msg                  VARCHAR2(500);
      l_stage                      VARCHAR2(20);
      v_source_id                  NUMBER:=null;
      l_transaction_type_id        NUMBER;
      l_transaction_action_id      NUMBER;
      l_transaction_source_type_id NUMBER;
      l_prim_trx_quantity          NUMBER;
      l_user_id                    NUMBER;
      l_material_element           NUMBER;
      l_material_overhead_element  NUMBER;
      l_resource_element           NUMBER;
      v_dist_account               NUMBER;
      l_revision                   VARCHAR2(3);
   BEGIN
   
      SELECT user_id
        INTO l_user_id
        FROM fnd_user
       WHERE user_name = 'CONVERSION';
   
      fnd_global.apps_initialize(user_id      => l_user_id,
                                 resp_id      => 50606,
                                 resp_appl_id => 660);
   
      /*   -- Get Global Data
            SELECT a.org_information3
              INTO v_org_id
              FROM hr_organization_information a
             WHERE a.org_information_context = 'Accounting Information' AND
                   a.organization_id = p_organization_id;
      */
      -- SELECT FROM cst_cost_groups
   
      SELECT transaction_type_id,
             transaction_action_id,
             transaction_source_type_id
        INTO l_transaction_type_id,
             l_transaction_action_id,
             l_transaction_source_type_id
        FROM mtl_transaction_types mtt
       WHERE mtt.transaction_type_name = 'Average cost update';
   
      SELECT cost_element_id
        INTO l_material_element
        FROM cst_cost_elements
       WHERE cost_element = 'Material';
   
      SELECT cost_element_id
        INTO l_material_overhead_element
        FROM cst_cost_elements
       WHERE cost_element = 'Material Overhead';
   
      SELECT cost_element_id
        INTO l_resource_element
        FROM cst_cost_elements
       WHERE cost_element = 'Resource';
   
      FOR cur_item_cost IN csr_items_cost LOOP
      
         --FOR cur_inv_item IN csr_items_params(cur_item_cost.item_code,
         --                                     cur_item_cost.organization) LOOP
      
         BEGIN
         
            l_stage             := NULL;
            cur_inv_item        := cur_inv_item_mis;
            v_source_id         := NULL;
            l_revision          := NULL;
            l_prim_trx_quantity := NULL;
         
            l_stage := 'Item';
            SELECT msi.inventory_item_id,
                   msi.organization_id,
                   primary_uom_code,
                   mp.primary_cost_method,
                   mp.default_cost_group_id,
                   msi.revision_qty_control_code,
                   mp.material_account,
                   mp.material_overhead_account,
                   mp.resource_account,
                   mp.outside_processing_account,
                   mp.overhead_account
              INTO cur_inv_item
              FROM mtl_system_items_b msi, mtl_parameters mp
             WHERE msi.organization_id = mp.organization_id AND
                   msi.segment1 = cur_item_cost.item_code AND
                   mp.organization_code = cur_item_cost.organization;
         
            /*l_stage := 'Tansaction Source';
            -- BEGIN
            SELECT a.disposition_id, A.DISTRIBUTION_ACCOUNT
              INTO v_source_id, v_dist_account
              FROM mtl_generic_dispositions a
             WHERE a.organization_id = cur_inv_item.organization_id AND
                   upper(segment1) = upper('WRI_RES_CORRECTION'); --*/-----*********************-----------
            -------------------------------------------------------------------------------
            --EXCEPTION
            --   WHEN no_data_found THEN
            --      v_source_id := NULL;
            --END;
            

            l_stage := 'Code Combination ID';
         
            BEGIN
            
              select GLCC.code_combination_id
              into v_dist_account
              from GL_CODE_COMBINATIONS_KFV GLCC
              WHERE GLCC.concatenated_segments=account_num;
            
            EXCEPTION
               WHEN OTHERS THEN
                  v_dist_account := NULL;
               
            END;
            
            l_stage := 'Revision';
         
            BEGIN
            
               SELECT MAX(revision)
                 INTO l_revision
                 FROM mtl_item_revisions_b
                WHERE inventory_item_id = cur_inv_item.inventory_item_id AND
                      organization_id = cur_inv_item.organization_id;
            
            EXCEPTION
               WHEN OTHERS THEN
                  l_revision := NULL;
               
            END;
         
            l_stage := 'Check On-Hand';
         
            SELECT nvl(SUM(primary_transaction_quantity), 0)
              INTO l_prim_trx_quantity
              FROM mtl_onhand_quantities_detail
             WHERE inventory_item_id = cur_inv_item.inventory_item_id AND
                   organization_id = cur_inv_item.organization_id;
         
            l_stage := 'Insert';
         
            SELECT inv.mtl_material_transactions_s.NEXTVAL
              INTO v_interfaced_txn_id
              FROM dual;
              
         
            INSERT INTO mtl_transactions_interface
               (transaction_interface_id,
                inventory_item_id,
                organization_id,
                revision,
                transaction_type_id,
                transaction_action_id,
                transaction_source_type_id,
                transaction_source_id,
                transaction_quantity,
                transaction_uom,
                primary_quantity,
                transaction_date,
                cost_group_id,
                cost_type_id,
                new_average_cost,
                source_line_id,
                source_header_id,
                process_flag,
                transaction_mode,
                creation_date,
                created_by,
                last_update_date,
                last_updated_by,
                last_update_login,
                source_code,
                material_account,
                material_overhead_account,
                resource_account,
                outside_processing_account,
                overhead_account)
            VALUES
               (v_interfaced_txn_id,
                cur_inv_item.inventory_item_id,
                cur_inv_item.organization_id,
                l_revision,
                l_transaction_type_id,
                l_transaction_action_id,
                l_transaction_source_type_id,
                v_source_id,
                0,
                cur_inv_item.primary_uom_code,
                l_prim_trx_quantity,
                to_date(trx_date, 'DD/MM/YYYY'), --'31/08/2009'
                cur_inv_item.default_cost_group_id,
                cur_inv_item.primary_cost_method,
                (nvl(cur_item_cost.material_cost, 0) +
                nvl(cur_item_cost.material_overhead_cost, 0) +
                nvl(cur_item_cost.resource_cost, 0)),
                1, --> ?????
                1, --> ?????
                '1', --> ?????
                '3', --> ?????
                trunc(sysdate),--'31/08/2009'
                l_user_id,
                trunc(sysdate), --'31/08/2009'
                l_user_id,
                -1,
                'COST_CORRECTION',
                v_dist_account,--cur_inv_item.material_account,
                v_dist_account,--cur_inv_item.material_overhead_account,
                v_dist_account,--cur_inv_item.resource_account,
                v_dist_account,--cur_inv_item.outside_processing_account,
                v_dist_account);--cur_inv_item.overhead_account);
            l_stage := 'Cost';
         
            l_stage := 'Material';
            INSERT INTO mtl_txn_cost_det_interface
               (transaction_interface_id,
                last_update_date,
                last_updated_by,
                creation_date,
                created_by,
                last_update_login,
                organization_id,
                cost_element_id,
                level_type,
                new_average_cost)
            VALUES
               (v_interfaced_txn_id,
                trunc(sysdate),--'31/08/2009'
                l_user_id,
                trunc(sysdate),--'31/08/2009'
                l_user_id,
                -1,
                cur_inv_item.organization_id,
                l_material_element, --Element id from file!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
                1,
                nvl(cur_item_cost.material_cost, 0));
         
            l_stage := 'Material Overhead';
            INSERT INTO mtl_txn_cost_det_interface
               (transaction_interface_id,
                last_update_date,
                last_updated_by,
                creation_date,
                created_by,
                last_update_login,
                organization_id,
                cost_element_id,
                level_type,
                new_average_cost)
            VALUES
               (v_interfaced_txn_id,
                trunc(sysdate),--'31/08/2009'
                l_user_id,
                trunc(sysdate),--'31/08/2009'
                l_user_id,
                -1,
                cur_inv_item.organization_id,
                l_material_overhead_element, --Element id from file!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
                1,
                nvl(cur_item_cost.material_overhead_cost, 0));
         
            l_stage := 'Resource';
            INSERT INTO mtl_txn_cost_det_interface
               (transaction_interface_id,
                last_update_date,
                last_updated_by,
                creation_date,
                created_by,
                last_update_login,
                organization_id,
                cost_element_id,
                level_type,
                new_average_cost)
            VALUES
               (v_interfaced_txn_id,
                trunc(sysdate),--'31/08/2009'
                l_user_id,
                trunc(sysdate),--'31/08/2009'
                l_user_id,
                -1,
                cur_inv_item.organization_id,
                l_resource_element, --Element id from file!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
                1,
                nvl(cur_item_cost.resource_cost, 0));
         
            UPDATE xxobjt_conv_item_cost t
               SET t.err_code = 'S', t.err_message = NULL
             WHERE item_code = cur_item_cost.item_code AND
                   organization = cur_item_cost.organization;
         
         EXCEPTION
            WHEN OTHERS THEN
            
               ROLLBACK;
               l_error_msg := l_stage || ': ' || SQLERRM;
               UPDATE xxobjt_conv_item_cost t
                  SET t.err_code = 'E', t.err_message = l_error_msg
                WHERE item_code = cur_item_cost.item_code AND
                      organization = cur_item_cost.organization;
         END;
         COMMIT;
      END LOOP;
   
   END update_items_cost;

END xxconv_initialize_inv_pkg;
/

